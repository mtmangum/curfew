extends Node2D
# A street light: a cast-iron post (plinth, banded shaft, curved arm) with a
# lantern at the top, a warm bloom around the glass, a faint shaft of light down
# to the road, and a soft pixel-dithered pool of light on the ground. The post is
# solid (a thin circle). Standing in the pool of light makes you easier to spot (see
# Main.in_light); some lamps flicker every few seconds, and the ground is dark while one is out.

const Sprites := preload("res://scripts/Sprites.gd")

const WARM := Color(1.0, 0.82, 0.45)
const GLASS := Color(1.0, 0.92, 0.6)
const POOL_TEXELS := 21  # radius of the light pool texture, in texels
const POOL_STEPS := 6    # brightness levels in the pool

# The pool of light: a radial falloff in a few dithered steps, so it reads as
# pixel art like everything else. Drawn on the ground plane, where the shear
# turns it into an ellipse.
static var pool_texture: Texture2D = null

static func get_pool_texture() -> Texture2D:
    if pool_texture != null:
        return pool_texture
    var size: int = POOL_TEXELS * 2 + 1
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    for y in size:
        for x in size:
            var d: float = Vector2(float(x - POOL_TEXELS), float(y - POOL_TEXELS)).length() / float(POOL_TEXELS)
            if d >= 1.0:
                continue
            var level: float = pow(1.0 - d, 1.5) * float(POOL_STEPS)
            var threshold: float = (float(bayer[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0
            var stepped: float = floorf(level + threshold)
            if stepped <= 0.0:
                continue
            img.set_pixel(x, y, Color(WARM.r, WARM.g, WARM.b, 0.075 * stepped))
    pool_texture = ImageTexture.create_from_image(img)
    return pool_texture

class Pool extends Node2D:
    var lamp

    func _draw() -> void:
        var r: float = lamp.radius
        draw_texture_rect(lamp.get_pool_texture(), Rect2(-r, -r, 2.0 * r, 2.0 * r), false, Color(1, 1, 1, lamp.brightness()))

class Post extends Node2D:
    var lamp

    # Drawn upright, with the foot at the origin. `side` is which way the arm
    # curves (+1 right, -1 left).
    func _draw() -> void:
        var k: float = lamp.brightness()
        var s: float = lamp.side
        var iron := Color("2d3342")
        var dark := Color("171a25")
        var rim := Color("5d6784")
        var head := Vector2(s * 10.0, -52.0)

        # A faint shaft of light from the lantern down to the pool.
        Sprites.fill(self, PackedVector2Array([
            head + Vector2(-4.0, 2.0), head + Vector2(4.0, 2.0), Vector2(s * 4.0 + 18.0, -3.0), Vector2(s * 4.0 - 18.0, -3.0)]),
            Color(WARM.r, WARM.g, WARM.b, 0.045 * k))

        # Plinth, shaft with bands, and a tapered collar under the arm.
        draw_rect(Rect2(-3.5, -2.0, 7.0, 2.0), dark)
        draw_rect(Rect2(-2.5, -5.0, 5.0, 3.0), iron)
        draw_rect(Rect2(-2.5, -5.0, 1.0, 3.0), rim)
        draw_rect(Rect2(-1.5, -43.0, 3.0, 38.0), iron)
        draw_rect(Rect2(-1.5, -43.0, 1.0, 38.0), rim)
        for band in [-9.0, -25.0, -40.0]:
            draw_rect(Rect2(-2.3, band, 4.6, 1.6), dark)
            draw_rect(Rect2(-2.3, band, 4.6, 0.6), rim)
        draw_rect(Rect2(-2.2, -45.0, 4.4, 3.0), iron)

        # The curved arm up and out to the lantern.
        Sprites.polyline(self, PackedVector2Array([
            Vector2(0.0, -44.0), Vector2(s * 1.2, -49.0), Vector2(s * 3.8, -52.0), Vector2(s * 7.0, -53.0)]), iron, 2.0)
        Sprites.polyline(self, PackedVector2Array([
            Vector2(0.0 - s * 0.4, -44.0), Vector2(s * 0.8, -49.0), Vector2(s * 3.4, -52.6), Vector2(s * 7.0, -53.6)]), rim, 0.8)

        # The lantern: a pointed cap, glass, a dark frame and an underside.
        Sprites.fill(self, PackedVector2Array([
            head + Vector2(-6.5, -3.0), head + Vector2(6.5, -3.0), head + Vector2(3.5, -6.5), head + Vector2(-3.5, -6.5)]), dark)
        Sprites.fill(self, PackedVector2Array([
            head + Vector2(-5.5, -3.2), head + Vector2(5.5, -3.2), head + Vector2(3.2, -6.0), head + Vector2(-3.2, -6.0)]), iron)
        draw_rect(Rect2(head.x - 0.8, head.y - 8.5, 1.6, 2.4), dark)
        draw_rect(Rect2(head.x - 4.6, head.y - 3.0, 9.2, 4.6), dark)
        draw_rect(Rect2(head.x - 3.8, head.y - 2.4, 7.6, 3.4), Color(GLASS.r, GLASS.g, GLASS.b, 0.35 + 0.65 * k))
        draw_rect(Rect2(head.x - 2.4, head.y - 1.8, 4.8, 2.0), Color(1.0, 0.98, 0.82, k))
        draw_rect(Rect2(head.x - 0.4, head.y - 2.4, 0.8, 3.4), Color(dark.r, dark.g, dark.b, 0.7))
        draw_rect(Rect2(head.x - 5.0, head.y + 1.6, 10.0, 1.4), dark)

        # Bloom around the glass.
        var c: Vector2 = head + Vector2(0.0, -0.8)
        Sprites.disc(self, c, 15.0, Color(WARM.r, WARM.g, WARM.b, 0.05 * k))
        Sprites.disc(self, c, 10.0, Color(WARM.r, WARM.g, WARM.b, 0.09 * k))
        Sprites.disc(self, c, 6.0, Color(WARM.r, WARM.g, WARM.b, 0.16 * k))

var main
var radius := 56.0  # reach of the pool of light on the ground (and of being seen in it)
var body_radius := 3.0  # the post itself is solid
var flicker := false
var dead := false  # a blackout: dark, and lights nothing
var side := 1.0  # which way the arm curves
var t := 0.0
var period := 5.0       # seconds between one flicker and the next
var seed_phase := 0.0
var pool: Pool
var post: Post

func _ready() -> void:
    pool = Pool.new()
    pool.lamp = self
    pool.z_as_relative = false
    pool.z_index = -35
    add_child(pool)
    post = Post.new()
    post.lamp = self
    Sprites.upright(self, 3.0).add_child(post)
    set_process(flicker)
    t = randf() * 10.0
    period = randf_range(3.5, 7.5)
    seed_phase = randf() * TAU

# Is this ground lit by the lamp right now? A lamp in the middle of a flicker is dark.
func lights(p: Vector2) -> bool:
    return brightness() > 0.6 and p.distance_squared_to(global_position) < radius * radius

# 1 normally; a dead lamp is 0. A flickering lamp is steady most of the time and then, every few
# seconds, stutters for about a second: it drops out, comes back, drops again, and sometimes goes
# out for a beat.
func brightness() -> float:
    if dead:
        return 0.0
    if not flicker:
        return 1.0
    var phase: float = fposmod(t, period)
    if phase > 1.1:
        return 1.0
    var stutter: float = sin(phase * 47.0 + seed_phase) * sin(phase * 19.0)
    if phase > 0.55 and phase < 0.7:
        return 0.0
    return 0.2 if stutter > 0.15 else 1.0

func _process(delta: float) -> void:
    t += delta
    # Only redraw while on screen.
    if main != null and global_position.distance_squared_to(main.focus) < main.NEAR_VIEW * main.NEAR_VIEW:
        pool.queue_redraw()
        post.queue_redraw()
