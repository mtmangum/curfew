extends RefCounted
# The city plan: a regular grid of roads and blocks, written as plain numbers and a
# little code that turns them into building footprints, hazards and patrols. The
# world is a grid of these 2560x1440 districts (TILE_MIN..TILE_MAX); odd columns are
# mirrored left-to-right so the city doesn't repeat exactly (the road grid is
# symmetric, so mirroring never breaks it). LevelBuilder.gd turns the plan into the
# world; edit the numbers here to rearrange the streets.
#
# Everything is in "base tile" coordinates: 0..2560 across, 0..1440 down.

const TILE := Vector2(2560, 1440)
# The playable district is tiles (0..2, 0..1); the start is in a plaza in tile
# (0,1). A column to the west and a row to the south are quiet outskirts (buildings,
# cars and lamps, but no cops or cats), so the start has ground behind it. Tile
# coordinates can be negative; tile (0,0) sits at the world origin.
const TILE_MIN := Vector2i(-1, 0)
const TILE_MAX := Vector2i(2, 2)

# Roads. Avenues have four lanes, streets two plus a row of parking. Each entry is
# [centre line, total width including both pavements]. The pattern is the same
# across and down, and symmetric, so adjacent tiles join up.
const AVENUE := 148.0
const STREET := 114.0
const WALK := 18.0  # pavement width along every block
const ROADS_X := [[0.0, 148.0], [640.0, 114.0], [1280.0, 148.0], [1920.0, 114.0], [2560.0, 148.0]]
const ROADS_Y := [[0.0, 148.0], [360.0, 114.0], [720.0, 148.0], [1080.0, 114.0], [1440.0, 148.0]]

# Where in the base tile the start plaza is (block column 0, row 3, the bottom-left).
const PLAZA_COL := 0
const PLAZA_ROW := 3
# The start point inside it.
const START_BASE := Vector2(250.0, 1290.0)

static var _blocks: Array = []
static var _buildings: Array = []
static var _alleys: Array = []
static var _props: Array = []
static var _vents: Array = []
static var _fires: Array = []
static var _cats: Array = []
static var _routes: Array = []

# Plazas: a few blocks left open instead of built on.
static func is_plaza(col: int, row: int) -> bool:
    return (col * 5 + row * 3) % 7 == 2

# Every block: {rect, col, row, plaza}. The rect includes the pavement round it.
static func blocks() -> Array:
    if _blocks.is_empty():
        for i in 4:
            for j in 4:
                # A block runs from the kerb of one road to the kerb of the next, so it
                # includes its own pavement (the road's width counts both pavements).
                var x0: float = ROADS_X[i][0] + ROADS_X[i][1] * 0.5 - WALK
                var x1: float = ROADS_X[i + 1][0] - ROADS_X[i + 1][1] * 0.5 + WALK
                var y0: float = ROADS_Y[j][0] + ROADS_Y[j][1] * 0.5 - WALK
                var y1: float = ROADS_Y[j + 1][0] - ROADS_Y[j + 1][1] * 0.5 + WALK
                _blocks.append({"rect": Rect2(x0, y0, x1 - x0, y1 - y0), "col": i, "row": j, "plaza": is_plaza(i, j)})
    return _blocks

static func plazas() -> Array:
    var out: Array = []
    for b in blocks():
        if b.plaza:
            out.append(b.rect)
    return out

# Each built block is split into one to three buildings with narrow alleys between.
static func _plan_buildings() -> void:
    if not _buildings.is_empty():
        return
    var splits: Array = [[1.0], [0.5, 0.5], [0.34, 0.33, 0.33], [0.62, 0.38], [0.38, 0.62]]
    for b in blocks():
        if b.plaza:
            continue
        var zone: Rect2 = b.rect.grow(-WALK)
        var parts: Array = splits[(b.col * 7 + b.row * 13 + 3) % 5]
        var gap := 20.0
        var avail: float = zone.size.x - gap * float(parts.size() - 1)
        var x: float = zone.position.x
        for k in parts.size():
            var w: float = avail * float(parts[k])
            _buildings.append(Rect2(x, zone.position.y, w, zone.size.y))
            if k < parts.size() - 1:
                _alleys.append([x + w + gap * 0.5, b.rect, zone])
            x += w + gap

static func base_buildings() -> Array:
    _plan_buildings()
    return _buildings

# [x centre, block rect, building zone] for every alley between two buildings.
static func alleys() -> Array:
    _plan_buildings()
    return _alleys

# Bins sit on the pavement beside each alley mouth.
static func base_props() -> Array:
    if _props.is_empty():
        _plan_buildings()
        for k in _alleys.size():
            var a: Array = _alleys[k]
            var b: Rect2 = a[1]
            var y: float = b.position.y + 9.0 if k % 2 == 0 else b.end.y - 9.0
            _props.append(Vector2(a[0] + 16.0, y))
    return _props

# Steam vents in some pavement corners.
static func base_vents() -> Array:
    if _vents.is_empty():
        var n := 0
        for b in blocks():
            if (b.col * 5 + b.row * 3) % 4 == 1:
                continue
            var r: Rect2 = b.rect
            var cx: float = r.position.x + 12.0 if n % 2 == 0 else r.end.x - 12.0
            var cy: float = r.position.y + 11.0 if (n / 2) % 2 == 0 else r.end.y - 11.0
            _vents.append([Vector2(cx, cy), float(n) * 1.37 + 0.5])
            n += 1
    return _vents

# Burn barrels: one in the plaza away from the start, three in alleys.
static func base_fires() -> Array:
    if _fires.is_empty():
        _plan_buildings()
        for b in blocks():
            if b.plaza and not (b.col == PLAZA_COL and b.row == PLAZA_ROW):
                _fires.append(b.rect.get_center() + Vector2(-70.0, 30.0))
        var picked := 0
        for k in _alleys.size():
            if k % 4 == 2 and picked < 3:
                var a: Array = _alleys[k]
                var z: Rect2 = a[2]
                _fires.append(Vector2(a[0], z.get_center().y))
                picked += 1
    return _fires

# Cats start on the pavements and in plazas.
static func base_cats() -> Array:
    if _cats.is_empty():
        var n := 0
        for b in blocks():
            var r: Rect2 = b.rect
            if b.plaza:
                _cats.append(r.get_center() + Vector2(60.0, -40.0))
            else:
                var t: float = 0.2 + 0.6 * float((b.col * 3 + b.row * 5) % 7) / 6.0
                var y: float = r.position.y + 9.0 if n % 2 == 0 else r.end.y - 9.0
                _cats.append(Vector2(r.position.x + r.size.x * t, y))
            n += 1
    return _cats

# Patrols: a loop round the pavement of most blocks, clockwise, each starting at a
# different corner. None round the blocks next to the start plaza.
static func base_routes() -> Array:
    if _routes.is_empty():
        for b in blocks():
            if b.plaza:
                continue
            if (b.col * 7 + b.row * 11 + b.col * b.row * 3) % 5 >= 2:
                continue
            var r: Rect2 = b.rect.grow(-WALK * 0.5)
            var corners: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
            var start: int = (b.col + b.row * 2) % 4
            var loop: Array = []
            for k in 4:
                loop.append(corners[(start + k) % 4])
            _routes.append(loop)
    return _routes

# --- Roads --------------------------------------------------------------------------
# Every road in the base tile: {horizontal, centre, width, avenue}. The matching lanes
# come from lanes_of().
static func roads() -> Array:
    var out: Array = []
    for r in ROADS_Y:
        out.append({"horizontal": true, "centre": r[0], "width": r[1], "avenue": r[1] == AVENUE})
    for r in ROADS_X:
        out.append({"horizontal": false, "centre": r[0], "width": r[1], "avenue": r[1] == AVENUE})
    return out

# Offsets from a road's centre line to each driving lane's middle, with the
# direction (+1 along +x or +y, -1 the other way). Traffic keeps to the right:
# eastbound lanes are on the south of a horizontal road, southbound on the west of a
# vertical one.
static func lanes_of(horizontal: bool, avenue: bool) -> Array:
    if avenue:
        return [[-42.0, -1], [-14.0, -1], [14.0, 1], [42.0, 1]] if horizontal else [[-42.0, 1], [-14.0, 1], [14.0, -1], [42.0, -1]]
    return [[0.0, -1], [26.0, 1]] if horizontal else [[0.0, 1], [26.0, -1]]

# Offset to the middle of the parking lane on a street (north or west side).
const PARKING_OFFSET := -26.0
