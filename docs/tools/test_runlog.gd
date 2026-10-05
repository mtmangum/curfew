extends SceneTree
# The run log (playtest telemetry): it counts sightings and chases, records how a run
# ends (won, caught, run over, abandoned), and F3 toggles its readout.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_runlog.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _fresh(seed_value: int):
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = seed_value
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    return main

func _init() -> void:
    # 1. A win is logged with the time and straight-line home distance.
    var main = await _fresh(1)
    for i in 60:
        await physics_frame
    main.player.global_position = main.home_zone.get_center()
    for i in 5:
        await physics_frame
    var s: Dictionary = main.runlog.summary()
    print("1. outcome: ", s.outcome, "  seconds: ", s.seconds, "  distance gain: ", s.best_distance_gain_fraction, "  ok: ", s.outcome == "won" and s.seconds > 0.9 and s.best_distance_gain_fraction > 0.95 and s.initial_home_distance > 4000)
    main.queue_free()
    await process_frame

    # 2. A cop that sees her is a sighting, then a chase; being caught is logged with how long he chased.
    main = await _fresh(1)
    var spot: Vector2 = Helpers.free_spot(main, main.START + Vector2(300, -200))
    var cop = main.cops[0]
    for c in main.cops:
        c.global_position = Vector2(-2000, 100)  # out of the way
    cop.global_position = spot
    cop.angle = 0.0
    main.player.global_position = spot + Vector2(40, 0)
    main.dog.global_position = main.player.global_position
    main.focus = main.player.global_position
    for i in 300:
        await physics_frame
        if main.state != "play":
            break
    s = main.runlog.summary()
    print("2. outcome: ", s.outcome, "  sightings: ", s.sightings, "  chases: ", s.chases, "  closest: ", s.closest_cop, "  ok: ", s.outcome == "caught" and s.sightings >= 1 and s.chases >= 1 and s.detail.has("cop_chase_s"))
    main.queue_free()
    await process_frame

    # 3. A car hit is logged as run_over; the log is final once the run has ended.
    main = await _fresh(2)
    var stub = load("res://scripts/Traffic.gd").new()
    stub.heading = Vector2.RIGHT
    stub.speed = 150.0
    main.vitals.health = 10.0
    main.run_over(stub)
    s = main.runlog.summary()
    main.runlog.finish("won")  # too late: the first ending stands
    print("3. outcome: ", s.outcome, " then ", main.runlog.summary().outcome, "  ok: ", s.outcome == "run_over" and main.runlog.summary().outcome == "run_over")
    main.queue_free()
    await process_frame

    # 4. F3 shows and hides the readout.
    main = await _fresh(3)
    var before: bool = main.runlog._layer.visible
    main.runlog.toggle()
    var shown: bool = main.runlog._layer.visible
    main.runlog.toggle()
    print("4. readout starts hidden: ", not before, ", toggles on: ", shown, ", off again: ", not main.runlog._layer.visible, "  ok: ", (not before) and shown and not main.runlog._layer.visible)
    main.queue_free()
    await process_frame

    # 5. C gathers the session's runs as JSON (the end banner itself stays free of debug text).
    main = await _fresh(4)
    for i in 90:
        await physics_frame
    main.player.global_position = main.home_zone.get_center()
    for i in 5:
        await physics_frame
    var count: int = main.runlog.copy_to_clipboard()
    var parsed = JSON.parse_string(JSON.stringify(main.runlog.session))
    print("5. the end banner carries no debug text: ", main.hud.banner.get_child_count() <= 2, "; C gathers the session's runs (", count, ")  ok: ", count >= 1 and parsed is Array and parsed[-1].outcome == "won")
    main.queue_free()
    quit()

