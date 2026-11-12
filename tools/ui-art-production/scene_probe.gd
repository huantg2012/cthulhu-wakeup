extends "res://tools/ui-art-production/overview_probe.gd"
## Evidence routes through production controls. The optional existing Session is copied unchanged.
var batch := ""

func setup(args: PackedStringArray) -> bool:
	var isolated := "user://ui-art-production-probe/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	var fixture := ""
	for arg: String in args:
		if arg.begins_with("--save="): fixture = arg.trim_prefix("--save=")
	if not fixture.is_empty():
		var path := isolated.path_join("1793836800-7001.json")
		if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(fixture), ProjectSettings.globalize_path(path)) == OK, "Could not copy save"): return false
	var main := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if not require(main != null, "Cannot load production main scene"): return false
	var game := main.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(isolated)
	app.display_settings_path = isolated.path_join("display.cfg")
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	app._large_text = "--large" in args
	await process_frame
	if batch == "b10": await capture("title")
	if not fixture.is_empty():
		if not await click("SavedGames"): return false
		if not await click("SavedGame_0"): return false
	else:
		if not await click("NewGameOptions"): return false
		(app.find_child("Seed", true, false) as LineEdit).text = "1"
		if not await click("NewGame"): return false
	return require(app.projection.get("active", false), "Campaign didn't load: " + app._notice_text)

func capture(file_name: String) -> void:
	if output.is_empty(): return
	await create_timer(0.26).timeout
	RenderingServer.force_draw(false)
	require(root.get_texture().get_image().save_png(output.path_join(file_name + ".png")) == OK, "Could not capture " + file_name)

func world(id: String) -> bool:
	var fan: Control = app.find_child("WorldFan", true, false)
	var index := -1
	for i: int in fan.cards.size():
		if fan.cards[i].get_meta("subject_id") == id: index = i; break
	if not require(index >= 0, "Missing public world " + id): return false
	fan.grab_focus()
	while fan.focus_index != index:
		var previous: int = fan.focus_index
		await press_key(KEY_RIGHT if index > fan.focus_index else KEY_LEFT)
		if not require(fan.focus_index != previous, "World focus did not change"): return false
	await press_key(KEY_ENTER)
	return require(app._world_id == id, "World didn't open: " + id)

func wait_art(name_value: String, needed := true) -> bool:
	var art := app.find_child(name_value, true, false) as TextureRect
	if not require(art != null, "No object slot " + name_value): return false
	if not needed: return true
	var deadline := Time.get_ticks_msec() + 30000
	while art.texture == null and Time.get_ticks_msec() < deadline:
		await process_frame
	return require(art.texture != null, "No art delivered for " + name_value + " key=" + str(art.get_meta("art_key", "")))

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size() >= 2, "Need output path and batch"): return
	output = args[0]
	batch = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	if not await setup(args): return
	var ok := false
	match batch:
		"b03": ok = await local_archive_cult()
		"b04": ok = await people_and_prayer()
		"b04-new": ok = await prayer_only()
		"b09-compare": ok = await compare_people()
		"b05": ok = await powers()
		"b06": ok = await anchor_and_activity()
		"b07": ok = await economy()
		"b08": ok = await rounds_and_event()
		"b09": ok = await records_and_ending()
		"b10": ok = await settings_and_pause()
	if ok:
		print("PASS: ", batch)
		quit()

func local_archive_cult() -> bool:
	var before: String = app.session.turn.snapshot()
	var known_cults: Array = app.projection.cults.filter(func(c: Dictionary) -> bool: return c.status != "destroyed")
	var first_id: String = known_cults[0].domain if not known_cults.is_empty() else app.projection.domains[0].id
	if not await world(first_id): return false
	if not await wait_art("SceneSlot"): return false
	await capture("local")
	if not await click("MetricHelp_barrier"): return false
	await capture("intelligence")
	await press_key(KEY_ESCAPE)
	if not require(app._dialog.is_empty() and app._world_id == first_id, "Intelligence did not return to local"): return false
	if not known_cults.is_empty():
		if not await click("LocalCult"): return false
		await capture("cult")
		if not await click("Orders"): return false
		await capture("cult-orders")
		await press_key(KEY_ESCAPE)
		await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	if not await click("AllWorlds"): return false
	var field := app.find_child("ArchiveSearch", true, false) as LineEdit
	field.text = "無此名稱"
	field.text_changed.emit(field.text)
	await process_frame
	if not require(app.find_child("WorldRecord_" + first_id, true, false) == null, "No-match search still shows results"): return false
	if not await click("ClearArchiveSearch"): return false
	if not await click("WorldRecord_" + first_id): return false
	await capture("archive")
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	return require(app._world_id.is_empty() and app._dialog.is_empty() and app.session.turn.snapshot() == before, "Archive mutated or changed scope")

func people_and_prayer() -> bool:
	if not await click("People"): return false
	if not await wait_art("DirectoryPortrait"): return false
	var slot: TextureRect = app.find_child("DirectoryPortrait", true, false)
	var same: String = slot.get_meta("art_key")
	if not await click("DirectoryTab_history"): return false
	await process_frame
	slot = app.find_child("DirectoryPortrait", true, false)
	if not require(slot.get_meta("art_key") == same and slot.texture != null, "Directory tab changed portrait"): return false
	await capture("people")
	await press_key(KEY_ESCAPE)
	return await prayer_only()

func prayer_only() -> bool:
	var before: String = app.session.turn.snapshot()
	if not await click("PrayerIndex"): return false
	if app._dialog == "prayer_intro":
		var buttons: Array[Node] = app._surface.find_children("IntroPrayer_*", "Button", true, false)
		if not require(not buttons.is_empty(), "No prayer in current save"): return false
		if not await click(str(buttons[0].name)): return false
	if not require(app._dialog == "prayer_detail", "Did not open a formal prayer"): return false
	var art: TextureRect = app._surface.find_child("SceneSlot", true, false)
	if not str(art.get_meta("art_key", "")).is_empty():
		if not await wait_art("SceneSlot"): return false
	await capture("generated-prayer" if batch == "b04-new" else "prayer")
	var art_key: String = art.get_meta("art_key", "")
	if not art_key.is_empty() and first_button("Person_1") != null:
		if not await click_first("Person_1"): return false
		if not await wait_art("PeekPortrait"): return false
		var peek: TextureRect = app.find_child("PeekPortrait", true, false)
		if not require(peek.get_meta("art_key") == art_key, "Petitioner changed identity in related view"): return false
		await press_key(KEY_ESCAPE)
	var choices: Array[Node] = app._surface.find_children("SpaceChoice_*", "Button", true, false)
	for choice: Button in choices:
		if not choice.disabled:
			if not await click(str(choice.name)): return false
			break
	var dismiss: Button = app._surface.find_child("DismissPrayer", true, false)
	if dismiss != null and not dismiss.disabled:
		if not await click("DismissPrayer"): return false
		if not require(app._dialog == "prayer_confirm", "Irreversible choice skipped its confirmation"): return false
		await capture("dismiss-confirmation")
		await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	return require(app.session.turn.snapshot() == before, "Reading and cancelling changed the Session")

func ensure_button(control: Button) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await process_frame

func first_button(pattern: String, text_value := "") -> Button:
	var scope: Control = app._surface
	if not is_instance_valid(scope): return null
	for control: Button in scope.find_children(pattern, "Button", true, false):
		if control.disabled or not control.is_visible_in_tree(): continue
		if text_value.is_empty() or control.text.contains(text_value): return control
	return null

func click_first(pattern: String, text_value := "") -> bool:
	var button := first_button(pattern, text_value)
	if not require(button != null, "No matching control: %s / %s" % [pattern, text_value]): return false
	await ensure_button(button)
	return await click(str(button.name))

func powers() -> bool:
	var before: String = app.session.turn.snapshot()
	if not await click("PowerIndex"): return false
	if not require(app._surface.find_children("Sigil_*", "Button", true, false).size() == 12, "Power circle lost entries"): return false
	await capture("powers")
	if not await click("Sigil_POWER_MANIFEST"): return false
	if not await click("PowerRules"): return false
	await capture("power-rules")
	await press_key(KEY_ESCAPE)
	if not await click("Sigil_POWER_LISTEN"): return false
	if not await click("PreparePower"): return false
	if not await click("ActionTab_domain"): return false
	var next := first_button("Choice_domain_*")
	if next != null:
		await ensure_button(next)
		if not await click(str(next.name)): return false
	await capture("preparation")
	await press_key(KEY_ESCAPE)
	return require(app.session.turn.snapshot() == before, "Preparation mutated the Session")

func anchor_and_activity() -> bool:
	var before: String = app.session.turn.snapshot()
	if not await world(app.projection.domains[0].id): return false
	if not await click("AnchorIndex"): return false
	if not await click_first("AnchorGoal_*"): return false
	await capture("anchor")
	if not await click("AnchorConditions"): return false
	await capture("anchor-conditions")
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	if not await click("Activities"): return false
	await capture("activities")
	await press_key(KEY_ESCAPE)
	return require(app.session.turn.snapshot() == before, "Reading anchor/activities mutated the Session")

func economy() -> bool:
	var before: String = app.session.turn.snapshot()
	if not await click("RelicIndex"): return false
	await capture("relics")
	await press_key(KEY_ESCAPE)
	if not await click("Budget"): return false
	if not await click_first("BudgetAnchor_*"): return false
	if not await click_first("ToggleSupply"): return false
	await capture("budget-draft")
	if not await click("SaveSupply"): return false
	if not await click("CancelSupply"): return false
	await press_key(KEY_ESCAPE)
	if not await click("Menu"): return false
	if not await click_first("Attention"): return false
	await capture("attention")
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	if not await click("Self"): return false
	await capture("manifest")
	var continue_ritual := first_button("*", "继续本轮降临")
	if continue_ritual != null:
		if not await click(str(continue_ritual.name)): return false
		await capture("manifest-renewal")
		await press_key(KEY_ESCAPE)
	if not await click_first("ReviewRest"): return false
	if app._dialog == "task_rest_confirm":
		await capture("rest")
		await press_key(KEY_ESCAPE)
	return require(app.session.turn.snapshot() == before, "An unconfirmed expense mutated the Session")

func rounds_and_event() -> bool:
	for expected_turn: int in range(2, 5):
		if app._dialog == "prayer_intro":
			if not await click("DismissPrayers"): return false
		if not await click("PhaseAction"): return false
		if expected_turn == 2:
			await capture("responsibility")
			if not await click("ReviewSupply"): return false
			await press_key(KEY_ESCAPE)
			if not require(app._dialog == "end", "Review did not return to turn responsibility: " + str(app._dialog)): return false
		if not await click("ConfirmEnd"): return false
		if not require(app.projection.turn == expected_turn, "Did not advance to expected turn"): return false
	if not require(app._dialog == "event", "Older real save did not produce a pending event"): return false
	await press_key(KEY_ESCAPE)
	if not require(app._dialog == "event", "Escape bypassed the event"): return false
	await capture("event")
	if not await click("InspectWorld"): return false
	if not await click("ReturnEvent"): return false
	var item: Dictionary = app._pending_events()[0]
	var option := "Option_" + str(item.descriptor.default_action)
	if not await click_first(option): return false
	var before: String = app.session.turn.snapshot()
	await press_key(KEY_ESCAPE)
	if not require(app._dialog == "event" and app.session.turn.snapshot() == before, "Cancelling event choice committed"): return false
	if not await click_first(option): return false
	await capture("event-review")
	if not await click("ConfirmEvent"): return false
	if app._dialog == "prayer_intro":
		if not await click("DismissPrayers"): return false
	if not await click("Receipt"): return false
	await capture("receipt")
	return require(app.projection.phase == "actions" and not app._receipt.is_empty(), "No real outcome after resolving event")

func records_and_ending() -> bool:
	if not await click("History"): return false
	if not await click_first("Record_*"): return false
	await capture("history")
	await press_key(KEY_ESCAPE)
	if not await click("Menu"): return false
	if not await click("SealGame"): return false
	if not await click("ConfirmSeal"): return false
	if not require(app.projection.get("terminal", false), "Expected an actual sealed Session"): return false
	await capture("ending")
	if not await click("ReviewEndingHistory"): return false
	await press_key(KEY_ESCAPE)
	return require(app.projection.get("terminal", false), "Review changed sealed state")

func settings_and_pause() -> bool:
	if not await click("Menu"): return false
	await capture("pause")
	if not await click_first("Settings"): return false
	if not await click("TextSize"): return false
	await capture("settings")
	await press_key(KEY_ESCAPE)
	if not await click_first("SavedGames"): return false
	await capture("saves")
	await press_key(KEY_ESCAPE)
	if not await click_first("NewGameOptions"): return false
	(app.find_child("Seed", true, false) as LineEdit).text = "not an integer"
	if not await click("NewGame"): return false
	if not require(app._dialog == "new_game", "Invalid seed changed campaign"): return false
	await capture("invalid-seed")
	await press_key(KEY_ESCAPE)
	if not await click("SealGame"): return false
	await capture("seal-confirmation")
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	return require(app._dialog.is_empty() and not app.projection.get("terminal", false), "Cancelled seal: dialog=%s terminal=%s" % [app._dialog, app.projection.get("terminal", false)])

# Scene coverage uses native keyboard activation, independent of pointer motion.
# The overview and world-card probes cover mouse hit targets separately.
func click(path: String) -> bool:
	await process_frame
	var scope: Control = app._surface if is_instance_valid(app._surface) else app._stage
	var control := scope.find_child(path, true, false) as Button
	if not require(control != null and not control.disabled and control.is_visible_in_tree(), "Unavailable: %s in %s" % [path, app._dialog]): return false
	await ensure_button(control)
	control.grab_focus()
	await process_frame
	if not require(root.gui_get_focus_owner() == control, "Did not focus " + path): return false
	await press_key(KEY_ENTER)
	return true

func compare_people() -> bool:
	var cult: Dictionary = app.projection.cults[0]
	if not await world(cult.domain): return false
	if not await click("LocalCult"): return false
	if not await click("Roster"): return false
	if not await click_first("Member_*"): return false
	if not await click("MemberActions"): return false
	if not await click_first("*", "留作对照"): return false
	if not require(app.find_child("ComparisonSlot_0", true, false) != null, "Object comparison didn't open"): return false
	await capture("comparison")
	await press_key(KEY_ESCAPE)
	return true
