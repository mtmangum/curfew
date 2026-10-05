extends RefCounted
# One-time hints that explain what just happened, so the rules do not have to be guessed: a cat
# knocks over a bin and a cop turns up; Stella lifts her head and leads off; a "?" or "!" appears
# over a cop. Each one is shown once, ever (remembered across visits: in the browser's localStorage on
# the web, a file in user:// elsewhere), after a full visible reading interval, and only on the levels that ask for it (`settings.clues`,
# levels 1 to 3: by level 4 the rules are known). They show on a card at the bottom of the screen
# (Hud.show_clue) for long enough to read. Ordinary explanations queue; urgent warnings
# interrupt them, then the interrupted explanation returns for a fresh reading interval.
# (Main owns one: `main.clues`; things call `main.clues.offer("bin")` when they happen. Typing CLUES
# in the game forgets what has been shown.)

const Style := preload("res://scripts/Style.gd")
const Items := preload("res://scripts/Items.gd")

const COOLDOWN := 6.0   # seconds between two clues (an urgent one skips the wait)
const GRACE := 3.0      # nothing in the first few seconds of a level
const STORE := "user://clues.json"
const WEB_KEY := "curfew_clues"
const TITLES := {
    "patrol": "Going around patrols",
    "bin": "Loud bin crashes", "bin_quiet": "Noise attracts cops",
    "scent": "Stella’s home cue", "phone": "Working phones",
    "cop_look": "A cop’s yellow ?", "cop_chase": "A cop’s red !",
    "drag": "Stella pulling", "zombie": "Zombie hobos",
}

# id -> the picture and the words. Say what happened, then what to do about it.
const CATALOG := {
    "patrol": {"icon": "question", "text": "A patrol ahead. Use Sneak to stay quiet, or take a street outside his beam. You can go around."},
    "bin": {"icon": "bin", "text": "A cat knocked over a bin, and the crash drew a cop. Cops come to check out loud noises."},
    "bin_quiet": {"icon": "bin", "text": "A cat knocked over a bin. Crashes are loud: any cop close by will come to look."},
    "scent": {"icon": "house", "text": "Stella smells home. Follow her home arrow; she waits for you to walk. Need help? Pause → Stella, home? or H."},
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
var last_id := ""        # context when opening the field guide
var last_at := 0.0       # gameplay time when the last clue started
var elapsed := 0.0       # does not advance while paused or after the run ends
var reading_left := 0.0
var pending: Array[String] = []  # bounded by the distinct catalogue IDs

func _init(game) -> void:
    main = game
    _load_once()
    last_at = -COOLDOWN + GRACE

# Explain a calm cop only when he is on screen with an unobstructed view, before
# entering his beam. A wall between them is already a successful way around.
func notice_patrol(cop) -> void:
    if not main.settings.clues or main.state != "play" or seen.has("patrol") or current_id == "patrol" or pending.has("patrol"):
        return
    if cop.state != cop.State.PATROL or cop.seeing:
        return
    var offset: Vector2 = cop.global_position - main.player.global_position
    var distance: float = offset.length()
    if distance < 1.0 or distance > 200.0:
        return
    var screen: Vector2 = main.get_viewport().canvas_transform * cop.global_position
    if main.get_viewport_rect().grow(-40.0).has_point(screen) and main.ray_hit(main.player.global_position, offset / distance, distance) >= distance - 1.0:
        offer("patrol")

# How long a clue stays up: a moment to notice it, then about 25 characters a second.
static func reading_time(text: String) -> float:
    return clampf(1.2 + 0.04 * float(text.length()), 4.0, 7.0)

# Accept an unseen explanation once. Item pickups are ordinary teaching, not danger.
# The return value means accepted (shown now or queued), so one-shot events are retained.
func offer(id: String, urgent: bool = false) -> bool:
    if catalog(id).is_empty() or seen.has(id) or current_id == id or pending.has(id):
        return false
    if not main.settings.clues or main.state != "play" or main.hud == null:
        return false
    if urgent:
        # Keep an unread interrupted card ahead of the ordinary backlog.
        if current_id != "" and not seen.has(current_id):
            pending.push_front(current_id)
        _start(id)
    else:
        pending.append(id)
        _next()
    return true

func _start(id: String) -> void:
    var clue: Dictionary = catalog(id)
    current_id = id
    last_id = id
    last_at = elapsed
    reading_left = reading_time(clue.text)
    main.hud.show_clue(clue.icon, clue.text, reading_left, finished_reading.bind(id))

func _next() -> void:
    if current_id != "" or main.hud.clue_up or pending.is_empty() or elapsed - last_at < COOLDOWN or main.hud.title_card.modulate.a > 0.02:
        return
    _start(pending.pop_front())

func update(delta: float) -> void:
    if main.state != "play" or main.get_tree().paused:
        return
    elapsed += delta
    if current_id != "":
        # Fade-in and hidden/paused time cannot count as reading. Completion is driven
        # by the HUD hold callback so a low-FPS frame cannot miss the final interval.
        if main.hud.clue_up and main.hud.clue_layer.visible and main.hud.clue_layer.modulate.a >= 0.98:
            reading_left = maxf(0.0, reading_left - delta)
        if not main.hud.clue_up:
            current_id = ""
    _next()

func finished_reading(id: String) -> void:
    if current_id != id or main.state != "play" or main.get_tree().paused or not main.hud.clue_layer.visible:
        return
    seen[current_id] = true
    reading_left = 0.0
    _save()

# Used by the CLUES reset and fixtures; cancel the old timer as well as the queue.
func cancel() -> void:
    pending.clear()
    current_id = ""
    reading_left = 0.0
    main.hud.dismiss_clue()

static func guide_ids(level: int) -> Array[String]:
    var ids: Array[String] = []
    for id in CATALOG:
        ids.append(id)
    for kind in Items.available(level):
        ids.append("item_" + kind)
    return ids

static func title(id: String) -> String:
    return Items.info(id.trim_prefix("item_")).name if id.begins_with("item_") else TITLES.get(id, id)

static func display_text(text: String, pointer: bool) -> String:
    return text.replace("Use it (E)", "Tap the item").replace(" or press H", "").replace(" or H", "") if pointer else text

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
