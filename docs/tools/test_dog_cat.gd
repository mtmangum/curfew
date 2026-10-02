extends SceneTree

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    var cat = main.cats[0]
    for c in main.cops:
        c.global_position = Vector2(1200, 700)
        c.wait = 999.0
    cat.global_position = Vector2(600, 440)
    cat.state = cat.State.IDLE
    cat.timer = 999.0
    main.player.global_position = Vector2(515, 440)
    main.dog.global_position = Vector2(545, 445)
    var p0: Vector2 = main.player.global_position
    var barked := false
    for i in 240:
        await physics_frame
        if main.dog.bark_cd > 2.5:
            barked = true
    print("dog chased+barked: ", barked, " cat state: ", cat.state, " (FLEE=", cat.State.FLEE, ")")
    print("player dragged: ", p0.distance_to(main.player.global_position) > 1.0)
    print("game state: ", main.state)
    quit()
