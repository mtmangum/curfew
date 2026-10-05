extends Node2D
# A building drawn as an isometric box: a roof and two lit walls (south and
# east). Its footprint `rect` is also the collision wall (for the playable
# ones). Fades out when someone is standing behind it so they stay visible.
# Buildings vary by number of storeys, wall colour, ground-floor style and the
# clutter on the roof.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")
const RoofsScript := preload("res://scripts/Roofs.gd")
const RoofFanScript := preload("res://scripts/RoofFan.gd")
const RoofPropsScript := preload("res://scripts/RoofProps.gd")
const ShopWindowsScript := preload("res://scripts/ShopWindows.gd")
const BeamSpotsScript := preload("res://scripts/BeamSpots.gd")
const HouseLotScript := preload("res://scripts/HouseLot.gd")
const NeonSignScript := preload("res://scripts/NeonSign.gd")

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
const UPPER_AWNING_Z := 43.0  # top of an upper-floor awning (just above the first-floor windows)

var rect := Rect2()
var floors := 2
var palette := 0
var shop := false  # ground floor is a shopfront with an awning
var house := false
var fades := true  # goes see-through when Nicole is hidden behind it (buildings only: street furniture and cars stay solid)
var height := 52.0
var variant := 0  # drives the deterministic details (doors, roof units)
var dark_windows := 0.0  # fraction of the lit windows that are out (a blackout); never the house
var window_light := LIT  # colour of a lit window
var boarded := 0.0   # fraction of the dark windows boarded up (an abandoned neighbourhood)
var graffiti := false  # tags sprayed on the ground-floor walls
var screen_box := Rect2()  # where it covers on screen, in iso coordinates from the world origin
var roof_plan := {}  # what stands on the roof (Roofs.gd)
var roof_extra := 0.0  # how far the tallest of it reaches above the roof
var roof_props: Node2D = null  # the units and water tank on the roof that stay over the building, a piece of its own so it fades harder
var roof_over: Node2D = null  # the ones that would show outside its outline when it is see-through: hidden altogether then
var fans: Array = []  # the RoofFans of the units on this roof whose fans turn
var neon := 0.0  # level 5 and up: this building may carry a neon sign (NeonSign.gd)
var neon_sign: Node2D = null
var spots: Node2D = null  # where cops' torch beams land on its walls (BeamSpots.gd), made the first time one does

func setup(r: Rect2, floor_count: int, palette_index: int, is_shop: bool, is_house: bool, seed_value: int) -> void:
    rect = r
    floors = floor_count
    palette = palette_index
    shop = is_shop
    house = is_house
    variant = seed_value
    height = float(floors) * FLOOR + 4.0
    if house:
        height = HouseLotScript.WALL_H + 31.0  # (the house inside its lot: walls, pitched roof and chimney)
    roof_plan = RoofsScript.plan(rect, variant, house)
    roof_extra = float(roof_plan.extra)
    update_screen_box()

# The iso-space bounds of the whole box, roof and all; used to skip things that
# can't be on screen (and pairs that can't overlap) when depth sorting.
func update_screen_box() -> void:
    var s: float = Sprites.ISO
    var left: float = (rect.position.x - rect.end.y) * s
    var right: float = (rect.end.x - rect.position.y) * s
    var top: float = (rect.position.x + rect.position.y) * s * 0.5 - height - roof_extra
    var bottom: float = (rect.end.x + rect.end.y) * s * 0.5
    screen_box = Rect2(left, top, right - left, bottom - top)

func _ready() -> void:
    queue_redraw()
    _make_roof_props()
    _make_neon_sign()

# What stands on the roof, as pieces of their own: the ones that stay over the building, and the ones
# that would show outside its outline when it is see-through (a tall water tank near the back edge),
# which are hidden altogether then. Each has the fans on it that turn (each a small piece that draws
# only its spokes).
# On level 5 and up, about half the buildings have a neon sign on the south or east wall.
func _make_neon_sign() -> void:
    if neon <= 0.0 or house or floors <= 0:
        return
    var plan: Dictionary = NeonSignScript.plan_for(rect, variant, height, floors)
    if plan.is_empty():
        return
    neon_sign = NeonSignScript.new()
    neon_sign.building = self
    neon_sign.plan = plan
    add_child(neon_sign)

func _make_roof_props() -> void:
    if house or roof_plan.is_empty() or roof_plan.props.is_empty():
        return
    var outline := RoofsScript.inner_outline(self)
    var inside: Array = []
    var over: Array = []
    for p in roof_plan.props:
        if RoofsScript.overhangs(p, height, outline):
            over.append(p)
        else:
            inside.append(p)
    roof_props = _roof_piece(inside)
    roof_over = _roof_piece(over)

func _roof_piece(pieces: Array) -> Node2D:
    if pieces.is_empty():
        return null
    var node: Node2D = RoofPropsScript.new()
    node.building = self
    node.props = pieces
    add_child(node)
    for p in pieces:
        if p.kind == "ac" and p.spin:
            var f := RoofFanScript.new()
            f.position = RoofsScript.fan_centre(p)
            f.top_z = height + float(p.h)
            f.radius = RoofsScript.fan_radius(p) * 0.8
            f.rate = RoofsScript.fan_rate(p)
            f.angle = float(int(p.v) % 628) / 100.0
            node.add_child(f)
            fans.append(f)
    return node

func beam_spots() -> Node2D:
    if spots == null:
        spots = BeamSpotsScript.new()
        spots.building = self
        add_child(spots)
    return spots

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
# An awning that slopes out from the south wall: top edge on the wall at z_top,
# front edge `depth` out and lower at z_bottom, in alternating stripes with a
# darker valance. `u0..u1` is the span along the wall.
func _awning(origin: Vector2, u0: float, u1: float, z_top: float, z_bottom: float, depth: float, color: Color) -> void:
    var stripe := 6.0
    var u := u0
    var n := 0
    while u < u1:
        var w: float = minf(stripe, u1 - u)
        var c: Color = color if n % 2 == 0 else color.lightened(0.5)
        var a: Vector2 = origin + Vector2(u, 0.0)
        var b: Vector2 = origin + Vector2(u + w, 0.0)
        Sprites.fill(self, PackedVector2Array([
            Sprites.proj(a, z_top), Sprites.proj(b, z_top),
            Sprites.proj(b + Vector2(0.0, depth), z_bottom), Sprites.proj(a + Vector2(0.0, depth), z_bottom)]), c)
        u += stripe
        n += 1
    # Valance along the front edge, and a shadow line on the wall beneath.
    var front0: Vector2 = origin + Vector2(u0, depth)
    var front1: Vector2 = origin + Vector2(u1, depth)
    Sprites.fill(self, PackedVector2Array([
        Sprites.proj(front0, z_bottom), Sprites.proj(front1, z_bottom),
        Sprites.proj(front1, z_bottom - 2.0), Sprites.proj(front0, z_bottom - 2.0)]), color.darkened(0.3))
    draw_line(Sprites.proj(origin + Vector2(u0, 0.0), z_bottom - 0.5), Sprites.proj(origin + Vector2(u1, 0.0), z_bottom - 0.5), Color(0, 0, 0, 0.35), 1.0)

# In a blackout a steady share of the windows is out (the house she is heading for never is).
func _blacked_out(salt: int) -> bool:
    return not house and dark_windows > 0.0 and float(posmod(salt, 10)) < dark_windows * 10.0

func _boarded(salt: int) -> bool:
    return boarded > 0.0 and not house and float(posmod(salt, 10)) < boarded * 3.0

# Planks nailed across a window: a sheet of plywood with dark gaps and one slanting board.
func _boards(origin: Vector2, along: Vector2, u0: float, u1: float, z0: float, z1: float) -> void:
    var wood := Color("5b4631")
    Sprites.fill(self, _quad(origin, along, u0, u1, z0, z1), wood)
    var third: float = (z1 - z0) / 3.0
    for k in 2:
        var zg: float = z0 + third * float(k + 1)
        Sprites.fill(self, _quad(origin, along, u0, u1, zg - 0.4, zg + 0.4), Color("1d150e"))
    var a: Vector2 = origin + along * u0
    var b: Vector2 = origin + along * u1
    Sprites.fill(self, PackedVector2Array([
        Sprites.proj(a, z0), Sprites.proj(a, z0 + 1.6), Sprites.proj(b, z1), Sprites.proj(b, z1 - 1.6)]), Color("7b6144"))

# A few tags sprayed on a wall, low down: bright squiggles with a drip.
func _tags(origin: Vector2, along: Vector2, length: float, seed_: int) -> void:
    if not graffiti or house:
        return
    var colors := [Color("ff4fa3"), Color("4fe3ff"), Color("a6ff4f"), Color("ff9a3c")]
    var count := 2 + posmod(seed_, 2)
    for k in count:
        var u: float = 10.0 + float(posmod(seed_ * 7 + k * 53, maxi(int(length) - 44, 1)))
        var z: float = 5.0 + float(posmod(seed_ + k * 3, 4))
        var col: Color = colors[posmod(seed_ + k, colors.size())]
        var pts := PackedVector2Array()
        for i in 9:
            var uu: float = u + float(i) * 2.6
            pts.append(Sprites.proj(origin + along * uu, z + 3.0 * sin(float(i) * 1.25 + float(k)) + float(i % 3)))
        Sprites.polyline(self, pts, col, 1.6)
        var dx: float = u + 7.8
        draw_line(Sprites.proj(origin + along * dx, z + 1.0), Sprites.proj(origin + along * dx, z - 2.5), col, 1.0)

# The windows along a wall, as a list: [{u0, u1, z0, z1, lit, shop, n, board}], from the wall's own layout.
# Drawing (_windows) and the dark's window glows (lit_glows) both use it, so they cannot disagree.
func _window_cells(length: float, seed_: int, skip: Vector2, shop_front: bool) -> Array:
    var out: Array = []
    for f in floors:
        var z0: float = float(f) * FLOOR + 6.0
        if f == 0 and shop_front:
            # Wide shop windows, mostly lit.
            var u := 8.0
            var n := 0
            while u + 28.0 < length - 8.0:
                if not (u + 28.0 > skip.x - 3.0 and u < skip.y + 3.0):
                    var on: bool = (n * 7 + seed_) % 5 != 0 and not _blacked_out(n * 3 + seed_)
                    out.append({"u0": u, "u1": u + 28.0, "z0": 4.0, "z1": 16.0, "lit": on, "shop": true, "n": n, "board": (not on) and _boarded(n * 5 + seed_)})
                u += 38.0
                n += 1
            continue
        var u2 := 12.0
        var col := 0
        while u2 < length - 14.0:
            var skipped: bool = f == 0 and u2 + 9.0 > skip.x - 3.0 and u2 < skip.y + 3.0
            if not skipped:
                var lit: bool = (col * 7 + f * 13 + seed_) % 5 == 0 and not _blacked_out(col * 11 + f * 5 + seed_ * 3)
                out.append({"u0": u2, "u1": u2 + 9.0, "z0": z0, "z1": z0 + 11.0, "lit": lit, "shop": false, "n": col, "board": (not lit) and _boarded(col * 13 + f * 7 + seed_)})
            u2 += 22.0
            col += 1
    return out

# Draws a wall's windows: a shop's as displays of goods (ShopWindows.gd), the rest as lit or dark panes.
func _windows(origin: Vector2, along: Vector2, length: float, seed_: int, dark: Color, skip: Vector2, shop_front: bool) -> void:
    var theme: int = ShopWindowsScript.theme_for(seed_)
    for w in _window_cells(length, seed_, skip, shop_front):
        if w.shop:
            if w.lit:
                ShopWindowsScript.paint(self, origin, along, w.u0, window_light, theme, w.n, w.n == 1 and ShopWindowsScript.has_sign(seed_), ShopWindowsScript.sign_color(seed_))
            else:
                Sprites.fill(self, _quad(origin, along, w.u0, w.u1, w.z0, w.z1), dark)
        else:
            Sprites.fill(self, _quad(origin, along, w.u0, w.u1, w.z0, w.z1), window_light if w.lit else dark)
        if w.board:
            _boards(origin, along, w.u0, w.u1, w.z0, w.z1)

# Where the front door goes along the south wall, and the seed the windows are laid out from.
func _wall_layout() -> Dictionary:
    var door_u: float = rect.size.x - 120.0 if house else 16.0 + float((variant * 37) % int(maxf(rect.size.x - 50.0, 1.0)))
    var door_w: float = 40.0 if house else 11.0
    var seed_ := int(rect.position.x * 0.37 + rect.position.y * 0.91) + variant
    return {"door_u": door_u, "door_w": door_w, "seed": seed_}

var _glows: Array = []  # see lit_glows
var _glows_made := false

# The lit windows as glows for the dark (LightMap.gd): [[centre on screen from the world's origin, radius in pixels, is a shop's], ...].
func lit_glows() -> Array:
    if _glows_made:
        return _glows
    _glows_made = true
    if house:
        _glows = HouseLotScript.glows(self)
        return _glows
    var lay: Dictionary = _wall_layout()
    var south := Vector2(rect.position.x, rect.end.y)
    var east := Vector2(rect.end.x, rect.end.y)
    var walls := [[south, Vector2.RIGHT, rect.size.x, lay.seed, Vector2(lay.door_u, lay.door_u + lay.door_w), shop and not house],
            [east, Vector2.UP, rect.size.y, lay.seed + 3, Vector2(-100.0, -100.0), false]]
    for wall in walls:
        for w in _window_cells(wall[2], wall[3], wall[4], wall[5]):
            if not w.lit:
                continue
            var mid: Vector2 = wall[0] + wall[1] * ((w.u0 + w.u1) * 0.5)
            _glows.append([Sprites.proj(mid, (w.z0 + w.z1) * 0.5), (w.u1 - w.u0) * 0.8 * 0.5 + 4.0, w.shop])
    return _glows

# A small box on the roof: an air-conditioning unit, a stairwell, a tank.
func _roof_box(x: float, y: float, w: float, d: float, h: float, base_z: float, wall_s: Color, wall_e: Color, top: Color) -> void:
    Sprites.roof_box(self, x, y, w, d, h, base_z, wall_s, wall_e, top)

func _draw() -> void:
    if house:
        HouseLotScript.paint(self)  # home is a house in a fenced lot, not a block
        return
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
    Sprites.fill(self, PackedVector2Array([
        _p(r.position.x, r.end.y, 0.0), _p(r.end.x, r.end.y, 0.0),
        _p(r.end.x, r.end.y, h), _p(r.position.x, r.end.y, h)]), wall_s)
    Sprites.fill(self, PackedVector2Array([
        _p(r.end.x, r.end.y, 0.0), _p(r.end.x, r.position.y, 0.0),
        _p(r.end.x, r.position.y, h), _p(r.end.x, r.end.y, h)]), wall_e)
    # Ledges between storeys, so the number of floors reads at a glance.
    for f in range(1, floors):
        var z: float = float(f) * FLOOR
        draw_line(_p(r.position.x, r.end.y, z), _p(r.end.x, r.end.y, z), wall_s.darkened(0.25), 1.0)
        draw_line(_p(r.end.x, r.end.y, z), _p(r.end.x, r.position.y, z), wall_e.darkened(0.25), 1.0)

    # Where the front door goes along the south wall.
    var layout: Dictionary = _wall_layout()
    var door_u: float = layout.door_u
    var door_w: float = layout.door_w
    var seed_: int = layout.seed
    var south := Vector2(r.position.x, r.end.y)
    var east := Vector2(r.end.x, r.end.y)
    _windows(south, Vector2.RIGHT, r.size.x, seed_, dark, Vector2(door_u, door_u + door_w), shop and not house)
    _windows(east, Vector2.UP, r.size.y, seed_ + 3, dark, Vector2(-100.0, -100.0), false)
    _tags(south, Vector2.RIGHT, r.size.x, seed_)
    _tags(east, Vector2.UP, r.size.y, seed_ + 5)

    # Awnings: a long striped one over a shop's ground floor, a small canopy over
    # most doors, and a row of little ones over some upper windows.
    if shop and not house:
        # (hung high and shallow, so the displays in the windows below show: a deep, low one hid the top third)
        _awning(south, 3.0, r.size.x - 3.0, 23.0, 19.0, 5.0, AWNINGS[variant % AWNINGS.size()])
    elif not house and variant % 3 != 2:
        _awning(south, door_u - 3.0, door_u + door_w + 3.0, 19.0, 16.0, 5.0, AWNINGS[(variant + 1) % AWNINGS.size()])
    if floors >= 2 and not house and variant % 3 == 0:
        var wu := 12.0
        var wc := 0
        var awn: Color = AWNINGS[(variant + 2) % AWNINGS.size()]
        while wu < r.size.x - 14.0:
            if wc % 2 == 0:
                _awning(south, wu - 2.0, wu + 11.0, UPPER_AWNING_Z, UPPER_AWNING_Z - 4.0, 4.0, awn)
            wu += 22.0
            wc += 1

    # Ordinary door.
    if not house:
        var door := south + Vector2(door_u, 0.0)
        var fill: Color = Color("2b2216") if shop else Color("0b0c12")
        Sprites.fill(self, _quad(door, Vector2.RIGHT, 0.0, door_w, 0.0, 15.0), fill)
        Sprites.polyline(self, PackedVector2Array([
            Sprites.proj(door, 0.0), Sprites.proj(door, 15.0),
            Sprites.proj(door + Vector2(door_w, 0.0), 15.0), Sprites.proj(door + Vector2(door_w, 0.0), 0.0)]),
            wall_s.lightened(0.3), 1.0)

    # The roof: surface, coping and what stands on it (see Roofs.gd).
    RoofsScript.paint(self, r, h, roof, wall_s, wall_e)

    # Light catching the vertical corner and the base.
    draw_line(_p(r.end.x, r.end.y, 0.0), _p(r.end.x, r.end.y, h), wall_s.lightened(0.2), 1.0)
    draw_line(_p(r.position.x, r.end.y, 0.0), _p(r.end.x, r.end.y, 0.0), Color(0, 0, 0, 0.5), 1.0)

    if house:
        var door_pos := Vector2(r.end.x - 120.0, r.end.y)
        Sprites.fill(self, _quad(door_pos, Vector2.RIGHT, 0.0, 40.0, 0.0, 26.0), Color("ffd27a"))
        Sprites.polyline(self, PackedVector2Array([
            Sprites.proj(door_pos, 0.0), Sprites.proj(door_pos, 26.0),
            Sprites.proj(door_pos + Vector2(40, 0), 26.0), Sprites.proj(door_pos + Vector2(40, 0), 0.0)]),
            Color("a8793a"), 1.0)
        Style.draw_world_text(self, Sprites.proj(door_pos + Vector2(7, 0), 36.0), "HOME", 8, Style.GOLD)
