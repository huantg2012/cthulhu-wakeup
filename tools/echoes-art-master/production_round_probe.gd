extends SceneTree
## Short B01 check, driven through the production buttons with a real Session.
## Optionally capture rendered states in an existing directory passed after --.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
const ORIGINAL := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
const EVENT_START := "res://docs/qa/ui-manifest/saves/ready.json"
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

func _key(code: Key, shift := false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		event.shift_pressed = shift
		root.push_input(event, true)

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
	_press("NewGameOptions")
	app.find_child("Seed", true, false).text = "1"
	_press("NewGame")
	if not _check(app.projection.phase == "actions" and app.projection.turn == 1, "empty opening blocked actions"): return
	var read_only: String = app.session.turn.snapshot()
	_press("PhaseAction")
	_press("ReviewPrayers")
	var prayer: Dictionary = app._pending_prayers()[0]
	var card := "IntroPrayer_" + str(prayer.id)
	_press(card)
	_key(KEY_ESCAPE)
	if not _check(app._dialog == "prayer_intro" and root.gui_get_focus_owner().name == card, "Escape did not restore the selected prayer in the list"): return
	_press("DismissPrayers")
	if not _check(app._dialog == "end" and root.gui_get_focus_owner().name == "ReviewPrayers", "Prayer list did not restore the round responsibility entry"): return
	app._menu_button.grab_focus()
	_key(KEY_ENTER)
	if not _check(app._dialog == "end", "Keyboard activated the menu behind the active surface"): return
	_key(KEY_TAB, true)
	if not _check(root.gui_get_focus_owner().name == "ConfirmEnd", "Backward Tab from outside the surface did not enter at the last control"): return
	_key(KEY_ESCAPE)
	_press("Menu")
	_press("WorldArchive")
	_key(KEY_ESCAPE)
	if not _check(app._dialog == "menu" and root.gui_get_focus_owner().name == "WorldArchive", "Archive did not return to its menu entry"): return
	_press("Attention")
	_press("ReturnSubject")
	if not _check(app._dialog == "menu" and root.gui_get_focus_owner().name == "Attention", "Attention did not return to its menu entry"): return
	_press("SavedGames")
	_press("Import")
	_key(KEY_ESCAPE)
	if not _check(app._dialog == "saved_games" and root.gui_get_focus_owner().name == "Import", "Cancel lost the import entry"): return
	_key(KEY_ESCAPE)
	if not _check(app._dialog == "menu" and root.gui_get_focus_owner().name == "SavedGames", "Escape lost the save-management entry"): return
	_key(KEY_ESCAPE)
	if not _check(app._dialog.is_empty() and app.session.turn.snapshot() == read_only, "Inspection or cancellation changed the turn"): return
	# The compatibility save still has a real request that expires into EVENT_12.
	# New campaigns now replace that opening request with generated situations.
	var event_start_hash := FileAccess.get_sha256(EVENT_START)
	app._import_copy(ProjectSettings.globalize_path(EVENT_START))
	if not _check(app.projection.turn == 1 and app.projection.phase == "actions", "Could not load compatible event setup"): return
	for expected_turn in range(2, 5):
		if app._dialog == "prayer_intro": _press("DismissPrayers")
		_press("PhaseAction")
		var confirm: Button = app.find_child("ConfirmEnd", true, false)
		if not _check(not confirm.disabled, "real end preview was unavailable"): return
		confirm.pressed.emit()
		confirm.pressed.emit()
		if not _check(app.projection.turn == expected_turn, "duplicate end advanced more than once"): return
		await process_frame
	if not _check(app.projection.phase == "events" and app._pending_events().size() == 1, "Compatible request did not produce its real opening event"): return
	_key(KEY_ESCAPE)
	if not _check(app._dialog == "event", "Escape skipped a required opening event"): return
	await _capture("01-opening-event")
	_press("InspectWorld")
	if not _check(app.projection.phase == "events" and not app.session.preview_action("POWER_LISTEN").ok, "inspection opened ordinary actions"): return
	await _capture("02-inspect-world")
	_press("ReturnEvent")
	if not _check(root.gui_get_focus_owner().name == "InspectWorld", "Event context did not restore its entry"): return
	# The current seed-one event has a zero-cost default. Its paid alternative
	# is rejected by the pre-migration rules as well.
	var event: Dictionary = app._pending_events()[0]
	var option: String = "Option_" + str(event.descriptor.default_action)
	var before_event: String = app.session.turn.snapshot()
	var faith: int = app.projection.faith
	_press(option)
	_press("Cancel")
	if not _check(app.session.turn.snapshot() == before_event and app.projection.phase == "events", "cancel changed event state"): return
	_press(option)
	var resolve: Button = app.find_child("ConfirmEvent", true, false)
	if not _check(not resolve.disabled, "zero-cost event option unavailable"): return
	if not _check(is_equal_approx(resolve.get_parent().position.y, 424.0), "event review left the sample's decision area"): return
	resolve.pressed.emit()
	var resolved: String = app.session.turn.snapshot()
	resolve.pressed.emit()
	if not _check(app.projection.faith == faith and app.projection.phase == "actions" and resolved == app.session.turn.snapshot() and not app._receipt.is_empty(), "event receipt, phase or repeat submission incorrect"): return
	await _capture("03-event-receipt")
	_press("PhaseAction")
	await _capture("04-end-preview")
	_press("ConfirmEnd")
	var checkpoint: Dictionary = app.session.project()
	_press("Menu")
	_press("Save")
	game.free()
	game = _open()
	_press("Continue")
	if not _check(app.projection.turn == checkpoint.turn and app.projection.phase == checkpoint.phase and app.projection.faith == checkpoint.faith, "saved game did not resume the actual next round"): return
	var original_hash := FileAccess.get_sha256(ORIGINAL)
	app._import_copy(ProjectSettings.globalize_path(ORIGINAL))
	if not _check(app.projection.turn == 4 and app.projection.phase == "actions" and app.session.slot.begins_with(ProjectSettings.globalize_path(save_dir) + "/"), "compatible between save did not advance inside an independent copy"): return
	app._save(false)
	if not _check(original_hash == FileAccess.get_sha256(ORIGINAL) and event_start_hash == FileAccess.get_sha256(EVENT_START), "import changed an original save"): return
	print("B01_OK zero-event start, event gate, cancellation, duplicate submits, default resolution, next round, save/reload, independent import")
	game.free()
	quit()
