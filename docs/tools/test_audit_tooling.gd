extends SceneTree
const Game := preload("res://scenes/Main.tscn")
const Inputs := preload("res://docs/tools/audit_inputs.gd")
const Route := preload("res://docs/tools/audit_route.gd")
const Policy := preload("res://docs/tools/bot_policy.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")
var failed := false

func check(label: String, passed: bool) -> void:
    print(label, "  ok: ", passed)
    failed = failed or not passed

func fresh(audit_seed: int, overrides: Dictionary = {}, retry_at: Vector2 = Vector2.INF):
    var game = Game.instantiate()
    game.home_seed = 1
    game.level_override = 3
    game.audit_seed = audit_seed
    game.audit_settings = overrides
    game.traffic_enabled = true
    game.retry_pos = retry_at
    game.retry_seed = -1
    game.retry_state = {}
    game.process_mode = Node.PROCESS_MODE_DISABLED
    root.add_child(game)
    game.runlog.persist = false
    await process_frame
    game.process_mode = Node.PROCESS_MODE_INHERIT
    return game

func dispose(game) -> void:
    game.queue_free()
    for i in 2:
        await process_frame

func replay(extra_sounds: bool = false) -> Dictionary:
    var game = await fresh(1001)
    var initial: Dictionary = Inputs.snapshot(game)
    # Fixed documented inputs include a LOOK cop, exercising the former wall clock.
    var cop = game.cops[0]
    cop.global_position = game.START + Vector2(300, 0)
    cop.state = cop.State.LOOK
    cop.look_t = 30.0
    cop.angle = PI
    game.player.dest = game.START + Vector2(300, -100)
    game.player.has_dest = true
    for i in 900:
        if extra_sounds and i % 60 == 0:
            game.audio.bark()
            game.audio.footstep(-6.0)
        await process_frame
    var final: Dictionary = Inputs.snapshot(game)
    var log: Dictionary = game.runlog.summary().duplicate(true)
    await dispose(game)
    return {"initial": initial, "final": final, "log": log}

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var first: Dictionary = await replay()
    var second: Dictionary = await replay()
    check("Cold/warm boot actor and RNG states repeat", first.initial == second.initial)
    if first.final != second.final:
        FileAccess.open("/tmp/curfew-a8-state-diff.json", FileAccess.WRITE).store_string(JSON.stringify([first.final, second.final], "  "))
    check("Fixed-input actor states and weather/traffic replay", first.final == second.final)
    check("Fixed-input event timeline and summary replay", first.log == second.log)
    var sound_variant: Dictionary = await replay(true)
    check("Extra sound variations do not perturb actor replay", sound_variant.final == first.final and sound_variant.log == first.log)
    var game = await fresh(1002)
    check("Changing run ID changes initial actor state", Inputs.signature(Inputs.snapshot(game)) != Inputs.signature(first.initial))
    await dispose(game)
    game = await fresh(1001, {"cop_sight": 0.5, "cop_chase_speed": 72.0})
    check("Paired reaction/speed variant matches initial conditions", Inputs.snapshot(game) == first.initial and game.settings.cop_sight == 0.5)
    var planner := Route.new()
    var path: Array = planner._find_path(game, game.player.global_position, game.home_zone.get_center())
    game.runlog.audit_path_length = planner.length(path)
    var swept := not path.is_empty()
    for i in range(1, path.size()):
        swept = swept and planner._clear_walk(game, path[i - 1], path[i])
    check("A* connects real start and door with clear swept edges", swept and path[0] == game.player.global_position and path[-1] == game.home_zone.get_center())
    var log: Dictionary = game.runlog.summary()
    check("Schema distinguishes A* length and initial straight-line distance", log.schema == 2 and log.astar_path_length > log.initial_home_distance and not log.has("route") and not log.has("progress"))
    check("Destination identity is stable across paired variants", log.destination_id == first.log.destination_id)
    var original_distance: float = log.initial_home_distance
    var retry_at: Vector2 = game.START + Vector2(100, 0)
    await dispose(game)
    game = await fresh(1001, {}, retry_at)
    check("Retry log uses actual run origin", not is_equal_approx(game.runlog.home_start, original_distance) and is_equal_approx(game.runlog.home_start, game.player.global_position.distance_to(game.home_zone.get_center())))
    await dispose(game)

    # Level 1 has an existing visible treat. Walk to it without inventory injection.
    var policy := Policy.new()
    var item = null
    game = Game.instantiate()
    game.home_seed = 0
    game.level_override = 1
    game.audit_seed = 1
    game.traffic_enabled = false
    root.add_child(game)
    game.runlog.persist = false
    policy = Policy.new()
    item = policy.nearby_item(game)
    check("Visible nearby item produces a bounded detour", item != null and item.global_position.distance_to(game.player.global_position) <= 180.0 and policy.item_detours == 1)
    var treat_at: Vector2 = item.global_position
    for i in 180:
        game.player.dest = treat_at
        game.player.has_dest = true
        await process_frame
        policy.use_item(game, false)
        if game.items.treat_on():
            break
    check("Policy uses collected treat and records real effect", game.items.treat_on() and game.runlog.items_found.get("treat", 0) == 1 and game.runlog.items.get("treat", 0) == 1 and game.carried == "")
    await dispose(game)

    # Real chase on an open road. Set the initial chase explicitly, then let AI run.
    game = await fresh(1001)
    game.traffic_director.enabled = false
    for list in [game.cops, game.cats, game.npcs, game.squirrels]:
        for actor in list:
            actor.set_process(false)
    game.dog.set_process(false)
    game.player.global_position = Helpers.road_east()
    game.dog.global_position = game.player.global_position + Vector2(-20, 8)
    var cop = game.cops[0]
    cop.global_position = game.player.global_position - Vector2(65, 0)
    cop.state = cop.State.CHASE
    cop.target = game.player.global_position
    cop.angle = 0.0
    cop.set_process(true)
    game.runlog._last_pos = game.player.global_position
    policy = Policy.new()
    var separation: float = cop.global_position.distance_to(game.player.global_position)
    var first_aim: Vector2 = policy.escape_aim(game, 1.0 / 60.0)
    check("Escape aims along a clear route away from the pursuer", planner._clear_walk(game, game.player.global_position, first_aim) and first_aim.distance_to(cop.global_position) > separation)
    for i in 720:
        if game.state != "play" or cop.state != cop.State.CHASE:
            break
        game.sneak_toggle = false
        game.player.dest = policy.escape_aim(game, 1.0 / 60.0)
        game.player.has_dest = true
        await process_frame
    await process_frame
    check("Walking escape survives and real cop gives up", game.state == "play" and cop.state != cop.State.CHASE and game.runlog.escapes >= 1 and not game.player.sneaking)
    game.carried = "donut"
    cop.state = cop.State.CHASE
    cop.global_position = game.player.global_position - Vector2(65, 0)
    policy.use_item(game, true)
    check("Item policy saves donuts during a chase", game.carried == "donut" and game.donuts.is_empty())
    game.carried = "extinguisher"
    policy.use_item(game, true)
    check("Item policy hides with a real cloud during close pursuit", game.carried == "" and game.in_steam(game.player.global_position) and game.runlog.items.get("extinguisher", 0) == 1)
    await dispose(game)
    game = await fresh(-1, {"cop_sight": 99.0})
    check("Audit overrides are opt-in", game.settings.cop_sight != 99.0)
    await dispose(game)
    quit(1 if failed else 0)
