extends SceneTree
# The map: home is not marked at the start, only a ring over the part of town it is in,
# which tightens as Nicole gets closer and never grows back, until she finds the house.
# A phone booth call fills the map in and marks home. After a lost run the same house
# and the explored map carry over. Cops she has seen are marked where she saw them.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_minimap.gd
const MainScript := preload("res://scripts/Main.gd")

func _fresh(seed_value: int):
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = seed_value
    main.level_override = 1  # phone booths work on level 1 only
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    for n in main.npcs:
        n.set_process(false)
    return main

# A spot within `radius` of `at` that nothing solid occupies.
func _near(main, at: Vector2, radius: float) -> Vector2:
    for k in 16:
        var p: Vector2 = at + Vector2.from_angle(float(k) * TAU / 16.0) * radius
        if not main.blocked_circle(p, 5.0):
            return p
    return at

func _init() -> void:
    var main = await _fresh(2)
    var mm = main.minimap
    var home: Vector2 = main.home_zone.get_center()

    # 1. At the start home is not marked: a ring that holds it but is not centred on it.
    var ring: Array = mm.ring()
    var off: float = (ring[0] as Vector2).distance_to(home)
    print("1. start: found ", mm.home_found(), ", ring radius ", int(ring[1]), ", centre ", int(off), " from home  ok: ",
        not mm.home_found() and ring[1] == mm.RING_MAX and off > 50.0 and off < ring[1])

    # 2. It tightens as she gets closer and never grows back.
    main.player.global_position = home + Vector2(-1400, 0)
    mm._process(0.0)
    var r_far: float = mm.ring()[1]
    main.player.global_position = home + Vector2(-700, 0)
    mm._process(0.0)
    var r_mid: float = mm.ring()[1]
    main.player.global_position = home + Vector2(-3000, 0)
    mm._process(0.0)
    var r_back: float = mm.ring()[1]
    print("2. ring at 1400 away ", int(r_far), ", at 700 ", int(r_mid), ", back at 3000 ", int(r_back), "  ok: ", r_mid < r_far and r_back == r_mid)
    print("   the ring still holds home: ", (mm.ring()[0] as Vector2).distance_to(home) < mm.ring()[1], "  ok: ", (mm.ring()[0] as Vector2).distance_to(home) < mm.ring()[1])

    # 3. Near enough, home is pinned (and the caption gives the exact distance).
    main.player.global_position = home + Vector2(0, 240)
    mm._process(0.0)
    print("3. at 240 from the door: found ", mm.home_found(), "  ok: ", mm.home_found())
    main.queue_free()
    await process_frame

    # 4. Seeing the house (its cell revealed) also finds it.
    main = await _fresh(2)
    mm = main.minimap
    home = main.home_zone.get_center()
    mm._reveal_around(home, 100.0)
    print("4. the house revealed on the map: found ", mm.home_found(), "  ok: ", mm.home_found())
    main.queue_free()
    await process_frame

    # 5. A call from a phone booth: stand beside it for three seconds. The map fills in and home is marked.
    main = await _fresh(2)
    mm = main.minimap
    var booth = main.phones[0]
    var before: int = mm.seen_cells.size()
    main.player.global_position = _near(main, booth.global_position, 16.0)
    main.dog.global_position = main.player.global_position
    for i in 120:  # 2 s: not yet
        await physics_frame
    var early: bool = booth.used
    for i in 90:
        await physics_frame
    print("5. phone booth: used after 2 s ", early, ", after 3.5 s ", booth.used, ", home found ", mm.home_found(), ", map cells ", before, " -> ", mm.seen_cells.size(),
        ", calls logged ", main.runlog.phone_calls, "  ok: ", not early and booth.used and mm.home_found() and mm.seen_cells.size() > before + 100 and main.runlog.phone_calls == 1)
    print("   booths on the map: ", main.phones.size(), "  ok: ", main.phones.size() >= 8)
    var hidden := 0
    var lit := 0
    for o in main.builder.booth_objects:
        if o.working:
            lit += 1
            if main.builder._booth_hidden(o):
                hidden += 1
    print("   lit booths ", lit, " (one per working booth: ", lit == main.phones.size() - 1, "), hidden behind a building: ", hidden, "  ok: ", hidden == 0 and lit == main.phones.size() - 1)
    main.queue_free()
    await process_frame

    # 6. A cop she has seen is marked where she saw him.
    main = await _fresh(2)
    mm = main.minimap
    var cop = main.cops[0]
    for c in main.cops:
        c.global_position = Vector2(-2000, 100)
    var spot: Vector2 = _near(main, main.START + Vector2(400, -200), 10.0)
    main.player.global_position = spot
    cop.global_position = _near(main, spot, 70.0)
    mm._note_cops(Time.get_ticks_msec() / 1000.0)
    print("6. a cop in sight is marked: ", mm.cop_marks.has(cop.get_instance_id()), "  ok: ", mm.cop_marks.has(cop.get_instance_id()))
    main.queue_free()
    await process_frame

    # 7. After a lost run the same house and the explored map carry over; a win clears them.
    main = await _fresh(2)
    mm = main.minimap
    mm.home_best = 600.0
    mm._reveal_around(main.START + Vector2(1500, -300), 500.0)
    var cells: int = mm.seen_cells.size()
    var house: Vector2 = main.home_zone.get_center()
    MainScript.retry_seed = main.home_seed
    MainScript.retry_state = mm.export_state()
    var fell: Vector2 = main.START + Vector2(900, -250)
    MainScript.retry_pos = fell
    main.queue_free()
    await process_frame
    var again = load("res://scenes/Main.tscn").instantiate()  # home_seed left at -1, like a restarted game
    again.level_override = 1
    again.traffic_enabled = false
    root.add_child(again)
    for i in 3:
        await process_frame
    print("7. next try: same house ", again.home_zone.get_center() == house, ", explored cells ", cells, " -> ", again.minimap.seen_cells.size(), ", home ring kept ",
        again.minimap.home_best == 600.0 or again.minimap.home_best < 600.0, "  ok: ",
        again.home_zone.get_center() == house and again.minimap.seen_cells.size() >= cells and again.minimap.home_best <= 600.0)
    var moved: float = again.player.global_position.distance_to(fell)
    print("   and she starts near where she fell (", int(moved), " away; the start is ", int(again.START.distance_to(fell)), " away)  ok: ", moved < 340.0 and not again.blocked_circle(again.player.global_position, 5.0))
    for c in again.cops:
        c.set_process(false)
    again.player.global_position = again.home_zone.get_center()
    for i in 5:
        await physics_frame
    print("   a win clears it: seed ", MainScript.retry_seed, "  ok: ", MainScript.retry_seed == -1 and MainScript.retry_state.is_empty() and MainScript.retry_pos == Vector2.INF)
    again.queue_free()
    await process_frame

    # 8. She never comes back next to a cop: even if she fell right at one's post, the spot is
    #    well clear of every cop and every patrol route.
    main = await _fresh(2)
    var post: Vector2 = main.cops[0].waypoints[0]
    MainScript.retry_seed = main.home_seed
    MainScript.retry_state = {}
    MainScript.retry_pos = post
    main.queue_free()
    await process_frame
    again = load("res://scenes/Main.tscn").instantiate()
    again.level_override = 1
    again.traffic_enabled = false
    root.add_child(again)
    for i in 3:
        await process_frame
    var spot2: Vector2 = again.player.global_position
    var nearest_cop := INF
    var nearest_route := INF
    for c in again.cops:
        nearest_cop = minf(nearest_cop, c.global_position.distance_to(spot2))
        for i in c.waypoints.size():
            var q: Vector2 = Geometry2D.get_closest_point_to_segment(spot2, c.waypoints[i], c.waypoints[(i + 1) % c.waypoints.size()])
            nearest_route = minf(nearest_route, q.distance_to(spot2))
    print("8. fell at a cop's post: comes back ", int(spot2.distance_to(post)), " away, nearest cop ", int(nearest_cop), ", nearest patrol ", int(nearest_route),
        "  ok: ", nearest_cop >= 380.0 and nearest_route >= 220.0 and not again.blocked_circle(spot2, 5.0))
    again.queue_free()
    MainScript.retry_seed = -1
    MainScript.retry_state = {}
    MainScript.retry_pos = Vector2.INF
    quit()
