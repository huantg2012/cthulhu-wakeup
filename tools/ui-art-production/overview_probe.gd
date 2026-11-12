extends SceneTree
## Real keyboard/mouse smoke path through the project's main scene, using a separate save directory.
const Session = preload("res://src/presentation/session.gd")
var app: Control
var output := ""

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func press_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func click(path: String) -> bool:
	await process_frame
	var button := app.find_child(path, true, false) as Button
	if not require(button != null and button.is_visible_in_tree() and not button.disabled, "Unavailable: " + path): return false
	var at := Vector2.ZERO
	for attempt: int in 5:
		at = button.get_global_transform_with_canvas() * (button.size / 2.0)
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		root.push_input(motion, true)
		await process_frame
		if root.gui_get_hovered_control() == button: break
	if not require(root.gui_get_hovered_control() == button, "Mouse intercepted at %s by %s at %s" % [path, root.gui_get_hovered_control(), at]): return false
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	return true

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	var main := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var game := main.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	var isolated := "user://ui-art-production-probe/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	app.session = Session.new(isolated)
	app.display_settings_path = isolated.path_join("display.cfg")
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	app._large_text = "--large" in args
	if not await click("NewGameOptions"): return
	(app.find_child("Seed", true, false) as LineEdit).text = "1"
	if not await click("NewGame"): return
	if not require(app.projection.get("active", false) and app._dialog.is_empty() and app._world_id.is_empty(), "Seed 1 new game did not reach 诸界"): return
	var atmosphere: Control = app._atmosphere
	var before: String = app.session.turn.snapshot()
	for label: Label in app.find_children("ResourceAmount", "Label", true, false):
		var font := label.get_theme_font("font")
		var pixels := label.get_theme_font_size("font_size")
		if not require(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x, "Resource cropped: " + label.text): return
		for code: int in label.text.to_utf32_buffer().to_int32_array():
			if not require(font.has_char(code), "Missing resource glyph: %d" % code): return
	var phase := app.find_child("PhaseAction", true, false) as Button
	var elapsed: float = atmosphere.elapsed
	if not await click("PhaseAction"): return
	if not require(app._dialog == "end", "Phase entry did not open real responsibilities: " + str(app._dialog)): return
	await press_key(KEY_ESCAPE)
	if not require(app._dialog.is_empty() and root.gui_get_focus_owner() == phase, "Esc did not restore phase focus"): return
	if not require(not phase.get_theme_stylebox("focus") is StyleBoxEmpty, "Keyboard focus didn't retain its material"): return
	if not require(app._atmosphere == atmosphere and fposmod(atmosphere.elapsed - elapsed, 24.0) < 3.0, "Overlay reset the ambient clock"): return
	var fan: Control = app.find_child("WorldFan", true, false)
	var local_id: String = fan.cards[fan.focus_index].get_meta("subject_id")
	fan.grab_focus()
	await press_key(KEY_ENTER)
	if not require(app._world_id == local_id and app._atmosphere == atmosphere, "World entry lost the selected subject or ambient instance"): return
	await press_key(KEY_ESCAPE)
	if not require(app._world_id.is_empty() and app.session.turn.snapshot() == before, "Navigation changed the Session"): return
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await create_timer(0.55).timeout
		await RenderingServer.frame_post_draw
		if not require(root.get_texture().get_image().save_png(output) == OK, "Could not capture overview"): return
	if "--cycle" in args:
		var frames := 0
		var start := Time.get_ticks_msec()
		var start_elapsed: float = atmosphere.elapsed
		while Time.get_ticks_msec() - start < 24500:
			await process_frame
			frames += 1
		print("24 s running environment: %s frames in %d ms; ambient %.3f → %.3f" % [frames, Time.get_ticks_msec() - start, start_elapsed, atmosphere.elapsed])
	print("PASS: new game → 诸界 → 回合责任 → Esc → 当地 → Esc; large=", app._large_text)
	quit()
