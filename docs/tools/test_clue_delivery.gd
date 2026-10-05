extends SceneTree
# Real encounter collisions and GUI replay, with normal Main updates/tweens.
# Paused/end-screen frames must not turn unread teaching into persisted completion.
const Clues := preload("res://scripts/Clues.gd")
const Items := preload("res://scripts/Items.gd")
var shots := OS.get_environment("CLUE_SHOTS")

func _init() -> void:
    call_deferred("run")

func frames(count: int) -> void:
    for i in count:
        await process_frame

func seconds(time: float) -> void:
    await frames(ceili(time * 60.0) + 2)

func fresh() -> Node:
    root.size = Vector2i(390, 844)
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 3
    main.home_seed = 1
    main.traffic_enabled = false
    main.presentation_size_override = Vector2(390, 844)
    root.add_child(main)
    main.runlog.persist = false
    await frames(5)
    main.pause_menu.resume()
    main.player.set_process(false)
    main.dog.set_process(false)
    for list in [main.cops, main.cats, main.squirrels, main.npcs, main.phones, main.item_pickups]:
        for actor in list:
            actor.set_process(false)
    await frames(280)
    main.clues.cancel()
    main.clues.last_at = -1000
    return main

func tap(control: Control) -> void:
    var at: Vector2 = control.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    root.push_input(motion, true)
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = down
        event.position = at
        root.push_input(event, true)
        await process_frame
    await frames(5)

func snapshot(name: String) -> void:
    if shots == "" or DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

func until(main, id: String, max_frames: int = 650) -> bool:
    for i in max_frames:
        if main.clues.current_id == id:
            return true
        await process_frame
    return false

func guide_fits(main) -> bool:
    var pm = main.pause_menu
    var unit: float = main.presentation.unit
    var good: bool = root.get_visible_rect().encloses(pm.box.get_global_rect()) and pm.box.scale.y / unit >= 0.99 and pm.guide_text.get_theme_font_size("font_size") == 16
    for button in [pm.guide_prev, pm.guide_next, pm.back_button]:
        good = good and button.get_global_rect().size.y / unit >= 44 and root.get_visible_rect().encloses(button.get_global_rect())
    return good

func run() -> void:
    Clues.persist = false
    Clues.seen.clear()
    var main = await fresh()
    var first: bool = main.clues.offer("scent")
    var pickup = preload("res://scripts/ItemPickup.gd").new()
    pickup.main = main
    pickup.kind = "treat"
    main.actors.add_child(pickup)
    main.item_pickups.append(pickup)
    main.collect_item(pickup)
    print("scent then real item pickup queues teaching without replacing it  ok: ", first and main.carried == "treat" and main.clues.current_id == "scent" and main.clues.pending == ["item_treat"] and Clues.seen.is_empty())
    var duplicates_rejected := true
    for i in 100:
        duplicates_rejected = duplicates_rejected and not main.clues.offer("item_treat") and not main.clues.offer("scent")
    print("repeat encounter offers are deduplicated while current or queued  ok: ", duplicates_rejected and main.clues.pending.size() == 1)
    await seconds(1.0)
    main.clues.offer("cop_chase", true)
    await frames(20)
    print("urgent cop warning appears promptly, retaining interrupted scent first  ok: ", main.clues.current_id == "cop_chase" and main.clues.pending == ["scent", "item_treat"] and main.hud.clue_layer.modulate.a > 0.98 and Clues.seen.is_empty())
    await snapshot("urgent-warning")
    await tap(main.hud.pause_button)
    var left: float = main.clues.reading_left
    var clock: float = main.clues.elapsed
    await seconds(8.0)
    print("pause cannot consume a warning or persist it as read  ok: ", paused and main.clues.current_id == "cop_chase" and is_equal_approx(main.clues.reading_left, left) and is_equal_approx(main.clues.elapsed, clock) and Clues.seen.is_empty())
    await tap(main.pause_menu.guide_button)
    var pm = main.pause_menu
    print("field guide opens the carried item and does not alter clue completion  ok: ", paused and pm.guide_open and pm.guide_ids[pm.guide_index] == "item_treat" and "Tap the item" in pm.guide_text.text and Clues.seen.is_empty() and main.clues.current_id == "cop_chase")
    await snapshot("portrait-item-guide")
    var index: int = pm.guide_index
    await tap(pm.guide_next)
    var advanced: bool = pm.guide_index == posmod(index + 1, pm.guide_ids.size())
    await tap(pm.guide_prev)
    print("field guide previous/next work through real GUI taps without steering  ok: ", advanced and pm.guide_index == index and not main.player.has_dest and not main.player.pointer_down)
    var all_fit := true
    for i in pm.guide_ids.size():
        pm._browse_guide(1)
        await frames(5)
        all_fit = all_fit and guide_fits(main)
    print("every rule and unlocked item fits readable portrait guide  ok: ", all_fit and pm.guide_ids.size() == Clues.guide_ids(3).size())
    pm.guide_index = pm.guide_ids.find("scent")
    pm._browse_guide(0)
    await frames(5)
    await snapshot("portrait-rule-guide")
    root.size = Vector2i(844, 390)
    main.presentation_size_override = Vector2(844, 390)
    main.presentation.refresh()
    await frames(5)
    all_fit = true
    for i in pm.guide_ids.size():
        pm._browse_guide(1)
        await frames(5)
        all_fit = all_fit and guide_fits(main)
    print("rotation while browsing keeps all guide text and targets readable  ok: ", all_fit and paused and main.hud.ui.size.is_equal_approx(Vector2(844, 390)))
    pm.guide_index = pm.guide_ids.find("item_extinguisher")
    pm._browse_guide(0)
    await frames(5)
    await snapshot("landscape-item-guide")
    await tap(pm.back_button)
    print("four-action landscape pause menu fits without shrinking targets  ok: ", not pm.guide_open and root.get_visible_rect().encloses(pm.box.get_global_rect()) and pm.box.scale.y / main.presentation.unit >= 0.99 and pm.guide_button.get_global_rect().size.y / main.presentation.unit >= 48)
    await snapshot("landscape-pause")
    await tap(pm.resume_button)
    var restored: bool = await until(main, "scent")
    print("interrupted explanation returns with its full reading interval  ok: ", restored and Clues.seen.has("cop_chase") and not Clues.seen.has("scent") and not Clues.seen.has("item_treat") and main.clues.reading_left >= Clues.reading_time(Clues.CATALOG.scent.text) - 0.05)
    await seconds(0.4)
    await snapshot("restored-scent")
    await seconds(2.0)
    print("partial restored reading is not recorded as seen  ok: ", not Clues.seen.has("scent") and main.clues.current_id == "scent")
    var item_shown: bool = await until(main, "item_treat")
    print("queued item follows a completed restored explanation  ok: ", item_shown and Clues.seen.has("scent") and not Clues.seen.has("item_treat") and main.clues.pending.is_empty())
    main._lose("CAUGHT")
    await seconds(9.0)
    var stored: String = Clues.serialize()
    print("death and end-screen time cannot persist an unread item clue  ok: ", main.state == "caught" and Clues.parse(stored).has("scent") and Clues.parse(stored).has("cop_chase") and not Clues.parse(stored).has("item_treat"))
    main.queue_free()
    main = null
    await frames(5)
    Clues.seen = Clues.parse(stored)
    main = await fresh()
    print("fresh scene using the stored seen list accepts the unread explanation  ok: ", main.clues.offer("item_treat") and main.clues.current_id == "item_treat")
    await seconds(Clues.reading_time(Items.INFO.treat.text) + 1.0)
    print("full uninterrupted visible dwell persists once and rejects repeats  ok: ", Clues.parse(Clues.serialize()).has("item_treat") and not main.clues.offer("item_treat"))
    main.clues.cancel()
    Clues.seen.clear()
    main.clues.elapsed = 0
    main.clues.last_at = -Clues.COOLDOWN + Clues.GRACE
    main.hud.title_card.modulate.a = 1.0
    main.clues.offer("item_donut")
    await seconds(4.0)
    var waiting: bool = main.clues.current_id == "" and main.clues.pending == ["item_donut"] and Clues.seen.is_empty()
    main.hud.title_card.modulate.a = 0.0
    await frames(5)
    print("one-shot teaching during title/grace is retained and starts afterward  ok: ", waiting and main.clues.current_id == "item_donut")
    main.clues.cancel()
    Clues.seen.clear()
    var ids: Array[String] = Clues.guide_ids(3)
    for i in 100:
        for id in ids:
            main.clues.offer(id)
    print("queue remains bounded to distinct catalogue entries under repeated offers  ok: ", main.clues.pending.size() + (1 if main.clues.current_id != "" else 0) == ids.size() and not main.clues.offer("unknown") and Clues.guide_ids(1).size() == Clues.CATALOG.size() + 2 and Clues.guide_ids(2).size() == Clues.CATALOG.size() + 2 and Clues.guide_ids(3).size() == Clues.CATALOG.size() + 4)
    # Cancel kills the old completion callback: the CLUES cheat must stay reset.
    main.clues.cancel()
    Clues.reset()
    await seconds(8.0)
    print("cancelled clue cannot mark itself seen after a reset  ok: ", Clues.seen.is_empty() and main.clues.pending.is_empty() and main.clues.current_id == "")
    main.queue_free()
    main = null
    await frames(5)
    quit()
