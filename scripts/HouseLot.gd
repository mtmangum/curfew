extends RefCounted
# Home: a house, not a block. The lot (the Building's rect, which is what stops people walking in) holds a lawn with a
# picket fence round it and a gate in front of the pavement she is heading for (the home zone), a stone path from the
# gate to the front door, bushes, a mailbox, and at the back a low house with a pitched tile roof, a chimney with smoke
# and lit windows. A name board hangs over the gate. (Building._draw calls paint for the house; the pitched roof is
# Roofs._house.)

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")
const RoofsScript := preload("res://scripts/Roofs.gd")

const WALL_H := 34.0
const FENCE_H := 7.0
const GATE_FROM := 130.0   # the gate spans from this far to this far in from the lot's east edge (the home zone is in front of it)
const GATE_TO := 70.0
const DOOR_FROM := 109.0   # the door, in from the east edge
const DOOR_TO := 91.0
const DOOR_H := 25.0

const LAWN := Color("2c4a35")
const LAWN_DARK := Color("203a2b")
const PATH := Color("a79c88")
const WALL_S := Color("d8c39b")
const WALL_E := Color("a8946f")
const WOOD := Color("e8e2d4")
const WOOD_SHADE := Color("b8b2a4")
const WINDOW := Color("ffcf70")
const FRAME := Color("f2eadb")

# The house itself, at the back of the lot and toward the east, in front of which the path runs to the gate.
static func body(lot: Rect2) -> Rect2:
    return Rect2(lot.end.x - 164.0, lot.end.y - 196.0, 132.0, 86.0)

# Windows as [wall, u0, u1, z0, z1]: "s" is the south wall, along it from the house's west end; "e" the east wall, along it
# from its south end going north.
static func windows() -> Array:
    return [["s", 10.0, 36.0, 8.0, 24.0], ["s", 96.0, 122.0, 8.0, 24.0], ["e", 14.0, 38.0, 8.0, 24.0], ["e", 50.0, 74.0, 8.0, 24.0]]

# The lit windows as glows for the dark (the same shape Building.lit_glows gives): [[centre, radius, is a shop's], ...].
static func glows(b) -> Array:
    var out: Array = []
    var hb: Rect2 = body(b.rect)
    for w in windows():
        var mid: Vector2
        if w[0] == "s":
            mid = Vector2(hb.position.x + (w[1] + w[2]) * 0.5, hb.end.y)
        else:
            mid = Vector2(hb.end.x, hb.end.y - (w[1] + w[2]) * 0.5)
        out.append([Sprites.proj(mid, (w[3] + w[4]) * 0.5), (w[2] - w[1]) * 0.8 * 0.5 + 6.0, false])
    return out

static func _ground(b, pts: Array, col: Color) -> void:
    var poly := PackedVector2Array()
    for q in pts:
        poly.append(b._p(q.x, q.y, 0.0))
    Sprites.fill(b, poly, col)

static func _wall(b, origin: Vector2, along: Vector2, u0: float, u1: float, z0: float, z1: float, col: Color) -> void:
    Sprites.fill(b, b._quad(origin, along, u0, u1, z0, z1), col)

static func paint(b) -> void:
    b.draw_set_transform_matrix(Sprites.UP)
    var r: Rect2 = b.rect
    var hb: Rect2 = body(r)
    # the lawn, with a darker verge round the edge, and the path from the door to the gate
    _ground(b, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)], LAWN_DARK)
    var inner: Rect2 = r.grow(-4.0)
    _ground(b, [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)], LAWN)
    var door_x: float = r.end.x - (DOOR_FROM + DOOR_TO) * 0.5
    _ground(b, [Vector2(door_x - 9.0, hb.end.y), Vector2(door_x + 9.0, hb.end.y), Vector2(door_x + 9.0, r.end.y), Vector2(door_x - 9.0, r.end.y)], PATH)
    for k in 6:  # the stones' joints
        var yy: float = lerpf(hb.end.y, r.end.y, float(k + 1) / 7.0)
        b.draw_line(b._p(door_x - 9.0, yy, 0.0), b._p(door_x + 9.0, yy, 0.0), PATH.darkened(0.3), 1.0)
    # the house: south wall, east wall, windows, door, porch roof
    var south := Vector2(hb.position.x, hb.end.y)
    var east := Vector2(hb.end.x, hb.end.y)
    _wall(b, south, Vector2.RIGHT, 0.0, hb.size.x, 0.0, WALL_H, WALL_S)
    _wall(b, east, Vector2.UP, 0.0, hb.size.y, 0.0, WALL_H, WALL_E)
    _wall(b, south, Vector2.RIGHT, 0.0, hb.size.x, 0.0, 3.0, WALL_S.darkened(0.25))   # the plinth
    for w in windows():
        var origin: Vector2 = south if w[0] == "s" else east
        var along: Vector2 = Vector2.RIGHT if w[0] == "s" else Vector2.UP
        _wall(b, origin, along, w[1] - 1.5, w[2] + 1.5, w[3] - 1.5, w[4] + 1.5, FRAME if w[0] == "s" else FRAME.darkened(0.3))
        _wall(b, origin, along, w[1], w[2], w[3], w[4], WINDOW if w[0] == "s" else WINDOW.darkened(0.2))
        _wall(b, origin, along, (w[1] + w[2]) * 0.5 - 0.5, (w[1] + w[2]) * 0.5 + 0.5, w[3], w[4], FRAME.darkened(0.2))   # the glazing bar
    var du0: float = door_x - 9.0 - hb.position.x
    var du1: float = door_x + 9.0 - hb.position.x
    _wall(b, south, Vector2.RIGHT, du0 - 2.0, du1 + 2.0, 0.0, DOOR_H + 2.0, FRAME)
    _wall(b, south, Vector2.RIGHT, du0, du1, 0.0, DOOR_H, Color("ffd27a"))                 # the door: warm light behind it
    _wall(b, south, Vector2.RIGHT, du0 + 2.0, du1 - 2.0, 4.0, DOOR_H - 3.0, Color("e8a94a"))
    # a little porch roof over the door, sloping out
    Sprites.fill(b, PackedVector2Array([b._p(door_x - 14.0, hb.end.y, DOOR_H + 5.0), b._p(door_x + 14.0, hb.end.y, DOOR_H + 5.0),
        b._p(door_x + 14.0, hb.end.y + 9.0, DOOR_H + 1.0), b._p(door_x - 14.0, hb.end.y + 9.0, DOOR_H + 1.0)]), Color("7a4036"))
    b.draw_line(b._p(door_x - 14.0, hb.end.y + 9.0, DOOR_H + 1.0), b._p(door_x + 14.0, hb.end.y + 9.0, DOOR_H + 1.0), Color("a8574a"), 1.0)
    b.draw_line(b._p(hb.position.x, hb.end.y, 0.0), b._p(hb.end.x, hb.end.y, 0.0), Color(0, 0, 0, 0.45), 1.0)
    b.draw_line(b._p(hb.end.x, hb.end.y, 0.0), b._p(hb.end.x, hb.end.y, WALL_H), WALL_S.lightened(0.15), 1.0)
    # the pitched roof and the chimney (Roofs._house), with its smoke
    var smoke: Array = []
    RoofsScript._house(b, hb, WALL_H, WALL_E, smoke)
    RoofsScript._flush(b, PackedVector2Array(), PackedColorArray(), smoke)
    # bushes by the front wall, either side of the door, and one at the gate
    for q in [Vector2(hb.position.x + 24.0, hb.end.y + 7.0), Vector2(hb.end.x - 20.0, hb.end.y + 7.0), Vector2(r.position.x + 22.0, r.end.y - 22.0), Vector2(r.end.x - 20.0, r.end.y - 20.0)]:
        _bush(b, q)
    _fence(b, r)
    # the name board over the gate, and a mailbox on the post beside it
    var gx0: float = r.end.x - GATE_FROM
    var gx1: float = r.end.x - GATE_TO
    var gate := Vector2(gx0, r.end.y)
    Sprites.fill(b, b._quad(gate, Vector2.RIGHT, 0.0, GATE_FROM - GATE_TO, 14.0, 24.0), Color("3a2a1c"))
    Sprites.polyline(b, PackedVector2Array([b._p(gx0, r.end.y, 14.0), b._p(gx1, r.end.y, 14.0), b._p(gx1, r.end.y, 24.0), b._p(gx0, r.end.y, 24.0), b._p(gx0, r.end.y, 14.0)]), Color("a8793a"), 1.0)
    Style.draw_world_text(b, b._p(gx0 + 11.0, r.end.y, 16.5), "HOME", 8, Style.GOLD)
    Sprites.roof_box(b, gx1 + 3.0, r.end.y - 3.0, 6.0, 5.0, 9.0, 6.0, Color("3a5a8a"), Color("284266"), Color("4a6ea6"))   # the mailbox

static func _bush(b, q: Vector2) -> void:
    var c: Vector2 = b._p(q.x, q.y, 5.0)
    b.draw_circle(c + Vector2(0.0, 2.0), 9.0, Color(0, 0, 0, 0.25))
    b.draw_circle(c, 8.5, Color("1f4a2a"))
    b.draw_circle(c + Vector2(-2.0, -2.0), 6.5, Color("2f6a3c"))
    b.draw_circle(c + Vector2(-3.0, -3.5), 3.0, Color("4a8a52"))

# A white picket fence round the lot, with the gap for the gate in the south side: posts every few units and two rails.
static func _fence(b, r: Rect2) -> void:
    var gx0: float = r.end.x - GATE_FROM
    var gx1: float = r.end.x - GATE_TO
    var runs: Array = [[Vector2(r.position.x, r.end.y), Vector2(gx0, r.end.y)], [Vector2(gx1, r.end.y), Vector2(r.end.x, r.end.y)],
        [Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)],
        [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)]]
    var lines := PackedVector2Array()
    var cols := PackedColorArray()
    for i in runs.size():
        var a: Vector2 = runs[i][0]
        var c: Vector2 = runs[i][1]
        if i == 4:
            continue  # (the back fence is behind the house and off the street: not worth the lines)
        var n: int = maxi(int(a.distance_to(c) / 6.0), 1)
        var front: bool = i != 2  # the west fence is seen from behind the lawn: darker
        for k in n + 1:
            var q: Vector2 = a.lerp(c, float(k) / float(n))
            lines.append(b._p(q.x, q.y, 0.0))
            lines.append(b._p(q.x, q.y, FENCE_H))
            cols.append(WOOD if front else WOOD_SHADE)   # (one colour for each line)
        for z in [2.0, 5.0]:  # the rails
            lines.append(b._p(a.x, a.y, z))
            lines.append(b._p(c.x, c.y, z))
            cols.append(WOOD_SHADE)
    b.draw_multiline_colors(lines, cols, 1.6)
    # gate posts, a little taller
    for gx in [gx0, gx1]:
        b.draw_line(b._p(gx, r.end.y, 0.0), b._p(gx, r.end.y, 14.0), WOOD, 3.0)
