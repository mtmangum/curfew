extends "res://scripts/Car.gd"
# A car driving up and down a road. If it hits Nicole or Stella the run is over, so
# the player has to watch for headlights and pick a moment to cross. It honks when
# she is in its way (which cops hear), whooshes past, and fades in and out at the
# ends of its stretch of road rather than popping.

const LENGTH := 40.0
const WIDTH := 20.0
const FAR := 1350.0       # cars farther than this from Nicole stand still and cost nothing
const FADE := 70.0        # distance over which it fades in and out at the ends of its road
const HONK_RANGE := 130.0

# Two soft cones of light on the road ahead of the headlights.
class Beams extends Node2D:
    var car

    func _draw() -> void:
        var d: Vector2 = car.heading
        var side: Vector2 = d.orthogonal()
        var front: Vector2 = d * (LENGTH * 0.5)
        var reach: Vector2 = d * 120.0
        draw_colored_polygon(PackedVector2Array([
            front + side * 8.0, front - side * 8.0, front + reach - side * 26.0, front + reach + side * 26.0]),
            Color(1.0, 0.95, 0.65, 0.10))
        draw_colored_polygon(PackedVector2Array([
            front + side * 5.0, front - side * 5.0, front + reach * 0.55 - side * 12.0, front + reach * 0.55 + side * 12.0]),
            Color(1.0, 0.97, 0.75, 0.10))

var main
var heading := Vector2.RIGHT
var horizontal := true
var lane_a := 0.0  # the lane runs from this coordinate along its axis...
var lane_b := 0.0  # ...to this one
var speed := 120.0
var honk_cd := 0.0
var passing := false
var beams: Beams

func setup_traffic(game, is_horizontal: bool, fixed: float, a: float, b: float, dir: int, spd: float, color_i: int, start_t: float, seed_value: int) -> void:
    main = game
    horizontal = is_horizontal
    lane_a = a
    lane_b = b
    speed = spd
    heading = Vector2(float(dir), 0.0) if horizontal else Vector2(0.0, float(dir))
    var size := Vector2(LENGTH, WIDTH) if horizontal else Vector2(WIDTH, LENGTH)
    var along: float = lerpf(a, b, start_t)
    var centre: Vector2 = Vector2(along, fixed) if horizontal else Vector2(fixed, along)
    setup_car(Rect2(centre - size * 0.5, size), color_i, dir, seed_value)
    local_rect = Rect2(-size * 0.5, size)
    use_local = true
    position = centre

func _ready() -> void:
    super._ready()
    beams = Beams.new()
    beams.car = self
    beams.z_as_relative = false
    beams.z_index = -34
    add_child(beams)

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    var pp: Vector2 = main.player.global_position
    if global_position.distance_squared_to(pp) > FAR * FAR:
        return
    honk_cd = maxf(0.0, honk_cd - delta)
    position += heading * speed * delta
    var along: float = position.x if horizontal else position.y
    var forward: bool = (heading.x + heading.y) > 0.0
    if forward and along > lane_b:
        along = lane_a
    elif (not forward) and along < lane_a:
        along = lane_b
    if horizontal:
        position.x = along
    else:
        position.y = along
    rect = Rect2(position + local_rect.position, local_rect.size)
    update_screen_box()
    modulate.a = clampf(minf(along - lane_a, lane_b - along) / FADE, 0.0, 1.0)
    if modulate.a > 0.5:
        _check_hit()
    _warn(pp)

func _check_hit() -> void:
    if rect.grow(5.0).has_point(main.player.global_position) or rect.grow(4.0).has_point(main.dog.global_position):
        main.run_over(self)

# Honk when Nicole is in the road ahead, and whoosh as the car goes by.
func _warn(pp: Vector2) -> void:
    var to_her: Vector2 = pp - position
    var ahead: float = to_her.dot(heading)
    var off: float = absf(to_her.dot(heading.orthogonal()))
    if honk_cd <= 0.0 and ahead > 20.0 and ahead < HONK_RANGE and off < 30.0:
        honk_cd = 3.0
        main.play_at("honk", position, 0.0, 700.0)
        main.noise(position, 240.0, true)  # cops hear a horn
    var near: bool = to_her.length() < 70.0
    if near and not passing:
        passing = true
        main.play_at("car_pass", position, -2.0, 400.0)
    elif passing and to_her.length() > 170.0:
        passing = false
