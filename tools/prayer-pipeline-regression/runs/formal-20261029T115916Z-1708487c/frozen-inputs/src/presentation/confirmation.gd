extends Control
## A single-canvas modal keeps logical size, focus and keyboard routing stable.
signal confirmed
signal canceled
var title: String = "确认后果"
var ok_button_text: String = "确认"
var cancel_button_text: String = "返回"
var _ok: Button
var _cancel: Button
var body: Label
var scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.6); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel := PanelContainer.new(); panel.position = Vector2(280, 150); panel.size = Vector2(720, 420); add_child(panel)
	var frame := VBoxContainer.new(); panel.add_child(frame)
	var heading := Label.new(); heading.text = title; heading.theme_type_variation = "Heading"; frame.add_child(heading)
	scroll = ScrollContainer.new(); scroll.custom_minimum_size.y = 300; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.focus_mode = Control.FOCUS_ALL; scroll.follow_focus = true; frame.add_child(scroll)
	body = Label.new(); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
	var buttons := HBoxContainer.new(); frame.add_child(buttons)
	_ok = Button.new(); _ok.text = ok_button_text; _ok.custom_minimum_size.y = 38; _ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL; buttons.add_child(_ok)
	_cancel = Button.new(); _cancel.text = cancel_button_text; _cancel.custom_minimum_size.y = 38; _cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; buttons.add_child(_cancel)
	_ok.pressed.connect(func() -> void: hide(); confirmed.emit())
	_cancel.pressed.connect(_dismiss)
	hide()

func popup_centered(_dimensions: Vector2i = Vector2i.ZERO) -> void:
	scroll.scroll_vertical = 0; show(); move_to_front(); _cancel.grab_focus()

func get_cancel_button() -> Button: return _cancel
func get_ok_button() -> Button: return _ok

func _dismiss() -> void:
	hide(); canceled.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed: return
	if event.keycode == KEY_ESCAPE:
		_dismiss(); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB:
		var controls: Array[Control] = [_cancel, _ok, scroll]
		var index: int = controls.find(get_viewport().gui_get_focus_owner())
		controls[posmod(index + (-1 if event.shift_pressed else 1), controls.size())].grab_focus(); get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		scroll.scroll_vertical += -240 if event.keycode == KEY_PAGEUP else 240; get_viewport().set_input_as_handled()
