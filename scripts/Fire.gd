extends Node2D
# A burning trash can. Anyone standing in its glow is easier to spot.

const Sprites := preload("res://scripts/Sprites.gd")

class Glow extends Node2D:
    var fire

    func _draw() -> void:
        var flick: float = 0.85 + 0.15 * sin(fire.t * 13.0)
        for i in 5:
            var k: float = float(i + 1) / 5.0
            draw_circle(Vector2.ZERO, fire.radius * k * flick, Color(1.0, 0.55, 0.15, 0.06))

var main
var radius := 80.0  # how far the glow reaches
var body_radius := 7.0  # the barrel itself is solid
var sprite: Sprite2D
var glow: Glow
var frames: Array = []
var t := 0.0

func _ready() -> void:
    glow = Glow.new()
    glow.fire = self
    glow.z_as_relative = false
    glow.z_index = -30
    add_child(glow)
    sprite = Sprites.make("res://assets/sprites/trashfire/flicker0.png", 0.36)
    Sprites.upright(self, 6.0).add_child(sprite)
    frames = Sprites.load_frames("trashfire", ["flicker0", "flicker1"])

func lights(p: Vector2) -> bool:
    return p.distance_to(global_position) < radius

func _process(delta: float) -> void:
    t += delta
    sprite.texture = frames[int(t * 5.0) % frames.size()]
    glow.queue_redraw()
