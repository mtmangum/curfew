extends SceneTree
# Nobody should be near the player at the start: no cop within SAFE units, and
# standing still at the start for 30 seconds must not get you caught.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_start_safe.gd
const SAFE := 450.0

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    var nearest := INF
    for c in main.cops:
        nearest = minf(nearest, c.global_position.distance_to(main.player.global_position))
    print("nearest cop to the start: ", snappedf(nearest, 1.0), " (need at least ", SAFE, "): ", nearest >= SAFE)
    var worst := 0.0
    for f in 1800:
        await physics_frame
        for c in main.cops:
            worst = maxf(worst, c.exposure)
    print("30s standing still: state=", main.state, " worst suspicion=", snappedf(worst, 0.01))
    quit()
