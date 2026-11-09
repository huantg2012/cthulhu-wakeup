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
	if not press("NewGameOptions"): return
	app.find_child("Seed", true, false).text = args[2] if args.size() > 2 and args[2].is_valid_int() else "1"
	if not press("NewGame"): return
	if app._dialog == "prayer_intro": press("DismissPrayers")
	var offered: Array = app.projection.prayers.filter(func(p: Dictionary) -> bool: return p.descriptor.get("space", false))
	if not expect(offered.size() == 2 and offered.size() == app.projection.prayers.size(), "new campaign did not open with two concrete requests only"): return
	var first: Dictionary = app.projection.prayers[0]
	if not expect(first.descriptor.get("space", false), "legacy offer led the player projection"): return
	if not press("PrayerIndex"): return
	if not expect(app._dialog == "prayer_intro" and app.get_viewport().gui_get_focus_owner() == button("IntroPrayer_" + str(first.id)), "overview list did not lead with the generated offer"): return
	await capture("prayer-space-offers")
	if not press("DismissPrayers"): return
	if unknown_mode:
		offered = offered.filter(func(p: Dictionary) -> bool: return app.session.prayer_space_choices(p.id).any(func(c: Dictionary) -> bool: return c.get("disclosure") == "unknown"))
		if not expect(not offered.is_empty(), "no unknown response in fixture"): return
	var request: Dictionary = offered[0]
	if not press("World_" + str(request.descriptor.domain)): return
	press("PrayerIndex")
	if app._dialog == "prayer_intro": press("IntroPrayer_" + str(request.id))
	if not expect(app._dialog == "prayer_detail", "request did not open"): return
	var choices: Array = app.session.prayer_space_choices(request.id)
	if not expect(choices.size() == app._surface.find_children("SpaceChoice_*", "Button", true, false).size() and button("Mode_shallow") == null, "concrete options were replaced or dropped"): return
	var person: String = request.descriptor.subjects.petitioner
	if not expect(not app._views._find(app, "people", person).is_empty() and screen_text(app._surface).contains(app.title(person)), "bound petitioner missing from the scene"): return
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
	var untouched: String = app.session.turn.snapshot()
	if not press("DeferPrayer"): return
	if app._dialog.is_empty() and not press("PrayerIndex"): return
	if app._dialog == "prayer_intro" and not press("IntroPrayer_" + str(request.id)): return
	if not expect(app.session.turn.snapshot() == untouched and app._prayers._draft().mode == chosen, "deferring spent resources or lost the selected response"): return
	var before: Dictionary = app.session.project()
	var row: Dictionary = app._actions.resolve_row(app, request.key + "/" + chosen, {})
	var price: Dictionary = row.preview.preview
	for field: String in ["context", "goal", "effect", "tradeoff", "pollution", "alert", "disaster_text", "outcomes"]:
		if not expect(not price.has(field), "pre-action projection exposes " + field): return
	if not expect(int(price.get("success_target", -1)) > 0 and screen_text(app._surface).contains("掷出 1–"), "missing visible roll target"): return
	if not expect(not request.descriptor.has("context") and not request.descriptor.has("goal"), "public request still repeats background/goal"): return
	var title: Control = app._surface.find_child("PrayerSpace", true, false)
	var title_position := title.global_position
	app._prayers._scroll.scroll_vertical = 100
	await process_frame
	if not expect(title.global_position == title_position and button("Respond").is_visible_in_tree(), "header/footer moved with content"): return
	await process_frame
	await process_frame
	app._prayers._scroll.scroll_vertical = 0
	await process_frame
	var cue: Label = app._surface.find_child("ScrollCue", true, false)
	var bar: VScrollBar = app._prayers._scroll.get_v_scroll_bar()
	if not expect(cue.text.contains("下文") == (bar.max_value - bar.page > 1), "overflow cue did not reflect available content"): return
	if bar.max_value - bar.page > 1:
		bar.value = bar.max_value - bar.page
		if not expect(cue.text.contains("上文"), "overflow cue did not change at the end of the list"): return
		bar.value = 0
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
	var receipts: Array = after.last_result.facts.filter(func(fact: Dictionary) -> bool: return fact.get("kind") == "prayer_space_result")
	if not expect(receipts.size() == 1, "submission did not produce one generated-prayer receipt"): return
	var actual: Dictionary = receipts[0]
	var upkeep: int = int(price.get("first_upkeep", 0)) if actual.changes.outcome in ["success", "deep"] else 0
	if not expect(int(before.faith) - int(after.faith) == int(price.faith) + upkeep and int(before.whispers) - int(after.whispers) == int(price.whispers), "wrong actual payment"): return
	if not expect(screen_text(app._surface).contains("骰点 ") and screen_text(app._surface).contains("成功点数 1–"), "receipt missing actual die and target"): return
	await capture("prayer-unknown-result" if unknown_mode else "prayer-space-result")
	var others: Array = after.prayers.filter(func(p: Dictionary) -> bool: return p.descriptor.get("space", false))
	if not others.is_empty():
		var other: Dictionary = others[0]
		if not press("ClosePrayerResult"): return
		if app._dialog.is_empty() and not press("PrayerIndex"): return
		if app._dialog == "prayer_intro" and not press("IntroPrayer_" + str(other.id)): return
		if not expect(button("Respond").disabled and screen_text(app._surface).contains("本轮回应机会已用"), "second situation admitted another response"): return
		var checks_state: int = app.session.world.randoms.checks.state
		if not press("DismissPrayer"): return
		if not expect(app._dialog == "prayer_confirm", "closing the request skipped confirmation"): return
		if not press("BackToPrayer"): return
		if not expect(app.projection.prayers.any(func(p: Dictionary) -> bool: return p.id == other.id) and root.gui_get_focus_owner().name == "DismissPrayer", "cancel lost the open prayer or its focus"): return
		if not press("DismissPrayer") or not press("ConfirmDismissPrayer"): return
		var dismissed: Dictionary = app.session.project()
		if not expect(app._dialog == "prayer_result" and dismissed.prayers.all(func(p: Dictionary) -> bool: return p.id != other.id) and dismissed.prayer_response_spent and dismissed.faith == after.faith and dismissed.whispers == after.whispers and app.session.world.randoms.checks.state == checks_state, "dismiss charged, rolled, or failed to close the original situation"): return
	var saved: Dictionary = app.session.save_game()
	if not expect(saved.get("ok", false), "Session save rejected"): return
	var resumed := Session.new("user://prayer-space-ui-restored/%d" % Time.get_ticks_usec())
	var loaded: Dictionary = resumed.continue_game(saved.path)
	if not expect(loaded.get("ok", false), "Session resume rejected: " + str(loaded.get("error", ""))): return
	var restored: Dictionary = resumed.project()
	if not expect(restored.prayer_response_spent and restored.faith == after.faith and restored.whispers == after.whispers, "resume rewrote paid response"): return
	print("PRAYER_SPACE_UI_OK generated-first / concrete choice / real petitioner / defer / associated return / actual payment and receipt / save-resume")
	game.free()
	quit(0 if not failed else 1)
