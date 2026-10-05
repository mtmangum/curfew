extends SceneTree
# Sound wiring: loops play, the busy music layer follows suspicion, effects fall
# off with distance, and buses are not duplicated by a restart.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_audio.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 5:
        await process_frame
    print("loops playing: ", main.audio.ambience_player.playing, main.audio.music_low.playing, main.audio.music_high.playing)
    print("loop modes (1 = forward): ", main.audio.ambience_player.stream.loop_mode, main.audio.music_low.stream.loop_mode,
        "  ok: ", main.audio.ambience_player.stream.loop_mode == 1 and main.audio.music_low.stream.loop_mode == 1)
    print("buses: ", AudioServer.get_bus_index("Music") >= 0, AudioServer.get_bus_index("Ambience") >= 0, AudioServer.get_bus_index("SFX") >= 0)
    var quiet: float = main.audio.music_low.volume_db
    for i in 270:
        await process_frame
    print("ambience arrives before music: ", main.audio.ambience_player.volume_db > -10.0 \
        and main.audio.music_low.volume_db < -16.0)
    for i in 300:
        await process_frame
    print("music fades in slowly (", snappedf(quiet, 0.1), " -> ", snappedf(main.audio.music_low.volume_db, 0.1), " dB): ",
        quiet < -30.0 and main.audio.music_low.volume_db > -13.0)
    # A collection requests playback in the same frame as the life change.
    var pizza = main.pickups[0]
    main.vitals.health = 50.0
    main.collect_pickup(pizza)
    var pickup_players: Array = main.audio.get_children().filter(func(p): return p is AudioStreamPlayer and p.stream == main.audio.sounds["pickup"])
    print("pickup heals and starts its sound immediately: ", main.vitals.health > 50.0 and pickup_players.size() == 1 and pickup_players[0].playing)
    if OS.has_feature("web"):
        print("pickup sample already prepared: ", AudioServer.is_stream_registered_as_sample(main.audio.sounds["pickup"]))
    var calm: float = main.audio.music_high.volume_db
    # Put the player in a cop's beam: tension should rise and the busy layer swell.
    for c in main.cops:
        c.set_process(false)
    main.cops[0].exposure = 0.8
    for i in 90:
        await process_frame
    print("busy layer swells with suspicion: ", main.audio.music_high.volume_db > calm + 10.0, " (", snappedf(calm, 0.1), " -> ", snappedf(main.audio.music_high.volume_db, 0.1), " dB)")
    main.cops[0].exposure = 0.0
    # Distance falloff for positional effects.
    var before: int = main.audio.get_child_count()
    main.play_at("alert", main.player.global_position + Vector2(5000, 0), 0.0, 300.0)
    print("too-far sound is skipped: ", main.audio.get_child_count() == before)
    main.play_at("alert", main.player.global_position + Vector2(50, 0), 0.0, 300.0)
    print("near sound plays: ", main.audio.get_child_count() == before + 1)
    # A vent's hiss starts when it blows next to the player.
    var v = main.vents[0]
    main.player.global_position = v.global_position + Vector2(20, 0)
    v.t = 1.0
    v.amount = 1.0
    for i in 5:
        await process_frame
    print("vent hiss plays when close: ", v.hiss.playing)
    # Ending the run fades the music.
    main.caught(main.cops[0])
    for i in 90:
        await process_frame
    print("music fades after caught: ", main.audio.music_gain < 0.05)
    # Restart must not stack buses.
    var count: int = AudioServer.bus_count
    var again = load("res://scenes/Main.tscn").instantiate()
    root.add_child(again)
    for i in 3:
        await process_frame
    print("restart keeps bus count: ", AudioServer.bus_count == count)
    quit()
