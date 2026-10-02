extends Node2D
# Stella, on a short leash. She follows Nicole and can be spotted too.

const Sprites := preload("res://scripts/Sprites.gd")

const RADIUS := 4.0
const SPEED := 100.0
const LEASH := 55.0
const NOTICE := 90.0
const PULL_SPEED := 30.0
const BARK_NOISE := 150.0

var main
var sprite: Sprite2D
var up: Node2D
var idle_tex: Texture2D
var run_frames: Array = []
var moving := false
var anim_t := 0.0
var bark_cd := 0.0
var chasing = null

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/dog/idle.png", 0.5)
    up = Sprites.upright(self, 5.0)
    up.add_child(sprite)
    idle_tex = Sprites.load_tex("res://assets/sprites/dog/idle.png")
    run_frames = Sprites.load_frames("dog", ["extended0", "gathered0"])

func visibility_mult() -> float:
    return 1.8 if main.in_fire(global_position) else 1.0

func _nearest_cat():
    var best = null
    var best_d := NOTICE
    for c in main.cats:
        if c.state == c.State.FLEE:
            continue
        var d: float = global_position.distance_to(c.global_position)
        if d < best_d:
            best_d = d
            best = c
    return best

func _bark(cat) -> void:
    bark_cd = 3.0
    main.noise(global_position, BARK_NOISE, true)
    main.play("bark", -6.0)
    cat.scare_from(global_position)

func _process(delta: float) -> void:
    if main.state != "play":
        return
    bark_cd = maxf(0.0, bark_cd - delta)
    var owner_pos: Vector2 = main.player.global_position
    chasing = _nearest_cat()
    moving = false
    if chasing != null:
        var to_cat: Vector2 = chasing.global_position - global_position
        var cat_dist: float = to_cat.length()
        if cat_dist > 26.0:
            var cdir: Vector2 = to_cat / cat_dist
            global_position = main.slide(global_position, cdir * SPEED * delta, RADIUS)
            moving = true
            sprite.flip_h = Sprites.faces_left(cdir)
        elif bark_cd <= 0.0:
            _bark(chasing)
    else:
        var to_owner: Vector2 = owner_pos - global_position
        var dist: float = to_owner.length()
        if dist > 28.0:
            var dir: Vector2 = to_owner / dist
            var step: float = minf(SPEED * delta, dist - 24.0)
            global_position = main.slide(global_position, dir * step, RADIUS)
            moving = true
            sprite.flip_h = Sprites.faces_left(dir)

    var off: Vector2 = global_position - owner_pos
    if off.length() > LEASH:
        var pulled: Vector2 = owner_pos + off.limit_length(LEASH)
        if not main.blocked_circle(pulled, RADIUS):
            global_position = pulled
        # Straining after a cat drags Nicole along. Sneaking digs her heels in.
        if chasing != null and not main.player.sneaking:
            var tug: Vector2 = (global_position - owner_pos).normalized() * PULL_SPEED * delta
            main.player.global_position = main.slide(owner_pos, tug, main.player.RADIUS)

    if moving:
        anim_t += delta * 8.0
        sprite.texture = run_frames[int(anim_t) % run_frames.size()]
    else:
        sprite.texture = idle_tex
    queue_redraw()

func _draw() -> void:
    var to_owner: Vector2 = main.player.global_position - global_position
    draw_set_transform_matrix(Sprites.UP)
    draw_line(Vector2(0, -6), Sprites.iso(to_owner) + Vector2(0, -14), Color(0.85, 0.3, 0.4), 1.0)
