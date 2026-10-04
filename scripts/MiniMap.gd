extends Control
# A small map for the corner of the screen. It only knows what Nicole has seen: the
# streets and buildings near wherever she has been are revealed as she walks, and the
# rest stays dark.
#
# Home is not marked at all until she finds it: no ring, no distance. She has to explore, or
# follow Stella when she catches the scent of home (Dog.gd). Once she has seen the house, or
# got near enough to, it appears on the map with its distance. A call from a phone booth fills
# in the area round it (see PhoneBooth.gd) but does not mark home.
#
# Things she has seen are remembered on the map: pizza slices, steam vents and phone
# booths where she has been near them, and the last place she saw each cop (a mark that
# fades in ten seconds, and never through a wall). It never shows where anyone is right now.
#
# After a lost run the explored map and what she learned about home carry over to the
# next try (export_state / import_state, kept by Main).

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

const CELL := 64.0       # size of one explored cell, in world units
const REVEAL := 380.0    # how far around Nicole is revealed as she walks
const MAP_SIZE := Vector2(280, 118)
const CAPTION_H := 18.0  # room under the map for the caption

const FOUND_DIST := 260.0   # this close (or having seen the house) and home is pinned
const COP_MARK_SECONDS := 10.0   # a mark fades quickly: it is where she last saw him, not where he is
const COP_SPOT_RANGE := 260.0

const BG := Color(0.03, 0.04, 0.07, 0.86)
const STREET := Color(0.17, 0.21, 0.31)
const BLOCK := Color(0.33, 0.38, 0.54)
const BORDER := Color("5d6784")
const GOLD := Color("ffd27a")
const PIZZA := Color("ffcf4a")
const VENT := Color("7fd4ff")
const BOOTH := Color("72ebff")
const COP := Color("ff5a4d")

var main
var origin := Vector2.ZERO
var factor := 1.0
var cols := 0
var rows := 0
var seen := PackedByteArray()
var seen_cells: Array = []  # [x, y] of every revealed cell, so drawing skips the empty ones
var last_cell := Vector2i(-99999, -99999)
var tick := 0.0
var home_best := INF        # the closest she has been to home
var cop_marks := {}         # cop id -> {pos, t}: where she last saw him

func setup(game) -> void:
    main = game
    origin = main.world_rect.position
    factor = MAP_SIZE.x / main.world_rect.size.x
    cols = ceili(main.world_rect.size.x / CELL)
    rows = ceili(main.world_rect.size.y / CELL)
    seen.resize(cols * rows)
    custom_minimum_size = Vector2(MAP_SIZE.x, MAP_SIZE.y + CAPTION_H)
    size = custom_minimum_size
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _reveal(true)

# Map coordinates (pixels from the map's top-left) of a point in the world.
func to_map(p: Vector2) -> Vector2:
    return ((p - origin) * factor).round()

func _cell_index(cx: int, cy: int) -> int:
    return cy * cols + cx

func is_seen(p: Vector2) -> bool:
    var cx := floori((p.x - origin.x) / CELL)
    var cy := floori((p.y - origin.y) / CELL)
    if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
        return false
    return seen[_cell_index(cx, cy)] == 1

# --- What she knows about home ------------------------------------------------------------
func home_pos() -> Vector2:
    return main.home_zone.get_center()

func home_found() -> bool:
    return home_best <= FOUND_DIST or is_seen(home_pos())

# A phone call: the map fills in round the booth. (It does not say where home is.)
func phone_call(at: Vector2) -> void:
    _reveal_around(at, 600.0)
    queue_redraw()

# --- Exploring --------------------------------------------------------------------------
func _reveal_around(pos: Vector2, radius: float) -> void:
    var here := Vector2i(floori((pos.x - origin.x) / CELL), floori((pos.y - origin.y) / CELL))
    var span: int = ceili(radius / CELL)
    for dy in range(-span, span + 1):
        for dx in range(-span, span + 1):
            var cx: int = here.x + dx
            var cy: int = here.y + dy
            if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
                continue
            if Vector2(float(dx), float(dy)).length() * CELL > radius:
                continue
            var i: int = _cell_index(cx, cy)
            if seen[i] == 0:
                seen[i] = 1
                seen_cells.append([cx, cy])

# Reveal every cell within REVEAL of Nicole, if she has moved to a new cell.
func _reveal(force: bool = false) -> void:
    var pos: Vector2 = main.player.global_position if main.player != null else main.START
    var here := Vector2i(floori((pos.x - origin.x) / CELL), floori((pos.y - origin.y) / CELL))
    if here == last_cell and not force:
        return
    last_cell = here
    _reveal_around(pos, REVEAL)
    queue_redraw()

func _note_cops(now: float) -> void:
    var me: Vector2 = main.player.global_position
    for c in main.cops:
        var d: float = c.global_position.distance_to(me)
        if d < COP_SPOT_RANGE and main.los(c.global_position, me):  # only a cop she can actually see
            cop_marks[c.get_instance_id()] = {"pos": c.global_position, "t": now}
    for id in cop_marks.keys():
        if now - cop_marks[id].t > COP_MARK_SECONDS:
            cop_marks.erase(id)

func _process(delta: float) -> void:
    if main == null or main.player == null:
        return
    _reveal()
    home_best = minf(home_best, main.player.global_position.distance_to(home_pos()))
    tick += delta
    if tick >= 0.12:  # the dot moves, the markers pulse, the cop marks fade
        tick = 0.0
        _note_cops(Time.get_ticks_msec() / 1000.0)
        queue_redraw()

# --- Keeping the map for the next try --------------------------------------------------------
func export_state() -> Dictionary:
    return {"seen": seen.duplicate(), "home_best": home_best}

func import_state(state: Dictionary) -> void:
    if state.is_empty() or state.seen.size() != seen.size():
        return
    seen = state.seen.duplicate()
    seen_cells.clear()
    for cy in rows:
        for cx in cols:
            if seen[_cell_index(cx, cy)] == 1:
                seen_cells.append([cx, cy])
    home_best = state.home_best
    queue_redraw()

# --- Drawing ------------------------------------------------------------------------------
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), BG)
    # Revealed ground.
    var cell_px: float = CELL * factor
    for c in seen_cells:
        var p: Vector2 = to_map(origin + Vector2(float(c[0]), float(c[1])) * CELL)
        draw_rect(Rect2(p, Vector2(ceilf(cell_px) + 0.5, ceilf(cell_px) + 0.5)), STREET)
    # Buildings, but only those that have been seen. The house shows in gold once it has.
    for r in main.buildings:
        if not is_seen(r.get_center()):
            continue
        var tl: Vector2 = to_map(r.position)
        var br: Vector2 = to_map(r.end)
        var col: Color = GOLD if r == main.house else BLOCK
        draw_rect(Rect2(tl, Vector2(maxf(br.x - tl.x, 2.0), maxf(br.y - tl.y, 2.0))), col)

    _draw_things()
    _draw_home()

    # Nicole.
    var me: Vector2 = to_map(main.player.global_position)
    draw_circle(me, 3.2, Color(0, 0, 0, 0.9))
    draw_circle(me, 2.2, Color("ff6f9a"))

    draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), BORDER, false, 2.0)
    _draw_caption()

# Things she has seen: pizza, steam vents, phone booths, and cops where she last saw them.
func _draw_things() -> void:
    for v in main.vents:
        if is_seen(v.global_position):
            var p: Vector2 = to_map(v.global_position)
            draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), VENT)
    for ph in main.phones:
        if not ph.used and is_seen(ph.global_position):
            var p: Vector2 = to_map(ph.global_position)
            draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0, 0.8))
            draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), BOOTH)
    for pz in main.pickups:
        if is_seen(pz.global_position):
            var p: Vector2 = to_map(pz.global_position)
            Sprites.fill(self, PackedVector2Array([p + Vector2(-2.5, -2), p + Vector2(2.5, -2), p + Vector2(0, 3)]), Color(0, 0, 0, 0.8))
            Sprites.fill(self, PackedVector2Array([p + Vector2(-1.6, -1.2), p + Vector2(1.6, -1.2), p + Vector2(0, 1.8)]), PIZZA)
    var now: float = Time.get_ticks_msec() / 1000.0
    for id in cop_marks:
        var m: Dictionary = cop_marks[id]
        var fade: float = clampf(1.0 - (now - m.t) / COP_MARK_SECONDS, 0.0, 1.0)
        var p2: Vector2 = to_map(m.pos)
        draw_circle(p2, 2.4, Color(0, 0, 0, 0.6 * fade))
        draw_circle(p2, 1.6, Color(COP.r, COP.g, COP.b, 0.25 + 0.65 * fade))

# Home is on the map only once she has found it.
func _draw_home() -> void:
    if not home_found():
        return
    var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
    var home: Vector2 = to_map(home_pos())
    draw_arc(home, 5.0 + 2.5 * pulse, 0.0, TAU, 20, Color(GOLD.r, GOLD.g, GOLD.b, 0.45 + 0.4 * pulse), 1.0)
    draw_rect(Rect2(home + Vector2(-3, -1), Vector2(6, 4)), GOLD)
    Sprites.fill(self, PackedVector2Array([home + Vector2(-4, -1), home + Vector2(4, -1), home + Vector2(0, -4)]), GOLD)

# Under the map: the distance to home once it has been found, and nothing before that.
func _draw_caption() -> void:
    if not home_found():
        return
    var me: Vector2 = main.player.global_position
    var text: String = "HOME  %d m" % int(round(me.distance_to(home_pos()) / 100.0) * 10.0)
    var font: Font = Style.BODY_FONT
    var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    var at := Vector2(MAP_SIZE.x - width, MAP_SIZE.y + 15.0)
    draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Style.OUTLINE)
    draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
