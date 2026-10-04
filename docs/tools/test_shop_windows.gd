extends SceneTree
# Shop windows: every display (7 kinds of shop, several windows each) and the neon OPEN sign fit inside
# their 28 by 12 window, the shops on a street are of all kinds, and about one in three has the sign.
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_shop_windows.gd
const ShopWindows := preload("res://scripts/ShopWindows.gd")

func _fits(r: Array) -> bool:
    return r[0] >= 0.0 and r[1] <= ShopWindows.WIDTH and r[2] >= 0.0 and r[3] <= ShopWindows.HEIGHT and r[1] > r[0] and r[3] > r[2]

func _init() -> void:
    # 1. The displays are well formed and fit the window.
    var pieces := 0
    var outside := 0
    var empty := 0
    for theme in ShopWindows.THEMES:
        for n in 6:
            var d: Array = ShopWindows.display(theme, n)
            if d.size() < 6:
                empty += 1
            for r in d:
                pieces += 1
                if not _fits(r):
                    outside += 1
    var sign_ok := true
    var sign_pieces := 0
    for color in ShopWindows.NEON:
        for r in ShopWindows.neon_sign(color):
            sign_pieces += 1
            if not _fits(r):
                sign_ok = false
    # the windows of one shop differ from each other
    var differ := 0
    for theme in ShopWindows.THEMES:
        if str(ShopWindows.display(theme, 0)) != str(ShopWindows.display(theme, 1)):
            differ += 1
    print("1. ", ShopWindows.THEMES, " kinds of shop, ", pieces, " pieces over 6 windows each: outside the window ", outside, ", thin displays ", empty,
        "; the OPEN sign (", sign_pieces, " pieces over 3 colours) fits: ", sign_ok, "; windows 0 and 1 differ for ", differ, " kinds",
        "  ok: ", outside == 0 and empty == 0 and sign_ok and differ >= 5)

    # 2. On a real street: every kind of shop turns up, and about a third have the sign.
    var main = load("res://scenes/Main.tscn").instantiate()
    main.level_override = 1
    main.home_seed = 3
    main.traffic_enabled = false
    root.add_child(main)
    for i in 3:
        await process_frame
    var shops := 0
    var kinds := {}
    var signed := 0
    for b in main.building_nodes:
        if b.floors > 0 and b.shop and not b.house:
            shops += 1
            var seed_: int = int(b.rect.position.x * 0.37 + b.rect.position.y * 0.91) + b.variant
            kinds[ShopWindows.theme_for(seed_)] = true
            if ShopWindows.has_sign(seed_):
                signed += 1
    var share: float = float(signed) / float(maxi(shops, 1))
    print("2. ", shops, " shops, ", kinds.size(), " of ", ShopWindows.THEMES, " kinds, ", signed, " with the OPEN sign (", snappedf(share * 100.0, 1.0), "%)",
        "  ok: ", shops > 100 and kinds.size() == ShopWindows.THEMES and share > 0.2 and share < 0.5)
    quit()
