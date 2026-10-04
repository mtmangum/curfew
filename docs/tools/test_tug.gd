extends SceneTree
# The leash tug: a hard lunge (at a cat, a squirrel, a hydrant) plays `tug` (a thump and a jingle of
# clasp and collar ring), the gentle pull toward home plays `tug_soft` (a twang), and neither is the old
# noisy crunch (both are short, and the files exist and differ).
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_tug.gd
const Helpers := preload("res://docs/tools/world_helpers.gd")

# Which of the two tug sounds is playing, and at what volume, across `frames` frames.
func _watch(main, frames: int) -> Dictionary:
    var seen := {}
    for i in frames:
        await physics_frame
        for c in main.audio.get_children():
            if c is AudioStreamPlayer and c.bus == "SFX":
                if c.stream == main.audio.sounds["tug"]:
                    seen["tug"] = c.volume_db
                elif c.stream == main.audio.sounds["tug_soft"]:
                    seen["tug_soft"] = c.volume_db
    return seen

# The start of a stretch of open ground 130 units long running along +x, near the start.
func _clear_run(main) -> Vector2:
    var base: Vector2 = Helpers.free_spot(main, main.START + Vector2(260, -160))
    for dy in range(0, 400, 20):
        for dx in range(0, 400, 40):
            var p: Vector2 = base + Vector2(dx, -dy)
            var open := true
            for k in range(0, 135, 8):
                if main.blocked_circle(p + Vector2(k, 0), 6.0):
                    open = false
                    break
            if open:
                return p
    return base

func _fresh() -> Node:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    main.player.set_process(false)  # no input; only Stella moves her
    main.state = "play"
    return main

func _init() -> void:
    # 1. Both sounds exist, are different, and are short.
    var main = await _fresh()
    var hard = main.audio.sounds["tug"]
    var soft = main.audio.sounds["tug_soft"]
    print("1. tug ", snappedf(hard.get_length(), 0.01), " s, tug_soft ", snappedf(soft.get_length(), 0.01), " s, different: ", hard != soft,
        "  ok: ", hard != soft and hard.get_length() > 0.25 and hard.get_length() < 0.5 and soft.get_length() > 0.25 and soft.get_length() < 0.5)

    # 2. Stella lunges at a cat: the leash goes taut with the jingle (and not the twang).
    for other in main.cats:
        other.global_position = Vector2(1200, 700)
        other.state = other.State.IDLE
        other.timer = 999.0
    var cat = main.cats[0]
    cat.state = cat.State.IDLE
    cat.timer = 999.0
    cat.cooldown = 0.0
    var run: Vector2 = _clear_run(main)
    cat.global_position = run + Vector2(115, 0)
    main.player.global_position = run
    main.dog.global_position = run + Vector2(30, 5)
    main.dog.pee_cd = 999.0
    main.dog.bark_cd = 0.0
    var seen: Dictionary = await _watch(main, 200)
    print("2. a lunge at a cat plays: ", seen.keys(), " at ", seen.get("tug", "-"), " dB  ok: ", seen.has("tug") and not seen.has("tug_soft") and absf(float(seen.get("tug", 0.0)) + 4.0) < 0.1)
    main.queue_free()
    await process_frame

    # 3. Stella leads the way home: the gentler pull plays the twang (and not the jingle).
    main = await _fresh()
    for other in main.cats:
        other.global_position = Vector2(1200, 700)
        other.state = other.State.IDLE
        other.timer = 999.0
    var from: Vector2 = Helpers.free_spot(main, main.START + Vector2(260, -160))
    main.player.global_position = from
    main.dog.global_position = from + Vector2(-24, 6)
    main.dog.pee_cd = 999.0
    main.dog.scent_cd = 0.0
    seen = await _watch(main, 220)
    print("3. the pull toward home plays: ", seen.keys(), " at ", seen.get("tug_soft", "-"), " dB  ok: ", seen.has("tug_soft") and not seen.has("tug") and absf(float(seen.get("tug_soft", 0.0)) + 7.0) < 0.1)
    quit()
