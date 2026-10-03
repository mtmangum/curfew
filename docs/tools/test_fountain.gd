extends SceneTree
# Fountains: the water moves while a fountain is in view, and nothing else on the street runs every frame.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_fountain.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    var fountains: Array = main.building_nodes.filter(func(b): return b.get("kind") != null and b.kind == b.Kind.FOUNTAIN)
    var f = fountains[0]
    print("0. fountains in town: ", fountains.size(), "  ok: ", fountains.size() >= 1)

    # Near the view the water moves: the picture changes from one moment to the next.
    var at: Vector2 = f.rect.get_center()
    main.player.global_position = Helpers.free_spot(main, at + Vector2(60, 60))
    main.dog.global_position = main.player.global_position
    main.focus = at
    main.state = "play"
    for i in 20:
        await physics_frame
    var t0: float = f.water_t
    for i in 60:
        await physics_frame
    var moved: float = f.water_t - t0
    print("1. a fountain in view: the water clock ran ", snappedf(moved, 0.1), " s in a second  ok: ", moved > 0.8 and f.is_processing())

    # Only fountains run each frame: no bench, hydrant or tree is processing.
    var others: int = main.building_nodes.filter(func(b): return b.get("kind") != null and b.kind != b.Kind.FOUNTAIN and b.is_processing()).size()
    print("2. other street furniture left alone: ", others, " of them processing  ok: ", others == 0)
    quit()
