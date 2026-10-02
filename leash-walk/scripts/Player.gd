extends Node2D

var speed := 220.0
var tug := Vector2.ZERO

func apply_tug(v: Vector2):
    tug += v

func _physics_process(delta):
    var input_dir := Vector2(Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
                        Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
    if input_dir.length() > 0:
        global_position += input_dir.normalized() * speed * delta
    # apply any tug from the dog
    if tug.length() > 0.01:
        global_position += tug
        tug *= 0.85
    update()

func _draw():
    draw_circle(Vector2.ZERO, 12, Color(0.2,0.6,1))
