extends SceneTree
# Zombies asleep in the plazas (level 2 on): some lie on the park benches, some sit slumped by
# the fountain. They stay put until Nicole comes within about 120 units, then get up and come
# for her; if she gets away they go back to their seat. Level 1 has none.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_plaza_zombies.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _fresh(level: int):
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
    main.dog.set_process(false)
    return main

func _init() -> void:
    var one = await _fresh(1)
    var resting1: int = one.npcs.filter(func(n): return n.rest_pose != "").size()
    one.queue_free()
    await process_frame
    var main = await _fresh(2)
    var lying: Array = main.npcs.filter(func(n): return n.rest_pose == "lie")
    var sitting: Array = main.npcs.filter(func(n): return n.rest_pose == "sit")
    var on_benches: int = lying.filter(func(n): return n.rest_bench.occupant == 1 and n.state == n.State.DORMANT and not n.sprite.visible).size()
    print("1. asleep in the plazas on level 2: ", lying.size(), " on benches (", on_benches, " drawn lying on them), ", sitting.size(), " sitting; level 1: ", resting1,
        "  ok: ", lying.size() >= 8 and sitting.size() >= 8 and on_benches == lying.size() and resting1 == 0)

    # 2. A sleeper on a bench stays put while she is a little way off, wakes when she is close.
    var z = lying[0]
    var bench = z.rest_bench
    var seat: Vector2 = z.global_position
    main.state = "play"
    main.player.global_position = Helpers.free_spot(main, seat + Vector2(190, 0))
    main.dog.global_position = main.player.global_position
    for i in 120:
        await physics_frame
    var still: bool = z.state == z.State.DORMANT and bench.occupant == 1 and z.global_position == seat
    main.player.global_position = Helpers.free_spot(main, seat + Vector2(80, 30))
    main.dog.global_position = main.player.global_position
    for i in 30:
        await physics_frame
    print("2. asleep at ~190 away (", still, "); at ~85 he is up and after her: state ", z.state, ", bench empty ", bench.occupant == 0, ", visible ", z.sprite.visible,
        "  ok: ", still and z.state == z.State.HUNT and bench.occupant == 0 and z.sprite.visible)

    # 3. She gets away: he goes back to the bench and lies down again.
    main.player.global_position = seat + Vector2(745, 0)  # past where he loses her (700), inside the range where things run (800)
    main.dog.global_position = main.player.global_position
    var gap: float = main.player.global_position.distance_to(seat)
    var back := false
    for i in 60 * 14:
        await physics_frame
        if z.state == z.State.DORMANT:
            back = true
            break
    print("3. she gets away (", int(gap), " off): he goes back to the bench and lies down (", back, "), bench occupied ", bench.occupant == 1, ", at his spot ", z.global_position.distance_to(seat) < 4.0,
        "  ok: ", back and bench.occupant == 1 and z.global_position.distance_to(seat) < 4.0)

    # 4. One sitting on the ground wakes the same way and has his own sprite.
    var s = sitting[0]
    var sat: Vector2 = s.global_position
    main.player.global_position = Helpers.free_spot(main, sat + Vector2(200, 0))
    main.dog.global_position = main.player.global_position
    for i in 30:
        await physics_frame
    var asleep: bool = s.state == s.State.DORMANT and s.sprite.visible and s.sprite.texture == s.rest_frames[0] or s.sprite.texture == s.rest_frames[1]
    main.player.global_position = Helpers.free_spot(main, sat + Vector2(70, 0))
    main.dog.global_position = main.player.global_position
    for i in 30:
        await physics_frame
    print("4. a sitter sleeps in his own pose (", asleep, "), then gets up: ", s.state == s.State.HUNT, "  ok: ", asleep and s.state == s.State.HUNT)
    quit()
