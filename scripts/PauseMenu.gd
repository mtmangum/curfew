extends Node
# Pausing: P or Esc stops everything (the whole tree is paused; only this node keeps
# running) and shows a PAUSED card. The game also pauses by itself when the window loses
# focus or the browser tab is hidden, so switching away never costs a life. Only while a run
# is in progress.

const Style := preload("res://scripts/Style.gd")

var main
var layer: CanvasLayer
var box: VBoxContainer
var resume_button: Button
var sound_button: Button
var window_size := Vector2i.ZERO

func setup(game) -> void:
    main = game
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = CanvasLayer.new()
    layer.layer = 80
    layer.visible = false
    add_child(layer)
    var dim := ColorRect.new()
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.02, 0.03, 0.08, 0.62)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.theme = Style.theme()
    layer.add_child(dim)
    box = VBoxContainer.new()
    box.custom_minimum_size.x = 320
    box.add_theme_constant_override("separation", 16)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dim.add_child(box)
    var title: Label = Style.display_label("PAUSED", 48, Style.GOLD, 8)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var sub := Label.new()
    sub.text = "Resume, or press P / Esc"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 20)
    box.add_child(sub)
    resume_button = Style.pointer_button("Resume", 320)
    resume_button.pressed.connect(resume)
    box.add_child(resume_button)
    sound_button = Style.pointer_button("Sound ON", 320)
    sound_button.pressed.connect(func():
        main.toggle_sound()
        _sync_sound())
    box.add_child(sound_button)

func _sync_sound() -> void:
    sound_button.text = "Sound OFF" if AudioServer.is_bus_mute(0) else "Sound ON"

func _process(_delta: float) -> void:
    if layer.visible and window_size != get_window().size:
        _layout()

func _layout() -> void:
    window_size = get_window().size
    var view_size: Vector2 = get_viewport().get_visible_rect().size
    var box_size: Vector2 = box.get_combined_minimum_size()
    var factor: float = minf(Style.pointer_scale(get_viewport()), minf((view_size.x - 32.0) / box_size.x, (view_size.y - 32.0) / box_size.y))
    box.scale = Vector2.ONE * factor
    box.position = (view_size - box_size * factor) * 0.5

func pause() -> void:
    if main == null or not main.is_booted or main.state != "play" or get_tree().paused:
        return
    get_tree().paused = true
    layer.visible = true
    main.player.pointer_down = false
    _sync_sound()
    _layout()

func resume() -> void:
    main.player.pointer_down = false
    get_tree().paused = false
    layer.visible = false

func toggle() -> void:
    if get_tree().paused:
        resume()
    else:
        pause()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_P or event.keycode == KEY_ESCAPE):
        toggle()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        pause()  # switched away: don't let the cops keep walking

func _exit_tree() -> void:
    if is_inside_tree():
        get_tree().paused = false
