extends Node2D
# The blades of a rooftop air-conditioning fan, turning slowly. A roof is drawn once and kept, so each
# fan that spins is its own tiny piece that redraws only itself a dozen times a second (and not at all
# while it is far from the action: see ActivityGate). It is a child of its building, so it draws on
# top of the roof and fades with the building. (Roofs.gd decides which units spin and draws the rest
# of the unit; the static ones keep their spokes in the roof's own drawing.)

const Sprites := preload("res://scripts/Sprites.gd")

const STEP := 0.08  # seconds between redraws (about 12 a second: plenty for a slow turn)

var top_z := 0.0     # the screen height of the top of the unit
var radius := 6.0    # how long the spokes are, on the ground plane
var rate := 1.0      # radians a second
var angle := 0.0
var since := 0.0

func _process(delta: float) -> void:
    angle += delta * rate
    since += delta
    if since >= STEP:
        since = 0.0
        queue_redraw()

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    var centre := Vector2(0.0, -top_z)
    for k in 4:
        var a: float = angle + float(k) * PI * 0.5
        draw_line(centre, centre + Sprites.iso(Vector2(cos(a), sin(a)) * radius), Color("6c7380"), 1.0)
