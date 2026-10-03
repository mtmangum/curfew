extends SceneTree
# Street furniture: plenty of different kinds, none overlapping a building, a car,
# a patrol line or the spawn point, and all of them solid.
#   godot --headless --path . --script docs/tools/test_obstacles.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    main.home_seed = 1
    root.add_child(main)
    for i in 3:
        await process_frame
    var kinds := {}
    for n in main.building_nodes:
        if n.has_method("setup_object"):
            kinds[n.kind] = true
    var overlaps := 0
    for o in main.obstacles:
        for b in main.buildings:
            if b.intersects(o):
                overlaps += 1
        for car in main.cars:
            if car.intersects(o):
                overlaps += 1
        for route in main.cop_routes:
            for i in route.size():  # patrols are loops, so the last point joins the first
                var from: Vector2 = route[i]
                var to: Vector2 = route[(i + 1) % route.size()]
                for n in int(from.distance_to(to) / 6.0) + 1:
                    var pt: Vector2 = from.lerp(to, float(n) * 6.0 / maxf(from.distance_to(to), 1.0))
                    if o.grow(6.0).has_point(pt):
                        overlaps += 1
        if o.grow(10.0).has_point(main.START):
            overlaps += 1
    var solid := 0
    for o in main.obstacles:
        if main.blocked_circle(o.get_center(), 3.0):
            solid += 1
    print("obstacles: ", main.obstacles.size(), "  kinds: ", kinds.size(), " of 10  ok: ", kinds.size() >= 8)
    print("overlaps with buildings, cars, patrols or the start: ", overlaps, "  ok: ", overlaps == 0)
    print("solid to walk into: ", solid, " of ", main.obstacles.size(), "  ok: ", solid == main.obstacles.size())
    quit()
