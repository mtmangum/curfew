extends Node2D
# A found item lying on the pavement (see Items.gd): its picture bobbing over a pulsing ring in the item's colour.
# Walk over it to pick it up, if her hands are empty (she carries one at a time); if they are full it waits, with its
# ring dimmed. Like the pizza, it stays where it is, so she can come back for it. (LevelBuilder puts them about the
# streets; Main.collect_item takes one.)

const Sprites := preload("res://scripts/Sprites.gd")
const Items := preload("res://scripts/Items.gd")

const REACH := 14.0

var main
var kind := "treat"
var t := 0.0
var art: Node2D

class Art extends Node2D:
    var pickup

    func _draw() -> void:
        var bob: float = sin(pickup.t * 3.0) * 1.8
        var taken: bool = pickup.main != null and pickup.main.carried != ""
        Items.draw_icon(self, pickup.kind, Vector2(0.0, -16.0 + bob), 24.0, 0.55 if taken else 1.0)

func _ready() -> void:
    art = Art.new()
    art.pickup = self
    Sprites.upright(self, 4.0).add_child(art)
    t = randf() * TAU

func _process(delta: float) -> void:
    t += delta
    if main == null or main.state != "play":
        return
    var d: float = global_position.distance_to(main.player.global_position)
    if d > main.NEAR_VIEW:
        return
    art.queue_redraw()
    queue_redraw()
    if d < REACH and main.carried == "":
        main.collect_item(self)

func _draw() -> void:
    var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
    var col: Color = Items.info(kind).color
    var dim: float = 0.5 if (main != null and main.carried != "") else 1.0
    draw_arc(Vector2.ZERO, 11.0 + 2.0 * pulse, 0.0, TAU, 28, Color(col.r, col.g, col.b, (0.35 + 0.3 * pulse) * dim), 1.2)
