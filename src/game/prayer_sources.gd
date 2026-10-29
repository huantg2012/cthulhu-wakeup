extends RefCounted
## Lightweight rescue scenes. Background kinship is local to this scene;
## only admitted requests acquire a patient, deadline and persistent outcome.
const Store = preload("res://src/simulation/archive_store.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Producers = preload("res://src/game/prayer_producers.gd")
const ID: String = "prayer_sources"
const SCHEMA: int = 2
const ROOT: String = "ROOT_INJURY"
const CRISIS: String = "dying_condition"

static func version(content: RefCounted) -> String:
	return "sources/scenes2/" + Knowledge.version(content)

static func _fact(state: Dictionary, source: String) -> Dictionary:
	return Store.entry(state.get("facts", {}), source, {})

static func install(world: RefCounted) -> bool:
	if world.state.has(ID): return world.state[ID].get("version") == version(world.catalog)
	if world.state.turn != 0 or not world.state.has("event_system") or not world.state.has("prayer_system"): return false
	world.stage_collections([ID])
	world.state[ID] = {"schema": SCHEMA, "version": version(world.catalog), "open": {}, "cooldowns": {}}
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
	return [] if proposal.is_empty() else [{"root": ROOT, "legacy": false, "weight": world.catalog.integer("rescue_scene_weight"), "proposal": proposal, "snapshot": sample.duplicate(true)}]

static func _managed(world: RefCounted, owner: Object) -> bool:
	return owner != null and world._driver_allowed(owner) and world.transaction != null and not world.participant_read and world.state.has(ID)

static func commit(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	if not _managed(world, owner) or owner.context.phase != "evolution" or owner._owners.get("candidate_generation") != "events" or choice.get("snapshot") != Knowledge.capture(world, owner): return {"ok": false, "error": "Rescue scene requires the managed sampled Events handler"}
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

static func state_capacity_blocked(world: RefCounted, actors: Array) -> bool:
	# The next freeze orders older requests first. Only establish a fatal scene
	# if it can actually enter that next visible offer list.
	var waiting: Dictionary = {}
	var visible: int = int(world.state.turn) + 1
	for id: String in world.state.prayer_system.requests:
		var request: Dictionary = world.state.prayer_system.requests[id]
		if request.status == "open" and request.card.visible_turn <= visible and request.card.due_turn >= visible: waiting[id] = true
	for id: String in world.state.simulation.candidates:
		var card: Dictionary = world.state.simulation.candidates[id]
		var request: Dictionary = world.state.prayer_system.requests.get(id, {})
		if card.get("origin") == "prayer_situation" and request.get("status", "open") == "open" and card.visible_turn <= visible and card.due_turn >= visible: waiting[id] = true
	if waiting.size() >= world.catalog.integer("prayer_offer_limit"): return true
	if world.state.simulation.candidates.size() >= int(world.abstract_sim.parameters.pending_candidate_limit) or actors.size() > int(world.abstract_sim.parameters.candidate_actor_limit): return true
	if world.state.has("attention"):
		var result: Dictionary = world.attention.preview(world.state, {"focus": [], "people": actors, "members": world._prayer_members("PRAYER_01", actors), "identities": [], "source": ""})
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
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != version(content) or not ledger.get("open") is Dictionary or not ledger.get("cooldowns") is Dictionary: return ["Invalid rescue scene state"]
	var expected: Dictionary = trusted[ID].duplicate(true) if trusted.has(ID) else {"schema": SCHEMA, "version": version(content), "open": {}, "cooldowns": {}}
	for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		if fact.get("kind") == "rescue_scene_fixed":
			var entry: Dictionary = fact.changes
			var root: Dictionary = _fact(state, str(entry.get("root", "")))
			var situation: Dictionary = _fact(state, str(entry.get("source", "")))
			if expected.open.has(entry.get("root")) or root.get("kind") != CRISIS or root.changes.get("rule") != "kinship_rescue_scene" or root.changes.get("version") != version(content) or root.changes.get("patient") != entry.get("patient") or root.changes.get("petitioner") != entry.get("petitioner") or root.changes.get("due") != entry.get("due") or root.domain != entry.get("domain") or entry.due != fact.turn + int(content.tables.prayers.PRAYER_01.lifetime) or situation.get("kind") != "prayer_situation" or situation.changes.get("facts", {}).get("condition") != entry.root: return ["Rescue scene lost its fixed patient, source or deadline"]
			expected.open[entry.root] = entry.duplicate(true)
			expected.cooldowns[entry.domain] = int(fact.turn) + content.integer("rescue_scene_cooldown")
		elif fact.get("kind") == "rescue_scene_closed":
			var root: String = str(fact.changes.get("root", ""))
			if not expected.open.has(root) or str(Store.entry(state.invalid_records, root, "")) != fact.changes.get("result") or _fact(state, str(fact.changes.result)).is_empty(): return ["Rescue scene closed without its one actual result"]
			expected.open.erase(root)
	if expected != ledger: return ["Rescue scene state differs from its fixed lifecycle"]
	return []
