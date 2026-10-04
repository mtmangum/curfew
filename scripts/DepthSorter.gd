extends RefCounted
# Draws the street in the right order, and sees through buildings. Everything that stands on
# the ground is sorted every frame so nearer things draw on top; only pairs whose screen boxes
# overlap can hide each other, so only those are compared, and things off screen keep whatever
# z they had. Buildings go see-through while Nicole or Stella is hidden behind one.
# (Main owns one: `main.depth`.)

const BuildingScript := preload("res://scripts/Building.gd")
const Sprites := preload("res://scripts/Sprites.gd")

var main
# The static things near the view, refreshed only as the camera moves, so the
# per-frame sorting and fading don't scan every building, car and lamp.
var near_cache_focus := Vector2(-999999.0, -999999.0)
var near_boxes: Array = []
var near_statics: Array = []

func _init(game) -> void:
    main = game

# True if `a` has to be drawn before (behind) `b`. Actors sort by distance
# along the view diagonal; boxes sort by which side of them an actor is on.
func behind(a, b) -> bool:
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
        return not behind(b, a)
    var p: Vector2 = a.global_position
    var r: Rect2 = b.rect
    return not (p.x >= r.end.x or p.y >= r.end.y)

# Rebuilds the near_* caches if the camera has moved far enough. They cover a
# generous area around the focus, so a refresh every ~140 units is plenty.
func refresh_near() -> void:
    if main.focus.distance_squared_to(near_cache_focus) < 140.0 * 140.0:
        return
    near_cache_focus = main.focus
    var area := Rect2(Sprites.iso(main.focus) - Vector2(700.0, 520.0), Vector2(1400.0, 1040.0))
    near_boxes.clear()
    near_statics.clear()
    for b in main.building_nodes:
        if b.screen_box.intersects(area):
            near_boxes.append(b)
    for list in [main.props, main.fires, main.lamps]:
        for n in list:
            if area.has_point(Sprites.iso(n.global_position)):
                near_statics.append(n)

# Orders everything on screen that stands on the ground (sets each one's z_index).
func sort() -> void:
    refresh_near()
    var centre: Vector2 = Sprites.iso(main.focus)
    var view := Rect2(centre - Vector2(450.0, 310.0), Vector2(900.0, 620.0))
    var items: Array = []
    var boxes: Array = []  # screen box of each item
    for b in near_boxes:
        if b.screen_box.intersects(view):
            items.append(b)
            boxes.append(b.screen_box)
    for n in near_statics:
        var sp0: Vector2 = Sprites.iso(n.global_position)
        if view.has_point(sp0):
            items.append(n)
            boxes.append(Rect2(sp0.x - 14.0, sp0.y - 52.0, 28.0, 54.0))
    for list in [main.cats, main.cops, main.npcs, main.skaters, main.pickups, main.squirrels]:
        for n in list:
            var sp: Vector2 = Sprites.iso(n.global_position)
            if view.has_point(sp):
                items.append(n)
                boxes.append(Rect2(sp.x - 14.0, sp.y - 52.0, 28.0, 54.0))
    for car in main.traffic:  # moving boxes: their screen box changes every frame
        if car.screen_box.intersects(view):
            items.append(car)
            boxes.append(car.screen_box)
    for n in [main.dog, main.player]:
        var sp2: Vector2 = Sprites.iso(n.global_position)
        items.append(n)
        boxes.append(Rect2(sp2.x - 14.0, sp2.y - 52.0, 28.0, 54.0))
    var count: int = items.size()
    var waiting := PackedInt32Array()
    waiting.resize(count)
    var after: Array = []
    for i in count:
        after.append([])
    for i in count:
        var bi: Rect2 = boxes[i]
        for j in range(i + 1, count):
            if not bi.intersects(boxes[j]):
                continue
            if behind(items[i], items[j]):
                after[i].append(j)
                waiting[j] += 1
            elif behind(items[j], items[i]):
                after[j].append(i)
                waiting[i] += 1
    var done := PackedByteArray()
    done.resize(count)
    for rank in count:
        var pick := -1
        var pick_key := INF
        var fallback := -1
        var fallback_key := INF
        for i in count:
            if done[i] == 1:
                continue
            var key: float = depth_key(items[i])
            if key < fallback_key:
                fallback_key = key
                fallback = i
            if waiting[i] == 0 and key < pick_key:
                pick_key = key
                pick = i
        if pick == -1:
            pick = fallback
        done[pick] = 1
        items[pick].z_index = 100 + rank
        for k in after[pick]:
            waiting[k] -= 1

func depth_key(n) -> float:
    if n is BuildingScript:
        return n.rect.end.x + n.rect.end.y
    return n.global_position.x + n.global_position.y

# Buildings go see-through while Nicole or Stella is hidden behind one.
func fade_buildings(delta: float) -> void:
    refresh_near()
    for b in near_boxes:
        if not b.fades:
            b.modulate.a = 1.0
            continue
        var hidden := false
        for who in [main.player, main.dog]:
            if not behind(who, b):
                continue
            var foot: Vector2 = Sprites.iso(who.global_position)
            if not b.screen_box.has_point(foot):
                continue
            var poly: PackedVector2Array = b.silhouette()
            if Geometry2D.is_point_in_polygon(foot, poly) \
                    or Geometry2D.is_point_in_polygon(foot + Vector2(0, -26), poly):
                hidden = true
        b.modulate.a = move_toward(b.modulate.a, 0.3 if hidden else 1.0, 4.0 * delta)
