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
const INVESTIGATE_ARRIVE := 16.0  # close enough: the noise may be at something solid
const INVESTIGATE_MAX := 8.0  # give up and look around after this long

class Beam extends Node2D:
    var cop

    func _draw() -> void:
        var poly: PackedVector2Array = cop.beam_polygon()
        if poly.size() < 3:
            return
        draw_colored_polygon(poly, Color(1.0, 0.95, 0.6, 0.16))
        draw_polyline(poly, Color(1.0, 0.95, 0.6, 0.25), 1.0)

# The flashlight in his hand: a glow at the lens and a faint shaft of light down
# to where the beam meets the ground. Drawn upright, over the sprite.
class Flash extends Node2D:
    var cop

    func _draw() -> void:
        if cop.chasing:
            return  # the club is out; the light is stowed
        draw_set_transform_matrix(Sprites.UP)
        var side: float = -1.0 if cop.sprite.flip_h else 1.0
        var lens := Vector2(10.0 * side, -14.8)
        var a0: float = cop.angle - FOV * 0.5
        var a1: float = cop.angle + FOV * 0.5
        var near_a: Vector2 = Sprites.iso(Vector2.from_angle(a0) * 16.0)
        var near_b: Vector2 = Sprites.iso(Vector2.from_angle(a1) * 16.0)
        draw_colored_polygon(PackedVector2Array([lens, near_a, near_b]), Color(1.0, 0.95, 0.6, 0.10))
        draw_circle(lens, 4.5, Color(1.0, 0.95, 0.6, 0.18))
        draw_circle(lens, 2.2, Color(1.0, 0.97, 0.75, 0.55))

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
var last_frame := -1
var investigate_t := 0.0
var was_seeing := false
var sprite: Sprite2D
var frames: Array = []        # club raised: he is after you
var calm_frames: Array = []   # club down: patrolling or checking out a noise
var chasing := false
var beam: Beam
var flash: Flash

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
    calm_frames = Sprites.load_frames("cop", ["walk0", "walk1", "walk2", "walk3"])
    flash = Flash.new()
    flash.cop = self
    add_child(flash)
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
    chasing = false  # just checking out a noise

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
        anim_t += delta * 6.0
        var frame: int = int(anim_t) % frames.size()
        sprite.texture = (frames if chasing else calm_frames)[frame]
        # A boot lands on every other frame of the patrol walk.
        if frame != last_frame and frame % 2 == 0:
            main.footstep(-8.0, 0.8, global_position, 240.0)
        last_frame = frame
    else:
        sprite.texture = (frames if chasing else calm_frames)[0]
        last_frame = -1
    sprite.flip_h = Sprites.faces_left(Vector2.from_angle(angle))
    beam.queue_redraw()
    flash.queue_redraw()
    queue_redraw()

func _update_ai(delta: float) -> void:
    if state != State.INVESTIGATE:
        investigate_t = 0.0
        chasing = false  # a cop who has stopped going after something puts his club away
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
            # Noises come from bins, walls and barrels a cop can't stand on, and
            # sliding round one still counts as moving, so don't rely on "stuck"
            # alone: arrive when near, and give up after a while.
            investigate_t += delta
            var arrived: bool = global_position.distance_to(target) < INVESTIGATE_ARRIVE
            if _step_toward(target, INVESTIGATE_SPEED, delta) or stuck > 0.6 \
                    or arrived or investigate_t > INVESTIGATE_MAX:
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
            chasing = true  # he has spotted you: club up
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
