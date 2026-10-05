extends Node2D
# A phone booth on the pavement. Stand beside it for a few seconds and make a call: the map
# fills in around it (see MiniMap.phone_call). It does not say where home is.
# One call per booth. A bobbing cyan handset bubble above it says it still works; a ring on
# the ground fills while she stands there. Standing still is the cost: zombies drift in
# if she lingers, and the call is heard a short way off.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

const USE_TIME := 3.0
const REACH := 20.0

var main
var obj  # the booth drawn on the street (StreetObject): it goes dark once the call is used
var used := false
var t := 0.0      # how long she has been using it
var pulse := 0.0
var explain := false

func _ready() -> void:
    z_as_relative = false
    z_index = 3000  # the marker and ring sit on top of everything

func _process(delta: float) -> void:
    if main == null or main.state != "play" or used:
        return
    var d: float = global_position.distance_to(main.player.global_position)
    explain = d < 60.0 and main.los(global_position, main.player.global_position)
    if d > main.NEAR_VIEW:
        return
    pulse += delta
    if explain and main.audio.tension < 0.35 and main.player.stunned_t <= 0.0:
        main.clues.offer("phone")
    if d < REACH and not main.player.moving and main.player.stunned_t <= 0.0:
        t += delta
    else:
        t = maxf(0.0, t - 2.0 * delta)
    if t >= USE_TIME:
        used = true
        if obj != null:
            obj.working = false
            obj.queue_redraw()
        queue_redraw()
        main.use_phone(self)
        return
    queue_redraw()

func _draw() -> void:
    if used:
        return
    if t > 0.0:
        # a ring on the ground that fills as the call goes through
        draw_arc(Vector2.ZERO, 13.0, -PI / 2.0, -PI / 2.0 + TAU * t / USE_TIME, 28, Color(0.5, 0.95, 1.0, 0.9), 2.0)
    draw_set_transform_matrix(Sprites.UP)
    var bob: float = sin(pulse * 3.5) * 2.0
    var c := Vector2(0.0, -66.0 + bob)
    var col := Color(0.45, 0.92, 1.0, 0.97)
    var ink := Color("0e1a30")
    # a speech-bubble with a handset in it, pointing down at the booth
    Sprites.disc(self, c, 8.2, Color(0, 0, 0, 0.75))
    Sprites.fill(self, PackedVector2Array([c + Vector2(-4.2, 5.0), c + Vector2(4.2, 5.0), c + Vector2(0, 11.4)]), Color(0, 0, 0, 0.75))
    Sprites.disc(self, c, 6.8, col)
    Sprites.fill(self, PackedVector2Array([c + Vector2(-3.2, 5.0), c + Vector2(3.2, 5.0), c + Vector2(0, 9.6)]), col)
    draw_arc(c + Vector2(0.0, 1.0), 3.5, PI, TAU, 10, ink, 1.8)
    draw_rect(Rect2(c + Vector2(-4.6, 0.8), Vector2(2.4, 3.6)), ink)
    draw_rect(Rect2(c + Vector2(2.2, 0.8), Vector2(2.4, 3.6)), ink)
    if explain:
        draw_string(Style.BODY_FONT, Vector2(-75, -82), "Stand still 3s", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
    draw_set_transform_matrix(Transform2D.IDENTITY)
