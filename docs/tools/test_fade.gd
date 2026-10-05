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
    var spot: Array = Helpers.building_with_room(main, true)
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
    # what stands on its roof goes much fainter than the building (the building's alpha squared) and a piece
    # that would show over the street behind it is gone altogether, so none of it looks like clutter in the road
    var props_alpha: float = node.modulate.a * node.roof_props.modulate.a
    var over_gone: bool = not node.roof_over.visible or node.roof_over.modulate.a < 0.01
    var props_gone: bool = not node.roof_props.visible or node.roof_props.modulate.a < 0.01   # every roof piece is gone, none left looking like it is in the street
    print("the things on its roof fade harder: ", snappedf(props_alpha, 0.01), " against the building's ", snappedf(node.modulate.a, 0.01),
        ", the ones that would stand over the street are hidden: ", over_gone,
        "  ok: ", props_alpha < 0.12 and props_alpha < node.modulate.a * 0.5 and over_gone and props_gone)
    main.player.global_position = front
    main.dog.global_position = front + Vector2(-10, 4)
    main.focus = front
    for i in 60:
        await process_frame
    print("solid again with her in front: ", node.modulate.a > 0.95, " (alpha ", snappedf(node.modulate.a, 0.01), "), the roof's pieces too: ", node.roof_props.modulate.a > 0.95 and node.roof_props.visible and node.roof_over.visible and node.roof_over.modulate.a > 0.95)

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
