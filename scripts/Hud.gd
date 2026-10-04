extends RefCounted
# The heads-up display, built over the fog (canvas layer 2): the danger tint and hurt flash, the
# life bar, the level and the objective, the hint strip, the map, the toast line, the level's
# title card, and the end-of-run banner. (Main owns one: `main.hud`; Main.minimap is the map it
# builds.)

const MiniMapScript := preload("res://scripts/MiniMap.gd")
const Style := preload("res://scripts/Style.gd")

var main
var danger: ColorRect
var hurt_flash: ColorRect
var objective: Label
var level_label: Label
var hints: Control
var toast: Label
var toast_tween: Tween
var title_card: VBoxContainer  # "LEVEL 3 / RAINY NIGHT" as a level starts
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
