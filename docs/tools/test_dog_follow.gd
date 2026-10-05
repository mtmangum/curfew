extends SceneTree
# Regression: a following Stella must walk round a parked car rather than pinning
# Nicole to a taut leash indefinitely. Distraction and scent behavior have their own checks.
const Follow := preload("res://scripts/DogFollow.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    main.runlog.persist = false
    for i in 3:
        await process_frame
    main.set_process(false)
    main.player.set_process(false)
    main.dog.set_process(false)
    for list in [main.cops, main.cats, main.squirrels]:
        for actor in list:
            actor.set_process(false)
    main.cats = []
    main.squirrels = []
    main.hydrants = []
    main.dog.scent_cd = 999.0
    var from := Vector2.INF
    var owner := Vector2.INF
    for car in main.cars:
        if car.size != Vector2(20, 40):
            continue
        var at: Vector2 = Vector2(car.get_center().x, car.end.y + main.dog.RADIUS + 0.2)
        var to: Vector2 = at - Vector2(0, 79)
        if not main.blocked_circle(at, main.dog.RADIUS) and not main.blocked_circle(to, main.player.RADIUS) \
                and not Follow.path(main, at, to, main.dog.RADIUS).is_empty():
            from = at
            owner = to
            break
    print("found a real parked-car detour  ok: ", from != Vector2.INF)
    if from == Vector2.INF:
        quit(1)
        return
    main.dog.global_position = from
    main.player.global_position = owner
    print("car fixture: dog ", from, ", owner ", owner)
    var clipped := false
    var widest := 0.0
    var path_size := 0
    var freed_at := INF
    for f in 480:
        main.dog._process(1.0 / 60.0)
        clipped = clipped or main.blocked_circle(main.dog.global_position, main.dog.RADIUS)
        widest = maxf(widest, main.dog.global_position.distance_to(main.player.global_position))
        path_size = maxi(path_size, main.dog.follow_path.size())
        if freed_at == INF and main.dog.global_position.distance_to(main.player.global_position) <= main.dog.FOLLOW_GAP + 3.0:
            freed_at = float(f + 1) / 60.0
    print("following clears the car in ", freed_at, "s, widest leash ", widest, "  ok: ",
        freed_at < 8.0 and not clipped and widest <= main.dog.LEASH + 1.0)
    print("end: dog ", main.dog.global_position, ", owner ", main.player.global_position, ", remaining path ", main.dog.follow_path)
    print("detour is bounded and discarded near Nicole  ok: ", path_size > 0 and path_size < 1024 and main.dog.follow_path.is_empty())
    var before := Time.get_ticks_usec()
    for i in 20:
        Follow.path(main, from, owner, main.dog.RADIUS)
    print("local route rebuild average: ", float(Time.get_ticks_usec() - before) / 20000.0, "ms")
    print("teleports do not allocate a city-sized grid  ok: ", Follow.path(main, from, from + Vector2(2000, 0), 4.0).is_empty())
    main.queue_free()
    await process_frame
    quit()
