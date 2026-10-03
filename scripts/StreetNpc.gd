extends Node2D
# Three kinds of street character to steer clear of. None can end the run in one go,
# but all are loud, so cops come, and all slow Nicole down.
#
#  HOBO  A crazy hobo who lives by a burn barrel. Mutters and shuffles about his spot
#        until Nicole comes near, then rants at her (loudly), shuffles over, and gets
#        hold of her: she crawls while he has her, and he keeps shouting.
#  ZOMBIE  A hobo gone wrong: ashen, in rags, with a cloud of flies round his head. Dozing in an alley until she comes within about 340 units,
#        then he shambles after her by smell, through anything but walls, moaning (loud).
#        Slower than even a sneak, so he can never catch her while she keeps moving; stand
#        still and he does. His bite costs life. Nothing loses him but distance. More of them
#        turn up if she lingers (see TrafficDirector.gd).
#  PUNK  Street punks who loiter under street lights. They notice Nicole from a way off,
#        jeer, then chase her faster than she can walk (but give up after 8 s). A punk who catches her shoves
#        her flat on her back. They give up if she gets far enough away.

const Sprites := preload("res://scripts/Sprites.gd")

enum Kind {HOBO, PUNK, ZOMBIE}
enum State {LOUNGE, RANT, GRAB, TAUNT, CHASE, RETURN, HUNT}

const SIGHT_HOBO := 105.0
const SIGHT_PUNK := 150.0
const HOBO_WALK := 14.0
const HOBO_RUSH := 34.0
const PUNK_WALK := 12.0
const PUNK_CHASE := 92.0  # faster than Nicole's 85, slower than a bark
const PUNK_RETURN := 55.0
const RADIUS := 5.0
const ZOMBIE_SPEED := 26.0   # slower than a sneak (42): he only catches her if she stops
const ZOMBIE_SENSE := 340.0
const ZOMBIE_LOSE := 700.0
const ZOMBIE_BITE_DIST := 14.0
const GRAB_MAX := 3.0        # a hobo's grip lasts this long, then she wrenches free
const GRAB_COOLDOWN := 6.0
const ZOMBIE_SLOW := 0.6          # she keeps this much of her speed in a zombie's grip (42 of 85: faster than he walks)
const ZOMBIE_HOLD_MAX := 2.5      # and she wrenches free after this long, shoving him back
const ZOMBIE_RELEASE_COOLDOWN := 6.0  # he cannot take hold of her again for this long
const PUNK_GIVE_UP_AFTER := 8.0  # a punk who cannot get her gives up after this long
const PUNK_LEAVE_ALONE := 12.0   # after he knocks her down he leaves her be for this long
const PUNK_BACK_OFF := 6.0       # and a punk who finds her already down (grace) backs off for this long

# A little swarm of flies round a zombie's head, drawn in code.
class Flies extends Node2D:
    var t := 0.0
    var seeds: Array = []

    func _init() -> void:
        for i in 6:
            seeds.append([randf() * TAU, randf_range(0.8, 1.7), randf_range(5.0, 11.0), randf_range(2.5, 5.5)])

    func tick(delta: float) -> void:
        t += delta
        queue_redraw()

    func _draw() -> void:
        for i in seeds.size():
            var s: Array = seeds[i]
            var a: float = s[0] + t * s[1] * 3.0
            # circling, with sudden darts
            var dart: float = sin(t * 7.0 + float(i) * 2.3)
            var p := Vector2(cos(a) * s[2] + dart * 2.0, -27.0 + sin(a * 1.7) * s[3] + sin(t * 23.0 + float(i)) * 1.2)
            draw_rect(Rect2(p.x - 0.6, p.y - 0.6, 1.2, 1.2), Color(0.04, 0.04, 0.05))
            # wings flicker
            if int(t * 30.0 + float(i)) % 2 == 0:
                draw_rect(Rect2(p.x - 1.4, p.y - 1.5, 1.0, 0.8), Color(0.85, 0.88, 0.95, 0.55))
                draw_rect(Rect2(p.x + 0.4, p.y - 1.5, 1.0, 0.8), Color(0.85, 0.88, 0.95, 0.55))

var main
var kind: int = Kind.HOBO
var home := Vector2.ZERO
var state: int = State.LOUNGE
var sprite: Sprite2D
var frames: Array = []
var action_frames: Array = []  # hobo rant, punk shove
var timer := 1.0
var yell_cd := 0.0
var shove_cd := 0.0
var lost_t := 0.0
var anim_t := 0.0
var wander_goal := Vector2.ZERO
var moving := false
var flip_left := false
var stuck_t := 0.0
var detour_t := 0.0
var detour_dir := Vector2.ZERO
var grab_t := 0.0
var grab_cd := 0.0
var chase_t := 0.0
var leave_alone_t := 0.0  # > 0: this punk will not go for her
var shoved := false
var flies: Node2D
var drifter := false  # turned up because Nicole lingered; removed when far behind

func setup(game, k: int, home_pos: Vector2) -> void:
    main = game
    kind = k
    home = home_pos
    wander_goal = home_pos

func _ready() -> void:
    if kind == Kind.HOBO or kind == Kind.ZOMBIE:
        var look: String = "zombie" if kind == Kind.ZOMBIE else "hobo"
        frames = Sprites.load_frames(look, ["shuffle0", "shuffle1", "shuffle2", "shuffle3"])
        action_frames = Sprites.load_frames(look, ["rant0", "rant1"])
    else:
        frames = Sprites.load_frames("punk", ["walk0", "walk1", "walk2", "walk3"])
        action_frames = Sprites.load_frames("punk", ["shove"])
    var folder: String = "punk" if kind == Kind.PUNK else ("zombie" if kind == Kind.ZOMBIE else "hobo")
    sprite = Sprites.make("res://assets/sprites/%s/%s.png" % [folder, ("walk0" if kind == Kind.PUNK else "shuffle0")], 0.36)
    var layer: Node2D = Sprites.upright(self, 6.0)
    layer.add_child(sprite)
    if kind == Kind.ZOMBIE:
        flies = Flies.new()
        layer.add_child(flies)
    timer = randf_range(0.5, 3.0)

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    var pp: Vector2 = main.player.global_position
    var d: float = global_position.distance_to(pp)
    if d > main.NEAR_VIEW:
        return  # far from the action: stand still and cost nothing
    yell_cd = maxf(0.0, yell_cd - delta)
    shove_cd = maxf(0.0, shove_cd - delta)
    grab_cd = maxf(0.0, grab_cd - delta)
    leave_alone_t = maxf(0.0, leave_alone_t - delta)
    moving = false
    if kind == Kind.ZOMBIE:
        _zombie(delta, pp, d)
        _animate(delta)
        flies.tick(delta)
        return
    var sees: bool = d < (SIGHT_HOBO if kind == Kind.HOBO else SIGHT_PUNK) and main.los(global_position, pp)
    if kind == Kind.HOBO:
        _hobo(delta, pp, d, sees)
    else:
        _punk(delta, pp, d, sees)
    _animate(delta)

# --- The hobo ------------------------------------------------------------------------
func _hobo(delta: float, pp: Vector2, d: float, sees: bool) -> void:
    match state:
        State.LOUNGE:
            _potter(delta, HOBO_WALK, 38.0)
            if sees:
                state = State.RANT
                lost_t = 0.0
        State.RANT:
            _face(pp - global_position)
            _step_toward(pp, HOBO_RUSH, delta)
            _shout(1.7, 240.0, 0.82)
            lost_t = 0.0 if sees else lost_t + delta
            if d < 20.0 and grab_cd <= 0.0:
                state = State.GRAB
                grab_t = 0.0
            elif lost_t > 5.0 or d > 230.0:
                state = State.RETURN
        State.GRAB:
            # He has hold of her: she crawls, and he bellows in her face.
            _face(pp - global_position)
            main.player.hold(0.3)
            main.drain(main.vitals.HOBO_DRAIN * delta, "hobo")
            _shout(1.0, 320.0, 0.78)
            grab_t += delta
            if grab_t > GRAB_MAX:
                # She wrenches free and he staggers back, spent for a while.
                grab_cd = GRAB_COOLDOWN
                state = State.RANT
                main.player.hold(0.0)
            elif d > 30.0:
                state = State.RANT
        State.RETURN:
            if _step_toward(home, HOBO_WALK * 1.6, delta):
                state = State.LOUNGE
            if sees:
                state = State.RANT

# --- The zombie ---------------------------------------------------------------------
func _zombie(delta: float, pp: Vector2, d: float) -> void:
    match state:
        State.LOUNGE:
            _potter(delta, 6.0, 18.0)
            if d < ZOMBIE_SENSE:
                state = State.HUNT
                _shout(0.0, 200.0, 1.0, "zombie_moan")
        State.HUNT:
            _face(pp - global_position)
            _step_toward(pp, ZOMBIE_SPEED, delta)
            _shout(3.2, 190.0, 1.0, "zombie_moan")
            if d < ZOMBIE_BITE_DIST and grab_cd <= 0.0:
                main.player.hold(0.3, ZOMBIE_SLOW)  # he has her by the coat, but she can pull away
                grab_t += delta
                if main.hurt(main.vitals.ZOMBIE_DAMAGE, "zombie"):
                    main.play_at("zombie_bite", global_position, -2.0, 350.0)
                if grab_t > ZOMBIE_HOLD_MAX:
                    # She wrenches free and he staggers back: she has time to get away.
                    grab_t = 0.0
                    grab_cd = ZOMBIE_RELEASE_COOLDOWN
                    main.player.slow_t = 0.0
                    global_position = main.slide(global_position, (global_position - pp).normalized() * 18.0, RADIUS)
            else:
                grab_t = maxf(0.0, grab_t - delta * 2.0)
                if d > ZOMBIE_LOSE:
                    state = State.RETURN
        State.RETURN:
            if _step_toward(home, ZOMBIE_SPEED, delta):
                state = State.LOUNGE
            if d < ZOMBIE_SENSE:
                state = State.HUNT

# --- The punk ------------------------------------------------------------------------
func _punk(delta: float, pp: Vector2, d: float, sees: bool) -> void:
    match state:
        State.LOUNGE:
            _potter(delta, PUNK_WALK, 30.0)
            if sees and leave_alone_t <= 0.0:
                state = State.TAUNT
                timer = 0.7
                lost_t = 0.0
                _shout(0.0, 220.0, 1.1)
        State.TAUNT:
            # A beat of jeering before they come: she has time to run.
            _face(pp - global_position)
            timer -= delta
            if timer <= 0.0:
                if shoved:
                    shoved = false  # he has had his fun: he lets her get up and go
                    state = State.RETURN
                else:
                    state = State.CHASE
                    chase_t = 0.0
        State.CHASE:
            _face(pp - global_position)
            _step_toward(pp, PUNK_CHASE, delta)
            _shout(2.2, 220.0, 1.1)
            lost_t = 0.0 if sees else lost_t + delta
            chase_t += delta
            if d < 15.0 and shove_cd <= 0.0:
                _shove(pp)
            elif lost_t > 6.0 or d > 330.0:
                state = State.RETURN
            elif chase_t > PUNK_GIVE_UP_AFTER:
                state = State.RETURN
                leave_alone_t = PUNK_BACK_OFF

        State.RETURN:
            if _step_toward(home, PUNK_RETURN, delta):
                state = State.LOUNGE
            if sees and leave_alone_t <= 0.0:
                state = State.TAUNT
                timer = 0.4

func _shove(pp: Vector2) -> void:
    if not main.hurt(main.vitals.PUNK_DAMAGE, "punk"):
        # She is already down or still in grace from the last hit: he backs off instead.
        state = State.RETURN
        leave_alone_t = PUNK_BACK_OFF
        return
    shove_cd = 3.5
    leave_alone_t = PUNK_LEAVE_ALONE
    shoved = true
    var away: Vector2 = (pp - global_position).normalized()
    main.player.stun(1.1, away * 26.0)
    main.noise(global_position, 240.0, true)
    main.play_at("yell", global_position, 0.0, 600.0, 1.15)
    main.play_at("shove", global_position, 0.0, 400.0)
    state = State.TAUNT  # a moment of gloating, then he lets her go
    timer = 1.0

# --- Shared bits ------------------------------------------------------------------------
# Loiter: shuffle to a spot near home now and then.
func _potter(delta: float, speed: float, radius: float) -> void:
    timer -= delta
    if timer <= 0.0:
        var pick: Vector2 = home + Vector2.from_angle(randf() * TAU) * randf_range(4.0, radius)
        if not main.blocked_circle(pick, RADIUS):
            wander_goal = pick
        timer = randf_range(1.5, 4.0)
    if global_position.distance_to(wander_goal) > 3.0:
        _step_toward(wander_goal, speed, delta)

# Returns true once at the goal.
func _step_toward(goal: Vector2, speed: float, delta: float) -> bool:
    var to: Vector2 = goal - global_position
    var dist: float = to.length()
    if dist < 3.0:
        return true
    var dir: Vector2 = to / dist
    var step: float = minf(speed * delta, dist)
    if detour_t > 0.0:
        # Going round something that was in the way.
        detour_t -= delta
        dir = detour_dir
        step = speed * delta
    var before: Vector2 = global_position
    global_position = main.slide(global_position, dir * step, RADIUS)
    if global_position.distance_to(before) > 0.01:
        stuck_t = 0.0
        moving = true
        _face(dir)
    else:
        stuck_t += delta
        if stuck_t > 0.2 and detour_t <= 0.0:
            # Blocked head-on: sidestep for a moment, then try the direct way again.
            var side: Vector2 = to.orthogonal().normalized() * (1.0 if randf() < 0.5 else -1.0)
            detour_dir = (side + to.normalized() * 0.4).normalized()
            detour_t = 0.7
            stuck_t = 0.0
    return false

func _shout(every: float, noise_radius: float, pitch: float, sound: String = "yell") -> void:
    if yell_cd > 0.0:
        return
    yell_cd = every
    main.noise(global_position, noise_radius, true)  # cops hear it
    main.play_at(sound, global_position, 0.0, 600.0, pitch * randf_range(0.95, 1.05))

# Face along a ground direction, flipping only when it is clearly to one side.
func _face(dir: Vector2) -> void:
    var across: float = dir.x - dir.y
    if absf(across) > 0.35 * maxf(dir.length(), 0.001):
        flip_left = across < 0.0
        sprite.flip_h = flip_left

func _animate(delta: float) -> void:
    anim_t += delta
    if kind == Kind.ZOMBIE:
        # arms reaching when close, otherwise a slow lurch
        if state == State.HUNT and global_position.distance_to(main.player.global_position) < 55.0:
            sprite.texture = action_frames[int(anim_t * 2.5) % 2]
        elif moving:
            sprite.texture = frames[int(anim_t * 3.0) % frames.size()]
        else:
            sprite.texture = frames[0]
        return
    var shouting: bool = state == State.RANT or state == State.GRAB
    var shoving: bool = kind == Kind.PUNK and state == State.TAUNT and shove_cd > 2.0
    if kind == Kind.HOBO and shouting:
        sprite.texture = action_frames[int(anim_t * 4.0) % 2]
    elif shoving:
        sprite.texture = action_frames[0]
    elif moving:
        sprite.texture = frames[int(anim_t * (9.0 if state == State.CHASE else 6.0)) % frames.size()]
    else:
        sprite.texture = frames[0]
