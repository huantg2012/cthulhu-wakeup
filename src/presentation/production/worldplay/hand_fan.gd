extends "res://src/presentation/production/painted/card_fan.gd"
## A complete deck on a bounded tabletop. Browsing redistributes the gaps;
## it never culls, fades or slides distant cards beyond the table.
const HAND_SIZE := Vector2(148,198)
const TABLE_MARGIN := 8.0
signal card_hovered(index: int)
var _lift_armed := false
func set_blocked(value: bool) -> void:
	if value: _lift_armed = false
	super.set_blocked(value)

func _spread_gaps() -> PackedFloat32Array:
	var count := cards.size()-1
	var gaps := PackedFloat32Array()
	if count<=0: return gaps
	var span := maxf(0,size.x-HAND_SIZE.x-TABLE_MARGIN*2)
	var floor_gap := minf(9,span*.42/count)
	var ceiling_gap := maxf(HAND_SIZE.x,span/count)
	var weights := PackedFloat32Array()
	var remaining := span
	var pending: Array[int] = []
	# A narrow, positive edge belongs to EVERY card, even deep in either pile.
	# Only the remaining space is lent to the cards near the current opening.
	for i: int in count:
		gaps.append(floor_gap)
		weights.append(exp(-absf(i+.5-_visual_focus)/2.4))
		pending.append(i)
		remaining -= floor_gap
	# When adjacent cards trade depth, first separate their faces. At the exact
	# z-order exchange they no longer overlap, so no face suddenly pops on top.
	var crossing := clampi(floori(_visual_focus),0,count-1)
	var phase := _visual_focus-floorf(_visual_focus)
	var separation := (HAND_SIZE.x-floor_gap)*pow(sin(PI*phase),2)
	gaps[crossing] += separation
	remaining -= separation
	# Capped distribution avoids a large hole beside the first or last card.
	# The sum stays equal to span: both outer card edges remain anchored.
	while not pending.is_empty() and remaining>.0001:
		var weight_sum := 0.0
		for i: int in pending: weight_sum += weights[i]
		var saturated: Array[int] = []
		for i: int in pending:
			if gaps[i]+remaining*weights[i]/weight_sum>ceiling_gap:
				saturated.append(i)
		if saturated.is_empty():
			for i: int in pending: gaps[i] += remaining*weights[i]/weight_sum
			break
		for i: int in saturated:
			remaining -= ceiling_gap-gaps[i]
			gaps[i] = ceiling_gap
			pending.erase(i)
	return gaps

func _layout_cards() -> void:
	if cards.is_empty(): return
	var stacked := is_stacked()
	var flat_width: float = cards.size()*HAND_SIZE.x+maxi(0,cards.size()-1)*16.0
	var gaps := _spread_gaps() if stacked else PackedFloat32Array()
	var x: float = TABLE_MARGIN if stacked else (size.x-flat_width)*.5
	var front := clampi(roundi(_visual_focus),0,cards.size()-1)
	for i: int in cards.size():
		var card: Control = cards[i]
		var depth := absf(float(i)-_visual_focus)
		card.visible = true
		card.modulate.a = 1.0
		card.size = HAND_SIZE
		card.pivot_offset = HAND_SIZE*.5
		card.position = Vector2(x,3+5*(1-exp(-depth/4.0)) if stacked else 3)
		card.rotation = 0
		card.scale = Vector2.ONE
		card.z_index = cards.size()-absi(i-front)
		var exposed := HAND_SIZE.x
		if stacked and i!=front:
			exposed = gaps[i] if i<front else gaps[i-1]
		# Fold reading into the spine instead of exposing fragments of horizontal
		# paragraphs. Only the text fades; every painted card stays fully opaque.
		var reading := smoothstep(HAND_SIZE.x-40,HAND_SIZE.x,exposed)
		for label_name: String in ["CardType","CardTitle","CardDetail"]:
			var label := card.get_node_or_null(label_name) as Control
			if label!=null: label.modulate.a = reading
		for side: String in ["LeftSpine","RightSpine"]:
			var spine := card.get_node_or_null(side) as Control
			if spine!=null:
				spine.visible = stacked and i!=front and (i<front if side=="LeftSpine" else i>front)
				spine.modulate.a = smoothstep(30,44,exposed)*(1-reading)
		card.set_meta("fan_stacked",stacked)
		card.set_meta("fan_focused",i==front)
		card.set_meta("fan_hovered",i==_hovered_card)
		card.set_meta("fan_edge",-1 if i<front else 1)
		card.queue_redraw()
		if i<cards.size()-1: x += gaps[i] if stacked else HAND_SIZE.x+16

	# Sibling order stays inside the hand's layer; cards cannot draw over modals.
	var order: Array[Control] = cards.duplicate()
	order.sort_custom(func(a: Control,b: Control)->bool:
		return a.z_index < b.z_index if a.z_index != b.z_index else cards.find(a) < cards.find(b))
	for card: Control in order:
		card.z_index = 0
		move_child(card,-1)

func is_stacked() -> bool:
	return cards.size()*HAND_SIZE.x+maxi(0,cards.size()-1)*16>size.x-16

func _gui_input(event: InputEvent) -> void:
	if _blocked: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] and not cards.is_empty():
		accept_event()
		card_chosen.emit(focus_index)
		return
	super._gui_input(event)
	if event is InputEventMouseMotion and not _pressed:
		card_hovered.emit(_card_at(event.position))

func _input(event: InputEvent) -> void:
	if _blocked: return
	if not _pressed: return
	if not is_visible_in_tree():
		_pressed = false
		_dragging = false
		return
	# Use this event's coordinates, not a later OS cursor sample. This keeps
	# swipe direction and release targets coherent during fast or replayed input.
	if event is InputEventMouseMotion:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		var delta: Vector2 = pointer-_press_position
		if not _dragging and _pressed_card>=0 and delta.y < -20 and absf(delta.y)>absf(delta.x)*1.2:
			_lift_armed = true
			_pressed = false
			return
		var elapsed: float = maxf(float(Time.get_ticks_usec()-_last_motion_usec)/1000000.0,.001)
		_velocity_x = lerpf(_velocity_x,(pointer.x-_last_pointer.x)/elapsed,.4)
		_last_pointer = pointer
		_last_motion_usec = Time.get_ticks_usec()
		if not _dragging and absf(delta.x)>=DRAG_THRESHOLD: _dragging = true
		if _dragging:
			_visual_focus = clampf(_press_focus-delta.x/DRAG_STEP,0,float(cards.size()-1))
			_set_focus_index(clampi(roundi(_visual_focus),0,cards.size()-1))
			_layout_cards()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		_finish_gesture(get_global_transform_with_canvas().affine_inverse()*event.position)

func _clear_hover() -> void:
	super._clear_hover()
	card_hovered.emit(-1)

func _get_tooltip(at_position: Vector2) -> String:
	var index := _card_at(at_position)
	return cards[index].tooltip_text if index>=0 else ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _blocked or not _lift_armed or _pressed_card<0: return null
	_lift_armed = false
	var selected: Control = cards[_pressed_card]
	var preview := selected.duplicate() as Control
	preview.position = -HAND_SIZE*.5
	preview.z_index = 0
	for label_name: String in ["CardType","CardTitle","CardDetail"]:
		var label := preview.get_node_or_null(label_name) as Control
		if label!=null: label.modulate.a = 1.0
	for name_value: String in ["LeftSpine","RightSpine"]:
		var spine := preview.get_node_or_null(name_value) as Control
		if spine!=null: spine.hide()
	var holder := Control.new()
	holder.add_child(preview)
	_disable_card_input(holder)
	set_drag_preview(holder)
	return {"worldplay_card":selected.payload}

func _disable_card_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children(): _disable_card_input(child)
