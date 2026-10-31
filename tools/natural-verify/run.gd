extends SceneTree
## One retained M1 trajectory; at most three additional action windows.
const Session = preload("res://src/presentation/session.gd")
const World = preload("res://src/simulation/world.gd")
const History = preload("res://src/simulation/history_index.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const TARGET = "BACKGROUND-00000008"
var error: String = ""
var rows: Array = []
var folder: String
var replay_status: String = "not_executed_no_legal_action"

func need(ok: bool, why: String) -> bool:
	if not ok and error.is_empty(): error = why
	return ok

func complete(s: RefCounted) -> String:
	return World.canonical(History.export_value({"snapshot": s.turn.snapshot(), "campaign": s._campaign, "sequence": s._request_sequence, "inputs": s._action_inputs, "knowledge": s.knowledge_snapshot(), "cursor": s._knowledge_cursor, "known": [s.known_domains(), s.known_people(), s.known_sources()]}))

func observation(s: RefCounted) -> Dictionary:
	var requests: Dictionary = s.world.state.prayer_system.requests
	return {"turn": s.turn.context.turn, "phase": s.turn.context.phase, "faith": s.world.state.faith, "whispers": s.world.state.whispers, "offered": s.world.state.prayer_system.offered.duplicate(), "target": requests.get(TARGET, {}).duplicate(true), "targetRemembered": s.prayer_entry(TARGET).duplicate(true), "targetOffered": TARGET in s.world.state.prayer_system.offered, "opportunities": s.world.state.opportunities.duplicate(true)}

func advance(s: RefCounted) -> bool:
	for unused: int in 7:
		if s.turn.context.phase in ["actions", "ended"]: return true
		if not need(s.progress().get("ok", false), "Original phase progression rejected"): return false
	return need(false, "Bounded phase progression did not reach actions")

func save_replay(s: RefCounted, key: String, id: String) -> bool:
	var saved: Dictionary = s.save_game(folder.path_join("continued.json"))
	if not need(saved.get("ok", false), "Real Session save failed: " + str(saved)): return false
	var restored := Session.new(folder.path_join("receiver"))
	var loaded: Dictionary = restored.continue_game(saved.path)
	if not need(loaded.get("ok", false) and complete(s) == complete(restored), "Complete Session continuation differs: " + str(loaded)): return false
	var before: String = complete(restored)
	var replay: Dictionary = restored.execute_action(key, {}, true, id)
	if not need(replay.get("ok", false) and before == complete(restored), "Durable replay changed complete state or charged resources"): return false
	var first: Dictionary = s.progress(true)
	var second: Dictionary = restored.progress(true)
	if not need(first.get("ok", false) and second.get("ok", false) and World.canonical(first) == World.canonical(second) and complete(s) == complete(restored), "Same next progress differs after restoration"): return false
	replay_status = "pass"
	rows.append({"id": "NATURAL-CURRENT-SAVE", "status": "pass", "loaded": loaded, "savedSha256": FileAccess.get_file_as_string(saved.path).sha256_text(), "durableId": id, "replay": replay, "nextProgress": first, "completeStateEqual": true, "slotExcludedFromSimulationComparison": true})
	return true

func run(input: String) -> bool:
	var s := Session.new(folder.path_join("working"))
	var loaded: Dictionary = s.continue_game(input)
	if not need(loaded.get("ok", false), "Retained current-M1 formal Session rejected: " + str(loaded)): return false
	rows.append({"id": "NATURAL-RETAINED-INPUT", "status": "pass", "savedState": observation(s)})
	if not need(s.turn.context.turn == 8 and s.turn.context.phase == "between", "Expected retained T8/between automatic save"): return false
	if not advance(s): return false
	if not need(s.turn.context.turn == 9 and s.turn.context.phase == "actions", "Original continuation did not reach T9/actions"): return false
	rows.append({"id": "NATURAL-T9-OBSERVATION", "status": "pass", "state": observation(s)})
	for window: int in 3:
		if s.turn.context.phase == "ended": break
		var entry: Dictionary = {"id": "NATURAL-WINDOW/" + str(window + 1), "before": observation(s), "previews": [], "action": {}}
		var chosen: String = ""
		for action: Dictionary in s.action_catalog():
			var key: String = action.key
			if not key.begins_with("prayer/") or not key.ends_with("/shallow"): continue
			var preview: Dictionary = s.preview_action(key, {})
			entry.previews.append({"key": key, "preview": preview})
			if preview.get("ok", false): chosen = key; break
		var progressed: bool = false
		if not chosen.is_empty():
			var durable: String = "NATURAL-CLEAR/" + str(window + 1)
			var response: Dictionary = s.execute_action(chosen, {}, true, durable)
			entry.action = {"key": chosen, "durableId": durable, "response": response, "after": observation(s)}
			rows.append(entry)
			if not need(response.get("ok", false), "Legal public response rejected: " + str(response)): return false
			if replay_status != "pass":
				if not save_replay(s, chosen, durable): return false
				progressed = true
		else: rows.append(entry)
		if not progressed and not need(s.progress(true).get("ok", false), "Original end_actions rejected"): return false
		if not advance(s): return false
	rows.append({"id": "NATURAL-FINAL", "status": "observed", "state": observation(s), "sampleStatus": "bounded_continuation_censored", "saveReplay": replay_status})
	return need(s.save_game(folder.path_join("final.json")).get("ok", false), "Final real Session save failed")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0]; folder = output.get_base_dir()
	var valid: bool = run(args[1])
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(World.canonical(History.export_value({"status": "pass" if valid else "fail", "error": error, "checks": rows, "saveReplay": replay_status, "scope": "One retained M1 seed-1 continuation, T9-T11 at most three actions windows, one oldest affordable shallow prayer per window. Original RNG and default events; no injected resources, qualifications or target outcomes. Task remains partial; no natural anchor/ending claim."}))); file.close()
	quit(0 if valid else 1)
