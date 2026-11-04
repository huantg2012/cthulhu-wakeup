extends SceneTree
## Short B01 check, driven through the production buttons with a real Session.
## Optionally capture rendered states in an existing directory passed after --.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
const ORIGINAL := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
var app: Control
var save_dir: String
var evidence_dir := ""

func _initialize() -> void:
	run.call_deferred()

func _open() -> Node:
	var game: Node = Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(save_dir)
	root.add_child(game)
	return game

func _press(node_name: String) -> void:
	var control: Button = app.find_child(node_name, true, false)
	control.pressed.emit()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("B01: " + message)
		quit(1)
	return condition

func _capture(name_value: String) -> void:
	if evidence_dir.is_empty(): return
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if not _check(frame.get_size() == Vector2i(1920, 1080), "capture output is not 1920×1080"): return
	_check(frame.save_png(evidence_dir.path_join(name_value + ".png")) == OK, "capture failed")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless": evidence_dir = args[0]
	save_dir = "user://production-ui-b01-probe/%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var game := _open()
	_press("NewGame")
	if not _check(app.projection.phase == "actions" and app.projection.turn == 1, "empty opening blocked actions"): return
	for expected_turn in range(2, 5):
		_press("PhaseAction")
		var confirm: Button = app.find_child("ConfirmEnd", true, false)
		if not _check(not confirm.disabled, "real end preview was unavailable"): return
		confirm.pressed.emit()
		confirm.pressed.emit()
		if not _check(app.projection.turn == expected_turn, "duplicate end advanced more than once"): return
		await process_frame
	if not _check(app.projection.phase == "events" and app._pending_events().size() == 1, "seed 1 no longer reaches the expected real event"): return
	await _capture("01-opening-event")
	_press("InspectWorld")
	if not _check(app.projection.phase == "events" and not app.session.preview_action("POWER_LISTEN").ok, "inspection opened ordinary actions"): return
	await _capture("02-inspect-world")
	_press("PhaseAction")
	_press("Option_B")
	_press("Cancel")
	if not _check(app.projection.faith == 18 and app.projection.phase == "events", "cancel changed faith or phase"): return
	_press("Option_B")
	var pay: Button = app.find_child("ConfirmEvent", true, false)
	if not _check(not pay.disabled, "paid event option was unavailable"): return
	pay.pressed.emit()
	pay.pressed.emit()
	if not _check(app.projection.faith == 14 and app.projection.phase == "actions" and app._resource_delta == "信仰 18 → 14", "event payment/receipt or phase was incorrect"): return
	await _capture("03-paid-receipt")
	_press("PhaseAction")
	await _capture("04-end-preview")
	_press("ConfirmEnd")
	_press("Menu")
	_press("Save")
	game.free()
	game = _open()
	_press("Continue")
	if not _check(app.projection.turn == 5 and app.projection.phase == "actions" and app.projection.faith == 14, "saved game did not resume at the real next round"): return
	var original_hash := FileAccess.get_sha256(ORIGINAL)
	app._import_copy(ProjectSettings.globalize_path(ORIGINAL))
	if not _check(app.projection.turn == 4 and app.projection.phase == "actions" and app.session.slot.begins_with(ProjectSettings.globalize_path(save_dir) + "/"), "compatible between save did not advance inside an independent copy"): return
	app._save(false)
	if not _check(original_hash == FileAccess.get_sha256(ORIGINAL), "import changed the original save"): return
	print("B01_OK zero-event start, event gate, cancellation, duplicate submits, real payment, next round, save/reload, independent import")
	game.free()
	quit()
