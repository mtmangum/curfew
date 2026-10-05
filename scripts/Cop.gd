extends Node2D
# Patrolling cop with a flashlight cone. Walls and active steam block the beam.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")
const BeamCastScript := preload("res://scripts/BeamCast.gd")
const ItemsScript := preload("res://scripts/Items.gd")

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
const ALERT_TIME := 8.0  # after Stella's bark points him at us: quicker to get there, searches longer, and suspicious
const ALERT_SPEED := 1.25
const ALERT_SUSPICION := 1.5
const INVESTIGATE_ARRIVE := 16.0  # close enough: the noise may be at something solid
const INVESTIGATE_MAX := 8.0  # give up and look around after this long
const MARK_INVESTIGATE := Color(1.0, 0.9, 0.2)  # the "?": he heard or glimpsed something and is coming to look
const MARK_CHASE := Color(1.0, 0.16, 0.12)  # the "!": he is after her
const MARK_POP := 0.25  # a new mark pops in (starts big and settles) over this long
const CLUE_DIST := 520.0  # a cop this near is one she can see: his first "?" and "!" are explained (Clues.gd)

class Beam extends Node2D:
    var cop

    # The lit pool is the ground the rays reach: a fan from the torch's spot on the ground (`cop.beam_origin`),
    # which cannot fold over itself however a wall cuts it short. The lens is joined to it by the beam's two
    # edges and a faint wedge of light in the air above.
    func _draw() -> void:
        var ground: PackedVector2Array = cop.beam_ground
        if ground.size() < 2:
            return
        draw_set_transform_matrix(Sprites.UP)
        var origin: Vector2 = Sprites.iso(cop.beam_origin)
        var pts := PackedVector2Array()
        for g in ground:
            pts.append(Sprites.iso(g))
        for i in range(pts.size() - 1):
            if absf((pts[i] - origin).cross(pts[i + 1] - origin)) < 0.2:
                continue
            Sprites.fill(self, PackedVector2Array([origin, pts[i], pts[i + 1]]), Color(1.0, 0.95, 0.6, 0.16))
        var lens: Vector2 = cop.lens_screen()
        var last: Vector2 = pts[pts.size() - 1]
        if absf((pts[0] - lens).cross(last - lens)) >= 0.2:
            Sprites.fill(self, PackedVector2Array([lens, pts[0], last]), Color(1.0, 0.95, 0.6, 0.05))
        draw_line(lens, pts[0], Color(1.0, 0.95, 0.6, 0.25), 1.0)
        draw_line(lens, last, Color(1.0, 0.95, 0.6, 0.25), 1.0)
        Sprites.polyline(self, pts, Color(1.0, 0.95, 0.6, 0.25), 1.0)

# The flashlight in his hand: a glow at the lens. (The beam itself, drawn by Beam, starts
# here and fans out to where it reaches.) Drawn upright, over the sprite.
class Flash extends Node2D:
    var cop

    func _draw() -> void:
        if cop.chasing:
            return  # the club is out; the light is stowed
        draw_set_transform_matrix(Sprites.UP)
        var side: float = -1.0 if cop.sprite.flip_h else 1.0
        var lens := Vector2(10.0 * side, -14.8)
        Sprites.disc(self, lens, 4.5, Color(1.0, 0.95, 0.6, 0.18))
        Sprites.disc(self, lens, 2.2, Color(1.0, 0.97, 0.75, 0.55))

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
var alert_t := 0.0  # > 0 after a bark has told him where we are
var winded_t := 0.0  # > 0 after giving up a chase: he won't start another at a distance
var seen_at := Vector2.ZERO  # where he last saw Nicole or Stella
var was_seeing := false
var sprite: Sprite2D
var frames: Array = []        # club raised: he is after you
var calm_frames: Array = []   # club down: patrolling or checking out a noise
var chasing := false
var mark := ""  # the alert mark showing over his head (see alert_mark)
var mark_age := 0.0  # how long that mark has been up
var beam: Beam
var drop := false      # got out of a police car (PoliceCar.gd): he is gone a few seconds after he gives up
var drop_t := 0.0
var eat_t := 0.0       # > 0: stopped to eat a box of donuts (DonutBox.gd)
var beam_origin := Vector2.ZERO  # where on the ground the rays start, relative to his feet (his hand, or his feet against a wall)
var beam_ground := PackedVector2Array()  # where the beam's rays end, relative to his feet (see _update_beam)
var lit_by_beam: Array = []  # the Buildings his beam is landing on
var flash: Flash

func setup(game, pts: Array) -> void:
    main = game
    for p in pts:
        waypoints.append(p)
    global_position = waypoints[0]
    if waypoints.size() > 1:
        angle = (waypoints[1] - waypoints[0]).angle()

# Sent to the part of his own patrol that is farthest from `p`, calm and unalerted: used when she
# comes back where she fell and his post was close by.
func send_away_from(p: Vector2) -> void:
    var best := 0
    var best_d := -1.0
    for i in waypoints.size():
        var d: float = (waypoints[i] as Vector2).distance_to(p)
        if d > best_d:
            best_d = d
            best = i
    global_position = waypoints[best]
    wp_i = (best + 1) % waypoints.size()
    state = State.PATROL
    chasing = false
    exposure = 0.0
    alert_t = 0.0
    wait = 0.0
    if waypoints.size() > 1:
        angle = (waypoints[wp_i] - waypoints[best]).angle()

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

# Returns whether he turned to look (a cop who is busy chasing, or has her in his beam, does not).
# Straight into the chase (a cop who has just got out of a police car).
func start_chase(at: Vector2) -> void:
    state = State.CHASE
    lost_t = 0.0
    chase_t = 0.0
    stuck = 0.0
    target = at
    exposure = 0.7
    chasing = true

# A cop from a police car goes back to it once he has given up: he is not a patrol, so he leaves the map.
func _leave() -> void:
    main.cops.erase(self)
    if not lit_by_beam.is_empty():
        BeamCastScript.clear(get_instance_id(), lit_by_beam)
    queue_free()

# A box of donuts is down nearby (DonutBox.gd): go and look, if he is not busy with her.
func lure(pos: Vector2) -> void:
    if state == State.INVESTIGATE and target.distance_to(pos) < 12.0:
        return
    state = State.INVESTIGATE
    target = pos
    stuck = 0.0
    investigate_t = 0.0
    chasing = false

# He has reached the donuts: he stands and eats for a while, not looking about much.
func eat(seconds: float) -> void:
    eat_t = seconds
    state = State.LOOK
    look_t = seconds
    stuck = 0.0
    chasing = false

func hear(pos: Vector2, alerted: bool = false) -> bool:
    if alerted:
        alert_t = ALERT_TIME
    if seeing or state == State.CHASE:
        return false  # busy chasing; a noise won't turn his head
    if state != State.INVESTIGATE:
        main.play_at("alert", global_position, -3.0, 420.0)
    state = State.INVESTIGATE
    target = pos
    stuck = 0.0
    chasing = false  # just checking out a noise
    return true

# The torch is held out to the side he faces (10 screen pixels) and 14.8 up. `hand_local` is the spot on
# the ground plane under it (relative to his feet): the beam's rays are cast from there, so they start where
# the light does. `lens_screen` is where the lens shows on screen, relative to his feet.
func hand_local() -> Vector2:
    var side: float = -1.0 if sprite != null and sprite.flip_h else 1.0
    return Vector2(0.5, -0.5) * (10.0 * side / Sprites.ISO)

func lens_screen() -> Vector2:
    return Sprites.iso(hand_local()) + Vector2(0.0, -14.8)

# Casts the beam (BeamCast.gd): `beam_ground` becomes the ground points where each ray ends (relative to his
# feet), and where a ray ends on a wall the camera can see, the wall is told to light a patch there
# (BeamSpots.gd), brighter the nearer the wall.
func _update_beam() -> void:
    var r: Dictionary = BeamCastScript.cast(main, global_position, hand_local(), angle, FOV, RANGE, RAYS)
    beam_origin = r.origin
    beam_ground = r.ground
    lit_by_beam = BeamCastScript.register(get_instance_id(), lit_by_beam, r.strips)

func _process(delta: float) -> void:
    if main.state != "play":
        return
    if drop and state == State.PATROL:  # given up: a cop from a police car goes back to it (wherever he is)
        drop_t += delta
        if drop_t > 3.0:
            _leave()
            return
    # Cops far from the action stand still (and cost nothing).
    if global_position.distance_squared_to(main.player.global_position) > main.NEAR_VIEW * main.NEAR_VIEW:
        return
    moving = false
    eat_t = maxf(eat_t - delta, 0.0)
    _update_ai(delta)
    _update_detection(delta)
    _update_mark(delta)
    _update_beam()
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

# Exposure is stored in the original units; displays fill at this level's chase threshold.
func suspicion_progress() -> float:
    if state == State.CHASE:
        return 1.0
    return clampf(exposure / maxf(0.01, float(main.settings.get("cop_spot_at", SPOT_AT))), 0.0, 1.0)

# A yellow "?" while noticing her or investigating, a red "!" during a chase.
func alert_mark() -> String:
    match state:
        State.INVESTIGATE:
            return "?"
        State.CHASE:
            return "!"
    if seeing and suspicion_progress() >= 0.08:
        return "?"
    return ""

# Draws a mark ("?" or "!") over a cop's head `age` seconds after it appeared: it pops in large and
# settles, and the "!" throbs a little. (A static function so the sprite gallery can draw it too.)
static func draw_alert_mark(item: CanvasItem, mark: String, age: float) -> void:
    var chase: bool = mark == "!"
    var settle: float = 1.0 - clampf(age / MARK_POP, 0.0, 1.0)
    var size: int = roundi((20.0 if chase else 16.0) * (1.0 + 0.7 * settle * settle))
    var width: float = Style.DISPLAY_FONT.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    var bob: float = sin(age * 14.0) * 1.2 if chase else 0.0
    Style.draw_world_text(item, Vector2(-width * 0.5, -50.0 + bob), mark, size, MARK_CHASE if chase else MARK_INVESTIGATE)

# Keeps track of how long the current mark has been up, so a new one can pop in.
func _update_mark(delta: float) -> void:
    var now: String = alert_mark()
    if now != mark:
        mark = now
        mark_age = 0.0
        if now != "" and global_position.distance_to(main.player.global_position) < CLUE_DIST:
            main.clues.offer("cop_look" if now == "?" else "cop_chase", now == "!")
    else:
        mark_age += delta

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
            var alerted: bool = alert_t > 0.0
            if _step_toward(target, INVESTIGATE_SPEED * (ALERT_SPEED if alerted else 1.0), delta) or stuck > 0.6 \
                    or arrived or investigate_t > INVESTIGATE_MAX * (1.5 if alerted else 1.0):
                state = State.LOOK
                look_t = 4.0 if alerted else 2.5
                stuck = 0.0
        State.CHASE:
            if seeing:
                lost_t = 0.0
                target = main.player.global_position
            else:
                lost_t += delta
            var reached: bool = global_position.distance_to(target) < INVESTIGATE_ARRIVE
            _step_toward(target, float(main.settings.get("cop_chase_speed", CHASE_SPEED)), delta)
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
    var seconds: float = main.audit_time if main.audit_seed >= 0 else Time.get_ticks_msec() / 1000.0
    angle += sin(seconds / 0.6) * 0.7 * delta

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
    alert_t = maxf(0.0, alert_t - delta)
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
        if exposure > float(main.settings.get("cop_spot_at", SPOT_AT)) and state != State.CHASE:
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
    if dist > RANGE * (main.items.sight_range_mult() if actor == main.player else 1.0):
        return 0.0
    if dist > 4.0 and absf(angle_difference(angle, d.angle())) > FOV * 0.5:
        return 0.0
    if not main.los(global_position, p):
        return 0.0
    var closeness: float = 1.0 + (1.0 - dist / RANGE)
    var alertness: float = ALERT_SUSPICION if alert_t > 0.0 else 1.0
    return closeness / SEE_TIME * weight * actor.visibility_mult() * alertness * float(main.settings.cop_sight) * (0.5 if eat_t > 0.0 else 1.0)

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    if exposure > 0.02:
        var progress: float = suspicion_progress()
        draw_rect(Rect2(-15, -46, 30, 5), Color(0, 0, 0, 0.8))
        draw_rect(Rect2(-15, -46, 30.0 * progress, 5), Color(1.0, 1.0 - progress, 0.1))
    if mark != "":
        draw_alert_mark(self, mark, mark_age)
    elif eat_t > 0.0:
        ItemsScript.draw_icon(self, "donut", Vector2(0.0, -56.0), 13.0)
