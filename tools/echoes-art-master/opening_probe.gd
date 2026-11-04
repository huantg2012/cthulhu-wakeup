extends SceneTree
## Opening presentation fixture only; does not exercise Session.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
var app: Control
func _initialize() -> void:
	Input.use_accumulated_input = false
	run.call_deferred()
func frame() -> void:
	await process_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("OPENING_PROBE: " + message)
		quit(1)
func snap(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/echoes-art-master/evidence/opening-" + name_value + ".png")
func click(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await frame()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frame()
func run() -> void:
	app = Scene.instantiate()
	root.add_child(app)
	await frame()
	check(app.opening_phase == "event", "event first")
	await snap("event")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await frame()
	check(app.opening_phase == "event", "escape cannot skip event")
	await click(app.opening_layer.get_node("Choice_0"))
	check(app.opening_phase == "prayers", "event choice leads to prayers")
	await snap("prayers")
	for i: int in range(3):
		if i > 0:
			app.show_opening_prayers()
			await frame()
		await click(app.opening_layer.get_node("Prayer_%d" % i))
		check(app.opening_phase.is_empty(), "prayer dismisses opening")
		check(app.current_prayer == [1,2,0][i] and app.current_mode == "prayer", "opens corresponding prayer")
	print("OPENING_PROBE_OK event, escape, all 3 cards")
	quit()
