extends SceneTree
# Cars drive the roads. One that hits Nicole or Stella ends the run; standing beside
# the road is safe; a horn goes up when she's in the way, and cops hear it.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_traffic.gd

func _calm(main) -> void:
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = 1
    root.add_child(main)
    for i in 3:
        await process_frame
    _calm(main)
    print("cars on the road: ", main.traffic.size(), "  ok: ", main.traffic.size() > 30)

    var car = main.traffic[7]
    var ahead: Vector2 = car.heading * 140.0

    # 1. Cars move.
    main.player.global_position = car.position + ahead * 4.0 + car.heading.orthogonal() * 400.0  # nearby, but out of the way
    main.dog.global_position = main.player.global_position
    var p0: Vector2 = car.position
    for i in 30:
        await physics_frame
    print("1. a car moves: ", snappedf(car.position.distance_to(p0), 1.0), " units in half a second  ok: ", car.position.distance_to(p0) > 30.0)

    # 2. Standing in its path: run over.
    car.position = p0
    var lane_point: Vector2 = car.position + ahead
    main.player.global_position = lane_point
    main.dog.global_position = lane_point + car.heading.orthogonal() * 120.0
    main.state = "play"
    var cop = main.cops[0]
    cop.global_position = car.position + car.heading.orthogonal() * 150.0
    cop.state = cop.State.PATROL
    cop.set_process(false)
    for i in 150:
        await physics_frame
        if main.state != "play":
            break
    print("2. stood in its way: state=", main.state, " banner=", main.banner_title.text, "  ok: ", main.state == "caught" and main.banner_title.text == "RUN OVER")
    print("   the horn reached a nearby cop: cop state=", cop.state, "  ok: ", cop.state == cop.State.INVESTIGATE)

    # 3. Stella in its path while Nicole is safe: still run over.
    main.state = "play"
    main.banner.visible = false
    car.position = p0
    car.rect = Rect2(car.position + car.local_rect.position, car.local_rect.size)
    main.player.global_position = car.position + ahead + car.heading.orthogonal() * 200.0
    main.dog.global_position = car.position + ahead
    for i in 150:
        await physics_frame
        if main.state != "play":
            break
    print("3. Stella in its way: state=", main.state, "  ok: ", main.state == "caught")

    # 4. Standing beside the road while it passes: safe.
    main.state = "play"
    car.position = p0
    car.rect = Rect2(car.position + car.local_rect.position, car.local_rect.size)
    main.player.global_position = car.position + ahead + car.heading.orthogonal() * 45.0
    main.dog.global_position = main.player.global_position + car.heading * 10.0
    for i in 150:
        await physics_frame
    print("4. beside the road as it passes: state=", main.state, "  ok: ", main.state == "play")
    quit()
