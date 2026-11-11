extends Control
## Exploration-only world-card carrier. No Session data or game action lives here.
## The parent supplies painted Controls and decides what entering a card means.

signal card_chosen(index: int)
signal focus_changed(index: int)

const CARD_SIZE := Vector2(260.0, 390.0)
const FLAT_GAP := 28.0
const DRAG_THRESHOLD := 9.0
const DRAG_STEP := 108.0
const VISIBLE_NEIGHBOURS := 5.0

var focus_index: int = 0
var cards: Array[Control] = []
var _visual_focus := 0.0
var _goal_focus := 0.0
var _pressed := false
var _dragging := false
var _press_position := Vector2.ZERO
var _press_focus := 0.0
var _pressed_card := -1
var _hovered_card := -1
var _last_pointer := Vector2.ZERO
var _last_motion_usec: int = 0
var _velocity_x := 0.0
var _wheel_units := 0.0
var _pan_units := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(_layout_cards)
	mouse_exited.connect(_clear_hover)
	_layout_cards()


func configure(new_cards: Array[Control]) -> void:
	# Ownership is transferred to this carrier. Supplied controls are never cloned.
	_pressed = false
	_dragging = false
	_hovered_card = -1
	for old_card: Control in cards:
		if is_instance_valid(old_card) and not new_cards.has(old_card):
			if old_card.get_parent() == self:
				remove_child(old_card)
			old_card.queue_free()
	cards = new_cards.duplicate()
	for card: Control in cards:
		if card.get_parent() == null:
			add_child(card)
		elif card.get_parent() != self:
			card.reparent(self, false)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE * 0.5
		_disable_card_input(card)
	focus_index = clampi(focus_index, 0, maxi(0, cards.size() - 1))
	_visual_focus = float(focus_index)
	_goal_focus = _visual_focus
	_layout_cards()
	focus_changed.emit(focus_index)


func set_focus(index: int, animate: bool = true) -> void:
	if cards.is_empty():
		return
	var next := clampi(index, 0, cards.size() - 1)
	_goal_focus = float(next)
	if not animate:
		_visual_focus = _goal_focus
	_set_focus_index(next)
	_layout_cards()


func is_stacked() -> bool:
	return cards.size() * CARD_SIZE.x + maxi(0, cards.size() - 1) * FLAT_GAP > size.x - 32.0


func _disable_card_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_disable_card_input(child)


func _process(delta: float) -> void:
	if not _dragging and absf(_visual_focus - _goal_focus) > 0.001:
		_visual_focus = lerpf(_visual_focus, _goal_focus, 1.0 - exp(-18.0 * delta))
		if absf(_visual_focus - _goal_focus) < 0.001:
			_visual_focus = _goal_focus
		_layout_cards()


func _layout_cards() -> void:
	if cards.is_empty():
		return
	var stacked := is_stacked()
	var centre_x := (size.x - CARD_SIZE.x) * 0.5
	var base_y := maxf(0.0, (size.y - CARD_SIZE.y) * 0.5)
	var flat_width := cards.size() * CARD_SIZE.x + (cards.size() - 1) * FLAT_GAP
	var flat_left := (size.x - flat_width) * 0.5
	# Preserve a generous first exposed edge, then smaller edges deeper in the pile.
	var max_side := maxf(0.0, centre_x - 16.0)
	var first_step := minf(CARD_SIZE.x * 0.57, max_side)
	var further_step := maxf(0.0, (max_side - first_step) / (VISIBLE_NEIGHBOURS - 1.0))
	for i: int in range(cards.size()):
		var card: Control = cards[i]
		var distance := float(i) - _visual_focus
		var depth := absf(distance)
		var shown := not stacked or depth <= VISIBLE_NEIGHBOURS + 0.25
		card.visible = shown
		if not shown:
			continue
		var x := flat_left + float(i) * (CARD_SIZE.x + FLAT_GAP)
		var y := base_y
		if stacked:
			var offset := minf(depth, 1.0) * first_step + maxf(depth - 1.0, 0.0) * further_step
			x = centre_x + signf(distance) * offset
			y += minf(depth, VISIBLE_NEIGHBOURS) * 1.4 - 5.0 * maxf(0.0, 1.0 - depth)
		else:
			y -= 5.0 if i == focus_index or i == _hovered_card else 0.0
		card.position = Vector2(x, maxf(0.0, y))
		card.rotation = 0.0
		card.scale = Vector2.ONE
		card.z_index = 1000 - int(roundf(depth * 20.0))
		card.modulate = Color(1.0, 1.0, 1.0, clampf((VISIBLE_NEIGHBOURS + 0.25 - depth) * 4.0, 0.0, 1.0) if stacked else 1.0)
		var focused := i == focus_index
		var hovered := i == _hovered_card
		if not card.has_meta("fan_stacked") or card.get_meta("fan_focused", false) != focused or card.get_meta("fan_hovered", false) != hovered or card.get_meta("fan_stacked", false) != stacked:
			card.set_meta("fan_focused", focused)
			card.set_meta("fan_hovered", hovered)
			card.set_meta("fan_stacked", stacked)
			card.queue_redraw()


func _set_focus_index(value: int) -> void:
	if focus_index == value:
		return
	focus_index = value
	focus_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if cards.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grab_focus()
			_pressed = true
			_dragging = false
			_press_position = event.position
			_last_pointer = event.position
			_press_focus = _visual_focus
			_pressed_card = _card_at(event.position)
			_last_motion_usec = Time.get_ticks_usec()
			_velocity_x = 0.0
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			grab_focus()
			var direction := -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
			_wheel_units += direction * event.factor
			var steps := int(_wheel_units)
			if steps != 0:
				_wheel_units -= float(steps)
				set_focus(focus_index + steps)
			accept_event()
	elif event is InputEventMouseMotion and not _pressed:
		var hovered := _card_at(event.position)
		if hovered != _hovered_card:
			_hovered_card = hovered
			_layout_cards()
	elif event is InputEventPanGesture:
		grab_focus()
		_pan_units += event.delta.x if absf(event.delta.x) >= absf(event.delta.y) else event.delta.y
		var steps := int(_pan_units / 1.6)
		if steps != 0:
			_pan_units -= float(steps) * 1.6
			set_focus(focus_index + steps)
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			set_focus(focus_index - 1)
			accept_event()
		elif event.keycode == KEY_RIGHT:
			set_focus(focus_index + 1)
			accept_event()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not event.echo:
			card_chosen.emit(focus_index)
			accept_event()


func _input(event: InputEvent) -> void:
	# Capture only an already-started gesture, including its release beyond the carrier.
	if not _pressed:
		return
	if not is_visible_in_tree():
		_pressed = false
		_dragging = false
		return
	if event is InputEventMouseMotion:
		var pointer := get_local_mouse_position()
		var elapsed := maxf(float(Time.get_ticks_usec() - _last_motion_usec) / 1000000.0, 0.001)
		_velocity_x = lerpf(_velocity_x, (pointer.x - _last_pointer.x) / elapsed, 0.4)
		_last_pointer = pointer
		_last_motion_usec = Time.get_ticks_usec()
		if not _dragging and absf(pointer.x - _press_position.x) >= DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_visual_focus = clampf(_press_focus - (pointer.x - _press_position.x) / DRAG_STEP, 0.0, float(cards.size() - 1))
			_set_focus_index(clampi(int(roundf(_visual_focus)), 0, cards.size() - 1))
			_layout_cards()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_gesture(get_local_mouse_position())
		get_viewport().set_input_as_handled()


func _finish_gesture(pointer: Vector2) -> void:
	_pressed = false
	if _dragging:
		_dragging = false
		if Time.get_ticks_usec() - _last_motion_usec > 90000:
			_velocity_x = 0.0
		var coast := clampf(-_velocity_x * 0.065 / DRAG_STEP, -2.0, 2.0)
		set_focus(int(roundf(_visual_focus + coast)))
		return
	var released_card := _card_at(pointer)
	if released_card < 0 or released_card != _pressed_card:
		return
	# Exposed edges bring a card forward; only a full front card opens its world.
	if is_stacked() and released_card != focus_index:
		set_focus(released_card)
	else:
		set_focus(released_card)
		card_chosen.emit(released_card)


func _card_at(pointer: Vector2) -> int:
	if not Rect2(Vector2.ZERO, size).has_point(pointer):
		return -1
	var best := -1
	var highest_z := -2147483648
	for i: int in range(cards.size()):
		var card: Control = cards[i]
		if not card.visible or card.modulate.a < 0.2:
			continue
		var local := card.get_transform().affine_inverse() * pointer
		if Rect2(Vector2.ZERO, card.size).has_point(local) and card.z_index >= highest_z:
			best = i
			highest_z = card.z_index
	return best


func _clear_hover() -> void:
	_hovered_card = -1
	_layout_cards()
