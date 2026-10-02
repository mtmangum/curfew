extends SceneTree
# Stella chases a cat; the leash goes taut and she hauls Nicole along (sneaking
# doesn't stop it) and the leash never stretches.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_dog_cat.gd

func _run(main, sneak: bool) -> Dictionary:
    var cat = main.cats[0]
    cat.state = cat.State.IDLE
    cat.timer = 999.0
    cat.cooldown = 0.0
    cat.global_position = Vector2(630, 440)
    main.player.global_position = Vector2(515, 440)
    main.dog.global_position = Vector2(545, 445)
    main.sneak_toggle = sneak
    main.dog.bark_cd = 0.0
    var p0: Vector2 = main.player.global_position
    var barks := 0
    var last_cd := 0.0
    var fled := false
    var max_leash := 0.0
    var dragged_frames := 0
    for i in 240:
        await physics_frame
        max_leash = maxf(max_leash, main.dog.global_position.distance_to(main.player.global_position))
        if main.dog.straining:
            dragged_frames += 1
        if main.dog.bark_cd > last_cd + 0.5:
            barks += 1
        last_cd = main.dog.bark_cd
        if cat.state == cat.State.FLEE:
            fled = true
            break
    return {"barked": barks, "fled": fled, "moved": p0.distance_to(main.player.global_position),
        "max_leash": max_leash, "dragged_frames": dragged_frames}

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for other in main.cats:
        other.global_position = Vector2(1200, 700)
        other.state = other.State.IDLE
        other.timer = 999.0
    main.player.set_process(false)  # no input; only Stella moves her
    for sneak in [false, true]:
        var r: Dictionary = await _run(main, sneak)
        print("sneak=", sneak, " barks=", r.barked, " cat fled=", r.fled, " Nicole dragged ", snappedf(r.moved, 0.1),
            " units over ", r.dragged_frames, " frames, longest leash ", snappedf(r.max_leash, 0.1),
            " (limit ", main.dog.LEASH, ")")
        # let the cat settle back to idle for the next round
        main.cats[0].state = main.cats[0].State.IDLE
    print("game state: ", main.state)
    quit()
