extends "res://scripts/Building.gd"
# A parked car: an isometric two-box body (low body, smaller cabin) with wheels,
# glass and lights. It is drawn and depth-sorted like a building, and its footprint
# is solid for walking (Main.cars) but low enough that light and sight pass over it.

const BODY_COLORS := [
    Color("7a2a30"),  # red
    Color("2d4a7a"),  # blue
    Color("2f6a5a"),  # teal
    Color("a58a30"),  # taxi yellow
    Color("9aa0ae"),  # silver
    Color("23262e"),  # black
    Color("6a4a2e"),  # brown
]

var color_index := 0
var local_rect := Rect2()  # a moving car draws around its own origin instead of at its world rect
var use_local := false
var front := 1  # which way along its long axis the car faces (+1 or -1)
var paint := Color(0, 0, 0, 0)  # a set colour (alpha above 0) instead of the palette: a police car's
var wrecked := false  # rusted, smashed glass, dead lights (an abandoned neighbourhood)

func setup_car(r: Rect2, color_i: int, front_dir: int, seed_value: int) -> void:
    rect = r
    color_index = color_i
    front = front_dir
    variant = seed_value
    floors = 0
    height = 21.0
    fades = false  # low: never hides her enough to be worth ghosting (only buildings do)
    update_screen_box()

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    var r := local_rect if use_local else rect
    var along_x: bool = r.size.x >= r.size.y
    var body: Color = paint if paint.a > 0.0 else BODY_COLORS[color_index % BODY_COLORS.size()]
    if wrecked:
        body = body.darkened(0.35).lerp(Color("5a3a28"), 0.5)
    var side: Color = body.darkened(0.32)
    var top: Color = body.lightened(0.12)
    var glass := Color("182034") if not wrecked else Color("07090d")
    var glass_lit := Color("2c3a58") if not wrecked else Color("07090d")
    var low := 3.0  # ground clearance
    var shoulder := 12.0  # top of the body
    var roof := 20.0  # top of the cabin

    # Soft shadow on the road.
    var sh := r.grow(2.5)
    Sprites.fill(self, PackedVector2Array([
        _p(sh.position.x, sh.position.y, 0.0), _p(sh.end.x, sh.position.y, 0.0),
        _p(sh.end.x, sh.end.y, 0.0), _p(sh.position.x, sh.end.y, 0.0)]), Color(0, 0, 0, 0.32))

    # Lower body: south and east faces, then the top (hood and boot).
    Sprites.fill(self, PackedVector2Array([
        _p(r.position.x, r.end.y, low), _p(r.end.x, r.end.y, low),
        _p(r.end.x, r.end.y, shoulder), _p(r.position.x, r.end.y, shoulder)]), body)
    Sprites.fill(self, PackedVector2Array([
        _p(r.end.x, r.end.y, low), _p(r.end.x, r.position.y, low),
        _p(r.end.x, r.position.y, shoulder), _p(r.end.x, r.end.y, shoulder)]), side)
    Sprites.fill(self, PackedVector2Array([
        _p(r.position.x, r.position.y, shoulder), _p(r.end.x, r.position.y, shoulder),
        _p(r.end.x, r.end.y, shoulder), _p(r.position.x, r.end.y, shoulder)]), top)
    # A shine line along the top edge of the body.
    draw_line(_p(r.position.x, r.end.y, shoulder), _p(r.end.x, r.end.y, shoulder), body.lightened(0.35), 1.0)
    draw_line(_p(r.end.x, r.end.y, shoulder), _p(r.end.x, r.position.y, shoulder), side.lightened(0.25), 1.0)

    # Cabin, set back from the bonnet end so the car has a nose.
    var c: Rect2 = r
    if along_x:
        var nose: float = 13.0
        var tail: float = 7.0
        c = Rect2(r.position.x + (tail if front > 0 else nose), r.position.y + 2.5,
            r.size.x - nose - tail, r.size.y - 5.0)
    else:
        var nose2: float = 13.0
        var tail2: float = 7.0
        c = Rect2(r.position.x + 2.5, r.position.y + (tail2 if front > 0 else nose2),
            r.size.x - 5.0, r.size.y - nose2 - tail2)
    Sprites.fill(self, PackedVector2Array([
        _p(c.position.x, c.end.y, shoulder), _p(c.end.x, c.end.y, shoulder),
        _p(c.end.x, c.end.y, roof), _p(c.position.x, c.end.y, roof)]), body.darkened(0.08))
    Sprites.fill(self, PackedVector2Array([
        _p(c.end.x, c.end.y, shoulder), _p(c.end.x, c.position.y, shoulder),
        _p(c.end.x, c.position.y, roof), _p(c.end.x, c.end.y, roof)]), side)
    # Glass on the two visible cabin faces.
    var south_len: float = c.size.x
    var east_len: float = c.size.y
    Sprites.fill(self, _quad(Vector2(c.position.x, c.end.y), Vector2.RIGHT, 1.5, south_len - 1.5, shoulder + 1.5, roof - 1.5), glass_lit if variant % 2 == 0 else glass)
    Sprites.fill(self, _quad(Vector2(c.end.x, c.end.y), Vector2.UP, 1.5, east_len - 1.5, shoulder + 1.5, roof - 1.5), glass)
    if wrecked:
        # smashed glass: a few white cracks across the windscreen side, and a scorch mark on the top
        var gx: float = c.position.x
        draw_line(Sprites.proj(Vector2(gx + south_len * 0.25, c.end.y), shoulder + 2.0), Sprites.proj(Vector2(gx + south_len * 0.55, c.end.y), roof - 2.0), Color(0.82, 0.88, 0.95, 0.55), 1.0)
        draw_line(Sprites.proj(Vector2(gx + south_len * 0.55, c.end.y), roof - 2.0), Sprites.proj(Vector2(gx + south_len * 0.8, c.end.y), shoulder + 3.5), Color(0.82, 0.88, 0.95, 0.45), 1.0)
        draw_line(Sprites.proj(Vector2(gx + south_len * 0.4, c.end.y), shoulder + 4.5), Sprites.proj(Vector2(gx + south_len * 0.7, c.end.y), shoulder + 5.0), Color(0.82, 0.88, 0.95, 0.4), 1.0)
        Sprites.fill(self, PackedVector2Array([
            _p(r.position.x + 3.0, r.position.y + 3.0, shoulder), _p(r.position.x + r.size.x * 0.45, r.position.y + 2.0, shoulder),
            _p(r.position.x + r.size.x * 0.4, r.position.y + r.size.y * 0.6, shoulder), _p(r.position.x + 2.0, r.position.y + r.size.y * 0.5, shoulder)]), Color(0.04, 0.03, 0.03, 0.5))
    # Pillar between the doors on a long side.
    if along_x and south_len > 14.0:
        var mid: float = south_len * 0.5
        Sprites.fill(self, _quad(Vector2(c.position.x, c.end.y), Vector2.RIGHT, mid - 0.8, mid + 0.8, shoulder + 1.5, roof - 1.5), body.darkened(0.08))
    elif (not along_x) and east_len > 14.0:
        var mid2: float = east_len * 0.5
        Sprites.fill(self, _quad(Vector2(c.end.x, c.end.y), Vector2.UP, mid2 - 0.8, mid2 + 0.8, shoulder + 1.5, roof - 1.5), side)
    # Roof.
    Sprites.fill(self, PackedVector2Array([
        _p(c.position.x, c.position.y, roof), _p(c.end.x, c.position.y, roof),
        _p(c.end.x, c.end.y, roof), _p(c.position.x, c.end.y, roof)]), top.lightened(0.05))

    # Wheels on the long visible side.
    var wheel := Color("0b0c10")
    var hub := Color("4a4f5c")
    if along_x:
        for u in [8.0, r.size.x - 8.0]:
            var o := Vector2(r.position.x, r.end.y)
            Sprites.fill(self, _quad(o, Vector2.RIGHT, u - 3.5, u + 3.5, 0.0, 6.0), wheel)
            Sprites.fill(self, _quad(o, Vector2.RIGHT, u - 1.2, u + 1.2, 1.8, 4.2), hub)
    else:
        for u2 in [8.0, r.size.y - 8.0]:
            var o2 := Vector2(r.end.x, r.end.y)
            Sprites.fill(self, _quad(o2, Vector2.UP, u2 - 3.5, u2 + 3.5, 0.0, 6.0), wheel)
            Sprites.fill(self, _quad(o2, Vector2.UP, u2 - 1.2, u2 + 1.2, 1.8, 4.2), hub)

    # Lights on whichever end faces the viewer: headlights if that end is the
    # nose, tail-lights otherwise.
    var visible_end_is_front: bool = front > 0
    var lamp: Color = Color("f4e7b4") if visible_end_is_front else Color("c93b3b")
    if wrecked:
        lamp = Color("2a2220")
    if along_x:
        var o3 := Vector2(r.end.x, r.end.y)
        for u3 in [2.0, r.size.y - 5.0]:
            Sprites.fill(self, _quad(o3, Vector2.UP, u3, u3 + 3.0, 6.0, 9.0), lamp)
    else:
        var o4 := Vector2(r.position.x, r.end.y)
        for u4 in [2.0, r.size.x - 5.0]:
            Sprites.fill(self, _quad(o4, Vector2.RIGHT, u4, u4 + 3.0, 6.0, 9.0), lamp)
