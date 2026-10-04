extends RefCounted
# Casting a torch beam: shared by the cops' torches and Nicole's. Rays are cast from the holder's hand
# across a fan; each ends where it reaches its range or a wall. The result is the ground points the
# rays end at (relative to the holder's feet) and, where a ray ends on a wall the camera can see (a
# south or east face), the wall strips to light there (BeamSpots.gd).

# Returns {"origin": where the rays start (relative to the feet), "ground": [ray ends, relative to the
# feet], "strips": {Building: [[face, u0, u1, strength], ...]}}. `hand` is the torch's spot on the
# ground relative to the feet; if it is inside a wall, the rays start from the feet instead.
static func cast(main, feet: Vector2, hand: Vector2, angle: float, fov: float, reach: float, rays: int) -> Dictionary:
    var from: Vector2 = feet + hand
    if main.ray_hit_wall(from, Vector2.RIGHT, 1.0)[0] < 0.001:
        hand = Vector2.ZERO
        from = feet
    var ground := PackedVector2Array()
    var strips := {}
    var prev_b = null
    var prev_face := ""
    var prev_u := 0.0
    var prev_reach := 0.0
    for i in range(rays + 1):
        var a: float = angle - fov * 0.5 + fov * float(i) / float(rays)
        var dir := Vector2.from_angle(a)
        var hit: Array = main.ray_hit_wall(from, dir, reach)
        var t: float = hit[0]
        ground.append(hand + dir * t)
        var wall_b = null
        var face := ""
        var u := 0.0
        if hit[1] != null and t < reach - 0.5:
            var r: Rect2 = hit[1]
            var at: Vector2 = from + dir * t
            if hit[2] == 1 and dir.y < 0.0:
                face = "s"
                u = clampf(at.x - r.position.x, 0.0, r.size.x)
            elif hit[2] == 0 and dir.x < 0.0:
                face = "e"
                u = clampf(r.end.y - at.y, 0.0, r.size.y)
            if face != "":
                wall_b = main.building_by_rect.get(r)
        if wall_b != null and wall_b == prev_b and face == prev_face:
            if not strips.has(wall_b):
                strips[wall_b] = []
            var strength: float = clampf(1.0 - (t + prev_reach) / (2.0 * reach), 0.25, 1.0)
            strips[wall_b].append([face, minf(u, prev_u), maxf(u, prev_u), strength])
        prev_b = wall_b
        prev_face = face
        prev_u = u
        prev_reach = t
    return {"origin": hand, "ground": ground, "strips": strips}

# Hands the strips of one holder to the buildings (and takes back the ones it no longer lights).
# `lit` is the buildings it lit last time; returns the buildings it lights now.
static func register(owner_id: int, lit: Array, strips: Dictionary) -> Array:
    for b in lit:
        if not strips.has(b) and is_instance_valid(b) and b.spots != null:
            b.spots.clear_strips(owner_id)
    for b in strips:
        b.beam_spots().set_strips(owner_id, strips[b])
    return strips.keys()

# Takes everything a holder was lighting off the buildings.
static func clear(owner_id: int, lit: Array) -> Array:
    return register(owner_id, lit, {})
