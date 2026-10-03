extends Control
# A small map for the corner of the screen. It only knows what Nicole has seen: the
# streets and buildings near wherever she has been are revealed as she walks, and
# the rest stays dark. The one thing it always shows is where home is. It does not
# show cops or cats; she can't know where they are.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")

const CELL := 64.0       # size of one explored cell, in world units
const REVEAL := 380.0    # how far around Nicole is revealed as she walks
const MAP_SIZE := Vector2(280, 118)
const CAPTION_H := 18.0  # room under the map for the distance caption

const BG := Color(0.03, 0.04, 0.07, 0.86)
const STREET := Color(0.17, 0.21, 0.31)
const BLOCK := Color(0.33, 0.38, 0.54)
const BORDER := Color("5d6784")
const GOLD := Color("ffd27a")

var main
var origin := Vector2.ZERO
var factor := 1.0
var cols := 0
var rows := 0
var seen := PackedByteArray()
var seen_cells: Array = []  # [x, y] of every revealed cell, so drawing skips the empty ones
var last_cell := Vector2i(-99999, -99999)
var tick := 0.0

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

# Reveal every cell within REVEAL of Nicole, if she has moved to a new cell.
func _reveal(force: bool = false) -> void:
    var pos: Vector2 = main.player.global_position if main.player != null else main.START
    var here := Vector2i(floori((pos.x - origin.x) / CELL), floori((pos.y - origin.y) / CELL))
    if here == last_cell and not force:
        return
    last_cell = here
    var span: int = ceili(REVEAL / CELL)
    for dy in range(-span, span + 1):
        for dx in range(-span, span + 1):
            var cx: int = here.x + dx
            var cy: int = here.y + dy
            if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
                continue
            if Vector2(float(dx), float(dy)).length() * CELL > REVEAL:
                continue
            var i: int = _cell_index(cx, cy)
            if seen[i] == 0:
                seen[i] = 1
                seen_cells.append([cx, cy])
    queue_redraw()

func _process(delta: float) -> void:
    if main == null or main.player == null:
        return
    _reveal()
    tick += delta
    if tick >= 0.12:  # the dot moves and the home marker pulses
        tick = 0.0
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), BG)
    # Revealed ground.
    var cell_px: float = CELL * factor
    for c in seen_cells:
        var p: Vector2 = to_map(origin + Vector2(float(c[0]), float(c[1])) * CELL)
        draw_rect(Rect2(p, Vector2(ceilf(cell_px) + 0.5, ceilf(cell_px) + 0.5)), STREET)
    # Buildings, but only those that have been seen.
    for r in main.buildings:
        if not is_seen(r.get_center()):
            continue
        var tl: Vector2 = to_map(r.position)
        var br: Vector2 = to_map(r.end)
        var col: Color = GOLD if r == main.house else BLOCK
        draw_rect(Rect2(tl, Vector2(maxf(br.x - tl.x, 2.0), maxf(br.y - tl.y, 2.0))), col)

    # Home: always marked. A small house with a pulsing ring.
    var home: Vector2 = to_map(main.home_zone.get_center())
    var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
    draw_arc(home, 5.0 + 2.5 * pulse, 0.0, TAU, 20, Color(GOLD.r, GOLD.g, GOLD.b, 0.45 + 0.4 * pulse), 1.0)
    draw_rect(Rect2(home + Vector2(-3, -1), Vector2(6, 4)), GOLD)
    draw_colored_polygon(PackedVector2Array([home + Vector2(-4, -1), home + Vector2(4, -1), home + Vector2(0, -4)]), GOLD)

    # Nicole.
    var me: Vector2 = to_map(main.player.global_position)
    draw_circle(me, 3.2, Color(0, 0, 0, 0.9))
    draw_circle(me, 2.2, Color("ff6f9a"))

    draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), BORDER, false, 2.0)

    # Caption: how far home is, in "metres" (ten world units each).
    var dist: float = main.player.global_position.distance_to(main.home_zone.get_center()) / 10.0
    var text := "HOME  %d m" % int(round(dist / 10.0) * 10.0)
    var font: Font = Style.BODY_FONT
    var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    var at := Vector2(MAP_SIZE.x - width, MAP_SIZE.y + 15.0)
    draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Style.OUTLINE)
    draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
