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
    root.add_child(main)
    for i in 3:
        await process_frame
    var bad := 0
    for cat in main.cats:
        cat.set_process(false)
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
        var worst_still := 0
        var still := 0
        for f in 3600:
            await process_frame
            if f % 30 == 0:
                _park(main, cop)
            seen[cop.wp_i] = true
            if cop.global_position.distance_to(last_pos) < 0.02 and cop.wait <= 0.0 and cop.state == cop.State.PATROL:
                still += 1
            else:
                still = 0
            worst_still = maxi(worst_still, still)
            last_pos = cop.global_position
            if main.state != "play":
                break
        var ok: bool = seen.size() == cop.waypoints.size() and worst_still < 90
        if not ok:
            bad += 1
        print("cop ", ci, " waypoints reached ", seen.size(), "/", cop.waypoints.size(),
            " longest stall frames ", worst_still, " ", "ok" if ok else "STUCK at ", "" if ok else str(cop.global_position))
    print("stuck cops: ", bad)
    quit()
