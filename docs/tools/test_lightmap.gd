extends SceneTree
# The dark of level 3 and up ("Lights Out"): levels 1 and 2 are as they were, level 3 on has the light map and
# Nicole's torch (on by default, F toggles it, and cops see her the better for it); the lights listed are the lit
# street lamps near the camera (not dead ones), burn barrels, her glow and the door of home; her torch is a
# beam that stops at walls and lights the wall it lands on. (The picture itself needs a window; see LightMap.gd.)
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_lightmap.gd
const LevelSettings := preload("res://scripts/LevelSettings.gd")

func _fresh(level: int) -> Node:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = level
    main.home_seed = 3
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    main.state = "play"
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    return main

func _init() -> void:
    # 1. The settings: the dark starts at level 3, and the levels are renamed to suit.
    var dark := []
    for n in [1, 2, 3, 4, 7]:
        dark.append(float(LevelSettings.for_level(n).darkness))
    print("1. darkness for levels 1,2,3,4,7: ", dark, "; titles: ", LevelSettings.for_level(2).title, " / ", LevelSettings.for_level(3).title,
        "  ok: ", dark == [0.0, 0.0, 0.88, 0.88, 0.88] and LevelSettings.for_level(3).title == "Lights Out" and LevelSettings.for_level(2).title == "Cold Fog")

    # 2. Level 2 is not dark: no light map, no torch, F does nothing.
    var main = await _fresh(2)
    main.player.toggle_torch()
    print("2. level 2: light map ", main.lightmap != null, ", torch ", main.player.torch_on, "  ok: ", main.lightmap == null and not main.player.torch_on)
    main.queue_free()
    await process_frame

    # 3. Level 3: the light map, the torch on, F toggles it, and cops see her the better with it on.
    main = await _fresh(3)
    var p = main.player
    var with_torch: float = p.visibility_mult()
    var start_on: bool = p.torch_on
    p.toggle_torch()
    var off_mult: float = p.visibility_mult()
    var off_now: bool = not p.torch_on
    p.toggle_torch()
    print("3. level 3: light map ", main.lightmap != null, ", torch on to start ", start_on, ", F turns it off (", off_now, ") and on; seen ",
        snappedf(with_torch / off_mult, 0.01), "x as easily with it on  ok: ", main.lightmap != null and start_on and off_now and p.torch_on and absf(with_torch / off_mult - p.TORCH_VISIBILITY) < 0.01)

    # 4. The lights listed: every lit lamp near the camera and no dead one, the barrels, her glow and the door of home.
    var focus: Vector2 = main.focus
    var near_lit := 0
    var near_dead := 0
    for l in main.lamps:
        if l.global_position.distance_to(focus) <= main.lightmap.NEAR:
            if l.brightness() > 0.02:
                near_lit += 1
            else:
                near_dead += 1
    var lights: Array = main.lightmap.lights()
    var lamp_lights := 0
    for l in lights:
        if l.color == main.lightmap.LAMP_WARM:
            lamp_lights += 1
    var glow := lights.any(func(l): return l.pos == p.global_position)
    # put Nicole by the house: its door lights up
    p.global_position = main.house.get_center()
    main.focus = main.house.get_center()
    var door: bool = main.lightmap.lights().any(func(l): return l.pos.distance_to(Vector2(main.house.end.x - 100.0, main.house.end.y)) < 8.0)
    print("4. lights near the camera: ", lamp_lights, " lamp pools for ", near_lit, " lit lamps (", near_dead, " dead or out left unlit), her glow ", glow, ", home's door ", door,
        "  ok: ", lamp_lights == near_lit and near_lit > 0 and glow and door)

    # 5. Her torch: a beam that stops at a wall and lights its south face; off, it is gone from the light map and the wall.
    var b = null
    for n in main.building_nodes:
        if n.floors > 0 and not n.house and n.rect.size.x > 120.0 and n.rect.end.y + 120.0 < main.world_rect.end.y \
                and not main.blocked_circle(Vector2(n.rect.get_center().x, n.rect.end.y + 40.0), 8.0):
            b = n
            break
    p.global_position = Vector2(b.rect.get_center().x, b.rect.end.y + 40.0)
    p.face_dir = Vector2(0.0, -1.0)
    p._update_torch()
    var rays_ok: bool = p.torch_ground.size() == p.TORCH_RAYS + 1
    var stops: bool = true
    for g in p.torch_ground:
        if (p.global_position + g).y < b.rect.end.y - 0.6:
            stops = false  # a ray ended inside the wall
    var lit_wall: bool = b.spots != null and not b.spots.strips.is_empty()
    var in_map: bool = main.lightmap.beams().size() >= 1
    p.toggle_torch()
    p._update_torch()
    var cleared: bool = (b.spots == null or b.spots.strips.is_empty()) and main.lightmap.beams().is_empty()
    print("5. torch at a wall: ", p.torch_ground.size(), " ray ends (none inside the wall: ", stops, "), wall lit ", lit_wall, ", in the light map ", in_map, "; off: gone ", cleared,
        "  ok: ", rays_ok and stops and lit_wall and in_map and cleared)
    # 6. Lit windows glow: buildings near the camera have glows, each on its own building's wall, and a dark
    # (blacked-out) window never does.
    main.queue_free()
    await process_frame
    main = await _fresh(3)
    var glows := 0
    var off_building := 0
    var buildings_with := 0
    var shop_glows := 0
    for bn in main.building_nodes:
        if bn.floors <= 0 or bn.rect.get_center().distance_to(main.focus) > main.lightmap.NEAR:
            continue
        var g: Array = bn.lit_glows()
        if not g.is_empty():
            buildings_with += 1
        for e in g:
            glows += 1
            if e[2]:
                shop_glows += 1
            if not bn.screen_box.grow(8.0).has_point(e[0]):
                off_building += 1
    print("6. lit windows near the camera: ", glows, " glows on ", buildings_with, " buildings (", shop_glows, " in shops), off their building ", off_building,
        "  ok: ", glows > 10 and off_building == 0 and shop_glows > 0)

    # 7. Cars: each moving car near the camera has a headlight beam pointing the way it drives, and lights front and back.
    main.queue_free()
    await process_frame
    var traffic_main = load("res://scenes/Main.tscn").instantiate()
    traffic_main.level_override = 3
    traffic_main.home_seed = 3
    root.add_child(traffic_main)
    for i in 3:
        await process_frame
    traffic_main.state = "play"
    traffic_main.traffic_director.enabled = false
    var lane: Dictionary = traffic_main.traffic_director.lanes[0]
    var along: float = (float(lane.a) + float(lane.b)) * 0.5
    traffic_main.traffic_director.spawn_car(lane, along, true)
    traffic_main.traffic_director.spawn_car(lane, along + 400.0, true)
    var spot: Vector2 = Vector2(along, lane.fixed) if lane.horizontal else Vector2(lane.fixed, along)
    traffic_main.player.global_position = spot + Vector2(60, 60)
    traffic_main.focus = spot
    for i in 30:
        await process_frame
    var beams: Array = traffic_main.lightmap.car_lights()
    var aligned := true
    for bm in beams:
        var found := false
        for c in traffic_main.traffic:
            if c.heading == bm.heading and c.global_position.distance_to(bm.front) < c.LENGTH:
                found = true
        if not found:
            aligned = false
    var red: int = traffic_main.lightmap.lights().filter(func(l): return l.color.r > 0.9 and l.color.g < 0.2).size()
    print("7. cars: ", traffic_main.traffic.size(), " on the road, ", beams.size(), " headlight beams near the camera (each at its car's front, along its heading: ", aligned, "), tail lights ", red,
        "  ok: ", beams.size() > 0 and aligned and red == beams.size())
    quit()
