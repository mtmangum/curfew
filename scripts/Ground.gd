extends RefCounted
# The ground, drawn flat in world coordinates (the isometric shear makes it a diamond
# grid). Two kinds of node: one big Floor under everything (asphalt, a faint grid, the
# glowing patch in front of the front door, pavements for the scenery ring), and one
# TileGround per tile with that tile's pavements, plazas, lane markings and
# crosswalks. Per-tile nodes mean tiles off screen cost nothing to draw.

const LevelData := preload("res://scripts/LevelData.gd")
const Sprites := preload("res://scripts/Sprites.gd")

const PAVEMENT := Color("262b3b")
const PAVEMENT_EDGE := Color("3a4056")
const PAVERS := Color("2c3042")
const YELLOW := Color(0.80, 0.66, 0.27, 0.85)
const WHITE := Color(0.88, 0.9, 0.95, 0.5)

class Floor extends Node2D:
    var main

    func _draw() -> void:
        var wr: Rect2 = main.world_rect
        # The street carries on under the scenery blocks around the playable area.
        var floor: Rect2 = wr.grow(main.DECOR_MARGIN + 500.0)
        draw_rect(floor, Color("141824"))
        for r in main.decor:
            draw_rect(r.grow(10), Color("262b3b"))
        draw_rect(main.home_zone, Color(1.0, 0.85, 0.4, 0.22))
        for x in range(int(floor.position.x / 40.0) * 40, int(floor.end.x) + 1, 40):
            draw_line(Vector2(x, floor.position.y), Vector2(x, floor.end.y), Color(1, 1, 1, 0.02), 1.0)
        for y in range(int(floor.position.y / 40.0) * 40, int(floor.end.y) + 1, 40):
            draw_line(Vector2(floor.position.x, y), Vector2(floor.end.x, y), Color(1, 1, 1, 0.02), 1.0)
        for r in main.decor:
            Sprites.outline(self, r.grow(10), Color("3a4056"), 1.0)
        Sprites.outline(self, main.home_zone, Color(1.0, 0.85, 0.4, 0.55), 1.0)

class TileGround extends Node2D:
    var builder      # LevelBuilder, for tile mapping
    var tx := 0
    var ty := 0

    func _draw() -> void:
        var origin := Vector2(float(tx), float(ty)) * LevelData.TILE
        # Godot merges runs of the same kind of drawing into one draw call, so this is drawn in
        # runs: every pavement and plaza fill, then every line (edges, paver grid, lane markings),
        # then the crossings' bars. (One block at a time would break a run at every step.)
        var blocks: Array = []
        for b in LevelData.blocks():
            blocks.append([builder._tr(b.rect, tx, ty), b.plaza])
        for e in blocks:
            draw_rect(e[0], PAVEMENT)
        for e in blocks:
            if e[1]:
                draw_rect(e[0].grow(-LevelData.WALK), PAVERS)
        for e in blocks:
            Sprites.outline(self, e[0], PAVEMENT_EDGE, 1.5)
        for e in blocks:
            if e[1]:
                _pavers(e[0].grow(-LevelData.WALK))
        # Lane markings along every road, broken at the junctions.
        for road in LevelData.roads():
            _mark_road(road, origin)
        # Zebra crossings on every arm of every junction.
        for rx in LevelData.ROADS_X:
            for ry in LevelData.ROADS_Y:
                _crossings(Vector2(rx[0], ry[0]) + origin, rx[1], ry[1])
        if float(builder.main.settings.rain) > 0.0:
            for road in LevelData.roads():
                _puddles(road, origin)

    # The faint grid of paving stones in a plaza.
    func _pavers(inner: Rect2) -> void:
        var x := inner.position.x
        while x < inner.end.x:
            draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(1, 1, 1, 0.04), 1.0)
            x += 24.0
        var y := inner.position.y
        while y < inner.end.y:
            draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.04), 1.0)
            y += 24.0

    # Rain: puddles lying on the asphalt along every road, each with a pale sheen.
    func _puddles(road: Dictionary, origin: Vector2) -> void:
        var horizontal: bool = road.horizontal
        var c: float = road.centre
        var length: float = LevelData.TILE.x if horizontal else LevelData.TILE.y
        var half: float = _half(148.0 if road.avenue else 114.0) - 8.0
        var k := 0
        var t := 30.0
        while t < length - 30.0:
            k += 1
            var h: int = (k * 7919 + int(c) * 131 + (1 if horizontal else 2) * 17) % 97
            if h < 38:
                var off: float = (float(h % 11) / 10.0 - 0.5) * 2.0 * half
                var rx: float = 7.0 + float(h % 9)
                var ry: float = 3.5 + float(h % 5)
                var at: Vector2 = origin + (Vector2(t, c + off) if horizontal else Vector2(c + off, t))
                _ellipse(at, rx, ry, Color(0.17, 0.26, 0.38, 0.6))
                _ellipse(at + Vector2(-rx * 0.15, -ry * 0.25), rx * 0.55, ry * 0.45, Color(0.62, 0.74, 0.88, 0.2))
            t += 46.0 + float(h % 40)

    func _ellipse(at: Vector2, rx: float, ry: float, col: Color) -> void:
        Sprites.ellipse(self, at, rx, ry, col)

    # The asphalt half-width of a road (its width less both pavements).
    func _half(width: float) -> float:
        return width * 0.5 - LevelData.WALK

    # Dashes along a road, skipping the junctions.
    func _mark_road(road: Dictionary, origin: Vector2) -> void:
        var horizontal: bool = road.horizontal
        var c: float = road.centre
        var length: float = LevelData.TILE.x if horizontal else LevelData.TILE.y
        var crossing: Array = LevelData.ROADS_X if horizontal else LevelData.ROADS_Y
        var spans: Array = []  # stretches of this road between junctions
        var start := 0.0
        var cuts: Array = []
        for cr in crossing:
            cuts.append([cr[0] - _half(cr[1]) - 24.0, cr[0] + _half(cr[1]) + 24.0])
        cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
        for cut in cuts:
            if cut[0] > start:
                spans.append([start, minf(cut[0], length)])
            start = maxf(start, cut[1])
        if start < length:
            spans.append([start, length])
        for s in spans:
            if road.avenue:
                # double yellow down the middle, white dashes between same-way lanes
                _line(horizontal, c - 1.8, s[0], s[1], origin, YELLOW, 1.4, 0.0, 0.0)
                _line(horizontal, c + 1.8, s[0], s[1], origin, YELLOW, 1.4, 0.0, 0.0)
                _line(horizontal, c - 28.0, s[0], s[1], origin, WHITE, 1.2, 14.0, 20.0)
                _line(horizontal, c + 28.0, s[0], s[1], origin, WHITE, 1.2, 14.0, 20.0)
            else:
                # broken yellow between the two lanes; a solid white line by the parking
                _line(horizontal, c + 13.0, s[0], s[1], origin, YELLOW, 1.4, 16.0, 16.0)
                _line(horizontal, c - 13.0, s[0], s[1], origin, WHITE, 1.1, 0.0, 0.0)

    # One marking along a road at offset `off` from its centre line; dashed if dash > 0.
    func _line(horizontal: bool, off: float, a: float, b: float, origin: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
        var t := a
        while t < b:
            var e: float = b if dash <= 0.0 else minf(t + dash, b)
            if horizontal:
                draw_line(origin + Vector2(t, off), origin + Vector2(e, off), color, width)
            else:
                draw_line(origin + Vector2(off, t), origin + Vector2(off, e), color, width)
            if dash <= 0.0:
                break
            t = e + gap

    # Zebra bars across each of the four arms of a junction.
    func _crossings(centre: Vector2, vertical_road_width: float, horizontal_road_width: float) -> void:
        var vh: float = _half(vertical_road_width)    # the vertical road is vertical_road_width wide
        var hh: float = _half(horizontal_road_width)
        var col := Color(0.9, 0.92, 0.96, 0.32)
        # West and east arms cross the horizontal road: bars run along x, stacked in y.
        for side in [-1.0, 1.0]:
            var x0: float = centre.x + side * (vh + 8.0) - (14.0 if side < 0.0 else 0.0)
            var y := centre.y - hh + 3.0
            while y < centre.y + hh - 3.0:
                draw_rect(Rect2(x0, y, 14.0, 5.0), col)
                y += 10.0
        # North and south arms cross the vertical road: bars run along y, side by side in x.
        for side in [-1.0, 1.0]:
            var y0: float = centre.y + side * (hh + 8.0) - (14.0 if side < 0.0 else 0.0)
            var x := centre.x - vh + 3.0
            while x < centre.x + vh - 3.0:
                draw_rect(Rect2(x, y0, 5.0, 14.0), col)
                x += 10.0
