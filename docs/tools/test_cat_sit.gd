extends SceneTree
# A cat that isn't moving sits; a moving one runs.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_cat_sit.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    main.player.global_position = Vector2(2000, 700)
    var cat = main.cats[0]
    for other in main.cats:
        if other != cat:
            other.set_process(false)
    main.player.global_position = cat.global_position + Vector2(300, 0)  # near enough to be awake, too far to startle
    cat.state = cat.State.IDLE
    cat.timer = 999.0
    var seen := {}
    for i in 240:
        await physics_frame
        seen[cat.sprite.texture.resource_path.get_file()] = true
    print("idle cat: ", seen.keys(), "  sits: ", seen.has("sit0.png") and not seen.has("run0.png"))
    seen.clear()
    cat.scare_from(cat.global_position + Vector2(-40, 0))  # bolts to the right
    for i in 40:
        await physics_frame
        seen[cat.sprite.texture.resource_path.get_file()] = true
    print("fleeing cat: ", seen.keys(), "  runs: ", seen.has("run0.png") or seen.has("run1.png"))
    quit()
