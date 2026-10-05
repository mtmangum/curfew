extends SceneTree
const Reference=preload("res://docs/tools/audit_depth_candidate.gd")
func _init() -> void:
    call_deferred("run")

func run() -> void:
    var game=load("res://scenes/Main.tscn").instantiate()
    game.level_override=6
    game.home_seed=731
    game.audit_seed=731
    game.traffic_enabled=false
    root.add_child(game)
    game.runlog.persist=false
    game.set_process(false)
    var candidate=Reference.new(game)
    var results: Array=[]
    for at in [game.START,Vector2(1800,1200),Vector2(4200,1700),Vector2(6800,2300)]:
        game.focus=at
        var times: Dictionary={}
        game.depth.sort()
        var expected: Dictionary={}
        for node in game.actors.get_children(): expected[node.get_instance_id()]=node.z_index
        candidate.sort()
        var same:=true
        for node in game.actors.get_children():
            if expected[node.get_instance_id()]!=node.z_index: same=false
        for label in ["optimized","reference"]:
            var samples: Array=[]
            for i in 200:
                var start:=Time.get_ticks_usec()
                if label=="optimized": game.depth.sort()
                else: candidate.sort()
                samples.append(float(Time.get_ticks_usec()-start)/1000.0)
            samples.sort()
            times[label]={"p50":samples[100],"p95":samples[190]}
        results.append({"position":str(at),"same_order":same,"ms":times})
    FileAccess.open("/tmp/curfew-depth-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    print(JSON.stringify(results))
    candidate=null
    game.queue_free()
    game=null
    for i in 4: await process_frame
    quit()
