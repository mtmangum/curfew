extends Node2D
# A street steam vent. While venting, the cloud blocks sight lines and hides
# anyone standing in it. A short puff of warning comes just before it starts.

const Sprites := preload("res://scripts/Sprites.gd")

const ON_TIME := 4.0
const OFF_TIME := 3.5

const PUFFS := 16
const RISE := 54.0  # how high a puff climbs before it fades, in screen pixels
const TEXEL := 0.8  # size of one pixel of puff art, in screen pixels
const SIZES := [4, 6, 8, 10, 12, 14, 16, 18]  # puff radii in texels
const LIGHT := Color("f1f6fb")
const MID := Color("c3d1e2")
const DARK := Color("8e9fb8")

# Pixel-art puff discs shaded from the upper left, cached by radius.
static var puff_textures: Dictionary = {}

static func puff_texture(radius: int) -> Texture2D:
    if puff_textures.has(radius):
        return puff_textures[radius]
    var size: int = radius * 2 + 1
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var dx: float = float(x - radius)
            var dy: float = float(y - radius)
            if dx * dx + dy * dy > float(radius * radius) + 0.5:
                continue
            # Positive toward the lower right, away from the light.
            var shade: float = (dx * 0.55 + dy * 0.75) / float(radius)
            # Checkerboard dithering where the tones meet.
            shade += 0.07 if (x + y) % 2 == 0 else -0.07
            var c: Color = LIGHT
            if shade > 0.5:
                c = DARK
            elif shade > -0.05:
                c = MID
            img.set_pixel(x, y, c)
    var tex := ImageTexture.create_from_image(img)
    puff_textures[radius] = tex
    return tex

class Cloud extends Node2D:
    var vent
    # Per-puff constants: where on the footprint it starts, how it drifts, when.
    var spots: Array = []
    var drift: Array = []
    var offsets: Array = []

    func _setup() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = int(vent.global_position.x * 7.0 + vent.global_position.y * 13.0)
        for i in vent.PUFFS:
            var a: float = rng.randf() * TAU
            var d: float = sqrt(rng.randf()) * vent.radius * 0.5
            spots.append(Vector2.from_angle(a) * d)
            drift.append(Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 4.0)))
            offsets.append(float(i) / float(vent.PUFFS) + rng.randf_range(-0.02, 0.02))

    func _draw() -> void:
        if spots.is_empty():
            _setup()
        var amt: float = vent.amount
        if amt > 0.01:
            # Footprint mist on the ground: this is where you are hidden.
            draw_circle(Vector2.ZERO, vent.radius * 0.95, Color(0.8, 0.88, 0.96, 0.10 * amt))
            draw_circle(Vector2.ZERO, vent.radius * 0.6, Color(0.8, 0.88, 0.96, 0.08 * amt))
            draw_set_transform_matrix(Sprites.UP)
            var order: Array = []
            for i in vent.PUFFS:
                order.append([fposmod(vent.t * 0.32 + offsets[i], 1.0), i])
            # Oldest (highest, largest) puffs first so young ones sit in front.
            order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
            for o in order:
                var u: float = o[0]
                var i: int = o[1]
                var fade: float = sin(PI * pow(u, 0.7))
                var texels: float = lerpf(4.0, 18.0, pow(u, 0.8))
                var tex: Texture2D = vent.puff_texture(_nearest_size(texels))
                var base: Vector2 = Sprites.iso(spots[i])
                var pos: Vector2 = base + drift[i] * u + Vector2(0.0, -4.0 - u * vent.RISE)
                # Snap to the puff pixel grid so it keeps the pixel-art look.
                pos = (pos / vent.TEXEL).round() * vent.TEXEL
                var rect_size: Vector2 = tex.get_size() * vent.TEXEL
                draw_texture_rect(tex, Rect2(pos - rect_size * 0.5, rect_size), false,
                    Color(1, 1, 1, 0.78 * fade * amt))
        elif vent.hint:
            # A few small puffs just before the vent blows.
            draw_set_transform_matrix(Sprites.UP)
            for i in 3:
                var rise: float = fmod(vent.t * 14.0 + float(i) * 5.0, 14.0)
                var tex: Texture2D = vent.puff_texture(vent.SIZES[0])
                var rect_size: Vector2 = tex.get_size() * vent.TEXEL
                var pos := Vector2(float(i - 1) * 6.0, -3.0 - rise)
                pos = (pos / vent.TEXEL).round() * vent.TEXEL
                draw_texture_rect(tex, Rect2(pos - rect_size * 0.5, rect_size), false,
                    Color(1, 1, 1, 0.55 * (1.0 - rise / 14.0)))

    func _nearest_size(texels: float) -> int:
        var best: int = vent.SIZES[0]
        for s in vent.SIZES:
            if absf(float(s) - texels) < absf(float(best) - texels):
                best = s
        return best

var main
var radius := 46.0
var phase := 0.0
var t := 0.0
var active := false
var hint := false
var amount := 0.0
var cloud: Cloud
var hiss: AudioStreamPlayer

func _ready() -> void:
    t = phase
    cloud = Cloud.new()
    cloud.vent = self
    cloud.z_as_relative = false
    cloud.z_index = 3000
    add_child(cloud)
    hiss = AudioStreamPlayer.new()
    hiss.stream = load("res://assets/audio/steam_loop.wav")
    hiss.bus = "SFX"
    hiss.volume_db = -80.0
    add_child(hiss)

func _process(delta: float) -> void:
    t += delta
    var cyc: float = fmod(t, ON_TIME + OFF_TIME)
    active = cyc < ON_TIME
    hint = (not active) and cyc > ON_TIME + OFF_TIME - 1.0
    amount = move_toward(amount, 1.0 if active else 0.0, delta * 1.5)
    # The hiss swells as the vent blows and as Nicole gets close.
    if main != null and main.player != null:
        var near: float = clampf(1.0 - global_position.distance_to(main.player.global_position) / 200.0, 0.0, 1.0)
        var level: float = amount * near * near
        if level > 0.01:
            if not hiss.playing:
                hiss.play()
            hiss.volume_db = linear_to_db(level) - 10.0
        elif hiss.playing:
            hiss.stop()
    # Far-away vents keep time but aren't redrawn.
    if (amount > 0.0 or hint) and global_position.distance_squared_to(main.focus) < main.NEAR_VIEW * main.NEAR_VIEW:
        cloud.queue_redraw()

func _draw() -> void:
    # A flat grate set into the street.
    draw_rect(Rect2(-13, -13, 26, 26), Color(0.26, 0.28, 0.34))
    draw_rect(Rect2(-11, -11, 22, 22), Color(0.06, 0.07, 0.1))
    for i in 6:
        draw_rect(Rect2(-9 + i * 3.6, -11, 1.8, 22), Color(0.3, 0.32, 0.38))
