extends "res://tools/material-transfer/run.gd"
const Spread = preload("res://src/game/cult-spread.gd")

class EventWorld extends ReceptionRejectWorld:
	var validation_errors: Array[String] = []
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if not issues.is_empty(): validation_errors = issues.duplicate()
		return issues

func _attach_dispatch(data: Dictionary) -> Dictionary:
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog)); accepted.merge(PlayerSources.issuer_capability(catalog))
	if data.world.state.has("economy"): data.world.state.economy.issuers = accepted.duplicate(true)
	# Controlled existing-campaign insight/funding; no cult/material result is
	# synthesized by this prerequisite. Production equations remain unchanged.
	data.world.state.insight = 10; data.world._refresh_anchors()
	data.economy = Economy.new(catalog, accepted)
	data.turn = Turn.new(data.world)
	assert(data.turn._attached and data.economy.install(data.turn))
	data.fixture = Fixture.new()
	assert(data.turn.register_participant("cult-fixture", "1", ["deadlines", "ending"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog); data.relics = Relics.new(catalog, accepted); data.powers = Powers.new(catalog, accepted); data.prayers = Prayers.new(catalog, accepted); data.events = Events.new(catalog); data.player_sources = PlayerSources.new(catalog)
	assert(data.cults.install(data.turn) and data.relics.install(data.turn) and data.powers.install(data.turn) and data.prayers.install(data.turn) and data.events.install(data.turn) and data.player_sources.install(data.turn))
	return data

func _initialize() -> void:
	catalog = Catalog.new()
	if catalog.load_files():
		_setup_materials()
		var setup: Array = records.duplicate(true); records.clear()
		_expansion(setup)
		_seed_result()
		_event_transactions()
		await _full_session()
	else: _check("CS-CATALOG", "Current Catalog", false, {"errors": catalog.errors})
	var passed: bool = records.size() == 4 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "checks": records, "engine": Engine.get_version_info().string, "scope": "four_bounded_cult_spread_groups", "fixtures": ["Existing sourced cult, membership, initial 20 faith and 10 insight are controlled campaign prerequisites.", "Successful check seeds and original dispute/ritual/contact scenarios are explicit inputs; dream, prayer, event, route, receipt, qualification, cost and growth outputs are production.", "First-cult operations, alternate raw producers, relic lifecycle, full Session continuation and natural balance remain downstream."]}, "\t", true, true) + "\n")
	file.close(); quit(0 if passed else 1)

func _expansion(setup: Array) -> void:
	var data: Dictionary = transfer_data
	var plan: Dictionary = {"strategies": {data.cult: "expand"}}
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.economy.preview(data.world.state, plan, data.world.history)
	var row: Dictionary = _integration_cult_row(preview, data.cult)
	var pure: bool = before == data.turn.snapshot()
	var shadow: Dictionary = History.export_value(data.world.state)
	for source: String in shadow.cult_system.spread_routes[data.cult]: shadow.invalid_records[source] = data.source
	var missing: Dictionary = data.economy.preview(shadow, plan)
	var no_source: Dictionary = _integration_cult_row(missing, data.cult)
	var selected: Dictionary = Spread.select(data.world.state, data.cult, data.world.history)
	var followers: int = data.world.state.domains["DOMAIN-001"].unnamed_followers
	var planned: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": plan})
	var evolved: bool = planned.ok and _evolve(data)
	var work: Array = _facts(data.world, "economy_work").filter(func(fact: Dictionary) -> bool: return fact.turn == data.world.state.turn and fact.changes.get("cult") == data.cult)
	var payments: Array = _facts(data.world, "economy_strategy_payment").filter(func(fact: Dictionary) -> bool: return fact.turn == data.world.state.turn and fact.changes.get("cult") == data.cult)
	var resumed: bool = evolved and _finish(data) and _open(data)
	_check("CS-EXPANSION", "Actual existing cult recruits without official permission; missing channel holds without fee; preview is pure", setup.size() == 1 and setup[0].status == "pass" and pure and row.get("effective") == "expand" and row.get("fee") == catalog.integer("expansion_faith_cost") and no_source.get("effective") == "hold" and no_source.get("fee") == 0 and not selected.is_empty() and selected.route.changes.route_id == "COVERT_CELL" and work.size() == 1 and work[0].changes.growth > 0 and payments.size() == 1 and resumed, {"sourceSetup": setup, "preview": preview, "missingSource": missing, "cell": selected, "work": work, "payments": payments, "followersBefore": followers, "pure": pure})

func _integration_cult_row(preview: Dictionary, cult: String) -> Dictionary:
	for row: Dictionary in preview.get("preview", {}).get("cults", []):
		if row.cult == cult: return row
	return {}

func _seed_result() -> void:
	var data: Dictionary = transfer_data
	var before: String = data.turn.snapshot()
	var absent: Array = data.player_sources.available(data.turn).filter(func(fact: Dictionary) -> bool: return fact.changes.rule == "spread")
	var delivered: Dictionary = _submit(data, "act", {"participant": "cults", "action": "transfer_material", "payload": data.payload})
	var proofs: Array = data.player_sources.available(data.turn).filter(func(fact: Dictionary) -> bool: return fact.changes.rule == "spread" and fact.actor == data.recipient)
	var preview: Dictionary = {}; var action: Dictionary = {}; var pure: bool = false; var forged: bool = false; var stale: bool = false; var selector: Dictionary = {}
	if proofs.size() == 1:
		var proof: Dictionary = proofs[0]
		var payload: Dictionary = {"npc": data.recipient, "source": proof.changes.origin, "qualification": proof.id}
		selector = _spread_selector(data, proof)
		before = data.turn.snapshot(); preview = data.powers.preview(data.turn, "POWER_SEED", payload); pure = before == data.turn.snapshot()
		var counterfeit: Dictionary = proof.duplicate(true); counterfeit.changes.basis.route = "calendar_rites"
		forged = not data.player_sources.valid_proof(data.world.state, counterfeit, null, false)
		_seed(data, "POWER_SEED", "success", payload); action = _power(data, "POWER_SEED", payload)
		var shadow: Dictionary = History.export_value(data.world.state); shadow.npcs[data.recipient].status = "dead"
		stale = data.player_sources.valid_proof(shadow, proof, null, false) and not data.player_sources.valid_proof(shadow, proof)
	var attempts: Array = _facts(data.world, "power_attempt").filter(func(fact: Dictionary) -> bool: return fact.changes.get("power") == "POWER_SEED")
	var same_turn: Dictionary = _actual_same_turn_spread()
	_check("CS-SEED", "Actual PlayerSources secret source plus shared spread profile supports paid SEED; stale/forged proof and anchor turn distinction", absent.is_empty() and delivered.ok and proofs.size() == 1 and preview.get("ok", false) and pure and forged and stale and action.get("ok", false) and attempts.size() == 1 and same_turn.get("pass", false) and selector.get("pass", false), {"noProfileProofCount": absent.size(), "transfer": delivered, "proofs": proofs, "preview": preview, "action": action, "attempts": attempts, "pure": pure, "forgedRejected": forged, "historicalSurvivesCurrentDeath": stale, "sameTurnSharedConsumer": same_turn, "sessionSelector": selector})

func _spread_selector(data: Dictionary, proof: Dictionary) -> Dictionary:
	var session: RefCounted = Session.new()
	session.catalog = catalog; session.world = data.world; session.turn = data.turn
	session.modules = {"player_sources": data.player_sources}
	session._known_domains[proof.domain] = true
	session._known_people[data.sender] = true; session._known_people[data.recipient] = true
	session._learn(data.world.state.cults[data.cult].established_source)
	var rule: Dictionary = ActualAnchors.evaluate(data.world.state, proof.changes.institution, proof.changes.basis.profile_rule, catalog, data.world.history, "spread", proof.actor)
	var hidden: bool = not session._spread_visible(proof)
	for source: String in rule.dependencies: session._learn(source)
	session._refresh_knowledge(false)
	var options: Array = Session.Actions.new()._source_options(session, proof.domain, "spread", "", proof.actor)
	return {"pass": hidden and options.any(func(row: Dictionary) -> bool: return row.id == proof.id), "hiddenWithoutMaterial": hidden, "knownMaterialOptions": options, "automaticOriginNotDisclosed": not session.is_known_source(proof.changes.origin)}

func _event_base(content: String) -> Dictionary:
	var world: RefCounted = EventWorld.new(catalog)
	assert(world.generate_hybrid(1))
	var domain: String = "DOMAIN-001"; var origin: String = world.state.domains[domain].origin
	var target: String = domain + "/propagation"; var receiver: String = world.state.institutions[target].representative
	var sender: String = world.state.institutions[domain + "/interpretation"].representative
	var opponent: String = world.state.institutions[domain + "/order"].representative
	if content == "PRAYER_05":
		var key: String = "cult-spread/priest"; var reserve: Dictionary = world.attention.reserve(world, {"focus": [], "people": [], "members": [], "identities": [key], "source": origin})
		sender = "NPC-%08d" % int(world.state.next_npc)
		assert(reserve.ok and world.submit({"kind": "nominate", "domain": domain, "institution": domain + "/interpretation", "profile": "NPC_PROFILE_02", "group": "unnamed_nonfollowers", "parents": [origin], "identity_key": key, "attention_token": reserve.token}))
		world.attention.finish(world, reserve.token)
	var economy: RefCounted = Economy.new(catalog, ISSUERS)
	assert(economy.initialize(world) and world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
	_bind(world, receiver)
	var cult: String = "CULT-EVENT"
	var authority: String = world.introduce_fact("cult_establishment_authorized", domain, receiver, [receiver], [origin], {"issuer": "cult-fixture", "version": "1", "cult": cult, "domain": domain, "leader": receiver, "cohesion": 80}, [])
	assert(world.submit({"kind": "establish_cult", "authorization": authority, "parents": [authority]}))
	world.state.faith = 20
	var data: Dictionary = {"world": world, "source": origin, "domain": domain, "sender": sender, "recipient": receiver, "opponent": opponent, "institution": target, "cult": cult}
	var subjects: Dictionary = {"petitioner": sender}; var facts: Dictionary = {}
	if content == "PRAYER_10":
		subjects.opponent = opponent
		for relation: Dictionary in _facts(world, "initial_relationship"):
			if not world.history.relation(sender, opponent, relation.id).is_empty() or not world.history.relation(opponent, sender, relation.id).is_empty(): facts.relation = relation.id; break
		assert(facts.has("relation"))
		var stance: String = _given_fact(data, "message", sender, [sender, opponent], {"institution": target, "stance": "existing_dispute_position"})
		world._institution_know(target, stance)
		facts.conflict = _given_fact(data, "faction_conflict", sender, [sender, opponent], {"parties": [sender, opponent], "institution": target, "default_stance": stance, "due": 10}, [facts.relation, stance])
	else:
		target = str(Store.entry(world.state.npcs, sender).institution); data.institution = target
		facts.ritual = _given_fact(data, "ritual_context", sender, [sender], {"subject": sender, "institution": target, "turn": 0})
	var actors: Array = [sender, opponent] if content == "PRAYER_10" else [sender]
	var parents: Array = LocalEventRules.roots(facts)
	var source: String = world.introduce_fact("prayer_situation", domain, sender, actors, parents, {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers[content].need, "domain": domain, "institution": target, "actors": actors, "subjects": subjects, "facts": facts, "crisis": {"source": facts.conflict, "due": 10} if content == "PRAYER_10" else {}}, actors)
	assert(not source.is_empty())
	var contact: String = _given_fact(data, "devotion_contact", sender, [sender], {"subject": sender, "institution": Store.entry(world.state.npcs, sender).institution})
	data.contact = contact; data.dream = _qualification(data, "dream", sender, sender, domain, {"contact": contact}, Store.entry(world.state.npcs, sender).institution)
	if content == "PRAYER_10":
		data.receiver_contact = _given_fact(data, "devotion_contact", receiver, [receiver], {"subject": receiver, "institution": target})
		data.receiver_dream = _qualification(data, "dream", receiver, receiver, domain, {"contact": data.receiver_contact}, target)
	_attach_dispatch(data)
	data.anchors = ActualAnchors.new(catalog, data.prayers.issuers)
	data.response = {"ok": false, "error": "Event prerequisite failed"}
	data.setup = {"content": content, "anchorsInstalled": data.anchors.install(data.turn)}
	if not data.setup.anchorsInstalled: return data
	data.setup.situation = data.prayers.validate_situation(world, source)
	data.setup.admission = world.preview_prayer_fix(source, data.turn)
	data.setup.fixed = world.fix_prayer_source(source, data.turn)
	if not data.setup.fixed:
		data.setup.worldError = world.last_error
		data.setup.validationErrors = world.validation_errors
		return data
	data.setup.bootstrap = _boot(data)
	if not data.setup.bootstrap.get("ok", false): return data
	data.setup.advance = _submit(data, "advance")
	if not data.setup.advance.get("ok", false): return data
	data.setup.actions = _submit(data, "finish_events")
	if not data.setup.actions.get("ok", false): return data
	data.request = ""
	for request: String in world.state.prayer_system.offered:
		if world.state.prayer_system.requests[request].descriptor.source == source: data.request = request
	data.setup.request = data.request
	if data.request.is_empty(): return data
	if content == "PRAYER_10":
		var payload: Dictionary = {"npc": sender, "source": contact, "qualification": data.dream}
		_seed(data, "POWER_DREAM", "success", payload); assert(_power(data, "POWER_DREAM", payload).ok)
	_choose_prayer_seed(data, "success", sender, domain)
	data.response = _response(data, data.request, "shallow")
	if content == "PRAYER_10" and data.response.ok:
		# The target's independent record is produced on a different actual turn.
		# EVENT09's fixed remote material is still missing until its real delivery.
		data.setup.nextWindow = _evolve(data) and _finish(data) and _open(data)
		if not data.setup.nextWindow: return data
		var payload: Dictionary = {"npc": receiver, "source": data.receiver_contact, "qualification": data.receiver_dream}
		_seed(data, "POWER_DREAM", "success", payload)
		data.setup.targetDream = _power(data, "POWER_DREAM", payload)
	return data

func _event_transactions() -> void:
	var data: Dictionary = _event_base("PRAYER_10")
	var valid: bool = data.response.ok and data.setup.get("nextWindow", false) and data.setup.get("targetDream", {}).get("ok", false)
	var event: String = ""
	while valid and data.world.state.turn < 5 and event.is_empty():
		valid = _evolve(data) and _finish(data) and _submit(data, "advance").ok
		for id: String in data.world.state.event_system.selected:
			if data.world.state.event_system.cards.has(id) and data.world.state.event_system.cards[id].descriptor.content_id == "EVENT_09": event = id
		if event.is_empty(): valid = valid and _submit(data, "finish_events").ok
	valid = valid and not event.is_empty()
	var details: Dictionary = {"setup": data.setup, "response": data.response, "event": event}
	if not event.is_empty():
		var descriptor: Dictionary = data.world.state.event_system.cards[event].descriptor
		var basis_missing: bool = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history).is_empty()
		var before: String = data.turn.snapshot(); var preview: Dictionary = data.events.preview(data.turn, event, "A")
		var pure: bool = before == data.turn.snapshot()
		data.world.reject_reception = true
		var denied: Dictionary = _submit(data, "resolve_event", {"event": event, "action": "A"})
		data.world.reject_reception = false
		var rollback: bool = not denied.ok and before == data.turn.snapshot()
		var faith: int = data.world.state.faith; var whispers: int = data.world.state.whispers; var alert: int = data.world.state.domains[data.domain].alert
		request_sequence += 1
		var request: Dictionary = {"id": "CS-09-RETRY", "op": "resolve_event", "turn": data.turn.context.turn, "phase": data.turn.context.phase, "event": event, "action": "A"}
		var result: Dictionary = data.turn.submit(request)
		var after: String = data.turn.snapshot(); var retry: Dictionary = data.turn.submit(request)
		var receipts: Array = _facts(data.world, "material_received"); var routes: Array = _facts(data.world, "cult_contact_route").filter(func(fact: Dictionary) -> bool: return fact.changes.route_id == "ALLIED_CHANNEL")
		var hostility: Array = _facts(data.world, "relationship").filter(func(fact: Dictionary) -> bool: return fact.actor == descriptor.subjects.cooperator and descriptor.subjects.opponent in fact.targets and fact.changes.get("kind", fact.changes.get("type")) == "hostile")
		var bases: Array = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history)
		var recruitment: Dictionary = Spread.qualification(data.world.state, data.cult, data.world.history)
		var endpoint_fixed: bool = receipts.size() == 1 and routes.size() == 1 and receipts[0].changes.source == descriptor.facts.material and receipts[0].changes.recipient == descriptor.subjects.recipient and receipts[0].changes.target_institution == descriptor.subjects.target_institution and receipts[0].changes.channel.source == routes[0].id and receipts[0].changes.trigger == routes[0].changes.origin and data.world.history.knows(data.world.state, data.recipient, descriptor.facts.material)
		var paid_once: bool = result.ok and faith - data.world.state.faith == 4 and whispers == data.world.state.whispers and data.world.state.domains[data.domain].alert - alert == 3
		var fallback: Dictionary = History.export_value(data.world.state)
		for route: Dictionary in routes: fallback.invalid_records[route.id] = data.source
		var cell: Dictionary = Spread.qualification(fallback, data.cult)
		valid = valid and preview.ok and pure and rollback and paid_once and retry.ok and after == data.turn.snapshot() and endpoint_fixed and basis_missing and not bases.is_empty() and recruitment.get("allowed", false) and hostility.size() == 1 and routes[0].changes.origin in hostility[0].causal_parents and cell.get("allowed", false) and not LocalEventRules.cooperative_endpoint(data.world.state, descriptor, catalog, data.world.history).get("ok", false)
		details.merge({"descriptor": descriptor, "preview": preview, "injectedFailure": denied, "rollback": rollback, "paidOnce": paid_once, "result": result, "retry": retry, "receipts": receipts, "routes": routes, "fixedEndpoint": endpoint_fixed, "basisMissingBefore": basis_missing, "basisAfter": bases, "recruitment": recruitment, "hostility": hostility, "cellFallback": cell})
	var ritual: Dictionary = _event_base("PRAYER_05")
	var ritual_valid: bool = ritual.response.ok
	while ritual_valid and ritual.world.state.turn < 4:
		ritual_valid = _evolve(ritual) and _finish(ritual) and _open(ritual)
	var defaults: Array = _facts(ritual.world, "event_result").filter(func(fact: Dictionary) -> bool: return fact.changes.get("content_id") == "EVENT_04")
	var retired: bool = LocalEventRules.active_choices(catalog, "EVENT_04") == ["B"] and defaults.size() == 1 and defaults[0].changes.option == "B" and defaults[0].changes.default and defaults[0].changes.payment == ""
	var denial: Array = _facts(ritual.world, "event_fact").filter(func(fact: Dictionary) -> bool: return fact.changes.get("event") == "EVENT_04" and fact.changes.get("tag") == "interpretation_rejected")
	var phantom_growth: Array = _facts(ritual.world, "event_delta").filter(func(fact: Dictionary) -> bool: return fact.changes.get("field") == "followers" and defaults.any(func(outcome: Dictionary) -> bool: return outcome.id in fact.causal_parents))
	retired = retired and denial.size() == 1 and defaults[0].id in denial[0].causal_parents and phantom_growth.is_empty()
	var retired_rule: Dictionary = LocalEventRules.legal(ritual.world.state, defaults[0].changes.descriptor, "A", catalog, ritual.world.history) if not defaults.is_empty() else {}
	retired = retired and not retired_rule.get("ok", true) and retired_rule.get("error") == "Event option is retired"
	var unchanged: String = ritual.turn.snapshot()
	var retired_request: Dictionary = _submit(ritual, "resolve_event", {"event": defaults[0].changes.event if not defaults.is_empty() else "missing04", "action": "A"})
	retired = retired and not retired_request.ok and unchanged == ritual.turn.snapshot()
	_check("CS-EVENTS", "Actual09 transaction receives once at original fee and hostility/alert, rolls back/retries, preserves cell;04B auto-default and retired A rejects", valid and ritual_valid and retired, details.merged({"cooperationPassed": valid, "ritualSetup": ritual.setup, "ritualResponse": ritual.response, "ritualDefault": defaults, "ritualDenial": denial, "phantomGrowth": phantom_growth, "retiredRule": retired_rule, "retiredRejected": retired_request}))

func _full_session() -> void:
	var directory: String = OS.get_cmdline_user_args()[0].get_base_dir().path_join("session-campaigns")
	var session: RefCounted = Session.new(directory)
	var start: Dictionary = session.start_new(1)
	var valid: bool = start.ok
	var opened: Dictionary = session._submit("finish_events") if valid else {}
	var actions: Array = session.modules.get("player_sources").available(session.turn) if valid else []
	var listed: Array = session.modules.get("player_sources").available(session.turn) if valid else []
	var menu: Array = session.action_catalog() if valid else []
	var chosen: Dictionary = {}; var result: Dictionary = {}
	for row: Dictionary in menu:
		if str(row.get("key", "")).begins_with("prayer/") and str(row.key).ends_with("/shallow"):
			chosen = row; break
	if not chosen.is_empty(): result = session.execute_action(chosen.key, {}, true, "CS-SESSION-RESPONSE")
	var scene: Node = load("res://src/presentation/game_root.tscn").instantiate()
	scene.session = session; root.add_child(scene); await process_frame
	var scene_ok: bool = scene.is_inside_tree() and session.project().get("ok", false)
	scene.free()
	var cycle: Array = []
	if valid:
		cycle.append(session._submit("end_actions"))
		for step: int in 4: cycle.append(session._submit("advance"))
		cycle.append(session._submit("finish_events"))
	valid = valid and opened.get("ok", false) and scene_ok and result.get("ok", false) and cycle.all(func(value: Dictionary) -> bool: return value.get("ok", false)) and session.turn.context.turn == 2 and session.turn.context.phase == "actions" and session.modules.size() == 10 and session.world.state.simulation.bootstrap
	_check("CS-SESSION", "Unmodified formal Session loads every module, actual bootstrap/action via existing UI and one normal round to next action window", valid, {"start": start, "opened": opened, "offeredActions": menu, "chosen": chosen, "response": result, "productionSceneLoaded": scene_ok, "cycle": cycle, "phase": session.turn.context.phase, "turn": session.turn.context.turn, "installed": session.modules.keys(), "sourceCounts": [actions.size(), listed.size()]})
