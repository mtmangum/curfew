extends Node2D
# The picture of a sound that carries to the cops, kept quiet on purpose so it never competes
# with the game: a smooth, thin ring spreading out over the ground (as an isometric ellipse)
# and fading as it goes, with a fainter one a moment behind and the barest wash inside. The
# outermost reach is `radius` world units: that is how far cops can hear it.

const Sprites := preload("res://scripts/Sprites.gd")

const LIFE := 0.85
const RINGS := 2
const STAGGER := 0.18
const STRENGTH := 0.2  # overall opacity: very subtle

var radius := 100.0
var life := 0.0

func _process(delta: float) -> void:
    life += delta
    if life > LIFE:
        queue_free()
        return
    queue_redraw()

func _ellipse(r: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    var n: int = clampi(int(r * 0.5), 24, 96)
    for j in range(n + 1):
        pts.append(Sprites.iso(Vector2.from_angle(TAU * float(j) / float(n)) * r))
    return pts

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)  # drawn on the ground ellipse
    var span: float = LIFE - STAGGER * float(RINGS - 1)
    for i in RINGS:
        var k: float = clampf((life - STAGGER * float(i)) / span, 0.0, 1.0)
        if k <= 0.0:
            continue
        var ease_out: float = 1.0 - pow(1.0 - k, 2.2)
        var r: float = radius * (0.12 + 0.88 * ease_out)
        var fade: float = pow(1.0 - k, 1.4) * STRENGTH * (1.0 if i == 0 else 0.55)
        var pts: PackedVector2Array = _ellipse(r)
        draw_polyline(pts, Color(1.0, 0.95, 0.75, 0.35 * fade), 3.0, true)  # a soft halo
        draw_polyline(pts, Color(1.0, 0.97, 0.85, fade), 1.2, true)           # the ring itself
