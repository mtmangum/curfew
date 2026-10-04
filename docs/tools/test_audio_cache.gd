extends SceneTree
# A retry must reuse stream identities. Web registrations are keyed by resource
# ID, so merely checking scene/object cleanup misses retained browser samples.
const Audio = preload("res://scripts/AudioDirector.gd")
func _init() -> void:
    call_deferred("run")
func run() -> void:
    var ids: Dictionary = {}
    for cycle in 3:
        var game = load("res://scenes/Main.tscn").instantiate()
        game.level_override = 6
        game.home_seed = 731
        game.traffic_enabled = false
        root.add_child(game)
        game.runlog.persist = false
        var streams: Array = game.audio.sounds.values()
        for player in [game.audio.ambience_player,game.audio.music_low,game.audio.music_high,game.audio.wind_player,game.audio.rain_player]:
            streams.append(player.stream)
        streams.append(game.vents[0].hiss.stream)
        var reused := true
        for stream in streams:
            var key: String = stream.resource_path
            if cycle == 0: ids[key] = stream.get_instance_id()
            elif ids[key] != stream.get_instance_id(): reused = false
        var scene_ref: WeakRef = weakref(game)
        game.queue_free()
        game = null
        for i in 4: await process_frame
        print("audio cycle ",cycle+1," stream identities reused and scene released  ok: ",reused and scene_ref.get_ref() == null)
    print("audio cache bounded to roster  ok: ",Audio._streams.size() <= Audio.SOUND_NAMES.size()+Audio.LOOP_NAMES.size())
    print("unknown names do not grow cache  ok: ",Audio.stream_for("nonexistent") == null)
    Engine.max_fps = 60
    await create_timer(0.5).timeout
    quit()
