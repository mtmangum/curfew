extends RefCounted
# What Nicole is carrying (`main.carried`, one found item at a time: see Items.gd) and what each one does when she
# uses it (E, or a tap on the slot in the corner). Owns the timers of the effects that are running (the dark hoodie,
# the coffee, the dog treat) and answers the questions the rest of the game asks of them. (Main owns one: `main.items`.)
#
#   hoodie        Player.visibility_mult() and Cop._rate_for() ask: she is seen slower, and from less far.
#   coffee        Player asks: she is faster, and her steps are loud, sneaking or not.
#   treat         Dog asks before she notices a cat, squirrel, hydrant or person on the corner.
#   donut         a DonutBox is put down; it draws the cops (DonutBox.gd).
#   extinguisher  a SteamVent that blows once (it does what steam does: hides her and blocks a cop's beam), and a hiss
#                 that a cop right by can hear.

const Items := preload("res://scripts/Items.gd")
const DonutBoxScript := preload("res://scripts/DonutBox.gd")
const VentScript := preload("res://scripts/SteamVent.gd")

const HOODIE_SIGHT := 0.7      # a cop's sight range, against her, with the hoodie on
const HOODIE_VISIBLE := 0.55   # and how fast his suspicion builds
const COFFEE_SPEED := 1.25
const CLOUD_RADIUS := 42.0
const HISS_NOISE := 90.0

var main
var hoodie_t := 0.0
var coffee_t := 0.0
var treat_t := 0.0

func _init(game) -> void:
    main = game

func tick(delta: float) -> void:
    hoodie_t = maxf(hoodie_t - delta, 0.0)
    coffee_t = maxf(coffee_t - delta, 0.0)
    treat_t = maxf(treat_t - delta, 0.0)

func treat_on() -> bool:
    return treat_t > 0.0

func hoodie_on() -> bool:
    return hoodie_t > 0.0

func coffee_on() -> bool:
    return coffee_t > 0.0

# What a cop sees of her: how far (a share of his range) and how readily.
func sight_range_mult() -> float:
    return HOODIE_SIGHT if hoodie_t > 0.0 else 1.0

func visibility_mult() -> float:
    return HOODIE_VISIBLE if hoodie_t > 0.0 else 1.0

func speed_mult() -> float:
    return COFFEE_SPEED if coffee_t > 0.0 else 1.0

# The effect to show in the slot's bar: the one with the most of its time left. {} if none is running.
func running() -> Dictionary:
    var best := {}
    var best_frac := 0.0
    for e in [["hoodie", hoodie_t], ["coffee", coffee_t], ["treat", treat_t]]:
        var frac: float = float(e[1]) / float(Items.info(e[0]).seconds)
        if e[1] > 0.0 and frac > best_frac:
            best_frac = frac
            best = {"kind": e[0], "frac": frac}
    return best

# Uses what she is carrying, if anything, and empties her hands. Returns whether anything happened.
func use() -> bool:
    var kind: String = main.carried
    if kind == "" or main.state != "play":
        return false
    var at: Vector2 = main.player.global_position
    match kind:
        "treat":
            treat_t = float(Items.info(kind).seconds)
            main.dog.cat_interest_t = 0.0
            main._show_toast("Stella gets her treat: she will ignore cats, squirrels and hydrants for a while")
        "hoodie":
            hoodie_t = float(Items.info(kind).seconds)
            main._show_toast("Hood up: cops see you less far")
        "coffee":
            coffee_t = float(Items.info(kind).seconds)
            main._show_toast("Coffee: faster, but your steps are loud")
        "donut":
            var box := DonutBoxScript.new()
            box.main = main
            main.actors.add_child(box)
            box.global_position = at + main.player.face_dir * 8.0
            main.donuts.append(box)
            main._show_toast("Donuts down: cops that are not after you will stop to eat")
        "extinguisher":
            var cloud := VentScript.new()
            cloud.main = main
            cloud.radius = CLOUD_RADIUS
            cloud.one_shot = float(Items.info(kind).seconds)
            cloud.z_index = -20
            main.actors.add_child(cloud)
            cloud.global_position = at
            main.vents.append(cloud)
            main.noise(at, HISS_NOISE, true)
    main.carried = ""
    main.play("pickup", -6.0)
    main.runlog.note_item(kind)
    return true
