extends RefCounted
# Turns the city plan (LevelData.gd) into the world: builds every tile (buildings,
# bins, vents, fires, patrolling cops, cats), parks cars along the streets, lines the
# kerbs with street lights and furniture, dresses the plazas, adds the ring of
# scenery round the playable area, and makes the building nodes. Everything it
# creates is added to Main's lists (buildings, cars, lamps, props, cops, ...), which
# the rest of the game reads. Roads and the things on them (parked cars, lane
# markings, traffic) never depend on mirroring; buildings and what goes with them do.

const LevelData := preload("res://scripts/LevelData.gd")
const Sprites := preload("res://scripts/Sprites.gd")
const LevelSettingsScript := preload("res://scripts/LevelSettings.gd")
const PropScript := preload("res://scripts/Prop.gd")
const VentScript := preload("res://scripts/SteamVent.gd")
const FireScript := preload("res://scripts/Fire.gd")
const CopScript := preload("res://scripts/Cop.gd")
const CatScript := preload("res://scripts/Cat.gd")
const BuildingScript := preload("res://scripts/Building.gd")
const CarScript := preload("res://scripts/Car.gd")
const LampScript := preload("res://scripts/StreetLight.gd")
const ObjectScript := preload("res://scripts/StreetObject.gd")
const NpcScript := preload("res://scripts/StreetNpc.gd")
const PickupScript := preload("res://scripts/Pickup.gd")
const SquirrelScript := preload("res://scripts/Squirrel.gd")
const PhoneBoothScript := preload("res://scripts/PhoneBooth.gd")

var main

func _init(game) -> void:
    main = game

# A coroutine so the web build can show progress and give the browser a frame between
# tiles (see Main.boot_step); elsewhere it runs straight through.
func build() -> void:
    _choose_home()
    var tiles := float((LevelData.TILE_MAX.x - LevelData.TILE_MIN.x + 1) * (LevelData.TILE_MAX.y - LevelData.TILE_MIN.y + 1))
    var done := 0.0
    # Playable tiles first (so cop, cat and bin lists start with tile (0,0)), then outskirts.
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            if _is_play_tile(tx, ty):
                _build_tile(tx, ty)
                done += 1.0
                await main.boot_step("city", 0.7 * done / tiles)
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            if not _is_play_tile(tx, ty):
                _build_tile(tx, ty)
                done += 1.0
                await main.boot_step("city", 0.7 * done / tiles)
    _make_decor()
    var first_building: int = main.building_nodes.size()
    var total: float = float(main.buildings.size() + main.decor.size())
    for i in main.buildings.size():
        _add_building(main.buildings[i], i)
        if i % 40 == 0:
            await main.boot_step("city", 0.7 + 0.3 * float(i) / total)
    for i in main.decor.size():
        _add_building(main.decor[i], main.buildings.size() + i)
        if i % 40 == 0:
            await main.boot_step("city", 0.7 + 0.3 * float(main.buildings.size() + i) / total)
    _remove_vents_behind_buildings(first_building)
    await _assign_phones()
    await main.boot_step("city", 1.0)

# A steam vent whose plume rises behind a building looks like the building is smoking (and
# the grate itself is hidden), so any vent that stands behind a building, with its plume
# overlapping that building on the screen, is taken out.
const PLUME := Rect2(-16.0, -78.0, 32.0, 82.0)  # the plume's screen box, relative to the grate's iso position

func _remove_vents_behind_buildings(first_building: int) -> void:
    var nodes: Array = main.building_nodes.slice(first_building, first_building + main.buildings.size())
    for v in main.vents.duplicate():
        var p: Vector2 = v.global_position
        var plume := Rect2(Sprites.iso(p) + PLUME.position, PLUME.size)
        for b in nodes:
            var r: Rect2 = b.rect
            var behind: bool = not (p.x >= r.end.x or p.y >= r.end.y)
            if behind and b.screen_box.intersects(plume):
                main.vents.erase(v)
                v.queue_free()
                break

# Most booths are scenery (dark); every few of the ones you can actually see still take a
# call. A booth with a building in front of it would show only its floating marker, so those
# are never the working ones.
func _assign_phones() -> void:
    if not main.settings.phones:
        return  # a later level: nobody to ask the way, every booth is scenery
    var seen := 0
    var checked := 0
    for obj in booth_objects:
        checked += 1
        if checked % 12 == 0:
            await main.boot_step("city", 1.0)
        if _booth_hidden(obj):
            continue
        seen += 1
        if seen % PHONE_WORKING_EVERY != 1:
            continue
        obj.working = true
        var booth := PhoneBoothScript.new()
        booth.main = main
        booth.obj = obj
        main.actors.add_child(booth)
        booth.global_position = obj.rect.get_center()
        main.phones.append(booth)

# Is a booth covered, on the screen, by a building standing in front of it?
func _booth_hidden(obj) -> bool:
    var c: Vector2 = obj.rect.get_center()
    var foot: Vector2 = Sprites.iso(c)
    var body := Rect2(foot + Vector2(-9.0, -50.0), Vector2(18.0, 52.0))
    for b in main.building_nodes:
        if b is ObjectScript:
            continue
        var r: Rect2 = b.rect
        if c.x >= r.end.x or c.y >= r.end.y:
            continue  # beside it or in front of it
        if not b.screen_box.intersects(body):
            continue
        var poly: PackedVector2Array = b.silhouette()
        for z in [6.0, 24.0, 42.0]:
            if Geometry2D.is_point_in_polygon(foot + Vector2(0.0, -z), poly):
                return true
    return false

# --- Home ------------------------------------------------------------------------
# Picks which building is home, this run: a wide building well away from the start,
# whose pavement in front of the door is clear (no bin, barrel, vent or patrol on
# it). Sets main.house and main.home_zone, which the cars, lamps, map and win check
# all read.
# (how far the front door is from the start comes from the level: main.settings.home_min)

func _choose_home() -> void:
    var options: Array = []
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            if not _is_play_tile(tx, ty):
                continue
            for base in LevelData.base_buildings():
                var r: Rect2 = _tr(base, tx, ty)
                if r.size.x < 160.0 or r.size.y < 90.0:
                    continue
                # The pavement in front of the glowing door Building draws on a house.
                var zone := Rect2(r.end.x - 130.0, r.end.y + 1.0, 60.0, 16.0)
                if _home_spot_clear(zone, tx, ty):
                    options.append([r, zone])
    # The level's distance band; if no house falls in it (it shouldn't happen), the nearest-fitting ones.
    var in_band: Array = options.filter(func(o): 
        var away: float = o[1].get_center().distance_to(main.START)
        return away >= float(main.settings.home_min) and away <= float(main.settings.home_max))
    if in_band.is_empty():
        in_band = options.filter(func(o): return o[1].get_center().distance_to(main.START) >= float(main.settings.home_min))
    if not in_band.is_empty():
        options = in_band
    var rng := RandomNumberGenerator.new()
    if main.home_seed >= 0:
        rng.seed = main.home_seed
    else:
        rng.randomize()
    var pick: Array = options[rng.randi() % options.size()]
    main.house = pick[0]
    main.home_zone = pick[1]

func _home_spot_clear(zone: Rect2, tx: int, ty: int) -> bool:
    var centre: Vector2 = zone.get_center()
    for p in LevelData.base_props():
        if _tp(p, tx, ty).distance_to(centre) < 40.0:
            return false
    for p in LevelData.base_fires():
        if _tp(p, tx, ty).distance_to(centre) < 60.0:
            return false
    for v in LevelData.base_vents():
        if _tp(v[0], tx, ty).distance_to(centre) < 50.0:
            return false
    var near := Rect2(centre, Vector2.ZERO).grow(46.0)
    for route in LevelData.base_routes():
        for i in route.size():
            var from: Vector2 = _tp(route[i], tx, ty)
            var to: Vector2 = _tp(route[(i + 1) % route.size()], tx, ty)
            var steps: int = int(from.distance_to(to) / 8.0) + 1
            for n in steps + 1:
                if near.has_point(from.lerp(to, float(n) / float(steps))):
                    return false
    return true

# --- Tiles -----------------------------------------------------------------------
# Whether tile column `tx` is mirrored left-to-right. Odd columns are.
func _mirrored(tx: int) -> bool:
    return posmod(tx, 2) == 1

# The playable tiles; the others are outskirts.
func _is_play_tile(tx: int, ty: int) -> bool:
    return tx >= 0 and ty <= 1

# A point of the base tile as it appears in tile (tx, ty), mirrored in odd columns.
func _tp(p: Vector2, tx: int, ty: int) -> Vector2:
    var x: float = LevelData.TILE.x - p.x if _mirrored(tx) else p.x
    return Vector2(x + float(tx) * LevelData.TILE.x, p.y + float(ty) * LevelData.TILE.y)

func _tr(r: Rect2, tx: int, ty: int) -> Rect2:
    var x: float = LevelData.TILE.x - r.end.x if _mirrored(tx) else r.position.x
    return Rect2(x + float(tx) * LevelData.TILE.x, r.position.y + float(ty) * LevelData.TILE.y, r.size.x, r.size.y)

# Builds one copy of the base tile at tile (tx, ty).
func _build_tile(tx: int, ty: int) -> void:
    var play: bool = _is_play_tile(tx, ty)
    var tile_index: int = (ty + 1) * 7 + (tx + 1)
    var tile_rect := Rect2(Vector2(tx, ty) * LevelData.TILE, LevelData.TILE)
    var tile_buildings: Array = []
    for r in LevelData.base_buildings():
        var rect: Rect2 = _tr(r, tx, ty)
        main.buildings.append(rect)
        tile_buildings.append(rect)
    for p in LevelData.base_props():
        var prop := PropScript.new()
        prop.main = main
        main.actors.add_child(prop)
        prop.global_position = _tp(p, tx, ty)
        main.props.append(prop)
    for v in (LevelData.base_vents() if play else []):
        var vent := VentScript.new()
        vent.main = main
        vent.phase = v[1] + float(tile_index) * 1.7  # so the vents of different tiles aren't in step
        vent.z_index = -20
        main.actors.add_child(vent)
        vent.global_position = _tp(v[0], tx, ty)
        main.vents.append(vent)
    for pos in (LevelData.base_fires() if play else []):
        var fire := FireScript.new()
        fire.main = main
        main.actors.add_child(fire)
        fire.global_position = _tp(pos, tx, ty)
        main.fires.append(fire)
    var routes: Array = []
    var route_index := -1
    for base_route in LevelData.base_routes():
        route_index += 1
        if not play:
            break  # nobody patrols the outskirts
        var route: Array = []
        for pt in base_route:
            route.append(_tp(pt, tx, ty))
        routes.append(route)  # (placement keeps clear of every route, even one nobody walks)
        var too_close := false
        for pt in route:
            if pt.distance_to(main.START) < SAFE_COPS:
                too_close = true
        if too_close or not LevelSettingsScript.keeps(route_index, tile_index, float(main.settings.cops)):
            continue  # too near the start, or not a patrol this level has
        main.cop_routes.append(route)
        var cop := CopScript.new()
        main.actors.add_child(cop)
        cop.setup(main, route)
        main.cops.append(cop)
    for pos in (LevelData.base_cats() if play else []):
        var cat := CatScript.new()
        cat.main = main
        main.actors.add_child(cat)
        cat.global_position = _tp(pos, tx, ty)
        main.cats.append(cat)

    var first_car: int = main.cars.size()
    _make_cars_for(tx, ty, tile_rect)
    var first_lamp: int = main.lamps.size()
    _make_lamps_for(tx, ty, routes, tile_rect)
    var first_obstacle: int = main.obstacles.size()
    _make_furniture_for(tx, ty, routes, tile_rect, first_lamp, first_obstacle)
    if play:
        _make_street_people(tx, ty, first_lamp)
        _make_zombies_for(tx, ty)
        _make_pickups_for(first_lamp)

# --- Parked cars -------------------------------------------------------------------
# Cars stand nose to tail in the parking lane on the north (or west) side of each
# street, facing the way the lane beside them flows. Not on avenues, and not near
# a junction.
func _make_cars_for(tx: int, ty: int, tile_rect: Rect2) -> void:
    var first_car: int = main.cars.size()
    var index := 0
    for road in LevelData.roads():
        if road.avenue:
            continue
        var horizontal: bool = road.horizontal
        var length: float = LevelData.TILE.x if horizontal else LevelData.TILE.y
        var crossing: Array = LevelData.ROADS_X if horizontal else LevelData.ROADS_Y
        var along := 80.0
        var k := 0
        while along + 40.0 < length - 80.0:
            var mid: float = along + 20.0
            var at_junction := false
            for c in crossing:
                if absf(mid - c[0]) < c[1] * 0.5 + 26.0:
                    at_junction = true
            if not at_junction and (int(road.centre) / 10 * 3 + k * 5 + (1 if horizontal else 0)) % 9 < 4:
                var lane: float = road.centre + LevelData.PARKING_OFFSET
                var r: Rect2
                if horizontal:
                    r = Rect2(tile_rect.position + Vector2(along, lane - 10.0), Vector2(40.0, 20.0))
                else:
                    r = Rect2(tile_rect.position + Vector2(lane - 10.0, along), Vector2(20.0, 40.0))
                if _car_spot_ok(r, tile_rect, first_car):
                    main.cars.append(r)
                    var car := CarScript.new()
                    var facing: int = -1 if horizontal else 1
                    car.setup_car(r, (index + k) % CarScript.BODY_COLORS.size(), facing, main.car_count)
                    main.actors.add_child(car)
                    main.building_nodes.append(car)
                    main.car_count += 1
                    index += 1
            along += 56.0
            k += 1

func _car_spot_ok(r: Rect2, tile_rect: Rect2, first_car: int) -> bool:
    if not tile_rect.grow(-16.0).encloses(r):
        return false
    for i in range(first_car, main.cars.size()):
        if main.cars[i].grow(6.0).intersects(r):
            return false
    return r.get_center().distance_to(main.START) > 130.0

# --- Street lights -----------------------------------------------------------------
# Along the kerb of every block, spaced out, where nothing else is in the way.
func _make_lamps_for(tx: int, ty: int, routes: Array, tile_rect: Rect2) -> void:
    var first_lamp: int = main.lamps.size()
    var n := 0
    for b in LevelData.blocks():
        var r: Rect2 = _tr(b.rect, tx, ty)
        var spots: Array = []
        var t := 50.0
        while t < r.size.x - 40.0:
            spots.append(Vector2(r.position.x + t, r.position.y + 4.5))
            spots.append(Vector2(r.position.x + t + 55.0, r.end.y - 4.5))
            t += 130.0
        t = 45.0
        while t < r.size.y - 40.0:
            spots.append(Vector2(r.position.x + 4.5, r.position.y + t + 20.0))
            spots.append(Vector2(r.end.x - 4.5, r.position.y + t))
            t += 110.0
        for p in spots:
            n += 1
            if n % 10 >= 7:
                continue
            if not _lamp_spot_ok(p, routes, tile_rect, first_lamp):
                continue
            var lamp := LampScript.new()
            lamp.main = main
            lamp.flicker = n % 9 == 0
            lamp.side = 1.0 if n % 2 == 0 else -1.0
            main.actors.add_child(lamp)
            lamp.global_position = p
            main.lamps.append(lamp)

func _lamp_spot_ok(p: Vector2, routes: Array, tile_rect: Rect2, first_lamp: int) -> bool:
    if not tile_rect.grow(-24.0).has_point(p):
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
        if p.distance_to(q.global_position) < 24.0:
            return false
    return not _near_route(p, routes, 9.0)

# Is a point within `margin` of any patrol route in this tile?
func _near_route(p: Vector2, routes: Array, margin: float) -> bool:
    var near := Rect2(p, Vector2.ZERO).grow(margin)
    for route in routes:
        for i in route.size():
            var from: Vector2 = route[i]
            var to: Vector2 = route[(i + 1) % route.size()]
            var steps: int = int(from.distance_to(to) / 6.0) + 1
            for n in steps + 1:
                if near.has_point(from.lerp(to, float(n) / float(steps))):
                    return true
    return false

# --- Street furniture ----------------------------------------------------------------
# Along the pavements, in the alleys and in the plazas.
func _make_furniture_for(tx: int, ty: int, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> void:
    var K = ObjectScript.Kind
    var wide_kinds: Array = [K.HYDRANT, K.MAILBOX, K.BENCH, K.PHONE, K.TREE, K.CONES, K.PLANTER, K.BARRICADE]
    var narrow_kinds: Array = [K.HYDRANT, K.MAILBOX, K.PHONE, K.TREE]
    var n := 0
    # Pavements round each built block.
    for b in LevelData.blocks():
        if b.plaza:
            continue
        var r: Rect2 = _tr(b.rect, tx, ty)
        var x := 40.0
        while x < r.size.x - 70.0:
            for side in 2:
                n += 1
                if n % 7 >= 2:
                    continue
                var kind: int = wide_kinds[(n * 3 + side) % wide_kinds.size()]
                if kind == K.PHONE and side == 0:
                    kind = K.MAILBOX  # a booth on the far pavement would stand hidden behind the block's buildings
                elif side == 1 and n % 28 == 8:
                    kind = K.PHONE  # the near pavement, facing the street, is where they can be seen
                var sz: Vector2 = ObjectScript.size_of(kind)
                var yc: float = r.position.y + 9.0 if side == 0 else r.end.y - 9.0
                _add_object(Rect2(r.position.x + x, yc - sz.y * 0.5, sz.x, sz.y), kind, routes, tile_rect, first_lamp, first_obstacle)
            x += 85.0
        var y := 50.0
        while y < r.size.y - 60.0:
            for side in 2:
                n += 1
                if n % 9 >= 2:
                    continue
                var kind2: int = narrow_kinds[(n * 5 + side) % narrow_kinds.size()]
                var sz2: Vector2 = ObjectScript.size_of(kind2)
                var xc: float = r.position.x + 9.0 if side == 0 else r.end.x - 9.0
                _add_object(Rect2(xc - sz2.x * 0.5, r.position.y + y, sz2.x, sz2.y), kind2, routes, tile_rect, first_lamp, first_obstacle)
            y += 85.0
    # A fire hydrant on the pavement beside every other block, for Stella.
    var hb := 0
    for b in LevelData.blocks():
        if b.plaza:
            continue
        hb += 1
        if hb % 2 != 0:
            continue
        var rb: Rect2 = _tr(b.rect, tx, ty)
        var hsz: Vector2 = ObjectScript.size_of(K.HYDRANT)
        var hx: float = rb.position.x + 50.0 + float((hb * 37) % 70)
        var hy: float = rb.position.y + 9.0 if hb % 4 == 0 else rb.end.y - 9.0
        _add_object(Rect2(hx - hsz.x * 0.5, hy - hsz.y * 0.5, hsz.x, hsz.y), K.HYDRANT, routes, tile_rect, first_lamp, first_obstacle)
    # Dumpsters and crates in some alleys (the ones with a burn barrel stay clear).
    var alleys: Array = LevelData.alleys()
    for k in alleys.size():
        if k % 4 == 2 or k % 3 != 0:
            continue
        var a: Array = alleys[k]
        var z: Rect2 = a[2]
        var kind3: int = K.DUMPSTER if k % 2 == 0 else K.CRATES
        var base_sz: Vector2 = ObjectScript.size_of(kind3)
        var sz3 := Vector2(minf(base_sz.y, 18.0), base_sz.x) if kind3 == K.DUMPSTER else base_sz  # turned to run along the alley
        var centre: Vector2 = _tp(Vector2(a[0], z.position.y + 36.0), tx, ty)
        _add_object(Rect2(centre - sz3 * 0.5, sz3), kind3, routes, tile_rect, first_lamp, first_obstacle)
    # Plazas: a fountain in the middle, trees at the corners, benches and planters.
    for plaza in LevelData.plazas():
        _dress_plaza(plaza, tx, ty, routes, tile_rect, first_lamp, first_obstacle)

func _dress_plaza(base: Rect2, tx: int, ty: int, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> void:
    var K = ObjectScript.Kind
    var c: Vector2 = base.get_center()
    var items: Array = [
        [K.FOUNTAIN, c],
        [K.TREE, Vector2(base.position.x + 70.0, base.position.y + 60.0)],
        [K.TREE, Vector2(base.end.x - 70.0, base.position.y + 60.0)],
        [K.TREE, Vector2(base.position.x + 70.0, base.end.y - 60.0)],
        [K.TREE, Vector2(base.end.x - 70.0, base.end.y - 60.0)],
        [K.TREE, c + Vector2(-150.0, 0.0)],
        [K.TREE, c + Vector2(150.0, 0.0)],
        [K.BENCH, c + Vector2(-55.0, -62.0)],
        [K.BENCH, c + Vector2(55.0, 62.0)],
        [K.BENCH, c + Vector2(-55.0, 62.0)],
        [K.BENCH, c + Vector2(55.0, -62.0)],
        [K.PLANTER, c + Vector2(-210.0, -80.0)],
        [K.PLANTER, c + Vector2(210.0, 80.0)],
        [K.PLANTER, c + Vector2(-210.0, 80.0)],
        [K.PLANTER, c + Vector2(210.0, -80.0)],
    ]
    var benches: Array = []
    for it in items:
        var sz: Vector2 = ObjectScript.size_of(it[0])
        var p: Vector2 = _tp(it[1], tx, ty)
        var obj = _add_object(Rect2(p - sz * 0.5, sz), it[0], routes, tile_rect, first_lamp, first_obstacle)
        if obj != null and it[0] == K.BENCH:
            benches.append(obj)
    _seat_zombies(_tp(c, tx, ty), benches)

# Zombies asleep in a plaza (from level 2): one laid out on a park bench and one slumped on the
# ground by the fountain, in about two plazas out of three.
var plaza_count := 0

func _seat_zombies(centre: Vector2, benches: Array) -> void:
    plaza_count += 1
    if float(main.settings.zombies) <= 0.0 or plaza_count % 3 == 0:
        return
    if not LevelSettingsScript.keeps(plaza_count, 5, float(main.settings.zombies)):
        return
    if not benches.is_empty():
        var bench = benches[plaza_count % benches.size()]
        var spot := Vector2(bench.rect.get_center().x, bench.rect.end.y + 7.5)  # just in front of the bench
        if _npc_spot_ok(spot):
            _add_npc(NpcScript.Kind.ZOMBIE, spot, "lie", bench)
    for off in [Vector2(0.0, 30.0), Vector2(-30.0, 12.0), Vector2(30.0, 12.0), Vector2(0.0, -30.0)]:
        if _npc_spot_ok(centre + off):
            _add_npc(NpcScript.Kind.ZOMBIE, centre + off, "sit")
            break

func _add_object(r: Rect2, kind: int, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> Node:
    if not _obstacle_spot_ok(r, routes, tile_rect, first_lamp, first_obstacle):
        return null
    main.obstacles.append(r)
    var obj := ObjectScript.new()
    obj.setup_object(r, kind, main.obstacles.size())
    main.actors.add_child(obj)
    main.building_nodes.append(obj)
    if kind == ObjectScript.Kind.FOUNTAIN:
        obj.main = main  # so the water can move while it is in view
    if kind == ObjectScript.Kind.PHONE:
        booth_objects.append(obj)  # which ones work is decided once every building is up (_assign_phones)
    if kind == ObjectScript.Kind.HYDRANT:
        main.hydrants.append(obj)
    elif kind == ObjectScript.Kind.TREE:
        main.trees.append(r.get_center())
        if main.trees.size() % 4 == 0 and main.settings.squirrels:
            _add_squirrel(r.get_center())
    return obj

# A squirrel at the foot of a tree, on a spot clear of anything solid.
func _add_squirrel(tree_at: Vector2) -> void:
    for k in 8:
        var cand: Vector2 = tree_at + Vector2.from_angle(float(k) * TAU / 8.0 + 0.6) * 16.0
        if _npc_spot_ok(cand):
            var sq := SquirrelScript.new()
            sq.setup(main, tree_at, cand)
            main.actors.add_child(sq)
            sq.global_position = cand
            main.squirrels.append(sq)
            return

func _obstacle_spot_ok(r: Rect2, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> bool:
    if not tile_rect.grow(-16.0).encloses(r):
        return false
    for b in main.buildings:
        if b.intersects(r):
            return false
    for i in range(first_obstacle, main.obstacles.size()):
        if main.obstacles[i].grow(6.0).intersects(r):
            return false
    var c: Vector2 = r.get_center()
    if c.distance_to(main.START) < 70.0 or r.grow(30.0).intersects(main.home_zone):
        return false
    for i in range(first_lamp, main.lamps.size()):
        if main.lamps[i].global_position.distance_to(c) < r.size.x * 0.5 + 9.0:
            return false
    for p in main.props:
        if c.distance_to(p.global_position) < 22.0 + r.size.x * 0.4:
            return false
    for f in main.fires:
        if c.distance_to(f.global_position) < 34.0:
            return false
    for v in main.vents:
        if c.distance_to(v.global_position) < 30.0:
            return false
    for cat in main.cats:
        if r.grow(8.0).has_point(cat.global_position):
            return false
    return not _near_route(c, routes, 16.0 + minf(r.size.x, 20.0) * 0.4)

# --- Street people -------------------------------------------------------------------
# A hobo by every burn barrel, and two punks under every so-many-th street light (not
# near the start).
func _make_street_people(tx: int, ty: int, first_lamp: int) -> void:
    if main.settings.hobos:
        for f in LevelData.base_fires():
            var spot: Vector2 = _tp(f, tx, ty) + Vector2(2.0, 18.0)
            _add_npc(NpcScript.Kind.HOBO, spot)
    if float(main.settings.punks) <= 0.0:
        return
    var n := 0
    for i in range(first_lamp, main.lamps.size()):
        n += 1
        if n % 22 != 4:  # one lamp in twenty-two, so they are a rarer hazard
            continue
        if not LevelSettingsScript.keeps(n, i, float(main.settings.punks)):
            continue
        var lamp_pos: Vector2 = main.lamps[i].global_position
        var placed := 0
        for k in 8:
            var cand: Vector2 = lamp_pos + Vector2.from_angle(float(k) * TAU / 8.0 + 0.4) * 17.0
            if _npc_spot_ok(cand):
                _add_npc(NpcScript.Kind.PUNK, cand)
                placed += 1
                if placed == 2:
                    break

# Pizza slices to restore life, left on the pavement under some of the street lights
# (so reaching one means standing in the light), and well away from the start and
# the front door.
const PICKUP_EVERY := 6

# Breathing room at the start. Nothing that hunts her is placed within these distances of
# the start (cops patrol, street people and zombies live, no traffic before TrafficDirector's
# ramp), so there is time to look around, play with the fountain and the squirrels, and
# learn the controls before the first threat. Danger then builds up with distance.
const SAFE_COPS := 1000.0    # no cop whose patrol comes within this of the start
const SAFE_PEOPLE := 900.0   # no hobo, punk or zombie within this
const PHONE_WORKING_EVERY := 3  # one visible booth in three takes a call
var booth_objects: Array = []  # every phone booth on the street, working or not
func _make_pickups_for(first_lamp: int) -> void:
    var n := 0
    for i in range(first_lamp, main.lamps.size()):
        n += 1
        if n % PICKUP_EVERY != 2:
            continue
        var lamp_pos: Vector2 = main.lamps[i].global_position
        for k in 8:
            var cand: Vector2 = lamp_pos + Vector2.from_angle(float(k) * TAU / 8.0 + 1.1) * 22.0
            if _npc_spot_ok(cand) and cand.distance_to(main.START) > 400.0:
                var pickup := PickupScript.new()
                pickup.main = main
                main.actors.add_child(pickup)
                pickup.global_position = cand
                main.pickups.append(pickup)
                break

# Zombie hobos doze in some of the alleys, two or three together.
func _make_zombies_for(tx: int, ty: int) -> void:
    if float(main.settings.zombies) <= 0.0:
        return
    var alleys: Array = LevelData.alleys()
    for k in alleys.size():
        if k % 5 != 1:
            continue
        if not LevelSettingsScript.keeps(k, tx + ty, float(main.settings.zombies)):
            continue
        var a: Array = alleys[k]
        var z: Rect2 = a[2]
        var centre: Vector2 = _tp(Vector2(a[0], z.position.y + 90.0), tx, ty)
        var placed := 0
        for j in 6:
            var cand: Vector2 = centre + Vector2(0.0, float(j - 1) * 16.0)  # the alley runs north-south
            if _npc_spot_ok(cand) and not _tile_is_start(cand):
                _add_npc(NpcScript.Kind.ZOMBIE, cand)
                placed += 1
                if placed == 2 + k % 2:
                    break

func _tile_is_start(p: Vector2) -> bool:
    return p.distance_to(main.START) < SAFE_PEOPLE

func _npc_spot_ok(p: Vector2) -> bool:
    for b in main.buildings:
        if b.grow(6.0).has_point(p):
            return false
    for o in main.obstacles:
        if o.grow(6.0).has_point(p):
            return false
    for c in main.cars:
        if c.grow(6.0).has_point(p):
            return false
    return p.distance_to(main.START) > 300.0 and not main.home_zone.grow(60.0).has_point(p)

func _add_npc(kind: int, p: Vector2, pose: String = "", bench = null) -> void:
    if p.distance_to(main.START) < SAFE_PEOPLE:
        return
    var npc := NpcScript.new()
    npc.setup(main, kind, p, pose, bench)
    main.actors.add_child(npc)
    npc.global_position = p
    main.npcs.append(npc)

# --- Buildings and scenery -------------------------------------------------------------
func _add_building(rect: Rect2, index: int) -> void:
    var is_house: bool = rect == main.house
    var floors: int = 3 if is_house else [2, 3, 2, 1, 3, 2, 2][(index * 3 + 1) % 7]
    var b := BuildingScript.new()
    b.setup(rect, floors, (index * 2 + index / 5) % 5, floors == 1 or index % 4 == 1, is_house, index)
    main.actors.add_child(b)
    main.building_nodes.append(b)

# A ring of scenery blocks around the playable area. They aren't walls: the world
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
