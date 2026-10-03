extends SceneTree
# Street characters to avoid: a hobo rants and grabs (she crawls, and it's loud); punks
# jeer, chase, and shove her flat; a skateboarder knocks her down. None of these ends
# the run by itself; they cost time and make noise.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_street_people.gd

# A spot `dist` away from `from` with a clear line of sight and room to stand.
func _clear_spot(main, from: Vector2, dist: float) -> Vector2:
    for k in 24:
        var p: Vector2 = from + Vector2.from_angle(float(k) * TAU / 24.0) * dist
        if not main.blocked_circle(p, 6.0) and main.los(from, p):
            return p
    return from + Vector2(dist, 0.0)

func _calm(main) -> void:
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)

func _reset(main, npc) -> void:
    for other in main.npcs:
        other.set_process(other == npc)
    main.state = "play"
    main.player.stunned_t = 0.0
    main.player.slow_t = 0.0

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    main.home_seed = 1
    root.add_child(main)
    for i in 3:
        await process_frame
    _calm(main)
    print("street people: ", main.npcs.size(), "  ok: ", main.npcs.size() > 30)

    # 1. The hobo rants, shouts (a cop hears), and grabs her.
    var hobo = null
    for n in main.npcs:
        if n.kind == 0:
            hobo = n
            break
    _reset(main, hobo)
    var cop = main.cops[0]
    cop.global_position = hobo.global_position + Vector2(0, 140)
    cop.state = cop.State.PATROL
    cop.wait = 100.0
    main.player.set_process(false)
    var spot: Vector2 = _clear_spot(main, hobo.global_position, 70.0)
    main.player.global_position = spot
    main.dog.global_position = spot
    var shouted := false
    var grabbed := false
    for i in 480:
        await physics_frame
        if main.player.slow_t > 0.0:
            grabbed = true
        if cop.state == cop.State.INVESTIGATE:
            shouted = true
    print("1. the hobo rants then grabs: state=", hobo.state, " grabbed=", grabbed, "  ok: ", grabbed)
    print("   his shouting drew a cop: ", shouted, "  ok: ", shouted)
    # While he has hold of her she crawls: far slower than a walk.
    main.player.set_process(true)
    var before: Vector2 = main.player.global_position
    main.player.slow_t = 1.0
    main.player.dest = before + Vector2(60, 0)
    main.player.has_dest = true
    for i in 60:
        await physics_frame
        main.player.slow_t = 1.0
    var crawled: float = main.player.global_position.distance_to(before)
    print("   held for a second she moved ", snappedf(crawled, 1.0), " units (a free walk is 85)  ok: ", crawled < 50.0)
    main.player.has_dest = false
    main.player.set_process(false)

    # 2. A punk notices her, taunts, chases and shoves her flat.
    var punk = null
    for n in main.npcs:
        if n.kind == 1:
            punk = n
            break
    _reset(main, punk)
    spot = _clear_spot(main, punk.global_position, 110.0)
    main.player.global_position = spot
    main.dog.global_position = spot
    var chased := false
    var shoved := false
    for i in 600:
        await physics_frame
        if punk.state == punk.State.CHASE:
            chased = true
        if main.player.stunned_t > 0.0:
            shoved = true
            break
    print("2. the punk chases: ", chased, "  shoves her flat: ", shoved, " (game still on: ", main.state == "play", ")  ok: ", chased and shoved and main.state == "play")
    # she gets up again
    main.player.set_process(true)
    for i in 150:
        await physics_frame
    print("   she is back on her feet afterwards: ", main.player.stunned_t <= 0.0, "  ok: ", main.player.stunned_t <= 0.0)
    main.player.set_process(false)

    # 3. A skateboarder knocks her down, and she is not out.
    main.state = "play"
    main.player.stunned_t = 0.0
    for other in main.npcs:
        other.set_process(false)
    var lane: Dictionary = {}
    for l in main.traffic_director.lanes:
        if l.horizontal and absf(l.fixed - 734.0) < 0.5 and l.dir == 1:
            lane = l
    var sk = main.traffic_director.spawn_skater(lane, 1000.0, true)
    main.player.global_position = Vector2(1130.0, 734.0)
    main.dog.global_position = Vector2(1130.0, 640.0)
    var knocked := false
    for i in 240:
        await physics_frame
        if main.player.stunned_t > 0.0:
            knocked = true
            break
    print("3. the skateboarder knocks her down: ", knocked, " (game still on: ", main.state == "play", ")  ok: ", knocked and main.state == "play")
    quit()
