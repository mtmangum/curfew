extends SceneTree

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    await process_frame
    var cop = main.cops[0]
    # 1. cop at (80,360) facing east; stand in the beam
    cop.global_position = Vector2(80, 360)
    cop.angle = 0.0
    cop.wp_i = 1
    cop.wait = 100.0
    main.player.global_position = Vector2(140, 360)
    main.dog.global_position = Vector2(130, 365)
    for i in 150:
        await physics_frame
    print("T1 state after standing in cone: ", main.state, " exposure=", cop.exposure)

    # 2. reset, put an active vent between cop and player: LOS must be blocked
    main.state = "play"
    cop.exposure = 0.0
    var v = main.vents[1]
    v.active = true
    v.global_position = Vector2(150, 360)
    v.t = 0.0
    print("T2 los through active vent: ", main.los(Vector2(80, 360), Vector2(140, 360)), " (expect false)")
    v.active = false
    print("T2 los no vent: ", main.los(Vector2(80, 360), Vector2(140, 360)), " (expect true)")
    print("T2 los through wall: ", main.los(Vector2(300, 400), Vector2(300, 500)), " (expect false)")

    # 3. knock a bin; nearby cop investigates
    var cop2 = main.cops[2]
    cop2.global_position = Vector2(520, 560)
    cop2.state = cop2.State.PATROL
    main.props[0].knock()
    print("T3 cop2 state after bin knock: ", cop2.state, " (expect ", cop2.State.INVESTIGATE, ")")

    # 4. cat startled by player
    var cat = main.cats[0]
    main.state = "play"
    main.player.global_position = cat.global_position + Vector2(20, 0)
    for i in 10:
        await physics_frame
    print("T4 cat state: ", cat.state, " (expect ", cat.State.FLEE, ")")

    # 5. win zone
    main.state = "play"
    main.player.global_position = main.home_zone.get_center()
    for i in 5:
        await physics_frame
    print("T5 state at home: ", main.state)
    quit()
