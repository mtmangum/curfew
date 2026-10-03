extends SceneTree
# A picture of the start area, for checking visuals without playing. Needs a real
# (non-headless) window and SHOT_DIR set to an output folder; saves shot.png.
#   SHOT_DIR=/tmp godot --path . --script docs/tools/screenshot.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    main.focus = main.player.global_position
    for i in 40:
        await process_frame
    root.get_viewport().get_texture().get_image().save_png("%s/shot.png" % OS.get_environment("SHOT_DIR"))
    quit()
