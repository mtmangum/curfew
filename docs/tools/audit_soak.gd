extends "res://docs/tools/audit_restarts.gd"
# Real player pointer controls, real loss/win transitions and real scene reloads.
const Route = preload("res://docs/tools/audit_route.gd")
var planner := Route.new()

func publish(done: bool = false) -> void:
    report.complete = done
    var json := JSON.stringify(report)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.auditPublish(" + json + ")", true)
    else:
        var output := OS.get_environment("AUDIT_OUT")
        if output == "": output = "/tmp/curfew-soak.json"
        FileAccess.open(output, FileAccess.WRITE).store_string(json)

func stats(values: Array) -> Dictionary:
    values.sort()
    if values.is_empty(): return {}
    return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*0.95))],"max":values[-1]}

func run() -> void:
    var browser: bool = OS.has_feature("web")
    if browser:
        while not JavaScriptBridge.eval("window.auditStarted", true): await get_tree().process_frame
    var duration := 1800.0
    var requested := OS.get_environment("AUDIT_SECONDS")
    if requested != "": duration = float(requested)
    report = {"name":"soak-chrome" if browser else "soak-native","samples":[],"runs":[]}
    report.environment = {"godot":Engine.get_version_info().string,"browser":JavaScriptBridge.eval("navigator.userAgent",true) if browser else "none","seconds":duration,"clock":"wall" if browser else "simulated fixed 60 FPS","playback_type":ProjectSettings.get_setting_with_override("audio/general/default_playback_type"),"renderer":RenderingServer.get_current_rendering_method(),"debug":OS.is_debug_build()}
    if not browser:
        report.source_hashes = {}
        for filename in DirAccess.get_files_at("res://scripts"):
            if filename.ends_with(".gd"):
                report.source_hashes[filename] = FileAccess.get_file_as_string("res://scripts/"+filename).sha256_text()
    report.baseline = runtime()
    MainScript.level_number = 10
    var game = Game.instantiate()
    game.home_seed = 731
    root.add_child(game)
    get_tree().current_scene = game
    while not game.is_booted: await get_tree().process_frame
    game.runlog.persist = false
    var path: Array = planner._find_path(game,game.START,game.home_zone.get_center())
    var index := 0
    var elapsed := 0.0
    var segment := 0.0
    var frames := 0
    var restarts := 0
    var max_traffic := 0
    var max_skaters := 0
    var distance := 0.0
    var previous_position: Vector2 = game.player.global_position
    var values: Array = []
    var process_times: Array = []
    var started := Time.get_ticks_usec()
    var previous := started
    while elapsed < duration:
        get_tree().paused = false
        game.pause_menu.layer.visible = false
        await get_tree().process_frame
        var now := Time.get_ticks_usec()
        values.append(float(now-previous)/1000.0)
        previous = now
        process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
        frames += 1
        var delta := game.get_process_delta_time()
        elapsed = float(now-started)/1000000.0 if browser else elapsed + delta
        segment += delta
        max_traffic = maxi(max_traffic,game.traffic.size())
        max_skaters = maxi(max_skaters,game.skaters.size())
        distance += previous_position.distance_to(game.player.global_position)
        previous_position = game.player.global_position
        if game.state != "play" or segment > 120.0:
            var summary: Dictionary = game.runlog.summary()
            summary.erase("events")
            report.runs.append(summary)
            MainScript.level_number = [1,2,10][restarts % 3]
            game.restart(true)
            game = null
            while get_tree().current_scene == null: await get_tree().process_frame
            game = get_tree().current_scene
            while not game.is_booted: await get_tree().process_frame
            game.runlog.persist = false
            path = planner._find_path(game,game.START,game.home_zone.get_center())
            index = 0
            segment = 0.0
            restarts += 1
            previous_position = game.player.global_position
        if not path.is_empty():
            while index < path.size()-1 and game.player.global_position.distance_to(path[index]) < 18.0: index += 1
            game.player.dest = path[mini(index+2,path.size()-1)]
            game.player.has_dest = true
            game.player.pointer_down = false
            game.player.stuck = 0.0
            game.sneak_toggle = false
        if elapsed >= float(report.samples.size()+1)*60.0:
            report.samples.append({"minute":report.samples.size()+1,"elapsed":elapsed,"frames":frames,"frame_ms":stats(values),"process_ms":stats(process_times),"after":runtime(),"distance":distance,"restarts":restarts,"max_traffic":max_traffic,"max_skaters":max_skaters})
            values.clear()
            process_times.clear()
            publish()
            print("SOAK minute ",report.samples.size()," restarts ",restarts)
    report.elapsed_seconds = elapsed
    report.wall_seconds = float(Time.get_ticks_usec()-started)/1000000.0
    report.final_world = runtime()
    game.queue_free()
    game = null
    if not browser: Engine.max_fps = 60  # permit real audio-driver teardown time
    await wait_seconds(1.0)
    report.cleanup = runtime()
    await wait_seconds(30.0 if browser else 0.4)
    report.after_idle = runtime()
    publish(true)
    if not browser: get_tree().quit()
