extends RefCounted
# Switches off the per-frame script of everything that is far from the action, and back on as it
# comes near. Cops, cats, street people, squirrels, pizza, fires, roof fans and flickering lamps all stand
# still (and cost nothing) when they are beyond NEAR_VIEW, but each of them was still having its
# `_process` called, hundreds of calls a frame, only to return at once (and the fires redrew
# themselves every frame, seen or not). Now they are not called at all.
#
# It works through each node's process_mode (DISABLED far away, INHERIT near), which is separate
# from set_process(): a node something has stopped on purpose (a test freezing a cop) stays stopped
# however near it is. Updated every quarter of a second, and at once if Nicole jumps somewhere far
# (a teleport). (Main owns one: `main.gate`.)

const OFF_BEYOND := 1000.0  # switched off past this distance from Nicole (NEAR_VIEW is 800)
const ON_WITHIN := 900.0    # and back on inside this, so nodes at the edge don't flicker on and off
const EVERY := 0.25
const JUMP := 100.0

var main
var since := 0.0
var last_at := Vector2(-1.0e9, -1.0e9)

func _init(game) -> void:
    main = game

# Called every frame; does its work a few times a second.
func tick(delta: float) -> void:
    since += delta
    var at: Vector2 = main.player.global_position
    if since < EVERY and at.distance_to(last_at) < JUMP:
        return
    since = 0.0
    last_at = at
    update()

func update() -> void:
    var at: Vector2 = main.player.global_position
    var off2: float = OFF_BEYOND * OFF_BEYOND
    var on2: float = ON_WITHIN * ON_WITHIN
    for list in [main.cops, main.cats, main.npcs, main.squirrels, main.pickups, main.fires, main.fans]:
        _gate(list, at, off2, on2, false)
    _gate(main.lamps, at, off2, on2, true)

func _gate(list: Array, at: Vector2, off2: float, on2: float, only_flickering: bool) -> void:
    for n in list:
        if not is_instance_valid(n):
            continue
        if only_flickering and not n.flicker:
            continue  # a steady lamp never had a per-frame script to switch
        var d2: float = n.global_position.distance_squared_to(at)
        if n.process_mode == Node.PROCESS_MODE_DISABLED:
            if d2 < on2:
                n.process_mode = Node.PROCESS_MODE_INHERIT
        elif d2 > off2:
            n.process_mode = Node.PROCESS_MODE_DISABLED
