extends RefCounted
# Helpers for the pixel-art sprites in assets/sprites, and for the isometric
# view. Game logic runs on a flat top-down plane; the viewport's canvas
# transform (set in Main.gd) shears that plane into an isometric one. Anything
# that should stand upright (sprites, bars, labels) hangs under an `upright`
# layer that cancels the shear. Sprites are anchored at bottom-center so a
# node's origin is where the character's feet are.

# Screen pixels per world unit along each ground axis (before camera zoom).
const ISO := 0.8
const ISO_X := Vector2(ISO, ISO * 0.5)
const ISO_Y := Vector2(-ISO, ISO * 0.5)
# Inverse of the ground shear: draws in this transform's space are plain screen
# offsets from the node's origin.
const UP := Transform2D(Vector2(0.5 / ISO, -0.5 / ISO), Vector2(1.0 / ISO, 1.0 / ISO), Vector2.ZERO)

# A world-plane vector as a screen offset.
static func iso(p: Vector2) -> Vector2:
    return Vector2((p.x - p.y) * ISO, (p.x + p.y) * ISO * 0.5)

# A world point at some height above the ground, as a screen offset.
static func proj(p: Vector2, z: float = 0.0) -> Vector2:
    return iso(p) + Vector2(0.0, -z)

# Maps a screen-relative direction (right/down/...) onto the ground plane.
static func ground_dir(screen: Vector2) -> Vector2:
    return screen.x * Vector2(1, -1) + screen.y * Vector2(1, 1)

# True if a ground-plane direction points toward the left of the screen.
static func faces_left(dir: Vector2) -> bool:
    return dir.x - dir.y < 0.0

# A filled convex polygon, drawn so that Godot can batch it. `draw_colored_polygon` costs one draw
# call each (400 of them are 400 calls); triangles and quads drawn with `draw_primitive` merge
# into a few calls however many there are. Anything with more corners goes the old way.
static func fill(item: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
    var n: int = pts.size()
    if n == 4:
        item.draw_primitive(pts, PackedColorArray([color, color, color, color]), PackedVector2Array())
    elif n == 3:
        item.draw_primitive(pts, PackedColorArray([color, color, color]), PackedVector2Array())
    else:
        item.draw_colored_polygon(pts, color)

# An outline drawn as four lines: `draw_rect(r, c, false, w)` costs a draw call each, but lines
# (like filled rects) batch, as long as the fills are drawn together and the lines together.
static func outline(item: CanvasItem, r: Rect2, color: Color, width: float) -> void:
    var h: float = width * 0.5
    item.draw_line(Vector2(r.position.x - h, r.position.y), Vector2(r.end.x + h, r.position.y), color, width)
    item.draw_line(Vector2(r.position.x - h, r.end.y), Vector2(r.end.x + h, r.end.y), color, width)
    item.draw_line(Vector2(r.position.x, r.position.y - h), Vector2(r.position.x, r.end.y + h), color, width)
    item.draw_line(Vector2(r.end.x, r.position.y - h), Vector2(r.end.x, r.end.y + h), color, width)

# A line through several points, drawn as one batched `draw_multiline` (draw_polyline costs a draw
# call each).
static func polyline(item: CanvasItem, pts: PackedVector2Array, color: Color, width: float = 1.0) -> void:
    var segments := PackedVector2Array()
    for i in range(pts.size() - 1):
        segments.append(pts[i])
        segments.append(pts[i + 1])
    item.draw_multiline(segments, color, width)

# Discs and ellipses (blooms, puddles, bushes, dots) drawn from one soft-edged white disc texture,
# so they batch: draw_circle costs a draw call each, while textured rects that share a texture
# merge into a few. `at` is the centre, the colour tints the white disc.
static var disc_tex: Texture2D = null

static func disc_texture() -> Texture2D:
    if disc_tex == null:
        var size := 64
        var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
        for y in size:
            for x in size:
                var d: float = Vector2(float(x) + 0.5 - float(size) * 0.5, float(y) + 0.5 - float(size) * 0.5).length()
                img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(float(size) * 0.5 - d, 0.0, 1.0)))
        disc_tex = ImageTexture.create_from_image(img)
    return disc_tex

static func ellipse(item: CanvasItem, at: Vector2, rx: float, ry: float, color: Color) -> void:
    item.draw_texture_rect(disc_texture(), Rect2(at - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), false, color)

static func disc(item: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
    ellipse(item, at, radius, radius, color)

class Shadow extends Node2D:
    var radius := 6.0

    func _draw() -> void:
        # Drawn on the ground plane, so the shear turns the circle into an ellipse.
        draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.35))

# Adds a soft ground shadow (optional) and returns a layer to parent sprites
# and other upright drawing to.
static func upright(parent: Node2D, shadow: float = 0.0) -> Node2D:
    if shadow > 0.0:
        var sh := Shadow.new()
        sh.radius = shadow
        parent.add_child(sh)
    var layer := Node2D.new()
    layer.transform = UP
    parent.add_child(layer)
    return layer

static func load_tex(path: String) -> Texture2D:
    return load(path) as Texture2D

static func load_frames(dir: String, names: Array) -> Array:
    var out: Array = []
    for n in names:
        out.append(load_tex("res://assets/sprites/%s/%s.png" % [dir, n]))
    return out

static func set_tex(sp: Sprite2D, t: Texture2D) -> void:
    if t == null:
        return
    sp.texture = t
    var size: Vector2 = t.get_size()
    sp.offset = Vector2(-size.x * 0.5, -size.y)

static func make(path: String, s: float) -> Sprite2D:
    var sp := Sprite2D.new()
    sp.centered = false
    sp.scale = Vector2(s, s)
    set_tex(sp, load_tex(path))
    return sp
