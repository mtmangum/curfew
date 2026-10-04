extends Node2D
# A trash bin. Cats knock it over, which makes noise cops come to investigate.

const Sprites := preload("res://scripts/Sprites.gd")

const NOISE_RADIUS := 260.0
const CLUE_DIST := 450.0  # a crash this near to Nicole is one she can see: it gets explained (Clues.gd)

var main
var radius := 6.0
var sprite: Sprite2D
var knocked := false

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/trashbin/upright.png", 0.36)
    Sprites.upright(self, 6.0).add_child(sprite)

func knock() -> void:
    if knocked:
        return
    knocked = true
    sprite.rotation = deg_to_rad(80.0)
    sprite.modulate = Color(0.75, 0.75, 0.75)
    var turned: int = main.noise(global_position, NOISE_RADIUS, true)
    main.play_at("bin_crash", global_position, 0.0, 700.0)
    if global_position.distance_to(main.player.global_position) < CLUE_DIST:
        main.clues.offer("bin" if turned > 0 else "bin_quiet")
