extends SceneTree
# Read-only game fixtures for the engagement audit. Does not change production rules.
# godot --headless --fixed-fps 60 --path . --script docs/tools/audit_playability.gd -- out=/tmp/playability-probes.json
const Settings := preload("res://scripts/LevelSettings.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")
const Clues := preload("res://scripts/Clues.gd")
var report := {"warning": [], "idle_guidance": [], "controls": {}, "clue_collision": {}}
var out_path := "docs/audits/2026-10-04/playability/probes.json"

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("out="):
            out_path = arg.trim_prefix("out=")
    call_deferred("run")

func make_game(level: int, home_seed: int):
    var game = load("res://scenes/Main.tscn").instantiate()
    game.level_override = level
    game.home_seed = home_seed
    game.audit_seed = 1000 * home_seed + 1
    game.traffic_enabled = false
    root.add_child(game)
    game.runlog.persist = false
    return game

func buttons(node: Node) -> Array:
    var found := []
    if node is BaseButton:
        found.append(str(node.text))
    for child in node.get_children():
        found.append_array(buttons(child))
    return found

func measure_warning(game, cop, lv: int, distance: float, sneak: bool, lit: bool) -> Dictionary:
    game.settings = Settings.for_level(lv)
    var road: Vector2 = Helpers.road_east()
    cop.global_position = road
    game.player.global_position = road + Vector2(distance, 0)
    game.dog.global_position = road + Vector2(2000, 0)
    game.player.sneaking = sneak
    game.player.moving = true
    game.player.lit = lit
    game.player.dragged_t = 0.0
    game.player.torch_on = false
    cop.state = cop.State.PATROL
    cop.exposure = 0.0
    cop.angle = 0.0
    cop.seeing = false
    cop.was_seeing = false
    cop.alert_t = 0.0
    cop.winded_t = 0.0
    cop.eat_t = 0.0
    var warning := -1.0
    var seconds := -1.0
    for frame in 1200:
        cop._update_detection(1.0 / 60.0)
        if warning < 0.0 and cop.alert_mark() == "?":
            warning = float(frame + 1) / 60.0
        if cop.state == cop.State.CHASE:
            seconds = float(frame + 1) / 60.0
            break
    return {"level": lv, "distance": distance, "sneak": sneak, "lit": lit,
        "seconds_to_chase": seconds, "first_warning_seconds": warning, "mark_before_chase": "?" if warning >= 0.0 else "none while continuously visible",
        "chase_speed": game.settings.get("cop_chase_speed", cop.CHASE_SPEED)}

func run() -> void:
    var game = make_game(1, 0)
    for i in 3:
        await process_frame
    game.set_process(false)
    game.player.set_process(false)
    game.dog.set_process(false)
    for cop in game.cops:
        cop.set_process(false)
    for lv in [1, 2, 3]:
        for distance in [60.0, 100.0]:
            for sneak in [false, true]:
                report.warning.append(measure_warning(game, game.cops[0], lv, distance, sneak, true))

    # Pause input is the actual handler, including the one that runs while paused.
    game.settings = Settings.for_level(1)
    game.pause_menu.pause()
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    game.pause_menu._unhandled_input(mouse)
    var mouse_keeps_paused: bool = paused
    var touch := InputEventScreenTouch.new()
    touch.pressed = true
    game.pause_menu._unhandled_input(touch)
    var touch_keeps_paused: bool = paused
    var key := InputEventKey.new()
    key.keycode = KEY_P
    key.pressed = true
    game.pause_menu._unhandled_input(key)
    report.controls = {"mouse_keeps_paused": mouse_keeps_paused,
        "touch_keeps_paused": touch_keeps_paused, "P_resumes": not paused,
        "pause_buttons": buttons(game.pause_menu), "game_buttons": buttons(game),
        "portrait_scale_390_wide": 390.0 / 1280.0,
        "portrait_item_slot_css_px": 64.0 * 390.0 / 1280.0}

    # Two events occurring together: an urgent item clue replaces a scent explanation.
    Clues.seen.clear()
    game.hud.title_card.modulate.a = 0.0
    game.clues.last_at = -100.0
    game.state = "play"
    var scent_shown: bool = game.clues.offer("scent")
    var item_shown: bool = game.clues.offer("item_treat", true)
    report.clue_collision = {"scent_shown": scent_shown, "item_replaced_scent": item_shown,
        "current": game.clues.current_id, "scent_marked_seen": Clues.seen.has("scent"),
        "scent_can_be_offered_again": game.clues.offer("scent", true)}
    game.queue_free()
    for i in 3:
        await process_frame

    # Natural idle behavior, including Stella's ordinary distractions. Not a novice model.
    for lv in [1, 2, 3]:
        for home_seed in 3:
            game = make_game(lv, home_seed)
            Clues.seen.clear()
            for i in 3:
                await process_frame
            var initial: Vector2 = game.player.global_position
            var scheduled: float = game.dog.scent_cd
            var first := -1.0
            for frame in 60 * 90:
                await physics_frame
                if game.dog.scent_t > 0.0:
                    first = float(frame + 1) / 60.0
                    break
                if game.state != "play":
                    break
            report.idle_guidance.append({"level": lv, "home_seed": home_seed,
                "scheduled_scent_seconds": scheduled, "observed_first_scent_seconds": first,
                "state": game.state, "displacement_before_hint": initial.distance_to(game.player.global_position),
                "stop": game.dog.planted, "stella_stops": game.runlog.summary().stella_stops})
            print("idle probe level ", lv, " home ", home_seed, " first scent ", first)
            game.queue_free()
            for i in 3:
                await process_frame
    var file := FileAccess.open(out_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  ") + "\n")
    file.close()
    print("Saved playability probes to ", out_path)
    quit()
