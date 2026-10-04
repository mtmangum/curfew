extends Node2D
# Streetwise II: Curfew: sneak Nicole and Stella home across a night street. The level is
# built here from plain data so it's easy to rearrange.

const PlayerScript := preload("res://scripts/Player.gd")
const DogScript := preload("res://scripts/Dog.gd")
const CopScript := preload("res://scripts/Cop.gd")
const CatScript := preload("res://scripts/Cat.gd")
const PropScript := preload("res://scripts/Prop.gd")
const VentScript := preload("res://scripts/SteamVent.gd")
const FireScript := preload("res://scripts/Fire.gd")
const BuildingScript := preload("res://scripts/Building.gd")
const CarScript := preload("res://scripts/Car.gd")
const LampScript := preload("res://scripts/StreetLight.gd")
const MiniMapScript := preload("res://scripts/MiniMap.gd")
const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")
const LevelData := preload("res://scripts/LevelData.gd")
const CollisionScript := preload("res://scripts/Collision.gd")
const LevelBuilderScript := preload("res://scripts/LevelBuilder.gd")
const GroundScript := preload("res://scripts/Ground.gd")
const TrafficDirectorScript := preload("res://scripts/TrafficDirector.gd")
const RunLogScript := preload("res://scripts/RunLog.gd")
const NoiseRingScript := preload("res://scripts/NoiseRing.gd")
const LevelSettingsScript := preload("res://scripts/LevelSettings.gd")
const LevelLookScript := preload("res://scripts/LevelLook.gd")
const PauseMenuScript := preload("res://scripts/PauseMenu.gd")
const VitalsScript := preload("res://scripts/Vitals.gd")

const ZOOM := 1.8
# Only things this close to the view get depth-sorted and (for cops) simulated.
const NEAR_VIEW := 800.0
# Decorative blocks around the playable street so the view never reaches the void.
const DECOR_MARGIN := 700.0

# The start is in the bottom-left tile. Home is a different building every run
# (LevelBuilder._choose_home), so `house` and `home_zone` are set before the world is built.
const START := Vector2(250, 1290 + 1440)  # in the bottom-left plaza of tile (0,1)

var world_rect := Rect2(-2560, 0, 2560 * 4, 1440 * 3)
var home_zone := Rect2()  # the patch of street in front of the front door
var home_seed := -1  # >= 0 makes the choice of home repeatable (tests); set before adding Main to the tree
var house := Rect2()  # the building that is home
# City blocks in rows from north to south, with avenues between the rows and
# lanes between the blocks.
var buildings: Array[Rect2] = []
var walls: Array[Rect2] = []
var cars: Array[Rect2] = []  # parked cars: solid to walk into, but low enough to see over
var npcs: Array = []  # hobos and punks
var skaters: Array = []  # skateboarders on the roads (spawned by the traffic director)
var traffic: Array = []  # cars driving the roads (they move, so they are sorted every frame)
var obstacles: Array[Rect2] = []  # street furniture (dumpsters, trees, ...): solid, but not sight blockers
# Patrol routes, one per cop (also used to keep parked cars off their paths).
var cop_routes: Array = []  # every cop's patrol, in world coordinates
var decor: Array[Rect2] = []
var car_count := 0
var lamps: Array = []
# The static things near the view, refreshed only as the camera moves, so the
# per-frame sorting and fading don't scan every building, car and lamp.
var builder  # made the world; the ground reads its tile mapping
var traffic_director  # spawns and removes the cars (see TrafficDirector.gd)
var traffic_enabled := true  # tests that don't want cars on the road set this before adding Main
var collision  # answers walking and line-of-sight questions (see Collision.gd)
var near_cache_focus := Vector2(-999999.0, -999999.0)
var near_boxes: Array = []
var near_statics: Array = []

var state := "play"
var screen_relative := false
var sneak_toggle := false  # holds sneaking on without Shift (no button for it any more; the tests and the bot use it)
var ended_at := 0
var player
var dog
var cops: Array = []
var vents: Array = []
var fires: Array = []
var props: Array = []
var cats: Array = []
var sounds := {}

var actors: Node2D
var focus := Vector2.ZERO
var building_nodes: Array = []
var danger: ColorRect
var objective: Label
var hints: Control
var toast: Label
var banner: Control
var banner_dim: ColorRect
var banner_title: Label
var banner_sub: Label
var walked := 0.0
var play_time := 0.0
var ambience_player: AudioStreamPlayer
var music_low: AudioStreamPlayer
var music_high: AudioStreamPlayer
var tension := 0.0
var music_gain := 1.0  # 1 while playing; fades to 0 when the run ends
var fade_in := 0.0  # the music and ambience swell in from silence at the start
var fade_started := false
# Browsers hold all audio until the first click or key press, so on the web the
# fade-in waits for that. Static, so a restart (which reloads the scene) remembers.
static var audio_unlocked := false
var last_pos := Vector2.ZERO
var toast_tween: Tween
var minimap: Control
var vitals  # Nicole's life (see Vitals.gd)
var pickups: Array = []  # pizza slices lying about (see Pickup.gd)
var hydrants: Array = []  # StreetObject hydrants Stella may pee on
var trees: Array = []  # tree positions
var squirrels: Array = []  # see Squirrel.gd
var phones: Array = []  # PhoneBooth nodes: a call fills in the map round the booth
# What carries over to the next try after a lost run (or an R): the same home, and the map
# she had explored (see MiniMap). A win, or Shift+R, starts afresh. Static, so it survives
# reload_current_scene.
static var retry_seed := -1
static var retry_state := {}
static var retry_pos := Vector2.INF  # where the last try ended: the next one starts here
# Which level she is on (see LevelSettings.gd). A win moves it up; losing keeps it. Static, so it
# survives reloading the scene. CURFEW_LEVEL in the environment starts a session on that level.
static var level_number := maxi(1, int(OS.get_environment("CURFEW_LEVEL")))
var level_override := -1  # tests set this before adding Main to the tree
var level := 1
var settings := {}
var level_label: Label
var pause_menu  # P / Esc (see PauseMenu.gd)
var look  # the level's colour grade, fog and rain (LevelLook.gd)
var title_card: VBoxContainer  # "LEVEL 3 / RAINY NIGHT" as a level starts
var wind_player: AudioStreamPlayer  # level 2 and up
var rain_player: AudioStreamPlayer  # level 3 and up
const WIND_DB := -20.0
const RAIN_DB := -15.0
var hurt_flash: ColorRect
var runlog  # playtest telemetry (see RunLog.gd); F3 shows it

# Booting. On the web the world is built a piece at a time, a frame between pieces, so
# the loading page (web/shell.html) can show real progress for each stage and a slow
# phone is not left with a frozen screen. Everywhere else it is built in one go (no
# frame passes), which is what the tests rely on. A test can set progressive_boot to
# try the slow path; set it before adding Main to the tree.
signal boot_progress(stage: String, fraction: float)  # stage: "sound", "city", "streets"
signal booted
var progressive_boot := OS.has_feature("web")
var is_booted := false

func boot_step(stage: String, fraction: float) -> void:
    boot_progress.emit(stage, fraction)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.curfewBoot&&window.curfewBoot('%s',%.3f)" % [stage, fraction], true)
    if progressive_boot:
        await get_tree().process_frame

func _ready() -> void:
    randomize()
    walls = buildings
    level = level_override if level_override > 0 else level_number
    settings = LevelSettingsScript.for_level(level)
    if home_seed < 0:  # a try after a lost run keeps the same house; otherwise pick one
        home_seed = retry_seed if retry_seed >= 0 else randi() % 1000000
    if progressive_boot:
        process_mode = Node.PROCESS_MODE_DISABLED  # nothing runs until the world is built
        visible = false  # and nothing draws (beams and so on read the collision grids)
    await boot_step("sound", 0.0)
    for n in ["pickup", "tug", "step0", "step1", "step2", "step3", "step4", "bin_crash", "meow", "cat_hiss",
            "alert", "spotted", "caught", "home", "tick", "honk", "car_pass", "yell", "thunder", "siren_far", "sniff",
            "car_hit", "skate_hit", "shove", "zombie_bite", "zombie_moan", "bark0", "bark1", "bark2"]:
        sounds[n] = load("res://assets/audio/%s.wav" % n)
    _setup_audio()
    if not OS.has_feature("web") or audio_unlocked:
        _start_fade_in()
    await boot_step("sound", 1.0)

    actors = Node2D.new()
    add_child(actors)

    builder = LevelBuilderScript.new(self)
    await builder.build()
    await boot_step("streets", 0.0)
    _make_ground()

    player = PlayerScript.new()
    player.main = self
    actors.add_child(player)
    player.global_position = START

    dog = DogScript.new()
    dog.main = self
    actors.add_child(dog)
    dog.global_position = START + Vector2(-20, 8)

    collision = CollisionScript.new()
    collision.main = self
    await boot_step("streets", 0.4)
    collision.build()
    if retry_pos != Vector2.INF:  # a try after a lost run starts where the last one ended
        player.global_position = _respawn_spot(retry_pos)
        dog.global_position = slide(player.global_position, Vector2(-20, 8), dog.RADIUS)
    await boot_step("streets", 0.7)
    traffic_director = TrafficDirectorScript.new()
    traffic_director.setup(self)
    traffic_director.enabled = traffic_enabled
    add_child(traffic_director)
    focus = player.global_position
    last_pos = player.global_position
    _update_view(1.0)
    _depth_sort()

    vitals = VitalsScript.new()
    vitals.setup(self)
    add_child(vitals)
    _build_hud()
    runlog = RunLogScript.new()
    add_child(runlog)
    runlog.setup(self)
    _show_title_card()
    look = LevelLookScript.new()
    add_child(look)
    look.setup(self)
    pause_menu = PauseMenuScript.new()
    add_child(pause_menu)
    pause_menu.setup(self)
    await boot_step("streets", 1.0)
    if progressive_boot:
        process_mode = Node.PROCESS_MODE_INHERIT
        visible = true
        await get_tree().process_frame  # let the first frame of the game draw
    is_booted = true
    booted.emit()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.curfewReady&&window.curfewReady()", true)

# The Music / Ambience / SFX buses come from default_bus_layout.tres. They have
# to exist before the game starts: on the web, buses added at runtime never
# reach the browser's audio graph and everything goes silent.
func _setup_audio() -> void:
    ambience_player = _loop_player("ambience", "Ambience", -9.0)
    music_low = _loop_player("music_low", "Music", -12.0)
    music_high = _loop_player("music_high", "Music", -50.0)
    if settings.wind:
        wind_player = _loop_player("wind_loop", "Ambience", WIND_DB)
    if float(settings.rain) > 0.0:
        rain_player = _loop_player("rain_loop", "Ambience", RAIN_DB)

func _loop_player(stream_name: String, bus: String, db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = load("res://assets/audio/%s.wav" % stream_name)
    p.bus = bus
    p.volume_db = db
    add_child(p)
    p.play()
    return p

# The music has a calm layer and a busy layer; the busy one swells in as cops
# get suspicious or go to investigate.
func _update_music(delta: float, worst: float) -> void:
    var target := clampf(worst * 1.6, 0.0, 1.0)
    for c in cops:
        if c.state == c.State.INVESTIGATE and c.global_position.distance_squared_to(player.global_position) < 350.0 * 350.0:
            target = maxf(target, 0.45)
        elif c.state == c.State.CHASE and c.global_position.distance_squared_to(player.global_position) < 700.0 * 700.0:
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

func _fade_music(seconds: float) -> void:
    var tw := create_tween()
    tw.tween_property(self, "music_gain", 0.0, seconds)

# One floor under everything, and a ground node per tile with its pavements, plazas,
# lane markings and crosswalks (so tiles off screen cost nothing to draw).
func _make_ground() -> void:
    var floor := GroundScript.Floor.new()
    floor.main = self
    floor.z_index = -100
    floor.z_as_relative = false
    add_child(floor)
    for ty in range(LevelData.TILE_MIN.y, LevelData.TILE_MAX.y + 1):
        for tx in range(LevelData.TILE_MIN.x, LevelData.TILE_MAX.x + 1):
            var tile := GroundScript.TileGround.new()
            tile.builder = builder
            tile.tx = tx
            tile.ty = ty
            tile.z_index = -99
            tile.z_as_relative = false
            add_child(tile)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 2  # over the level's fog (layer 1)
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.theme = Style.theme()
    layer.add_child(ui)

    danger = ColorRect.new()
    danger.set_anchors_preset(Control.PRESET_FULL_RECT)
    danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    danger.color = Color(0.8, 0.05, 0.05, 0.0)
    ui.add_child(danger)

    hurt_flash = ColorRect.new()
    hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hurt_flash.color = Color(1.0, 0.1, 0.05, 0.0)
    ui.add_child(hurt_flash)

    vitals.build_bar(ui)
    level_label = Label.new()
    level_label.text = "LEVEL %d" % level
    level_label.position = Vector2(432, 11)
    level_label.add_theme_font_size_override("font_size", 18)
    level_label.add_theme_color_override("font_color", Style.GOLD)
    ui.add_child(level_label)

    objective = Label.new()
    objective.text = "Get Nicole and Stella home unseen."
    objective.position = Vector2(20, 46)
    objective.add_theme_font_size_override("font_size", 24)
    objective.add_theme_color_override("font_color", Style.GOLD)
    ui.add_child(objective)

    var version := Label.new()
    version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
    version.add_theme_font_size_override("font_size", 16)
    version.add_theme_color_override("font_color", Style.DIM)
    version.anchor_top = 1.0
    version.anchor_bottom = 1.0
    version.offset_left = 18
    version.offset_top = -62  # above the hint row, which is wide
    version.offset_bottom = -10
    ui.add_child(version)

    # Control hints along the bottom; they fade once the player has got going.
    var bottom := VBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
    bottom.alignment = BoxContainer.ALIGNMENT_END
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(bottom)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(center)
    var strip := PanelContainer.new()
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var strip_box := StyleBoxFlat.new()
    strip_box.bg_color = Color(0.04, 0.05, 0.09, 0.72)
    strip_box.set_corner_radius_all(6)
    strip_box.content_margin_left = 16
    strip_box.content_margin_right = 16
    strip_box.content_margin_top = 8
    strip_box.content_margin_bottom = 8
    strip.add_theme_stylebox_override("panel", strip_box)
    center.add_child(strip)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 22)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.add_child(row)
    row.add_child(Style.hint(["CLICK"], "walk"))
    row.add_child(Style.hint(["W", "A", "S", "D"], "move"))
    row.add_child(Style.hint(["SHIFT"], "sneak"))
    row.add_child(Style.hint(["TAB"], "keys"))
    row.add_child(Style.hint(["M"], "map"))
    row.add_child(Style.hint(["N"], "sound"))
    row.add_child(Style.hint(["P"], "pause"))
    row.add_child(Style.hint(["R"], "restart"))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 18)
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(gap)
    hints = center

    # The map in the top-right corner: shows only what Nicole has seen, plus home.
    minimap = MiniMapScript.new()
    minimap.setup(self)
    if not retry_state.is_empty():
        minimap.import_state(retry_state)
        retry_state = {}
    minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    minimap.offset_left = -(minimap.size.x + 16.0)
    minimap.offset_right = -16.0
    minimap.offset_top = 14.0
    minimap.offset_bottom = 14.0 + minimap.size.y
    ui.add_child(minimap)

    toast = Label.new()
    toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
    toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
    toast.position.y = 64
    toast.modulate.a = 0.0
    toast.add_theme_font_size_override("font_size", 22)
    ui.add_child(toast)

    # The level's title card, shown for a few seconds as it starts.
    title_card = VBoxContainer.new()
    title_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
    title_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
    title_card.position.y = 120
    title_card.add_theme_constant_override("separation", 6)
    title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_card.modulate.a = 0.0
    var card_level := Style.display_label("", 26, Style.GOLD, 6)
    card_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_card.add_child(card_level)
    var card_name := Style.display_label("", 60, Style.INK, 10)
    card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_card.add_child(card_name)
    ui.add_child(title_card)

    # End-of-run banner: dimmed screen, big title, blinking prompt.
    banner = Control.new()
    banner.set_anchors_preset(Control.PRESET_FULL_RECT)
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.visible = false
    ui.add_child(banner)
    banner_dim = ColorRect.new()
    banner_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    banner_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(banner_dim)
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 18)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(box)
    banner_title = Style.display_label("", 80, Style.RED, 12)
    banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(banner_title)
    banner_sub = Label.new()
    banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_sub.add_theme_font_size_override("font_size", 26)
    box.add_child(banner_sub)

# "LEVEL 3" over the level's name, fading in, holding a moment and fading out.
func _show_title_card() -> void:
    (title_card.get_child(0) as Label).text = "LEVEL %d" % level
    (title_card.get_child(1) as Label).text = str(settings.title).to_upper()
    var tw := create_tween()
    tw.tween_property(title_card, "modulate:a", 1.0, 0.6)
    tw.tween_interval(2.4)
    tw.tween_property(title_card, "modulate:a", 0.0, 1.0)

func _show_toast(text: String) -> void:
    toast.text = text
    if toast_tween != null:
        toast_tween.kill()
    toast.modulate.a = 1.0
    toast_tween = create_tween()
    toast_tween.tween_interval(1.4)
    toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)

func _show_banner(title: String, sub: String, color: Color, dim: Color) -> void:
    banner_title.text = title
    banner_title.add_theme_color_override("font_color", color)
    banner_sub.text = sub
    banner_dim.color = dim
    banner.modulate.a = 0.0
    banner.visible = true
    var fade := create_tween()
    fade.tween_property(banner, "modulate:a", 1.0, 0.4)
    # Title pops in; the prompt blinks.
    await get_tree().process_frame
    banner_title.pivot_offset = banner_title.size * 0.5
    banner_title.scale = Vector2(1.4, 1.4)
    var pop := create_tween()
    pop.tween_property(banner_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var blink := create_tween().set_loops()
    blink.tween_property(banner_sub, "modulate:a", 0.35, 0.7)
    blink.tween_property(banner_sub, "modulate:a", 1.0, 0.7)

# Where a try after a lost run starts: as near as it can to where she fell, but on open ground
# with no cop close (nor a cop's patrol about to bring him by), no street person or zombie close
# (the world is rebuilt, so they are all back at their posts), and not on the front step. Falls
# back to the usual start, which no cop's patrol comes near.
const RESPAWN_COP_DIST := 380.0    # no cop standing this close
const RESPAWN_ROUTE_DIST := 220.0  # and no patrol route this close: he would be along in moments

func _respawn_spot(want: Vector2) -> Vector2:
    var tries: Array = [want]
    for radius in [40.0, 80.0, 140.0, 220.0, 320.0, 450.0, 600.0, 800.0]:
        for k in 16:
            tries.append(want + Vector2.from_angle(float(k) * TAU / 16.0 + radius) * radius)
    for p in tries:
        if not world_rect.grow(-60.0).has_point(p) or blocked_circle(p, 9.0) or home_zone.grow(40.0).has_point(p):
            continue
        if cop_near(p):
            continue
        var clear := true
        for n in npcs:
            if n.global_position.distance_to(p) < 160.0:
                clear = false
                break
        if clear:
            return p
    return START

# Is a cop close to a point, or does one of the patrols pass close by it?
func cop_near(p: Vector2) -> bool:
    for c in cops:
        if c.global_position.distance_to(p) < RESPAWN_COP_DIST:
            return true
        var w: Array = c.waypoints
        for i in w.size():
            var from: Vector2 = w[i]
            var to: Vector2 = w[(i + 1) % w.size()]
            if Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) < RESPAWN_ROUTE_DIST:
                return true
    return false

# Start over. After a lost run (or R mid-run) the house and the explored map are kept;
# after a win, or with Shift+R, it is a new neighbourhood.
func restart(fresh: bool = false) -> void:
    if fresh or state == "won":
        retry_seed = -1
        retry_state = {}
        retry_pos = Vector2.INF
    else:
        retry_seed = home_seed
        retry_state = minimap.export_state()
        retry_pos = player.global_position
    get_tree().reload_current_scene()

# A hidden way to test any level: type LEVEL and then a digit (1 to 9, 0 for level 10) and the
# game starts that level, in a new neighbourhood. Any other key in between spoils the word.
const CHEAT_WORD := "LEVEL"
var cheat_typed := ""

func _cheat_input(event: InputEventKey) -> void:
    var code: int = event.keycode
    if code >= KEY_A and code <= KEY_Z:
        cheat_typed = (cheat_typed + char(code)).right(CHEAT_WORD.length())
        return
    var digit := -1
    if code >= KEY_0 and code <= KEY_9:
        digit = code - KEY_0
    elif code >= KEY_KP_0 and code <= KEY_KP_9:
        digit = code - KEY_KP_0
    if digit < 0:
        return
    var armed: bool = cheat_typed == CHEAT_WORD
    cheat_typed = ""
    if armed:
        go_to_level(10 if digit == 0 else digit)

func go_to_level(n: int) -> void:
    if not is_booted:
        return
    level_number = maxi(1, n)
    retry_seed = -1
    retry_state = {}
    retry_pos = Vector2.INF
    get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        _cheat_input(event)
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        restart(event.shift_pressed)
    # Tap to play again once the banner has been up a moment.
    if state != "play" and event is InputEventMouseButton and event.pressed \
            and Time.get_ticks_msec() - ended_at > 700:
        restart()
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
        var n: int = runlog.copy_to_clipboard()
        _show_toast("Copied %d run%s to the clipboard" % [n, "" if n == 1 else "s"])
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
        runlog.toggle()
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
        minimap.visible = not minimap.visible
        _show_toast("Map on" if minimap.visible else "Map off")
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
        var muted: bool = not AudioServer.is_bus_mute(0)
        AudioServer.set_bus_mute(0, muted)
        _show_toast("Sound off" if muted else "Sound on")
        if not muted:
            play("tick")
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
        screen_relative = not screen_relative
        _show_toast("Keys: screen-relative" if screen_relative else "Keys: along the streets")

func _process(delta: float) -> void:
    focus = focus.lerp(player.global_position, clampf(8.0 * delta, 0.0, 1.0))
    _update_view(delta)
    _depth_sort()
    _fade_buildings(delta)
    var worst := 0.0
    for c in cops:
        worst = maxf(worst, c.exposure)
    danger.color.a = worst * 0.35
    _update_music(delta, worst)
    # Fade the hints once the player has got going, then the objective.
    walked += player.global_position.distance_to(last_pos)
    last_pos = player.global_position
    # Both fade only after you have walked a good way AND played a while, so the
    # controls stay up long enough to learn them.
    if state == "play":
        play_time += delta
    var progress: float = minf(walked / 600.0, play_time / 30.0)
    hints.modulate.a = clampf(1.0 - (progress - 1.0) / 0.25, 0.0, 1.0)
    objective.modulate.a = clampf(1.0 - (progress - 2.0) / 0.25, 0.0, 1.0)
    if state == "play" and home_zone.has_point(player.global_position):
        _win()

# The whole street is drawn through an isometric canvas transform that follows
# the player. Game logic never sees it: positions stay on the flat plane.
func _update_view(_delta: float) -> void:
    var t := Transform2D(Sprites.ISO_X * ZOOM, Sprites.ISO_Y * ZOOM, Vector2.ZERO)
    t.origin = get_viewport_rect().size * 0.5 - t.basis_xform(focus)
    get_viewport().canvas_transform = t

# True if `a` has to be drawn before (behind) `b`. Actors sort by distance
# along the view diagonal; boxes sort by which side of them an actor is on.
func _behind(a, b) -> bool:
    var a_box: bool = a is BuildingScript
    var b_box: bool = b is BuildingScript
    if not a_box and not b_box:
        return a.global_position.x + a.global_position.y < b.global_position.x + b.global_position.y
    if a_box and b_box:
        var ra: Rect2 = a.rect
        var rb: Rect2 = b.rect
        var a_first: bool = ra.end.x <= rb.position.x or ra.end.y <= rb.position.y
        var b_first: bool = rb.end.x <= ra.position.x or rb.end.y <= ra.position.y
        return a_first and not b_first
    if a_box:
        return not _behind(b, a)
    var p: Vector2 = a.global_position
    var r: Rect2 = b.rect
    return not (p.x >= r.end.x or p.y >= r.end.y)

# Orders everything on screen that stands on the ground so nearer things draw on
# top. Only pairs whose screen boxes overlap can hide each other, so only those
# are compared. Things off screen keep whatever z they had.
# Rebuilds the near_* caches if the camera has moved far enough. They cover a
# generous area around the focus, so a refresh every ~140 units is plenty.
func _refresh_near() -> void:
    if focus.distance_squared_to(near_cache_focus) < 140.0 * 140.0:
        return
    near_cache_focus = focus
    var area := Rect2(Sprites.iso(focus) - Vector2(700.0, 520.0), Vector2(1400.0, 1040.0))
    near_boxes.clear()
    near_statics.clear()
    for b in building_nodes:
        if b.screen_box.intersects(area):
            near_boxes.append(b)
    for list in [props, fires, lamps]:
        for n in list:
            if area.has_point(Sprites.iso(n.global_position)):
                near_statics.append(n)

func _depth_sort() -> void:
    _refresh_near()
    var centre: Vector2 = Sprites.iso(focus)
    var view := Rect2(centre - Vector2(450.0, 310.0), Vector2(900.0, 620.0))
    var items: Array = []
    var boxes: Array = []  # screen box of each item
    for b in near_boxes:
        if b.screen_box.intersects(view):
            items.append(b)
            boxes.append(b.screen_box)
    for n in near_statics:
        var sp0: Vector2 = Sprites.iso(n.global_position)
        if view.has_point(sp0):
            items.append(n)
            boxes.append(Rect2(sp0.x - 14.0, sp0.y - 52.0, 28.0, 54.0))
    for list in [cats, cops, npcs, skaters, pickups, squirrels]:
        for n in list:
            var sp: Vector2 = Sprites.iso(n.global_position)
            if view.has_point(sp):
                items.append(n)
                boxes.append(Rect2(sp.x - 14.0, sp.y - 52.0, 28.0, 54.0))
    for car in traffic:  # moving boxes: their screen box changes every frame
        if car.screen_box.intersects(view):
            items.append(car)
            boxes.append(car.screen_box)
    for n in [dog, player]:
        var sp2: Vector2 = Sprites.iso(n.global_position)
        items.append(n)
        boxes.append(Rect2(sp2.x - 14.0, sp2.y - 52.0, 28.0, 54.0))
    var count: int = items.size()
    var waiting := PackedInt32Array()
    waiting.resize(count)
    var after: Array = []
    for i in count:
        after.append([])
    for i in count:
        var bi: Rect2 = boxes[i]
        for j in range(i + 1, count):
            if not bi.intersects(boxes[j]):
                continue
            if _behind(items[i], items[j]):
                after[i].append(j)
                waiting[j] += 1
            elif _behind(items[j], items[i]):
                after[j].append(i)
                waiting[i] += 1
    var done := PackedByteArray()
    done.resize(count)
    for rank in count:
        var pick := -1
        var pick_key := INF
        var fallback := -1
        var fallback_key := INF
        for i in count:
            if done[i] == 1:
                continue
            var key: float = _depth_key(items[i])
            if key < fallback_key:
                fallback_key = key
                fallback = i
            if waiting[i] == 0 and key < pick_key:
                pick_key = key
                pick = i
        if pick == -1:
            pick = fallback
        done[pick] = 1
        items[pick].z_index = 100 + rank
        for k in after[pick]:
            waiting[k] -= 1

func _depth_key(n) -> float:
    if n is BuildingScript:
        return n.rect.end.x + n.rect.end.y
    return n.global_position.x + n.global_position.y

# Buildings go see-through while Nicole or Stella is hidden behind one.
func _fade_buildings(delta: float) -> void:
    _refresh_near()
    for b in near_boxes:
        if not b.fades:
            b.modulate.a = 1.0
            continue
        var hidden := false
        for who in [player, dog]:
            if not _behind(who, b):
                continue
            var foot: Vector2 = Sprites.iso(who.global_position)
            if not b.screen_box.has_point(foot):
                continue
            var poly: PackedVector2Array = b.silhouette()
            if Geometry2D.is_point_in_polygon(foot, poly) \
                    or Geometry2D.is_point_in_polygon(foot + Vector2(0, -26), poly):
                hidden = true
        b.modulate.a = move_toward(b.modulate.a, 0.3 if hidden else 1.0, 4.0 * delta)

func _win() -> void:
    state = "won"
    ended_at = Time.get_ticks_msec()
    runlog.finish("won")
    level_number = level + 1  # the next time is the next level
    retry_seed = -1
    retry_state = {}
    retry_pos = Vector2.INF
    _show_banner("LEVEL %d CLEAR" % level, "Press R or tap for level %d: %s" % [level + 1, str(LevelSettingsScript.for_level(level + 1).title)], Style.GOLD, Color(0.1, 0.07, 0.0, 0.5))
    play("home")
    _fade_music(2.5)

func caught(cop) -> void:
    if state != "play":
        return
    runlog.finish("caught", {"cop_chase_s": snappedf(runlog._cop_state.get(cop.get_instance_id(), {}).get("chase_t", 0.0), 0.1)})
    _lose("CAUGHT")
    play("caught")

# A car hit Nicole or Stella: it costs a lot of life and flings her clear. Only the
# last of her life ends the run.
func run_over(car, stella_hit: bool = false) -> void:
    if state != "play":
        return
    var detail := {"avenue": absf(car.speed) > 120.0, "sneaking": player.sneaking, "stella": stella_hit}
    if not hurt(VitalsScript.CAR_DAMAGE, "car", detail):
        return
    play("car_hit")
    play("honk", -4.0)
    if state != "play":
        return
    # She is thrown sideways out of the lane and left seeing stars; Stella is only shoved.
    var victim: Node2D = dog if stella_hit else player
    var side: Vector2 = car.heading.orthogonal()
    if side.dot(victim.global_position - car.global_position) < 0.0:
        side = -side
    if stella_hit:
        dog.global_position = slide(dog.global_position, side * 30.0, dog.RADIUS)
    else:
        player.stun(2.0, side * 34.0)
    noise(car.global_position, 240.0, true)

# A street hazard hurts her. False while she is still in grace from the last hit (the
# hazard should then do nothing). Her life running out ends the run.
func hurt(amount: float, source: String, detail: Dictionary = {}) -> bool:
    if state != "play":
        return false
    if not vitals.hurt(amount, source):
        return false
    runlog.note_damage(source, amount, vitals.health)
    hurt_flash.color.a = 0.35
    create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.5)
    if vitals.health <= 0.0:
        _out_of_life(source, detail)
    return true

# Steady damage (a hobo's grip): no grace, no flash.
func drain(amount: float, source: String) -> void:
    if state != "play":
        return
    vitals.drain(amount, source)
    runlog.note_damage(source, amount, vitals.health)
    if vitals.health <= 0.0:
        _out_of_life(source, {})

func _out_of_life(source: String, detail: Dictionary) -> void:
    detail["source"] = source
    if source == "car":
        runlog.finish("run_over", detail)
        _lose("RUN OVER")
    else:
        runlog.finish("knocked_out", detail)
        _lose("KNOCKED OUT")

# Nicole finished a call at a phone booth: the map fills in round it (home is not marked).
func use_phone(booth) -> void:
    minimap.phone_call(booth.global_position)
    play("pickup")
    noise(booth.global_position, 150.0, true)  # a call can be heard a little way off
    runlog.note_phone()
    _show_toast("Phone booth: map updated")

# Nicole walked over a slice of pizza.
func collect_pickup(pickup) -> void:
    var gained: float = vitals.heal(VitalsScript.PIZZA)
    pickups.erase(pickup)
    pickup.queue_free()
    runlog.note_pickup(gained)
    play("pickup")
    _show_toast("+%d LIFE" % int(gained))

func _lose(title: String) -> void:
    state = "caught"
    ended_at = Time.get_ticks_msec()
    _show_banner(title, "Press R or tap to try again (same house, same map, where you fell)", Style.RED, Color(0.14, 0.0, 0.0, 0.58))
    _fade_music(0.6)

# One of Stella's barks: a random one of three, with a little pitch wobble.
func bark(db: float = 0.0) -> void:
    play("bark%d" % (randi() % 3), db, randf_range(0.94, 1.08))

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
    var d: float = pos.distance_to(player.global_position)
    if d >= reach:
        return
    play(sound_name, db + linear_to_db(pow(1.0 - d / reach, 1.5)), pitch)

# One footfall. Variant, volume and pitch wobble a little so steps never repeat
# exactly. `weight` shifts the pitch: below 1 is a heavier boot.
const STEP_VARIANTS := 5
func footstep(db: float, weight: float = 1.0, pos = null, reach: float = 240.0) -> void:
    var name := "step%d" % randi_range(0, STEP_VARIANTS - 1)
    var wobble_db: float = randf_range(-1.5, 1.5)
    var pitch: float = weight * randf_range(0.94, 1.06)
    if pos == null:
        play(name, db + wobble_db, pitch)
    else:
        play_at(name, pos, db + wobble_db, reach, pitch)

# A sound. Cops within `radius` of `pos` hear it and go to look. `lead` is where they are
# told to go if that is not where it came from (Stella's barks point them at Nicole), and
# `alert` leaves them quicker, more thorough and more suspicious for a while.
func noise(pos: Vector2, radius_in: float, show_ring: bool = true, alert: bool = false, lead: Vector2 = Vector2.INF) -> void:
    var radius: float = radius_in * float(settings.noise_scale)  # rain hushes everything a little
    if show_ring:
        var ring := NoiseRingScript.new()
        ring.radius = radius
        ring.z_as_relative = false
        ring.z_index = 3500
        add_child(ring)
        ring.global_position = pos
    var told: Vector2 = pos if lead == Vector2.INF else lead
    for c in cops:
        if c.global_position.distance_to(pos) <= radius:
            c.hear(told, alert)

func in_steam(p: Vector2) -> bool:
    for v in vents:
        if v.active and p.distance_to(v.global_position) < v.radius:
            return true
    return false

func in_fire(p: Vector2) -> bool:
    for f in fires:
        if f.lights(p):
            return true
    return false

# Lit ground makes whoever stands on it easier to spot: by a trash fire or a street lamp.
func in_light(p: Vector2) -> bool:
    return in_fire(p) or collision.lit_by_lamp(p)

# --- Collision and sight, answered by Collision.gd ---------------------------------
func blocked_circle(pos: Vector2, r: float) -> bool:
    return collision.blocked_circle(pos, r)

# Move from pos by motion, sliding along walls and around round obstacles.
func slide(pos: Vector2, motion: Vector2, r: float) -> Vector2:
    return collision.slide(pos, motion, r)

# Distance along the ray to the first wall or active steam cloud.
func ray_hit(origin: Vector2, dir: Vector2, max_len: float) -> float:
    return collision.ray_hit(origin, dir, max_len)

func los(a: Vector2, b: Vector2) -> bool:
    return collision.los(a, b)
