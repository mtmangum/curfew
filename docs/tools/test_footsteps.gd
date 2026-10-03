extends SceneTree
# Nicole's steps land on the walk animation's contact frames, so they come at an
# even beat that matches her gait (two per six-frame cycle). The footstep sound
# itself is switched off (Player.FOOTSTEP_SOUND), so this counts foot-downs.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_footsteps.gd

func _walk(main, goal: Vector2, sneak: bool) -> Array:
    main.sneak_toggle = sneak
    main.player.global_position = Vector2(100, 2830)
    main.player.last_frame = -1
    main.player.dest = goal
    main.player.has_dest = true
    var last: int = main.player.steps_taken
    var times: Array = []
    for f in 240:
        await physics_frame
        if main.player.steps_taken != last:
            last = main.player.steps_taken
            times.append(f / 60.0)
    return times

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    for sneak in [false, true]:
        var t: Array = await _walk(main, Vector2(500, 2830), sneak)
        var gaps: Array = []
        for i in range(1, t.size()):
            gaps.append(snappedf(t[i] - t[i - 1], 0.001))
        var expect: float = 0.5 if sneak else 0.3
        var even := true
        for g in gaps:
            if absf(g - expect) > 0.04:
                even = false
        print("sneak=", sneak, ": ", t.size(), " steps in 4s, gaps ", gaps.slice(0, 6), " (expect ", expect, "s each): ", even and t.size() >= 4)
    quit()
