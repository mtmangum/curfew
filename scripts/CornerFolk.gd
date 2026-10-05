extends Node2D
# A person who stands on a corner under the neon, from level 5 ("Neon Nose"). Three kinds (assets/sprites/cornerfolk,
# made by docs/tools/render_cornerfolk.mjs): one leaning in a long pink coat, one under an umbrella, one smoking.
# They stay where they are, and they are not a danger: Stella is drawn to them. She stops and sniffs for a few
# seconds (see Dog.gd), and the leash holds Nicole while she does. Each one can be sniffed again only after a good
# while, so one corner cannot trap her. (LevelBuilder._place_corner_folk puts them under the signs.)

const Sprites := preload("res://scripts/Sprites.gd")

const COOLDOWN := 40.0     # seconds before Stella will stop for the same person again
const KINDS := ["lean", "umbrella", "smoke"]

var main
var kind := "lean"
var facing_left := false
var frames: Array = []
var sprite: Sprite2D
var cool := 0.0
var t := 0.0
var shown := -1

func _ready() -> void:
    frames = Sprites.load_frames("cornerfolk", ["%s0" % kind, "%s1" % kind])
    sprite = Sprites.make("res://assets/sprites/cornerfolk/%s0.png" % kind, 0.36)
    Sprites.upright(self, 6.0).add_child(sprite)
    sprite.flip_h = facing_left
    t = randf() * 6.0

# Whether Stella will stop for this person now.
func ready_to_sniff() -> bool:
    return cool <= 0.0

# Stella has come to sniff: the cooldown starts, and the person turns to look at her.
func sniffed(from: Vector2) -> void:
    cool = COOLDOWN
    sprite.flip_h = Sprites.faces_left(from - global_position)

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    if global_position.distance_squared_to(main.player.global_position) > main.NEAR_VIEW * main.NEAR_VIEW:
        return  # far from the action: stand still and cost nothing
    cool = maxf(0.0, cool - delta)
    t += delta
    var f: int = int(t * 1.4) % 2
    if f != shown:
        shown = f
        Sprites.set_tex(sprite, frames[f])
