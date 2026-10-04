extends RefCounted
# Shared helpers for the headless tests: the city is generated, so tests find the
# geometry they need (open ground, a stretch of road, a building to hide in) from the
# world instead of hard-coding coordinates.

# A point near `near` where a circle of radius `clear` fits (no wall, car, bin, post
# or furniture within it).
static func free_spot(main, near: Vector2, clear: float = 40.0) -> Vector2:
    for ring in range(0, 40):
        var radius: float = float(ring) * 20.0
        var steps: int = maxi(1, ring * 6)
        for k in steps:
            var p: Vector2 = near + Vector2.from_angle(TAU * float(k) / float(steps)) * radius
            if _fits(main, p, clear):
                return p
    return near

static func _fits(main, p: Vector2, clear: float) -> bool:
    if main.blocked_circle(p, clear):
        return false
    for k in 8:
        if main.blocked_circle(p + Vector2.from_angle(TAU * float(k) / 8.0) * clear, 6.0):
            return false
    return true

# A long straight stretch of a road: the middle of the first avenue running east-west
# in the playable area, from x = 400 onward. Returns the start point; the road runs
# east (+x) for at least 2000 units and is free of walls, bins and furniture.
static func road_east() -> Vector2:
    return Vector2(400.0, 720.0)

# The same, running south down the avenue at x = 1280.
static func road_south() -> Vector2:
    return Vector2(1280.0, 160.0)

# The centre of a building, a place to stand out of sight.
static func hide_spot(main, near: Vector2) -> Vector2:
    var best: Rect2 = main.buildings[0]
    var best_d := INF
    for b in main.buildings:
        var d: float = b.get_center().distance_to(near)
        if d < best_d:
            best_d = d
            best = b
    return best.get_center()

# A wide building with open ground on its north side, for the fade test; returns
# [building, a spot behind it, a spot in front of it]. `with_roof_pieces` asks for one with both
# kinds of rooftop piece: some that stay over the building and some that stand out over the street.
static func building_with_room(main, with_roof_pieces := false) -> Array:
    for b in main.buildings:
        if b.size.x < 140.0 or b.position.x < 400.0 or b.position.y < 200.0:
            continue
        if with_roof_pieces and not main.building_nodes.any(func(n): return n.rect == b and n.roof_props != null and n.roof_over != null):
            continue
        var behind := Vector2(b.get_center().x, b.position.y - 9.0)
        var front := Vector2(b.get_center().x, b.end.y + 22.0)
        if not main.blocked_circle(behind, 4.0) and not main.blocked_circle(front, 4.0):
            return [b, behind, front]
    return [main.buildings[0], main.buildings[0].get_center(), main.buildings[0].get_center()]
