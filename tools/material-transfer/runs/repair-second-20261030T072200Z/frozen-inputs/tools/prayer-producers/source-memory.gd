extends "res://tools/prayer-producers/local-conflict.gd"
## Three memory conclusions plus seven directly affected source regressions.
func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files(): _check("SM-CATALOG", "Formal CSV load", false, {"errors": catalog.errors})
	else:
		_case(false); _case(true); _capacity()
		for content: String in ["PRAYER_02", "PRAYER_10", "PRAYER_03", "PRAYER_11"]: _conflict_case(content)
		for mode: String in ["shallow", "deep", "expiry"]: _memory_case(mode)
	Support.write_report(records, "lightweight_memory_sources_with_core_regression", [], ["Controlled RNG inputs and explicit initial population/private-knowledge prerequisites; no target shared observation, request, qualification or event result is injected.", "Turn/World component save only; full Session, cult compatibility, other source families, natural campaign and balance remain downstream."])
	quit(0 if records.size() == 10 and records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _memory_setup(minimum: bool) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, 7919)
	var origin: String = world.state.domains["DOMAIN-001"].origin
	var people: Array = world.history.ids("active/DOMAIN-001"); people.sort()
	if minimum:
		# Main-thread reviewed input after the two retained failed runs: keep
		# a real recognition petitioner and one messenger before bootstrap.
		var recorders: Array = people.filter(func(id: String) -> bool: return "recognition" in Store.entry(world.state.npcs, id).need_tags)
		if recorders.is_empty():
			var recorder: String = "NPC-%08d" % int(world.state.next_npc)
			assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", origin))
			people.append(recorder); recorders.append(recorder)
		var recorder: String = recorders[0]
		var partners: Array = people.filter(func(id: String) -> bool: return id != recorder and "messenger" in Store.entry(world.state.npcs, id).role_tags)
		if partners.is_empty(): partners = people.filter(func(id: String) -> bool: return id != recorder)
		assert(not partners.is_empty())
		for person: String in people:
			if not person in [recorder, partners[0]]: assert(world.submit({"kind": "status", "npc": person, "status": "detained", "parents": [origin]}))
	var remote: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-002"].origin))
	var private_fact: String = world._record("message", "DOMAIN-002", remote, [remote], [world.state.domains["DOMAIN-002"].origin], {"fixture": "unrelated private fact"})
	world._know(remote, private_fact)
	for person: String in people: world._know(person, private_fact)
	_set_scene_random_input(world, "ROOT_MEMORY_REVIEW")
	var data: Dictionary = {"world": world, "source": origin, "remote": remote, "private_fact": private_fact, "private_owners": people}
	_attach_dispatch(data)
	assert(_boot(data).ok)
	return data

func _memory_qualifications(world: RefCounted, root: String) -> Array:
	return _facts(world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("tag") == "memory_preserved" and fact.changes.get("original") == root)

func _memory_case(mode: String) -> void:
	var data: Dictionary = _memory_setup(mode == "shallow")
	var valid: bool = _open(data) and _evolve(data)
	var entry: Dictionary = {}
	for item: Dictionary in data.world.state.prayer_sources.situations.values():
		if item.content == "PRAYER_07" and item.domain == "DOMAIN-001": entry = item.duplicate(true)
	valid = valid and not entry.is_empty()
	var details: Dictionary = {"entry": entry}
	if valid:
		var risk: Dictionary = Store.entry(data.world.state.facts, entry.root)
		var experience: String = risk.changes.memory
		var fixed: String = World.canonical(risk)
		valid = _memory_qualifications(data.world, entry.root).is_empty() and LocalEventRules.actual_prayer(data.world.state, experience, data.world.history).is_empty()
		valid = valid and risk.changes.holders.size() == (1 if mode == "shallow" else 3) and _finish(data) and _open(data)
		var request: String = ""
		for id: String in data.world.state.prayer_system.offered:
			if data.world.state.prayer_system.requests[id].descriptor.source == entry.source: request = id
		valid = valid and not request.is_empty()
		var saved: String = data.turn.snapshot()
		valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved and World.canonical(Store.entry(data.world.state.facts, entry.root)) == fixed
		if mode == "shallow": valid = valid and not data.prayers.preview(data.turn, request, "deep").ok
		if mode != "expiry" and valid:
			_choose_prayer_seed(data, "success", entry.petitioner, entry.domain)
			var response: Dictionary = _response(data, request, mode)
			var qualifications: Array = _memory_qualifications(data.world, entry.root)
			valid = response.ok and qualifications.size() == (1 if mode == "shallow" else 3)
			for qualification: Dictionary in qualifications: valid = valid and not LocalEventRules.actual_prayer(data.world.state, qualification.id, data.world.history).is_empty()
			var faith: int = data.world.state.faith
			var repeated: Dictionary = _response(data, request, mode)
			valid = valid and not repeated.ok and data.world.state.faith == faith
			details.merge({"response": response, "qualificationCount": qualifications.size(), "duplicateRejected": not repeated.ok})
			if mode == "deep" and valid:
				var event: Dictionary = _memory_event(data)
				valid = not event.is_empty()
				if valid:
					var chosen: String = qualifications[0].id
					var selected: Dictionary = _submit(data, "resolve_event", {"event": event.id, "action": "B", "payload": {"qualification": chosen}})
					var current: int = 0
					for qualification: Dictionary in qualifications:
						if not Store.has(data.world.state.invalid_records, qualification.id): current += 1
					valid = selected.ok and Store.has(data.world.state.invalid_records, chosen) and current == 2 and LocalEventRules.current(data.world.state, experience, data.world.history)
					details.merge({"eventB": selected, "remainingQualifications": current, "selectedQualification": chosen})
		if mode == "expiry" and valid:
			while valid and int(data.world.state.turn) <= int(entry.due):
				valid = _evolve(data) and _finish(data)
				if int(data.world.state.turn) <= int(entry.due): valid = valid and _open(data)
			var lost: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("tag") == "memory_qualification_lost" and fact.changes.get("original") == entry.root)
			valid = valid and lost.size() == 3 and _memory_qualifications(data.world, entry.root).is_empty() and not data.world.state.prayer_sources.situations.has(entry.root)
			details["lostQualificationCount"] = lost.size()
		valid = valid and data.world.history.knows(data.world.state, data.remote, data.private_fact) and LocalEventRules.current(data.world.state, experience, data.world.history) and World.canonical(Store.entry(data.world.state.facts, entry.root)) == fixed
		for person: String in [entry.petitioner] + risk.changes.holders: valid = valid and data.world.history.knows(data.world.state, person, experience)
		for person: String in data.private_owners: valid = valid and data.world.history.knows(data.world.state, person, data.private_fact)
		details.merge({"fixedRisk": JSON.parse_string(fixed), "experience": experience, "privateKnowledgePreserved": data.world.history.knows(data.world.state, data.remote, data.private_fact)})
	_check("SM-" + mode.to_upper(), "Formal shared scene, actual qualification scope, deadline and stable save", valid, details)

func _memory_event(data: Dictionary) -> Dictionary:
	for attempt: int in 7:
		if data.turn.context.phase == "actions" and (not _evolve(data) or not _finish(data)): return {}
		if data.turn.context.phase == "between" and not _submit(data, "advance").ok: return {}
		for card: Dictionary in data.turn.context.events:
			var entry: Dictionary = data.world.state.event_system.cards.get(card.id, {})
			if not card.resolved and entry.get("descriptor", {}).get("content_id") == "EVENT_06" and entry.descriptor.domain == "DOMAIN-001": return card
		if not _submit(data, "finish_events").ok: return {}
	return {}
