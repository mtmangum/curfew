extends SceneTree
# Stella's distractions: a hydrant she hasn't marked (she pees on it, rooted there,
# with Nicole held at the end of the leash), and a squirrel that bolts up a tree
# (she chases it, then barks up at it, rooted, until it settles). Lingering brings zombies.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_stella_stops.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _fresh(level: int = 1):  # squirrels are on level 1; zombies drifting in on level 2
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = level
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.set_process(false)
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
    var main = await _fresh()
    print("0. hydrants ", main.hydrants.size(), ", trees ", main.trees.size(), ", squirrels ", main.squirrels.size(),
        "  ok: ", main.hydrants.size() >= 30 and main.squirrels.size() >= 5)

    # 1. Stella sees a hydrant: she goes to it, pees (rooted), and Nicole is held at the leash's end.
    var h = main.hydrants[0]
    var hc: Vector2 = h.rect.get_center()
    main.dog.global_position = _near(main, hc, 28.0)
    var away: Vector2 = _near(main, main.dog.global_position, 40.0)
    main.player.global_position = away
    main.dog.pee_cd = 0.0
    main.state = "play"
    var peed := false
    for i in 240:
        await physics_frame
        if main.dog.planted == "pee":
            peed = true
            break
    var rooted_at: Vector2 = main.dog.global_position
    # Nicole tries to walk away; the leash must hold her.
    var dir: Vector2 = (away - rooted_at).normalized()
    var held_ok := true
    for i in 90:
        await physics_frame
        main.player.global_position = main.slide(main.player.global_position, dir * 85.0 / 60.0, 5.0)
        if main.player.global_position.distance_to(main.dog.global_position) > main.dog.LEASH + 6.0:
            held_ok = false
    var stayed: bool = main.dog.global_position.distance_to(rooted_at) < 3.0
    print("1. she pees on the hydrant: ", peed, " (marked: ", h.marked, "), stayed put: ", stayed, ", Nicole held within the leash: ", held_ok,
        "  ok: ", peed and h.marked and held_ok and stayed)
    for i in 200:
        await physics_frame
    print("   afterwards she is free again: ", main.dog.planted == "", "  ok: ", main.dog.planted == "")
    # a marked hydrant is not used twice
    main.dog.pee_cd = 0.0
    main.dog.global_position = _near(main, hc, 28.0)
    for i in 60:
        await physics_frame
    print("   a marked hydrant is ignored: ", main.dog.planted == "", "  ok: ", main.dog.planted == "")

    # 2. A squirrel bolts up a tree; Stella chases it and barks up at the tree, rooted.
    var sq = main.squirrels[0]
    main.dog.pee_cd = 999.0
    main.player.global_position = Helpers.free_spot(main, sq.global_position + Vector2(50, 40))
    main.dog.global_position = Helpers.free_spot(main, sq.global_position + Vector2(40, 30))
    var treed := false
    var barked := false
    for i in 600:
        await physics_frame
        if sq.state == sq.State.TREED:
            treed = true
        if main.dog.planted == "tree":
            barked = true
            break
    print("2. squirrel treed: ", treed, ", Stella barking up at it: ", barked, "  ok: ", treed and barked)
    # At the tree she sits, then rears up on her hind legs with her paws on the trunk.
    var sat := false
    var reared := false
    for i in 300:
        await physics_frame
        if main.dog.planted != "tree":
            break
        if main.dog.sprite.texture == main.dog.idle_tex:
            sat = true
        if main.dog.rear_frames.has(main.dog.sprite.texture):
            reared = true
    print("   she sits (", sat, ") and rears up on her hind legs (", reared, ")  ok: ", sat and reared)
    var gave_up := false
    for i in 1500:
        await physics_frame
        if main.dog.planted == "":
            gave_up = true
            break
    print("   she stops once it settles: ", gave_up, "  ok: ", gave_up)
    main.queue_free()
    await process_frame

    # 3. Standing about brings zombies from outside the view.
    main = await _fresh(2)
    main.traffic_director.enabled = true
    main.play_time = 100.0  # past the quiet opening
    main.player.global_position = Helpers.free_spot(main, main.START + Vector2(1500, -600))
    main.dog.global_position = main.player.global_position
    main.dog.set_process(false)
    var first_seen := {}
    var nearest_spawn := INF
    for i in 60 * 14:
        await physics_frame
        for n in main.npcs:
            if n.drifter and not first_seen.has(n.get_instance_id()):
                first_seen[n.get_instance_id()] = true
                nearest_spawn = minf(nearest_spawn, n.global_position.distance_to(main.player.global_position))
    print("3. after 14 s standing about: drifting zombies ", first_seen.size(), " (the nearest set out ", snappedf(nearest_spawn, 1.0), " away, outside the view)  ok: ", first_seen.size() >= 1 and nearest_spawn > 450.0)
    main.queue_free()
    await process_frame

    # 4. Stella catches the scent of home: she sniffs and leads off toward it, giving the leash a
    #    gentle haul that way (Nicole is not moving herself); a cat or squirrel would drop it, and
    #    once home is found she no longer does it. Later levels do it less often.
    main = await _fresh()
    var home: Vector2 = main.home_zone.get_center()
    var from: Vector2 = Helpers.free_spot(main, main.START + Vector2(260, -160))
    main.player.global_position = from
    main.dog.global_position = from + Vector2(-24, 6)
    main.dog.pee_cd = 999.0
    main.dog.scent_cd = 0.0
    main.state = "play"
    var dog_d0: float = main.dog.global_position.distance_to(home)
    var me_d0: float = from.distance_to(home)
    await physics_frame
    await physics_frame
    var started: bool = main.dog.scent_t > 0.0
    for i in 150:
        await physics_frame
    var dog_gain: float = dog_d0 - main.dog.global_position.distance_to(home)
    var me_gain: float = me_d0 - main.player.global_position.distance_to(home)
    print("4. she catches the scent (", started, "), leads toward home (she gained ", snappedf(dog_gain, 1.0), ", the leash hauled Nicole ", snappedf(me_gain, 1.0), ")",
        "  ok: ", started and dog_gain > 15.0 and me_gain > 5.0)
    main.dog.scent_cd = 0.0
    main.minimap.home_best = 100.0  # home found
    for i in 40:
        await physics_frame
    print("   once home is found she stops doing it: ", main.dog.scent_t <= 0.0, "  ok: ", main.dog.scent_t <= 0.0)
    var l1: Vector2 = main.settings.nose
    var l2: Vector2 = load("res://scripts/LevelSettings.gd").for_level(2).nose
    var l3: Vector2 = load("res://scripts/LevelSettings.gd").for_level(3).nose
    print("   level 1 every ", l1.x, "-", l1.y, " s, level 2 ", l2.x, "-", l2.y, ", level 3 ", l3.x, "-", l3.y, "  ok: ", l1.x < l2.x and l2.x < l3.x)
    main.queue_free()
    await process_frame

    # 5. A cat that will not run does not hold her for ever: after about seven seconds she loses
    #    interest in cats, goes back to Nicole's side, and ignores cats for a good while. (The test
    #    keeps the cat calm and in place, however many times she barks at it.)
    main = await _fresh()
    var spot: Vector2 = Helpers.free_spot(main, main.START + Vector2(260, -160))
    main.player.global_position = spot
    main.dog.global_position = Helpers.free_spot(main, spot + Vector2(70, 0))
    main.dog.pee_cd = 999.0
    main.dog.scent_cd = 999.0
    main.state = "play"
    var cat = main.cats[0]
    var cat_at: Vector2 = Helpers.free_spot(main, spot + Vector2(150, 0))
    cat.global_position = cat_at
    var keen_at := -1.0
    var bored_at := -1.0
    var t5 := 0.0
    for i in 60 * 12:
        await physics_frame
        t5 += 1.0 / 60.0
        cat.state = 0  # still calm
        cat.global_position = cat_at
        if main.dog.chasing != null:
            keen_at = t5
        elif keen_at > 0.0 and bored_at < 0.0:
            bored_at = t5
    var back: float = main.dog.global_position.distance_to(main.player.global_position)
    print("5. a cat that will not run: keen until ", snappedf(keen_at, 0.1), " s, bored by ", snappedf(bored_at, 0.1), " s, back beside Nicole (", snappedf(back, 1.0), " away), ignoring cats for ",
        snappedf(main.dog.cat_bored_t, 1.0), " s more  ok: ", keen_at > 5.0 and keen_at < 8.5 and bored_at > 0.0 and back < 60.0 and main.dog.cat_bored_t > 15.0)
    quit()
