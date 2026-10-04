extends SceneTree
# Every cop should keep making progress along its route (no getting wedged on
# bins, barrels or walls). The player is parked inside a building near each
# cop so it stays out of sight but the cop is within the active radius.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_patrols.gd

# Keep the player out of sight inside the nearest building, so the cop stays active.
func _park(main, cop) -> void:
    var best := Vector2.ZERO
    var best_d := INF
    for b in main.buildings:
        var d: float = b.get_center().distance_to(cop.global_position)
        if d < best_d:
            best_d = d
            best = b.get_center()
    main.player.global_position = best
    main.dog.global_position = best

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    var bad := 0
    for cat in main.cats:
        cat.set_process(false)
    for npc in main.npcs:
        npc.set_process(false)  # measure patrol progress without street shouts
    main.dog.set_process(false)
    main.player.set_process(false)
    # the first tile's ten cops, plus one from each other tile (the rest repeat them)
    var sample: Array = []
    for ci in main.cops.size():
        if ci < 10 or ci % 10 == 3:
            sample.append(ci)
    for ci in sample:
        var cop = main.cops[ci]
        for other in main.cops:
            other.set_process(other == cop)
        _park(main, cop)
        var seen: Dictionary = {}
        var last_move := 0
        var last_pos: Vector2 = cop.global_position
        var last_waypoint: int = cop.wp_i
        var walked := 0.0
        var worst_still := 0
        var still := 0
        for f in 3600:
            await process_frame
            if f % 30 == 0:
                _park(main, cop)
            seen[cop.wp_i] = true
            var moved: float = cop.global_position.distance_to(last_pos)
            walked += moved
            # Cop._step_toward treats >0.01 units as progress. Slow slides along
            # furniture are movement; still require every waypoint within a minute.
            # Advancing past a blocked waypoint is intentional recovery, not a
            # frozen AI. Also require real movement, so skipping every target fails.
            if moved <= 0.01 and cop.wp_i == last_waypoint and cop.wait <= 0.0 and cop.state == cop.State.PATROL:
                still += 1
            else:
                still = 0
            worst_still = maxi(worst_still, still)
            last_pos = cop.global_position
            last_waypoint = cop.wp_i
            if main.state != "play":
                break
        var ok: bool = seen.size() == cop.waypoints.size() and worst_still < 90 and walked > 100.0
        if not ok:
            bad += 1
            print("failed patrol: game ", main.state, " cop state ", cop.state, " processing ", cop.can_process(),
                " distance to player ", cop.global_position.distance_to(main.player.global_position))
        print("cop ", ci, " route targets visited ", seen.size(), "/", cop.waypoints.size(), " walked ", snappedf(walked, 0.1),
            " longest stall frames ", worst_still, " ", "ok" if ok else "STUCK at ", "" if ok else str(cop.global_position))
    print("stuck cops: ", bad, "  ok: ", bad == 0)
    quit()
