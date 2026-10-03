extends "res://scripts/Building.gd"
# Street furniture and junk: dumpsters, crates, barricades, hydrants, mailboxes,
# benches, phone booths, trees, traffic cones and planters. Each is a small
# isometric box (or a few), drawn and depth-sorted like a building, and solid to walk
# into. They are low or thin enough that light and sight pass over them.

enum Kind {DUMPSTER, CRATES, BARRICADE, HYDRANT, MAILBOX, BENCH, PHONE, TREE, CONES, PLANTER, FOUNTAIN}

# Footprint (along x) and overall height of each kind.
const SIZES := {
    Kind.DUMPSTER: Vector2(36, 18),
    Kind.CRATES: Vector2(18, 18),
    Kind.BARRICADE: Vector2(34, 6),
    Kind.HYDRANT: Vector2(7, 7),
    Kind.MAILBOX: Vector2(9, 9),
    Kind.BENCH: Vector2(30, 10),
    Kind.PHONE: Vector2(12, 12),
    Kind.TREE: Vector2(8, 8),
    Kind.CONES: Vector2(24, 8),
    Kind.PLANTER: Vector2(22, 12),
    Kind.FOUNTAIN: Vector2(34, 34),
}
const HEIGHTS := {
    Kind.DUMPSTER: 20.0, Kind.CRATES: 24.0, Kind.BARRICADE: 14.0, Kind.HYDRANT: 16.0,
    Kind.MAILBOX: 22.0, Kind.BENCH: 16.0, Kind.PHONE: 44.0, Kind.TREE: 60.0,
    Kind.CONES: 10.0, Kind.PLANTER: 18.0, Kind.FOUNTAIN: 22.0,
}

var kind: int = Kind.DUMPSTER
var marked := false  # a hydrant Stella has already used

static func size_of(k: int) -> Vector2:
    return SIZES[k]

func setup_object(r: Rect2, k: int, seed_value: int) -> void:
    rect = r
    kind = k
    variant = seed_value
    floors = 0
    height = HEIGHTS[k]
    update_screen_box()

# A tree's crown spreads well beyond its trunk, so widen the on-screen box for sorting.
func update_screen_box() -> void:
    super.update_screen_box()
    if kind == Kind.TREE:
        screen_box = screen_box.grow_individual(18.0, 4.0, 18.0, 0.0)

# A solid box: south and east faces and a top.
func _slab(x: float, y: float, w: float, d: float, h: float, z: float, c: Color) -> void:
    _roof_box(x, y, w, d, h, z, c, c.darkened(0.32), c.lightened(0.14))

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    var r := rect
    var cx: float = r.get_center().x
    var cy: float = r.get_center().y
    # Soft shadow on the ground.
    var sh := r.grow(1.5)
    draw_colored_polygon(PackedVector2Array([
        _p(sh.position.x, sh.position.y, 0.0), _p(sh.end.x, sh.position.y, 0.0),
        _p(sh.end.x, sh.end.y, 0.0), _p(sh.position.x, sh.end.y, 0.0)]), Color(0, 0, 0, 0.3))
    match kind:
        Kind.DUMPSTER:
            var paint: Color = [Color("2f5a43"), Color("2f4f6a"), Color("6a3f2c")][variant % 3]
            _slab(r.position.x, r.position.y, r.size.x, r.size.y, 15.0, 3.0, paint)
            _slab(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, r.size.y + 2.0, 3.0, 18.0, paint.darkened(0.45))
            # a stripe and two small wheels on the long face
            draw_colored_polygon(_quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, 3.0, r.size.x - 3.0, 9.0, 11.0), paint.lightened(0.25))
            for u in [5.0, r.size.x - 5.0]:
                draw_colored_polygon(_quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, u - 1.5, u + 1.5, 0.0, 3.0), Color("0b0c10"))
        Kind.CRATES:
            var wood := Color("6b4a2e")
            _slab(r.position.x, r.position.y + 1.0, 16.0, 16.0, 12.0, 0.0, wood)
            _slab(r.position.x + 3.0, r.position.y + 4.0, 11.0, 11.0, 10.0, 12.0, wood.lightened(0.1))
            draw_line(_p(r.position.x, r.end.y - 1.0, 6.0), _p(r.position.x + 16.0, r.end.y - 1.0, 6.0), wood.darkened(0.5), 1.0)
            draw_line(_p(r.position.x + 3.0, r.end.y - 3.0, 17.0), _p(r.position.x + 14.0, r.end.y - 3.0, 17.0), wood.darkened(0.5), 1.0)
        Kind.BARRICADE:
            var red := Color("b13a34")
            var white := Color("e6e1d4")
            for post in [r.position.x + 1.0, r.end.x - 3.0]:
                _slab(post, r.position.y + 1.0, 2.0, 2.0, 12.0, 0.0, Color("3a3e4a"))
            var seg := 0
            var u := r.position.x
            while u < r.end.x - 0.5:
                var w: float = minf(6.0, r.end.x - u)
                _slab(u, r.position.y + 1.0, w, 4.0, 5.0, 8.0, red if seg % 2 == 0 else white)
                u += 6.0
                seg += 1
        Kind.HYDRANT:
            var red2 := Color("b8322d")
            _slab(cx - 2.0, cy - 2.0, 4.0, 4.0, 11.0, 0.0, red2)
            _slab(cx - 3.0, cy - 3.0, 6.0, 6.0, 3.0, 11.0, red2.darkened(0.1))
            _slab(cx - 5.0, cy - 1.0, 3.0, 2.0, 3.0, 6.0, red2.lightened(0.1))
            _slab(cx + 2.0, cy - 1.0, 3.0, 2.0, 3.0, 6.0, red2.lightened(0.1))
        Kind.MAILBOX:
            var blue := Color("2b4f8f")
            _slab(cx - 1.5, cy - 1.5, 3.0, 3.0, 12.0, 0.0, Color("4a5060"))
            _slab(cx - 4.0, cy - 4.0, 8.0, 8.0, 8.0, 12.0, blue)
            _slab(cx - 4.0, cy - 4.0, 8.0, 8.0, 2.0, 20.0, blue.darkened(0.2))
            draw_colored_polygon(_quad(Vector2(cx - 4.0, cy + 4.0), Vector2.RIGHT, 1.5, 6.5, 15.0, 16.5), Color("0e1320"))
        Kind.BENCH:
            var wood2 := Color("5d4128")
            for leg in [r.position.x + 2.0, r.end.x - 4.0]:
                _slab(leg, r.position.y + 3.0, 2.0, 4.0, 6.0, 0.0, Color("2f333f"))
            _slab(r.position.x, r.position.y + 2.0, r.size.x, 7.0, 3.0, 6.0, wood2)
            _slab(r.position.x, r.position.y, r.size.x, 2.0, 7.0, 9.0, wood2.darkened(0.15))
        Kind.PHONE:
            var frame := Color("2c3a58")
            _slab(r.position.x, r.position.y, r.size.x, r.size.y, 40.0, 0.0, frame)
            _slab(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, r.size.y + 2.0, 4.0, 40.0, frame.darkened(0.3))
            var glass := Color("7fb6d6") if variant % 2 == 0 else Color("e8c56a")
            draw_colored_polygon(_quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, 2.0, r.size.x - 2.0, 6.0, 36.0), Color(glass.r, glass.g, glass.b, 0.55))
            draw_colored_polygon(_quad(Vector2(r.end.x, r.end.y), Vector2.UP, 2.0, r.size.y - 2.0, 6.0, 36.0), Color(glass.r, glass.g, glass.b, 0.3))
        Kind.TREE:
            _slab(cx - 2.0, cy - 2.0, 4.0, 4.0, 26.0, 0.0, Color("4a3526"))
            _crown(cx, cy)
        Kind.CONES:
            for i in 3:
                var ox: float = r.position.x + 2.0 + float(i) * 9.0
                _slab(ox - 1.0, r.position.y + 1.0, 6.0, 6.0, 1.0, 0.0, Color("232630"))
                _slab(ox + 0.5, r.position.y + 2.5, 3.0, 3.0, 7.0, 1.0, Color("e0742c"))
                _slab(ox + 0.2, r.position.y + 2.2, 3.6, 3.6, 1.6, 4.0, Color("e8e4da"))
        Kind.FOUNTAIN:
            _fountain(r)
        Kind.PLANTER:
            var stone := Color("5a4f46")
            _slab(r.position.x, r.position.y, r.size.x, r.size.y, 8.0, 0.0, stone)
            draw_colored_polygon(PackedVector2Array([
                _p(r.position.x + 1.5, r.position.y + 1.5, 8.0), _p(r.end.x - 1.5, r.position.y + 1.5, 8.0),
                _p(r.end.x - 1.5, r.end.y - 1.5, 8.0), _p(r.position.x + 1.5, r.end.y - 1.5, 8.0)]), Color("2a2118"))
            var bush: Vector2 = Sprites.proj(Vector2(cx, cy), 12.0)
            draw_circle(bush + Vector2(-4, 1), 5.0, Color("1f3a2d"))
            draw_circle(bush + Vector2(4, 1), 5.0, Color("1f3a2d"))
            draw_circle(bush + Vector2(0, -3), 6.0, Color("2a5038"))
            draw_circle(bush + Vector2(-2, -5), 3.0, Color("3f7050"))

# A stone basin with water and a central jet, for the plazas.
func _fountain(r: Rect2) -> void:
    var stone := Color("6a6f80")
    _slab(r.position.x, r.position.y, r.size.x, r.size.y, 8.0, 0.0, stone)
    var water := Color("5b8fb8")
    draw_colored_polygon(PackedVector2Array([
        _p(r.position.x + 3.0, r.position.y + 3.0, 8.0), _p(r.end.x - 3.0, r.position.y + 3.0, 8.0),
        _p(r.end.x - 3.0, r.end.y - 3.0, 8.0), _p(r.position.x + 3.0, r.end.y - 3.0, 8.0)]), water)
    var cx: float = r.get_center().x
    var cy: float = r.get_center().y
    _slab(cx - 2.0, cy - 2.0, 4.0, 4.0, 10.0, 8.0, stone.lightened(0.15))
    var top: Vector2 = Sprites.proj(Vector2(cx, cy), 20.0)
    draw_circle(top + Vector2(0, -2), 2.0, Color(0.85, 0.93, 1.0, 0.85))
    draw_circle(top + Vector2(-5, 3), 1.5, Color(0.85, 0.93, 1.0, 0.7))
    draw_circle(top + Vector2(5, 3), 1.5, Color(0.85, 0.93, 1.0, 0.7))
    draw_circle(top + Vector2(0, 6), 2.5, Color(0.85, 0.93, 1.0, 0.45))

# A leafy crown, in pixel-ish clumps of three greens.
func _crown(cx: float, cy: float) -> void:
    var base: Vector2 = Sprites.proj(Vector2(cx, cy), 36.0)
    var dark := Color("1b3528")
    var mid := Color("2a5038")
    var light := Color("3f7050")
    var spots: Array = [Vector2(-9, 4), Vector2(9, 4), Vector2(0, -2), Vector2(-5, -10), Vector2(6, -9), Vector2(0, -15)]
    for i in spots.size():
        var s: Vector2 = spots[i]
        var wobble := Vector2(float((variant * 7 + i * 5) % 5) - 2.0, float((variant * 3 + i * 7) % 4) - 1.5)
        var rad: float = 9.0 - float(i % 3)
        draw_circle(base + s + wobble, rad, dark)
    for i in spots.size():
        var s2: Vector2 = spots[i]
        var rad2: float = 7.0 - float(i % 3)
        draw_circle(base + s2 + Vector2(-1.5, -2.0), rad2, mid)
    for i in range(0, spots.size(), 2):
        draw_circle(base + spots[i] + Vector2(-3.0, -4.5), 3.5, light)
