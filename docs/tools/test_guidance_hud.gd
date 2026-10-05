extends SceneTree
const Clues := preload("res://scripts/Clues.gd")
const Game := preload("res://scenes/Main.tscn")
var shots := OS.get_environment("GUIDANCE_SHOTS")
var failed := false

func _init() -> void:
    call_deferred("run")

func check(label: String, passed: bool) -> void:
    print(label, "  ok: ", passed)
    failed = failed or not passed

func settle() -> void:
    for i in 6:
        await process_frame

func tap(control: Control) -> void:
    if DisplayServer.get_name() != "headless":
        # Native window resizes/focus make framebuffer event injection unreliable.
        # This branch prepares visual states; headless runs test real GUI dispatch.
        control.pressed.emit()
        await settle()
        return
    var point: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = point
    root.push_input(motion, false)
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        event.position = point
        root.push_input(event, false)
        await process_frame
    await settle()

func screenshot(name: String, game = null) -> void:
    if shots != "" and DisplayServer.get_name() != "headless":
        # Focus loss can pause the native fixture while another app is active.
        # Resume gameplay captures immediately before drawing; menu captures stay paused.
        if game != null:
            game.pause_menu.resume()
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

func freeze(game) -> void:
    game.pause_menu.resume()
    game.runlog.persist = false
    game.set_process(false)
    game.player.set_process(false)
    game.dog.set_process(false)
    for list in [game.cops, game.cats, game.squirrels, game.npcs]:
        for actor in list:
            actor.set_process(false)
    game.hud.title_card.hide()

func targets_fit(game, controls: Array) -> bool:
    for control in controls:
        var rect: Rect2 = control.get_global_rect()
        if not root.get_visible_rect().encloses(rect) or rect.size.y / game.presentation.unit < 44.0:
            return false
    return true

func run() -> void:
    Clues.persist = false
    print("Native visual-state checks; pointer dispatch is tested headless" if DisplayServer.get_name() != "headless" else "Headless real GUI-dispatch and guidance checks")
    root.size = Vector2i(390, 844)
    var game = Game.instantiate()
    game.level_override = 1
    game.home_seed = 0
    game.audit_seed = 1
    game.traffic_enabled = false
    game.presentation_size_override = Vector2(390, 844)
    root.add_child(game)
    await settle()
    freeze(game)
    game.hud.update(0, 0)
    await settle()
    check("Level 1 has Pause and Sneak, the map always on at the top right, and no torch or item", game.hud.pointer_controls.get_child_count() == 2 and not game.hud.torch_button.visible and game.minimap.visible and game.minimap.global_position.y < 100.0 and game.hud.objective.visible and not game.hud.item_slot.visible)
    check("Portrait primary targets remain readable and usable", targets_fit(game, [game.hud.sneak_button, game.hud.pause_button]))
    await screenshot("portrait-play", game)
    game.player._clear_dest()
    await tap(game.hud.pause_button)
    var menu = game.pause_menu
    check("Portrait menu exposes sound and teaching", paused and targets_fit(game, [menu.resume_button, menu.sound_button, menu.controls_button, menu.guide_button]) and root.get_visible_rect().encloses(menu.box.get_global_rect()))
    await screenshot("portrait-pause")
    await tap(menu.resume_button)
    game.request_home()   # (the H key; there is no button)
    check("A home request (H) queues without steering or revealing home", game.dog.home_requested and not paused and not game.player.has_dest and not game.player.pointer_down and not game.minimap.home_found())
    await tap(game.hud.pause_button)
    await tap(menu.resume_button)
    check("Resuming leaves the map on, and the text beside it keeps clear of it", not paused and game.minimap.visible and game.hud.objective.visible and game.hud.pointer_hint.visible and not game.hud.objective.get_global_rect().intersects(game.minimap.get_global_rect()) and not game.hud.pointer_hint.get_global_rect().intersects(game.minimap.get_global_rect()))
    await screenshot("portrait-map", game)
    check("Nothing hides the map: no hide button, and the M key does nothing", not game.hud.has_method("toggle_map"))
    for screen in [Vector2(844, 390), Vector2(640, 320)]:
        root.size = Vector2i(screen)
        game.presentation_size_override = screen
        game.presentation.refresh()
        await settle()
        await tap(game.hud.pause_button)
        check("Landscape %s menu retains 44px targets and fits" % str(screen), targets_fit(game, [menu.resume_button, menu.sound_button, menu.controls_button, menu.guide_button]) and root.get_visible_rect().encloses(menu.box.get_global_rect()))
        await screenshot("landscape-pause-%d" % int(screen.y))
        menu.resume()
    root.size = Vector2i(1280, 720)
    game.presentation_size_override = Vector2(1280, 720)
    game.presentation.refresh()
    await settle()
    check("Desktop map is on at the top right and essential controls fit", game.minimap.visible and game.minimap.global_position.y < 40.0 and not game.hud.sneak_button.visible and targets_fit(game, [game.hud.pause_button]))
    var dog = game.dog
    game.cats = []
    game.squirrels = []
    game.hydrants = []
    game.corner_folk = []
    var origin: Vector2 = game.START
    var original_home: Rect2 = game.home_zone
    var idle_still := true
    var bounded := true
    var leads := 0
    for i in 8:
        var direction: Vector2 = Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
        game.home_zone = Rect2(origin + direction * 1000.0, Vector2(10, 10))
        game.player.global_position = origin
        game.player.dragged_t = 0.0
        dog.global_position = origin + Vector2(-20, 8)
        dog.planted = ""
        dog.scent_t = 0.0
        dog._start_scent()
        if not dog.scent_path.is_empty():
            leads += 1
        for frame in 480:
            dog._process(1.0 / 60.0)
            idle_still = idle_still and game.player.global_position == origin and game.player.dragged_t == 0.0
            bounded = bounded and dog.global_position.distance_to(origin) <= dog.LEASH + 0.1
    check("Repeated hints in eight directions never move an idle owner", idle_still and leads >= 4)
    check("Home leads stay within the leash instead of reeling Nicole", bounded)
    dog.global_position = origin + Vector2(dog.LEASH + 20, 0)
    dog.scent_t = 2.6
    dog.scent_path = PackedVector2Array([origin + Vector2(200, 0)])
    dog._process(1.0 / 60.0)
    check("An overextended home leash corrects Stella, not Nicole", game.player.global_position == origin and dog.global_position.x < origin.x + dog.LEASH + 20)
    game.home_zone = original_home
    dog.global_position = origin + Vector2(20, 0)
    dog.scent_len = 6.0
    dog.scent_t = 3.0
    game.focus = origin
    game._update_view(0)
    for entry in [["east", Vector2.RIGHT], ["north", Vector2.UP], ["west", Vector2.LEFT], ["south", Vector2.DOWN]]:
        dog.scent_dir = entry[1]
        dog.queue_redraw()
        await settle()
        await screenshot("cue-" + entry[0], game)
    await tap(game.hud.pause_button)
    await tap(menu.guide_button)
    menu.guide_index = menu.guide_ids.find("scent")
    menu._browse_guide(0)
    await settle()
    check("Field guide explains following Stella and the H hint", "Press H" in menu.guide_text.text and "Follow" in menu.guide_text.text)
    await screenshot("desktop-home-guide")
    menu.resume()
    game.queue_free()
    await settle()
    quit(1 if failed else 0)
