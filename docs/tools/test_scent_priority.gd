extends SceneTree
# A due scent hint waits for a distraction to end; once started, new cats,
# squirrels and hydrants cannot erase it. Ordinary chasing resumes afterwards.
const Helpers := preload("res://docs/tools/world_helpers.gd")
const CluesScript := preload("res://scripts/Clues.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 1
    main.traffic_enabled = false
    root.add_child(main)
    main.runlog.persist = false
    for i in 3:
        await process_frame
    main.set_process(false)
    main.player.set_process(false)
    main.dog.set_process(false)
    for c in main.cops:
        c.set_process(false)
    for c in main.cats:
        c.set_process(false)
    for s in main.squirrels:
        s.set_process(false)
    var dog = main.dog
    var cat = main.cats[0]
    var squirrel = main.squirrels[0]
    var hydrant = main.hydrants[0]
    main.cats = [cat]
    main.squirrels = []
    main.hydrants = []
    main.state = "play"
    main.audio.tension = 0.0
    CluesScript.seen["scent"] = true
    var spot: Vector2 = Helpers.open_run(main)
    main.player.global_position = spot
    dog.global_position = spot + Vector2(20, 0)
    dog.pee_cd = 999.0
    dog.scent_t = 0.0
    dog.scent_cd = 0.0
    dog.bark_cd = 999.0
    cat.global_position = dog.global_position + Vector2(45, 0)
    cat.state = cat.State.IDLE
    dog.chasing = cat  # already chasing when the timer comes due
    dog._process(1.0 / 60.0)
    print("due hint waits while chasing a cat  ok: ", dog.chasing == cat and dog.scent_t == 0.0 and dog.scent_cd == 0.0)
    cat.state = cat.State.FLEE
    dog._process(1.0 / 60.0)
    print("hint starts when cat distraction ends  ok: ", dog.scent_t > 0.0 and dog.chasing == null)
    var kept_hint := true
    # Present all three distractions throughout the hint, wherever she walks.
    main.squirrels = [squirrel]
    main.hydrants = [hydrant]
    dog.pee_cd = 0.0
    var steps: int = int(ceil(dog.scent_t * 60.0))
    for i in steps + 1:
        if dog.scent_t <= 0.0:
            break
        cat.state = cat.State.IDLE
        cat.global_position = dog.global_position + Vector2(45, 0)
        squirrel.state = squirrel.State.RUN
        squirrel.tree_pos = dog.global_position + Vector2(50, 0)
        hydrant.marked = false
        hydrant.rect.position = dog.global_position + Vector2(35, 0)
        var remaining: float = dog.scent_t
        dog._process(1.0 / 60.0)
        kept_hint = kept_hint and absf(dog.scent_t - maxf(0.0, remaining - 1.0 / 60.0)) < 0.001 \
            and dog.chasing == null and dog.squirrel == null and dog.hydrant == null and dog.planted == ""
    print("full hint survives cats, squirrels and hydrants  ok: ", kept_hint and dog.scent_t <= 0.0 and dog.scent_cd > 0.0)
    cat.global_position = dog.global_position + Vector2(45, 0)
    dog._process(1.0 / 60.0)
    print("ordinary cat chasing resumes after hint  ok: ", dog.chasing == cat)
    main.queue_free()
    await process_frame
    quit()
