extends RefCounted
# One-time hints that explain what just happened, so the rules do not have to be guessed: a cat
# knocks over a bin and a cop turns up; Stella lifts her head and leads off; a "?" or "!" appears
# over a cop. Each one is shown once, ever (remembered across visits: in the browser's localStorage on
# the web, a file in user:// elsewhere), and only on the levels that ask for it (`settings.clues`,
# levels 1 to 3: by level 4 the rules are known). They show on a card at the bottom of the screen
# (Hud.show_clue) for long enough to read, one at a time and not too close together.
# (Main owns one: `main.clues`; things call `main.clues.offer("bin")` when they happen. Typing CLUES
# in the game forgets what has been shown.)

const Style := preload("res://scripts/Style.gd")
const Items := preload("res://scripts/Items.gd")

const COOLDOWN := 6.0   # seconds between two clues (an urgent one skips the wait)
const GRACE := 3.0      # nothing in the first few seconds of a level
const STORE := "user://clues.json"
const WEB_KEY := "curfew_clues"

# id -> the picture and the words. Say what happened, then what to do about it.
const CATALOG := {
    "bin": {"icon": "bin", "text": "A cat knocked over a bin, and the crash drew a cop. Cops come to check out loud noises."},
    "bin_quiet": {"icon": "bin", "text": "A cat knocked over a bin. Crashes are loud: any cop close by will come to look."},
    "scent": {"icon": "house", "text": "Stella smells home. Follow her toward the next street. Need a hint? Tap Stella, home? or press H."},
    "phone": {"icon": "question", "text": "This phone works. Stand beside it, still, for 3 seconds to reveal nearby streets on the map. It does not mark home."},
    "cop_look": {"icon": "question", "text": "A yellow ? means a cop is noticing you or checking something out. Leave his beam and stay out of sight."},
    "cop_chase": {"icon": "alert", "text": "A red ! means you have been spotted and he is after you. Break his line of sight and keep moving: he gives up."},
    "drag": {"icon": "paw", "text": "Stella is hauling you after something. Being dragged is loud and easy to spot: walk the other way to hold her back."},
    "zombie": {"icon": "zombie", "text": "A zombie hobo has woken and is coming. They are slow: keep moving, and do not stand about."},
}

# The found items each have a card the first time she picks one up ("item_treat" and so on, from Items.gd).
static func catalog(id: String) -> Dictionary:
    if CATALOG.has(id):
        return CATALOG[id]
    if id.begins_with("item_") and Items.INFO.has(id.trim_prefix("item_")):
        var kind: String = id.trim_prefix("item_")
        return {"icon": "item_" + kind, "text": Items.INFO[kind].text}
    return {}

static var seen := {}      # ids already shown (across visits)
static var persist := DisplayServer.get_name() != "headless"  # the tests run headless: they neither read nor write the real store
static var _loaded := false

var main
var current_id := ""     # the clue now on the card ("" when none)
var last_at := 0.0       # when the last one was shown, in seconds

func _init(game) -> void:
    main = game
    _load_once()
    last_at = _now() - COOLDOWN + GRACE

static func _now() -> float:
    return Time.get_ticks_msec() / 1000.0

# How long a clue stays up: a moment to notice it, then about 25 characters a second.
static func reading_time(text: String) -> float:
    return clampf(1.2 + 0.04 * float(text.length()), 4.0, 7.0)

# Shows the clue `id` if it is the right time: it has not been shown before, this level has clues,
# the game is running, the level's title card is not up, and the last one was a while ago (or this one
# is urgent). Returns whether it was shown. `urgent` is for something that is happening to her now.
func offer(id: String, urgent: bool = false) -> bool:
    if catalog(id).is_empty() or seen.has(id):
        return false
    if not main.settings.clues or main.state != "play" or main.hud == null:
        return false
    if main.hud.title_card.modulate.a > 0.02:
        return false
    var now: float = _now()
    if not urgent and (now - last_at < COOLDOWN or main.hud.clue_up):
        return false
    var clue: Dictionary = catalog(id)
    seen[id] = true
    _save()
    current_id = id
    last_at = now
    main.hud.show_clue(clue.icon, clue.text, reading_time(clue.text))
    return true

# --- remembering what has been shown ------------------------------------------------------

static func serialize() -> String:
    return JSON.stringify(seen.keys())

static func parse(raw: String) -> Dictionary:
    var out := {}
    var json := JSON.new()  # (not JSON.parse_string: that logs an error for a damaged store)
    if raw != "" and json.parse(raw) == OK and json.data is Array:
        for id in json.data:
            out[str(id)] = true
    return out

static func _load_once() -> void:
    if _loaded:
        return
    _loaded = true
    if not persist:
        return
    var raw := ""
    if OS.has_feature("web"):
        var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % WEB_KEY, true)
        raw = str(v) if v != null else ""
    elif FileAccess.file_exists(STORE):
        raw = FileAccess.get_file_as_string(STORE)
    seen = parse(raw)

static func _save() -> void:
    if not persist:
        return
    var text: String = serialize()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [WEB_KEY, JSON.stringify(text)], true)
    else:
        var f := FileAccess.open(STORE, FileAccess.WRITE)
        if f != null:
            f.store_string(text)
            f.close()

# Forget everything that has been shown, so the clues come round again.
static func reset() -> void:
    seen.clear()
    _loaded = true
    _save()
