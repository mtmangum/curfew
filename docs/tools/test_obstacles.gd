extends SceneTree
# Street furniture: plenty of different kinds, none overlapping a building, a car,
# a patrol route, a bin or the start, and all of them solid.
#   godot --headless --path . --script docs/tools/test_obstacles.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
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
            for i in range(route.size() - 1):
                for n in int(route[i].distance_to(route[i + 1]) / 8.0) + 1:
                    var pt: Vector2 = route[i].lerp(route[i + 1], float(n) * 8.0 / maxf(route[i].distance_to(route[i + 1]), 1.0))
                    if o.grow(20.0).has_point(pt):
                        overlaps += 1
        if o.get_center().distance_to(main.START) < 100.0:
            overlaps += 1
    var solid := 0
    for o in main.obstacles:
        if main.blocked_circle(o.get_center(), 3.0):
            solid += 1
    print("obstacles: ", main.obstacles.size(), "  kinds: ", kinds.size(), " of 10  ok: ", kinds.size() >= 8)
    print("overlaps with buildings, cars, patrols or the start: ", overlaps, "  ok: ", overlaps == 0)
    print("solid to walk into: ", solid, " of ", main.obstacles.size(), "  ok: ", solid == main.obstacles.size())
    quit()
