extends SceneTree
# A scripted player for balance data. It walks the real game (real cops, cats, traffic,
# collision and RunLog) from the start to the front door along an A* route, using
# the same pointer/sneak controls as a person, and reports how runs end.
#
#   godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,sneak,careful seeds=6 max=420
#
# Policies (scripted approximations, not novice players):
#   rush     walk the shortest route, never sneak, never look.
#   sneak    the same route, always sneaking.
#   careful  walk, but sneak near cops, stop short of a cop's beam, and wait for cars
#            and skateboarders to pass before stepping into their lane.
#   items    careful + short visible-item detours and contextual use.
#   escape   careful + walk away from nearby active chasers, favoring broken sight.
#   resourceful combines items and escape.
# policy=profile only measures each route (patrols and hazards beside it) without playing.
# Arguments after the -- are optional: policy=a,b  seeds=N (homes 0..N-1)  runs=K (per
# seed and policy)  level=1|2|...  max=seconds  out=/path/results.json  quiet=1  traffic=0 (no cars)  verbose=1 (print each run's events)
# sight=multiplier and chase_speed=units/sec provide paired variants with matched
# seed/run IDs. Check initial_signature before comparing; roster changes may differ.
# Bots know where home is. These runs measure route survival, not novice exploration
# or comprehension; steering errors and random traffic also affect their outcomes.

const STEP := 10.0
const CLEARANCE := 7.0

var policies: Array = ["rush", "sneak", "careful"]
var seeds := 6
var runs_per := 1
var max_seconds := 420.0
var out_path := ""
var quiet := false
var traffic := true
var level := 1
var verbose := false
var results: Array = []
var overrides := {}
var source_signature := ""
var output_error := false
const Inputs := preload("res://docs/tools/audit_inputs.gd")
const Policy := preload("res://docs/tools/bot_policy.gd")
const Clues := preload("res://scripts/Clues.gd")

const Route := preload("res://docs/tools/audit_route.gd")
var planner := Route.new()

func _find_path(main, from: Vector2, to: Vector2) -> Array:
    return planner._find_path(main, from, to)

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
func _clear_walk(main, from: Vector2, to: Vector2) -> bool:
    var steps: int = maxi(1, ceili(from.distance_to(to) / 2.0))
    for i in range(1, steps + 1):
        if main.blocked_circle(from.lerp(to, float(i) / steps), main.player.RADIUS):
            return false
    return true

func _fresh_tutorial() -> void:
    # First-time scent leads last longer. Match teaching memory across policies too.
    Clues.persist = false
    Clues._loaded = true
    Clues.seen.clear()

func _play(policy: String, seed_value: int, run_index: int = 0) -> Dictionary:
    _fresh_tutorial()
    var main = load("res://scenes/Main.tscn").instantiate()
    main.home_seed = seed_value
    main.level_override = level
    main.audit_seed = Inputs.random_seed(seed_value, run_index)
    main.audit_settings = overrides.duplicate()
    main.traffic_enabled = traffic
    main.retry_pos = Vector2.INF
    main.retry_seed = -1
    main.retry_state = {}
    main.process_mode = Node.PROCESS_MODE_DISABLED
    root.add_child(main)
    while not main.is_booted:
        await process_frame
    await process_frame  # register every child before releasing the same frame boundary
    main.runlog.persist = false
    var initial: Dictionary = Inputs.snapshot(main)
    main.process_mode = Node.PROCESS_MODE_INHERIT
    var controller := Policy.new()
    var player = main.player
    var home: Vector2 = main.home_zone.get_center()
    var path: Array = _find_path(main, player.global_position, home)
    main.runlog.audit_path_length = planner.length(path) if not path.is_empty() else -1.0
    var idx := 0
    var hold_t := 0.0
    var traffic_wait := false
    var stalled_t := 0.0
    var last_pos: Vector2 = player.global_position
    var goal := home
    var was_escaping := false
    var waited := false
    var replans := 0
    var item_aware: bool = policy in ["items", "resourceful"]
    var escape_aware: bool = policy in ["escape", "resourceful"]
    if path.is_empty():
        main.runlog.finish("no_path")
    for f in int(max_seconds * 60.0):
        if f > 0 and absf(main.get_process_delta_time() - 1.0 / 60.0) > 0.000001:
            push_error("Audit requires --fixed-fps 60; process step differs")
            output_error = true
            main.runlog.finish("harness_clock_error")
            break
        if main.state != "play" or main.runlog.finished:
            break
        var escaping: bool = escape_aware and not controller.chasers(main).is_empty()
        if item_aware:
            controller.use_item(main, not controller.chasers(main).is_empty())
        var target = controller.nearby_item(main) if item_aware and not escaping else null
        var next_goal: Vector2 = target.global_position if is_instance_valid(target) else home
        if next_goal != goal or (was_escaping and not escaping):
            goal = next_goal
            path = _find_path(main, player.global_position, goal)
            idx = 0
            replans += 1
        # An unreached route can stall even after Player clears has_dest.
        if not waited and not escaping and player.global_position.distance_to(last_pos) < 0.1 \
                and player.stunned_t <= 0.0 and main.dog.planted == "" and player.global_position.distance_to(goal) > 14.0:
            stalled_t += 1.0 / 60.0
        else:
            stalled_t = 0.0
        last_pos = player.global_position
        if stalled_t > 1.5:
            path = _find_path(main, player.global_position, goal)
            idx = 0
            replans += 1
            stalled_t = 0.0
        if path.is_empty():
            main.runlog.finish("steering_failure", {"goal": Inputs.vector(goal)})
            break
        while idx < path.size() - 1 and player.global_position.distance_to(path[idx]) < 18.0 \
                and _clear_walk(main, player.global_position, path[idx + 1]):
            idx += 1
        var aim_i: int = mini(idx + 2, path.size() - 1)
        if not _clear_walk(main, player.global_position, path[aim_i]):
            aim_i = idx
        var aim: Vector2 = path[aim_i]
        var wait_now := false
        if escaping:
            aim = controller.escape_aim(main, 1.0 / 60.0)
            main.sneak_toggle = false
            hold_t = 0.0
            traffic_wait = false
        elif policy in ["careful", "items", "escape", "resourceful"]:
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
            wait_now = wait_now or traffic_wait
            main.sneak_toggle = sneak_now
        else:
            main.sneak_toggle = policy == "sneak"
        if wait_now:
            hold_t += 1.0 / 60.0
            player.has_dest = false
        else:
            hold_t = maxf(0.0, hold_t - 0.5 / 60.0)
            player.dest = aim
            player.has_dest = true
            player.stuck = 0.0
        player.pointer_down = false
        waited = wait_now
        was_escaping = escaping
        await process_frame
    if not main.runlog.finished:
        main.runlog.finish("timeout")
    var summary: Dictionary = main.runlog.summary().duplicate(true)
    summary["tutorial_profile"] = "fresh visitor"
    summary["measurement"] = "route-aware simulation; not beginner completion"
    summary["initial_signature"] = Inputs.signature(initial)
    summary["initial_conditions"] = initial
    summary["settings"] = main.settings.duplicate(true)
    summary["traffic_enabled"] = traffic
    summary["fixed_fps"] = 60
    summary["godot"] = Engine.get_version_info().string
    summary["source_signature"] = source_signature
    summary["steering_replans"] = replans
    summary["item_detours"] = controller.item_detours
    summary["escape_decisions"] = controller.escape_decisions
    if summary.outcome == "timeout":
        summary.detail["position"] = Inputs.vector(player.global_position)
        summary.detail["aim"] = Inputs.vector(player.dest)
        summary.detail["dog_stop"] = main.dog.planted
    if not verbose:
        summary.erase("events")
    summary["policy"] = policy
    summary["seed"] = seed_value
    summary["run"] = run_index
    await process_frame
    main.queue_free()
    for i in 2:
        await process_frame
    return summary

# --- What the route is like, without playing it -------------------------------------------
# Cops whose patrol comes within sight of the route, and other hazards beside it.
func _route_profile(main, seed_value: int) -> Dictionary:
    var path: Array = _find_path(main, main.START, main.home_zone.get_center())
    if path.is_empty():
        return {"seed": seed_value, "astar_path_length": -1.0, "destination_id": main.runlog.summary().destination_id, "cops_cross": 0, "cops_on_route": 0, "near": {}, "outcome": "no_path"}
    var length: float = planner.length(path)
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
    return {"seed": seed_value, "astar_path_length": snappedf(length, 0.1), "destination_id": main.runlog.summary().destination_id, "cops_cross": cops_on, "cops_on_route": cops_close, "near": near}

# --- Report ----------------------------------------------------------------------------
func _report() -> void:
    print("")
    print("Route-aware bot simulations, not beginner completion/retention. Distance gain is radial, not route completion.")
    print("Distinct destinations: ", _destinations())
    print("policy    runs  won%  caught  hit-by-car  ko'd  timeout  harness-failed  median-s(won)  seen  chases  escaped  stuns  life-lost  sneak%  best-distance-gain-at-death")
    for policy in policies:
        var rs: Array = results.filter(func(r): return r.policy == policy)
        if rs.is_empty():
            continue
        var won := 0
        var caught := 0
        var car := 0
        var ko := 0
        var lost := 0.0
        var timeout := 0
        var harness_failed := 0
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
                    death_progress.append(r.best_distance_gain_fraction)
                "run_over":
                    car += 1
                    death_progress.append(r.best_distance_gain_fraction)
                "knocked_out":
                    ko += 1
                    death_progress.append(r.best_distance_gain_fraction)
                "no_path", "steering_failure", "harness_clock_error":
                    harness_failed += 1
                _:
                    timeout += 1
            seen += r.sightings
            for src in r.damage:
                lost += r.damage[src]
            chases += r.chases
            esc += r.escapes
            stuns += r.stuns
            sneak += r.sneak_pct
        win_times.sort()
        var med: String = "-" if win_times.is_empty() else str(_median(win_times))
        var n: float = rs.size()
        var prog := "-"
        if not death_progress.is_empty():
            death_progress.sort()
            prog = "%d%%" % int(100.0 * _median(death_progress))
        print("%-9s %4d  %3d%%  %6d  %10d  %4d  %7d  %14d  %13s  %4.1f  %6.1f  %7.1f  %5.1f  %9d  %6d  %s" % [policy, rs.size(), int(100.0 * won / n), caught, car, ko, timeout, harness_failed, med, seen / n, chases / n, esc / n, stuns / n, int(lost / n), int(sneak / n), prog])
    print("")
    for r in results:
        if r.outcome == "no_path":
            print("seed %d: NO PATH from the start to home" % r.seed)
            continue
        print("%-8s seed %d  %-9s %6.1fs  walked %5d  A* %5d  best distance gain %3d%%  seen %2d  chases %2d  escaped %2d  stuns %d  closest cop %d  %s" % [
                r.policy, r.seed, r.outcome, r.seconds, r.walked, r.astar_path_length, int(100.0 * r.best_distance_gain_fraction), r.sightings, r.chases, r.escapes, r.stuns, r.closest_cop,
                JSON.stringify(r.detail) if not r.detail.is_empty() else ""])
        if verbose:
            for e in r.events:
                print("      %6.1fs  %-8s at (%d, %d)  home distance %d%% of initial" % [e.t, e.kind, e.x, e.y, int(100.0 * e.home_distance_ratio)])
    _write_results()

func _median(values: Array) -> float:
    var middle: int = values.size() / 2
    return float(values[middle]) if values.size() % 2 else (float(values[middle - 1]) + float(values[middle])) * 0.5

func _destinations() -> int:
    var identities := {}
    for result in results:
        identities[result.destination_id] = true
    return identities.size()

func _write_results() -> void:
    if out_path == "":
        return
    var file := FileAccess.open(out_path, FileAccess.WRITE)
    if file == null:
        output_error = true
        push_error("Cannot write audit output: " + out_path)
        quit(1)
        return
    file.store_string(JSON.stringify(results, "  "))

func _profile_only() -> void:
    for seed_value in seeds:
        _fresh_tutorial()
        var main = load("res://scenes/Main.tscn").instantiate()
        main.home_seed = seed_value
        main.level_override = level
        main.audit_seed = Inputs.random_seed(seed_value, 0)
        main.audit_settings = overrides.duplicate()
        main.traffic_enabled = false
        main.process_mode = Node.PROCESS_MODE_DISABLED
        root.add_child(main)
        while not main.is_booted:
            await process_frame
        var initial: Dictionary = Inputs.snapshot(main)
        var p: Dictionary = _route_profile(main, seed_value)
        p.merge({"tutorial_profile": "fresh visitor", "level": level, "policy": "profile", "audit_seed": main.audit_seed, "initial_signature": Inputs.signature(initial), "initial_conditions": initial, "settings": main.settings, "initial_home_distance": main.runlog.home_start, "godot": Engine.get_version_info().string, "source_signature": source_signature, "measurement": "route-aware simulation; not beginner completion"})
        results.append(p)
        print("seed %d: A* path %d units (%.0fs walking)  patrols within sight of it: %d (%d right on it)  beside it: %s" % [seed_value, p.astar_path_length, p.astar_path_length / 85.0, p.cops_cross, p.cops_on_route, JSON.stringify(p.near)])
        main.queue_free()
        for i in 2:
            await process_frame
    _write_results()
    quit(1 if output_error else 0)

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
            "level": level = int(kv[1])
            "verbose": verbose = kv[1] == "1"
            "sight": overrides["cop_sight"] = float(kv[1])
            "chase_speed": overrides["cop_chase_speed"] = float(kv[1])
    source_signature = Inputs.source_signature()
    if not is_equal_approx(Engine.get_physics_ticks_per_second(), 60) or not is_equal_approx(Engine.get_time_scale(), 1.0):
        push_error("Audit requires 60 physics ticks and time_scale=1")
        quit(1)
        return
    for policy in policies:
        if policy not in ["rush", "sneak", "careful", "items", "escape", "resourceful", "profile"]:
            push_error("Unknown policy: " + policy)
            quit(1)
            return
    if policies.has("profile") and policies != ["profile"]:
        push_error("profile must run by itself")
        quit(1)
        return
    if seeds < 1 or runs_per < 1 or max_seconds <= 0.0 or level < 1:
        push_error("seeds, runs, max and level must be positive")
        quit(1)
        return
    if policies == ["profile"]:
        _profile_only()
        return
    for seed_value in seeds:
        for policy in policies:
            for k in runs_per:
                var r: Dictionary = await _play(policy, seed_value, k)
                results.append(r)
                if not quiet:
                    print("  finished %s seed %d: %s in %.1fs" % [policy, seed_value, r.outcome, r.seconds])
    _report()
    quit(1 if output_error else 0)
