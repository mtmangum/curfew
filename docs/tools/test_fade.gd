extends SceneTree
# A building goes see-through when Nicole is hidden behind it, and solid again
# when she steps out.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_fade.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    # A building with open ground behind and in front of it.
    var spot: Array = Helpers.building_with_room(main)
    var block: Rect2 = spot[0]
    var behind: Vector2 = spot[1]
    var front: Vector2 = spot[2]
    main.player.global_position = behind
    main.dog.global_position = behind + Vector2(-10, -4)
    main.focus = behind
    for i in 40:
        await process_frame
    var node = null
    for b in main.building_nodes:
        if b.rect == block:
            node = b
    if node == null:
        print("no building found: ok: false")
        quit()
        return
    print("building fades with her behind it: ", node.modulate.a < 0.5, " (alpha ", snappedf(node.modulate.a, 0.01), ")")
    main.player.global_position = front
    main.dog.global_position = front + Vector2(-10, 4)
    main.focus = front
    for i in 60:
        await process_frame
    print("solid again with her in front: ", node.modulate.a > 0.95, " (alpha ", snappedf(node.modulate.a, 0.01), ")")

    # Street furniture (a fountain, a bench, a tree) never fades, even with her right behind it.
    var fountain = null
    for b in main.building_nodes:
        if "kind" in b and b.kind == b.Kind.FOUNTAIN:
            fountain = b
            break
    var fc: Vector2 = fountain.rect.get_center()
    main.player.global_position = fc + Vector2(-10, -14)  # behind it, as seen from the south-east
    main.dog.global_position = main.player.global_position + Vector2(-8, -4)
    main.focus = main.player.global_position
    for i in 60:
        await process_frame
    print("fountain stays solid with her behind it: ", fountain.modulate.a > 0.99, " (alpha ", snappedf(fountain.modulate.a, 0.01), ")  ok: ", fountain.modulate.a > 0.99)

    # Only buildings fade: every parked car and piece of street furniture is set not to.
    var buildings := 0
    var others := 0
    var wrong := 0
    for b in main.building_nodes:
        if b.floors > 0:
            buildings += 1
            if not b.fades:
                wrong += 1
        else:
            others += 1
            if b.fades:
                wrong += 1
    print("only buildings fade: ", buildings, " buildings, ", others, " cars and objects, ", wrong, " set the wrong way  ok: ", wrong == 0 and buildings > 100 and others > 100)
    quit()
