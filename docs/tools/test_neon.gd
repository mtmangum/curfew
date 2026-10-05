extends SceneTree
# Level 5 and up, "Neon Nose": the settings (neon on, people on the corners, no boarded-up look, a violet dark with
# pink windows and fog), and what a level 5 city looks like next to levels 3 and 4. (More is added as the neon is built.)
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_neon.gd
const LevelSettings := preload("res://scripts/LevelSettings.gd")

func _init() -> void:
    # 1. The settings by level: neon only from level 5, with people on the corners, and no dressing.
    var rows := []
    var ok := true
    for n in [2, 3, 4, 5, 6, 9]:
        var s: Dictionary = LevelSettings.for_level(n)
        rows.append([n, float(s.neon), int(s.corner_folk), float(s.dressing), float(s.darkness)])
        var neon: bool = n >= 5
        if (float(s.neon) > 0.0) != neon or (int(s.corner_folk) > 0) != neon or (float(s.dressing) > 0.0) != (n == 4):
            ok = false
    var five: Dictionary = LevelSettings.for_level(5)
    var look_ok: bool = five.title == "Neon Nose" and float(five.darkness) < 0.88 and float(five.darkness) > 0.7 \
            and five.ambient.r > five.ambient.b * 0.6 and LevelSettings.for_level(3).ambient.b > LevelSettings.for_level(3).ambient.r \
            and five.window_light.r > 0.9 and five.window_light.g < 0.6 and five.fog_tint.r > five.fog_tint.g
    print("1. [level, neon, corner folk, dressing, darkness]: ", rows, "; level 5 title ", five.title, " and a violet dark, pink windows and fog: ", look_ok,
        "  ok: ", ok and look_ok and int(LevelSettings.for_level(9).corner_folk) <= 24 and int(LevelSettings.for_level(9).corner_folk) >= int(five.corner_folk))

    # 2. A level 5 city: no boarded windows, the dark is on (with its violet ambient), the title card says so.
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 5
    main.home_seed = 3
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    var boarded := 0
    for b in main.building_nodes:
        if b.boarded > 0.0:
            boarded += 1
    var amb: Color = main.lightmap.ambient
    print("2. level 5: buildings set to be boarded ", boarded, ", light map on ", main.lightmap != null, ", ambient ", amb, ", title card ", (main.hud.title_card.get_child(1) as Label).text,
        "  ok: ", boarded == 0 and main.lightmap != null and amb.r > amb.b * 0.6 and (main.hud.title_card.get_child(1) as Label).text == "NEON NOSE")
    # 3. The signs: about half the buildings have one, each fits on its wall, in a neon colour, from the letters we have,
    # decided from the building's number (the same every time); flickering ones stutter out and back.
    var NeonSign = load("res://scripts/NeonSign.gd")
    var eligible := 0
    var signed := 0
    var off_wall := 0
    var again_differs := 0
    var bad_colour := 0
    var made := 0
    for b in main.building_nodes:
        if b.floors <= 0 or b.house:
            continue
        eligible += 1
        var p: Dictionary = NeonSign.plan_for(b.rect, b.variant, b.height, b.floors)
        if b.neon_sign != null:
            made += 1
        if p.is_empty():
            continue
        signed += 1
        if str(p) != str(NeonSign.plan_for(b.rect, b.variant, b.height, b.floors)):
            again_differs += 1
        var length: float = b.rect.size.x if p.face == "s" else b.rect.size.y
        if p.u < 0.0 or p.u + p.w > length or p.z < 18.0 or p.z + p.h > b.height + 8.0:
            off_wall += 1
        if not (p.color in NeonSign.COLORS):
            bad_colour += 1
    var share: float = float(signed) / float(maxi(eligible, 1))
    var lows := 0
    var steps := 4700
    for k in steps:
        if NeonSign.brightness_at(float(k) * 0.001) < 0.5:
            lows += 1
    var words_ok := true
    for w in NeonSign.WORDS:
        for ch in w:
            if not NeonSign.FONT.has(ch):
                words_ok = false
    print("3. signs: ", signed, " of ", eligible, " buildings (", snappedf(share * 100.0, 1.0), "%), nodes made ", made, ", off their wall ", off_wall, ", not the same twice ", again_differs, ", bad colours ", bad_colour,
        "; every letter there: ", words_ok, "; a flickering sign is dark ", snappedf(100.0 * float(lows) / float(steps), 0.1), "% of the time",
        "  ok: ", share > 0.4 and share < 0.7 and made == signed and off_wall == 0 and again_differs == 0 and bad_colour == 0 and words_ok and lows > 100 and lows < 1500)

    # 4. The light map lights the street and the wall round every sign near the camera, in its colour.
    var near_signs := 0
    var lit_pools := 0
    var lit_halos := 0
    for s in main.neon_signs:
        if s.anchor().distance_to(main.focus) <= main.lightmap.NEAR:
            near_signs += 1
            if main.lightmap.lights().any(func(l): return l.color == s.plan.color and l.pos.distance_to(s.anchor() + s.outward() * 22.0) < 0.1):
                lit_pools += 1
            if main.lightmap.halos().any(func(h): return h.color == s.plan.color and h.pos == s.anchor() and h.height == s.height_mid()):
                lit_halos += 1
    print("4. signs near the camera ", near_signs, ", each with a pool on the street ", lit_pools, " and a glow on its wall ", lit_halos, "  ok: ", near_signs > 3 and lit_pools == near_signs and lit_halos == near_signs)
    # 5. The corner characters: the number the level asks for, all three kinds, on open ground, clear of the start and of each other.
    var want: int = int(main.settings.corner_folk)
    var kinds := {}
    var blocked := 0
    var too_near_start := 0
    var bunched := 0
    var outside := 0
    for k in main.corner_folk.size():
        var f = main.corner_folk[k]
        kinds[f.kind] = true
        if main.blocked_circle(f.global_position, 6.0):
            blocked += 1
        if f.global_position.distance_to(main.START) < 260.0:
            too_near_start += 1
        if not main.world_rect.has_point(f.global_position):
            outside += 1
        for j in range(k + 1, main.corner_folk.size()):
            if f.global_position.distance_to(main.corner_folk[j].global_position) < 140.0:
                bunched += 1
    print("5. corner folk: ", main.corner_folk.size(), " of the ", want, " asked for, ", kinds.size(), " kinds, in walls ", blocked, ", near the start ", too_near_start, ", bunched ", bunched, ", outside the world ", outside,
        "  ok: ", main.corner_folk.size() >= want - 2 and main.corner_folk.size() <= want and kinds.size() == 3 and blocked == 0 and too_near_start == 0 and bunched == 0 and outside == 0)

    # 6. Stella stops for one: she goes to it, sniffs for about four seconds with the leash holding Nicole, goes on,
    # and will not stop for the same person again for a good while.
    main.state = "play"
    for c in main.cops:
        c.set_process(false)
    for cat in main.cats:
        cat.global_position = Vector2(-9000.0, -9000.0)
    main.player.set_process(false)
    main.dog.scent_cd = 99999.0
    main.dog.pee_cd = 99999.0
    var person = main.corner_folk[0]
    var Helpers = load("res://docs/tools/world_helpers.gd")
    var start: Vector2 = Helpers.free_spot(main, person.global_position + Vector2(0.0, 60.0))
    main.player.global_position = start + Vector2(20.0, 10.0)
    main.dog.global_position = start
    main.focus = start
    var reached := false
    var sniff_frames := 0
    var after_frames := 0
    var resniffed := false
    var max_leash := 0.0
    for i in 900:
        await physics_frame
        max_leash = maxf(max_leash, main.dog.global_position.distance_to(main.player.global_position))
        if main.dog.planted == "sniff":
            reached = true
            sniff_frames += 1
        elif reached:
            after_frames += 1
            if main.dog.folk != null and main.dog.folk == person:
                resniffed = true
    var secs: float = float(sniff_frames) / 60.0
    print("6. Stella sniffed the person: ", reached, " for ", snappedf(secs, 0.1), " s, the leash held (longest ", snappedf(max_leash, 1.0), " of ", main.dog.LEASH, "), the person's cooldown ", snappedf(person.cool, 1.0),
        " s left, sniffed them again within ", snappedf(float(after_frames) / 60.0, 0.1), " s: ", resniffed,
        "  ok: ", reached and secs > 3.5 and secs < 4.6 and max_leash <= main.dog.LEASH + 1.0 and person.cool > 0.0 and not resniffed)
    # 7. Wet streets: a spot beside a sign takes its colour (a puddle shines in it), one far from any sign takes none.
    var tile = main.get_children().filter(func(c): return c.has_method("neon_tint_at"))[0]
    var s0 = main.neon_signs[0]
    var near_tint: Color = tile.neon_tint_at(s0.anchor() + s0.outward() * 40.0)
    var far_tint: Color = tile.neon_tint_at(Vector2(-99999.0, -99999.0))
    print("7. a puddle 40 units from a sign takes its colour: ", near_tint == s0.plan.color, "; one far from any sign takes none: ", far_tint.a == 0.0, "  ok: ", near_tint == s0.plan.color and far_tint.a == 0.0)
    quit()
