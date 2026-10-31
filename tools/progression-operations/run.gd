extends "res://tools/cult-spread/run.gd"
const Routes = preload("res://src/game/progression_routes.gd")
const RouteResistance = preload("res://src/game/resistance.gd")
const RouteEndings = preload("res://src/game/endings.gd")
var route_fixture: Dictionary = {}

class ContactWorld extends RefCounted:
	var state: Dictionary
	var history: RefCounted
	var attention: RefCounted

class ContactTurn extends RefCounted:
	const View = preload("res://src/simulation/state_view.gd")
	var world: RefCounted
	var context: Dictionary
	var _participants: Dictionary
	func _read_view(id: String, slot: String) -> Dictionary:
		return View.new(world.state, context, 0, world.history).participant(id, slot)

func _initialize() -> void:
	catalog = Catalog.new()
	scratch = OS.get_cmdline_user_args()[0].get_base_dir()
	if catalog.load_files():
		_contacts_and_organization()
		_material_production()
		_memory_and_contract()
		_full_player_session()
	else: _check("PO-CATALOG", "Current authored content loads", false, {"errors": catalog.errors})
	var passed: bool = records.size() == 4 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "scope": "four_bounded_progression_capability_groups", "fixtures": ["Existing generated people, authored roles, original contacts, voluntary dedication/member admission, 80 faith and 10 insight are explicit prerequisites; target route materials and cult formation are produced by actual actions.", "Successful check rolls are controlled inputs, not naturally observed success rates. Cosmic domain access uses the original attention admission/expansion path.", "Component Turn save/restore is distinct from mature complete Session continuation. Only the separate actual Session.start_new case establishes installation and a finite first player window.", "No natural first-cult balance, all-eight alternate active-anchor closure, scheduler waiting bound, full campaign save, UI aesthetics or release performance claim."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _route_base(cosmic: bool = false, bound_all: bool = true, teacher_pair: bool = false) -> Dictionary:
	if cosmic:
		var cosmic_data: Dictionary = _route_base(false, bound_all)
		var cosmic_domain: String = ""
		for id: String in cosmic_data.world.state.domains:
			if cosmic_data.world.state.domains[id].tier == "cosmic": cosmic_domain = id; break
		var admitted: Dictionary = _submit(cosmic_data, "attention", {"command": {"kind": "focus", "domain": cosmic_domain}})
		assert(admitted.get("ok", false), "Cosmic prerequisite uses the managed focus action: " + str(admitted))
		cosmic_data.domain = cosmic_domain; cosmic_data.source = cosmic_data.world.state.domains[cosmic_domain].origin
		cosmic_data.people = cosmic_data.world.history.ids("active/" + cosmic_domain); cosmic_data.people.sort()
		assert(cosmic_data.people.size() >= 4)
		return cosmic_data
	var world: RefCounted = Support.new_world(catalog, 1)
	var domain: String = "DOMAIN-001"
	var people: Array = world.history.ids("active/" + domain); people.sort()
	assert(people.size() >= 4)
	var source: String = world.state.domains[domain].origin
	for role: String in ([] if cosmic else ["record_keeper", "ritual_keeper"]):
		if people.any(func(id: String) -> bool: return role in Store.entry(world.state.npcs, id).role_tags): continue
		var nominated: String = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01" if role == "record_keeper" else "NPC_PROFILE_02", source))
		people.append(nominated)
	var data: Dictionary = {"world": world, "domain": domain, "source": source, "people": people, "contacts": {}, "dreams": {}}
	if teacher_pair:
		var teacher: String = people.filter(func(id: String) -> bool: return "ritual_keeper" in Store.entry(world.state.npcs, id).role_tags)[0]
		var person: Dictionary = Store.entry(world.state.npcs, teacher)
		var students: Array = people.filter(func(id: String) -> bool: return id != teacher and Store.entry(world.state.npcs, id).institution == person.institution and Array(Store.entry(world.state.npcs, id).need_tags).any(func(need: String) -> bool: return need in person.need_tags))
		if students.is_empty():
			var student: String = "NPC-%08d" % int(world.state.next_npc)
			assert(world._nominate_local(domain, person.institution, "NPC_PROFILE_02", source))
			people.append(student); students.append(student)
		data["teacher"] = teacher; data["student"] = students[0]
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog)); accepted.merge(PlayerSources.issuer_capability(catalog))
	data.economy = Economy.new(catalog, accepted)
	assert(data.economy.initialize(world))
	world.state.faith = 80; world.state.insight = 10; world._refresh_anchors()
	for id: String in people:
		if bound_all: _bind(world, id)
		else: _dedicate(world, id)
		var contact: String = world._record("devotion_contact", domain, id, [id], [source], {"subject": id, "institution": Store.entry(world.state.npcs, id).institution})
		world._know(id, contact)
		data.contacts[id] = contact
		data.dreams[id] = _qualification(data, "dream", id, id, domain, {"contact": contact}, Store.entry(world.state.npcs, id).institution)
	data.turn = Turn.new(world)
	assert(data.turn._attached and data.economy.install(data.turn))
	data.fixture = Fixture.new(); data.fixture.domain = domain
	assert(data.turn.register_participant("cult-fixture", "1", ["deadlines"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog); data.relics = Relics.new(catalog, accepted); data.powers = Powers.new(catalog, accepted); data.prayers = Prayers.new(catalog, accepted); data.anchors = ActualAnchors.new(catalog, accepted); data.events = Events.new(catalog); data.resistance = RouteResistance.new(catalog); data.endings = RouteEndings.new(catalog); data.player_sources = PlayerSources.new(catalog); data.routes = Routes.new(catalog)
	for name: String in ["cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources", "routes"]:
		assert(data[name].install(data.turn), "Actual module installation: " + name)
	assert(_boot(data).get("ok", false) and _open(data))
	return data

func _route(data: Dictionary, operation: String, fields: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {"npc": data.actor, "source": data.source}; payload.merge(fields, true)
	var prepared: Dictionary = data.routes.preview(data.turn, operation, payload)
	if prepared.get("ok", false) and prepared.probability >= 0:
		for seed_value: int in range(1, 101):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
			if data.world.check_result(prepared.probability, rng.randi_range(1, 100)) == "success": data.world.randoms.checks.seed = seed_value; break
	request_sequence += 1
	var request: Dictionary = {"id": "PO-" + str(request_sequence), "op": "act", "turn": data.turn.context.turn, "phase": data.turn.context.phase, "participant": Routes.ID, "action": operation, "payload": payload}
	data["last_request"] = request.duplicate(true)
	var result: Dictionary = data.turn.submit(request)
	if not result.ok: print("ROUTE_REJECTED ", operation, " ", prepared, " ", result)
	return result

func _route_next(data: Dictionary) -> bool:
	return _evolve(data) and _finish(data) and _open(data)

func _role(data: Dictionary, tag: String) -> String:
	for id: String in data.people:
		if tag in Store.entry(data.world.state.npcs, id).role_tags: return id
	return ""

func _dream_actual(data: Dictionary, person: String) -> Dictionary:
	var payload: Dictionary = {"npc": person, "source": data.contacts[person], "qualification": data.dreams[person]}
	_seed(data, "POWER_DREAM", "success", payload)
	return _power(data, "POWER_DREAM", payload)

func _route_materials(data: Dictionary, tag: String) -> Array:
	return _facts(data.world, "route_material").filter(func(fact: Dictionary) -> bool: return fact.changes.get("tag") == tag)

func _route_basis(data: Dictionary, route: String) -> Array:
	var result: Array = []
	for institution: String in data.world.state.progression_routes.bases:
		var basis: Dictionary = data.world.state.progression_routes.bases[institution].get(route, {})
		if not basis.is_empty(): result.append({"institution": institution, "basis": basis})
	return result

func _route_context_source(data: Dictionary, operation: String) -> String:
	for entry: Dictionary in data.world.state.progression_routes.progress.values():
		if entry.operation == operation and entry.npc == data.actor: return str(entry.get("context", ""))
	return ""

func _offered_route_context(data: Dictionary, source: String) -> String:
	for id: String in data.world.state.prayer_system.offered:
		if data.world.state.prayer_system.requests[id].descriptor.source == source: return id
	return ""

func _unfocused_contact_control(data: Dictionary, full: bool) -> Dictionary:
	# Read-only next-window consumer controls. This does not claim an actual
	# focus transfer, complete alternate campaign or saved counterfactual state.
	var shadow: Dictionary = History.export_value(data.world.state)
	shadow.simulation.candidates = {}; shadow.simulation.focused = []
	shadow.prayer_system.offered = []; shadow.prayer_system.requests = {}
	shadow.anchor_system.opportunities = {}; shadow.cults = {}
	shadow.attention.release = {}; shadow.attention.reservations = {}
	if full:
		for domain: String in shadow.domains:
			if domain == data.domain: continue
			shadow.simulation.focused.append(domain)
			if shadow.simulation.focused.size() == int(data.world.attention.parameters.focused_domain_limit): break
	var index: RefCounted = History.new(); index.rebuild(shadow)
	var world: RefCounted = ContactWorld.new(); world.state = shadow; world.history = index; world.attention = data.world.attention
	var query: RefCounted = ContactTurn.new(); query.world = world; query.context = History.export_value(data.turn.context); query._participants = data.turn._participants
	var contacts: Array = data.endings.contacts(query)
	return {"kind": "read_only_next_window_counterfactual", "fullFocusBudget": full, "contacts": contacts, "actorEligible": contacts.any(func(item: Dictionary) -> bool: return item.kind == "private_devotion" and item.subject == data.actor)}

func _contacts_and_organization() -> void:
	var data: Dictionary = _route_base(false, false); data.actor = _role(data, "record_keeper")
	var private_payload: Dictionary = {"npc": data.actor, "source": data.source}
	var no_identity: Dictionary = data.routes.preview(data.turn, "ROUTE_PRIVATE_DEVOTION", private_payload)
	var absent_cult: bool = data.world.state.cults.is_empty()
	var initially_unbound: bool = not Store.entry(data.world.state.npcs, data.actor).get("bound_member", false)
	var dream: Dictionary = _dream_actual(data, data.actor)
	var valid: bool = absent_cult and not no_identity.ok and dream.ok and _route_next(data)
	var before: String = data.turn.snapshot()
	var contacts: Array = data.endings.contacts(data.turn)
	var pure: bool = before == data.turn.snapshot()
	var next_view: Dictionary = data.endings._next_view(data.turn)
	var real_next_prepare: Dictionary = data.routes.prepare(next_view, "ROUTE_PRIVATE_DEVOTION", {"npc": data.actor, "source": Store.entry(data.world.state.npcs, data.actor).dedication_source})
	next_view.reader.close()
	var unfocused: Dictionary = _unfocused_contact_control(data, false)
	var saturated: Dictionary = _unfocused_contact_control(data, true)
	var devotion: Dictionary = _route(data, "ROUTE_PRIVATE_DEVOTION") if valid else {}
	valid = valid and initially_unbound and pure and real_next_prepare.get("ok", false) and unfocused.actorEligible and not saturated.actorEligible and devotion.get("ok", false) and Store.entry(data.world.state.npcs, data.actor).get("bound_member", false) and data.world.state.cults.is_empty() and _route_next(data)
	var actions: Array = []
	for attempt: int in 2:
		if not valid: break
		var paid_before: int = data.world.state.faith
		var action: Dictionary = _route(data, "ROUTE_COVERT_GATHERING"); actions.append(action)
		valid = action.ok and data.world.state.faith == paid_before - 4 and _route_next(data)
	var formed: Array = _facts(data.world, "cult_established")
	valid = valid and formed.size() == 1 and data.world.state.domains[data.domain].unnamed_followers == 6 and int(data.world.state.cult_system.spend[data.domain].amount) >= 8
	route_fixture = data
	_check("PO-CONTACT", "Known willing unbound contact uses actual prepare/enrollment; no existing cult is required for two paid gatherings and original formation", valid, {"noIdentityRejected": no_identity, "initiallyNoCult": absent_cult, "initiallyUnbound": initially_unbound, "dream": dream, "endingContacts": contacts, "nextWindowActualPrepare": real_next_prepare, "unfocusedContactControl": unfocused, "fullFocusControl": saturated, "contactPreviewPure": pure, "privateDevotion": devotion, "gatherings": actions, "formed": formed})

func _material_production() -> void:
	var data: Dictionary = _route_base(false, true, true); data.actor = _role(data, "record_keeper")
	var valid: bool = not str(data.actor).is_empty()
	var first: Dictionary = _route(data, "ROUTE_RECORD_PRACTICE") if valid else {}
	var premature: bool = _route_basis(data, "record_dependency").is_empty()
	var saved: String = data.turn.snapshot()
	var duplicate: Dictionary = _route(data, "ROUTE_RECORD_PRACTICE")
	var duplicate_atomic: bool = not duplicate.ok and saved == data.turn.snapshot()
	valid = valid and first.get("ok", false) and premature and duplicate_atomic and _route_next(data)
	var second: Dictionary = _route(data, "ROUTE_RECORD_PRACTICE") if valid else {}
	var dependencies: Array = _route_materials(data, "record_dependency")
	var resolved: Dictionary = {} if dependencies.is_empty() else Materials.resolve(data.world.state, dependencies[0].id, catalog, data.world.history)
	var available: Array = ActualAnchors.available(data.world.state, str(Store.entry(data.world.state.npcs, data.actor).institution), catalog, data.world.history)
	valid = valid and second.get("ok", false) and dependencies.size() == 1 and resolved.get("ok", false) and not _route_basis(data, "record_dependency").is_empty() and not available.is_empty()
	var priest: String = _role(data, "ritual_keeper")
	var rite: Dictionary = {}; var second_rite: Dictionary = {}; var network: Dictionary = {}; var cosmic: Dictionary = {}; var pair: Array = []; var teaching: Dictionary = {}
	if valid and not priest.is_empty() and _route_next(data):
		data.actor = priest; rite = _route(data, "ROUTE_CALENDAR_RITE")
		valid = rite.ok and _route_materials(data, "performed_rite").size() == 1 and data.world.state.cults.is_empty() and _route_next(data)
		if valid:
			second_rite = _route(data, "ROUTE_CALENDAR_RITE")
			valid = second_rite.ok and _route_materials(data, "performed_rite").size() == 2 and _route_next(data) and _facts(data.world, "cult_established").size() == 1
		data.actor = data.people[0]
		var other: String = ""
		for id: String in data.people:
			if Store.entry(data.world.state.npcs, id).institution != Store.entry(data.world.state.npcs, data.actor).institution: other = id; break
		network = _route(data, "ROUTE_NETWORK_EXCHANGE", {"other": other})
		var exchanges: Array = _route_materials(data, "network_dependency")
		valid = valid and network.ok and exchanges.size() == 1 and Materials.resolve(data.world.state, exchanges[0].id, catalog, data.world.history).get("ok", false)
		if valid and _route_next(data):
			var dream: Dictionary = _dream_actual(data, data.actor)
			var dreams: Array = _facts(data.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.actor == data.actor and fact.changes.get("power") == "POWER_DREAM")
			valid = dream.ok and not dreams.is_empty() and _route_next(data)
			for step: int in 2:
				if not valid: break
				var practice: Dictionary = _route(data, "ROUTE_MEMORY_PRACTICE", {"other": other, "record": dreams[-1].id}); pair.append(practice)
				valid = practice.ok
				if step == 0: valid = valid and _route_basis(data, "memory_practice").is_empty() and _route_next(data)
			var pair_bases: Array = _route_basis(data, "memory_practice")
			var pair_dependencies: Array = _route_materials(data, "recollection_dependency")
			valid = valid and pair_bases.size() == 1 and pair_dependencies.size() == 1 and pair_dependencies[0].changes.data.registrations == pair_bases[0].basis.registrations and Materials.resolve(data.world.state, pair_dependencies[0].id, catalog, data.world.history).get("ok", false)
		if valid and _route_next(data):
			data.actor = data.teacher
			var cooperation: Dictionary = _route(data, "ROUTE_JOINT_WORK", {"other": data.student})
			valid = cooperation.ok and _route_next(data)
			var lesson_key: String = ""
			var taught: Dictionary = {}
			if valid:
				var preview: Dictionary = data.routes.preview(data.turn, "ROUTE_RITUAL_TRANSMISSION", {"npc": data.teacher, "source": data.source, "other": data.student})
				lesson_key = str(preview.get("key", ""))
				taught = _route(data, "ROUTE_RITUAL_TRANSMISSION", {"other": data.student})
				valid = taught.ok and _route_materials(data, "practiced_rite").is_empty() and _route_next(data)
			var performed: Dictionary = {}
			if valid:
				data.actor = data.student
				performed = _route(data, "ROUTE_RITUAL_TRANSMISSION", {"target": lesson_key})
				var actual: Array = _route_materials(data, "practiced_rite")
				valid = performed.ok and actual.size() == 1 and actual[0].actor == data.student and actual[0].changes.originals == [data.student] and Store.entry(data.world.state.npcs, data.teacher).acted_turn != data.world.state.turn
			teaching = {"cooperation": cooperation, "lesson": taught, "key": lesson_key, "studentPerformance": performed}
	else: valid = false
	var astronomy: Dictionary = _route_base(true); astronomy.actor = astronomy.people[0]
	var observed: Dictionary = _route(astronomy, "ROUTE_AXIOM_PROBE")
	var one: Array = _route_materials(astronomy, "axiom_record")
	var other_node: String = ""
	for id: String in astronomy.people:
		if Store.entry(astronomy.world.state.npcs, id).institution != Store.entry(astronomy.world.state.npcs, astronomy.actor).institution: other_node = id; break
	if observed.ok and one.size() == 1 and _route_next(astronomy):
		astronomy.actor = other_node
		var recheck: Dictionary = _route(astronomy, "ROUTE_AXIOM_RECHECK", {"target": one[0].changes.data.exception})
		var observations: Array = _route_materials(astronomy, "axiom_record")
		var normalized: Array = observations.map(func(item: Dictionary) -> Dictionary: return ActualAnchors.material(astronomy.world.state, item.id, catalog, astronomy.world.history))
		cosmic = {"first": observed, "second": recheck, "normalized": normalized}
		valid = valid and recheck.ok and normalized.size() == 2 and normalized[0].root != normalized[1].root and normalized[0].data.exception == normalized[1].data.exception
		astronomy.actor = astronomy.people[0]
		var repeats: Array = []
		for step: int in 2:
			if not valid or not _route_next(astronomy): valid = false; break
			var repeated: Dictionary = _route(astronomy, "ROUTE_AXIOM_REPEAT", {"target": one[0].changes.data.exception}); repeats.append(repeated)
			valid = repeated.ok
		var archive: Array = _route_materials(astronomy, "axiom_dependency")
		cosmic["repeatUses"] = repeats
		valid = valid and archive.size() == 1 and Materials.resolve(astronomy.world.state, archive[0].id, catalog, astronomy.world.history).get("ok", false)
	else: valid = false
	_check("PO-MATERIAL", "Distinct-turn operator/pair uses, student-owned later rite, paid first-cult rites, network and same-exception observations reach shared raw consumers", valid, {"firstUse": first, "noPrematureDependency": premature, "sameTurnRejectedWithoutCost": duplicate_atomic, "secondUse": second, "resolvedDependency": resolved, "currentPermissions": available, "rite": rite, "secondRite": second_rite, "network": network, "pair": pair, "teaching": teaching, "cosmic": cosmic, "unrunParameterArms": ["calendar_keeping", "dissent_practice"]})

func _memory_and_contract() -> void:
	var data: Dictionary = _route_base()
	data.actor = _role(data, "record_keeper")
	var produced: Dictionary = _dream_actual(data, data.actor)
	var valid: bool = produced.ok and _route_next(data)
	var miracles: Array = _facts(data.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.actor == data.actor and fact.changes.get("power") == "POWER_DREAM")
	var record: String = miracles[-1].id if not miracles.is_empty() else ""
	var others: Array = data.people.filter(func(id: String) -> bool: return id != data.actor).slice(0, 3)
	var circle: Dictionary = _route(data, "ROUTE_MEMORY_CIRCLE", {"record": record, "participants": others}) if valid else {}
	var circle_source: String = _route_context_source(data, "ROUTE_MEMORY_CIRCLE")
	# The source is produced by the paid action, then offered by the original
	# freeze pipeline. No target prayer or qualification is injected.
	valid = valid and circle.get("ok", false) and _route_next(data)
	var memory_request: String = _offered_route_context(data, circle_source)
	var preserved: Dictionary = {}
	if valid and not memory_request.is_empty():
		var request: String = memory_request
		var original: Dictionary = data.world.state.prayer_system.requests[request].descriptor
		_choose_prayer_seed(data, "success", original.subjects.petitioner, original.domain)
		preserved = _response(data, request, "deep")
		valid = preserved.ok and _memory_qualifications(data.world, original.facts.memory).size() == 3
	else: valid = false
	var other: String = ""
	for id: String in data.people:
		if Store.entry(data.world.state.npcs, id).institution != Store.entry(data.world.state.npcs, data.actor).institution: other = id; break
	var agreement: Dictionary = {}; var performed: Dictionary = {}; var covenant: Dictionary = {}; var legs: Array = []; var receptions: Array = []
	var second_record: String = ""; var contract_source: String = ""; var contract_request: String = ""
	if valid and _route_next(data):
		var second_dream: Dictionary = _dream_actual(data, other)
		var actual_dreams: Array = _facts(data.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.actor == other and fact.changes.get("power") == "POWER_DREAM")
		valid = second_dream.ok and not actual_dreams.is_empty() and _route_next(data)
		if valid:
			second_record = actual_dreams[-1].id
			agreement = _route(data, "ROUTE_PACT_AGREEMENT", {"record": record, "other": other})
			contract_source = _route_context_source(data, "ROUTE_PACT_AGREEMENT")
			valid = agreement.ok and not contract_source.is_empty() and _route_next(data)
	if valid:
		contract_request = _offered_route_context(data, contract_source)
		valid = not contract_request.is_empty()
		if valid:
			var descriptor: Dictionary = data.world.state.prayer_system.requests[contract_request].descriptor
			_choose_prayer_seed(data, "success", descriptor.subjects.petitioner, descriptor.domain)
			performed = _response(data, contract_request, "deep")
			valid = performed.ok and _contract_materials(data, contract_request, "contract_dependency").size() == 1 and _route_next(data)
	if valid:
		covenant = _route(data, "ROUTE_RECIPROCAL_COVENANT", {"record": record, "second_record": second_record, "other": other, "stage": "prepare"})
		valid = covenant.ok and _route_basis(data, "contract_reciprocal").is_empty() and _route_next(data)
	for position: int in 2:
		if not valid: break
		var leg: Dictionary = _route(data, "ROUTE_RECIPROCAL_COVENANT", {"other": other, "stage": "perform"}); legs.append(leg)
		receptions = _facts(data.world, "material_received").filter(func(fact: Dictionary) -> bool: return fact.changes.get("channel", {}).get("kind") == "reciprocal")
		valid = leg.ok and receptions.size() == position + 1 and _route_materials(data, "reciprocal_leg").size() == position + 1
		if position == 0: valid = valid and _route_basis(data, "contract_reciprocal").is_empty() and _route_next(data)
	valid = valid and _route_basis(data, "contract_reciprocal").size() == 1 and _route_materials(data, "reciprocal_dependency").size() == 1
	route_fixture = data
	_check("PO-MEMORY-CONTRACT", "Original action-created PR07/PR06 responses and two distinct-turn reciprocal legs use real material reception", valid, {"actualInitialRecord": produced, "circle": circle, "memoryRequest": memory_request, "preserved": preserved, "agreement": agreement, "contractRequest": contract_request, "performed": performed, "covenant": covenant, "legs": legs, "receptions": receptions, "reciprocalBasis": _route_basis(data, "contract_reciprocal")})

func _session_route_choice(session: RefCounted) -> Dictionary:
	for id: String in session.current_people():
		var person: Dictionary = Store.entry(session.world.state.npcs, id)
		var source: String = ""
		for known: String in session.current_sources():
			if Store.entry(session.world.state.facts, known).domain == person.domain: source = known; break
		var operations: Array = []
		if "record_keeper" in person.role_tags: operations.append("ROUTE_RECORD_PRACTICE")
		if "ritual_keeper" in person.role_tags: operations.append("ROUTE_CALENDAR_RITE")
		if person.get("bound_member", false): operations.append("ROUTE_COVERT_GATHERING")
		for operation: String in operations:
			var choice: Dictionary = {"domain": person.domain, "npc": id, "source": source, "operation": operation}
			if session.preview_action("route/context", choice).get("ok", false): return choice
	return {}

func _session_round(session: RefCounted) -> Array:
	var cycle: Array = [session._submit("end_actions")]
	for step: int in 4: cycle.append(session._submit("advance"))
	cycle.append(session._submit("finish_events"))
	return cycle

func _controlled_route_projection(data: Dictionary) -> Dictionary:
	# This is the real presenter over the prior group's actual delivered materials.
	# Its controlled selection fields do not assert a CIV06 menu in this CIV01 fixture.
	var presenter: RefCounted = Session.new()
	presenter.catalog = catalog; presenter.world = data.world; presenter.turn = data.turn
	presenter._known_domains[data.domain] = true
	var entry: Dictionary = {}
	for progress: Dictionary in data.world.state.progression_routes.progress.values():
		if progress.operation == "ROUTE_RECIPROCAL_COVENANT": entry = progress; break
	if entry.is_empty(): return {"pass": false}
	for id: String in entry.people: presenter._known_people[id] = true
	for id: String in entry.records: presenter._learn(id)
	var actions: RefCounted = Session.Actions.new()
	var selection: Dictionary = {"npc": entry.npc, "operation": entry.operation, "other": entry.people[1], "record": entry.records[0]}
	var fields: Array = []
	for key: String in selection:
		fields.append(actions._field(key, key, [actions._choice(selection[key], "互惠交付" if key == "operation" else "已知选择")]))
	var before: String = data.turn.snapshot()
	var projected: Dictionary = actions._route_details(presenter, selection, fields)
	var terms: Array = projected.get("原两项条款", [])
	var valid: bool = projected.get("已完成交付") == 2 and projected.get("所需交付") == 2 and terms.size() == 2
	for index: int in terms.size():
		valid = valid and terms[index].get("原记录") == presenter.object_title(entry.records[index]) and terms[index].get("交予者") == presenter.object_title(entry.people[1 - index]) and terms[index].get("接收者") == presenter.object_title(entry.people[index]) and terms[index].get("状态") == "已完成"
	presenter._known_facts.erase(entry.records[0])
	var hidden: Dictionary = actions._route_details(presenter, selection, fields)
	valid = valid and hidden.get("原两项条款", [{}])[0].get("原记录") == "尚未知晓的记录" and not JSON.stringify(hidden).contains(entry.records[0])
	var encoded: String = JSON.stringify(projected)
	for private_key: String in ["issuer", "record_roots", "route_attempt", "causal_parents", "version"]: valid = valid and not encoded.contains(private_key)
	var reasons: Dictionary = {}
	for error: String in ["A later turn is required", "Participant unavailable or already acted", "Original student must personally perform on a later turn", "Continue the fixed covenant rather than replace its terms", "Outstanding original reciprocal leg required", "Private devotion needs actual deity knowledge", "Private devotion needs current willingness", "No current capacity for this fixed request"]:
		reasons[error] = presenter.explain_error(error)
		valid = valid and reasons[error] != error and reasons[error] != "当前对象、来源、资源或阶段不符合执行条件"
	valid = valid and before == data.turn.snapshot()
	return {"pass": valid, "kind": "controlled_presenter_over_actual_two_leg_results", "details": projected, "unknownRecordHidden": hidden.get("原两项条款", [{}])[0].get("原记录") == "尚未知晓的记录", "reasons": reasons, "pure": before == data.turn.snapshot()}

func _full_player_session() -> void:
	var session: RefCounted = Session.new(scratch.path_join("session-campaigns"))
	var opened: Dictionary = session.start_new(1)
	var valid: bool = opened.get("ok", false) and session.modules.size() == 11 and session.modules.has("progression_routes")
	if valid and session.turn.context.phase == "events": valid = session._submit("finish_events").ok
	var actions: Array = session.action_catalog() if valid else []
	var route_rows: Array = actions.filter(func(row: Dictionary) -> bool: return str(row.key).begins_with("route/"))
	var before: String = session.turn.snapshot() if valid else ""
	var rejected: Dictionary = session.execute_action("route/context", {"operation": "ROUTE_PRIVATE_DEVOTION", "npc": "", "source": ""}, true) if valid else {}
	var atomic: bool = valid and not rejected.get("ok", false) and before == session.turn.snapshot()
	var selection: Dictionary = {}; var selected_row: Dictionary = {}; var action: Dictionary = {}; var first_response: Dictionary = {}; var warmup: Array = []
	if valid:
		selection = _session_route_choice(session)
		if selection.is_empty():
			for id: String in session.world.state.prayer_system.offered:
				var request: Dictionary = session.prayer_entry(id)
				if request.get("descriptor", {}).get("content_id") != "PRAYER_08": continue
				var descriptor: Dictionary = request.descriptor
				_choose_prayer_seed({"world": session.world}, "success", descriptor.subjects.petitioner, descriptor.domain)
				first_response = session.execute_action("prayer/" + id + "/shallow", {}, true, "PO-SESSION-INITIAL-DEVOTION")
				break
			if first_response.get("ok", false):
				warmup = _session_round(session)
				if warmup.all(func(value: Dictionary) -> bool: return value.get("ok", false)): selection = _session_route_choice(session)
		for row: Dictionary in session.action_catalog(selection):
			if row.key == "route/context": selected_row = row; break
		var payload: Dictionary = selection.duplicate(); payload.erase("domain"); payload.erase("operation")
		var plan: Dictionary = session.modules.progression_routes.preview(session.turn, str(selection.get("operation", "")), payload)
		if plan.get("ok", false):
			for seed_value: int in range(1, 101):
				var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
				if session.world.check_result(plan.probability, rng.randi_range(1, 100)) == "success": session.world.randoms.checks.seed = seed_value; break
		action = session.execute_action("route/context", selection, true, "PO-SESSION-ACTION")
		var actual_output: bool = not _facts(session.world, "route_material").is_empty() or (not selection.is_empty() and int(session.world.state.domains[selection.domain].unnamed_followers) > 0)
		valid = selected_row.get("available", false) and action.get("ok", false) and actual_output
	var public_progress: Dictionary = {}; var public_preview: Dictionary = {}
	if valid:
		var before_query: String = session.turn.snapshot()
		for row: Dictionary in session.action_catalog(selection):
			if row.key == "route/context": public_progress = row.details; public_preview = row.preview; break
		valid = public_progress.get("成功回合") == 1 and public_progress.get("所需成功回合") == 2 and public_preview.get("当前进展") == public_progress and public_preview.get("error") == session.explain_error("Participant unavailable or already acted") and before_query == session.turn.snapshot()
	var component_projection: Dictionary = _controlled_route_projection(route_fixture)
	valid = valid and component_projection.get("pass", false)
	var cycle: Array = []
	if valid:
		cycle = _session_round(session)
	valid = valid and cycle.all(func(result: Dictionary) -> bool: return result.get("ok", false)) and session.turn.context.turn == (2 if warmup.is_empty() else 3) and session.turn.context.phase == "actions"
	var data: Dictionary = route_fixture
	var serialized: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(serialized) and serialized == data.turn.snapshot()
	var repeated: Dictionary = data.turn.submit(data.last_request)
	var once: bool = repeated.get("ok", false) and serialized == data.turn.snapshot()
	valid = valid and not route_rows.is_empty() and atomic and restored and once
	_check("PO-SESSION", "Actual eleven-module new game exposes one contextual route selector, executes a real action and full round; rejection and component durable once hold", valid, {"startup": opened, "installed": session.modules.keys(), "routeRows": route_rows.size(), "initialDevotionIfNeeded": first_response, "warmupIfNeeded": warmup, "selected": selection, "available": selected_row.get("available", false), "action": action, "invalidAction": rejected, "atomicReject": atomic, "publicRouteProgress": public_progress, "publicRoutePreview": public_preview, "controlledReciprocalProjection": component_projection, "fullRound": cycle, "componentRestored": restored, "durableReplay": repeated, "once": once})
