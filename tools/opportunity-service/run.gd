extends "res://tools/progression-operations/run.gd"
const Service = preload("res://src/game/opportunity_service.gd")
const Planner = preload("res://src/game/opportunity_planner.gd")
const Ledger = preload("res://src/game/player_knowledge.gd")
const AdmissionQuery = preload("res://src/game/opportunity_eligibility.gd")
const ManagedTransaction = preload("res://src/simulation/transaction.gd")
var player: RefCounted
var bootstrap_entry: String = ""

func _initialize() -> void:
	scratch = OS.get_cmdline_user_args()[0].get_base_dir()
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	if loaded:
		player = Session.new(scratch.path_join("campaigns"))
		var started: Dictionary = player.start_new(1)
		if started.get("ok", false):
			if "negative" in OS.get_cmdline_user_args():
				player._submit("finish_events")
				_components()
			else:
				_boundary(started)
				_stages()
				_authority()
				_components()
		else: _check("OS-START", "Formal Session starts", false, {"startup": started})
	else: _check("OS-CATALOG", "Current authored content loads", false, {"errors": catalog.errors})
	var expected: int = 1 if "negative" in OS.get_cmdline_user_args() else 4
	var passed: bool = records.size() == expected and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "scope": "bounded_direct_opportunity_service", "checks": records, "fixtures": ["Actual Session.start_new(1), original bootstrap PR08 and formal finish_events/actions boundary. Controlled successful response roll is not natural balance evidence.", "Existing progression fixture supplies generated people, initial binding/contact capabilities, 80 faith and 10 insight. Gatherings, practices, dreams, observations, covenants and first reciprocal leg are actual Turn actions. Copied known-material/participant ledgers only test the pure route-stage consumer; they do not prove new Session discovery or full target routes.", "World/Turn component snapshots and a transaction rollback control do not claim mature complete Session continuation.", "No B compensation/FIFO/pipeline guarantee, twenty-route active closure, natural frequency, human UI acceptance or production balance claim."]}, "\t", true, true) + "\n")
	file.close(); quit(0 if passed else 1)

func _goal(goal_id: String) -> Dictionary:
	return player.world.state.opportunities.goals.get(Planner.key(goal_id), {})

func _boundary(started: Dictionary) -> void:
	var before: String = player.turn.snapshot()
	var planned_before: Dictionary = Service.plan(player.turn)
	var events_no_service: bool = _facts(player.world, "opportunity_served").is_empty() and before == player.turn.snapshot()
	var opened: Dictionary = player._submit("finish_events")
	var first: Dictionary = _goal("GOAL_FIRST_CULT")
	var receipt: Dictionary = Store.entry(player.world.state.facts, str(first.get("step", {}).get("service_source", "")), {})
	bootstrap_entry = str(receipt.get("changes", {}).get("entry_id", ""))
	var fresh: String = player.turn.snapshot()
	var planned: Dictionary = Service.plan(player.turn)
	var again: Dictionary = Service.plan(player.turn)
	var pure: bool = fresh == player.turn.snapshot() and planned == again
	var query: Dictionary = player.entry_eligibility(bootstrap_entry)
	var poor_view: Dictionary = player.turn._read_view("prayers", "actions")
	poor_view.world.whispers = 0
	var poor: Dictionary = AdmissionQuery.query(poor_view, player.knowledge_snapshot(), player.modules, bootstrap_entry)
	poor_view.reader.close()
	var goal_count: int = player.world.state.opportunities.goals.size()
	var no_cult: bool = player.world.state.cults.is_empty() and first.get("status") == "served" and first.get("completion_source") == ""
	var valid: bool = events_no_service and opened.get("ok", false) and query.get("ok", false) and not poor.get("ok", false) and pure and no_cult and goal_count == catalog.integer("domains_total") * catalog.integer("institutions_per_domain") + 2
	valid = valid and planned_before.ok and planned.ok and receipt.get("kind") == "opportunity_served" and bootstrap_entry.begins_with("prayer/") and receipt.changes.transaction_sequence == player.turn.commit_sequence and player.turn.context.player_knowledge == player.knowledge_snapshot()
	_check("OS-BOUNDARY", "Only a real complete actions window serves the exact current contact step", valid, {"startup": started, "enteredActions": opened, "entry": bootstrap_entry, "receipt": receipt, "eventsNoService": events_no_service, "queryPure": pure, "noFalseCultCompletion": no_cult, "goalCount": goal_count, "tables": {"goals": catalog.tables.progression_opportunity_goals.size(), "routes": catalog.tables.progression_routes.size()}, "currentQuery": query.get("ok", false), "noWhispersRejected": poor})

func _known_fixture(data: Dictionary) -> Dictionary:
	var ledger: Dictionary = data.turn.context.player_knowledge.duplicate(true)
	for source: String in data.contacts.values(): ledger = Ledger.learn(data.world.state, data.turn.context, ledger, catalog, data.world.history, source)
	for kind: String in ["miracle", "route_material", "exception"]:
		for fact: Dictionary in _facts(data.world, kind): ledger = Ledger.learn(data.world.state, data.turn.context, ledger, catalog, data.world.history, fact.id)
	for routes: Dictionary in data.world.state.anchor_system.routes.values():
		for source: String in routes.values(): ledger = Ledger.learn(data.world.state, data.turn.context, ledger, catalog, data.world.history, source)
	return ledger

func _view_fixture(data: Dictionary) -> Dictionary:
	return data.turn._read_view("progression_routes", "actions")

func _fixture_modules(data: Dictionary) -> Dictionary:
	var modules: Dictionary = {}
	for id: String in data.turn._participants: modules[id] = data.turn._participants[id].instance
	return modules

func _stages() -> void:
	var data: Dictionary = _route_base(); data.actor = data.people[0]
	var view: Dictionary = _view_fixture(data)
	var route: Dictionary = catalog.tables.progression_routes.ROUTE_FIRST_CULT_GATHERING
	var original: Array = Planner._first_cult(view, _known_fixture(data), route, data.domain)
	view.reader.close()
	var gathering: Dictionary = _route(data, "ROUTE_COVERT_GATHERING")
	var advanced: bool = gathering.get("ok", false) and _route_next(data)
	view = _view_fixture(data)
	var subsequent: Array = Planner._first_cult(view, _known_fixture(data), route, data.domain)
	var changed_gap: bool = not original.is_empty() and not subsequent.is_empty() and original[0].id != subsequent[0].id and data.world.state.cults.is_empty()
	view.reader.close()
	data.actor = _role(data, "record_keeper")
	var first_use: Dictionary = _route(data, "ROUTE_RECORD_PRACTICE") if advanced else {}
	var second_use: Dictionary = _route(data, "ROUTE_RECORD_PRACTICE") if first_use.get("ok", false) and _route_next(data) else {}
	view = _view_fixture(data)
	var office: String = str(Store.entry(data.world.state.npcs, data.actor).institution)
	var permissions: Array = ActualAnchors.available(view.world, office, catalog, view.reader)
	var tail: Array = Planner._tail(view, _known_fixture(data), _fixture_modules(data), catalog.tables.progression_routes.ROUTE_CIV01_PRACTICE, data.domain, office, permissions, {}) if not permissions.is_empty() else []
	var tail_real: bool = not permissions.is_empty() and tail.any(func(item: Dictionary) -> bool: return item.entry_id.begins_with("opportunity/") or item.entry_id == "POWER_ANCHOR" or item.entry_id in ["ROUTE_PRIVATE_DEVOTION", "ROUTE_COVERT_GATHERING", "ROUTE_CALENDAR_RITE"])
	view.reader.close()
	var cosmic: Dictionary = _route_base(true); cosmic.actor = cosmic.people[0]
	var observation: Dictionary = _route(cosmic, "ROUTE_AXIOM_PROBE")
	var records_produced: Array = _route_materials(cosmic, "axiom_record")
	var ready_second: bool = observation.get("ok", false) and records_produced.size() == 1 and _route_next(cosmic)
	var rechecks: Array = []
	var unknown_second_blocked: bool = false
	if ready_second:
		view = _view_fixture(cosmic)
		var actual_office: String = str(Store.entry(cosmic.world.state.npcs, cosmic.actor).institution)
		var observed_ledger: Dictionary = _known_fixture(cosmic)
		var unknown_second: Array = Planner._route(view, observed_ledger, _fixture_modules(cosmic), catalog.tables.progression_routes.ROUTE_CIV07_NODES, cosmic.domain, actual_office)
		unknown_second_blocked = unknown_second.is_empty()
		# A consumer-only knowledge prerequisite over already generated people;
		# this does not alter Turn/Session authority or manufacture an observation.
		var known_participants: Dictionary = observed_ledger.duplicate(true)
		for person: String in cosmic.people: known_participants.known_people[person] = true
		rechecks = Planner._route(view, known_participants, _fixture_modules(cosmic), catalog.tables.progression_routes.ROUTE_CIV07_NODES, cosmic.domain, actual_office)
		view.reader.close()
	var same_exception: String = str(records_produced[0].changes.data.exception) if records_produced.size() == 1 else ""
	var exact_second: bool = unknown_second_blocked and not rechecks.is_empty() and rechecks.all(func(item: Dictionary) -> bool: return item.entry_id == "ROUTE_AXIOM_RECHECK" and item.selection.target == same_exception and Store.entry(cosmic.world.state.npcs, item.selection.npc).institution != Store.entry(cosmic.world.state.npcs, cosmic.actor).institution)
	var pact: Dictionary = _route_base(); pact.actor = pact.people[0]
	var other: String = pact.people.filter(func(id: String) -> bool: return Store.entry(pact.world.state.npcs, id).institution != Store.entry(pact.world.state.npcs, pact.actor).institution)[0]
	var dream_a: Dictionary = _dream_actual(pact, pact.actor)
	var dream_b: Dictionary = _dream_actual(pact, other) if dream_a.get("ok", false) and _route_next(pact) else {}
	var dreams: Array = _facts(pact.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.changes.get("power") == "POWER_DREAM")
	var covenant: Dictionary = _route(pact, "ROUTE_RECIPROCAL_COVENANT", {"other": other, "record": dreams[0].id, "second_record": dreams[1].id, "stage": "prepare"}) if dream_b.get("ok", false) and dreams.size() == 2 and _route_next(pact) else {}
	var leg: Dictionary = _route(pact, "ROUTE_RECIPROCAL_COVENANT", {"other": other, "stage": "perform"}) if covenant.get("ok", false) and _route_next(pact) else {}
	var second_legs: Array = []
	if leg.get("ok", false) and _route_next(pact):
		view = _view_fixture(pact)
		second_legs = Planner._continuations(view, _known_fixture(pact), catalog.tables.progression_routes.ROUTE_CIV06_RECIPROCAL, "ROUTE_RECIPROCAL_COVENANT", pact.domain, Store.entry(pact.world.state.npcs, pact.actor).institution)
		view.reader.close()
	var exact_leg: bool = not second_legs.is_empty() and second_legs.all(func(item: Dictionary) -> bool: return item.id.begins_with("leg/1/") and item.selection.stage == "perform") and _route_basis(pact, "contract_reciprocal").is_empty()
	_check("OS-STAGES", "Actual progress binds the next gap, original independent node and unpaid reciprocal leg", changed_gap and second_use.get("ok", false) and tail_real and exact_second and exact_leg, {"gathering": gathering, "firstOrganizeStep": original[0].id if not original.is_empty() else "", "secondOrganizeStep": subsequent[0].id if not subsequent.is_empty() else "", "gapChangedBeforeCult": changed_gap, "practiceActions": [first_use, second_use], "sharedTailUsesActualBasis": tail_real, "actualFirstObservation": observation, "sameExceptionSecondNodeOnly": exact_second, "unknownSecondNodeHasNoFakeProbe": unknown_second_blocked, "secondNodeEntries": rechecks.map(func(item: Dictionary) -> Dictionary: return {"stage": item.id, "entry": item.entry_id, "selection": item.selection}), "covenant": covenant, "actualFirstLeg": leg, "onlyUnpaidSecondLeg": exact_leg, "secondLegStage": second_legs[0].id if not second_legs.is_empty() else ""})

func _authority() -> void:
	var request: String = bootstrap_entry.split("/")[1]
	var preview: Dictionary = player.modules.prayers.preview(player.turn, request, "shallow")
	if preview.get("ok", false):
		for seed_value: int in range(1, 101):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
			if player.world.check_result(preview.probability, rng.randi_range(1, 100)) == "success": player.world.randoms.checks.seed = seed_value; break
	var response: Dictionary = player.execute_action(bootstrap_entry, {}, true, "OS-ACTUAL-RESPONSE")
	var once: String = player.turn.snapshot()
	var replay: Dictionary = player.execute_action(bootstrap_entry, {}, true, "OS-ACTUAL-RESPONSE")
	var deduplicated: bool = once == player.turn.snapshot() and replay.get("ok", false)
	var ledger: Dictionary = player.knowledge_snapshot()
	var unknown: String = ""
	for fact: Dictionary in Store.values(player.world.state.facts):
		if not ledger.known_facts.has(fact.id): unknown = fact.id; break
	player._learn(unknown)
	var no_second_writer: bool = ledger == player.knowledge_snapshot()
	var all_internal: bool = true
	for fact: Dictionary in _facts(player.world, "opportunity_served") + _facts(player.world, "opportunity_outcome"):
		all_internal = all_internal and not ledger.known_facts.has(fact.id)
	var service_before: String = str(_goal("GOAL_FIRST_CULT").get("step", {}).get("service_source", ""))
	var cycle: Array = _session_round(player)
	var first_key: String = Planner.key("GOAL_FIRST_CULT")
	var names: Array = player.world.state.opportunities.goals.keys().filter(func(id: String) -> bool: return id == first_key)
	var exact: bool = player.knowledge_snapshot() == player.turn.context.player_knowledge and player.known_domains() == player.knowledge_snapshot().known_domains.keys()
	_check("OS-AUTHORITY", "One transactional ledger, private service facts, original result and stable goal identity", response.get("ok", false) and deduplicated and no_second_writer and all_internal and exact and names.size() == 1 and cycle.all(func(item: Dictionary) -> bool: return item.get("ok", false)), {"response": response, "deduplicated": deduplicated, "sessionCannotLearnUnknown": no_second_writer, "internalServiceFactsHidden": all_internal, "sameTurnLedger": exact, "stableRunGoalCopies": names.size(), "firstService": service_before, "normalRound": cycle, "notCultUntilRealMilestone": _goal("GOAL_FIRST_CULT").get("completion_source", "") == ""})

func _components() -> void:
	var serialized: String = player.turn.snapshot()
	var fresh: Dictionary = player._build(1)
	var restored: bool = fresh.get("ok", false) and fresh.turn.restore(serialized)
	var exact: bool = restored and fresh.turn.context.player_knowledge == player.turn.context.player_knowledge and fresh.world.state.opportunities == player.world.state.opportunities
	var outer: Dictionary = World._normalize_numbers(JSON.parse_string(serialized))
	outer.body.context.knowledge_version = "obsolete"
	outer.checksum = World.canonical(outer.body).sha256_text()
	var obsolete_rejected: bool = not fresh.turn.restore(World.canonical(outer)) if restored else false
	outer = World._normalize_numbers(JSON.parse_string(serialized))
	var inner: Dictionary = World._normalize_numbers(JSON.parse_string(outer.body.world))
	var changed: bool = false
	for goal: Dictionary in inner.body.state.opportunities.goals.values():
		if not goal.step.is_empty() and not str(goal.step.service_source).is_empty(): goal.step.id += "/forged"; changed = true; break
	inner.checksum = World.canonical(inner.body).sha256_text()
	outer.body.world = World.canonical(inner); outer.checksum = World.canonical(outer.body).sha256_text()
	var forged_rejected: bool = not fresh.turn.restore(World.canonical(outer)) if changed and restored else false
	var rollback_player: RefCounted = Session.new(scratch.path_join("rollback-campaigns"))
	var opened: Dictionary = rollback_player.start_new(1)
	var before: String = rollback_player.turn.snapshot() if opened.get("ok", false) else ""
	var rolled_back: bool = false
	if opened.get("ok", false):
		var tx: RefCounted = ManagedTransaction.new(rollback_player.world, rollback_player.turn.context, rollback_player.turn.commit_sequence)
		if tx.activate():
			rollback_player.turn.context = tx.context; rollback_player.turn._transaction = tx; rollback_player.turn._in_transaction = true
			rollback_player.turn.context.phase = "actions"
			var observed: bool = Service.observe(rollback_player.turn, true, [], {"id": "OS-ROLLBACK", "op": "finish_events"})
			var wrote: bool = not rollback_player.world.state.opportunities.goals.is_empty() and not _facts(rollback_player.world, "opportunity_served").is_empty()
			tx.rollback(); rollback_player.turn.context = tx.base_context; rollback_player.turn._transaction = null; rollback_player.turn._in_transaction = false
			rolled_back = observed and wrote and before == rollback_player.turn.snapshot()
	var after: String = player.turn.snapshot()
	# Pure terminal-summary controls. These are supplied consumer values, never
	# installed World facts, produced milestones or a complete ending trajectory.
	var summaries: Dictionary = {Planner.key("GOAL_FIRST_CULT"): {"status": "satisfied", "completion_source": "consumer/prior-milestone"}, Planner.key("GOAL_MANIFEST"): {"status": "waiting", "completion_source": "", "block": {"reason": "blocked_world"}}}
	var failed_ending: Dictionary = Service.terminal_projection(summaries, "")
	var completed_ending: Dictionary = Service.terminal_projection(summaries, "consumer/manifest-complete")
	var terminal_valid: bool = failed_ending[Planner.key("GOAL_FIRST_CULT")].status == "satisfied" and failed_ending[Planner.key("GOAL_MANIFEST")].status == "terminal" and failed_ending[Planner.key("GOAL_MANIFEST")].completion_source == "" and completed_ending[Planner.key("GOAL_MANIFEST")].status == "satisfied" and completed_ending[Planner.key("GOAL_MANIFEST")].completion_source == "consumer/manifest-complete" and summaries[Planner.key("GOAL_MANIFEST")].status == "waiting"
	_check("OS-COMPONENTS", "Component source/version, rollback and finite terminal projection", exact and obsolete_rejected and forged_rejected and rolled_back and after == serialized and terminal_valid, {"componentRestoreExact": exact, "obsoleteLedgerRejected": obsolete_rejected, "forgedStepRejected": forged_rejected, "rollbackAfterActualServiceWrites": rolled_back, "originalUntouched": after == serialized, "terminalProjection": {"kind": "supplied_summary_consumer_control_not_world_or_complete_ending", "passed": terminal_valid, "failedEnding": failed_ending, "completionEnding": completed_ending}, "negativeControl": "The isolated variant disables only the receipt/step binding guard; forgedStepRejected must become false without parse/load failure."})
