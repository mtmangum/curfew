extends Node2D
# A cat that wanders to trash bins and knocks them over. Hisses and bolts if
# you get too close, which is also noisy.

const Sprites := preload("res://scripts/Sprites.gd")

enum State {IDLE, GO_PROP, KNOCK, FLEE, WANDER}

const RADIUS := 3.0
const STARTLE_DIST := 45.0

var main
var home := Vector2.ZERO
var state: State = State.IDLE
var timer := 1.0
var cooldown := 0.0
var goal := Vector2.ZERO
var prop = null
var moving := false
var anim_t := 0.0
var sprite: Sprite2D
var run_frames: Array = []
var hiss_frames: Array = []

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/cat/run0.png", 0.41)
    Sprites.upright(self, 4.0).add_child(sprite)
    run_frames = Sprites.load_frames("cat", ["run0", "run1", "run2", "run3"])
    hiss_frames = Sprites.load_frames("cat", ["hiss0", "hiss1"])
    home = global_position

func _process(delta: float) -> void:
    if main.state != "play":
        return
    moving = false
    cooldown = maxf(0.0, cooldown - delta)
    if state != State.FLEE and cooldown <= 0.0 \
            and global_position.distance_to(main.player.global_position) < STARTLE_DIST:
        _startle()

    match state:
        State.IDLE:
            timer -= delta
            if timer <= 0.0:
                _pick_next()
        State.GO_PROP:
            if prop == null or prop.knocked:
                state = State.IDLE
                timer = 1.0
            elif _step_toward(prop.global_position + Vector2(14, 0), 55.0, delta):
                state = State.KNOCK
                timer = 1.2
                main.play_at("cat_hiss", global_position, -6.0, 300.0)
        State.KNOCK:
            timer -= delta
            if timer <= 0.0:
                if prop != null:
                    prop.knock()
                _wander_goal()
        State.FLEE:
            timer -= delta
            if _step_toward(goal, 130.0, delta) or timer <= 0.0:
                state = State.IDLE
                timer = 2.0
        State.WANDER:
            timer -= delta
            if _step_toward(goal, 25.0, delta) or timer <= 0.0:
                state = State.IDLE
                timer = randf_range(1.5, 4.0)
    _animate(delta)

func _pick_next() -> void:
    var best = null
    var best_d := 400.0
    for p in main.props:
        if p.knocked:
            continue
        var d: float = global_position.distance_to(p.global_position)
        if d < best_d:
            best_d = d
            best = p
    if best != null:
        prop = best
        state = State.GO_PROP
    else:
        _wander_goal()

func _wander_goal() -> void:
    for i in 6:
        var cand := home + Vector2(randf_range(-60, 60), randf_range(-40, 40))
        if not main.blocked_circle(cand, RADIUS):
            goal = cand
            break
    state = State.WANDER
    timer = 4.0

func _startle() -> void:
    scare_from(main.player.global_position)
    main.noise(global_position, 110.0, true)
    main.play_at("meow", global_position, -2.0, 450.0)

# Bolt away from a point. Quiet by itself; callers add noise if appropriate.
func scare_from(src: Vector2) -> void:
    var away: Vector2 = global_position - src
    if away.length() < 1.0:
        away = Vector2.RIGHT
    goal = global_position + away.normalized() * 120.0
    state = State.FLEE
    timer = 1.5
    cooldown = 4.0

func _step_toward(g: Vector2, speed: float, delta: float) -> bool:
    var d: Vector2 = g - global_position
    var dist: float = d.length()
    if dist < 3.0:
        return true
    var dir: Vector2 = d / dist
    var before: Vector2 = global_position
    global_position = main.slide(global_position, dir * minf(speed * delta, dist), RADIUS)
    moving = global_position.distance_to(before) > 0.01
    # The cat sprites face left.
    if dir.x != dir.y:
        sprite.flip_h = not Sprites.faces_left(dir)
    return false

func _animate(delta: float) -> void:
    anim_t += delta * 10.0
    if state == State.KNOCK:
        sprite.texture = hiss_frames[int(anim_t * 0.5) % hiss_frames.size()]
    elif moving:
        sprite.texture = run_frames[int(anim_t) % run_frames.size()]
    else:
        sprite.texture = run_frames[0]
