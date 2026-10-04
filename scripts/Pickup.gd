extends Node2D
# A slice of pizza on the pavement: walk over it to get some life back. It is left
# where it is while Nicole's life is full, so she can come back for it. The faint
# ring on the ground makes it easy to spot at night.

const Sprites := preload("res://scripts/Sprites.gd")

const REACH := 13.0

var main
var t := 0.0
var art: Node2D

class Art extends Node2D:
    var pickup

    func _draw() -> void:
        var bob: float = sin(pickup.t * 3.0) * 1.8
        var y: float = -14.0 + bob
        var dark := Color(0.16, 0.08, 0.04)
        # the slice: a wedge pointing down, crust along the top
        Sprites.fill(self, PackedVector2Array([Vector2(-8.5, y - 6.5), Vector2(8.5, y - 6.5), Vector2(0, y + 8.5)]), dark)
        Sprites.fill(self, PackedVector2Array([Vector2(-7, y - 5), Vector2(7, y - 5), Vector2(0, y + 6.5)]), Color(0.98, 0.8, 0.28))
        draw_rect(Rect2(-8.5, y - 8.0, 17.0, 3.5), Color(0.8, 0.5, 0.2))
        draw_rect(Rect2(-8.5, y - 8.0, 17.0, 1.2), Color(0.95, 0.7, 0.35))
        for d in [Vector2(-3, y - 1.5), Vector2(3, y - 2), Vector2(0, y + 2.8)]:
            Sprites.disc(self, d, 1.7, Color(0.78, 0.18, 0.15))

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
    if d < REACH and not main.vitals.is_full():
        main.collect_pickup(self)

# A pulsing ring on the ground.
func _draw() -> void:
    var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
    draw_arc(Vector2.ZERO, 11.0 + 2.0 * pulse, 0.0, TAU, 28, Color(1.0, 0.85, 0.35, 0.35 + 0.3 * pulse), 1.2)
