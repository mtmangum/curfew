extends Node2D
# Patrolling cop with a flashlight cone. Walls and active steam block the beam.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

enum State {PATROL, INVESTIGATE, LOOK, CHASE}

const RADIUS := 5.0
const RANGE := 120.0
const FOV := 0.9
const RAYS := 20
const SEE_TIME := 1.1
const PATROL_SPEED := 38.0
const INVESTIGATE_SPEED := 70.0
# Chasing: a cop who has seen you runs at you. Nicole walks at 85, so she can just
# outpace him (sneaking at 42 cannot), and he catches her only by reaching her.
const CHASE_SPEED := 80.0
const CATCH_DIST := 13.0  # close enough to grab her
const SPOT_AT := 0.2  # how full the suspicion bar must be before he gives chase
const GLIMPSE := 0.06  # even a glimpse this strong sends him to where he saw her
const LOSE_AFTER := 4.0  # seconds without sight of her before he stops running
const EVADE_GIVE_UP := 8.0  # he gives up after this long without getting close, even while he can still see her
const EVADE_CLOSE := 30.0  # near enough that the clock starts over
const EVADE_COOLDOWN := 5.0  # winded: he ignores her at a distance for this long afterwards
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
var lost_t := 0.0  # how long since he last saw her, while chasing
var chase_t := 0.0  # how long he has been chasing without getting close
var winded_t := 0.0  # > 0 after giving up a chase: he won't start another at a distance
var seen_at := Vector2.ZERO  # where he last saw Nicole or Stella
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
    if seeing or state == State.CHASE:
        return  # busy chasing; a noise won't turn his head
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
    # The game ends only when he actually reaches her.
    if state == State.CHASE and global_position.distance_to(main.player.global_position) < CATCH_DIST:
        main.caught(self)
    if moving:
        anim_t += delta * (9.0 if chasing else 6.0)
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
    # The moment he sees something he stops and turns to look at it, rather than
    # walking on with his back to her while his suspicion builds.
    if seeing and state != State.CHASE:
        var to_seen: Vector2 = seen_at - global_position
        if to_seen.length() > 4.0:
            angle = lerp_angle(angle, to_seen.angle(), clampf(8.0 * delta, 0.0, 1.0))
        return
    if state != State.INVESTIGATE:
        investigate_t = 0.0
    # Club out only while he is running after her.
    chasing = state == State.CHASE
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
        State.CHASE:
            if seeing:
                lost_t = 0.0
                target = main.player.global_position
            else:
                lost_t += delta
            var reached: bool = global_position.distance_to(target) < INVESTIGATE_ARRIVE
            _step_toward(target, CHASE_SPEED, delta)
            # She is outrunning him: after a while he gives up, even in sight of her.
            if global_position.distance_to(main.player.global_position) < EVADE_CLOSE:
                chase_t = 0.0
            else:
                chase_t += delta
            if chase_t > EVADE_GIVE_UP:
                state = State.LOOK
                look_t = 3.5
                stuck = 0.0
                exposure = 0.0
                winded_t = EVADE_COOLDOWN
                chasing = false
                return
            # Lost her: he got to where he last saw her, got stuck, or too long has passed.
            if not seeing and (reached or stuck > 0.6 or lost_t > LOSE_AFTER):
                state = State.LOOK
                look_t = 3.0
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
    if winded_t > 0.0:
        winded_t -= delta
        if global_position.distance_to(main.player.global_position) > 60.0:
            seeing = false
            was_seeing = false
            exposure = maxf(0.0, exposure - 0.35 * delta)
            return
    var rate_nicole: float = _rate_for(main.player, 1.0)
    var rate_stella: float = _rate_for(main.dog, 0.6)
    var rate := maxf(rate_nicole, rate_stella)
    seeing = rate > 0.0
    if seeing:
        seen_at = main.player.global_position if rate_nicole >= rate_stella else main.dog.global_position
    if seeing and not was_seeing:
        main.play_at("spotted", global_position, -2.0, 520.0)
    # He saw something and lost it: go and look where it was.
    if was_seeing and not seeing and exposure > GLIMPSE and state != State.CHASE:
        state = State.INVESTIGATE
        target = seen_at
        stuck = 0.0
    was_seeing = seeing
    if seeing:
        exposure += rate * delta
        exposure = minf(exposure, 1.0)
        if exposure > SPOT_AT and state != State.CHASE:
            # He has seen enough: after her.
            state = State.CHASE
            lost_t = 0.0
            chase_t = 0.0
            stuck = 0.0
            target = main.player.global_position
    else:
        exposure = maxf(0.0, exposure - 0.35 * delta)
    if state == State.CHASE:
        exposure = maxf(exposure, 0.7)  # keep the red alert up for the whole chase

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
