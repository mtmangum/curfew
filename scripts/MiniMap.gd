extends Control
# A small map for the corner of the screen. It only knows what Nicole has seen: the
# streets and buildings near wherever she has been are revealed as she walks, and the
# rest stays dark.
#
# Home is not marked at the start. The map shows a ring somewhere in the right part of
# town, and the ring tightens as she gets closer (it never grows back), until she is near
# enough to see the house and it appears. A call from a phone booth fills in the area
# round it and marks home outright (see PhoneBooth.gd).
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
const RING_MAX := 760.0     # world units: the ring at the start
const RING_RATE := 0.55     # ring radius per unit of distance still to go beyond FOUND_DIST
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
var home_best := INF        # the closest she has been to home (or the booth call's answer)
var decoy := Vector2.ZERO   # the ring is centred off to this side of home, so it doesn't give it away
var cop_marks := {}         # cop id -> {pos, t}: where she last saw him

func setup(game) -> void:
    main = game
    origin = main.world_rect.position
    factor = MAP_SIZE.x / main.world_rect.size.x
    cols = ceili(main.world_rect.size.x / CELL)
    rows = ceili(main.world_rect.size.y / CELL)
    seen.resize(cols * rows)
    decoy = Vector2.from_angle(fposmod(float(main.home_seed) * 2.399963, TAU))
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

# The ring that stands in for home until it is found: [centre, radius] in world units.
func ring() -> Array:
    var r: float = clampf((home_best - FOUND_DIST) * RING_RATE, 0.0, RING_MAX)
    return [home_pos() + decoy * r * 0.5, r]

# A phone call: the map fills in round the booth and home is marked.
func phone_call(at: Vector2) -> void:
    _reveal_around(at, 600.0)
    home_best = minf(home_best, 120.0)
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
func _inside(p: Vector2) -> bool:
    return p.x >= 1.0 and p.y >= 1.0 and p.x <= MAP_SIZE.x - 1.0 and p.y <= MAP_SIZE.y - 1.0

func _clamp_to_map(p: Vector2, margin: float = 1.0) -> Vector2:
    return Vector2(clampf(p.x, margin, MAP_SIZE.x - margin), clampf(p.y, margin, MAP_SIZE.y - margin))

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
            draw_colored_polygon(PackedVector2Array([p + Vector2(-2.5, -2), p + Vector2(2.5, -2), p + Vector2(0, 3)]), Color(0, 0, 0, 0.8))
            draw_colored_polygon(PackedVector2Array([p + Vector2(-1.6, -1.2), p + Vector2(1.6, -1.2), p + Vector2(0, 1.8)]), PIZZA)
    var now: float = Time.get_ticks_msec() / 1000.0
    for id in cop_marks:
        var m: Dictionary = cop_marks[id]
        var fade: float = clampf(1.0 - (now - m.t) / COP_MARK_SECONDS, 0.0, 1.0)
        var p2: Vector2 = to_map(m.pos)
        draw_circle(p2, 2.4, Color(0, 0, 0, 0.6 * fade))
        draw_circle(p2, 1.6, Color(COP.r, COP.g, COP.b, 0.25 + 0.65 * fade))

func _draw_home() -> void:
    var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
    if home_found():
        var home: Vector2 = to_map(home_pos())
        draw_arc(home, 5.0 + 2.5 * pulse, 0.0, TAU, 20, Color(GOLD.r, GOLD.g, GOLD.b, 0.45 + 0.4 * pulse), 1.0)
        draw_rect(Rect2(home + Vector2(-3, -1), Vector2(6, 4)), GOLD)
        draw_colored_polygon(PackedVector2Array([home + Vector2(-4, -1), home + Vector2(4, -1), home + Vector2(0, -4)]), GOLD)
        return
    # Not found: a dashed ring over the part of town it is in.
    var rg: Array = ring()
    var centre: Vector2 = to_map(rg[0])
    var radius: float = maxf(rg[1] * factor, 3.0)
    var segments := 28
    for i in segments:
        if i % 2 == 1:
            continue
        var a0: float = TAU * float(i) / segments
        var a1: float = TAU * float(i + 1) / segments
        var p0: Vector2 = centre + Vector2.from_angle(a0) * radius
        var p1: Vector2 = centre + Vector2.from_angle(a1) * radius
        if _inside(p0) or _inside(p1):  # a dash running off the edge of the map is cut short
            draw_line(_clamp_to_map(p0), _clamp_to_map(p1), Color(GOLD.r, GOLD.g, GOLD.b, 0.5 + 0.4 * pulse), 1.5)
    # the question mark stays on the map even when the ring's centre is off it
    var q: Vector2 = _clamp_to_map(centre, 8.0)
    Style.draw_world_text(self, q + Vector2(-3, 5), "?", 14, Color(GOLD.r, GOLD.g, GOLD.b, 0.75 + 0.25 * pulse))

# Under the map: the exact distance once home is found, otherwise roughly which way and how far.
func _draw_caption() -> void:
    var text: String
    var me: Vector2 = main.player.global_position
    if home_found():
        text = "HOME  %d m" % int(round(me.distance_to(home_pos()) / 100.0) * 10.0)
    else:
        var rg: Array = ring()
        var to: Vector2 = rg[0] - me
        text = "HOME  ABOUT %d m %s" % [int(round(to.length() / 100.0) * 10.0), _compass(to)]
    var font: Font = Style.BODY_FONT
    var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    var at := Vector2(MAP_SIZE.x - width, MAP_SIZE.y + 15.0)
    draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Style.OUTLINE)
    draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)

# Map north is up the screen (towards smaller y).
func _compass(to: Vector2) -> String:
    var names := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
    var i: int = int(round(fposmod(to.angle(), TAU) / (TAU / 8.0))) % 8
    return names[i]
