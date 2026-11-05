extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Scene = preload("res://src/presentation/production/game_root.tscn")
var app: Control
func _initialize() -> void: run.call_deferred()
func press(id: String) -> void:
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
		assert(app._dialog == "task_action", "no action " + key)
		var row: Dictionary = player.action_entry(key, app._tasks.draft.selection)
		if row.is_empty(): app._close_surface(); continue
		assert(app.find_child("ActionTab___outcomes", true, false) != null, "missing result tab " + key)
		for field: Dictionary in row.fields:
			var b: Button = app.find_child("ActionTab_"+str(field.key), true, false)
			assert(b != null, "missing field " + key + " / " + str(field.key))
			b.pressed.emit()
			assert(app.find_child("ActionOptionsScroll", true, false) != null)
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
	press("ActionTab___outcomes")
	var texts: PackedStringArray = []
	for label: Label in app.find_child("ActionOptionsScroll", true, false).find_children("*", "Label", true, false): texts.append(label.text)
	var visible: String = "\n".join(texts)
	assert(visible.contains("深刻成功  11%") and visible.contains("成功  44%") and visible.contains("失败  36%") and visible.contains("灾变  9%"))
	assert(player.turn.snapshot() == before)
	app._close_surface()
	print("DREAM_OUTCOMES_OK")
	# Numeric candidates remain bounded and do not create one control per person.
	app._tasks.open_action("POWER_TRANSFER", {"domain":"DOMAIN-001"})
	press("ActionTab_escort")
	var count: SpinBox = app.find_child("Field_escort", true, false)
	assert(count != null and count.max_value == 81)
	count.value = 5; press("Apply_escort")
	assert(app._tasks.draft.selection.escort == 5)
	press("ActionTab_npc"); press("Choice_npc_0")
	var selected_npc: String = app._tasks.draft.selection.npc
	press("Read_npc"); assert(app._dialog == "task_related")
	app._tasks.back(); assert(app._tasks.draft.selection.npc == selected_npc and app._tasks.draft.selection.escort == 5)
	press("ActionTab_domain"); press("Choice_domain_1")
	assert(not app._tasks.draft.selection.has("npc") and player.turn.snapshot() == before)
	app._close_surface()
	print("TRANSFER_NUMERIC_OK")
	app._tasks.open_action("POWER_LISTEN", {"domain":"DOMAIN-001"})
	var row: Dictionary = player.action_entry("POWER_LISTEN", app._tasks.draft.selection)
	if not row.preview.get("ok",false):
		for field: Dictionary in row.fields:
			if field.key == "source" and not field.options.is_empty():
				press("ActionTab_source"); press("Choice_source_0")
	var result: Dictionary = player.preview_action("POWER_LISTEN", app._tasks.draft.selection)
	assert(result.ok, "Listen preview not available " + str(result))
	press("ActionTab___outcomes")
	assert(app.find_child("ActionOptionsScroll", true, false) != null)
	var whispers: int = app.projection.whispers
	press("ExecuteDraft")
	assert(app._dialog == "receipt" and app.projection.whispers == whispers-1)
	print("ACTION_EXEC_OK")
	game.free();quit()
