extends RefCounted
# A city tree grate: a square cast-iron plate in a steel frame, rings of short radial slots, a dark pit
# for the trunk. Drawn flat on the ground in world coordinates (the ground's isometric shear makes it a
# diamond), so Ground.TileGround draws one at every tree and the sprite gallery renders the same code.
# `half` is half the side: as big as the pavement round the tree allows (the kerb trees have only 9
# units), between MIN and MAX.

const MIN := 8.5
const MAX := 13.0
const FRAME := Color("5a647a")
const IRON := Color("353c4d")
const SLOT := Color("090b10")
const PIT := Color("0e0c09")

const Sprites := preload("res://scripts/Sprites.gd")

# The plate: the frame, the iron inside it and the pit the trunk comes up through (flat fills).
static func draw_plate(item: CanvasItem, c: Vector2, half: float) -> void:
    var h := Vector2(half, half)
    var inner := Vector2(half - 1.0, half - 1.0)
    item.draw_rect(Rect2(c - h, h * 2.0), FRAME)
    item.draw_rect(Rect2(c - inner, inner * 2.0), IRON)
    item.draw_rect(Rect2(c - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), PIT)
    Sprites.fill(item, PackedVector2Array([c + Vector2(0.0, -4.2), c + Vector2(4.2, 0.0), c + Vector2(0.0, 4.2), c + Vector2(-4.2, 0.0)]), PIT)

# The rings of short radial slots for a list of grates ([[centre, half], ...]), as one batched run of
# lines (alternate rings are staggered).
static func draw_slots(item: CanvasItem, grates: Array) -> void:
    var segs := PackedVector2Array()
    for g in grates:
        var c: Vector2 = g[0]
        var ring := 5.0
        var odd := false
        while ring < float(g[1]) - 1.2:
            var n: int = int(ring * 1.7) + 1
            for k in n:
                var d := Vector2.from_angle(TAU * (float(k) + (0.5 if odd else 0.0)) / float(n))
                segs.append(c + d * (ring - 0.9))
                segs.append(c + d * (ring + 0.9))
            ring += 2.2
            odd = not odd
    if not segs.is_empty():
        item.draw_multiline(segs, SLOT, 1.0)
