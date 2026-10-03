extends Node
# Nicole's life. Street hazards (cars, skateboarders, punks, hobos) hurt her instead of
# ending the run outright: the run is over when the life bar is empty. A cop catching
# her still ends it at once, because the game is about not being seen.
# After a hit she has a moment of grace so one collision can't hit twice. Pizza slices
# lying about the streets restore life (see Pickup.gd).

const Style := preload("res://scripts/Style.gd")

const MAX := 100.0
const CAR_DAMAGE := 50.0
const SKATER_DAMAGE := 15.0
const PUNK_DAMAGE := 15.0
const HOBO_DRAIN := 3.0   # per second while a hobo has hold of her
const ZOMBIE_DAMAGE := 10.0  # a bite (then the usual grace)
const GRACE := 2.5        # seconds of not being hurt again after a hit
const PIZZA := 35.0
const DANGER := 30.0

# The bar runs red -> orange -> yellow -> green, like the one in Streetwise.
const RAMP := [[0.0, Color("d94f3d")], [0.333, Color("e08a3f")], [0.667, Color("e0c93f")], [1.0, Color("4fae62")]]

var main
var health := MAX
var grace_t := 0.0
var last_source := ""
var bar: LifeBar

class LifeBar extends Control:
    var vitals
    var shown := 1.0   # eases towards the real value so a hit visibly drains
    var flash_t := 0.0
    var t := 0.0

    func _process(delta: float) -> void:
        t += delta
        var target: float = vitals.health / vitals.MAX
        shown = move_toward(shown, target, 0.9 * delta)
        flash_t = maxf(0.0, flash_t - delta)
        queue_redraw()

    func _draw() -> void:
        var w := size.x
        var h := size.y
        var danger: bool = vitals.health > 0.0 and vitals.health <= vitals.DANGER and vitals.main.state == "play"
        var pulse: float = 0.5 + 0.5 * sin(t * 9.0)
        draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.04, 0.07, 0.85))
        var inner := Rect2(3, 3, w - 6, h - 6)
        var f: float = clampf(shown, 0.0, 1.0)
        var col: Color = vitals.colour_for(f)
        if danger:
            col = col.lerp(Color(1, 1, 1), 0.25 * pulse)
        draw_rect(Rect2(inner.position, Vector2(inner.size.x * f, inner.size.y)), col)
        # the part just lost, in white, until the bar catches up
        var real: float = clampf(vitals.health / vitals.MAX, 0.0, 1.0)
        if f > real:
            draw_rect(Rect2(inner.position + Vector2(inner.size.x * real, 0), Vector2(inner.size.x * (f - real), inner.size.y)), Color(1, 1, 1, 0.8))
        # ten segments
        for i in range(1, 10):
            var x: float = inner.position.x + inner.size.x * i / 10.0
            draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0, 0, 0, 0.45), 1.0)
        var border := Color(1.0, 0.35 + 0.4 * pulse, 0.3) if danger else Color(0.75, 0.78, 0.9)
        draw_rect(Rect2(0, 0, w, h), border, false, 2.0)
        if flash_t > 0.0:
            draw_rect(Rect2(0, 0, w, h), Color(1, 0.2, 0.2, flash_t * 1.2))

func setup(game) -> void:
    main = game

func build_bar(parent: Control) -> void:
    bar = LifeBar.new()
    bar.vitals = self
    bar.position = Vector2(20, 14)
    bar.size = Vector2(250, 20)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(bar)
    var label := Label.new()
    label.text = "LIFE"
    label.position = Vector2(278, 11)
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", Style.DIM)
    parent.add_child(label)

func colour_for(fraction: float) -> Color:
    var f := clampf(fraction, 0.0, 1.0)
    for i in range(RAMP.size() - 1):
        var a: Array = RAMP[i]
        var b: Array = RAMP[i + 1]
        if f >= a[0] and f <= b[0]:
            return a[1].lerp(b[1], (f - a[0]) / (b[0] - a[0]))
    return RAMP[RAMP.size() - 1][1]

func _process(delta: float) -> void:
    grace_t = maxf(0.0, grace_t - delta)

func in_grace() -> bool:
    return grace_t > 0.0

# A hit. False (and nothing happens) while she is still in grace from the last one.
func hurt(amount: float, source: String) -> bool:
    if grace_t > 0.0 or health <= 0.0:
        return false
    health = maxf(0.0, health - amount)
    grace_t = GRACE
    last_source = source
    if bar != null:
        bar.flash_t = 0.5
    return true

# Steady damage with no grace (a hobo's grip).
func drain(amount: float, source: String) -> void:
    if health <= 0.0:
        return
    health = maxf(0.0, health - amount)
    last_source = source

# Returns how much was actually restored.
func heal(amount: float) -> float:
    var before := health
    health = minf(MAX, health + amount)
    return health - before

func is_full() -> bool:
    return health >= MAX - 0.01
