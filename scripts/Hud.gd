extends RefCounted
# The heads-up display, built over the fog (canvas layer 2): the danger tint and hurt flash, the
# life bar, the level and the objective, the hint strip, the map, the toast line, the level's
# title card, and the end-of-run banner. (Main owns one: `main.hud`; Main.minimap is the map it
# builds.)

const MiniMapScript := preload("res://scripts/MiniMap.gd")
const Style := preload("res://scripts/Style.gd")
const Items := preload("res://scripts/Items.gd")
const Clues := preload("res://scripts/Clues.gd")

# The border colour of the clue card for each picture.
const CLUE_TONES := {"question": Color("ffd23a"), "alert": Color("ff3a2c"), "house": Color("ffd27a"),
        "bin": Color("8d96a6"), "paw": Color("e8d9c0"), "zombie": Color("a9b79a")}

# The slot in the corner for the found item she carries (Items.gd): its picture, the key to use it, and, while an
# effect is running, how much of it is left. Tapping it uses the item.
class ItemSlot extends Control:
    var main
    var index := 0       # which item in her bag this slot shows; -1 for the one that shows an effect that is running
    var shown := ""      # what the slot last drew
    var pointer_mode := false
    var frac := -1.0     # and the effect's bar

    func kind() -> String:
        return main.bag[index] if index >= 0 and index < main.bag.size() else ""

    func _gui_input(event: InputEvent) -> void:
        if index >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            main.use_item(index)
            accept_event()

    func _draw() -> void:
        var tone: Color = Color(1, 1, 1, 0.25)
        var running: Dictionary = main.items.running() if index < 0 else {}
        var held: String = kind()
        if held != "":
            tone = Items.info(held).color
        elif not running.is_empty():
            tone = Items.info(running.kind).color
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.09, 0.78))
        draw_rect(Rect2(Vector2.ZERO, size), Color(tone.r, tone.g, tone.b, 0.9), false, 2.0)
        if held != "":
            Items.draw_icon(self, held, Vector2(size.x * 0.5, size.y * 0.46), size.x * 0.62)
            var cap := Rect2(size.x - 31.0, size.y - 17.0, 30.0, 16.0) if pointer_mode else Rect2(size.x - 17.0, size.y - 17.0, 16.0, 16.0)
            draw_rect(cap, Color(0.9, 0.88, 0.8))
            draw_string(Style.DISPLAY_FONT, cap.position + Vector2(3.0, 13.0), "USE" if pointer_mode else ("E" if index == 0 else str(index + 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11 if pointer_mode else 13, Color(0.1, 0.1, 0.14))
        elif not running.is_empty():
            Items.draw_icon(self, running.kind, Vector2(size.x * 0.5, size.y * 0.46), size.x * 0.62, 0.55)
        if not running.is_empty():
            var w: float = (size.x - 8.0) * float(running.frac)
            draw_rect(Rect2(4.0, size.y - 8.0, size.x - 8.0, 4.0), Color(0, 0, 0, 0.6))
            draw_rect(Rect2(4.0, size.y - 8.0, w, 4.0), Items.info(running.kind).color)

# The picture on the clue card, drawn by Style.draw_clue_icon.
class ClueIcon extends Control:
    var kind := ""

    func _draw() -> void:
        Style.draw_clue_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.9)

var main
var ui: Control
var compact := false
var screen_size := Vector2.ZERO
var pointer_hint: Label
var version: Label
var clue_panel: PanelContainer
var banner_box: VBoxContainer
var banner_text := ""
var clue_text := ""
var danger: ColorRect
var hurt_flash: ColorRect
var objective: Label
var level_label: Label
var hints: Control
var toast: Label
var toast_tween: Tween
var title_card: VBoxContainer  # "LEVEL 3 / RAINY NIGHT" as a level starts
var clue_layer: Control   # the card for the one-time hints (Clues.gd), over the hint strip
var clue_icon: ClueIcon
var clue_label: Label
var clue_style: StyleBoxFlat
var clue_tween: Tween
var clue_up := false  # a clue is on the card now
var item_slot: ItemSlot          # the first slot of her bag
var item_slots: Array = []        # all of them: the bag's slots, then the one that shows a running effect
var banner: Control
var banner_dim: ColorRect
var banner_title: Label
var banner_sub: Label
var pointer_controls: HBoxContainer
var sneak_button: Button
var torch_button: Button
var pause_button: Button
var pointer_window_size := Vector2i.ZERO
var patrol_warning: VBoxContainer
var patrol_warning_text: Label
var patrol_warning_bar: ProgressBar
var patrol_warning_fill: StyleBoxFlat
var warning_chasing := false

func _init(game) -> void:
    main = game

func build() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 2  # over the level's fog (layer 1)
    main.add_child(layer)
    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.theme = Style.theme()
    layer.add_child(ui)

    danger = ColorRect.new()
    danger.set_anchors_preset(Control.PRESET_FULL_RECT)
    danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    danger.color = Color(0.8, 0.05, 0.05, 0.0)
    ui.add_child(danger)

    hurt_flash = ColorRect.new()
    hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hurt_flash.color = Color(1.0, 0.1, 0.05, 0.0)
    ui.add_child(hurt_flash)

    main.vitals.build_bar(ui)
    level_label = Label.new()
    level_label.text = "LEVEL %d" % main.level
    level_label.position = Vector2(432, 11)
    level_label.add_theme_font_size_override("font_size", 18)
    level_label.add_theme_color_override("font_color", Style.GOLD)
    ui.add_child(level_label)

    objective = Label.new()
    objective.text = "Get Nicole and Stella home unseen."
    objective.position = Vector2(20, 46)
    objective.add_theme_font_size_override("font_size", 24)
    objective.add_theme_color_override("font_color", Style.GOLD)
    ui.add_child(objective)

    patrol_warning = VBoxContainer.new()
    patrol_warning.position = Vector2(20, 86)
    patrol_warning.custom_minimum_size.x = 420
    patrol_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(patrol_warning)
    patrol_warning_text = Label.new()
    patrol_warning_text.add_theme_font_size_override("font_size", 22)
    patrol_warning.add_child(patrol_warning_text)
    patrol_warning_bar = ProgressBar.new()
    patrol_warning_bar.custom_minimum_size = Vector2(420, 12)
    patrol_warning_bar.max_value = 1.0
    patrol_warning_bar.show_percentage = false
    patrol_warning_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var warning_back := StyleBoxFlat.new()
    warning_back.bg_color = Color(0.02, 0.03, 0.06, 0.85)
    warning_back.border_color = Style.DIM
    warning_back.set_border_width_all(1)
    patrol_warning_bar.add_theme_stylebox_override("background", warning_back)
    patrol_warning_fill = StyleBoxFlat.new()
    patrol_warning_fill.bg_color = Style.GOLD
    patrol_warning_bar.add_theme_stylebox_override("fill", patrol_warning_fill)
    patrol_warning.add_child(patrol_warning_bar)
    patrol_warning.hide()

    version = Label.new()
    version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
    version.add_theme_font_size_override("font_size", 16)
    version.add_theme_color_override("font_color", Style.DIM)
    version.anchor_top = 1.0
    version.anchor_bottom = 1.0
    version.offset_left = 18
    version.offset_top = -62  # above the hint row, which is wide
    version.offset_bottom = -10
    ui.add_child(version)

    # Control hints along the bottom; they fade once the player has got going.
    var bottom := VBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
    bottom.alignment = BoxContainer.ALIGNMENT_END
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(bottom)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(center)
    var strip := PanelContainer.new()
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var strip_box := StyleBoxFlat.new()
    strip_box.bg_color = Color(0.04, 0.05, 0.09, 0.72)
    strip_box.set_corner_radius_all(6)
    strip_box.content_margin_left = 16
    strip_box.content_margin_right = 16
    strip_box.content_margin_top = 8
    strip_box.content_margin_bottom = 8
    strip.add_theme_stylebox_override("panel", strip_box)
    center.add_child(strip)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 22)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.add_child(row)
    row.add_child(Style.hint(["CLICK"], "walk"))
    row.add_child(Style.hint(["W", "A", "S", "D"], "move"))
    row.add_child(Style.hint(["SHIFT"], "sneak"))
    if float(main.settings.darkness) > 0.0:
        row.add_child(Style.hint(["F"], "torch"))
        row.add_theme_constant_override("separation", 12)  # (the row is wider with the torch hint)
    row.add_child(Style.hint(["P"], "pause"))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 18)
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(gap)
    hints = center
    pointer_hint = Label.new()
    pointer_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pointer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ui.add_child(pointer_hint)

    # The map in the top-right corner: shows only what Nicole has seen, plus home.
    var minimap = MiniMapScript.new()
    minimap.setup(main)
    var saved: Dictionary = main.take_retry_state()
    if not saved.is_empty():
        minimap.import_state(saved)
    main.minimap = minimap
    minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    minimap.offset_left = -(minimap.size.x + 16.0)
    minimap.offset_right = -16.0
    minimap.offset_top = 14.0
    minimap.offset_bottom = 14.0 + minimap.size.y
    ui.add_child(minimap)

    # The found item she carries: a slot above the version number, bottom left.
    item_slot = ItemSlot.new()
    item_slot.main = main
    item_slot.anchor_top = 1.0
    item_slot.anchor_bottom = 1.0
    item_slot.offset_left = 18
    item_slot.offset_right = 18 + 64
    item_slot.offset_top = -144
    item_slot.offset_bottom = -80
    item_slot.visible = false
    ui.add_child(item_slot)
    item_slots.append(item_slot)
    for i in range(1, main.BAG_SIZE + 1):  # the rest of the bag, and last the one that shows an effect running
        var slot := ItemSlot.new()
        slot.main = main
        slot.index = i if i < main.BAG_SIZE else -1
        slot.visible = false
        ui.add_child(slot)
        item_slots.append(slot)

    # Persistent actions below the map, away from item/clue/retry prompts.
    pointer_controls = HBoxContainer.new()
    pointer_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pointer_controls.add_theme_constant_override("separation", 8)
    ui.add_child(pointer_controls)
    sneak_button = Style.pointer_button("Sneak OFF")
    sneak_button.toggle_mode = true
    sneak_button.toggled.connect(func(on: bool): main.sneak_toggle = on)
    pointer_controls.add_child(sneak_button)
    torch_button = Style.pointer_button("Torch ON")
    torch_button.toggle_mode = true
    torch_button.visible = float(main.settings.darkness) > 0.0
    torch_button.pressed.connect(func(): main.player.toggle_torch())
    pointer_controls.add_child(torch_button)
    pause_button = Style.pointer_button("Pause")
    pause_button.pressed.connect(func(): main.pause_menu.pause())
    ui.add_child(pause_button)
    for button in [sneak_button, torch_button, pause_button]:
        button.button_down.connect(func(): main.player.pointer_down = false)

    # The clue card: a picture and a line or two just above the hint strip, for the one-time hints.
    clue_panel = PanelContainer.new()
    clue_layer = clue_panel
    clue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clue_layer.modulate.a = 0.0
    ui.add_child(clue_layer)
    clue_style = StyleBoxFlat.new()
    clue_style.bg_color = Color(0.04, 0.05, 0.09, 0.88)
    clue_style.set_corner_radius_all(8)
    clue_style.set_border_width_all(2)
    clue_style.border_color = Style.GOLD
    clue_style.content_margin_left = 14
    clue_style.content_margin_right = 18
    clue_style.content_margin_top = 10
    clue_style.content_margin_bottom = 10
    clue_panel.add_theme_stylebox_override("panel", clue_style)
    clue_panel.resized.connect(_position_clue)
    var clue_row := HBoxContainer.new()
    clue_row.add_theme_constant_override("separation", 14)
    clue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clue_panel.add_child(clue_row)
    clue_icon = ClueIcon.new()
    clue_icon.custom_minimum_size = Vector2(44, 44)
    clue_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clue_row.add_child(clue_icon)
    clue_label = Label.new()
    clue_label.custom_minimum_size = Vector2(540, 0)
    clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    clue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    clue_label.add_theme_font_size_override("font_size", 18)
    clue_row.add_child(clue_label)
    toast = Label.new()
    toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
    toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
    toast.position.y = 64
    toast.modulate.a = 0.0
    toast.add_theme_font_size_override("font_size", 22)
    ui.add_child(toast)

    # The level's title card, shown for a few seconds as it starts.
    title_card = VBoxContainer.new()
    title_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
    title_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
    title_card.position.y = 120
    title_card.add_theme_constant_override("separation", 6)
    title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_card.modulate.a = 0.0
    var card_level := Style.display_label("", 26, Style.GOLD, 6)
    card_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_card.add_child(card_level)
    var card_name := Style.display_label("", 60, Style.INK, 10)
    card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_card.add_child(card_name)
    ui.add_child(title_card)

    # End-of-run banner: dimmed screen, big title, blinking prompt.
    banner = Control.new()
    banner.set_anchors_preset(Control.PRESET_FULL_RECT)
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.visible = false
    ui.add_child(banner)
    banner_dim = ColorRect.new()
    banner_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    banner_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(banner_dim)
    var box := VBoxContainer.new()
    banner_box = box
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 18)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(box)
    banner_title = Style.display_label("", 80, Style.RED, 12)
    banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(banner_title)
    banner_sub = Label.new()
    banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_sub.add_theme_font_size_override("font_size", 26)
    banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(banner_sub)
    box.resized.connect(_position_banner)

# Each frame: the red tint grows with how close any cop is to spotting her, and the hints and then
# the objective fade once the player has got going (`progress` is 1 when the hints should start
# to go, 2 for the objective).
func update(worst: float, progress: float) -> void:
    danger.color.a = worst * 0.35
    hints.modulate.a = clampf(1.0 - (progress - 1.0) / 0.25, 0.0, 1.0)
    objective.modulate.a = clampf(1.0 - (progress - 2.0) / 0.25, 0.0, 1.0)
    pointer_hint.modulate.a = hints.modulate.a
    pointer_controls.visible = main.state == "play"
    pause_button.visible = main.state == "play"
    main.minimap.visible = main.state == "play"  # (the map is always there, top right)
    objective.visible = main.state == "play"
    toast.visible = main.state == "play"
    sync_input_hints()
    sneak_button.set_pressed_no_signal(main.sneak_toggle)
    sneak_button.text = "Sneak ON" if main.sneak_toggle or Input.is_physical_key_pressed(KEY_SHIFT) else "Sneak OFF"
    torch_button.set_pressed_no_signal(main.player.torch_on)
    torch_button.text = "Torch ON" if main.player.torch_on else "Torch OFF"

func layout() -> void:
    compact = main.presentation.compact
    ui.scale = Vector2.ONE * main.presentation.unit
    ui.size = main.get_viewport_rect().size / main.presentation.unit
    screen_size = ui.size
    var width: float = screen_size.x
    var height: float = screen_size.y
    if compact:
        var map_scale: float = 0.62 if width < 600.0 else 0.8  # smaller on a phone, so it leaves room to see
        var reserve: float = main.minimap.custom_minimum_size.x * map_scale + 12.0  # the text beside the map keeps clear of it
        main.vitals.bar.scale = Vector2(160.0 / 340.0, 0.7)
        main.vitals.bar.position = Vector2(12, 12)
        main.vitals.label.position = Vector2(178, 10)
        main.vitals.label.add_theme_font_size_override("font_size", 14)
        level_label.position = Vector2(12, 32)
        level_label.add_theme_font_size_override("font_size", 14)
        objective.position = Vector2(12, 64)
        objective.text = "Get Nicole and Stella home unseen."
        objective.add_theme_font_size_override("font_size", 17)
        objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        objective.custom_minimum_size.x = width - 24 - reserve   # (so it wraps beside the map)
        objective.size = Vector2(width - 24 - reserve, 0)
        patrol_warning.position = Vector2(12, 116)
        patrol_warning.custom_minimum_size.x = minf(420, width - 24 - reserve)
        patrol_warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        patrol_warning_text.custom_minimum_size.x = minf(420, width - 24 - reserve)
        patrol_warning_text.add_theme_font_size_override("font_size", 16)
        patrol_warning_bar.custom_minimum_size = Vector2(minf(420, width - 24 - reserve), 6)
        patrol_warning.size.x = minf(420, width - 24 - reserve)
        sneak_button.visible = true   # a phone has no Shift
        for button in [sneak_button, torch_button, pause_button]:
            button.scale = Vector2.ONE
            button.custom_minimum_size.y = 48
            button.add_theme_font_size_override("font_size", 16)
        sneak_button.custom_minimum_size.x = 104
        torch_button.custom_minimum_size.x = 96
        pause_button.custom_minimum_size.x = 72
        pause_button.size = pause_button.custom_minimum_size
        pause_button.position = Vector2(width - 84, 8)
        pointer_controls.scale = Vector2.ONE
        pointer_controls.reset_size()
        var actions: Vector2 = pointer_controls.get_combined_minimum_size()
        pointer_controls.position = Vector2(width - actions.x - 12, height - 60)
        main.minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
        main.minimap.scale = Vector2.ONE * map_scale
        main.minimap.size = main.minimap.custom_minimum_size
        main.minimap.position = Vector2(width - main.minimap.size.x * main.minimap.scale.x - 12, 64)
        main.minimap.visible = main.state == "play"
        item_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
        item_slot.size = Vector2(56, 56)
        item_slot.position = Vector2(12, height - 68)
        version.hide()
        pointer_hint.position = Vector2(12, 88)
        pointer_hint.size = Vector2(width - 24 - reserve, 0)
        pointer_hint.add_theme_font_size_override("font_size", 16)
        toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
        toast.position = Vector2(12, 152)
        toast.size = Vector2(width - 24, 0)
        toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        toast.add_theme_font_size_override("font_size", 16)
        title_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
        title_card.get_child(0).add_theme_font_size_override("font_size", 18)
        title_card.get_child(1).add_theme_font_size_override("font_size", 30)
        title_card.reset_size()
        title_card.position = Vector2((width - title_card.get_combined_minimum_size().x) * 0.5, 192 if height > width else 72)
        banner_title.add_theme_font_size_override("font_size", 36)
        banner_sub.add_theme_font_size_override("font_size", 16)
        banner_sub.custom_minimum_size.x = width - 32
    else:
        main.vitals.bar.scale = Vector2.ONE
        main.vitals.bar.position = Vector2(20, 14)
        main.vitals.label.position = Vector2(368, 11)
        main.vitals.label.add_theme_font_size_override("font_size", 18)
        level_label.position = Vector2(432, 11)
        level_label.add_theme_font_size_override("font_size", 18)
        objective.position = Vector2(20, 46)
        objective.autowrap_mode = TextServer.AUTOWRAP_OFF
        objective.custom_minimum_size.x = 0.0
        objective.add_theme_font_size_override("font_size", 24)
        objective.reset_size()
        patrol_warning.position = Vector2(20, 86)
        patrol_warning_text.autowrap_mode = TextServer.AUTOWRAP_OFF
        patrol_warning_text.custom_minimum_size.x = 420
        patrol_warning_text.add_theme_font_size_override("font_size", 22)
        patrol_warning_bar.custom_minimum_size = Vector2(420, 12)
        patrol_warning.custom_minimum_size.x = 420
        patrol_warning.reset_size()
        sneak_button.visible = false   # on a computer Shift sneaks (the hint strip and the click hint say so): no button
        for button in [sneak_button, torch_button, pause_button]:
            button.custom_minimum_size = Vector2(128, 64)
            button.add_theme_font_size_override("font_size", 20)
        pointer_controls.reset_size()
        var row_size: Vector2 = pointer_controls.get_combined_minimum_size()
        var factor: float = minf(Style.pointer_scale(main.get_viewport()), minf((width - 32.0) / row_size.x, (height - 180.0) / (row_size.y + 72.0)))
        pointer_controls.scale = Vector2.ONE * factor
        pointer_controls.position = Vector2(width - row_size.x * factor - 16, height - row_size.y * factor - 16)
        pause_button.scale = Vector2.ONE
        pause_button.size = pause_button.custom_minimum_size
        main.minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
        main.minimap.scale = Vector2.ONE
        main.minimap.size = main.minimap.custom_minimum_size
        main.minimap.position = Vector2(width - main.minimap.size.x - 16, 14)  # top right
        var below_map: float = main.minimap.position.y + main.minimap.size.y + 8
        pause_button.position = Vector2(width - 144, below_map)
        item_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
        item_slot.size = Vector2(64, 64)
        item_slot.position = Vector2(18, height - 144)
        version.show()
        pointer_hint.position = Vector2(20, height - 46)
        pointer_hint.size = Vector2(width - 40, 0)
        pointer_hint.add_theme_font_size_override("font_size", 18)
        toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
        toast.size = Vector2(840, 0)
        toast.position = Vector2((width - 840) * 0.5, 64)
        toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        toast.add_theme_font_size_override("font_size", 22)
        title_card.get_child(0).add_theme_font_size_override("font_size", 26)
        title_card.get_child(1).add_theme_font_size_override("font_size", 60)
        title_card.reset_size()
        title_card.position = Vector2((width - title_card.get_combined_minimum_size().x) * 0.5, 120)
        banner_title.add_theme_font_size_override("font_size", 80)
        banner_sub.add_theme_font_size_override("font_size", 26)
        banner_sub.custom_minimum_size.x = 760
    main.minimap.visible = main.state == "play"
    banner_sub.text = banner_text.replace("Press R or tap", "Tap") if compact else banner_text
    banner_title.custom_minimum_size.x = banner_sub.custom_minimum_size.x
    banner_title.size.x = banner_sub.custom_minimum_size.x
    banner_sub.size.x = banner_sub.custom_minimum_size.x
    # Containers grow to fit children but retain an old desktop width on rotation.
    banner_box.size.x = banner_sub.custom_minimum_size.x
    banner_box.reset_size()
    _layout_clue()
    _position_banner()
    _place_item_slots()
    sync_input_hints()

func _layout_clue() -> void:
    var width: float = minf(440, screen_size.x - 24) if compact else 630.0
    var icon_size: float = 28.0 if compact else 44.0
    clue_icon.custom_minimum_size = Vector2.ONE * icon_size
    clue_style.content_margin_left = 12 if compact else 14
    clue_style.content_margin_right = 12 if compact else 18
    clue_label.add_theme_font_size_override("font_size", 16 if compact else 18)
    clue_label.custom_minimum_size.x = width - icon_size - 14 - clue_style.content_margin_left - clue_style.content_margin_right
    clue_label.size.x = clue_label.custom_minimum_size.x
    clue_panel.reset_size()
    clue_panel.size.x = width
    _position_clue()

func _position_clue() -> void:
    if clue_panel == null:
        return
    var portrait: bool = screen_size.y > screen_size.x
    var left: float = 12.0 if compact and not portrait else (screen_size.x - clue_panel.size.x) * 0.5
    var gap: float = 84.0 if compact else 80.0
    clue_panel.position = Vector2(left, screen_size.y - gap - clue_panel.size.y)

func _position_banner() -> void:
    if banner_box != null:
        banner_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
        banner_box.position = (screen_size - banner_box.size) * 0.5

func sync_input_hints() -> void:
    var pointer: bool = main.presentation.pointer_mode
    hints.visible = not compact and not pointer and main.state == "play"
    pointer_hint.visible = (compact or pointer) and main.state == "play"
    pointer_hint.text = "Tap to walk. Follow Stella’s home cue." if compact else "Click to walk. Hold Shift to sneak. Follow Stella’s home cue."
    if item_slot.pointer_mode != (pointer or compact):
        for slot in item_slots:
            slot.pointer_mode = pointer or compact
            slot.queue_redraw()
    var shown: String = Clues.display_text(clue_text, pointer or compact)
    if clue_label.text != shown:
        clue_label.text = shown
        _layout_clue()

# The rest of the bag sits in a row to the right of the first slot, then the effect that is running.
func _place_item_slots() -> void:
    for i in range(1, item_slots.size()):
        var slot: ItemSlot = item_slots[i]
        slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
        slot.size = item_slot.size
        slot.position = item_slot.position + Vector2((item_slot.size.x + 8.0) * float(i), 0.0)


func update_patrol_warning(progress: float, chasing: bool) -> void:
    patrol_warning.visible = main.state == "play" and progress >= 0.08
    if patrol_warning_text.text == "" or warning_chasing != chasing:
        warning_chasing = chasing
        patrol_warning_text.text = "SPOTTED! Break sight and keep moving" if chasing else "COP NOTICING — leave the beam"
        patrol_warning_text.add_theme_color_override("font_color", Style.RED if chasing else Style.GOLD)
        patrol_warning_fill.bg_color = Style.RED if chasing else Style.GOLD
    patrol_warning_bar.value = progress

# A red flash across the screen when she is hurt.
func flash_hurt() -> void:
    hurt_flash.color.a = 0.35
    main.create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.5)

# "LEVEL 3" over the level's name, fading in, holding a moment and fading out.
func show_title_card() -> void:
    (title_card.get_child(0) as Label).text = "LEVEL %d" % main.level
    (title_card.get_child(1) as Label).text = str(main.settings.title).to_upper()
    var tw: Tween = main.create_tween()
    tw.tween_property(title_card, "modulate:a", 1.0, 0.6)
    tw.tween_interval(2.4)
    tw.tween_property(title_card, "modulate:a", 0.0, 1.0)

# The slot shows while she carries something or an effect from one is running; redrawn only when that changes.
func update_item() -> void:
    var running: Dictionary = main.items.running()
    var frac: float = snappedf(float(running.get("frac", 0.0)), 0.02)
    for slot in item_slots:
        var held: String = slot.kind()
        var shown: String = held if slot.index >= 0 else str(running.get("kind", "")) + "|" + str(frac)
        slot.visible = main.state == "play" and (held != "" if slot.index >= 0 else not running.is_empty())
        if slot.visible and shown != slot.shown:
            slot.shown = shown
            slot.queue_redraw()
    _place_item_slots()

# A one-time hint (see Clues.gd): fades in on the card, stays for `seconds`, fades out.
func show_clue(kind: String, text: String, seconds: float, on_read: Callable = Callable()) -> void:
    clue_icon.kind = kind
    clue_icon.queue_redraw()
    clue_text = text
    sync_input_hints()
    _layout_clue()
    clue_style.border_color = Items.info(kind.trim_prefix("item_")).color if kind.begins_with("item_") else CLUE_TONES.get(kind, Style.GOLD)
    if clue_tween != null:
        clue_tween.kill()
    clue_up = true
    clue_layer.show()
    clue_layer.modulate.a = 0.0
    clue_tween = main.create_tween()
    clue_tween.tween_property(clue_layer, "modulate:a", 1.0, 0.25)
    clue_tween.tween_interval(seconds)
    if on_read.is_valid():
        clue_tween.tween_callback(on_read)
    clue_tween.tween_property(clue_layer, "modulate:a", 0.0, 0.6)
    clue_tween.tween_callback(func(): clue_up = false)

func dismiss_clue() -> void:
    if clue_tween != null:
        clue_tween.kill()
    clue_up = false
    clue_layer.modulate.a = 0.0

func show_toast(text: String) -> void:
    toast.text = text
    if toast_tween != null:
        toast_tween.kill()
    toast.modulate.a = 1.0
    toast_tween = main.create_tween()
    toast_tween.tween_interval(1.4)
    toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)

func show_banner(title: String, sub: String, color: Color, dim: Color) -> void:
    patrol_warning.hide()
    pointer_controls.hide()  # taps on the end screen must reach the retry handler
    pause_button.hide()
    pointer_hint.hide()
    hints.hide()
    for slot in item_slots:
        slot.hide()
    clue_layer.hide()
    toast.hide()
    banner_title.text = title
    banner_title.add_theme_color_override("font_color", color)
    banner_text = sub
    banner_sub.text = sub.replace("Press R or tap", "Tap") if compact else sub
    _position_banner()
    banner_dim.color = dim
    banner.modulate.a = 0.0
    banner.visible = true
    var fade: Tween = main.create_tween()
    fade.tween_property(banner, "modulate:a", 1.0, 0.4)
    # Keep the next-walk explanation steady and readable while the title pops in.
    await main.get_tree().process_frame
    banner_title.pivot_offset = banner_title.size * 0.5
    banner_title.scale = Vector2(1.4, 1.4)
    var pop: Tween = main.create_tween()
    pop.tween_property(banner_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    banner_sub.modulate.a = 1.0
