extends RefCounted
# A reachable next street, not a revealed route to the hidden house. The temporary
# search stays within 300 units of Stella (961 cells) and is discarded after a hint.
const Follow := preload("res://scripts/DogFollow.gd")
const STEP := 20.0
const SIDE := 31
const HALF := 15
const MAX_CELLS := SIDE * SIDE
const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

static func path(main, from: Vector2, home: Vector2, radius: float) -> PackedVector2Array:
    var straight: Vector2 = from.move_toward(home, STEP * HALF)
    if Follow.clear_segment(main, from, straight, radius + 1.0):
        return PackedVector2Array([straight])
    var origin: Vector2 = from - Vector2.ONE * STEP * HALF
    var solid := PackedByteArray()
    solid.resize(MAX_CELLS)
    for i in MAX_CELLS:
        solid[i] = int(main.blocked_circle(origin + Vector2(i % SIDE, i / SIDE) * STEP, radius + 1.0))
    var parents := PackedInt32Array()
    parents.resize(MAX_CELLS)
    parents.fill(-1)
    var distance := PackedInt32Array()
    distance.resize(MAX_CELLS)
    var start: int = HALF * SIDE + HALF
    var queue := PackedInt32Array([start])
    parents[start] = start
    var cursor := 0
    var best := start
    var best_score := INF
    var edge_best := -1
    var edge_score := INF
    while cursor < queue.size():
        var current: int = queue[cursor]
        cursor += 1
        var cell := Vector2i(current % SIDE, current / SIDE)
        var point: Vector2 = origin + Vector2(cell) * STEP
        var score: float = point.distance_to(home) + distance[current] * STEP * 0.05
        if score < best_score:
            best_score = score
            best = current
        if (cell.x == 0 or cell.y == 0 or cell.x == SIDE - 1 or cell.y == SIDE - 1) and score < edge_score:
            edge_score = score
            edge_best = current
        for direction in DIRS:
            var next: Vector2i = cell + direction
            if next.x < 0 or next.y < 0 or next.x >= SIDE or next.y >= SIDE:
                continue
            var index: int = next.y * SIDE + next.x
            if parents[index] >= 0 or solid[index] == 1:
                continue
            var next_point: Vector2 = origin + Vector2(next) * STEP
            # Check edges too: a thin post or bin can sit between two clear cells.
            if not Follow.clear_segment(main, point, next_point, radius + 1.0):
                continue
            parents[index] = current
            distance[index] = distance[current] + 1
            queue.append(index)
    # When home lies outside the search, choose a reachable exit rather than the
    # point nearest home on the face of the building that blocked the direct lead.
    var best_point: Vector2 = origin + Vector2(best % SIDE, best / SIDE) * STEP
    if best_point.distance_to(home) > STEP * 1.5 and edge_best >= 0:
        best = edge_best
    var route := PackedVector2Array()
    while best != start:
        route.append(origin + Vector2(best % SIDE, best / SIDE) * STEP)
        best = parents[best]
    route.reverse()
    # Remove grid stair-steps, only where the actual swept circle fits.
    var smooth := PackedVector2Array()
    var at: Vector2 = from
    var first := 0
    while first < route.size():
        var last: int = first
        while last + 1 < route.size() and Follow.clear_segment(main, at, route[last + 1], radius + 1.0):
            last += 1
        smooth.append(route[last])
        at = route[last]
        first = last + 1
    return smooth
