extends SceneTree
# A cop carries his club at his side while patrolling or checking out a noise,
# and raises it only once he has spotted Nicole.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_cop_pose.gd

func _tex(cop) -> String:
    return cop.sprite.texture.resource_path.get_file()

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for other in main.cops:
        other.set_process(other == main.cops[0])
    for cat in main.cats:
        cat.set_process(false)
    main.dog.set_process(false)
    var cop = main.cops[0]
    main.player.set_process(false)
    main.player.global_position = Vector2(300, 500)  # parked out of sight in a building
    main.dog.global_position = Vector2(300, 500)
    # 1. patrolling
    var seen := {}
    for i in 120:
        await physics_frame
        seen[_tex(cop)] = true
    print("patrolling: ", seen.keys(), "  club down: ", not seen.keys().any(func(n): return n.begins_with("patrol")))
    # 2. checking out a noise
    seen.clear()
    cop.hear(cop.global_position + Vector2(120, 0))
    for i in 30:
        await physics_frame
        seen[_tex(cop)] = true
    print("investigating a noise: ", seen.keys(), "  club down: ", not seen.keys().any(func(n): return n.begins_with("patrol")))
    # 3. spots Nicole in his beam
    cop.state = cop.State.PATROL
    cop.wait = 100.0
    cop.global_position = Vector2(80, 360)
    cop.angle = 0.0
    main.player.global_position = Vector2(140, 360)
    main.dog.global_position = Vector2(135, 364)
    seen.clear()
    for i in 40:
        await physics_frame
        if cop.chasing:
            seen[_tex(cop)] = true
    print("after spotting her: chasing=", cop.chasing, " ", seen.keys(), "  club up: ", seen.keys().any(func(n): return n.begins_with("patrol")))
    quit()
