extends Node2D
# A street steam vent. While venting, the cloud blocks sight lines and hides
# anyone standing in it. A short puff of warning comes just before it starts.

const Sprites := preload("res://scripts/Sprites.gd")

const ON_TIME := 4.0
const OFF_TIME := 3.5

const PUFFS := 18
const BILLOWS := 14  # low fog that fills the hiding zone
const RISE := 62.0  # how high a puff climbs before it fades, in screen pixels
const TEXEL := 0.8  # size of one pixel of puff art, in screen pixels
const SIZES := [3, 5, 7, 9, 11, 13, 15, 17]  # puff radii in texels
const VARIANTS := 3
const LIGHT := Color("dbe6f2")
const MID := Color("aebfd3")
const DARK := Color("7c8da6")

# Lumpy pixel-art cloud puffs shaded from the upper left, cached by radius and
# variant. The outermost ring of texels is half transparent for a soft edge.
static var puff_textures: Dictionary = {}

static func puff_texture(radius: int, variant: int = 0) -> Texture2D:
    var key: int = radius * 10 + variant
    if puff_textures.has(key):
        return puff_textures[key]
    var rng := RandomNumberGenerator.new()
    rng.seed = radius * 131 + variant * 7919
    # A fat middle lump plus a few smaller ones around it: [x, y, radius] in
    # fractions of the puff radius.
    var lumps: Array = [[0.0, 0.08, 0.6]]
    for k in 3:
        var a: float = rng.randf() * TAU
        var d: float = rng.randf_range(0.34, 0.5)
        lumps.append([cos(a) * d, sin(a) * d * 0.85, rng.randf_range(0.42, 0.55)])
    var size: int = radius * 2 + 1
    var inside: Array = []
    var nearest: Array = []  # normalised distance to the closest lump centre
    for y in size:
        var row_in: Array = []
        var row_d: Array = []
        for x in size:
            var dx: float = float(x - radius) / float(radius)
            var dy: float = float(y - radius) / float(radius)
            var best: float = 99.0
            for l in lumps:
                var d: float = Vector2(dx - l[0], dy - l[1]).length() / l[2]
                best = minf(best, d)
            row_in.append(best <= 1.0 and dx * dx + dy * dy <= 1.0)
            row_d.append(best)
        inside.append(row_in)
        nearest.append(row_d)
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            if not inside[y][x]:
                continue
            var dx: float = float(x - radius) / float(radius)
            var dy: float = float(y - radius) / float(radius)
            # Higher toward the lower right (away from the light) and toward lump edges.
            var shade: float = (dx * 0.5 + dy * 0.85) * 0.8 + nearest[y][x] * 0.5
            var c: Color = LIGHT
            if shade > 0.55:
                c = DARK
            elif shade > 0.08:
                c = MID
            var edge: bool = false
            for n in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
                var nx: int = x + n[0]
                var ny: int = y + n[1]
                if nx < 0 or ny < 0 or nx >= size or ny >= size or not inside[ny][nx]:
                    edge = true
            if edge:
                c.a = 0.55
            img.set_pixel(x, y, c)
    var tex := ImageTexture.create_from_image(img)
    puff_textures[key] = tex
    return tex

class Cloud extends Node2D:
    var vent
    # Per-puff constants: where it leaves the grate, how it drifts, and when.
    var spots: Array = []
    var drift: Array = []
    var offsets: Array = []
    var variants: Array = []
    var billow_spots: Array = []
    var billow_offsets: Array = []

    func _setup() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = int(vent.global_position.x * 7.0 + vent.global_position.y * 13.0)
        for i in vent.PUFFS:
            # Puffs leave from the middle of the grate, not the whole footprint.
            spots.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 6.0))
            drift.append(rng.randf_range(-26.0, 26.0))
            offsets.append(float(i) / float(vent.PUFFS) + rng.randf_range(-0.02, 0.02))
            variants.append(rng.randi() % vent.VARIANTS)
        for i in vent.BILLOWS:
            # Spread over the whole footprint, denser toward the middle.
            billow_spots.append(Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * vent.radius * 0.8)
            billow_offsets.append(float(i) / float(vent.BILLOWS) + rng.randf_range(-0.04, 0.04))

    func _draw() -> void:
        if spots.is_empty():
            _setup()
        var amt: float = vent.amount
        if amt > 0.01:
            _draw_zone(amt)
            draw_set_transform_matrix(Sprites.UP)
            _draw_fog(amt)
            _draw_plume(amt)
        elif vent.hint:
            _draw_warning()

    # The footprint on the ground where you are hidden: a faint fog.
    func _draw_zone(amt: float) -> void:
        Sprites.disc(self, Vector2.ZERO, vent.radius, Color(0.75, 0.85, 0.95, 0.07 * amt))

    # Low, slow billows rolling across the footprint so the whole hiding zone
    # looks filled with steam.
    func _draw_fog(amt: float) -> void:
        for i in vent.BILLOWS:
            var u: float = fposmod(vent.t * 0.18 + billow_offsets[i], 1.0)
            var tex: Texture2D = vent.puff_texture(_nearest_size(lerpf(8.0, 15.0, u)), i % vent.VARIANTS)
            var pos: Vector2 = Sprites.iso(billow_spots[i]) + Vector2(sin(vent.t * 0.7 + float(i)) * 4.0, -4.0 - u * 16.0)
            pos = (pos / vent.TEXEL).round() * vent.TEXEL
            var alpha: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.5, 1.0, u)) * 0.42 * amt
            var rect_size: Vector2 = tex.get_size() * vent.TEXEL
            draw_texture_rect(tex, Rect2(pos - rect_size * 0.5, rect_size), false, Color(1, 1, 1, alpha))

    # A plume that bursts from the grate, rises, sways and widens.
    func _draw_plume(amt: float) -> void:
        var order: Array = []
        for i in vent.PUFFS:
            order.append([fposmod(vent.t * 0.3 + offsets[i], 1.0), i])
        # Oldest (highest, largest) puffs first so young ones sit in front.
        order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
        for o in order:
            var u: float = o[0]
            var i: int = o[1]
            # Quick out of the vent, slowing as it climbs.
            var lift: float = 1.0 - pow(1.0 - u, 1.7)
            var sway: float = sin(vent.t * 1.3 + float(i) * 1.7) * 5.0 * u
            var texels: float = lerpf(3.0, 17.0, pow(u, 0.7))
            var tex: Texture2D = vent.puff_texture(_nearest_size(texels), variants[i])
            var pos: Vector2 = Sprites.iso(spots[i]) + Vector2(drift[i] * u + sway, -3.0 - lift * vent.RISE)
            # Snap to the puff pixel grid so it keeps the pixel-art look.
            pos = (pos / vent.TEXEL).round() * vent.TEXEL
            var alpha: float = smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.5, 1.0, u)) * 0.7 * amt
            var rect_size: Vector2 = tex.get_size() * vent.TEXEL
            draw_texture_rect(tex, Rect2(pos - rect_size * 0.5, rect_size), false, Color(1, 1, 1, alpha))

    # A few small wisps just before the vent blows.
    func _draw_warning() -> void:
        draw_set_transform_matrix(Sprites.UP)
        for i in 3:
            var rise: float = fmod(vent.t * 14.0 + float(i) * 5.0, 14.0)
            var tex: Texture2D = vent.puff_texture(vent.SIZES[0], i % vent.VARIANTS)
            var rect_size: Vector2 = tex.get_size() * vent.TEXEL
            var pos := Vector2(float(i - 1) * 4.0, -3.0 - rise)
            pos = (pos / vent.TEXEL).round() * vent.TEXEL
            draw_texture_rect(tex, Rect2(pos - rect_size * 0.5, rect_size), false,
                Color(1, 1, 1, 0.55 * (1.0 - rise / 14.0)))

    func _nearest_size(texels: float) -> int:
        var best: int = vent.SIZES[0]
        for s in vent.SIZES:
            if absf(float(s) - texels) < absf(float(best) - texels):
                best = s
        return best

var main
var radius := 46.0
var phase := 0.0
var t := 0.0
var active := false
var hint := false
var one_shot := 0.0  # > 0: not a street vent but a cloud that blows once for this long, then goes (a fire extinguisher)
var amount := 0.0
var cloud: Cloud
var hiss: AudioStreamPlayer

func _ready() -> void:
    t = phase
    active = one_shot > 0.0  # a cloud from an extinguisher hides her from the first moment
    cloud = Cloud.new()
    cloud.vent = self
    cloud.z_as_relative = false
    cloud.z_index = 3000
    add_child(cloud)
    hiss = AudioStreamPlayer.new()
    hiss.stream = preload("res://scripts/AudioDirector.gd").stream_for("steam_loop")
    hiss.bus = "SFX"
    hiss.volume_db = -80.0
    add_child(hiss)

func _process(delta: float) -> void:
    t += delta
    if one_shot > 0.0:
        active = t < one_shot
        hint = false
        if t > one_shot + 1.5:  # it has thinned away
            main.vents.erase(self)
            queue_free()
            return
    else:
        var cyc: float = fmod(t, ON_TIME + OFF_TIME)
        active = cyc < ON_TIME
        hint = (not active) and cyc > ON_TIME + OFF_TIME - 1.0
    amount = move_toward(amount, 1.0 if active else 0.0, delta * 1.5)
    # The hiss swells as the vent blows and as Nicole gets close.
    if main != null and main.player != null:
        var near: float = clampf(1.0 - global_position.distance_to(main.player.global_position) / 200.0, 0.0, 1.0)
        var level: float = amount * near * near
        if level > 0.01:
            if not hiss.playing:
                hiss.play()
            hiss.volume_db = linear_to_db(level) - 10.0
        elif hiss.playing:
            hiss.stop()
    # Far-away vents keep time but aren't redrawn.
    if (amount > 0.0 or hint) and global_position.distance_squared_to(main.focus) < main.NEAR_VIEW * main.NEAR_VIEW:
        cloud.queue_redraw()

func _draw() -> void:
    if one_shot > 0.0:
        return  # no grate: it is only a cloud
    # A flat grate set into the street.
    draw_rect(Rect2(-13, -13, 26, 26), Color(0.26, 0.28, 0.34))
    draw_rect(Rect2(-11, -11, 22, 22), Color(0.06, 0.07, 0.1))
    for i in 6:
        draw_rect(Rect2(-9 + i * 3.6, -11, 1.8, 22), Color(0.3, 0.32, 0.38))
