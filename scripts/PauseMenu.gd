extends Node
# Pausing: P or Esc stops everything (the whole tree is paused; only this node keeps
# running) and shows a PAUSED card. The game also pauses by itself when the window loses
# focus or the browser tab is hidden, so switching away never costs a life. Only while a run
# is in progress.

const Style := preload("res://scripts/Style.gd")
const Clues := preload("res://scripts/Clues.gd")
const Hud := preload("res://scripts/Hud.gd")

var main
var layer: CanvasLayer
var box: VBoxContainer
var resume_button: Button
var sound_button: Button
var controls_button: Button
var guide_button: Button
var actions: GridContainer
var back_button: Button
var help_label: Label
var title: Label
var sub: Label
var help_open := false
var guide_open := false
var guide_ids: Array[String] = []
var guide_index := 0
var guide_nav: HBoxContainer
var guide_name: Label
var guide_prev: Button
var guide_next: Button
var guide_card: PanelContainer
var guide_icon: Hud.ClueIcon
var guide_text: Label
var last_box_size := Vector2.ZERO
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
    dim.color = Color(0.02, 0.03, 0.08, 0.92)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.theme = Style.theme()
    layer.add_child(dim)
    box = VBoxContainer.new()
    box.custom_minimum_size.x = 320
    box.add_theme_constant_override("separation", 16)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dim.add_child(box)
    title = Style.display_label("PAUSED", 48, Style.GOLD, 8)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    sub = Label.new()
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
    actions = GridContainer.new()
    actions.columns = 2
    actions.add_theme_constant_override("h_separation", 8)
    actions.add_theme_constant_override("v_separation", 10)
    box.add_child(actions)
    controls_button = Style.pointer_button("Controls", 320)
    controls_button.pressed.connect(func(): _show_help(true))
    actions.add_child(controls_button)
    guide_button = Style.pointer_button("Field guide", 320)
    guide_button.pressed.connect(func(): _show_guide(true))
    actions.add_child(guide_button)
    help_label = Label.new()
    help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help_label.text = "Tap ground to walk. Hold to steer.\nStella points home; you must walk there.\nStella leads home every so often; press H to ask for a hint.\nSneak toggles quiet walking. Tap an item to use it.\n\nKeys: WASD/arrows move, Shift sneaks, E uses items, H asks home, F toggles the torch, N mutes, Tab changes key directions, R retries (Shift+R starts fresh)."
    help_label.hide()
    box.add_child(help_label)
    guide_nav = HBoxContainer.new()
    guide_nav.add_theme_constant_override("separation", 10)
    guide_nav.hide()
    box.add_child(guide_nav)
    guide_prev = Style.pointer_button("‹ Prev", 88)
    guide_prev.pressed.connect(func(): _browse_guide(-1))
    guide_nav.add_child(guide_prev)
    guide_name = Label.new()
    guide_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    guide_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    guide_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    guide_nav.add_child(guide_name)
    guide_next = Style.pointer_button("Next ›", 88)
    guide_next.pressed.connect(func(): _browse_guide(1))
    guide_nav.add_child(guide_next)
    guide_card = PanelContainer.new()
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.07, 0.08, 0.13, 0.98)
    card_style.set_content_margin_all(12)
    card_style.set_corner_radius_all(4)
    guide_card.add_theme_stylebox_override("panel", card_style)
    guide_card.hide()
    box.add_child(guide_card)
    var card_row := HBoxContainer.new()
    card_row.add_theme_constant_override("separation", 14)
    guide_card.add_child(card_row)
    guide_icon = Hud.ClueIcon.new()
    card_row.add_child(guide_icon)
    guide_text = Label.new()
    guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card_row.add_child(guide_text)
    back_button = Style.pointer_button("Back", 320)
    back_button.pressed.connect(func(): _show_help(false))
    back_button.hide()
    box.add_child(back_button)

func _show_help(on: bool) -> void:
    help_open = on
    guide_open = false
    _sync_page()
    _layout()

func _sync_page() -> void:
    title.text = "FIELD GUIDE" if guide_open else "CONTROLS" if help_open else "PAUSED"
    sub.visible = not help_open and not guide_open
    resume_button.visible = not guide_open
    sound_button.visible = sub.visible
    controls_button.visible = sub.visible
    guide_button.visible = sub.visible
    actions.visible = sub.visible
    help_label.visible = help_open
    guide_nav.visible = guide_open
    guide_card.visible = guide_open
    back_button.visible = help_open or guide_open

func _show_guide(on: bool) -> void:
    guide_open = on
    help_open = false
    if on:
        guide_ids = Clues.guide_ids(main.level)
        var context: String = "item_" + main.carried if main.carried != "" else main.clues.last_id
        guide_index = maxi(0, guide_ids.find("bin" if context == "bin_quiet" else context if context != "" else "scent"))
        _browse_guide(0)
    _sync_page()
    _layout()

func _browse_guide(step: int) -> void:
    guide_index = posmod(guide_index + step, guide_ids.size())
    var id: String = guide_ids[guide_index]
    guide_name.text = Clues.title(id)
    guide_icon.kind = Clues.catalog(id).icon
    guide_icon.queue_redraw()
    guide_text.text = Clues.display_text(Clues.catalog(id).text, main.presentation.compact or main.presentation.pointer_mode)
    _layout()

func _sync_sound() -> void:
    sound_button.text = "Sound OFF" if AudioServer.is_bus_mute(0) else "Sound ON"

func _process(_delta: float) -> void:
    if layer.visible and (window_size != get_window().size or last_box_size != box.get_combined_minimum_size()):
        _layout()

func _layout() -> void:
    window_size = get_window().size
    var unit: float = main.presentation.unit
    var view_size: Vector2 = get_viewport().get_visible_rect().size / unit
    var compact: bool = main.presentation.compact
    box.custom_minimum_size.x = minf(520 if (help_open or guide_open) and view_size.x > view_size.y else 320, view_size.x - 24)
    box.add_theme_constant_override("separation", 10 if compact else 16)
    title.add_theme_font_size_override("font_size", 30 if compact else 48)
    sub.add_theme_font_size_override("font_size", 16 if compact else 20)
    help_label.add_theme_font_size_override("font_size", 16 if compact else 18)
    help_label.custom_minimum_size.x = box.custom_minimum_size.x
    help_label.size.x = box.custom_minimum_size.x
    for button in [resume_button, sound_button, back_button]:
        button.custom_minimum_size = Vector2(box.custom_minimum_size.x, 48 if compact else 64)
        button.add_theme_font_size_override("font_size", 16 if compact else 20)
    for button in [controls_button, guide_button]:
        button.custom_minimum_size = Vector2((box.custom_minimum_size.x - 8) * 0.5, 48 if compact else 64)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 16 if compact else 20)
    for button in [guide_prev, guide_next]:
        button.custom_minimum_size = Vector2(88, 48 if compact else 64)
        button.add_theme_font_size_override("font_size", 16 if compact else 20)
    guide_name.add_theme_font_size_override("font_size", 16 if compact else 18)
    guide_text.add_theme_font_size_override("font_size", 16 if compact else 18)
    guide_icon.custom_minimum_size = Vector2.ONE * (28 if compact else 44)
    guide_text.custom_minimum_size.x = box.custom_minimum_size.x - 24 - guide_icon.custom_minimum_size.x - 14
    guide_text.size.x = guide_text.custom_minimum_size.x
    if guide_open:
        guide_text.text = Clues.display_text(Clues.catalog(guide_ids[guide_index]).text, compact or main.presentation.pointer_mode)
    box.reset_size()
    var box_size: Vector2 = box.get_combined_minimum_size()
    last_box_size = box_size
    var factor: float = minf(1.0, minf((view_size.x - 24) / box_size.x, (view_size.y - 24) / box_size.y))
    box.scale = Vector2.ONE * factor * unit
    box.position = (view_size - box_size * factor) * 0.5 * unit

func pause() -> void:
    if main == null or not main.is_booted or main.state != "play" or get_tree().paused:
        return
    get_tree().paused = true
    layer.visible = true
    main.player.pointer_down = false
    _sync_sound()
    _show_help(false)

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
