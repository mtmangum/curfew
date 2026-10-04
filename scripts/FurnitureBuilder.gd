extends RefCounted
# Street furniture for LevelBuilder: along the pavements, in the alleys and in the plazas
# (dumpsters, crates, barricades, hydrants, mailboxes, benches, phone booths, trees, cones,
# planters and fountains), the squirrels at the trees, the zombies asleep in the plazas, and
# which phone booths work. (LevelBuilder owns one: `builder.furniture`.)

const LevelData := preload("res://scripts/LevelData.gd")
const Sprites := preload("res://scripts/Sprites.gd")
const LevelSettingsScript := preload("res://scripts/LevelSettings.gd")
const ObjectScript := preload("res://scripts/StreetObject.gd")
const NpcScript := preload("res://scripts/StreetNpc.gd")
const SquirrelScript := preload("res://scripts/Squirrel.gd")
const PhoneBoothScript := preload("res://scripts/PhoneBooth.gd")

const PHONE_WORKING_EVERY := 3  # one visible booth in three takes a call

var builder  # the LevelBuilder: tile mapping, spot checks, people
var main
var booth_objects: Array = []  # every phone booth on the street, working or not

func _init(owner_builder) -> void:
    builder = owner_builder
    main = owner_builder.main

# Most booths are scenery (dark); every few of the ones you can actually see still take a
# call. A booth with a building in front of it would show only its floating marker, so those
# are never the working ones.
func assign_phones() -> void:
    if not main.settings.phones:
        return  # a later level: nobody to ask the way, every booth is scenery
    var seen := 0
    var checked := 0
    for obj in booth_objects:
        checked += 1
        if checked % 12 == 0:
            await main.boot_step("city", 1.0)
        if _booth_hidden(obj):
            continue
        seen += 1
        if seen % PHONE_WORKING_EVERY != 1:
            continue
        obj.working = true
        var booth := PhoneBoothScript.new()
        booth.main = main
        booth.obj = obj
        main.actors.add_child(booth)
        booth.global_position = obj.rect.get_center()
        main.phones.append(booth)

# Is a booth covered, on the screen, by a building standing in front of it?
func _booth_hidden(obj) -> bool:
    var c: Vector2 = obj.rect.get_center()
    var foot: Vector2 = Sprites.iso(c)
    var body := Rect2(foot + Vector2(-9.0, -50.0), Vector2(18.0, 52.0))
    for b in main.building_nodes:
        if b is ObjectScript:
            continue
        var r: Rect2 = b.rect
        if c.x >= r.end.x or c.y >= r.end.y:
            continue  # beside it or in front of it
        if not b.screen_box.intersects(body):
            continue
        var poly: PackedVector2Array = b.silhouette()
        for z in [6.0, 24.0, 42.0]:
            if Geometry2D.is_point_in_polygon(foot + Vector2(0.0, -z), poly):
                return true
    return false

# Along the pavements, in the alleys and in the plazas.
func make_for(tx: int, ty: int, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> void:
    var K = ObjectScript.Kind
    var wide_kinds: Array = [K.HYDRANT, K.MAILBOX, K.BENCH, K.PHONE, K.TREE, K.CONES, K.PLANTER, K.BARRICADE]
    var narrow_kinds: Array = [K.HYDRANT, K.MAILBOX, K.PHONE, K.TREE]
    var n := 0
    # Pavements round each built block.
    for b in LevelData.blocks():
        if b.plaza:
            continue
        var r: Rect2 = builder._tr(b.rect, tx, ty)
        var x := 40.0
        while x < r.size.x - 70.0:
            for side in 2:
                n += 1
                if n % 7 >= 2:
                    continue
                var kind: int = wide_kinds[(n * 3 + side) % wide_kinds.size()]
                if float(main.settings.dressing) > 0.0 and kind in [K.CONES, K.PLANTER, K.BENCH, K.MAILBOX]:
                    kind = K.BARRICADE  # quarantine barriers along the pavements
                if kind == K.PHONE and side == 0:
                    kind = K.MAILBOX  # a booth on the far pavement would stand hidden behind the block's buildings
                elif side == 1 and n % 28 == 8:
                    kind = K.PHONE  # the near pavement, facing the street, is where they can be seen
                var sz: Vector2 = ObjectScript.size_of(kind)
                var yc: float = r.position.y + 9.0 if side == 0 else r.end.y - 9.0
                _add_object(Rect2(r.position.x + x, yc - sz.y * 0.5, sz.x, sz.y), kind, routes, tile_rect, first_lamp, first_obstacle)
            x += 85.0
        var y := 50.0
        while y < r.size.y - 60.0:
            for side in 2:
                n += 1
                if n % 9 >= 2:
                    continue
                var kind2: int = narrow_kinds[(n * 5 + side) % narrow_kinds.size()]
                var sz2: Vector2 = ObjectScript.size_of(kind2)
                var xc: float = r.position.x + 9.0 if side == 0 else r.end.x - 9.0
                _add_object(Rect2(xc - sz2.x * 0.5, r.position.y + y, sz2.x, sz2.y), kind2, routes, tile_rect, first_lamp, first_obstacle)
            y += 85.0
    # A fire hydrant on the pavement beside every other block, for Stella.
    var hb := 0
    for b in LevelData.blocks():
        if b.plaza:
            continue
        hb += 1
        if hb % 2 != 0:
            continue
        var rb: Rect2 = builder._tr(b.rect, tx, ty)
        var hsz: Vector2 = ObjectScript.size_of(K.HYDRANT)
        var hx: float = rb.position.x + 50.0 + float((hb * 37) % 70)
        var hy: float = rb.position.y + 9.0 if hb % 4 == 0 else rb.end.y - 9.0
        _add_object(Rect2(hx - hsz.x * 0.5, hy - hsz.y * 0.5, hsz.x, hsz.y), K.HYDRANT, routes, tile_rect, first_lamp, first_obstacle)
    # Dumpsters and crates in some alleys (the ones with a burn barrel stay clear).
    var alleys: Array = LevelData.alleys()
    for k in alleys.size():
        if k % 4 == 2 or k % 3 != 0:
            continue
        var a: Array = alleys[k]
        var z: Rect2 = a[2]
        var kind3: int = K.DUMPSTER if k % 2 == 0 else K.CRATES
        var base_sz: Vector2 = ObjectScript.size_of(kind3)
        var sz3 := Vector2(minf(base_sz.y, 18.0), base_sz.x) if kind3 == K.DUMPSTER else base_sz  # turned to run along the alley
        var centre: Vector2 = builder._tp(Vector2(a[0], z.position.y + 36.0), tx, ty)
        _add_object(Rect2(centre - sz3 * 0.5, sz3), kind3, routes, tile_rect, first_lamp, first_obstacle)
    # Plazas: a fountain in the middle, trees at the corners, benches and planters.
    for plaza in LevelData.plazas():
        _dress_plaza(plaza, tx, ty, routes, tile_rect, first_lamp, first_obstacle)

func _dress_plaza(base: Rect2, tx: int, ty: int, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> void:
    var K = ObjectScript.Kind
    var c: Vector2 = base.get_center()
    var items: Array = [
        [K.FOUNTAIN, c],
        [K.TREE, Vector2(base.position.x + 70.0, base.position.y + 60.0)],
        [K.TREE, Vector2(base.end.x - 70.0, base.position.y + 60.0)],
        [K.TREE, Vector2(base.position.x + 70.0, base.end.y - 60.0)],
        [K.TREE, Vector2(base.end.x - 70.0, base.end.y - 60.0)],
        [K.TREE, c + Vector2(-150.0, 0.0)],
        [K.TREE, c + Vector2(150.0, 0.0)],
        [K.BENCH, c + Vector2(-55.0, -62.0)],
        [K.BENCH, c + Vector2(55.0, 62.0)],
        [K.BENCH, c + Vector2(-55.0, 62.0)],
        [K.BENCH, c + Vector2(55.0, -62.0)],
        [K.PLANTER, c + Vector2(-210.0, -80.0)],
        [K.PLANTER, c + Vector2(210.0, 80.0)],
        [K.PLANTER, c + Vector2(-210.0, 80.0)],
        [K.PLANTER, c + Vector2(210.0, -80.0)],
    ]
    var benches: Array = []
    for it in items:
        var sz: Vector2 = ObjectScript.size_of(it[0])
        var p: Vector2 = builder._tp(it[1], tx, ty)
        var obj = _add_object(Rect2(p - sz * 0.5, sz), it[0], routes, tile_rect, first_lamp, first_obstacle)
        if obj != null and it[0] == K.BENCH:
            benches.append(obj)
        elif obj != null and it[0] == K.FOUNTAIN:
            fountain_count += 1
            if fountain_count % 3 == 1:
                obj.turn_off()  # one fountain in three is off, for variety
    _seat_zombies(builder._tp(c, tx, ty), benches)

# Zombies asleep in a plaza (from level 2): one laid out on a park bench and one slumped on the
# ground by the fountain, in about two plazas out of three.
var plaza_count := 0
var fountain_count := 0

func _seat_zombies(centre: Vector2, benches: Array) -> void:
    plaza_count += 1
    if float(main.settings.zombies) <= 0.0 or plaza_count % 3 == 0:
        return
    if not LevelSettingsScript.keeps(plaza_count, 5, float(main.settings.zombies)):
        return
    if not benches.is_empty():
        var bench = benches[plaza_count % benches.size()]
        var spot := Vector2(bench.rect.get_center().x, bench.rect.end.y + 7.5)  # just in front of the bench
        if builder._npc_spot_ok(spot):
            builder._add_npc(NpcScript.Kind.ZOMBIE, spot, "lie", bench)
    for off in [Vector2(0.0, 30.0), Vector2(-30.0, 12.0), Vector2(30.0, 12.0), Vector2(0.0, -30.0)]:
        if builder._npc_spot_ok(centre + off):
            builder._add_npc(NpcScript.Kind.ZOMBIE, centre + off, "sit")
            break

func _add_object(r: Rect2, kind: int, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> Node:
    if not _obstacle_spot_ok(r, routes, tile_rect, first_lamp, first_obstacle):
        return null
    main.obstacles.append(r)
    var obj := ObjectScript.new()
    obj.setup_object(r, kind, main.obstacles.size())
    main.actors.add_child(obj)
    main.building_nodes.append(obj)
    if kind == ObjectScript.Kind.FOUNTAIN:
        obj.main = main  # so the water can move while it is in view
    if kind == ObjectScript.Kind.PHONE:
        booth_objects.append(obj)  # which ones work is decided once every building is up (assign_phones)
    if kind == ObjectScript.Kind.HYDRANT:
        main.hydrants.append(obj)
    elif kind == ObjectScript.Kind.TREE:
        main.trees.append(r.get_center())
        if main.trees.size() % 4 == 0 and main.settings.squirrels:
            _add_squirrel(r.get_center())
    return obj

# A squirrel at the foot of a tree, on a spot clear of anything solid.
func _add_squirrel(tree_at: Vector2) -> void:
    for k in 8:
        var cand: Vector2 = tree_at + Vector2.from_angle(float(k) * TAU / 8.0 + 0.6) * 16.0
        if builder._npc_spot_ok(cand):
            var sq := SquirrelScript.new()
            sq.setup(main, tree_at, cand)
            main.actors.add_child(sq)
            sq.global_position = cand
            main.squirrels.append(sq)
            return

func _obstacle_spot_ok(r: Rect2, routes: Array, tile_rect: Rect2, first_lamp: int, first_obstacle: int) -> bool:
    if not tile_rect.grow(-16.0).encloses(r):
        return false
    for b in main.buildings:
        if b.intersects(r):
            return false
    for i in range(first_obstacle, main.obstacles.size()):
        if main.obstacles[i].grow(6.0).intersects(r):
            return false
    var c: Vector2 = r.get_center()
    if c.distance_to(main.START) < 70.0 or r.grow(30.0).intersects(main.home_zone):
        return false
    for i in range(first_lamp, main.lamps.size()):
        if main.lamps[i].global_position.distance_to(c) < r.size.x * 0.5 + 9.0:
            return false
    for p in main.props:
        if c.distance_to(p.global_position) < 22.0 + r.size.x * 0.4:
            return false
    for f in main.fires:
        if c.distance_to(f.global_position) < 34.0:
            return false
    for v in main.vents:
        if c.distance_to(v.global_position) < 30.0:
            return false
    for cat in main.cats:
        if r.grow(8.0).has_point(cat.global_position):
            return false
    return not builder._near_route(c, routes, 16.0 + minf(r.size.x, 20.0) * 0.4)
