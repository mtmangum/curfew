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

# The light thrown on the road ahead of the headlights: a soft pool, brightest by the
# car and fading with distance, in the same dithered pixel style as the street lamps'
# pools. Built once, pointing along +x, and turned to the car's heading when drawn.
static var beam_texture: Texture2D = null
const BEAM_REACH := 120.0   # units ahead of the front bumper
const BEAM_SPREAD := 74.0   # width at the far end
const BEAM_TEXEL := 2.0

static func get_beam_texture() -> Texture2D:
    if beam_texture != null:
        return beam_texture
    var w: int = int(BEAM_REACH / BEAM_TEXEL)
    var h: int = int(BEAM_SPREAD / BEAM_TEXEL)
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    for y in h:
        for x in w:
            var u: float = (float(x) + 0.5) / float(w)               # 0 at the bumper, 1 at the far end
            var v: float = ((float(y) + 0.5) / float(h) - 0.5) * 2.0   # -1..1 across
            var half: float = 0.28 + 0.62 * u                          # the beam widens with distance
            if absf(v) >= half:
                continue
            var across: float = 1.0 - (absf(v) / half) * (absf(v) / half)
            var level: float = pow(1.0 - u, 1.3) * across * 6.0
            var stepped: float = floorf(level + (float(bayer[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0)
            if stepped <= 0.0:
                continue
            img.set_pixel(x, y, Color(1.0, 0.94, 0.68, 0.058 * stepped))
    beam_texture = ImageTexture.create_from_image(img)
    return beam_texture

class Beams extends Node2D:
    var car

    func _draw() -> void:
        # Drawn on the ground plane (the shear makes it a diamond-grid pool), turned
        # along the car's heading.
        draw_set_transform(Vector2.ZERO, car.heading.angle(), Vector2.ONE)
        var front: float = car.LENGTH * 0.5 - 2.0
        draw_texture_rect(car.get_beam_texture(), Rect2(front, -car.BEAM_SPREAD * 0.5, car.BEAM_REACH, car.BEAM_SPREAD), false)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var main
var heading := Vector2.RIGHT
var horizontal := true
var lane_a := 0.0  # the lane runs from this coordinate along its axis...
var lane_b := 0.0  # ...to this one
var speed := 120.0
var honk_cd := 0.0
var passing := false
var is_police := false  # a police car (PoliceCar.gd) is a Traffic that drives itself
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
    if rect.grow(5.0).has_point(main.player.global_position):
        main.run_over(self, false)
    elif rect.grow(4.0).has_point(main.dog.global_position):
        main.run_over(self, true)

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
