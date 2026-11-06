extends SceneTree
## Bounded UI latency regression: cold/reopened entries on new and nine-anchor saves.
## Measures the real synchronous handler and next rendered frame separately.
const Session = preload("res://src/presentation/session.gd")
const Production = preload("res://src/presentation/production/game_root.tscn")
class WatchedSession extends Session:
	var watch := false
	var global_queries := 0
	var transfers := 0
	func action_catalog(selection: Dictionary = {}, prefix: String = "") -> Array:
		if watch and prefix.is_empty(): global_queries += 1
		return super.action_catalog(selection, prefix)
	func material_transfer_options() -> Array:
		if watch: transfers += 1
		return super.material_transfer_options()
var app: Control
var game: Node
var evidence: String
var sample: String
var rows: Array = []
var checks: Array = []
var failed := false

func _initialize() -> void:
	run.call_deferred()

func need(condition: bool, message: String) -> void:
	checks.append({"check":message, "pass":condition})
	if not condition: failed = true; push_error(message)

func measure(label: String, action: Callable) -> void:
	await process_frame
	var start := Time.get_ticks_usec()
	action.call()
	var handler_ms := (Time.get_ticks_usec() - start) / 1000.0
	if DisplayServer.get_name() == "headless": await process_frame
	else: await RenderingServer.frame_post_draw
	var frame_ms := (Time.get_ticks_usec() - start) / 1000.0
	rows.append({"sample":sample, "entry":label, "handler_ms":handler_ms, "frame_ms":frame_ms})
	print("LATENCY ", sample, " ", label, " ", handler_ms, " / ", frame_ms)
	need(handler_ms < 250.0, sample + "/" + label + " handler <250ms")
	if DisplayServer.get_name() != "headless": need(frame_ms < 350.0, sample + "/" + label + " visible <350ms")

func press(id: String) -> void:
	var button: Button = app.find_child(id, true, false)
	need(button != null and not button.disabled, "enabled button " + id)
	if button != null and not button.disabled: button.pressed.emit()

func close() -> void:
	app._close_surface()
	app._tasks.reset()

func shoot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	need(captured.get_size() == Vector2i(1920,1080), "1080p " + name_value)
	captured.save_png(evidence.path_join(name_value + ".png"))

func sweep(player: RefCounted, name_value: String) -> void:
	sample = name_value
	game = Production.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = player
	root.add_child(game)
	close()
	await process_frame
	var before: String = player.turn.snapshot()
	var knowledge: Dictionary = player.knowledge_snapshot()
	player.watch = true
	for power: String in player.catalog.tables.powers:
		var transfers_before: int = player.transfers
		for pass_number: int in 2:
			await measure(power + ("/cold" if pass_number == 0 else "/reopen"), app._tasks.open_action.bind(power))
			need(app._dialog == "task_action", power + " opened preparation")
			if power == "POWER_LISTEN" and pass_number == 0: await shoot(sample + "-listen")
			app._close_surface()
		need(player.transfers == transfers_before, power + " does not query material transfers")
		close()
	if name_value == "nine-anchor":
		app._tasks.open_action("POWER_LISTEN")
		await measure("selector/open-world", press.bind("ActionTab_domain"))
		await process_frame
		while app._tasks._candidate_job != null or not app._tasks._candidate_queue.is_empty(): await process_frame
		await measure("selector/choose-world", press.bind("Choice_domain_0"))
		var selected: Dictionary = app._tasks.draft.selection.duplicate(true)
		await measure("selector/read-world", press.bind("Read_domain"))
		need(app._dialog == "task_related", "associated reading hides action controls")
		await measure("selector/return-to-action", app._tasks.back)
		need(app._dialog == "task_action" and app._tasks.draft.selection == selected, "associated return preserves selection and refreshes preview")
		close()
	for id: String in ["CultIndex", "RelicIndex", "WorldArchive", "People", "Attention", "Budget", "Self", "History", "Menu"]:
		var transfers_before: int = player.transfers
		await measure(id + "/cold", press.bind(id))
		if id == "RelicIndex": await shoot(sample + "-relics")
		close()
		await measure(id + "/reopen", press.bind(id))
		need(player.transfers == transfers_before, id + " does not query material transfers")
		close()
	for collection: String in ["domains", "people", "institutions", "cults", "relics", "anchors"]:
		if app.projection.get(collection, []).is_empty(): continue
		var id: String = app.projection[collection][0].id
		var kind: String = {"domains":"world", "people":"person", "institutions":"institution", "cults":"cult", "relics":"relic", "anchors":"anchor"}[collection]
		await measure("detail/" + kind, app._tasks.open_subject.bind(kind, id))
		await measure("back/" + kind, app._tasks.back)
		close()
	for kind: String in ["materials", "anchors", "institutions"]:
		await measure("list/" + kind, app._tasks.open_subject.bind(kind))
		close()
	for prefix: String in ["relic/", "attention/", "prayer/"]:
		for entry: Dictionary in player.action_entries(prefix):
			await measure("action/" + entry.key, app._tasks.open_action.bind(entry.key))
			close()
	var opportunities: Array = player.action_entries("opportunity/")
	for i: int in mini(3, opportunities.size()):
		await measure("action/" + opportunities[i].key, app._tasks.open_action.bind(opportunities[i].key))
		close()
	await measure("action/route/context", app._tasks.open_action.bind("route/context"))
	close()
	if not player.world.state.power_system.manifest.is_empty():
		for key: String in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]:
			await measure(key, app._tasks.open_action.bind(key))
			await measure(key + "/confirm", press.bind("ExecuteDraft"))
			need(app._dialog == "task_confirm", "irreversible confirmation " + key)
			await measure(key + "/cancel", press.bind("CancelAction"))
			need(app._dialog == "task_action", "cancel returns to draft " + key)
			close()
	need(player.global_queries == 0, sample + " no whole-catalog UI queries")
	need(player.turn.snapshot() == before and player.knowledge_snapshot() == knowledge, sample + " navigation/preview/cancel preserves full state, RNG, receipts and knowledge")
	player.watch = false
	game.free()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	evidence = args[0] if not args.is_empty() else "/tmp/ui-latency-review"
	DirAccess.make_dir_recursive_absolute(evidence)
	var player := WatchedSession.new(evidence.path_join("new-game"))
	need(player.start_new(1).get("ok", false), "start ordinary new game")
	await sweep(player, "new-game")
	player = WatchedSession.new(evidence.path_join("nine-anchor"))
	need(player.continue_game("res://docs/qa/ui-manifest/saves/ongoing.json").get("ok", false), "load ordinary current nine-anchor save")
	player.slot = evidence.path_join("working.json")
	await sweep(player, "nine-anchor")
	var file := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"fail" if failed else "pass", "engine":Engine.get_version_info().string, "display":DisplayServer.get_name(), "source_save":"docs/qa/ui-manifest/saves/ongoing.json", "source_sha256":FileAccess.get_sha256("res://docs/qa/ui-manifest/saves/ongoing.json"), "timings":rows, "checks":checks}, "\t", true, true) + "\n")
	file.close()
	quit(1 if failed else 0)
