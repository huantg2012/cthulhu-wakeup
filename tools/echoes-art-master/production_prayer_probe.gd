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
	_button(node_name).pressed.emit()

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
	_press("NewGame")
	if not _expect(app._dialog == "prayer_intro", "new game did not announce its opening prayer"): return
	_press("DismissPrayers")
	_next_round()
	if not _expect(app.projection.turn == 2 and app._dialog.is_empty() and app._prayers.cards.size() == 1, "old prayer blocked the zero-new turn"): return
	_next_round()
	if not _expect(app.projection.turn == 3 and app._dialog == "prayer_intro" and app._prayers.cards.size() == 2, "third turn should have an old and a new prayer"): return
	var intro: Array[Node] = app._surface.find_children("IntroPrayer_*", "Button", false, false)
	if not _expect(intro.size() == 1, "introduced an old prayer"): return
	await _capture("01-new-prayer")
	var before: Dictionary = app.projection
	var new_prayer: Dictionary = before.prayers[1]
	var old_prayer: Dictionary = before.prayers[0]
	intro[0].pressed.emit()
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
	app._prayers.cards[old_prayer.id].pressed.emit()
	if not _expect(app._prayers._row().key == old_prayer.key + "/shallow", "different prayer reused another mode"): return
	app._prayers.close()
	if not _expect(root.gui_get_focus_owner() == app._prayers.cards[old_prayer.id], "close did not return focus to the source card"): return
	app._prayers.cards[new_prayer.id].pressed.emit()
	if not _expect(app._prayers._row().key == deep.key and app._prayers._row().preview.preview == costs, "reopen did not restore and re-preview the right request"): return
	_press("Respond")
	_press("CancelPrayer")
	if not _expect(app.session.project().faith == before.faith and app.session.project().whispers == before.whispers, "browsing or cancel spent resources"): return
	_press("Respond")
	var confirm := _button("ConfirmPrayer")
	confirm.pressed.emit()
	confirm.pressed.emit()
	var after: Dictionary = app.projection
	if not _expect(after.prayer_response_spent and app._dialog == "prayer_result" and before.whispers - after.whispers == costs.whispers and before.faith - after.faith == costs.faith, "receipt or duplicate payment mismatch"): return
	await _capture("04-response-receipt")
	app._prayers.cards[old_prayer.id].pressed.emit()
	var rejected: Dictionary = app._prayers._row().preview
	if not _expect(_button("Respond").disabled and not rejected.ok and str(rejected.error).contains("已使用"), "second request still looked payable"): return
	app._prayers.close()
	_next_round()
	if not _expect(app.projection.turn == 4 and app._dialog == "event", "expected the real expiry event at the next opening"): return
	_press("Option_A")
	_press("ConfirmEvent")
	if not _expect(app.projection.phase == "actions" and app._dialog == "prayer_intro", "new prayer did not wait for the event"): return
	print("B02_OK first visibility, no-new boundary, selection/focus restoration, cancel, one payment, spent response, next event")
	game.free()
	quit()
