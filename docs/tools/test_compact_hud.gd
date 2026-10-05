extends SceneTree
# Real GUI dispatch, screen-sized target/text checks, rotation during pause,
# movement mapping, readable clue layout and unobstructed retry hit targets.
const Clues := preload("res://scripts/Clues.gd")
const Items := preload("res://scripts/Items.gd")
var shots := OS.get_environment("COMPACT_SHOTS")

func _init() -> void:
    call_deferred("run")

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

func snapshot(name: String) -> void:
    if shots == "" or DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

func settle() -> void:
    for i in 5:
        await process_frame

func sized(main, screen: Vector2) -> void:
    root.size = Vector2i(screen)
    main.presentation_size_override = screen
    main.presentation.refresh()
    await settle()

func controls_fit(main) -> bool:
    var visible := []
    for c in [main.hud.sneak_button, main.hud.torch_button, main.hud.pause_button, main.hud.item_slot]:
        if c.visible:
            visible.append(c)
    var fits := true
    for i in visible.size():
        var box: Rect2 = visible[i].get_global_rect()
        fits = fits and root.get_visible_rect().encloses(box) and box.size.x / main.presentation.unit >= 44.0 and box.size.y / main.presentation.unit >= 44.0
        for j in range(i + 1, visible.size()):
            fits = fits and not box.intersects(visible[j].get_global_rect())
    return fits

func run() -> void:
    Clues.persist = false
    root.size = Vector2i(390, 844)
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 3
    main.home_seed = 1
    main.traffic_enabled = false
    main.presentation_size_override = Vector2(390, 844)
    root.add_child(main)
    main.runlog.persist = false
    await settle()
    main.pause_menu.resume()
    main.dog.set_process(false)
    main.player.set_process(false)
    for actors in [main.cops, main.cats, main.squirrels, main.npcs]:
        for actor in actors:
            actor.set_process(false)
    main.carried = "treat"
    main.hud.update_item()
    await settle()
    var hud = main.hud
    print("portrait fills the screen with independent UI units  ok: ", main.presentation.compact and root.get_visible_rect().size.is_equal_approx(Vector2(585, 1266)) and hud.ui.size.is_equal_approx(Vector2(390, 844)))
    print("portrait primary targets are at least 44px, contained and distinct  ok: ", controls_fit(main) and hud.item_slot.size.y == 56 and main.minimap.visible)
    print("portrait goal and pointer hint use readable fonts, no key strip  ok: ", hud.objective.get_theme_font_size("font_size") >= 16 and hud.pointer_hint.get_theme_font_size("font_size") >= 16 and hud.pointer_hint.visible and not hud.hints.visible)
    main.hud.title_card.hide()
    await snapshot("portrait-game")
    main.player._clear_dest()
    main.player.pointer_down = true
    await tap(hud.sneak_button)
    var sneaked: bool = main.sneak_toggle
    await tap(hud.torch_button)
    await tap(hud.pause_button)
    await tap(main.pause_menu.resume_button)
    var mapped: bool = main.minimap.visible  # the map is always on, top right
    await tap(hud.item_slot)
    print("portrait taps sneak, torch, map and item without steering  ok: ", sneaked and not main.player.torch_on and mapped and main.carried == "" and main.items.treat_on() and not main.player.has_dest and not main.player.pointer_down)
    # Longest item explanation; inspect actual wrapped height rather than fixed assumptions.
    hud.show_clue("item_extinguisher", Items.INFO.extinguisher.text, 7.0)
    for i in 25:
        await process_frame
    var card: Rect2 = hud.clue_panel.get_global_rect()
    print("portrait long clue wraps, fits, and avoids controls  ok: ", root.get_visible_rect().encloses(card) and hud.clue_label.get_theme_font_size("font_size") == 16 and "Tap the item" in hud.clue_label.text and not card.intersects(hud.item_slot.get_global_rect()) and card.size.y / main.presentation.unit < 160)
    await snapshot("portrait-clue")
    await tap(hud.pause_button)
    await tap(main.pause_menu.controls_button)
    await snapshot("portrait-controls-help")
    await sized(main, Vector2(844, 390))
    print("rotation while paused reflows both HUD and menu  ok: ", paused and hud.ui.size.is_equal_approx(Vector2(844, 390)) and controls_fit(main) and root.get_visible_rect().encloses(main.pause_menu.box.get_global_rect()))
    print("landscape help retains readable text and touch targets  ok: ", main.pause_menu.help_label.get_theme_font_size("font_size") == 16 and main.pause_menu.box.scale.y / main.presentation.unit >= 0.99 and main.pause_menu.resume_button.size.y >= 48)
    print("landscape help box: ", main.pause_menu.box.get_global_rect(), ", unit ", main.presentation.unit, ", scale ", main.pause_menu.box.scale)
    await snapshot("landscape-controls-help")
    await tap(main.pause_menu.back_button)
    await tap(main.pause_menu.sound_button)
    await tap(main.pause_menu.resume_button)
    AudioServer.set_bus_mute(0, false)
    await settle()
    main.pause_menu.resume()
    print("landscape resumes through the same pointer-only menu  ok: ", not paused and not main.player.has_dest and main.presentation.compact and controls_fit(main))
    hud.show_clue("scent", Clues.CATALOG.scent.text, 7.0)
    for i in 25:
        await process_frame
    card = hud.clue_panel.get_global_rect()
    print("landscape clue fits above the item  ok: ", root.get_visible_rect().encloses(card) and not card.intersects(hud.item_slot.get_global_rect()))
    await snapshot("landscape-clue")
    # A ground tap still inverts the resized camera, rather than applying UI scale.
    main.player._clear_dest()
    var target: Vector2 = main.player.global_position + Vector2(55, 0)
    var pointer: Vector2 = root.canvas_transform * target
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = pointer
    root.push_input(event, true)
    await process_frame
    print("resized ground tap maps to the intended world destination  ok: ", main.player.has_dest and main.player.dest.distance_to(target) < 1.0)
    event.pressed = false
    root.push_input(event, true)
    main.player._clear_dest()
    # Compact -> desktop -> compact: no stale anchors or double scale.
    await sized(main, Vector2(1280, 720))
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_H
    root.push_input(key, true)
    await settle()
    print("desktop restores keyboard hints and framing with the map on at the top right  ok: ", not main.presentation.compact and hud.ui.scale == Vector2.ONE and hud.hints.visible and not hud.pointer_hint.visible and main.minimap.visible and main.minimap.global_position.y < 40.0 and controls_fit(main))
    await sized(main, Vector2(390, 844))
    main._lose("CAUGHT")
    for i in 35:
        await process_frame
    print("compact end banner is readable and leaves retry taps unobstructed  ok: ", not hud.pause_button.visible and not main.minimap.visible and not hud.item_slot.visible and not hud.clue_layer.visible and not hud.toast.visible and root.get_visible_rect().encloses(hud.banner_box.get_global_rect()) and hud.banner_sub.get_theme_font_size("font_size") == 16)
    print("retry box: ", hud.banner_box.get_global_rect(), ", viewport ", root.get_visible_rect(), ", pause/map/item ", [hud.pause_button.visible, main.minimap.visible, hud.item_slot.visible])
    await snapshot("portrait-retry")
    # The banner's center must reach Main's retry handler through the GUI.
    current_scene = main
    main.ended_at = Time.get_ticks_msec() - 1000
    var old_scene: WeakRef = weakref(main)
    await tap(hud.banner_sub)
    for i in 8:
        await process_frame
    main = current_scene
    print("compact retry prompt dispatches a real scene restart  ok: ", old_scene.get_ref() == null and main != null and main.is_booted and main.state == "play" and main.home_seed == 1)
    main.runlog.persist = false
    main.retry_seed = -1
    main.retry_state = {}
    main.retry_pos = Vector2.INF
    main.queue_free()
    await settle()
    # Fresh landscape boot, not just rotation from the portrait instance.
    root.size = Vector2i(844, 390)
    main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 1
    main.traffic_enabled = false
    main.presentation_size_override = Vector2(844, 390)
    root.add_child(main)
    await settle()
    main.pause_menu.resume()
    main.dog.set_process(false)
    print("fresh landscape boot has a readable goal and essential controls  ok: ", main.is_booted and main.presentation.compact and controls_fit(main) and not main.hud.torch_button.visible and main.hud.pointer_hint.visible)
    main.hud.title_card.hide()
    await snapshot("landscape-first-visit")
    await sized(main, Vector2(390, 844))
    await snapshot("portrait-first-visit")
    main.queue_free()
    await settle()
    quit()
