extends SceneTree
## One real Session/UI path: fixed reading, choice, payment, receipt, and resume.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app: Control
var evidence := ""
var failed := false
var unknown_mode := false

func screen_text(node: Node) -> String:
	var text := ""
	if node is Label or node is Button: text += str(node.text) + "\n"
	for child: Node in node.get_children(): text += screen_text(child)
	return text

func no_spoilers(request: Dictionary) -> bool:
	var shown := screen_text(app._surface)
	var scene: Dictionary = app.session.world.state.prayer_system.space.scenes[request.id]
	for contract: Dictionary in scene.contracts.values():
		for branch: Dictionary in contract.get("outcomes", []):
			if not expect(not shown.contains(str(branch.effect)), "hidden ending leaked before execution"): return false
	return true

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
	unknown_mode = args.has("--unknown")
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new("user://prayer-space-ui-probe/%d" % Time.get_ticks_usec())
	root.add_child(game)
	if args.size() > 2 and args[2].is_valid_int(): app.find_child("Seed", true, false).text = args[2]
	if not press("NewGame"): return
	if app._dialog == "prayer_intro": press("DismissPrayers")
	var offered: Array = app.projection.prayers.filter(func(p: Dictionary) -> bool: return p.descriptor.get("space", false))
	if not expect(not offered.is_empty() and app.projection.prayers.size() <= 3, "new requests missing or total exceeds three"): return
	if unknown_mode:
		offered = offered.filter(func(p: Dictionary) -> bool: return app.session.modules.prayers.space_choices(app.session.world.state, p.id).any(func(c: Dictionary) -> bool: return c.get("disclosure") == "unknown"))
		if not expect(not offered.is_empty(), "no unknown response in fixture"): return
	var request: Dictionary = offered[0]
	app._prayers.cards[request.id].pressed.emit()
	if not expect(app._dialog == "prayer_detail", "request did not open"): return
	var choices: Array = app.session.modules.prayers.space_choices(app.session.world.state, request.id)
	var chosen := ""
	for choice: Dictionary in choices:
		if unknown_mode and choice.get("disclosure") != "unknown": continue
		var control := button("SpaceChoice_" + str(choice.id))
		if is_instance_valid(control) and not control.disabled:
			chosen = str(choice.id)
			control.pressed.emit()
			break
	if not expect(not chosen.is_empty() and not button("Respond").disabled, "no usable concrete response"): return
	if not no_spoilers(request): return
	var before: Dictionary = app.session.project()
	var row: Dictionary = app._actions.resolve_row(app, request.key + "/" + chosen, {})
	var price: Dictionary = row.preview.preview
	for field: String in ["context", "goal", "effect", "tradeoff", "pollution", "alert", "disaster_text", "outcomes"]:
		if not expect(not price.has(field), "pre-action projection exposes " + field): return
	if not expect(int(price.get("success_target", -1)) > 0 and screen_text(app._surface).contains("掷出 1–"), "missing visible roll target"): return
	if not expect(not request.descriptor.has("context") and not request.descriptor.has("goal"), "public request still repeats background/goal"): return
	var title: Control = app._surface.find_child("PrayerSpaceSupport", true, false)
	var title_position := title.global_position
	app._prayers._scroll.scroll_vertical = 100
	await process_frame
	if not expect(title.global_position == title_position and button("Respond").is_visible_in_tree(), "header/footer moved with content"): return
	await process_frame
	await process_frame
	app._prayers._scroll.scroll_vertical = 0
	await process_frame
	await capture("prayer-unknown-standard" if unknown_mode else "prayer-space-standard")
	app._large_text = true
	app._prayers._stage("prayer_detail")
	app._prayers._update_detail("SpaceChoice_" + chosen)
	if unknown_mode:
		await process_frame
		await process_frame
		app._prayers._scroll.scroll_vertical = maxi(0, int(button("SpaceChoice_" + chosen).position.y) - 28)
		await process_frame
	await capture("prayer-unknown-large" if unknown_mode else "prayer-space-large")
	var related := button("Person_1")
	if is_instance_valid(related):
		related.pressed.emit()
		if not expect(button("Respond") == null, "execution leaked into associated reading"): return
		press("BackToPrayer")
		if not expect(str(app._prayers._draft().mode) == chosen, "associated reading lost selected response"): return
	if not expect(app.session.project().faith == before.faith and app.session.project().whispers == before.whispers, "reading charged resources"): return
	if not press("Respond"): return
	if app._dialog == "prayer_confirm":
		if not no_spoilers(request): return
		press("BackToPrayer")
		if not expect(app.session.project().faith == before.faith, "cancel charged resources"): return
		press("Respond")
		press("ConfirmPrayer")
	var after: Dictionary = app.session.project()
	if not expect(app._dialog == "prayer_result" and after.prayer_response_spent, "no real receipt or response not consumed"): return
	if not expect(int(before.faith) - int(after.faith) == int(price.faith) and int(before.whispers) - int(after.whispers) == int(price.whispers), "wrong actual payment"): return
	if not expect(screen_text(app._surface).contains("骰点 ") and screen_text(app._surface).contains("成功点数 1–"), "receipt missing actual die and target"): return
	await capture("prayer-unknown-result" if unknown_mode else "prayer-space-result")
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
