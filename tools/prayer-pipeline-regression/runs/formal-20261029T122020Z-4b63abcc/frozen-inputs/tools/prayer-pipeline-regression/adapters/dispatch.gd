extends "res://tools/prayer-producers/dispatch_regression.gd"
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")
var ppr_kinship_prerequisites: Array = []
var ppr_notice_prerequisites: Array = []
var ppr_notice_steps: Array = []

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

func _dispatch_native(seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, seed_value)
	return {"world": world, "source": world.state.domains["DOMAIN-001"].origin}

func _write_report() -> void:
	Support.write_report(records, "current_dispatch_component_regression", ["Standalone source-backed identities and real graph relationship prerequisites.", {"kinshipInputs": ppr_kinship_prerequisites, "noticeInputs": ppr_notice_prerequisites, "noticeStepArtifacts": ppr_notice_steps}], ["Prepared current sources; no natural root or complete Session claim.", "Automatic notice positives retain the original six seeds and twelve rounds; diagnostics do not prove their failure has been repaired."])
	quit(0 if records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _local_people(world: RefCounted) -> Array:
	return Support.ordered_people(world)

func _given_relation(data: Dictionary, first: String, second: String, kind: String) -> String:
	return Support.existing_relation(data.world, first, second, kind)

func _independent_same_petitioner() -> void:
	var family: RefCounted = Support.family_world(catalog, "branch")
	var data: Dictionary = {"world": family, "source": family.state.domains["DOMAIN-001"].origin}
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
	var family: RefCounted = Support.family_world(catalog, "matching")
	var data: Dictionary = {"world": family, "source": family.state.domains["DOMAIN-001"].origin}
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
	var world: RefCounted = data.world
	var originals: Array = _local_people(world)
	var chosen: Dictionary = Support.pair(world, ["family"] if variant == "wrong_relation" else ["support", "cooperation"], variant == "same_institution" if variant != "wrong_relation" else null)
	assert(not chosen.is_empty())
	data.sender = chosen.a; data.recipient = chosen.b
	var origin: String = world.state.domains["DOMAIN-001"].origin
	if variant in ["no_relation", "cross_domain"]:
		var domain: String = "DOMAIN-002" if variant == "cross_domain" else "DOMAIN-001"
		data.recipient = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin))
	var passage_competitor: String = ""
	if variant == "same_institution":
		passage_competitor = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/propagation", "NPC_PROFILE_03", origin))
	for person: String in originals:
		if person not in [data.sender, data.recipient]: assert(world.submit({"kind": "status", "npc": person, "status": "detained", "parents": [origin]}))
	if variant in ["dead", "detained", "missing"]: assert(world.submit({"kind": "status", "npc": data.recipient, "status": variant, "parents": [origin]}))
	if variant == "no_route":
		var left: String = Store.entry(world.state.npcs, data.sender).institution
		var right: String = Store.entry(world.state.npcs, data.recipient).institution
		world.state.institutions[left].links.erase(right)
	var contact: String = _given_fact(data, "devotion_contact", data.sender, [data.sender], {"subject": data.sender, "institution": Store.entry(world.state.npcs, data.sender).institution})
	if variant == "anomaly_only": _given_fact(data, "exposure", data.sender, [data.sender], {"public": false, "unexplained": true})
	var accepted: Dictionary = ISSUERS.duplicate(true); accepted.merge(Events.issuer_capability(catalog))
	var prerequisite_economy: RefCounted = Economy.new(catalog, accepted)
	assert(prerequisite_economy.initialize(world))
	var available: int = int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers)
	assert(available > 0)
	if available > 1: assert(world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": available - 1, "parents": [origin]}))
	var qualification: String = _qualification(data, "dream", data.sender, data.sender, "DOMAIN-001", {"contact": contact})
	data.dream = {"npc": data.sender, "source": contact, "qualification": qualification}
	data["ppr_notice_input"] = {"seed": seed_value, "mode": mode, "variant": variant, "sender": data.sender, "recipient": data.recipient, "selectedSource": chosen.source}
	_attach_dispatch(data)
	assert(world.state.domains["DOMAIN-001"].unnamed_nonfollowers == 0)
	ppr_notice_prerequisites.append({"seed": seed_value, "mode": mode, "variant": variant, "sender": data.sender, "recipient": data.recipient, "selectedActualSource": chosen.source, "selectedActualKind": chosen.kind, "sameInstitutionRequired": variant == "same_institution", "independentPassageCompetitor": passage_competitor, "qualificationBeforeBootstrap": qualification, "anonymousAfterBootstrap": world.state.domains["DOMAIN-001"].unnamed_nonfollowers})
	assert(_open(data))
	if variant not in ["unidentified", "anomaly_only"]:
		assert(_seed(data, "POWER_DREAM", "success", data.dream) > 0)
		var response: Dictionary = _power(data, "POWER_DREAM", data.dream)
		assert(response.ok and Knowledge.known(world.state, data.sender).get("known", false))
	if mode == "background":
		assert(_submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}).ok)
		assert(_evolve(data) and _finish(data) and _open(data))
	return data

func _notice_person(view: Dictionary, person: String) -> Dictionary:
	var npc: Dictionary = Store.entry(view.npcs, person, {})
	var result: Dictionary = {"id": person}
	for field: String in ["profile", "domain", "institution", "status", "bound_member", "role_tags", "need_tags"]:
		if npc.has(field): result[field] = npc[field]
	result["knowledge"] = Knowledge.known(view, person)
	return result

func _notice_observation(data: Dictionary, view: Dictionary, index: RefCounted) -> Dictionary:
	var sender: String = data.sender; var recipient: String = data.recipient
	var active: Array = index.ids("active/DOMAIN-001"); active.sort()
	var candidates: Array = []
	for person: String in active: candidates.append(_notice_person(view, person))
	var office: Dictionary = view.institutions.get(str(Store.entry(view.npcs, sender, {}).get("institution", "")), {})
	var route: Dictionary = {}
	for field: String in ["id", "domain", "active", "links", "source"]:
		if office.has(field): route[field] = office[field]
	return {"turn": view.turn, "sender": _notice_person(view, sender), "recipient": _notice_person(view, recipient), "activePeople": candidates,
		"forwardHead": index.relation_head(sender, recipient, ["support", "cooperation"]),
		"reverseHead": index.relation_head(recipient, sender, ["support", "cooperation"]),
		"exactForwardHistory": index.relation(sender, recipient, data.ppr_notice_input.selectedSource),
		"exactReverseHistory": index.relation(recipient, sender, data.ppr_notice_input.selectedSource),
		"currentPair": index.relation_between(sender, recipient, ["support", "cooperation"]),
		"senderInstitution": route,
		"position": view.prayer_dispatch.positions["DOMAIN-001"].duplicate(true), "cursor": view.simulation.cursors["DOMAIN-001"].duplicate(true)}

func _submit(data: Dictionary, op: String, payload: Dictionary = {}) -> Dictionary:
	if not data.has("ppr_notice_input") or op != "advance" or data.turn.context.phase != "evolution": return super._submit(data, op, payload)
	# Pure reads at the actual pre-advance boundary. This observer neither calls
	# a producer nor supplies a selection, proof, random value or World command.
	var world: RefCounted = data.world
	var frozen: Dictionary = world._evolution_snapshot()
	var before: Dictionary = _notice_observation(data, frozen, frozen._history_snapshot)
	var current_before: Dictionary = _notice_observation(data, world.state, world.history)
	var result: Dictionary = super._submit(data, op, payload)
	var last: String = str(world.state.prayer_dispatch.last.get("DOMAIN-001", ""))
	var record: Dictionary = {"fixture": data.ppr_notice_input.duplicate(true), "preAdvancePhase": "evolution", "frozenBeforeAdvance": before,
		"currentBeforeAdvance": current_before, "response": result.duplicate(true),
		"actualDispatchTick": Store.entry(world.state.facts, last, {}).duplicate(true),
		"currentAfterAdvance": _notice_observation(data, world.state, world.history),
		"received": _facts(world, "deity_identity_received"),
		"scope": "Read-only actual advance diagnostics, including the unchanged dispatch tick's notice_scan/eligible/choice/new_outcome/position. The pre-advance frozen observation is separately labelled, not a submitted sampling credential."}
	var path: String = scratch.path_join("notice-step-%04d.json" % ppr_notice_steps.size())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null); file.store_string(JSON.stringify(record, "\t", true, true) + "\n"); file.close()
	ppr_notice_steps.append({"path": path, "sha256": FileAccess.get_sha256(path), "fixture": data.ppr_notice_input.duplicate(true), "turn": before.turn, "advanceOk": result.ok})
	return result

func _rescue_prerequisite(data: Dictionary, petitioner: String, patient: String, due: int, delayed: bool = false, empty_crisis: bool = false) -> Dictionary:
	var result: Dictionary = super._rescue_prerequisite(data, petitioner, patient, due, delayed, empty_crisis)
	result["explicitPrerequisite"] = {"seed": str(data.world.randoms.generation.seed), "patient": patient, "petitioner": petitioner, "source": Support.existing_relation(data.world, petitioner, patient, "family"), "scope": "Actual initial graph kinship and explicit existing injury consumer input; no natural injury producer claim."}
	ppr_kinship_prerequisites.append(result.explicitPrerequisite.duplicate(true))
	return result
