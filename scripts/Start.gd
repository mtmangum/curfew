extends CanvasLayer
# Returning players choose before generating the city. First visits go straight
# into level 1. Keep this lightweight screen visible until the chosen game boots.
const Progress := preload("res://scripts/Progress.gd")
const Main := preload("res://scripts/Main.gd")
const Style := preload("res://scripts/Style.gd")
var box: VBoxContainer
var title: Label
var sub: Label
var note: Label
var continue_button: Button
var new_button: Button
var screen_size_override := Vector2.ZERO
var starting := false
var window_size := Vector2i.ZERO
var ui: ColorRect

func _ready() -> void:
    layer = 100
    get_tree().paused = false
    Progress.load_once()
    var bg := ColorRect.new()
    ui = bg
    bg.color = Color("0b0d17")
    bg.theme = Style.theme()
    add_child(bg)
    box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 16)
    bg.add_child(box)
    title = Style.display_label("STREETWISE II\nCURFEW", 40, Style.GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(title)
    sub = Label.new()
    sub.text = "Bring Nicole and Stella home again."
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(sub)
    continue_button = _button("Continue · Level %d" % Progress.unlocked)
    continue_button.pressed.connect(func(): _begin(Progress.unlocked))
    new_button = _button("New Run · Level 1")
    new_button.pressed.connect(func(): _begin(1))
    note = Label.new()
    note.text = "New Run keeps your unlocked levels."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(note)
    box.resized.connect(_center)
    box.minimum_size_changed.connect(_fit, CONNECT_DEFERRED)
    get_window().size_changed.connect(_layout)
    _layout()
    var debug_level := maxi(0, int(OS.get_environment("CURFEW_LEVEL")))
    if debug_level > 0 or Progress.unlocked <= 1:
        _begin.call_deferred(debug_level if debug_level > 0 else 1)
    else:
        continue_button.grab_focus()
        if OS.has_feature("web"):
            JavaScriptBridge.eval("window.curfewMenuReady&&window.curfewMenuReady()", true)

func _button(text: String) -> Button:
    var button := Style.pointer_button(text)
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_stylebox_override("focus", Style._box(Color(0, 0, 0, 0), Style.GOLD))
    box.add_child(button)
    return button

func _layout() -> void:
    window_size = get_window().size
    var screen := screen_size_override
    if screen == Vector2.ZERO:
        screen = Style.canvas_size(get_viewport())
    screen = screen.max(Vector2(240, 240))
    var compact := screen.x < 1000.0 or screen.y < 600.0
    var unit := 1.5 if compact else 1.0
    get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if compact else Window.CONTENT_SCALE_ASPECT_KEEP
    get_window().content_scale_size = Vector2i(screen * unit) if compact else Vector2i(1280, 720)
    ui.scale = Vector2.ONE * unit
    ui.size = get_viewport().get_visible_rect().size / unit
    var width: float = minf(520.0, get_viewport().get_visible_rect().size.x / unit - 32.0)
    box.custom_minimum_size.x = width
    box.size.x = width
    title.add_theme_font_size_override("font_size", 28 if compact else 40)
    title.custom_minimum_size.x = width
    title.size.x = width
    for label in [sub, note]:
        label.add_theme_font_size_override("font_size", 16 if compact else 20)
        label.custom_minimum_size.x = width
        label.size.x = width
    for button in [continue_button, new_button]:
        button.custom_minimum_size = Vector2(width, 48 if compact else 64)
        button.add_theme_font_size_override("font_size", 18 if compact else 22)
    box.reset_size()
    _center()

func _fit() -> void:
    box.reset_size()
    _center()

func _center() -> void:
    if box != null:
        box.position = (ui.size - box.size) * 0.5

func _begin(n: int) -> void:
    if starting:
        return
    starting = true
    continue_button.hide()
    new_button.hide()
    note.hide()
    sub.text = "Starting level %d…" % n
    Main.level_number = n
    Main.checkpoint_enabled = OS.get_environment("CURFEW_LEVEL") == ""
    Main.retry_seed = -1
    Main.retry_state = {}
    Main.retry_pos = Vector2.INF
    var game = load("res://scenes/Main.tscn").instantiate()
    game.presentation_size_override = screen_size_override
    game.boot_progress.connect(func(stage, fraction): sub.text = "Starting level %d · %s %d%%" % [n, stage, roundi(fraction * 100)])
    get_tree().root.add_child(game)
    if not game.is_booted:
        await game.booted
    # The chooser is not the scene used for R/retry: the selected game is.
    get_tree().current_scene = game
    queue_free()
