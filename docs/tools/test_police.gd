extends SceneTree
# Police cars (level 3 and up): the level settings; what a car can see; that it stays on the road's lanes
# whether it cruises or chases; that in a chase it turns corners to get to her; and that when it reaches her a cop
# gets out on foot (and leaves again some seconds after he gives up), while the car waits and then cruises on.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_police.gd
const LevelSettings := preload("res://scripts/LevelSettings.gd")

func _on_lane(main, car) -> bool:
    for l in main.traffic_director.lanes:
        if l.horizontal == car.horizontal:
            var across: float = car.position.y if car.horizontal else car.position.x
            if absf(l.fixed - across) < 1.5:
                return true
    return false

func _init() -> void:
    # 1. How many police cars each level has.
    var counts := []
    for n in [1, 2, 3, 4, 5, 7]:
        counts.append(int(LevelSettings.for_level(n).police))
    print("1. police cars on levels 1,2,3,4,5,7: ", counts, "  ok: ", counts == [0, 0, 2, 3, 4, 4])

    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 3
    main.home_seed = 3
    root.add_child(main)
    for i in 3:
        await process_frame
    main.state = "play"
    for c in main.cops:
        c.set_process(false)
    main.dog.set_process(false)
    main.player.set_process(false)
    var director = main.traffic_director
    director.enabled = false
    for car in main.traffic.duplicate():
        main.traffic.erase(car)
        car.queue_free()
    var lane: Dictionary = {}
    for l in director.lanes:
        if l.horizontal and l.dir == 1 and l.outer:
            lane = l
            break
    var along0: float = float(lane.a) + 700.0
    var Y: float = lane.fixed

    # 2. What it can see: on the road ahead, or close; not far behind it, and not at all when she is hidden in steam.
    var car = director.spawn_police(lane, along0, true)
    main.player.global_position = Vector2(along0 + 200.0, Y)
    var ahead: bool = car.sees(main.player.global_position)
    main.player.global_position = Vector2(along0 - 100.0, Y)
    var near_behind: bool = car.sees(main.player.global_position)
    main.player.global_position = Vector2(along0 - 300.0, Y)
    var far_behind: bool = car.sees(main.player.global_position)
    main.player.global_position = Vector2(along0 + 600.0, Y)
    var too_far: bool = car.sees(main.player.global_position)
    print("2. sees her 200 ahead: ", ahead, ", 100 behind (close): ", near_behind, ", 300 behind: ", far_behind, ", 600 ahead (too far): ", too_far,
        "  ok: ", ahead and near_behind and not far_behind and not too_far)

    # 3. Cruising: 15 seconds along the road, never off a lane.
    main.player.global_position = Vector2(along0, Y + 1000.0)  # too far to be seen (420), near enough for the car to be simulated (1350)
    car.speed = car.PATROL_SPEED
    var off := 0
    var moved := 0.0
    var last: Vector2 = car.position
    var left_the_map := false
    seed(11)  # its turns are random: a turn north or south from this lane can end at the edge of the world, where it is removed
    for i in 900:
        if not is_instance_valid(car):
            left_the_map = true
            break
        main.player.global_position = car.position + Vector2(0.0, 700.0)  # trails it, out of its sight
        await physics_frame
        if is_instance_valid(car):
            moved += car.position.distance_to(last)
            last = car.position
            if not _on_lane(main, car):
                off += 1
    print("3. cruising for 15 s: drove ", snappedf(moved, 1.0), ", frames off its lane ", off, ", left the map at an edge (fine) ", left_the_map, "  ok: ", (moved > 600.0 or left_the_map) and off == 0)
    if is_instance_valid(car):
        main.traffic.erase(car)
        car.queue_free()

    # 4. A chase: Nicole on the pavement of a crossing road, ahead and to the side: the car turns the corner onto it,
    # stays on lanes, and gets to her; then it stops and a cop gets out and runs at her.
    var xr := 0.0
    for r in director.road_xs:
        if r.centre >= along0 + 400.0 and r.centre <= along0 + 1200.0:
            xr = r.centre
            break
    var chase_car = director.spawn_police(lane, along0, true)
    if xr == 0.0:
        print("no crossing road in range")
        quit()
        return
    var target := Vector2(xr + 80.0, Y + 330.0)
    main.player.global_position = target
    main.dog.global_position = target + Vector2(10, 6)
    chase_car._start_chase(target)
    var turned := false
    var off2 := 0
    var start_d: float = chase_car.position.distance_to(target)
    var frames := 0
    while frames < 1200 and chase_car.mode != chase_car.Mode.STOPPED and main.state == "play":
        await physics_frame
        frames += 1
        if not chase_car.horizontal:
            turned = true
        if not _on_lane(main, chase_car):
            off2 += 1
    var dropped: bool = main.cops.any(func(c): return is_instance_valid(c) and c.drop and c.state == c.State.CHASE)
    var end_d: float = chase_car.position.distance_to(target)
    print("4. chase: ", frames, " frames, turned the corner ", turned, ", frames off a lane ", off2, ", distance to her ", snappedf(start_d, 1.0), " -> ", snappedf(end_d, 1.0),
        ", stopped ", chase_car.mode == chase_car.Mode.STOPPED, ", a cop got out chasing ", dropped,
        "  ok: ", turned and off2 == 0 and end_d < chase_car.DROP_DIST + 5.0 and chase_car.mode == chase_car.Mode.STOPPED and dropped)

    # 5. The cop leaves some seconds after he gives up, and the car cruises on after its wait.
    var cop = null
    for c in main.cops:
        if is_instance_valid(c) and c.drop:
            cop = c
    if cop == null:
        print("5. no cop got out  ok: false")
        quit()
        return
    main.state = "play"
    main.player.global_position = target + Vector2(500.0, 500.0)  # near enough for him to be simulated, too far to see
    cop.set_process(true)
    cop.state = cop.State.PATROL
    cop.exposure = 0.0
    cop.drop_t = 2.9
    chase_car.stop_t = 0.2
    for i in 40:
        await physics_frame
    print("5. the cop has left: ", not is_instance_valid(cop) or not main.cops.has(cop), "; the car cruises on again: ", chase_car.mode == chase_car.Mode.PATROL,
        "  ok: ", (not is_instance_valid(cop) or not main.cops.has(cop)) and chase_car.mode == chase_car.Mode.PATROL)
    quit()
