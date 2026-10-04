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
const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")
const LevelData := preload("res://scripts/LevelData.gd")
const CollisionScript := preload("res://scripts/Collision.gd")
const LevelBuilderScript := preload("res://scripts/LevelBuilder.gd")
const GroundScript := preload("res://scripts/Ground.gd")
const TrafficDirectorScript := preload("res://scripts/TrafficDirector.gd")
const RunLogScript := preload("res://scripts/RunLog.gd")
const NoiseRingScript := preload("res://scripts/NoiseRing.gd")
const CluesScript := preload("res://scripts/Clues.gd")
const LevelSettingsScript := preload("res://scripts/LevelSettings.gd")
const LevelLookScript := preload("res://scripts/LevelLook.gd")
const PauseMenuScript := preload("res://scripts/PauseMenu.gd")
const VitalsScript := preload("res://scripts/Vitals.gd")
const AudioDirectorScript := preload("res://scripts/AudioDirector.gd")
const DepthSorterScript := preload("res://scripts/DepthSorter.gd")
const HudScript := preload("res://scripts/Hud.gd")
const ActivityGateScript := preload("res://scripts/ActivityGate.gd")

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
var clues  # the one-time hints (Clues.gd)
var fans: Array = []  # RoofFans: the air-conditioning fans that turn (see RoofFan.gd)
var builder  # made the world; the ground reads its tile mapping
var traffic_director  # spawns and removes the cars (see TrafficDirector.gd)
var traffic_enabled := true  # tests that don't want cars on the road set this before adding Main
var collision  # answers walking and line-of-sight questions (see Collision.gd)

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

var actors: Node2D
var focus := Vector2.ZERO
var building_nodes: Array = []
var building_by_rect := {}  # a building's rect -> its node (to find what a torch beam lands on)
var walked := 0.0
var play_time := 0.0
var last_pos := Vector2.ZERO
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
var pause_menu  # P / Esc (see PauseMenu.gd)
var look  # the level's colour grade, fog and rain (LevelLook.gd)
var audio  # the sounds and music (AudioDirector.gd)
var depth  # draw order and see-through buildings (DepthSorter.gd)
var hud  # the heads-up display and its messages (Hud.gd)
var gate  # switches off what is far away (ActivityGate.gd)
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
    depth = DepthSorterScript.new(self)
    gate = ActivityGateScript.new(self)
    walls = buildings
    level = level_override if level_override > 0 else level_number
    settings = LevelSettingsScript.for_level(level)
    clues = CluesScript.new(self)
    if home_seed < 0:  # a try after a lost run keeps the same house; otherwise pick one
        home_seed = retry_seed if retry_seed >= 0 else randi() % 1000000
    if progressive_boot:
        process_mode = Node.PROCESS_MODE_DISABLED  # nothing runs until the world is built
        visible = false  # and nothing draws (beams and so on read the collision grids)
    await boot_step("sound", 0.0)
    audio = AudioDirectorScript.new()
    add_child(audio)
    audio.setup(self)
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
        _clear_threats_from(player.global_position)
    await boot_step("streets", 0.7)
    traffic_director = TrafficDirectorScript.new()
    traffic_director.setup(self)
    traffic_director.enabled = traffic_enabled
    add_child(traffic_director)
    focus = player.global_position
    last_pos = player.global_position
    _update_view(1.0)
    depth.sort()

    vitals = VitalsScript.new()
    vitals.setup(self)
    add_child(vitals)
    hud = HudScript.new(self)
    hud.build()
    runlog = RunLogScript.new()
    add_child(runlog)
    runlog.setup(self)
    hud.show_title_card()
    look = LevelLookScript.new()
    add_child(look)
    look.setup(self)
    pause_menu = PauseMenuScript.new()
    add_child(pause_menu)
    pause_menu.setup(self)
    await boot_step("streets", 1.0)
    if progressive_boot and OS.has_feature("web"):
        await _hold_for_loader()
    if progressive_boot:
        process_mode = Node.PROCESS_MODE_INHERIT
        visible = true
        await get_tree().process_frame  # let the first frame of the game draw
    is_booted = true
    booted.emit()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.curfewReady&&window.curfewReady()", true)

# On the web the loading page may ask for a moment more before the game starts, so the tip it is
# showing can be read (a cached start is over in a blink): window.curfewHold gives the milliseconds
# it still wants, 0 when the tip has had its time or the player pressed a key. The game stays frozen
# and unseen meanwhile (process_mode is DISABLED and visible is off until this returns).
func _hold_for_loader() -> void:
    while true:
        var left = JavaScriptBridge.eval("window.curfewHold?window.curfewHold():0", true)
        if not (left is float or left is int) or float(left) <= 0.0:
            return
        await get_tree().create_timer(minf(float(left), 100.0) / 1000.0, true).timeout

# The Music / Ambience / SFX buses come from default_bus_layout.tres. They have
# to exist before the game starts: on the web, buses added at runtime never
# reach the browser's audio graph and everything goes silent.
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

# Where a try after a lost run starts: where she fell, or as near as open ground allows (a short
# search, never far: out of walls, off the front step, and away from any street person if there is
# a spot within 60 units that is). What could end her at once is moved instead of her: a cop
# posted within RESPAWN_COP_DIST of the spot is sent to the part of his own patrol farthest from
# it (the world is rebuilt, so every cop is back at his post, and a death is usually at a cop).
const RESPAWN_COP_DIST := 380.0
const RESPAWN_PEOPLE_DIST := 160.0

func _respawn_spot(want: Vector2) -> Vector2:
    var tries: Array = [want]
    var radii: Array = [18.0, 36.0, 60.0, 90.0, 130.0, 190.0]
    for radius in radii:
        for k in 12:
            tries.append(want + Vector2.from_angle(float(k) * TAU / 12.0 + radius) * radius)
    var nearest_open := Vector2.INF
    for p in tries:
        if not world_rect.grow(-60.0).has_point(p) or blocked_circle(p, 9.0) or home_zone.grow(40.0).has_point(p):
            continue
        if nearest_open == Vector2.INF:
            nearest_open = p
        if p.distance_to(want) <= 60.0 and _people_clear(p):
            return p
    return nearest_open if nearest_open != Vector2.INF else START

func _people_clear(p: Vector2) -> bool:
    for n in npcs:
        if n.global_position.distance_to(p) < RESPAWN_PEOPLE_DIST:
            return false
    return true

# Once she is placed: cops posted close by go to the far end of their patrols, and street people
# close by are told to leave her be for a few seconds.
func _clear_threats_from(p: Vector2) -> void:
    for c in cops:
        if c.global_position.distance_to(p) < RESPAWN_COP_DIST:
            c.send_away_from(p)
    for n in npcs:
        if n.global_position.distance_to(p) < RESPAWN_PEOPLE_DIST:
            n.grab_cd = maxf(n.grab_cd, 3.0)
            n.leave_alone_t = maxf(n.leave_alone_t, 6.0)

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
const CLUES_WORD := "CLUES"  # typing this forgets which clues have been shown, so they come round again
var cheat_typed := ""

func _cheat_input(event: InputEventKey) -> void:
    var code: int = event.keycode
    if code >= KEY_A and code <= KEY_Z:
        cheat_typed = (cheat_typed + char(code)).right(maxi(CHEAT_WORD.length(), CLUES_WORD.length()))
        if cheat_typed == CLUES_WORD:
            cheat_typed = ""
            CluesScript.reset()
            _show_toast("Clues reset: they will show again")
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
    gate.tick(delta)
    depth.sort()
    depth.fade_buildings(delta)
    var worst := 0.0
    for c in cops:
        worst = maxf(worst, c.exposure)
    audio.update(delta, worst)
    # Fade the hints once the player has got going, then the objective.
    walked += player.global_position.distance_to(last_pos)
    last_pos = player.global_position
    # Both fade only after you have walked a good way AND played a while, so the
    # controls stay up long enough to learn them.
    if state == "play":
        play_time += delta
    var progress: float = minf(walked / 600.0, play_time / 30.0)
    hud.update(worst, progress)
    if state == "play" and home_zone.has_point(player.global_position):
        _win()

# The whole street is drawn through an isometric canvas transform that follows
# the player. Game logic never sees it: positions stay on the flat plane.
func _update_view(_delta: float) -> void:
    var t := Transform2D(Sprites.ISO_X * ZOOM, Sprites.ISO_Y * ZOOM, Vector2.ZERO)
    t.origin = get_viewport_rect().size * 0.5 - t.basis_xform(focus)
    get_viewport().canvas_transform = t

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
    audio.fade_music(2.5)

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
    hud.flash_hurt()
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
    audio.fade_music(0.6)

# Sound, toast and banner: the rest of the game calls these; the work is in AudioDirector and Hud.
func bark(db: float = 0.0) -> void:
    audio.bark(db)

func play(sound_name: String, db: float = 0.0, pitch: float = 1.0) -> void:
    audio.play(sound_name, db, pitch)

func play_at(sound_name: String, pos: Vector2, db: float = 0.0, reach: float = 320.0, pitch: float = 1.0) -> void:
    audio.play_at(sound_name, pos, db, reach, pitch)

func footstep(db: float, weight: float = 1.0, pos = null, reach: float = 240.0) -> void:
    audio.footstep(db, weight, pos, reach)

func _show_toast(text: String) -> void:
    hud.show_toast(text)

func _show_banner(title: String, sub: String, color: Color, dim: Color) -> void:
    hud.show_banner(title, sub, color, dim)

# The map she had explored before the last try, handed over once (to the new map).
func take_retry_state() -> Dictionary:
    var saved: Dictionary = retry_state
    retry_state = {}
    return saved

# A sound. Cops within `radius` of `pos` hear it and go to look. `lead` is where they are
# told to go if that is not where it came from (Stella's barks point them at Nicole), and
# `alert` leaves them quicker, more thorough and more suspicious for a while. Returns how many
# cops turned to look (one already chasing her does not).
func noise(pos: Vector2, radius_in: float, show_ring: bool = true, alert: bool = false, lead: Vector2 = Vector2.INF) -> int:
    var radius: float = radius_in * float(settings.noise_scale)  # rain hushes everything a little
    if show_ring:
        var ring := NoiseRingScript.new()
        ring.radius = radius
        ring.z_as_relative = false
        ring.z_index = 3500
        add_child(ring)
        ring.global_position = pos
    var told: Vector2 = pos if lead == Vector2.INF else lead
    var turned := 0
    for c in cops:
        if c.global_position.distance_to(pos) <= radius and c.hear(told, alert):
            turned += 1
    return turned

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

func ray_hit_wall(origin: Vector2, dir: Vector2, max_len: float) -> Array:
    return collision.ray_hit_wall(origin, dir, max_len)

func los(a: Vector2, b: Vector2) -> bool:
    return collision.los(a, b)
