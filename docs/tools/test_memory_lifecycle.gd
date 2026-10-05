extends SceneTree
# Helpers must be released along with their owning scene, including the
# LevelBuilder/FurnitureBuilder back-reference. An orphan-node check misses this.
func _init() -> void:
    call_deferred("run")

func run() -> void:
    for i in 5:
        var game=load("res://scenes/Main.tscn").instantiate()
        game.level_override=6
        game.home_seed=731
        game.traffic_enabled=false
        root.add_child(game)
        game.runlog.persist=false
        var builder_ref: WeakRef=weakref(game.builder)
        var furniture_ref: WeakRef=weakref(game.builder.furniture)
        var collision_ref: WeakRef=weakref(game.collision)
        var depth_ref: WeakRef=weakref(game.depth)
        var clues_ref: WeakRef=weakref(game.clues)
        game.queue_free()
        game=null
        for j in 4: await process_frame
        var released: bool=builder_ref.get_ref()==null and furniture_ref.get_ref()==null and collision_ref.get_ref()==null and depth_ref.get_ref()==null and clues_ref.get_ref()==null
        print("cycle ",i+1," helper references released  ok: ",released)
    # Exercise the actual R/retry path as well as manual world disposal.
    var game=load("res://scenes/Main.tscn").instantiate()
    game.level_override=6
    root.add_child(game)
    current_scene=game
    for i in 5:
        game.runlog.persist=false
        game.settings.clues=true
        game.hud.title_card.modulate.a=0.0
        game.clues.last_at=-1000.0
        game.clues.offer("scent")
        game.clues.offer("item_treat")
        var old_scene: WeakRef=weakref(game)
        var old_builder: WeakRef=weakref(game.builder)
        var old_furniture: WeakRef=weakref(game.builder.furniture)
        var old_clues: WeakRef=weakref(game.clues)
        game.restart()
        game=null
        for j in 8: await process_frame
        game=current_scene
        var released: bool=old_scene.get_ref()==null and old_builder.get_ref()==null and old_furniture.get_ref()==null and old_clues.get_ref()==null
        print("restart ",i+1," previous scene and helpers released  ok: ",released)
    game.runlog.persist=false
    game.queue_free()
    game=null
    for j in 4: await process_frame
    await create_timer(0.4).timeout  # let the audio driver retire deferred playbacks
    quit()
