extends RefCounted
## Lightweight rescue scenes. Background kinship is local to this scene;
## only admitted requests acquire a patient, deadline and persistent outcome.
const Store = preload("res://src/simulation/archive_store.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Producers = preload("res://src/game/prayer_producers.gd")
const ID: String = "prayer_sources"
const SCHEMA: int = 3
const ROOT: String = "ROOT_INJURY"
const CRISIS: String = "dying_condition"
const ROOTS: Array[String] = [ROOT, "ROOT_DISPUTE", "ROOT_PURSUIT", "ROOT_ACTUAL_SEIZURE", "ROOT_MEMORY_REVIEW", "ROOT_COSMIC_OBSERVATION", "ROOT_CURRENT_PACT"]

static func version(content: RefCounted) -> String:
	return "sources/scenes6/" + Knowledge.version(content)

static func _fact(state: Dictionary, source: String) -> Dictionary:
	return Store.entry(state.get("facts", {}), source, {})

static func install(world: RefCounted) -> bool:
	if world.state.has(ID): return world.state[ID].get("version") == version(world.catalog)
	if world.state.turn != 0 or not world.state.has("event_system") or not world.state.has("prayer_system"): return false
	world.stage_collections([ID])
	world.state[ID] = {"schema": SCHEMA, "version": version(world.catalog), "open": {}, "cooldowns": {}, "situations": {}, "claims": {}, "anomalies": {}, "observations": {}}
	return true

static func _pair(world: RefCounted, state: Dictionary, domain: String, index: RefCounted) -> Dictionary:
	if int(state[ID].cooldowns.get(domain, -1)) > int(state.turn): return {}
	var people: Array = index.ids("active/" + domain); people.sort()
	var offset: int = int((str(state.prayer_knowledge.seed) + "/rescue/" + domain + "/" + str(state.simulation.cursors[domain].next_turn)).sha256_text().substr(0, 12).hex_to_int())
	for step: int in people.size():
		var petitioner: String = people[(offset + step) % people.size()]
		var npc: Dictionary = Store.entry(state.npcs, petitioner)
		if not state.institutions.get(str(npc.institution), {}).get("active", false): continue
		for next: int in range(1, people.size()):
			var patient: String = people[(offset + step + next) % people.size()]
			var busy: bool = false
			for entry: Dictionary in state[ID].open.values():
				if patient in [entry.patient, entry.petitioner] or petitioner in [entry.patient, entry.petitioner]: busy = true
			for crisis: Dictionary in state.prayer_system.crises.values():
				if crisis.get("descriptor", {}).get("subjects", {}).get("relative") == patient: busy = true
			if busy: continue
			# Do not invent kinship for a pair whose current explicit conflict is
			# already known. No new permanent relationship edge is manufactured.
			if not index.relation_head(petitioner, patient, ["rival", "hostile"]).is_empty() or not index.relation_head(patient, petitioner, ["rival", "hostile"]).is_empty(): continue
			var relative: Dictionary = index.relation_head(petitioner, patient, ["family"])
			if relative.is_empty(): relative = index.relation_head(patient, petitioner, ["family"])
			return {"root": ROOT, "domain": domain, "petitioner": petitioner, "patient": patient, "institution": npc.institution, "relation": str(relative.get("source", ""))}
	return {}

static func options(world: RefCounted, view: Dictionary, domain: String, sample: Dictionary) -> Array:
	if not view.has(ID): return []
	var proposal: Dictionary = _pair(world, view, domain, view._history_snapshot)
	var result: Array = [] if proposal.is_empty() else [{"root": ROOT, "legacy": false, "weight": world.catalog.integer("rescue_scene_weight"), "proposal": proposal, "snapshot": sample.duplicate(true)}]
	for root: String in ROOTS.slice(1):
		var scene: Dictionary = _situation(world, view, domain, root, view._history_snapshot)
		if not scene.is_empty(): result.append({"root": root, "legacy": false, "weight": world.catalog.integer("contract_scene_weight" if root == "ROOT_CURRENT_PACT" else ("exception_scene_weight" if root == "ROOT_COSMIC_OBSERVATION" else ("memory_scene_weight" if root == "ROOT_MEMORY_REVIEW" else "conflict_scene_weight"))), "proposal": scene, "snapshot": sample.duplicate(true)})
	return result

static func _managed(world: RefCounted, owner: Object) -> bool:
	return owner != null and world._driver_allowed(owner) and world.transaction != null and not world.participant_read and world.state.has(ID)

## A real paid route decision uses the same scene and request lifecycle. This
## explicit action contract never changes the coordinator's current phase.
static func route_context(world: RefCounted, plan: Dictionary, owner: Object) -> Dictionary:
	if not _managed(world, owner) or owner.context.phase != "actions" or not owner._participants.has("progression_routes") or not plan.operation in ["ROUTE_MEMORY_CIRCLE", "ROUTE_PACT_AGREEMENT"]: return {"ok": false}
	owner.route_action = plan.operation
	var sample: Dictionary = Knowledge.capture(world, owner)
	var memory: bool = plan.operation == "ROUTE_MEMORY_CIRCLE"
	var proposal: Dictionary = {"root": "ROOT_MEMORY_REVIEW" if memory else "ROOT_CURRENT_PACT", "domain": plan.domain, "petitioner": plan.npc, "other": "" if memory else plan.people[1], "content": "PRAYER_07" if memory else "PRAYER_06", "institution": plan.institution, "holders": plan.people.slice(1) if memory else [], "term": "preserve_record", "record": str(plan.payload.get("record", ""))}
	var result: Dictionary = _commit_situation(world, {"root": proposal.root, "proposal": proposal, "snapshot": sample, "route_action": plan.operation}, owner)
	owner.route_action = ""
	return result

static func commit(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	if not _managed(world, owner) or owner.context.phase != "evolution" or owner._owners.get("candidate_generation") != "events" or choice.get("snapshot") != Knowledge.capture(world, owner): return {"ok": false, "error": "Rescue scene requires the managed sampled Events handler"}
	if choice.get("root") != ROOT: return _commit_situation(world, choice, owner)
	var proposal: Dictionary = choice.get("proposal", {})
	var domain: String = str(proposal.get("domain", ""))
	if proposal != _pair(world, world.state, domain, world.history): return {"ok": true, "outcome": "source_changed"}
	var actors: Array = [proposal.petitioner, proposal.patient]
	if state_capacity_blocked(world, actors): return {"ok": true, "outcome": "capacity_blocked"}
	world.stage_current(); world.stage_collections([ID])
	var due: int = int(world.state.turn) + int(world.catalog.tables.prayers.PRAYER_01.lifetime)
	var patient: Dictionary = Store.entry(world.state.npcs, proposal.patient)
	var petitioner: Dictionary = Store.entry(world.state.npcs, proposal.petitioner)
	var root: String = world._record(CRISIS, domain, proposal.petitioner, actors, world._unique_sorted([patient.identity_source, patient.status_source, petitioner.identity_source, petitioner.status_source]), {"rule": "kinship_rescue_scene", "version": version(world.catalog), "patient": proposal.patient, "petitioner": proposal.petitioner, "relationship": "family", "due": due, "snapshot": choice.snapshot.duplicate(true)})
	var relation: String = root if str(proposal.relation).is_empty() else str(proposal.relation)
	var descriptor: Dictionary = {"content_id": "PRAYER_01", "domain": domain, "institution": proposal.institution, "actors": actors, "subjects": {"petitioner": proposal.petitioner, "relative": proposal.patient}, "facts": {"condition": root, "relation": relation}, "crisis": {"source": root, "due": due}}
	var result: Dictionary = Producers.materialize(world, descriptor, choice.snapshot, owner)
	if not result.get("ok", false): return result
	var preview: Dictionary = world.preview_prayer_fix(result.source, owner)
	if not preview.ok: return {"ok": false, "error": "Rescue admission changed after preflight: " + str(preview.outcome)}
	if not world.fix_prayer_source(result.source, owner): return {"ok": false, "error": "Admitted rescue could not be fixed"}
	var entry: Dictionary = {"root": root, "domain": domain, "petitioner": proposal.petitioner, "patient": proposal.patient, "due": due, "source": result.source}
	world._record("rescue_scene_fixed", domain, proposal.petitioner, actors, [root, result.source], entry)
	world.state[ID].open[root] = entry
	world.state[ID].cooldowns[domain] = int(world.state.turn) + world.catalog.integer("rescue_scene_cooldown")
	return {"ok": true, "outcome": "fixed", "source": result.source}

static func state_capacity_blocked(world: RefCounted, actors: Array, prayer: String = "PRAYER_01") -> bool:
	return capacity_blocked(world.state, actors, prayer, world.catalog, world.attention)

static func capacity_blocked(state: Dictionary, actors: Array, prayer: String, content: RefCounted, attention: RefCounted) -> bool:
	# The next freeze orders older requests first. Only establish a fatal scene
	# if it can actually enter that next visible offer list.
	var waiting: Dictionary = {}
	var visible: int = int(state.turn) + 1
	for id: String in state.prayer_system.requests:
		var request: Dictionary = state.prayer_system.requests[id]
		if request.status == "open" and request.card.visible_turn <= visible and request.card.due_turn >= visible: waiting[id] = true
	for id: String in state.simulation.candidates:
		var card: Dictionary = state.simulation.candidates[id]
		var request: Dictionary = state.prayer_system.requests.get(id, {})
		if card.get("origin") == "prayer_situation" and request.get("status", "open") == "open" and card.visible_turn <= visible and card.due_turn >= visible: waiting[id] = true
	if waiting.size() >= content.integer("prayer_offer_limit"): return true
	if state.simulation.candidates.size() >= int(attention.parameters.pending_candidate_limit) or actors.size() > int(attention.parameters.candidate_actor_limit): return true
	if state.has("attention"):
		var result: Dictionary = attention.preview(state, {"focus": [], "people": actors, "members": attention.prayer_members(prayer, actors), "identities": [], "source": ""})
		return not result.ok
	return false

static func _close(world: RefCounted, root: String, result: String, reason: String) -> bool:
	if not world.state[ID].open.has(root): return true
	world.stage_collections([ID])
	var entry: Dictionary = world.state[ID].open[root]
	world._record("rescue_scene_closed", entry.domain, entry.petitioner, [entry.patient], [root, result], {"root": root, "result": result, "reason": reason})
	world.state[ID].open.erase(root)
	return true

static func resolve(world: RefCounted, root: String, result: String, owner: Object) -> bool:
	if world.state.has(ID) and world.state[ID].situations.has(root):
		return _close_situation(world, root, result) if _managed(world, owner) else false
	if not world.state.has(ID) or not world.state[ID].open.has(root): return true
	if not _managed(world, owner): return false
	var cured: Dictionary = _fact(world.state, result)
	if cured.get("kind") != "prayer_fact" or cured.changes.get("tag") != "condition_cured" or cured.changes.get("original") != root: return false
	return _close(world, root, result, "resolved")

static func phase5(world: RefCounted, owner: Object) -> bool:
	if not world.state.has(ID): return true
	if not _managed(world, owner): return false
	for root: String in world.state[ID].open.keys():
		var entry: Dictionary = world.state[ID].open[root]
		var invalid: String = str(Store.entry(world.state.invalid_records, root, ""))
		if not invalid.is_empty():
			if not _close(world, root, invalid, "resolved"): return false
			continue
		if int(entry.due) > int(world.state.turn): continue
		var patient: Dictionary = Store.entry(world.state.npcs, entry.patient)
		var result: String = str(patient.status_source)
		if patient.status != "dead":
			result = world._record("rescue_scene_due", entry.domain, entry.petitioner, [entry.patient], [root], {"root": root, "due": entry.due})
			if not world.submit({"kind": "status", "npc": entry.patient, "status": "dead", "parents": [root, result]}, owner): return false
		world.stage_collections(["invalid_records"]); Store.put(world.state.invalid_records, root, result)
		if not _close(world, root, result, "expired"): return false
	return true

static func knowledge_allowed(state: Dictionary, owner: String, source: String, institution: bool = false, first: int = 1, _shares: Dictionary = {}) -> bool:
	var scene: Dictionary = _fact(state, source)
	if scene.get("kind") != CRISIS or scene.changes.get("rule") != "kinship_rescue_scene": return true
	if not institution: return owner in [scene.changes.get("petitioner"), scene.changes.get("patient")]
	for number: int in range(first, int(state.next_fact)):
		var shared: Dictionary = _fact(state, "FACT-%08d" % number)
		if shared.get("kind") == "record_shared" and shared.changes.get("institution") == owner and shared.changes.get("source") == source and shared.actor in [scene.changes.petitioner, scene.changes.patient] and source in shared.causal_parents: return true
	return false

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, _index: RefCounted = null) -> Array[String]:
	if not state.has(ID):
		if trusted.has(ID): return ["Rescue scenes disappeared"]
		return []
	var ledger: Variant = state[ID]
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != version(content) or not ledger.get("open") is Dictionary or not ledger.get("cooldowns") is Dictionary or not ledger.get("situations") is Dictionary or not ledger.get("claims") is Dictionary or not ledger.get("anomalies") is Dictionary or not ledger.get("observations") is Dictionary: return ["Invalid rescue scene state"]
	var expected: Dictionary = trusted[ID].duplicate(true) if trusted.has(ID) else {"schema": SCHEMA, "version": version(content), "open": {}, "cooldowns": {}, "situations": {}, "claims": {}, "anomalies": {}, "observations": {}}
	for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		if fact.get("kind") == "rescue_scene_fixed":
			var entry: Dictionary = fact.changes
			var root: Dictionary = _fact(state, str(entry.get("root", "")))
			var situation: Dictionary = _fact(state, str(entry.get("source", "")))
			if expected.open.has(entry.get("root")) or root.get("kind") != CRISIS or root.changes.get("rule") != "kinship_rescue_scene" or root.changes.get("version") != version(content) or root.changes.get("patient") != entry.get("patient") or root.changes.get("petitioner") != entry.get("petitioner") or root.changes.get("due") != entry.get("due") or root.domain != entry.get("domain") or entry.due != fact.turn + int(content.tables.prayers.PRAYER_01.lifetime) or situation.get("kind") != "prayer_situation" or situation.changes.get("facts", {}).get("condition") != entry.root: return ["Rescue scene lost its fixed patient, source or deadline"]
			expected.open[entry.root] = entry.duplicate(true)
			expected.cooldowns[entry.domain] = int(fact.turn) + content.integer("rescue_scene_cooldown")
		elif fact.get("kind") == "conflict_scene_fixed":
			var entry: Dictionary = fact.changes
			var root: Dictionary = _fact(state, str(entry.get("root", "")))
			var source: Dictionary = _fact(state, str(entry.get("source", "")))
			if expected.situations.has(entry.get("root")) or root.changes.get("scene_rule") != entry.get("kind") or root.changes.get("snapshot", {}).get("turn") != fact.turn or source.get("kind") != "prayer_situation" or source.changes.get("subjects", {}).get("petitioner") != entry.get("petitioner") or root.changes.get("petitioner") != entry.get("petitioner") or root.domain != entry.get("domain") or entry.get("due") != fact.turn + int(content.tables.prayers[entry.content].lifetime): return ["Conflict scene lost its fixed origin or window"]
			expected.situations[entry.root] = entry.duplicate(true)
			expected.cooldowns[entry.kind + "/" + entry.domain] = fact.turn + content.integer("contract_scene_cooldown" if entry.content == "PRAYER_06" else ("memory_scene_cooldown" if entry.content == "PRAYER_07" else "conflict_scene_cooldown"))
			if entry.content == "PRAYER_11":
				if expected.claims.has(root.changes.status_source): return ["Seizure generated duplicate claim"]
				expected.claims[root.changes.status_source] = entry.root
		elif fact.get("kind") == "anomaly_observation_fixed":
			var entry: Dictionary = fact.changes.entry
			var observation: Dictionary = _fact(state, entry.root)
			var anomaly: Dictionary = _fact(state, observation.changes.get("exception", ""))
			if observation.get("kind") != "law_observation" or observation.changes.get("observer") != entry.petitioner or observation.changes.get("node") != fact.changes.get("node") or anomaly.get("kind") != "exception" or anomaly.domain != entry.domain or entry.due != fact.turn + int(content.tables.prayers.PRAYER_12.lifetime): return ["Anomaly observation lost its original observer, node or exception"]
			var previous: String = str(expected.anomalies.get(entry.domain, ""))
			if previous != anomaly.id: expected.observations.erase(previous)
			expected.anomalies[entry.domain] = anomaly.id
			if not expected.observations.has(anomaly.id): expected.observations[anomaly.id] = {}
			expected.observations[anomaly.id][fact.changes.node] = observation.id
			expected.situations[entry.root] = entry.duplicate(true)
			expected.cooldowns[entry.kind + "/" + entry.domain] = fact.turn + content.integer("exception_scene_cooldown")
		elif fact.get("kind") == "conflict_scene_closed":
			var root: String = str(fact.changes.get("root", ""))
			if not expected.situations.has(root) or _fact(state, str(fact.changes.get("result", ""))).is_empty(): return ["Conflict scene closed without a result"]
			expected.situations.erase(root)
		elif fact.get("kind") == "rescue_scene_closed":
			var root: String = str(fact.changes.get("root", ""))
			if not expected.open.has(root) or str(Store.entry(state.invalid_records, root, "")) != fact.changes.get("result") or _fact(state, str(fact.changes.result)).is_empty(): return ["Rescue scene closed without its one actual result"]
			expected.open.erase(root)
	if expected != ledger: return ["Rescue scene state differs from its fixed lifecycle"]
	return []

static func _situation(world: RefCounted, state: Dictionary, domain: String, root: String, index: RefCounted) -> Dictionary:
	if root == "ROOT_COSMIC_OBSERVATION": return _exception_proposal(world, state, domain, index)
	if int(state[ID].cooldowns.get(root + "/" + domain, -1)) > int(state.turn): return {}
	for entry: Dictionary in state[ID].situations.values():
		if entry.domain == domain and entry.kind == root: return {}
	var people: Array = index.ids("active/" + domain); people.sort()
	if not people.is_empty():
		var shift: int = int((str(state.prayer_knowledge.seed) + "/" + root + "/" + domain + "/" + str(state.simulation.cursors[domain].next_turn)).sha256_text().substr(0, 12).hex_to_int()) % people.size()
		people = people.slice(shift) + people.slice(0, shift)
	if root == "ROOT_CURRENT_PACT":
		for person: String in people:
			var npc: Dictionary = Store.entry(state.npcs, person)
			if not state.institutions.get(str(npc.institution), {}).get("active", false): continue
			for other: String in people:
				if other != person: return {"root": root, "domain": domain, "petitioner": person, "other": other, "content": "PRAYER_06", "institution": npc.institution, "term": world.catalog.tables.prayer_root_rules[root].rule}
		return {}
	if root == "ROOT_MEMORY_REVIEW":
		for person: String in people:
			var npc: Dictionary = Store.entry(state.npcs, person)
			if not state.institutions.get(str(npc.institution), {}).get("active", false): continue
			var others: Array = people.filter(func(id: String) -> bool: return id != person)
			if others.is_empty(): continue
			var holders: Array = others.slice(0, 3) if others.size() >= 3 else others.slice(0, 1)
			if holders.size() == 3 and state.has("attention"):
				var admitted: Dictionary = world.attention.preview(state, {"focus": [], "people": [person] + holders, "members": [], "identities": [], "source": ""})
				if not admitted.ok: holders = holders.slice(0, 1)
			return {"root": root, "domain": domain, "petitioner": person, "other": "", "content": "PRAYER_07", "institution": npc.institution, "basis": "", "relation": "", "holders": holders}
		return {}
	for person: String in people:
		var npc: Dictionary = Store.entry(state.npcs, person)
		if not state.institutions.get(str(npc.institution), {}).get("active", false): continue
		if root == "ROOT_ACTUAL_SEIZURE":
			for id: String in Store.keys(state.relics):
				var relic: Dictionary = Store.entry(state.relics, id)
				var seized: Dictionary = _fact(state, str(relic.get("status_source", "")))
				if relic.domain == domain and relic.placement == "seized" and seized.get("kind") == "relic_seize" and seized.changes.get("previous_holder") == person and not state[ID].claims.has(seized.id):
					return {"root": root, "domain": domain, "petitioner": person, "other": "", "content": "PRAYER_11", "institution": relic.captor, "relic": id, "basis": seized.id, "relation": ""}
			continue
		var need: String = "recognition" if "recognition" in npc.need_tags else ("judgment" if "judgment" in npc.need_tags else "")
		if root == "ROOT_DISPUTE" and (need.is_empty() or int(state.domains[domain].stability) >= world.catalog.integer("attribute_max")): continue
		var clue: String = ""
		if root == "ROOT_PURSUIT":
			for source: String in index.ids("exposed/" + domain + "/order/" + domain + "/" + person):
				if not Store.has(state.invalid_records, source): clue = source; break
			if clue.is_empty(): continue
		for other: String in people:
			if other == person: continue
			var opponent: Dictionary = Store.entry(state.npcs, other)
			if root == "ROOT_PURSUIT" and (opponent.institution != domain + "/order" or not "investigator" in opponent.role_tags): continue
			var relation: Dictionary = index.relation_head(person, other, ["rival", "hostile"])
			if relation.is_empty(): relation = index.relation_head(other, person, ["rival", "hostile"])
			var secret_other: String = ""
			if root == "ROOT_DISPUTE" and need == "judgment":
				for third: String in people:
					if third in [person, other] or not index.relation_between(other, third, []).is_empty() or not index.relation_between(third, other, []).is_empty(): continue
					secret_other = third; break
				if secret_other.is_empty(): continue
			return {"root": root, "domain": domain, "petitioner": person, "other": other, "content": ("PRAYER_02" if need == "recognition" else "PRAYER_10") if root == "ROOT_DISPUTE" else "PRAYER_03", "institution": npc.institution if root == "ROOT_DISPUTE" else opponent.institution, "basis": clue, "relation": str(relation.get("source", "")), "relation_other": secret_other}
	return {}

static func _commit_situation(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	if choice.get("root") == "ROOT_COSMIC_OBSERVATION": return _commit_exception(world, choice, owner)
	var proposal: Dictionary = choice.get("proposal", {})
	var route: bool = choice.get("route_action", "") in ["ROUTE_MEMORY_CIRCLE", "ROUTE_PACT_AGREEMENT"] and owner.route_action == choice.route_action and owner.context.phase == "actions" and choice.snapshot == Knowledge.capture(world, owner)
	if not str(choice.get("root", "")) in ROOTS or (not route and proposal != _situation(world, world.state, str(proposal.get("domain", "")), str(choice.root), world.history)): return {"ok": true, "outcome": "source_changed"}
	var actors: Array = [proposal.petitioner] + ([] if str(proposal.other).is_empty() else [proposal.other])
	if proposal.content == "PRAYER_10": actors.append(proposal.relation_other)
	if proposal.content == "PRAYER_07": actors.append_array(proposal.holders)
	if state_capacity_blocked(world, actors, proposal.content): return {"ok": true, "outcome": "capacity_blocked"}
	world.stage_current(); world.stage_collections([ID])
	var due: int = int(world.state.turn) + int(world.catalog.tables.prayers[proposal.content].lifetime)
	var details: Dictionary = {"scene_rule": proposal.root, "petitioner": proposal.petitioner, "subject": proposal.petitioner, "institution": proposal.institution, "snapshot": choice.snapshot.duplicate(true), "due": due}
	var parents: Array = [Store.entry(world.state.npcs, proposal.petitioner).identity_source]
	var subjects: Dictionary = {"petitioner": proposal.petitioner}
	var facts: Dictionary = {}; var crisis: Dictionary = {}
	var kind: String = "contract_obligation" if proposal.root == "ROOT_CURRENT_PACT" else ("memory_at_risk" if proposal.root == "ROOT_MEMORY_REVIEW" else ("faction_conflict" if proposal.root == "ROOT_DISPUTE" else ("pursuit_condition" if proposal.root == "ROOT_PURSUIT" else "message")))
	if proposal.root == "ROOT_CURRENT_PACT":
		details.merge({"obligor": proposal.petitioner, "counterparty": proposal.other, "term": proposal.term})
		if route:
			details["record"] = proposal.record; details["route_operation"] = choice.route_action; parents.append(proposal.record)
		parents.append(Store.entry(world.state.npcs, proposal.other).identity_source)
		subjects.counterparty = proposal.other
	elif proposal.root == "ROOT_MEMORY_REVIEW":
		var experience: String = world._record("shared_observation", proposal.domain, proposal.petitioner, actors, actors.map(func(id: String) -> String: return Store.entry(world.state.npcs, id).identity_source), {"participants": actors.duplicate(), "background": "shared_uncertain_recollection", "record": proposal.get("record", "")})
		for person: String in actors: world._know(person, experience)
		parents.append(experience)
		details.merge({"memory": experience, "holders": proposal.holders.duplicate()})
		subjects.memory_people = proposal.holders.duplicate()
	elif proposal.root == "ROOT_DISPUTE":
		details.merge({"parties": [proposal.petitioner, proposal.other], "reason": "contested_interpretation", "default_stance": "existing_order", "selected_need": "recognition" if proposal.content == "PRAYER_02" else "judgment", "secret": {"a": proposal.other, "b": proposal.relation_other, "kind": "concealed_agreement"} if proposal.content == "PRAYER_10" else {}})
		subjects["rival" if proposal.content == "PRAYER_02" else "opponent"] = proposal.other
		if proposal.content == "PRAYER_10": subjects.relation_other = proposal.relation_other
	elif proposal.root == "ROOT_PURSUIT":
		details.merge({"pursuer": proposal.other, "clue": proposal.basis, "relation": proposal.relation}); parents.append(proposal.basis); subjects.pursuer = proposal.other
	else:
		details.merge({"relic": proposal.relic, "status_source": proposal.basis}); parents.append(proposal.basis); subjects.relic = proposal.relic; actors.append(proposal.relic)
	var root: String = world._record(kind, proposal.domain, proposal.petitioner, actors, world._unique_sorted(parents), details)
	if proposal.root == "ROOT_CURRENT_PACT":
		facts = {"contract": root}
		for person: String in actors: world._know(person, root)
	elif proposal.root == "ROOT_MEMORY_REVIEW":
		var ties: Array = []
		for person: String in proposal.holders: ties.append(root)
		facts = {"memory": root, "relations": ties}
	elif proposal.root == "ROOT_DISPUTE": facts = {"conflict": root, "relation": root if proposal.content == "PRAYER_10" or str(proposal.relation).is_empty() else proposal.relation}
	elif proposal.root == "ROOT_PURSUIT": facts = {"pursuit": root}
	else: facts = {"claim": root}; actors.erase(proposal.relic)
	if proposal.content != "PRAYER_11": crisis = {"source": root, "due": due}
	var descriptor: Dictionary = {"content_id": proposal.content, "domain": proposal.domain, "institution": proposal.institution, "actors": actors, "subjects": subjects, "facts": facts, "crisis": crisis}
	var result: Dictionary = Producers.materialize(world, descriptor, choice.snapshot, owner)
	if not result.get("ok", false): return result
	if not world.fix_prayer_source(result.source, owner): return {"ok": false, "error": "Admitted conflict scene could not be fixed"}
	var entry: Dictionary = {"root": root, "domain": proposal.domain, "petitioner": proposal.petitioner, "other": proposal.other, "content": proposal.content, "kind": proposal.root, "due": due, "source": result.source}
	world._record("conflict_scene_fixed", proposal.domain, proposal.petitioner, descriptor.actors, [root, result.source], entry)
	world.state[ID].situations[root] = entry
	world.state[ID].cooldowns[proposal.root + "/" + proposal.domain] = int(world.state.turn) + world.catalog.integer("contract_scene_cooldown" if proposal.content == "PRAYER_06" else ("memory_scene_cooldown" if proposal.content == "PRAYER_07" else "conflict_scene_cooldown"))
	if proposal.content == "PRAYER_11": world.state[ID].claims[proposal.basis] = root
	return {"ok": true, "outcome": "fixed", "source": result.source}

static func _close_situation(world: RefCounted, root: String, result: String) -> bool:
	if not world.state.get(ID, {}).get("situations", {}).has(root): return true
	world.stage_collections([ID])
	var entry: Dictionary = world.state[ID].situations[root]
	world._record("conflict_scene_closed", entry.domain, entry.petitioner, [], [root, result], {"root": root, "result": result})
	world.state[ID].situations.erase(root)
	return true

static func finish_deadlines(world: RefCounted) -> bool:
	if not world.state.has(ID): return true
	for root: String in world.state[ID].situations.keys():
		var entry: Dictionary = world.state[ID].situations[root]
		if int(entry.due) > int(world.state.turn): continue
		var expired: String = world._record("conflict_scene_due", entry.domain, entry.petitioner, [], [root], {"root": root, "due": entry.due})
		if not _close_situation(world, root, expired): return false
	return true

static func _exception_proposal(world: RefCounted, state: Dictionary, domain: String, index: RefCounted) -> Dictionary:
	if state.domains[domain].profile != "CIV_07" or int(state[ID].cooldowns.get("ROOT_COSMIC_OBSERVATION/" + domain, -1)) > int(state.turn): return {}
	for entry: Dictionary in state[ID].situations.values():
		if entry.domain == domain and entry.content == "PRAYER_12": return {}
	var anomaly: String = str(state[ID].anomalies.get(domain, ""))
	if Store.has(state.invalid_records, anomaly): anomaly = ""
	var offices: Array = state.domains[domain].institutions.duplicate(); offices.sort()
	var recorded: Dictionary = state[ID].observations.get(anomaly, {})
	offices.sort_custom(func(a: String, b: String) -> bool: return (not recorded.has(a)) if recorded.has(a) != recorded.has(b) else a < b)
	for node: String in offices:
		if not state.institutions[node].active: continue
		var retained: bool = false
		if not anomaly.is_empty():
			for source: String in index.event_record_heads(node, "", "exception/" + anomaly):
				var observation: Dictionary = Anchors.exception_observation(state, source, index)
				var material: Dictionary = Anchors._prayer_record(state, source, index)
				if not observation.is_empty() and observation.node == node and material.institution == node: retained = true; break
		if retained: continue
		var person: String = ""
		for id: String in index.ids("active/" + domain):
			if Store.entry(state.npcs, id).institution == node: person = id; break
		var profile: String = ""
		if person.is_empty():
			var profiles: Array = world.catalog.tables.npc_profiles.keys(); profiles.sort()
			for id: String in profiles:
				if world._profile_legal(world.catalog.tables.npc_profiles[id], domain, node): profile = id; break
			if profile.is_empty() or int(state.domains[domain].unnamed_nonfollowers) <= 0: continue
		var other: String = ""
		for connected: String in state.institutions[node].links:
			if connected != node and state.institutions.get(connected, {}).get("active", false): other = connected; break
		return {"root": "ROOT_COSMIC_OBSERVATION", "content_id": "PRAYER_12", "domain": domain, "institution": node, "petitioner": person, "profile": profile, "exception": anomaly, "other_institution": other, "source_ids": world._unique_sorted([state.domains[domain].origin, state.institutions[node].source]), "once_key": "observation/" + domain + "/" + node + "/" + str(state.simulation.cursors[domain].next_turn)}
	return {}

static func _commit_exception(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	var proposal: Dictionary = choice.proposal
	if proposal != _exception_proposal(world, world.state, proposal.domain, world.history): return {"ok": true, "outcome": "source_changed"}
	var person: String = proposal.petitioner
	if state_capacity_blocked(world, [] if person.is_empty() else [person], "PRAYER_12"): return {"ok": true, "outcome": "capacity_blocked"}
	var token: String = ""; var nomination: String = ""
	if person.is_empty():
		var named: Dictionary = world.nominate_prayer_contact(proposal, choice.snapshot, owner)
		if not named.get("ok", false) or named.get("outcome") != "nominated": return named
		person = named.person; token = named.token; nomination = named.nomination
	world.stage_current(); world.stage_collections([ID])
	var parents: Array = proposal.source_ids.duplicate()
	if not nomination.is_empty(): parents.append(nomination)
	var anomaly: String = proposal.exception
	var changes: Dictionary = {"scene_rule": "ROOT_COSMIC_OBSERVATION", "petitioner": person, "nomination": nomination, "snapshot": choice.snapshot.duplicate(true)}
	if anomaly.is_empty(): anomaly = world._record("exception", proposal.domain, person, [person], parents, changes)
	var details: Dictionary = changes.duplicate(true)
	details.merge({"exception": anomaly, "observer": person, "node": proposal.institution})
	var observation: String = world._record("law_observation", proposal.domain, person, [person], world._unique_sorted(parents + [anomaly]), details)
	world._know(person, observation); world._know(person, anomaly); world._institution_know(proposal.institution, anomaly)
	var subjects: Dictionary = {"petitioner": person}
	if not str(proposal.other_institution).is_empty(): subjects.other_institution = proposal.other_institution
	var descriptor: Dictionary = {"content_id": "PRAYER_12", "domain": proposal.domain, "institution": proposal.institution, "actors": [person], "subjects": subjects, "facts": {"exception": anomaly, "observation": observation}, "crisis": {}}
	var result: Dictionary = Producers.materialize(world, descriptor, choice.snapshot, owner)
	if not result.get("ok", false): return result
	if not world.fix_prayer_source(result.source, owner, token): return {"ok": false, "error": "Admitted anomaly observation could not be fixed"}
	var due: int = int(world.state.turn) + int(world.catalog.tables.prayers.PRAYER_12.lifetime)
	var entry: Dictionary = {"root": observation, "domain": proposal.domain, "petitioner": person, "other": "", "content": "PRAYER_12", "kind": "ROOT_COSMIC_OBSERVATION", "due": due, "source": result.source}
	world._record("anomaly_observation_fixed", proposal.domain, person, [person], [anomaly, observation, result.source], {"entry": entry, "node": proposal.institution})
	var previous: String = str(world.state[ID].anomalies.get(proposal.domain, ""))
	if previous != anomaly: world.state[ID].observations.erase(previous)
	world.state[ID].anomalies[proposal.domain] = anomaly
	if not world.state[ID].observations.has(anomaly): world.state[ID].observations[anomaly] = {}
	world.state[ID].observations[anomaly][proposal.institution] = observation
	world.state[ID].situations[observation] = entry
	world.state[ID].cooldowns["ROOT_COSMIC_OBSERVATION/" + proposal.domain] = int(world.state.turn) + world.catalog.integer("exception_scene_cooldown")
	return {"ok": true, "outcome": "fixed", "source": result.source}
