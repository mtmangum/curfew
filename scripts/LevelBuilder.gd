extends RefCounted
# Turns the level data (LevelData.gd) into the world: builds every tile of the
# district (buildings, bins, vents, fires, patrolling cops, cats), scatters parked
# cars and street lights, adds the ring of scenery round the playable area, and
# makes the building nodes. Everything it creates is added to Main's lists
# (buildings, cars, lamps, props, cops, ...), which the rest of the game reads.

const LevelData := preload("res://scripts/LevelData.gd")
const PropScript := preload("res://scripts/Prop.gd")
const VentScript := preload("res://scripts/SteamVent.gd")
const FireScript := preload("res://scripts/Fire.gd")
const CopScript := preload("res://scripts/Cop.gd")
const CatScript := preload("res://scripts/Cat.gd")
const BuildingScript := preload("res://scripts/Building.gd")
const CarScript := preload("res://scripts/Car.gd")
const LampScript := preload("res://scripts/StreetLight.gd")
const ObjectScript := preload("res://scripts/StreetObject.gd")
const TrafficScript := preload("res://scripts/Traffic.gd")

var main

func _init(game) -> void:
    main = game

func build() -> void:
    _choose_home()
    # Playable tiles first (so cop, cat and bin lists start with tile (0,0)), then outskirts.
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            if _is_play_tile(tx, ty):
                _build_tile(tx, ty)
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            if not _is_play_tile(tx, ty):
                _build_tile(tx, ty)
    _make_decor()
    for i in main.buildings.size():
        _add_building(main.buildings[i], i)
    for i in main.decor.size():
        _add_building(main.decor[i], main.buildings.size() + i)

# Picks which building is home, this run: a wide building well away from the start,
# with a clear patch of street in front of its door (no bin, barrel, vent, patrol or
# other building on it). Sets main.house and main.home_zone, which the cars, lamps,
# map and win check all read.
const HOME_MIN_DISTANCE := 4500.0  # how far the front door must be from the start

func _choose_home() -> void:
    var options: Array = []
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            if not _is_play_tile(tx, ty):
                continue
            for base in LevelData.BASE_BUILDINGS:
                var r: Rect2 = _tr(base, tx, ty)
                if r.size.x < 160.0 or r.size.y < 90.0:
                    continue
                # Same geometry as the glowing door Building draws on a house.
                var zone := Rect2(r.end.x - 130.0, r.end.y + 2.0, 60.0, 40.0)
                if zone.get_center().distance_to(main.START) < HOME_MIN_DISTANCE:
                    continue
                if _home_spot_clear(zone, r, tx, ty):
                    options.append([r, zone])
    var rng := RandomNumberGenerator.new()
    if main.home_seed >= 0:
        rng.seed = main.home_seed
    else:
        rng.randomize()
    var pick: Array = options[rng.randi() % options.size()]
    main.house = pick[0]
    main.home_zone = pick[1]

func _home_spot_clear(zone: Rect2, house_rect: Rect2, tx: int, ty: int) -> bool:
    if not Rect2(Vector2(tx, ty) * LevelData.TILE, LevelData.TILE).grow(-40.0).encloses(zone):
        return false
    for base in LevelData.BASE_BUILDINGS:
        var other: Rect2 = _tr(base, tx, ty)
        if other != house_rect and other.grow(16.0).intersects(zone):
            return false
    var centre: Vector2 = zone.get_center()
    for p in LevelData.BASE_PROPS:
        if _tp(p, tx, ty).distance_to(centre) < 55.0:
            return false
    for p in LevelData.BASE_FIRES:
        if _tp(p, tx, ty).distance_to(centre) < 70.0:
            return false
    for v in LevelData.BASE_VENTS:
        if _tp(v[0], tx, ty).distance_to(centre) < 70.0:
            return false
    var near := Rect2(centre, Vector2.ZERO).grow(70.0)
    for route in LevelData.BASE_ROUTES:
        for i in range(route.size() - 1):
            var from: Vector2 = _tp(route[i], tx, ty)
            var to: Vector2 = _tp(route[i + 1], tx, ty)
            var steps: int = int(from.distance_to(to) / 8.0) + 1
            for n in steps + 1:
                if near.has_point(from.lerp(to, float(n) / float(steps))):
                    return false
    return true

# Whether tile column `tx` is mirrored left-to-right. Only the middle column is.
func _mirrored(tx: int) -> bool:
    return posmod(tx, 2) == 1

# The playable tiles; the others are outskirts.
func _is_play_tile(tx: int, ty: int) -> bool:
    return tx >= 0 and ty <= 1

# A point of the base district as it appears in tile (tx, ty).
func _tp(p: Vector2, tx: int, ty: int) -> Vector2:
    var x: float = LevelData.TILE.x - p.x if _mirrored(tx) else p.x
    return Vector2(x + float(tx) * LevelData.TILE.x, p.y + float(ty) * LevelData.TILE.y)

func _tr(r: Rect2, tx: int, ty: int) -> Rect2:
    var x: float = LevelData.TILE.x - r.end.x if _mirrored(tx) else r.position.x
    return Rect2(x + float(tx) * LevelData.TILE.x, r.position.y + float(ty) * LevelData.TILE.y, r.size.x, r.size.y)

# Builds one copy of the base district at tile (tx, ty).
func _build_tile(tx: int, ty: int) -> void:
    var play: bool = _is_play_tile(tx, ty)
    var tile_index: int = (ty + 1) * 7 + (tx + 1)
    var tile_rect := Rect2(Vector2(tx, ty) * LevelData.TILE, LevelData.TILE)
    var tile_buildings: Array = []
    for r in LevelData.BASE_BUILDINGS:
        var rect: Rect2 = _tr(r, tx, ty)
        main.buildings.append(rect)
        tile_buildings.append(rect)
    for p in LevelData.BASE_PROPS:
        var prop := PropScript.new()
        prop.main = main
        main.actors.add_child(prop)
        prop.global_position = _tp(p, tx, ty)
        main.props.append(prop)
    for v in (LevelData.BASE_VENTS if play else []):
        var vent := VentScript.new()
        vent.main = main
        vent.phase = v[1] + float(tile_index) * 1.7  # so the vents of different tiles aren't in step
        vent.z_index = -20
        main.actors.add_child(vent)
        vent.global_position = _tp(v[0], tx, ty)
        main.vents.append(vent)
    for pos in (LevelData.BASE_FIRES if play else []):
        var fire := FireScript.new()
        fire.main = main
        main.actors.add_child(fire)
        fire.global_position = _tp(pos, tx, ty)
        main.fires.append(fire)
    var routes: Array = []
    for base_route in LevelData.BASE_ROUTES:
        var route: Array = []
        for pt in base_route:
            route.append(_tp(pt, tx, ty))
        if not play:
            continue  # nobody patrols the outskirts
        routes.append(route)
        main.cop_routes.append(route)
        var cop := CopScript.new()
        main.actors.add_child(cop)
        cop.setup(main, route)
        main.cops.append(cop)
    for pos in (LevelData.BASE_CATS if play else []):
        var cat := CatScript.new()
        cat.main = main
        main.actors.add_child(cat)
        cat.global_position = _tp(pos, tx, ty)
        main.cats.append(cat)
    var first_car: int = main.cars.size()
    _make_cars_for(tile_buildings, routes, tile_rect)
    var first_lamp: int = main.lamps.size()
    _make_lamps_for(tile_buildings, routes, tile_rect, first_car)
    var first_obstacle_index: int = main.obstacles.size()
    _make_obstacles_for(tile_buildings, routes, tile_rect, first_car, first_lamp)
    _make_traffic_for(tile_buildings, routes, tile_rect, first_car, first_lamp, first_obstacle_index)

# Parked cars in one tile: nose to tail along the north and south kerbs of every
# block, and along some of the lanes between blocks. Candidates come from a fixed
# pattern and are kept only where they leave everything else clear (see
# _car_spot_ok): not on a patrol route, a bin, a barrel, a vent, the start spot or
# the front door, and lane cars only where a walkable corridor stays open.
func _make_cars_for(tile_buildings: Array, routes: Array, tile_rect: Rect2) -> void:
    var first_car: int = main.cars.size()
    for bi in tile_buildings.size():
        var b: Rect2 = tile_buildings[bi]
        if b == main.house:
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
                if (bi * 7 + side * 3 + k * 5) % 9 < 3:
                    _try_car(Rect2(x, y0, 40.0, 20.0), bi + k + side, k, tile_buildings, routes, tile_rect, first_car, 0.0)
                x += 62.0
                k += 1
        # West (side 0) and east (side 1) walls, along the lanes: cars point along y.
        for side in 2:
            var x0: float = b.position.x - 12.0 - 20.0 if side == 0 else b.end.x + 12.0
            var y: float = b.position.y + 12.0
            var k2 := 0
            while y + 40.0 < b.end.y - 8.0:
                if (bi * 5 + side * 2 + k2 * 7) % 9 < 1:
                    _try_car(Rect2(x0, y, 20.0, 40.0), bi + k2 + side + 3, k2, tile_buildings, routes, tile_rect, first_car, 56.0)
                y += 54.0
                k2 += 1

# Street lights at about half the corners of every block, wherever there is room
# for a slim post and nothing else is in the way.
func _make_lamps_for(tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int) -> void:
    var first_lamp: int = main.lamps.size()
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
            lamp.main = main
            lamp.flicker = (bi * 5 + ci * 3 + main.lamps.size()) % 9 == 0
            lamp.side = 1.0 if (bi + ci) % 2 == 0 else -1.0
            main.actors.add_child(lamp)
            lamp.global_position = p
            main.lamps.append(lamp)

func _lamp_spot_ok(p: Vector2, tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int, first_lamp: int) -> bool:
    if not tile_rect.grow(-24.0).has_point(p):
        return false
    for other in tile_buildings:
        if other.grow(10.0).has_point(p):
            return false
    for i in range(first_car, main.cars.size()):
        if main.cars[i].grow(10.0).has_point(p):
            return false
    for i in range(first_lamp, main.lamps.size()):
        if main.lamps[i].global_position.distance_to(p) < 115.0:
            return false
    if p.distance_to(main.START) < 40.0 or main.home_zone.grow(24.0).has_point(p):
        return false
    for q in main.props:
        if p.distance_to(q.global_position) < 22.0:
            return false
    for q in main.fires:
        if p.distance_to(q.global_position) < 44.0:
            return false
    for q in main.vents:
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
# --- Traffic ---------------------------------------------------------------------
# Cars drive the roads. To find roads, the tile is rasterised into 10-unit cells with
# everything a car can't pass marked blocked (buildings, parked cars, furniture, lamp
# posts, bins, patrol routes, the start, the front door). A road is then a long
# straight run of free cells wide enough for a car; the longest ones, kept apart from
# each other, become lanes, and each gets a car or two.
const LANE_CELL := 10.0
const MAX_LANES_H := 5
const MAX_LANES_V := 4
const MIN_LANE_CELLS := 60  # shortest road worth a car: 600 units

var _raster := PackedByteArray()
var _raster_cols := 0
var _raster_rows := 0
var _raster_origin := Vector2.ZERO

func _mark(r: Rect2) -> void:
    var x0: int = maxi(0, floori((r.position.x - _raster_origin.x) / LANE_CELL))
    var y0: int = maxi(0, floori((r.position.y - _raster_origin.y) / LANE_CELL))
    var x1: int = mini(_raster_cols - 1, floori((r.end.x - _raster_origin.x) / LANE_CELL))
    var y1: int = mini(_raster_rows - 1, floori((r.end.y - _raster_origin.y) / LANE_CELL))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            _raster[y * _raster_cols + x] = 1

func _make_traffic_for(tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int, first_lamp: int, first_obstacle: int) -> void:
    _raster_origin = tile_rect.position
    _raster_cols = int(LevelData.TILE.x / LANE_CELL)
    _raster_rows = int(LevelData.TILE.y / LANE_CELL)
    _raster.resize(_raster_cols * _raster_rows)
    _raster.fill(0)
    for b in tile_buildings:
        _mark(b.grow(10.0))
    for i in range(first_car, main.cars.size()):
        _mark(main.cars[i].grow(6.0))
    for i in range(first_obstacle, main.obstacles.size()):
        _mark(main.obstacles[i].grow(6.0))
    for i in range(first_lamp, main.lamps.size()):
        _mark(Rect2(main.lamps[i].global_position, Vector2.ZERO).grow(10.0))
    for p in main.props:
        if tile_rect.has_point(p.global_position):
            _mark(Rect2(p.global_position, Vector2.ZERO).grow(p.radius + 10.0))
    for f in main.fires:
        if tile_rect.has_point(f.global_position):
            _mark(Rect2(f.global_position, Vector2.ZERO).grow(f.body_radius + 10.0))
    for route in routes:
        for i in range(route.size() - 1):
            var from: Vector2 = route[i]
            var to: Vector2 = route[i + 1]
            var steps: int = int(from.distance_to(to) / 8.0) + 1
            for n in steps + 1:
                _mark(Rect2(from.lerp(to, float(n) / float(steps)), Vector2.ZERO).grow(18.0))
    _mark(Rect2(main.START, Vector2.ZERO).grow(220.0))
    _mark(main.home_zone.grow(120.0))
    # a margin at the tile edge so lanes stay inside their tile
    _mark(Rect2(tile_rect.position, Vector2(tile_rect.size.x, 30.0)))
    _mark(Rect2(tile_rect.position + Vector2(0.0, tile_rect.size.y - 30.0), Vector2(tile_rect.size.x, 30.0)))
    _mark(Rect2(tile_rect.position, Vector2(30.0, tile_rect.size.y)))
    _mark(Rect2(tile_rect.position + Vector2(tile_rect.size.x - 30.0, 0.0), Vector2(30.0, tile_rect.size.y)))

    var lanes: Array = _pick_lanes(true, MAX_LANES_H) + _pick_lanes(false, MAX_LANES_V)
    var index := 0
    for lane in lanes:
        var horizontal: bool = lane[0]
        var fixed: float = (float(lane[1]) + 0.5) * LANE_CELL + (_raster_origin.y if horizontal else _raster_origin.x)
        var origin_along: float = _raster_origin.x if horizontal else _raster_origin.y
        var a: float = (float(lane[2]) + 0.5) * LANE_CELL + origin_along
        var b: float = (float(lane[3]) + 0.5) * LANE_CELL + origin_along
        var count: int = 2 if (lane[3] - lane[2]) > 150 else 1
        for j in count:
            var car := TrafficScript.new()
            var dir: int = 1 if (index + j) % 2 == 0 else -1
            var spd: float = 110.0 + float((index * 37 + j * 53) % 40)
            var t: float = (float(j) + 0.3 + 0.4 * float((index * 17) % 10) / 10.0) / float(count)
            car.setup_traffic(main, horizontal, fixed, a, b, dir, spd, (index * 3 + j) % CarScript.BODY_COLORS.size(), t, main.traffic.size())
            main.actors.add_child(car)
            main.traffic.append(car)
        index += 1

# The longest free straight runs in the raster, one per road (roads kept 50+ units
# apart where they overlap along their length). Returns [horizontal, line, from, to]
# in cell coordinates.
func _pick_lanes(horizontal: bool, limit: int) -> Array:
    var lines: int = _raster_rows if horizontal else _raster_cols
    var along: int = _raster_cols if horizontal else _raster_rows
    var spans: Array = []
    for line in range(2, lines - 2):
        # A cell is unusable if any of the 3 cells across it is blocked.
        var bad := PackedInt32Array()
        bad.resize(along + 1)
        for i in along:
            var blocked := false
            for across in range(-1, 2):
                var x: int = i if horizontal else line + across
                var y: int = line + across if horizontal else i
                if _raster[y * _raster_cols + x] == 1:
                    blocked = true
                    break
            bad[i + 1] = bad[i] + (1 if blocked else 0)
        # A car needs 2 free cells either side of its centre, along the road.
        var run_start := -1
        for i in range(2, along - 2):
            var clear: bool = bad[i + 3] - bad[i - 2] == 0
            if clear and run_start < 0:
                run_start = i
            if (not clear or i == along - 3) and run_start >= 0:
                var run_end: int = i - 1 if not clear else i
                if run_end - run_start + 1 >= MIN_LANE_CELLS:
                    spans.append([run_end - run_start, line, run_start, run_end])
                run_start = -1
    spans.sort_custom(func(p: Array, q: Array) -> bool: return p[0] > q[0])
    var chosen: Array = []
    for s in spans:
        if chosen.size() >= limit:
            break
        var fine := true
        for c in chosen:
            if absi(c[1] - s[1]) < 6 and mini(c[3], s[3]) - maxi(c[2], s[2]) > 20:
                fine = false
                break
        if fine:
            chosen.append([horizontal, s[1], s[2], s[3]])
    return chosen

# Street furniture along the kerbs, in the gaps the cars and lamps leave. The kind
# comes from a fixed pattern; a spot is kept only where there is room and nothing
# important is in the way (see _obstacle_spot_ok).
func _make_obstacles_for(tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int, first_lamp: int) -> void:
    var first_obstacle: int = main.obstacles.size()
    var kinds: int = ObjectScript.Kind.size()
    for bi in tile_buildings.size():
        var b: Rect2 = tile_buildings[bi]
        if b == main.house:
            continue
        for side in 2:
            var x: float = b.position.x + 20.0
            var k := 0
            while x < b.end.x - 24.0:
                if (bi * 11 + side * 5 + k * 3) % 7 < 2:
                    var kind: int = (bi * 3 + side * 7 + k * 5) % kinds
                    var size: Vector2 = ObjectScript.size_of(kind)
                    # trees stand a little further out; the rest hug the kerb
                    var gap: float = 14.0 if kind == ObjectScript.Kind.TREE else 7.0
                    var y: float = b.position.y - gap - size.y if side == 0 else b.end.y + gap
                    var r := Rect2(x, y, size.x, size.y)
                    if _obstacle_spot_ok(r, tile_buildings, routes, tile_rect, first_car, first_lamp, first_obstacle):
                        main.obstacles.append(r)
                        var obj := ObjectScript.new()
                        obj.setup_object(r, kind, main.obstacles.size())
                        main.actors.add_child(obj)
                        main.building_nodes.append(obj)
                x += 74.0
                k += 1

func _obstacle_spot_ok(r: Rect2, tile_buildings: Array, routes: Array, tile_rect: Rect2, first_car: int, first_lamp: int, first_obstacle: int) -> bool:
    if not tile_rect.grow(-16.0).encloses(r):
        return false
    for other in tile_buildings:
        if other.grow(3.0).intersects(r):
            return false
    for i in range(first_car, main.cars.size()):
        if main.cars[i].grow(6.0).intersects(r):
            return false
    for i in range(first_obstacle, main.obstacles.size()):
        if main.obstacles[i].grow(8.0).intersects(r):
            return false
    var c: Vector2 = r.get_center()
    if c.distance_to(main.START) < 130.0 or r.grow(40.0).intersects(main.home_zone):
        return false
    for i in range(first_lamp, main.lamps.size()):
        if main.lamps[i].global_position.distance_to(c) < r.size.x * 0.5 + 12.0:
            return false
    for p in main.props:
        if c.distance_to(p.global_position) < 36.0:
            return false
    for f in main.fires:
        if c.distance_to(f.global_position) < 46.0:
            return false
    for v in main.vents:
        if c.distance_to(v.global_position) < 56.0:
            return false
    var clear: Rect2 = r.grow(26.0)
    for route in routes:
        for i in range(route.size() - 1):
            var from: Vector2 = route[i]
            var to: Vector2 = route[i + 1]
            var steps: int = int(from.distance_to(to) / 8.0) + 1
            for n in steps + 1:
                if clear.has_point(from.lerp(to, float(n) / float(steps))):
                    return false
    for cat in main.cats:
        if r.grow(10.0).has_point(cat.global_position):
            return false
    return true

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
    main.cars.append(r)
    var car := CarScript.new()
    car.setup_car(r, (color_seed + main.car_count) % CarScript.BODY_COLORS.size(), 1 if (color_seed + k) % 2 == 0 else -1, main.car_count)
    main.actors.add_child(car)
    main.building_nodes.append(car)
    main.car_count += 1

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
    for i in range(first_car, main.cars.size()):
        if main.cars[i].grow(5.0).intersects(r):
            return false
    var c: Vector2 = r.get_center()
    if c.distance_to(main.START) < 130.0 or r.grow(40.0).intersects(main.home_zone):
        return false
    for p in main.props:
        if c.distance_to(p.global_position) < 44.0:
            return false
    for f in main.fires:
        if c.distance_to(f.global_position) < 50.0:
            return false
    for v in main.vents:
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
    for cat in main.cats:
        if r.grow(10.0).has_point(cat.global_position):
            return false
    return true

# Storeys, wall colour and ground-floor style are picked from the index so the
# street has a mix: low shops, two-storey blocks and three-storey buildings.
func _add_building(rect: Rect2, index: int) -> void:
    var is_house: bool = rect == main.house
    var floors: int = 3 if is_house else [2, 3, 2, 1, 3, 2, 2][(index * 3 + 1) % 7]
    var b := BuildingScript.new()
    b.setup(rect, floors, (index * 2 + index / 5) % 5, floors == 1 or index % 4 == 1, is_house, index)
    main.actors.add_child(b)
    main.building_nodes.append(b)

# A ring of scenery blocks around the street. They aren't walls: the world
# edge already stops everyone. More room is left on the south and east sides,
# where tall blocks would otherwise stand in front of the player.
func _make_decor() -> void:
    var outer: Rect2 = main.world_rect.grow(main.DECOR_MARGIN)
    var keep_out: Rect2 = main.world_rect.grow_individual(24.0, 24.0, 140.0, 140.0)
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
                main.decor.append(r)
            y += 290.0
            row += 1
        x += 360.0
        col += 1
