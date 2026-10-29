extends "res://tools/prayer-producers/dispatch_regression.gd"
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")
const PredictionProducers = preload("res://src/game/prayer_producers.gd")
const PredictionDispatch = preload("res://src/game/prayer_dispatch.gd")
var ppr_kinship_prerequisites: Array = []
var ppr_notice_prerequisites: Array = []
var ppr_notice_steps: Array = []
var ppr_notice_selection: Dictionary = {}
var ppr_notice_selection_artifacts: Array = []

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
	Support.write_report(records, "current_dispatch_component_regression", ["Standalone source-backed identities and real graph relationship prerequisites.", {"kinshipInputs": ppr_kinship_prerequisites, "noticeInputs": ppr_notice_prerequisites, "noticeStepArtifacts": ppr_notice_steps, "noticeSelectionArtifacts": ppr_notice_selection_artifacts}], ["Prepared current sources; no natural root or complete Session claim.", "Notice positives replace the old six-seed input with the smallest initialization-only predicted seed in the fixed 1..512 set; twelve rounds and original business assertions remain. No natural notice-frequency claim."])
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
	var setup: Dictionary = _notice_setup(variant == "same_institution")
	assert(setup.ok and int(setup.seed) == seed_value)
	var chosen: Dictionary = setup.family if variant == "wrong_relation" else setup.pair
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
	var expectation: Dictionary = setup.duplicate(true); expectation.erase("examined")
	data["ppr_notice_input"] = {"seed": seed_value, "mode": mode, "variant": variant, "sender": data.sender, "recipient": data.recipient, "selectedSource": chosen.source, "expected": expectation}
	_attach_dispatch(data)
	assert(world.state.domains["DOMAIN-001"].unnamed_nonfollowers == 0)
	ppr_notice_prerequisites.append({"seed": seed_value, "mode": mode, "variant": variant, "sender": data.sender, "recipient": data.recipient, "selectedActualSource": chosen.source, "selectedActualKind": chosen.kind, "sameInstitutionRequired": variant == "same_institution", "independentPassageCompetitor": passage_competitor, "qualificationBeforeBootstrap": qualification, "anonymousAfterBootstrap": world.state.domains["DOMAIN-001"].unnamed_nonfollowers, "initialCursor": setup.cursor, "expectedRoots": setup.expectedRoots, "expectedChoice": setup.expectedChoice, "expectedNoticeMode": "detailed_candidates" if mode == "focused" else "abstract_candidates_due"})
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
	var preflight: Dictionary = _notice_preflight(data, frozen)
	if int(frozen.turn) == 2 and preflight.ok and preflight.has("completeEligible"): data["ppr_notice_prediction"] = preflight.duplicate(true)
	var result: Dictionary = super._submit(data, op, payload) if preflight.ok else {"ok": false, "error": "Predeclared notice fixture prediction disagrees with the real frozen prerequisites", "fixturePrediction": preflight}
	var last: String = str(world.state.prayer_dispatch.last.get("DOMAIN-001", ""))
	var actual_tick: Dictionary = Store.entry(world.state.facts, last, {})
	if int(frozen.turn) == 1 and data.ppr_notice_input.variant in ["valid", "same_institution"]:
		var changes: Dictionary = actual_tick.get("changes", {})
		data["ppr_notice_t1_unchanged"] = result.ok and not changes.get("opportunity", true) and changes.get("before", {}) == data.ppr_notice_input.expected.cursor and changes.get("after", {}) == data.ppr_notice_input.expected.cursor and str(changes.get("position_after", {}).get("notice_sender", "")).is_empty() and str(changes.get("position_after", {}).get("notice_after", "")).is_empty()
	var record: Dictionary = {"fixture": data.ppr_notice_input.duplicate(true), "preAdvancePhase": "evolution", "frozenBeforeAdvance": before,
		"currentBeforeAdvance": current_before, "fixturePreflight": preflight, "response": result.duplicate(true),
		"actualDispatchTick": actual_tick.duplicate(true), "t1CursorAndNoticeUnchanged": data.get("ppr_notice_t1_unchanged"),
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

func _notice_setup(same_institution: bool) -> Dictionary:
	var key: String = "same_institution" if same_institution else "valid"
	if ppr_notice_selection.has(key): return ppr_notice_selection[key]
	var selected: Dictionary = Support.notice_input(catalog, same_institution)
	var path: String = scratch.path_join("notice-initial-input-" + key + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null); file.store_string(JSON.stringify(selected, "\t", true, true) + "\n"); file.close()
	ppr_notice_selection_artifacts.append({"path": path, "sha256": FileAccess.get_sha256(path), "case": key})
	ppr_notice_selection[key] = selected
	return selected

func _notice_preflight(data: Dictionary, frozen: Dictionary) -> Dictionary:
	var input: Dictionary = data.ppr_notice_input
	if not input.variant in ["valid", "same_institution"]: return {"ok": true, "scope": "Negative current eligibility input; no notice selection promised"}
	var cursor: Dictionary = frozen.simulation.cursors["DOMAIN-001"]
	var position: Dictionary = frozen.prayer_dispatch.positions["DOMAIN-001"]
	var expected: Dictionary = input.expected
	if int(frozen.turn) > 2: return {"ok": false, "error": "Predicted first notice was not committed at turn two"}
	var initial: bool = cursor == expected.cursor and str(position.notice_sender).is_empty() and str(position.notice_after).is_empty()
	if int(frozen.turn) == 1: return {"ok": initial and int(cursor.next_turn) == 2, "initialCursorAndNoticePosition": initial, "opportunity": false}
	# Read-only diagnostic sample for pure predicates. It is never submitted to
	# an authorization or gameplay handler; the real transaction makes its own.
	var sample: Dictionary = {"turn": int(frozen.turn), "phase": 4, "commit_seq": int(data.turn.commit_sequence), "fact_cutoff": int(data.world.state.next_fact) - 1}
	var options: Array = PredictionProducers.prepare_options(data.world, frozen, "DOMAIN-001", sample)
	var notice: Dictionary = PredictionDispatch._notice(data.world, frozen, "DOMAIN-001", position, sample, int(cursor.next_turn))
	var roots: Array = options.map(func(option: Dictionary) -> String: return str(option.root))
	if not notice.selection.is_empty():
		roots.append("ROOT_IDENTITY_NOTICE")
		options.append({"root": "ROOT_IDENTITY_NOTICE", "legacy": false, "selection": notice.selection.duplicate(true)})
	var mode: String = "focused" if "DOMAIN-001" in frozen.simulation.focused else "background"
	var known: Dictionary = Knowledge.known(frozen, data.sender, sample)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = int(cursor.seed); rng.state = int(cursor.state)
	var chance: int = rng.randi_range(1, 100)
	var index: int = rng.randi_range(0, roots.size() - 1) if chance <= catalog.integer("ambient_event_chance") and not roots.is_empty() else -1
	var selected: String = str(roots[index]) if index >= 0 else ""
	var full_choice: Dictionary = options[index].duplicate(true) if index >= 0 else {}
	var exact_parties: bool = notice.sender == data.sender and notice.people[0] == data.sender and notice.selection.get("sender") == data.sender and notice.selection.get("recipient") == data.recipient and notice.selection.get("relation") == input.selectedSource
	return {"ok": initial and roots == expected.expectedRoots and selected == expected.expectedChoice and mode == input.mode and known.get("known", false) and exact_parties and chance == int(expected.chanceDraw) and index == int(expected.indexDraw) and str(rng.state) == expected.rngAfter, "initialCursorAndNoticePosition": initial, "actualRoots": roots, "actualPredictedChoice": selected, "completeEligible": options, "completeChoice": full_choice, "diagnosticSample": sample, "sampleDerivation": "Outside a transaction Knowledge.capture correctly returns empty. This private predicate input describes the next transaction base: current turn, phase four, current committed sequence, next_fact minus one; no privilege, source or authorization is produced.", "chanceDraw": chance, "indexDraw": index, "mode": mode, "knownSender": known, "exactParties": exact_parties, "notice": notice, "scope": "Pure current pre-advance consistency check, never an authority or submitted selection"}

func _notice_receipt_matches(data: Dictionary, mode: String) -> Dictionary:
	var received: Array = _facts(data.world, "deity_identity_received")
	if received.size() != 1: return {"ok": false, "receivedCount": received.size()}
	var tick: Dictionary = {}
	for fact: Dictionary in _facts(data.world, "prayer_dispatch_tick"):
		if fact.domain == "DOMAIN-001" and fact.changes.get("produced") == received[0].id: tick = fact
	var selected: Array = _facts(data.world, "identity_notice_selected")
	var receipt: Dictionary = {}
	if selected.size() == 1 and not tick.is_empty():
		for entry: Dictionary in Store.values(data.turn.context.receipts):
			if int(str(selected[0].id).trim_prefix("FACT-")) >= int(entry.get("fact_before", -1)) and int(str(tick.id).trim_prefix("FACT-")) < int(entry.get("fact_after", -1)): receipt = entry
	var expected: Dictionary = data.ppr_notice_input.expected
	var roots: Array = tick.get("changes", {}).get("eligible", []).map(func(item: Dictionary) -> String: return str(item.root))
	var expected_mode: String = "detailed_candidates" if mode == "focused" else "abstract_candidates_due"
	var actual: Dictionary = tick.get("changes", {})
	var prediction: Dictionary = data.get("ppr_notice_prediction", {})
	var full_match: bool = not prediction.is_empty() and actual.get("eligible", []) == prediction.get("completeEligible", []) and actual.get("choice", {}) == prediction.get("completeChoice", {}) and actual.get("notice_scan", {}) == prediction.get("notice", {}) and actual.get("snapshot", {}) == prediction.get("diagnosticSample", {})
	var valid: bool = full_match and data.get("ppr_notice_t1_unchanged", false) and not receipt.is_empty() and receipt.request.phase == "evolution" and int(tick.get("turn", -1)) == 2 and actual.get("mode") == expected_mode and roots == expected.expectedRoots and actual.get("choice", {}).get("root") == expected.expectedChoice and actual.get("new_outcome") == "identity_received" and actual.get("before", {}) == expected.cursor and actual.get("after", {}).get("state") == expected.rngAfter
	return {"ok": valid, "actualTick": tick, "sameReceipt": receipt, "expected": expected, "completePrediction": prediction, "fullCandidatesChoiceNoticeAndSampleEqual": full_match, "sampleNormalization": "none; all sample fields compared exactly", "t1CursorAndNoticeUnchanged": data.get("ppr_notice_t1_unchanged", false), "scope": "Actual committed tick mode, full eligible roots and original RNG prediction match the same selected/received evolution receipt"}

func _notice_dispatch_cases() -> void:
	var setup: Dictionary = _notice_setup(false)
	var same_setup: Dictionary = _notice_setup(true)
	if not setup.get("ok", false) or not same_setup.get("ok", false):
		for suffix: String in ["focused", "background", "unidentified", "anomaly_only", "no_relation", "wrong_relation", "no_route", "dead", "detained", "missing", "cross_domain", "same_institution", "ROLLBACK"]:
			_check("PD-NOTICE/" + suffix, "Predeclared actual initialization fixture prerequisites must exist", false, {"setup": setup, "sameInstitutionSetup": same_setup})
		return
	var selected_seed: int = -1
	for mode: String in ["focused", "background"]:
		var found: Dictionary = {}
		var evidence: Array = []
		for seed_value: int in [int(setup.seed)]:
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
			found["predictedAndActual"] = _notice_receipt_matches(data, mode)
			valid = valid and found.predictedAndActual.ok
			found.erase("data")
			found["sameReceipt"] = receipt
		_check("PD-NOTICE/" + mode, "The real shared opportunity selection automatically transfers sourced identity within one published evolution receipt", valid, {"evidence": evidence, "found": found, "scope": "Existing real relationship/population prerequisites and actual successful dream; no hand-selected notice authorization"})
	if selected_seed < 0: return
	for variant: String in ["unidentified", "anomaly_only", "no_relation", "wrong_relation", "no_route", "dead", "detained", "missing", "cross_domain", "same_institution"]:
		var case_seed: int = int(same_setup.seed) if variant == "same_institution" else selected_seed
		var data: Dictionary = _notice_fixture("focused", variant, case_seed)
		var valid: bool = true
		for attempt: int in 12:
			valid = valid and _evolve(data)
			if not _facts(data.world, "deity_identity_received").is_empty() or not valid: break
			valid = valid and _finish(data) and _open(data)
		var received: Array = _facts(data.world, "deity_identity_received")
		var known: bool = Knowledge.known(data.world.state, data.recipient).get("known", false)
		valid = valid and (known and received.size() == 1 if variant == "same_institution" else not known and received.is_empty())
		var exact: Dictionary = _notice_receipt_matches(data, "focused") if variant == "same_institution" else {}
		if variant == "same_institution": valid = valid and exact.get("ok", false)
		_check("PD-NOTICE/" + variant, "Automatic identity notice requires the actual original knowledge, relationship, active same-domain parties and current route", valid, {"received": received, "recipientKnowledge": Knowledge.known(data.world.state, data.recipient), "seed": case_seed, "turn": data.world.state.turn, "predictedAndActual": exact})
	_notice_rollback(selected_seed)

