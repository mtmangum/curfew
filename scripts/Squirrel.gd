extends Node2D
# A squirrel at the foot of a tree. When Stella (or Nicole) comes near it bolts up the
# trunk and sits in the branches for a while; Stella wants it badly, and stands under
# the tree barking up at it until it settles (see Dog.gd). It is drawn in code.

const Sprites := preload("res://scripts/Sprites.gd")

enum State {IDLE, RUN, CLIMB, TREED, AWAY}

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
var art: Node2D

class Art extends Node2D:
    var sq

    func _draw() -> void:
        if sq.state == sq.State.AWAY:
            return
        var up: float = sq.climb
        var hop: float = absf(sin(sq.t * 18.0)) * 2.0 if sq.state == sq.State.RUN else 0.0
        var fx: float = -1.0 if sq.flip else 1.0
        var y: float = -3.0 - up - hop
        var fur := Color(0.58, 0.36, 0.2)
        var dark := Color(0.12, 0.07, 0.04)
        # tail: a big curl behind
        draw_circle(Vector2(-5.0 * fx, y - 5.0), 3.6, dark)
        draw_circle(Vector2(-5.0 * fx, y - 5.0), 2.7, Color(0.68, 0.45, 0.26))
        # body and head
        draw_circle(Vector2(0, y - 2.5), 3.4, dark)
        draw_circle(Vector2(0, y - 2.5), 2.6, fur)
        draw_circle(Vector2(3.0 * fx, y - 5.2), 2.5, dark)
        draw_circle(Vector2(3.0 * fx, y - 5.2), 1.8, fur)
        draw_rect(Rect2(3.0 * fx - 0.5, y - 5.9, 1.0, 1.0), Color(1, 1, 1))  # an eye
        # a nut in its paws while it is sitting at the foot of the tree
        if sq.state == sq.State.IDLE and int(sq.t * 2.0) % 3 != 0:
            draw_rect(Rect2(4.6 * fx - 0.8, y - 3.2, 1.6, 1.6), Color(0.85, 0.7, 0.4))

func setup(game, tree_at: Vector2, at: Vector2) -> void:
    main = game
    tree_pos = tree_at
    home = at
    position = at

func _ready() -> void:
    art = Art.new()
    art.sq = self
    Sprites.upright(self, 2.5).add_child(art)
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
    art.queue_redraw()

# The spot at the foot of the trunk, on the near side, where it climbs.
func _trunk() -> Vector2:
    return tree_pos + Vector2(0.0, 7.0)

func _face(dir: Vector2) -> void:
    var across: float = dir.x - dir.y
    if absf(across) > 0.35 * maxf(dir.length(), 0.001):
        flip = across < 0.0
