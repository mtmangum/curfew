extends Node

@export var spawn_interval := 3.5
@export var spawn_radius := 360
@export var initial_spawn := 3

var timer := 0.0
var kinds := ["squirrel","pigeon","pizza"]

func _ready():
    # spawn a few to start
    for i in range(initial_spawn):
        _spawn_random()

func _process(delta):
    timer += delta
    if timer >= spawn_interval:
        timer = 0
        _spawn_random()

func _spawn_random():
    var main = get_parent()
    if not main:
        return
    var cam_pos = main.get_node("Camera2D").global_position
    var offset = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized() * (randf() * spawn_radius)
    var pos = cam_pos + offset
    var kind = kinds[randi() % kinds.size()]
    main.spawn_lure(pos)
    # after spawn, set kind on last child lure if possible
    var last = main.get_child(main.get_child_count() - 1)
    if last and last is Node and last.has_method("set"):
        if last.has_variable("kind"):
            last.kind = kind
*** End Patch