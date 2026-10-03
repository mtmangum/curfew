extends SceneTree
# A scripted player for balance data. It walks the real game (real cops, cats, traffic,
# collision and RunLog) from the start to the front door along an A* route, using
# the same pointer/sneak controls as a person, and reports how runs end.
#
#   godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,sneak,careful seeds=6 max=420
#
# Policies (what a person might do):
#   rush     walk the shortest route, never sneak, never look.
#   sneak    the same route, always sneaking.
#   careful  walk, but sneak near cops, stop short of a cop's beam, and wait for cars
#            and skateboarders to pass before stepping into their lane.
# policy=profile only measures each route (patrols and hazards beside it) without playing.
# Arguments after the -- are optional: policy=a,b  seeds=N (homes 0..N-1)  runs=K (per
# seed and policy)  max=seconds  out=/path/results.json  quiet=1  traffic=0 (no cars)  verbose=1 (print each run's events)
# This measures the *game*, not the bot: a bot that dies often says the game is hard
# for someone who isn't paying attention; one that wins easily says a careful player
# has little to fear.

const STEP := 10.0
const CLEARANCE := 7.0

var policies: Array = ["rush", "sneak", "careful"]
var seeds := 6
var runs_per := 1
var max_seconds := 420.0
var out_path := ""
var quiet := false
var traffic := true
var verbose := false
var results: Array = []

# --- A* over the real collision -------------------------------------------------------
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

# --- Judgement calls of the careful policy ------------------------------------------------
func _in_beam(main, cop, p: Vector2) -> bool:
    var d: Vector2 = p - cop.global_position
    var dist: float = d.length()
    if dist > cop.RANGE + 14.0:
        return false
    if dist > 4.0 and absf(angle_difference(cop.angle, d.angle())) > cop.FOV * 0.5 + 0.2:
        return false
    return main.los(cop.global_position, p)

# Would walking the next three seconds of the route put Nicole (or, trailing her, Stella)
# in a car's or skateboarder's way? With `stand`, asks the same about staying where she is.
func _hit_predicted(main, path: Array, idx: int, pp: Vector2, stand: bool) -> bool:
    for list_i in 2:
        var list: Array = main.traffic if list_i == 0 else main.skaters
        var half_len: float = 24.0 + 12.0 if list_i == 0 else 8.0 + 12.0
        var half_w: float = 15.0 if list_i == 0 else 12.0
        for car in list:
            if car.global_position.distance_to(pp) > 560.0:
                continue
            for k in 31:
                var tau: float = k * 0.1
                var cpos: Vector2 = car.global_position + car.heading * car.speed * tau
                var spots: Array = []
                if stand:
                    spots.append(pp)
                else:
                    spots.append(path[mini(idx + int(tau * 85.0 / STEP), path.size() - 1)])
                    spots.append(path[maxi(0, mini(idx + int(tau * 85.0 / STEP) - 5, path.size() - 1))])  # Stella, behind her
                for hpos in spots:
                    var rel: Vector2 = hpos - cpos
                    if absf(rel.dot(car.heading)) < half_len and absf(rel.dot(car.heading.orthogonal())) < half_w:
                        return true
    return false

# --- One run ---------------------------------------------------------------------------
func _play(policy: String, seed_value: int) -> Dictionary:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = seed_value
    main.traffic_enabled = traffic
    root.add_child(main)
    for i in 3:
        await process_frame
    main.runlog.persist = false
    var player = main.player
    var home: Vector2 = main.home_zone.get_center()
    var path: Array = _find_path(main, main.START, home)
    if path.is_empty():
        main.queue_free()
        return {"outcome": "no_path", "seconds": 0.0, "seed": seed_value, "policy": policy}
    var idx := 0
    var hold_t := 0.0
    var traffic_wait := false
    var frames := int(max_seconds * 60.0)
    for f in frames:
        await physics_frame
        if main.state != "play":
            break
        # advance along the route
        while idx < path.size() - 1 and player.global_position.distance_to(path[idx]) < 18.0:
            idx += 1
        var aim_i: int = mini(idx + 2, path.size() - 1)
        var aim: Vector2 = path[aim_i]
        var wait_now := false
        if policy == "careful":
            var sneak_now := false
            var q: Vector2 = path[mini(idx + 4, path.size() - 1)]
            for c in main.cops:
                var dpl: float = c.global_position.distance_to(player.global_position)
                if dpl > 260.0:
                    continue
                sneak_now = true
                if hold_t < 9.0 and (_in_beam(main, c, q) or _in_beam(main, c, aim)) and not main.in_steam(q):
                    wait_now = true
            if f % 3 == 0:
                traffic_wait = hold_t < 12.0 and _hit_predicted(main, path, idx, player.global_position, false) \
                        and not _hit_predicted(main, path, idx, player.global_position, true)
            if traffic_wait:
                wait_now = true
            main.sneak_toggle = sneak_now
        elif policy == "sneak":
            main.sneak_toggle = true
        else:
            main.sneak_toggle = false
        if wait_now:
            hold_t += 1.0 / 60.0
            player.has_dest = false
            player.pointer_down = false
        else:
            hold_t = maxf(0.0, hold_t - 0.5 / 60.0)
            player.dest = aim
            player.has_dest = true
            player.pointer_down = false
            player.stuck = 0.0
    var summary: Dictionary
    if main.state == "play":
        main.runlog.finish("timeout")
    summary = main.runlog.summary()
    if not verbose:
        summary.erase("events")
    summary["policy"] = policy
    summary["seed"] = seed_value
    main.queue_free()
    for i in 2:
        await process_frame
    return summary

# --- What the route is like, without playing it -------------------------------------------
# Cops whose patrol comes within sight of the route, and other hazards beside it.
func _route_profile(main, seed_value: int) -> Dictionary:
    var path: Array = _find_path(main, main.START, main.home_zone.get_center())
    if path.is_empty():
        return {"seed": seed_value, "route": 0}
    var length := 0.0
    for i in range(1, path.size()):
        length += path[i].distance_to(path[i - 1])
    var thin: Array = []  # every ~30 units
    for i in range(0, path.size(), 3):
        thin.append(path[i])
    var cops_on := 0
    var cops_close := 0
    for route in main.cop_routes:
        var best := INF
        for j in route.size():
            var a: Vector2 = route[j]
            var b: Vector2 = route[(j + 1) % route.size()]
            var n: int = maxi(1, int(a.distance_to(b) / 40.0))
            for k in n + 1:
                var q: Vector2 = a.lerp(b, float(k) / n)
                for pt in thin:
                    var d: float = q.distance_to(pt)
                    if d < best:
                        best = d
        if best < 120.0:
            cops_on += 1
        if best < 40.0:
            cops_close += 1
    var near := {"lamps": 0, "cats": 0, "vents": 0, "fires": 0, "npcs": 0}
    for kind in [["lamps", main.lamps, 60.0], ["cats", main.cats, 70.0], ["vents", main.vents, 50.0], ["fires", main.fires, 80.0], ["npcs", main.npcs, 150.0]]:
        for thing in kind[1]:
            for pt in thin:
                if thing.global_position.distance_to(pt) < kind[2]:
                    near[kind[0]] += 1
                    break
    return {"seed": seed_value, "route": int(length), "cops_cross": cops_on, "cops_on_route": cops_close, "near": near}

# --- Report ----------------------------------------------------------------------------
func _report() -> void:
    print("")
    print("policy    runs  won%  caught  hit-by-car  timeout  median-s(won)  seen  chases  escaped  stuns  sneak%  progress-at-death")
    for policy in policies:
        var rs: Array = results.filter(func(r): return r.policy == policy and r.outcome != "no_path")
        if rs.is_empty():
            continue
        var won := 0
        var caught := 0
        var car := 0
        var timeout := 0
        var win_times: Array = []
        var seen := 0.0
        var chases := 0.0
        var esc := 0.0
        var stuns := 0.0
        var sneak := 0.0
        var death_progress: Array = []
        for r in rs:
            match r.outcome:
                "won":
                    won += 1
                    win_times.append(r.seconds)
                "caught":
                    caught += 1
                    death_progress.append(r.progress)
                "run_over":
                    car += 1
                    death_progress.append(r.progress)
                _:
                    timeout += 1
            seen += r.sightings
            chases += r.chases
            esc += r.escapes
            stuns += r.stuns
            sneak += r.sneak_pct
        win_times.sort()
        var med: String = "-" if win_times.is_empty() else str(win_times[win_times.size() / 2])
        var n: float = rs.size()
        var prog := "-"
        if not death_progress.is_empty():
            death_progress.sort()
            prog = "%d%%" % int(100.0 * death_progress[death_progress.size() / 2])
        print("%-9s %4d  %3d%%  %6d  %10d  %7d  %13s  %4.1f  %6.1f  %7.1f  %5.1f  %6d  %s" % [policy, rs.size(), int(100.0 * won / n), caught, car, timeout, med, seen / n, chases / n, esc / n, stuns / n, int(sneak / n), prog])
    print("")
    for r in results:
        if r.outcome == "no_path":
            print("seed %d: NO PATH from the start to home" % r.seed)
            continue
        print("%-8s seed %d  %-9s %6.1fs  walked %5d/%5d  progress %3d%%  seen %2d  chases %2d  escaped %2d  stuns %d  closest cop %d  %s" % [
                r.policy, r.seed, r.outcome, r.seconds, r.walked, r.route, int(100.0 * r.progress), r.sightings, r.chases, r.escapes, r.stuns, r.closest_cop,
                JSON.stringify(r.detail) if not r.detail.is_empty() else ""])
        if verbose:
            for e in r.events:
                print("      %6.1fs  %-8s at (%d, %d)  %d%% of the way left" % [e.t, e.kind, e.x, e.y, int(100.0 * e.home)])
    if out_path != "":
        var f := FileAccess.open(out_path, FileAccess.WRITE)
        if f != null:
            f.store_string(JSON.stringify(results, "  "))
            f.close()

func _profile_only() -> void:
    for seed_value in seeds:
        var main = load("res://scenes/Main.tscn").instantiate()
        main.home_seed = seed_value
        main.traffic_enabled = false
        root.add_child(main)
        for i in 3:
            await process_frame
        var p: Dictionary = _route_profile(main, seed_value)
        print("seed %d: route %d units (%.0fs walking)  patrols within sight of it: %d (%d right on it)  beside it: %s" % [seed_value, p.route, p.route / 85.0, p.cops_cross, p.cops_on_route, JSON.stringify(p.near)])
        main.queue_free()
        for i in 2:
            await process_frame
    quit()

func _init() -> void:
    for a in OS.get_cmdline_user_args():
        var kv: PackedStringArray = a.split("=", true, 1)
        if kv.size() != 2:
            continue
        match kv[0]:
            "policy": policies = Array(kv[1].split(","))
            "seeds": seeds = int(kv[1])
            "runs": runs_per = int(kv[1])
            "max": max_seconds = float(kv[1])
            "out": out_path = kv[1]
            "quiet": quiet = kv[1] == "1"
            "traffic": traffic = kv[1] != "0"
            "verbose": verbose = kv[1] == "1"
    if policies == ["profile"]:
        _profile_only()
        return
    for seed_value in seeds:
        for policy in policies:
            for k in runs_per:
                var r: Dictionary = await _play(policy, seed_value)
                results.append(r)
                if not quiet:
                    print("  finished %s seed %d: %s in %.1fs" % [policy, seed_value, r.outcome, r.seconds])
    _report()
    quit()
