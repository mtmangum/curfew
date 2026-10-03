extends SceneTree
# Levels: level 1 is a gentle walk home (fewer cops, a few cars and skateboarders, no street
# people, a nearer house); level 2 is the full city with more of everything. Winning moves on
# to the next level; losing keeps the level.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_levels.gd
const MainScript := preload("res://scripts/Main.gd")
const Helpers := preload("res://docs/tools/world_helpers.gd")

func _build(level: int):
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = level
    main.home_seed = 4
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    return main

# Type some keys (letters and digits) at the game.
func _type(text: String) -> void:
    for ch in text:
        var ev := InputEventKey.new()
        ev.pressed = true
        ev.keycode = ch.unicode_at(0) as Key
        ev.physical_keycode = ev.keycode
        root.push_input(ev)

func _count(main) -> Dictionary:
    var c := {"hobos": 0, "punks": 0, "zombies": 0}
    for n in main.npcs:
        if n.kind == n.Kind.HOBO:
            c.hobos += 1
        elif n.kind == n.Kind.PUNK:
            c.punks += 1
        else:
            c.zombies += 1
    c["cops"] = main.cops.size()
    c["home"] = int(main.home_zone.get_center().distance_to(main.START))
    return c

func _init() -> void:
    MainScript.level_number = 1
    var one = await _build(1)
    var c1: Dictionary = _count(one)
    var settings1: Dictionary = one.settings
    one.queue_free()
    await process_frame
    var two = await _build(2)
    var c2: Dictionary = _count(two)
    var settings2: Dictionary = two.settings
    print("1. level 1: ", c1, "  level 2: ", c2)
    print("   level 1 has no hobos, punks or zombies: ", c1.hobos == 0 and c1.punks == 0 and c1.zombies == 0,
        "  ok: ", c1.hobos == 0 and c1.punks == 0 and c1.zombies == 0)
    print("   level 2 has them all: ", c2.hobos > 0 and c2.punks > 10 and c2.zombies > 10, "  ok: ", c2.hobos > 0 and c2.punks > 10 and c2.zombies > 10)
    print("   fewer cops on level 1 (", c1.cops, " vs ", c2.cops, "), still a few: ", c1.cops >= 8 and c1.cops < c2.cops * 0.6, "  ok: ", c1.cops >= 8 and c1.cops < c2.cops * 0.6)
    print("   the house is within level 1's band (", c1.home, ", ", int(settings1.home_min), " to ", int(settings1.home_max), ") and at least level 2's minimum on level 2 (", c2.home, " >= ", int(settings2.home_min), ")",
        "  ok: ", c1.home >= settings1.home_min and c1.home <= settings1.home_max and c2.home >= settings2.home_min and settings1.home_min < settings2.home_min)
    print("   traffic: cars ", settings1.cars, " vs ", settings2.cars, ", skateboarders ", settings1.skaters, " vs ", settings2.skaters,
        "  ok: ", settings1.cars < settings2.cars and settings1.skaters > 0 and settings2.skaters >= settings1.skaters)

    # 2. Dawdling brings zombies on level 2 but not on level 1.
    var drifters2 := 0
    two.traffic_director.enabled = true
    two.play_time = 100.0
    two.player.global_position = Helpers.free_spot(two, two.START + Vector2(1500, -600))
    two.dog.global_position = two.player.global_position
    two.dog.set_process(false)
    for i in 60 * 14:
        await physics_frame
    for n in two.npcs:
        if n.drifter:
            drifters2 += 1
    two.queue_free()
    await process_frame
    var one_b = await _build(1)
    one_b.traffic_director.enabled = true
    one_b.play_time = 100.0
    one_b.player.global_position = Helpers.free_spot(one_b, one_b.START + Vector2(1500, -600))
    one_b.dog.global_position = one_b.player.global_position
    one_b.dog.set_process(false)
    for i in 60 * 14:
        await physics_frame
    var drifters1 := 0
    for n in one_b.npcs:
        if n.drifter:
            drifters1 += 1
    print("2. standing about for 14 s: zombies turn up on level 2 (", drifters2, ") but not on level 1 (", drifters1, ")  ok: ", drifters2 >= 1 and drifters1 == 0)
    one_b.queue_free()
    await process_frame

    # 3. Losing keeps the level; winning moves on to the next.
    MainScript.level_number = 1
    var a = await _build(1)
    a.caught(a.cops[0])
    print("3. after losing level 1 the next try is still level ", MainScript.level_number, "  ok: ", MainScript.level_number == 1)
    a.queue_free()
    await process_frame
    var b = await _build(1)
    for c in b.cops:
        c.set_process(false)
    b.player.global_position = b.home_zone.get_center()
    for i in 5:
        await physics_frame
    print("   after winning it is level ", MainScript.level_number, ", banner: ", b.banner_title.text, "  ok: ", MainScript.level_number == 2 and b.banner_title.text == "LEVEL 1 CLEAR")
    b.queue_free()
    await process_frame

    # 4. The hidden way in: type LEVEL and then a digit and that level starts. A digit alone, or a
    #    spoiled word, does nothing.
    MainScript.level_number = 1
    var d = await _build(1)
    current_scene = d
    _type("5")
    _type("LEVELX3")
    var held: bool = MainScript.level_number == 1
    _type("LEVEL3")
    var went_to: int = MainScript.level_number
    for i in 8:
        await process_frame
    var fresh = current_scene
    print("4. a digit alone or a spoiled word do nothing (", held, "); typing LEVEL3 goes to level ", went_to, ", a fresh game (", fresh != d, ") showing level ", fresh.level,
        "  ok: ", held and went_to == 3 and fresh != d and fresh.level == 3 and fresh.settings.cops > 0.9)
    fresh.queue_free()
    MainScript.level_number = 1
    MainScript.retry_seed = -1
    MainScript.retry_state = {}
    MainScript.retry_pos = Vector2.INF
    quit()
