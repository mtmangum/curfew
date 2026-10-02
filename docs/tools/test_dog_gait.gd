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
    # 3. She faces the cat for as long as she is after it, whichever side it is on.
    for side in [-1.0, 1.0]:
        main.player.has_dest = false
        main.dog.global_position = Vector2(700, 1394)
        main.player.global_position = main.dog.global_position - Vector2(side * 60.0, 4.0)  # behind her, well clear of the cat
        var cat2 = main.cats[1]
        cat2.state = cat2.State.IDLE
        cat2.timer = 999.0
        cat2.cooldown = 0.0
        cat2.global_position = main.dog.global_position + Vector2(side * 70.0, 0.0)
        var right_way := 0
        var total := 0
        for i in 40:
            await physics_frame
            if main.dog.chasing == null:
                break
            total += 1
            if main.dog.sprite.flip_h == (side < 0.0):
                right_way += 1
        print("cat on her ", "left" if side < 0.0 else "right", ": faced it in ", right_way, " of ", total, " frames  ok: ", total > 5 and right_way == total)
    quit()

