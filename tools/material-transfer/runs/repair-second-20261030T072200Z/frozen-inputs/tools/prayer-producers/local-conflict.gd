extends "res://tools/prayer-producers/local-ties.gd"
## Four new representative cases plus the unchanged three rescue assertions.
const LocalEventRules = preload("res://src/game/event_rules.gd")
func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files(): _check("SLC-CATALOG", "Formal CSV load", false, {"errors": catalog.errors})
	else:
		_case(false); _case(true); _capacity()
		for content: String in ["PRAYER_02", "PRAYER_10", "PRAYER_03", "PRAYER_11"]: _conflict_case(content)
	Support.write_report(records, "lightweight_local_conflict_with_rescue_regression", [], ["Controlled initial RNG/check inputs and explicit exposure/relic preconditions; generated calls, situations and results are not injected.", "Component Turn/World save only. Full Session, cult compatibility, natural campaign reachability and balance remain downstream."])
	quit(0 if records.size() == 7 and records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _conflict_setup(content: String) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, 7919)
	var data: Dictionary = {"world": world, "source": world.state.domains["DOMAIN-001"].origin, "clue": "", "relic": ""}
	var people: Array = world.history.ids("active/DOMAIN-001"); people.sort()
	if content in ["PRAYER_02", "PRAYER_10"]:
		var unwanted: String = "judgment" if content == "PRAYER_02" else "recognition"
		for person: String in people:
			if unwanted in Store.entry(world.state.npcs, person).need_tags: assert(world.submit({"kind": "status", "npc": person, "status": "detained", "parents": [data.source]}))
	if content == "PRAYER_02":
		assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", data.source))
	if content == "PRAYER_10":
		# Choose a small initial population prerequisite using only the selector's
		# stable hash. Never execute/retry worlds or inject a dispute.
		var count: int = -1
		var shift_hash: int = int((str(world.randoms.generation.seed) + "/ROOT_DISPUTE/DOMAIN-001/1").sha256_text().substr(0, 12).hex_to_int())
		var active: Array = world.history.ids("active/DOMAIN-001"); active.sort()
		for added: int in range(1, 9):
			var predicted: Array = active.duplicate()
			for offset: int in added + 1: predicted.append("NPC-%08d" % (int(world.state.next_npc) + offset))
			predicted.sort()
			var shift: int = shift_hash % predicted.size()
			var first: String = ""
			for person: String in predicted.slice(shift) + predicted.slice(0, shift):
				if not Store.has(world.state.npcs, person):
					first = "recognition" if person == predicted.back() else "judgment"; break
				if "judgment" in Store.entry(world.state.npcs, person).need_tags: first = "judgment"; break
			if first == "judgment": count = added; break
		assert(count >= 1)
		for added: int in count: assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/order", "NPC_PROFILE_05", data.source))
	if content == "PRAYER_03":
		var person: String = people[0]
		data.clue = world.introduce_fact("exposure", "DOMAIN-001", person, [person], [data.source], {"public": true, "fixture": "existing real public exposure"}, [], ["DOMAIN-001/order"])
		assert(not str(data.clue).is_empty())
	if content == "PRAYER_11":
		var holder: String = people[0]
		data.relic = _given_relic(world, "DOMAIN-001", "RELIC_WITNESS_LENS")
		var item: Dictionary = Store.entry(world.state.relics, data.relic)
		item.placement = "carried"; item.holder = holder
		var auth: String = world.introduce_fact("relic_seize_authorized", "DOMAIN-001", "", [data.relic], [item.status_source], {"institution": "DOMAIN-001/order", "proof": {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": "DOMAIN-001", "target": data.relic, "status_source": item.status_source}}, [], [])
		var service: RefCounted = Relics.new(catalog, ISSUERS)
		assert(service.commit(world, {"type": "relics", "operation": "seize", "payload": {"relic": data.relic, "source": auth}}, null))
	var root: String = "ROOT_DISPUTE" if content in ["PRAYER_02", "PRAYER_10"] else ("ROOT_PURSUIT" if content == "PRAYER_03" else "ROOT_ACTUAL_SEIZURE")
	_set_scene_random_input(world, root)
	_attach_dispatch(data)
	assert(_boot(data).ok)
	return data

func _conflict_case(content: String) -> void:
	var data: Dictionary = _conflict_setup(content)
	var valid: bool = _open(data) and _evolve(data)
	var found: Dictionary = {}
	for entry: Dictionary in data.world.state.prayer_sources.situations.values():
		if entry.domain == "DOMAIN-001" and entry.content == content: found = entry.duplicate(true)
	valid = valid and not found.is_empty()
	var details: Dictionary = {"entry": found, "tick": Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last["DOMAIN-001"], {})}
	if valid:
		var original: String = World.canonical(Store.entry(data.world.state.facts, found.root))
		valid = _finish(data) and _open(data)
		var request: String = ""
		for id: String in data.world.state.prayer_system.offered:
			if data.world.state.prayer_system.requests[id].descriptor.source == found.source: request = id
		valid = valid and not request.is_empty()
		var saved: String = data.turn.snapshot()
		valid = valid and data.turn.restore(saved) and data.turn.snapshot() == saved
		if valid:
			var loyalty_before: int = Store.entry(data.world.state.npcs, found.petitioner).loyalty
			_choose_prayer_seed(data, "success", found.petitioner, found.domain)
			var response: Dictionary = _response(data, request, "deep" if content == "PRAYER_11" else "shallow")
			details["response"] = response
			valid = response.ok and original == World.canonical(Store.entry(data.world.state.facts, found.root)) and not data.world.state.prayer_sources.situations.has(found.root)
			var faith: int = data.world.state.faith
			var repeated: Dictionary = _response(data, request, "shallow")
			valid = valid and not repeated.ok and data.world.state.faith == faith
			if content == "PRAYER_02":
				var testimony: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") == "private_testimony")
				valid = valid and testimony.size() == 1 and Store.entry(data.world.state.npcs, found.petitioner).loyalty == mini(catalog.integer("attribute_max"), loyalty_before + 5)
				details["testimonyCount"] = testimony.size()
			if content == "PRAYER_03": valid = valid and not Store.has(data.world.state.invalid_records, data.clue) and Store.has(data.world.state.invalid_records, found.root)
			if content == "PRAYER_10":
				valid = valid and data.world.history.knows(data.world.state, found.petitioner, found.root) and not data.world.history.knows(data.world.state, found.other, found.root)
				var callbacks: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") == "future_callback" and fact.changes.get("event") == "EVENT_09")
				var event: Dictionary = LocalEventRules.descriptor(data.world.state, str(callbacks[0].id), catalog, data.world.history) if callbacks.size() == 1 else {}
				var usable: bool = not event.is_empty() and LocalEventRules.current(data.world.state, found.root, data.world.history) and LocalEventRules.current(data.world.state, str(event.facts.relation), data.world.history) and LocalEventRules.legal(data.world.state, event, "B", catalog, data.world.history).ok
				valid = valid and usable
				details["callbackArchiveUsable"] = usable
				details["callbackDescriptor"] = event
			if content == "PRAYER_11":
				var relic: Dictionary = Store.entry(data.world.state.relics, data.relic)
				var opportunities: Array = _facts(data.world, "prayer_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("request") == request and fact.changes.get("tag") == "relic_recovery_opportunity")
				valid = valid and relic.placement == "seized" and opportunities.size() == 1 and opportunities[0].changes.relic == data.relic
			details.merge({"originalRoot": JSON.parse_string(original), "repeat": repeated, "sameFaithAfterRepeat": faith == data.world.state.faith, "closed": not data.world.state.prayer_sources.situations.has(found.root)})
	_check("SLC-" + content, "Formal source to response, saved fixed facts and one result", valid, details)
