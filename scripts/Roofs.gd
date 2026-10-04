extends RefCounted
# Rooftops. The camera looks down on the city, so a roof is a big part of what is on screen. Each
# roof has a surface (tar paper, gravel or membrane seams with a few stains, leaning toward rust,
# green-grey, concrete or slate) and a low parapet with coping, and that is nearly all: a few
# air-conditioning units, and on about one roof in three a wooden water tank in the back corner.
# (Anything busier looked like clutter in the road when the building went see-through.) The house
# she is heading for has a pitched tile roof and a chimney with smoke. Everything is worked out from
# the building's number, so it is the same every time, and it is drawn with quads and one batched
# run of lines, so it costs few draw calls.
# (Building.setup makes the plan; Building._draw calls paint.)

const Sprites := preload("res://scripts/Sprites.gd")

const TINTS := [Color("5a4a40"), Color("4a5a52"), Color("6c6c74"), Color("4a4f66")]
const MAX_UNITS := 3  # air-conditioning units on one roof

static func _h(a: int, b: int) -> int:
    return posmod((a * 73856093) ^ (b * 19349663) ^ 0x9e3779b1, 1000003)

# Footprint (width, depth) and height of a piece (big enough to read as what they are from the street).
static func _size(kind: String, hv: int) -> Vector3:
    if kind == "tower":
        return Vector3(26.0, 26.0, 50.0)
    return Vector3(22.0 + float(hv % 9), 15.0 + float(hv % 6), 11.0 + float(hv % 4))  # an AC unit

# The pieces on one roof: [{kind, x, y, w, d, h, v}], sorted far to near, plus how far above the
# roof the tallest of them reaches (the building's screen box has to include that), and the surface.
static func plan(rect: Rect2, variant: int, is_house: bool) -> Dictionary:
    if is_house:
        return {"props": [], "extra": 38.0, "surface": 0}
    var inner: Rect2 = rect.grow(-6.0)
    var nx: int = clampi(int(inner.size.x / 50.0), 1, 5)
    var ny: int = clampi(int(inner.size.y / 44.0), 1, 3)
    var sw: float = inner.size.x / float(nx)
    var sh: float = inner.size.y / float(ny)
    var props: Array = []
    var extra := 6.0
    var units := 0
    for iy in ny:
        for ix in nx:
            var hv: int = _h(variant, ix * 7 + iy * 13 + 1)
            var kind := ""
            if ix == 0 and iy == 0 and variant % 3 == 0:
                kind = "tower"  # one roof in three has a water tank, in the back corner
            elif units < MAX_UNITS and hv % 100 < 38:
                kind = "ac"
            else:
                continue
            var sz: Vector3 = _size(kind, hv)
            if sz.x + 4.0 > sw or sz.y + 4.0 > sh:
                continue
            if kind == "ac":
                units += 1
            var fx: float = float((hv / 3) % 100) / 100.0
            var fy: float = float((hv / 11) % 100) / 100.0
            props.append({"kind": kind,
                "x": inner.position.x + float(ix) * sw + 2.0 + fx * (sw - sz.x - 4.0),
                "y": inner.position.y + float(iy) * sh + 2.0 + fy * (sh - sz.y - 4.0),
                "w": sz.x, "d": sz.y, "h": sz.z, "v": hv})
            extra = maxf(extra, sz.z + 3.0)
    props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x + a.y + a.w * 0.5 + a.d * 0.5 < b.x + b.y + b.w * 0.5 + b.d * 0.5)
    return {"props": props, "extra": extra, "surface": (variant / 3) % 3}

# Draws the roof of building `b` at height h.
static func paint(b, r: Rect2, h: float, roof: Color, wall_s: Color, wall_e: Color) -> void:
    # each roof leans a little toward rust, green-grey, concrete or slate, so they are not all one colour
    if not b.house:
        var tint: Color = TINTS[(b.variant / 7) % TINTS.size()]
        roof = roof.lerp(tint, 0.38)
    var inner: Rect2 = r.grow(-5.0)
    var top := PackedVector2Array([b._p(r.position.x, r.position.y, h), b._p(r.end.x, r.position.y, h),
        b._p(r.end.x, r.end.y, h), b._p(r.position.x, r.end.y, h)])
    Sprites.fill(b, top, roof)
    Sprites.fill(b, PackedVector2Array([b._p(inner.position.x, inner.position.y, h), b._p(inner.end.x, inner.position.y, h),
        b._p(inner.end.x, inner.end.y, h), b._p(inner.position.x, inner.end.y, h)]), roof.darkened(0.25))
    var lines := PackedVector2Array()
    var cols := PackedColorArray()
    # a low parapet along the two front edges, with the coping on top
    Sprites.fill(b, b._quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, 0.0, r.size.x, h, h + 2.5), roof.lightened(0.05))
    Sprites.fill(b, b._quad(Vector2(r.end.x, r.end.y), Vector2.UP, 0.0, r.size.y, h, h + 2.5), roof.darkened(0.15))
    var edge: Color = roof.lightened(0.3)
    for pair in [[top[0], top[1]], [top[1], top[2]], [top[2], top[3]], [top[3], top[0]]]:
        _line(lines, cols, pair[0], pair[1], edge)
    var glows: Array = []
    if b.house:
        _house(b, r, h, wall_e, lines, cols, glows)
    else:
        var plan: Dictionary = b.roof_plan
        _surface(b, inner, h, roof, plan.surface, lines, cols)
        for p in plan.props:
            if p.kind == "tower":
                _tower(b, p, h, lines, cols)
            else:
                _unit(b, p, h, lines, cols, glows)
    _flush(b, lines, cols, glows)

static func _line(lines: PackedVector2Array, cols: PackedColorArray, a: Vector2, c: Vector2, color: Color) -> void:
    lines.append(a)
    lines.append(c)
    cols.append(color)  # one colour per segment

# What is left to draw once the roof's fills are done: the smoke (discs, one texture so one batch),
# then all the thin lines in one batched call.
static func _flush(b, lines: PackedVector2Array, cols: PackedColorArray, glows: Array) -> void:
    for g in glows:
        Sprites.ellipse(b, g[0], g[1], g[2], g[3])
    if not lines.is_empty():
        b.draw_multiline_colors(lines, cols, 1.0)

static func _quad(b, x0: float, y0: float, x1: float, y1: float, z: float, color: Color) -> void:
    Sprites.fill(b, PackedVector2Array([b._p(x0, y0, z), b._p(x1, y0, z), b._p(x1, y1, z), b._p(x0, y1, z)]), color)

# The surface: speckle (tar paper dark, gravel light) or seams (a membrane), and a few stains.
static func _surface(b, inner: Rect2, h: float, roof: Color, kind: int, lines: PackedVector2Array, cols: PackedColorArray) -> void:
    var v: int = b.variant
    if kind == 2:
        var x: float = inner.position.x + 12.0
        while x < inner.end.x - 4.0:
            _line(lines, cols, b._p(x, inner.position.y, h), b._p(x, inner.end.y, h), Color(roof.darkened(0.3), 0.8))
            x += 15.0
    else:
        var speck: Color = Color(roof.darkened(0.55), 0.8) if kind == 0 else Color(roof.lightened(0.42), 0.75)
        for k in 26 + v % 12:
            var hv: int = _h(v, 100 + k)
            var px: float = inner.position.x + 2.0 + float(hv % 1000) / 1000.0 * (inner.size.x - 5.0)
            var py: float = inner.position.y + 2.0 + float((hv / 1000) % 1000) / 1000.0 * (inner.size.y - 5.0)
            Sprites.fill(b, PackedVector2Array([b._p(px, py, h), b._p(px + 1.8, py, h), b._p(px + 1.8, py + 1.4, h), b._p(px, py + 1.4, h)]), speck)
    for k in 2 + v % 3:
        var hv2: int = _h(v, 200 + k)
        var sw: float = 8.0 + float(hv2 % 10)
        var sd: float = 5.0 + float((hv2 / 10) % 8)
        var sx: float = inner.position.x + float((hv2 / 100) % 100) / 100.0 * maxf(inner.size.x - sw, 1.0)
        var sy: float = inner.position.y + float((hv2 / 7) % 100) / 100.0 * maxf(inner.size.y - sd, 1.0)
        _quad(b, sx, sy, sx + sw, sy + sd, h, Color(0, 0, 0, 0.22))

# A rooftop air-conditioning unit: a cream, sage or grey sheet-metal cabinet on dark base rails, with
# louvres, an access panel with a latch and a green light, vents on the east side and a big round
# fan on top (a dark ring and well, with spokes).
static func _unit(b, p: Dictionary, h: float, lines: PackedVector2Array, cols: PackedColorArray, glows: Array) -> void:
    var x: float = p.x
    var y: float = p.y
    var w: float = p.w
    var d: float = p.d
    var hh: float = p.h
    var tones := [Color("a8a496"), Color("8f9e96"), Color("a4a8ae")]
    var body: Color = tones[int(p.v) % 3]
    b._roof_box(x, y, w, d, 2.0, h, Color("3a3f48"), Color("2a2e36"), Color("484e58"))
    b._roof_box(x + 1.0, y + 1.0, w - 2.0, d - 2.0, hh - 2.0, h + 2.0, body, body.darkened(0.42), body.lightened(0.14))
    var top: float = h + hh
    # louvres across the front, an access panel with a latch and a light at the right end
    for k in 4:
        var z: float = h + 4.0 + float(k) * 2.4
        Sprites.fill(b, b._quad(Vector2(x + 1.0, y + d - 1.0), Vector2.RIGHT, 2.0, w * 0.6, z, z + 1.1), body.darkened(0.5))
    Sprites.fill(b, b._quad(Vector2(x + 1.0, y + d - 1.0), Vector2.RIGHT, w * 0.68, w - 3.0, h + 3.5, top - 3.0), body.darkened(0.22))
    Sprites.fill(b, b._quad(Vector2(x + 1.0, y + d - 1.0), Vector2.RIGHT, w * 0.68 + 1.2, w * 0.68 + 3.2, h + 5.5, h + 7.0), body.lightened(0.3))
    Sprites.fill(b, b._quad(Vector2(x + 1.0, y + d - 1.0), Vector2.RIGHT, w - 6.0, w - 4.6, top - 5.5, top - 4.2), Color("5be08a"))
    # vents down the east side
    for k in 3:
        var z2: float = h + 4.0 + float(k) * 2.6
        Sprites.fill(b, b._quad(Vector2(x + w - 1.0, y + d - 1.0), Vector2.UP, 3.0, d - 4.0, z2, z2 + 1.1), body.darkened(0.62))
    # the fan on top: a dark ring, a darker well, spokes and a hub
    var cx: float = x + w * 0.4
    var cy: float = y + d * 0.5
    var r: float = minf(w * 0.3, d * 0.36)
    var fan: Vector2 = b._p(cx, cy, top)
    glows.append([fan, r * 1.131 + 0.9, r * 0.566 + 0.5, Color("353a44")])
    glows.append([fan, r * 1.131 * 0.84, r * 0.566 * 0.84, Color("14161c")])
    for k in 4:
        var an: float = float(k) * PI * 0.5 + 0.4
        _line(lines, cols, b._p(cx, cy, top), b._p(cx + r * 0.8 * cos(an), cy + r * 0.8 * sin(an), top), Color("6c7380"))
    glows.append([fan, 1.7, 1.0, Color("8a919c")])

# A water tank: a round wooden drum of staves on four legs, with iron hoops and a conical cap, the
# way they stand on New York roofs. Drawn as strips round the half that faces the camera, shaded from
# the dark east side to the lit south, with a ring of cap triangles.
static func _tower(b, p: Dictionary, h: float, lines: PackedVector2Array, cols: PackedColorArray) -> void:
    var cx: float = p.x + p.w * 0.5
    var cy: float = p.y + p.d * 0.5
    var rad: float = minf(p.w, p.d) * 0.5 - 1.0
    var tall: float = p.h
    var z0: float = h + tall * 0.34
    var z1: float = z0 + tall * 0.40
    var legs := Color("33271f")
    for c in [[-0.75, -0.75], [0.75, -0.75], [-0.75, 0.75], [0.75, 0.75]]:
        _line(lines, cols, b._p(cx + rad * c[0], cy + rad * c[1], h), b._p(cx + rad * c[0], cy + rad * c[1], z0), legs)
    _line(lines, cols, b._p(cx - rad * 0.75, cy + rad * 0.75, h + 3.0), b._p(cx + rad * 0.75, cy + rad * 0.75, z0 - 3.0), legs)
    _line(lines, cols, b._p(cx + rad * 0.75, cy + rad * 0.75, h + 3.0), b._p(cx - rad * 0.75, cy + rad * 0.75, z0 - 3.0), legs)
    _line(lines, cols, b._p(cx - rad * 0.75, cy + rad * 0.75, h + 8.0), b._p(cx + rad * 0.75, cy + rad * 0.75, h + 8.0), legs)
    var steps := 11
    var a_start: float = -PI * 0.25
    var a_span: float = PI
    var dark := Color("4a3220")
    var lit := Color("9a6c42")
    var body_h: float = z1 - z0
    var hoops := [z0 + body_h * 0.2, z0 + body_h * 0.62]
    var apex: Vector2 = b._p(cx, cy, z1 + tall * 0.22)
    for i in steps:
        var a0: float = a_start + a_span * float(i) / float(steps)
        var a1: float = a_start + a_span * float(i + 1) / float(steps)
        var shade: float = clampf(0.5 + 0.5 * sin((a0 + a1) * 0.5), 0.0, 1.0)
        var wood: Color = dark.lerp(lit, shade)
        var q0 := Vector2(cx + rad * cos(a0), cy + rad * sin(a0))
        var q1 := Vector2(cx + rad * cos(a1), cy + rad * sin(a1))
        Sprites.fill(b, PackedVector2Array([b._p(q0.x, q0.y, z0), b._p(q1.x, q1.y, z0), b._p(q1.x, q1.y, z1), b._p(q0.x, q0.y, z1)]), wood)
        var cap: Color = Color("5a3b28").lerp(Color("8a5a3a"), shade)
        Sprites.fill(b, PackedVector2Array([b._p(q0.x, q0.y, z1), b._p(q1.x, q1.y, z1), apex]), cap)
        _line(lines, cols, b._p(q0.x, q0.y, z0), b._p(q0.x, q0.y, z1), wood.darkened(0.3))
        for hz in hoops:
            _line(lines, cols, b._p(q0.x, q0.y, hz), b._p(q1.x, q1.y, hz), Color("23262e"))
        _line(lines, cols, b._p(q0.x, q0.y, z1), b._p(q1.x, q1.y, z1), Color("2a1c12"))
    _line(lines, cols, apex, apex + Vector2(0.0, -4.0), Color("23262e"))

# The house: a pitched roof of terracotta tiles, a gable end and a chimney with smoke.
static func _house(b, r: Rect2, h: float, wall_e: Color, lines: PackedVector2Array, cols: PackedColorArray, glows: Array) -> void:
    var cy: float = (r.position.y + r.end.y) * 0.5
    var rh := 17.0
    var tile := Color("8a3d2f")
    Sprites.fill(b, PackedVector2Array([b._p(r.position.x, r.position.y, h), b._p(r.end.x, r.position.y, h), b._p(r.end.x, cy, h + rh), b._p(r.position.x, cy, h + rh)]), tile.darkened(0.3))
    Sprites.fill(b, PackedVector2Array([b._p(r.end.x, r.end.y, h), b._p(r.end.x, r.position.y, h), b._p(r.end.x, cy, h + rh)]), wall_e)
    Sprites.fill(b, PackedVector2Array([b._p(r.position.x, r.end.y, h), b._p(r.end.x, r.end.y, h), b._p(r.end.x, cy, h + rh), b._p(r.position.x, cy, h + rh)]), tile)
    for k in range(1, 6):
        var t: float = float(k) / 6.0
        var yy: float = lerpf(r.end.y, cy, t)
        _line(lines, cols, b._p(r.position.x, yy, h + rh * t), b._p(r.end.x, yy, h + rh * t), tile.darkened(0.25))
    _line(lines, cols, b._p(r.position.x, cy, h + rh), b._p(r.end.x, cy, h + rh), tile.lightened(0.3))
    _line(lines, cols, b._p(r.end.x, r.end.y, h), b._p(r.end.x, cy, h + rh), tile.lightened(0.18))
    # a chimney near the east end, up through the north slope, with a thread of smoke
    var cx: float = r.end.x - 26.0
    b._roof_box(cx, cy - 8.0, 8.0, 8.0, 14.0, h + rh * 0.55, Color("6a3a32"), Color("48261f"), Color("7c4a40"))
    b._roof_box(cx - 1.0, cy - 9.0, 10.0, 10.0, 2.0, h + rh * 0.55 + 14.0, Color("4a4048"), Color("342c32"), Color("5a5058"))
    var base: Vector2 = b._p(cx + 4.0, cy - 4.0, h + rh * 0.55 + 18.0)
    for k in 4:
        var f: float = float(k) / 3.0
        var rr: float = 2.6 + 1.6 * float(k)
        glows.append([base + Vector2(2.0 * float(k), -5.0 - 7.0 * float(k)), rr, rr, Color(0.78, 0.8, 0.88, 0.30 * (1.0 - f * 0.7))])
