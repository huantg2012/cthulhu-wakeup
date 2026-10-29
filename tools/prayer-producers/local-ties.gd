extends "res://tools/prayer-producers/run.gd"
## Four focused cases; reuse the existing Turn fixture helpers, never their matrix.
const Sources = preload("res://src/game/prayer_sources.gd")
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files():
		_check("SLT-CATALOG", "Formal CSV load", false, {"errors": catalog.errors})
	else:
		_case(false)
		_case(true)
		_capacity()
	Support.write_report(records, "lightweight_rescue_scene_core", [], ["Controlled RNG inputs; no target situation/result injection.", "Turn/World component save only; full Session and cult compatibility remain separate.", "Other prayer source families, natural campaign probability and balance are outside this check."])
	quit(0 if records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _local_ties_setup(full: bool = false) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, 7919)
	# Explicit initial random input. Probe only this tiny RNG, never whole worlds.
	# Source options are ordered with rescue last among the three/four roots.
	var controlled: int = 0
	for seed_value: int in range(1, 65):
		var a: RandomNumberGenerator = RandomNumberGenerator.new(); a.seed = seed_value
		var first: int = a.randi_range(1, 100)
		var saved: int = a.state
		var third: int = a.randi_range(1, 3)
		a.state = saved
		var fourth: int = a.randi_range(1, 4)
		if first <= catalog.integer("ambient_event_chance") and third == 3 and fourth == 4:
			a.seed = seed_value; controlled = a.state; break
	assert(controlled != 0)
	world.state.simulation.cursors["DOMAIN-001"].state = str(controlled)
	world.state.simulation.cursors["DOMAIN-001"].next_turn = 1
	var data: Dictionary = {"world": world, "source": world.state.domains["DOMAIN-001"].origin}
	var supplied: Array = []
	if full:
		while supplied.size() < catalog.integer("prayer_offer_limit"): supplied.append(_foreign_record_fixture(data))
	_attach_dispatch(data)
	for source: String in supplied: assert(world.fix_prayer_source(source, data.turn))
	data["supplied"] = supplied
	assert(_boot(data).ok)
	return data

func _scene(data: Dictionary) -> Dictionary:
	if not _open(data) or not _evolve(data): return {}
	for entry: Dictionary in data.world.state.prayer_sources.open.values():
		if entry.domain == "DOMAIN-001": return entry.duplicate(true)
	return {}

func _case(rescue: bool) -> void:
	var data: Dictionary = _local_ties_setup()
	var entry: Dictionary = _scene(data)
	var valid: bool = not entry.is_empty()
	var details: Dictionary = {"entry": entry, "tick": Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last["DOMAIN-001"], {})}
	if valid:
		var root: Dictionary = Store.entry(data.world.state.facts, entry.root)
		valid = root.changes.rule == "kinship_rescue_scene" and root.changes.due == entry.due and data.world.relation_between(entry.petitioner, entry.patient, ["family"]).is_empty()
		valid = valid and _finish(data) and _open(data)
		var request: String = ""
		for id: String in data.world.state.prayer_system.offered:
			if data.world.state.prayer_system.requests[id].descriptor.facts.get("condition") == entry.root: request = id
		valid = valid and not request.is_empty()
		var saved: String = data.turn.snapshot()
		var restored: bool = data.turn.restore(saved)
		valid = valid and restored and data.turn.snapshot() == saved and data.world.state.prayer_sources.open.get(entry.root) == entry
		details["restoredFixedState"] = restored
		if rescue and valid:
			_choose_prayer_seed(data, "success", entry.petitioner, entry.domain)
			var response: Dictionary = _response(data, request, "shallow")
			details["response"] = response
			valid = valid and response.ok and Store.has(data.world.state.invalid_records, entry.root) and not data.world.state.prayer_sources.open.has(entry.root)
		while valid and int(data.world.state.turn) <= int(entry.due):
			valid = _evolve(data) and _finish(data)
			if int(data.world.state.turn) <= int(entry.due): valid = valid and _open(data)
		var patient: Dictionary = Store.entry(data.world.state.npcs, entry.patient)
		var deaths: Array = _facts(data.world, "status_change").filter(func(fact: Dictionary) -> bool: return fact.actor == entry.patient and fact.changes.get("to") == "dead")
		valid = valid and (patient.status == "active" and deaths.is_empty() if rescue else patient.status == "dead" and deaths.size() == 1)
		var closed: Array = _facts(data.world, "rescue_scene_closed").filter(func(fact: Dictionary) -> bool: return fact.changes.root == entry.root)
		valid = valid and closed.size() == 1
		details.merge({"patientStatus": patient.status, "deathCount": deaths.size(), "closeCount": closed.size(), "finalTurn": data.world.state.turn})
	_check("SLT-RESCUE" if rescue else "SLT-EXPIRY", "Formal scene, next-turn response window, stable save and one actual cure/death", valid, details)

func _capacity() -> void:
	var data: Dictionary = _local_ties_setup(true)
	var supplied: Array = data.supplied
	var entry: Dictionary = _scene(data)
	var tick: Dictionary = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last["DOMAIN-001"], {})
	var roots: Array = _facts(data.world, "dying_condition").filter(func(fact: Dictionary) -> bool: return fact.changes.get("rule") == "kinship_rescue_scene")
	_check("SLT-CAPACITY", "Offer capacity prevents new hidden fatal scene", entry.is_empty() and roots.is_empty() and tick.get("changes", {}).get("new_outcome") == "capacity_blocked", {"tick": tick, "newFatalScenes": roots.size(), "prerequisiteKnowledgeSources": supplied})
