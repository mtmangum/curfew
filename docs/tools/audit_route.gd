extends RefCounted
# Reuse the existing balance bot route planner; no gameplay policy is changed.
const STEP := 10.0
const CLEARANCE := 7.0
func _find_path(main, from: Vector2, to: Vector2) -> Array:
    var origin: Vector2 = main.world_rect.position
    var cols: int = int(main.world_rect.size.x / STEP) + 1
    var rows: int = int(main.world_rect.size.y / STEP) + 1
    var total: int = cols * rows
    var g := PackedFloat32Array()
    g.resize(total)
    g.fill(INF)
    var parent := PackedInt32Array()
    parent.resize(total)
    parent.fill(-1)
    var closed := PackedByteArray()
    closed.resize(total)
    var start := Vector2i(int((from.x - origin.x) / STEP), int((from.y - origin.y) / STEP))
    var goal := Vector2i(int((to.x - origin.x) / STEP), int((to.y - origin.y) / STEP))
    var heap_f: Array = []
    var heap_i: Array = []
    var s_idx: int = start.y * cols + start.x
    g[s_idx] = 0.0
    _push(heap_f, heap_i, 0.0, s_idx)
    var goal_idx := -1
    var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
    while not heap_i.is_empty():
        var cur: int = _pop(heap_f, heap_i)
        if closed[cur] == 1:
            continue
        closed[cur] = 1
        var cx: int = cur % cols
        var cy: int = cur / cols
        if absi(cx - goal.x) <= 1 and absi(cy - goal.y) <= 1:
            goal_idx = cur
            break
        for d in dirs:
            var nx: int = cx + d.x
            var ny: int = cy + d.y
            if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
                continue
            var ni: int = ny * cols + nx
            if closed[ni] == 1:
                continue
            var npos := Vector2(nx, ny) * STEP + origin
            if main.blocked_circle(npos, CLEARANCE):
                continue
            if d.x != 0 and d.y != 0:
                # no squeezing diagonally between two blocked corners
                if main.blocked_circle(Vector2(cx + d.x, cy) * STEP + origin, CLEARANCE) \
                        or main.blocked_circle(Vector2(cx, cy + d.y) * STEP + origin, CLEARANCE):
                    continue
            var step_cost: float = 1.4142 if (d.x != 0 and d.y != 0) else 1.0
            var ng: float = g[cur] + step_cost
            if ng < g[ni]:
                g[ni] = ng
                parent[ni] = cur
                var dx: float = absf(nx - goal.x)
                var dy: float = absf(ny - goal.y)
                var h: float = (dx + dy) + (1.4142 - 2.0) * minf(dx, dy)
                _push(heap_f, heap_i, ng + h, ni)
    if goal_idx < 0:
        return []
    var path: Array = []
    var i: int = goal_idx
    while i != -1:
        path.append(Vector2(i % cols, i / cols) * STEP + origin)
        i = parent[i]
    path.reverse()
    return path

func _push(hf: Array, hi: Array, f: float, id: int) -> void:
    hf.append(f)
    hi.append(id)
    var c: int = hf.size() - 1
    while c > 0:
        var p: int = (c - 1) / 2
        if hf[p] <= hf[c]:
            break
        var tf = hf[p]; hf[p] = hf[c]; hf[c] = tf
        var ti = hi[p]; hi[p] = hi[c]; hi[c] = ti
        c = p

func _pop(hf: Array, hi: Array) -> int:
    var top: int = hi[0]
    var lf = hf.pop_back()
    var li = hi.pop_back()
    if not hi.is_empty():
        hf[0] = lf
        hi[0] = li
        var c := 0
        var n: int = hi.size()
        while true:
            var l: int = c * 2 + 1
            var r: int = l + 1
            var m: int = c
            if l < n and hf[l] < hf[m]:
                m = l
            if r < n and hf[r] < hf[m]:
                m = r
            if m == c:
                break
            var tf = hf[m]; hf[m] = hf[c]; hf[c] = tf
            var ti = hi[m]; hi[m] = hi[c]; hi[c] = ti
            c = m
    return top
