extends SceneTree
# Rooftops: each building's roof plan is the same every time, the pieces on it fit inside the roof
# and do not overlap, the building's screen box reaches up as far as the tallest of them, the styles
# vary, and the house has a pitched roof.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_roofs.gd
const RoofsScript := preload("res://scripts/Roofs.gd")

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 3
    root.add_child(main)
    for i in 3:
        await process_frame
    var buildings: Array = main.building_nodes.filter(func(b): return b.floors > 0)
    var plain: Array = buildings.filter(func(b): return not b.house)
    var same := true
    var outside := 0
    var overlapping := 0
    var short_box := 0
    var styles := {}
    var kinds := {}
    var total_props := 0
    for b in plain:
        var again: Dictionary = RoofsScript.plan(b.rect, b.variant, false)
        if again.props.size() != b.roof_plan.props.size() or again.surface != b.roof_plan.surface or again.style != b.roof_plan.style:
            same = false
        styles[b.roof_plan.style] = true
        var top: float = 0.0
        var props: Array = b.roof_plan.props
        total_props += props.size()
        for i in props.size():
            var p: Dictionary = props[i]
            kinds[p.kind] = true
            top = maxf(top, p.h)
            if p.x < b.rect.position.x or p.y < b.rect.position.y or p.x + p.w > b.rect.end.x or p.y + p.d > b.rect.end.y:
                outside += 1
            for j in range(i + 1, props.size()):
                var q: Dictionary = props[j]
                if Rect2(p.x, p.y, p.w, p.d).intersects(Rect2(q.x, q.y, q.w, q.d)):
                    overlapping += 1
        if b.roof_extra < top:
            short_box += 1
    print("1. ", plain.size(), " roofs: the same plan every time (", same, "), ", total_props, " pieces, outside the roof ", outside, ", overlapping ", overlapping, ", screen box too short ", short_box,
        "  ok: ", same and outside == 0 and overlapping == 0 and short_box == 0 and total_props > plain.size())
    print("2. styles ", styles.size(), " of 6, kinds of piece ", kinds.size(), " (", kinds.keys(), ")  ok: ", styles.size() == 6 and kinds.size() >= 12)
    var house = buildings.filter(func(b): return b.house)[0]
    print("3. the house has its own roof: extra height ", house.roof_extra, ", no flat-roof pieces ", house.roof_plan.props.is_empty(), "  ok: ", house.roof_extra >= 30.0 and house.roof_plan.props.is_empty())
    quit()
