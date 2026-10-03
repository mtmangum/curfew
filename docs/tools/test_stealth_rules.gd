extends SceneTree
# The core stealth rules: standing in a beam gets you caught (by him reaching you),
# steam and walls block sight, a knocked bin draws a cop, a cat startles, and
# reaching home wins.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_stealth_rules.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    await process_frame
    await process_frame
    var cop = main.cops[0]
    # A stretch of the avenue: the cop at its start facing east, Nicole 60 units ahead.
    var road: Vector2 = Helpers.road_east()
    var cop_pos: Vector2 = road
    var near_pos: Vector2 = road + Vector2(60, 0)

    # 1. cop facing east; stand in the beam
    cop.global_position = cop_pos
    cop.angle = 0.0
    cop.state = cop.State.PATROL
    cop.wait = 100.0
    main.player.global_position = near_pos
    main.dog.global_position = near_pos + Vector2(-10, 5)
    for i in 150:
        await physics_frame
    print("T1 state after standing in cone: ", main.state, " exposure=", cop.exposure)

    # 2. reset, put an active vent between cop and player: LOS must be blocked
    main.state = "play"
    cop.exposure = 0.0
    var v = main.vents[1]
    v.active = true
    v.global_position = road + Vector2(70, 0)  # between them, outside the radius round the cop
    v.t = 0.0
    var far_pos: Vector2 = road + Vector2(125, 0)
    print("T2 los through active vent: ", main.los(cop_pos, far_pos), " (expect false)")
    v.active = false
    print("T2 los no vent: ", main.los(cop_pos, far_pos), " (expect true)")
    var wall: Rect2 = main.buildings[0]
    print("T2 los through wall: ", main.los(Vector2(wall.get_center().x, wall.position.y - 30.0), Vector2(wall.get_center().x, wall.end.y + 30.0)), " (expect false)")

    # 3. knock a bin; a nearby cop investigates
    var cop2 = main.cops[2]
    var bin = main.props[0]
    cop2.global_position = bin.global_position + Vector2(60, 0)
    cop2.state = cop2.State.PATROL
    bin.knock()
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
