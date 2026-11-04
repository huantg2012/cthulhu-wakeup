extends SceneTree
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
var app: Control
func _initialize(): run.call_deferred()
func pause(t: float): await create_timer(t).timeout
func click(node: Control):
	var at := node.get_global_rect().get_center()
	var m := InputEventMouseMotion.new(); m.position=at; m.global_position=at
	Input.parse_input_event(m)
	await pause(0.12)
	for down in [true,false]:
		var e := InputEventMouseButton.new(); e.position=at; e.global_position=at; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down
		Input.parse_input_event(e)
		await pause(0.08)
func key(code: Key):
	var e:=InputEventKey.new(); e.keycode=code; e.pressed=true; Input.parse_input_event(e)
	await pause(0.06)
	e=InputEventKey.new(); e.keycode=code; e.pressed=false; Input.parse_input_event(e)
func run():
	app=Scene.instantiate(); root.add_child(app)
	await pause(0.5)
	root.grab_focus()
	await pause(2.0)
	await click(app.opening_layer.get_node("Choice_0")); await pause(0.3)
	if app.opening_phase == "event": app.opening_layer.get_node("Choice_0").pressed.emit()
	await pause(2)
	await click(app.opening_layer.get_node("Prayer_2")); await pause(0.3)
	if app.opening_phase == "prayers": app.opening_layer.get_node("Prayer_2").pressed.emit()
	await pause(2)
	await click(app.get_node("Interface/PrimaryStage/ChooseDeep")); await pause(0.2)
	if app.current_variant != "deep": app.show_prayer_stage(app.current_prayer,"deep")
	await pause(1)
	await click(app.get_node("Interface/PrimaryStage/ChooseShallow")); await pause(0.2)
	if app.current_variant != "shallow": app.show_prayer_stage(app.current_prayer,"shallow")
	await pause(1)
	await click(app.get_node("Interface/PrimaryStage/InspectPerson")); await pause(0.2)
	if app.current_mode != "prayer_person": app.show_prayer_person(app.current_prayer)
	await pause(1)
	await click(app.get_node("Interface/PrimaryStage/ReturnPrayer")); await pause(0.2)
	if app.current_mode != "prayer": app.return_to_prayer()
	await pause(1)
	await click(app.get_node("Interface/PrimaryStage/ClosePrayer")); await pause(0.2)
	if app.current_mode != "world": app.close_prayer_stage()
	await pause(1)
	var baseline := get_node_count()
	for i in range(20):
		app.show_prayer_stage(i%3,"deep" if i%2 else "shallow")
		app.show_prayer_person(i%3)
		app.return_to_prayer()
		await pause(0.06)
	await pause(1)
	if app.current_prayer != 1 or app.current_variant != "deep": push_error("STRESS: incorrect final identity or variant"); quit(1); return
	await key(KEY_F3); await pause(2)
	if app.motion.enabled: push_error("STRESS: F3 did not disable motion"); quit(1); return
	await key(KEY_F3); await pause(2)
	if not app.motion.enabled: push_error("STRESS: F3 did not re-enable motion"); quit(1); return
	app.close_prayer_stage(); await pause(1)
	var focused := root.gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree(): push_error("STRESS: hidden focus"); quit(1); return
	if get_node_count() > baseline + 12: push_error("STRESS: node accumulation"); quit(1); return
	if app.motion.effects.size() != 0: push_error("STRESS: active animation remains"); quit(1); return
	if get_nodes_in_group("motion_retiring").size() != 0: push_error("STRESS: retired overlay remains"); quit(1); return
	print("MOTION_STRESS_OK 20 switches, F3, focus and retired layers")
	await pause(5)
	quit()
