extends SceneTree
# The one-time hints (Clues.gd): the catalogue is complete, a clue shows once and not too close to
# another, an urgent one skips the wait, levels 4 and up have none, and each thing that should explain
# itself does: a bin crash (naming the cop it drew), Stella's nose, a cop's "?" and "!", being dragged
# after something, and a zombie getting up. Typing CLUES forgets what has been shown.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_clues.gd
const CluesScript := preload("res://scripts/Clues.gd")
const HudScript := preload("res://scripts/Hud.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _fresh(level: int) -> Node:
    CluesScript.seen.clear()
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = level
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    for c in main.cats:
        c.set_process(false)
    main.player.set_process(false)
    main.dog.set_process(false)
    main.state = "play"
    for i in 270:  # the level's title card is up for about four seconds, and nothing shows over it
        await process_frame
    return main

# Ready for the next thing: nothing shown yet, and no wait.
func _clear(main) -> void:
    CluesScript.seen.clear()
    main.clues.last_at = -1000.0
    main.clues.current_id = ""
    main.hud.clue_up = false

func _key(main, letter: String) -> void:
    var e := InputEventKey.new()
    e.keycode = letter.unicode_at(0)  # KEY_A..KEY_Z are the capital letters' codes
    e.pressed = true
    main._cheat_input(e)

func _init() -> void:
    CluesScript.persist = false  # (the default when headless, said again)
    var main = await _fresh(1)

    # 1. The catalogue: every clue has a picture the card knows, and words short enough for two lines.
    var bad := 0
    var longest := 0
    for id in CluesScript.CATALOG:
        var clue: Dictionary = CluesScript.CATALOG[id]
        longest = maxi(longest, clue.text.length())
        if not HudScript.CLUE_TONES.has(clue.icon) or clue.text.length() > 130 or clue.text.length() < 20:
            bad += 1
    var round_trip: bool = CluesScript.parse(CluesScript.serialize()).hash() == CluesScript.seen.hash() \
            and CluesScript.parse('["bin","scent"]').has("scent") and CluesScript.parse("garbage").is_empty()
    var levels_ok: bool = true
    var level_flags := []
    for n in [1, 2, 3, 4, 7]:
        var flag: bool = load("res://scripts/LevelSettings.gd").for_level(n).clues
        level_flags.append(flag)
        if flag != (n <= 3):
            levels_ok = false
    print("1. ", CluesScript.CATALOG.size(), " clues, longest ", longest, " characters, ", bad, " badly formed; stored list reads back: ", round_trip,
        "; clues on for levels 1,2,3,4,7: ", level_flags, "  ok: ", bad == 0 and round_trip and levels_ok and CluesScript.reading_time("x") >= 4.0 and CluesScript.reading_time("x".repeat(500)) <= 7.0)

    # 2. The rules: shown once, not on top of another, an urgent one gets through, and it is on the card.
    _clear(main)
    var first: bool = main.clues.offer("scent")
    var on_card: bool = main.hud.clue_up and main.hud.clue_label.text == CluesScript.CATALOG["scent"].text and main.hud.clue_icon.kind == "house"
    var again: bool = main.clues.offer("scent")
    var too_soon: bool = main.clues.offer("drag")
    var urgent: bool = main.clues.offer("cop_chase", true)
    print("2. shown ", first, " (on the card: ", on_card, "), the same again ", again, ", another too soon ", too_soon, ", an urgent one ", urgent,
        "  ok: ", first and on_card and not again and not too_soon and urgent and main.clues.current_id == "cop_chase")

    # 3. A bin crash near her: the first time it is explained, naming the cop it drew; with no cop to hear it, the quieter version.
    _clear(main)
    var bin = main.props[0]
    bin.knocked = false
    main.player.global_position = bin.global_position + Vector2(60, 0)
    for c in main.cops:
        c.global_position = bin.global_position + Vector2(-9000, 0)
    var cop = main.cops[0]
    cop.global_position = bin.global_position + Vector2(0, -150)
    cop.state = cop.State.PATROL
    cop.exposure = 0.0
    bin.knock()
    var heard: bool = main.clues.current_id == "bin" and "drew a cop" in main.hud.clue_label.text and cop.state == cop.State.INVESTIGATE
    _clear(main)
    bin.knocked = false
    cop.global_position = bin.global_position + Vector2(-9000, 0)
    cop.state = cop.State.PATROL
    bin.knock()
    var quiet: bool = main.clues.current_id == "bin_quiet" and not ("drew a cop" in main.hud.clue_label.text)
    _clear(main)
    bin.knocked = false
    main.player.global_position = bin.global_position + Vector2(2000, 0)  # too far to be seen: nothing to explain
    bin.knock()
    var far: bool = main.clues.current_id == ""
    print("3. a bin crash: with a cop to hear it \"", "bin" if heard else "?", "\" and he turned: ", heard, "; with none ", quiet, "; far from her it says nothing: ", far,
        "  ok: ", heard and quiet and far)
    bin.knocked = false

    # 4. Stella catches the scent: the card, and the bubble (it shows while she leads, the clue only the first time).
    _clear(main)
    main.dog.scent_t = 0.0
    main.dog._start_scent()
    var scent_card: bool = main.clues.current_id == "scent" and main.dog.scent_t > 0.0 and main.dog.scent_len == main.dog.SCENT_TIME_FIRST
    _clear(main)
    main.dog.scent_t = 0.0
    CluesScript.seen["scent"] = true
    main.dog._start_scent()
    var bubble_only: bool = main.clues.current_id == "" and main.dog.scent_t > 0.0 and main.dog.scent_len == main.dog.SCENT_TIME
    main.dog.scent_t = 0.0
    print("4. the scent: card the first time ", scent_card, "; later the bubble still shows (scent_t > 0) with no card: ", bubble_only, "  ok: ", scent_card and bubble_only)

    # 5. A cop's marks: his first "?" is explained, and his first "!" (urgent) gets through at once.
    _clear(main)
    cop = main.cops[0]
    cop.set_process(true)
    cop.global_position = main.player.global_position + Vector2(160, 0)
    cop.wait = 100.0
    cop.state = cop.State.INVESTIGATE
    cop.target = cop.global_position + Vector2(0, 250)  # somewhere to walk, so he stays on his way to look
    main.gate.update()  # he was sent far away earlier, so the activity gate switched him off: bring him back
    await process_frame
    await process_frame
    var look_card: bool = main.clues.current_id == "cop_look" and cop.mark == "?"
    cop.state = cop.State.CHASE
    await process_frame
    await process_frame
    var chase_card: bool = main.clues.current_id == "cop_chase" and cop.mark == "!"
    cop.set_process(false)
    cop.state = cop.State.PATROL
    print("5. his first ? is explained: ", look_card, ", and his first ! straight away: ", chase_card, "  ok: ", look_card and chase_card)

    # 6. Stella hauls her after a cat: explained the first time the leash goes taut.
    _clear(main)
    main.dog.set_process(true)
    var run: Vector2 = Helpers.open_run(main)
    var cat = main.cats[0]
    for other in main.cats:
        other.global_position = Vector2(1200, 700)
        other.state = other.State.IDLE
        other.timer = 999.0
    cat.cooldown = 0.0
    cat.global_position = run + Vector2(115, 0)
    main.player.global_position = run
    main.dog.global_position = run + Vector2(30, 5)
    main.dog.pee_cd = 999.0
    main.dog.bark_cd = 0.0
    var dragged := false
    for i in 200:
        await physics_frame
        if main.clues.current_id == "drag":
            dragged = true
            break
    main.dog.set_process(false)
    print("6. dragged after a cat: ", dragged, "  ok: ", dragged)

    # 7. Typing CLUES forgets what has been shown.
    CluesScript.seen["bin"] = true
    CluesScript.seen["scent"] = true
    for letter in ["C", "L", "U", "E", "S"]:
        _key(main, letter)
    print("7. typing CLUES forgets them: ", CluesScript.seen.size(), " left  ok: ", CluesScript.seen.is_empty())
    main.queue_free()
    await process_frame

    # 8. A zombie getting up near her (level 2): explained.
    main = await _fresh(2)
    var zombie = null
    for n in main.npcs:
        if n.kind == n.Kind.ZOMBIE:
            zombie = n
            break
    _clear(main)
    main.player.global_position = zombie.global_position + Vector2(200, 0)
    zombie._wake()
    var zombie_card: bool = main.clues.current_id == "zombie"
    _clear(main)
    main.player.global_position = zombie.global_position + Vector2(3000, 0)
    zombie._wake()
    var zombie_far: bool = main.clues.current_id == ""
    print("8. a zombie wakes near her: ", zombie_card, "; far away: ", zombie_far, "  ok: ", zombie_card and zombie_far)
    main.queue_free()
    await process_frame

    # 9. Level 4 and up: no clues at all, even for something that would have one.
    main = await _fresh(4)
    _clear(main)
    var any: bool = false
    for id in CluesScript.CATALOG:
        any = any or main.clues.offer(id, true)
    print("9. level 4 offers: ", any, ", the card is up: ", main.hud.clue_up, "  ok: ", not any and not main.hud.clue_up and not main.settings.clues)
    quit()
