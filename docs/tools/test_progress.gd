extends SceneTree
# Actual saved-file reload, lightweight entry choice, GUI input and same-world retry.
const Progress := preload("res://scripts/Progress.gd")
const Main := preload("res://scripts/Main.gd")
const Clues := preload("res://scripts/Clues.gd")
const Advice := preload("res://scripts/RetryAdvice.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")
var shots := OS.get_environment("PROGRESS_SHOTS")
var qa_path := "user://qa-progress-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]

func _init() -> void:
    call_deferred("run")

func settle(frames: int = 8) -> void:
    for i in frames:
        await process_frame

func snapshot(name: String) -> void:
    if shots != "" and DisplayServer.get_name() != "headless":
        RenderingServer.force_draw()  # also capture when the native window is occluded
        root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

func tap(control: Control) -> void:
    var at := control.get_global_rect().get_center()
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        event.position = at
        root.push_input(event, true)
        await process_frame
    await settle()

func key(code: Key) -> void:
    for down in [true, false]:
        var event := InputEventKey.new()
        event.keycode = code
        event.physical_keycode = code
        event.pressed = down
        root.push_input(event)
        await process_frame
    await settle()

func freeze(game) -> void:
    game.runlog.persist = false
    game.pause_menu.resume()
    game.hud.title_card.hide()
    game.set_process(false)
    game.traffic_director.enabled = false
    for actor in game.actors.get_children():
        actor.set_process(false)

func entry(screen: Vector2):
    root.size = Vector2i(screen)
    var start = load("res://scenes/Start.tscn").instantiate()
    start.screen_size_override = screen
    root.add_child(start)
    current_scene = start
    await settle()
    return start

func dispose(game) -> void:
    game.queue_free()
    await settle()

func menu_fits(start) -> bool:
    var fits: bool = root.get_visible_rect().encloses(start.box.get_global_rect())
    for button in [start.continue_button, start.new_button]:
        var rect: Rect2 = button.get_global_rect()
        fits = fits and rect.size.y / start.ui.scale.y >= 48 and root.get_visible_rect().encloses(rect)
    return fits and start.sub.get_theme_font_size("font_size") >= 16

func sized(game, screen: Vector2) -> void:
    root.size = Vector2i(screen)
    game.presentation_size_override = screen
    game.presentation.refresh()
    await settle()

func run() -> void:
    OS.set_environment("CURFEW_LEVEL", "")
    Clues.persist = false
    Progress.persist = true  # only the uniquely named QA file, never the real store
    Progress.store_path = qa_path
    var valid := Progress.parse('{"version":1,"unlocked":2}') == 2
    for raw in ["", "garbage", "[]", "null", '{"unlocked":2}', '{"version":2,"unlocked":2}', '{"version":1,"unlocked":true}', '{"version":1,"unlocked":"2"}', '{"version":1,"unlocked":0}', '{"version":1,"unlocked":-2}', '{"version":1,"unlocked":2.5}', '{"version":1,"unlocked":10001}', '{"version":1,"unlocked":1e300}']:
        valid = valid and Progress.parse(raw) == 1
    print("invalid, missing, fractional and oversized saves fall back safely  ok: ", valid)
    Progress.loaded = false
    Progress.load_once()
    print("missing storage begins at level 1  ok: ", Progress.unlocked == 1)
    print("winning saves the next unlock and lower wins cannot downgrade it  ok: ", Progress.record_win(5) and Progress.unlocked == 6 and Progress.record_win(1) and Progress.unlocked == 6)
    Progress.unlocked = 1
    Progress.loaded = false
    Progress.load_once()
    print("a fresh cache reads the persisted unlock  ok: ", Progress.unlocked == 6 and Progress.parse(Progress.serialize()) == 6)
    Progress.unlocked = 1
    Progress.save()

    # First visits build the real level directly, with no mandatory choice.
    await entry(Vector2(390, 844))
    var game = current_scene
    print("fresh entry automatically starts level 1  ok: ", game is Main and game.level == 1 and game.is_booted)
    freeze(game)
    game._win()
    await settle()
    print("clearing the real level saves level 2 before continuing  ok: ", Progress.unlocked == 2 and Progress.parse(FileAccess.get_file_as_string(qa_path)) == 2)
    await dispose(game)
    Main.level_number = 1
    Main.retry_seed = 44
    Main.retry_state = {"old": true}
    Main.retry_pos = Vector2(10, 10)
    Progress.loaded = false
    Progress.unlocked = 1
    var start = await entry(Vector2(390, 844))
    print("a fresh visit offers the saved level before creating a city  ok: ", not start.starting and Progress.unlocked == 2 and start.continue_button.text == "Continue · Level 2" and not root.get_children().any(func(n): return n is Main))
    print("portrait choice has readable text and 48-pixel targets  ok: ", menu_fits(start))
    print("menu bounds: ", start.box.get_global_rect(), " viewport: ", root.get_visible_rect(), " minimum: ", start.box.get_combined_minimum_size())
    await snapshot("continue-portrait")
    root.size = Vector2i(844, 390)
    start.screen_size_override = Vector2(844, 390)
    start._layout()
    await settle()
    print("choice rotates to landscape without clipping or overlap  ok: ", menu_fits(start) and not start.continue_button.get_global_rect().intersects(start.new_button.get_global_rect()))
    await snapshot("continue-landscape")
    root.size = Vector2i(1280, 720)
    start.screen_size_override = Vector2(1280, 720)
    start._layout()
    await settle()
    print("desktop choice remains contained with keyboard focus visible  ok: ", menu_fits(start) and start.continue_button.has_focus())
    await snapshot("continue-desktop")
    var old_start: WeakRef = weakref(start)
    await tap(start.continue_button)
    start = null
    game = current_scene
    freeze(game)
    print("Continue tap enters level 2 without latched movement or stale retry state  ok: ", game is Main and game.level == 2 and game.home_seed != 44 and Main.retry_seed == -1 and Main.retry_state.is_empty() and Main.retry_pos == Vector2.INF and not game.player.pointer_down and not game.player.has_dest)
    print("entry screen is released and retries target the selected game scene  ok: ", old_start.get_ref() == null and game.scene_file_path == "res://scenes/Main.tscn")
    game._win()
    print("the next real clear advances the saved unlock again  ok: ", Progress.unlocked == 3 and Progress.parse(FileAccess.get_file_as_string(qa_path)) == 3)
    await dispose(game)

    Clues.seen["scent"] = true
    start = await entry(Vector2(390, 844))
    await key(KEY_TAB)
    print("keyboard focus can reach New Run  ok: ", start.new_button.has_focus())
    await key(KEY_ENTER)
    game = current_scene
    freeze(game)
    print("New Run starts level 1 while retaining unlocks and rule memory  ok: ", game.level == 1 and Progress.unlocked == 3 and Progress.parse(FileAccess.get_file_as_string(qa_path)) == 3 and Clues.seen.has("scent"))

    game.player.global_position = Helpers.free_spot(game, game.START + Vector2(180, -120), 20)
    game.dog.global_position = game.player.global_position + Vector2(-20, 8)
    game.focus = game.player.global_position
    game._update_view(0.0)
    game.minimap._process(0.1)
    var house: Rect2 = game.home_zone
    var pos: Vector2 = game.player.global_position
    var cells: int = game.minimap.seen_cells.size()
    game.caught(game.cops[0])
    game.hud.update(0.0, 0.0)
    await settle(70)
    print("capture explains the cause at full life and preserves unlocks  ok: ", game.state == "caught" and game.vitals.health == 100 and "A cop caught you" in game.hud.banner_sub.text and "sneaking is too slow" in game.hud.banner_sub.text and Progress.unlocked == 3)
    await snapshot("capture-portrait")
    await sized(game, Vector2(844, 390))
    print("causal retry card fits compact landscape  ok: ", root.get_visible_rect().encloses(game.hud.banner_box.get_global_rect()) and game.hud.banner_sub.get_theme_font_size("font_size") == 16)
    await snapshot("capture-landscape")
    game.ended_at = Time.get_ticks_msec() - 1000
    await tap(game.hud.banner_sub)
    game = current_scene
    freeze(game)
    print("actual retry skips the chooser and preserves house, map and location  ok: ", game is Main and game.home_zone == house and game.minimap.seen_cells.size() >= cells and game.player.global_position.distance_to(pos) < 60 and game.state == "play" and Progress.unlocked == 3)
    game.vitals.health = 40
    game.hurt(50, "car", {"stella": true})
    game.hud.update(0.0, 0.0)
    await settle(70)
    print("fatal traffic hit names Stella, depleted life and a crossing response  ok: ", game.hud.banner_title.text == "RUN OVER" and "hit Stella" in game.hud.banner_sub.text and "wait for a gap" in game.hud.banner_sub.text and game.runlog.summary().outcome == "run_over")
    await snapshot("traffic-retry")
    var npc_ok := true
    for pair in [["skater", "skateboarder"], ["punk", "punk"], ["hobo", "hobo"], ["zombie", "zombie"]]:
        game.state = "play"
        game.vitals.health = 1
        game.vitals.grace_t = 0
        game.hurt(20, pair[0])
        npc_ok = npc_ok and game.hud.banner_title.text == "KNOCKED OUT" and pair[1] in game.hud.banner_sub.text and "pizza" in game.hud.banner_sub.text
    print("street-person and skateboarder life loss use causal recovery hints  ok: ", npc_ok and "life ran out" in Advice.for_failure("KNOCKED OUT", "unknown"))

    game.go_to_level(3)
    await settle()
    game = current_scene
    freeze(game)
    game._win()
    print("debug level selection and clearing cannot inflate saved unlocks  ok: ", game.level == 3 and not Main.checkpoint_enabled and Progress.unlocked == 3 and Progress.parse(FileAccess.get_file_as_string(qa_path)) == 3)
    await dispose(game)
    start = await entry(Vector2(844, 390))
    await tap(start.new_button)
    game = current_scene
    freeze(game)
    print("a normal New Run restores checkpoint eligibility after debugging  ok: ", game.level == 1 and Main.checkpoint_enabled)

    Progress.store_path = "user://missing-qa-%d/progress.json" % Time.get_ticks_usec()
    Progress.unlocked = 1
    game.state = "play"
    game._win()
    await settle(70)
    game.hud.update(0.0, 0.0)
    print("failed storage keeps the session unlock and explains the limitation  ok: ", Progress.unlocked == 2 and not Progress.last_save_ok and "session only" in game.hud.banner_sub.text and game.state == "won")
    print("storage-failure preview stays readable in landscape  ok: ", root.get_visible_rect().encloses(game.hud.banner_box.get_global_rect()))
    await snapshot("session-only-save")
    await dispose(game)
    Progress.loaded = false
    Progress.unlocked = 2
    Progress.load_once()
    print("a later visit with unavailable storage safely falls back to level 1  ok: ", Progress.unlocked == 1)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_path))
    Progress.persist = false
    quit()
