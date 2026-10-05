extends RefCounted
# A small, temporary navigation grid for a following dog wedged behind furniture.
# No city-wide search or persistent graph: only the space around dog and owner.
const STEP := 8.0
const MARGIN := 48.0
const MAX_SEPARATION := 160.0
const MAX_CELLS := 1024

static func clear_segment(main, from: Vector2, to: Vector2, radius: float) -> bool:
    var steps: int = maxi(1, ceili(from.distance_to(to) / 2.0))
    for i in range(1, steps + 1):
        if main.blocked_circle(from.lerp(to, float(i) / steps), radius):
            return false
    return true

static func nearest_cell(main, grid: AStarGrid2D, at: Vector2, radius: float) -> Vector2i:
    var centre := Vector2i(((at - grid.offset) / STEP).round())
    var best := Vector2i(-1, -1)
    var distance := INF
    for y in range(centre.y - 2, centre.y + 3):
        for x in range(centre.x - 2, centre.x + 3):
            var cell := Vector2i(x, y)
            if not grid.region.has_point(cell) or grid.is_point_solid(cell):
                continue
            var point: Vector2 = grid.get_point_position(cell)
            var away: float = at.distance_squared_to(point)
            if away < distance and clear_segment(main, at, point, radius):
                best = cell
                distance = away
    return best

static func path(main, from: Vector2, to: Vector2, radius: float) -> PackedVector2Array:
    if from.distance_to(to) > MAX_SEPARATION:
        return PackedVector2Array()
    var area := Rect2(from, Vector2.ZERO).expand(to).grow(MARGIN)
    var origin: Vector2 = (area.position / STEP).floor() * STEP
    var size := Vector2i(((area.end - origin) / STEP).ceil()) + Vector2i.ONE
    if size.x * size.y > MAX_CELLS:
        return PackedVector2Array()
    var grid := AStarGrid2D.new()
    grid.region = Rect2i(Vector2i.ZERO, size)
    grid.cell_size = Vector2(STEP, STEP)
    grid.offset = origin
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for y in size.y:
        for x in size.x:
            var cell := Vector2i(x, y)
            grid.set_point_solid(cell, main.blocked_circle(grid.get_point_position(cell), radius + 1.0))
    var start: Vector2i = nearest_cell(main, grid, from, radius)
    var goal: Vector2i = nearest_cell(main, grid, to, radius)
    if start.x < 0 or goal.x < 0:
        return PackedVector2Array()
    return grid.get_point_path(start, goal)
