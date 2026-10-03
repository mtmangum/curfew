extends SceneTree
# Life: street hazards cost life instead of ending the run; the run ends when the bar
# is empty (a cop's catch still ends it at once); grace after a hit; pizza restores
# life, and is left alone at full life.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_life.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _fresh(seed_value: int):
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = seed_value
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
    var main = await _fresh(1)
    print("0. pizza slices on the map: ", main.pickups.size(), "  ok: ", main.pickups.size() >= 10 and main.pickups.size() <= 120)
    var v = main.vitals
    var car_stub = load("res://scripts/Traffic.gd").new()
    car_stub.speed = 150.0
    car_stub.heading = Vector2.RIGHT

    # 1. A car costs 50, throws her aside and knocks her flat; the run goes on.
    var pos: Vector2 = Helpers.free_spot(main, main.START + Vector2(300, -200))
    main.player.global_position = pos
    main.run_over(car_stub, false)
    print("1. after one car: life ", v.health, " state ", main.state, " stunned ", main.player.stunned_t > 1.0, "  ok: ", v.health == 50.0 and main.state == "play" and main.player.stunned_t > 1.0)

    # 2. A second hit straight away does nothing (grace); after the grace it hurts again, and that is the end.
    main.run_over(car_stub, false)
    var in_grace: bool = v.health == 50.0
    v.grace_t = 0.0
    main.run_over(car_stub, false)
    print("2. in grace: nothing (", in_grace, "); then the second car: life ", v.health, " state ", main.state, " banner ", main.banner_title.text, "  ok: ", in_grace and v.health == 0.0 and main.state == "caught" and main.banner_title.text == "RUN OVER")
    main.queue_free()
    await process_frame

    # 3. Skater and punk cost 15 each; a hobo drains steadily; then knocked out.
    main = await _fresh(1)
    v = main.vitals
    main.hurt(v.SKATER_DAMAGE, "skater")
    var after_skater: float = v.health
    v.grace_t = 0.0
    main.hurt(v.PUNK_DAMAGE, "punk")
    var after_punk: float = v.health
    for i in 60:
        main.drain(v.HOBO_DRAIN / 60.0, "hobo")
    print("3. skater -> ", after_skater, ", punk -> ", after_punk, ", a second of a hobo -> ", snappedf(v.health, 0.1), "  ok: ", after_skater == 85.0 and after_punk == 70.0 and absf(v.health - (70.0 - v.HOBO_DRAIN)) < 0.2)
    v.grace_t = 0.0
    main.hurt(1000.0, "punk")
    print("   knocked out: state ", main.state, " banner ", main.banner_title.text, " outcome ", main.runlog.summary().outcome, "  ok: ", main.state == "caught" and main.banner_title.text == "KNOCKED OUT" and main.runlog.summary().outcome == "knocked_out")
    main.queue_free()
    await process_frame

    # 4. Pizza: restores life (capped), is left alone at full life, and is eaten by walking over it.
    main = await _fresh(1)
    v = main.vitals
    var pizza = main.pickups[0]
    main.player.global_position = pizza.global_position
    main.dog.global_position = pizza.global_position + Vector2(10, 0)
    for i in 10:
        await physics_frame
    var still_there: bool = is_instance_valid(pizza) and not pizza.is_queued_for_deletion() and main.pickups.has(pizza)
    v.health = 40.0
    for i in 10:
        await physics_frame
    var eaten: bool = not main.pickups.has(pizza)
    print("4. at full life it stays (", still_there, "); at 40 it is eaten (", eaten, ") -> life ", v.health, "  ok: ", still_there and eaten and v.health == 75.0)
    v.health = 90.0
    var gained: float = v.heal(v.PIZZA)
    print("   healing caps at the maximum: ", v.health, " (gained ", gained, ")  ok: ", v.health == 100.0 and gained == 10.0)
    main.queue_free()
    await process_frame

    # 5. A cop catching her still ends the run at once, whatever her life.
    main = await _fresh(1)
    main.caught(main.cops[0])
    print("5. caught by a cop at full life: state ", main.state, "  ok: ", main.state == "caught")
    main.queue_free()
    quit()
