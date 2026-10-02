extends RefCounted
# Helpers for the pixel-art sprites in assets/sprites. Sprites are anchored at
# bottom-center so a node's origin is where the character's feet are.

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
