extends RefCounted
# Rooftops. The camera looks down on the city, so a roof is a big part of what is on screen. Each
# building gets a surface (tar paper, gravel or membrane seams with a few stains, leaning toward
# rust, green-grey or concrete), a low parapet with coping, maybe a pipe run, and things standing on
# it chosen by a style: air-conditioning units and a stairwell, a water tower, skylights with an
# antenna and dish, solar panels, a rooftop garden and greenhouse, or a billboard, with hatches,
# vent stacks, crates, barrels and laundry lines among them (and a helipad on some big roofs). The
# house she is heading for has a pitched tile roof and a chimney with smoke. Everything is worked
# out from the building's number, so it is the same every time, and it is drawn with quads and one
# batched run of lines, so it costs few draw calls.
# (Building.setup makes the plan; Building._draw calls paint.)

const Sprites := preload("res://scripts/Sprites.gd")

# What each style puts on a roof: one signature piece in the back corner, and fillers elsewhere.
const STYLES := [
    {"sig": "bulkhead", "fill": ["ac", "ac", "vent", "crates", "laundry"]},
    {"sig": "tower", "fill": ["ac", "hatch", "vent", "barrels", "crates"]},
    {"sig": "antenna", "fill": ["skylight", "skylight", "vent", "ac", "laundry"]},
    {"sig": "solar", "fill": ["solar", "ac", "hatch", "solar", "vent"]},
    {"sig": "greenhouse", "fill": ["bed", "bed", "hatch", "barrels", "bed"]},
    {"sig": "billboard", "fill": ["ac", "vent", "ac", "crates", "barrels"]},
]
const TINTS := [Color("5a4a40"), Color("4a5a52"), Color("6c6c74"), Color("4a4f66")]
const SIGNS := [Color("ff4fa3"), Color("4fe3ff"), Color("ffb23c"), Color("a6ff4f")]

static func _h(a: int, b: int) -> int:
    return posmod((a * 73856093) ^ (b * 19349663) ^ 0x9e3779b1, 1000003)

# Footprint (width, depth) and height of a piece.
static func _size(kind: String, hv: int) -> Vector3:
    match kind:
        "ac": return Vector3(14.0 + float(hv % 7), 10.0 + float(hv % 5), 7.0 + float(hv % 3))
        "bulkhead": return Vector3(22.0, 18.0, 17.0)
        "tower": return Vector3(16.0, 16.0, 34.0)
        "antenna": return Vector3(6.0, 6.0, 27.0)
        "skylight": return Vector3(16.0 + float(hv % 6), 12.0, 4.0)
        "solar": return Vector3(32.0, 20.0, 7.0)
        "greenhouse": return Vector3(26.0, 17.0, 10.0)
        "bed": return Vector3(18.0, 10.0, 3.0)
        "billboard": return Vector3(36.0, 5.0, 30.0)
        "vent": return Vector3(4.0, 4.0, 10.0)
        "crates": return Vector3(13.0, 9.0, 8.0)
        "barrels": return Vector3(12.0, 9.0, 6.0)
        "laundry": return Vector3(26.0, 3.0, 11.0)
        "pad": return Vector3(30.0, 30.0, 1.0)
        _: return Vector3(7.0, 7.0, 3.0)  # hatch

# The pieces on one roof: [{kind, x, y, w, d, h, v}], sorted far to near, plus how far above the
# roof the tallest of them reaches (the building's screen box has to include that), and the surface.
static func plan(rect: Rect2, variant: int, is_house: bool) -> Dictionary:
    if is_house:
        return {"props": [], "extra": 38.0, "surface": 0, "style": -1}
    var inner: Rect2 = rect.grow(-6.0)
    var nx: int = clampi(int(inner.size.x / 50.0), 1, 5)
    var ny: int = clampi(int(inner.size.y / 44.0), 1, 3)
    var sw: float = inner.size.x / float(nx)
    var sh: float = inner.size.y / float(ny)
    var style: int = posmod(variant * 5 + 2, STYLES.size())
    var kinds: Dictionary = STYLES[style]
    var props: Array = []
    var extra := 6.0
    for iy in ny:
        for ix in nx:
            var hv: int = _h(variant, ix * 7 + iy * 13 + 1)
            var kind := ""
            if ix == 0 and iy == 0:
                kind = kinds.sig
                if variant % 11 == 0 and rect.size.x > 200.0 and rect.size.y > 130.0:
                    kind = "pad"  # a helipad on some of the bigger roofs
            elif hv % 100 < 20:
                continue
            else:
                kind = kinds.fill[(hv / 7) % kinds.fill.size()]
            var sz: Vector3 = _size(kind, hv)
            if sz.x + 4.0 > sw or sz.y + 4.0 > sh:
                if ix != 0 or iy != 0:
                    continue
                kind = "ac"  # the signature piece will not fit this small a roof
                sz = _size(kind, hv)
                if sz.x + 4.0 > sw or sz.y + 4.0 > sh:
                    continue
            var fx: float = float((hv / 3) % 100) / 100.0
            var fy: float = float((hv / 11) % 100) / 100.0
            props.append({"kind": kind,
                "x": inner.position.x + float(ix) * sw + 2.0 + fx * (sw - sz.x - 4.0),
                "y": inner.position.y + float(iy) * sh + 2.0 + fy * (sh - sz.y - 4.0),
                "w": sz.x, "d": sz.y, "h": sz.z, "v": hv})
            extra = maxf(extra, sz.z + 3.0)
    props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x + a.y + a.w * 0.5 + a.d * 0.5 < b.x + b.y + b.w * 0.5 + b.d * 0.5)
    return {"props": props, "extra": extra, "surface": (variant / 3) % 3, "style": style}

# Draws the roof of building `b` at height h.
static func paint(b, r: Rect2, h: float, roof: Color, wall_s: Color, wall_e: Color) -> void:
    # each roof leans a little toward rust, green-grey or concrete, so they are not all one colour
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
    if b.house:
        var glows_h: Array = []
        _house(b, r, h, roof, wall_s, wall_e, lines, cols, glows_h)
        _flush(b, lines, cols, glows_h)
        return
    var plan: Dictionary = b.roof_plan
    _surface(b, inner, h, roof, plan.surface, lines, cols)
    _pipes(b, inner, h, lines, cols)
    var glows: Array = []
    for p in plan.props:
        _prop(b, p, h, roof, wall_s, wall_e, lines, cols, glows)
    _flush(b, lines, cols, glows)

static func _line(lines: PackedVector2Array, cols: PackedColorArray, a: Vector2, c: Vector2, color: Color) -> void:
    lines.append(a)
    lines.append(c)
    cols.append(color)  # one colour per segment

# What is left to draw once the roof's fills are done: all its discs together (one texture, so one
# batch), then all its thin lines in one batched call. (Drawing the three kinds in turn rather than
# mixed keeps a roof to a handful of draw calls.)
static func _glow(glows: Array, at: Vector2, rx: float, ry: float, color: Color) -> void:
    glows.append([at, rx, ry, color])

static func _glowd(glows: Array, at: Vector2, r: float, color: Color) -> void:
    glows.append([at, r, r, color])

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

# A pipe or two running across the roof, low on its posts.
static func _pipes(b, inner: Rect2, h: float, lines: PackedVector2Array, cols: PackedColorArray) -> void:
    var v: int = b.variant
    if v % 3 == 0:
        return
    var hv: int = _h(v, 300)
    var along_x: bool = hv % 2 == 0
    var pipe := Color("747c88")
    if along_x:
        var y: float = inner.position.y + 6.0 + float((hv / 2) % 100) / 100.0 * maxf(inner.size.y - 12.0, 1.0)
        var x0: float = inner.position.x + 6.0
        var x1: float = inner.end.x - 6.0
        Sprites.fill(b, PackedVector2Array([b._p(x0, y, h + 2.5), b._p(x1, y, h + 2.5), b._p(x1, y + 2.0, h + 2.5), b._p(x0, y + 2.0, h + 2.5)]), pipe.lightened(0.15))
        Sprites.fill(b, b._quad(Vector2(x0, y + 2.0), Vector2.RIGHT, 0.0, x1 - x0, h + 1.0, h + 2.5), pipe.darkened(0.2))
        var u: float = x0 + 6.0
        while u < x1:
            _line(lines, cols, b._p(u, y + 1.0, h), b._p(u, y + 1.0, h + 2.5), Color("3a4049"))
            u += 18.0
    else:
        var x: float = inner.position.x + 6.0 + float((hv / 2) % 100) / 100.0 * maxf(inner.size.x - 12.0, 1.0)
        var y0: float = inner.position.y + 6.0
        var y1: float = inner.end.y - 6.0
        Sprites.fill(b, PackedVector2Array([b._p(x, y0, h + 2.5), b._p(x + 2.0, y0, h + 2.5), b._p(x + 2.0, y1, h + 2.5), b._p(x, y1, h + 2.5)]), pipe.lightened(0.15))
        Sprites.fill(b, b._quad(Vector2(x + 2.0, y1), Vector2.UP, 0.0, y1 - y0, h + 1.0, h + 2.5), pipe.darkened(0.3))

static func _prop(b, p: Dictionary, h: float, roof: Color, wall_s: Color, wall_e: Color, lines: PackedVector2Array, cols: PackedColorArray, glows: Array) -> void:
    var x: float = p.x
    var y: float = p.y
    var w: float = p.w
    var d: float = p.d
    var hh: float = p.h
    var hv: int = p.v
    var lit: bool = not b._blacked_out(b.variant * 3 + hv)
    match p.kind:
        "ac":
            b._roof_box(x, y, w, d, hh, h, Color("7e8896"), Color("535b69"), Color("a1abb8"))
            var gx: float = x + w * 0.5
            var gy: float = y + d * 0.5
            var rr: float = minf(w, d) * 0.3
            _quad(b, gx - rr, gy - rr, gx + rr, gy + rr, h + hh, Color("2a2f3a"))
            _line(lines, cols, b._p(gx - rr, gy, h + hh), b._p(gx + rr, gy, h + hh), Color("b9c2cf"))
            _line(lines, cols, b._p(gx, gy - rr, h + hh), b._p(gx, gy + rr, h + hh), Color("b9c2cf"))
            for k in 3:
                var z0: float = h + 1.5 + float(k) * 2.2
                Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, 2.0, w - 2.0, z0, z0 + 1.0), Color("3a414d"))
        "bulkhead":
            b._roof_box(x, y, w, d, hh, h, wall_s.lightened(0.1), wall_e.lightened(0.04), roof.lightened(0.2))
            Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, w * 0.55, w * 0.55 + 7.0, h, h + 11.0), Color("14161d"))
            if lit:
                Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, w * 0.55 + 1.5, w * 0.55 + 5.5, h + 6.5, h + 9.5), b.window_light)
                _glowd(glows, b._p(x + w * 0.55 + 3.5, y + d, h + 12.5), 2.2, Color(b.window_light, 0.35))
            _line(lines, cols, b._p(x, y + d, h + hh - 1.5), b._p(x + w, y + d, h + hh - 1.5), wall_s.lightened(0.3))
        "tower":
            var wood := Color("6b4a2e")
            for c in [[x + 1.5, y + 1.5], [x + w - 1.5, y + 1.5], [x + 1.5, y + d - 1.5], [x + w - 1.5, y + d - 1.5]]:
                _line(lines, cols, b._p(c[0], c[1], h), b._p(c[0], c[1], h + 12.0), Color("3a2c22"))
            _line(lines, cols, b._p(x + 1.5, y + d - 1.5, h + 2.0), b._p(x + w - 1.5, y + d - 1.5, h + 10.0), Color("3a2c22"))
            _line(lines, cols, b._p(x + w - 1.5, y + d - 1.5, h + 2.0), b._p(x + 1.5, y + d - 1.5, h + 10.0), Color("3a2c22"))
            b._roof_box(x + 1.0, y + 1.0, w - 2.0, d - 2.0, 14.0, h + 12.0, wood, wood.darkened(0.35), wood.lightened(0.15))
            for z in [h + 16.0, h + 22.0]:
                _line(lines, cols, b._p(x + 1.0, y + d - 1.0, z), b._p(x + w - 1.0, y + d - 1.0, z), Color("23262e"))
                _line(lines, cols, b._p(x + w - 1.0, y + d - 1.0, z), b._p(x + w - 1.0, y + 1.0, z), Color("23262e"))
            var u: float = x + 4.0
            while u < x + w - 2.0:
                _line(lines, cols, b._p(u, y + d - 1.0, h + 12.0), b._p(u, y + d - 1.0, h + 26.0), wood.darkened(0.25))
                u += 3.5
            var cx: float = x + w * 0.5
            var cy: float = y + d * 0.5
            Sprites.fill(b, PackedVector2Array([b._p(x + 1.0, y + d - 1.0, h + 26.0), b._p(x + w - 1.0, y + d - 1.0, h + 26.0), b._p(cx, cy, h + 33.0)]), Color("4a3426"))
            Sprites.fill(b, PackedVector2Array([b._p(x + w - 1.0, y + d - 1.0, h + 26.0), b._p(x + w - 1.0, y + 1.0, h + 26.0), b._p(cx, cy, h + 33.0)]), Color("34231a"))
        "antenna":
            var mx: float = x + w * 0.5
            var my: float = y + d * 0.5
            var tip: Vector2 = b._p(mx, my, h + hh)
            _line(lines, cols, b._p(mx, my, h), tip, Color("a4adbc"))
            for z in [h + 15.0, h + 20.0]:
                _line(lines, cols, b._p(mx - 4.0, my, z), b._p(mx + 4.0, my, z), Color("a4adbc"))
            _glow(glows, b._p(mx + 3.0, my + 2.0, h + 11.0), 5.0, 3.6, Color("747d8c"))
            _glow(glows, b._p(mx + 3.0, my + 2.0, h + 11.0) + Vector2(0.0, -0.8), 4.4, 3.0, Color("c9d0dc"))
            if lit:
                _glowd(glows, tip + Vector2(0.0, -1.0), 4.5, Color(1.0, 0.2, 0.15, 0.22))
                _glowd(glows, tip + Vector2(0.0, -1.0), 1.3, Color(1.0, 0.3, 0.25, 0.95))
        "skylight":
            b._roof_box(x, y, w, d, hh - 1.0, h, Color("3a4150"), Color("272c37"), Color("4b5365"))
            var glass: Color = Color(b.window_light.lerp(Color(0.8, 0.92, 1.0), 0.5)) if lit else Color("1b2433")
            _quad(b, x + 1.5, y + 1.5, x + w - 1.5, y + d - 1.5, h + hh - 1.0, glass)
            _line(lines, cols, b._p(x + 1.5, y + d - 1.5, h + hh - 1.0), b._p(x + w - 1.5, y + 1.5, h + hh - 1.0), Color(1, 1, 1, 0.35))
            if lit:
                _glow(glows, b._p(x + w * 0.5, y + d * 0.5, h + hh), w * 0.9, d * 0.7, Color(b.window_light, 0.12))
        "solar":
            var rows := 2
            var pw: float = (w - 2.0) / 3.0
            var rd: float = (d - 2.0) / float(rows)
            for row in rows:
                var ry: float = y + 1.0 + float(row) * rd
                for col in 3:
                    var px: float = x + 1.0 + float(col) * pw
                    Sprites.fill(b, PackedVector2Array([b._p(px, ry + rd - 1.0, h + 2.0), b._p(px + pw - 1.0, ry + rd - 1.0, h + 2.0),
                        b._p(px + pw - 1.0, ry, h + 6.0), b._p(px, ry, h + 6.0)]), Color("1f2d4a"))
                    _line(lines, cols, b._p(px, ry + (rd - 1.0) * 0.5, h + 4.0), b._p(px + pw - 1.0, ry + (rd - 1.0) * 0.5, h + 4.0), Color("5f7aa8"))
                    _line(lines, cols, b._p(px + (pw - 1.0) * 0.5, ry + rd - 1.0, h + 2.0), b._p(px + (pw - 1.0) * 0.5, ry, h + 6.0), Color("5f7aa8"))
        "greenhouse":
            for k in 4:
                _glowd(glows, b._p(x + 4.0 + float(k) * 5.5, y + d * 0.5 + float(k % 2) * 3.0, h + 4.0) + Vector2(0.0, -1.0), 2.8 + float(k % 2), Color("4f9a58") if k % 2 == 0 else Color("3b7a45"))
            Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, 0.0, w, h, h + hh - 3.0), Color(0.7, 0.88, 0.8, 0.30))
            Sprites.fill(b, b._quad(Vector2(x + w, y + d), Vector2.UP, 0.0, d, h, h + hh - 3.0), Color(0.5, 0.7, 0.62, 0.30))
            Sprites.fill(b, PackedVector2Array([b._p(x, y + d, h + hh - 3.0), b._p(x + w, y + d, h + hh - 3.0), b._p(x + w, y + d * 0.5, h + hh), b._p(x, y + d * 0.5, h + hh)]), Color(0.75, 0.92, 0.85, 0.34))
            for u2 in [0.0, w * 0.5, w]:
                _line(lines, cols, b._p(x + u2, y + d, h), b._p(x + u2, y + d, h + hh - 3.0), Color("d8e6dc"))
            _line(lines, cols, b._p(x, y + d * 0.5, h + hh), b._p(x + w, y + d * 0.5, h + hh), Color("d8e6dc"))
        "bed":
            b._roof_box(x, y, w, d, hh, h, Color("5a4030"), Color("3b2a1e"), Color("2f2217"))
            for k in 4:
                var tone: Color = Color("3f7a4a") if (k + hv) % 2 == 0 else Color("56984f")
                _glowd(glows, b._p(x + 3.0 + float(k) * (w - 6.0) / 3.0, y + d * 0.5, h + hh + 1.5) + Vector2(0.0, -1.5), 2.6 + float((k + hv) % 3) * 0.5, tone)
        "billboard":
            var neon: Color = SIGNS[hv % SIGNS.size()]
            for px2 in [x + 5.0, x + w - 5.0]:
                _line(lines, cols, b._p(px2, y + 2.0, h), b._p(px2, y + 2.0, h + 15.0), Color("2d3342"))
            Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, 0.0, w, h + 14.0, h + 28.0), Color("14161d"))
            var panel: Color = neon if lit else neon.darkened(0.7)
            Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, 1.5, w - 1.5, h + 15.5, h + 26.5), panel)
            for k in 3:
                var bw: float = (w - 8.0) * (0.45 + float((hv / (k + 3)) % 50) / 100.0)
                Sprites.fill(b, b._quad(Vector2(x, y + d), Vector2.RIGHT, 4.0, 4.0 + bw, h + 17.5 + float(k) * 3.0, h + 19.0 + float(k) * 3.0), Color(1, 1, 1, 0.78 if lit else 0.15))
            Sprites.fill(b, b._quad(Vector2(x + w, y + d), Vector2.UP, 0.0, d, h + 14.0, h + 28.0), Color("0c0d12"))
            if lit:
                _glow(glows, b._p(x + w * 0.5, y + d, h + 21.0), w * 0.8, 9.0, Color(neon, 0.10))
        "crates":
            b._roof_box(x, y, 8.0, 8.0, 6.0, h, Color("7a5a38"), Color("523a22"), Color("8c6a44"))
            b._roof_box(x + 6.0, y + 1.0, 7.0, 8.0, 8.0, h, Color("6e5032"), Color("48321d"), Color("826040"))
            _line(lines, cols, b._p(x, y + 8.0, h + 3.0), b._p(x + 8.0, y + 8.0, h + 3.0), Color("3a2916"))
        "barrels":
            for k in 3:
                var bx: float = x + 3.0 + float(k) * 3.6
                var by: float = y + 4.0 + float(k % 2) * 2.0
                Sprites.fill(b, PackedVector2Array([b._p(bx - 2.0, by + 2.0, h), b._p(bx + 2.0, by + 2.0, h), b._p(bx + 2.0, by + 2.0, h + 6.0), b._p(bx - 2.0, by + 2.0, h + 6.0)]), Color("3f5a78") if (k + hv) % 2 == 0 else Color("7a3a30"))
                _glow(glows, b._p(bx, by, h + 6.0), 2.4, 1.5, Color("9aa4b4"))
        "laundry":
            for px3 in [x + 1.0, x + w - 1.0]:
                _line(lines, cols, b._p(px3, y + 1.5, h), b._p(px3, y + 1.5, h + 11.0), Color("5a4a3a"))
            _line(lines, cols, b._p(x + 1.0, y + 1.5, h + 10.0), b._p(x + w - 1.0, y + 1.5, h + 9.0), Color("b9b2a2"))
            var rags := [Color("c8473e"), Color("e6e0d0"), Color("4a78b8"), Color("d9b43c"), Color("e6e0d0")]
            for k in 5:
                var lx: float = x + 3.0 + float(k) * 4.4
                Sprites.fill(b, b._quad(Vector2(lx, y + 1.5), Vector2.RIGHT, 0.0, 3.0, h + 5.0 - float(k) * 0.2, h + 9.6 - float(k) * 0.2), rags[(k + hv) % rags.size()])
        "pad":
            var pc: Vector2 = b._p(x + w * 0.5, y + d * 0.5, h)
            Sprites.ellipse(b, pc, 21.0, 12.0, Color(0.85, 0.85, 0.9, 0.55))
            Sprites.ellipse(b, pc, 18.5, 10.4, Color(0.1, 0.12, 0.16, 0.9))
            var hx: float = x + w * 0.5
            var hy: float = y + d * 0.5
            var padc := Color("e8d070")
            _quad(b, hx - 6.0, hy - 7.0, hx - 4.0, hy + 7.0, h, padc)
            _quad(b, hx + 4.0, hy - 7.0, hx + 6.0, hy + 7.0, h, padc)
            _quad(b, hx - 6.0, hy - 1.0, hx + 6.0, hy + 1.0, h, padc)
        "vent":
            b._roof_box(x, y, w, d, hh, h, Color("6b727d"), Color("484e58"), Color("8a919c"))
            b._roof_box(x - 1.0, y - 1.0, w + 2.0, d + 2.0, 1.5, h + hh, Color("535a66"), Color("39404a"), Color("7a8190"))
        _:  # a hatch
            b._roof_box(x, y, w, d, hh, h, roof.lightened(0.1), roof.darkened(0.2), roof.lightened(0.25))
            _line(lines, cols, b._p(x + 1.0, y + 1.0, h + hh), b._p(x + w - 1.0, y + d - 1.0, h + hh), Color("d9b43c"))

# The house: a pitched roof of terracotta tiles, a gable end and a chimney with smoke.
static func _house(b, r: Rect2, h: float, roof: Color, wall_s: Color, wall_e: Color, lines: PackedVector2Array, cols: PackedColorArray, glows: Array) -> void:
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
        _glowd(glows, base + Vector2(2.0 * float(k), -5.0 - 7.0 * float(k)), 2.6 + 1.6 * float(k), Color(0.78, 0.8, 0.88, 0.30 * (1.0 - f * 0.7)))
