extends RefCounted
# Shared look for text and HUD widgets: a pixel font with a dark outline and
# drop shadow so it reads over any part of the street.

const BODY_FONT := preload("res://assets/fonts/PixelifySans.ttf")
const SpritesScript := preload("res://scripts/Sprites.gd")
const ItemsScript := preload("res://scripts/Items.gd")
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

# Keep pointer controls readable when the fixed game canvas shrinks. Web window sizes
# include device pixels; the canvas's CSS size is what determines a finger-sized target.
static func pointer_scale(viewport: Viewport) -> float:
    var factor: float = viewport.get_stretch_transform().get_scale().x
    if OS.has_feature("web"):
        var size: Vector2 = viewport.get_visible_rect().size
        var css_factor = JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');return c ? Math.min(c.clientWidth/%f,c.clientHeight/%f) : 1;})()" % [size.x, size.y], true)
        if css_factor is float or css_factor is int:
            factor = float(css_factor)
    return maxf(1.0, 1.0 / maxf(factor, 0.1))

static func pointer_button(text: String, width: float = 128.0) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(width, 64)
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 20)
    return button

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

# The little pictures that go with a clue (the card at the bottom of the screen, and the bubble over
# Stella's head): drawn in code in a square `s` pixels across centred on `c`. `a` fades them.
# kinds: question, alert, house, bin, paw, zombie
static func draw_clue_icon(item: CanvasItem, kind: String, c: Vector2, s: float, a: float = 1.0) -> void:
    var r: float = s * 0.5
    var fade := Color(1, 1, 1, a)
    if kind.begins_with("item_"):
        ItemsScript.draw_icon(item, kind.trim_prefix("item_"), c, s, a)
        return
    match kind:
        "question":
            _icon_glyph(item, "?", c, s, Color(1.0, 0.9, 0.2) * fade)
        "alert":
            _icon_glyph(item, "!", c, s, Color(1.0, 0.16, 0.12) * fade)
        "house":
            # home, as the game's own house: a pitched roof and chimney, a lit window, and the glowing door
            item.draw_rect(Rect2(c + Vector2(r * 0.34, -r * 0.82), Vector2(r * 0.26, r * 0.55)), Color("8a4a3c") * fade)  # chimney
            item.draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.1), Vector2(r * 1.32, r * 0.98)), Color("e9d7a8") * fade)  # walls
            item.draw_rect(Rect2(c + Vector2(-r * 0.66, r * 0.7), Vector2(r * 1.32, r * 0.18)), Color("b8a678") * fade)  # shaded base
            item.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.02), c + Vector2(0.0, -r * 0.92), c + Vector2(r * 0.95, -r * 0.02)]), Color("c4553f") * fade)
            item.draw_line(c + Vector2(-r * 0.95, -r * 0.02), c + Vector2(r * 0.95, -r * 0.02), Color("8f3a2c") * fade, 1.0)  # eave
            item.draw_rect(Rect2(c + Vector2(-r * 0.56, r * 0.16), Vector2(r * 0.34, r * 0.34)), Color("ffd27a") * fade)  # lit window
            item.draw_rect(Rect2(c + Vector2(r * 0.0, r * 0.12), Vector2(r * 0.5, r * 0.76)), Color(1.0, 0.82, 0.3, 0.35) * fade)  # glow
            item.draw_rect(Rect2(c + Vector2(r * 0.1, r * 0.26), Vector2(r * 0.3, r * 0.62)), Color("ffe08a") * fade)  # door
        "bin":
            item.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.35), c + Vector2(r * 0.55, -r * 0.35), c + Vector2(r * 0.42, r * 0.85), c + Vector2(-r * 0.42, r * 0.85)]), Color("8d96a6") * fade)
            item.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.62), Vector2(r * 1.4, r * 0.24)), Color("c3cad6") * fade)
            for k in [-0.22, 0.0, 0.22]:
                item.draw_line(c + Vector2(r * k, -r * 0.2), c + Vector2(r * k * 0.8, r * 0.7), Color("4b5262") * fade, 1.0)
        "paw":
            var col: Color = Color("e8d9c0") * fade
            item.draw_circle(c + Vector2(0.0, r * 0.3), r * 0.42, col)
            for p in [Vector2(-0.58, -0.1), Vector2(-0.22, -0.52), Vector2(0.22, -0.52), Vector2(0.58, -0.1)]:
                item.draw_circle(c + p * r, r * 0.2, col)
        "zombie":
            var skin: Color = Color("a9b79a") * fade
            item.draw_circle(c + Vector2(0.0, -r * 0.1), r * 0.7, skin)
            item.draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.35), Vector2(r * 0.8, r * 0.45)), skin)
            item.draw_circle(c + Vector2(-r * 0.28, -r * 0.18), r * 0.17, Color("1b2020") * fade)
            item.draw_circle(c + Vector2(r * 0.28, -r * 0.18), r * 0.17, Color("1b2020") * fade)
            for k in [-0.2, 0.0, 0.2]:
                item.draw_line(c + Vector2(r * k, r * 0.5), c + Vector2(r * k, r * 0.78), Color("1b2020") * fade, 1.0)

static func _icon_glyph(item: CanvasItem, text: String, c: Vector2, s: float, color: Color) -> void:
    var size: int = int(s * 0.95)
    var w: float = DISPLAY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    draw_world_text(item, c + Vector2(-w * 0.5, s * 0.34), text, size, color)

# A thought bubble with a clue picture in it, centred on `at`, with a tail pointing down at whoever is
# thinking it (Stella over her head while she leads the way home). `a` fades it.
static func draw_thought_bubble(item: CanvasItem, at: Vector2, kind: String, a: float = 1.0) -> void:
    var rim := Color(0.97, 0.95, 0.88, 0.9 * a)
    item.draw_colored_polygon(PackedVector2Array([at + Vector2(-4.0, 10.0), at + Vector2(4.0, 10.0), at + Vector2(0.0, 20.0)]), rim)
    SpritesScript.disc(item, at, 14.5, rim)
    SpritesScript.disc(item, at, 12.8, Color(0.07, 0.08, 0.13, 0.94 * a))
    draw_clue_icon(item, kind, at + Vector2(0.0, 0.5), 21.0, a)
