extends Node2D
# Patrolling cop with a flashlight cone. Walls and active steam block the beam.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

enum State {PATROL, INVESTIGATE, LOOK}

const RADIUS := 5.0
const RANGE := 120.0
const FOV := 0.9
const RAYS := 20
const SEE_TIME := 1.1
const PATROL_SPEED := 38.0
const INVESTIGATE_SPEED := 70.0

class Beam extends Node2D:
    var cop

    func _draw() -> void:
        var poly: PackedVector2Array = cop.beam_polygon()
        if poly.size() < 3:
            return
        draw_colored_polygon(poly, Color(1.0, 0.95, 0.6, 0.16))
        draw_polyline(poly, Color(1.0, 0.95, 0.6, 0.25), 1.0)

var main
var waypoints: Array = []
var wp_i := 0
var angle := 0.0
var state: State = State.PATROL
var target := Vector2.ZERO
var wait := 0.0
var look_t := 0.0
var stuck := 0.0
var exposure := 0.0
var seeing := false
var moving := false
var anim_t := 0.0
var step_t := 0.0
var was_seeing := false
var sprite: Sprite2D
var frames: Array = []
var beam: Beam

func setup(game, pts: Array) -> void:
    main = game
    for p in pts:
        waypoints.append(p)
    global_position = waypoints[0]
    if waypoints.size() > 1:
        angle = (waypoints[1] - waypoints[0]).angle()

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/cop/patrol0.png", 0.36)
    Sprites.upright(self, 6.0).add_child(sprite)
    frames = Sprites.load_frames("cop", ["patrol0", "patrol1", "patrol2", "patrol3"])
    beam = Beam.new()
    beam.cop = self
    beam.z_as_relative = false
    beam.z_index = -50
    add_child(beam)

func hear(pos: Vector2) -> void:
    if seeing:
        return
    if state != State.INVESTIGATE:
        main.play_at("alert", global_position, -3.0, 420.0)
    state = State.INVESTIGATE
    target = pos
    stuck = 0.0

func beam_polygon() -> PackedVector2Array:
    var pts := PackedVector2Array()
    pts.append(Vector2.ZERO)
    var o: Vector2 = global_position
    for i in range(RAYS + 1):
        var a: float = angle - FOV * 0.5 + FOV * float(i) / float(RAYS)
        var dir := Vector2.from_angle(a)
        var reach: float = main.ray_hit(o, dir, RANGE)
        pts.append(dir * maxf(reach, 2.0))
    return pts

func _process(delta: float) -> void:
    if main.state != "play":
        return
    # Cops far from the action stand still (and cost nothing).
    if global_position.distance_squared_to(main.player.global_position) > main.NEAR_VIEW * main.NEAR_VIEW:
        return
    moving = false
    _update_ai(delta)
    _update_detection(delta)
    if moving:
        step_t -= delta
        if step_t <= 0.0:
            step_t = 0.36 if state == State.INVESTIGATE else 0.56
            main.play_at("step%d" % randi_range(0, 2), global_position, -9.0, 240.0)
    if moving:
        anim_t += delta * 6.0
        sprite.texture = frames[int(anim_t) % frames.size()]
    else:
        sprite.texture = frames[0]
    sprite.flip_h = Sprites.faces_left(Vector2.from_angle(angle))
    beam.queue_redraw()
    queue_redraw()

func _update_ai(delta: float) -> void:
    match state:
        State.PATROL:
            if waypoints.is_empty():
                return
            if wait > 0.0:
                wait -= delta
                _look_around(delta)
                return
            if _step_toward(waypoints[wp_i], PATROL_SPEED, delta):
                wp_i = (wp_i + 1) % waypoints.size()
                wait = 1.2
            elif stuck > 1.0:
                # Boxed in: give up on this waypoint rather than freezing here.
                wp_i = (wp_i + 1) % waypoints.size()
                stuck = 0.0
        State.INVESTIGATE:
            if _step_toward(target, INVESTIGATE_SPEED, delta) or stuck > 0.6:
                state = State.LOOK
                look_t = 2.5
                stuck = 0.0
        State.LOOK:
            look_t -= delta
            _look_around(delta)
            if look_t <= 0.0:
                state = State.PATROL

func _look_around(delta: float) -> void:
    angle += sin(Time.get_ticks_msec() / 600.0) * 0.7 * delta

# Returns true once we've arrived at the goal.
func _step_toward(goal: Vector2, speed: float, delta: float) -> bool:
    var d: Vector2 = goal - global_position
    var dist: float = d.length()
    if dist < 3.0:
        return true
    var dir: Vector2 = d / dist
    angle = lerp_angle(angle, dir.angle(), clampf(6.0 * delta, 0.0, 1.0))
    var before: Vector2 = global_position
    global_position = main.slide(global_position, dir * minf(speed * delta, dist), RADIUS)
    if global_position.distance_to(before) > 0.01:
        stuck = 0.0
        moving = true
    else:
        stuck += delta
    return false

func _update_detection(delta: float) -> void:
    var rate := maxf(_rate_for(main.player, 1.0), _rate_for(main.dog, 0.6))
    seeing = rate > 0.0
    if seeing and not was_seeing:
        main.play_at("spotted", global_position, -2.0, 520.0)
    was_seeing = seeing
    if seeing:
        exposure += rate * delta
        if exposure > 0.25:
            state = State.INVESTIGATE
            target = main.player.global_position
            stuck = 0.0
        if exposure >= 1.0:
            main.caught(self)
    else:
        exposure = maxf(0.0, exposure - 0.35 * delta)

func _rate_for(actor, weight: float) -> float:
    var p: Vector2 = actor.global_position
    var d: Vector2 = p - global_position
    var dist: float = d.length()
    if dist > RANGE:
        return 0.0
    if dist > 4.0 and absf(angle_difference(angle, d.angle())) > FOV * 0.5:
        return 0.0
    if not main.los(global_position, p):
        return 0.0
    var closeness: float = 1.0 + (1.0 - dist / RANGE)
    return closeness / SEE_TIME * weight * actor.visibility_mult()

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    if exposure > 0.02:
        draw_rect(Rect2(-10, -46, 20, 3), Color(0, 0, 0, 0.7))
        draw_rect(Rect2(-10, -46, 20.0 * minf(exposure, 1.0), 3), Color(1.0, 1.0 - exposure, 0.1))
    if state == State.INVESTIGATE:
        Style.draw_world_text(self, Vector2(-3, -50), "?", 16, Color(1, 0.9, 0.2))
