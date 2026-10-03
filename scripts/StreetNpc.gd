extends Node2D
# Two kinds of street character to steer clear of. Neither can end the run on its own,
# but both are loud, so cops come, and both slow Nicole down.
#
#  HOBO  A crazy hobo who lives by a burn barrel. Mutters and shuffles about his spot
#        until Nicole comes near, then rants at her (loudly), shuffles over, and gets
#        hold of her: she crawls while he has her, and he keeps shouting.
#  PUNK  Street punks who loiter under street lights. They notice Nicole from a way off,
#        jeer, then chase her faster than she can walk. A punk who catches her shoves
#        her flat on her back. They give up if she gets far enough away.

const Sprites := preload("res://scripts/Sprites.gd")

enum Kind {HOBO, PUNK}
enum State {LOUNGE, RANT, GRAB, TAUNT, CHASE, RETURN}

const SIGHT_HOBO := 105.0
const SIGHT_PUNK := 150.0
const HOBO_WALK := 14.0
const HOBO_RUSH := 34.0
const PUNK_WALK := 12.0
const PUNK_CHASE := 92.0  # faster than Nicole's 85, slower than a bark
const PUNK_RETURN := 55.0
const RADIUS := 5.0

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

func setup(game, k: int, home_pos: Vector2) -> void:
    main = game
    kind = k
    home = home_pos
    wander_goal = home_pos

func _ready() -> void:
    if kind == Kind.HOBO:
        frames = Sprites.load_frames("hobo", ["shuffle0", "shuffle1", "shuffle2", "shuffle3"])
        action_frames = Sprites.load_frames("hobo", ["rant0", "rant1"])
    else:
        frames = Sprites.load_frames("punk", ["walk0", "walk1", "walk2", "walk3"])
        action_frames = Sprites.load_frames("punk", ["shove"])
    sprite = Sprites.make("res://assets/sprites/%s/%s.png" % [("hobo" if kind == Kind.HOBO else "punk"), ("shuffle0" if kind == Kind.HOBO else "walk0")], 0.36)
    Sprites.upright(self, 6.0).add_child(sprite)
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
    moving = false
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
            if d < 20.0:
                state = State.GRAB
            elif lost_t > 5.0 or d > 230.0:
                state = State.RETURN
        State.GRAB:
            # He has hold of her: she crawls, and he bellows in her face.
            _face(pp - global_position)
            main.player.hold(0.3)
            _shout(1.0, 320.0, 0.78)
            if d > 30.0:
                state = State.RANT
        State.RETURN:
            if _step_toward(home, HOBO_WALK * 1.6, delta):
                state = State.LOUNGE
            if sees:
                state = State.RANT

# --- The punk ------------------------------------------------------------------------
func _punk(delta: float, pp: Vector2, d: float, sees: bool) -> void:
    match state:
        State.LOUNGE:
            _potter(delta, PUNK_WALK, 30.0)
            if sees:
                state = State.TAUNT
                timer = 0.7
                lost_t = 0.0
                _shout(0.0, 220.0, 1.1)
        State.TAUNT:
            # A beat of jeering before they come: she has time to run.
            _face(pp - global_position)
            timer -= delta
            if timer <= 0.0:
                state = State.CHASE
        State.CHASE:
            _face(pp - global_position)
            _step_toward(pp, PUNK_CHASE, delta)
            _shout(2.2, 220.0, 1.1)
            lost_t = 0.0 if sees else lost_t + delta
            if d < 15.0 and shove_cd <= 0.0:
                _shove(pp)
            elif lost_t > 6.0 or d > 330.0:
                state = State.RETURN
        State.RETURN:
            if _step_toward(home, PUNK_RETURN, delta):
                state = State.LOUNGE
            if sees:
                state = State.TAUNT
                timer = 0.4

func _shove(pp: Vector2) -> void:
    shove_cd = 3.5
    var away: Vector2 = (pp - global_position).normalized()
    main.player.stun(1.1, away * 26.0)
    main.noise(global_position, 240.0, true)
    main.play_at("yell", global_position, 0.0, 600.0, 1.15)
    main.play_at("bin_crash", global_position, -10.0, 300.0)
    state = State.TAUNT  # a moment of gloating before the next go
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

func _shout(every: float, noise_radius: float, pitch: float) -> void:
    if yell_cd > 0.0:
        return
    yell_cd = every
    main.noise(global_position, noise_radius, true)  # cops hear it
    main.play_at("yell", global_position, 0.0, 600.0, pitch * randf_range(0.95, 1.05))

# Face along a ground direction, flipping only when it is clearly to one side.
func _face(dir: Vector2) -> void:
    var across: float = dir.x - dir.y
    if absf(across) > 0.35 * maxf(dir.length(), 0.001):
        flip_left = across < 0.0
        sprite.flip_h = flip_left

func _animate(delta: float) -> void:
    anim_t += delta
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
