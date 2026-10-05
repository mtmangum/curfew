extends SceneTree
# Standing in a street lamp's pool of light makes you easier to spot; stepping out
# of it, or the lamp flickering out, doesn't.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_lamp_light.gd

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    var lamp = null
    for l in main.lamps:
        if not l.flicker and not l.dead and not main.in_fire(l.global_position + Vector2(20, 0)):   # (a lamp that is out lights nothing)
            lamp = l
            break
    var inside: Vector2 = lamp.global_position + Vector2(20, 0)
    var outside: Vector2 = lamp.global_position + Vector2(lamp.radius + 30.0, 0)
    # make sure the "outside" spot really is out of every other pool too
    var tries := 0
    while main.in_light(outside) and tries < 12:
        outside += Vector2(30, 0)
        tries += 1
    main.player.set_process(true)
    main.player.global_position = inside
    for i in 4:
        await process_frame
    var lit_mult: float = main.player.visibility_mult()
    print("in the pool: lit=", main.player.lit, " visibility x", snappedf(lit_mult, 0.01))
    main.player.global_position = outside
    for i in 4:
        await process_frame
    var dark_mult: float = main.player.visibility_mult()
    print("out of it: lit=", main.player.lit, " visibility x", snappedf(dark_mult, 0.01),
        "  ok: ", not main.player.lit and lit_mult > dark_mult * 1.5)
    # a flickering lamp that is out lights nothing
    var flick = null
    for l in main.lamps:
        if l.flicker:
            flick = l
            break
    if flick != null:
        var spot: Vector2 = flick.global_position + Vector2(15, 0)
        flick.t = 0.0
        var dark_found := false
        var lit_found := false
        for k in 400:
            flick.t = float(k) * 0.01
            if flick.lights(spot):
                lit_found = true
            else:
                dark_found = true
        print("flickering lamp: lights the ground sometimes (", lit_found, ") and is dark sometimes (", dark_found, ")  ok: ", lit_found and dark_found)
    quit()
