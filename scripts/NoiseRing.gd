extends Node2D
# The picture of a sound that carries to the cops, kept quiet on purpose so it never competes
# with the game: two faint rings of small pale dots spreading out over the ground (as an
# isometric ellipse), each dashed and slowly turning, and a tiny puff of sound-waves over
# the spot it came from. The outermost reach is `radius` world units:
# that is how far cops can hear it.

const Sprites := preload("res://scripts/Sprites.gd")

const LIFE := 0.8
const RINGS := 2
const STAGGER := 0.16
const STRENGTH := 0.32  # overall opacity: subtle

var radius := 100.0
var life := 0.0

func _process(delta: float) -> void:
    life += delta
    if life > LIFE:
        queue_free()
        return
    queue_redraw()

func _ground(angle: float, r: float) -> Vector2:
    return Sprites.iso(Vector2.from_angle(angle) * r)

func _dot(p: Vector2, size: float, col: Color) -> void:
    draw_rect(Rect2((p - Vector2(size, size) * 0.5).round(), Vector2(size, size)), col)

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)  # upright pixels, placed on the ground ellipse
    var span: float = LIFE - STAGGER * float(RINGS - 1)
    for i in RINGS:
        var k: float = clampf((life - STAGGER * float(i)) / span, 0.0, 1.0)
        if k <= 0.0:
            continue
        var ease_out: float = 1.0 - pow(1.0 - k, 2.2)
        var r: float = radius * (0.12 + 0.88 * ease_out)
        var fade: float = pow(1.0 - k, 1.3) * STRENGTH
        var count: int = clampi(int(r * 0.7), 16, 110)
        var spin: float = life * (0.9 if i % 2 == 0 else -0.9)
        # a thin continuous edge under the dots, so the wave reads as one ring
        var edge := PackedVector2Array()
        for j in range(count + 1):
            edge.append(_ground(TAU * float(j) / float(count), r))
        draw_polyline(edge, Color(1.0, 0.9, 0.55, 0.12 * fade), 1.0)
        for j in count:
            if j % 4 == 3:
                continue  # dashed
            var a: float = TAU * float(j) / float(count) + spin
            var p: Vector2 = _ground(a, r)
            var size: float = 1.8 if i == 0 else 1.4
            _dot(p, size, Color(1.0, 0.93, 0.62, 0.95 * fade))
    # a faint wash on the ground out to the leading ring
    var k0: float = clampf(life / span, 0.0, 1.0)
    var wash := PackedVector2Array()
    var wr: float = radius * (0.12 + 0.88 * (1.0 - pow(1.0 - k0, 2.2)))
    for j in 28:
        wash.append(_ground(TAU * float(j) / 28.0, wr))
    draw_colored_polygon(wash, Color(1.0, 0.9, 0.55, 0.025 * (1.0 - k0)))
    # sound waves over the source for a moment: ((  ))
    if life < 0.3:
        var f: float = (1.0 - life / 0.3) * 0.5
        var c := Vector2(0.0, -20.0 - life * 10.0)
        for w in 2:
            var rr: float = 3.0 + float(w) * 3.0
            var col := Color(1.0, 0.95, 0.7, f * (1.0 - float(w) * 0.35))
            for s in [-1.0, 1.0]:
                for t in 3:
                    var ang: float = (float(t) - 1.0) * 0.4
                    _dot(c + Vector2(cos(ang) * s, sin(ang)) * rr, 1.2, col)
