extends SceneTree
# Untouched real level 1, no player input, default distractions and traffic.
const Clues := preload("res://scripts/Clues.gd")
const Inputs := preload("res://docs/tools/audit_inputs.gd")
var rows: Array = []
var output := "/tmp/curfew-idle-guidance.json"

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("out="):
            output = arg.trim_prefix("out=")
    call_deferred("run")

func run() -> void:
    for home_seed in 6:
        Clues.persist = false
        Clues._loaded = true
        Clues.seen.clear()
        var game = load("res://scenes/Main.tscn").instantiate()
        game.level_override = 1
        game.home_seed = home_seed
        game.audit_seed = 1000 * home_seed + 1
        game.process_mode = Node.PROCESS_MODE_DISABLED
        root.add_child(game)
        game.runlog.persist = false
        await process_frame
        game.process_mode = Node.PROCESS_MODE_INHERIT
        var origin: Vector2 = game.player.global_position
        for frame in 10800:  # three simulated minutes, including repeated home hints
            if game.state != "play":
                break
            await process_frame
        if game.state == "play":
            game.runlog.finish("idle_observation")
        var summary: Dictionary = game.runlog.summary().duplicate(true)
        summary["idle_displacement"] = origin.distance_to(game.player.global_position)
        summary["home_seed"] = home_seed
        summary["tutorial_profile"] = "fresh visitor"
        summary["source_signature"] = Inputs.source_signature()
        summary["godot"] = Engine.get_version_info().string
        summary["fixed_fps"] = Engine.get_physics_ticks_per_second()
        rows.append(summary)
        print("idle seed ", home_seed, ": ", summary.outcome, "; displacement ", summary.idle_displacement, "; home hints ", summary.stella_stops.get("scent", 0))
        game.queue_free()
        for i in 2:
            await process_frame
    FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
    quit()
