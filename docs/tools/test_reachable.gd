extends SceneTree
# Nicole must always be able to walk from the start to the front door, whatever
# is parked in the way. Breadth-first search on a grid using the real collision.
#   godot --headless --path . --script docs/tools/test_reachable.gd
const STEP := 8.0

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    var r: float = main.player.RADIUS
    var cols: int = int(main.world_rect.size.x / STEP) + 1
    var rows: int = int(main.world_rect.size.y / STEP) + 1
    var seen := PackedByteArray()
    seen.resize(cols * rows)
    var origin: Vector2 = main.world_rect.position
    var start := Vector2i(int((main.START.x - origin.x) / STEP), int((main.START.y - origin.y) / STEP))
    var goal: Vector2 = main.HOME_ZONE.get_center()
    var queue: Array = [start]
    seen[start.y * cols + start.x] = 1
    var head := 0
    var found := false
    var visited := 0
    while head < queue.size():
        var c: Vector2i = queue[head]
        head += 1
        visited += 1
        if (Vector2(c) * STEP + origin).distance_to(goal) < 16.0:
            found = true
            break
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = c + d
            if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or seen[n.y * cols + n.x] == 1:
                continue
            if main.blocked_circle(Vector2(n) * STEP + origin, r):
                continue
            seen[n.y * cols + n.x] = 1
            queue.append(n)
    print("cars parked: ", main.cars.size(), "  reachable cells: ", visited)
    print("start to the front door is walkable: ", found)
    quit()
