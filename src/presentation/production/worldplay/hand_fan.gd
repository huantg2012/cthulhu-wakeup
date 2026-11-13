extends Control
## Fixed right-over-left deck. Browsing changes only lift, never order or x.
signal focus_changed(index: int)
signal card_hovered(index: int)

const HAND_SIZE := Vector2(148, 198)
const TABLE_MARGIN := 8.0
const REST_Y := 58.0
const FLAT_STEP := 164.0
const STACK_LIFT := 56.0
const FLAT_LIFT := 12.0
const HOVER_DWELL := 0.05
const SPRING_RATE := 25.0
const DRAG_THRESHOLD := 9.0
const DRAG_STEP := 52.0
const LIFT_THRESHOLD := 22.0
const RETURN_DURATION := 0.18

var cards: Array[Control] = []
var focus_index := 0
var allow_play := true
# Caller compatibility only: this value never controls x or sibling order.
var _visual_focus := 0.0
var _blocked := false
var _pressed := false
var _dragging := false
var _pressed_card := -1
var _hovered_card := -1
var _browse_index := -1
var _hover_candidate := -1
var _hover_time := 0.0
var _press_position := Vector2.ZERO
var _press_focus := 0.0
var _grab_offset := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _last_motion_usec := 0
var _velocity_x := 0.0
var _wheel_units := 0.0
var _pan_units := 0.0
var _lift_armed := false
var _native_drag_index := -1
var _drag_source_lift := 0.0
var _drag_face: WeakRef
var _drag_pointer := Vector2.ZERO
var _drag_transform := Transform2D.IDENTITY
var _return_layer: CanvasLayer
var _return_face: Control
var _return_index := -1
var _return_time := 0.0
var _return_from := Transform2D.IDENTITY
var _lifts := PackedFloat32Array()
var _lift_velocities := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(_layout_cards)
	mouse_exited.connect(_clear_hover)
	visibility_changed.connect(_visibility_changed)
	_layout_cards()


func configure(new_cards: Array[Control]) -> void:
	_cancel_gesture()
	_clear_return_ghost()
	_clear_hover()
	for old_card: Control in cards:
		if is_instance_valid(old_card) and not new_cards.has(old_card):
			if old_card.get_parent() == self:
				remove_child(old_card)
			old_card.queue_free()
	cards = new_cards.duplicate()
	_lifts.resize(cards.size())
	_lifts.fill(0.0)
	_lift_velocities.resize(cards.size())
	_lift_velocities.fill(0.0)
	for card: Control in cards:
		if card.get_parent() == null:
			add_child(card)
		elif card.get_parent() != self:
			card.reparent(self, false)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.size = HAND_SIZE
		# Install draw/hit order once. Hover and dragging never promote a card.
		card.z_index = 0
		move_child(card, -1)
		_disable_card_input(card)
		if _has_property(card, "hover_enabled"):
			card.set("hover_enabled", false)
		if card.has_method("set_card_hover"):
			card.call("set_card_hover", false)
	focus_index = clampi(focus_index, 0, maxi(0, cards.size() - 1))
	_visual_focus = float(focus_index)
	_layout_cards()
	focus_changed.emit(focus_index)


func set_blocked(value: bool) -> void:
	if _blocked == value:
		return
	_blocked = value
	if value:
		_cancel_gesture()
		_clear_hover()


func set_focus(index: int, animate: bool = true) -> void:
	if cards.is_empty() or _blocked:
		return
	var next := clampi(index, 0, cards.size() - 1)
	_browse_index = next
	_hovered_card = -1
	_hover_candidate = -1
	_hover_time = 0.0
	_visual_focus = float(next)
	_set_focus_index(next)
	if not animate:
		for i: int in cards.size():
			_lifts[i] = _lift_height() if i == next else 0.0
			_lift_velocities[i] = 0.0
	_layout_cards()


func _set_focus_index(index: int) -> void:
	if focus_index == index:
		return
	focus_index = index
	focus_changed.emit(index)


func _step() -> float:
	if cards.size() <= 1:
		return FLAT_STEP
	return minf(FLAT_STEP, maxf(0.0, size.x - TABLE_MARGIN * 2.0 - HAND_SIZE.x) / float(cards.size() - 1))


func _left() -> float:
	return (size.x - HAND_SIZE.x - float(maxi(0, cards.size() - 1)) * _step()) * 0.5


func _rest_y() -> float:
	# A 260px container reserves 56px of lift and a 4px heel. Legacy short
	# arrival containers still show the complete card, with a smaller lift.
	return clampf(size.y - HAND_SIZE.y - 2.0, 0.0, REST_Y)


func _lift_height() -> float:
	return minf(STACK_LIFT if is_stacked() else FLAT_LIFT, maxf(0.0, _rest_y() - 2.0))


func is_stacked() -> bool:
	return cards.size() > 1 and _step() < HAND_SIZE.x


func _process(delta: float) -> void:
	if _native_drag_index >= 0:
		_remember_drag_transform()
	if _hover_candidate >= 0 and not _blocked and not _pressed and _native_drag_index < 0:
		_hover_time += delta
		if _hover_time >= HOVER_DWELL:
			var next := _hover_candidate
			set_focus(next)
			_hovered_card = next
			card_hovered.emit(next)
	if cards.is_empty():
		return
	var changed := false
	var amount := _lift_height()
	# Exact critical damping retains velocity through rapid target changes.
	# No restarted tweens, transforms or z-order exchanges are involved.
	var decay := exp(-SPRING_RATE * delta)
	for i: int in cards.size():
		var target := amount if i == _browse_index and not _blocked else 0.0
		if i == _native_drag_index:
			target = _drag_source_lift
		var offset := _lifts[i] - target
		if absf(offset) < 0.01 and absf(_lift_velocities[i]) < 0.05:
			if _lifts[i] != target:
				_lifts[i] = target
				changed = true
			_lift_velocities[i] = 0.0
			continue
		var travel := (_lift_velocities[i] + SPRING_RATE * offset) * delta
		_lifts[i] = clampf(target + (offset + travel) * decay, 0.0, amount)
		_lift_velocities[i] = (_lift_velocities[i] - SPRING_RATE * travel) * decay
		changed = true
	if changed:
		_layout_cards()
	_update_return_ghost(delta)


func _layout_cards() -> void:
	if cards.is_empty() or _lifts.size() != cards.size():
		return
	var spacing := _step()
	var origin := _left()
	var resting := _rest_y()
	var maximum_lift := _lift_height()
	for i: int in cards.size():
		var card: Control = cards[i]
		card.visible = true
		card.size = HAND_SIZE
		card.position = Vector2(origin + float(i) * spacing, resting - _lifts[i])
		card.scale = Vector2.ONE
		card.rotation = 0.0
		var exposed := minf(HAND_SIZE.x, spacing) if i < cards.size() - 1 else HAND_SIZE.x
		var side := -1 if exposed < HAND_SIZE.x else 0
		if card.has_method("set_exposure"):
			card.call("set_exposure", side, exposed)
		else:
			_legacy_exposure(card, side, exposed)
		var peek := _lifts[i] / maximum_lift if maximum_lift > 0.0 else 0.0
		if card.has_method("set_peek_amount"):
			card.modulate = Color.WHITE
			card.call("set_peek_amount", peek)
		else:
			var light := 1.0 + peek * 0.045
			card.modulate = Color(light, light, light, 1.0)
		card.set_meta("fan_stacked", is_stacked())
		card.set_meta("fan_focused", i == _browse_index)
		card.queue_redraw()


func _legacy_exposure(card: Control, side: int, exposed: float) -> void:
	var reading := smoothstep(HAND_SIZE.x - 40.0, HAND_SIZE.x, exposed)
	for label_name: String in ["CardType", "CardTitle", "CardDetail"]:
		var label := card.get_node_or_null(label_name) as Control
		if label != null:
			label.modulate.a = reading
	for side_name: String in ["LeftSpine", "RightSpine"]:
		var spine := card.get_node_or_null(side_name) as Control
		if spine != null:
			spine.visible = side < 0 and side_name == "LeftSpine" and exposed >= 24.0
			spine.modulate.a = 1.0 - reading


func _card_at(pointer: Vector2) -> int:
	if not Rect2(Vector2.ZERO, size).has_point(pointer):
		return -1
	# Baseline left-edge intervals do not move with hover animation.
	if pointer.y >= _rest_y() and pointer.y < _rest_y() + HAND_SIZE.y:
		for i: int in range(cards.size() - 1, -1, -1):
			var width := minf(_step(), HAND_SIZE.x) if i < cards.size() - 1 else HAND_SIZE.x
			var left := _left() + float(i) * _step()
			if pointer.x >= left and pointer.x < left + width:
				return i
		return -1
	# In the lifted shoulder band, use the actual fixed-order visible cards.
	for i: int in range(cards.size() - 1, -1, -1):
		if cards[i].visible and cards[i].get_rect().has_point(pointer):
			return i
	return -1


func _queue_hover(index: int) -> void:
	if index < 0:
		_clear_hover()
	elif index == _hovered_card and index == _browse_index:
		# Returning to the raised card cancels another shoulder's pending dwell.
		_hover_candidate = -1
		_hover_time = 0.0
	elif index != _hover_candidate:
		_hover_candidate = index
		_hover_time = 0.0


func _clear_hover() -> void:
	_hover_candidate = -1
	_hover_time = 0.0
	_hovered_card = -1
	if not _pressed and _native_drag_index < 0:
		_browse_index = -1
	card_hovered.emit(-1)


func _gui_input(event: InputEvent) -> void:
	if _blocked or cards.is_empty() or _native_drag_index >= 0:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var index := _card_at(event.position)
			if index < 0:
				return
			grab_focus()
			_pressed = true
			_dragging = false
			_lift_armed = false
			_pressed_card = index
			_press_position = event.position
			_grab_offset = event.position - cards[index].position
			_last_pointer = event.position
			_last_motion_usec = Time.get_ticks_usec()
			_velocity_x = 0.0
			set_focus(index)
			_press_focus = float(index)
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
		_queue_hover(_card_at(event.position))
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
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			# Selection is never a game action; read-only arrival owns its Enter.
			accept_event()


func _input(event: InputEvent) -> void:
	if _native_drag_index >= 0:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_viewport().gui_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion or event is InputEventMouseButton:
			# GUI may delete its preview before DRAG_END. Preserve the final
			# release transform even when that release arrives between frames.
			_remember_drag_transform()
			_drag_transform.origin += event.position - _drag_pointer
			_drag_pointer = event.position
		return
	if _blocked or not _pressed:
		return
	if not is_visible_in_tree():
		_cancel_gesture()
		return
	if event is InputEventMouseMotion:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var delta := pointer - _press_position
		if allow_play and not _dragging and delta.y < -LIFT_THRESHOLD and absf(delta.y) > absf(delta.x) * 1.2:
			_last_pointer = pointer
			_lift_armed = true
			_start_native_drag()
			get_viewport().set_input_as_handled()
			return
		var elapsed := maxf(float(Time.get_ticks_usec() - _last_motion_usec) / 1000000.0, 0.001)
		_velocity_x = lerpf(_velocity_x, (pointer.x - _last_pointer.x) / elapsed, 0.4)
		_last_pointer = pointer
		_last_motion_usec = Time.get_ticks_usec()
		if not _dragging and absf(delta.x) >= DRAG_THRESHOLD and absf(delta.x) >= absf(delta.y) * 0.75:
			_dragging = true
		if _dragging:
			var browse := clampf(_press_focus - delta.x / DRAG_STEP, 0.0, float(cards.size() - 1))
			set_focus(roundi(browse))
			_visual_focus = browse
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_gesture(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func _finish_gesture(pointer: Vector2) -> void:
	_pressed = false
	_lift_armed = false
	if _dragging:
		_dragging = false
		if Time.get_ticks_usec() - _last_motion_usec > 90000:
			_velocity_x = 0.0
		var coast := clampf(-_velocity_x * 0.035 / DRAG_STEP, -1.0, 1.0)
		set_focus(roundi(_visual_focus + coast))
	elif _card_at(pointer) == _pressed_card:
		set_focus(_pressed_card)
	_pressed_card = -1


func _payload(index: int) -> Dictionary:
	if index < 0 or index >= cards.size():
		return {}
	var value: Variant = cards[index].get("payload")
	return value if value is Dictionary else {}


func _start_native_drag() -> void:
	var payload := _payload(_pressed_card)
	if _blocked or not allow_play or not _lift_armed or payload.is_empty():
		return
	var holder := _drag_preview(_pressed_card)
	_begin_native_drag()
	force_drag({"worldplay_card": payload}, holder)
	_remember_drag_transform()


func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload := _payload(_pressed_card)
	if _blocked or not allow_play or not _lift_armed or payload.is_empty():
		return null
	var holder := _drag_preview(_pressed_card)
	_begin_native_drag()
	set_drag_preview(holder)
	_remember_drag_transform()
	return {"worldplay_card": payload}


func _begin_native_drag() -> void:
	_clear_return_ghost()
	_native_drag_index = _pressed_card
	_drag_pointer = get_global_transform_with_canvas() * _last_pointer
	_drag_source_lift = _lifts[_pressed_card]
	_lift_velocities[_pressed_card] = 0.0
	_pressed = false
	_dragging = false
	_lift_armed = false
	_hover_candidate = -1


func _drag_preview(index: int) -> Control:
	var preview := _complete_face(index)
	preview.position = -_grab_offset
	var holder := Control.new()
	holder.add_child(preview)
	_disable_card_input(holder)
	_drag_face = weakref(preview)
	return holder


func _complete_face(index: int) -> Control:
	var selected := cards[index]
	var preview: Control
	if selected.has_method("make_drag_preview"):
		preview = selected.call("make_drag_preview") as Control
	if preview == null:
		preview = selected.duplicate() as Control
		for property_name: String in ["palette", "seed_value"]:
			if _has_property(selected, property_name):
				preview.set(property_name, selected.get(property_name))
	if _has_property(preview, "hover_enabled"):
		preview.set("hover_enabled", false)
	preview.remove_meta("fan_focused")
	preview.remove_meta("fan_stacked")
	preview.size = HAND_SIZE
	preview.scale = Vector2.ONE
	preview.rotation = 0.0
	preview.z_index = 0
	preview.modulate = Color.WHITE
	preview.position = Vector2.ZERO
	if preview.has_method("set_exposure"):
		preview.call("set_exposure", 0, HAND_SIZE.x)
	else:
		_legacy_exposure(preview, 0, HAND_SIZE.x)
	if preview.has_method("set_peek_amount"):
		preview.call("set_peek_amount", 0.0)
	_disable_card_input(preview)
	return preview


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _native_drag_index >= 0:
		_remember_drag_transform()
		if not is_drag_successful():
			_start_return_ghost(_native_drag_index)
		_native_drag_index = -1
		_pressed_card = -1
		_drag_face = null
		_clear_hover()


func _remember_drag_transform() -> void:
	if _drag_face == null:
		return
	var preview := _drag_face.get_ref() as Control
	if is_instance_valid(preview) and preview.is_inside_tree():
		# Both this transform and the destination include canvas transforms,
		# so window scaling and nested production layers share one coordinate space.
		_drag_transform = preview.get_global_transform_with_canvas()


func _start_return_ghost(index: int) -> void:
	_clear_return_ghost()
	if not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree():
		return
	if index < 0 or index >= cards.size() or not is_instance_valid(cards[index]):
		return
	_return_index = index
	_return_time = 0.0
	_return_from = _drag_transform
	_return_face = _complete_face(index)
	_return_layer = CanvasLayer.new()
	_return_layer.name = "ReturningHandCard"
	_return_layer.layer = 80
	_return_layer.transform = _return_from
	# Owned by the hand, not by the root: changing scenes cannot leave a ghost.
	add_child(_return_layer)
	_return_layer.add_child(_return_face)


func _update_return_ghost(delta: float) -> void:
	if not is_instance_valid(_return_layer):
		return
	if _return_index < 0 or _return_index >= cards.size() or not is_visible_in_tree():
		_clear_return_ghost()
		return
	var destination: Control = cards[_return_index]
	if not is_instance_valid(destination) or destination.is_queued_for_deletion():
		_clear_return_ghost()
		return
	_return_time += delta
	var progress := clampf(_return_time / RETURN_DURATION, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - progress, 3.0)
	_return_layer.transform = _return_from.interpolate_with(destination.get_global_transform_with_canvas(), ease)
	# Blend only the final arrival into the original (still occupied) slot.
	# Alpha changes coverage; the artwork's RGB is never recoloured.
	_return_face.modulate.a = 1.0 - smoothstep(0.68, 1.0, progress)
	if progress >= 1.0:
		_clear_return_ghost()


func _clear_return_ghost() -> void:
	if is_instance_valid(_return_layer):
		_return_layer.queue_free()
	_return_layer = null
	_return_face = null
	_return_index = -1


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_return_ghost()


func _exit_tree() -> void:
	_clear_return_ghost()


func _cancel_gesture() -> void:
	_pressed = false
	_dragging = false
	_lift_armed = false
	_pressed_card = -1
	if _native_drag_index >= 0 and is_inside_tree():
		var viewport := get_viewport()
		if viewport.has_method("gui_cancel_drag"):
			viewport.call("gui_cancel_drag")
	_native_drag_index = -1


func _get_tooltip(at_position: Vector2) -> String:
	var index := _card_at(at_position)
	return cards[index].tooltip_text if index >= 0 and not _blocked else ""


func _disable_card_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_disable_card_input(child)


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.name == property_name:
			return true
	return false
