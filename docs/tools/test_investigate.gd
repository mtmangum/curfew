extends SceneTree
# A cop sent to investigate a noise at a solid object (a bin or a fire barrel)
# must reach it, look around, and go back on patrol, not circle it forever. Tries
# the cop from many directions and distances.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_investigate.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    var cop = main.cops[0]
    for other in main.cops:
        other.set_process(other == cop)
    var worst := 0.0
    var worst_case := ""
    var failures := 0
    var targets: Array = [main.props[0].global_position, main.props[1].global_position, main.fires[0].global_position]
    for target in targets:
        for dist in [40.0, 90.0, 160.0]:
            for k in 8:
                var a: float = TAU * float(k) / 8.0 + 0.2
                var start: Vector2 = target + Vector2.from_angle(a) * dist
                if main.blocked_circle(start, 5.0):
                    continue
                cop.global_position = start
                cop.angle = a + PI
                cop.state = cop.State.PATROL
                cop.wait = 100.0
                main.player.global_position = Vector2(300, 500)
                cop.hear(target)
                var investigating := 0
                for f in 900:
                    await physics_frame
                    main.player.global_position = Vector2(300, 500)
                    if cop.state == cop.State.INVESTIGATE:
                        investigating += 1
                    else:
                        break
                var secs: float = investigating / 60.0
                if secs > worst:
                    worst = secs
                    worst_case = "target %s dist %d angle %d deg" % [target, dist, int(rad_to_deg(a))]
                if investigating >= 899:
                    failures += 1
    print("longest investigation: ", snappedf(worst, 0.1), "s  (", worst_case, ")")
    print("cops still circling after 15s: ", failures)
    quit()
