extends Node2D
# Stella, on a short leash. She follows Nicole and can be spotted too.

const Sprites := preload("res://scripts/Sprites.gd")

const RADIUS := 4.0
const SPEED := 100.0
const LEASH := 55.0

var main
var sprite: Sprite2D
var idle_tex: Texture2D
var run_frames: Array = []
var moving := false
var anim_t := 0.0

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/dog/idle.png", 0.5)
    add_child(sprite)
    idle_tex = Sprites.load_tex("res://assets/sprites/dog/idle.png")
    run_frames = Sprites.load_frames("dog", ["extended0", "gathered0"])

func visibility_mult() -> float:
    return 1.8 if main.in_fire(global_position) else 1.0

func _process(delta: float) -> void:
    if main.state != "play":
        return
    var owner_pos: Vector2 = main.player.global_position
    var to_owner: Vector2 = owner_pos - global_position
    var dist: float = to_owner.length()
    moving = false
    if dist > 28.0:
        var dir: Vector2 = to_owner / dist
        var step: float = minf(SPEED * delta, dist - 24.0)
        global_position = main.slide(global_position, dir * step, RADIUS)
        moving = true
        sprite.flip_h = dir.x < 0.0

    var off: Vector2 = global_position - owner_pos
    if off.length() > LEASH:
        var pulled: Vector2 = owner_pos + off.limit_length(LEASH)
        if not main.blocked_circle(pulled, RADIUS):
            global_position = pulled

    if moving:
        anim_t += delta * 8.0
        sprite.texture = run_frames[int(anim_t) % run_frames.size()]
    else:
        sprite.texture = idle_tex
    queue_redraw()

func _draw() -> void:
    var to_owner: Vector2 = main.player.global_position - global_position
    draw_line(Vector2(0, -6), to_owner + Vector2(0, -14), Color(0.85, 0.3, 0.4), 1.0)
