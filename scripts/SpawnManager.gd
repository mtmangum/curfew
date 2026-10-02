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
    main.spawn_lure(pos, kind)
