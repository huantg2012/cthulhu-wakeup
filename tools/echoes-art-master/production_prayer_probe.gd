extends SceneTree
## B02 payment and information flow through the production scene and real Session.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app: Control
var evidence := ""

func _initialize() -> void:
	run.call_deferred()

func _button(node_name: String) -> Button:
	return app.find_child(node_name, true, false)

func _press(node_name: String) -> void:
	var control := _button(node_name)
	control.grab_focus()
	control.pressed.emit()

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("B02: " + message)
		quit(1)
	return condition

func _capture(file_name: String) -> void:
	if evidence.is_empty(): return
	await create_timer(0.85).timeout
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if not _expect(frame.get_size() == Vector2i(1920, 1080), "expected 1080p capture"): return
	_expect(frame.save_png(evidence.path_join(file_name + ".png")) == OK, "could not save capture")

func _next_round() -> void:
	_press("PhaseAction")
	_press("ConfirmEnd")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless": evidence = args[0]
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new("user://production-ui-b02-probe/%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	root.add_child(game)
	if args.size() > 1:
		var directory: String = ProjectSettings.globalize_path(app.session.save_directory)
		var copy: String = directory.path_join("legacy-fixture.json")
		if not _expect(DirAccess.make_dir_recursive_absolute(directory) == OK and DirAccess.copy_absolute(ProjectSettings.globalize_path(args[1]), copy) == OK, "could not copy historical save"): return
		app._load_saved(copy)
	else:
		_press("NewGameOptions")
		app.find_child("Seed", true, false).text = "1"
		_press("NewGame")
	if app._dialog == "prayer_intro": _press("DismissPrayers")
	if not _expect(app._dialog.is_empty() and app.projection.phase == "actions", "campaign did not open the overview"): return
	var before: Dictionary = app.projection
	var requests: Array = app._pending_prayers()
	if not _expect(requests.size() >= 2, "fixture needs two distinct requests"): return
	var new_prayer: Dictionary = requests[1]
	var old_prayer: Dictionary = requests[0]
	_press("PrayerIndex")
	await _capture("01-new-prayer")
	_press("IntroPrayer_" + new_prayer.id)
	if new_prayer.descriptor.get("space", false):
		var choices: Array = app.session.prayer_space_choices(new_prayer.id)
		var option: String = str(choices[1].id)
		_press("SpaceChoice_" + option)
	else:
		_press("Mode_deep")
	var deep: Dictionary = app._prayers._row()
	var costs: Dictionary = deep.preview.preview
	await _capture("02-deep-preview")
	var person: Button = app._surface.find_child("Person_*", true, false)
	var person_button := String(person.name)
	person.pressed.emit()
	if not _expect(_button("Respond") == null and app._dialog == "prayer_person", "submission leaked into related reading"): return
	await _capture("03-related-person")
	app._prayers.back_to_detail()
	if not _expect(root.gui_get_focus_owner().name == person_button, "return did not restore the person link"): return
	app._prayers.close()
	if not _expect(root.gui_get_focus_owner().name == "IntroPrayer_" + new_prayer.id, "close did not return focus to the selected request"): return
	_press("DismissPrayers")
	if not _expect(root.gui_get_focus_owner().name == "PrayerIndex", "list did not return focus to its entrance"): return
	_press("PrayerIndex")
	_press("IntroPrayer_" + old_prayer.id)
	var default_mode := "" if old_prayer.descriptor.get("space", false) else "shallow"
	if not _expect(app._prayers._draft().mode == default_mode, "different prayer reused another mode"): return
	app._prayers.close()
	_press("IntroPrayer_" + new_prayer.id)
	if not _expect(app._prayers._row().key == deep.key and app._prayers._row().preview.preview == costs, "reopen did not restore and re-preview the right request"): return
	_press("Respond")
	if not _expect(app._dialog == "prayer_confirm", "irreversible choice skipped confirmation"): return
	_press("BackToPrayer" if new_prayer.descriptor.get("space", false) else "CancelPrayer")
	if not _expect(app.session.project().faith == before.faith and app.session.project().whispers == before.whispers, "browsing or cancel spent resources"): return
	_press("Respond")
	var confirm := _button("ConfirmPrayer")
	if not _expect(is_instance_valid(confirm), "could not re-enter confirmation"): return
	confirm.pressed.emit()
	confirm.pressed.emit()
	var after: Dictionary = app.projection
	if not _expect(after.prayer_response_spent and app._dialog == "prayer_result" and before.whispers - after.whispers == costs.whispers and before.faith - after.faith == costs.faith, "receipt or duplicate payment mismatch"): return
	await _capture("04-response-receipt")
	_press("ClosePrayerResult")
	_press("IntroPrayer_" + old_prayer.id)
	if not _expect(_button("Respond").disabled, "second request still looked payable"): return
	if not app._prayers._is_space():
		var rejected: Dictionary = app._prayers._row().preview
		if not _expect(not rejected.ok and str(rejected.error).contains("已使用"), "legacy second response was not rejected"): return
	app._prayers.close()
	_press("DismissPrayers")
	_next_round()
	if not _expect(app.projection.turn == 2 and app._dialog.is_empty(), "ordinary progression should return to the overview"): return
	print("B02_OK isolated drafts, related return, cancel, one payment, spent response, next round")
	game.free()
	quit()
