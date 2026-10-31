extends "res://tools/prayer-producers/source-memory.gd"
const ExceptionAnchors = preload("res://src/game/anchors.gd")
func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files(): _check("SE-CATALOG", "Formal CSV load", false, {"errors": catalog.errors})
	else:
		_case(false); _case(true); _capacity()
		for content: String in ["PRAYER_02", "PRAYER_10", "PRAYER_03", "PRAYER_11"]: _conflict_case(content)
		for mode: String in ["shallow", "deep", "expiry"]: _memory_case(mode)
		_exception_first(); _exception_independence(); _exception_capacity()
	Support.write_report(records, "current_anomaly_sources_and_core_regression", [], ["Controlled initial RNG/check inputs and explicit non-target setup. Actual observations/calls/results are produced through Turn.", "The independence case explicitly names three lawful initial node representatives and a public exposure; other cases start with no cosmic F or named observer. Non-target domains have controlled initial RNG misses for this bounded window.", "No full Session, finite-wait guarantee, complete CIV07 anchor route or natural campaign balance acceptance."])
	quit(0 if records.size() == 13 and records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _exception_setup(deep_fixture: bool = false, capacity: bool = false) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, 7919)
	var domain: String = ""
	for id: String in world.state.domains:
		if world.state.domains[id].profile == "CIV_07": domain = id; break
	assert(not domain.is_empty())
	var data: Dictionary = {"world": world, "source": world.state.domains["DOMAIN-001"].origin, "domain": domain}
	if deep_fixture:
		# Legal named prerequisites, not source outputs or a focus reservation.
		var profiles: Array = catalog.tables.npc_profiles.keys(); profiles.sort()
		for node: String in world.state.domains[domain].institutions:
			for profile: String in profiles:
				if world._profile_legal(catalog.tables.npc_profiles[profile], domain, node):
					assert(world._nominate_local(domain, node, profile, world.state.domains[domain].origin)); break
		var people: Array = world.history.ids("active/" + domain)
		assert(people.size() == 3)
		var subject: String = people.filter(func(id: String) -> bool: return Store.entry(world.state.npcs, id).institution != domain + "/order")[0]
		var clue: String = world.introduce_fact("exposure", domain, subject, [subject], [world.state.domains[domain].origin], {"public": true, "fixture": "existing exposure keeps source classes stable"}, [], [domain + "/order"])
		assert(not clue.is_empty())
	# Only initial RNG inputs are controlled: no output or probability changes.
	for other: String in world.state.domains:
		if other == domain: continue
		for seed_value: int in range(1, 8193):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
			var misses: bool = true
			for opportunity: int in 4:
				if rng.randi_range(1, 100) <= catalog.integer("ambient_event_chance"): misses = false; break
			if misses:
				rng.seed = seed_value; world.state.simulation.cursors[other].state = str(rng.state); break
	var supplied: Array = []
	if capacity:
		for index: int in catalog.integer("prayer_offer_limit"): supplied.append(_foreign_record_fixture(data))
	_exception_random_input(world, domain)
	_attach_dispatch(data)
	for source: String in supplied: assert(world.fix_prayer_source(source, data.turn))
	assert(_boot(data).ok)
	return data

func _exception_random_input(world: RefCounted, domain: String) -> void:
	world.state.simulation.cursors[domain].next_turn = 1
	var view: Dictionary = world._evolution_snapshot().duplicate(false)
	view[Sources.ID] = {"open": {}, "cooldowns": {}, "situations": {}, "claims": {}, "anomalies": {}, "observations": {}}
	view["prayer_knowledge"] = {"seed": str(world.randoms.generation.seed)}
	view["prayer_system"] = {"requests": {}, "crises": {}}; view["turn"] = 1
	var options: Array = Producers.prepare_options(world, view, domain, {})
	options.append_array(Sources.options(world, view, domain, {}))
	var target: int = -1
	for index: int in options.size():
		if options[index].root == "ROOT_COSMIC_OBSERVATION": target = index + 1
	assert(target > 0)
	var found: bool = false
	# This is a few integer RNG operations, never a search through simulated worlds.
	for seed_value: int in range(1, 8193):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randi_range(1, 100) > catalog.integer("ambient_event_chance") or rng.randi_range(1, options.size()) != target: continue
		if rng.randi_range(1, 100) > catalog.integer("ambient_event_chance") or rng.randi_range(1, options.size()) != target: continue
		rng.seed = seed_value; world.state.simulation.cursors[domain].state = str(rng.state); found = true; break
	assert(found)

func _exception_entry(data: Dictionary) -> Dictionary:
	for entry: Dictionary in data.world.state.prayer_sources.situations.values():
		if entry.domain == data.domain and entry.content == "PRAYER_12": return entry.duplicate(true)
	return {}

func _exception_request(data: Dictionary, entry: Dictionary) -> String:
	for id: String in data.world.state.prayer_system.offered:
		if data.world.state.prayer_system.requests[id].descriptor.source == entry.source: return id
	return ""

func _exception_first() -> void:
	var data: Dictionary = _exception_setup()
	var before: int = data.world.history.ids("active/" + data.domain).size()
	var valid: bool = before == 0 and not data.domain in data.world.state.simulation.focused and _open(data) and _evolve(data)
	var entry: Dictionary = _exception_entry(data)
	valid = valid and not entry.is_empty()
	var details: Dictionary = {"entry": entry, "beforeNamed": before}
	if valid:
		var anomaly: String = data.world.state.prayer_sources.anomalies[data.domain]
		var observation: Dictionary = Store.entry(data.world.state.facts, entry.root)
		valid = not data.domain in data.world.state.simulation.focused and observation.changes.exception == anomaly and data.world.history.ids("active/" + data.domain).size() == 1
		var saved: String = data.turn.snapshot()
		valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved
		valid = valid and _finish(data) and _open(data)
		var request: String = _exception_request(data, entry)
		valid = valid and not request.is_empty()
		if valid:
			_choose_prayer_seed(data, "success", entry.petitioner, data.domain)
			var response: Dictionary = _response(data, request, "shallow")
			var records_here: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") == "exception_record")
			valid = response.ok and records_here.size() == 1 and not ExceptionAnchors.exception_observation(data.world.state, records_here[0].id, data.world.history).is_empty()
			details.merge({"response": response, "anomaly": anomaly, "observation": observation, "materialCount": records_here.size(), "noFocusForProduction": not data.domain in data.world.state.simulation.focused})
	_check("SE-FIRST", "Unfocused unnamed cosmic domain produces a real observer and PR12 response", valid, details)

func _exception_independence() -> void:
	var data: Dictionary = _exception_setup(true)
	var valid: bool = _open(data) and _evolve(data)
	var first: Dictionary = _exception_entry(data)
	valid = valid and not first.is_empty() and _finish(data) and _open(data)
	var details: Dictionary = {"first": first}
	if valid:
		var request: String = _exception_request(data, first)
		_choose_prayer_seed(data, "success", first.petitioner, data.domain)
		var response: Dictionary = _response(data, request, "deep")
		var transferred: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") in ["exception_learned", "public_exception_qualification"])
		valid = response.ok and transferred.size() == 2 and not ExceptionAnchors.independent_exception_records(data.world.state, transferred[0].id, transferred[1].id, data.world.history)
		while valid and int(data.world.state.turn) < 5:
			valid = _evolve(data) and _finish(data) and _open(data)
		if valid: valid = _evolve(data)
		var second: Dictionary = _exception_entry(data)
		valid = valid and not second.is_empty() and second.root != first.root and second.petitioner != first.petitioner
		if valid:
			var one: Dictionary = Store.entry(data.world.state.facts, first.root)
			var two: Dictionary = Store.entry(data.world.state.facts, second.root)
			valid = one.changes.exception == two.changes.exception and one.changes.node != two.changes.node and _finish(data) and _open(data)
			var second_request: String = _exception_request(data, second)
			_choose_prayer_seed(data, "success", second.petitioner, data.domain)
			var actual: Dictionary = _response(data, second_request, "shallow")
			var material: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == second_request and fact.changes.get("tag") == "exception_record")
			valid = valid and actual.ok and material.size() == 1 and ExceptionAnchors.independent_exception_records(data.world.state, transferred[0].id, material[0].id, data.world.history)
			details.merge({"second": second, "deepTransfer": response, "secondResponse": actual, "sameAnomaly": one.changes.exception == two.changes.exception, "copyNotIndependent": true, "secondIndependent": valid})
	_check("SE-INDEPENDENCE", "Deep transfer is one observation; a later different node produces an independent one", valid, details)

func _exception_capacity() -> void:
	var data: Dictionary = _exception_setup(false, true)
	var valid: bool = _open(data) and _evolve(data)
	var tick: Dictionary = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last[data.domain])
	valid = valid and tick.changes.get("choice", {}).get("root") == "ROOT_COSMIC_OBSERVATION" and tick.changes.get("new_outcome") == "capacity_blocked" and data.world.history.ids("active/" + data.domain).is_empty() and not data.world.state.prayer_sources.anomalies.has(data.domain)
	var details: Dictionary = {"blockedTick": tick, "zeroObserverAndAnomaly": valid}
	var later: Dictionary = {}
	while valid and int(data.world.state.turn) <= 5:
		if later.is_empty(): later = _exception_entry(data)
		valid = _finish(data)
		if int(data.world.state.turn) > 5: break
		valid = valid and _open(data) and _evolve(data)
	valid = valid and not later.is_empty() and data.world.history.ids("active/" + data.domain).size() == 1
	details["laterEntry"] = later
	details["laterTick"] = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last[data.domain])
	# Same check also exercises an actual unanswered request, not only a pool
	# release: its scene expires and a later opportunity keeps the anomaly ID.
	var unanswered: Dictionary = _exception_setup()
	valid = valid and _open(unanswered) and _evolve(unanswered)
	var first: Dictionary = _exception_entry(unanswered)
	valid = valid and not first.is_empty()
	var retried: Dictionary = {}
	while valid and int(unanswered.world.state.turn) <= 5:
		var current: Dictionary = _exception_entry(unanswered)
		if not current.is_empty() and current.root != first.root: retried = current
		valid = _finish(unanswered)
		if int(unanswered.world.state.turn) > 5: break
		valid = valid and _open(unanswered) and _evolve(unanswered)
	var closed: Array = _facts(unanswered.world, "conflict_scene_closed").filter(func(fact: Dictionary) -> bool: return fact.changes.root == first.get("root"))
	valid = valid and closed.size() == 1 and not retried.is_empty()
	if valid:
		var original: Dictionary = Store.entry(unanswered.world.state.facts, first.root)
		var retry: Dictionary = Store.entry(unanswered.world.state.facts, retried.root)
		valid = original.changes.exception == retry.changes.exception and original.id != retry.id
	details.merge({"unansweredFirst": first, "unansweredRetry": retried, "unansweredCloseCount": closed.size(), "retryTick": Store.entry(unanswered.world.state.facts, unanswered.world.state.prayer_dispatch.last[unanswered.domain])})
	_check("SE-CAPACITY", "Capacity creates no phantom observer; released capacity and expired requests allow new observations", valid, details)
