extends "res://tools/prayer-producers/source-contract.gd"
const AnchorRules = preload("res://src/game/anchor_routes.gd")
const ActualAnchors = preload("res://src/game/anchors.gd")
var production: Dictionary = {}

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files():
		_check("AR-CATALOG", "Formal route CSV grammar loads", false, {"errors": catalog.errors})
	else:
		_rule_inputs()
		_differences()
		_production()
		_boundaries()
	var passed: bool = records.size() == 4 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "scope": "shared_route_consumers_and_actual_response_to_basis", "limitations": ["Sixteen normalized route inputs are consumer checks, not natural production or reachability.", "Only existing Prayers/Powers raw producers are installed; eight alternate production adapters remain missing_producer for TASK-PROGRESSION-OPERATIONS.", "Controlled original records/knowledge and RNG are prerequisites; actual calls, responses and basis facts must come from Turn.", "No full Session, relic/upkeep/ending integration, per-civilization alternate active route, balance or human visual acceptance."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _normalized(route: String) -> Dictionary:
	var row: Dictionary = catalog.tables.anchor_route_rules[route]
	var state: Dictionary = {"domains": {"D": {"profile": row.profile}}, "institutions": {"A": {"domain": "D", "active": false, "representative": "", "links": ["B"]}, "B": {"domain": "D", "active": false, "representative": "", "links": ["A"]}}, "npcs": {}}
	for id: String in ["p1", "p2", "p3"]: state.npcs[id] = {"id": id, "domain": "D", "institution": "A", "status": "active", "known_facts": []}
	var data: Dictionary = {"state": state, "materials": {}, "basis": {"route": route}, "route": route}
	match str(row.selector):
		"testimonies", "network_independent":
			if row.selector == "network_independent": state.npcs.p2.institution = "B"; data.basis["other_institution"] = "B"
			_input_material(data, "r1", "evidence", ["p1"], {}, "A", 1)
			_input_material(data, "r2", "evidence", ["p2"], {}, str(state.npcs.p2.institution), 2)
			data.basis.merge({"records": ["r1", "r2"], "witnesses": ["p1", "p2"]}); data.essential = "r1"
		"operator_dependency":
			var kind: String = {"record_dependency": "record_dependency", "calendar_dependency": "calendar_dependency", "axiom_archive": "axiom_dependency"}[route]
			var key: String = "exception" if route == "axiom_archive" else "series"
			var root: String = "e" if key == "exception" else "s"
			_input_material(data, root, "exception" if key == "exception" else ("record_series" if route == "record_dependency" else "calendar_pulse"), ["p1"])
			for offset: int in 2: _input_material(data, "u" + str(offset), "axiom_use" if key == "exception" else ("record_use" if route == "record_dependency" else "calendar_use"), ["p1"], {key: root, "operator": "p1"}, "A", offset + 1)
			_input_material(data, "dep", kind, ["p1"], {key: root, "operator": "p1", "uses": ["u0", "u1"]})
			data.basis.merge({key: root, "operator": "p1", "uses": ["u0", "u1"], "dependency": "dep"}); data.essential = "dep"
		"rites", "keeper":
			_input_material(data, "r1", "ritual", ["p1"], {"priest": "p1"}, "A", 1)
			_input_material(data, "r2", "ritual", ["p1"], {"priest": "p1"}, "A", 2)
			data.basis["priest"] = "p1"; data.basis["rituals" if row.selector == "rites" else "ritual"] = ["r1", "r2"] if row.selector == "rites" else "r1"; data.essential = "r1"
		"ritual_practice":
			_input_material(data, "lesson", "ritual_lesson", ["p1"], {"student": "p1", "teacher": "p3", "teacher_qualified": true}, "A", 1)
			_input_material(data, "rite", "practiced_rite", ["p1"], {"practitioner": "p1", "lesson": "lesson"}, "A", 2)
			data.basis.merge({"lesson": "lesson", "ritual": "rite", "practitioner": "p1"}); state.npcs.p3.status = "dead"; data.essential = "rite"
		"memory_circle":
			_input_material(data, "memory", "shared_memory", ["p1", "p2", "p3"])
			_input_material(data, "review", "memory_review", [], {"memory": "memory", "holders": ["p1", "p2", "p3"]})
			for offset: int in 3: _input_material(data, "q" + str(offset), "memory_qualification", ["p" + str(offset + 1)], {"memory": "memory", "review": "review", "person": "p" + str(offset + 1)})
			data.basis.merge({"memory": "memory", "review": "review", "witnesses": ["p1", "p2", "p3"], "qualifications": ["q0", "q1", "q2"]})
			if route == "dissent_circle":
				_input_material(data, "conflict", "memory_conflict", ["p1", "p2", "p3"], {"memory": "memory", "review": "review"}); data.basis["conflicts"] = ["conflict", "conflict", "conflict"]
			data.essential = "memory"
		"pair_dependency":
			_input_material(data, "session", "practice_session", ["p1", "p2"])
			for offset: int in 2:
				_input_material(data, "reg" + str(offset), "practice_registration", ["p" + str(offset + 1)], {"session": "session", "person": "p" + str(offset + 1), "viewpoint": "intact" if offset == 0 else "broken"})
				_input_material(data, "u" + str(offset), "recollection_use" if route == "memory_practice" else "dissent_use", ["p1", "p2"], {"session": "session", "participants": ["p1", "p2"]}, "A", offset + 1)
			_input_material(data, "dep", "recollection_dependency" if route == "memory_practice" else "dissent_dependency", ["p1", "p2"], {"session": "session", "participants": ["p1", "p2"], "registrations": ["reg0", "reg1"], "uses": ["u0", "u1"]})
			data.basis.merge({"session": "session", "participants": ["p1", "p2"], "registrations": ["reg0", "reg1"], "uses": ["u0", "u1"], "dependency": "dep"}); data.essential = "dep"
		"network_exchange":
			state.npcs.p2.institution = "B"
			_input_material(data, "end0", "network_endpoint_use", ["p1"], {"operator": "p1", "exchange": "x"}, "A")
			_input_material(data, "end1", "network_endpoint_use", ["p2"], {"operator": "p2", "exchange": "x"}, "B")
			_input_material(data, "dep", "network_dependency", ["p1", "p2"], {"exchange": "x", "endpoints": ["end0", "end1"], "operators": ["p1", "p2"], "institutions": ["A", "B"]})
			data.basis.merge({"other_institution": "B", "exchange": "dep"}); data.essential = "dep"
		"contract_performance":
			_input_material(data, "contract", "contract", ["p1", "p2"], {"parties": ["p1", "p2"], "term": "preserve_record"})
			_input_material(data, "dep", "contract_dependency", ["p1"], {"contract": "contract", "performance": "performance", "term": "preserve_record", "origin": "route"})
			for offset: int in 2: _input_material(data, "w" + str(offset), "contract_witness", ["p" + str(offset + 1)], {"contract": "contract", "performance": "performance"})
			data.basis.merge({"contract": "contract", "dependency": "dep", "witnesses": ["w0", "w1"]}); data.essential = "dep"
		"contract_reciprocal":
			state.npcs.p2.institution = "B"
			_input_material(data, "covenant", "reciprocal_covenant", ["p1", "p2"], {"parties": ["p1", "p2"], "record_roots": ["root0", "root1"]})
			for offset: int in 2:
				var person: String = "p" + str(offset + 1); var office: String = "A" if offset == 0 else "B"
				_input_material(data, "r" + str(offset), "evidence", [person], {}, office, offset + 1, "root" + str(offset))
				_input_material(data, "leg" + str(offset), "reciprocal_leg", [person], {"index": offset, "covenant": "covenant", "recipient": person, "record": "r" + str(offset), "term": "deliver_record"}, office, offset + 1)
			_input_material(data, "dep", "reciprocal_dependency", ["p1", "p2"], {"covenant": "covenant", "legs": ["leg0", "leg1"]})
			data.basis.merge({"covenant": "covenant", "legs": ["leg0", "leg1"], "dependency": "dep", "parties": ["p1", "p2"], "other_institution": "B"}); data.essential = "dep"
		"axiom_nodes":
			state.npcs.p2.institution = "B"; _input_material(data, "exception", "exception", [])
			for offset: int in 2:
				var person: String = "p" + str(offset + 1); var office: String = "A" if offset == 0 else "B"
				_input_material(data, "r" + str(offset), "exception_record", [person], {"exception": "exception", "observer": person, "observation": "obs" + str(offset)}, office)
			data.basis.merge({"exception": "exception", "other_institution": "B", "records": ["r0", "r1"]}); data.essential = "r0"
	return data

func _input_material(data: Dictionary, id: String, kind: String, owners: Array, details: Dictionary = {}, institution: String = "A", turn: int = 1, root: String = "") -> void:
	data.materials[id] = {"id": id, "kind": kind, "root": id if root.is_empty() else root, "turn": turn, "institution": institution, "owners": owners.duplicate(), "originals": owners.duplicate(), "knowledge": [id], "current": true, "data": details, "causes": []}
	for owner: String in owners:
		if data.state.npcs.has(owner): data.state.npcs[owner].known_facts.append(id)

func _evaluate_input(data: Dictionary, purpose: String = "anchor") -> Dictionary:
	return AnchorRules.evaluate_normalized(data.state, "A", data.basis, data.materials, catalog, null, purpose)

func _rule_inputs() -> void:
	var results: Array = []; var valid: bool = true
	for route: String in catalog.tables.anchor_route_rules:
		var data: Dictionary = _normalized(route)
		var positive: Dictionary = _evaluate_input(data)
		data.materials[data.essential].current = false
		var negative: Dictionary = _evaluate_input(data)
		var row_ok: bool = positive.get("allowed", false) and not negative.get("allowed", false)
		valid = valid and row_ok
		results.append({"route": route, "pass": row_ok, "positive": positive, "negative": negative, "evidenceKind": "controlled_normalized_consumer_inputs"})
	_check("AR-RULES", "Sixteen finite route consumers accept actual-shape inputs and reject missing current material; no producer capability is fabricated", valid and results.size() == 16, {"routes": results})

func _differences() -> void:
	var testimony: Dictionary = _normalized("record_testimonies"); testimony.materials.r2.turn = 1
	var same_turn_anchor: Dictionary = _evaluate_input(testimony)
	var same_turn_spread: Dictionary = _evaluate_input(testimony, "spread")
	var dissent: Dictionary = _normalized("dissent_circle"); dissent.state.npcs.p3.status = "dead"
	var two_anchor: Dictionary = _evaluate_input(dissent); var two_spread: Dictionary = _evaluate_input(dissent, "spread")
	dissent.state.npcs.p2.status = "dead"; var one_anchor: Dictionary = _evaluate_input(dissent)
	var pact: Dictionary = _normalized("contract_performance"); pact.materials.dep.data.term = "deliver_record"; pact.materials.contract.data.term = "deliver_record"
	var single_leg: Dictionary = _evaluate_input(pact)
	var reciprocal: Dictionary = _normalized("contract_reciprocal"); reciprocal.materials.r1.root = reciprocal.materials.r0.root
	var copied_root: Dictionary = _evaluate_input(reciprocal)
	var use: Dictionary = _normalized("axiom_archive"); use.materials.u1.turn = use.materials.u0.turn
	var same_use: Dictionary = _evaluate_input(use)
	var circle: Dictionary = _normalized("memory_circle")
	circle.state.npcs.p2.institution = "B"; circle.state.npcs.p3.institution = "B"
	circle.state.institutions.A.links = []; circle.state.institutions.B.links = []
	var cross_circle: Dictionary = _evaluate_input(circle)
	var practice: Dictionary = _normalized("memory_practice"); practice.state.npcs.p2.institution = "B"
	practice.state.institutions.A.links = []; practice.state.institutions.B.links = []
	var severed_practice: Dictionary = _evaluate_input(practice)
	var valid: bool = not same_turn_anchor.allowed and same_turn_spread.allowed and two_anchor.allowed and not two_spread.allowed and not one_anchor.allowed and not single_leg.allowed and not copied_root.allowed and not same_use.allowed and cross_circle.allowed and not severed_practice.allowed
	_check("AR-DIFFERENCES", "Keep original/alternate counts, spread versus anchor turns, preserve_record versus two actual legs, and independent use roots distinct", valid, {"sameTurnAnchor": same_turn_anchor, "sameTurnSpread": same_turn_spread, "dissentTwoAliveAnchor": two_anchor, "dissentTwoAliveSpread": two_spread, "dissentOneAliveAnchor": one_anchor, "deliverRecordSingleBranch": single_leg, "copiedReciprocalRoot": copied_root, "sameUseTurn": same_use, "crossInstitutionOldCircleWithoutNewLinksGate": cross_circle, "crossInstitutionPracticeRequiresCurrentLink": severed_practice})

func _production() -> void:
	var data: Dictionary = _producer_native(1)
	var institution: String = "DOMAIN-001/interpretation"
	var people: Array = _local_people(data.world).filter(func(id: String) -> bool: return Store.entry(data.world.state.npcs, id).institution == institution)
	var valid: bool = data.world.state.domains["DOMAIN-001"].profile == "CIV_01" and people.size() >= 2
	var roots: Array = []
	if valid:
		for person: String in people.slice(0, 2): roots.append(_record_input(data, person))
		_attach_dispatch(data)
		data.anchors = ActualAnchors.new(catalog, data.prayers.issuers)
		valid = data.anchors.install(data.turn) and _boot(data).get("ok", false) and _open(data)
	var spread: Dictionary = _actual_same_turn_spread()
	var succession: Dictionary = _actual_successor_material()
	var responses: Array = []
	var loops: int = 0
	while valid and responses.size() < 2 and loops < 8:
		loops += 1
		for request: String in data.world.state.prayer_system.offered:
			var entry: Dictionary = data.world.state.prayer_system.requests[request]
			if entry.descriptor.content_id != "PRAYER_04" or not entry.descriptor.facts.get("record", "") in roots: continue
			_choose_prayer_seed(data, "success", entry.descriptor.subjects.petitioner, entry.descriptor.domain)
			var response: Dictionary = _response(data, request, "shallow")
			responses.append({"request": request, "turn": data.world.state.turn, "response": response})
			valid = valid and response.get("ok", false); break
		if responses.size() < 2: valid = valid and _evolve(data) and _finish(data) and _open(data)
	var bases: Array = _facts(data.world, "anchor_basis") if data.has("turn") else []
	var available: Array = ActualAnchors.available(data.world.state, institution, catalog, data.world.history) if data.has("turn") else []
	valid = valid and responses.size() == 2 and available.size() == 1 and available[0].route == "record_testimonies" and spread.get("pass", false) and succession.get("pass", false)
	production = data; production["institution"] = institution; production["valid"] = valid; production["roots"] = roots
	_check("AR-PRODUCTION", "Two original known records reach formal calls, successful responses and transaction-derived current basis without a target basis fixture", valid, {"inputs": {"seed": 1, "profile": "CIV_01", "originalRecords": roots, "givenKnowledge": people.slice(0, 2)}, "responses": responses, "sameTurnFormalSpread": spread, "actualSuccessorMaterial": succession, "bases": bases, "available": available, "loops": loops, "rawAdapterScope": "Existing actual PR04 results; not alternate producer or natural balance proof"})

func _boundaries() -> void:
	if not production.get("valid", false):
		_check("AR-BOUNDARIES", "Pure query, exact known projection, idempotence, current invalidation and component restoration", false, {"reason": "production_prerequisite_failed"}); return
	var data: Dictionary = production
	var permissions: Array = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history)
	var permission: Dictionary = permissions[0]
	var source: String = permission.source
	var before: String = data.turn.snapshot()
	var preview: Dictionary = ActualAnchors.discover(data.world.state, data.institution, catalog, data.world.history)
	var pure: bool = before == data.turn.snapshot()
	var saved: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(saved) and saved == data.turn.snapshot()
	var session: RefCounted = Session.new()
	session.catalog = catalog; session.world = data.world; session.turn = data.turn; session.modules = {"player_sources": null}
	var hidden: bool = session.anchor_source_options(data.institution).is_empty()
	var fact: Dictionary = Store.entry(data.world.state.facts, source)
	for parent: String in fact.causal_parents: session._learn(parent)
	# Inputs remain individually disclosed by their original result; learning a
	# basis itself must not reveal an otherwise unknown material or person.
	for target: String in fact.targets:
		if Store.has(data.world.state.npcs, target): session._known_people[target] = true
	session._known_domains[fact.domain] = true
	session._learn(source)
	var known: Array = session.anchor_source_options(data.institution)
	var known_ok: bool = known.size() == 1 and known[0].id == source
	var original_count: int = _facts(data.world, "anchor_basis").size()
	var repeated: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": {}})
	var idempotent: bool = repeated.get("ok", false) and _facts(data.world, "anchor_basis").size() == original_count
	var shadow: Dictionary = data.world.state.duplicate(false)
	# Counterfactual consumer invalidation only. No mutation of authoritative H.
	shadow.invalid_records = {}
	for id: String in Store.keys(data.world.state.invalid_records): shadow.invalid_records[id] = Store.entry(data.world.state.invalid_records, id)
	shadow.invalid_records[permission.basis.records[0]] = data.roots[0]
	var invalid: Dictionary = ActualAnchors.qualify(shadow, data.institution, source, catalog)
	var missing: Array = preview.get("missing_producer", [])
	var valid: bool = pure and restored and hidden and known_ok and idempotent and not invalid.get("allowed", false) and "record_dependency" in missing
	_check("AR-BOUNDARIES", "Queries do not issue basis/knowledge/RNG; actual basis is idempotent, current-material-bound and disclosed only with known inputs", valid, {"pure": pure, "componentRestore": restored, "hiddenBeforeKnowledge": hidden, "knownSourceCount": known.size(), "repeat": repeated, "basisCountBefore": original_count, "basisCountAfter": _facts(data.world, "anchor_basis").size(), "invalidatedMaterial": invalid, "missingProducer": missing, "invalidationEvidence": "read-only state counterfactual; actual lawful erase remains owned by Events", "sessionEvidence": "bounded projection component, not full Session installation"})

func _actual_same_turn_spread() -> Dictionary:
	var data: Dictionary = _producer_native(1)
	var office: String = "DOMAIN-001/interpretation"
	var people: Array = _local_people(data.world).filter(func(id: String) -> bool: return Store.entry(data.world.state.npcs, id).institution == office).slice(0, 2)
	var contacts: Array = []; var qualifications: Array = []
	for person: String in people:
		var contact: String = data.world._record("devotion_contact", "DOMAIN-001", person, [person], [data.source], {"subject": person, "institution": office})
		data.world._know(person, contact); contacts.append(contact)
		qualifications.append(_qualification(data, "dream", person, person, "DOMAIN-001", {"contact": contact}, office))
	_attach_dispatch(data)
	data.anchors = ActualAnchors.new(catalog, data.prayers.issuers)
	var valid: bool = people.size() == 2 and data.anchors.install(data.turn) and _boot(data).get("ok", false) and _open(data)
	var actions: Array = []
	for position: int in people.size():
		var payload: Dictionary = {"npc": people[position], "source": contacts[position], "qualification": qualifications[position]}
		_seed(data, "POWER_DREAM", "success", payload)
		var action: Dictionary = _power(data, "POWER_DREAM", payload)
		actions.append(action); valid = valid and action.get("ok", false)
	var before: String = data.turn.snapshot()
	var spread: Dictionary = ActualAnchors.discover(data.world.state, office, catalog, data.world.history, "spread")
	var anchor: Dictionary = ActualAnchors.discover(data.world.state, office, catalog, data.world.history)
	valid = valid and _facts(data.world, "miracle").size() == 2 and spread.candidates.size() == 1 and anchor.candidates.is_empty() and _facts(data.world, "anchor_basis").is_empty() and before == data.turn.snapshot()
	var pure: bool = before == data.turn.snapshot()
	var published: Dictionary = {}; var wrapped: Dictionary = {}; var revoked: Dictionary = {}; var choice: Dictionary = {}
	if valid:
		for index: int in 2:
			valid = valid and _evolve(data) and _finish(data) and _submit(data, "advance").get("ok", false)
			var event: String = ""
			for id: String in data.world.state.event_system.selected:
				if data.world.state.event_system.cards[id].descriptor.content_id == "EVENT_02": event = id; break
			if not event.is_empty():
				choice = _submit(data, "resolve_event", {"event": event, "action": "B"})
				var publications: Array = _facts(data.world, "event_publication")
				if choice.get("ok", false) and not publications.is_empty(): published = publications[0]
				break
			valid = valid and _submit(data, "finish_events").get("ok", false)
	if not published.is_empty():
		wrapped = ActualAnchors.material(data.world.state, published.id, catalog, data.world.history)
		var shadow: Dictionary = data.world.state.duplicate(false); shadow.invalid_records = {}
		for id: String in Store.keys(data.world.state.invalid_records): shadow.invalid_records[id] = Store.entry(data.world.state.invalid_records, id)
		shadow.invalid_records[published.changes.record] = published.id
		revoked = ActualAnchors.material(shadow, published.id, catalog, null, true)
	valid = valid and not wrapped.is_empty() and wrapped.current and not revoked.is_empty() and not revoked.current
	return {"pass": valid, "dreamContactPrerequisites": contacts, "qualificationPrerequisites": qualifications, "actions": actions, "actualMiracles": _facts(data.world, "miracle"), "spread": spread, "anchor": anchor, "pure": pure, "actualPublicationAction": choice, "actualPublication": published, "wrappedMaterial": wrapped, "baseRevocationCounterfactual": revoked}


func _actual_successor_material() -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, 7919)
	_set_scene_random_input(world, "ROOT_CURRENT_PACT")
	var data: Dictionary = {"world": world, "source": world.state.domains["DOMAIN-001"].origin}
	_attach_dispatch(data)
	data.anchors = ActualAnchors.new(catalog, data.prayers.issuers)
	var valid: bool = data.anchors.install(data.turn) and _boot(data).get("ok", false) and _open(data) and _evolve(data)
	var entry: Dictionary = _contract_entry(data)
	valid = valid and not entry.is_empty() and _finish(data) and _open(data)
	var dependency: String = ""; var witness_ids: Array = []; var response: Dictionary = {}; var continuation: Dictionary = {}; var actual: Array = []
	if valid:
		var request: String = _contract_request(data, entry)
		_choose_prayer_seed(data, "success", entry.petitioner, entry.domain)
		response = _response(data, request, "deep")
		var dependencies: Array = _contract_materials(data, request, "contract_dependency")
		valid = response.get("ok", false) and dependencies.size() == 1
		if valid:
			dependency = dependencies[0].id
			for tag: String in ["contract_fulfilled", "hostile_witness"]:
				var ends: Array = _contract_materials(data, request, tag)
				if not ends.is_empty(): witness_ids.append(ends[0].id)
			data.fixture.deadlines = [_status(data, entry.petitioner, "dead")]
			var event: String = _contract_to_event(data)
			valid = not event.is_empty()
			if valid:
				continuation = _submit(data, "resolve_event", {"event": event, "action": "B"})
				actual = _facts(world, "contract_successor_authorized")
				valid = continuation.get("ok", false) and actual.size() == 1
	var normalized: Dictionary = ActualAnchors.material(world.state, dependency, catalog, world.history) if not dependency.is_empty() else {}
	var successor: Dictionary = ActualAnchors.material(world.state, str(actual[0].id), catalog, world.history) if actual.size() == 1 else {}
	valid = valid and not normalized.is_empty() and not successor.is_empty() and successor.data.successor in normalized.owners and not successor.data.successor in normalized.originals and world.history.knows(world.state, successor.data.successor, dependency) and normalized.current
	var consumed: Dictionary = {}; var wrong_target: Dictionary = {}
	if valid:
		var shadow: Dictionary = world.state.duplicate(false); shadow.domains = world.state.domains.duplicate(false)
		shadow.domains[entry.domain] = world.state.domains[entry.domain].duplicate(false); shadow.domains[entry.domain].profile = "CIV_06"
		var office: String = Store.entry(world.state.npcs, successor.data.successor).institution
		var basis: Dictionary = {"route": "contract_performance", "contract": entry.root, "dependency": dependency, "witnesses": witness_ids, "successor": actual[0].id}
		consumed = ActualAnchors.evaluate(shadow, office, basis, catalog, world.history)
		for other: String in world.state.domains[entry.domain].institutions:
			if other != office:
				wrong_target = ActualAnchors.evaluate(shadow, other, basis, catalog, world.history); break
		valid = consumed.get("allowed", false) and not wrong_target.get("allowed", false)
	return {"pass": valid, "consumerProfileCounterfactual": "CIV_06 only; all referenced source/results/people remain actual", "actualMaterialConsumer": consumed, "wrongTargetCoreCarrier": wrong_target, "response": response, "continuation": continuation, "actualSuccessor": actual, "normalizedDependency": normalized, "normalizedSuccessor": successor, "scope": "Existing actual PR06 and 05B material adaptation; no claim that its generated civilization is CIV06 or that a complete anchor was built"}
