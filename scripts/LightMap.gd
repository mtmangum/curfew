extends Node
# The dark, from level 3 ("Lights Out"). A second, half-size picture of the world is painted nearly black
# (12% bright, a little blue) and then everything that gives light is added to it in soft pools: street
# lamps, burn barrels, the cops' torch beams, Nicole's own torch and a glow at her feet, the lit windows, the
# headlights and tail lights of the cars on the road, and the lit door of home. That picture is multiplied over the world, so a building shows only where something lights it, and a
# street light only partly lights the wall beside it. (Godot's own 2D lights draw the scene again for each
# light, which would be far too slow in the browser; this is one extra pass whatever the number of lights.)
# The HUD is above it, and the fog and rain below it. (Main owns one when the level is dark: `main.lightmap`.)

const Sprites := preload("res://scripts/Sprites.gd")

const TINT := Color(0.55, 0.62, 1.0)  # the colour of the dark; its brightness is 1 - the level's darkness
const NEAR := 900.0                   # lights this far from the camera are drawn
const LAMP_WARM := Color(1.0, 0.82, 0.5)
const FIRE_WARM := Color(1.0, 0.55, 0.2)
const TORCH_WARM := Color(1.0, 0.93, 0.75)
const FLASH_TINT := Color(0.78, 0.84, 1.0)  # what the dark brightens to in a flash of lightning
const FLASH_LIFT := 0.8                      # ...and how far it goes (1 would be as bright as day)
const LAMP_HEAD := 36.0               # how high a street lamp's light sits, in screen pixels

# The pool of light all of them are made from: white in the middle, fading smoothly to nothing.
static var _soft: Texture2D

static func soft_texture() -> Texture2D:
    if _soft == null:
        var size := 128
        var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
        for y in size:
            for x in size:
                var d: float = Vector2(float(x) + 0.5 - float(size) * 0.5, float(y) + 0.5 - float(size) * 0.5).length() / (float(size) * 0.5)
                var a: float = pow(clampf(1.0 - d, 0.0, 1.0), 1.6)
                img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
        _soft = ImageTexture.create_from_image(img)
    return _soft

class LightDraw extends Node2D:
    var map

    func _draw() -> void:
        var main = map.main
        var soft: Texture2D = map.soft_texture()
        # 1. pools on the ground (in the ground plane, so each is an ellipse on screen)
        for l in map.lights():
            var r: float = l.radius
            draw_texture_rect(soft, Rect2(l.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(l.color.r, l.color.g, l.color.b, l.strength))
        # torch beams: a fan from the torch, bright by it and fading with distance
        for beam in map.beams():
            var origin: Vector2 = beam.origin
            var pts: Array = beam.points
            var reach: float = beam.reach
            var col: Color = beam.color
            # Two rings between the torch and where the rays end, both fading to nothing at the beam's edges, so
            # its sides are soft (a plain fan from one point is bright right to its edge): brightest by the torch
            # and down the middle, and dimmer toward the far end.
            var n: int = pts.size()
            var inner: Array = []
            var in_a: Array = []
            var out_a: Array = []
            for i in n:
                var across: float = absf(2.0 * float(i) / float(n - 1) - 1.0)   # 0 down the middle, 1 at an edge
                var side: float = 1.0 - across * across
                var along: float = clampf(origin.distance_to(pts[i]) / reach, 0.0, 1.0)
                inner.append(origin + (pts[i] - origin) * 0.2)
                in_a.append(beam.strength * side * 0.9)
                out_a.append(beam.strength * side * (0.12 + 0.88 * (1.0 - along)))
            for i in range(n - 1):
                draw_primitive(PackedVector2Array([origin, inner[i], inner[i + 1]]),
                        PackedColorArray([Color(col.r, col.g, col.b, beam.strength), Color(col.r, col.g, col.b, in_a[i]), Color(col.r, col.g, col.b, in_a[i + 1])]), PackedVector2Array())
                draw_primitive(PackedVector2Array([inner[i], pts[i], pts[i + 1]]),
                        PackedColorArray([Color(col.r, col.g, col.b, in_a[i]), Color(col.r, col.g, col.b, out_a[i]), Color(col.r, col.g, col.b, out_a[i + 1])]), PackedVector2Array())
                draw_primitive(PackedVector2Array([inner[i], pts[i + 1], inner[i + 1]]),
                        PackedColorArray([Color(col.r, col.g, col.b, in_a[i]), Color(col.r, col.g, col.b, out_a[i + 1]), Color(col.r, col.g, col.b, in_a[i + 1])]), PackedVector2Array())
        # cars' headlights: a wide beam ahead of each moving car, bright by the bumper
        for car in map.car_lights():
            var h: Vector2 = car.heading
            var side: Vector2 = Vector2(-h.y, h.x) * float(car.spread) * 0.5
            var far: Vector2 = car.front + h * float(car.reach)
            var s: float = car.strength
            var warm := Color(1.0, 0.94, 0.68)
            draw_primitive(PackedVector2Array([car.front, far - side, far]),
                    PackedColorArray([Color(warm.r, warm.g, warm.b, s), Color(warm.r, warm.g, warm.b, 0.0), Color(warm.r, warm.g, warm.b, s * 0.22)]), PackedVector2Array())
            draw_primitive(PackedVector2Array([car.front, far, far + side]),
                    PackedColorArray([Color(warm.r, warm.g, warm.b, s), Color(warm.r, warm.g, warm.b, s * 0.22), Color(warm.r, warm.g, warm.b, 0.0)]), PackedVector2Array())
        # 2. things that light what stands up: a lamp's glow at the height of its head, the patches a torch
        # leaves on walls, and the lit door of home (in screen space, from the world's origin as the buildings are)
        draw_set_transform_matrix(Sprites.UP)
        for h in map.halos():
            var at: Vector2 = Sprites.iso(h.pos) + Vector2(0.0, -h.height)
            draw_texture_rect(soft, Rect2(at - Vector2(h.radius, h.radius), Vector2(h.radius, h.radius) * 2.0), false, Color(h.color.r, h.color.g, h.color.b, h.strength))
        for b in main.building_nodes:
            if b.floors <= 0 or b.rect.get_center().distance_to(main.focus) > map.NEAR + 400.0:
                continue
            # lit windows: a glow round each, in the colour of the level's window light
            var wl: Color = b.window_light
            for g in b.lit_glows():
                var gr: float = g[1] * 1.9
                draw_texture_rect(soft, Rect2(g[0] - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(wl.r, wl.g, wl.b, 0.6 if g[2] else 0.8))
            if b.spots == null or b.spots.strips.is_empty():
                continue
            var rc: Rect2 = b.rect
            for s in b.spots.strips:
                var south: bool = s[1] == "s"
                var o := Vector2(rc.position.x, rc.end.y) if south else Vector2(rc.end.x, rc.end.y)
                var along := Vector2.RIGHT if south else Vector2.UP
                for band in [[2.0, 24.0, 0.30], [5.0, 20.0, 0.34], [8.0, 16.0, 0.38]]:
                    Sprites.fill(self, b._quad(o, along, s[2], s[3], band[0], band[1]), Color(TORCH_WARM.r, TORCH_WARM.g, TORCH_WARM.b, band[2] * s[4]))

var main
var ambient := Color.BLACK   # the dark itself, before any lightning
var dark_rect: ColorRect
var viewport: SubViewport
var painter: Node2D
var view: TextureRect

func setup(game) -> void:
    main = game
    ambient = TINT * (1.0 - float(main.settings.darkness))
    ambient.a = 1.0
    viewport = SubViewport.new()
    viewport.size = _half_size()
    viewport.transparent_bg = false
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var floor_layer := CanvasLayer.new()  # the dark itself, under the lights (a canvas layer ignores the camera)
    floor_layer.layer = -5
    viewport.add_child(floor_layer)
    dark_rect = ColorRect.new()
    dark_rect.color = ambient
    dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    floor_layer.add_child(dark_rect)
    painter = LightDraw.new()
    painter.map = self
    var add := CanvasItemMaterial.new()
    add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    painter.material = add
    viewport.add_child(painter)
    var layer := CanvasLayer.new()  # over the fog (layer 1, made before this), under the HUD (layer 2)
    layer.layer = 1
    add_child(layer)
    view = TextureRect.new()
    view.texture = viewport.get_texture()
    view.set_anchors_preset(Control.PRESET_FULL_RECT)
    view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    view.stretch_mode = TextureRect.STRETCH_SCALE
    view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mul := CanvasItemMaterial.new()
    mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
    view.material = mul
    layer.add_child(view)

func _half_size() -> Vector2i:
    var s: Vector2 = get_viewport().get_visible_rect().size * 0.5
    return Vector2i(maxi(int(s.x), 64), maxi(int(s.y), 64))

func _process(_delta: float) -> void:
    var size: Vector2i = _half_size()
    if viewport.size != size:
        viewport.size = size
    # the same view of the world as the main one, at half size
    var t: Transform2D = get_viewport().canvas_transform
    viewport.canvas_transform = Transform2D(t.x * 0.5, t.y * 0.5, t.origin * 0.5)
    dark_rect.color = ambient_now()
    painter.queue_redraw()

# How bright the lightning is now, 0 to 1: the level's flash (LevelLook) is a white wash that peaks at 0.34 alpha.
func lightning() -> float:
    var look = main.look
    if look == null or look.flash == null:
        return 0.0
    return clampf(look.flash.color.a / 0.34, 0.0, 1.0)

# The dark, lifted toward cool white while a flash of lightning lasts, so the whole scene, buildings and all,
# shows for a moment.
func ambient_now() -> Color:
    return ambient.lerp(FLASH_TINT, lightning() * FLASH_LIFT)

# The pools of light on the ground near the camera: [{pos, radius, color, strength}], in world coordinates.
func lights() -> Array:
    var out: Array = []
    var focus: Vector2 = main.focus
    var near2: float = NEAR * NEAR
    for l in main.lamps:
        if l.global_position.distance_squared_to(focus) > near2:
            continue
        var k: float = l.brightness()
        if k > 0.02:
            out.append({"pos": l.global_position, "radius": l.radius * 1.7, "color": LAMP_WARM, "strength": k})
    for f in main.fires:
        if f.global_position.distance_squared_to(focus) > near2:
            continue
        var flick: float = 0.9 + 0.1 * sin(f.t * 13.0)
        out.append({"pos": f.global_position, "radius": f.radius * 1.5 * flick, "color": FIRE_WARM, "strength": 0.95})
    # cars on the road: a pool at the front and a red glow at the back
    for c in main.traffic:
        if c.global_position.distance_squared_to(focus) > near2 or c.modulate.a < 0.05 or absf(c.speed) < 1.0:
            continue
        out.append({"pos": c.global_position + c.heading * (c.LENGTH * 0.5), "radius": 26.0, "color": Color(1.0, 0.94, 0.68), "strength": 0.7 * c.modulate.a})
        out.append({"pos": c.global_position - c.heading * (c.LENGTH * 0.5), "radius": 13.0, "color": Color(1.0, 0.12, 0.08), "strength": 0.6 * c.modulate.a})
    # every cop is a light: a dim pool round him (red once he is after her), so he can be seen coming
    for c in main.cops:
        if c.global_position.distance_squared_to(focus) <= near2:
            var chasing: bool = c.state == c.State.CHASE
            out.append({"pos": c.global_position, "radius": 44.0 if chasing else 40.0, "color": Color(1.0, 0.45, 0.35) if chasing else TORCH_WARM, "strength": 0.5})
    # a little light at her feet, so she can always see her own step
    out.append({"pos": main.player.global_position, "radius": 34.0, "color": TORCH_WARM, "strength": 0.4})
    # the lit door of home
    if main.house.size != Vector2.ZERO and main.house.get_center().distance_squared_to(focus) < (near2 + 160000.0):
        out.append({"pos": Vector2(main.house.end.x - 100.0, main.house.end.y + 4.0), "radius": 70.0, "color": Color(1.0, 0.82, 0.35), "strength": 0.8})
    return out

# Glows at a height above the ground (a lamp's head, the door of home): [{pos, height, radius, color, strength}].
func halos() -> Array:
    var out: Array = []
    var focus: Vector2 = main.focus
    var near2: float = NEAR * NEAR
    for l in main.lamps:
        if l.global_position.distance_squared_to(focus) > near2:
            continue
        var k: float = l.brightness()
        if k > 0.02:
            out.append({"pos": l.global_position, "height": LAMP_HEAD, "radius": 38.0, "color": LAMP_WARM, "strength": 0.55 * k})
    # the lens of each cop's torch, a bright point you can see from far off (stowed when he is chasing)
    for c in main.cops:
        if c.global_position.distance_squared_to(focus) <= near2 and c.state != c.State.CHASE:
            out.append({"pos": c.global_position + c.hand_local(), "height": 14.8, "radius": 15.0, "color": TORCH_WARM, "strength": 1.0})
    if main.house.size != Vector2.ZERO and main.house.get_center().distance_squared_to(focus) < (near2 + 160000.0):
        out.append({"pos": Vector2(main.house.end.x - 100.0, main.house.end.y), "height": 14.0, "radius": 34.0, "color": Color(1.0, 0.82, 0.35), "strength": 0.85})
    return out

# The headlight beams of the cars on the road near the camera: [{front, heading, reach, spread, strength}].
func car_lights() -> Array:
    var out: Array = []
    var focus: Vector2 = main.focus
    for c in main.traffic:
        if c.global_position.distance_squared_to(focus) > NEAR * NEAR or c.modulate.a < 0.05 or absf(c.speed) < 1.0:
            continue
        out.append({"front": c.global_position + c.heading * (c.LENGTH * 0.5 - 2.0), "heading": c.heading, "reach": c.BEAM_REACH,
                "spread": c.BEAM_SPREAD, "strength": 0.9 * c.modulate.a})
    return out

# The torch beams in view: Nicole's (when it is on) and the cops': [{origin, points, reach, color, strength}], all in world coordinates.
func beams() -> Array:
    var out: Array = []
    var p = main.player
    if p.torch_on and p.torch_ground.size() > 1:
        out.append(_beam(p.global_position, p.torch_origin, p.torch_ground, p.TORCH_RANGE, TORCH_WARM, 0.95))
    var focus: Vector2 = main.focus
    for c in main.cops:
        if c.beam_ground.size() > 1 and c.global_position.distance_squared_to(focus) < NEAR * NEAR:
            out.append(_beam(c.global_position, c.beam_origin, c.beam_ground, c.RANGE, Color(1.0, 0.95, 0.7), 0.6))
    return out

func _beam(feet: Vector2, origin: Vector2, ground: PackedVector2Array, reach: float, color: Color, strength: float) -> Dictionary:
    var pts: Array = []
    for g in ground:
        pts.append(feet + g)
    return {"origin": feet + origin, "points": pts, "reach": reach, "color": color, "strength": strength}
