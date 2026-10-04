extends Node2D
# Where cops' torch beams land on a building's walls: soft warm patches on the south and east faces (the
# two the camera sees), so the light is seen to reach the wall instead of just stopping at its foot. A child
# of the Building, drawn right after it, so it fades with it and cars and people in front still cover it.
# Cops hand it strips each frame (Cop._update_beam): [owner id, face "s" or "e", u0, u1, strength].

const Sprites := preload("res://scripts/Sprites.gd")

var building
var strips: Array = []

# Replaces what cop `owner_id` is lighting here.
func set_strips(owner_id: int, new_strips: Array) -> void:
    clear_strips(owner_id)
    for s in new_strips:
        strips.append([owner_id, s[0], s[1], s[2], s[3]])
    queue_redraw()

func clear_strips(owner_id: int) -> void:
    var kept: Array = []
    for s in strips:
        if s[0] != owner_id:
            kept.append(s)
    if kept.size() != strips.size():
        strips = kept
        queue_redraw()

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    var r: Rect2 = building.rect
    for s in strips:
        var south: bool = s[1] == "s"
        var origin := Vector2(r.position.x, r.end.y) if south else Vector2(r.end.x, r.end.y)
        var along := Vector2.RIGHT if south else Vector2.UP
        var u0: float = s[2]
        var u1: float = s[3]
        var a: float = s[4]
        # a soft pool, brightest at torch height: three bands that add up
        for band in [[2.0, 24.0, 0.11], [5.0, 20.0, 0.13], [8.0, 16.0, 0.15]]:
            Sprites.fill(self, building._quad(origin, along, u0, u1, band[0], band[1]), Color(1.0, 0.95, 0.68, band[2] * a))
