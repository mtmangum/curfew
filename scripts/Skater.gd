extends Node2D
# A mean skateboarder, tearing along the road. Fast, and he swerves at Nicole if she's
# in his way. If he hits her she is knocked flat for a moment (not out of the game),
# and the commotion carries to the cops. Spawned and removed off screen by the
# TrafficDirector, like the cars.

const Sprites := preload("res://scripts/Sprites.gd")

const FAR := 1350.0
const RADIUS := 7.0   # how close counts as a hit
const SWERVE := 22.0  # how far across his lane he'll lean at someone
const FADE := 70.0
const STUN_TIME := 2.5  # how long she is knocked flat (seeing stars); it never ends the run

var main
var horizontal := true
var fixed := 0.0     # the lane's coordinate across the road
var lane_a := 0.0
var lane_b := 0.0
var dir := 1
var speed := 190.0
var swerve := 0.0    # his sideways offset from the lane
var heading := Vector2.RIGHT
var sprite: Sprite2D
var frames: Array = []
var bail_tex: Texture2D
var hit_cd := 0.0
var yell_cd := 0.0
var anim_t := 0.0

func setup_skater(game, is_horizontal: bool, fixed_coord: float, a: float, b: float, d: int, spd: float, along: float) -> void:
    main = game
    horizontal = is_horizontal
    fixed = fixed_coord
    lane_a = a
    lane_b = b
    dir = d
    speed = spd
    heading = Vector2(float(d), 0.0) if horizontal else Vector2(0.0, float(d))
    position = Vector2(along, fixed) if horizontal else Vector2(fixed, along)

func _ready() -> void:
    frames = Sprites.load_frames("skater", ["ride0", "ride1"])
    bail_tex = Sprites.load_tex("res://assets/sprites/skater/bail.png")
    sprite = Sprites.make("res://assets/sprites/skater/ride0.png", 0.36)
    Sprites.upright(self, 6.0).add_child(sprite)
    sprite.flip_h = Sprites.faces_left(heading)

func _process(delta: float) -> void:
    if main == null or main.state != "play":
        return
    var pp: Vector2 = main.player.global_position
    if global_position.distance_squared_to(pp) > FAR * FAR:
        return
    hit_cd = maxf(0.0, hit_cd - delta)
    yell_cd = maxf(0.0, yell_cd - delta)
    # Lean towards her if she is just ahead of him and close to his line.
    var to_her: Vector2 = pp - global_position
    var ahead: float = to_her.dot(heading)
    var across: float = to_her.dot(heading.orthogonal())
    var target := 0.0
    if ahead > 10.0 and ahead < 130.0 and absf(across) < 55.0:
        target = clampf(across, -SWERVE, SWERVE)
        if yell_cd <= 0.0:
            yell_cd = 3.0
            main.play_at("yell", global_position, -2.0, 500.0, 1.3)
            main.noise(global_position, 200.0, true)
    swerve = move_toward(swerve, target, 60.0 * delta)
    var along: float = (position.x if horizontal else position.y) + float(dir) * speed * delta
    if (dir > 0 and along > lane_b) or (dir < 0 and along < lane_a):
        along = lane_a if dir > 0 else lane_b
    if horizontal:
        position = Vector2(along, fixed + swerve)
    else:
        position = Vector2(fixed + swerve, along)
    modulate.a = clampf(minf(along - lane_a, lane_b - along) / FADE, 0.0, 1.0)
    if hit_cd <= 0.0 and modulate.a > 0.5 and global_position.distance_to(pp) < RADIUS + 4.0:
        _hit(pp)
    anim_t += delta
    sprite.texture = bail_tex if hit_cd > 3.0 else frames[int(anim_t * 5.0) % frames.size()]

func _hit(pp: Vector2) -> void:
    if not main.hurt(main.vitals.SKATER_DAMAGE, "skater"):
        hit_cd = 0.5  # she is still in grace from the last hit: he rides through
        return
    hit_cd = 4.5
    # Knocked sideways off his line.
    var side: Vector2 = heading.orthogonal() * (1.0 if (pp - global_position).dot(heading.orthogonal()) >= 0.0 else -1.0)
    main.player.stun(STUN_TIME, side * 22.0)
    main.noise(global_position, 240.0, true)
    main.play_at("yell", global_position, 0.0, 600.0, 1.2)
    main.play_at("bin_crash", global_position, -8.0, 300.0)
