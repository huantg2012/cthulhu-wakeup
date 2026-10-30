extends "res://tools/prayer-producers/run.gd"
const DispatchPolicy = preload("res://src/game/prayer_dispatch.gd")
const SourcePolicy = preload("res://src/game/source_fairness.gd")
const OpportunityService = preload("res://src/game/opportunity_service.gd")
const Tx = preload("res://src/simulation/transaction.gd")
var session_player: RefCounted

func _initialize() -> void:
	scratch = OS.get_cmdline_user_args()[0].get_base_dir()
	catalog = Catalog.new()
	if catalog.load_files():
		_policy()
		if not "negative" in OS.get_cmdline_user_args():
			_callbacks()
			_session_chain()
			_components_and_rollback()
	else: _check("OQ-CATALOG", "Current CSV loads", false, {"errors": catalog.errors})
	var expected: int = 1 if "negative" in OS.get_cmdline_user_args() else 4
	var passed: bool = records.size() == expected and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "checks": records, "engine": Engine.get_version_info().string, "scope": "original_B_source_compensation_and_FIFO", "fixtures": ["Eleven-family worst case uses supplied finite policy options and repeated adverse gate RNG, with consumer success tokens only. It proves policy arithmetic, not simultaneous world eligibility or real production.", "Original handlers receive finite prepared options inside a managed transaction; the passage proposal is deliberately stale. Ritual publication is real, then the transaction is rolled back.", "One actual Session seed 1 is driven through original phases without target calls, situations or cards supplied. Source production, original fixation and actual actions admission are recorded separately from the controlled policy bound.", "Restore/retry/rollback are World/Turn components; no full mature Session save, all-route active, natural frequency or victory bound claim."]}, "\t", true, true) + "\n")
	file.close(); quit(0 if passed else 1)

func _adverse_cursor() -> Dictionary:
	for value: int in range(1, 101):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = value
		var state: String = str(rng.state)
		if rng.randi_range(1, 100) > catalog.integer("ambient_event_chance"): return {"seed": str(value), "state": state, "next_turn": 0}
	return {}

func _policy() -> void:
	var options: Array = []
	for root: String in SourcePolicy.roots(): options.append({"root": root, "weight": 1})
	var state: Dictionary = SourcePolicy.initial(); var sequence: int = 1
	var cursor: Dictionary = _adverse_cursor(); var produced: Dictionary = {}; var evidence: Array = []
	var no_extra_rng: bool = true; var cooldown_exact: bool = true; var finite: bool = true
	for slot: int in range(1, 14):
		var selected: Dictionary = SourcePolicy.select(state, options, cursor, true, catalog)
		var root: String = ""; var token: String = ""; var attempts: Array = []
		if selected.mode == "forced":
			no_extra_rng = no_extra_rng and selected.random_after == cursor.state
			root = selected.forced_roots[0]; token = "consumer/" + str(slot)
			attempts.append({"root": root, "outcome": "consumer_success"})
		elif not selected.choice.is_empty(): root = selected.choice.root; token = "consumer/" + str(slot)
		if not root.is_empty() and not produced.has(root): produced[root] = slot
		var after: Dictionary = SourcePolicy.finish(state, sequence, options, attempts, root, token, slot * 4, true, catalog)
		for cooling: String in selected.cooling:
			cooldown_exact = cooldown_exact and after.sources[cooling].cooldown == 0 and after.sources[cooling].missed_due_slots == state[cooling].missed_due_slots and after.sources[cooling].queue_seq == 0
		finite = finite and selected.forced_roots.size() <= 11 and SourcePolicy.validate_shape(after.sources, after.next_queue_seq).is_empty()
		evidence.append({"slot": slot, "mode": selected.mode, "forced": selected.forced_roots, "success": root, "cooling": selected.cooling})
		state = after.sources; sequence = after.next_queue_seq
	var weighted: Dictionary = SourcePolicy.initial()
	weighted.ROOT_IDENTITY_NOTICE.missed_due_slots = 1
	var selection: Dictionary = SourcePolicy.select(weighted, [{"root": "ROOT_IDENTITY_NOTICE", "weight": 7}, {"root": "ROOT_CURRENT_APPEAL"}], cursor, true, catalog)
	var weights_correct: bool = selection.weights == {"ROOT_IDENTITY_NOTICE": 8, "ROOT_CURRENT_APPEAL": 1}
	var idle: Dictionary = SourcePolicy.finish(weighted, 1, options, [], "", "", 0, false, catalog)
	var unknown: Dictionary = SourcePolicy.select(weighted, [{"root": "ROOT_KNOWN_RECORD"}], cursor, true, catalog)
	var bound: bool = produced.size() == 11 and produced.values().all(func(value: int) -> bool: return value <= 13)
	_check("OQ-POLICY", "Original weights, notice parity, M2 FIFO and one-slot cooldown survive repeated adverse gate rolls", bound and weights_correct and finite and cooldown_exact and no_extra_rng and idle.sources == weighted and not unknown.ok and SourcePolicy.binding_errors().is_empty(), {"boundedProduction": bound, "kind": "pure_policy_supplied_options_not_world_production", "families": options.map(func(option: Dictionary) -> String: return option.root), "firstSuccessDueSlot": produced, "conditionalBoundTurns": 52, "weights": selection.weights, "cooldownExact": cooldown_exact, "forcedConsumesNoRNG": no_extra_rng, "finite": finite, "evidence": evidence})

func _activate(data: Dictionary) -> RefCounted:
	var tx: RefCounted = Tx.new(data.world, data.turn.context, data.turn.commit_sequence)
	assert(tx.activate())
	data.turn.context = tx.context; data.turn._transaction = tx; data.turn._in_transaction = true
	data.turn.context.phase = "evolution"
	return tx

func _undo(data: Dictionary, tx: RefCounted) -> void:
	tx.rollback(); data.turn.context = tx.base_context; data.turn._transaction = null; data.turn._in_transaction = false

func _callbacks() -> void:
	var data: Dictionary = _producer_native(1)
	_attach_dispatch(data)
	assert(_boot(data).get("ok", false) and _open(data))
	var before: String = data.turn.snapshot()
	var tx: RefCounted = _activate(data)
	# Controlled original-handler prerequisite only; neither this nomination nor
	# its ritual result is committed. Native initialization remains untouched.
	data.world.stage_current()
	assert(data.world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_02", data.source))
	var sample: Dictionary = Knowledge.capture(data.world, data.turn)
	var view: Dictionary = data.world._evolution_snapshot()
	var options: Array = Producers.prepare_options(data.world, view, "DOMAIN-001", sample)
	var names: Array = options.map(func(option: Dictionary) -> String: return option.root)
	var stale: Dictionary = {}
	for option: Dictionary in options:
		if option.root == "ROOT_CURRENT_PASSAGE": stale = option.duplicate(true)
	var ready: bool = not stale.is_empty() and "ROOT_CURRENT_RITUAL" in names and "ROOT_CURRENT_APPEAL" in names
	var result: Dictionary = {}; var ticket_retained: bool = false
	if ready:
		stale.proposal.barrier_source = "consumer/stale_original_barrier"
		var inputs: Array = [stale]
		for option: Dictionary in options:
			if option.root != stale.root: inputs.append(option)
		var order: Array = ["ROOT_CURRENT_PASSAGE", "ROOT_CURRENT_RITUAL", "ROOT_CURRENT_APPEAL"]
		var item: Dictionary = {"domain": "DOMAIN-001", "eligible": inputs, "choice": {}, "selection": {"mode": "forced", "forced_roots": order}}
		result = DispatchPolicy._commit_b(data.world, item, data.events, data.turn)
		var supplied_debt: Dictionary = SourcePolicy.initial()
		for index: int in order.size(): supplied_debt[order[index]].missed_due_slots = 2; supplied_debt[order[index]].queue_seq = index + 1
		var finished: Dictionary = SourcePolicy.finish(supplied_debt, 4, inputs, result.get("attempts", []), result.get("root", ""), result.get("source", ""), data.world.state.turn, true, catalog)
		ticket_retained = finished.sources.ROOT_CURRENT_PASSAGE.queue_seq == 1 and finished.sources.ROOT_CURRENT_PASSAGE.missed_due_slots == 2 and finished.sources.ROOT_CURRENT_RITUAL.cooldown == 1
	_undo(data, tx)
	var attempts: Array = result.get("attempts", [])
	var valid: bool = ready and result.get("ok", false) and result.get("outcome") == "root_published" and result.get("root") == "ROOT_CURRENT_RITUAL" and attempts.size() == 2 and attempts[0].outcome == "source_changed" and attempts[0].fact_before == attempts[0].fact_after and not str(attempts[1].source).is_empty() and ticket_retained and before == data.turn.snapshot()
	_check("OQ-CALLBACKS", "Original stale X keeps its ticket, same-slot Y publishes one real ritual and stops before Z", valid, {"preparedRoots": names, "result": result, "retainedDebtAndCooldown": ticket_retained, "exactRollback": before == data.turn.snapshot(), "kind": "controlled_original_handler_boundary_then_rollback"})

func _session_chain() -> void:
	session_player = Session.new(scratch.path_join("campaigns"))
	var started: Dictionary = session_player.start_new(1)
	var valid: bool = started.get("ok", false) and session_player._submit("finish_events").get("ok", false)
	var source: String = ""; var production: Dictionary = {}; var fixed: Dictionary = {}; var query: Dictionary = {}; var rounds: int = 0
	for index: int in 10:
		if not valid: break
		for tick: Dictionary in _facts(session_player.world, "prayer_dispatch_tick"):
			if tick.changes.get("b_produced", "").is_empty(): continue
			var candidate: Dictionary = Store.entry(session_player.world.state.facts, tick.changes.b_produced, {})
			if candidate.get("kind") == "prayer_situation": source = candidate.id; production = tick; break
		if not source.is_empty():
			for fact: Dictionary in _facts(session_player.world, "prayer_fixed"):
				if fact.changes.candidate.get("source") == source: fixed = fact.changes.candidate
			if not fixed.is_empty():
				query = session_player.entry_eligibility("prayer/" + str(fixed.id) + "/shallow")
				if query.get("ok", false): break
		for op: String in ["end_actions", "advance", "advance", "advance", "advance", "finish_events"]:
			var submitted: Dictionary = session_player._submit(op)
			if not submitted.get("ok", false): valid = false; break
		rounds += 1
	var restored: Dictionary = session_player._build(1)
	var snapshot: String = session_player.turn.snapshot()
	var exact: bool = restored.get("ok", false) and restored.turn.restore(snapshot) and restored.turn.snapshot() == snapshot
	_check("OQ-SESSION", "A real Session B source reaches original fixation and the actual shared actions admission", valid and query.get("ok", false) and not production.is_empty() and exact, {"startup": started, "rounds": rounds, "productionTick": production.id if not production.is_empty() else "", "source": source, "root": production.changes.choice.root if not production.is_empty() else "", "attempts": production.changes.attempts if not production.is_empty() else [], "fixed": fixed, "actualActionsQuery": query, "phase": session_player.turn.context.phase, "componentRestoreExact": exact, "restoreError": restored.turn.last_error if restored.get("ok", false) else restored, "kind": "actual_Session_original_B_fix_and_actions_not_natural_frequency"})

func _components_and_rollback() -> void:
	var data: Dictionary = _attach_dispatch(_dispatch_native(7919))
	var valid: bool = _boot(data).get("ok", false) and _open(data) and _submit(data, "end_actions").get("ok", false)
	var before: String = data.turn.snapshot()
	data.world.reject_dispatch = true
	var request: Dictionary = {"id": "OQ-RETRY", "op": "advance", "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	var rejected: Dictionary = data.turn.submit(request)
	var rolled_back: bool = not rejected.get("ok", false) and before == data.turn.snapshot()
	data.world.reject_dispatch = false
	var retried: Dictionary = data.turn.submit(request)
	var once: String = data.turn.snapshot()
	var repeated: Dictionary = data.turn.submit(request)
	var replay_exact: bool = retried.get("ok", false) and repeated.get("ok", false) and once == data.turn.snapshot()
	var saved: String = session_player.turn.snapshot()
	var outer: Dictionary = World._normalize_numbers(JSON.parse_string(saved))
	var inner: Dictionary = World._normalize_numbers(JSON.parse_string(outer.body.world))
	inner.body.state.prayer_dispatch.sources["DOMAIN-001"].ROOT_CURRENT_APPEAL.missed_due_slots += 1
	var restore_target: Dictionary = session_player._build(1)
	var forged: bool = not restore_target.turn.restore(_resign(outer, inner))
	outer = World._normalize_numbers(JSON.parse_string(saved)); inner = World._normalize_numbers(JSON.parse_string(outer.body.world))
	inner.body.state.prayer_dispatch.schema = 1
	var obsolete: bool = not restore_target.turn.restore(_resign(outer, inner))
	var source_binding: bool = false; var source_control: Dictionary = {}
	for tick: Dictionary in _facts(session_player.world, "prayer_dispatch_tick"):
		for attempt: Dictionary in tick.changes.get("attempts", []):
			if attempt.root != "ROOT_CURRENT_PACT" or str(attempt.source).is_empty(): continue
			var original: bool = DispatchPolicy._valid_b_source(session_player.world.state, attempt.source, tick.domain, attempt.root, attempt.fact_before, tick.turn)
			var impersonated: bool = DispatchPolicy._valid_b_source(session_player.world.state, attempt.source, tick.domain, "ROOT_PURSUIT", attempt.fact_before, tick.turn)
			source_binding = original and not impersonated
			source_control = {"actualSource": attempt.source, "actualRoot": attempt.root, "actualAccepted": original, "wrongFamily": "ROOT_PURSUIT", "wrongFamilyAccepted": impersonated}
	var source_before_modes: Dictionary = session_player.world.state.prayer_dispatch.duplicate(true)
	var cursor_before_modes: Dictionary = session_player.world.state.simulation.cursors.duplicate(true)
	var released: Dictionary = session_player._submit("attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}})
	var focused: Dictionary = session_player._submit("attention", {"command": {"kind": "focus", "domain": "DOMAIN-001"}})
	var modes_exact: bool = released.get("ok", false) and focused.get("ok", false) and source_before_modes == session_player.world.state.prayer_dispatch and cursor_before_modes == session_player.world.state.simulation.cursors
	saved = session_player.turn.snapshot()
	var ledger_before: Dictionary = session_player.world.state.opportunities.duplicate(true)
	var tx: RefCounted = _activate({"world": session_player.world, "turn": session_player.turn})
	var view: Dictionary = session_player.world._evolution_snapshot()
	var plan: Dictionary = DispatchPolicy.prepare(session_player.world, view, session_player.modules.events, session_player.turn)
	var committed: bool = plan.get("ok", false) and DispatchPolicy.commit(session_player.world, plan, session_player.modules.events, session_player.turn)
	var separate: bool = committed and ledger_before == session_player.world.state.opportunities
	_undo({"world": session_player.world, "turn": session_player.turn}, tx)
	_check("OQ-COMPONENTS", "Original transaction rollback, retry, replay and version/source audit preserve separate direct-service debt", valid and rolled_back and replay_exact and forged and obsolete and source_binding and modes_exact and separate and saved == session_player.turn.snapshot(), {"injectedRejection": rejected, "rollbackExact": rolled_back, "retry": retried, "idempotentReplayExact": replay_exact, "forgedDebtRejected": forged, "obsoleteSchemaRejected": obsolete, "realSourceFamilyBinding": source_control, "modeSwitchKeepsOriginalCursorAndDebt": modes_exact, "BDoesNotClearServiceLedger": separate, "kind": "actual_component_transaction_and_restore_controls"})
