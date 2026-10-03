extends SceneTree
# Home is a different building each run, but always a fair one: far from the start,
# with open street in front of the door, and not under a patrol, bin or parked car.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_home.gd

func _init() -> void:
    var homes := {}
    var problems: Array = []
    for seed_value in range(12):
        var main = load("res://scenes/Main.tscn").instantiate()
        main.traffic_enabled = false
        main.traffic_enabled = false
        main.home_seed = seed_value
        root.add_child(main)
        for i in 3:
            await process_frame
        var centre: Vector2 = main.home_zone.get_center()
        homes[centre] = true
        if centre.distance_to(main.START) < 4500.0:
            problems.append("seed %d: too close to the start" % seed_value)
        if not main.buildings.has(main.house):
            problems.append("seed %d: the house is not a building" % seed_value)
        if main.blocked_circle(centre, 5.0):
            problems.append("seed %d: the door zone is blocked" % seed_value)
        for car in main.cars:
            if car.intersects(main.home_zone):
                problems.append("seed %d: a car is parked in the door zone" % seed_value)
        for cop in main.cops:
            if cop.global_position.distance_to(centre) < 35.0:
                problems.append("seed %d: a cop starts at the door" % seed_value)
        main.queue_free()
        for i in 2:
            await process_frame
    print("distinct homes over 12 seeds: ", homes.size(), "  ok: ", homes.size() >= 4)
    print("problems: ", problems.size() if not problems.is_empty() else "none", " ", problems.slice(0, 4))
    quit()
