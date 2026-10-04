extends SceneTree
# A cop's torch beam: the lit pool never folds over itself, whichever way he faces and however
# near a wall is; its ground footprint stops at walls (no ray ends inside one); and where it lands on a wall
# the camera can see, the building lights a patch there (and for a wall it cannot see, none).
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_beam.gd
const Sprites := preload("res://scripts/Sprites.gd")

# How many triangles of the lit pool's fan (its origin, ground point, next ground point) wind the other way from the rest.
func _folds(cop) -> int:
    var apex: Vector2 = Sprites.iso(cop.beam_origin)
    var pts: Array = []
    for g in cop.beam_ground:
        pts.append(Sprites.iso(g))
    var plus := 0
    var minus := 0
    for i in range(pts.size() - 1):
        var x: float = (pts[i] - apex).cross(pts[i + 1] - apex)
        if x > 0.05:
            plus += 1
        elif x < -0.05:
            minus += 1
    return mini(plus, minus)

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 3
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    main.state = "play"
    for c in main.cops:
        c.set_process(false)
    main.player.set_process(false)
    var cop = main.cops[0]
    # a building with open ground on its south side
    var b = null
    for n in main.building_nodes:
        if n.floors > 0 and not n.house and n.rect.size.x > 120.0 and n.rect.end.y + 120.0 < main.world_rect.end.y \
                and not main.blocked_circle(Vector2(n.rect.get_center().x, n.rect.end.y + 60.0), 8.0):
            b = n
            break
    var rect: Rect2 = b.rect
    var foot_x: float = rect.get_center().x

    # 1. The cone does not fold: every direction he can face, at several distances from the wall.
    var worst := 0
    var inside := 0
    var cases := 0
    for dist in [3.0, 12.0, 30.0, 70.0]:
        for k in 16:
            cop.global_position = Vector2(foot_x, rect.end.y + dist)
            cop.angle = TAU * float(k) / 16.0
            cop._update_beam()
            cases += 1
            worst = maxi(worst, _folds(cop))
            for g in cop.beam_ground:
                if rect.grow(-0.5).has_point(cop.global_position + g):
                    inside += 1
    print("1. ", cases, " cases (16 directions, 4 distances from a wall): most folded triangles ", worst, ", ray ends inside the wall ", inside, "  ok: ", worst == 0 and inside == 0)

    # 2. Facing the wall from the south, the beam lights its south face, within the wall, and a cop facing away lights nothing.
    cop.global_position = Vector2(foot_x, rect.end.y + 50.0)
    cop.angle = -PI * 0.5   # north, at the wall
    cop._update_beam()
    var strips: Array = b.spots.strips if b.spots != null else []
    var on_wall := not strips.is_empty()
    var in_bounds := true
    for s in strips:
        if s[1] != "s" or s[2] < 0.0 or s[3] > rect.size.x or s[3] < s[2]:
            in_bounds = false
    cop.angle = PI * 0.5    # south, away from it
    cop._update_beam()
    var away: bool = b.spots == null or b.spots.strips.is_empty()
    print("2. facing the wall: ", strips.size(), " strips on its south face (within the wall: ", in_bounds, "); facing away lights nothing: ", away, "  ok: ", on_wall and in_bounds and away)

    # 3. A wall the camera cannot see (its north face) gets no patch: a cop north of the building, facing it.
    cop.global_position = Vector2(foot_x, rect.position.y - 40.0)
    cop.angle = PI * 0.5
    cop._update_beam()
    var north_blind: bool = b.spots == null or b.spots.strips.is_empty()
    print("3. beam on the north face (not visible) lights nothing: ", north_blind, "  ok: ", north_blind)
    quit()
