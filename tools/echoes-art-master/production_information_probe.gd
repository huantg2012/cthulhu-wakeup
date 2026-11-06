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
	for entry: String in ["Activities", "AnchorIndex", "RelicIndex", "CultIndex", "WorldArchive", "People", "Budget", "Self"]:
		assert(app.find_child(entry, true, false) != null)
	await capture("01-main")
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
	app._tasks.open_subject("history")
	await capture("08-history")
	assert(s.turn.snapshot() == before and s.knowledge_snapshot() == knowledge, "reading mutated state or knowledge")
	print("INFORMATION_OWNERSHIP_ROUTES_EVIDENCE_PURITY_OK")
	game.free(); quit()
