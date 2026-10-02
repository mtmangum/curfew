extends RefCounted
# Shared look for text and HUD widgets: a pixel font with a dark outline and
# drop shadow so it reads over any part of the street.

const BODY_FONT := preload("res://assets/fonts/PixelifySans.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/Silkscreen-Bold.ttf")

const INK := Color("e9e4d4")
const DIM := Color("9aa0b4")
const GOLD := Color("ffd27a")
const RED := Color("ff5a4d")
const OUTLINE := Color("0a0b12")

# A Theme so every Control under the HUD picks up the pixel font.
static func theme() -> Theme:
    var t := Theme.new()
    t.default_font = BODY_FONT
    t.default_font_size = 20
    t.set_color("font_color", "Label", INK)
    t.set_color("font_outline_color", "Label", OUTLINE)
    t.set_constant("outline_size", "Label", 5)
    t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
    t.set_constant("shadow_offset_x", "Label", 0)
    t.set_constant("shadow_offset_y", "Label", 2)
    t.set_color("font_color", "Button", INK)
    t.set_color("font_pressed_color", "Button", GOLD)
    t.set_color("font_hover_color", "Button", Color.WHITE)
    t.set_color("font_outline_color", "Button", OUTLINE)
    t.set_constant("outline_size", "Button", 4)
    t.set_stylebox("normal", "Button", _box(Color(0.07, 0.08, 0.13, 0.82), Color("3a4056")))
    t.set_stylebox("hover", "Button", _box(Color(0.1, 0.11, 0.18, 0.9), Color("5a6180")))
    t.set_stylebox("pressed", "Button", _box(Color(0.35, 0.26, 0.1, 0.92), GOLD))
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    return t

static func _box(fill: Color, border: Color, bottom: int = 2) -> StyleBoxFlat:
    var b := StyleBoxFlat.new()
    b.bg_color = fill
    b.border_color = border
    b.set_border_width_all(2)
    b.border_width_bottom = bottom
    b.set_corner_radius_all(3)
    b.content_margin_left = 10
    b.content_margin_right = 10
    b.content_margin_top = 4
    b.content_margin_bottom = 4
    return b

# A label in the display font (big titles, signs).
static func display_label(text: String, size: int, color: Color, outline: int = 8) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", DISPLAY_FONT)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", OUTLINE)
    l.add_theme_constant_override("outline_size", outline)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
    l.add_theme_constant_override("shadow_offset_y", 4)
    return l

# A small keyboard-key shaped tag, e.g. [W] or [SHIFT].
static func keycap(text: String) -> Control:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _box(Color("1d2030"), Color("6a7190"), 4))
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", DISPLAY_FONT)
    l.add_theme_font_size_override("font_size", 16)
    l.add_theme_constant_override("outline_size", 0)
    l.add_theme_constant_override("shadow_offset_y", 0)
    l.add_theme_color_override("font_color", INK)
    p.add_child(l)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return p

# keys + a caption, e.g. [W][A][S][D] move
static func hint(keys: Array, caption: String) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for k in keys:
        row.add_child(keycap(k))
    var l := Label.new()
    l.text = " " + caption
    l.add_theme_color_override("font_color", DIM)
    row.add_child(l)
    return row

# Text drawn inside the world (HOME sign, "?" over a cop): fill plus outline.
static func draw_world_text(item: CanvasItem, pos: Vector2, text: String, size: int, color: Color) -> void:
    item.draw_string_outline(DISPLAY_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, OUTLINE)
    item.draw_string(DISPLAY_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
