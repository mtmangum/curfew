extends Node
# Playtest telemetry. Watches a run (without touching how it plays) and keeps the
# numbers a designer needs: how long it took, how often cops saw Nicole, how often a
# chase began and ended, and how and where the run finished. Press F3 for a live
# readout. A finished run is printed as a RUNLOG line and, in a real (non-headless)
# build, saved: to user://runs.jsonl, and on the web to localStorage "curfew_runs"
# (read it in the browser console with localStorage.getItem("curfew_runs")).
# The headless bot in docs/tools/bot_playtest.gd reads `summary()` directly.

const MAX_SAVED := 60
const MAX_SESSION := 40
const EVENT_LIMIT := 400

# Every run finished since the game was opened (survives restarts), so one paste can
# carry a whole play session.
static var session: Array = []

var main
var t := 0.0
var finished := false
var outcome := ""
var detail := {}
var events: Array = []
var persist := true

var walked := 0.0
var sneak_t := 0.0
var lit_t := 0.0
var dragged_t := 0.0
var held_t := 0.0
var stuns := 0
var damage := {}         # life lost, by what hurt her
var pickups := 0         # pizza slices eaten
var stops := {}          # times Stella planted herself, by what (pee / tree)
var stella_held_s := 0.0 # seconds the leash held Nicole while Stella was planted
var zombie_bites := 0
var phone_calls := 0
var life_left := 100.0
var sightings := 0       # a cop began to see Nicole or Stella
var chases := 0          # a cop began a chase
var escapes := 0         # a chase ended without catching her
var investigations := 0  # a cop went to look at a noise or glimpse
var longest_chase := 0.0
var closest_cop := INF
var home_start := 1.0
var home_best := INF

var _last_pos := Vector2.ZERO
var _cop_state := {}     # cop id -> {chase, seeing, inv, chase_t}
var _was_stunned := false
var _was_held := false
var _label: Label
var _layer: CanvasLayer
var _readout_t := 0.0

func setup(game) -> void:
    main = game
    _last_pos = main.player.global_position
    home_start = maxf(main.home_zone.get_center().distance_to(main.START), 1.0)
    home_best = home_start
    _layer = CanvasLayer.new()
    _layer.layer = 60
    add_child(_layer)
    _label = Label.new()
    _label.position = Vector2(12, 150)
    _label.add_theme_font_size_override("font_size", 13)
    _label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
    _label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    _label.add_theme_constant_override("outline_size", 4)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _layer.add_child(_label)
    _layer.visible = false

func toggle() -> void:
    _layer.visible = not _layer.visible

func _process(delta: float) -> void:
    if main == null or main.player == null or finished or main.state != "play":
        return
    t += delta
    var p: Node2D = main.player
    walked += p.global_position.distance_to(_last_pos)
    _last_pos = p.global_position
    var home_d: float = p.global_position.distance_to(main.home_zone.get_center())
    home_best = minf(home_best, home_d)
    if main.dog.planted != "":
        stella_held_s += delta
    if p.sneaking:
        sneak_t += delta
    if p.lit:
        lit_t += delta
    if p.dragged_t > 0.0:
        dragged_t += delta
    if p.slow_t > 0.0:
        held_t += delta
    var stunned: bool = p.stunned_t > 0.0
    if stunned and not _was_stunned:
        stuns += 1
        _event("stun")
    _was_stunned = stunned
    var held: bool = p.slow_t > 0.0
    if held and not _was_held:
        _event("held")
    _was_held = held
    for c in main.cops:
        var d: float = c.global_position.distance_to(p.global_position)
        if d > 700.0:
            continue
        closest_cop = minf(closest_cop, d)
        _watch_cop(c, delta)
    if _layer.visible:
        _readout_t -= delta
        if _readout_t <= 0.0:
            _readout_t = 0.25
            _label.text = _readout()

func _watch_cop(c, delta: float) -> void:
    var id: int = c.get_instance_id()
    var rec: Dictionary = _cop_state.get(id, {"chase": false, "seeing": false, "inv": false, "chase_t": 0.0})
    var chase: bool = c.state == c.State.CHASE
    var inv: bool = c.state == c.State.INVESTIGATE
    if c.seeing and not rec.seeing:
        sightings += 1
        _event("seen")
    if inv and not rec.inv:
        investigations += 1
    if chase and not rec.chase:
        chases += 1
        rec.chase_t = 0.0
        _event("chase")
    if chase:
        rec.chase_t += delta
        longest_chase = maxf(longest_chase, rec.chase_t)
    if rec.chase and not chase and not finished:
        escapes += 1
        _event("escaped")
    rec.chase = chase
    rec.seeing = c.seeing
    rec.inv = inv
    _cop_state[id] = rec

func _event(kind: String) -> void:
    if events.size() >= EVENT_LIMIT:
        return
    var pos: Vector2 = main.player.global_position
    events.append({"t": snappedf(t, 0.1), "kind": kind, "x": int(pos.x), "y": int(pos.y),
            "home": snappedf(pos.distance_to(main.home_zone.get_center()) / home_start, 0.01)})

func note_damage(source: String, amount: float, left: float) -> void:
    damage[source] = snappedf(damage.get(source, 0.0) + amount, 0.1)
    life_left = left
    if amount >= 5.0:  # a hobo's grip drains a little every frame; log only real hits
        _event("hurt_" + source)

func note_stop(kind: String) -> void:
    stops[kind] = stops.get(kind, 0) + 1
    _event("stella_" + kind)

func note_phone() -> void:
    phone_calls += 1
    _event("phone")

func note_pickup(gained: float) -> void:
    pickups += 1
    life_left = main.vitals.health
    _event("pizza")

func chasers_now() -> int:
    var n := 0
    for c in main.cops:
        if c.state == c.State.CHASE:
            n += 1
    return n

# --- Endings -----------------------------------------------------------------------------
func finish(result: String, extra: Dictionary = {}) -> void:
    if finished:
        return
    outcome = result
    detail = extra
    home_best = minf(home_best, main.player.global_position.distance_to(main.home_zone.get_center()))
    detail["dragged"] = main.player.dragged_t > 0.0
    detail["stunned"] = main.player.stunned_t > 0.0
    detail["held"] = main.player.slow_t > 0.0
    detail["chasers"] = chasers_now()
    _event(result)
    finished = true
    var s: Dictionary = summary()
    session.append(s)
    if session.size() > MAX_SESSION:
        session.pop_front()
    if not DisplayServer.get_name() == "headless":
        print("RUNLOG ", JSON.stringify(s))
        if persist:
            _save(s)

func _exit_tree() -> void:
    # Restarting mid-run (R) is itself worth knowing: where did they give up?
    if not finished and t > 8.0 and main != null and is_instance_valid(main.player):
        finish("abandoned")

func summary() -> Dictionary:
    var end_pos: Vector2 = main.player.global_position if is_instance_valid(main.player) else Vector2.ZERO
    return {
        "outcome": outcome,
        "seconds": snappedf(t, 0.1),
        "walked": int(walked),
        "route": int(home_start),
        "progress": snappedf(1.0 - home_best / home_start, 0.01),
        "end_x": int(end_pos.x), "end_y": int(end_pos.y),
        "sneak_pct": int(100.0 * sneak_t / maxf(t, 0.1)),
        "lit_s": snappedf(lit_t, 0.1),
        "dragged_s": snappedf(dragged_t, 0.1),
        "held_s": snappedf(held_t, 0.1),
        "stuns": stuns,
        "damage": damage,
        "pickups": pickups,
        "phone_calls": phone_calls,
        "stella_stops": stops,
        "stella_held_s": snappedf(stella_held_s, 0.1),
        "life_left": int(life_left),
        "sightings": sightings,
        "chases": chases,
        "escapes": escapes,
        "investigations": investigations,
        "longest_chase": snappedf(longest_chase, 0.1),
        "closest_cop": int(closest_cop) if closest_cop < INF else -1,
        "detail": detail,
        "events": events,
    }

# All runs this session, plus the current one if it is still going, as JSON on the
# clipboard. Returns how many runs it holds.
func copy_to_clipboard() -> int:
    var runs: Array = session.duplicate()
    if not finished and t > 0.5:
        outcome = "in_progress"
        var snap: Dictionary = summary()
        outcome = ""
        runs.append(snap)
    DisplayServer.clipboard_set(JSON.stringify(runs))
    return runs.size()

func _save(s: Dictionary) -> void:
    var slim: Dictionary = s.duplicate()
    slim.erase("events")  # the full timeline is only printed
    slim["at"] = Time.get_datetime_string_from_system(true)
    var line := JSON.stringify(slim)
    var f := FileAccess.open("user://runs.jsonl", FileAccess.READ_WRITE if FileAccess.file_exists("user://runs.jsonl") else FileAccess.WRITE)
    if f != null:
        f.seek_end()
        f.store_line(line)
        f.close()
    if OS.has_feature("web"):
        var js := "(function(){var k='curfew_runs',a=[];try{a=JSON.parse(localStorage.getItem(k)||'[]');}catch(e){}" \
                + "a.push(%s);if(a.length>%d)a=a.slice(-%d);localStorage.setItem(k,JSON.stringify(a));})();" % [line, MAX_SAVED, MAX_SAVED]
        JavaScriptBridge.eval(js, true)

func _readout() -> String:
    var home_d: float = main.player.global_position.distance_to(main.home_zone.get_center())
    var lines: Array = [
        "RUN LOG (F3)",
        "time %5.1fs  walked %d  home %d (%d%% there)" % [t, int(walked), int(home_d), int(100.0 * (1.0 - home_d / home_start))],
        "seen %d  chases %d  escaped %d  investigated %d" % [sightings, chases, escapes, investigations],
        "chasing now %d  longest chase %.1fs  closest cop %d" % [chasers_now(), longest_chase, int(closest_cop) if closest_cop < INF else -1],
        "life %d  lost %s  pizza %d" % [int(main.vitals.health), JSON.stringify(damage), pickups],
        "sneak %d%%  lit %.1fs  dragged %.1fs  held %.1fs  stuns %d" % [int(100.0 * sneak_t / maxf(t, 0.1)), lit_t, dragged_t, held_t, stuns],
    ]
    for e in events.slice(maxi(0, events.size() - 6)):
        lines.append("  %5.1fs %s  (%d%% of the way left)" % [e.t, e.kind, int(100.0 * e.home)])
    return "\n".join(lines)
