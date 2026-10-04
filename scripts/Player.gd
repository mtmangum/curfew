extends Node2D
# Nicole. Click or tap to walk there (hold to keep steering toward the
# pointer), or use WASD / arrows. Shift or the on-screen button sneaks.

const BeamCastScript := preload("res://scripts/BeamCast.gd")
const Sprites := preload("res://scripts/Sprites.gd")

const RADIUS := 5.0
const WALK_SPEED := 85.0
const SNEAK_SPEED := 42.0
const FOOTSTEP_NOISE := 45.0  # how far a step carries to cops (not a sound you hear)
# Nicole's footstep sound effect is off for now: it never sat right. Her steps
# still make noise cops react to; flip this to hear them again.
const FOOTSTEP_SOUND := false

class Marker extends Node2D:
    var t := 0.0

    func _process(delta: float) -> void:
        t += delta
        queue_redraw()

    func _draw() -> void:
        var pulse: float = 0.5 + 0.5 * sin(t * 8.0)
        draw_arc(Vector2.ZERO, 7.0 + 2.0 * pulse, 0.0, TAU, 24, Color(1, 1, 1, 0.55), 1.2)
        Sprites.disc(self, Vector2.ZERO, 1.5, Color(1, 1, 1, 0.7))

# Seeing stars: a few sparkles circling her head while she is knocked down.
class Stars extends Node2D:
    var player
    var t := 0.0

    func _process(delta: float) -> void:
        var on: bool = player.stunned_t > 0.0
        if on:
            t += delta
        if on != visible:
            visible = on
        if on:
            queue_redraw()

    func _draw() -> void:
        # Her head is on the left of the fallen sprite (flipped when she faces left).
        var side: float = -1.0 if player.sprite.flip_h else 1.0
        var centre := Vector2(-9.0 * side, -13.0)
        for i in 3:
            var a: float = t * 6.0 + float(i) * TAU / 3.0
            var p: Vector2 = centre + Vector2(cos(a) * 11.0, sin(a) * 4.0 - 4.0)
            var r: float = 3.4 + 0.7 * sin(t * 14.0 + float(i) * 2.0)
            var col := Color(1.0, 0.92, 0.3) if (int(t * 8.0) + i) % 2 == 0 else Color(1.0, 1.0, 0.8)
            # a four-point sparkle
            Sprites.fill(self, PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.35, -r * 0.35), p + Vector2(r, 0),
                    p + Vector2(r * 0.35, r * 0.35), p + Vector2(0, r), p + Vector2(-r * 0.35, r * 0.35),
                    p + Vector2(-r, 0), p + Vector2(-r * 0.35, -r * 0.35)]), col)

var main
var sprite: Sprite2D
var walk_frames: Array = []
var idle_tex: Texture2D
var sneaking := false
var moving := false
var in_cover := false
var lit := false
var torch_on := false  # her torch (levels with darkness): a cone of light ahead of her, and cops see her the better for it (F)
var face_dir := Vector2(1.0, 1.0).normalized()  # the way she last moved, on the ground plane
var torch_ground := PackedVector2Array()  # where her torch's rays end, relative to her feet
var torch_origin := Vector2.ZERO
var lit_by_torch: Array = []  # buildings her torch is landing on
const TORCH_RANGE := 130.0
const TORCH_FOV := 0.85
const TORCH_RAYS := 16
const TORCH_VISIBILITY := 1.4  # cops see her this much the better with it on
var anim_t := 0.0
var last_frame := -1
var steps_taken := 0  # counts each foot-down, whether or not it is audible
var dragged_t := 0.0  # > 0 while Stella is hauling Nicole along
var stunned_t := 0.0  # > 0 while she is knocked down
var slow_t := 0.0  # > 0 while someone has hold of her: she moves at a crawl
var slow_factor := 0.35  # how much of her speed she keeps while held (a zombie's grip is weaker than a hobo's)
var fall_tex: Texture2D
var drag_dir := Vector2.ZERO
var pointer_down := false
var pointer_pos := Vector2.ZERO  # viewport coordinates
var dest := Vector2.ZERO
var has_dest := false
var stuck := 0.0
var marker: Marker

func _ready() -> void:
    sprite = Sprites.make("res://assets/sprites/player/idle0.png", 0.5)
    var layer: Node2D = Sprites.upright(self, 6.0)
    layer.add_child(sprite)
    var stars := Stars.new()
    stars.player = self
    stars.visible = false
    layer.add_child(stars)
    idle_tex = Sprites.load_tex("res://assets/sprites/player/idle0.png")
    walk_frames = Sprites.load_frames("player", ["walk0", "walk1", "walk2", "walk3", "walk4", "walk5"])
    fall_tex = Sprites.load_tex("res://assets/sprites/player/fallForward.png")
    marker = Marker.new()
    marker.top_level = true
    marker.z_as_relative = false
    marker.z_index = -10
    marker.visible = false
    add_child(marker)

func _unhandled_input(event: InputEvent) -> void:
    # Touches arrive as emulated left-button mouse events.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        pointer_down = event.pressed
        pointer_pos = event.position
        if event.pressed:
            _set_dest_from_pointer()
    elif event is InputEventMouseMotion and pointer_down:
        pointer_pos = event.position

# The pointer lives in screen space, but the view follows the player, so it is
# converted back to the ground each frame.
func _set_dest_from_pointer() -> void:
    dest = get_canvas_transform().affine_inverse() * pointer_pos
    has_dest = true
    stuck = 0.0

func _clear_dest() -> void:
    has_dest = false
    pointer_down = false
    marker.visible = false

# Knocked down for a moment (a shove, a skateboarder). She can't move or sneak while
# down, and `push` moves her a little way.
func stun(seconds: float, push: Vector2 = Vector2.ZERO) -> void:
    stunned_t = maxf(stunned_t, seconds)
    if push != Vector2.ZERO:
        global_position = main.slide(global_position, push, RADIUS)
    _clear_dest()

# Someone has hold of her: she crawls for a moment (refreshed while they do).
func hold(seconds: float = 0.3, factor: float = 0.35) -> void:
    slow_t = maxf(slow_t, seconds)
    slow_factor = factor

# Stella hauling on the leash. Nicole is moved, and looks like she is running.
func drag(motion: Vector2) -> void:
    global_position = main.slide(global_position, motion, RADIUS)
    dragged_t = 0.2
    drag_dir = motion

# Multiplier on how fast cops notice us.
# The torch (F): on or off, on the levels that are dark.
func toggle_torch() -> void:
    if float(main.settings.darkness) <= 0.0:
        return
    torch_on = not torch_on
    main._show_toast("Torch on: it lights the way, and cops see you the better" if torch_on else "Torch off")

# Casts the torch's beam each frame it is on (BeamCast.gd): a cone ahead of her, stopped by walls, with soft
# patches on the walls it lands on; LightMap.gd draws the light.
func _update_torch() -> void:
    if not torch_on or float(main.settings.darkness) <= 0.0:
        if not lit_by_torch.is_empty():
            lit_by_torch = BeamCastScript.clear(get_instance_id(), lit_by_torch)
            torch_ground = PackedVector2Array()
        return
    var r: Dictionary = BeamCastScript.cast(main, global_position, face_dir * 5.0, face_dir.angle(), TORCH_FOV, TORCH_RANGE, TORCH_RAYS)
    torch_origin = r.origin
    torch_ground = r.ground
    lit_by_torch = BeamCastScript.register(get_instance_id(), lit_by_torch, r.strips)

func visibility_mult() -> float:
    var m := 1.0
    if sneaking and dragged_t <= 0.0:
        m *= 0.55
    if not moving:
        m *= 0.8
    if lit:
        m *= 1.8
    if torch_on and float(main.settings.darkness) > 0.0:
        m *= TORCH_VISIBILITY
    return m

func _process(delta: float) -> void:
    if main.state != "play":
        _clear_dest()
        return
    dragged_t = maxf(dragged_t - delta, 0.0)
    slow_t = maxf(slow_t - delta, 0.0)
    _update_torch()
    if stunned_t > 0.0:
        # Flat on the pavement: no moving, and the light still falls on her.
        stunned_t -= delta
        moving = false
        sprite.texture = fall_tex
        in_cover = main.in_steam(global_position)
        lit = main.in_light(global_position)
        return
    var dir := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        dir.x += 1.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        dir.x -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        dir.y += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        dir.y -= 1.0
    sneaking = Input.is_physical_key_pressed(KEY_SHIFT) or main.sneak_toggle
    var move := Vector2.ZERO
    var step_scale := 1.0
    if dir != Vector2.ZERO:
        # Keys cancel any pointer destination. By default each key runs along a
        # street (a ground axis), so one key walks a block. Tab switches to
        # keys that follow the screen instead.
        _clear_dest()
        move = Sprites.ground_dir(dir) if main.screen_relative else dir
        move = move.normalized()
    elif has_dest:
        if pointer_down:
            _set_dest_from_pointer()
        var to_dest: Vector2 = dest - global_position
        var dist: float = to_dest.length()
        if dist < 2.0:
            _clear_dest()
        else:
            move = to_dest / dist
            step_scale = minf(1.0, dist / ((SNEAK_SPEED if sneaking else WALK_SPEED) * delta))
            marker.global_position = dest
            marker.visible = true
    var dragged: bool = dragged_t > 0.0
    moving = move != Vector2.ZERO or dragged
    if moving:
        if move != Vector2.ZERO:
            var speed := (SNEAK_SPEED if sneaking else WALK_SPEED) * (slow_factor if slow_t > 0.0 else 1.0)
            var before: Vector2 = global_position
            global_position = main.slide(global_position, move * speed * step_scale * delta, RADIUS)
            # Give up on a destination we can't make progress toward.
            if has_dest and not pointer_down:
                if global_position.distance_to(before) < 0.01:
                    stuck += delta
                    if stuck > 0.3:
                        _clear_dest()
                else:
                    stuck = 0.0
        # Being hauled along is never quiet, even when sneaking.
        var quiet: bool = sneaking and not dragged
        var facing: Vector2 = move if move != Vector2.ZERO else drag_dir
        if facing != Vector2.ZERO:
            face_dir = facing.normalized()
        if facing.x != facing.y:
            sprite.flip_h = Sprites.faces_left(facing)
        anim_t += delta * (6.0 if quiet else 10.0)
        var frame: int = int(anim_t) % walk_frames.size()
        sprite.texture = walk_frames[frame]
        # A foot comes down when the legs are furthest apart: frames 0 and 3 of
        # the six-frame walk. Landing steps there keeps sound and gait in time.
        if frame != last_frame and (frame == 0 or frame == 3):
            steps_taken += 1
            if FOOTSTEP_SOUND:
                main.footstep(-14.0 if quiet else -6.0)
            if not quiet:
                main.noise(global_position, FOOTSTEP_NOISE, false)
        last_frame = frame
    else:
        sprite.texture = idle_tex
        anim_t = 0.0
        last_frame = -1

    in_cover = main.in_steam(global_position)
    lit = main.in_light(global_position)
    var tint := Color(1, 1, 1, 1)
    if sneaking:
        tint = Color(0.75, 0.75, 0.85, 1)
    if lit:
        tint = Color(1.2, 1.0, 0.8, 1)
    if in_cover:
        tint.a = 0.45
    elif main.vitals.in_grace() and int(Time.get_ticks_msec() / 90) % 2 == 0:
        tint.a = 0.4  # flickering: she can't be hurt again for a moment
    sprite.modulate = tint
