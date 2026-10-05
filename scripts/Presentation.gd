extends Node
# Read CSS dimensions at startup/resizes. Small screens use the full canvas;
# UI uses screen-sized units independently of the world transform.
const Style := preload("res://scripts/Style.gd")
const COMPACT_DENSITY := 1.5
var main
var css_size := Vector2.ZERO
var compact := false
var pointer_mode := false
var unit := 1.0
var window_size := Vector2i.ZERO
var dirty := true

func setup(game) -> void:
    main = game
    process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
    get_window().size_changed.connect(func(): dirty = true)
    refresh()

func _process(_delta: float) -> void:
    if dirty or window_size != get_window().size:
        refresh()

func refresh() -> void:
    dirty = false
    window_size = get_window().size
    var screen: Vector2 = main.presentation_size_override
    if screen == Vector2.ZERO:
        screen = Style.canvas_size(get_viewport())
    screen = screen.max(Vector2(240, 240))
    if screen == css_size:
        return
    css_size = screen
    var was_compact: bool = compact
    compact = screen.x < 1000.0 or screen.y < 600.0
    if compact and not was_compact:
        pointer_mode = true
    var window: Window = get_window()
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if compact else Window.CONTENT_SCALE_ASPECT_KEEP
    window.content_scale_size = Vector2i(screen * COMPACT_DENSITY) if compact else Vector2i(1280, 720)
    unit = COMPACT_DENSITY if compact else 1.0
    if main.hud != null:
        main.hud.layout()
    if main.pause_menu != null:
        main.pause_menu._layout()

func _input(event: InputEvent) -> void:
    var next: bool = pointer_mode
    if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
        next = true
    elif event is InputEventKey and event.pressed and not event.echo:
        next = false
    if next != pointer_mode:
        pointer_mode = next
        if main.hud != null:
            main.hud.sync_input_hints()
