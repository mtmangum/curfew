extends Node2D
# Stella, on a short leash. She follows Nicole and can be spotted too.

const Sprites := preload("res://scripts/Sprites.gd")

const RADIUS := 4.0
const SPEED := 100.0  # flat out after a cat
const FOLLOW_SPEED := 90.0  # an easy walk beside Nicole
const STRIDE := 9.0  # ground covered per walk-animation frame, so her feet keep pace
const LEASH := 80.0  # the leash never stretches past this
const FOLLOW_START := 46.0  # Stella trails Nicole by about this much
const FOLLOW_STOP := 40.0
const NOTICE := 90.0
const DRAG_SPEED := 70.0  # how hard she hauls Nicole while straining after a cat
const BARK_NOISE := 150.0

var main
var sprite: Sprite2D
var up: Node2D
var idle_tex: Texture2D
var run_frames: Array = []
var walk_frames: Array = []
var walk_t := 0.0
var moving := false
var anim_t := 0.0
var bark_cd := 0.0
var chasing = null
var straining := false

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/dog/idle.png", 0.5)
    up = Sprites.upright(self, 5.0)
    up.add_child(sprite)
    idle_tex = Sprites.load_tex("res://assets/sprites/dog/idle.png")
    run_frames = Sprites.load_frames("dog", ["extended0", "gathered0"])
    walk_frames = Sprites.load_frames("dog", ["walk0", "walk1", "walk2", "walk3"])

func visibility_mult() -> float:
    return 1.8 if main.in_fire(global_position) else 1.0

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

func _bark(cat) -> void:
    bark_cd = 3.0
    main.noise(global_position, BARK_NOISE, true)
    main.play("bark", -6.0)
    cat.scare_from(global_position)

func _process(delta: float) -> void:
    if main.state != "play":
        return
    bark_cd = maxf(0.0, bark_cd - delta)
    var owner_pos: Vector2 = main.player.global_position
    chasing = _nearest_cat()
    moving = false
    var start_pos: Vector2 = global_position
    if chasing != null:
        var to_cat: Vector2 = chasing.global_position - global_position
        var cat_dist: float = to_cat.length()
        if cat_dist > 26.0:
            var cdir: Vector2 = to_cat / cat_dist
            global_position = main.slide(global_position, cdir * SPEED * delta, RADIUS)
            moving = true
            sprite.flip_h = Sprites.faces_left(cdir)
        elif bark_cd <= 0.0:
            _bark(chasing)
    else:
        var to_owner: Vector2 = owner_pos - global_position
        var dist: float = to_owner.length()
        if dist > FOLLOW_START:
            var dir: Vector2 = to_owner / dist
            var step: float = minf(FOLLOW_SPEED * delta, dist - FOLLOW_STOP)
            global_position = main.slide(global_position, dir * step, RADIUS)
            moving = true
            sprite.flip_h = Sprites.faces_left(dir)
    var walked_now: float = global_position.distance_to(start_pos)

    var off: Vector2 = global_position - owner_pos
    var was_straining := straining
    straining = false
    if chasing != null and off.length() >= LEASH - 1.0:
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
        global_position = main.slide(global_position, -off.normalized() * minf(excess, max_reel), RADIUS)
        off = global_position - owner_pos
        if off.length() > LEASH + 0.5:
            main.player.global_position = main.slide(main.player.global_position,
                off.normalized() * minf(off.length() - LEASH, max_reel), main.player.RADIUS)

    if moving and chasing != null:
        # Stretched out after a cat.
        anim_t += delta * 8.0
        sprite.texture = run_frames[int(anim_t) % run_frames.size()]
    elif moving and walked_now > 0.01:
        # An ordinary walk, stepping in time with the ground she covers.
        walk_t += walked_now / STRIDE
        sprite.texture = walk_frames[int(walk_t) % walk_frames.size()]
    else:
        sprite.texture = idle_tex
    queue_redraw()

func _draw() -> void:
    var to_owner: Vector2 = main.player.global_position - global_position
    draw_set_transform_matrix(Sprites.UP)
    draw_line(Vector2(0, -6), Sprites.iso(to_owner) + Vector2(0, -14), Color(0.85, 0.3, 0.4), 1.0)
