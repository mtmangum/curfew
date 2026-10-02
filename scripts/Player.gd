extends Node2D
# Nicole. WASD / arrows to move, Shift to sneak.

const Sprites := preload("res://scripts/Sprites.gd")

const RADIUS := 5.0
const WALK_SPEED := 85.0
const SNEAK_SPEED := 42.0
const FOOTSTEP_NOISE := 45.0

var main
var sprite: Sprite2D
var walk_frames: Array = []
var idle_tex: Texture2D
var sneaking := false
var moving := false
var in_cover := false
var lit := false
var anim_t := 0.0
var step_timer := 0.0

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/player/idle0.png", 0.5)
    add_child(sprite)
    idle_tex = Sprites.load_tex("res://assets/sprites/player/idle0.png")
    walk_frames = Sprites.load_frames("player", ["walk0", "walk1", "walk2", "walk3", "walk4", "walk5"])

# Multiplier on how fast cops notice us.
func visibility_mult() -> float:
    var m := 1.0
    if sneaking:
        m *= 0.55
    if not moving:
        m *= 0.8
    if lit:
        m *= 1.8
    return m

func _process(delta: float) -> void:
    if main.state != "play":
        return
    var dir := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        dir.x += 1.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        dir.x -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        dir.y += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        dir.y -= 1.0
    sneaking = Input.is_physical_key_pressed(KEY_SHIFT)
    moving = dir.length() > 0.0
    if moving:
        var speed := SNEAK_SPEED if sneaking else WALK_SPEED
        global_position = main.slide(global_position, dir.normalized() * speed * delta, RADIUS)
        if dir.x != 0.0:
            sprite.flip_h = dir.x < 0.0
        anim_t += delta * (6.0 if sneaking else 10.0)
        sprite.texture = walk_frames[int(anim_t) % walk_frames.size()]
        if not sneaking:
            step_timer -= delta
            if step_timer <= 0.0:
                step_timer = 0.45
                main.noise(global_position, FOOTSTEP_NOISE, false)
    else:
        sprite.texture = idle_tex
        anim_t = 0.0

    in_cover = main.in_steam(global_position)
    lit = main.in_fire(global_position)
    var tint := Color(1, 1, 1, 1)
    if sneaking:
        tint = Color(0.75, 0.75, 0.85, 1)
    if lit:
        tint = Color(1.2, 1.0, 0.8, 1)
    if in_cover:
        tint.a = 0.45
    sprite.modulate = tint
