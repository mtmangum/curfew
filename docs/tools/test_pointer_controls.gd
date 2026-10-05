extends SceneTree
# Exercise real GUI dispatch: action taps must not also become world destinations.
var shot_dir := OS.get_environment("POINTER_SHOTS")

func snapshot(name: String) -> void:
    if shot_dir == "" or DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))

func tap(control: Control) -> void:
    var at: Vector2 = control.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion, true)
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        event.position = at
        root.push_input(event, true)
        await process_frame

func _init() -> void:
    call_deferred("run")

func run() -> void:
    if OS.get_environment("POINTER_SMALL_WINDOW") == "1":
        root.size = Vector2i(390, 844)
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 3
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for cop in main.cops:
        cop.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    var hud = main.hud
    main.player._clear_dest()
    # A released movement touch over a UI button must not leave hold-to-steer latched.
    main.player.pointer_down = true
    print("1. on a computer there is no sneak button (Shift sneaks; the phone layout keeps one)  ok: ", not hud.sneak_button.visible)
    main.sneak_toggle = true
    main.player.set_process(true)
    await process_frame
    print("2. toggle reaches actual player sneak  ok: ", main.player.sneaking)
    main.player.set_process(false)
    main.sneak_toggle = false
    print("3. releasing the toggle releases sneak  ok: ", not main.sneak_toggle)
    var torch_before: bool = main.player.torch_on
    await tap(hud.torch_button)
    print("4. dark-level torch tap changes light without walking  ok: ", main.player.torch_on != torch_before and not main.player.has_dest)
    # Keyboard and button state stay in step.
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_F
    main._unhandled_input(key)
    await process_frame
    print("5. keyboard torch state reflected on button  ok: ", hud.torch_button.button_pressed == main.player.torch_on)
    await snapshot("dark-controls")
    await tap(hud.pause_button)
    var before_t: float = main.runlog.t
    for i in 15:
        await physics_frame
    print("6. pause tap freezes game and clock  ok: ", paused and main.pause_menu.layer.visible and main.runlog.t == before_t)
    await snapshot("paused")
    var mute_before: bool = AudioServer.is_bus_mute(0)
    await tap(main.pause_menu.sound_button)
    print("7. sound control works while paused  ok: ", paused and AudioServer.is_bus_mute(0) != mute_before)
    AudioServer.set_bus_mute(0, mute_before)
    await tap(main.pause_menu.resume_button)
    print("8. Resume works through GUI while paused, without setting a destination  ok: ", not paused and not main.pause_menu.layer.visible and not main.player.has_dest)
    main.player.pointer_down = true
    main.pause_menu._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    var released: bool = not main.player.pointer_down
    await tap(main.pause_menu.resume_button)
    print("9. auto-pause releases held steering and has pointer-only recovery  ok: ", released and not paused)
    main.carried = "treat"
    hud.update_item()
    await process_frame
    await tap(hud.item_slot)
    print("9b. item slot still uses the treat without walking  ok: ", main.carried == "" and main.items.treat_on() and not main.player.has_dest)
    for code in [KEY_ESCAPE, KEY_P]:
        key.keycode = code
        root.push_input(key, true)
        await process_frame
    print("9c. Esc and P still pause and resume through input dispatch  ok: ", not paused)
    # The controls must never cover or steal a retry tap.
    main.carried = "treat"
    main._lose("CAUGHT")
    for i in 3:
        await process_frame
    print("10. end banner hides action and item hit targets  ok: ", not hud.pointer_controls.visible and not hud.item_slot.visible)
    main.queue_free()
    for i in 3:
        await process_frame
    main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    print("11. fresh level resets sneak and omits unnecessary torch  ok: ", not main.sneak_toggle and not main.hud.torch_button.visible and main.hud.pointer_controls.visible)
    var actions: Rect2 = main.hud.pointer_controls.get_global_rect()
    var slot: Rect2 = main.hud.item_slot.get_global_rect()
    var pause_rect: Rect2 = main.hud.pause_button.get_global_rect()
    print("control rectangles: actions ", actions, ", pause ", pause_rect, ", slot ", slot, ", map ", main.minimap.get_global_rect(), ", view ", root.get_visible_rect())
    print("12. controls fit viewport, Pause sits in the row with them, and they avoid map/item slot  ok: ", root.get_visible_rect().encloses(actions) and root.get_visible_rect().encloses(pause_rect) and not actions.intersects(slot) and not pause_rect.intersects(slot) and actions.encloses(pause_rect) and not pause_rect.intersects(main.minimap.get_global_rect()) and not actions.intersects(main.minimap.get_global_rect()))
    await snapshot("first-level-controls")
    main.queue_free()
    for i in 3:
        await process_frame
    quit()
