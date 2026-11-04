extends SceneTree
## Exercises mouse-open/Escape and keyboard navigation on the isolated fixture.
const SCENE = preload("res://tools/echoes-art-master/scene.tscn")

func _initialize() -> void:
	_run.call_deferred()

func frame() -> void:
	await process_frame
	await process_frame

func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await frame()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frame()

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frame()

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _run() -> void:
	var app: Control = SCENE.instantiate()
	app.show_opening_on_start = false
	root.add_child(app)
	await frame()
	for path: String in ["Interface/Chronicle/History", "Interface/TopBar/WorldIndex", "Interface/WorldContext/AnchorStatus"]:
		var button: Button = app.get_node(path)
		await click(button)
		if not require(app.modal_kind != "", path + " did not open"): return
		await key(KEY_ESCAPE)
		if not require(app.modal_kind == "" and not app.keyboard_input and root.gui_get_focus_owner() == button and button.get_theme_stylebox("focus") is StyleBoxEmpty, path + " retained keyboard focus visual"): return
		await key(KEY_META)
		if not require(not app.keyboard_input and button.get_theme_stylebox("focus") is StyleBoxEmpty, path + " showed focus after window-switch modifier"): return
		var shortcut := InputEventKey.new()
		shortcut.keycode = KEY_TAB
		shortcut.pressed = true
		shortcut.meta_pressed = true
		app._input(shortcut)
		if not require(not app.keyboard_input and button.get_theme_stylebox("focus") is StyleBoxEmpty, path + " showed focus on window-switch shortcut"): return
	await click(app.get_node("Interface/WorldContext/ManageCult"))
	var orders: Button = app.get_node("Interface/PrimaryStage/Orders")
	await click(orders)
	if not require(app.modal_kind == "info", "cult orders did not open"): return
	await key(KEY_ESCAPE)
	if not require(not app.keyboard_input and orders.get_theme_stylebox("focus") is StyleBoxEmpty, "cult orders retained focus"): return
	var next: Button = app.get_node("Interface/Dock/EndTurn")
	await click(next)
	if not require(app.modal_kind == "info", "round action did not open"): return
	await key(KEY_ESCAPE)
	if not require(not app.keyboard_input and not next.keyboard_focus_query.call(), "round action retained keyboard focus"): return
	var power: Button = app.get_node("Interface/Dock/PowerScroll/Items/Power_POWER_LISTEN")
	await click(power)
	if not require(app.modal_kind == "power", "power did not open"): return
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(840, 300)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await frame()
	await key(KEY_ESCAPE)
	if not require(not app.keyboard_input and power.get_node("Icon").scale == Vector2.ONE, "power icon retained focus highlight"): return
	var history: Button = app.get_node("Interface/Chronicle/History")
	await click(history)
	await key(KEY_TAB)
	await key(KEY_ESCAPE)
	if not require(app.keyboard_input and root.gui_get_focus_owner() == history and not history.get_theme_stylebox("focus") is StyleBoxEmpty, "keyboard navigation did not retain visible return focus"): return
	await key(KEY_TAB)
	if not require(app.keyboard_input and root.gui_get_focus_owner() != null, "keyboard navigation lost focus"): return
	print("BUTTON_FOCUS_PROBE_OK")
	quit()
