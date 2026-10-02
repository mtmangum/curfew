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

const START := Vector2(70, 650)
const HOME_ZONE := Rect2(1150, 112, 60, 40)

class Ground extends Node2D:
    var main

    func _draw() -> void:
        draw_rect(main.world_rect, Color("12151f"))
        for x in range(20, 1280, 48):
            draw_rect(Rect2(x, 358, 22, 3), Color(0.35, 0.35, 0.3, 0.45))
        for r in main.buildings:
            draw_rect(r.grow(7), Color("262a38"))
        for r in main.buildings:
            var body: Color = Color("1b1d29")
            if r == main.house:
                body = Color("3a2a2a")
            draw_rect(r, body)
            draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), Color(0, 0, 0, 0.35))
            var x: float = r.position.x + 12.0
            while x < r.end.x - 14.0:
                var y: float = r.position.y + 16.0
                while y < r.end.y - 14.0:
                    if (int(x * 7.0 + y * 13.0) % 5) == 0:
                        draw_rect(Rect2(x, y, 8, 10), Color("e8c56a"))
                    else:
                        draw_rect(Rect2(x, y, 8, 10), Color("11131b"))
                    y += 26.0
                x += 24.0
        draw_rect(Rect2(1160, 98, 40, 12), Color("ffd27a"))
        draw_rect(main.home_zone, Color(1.0, 0.85, 0.4, 0.10))
        draw_string(ThemeDB.fallback_font, Vector2(1160, 80), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd27a"))

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
var player
var dog
var cops: Array = []
var vents: Array = []
var fires: Array = []
var props: Array = []
var cats: Array = []
var sounds := {}

var actors: Node2D
var cam: Camera2D
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
    actors.y_sort_enabled = true
    add_child(actors)

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

    cam = Camera2D.new()
    cam.zoom = Vector2(2.5, 2.5)
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = 1280
    cam.limit_bottom = 720
    cam.position_smoothing_enabled = true
    cam.position = player.global_position
    add_child(cam)

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
    hud.text = "Curfew: get Nicole and Stella home unseen.\nWASD / arrows move   Shift sneak   R restart"
    layer.add_child(hud)
    banner = Label.new()
    banner.set_anchors_preset(Control.PRESET_CENTER)
    banner.add_theme_font_size_override("font_size", 40)
    banner.visible = false
    layer.add_child(banner)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        get_tree().reload_current_scene()

func _process(_delta: float) -> void:
    cam.position = player.global_position
    var worst := 0.0
    for c in cops:
        worst = maxf(worst, c.exposure)
    danger.color.a = worst * 0.35
    if state == "play" and home_zone.has_point(player.global_position):
        _win()

func _win() -> void:
    state = "won"
    banner.text = "HOME SAFE\nPress R to play again"
    banner.visible = true
    play("pickup")

func caught(_cop) -> void:
    if state != "play":
        return
    state = "caught"
    banner.text = "CAUGHT\nPress R to try again"
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
        ring.z_index = 40
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
