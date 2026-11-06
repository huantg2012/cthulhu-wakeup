extends SceneTree
## One real Session/UI path: fixed reading, choice, payment, receipt, and resume.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app: Control
var evidence := ""
var failed := false

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> bool:
	if not value:
		failed = true
		push_error("PRAYER_SPACE_UI: " + message)
		quit(1)
	return value

func button(name_value: String) -> Button:
	return app.find_child(name_value, true, false)

func press(name_value: String) -> bool:
	var target := button(name_value)
	if not expect(is_instance_valid(target) and not target.disabled, "missing/disabled " + name_value): return false
	target.pressed.emit()
	return true

func capture(name_value: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	expect(frame.save_png(evidence.path_join(name_value + ".png")) == OK, "capture failed")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): evidence = args[0]
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new("user://prayer-space-ui-probe/%d" % Time.get_ticks_usec())
	root.add_child(game)
	if not press("NewGame"): return
	if app._dialog == "prayer_intro": press("DismissPrayers")
	var offered: Array = app.projection.prayers.filter(func(p: Dictionary) -> bool: return p.descriptor.get("space", false))
	if not expect(not offered.is_empty() and app.projection.prayers.size() <= 3, "new requests missing or total exceeds three"): return
	var request: Dictionary = offered[0]
	app._prayers.cards[request.id].pressed.emit()
	if not expect(app._dialog == "prayer_detail", "request did not open"): return
	var choices: Array = app.session.modules.prayers.space_choices(app.session.world.state, request.id)
	var chosen := ""
	for choice: Dictionary in choices:
		var control := button("SpaceChoice_" + str(choice.id))
		if is_instance_valid(control) and not control.disabled:
			chosen = str(choice.id)
			control.pressed.emit()
			break
	if not expect(not chosen.is_empty() and not button("Respond").disabled, "no usable concrete response"): return
	var before: Dictionary = app.session.project()
	var row: Dictionary = app._actions.resolve_row(app, request.key + "/" + chosen, {})
	var price: Dictionary = row.preview.preview
	var title: Control = app._surface.find_child("PrayerSpaceSupport", true, false)
	var title_position := title.global_position
	app._prayers._scroll.scroll_vertical = 100
	await process_frame
	if not expect(title.global_position == title_position and button("Respond").is_visible_in_tree(), "header/footer moved with content"): return
	await capture("prayer-space-standard")
	app._large_text = true
	app._prayers._stage("prayer_detail")
	app._prayers._update_detail("SpaceChoice_" + chosen)
	await capture("prayer-space-large")
	var related := button("Person_1")
	if is_instance_valid(related):
		related.pressed.emit()
		if not expect(button("Respond") == null, "execution leaked into associated reading"): return
		press("BackToPrayer")
		if not expect(str(app._prayers._draft().mode) == chosen, "associated reading lost selected response"): return
	if not expect(app.session.project().faith == before.faith and app.session.project().whispers == before.whispers, "reading charged resources"): return
	if not press("Respond"): return
	if app._dialog == "prayer_confirm":
		press("BackToPrayer")
		if not expect(app.session.project().faith == before.faith, "cancel charged resources"): return
		press("Respond")
		press("ConfirmPrayer")
	var after: Dictionary = app.session.project()
	if not expect(app._dialog == "prayer_result" and after.prayer_response_spent, "no real receipt or response not consumed"): return
	if not expect(int(before.faith) - int(after.faith) == int(price.faith) and int(before.whispers) - int(after.whispers) == int(price.whispers), "wrong actual payment"): return
	await capture("prayer-space-result")
	var saved: Dictionary = app.session.save_game()
	if not expect(saved.get("ok", false), "Session save rejected"): return
	var resumed := Session.new("user://prayer-space-ui-restored/%d" % Time.get_ticks_usec())
	var loaded: Dictionary = resumed.continue_game(saved.path)
	if not expect(loaded.get("ok", false), "Session resume rejected: " + str(loaded.get("error", ""))): return
	var restored: Dictionary = resumed.project()
	if not expect(restored.prayer_response_spent and restored.faith == after.faith and restored.whispers == after.whispers, "resume rewrote paid response"): return
	print("PRAYER_SPACE_UI_OK concrete choice / fixed title-footer / associated return / one payment / actual receipt / Session save-resume")
	game.free()
	quit(0 if not failed else 1)
