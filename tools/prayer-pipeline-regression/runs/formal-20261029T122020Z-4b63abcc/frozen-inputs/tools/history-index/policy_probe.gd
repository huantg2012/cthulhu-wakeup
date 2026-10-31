extends SceneTree
## Runs only in the wrapper's disposable project. Never edits the real CSV.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")

class Adapter extends RefCounted:
	func handle(_view: Dictionary, input: Dictionary) -> Dictionary:
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
		if input.slot == "events" and input.operation == "gather":
			result.events = []
		return result

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	assert(FileAccess.file_exists("res://history-policy-scratch-only"))
	var catalog: RefCounted = Catalog.new()
	assert(catalog.load_files())
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	var turn: RefCounted = Turn.new(world)
	var adapter: RefCounted = Adapter.new()
	assert(turn.register_participant("policy-fixture", "1", Turn.SLOTS, [], adapter.handle))
	var older: String = turn.snapshot()
	assert(turn.submit({"id": "POLICY-1", "op": "advance", "turn": 0, "phase": "between"}).ok)
	assert(turn.submit({"id": "POLICY-2", "op": "finish_events", "turn": 1, "phase": "events"}).ok)
	var before: String = turn.snapshot()
	var state: Dictionary = world.state
	var context: Dictionary = turn.context
	var randoms: Dictionary = world.randoms
	var history: RefCounted = world.history
	var index_data: Dictionary = history.data
	var index_version: int = history.version
	var standalone: RefCounted = World.new(catalog)
	assert(standalone.generate(7919) and standalone.ensure_history())
	var standalone_before: String = standalone.snapshot()
	var standalone_index: RefCounted = standalone.history
	var original: String = FileAccess.get_file_as_string("res://data/fidelity_parameters.csv")
	var lines: PackedStringArray = original.split("\n")
	for i: int in lines.size():
		if lines[i].begins_with("decision_query_page_limit,"):
			var cells: PackedStringArray = lines[i].split(",")
			cells[1] = "0"
			lines[i] = ",".join(cells)
	var file: FileAccess = FileAccess.open("res://data/fidelity_parameters.csv", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	var accepted: bool = turn.restore(older)
	var error: String = turn.last_error
	var unchanged: bool = turn.snapshot() == before and is_same(state, world.state) and is_same(context, turn.context) and is_same(randoms, world.randoms) and is_same(history, world.history) and is_same(index_data, history.data) and history.version == index_version
	var ensure_rejected: bool = not standalone.ensure_history(true) and standalone.snapshot() == standalone_before and is_same(standalone_index, standalone.history)
	var generate_rejected: bool = not standalone.generate(1981) and standalone.snapshot() == standalone_before and is_same(standalone_index, standalone.history)
	file = FileAccess.open("res://data/fidelity_parameters.csv", FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var valid_restore: bool = turn.restore(older)
	var ok: bool = not accepted and unchanged and ensure_rejected and generate_rejected and valid_restore
	var report: Dictionary = {"status": "pass" if ok else "fail", "restoreRejected": not accepted, "allSessionRootsAndRandomsPreserved": unchanged, "ensureRejectedWithoutPublish": ensure_rejected, "generateRejectedWithoutPublish": generate_rejected, "originalSnapshotValidAfterPolicyRepair": valid_restore, "restoreError": error}
	file = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()
	print("POLICY_PROBE ", report)
	quit(0 if ok else 1)
