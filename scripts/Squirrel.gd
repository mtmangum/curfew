extends Node2D
# A squirrel at the foot of a tree. When Stella (or Nicole) comes near it bolts up the
# trunk and sits in the branches for a while; Stella wants it badly, and stands under
# the tree barking up at it until it settles (see Dog.gd). Art: assets/sprites/squirrel,
# made by docs/tools/render_squirrel.mjs.

const Sprites := preload("res://scripts/Sprites.gd")

enum State {IDLE, RUN, CLIMB, TREED, AWAY}

const SCALE := 0.34  # smaller than a cat (0.41): about 11 world units tall sitting
const SPOOK_DOG := 95.0
const SPOOK_NICOLE := 55.0
const RUN_SPEED := 150.0
const TREED_TIME := 8.0     # up the tree, taunting: Stella barks at it this long
const AWAY_TIME := 30.0     # before it comes back down

var main
var tree_pos := Vector2.ZERO
var home := Vector2.ZERO
var state: int = State.IDLE
var timer := 0.0
var climb := 0.0     # height up the trunk while climbing
var t := 0.0
var flip := false
var sprite: Sprite2D
var sit: Array = []
var chatter: Array = []
var run: Array = []
var climb_frames: Array = []

func setup(game, tree_at: Vector2, at: Vector2) -> void:
    main = game
    tree_pos = tree_at
    home = at
    position = at

func _ready() -> void:
    sit = Sprites.load_frames("squirrel", ["sit0", "sit1"])
    chatter = Sprites.load_frames("squirrel", ["chatter0", "chatter1"])
    run = Sprites.load_frames("squirrel", ["run0", "run1"])
    climb_frames = Sprites.load_frames("squirrel", ["climb0", "climb1"])
    sprite = Sprites.make("res://assets/sprites/squirrel/sit0.png", SCALE)
    Sprites.upright(self, 2.5).add_child(sprite)
    t = randf() * 10.0

# Stella wants it while it is running for the tree, climbing, or up in the branches.
func chasable() -> bool:
    return state == State.RUN or state == State.CLIMB or state == State.TREED

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    if global_position.distance_to(main.player.global_position) > main.NEAR_VIEW:
        return
    t += delta
    match state:
        State.IDLE:
            if global_position.distance_to(main.dog.global_position) < SPOOK_DOG \
                    or global_position.distance_to(main.player.global_position) < SPOOK_NICOLE:
                state = State.RUN
                _face(_trunk() - global_position)
        State.RUN:
            var to_tree: Vector2 = _trunk() - global_position
            if to_tree.length() < 7.0:
                state = State.CLIMB
            else:
                _face(to_tree)
                position += to_tree.normalized() * minf(RUN_SPEED * delta, to_tree.length())
        State.CLIMB:
            climb += 70.0 * delta
            if climb > 34.0:
                state = State.TREED
                timer = TREED_TIME
                visible = true
        State.TREED:
            timer -= delta
            climb = 34.0
            if timer <= 0.0:
                state = State.AWAY
                timer = AWAY_TIME
        State.AWAY:
            timer -= delta
            if timer <= 0.0:
                state = State.IDLE
                climb = 0.0
                position = home
    _show()

# The spot at the foot of the trunk, on the near side, where it climbs.
func _trunk() -> Vector2:
    return tree_pos + Vector2(0.0, 7.0)

# Picks the frame for what it is doing: nibbling an acorn, running, climbing, or
# chattering down from the branches.
func _show() -> void:
    sprite.visible = state != State.AWAY
    sprite.flip_h = flip
    var hop: float = absf(sin(t * 18.0)) * 1.5 if state == State.RUN else 0.0
    sprite.position.y = -climb - hop
    match state:
        State.IDLE:
            sprite.texture = sit[int(t * 1.6) % 2]
        State.RUN:
            sprite.texture = run[int(t * 10.0) % 2]
        State.CLIMB:
            sprite.texture = climb_frames[int(t * 9.0) % 2]
        State.TREED:
            sprite.texture = chatter[int(t * 5.0) % 2]

func _face(dir: Vector2) -> void:
    var across: float = dir.x - dir.y
    if absf(across) > 0.35 * maxf(dir.length(), 0.001):
        flip = across < 0.0
