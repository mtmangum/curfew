extends SceneTree
# A building goes see-through when Nicole is hidden behind it, and solid again
# when she steps out.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_fade.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    # Standing just north of a big block, close to its back edge: she is behind it.
    var block := Rect2(560, 480, 240, 160)  # tile (0,0) building
    var behind := Vector2(block.position.x + 120.0, block.position.y - 14.0)
    main.player.global_position = behind
    main.dog.global_position = behind + Vector2(-10, -6)
    main.focus = behind
    for i in 40:
        await process_frame
    var node = null
    for b in main.building_nodes:
        if b.rect == block:
            node = b
    print("building fades with her behind it: ", node.modulate.a < 0.5, " (alpha ", snappedf(node.modulate.a, 0.01), ")")
    var front := Vector2(block.position.x + 120.0, block.end.y + 30.0)
    main.player.global_position = front
    main.dog.global_position = front + Vector2(-10, 6)
    main.focus = front
    for i in 60:
        await process_frame
    print("solid again with her in front: ", node.modulate.a > 0.95, " (alpha ", snappedf(node.modulate.a, 0.01), ")")
    quit()
