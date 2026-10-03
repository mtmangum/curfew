extends SceneTree
# The chase: a cop who sees Nicole runs at her; the game ends when he reaches her,
# not when a bar fills at a distance. She can outpace him at a walk. Barks draw cops.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_chase.gd

func _setup(main, cop) -> void:
    for other in main.cops:
        other.set_process(other == cop)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    main.state = "play"
    cop.exposure = 0.0
    cop.state = cop.State.PATROL
    cop.wait = 100.0
    cop.global_position = Vector2(80, 360)
    cop.angle = 0.0

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    var cop = main.cops[0]

    # 1. Spotted from 100 units away: he runs at her, but she is not caught at once.
    _setup(main, cop)
    main.player.global_position = Vector2(180, 360)
    main.dog.global_position = Vector2(185, 364)
    var start_gap: float = 100.0
    for i in 45:
        await physics_frame
    var gap: float = cop.global_position.distance_to(main.player.global_position)
    print("1. spotted at 100: state=", main.state, " cop is chasing=", cop.chasing, " gap ", snappedf(start_gap, 1.0), " -> ", snappedf(gap, 1.0),
        "  ok: ", main.state == "play" and cop.chasing and gap < start_gap)

    # 2. She walks away at full speed along the avenue; he never catches up.
    _setup(main, cop)
    var p: Vector2 = Vector2(150, 360)
    main.player.global_position = p
    main.dog.global_position = p
    var min_gap := 999.0
    for i in 360:
        await physics_frame
        p = main.slide(p, Vector2(85.0 / 60.0, 0.0), 5.0)
        main.player.global_position = p
        main.dog.global_position = p
        min_gap = minf(min_gap, cop.global_position.distance_to(p))
    print("2. 6s of walking away: state=", main.state, " closest he got ", snappedf(min_gap, 1.0), "  ok: ", main.state == "play" and min_gap > 20.0)

    # 3. She stands still; he reaches her and it is over.
    _setup(main, cop)
    main.player.global_position = Vector2(150, 360)
    main.dog.global_position = Vector2(150, 360)
    for i in 180:
        await physics_frame
    print("3. standing still in front of him: state=", main.state, "  ok: ", main.state == "caught")

    # 4. A bark near a cop sends him over (or after her).
    _setup(main, cop)
    main.player.global_position = Vector2(300, 500)  # parked in a building, out of sight
    main.dog.global_position = Vector2(150, 360)
    cop.global_position = Vector2(80, 360)
    cop.angle = PI  # facing away
    await physics_frame  # let him stop believing he can see her from the last test
    await physics_frame
    main.noise(main.dog.global_position, main.dog.BARK_NOISE, false)
    for i in 10:
        await physics_frame
    print("4. bark 70 units from a cop: state=", cop.state, "  ok: ", cop.state == cop.State.INVESTIGATE or cop.state == cop.State.CHASE)
    # 5. A glimpse: she is in his beam for a moment, then slips out of sight. He goes
    #    to where he saw her instead of carrying on with his patrol.
    _setup(main, cop)
    cop.wait = 0.0
    cop.wp_i = 1  # patrolling away from her, east to the next waypoint
    main.player.global_position = Vector2(170, 360)
    main.dog.global_position = Vector2(175, 364)
    for i in 8:
        await physics_frame
    main.player.global_position = Vector2(300, 500)  # ducks into a building, out of sight
    main.dog.global_position = Vector2(300, 500)
    for i in 20:
        await physics_frame
    var gap_after: float = cop.global_position.distance_to(Vector2(170, 360))
    print("5. a glimpse: state=", cop.state, " cop is ", snappedf(gap_after, 1.0), " from where she was seen",
        "  ok: ", cop.state == cop.State.INVESTIGATE or cop.state == cop.State.CHASE)
    quit()

