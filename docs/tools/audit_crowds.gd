extends SceneTree
# Synthetic sort pressure; fixtures are Node2D actors, not extra gameplay AI.
const Reference = preload("res://docs/tools/audit_depth_candidate.gd")
const Sorter = preload("res://scripts/DepthSorter.gd")
class CountedSorter extends Sorter:
    var key_reads := 0
    func depth_key(node) -> float:
        key_reads += 1
        return super.depth_key(node)

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://scenes/Main.tscn").instantiate()
    game.level_override = 10
    game.home_seed = 731
    game.audit_seed = 731
    game.traffic_enabled = false
    root.add_child(game)
    game.runlog.persist = false
    game.process_mode = Node.PROCESS_MODE_DISABLED
    var sorter := CountedSorter.new(game)
    var reference := Reference.new(game)
    var report: Dictionary = {"samples":[],"tree_categories":{},"node_count":game.get_child_count()}
    var pending: Array = [game]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        var category: String = node.get_script().resource_path if node.get_script() else node.get_class()
        report.tree_categories[category] = int(report.tree_categories.get(category,0)) + 1
        pending.append_array(node.get_children())
    var added: Array[Node2D] = []
    for extras in [0,32,64,128,256]:
        while added.size() < extras:
            var actor := Node2D.new()
            actor.position = game.START + Vector2((added.size()%16)*12-96,(added.size()/16)*10-80)
            game.actors.add_child(actor)
            game.npcs.append(actor)
            added.append(actor)
        sorter.key_reads = 0
        sorter.sort()
        var item_count: int = sorter.key_reads
        var expected: Dictionary = {}
        for actor in game.actors.get_children(): expected[actor.get_instance_id()] = actor.z_index
        reference.sort()
        var identical := true
        for actor in game.actors.get_children():
            if expected[actor.get_instance_id()] != actor.z_index: identical = false
        var timings: Dictionary = {}
        for label in ["cached","reference"]:
            var values: Array[float] = []
            for i in 60:
                var start := Time.get_ticks_usec()
                if label == "cached": sorter.sort()
                else: reference.sort()
                values.append(float(Time.get_ticks_usec()-start)/1000.0)
            values.sort()
            timings[label] = {"p50":values[30],"p95":values[57],"max":values[-1]}
        report.samples.append({"extra_actors":extras,"visible_items":item_count,"identical_order":identical,"sort_ms":timings})
    FileAccess.open("res://docs/audits/2026-10-04/followup/crowds.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report.samples))
    game.queue_free()
    game = null
    sorter = null
    reference = null
    for i in 4: await process_frame
    await create_timer(0.4).timeout
    quit()
