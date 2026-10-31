extends "res://tools/progression-operations/run.gd"
const Birth = preload("res://src/simulation/world_initialization.gd")
const Service = preload("res://src/game/opportunity_service.gd")
const GROUPS: Dictionary = {
	"records-calendar": ["record_testimonies", "record_dependency", "calendar_rites", "calendar_dependency"],
	"ritual": ["ritual_keeper", "ritual_practice"],
	"network": ["network_independent", "network_exchange"],
	"axiom": ["axiom_nodes", "axiom_archive"],
	"memory-dissent": ["memory_circle", "memory_practice", "dissent_circle", "dissent_practice"],
	"contract": ["contract_performance", "contract_reciprocal"]}
const BLOCKED: Dictionary = {
	"record_testimonies": "ROUTE_RECORD_PRACTICE", "calendar_rites": "ROUTE_CALENDAR_KEEPING", "calendar_dependency": "ROUTE_CALENDAR_RITE",
	"ritual_keeper": "ROUTE_RITUAL_TRANSMISSION", "ritual_practice": "ROUTE_CALENDAR_RITE", "network_independent": "ROUTE_NETWORK_EXCHANGE",
	"axiom_nodes": "ROUTE_AXIOM_REPEAT", "axiom_archive": "ROUTE_AXIOM_RECHECK", "memory_circle": "ROUTE_MEMORY_PRACTICE", "memory_practice": "ROUTE_MEMORY_CIRCLE",
	"dissent_circle": "ROUTE_DISSENT_PRACTICE", "dissent_practice": "ROUTE_MEMORY_CIRCLE", "contract_performance": "ROUTE_RECIPROCAL_COVENANT", "contract_reciprocal": "ROUTE_PACT_AGREEMENT"}

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	scratch = arguments[0].get_base_dir()
	var group: String = arguments[1]
	var selected: Array = GROUPS.get(group, []).duplicate()
	if arguments.size() > 2: selected = [arguments[2]] if arguments[2] in selected else []
	var cases: Array = []
	for route: String in selected:
		var outcome: Dictionary = _closure_case(route)
		cases.append(outcome)
		print("CLOSURE_CASE ", route, " ", outcome.get("passed", false), " ", outcome.get("failure", ""))
		if not outcome.get("passed", false): break
	var passed: bool = not cases.is_empty() and cases.all(func(item: Dictionary) -> bool: return item.passed)
	var report: Dictionary = {"status": "pass" if passed else "fail", "checks": [{"id": "APC-" + group.to_upper(), "status": "pass" if passed else "fail", "name": "Actual route production and paid active anchors: " + group, "details": {"cases": cases}}], "engine": Engine.get_version_info().string,
		"scope": "finite_native_eleven_module_Turn_routes_not_Session_UI_or_natural_frequency",
		"fixtures": ["Generated legal world seed/profile, explicitly admitted existing people/roles, sourced preexisting cult/membership, 81 followers, 80 faith, 20 insight and 80 pollution are controlled initial prerequisites.", "Where recorded, the other route's unique operation runtime_status is disabled in this case's detached Catalog. The network-exchange case instead explicitly removes POWER_DREAM's unique definition. Original prepare and Turn commands must reject at both ends; controlled content versions are distinct, with no original-Catalog restore claim.", "Check RNG is controlled. Target miracle/route/prayer materials, custody receipts, basis, opportunity, relic, anchor binding and actual upkeep are never supplied.", "No new simulation model, natural frequency, endgame, mature Session save, UI or balance acceptance."]}
	var file: FileAccess = FileAccess.open(arguments[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n"); file.close()
	quit(0 if passed else 1)

func _fixture(route: String) -> Dictionary:
	catalog = Catalog.new()
	assert(catalog.load_files())
	var profile: String = catalog.tables.anchor_route_rules[route].profile
	var world: RefCounted = Support.CompatibleWorld.new(catalog)
	var domain: String = ""; var chosen_seed: int = 0
	for seed_value: int in range(1, 33):
		var plan: Dictionary = Birth.plan(catalog, str(seed_value), true, int(world.abstract_sim.parameters.initial_focused_domains), int(world.abstract_sim.parameters.local_actor_limit))
		for row: Dictionary in plan.domains:
			if row.profile == profile and row.id != "DOMAIN-001": domain = row.id; chosen_seed = seed_value; break
		if not domain.is_empty(): break
	assert(not domain.is_empty())
	var disabled: String = str(BLOCKED.get(route, ""))
	var control: Dictionary = {}
	if not disabled.is_empty():
		control = {"operation": disabled, "before": catalog.tables.progression_route_operations[disabled].runtime_status, "after": "design_only", "kind": "controlled_unique_operation_unavailable"}
		catalog.tables.progression_route_operations[disabled].runtime_status = "design_only"
		catalog.extension_versions.progression_route_operations = "controlled-disabled/" + disabled + "/" + JSON.stringify(catalog.tables.progression_route_operations, "", true, true).sha256_text()
	elif route == "network_exchange":
		control = {"operation": "POWER_DREAM", "before": catalog.tables.powers.POWER_DREAM.duplicate(true), "after": "missing", "kind": "controlled_missing_unique_power_producer"}
		catalog.tables.powers.erase("POWER_DREAM")
		catalog.extension_versions.powers = "controlled-missing/POWER_DREAM/" + JSON.stringify(catalog.tables.powers, "", true, true).sha256_text()
	assert(world.generate_hybrid(chosen_seed))
	var origin: String = world.state.domains[domain].origin
	var people: Array = []
	var guardian_profile: String = "NPC_PROFILE_02" if route in ["calendar_rites", "ritual_keeper", "ritual_practice"] else "NPC_PROFILE_01"
	var guardian: String = _named(world, domain, "interpretation", guardian_profile, origin); people.append(guardian)
	var other: String = _named(world, domain, "propagation", "NPC_PROFILE_02" if route == "ritual_practice" else "NPC_PROFILE_03", origin); people.append(other)
	if route in ["memory_circle", "dissent_circle"]:
		people.append(_named(world, domain, "interpretation", "NPC_PROFILE_01", origin))
		people.append(_named(world, domain, "order", "NPC_PROFILE_05", origin))
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog)); accepted.merge(PlayerSources.issuer_capability(catalog))
	var economy: RefCounted = Economy.new(catalog, accepted)
	assert(economy.initialize(world) and world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
	_bind(world, guardian)
	var cult: String = "CULT-CLOSURE/" + domain
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, guardian, [guardian], [origin], {"issuer": "cult-fixture", "version": "1", "cult": cult, "domain": domain, "leader": guardian, "cohesion": 100}, [])
	assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
	for person: String in people:
		if person != guardian and route != "record_dependency": _member(world, person, cult)
	world.state.faith = 80; world.state.insight = 20; world.state.domains[domain].pollution = 80; world.state.domains[domain].alert = 0; world._refresh_anchors()
	var data: Dictionary = {"world": world, "source": origin, "domain": domain, "institution": domain + "/interpretation", "guardian": guardian, "actor": guardian, "other": other, "people": people, "cult": cult, "route": route, "seed": chosen_seed, "control": control, "contacts": {}, "dreams": {}, "actions": [], "failure": "", "economy": economy, "productionStart": int(world.state.next_fact)}
	for person: String in people:
		if route == "record_dependency" and person != guardian: continue
		var office: String = Store.entry(world.state.npcs, person).institution
		var contact: String = world._record("devotion_contact", domain, person, [person], [origin], {"subject": person, "institution": office})
		world._know(person, contact); data.contacts[person] = contact
		data.dreams[person] = _qualification(data, "dream", person, person, domain, {"contact": contact}, office)
	var initial_issues: Array[String] = world.validate_state(world.state)
	if not initial_issues.is_empty(): return {"fixtureFailure": "Current native initialization rejected controlled prerequisites", "issues": initial_issues}
	data.turn = Turn.new(world)
	assert(data.turn._attached and economy.install(data.turn))
	data.fixture = Fixture.new()
	data.fixture.domain = domain
	assert(data.turn.register_participant("cult-fixture", "1", ["deadlines"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog); data.relics = Relics.new(catalog, accepted); data.powers = Powers.new(catalog, accepted); data.prayers = Prayers.new(catalog, accepted); data.anchors = ActualAnchors.new(catalog, accepted); data.events = Events.new(catalog); data.resistance = RouteResistance.new(catalog); data.endings = RouteEndings.new(catalog); data.player_sources = PlayerSources.new(catalog); data.routes = Routes.new(catalog)
	for name: String in ["cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources", "routes"]: assert(data[name].install(data.turn))
	assert(Service.install(data.turn) and _boot(data).get("ok", false) and _open(data))
	return data

func _named(world: RefCounted, domain: String, role: String, profile: String, origin: String) -> String:
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local(domain, domain + "/" + role, profile, origin))
	return person

func _accept(data: Dictionary, result: Dictionary, stage: String) -> bool:
	_mark(data, stage + "/end")
	data.actions.append({"stage": stage, "turn": data.turn.context.turn, "result": result})
	if result.get("ok", false): return true
	data.failure = stage + ": " + str(result.get("error", result)); return false

func _next(data: Dictionary) -> bool:
	_mark(data, "next/start")
	var advanced: bool = _route_next(data)
	_mark(data, "next/end")
	if advanced: return true
	data.failure = "Original phase advancement: " + str(data.turn.last_error); return false

func _open(data: Dictionary) -> bool:
	if not _submit(data, "advance").get("ok", false): return false
	if data.route == "contract_reciprocal":
		for id: String in data.world.state.event_system.selected.duplicate():
			var entry: Dictionary = data.world.state.event_system.cards.get(id, {})
			var descriptor: Dictionary = entry.get("descriptor", {})
			if descriptor.get("content_id") != "EVENT_12" or descriptor.get("subjects", {}).get("petitioner") != data.guardian: continue
			# Keep this existing guardian's request alive by the original paid B
			# choice; accepting default A legitimately removes their willingness.
			var result: Dictionary = _submit(data, "resolve_event", {"event": id, "action": "B"})
			data.actions.append({"stage": "actual_guardian_request_reopen", "turn": data.turn.context.turn, "event": id, "result": result})
			if not result.get("ok", false): return false
	return _submit(data, "finish_events").get("ok", false)

func _operate(data: Dictionary, operation: String, payload: Dictionary = {}) -> bool:
	_mark(data, operation + "/start")
	return _accept(data, _route(data, operation, payload), operation)

func _dream(data: Dictionary, person: String, outcome: String = "success") -> String:
	_mark(data, "POWER_DREAM/" + outcome + "/start")
	var payload: Dictionary = {"npc": person, "source": data.contacts[person], "qualification": data.dreams[person]}
	_seed(data, "POWER_DREAM", outcome, payload)
	var first: int = data.world.state.next_fact
	if not _accept(data, _power(data, "POWER_DREAM", payload), "POWER_DREAM/" + outcome): return ""
	for fact: Dictionary in _facts(data.world, "miracle"):
		if int(str(fact.id).trim_prefix("FACT-")) >= first and fact.changes.get("power") == "POWER_DREAM": return fact.id
	return "" if outcome == "failure" else "missing_actual_dream"

func _blocked(data: Dictionary) -> bool:
	var before: String = data.turn.snapshot()
	var operation: String = str(data.control.get("operation", ""))
	var result: Dictionary
	if catalog.tables.progression_route_operations.has(operation):
		result = _submit(data, "act", {"participant": Routes.ID, "action": operation, "payload": {"npc": data.guardian, "source": data.source}})
	else:
		var payload: Dictionary = {"npc": data.other, "source": data.source}
		if data.route == "network_exchange": payload = {"npc": data.other, "source": data.contacts[data.other], "qualification": data.dreams[data.other]}
		result = _power(data, "POWER_DREAM", payload)
		if data.route == "record_dependency": data.control = {"kind": "actual_missing_second_dream_qualification", "person": data.other, "operation": "POWER_DREAM"}
	data.control["actualRejectedCommand"] = result; data.control["rejectionWasAtomic"] = before == data.turn.snapshot()
	return not result.get("ok", false) and before == data.turn.snapshot()

func _produce(data: Dictionary) -> bool:
	var route: String = data.route
	if route in ["record_testimonies", "network_independent"]:
		var first: String = _dream(data, data.guardian)
		if first.is_empty() or first == "missing_actual_dream" or not _next(data): return false
		var second: String = _dream(data, data.other)
		if second.is_empty() or second == "missing_actual_dream": return false
		if route == "record_testimonies":
			if not _next(data): return false
			var before: String = data.turn.snapshot()
			var ordinary: Dictionary = _submit(data, "act", {"participant": "cults", "action": "transfer_material", "payload": {"sender": data.other, "recipient": data.guardian, "source": data.source, "target_institution": data.institution, "grant": "custody"}})
			var copied: Dictionary = ActualAnchors.evaluate(data.world.state, data.institution, {"route": route, "records": [first, first], "witnesses": [data.guardian, data.other]}, catalog, data.world.history)
			data["negative"] = {"ordinaryMaterialTransfer": ordinary, "sameRootCannotSubstitute": copied, "atomic": before == data.turn.snapshot()}
			if ordinary.get("ok", false) or copied.get("allowed", false) or before != data.turn.snapshot(): data.failure = "Ordinary material or duplicated root bypassed original admission"; return false
			if not _accept(data, _submit(data, "act", {"participant": "cults", "action": "transfer_material", "payload": {"sender": data.other, "recipient": data.guardian, "source": second, "target_institution": data.institution, "grant": "custody"}}), "actual_testimony_custody"): return false
		return true
	if route in ["record_dependency", "calendar_dependency", "calendar_rites", "ritual_keeper", "axiom_archive"]:
		var operation: String = {"record_dependency": "ROUTE_RECORD_PRACTICE", "calendar_dependency": "ROUTE_CALENDAR_KEEPING", "calendar_rites": "ROUTE_CALENDAR_RITE", "ritual_keeper": "ROUTE_CALENDAR_RITE", "axiom_archive": "ROUTE_AXIOM_REPEAT"}[route]
		var payload: Dictionary = {}
		if route == "axiom_archive":
			if not _operate(data, "ROUTE_AXIOM_PROBE") or not _next(data): return false
			payload.target = _route_materials(data, "axiom_record")[-1].changes.data.exception
		for index: int in (1 if route == "ritual_keeper" else 2):
			if index > 0 and not _next(data): return false
			if not _operate(data, operation, payload): return false
		return true
	if route == "network_exchange":
		return _operate(data, "ROUTE_NETWORK_EXCHANGE", {"other": data.other})
	if route == "axiom_nodes":
		if not _operate(data, "ROUTE_AXIOM_PROBE") or not _next(data): return false
		var exception: String = _route_materials(data, "axiom_record")[-1].changes.data.exception
		data.actor = data.other
		return _operate(data, "ROUTE_AXIOM_RECHECK", {"target": exception})
	if route == "ritual_practice":
		data.actor = data.other
		if not _operate(data, "ROUTE_JOINT_WORK", {"other": data.guardian}) or not _next(data): return false
		var preview: Dictionary = data.routes.preview(data.turn, "ROUTE_RITUAL_TRANSMISSION", {"npc": data.other, "source": data.source, "other": data.guardian})
		if not _operate(data, "ROUTE_RITUAL_TRANSMISSION", {"other": data.guardian}) or not _next(data): return false
		data.actor = data.guardian
		return _operate(data, "ROUTE_RITUAL_TRANSMISSION", {"target": preview.get("key", "")})
	var record: String = _dream(data, data.guardian)
	if record.is_empty() or record == "missing_actual_dream" or not _next(data): return false
	if route in ["memory_practice", "dissent_practice"]:
		for index: int in 2:
			if index > 0 and not _next(data): return false
			if not _operate(data, "ROUTE_MEMORY_PRACTICE" if route == "memory_practice" else "ROUTE_DISSENT_PRACTICE", {"record": record, "other": data.other}): return false
		return true
	if route in ["memory_circle", "dissent_circle", "contract_performance"]:
		var operation: String = "ROUTE_PACT_AGREEMENT" if route == "contract_performance" else "ROUTE_MEMORY_CIRCLE"
		var payload: Dictionary = {"record": record}
		if route == "contract_performance": payload.other = data.other
		else: payload.participants = data.people.filter(func(id: String) -> bool: return id != data.guardian)
		if not _operate(data, operation, payload): return false
		var source: String = _route_context_source(data, operation)
		if not _next(data): return false
		var request: String = _offered_route_context(data, source)
		if request.is_empty(): data.failure = "Original fixed request not offered: " + source; return false
		var descriptor: Dictionary = data.world.state.prayer_system.requests[request].descriptor
		_choose_prayer_seed(data, "success", descriptor.subjects.petitioner, descriptor.domain)
		if not _accept(data, _response(data, request, "deep"), "actual_original_prayer_deep"): return false
		return _contract_witness_heads(data, request) if route == "contract_performance" else true
	if route == "contract_reciprocal":
		var second: String = _dream(data, data.other)
		if second.is_empty() or second == "missing_actual_dream" or not _next(data): return false
		if not _operate(data, "ROUTE_RECIPROCAL_COVENANT", {"record": record, "second_record": second, "other": data.other, "stage": "prepare"}) or not _next(data): return false
		for index: int in 2:
			if index > 0 and not _next(data): return false
			if not _operate(data, "ROUTE_RECIPROCAL_COVENANT", {"other": data.other, "stage": "perform"}): return false
		return true
	data.failure = "Missing finite test route"; return false

func _contract_witness_heads(data: Dictionary, request: String) -> bool:
	var heads: Array = []
	var valid: bool = true
	for person: String in [data.guardian, data.other]:
		var bucket: String = "anchor_materials/" + data.domain + "/" + person + "/contract_witness"
		var source: String = str(Store.entry(data.world.history._bucket(bucket), request, ""))
		var fact: Dictionary = Store.entry(data.world.state.facts, source, {})
		var material: Dictionary = ActualAnchors.material(data.world.state, source, catalog, data.world.history)
		var owned: bool = person in fact.get("targets", []) and person in material.get("originals", []) and fact.get("changes", {}).get("request") == request
		heads.append({"person": person, "source": source, "targets": fact.get("targets", []), "originals": material.get("originals", []), "actualTargetHead": owned})
		valid = valid and owned
	data["contractWitnessHeads"] = heads
	if not valid: data.failure = "Contract witness head does not belong to its actual endpoint"
	return valid

func _tail(data: Dictionary) -> bool:
	_mark(data, "basis/start")
	var permissions: Array = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history).filter(func(item: Dictionary) -> bool: return item.route == data.route)
	_mark(data, "basis/end")
	if permissions.size() != 1: data.failure = "Produced route has no unique current basis: " + str(permissions); return false
	var proof: String = permissions[0].source
	var opportunity: String = str(data.world.state.anchor_system.opportunities.get(data.institution, ""))
	if opportunity.is_empty(): data.failure = "Actual basis did not issue first relic opportunity"; return false
	# A prayer's response can leave only one whisper; its discovered opportunity
	# has the original lifetime, so this is a real later action, not a due extension.
	if not _next(data): return false
	if not _accept(data, _submit(data, "act", {"participant": "events", "action": "opportunity", "payload": {"opportunity": opportunity, "option": "recover"}}), "first_relic_recovery") or not _next(data): return false
	var relics: Array = Store.values(data.world.state.relics).filter(func(item: Dictionary) -> bool: return item.get("formal", false) and item.domain == data.domain)
	if relics.size() != 1: data.failure = "Recovery did not produce one actual relic"; return false
	var payload: Dictionary = {"npc": data.guardian, "institution": data.institution, "relic": relics[0].id, "source": proof, "qualification": proof}
	var before_preview: String = data.turn.snapshot()
	var guardian: Dictionary = Store.entry(data.world.state.npcs, data.guardian)
	data["anchorPreflight"] = {"preview": data.powers.preview(data.turn, "POWER_ANCHOR", payload), "worldQualification": ActualAnchors.qualify(data.world.state, data.institution, proof, catalog, data.world.history), "guardian": {"id": guardian.id, "status": guardian.status, "bound_member": guardian.bound_member, "cult_id": guardian.cult_id, "loyalty": guardian.loyalty, "binding_source": guardian.binding_source, "dedication_source": guardian.dedication_source}, "faith": data.world.state.faith, "whispers": data.world.state.whispers, "pollution": data.world.state.domains[data.domain].pollution, "turn": data.turn.context.turn, "currentRouteSource": data.world.state.anchor_system.routes.get(data.institution, {}).get(data.route, ""), "submittedSource": proof}
	data.anchorPreflight["pure"] = before_preview == data.turn.snapshot()
	print("CLOSURE_ANCHOR_PREFLIGHT ", data.route, " ", JSON.stringify(data.anchorPreflight))
	if not data.anchorPreflight.pure: data.failure = "Anchor preflight mutated authoritative state or RNG"; return false
	_seed(data, "POWER_ANCHOR", "success", payload)
	if not _accept(data, _power(data, "POWER_ANCHOR", payload), "actual_anchor_structure"): return false
	var id: String = "ANCHOR/" + data.institution
	if not data.world.state.anchors.has(id): data.failure = "Missing actual anchor structure"; return false
	var structure: Dictionary = data.world.state.anchors[id].duplicate(true)
	_mark(data, "upkeep/start")
	if structure.state != "dormant" or not _evolve(data): data.failure = "Structure skipped real prepay or evolution failed: " + data.turn.last_error; return false
	_mark(data, "upkeep/end")
	var current: Dictionary = data.world.state.anchors[id]
	var binding: Dictionary = data.world.state.anchor_system.bindings[id]
	var payments: Array = _facts(data.world, "economy_anchor_payment").filter(func(fact: Dictionary) -> bool: return fact.changes.anchor == id)
	var discoveries: Array = _facts(data.world, "institution_relic_opportunity").filter(func(fact: Dictionary) -> bool: return fact.changes.institution == data.institution)
	data["tail"] = {"basis": Store.entry(data.world.state.facts, proof), "opportunity": Store.entry(data.world.state.facts, opportunity), "relic": relics[0], "structureBeforePayment": structure, "activeAnchor": current.duplicate(true), "binding": binding.duplicate(true), "payments": payments, "opportunityCount": discoveries.size()}
	return current.state == "active" and current.route == data.route and binding.route == data.route and binding.proof == proof and discoveries.size() == 1 and current.ordinal == 1 and current.relic == relics[0].id and not payments.is_empty() and payments[-1].changes.fee == catalog.integer("anchor_" + str(data.world.state.domains[data.domain].tier) + "_upkeep")

func _mark(data: Dictionary, stage: String) -> void:
	var now: int = Time.get_ticks_msec()
	var entry: Dictionary = {"stage": stage, "elapsedMs": now - int(data.timingStart), "sincePreviousMarkerMs": now - int(data.timingPrevious)}
	data.timings.append(entry); data.timingPrevious = now
	print("CLOSURE_STAGE ", data.route, " ", JSON.stringify(entry))

func _closure_case(route: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	print("CLOSURE_START ", route)
	var data: Dictionary = _fixture(route)
	if data.has("fixtureFailure"): return {"route": route, "passed": false, "failure": data.fixtureFailure, "issues": data.issues}
	data["timingStart"] = started; data["timingPrevious"] = started; data["timings"] = []
	_mark(data, "fixture_ready")
	var blocked: bool = _blocked(data)
	_mark(data, "initial_alternative_control/end")
	var produced: bool = blocked and _produce(data)
	_mark(data, "production/end")
	var closed: bool = produced and _tail(data)
	var start_control: Dictionary = data.control.duplicate(true)
	if closed:
		closed = _finish(data) and _open(data) and _blocked(data)
	_mark(data, "final_alternative_control/end")
	data.control["start"] = start_control
	if not closed and data.failure.is_empty(): data.failure = "Closure invariant or original alternate rejection failed"
	var runtime_control_held: bool = (not BLOCKED.has(route) or catalog.tables.progression_route_operations[BLOCKED[route]].runtime_status == "design_only") and (route != "network_exchange" or not catalog.tables.powers.has("POWER_DREAM"))
	var outputs: Array = []
	for fact: Dictionary in Store.values(data.world.state.facts):
		if int(str(fact.id).trim_prefix("FACT-")) >= data.productionStart and fact.domain == data.domain and fact.kind in ["route_material", "miracle", "prayer_fact", "material_received", "anchor_basis", "institution_relic_opportunity", "anchor_institution_bound", "economy_anchor_payment"]: outputs.append(fact)
	return {"route": route, "profile": catalog.tables.anchor_route_rules[route].profile, "passed": closed and runtime_control_held, "failure": data.failure, "seed": data.seed, "domain": data.domain, "institution": data.institution, "people": data.people, "cult": data.cult, "controlledContentVersions": {"progression_route_operations": str(catalog.extension_versions.progression_route_operations), "powers": str(catalog.extension_versions.powers)}, "alternativeControl": data.control, "alternativeDisabledThroughoutChain": runtime_control_held, "negative": data.get("negative", {}), "contractWitnessHeads": data.get("contractWitnessHeads", []), "anchorPreflight": data.get("anchorPreflight", {}), "actions": data.actions, "actualOutputs": outputs, "tail": data.get("tail", {}), "timings": data.timings}
