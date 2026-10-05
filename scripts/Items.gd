extends RefCounted
# The found items: things Nicole picks up on the street and carries, one at a time, to use when she needs them.
# This is the catalogue (what each does and for how long, and which level it first turns up on) and the pictures
# (drawn in code, for the ground, the HUD slot and the gallery). What each one does is in ItemEffects.gd.
#
#   treat         A dog treat: Stella ignores cats, squirrels, hydrants and people on the corners for 30 seconds
#                 (the scent of home still pulls her), so she stops dragging Nicole about.
#   donut         A box of donuts: dropped at her feet, it draws cops on patrol to it; each stops to eat for
#                 about six seconds. A cop who is already chasing her ignores it.
#   hoodie        A dark hoodie: for 20 seconds cops see her less far and less fast.
#   extinguisher  A fire extinguisher: a white cloud at her feet for six seconds that hides her, as steam does. The
#                 hiss is a small noise that a cop right by can hear.
#   coffee        Coffee: for eight seconds she is 25% faster, but her steps are loud, sneaking or not.

const Sprites := preload("res://scripts/Sprites.gd")

const KINDS := ["treat", "donut", "hoodie", "extinguisher", "coffee"]

# name, the level it first turns up on, how long its effect lasts (seconds; 0 for one that is instant), the colour of its
# ring on the ground, and a line for the card the first time she picks one up.
const INFO := {
    "treat": {"name": "Dog treat", "level": 1, "seconds": 30.0, "color": Color("e8b86a"),
        "text": "A dog treat. Use it (E) and Stella ignores cats, squirrels and hydrants for a while, so she stops dragging you about."},
    "donut": {"name": "Donut box", "level": 1, "seconds": 6.0, "color": Color("ff8ac0"),
        "text": "A box of donuts. Use it (E) to put it down: cops that are not after you walk over and stop to eat."},
    "hoodie": {"name": "Dark hoodie", "level": 2, "seconds": 20.0, "color": Color("8d86c4"),
        "text": "A dark hoodie. Use it (E) and for a while cops see you less far and less fast."},
    "extinguisher": {"name": "Fire extinguisher", "level": 2, "seconds": 6.0, "color": Color("ff5a4d"),
        "text": "A fire extinguisher. Use it (E) for a white cloud that hides you, but the hiss carries to a cop right by."},
    "coffee": {"name": "Coffee", "level": 3, "seconds": 8.0, "color": Color("c98a5a"),
        "text": "A coffee. Use it (E) for a burst of speed, but your steps are loud, sneaking or not."},
}

# The kinds that can turn up on a level: each is unlocked on its own level, a few at a time.
static func available(level: int) -> Array:
    var out: Array = []
    for k in KINDS:
        if int(INFO[k].level) <= level:
            out.append(k)
    return out

# A pick for the n-th item of a level: every available kind in turn (a stride of 3, which shares no factor with a pool of
# 2, 4, 5 or 7, so it visits them all), with the stronger ones (hoodie, extinguisher) a share more of the places from
# level 4, once everything is out.
static func pick(level: int, n: int) -> String:
    var pool: Array = available(level)
    if level >= 4:
        pool = pool + ["hoodie", "extinguisher"]
    return pool[posmod(n * 3 + level, pool.size())]

static func info(kind: String) -> Dictionary:
    return INFO[kind]

# The picture of an item, in a square `s` pixels across centred on `c`, in screen space. `a` fades it.
static func draw_icon(item: CanvasItem, kind: String, c: Vector2, s: float, a: float = 1.0) -> void:
    var r: float = s * 0.5
    var fade := Color(1, 1, 1, a)
    var dark: Color = Color("1b1420") * fade
    match kind:
        "treat":  # a bone
            var bone: Color = Color("f0dcb0") * fade
            item.draw_line(c + Vector2(-r * 0.55, r * 0.35), c + Vector2(r * 0.55, -r * 0.35), dark, r * 0.62)
            item.draw_line(c + Vector2(-r * 0.55, r * 0.35), c + Vector2(r * 0.55, -r * 0.35), bone, r * 0.42)
            for p in [Vector2(-0.78, 0.08), Vector2(-0.3, 0.66), Vector2(0.78, -0.08), Vector2(0.3, -0.66)]:
                item.draw_circle(c + p * r, r * 0.3, dark)
            for p in [Vector2(-0.78, 0.08), Vector2(-0.3, 0.66), Vector2(0.78, -0.08), Vector2(0.3, -0.66)]:
                item.draw_circle(c + p * r, r * 0.22, bone)
        "donut":  # a box with a donut on its lid
            item.draw_rect(Rect2(c + Vector2(-r * 0.85, r * 0.0), Vector2(r * 1.7, r * 0.85)), Color("ff8ac0") * fade)
            item.draw_rect(Rect2(c + Vector2(-r * 0.85, r * 0.0), Vector2(r * 1.7, r * 0.22)), Color("ffc0de") * fade)
            item.draw_circle(c + Vector2(0.0, -r * 0.3), r * 0.55, dark)
            item.draw_circle(c + Vector2(0.0, -r * 0.3), r * 0.45, Color("d99a55") * fade)
            item.draw_circle(c + Vector2(0.0, -r * 0.34), r * 0.4, Color("ff6fae") * fade)
            item.draw_circle(c + Vector2(0.0, -r * 0.3), r * 0.16, dark)
        "hoodie":  # a dark hooded top
            var cloth: Color = Color("6a64a0") * fade
            item.draw_rect(Rect2(c + Vector2(-r * 1.0, -r * 0.88), Vector2(r * 2.0, r * 1.84)), Color(0.12, 0.1, 0.2, 0.0))
            item.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.8), c + Vector2(r * 0.4, -r * 0.8), c + Vector2(r * 0.95, -r * 0.35),
                    c + Vector2(r * 0.95, r * 0.35), c + Vector2(r * 0.55, r * 0.3), c + Vector2(r * 0.55, r * 0.9), c + Vector2(-r * 0.55, r * 0.9),
                    c + Vector2(-r * 0.55, r * 0.3), c + Vector2(-r * 0.95, r * 0.35), c + Vector2(-r * 0.95, -r * 0.35)]), cloth)
            item.draw_circle(c + Vector2(0.0, -r * 0.55), r * 0.32, dark)       # the hood's opening
            item.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.15), Vector2(r * 0.6, r * 0.4)), Color("4a4578") * fade)  # the pocket
        "extinguisher":  # a red cylinder with a nozzle
            item.draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.45), Vector2(r * 0.8, r * 1.35)), Color("d6382c") * fade)
            item.draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.45), Vector2(r * 0.25, r * 1.35)), Color("f06a58") * fade)
            item.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.78), Vector2(r * 0.4, r * 0.34)), Color("2a2830") * fade)
            item.draw_line(c + Vector2(r * 0.2, -r * 0.62), c + Vector2(r * 0.7, -r * 0.3), Color("2a2830") * fade, r * 0.2)
            item.draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.0), Vector2(r * 0.8, r * 0.3)), Color("f2f0ea") * fade)   # the label
        "coffee":  # a cup with steam
            item.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.2), Vector2(r * 1.1, r * 1.0)), Color("f2eadc") * fade)
            item.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.2), Vector2(r * 1.1, r * 0.3)), Color("8b5a3a") * fade)
            item.draw_rect(Rect2(c + Vector2(-r * 0.6, r * 0.15), Vector2(r * 1.2, r * 0.3)), Color("c9573a") * fade)
            item.draw_arc(c + Vector2(r * 0.7, r * 0.25), r * 0.28, -PI * 0.5, PI * 0.5, 8, dark, r * 0.18)
            for k in [-0.28, 0.12]:
                item.draw_line(c + Vector2(r * k, -r * 0.4), c + Vector2(r * (k + 0.1), -r * 0.95), Color(0.9, 0.9, 0.95, 0.7 * a), r * 0.12)
