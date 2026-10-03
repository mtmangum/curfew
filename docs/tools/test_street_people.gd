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
    # and he lets her go: even standing right beside him she is not shoved again for ten seconds
    var knocked_once: float = main.runlog.damage.get("punk", 0.0)
    for i in 600:
        await physics_frame
    var still_ok: bool = punk.state != punk.State.CHASE
    print("   he lets her go: state ", punk.state, ", punk damage ", knocked_once, " -> ", main.runlog.damage.get("punk", 0.0),
        "  ok: ", still_ok and main.runlog.damage.get("punk", 0.0) == knocked_once)
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
    var long_enough: float = main.player.stunned_t
    await physics_frame
    await physics_frame
    var stars_shown := false
    for n in main.player.find_children("*", "Node2D", true, false):
        if n.get_script() != null and "player" in n and n.visible:
            stars_shown = true
    print("   she is down for about ", snappedf(long_enough, 0.1), "s, with stars round her head: ", stars_shown, "  ok: ", long_enough > 2.0 and stars_shown)

    # 4. A zombie hobo wakes up when she comes near and shambles after her, slower than
    #    even a sneak, so he can't catch her while she moves; stand still and he bites.
    var zombie = null
    for n in main.npcs:
        if n.kind == n.Kind.ZOMBIE and n.rest_pose == "":  # an alley zombie, not a plaza sleeper
            zombie = n
            break
    _reset(main, zombie)
    main.vitals.health = 100.0
    main.vitals.grace_t = 0.0
    var zspot: Vector2 = _clear_spot(main, zombie.global_position, 200.0)
    main.player.global_position = zspot
    main.dog.global_position = zspot
    var zp: Vector2 = zspot
    var woke := false
    var closest := 999.0
    for i in 600:  # 10 s of walking away at a sneak
        await physics_frame
        if zombie.state == zombie.State.HUNT:
            woke = true
        zp = main.slide(zp, (zp - zombie.global_position).normalized() * 42.0 / 60.0, 5.0)
        main.player.global_position = zp
        closest = minf(closest, zombie.global_position.distance_to(zp))
    var gap_walking: float = zombie.global_position.distance_to(zp)
    print("4. a zombie wakes (", woke, ") and cannot catch a sneaking Nicole: gap ", snappedf(gap_walking, 1.0), ", closest ", snappedf(closest, 1.0),
        ", life ", main.vitals.health, "  ok: ", woke and closest > 20.0 and main.vitals.health == 100.0)
    # then she stops
    for i in 900:
        await physics_frame
        if main.vitals.health < 100.0:
            break
    print("   standing still, he gets her: life ", main.vitals.health, ", game still on: ", main.state == "play", "  ok: ", main.vitals.health < 100.0 and main.state == "play")
    # but she can get away: held no longer than about 2.5 s at a time, then he lets go and cannot
    # take hold again for a while, and even while held she is faster than he is
    var longest_hold := 0.0
    var run := 0.0
    var released := false
    for i in 420:
        await physics_frame
        if main.player.slow_t > 0.0:
            run += 1.0 / 60.0
            longest_hold = maxf(longest_hold, run)
        else:
            run = 0.0
        if zombie.grab_cd > 0.0:
            released = true
    print("   he lets go: longest hold ", snappedf(longest_hold, 0.1), " s, released ", released, "  ok: ", released and longest_hold < 3.2)
    var gap_before: float = zombie.global_position.distance_to(main.player.global_position)
    var life_before: float = main.vitals.health
    var zp2: Vector2 = main.player.global_position
    # walk off along whichever direction has clear ground for the next 300 units
    var away_dir: Vector2 = (zp2 - zombie.global_position).normalized()
    var best_clear := -1.0
    for k in 16:
        var dir_k: Vector2 = Vector2.from_angle(float(k) * TAU / 16.0)
        var clear := 0.0
        while clear < 300.0 and not main.blocked_circle(zp2 + dir_k * (clear + 10.0), 6.0):
            clear += 10.0
        if clear > best_clear or (clear == best_clear and dir_k.dot(away_dir) > away_dir.dot(away_dir) * 0.0 and dir_k.dot(away_dir) > 0.5):
            best_clear = clear
            away_dir = dir_k
    for i in 180:  # three seconds of walking away
        await physics_frame
        zp2 = main.slide(zp2, away_dir * 85.0 / 60.0, 5.0)
        main.player.global_position = zp2
    var gap_after: float = zombie.global_position.distance_to(zp2)
    print("   and she gets away: gap ", snappedf(gap_before, 1.0), " -> ", snappedf(gap_after, 1.0), ", life ", main.vitals.health, "  ok: ", gap_after > gap_before + 40.0 and main.vitals.health >= life_before - 10.0)
    quit()
