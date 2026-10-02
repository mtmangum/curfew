extends SceneTree
# Click-to-walk and hold-to-steer: run with
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_pointer.gd

func _click(main, ground: Vector2, pressed: bool) -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = pressed
    ev.position = root.get_canvas_transform() * ground
    # Straight to the handler: parse_input_event would apply the headless window's stretch.
    main.player._unhandled_input(ev)

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)

    # Tap a spot down the street: Nicole walks there and stops.
    var start: Vector2 = main.player.global_position
    var goal := start + Vector2(120, 0)
    _click(main, goal, true)
    _click(main, goal, false)
    for i in 240:
        await process_frame
    print("tap arrived: ", main.player.global_position.distance_to(goal) < 3.0,
        " has_dest=", main.player.has_dest)

    # Tap inside a building: she gives up instead of pushing forever.
    var wall := Vector2(300, 500)
    _click(main, wall, true)
    _click(main, wall, false)
    for i in 600:
        await process_frame
    print("blocked tap gave up: ", not main.player.has_dest, " not inside wall: ",
        not main.blocked_circle(main.player.global_position, 0.0))

    # Holding the pointer keeps steering toward it as it moves.
    main.player.global_position = Vector2(100, 650)
    main.focus = main.player.global_position
    for i in 3:
        await process_frame
    var p0: Vector2 = main.player.global_position
    _click(main, p0 + Vector2(60, 0), true)
    for i in 30:
        await process_frame
    var mid: Vector2 = main.player.global_position
    print("hold moved: ", mid.distance_to(p0) > 5.0)
    _click(main, mid, false)
    quit()
