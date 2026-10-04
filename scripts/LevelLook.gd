extends Node
# The look of a level: a colour grade over the whole world (a CanvasModulate), a thin
# drifting fog (two layers of soft cloud sliding across the screen at different speeds, and
# a haze that thickens toward the far end of the view), and from level 3 rain (streaks and
# splashes over the screen, and now and then lightning with thunder a moment behind it). From
# level 2 a far-off siren sounds every so often. Level 1 has none of it, so it keeps its warm
# night. The rest of the look (dark windows, dead and flickering street lights, puddles, boarded
# windows) is decided where those are made, from the same level settings.

const Sprites := preload("res://scripts/Sprites.gd")

const FOG_TINT := Color(0.66, 0.80, 0.82)
const CLOUD_TEXELS := 128
const CLOUD_ALPHA := [0.10, 0.065]    # how strong each layer of cloud is at fog = 1
const CLOUD_SCALE := [5.0, 7.5]      # screen pixels per texel
const CLOUD_DRIFT := [Vector2(9.0, 3.0), Vector2(-5.0, 2.0)]  # texels' worth of slide per second, scaled
const CLOUD_PARALLAX := [0.30, 0.55] # how much of the camera's movement the cloud follows
const HAZE_ALPHA := 0.2

const RAIN_STREAKS := 150
const RAIN_COLOR := Color(0.78, 0.88, 0.98)

# Rain over the screen: slanting streaks that fall and wrap, and tiny splashes low down.
class Rain extends Node2D:
    var amount := 1.0
    var size := Vector2(1280, 720)
    var streaks: Array = []   # [x, y, length, speed, alpha]
    var splashes: Array = []  # [x, y, age]
    var rng := RandomNumberGenerator.new()

    func _ready() -> void:
        rng.randomize()
        for i in int(RAIN_STREAKS * amount):
            streaks.append(_streak(true))

    func _streak(anywhere: bool) -> Array:
        return [rng.randf() * (size.x + 200.0), (rng.randf() * size.y) if anywhere else -30.0,
            rng.randf_range(9.0, 20.0), rng.randf_range(620.0, 980.0), rng.randf_range(0.14, 0.38)]

    func tick(delta: float, view: Vector2) -> void:
        size = view
        for s in streaks:
            s[1] += s[3] * delta
            s[0] -= s[3] * delta * 0.22
            if s[1] > size.y + 20.0 or s[0] < -30.0:
                var fresh: Array = _streak(false)
                s[0] = fresh[0]
                s[1] = fresh[1]
                s[2] = fresh[2]
                s[3] = fresh[3]
                s[4] = fresh[4]
        # splashes: a few new ones a frame, low on the screen where the ground is
        if rng.randf() < 0.9 * amount:
            splashes.append([rng.randf() * size.x, size.y * rng.randf_range(0.35, 1.0), 0.0])
        for sp in splashes:
            sp[2] += delta
        splashes = splashes.filter(func(sp): return sp[2] < 0.32)
        queue_redraw()

    func _draw() -> void:
        for s in streaks:
            draw_line(Vector2(s[0], s[1]), Vector2(s[0] - s[2] * 0.22, s[1] - s[2]), Color(RAIN_COLOR.r, RAIN_COLOR.g, RAIN_COLOR.b, s[4]), 1.0)
        for sp in splashes:
            var k: float = sp[2] / 0.32
            draw_set_transform(Vector2(sp[0], sp[1]), 0.0, Vector2(1.0, 0.4))
            draw_arc(Vector2.ZERO, 1.5 + 5.0 * k, 0.0, TAU, 10, Color(RAIN_COLOR.r, RAIN_COLOR.g, RAIN_COLOR.b, 0.35 * (1.0 - k)), 1.0)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static var cloud_texture: Texture2D = null
static var haze_texture: Texture2D = null

var main
var fog := 0.0
var layer: CanvasLayer
var clouds: Array = []   # Sprite2D per layer
var haze: TextureRect
var rain: Rain
var flash: ColorRect
var flash_tween: Tween
var t := 0.0
var thunder_in := -1.0   # seconds until the thunder that follows a flash
var next_storm := 0.0    # seconds until the next lightning
var next_siren := 0.0    # seconds until the next far-off siren

func setup(game) -> void:
    main = game
    var grade: Color = main.settings.grade
    if grade != Color.WHITE:
        var tint := CanvasModulate.new()
        tint.color = grade
        add_child(tint)
    fog = float(main.settings.fog)
    var rain_amount := float(main.settings.rain)
    next_storm = randf_range(8.0, 20.0)
    next_siren = randf_range(15.0, 40.0)
    if fog <= 0.0 and rain_amount <= 0.0:
        set_process(main.settings.sirens)
        return
    layer = CanvasLayer.new()
    layer.layer = 1  # over the world, under the HUD (layer 2)
    add_child(layer)
    if rain_amount > 0.0:
        flash = ColorRect.new()
        flash.set_anchors_preset(Control.PRESET_FULL_RECT)
        flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
        flash.color = Color(0.85, 0.92, 1.0, 0.0)
        layer.add_child(flash)
        rain = Rain.new()
        rain.amount = rain_amount
        layer.add_child(rain)
    if fog > 0.0:
        _make_fog()
    set_process(true)

func _make_fog() -> void:
    haze = TextureRect.new()
    haze.texture = get_haze_texture()
    haze.set_anchors_preset(Control.PRESET_FULL_RECT)
    haze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    haze.stretch_mode = TextureRect.STRETCH_SCALE
    haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
    haze.modulate = Color(1, 1, 1, clampf(fog, 0.0, 1.5))
    layer.add_child(haze)
    for i in 2:
        var sp := Sprite2D.new()
        sp.texture = get_cloud_texture()
        sp.centered = false
        sp.region_enabled = true
        sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
        sp.scale = Vector2.ONE * float(CLOUD_SCALE[i])
        layer.add_child(sp)
        clouds.append(sp)

# Lightning now and then with the thunder a beat behind it, and a far-off siren every so often.
func _weather(delta: float) -> void:
    if rain != null:
        next_storm -= delta
        if next_storm <= 0.0:
            next_storm = randf_range(18.0, 45.0)
            _lightning()
        if thunder_in >= 0.0:
            thunder_in -= delta
            if thunder_in < 0.0:
                main.play("thunder", -4.0, randf_range(0.9, 1.05))
    if main.settings.sirens:
        next_siren -= delta
        if next_siren <= 0.0:
            next_siren = randf_range(30.0, 70.0)
            main.play("siren_far", -9.0, randf_range(0.92, 1.06))

# A double flash across the whole screen; the thunder follows in a second or two.
func _lightning() -> void:
    if flash == null:
        return
    if flash_tween != null:
        flash_tween.kill()
    flash_tween = create_tween()
    flash_tween.tween_property(flash, "color:a", 0.34, 0.05)
    flash_tween.tween_property(flash, "color:a", 0.05, 0.08)
    flash_tween.tween_property(flash, "color:a", 0.26, 0.04)
    flash_tween.tween_property(flash, "color:a", 0.0, 0.35)
    thunder_in = randf_range(0.6, 2.2)

# A seamless soft cloud: smooth noise with the low values cut away, tinted and left transparent.
static func get_cloud_texture() -> Texture2D:
    if cloud_texture != null:
        return cloud_texture
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.016
    noise.fractal_octaves = 3
    noise.seed = 11
    var src: Image = noise.get_seamless_image(CLOUD_TEXELS, CLOUD_TEXELS, false, false, 0.2, true)
    var img := Image.create(CLOUD_TEXELS, CLOUD_TEXELS, false, Image.FORMAT_RGBA8)
    for y in CLOUD_TEXELS:
        for x in CLOUD_TEXELS:
            var v: float = src.get_pixel(x, y).r
            img.set_pixel(x, y, Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b, smoothstep(0.38, 0.9, v)))
    cloud_texture = ImageTexture.create_from_image(img)
    return cloud_texture

# Thickest at the top of the screen (the far end of the street) and clear by the middle.
static func get_haze_texture() -> Texture2D:
    if haze_texture != null:
        return haze_texture
    var img := Image.create(1, 48, false, Image.FORMAT_RGBA8)
    for y in 48:
        var k: float = clampf(1.0 - float(y) / 30.0, 0.0, 1.0)
        img.set_pixel(0, y, Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b, HAZE_ALPHA * pow(k, 1.6)))
    haze_texture = ImageTexture.create_from_image(img)
    return haze_texture

func _process(delta: float) -> void:
    t += delta
    if main.state == "play":
        _weather(delta)
    if layer == null:
        return
    var size: Vector2 = get_viewport().get_visible_rect().size
    if rain != null:
        rain.tick(delta, size)
    if clouds.is_empty():
        return
    var cam: Vector2 = Sprites.iso(main.focus)
    for i in clouds.size():
        var sp: Sprite2D = clouds[i]
        var s: float = CLOUD_SCALE[i]
        var offset: Vector2 = CLOUD_DRIFT[i] * t + cam * float(CLOUD_PARALLAX[i]) / s
        sp.region_rect = Rect2(offset, size / s + Vector2(2, 2))
        var breathe: float = 1.0 + 0.18 * sin(t * (0.23 + 0.07 * float(i)) + float(i) * 2.0)
        sp.modulate = Color(1, 1, 1, float(CLOUD_ALPHA[i]) * fog * breathe)
