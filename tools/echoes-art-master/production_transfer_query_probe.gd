extends "res://tools/anchor-production-closure/run.gd"
## One existing testimony fixture: positive/hidden/stale candidates and real transfer.
const PlayerSession = preload("res://src/presentation/session.gd")
const Production = preload("res://src/presentation/production/game_root.tscn")
var checks: Array = []
var failed := false
func _initialize() -> void:
	run_query.call_deferred()
func need(ok: bool, label: String) -> void:
	checks.append({"check":label, "pass":ok})
	if not ok: failed = true; push_error(label)
func run_query() -> void:
	var data: Dictionary = _fixture("record_testimonies")
	need(not data.has("fixtureFailure"), "existing two-member testimony prerequisites")
	data.timingStart = Time.get_ticks_msec(); data.timingPrevious = data.timingStart; data.timings = []
	var first: String = _dream(data, data.guardian)
	need(not first.is_empty() and first != "missing_actual_dream" and _next(data), "first actual testimony and next turn")
	var second: String = _dream(data, data.other)
	need(not second.is_empty() and second != "missing_actual_dream" and _next(data), "second actual testimony and next turn")
	var player := PlayerSession.new("/tmp/ui-transfer-query/%s" % Time.get_ticks_usec())
	player.world = data.world; player.turn = data.turn; player.catalog = catalog
	for key: String in ["economy", "cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources"]: player.modules[key] = data[key]
	player.modules.progression_routes = data.routes
	player._refresh_knowledge(false)
	var before: String = data.turn.snapshot()
	var started := Time.get_ticks_usec()
	var candidates: Array = player.material_transfer_options()
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	need(not candidates.is_empty(), "actual testimony offers a legal transfer candidate")
	if candidates.is_empty(): quit(1); return
	var request: Dictionary = candidates[0]
	need(request.source in [first, second] and request.sender != request.recipient and request.grant == "custody", "candidate refers to a produced testimony and distinct original endpoints")
	need(ms < 250.0, "positive transfer candidates <250ms")
	var args := OS.get_cmdline_user_args()
	# Optional comparison with an unmodified selector from the reported revision.
	if args.size() > 1:
		var original = load(args[1])
		var view: Dictionary = data.turn._read_view("economy", data.turn.context.phase)
		var old: Array = original.transfer_options(original.context(view, player.knowledge_snapshot(), player.modules))
		view.reader.close()
		need(JSON.stringify(candidates, "", true, true) == JSON.stringify(old, "", true, true), "all positive candidates equal previous implementation")
	var ledger: Dictionary = player.knowledge_snapshot()
	var view: Dictionary = data.turn._read_view("economy", data.turn.context.phase)
	ledger.known_people.erase(data.other)
	var private_options: Array = PlayerSession.EntrySelectors.transfer_options(PlayerSession.EntrySelectors.context(view, ledger, player.modules))
	view.reader.close()
	need(not private_options.any(func(item: Dictionary) -> bool: return item.sender == data.other or item.recipient == data.other), "hidden participant excluded")
	need(before == data.turn.snapshot(), "candidate reads leave state/knowledge/RNG unchanged")
	var entry: Dictionary = player.action_entry("cults/transfer_material", request)
	need(entry.get("preview", {}).get("ok", false), "targeted UI row uses actual transfer eligibility")
	var local: Dictionary = request.duplicate(true)
	local.domain = data.domain
	var scoped: Dictionary = player.entry_eligibility("cults/transfer_material", local)
	need(scoped.get("ok", false) and scoped.fields.payload == request, "world scope is validated and does not change the formal command")
	var job: RefCounted = player.action_candidate("cults/transfer_material", {"domain":data.domain})
	while not job.step(): await process_frame
	need(job.result.get("ok", false), "world entry offers a complete legal transfer")
	var unknown: Dictionary = local.duplicate(true); unknown.domain = "unknown-world"
	need(not player.preview_action("cults/transfer_material", unknown).get("ok", false), "unknown browsing scope rejected")
	var game := Production.instantiate()
	var app: Control = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = player; root.add_child(game); app._close_surface()
	var entrance: Button = app.find_child("MaterialTransfer", true, false)
	need(entrance != null, "material transfer has a direct world entrance")
	entrance.pressed.emit()
	need(app._tasks.draft.selection.get("domain") == app._world_id, "world entrance preserves its actual scope")
	app._tasks.open_action("cults/transfer_material", local)
	var execute: Button = app.find_child("ExecuteDraft", true, false)
	need(execute != null and not execute.disabled, "actual transfer is executable in the production workbench")
	execute.pressed.emit()
	need(app._dialog == "receipt", "actual transfer accepted and paid through production UI")
	need(not player.material_transfer_options().has(request), "already-held candidate removed immediately after receipt")
	need(not player.preview_action("cults/transfer_material", request).get("ok", false), "old selection revalidated and rejected after transfer")
	var output: String = args[0] if not args.is_empty() else "/tmp/ui-transfer-query-results.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"fail" if failed else "pass", "candidate_ms":ms, "candidate_count":candidates.size(), "checks":checks, "scope":"Existing controlled two-member record_testimonies fixture, actual two dream materials and paid transfer; not a natural campaign or full Session save."}, "\t", true, true) + "\n")
	file.close()
	print("TRANSFER_QUERY ", "FAIL" if failed else "OK", " ", ms, "ms ", candidates.size(), " candidates")
	quit(1 if failed else 0)
