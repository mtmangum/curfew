extends Node2D
# A building drawn as an isometric box: a roof and two lit walls (south and
# east). Its footprint `rect` is also the collision wall. Fades out when
# someone is standing behind it so they stay visible.

const Sprites := preload("res://scripts/Sprites.gd")

var rect := Rect2()
var height := 60.0
var house := false

func _ready() -> void:
    queue_redraw()

func _p(x: float, y: float, z: float) -> Vector2:
    return Sprites.proj(Vector2(x, y), z)

# Screen-space outline (relative to the world origin) for occlusion tests.
func silhouette() -> PackedVector2Array:
    var r := rect
    return PackedVector2Array([
        _p(r.position.x, r.position.y, height),
        _p(r.end.x, r.position.y, height),
        _p(r.end.x, r.position.y, 0.0),
        _p(r.end.x, r.end.y, 0.0),
        _p(r.position.x, r.end.y, 0.0),
        _p(r.position.x, r.end.y, height),
    ])

# A rectangle on a wall. `along` is the wall's direction on the ground plane.
func _quad(origin: Vector2, along: Vector2, u0: float, u1: float, z0: float, z1: float) -> PackedVector2Array:
    var a: Vector2 = origin + along * u0
    var b: Vector2 = origin + along * u1
    return PackedVector2Array([
        Sprites.proj(a, z0), Sprites.proj(b, z0), Sprites.proj(b, z1), Sprites.proj(a, z1),
    ])

func _windows(origin: Vector2, along: Vector2, length: float, seed_: int, lit: Color, dark: Color) -> void:
    var u := 12.0
    var col := 0
    while u < length - 14.0:
        var z := 10.0
        var row := 0
        while z + 12.0 < height - 6.0:
            var on: bool = (col * 7 + row * 13 + seed_) % 5 == 0
            draw_colored_polygon(_quad(origin, along, u, u + 9.0, z, z + 11.0), lit if on else dark)
            z += 20.0
            row += 1
        u += 22.0
        col += 1

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    var r := rect
    var h := height
    var wall_s := Color("2a2d42")
    var wall_e := Color("1a1c2b")
    var roof := Color("323650")
    var lit := Color("e8c56a")
    var dark := Color("11131b")
    if house:
        wall_s = Color("4a3434")
        wall_e = Color("33231f")
        roof = Color("5a3d3a")
        dark = Color("1d1414")

    # South wall (faces the lower left) and east wall (faces the lower right).
    draw_colored_polygon(PackedVector2Array([
        _p(r.position.x, r.end.y, 0.0), _p(r.end.x, r.end.y, 0.0),
        _p(r.end.x, r.end.y, h), _p(r.position.x, r.end.y, h)]), wall_s)
    draw_colored_polygon(PackedVector2Array([
        _p(r.end.x, r.end.y, 0.0), _p(r.end.x, r.position.y, 0.0),
        _p(r.end.x, r.position.y, h), _p(r.end.x, r.end.y, h)]), wall_e)

    var seed_ := int(r.position.x * 0.37 + r.position.y * 0.91)
    _windows(Vector2(r.position.x, r.end.y), Vector2.RIGHT, r.size.x, seed_, lit, dark)
    _windows(Vector2(r.end.x, r.end.y), Vector2.UP, r.size.y, seed_ + 3, lit * Color(0.9, 0.9, 0.9), dark)

    # Roof with a parapet edge and a darker inset.
    var top := PackedVector2Array([
        _p(r.position.x, r.position.y, h), _p(r.end.x, r.position.y, h),
        _p(r.end.x, r.end.y, h), _p(r.position.x, r.end.y, h)])
    draw_colored_polygon(top, roof)
    var inner := r.grow(-5.0)
    draw_colored_polygon(PackedVector2Array([
        _p(inner.position.x, inner.position.y, h), _p(inner.end.x, inner.position.y, h),
        _p(inner.end.x, inner.end.y, h), _p(inner.position.x, inner.end.y, h)]), roof.darkened(0.25))
    var outline := top.duplicate()
    outline.append(top[0])
    draw_polyline(outline, roof.lightened(0.25), 1.0)
    # Light catching the vertical corner and the base.
    draw_line(_p(r.end.x, r.end.y, 0.0), _p(r.end.x, r.end.y, h), wall_s.lightened(0.2), 1.0)
    draw_line(_p(r.position.x, r.end.y, 0.0), _p(r.end.x, r.end.y, 0.0), Color(0, 0, 0, 0.5), 1.0)

    if house:
        var door_x: float = r.end.x - 120.0
        var door := Vector2(door_x, r.end.y)
        draw_colored_polygon(_quad(door, Vector2.RIGHT, 0.0, 40.0, 0.0, 26.0), Color("ffd27a"))
        draw_polyline(PackedVector2Array([
            Sprites.proj(door, 0.0), Sprites.proj(door, 26.0),
            Sprites.proj(door + Vector2(40, 0), 26.0), Sprites.proj(door + Vector2(40, 0), 0.0)]),
            Color("a8793a"), 1.0)
        draw_string(ThemeDB.fallback_font, Sprites.proj(door + Vector2(8, 0), 36.0), "HOME",
            HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffd27a"))
