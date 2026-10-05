extends Node2D
# A box of donuts put down on the pavement (Items.gd, ItemEffects.gd). Cops that are patrolling or checking out a
# noise, and within LURE of it, come over (a "?" over their heads) and stop to eat for EAT_TIME each; one who is after
# her, or who can see her, ignores it. Gone when the cops have had it (FEEDS of them), or after LIFE seconds.

const Sprites := preload("res://scripts/Sprites.gd")
const Items := preload("res://scripts/Items.gd")

const LURE := 150.0
const REACH := 20.0
const EAT_TIME := 6.0
const FEEDS := 3
const LIFE := 25.0

var main
var life := LIFE
var fed: Array = []
var t := 0.0
var art: Node2D

class Art extends Node2D:
    func _draw() -> void:
        Items.draw_icon(self, "donut", Vector2(0.0, -7.0), 14.0)

func _ready() -> void:
    art = Art.new()
    Sprites.upright(self, 4.0).add_child(art)

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    life -= delta
    if life <= 0.0 or fed.size() >= FEEDS:
        queue_free()
        return
    for c in main.cops:
        if not is_instance_valid(c) or fed.has(c):
            continue
        if c.state == c.State.CHASE or c.seeing:
            continue
        var d: float = c.global_position.distance_to(global_position)
        if d <= REACH:
            c.eat(EAT_TIME)
            fed.append(c)
        elif d <= LURE:
            c.lure(global_position)

func _exit_tree() -> void:
    if main != null:
        main.donuts.erase(self)
