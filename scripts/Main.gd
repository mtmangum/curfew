extends Node2D
# Curfew: sneak Nicole and Stella home across a night street. The level is
# built here from plain data so it's easy to rearrange.

const PlayerScript := preload("res://scripts/Player.gd")
const DogScript := preload("res://scripts/Dog.gd")
const CopScript := preload("res://scripts/Cop.gd")
const CatScript := preload("res://scripts/Cat.gd")
const PropScript := preload("res://scripts/Prop.gd")
const VentScript := preload("res://scripts/SteamVent.gd")
const FireScript := preload("res://scripts/Fire.gd")
const BuildingScript := preload("res://scripts/Building.gd")
const Sprites := preload("res://scripts/Sprites.gd")

const ZOOM := 1.8
const BUILDING_HEIGHTS := [58.0, 52.0, 64.0, 60.0, 68.0, 54.0, 74.0]

const START := Vector2(70, 650)
const HOME_ZONE := Rect2(1150, 112, 60, 40)

class Ground extends Node2D:
    var main

    func _draw() -> void:
        var wr: Rect2 = main.world_rect
        # Everything past the edge of the street is void.
        draw_rect(wr.grow(4000), Color("07080d"))
        # The street is a slab with a visible thickness along its two near edges.
        draw_set_transform_matrix(Sprites.UP)
        var corners := [wr.position, Vector2(wr.end.x, wr.position.y), wr.end, Vector2(wr.position.x, wr.end.y)]
        var drop := Vector2(0, 14)
        var sw: Vector2 = Sprites.iso(corners[3])
        var se: Vector2 = Sprites.iso(corners[2])
        var ne: Vector2 = Sprites.iso(corners[1])
        draw_colored_polygon(PackedVector2Array([sw, se, se + drop, sw + drop]), Color("0d0f17"))
        draw_colored_polygon(PackedVector2Array([se, ne, ne + drop, se + drop]), Color("090b11"))
        draw_set_transform_matrix(Transform2D.IDENTITY)

        draw_rect(wr, Color("141824"))
        for x in range(0, 1281, 40):
            draw_line(Vector2(x, 0), Vector2(x, wr.end.y), Color(1, 1, 1, 0.025), 1.0)
        for y in range(0, 721, 40):
            draw_line(Vector2(0, y), Vector2(wr.end.x, y), Color(1, 1, 1, 0.025), 1.0)
        for x in range(20, 1280, 48):
            draw_rect(Rect2(x, 358, 22, 3), Color(0.55, 0.55, 0.45, 0.45))
        for r in main.buildings:
            var walk: Rect2 = r.grow(10)
            draw_rect(walk, Color("262b3b"))
            draw_rect(walk, Color("3a4056"), false, 1.0)
        draw_rect(main.home_zone, Color(1.0, 0.85, 0.4, 0.16))
        draw_rect(main.home_zone, Color(1.0, 0.85, 0.4, 0.45), false, 1.0)

class NoiseRing extends Node2D:
    var radius := 100.0
    var life := 0.0

    func _process(delta: float) -> void:
        life += delta
        if life > 0.7:
            queue_free()
        queue_redraw()

    func _draw() -> void:
        var k: float = life / 0.7
        draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * k), 0.0, TAU, 48, Color(1, 1, 1, 0.5 * (1.0 - k)), 1.5)

var world_rect := Rect2(0, 0, 1280, 720)
var home_zone := HOME_ZONE
var house := Rect2(1100, 0, 180, 110)
var buildings: Array[Rect2] = [
    Rect2(160, 430, 280, 150),
    Rect2(560, 480, 240, 160),
    Rect2(920, 400, 240, 200),
    Rect2(140, 120, 300, 170),
    Rect2(560, 100, 180, 220),
    Rect2(860, 180, 200, 140),
    Rect2(1100, 0, 180, 110),
]
var walls: Array[Rect2] = []

var state := "play"
var screen_relative := false
var sneak_toggle := false
var ended_at := 0
var sneak_button: Button
var player
var dog
var cops: Array = []
var vents: Array = []
var fires: Array = []
var props: Array = []
var cats: Array = []
var sounds := {}

var actors: Node2D
var focus := Vector2.ZERO
var building_nodes: Array = []
var sortables: Array = []
var hud: Label
var banner: Label
var danger: ColorRect

func _ready() -> void:
    randomize()
    walls = buildings
    for n in ["pickup", "bark", "lure_drop", "tug"]:
        sounds[n] = load("res://assets/audio/%s.wav" % n)

    var ground := Ground.new()
    ground.main = self
    ground.z_index = -100
    ground.z_as_relative = false
    add_child(ground)

    actors = Node2D.new()
    add_child(actors)

    for i in buildings.size():
        var b := BuildingScript.new()
        b.rect = buildings[i]
        b.height = BUILDING_HEIGHTS[i]
        b.house = buildings[i] == house
        actors.add_child(b)
        building_nodes.append(b)

    for p in [Vector2(470, 500), Vector2(640, 400), Vector2(900, 385)]:
        var prop := PropScript.new()
        prop.main = self
        actors.add_child(prop)
        prop.global_position = p
        props.append(prop)

    for v in [[Vector2(330, 665), 0.0], [Vector2(500, 385), 2.5], [Vector2(860, 520), 1.0], [Vector2(1080, 345), 4.0]]:
        var vent := VentScript.new()
        vent.main = self
        vent.phase = v[1]
        vent.z_index = -20
        actors.add_child(vent)
        vent.global_position = v[0]
        vents.append(vent)

    var fire := FireScript.new()
    fire.main = self
    actors.add_child(fire)
    fire.global_position = Vector2(700, 370)
    fires.append(fire)

    player = PlayerScript.new()
    player.main = self
    actors.add_child(player)
    player.global_position = START

    dog = DogScript.new()
    dog.main = self
    actors.add_child(dog)
    dog.global_position = START + Vector2(-20, 8)

    for route in [
        [Vector2(80, 360), Vector2(500, 360)],
        [Vector2(900, 350), Vector2(1230, 350), Vector2(1230, 150)],
        [Vector2(120, 675), Vector2(520, 675), Vector2(520, 450)],
    ]:
        var cop := CopScript.new()
        actors.add_child(cop)
        cop.setup(self, route)
        cops.append(cop)

    for pos in [Vector2(520, 520), Vector2(980, 380)]:
        var cat := CatScript.new()
        cat.main = self
        actors.add_child(cat)
        cat.global_position = pos
        cats.append(cat)

    focus = player.global_position
    _update_view(1.0)
    _depth_sort()

    _build_hud()

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    danger = ColorRect.new()
    danger.set_anchors_preset(Control.PRESET_FULL_RECT)
    danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    danger.color = Color(0.8, 0.05, 0.05, 0.0)
    layer.add_child(danger)
    hud = Label.new()
    hud.position = Vector2(12, 10)
    hud.add_theme_font_size_override("font_size", 20)
    hud.text = _hud_text()
    layer.add_child(hud)
    banner = Label.new()
    banner.set_anchors_preset(Control.PRESET_CENTER)
    banner.add_theme_font_size_override("font_size", 40)
    banner.visible = false
    layer.add_child(banner)
    # Touch screens have no Shift key.
    sneak_button = Button.new()
    sneak_button.toggle_mode = true
    sneak_button.focus_mode = Control.FOCUS_NONE
    sneak_button.text = "Sneak"
    sneak_button.add_theme_font_size_override("font_size", 24)
    sneak_button.custom_minimum_size = Vector2(150, 64)
    sneak_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    sneak_button.offset_left = -170
    sneak_button.offset_top = -84
    sneak_button.offset_right = -20
    sneak_button.offset_bottom = -20
    sneak_button.toggled.connect(func(on: bool) -> void: sneak_toggle = on)
    layer.add_child(sneak_button)

func _hud_text() -> String:
    var keys := "screen-relative" if screen_relative else "along the streets"
    return "Curfew: get Nicole and Stella home unseen.\nClick / tap to walk, hold to steer   WASD move (%s, Tab to switch)   Shift or button sneak   R restart" % keys

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        get_tree().reload_current_scene()
    # Tap to play again once the banner has been up a moment.
    if state != "play" and event is InputEventMouseButton and event.pressed \
            and Time.get_ticks_msec() - ended_at > 700:
        get_tree().reload_current_scene()
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
        screen_relative = not screen_relative
        hud.text = _hud_text()

func _process(delta: float) -> void:
    focus = focus.lerp(player.global_position, clampf(8.0 * delta, 0.0, 1.0))
    _update_view(delta)
    _depth_sort()
    _fade_buildings(delta)
    var worst := 0.0
    for c in cops:
        worst = maxf(worst, c.exposure)
    danger.color.a = worst * 0.35
    if state == "play" and home_zone.has_point(player.global_position):
        _win()

# The whole street is drawn through an isometric canvas transform that follows
# the player. Game logic never sees it: positions stay on the flat plane.
func _update_view(_delta: float) -> void:
    var t := Transform2D(Sprites.ISO_X * ZOOM, Sprites.ISO_Y * ZOOM, Vector2.ZERO)
    t.origin = get_viewport_rect().size * 0.5 - t.basis_xform(focus)
    get_viewport().canvas_transform = t

# True if `a` has to be drawn before (behind) `b`. Actors sort by distance
# along the view diagonal; boxes sort by which side of them an actor is on.
func _behind(a, b) -> bool:
    var a_box: bool = a is BuildingScript
    var b_box: bool = b is BuildingScript
    if not a_box and not b_box:
        return a.global_position.x + a.global_position.y < b.global_position.x + b.global_position.y
    if a_box and b_box:
        var ra: Rect2 = a.rect
        var rb: Rect2 = b.rect
        var a_first: bool = ra.end.x <= rb.position.x or ra.end.y <= rb.position.y
        var b_first: bool = rb.end.x <= ra.position.x or rb.end.y <= ra.position.y
        return a_first and not b_first
    if a_box:
        return not _behind(b, a)
    var p: Vector2 = a.global_position
    var r: Rect2 = b.rect
    return not (p.x >= r.end.x or p.y >= r.end.y)

# Orders everything that stands on the ground so nearer things draw on top.
func _depth_sort() -> void:
    var items: Array = []
    items.append_array(building_nodes)
    items.append_array(props)
    items.append_array(fires)
    items.append_array(cats)
    items.append_array(cops)
    items.append(dog)
    items.append(player)
    var remaining: Array = items.duplicate()
    var rank := 0
    while not remaining.is_empty():
        var pick = null
        var pick_key := INF
        var fallback = null
        var fallback_key := INF
        for a in remaining:
            var key: float = _depth_key(a)
            if key < fallback_key:
                fallback_key = key
                fallback = a
            var blocked := false
            for b in remaining:
                if b != a and _behind(b, a):
                    blocked = true
                    break
            if not blocked and key < pick_key:
                pick_key = key
                pick = a
        if pick == null:
            pick = fallback
        pick.z_index = 100 + rank
        rank += 1
        remaining.erase(pick)

func _depth_key(n) -> float:
    if n is BuildingScript:
        return n.rect.end.x + n.rect.end.y
    return n.global_position.x + n.global_position.y

# Buildings go see-through while Nicole or Stella is hidden behind one.
func _fade_buildings(delta: float) -> void:
    for b in building_nodes:
        var hidden := false
        var poly: PackedVector2Array = b.silhouette()
        for who in [player, dog]:
            if not _behind(who, b):
                continue
            var foot: Vector2 = Sprites.iso(who.global_position)
            if Geometry2D.is_point_in_polygon(foot, poly) \
                    or Geometry2D.is_point_in_polygon(foot + Vector2(0, -26), poly):
                hidden = true
        b.modulate.a = move_toward(b.modulate.a, 0.3 if hidden else 1.0, 4.0 * delta)

func _win() -> void:
    state = "won"
    ended_at = Time.get_ticks_msec()
    banner.text = "HOME SAFE\nPress R or tap to play again"
    banner.visible = true
    play("pickup")

func caught(_cop) -> void:
    if state != "play":
        return
    state = "caught"
    ended_at = Time.get_ticks_msec()
    banner.text = "CAUGHT\nPress R or tap to try again"
    banner.visible = true
    play("bark")

func play(sound_name: String, db: float = 0.0) -> void:
    var s = sounds.get(sound_name)
    if s == null:
        return
    var p := AudioStreamPlayer.new()
    p.stream = s
    p.volume_db = db
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

func noise(pos: Vector2, radius: float, show_ring: bool = true) -> void:
    if show_ring:
        var ring := NoiseRing.new()
        ring.radius = radius
        ring.z_as_relative = false
        ring.z_index = 3500
        add_child(ring)
        ring.global_position = pos
    for c in cops:
        if c.global_position.distance_to(pos) <= radius:
            c.hear(pos)

func in_steam(p: Vector2) -> bool:
    for v in vents:
        if v.active and p.distance_to(v.global_position) < v.radius:
            return true
    return false

func in_fire(p: Vector2) -> bool:
    for f in fires:
        if f.lights(p):
            return true
    return false

func blocked_circle(pos: Vector2, r: float) -> bool:
    if not world_rect.grow(-r).has_point(pos):
        return true
    for w in walls:
        if w.grow(r).has_point(pos):
            return true
    return false

# Move from pos by motion, sliding along walls. Returns the new position.
func slide(pos: Vector2, motion: Vector2, r: float) -> Vector2:
    var p := pos + motion
    if not blocked_circle(p, r):
        return p
    var px := Vector2(p.x, pos.y)
    if not blocked_circle(px, r):
        return px
    var py := Vector2(pos.x, p.y)
    if not blocked_circle(py, r):
        return py
    return pos

# Distance along the ray to the first wall or active steam cloud.
func ray_hit(origin: Vector2, dir: Vector2, max_len: float) -> float:
    var best := max_len
    for w in walls:
        var t := _ray_rect(origin, dir, w)
        if t >= 0.0 and t < best:
            best = t
    for v in vents:
        if v.active:
            var t2 := _ray_circle(origin, dir, v.global_position, v.radius)
            if t2 >= 0.0 and t2 < best:
                best = t2
    return best

func los(a: Vector2, b: Vector2) -> bool:
    var d := b - a
    var dist := d.length()
    if dist < 1.0:
        return true
    return ray_hit(a, d / dist, dist) >= dist

func _ray_rect(o: Vector2, d: Vector2, r: Rect2) -> float:
    var tmin := 0.0
    var tmax := INF
    for axis in 2:
        var oa: float = o[axis]
        var da: float = d[axis]
        var lo: float = r.position[axis]
        var hi: float = r.end[axis]
        if absf(da) < 0.00001:
            if oa < lo or oa > hi:
                return -1.0
        else:
            var t1 := (lo - oa) / da
            var t2 := (hi - oa) / da
            if t1 > t2:
                var tmp := t1
                t1 = t2
                t2 = tmp
            tmin = maxf(tmin, t1)
            tmax = minf(tmax, t2)
            if tmin > tmax:
                return -1.0
    return tmin

func _ray_circle(o: Vector2, d: Vector2, c: Vector2, rad: float) -> float:
    var oc := o - c
    var b := oc.dot(d)
    var cc := oc.dot(oc) - rad * rad
    var disc := b * b - cc
    if disc < 0.0:
        return -1.0
    var t := -b - sqrt(disc)
    return t if t >= 0.0 else -1.0
