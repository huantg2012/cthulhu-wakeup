extends SceneTree
var view: Control
func _initialize() -> void: call_deferred("run")
func motion(pos: Vector2,mask:=0,delta:=Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*pos
	event.global_position = event.position
	event.relative = delta
	event.button_mask = mask
	Input.parse_input_event(event)
func button(pos: Vector2,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform()*pos
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
func point() -> Vector2:
	return view._fan.global_position+view._fan.cards[view._fan.focus_index].position+Vector2(74,75)
func run() -> void:
	root.add_child(load("res://docs/art/visual-generation/worldplay-study/worldplay.tscn").instantiate())
	view = root.get_node("GameRoot/Presentation/CanvasLayer/OverlayRoot")
	await process_frame
	await process_frame
	var sequence: int = view.session.turn.commit_sequence
	view._fan.set_focus(0,false)
	var p := point()
	motion(p)
	await process_frame
	button(p,true)
	await process_frame
	button(p,false)
	await process_frame
	if view._played.get("kind")!="cult": print("INPUT_FAIL front_click"); quit(1); return
	print("FOUR_ZONE_INPUT front_click true")
	view._recall()
	view._fan.set_focus(2,false)
	await process_frame
	p = point()
	motion(p)
	await process_frame
	button(p,true)
	await process_frame
	motion(p+Vector2(0,-40),MOUSE_BUTTON_MASK_LEFT,Vector2(0,-40))
	await process_frame
	var target: Vector2 = view._table.get_global_rect().get_center()
	motion(target,MOUSE_BUTTON_MASK_LEFT,target-p)
	await process_frame
	print("FOUR_ZONE_INPUT native_drag ",root.gui_is_dragging())
	button(target,false)
	await process_frame
	await process_frame
	if view._played.get("id")!="POWER_DREAM": print("INPUT_FAIL upward_drop"); quit(1); return
	print("FOUR_ZONE_INPUT upward_drop true")
	view._recall()
	view._fan.set_focus(12,false)
	await process_frame
	p = point()
	motion(p)
	await process_frame
	button(p,true)
	await process_frame
	motion(p+Vector2(-120,0),MOUSE_BUTTON_MASK_LEFT,Vector2(-120,0))
	await process_frame
	button(p+Vector2(-120,0),false)
	await process_frame
	if view._fan.focus_index<=12 or not view._played.is_empty(): print("INPUT_FAIL sideways_scroll"); quit(1); return
	print("FOUR_ZONE_INPUT sideways_scroll_without_play true")
	p = view._persistent_dock.get_node("PowerIndex").get_global_rect().get_center()
	motion(p)
	await process_frame
	button(p,true)
	await process_frame
	button(p,false)
	await process_frame
	if view._library!="power" or view._table.has_node("Execute"): print("INPUT_FAIL dock_reference"); quit(1); return
	print("FOUR_ZONE_INPUT dock_reference true")
	view._fan.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	if view._played.get("kind")!="power" or view._table.has_node("Execute"): print("INPUT_FAIL keyboard_reference"); quit(1); return
	print("FOUR_ZONE_INPUT keyboard_reference true")
	print("FOUR_ZONE_INPUT no_mutation ",sequence==view.session.turn.commit_sequence)
	quit()
