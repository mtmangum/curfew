extends Node2D
# Stella, on a short leash. She follows Nicole and can be spotted too. She is easily
# distracted, and when she is the leash makes it Nicole's problem:
#  - a cat: she runs at it, hauling Nicole along, and barks;
#  - a squirrel that bolts up a tree: she chases it, then stands under the tree barking
#    up at it until it settles (Squirrel.gd), and Nicole can't get further than the leash;
#  - a fire hydrant she hasn't marked yet: she goes and pees on it, rooted there for a
#    few seconds, with Nicole held at the end of the leash.

const Sprites := preload("res://scripts/Sprites.gd")

const RADIUS := 4.0
const SPEED := 100.0  # flat out after a cat
const FOLLOW_SPEED := 90.0  # an easy walk beside Nicole
const STRIDE := 9.0  # ground covered per walk-animation frame, so her feet keep pace
const LEASH := 80.0  # the leash never stretches past this
const FOLLOW_GAP := 40.0  # she settles this far behind Nicole
const FOLLOW_EASE := 6.0  # speed per unit of distance beyond the gap, so she eases in and out
const SIT_AFTER := 0.25  # stands still this long before she sits
const NOTICE := 90.0
const DRAG_SPEED := 70.0  # how hard she hauls Nicole while straining after a cat
const BARK_NOISE := 190.0  # how far a bark carries to cops
const BARK_EVERY := 1.1  # she barks this often while after a cat
const PEE_TIME := 3.5  # how long she is rooted to a hydrant
const PEE_COOLDOWN := 40.0  # she has to build up to the next one
const HYDRANT_NOTICE := 60.0
const HYDRANT_REACH := 13.0
const SQUIRREL_NOTICE := 170.0  # how far off she notices a squirrel making for a tree
const TREE_REACH := 20.0

var main
var sprite: Sprite2D
var up: Node2D
var idle_tex: Texture2D
var run_frames: Array = []
var walk_frames: Array = []
var walk_t := 0.0
var still_t := 0.0
var moving := false
var anim_t := 0.0
var bark_cd := 0.0
var chasing = null
var straining := false
var squirrel = null
var hydrant = null
var planted := ""  # "pee" or "tree" while she has stopped and won't be moved
var planted_t := 0.0
var pee_cd := 0.0
var pee_at := Vector2.ZERO

class Puddle extends Node2D:
    func _draw() -> void:
        draw_circle(Vector2.ZERO, 6.0, Color(0.85, 0.78, 0.2, 0.22))
        draw_circle(Vector2(1.0, 0.5), 3.5, Color(0.9, 0.82, 0.25, 0.3))

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/dog/idle.png", 0.5)
    up = Sprites.upright(self, 5.0)
    up.add_child(sprite)
    idle_tex = Sprites.load_tex("res://assets/sprites/dog/idle.png")
    run_frames = Sprites.load_frames("dog", ["extended0", "gathered0"])
    walk_frames = Sprites.load_frames("dog", ["walk0", "walk1", "walk2", "walk3"])

func visibility_mult() -> float:
    return 1.8 if main.in_light(global_position) else 1.0

func _nearest_cat():
    var best = null
    var best_d := NOTICE
    for c in main.cats:
        if c.state == c.State.FLEE:
            continue
        var d: float = global_position.distance_to(c.global_position)
        if d < best_d:
            best_d = d
            best = c
    return best

func _nearest_hydrant():
    var best = null
    var best_d := HYDRANT_NOTICE
    for h in main.hydrants:
        if h.marked:
            continue
        var d: float = global_position.distance_to(h.rect.get_center())
        if d < best_d:
            best_d = d
            best = h
    return best

# A squirrel making for (or up) a tree near her, which she can see.
func _fixated_squirrel():
    for sq in main.squirrels:
        if sq.chasable() and sq.tree_pos.distance_to(global_position) < SQUIRREL_NOTICE:
            return sq
    return null

# A bark carries to cops (BARK_NOISE). Only one that lands on the cat sends it running.
func _bark(cat, scare: bool) -> void:
    bark_cd = BARK_EVERY
    main.noise(global_position, BARK_NOISE, true)
    main.play("bark", -6.0)
    if scare:
        cat.scare_from(global_position)

func _process(delta: float) -> void:
    if main.state != "play":
        return
    bark_cd = maxf(0.0, bark_cd - delta)
    pee_cd = maxf(0.0, pee_cd - delta)
    var owner_pos: Vector2 = main.player.global_position
    chasing = _nearest_cat()
    squirrel = null
    hydrant = null
    if chasing != null:
        planted = ""  # a cat trumps everything
    else:
        squirrel = _fixated_squirrel()
        if planted == "tree" and squirrel == null:
            planted = ""  # it has settled down
        elif planted == "pee":
            planted_t -= delta
            if planted_t <= 0.0:
                planted = ""
        if squirrel != null and planted == "pee":
            planted = ""
        if squirrel == null and planted == "" and pee_cd <= 0.0:
            hydrant = _nearest_hydrant()
    moving = false
    var start_pos: Vector2 = global_position
    if chasing != null:
        var to_cat: Vector2 = chasing.global_position - global_position
        var cat_dist: float = to_cat.length()
        # Facing the cat the whole time, even when she stops beside it or the leash
        # holds her back.
        if cat_dist > 0.5:
            _face(to_cat)
        if cat_dist > 26.0:
            var cdir: Vector2 = to_cat / cat_dist
            global_position = main.slide(global_position, cdir * SPEED * delta, RADIUS)
            moving = true
        # She barks the moment she notices a cat and keeps on as she runs at it.
        if bark_cd <= 0.0:
            _bark(chasing, cat_dist <= 26.0)
    elif squirrel != null:
        var to_tree: Vector2 = squirrel.tree_pos - global_position
        var tree_dist: float = to_tree.length()
        _face(to_tree)
        if tree_dist > TREE_REACH and planted == "":
            var goal: Vector2 = squirrel.global_position if squirrel.state == squirrel.State.RUN else squirrel.tree_pos
            var gdir: Vector2 = (goal - global_position).normalized()
            global_position = main.slide(global_position, gdir * SPEED * delta, RADIUS)
            moving = true
        else:
            if planted != "tree":
                planted = "tree"
                main.runlog.note_stop("tree")
            # Standing under the tree, barking up at it.
            if bark_cd <= 0.0:
                bark_cd = BARK_EVERY
                main.noise(global_position, BARK_NOISE, true)
                main.play("bark", -6.0)
    elif hydrant != null:
        var hc: Vector2 = hydrant.rect.get_center()
        var to_h: Vector2 = hc - global_position
        _face(to_h)
        if to_h.length() > HYDRANT_REACH:
            global_position = main.slide(global_position, to_h.normalized() * SPEED * 0.8 * delta, RADIUS)
            moving = true
        else:
            planted = "pee"
            planted_t = PEE_TIME
            pee_cd = PEE_COOLDOWN
            pee_at = hc
            hydrant.marked = true
            var puddle := Puddle.new()
            puddle.z_as_relative = false
            puddle.z_index = -34
            main.add_child(puddle)
            puddle.global_position = hc + Vector2(0.0, 5.0)
            main.runlog.note_stop("pee")
    elif planted == "pee":
        _face(pee_at - global_position)  # still at it
    else:
        var to_owner: Vector2 = owner_pos - global_position
        var dist: float = to_owner.length()
        if dist > FOLLOW_GAP + 2.0:
            # Speed grows with how far behind she is, so she keeps pace with Nicole
            # smoothly and eases to a stop, instead of lurching on and off.
            var dir: Vector2 = to_owner / dist
            var speed: float = minf(FOLLOW_SPEED, (dist - FOLLOW_GAP) * FOLLOW_EASE)
            var step: float = minf(speed * delta, dist - FOLLOW_GAP)
            global_position = main.slide(global_position, dir * step, RADIUS)
            moving = true
            _face(dir)
    var walked_now: float = global_position.distance_to(start_pos)

    var off: Vector2 = global_position - owner_pos
    var was_straining := straining
    straining = false
    var after_something: bool = chasing != null or ((squirrel != null or hydrant != null) and planted == "")
    if after_something and off.length() >= LEASH - 1.0:
        # The leash is taut and Stella is still going for the cat: Nicole gets
        # hauled along behind her, whether she sneaks or not. She can only
        # fight it by walking the other way.
        straining = true
        main.player.drag(off.normalized() * DRAG_SPEED * delta)
        owner_pos = main.player.global_position
        off = global_position - owner_pos
        if not was_straining:
            main.play("tug", -4.0)
    if off.length() > LEASH:
        # The leash never stretches: reel Stella in, and if she is wedged
        # against something, reel Nicole in instead. Capped per frame so a
        # sudden separation (a teleport) doesn't fling either of them across the map.
        var max_reel: float = SPEED * 1.5 * delta
        var excess: float = off.length() - LEASH
        if planted == "":
            global_position = main.slide(global_position, -off.normalized() * minf(excess, max_reel), RADIUS)
            off = global_position - owner_pos
        # Rooted to the spot (a hydrant, a tree): she won't be reeled in, so Nicole is
        # held where the leash runs out.
        if off.length() > LEASH + 0.5 or planted != "":
            main.player.global_position = main.slide(main.player.global_position,
                off.normalized() * minf(off.length() - LEASH, max_reel), main.player.RADIUS)

    sprite.position.y = 0.0
    if planted != "":
        anim_t += delta
        sprite.texture = walk_frames[0]
        if planted == "tree":
            sprite.position.y = -absf(sin(anim_t * 9.0)) * 2.5  # hopping as she barks
        still_t = 0.0
    elif moving and (chasing != null or squirrel != null or hydrant != null):
        # Stretched out after a cat.
        anim_t += delta * 8.0
        sprite.texture = run_frames[int(anim_t) % run_frames.size()]
        still_t = 0.0
    elif moving and walked_now > 0.01:
        # An ordinary walk, stepping in time with the ground she covers.
        walk_t += walked_now / STRIDE
        sprite.texture = walk_frames[int(walk_t) % walk_frames.size()]
        still_t = 0.0
    else:
        # She sits only once she has really stopped, not for a frame between steps.
        still_t += delta
        if still_t > SIT_AFTER:
            sprite.texture = idle_tex
    queue_redraw()

# Turn to face along a ground direction, but only when it is clearly to one side of
# the screen, so she doesn't flip back and forth while it is nearly straight up or down.
func _face(dir: Vector2) -> void:
    var across: float = dir.x - dir.y
    if absf(across) > 0.35 * dir.length():
        sprite.flip_h = across < 0.0

func _draw() -> void:
    var to_owner: Vector2 = main.player.global_position - global_position
    draw_set_transform_matrix(Sprites.UP)
    draw_line(Vector2(0, -6), Sprites.iso(to_owner) + Vector2(0, -14), Color(0.85, 0.3, 0.4), 1.0)
    if planted == "pee":
        # a dotted yellow arc from her to the hydrant
        var to_h: Vector2 = Sprites.iso(pee_at - global_position)
        for i in range(1, 9):
            var f: float = float(i) / 9.0
            var p: Vector2 = to_h * f + Vector2(0.0, -9.0 - sin(f * PI) * 4.0 + f * 7.0)
            draw_rect(Rect2(p.x - 0.7, p.y - 0.7, 1.4, 1.4), Color(1.0, 0.92, 0.3, 0.9))
