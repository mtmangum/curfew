extends "res://scripts/Traffic.gd"
# A police car, from level 3. It cruises the road grid, turning at junctions; if it sees Nicole (headlights
# ahead, or anyone close, with a clear line) it builds suspicion like a cop does, and then gives chase: faster
# than the traffic, picking at each junction the turn that gets it nearest to her. A car cannot leave the road,
# so when it reaches her kerb it stops and a cop gets out and chases on foot (Cop.drop), and the car waits a
# few seconds before it cruises again. Pavements, alleys and doorways are where a car cannot follow.
# (TrafficDirector keeps `settings.police` of them near her. Subclass of Traffic: it still hits what is in
# its way.)

const CopScript := preload("res://scripts/Cop.gd")
const LevelData := preload("res://scripts/LevelData.gd")

enum Mode {PATROL, CHASE, STOPPED}

const PATROL_SPEED := 88.0
const CHASE_SPEED := 150.0
const SEE_RANGE := 420.0   # how far ahead it sees her
const SEE_NEAR := 140.0    # anyone this close it sees whichever way it faces
const SEE_CONE := 0.95     # half the angle of its sight, in radians (about 55 degrees)
const SEE_TIME := 1.5      # seconds in plain view to be sure it has seen her (less when she is lit or close)
const LOSE_AFTER := 6.0    # seconds without sight of her before it gives up the chase
const DROP_DIST := 80.0    # near enough to her for the cop to get out
const STOP_TIME := 6.0     # it waits this long after dropping the cop
const MAX_DROPPED := 2     # cops on foot from police cars at once
const DECIDE_AHEAD := 60.0 # it picks its turn this far before a junction
const LOOK := 240.0        # how far down a road it looks to judge a turn

var mode: Mode = Mode.PATROL
var exposure := 0.0
var lost_t := 0.0
var stop_t := 0.0
var siren_t := 0.0
var flash_t := 0.0
var mark := ""
var mark_age := 0.0
var last_seen := Vector2.ZERO
var director
var road_c := 0.0          # the centre line of the road it is on
var avenue := false
var decided_c := INF       # the junction it has chosen for already
var turn_at := INF         # where along the road it turns, once it has chosen to
var turn_dir := 0          # ...and the way it goes
var turn_road: Dictionary = {}  # the crossing road it turns into

func setup_police(game, boss, lane: Dictionary, along: float) -> void:
    director = boss
    is_police = true
    var t: float = (along - lane.a) / (lane.b - lane.a)
    setup_traffic(game, lane.horizontal, lane.fixed, lane.a, lane.b, lane.dir, PATROL_SPEED, 5, t, 0)
    paint = Color("20263a")
    var roads: Array = boss.road_ys if lane.horizontal else boss.road_xs
    var best := 1.0e9
    for r in roads:
        if absf(r.centre - lane.fixed) < best:
            best = absf(r.centre - lane.fixed)
            road_c = r.centre
            avenue = r.avenue

# Which way a car on a road of the other kind goes, for the lane it should take: x or y of that lane.
func _lane_offset(horizontal_road: bool, is_avenue: bool, dir: int) -> float:
    for l in LevelData.lanes_of(horizontal_road, is_avenue):
        if l[1] == dir:
            return float(l[0])
    return 0.0

# Whether it can see her now: in the cone of its headlights or close, within range, and a clear line.
func sees(pp: Vector2) -> bool:
    var v: Vector2 = pp - position
    var d: float = v.length()
    if d > SEE_RANGE or main.player.in_cover:
        return false
    if d > SEE_NEAR and absf(angle_difference(heading.angle(), v.angle())) > SEE_CONE:
        return false
    return main.los(position, pp)

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    var pp: Vector2 = main.player.global_position
    if global_position.distance_squared_to(pp) > FAR * FAR:
        return
    flash_t += delta
    mark_age += delta
    var seen: bool = mode != Mode.STOPPED and sees(pp)
    match mode:
        Mode.PATROL:
            if seen:
                var close: float = 1.0 + (1.0 - clampf(position.distance_to(pp) / SEE_RANGE, 0.0, 1.0))
                exposure += close * main.player.visibility_mult() / SEE_TIME * delta
            else:
                exposure = maxf(0.0, exposure - 0.4 * delta)
            _set_mark("?" if exposure > 0.3 else "")
            if exposure >= 1.0:
                _start_chase(pp)
        Mode.CHASE:
            if seen:
                last_seen = pp
                lost_t = 0.0
            else:
                lost_t += delta
                if lost_t > LOSE_AFTER:
                    mode = Mode.PATROL
                    speed = PATROL_SPEED
                    exposure = 0.0
                    _set_mark("?")  # looking about
            siren_t -= delta
            if siren_t <= 0.0:
                siren_t = 2.2
                main.play_at("police_siren", position, -3.0, 900.0)
            if position.distance_to(pp) < DROP_DIST and _dropped_now() < MAX_DROPPED:
                _stop_and_drop(pp)
        Mode.STOPPED:
            stop_t -= delta
            if stop_t <= 0.0:
                mode = Mode.PATROL
                speed = PATROL_SPEED
                exposure = 0.0
    if mode != Mode.STOPPED:
        _drive(delta, pp)
    modulate.a = 1.0
    rect = Rect2(position + local_rect.position, local_rect.size)
    update_screen_box()
    if speed > 10.0:
        _check_hit()
    queue_redraw()

func _set_mark(m: String) -> void:
    if m != mark:
        mark = m
        mark_age = 0.0

func _start_chase(pp: Vector2) -> void:
    mode = Mode.CHASE
    speed = CHASE_SPEED
    last_seen = pp
    lost_t = 0.0
    siren_t = 0.0
    _set_mark("!")

# Cops on foot who got out of a police car and are still about.
func _dropped_now() -> int:
    var n := 0
    for c in main.cops.duplicate():
        if is_instance_valid(c) and c.drop:
            if c.global_position.distance_to(main.player.global_position) > 1100.0:
                c._leave()  # left far behind: he is not a patrol, so he goes
            else:
                n += 1
    return n

func _stop_and_drop(pp: Vector2) -> void:
    mode = Mode.STOPPED
    speed = 0.0
    stop_t = STOP_TIME
    _set_mark("")
    # he gets out on the side nearer her
    var side: Vector2 = heading.orthogonal()
    if side.dot(pp - position) < 0.0:
        side = -side
    var spot: Vector2 = position + side * (WIDTH * 0.5 + 8.0)
    var cop := CopScript.new()
    main.actors.add_child(cop)
    cop.setup(main, [spot, spot + Vector2(40.0, 0.0)])
    cop.global_position = spot
    cop.drop = true
    main.cops.append(cop)
    cop.start_chase(pp)
    main.play_at("alert", position, 0.0, 600.0)

# Moves along the road, and at each junction picks straight on or a turn: while cruising mostly straight on,
# while chasing whichever gets it nearest to her.
func _drive(delta: float, pp: Vector2) -> void:
    var dir_i: int = int(signf(heading.x + heading.y))
    var along: float = position.x if horizontal else position.y
    var centres: Array = director.road_xs if horizontal else director.road_ys
    # choose, a little before the next junction
    if turn_at == INF:
        for r in centres:
            var ahead: float = (r.centre - along) * float(dir_i)
            if ahead > 0.0 and ahead <= DECIDE_AHEAD and r.centre != decided_c:
                decided_c = r.centre
                _choose(r, dir_i, pp)
                break
    var step: float = speed * delta
    var new_along: float = along + float(dir_i) * step
    if turn_at != INF and (turn_at - along) * float(dir_i) <= step:
        _turn(dir_i)
        return
    if horizontal:
        position.x = new_along
    else:
        position.y = new_along
    # off the end of the world: gone (the director puts another near her)
    if new_along < lane_a - 40.0 or new_along > lane_b + 40.0:
        main.traffic.erase(self)
        queue_free()

# Picks what to do at the crossing road `r` ({centre, avenue}): the options are straight on and each way along it.
func _choose(r: Dictionary, dir_i: int, pp: Vector2) -> void:
    var here: float = position.y if horizontal else position.x   # our lane's coordinate across
    var options: Array = []
    # straight on
    var junction: Vector2 = Vector2(r.centre, here) if horizontal else Vector2(here, r.centre)
    options.append({"dir": 0, "score": (junction + heading * LOOK).distance_to(pp)})
    for nd in [-1, 1]:
        var h: Vector2 = Vector2(0.0, float(nd)) if horizontal else Vector2(float(nd), 0.0)
        options.append({"dir": nd, "score": (junction + h * LOOK).distance_to(pp)})
    var pick: Dictionary = options[0]
    if mode == Mode.CHASE or position.distance_to(pp) > 900.0:
        for o in options:
            if o.score < pick.score:
                pick = o
    else:
        var roll: float = randf()
        pick = options[0] if roll < 0.55 else (options[1] if roll < 0.775 else options[2])
    if pick.dir == 0:
        return
    turn_dir = int(pick.dir)
    turn_road = r
    turn_at = r.centre + _lane_offset(not horizontal, r.avenue, turn_dir)

# Swings into the crossing road at the lane the turn was aimed at.
func _turn(dir_i: int) -> void:
    var wr: Rect2 = main.world_rect
    var new_horizontal: bool = not horizontal
    var at: float = turn_at
    if horizontal:
        position.x = at
    else:
        position.y = at
    horizontal = new_horizontal
    heading = Vector2(float(turn_dir), 0.0) if horizontal else Vector2(0.0, float(turn_dir))
    front = turn_dir
    lane_a = (wr.position.x if horizontal else wr.position.y) + 80.0
    lane_b = (wr.end.x if horizontal else wr.end.y) - 80.0
    var size := Vector2(LENGTH, WIDTH) if horizontal else Vector2(WIDTH, LENGTH)
    local_rect = Rect2(-size * 0.5, size)
    road_c = turn_road.centre
    avenue = turn_road.avenue
    decided_c = INF
    # (decided_c is the junction we just turned at: never choose it again straight away)
    decided_c = road_c
    turn_at = INF
    turn_dir = 0

# No honking: police cars do not.
func _warn(_pp: Vector2) -> void:
    pass

# The car, with a white stripe down its side, and a bar of red and blue lights on its roof.
func _draw() -> void:
    super._draw()
    draw_set_transform_matrix(Sprites.UP)
    var r: Rect2 = local_rect
    Sprites.fill(self, _quad(Vector2(r.position.x, r.end.y), Vector2.RIGHT, 3.0, r.size.x - 3.0, 8.0, 10.0), Color("e8ecf2"))
    Sprites.fill(self, _quad(Vector2(r.end.x, r.end.y), Vector2.UP, 3.0, r.size.y - 3.0, 8.0, 10.0), Color("c3c9d6"))
    var rate: float = 6.0 if mode == Mode.CHASE else 3.0
    var red_first: bool = int(flash_t * rate) % 2 == 0
    var red := Color("ff3b3b")
    var blue := Color("3b6bff")
    var dim := Color("40242a")
    var c: Vector2 = r.get_center()
    var half: float = (WIDTH if horizontal else WIDTH) * 0.3
    # the bar runs across the car: two lamps, one each side of its middle
    var a: Vector2 = c + (Vector2(0.0, -half) if horizontal else Vector2(-half, 0.0))
    var b: Vector2 = c + (Vector2(0.0, half) if horizontal else Vector2(half, 0.0))
    Sprites.roof_box(self, a.x - 2.0, a.y - 2.0, 4.0, 4.0, 3.0, height, red if red_first else dim, red.darkened(0.3) if red_first else dim, red.lightened(0.2) if red_first else dim)
    Sprites.roof_box(self, b.x - 2.0, b.y - 2.0, 4.0, 4.0, 3.0, height, dim if red_first else blue, dim if red_first else blue.darkened(0.3), dim if red_first else blue.lightened(0.2))
    if mark != "":
        CopScript.draw_alert_mark(self, mark, mark_age)
