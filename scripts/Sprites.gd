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
