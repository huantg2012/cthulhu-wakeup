extends SceneTree
## Short real-Session check for the archive and the next settlement.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
const ORIGINAL := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
var app: Control
var evidence := ""

func _initialize() -> void:
	run.call_deferred()

func _press(node_name: String) -> void:
	var button: Button = app.find_child(node_name, true, false)
	if button == null or button.disabled:
		_expect(false, "Missing or disabled control " + node_name)
		return
	button.pressed.emit()

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("B03: " + message)
		quit(1)
	return condition

func _capture(name_value: String) -> void:
	if evidence.is_empty(): return
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if _expect(frame.get_size() == Vector2i(1920, 1080), "expected 1080p capture"):
		_expect(frame.save_png(evidence.path_join(name_value + ".png")) == OK, "capture failed")

func _dismiss_intro() -> void:
	if app._dialog == "prayer_intro": _press("DismissPrayers")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless": evidence = args[0]
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new("user://production-ui-b03-probe/%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	root.add_child(game)
	var original_hash := FileAccess.get_sha256(ORIGINAL)
	app._import_copy(ProjectSettings.globalize_path(ORIGINAL))
	_dismiss_intro()
	if not _expect(app.projection.turn == 4 and app.projection.cults.size() == 1, "first-cult save did not open"): return
	var cult: Dictionary = app.projection.cults[0]
	var member: String = cult.leader
	var before_faith: int = app.projection.faith
	_press("Menu")
	_press("WorldArchive")
	var search: LineEdit = app.find_child("ArchiveSearch", true, false)
	search.text = "zz-no-match"
	search.text_changed.emit(search.text)
	if not _expect(app._world_management._list_buttons.is_empty(), "search should have no matches"): return
	_press("ClearArchiveSearch")
	_press("ArchiveScope")
	if not _expect(app._world_management._list_buttons.has(cult.domain), "focused scope lost the cult world"): return
	_press("ArchiveScope")
	if not _expect(app._world_management._list_buttons.is_empty(), "unfocused scope included a focused world"): return
	_press("ArchiveScope")
	_press("WorldRecord_" + cult.domain)
	_press("ArchiveCult")
	_press("Roster")
	_press("Member_" + member)
	_press("MemberCarried")
	if not _expect(app._world_management._member == member and app._world_management._tab == "carried", "member or column was lost"): return
	await _capture("01-member-roster")
	_press("WorldBack")
	_press("Orders")
	_press("Strategy_conceal")
	_press("Roster")
	_press("WorldBack")
	if not _expect(app.projection.faith == before_faith and app.projection.economy_plan.strategies.is_empty(), "view or preview changed the actual plan"): return
	_press("Orders")
	if not _expect(not app.find_child("SaveCultPlan", true, false).disabled, "roster return lost the drafted strategy"): return
	await _capture("02-plan-preview")
	_press("SaveCultPlan")
	if not _expect(app.projection.faith == before_faith and app.projection.economy_plan.strategies.get(cult.id) == "conceal", "instruction did not register without payment"): return
	# Controlled precondition for an archive-only world. Use formal attention
	# and prayer actions outside the B03 player-facing controls.
	if not _expect(app.session.execute_action("attention/release_focus", {"domain": cult.domain}, true).ok, "could not schedule focus release"): return
	_press("PhaseAction")
	_press("ConfirmEnd")
	_dismiss_intro()
	var actual: Array = app._world_management._settlements.get(cult.id, [])
	if not _expect(app.projection.turn == 5 and actual.size() == 2 and actual[0].effective == "conceal" and actual[0].fee == 0 and actual[1].actual == 0, "actual settlement did not apply the registered instruction"): return
	if not _expect("实际入账 0 信仰" in " ".join(app._receipt), "round receipt omitted actual income"): return
	_press("World_" + cult.domain)
	_press("LocalCult")
	await _capture("03-settlement")
	app._world_management.close()
	var pending: Array = app._pending_prayers()
	var local_response := ""
	for prayer: Dictionary in pending:
		if prayer.card.domain != cult.domain: continue
		var variants: Array = ["shallow", "deep"]
		if prayer.descriptor.get("space", false):
			variants = app.session.prayer_space_choices(prayer.id).map(func(choice: Dictionary) -> String: return str(choice.id))
		for variant: String in variants:
			var key: String = prayer.key + "/" + variant
			if not app.session.preview_action(key).get("ok", false): continue
			local_response = key
			break
		if not local_response.is_empty(): break
	if not _expect(not local_response.is_empty(), "original domain lost all payable requests"): return
	if not _expect(local_response.begins_with("prayer/PS-") and not cult.domain in app.session.world.state.simulation.focused, "fixture did not reach a generated request in a released world"): return
	if not _expect(app.session.execute_action(local_response, {}, true).ok, "could not respond to the generated situation while refocusing its original world"): return
	var saved: Dictionary = app.session.save_game()
	var resumed := Session.new(app.session.save_directory)
	if not _expect(saved.get("ok", false) and resumed.continue_game(saved.path).get("ok", false) and resumed.turn.snapshot() == app.session.turn.snapshot(), "reopened save did not validate the generated prayer's attention receipt"): return
	app._refresh()
	if not _expect(app._world_id == cult.domain, "losing focus erased the viewed world"): return
	_press("Menu")
	_press("WorldArchive")
	var clues: Array = app.projection.domains.filter(func(w: Dictionary) -> bool: return w.has("已知范围"))
	if not _expect(not clues.is_empty(), "new offer displaced the other world's contact clue"): return
	var clue: Dictionary = clues[0]
	_press("WorldRecord_" + clue.id)
	if not _expect(app._views._current_cult(app, clue.id).is_empty() and app.find_child("ArchiveCult", true, false) == null, "clue-only world displayed a cult"): return
	await process_frame
	_press("WorldRecord_" + cult.domain)
	if not _expect(app._surface.find_child("Observation_*", true, false) == null, "archive reintroduced a separate observation page"): return
	await _capture("04-world-archive")
	_press("WorldBack")
	if not _expect(app._world_management._domain.is_empty() and root.gui_get_focus_owner().name == "WorldRecord_" + cult.domain, "World detail did not return to its archive row"): return
	_press("WorldRecord_" + cult.domain)
	_press("EnterLocalWorld")
	if not _expect(app._dialog.is_empty() and app._world_id == cult.domain, "Archive could not deliberately enter a local world"): return
	if not _expect(original_hash == FileAccess.get_sha256(ORIGINAL), "original save changed"): return
	print("B03_OK archive-only world, search, clue-only world, inline observation explanation, member tabs, deferred strategy and actual settlement")
	game.free()
	quit()
