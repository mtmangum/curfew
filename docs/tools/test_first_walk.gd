extends SceneTree
# Optional practice uses the real generated city, pickup, patrol and win flow.
const Clues := preload("res://scripts/Clues.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")
var shots := OS.get_environment("FIRST_WALK_SHOTS")

func _init() -> void:
    call_deferred("run")

func settle() -> void:
    for i in 5:
        await process_frame

func snapshot(name: String) -> void:
    if shots != "" and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

func build(level: int):
    var game = load("res://scenes/Main.tscn").instantiate()
    game.level_override = level
    game.home_seed = 1
    game.traffic_enabled = false
    root.add_child(game)
    game.runlog.persist = false
    await settle()
    game.pause_menu.resume()
    game.set_process(false)
    for actor in game.actors.get_children():
        actor.set_process(false)
    for i in 270:
        await process_frame
    game.hud.title_card.hide()
    game.hud.title_card.modulate.a = 0.0
    game.clues.elapsed = 10.0
    game.clues.last_at = -100.0
    return game

func run() -> void:
    Clues.persist = false
    Clues.seen.clear()
    var main = await build(1)
    var treat
    for item in main.item_pickups:
        if item.kind == "treat" and item.global_position.distance_to(main.START) < 150.0:
            treat = item
            break
    print("nearby treat has an unobstructed walk from the starting plaza  ok: ", treat != null and main.builder._practice_line_clear(main.START, treat.global_position, 10.0))
    if treat == null:
        quit(1)
        return
    print("treat position: ", treat.global_position, " distance: ", treat.global_position.distance_to(main.START))
    await snapshot("starting-treat")

    var cop
    for candidate in main.cops:
        if candidate.waypoints.size() == 2:
            cop = candidate
            break
    print("one existing cop offers a short optional patrol  ok: ", cop != null and main.cops.filter(func(c): return c.waypoints.size() == 2).size() == 1)
    if cop == null:
        quit(1)
        return
    print("practice patrol: ", cop.waypoints, " distance: ", cop.global_position.distance_to(main.START))
    var clear := true
    for i in 71:
        var point: Vector2 = cop.waypoints[0].lerp(cop.waypoints[1], float(i) / 70.0)
        clear = clear and point.distance_to(main.START) >= main.builder.SAFE_COPS and not main.blocked_circle(point, cop.RADIUS) and not main.home_zone.grow(60).has_point(point)
    print("full patrol stays on clear pavement outside the 1000-unit safe zone and door  ok: ", clear)
    var moved := 0.0
    for i in 1800:
        var before: Vector2 = cop.global_position
        cop._update_ai(1.0 / 60.0)
        cop._update_detection(1.0 / 60.0)
        moved += before.distance_to(cop.global_position)
    print("30 seconds of actual patrol movement preserves a safe start without getting stuck  ok: ", moved > 600 and main.state == "play" and cop.exposure == 0.0)

    main.player.global_position = treat.global_position
    treat._process(0.016)
    print("real walk-over pickup carries and explains the treat  ok: ", main.carried == "treat" and main.clues.current_id == "item_treat")
    main.use_item()
    print("using the optional treat activates its 30-second effect  ok: ", main.carried == "" and main.items.treat_on() and main.items.treat_t == 30.0)
    main.hud.toast.text = ""
    main.clues.cancel()
    var direction: Vector2 = cop.waypoints[0].direction_to(cop.waypoints[1])
    cop.global_position = cop.waypoints[0]
    cop.angle = direction.angle()
    main.player.global_position = cop.global_position - direction * 160.0
    main.dog.global_position = main.player.global_position + Vector2(-20, 8)
    main.focus = main.player.global_position
    main._update_view(0.0)
    cop.seeing = false
    main.clues.last_at = -100
    main.clues.notice_patrol(cop)
    print("calm visible patrol is explained before entering its beam  ok: ", main.clues.current_id == "patrol" and "Sneak" in main.hud.clue_label.text and cop.exposure == 0.0)
    for i in 70:
        main.depth.sort()
        main.depth.fade_buildings(1.0 / 60.0)
        await process_frame
    cop._update_beam()
    await snapshot("optional-patrol")
    main.clues.cancel()
    main.player.global_position = Helpers.hide_spot(main, cop.global_position)
    main.focus = main.player.global_position
    main._update_view(0.0)
    main.clues.notice_patrol(cop)
    print("an occluded patrol does not announce itself through a wall  ok: ", main.clues.current_id == "")

    # No practice-completion flag exists: reaching home always clears the level.
    main.player.global_position = main.home_zone.get_center()
    main.dog.global_position = main.player.global_position + Vector2(-20, 8)
    main.focus = main.player.global_position
    main.carried = ""
    main.items.treat_t = 0.0
    main._process(0.016)
    main.hud.update(0.0, 0.0)
    for i in 70:
        await process_frame
    print("home clears without carrying an item or completing practice  ok: ", main.state == "won" and "Stella still knows" in main.hud.banner_sub.text)
    for screen in [Vector2(390, 844), Vector2(844, 390)]:
        root.size = Vector2i(screen)
        main.presentation_size_override = screen
        main.presentation.refresh()
        await settle()
        print("banner bounds: ", main.hud.banner_box.get_global_rect(), " viewport: ", root.get_visible_rect(), " alpha: ", main.hud.banner_sub.modulate.a)
        print("banner minima: title ", main.hud.banner_title.get_combined_minimum_size(), " sub ", main.hud.banner_sub.get_combined_minimum_size(), " box ", main.hud.banner_box.get_combined_minimum_size())
        print("next-walk card fits ", screen, " with readable steady text  ok: ", root.get_visible_rect().encloses(main.hud.banner_box.get_global_rect()) and main.hud.banner_sub.get_theme_font_size("font_size") >= 16 and main.hud.banner_sub.modulate.a == 1.0 and main.hud.banner_sub.text.ends_with("Tap to continue"))
        await snapshot("next-walk-%dx%d" % [screen.x, screen.y])
    main.queue_free()
    await process_frame
    var two = await build(2)
    print("level 2 retains ordinary item and patrol placement  ok: ", two.item_pickups.all(func(i): return i.global_position.distance_to(two.START) > 300.0) and two.cops.all(func(c): return c.waypoints.size() == 4))
    two._win()
    await settle()
    print("level 3 preview explains the torch tradeoff and moving past zombies  ok: ", "switch it off near cops" in two.hud.banner_sub.text and "zombie hobos" in two.hud.banner_sub.text)
    two.queue_free()
    await process_frame
    quit()
