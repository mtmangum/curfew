extends Node2D
# A street steam vent. While venting, the cloud blocks sight lines and hides
# anyone standing in it. A short puff of warning comes just before it starts.

const Sprites := preload("res://scripts/Sprites.gd")

const ON_TIME := 4.0
const OFF_TIME := 3.5

class Cloud extends Node2D:
    var vent

    # Puffs are drawn upright so the steam rises instead of lying on the ground.
    func _draw() -> void:
        draw_set_transform_matrix(Sprites.UP)
        var amt: float = vent.amount
        var r: float = vent.radius * Sprites.ISO
        if amt > 0.01:
            for i in 9:
                var a: float = float(i) * 0.7 + vent.t * 0.4
                var wob: float = 0.5 + 0.5 * sin(vent.t * 1.3 + float(i))
                var c: Vector2 = Sprites.iso(Vector2.from_angle(a) * vent.radius * 0.45 * wob)
                draw_circle(c + Vector2(0, -16), r * 0.7, Color(0.86, 0.9, 0.95, 0.30 * amt))
            draw_circle(Vector2(0, -16), r * 0.9, Color(0.9, 0.93, 0.97, 0.25 * amt))
        elif vent.hint:
            for i in 3:
                var c: Vector2 = Vector2(float(i - 1) * 6.0, -4.0 - float(i) * 4.0 - fmod(vent.t * 8.0, 6.0))
                draw_circle(c, 5.0, Color(0.9, 0.93, 0.97, 0.25))

var main
var radius := 46.0
var phase := 0.0
var t := 0.0
var active := false
var hint := false
var amount := 0.0
var cloud: Cloud

func _ready() -> void:
    t = phase
    cloud = Cloud.new()
    cloud.vent = self
    cloud.z_as_relative = false
    cloud.z_index = 3000
    add_child(cloud)

func _process(delta: float) -> void:
    t += delta
    var cyc: float = fmod(t, ON_TIME + OFF_TIME)
    active = cyc < ON_TIME
    hint = (not active) and cyc > ON_TIME + OFF_TIME - 1.0
    amount = move_toward(amount, 1.0 if active else 0.0, delta * 1.5)
    cloud.queue_redraw()

func _draw() -> void:
    # A flat grate set into the street.
    draw_rect(Rect2(-13, -13, 26, 26), Color(0.26, 0.28, 0.34))
    draw_rect(Rect2(-11, -11, 22, 22), Color(0.06, 0.07, 0.1))
    for i in 6:
        draw_rect(Rect2(-9 + i * 3.6, -11, 1.8, 22), Color(0.3, 0.32, 0.38))
