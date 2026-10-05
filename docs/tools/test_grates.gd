extends SceneTree
# Tree grates: every tree has exactly one iron grate inside a plaza, clear of the sidewalk
# and road, and drawn by the ground tile
# (so anyone walking past stands over it, not under the tree).
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_grates.gd
const GrateScript := preload("res://scripts/Grate.gd")
const LevelData := preload("res://scripts/LevelData.gd")

func _init() -> void:
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 3
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    var tiles: Array = main.get_children().filter(func(c): return c.has_method("tree_grates"))
    var total := 0
    var spilling := 0
    var smallest := 1.0e9
    var biggest := 0.0
    var bigger := 0
    var misplaced := 0
    var sidewalk_trees := 0
    var seen := {}
    for tile in tiles:
        var pavements: Array = tile.blocks()
        for g in tile.tree_grates():
            total += 1
            var c: Vector2 = g[0]
            var half: float = g[1]
            seen[c] = int(seen.get(c, 0)) + 1
            smallest = minf(smallest, half)
            biggest = maxf(biggest, half)
            if half > GrateScript.MIN + 0.01:
                bigger += 1
            var square := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
            var on_pavement := false
            for e in pavements:
                if e[0].encloses(square):
                    on_pavement = true
            if not on_pavement:
                spilling += 1
            if not main.trees.has(c):
                misplaced += 1
            var inside_plaza := false
            for e in pavements:
                if e[1] and e[0].grow(-LevelData.WALK).encloses(square):
                    inside_plaza = true
            if not inside_plaza:
                sidewalk_trees += 1
    var every_tree_once := true
    for t in main.trees:
        if int(seen.get(t, 0)) != 1:
            every_tree_once = false
    print("1. ", main.trees.size(), " trees, ", total, " grates in ", tiles.size(), " tiles (each tree exactly once: ", every_tree_once, "), half-sides ", snappedf(smallest, 0.1), " to ", snappedf(biggest, 0.1),
        ", ", bigger, " bigger than the smallest, spilling off the pavement ", spilling, ", not at a tree ", misplaced,
        ", sidewalk trees ", sidewalk_trees,
        "  ok: ", total == main.trees.size() and every_tree_once and spilling == 0 and misplaced == 0 and sidewalk_trees == 0 and smallest >= GrateScript.MIN - 0.01 and biggest <= GrateScript.MAX + 0.01 and bigger > 20)
    quit()
