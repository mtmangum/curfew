extends RefCounted
# Little pictures drawn the way the city is: isometric. x runs down and to the right, y down and to the left, z straight up,
# with the same 2:1 slope as the streets, light from the upper left (the top face is the lightest, the left face a little
# darker, the right face the darkest) and a dark outline. The found items (Items.draw_icon), the house on the clue cards
# and Stella's thought bubble (Style.draw_clue_icon) and the bin and paw print on the clue cards use it. `o` is where
# the (0, 0, 0) corner of the picture lands on screen and `k` is how many pixels a unit is.

const OUTLINE := Color(0.05, 0.04, 0.09)

static func p(o: Vector2, k: float, x: float, y: float, z: float) -> Vector2:
    return o + Vector2((x - y) * k, (x + y) * k * 0.5 - z * k)

static func shade(c: Color, f: float) -> Color:
    return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)

static func _poly(item: CanvasItem, pts: PackedVector2Array, col: Color, line: bool = true) -> void:
    item.draw_colored_polygon(pts, col)
    if line:
        var loop := pts.duplicate()
        loop.append(pts[0])
        item.draw_polyline(loop, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, col.a * 0.85), 1.0)

# The flat shadow on the ground under a picture: a diamond spanning x0..x1, y0..y1.
static func ground(item: CanvasItem, o: Vector2, k: float, x0: float, y0: float, x1: float, y1: float, a: float = 1.0) -> void:
    item.draw_colored_polygon(PackedVector2Array([p(o, k, x0, y0, 0), p(o, k, x1, y0, 0), p(o, k, x1, y1, 0), p(o, k, x0, y1, 0)]), Color(0, 0, 0, 0.32 * a))

# A box with its three visible faces: top, left (the y-max side) and right (the x-max side).
static func box(item: CanvasItem, o: Vector2, k: float, x0: float, y0: float, z0: float, sx: float, sy: float, sz: float, col: Color) -> void:
    var x1 := x0 + sx
    var y1 := y0 + sy
    var z1 := z0 + sz
    _poly(item, PackedVector2Array([p(o, k, x0, y1, z1), p(o, k, x1, y1, z1), p(o, k, x1, y1, z0), p(o, k, x0, y1, z0)]), shade(col, 0.8))
    _poly(item, PackedVector2Array([p(o, k, x1, y0, z1), p(o, k, x1, y1, z1), p(o, k, x1, y1, z0), p(o, k, x1, y0, z0)]), shade(col, 0.58))
    _poly(item, PackedVector2Array([p(o, k, x0, y0, z1), p(o, k, x1, y0, z1), p(o, k, x1, y1, z1), p(o, k, x0, y1, z1)]), shade(col, 1.08))

# A circle lying flat at height z, centre (cx, cy): an ellipse twice as wide as it is tall.
static func disc(item: CanvasItem, o: Vector2, k: float, cx: float, cy: float, z: float, r: float, col: Color, line: bool = true) -> void:
    var c := p(o, k, cx, cy, z)
    var rx: float = r * k * 1.4142
    var pts := PackedVector2Array()
    for i in 22:
        var a: float = TAU * float(i) / 22.0
        pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * 0.5))
    _poly(item, pts, col, line)

# An upright cylinder (or a cone, with a different top radius), its foot at height z0.
static func cylinder(item: CanvasItem, o: Vector2, k: float, cx: float, cy: float, z0: float, r: float, h: float, col: Color, top_r: float = -1.0, cap: bool = true) -> void:
    var tr: float = r if top_r < 0.0 else top_r
    var foot := p(o, k, cx, cy, z0)
    var head := p(o, k, cx, cy, z0 + h)
    var rx0: float = r * k * 1.4142
    var rx1: float = tr * k * 1.4142
    var body := PackedVector2Array()
    for i in 13:  # the front half of the foot, left to right
        var a: float = PI - PI * float(i) / 12.0
        body.append(foot + Vector2(cos(a) * rx0, sin(a) * rx0 * 0.5))
    for i in 13:  # and back along the front half of the head
        var a: float = PI * float(i) / 12.0
        body.append(head + Vector2(cos(a) * rx1, sin(a) * rx1 * 0.5))
    item.draw_colored_polygon(body, shade(col, 0.72))
    # the lit side, a band down the left
    var lit := PackedVector2Array()
    for i in 7:
        var a: float = PI - PI * 0.42 * float(i) / 6.0
        lit.append(foot + Vector2(cos(a) * rx0, sin(a) * rx0 * 0.5))
    for i in 7:
        var a: float = PI * 0.58 + PI * 0.42 * float(i) / 6.0   # (back up the head, so the band does not cross itself)
        lit.append(head + Vector2(cos(a) * rx1, sin(a) * rx1 * 0.5))
    item.draw_colored_polygon(lit, shade(col, 0.98))
    var edge := PackedVector2Array()
    edge.append(head + Vector2(-rx1, 0))
    for pt in body.slice(0, 13):
        edge.append(pt)
    edge.append(head + Vector2(rx1, 0))
    item.draw_polyline(edge, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.85), 1.0)
    if cap:
        disc(item, o, k, cx, cy, z0 + h, tr, shade(col, 1.1))

# A ball (a bone's knob, say): a circle with a highlight.
static func ball(item: CanvasItem, o: Vector2, k: float, x: float, y: float, z: float, r: float, col: Color) -> void:
    var c := p(o, k, x, y, z)
    item.draw_circle(c, r * k * 1.45 + 1.0, OUTLINE)
    item.draw_circle(c, r * k * 1.45, shade(col, 0.82))
    item.draw_circle(c + Vector2(-r * k * 0.25, -r * k * 0.3), r * k * 1.0, col)
    item.draw_circle(c + Vector2(-r * k * 0.4, -r * k * 0.5), r * k * 0.4, shade(col, 1.15))

# --- the found items (Items.gd), each in a square s across centred on c ------------------------------------------

static func _origin(c: Vector2, s: float, lift: float = 0.0) -> Array:
    var k: float = s / 17.0
    return [c + Vector2(0.0, s * 0.18 + lift * k), k]

static func bone(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    var cream := Color(0.96, 0.9, 0.72, a)
    ground(item, o, k, 0.2, 1.8, 8.8, 7.2, a)
    # a bone lying along the x axis: two knobs at each end, back pair first
    ball(item, o, k, 1.2, 3.1, 1.1, 1.05, cream)
    ball(item, o, k, 1.2, 4.9, 1.1, 1.05, cream)
    box(item, o, k, 1.2, 3.3, 0.0, 6.6, 1.4, 1.5, cream)
    ball(item, o, k, 7.8, 3.1, 1.1, 1.05, cream)
    ball(item, o, k, 7.8, 4.9, 1.1, 1.05, cream)

# One donut lying flat: dough, a glaze of `icing` (or none), a hole, and sprinkles if wanted.
static func one_donut(item: CanvasItem, o: Vector2, k: float, x: float, y: float, z: float, icing: Color, a: float, sprinkles: bool = false) -> void:
    var dough := Color(0.86, 0.6, 0.32, a)
    disc(item, o, k, x, y, z, 1.25, shade(dough, 0.62), false)
    disc(item, o, k, x, y, z + 0.3, 1.25, dough, false)
    disc(item, o, k, x, y, z + 0.5, 1.02, icing, false)
    disc(item, o, k, x, y, z + 0.55, 0.36, Color(0.17, 0.09, 0.07, a), false)
    if sprinkles:
        for sp in [Vector2(-0.6, 0.2), Vector2(0.5, -0.5), Vector2(0.7, 0.6), Vector2(-0.2, -0.8), Vector2(-0.5, 0.8)]:
            var q := p(o, k, x + sp.x, y + sp.y, z + 0.7)
            item.draw_rect(Rect2(q - Vector2(0.8, 0.4), Vector2(1.6, 0.9)), Color(1.0, 0.96, 0.8, a))

# An open cardboard box of donuts: the lid swung partway closed over the back with a pink stripe, a pink band round the bottom, and
# a handful of donuts inside (pink, chocolate, glazed, lemon and white).
static func donut(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, 1.5)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    var card := Color(0.97, 0.9, 0.8, a)
    var pink := Color(1.0, 0.5, 0.74, a)
    var x0 := 0.6
    var x1 := 8.0
    var y0 := 1.6
    var y1 := 6.6
    var zt := 2.2    # the rim
    var zf := 0.7    # the floor inside
    ground(item, o, k, x0 - 0.3, y0 - 0.3, x1 + 0.3, y1 + 0.3, a)
    # inside: the floor and the two back walls
    _poly(item, PackedVector2Array([p(o, k, x0, y0, zf), p(o, k, x1, y0, zf), p(o, k, x1, y1, zf), p(o, k, x0, y1, zf)]), shade(card, 0.68), false)
    _poly(item, PackedVector2Array([p(o, k, x0, y0, zt), p(o, k, x1, y0, zt), p(o, k, x1, y0, zf), p(o, k, x0, y0, zf)]), shade(card, 0.86), false)
    _poly(item, PackedVector2Array([p(o, k, x0, y0, zt), p(o, k, x0, y1, zt), p(o, k, x0, y1, zf), p(o, k, x0, y0, zf)]), shade(card, 0.76), false)
    # the donuts, back to front
    var rows: Array = [
        [Vector2(2.5, 3.0), Color(0.38, 0.22, 0.14, a), true], [Vector2(5.0, 3.0), Color(1.0, 0.55, 0.75, a), false], [Vector2(7.0, 3.3), Color(1.0, 0.93, 0.78, a), false],
        [Vector2(2.7, 5.2), Color(0.95, 0.78, 0.3, a), false], [Vector2(5.2, 5.2), Color(0.98, 0.9, 0.9, a), true]]
    for d in rows:
        one_donut(item, o, k, d[0].x, d[0].y, zf, d[1], a, d[2])
    # the lid, hinged along the back edge and swung partway closed: it leans over the back of the box with its pink stripe
    # showing, covering the back row of donuts and leaving the front ones in view
    var ly := y0 + 1.5
    var lz := zt + 3.4
    _poly(item, PackedVector2Array([p(o, k, x0, y0, zt), p(o, k, x1, y0, zt), p(o, k, x1, ly, lz), p(o, k, x0, ly, lz)]), shade(card, 1.04))
    _poly(item, PackedVector2Array([p(o, k, x0 + 0.5, y0 + 0.4, zt + 1.0), p(o, k, x1 - 0.5, y0 + 0.4, zt + 1.0), p(o, k, x1 - 0.5, y0 + 1.1, zt + 2.2), p(o, k, x0 + 0.5, y0 + 1.1, zt + 2.2)]), shade(pink, 1.0), false)
    _poly(item, PackedVector2Array([p(o, k, x0, ly, lz), p(o, k, x1, ly, lz), p(o, k, x1, ly, lz - 0.45), p(o, k, x0, ly, lz - 0.45)]), shade(card, 0.7))   # the lid's edge
    # the front of the box over the donuts' lower edges: the two outer faces, with a pink band along the bottom
    var left := [Vector2(x0, y1), Vector2(x1, y1)]
    _poly(item, PackedVector2Array([p(o, k, x0, y1, zt), p(o, k, x1, y1, zt), p(o, k, x1, y1, 0), p(o, k, x0, y1, 0)]), shade(card, 0.96))
    _poly(item, PackedVector2Array([p(o, k, x1, y0, zt), p(o, k, x1, y1, zt), p(o, k, x1, y1, 0), p(o, k, x1, y0, 0)]), shade(card, 0.74))
    _poly(item, PackedVector2Array([p(o, k, x0, y1, 0.9), p(o, k, x1, y1, 0.9), p(o, k, x1, y1, 0), p(o, k, x0, y1, 0)]), shade(pink, 0.95), false)
    _poly(item, PackedVector2Array([p(o, k, x1, y0, 0.9), p(o, k, x1, y1, 0.9), p(o, k, x1, y1, 0), p(o, k, x1, y0, 0)]), shade(pink, 0.7), false)

# A hooded sweatshirt laid flat on the ground, neck toward the back: body, two sleeves out to the sides with ribbed
# cuffs, the hood with its dark opening, the pocket and the drawstrings (so it reads as a hoodie, not a lump).
static func hoodie(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, 0.0)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    var cloth := Color(0.5, 0.45, 0.82, a)
    ground(item, o, k, 0.0, 0.0, 8.8, 8.0, a)
    var parts: Array = [
        [[-2.3, 0.7], [2.3, 0.7], [2.3, 7.7], [-2.3, 7.7]],                                          # the body
        [[-2.3, 0.9], [-4.9, 4.6], [-3.7, 5.6], [-2.3, 3.4]],                                        # the left sleeve
        [[2.3, 0.9], [4.9, 4.6], [3.7, 5.6], [2.3, 3.4]]]                                            # and the right
    for z in [0.0, 0.7]:   # once low and dark (the cloth's thickness shows along the lower edges), then on top
        for part in parts:
            _flat(item, o, k, part, z, shade(cloth, 0.55) if z == 0.0 else cloth)
    _flat(item, o, k, [[-2.3, 6.9], [2.3, 6.9], [2.3, 7.7], [-2.3, 7.7]], 0.72, shade(cloth, 0.78))   # the ribbed hem
    _flat(item, o, k, [[-4.9, 4.6], [-3.7, 5.6], [-4.15, 6.0], [-5.35, 4.95]], 0.72, shade(cloth, 0.78))   # the cuffs
    _flat(item, o, k, [[4.9, 4.6], [3.7, 5.6], [4.15, 6.0], [5.35, 4.95]], 0.72, shade(cloth, 0.78))
    _flat(item, o, k, [[-1.7, 4.5], [1.7, 4.5], [2.0, 6.4], [-2.0, 6.4]], 0.74, shade(cloth, 0.84))     # the pocket
    # the hood, lying open around the neck: a rim of cloth, a dark inside
    _flat_oval(item, o, k, 0.0, 0.9, 1.9, 1.5, 0.75, shade(cloth, 1.12))
    _flat_oval(item, o, k, 0.0, 1.05, 1.15, 0.95, 0.8, Color(0.1, 0.08, 0.17, a))
    for sx in [-0.7, 0.7]:   # drawstrings
        item.draw_line(p(o, k, 0.8 + 2.0, 4.0 + sx, 0.9), p(o, k, 0.8 + 3.9, 4.0 + sx * 1.15, 0.9), Color(0.96, 0.96, 1.0, a), 1.2)

# A polygon lying flat on the ground at height z, given as [across, along] points (across runs along y, along runs along x).
static func _flat(item: CanvasItem, o: Vector2, k: float, pts: Array, z: float, col: Color) -> void:
    var poly := PackedVector2Array()
    for q in pts:
        poly.append(p(o, k, 0.8 + q[1], 4.0 + q[0], z))
    _poly(item, poly, col)

static func _flat_oval(item: CanvasItem, o: Vector2, k: float, across: float, along: float, ra: float, rl: float, z: float, col: Color) -> void:
    var poly := PackedVector2Array()
    for i in 20:
        var t: float = TAU * float(i) / 20.0
        poly.append(p(o, k, 0.8 + along + sin(t) * rl, 4.0 + across + cos(t) * ra, z))
    _poly(item, poly, col)

static func extinguisher(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, -4.5)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    var red := Color(0.86, 0.22, 0.16, a)
    var brass := Color(0.8, 0.6, 0.22, a)
    var black := Color(0.16, 0.15, 0.17, a)
    ground(item, o, k, 1.2, 1.6, 6.4, 6.9, a)
    cylinder(item, o, k, 4.0, 4.0, 0.0, 1.6, 6.0, red, 1.6, false)                 # the red cylinder, with rounded shoulders
    cylinder(item, o, k, 4.0, 4.0, 6.0, 1.6, 1.0, red, 1.05, false)
    cylinder(item, o, k, 4.0, 4.0, 7.0, 0.95, 0.9, brass)                          # the brass neck
    # the pressure gauge on the neck: a rim, a cream face and a red needle
    var g := p(o, k, 3.3, 4.8, 8.0)
    item.draw_circle(g, k * 0.95 + 1.0, OUTLINE)
    item.draw_circle(g, k * 0.95, Color(0.7, 0.72, 0.76, a))
    item.draw_circle(g, k * 0.7, Color(0.97, 0.95, 0.86, a))
    item.draw_line(g, g + Vector2(k * 0.5, -k * 0.45), Color(0.85, 0.15, 0.1, a), 1.0)
    # the handle on top, a red lever with a squeeze trigger under its tip
    box(item, o, k, 2.6, 3.6, 8.5, 3.8, 0.8, 0.5, red)
    box(item, o, k, 4.8, 3.6, 8.0, 2.0, 0.8, 0.35, shade(red, 0.9))
    # the hose: black, from the neck out to the left and down the side of the cylinder to a cone nozzle
    var hose := PackedVector2Array([p(o, k, 3.4, 4.3, 7.8), p(o, k, 2.4, 5.4, 8.0), p(o, k, 2.2, 6.0, 6.4), p(o, k, 2.6, 6.2, 4.4), p(o, k, 3.0, 6.1, 2.8)])
    item.draw_polyline(hose, OUTLINE, 5.0)
    item.draw_polyline(hose, black, 3.4)
    cylinder(item, o, k, 3.0, 6.1, 0.0, 1.05, 2.8, black, 0.45, false)             # the nozzle, wide at the foot
    disc(item, o, k, 3.0, 6.1, 2.8, 0.45, shade(black, 1.4))

static func coffee(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, -1.5)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    ground(item, o, k, 1.8, 1.8, 6.2, 6.2, a)
    cylinder(item, o, k, 4.0, 4.0, 0.0, 1.5, 4.4, Color(0.96, 0.93, 0.86, a), 1.95, false)   # the cup, wider at the top
    cylinder(item, o, k, 4.0, 4.0, 1.1, 1.7, 1.9, Color(0.76, 0.4, 0.24, a), 1.82, false)    # the sleeve
    cylinder(item, o, k, 4.0, 4.0, 4.4, 2.05, 0.7, Color(0.36, 0.22, 0.16, a))               # the lid
    for sx in [-0.6, 0.7]:
        var base := p(o, k, 4.0 + sx, 4.0 + sx, 5.4)
        item.draw_polyline(PackedVector2Array([base, base + Vector2(2, -3), base + Vector2(-1, -6), base + Vector2(1.5, -9)]), Color(0.92, 0.92, 0.98, 0.7 * a), 1.2)

# --- the house on the clue cards and the thought bubble, and the bin and paw print -------------------------------

static func house(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, -1.0)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    var wall := Color(0.93, 0.84, 0.64, a)
    var roof := Color(0.72, 0.3, 0.22, a)
    ground(item, o, k, 0.2, 0.2, 8.6, 8.2, a)
    box(item, o, k, 0.8, 1.2, 0.0, 6.8, 5.6, 3.6, wall)
    # the lit window and the glowing door on the y-max (front-left) wall, and a window on the x-max wall
    var front_y := 6.8
    _poly(item, PackedVector2Array([p(o, k, 4.6, front_y, 2.7), p(o, k, 6.6, front_y, 2.7), p(o, k, 6.6, front_y, 1.1), p(o, k, 4.6, front_y, 1.1)]), Color(1.0, 0.82, 0.38, a))
    _poly(item, PackedVector2Array([p(o, k, 1.6, front_y, 2.3), p(o, k, 3.0, front_y, 2.3), p(o, k, 3.0, front_y, 0.0), p(o, k, 1.6, front_y, 0.0)]), Color(1.0, 0.7, 0.22, a))
    # a pitched roof along x: the front slope, and the triangle of the gable on the x-max wall
    var ridge_y := 4.0
    var ridge_z := 6.0
    _poly(item, PackedVector2Array([p(o, k, 0.4, 0.6, 3.3), p(o, k, 8.0, 0.6, 3.3), p(o, k, 8.0, ridge_y, ridge_z), p(o, k, 0.4, ridge_y, ridge_z)]), shade(roof, 0.62))   # the back slope, which faces away, shows above the ridge
    _poly(item, PackedVector2Array([p(o, k, 7.6, 6.8, 3.6), p(o, k, 7.6, ridge_y, ridge_z), p(o, k, 7.6, 1.2, 3.6)]), shade(wall, 0.58))
    _poly(item, PackedVector2Array([p(o, k, 0.4, 7.4, 3.3), p(o, k, 8.0, 7.4, 3.3), p(o, k, 8.0, ridge_y, ridge_z), p(o, k, 0.4, ridge_y, ridge_z)]), shade(roof, 0.9))
    box(item, o, k, 5.6, 2.4, 4.4, 1.0, 1.0, 1.9, Color(0.55, 0.28, 0.22, a))   # the chimney

static func bin(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, -1.5)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    ground(item, o, k, 1.5, 1.5, 6.5, 6.5, a)
    cylinder(item, o, k, 4.0, 4.0, 0.0, 1.9, 4.6, Color(0.55, 0.6, 0.68, a), 2.1, false)
    cylinder(item, o, k, 4.0, 4.0, 4.6, 2.2, 0.6, Color(0.42, 0.46, 0.54, a))
    box(item, o, k, 3.4, 3.7, 5.2, 1.2, 0.6, 0.45, Color(0.3, 0.33, 0.4, a))   # the lid's handle
    for dz in [1.2, 2.6]:
        var lo := p(o, k, 4.0, 4.0, dz)
        item.draw_arc(lo + Vector2(0, 1), 1.9 * k * 1.41, 0.15, PI - 0.15, 12, Color(0.3, 0.33, 0.4, 0.8 * a), 1.0)

static func paw(item: CanvasItem, c: Vector2, s: float, a: float = 1.0) -> void:
    var ok: Array = _origin(c, s, 0.0)
    var o: Vector2 = ok[0]
    var k: float = ok[1]
    var ink := Color(0.93, 0.85, 0.72, a)
    ground(item, o, k, 0.5, 0.5, 7.5, 7.5, a * 0.5)
    # flat on the ground: a pad, and four toes in an arc beyond it (up the screen, toward smaller x and y)
    var ahead := Vector2(-1.0, -1.0).normalized()
    var across := Vector2(1.0, -1.0).normalized()
    disc(item, o, k, 4.4, 4.4, 0.0, 2.0, ink)
    for t in [Vector2(-2.5, 1.9), Vector2(-0.9, 3.0), Vector2(0.9, 3.0), Vector2(2.5, 1.9)]:
        var at: Vector2 = Vector2(4.4, 4.4) + across * t.x + ahead * t.y
        disc(item, o, k, at.x, at.y, 0.0, 0.95, ink)
