extends Node2D

enum State {FOLLOW_OWNER, CHASE_LURE, RETURN}

var speed := 200.0
var owner_pos := Vector2.ZERO
var target_lure := null
var state := State.FOLLOW_OWNER

func set_owner_position(p):
    owner_pos = p

func attract_to(lure_node):
    target_lure = lure_node
    state = State.CHASE_LURE

func clear_lure():
    target_lure = null
    state = State.FOLLOW_OWNER

func _physics_process(delta):
    var target := owner_pos
    if state == State.CHASE_LURE and target_lure != null and is_instance_valid(target_lure):
        target = target_lure.global_position
        # if reached lure, notify main and clear
        if global_position.distance_to(target) < 12:
            var main = get_parent()
            if main and main.has_method("on_lure_collected"):
                main.on_lure_collected(target_lure)
            clear_lure()
    elif state == State.RETURN:
        target = owner_pos

    var dir := target - global_position
    if dir.length() > 6:
        global_position += dir.normalized() * speed * delta
        update()

func _draw():
    draw_circle(Vector2.ZERO, 10, Color(1,0.6,0.2))
