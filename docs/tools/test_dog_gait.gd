extends SceneTree
# Stella walks beside Nicole and only gallops when she is after a cat.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_dog_gait.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 4:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.global_position = Vector2(2000, 100)
    main.player.global_position = Vector2(600, 1390)
    main.dog.global_position = Vector2(560, 1390)
    var seen := {}
    # 1. follow: Nicole walks, Stella should walk (no gallop frames)
    main.player.dest = Vector2(900, 1390)
    main.player.has_dest = true
    for i in 180:
        await physics_frame
        seen[main.dog.sprite.texture.resource_path.get_file()] = true
    var walking_only: bool = not seen.has("extended0.png") and not seen.has("gathered0.png") and seen.has("walk0.png")
    print("following: frames used ", seen.keys(), "  walks, never gallops: ", walking_only)
    # 2. a cat appears near Stella: she should gallop
    main.player.has_dest = false
    var cat = main.cats[0]
    cat.state = cat.State.IDLE
    cat.timer = 999.0
    cat.cooldown = 0.0
    cat.global_position = main.dog.global_position - Vector2(70, 0)  # behind Stella, well outside the 45-unit range where Nicole would startle it
    seen.clear()
    for i in 40:
        await physics_frame
        seen[main.dog.sprite.texture.resource_path.get_file()] = true
    print("chasing a cat: frames used ", seen.keys(), "  gallops: ", seen.has("extended0.png") or seen.has("gathered0.png"))
    quit()
