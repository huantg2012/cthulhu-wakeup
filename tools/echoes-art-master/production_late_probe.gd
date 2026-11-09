extends SceneTree
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
# The existing tools/ui rest fixture starts with 12 faith and 3 wounds.
# Adapt its pre-receipt initial condition to the current read-only World root.
class RestSession extends Session:
	func _build(seed_value: int, frozen_content := "", legacy := false) -> Dictionary:
		var built: Dictionary = super._build(seed_value, frozen_content, legacy)
		if built.ok:
			built.world.state = built.world.state.duplicate(false)
			built.world.state.faith = 12
			built.world.state.wounds = 3
			built.world.state.awakening = built.catalog.integer("initial_awakening") - 3
		return built

var app: Control
var folder: String
var evidence := ""
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok:
		push_error(msg)
		quit(1)
	return ok
func press(name_value: String) -> void:
	var b: Button = app.find_child(name_value, true, false)
	if b == null or b.disabled:
		push_error("Missing or unavailable " + name_value)
		quit(1)
		return
	b.pressed.emit()
func shot(file: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not check(image.get_size() == Vector2i(1920,1080), "FHD required"): return
	image.save_png(evidence.path_join(file + ".png"))
func open_game(session_override: RefCounted = null) -> Node:
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(folder) if session_override == null else session_override
	root.add_child(game)
	return game
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		evidence = args[0]
		DirAccess.make_dir_recursive_absolute(evidence)
	folder = "user://ui-late-probe/%s" % Time.get_ticks_usec()
	var game := open_game()
	press("NewGameOptions")
	app.find_child("Seed", true, false).text = "1"
	press("NewGame")
	if not check(app._dialog.is_empty() and app.projection.phase == "actions", "New game should open in world overview"): return
	for power: String in app._ui.POWER_ORDER:
		if power in ["anchor", "manifest"]: continue
		press("PowerIndex")
		press("Sigil_POWER_" + power.to_upper())
		press("PreparePower")
		if not check(app._dialog == "task_action", "Power unreachable: " + power): return
		app._tasks.back()
		press("ClosePowers")
	press("PowerIndex")
	press("Sigil_POWER_LISTEN")
	press("PreparePower")
	await shot("01-listen")
	var whispers: int = app.projection.whispers
	press("ExecuteDraft")
	if not check(app._dialog == "receipt" and app.projection.whispers < whispers, "Listen did not execute and pay"): return
	await shot("01-result")
	app._close_surface()
	for round_offset: int in 2:
		press("PhaseAction")
		press("ConfirmEnd")
		if round_offset == 0 and app._dialog == "prayer_intro": press("DismissPrayers")
	if not check(app._dialog.is_empty(), "Third round should open in the overview"): return
	press("PrayerIndex")
	var prayer: Dictionary = app._pending_prayers().front()
	press("IntroPrayer_" + prayer.id)
	if app._prayers._is_space():
		var ready := false
		for candidate: Node in app._surface.find_children("SpaceChoice_*", "Button", true, false):
			if candidate.disabled: continue
			candidate.pressed.emit()
			var submit: Button = app._surface.find_child("Respond", true, false)
			if submit != null and not submit.disabled:
				ready = true
				break
		if not check(ready, "No payable prayer-space response in fixture"): return
	else:
		press("Mode_deep")
	press("Respond")
	if app._dialog == "prayer_confirm": press("ConfirmPrayer")
	if not check(app.projection.prayer_response_spent, "Prayer did not receive a response"): return
	app._close_surface()
	press("RelicIndex")
	await shot("02-relics")
	app._tasks.back()
	press("PowerIndex")
	press("Sigil_POWER_ANCHOR")
	press("PreparePower")
	await shot("03-anchor")
	app._tasks.back()
	if app._dialog == "powers": press("ClosePowers")
	press("Budget")
	await shot("04-budget")
	app._tasks.back()
	press("Menu")
	press("Attention")
	var p: Dictionary = app.projection
	var known: Dictionary = p.domains[0]
	app._tasks.open_action("attention/release_focus", {"domain":known.id})
	press("ExecuteDraft")
	if app._dialog == "task_confirm":
		press("CancelAction")
		if not check(app.projection.attention.scheduled_release.is_empty(),"cancel scheduled release"): return
		press("ExecuteDraft")
		press("ConfirmAction")
	if not check(app.projection.attention.focus == p.attention.focus and app.projection.attention.scheduled_release.get(known.id) == p.turn + 1,"release changed occupied capacity early or wrong date"): return
	app._close_surface()
	press("Menu")
	press("Attention")
	await shot("05-attention")
	app._tasks.back()
	press("History")
	var records: Array[Node] = app._surface.find_children("Record_*", "Button", true, false)
	if not check(not records.is_empty(), "history missing public records"): return
	records[0].pressed.emit()
	await shot("06-history")
	app._tasks.back()
	press("Self")
	await shot("07-self")
	app._tasks.request_rest()
	if not check(app._dialog == "task_subject" and app.projection.turn == p.turn, "unavailable rest should reject"): return
	app._tasks.back()
	press("Menu")
	if args.has("save-exit"):
		press("SaveExit")
		var saved := Session.new(folder)
		if check(saved.continue_game().get("ok", false) and saved.project().turn == app.projection.turn, "Save and exit did not persist the current round"):
			print("SAVE_EXIT_OK")
		return
	press("Save")
	var previous: Dictionary = app.projection.duplicate(true)
	var broken := ProjectSettings.globalize_path(folder.path_join("broken.json"))
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var hash_before := FileAccess.get_sha256(broken)
	app._import_copy(broken)
	if not check(app.projection.turn == previous.turn and FileAccess.get_sha256(broken) == hash_before and not app._notice_text.is_empty(), "bad import replaced or touched original"): return
	app._large_text = true
	app._refresh()
	press("History")
	records = app._surface.find_children("Record_*", "Button", true, false)
	if not check(not records.is_empty(), "large text lost history list"): return
	records[0].pressed.emit()
	await shot("06-history-large")
	app._tasks.back()
	press("Menu")
	press("Settings")
	await shot("08-settings")
	game.free()
	game = open_game()
	press("Continue")
	if app._dialog == "prayer_intro": app._close_surface()
	if not check(app.projection.turn == previous.turn and app.projection.attention.scheduled_release == previous.attention.scheduled_release,"continue lost same-turn release schedule"): return
	press("Menu")
	press("SealGame")
	press("CancelSeal")
	if not check(not app.projection.terminal, "Cancel sealed the campaign"): return
	press("SealGame")
	var before_seal: String = app.session.turn.snapshot()
	press("ConfirmSeal")
	if app.projection.terminal:
		game.free()
		game = open_game()
		press("Continue")
		if not check(app.projection.terminal and app._tasks._subject.get("kind") == "ending", "Terminal save did not reopen read-only " + app._notice_text): return
		await shot("09-ending")
		if not check(not app.session.preview_action("POWER_LISTEN").ok, "Terminal admitted action"): return
	else:
		# Session.abandon already rejects these fixture states on the merge base.
		if not check(app._dialog == "menu" and not app._notice_text.is_empty() and app.session.turn.snapshot() == before_seal, "Rejected seal must leave the game intact and explain the failure"): return
		print("BASELINE_SEAL_REJECTED")
	game.free()
	game = open_game(RestSession.new(folder.path_join("rest")))
	app._start_new(7919)
	if app._dialog == "prayer_intro": press("DismissPrayers")
	if not check(app.projection.get("phase") == "actions", "Rest fixture did not reach action phase"): return
	var rest_before: Dictionary = app.projection
	press("Self")
	app._tasks.request_rest()
	if not check(app._dialog == "task_rest_confirm", "Rest did not offer confirmation"): return
	press("CancelRest")
	if not check(app.projection.wounds == rest_before.wounds and app.projection.faith == rest_before.faith, "Rest cancel changed resources"): return
	app._tasks.request_rest()
	press("ConfirmRest")
	if not check(app.projection.turn == rest_before.turn + 1 and app.projection.wounds < rest_before.wounds, "Rest did not recover and advance"): return
	print("LATE_OK response, ten power entrances and paid Listen, relic empty, anchor entry, budget, pending release, public history, rest gate and recovery, bad save, continue, seal outcome")
	game.free()
	quit()
