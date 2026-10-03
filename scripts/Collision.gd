extends RefCounted
# Everything that asks "can I stand here?" and "what does this ray hit?". Walls,
# parked cars, bins, barrels and lamp posts are bucketed into grids once, so a
# check only looks at the few things in the cell around it instead of the whole map.
# Main keeps thin wrappers (blocked_circle, slide, ray_hit, los) so actors call
# main.slide(...) as before.

var main

# --- Spatial grids ---------------------------------------------------------------
# The map has hundreds of walls, cars, bins and barrels. Collision and light
# rays only look at the few in the cells near them, found through these grids.
const CELL := 128.0
var solid_grid := {}   # cell -> walls and cars (rects), for walking
var wall_grid := {}    # cell -> walls only, for rays (cars don't block sight)
var circle_grid := {}  # cell -> [center, radius] of bins and barrels
var lamp_grid := {}    # cell -> street lamps whose pool of light reaches into it

func _cell_of(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func _grid_add(grid: Dictionary, area: Rect2, item) -> void:
    var lo := _cell_of(area.position)
    var hi := _cell_of(area.end)
    for cx in range(lo.x, hi.x + 1):
        for cy in range(lo.y, hi.y + 1):
            var key := Vector2i(cx, cy)
            if not grid.has(key):
                grid[key] = []
            grid[key].append(item)

func build() -> void:
    solid_grid.clear()
    wall_grid.clear()
    circle_grid.clear()
    lamp_grid.clear()
    for w in main.walls:
        _grid_add(solid_grid, w.grow(16.0), w)
        _grid_add(wall_grid, w, w)
    for car in main.cars:
        _grid_add(solid_grid, car.grow(16.0), car)
    for o in main.obstacles:
        _grid_add(solid_grid, o.grow(16.0), o)
    for p in main.props:
        _grid_add(circle_grid, Rect2(p.global_position, Vector2.ZERO).grow(p.radius + 16.0), [p.global_position, p.radius])
    for f in main.fires:
        _grid_add(circle_grid, Rect2(f.global_position, Vector2.ZERO).grow(f.body_radius + 16.0), [f.global_position, f.body_radius])
    for l in main.lamps:
        _grid_add(lamp_grid, Rect2(l.global_position, Vector2.ZERO).grow(l.radius), l)
        _grid_add(circle_grid, Rect2(l.global_position, Vector2.ZERO).grow(l.body_radius + 16.0), [l.global_position, l.body_radius])

# Is this spot in the pool of light of a street lamp?
func lit_by_lamp(p: Vector2) -> bool:
    var lamps = lamp_grid.get(_cell_of(p))
    if lamps != null:
        for l in lamps:
            if l.lights(p):
                return true
    return false

func blocked_circle(pos: Vector2, r: float) -> bool:
    if not main.world_rect.grow(-r).has_point(pos):
        return true
    var key := _cell_of(pos)
    var rects = solid_grid.get(key)
    if rects != null:
        for w in rects:
            if w.grow(r).has_point(pos):
                return true
    var circles = circle_grid.get(key)
    if circles != null:
        for c in circles:
            if pos.distance_to(c[0]) < r + c[1]:
                return true
    return false

# The bin or fire barrel overlapping this circle, as [center, radius], or [].
func _round_blocker(pos: Vector2, r: float) -> Array:
    var circles = circle_grid.get(_cell_of(pos))
    if circles != null:
        for c in circles:
            if pos.distance_to(c[0]) < r + c[1]:
                return [c[0], c[1]]
    return []

# Move from pos by motion, sliding along walls and around round obstacles.
# Returns the new position.
func slide(pos: Vector2, motion: Vector2, r: float) -> Vector2:
    var p := pos + motion
    if not blocked_circle(p, r):
        return p
    var round_hit := _round_blocker(p, r)
    if not round_hit.is_empty():
        # Keep only the part of the motion that goes around the obstacle.
        var n: Vector2 = pos - round_hit[0]
        if n.length() < 0.01:
            n = motion.orthogonal()
        n = n.normalized()
        var along: Vector2 = motion - n * motion.dot(n)
        if along.length() < motion.length() * 0.2:
            # Head-on: always go around the same (right-hand) side.
            along = n.orthogonal() * motion.length()
        else:
            along = along.normalized() * motion.length()
        var q := pos + along
        if not blocked_circle(q, r):
            return q
    var px := Vector2(p.x, pos.y)
    if not blocked_circle(px, r):
        return px
    var py := Vector2(pos.x, p.y)
    if not blocked_circle(py, r):
        return py
    # Wedged between things: veer off to either side.
    for angle in [0.6, -0.6, 1.2, -1.2]:
        var q2 := pos + motion.rotated(angle) * 0.8
        if not blocked_circle(q2, r):
            return q2
    return pos

# Distance along the ray to the first wall or active steam cloud.
func ray_hit(origin: Vector2, dir: Vector2, max_len: float) -> float:
    var best := max_len
    var reach := Rect2(origin, Vector2.ZERO).expand(origin + dir * max_len)
    var lo := _cell_of(reach.position)
    var hi := _cell_of(reach.end)
    for cx in range(lo.x, hi.x + 1):
        for cy in range(lo.y, hi.y + 1):
            var rects = wall_grid.get(Vector2i(cx, cy))
            if rects == null:
                continue
            for w in rects:
                if not reach.intersects(w, true):
                    continue
                var t := _ray_rect(origin, dir, w)
                if t >= 0.0 and t < best:
                    best = t
    for v in main.vents:
        if not v.active:
            continue
        var span: float = max_len + v.radius
        if (v.global_position - origin).length_squared() > span * span:
            continue
        var t2 := _ray_circle(origin, dir, v.global_position, v.radius)
        if t2 >= 0.0 and t2 < best:
            best = t2
    return best

func los(a: Vector2, b: Vector2) -> bool:
    var d := b - a
    var dist := d.length()
    if dist < 1.0:
        return true
    return ray_hit(a, d / dist, dist) >= dist

func _ray_rect(o: Vector2, d: Vector2, r: Rect2) -> float:
    var tmin := 0.0
    var tmax := INF
    for axis in 2:
        var oa: float = o[axis]
        var da: float = d[axis]
        var lo: float = r.position[axis]
        var hi: float = r.end[axis]
        if absf(da) < 0.00001:
            if oa < lo or oa > hi:
                return -1.0
        else:
            var t1 := (lo - oa) / da
            var t2 := (hi - oa) / da
            if t1 > t2:
                var tmp := t1
                t1 = t2
                t2 = tmp
            tmin = maxf(tmin, t1)
            tmax = minf(tmax, t2)
            if tmin > tmax:
                return -1.0
    return tmin

func _ray_circle(o: Vector2, d: Vector2, c: Vector2, rad: float) -> float:
    var oc := o - c
    var b := oc.dot(d)
    var cc := oc.dot(oc) - rad * rad
    var disc := b * b - cc
    if disc < 0.0:
        return -1.0
    var t := -b - sqrt(disc)
    return t if t >= 0.0 else -1.0
