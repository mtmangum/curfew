extends SceneTree
# Rooftops: kept plain on purpose. Each roof's plan is the same every time, it holds only a few air-
# conditioning units (three at most) and, on about one roof in three, a water tank; the pieces fit
# inside the roof and do not overlap, the building's screen box reaches up as far as the tallest
# piece, and the house has a pitched roof of its own.
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
    var too_many_units := 0
    var kinds := {}
    var towers := 0
    var units := 0
    for b in plain:
        var again: Dictionary = RoofsScript.plan(b.rect, b.variant, false)
        if again.props.size() != b.roof_plan.props.size() or again.surface != b.roof_plan.surface:
            same = false
        var top := 0.0
        var props: Array = b.roof_plan.props
        var here := 0
        for i in props.size():
            var p: Dictionary = props[i]
            kinds[p.kind] = true
            if p.kind == "tower":
                towers += 1
            else:
                here += 1
            top = maxf(top, p.h)
            if p.x < b.rect.position.x or p.y < b.rect.position.y or p.x + p.w > b.rect.end.x or p.y + p.d > b.rect.end.y:
                outside += 1
            for j in range(i + 1, props.size()):
                var q: Dictionary = props[j]
                if Rect2(p.x, p.y, p.w, p.d).intersects(Rect2(q.x, q.y, q.w, q.d)):
                    overlapping += 1
        units += here
        if here > RoofsScript.MAX_UNITS:
            too_many_units += 1
        if b.roof_extra < top:
            short_box += 1
    var tower_share: float = float(towers) / float(plain.size())
    print("1. ", plain.size(), " roofs: the same plan every time (", same, "), pieces only of kinds ", kinds.keys(), ", ", units, " units (at most ", RoofsScript.MAX_UNITS, " a roof: ", too_many_units, " over), ",
        towers, " water tanks (", snappedf(tower_share * 100.0, 1.0), "% of roofs), outside the roof ", outside, ", overlapping ", overlapping, ", screen box too short ", short_box,
        "  ok: ", same and kinds.size() == 2 and too_many_units == 0 and tower_share > 0.15 and tower_share < 0.45 and outside == 0 and overlapping == 0 and short_box == 0)
    var house = buildings.filter(func(b): return b.house)[0]
    print("2. the house has its own roof: extra height ", house.roof_extra, ", no flat-roof pieces ", house.roof_plan.props.is_empty(), "  ok: ", house.roof_extra >= 30.0 and house.roof_plan.props.is_empty())
    quit()
