extends SceneTree

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    main.player.global_position = Vector2(300, 400)
    main.dog.global_position = Vector2(285, 405)
    main.vents[0].t = 1.0
    main.vents[1].t = 1.0
    main.cops[0].global_position = Vector2(180, 360)
    main.cops[0].angle = 0.0
    main.cops[0].wait = 100.0
    main.cops[0].wp_i = 1
    for i in 40:
        await process_frame
    root.get_viewport().get_texture().get_image().save_png("%s/shot.png" % OS.get_environment("SHOT_DIR"))
    quit()
