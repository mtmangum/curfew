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
const IsoArt := preload("res://scripts/IsoArt.gd")

const KINDS := ["treat", "donut", "hoodie", "extinguisher", "coffee"]

# name, the level it first turns up on, how long its effect lasts (seconds), the colour of its ring on the ground, a few
# words for the toast when she picks one up (the cards only run on levels 1 to 3), and a line for the card the first time.
# (Level 2 is gentle, with few cops to hide from, so the stealth items wait for level 3 and the coffee, a trade-off, for 4.)
const INFO := {
    "treat": {"name": "Dog treat", "level": 1, "seconds": 30.0, "color": Color("e8b86a"), "short": "Stella ignores cats and hydrants for a while",
        "text": "A dog treat. Use it (E) and Stella ignores cats, squirrels and hydrants for a while, so she stops dragging you about."},
    "donut": {"name": "Donut box", "level": 1, "seconds": 6.0, "color": Color("ff8ac0"), "short": "put it down to lure cops away",
        "text": "A box of donuts. Use it (E) to put it down: cops that are not after you walk over and stop to eat."},
    "hoodie": {"name": "Dark hoodie", "level": 3, "seconds": 20.0, "color": Color("8d86c4"), "short": "cops see you less far",
        "text": "A dark hoodie. Use it (E) and for a while cops see you less far and less fast."},
    "extinguisher": {"name": "Fire extinguisher", "level": 3, "seconds": 6.0, "color": Color("ff5a4d"), "short": "a cloud that hides you",
        "text": "A fire extinguisher. Use it (E) for a white cloud that hides you, but the hiss carries to a cop right by."},
    "coffee": {"name": "Coffee", "level": 4, "seconds": 8.0, "color": Color("c98a5a"), "short": "faster, but your steps are loud",
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

# The picture of an item, in a square `s` pixels across centred on `c`, in screen space. `a` fades it. They are drawn
# isometric, like the city (IsoArt.gd).
static func draw_icon(item: CanvasItem, kind: String, c: Vector2, s: float, a: float = 1.0) -> void:
    match kind:
        "treat":
            IsoArt.bone(item, c, s, a)
        "donut":
            IsoArt.donut(item, c, s, a)
        "hoodie":
            IsoArt.hoodie(item, c, s, a)
        "extinguisher":
            IsoArt.extinguisher(item, c, s, a)
        "coffee":
            IsoArt.coffee(item, c, s, a)
