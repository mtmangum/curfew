extends RefCounted
# What is in a shop's window. A shopfront has wide windows along its front (Building._windows); a lit
# one is a display: a warm interior with a strip light and a floor, a shelf and goods that depend on
# the kind of shop (shoes, hats, electronics, a boutique's mannequins, a grocer's bottles and fruit,
# a bakery's cakes, books), and, in about one shop in three, a neon OPEN sign. Everything is a plain
# rectangle in the window's own units (u along the wall 0..28, z up from the sill 0..12), listed as
# data so a test can check that it all fits, and drawn as batched quads on the wall.

const Sprites := preload("res://scripts/Sprites.gd")

const WIDTH := 28.0   # a shop window: 28 along the wall
const HEIGHT := 12.0  # and 12 high, from 4 above the pavement (Building._windows)
const SILL := 4.0
const THEMES := 7     # shoes, hats, electronics, boutique, grocer, bakery, books

const SHELF := Color("5b4631")
const SHOES := [Color("b53a3a"), Color("27406b"), Color("b98a4a"), Color("e9e4d8")]
const HATS := [Color("3b3b44"), Color("7a2f3a"), Color("c9b78a"), Color("2c4a3a")]
const DRESSES := [Color("d6407a"), Color("3f7fd6"), Color("e0b43a"), Color("8a4fd6")]
const BOTTLES := [Color("2e7d4f"), Color("c78a2a"), Color("cfd8df"), Color("7a2f2a")]
const SPINES := [Color("a8372f"), Color("2f5d8a"), Color("3d7a4a"), Color("c99a2e"), Color("5c3a7a"), Color("d8d2c0"), Color("2a2f3a")]
const NEON := [Color("ff4fa3"), Color("4fe3ff"), Color("ff3b3b")]

# The letters O P E N, 3 by 5 cells, as rows of bits.
const LETTERS := [[7, 5, 5, 5, 7], [7, 5, 7, 4, 4], [7, 4, 7, 4, 7], [7, 5, 5, 5, 5]]
const SIGN_W := 15.0
const SIGN_H := 5.0

static func _pick(list: Array, k: int) -> Color:
    return list[posmod(k, list.size())]

# Which kind of shop a building is: the same for all its windows, different from its neighbours'.
static func theme_for(seed_: int) -> int:
    return posmod(seed_, THEMES)

# Whether this shop has a neon OPEN sign (in its second window), and what colour.
static func has_sign(seed_: int) -> bool:
    return posmod(seed_ / 7, 3) == 0

static func sign_color(seed_: int) -> Color:
    return _pick(NEON, seed_)

# The goods in one window: [[u0, u1, z0, z1, color], ...] in window units. `n` is which window of
# the shop it is, so no two in a row are the same.
static func display(theme: int, n: int) -> Array:
    var out: Array = []
    match theme:
        0:  # shoes on a shelf, boots on the floor
            out.append([1.0, 27.0, 6.0, 6.9, SHELF])
            for k in 3:
                var u: float = 3.0 + 8.0 * float(k)
                var col: Color = _pick(SHOES, n * 3 + k)
                out.append([u, u + 5.5, 6.9, 7.7, Color("1a1612")])
                out.append([u + 0.5, u + 4.2, 7.7, 9.6, col])
                out.append([u + 4.2, u + 5.5, 7.7, 8.5, col])
            for k in 2:
                var u2: float = 6.0 + 14.0 * float(k)
                var bc: Color = _pick(SHOES, n * 5 + k + 2)
                out.append([u2, u2 + 3.2, 1.2, 5.2, bc])
                out.append([u2, u2 + 5.0, 1.2, 2.4, bc.darkened(0.25)])
        1:  # hats on stands
            for k in 3:
                var u: float = 4.0 + 8.5 * float(k)
                var lift: float = 2.0 if (k + n) % 2 == 1 else 0.0
                var col: Color = _pick(HATS, n * 2 + k)
                out.append([u + 1.4, u + 2.0, 1.0, 5.5 + lift, Color("4a3f33")])
                out.append([u - 0.6, u + 4.0, 5.5 + lift, 6.4 + lift, col])
                out.append([u + 0.4, u + 3.0, 6.4 + lift, 8.6 + lift, col])
                out.append([u + 0.4, u + 3.0, 6.4 + lift, 6.9 + lift, col.lightened(0.35)])
        2:  # screens on a rack, boxes below
            for k in 3:
                var u: float = 2.0 + 8.5 * float(k)
                var glow: Color = Color("7fd0ff") if (k + n) % 2 == 0 else Color("ffb36a")
                out.append([u, u + 7.0, 5.0, 10.6, Color("15171d")])
                out.append([u + 0.6, u + 6.4, 5.6, 10.0, glow])
                out.append([u + 3.0, u + 4.0, 4.2, 5.0, Color("15171d")])
                out.append([u + 0.5, u + 6.5, 0.8, 3.2, Color("cfc7b8")])
        3:  # mannequins in dresses
            for k in 2:
                var u: float = 8.0 + 12.0 * float(k)
                var col: Color = _pick(DRESSES, n * 2 + k)
                out.append([u - 0.9, u + 0.9, 9.8, 11.7, Color("e3b9a0")])
                out.append([u - 1.6, u + 1.6, 7.0, 9.8, col])
                out.append([u - 2.4, u + 2.4, 4.4, 7.0, col])
                out.append([u - 3.0, u + 3.0, 1.6, 4.4, col.darkened(0.15)])
                out.append([u - 0.3, u + 0.3, 0.8, 1.6, Color("2a2a30")])
        4:  # bottles on a shelf, a crate of fruit below
            out.append([13.0, 27.0, 6.0, 6.9, SHELF])
            for k in 7:
                var u: float = 14.0 + 1.9 * float(k)
                var col: Color = _pick(BOTTLES, n + k)
                out.append([u, u + 1.4, 6.9, 10.6, col])
                out.append([u + 0.4, u + 1.0, 10.6, 11.9, col])
            out.append([2.0, 12.0, 0.8, 4.0, Color("7a5a35")])
            for k in 4:
                var uf: float = 2.6 + 2.3 * float(k)
                out.append([uf, uf + 1.9, 4.0, 5.4, Color("d8602a") if (k + n) % 2 == 0 else Color("b8302a")])
        5:  # cakes on plates, a loaf below
            out.append([1.0, 27.0, 6.0, 6.9, SHELF])
            for k in 2:
                var u: float = 4.0 + 10.0 * float(k)
                out.append([u - 0.5, u + 5.5, 6.9, 7.4, Color("e9e4d8")])
                out.append([u, u + 5.0, 7.4, 9.9, Color("e58aa8") if (k + n) % 2 == 0 else Color("8a5a3a")])
                out.append([u, u + 5.0, 9.9, 10.7, Color("f4ede0")])
                out.append([u + 2.1, u + 2.9, 10.7, 11.5, Color("c22a2a")])
            out.append([21.0, 27.0, 1.0, 3.2, Color("8a5a2a")])
            out.append([21.8, 26.2, 3.2, 3.9, Color("a8733a")])
        _:  # books: two shelves of spines
            out.append([1.0, 27.0, 5.9, 6.8, SHELF])
            for row in 2:
                var z0: float = 0.9 if row == 0 else 6.8
                var u: float = 2.0
                var k := 0
                while u < 25.5:
                    var w: float = 1.0 + float(posmod(k * 7 + n * 3 + row, 3)) * 0.4
                    var h: float = 3.6 + float(posmod(k * 5 + row * 2, 3)) * 0.7
                    out.append([u, u + w, z0, z0 + h, _pick(SPINES, k * 3 + row + n)])
                    u += w + 0.15
                    k += 1
    return out

# The neon OPEN sign: a dark backing board and the letters, with a faint halo, in window units. The
# first is [u0, u1, z0, z1, color]; the sign sits in the window's upper right.
static func neon_sign(color: Color) -> Array:
    var out: Array = []
    var u0 := 11.0
    var z0 := 5.4
    out.append([u0 - 0.8, u0 + SIGN_W + 0.8, z0 - 0.8, z0 + SIGN_H + 0.8, Color(0.05, 0.03, 0.07, 0.9)])
    out.append([u0 - 1.2, u0 + SIGN_W + 1.2, z0 - 1.2, z0 + SIGN_H + 1.2, Color(color.r, color.g, color.b, 0.16)])
    for li in LETTERS.size():
        var lu: float = u0 + float(li) * 4.0
        for row in 5:
            var bits: int = LETTERS[li][row]
            for col in 3:
                if bits & (4 >> col) != 0:
                    out.append([lu + float(col), lu + float(col) + 1.0, z0 + float(4 - row), z0 + float(4 - row) + 1.0, color])
    return out

# Draws one lit window of a shop: the interior, strip light and floor, the goods, and the sign if it has one.
static func paint(b, origin: Vector2, along: Vector2, u: float, light: Color, theme: int, n: int, signed: bool, neon: Color) -> void:
    Sprites.fill(b, b._quad(origin, along, u, u + WIDTH, SILL, SILL + HEIGHT), light.lightened(0.05))
    Sprites.fill(b, b._quad(origin, along, u, u + WIDTH, SILL + HEIGHT - 1.0, SILL + HEIGHT), light.lightened(0.55))
    Sprites.fill(b, b._quad(origin, along, u, u + WIDTH, SILL, SILL + 1.0), light.darkened(0.4))
    for r in display(theme, n):
        Sprites.fill(b, b._quad(origin, along, u + r[0], u + r[1], SILL + r[2], SILL + r[3]), r[4])
    if signed:
        for r in neon_sign(neon):
            Sprites.fill(b, b._quad(origin, along, u + r[0], u + r[1], SILL + r[2], SILL + r[3]), r[4])
