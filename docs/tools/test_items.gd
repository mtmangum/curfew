extends SceneTree
# The found items (Items.gd, ItemPickup.gd, ItemEffects.gd): which kinds each level has; that she picks one up by walking
# over it, only with empty hands, and uses it with E; and what each does: the treat (Stella ignores a cat), the hoodie
# (a cop sees her less far), the coffee (faster, and loud even sneaking), the donuts (a patrolling cop stops to eat; one
# who is chasing her does not), the extinguisher (a cloud that hides her and a hiss a cop right by can hear).
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_items.gd
const Items := preload("res://scripts/Items.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _key(main, code: int) -> void:
    var e := InputEventKey.new()
    e.keycode = code
    e.pressed = true
    main._unhandled_input(e)

func _init() -> void:
    # 1. The catalogue: a few at a time through the levels.
    var per_level := []
    for n in [1, 2, 3, 4, 8]:
        per_level.append(Items.available(n).size())
    var picks_ok := true
    for lv in [1, 2, 3, 5]:
        for n in 40:
            picks_ok = picks_ok and Items.available(lv).has(Items.pick(lv, n))
    var seen_l1 := {}
    for n in 40:
        seen_l1[Items.pick(1, n)] = true
    var later := {}
    for lv in [4, 5, 8]:
        var counts := {}
        for n in 140:
            var k: String = Items.pick(lv, n)
            counts[k] = counts.get(k, 0) + 1
        later[lv] = counts
    var later_ok := true
    for lv in later:
        later_ok = later_ok and later[lv].size() == 5 and later[lv].hoodie > later[lv].treat and later[lv].extinguisher > later[lv].coffee
    print("1b. mix of kinds over 140 items on levels 4, 5, 8: ", later, "  every kind turns up, the stronger two more often: ", later_ok)
    print("1. kinds available on levels 1,2,3,4,8: ", per_level, "  picks stay within a level's kinds: ", picks_ok,
        "  level 1 gives both of its kinds: ", seen_l1.size() == 2, "  ok: ", per_level == [2, 2, 4, 5, 5] and picks_ok and seen_l1.size() == 2 and later_ok)

    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 4
    root.add_child(main)
    for i in 3:
        await process_frame
    main.state = "play"
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)

    # 2. Level 1 has items lying about, and only its own kinds.
    var kinds := {}
    for it in main.item_pickups:
        kinds[it.kind] = true
    var only_l1: bool = kinds.keys().all(func(k): return Items.available(1).has(k))
    print("2. level 1 has ", main.item_pickups.size(), " found items, kinds ", kinds.keys(), "  ok: ", main.item_pickups.size() >= 3 and only_l1)

    # 3. Pick up by walking over it; only with empty hands; E uses it.
    var run: Vector2 = Helpers.open_run(main)
    var a = preload("res://scripts/ItemPickup.gd").new()
    a.main = main
    a.kind = "treat"
    main.actors.add_child(a)
    a.global_position = run
    main.item_pickups.append(a)
    var b = preload("res://scripts/ItemPickup.gd").new()
    b.main = main
    b.kind = "donut"
    main.actors.add_child(b)
    b.global_position = run + Vector2(0, 60)
    main.item_pickups.append(b)
    main.player.global_position = run
    main.dog.global_position = run + Vector2(30, 5)
    for i in 3:
        await process_frame
    var got: bool = main.carried == "treat" and not is_instance_valid(a) or main.carried == "treat" and a.is_queued_for_deletion()
    main.player.global_position = b.global_position
    for i in 3:
        await process_frame
    var second: bool = main.bag == ["treat", "donut"] and (not is_instance_valid(b) or b.is_queued_for_deletion())
    # she can carry three; a fourth waits where it is, with a message, until there is room
    var extra: Array = []
    for k in ["coffee", "hoodie"]:
        var it = preload("res://scripts/ItemPickup.gd").new()
        it.main = main
        it.kind = k
        main.actors.add_child(it)
        it.global_position = run + Vector2(0, 100)
        main.item_pickups.append(it)
        extra.append(it)
    main.player.global_position = run + Vector2(0, 100)
    for i in 4:
        await process_frame
    var three: bool = main.bag == ["treat", "donut", "coffee"] and main.bag_full()
    var waits: bool = is_instance_valid(extra[1]) and not extra[1].is_queued_for_deletion()
    print("3. walked onto items: bag ", main.bag, "; the second was picked up too: ", second, "; a fourth waits while the bag is full: ", three and waits,
        "  ok: ", got and second and three and waits)
    # the keys: 2 uses the second item, E the first
    main.player.global_position = run  # (away from the item still waiting)
    _key(main, KEY_2)
    var after_two: Array = main.bag.duplicate()
    for box in main.donuts.duplicate():  # (the donut box that put down is not wanted in the later checks)
        box.queue_free()
    main.donuts.clear()
    await process_frame  # (so it is really gone: it would lure the cop in the coffee check)

    # 4. The treat: Stella ignores a cat while it lasts.
    var cat = main.cats[0]
    for other in main.cats:
        other.state = other.State.IDLE
        other.timer = 999.0
    main.player.global_position = run
    main.dog.global_position = run + Vector2(30, 5)
    cat.global_position = run + Vector2(90, 0)
    var before = main.dog._nearest_cat()
    _key(main, KEY_E)
    var after = main.dog._nearest_cat()
    print("4. Stella notices the cat before the treat: ", before != null, "  after: ", after == null, "  key 2 used the donut (bag ", after_two, "), then E the treat (bag ", main.bag, ")",
        "  ok: ", before != null and after == null and after_two == ["treat", "coffee"] and main.bag == ["coffee"] and main.items.treat_on())
    main.bag.clear()
    main.items.treat_t = 0.0

    # 5. The hoodie: a cop sees her less far and less readily.
    var cop = main.cops[0]
    cop.state = cop.State.PATROL
    cop.global_position = run - Vector2(100, 0)
    cop.angle = 0.0
    main.player.global_position = run
    main.dog.global_position = run + Vector2(2000, 0)
    var plain: float = cop._rate_for(main.player, 1.0)
    main.carried = "hoodie"
    _key(main, KEY_E)
    var far_with: float = cop._rate_for(main.player, 1.0)
    cop.global_position = run - Vector2(60, 0)
    var near_with: float = cop._rate_for(main.player, 1.0)
    main.items.hoodie_t = 0.0
    var near_plain: float = cop._rate_for(main.player, 1.0)
    print("5. cop at 100: ", snappedf(plain, 0.01), " -> ", snappedf(far_with, 0.01), " with the hoodie; at 60: ", snappedf(near_plain, 0.01), " -> ",
        snappedf(near_with, 0.01), "  ok: ", plain > 0.0 and far_with == 0.0 and near_with > 0.0 and near_with < near_plain)

    # 6. The coffee: faster, and loud even when sneaking (a sneaking step is silent without it).
    for it in main.item_pickups.duplicate():  # (nothing left lying about for her to walk onto)
        it.queue_free()
    main.item_pickups.clear()
    main.player.set_process(true)
    var ground: Vector2 = Helpers.free_spot(main, run + Vector2(0, 120), 60.0)
    var sneaked := {}
    for with_coffee in [false, true]:
        main.items.coffee_t = 8.0 if with_coffee else 0.0
        main.player.global_position = ground
        main.dog.global_position = ground + Vector2(-2000, 0)
        main.sneak_toggle = true
        cop.global_position = ground + Vector2(30, 10)
        cop.state = cop.State.PATROL
        cop.seeing = false
        main.player.dest = ground + Vector2(45, 0)
        main.player.has_dest = true
        var start: Vector2 = main.player.global_position
        for i in 90:
            await physics_frame
        sneaked[with_coffee] = {"moved": main.player.global_position.distance_to(start), "heard": cop.state == cop.State.INVESTIGATE}
    print("6. sneaking, no coffee: ", sneaked[false], "; with coffee: ", sneaked[true], "  ok: ", not sneaked[false].heard and sneaked[true].heard and sneaked[false].moved > 5.0)
    main.items.coffee_t = 0.0
    main.player.set_process(false)
    main.sneak_toggle = false
    cop.state = cop.State.PATROL

    # 7. The donuts: a patrolling cop walks over and stops to eat; one chasing her ignores them.
    var spot: Vector2 = Helpers.free_spot(main, run + Vector2(0, 200), 30.0)
    main.player.global_position = spot + Vector2(-400, 0)
    main.dog.global_position = spot + Vector2(-410, 0)
    # (the cop starts on a clear line to the box: the city's furniture is not the same every run)
    var from: Vector2 = spot + Vector2(110, 0)
    for step in 40:
        var cand: Vector2 = spot + Vector2(110.0 - float(step) * 2.5, 0.0)
        var clear := true
        for k in 12:
            clear = clear and not main.blocked_circle(spot.lerp(cand, float(k) / 11.0), 9.0)
        if clear:
            from = cand
            break
    cop.global_position = from
    cop.state = cop.State.PATROL
    cop.set_process(true)
    cop.waypoints = [cop.global_position]
    var chaser = main.cops[1]
    chaser.global_position = spot + Vector2(-110, 0)
    chaser.start_chase(main.player.global_position)
    main.player.global_position = spot + Vector2(-400, 0)
    main.carried = "donut"
    main.player.global_position = spot
    _key(main, KEY_E)
    main.player.global_position = spot + Vector2(-400, 0)
    var ate := false
    for i in 600:
        await physics_frame
        main.player.global_position = spot + Vector2(-400, 0)
        main.dog.global_position = spot + Vector2(-410, 0)
        if cop.eat_t > 0.0:
            ate = true
            break
    var chaser_ignored: bool = chaser.eat_t <= 0.0
    print("7. the box is down: ", main.donuts.size() == 1, "  the patrolling cop stopped to eat: ", ate, "  the chasing cop did not: ", chaser_ignored,
        "  ok: ", ate and chaser_ignored)
    for d in main.donuts.duplicate():
        d.queue_free()
    cop.set_process(false)
    chaser.set_process(false)
    cop.eat_t = 0.0

    # 8. The extinguisher: a cloud that hides her and a hiss a cop right by hears; it thins away.
    cop.state = cop.State.PATROL
    cop.seeing = false
    var spot2: Vector2 = Helpers.free_spot(main, run + Vector2(0, 400), 30.0)
    main.player.global_position = spot2
    cop.global_position = spot2 + Vector2(60, 0)
    var far_cop = main.cops[2]
    far_cop.state = far_cop.State.PATROL
    far_cop.global_position = spot2 + Vector2(300, 0)
    var vents_before: int = main.vents.size()
    main.carried = "extinguisher"
    _key(main, KEY_E)
    var hidden: bool = main.in_steam(spot2)
    var near_heard: bool = cop.state == cop.State.INVESTIGATE
    var far_deaf: bool = far_cop.state == far_cop.State.PATROL
    for i in 60 * 9:
        await physics_frame
    print("8. cloud made: ", main.vents.size() == vents_before + 1 or hidden, "  hides her: ", hidden, "  the near cop heard: ", near_heard, "  the far cop did not: ", far_deaf,
        "  gone after a while: ", main.vents.size() == vents_before and not main.in_steam(spot2),
        "  ok: ", hidden and near_heard and far_deaf and main.vents.size() == vents_before and not main.in_steam(spot2))

    # 9. A card the first time (levels 1-3), and the slot shows what she carries.
    main.carried = "hoodie"
    main.hud.update_item()
    print("9. slot visible with an item: ", main.hud.item_slot.visible, "  clue text for each kind: ",
        Items.KINDS.all(func(k): return not main.clues.catalog("item_" + k).is_empty()),
        "  ok: ", main.hud.item_slot.visible and Items.KINDS.all(func(k): return not main.clues.catalog("item_" + k).is_empty()))
    quit()
