extends SceneTree
# Pausing: P / Esc (toggle()) freezes the whole game and shows the PAUSED card; again carries on.
# It does nothing once a run has ended, and the game pauses itself when the window loses focus.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_pause.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    main.home_seed = 1
    root.add_child(main)
    for i in 3:
        await process_frame
    var pm = main.pause_menu
    # make something move so freezing is visible
    main.player.dest = main.player.global_position + Vector2(400, 0)
    main.player.has_dest = true
    for i in 20:
        await physics_frame
    var t_before: float = main.runlog.t
    pm.toggle()
    var pos: Vector2 = main.player.global_position
    var dog_pos: Vector2 = main.dog.global_position
    for i in 40:
        await physics_frame
    var frozen: bool = main.player.global_position == pos and main.dog.global_position == dog_pos and main.runlog.t == t_before
    print("1. paused: tree paused ", paused, ", card shown ", pm.layer.visible, ", everything frozen ", frozen, "  ok: ", paused and pm.layer.visible and frozen)
    pm.toggle()
    for i in 30:
        await physics_frame
    print("2. resumed: paused ", paused, ", card hidden ", not pm.layer.visible, ", moving again ", main.player.global_position != pos, ", clock running ", main.runlog.t > t_before,
        "  ok: ", not paused and not pm.layer.visible and main.player.global_position != pos and main.runlog.t > t_before)
    # the game pauses itself when the window loses focus
    pm._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    var auto: bool = paused
    pm.resume()
    print("3. losing focus pauses it: ", auto, "  ok: ", auto)
    # nothing to pause once the run has ended
    main.state = "caught"
    pm.toggle()
    print("4. no pausing after the run has ended: ", not paused, "  ok: ", not paused)
    paused = false
    quit()
