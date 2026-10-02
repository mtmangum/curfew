extends Node2D
# A street steam vent. While venting, the cloud blocks sight lines and hides
# anyone standing in it. A short puff of warning comes just before it starts.

const ON_TIME := 4.0
const OFF_TIME := 3.5

class Cloud extends Node2D:
    var vent

    func _draw() -> void:
        var amt: float = vent.amount
        if amt > 0.01:
            for i in 9:
                var a: float = float(i) * 0.7 + vent.t * 0.4
                var wob: float = 0.5 + 0.5 * sin(vent.t * 1.3 + float(i))
                var c: Vector2 = Vector2.from_angle(a) * vent.radius * 0.45 * wob
                draw_circle(c + Vector2(0, -8), vent.radius * 0.55, Color(0.86, 0.9, 0.95, 0.30 * amt))
            draw_circle(Vector2(0, -8), vent.radius * 0.7, Color(0.9, 0.93, 0.97, 0.25 * amt))
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
    cloud.z_index = 50
    add_child(cloud)

func _process(delta: float) -> void:
    t += delta
    var cyc: float = fmod(t, ON_TIME + OFF_TIME)
    active = cyc < ON_TIME
    hint = (not active) and cyc > ON_TIME + OFF_TIME - 1.0
    amount = move_toward(amount, 1.0 if active else 0.0, delta * 1.5)
    cloud.queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(-14, -5, 28, 10), Color(0.08, 0.09, 0.12))
    for i in 6:
        draw_rect(Rect2(-12 + i * 4, -4, 2, 8), Color(0.28, 0.3, 0.36))
