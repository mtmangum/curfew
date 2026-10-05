extends Node2D
# A neon sign on a building's wall, from level 5 ("Neon Nose"): a word (BAR, CLUB, HOTEL...) or a shape (a heart,
# an arrow, a cocktail glass) in glowing tubes, on a dark board, in pink, cyan, red, violet, amber or green. Some
# flicker, now and then stuttering out and back. It is drawn on the wall (a child of the Building, so it fades with
# it) and LightMap.gd lights the street and the wall round it in its colour. `plan` is static and decided from the
# building's number, so it is the same every time and a test can check it without drawing anything.

const Sprites := preload("res://scripts/Sprites.gd")

const SHARE := 55         # percent of buildings that have a sign
const CELL := 2.6         # one dot of the pixel lettering, in world units
const COLORS := [Color("ff3fa4"), Color("30e0ff"), Color("ff3b3b"), Color("a45cff"), Color("ffb03a"), Color("5cff9a")]
# Which colour a sign gets: pink and red half the time between them (a red-light district), the rest a share each.
const PICK := [0, 2, 0, 2, 3, 1, 4, 5]
const WORDS := ["BAR", "CLUB", "HOTEL", "JAZZ", "LIVE", "PUB", "DISCO"]
const SHAPES := ["heart", "arrow", "glass"]

# The letters, 3 dots wide by 5 high, one row per number (bits left to right).
const FONT := {
    "A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6], "E": [7, 4, 6, 4, 7],
    "H": [5, 5, 7, 5, 5], "I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2], "L": [4, 4, 4, 4, 7], "O": [2, 5, 5, 5, 2],
    "P": [6, 5, 6, 4, 4], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2], "U": [5, 5, 5, 5, 7],
    "V": [5, 5, 5, 5, 2], "Z": [7, 1, 2, 4, 7],
}
# The shapes, 5 dots wide by as many rows as they have.
const SHAPE_ROWS := {
    "heart": [10, 31, 31, 14, 4],
    "arrow": [4, 4, 21, 14, 4],
    "glass": [31, 14, 4, 4, 4, 14],
}

var building
var plan: Dictionary = {}
var bright := 1.0
var phase := 0.0
var t := 0.0

# The dots of a sign's picture: [[column, row], ...] and its width and height in dots.
static func dots(what: String) -> Dictionary:
    var out: Array = []
    var width := 0
    var height := 5
    if SHAPE_ROWS.has(what):
        var rows: Array = SHAPE_ROWS[what]
        height = rows.size()
        width = 5
        for r in rows.size():
            for c in 5:
                if int(rows[r]) & (16 >> c) != 0:
                    out.append([c, r])
    else:
        for i in what.length():
            var bits: Array = FONT[what[i]]
            for r in 5:
                for c in 3:
                    if int(bits[r]) & (4 >> c) != 0:
                        out.append([i * 4 + c, r])
        width = what.length() * 4 - 1
    return {"dots": out, "w": width, "h": height}

# Whether this building has a sign, and the whole of it: {face, u, z, what, color, flicker, w, h} in world units
# along the wall ("s" is the south wall, "e" the east one), or {} for none.
static func plan_for(rect: Rect2, variant: int, height: float, floors: int) -> Dictionary:
    var h: int = absi(variant * 2654435 + int(rect.position.x) * 31 + int(rect.position.y) * 17)
    if h % 100 >= SHARE:
        return {}
    var what: String = WORDS[(h / 100) % WORDS.size()] if (h / 700) % 4 != 0 else SHAPES[(h / 2800) % SHAPES.size()]
    var d: Dictionary = dots(what)
    var w: float = float(d.w) * CELL
    var south: bool = (h / 50) % 2 == 0
    var length: float = rect.size.x if south else rect.size.y
    if length < w + 28.0:
        south = not south
        length = rect.size.x if south else rect.size.y
        if length < w + 28.0:
            return {}
    var span: int = maxi(int(length - w - 24.0), 1)
    return {"face": "s" if south else "e", "u": 12.0 + float((h / 13) % span), "z": clampf(height - 17.0, 20.0, 30.0), "what": what,
            "color": COLORS[PICK[(h / 7) % PICK.size()]], "flicker": (h / 31) % 3 == 0, "w": w, "h": float(d.h) * CELL}

# How bright a flickering sign is at time `t`: steady, and then for a moment every few seconds it stutters out
# and back.
static func brightness_at(time: float) -> float:
    var k: float = fposmod(time, 4.7)
    if k > 0.9:
        return 1.0
    for gap in [[0.10, 0.17], [0.27, 0.31], [0.50, 0.55], [0.66, 0.9]]:
        if k >= gap[0] and k < gap[1]:
            return 0.12
    return 1.0

func _ready() -> void:
    phase = randf() * 10.0
    set_process(bool(plan.flicker))

func _process(delta: float) -> void:
    t += delta
    var b: float = brightness_at(t + phase)
    if absf(b - bright) > 0.01:
        bright = b
        queue_redraw()

# The wall it is on: where its edge starts, which way along the wall runs, and the face.
func _wall() -> Array:
    var r: Rect2 = building.rect
    if plan.face == "s":
        return [Vector2(r.position.x, r.end.y), Vector2.RIGHT]
    return [Vector2(r.end.x, r.end.y), Vector2.UP]

# The spot on the ground under the middle of the sign, and how high it is (for the light map).
func anchor() -> Vector2:
    var wall: Array = _wall()
    return wall[0] + wall[1] * (float(plan.u) + float(plan.w) * 0.5)

func height_mid() -> float:
    return float(plan.z) + float(plan.h) * 0.5

# Which way is out from the wall, on the ground plane (the street side).
func outward() -> Vector2:
    return Vector2(0.0, 1.0) if plan.face == "s" else Vector2(1.0, 0.0)

func _draw() -> void:
    if plan.is_empty() or building == null:
        return
    draw_set_transform_matrix(Sprites.UP)
    var wall: Array = _wall()
    paint(self, building, wall[0], wall[1], plan, bright)

# Draws a sign `plan` (see plan_for) on a wall that starts at `o` and runs along `along`, with `bright` 0..1: the board, a
# soft halo, then the tubes. `wall` is anything with a `_quad(origin, along, u0, u1, z0, z1)` (a Building, or the
# sprite gallery's preview), and the item is whatever is drawing (in screen space, as a Building draws).
static func paint(item: CanvasItem, wall, o: Vector2, along: Vector2, p: Dictionary, bright_now: float) -> void:
    var u0: float = p.u
    var z0: float = p.z
    var col: Color = p.color
    var lit := Color(col.r, col.g, col.b, 1.0).lerp(Color(0.12, 0.08, 0.14, 1.0), 1.0 - bright_now)
    Sprites.fill(item, wall._quad(o, along, u0 - 3.0, u0 + p.w + 3.0, z0 - 3.0, z0 + p.h + 3.0), Color(0.05, 0.03, 0.07, 0.92))
    Sprites.fill(item, wall._quad(o, along, u0 - 2.0, u0 + p.w + 2.0, z0 - 2.0, z0 + p.h + 2.0), Color(col.r, col.g, col.b, 0.14 * bright_now))
    var d: Dictionary = dots(p.what)
    for dot in d.dots:
        var du: float = float(dot[0]) * CELL
        var dz: float = (float(d.h) - 1.0 - float(dot[1])) * CELL
        Sprites.fill(item, wall._quad(o, along, u0 + du - 0.15, u0 + du + CELL * 0.93, z0 + dz - 0.15, z0 + dz + CELL * 0.93), lit)
