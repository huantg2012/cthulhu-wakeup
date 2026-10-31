extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const World = preload("res://src/simulation/world.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
var rows: Array = []
var error: String = ""
var folder: String

func need(ok: bool, why: String) -> bool:
	if not ok and error.is_empty(): error = why
	return ok

func positive_seed(s: RefCounted) -> void:
	for value: int in range(1, 10001):
		var rng := RandomNumberGenerator.new(); rng.seed = value
		if rng.randi_range(1, 100) == 1:
			s.world.randoms.checks.seed = value; return

func next_window(s: RefCounted) -> bool:
	if not need(s.progress(true).get("ok", false), "Cannot end original action window"): return false
	for unused: int in 6:
		if s.turn.context.phase == "actions": return true
		var result: Dictionary = s.progress()
		if not need(result.get("ok", false), "Original next-window progression rejected: " + str(result)): return false
	return need(s.turn.context.phase == "actions", "Next original window not reached")

func complete_state(s: RefCounted) -> String:
	return World.canonical({"turn": s.turn.snapshot(), "campaign": s._campaign, "sequence": s._request_sequence, "inputs": s._action_inputs, "knowledge": s.knowledge_snapshot(), "cursor": s._knowledge_cursor, "slot": s.slot, "known": [s.known_domains(), s.known_people(), s.known_sources()]})

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(World.canonical(History.export_value(value))); file.close()

func rejected(s: RefCounted, path: String, body: Dictionary, original: String, label: String) -> bool:
	write_json(path, {"body": body, "checksum": World.canonical(body).sha256_text()})
	var before: String = complete_state(s)
	var original_bytes: String = FileAccess.get_file_as_string(original)
	var candidate: String = FileAccess.get_file_as_string(path)
	var latest_exists: bool = FileAccess.file_exists(s.latest_path)
	var latest: String = FileAccess.get_file_as_string(s.latest_path) if latest_exists else ""
	var result: Dictionary = s.continue_game(path)
	var latest_after_exists: bool = FileAccess.file_exists(s.latest_path)
	var latest_after: String = FileAccess.get_file_as_string(s.latest_path) if latest_after_exists else ""
	var valid: bool = not result.get("ok", false) and before == complete_state(s) and original_bytes == FileAccess.get_file_as_string(original) and candidate == FileAccess.get_file_as_string(path) and latest_exists == latest_after_exists and latest == latest_after
	rows.append({"id": label, "status": "pass" if valid else "fail", "result": result, "checksumCorrect": JSON.parse_string(candidate).checksum == World.canonical(body).sha256_text(), "currentAndFilesProtected": valid, "candidateSha256": candidate.sha256_text(), "originalSha256": original_bytes.sha256_text()})
	return need(valid, "Rejected save mutated session/files: " + label)

func run() -> bool:
	var s := Session.new(folder.path_join("campaigns"))
	if not need(s.start_new(1).get("ok", false) and s.progress().get("ok", false), "Formal Session startup failed"): return false
	var bootstrap: String = ""
	for id: String in s.world.state.prayer_system.offered:
		if s.world.state.prayer_system.requests[id].card.content_id == "PRAYER_08": bootstrap = id; break
	if not need(not bootstrap.is_empty() and next_window(s), "Bootstrap or original waiting round missing"): return false
	var request: Dictionary = s.world.state.prayer_system.requests.get(bootstrap, {})
	if not need(not request.is_empty() and bootstrap in s.world.state.prayer_system.offered and s.turn.context.turn <= request.card.due_turn, "Original bootstrap expired before planned response"): return false
	var actor: String = request.descriptor.subjects.petitioner
	positive_seed(s)
	if not need(s.execute_action("prayer/" + bootstrap + "/shallow", {}, true, "CSC-DEVOTION").get("ok", false) and next_window(s), "Original devotion/next window failed"): return false
	var selection: Dictionary = {"domain": Store.entry(s.world.state.npcs, actor).domain, "npc": actor}
	var preview: Dictionary = s.preview_action("POWER_DREAM", selection)
	if not need(preview.get("ok", false), "Original dream unavailable: " + str(preview)): return false
	positive_seed(s)
	var action: Dictionary = s.execute_action("POWER_DREAM", selection, true, "CSC-DREAM")
	if not need(action.get("ok", false), "Original material-producing dream rejected"): return false
	var material: Dictionary = {}
	for fact: Dictionary in Store.values(s.world.state.facts):
		if fact.kind == "miracle" and fact.actor == actor: material = fact
	var person: Dictionary = Store.entry(s.world.state.npcs, actor)
	var held: bool = not material.is_empty() and History.has(person.known_facts, material.id)
	if not need(held and History.size(s.world.state.social_graph.edge_heads) > 0 and not s.world.state.opportunities.goals.is_empty() and not s.world.state.prayer_system.requests.is_empty(), "Nonempty material/relationships/opportunities/requests required"): return false
	var saved: Dictionary = s.save_game()
	if not need(saved.get("ok", false), "Original Session save rejected"): return false
	var path: String = saved.path
	var before: String = complete_state(s)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var restored := Session.new(folder.path_join("receiver"))
	var loaded: Dictionary = restored.continue_game(path)
	if not need(loaded.get("ok", false) and before == complete_state(restored), "Complete Session restoration differs: " + str(loaded)): return false
	var replay_before: String = complete_state(restored)
	var replay: Dictionary = restored.execute_action("POWER_DREAM", selection, true, "CSC-DREAM")
	if not need(replay.get("ok", false) and complete_state(restored) == replay_before, "Durable action replay charged or changed state"): return false
	rows.append({"id": "CSC-CURRENT", "status": "pass", "loaded": loaded, "material": material, "actualCarrier": actor, "carrierKnowsMaterial": held, "relationshipHeads": s.world.state.social_graph.edge_heads, "fixedRequests": s.world.state.prayer_system.requests, "opportunities": s.world.state.opportunities, "fullEnvelopeFields": envelope.body.keys(), "exactSessionState": true, "durableReplayUnchanged": true, "savedSha256": FileAccess.get_file_as_string(path).sha256_text()})
	var old: Dictionary = World._normalize_numbers(envelope.body.duplicate(true)); old.schema = Session.SAVE_SCHEMA - 1
	if not rejected(restored, folder.path_join("old.json"), old, path, "CSC-OLD"): return false
	var broken: Dictionary = World._normalize_numbers(envelope.body.duplicate(true)); broken.knowledge.facts.append("FACT-99999999")
	if not rejected(restored, folder.path_join("broken.json"), broken, path, "CSC-BROKEN"): return false
	var cached: Dictionary = World._normalize_numbers(envelope.body.duplicate(true)); cached.action_inputs["CSC-DREAM"].response.result.outcome = "awakened"
	if not rejected(restored, folder.path_join("cached.json"), cached, path, "CSC-CACHED-RESULT"): return false
	if not need(next_window(restored), "Restored Session cannot actually continue"): return false
	rows.append({"id": "CSC-CONTINUE", "status": "pass", "turn": restored.turn.context.turn, "phase": restored.turn.context.phase, "requestSequence": restored._request_sequence, "commitSequence": restored.turn.commit_sequence})
	return true

func _initialize() -> void:
	var output: String = OS.get_cmdline_user_args()[0]; folder = output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var started: int = Time.get_ticks_msec()
	var valid: bool = run()
	write_json(output, {"status": "pass" if valid else "fail", "error": error, "seconds": float(Time.get_ticks_msec() - started) / 1000.0, "checks": rows, "scope": "One real Session current save/restore/replay/continuation, one signed old schema and one signed missing knowledge reference. Actual dream RNG controlled; no mature fixture or snapshot mutation."})
	quit(0 if valid else 1)
