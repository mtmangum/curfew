extends SceneTree
# Sound wiring: loops play, the busy music layer follows suspicion, effects fall
# off with distance, and buses are not duplicated by a restart.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_audio.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    for i in 5:
        await process_frame
    print("loops playing: ", main.ambience_player.playing, main.music_low.playing, main.music_high.playing)
    print("loop modes (1 = forward): ", main.ambience_player.stream.loop_mode, main.music_low.stream.loop_mode)
    print("buses: ", AudioServer.get_bus_index("Music") >= 0, AudioServer.get_bus_index("Ambience") >= 0, AudioServer.get_bus_index("SFX") >= 0)
    var quiet: float = main.music_low.volume_db
    for i in 270:
        await process_frame
    print("music fades in (", snappedf(quiet, 0.1), " -> ", snappedf(main.music_low.volume_db, 0.1), " dB): ",
        quiet < -30.0 and main.music_low.volume_db > -13.0)
    var calm: float = main.music_high.volume_db
    # Put the player in a cop's beam: tension should rise and the busy layer swell.
    for c in main.cops:
        c.set_process(false)
    main.cops[0].exposure = 0.8
    for i in 90:
        await process_frame
    print("busy layer swells with suspicion: ", main.music_high.volume_db > calm + 10.0, " (", snappedf(calm, 0.1), " -> ", snappedf(main.music_high.volume_db, 0.1), " dB)")
    main.cops[0].exposure = 0.0
    # Distance falloff for positional effects.
    var before: int = main.get_child_count()
    main.play_at("alert", main.player.global_position + Vector2(5000, 0), 0.0, 300.0)
    print("too-far sound is skipped: ", main.get_child_count() == before)
    main.play_at("alert", main.player.global_position + Vector2(50, 0), 0.0, 300.0)
    print("near sound plays: ", main.get_child_count() == before + 1)
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
    print("music fades after caught: ", main.music_gain < 0.05)
    # Restart must not stack buses.
    var count: int = AudioServer.bus_count
    var again = load("res://scenes/Main.tscn").instantiate()
    root.add_child(again)
    for i in 3:
        await process_frame
    print("restart keeps bus count: ", AudioServer.bus_count == count)
    quit()
