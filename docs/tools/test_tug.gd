extends SceneTree
# The leash tug: a hard lunge (at a cat, a squirrel, a hydrant) plays `tug` (a thump and a jingle of
# clasp and collar ring). Home guidance waits at the leash limit without a tug or owner movement.
# The legacy soft sound remains loadable; both files are short and differ.
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

func _fresh() -> Node:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    main.home_seed = 0
    main.audit_seed = 1
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
    var run: Vector2 = Helpers.open_run(main)
    cat.global_position = run + Vector2(115, 0)
    main.player.global_position = run
    main.dog.global_position = run + Vector2(30, 5)
    main.dog.pee_cd = 999.0
    main.dog.bark_cd = 0.0
    var seen: Dictionary = await _watch(main, 200)
    print("2. a lunge at a cat plays: ", seen.keys(), " at ", seen.get("tug", "-"), " dB  ok: ", seen.has("tug") and not seen.has("tug_soft") and absf(float(seen.get("tug", 0.0)) + 4.0) < 0.1)
    main.queue_free()
    await process_frame

    # 3. Stella's home cue must not imply hauling with either tug sound.
    main = await _fresh()
    main.cats = []
    main.squirrels = []
    main.hydrants = []
    main.corner_folk = []
    var from: Vector2 = Helpers.free_spot(main, main.START + Vector2(260, -160))
    main.player.global_position = from
    main.dog.global_position = from + Vector2(-24, 6)
    main.dog.pee_cd = 999.0
    main.dog.scent_cd = 0.0
    main.dog._start_scent()
    var started: bool = main.dog.scent_t > 0.0
    seen = await _watch(main, 220)
    print("3. home guidance has no tug sound or owner movement  ok: ", started and seen.is_empty() and main.player.global_position.distance_to(from) < 0.1)
    quit()
