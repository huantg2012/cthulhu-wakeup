extends SceneTree
## Real public save: information ownership, direct routes and bounded evidence.
const Session = preload("res://src/presentation/session.gd")
const Scene = preload("res://src/presentation/production/game_root.tscn")
var app: Control
var captures := ""
func _initialize() -> void: run.call_deferred()
func text_of(node: Node) -> String:
	var out := ""
	if node is Label or node is Button: out += str(node.text) + "\n"
	for child in node.get_children(): out += text_of(child)
	return out
func press(id: String) -> void:
	var control: Button = app.find_child(id, true, false)
	assert(control != null and not control.disabled, id)
	control.pressed.emit()
func capture(id: String) -> void:
	if captures.is_empty(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(captures.path_join(id + ".png")) == OK)
func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty(): captures = OS.get_cmdline_user_args()[0]
	var s = Session.new("/tmp/information-review")
	assert(s.continue_game("res://docs/qa/ui-manifest/saves/ongoing.json").ok)
	s.slot = "/tmp/information-review-working.json"
	var game = Scene.instantiate(); app = game.get_node("Presentation/CanvasLayer/OverlayRoot"); app.session = s; root.add_child(game); app._close_surface()
	var before: String = s.turn.snapshot()
	var knowledge = s.knowledge_snapshot().duplicate(true)
	app._inspect_world("DOMAIN-001")
	for entry: String in ["Activities", "AnchorIndex", "RelicIndex", "People", "Budget", "Self"]:
		assert(app.find_child(entry, true, false) != null)
	await capture("01-main")
	assert(await check_world_intelligence())
	var cult: Dictionary = app.projection.cults[0]
	app._world_management.open_cult(cult.domain)
	var text := text_of(app._surface)
	for world_metric: String in ["屏障", "污染", "察觉", "稳定"]: assert(not text.contains(world_metric), "world property in cult: " + world_metric)
	assert(text.contains("信众") and text.contains("凝聚") and text.contains("成员活动"))
	assert(app.find_child("CultAnchors", true, false) == null and app.find_child("CultRelics", true, false) == null)
	await capture("02-cult")
	app._close_surface(); press("Activities")
	assert(text_of(app._surface).contains("活动"))
	await capture("03-activities")
	assert(app._dialog == "task_action" and app.find_child("PrepareActivity", true, false) == null)
	var selection := {"domain":"DOMAIN-001", "npc":"NPC-00000007", "operation":"ROUTE_MEMORY_PRACTICE"}
	assert(s.action_choices("route/context", selection).fields == s.action_entry("route/context", selection).fields)
	assert(s.action_choices("route/context", selection).details == s.action_entry("route/context", selection).details)
	app._tasks.open_subject("materials", cult.id)
	assert(app._tasks.draft.activity_cult == cult.id)
	for field: Dictionary in app._tasks._current_fields:
		if field.key == "npc":
			for option: Dictionary in field.options: assert(option.id in app._tasks.activity_actors())
	app._close_surface(); press("AnchorIndex")
	assert(text_of(app._surface).contains("锚点"))
	await capture("04-anchors")
	app._close_surface(); press("RelicIndex")
	await capture("05-relics")
	app._tasks.open_subject("institution", app.projection.institutions[0].id)
	assert(text_of(app._surface).contains("世界"))
	await capture("06-institution")
	var basis := ""
	for offset: int in range(0, s.known_sources().size(), 50):
		for fact: Dictionary in s.history_page(offset, 50).get("facts", []):
			if fact.kind == "anchor_basis": basis = fact.id; break
		if not basis.is_empty(): break
	assert(not basis.is_empty())
	app._tasks.open_subject("fact", basis)
	text = text_of(app._surface)
	assert(not text.contains("shared_memory") and not text.contains("已知前因") and not text.contains("实际变化"))
	assert(not text.contains("已知事实 ·"))
	await capture("07-record")
	app._tasks.open_subject("people")
	var directory: ScrollContainer = app._body_scroll
	var search: LineEdit = app._surface.find_child("SubjectSearch_people_", true, false)
	assert(search != null and not directory.is_ancestor_of(search))
	assert(not directory.is_ancestor_of(app._surface.find_child("PersonFilter_people_", true, false)))
	app._tasks.open_subject("history")
	press(str(app._surface.find_child("Record_*", true, false).name))
	var peek: Control = app._surface.get_node("RelatedPeek")
	var chronicle: ScrollContainer = app._body_scroll
	assert(chronicle.get_global_rect().end.x <= peek.get_global_rect().position.x, "chronicle list overlapped the record reader")
	assert(not chronicle.is_ancestor_of(app._surface.find_child("HistoryFilter", true, false)))
	await capture("08-history")
	assert(s.turn.snapshot() == before and s.knowledge_snapshot() == knowledge, "reading mutated state or knowledge")
	print("INFORMATION_OWNERSHIP_ROUTES_EVIDENCE_PURITY_OK")
	game.free(); quit()

func check_world_intelligence() -> bool:
	press("Menu")
	press("WorldArchive")
	var search: LineEdit = app.find_child("ArchiveSearch", true, false)
	search.text = "zz-no-match"
	search.text_changed.emit(search.text)
	app._world_management.close()
	press("Return")
	var current: String = app._world_id
	for row: Dictionary in app._worlds.duplicate():
		var domain: String = row.id
		app._select_world(domain)
		var help: Button = app.find_child("MetricHelp_barrier", true, false)
		help.grab_focus()
		assert(help.accessibility_description.contains("查看不会刷新") or help.accessibility_description.contains("尚未掌握"))
		press("MetricHelp_barrier")
		assert(app._world_management._page == "intelligence" and app._world_management._metric_field == "barrier")
		press("WorldBack")
		app.find_child("WorldObservations", true, false).grab_focus()
		press("WorldObservations")
		assert(app._world_management._page == "intelligence" and app._world_management._domain == domain)
		for duplicate: String in ["ArchiveSearch", "WorldRecord_*", "WorldAnchors", "WorldMaterials", "ArchiveCult", "WorldRelics", "Intelligence_observations", "IntelligenceSource_*"]:
			assert(app._surface.find_child(duplicate, true, false) == null, duplicate)
		assert(not text_of(app._surface).contains("观察依据"))
		for item: Dictionary in app.projection.institutions:
			assert((app._surface.find_child("Institution_" + str(item.id).validate_node_name(), true, false) != null) == (item.domain == domain), "institution scope: " + str(item.id) + " in " + domain)
		await process_frame
		await process_frame
		var reading: ScrollContainer = app._world_management._reading
		reading.scroll_vertical = 64
		var position := reading.scroll_vertical
		assert(not reading.is_ancestor_of(app._surface.find_child("WorldBack", true, false)))
		press("WorldBack")
		press("WorldObservations")
		await process_frame
		await process_frame
		assert(app._world_management._reading.scroll_vertical == position)
		press("WorldBack")
		assert(app._dialog.is_empty() and app._world_id == domain)
		assert(root.gui_get_focus_owner().name == "WorldObservations")
	app._select_world(current)
	press("Menu")
	press("WorldArchive")
	assert(app.find_child("ArchiveSearch", true, false).text == "zz-no-match", "local view reset global search")
	press("ClearArchiveSearch")
	press("WorldRecord_" + current)
	assert(app._surface.find_child("Observation_*", true, false) == null)
	app._world_management.close()
	press("Return")
	return true
