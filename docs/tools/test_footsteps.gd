extends SceneTree
# Footsteps are triggered by the walk animation's contact frames, so they come
# at an even beat that matches her gait (two per six-frame cycle).
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_footsteps.gd

func _step_players(main) -> Array:
    var out: Array = []
    for c in main.get_children():
        if c is AudioStreamPlayer and c.stream != null and "step" in c.stream.resource_path:
            out.append(c)
    return out

func _walk(main, goal: Vector2, sneak: bool) -> Array:
    main.sneak_toggle = sneak
    main.player.global_position = Vector2(100, 1390)
    main.player.last_frame = -1
    main.player.dest = goal
    main.player.has_dest = true
    var seen := {}
    for p in _step_players(main):
        seen[p.get_instance_id()] = true  # ignore sounds left over from before
    var times: Array = []
    for f in 240:
        await physics_frame
        for p in _step_players(main):
            if not seen.has(p.get_instance_id()):
                seen[p.get_instance_id()] = true
                times.append(f / 60.0)
    return times

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    for sneak in [false, true]:
        var t: Array = await _walk(main, Vector2(500, 1390), sneak)
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
