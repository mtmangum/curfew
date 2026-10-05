extends Node2D
# Stella, on a short leash. She follows Nicole and can be spotted too. She is easily
# distracted, and when she is the leash makes it Nicole's problem:
#  - a cat: she runs at it, hauling Nicole along, and barks;
#  - a squirrel that bolts up a tree: she chases it, then stands under the tree barking
#    up at it until it settles (Squirrel.gd), and Nicole can't get further than the leash;
#  - a fire hydrant she hasn't marked yet: she goes and pees on it, rooted there for a
#    few seconds, with Nicole held at the end of the leash.
# She does not stay keen for long: after about seven seconds of going for a cat she loses interest
# in cats altogether for half a minute (Nicole is not hauled about for ever by one that will not run).
# And she knows the way home. Every so often (the level says how often) she lifts her head,
# sniffs, and leads off toward home for a few seconds, giving the leash a gentle haul in that
# direction: the clue to follow, in place of a marker on the map. A hint waits until she is
# free of distractions, then she finishes it before chasing anything. Once home is found she stops.

const Sprites := preload("res://scripts/Sprites.gd")
const Style := preload("res://scripts/Style.gd")
const FollowPath := preload("res://scripts/DogFollow.gd")

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
const BARK_NOISE := 340.0  # how far a bark carries to cops: far, and it tells them where we are
const BARK_EVERY := 1.1  # she barks this often while after a cat
const PEE_TIME := 3.5  # how long she is rooted to a hydrant
const PEE_COOLDOWN := 40.0  # she has to build up to the next one
const HYDRANT_NOTICE := 60.0
const HYDRANT_REACH := 13.0
const FOLK_NOTICE := 110.0  # she notices a corner character (level 5 up) this near
const FOLK_REACH := 22.0
const SNIFF_TIME := 4.0     # and stops to sniff them for this long, with the leash holding Nicole
const SQUIRREL_NOTICE := 170.0  # how far off she notices a squirrel making for a tree
const TREE_REACH := 16.0
const TREE_CYCLE := 3.4  # at the tree: sits and barks, then rears up with her paws on the trunk, then again
const TREE_SIT := 1.5
const CAT_INTEREST := 7.0   # seconds of going for a cat before she gives up on it
const CAT_BORED_FOR := 30.0  # and then she ignores every cat for this long
const SCENT_TIME := 2.6   # how long she leads the way when she catches the scent of home
const SCENT_TIME_FIRST := 6.0  # ...the first time, when a clue card explains it: long enough to read it and still watch her
const SCENT_DRAG := 42.0  # a gentle haul on the leash toward home (she is only pointing the way)

var main
var sprite: Sprite2D
var up: Node2D
var idle_tex: Texture2D
var marking_tex: Texture2D
var rear_frames: Array = []
var tree_t := 0.0  # how long she has been at the foot of a tree
var jammed_t := 0.0  # how long she has been pushing at something solid on her way to a tree
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
var folk = null  # a corner character she is going to sniff
var sniff_at := Vector2.ZERO
var scent_t := 0.0    # > 0 while she is leading the way home
var scent_len := SCENT_TIME  # how long this one lasts (the bubble fades in and out over it)
var scent_cd := 0.0   # seconds until she next catches the scent
var scent_dir := Vector2.ZERO
var cat_interest_t := 0.0  # how long she has been going for a cat (it drains away when she isn't)
var cat_bored_t := 0.0     # > 0: she has lost interest in cats
var follow_path := PackedVector2Array()
var follow_stuck_t := 0.0
var follow_retry_cd := 0.0

class Puddle extends Node2D:
    func _draw() -> void:
        Sprites.disc(self, Vector2.ZERO, 6.0, Color(0.85, 0.78, 0.2, 0.22))
        Sprites.disc(self, Vector2(1.0, 0.5), 3.5, Color(0.9, 0.82, 0.25, 0.3))

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/dog/idle.png", 0.5)
    up = Sprites.upright(self, 5.0)
    up.add_child(sprite)
    idle_tex = Sprites.load_tex("res://assets/sprites/dog/idle.png")
    marking_tex = Sprites.load_tex("res://assets/sprites/dog/marking.png")
    rear_frames = Sprites.load_frames("dog", ["rear0", "rear1"])
    run_frames = Sprites.load_frames("dog", ["extended0", "gathered0"])
    walk_frames = Sprites.load_frames("dog", ["walk0", "walk1", "walk2", "walk3"])
    scent_cd = _next_scent()

# How long until she next catches the scent of home, from the level's settings.
func _next_scent() -> float:
    var r: Vector2 = main.settings.nose
    return randf_range(r.x, r.y)

func _can_scent() -> bool:
    var r: Vector2 = main.settings.nose
    return r.y > 0.0 and not main.minimap.home_found() and main.audio.tension < 0.35 and main.player.stunned_t <= 0.0

func _start_scent() -> void:
    main.play("sniff", -3.0, randf_range(0.95, 1.05))
    main.runlog.note_stop("scent")
    # The first time there is a card about it, and her sniffing goes on for longer, so it is not a choice
    # between reading and watching her.
    scent_len = SCENT_TIME_FIRST if main.clues.offer("scent") else SCENT_TIME
    scent_t = scent_len

func visibility_mult() -> float:
    return 1.8 if main.in_light(global_position) else 1.0

func _nearest_cat():
    if cat_bored_t > 0.0 or main.items.treat_on():
        return null
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

func _nearest_folk():
    if main.items.treat_on():
        return null  # (a treat in her mouth: she has no nose for anyone)
    var best = null
    var best_d := FOLK_NOTICE
    for f in main.corner_folk:
        if not is_instance_valid(f) or not f.ready_to_sniff():
            continue
        var dist: float = global_position.distance_to(f.global_position)
        if dist < best_d:
            best_d = dist
            best = f
    return best

func _nearest_hydrant():
    if main.items.treat_on():
        return null
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
    if main.items.treat_on():
        return null
    for sq in main.squirrels:
        if sq.chasable() and sq.tree_pos.distance_to(global_position) < SQUIRREL_NOTICE:
            return sq
    return null

# A bark carries a long way and gives us away: cops that hear it come for where Nicole is
# (she is on the other end of the leash), keyed up and watching for her.
func _bark_noise() -> void:
    main.noise(global_position, BARK_NOISE, true, true, main.player.global_position)

# A bark carries to cops (BARK_NOISE). Only one that lands on the cat sends it running.
func _bark(cat, scare: bool) -> void:
    bark_cd = BARK_EVERY
    _bark_noise()
    main.bark(-5.0)
    if scare:
        cat.scare_from(global_position)

func _process(delta: float) -> void:
    if main.state != "play":
        return
    bark_cd = maxf(0.0, bark_cd - delta)
    pee_cd = maxf(0.0, pee_cd - delta)
    scent_cd = maxf(0.0, scent_cd - delta)
    follow_retry_cd = maxf(0.0, follow_retry_cd - delta)
    var owner_pos: Vector2 = main.player.global_position
    cat_bored_t = maxf(0.0, cat_bored_t - delta)
    var scenting: bool = scent_t > 0.0
    chasing = null if scenting else _nearest_cat()
    if chasing != null:
        cat_interest_t += delta
        if cat_interest_t > CAT_INTEREST:  # enough of that cat
            cat_interest_t = 0.0
            cat_bored_t = CAT_BORED_FOR
            chasing = null
            main.runlog.note_stop("cat_bored")
    else:
        cat_interest_t = maxf(0.0, cat_interest_t - delta * 2.0)
    squirrel = null
    hydrant = null
    folk = null
    if chasing != null:
        planted = ""  # a cat trumps everything
    elif not scenting:
        squirrel = _fixated_squirrel()
        if planted == "tree" and squirrel == null:
            planted = ""  # it has settled down
        elif planted == "pee" or planted == "sniff":
            planted_t -= delta
            if planted_t <= 0.0:
                planted = ""
        if squirrel != null and (planted == "pee" or planted == "sniff"):
            planted = ""
        if squirrel == null and planted == "" and pee_cd <= 0.0:
            hydrant = _nearest_hydrant()
        if squirrel == null and hydrant == null and planted == "":
            folk = _nearest_folk()
    # An overdue hint waits for her current distraction to end. Once it starts,
    # keep her attention on home for the full hint, even if a new animal appears.
    if not scenting and chasing == null and squirrel == null and hydrant == null and folk == null and planted == "" \
            and scent_cd <= 0.0 and _can_scent():
        _start_scent()
    moving = false
    if chasing != null or squirrel != null or hydrant != null or folk != null or planted != "" or scent_t > 0.0:
        follow_path.clear()
        follow_stuck_t = 0.0
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
        # Close enough, or wedged against a bench or planter beside the tree: either way she
        # stops there and barks.
        if tree_dist > TREE_REACH and planted == "" and not (jammed_t > 0.3 and tree_dist < 40.0):
            var goal: Vector2 = squirrel.global_position if squirrel.state == squirrel.State.RUN else squirrel.tree_pos
            var gdir: Vector2 = (goal - global_position).normalized()
            var before_step: Vector2 = global_position
            global_position = main.slide(global_position, gdir * SPEED * delta, RADIUS)
            jammed_t = jammed_t + delta if global_position.distance_to(before_step) < SPEED * delta * 0.2 else 0.0
            moving = true
        else:
            jammed_t = 0.0
            if planted != "tree":
                planted = "tree"
                main.runlog.note_stop("tree")
            # Standing under the tree, barking up at it.
            if bark_cd <= 0.0:
                bark_cd = BARK_EVERY
                _bark_noise()
                main.bark(-5.0)
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
    elif folk != null:
        var fp: Vector2 = folk.global_position
        var to_f: Vector2 = fp - global_position
        _face(to_f)
        if to_f.length() > FOLK_REACH:
            global_position = main.slide(global_position, to_f.normalized() * SPEED * 0.8 * delta, RADIUS)
            moving = true
        else:
            planted = "sniff"
            planted_t = SNIFF_TIME
            sniff_at = fp
            folk.sniffed(global_position)
            main.runlog.note_stop("sniff_folk")
    elif scent_t > 0.0:
        scent_t -= delta
        var to_home: Vector2 = main.home_zone.get_center() - global_position
        scent_dir = to_home.normalized()
        _face(to_home)
        global_position = main.slide(global_position, scent_dir * FOLLOW_SPEED * delta, RADIUS)
        moving = true
        if scent_t <= 0.0:
            scent_cd = _next_scent()
    elif planted == "pee":
        _face(pee_at - global_position)  # still at it
    elif planted == "sniff":
        _face(sniff_at - global_position)  # sniffing the person
    else:
        var to_owner: Vector2 = owner_pos - global_position
        var dist: float = to_owner.length()
        if dist <= FOLLOW_GAP + 2.0:
            follow_path.clear()
            follow_stuck_t = 0.0
        if dist > FOLLOW_GAP + 2.0:
            # Speed grows with how far behind she is, so she keeps pace with Nicole
            # smoothly and eases to a stop, instead of lurching on and off.
            while not follow_path.is_empty() and global_position.distance_to(follow_path[0]) < 3.0:
                follow_path.remove_at(0)
            var detouring: bool = not follow_path.is_empty()
            var to_aim: Vector2 = (follow_path[0] - global_position) if detouring else to_owner
            var dir: Vector2 = to_aim.normalized()
            var speed: float = FOLLOW_SPEED if detouring else minf(FOLLOW_SPEED, (dist - FOLLOW_GAP) * FOLLOW_EASE)
            var step: float = minf(speed * delta, to_aim.length() if detouring else dist - FOLLOW_GAP)
            var before: Vector2 = global_position
            global_position = main.slide(global_position, dir * step, RADIUS)
            follow_stuck_t = follow_stuck_t + delta if global_position.distance_to(before) < step * 0.2 else 0.0
            if follow_stuck_t > 0.25 and follow_retry_cd <= 0.0:
                follow_path = FollowPath.path(main, global_position, owner_pos, RADIUS)
                follow_retry_cd = 1.0
                follow_stuck_t = 0.0
            moving = true
            _face(dir)
    var walked_now: float = global_position.distance_to(start_pos)

    var off: Vector2 = global_position - owner_pos
    var was_straining := straining
    straining = false
    var after_something: bool = chasing != null or ((squirrel != null or hydrant != null or folk != null) and planted == "") or scent_t > 0.0
    if after_something and off.length() >= LEASH - 1.0:
        # The leash is taut and Stella is still going for the cat: Nicole gets
        # hauled along behind her, whether she sneaks or not. She can only
        # fight it by walking the other way.
        straining = true
        var pull: float = DRAG_SPEED if (chasing != null or squirrel != null or hydrant != null or folk != null) else SCENT_DRAG
        main.player.drag(off.normalized() * pull * delta)
        owner_pos = main.player.global_position
        off = global_position - owner_pos
        if not was_straining:
            if pull == DRAG_SPEED:
                main.play("tug", -4.0)  # a lunge at a cat, a squirrel or a hydrant: the jingle and thump
                main.clues.offer("drag")
            else:
                main.play("tug_soft", -7.0)  # the gentle pull toward home: a twang
    if off.length() > LEASH:
        # The leash never stretches: reel Stella in, and if she is wedged
        # against something, reel Nicole in instead. Capped per frame so a
        # sudden separation (a teleport) doesn't fling either of them across the map.
        var max_reel: float = SPEED * 1.5 * delta
        var excess: float = off.length() - LEASH
        if planted == "" and follow_path.is_empty():
            global_position = main.slide(global_position, -off.normalized() * minf(excess, max_reel), RADIUS)
            off = global_position - owner_pos
        # While she detours, give her room by easing Nicole back instead of
        # undoing every sideways step and pinning her to the same car corner.
        # Rooted to the spot (a hydrant, a tree): she won't be reeled in, so Nicole is
        # held where the leash runs out.
        if off.length() > LEASH + 0.5 or planted != "":
            main.player.global_position = main.slide(main.player.global_position,
                off.normalized() * minf(off.length() - LEASH, max_reel), main.player.RADIUS)

    sprite.position.y = 0.0
    if planted != "tree":
        tree_t = 0.0
    if planted != "":
        anim_t += delta
        if planted == "pee":
            sprite.texture = marking_tex
            tree_t = 0.0
        elif planted == "sniff":
            sprite.texture = idle_tex
            sprite.position.y = sin(anim_t * 14.0) * 0.8  # her nose going
            tree_t = 0.0
        else:
            # Under the tree she sits and barks up at the squirrel, then rears onto her hind
            # legs with her paws on the trunk (mouth open just after each bark), and repeats.
            tree_t += delta
            var just_barked: bool = bark_cd > BARK_EVERY - 0.3
            if fmod(tree_t, TREE_CYCLE) < TREE_SIT:
                sprite.texture = idle_tex
            else:
                sprite.texture = rear_frames[1 if just_barked else 0]
            if just_barked:
                sprite.position.y = -1.5
        still_t = 0.0
    elif moving and (chasing != null or squirrel != null or hydrant != null or folk != null):
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
    if scent_t > 0.0:
        # a few faint wisps drifting from her nose the way she is heading
        var way: Vector2 = Sprites.iso(scent_dir).normalized()
        var now: float = Time.get_ticks_msec() / 1000.0
        for i in 5:
            var f: float = fposmod(now * 0.9 + float(i) * 0.2, 1.0)
            var w: Vector2 = Vector2(0.0, -9.0) + way * (7.0 + f * 24.0) + Vector2(0.0, -f * 7.0)
            Sprites.disc(self, w, 0.6 + 1.4 * (1.0 - f), Color(0.92, 0.96, 1.0, 0.55 * (1.0 - f)))
        # and a thought bubble with a house in it over her head, so it is plain what she is on about
        var shown: float = clampf(minf(scent_t, scent_len - scent_t) / 0.3, 0.0, 1.0)
        if shown > 0.0:
            Style.draw_thought_bubble(self, Vector2(0.0, -35.0 + sin(now * 5.0) * 1.2), "house", shown)
    if planted == "sniff":
        # a "?" in a thought bubble over her head while she sniffs
        var fade: float = clampf(minf(planted_t, SNIFF_TIME - planted_t) / 0.3, 0.0, 1.0)
        # (off to the side away from the person, so it does not cover them)
        var away: Vector2 = -Sprites.iso(sniff_at - global_position).normalized()
        Style.draw_thought_bubble(self, Vector2(away.x * 26.0, -32.0 + sin(anim_t * 5.0) * 1.2), "question", fade)
    if planted == "pee":
        # a dotted yellow arc from her to the hydrant
        var to_h: Vector2 = Sprites.iso(pee_at - global_position)
        for i in range(1, 9):
            var f: float = float(i) / 9.0
            var p: Vector2 = to_h * f + Vector2(0.0, -9.0 - sin(f * PI) * 4.0 + f * 7.0)
            draw_rect(Rect2(p.x - 0.7, p.y - 0.7, 1.4, 1.4), Color(1.0, 0.92, 0.3, 0.9))
