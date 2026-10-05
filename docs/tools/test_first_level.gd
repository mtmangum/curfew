extends SceneTree
# Exercise reaction, escape, guidance and real traffic in the browser introduction.
const Settings := preload("res://scripts/LevelSettings.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")
const Clues := preload("res://scripts/Clues.gd")

func _init() -> void:
    call_deferred("run")

func warning_time(main, cop, settings: Dictionary) -> float:
    main.settings = settings
    cop.state = cop.State.PATROL
    cop.exposure = 0.0
    cop.alert_t = 0.0
    cop.winded_t = 0.0
    cop.was_seeing = false
    cop.angle = 0.0
    for f in 600:
        cop._update_detection(1.0 / 60.0)
        if cop.state == cop.State.CHASE:
            return float(f + 1) / 60.0
    return INF

func run() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
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
    for list in [main.cops, main.cats, main.squirrels]:
        for actor in list:
            actor.set_process(false)
    var first: Dictionary = main.settings
    print("selected home has a clear door  ok: ", not main.blocked_circle(main.home_zone.get_center(), 5.0))
    var cop = main.cops[0]
    var road: Vector2 = Helpers.road_east()
    cop.global_position = road
    main.player.global_position = road + Vector2(60, 0)
    main.dog.global_position = main.player.global_position
    main.player.sneaking = false
    main.player.dragged_t = 0.0
    main.player.moving = true
    main.player.lit = true  # conspicuous walking, rather than a stationary actor in shadow
    var gentle: float = warning_time(main, cop, first)
    var normal: float = warning_time(main, cop, Settings.for_level(3))
    print("visible at 60 units: warning ", gentle, "s vs level 3 ", normal, "s  ok: ",
        gentle >= 0.5 and gentle < 3.0 and gentle > normal * 3.0)
    print("level 3+ retain default chase and detection thresholds  ok: ",
        not Settings.for_level(3).has("cop_chase_speed") and not Settings.for_level(3).has("cop_spot_at")
        and not Settings.for_level(5).has("cop_chase_speed"))

    # After a mistake, walking away creates room rather than losing it.
    main.settings = first
    cop.state = cop.State.CHASE
    cop.seeing = true
    cop.global_position = road
    main.player.global_position = road + Vector2(45, 0)
    main.dog.global_position = main.player.global_position
    cop.target = main.player.global_position
    cop.chase_t = 0.0
    for f in 120:
        main.player.global_position += Vector2(main.player.WALK_SPEED / 60.0, 0)
        main.dog.global_position = main.player.global_position
        cop._update_ai(1.0 / 60.0)
    var gap: float = cop.global_position.distance_to(main.player.global_position)
    print("walking away for 2 seconds opens the 45-unit gap to ", gap, "  ok: ", gap > 75.0)

    # Check the actual home chooser, not just the configured distance numbers.
    var homes := {}
    var fair := true
    for home_seed in 24:
        main.home_seed = home_seed
        main.builder._choose_home()
        var home: Vector2 = main.home_zone.get_center()
        var away: float = home.distance_to(main.START)
        homes[home] = true
        fair = fair and away >= 1400.0 and away <= 2200.0
    print("24 home seeds choose the nearby band (", homes.size(), " different homes)  ok: ", fair and homes.size() >= 3)

    main.cats = []
    main.squirrels = []
    main.hydrants = []
    main.player.global_position = main.START
    main.dog.global_position = main.START
    main.audio.tension = 0.0
    main.dog.scent_cd = main.dog._next_scent()
    main.dog.scent_t = 0.0
    Clues.seen["scent"] = true
    var first_hint := INF
    for f in 900:
        main.dog._process(1.0 / 60.0)
        if main.dog.scent_t > 0.0:
            first_hint = float(f + 1) / 60.0
            break
    print("first useful scent when free and safe at ", first_hint, "s  ok: ", first_hint >= 8.0 and first_hint <= 14.1)

    main.player.global_position = Helpers.free_spot(main, main.START + Vector2(2300, -600))
    main.traffic_director.enabled = true
    for f in 180:
        main.traffic_director._process(0.3)
    var nearby := 0
    for car in main.traffic:
        if car.global_position.distance_to(main.player.global_position) < main.traffic_director.ACTIVE_RADIUS:
            nearby += 1
    print("real traffic spawning: ", nearby, " nearby cars and ", main.skaters.size(), " skaters  ok: ",
        main.traffic.size() > 0 and nearby <= 2 and main.skaters.is_empty())
    main.queue_free()
    await process_frame
    quit()
