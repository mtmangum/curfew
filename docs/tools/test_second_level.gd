extends SceneTree
# Level 2 reaction time, meaningful warning, escape margin, home band and live traffic.
const Settings := preload("res://scripts/LevelSettings.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")
var shot_dir := OS.get_environment("BRIDGE_SHOTS")

func snapshot(main, name: String) -> void:
    if shot_dir == "" or DisplayServer.get_name() == "headless":
        return
    # A background native test window may have auto-paused on focus loss.
    main.pause_menu.resume()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))

func measure(main, cop, distance: float, sneak: bool) -> Dictionary:
    var road: Vector2 = Helpers.road_east()
    cop.global_position = road
    cop.state = cop.State.PATROL
    cop.exposure = 0.0
    cop.angle = 0.0
    cop.alert_t = 0.0
    cop.winded_t = 0.0
    cop.eat_t = 0.0
    cop.seeing = false
    cop.was_seeing = false
    main.player.global_position = road + Vector2(distance, 0)
    main.dog.global_position = road + Vector2(2000, 0)
    main.player.sneaking = sneak
    main.player.moving = true
    main.player.lit = true
    main.player.dragged_t = 0.0
    main.player.torch_on = false
    main.focus = main.player.global_position
    var warning := -1.0
    for frame in 1200:
        cop._update_detection(1.0 / 60.0)
        cop._update_mark(1.0 / 60.0)
        cop.queue_redraw()
        main._process(0.0)
        var now: float = float(frame + 1) / 60.0
        if distance == 60.0 and not sneak and frame == 20:
            cop._update_beam()
            cop.beam.queue_redraw()
            await snapshot(main, "noticing")
        if warning < 0.0 and cop.mark == "?" and main.hud.patrol_warning.visible:
            warning = now
        if cop.state == cop.State.CHASE:
            if distance == 60.0 and not sneak:
                await snapshot(main, "chase")
            return {"chase": now, "warning": warning, "readable": now - warning}
    return {"chase": INF, "warning": warning, "readable": 0.0}

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 2
    main.home_seed = 0
    main.traffic_enabled = false
    root.add_child(main)
    main.runlog.persist = false
    for i in 3:
        await process_frame
    main.set_process(false)
    main.player.set_process(false)
    main.dog.set_process(false)
    main.traffic_director.set_process(false)
    for list in [main.cops, main.cats, main.npcs]:
        for actor in list:
            actor.set_process(false)
    var bridge: Dictionary = main.settings
    main.hud.title_card.hide()
    main.hud.title_card.modulate.a = 0.0
    var cop = main.cops[0]
    for distance in [60.0, 100.0]:
        var walk: Dictionary = await measure(main, cop, distance, false)
        var sneak: Dictionary = await measure(main, cop, distance, true)
        print("warning at ", distance, ": walking ", walk, ", sneak ", sneak, "  ok: ",
            walk.chase >= 0.75 and walk.chase < 2.0 and walk.warning >= 0.0 and walk.readable >= 0.7
            and sneak.chase > walk.chase and sneak.chase < 3.0)
    print("chase fills HUD and cop bar at actual threshold  ok: ",
        cop.suspicion_progress() == 1.0 and main.hud.patrol_warning_bar.value == 1.0 and cop.mark == "!")
    cop.state = cop.State.PATROL
    cop.exposure = float(bridge.cop_spot_at) * 0.5
    print("half threshold is half displayed progress  ok: ", is_equal_approx(cop.suspicion_progress(), 0.5))
    cop.exposure = 0.0
    cop.seeing = false
    main._process(0.0)
    print("warning clears after sight is broken and suspicion decays  ok: ", not main.hud.patrol_warning.visible)
    # Levels 3+ preserve detection rules but use correctly normalized feedback too.
    main.settings = Settings.for_level(3)
    cop.exposure = cop.SPOT_AT * 0.5
    print("later level threshold display remains accurate  ok: ", is_equal_approx(cop.suspicion_progress(), 0.5))
    main.settings = bridge

    var road: Vector2 = Helpers.road_east()
    cop.global_position = road
    cop.state = cop.State.CHASE
    cop.seeing = true
    cop.chase_t = 0.0
    main.player.global_position = road + Vector2(45, 0)
    for frame in 120:
        main.player.global_position += Vector2(main.player.WALK_SPEED / 60.0, 0)
        cop._update_ai(1.0 / 60.0)
    var gap: float = cop.global_position.distance_to(main.player.global_position)
    print("2 seconds walking away opens 45-unit gap to ", gap, "  ok: ", gap >= 70.0)

    var homes := {}
    var fair := true
    for home_seed in 24:
        main.home_seed = home_seed
        main.builder._choose_home()
        var home: Vector2 = main.home_zone.get_center()
        var away: float = home.distance_to(main.START)
        homes[home] = true
        fair = fair and away >= 2200.0 and away <= 4200.0 and not main.blocked_circle(home, 5.0)
    print("24 home seeds in the bounded band (", homes.size(), " distinct homes)  ok: ", fair and homes.size() >= 3)
    print("phone help remains available; punks/zombies are deferred  ok: ",
        main.phones.size() >= 8 and main.npcs.all(func(n): return n.kind == n.Kind.HOBO) and not bridge.linger)
    main.cats = []
    main.hydrants = []
    main.player.global_position = main.START
    main.dog.global_position = main.START
    main.audio.tension = 0.0
    main.dog.scent_t = 0.0
    main.dog.scent_cd = main.dog._next_scent()
    var first_hint := INF
    for frame in 960:
        main.dog._process(1.0 / 60.0)
        if main.dog.scent_t > 0.0:
            first_hint = float(frame + 1) / 60.0
            break
    print("first scent when free/safe at ", first_hint, " seconds  ok: ", first_hint >= 10.0 and first_hint <= 15.1)
    main.player.global_position = Helpers.free_spot(main, main.START + Vector2(2300, -600))
    main.traffic_director.enabled = true
    main.traffic_director.rng.seed = 1234
    for frame in 180:
        main.traffic_director._process(0.3)
    var nearby: int = main.traffic.filter(func(car): return car.global_position.distance_to(main.player.global_position) < main.traffic_director.ACTIVE_RADIUS).size()
    print("live traffic: ", nearby, " nearby cars, ", main.skaters.size(), " skaters  ok: ",
        nearby > 0 and nearby <= 5 and main.skaters.size() > 0 and main.skaters.size() <= 1)
    main.queue_free()
    await process_frame
    quit()
