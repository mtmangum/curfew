extends "res://scripts/DepthSorter.gd"
# Pre-optimization reference implementation for timing and ordering comparisons.
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
