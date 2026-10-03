extends Node
# Keeps traffic flowing round Nicole. Cars spawn on the lanes of the nearby roads well
# outside the view, drive along them, and are removed once they are far behind, so a
# car is never seen appearing or vanishing. The lanes are the right-hand lanes of every
# road of the grid, running the whole width (or height) of the world.

const TrafficScript := preload("res://scripts/Traffic.gd")
const CarScript := preload("res://scripts/Car.gd")
const SkaterScript := preload("res://scripts/Skater.gd")
const LevelData := preload("res://scripts/LevelData.gd")

const TARGET := 16            # cars to keep within ACTIVE_RADIUS of Nicole
const SKATERS := 4            # skateboarders likewise
const ACTIVE_RADIUS := 1000.0
const DESPAWN_RADIUS := 1250.0
const SPAWN_MIN := 700.0      # spawn at least this far away: outside the view
const SPAWN_MAX := 1000.0
const LANE_REACH := 600.0     # lanes this close to Nicole's position can spawn cars
const GAP := 110.0            # keep this much room between cars on one lane

var main
var enabled := true  # tests switch it off
var lanes: Array = []  # {horizontal, fixed, dir, a, b, speed}
var timer := 0.0
var rng := RandomNumberGenerator.new()

func setup(game) -> void:
    main = game
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
    for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
        for road in LevelData.roads():
            if road.horizontal:
                continue
            var x: float = float(tx) * LevelData.TILE.x + road.centre
            if x <= wr.position.x + 100.0 or x >= wr.end.x - 100.0:
                continue
            _add_road_lanes(false, x, road.avenue, wr.position.y + 80.0, wr.end.y - 80.0)
    # the roads at each tile boundary appear in two tiles; keep one lane each
    var seen := {}
    var unique: Array = []
    for l in lanes:
        var key := "%s:%d:%d" % [l.horizontal, int(roundf(l.fixed)), l.dir]
        if not seen.has(key):
            seen[key] = true
            unique.append(l)
    lanes = unique

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
    # Remove cars that have fallen far behind (never anywhere near the view).
    for car in main.traffic.duplicate():
        if car.global_position.distance_to(pp) > DESPAWN_RADIUS or car.modulate.a <= 0.01:
            main.traffic.erase(car)
            car.queue_free()
    for sk in main.skaters.duplicate():
        if sk.global_position.distance_to(pp) > DESPAWN_RADIUS or sk.modulate.a <= 0.01:
            main.skaters.erase(sk)
            sk.queue_free()
    var near_skaters := 0
    for sk in main.skaters:
        if sk.global_position.distance_to(pp) < ACTIVE_RADIUS:
            near_skaters += 1
    if near_skaters < SKATERS and not lanes.is_empty():
        _try_spawn(pp, true)
    var near := 0
    for car in main.traffic:
        if car.global_position.distance_to(pp) < ACTIVE_RADIUS:
            near += 1
    if near >= TARGET or lanes.is_empty():
        return
    _try_spawn(pp, false)

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
