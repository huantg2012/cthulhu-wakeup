extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Scene = preload("res://src/presentation/production/game_root.tscn")
var app: Control
func _initialize() -> void: run.call_deferred()
func press(id: String) -> void:
	await process_frame
	var start := Time.get_ticks_msec()
	while app._tasks._candidate_job != null or not app._tasks._candidate_queue.is_empty():
		assert(Time.get_ticks_msec() - start < 20000, "availability did not settle")
		await process_frame
	var b: Button = app.find_child(id, true, false)
	assert(b != null and not b.disabled, "missing: " + id)
	b.pressed.emit()
func run() -> void:
	var player := Session.new("/tmp/ui-actions-all")
	assert(player.continue_game("res://docs/qa/ui-manifest/saves/ongoing.json").ok)
	player.slot = "/tmp/ui-actions-all-working.json"
	var game := Scene.instantiate(); app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = player; root.add_child(game); app._close_surface()
	var before: String = player.turn.snapshot()
	var keys: Array = player.catalog.tables.powers.keys()
	keys.append_array(["relic/equip", "relic/unequip", "relic/unbind", "relic/recover", "relic/disassemble", "attention/focus", "attention/release_focus", "attention/enroll", "attention/leave", "attention/release_project", "route/context"])
	for entry: Dictionary in player.action_entries("opportunity/").slice(0, 3): keys.append(entry.key)
	for key: String in keys:
		if key == "POWER_BESTOW": continue
		app._tasks.open_action(key)
		if key == "POWER_ANCHOR":
			assert(app._tasks._subject.kind == "anchors", "anchor begins with an institution goal")
			app._close_surface(); continue
		assert(app._dialog == "task_action", "no action " + key)
		var row: Dictionary = app._actions.decision_row(app._tasks, player.action_entry(key, app._tasks.draft.selection), app._tasks.draft.selection)
		if row.is_empty(): app._close_surface(); continue
		assert(app.find_child("ActionTab___outcomes", true, false) != null, "missing result tab " + key)
		for field: Dictionary in app._actions.visible_fields(row.fields):
			var b: Button = app.find_child("ActionTab_"+str(field.key), true, false)
			assert(b != null, "missing field " + key + " / " + str(field.key))
			b.pressed.emit()
			assert(app.find_child("ActionOptionsScroll", true, false) != null)
		for field: Dictionary in row.fields:
			if app._actions.fixed_evidence(field):
				assert(app.find_child("ActionTab_" + str(field.key), true, false) == null)
				assert(app._tasks.draft.selection.get(field.key) == field.options[0].id)
		if key in ["POWER_DREAM", "POWER_SACRIFICE", "POWER_TRANSFER", "POWER_ANCHOR", "relic/equip"]:
			if DisplayServer.get_name() != "headless":
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/ui-action-"+key.replace("/","-")+".png")
		app._close_surface()
	print("ALL_ACTION_TABS_OK ",keys.size())
	assert(player.turn.snapshot()==before)
	var oracle: Dictionary = player.action_entry("POWER_ORACLE", {})
	var prayer_label_checked := false
	for field: Dictionary in oracle.get("fields", []):
		if field.key != "declared_action": continue
		for option: Dictionary in field.options:
			if str(option.id).begins_with("PRAYER/"):
				assert(not app._actions._option_title(app._tasks, option).begins_with("PRAYER/"))
				prayer_label_checked = true
	assert(prayer_label_checked, "known prayer declarations missing")
	app._tasks.open_action("POWER_DREAM", {"domain":"DOMAIN-001", "npc":"NPC-00000007", "source":"FACT-00000269"})
	var dream: Dictionary = player.preview_action("POWER_DREAM", app._tasks.draft.selection)
	assert(dream.get("ok", false) and dream.preview.get("probability") == 55)
	var dream_row: Dictionary = player.action_entry("POWER_DREAM", app._tasks.draft.selection)
	var same_contact: Array = []
	for f: Dictionary in dream_row.fields:
		if f.key == "source": same_contact = f.options
	assert(same_contact.size() > 1, "fixture must retain distinct contact proofs")
	for candidate: Dictionary in same_contact:
		var inputs: Dictionary = app._tasks.draft.selection.duplicate(true); inputs.source = candidate.id
		var alternative: Dictionary = player.action_entry("POWER_DREAM", inputs)
		assert(alternative.preview.ok)
		for key: String in ["faith", "whispers", "probability", "outcomes"]:
			assert(alternative.preview.preview.get(key) == dream.preview.get(key), "equivalent dream proof changed " + key)
		assert(app._actions._outcome_effects(app._tasks, alternative, inputs) == app._actions._outcome_effects(app._tasks, dream_row, app._tasks.draft.selection))
		var presented: Dictionary = app._actions.decision_row(app._tasks, alternative, inputs)
		for field: Dictionary in presented.fields:
			if field.key == "source": assert(field.options.size() == 1 and field.options[0].id == candidate.id, "remembered proof replaced")
	assert(app._tasks.draft.selection.source == "FACT-00000269" and app.find_child("ActionTab_source", true, false) == null)
	print("EQUIVALENT_DREAM_CONTACT_OK")
	await press("ActionTab___outcomes")
	var texts: PackedStringArray = []
	for label: Label in app.find_child("ActionOptionsScroll", true, false).find_children("*", "Label", true, false): texts.append(label.text)
	var visible: String = "\n".join(texts)
	assert(visible.contains("深刻成功  11%") and visible.contains("成功  44%") and visible.contains("失败  36%") and visible.contains("灾变  9%"))
	assert(player.turn.snapshot() == before)
	app._close_surface()
	print("DREAM_OUTCOMES_OK")
	# Legal numeric selection and real migration are covered by production_transfer_probe.
	app._tasks.open_action("POWER_LISTEN", {"domain":"DOMAIN-001"})
	var row: Dictionary = player.action_entry("POWER_LISTEN", app._tasks.draft.selection)
	if not row.preview.get("ok",false):
		for field: Dictionary in row.fields:
			if field.key == "source" and not field.options.is_empty():
				await press("ActionTab_source"); await press("Choice_source_0")
	var result: Dictionary = player.preview_action("POWER_LISTEN", app._tasks.draft.selection)
	assert(result.ok, "Listen preview not available " + str(result))
	await press("ActionTab___outcomes")
	assert(app.find_child("ActionOptionsScroll", true, false) != null)
	var whispers: int = app.projection.whispers
	await press("ExecuteDraft")
	assert(app._dialog == "receipt" and app.projection.whispers == whispers-1)
	print("ACTION_EXEC_OK")
	game.free();quit()
