extends Node
# Pausing: P or Esc stops everything (the whole tree is paused; only this node keeps
# running) and shows a PAUSED card. The game also pauses by itself when the window loses
# focus or the browser tab is hidden, so switching away never costs a life. Only while a run
# is in progress.

const Style := preload("res://scripts/Style.gd")

var main
var layer: CanvasLayer

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
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(dim)
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 16)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(box)
    var title: Label = Style.display_label("PAUSED", 80, Style.GOLD, 12)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var sub := Label.new()
    sub.text = "Press P to carry on"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 26)
    box.add_child(sub)

func is_paused() -> bool:
    return get_tree().paused

func pause() -> void:
    if main == null or not main.is_booted or main.state != "play" or get_tree().paused:
        return
    get_tree().paused = true
    layer.visible = true

func resume() -> void:
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
