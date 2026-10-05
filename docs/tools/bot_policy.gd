extends RefCounted
# Audit controller. Knows home and local actor states; uses real movement/items.
const Route := preload("res://docs/tools/audit_route.gd")
var planner := Route.new()
var item_target = null
var escape_goal := Vector2.INF
var escape_t := 0.0
var escape_decisions := 0
var item_detours := 0

func chasers(main) -> Array:
    return main.cops.filter(func(c): return c.state == c.State.CHASE and c.global_position.distance_to(main.player.global_position) < 700.0)

func use_item(main, escaping: bool) -> void:
    var nearest := INF
    for cop in main.cops:
        nearest = minf(nearest, cop.global_position.distance_to(main.player.global_position))
    var use := false
    match main.carried:
        "treat": use = not main.items.treat_on()
        "donut": use = not escaping and nearest < 170.0
        "hoodie": use = nearest < 220.0 and not main.items.hoodie_on()
        "extinguisher": use = escaping and nearest < 100.0 and not main.in_steam(main.player.global_position)
        "coffee": use = escaping and not main.items.coffee_on()
    if use:
        main.use_item()

func nearby_item(main):
    if main.carried != "":
        item_target = null
        return null
    if is_instance_valid(item_target) and item_target in main.item_pickups:
        return item_target
    item_target = null
    var nearest := 180.0
    var pos: Vector2 = main.player.global_position
    for item in main.item_pickups:
        var distance: float = pos.distance_to(item.global_position)
        if distance < nearest and planner._clear_walk(main, pos, item.global_position):
            item_target = item
            nearest = distance
    if item_target != null:
        item_detours += 1
    return item_target

func escape_aim(main, delta: float) -> Vector2:
    escape_t -= delta
    var pos: Vector2 = main.player.global_position
    if escape_t > 0.0 and escape_goal != Vector2.INF and pos.distance_to(escape_goal) > 25.0 \
            and planner._clear_walk(main, pos, escape_goal):
        return escape_goal
    var pursuers: Array = chasers(main)
    var best := -INF
    escape_goal = pos
    # Try short, swept-clear directions. Prefer separation and broken line of sight.
    for radius in [140.0, 70.0, 30.0]:
        for i in 16:
            var candidate: Vector2 = pos + Vector2.RIGHT.rotated(float(i) * TAU / 16.0) * radius
            if not main.world_rect.grow(-10.0).has_point(candidate) or not planner._clear_walk(main, pos, candidate):
                continue
            var separation := INF
            for cop in pursuers:
                var score: float = candidate.distance_to(cop.global_position)
                if not main.los(cop.global_position, candidate):
                    score += 80.0
                separation = minf(separation, score)
            separation -= candidate.distance_to(main.home_zone.get_center()) * 0.03
            if separation > best:
                best = separation
                escape_goal = candidate
    escape_t = 0.6
    escape_decisions += 1
    return escape_goal
