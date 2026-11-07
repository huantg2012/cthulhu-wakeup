extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Copy = preload("res://src/content/player_text.gd")
const Scene = preload("res://src/presentation/production/game_root.tscn")
var app: Control
var output := "/tmp/echoes-player-copy"

func _initialize() -> void: run.call_deferred()

func need(value: bool, message: String) -> bool:
	if not value: push_error(message); quit(1)
	return value

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_value + ".png"))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var session := Session.new(output.path_join("saves"))
	if not need(session.continue_game("res://docs/qa/ui-manifest/saves/ongoing.json").ok, "Existing save must still load"): return
	var catalog: RefCounted = session.catalog
	var original: String = JSON.stringify(catalog.tables)
	if not need(catalog.tables.relics.RELIC_ECHO_BELL.name == "余响铃" and catalog.display_tables.relics.RELIC_ECHO_BELL.name == "唤梦铃", "Display and rules are separate"): return
	var identities := {}
	for ordinal: int in range(1, 1025):
		var name_value: String = catalog.player_text.person_name("NPC-%08d" % ordinal)
		if not need(not identities.has(name_value), "Names remain distinct within authored pool"): return
		identities[name_value] = true
	var before: String = session.turn.snapshot()
	var knowledge: Dictionary = session.knowledge_snapshot().duplicate(true)
	var projection: Dictionary = session.project()
	for person: Dictionary in projection.people:
		if not person.has("profile"): continue
		if not need(person.title == session.object_title(person.id) and person.has("role_name") and not person.title.contains("0000"), "Stable public person names and roles"): return
	for office: Dictionary in projection.institutions:
		if not need(not str(office.title).contains("机构") and not str(office.title).contains("DOMAIN"), "Institutions have local names"): return
	if not need(session.object_title("NPC-99999999") == "尚未知晓", "Naming must not disclose unknown identities"): return
	for relic: Dictionary in projection.relics:
		if not need(not session.object_title(relic.id).contains("FACT-"), "Relic titles do not expose source IDs"): return
	var choices: Dictionary = session.action_choices("route/context", {"domain":"DOMAIN-001"})
	for field: Dictionary in choices.fields:
		if field.key == "operation":
			for option: Dictionary in field.options:
				if not need(option.label == catalog.display_tables.progression_route_operations[option.id].name, "Choices use edited activity names"): return
	# A text file cannot change any numeric rule. Failed loads are transactional.
	var invalid_dir: String = output.path_join("invalid")
	DirAccess.make_dir_recursive_absolute(invalid_dir)
	var invalid := FileAccess.open(invalid_dir.path_join("player_text.csv"), FileAccess.WRITE)
	invalid.store_string("table,key,field,text\npowers,POWER_DREAM,faith,999\n"); invalid.close()
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://data/person_names.csv"), invalid_dir.path_join("person_names.csv"))
	var copy := Copy.new()
	if not need(not copy.load_files(catalog.tables, invalid_dir) and copy.tables.is_empty(), "Reject rule fields in text catalog"): return
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = session
	root.add_child(game)
	app._close_surface()
	app._large_text = false
	app._refresh()
	app._tasks.open_subject("relic", str(projection.relics[0].id))
	await capture("relic")
	app._large_text = true
	app._close_surface()
	app._refresh()
	app._tasks.open_subject("person", str(projection.people[0].id))
	await capture("person-large")
	if not need(session.turn.snapshot() == before and session.knowledge_snapshot() == knowledge and JSON.stringify(catalog.tables) == original, "Copy/rendering is read-only"): return
	game.queue_free()
	await process_frame
	print("PLAYER_COPY_OK old_save=compatible names=1024 rule_fields=rejected state=unchanged")
	quit()
