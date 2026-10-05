extends SceneTree
# Repeatable performance/memory probe. AUDIT_OUT chooses JSON output.
# --headless measures CPU/lifecycle only; --rendering-method gl_compatibility
# measures rendered desktop frames with the web-compatible renderer.
const Scene = preload("res://scenes/Main.tscn")
const Helpers = preload("res://docs/tools/world_helpers.gd")
const Sprites = preload("res://scripts/Sprites.gd")
var report := {"scenarios":[],"cleanup":[],"benchmarks":[]}
func _init() -> void:
    call_deferred("run")
func stats(a: Array) -> Dictionary:
    a.sort()
    return {"p50":a[int(a.size()*0.5)],"p95":a[mini(a.size()-1,int(a.size()*0.95))],"max":a[-1]}
func snapshot() -> Dictionary:
    return {"static_bytes":OS.get_static_memory_usage(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
func fresh(level: int):
    var game = Scene.instantiate()
    game.level_override=level
    game.home_seed=731
    game.audit_seed=731
    print("AUDIT building level ",level)
    root.add_child(game)
    while not game.is_booted: await process_frame
    game.runlog.persist=false
    return game
func bench(game, label: String) -> void:
    for method in ["sort","fade_buildings","gate","ray_hit"]:
        var times: Array=[]
        for i in 80:
            var before:=Time.get_ticks_usec()
            match method:
                "sort": game.depth.sort()
                "fade_buildings": game.depth.fade_buildings(1.0/60.0)
                "gate": game.gate.update()
                "ray_hit":
                    for k in 32:
                        game.ray_hit(game.player.global_position,Vector2.from_angle(float(k)*TAU/32.0),250.0)
            times.append(float(Time.get_ticks_usec()-before)/1000.0)
        report.benchmarks.append({"scenario":label,"method":method,"ms":stats(times)})
func run() -> void:
    print("AUDIT starting")
    root.size=Vector2i(1280,720)
    if DisplayServer.get_name()!="headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps=0
    report.environment={"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":"1280x720","seed":731,"debug":OS.is_debug_build()}
    report.source_hashes={}
    for name in DirAccess.get_files_at("res://scripts"):
        if name.ends_with(".gd"):
            report.source_hashes[name]=FileAccess.get_file_as_string("res://scripts/"+name).sha256_text()
    report.baseline=snapshot()
    for level in [1,2,3,6,10]:
        var before:=Time.get_ticks_usec()
        var game= await fresh(level)
        var boot_ms:=float(Time.get_ticks_usec()-before)/1000.0
        for sample in ["spawn","dense"]:
            var at: Vector2=game.START
            if sample=="dense":
                var best:=0
                for candidate in game.cops:
                    var count:=0
                    for other in game.cops:
                        if candidate.global_position.distance_squared_to(other.global_position)<800.0*800.0: count+=1
                    if count>best:
                        best=count
                        at=candidate.global_position
            at=Helpers.free_spot(game,at)
            game.player.global_position=at
            game.dog.global_position=at+Vector2(30,0)
            game.focus=at
            game.player.set_physics_process(false)
            game.dog.set_physics_process(false)
            game.gate.update()
            for i in 60: await process_frame
            var deltas: Array=[]
            var process_ms: Array=[]
            var physics_ms: Array=[]
            var draws: Array=[]
            var previous:=Time.get_ticks_usec()
            for i in 240:
                paused=false  # profiling continues if the audit window loses focus
                game.pause_menu.layer.visible=false
                game.state="play"
                await process_frame
                var now:=Time.get_ticks_usec()
                deltas.append(float(now-previous)/1000.0)
                previous=now
                process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
                physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
                draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
            var totals: Dictionary={}
            var active: Dictionary={}
            var processing: Dictionary={}
            for name in ["cops","cats","npcs","vents","fires","lamps","fans","traffic","skaters"]:
                var list: Array=game.get(name)
                totals[name]=list.size()
                active[name]=list.filter(func(n): return n.can_process()).size()
                processing[name]=list.filter(func(n): return n.can_process() and n.is_processing()).size()
            var label:="level_%d_%s"%[level,sample]
            report.scenarios.append({"name":label,"boot_ms":boot_ms,"frame_ms":stats(deltas),"process_ms":stats(process_ms),"physics_ms":stats(physics_ms),"draw_calls":stats(draws),"memory":snapshot(),"total":totals,"active":active,"processing":processing})
            bench(game,label)
            print("AUDIT ",label," frame ",stats(deltas)," memory ",snapshot())
        game.queue_free()
        game=null
        for i in 10: await process_frame
        report.cleanup.append(snapshot())
    # Rebuild/free the same late-level world repeatedly, looking for retained objects.
    report.cycles=[]
    for i in 10:
        var game=await fresh(6)
        for j in 12: await process_frame
        game.queue_free()
        game=null
        for j in 10: await process_frame
        report.cycles.append(snapshot())
    var dest:=OS.get_environment("AUDIT_OUT")
    if dest=="": dest="/tmp/curfew-performance-audit.json"
    var file:=FileAccess.open(dest,FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    print("AUDIT saved ",dest," cycles ",report.cycles)
    quit()
