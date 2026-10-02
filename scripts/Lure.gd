extends Node2D

@export var kind: String = "pizza"
@export var attraction: float = 1.6
@export var lifetime: float = 20.0

func _ready():
    match kind:
        "squirrel":
            attraction = 1.2
            lifetime = 12.0
        "pigeon":
            attraction = 1.0
            lifetime = 8.0
        "pizza":
            attraction = 1.6
            lifetime = 25.0
        _: 
            attraction = 1.0
    set_process(true)
    update()

func _process(delta):
    lifetime -= delta
    if lifetime <= 0:
        queue_free()

func _draw():
    var c = Color(1,0.8,0.2)
    if kind == "squirrel":
        c = Color(0.5,0.3,0.1)
    elif kind == "pigeon":
        c = Color(0.6,0.6,0.7)
    draw_circle(Vector2.ZERO, 8, c)
