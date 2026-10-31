extends "res://tools/prayers/run.gd"
## Independent bounded coordinator checks. Prepared situations are consumer
## prerequisites, never evidence that natural roots or new calls were produced.
const Events = preload("res://src/game/events.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Session = preload("res://src/presentation/session.gd")

class DispatchRejectWorld extends "res://src/simulation/world.gd":
	var reject_dispatch: bool = false
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_dispatch and candidate.get("prayer_dispatch", {}) != trusted.get("prayer_dispatch", {}):
			issues.append("Injected dispatcher publication failure")
		return issues

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PD-CATALOG", "Current formal CSV Catalog loads", loaded, {"errors": catalog.errors})
	if not loaded:
		_write_report()
		return
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	run_dispatch_cases()
	_write_report()

func _write_report() -> void:
	var ok: bool = true
	for row: Dictionary in records: ok = ok and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records, "executionScope": "bounded_prayer_dispatch_modules", "limitations": ["Prepared published prayer_situation facts are explicit consumer prerequisites, not natural root production.", "Legacy BG templates remain a transitional source path; this does not prove new call production, the four direction/mode cells, atomic bootstrap, action windows, minimal Session projection, natural reachability or balance.", "Full Session is still expected to reject unsupported CULT consumers."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if ok else 1)

func _attach_dispatch(data: Dictionary) -> Dictionary:
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog))
	if data.world.state.has("economy"): data.world.state.economy.issuers = accepted.duplicate(true)
	data.economy = Economy.new(catalog, accepted)
	var turn: RefCounted = Turn.new(data.world)
	assert(turn._attached and data.economy.install(turn))
	data.fixture = Fixture.new()
	assert(turn.register_participant("cult-fixture", "1", ["deadlines", "ending"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog)
	data.relics = Relics.new(catalog, accepted)
	data.powers = Powers.new(catalog, accepted)
	data.prayers = Prayers.new(catalog, accepted)
	assert(data.cults.install(turn) and data.relics.install(turn) and data.powers.install(turn) and data.prayers.install(turn))
	data.events = Events.new(catalog)
	assert(data.events.install(turn))
	data.turn = turn
	return data

func _dispatch_native(seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = DispatchRejectWorld.new(catalog)
	assert(world.generate_hybrid(seed_value))
	return {"world": world, "source": world.state.domains["DOMAIN-001"].origin}

func _situation_prerequisite(data: Dictionary, person: String, need: String = "devotion") -> String:
	var world: RefCounted = data.world
	var npc: Dictionary = Store.entry(world.state.npcs, person)
	var domain: String = npc.domain
	var institution: String = npc.institution
	if institution.is_empty(): institution = domain + "/interpretation"
	var root: String = world._record("devotion_contact", domain, person, [person], [world.state.domains[domain].origin], {"subject": person, "institution": institution})
	world._know(person, root)
	var source: String = world.introduce_fact("prayer_situation", domain, person, [person], [root], {"issuer": "cult-fixture", "version": "1", "need": need, "domain": domain, "institution": institution, "actors": [person], "subjects": {"petitioner": person}, "facts": {"contact": root}, "crisis": {}}, [person], [], data.get("turn"))
	assert(not source.is_empty())
	return source

func _resign(envelope: Dictionary, world_envelope: Dictionary) -> String:
	world_envelope.body = World._normalize_numbers(world_envelope.body)
	world_envelope.checksum = World.canonical(world_envelope.body).sha256_text()
	envelope.body.world = World.canonical(world_envelope)
	envelope.body = World._normalize_numbers(envelope.body)
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	return World.canonical(envelope)

func _state(data: Dictionary) -> Dictionary:
	return data.world.state.get("prayer_dispatch", {})

func _new_facts(world: RefCounted, kind: String, cutoff: int) -> Array:
	return _facts(world, kind).filter(func(fact: Dictionary) -> bool: return int(str(fact.id).trim_prefix("FACT-")) >= cutoff)

func run_dispatch_cases() -> void:
	_coordinator_protocol()
	for mode: String in ["focused", "background"]: _existing_every_turn(mode)
	_cadence_and_switch()
	_independent_same_petitioner()
	for earlier: bool in [false, true]: _capacity_due_priority(earlier)
	_paged_current_sources()
	_notice_dispatch_cases()
	_native_devotion_cases()
	_dispatch_save()
	_session_boundary()

func _ordinary_fixed(data: Dictionary, sources: Array) -> Array:
	var found: Array = []
	for card: Dictionary in data.world.state.simulation.candidates.values():
		if card.get("source", "") in sources: found.append(card.duplicate(true))
	return found

func _coordinator_protocol() -> void:
	for variant: String in ["focused_handler", "background_handler", "coordinator_owner"]:
		var data: Dictionary = _attach_dispatch(_dispatch_native())
		assert(_open(data) and _submit(data, "end_actions").ok)
		var before: String = data.turn.snapshot()
		var prior_owner: String = str(data.turn._owners.get("candidate_generation", ""))
		var prior_handlers: Dictionary = data.events.mode_handlers.duplicate()
		match variant:
			"focused_handler": data.events.mode_handlers["detailed_candidates"] = Callable()
			"background_handler": data.events.mode_handlers["abstract_candidates_due"] = Callable()
			"coordinator_owner": data.turn._owners["candidate_generation"] = "cult-fixture"
		var response: Dictionary = _submit(data, "advance")
		data.events.mode_handlers = prior_handlers
		data.turn._owners["candidate_generation"] = prior_owner
		_check("PD-COORDINATOR/" + variant, "The real evolution refuses a missing mode handler or wrong candidate coordinator and rolls back instead of silently falling back", not response.ok and before == data.turn.snapshot(), {"response": response, "unchanged": before == data.turn.snapshot(), "scope": "Bounded explicit protocol fault, not the future automated capability audit"})

func _local_people(world: RefCounted) -> Array:
	var people: Array = []
	for person: Dictionary in Store.values(world.state.npcs):
		if person.domain == "DOMAIN-001" and person.status == "active" and not person.get("bound_member", false): people.append(person.id)
	people.sort()
	return people

func _existing_every_turn(mode: String) -> void:
	var data: Dictionary = _dispatch_native()
	var people: Array = _local_people(data.world)
	var domain: String = "DOMAIN-001"
	if mode == "background":
		domain = "DOMAIN-002"
		people = []
		for index: int in 2:
			var person: String = "NPC-%08d" % int(data.world.state.next_npc)
			assert(data.world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", data.world.state.domains[domain].origin))
			people.append(person)
	var sources: Array = [_situation_prerequisite(data, people[0]), _situation_prerequisite(data, people[1])]
	_attach_dispatch(data)
	var installed: bool = not _state(data).is_empty()
	_check("PD-INSTALL/" + mode, "Events installs the versioned coordinator ledger", installed, {"ledger": _state(data).duplicate(true)})
	if not installed: return
	var opened: bool = _open(data)
	var before_fix: Array = _ordinary_fixed(data, sources)
	var before: Dictionary = data.world.state.simulation.cursors[domain].duplicate(true)
	var cutoff: int = int(data.world.state.next_fact)
	var evolved: bool = _evolve(data)
	var first: Array = _ordinary_fixed(data, sources)
	var first_last: Dictionary = _state(data).get("last", {}).duplicate(true)
	var actual_mode: String = "focused" if domain in data.world.state.simulation.focused else "background"
	_check("PD-EXISTING/FIRST/" + mode, "Real World.evolve fixes at most one published source in its domain; phase two does not eagerly fix it", opened and before_fix.is_empty() and evolved and first.size() == 1 and actual_mode == mode, {"before": before, "cards": first, "dispatchLast": first_last, "newFixed": _new_facts(data.world, "prayer_fixed", cutoff), "mode": actual_mode, "preparedSources": sources})
	var continued: bool = _finish(data) and _open(data)
	var first_count: int = _ordinary_fixed(data, sources).size()
	continued = continued and _evolve(data)
	var both: Array = _ordinary_fixed(data, sources)
	_check("PD-EXISTING/EVERY-TURN/" + mode, "The second published source is handled on the next phase four, independently of the four-turn new-opportunity cadence", continued and first_count == 1 and both.size() == 2, {"cards": both, "cursor": data.world.state.simulation.cursors[domain], "last": _state(data).get("last", {})})
	var single: bool = true
	for source: String in sources:
		var count: int = 0
		for fact: Dictionary in _facts(data.world, "prayer_fixed"):
			if fact.changes.get("candidate", {}).get("source") == source: count += 1
		single = single and count == 1
	_check("PD-EXISTING/UNIQUE/" + mode, "Published source consumption remains unique across the mode and retry boundaries", single, {"sources": sources, "callsGeneratedByPreparedSources": _facts(data.world, "prayer_call").size(), "scope": "Published-situation dispatch only; no raw-root or new-call production claim"})

func _cadence_and_switch() -> void:
	var data: Dictionary = _attach_dispatch(_dispatch_native())
	var samples: Array = []
	var valid: bool = not _state(data).is_empty()
	var saw_focused_due: bool = false
	var saw_background_due: bool = false
	for round_index: int in 12:
		if not _open(data): valid = false; break
		var turn_number: int = int(data.world.state.turn)
		if round_index in [2, 6]:
			var released: Dictionary = _submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}})
			valid = valid and released.ok
		if round_index == 4:
			var focused: Dictionary = _submit(data, "attention", {"command": {"kind": "focus", "domain": "DOMAIN-001"}})
			valid = valid and focused.ok
		var before: Dictionary = data.world.state.simulation.cursors["DOMAIN-001"].duplicate(true)
		var cutoff: int = int(data.world.state.next_fact)
		var progressed: bool = _evolve(data)
		var after: Dictionary = data.world.state.simulation.cursors["DOMAIN-001"].duplicate(true)
		var mode: String = "focused" if "DOMAIN-001" in data.world.state.simulation.focused else "background"
		var due: bool = int(before.next_turn) <= turn_number
		if due and mode == "focused": saw_focused_due = true
		if due and mode == "background": saw_background_due = true
		var expected_next: int = turn_number + int(data.world.abstract_sim.parameters.background_tick_interval) if due else int(before.next_turn)
		valid = valid and progressed and int(after.next_turn) == expected_next
		if not due: valid = valid and after == before
		var produced: Array = []
		for fact: Dictionary in _new_facts(data.world, "background_fixed", cutoff) + _new_facts(data.world, "identity_notice_selected", cutoff):
			if fact.domain == "DOMAIN-001": produced.append(fact)
		valid = valid and produced.size() <= 1 and (due or produced.is_empty())
		samples.append({"turn": turn_number, "mode": mode, "due": due, "before": before, "after": after, "produced": produced, "last": _state(data).get("last", {}).get("DOMAIN-001", "")})
		if not progressed or not _finish(data): valid = false; break
	_check("PD-CADENCE-SWITCH", "Focused/background share one four-turn cursor; switching neither resets the phase nor collects missed opportunities or doubles a draw", valid and saw_focused_due and saw_background_due, {"samples": samples, "focusedDueObserved": saw_focused_due, "backgroundDueObserved": saw_background_due})

func _dispatch_save() -> void:
	var data: Dictionary = _dispatch_native()
	for person: String in _local_people(data.world).slice(0, 4): _situation_prerequisite(data, person)
	_attach_dispatch(data)
	var ready: bool = _open(data) and _evolve(data)
	# Domain 001 is due at turn three for this authored deterministic seed;
	# joint RNG corruption must reach the sampled branch, not merely not-due.
	for index: int in 2: ready = ready and _finish(data) and _open(data) and _evolve(data)
	var saved: String = data.turn.snapshot()
	var original: Dictionary = _state(data).duplicate(true)
	var restored: bool = data.turn.restore(saved)
	_check("PD-SAVE-ROUNDTRIP", "Coordinator heads, bounded query positions, tick receipts, RNG and candidate consumption survive current-module restore", ready and restored and saved == data.turn.snapshot() and original == _state(data), {"restored": restored, "error": data.turn.last_error, "ledger": original})
	var envelope: Dictionary = JSON.parse_string(saved)
	var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
	var resigned: bool = data.turn.restore(_resign(envelope, world_envelope))
	_check("PD-SAVE-RESIGN-CONTROL", "An unchanged normalized re-sign succeeds before any semantic corruption negatives are accepted", resigned and data.turn.snapshot() == saved, {"restored": resigned, "error": data.turn.last_error})
	for variant: String in ["schema", "version", "installed", "last", "head_omission", "position", "rng_joint", "position_joint", "snapshot_commit", "snapshot_cutoff"]:
		envelope = JSON.parse_string(saved)
		world_envelope = JSON.parse_string(envelope.body.world)
		var ledger: Dictionary = world_envelope.body.state.get("prayer_dispatch", {})
		var tick: Dictionary = world_envelope.body.state.facts[ledger.last["DOMAIN-001"]].changes
		match variant:
			"schema": ledger.schema += 1
			"version": ledger.version += "/forged"
			"installed": ledger.installed = world_envelope.body.state.domains["DOMAIN-001"].origin
			"last": ledger.last["DOMAIN-001"] = world_envelope.body.state.domains["DOMAIN-001"].origin
			"head_omission": ledger.heads["DOMAIN-001"].clear()
			"position": ledger.positions["DOMAIN-001"]["source_after"] = "FACT-NONEXISTENT"
			"rng_joint":
				tick.after.state = str(int(tick.after.state) + 1)
				world_envelope.body.state.simulation.cursors["DOMAIN-001"].state = tick.after.state
			"position_joint":
				tick.position_after.source_after = "FORGED/SCAN/POSITION"
				ledger.positions["DOMAIN-001"].source_after = tick.position_after.source_after
			"snapshot_commit": tick.snapshot.commit_seq += 1
			"snapshot_cutoff": tick.snapshot.fact_cutoff += 1
		var before: String = data.turn.snapshot()
		var accepted: bool = data.turn.restore(_resign(envelope, world_envelope))
		_check("PD-SAVE-REJECT/" + variant, "Correct envelope checksums cannot authorize a corrupted coordinator ledger", resigned and not accepted and before == data.turn.snapshot() and "checksum" not in data.turn.last_error.to_lower(), {"accepted": accepted, "error": data.turn.last_error, "currentUnchanged": before == data.turn.snapshot()})
		if accepted: assert(data.turn.restore(saved))

func _paged_current_sources() -> void:
	var data: Dictionary = _dispatch_native()
	var people: Array = []
	var sources: Array = []
	var page_limit: int = int(data.world.history.page_limit)
	for index: int in page_limit + 3:
		var person: String = "NPC-%08d" % int(data.world.state.next_npc)
		assert(data.world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", data.source))
		people.append(person)
		sources.append(_situation_prerequisite(data, person))
	_attach_dispatch(data)
	var progressed: bool = _open(data) and _evolve(data)
	var samples: Array = []
	for index: int in range(1, page_limit + 1):
		data.fixture.deadlines.append({"type": "world_command", "source": data.source, "command": {"kind": "status", "npc": people[index], "status": "detained", "parents": [data.source]}})
	progressed = progressed and _finish(data)
	data.fixture.deadlines = []
	var reached: bool = false
	var roundtrip: bool = true
	for attempt: int in 3:
		progressed = progressed and _open(data) and _evolve(data)
		var cards: Array = _ordinary_fixed(data, sources.slice(page_limit + 1))
		reached = reached or not cards.is_empty()
		var saved: String = data.turn.snapshot()
		var position: Dictionary = _state(data).get("positions", {}).get("DOMAIN-001", {}).duplicate(true)
		roundtrip = roundtrip and data.turn.restore(saved) and data.turn.snapshot() == saved and _state(data).get("positions", {}).get("DOMAIN-001", {}) == position
		samples.append({"attempt": attempt, "position": position, "tailCards": cards, "headCount": _state(data).get("heads", {}).get("DOMAIN-001", {}).size()})
		if reached or not progressed: break
		progressed = progressed and _finish(data)
	_check("PD-PAGE-CONTINUATION", "An active source beyond a full page of newly invalid current heads remains reachable across bounded scans and save/restore", progressed and reached and roundtrip, {"pageLimit": page_limit, "sources": sources.size(), "invalidatedExistingPeople": page_limit, "samples": samples, "scope": "Explicit source/identity consumer fixture; no natural production claim"})

func _session_boundary() -> void:
	var session: RefCounted = Session.new(scratch.path_join("session"))
	var previous_world: RefCounted = session.world
	var previous_turn: RefCounted = session.turn
	var result: Dictionary = session.start_new(7919)
	_check("PD-SESSION-CULT-BOUNDARY", "Dispatch acceptance does not remove the explicit unsupported-CULT new-Session rejection", not result.ok and not str(result.get("error", "")).is_empty() and session.world == previous_world and session.turn == previous_turn and session.modules.is_empty(), {"result": result, "scope": "New empty Session rejection only; no full campaign restore or playability claim"})

func _rescue_prerequisite(data: Dictionary, petitioner: String, patient: String, due: int, delayed: bool = false, empty_crisis: bool = false) -> Dictionary:
	var world: RefCounted = data.world
	var institution: String = Store.entry(world.state.npcs, petitioner).institution
	var harm: String = _given_fact(data, "harm", patient, [patient], {"fixture": "existing_injury_consumer_prerequisite"})
	var condition: String = _given_fact(data, "dying_condition", petitioner, [patient], {"patient": patient, "due": due}, [harm])
	var relation: String = _given_relation(data, petitioner, patient, "family")
	var parents: Array = [condition, relation]
	var actors: Array = [petitioner, patient]
	var details: Dictionary = {"issuer": "cult-fixture", "version": "1", "need": "rescue", "domain": "DOMAIN-001", "institution": institution, "actors": actors, "subjects": {"petitioner": petitioner, "relative": patient}, "facts": {"condition": condition, "relation": relation}, "crisis": {"source": condition, "due": due}}
	if empty_crisis: details.crisis = {}
	if delayed:
		return {"effect": {"type": "fact", "source": condition, "kind": "prayer_situation", "domain": "DOMAIN-001", "actor": petitioner, "targets": actors, "parents": parents, "observers": actors, "institutions": [], "details": details}, "condition": condition}
	var source: String = world.introduce_fact("prayer_situation", "DOMAIN-001", petitioner, actors, parents, details, actors)
	assert(not source.is_empty())
	return {"source": source, "condition": condition}

func _independent_same_petitioner() -> void:
	var data: Dictionary = _dispatch_native()
	var people: Array = _local_people(data.world)
	var early: Dictionary = _rescue_prerequisite(data, people[0], people[1], 5, false, true)
	var late: Dictionary = _rescue_prerequisite(data, people[0], people[2], 6)
	_attach_dispatch(data)
	var initial: Dictionary = _state(data).duplicate(true)
	var valid: bool = _open(data) and _evolve(data)
	var first: Array = _ordinary_fixed(data, [early.source, late.source])
	valid = valid and first.size() == 1 and first[0].source == early.source
	var saved: String = data.turn.snapshot()
	valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved
	valid = valid and _finish(data) and _open(data) and _evolve(data)
	var both: Array = _ordinary_fixed(data, [early.source, late.source])
	_check("PD-INDEPENDENT-SAME-PETITIONER", "Two already-published crises for different actual patients remain independently dispatchable for the same petitioner and need", valid and both.size() == 2, {"early": early, "late": late, "initialLedger": initial, "first": first, "both": both, "scope": "Explicit lawful family/injury source consumer fixtures; no natural accident generator claim"})

func _capacity_due_priority(earlier_arrival: bool) -> void:
	var data: Dictionary = _dispatch_native()
	var people: Array = _local_people(data.world)
	var early: Dictionary = _rescue_prerequisite(data, people[0], people[1], 6)
	var late: Dictionary = _rescue_prerequisite(data, people[2], people[3], 8)
	var arriving: Dictionary = _rescue_prerequisite(data, people[4], people[5], 5, true) if earlier_arrival else {}
	var fillers: Array = []
	for index: int in 7:
		var person: String = "NPC-%08d" % int(data.world.state.next_npc)
		assert(data.world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", data.world.state.domains["DOMAIN-002"].origin))
		fillers.append(_situation_prerequisite(data, person))
	_attach_dispatch(data)
	for source: String in fillers: assert(data.world.fix_prayer_source(source, data.turn))
	if earlier_arrival: data.fixture.deadlines = [arriving.effect]
	var valid: bool = _open(data) and _evolve(data)
	var first_tick: Dictionary = Store.entry(data.world.state.facts, str(_state(data).get("last", {}).get("DOMAIN-001", "")), {})
	valid = valid and first_tick.get("changes", {}).get("selected") == early.source and first_tick.changes.get("existing_outcome") == "capacity_blocked" and _ordinary_fixed(data, [early.source, late.source]).is_empty()
	valid = valid and _finish(data)
	data.fixture.deadlines = []
	valid = valid and _open(data)
	var freed: bool = false
	var response: Dictionary = {}
	for id: String in data.world.state.prayer_system.offered:
		if data.prayers.preview(data.turn, id, "shallow").get("ok", false):
			var descriptor: Dictionary = data.world.state.prayer_system.requests[id].descriptor
			_choose_prayer_seed(data, "failure", descriptor.subjects.petitioner, descriptor.domain)
			response = _response(data, id, "shallow")
			freed = response.ok
			break
	var target: String = early.source
	if earlier_arrival:
		for fact: Dictionary in _facts(data.world, "prayer_situation"):
			if fact.changes.get("facts", {}).get("condition") == arriving.condition: target = fact.id
		valid = valid and target != early.source
	var saved: String = data.turn.snapshot()
	valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved
	valid = valid and _evolve(data)
	var second_tick: Dictionary = Store.entry(data.world.state.facts, str(_state(data).get("last", {}).get("DOMAIN-001", "")), {})
	var fixed: Array = _ordinary_fixed(data, [target])
	_check("PD-DUE-PRIORITY/" + ("new_earlier" if earlier_arrival else "blocked_retry"), "A capacity block or persisted scan position cannot let a later-due source bypass the earliest current legal source", valid and freed and second_tick.get("changes", {}).get("selected") == target and fixed.size() == 1, {"firstTick": first_tick, "secondTick": second_tick, "target": target, "fixed": fixed, "responseFreedSpace": response, "scope": "Capacity fillers were fixed through the normal World API; target sources were fixed only by actual World.evolve"})

func _notice_fixture(mode: String, variant: String, seed_value: int) -> Dictionary:
	var data: Dictionary = _dispatch_native(seed_value)
	var people: Array = _local_people(data.world)
	data.sender = people[0]
	data.recipient = people[1] if variant not in ["no_relation", "wrong_relation"] else people[3]
	var world: RefCounted = data.world
	var origin: String = world.state.domains["DOMAIN-001"].origin
	if variant == "cross_domain":
		data.recipient = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-002"].origin))
	if variant == "same_institution":
		data.recipient = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", origin))
		_given_relation(data, data.sender, data.recipient, "support")
	for person: String in people:
		if person not in [data.sender, data.recipient]: assert(world.submit({"kind": "status", "npc": person, "status": "detained", "parents": [origin]}))
	if variant in ["dead", "detained", "missing"]:
		assert(world.submit({"kind": "status", "npc": data.recipient, "status": variant, "parents": [origin]}))
	if variant == "wrong_relation": _given_relation(data, data.sender, data.recipient, "rival")
	if variant == "no_route":
		var sender_institution: String = Store.entry(world.state.npcs, data.sender).institution
		var recipient_institution: String = Store.entry(world.state.npcs, data.recipient).institution
		world.state.institutions[sender_institution].links.erase(recipient_institution)
	# Remove anonymous nomination opportunities through a real population change;
	# the fixture does not alter the producer table, RNG or candidate handler set.
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog))
	var prerequisite_economy: RefCounted = Economy.new(catalog, accepted)
	assert(prerequisite_economy.initialize(world))
	var available: int = int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers)
	if available > 0: assert(world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": available, "parents": [origin]}))
	var contact: String = _given_fact(data, "devotion_contact", data.sender, [data.sender], {"subject": data.sender, "institution": Store.entry(world.state.npcs, data.sender).institution})
	if variant == "anomaly_only": _given_fact(data, "exposure", data.sender, [data.sender], {"public": false, "unexplained": true})
	_attach_dispatch(data)
	var qualification: String = _qualification(data, "dream", data.sender, data.sender, "DOMAIN-001", {"contact": contact})
	data.dream = {"npc": data.sender, "source": contact, "qualification": qualification}
	assert(_open(data))
	if variant not in ["unidentified", "anomaly_only"]:
		assert(_seed(data, "POWER_DREAM", "success", data.dream) > 0)
		var response: Dictionary = _power(data, "POWER_DREAM", data.dream)
		assert(response.ok and Knowledge.known(world.state, data.sender).get("known", false))
	if mode == "background":
		assert(_submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}).ok)
		assert(_evolve(data) and _finish(data) and _open(data))
	return data

func _notice_dispatch_cases() -> void:
	var selected_seed: int = -1
	for mode: String in ["focused", "background"]:
		var found: Dictionary = {}
		var evidence: Array = []
		for seed_value: int in ([7919, 19, 42, 2027, 1981, 104729] if selected_seed < 0 else [selected_seed]):
			var data: Dictionary = _notice_fixture(mode, "valid", seed_value)
			var evolved: bool = true
			for attempt: int in 12:
				evolved = _evolve(data)
				var received: Array = _facts(data.world, "deity_identity_received")
				if not received.is_empty():
					found = {"data": data, "received": received, "seed": seed_value}
					break
				if not evolved or not _finish(data) or not _open(data): evolved = false; break
			var actual: String = "focused" if "DOMAIN-001" in data.world.state.simulation.focused else "background"
			evidence.append({"seed": seed_value, "evolved": evolved, "mode": actual, "turn": data.world.state.turn, "received": _facts(data.world, "deity_identity_received")})
			if not found.is_empty(): break
		var valid: bool = not found.is_empty()
		if valid:
			selected_seed = int(found.seed)
			var data: Dictionary = found.data
			var received: Dictionary = found.received[0]
			var selected: Array = _facts(data.world, "identity_notice_selected")
			valid = selected.size() == 1 and received.changes.get("sender") == data.sender and received.changes.get("person") == data.recipient and Knowledge.known(data.world.state, data.recipient).get("known", false) and selected[0].id in received.causal_parents
			var receipt: Dictionary = {}
			for entry: Dictionary in Store.values(data.turn.context.receipts):
				if int(str(selected[0].id).trim_prefix("FACT-")) >= int(entry.get("fact_before", -1)) and int(str(received.id).trim_prefix("FACT-")) < int(entry.get("fact_after", -1)): receipt = entry
			valid = valid and not receipt.is_empty() and receipt.request.phase == "evolution"
			found.erase("data")
			found["sameReceipt"] = receipt
		_check("PD-NOTICE/" + mode, "The real shared opportunity selection automatically transfers sourced identity within one published evolution receipt", valid, {"evidence": evidence, "found": found, "scope": "Existing real relationship/population prerequisites and actual successful dream; no hand-selected notice authorization"})
	if selected_seed < 0: return
	for variant: String in ["unidentified", "anomaly_only", "no_relation", "wrong_relation", "no_route", "dead", "detained", "missing", "cross_domain", "same_institution"]:
		var data: Dictionary = _notice_fixture("focused", variant, selected_seed)
		var valid: bool = true
		for attempt: int in 12:
			valid = valid and _evolve(data)
			if not _facts(data.world, "deity_identity_received").is_empty() or not valid: break
			valid = valid and _finish(data) and _open(data)
		var received: Array = _facts(data.world, "deity_identity_received")
		var known: bool = Knowledge.known(data.world.state, data.recipient).get("known", false)
		valid = valid and (known and received.size() == 1 if variant == "same_institution" else not known and received.is_empty())
		_check("PD-NOTICE/" + variant, "Automatic identity notice requires the actual original knowledge, relationship, active same-domain parties and current route", valid, {"received": received, "recipientKnowledge": Knowledge.known(data.world.state, data.recipient), "seed": selected_seed, "turn": data.world.state.turn})
	_notice_rollback(selected_seed)

func _notice_rollback(seed_value: int) -> void:
	var data: Dictionary = _notice_fixture("focused", "valid", seed_value)
	var saved: String = ""
	var result: Dictionary = {}
	var selected: Array = []
	for attempt: int in 12:
		assert(_submit(data, "end_actions").ok)
		saved = data.turn.snapshot()
		result = _submit(data, "advance")
		selected = _facts(data.world, "identity_notice_selected")
		if not selected.is_empty(): break
		assert(result.ok and _finish(data) and _open(data))
	var valid: bool = result.get("ok", false) and selected.size() == 1
	if valid:
		var committed: String = data.turn.snapshot()
		assert(data.turn.restore(saved))
		data.world.reject_dispatch = true
		var rejected: Dictionary = _submit(data, "advance")
		valid = valid and not rejected.ok and saved == data.turn.snapshot() and _facts(data.world, "identity_notice_selected").is_empty() and _facts(data.world, "deity_identity_received").is_empty()
		data.world.reject_dispatch = false
		var retried: Dictionary = _submit(data, "advance")
		# Different request IDs change receipt keys; the world/RNG must still match.
		var original: Dictionary = JSON.parse_string(committed)
		var original_world: String = original.body.world
		valid = valid and retried.ok and data.world.snapshot() == original_world and _facts(data.world, "identity_notice_selected").size() == 1 and _facts(data.world, "deity_identity_received").size() == 1
		result = {"rejected": rejected, "retried": retried, "sameWorld": data.world.snapshot() == original_world}
	_check("PD-NOTICE/ROLLBACK", "A true publication fault rolls back selection, knowledge, shared RNG and cursor together, with one identical world result on retry", valid, {"result": result, "selected": selected})

func _native_devotion_cases() -> void:
	for variant: String in ["shallow", "deep"]:
		for outcome: String in ["deep", "success", "failure", "disaster"]:
			var data: Dictionary = _attach_dispatch(_dispatch_native())
			var no_cult: bool = data.world.state.cults.is_empty()
			assert(_open(data))
			var request: String = ""
			for id: String in data.world.state.prayer_system.offered:
				if data.world.state.prayer_system.requests[id].descriptor.content_id == "PRAYER_08": request = id
			if request.is_empty():
				_check("PD-FIRST-DEVOTION/" + variant + "/" + outcome, "An actual no-cult bootstrap contact can be accepted without assuming an existing cult membership", false, {"offered": data.world.state.prayer_system.offered})
				continue
			var petitioner: String = data.world.state.prayer_system.requests[request].descriptor.subjects.petitioner
			assert(_submit(data, "set_plan", {"participant": "economy", "payload": {}}).ok)
			var seeded: int = _choose_prayer_seed(data, outcome, petitioner, "DOMAIN-001")
			var response: Dictionary = _response(data, request, variant)
			var results: Array = _facts(data.world, "prayer_result")
			var current: Dictionary = Knowledge.known(data.world.state, petitioner)
			var success: bool = outcome in ["deep", "success"]
			var valid: bool = no_cult and seeded > 0 and response.ok and results.size() == 1 and results[0].changes.outcome == outcome and Store.entry(data.world.state.npcs, petitioner).get("bound_member", false) == success and current.get("known", false) == success and _facts(data.world, "deity_identified").size() == (1 if success else 0)
			var membership: Dictionary = {}
			if success and not results.is_empty():
				membership = Store.entry(data.world.state.facts, str(results[0].changes.get("recognition", {}).get("membership", "")), {})
				valid = valid and membership.get("kind") == "member_enrolled" and membership.actor == petitioner
			var saved: String = data.turn.snapshot()
			var restored: bool = data.turn.restore(saved)
			var envelope: Dictionary = JSON.parse_string(saved)
			var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
			var resigned: bool = data.turn.restore(_resign(envelope, world_envelope))
			valid = valid and restored and resigned and data.turn.snapshot() == saved
			_check("PD-FIRST-DEVOTION/" + variant + "/" + outcome, "Real no-cult PR08 consumes the actual member enrollment only on successful acceptance; current save and unchanged re-sign preserve it", valid, {"response": response, "results": results, "knowledge": current, "membership": membership, "restored": restored, "normalizedResignControl": resigned, "scope": "Legacy bootstrap consumer regression; new root/call/bootstrap production remains PRAYER-PRODUCERS"})
			if success and variant == "shallow" and outcome == "success": _native_devotion_corruptions(data, saved, petitioner, results[0].id, membership.id)

func _native_devotion_corruptions(data: Dictionary, saved: String, petitioner: String, result_id: String, membership_id: String) -> void:
	for variant: String in ["wrong_membership", "wrong_person", "missing_devotion_cause", "different_commit_same_turn"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var state: Dictionary = world_envelope.body.state
		var identity: Dictionary = state.facts[Knowledge.known(data.world.state, petitioner).source]
		match variant:
			"wrong_membership":
				state.facts[result_id].changes.recognition.membership = state.domains["DOMAIN-001"].origin
				identity.changes.recognition.membership = state.domains["DOMAIN-001"].origin
			"wrong_person": state.facts[membership_id].actor = _local_people(data.world)[0]
			"missing_devotion_cause": state.facts[membership_id].causal_parents = [state.domains["DOMAIN-001"].origin]
			"different_commit_same_turn":
				var receipts: Dictionary = envelope.body.context.receipts
				var sequence: int = int(identity.changes.recognition.position.commit_seq)
				for entry: Dictionary in receipts.values():
					if int(entry.sequence) == sequence: entry.fact_before = int(membership_id.trim_prefix("FACT-")) + 1
					if int(entry.sequence) == sequence - 1: entry.fact_after = int(membership_id.trim_prefix("FACT-")) + 1
		var direct_context_issues: Array = Knowledge.validate_context(World._normalize_numbers(state), World._normalize_numbers(envelope.body.context), catalog)
		var before: String = data.turn.snapshot()
		var accepted: bool = data.turn.restore(_resign(envelope, world_envelope))
		var expected_layer: bool = variant != "different_commit_same_turn" or "Devotion enrollment and recognition have different commits" in direct_context_issues
		_check("PD-FIRST-DEVOTION-REJECT/" + variant, "A recomputed checksum cannot turn an unrelated, uncaused or separately committed membership into actual identity recognition", not accepted and before == data.turn.snapshot() and "checksum" not in data.turn.last_error.to_lower() and expected_layer, {"accepted": accepted, "error": data.turn.last_error, "directKnowledgeContextIssues": direct_context_issues, "currentUnchanged": before == data.turn.snapshot()})
		if accepted: assert(data.turn.restore(saved))
