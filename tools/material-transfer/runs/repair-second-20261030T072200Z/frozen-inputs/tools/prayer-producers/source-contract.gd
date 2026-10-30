extends "res://tools/prayer-producers/source-exception.gd"
## Four current-contract conclusions and the thirteen affected shared checks.
func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files(): _check("SC-CATALOG", "Formal CSV load", false, {"errors": catalog.errors})
	else:
		_case(false); _case(true); _capacity()
		for content: String in ["PRAYER_02", "PRAYER_10", "PRAYER_03", "PRAYER_11"]: _conflict_case(content)
		for mode: String in ["shallow", "deep", "expiry"]: _memory_case(mode)
		_exception_first(); _exception_independence(); _exception_capacity()
		_contract_case("shallow"); _contract_case("deep"); _contract_case("expiry"); _contract_succession()
	Support.write_report(records, "current_contract_sources_and_core_regression", [], ["Controlled initial RNG and actual response checks; ordinary contract/source/material/successor outputs come from Turn.", "Succession uses the actual initial social graph; death/status prerequisites use the existing deadline fixture. The selected-successor-ineligible negative is a read-only state counterfactual.", "Full Session/CULT compatibility, natural campaign balance, full CIV06 anchors and reciprocal operation/two-leg production remain downstream."])
	quit(0 if records.size() == 17 and records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _contract_setup() -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, 7919)
	_set_scene_random_input(world, "ROOT_CURRENT_PACT")
	var data: Dictionary = {"world": world, "source": world.state.domains["DOMAIN-001"].origin}
	_attach_dispatch(data); assert(_boot(data).ok)
	return data

func _contract_entry(data: Dictionary) -> Dictionary:
	for entry: Dictionary in data.world.state.prayer_sources.situations.values():
		if entry.domain == "DOMAIN-001" and entry.content == "PRAYER_06": return entry.duplicate(true)
	return {}

func _contract_request(data: Dictionary, entry: Dictionary) -> String:
	for id: String in data.world.state.prayer_system.offered:
		if data.world.state.prayer_system.requests[id].descriptor.source == entry.source: return id
	return ""

func _contract_materials(data: Dictionary, request: String, tag: String) -> Array:
	return _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") == tag)

func _contract_event(data: Dictionary) -> String:
	for id: String in data.world.state.event_system.selected:
		if data.world.state.event_system.cards[id].descriptor.content_id == "EVENT_05": return id
	return ""

func _contract_to_event(data: Dictionary) -> String:
	while int(data.world.state.turn) < 5:
		if not _evolve(data) or not _finish(data): return ""
		data.fixture.deadlines.clear()
		if not _submit(data, "advance").ok: return ""
		var found: String = _contract_event(data)
		if not found.is_empty(): return found
		if not _submit(data, "finish_events").ok: return ""
	return ""

func _contract_case(mode: String) -> void:
	var data: Dictionary = _contract_setup()
	var valid: bool = _open(data) and _evolve(data)
	var entry: Dictionary = _contract_entry(data)
	valid = valid and not entry.is_empty()
	var details: Dictionary = {"entry": entry}
	if valid:
		var root: Dictionary = Store.entry(data.world.state.facts, entry.root)
		valid = root.kind == "contract_obligation" and root.changes.term == catalog.tables.prayer_root_rules.ROOT_CURRENT_PACT.rule and root.changes.obligor == entry.petitioner and root.changes.due == entry.due and _facts(data.world, "contract_successor_authorized").is_empty()
		valid = valid and _finish(data) and _open(data)
		var request: String = _contract_request(data, entry)
		valid = valid and not request.is_empty() and _contract_materials(data, request, "contract_dependency").is_empty()
		var saved: String = data.turn.snapshot()
		valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved and data.world.state.prayer_sources.situations.get(entry.root) == entry
		if mode != "expiry" and valid:
			_choose_prayer_seed(data, "success", entry.petitioner, entry.domain)
			var response: Dictionary = _response(data, request, mode)
			var fulfilled: Array = _contract_materials(data, request, "contract_fulfilled")
			var dependencies: Array = _contract_materials(data, request, "contract_dependency")
			valid = response.ok and fulfilled.size() == 1 and Store.has(data.world.state.invalid_records, entry.root) and not data.world.state.prayer_sources.situations.has(entry.root)
			var faith: int = data.world.state.faith
			var repeated: Dictionary = _response(data, request, mode)
			valid = valid and not repeated.ok and data.world.state.faith == faith
			details.merge({"response": response, "fulfilledCount": fulfilled.size(), "dependencyCount": dependencies.size(), "duplicateRejected": not repeated.ok})
			if mode == "shallow":
				valid = valid and dependencies.is_empty() and _contract_materials(data, request, "contract_witness").size() == 1
				var restricted: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") == "appointment_restricted")
				valid = valid and restricted.size() == 1 and data.world.state.prayer_system.restrictions.get(entry.petitioner, {}).get("appointment", {}).get("until") == int(data.world.state.turn) + 1
				details["restrictionFacts"] = restricted
			else:
				valid = valid and dependencies.size() == 1 and _contract_materials(data, request, "contract_learned").size() == 1 and not Store.has(data.world.state.invalid_records, dependencies[0].id)
				var event: String = _contract_to_event(data)
				valid = valid and not event.is_empty()
				if valid:
					var descriptor: Dictionary = data.world.state.event_system.cards[event].descriptor
					valid = descriptor.facts.contract == entry.root and descriptor.facts.dependency == dependencies[0].id and LocalEventRules.legal(data.world.state, descriptor, "A", catalog, data.world.history).ok
					var release: Dictionary = _submit(data, "resolve_event", {"event": event, "action": "A"})
					valid = valid and release.ok and Store.has(data.world.state.invalid_records, dependencies[0].id) and _facts(data.world, "event_fact").any(func(fact: Dictionary) -> bool: return fact.changes.get("tag") == "contract_released")
					details["release"] = release
		else:
			while valid and int(data.world.state.turn) <= int(entry.due):
				valid = _evolve(data) and _finish(data)
				if int(data.world.state.turn) <= int(entry.due): valid = valid and _open(data)
			var closed: Array = _contract_materials(data, request, "cooperation_closed")
			var ended: Array = _facts(data.world, "conflict_scene_closed").filter(func(fact: Dictionary) -> bool: return fact.changes.root == entry.root)
			valid = valid and closed.size() == 1 and ended.size() == 1 and _contract_materials(data, request, "contract_dependency").is_empty() and Store.has(data.world.state.invalid_records, entry.root)
			details.merge({"cooperationClosedCount": closed.size(), "sceneCloseCount": ended.size(), "originalDue": entry.due})
	_check("SC-" + mode.to_upper(), "Formal current agreement: actual " + mode + " result, stable deadline/save and one settlement", valid, details)

func _contract_successors(data: Dictionary, entry: Dictionary) -> Array:
	var root: Dictionary = Store.entry(data.world.state.facts, entry.root)
	var result: Array = []
	for id: String in data.world.history.ids("active/" + entry.domain):
		if id in [entry.petitioner, root.changes.counterparty]: continue
		var relation: Dictionary = data.world.history.relation_head(entry.petitioner, id, ["family", "support", "cooperation"])
		if relation.is_empty(): relation = data.world.history.relation_head(id, entry.petitioner, ["family", "support", "cooperation"])
		if not relation.is_empty(): result.append(id)
	result.sort(); return result

func _contract_succession() -> void:
	var data: Dictionary = _contract_setup()
	var valid: bool = _open(data) and _evolve(data)
	var entry: Dictionary = _contract_entry(data)
	valid = valid and not entry.is_empty() and _finish(data) and _open(data)
	var details: Dictionary = {"entry": entry}
	if valid:
		var request: String = _contract_request(data, entry)
		var candidates: Array = _contract_successors(data, entry)
		_choose_prayer_seed(data, "success", entry.petitioner, entry.domain)
		var response: Dictionary = _response(data, request, "deep")
		var dependencies: Array = _contract_materials(data, request, "contract_dependency")
		valid = response.ok and dependencies.size() == 1 and candidates.size() >= 2
		data.fixture.deadlines = [_status(data, entry.petitioner, "dead")]
		var event: String = _contract_to_event(data) if valid else ""
		valid = valid and not event.is_empty()
		details.merge({"response": response, "existingCandidates": candidates, "event": event})
		if valid:
			var descriptor: Dictionary = data.world.state.event_system.cards[event].descriptor.duplicate(true)
			var selected: String = descriptor.subjects.get("successor", "")
			valid = selected in candidates and _facts(data.world, "contract_successor_authorized").is_empty()
			var saved: String = data.turn.snapshot()
			valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved and data.world.state.event_system.cards[event].descriptor == descriptor
			details["fixedDescriptor"] = descriptor
			details["selectionFacts"] = _facts(data.world, "contract_inheritance_fixed")
			details["obligorStatus"] = Store.entry(data.world.state.facts, Store.entry(data.world.state.npcs, entry.petitioner).status_source)
			if not selected in candidates:
				_check("SC-SUCCESSION", "Post-death existing relation selection must precede actual continuation", false, details); return
			# Deep-duplicating immutable history roots removes their readonly
			# marker. Copy only these finite NPC projections for this negative.
			var shadow: Dictionary = data.world.state.duplicate(false)
			shadow.npcs = {}
			for id: String in Store.keys(data.world.state.npcs): shadow.npcs[id] = Store.entry(data.world.state.npcs, id).duplicate(false)
			shadow.npcs[selected].status = "detained"
			var another: String = candidates.filter(func(id: String) -> bool: return id != selected)[0]
			valid = valid and LocalEventRules.alive(shadow, another) and not LocalEventRules.legal(shadow, descriptor, "B", catalog, data.world.history).ok and LocalEventRules.legal(shadow, descriptor, "A", catalog, data.world.history).ok
			var continuation: Dictionary = _submit(data, "resolve_event", {"event": event, "action": "B"})
			var actual: Array = _facts(data.world, "contract_successor_authorized")
			valid = valid and continuation.ok and actual.size() == 1 and actual[0].changes.successor == selected and data.world.history.knows(data.world.state, selected, entry.root) and data.world.history.knows(data.world.state, selected, dependencies[0].id) and not Store.has(data.world.state.invalid_records, dependencies[0].id)
			var faith: int = data.world.state.faith
			var repeated: Dictionary = _submit(data, "resolve_event", {"event": event, "action": "B"})
			valid = valid and not repeated.ok and data.world.state.faith == faith and _facts(data.world, "contract_successor_authorized").size() == 1
			details.merge({"selected": selected, "otherStillEligible": another, "fixedDescriptor": descriptor, "continuation": continuation, "authorization": actual, "repeatRejected": not repeated.ok})
	# Separate real no-candidate world, still within this single succession group.
	var none: Dictionary = _contract_setup()
	var no_valid: bool = _open(none) and _evolve(none)
	var no_entry: Dictionary = _contract_entry(none)
	no_valid = no_valid and not no_entry.is_empty() and _finish(none) and _open(none)
	if no_valid:
		var request: String = _contract_request(none, no_entry)
		_choose_prayer_seed(none, "success", no_entry.petitioner, no_entry.domain)
		no_valid = _response(none, request, "deep").ok
		none.fixture.deadlines = [_status(none, no_entry.petitioner, "dead")]
		for person: String in _contract_successors(none, no_entry): none.fixture.deadlines.append(_status(none, person, "detained"))
		var event: String = _contract_to_event(none) if no_valid else ""
		no_valid = no_valid and not event.is_empty()
		if no_valid:
			var descriptor: Dictionary = none.world.state.event_system.cards[event].descriptor
			no_valid = not descriptor.subjects.has("successor") and not LocalEventRules.legal(none.world.state, descriptor, "B", catalog, none.world.history).ok and LocalEventRules.legal(none.world.state, descriptor, "A", catalog, none.world.history).ok
			var dead_knowledge: String = World.canonical(Store.entry(none.world.state.npcs, no_entry.petitioner).known_facts)
			var release: Dictionary = _submit(none, "resolve_event", {"event": event, "action": "A"})
			var preserved: bool = World.canonical(Store.entry(none.world.state.npcs, no_entry.petitioner).known_facts) == dead_knowledge
			var released: bool = Store.has(none.world.state.invalid_records, descriptor.facts.dependency)
			no_valid = no_valid and release.ok and preserved and released and _facts(none.world, "contract_successor_authorized").is_empty()
			details.merge({"noCandidateRelease": release, "deadKnowledgePreserved": preserved, "noCandidateDependencyReleased": released})
	_check("SC-SUCCESSION", "Post-death existing relation selection is fixed; actual B continues, no candidate still permits release", valid and no_valid, details)
