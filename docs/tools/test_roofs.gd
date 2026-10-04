extends SceneTree
# Rooftops: kept plain on purpose. Each roof's plan is the same every time, it holds only a few air-
# conditioning units (three at most) and, on about one roof in three, a water tank; the pieces fit
# well in from the roof edge and do not overlap, the building's screen box reaches up as far as the tallest
# piece, and the house has a pitched roof of its own.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_roofs.gd
const RoofsScript := preload("res://scripts/Roofs.gd")
const Sprites := preload("res://scripts/Sprites.gd")

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
            if p.x < b.rect.position.x + RoofsScript.EDGE_MARGIN or p.y < b.rect.position.y + RoofsScript.EDGE_MARGIN \
                    or p.x + p.w > b.rect.end.x - RoofsScript.EDGE_MARGIN or p.y + p.d > b.rect.end.y - RoofsScript.EDGE_MARGIN:
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
        towers, " water tanks (", snappedf(tower_share * 100.0, 1.0), "% of roofs), too near the edge ", outside, ", overlapping ", overlapping, ", screen box too short ", short_box,
        "  ok: ", same and kinds.size() == 2 and too_many_units == 0 and tower_share > 0.15 and tower_share < 0.45 and outside == 0 and overlapping == 0 and short_box == 0)
    var house = buildings.filter(func(b): return b.house)[0]
    print("2. the house has its own roof: extra height ", house.roof_extra, ", no flat-roof pieces ", house.roof_plan.props.is_empty(), "  ok: ", house.roof_extra >= 30.0 and house.roof_plan.props.is_empty())
    # 3. About a third of the units have a fan that turns: each is its own small piece on its building,
    # registered with Main, turning at its own slow speed, and switched off by the activity gate when far away.
    var acs := 0
    var spinning := 0
    for b in plain:
        for p in b.roof_plan.props:
            if p.kind == "ac":
                acs += 1
                if p.spin:
                    spinning += 1
    var spin_share: float = float(spinning) / float(maxi(acs, 1))
    var fan_nodes: Array = main.fans.filter(func(f): return is_instance_valid(f))
    var on_buildings := fan_nodes.all(func(f): return f.get_parent().get_parent() in main.building_nodes and f.get_parent() in [f.get_parent().get_parent().roof_props, f.get_parent().get_parent().roof_over])
    var rates := {}
    for f in fan_nodes:
        rates[snappedf(f.rate, 0.01)] = true
        if f.rate < 0.5 or f.rate > 2.5:
            rates[-1.0] = true  # (too fast or too slow: the check below fails)
    var close: Array = fan_nodes.filter(func(f): return f.global_position.distance_to(main.player.global_position) < main.gate.ON_WITHIN)
    var before: float = close[0].angle if not close.is_empty() else 0.0
    for i in 20:
        await process_frame
    var turned: bool = not close.is_empty() and absf(close[0].angle - before) > 0.01
    main.gate.update()
    var near_on := 0
    var far_off := 0
    var far := 0
    for f in fan_nodes:
        if f.global_position.distance_to(main.player.global_position) > main.gate.OFF_BEYOND:
            far += 1
            if f.process_mode == Node.PROCESS_MODE_DISABLED:
                far_off += 1
        elif f.process_mode != Node.PROCESS_MODE_DISABLED:
            near_on += 1
    print("3. ", acs, " units, ", spinning, " with a turning fan (", snappedf(spin_share * 100.0, 1.0), "%), ", fan_nodes.size(), " fan pieces (one each: ",
        fan_nodes.size() == spinning, ", all on a building: ", on_buildings, "), ", rates.size(), " different speeds, they turn: ", turned,
        "; far from Nicole ", far, " (switched off ", far_off, "), near ", near_on,
        "  ok: ", spin_share > 0.2 and spin_share < 0.5 and fan_nodes.size() == spinning and on_buildings and rates.size() > 3 and not rates.has(-1.0) and turned and far_off == far)
    # 4. What would show outside the building's outline once it is see-through (a tall tank near the back edge)
    # is kept apart from what stays over the building: every piece is in exactly one group, the ones that
    # stay over it are inside the outline (a few pixels in) and the others reach out of it.
    var lost := 0
    var wrongly_inside := 0
    var wrongly_over := 0
    var staying := 0
    var sticking_out := 0
    var tanks_out := 0
    var units_out := 0
    for b in plain:
        var n: int = (b.roof_props.props.size() if b.roof_props != null else 0) + (b.roof_over.props.size() if b.roof_over != null else 0)
        if n != b.roof_plan.props.size():
            lost += 1
        var outline: PackedVector2Array = b.silhouette()
        var shrunk: Array = Geometry2D.offset_polygon(outline, -RoofsScript.OUTLINE_MARGIN)
        for group in [[b.roof_props, false], [b.roof_over, true]]:
            if group[0] == null:
                continue
            for p in group[0].props:
                var out := false
                for x in [p.x, p.x + p.w]:
                    for y in [p.y, p.y + p.d]:
                        for z in [b.height, b.height + p.h + 4.0]:
                            if not Geometry2D.is_point_in_polygon(Sprites.proj(Vector2(x, y), z), shrunk[0]):
                                out = true
                if group[1]:
                    sticking_out += 1
                    if p.kind == "tower":
                        tanks_out += 1
                    else:
                        units_out += 1
                    if not out:
                        wrongly_over += 1
                else:
                    staying += 1
                    if out:
                        wrongly_inside += 1
    print("4. ", staying, " pieces stay over their building and ", sticking_out, " would stand over the street (", tanks_out, " water tanks, ", units_out, " units); lost ", lost,
        ", kept over a building but reaching out ", wrongly_inside, ", set to hide but inside ", wrongly_over,
        "  ok: ", lost == 0 and wrongly_inside == 0 and wrongly_over == 0 and staying > 500 and tanks_out > 100)
    quit()
