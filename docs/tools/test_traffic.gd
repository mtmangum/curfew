extends SceneTree
# Traffic: cars drive the lanes of the road grid. One that hits Nicole or Stella ends
# the run; standing beside the road is safe; a horn goes up when she is in the way
# and cops hear it. Cars never fade or vanish where she could see them: they appear
# and disappear far outside the view.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_traffic.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _calm(main) -> void:
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)

# The eastbound lane of the avenue at y = 720 (the 3rd lane: offset +14).
func _lane(main) -> Dictionary:
    for l in main.traffic_director.lanes:
        if l.horizontal and absf(l.fixed - 734.0) < 0.5 and l.dir == 1:
            return l
    return {}

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = 1
    main.audit_seed = 1001
    root.add_child(main)  # traffic stays on: the director spawns cars round Nicole
    for i in 3:
        await process_frame
    _calm(main)
    print("lanes in the world: ", main.traffic_director.lanes.size(), "  ok: ", main.traffic_director.lanes.size() > 50)

    # 1. Cars appear round her on their own, and only well outside the view.
    var near_pos: Vector2 = Vector2(1280.0, 740.0)  # beside the avenue, clear of the lanes' edges
    main.player.global_position = Vector2(1100.0, 800.0)
    main.dog.global_position = Vector2(1090.0, 806.0)
    main.focus = main.player.global_position
    var nearest_spawn := INF
    var seen := {}
    var seen_fading := 0
    var removed_close := 0
    var before: Array = []
    for f in 1200:  # 20 seconds
        await physics_frame
        if main.state != "play":
            main.state = "play"  # a car may run her over on her spot; this part is about spawning
        for car in main.traffic:
            var d: float = car.global_position.distance_to(main.player.global_position)
            if not seen.has(car.get_instance_id()):
                seen[car.get_instance_id()] = true
                nearest_spawn = minf(nearest_spawn, d)
            if d < 600.0 and car.modulate.a < 0.99:
                seen_fading += 1
        for car in before:
            if is_instance_valid(car) and not main.traffic.has(car) and car.global_position.distance_to(main.player.global_position) < 700.0:
                removed_close += 1
        before = main.traffic.duplicate()
    print("2. cars spawned: ", seen.size(), ", nearest spawn ", snappedf(nearest_spawn, 1.0), " from her  ok: ", seen.size() >= 6 and nearest_spawn >= 650.0)
    print("   cars seen fading within 600 units: ", seen_fading, "  ok: ", seen_fading == 0)
    print("   cars that vanished within 700 units: ", removed_close, "  ok: ", removed_close == 0)

    # 3. A car moves, and one in her way runs her over; a horn reaches a nearby cop.
    main.traffic_director.enabled = false
    for car in main.traffic.duplicate():
        main.traffic.erase(car)
        car.queue_free()
    main.state = "play"
    var lane: Dictionary = _lane(main)
    var car = main.traffic_director.spawn_car(lane, 900.0, true)
    var p0: Vector2 = car.position
    main.player.global_position = Vector2(1200.0, 400.0)  # out of the way, but near enough to keep it simulated
    main.dog.global_position = main.player.global_position
    for i in 30:
        await physics_frame
    print("3. a car moves: ", snappedf(car.position.distance_to(p0), 1.0), " units in half a second  ok: ", car.position.distance_to(p0) > 30.0)

    car.position = p0
    car.rect = Rect2(car.position + car.local_rect.position, car.local_rect.size)
    var ahead: Vector2 = car.heading * 140.0
    main.player.global_position = car.position + ahead
    main.dog.global_position = car.position + ahead + Vector2(0, -150)
    main.vitals.health = 40.0  # one car is enough to finish her (a car costs 50)
    var cop = main.cops[0]
    # Rain reduces the 240-unit horn radius (180 on level 3). Keep the
    # listener inside the actual radius, rather than assuming dry weather.
    cop.global_position = car.position + Vector2(0, 240.0 * float(main.settings.noise_scale) * 0.6)
    cop.state = cop.State.PATROL
    cop.seeing = false
    cop.set_process(false)
    for i in 150:
        await physics_frame
        if main.state != "play":
            break
    print("4. stood in its way: state=", main.state, " banner=", main.hud.banner_title.text, "  ok: ", main.state == "caught" and main.hud.banner_title.text == "RUN OVER")
    print("   the horn reached a nearby cop: cop state=", cop.state, "  ok: ", cop.state == cop.State.INVESTIGATE)

    # 5. Stella in its way while Nicole is safe: still costs Nicole's life.
    main.state = "play"
    main.vitals.health = 40.0
    main.vitals.grace_t = 0.0
    main.hud.banner.visible = false
    car.position = p0
    car.rect = Rect2(car.position + car.local_rect.position, car.local_rect.size)
    main.player.global_position = car.position + ahead + Vector2(0, -200)
    main.dog.global_position = car.position + ahead
    for i in 150:
        await physics_frame
        if main.state != "play":
            break
    print("5. Stella in its way: state=", main.state, "  ok: ", main.state == "caught")

    # 6. Beside the road while it passes: safe.
    main.state = "play"
    car.position = p0
    car.rect = Rect2(car.position + car.local_rect.position, car.local_rect.size)
    main.player.global_position = car.position + ahead + Vector2(0, -60)
    main.dog.global_position = main.player.global_position + car.heading * 10.0
    for i in 150:
        await physics_frame
    print("6. beside the road as it passes: state=", main.state, "  ok: ", main.state == "play")
    quit()
