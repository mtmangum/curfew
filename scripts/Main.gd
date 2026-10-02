extends Node2D
# Curfew: sneak Nicole and Stella home across a night street. The level is
# built here from plain data so it's easy to rearrange.

const PlayerScript := preload("res://scripts/Player.gd")
const DogScript := preload("res://scripts/Dog.gd")
const CopScript := preload("res://scripts/Cop.gd")
const CatScript := preload("res://scripts/Cat.gd")
const PropScript := preload("res://scripts/Prop.gd")
const VentScript := preload("res://scripts/SteamVent.gd")
const FireScript := preload("res://scripts/Fire.gd")
const BuildingScript := preload("res://scripts/Building.gd")
const CarScript := preload("res://scripts/Car.gd")
const LampScript := preload("res://scripts/StreetLight.gd")
const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

const ZOOM := 1.8
# Only things this close to the view get depth-sorted and (for cops) simulated.
const NEAR_VIEW := 800.0
# Decorative blocks around the playable street so the view never reaches the void.
const DECOR_MARGIN := 700.0

# --- The base district -------------------------------------------------------
# One 2560x1440 district of blocks, avenues and lanes, written as plain data. The
# world is a grid of these (TILE_MIN..TILE_MAX), built by _build_tile(); alternate columns are
# mirrored so the city doesn't repeat exactly. The start is in the bottom-left
# tile and the house in the top-right one.
const TILE := Vector2(2560, 1440)
# The playable district is tiles (0..2, 0..1); the start is at the bottom-left of
# tile (0,1) and the house in tile (2,0). A column to the west and a row to the
# south are quiet outskirts (buildings, cars, lamps and bins, but no cops or
# cats), so the start has plenty of ground behind it. Tile coordinates can be
# negative; tile (0,0) sits at the world origin.
const TILE_MIN := Vector2i(-1, 0)
const TILE_MAX := Vector2i(2, 2)
const BASE_BUILDINGS := [
    Rect2(140, 120, 300, 170), Rect2(560, 100, 180, 220), Rect2(860, 180, 200, 140),
    Rect2(1420, 120, 300, 170), Rect2(1840, 100, 180, 220), Rect2(2140, 180, 200, 140),
    Rect2(160, 430, 280, 150), Rect2(560, 480, 240, 160), Rect2(920, 400, 240, 200),
    Rect2(1440, 430, 280, 150), Rect2(1840, 480, 240, 160), Rect2(2200, 400, 240, 200),
    Rect2(200, 800, 260, 170), Rect2(600, 830, 200, 150), Rect2(900, 780, 300, 200),
    Rect2(1300, 810, 240, 160), Rect2(1700, 790, 260, 190), Rect2(2040, 820, 180, 150),
    Rect2(2330, 780, 150, 200),
    Rect2(120, 1140, 320, 150), Rect2(520, 1160, 200, 160), Rect2(820, 1130, 280, 170),
    Rect2(1200, 1150, 240, 150), Rect2(1540, 1130, 300, 170), Rect2(1940, 1160, 200, 150),
    Rect2(2260, 1130, 240, 170),
    Rect2(2380, 0, 180, 110),
    # Infill for the big voids: shallow shops along the top strip (which make the
    # boulevards where tiles meet narrower), and buildings in the two plazas
    # either side of the north-south patrol street at x 1230-1250.
    Rect2(150, 14, 330, 38), Rect2(620, 14, 420, 38), Rect2(1340, 14, 380, 38), Rect2(1800, 14, 440, 38),
    Rect2(1105, 160, 80, 130), Rect2(1285, 170, 90, 130), Rect2(1295, 450, 100, 110),
]
# Each is a patrol route (the first point is where the cop starts).
const BASE_ROUTES := [
        [Vector2(80, 360), Vector2(500, 360)],
        [Vector2(900, 350), Vector2(1230, 350), Vector2(1230, 150)],
        [Vector2(1300, 360), Vector2(2100, 360), Vector2(2480, 360), Vector2(2480, 150)],
        [Vector2(80, 705), Vector2(1100, 705)],
        [Vector2(1300, 705), Vector2(2480, 705)],
        [Vector2(480, 720), Vector2(480, 1060), Vector2(1050, 1060)],
        [Vector2(1300, 1060), Vector2(2000, 1060), Vector2(2520, 1060)],
        [Vector2(1250, 420), Vector2(1250, 1000)],
        [Vector2(600, 1390), Vector2(1050, 1390)],
        [Vector2(1200, 1385), Vector2(2000, 1385), Vector2(2480, 1385)],
]
const BASE_PROPS := [Vector2(470, 500), Vector2(640, 400), Vector2(900, 385), Vector2(1120, 735), Vector2(1560, 400),
            Vector2(2050, 740), Vector2(1000, 1090), Vector2(1680, 1030), Vector2(2320, 1030),
            Vector2(350, 740), Vector2(760, 1355), Vector2(1900, 1350), Vector2(2400, 330)]
const BASE_VENTS := [[Vector2(330, 1375), 0.0], [Vector2(500, 385), 2.5], [Vector2(860, 520), 1.0], [Vector2(1080, 345), 4.0],
            [Vector2(700, 705), 3.0], [Vector2(1010, 1060), 1.5], [Vector2(1250, 880), 5.0], [Vector2(1600, 360), 2.0],
            [Vector2(1820, 705), 0.5], [Vector2(2200, 1060), 3.5], [Vector2(2000, 360), 6.0],
            [Vector2(1450, 1380), 4.5], [Vector2(2480, 500), 1.0]]
const BASE_FIRES := [Vector2(700, 370), Vector2(1700, 740), Vector2(850, 1030), Vector2(1900, 395)]
const BASE_CATS := [Vector2(520, 520), Vector2(980, 380), Vector2(1150, 700), Vector2(1700, 380), Vector2(600, 1080),
            Vector2(1900, 1070), Vector2(2300, 700),
            Vector2(300, 340), Vector2(780, 360), Vector2(1250, 560), Vector2(1450, 700), Vector2(2000, 380),
            Vector2(1300, 1090), Vector2(700, 1380), Vector2(2200, 1380)]

# The start is in the bottom-left tile, the front door in the top-right one.
const START := Vector2(70, 1390 + 1440)
const HOME_ZONE := Rect2(2430 + 5120, 112, 60, 40)

class Ground extends Node2D:
    var main

    func _draw() -> void:
        var wr: Rect2 = main.world_rect
        # The street carries on under the decorative blocks around the playable area.
        var floor: Rect2 = wr.grow(main.DECOR_MARGIN + 500.0)
        draw_rect(floor, Color("141824"))
        for x in range(int(floor.position.x / 40.0) * 40, int(floor.end.x) + 1, 40):
            draw_line(Vector2(x, floor.position.y), Vector2(x, floor.end.y), Color(1, 1, 1, 0.025), 1.0)
        for y in range(int(floor.position.y / 40.0) * 40, int(floor.end.y) + 1, 40):
            draw_line(Vector2(floor.position.x, y), Vector2(floor.end.x, y), Color(1, 1, 1, 0.025), 1.0)
        for r in main.buildings + main.decor:
            var walk: Rect2 = r.grow(10)
            draw_rect(walk, Color("262b3b"))
            draw_rect(walk, Color("3a4056"), false, 1.0)
        draw_rect(main.home_zone, Color(1.0, 0.85, 0.4, 0.16))
        draw_rect(main.home_zone, Color(1.0, 0.85, 0.4, 0.45), false, 1.0)

class NoiseRing extends Node2D:
    var radius := 100.0
    var life := 0.0

    func _process(delta: float) -> void:
        life += delta
        if life > 0.7:
            queue_free()
        queue_redraw()

    func _draw() -> void:
        var k: float = life / 0.7
        draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * k), 0.0, TAU, 48, Color(1, 1, 1, 0.5 * (1.0 - k)), 1.5)

var world_rect := Rect2(-2560, 0, 2560 * 4, 1440 * 3)
var home_zone := HOME_ZONE
var house := Rect2(2380 + 5120, 0, 180, 110)
# City blocks in rows from north to south, with avenues between the rows and
# lanes between the blocks. The house is last.
var buildings: Array[Rect2] = []
var walls: Array[Rect2] = []
var cars: Array[Rect2] = []  # parked cars: solid to walk into, but low enough to see over
# Patrol routes, one per cop (also used to keep parked cars off their paths).
var cop_routes: Array = []  # every cop's patrol, in world coordinates
var decor: Array[Rect2] = []
var car_count := 0
var lamps: Array = []
# The static things near the view, refreshed only as the camera moves, so the
# per-frame sorting and fading don't scan every building, car and lamp.
var near_cache_focus := Vector2(-999999.0, -999999.0)
var near_boxes: Array = []
var near_statics: Array = []

var state := "play"
var screen_relative := false
var sneak_toggle := false
var ended_at := 0
var sneak_button: Button
var player
var dog
var cops: Array = []
var vents: Array = []
var fires: Array = []
var props: Array = []
var cats: Array = []
var sounds := {}

var actors: Node2D
var focus := Vector2.ZERO
var building_nodes: Array = []
var sortables: Array = []
var danger: ColorRect
var objective: Label
var hints: Control
var toast: Label
var banner: Control
var banner_dim: ColorRect
var banner_title: Label
var banner_sub: Label
var walked := 0.0
var play_time := 0.0
var ambience_player: AudioStreamPlayer
var music_low: AudioStreamPlayer
var music_high: AudioStreamPlayer
var tension := 0.0
var music_gain := 1.0  # 1 while playing; fades to 0 when the run ends
var fade_in := 0.0  # the music and ambience swell in from silence at the start
var fade_started := false
# Browsers hold all audio until the first click or key press, so on the web the
# fade-in waits for that. Static, so a restart (which reloads the scene) remembers.
static var audio_unlocked := false
var last_pos := Vector2.ZERO
var toast_tween: Tween

func _ready() -> void:
    randomize()
    walls = buildings
    for n in ["pickup", "bark", "tug", "step0", "step1", "step2", "step3", "step4", "bin_crash", "meow", "cat_hiss",
            "alert", "spotted", "caught", "home", "tick"]:
        sounds[n] = load("res://assets/audio/%s.wav" % n)
    _setup_audio()
    if not OS.has_feature("web") or audio_unlocked:
        _start_fade_in()

    var ground := Ground.new()
    ground.main = self
    ground.z_index = -100
    ground.z_as_relative = false
    add_child(ground)

    actors = Node2D.new()
    add_child(actors)

    # Playable tiles first (so cop, cat and bin lists start with tile (0,0)), then outskirts.
    for ty in range(TILE_MIN.y, TILE_MAX.y + 1):
        for tx in range(TILE_MIN.x, TILE_MAX.x + 1):
            if _is_play_tile(tx, ty):
                _build_tile(tx, ty)
    for ty in range(TILE_MIN.y, TILE_MAX.y + 1):
        for tx in range(TILE_MIN.x, TILE_MAX.x + 1):
            if not _is_play_tile(tx, ty):
                _build_tile(tx, ty)
    _make_decor()
    for i in buildings.size():
        _add_building(buildings[i], i)
    for i in decor.size():
        _add_building(decor[i], buildings.size() + i)

    player = PlayerScript.new()
    player.main = self
    actors.add_child(player)
    player.global_position = START

    dog = DogScript.new()
    dog.main = self
    actors.add_child(dog)
    dog.global_position = START + Vector2(-20, 8)

    _build_grids()
    focus = player.global_position
    last_pos = player.global_position
    _update_view(1.0)
    _depth_sort()

    _build_hud()

# Whether tile column `tx` is mirrored left-to-right. Only the middle column is.
func _mirrored(tx: int) -> bool:
    return posmod(tx, 2) == 1

# The playable tiles; the others are outskirts.
func _is_play_tile(tx: int, ty: int) -> bool:
    return tx >= 0 and ty <= 1

# A point of the base district as it appears in tile (tx, ty).
func _tp(p: Vector2, tx: int, ty: int) -> Vector2:
    var x: float = TILE.x - p.x if _mirrored(tx) else p.x
    return Vector2(x + float(tx) * TILE.x, p.y + float(ty) * TILE.y)

func _tr(r: Rect2, tx: int, ty: int) -> Rect2:
    var x: float = TILE.x - r.end.x if _mirrored(tx) else r.position.x
    return Rect2(x + float(tx) * TILE.x, r.position.y + float(ty) * TILE.y, r.size.x, r.size.y)

# Builds one copy of the base district at tile (tx, ty).
func _build_tile(tx: int, ty: int) -> void:
    var play: bool = _is_play_tile(tx, ty)
    var tile_index: int = (ty + 1) * 7 + (tx + 1)
    var tile_rect := Rect2(Vector2(tx, ty) * TILE, TILE)
    var tile_buildings: Array = []
    for r in BASE_BUILDINGS:
        var rect: Rect2 = _tr(r, tx, ty)
        buildings.append(rect)
        tile_buildings.append(rect)
    for p in BASE_PROPS:
        var prop := PropScript.new()
        prop.main = self
        actors.add_child(prop)
        prop.global_position = _tp(p, tx, ty)
        props.append(prop)
    for v in (BASE_VENTS if play else []):
        var vent := VentScript.new()
        vent.main = self
        vent.phase = v[1] + float(tile_index) * 1.7  # so the vents of different tiles aren't in step
        vent.z_index = -20
        actors.add_child(vent)
        vent.global_position = _tp(v[0], tx, ty)
        vents.append(vent)
    for pos in (BASE_FIRES if play else []):
        var fire := FireScript.new()
        fire.main = self
        actors.add_child(fire)
        fire.global_position = _tp(pos, tx, ty)
        fires.append(fire)
    var routes: Array = []
    for base_route in BASE_ROUTES:
        var route: Array = []
        for pt in base_route:
            route.append(_tp(pt, tx, ty))
        if not play:
            continue  # nobody patrols the outskirts
        routes.append(route)
        cop_routes.append(route)
        var cop := CopScript.new()
        actors.add_child(cop)
        cop.setup(self, route)
        cops.append(cop)
    for pos in (BASE_CATS if play else []):
        var cat := CatScript.new()
        cat.main = self
        actors.add_child(cat)
        cat.global_position = _tp(pos, tx, ty)
        cats.append(cat)
    var first_car: int = cars.size()
    _make_cars_for(tile_buildings, routes, tile_rect)
    _make_lamps_for(tile_buildings, routes, tile_rect, first_car)

# The Music / Ambience / SFX buses come from default_bus_layout.tres. They have
# to exist before the game starts: on the web, buses added at runtime never
# reach the browser's audio graph and everything goes silent.
func _setup_audio() -> void:
    ambience_player = _loop_player("ambience", "Ambience", -9.0)
    music_low = _loop_player("music_low", "Music", -12.0)
    music_high = _loop_player("music_high", "Music", -50.0)

func _loop_player(stream_name: String, bus: String, db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = load("res://assets/audio/%s.wav" % stream_name)
    p.bus = bus
    p.volume_db = db
    add_child(p)
    p.play()
    return p

# The music has a calm layer and a busy layer; the busy one swells in as cops
# get suspicious or go to investigate.
func _update_music(delta: float, worst: float) -> void:
    var target := clampf(worst * 1.6, 0.0, 1.0)
    for c in cops:
        if c.state == c.State.INVESTIGATE and c.global_position.distance_squared_to(player.global_position) < 350.0 * 350.0:
            target = maxf(target, 0.45)
    tension = move_toward(tension, target, delta * (1.2 if target > tension else 0.4))
    var gain: float = linear_to_db(maxf(music_gain * fade_in, 0.0001))
    music_low.volume_db = -12.0 + gain
    music_high.volume_db = -9.0 + linear_to_db(maxf(tension * tension, 0.0001)) + gain
    ambience_player.volume_db = -9.0 + linear_to_db(maxf(lerpf(1.0, 0.35, 1.0 - music_gain) * fade_in, 0.0001))

func _start_fade_in() -> void:
    if fade_started:
        return
    fade_started = true
    var tw := create_tween()
    tw.tween_property(self, "fade_in", 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _input(event: InputEvent) -> void:
    if audio_unlocked:
        return
    if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
        audio_unlocked = true
        _start_fade_in()

func _fade_music(seconds: float) -> void:
    var tw := create_tween()
    tw.tween_property(self, "music_gain", 0.0, seconds)

# Parked cars in one tile: nose to tail along the north and south kerbs of every
# block, and along some of the lanes between blocks. Candidates come from a fixed
# pattern and are kept only where they leave everything else clear (see
# _car_spot_ok): not on a patrol route, a bin, a barrel, a vent, the start spot or
# the front door, and lane cars only where a walkable corridor stays open.
func _make_cars_for(tile_buildings: Array, routes: Array, tile_rect: Rect2) -> void:
    var first_car: int = cars.size()
    for bi in tile_buildings.size():
        var b: Rect2 = tile_buildings[bi]
        if b == house:
            continue
        # North (side 0) and south (side 1) kerbs: cars point along x. The shallow
        # shops on the top strip front onto the boulevard only; the lane behind
        # them is narrow and stays clear.
        for side in 2:
            if b.position.y < 40.0 and side == 1:
                continue
            var y0: float = b.position.y - 12.0 - 20.0 if side == 0 else b.end.y + 12.0
            var x: float = b.position.x + 12.0
            var k := 0
            while x + 40.0 < b.end.x - 8.0:
                if (bi * 7 + side * 3 + k * 5) % 9 < 7:
                    _try_car(Rect2(x, y0, 40.0, 20.0), bi + k + side, k, tile_buildings, routes, tile_rect, first_car, 0.0)
                x += 52.0
                k += 1
        # West (side 0) and east (side 1) walls, along the lanes: cars point along y.
        for side in 2:
            var x0: float = b.position.x - 12.0 - 20.0 if side == 0 else b.end.x + 12.0
            var y: float = b.position.y + 12.0
            var k2 := 0
            while y + 40.0 < b.end.y - 8.0:
                if (bi * 5 + side * 2 + k2 * 7) % 9 < 3:
                    _try_car(Rect2(x0, y, 20.0, 40.0), bi + k2 + side + 3, k2, tile_buildings, routes, tile_rect, first_car, 56.0)
                y += 54.0
                k2 += 1

# Street lights at about half the corners of every block, wherever there is room
# for a slim post and nothing else is in the way.
func _make_lamps_for(tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int) -> void:
    var first_lamp: int = lamps.size()
    for bi in tile_buildings.size():
        var b: Rect2 = tile_buildings[bi]
        var corners: Array = [b.end + Vector2(16, 16), b.position - Vector2(16, 16),
            Vector2(b.end.x + 16.0, b.position.y - 16.0), Vector2(b.position.x - 16.0, b.end.y + 16.0)]
        for ci in 4:
            if (bi * 3 + ci * 5) % 4 >= 2:
                continue
            var p: Vector2 = corners[ci]
            if not _lamp_spot_ok(p, tile_buildings, routes, tile_rect, first_car, first_lamp):
                continue
            var lamp := LampScript.new()
            lamp.main = self
            lamp.flicker = (bi * 5 + ci * 3 + lamps.size()) % 9 == 0
            lamp.side = 1.0 if (bi + ci) % 2 == 0 else -1.0
            actors.add_child(lamp)
            lamp.global_position = p
            lamps.append(lamp)

func _lamp_spot_ok(p: Vector2, tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int, first_lamp: int) -> bool:
    if not tile_rect.grow(-24.0).has_point(p):
        return false
    for other in tile_buildings:
        if other.grow(10.0).has_point(p):
            return false
    for i in range(first_car, cars.size()):
        if cars[i].grow(10.0).has_point(p):
            return false
    for i in range(first_lamp, lamps.size()):
        if lamps[i].global_position.distance_to(p) < 80.0:
            return false
    if p.distance_to(START) < 40.0 or HOME_ZONE.grow(24.0).has_point(p):
        return false
    for q in props:
        if p.distance_to(q.global_position) < 22.0:
            return false
    for q in fires:
        if p.distance_to(q.global_position) < 44.0:
            return false
    for q in vents:
        if p.distance_to(q.global_position) < 40.0:
            return false
    var clear: Rect2 = Rect2(p, Vector2.ZERO).grow(24.0)
    for route in routes:
        for i in range(route.size() - 1):
            var from: Vector2 = route[i]
            var to: Vector2 = route[i + 1]
            var steps: int = int(from.distance_to(to) / 8.0) + 1
            for n in steps + 1:
                if clear.has_point(from.lerp(to, float(n) / float(steps))):
                    return false
    return true

# Adds a car if the spot is fine. `corridor` is how much open ground must remain
# beside it (for lane cars), measured outward from the building it is parked at.
func _try_car(r: Rect2, color_seed: int, k: int, tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int, corridor: float) -> void:
    if not _car_spot_ok(r, tile_buildings, routes, tile_rect, first_car):
        return
    if corridor > 0.0:
        # Is there room to walk past? Look at the strip outward from the car.
        var away := Rect2(r.position.x - corridor, r.position.y, corridor, r.size.y) if r.position.x < r.get_center().x and _wall_on_east(r, tile_buildings) \
            else Rect2(r.end.x, r.position.y, corridor, r.size.y)
        for other in tile_buildings:
            if other.intersects(away):
                return
        if not tile_rect.grow(-12.0).encloses(away):
            return
    cars.append(r)
    var car := CarScript.new()
    car.setup_car(r, (color_seed + car_count) % CarScript.BODY_COLORS.size(), 1 if (color_seed + k) % 2 == 0 else -1, car_count)
    actors.add_child(car)
    building_nodes.append(car)
    car_count += 1

# True if the building this lane car is parked against is on its east side.
func _wall_on_east(r: Rect2, tile_buildings: Array) -> bool:
    var probe := Rect2(r.end.x, r.position.y, 16.0, r.size.y)
    for other in tile_buildings:
        if other.intersects(probe):
            return true
    return false

func _car_spot_ok(r: Rect2, tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int) -> bool:
    if not tile_rect.grow(-16.0).encloses(r):
        return false
    for other in tile_buildings:
        if other.grow(5.0).intersects(r):
            return false
    for i in range(first_car, cars.size()):
        if cars[i].grow(5.0).intersects(r):
            return false
    var c: Vector2 = r.get_center()
    if c.distance_to(START) < 130.0 or r.grow(40.0).intersects(HOME_ZONE):
        return false
    for p in props:
        if c.distance_to(p.global_position) < 44.0:
            return false
    for f in fires:
        if c.distance_to(f.global_position) < 50.0:
            return false
    for v in vents:
        if c.distance_to(v.global_position) < 60.0:
            return false
    # Keep clear of every patrol route in this tile: sample along each leg.
    var clear: Rect2 = r.grow(26.0)
    for route in routes:
        for i in range(route.size() - 1):
            var from: Vector2 = route[i]
            var to: Vector2 = route[i + 1]
            var steps: int = int(from.distance_to(to) / 8.0) + 1
            for n in steps + 1:
                if clear.has_point(from.lerp(to, float(n) / float(steps))):
                    return false
    for cat in cats:
        if r.grow(10.0).has_point(cat.global_position):
            return false
    return true

# Storeys, wall colour and ground-floor style are picked from the index so the
# street has a mix: low shops, two-storey blocks and three-storey buildings.
func _add_building(rect: Rect2, index: int) -> void:
    var is_house: bool = rect == house
    var floors: int = 3 if is_house else [2, 3, 2, 1, 3, 2, 2][(index * 3 + 1) % 7]
    var b := BuildingScript.new()
    b.setup(rect, floors, (index * 2 + index / 5) % 5, floors == 1 or index % 4 == 1, is_house, index)
    actors.add_child(b)
    building_nodes.append(b)

# A ring of scenery blocks around the street. They aren't walls: the world
# edge already stops everyone. More room is left on the south and east sides,
# where tall blocks would otherwise stand in front of the player.
func _make_decor() -> void:
    var outer: Rect2 = world_rect.grow(DECOR_MARGIN)
    var keep_out: Rect2 = world_rect.grow_individual(24.0, 24.0, 140.0, 140.0)
    var col := 0
    var x: float = outer.position.x
    while x < outer.end.x:
        var row := 0
        var y: float = outer.position.y
        while y < outer.end.y:
            var w: float = 230.0 + float((col * 13 + row * 29) % 5) * 22.0
            var d: float = 150.0 + float((col * 31 + row * 17) % 7) * 14.0
            var r := Rect2(x + 40.0, y + 40.0, w, d)
            if not keep_out.intersects(r):
                decor.append(r)
            y += 290.0
            row += 1
        x += 360.0
        col += 1

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.theme = Style.theme()
    layer.add_child(ui)

    danger = ColorRect.new()
    danger.set_anchors_preset(Control.PRESET_FULL_RECT)
    danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    danger.color = Color(0.8, 0.05, 0.05, 0.0)
    ui.add_child(danger)

    objective = Label.new()
    objective.text = "Get Nicole and Stella home unseen."
    objective.position = Vector2(20, 16)
    objective.add_theme_font_size_override("font_size", 24)
    objective.add_theme_color_override("font_color", Style.GOLD)
    ui.add_child(objective)

    var version := Label.new()
    version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
    version.add_theme_font_size_override("font_size", 16)
    version.add_theme_color_override("font_color", Style.DIM)
    version.anchor_top = 1.0
    version.anchor_bottom = 1.0
    version.offset_left = 18
    version.offset_top = -34
    version.offset_bottom = -10
    ui.add_child(version)

    # Control hints along the bottom; they fade once the player has got going.
    var bottom := VBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
    bottom.alignment = BoxContainer.ALIGNMENT_END
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(bottom)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(center)
    var strip := PanelContainer.new()
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var strip_box := StyleBoxFlat.new()
    strip_box.bg_color = Color(0.04, 0.05, 0.09, 0.72)
    strip_box.set_corner_radius_all(6)
    strip_box.content_margin_left = 16
    strip_box.content_margin_right = 16
    strip_box.content_margin_top = 8
    strip_box.content_margin_bottom = 8
    strip.add_theme_stylebox_override("panel", strip_box)
    center.add_child(strip)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 22)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.add_child(row)
    row.add_child(Style.hint(["CLICK"], "walk"))
    row.add_child(Style.hint(["W", "A", "S", "D"], "move"))
    row.add_child(Style.hint(["SHIFT"], "sneak"))
    row.add_child(Style.hint(["TAB"], "keys"))
    row.add_child(Style.hint(["M"], "sound"))
    row.add_child(Style.hint(["R"], "restart"))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 18)
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(gap)
    hints = center

    toast = Label.new()
    toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
    toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
    toast.position.y = 64
    toast.modulate.a = 0.0
    toast.add_theme_font_size_override("font_size", 22)
    ui.add_child(toast)

    # End-of-run banner: dimmed screen, big title, blinking prompt.
    banner = Control.new()
    banner.set_anchors_preset(Control.PRESET_FULL_RECT)
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.visible = false
    ui.add_child(banner)
    banner_dim = ColorRect.new()
    banner_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    banner_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(banner_dim)
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 18)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(box)
    banner_title = Style.display_label("", 80, Style.RED, 12)
    banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(banner_title)
    banner_sub = Label.new()
    banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_sub.add_theme_font_size_override("font_size", 26)
    box.add_child(banner_sub)

    # Touch screens have no Shift key.
    sneak_button = Button.new()
    sneak_button.toggle_mode = true
    sneak_button.focus_mode = Control.FOCUS_NONE
    sneak_button.text = "SNEAK"
    sneak_button.add_theme_font_size_override("font_size", 24)
    sneak_button.custom_minimum_size = Vector2(150, 64)
    sneak_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    sneak_button.offset_left = -170
    sneak_button.offset_top = -84
    sneak_button.offset_right = -20
    sneak_button.offset_bottom = -20
    sneak_button.toggled.connect(func(on: bool) -> void:
        sneak_toggle = on
        play("tick", -4.0))
    ui.add_child(sneak_button)

func _show_toast(text: String) -> void:
    toast.text = text
    if toast_tween != null:
        toast_tween.kill()
    toast.modulate.a = 1.0
    toast_tween = create_tween()
    toast_tween.tween_interval(1.4)
    toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)

func _show_banner(title: String, sub: String, color: Color, dim: Color) -> void:
    banner_title.text = title
    banner_title.add_theme_color_override("font_color", color)
    banner_sub.text = sub
    banner_dim.color = dim
    banner.modulate.a = 0.0
    banner.visible = true
    var fade := create_tween()
    fade.tween_property(banner, "modulate:a", 1.0, 0.4)
    # Title pops in; the prompt blinks.
    await get_tree().process_frame
    banner_title.pivot_offset = banner_title.size * 0.5
    banner_title.scale = Vector2(1.4, 1.4)
    var pop := create_tween()
    pop.tween_property(banner_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var blink := create_tween().set_loops()
    blink.tween_property(banner_sub, "modulate:a", 0.35, 0.7)
    blink.tween_property(banner_sub, "modulate:a", 1.0, 0.7)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        get_tree().reload_current_scene()
    # Tap to play again once the banner has been up a moment.
    if state != "play" and event is InputEventMouseButton and event.pressed \
            and Time.get_ticks_msec() - ended_at > 700:
        get_tree().reload_current_scene()
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
        var muted: bool = not AudioServer.is_bus_mute(0)
        AudioServer.set_bus_mute(0, muted)
        _show_toast("Sound off" if muted else "Sound on")
        if not muted:
            play("tick")
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
        screen_relative = not screen_relative
        _show_toast("Keys: screen-relative" if screen_relative else "Keys: along the streets")

func _process(delta: float) -> void:
    focus = focus.lerp(player.global_position, clampf(8.0 * delta, 0.0, 1.0))
    _update_view(delta)
    _depth_sort()
    _fade_buildings(delta)
    var worst := 0.0
    for c in cops:
        worst = maxf(worst, c.exposure)
    danger.color.a = worst * 0.35
    _update_music(delta, worst)
    # Fade the hints once the player has got going, then the objective.
    walked += player.global_position.distance_to(last_pos)
    last_pos = player.global_position
    # Both fade only after you have walked a good way AND played a while, so the
    # controls stay up long enough to learn them.
    if state == "play":
        play_time += delta
    var progress: float = minf(walked / 600.0, play_time / 30.0)
    hints.modulate.a = clampf(1.0 - (progress - 1.0) / 0.25, 0.0, 1.0)
    objective.modulate.a = clampf(1.0 - (progress - 2.0) / 0.25, 0.0, 1.0)
    if state == "play" and home_zone.has_point(player.global_position):
        _win()

# The whole street is drawn through an isometric canvas transform that follows
# the player. Game logic never sees it: positions stay on the flat plane.
func _update_view(_delta: float) -> void:
    var t := Transform2D(Sprites.ISO_X * ZOOM, Sprites.ISO_Y * ZOOM, Vector2.ZERO)
    t.origin = get_viewport_rect().size * 0.5 - t.basis_xform(focus)
    get_viewport().canvas_transform = t

# True if `a` has to be drawn before (behind) `b`. Actors sort by distance
# along the view diagonal; boxes sort by which side of them an actor is on.
func _behind(a, b) -> bool:
    var a_box: bool = a is BuildingScript
    var b_box: bool = b is BuildingScript
    if not a_box and not b_box:
        return a.global_position.x + a.global_position.y < b.global_position.x + b.global_position.y
    if a_box and b_box:
        var ra: Rect2 = a.rect
        var rb: Rect2 = b.rect
        var a_first: bool = ra.end.x <= rb.position.x or ra.end.y <= rb.position.y
        var b_first: bool = rb.end.x <= ra.position.x or rb.end.y <= ra.position.y
        return a_first and not b_first
    if a_box:
        return not _behind(b, a)
    var p: Vector2 = a.global_position
    var r: Rect2 = b.rect
    return not (p.x >= r.end.x or p.y >= r.end.y)

# Orders everything on screen that stands on the ground so nearer things draw on
# top. Only pairs whose screen boxes overlap can hide each other, so only those
# are compared. Things off screen keep whatever z they had.
# Rebuilds the near_* caches if the camera has moved far enough. They cover a
# generous area around the focus, so a refresh every ~140 units is plenty.
func _refresh_near() -> void:
    if focus.distance_squared_to(near_cache_focus) < 140.0 * 140.0:
        return
    near_cache_focus = focus
    var area := Rect2(Sprites.iso(focus) - Vector2(700.0, 520.0), Vector2(1400.0, 1040.0))
    near_boxes.clear()
    near_statics.clear()
    for b in building_nodes:
        if b.screen_box.intersects(area):
            near_boxes.append(b)
    for list in [props, fires, lamps]:
        for n in list:
            if area.has_point(Sprites.iso(n.global_position)):
                near_statics.append(n)

func _depth_sort() -> void:
    _refresh_near()
    var centre: Vector2 = Sprites.iso(focus)
    var view := Rect2(centre - Vector2(450.0, 310.0), Vector2(900.0, 620.0))
    var items: Array = []
    var boxes: Array = []  # screen box of each item
    for b in near_boxes:
        if b.screen_box.intersects(view):
            items.append(b)
            boxes.append(b.screen_box)
    for n in near_statics:
        var sp0: Vector2 = Sprites.iso(n.global_position)
        if view.has_point(sp0):
            items.append(n)
            boxes.append(Rect2(sp0.x - 14.0, sp0.y - 52.0, 28.0, 54.0))
    for list in [cats, cops]:
        for n in list:
            var sp: Vector2 = Sprites.iso(n.global_position)
            if view.has_point(sp):
                items.append(n)
                boxes.append(Rect2(sp.x - 14.0, sp.y - 52.0, 28.0, 54.0))
    for n in [dog, player]:
        var sp2: Vector2 = Sprites.iso(n.global_position)
        items.append(n)
        boxes.append(Rect2(sp2.x - 14.0, sp2.y - 52.0, 28.0, 54.0))
    var count: int = items.size()
    var waiting := PackedInt32Array()
    waiting.resize(count)
    var after: Array = []
    for i in count:
        after.append([])
    for i in count:
        var bi: Rect2 = boxes[i]
        for j in range(i + 1, count):
            if not bi.intersects(boxes[j]):
                continue
            if _behind(items[i], items[j]):
                after[i].append(j)
                waiting[j] += 1
            elif _behind(items[j], items[i]):
                after[j].append(i)
                waiting[i] += 1
    var done := PackedByteArray()
    done.resize(count)
    for rank in count:
        var pick := -1
        var pick_key := INF
        var fallback := -1
        var fallback_key := INF
        for i in count:
            if done[i] == 1:
                continue
            var key: float = _depth_key(items[i])
            if key < fallback_key:
                fallback_key = key
                fallback = i
            if waiting[i] == 0 and key < pick_key:
                pick_key = key
                pick = i
        if pick == -1:
            pick = fallback
        done[pick] = 1
        items[pick].z_index = 100 + rank
        for k in after[pick]:
            waiting[k] -= 1

func _depth_key(n) -> float:
    if n is BuildingScript:
        return n.rect.end.x + n.rect.end.y
    return n.global_position.x + n.global_position.y

# Buildings go see-through while Nicole or Stella is hidden behind one.
func _fade_buildings(delta: float) -> void:
    _refresh_near()
    for b in near_boxes:
        var hidden := false
        for who in [player, dog]:
            if not _behind(who, b):
                continue
            var foot: Vector2 = Sprites.iso(who.global_position)
            if not b.screen_box.has_point(foot):
                continue
            var poly: PackedVector2Array = b.silhouette()
            if Geometry2D.is_point_in_polygon(foot, poly) \
                    or Geometry2D.is_point_in_polygon(foot + Vector2(0, -26), poly):
                hidden = true
        b.modulate.a = move_toward(b.modulate.a, 0.3 if hidden else 1.0, 4.0 * delta)

func _win() -> void:
    state = "won"
    ended_at = Time.get_ticks_msec()
    _show_banner("HOME SAFE", "Press R or tap to play again", Style.GOLD, Color(0.1, 0.07, 0.0, 0.5))
    play("home")
    _fade_music(2.5)

func caught(_cop) -> void:
    if state != "play":
        return
    state = "caught"
    ended_at = Time.get_ticks_msec()
    _show_banner("CAUGHT", "Press R or tap to try again", Style.RED, Color(0.14, 0.0, 0.0, 0.58))
    play("caught")
    _fade_music(0.6)

func play(sound_name: String, db: float = 0.0, pitch: float = 1.0) -> void:
    var s = sounds.get(sound_name)
    if s == null:
        return
    var p := AudioStreamPlayer.new()
    p.stream = s
    p.volume_db = db
    p.pitch_scale = pitch
    p.bus = "SFX"
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

# A sound out in the world: quieter the farther it is from Nicole, silent past `reach`.
func play_at(sound_name: String, pos: Vector2, db: float = 0.0, reach: float = 320.0, pitch: float = 1.0) -> void:
    var d: float = pos.distance_to(player.global_position)
    if d >= reach:
        return
    play(sound_name, db + linear_to_db(pow(1.0 - d / reach, 1.5)), pitch)

# One footfall. Variant, volume and pitch wobble a little so steps never repeat
# exactly. `weight` shifts the pitch: below 1 is a heavier boot.
const STEP_VARIANTS := 5
func footstep(db: float, weight: float = 1.0, pos = null, reach: float = 240.0) -> void:
    var name := "step%d" % randi_range(0, STEP_VARIANTS - 1)
    var wobble_db: float = randf_range(-1.5, 1.5)
    var pitch: float = weight * randf_range(0.94, 1.06)
    if pos == null:
        play(name, db + wobble_db, pitch)
    else:
        play_at(name, pos, db + wobble_db, reach, pitch)

func noise(pos: Vector2, radius: float, show_ring: bool = true) -> void:
    if show_ring:
        var ring := NoiseRing.new()
        ring.radius = radius
        ring.z_as_relative = false
        ring.z_index = 3500
        add_child(ring)
        ring.global_position = pos
    for c in cops:
        if c.global_position.distance_to(pos) <= radius:
            c.hear(pos)

func in_steam(p: Vector2) -> bool:
    for v in vents:
        if v.active and p.distance_to(v.global_position) < v.radius:
            return true
    return false

func in_fire(p: Vector2) -> bool:
    for f in fires:
        if f.lights(p):
            return true
    return false

# --- Spatial grids ---------------------------------------------------------------
# The map has hundreds of walls, cars, bins and barrels. Collision and light
# rays only look at the few in the cells near them, found through these grids.
const CELL := 128.0
var solid_grid := {}   # cell -> walls and cars (rects), for walking
var wall_grid := {}    # cell -> walls only, for rays (cars don't block sight)
var circle_grid := {}  # cell -> [center, radius] of bins and barrels

func _cell_of(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func _grid_add(grid: Dictionary, area: Rect2, item) -> void:
    var lo := _cell_of(area.position)
    var hi := _cell_of(area.end)
    for cx in range(lo.x, hi.x + 1):
        for cy in range(lo.y, hi.y + 1):
            var key := Vector2i(cx, cy)
            if not grid.has(key):
                grid[key] = []
            grid[key].append(item)

func _build_grids() -> void:
    solid_grid.clear()
    wall_grid.clear()
    circle_grid.clear()
    for w in walls:
        _grid_add(solid_grid, w.grow(16.0), w)
        _grid_add(wall_grid, w, w)
    for car in cars:
        _grid_add(solid_grid, car.grow(16.0), car)
    for p in props:
        _grid_add(circle_grid, Rect2(p.global_position, Vector2.ZERO).grow(p.radius + 16.0), [p.global_position, p.radius])
    for f in fires:
        _grid_add(circle_grid, Rect2(f.global_position, Vector2.ZERO).grow(f.body_radius + 16.0), [f.global_position, f.body_radius])
    for l in lamps:
        _grid_add(circle_grid, Rect2(l.global_position, Vector2.ZERO).grow(l.body_radius + 16.0), [l.global_position, l.body_radius])

func blocked_circle(pos: Vector2, r: float) -> bool:
    if not world_rect.grow(-r).has_point(pos):
        return true
    var key := _cell_of(pos)
    var rects = solid_grid.get(key)
    if rects != null:
        for w in rects:
            if w.grow(r).has_point(pos):
                return true
    var circles = circle_grid.get(key)
    if circles != null:
        for c in circles:
            if pos.distance_to(c[0]) < r + c[1]:
                return true
    return false

# The bin or fire barrel overlapping this circle, as [center, radius], or [].
func _round_blocker(pos: Vector2, r: float) -> Array:
    var circles = circle_grid.get(_cell_of(pos))
    if circles != null:
        for c in circles:
            if pos.distance_to(c[0]) < r + c[1]:
                return [c[0], c[1]]
    return []

# Move from pos by motion, sliding along walls and around round obstacles.
# Returns the new position.
func slide(pos: Vector2, motion: Vector2, r: float) -> Vector2:
    var p := pos + motion
    if not blocked_circle(p, r):
        return p
    var round_hit := _round_blocker(p, r)
    if not round_hit.is_empty():
        # Keep only the part of the motion that goes around the obstacle.
        var n: Vector2 = pos - round_hit[0]
        if n.length() < 0.01:
            n = motion.orthogonal()
        n = n.normalized()
        var along: Vector2 = motion - n * motion.dot(n)
        if along.length() < motion.length() * 0.2:
            # Head-on: always go around the same (right-hand) side.
            along = n.orthogonal() * motion.length()
        else:
            along = along.normalized() * motion.length()
        var q := pos + along
        if not blocked_circle(q, r):
            return q
    var px := Vector2(p.x, pos.y)
    if not blocked_circle(px, r):
        return px
    var py := Vector2(pos.x, p.y)
    if not blocked_circle(py, r):
        return py
    # Wedged between things: veer off to either side.
    for angle in [0.6, -0.6, 1.2, -1.2]:
        var q2 := pos + motion.rotated(angle) * 0.8
        if not blocked_circle(q2, r):
            return q2
    return pos

# Distance along the ray to the first wall or active steam cloud.
func ray_hit(origin: Vector2, dir: Vector2, max_len: float) -> float:
    var best := max_len
    var reach := Rect2(origin, Vector2.ZERO).expand(origin + dir * max_len)
    var lo := _cell_of(reach.position)
    var hi := _cell_of(reach.end)
    for cx in range(lo.x, hi.x + 1):
        for cy in range(lo.y, hi.y + 1):
            var rects = wall_grid.get(Vector2i(cx, cy))
            if rects == null:
                continue
            for w in rects:
                if not reach.intersects(w, true):
                    continue
                var t := _ray_rect(origin, dir, w)
                if t >= 0.0 and t < best:
                    best = t
    for v in vents:
        if not v.active:
            continue
        var span: float = max_len + v.radius
        if (v.global_position - origin).length_squared() > span * span:
            continue
        var t2 := _ray_circle(origin, dir, v.global_position, v.radius)
        if t2 >= 0.0 and t2 < best:
            best = t2
    return best

func los(a: Vector2, b: Vector2) -> bool:
    var d := b - a
    var dist := d.length()
    if dist < 1.0:
        return true
    return ray_hit(a, d / dist, dist) >= dist

func _ray_rect(o: Vector2, d: Vector2, r: Rect2) -> float:
    var tmin := 0.0
    var tmax := INF
    for axis in 2:
        var oa: float = o[axis]
        var da: float = d[axis]
        var lo: float = r.position[axis]
        var hi: float = r.end[axis]
        if absf(da) < 0.00001:
            if oa < lo or oa > hi:
                return -1.0
        else:
            var t1 := (lo - oa) / da
            var t2 := (hi - oa) / da
            if t1 > t2:
                var tmp := t1
                t1 = t2
                t2 = tmp
            tmin = maxf(tmin, t1)
            tmax = minf(tmax, t2)
            if tmin > tmax:
                return -1.0
    return tmin

func _ray_circle(o: Vector2, d: Vector2, c: Vector2, rad: float) -> float:
    var oc := o - c
    var b := oc.dot(d)
    var cc := oc.dot(oc) - rad * rad
    var disc := b * b - cc
    if disc < 0.0:
        return -1.0
    var t := -b - sqrt(disc)
    return t if t >= 0.0 else -1.0
