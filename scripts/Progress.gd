extends RefCounted
# A completed walk earns the next level, not a mid-chase world snapshot.
# New Run keeps this highest unlock; retries still use Main's in-session map.
const WEB_KEY := "curfew_progress"
const MAX_LEVEL := 10000
static var store_path := "user://progress.json"
static var persist := DisplayServer.get_name() != "headless"
static var loaded := false
static var unlocked := 1
static var last_save_ok := true

static func parse(raw: String) -> int:
    var json := JSON.new()
    if raw == "" or json.parse(raw) != OK or not json.data is Dictionary:
        return 1
    var value: Dictionary = json.data
    if value.get("version") != 1:
        return 1
    var n = value.get("unlocked")
    if not (n is int or n is float) or not is_finite(float(n)):
        return 1
    if float(n) < 1.0 or float(n) > MAX_LEVEL or float(n) != floorf(float(n)):
        return 1
    return int(n)

static func serialize() -> String:
    return JSON.stringify({"version": 1, "unlocked": unlocked})

static func load_once() -> void:
    if loaded:
        return
    loaded = true
    if not persist:
        return
    var raw := ""
    if OS.has_feature("web"):
        var result = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % WEB_KEY, true)
        raw = str(result) if result != null else ""
    elif FileAccess.file_exists(store_path):
        raw = FileAccess.get_file_as_string(store_path)
    unlocked = parse(raw)

static func record_win(completed: int) -> bool:
    load_once()
    if completed < 1 or completed >= MAX_LEVEL or completed + 1 <= unlocked:
        return last_save_ok
    unlocked = completed + 1
    last_save_ok = save()
    return last_save_ok

static func save() -> bool:
    if not persist:
        return true
    var text := serialize()
    if OS.has_feature("web"):
        var result = JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s',%s);return true}catch(e){return false}})()" % [WEB_KEY, JSON.stringify(text)], true)
        return result == true
    var file := FileAccess.open(store_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(text)
    var ok := file.get_error() == OK
    file.close()
    return ok
