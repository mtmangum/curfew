extends Node
# Everything the game plays. The loops: the city's ambience (and from level 2 a wind, from level 3
# rain) and two layers of music, a calm one and a busy one that swells in as cops get suspicious or
# go to investigate. The one-shots: Main.play / play_at / bark / footstep forward here.

const WIND_DB := -20.0
const RAIN_DB := -15.0
const STEP_VARIANTS := 5
const BARK_SINGLES := 4  # bark0..bark3 are single barks of different tone; bark4 and bark5 are runs of two and three
const BARK_RUN_CHANCE := 0.3
const SOUND_NAMES := ["pickup", "tug", "step0", "step1", "step2", "step3", "step4", "bin_crash", "meow", "cat_hiss",
        "alert", "spotted", "caught", "home", "tick", "honk", "car_pass", "yell", "thunder", "siren_far", "sniff",
        "car_hit", "skate_hit", "shove", "zombie_bite", "zombie_moan", "bark0", "bark1", "bark2", "bark3", "bark4", "bark5"]
const LOOP_NAMES := ["ambience", "music_low", "music_high", "wind_loop", "rain_loop", "steam_loop"]

# A fixed-size cache keeps stream identities across scene reloads. The Web
# sample backend retains registered decoded buffers after a resource is freed;
# reloading new resources each retry otherwise registers another full set.
# Playback nodes remain scene-owned and are freed normally.
static var _streams: Dictionary = {}

static func stream_for(stream_name: String) -> AudioStream:
    if not SOUND_NAMES.has(stream_name) and not LOOP_NAMES.has(stream_name):
        return null
    if not _streams.has(stream_name):
        _streams[stream_name] = load("res://assets/audio/%s.wav" % stream_name)
    return _streams[stream_name]

# Browsers hold all audio until the first click or key press, so on the web the
# fade-in waits for that. Static, so a restart (which reloads the scene) remembers.
static var audio_unlocked := false

var main
var sounds := {}
var ambience_player: AudioStreamPlayer
var music_low: AudioStreamPlayer
var music_high: AudioStreamPlayer
var wind_player: AudioStreamPlayer  # level 2 and up
var rain_player: AudioStreamPlayer  # level 3 and up
var tension := 0.0
var music_gain := 1.0  # 1 while playing; fades to 0 when the run ends
var fade_in := 0.0  # the music and ambience swell in from silence at the start
var fade_started := false
var last_bark := -1

# Loads the sounds and starts the loops for this level.
func setup(game) -> void:
    main = game
    for n in SOUND_NAMES:
        sounds[n] = stream_for(n)
    ambience_player = _loop_player("ambience", "Ambience", -9.0)
    music_low = _loop_player("music_low", "Music", -12.0)
    music_high = _loop_player("music_high", "Music", -50.0)
    if main.settings.wind:
        wind_player = _loop_player("wind_loop", "Ambience", WIND_DB)
    if float(main.settings.rain) > 0.0:
        rain_player = _loop_player("rain_loop", "Ambience", RAIN_DB)
    if not OS.has_feature("web") or audio_unlocked:
        _start_fade_in()

func _loop_player(stream_name: String, bus: String, db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = stream_for(stream_name)
    p.bus = bus
    p.volume_db = db
    add_child(p)
    p.play()
    return p

# The music has a calm layer and a busy layer; the busy one swells in as cops
# get suspicious or go to investigate.
func update(delta: float, worst: float) -> void:
    var target := clampf(worst * 1.6, 0.0, 1.0)
    for c in main.cops:
        if c.state == c.State.INVESTIGATE and c.global_position.distance_squared_to(main.player.global_position) < 350.0 * 350.0:
            target = maxf(target, 0.45)
        elif c.state == c.State.CHASE and c.global_position.distance_squared_to(main.player.global_position) < 700.0 * 700.0:
            target = 1.0
    tension = move_toward(tension, target, delta * (1.2 if target > tension else 0.4))
    var gain: float = linear_to_db(maxf(music_gain * fade_in, 0.0001))
    music_low.volume_db = -12.0 + gain
    music_high.volume_db = -9.0 + linear_to_db(maxf(tension * tension, 0.0001)) + gain
    var ambient: float = linear_to_db(maxf(lerpf(1.0, 0.35, 1.0 - music_gain) * fade_in, 0.0001))
    ambience_player.volume_db = -9.0 + ambient
    if wind_player != null:
        wind_player.volume_db = WIND_DB + ambient
    if rain_player != null:
        rain_player.volume_db = RAIN_DB + ambient

func _start_fade_in() -> void:
    if fade_started:
        return
    fade_started = true
    var tw := create_tween()
    tw.tween_property(self, "fade_in", 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _input(event: InputEvent) -> void:
    if audio_unlocked:
        return
    if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
        audio_unlocked = true
        _start_fade_in()

# The run is over: the music fades out.
func fade_music(seconds: float) -> void:
    var tw := create_tween()
    tw.tween_property(self, "music_gain", 0.0, seconds)

# One of Stella's barks (cut from a real recording, docs/barks.m4a): mostly a single one (never the
# same as the last, since from one dog they sound alike), now and then a run of two or three, each
# with a good wobble in pitch and volume so a string of them doesn't sound like one sample.
func bark(db: float = 0.0) -> void:
    var n: int = randi() % BARK_SINGLES
    if n == last_bark:
        n = (n + 1 + randi() % (BARK_SINGLES - 1)) % BARK_SINGLES
    if randf() < BARK_RUN_CHANCE:
        n = BARK_SINGLES + randi() % 2
    last_bark = n
    play("bark%d" % n, db + randf_range(-1.5, 1.0), randf_range(0.88, 1.15))

func play(sound_name: String, db: float = 0.0, pitch: float = 1.0) -> void:
    var s = sounds.get(sound_name)
    if s == null:
        return
    var p := AudioStreamPlayer.new()
    p.stream = s
    p.volume_db = db
    p.pitch_scale = pitch
    p.bus = "SFX"
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

# A sound out in the world: quieter the farther it is from Nicole, silent past `reach`.
func play_at(sound_name: String, pos: Vector2, db: float = 0.0, reach: float = 320.0, pitch: float = 1.0) -> void:
    var d: float = pos.distance_to(main.player.global_position)
    if d >= reach:
        return
    play(sound_name, db + linear_to_db(pow(1.0 - d / reach, 1.5)), pitch)

# One footfall. Variant, volume and pitch wobble a little so steps never repeat
# exactly. `weight` shifts the pitch: below 1 is a heavier boot.
func footstep(db: float, weight: float = 1.0, pos = null, reach: float = 240.0) -> void:
    var name := "step%d" % randi_range(0, STEP_VARIANTS - 1)
    var wobble_db: float = randf_range(-1.5, 1.5)
    var pitch: float = weight * randf_range(0.94, 1.06)
    if pos == null:
        play(name, db + wobble_db, pitch)
    else:
        play_at(name, pos, db + wobble_db, reach, pitch)
