extends Node
# The audit node stays alive while the real current scene is reloaded.
const MainScript = preload("res://scripts/Main.gd")
const Game = preload("res://scenes/Main.tscn")
var report: Dictionary = {"samples": []}
var root: Window:
    get: return get_tree().root

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("run")

func _process(_delta: float) -> void:
    # Local profiling must keep running if tool/editor windows take focus.
    get_tree().paused = false
    var game = get_tree().current_scene
    if game != null and game.get("is_booted") == true and game.pause_menu != null:
        game.pause_menu.layer.visible = false

func runtime() -> Dictionary:
    var result: Dictionary = {
        "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
        "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
        "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
        "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
        "static_bytes": OS.get_static_memory_usage(),
        "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
    }
    if OS.has_feature("web"):
        var parsed = JSON.parse_string(JavaScriptBridge.eval("JSON.stringify(window.auditRuntimeSnapshot())", true))
        result.merge(parsed)
    return result

func wait_seconds(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func publish(done: bool = false) -> void:
    report.complete = done
    var json := JSON.stringify(report)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.auditPublish(" + json + ")", true)
    else:
        FileAccess.open("/tmp/curfew-restarts.json", FileAccess.WRITE).store_string(json)

func run() -> void:
    if OS.has_feature("web"):
        while not JavaScriptBridge.eval("window.auditStarted", true):
            await get_tree().process_frame
    var mode: String = "normal"
    if OS.has_feature("web"):
        mode = JavaScriptBridge.eval("window.auditMode", true)
    report.name = "restarts-" + mode
    report.environment = {"godot": Engine.get_version_info().string, "browser": JavaScriptBridge.eval("navigator.userAgent", true) if OS.has_feature("web") else "native", "mode": mode, "configured_playback":ProjectSettings.get_setting_with_override("audio/general/default_playback_type")}
    report.baseline = runtime()
    MainScript.level_number = 6
    var game = Game.instantiate()
    game.home_seed = 731
    root.add_child(game)
    get_tree().current_scene = game
    while not game.is_booted: await get_tree().process_frame
    game.runlog.persist = false
    for cycle in 20:
        await wait_seconds(1.0)
        get_tree().paused = false
        game.pause_menu.layer.visible = false
        # Explicitly run a one-shot as well as the world loops.
        game.play("bark0")
        var old_scene: WeakRef = weakref(game)
        var old_builder: WeakRef = weakref(game.builder)
        var old_furniture: WeakRef = weakref(game.builder.furniture)
        var before := runtime()
        game.restart()
        game = null
        while get_tree().current_scene == null: await get_tree().process_frame
        game = get_tree().current_scene
        while not game.is_booted: await get_tree().process_frame
        game.runlog.persist = false
        await wait_seconds(1.0)
        var after := runtime()
        report.samples.append({"cycle":cycle + 1,"before":before,"after":after,"released":old_scene.get_ref() == null and old_builder.get_ref() == null and old_furniture.get_ref() == null})
        publish()
    game.queue_free()
    game = null
    await wait_seconds(1.0)
    report.cleanup = runtime()
    await wait_seconds(30.0)
    report.after_idle = runtime()
    publish(true)
