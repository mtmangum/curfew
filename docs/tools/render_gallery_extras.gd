extends SceneTree
# Exact game drawing code, rendered to transparent PNGs for the web gallery (the code-drawn pieces that
# are not pixel-art sprites): tree grates, shop windows and their neon OPEN signs, the clue pictures,
# Stella's thought bubble and a cop's "?" and "!". Needs a window (not --headless):
#   godot --path . --rendering-method gl_compatibility --script docs/tools/render_gallery_extras.gd
# then python3 docs/tools/build_sprite_gallery.py to refresh the manifest.
# (The rooftop pieces have their own, render_rooftop_gallery.gd.)
const Sprites = preload("res://scripts/Sprites.gd")
const Style = preload("res://scripts/Style.gd")
const Grate = preload("res://scripts/Grate.gd")
const ShopWindows = preload("res://scripts/ShopWindows.gd")
const NeonSign = preload("res://scripts/NeonSign.gd")
const Cop = preload("res://scripts/Cop.gd")
const Ground = preload("res://scripts/Ground.gd")
const Items = preload("res://scripts/Items.gd")

const WALL := Color("2a2d42")   # a slate wall, the first of the building palettes
const WINDOW_LIGHT := Color("e8c56a")
const SHOP_NAMES := ["shoes", "hats", "electronics", "boutique", "grocer", "bakery", "books"]

# One thing to draw: what it is and its parameters; `_draw` calls the game's own code.
class Preview extends Node2D:
    var kind := ""
    var theme := 0
    var n := 0
    var signed := false
    var neon := Color.WHITE
    var size := 12.0
    var icon := ""
    var mark := ""
    var age := 0.0
    var bob := 0.0
    var sign_plan := {}

    func _p(x: float, y: float, z: float) -> Vector2:
        return Sprites.proj(Vector2(x, y), z)

    func _quad(origin: Vector2, along: Vector2, u0: float, u1: float, z0: float, z1: float) -> PackedVector2Array:
        var a := origin + along * u0
        var b := origin + along * u1
        return PackedVector2Array([_p(a.x, a.y, z0), _p(b.x, b.y, z0), _p(b.x, b.y, z1), _p(a.x, a.y, z1)])

    func _draw() -> void:
        match kind:
            "grate":
                # flat on the ground, in the ground's own sheared space (the preview's transform is the shear)
                draw_rect(Rect2(Vector2(-size - 7.0, -size - 7.0), Vector2(size + 7.0, size + 7.0) * 2.0), Ground.PAVEMENT)
                Grate.draw_plate(self, Vector2.ZERO, size)
                Grate.draw_slots(self, [[Vector2.ZERO, size]])

            "shop":
                var origin := Vector2.ZERO
                var along := Vector2.RIGHT
                Sprites.fill(self, _quad(origin, along, -6.0, 34.0, 0.0, 22.0), WALL)
                Sprites.fill(self, _quad(origin, along, -1.0, 29.0, 3.0, 17.0), Color("11131b"))
                ShopWindows.paint(self, origin, along, 0.0, WINDOW_LIGHT, theme, n, signed, neon)
            "neon":
                var origin := Vector2.ZERO
                Sprites.fill(self, _quad(origin, Vector2.RIGHT, -3.0, 21.0, 0.0, 12.0), WALL)
                for r in ShopWindows.neon_sign(neon):
                    Sprites.fill(self, _quad(origin, Vector2.RIGHT, 3.0 + r[0] - 11.0, 3.0 + r[1] - 11.0, 4.0 + r[2] - 5.4, 4.0 + r[3] - 5.4), r[4])
            "streetneon":
                Sprites.fill(self, _quad(Vector2.ZERO, Vector2.RIGHT, -8.0, sign_plan.w + 24.0, 0.0, 44.0), WALL)
                NeonSign.paint(self, self, Vector2.ZERO, Vector2.RIGHT, sign_plan, 1.0)
            "icon":
                Style.draw_clue_icon(self, icon, Vector2.ZERO, 40.0)
            "bubble":
                Style.draw_thought_bubble(self, Vector2(0.0, bob), "house", 1.0)
            "mark":
                Cop.draw_alert_mark(self, mark, age)

func _init() -> void:
    call_deferred("render_all")

# Renders every frame of one state, crops them all to the same box (so an animation does not jump),
# and saves them as <folder>/<state><n>.png.
func render_state(viewport: SubViewport, prop: Preview, folder: String, state: String, setups: Array, pad: int = 3) -> int:
    var images: Array = []
    var used := Rect2i()
    for i in setups.size():
        setups[i].call(prop)
        prop.queue_redraw()
        for wait in 3:  # (a texture used for the first time is a white box until the GPU has it)
            await process_frame
        RenderingServer.force_draw()  # also render when the native window is occluded
        var img: Image = viewport.get_texture().get_image()
        images.append(img)
        var r: Rect2i = img.get_used_rect()
        used = r if i == 0 else used.merge(r)
    used = used.grow(pad).intersection(Rect2i(Vector2i.ZERO, viewport.size))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://web/gallery/%s" % folder))
    for i in images.size():
        images[i].get_region(used).save_png("res://web/gallery/%s/%s%d.png" % [folder, state, i])
    return images.size()

func render_all() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(220, 190)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var prop := Preview.new()
    viewport.add_child(prop)
    var total := 0
    var centre := Vector2(110.0, 110.0)

    # Tree grates: the kerb size, the plaza size, and one with its tree standing in it.
    prop.transform = Transform2D(Sprites.ISO_X, Sprites.ISO_Y, centre)  # the ground's shear
    total += await render_state(viewport, prop, "treegrate", "kerb", [func(p): p.kind = "grate"; p.size = Grate.MIN])
    total += await render_state(viewport, prop, "treegrate", "plaza", [func(p): p.kind = "grate"; p.size = Grate.MAX])
    # (the tree is a sprite standing upright with its foot on the grate, 44 by 60 units as in StreetObject:
    # a Sprite2D here, since draw_texture_rect of a loaded texture comes out as a white box in an offscreen viewport)
    var tree := Sprite2D.new()
    tree.texture = load("res://assets/sprites/tree/tree0.png")
    tree.centered = false
    tree.offset = Vector2(-44.0, -116.0)
    tree.transform = Sprites.UP.scaled_local(Vector2(0.5, 0.5))
    prop.add_child(tree)
    total += await render_state(viewport, prop, "treegrate", "planted", [func(p): p.kind = "grate"; p.size = Grate.MAX])
    prop.remove_child(tree)
    tree.free()

    # Shop windows: each kind of shop, two windows (the second with the neon sign, as it is in the game).
    prop.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, centre + Vector2(-10.0, 40.0))
    var colours := [ShopWindows.NEON[0], ShopWindows.NEON[1], ShopWindows.NEON[2]]
    for theme in ShopWindows.THEMES:
        var setups: Array = []
        for w in 2:
            setups.append(func(p): p.kind = "shop"; p.theme = theme; p.n = w; p.signed = w == 1; p.neon = colours[theme % 3])
        total += await render_state(viewport, prop, "shopwindow", SHOP_NAMES[theme], setups)

    # The neon OPEN sign on its own, in each colour.
    for i in 3:
        total += await render_state(viewport, prop, "neonsign", ["pink", "cyan", "red"][i], [func(p): p.kind = "neon"; p.neon = colours[i]])

    # The neon signs of level 5, each picture in each of the six colours (the frames run through them).
    prop.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, centre + Vector2(-20.0, 50.0))
    for what in NeonSign.WORDS + NeonSign.SHAPES:
        var tints: Array = []
        for ci in NeonSign.COLORS.size():
            var pl := {"u": 8.0, "z": 20.0, "what": what, "color": NeonSign.COLORS[ci], "w": float(NeonSign.dots(what).w) * NeonSign.CELL, "h": float(NeonSign.dots(what).h) * NeonSign.CELL}
            tints.append(func(p): p.kind = "streetneon"; p.sign_plan = pl)
        total += await render_state(viewport, prop, "streetneon", what.to_lower(), tints)

    # The clue pictures.
    prop.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, centre)
    for icon in ["question", "alert", "house", "bin", "paw", "zombie"]:
        total += await render_state(viewport, prop, "clueicon", icon, [func(p): p.kind = "icon"; p.icon = icon])

    # The found items (Items.gd), as they are on the ground and in the slot.
    for kind in Items.KINDS:
        total += await render_state(viewport, prop, "founditems", kind, [func(p): p.kind = "icon"; p.icon = "item_" + kind])

    # Stella's thought bubble, bobbing.
    var bobs: Array = []
    for k in 4:
        bobs.append(func(p): p.kind = "bubble"; p.bob = sin(float(k) * TAU / 4.0) * 1.2)
    total += await render_state(viewport, prop, "thought", "bubble", bobs)

    # A cop's marks, popping in: large, settling.
    prop.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, centre + Vector2(0.0, 50.0))
    for mark in [["question", "?"], ["alert", "!"]]:
        var pops: Array = []
        for age in [0.0, 0.06, 0.12, 0.3]:
            pops.append(func(p): p.kind = "mark"; p.mark = mark[1]; p.age = age)
        total += await render_state(viewport, prop, "copmark", mark[0], pops)
    print("Rendered %d gallery frames from the game's drawing code" % total)
    quit()
