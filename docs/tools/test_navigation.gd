extends SceneTree
# Guidance is timely and reachable without interrupting an active distraction,
# starting during pursuit, revealing home, or letting requests prolong a hint.
const Helpers := preload("res://docs/tools/world_helpers.gd")
const Guidance := preload("res://scripts/DogGuidance.gd")
const Follow := preload("res://scripts/DogFollow.gd")
const Clues := preload("res://scripts/Clues.gd")
var shots := OS.get_environment("NAVIGATION_SHOTS")

func _init() -> void:
    call_deferred("run")

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

func snapshot(name: String) -> void:
    if shots == "" or DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

func run() -> void:
    Clues.persist = false
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    main.runlog.persist = false
    for i in 3:
        await process_frame
    main.pause_menu.resume()
    main.hud.title_card.modulate.a = 0.0
    main.hud.title_card.hide()
    main.set_process(false)
    main.player.set_process(false)
    main.dog.set_process(false)
    for actors in [main.cops, main.cats, main.squirrels, main.phones]:
        for actor in actors:
            actor.set_process(false)
    var dog = main.dog
    var cat = main.cats[0]
    var squirrel = main.squirrels[0]
    var hydrant = main.hydrants[0]
    var cop = main.cops[0]
    main.cats = [cat]
    main.squirrels = []
    main.hydrants = []
    for c in main.cops:
        c.state = c.State.PATROL
        c.global_position = main.START + Vector2(-3000, 0)
    main.audio.tension = 0.0
    var spot: Vector2 = Helpers.open_run(main)
    main.player.global_position = spot
    dog.global_position = spot + Vector2(20, 0)
    dog.scent_cd = 100.0
    dog.bark_cd = 999.0
    main.player._clear_dest()
    main.player.pointer_down = true
    main.hud.update(0.0, 0.0)
    await process_frame
    await tap(main.hud.home_button)
    print("request tap queues without movement or latched steering  ok: ", dog.home_requested and dog.scent_cd == 0.0 and not main.player.has_dest and not main.player.pointer_down)
    print("request is bounded and cannot be repeated  ok: ", not dog.request_home() and dog.home_request_cd == dog.HOME_REQUEST_COOLDOWN)

    dog.chasing = cat
    cat.state = cat.State.IDLE
    cat.global_position = dog.global_position + Vector2(45, 0)
    dog._process(1.0 / 60.0)
    print("queued hint finishes the current cat chase  ok: ", dog.scent_t == 0.0 and dog.chasing == cat and dog.home_requested)
    cat.state = cat.State.FLEE
    # Fresh squirrel/hydrant would previously win the next turn.
    main.squirrels = [squirrel]
    squirrel.state = squirrel.State.RUN
    squirrel.tree_pos = dog.global_position + Vector2(50, 0)
    main.hydrants = [hydrant]
    hydrant.marked = false
    hydrant.rect.position = dog.global_position + Vector2(35, 0)
    cop.global_position = main.player.global_position + Vector2(100, 0)
    cop.state = cop.State.CHASE
    dog._process(1.0 / 60.0)
    print("pursuit suppresses a due hint even before audio tension rises  ok: ", dog.scent_t == 0.0 and dog.home_requested)
    # Clear distractions acquired while unsafe; wait for their actual end too.
    dog.chasing = null
    dog.squirrel = squirrel
    dog.hydrant = null
    dog.planted = "tree"
    cop.state = cop.State.PATROL
    dog._process(1.0 / 60.0)
    print("current squirrel fixation still finishes before a hint  ok: ", dog.scent_t == 0.0 and dog.squirrel == squirrel)
    squirrel.state = squirrel.State.AWAY
    dog._process(1.0 / 60.0)
    print("overdue hint wins over the next hydrant  ok: ", dog.scent_t > 0.0 and dog.hydrant == null and dog.planted == "" and not dog.home_requested)
    var before: float = dog.scent_t
    var cannot_extend: bool = not dog.request_home() and dog.scent_t == before
    for i in 500:
        if dog.scent_t <= 0.0:
            break
        cat.state = cat.State.IDLE
        cat.global_position = dog.global_position + Vector2(45, 0)
        dog._process(1.0 / 60.0)
    print("hint cannot be extended; bearing lasts after leading without map reveal  ok: ", cannot_extend and dog.scent_t <= 0.0 and dog.bearing_t > 3.9 and not main.minimap.home_found())
    main.cats = []
    main.hydrants = []
    main.squirrels = []
    dog.bearing_t = 0.0
    dog.scent_cd = 100.0
    dog.home_request_cd = 0.0
    dog.chasing = null
    dog.squirrel = null
    dog.hydrant = null
    dog.planted = "pee"
    dog.planted_t = 0.1
    dog.hydrant = hydrant  # still set on the actual arrival frame
    hydrant.marked = true
    dog.request_home()
    dog._process(0.05)
    var waited: bool = dog.scent_t == 0.0 and dog.planted == "pee"
    cat.state = cat.State.IDLE
    cat.global_position = dog.global_position + Vector2(40, 0)
    main.cats = [cat]
    dog._process(0.06)
    print("marking finishes, then home wins over a newly arriving cat  ok: ", waited and dog.scent_t > 0.0 and dog.chasing == null)
    main.cats = []
    dog.scent_t = 0.0
    dog.scent_path.clear()
    dog.home_request_cd = 0.0
    main.player.stunned_t = 1.0
    dog.request_home()
    dog._process(0.1)
    var stun_wait: bool = dog.scent_t == 0.0 and dog.home_requested
    main.player.stunned_t = 0.0
    main.audio.tension = 0.5
    dog._process(0.1)
    var tension_wait: bool = dog.scent_t == 0.0 and dog.home_requested
    main.audio.tension = 0.0
    dog._process(0.1)
    print("stun and tension defer a queued request until safe  ok: ", stun_wait and tension_wait and dog.scent_t > 0.0)

    dog.scent_t = 0.0
    dog.home_request_cd = 0.0
    var key := InputEventKey.new()
    key.keycode = KEY_H
    key.pressed = true
    root.push_input(key, true)
    await process_frame
    print("H reaches the same home request through actual input dispatch  ok: ", dog.home_requested and dog.scent_cd == 0.0 and dog.home_request_cd == dog.HOME_REQUEST_COOLDOWN)

    # Both a real parked car and a building block the direct home vector.
    var routes := 0
    var clear := true
    var slowest := 0.0
    var maximum := 0
    var fixture := Vector2.INF
    var destination := Vector2.INF
    var buildings_tested := 0
    var cars_tested := 0
    for obstacle in main.cars + main.buildings:
        var building: bool = main.buildings.has(obstacle)
        if not building and cars_tested >= 6:
            continue
        var from: Vector2 = Vector2(obstacle.get_center().x, obstacle.end.y + 9.0)
        var home: Vector2 = Vector2(obstacle.get_center().x, obstacle.position.y - 30.0)
        if main.blocked_circle(from, 6.0) or main.blocked_circle(home, 6.0):
            continue
        var tick: int = Time.get_ticks_usec()
        var path: PackedVector2Array = Guidance.path(main, from, home, 5.0)
        slowest = maxf(slowest, float(Time.get_ticks_usec() - tick) / 1000.0)
        if path.is_empty():
            continue
        routes += 1
        if building:
            buildings_tested += 1
        else:
            cars_tested += 1
        maximum = maxi(maximum, path.size())
        var at: Vector2 = from
        for point in path:
            clear = clear and Follow.clear_segment(main, at, point, 6.0)
            at = point
        if fixture == Vector2.INF and obstacle.size == Vector2(20, 40):
            fixture = from
            destination = home
        if buildings_tested >= 6 and cars_tested >= 6 and fixture != Vector2.INF:
            break
    print("bounded lead paths clear real cars/buildings: ", cars_tested, "/", buildings_tested, ", max waypoints ", maximum, ", slowest ", slowest, "ms  ok: ", buildings_tested >= 6 and cars_tested >= 6 and clear and maximum < Guidance.MAX_CELLS and fixture != Vector2.INF)
    # Real dog movement must make sideways progress, without being reeled back.
    dog.global_position = fixture
    main.player.global_position = fixture + Vector2(0, 30)
    var original_home: Rect2 = main.home_zone
    main.home_zone = Rect2(destination - Vector2(5, 5), Vector2(10, 10))
    dog.scent_t = 0.0
    dog._start_scent()
    dog.scent_len = dog.SCENT_TIME_FIRST
    dog.scent_t = dog.scent_len
    var clipped := false
    var widest := 0.0
    var moved_sideways := 0.0
    for i in 180:
        dog._process(1.0 / 60.0)
        clipped = clipped or main.blocked_circle(dog.global_position, dog.RADIUS)
        widest = maxf(widest, dog.global_position.distance_to(main.player.global_position))
        moved_sideways = maxf(moved_sideways, absf(dog.global_position.x - fixture.x))
    print("physical lead detours round a parked car without clipping or a leash trap  ok: ", not clipped and widest <= dog.LEASH + 1.0 and moved_sideways > 12.0 and dog.global_position.y < fixture.y - 30.0)
    main.home_zone = original_home
    main.focus = main.player.global_position
    main._update_view(0.0)
    main.hud.update(0.0, 0.0)
    await process_frame
    await snapshot("leading-around-car")

    var booth = main.phones[0]
    main.player.global_position = booth.global_position + Vector2(0, 10)
    main.player.moving = true
    main.hud.clue_up = false
    main.clues.last_at = -1000.0
    Clues.seen.erase("phone")
    main.hud.title_card.modulate.a = 0.0
    booth._process(0.1)
    var instruction: bool = booth.explain and main.clues.current_id == "phone" and "3 seconds" in main.hud.clue_label.text and not booth.used
    print("phone fixture: nearby ", booth.explain, ", clue ", main.clues.current_id, ", title alpha ", main.hud.title_card.modulate.a)
    main.focus = booth.global_position
    dog.global_position = main.player.global_position + Vector2(15, 10)
    dog.scent_t = 0.0
    dog.bearing_t = 0.0
    dog.scent_path.clear()
    main._update_view(0.0)
    main.hud.update(0.0, 0.0)
    await process_frame
    for i in 30:
        await process_frame
    await snapshot("phone-instruction")
    main.player.moving = false
    booth._process(2.0)
    var early: bool = not booth.used
    booth._process(1.1)
    print("working booth explains stand-still interaction before a three-second call  ok: ", instruction and early and booth.used)

    dog.scent_t = 0.0
    dog.home_request_cd = 0.0
    dog.home_requested = false
    main.home_zone = Rect2(main.player.global_position - Vector2.ONE * 5, Vector2.ONE * 10)
    main.minimap._process(0.0)
    main.hud.update(0.0, 0.0)
    print("finding home ends requests and hides the control  ok: ", main.minimap.home_found() and not dog.request_home() and not main.hud.home_button.visible)
    main.queue_free()
    for i in 3:
        await process_frame
    quit()
