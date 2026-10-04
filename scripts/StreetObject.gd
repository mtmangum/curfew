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
    Kind.MAILBOX: 22.0, Kind.BENCH: 22.0, Kind.PHONE: 48.0, Kind.TREE: 60.0,
    Kind.CONES: 10.0, Kind.PLANTER: 18.0, Kind.FOUNTAIN: 22.0,
}

var kind: int = Kind.DUMPSTER
var marked := false  # a hydrant Stella has already used
var working := false  # a phone booth that still takes a call: lit up, with a glow on the pavement
var main  # only a fountain needs it: to animate its water while it is on screen
var flowing := true  # a fountain that is switched off: still, dull water and no jet
var water_t := 0.0
var occupant := 0       # a bench with a zombie asleep on it (1); StreetNpc wakes him and clears it
var occupant_frame := 0

# Pixel-art trees (assets/sprites/tree, made by docs/tools/render_trees.mjs): mostly oaks
# and elms, some pines, the odd autumn tree.
const TREE_KINDS := [0, 1, 0, 3, 1, 0, 2, 3]
static var tree_textures: Array = []

static func size_of(k: int) -> Vector2:
    return SIZES[k]

func setup_object(r: Rect2, k: int, seed_value: int) -> void:
    rect = r
    kind = k
    variant = seed_value
    floors = 0
    height = HEIGHTS[k]
    fades = false  # street furniture and trees are small: they never hide her enough to be worth ghosting
    if k == Kind.TREE or k == Kind.BENCH:
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    update_screen_box()

# A tree's crown spreads well beyond its trunk, so widen the on-screen box for sorting.
func update_screen_box() -> void:
    super.update_screen_box()
    if kind == Kind.TREE:
        screen_box = screen_box.grow_individual(18.0, 4.0, 18.0, 0.0)

func _ready() -> void:
    super._ready()
    set_process(kind == Kind.FOUNTAIN)  # (a script with _process is switched on when it is ready, so do this here)

# Switches a fountain off for variety: no jet, no ripples, and nothing to redraw.
func turn_off() -> void:
    flowing = false
    set_process(false)
    queue_redraw()

# A fountain's water moves: redraw it every frame while it is near the view.
func _process(delta: float) -> void:
    if main == null or not main.is_booted:
        return
    water_t += delta
    if Sprites.iso(rect.get_center()).distance_to(Sprites.iso(main.focus)) < 640.0:
        queue_redraw()

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
    Sprites.fill(self, PackedVector2Array([
        _p(sh.position.x, sh.position.y, 0.0), _p(sh.end.x, sh.position.y, 0.0),
        _p(sh.end.x, sh.end.y, 0.0), _p(sh.position.x, sh.end.y, 0.0)]), Color(0, 0, 0, 0.3))
    match kind:
        Kind.DUMPSTER:
            var paint: Color = [Color("2f5a43"), Color("2f4f6a"), Color("6a3f2c")][variant % 3]
            _slab(r.position.x, r.position.y, r.size.x, r.size.y, 15.0, 3.0, paint)
            _slab(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, r.size.y + 2.0, 3.0, 18.0, paint.darkened(0.45))
            # a stripe and two small wheels on the long face
            Sprites.fill(self, _quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, 3.0, r.size.x - 3.0, 9.0, 11.0), paint.lightened(0.25))
            for u in [5.0, r.size.x - 5.0]:
                Sprites.fill(self, _quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, u - 1.5, u + 1.5, 0.0, 3.0), Color("0b0c10"))
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
            Sprites.fill(self, _quad(Vector2(cx - 4.0, cy + 4.0), Vector2.RIGHT, 1.5, 6.5, 15.0, 16.5), Color("0e1320"))
        Kind.BENCH:
            var wood2 := Color("5d4128")
            for leg in [r.position.x + 2.0, r.end.x - 4.0]:
                _slab(leg, r.position.y + 3.0, 2.0, 4.0, 6.0, 0.0, Color("2f333f"))
            _slab(r.position.x, r.position.y + 2.0, r.size.x, 7.0, 3.0, 6.0, wood2)
            _slab(r.position.x, r.position.y, r.size.x, 2.0, 7.0, 9.0, wood2.darkened(0.15))
            if occupant == 1:
                _bench_sleeper(r)
        Kind.PHONE:
            _phone_booth(r)
        Kind.TREE:
            _tree(cx, cy)
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
            Sprites.fill(self, PackedVector2Array([
                _p(r.position.x + 1.5, r.position.y + 1.5, 8.0), _p(r.end.x - 1.5, r.position.y + 1.5, 8.0),
                _p(r.end.x - 1.5, r.end.y - 1.5, 8.0), _p(r.position.x + 1.5, r.end.y - 1.5, 8.0)]), Color("2a2118"))
            var bush: Vector2 = Sprites.proj(Vector2(cx, cy), 12.0)
            Sprites.disc(self, bush + Vector2(-4, 1), 5.0, Color("1f3a2d"))
            Sprites.disc(self, bush + Vector2(4, 1), 5.0, Color("1f3a2d"))
            Sprites.disc(self, bush + Vector2(0, -3), 6.0, Color("2a5038"))
            Sprites.disc(self, bush + Vector2(-2, -5), 3.0, Color("3f7050"))

# A phone booth: glass on every side with the telephone inside, four posts, and a sign on
# the roof with a handset on it. A working one is lit and spills light on the pavement; the
# rest are dark (and so is a working one once its call has been used).
func _phone_booth(r: Rect2) -> void:
    var cx: float = r.get_center().x
    var cy: float = r.get_center().y
    var x0: float = r.position.x
    var y0: float = r.position.y
    var x1: float = r.end.x
    var y1: float = r.end.y
    var frame := Color("3d5278") if working else Color("2b3040")
    var glass := Color("8defff") if working else Color("46566c")
    if working:
        for ring in [[22.0, 0.09], [13.0, 0.12]]:
            var pool := PackedVector2Array()
            for i in 18:
                var a: float = TAU * float(i) / 18.0
                pool.append(_p(cx + cos(a) * ring[0], cy + sin(a) * ring[0], 0.0))
            Sprites.fill(self, pool, Color(0.45, 0.92, 1.0, ring[1]))
    _slab(x0, y0, r.size.x, r.size.y, 3.0, 0.0, frame.darkened(0.35))
    _slab(x0, y0, 1.8, 1.8, 36.0, 3.0, frame.darkened(0.15))
    # the telephone on the back wall, seen through the glass
    _slab(cx - 2.6, y0 + 1.8, 5.2, 2.2, 10.0, 17.0, Color("8a93a6"))
    var lit := Color("c4f7ff") if working else Color("232a36")
    Sprites.fill(self, _quad(Vector2(cx - 2.6, y0 + 4.0), Vector2.RIGHT, 0.9, 4.3, 24.0, 26.2), lit)
    Sprites.fill(self, _quad(Vector2(cx - 2.6, y0 + 4.0), Vector2.RIGHT, 0.9, 4.3, 19.0, 22.5), Color("4b5366"))
    Sprites.fill(self, _quad(Vector2(cx - 2.6, y0 + 4.0), Vector2.RIGHT, 0.2, 0.9, 20.0, 27.0), Color("15181f"))  # the handset
    _slab(x1 - 1.8, y0, 1.8, 1.8, 36.0, 3.0, frame)
    _slab(x0, y1 - 1.8, 1.8, 1.8, 36.0, 3.0, frame)
    # glass in three panes up each visible side, with a frame bar between them
    var pane := Color(glass.r, glass.g, glass.b, 0.5 if working else 0.3)
    var pane_e := Color(glass.r * 0.7, glass.g * 0.7, glass.b * 0.7, pane.a * 0.8)
    for k in 3:
        var z0: float = 5.0 + float(k) * 10.4
        Sprites.fill(self, _quad(Vector2(x0, y1), Vector2.RIGHT, 1.8, r.size.x - 1.8, z0 + 0.8, z0 + 10.0), pane)
        Sprites.fill(self, _quad(Vector2(x1, y1), Vector2.UP, 1.8, r.size.y - 1.8, z0 + 0.8, z0 + 10.0), pane_e)
    for k in 4:
        var zb: float = 4.4 + float(k) * 10.4
        Sprites.fill(self, _quad(Vector2(x0, y1), Vector2.RIGHT, 0.0, r.size.x, zb, zb + 1.0), frame)
        Sprites.fill(self, _quad(Vector2(x1, y1), Vector2.UP, 0.0, r.size.y, zb, zb + 1.0), frame.darkened(0.3))
    _slab(x1 - 1.8, y1 - 1.8, 1.8, 1.8, 36.0, 3.0, frame.lightened(0.12))
    # roof and the lit sign with a handset on it
    _slab(x0 - 1.0, y0 - 1.0, r.size.x + 2.0, r.size.y + 2.0, 2.5, 39.0, frame.darkened(0.2))
    var sign_c := Color("66e8ff") if working else Color("4a5262")
    _slab(cx - 5.0, cy - 5.0, 10.0, 10.0, 6.5, 41.5, frame.darkened(0.3))
    Sprites.fill(self, _quad(Vector2(cx - 5.0, cy + 5.0), Vector2.RIGHT, 0.6, 9.4, 42.1, 47.4), sign_c)
    Sprites.fill(self, _quad(Vector2(cx + 5.0, cy + 5.0), Vector2.UP, 0.6, 9.4, 42.1, 47.4), sign_c.darkened(0.35))
    var ink := Color("0e1a30")
    var so := Vector2(cx - 5.0, cy + 5.0)
    Sprites.fill(self, _quad(so, Vector2.RIGHT, 2.3, 7.7, 45.4, 46.7), ink)
    Sprites.fill(self, _quad(so, Vector2.RIGHT, 2.3, 4.0, 43.3, 46.7), ink)
    Sprites.fill(self, _quad(so, Vector2.RIGHT, 6.0, 7.7, 43.3, 46.7), ink)

# A zombie stretched out asleep on the bench (a sprite drawn as part of the bench, so it sorts with it).
static var sleeper_textures: Array = []

func _bench_sleeper(r: Rect2) -> void:
    if sleeper_textures.is_empty():
        for n in ["lie", "lie1"]:
            sleeper_textures.append(Sprites.load_tex("res://assets/sprites/zombie/%s.png" % n))
    var tex: Texture2D = sleeper_textures[occupant_frame % 2]
    var size: Vector2 = tex.get_size() * 0.36
    var seat: Vector2 = _p(r.get_center().x, r.get_center().y, 9.0)
    draw_texture_rect(tex, Rect2(seat - Vector2(size.x * 0.5, size.y * 0.62), size), false)

# A stone basin with a central jet. The water is alive: a shimmer on the surface, ripples that
# spread from the jet's foot, a fan of droplets thrown up from the top that arc out and fall
# back into the basin (each one starting a small ripple where it lands), and a pulsing column.
const DROPS := 14
const WATER_TOP := 8.0   # the water's surface
const JET_TOP := 18.0    # where the column and the droplets start

func _fountain(r: Rect2) -> void:
    var stone := Color("6a6f80")
    _slab(r.position.x, r.position.y, r.size.x, r.size.y, 8.0, 0.0, stone)
    var cx: float = r.get_center().x
    var cy: float = r.get_center().y
    if not flowing:
        _fountain_off(r, cx, cy, stone)
        return
    var t: float = water_t
    var shimmer: float = 0.5 + 0.5 * sin(t * 1.7)
    var water := Color("5b8fb8").lerp(Color("6fa3cc"), shimmer * 0.5)
    Sprites.fill(self, PackedVector2Array([
        _p(r.position.x + 3.0, r.position.y + 3.0, WATER_TOP), _p(r.end.x - 3.0, r.position.y + 3.0, WATER_TOP),
        _p(r.end.x - 3.0, r.end.y - 3.0, WATER_TOP), _p(r.position.x + 3.0, r.end.y - 3.0, WATER_TOP)]), water)
    var foam := Color(0.88, 0.95, 1.0)
    # glints sliding over the surface
    for k in 5:
        var a: float = t * (0.35 + 0.05 * float(k)) + float(k) * 1.26
        var rad: float = 8.0 + float(k % 3) * 2.6
        var g0: Vector2 = _p(cx + cos(a) * rad, cy + sin(a) * rad, WATER_TOP)
        var g1: Vector2 = _p(cx + cos(a + 0.22) * rad, cy + sin(a + 0.22) * rad, WATER_TOP)
        draw_line(g0, g1, Color(foam.r, foam.g, foam.b, 0.25 + 0.4 * (0.5 + 0.5 * sin(t * 2.3 + float(k) * 1.9))), 1.0)
    # ripples spreading from the foot of the jet
    for k in 2:
        var u: float = fposmod(t * 0.55 + float(k) * 0.5, 1.0)
        _ripple(Vector2(cx, cy), 3.0 + u * 10.5, 0.55 * (1.0 - u), foam)
    # the droplets: where each lands, a ring is still spreading while the next one climbs
    for i in DROPS:
        var ang: float = float(i) * 2.399963
        var reach: float = 5.5 + float(i % 4) * 2.7
        var dir := Vector2(cos(ang), sin(ang))
        var u2: float = fposmod(t * 0.95 + float(i) / float(DROPS), 1.0)
        if u2 < 0.34:
            _ripple(Vector2(cx, cy) + dir * reach, 0.6 + u2 * 8.0, 0.5 * (1.0 - u2 / 0.34), foam)
    _slab(cx - 2.0, cy - 2.0, 4.0, 4.0, 10.0, WATER_TOP, stone.lightened(0.15))
    # the column, pulsing a little
    var pulse: float = 5.0 + 2.2 * sin(t * 5.1) + 1.2 * sin(t * 8.3)
    draw_line(_p(cx, cy, JET_TOP), _p(cx, cy, JET_TOP + pulse), Color(foam.r, foam.g, foam.b, 0.8), 2.0)
    Sprites.disc(self, _p(cx, cy, JET_TOP + pulse), 1.6, Color(1.0, 1.0, 1.0, 0.9))
    for i in DROPS:
        var ang2: float = float(i) * 2.399963
        var reach2: float = 5.5 + float(i % 4) * 2.7
        var dir2 := Vector2(cos(ang2), sin(ang2))
        var u3: float = fposmod(t * 0.95 + float(i) / float(DROPS), 1.0)
        for trail in 2:
            var u4: float = u3 - float(trail) * 0.055
            if u4 < 0.0:
                continue
            # up and out, then down onto the water
            var z: float = JET_TOP + 4.0 * 13.0 * u4 * (1.0 - u4) - (JET_TOP - WATER_TOP) * u4
            var at := Vector2(cx, cy) + dir2 * reach2 * u4
            Sprites.disc(self, _p(at.x, at.y, z), 1.15 - 0.4 * float(trail), Color(foam.r, foam.g, foam.b, 0.92 - 0.5 * float(trail)))

# Switched off: the water has gone still, darker and a little murky, with a few leaves on it,
# and the jet's stump stands dry in the middle.
func _fountain_off(r: Rect2, cx: float, cy: float, stone: Color) -> void:
    Sprites.fill(self, PackedVector2Array([
        _p(r.position.x + 3.0, r.position.y + 3.0, WATER_TOP - 1.0), _p(r.end.x - 3.0, r.position.y + 3.0, WATER_TOP - 1.0),
        _p(r.end.x - 3.0, r.end.y - 3.0, WATER_TOP - 1.0), _p(r.position.x + 3.0, r.end.y - 3.0, WATER_TOP - 1.0)]), Color("3f5f78"))
    # a faint sheen and a few leaves
    draw_line(_p(cx - 11.0, cy - 6.0, WATER_TOP - 1.0), _p(cx - 4.0, cy - 9.0, WATER_TOP - 1.0), Color(0.8, 0.9, 1.0, 0.18), 1.0)
    for leaf in [[-9.0, 6.0], [7.0, 9.0], [10.0, -4.0], [-4.0, -10.0]]:
        var p: Vector2 = _p(cx + leaf[0], cy + leaf[1], WATER_TOP - 1.0)
        draw_rect(Rect2(p.x - 1.0, p.y - 0.5, 2.0, 1.0), Color("6b5a2e") if int(leaf[0]) % 2 == 0 else Color("4d6034"))
    _slab(cx - 2.0, cy - 2.0, 4.0, 4.0, 10.0, WATER_TOP - 1.0, stone.lightened(0.05))

# A ring on the surface of the water, flattened by the view like everything on the ground.
func _ripple(at: Vector2, radius: float, alpha: float, col: Color) -> void:
    if alpha <= 0.02:
        return
    var pts := PackedVector2Array()
    for k in 13:
        var a: float = TAU * float(k) / 12.0
        pts.append(_p(at.x + cos(a) * radius, at.y + sin(a) * radius, WATER_TOP))
    Sprites.polyline(self, pts, Color(col.r, col.g, col.b, alpha), 1.0)

# A tree: a soft shadow under the crown on the ground, then the sprite standing on its
# trunk (44x60 world units, the foot at the bottom centre).
func _tree(cx: float, cy: float) -> void:
    if tree_textures.is_empty():
        for i in 4:
            tree_textures.append(Sprites.load_tex("res://assets/sprites/tree/tree%d.png" % i))
    var ring := PackedVector2Array()
    for i in 16:
        var a: float = TAU * float(i) / 16.0
        ring.append(_p(cx + 3.0 + cos(a) * 15.0, cy + 4.0 + sin(a) * 13.0, 0.0))
    Sprites.fill(self, ring, Color(0, 0, 0, 0.2))
    var tex: Texture2D = tree_textures[TREE_KINDS[variant % TREE_KINDS.size()]]
    var foot: Vector2 = _p(cx, cy, 0.0)
    draw_texture_rect(tex, Rect2(foot + Vector2(-22.0, -58.0), Vector2(44.0, 60.0)), false)

