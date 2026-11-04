extends SceneTree
## Keyboard/mouse focus regression for this isolated presentation fixture.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
var app: Control
var checks: Array[String] = []

func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()

func verify(ok: bool, message: String) -> bool:
	if not ok:
		push_error("MODAL_FOCUS_PROBE: " + message)
		quit(1)
		return false
	checks.append(message)
	return true

func key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame

func click(node: Control) -> void:
	var pos := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func inside_dialog() -> bool:
	var dialog: Control = app.get_node("PreviewLayer/Dialog")
	var focused := root.gui_get_focus_owner()
	return focused != null and dialog.is_ancestor_of(focused)

func _run() -> void:
	app = Scene.instantiate()
	root.add_child(app)
	for i in range(5): await process_frame
	var origin: Button = app.get_node("Interface/Prayers/PrayerCard_1/Shallow_1")
	await click(origin)
	if not verify(app.modal_kind == "prayer" and inside_dialog(), "opening prayer focuses its preview"): return
	for i in range(12):
		await key(KEY_TAB)
		if not verify(inside_dialog(), "Tab stays in prayer preview step %d" % (i + 1)): return
	for i in range(8):
		await key(KEY_TAB, true)
		if not verify(inside_dialog(), "Shift+Tab stays in prayer preview step %d" % (i + 1)): return
	for code: Key in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP, KEY_LEFT, KEY_DOWN]:
		await key(code)
		if not verify(inside_dialog(), "arrow navigation stays in preview"): return
	var previous_log: Array = app.interaction_log.duplicate()
	# Simulate an exceptional focus escape, then ensure activation cannot act on
	# the hidden background. The shield should recover to the preview close.
	app.get_node("Interface/TopBar/CultsIndex").grab_focus()
	await key(KEY_ENTER)
	if not verify(app.modal_kind == "prayer" and app.interaction_log == previous_log and inside_dialog(), "Enter cannot activate background even after focus escape"): return
	await click(app.get_node("PreviewLayer/Dialog/ChooseDeep"))
	if not verify(app.current_variant == "deep" and root.gui_get_focus_owner() == app.get_node("PreviewLayer/Dialog/ChooseDeep"), "mouse switching to deep retains option focus"): return
	await key(KEY_TAB, true)
	if not verify(root.gui_get_focus_owner() == app.get_node("PreviewLayer/Dialog/ChooseShallow"), "keyboard can reach the other option"): return
	await key(KEY_ENTER)
	if not verify(app.current_variant == "shallow" and root.gui_get_focus_owner() == app.get_node("PreviewLayer/Dialog/ChooseShallow"), "keyboard switching to shallow retains option focus"): return
	await key(KEY_ESCAPE)
	if not verify(not app.get_node("PreviewLayer").visible and root.gui_get_focus_owner() == origin, "Escape restores original prayer control"): return
	var relics: Button = app.get_node("Interface/Dock/RelicScroll/Items/Relic_0")
	await click(relics)
	if not verify(app.modal_kind == "relics" and inside_dialog(), "relic fixture preview opens"): return
	for i in range(8):
		await key(KEY_TAB)
		if not verify(inside_dialog(), "Tab stays in relic preview step %d" % (i + 1)): return
	await key(KEY_ESCAPE)
	if not verify(root.gui_get_focus_owner() == relics, "Escape restores relic entry focus"): return
	print("MODAL_FOCUS_PROBE_OK ", checks.size(), " checks")
	quit(0)
