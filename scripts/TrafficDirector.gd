extends Node
# Keeps traffic flowing round Nicole. Cars spawn on the lanes of the nearby roads well
# outside the view, drive along them, and are removed once they are far behind, so a
# car is never seen appearing or vanishing. The lanes are the right-hand lanes of every
# road of the grid, running the whole width (or height) of the world.
#
# It also keeps Nicole moving: stand about for too long and zombie hobos start turning
# up out of sight and shambling towards her (see StreetNpc.gd, Kind.ZOMBIE).
const NpcScript := preload("res://scripts/StreetNpc.gd")

const TrafficScript := preload("res://scripts/Traffic.gd")
const CarScript := preload("res://scripts/Car.gd")
const SkaterScript := preload("res://scripts/Skater.gd")
const PoliceScript := preload("res://scripts/PoliceCar.gd")
const LevelData := preload("res://scripts/LevelData.gd")

# (how many cars and skateboarders to keep near her comes from the level: main.settings.cars / .skaters)
const ACTIVE_RADIUS := 1000.0
const DESPAWN_RADIUS := 1250.0
const SPAWN_MIN := 700.0      # spawn at least this far away: outside the view
const SPAWN_MAX := 1000.0
const LANE_REACH := 600.0     # lanes this close to Nicole's position can spawn cars
const GAP := 110.0            # keep this much room between cars on one lane
const LINGER_RADIUS := 70.0   # staying within this of one spot counts as standing about
const LINGER_AFTER := 8.0     # seconds of that before the first zombie sets out
const LINGER_EVERY := 4.0     # then another this often
const LINGER_MAX := 6         # drifting zombies at once
const DRIFT_MIN := 480.0      # they appear this far away: out of the view
const DRIFT_MAX := 600.0
# Traffic builds up with distance from the start: none for the first stretch, the full
# amount from RAMP_FULL on. (Same for the linger zombies, which also wait out the first
# LINGER_GRACE seconds.)
const RAMP_START := 700.0
const RAMP_FULL := 2200.0
const LINGER_GRACE := 45.0

var main
var enabled := true  # tests switch it off
var lanes: Array = []  # {horizontal, fixed, dir, a, b, speed}
var road_xs: Array = []  # the vertical roads, left to right: {centre, avenue} (police cars turn at their junctions)
var road_ys: Array = []  # the horizontal roads, top to bottom
var timer := 0.0
var anchor := Vector2.ZERO
var linger_t := 0.0
var drift_cd := 0.0
var warned := false
var rng := RandomNumberGenerator.new()

func setup(game) -> void:
    main = game
    if main.audit_seed >= 0:
        rng.seed = main.audit_seed + 101
    else:
        rng.randomize()
    _build_lanes()

# Every driving lane of every road, across the whole world.
func _build_lanes() -> void:
    var wr: Rect2 = main.world_rect
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for road in LevelData.roads():
            if not road.horizontal:
                continue
            var y: float = float(ty) * LevelData.TILE.y + road.centre
            if y <= wr.position.y + 100.0 or y >= wr.end.y - 100.0:
                continue
            _add_road_lanes(true, y, road.avenue, wr.position.x + 80.0, wr.end.x - 80.0)
            _note_road(road_ys, y, road.avenue)
    for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
        for road in LevelData.roads():
            if road.horizontal:
                continue
            var x: float = float(tx) * LevelData.TILE.x + road.centre
            if x <= wr.position.x + 100.0 or x >= wr.end.x - 100.0:
                continue
            _add_road_lanes(false, x, road.avenue, wr.position.y + 80.0, wr.end.y - 80.0)
            _note_road(road_xs, x, road.avenue)
    # the roads at each tile boundary appear in two tiles; keep one lane each
    var seen := {}
    var unique: Array = []
    for l in lanes:
        var key := "%s:%d:%d" % [l.horizontal, int(roundf(l.fixed)), l.dir]
        if not seen.has(key):
            seen[key] = true
            unique.append(l)
    lanes = unique

# Remembers a road's centre line (once: the roads at a tile boundary come up in two tiles).
func _note_road(list: Array, centre: float, avenue: bool) -> void:
    for r in list:
        if absf(r.centre - centre) < 1.0:
            return
    list.append({"centre": centre, "avenue": avenue})
    list.sort_custom(func(p, q): return p.centre < q.centre)

func _add_road_lanes(horizontal: bool, centre: float, avenue: bool, a: float, b: float) -> void:
    for lane in LevelData.lanes_of(horizontal, avenue):
        var inner: bool = absf(lane[0]) < 20.0
        var speed: float = (150.0 if inner else 125.0) if avenue else 108.0
        lanes.append({"horizontal": horizontal, "fixed": centre + lane[0], "dir": lane[1], "a": a, "b": b, "speed": speed, "outer": (not inner) or (not avenue)})

func _process(delta: float) -> void:
    if not enabled or main == null or main.state != "play" or main.player == null:
        return
    timer += delta
    if timer < 0.3:
        return
    timer = 0.0
    var pp: Vector2 = main.player.global_position
    _linger(pp)
    # Remove cars that have fallen far behind (never anywhere near the view).
    for car in main.traffic.duplicate():
        if car.global_position.distance_to(pp) > DESPAWN_RADIUS or car.modulate.a <= 0.01:
            main.traffic.erase(car)
            car.queue_free()
    for sk in main.skaters.duplicate():
        if sk.global_position.distance_to(pp) > DESPAWN_RADIUS or sk.modulate.a <= 0.01:
            main.skaters.erase(sk)
            sk.queue_free()
    var ramp: float = clampf((pp.distance_to(main.START) - RAMP_START) / (RAMP_FULL - RAMP_START), 0.0, 1.0)
    var near_skaters := 0
    for sk in main.skaters:
        if sk.global_position.distance_to(pp) < ACTIVE_RADIUS:
            near_skaters += 1
    if near_skaters < ceili(int(main.settings.skaters) * ramp) and not lanes.is_empty():
        _try_spawn(pp, true)
    _maintain_police(pp, ramp)
    var near := 0
    for car in main.traffic:
        if not car.is_police and car.global_position.distance_to(pp) < ACTIVE_RADIUS:
            near += 1
    if near >= ceili(int(main.settings.cars) * ramp) or lanes.is_empty():
        return
    _try_spawn(pp, false)

# Keeps the level's police cars (settings.police) cruising near her, appearing out of the view like the rest.
func _maintain_police(pp: Vector2, ramp: float) -> void:
    var want: int = ceili(int(main.settings.police) * ramp)
    if want <= 0 or lanes.is_empty():
        return
    var near := 0
    for car in main.traffic:
        if car.is_police and car.global_position.distance_to(pp) < DESPAWN_RADIUS:
            near += 1
    if near >= want:
        return
    for attempt in 10:
        var lane: Dictionary = lanes[rng.randi() % lanes.size()]
        var across: float = pp.y if lane.horizontal else pp.x
        if absf(lane.fixed - across) > LANE_REACH:
            continue
        var along_pp: float = pp.x if lane.horizontal else pp.y
        var along: float = along_pp - float(lane.dir) * rng.randf_range(SPAWN_MIN, SPAWN_MAX)
        if along < lane.a or along > lane.b:
            continue
        if spawn_police(lane, along) != null:
            return

# A police car on a lane at a position along it, if the lane has room there and it is clear of the start.
func spawn_police(lane: Dictionary, along: float, ignore_start_rule: bool = false) -> Node:
    var spot: Vector2 = Vector2(along, lane.fixed) if lane.horizontal else Vector2(lane.fixed, along)
    if not ignore_start_rule and spot.distance_to(main.START) < 200.0:
        return null
    for other in main.traffic:
        if other.horizontal == lane.horizontal and absf((other.position.y if lane.horizontal else other.position.x) - lane.fixed) < 6.0 \
                and absf((other.position.x if lane.horizontal else other.position.y) - along) < GAP:
            return null
    var car = PoliceScript.new()
    car.setup_police(main, self, lane, along)
    main.actors.add_child(car)
    main.traffic.append(car)
    return car

# Standing about draws zombies. They set out from outside the view, one at a time.
func _linger(pp: Vector2) -> void:
    if not main.settings.linger:
        return
    if pp.distance_to(anchor) > LINGER_RADIUS:
        anchor = pp
        linger_t = 0.0
    else:
        linger_t += 0.3
    drift_cd = maxf(0.0, drift_cd - 0.3)
    var drifters: Array = []
    for n in main.npcs.duplicate():
        if n.drifter:
            if n.global_position.distance_to(pp) > DESPAWN_RADIUS + 200.0:
                main.npcs.erase(n)
                n.queue_free()
            else:
                drifters.append(n)
    if linger_t < LINGER_AFTER or drift_cd > 0.0 or drifters.size() >= LINGER_MAX \
            or main.play_time < LINGER_GRACE or pp.distance_to(main.START) < 900.0:
        return
    for attempt in 12:
        var spot: Vector2 = pp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(DRIFT_MIN, DRIFT_MAX)
        if not main.world_rect.grow(-120.0).has_point(spot) or main.blocked_circle(spot, 7.0):
            continue
        var z = NpcScript.new()
        z.setup(main, NpcScript.Kind.ZOMBIE, spot)
        z.drifter = true
        main.actors.add_child(z)
        z.global_position = spot
        z.state = NpcScript.State.HUNT
        main.npcs.append(z)
        drift_cd = LINGER_EVERY
        if not warned:
            warned = true
            main._show_toast("Something is coming. Keep moving.")
        return

# Picks a lane near Nicole and puts a car (or a skateboarder) on it, upstream and well
# out of sight.
func _try_spawn(pp: Vector2, skater: bool) -> void:
    for attempt in 10:
        var lane: Dictionary = lanes[rng.randi() % lanes.size()]
        var across: float = pp.y if lane.horizontal else pp.x
        if absf(lane.fixed - across) > LANE_REACH:
            continue
        var along_pp: float = pp.x if lane.horizontal else pp.y
        # Upstream of Nicole, so the car comes towards her part of the road.
        var along: float = along_pp - float(lane.dir) * rng.randf_range(SPAWN_MIN, SPAWN_MAX)
        if along < lane.a or along > lane.b:
            continue
        if skater:
            if lane.outer and spawn_skater(lane, along) != null:
                return
        elif spawn_car(lane, along) != null:
            return

# Puts a car on a lane at a position along it, if the lane has room there and the
# spot is clear of the start. Returns the car or null.
func spawn_car(lane: Dictionary, along: float, ignore_start_rule: bool = false) -> Node:
    var spot: Vector2 = Vector2(along, lane.fixed) if lane.horizontal else Vector2(lane.fixed, along)
    if not ignore_start_rule and spot.distance_to(main.START) < 200.0:
        return null
    for other in main.traffic:
        if other.horizontal == lane.horizontal and absf((other.position.y if lane.horizontal else other.position.x) - lane.fixed) < 6.0 \
                and absf((other.position.x if lane.horizontal else other.position.y) - along) < GAP:
            return null
    var car = TrafficScript.new()
    var t: float = (along - lane.a) / (lane.b - lane.a)
    car.setup_traffic(main, lane.horizontal, lane.fixed, lane.a, lane.b, lane.dir, lane.speed, rng.randi() % CarScript.BODY_COLORS.size(), t, main.traffic.size())
    main.actors.add_child(car)
    main.traffic.append(car)
    return car

# A skateboarder on a lane, if it is clear of cars and other skaters there.
func spawn_skater(lane: Dictionary, along: float, ignore_start_rule: bool = false) -> Node:
    var spot: Vector2 = Vector2(along, lane.fixed) if lane.horizontal else Vector2(lane.fixed, along)
    if not ignore_start_rule and spot.distance_to(main.START) < 250.0:
        return null
    for list in [main.traffic, main.skaters]:
        for other in list:
            if other.global_position.distance_to(spot) < 140.0:
                return null
    var sk = SkaterScript.new()
    sk.setup_skater(main, lane.horizontal, lane.fixed, lane.a, lane.b, lane.dir, rng.randf_range(170.0, 210.0), along)
    main.actors.add_child(sk)
    main.skaters.append(sk)
    return sk
