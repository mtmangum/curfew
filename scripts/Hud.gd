extends RefCounted
# The heads-up display, built over the fog (canvas layer 2): the danger tint and hurt flash, the
# life bar, the level and the objective, the hint strip, the map, the toast line, the level's
# title card, and the end-of-run banner. (Main owns one: `main.hud`; Main.minimap is the map it
# builds.)

const MiniMapScript := preload("res://scripts/MiniMap.gd")
const Style := preload("res://scripts/Style.gd")
const Items := preload("res://scripts/Items.gd")

# The border colour of the clue card for each picture.
const CLUE_TONES := {"question": Color("ffd23a"), "alert": Color("ff3a2c"), "house": Color("ffd27a"),
        "bin": Color("8d96a6"), "paw": Color("e8d9c0"), "zombie": Color("a9b79a")}

# The slot in the corner for the found item she carries (Items.gd): its picture, the key to use it, and, while an
# effect is running, how much of it is left. Tapping it uses the item.
class ItemSlot extends Control:
    var main
    var shown := ""      # what the slot last drew
    var frac := -1.0     # and the effect's bar

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            main.use_item()
            accept_event()

    func _draw() -> void:
        var tone: Color = Color(1, 1, 1, 0.25)
        var running: Dictionary = main.items.running()
        if main.carried != "":
            tone = Items.info(main.carried).color
        elif not running.is_empty():
            tone = Items.info(running.kind).color
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.09, 0.78))
        draw_rect(Rect2(Vector2.ZERO, size), Color(tone.r, tone.g, tone.b, 0.9), false, 2.0)
        if main.carried != "":
            Items.draw_icon(self, main.carried, Vector2(size.x * 0.5, size.y * 0.46), size.x * 0.62)
            var cap := Rect2(size.x - 17.0, size.y - 17.0, 16.0, 16.0)
            draw_rect(cap, Color(0.9, 0.88, 0.8))
            draw_string(Style.DISPLAY_FONT, cap.position + Vector2(3.0, 13.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.1, 0.14))
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
var item_slot: ItemSlot
var banner: Control
var banner_dim: ColorRect
var banner_title: Label
var banner_sub: Label

func _init(game) -> void:
    main = game

func build() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 2  # over the level's fog (layer 1)
    main.add_child(layer)
    var ui := Control.new()
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
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

    var version := Label.new()
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
    row.add_child(Style.hint(["TAB"], "keys"))
    row.add_child(Style.hint(["M"], "map"))
    row.add_child(Style.hint(["N"], "sound"))
    row.add_child(Style.hint(["P"], "pause"))
    row.add_child(Style.hint(["R"], "restart"))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 18)
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(gap)
    hints = center

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

    # The clue card: a picture and a line or two just above the hint strip, for the one-time hints.
    clue_layer = VBoxContainer.new()
    clue_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    (clue_layer as VBoxContainer).alignment = BoxContainer.ALIGNMENT_END
    clue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clue_layer.modulate.a = 0.0
    ui.add_child(clue_layer)
    var clue_center := CenterContainer.new()
    clue_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clue_layer.add_child(clue_center)
    var clue_panel := PanelContainer.new()
    clue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    clue_center.add_child(clue_panel)
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
    var clue_gap := Control.new()
    clue_gap.custom_minimum_size = Vector2(0, 80)  # clear of the hint strip
    clue_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clue_layer.add_child(clue_gap)

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
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 18)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(box)
    banner_title = Style.display_label("", 80, Style.RED, 12)
    banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(banner_title)
    banner_sub = Label.new()
    banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_sub.add_theme_font_size_override("font_size", 26)
    box.add_child(banner_sub)

# Each frame: the red tint grows with how close any cop is to spotting her, and the hints and then
# the objective fade once the player has got going (`progress` is 1 when the hints should start
# to go, 2 for the objective).
func update(worst: float, progress: float) -> void:
    danger.color.a = worst * 0.35
    hints.modulate.a = clampf(1.0 - (progress - 1.0) / 0.25, 0.0, 1.0)
    objective.modulate.a = clampf(1.0 - (progress - 2.0) / 0.25, 0.0, 1.0)

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
    var shown: String = main.carried + "|" + str(running.get("kind", ""))
    var frac: float = snappedf(float(running.get("frac", 0.0)), 0.02)
    item_slot.visible = shown != "|"
    if item_slot.visible and (shown != item_slot.shown or frac != item_slot.frac):
        item_slot.shown = shown
        item_slot.frac = frac
        item_slot.queue_redraw()

# A one-time hint (see Clues.gd): fades in on the card, stays for `seconds`, fades out.
func show_clue(kind: String, text: String, seconds: float) -> void:
    clue_icon.kind = kind
    clue_icon.queue_redraw()
    clue_label.text = text
    clue_style.border_color = Items.info(kind.trim_prefix("item_")).color if kind.begins_with("item_") else CLUE_TONES.get(kind, Style.GOLD)
    if clue_tween != null:
        clue_tween.kill()
    clue_up = true
    clue_layer.modulate.a = 0.0
    clue_tween = main.create_tween()
    clue_tween.tween_property(clue_layer, "modulate:a", 1.0, 0.25)
    clue_tween.tween_interval(seconds)
    clue_tween.tween_property(clue_layer, "modulate:a", 0.0, 0.6)
    clue_tween.tween_callback(func(): clue_up = false)

func show_toast(text: String) -> void:
    toast.text = text
    if toast_tween != null:
        toast_tween.kill()
    toast.modulate.a = 1.0
    toast_tween = main.create_tween()
    toast_tween.tween_interval(1.4)
    toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)

func show_banner(title: String, sub: String, color: Color, dim: Color) -> void:
    banner_title.text = title
    banner_title.add_theme_color_override("font_color", color)
    banner_sub.text = sub
    banner_dim.color = dim
    banner.modulate.a = 0.0
    banner.visible = true
    var fade: Tween = main.create_tween()
    fade.tween_property(banner, "modulate:a", 1.0, 0.4)
    # Title pops in; the prompt blinks.
    await main.get_tree().process_frame
    banner_title.pivot_offset = banner_title.size * 0.5
    banner_title.scale = Vector2(1.4, 1.4)
    var pop: Tween = main.create_tween()
    pop.tween_property(banner_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var blink: Tween = main.create_tween().set_loops()
    blink.tween_property(banner_sub, "modulate:a", 0.35, 0.7)
    blink.tween_property(banner_sub, "modulate:a", 1.0, 0.7)
