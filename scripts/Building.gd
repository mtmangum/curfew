extends Node2D
# A building drawn as an isometric box: a roof and two lit walls (south and
# east). Its footprint `rect` is also the collision wall (for the playable
# ones). Fades out when someone is standing behind it so they stay visible.
# Buildings vary by number of storeys, wall colour, ground-floor style and the
# clutter on the roof.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

const FLOOR := 24.0  # height of one storey, in screen pixels
const PALETTES := [  # south wall, east wall, roof
    [Color("2a2d42"), Color("1a1c2b"), Color("323650")],  # slate
    [Color("40292e"), Color("2a1b1f"), Color("4a3238")],  # brick
    [Color("2a3a3a"), Color("1b2727"), Color("33474a")],  # grey-green
    [Color("4a4235"), Color("322c23"), Color("5a5040")],  # sand
    [Color("232c46"), Color("161c2e"), Color("2b3556")],  # navy
]
const AWNINGS := [Color("a8403a"), Color("2f7f7a"), Color("b0873a"), Color("5a6fa8")]
const LIT := Color("e8c56a")
const SHOP_LIT := Color("f2cf86")

var rect := Rect2()
var floors := 2
var palette := 0
var shop := false  # ground floor is a shopfront with an awning
var house := false
var height := 52.0
var variant := 0  # drives the deterministic details (doors, roof units)

func setup(r: Rect2, floor_count: int, palette_index: int, is_shop: bool, is_house: bool, seed_value: int) -> void:
    rect = r
    floors = floor_count
    palette = palette_index
    shop = is_shop
    house = is_house
    variant = seed_value
    height = float(floors) * FLOOR + 4.0

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

# Rows of windows, one row per storey. `skip` is a span along the wall to leave
# clear (for a door) on the ground floor.
func _windows(origin: Vector2, along: Vector2, length: float, seed_: int, dark: Color, skip: Vector2, shop_front: bool) -> void:
    for f in floors:
        var z0: float = float(f) * FLOOR + 6.0
        if f == 0 and shop_front:
            # Wide shop windows, mostly lit.
            var u := 8.0
            var n := 0
            while u + 28.0 < length - 8.0:
                if not (u + 28.0 > skip.x - 3.0 and u < skip.y + 3.0):
                    var on: bool = (n * 7 + seed_) % 5 != 0
                    draw_colored_polygon(_quad(origin, along, u, u + 28.0, 4.0, 16.0), SHOP_LIT if on else dark)
                u += 38.0
                n += 1
            continue
        var u2 := 12.0
        var col := 0
        while u2 < length - 14.0:
            var skipped: bool = f == 0 and u2 + 9.0 > skip.x - 3.0 and u2 < skip.y + 3.0
            if not skipped:
                var lit: bool = (col * 7 + f * 13 + seed_) % 5 == 0
                draw_colored_polygon(_quad(origin, along, u2, u2 + 9.0, z0, z0 + 11.0), LIT if lit else dark)
            u2 += 22.0
            col += 1

# A small box on the roof: an air-conditioning unit, a stairwell, a tank.
func _roof_box(x: float, y: float, w: float, d: float, h: float, base_z: float, wall_s: Color, wall_e: Color, top: Color) -> void:
    var z1: float = base_z + h
    draw_colored_polygon(PackedVector2Array([
        _p(x, y + d, base_z), _p(x + w, y + d, base_z), _p(x + w, y + d, z1), _p(x, y + d, z1)]), wall_s)
    draw_colored_polygon(PackedVector2Array([
        _p(x + w, y + d, base_z), _p(x + w, y, base_z), _p(x + w, y, z1), _p(x + w, y + d, z1)]), wall_e)
    draw_colored_polygon(PackedVector2Array([
        _p(x, y, z1), _p(x + w, y, z1), _p(x + w, y + d, z1), _p(x, y + d, z1)]), top)

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    var r := rect
    var h := height
    var pal: Array = PALETTES[palette % PALETTES.size()]
    var wall_s: Color = pal[0]
    var wall_e: Color = pal[1]
    var roof: Color = pal[2]
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
    # Ledges between storeys, so the number of floors reads at a glance.
    for f in range(1, floors):
        var z: float = float(f) * FLOOR
        draw_line(_p(r.position.x, r.end.y, z), _p(r.end.x, r.end.y, z), wall_s.darkened(0.25), 1.0)
        draw_line(_p(r.end.x, r.end.y, z), _p(r.end.x, r.position.y, z), wall_e.darkened(0.25), 1.0)

    # Where the front door goes along the south wall.
    var door_u: float = r.size.x - 120.0 if house else 16.0 + float((variant * 37) % int(maxf(r.size.x - 50.0, 1.0)))
    var door_w: float = 40.0 if house else 11.0
    var seed_ := int(r.position.x * 0.37 + r.position.y * 0.91) + variant
    var south := Vector2(r.position.x, r.end.y)
    var east := Vector2(r.end.x, r.end.y)
    _windows(south, Vector2.RIGHT, r.size.x, seed_, dark, Vector2(door_u, door_u + door_w), shop and not house)
    _windows(east, Vector2.UP, r.size.y, seed_ + 3, dark, Vector2(-100.0, -100.0), false)

    # Shop awning over the ground-floor windows.
    if shop and not house:
        var awning: Color = AWNINGS[variant % AWNINGS.size()]
        draw_colored_polygon(_quad(south, Vector2.RIGHT, 3.0, r.size.x - 3.0, 18.0, 22.0), awning)
        draw_line(Sprites.proj(south + Vector2(3.0, 0.0), 18.0), Sprites.proj(south + Vector2(r.size.x - 3.0, 0.0), 18.0), awning.darkened(0.35), 1.0)

    # Ordinary door.
    if not house:
        var door := south + Vector2(door_u, 0.0)
        var fill: Color = Color("2b2216") if shop else Color("0b0c12")
        draw_colored_polygon(_quad(door, Vector2.RIGHT, 0.0, door_w, 0.0, 15.0), fill)
        draw_polyline(PackedVector2Array([
            Sprites.proj(door, 0.0), Sprites.proj(door, 15.0),
            Sprites.proj(door + Vector2(door_w, 0.0), 15.0), Sprites.proj(door + Vector2(door_w, 0.0), 0.0)]),
            wall_s.lightened(0.3), 1.0)

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

    # Rooftop clutter, placed deterministically and drawn far-to-near.
    if not house:
        var units: Array = []
        var count: int = 1 + variant % 3
        for k in count:
            var bw: float = 14.0 + float((variant * 5 + k * 11) % 13)
            var bd: float = 10.0 + float((variant * 3 + k * 7) % 9)
            var bh: float = 5.0 + float((variant + k * 5) % 7)
            var fx: float = float((variant * 13 + k * 29) % 100) / 100.0
            var fy: float = float((variant * 7 + k * 41) % 100) / 100.0
            if inner.size.x > bw + 12.0 and inner.size.y > bd + 12.0:
                units.append([inner.position.x + 6.0 + fx * (inner.size.x - bw - 12.0),
                    inner.position.y + 6.0 + fy * (inner.size.y - bd - 12.0), bw, bd, bh])
        units.sort_custom(func(a: Array, b: Array) -> bool: return a[0] + a[1] < b[0] + b[1])
        for u in units:
            _roof_box(u[0], u[1], u[2], u[3], u[4], h, wall_s.lightened(0.05), wall_e, roof.lightened(0.12))

    # Light catching the vertical corner and the base.
    draw_line(_p(r.end.x, r.end.y, 0.0), _p(r.end.x, r.end.y, h), wall_s.lightened(0.2), 1.0)
    draw_line(_p(r.position.x, r.end.y, 0.0), _p(r.end.x, r.end.y, 0.0), Color(0, 0, 0, 0.5), 1.0)

    if house:
        var door_pos := Vector2(r.end.x - 120.0, r.end.y)
        draw_colored_polygon(_quad(door_pos, Vector2.RIGHT, 0.0, 40.0, 0.0, 26.0), Color("ffd27a"))
        draw_polyline(PackedVector2Array([
            Sprites.proj(door_pos, 0.0), Sprites.proj(door_pos, 26.0),
            Sprites.proj(door_pos + Vector2(40, 0), 26.0), Sprites.proj(door_pos + Vector2(40, 0), 0.0)]),
            Color("a8793a"), 1.0)
        Style.draw_world_text(self, Sprites.proj(door_pos + Vector2(7, 0), 36.0), "HOME", 8, Style.GOLD)
