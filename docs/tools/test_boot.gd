extends SceneTree
# Booting: built in one go off the web (nothing waits a frame), and a piece at a time
# when progressive_boot is on (the web build), reporting progress for each stage so
# the loading page can draw its bars. Both must make the same world.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_boot.gd

func _init() -> void:
    # 1. The straight-through boot is finished the moment Main enters the tree.
    var a = load("res://scenes/Main.tscn").instantiate()
    a.traffic_enabled = false
    a.home_seed = 3
    root.add_child(a)
    await process_frame
    print("1. straight-through boot: booted ", a.is_booted, ", player ", a.player != null, "  ok: ", a.is_booted and a.player != null)
    var cops_a: int = a.cops.size()
    var buildings_a: int = a.buildings.size()
    var home_a: Vector2 = a.home_zone.get_center()
    a.queue_free()
    await process_frame

    # 2. The progressive boot takes several frames, reports every stage in order with
    #    rising fractions, keeps the game paused until it is done, and ends up the same.
    var b = load("res://scenes/Main.tscn").instantiate()
    b.traffic_enabled = false
    b.home_seed = 3
    b.progressive_boot = true
    var log: Array = []
    b.boot_progress.connect(func(stage, f): log.append([stage, f]))
    root.add_child(b)
    var frames := 0
    var paused_during := true
    while not b.is_booted and frames < 600:
        await process_frame
        frames += 1
        var still_building: bool = log.is_empty() or not (log[-1][0] == "streets" and log[-1][1] == 1.0)
        if still_building and b.process_mode != Node.PROCESS_MODE_DISABLED:
            paused_during = false
    var stages: Array = []
    var rising := true
    var last := {}
    for e in log:
        if not stages.has(e[0]):
            stages.append(e[0])
        if last.has(e[0]) and e[1] < last[e[0]] - 0.0001:
            rising = false
        last[e[0]] = e[1]
    var finished: bool = last.get("sound", 0.0) == 1.0 and last.get("city", 0.0) == 1.0 and last.get("streets", 0.0) == 1.0
    print("2. progressive boot: ", frames, " frames, ", log.size(), " reports, stages ", stages, ", paused while building ", paused_during, ", rising ", rising,
        "  ok: ", frames >= 10 and stages == ["sound", "city", "streets"] and rising and finished and paused_during)
    print("   same world: cops ", b.cops.size(), "/", cops_a, ", buildings ", b.buildings.size(), "/", buildings_a, ", home ", b.home_zone.get_center() == home_a, ", state ", b.state,
        "  ok: ", b.cops.size() == cops_a and b.buildings.size() == buildings_a and b.home_zone.get_center() == home_a and b.state == "play")
    # and it plays: the player moves
    var p0: Vector2 = b.player.global_position
    b.player.dest = p0 + Vector2(60, 0)
    b.player.has_dest = true
    for i in 30:
        await physics_frame
    print("   and it plays: ", b.player.global_position != p0, "  ok: ", b.player.global_position != p0)
    quit()
