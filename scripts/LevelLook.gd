extends Node
# The look of a level: a colour grade over the whole world (a CanvasModulate), and a thin
# drifting fog (two layers of soft cloud sliding across the screen at different speeds, and
# a haze that thickens toward the far end of the view). Level 1 has neither, so it keeps its
# warm night; later levels are cold and misty. The rest of the look (dark windows, dead and
# flickering street lights) is decided where those are made, from the same level settings.

const Sprites := preload("res://scripts/Sprites.gd")

const FOG_TINT := Color(0.66, 0.80, 0.82)
const CLOUD_TEXELS := 128
const CLOUD_ALPHA := [0.10, 0.065]    # how strong each layer of cloud is at fog = 1
const CLOUD_SCALE := [5.0, 7.5]      # screen pixels per texel
const CLOUD_DRIFT := [Vector2(9.0, 3.0), Vector2(-5.0, 2.0)]  # texels' worth of slide per second, scaled
const CLOUD_PARALLAX := [0.30, 0.55] # how much of the camera's movement the cloud follows
const HAZE_ALPHA := 0.2

static var cloud_texture: Texture2D = null
static var haze_texture: Texture2D = null

var main
var fog := 0.0
var layer: CanvasLayer
var clouds: Array = []   # Sprite2D per layer
var haze: TextureRect
var t := 0.0

func setup(game) -> void:
    main = game
    var grade: Color = main.settings.grade
    if grade != Color.WHITE:
        var tint := CanvasModulate.new()
        tint.color = grade
        add_child(tint)
    fog = float(main.settings.fog)
    if fog <= 0.0:
        set_process(false)
        return
    layer = CanvasLayer.new()
    layer.layer = 1  # over the world, under the HUD (layer 2)
    add_child(layer)
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
    set_process(true)

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
    if layer == null:
        return
    t += delta
    var size: Vector2 = get_viewport().get_visible_rect().size
    var cam: Vector2 = Sprites.iso(main.focus)
    for i in clouds.size():
        var sp: Sprite2D = clouds[i]
        var s: float = CLOUD_SCALE[i]
        var offset: Vector2 = CLOUD_DRIFT[i] * t + cam * float(CLOUD_PARALLAX[i]) / s
        sp.region_rect = Rect2(offset, size / s + Vector2(2, 2))
        var breathe: float = 1.0 + 0.18 * sin(t * (0.23 + 0.07 * float(i)) + float(i) * 2.0)
        sp.modulate = Color(1, 1, 1, float(CLOUD_ALPHA[i]) * fog * breathe)
