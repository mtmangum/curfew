extends Node2D
# A burning trash can. Anyone standing in its glow is easier to spot.

const Sprites := preload("res://scripts/Sprites.gd")

var main
var radius := 80.0
var sprite: Sprite2D
var frames: Array = []
var t := 0.0

func _ready() -> void:
    z_index = -40
    sprite = Sprites.make("res://assets/sprites/trashfire/flicker0.png", 0.36)
    sprite.z_index = 40
    add_child(sprite)
    frames = Sprites.load_frames("trashfire", ["flicker0", "flicker1"])

func lights(p: Vector2) -> bool:
    return p.distance_to(global_position) < radius

func _process(delta: float) -> void:
    t += delta
    sprite.texture = frames[int(t * 5.0) % frames.size()]
    queue_redraw()

func _draw() -> void:
    var flick: float = 0.85 + 0.15 * sin(t * 13.0)
    for i in 5:
        var k: float = float(i + 1) / 5.0
        draw_circle(Vector2(0, -6), radius * k * flick, Color(1.0, 0.55, 0.15, 0.06))
