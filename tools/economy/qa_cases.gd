extends RefCounted
## Independent economy assertions. Existing objects and authorized upstream facts
## are explicit test preconditions; all economy results run production Economy.

const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Turn = preload("res://src/game/turn.gd")
const Economy = preload("res://src/game/economy.gd")

class FaultWorld extends World:
	var inject_failure: bool = false
	var observed: Dictionary = {}
	func evolve(owner: Object = null, economic_batch: Dictionary = {}) -> Array:
		var actions: Array = super.evolve(owner, economic_batch)
		if inject_failure and state.phase == "between":
			observed = {"faith": state.faith, "followers": state.domains["DOMAIN-001"].unnamed_followers, "npc_updates": stats.npc_updates}
			# Fault injection happens only after the entire production evolution.
			# It neither supplies replacement NPC intentions nor computes economics.
			randoms.checks.randi_range(1, 100)
			state.phase = "actions"
		return actions

var content: RefCounted
var records: Array = []
var sequence: int = 0
var inject_deadline_failure: bool = false
var observed_income_at_failure: int = -1

func run(catalog: RefCounted) -> Array:
	content = catalog
	records = []
	sequence = 0
	_test_replaced_followers()
	_test_round_trip_followers()
	_test_nomination_and_named_death()
	_test_formula_rounding()
	_test_exact_attrition_continuation()
	_test_plan_preview_purity()
	_test_inconsistent_economy_snapshots()
	_test_new_cult_income_preview()
	_test_anchor_activation_boundary()
	_test_anchor_refusal_timing()
	_test_shared_alert_merge()
	_test_expansion_snapshot_and_knowledge()
	_test_deadline_income_atomicity()
	_test_prepay_budget_order()
	_test_capacity_after_refusal()
	_test_full_evolution_rollback()
	_test_round_start_population_order()
	_test_unavailable_cult_operation()
	_test_dictionary_order_independence()
	return records

func _check(id: String, name: String, passed: bool, details: Dictionary = {}) -> void:
	records.append({"id": id, "name": name, "status": "pass" if passed else "fail", "details": details})

func _source(world: RefCounted, domain: String = "DOMAIN-001") -> String:
	return world.state.domains[domain].origin

func _new_world(catalog: RefCounted, fault_world: bool = false) -> RefCounted:
	var world: RefCounted = FaultWorld.new(catalog) if fault_world else World.new(catalog)
	world.generate(1979)
	return world

func _setup(followers: int = 36, cohesion: int = 100, catalog: RefCounted = null, create_cult: bool = true, prepare: Callable = Callable(), fault_world: bool = false) -> Dictionary:
	var actual_catalog: RefCounted = catalog if catalog != null else content
	var world: RefCounted = _new_world(actual_catalog, fault_world)
	var economy: RefCounted = Economy.new(actual_catalog, {"qa-upstream": "1"})
	var ok: bool = economy.initialize(world)
	var domain: String = "DOMAIN-001"
	var leader: String = world.state.institutions[domain + "/order"].representative
	# The named leader's faith is an existing-world precondition, not a fabricated
	# economy result or a claim that player recruitment is already implemented.
	world.state.npcs[leader].loyalty = 100
	if followers > 0:
		ok = world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": followers, "parents": [_source(world)]}) and ok
	if create_cult:
		var cause: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [_source(world)],
			{"issuer": "qa-upstream", "version": "1", "cult": "CULT-QA", "domain": domain, "leader": leader, "cohesion": cohesion}, [])
		ok = not cause.is_empty() and ok
		ok = world.submit({"kind": "establish_cult", "authorization": cause, "parents": [cause]}) and ok
	if prepare.is_valid():
		ok = prepare.call(world) and ok
	var turn: RefCounted = Turn.new(world)
	ok = economy.install(turn) and ok
	ok = turn.register_participant("qa-upstream", "1", ["events", "actions", "start", "deadlines", "ending"], ["world_command", "fact", "check", "schedule"], _upstream) and ok
	return {"world": world, "turn": turn, "economy": economy, "leader": leader, "ok": ok}

func _upstream(context: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": context.participant_state.duplicate(true)}
	if input.slot == "events" and input.operation == "gather":
		result["events"] = []
	if input.operation == "act":
		var source: String = context.world.domains["DOMAIN-001"].origin
		result["meta"] = {"faith_cost": 0, "whispers_cost": 0, "min_awakening": 0, "responds": false, "used_power": false, "used_relic": false, "actor": "", "source": source, "outcome": "authorized_QA_upstream"}
		if input.action == "command":
			result.effects.append({"type": "world_command", "source": source, "command": input.payload.command})
		elif input.action == "fact":
			result.effects.append(input.payload.effect)
		elif input.action == "schedule":
			result.effects.append({"type": "schedule", "job": input.payload.job})
		elif input.action == "set_fixture":
			result.meta.faith_cost = 1
			result.state = input.payload.duplicate(true)
		else:
			result.ok = false
		result.empty = result.effects.is_empty()
	if input.slot == "start" and input.operation == "due":
		if input.action != "population":
			result.ok = false
		else:
			result.effects.append({"type": "world_command", "source": input.source, "command": input.payload.command})
		result.empty = result.effects.is_empty()
	if input.slot == "deadlines" and input.operation == "settle" and not result.state.get("used", false):
		var mode: String = result.state.get("fixture", "")
		if mode in ["kill_leader", "income_fault"]:
			var source: String = context.world.domains["DOMAIN-001"].origin
			var target: String = result.state.target
			result.state["used"] = true
			if mode == "kill_leader":
				result.effects.append({"type": "world_command", "source": source, "command": {"kind": "status", "npc": target, "status": "dead", "parents": [source]}})
			elif inject_deadline_failure:
				# Test-only telemetry and fault switch: formal income has already run.
				observed_income_at_failure = context.world.faith
				result.effects.append({"type": "check", "source": source, "npc": target, "attribute": "will", "domain": "DOMAIN-001", "mode": "occult", "preparation": 0, "branches": {"deep": [], "success": [], "failure": [], "disaster": []}})
				result.effects.append({"type": "world_command", "source": source, "command": {"kind": "status", "npc": target, "status": "dead", "parents": [source]}})
				result.effects.append({"type": "world_command", "source": source, "command": {"kind": "migrate", "npc": target, "domain": context.world.domains["DOMAIN-001"].neighbors[0], "parents": [source]}})
			result.empty = result.effects.is_empty()
	return result

func _request(setup: Dictionary, operation: String, extra: Dictionary = {}) -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "ECON-QA-%d" % sequence, "op": operation, "turn": setup.turn.context.turn, "phase": setup.turn.context.phase}
	request.merge(extra)
	return request

func _do(setup: Dictionary, operation: String, extra: Dictionary = {}) -> bool:
	return setup.turn.submit(_request(setup, operation, extra)).get("ok", false)

func _open(setup: Dictionary) -> bool:
	return _do(setup, "advance") and _do(setup, "finish_events")

func _close(setup: Dictionary) -> bool:
	return _do(setup, "end_actions") and _do(setup, "advance") and _do(setup, "advance") and _do(setup, "advance")

func _command(setup: Dictionary, command: Dictionary) -> bool:
	return _do(setup, "act", {"participant": "qa-upstream", "action": "command", "payload": {"command": command}})

func _population(setup: Dictionary, mode: String, amount: int, domain: String = "DOMAIN-001", target: String = "") -> bool:
	var command: Dictionary = {"kind": "population", "domain": domain, "mode": mode, "amount": amount, "parents": [_source(setup.world)]}
	if mode == "migrate":
		command["target"] = target
	return _command(setup, command)

func _plan(strategy: String = "hold") -> Dictionary:
	return {"strategies": {"CULT-QA": strategy}, "anchor_priority": [], "refuse_anchors": []}

func _test_replaced_followers() -> void:
	var setup: Dictionary = _setup()
	var initial_faith: int = setup.world.state.faith
	var initial_population: int = setup.world.state.domains["DOMAIN-001"].population
	var ok: bool = setup.ok and _open(setup)
	ok = _population(setup, "leave", 9) and ok
	ok = _population(setup, "convert", 9) and ok
	ok = _close(setup) and ok
	var actual_income: int = int(setup.world.state.faith) - initial_faith
	_check("ECON-QA-001", "旧信众流失后补新人不能按相同总人数重复供奉", ok and setup.world.state.domains["DOMAIN-001"].unnamed_followers == 36 and setup.world.state.domains["DOMAIN-001"].population == initial_population and actual_income == 5,
		{"start_followers": 36, "old_lost": 9, "new_added": 9, "expected_eligible": 27, "expected_income": 5, "actual_income": actual_income})

func _test_round_trip_followers() -> void:
	var setup: Dictionary = _setup()
	var world: RefCounted = setup.world
	var destination: String = world.state.domains["DOMAIN-001"].neighbors[0]
	var initial_faith: int = world.state.faith
	var original_pair: int = int(world.state.domains["DOMAIN-001"].population) + int(world.state.domains[destination].population)
	var ok: bool = setup.ok and _open(setup)
	var command: Dictionary = {"kind": "population", "domain": "DOMAIN-001", "mode": "migrate", "amount": 9, "target": destination, "parents": [_source(world)]}
	var request: Dictionary = _request(setup, "act", {"participant": "qa-upstream", "action": "command", "payload": {"command": command}})
	var first: Dictionary = setup.turn.submit(request)
	var migrated: String = setup.turn.snapshot()
	var replay: Dictionary = setup.turn.submit(request.duplicate(true))
	var no_second_move: bool = first.get("ok", false) and World.canonical(first) == World.canonical(replay) and migrated == setup.turn.snapshot()
	ok = _population(setup, "migrate", 9, destination, "DOMAIN-001") and ok
	ok = _close(setup) and ok
	var pair: int = int(world.state.domains["DOMAIN-001"].population) + int(world.state.domains[destination].population)
	_check("ECON-QA-002", "无名信众往返不恢复当轮资格，重送迁移不复制人口", ok and no_second_move and pair == original_pair and world.state.domains["DOMAIN-001"].unnamed_followers == 36 and world.state.domains[destination].unnamed_followers == 0 and int(world.state.faith) - initial_faith == 5,
		{"expected_income": 5, "actual_income": int(world.state.faith) - initial_faith, "replay_preserved_snapshot": no_second_move, "population_conserved": pair == original_pair})

func _test_nomination_and_named_death() -> void:
	var setup: Dictionary = _setup(50)
	var world: RefCounted = setup.world
	var initial_faith: int = world.state.faith
	var initial_population: int = world.state.domains["DOMAIN-001"].population
	var prior_ids: Array = world.state.npcs.keys()
	var leader: Dictionary = world.state.npcs[setup.leader]
	var ok: bool = setup.ok and _open(setup)
	ok = _command(setup, {"kind": "nominate", "domain": "DOMAIN-001", "profile": leader.profile, "institution": leader.institution, "group": "unnamed_followers", "parents": [_source(world)]}) and ok
	var added: Array = []
	for id: String in world.state.npcs:
		if not id in prior_ids:
			added.append(id)
	var one_nomination: bool = added.size() == 1 and world.state.domains["DOMAIN-001"].population == initial_population and world.state.domains["DOMAIN-001"].unnamed_followers == 49
	if added.size() == 1:
		ok = _command(setup, {"kind": "status", "npc": added[0], "status": "dead", "parents": [_source(world)]}) and ok
	else:
		ok = false
	ok = _close(setup) and ok
	_check("ECON-QA-003", "提名扣无名资格，具名死者不再扣第二个无名信众", ok and one_nomination and world.state.domains["DOMAIN-001"].unnamed_followers == 49 and world.state.domains["DOMAIN-001"].population == initial_population - 1 and int(world.state.faith) - initial_faith == 7,
		{"one_nomination": one_nomination, "expected_income": 7, "actual_income": int(world.state.faith) - initial_faith})

func _changed_catalog(key: String, new_value: String) -> Dictionary:
	var directory: String = "user://economy-independent-qa-%s" % str(Time.get_ticks_usec())
	var created: bool = DirAccess.make_dir_recursive_absolute(directory) == OK
	for name: String in Catalog.FILES:
		var text: String = FileAccess.get_file_as_string("res://data/" + name + ".csv")
		if name == "run_parameters":
			var lines: PackedStringArray = text.split("\n")
			for index: int in lines.size():
				if lines[index].begins_with(key + ","):
					var cells: PackedStringArray = lines[index].split(",")
					cells[2] = new_value
					lines[index] = ",".join(cells)
			text = "\n".join(lines)
		var file: FileAccess = FileAccess.open(directory.path_join(name + ".csv"), FileAccess.WRITE)
		if file == null:
			created = false
		else:
			file.store_string(text)
			file.close()
	var catalog: RefCounted = Catalog.new()
	var loaded: bool = created and catalog.load_files(directory)
	for name: String in Catalog.FILES:
		DirAccess.remove_absolute(directory.path_join(name + ".csv"))
	DirAccess.remove_absolute(directory)
	return {"catalog": catalog, "ok": loaded}

func _test_formula_rounding() -> void:
	var baseline: Dictionary = _setup(15, 80)
	var before: int = baseline.world.state.faith
	var ok: bool = baseline.ok and _open(baseline) and _close(baseline)
	var base_income: int = int(baseline.world.state.faith) - before
	var changed: Dictionary = _changed_catalog("conceal_income_multiplier", "0.75")
	var concealed: Dictionary = _setup(8, 100, changed.catalog)
	before = concealed.world.state.faith
	ok = concealed.ok and changed.ok and _open(concealed) and ok
	ok = _do(concealed, "set_plan", {"participant": "economy", "payload": _plan("conceal")}) and ok
	ok = _close(concealed) and ok
	var concealed_income: int = int(concealed.world.state.faith) - before
	_check("ECON-QA-004", "收入读取CSV并在全部系数应用后只最终取整", ok and base_income == 3 and concealed_income == 2,
		{"hold_n15_cohesion80": base_income, "conceal_n8_cohesion100_csv075": concealed_income, "scope": "敛藏系数变体仅写隔离测试CSV并通过正式Catalog加载"})

func _test_exact_attrition_continuation() -> void:
	var details: Array = []
	var passed: bool = true
	for parameters: Array in [[10, 75], [25, 90]]:
		var n: int = parameters[0]
		var cohesion: int = parameters[1]
		var original: Dictionary = _setup(n, cohesion)
		var ok: bool = original.ok
		for index: int in 19:
			ok = _open(original) and _close(original) and ok
		var before_twentieth: int = original.world.state.domains["DOMAIN-001"].unnamed_followers
		var resumed: Dictionary = _setup(n, cohesion)
		ok = resumed.ok and resumed.turn.restore(original.turn.snapshot()) and ok
		for operation: String in ["advance", "finish_events", "end_actions", "advance", "advance", "advance"]:
			var request: Dictionary = _request(original, operation)
			var first: Dictionary = original.turn.submit(request)
			var second: Dictionary = resumed.turn.submit(request.duplicate(true))
			ok = first.get("ok", false) and second.get("ok", false) and World.canonical(first) == World.canonical(second) and ok
		var after_twentieth: int = original.world.state.domains["DOMAIN-001"].unnamed_followers
		var same: bool = original.turn.snapshot() == resumed.turn.snapshot()
		var valid: bool = ok and before_twentieth == n and after_twentieth == n - 1 and same
		passed = passed and valid
		details.append({"start_followers": n, "cohesion": cohesion, "exact_loss_per_turn": "0.05", "after_19": before_twentieth, "after_20": after_twentieth, "restored_equals_continuous": same, "pass": valid})
	_check("ECON-QA-005", "0.05人流失跨十九轮存档后第二十轮恰扣一人", passed, {"cases": details})

func _test_plan_preview_purity() -> void:
	var setup: Dictionary = _setup()
	var ok: bool = setup.ok and _open(setup)
	ok = _do(setup, "set_plan", {"participant": "economy", "payload": _plan("hold")}) and ok
	var before: String = setup.turn.snapshot()
	var first: Dictionary = setup.turn.preview_plan("economy", _plan("hold"))
	var second: Dictionary = setup.turn.preview_plan("economy", _plan("hold"))
	var pure: bool = first.get("ok", false) and World.canonical(first) == World.canonical(second) and before == setup.turn.snapshot()
	var invalids: Array = [
		{"strategies": {"CULT-QA": "FREE_MONEY"}, "anchor_priority": [], "refuse_anchors": []},
		{"strategies": {"UNKNOWN": "hold"}, "anchor_priority": [], "refuse_anchors": []},
		{"strategies": {"CULT-QA": "hold"}, "anchor_priority": ["UNKNOWN"], "refuse_anchors": []},
		{"strategies": {"CULT-QA": "hold"}, "anchor_priority": [], "refuse_anchors": [], "faith_cost": -1},
		{"strategies": [], "anchor_priority": [], "refuse_anchors": []},
	]
	var rejected: bool = true
	for plan: Dictionary in invalids:
		var preview: Dictionary = setup.turn.preview_plan("economy", plan)
		var applied: Dictionary = setup.turn.submit(_request(setup, "set_plan", {"participant": "economy", "payload": plan}))
		rejected = not preview.get("ok", true) and not applied.get("ok", true) and before == setup.turn.snapshot() and rejected
	_check("ECON-QA-006", "重复预览纯读，坏计划拒绝且保留之前合法计划", ok and pure and rejected,
		{"repeat_preview_pure": pure, "invalid_plan_cases": invalids.size(), "rejected_without_changes": rejected})

func _test_inconsistent_economy_snapshots() -> void:
	var setup: Dictionary = _setup()
	var ok: bool = setup.ok and _open(setup)
	var original: String = setup.turn.snapshot()
	var cases: Array = []
	for mode: String in ["prepaid_before_phase4", "income_before_phase5", "future_remainder", "wrong_income_source", "wrong_cohort_source", "cohort_count_conflicts_with_source"]:
		var outer: Dictionary = World._normalize_numbers(JSON.parse_string(original))
		var inner: Dictionary = World._normalize_numbers(JSON.parse_string(outer.body.world))
		var state: Dictionary = inner.body.state
		match mode:
			"prepaid_before_phase4": state.economy.prepay_turn = state.turn
			"income_before_phase5": state.economy.income_turn = state.turn
			"future_remainder": state.economy.remainders["CULT-QA"] = Economy.ATTRITION_UNIT
			"wrong_income_source": state.economy.income_sources["CULT-QA"] = state.domains["DOMAIN-001"].origin
			"wrong_cohort_source": state.economy.cohort_sources["DOMAIN-001"] = state.domains["DOMAIN-001"].origin
			"cohort_count_conflicts_with_source": state.economy.eligible["DOMAIN-001"] = 35
		inner.checksum = World.canonical(inner.body).sha256_text()
		outer.body.world = World.canonical(inner)
		outer.checksum = World.canonical(outer.body).sha256_text()
		var restored: bool = setup.turn.restore(World.canonical(outer))
		var rejected: bool = not restored and setup.turn.snapshot() == original
		cases.append({"case": mode, "rejected_without_changes": rejected})
		ok = rejected and ok
		if restored:
			setup.turn.restore(original)
	_check("ECON-QA-007", "双层重签的经济时钟、来源和余量矛盾存档仍完整拒绝", ok, {"cases": cases})

func _authorize_cult_during_turn(setup: Dictionary, cohesion: int) -> bool:
	var domain: String = "DOMAIN-001"
	var leader: String = setup.leader
	var effect: Dictionary = {"type": "fact", "source": _source(setup.world), "kind": "cult_establishment_authorized", "domain": domain, "actor": leader, "targets": [leader], "observers": [], "institutions": [],
		"details": {"issuer": "qa-upstream", "version": "1", "cult": "CULT-QA", "domain": domain, "leader": leader, "cohesion": cohesion}}
	if not _do(setup, "act", {"participant": "qa-upstream", "action": "fact", "payload": {"effect": effect}}):
		return false
	var authorization: String = ""
	for fact: Dictionary in setup.world.state.facts.values():
		if fact.kind == "cult_establishment_authorized" and fact.turn == setup.world.state.turn and fact.changes.get("cult") == "CULT-QA":
			authorization = fact.id
	return not authorization.is_empty() and _command(setup, {"kind": "establish_cult", "authorization": authorization, "parents": [authorization]})

func _test_new_cult_income_preview() -> void:
	var setup: Dictionary = _setup(36, 100, null, false)
	var initial_faith: int = setup.world.state.faith
	var ok: bool = setup.ok and _open(setup)
	ok = _authorize_cult_during_turn(setup, 100) and ok
	var preview: Dictionary = setup.turn.preview_plan("economy", _plan("hold"))
	var predicted: int = -1
	if preview.get("ok", false) and preview.preview.cults.size() == 1:
		predicted = preview.preview.cults[0].income_if_unchanged
	ok = _close(setup) and ok
	var actual_income: int = int(setup.world.state.faith) - initial_faith
	_check("ECON-QA-008", "本轮新成立教团正式收入和已知条件预览均为零", ok and actual_income == 0 and predicted == 0,
		{"preview_income": predicted, "actual_income": actual_income, "scope": "成立由显式测试上游授权；经济收入为正式生产规则"})

func _add_anchor(world: RefCounted, status: String, pollution: int = 20) -> bool:
	var domain: String = "DOMAIN-001"
	var leader: String = world.state.cults["CULT-QA"].leader
	var source: String = world._record("qa_existing_anchor", domain, leader, [], [_source(world)], {"scope": "existing_object_precondition"})
	world.state.domains[domain].pollution = pollution
	world.state.relics["RELIC-QA"] = {"id": "RELIC-QA", "domain": domain, "holder": "", "placement": "bound", "anchor": "ANCHOR-QA"}
	world.state.anchors["ANCHOR-QA"] = {"id": "ANCHOR-QA", "domain": domain, "institution": domain + "/order", "state": status, "guardian": leader, "relic": "RELIC-QA", "needs_rebind": false, "origin": source, "ordinal": 1, "cult": "CULT-QA"}
	var qualified: bool = world.submit({"kind": "economy_qualification", "rule": "anchor", "subject": "ANCHOR-QA", "institution": domain + "/order", "allowed": true, "issuer": "qa-upstream", "version": "1", "parents": [source]})
	world._refresh_anchors()
	return qualified

func _test_anchor_activation_boundary() -> void:
	var cases: Array = []
	var passed: bool = true
	for status: String in ["active", "dormant", "destroyed"]:
		var setup: Dictionary = _setup(36, 100, null, true, _add_anchor.bind(status, 20))
		var initial_faith: int = setup.world.state.faith
		var ok: bool = setup.ok and _open(setup) and _close(setup)
		var current: String = setup.world.state.anchors["ANCHOR-QA"].state
		var pollution: int = setup.world.state.domains["DOMAIN-001"].pollution
		var expected_pollution: int = 20 if status == "active" else 18
		var upkeep: int = 0 if status == "destroyed" else 1
		var exact_faith: bool = int(setup.world.state.faith) == initial_faith - upkeep + 6
		var valid: bool = ok and pollution == expected_pollution and current == status and exact_faith
		passed = passed and valid
		cases.append({"initial_state": status, "final_state": current, "pollution": pollution, "expected_pollution": expected_pollution, "charged_upkeep": upkeep, "faith_correct": exact_faith, "pass": valid})
	_check("ECON-QA-009", "新恢复休眠锚付费不提前保护本批污染，毁坏锚不收费", passed, {"cases": cases, "scope": "已有锚点与上游资格为开轮前准备，支付/自然演化/复核使用正式规则"})

func _test_anchor_refusal_timing() -> void:
	var setup: Dictionary = _setup(36, 100, null, true, _add_anchor.bind("active", 20))
	var ok: bool = setup.ok and _open(setup)
	var before_awakening: int = setup.world.state.awakening
	var before_faith: int = setup.world.state.faith
	var plan: Dictionary = _plan("hold")
	plan.refuse_anchors = ["ANCHOR-QA"]
	ok = _do(setup, "set_plan", {"participant": "economy", "payload": plan}) and ok
	var plan_only: bool = setup.world.state.anchors["ANCHOR-QA"].state == "active" and setup.world.state.awakening == before_awakening and setup.world.state.faith == before_faith
	ok = _do(setup, "end_actions") and _do(setup, "advance") and ok
	var after_prepay: bool = setup.world.state.anchors["ANCHOR-QA"].state == "dormant" and setup.world.state.awakening == before_awakening - 4 and setup.world.state.faith == before_faith
	_check("ECON-QA-010", "拒付计划不提前撤贡献，实际阶段四拒付才休眠且不收费", ok and plan_only and after_prepay,
		{"plan_kept_active_contribution": plan_only, "settlement_removed_contribution": after_prepay})

func _prepare_alert_merge(world: RefCounted) -> bool:
	var domain: String = "DOMAIN-001"
	var witness: String = world.state.institutions[domain + "/propagation"].representative
	world.state.npcs[witness].loyalty = 50
	world.state.npcs[witness].sanity = 80
	world.state.domains[domain].alert = world.catalog.integer("attribute_max")
	var miracle: String = world.introduce_fact("miracle", domain, witness, [witness], [_source(world)], {"public": true, "witnesses": [witness]}, [witness])
	var anomaly: String = world.introduce_fact("public_anomaly", domain, witness, [witness], [_source(world)], {}, [witness])
	return not miracle.is_empty() and not anomaly.is_empty()

func _test_shared_alert_merge() -> void:
	var setup: Dictionary = _setup(36, 100, null, true, _prepare_alert_merge)
	var witness: String = setup.world.state.institutions["DOMAIN-001/propagation"].representative
	var ok: bool = setup.ok and _open(setup)
	ok = _do(setup, "set_plan", {"participant": "economy", "payload": _plan("conceal")}) and ok
	ok = _close(setup) and ok
	var acted: bool = int(setup.world.state.npcs[witness].loyalty) > 50
	var alert: int = setup.world.state.domains["DOMAIN-001"].alert
	var starting: int = content.integer("attribute_max")
	var npc_delta: int = content.integer("interpretation_public_alert")
	var conceal_delta: int = content.integer("conceal_alert")
	var expected: int = clampi(starting + npc_delta + conceal_delta, 0, starting)
	_check("ECON-QA-011", "同批NPC公开解释与敛藏增减相加后一次裁界", ok and acted and alert == expected,
		{"starting_alert": starting, "npc_public_alert": npc_delta, "conceal_alert": conceal_delta, "expected_alert": expected, "actual_alert": alert, "actual_npc_interpretation": acted})

func _prepare_expansion_snapshot(world: RefCounted) -> bool:
	var domain: String = "DOMAIN-001"
	var leader: String = world.state.cults["CULT-QA"].leader
	# One testimony stays below confirmation, so next turn really has an
	# available investigation rather than an already-completed target.
	world.state.npcs[leader].insight = 0
	world.state.npcs[leader].sanity = 80
	var source: String = world.introduce_fact("exposure", domain, leader, [leader], [_source(world)], {"public": true}, [leader], [domain + "/order"])
	world.state.domains[domain].alert = 29
	world.state.domains[domain].barrier = 70
	return not source.is_empty() and world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": "CULT-QA", "institution": domain + "/propagation", "allowed": true, "issuer": "qa-upstream", "version": "1", "parents": [source]})

func _test_expansion_snapshot_and_knowledge() -> void:
	var setup: Dictionary = _setup(36, 100, null, true, _prepare_expansion_snapshot)
	var world: RefCounted = setup.world
	var expected_growth: int = content.integer("expansion_base_growth") + int(floor(float(world.state.npcs[setup.leader].influence) / content.number("expansion_influence_divisor")))
	var ok: bool = setup.ok and _open(setup)
	ok = _do(setup, "set_plan", {"participant": "economy", "payload": _plan("expand")}) and ok
	ok = _close(setup) and ok
	var after_first: int = world.state.domains["DOMAIN-001"].alert
	var first_no_plan: bool = world.state.domains["DOMAIN-001"].pending_plan.is_empty()
	var growth: int = int(world.state.domains["DOMAIN-001"].unnamed_followers) - 36
	var private_knowledge: bool = true
	var expansion_sources: Array = []
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "exposure" and fact.changes.get("rule") == "expansion":
			expansion_sources.append(fact.id)
			for role: String in ["interpretation", "propagation"]:
				var institution: Dictionary = world.state.institutions["DOMAIN-001/" + role]
				private_knowledge = not HistoryIndex.has(institution.known_facts, fact.id) and not HistoryIndex.has(world.state.npcs[institution.representative].known_facts, fact.id) and private_knowledge
	var first_exposure: bool = world.state.domains["DOMAIN-001"].exposure_turn == 1 and expansion_sources.size() == 1
	ok = _open(setup) and _close(setup) and ok
	var next_plan: bool = not world.state.domains["DOMAIN-001"].pending_plan.is_empty()
	_check("ECON-QA-012", "传教真实增长和暴露不倒灌同批计划，也不广播精确领袖身份", ok and growth == expected_growth and after_first == 31 and first_exposure and first_no_plan and next_plan and private_knowledge,
		{"growth": growth, "expected_growth": expected_growth, "first_alert": after_first, "first_no_plan": first_no_plan, "next_turn_has_plan": next_plan, "unwitnessed_institutions_did_not_learn": private_knowledge, "actual_exposure": first_exposure})

func _test_deadline_income_atomicity() -> void:
	var cases: Array = []
	var passed: bool = true
	for mode: String in ["kill_leader", "income_fault"]:
		var setup: Dictionary = _setup()
		var world: RefCounted = setup.world
		var initial_faith: int = world.state.faith
		var ok: bool = setup.ok and _open(setup)
		ok = _do(setup, "act", {"participant": "qa-upstream", "action": "set_fixture", "payload": {"fixture": mode, "target": setup.leader}}) and ok
		ok = _do(setup, "end_actions") and _do(setup, "advance") and ok
		var before: String = setup.turn.snapshot()
		var prior_npc_updates: int = world.stats.npc_updates
		var request: Dictionary = _request(setup, "advance")
		inject_deadline_failure = mode == "income_fault"
		observed_income_at_failure = -1
		var result: Dictionary = setup.turn.submit(request)
		if mode == "kill_leader":
			var retained: bool = result.get("ok", false) and world.state.npcs[setup.leader].status == "dead" and int(world.state.faith) == initial_faith - 1 + 6
			ok = ok and retained
			cases.append({"case": mode, "income_not_retroactively_revoked": retained, "faith": world.state.faith})
		else:
			var restored: bool = not result.get("ok", true) and setup.turn.snapshot() == before and observed_income_at_failure == initial_faith - 1 + 6
			inject_deadline_failure = false
			var retry: Dictionary = setup.turn.submit(request.duplicate(true))
			var after: String = setup.turn.snapshot()
			var replay: Dictionary = setup.turn.submit(request.duplicate(true))
			var once: bool = retry.get("ok", false) and int(world.state.faith) == initial_faith - 1 + 6 and world.stats.npc_updates == prior_npc_updates and World.canonical(retry) == World.canonical(replay) and after == setup.turn.snapshot()
			ok = ok and restored and once
			cases.append({"case": mode, "saw_real_income_before_failure": observed_income_at_failure, "whole_state_rng_ledger_rollback": restored, "retry_once_no_extra_npc_or_income": once})
		passed = passed and ok
	_check("ECON-QA-013", "收入先于期限，失败整阶段回滚账本与RNG，重试不重收不复演化", passed, {"cases": cases})

func _prepare_budget(world: RefCounted, faith: int) -> bool:
	var ok: bool = _add_anchor(world, "active", 20)
	world.state.faith = faith
	return world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": "CULT-QA", "institution": "DOMAIN-001/propagation", "allowed": true, "issuer": "qa-upstream", "version": "1", "parents": [_source(world)]}) and ok

func _test_prepay_budget_order() -> void:
	var cases: Array = []
	var passed: bool = true
	for available: int in [0, 1, 2]:
		var setup: Dictionary = _setup(36, 100, null, true, _prepare_budget.bind(available))
		var world: RefCounted = setup.world
		var growth: int = content.integer("expansion_base_growth") + int(floor(float(world.state.npcs[setup.leader].influence) / content.number("expansion_influence_divisor")))
		var ok: bool = setup.ok and _open(setup)
		ok = _do(setup, "set_plan", {"participant": "economy", "payload": _plan("expand")}) and ok
		ok = _do(setup, "end_actions") and _do(setup, "advance") and ok
		var expands: bool = available >= content.integer("expansion_faith_cost")
		var expected_followers: int = 36 + (growth if expands else 0)
		var expected_anchor: String = "active" if available == 1 else "dormant"
		var prepay_valid: bool = world.state.faith == 0 and world.state.domains["DOMAIN-001"].unnamed_followers == expected_followers and world.state.anchors["ANCHOR-QA"].state == expected_anchor and world.state.economy.effective["CULT-QA"] == ("expand" if expands else "hold") and world.state.cults["CULT-QA"].strategy == "expand"
		ok = _do(setup, "advance") and ok
		var income_after: bool = world.state.faith == 6
		passed = passed and ok and prepay_valid and income_after
		cases.append({"starting_faith": available, "prepay_correct": prepay_valid, "expected_anchor": expected_anchor, "expected_followers": expected_followers, "income_only_after_prepay": income_after})
	_check("ECON-QA-014", "现存资金先传教后供奉，缺资守持不丢意向且不垫未来收入", passed, {"cases": cases})

func _prepare_capacity(world: RefCounted) -> bool:
	var ok: bool = _add_anchor(world, "active", 20)
	world.state.faith = content.integer("faith_capacity_base") + int(world.state.peak_awakening) * content.integer("faith_capacity_per_peak_awakening") - 1
	return ok

func _test_capacity_after_refusal() -> void:
	var setup: Dictionary = _setup(36, 100, null, true, _prepare_capacity)
	var world: RefCounted = setup.world
	var peak: int = world.state.peak_awakening
	var expected_capacity: int = content.integer("faith_capacity_base") + peak * content.integer("faith_capacity_per_peak_awakening")
	var ok: bool = setup.ok and _open(setup)
	var plan: Dictionary = _plan("hold")
	plan.refuse_anchors = ["ANCHOR-QA"]
	ok = _do(setup, "set_plan", {"participant": "economy", "payload": plan}) and ok
	ok = _close(setup) and ok
	var income: Dictionary = {}
	if world.state.economy.income_sources.has("CULT-QA"):
		income = world.state.facts[world.state.economy.income_sources["CULT-QA"]].changes
	var accounted: bool = income.get("gross") == 6 and income.get("actual") == 1 and income.get("overflow") == 5
	_check("ECON-QA-015", "失去当前苏醒保留历史容量，超额供奉逐笔记为散失", ok and world.state.awakening == peak - 4 and world.state.peak_awakening == peak and world.state.faith == expected_capacity and accounted,
		{"peak": peak, "current_awakening": world.state.awakening, "capacity": expected_capacity, "actual_faith": world.state.faith, "income": income})

func _prepare_expand_only(world: RefCounted) -> bool:
	return world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": "CULT-QA", "institution": "DOMAIN-001/propagation", "allowed": true, "issuer": "qa-upstream", "version": "1", "parents": [_source(world)]})

func _test_full_evolution_rollback() -> void:
	var setup: Dictionary = _setup(36, 100, null, true, _prepare_expand_only, true)
	var world: RefCounted = setup.world
	var initial_faith: int = world.state.faith
	var growth: int = content.integer("expansion_base_growth") + int(floor(float(world.state.npcs[setup.leader].influence) / content.number("expansion_influence_divisor")))
	var ok: bool = setup.ok and _open(setup)
	ok = _do(setup, "act", {"participant": "qa-upstream", "action": "set_fixture", "payload": {"fixture": "no_deadline_effect", "target": setup.leader}}) and ok
	ok = _do(setup, "set_plan", {"participant": "economy", "payload": _plan("expand")}) and _do(setup, "end_actions") and ok
	var before: String = setup.turn.snapshot()
	var request: Dictionary = _request(setup, "advance")
	world.inject_failure = true
	var failure: Dictionary = setup.turn.submit(request)
	var actual_work: bool = world.observed.get("faith") == initial_faith - 1 - content.integer("expansion_faith_cost") and world.observed.get("followers") == 36 + growth and world.observed.get("npc_updates") == 72
	var restored: bool = not failure.get("ok", true) and setup.turn.snapshot() == before
	world.inject_failure = false
	var retry: Dictionary = setup.turn.submit(request.duplicate(true))
	var after: String = setup.turn.snapshot()
	var replay: Dictionary = setup.turn.submit(request.duplicate(true))
	var once: bool = retry.get("ok", false) and world.state.faith == initial_faith - 1 - content.integer("expansion_faith_cost") and world.state.domains["DOMAIN-001"].unnamed_followers == 36 + growth and world.stats.npc_updates == 72 and World.canonical(retry) == World.canonical(replay) and after == setup.turn.snapshot()
	_check("ECON-QA-016", "正式阶段四已支付招募和演化后故障，完整账本人口RNG回滚再单次提交", ok and actual_work and restored and once,
		{"observed_before_fault": world.observed, "production_work_happened": actual_work, "whole_snapshot_restored": restored, "retry_committed_once": once, "scope": "测试子类完整调用生产evolve后才注入故障，不替换经济或NPC/CIV算法"})

func _add_existing_cult(world: RefCounted, id: String, domain: String, followers: int, cohesion: int = 100) -> bool:
	var leader: String = world.state.institutions[domain + "/order"].representative
	world.state.npcs[leader].loyalty = 100
	if not world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": followers, "parents": [_source(world, domain)]}):
		return false
	var source: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [_source(world, domain)],
		{"issuer": "qa-upstream", "version": "1", "cult": id, "domain": domain, "leader": leader, "cohesion": cohesion}, [])
	return not source.is_empty() and world.submit({"kind": "establish_cult", "authorization": source, "parents": [source]})

func _prepare_neighbor_cult(world: RefCounted) -> bool:
	return _add_existing_cult(world, "CULT-QA-B", world.state.domains["DOMAIN-001"].neighbors[0], 9)

func _cohort_fact(world: RefCounted, domain: String, turn_number: int) -> Dictionary:
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "economy_income_cohort" and fact.domain == domain and fact.turn == turn_number:
			return fact
	return {}

func _prepare_existing_purge_evidence(world: RefCounted) -> bool:
	var domain: String = "DOMAIN-001"
	var institution: String = domain + "/order"
	var leader: String = world.state.cults["CULT-QA"].leader
	# Already-confirmed institutional evidence is the explicit initial-world
	# precondition. Candidate selection, warning delay and purge are production.
	var exposure: String = world.introduce_fact("exposure", domain, leader, [leader], [_source(world)], {"public": true}, [], [institution])
	if exposure.is_empty():
		return false
	var strength: int = content.integer("evidence_confirmation_strength")
	var confirmation: String = world._record("evidence_confirmed", domain, "", [leader], [exposure], {"institution": institution, "strength": strength, "scope": "existing_knowledge_precondition"})
	world.state.evidence[institution + "|" + leader] = {"institution": institution, "subject": leader, "strength": strength, "sources": [exposure], "confirmations": [confirmation]}
	world._institution_know(institution, confirmation)
	world.state.domains[domain].alert = 60
	world.state.domains[domain].barrier = 70
	return true

func _test_round_start_population_order() -> void:
	var original: Dictionary = _setup(36, 100, null, true, _prepare_neighbor_cult)
	var world: RefCounted = original.world
	var destination: String = world.state.domains["DOMAIN-001"].neighbors[0]
	var population_pair: int = int(world.state.domains["DOMAIN-001"].population) + int(world.state.domains[destination].population)
	var ok: bool = original.ok and _open(original)
	var source: String = _source(world)
	var command: Dictionary = {"kind": "population", "domain": "DOMAIN-001", "mode": "migrate", "amount": 9, "target": destination, "parents": [source]}
	var job: Dictionary = {"id": "QA-DUE-MIGRATION", "due": 2, "phase": "start", "action": "population", "payload": {"command": command}, "source": source}
	ok = _do(original, "act", {"participant": "qa-upstream", "action": "schedule", "payload": {"job": job}}) and _close(original) and ok
	var resumed: Dictionary = _setup(36, 100, null, true, _prepare_neighbor_cult)
	ok = resumed.ok and resumed.turn.restore(original.turn.snapshot()) and ok
	var start: Dictionary = _request(original, "advance")
	var first: Dictionary = original.turn.submit(start)
	var second: Dictionary = resumed.turn.submit(start.duplicate(true))
	ok = first.get("ok", false) and second.get("ok", false) and ok
	var captured: Dictionary = _cohort_fact(world, destination, 2)
	var transfer: Dictionary = {}
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "population_transfer" and fact.turn == 2 and fact.changes.get("mode") == "migrate":
			transfer = fact
	var captured_before_migration: bool = captured.get("changes", {}).get("eligible") == 9 and captured.get("id", "missing") in transfer.get("causal_parents", []) and transfer.get("changes", {}).get("eligible_removed") == 9
	var cohorts_correct: bool = world.state.domains["DOMAIN-001"].unnamed_followers == 27 and world.state.domains[destination].unnamed_followers == 18 and world.state.economy.eligible["DOMAIN-001"] == 27 and world.state.economy.eligible[destination] == 9
	var income_before: int = world.state.faith
	for operation: String in ["finish_events", "end_actions", "advance", "advance", "advance"]:
		var request: Dictionary = _request(original, operation)
		first = original.turn.submit(request)
		second = resumed.turn.submit(request.duplicate(true))
		ok = first.get("ok", false) and second.get("ok", false) and World.canonical(first) == World.canonical(second) and ok
	var migration_income: int = int(world.state.faith) - income_before
	var migration_valid: bool = ok and captured_before_migration and cohorts_correct and migration_income == 8 and population_pair == int(world.state.domains["DOMAIN-001"].population) + int(world.state.domains[destination].population) and original.turn.snapshot() == resumed.turn.snapshot()

	var purge: Dictionary = _setup(36, 100, null, true, _prepare_existing_purge_evidence)
	ok = purge.ok and _open(purge) and _close(purge)
	var plan: Dictionary = purge.world.state.domains["DOMAIN-001"].pending_plan.duplicate(true)
	var selected_actual_purge: bool = plan.get("rule") == "RESIST_PURGE" and plan.get("due") == 3
	ok = _open(purge) and _close(purge) and _do(purge, "advance") and ok
	captured = _cohort_fact(purge.world, "DOMAIN-001", 3)
	var cleanup: Dictionary = {}
	for fact: Dictionary in purge.world.state.facts.values():
		if fact.kind == "population_transfer" and fact.turn == 3 and fact.changes.get("rule") == "purge_cult":
			cleanup = fact
	var captured_before_purge: bool = captured.get("changes", {}).get("eligible") == 36 and captured.get("id", "missing") in cleanup.get("causal_parents", []) and cleanup.get("changes", {}).get("eligible_removed") == 8
	var after_purge: bool = purge.world.state.domains["DOMAIN-001"].unnamed_followers == 28 and purge.world.state.economy.eligible["DOMAIN-001"] == 28 and purge.world.state.cults["CULT-QA"].cohesion == 90
	income_before = purge.world.state.faith
	ok = _do(purge, "finish_events") and _close(purge) and ok
	var purge_income: int = int(purge.world.state.faith) - income_before
	var purge_valid: bool = ok and selected_actual_purge and captured_before_purge and after_purge and purge_income == 4
	_check("ECON-QA-017", "轮初先登记旧资格再执行到期迁移与正式清洗，续存不改变顺序", migration_valid and purge_valid,
		{"migration": {"cohort_record_precedes_transfer": captured_before_migration, "cohorts_correct": cohorts_correct, "expected_income": 8, "actual_income": migration_income, "saved_continuation_equal": original.turn.snapshot() == resumed.turn.snapshot(), "pass": migration_valid},
		"purge": {"real_plan_selected": selected_actual_purge, "cohort_record_precedes_purge": captured_before_purge, "loss8_and_cohesion90": after_purge, "expected_income": 4, "actual_income": purge_income, "pass": purge_valid},
		"scope": "迁移使用显式上游到期命令；清洗只预置已有确认知识，选择、预告和清洗均由正式文明规则执行"})

func _prepare_unavailable_cult(world: RefCounted, mode: String) -> bool:
	var leader: String = world.state.cults["CULT-QA"].leader
	var ok: bool = true
	if mode in ["detained", "missing"]:
		ok = world.submit({"kind": "status", "npc": leader, "status": mode, "parents": [_source(world)]})
	elif mode == "low_loyalty":
		world.state.npcs[leader].loyalty = 0
	elif mode == "dormant":
		world.state.cults["CULT-QA"].status = "dormant"
	elif mode == "no_leader":
		world.state.cults["CULT-QA"].leader = ""
		world.state.cults["CULT-QA"].status = "dormant"
		for npc: Dictionary in world.state.npcs.values():
			if npc.domain == "DOMAIN-001":
				npc.loyalty = 0
	var carrier: String = world.state.institutions["DOMAIN-001/propagation"].representative
	world.state.domains["DOMAIN-001"].alert = 10
	var anomaly: String = world.introduce_fact("public_anomaly", "DOMAIN-001", carrier, [carrier], [_source(world)], {}, [])
	return not anomaly.is_empty() and ok

func _test_unavailable_cult_operation() -> void:
	var passed: bool = true
	var cases: Array = []
	for mode: String in ["detained", "missing", "low_loyalty", "dormant", "no_leader"]:
		for strategy: String in ["expand", "conceal"]:
			var setup: Dictionary = _setup(100, 50, null, true, _prepare_unavailable_cult.bind(mode))
			var world: RefCounted = setup.world
			var population: int = world.state.domains["DOMAIN-001"].population
			var nonfollowers: int = world.state.domains["DOMAIN-001"].unnamed_nonfollowers
			var faith: int = world.state.faith
			var ok: bool = setup.ok and _open(setup)
			ok = _do(setup, "set_plan", {"participant": "economy", "payload": _plan(strategy)}) and _close(setup) and ok
			var held: bool = world.state.economy.effective.get("CULT-QA") == "hold" and world.state.cults["CULT-QA"].strategy == strategy and world.state.domains["DOMAIN-001"].alert == 10 and world.state.faith == faith
			var attrition: bool = world.state.domains["DOMAIN-001"].unnamed_followers == 99 and world.state.domains["DOMAIN-001"].unnamed_nonfollowers == nonfollowers + 1 and world.state.domains["DOMAIN-001"].population == population and world.state.economy.eligible.get("DOMAIN-001") == 99
			var income: Dictionary = {}
			if world.state.economy.income_sources.has("CULT-QA"):
				income = world.state.facts[world.state.economy.income_sources["CULT-QA"]].changes
			var valid: bool = ok and held and attrition and income.get("gross") == 0 and not str(income.get("reason", "")).is_empty()
			passed = passed and valid
			cases.append({"initial_condition": mode, "intent": strategy, "no_fee_growth_conceal_or_income": held, "one_actual_attrition": attrition, "income_reason": income.get("reason", ""), "pass": valid})
	_check("ECON-QA-018", "失能领袖和休眠组织保留意向但不经营不收入，自然流失照常", passed,
		{"cases": cases, "scope": "失能/休眠为开轮前既有状态；持续公开异象排除自然静默衰减，失去传播资格不得误收费"})

func _prepare_order_fixture(world: RefCounted, reversed: bool) -> bool:
	var ok: bool = _add_existing_cult(world, "CULT-QA-B", "DOMAIN-007", 36)
	ok = _add_anchor(world, "active", 20) and _prepare_expand_only(world) and ok
	var cult: Dictionary = world.state.cults["CULT-QA-B"]
	var source: String = cult.established_source
	world.state.domains[cult.domain].pollution = 20
	world.state.relics["RELIC-Z"] = {"id": "RELIC-Z", "domain": cult.domain, "holder": "", "placement": "bound", "anchor": "ANCHOR-Z"}
	world.state.anchors["ANCHOR-Z"] = {"id": "ANCHOR-Z", "domain": cult.domain, "institution": str(cult.domain) + "/order", "state": "active", "guardian": cult.leader, "relic": "RELIC-Z", "needs_rebind": false, "origin": source, "ordinal": 1, "cult": cult.id}
	for qualification: Dictionary in [{"rule": "anchor", "subject": "ANCHOR-Z", "institution": str(cult.domain) + "/order"}, {"rule": "propagation", "subject": cult.id, "institution": str(cult.domain) + "/propagation"}]:
		qualification.merge({"kind": "economy_qualification", "allowed": true, "issuer": "qa-upstream", "version": "1", "parents": [source]})
		ok = world.submit(qualification) and ok
	world._refresh_anchors()
	world.state.faith = 3
	if reversed:
		# Same state and causal facts, different insertion order only. This happens
		# before Turn ownership, not through a replacement runtime settlement.
		for collection: String in ["cults", "anchors", "domains", "npcs", "institutions"]:
			var reordered: Dictionary = {}
			var ids: Array = world.state[collection].keys()
			ids.reverse()
			for id: String in ids:
				reordered[id] = world.state[collection][id]
			world.state[collection] = reordered
	return ok

func _test_dictionary_order_independence() -> void:
	var original: Dictionary = _setup(36, 100, null, true, _prepare_order_fixture.bind(false))
	var reversed: Dictionary = _setup(36, 100, null, true, _prepare_order_fixture.bind(true))
	var initial_equal: bool = original.turn.snapshot() == reversed.turn.snapshot()
	var ok: bool = original.ok and reversed.ok and initial_equal
	for operation: String in ["advance", "finish_events", "set_plan", "end_actions", "advance", "advance", "advance"]:
		var extra: Dictionary = {"participant": "economy", "payload": {"strategies": {"CULT-QA": "expand", "CULT-QA-B": "expand"}, "anchor_priority": [], "refuse_anchors": []}} if operation == "set_plan" else {}
		var request: Dictionary = _request(original, operation, extra)
		var reverse_request: Dictionary = request.duplicate(true)
		if operation == "set_plan":
			reverse_request.payload.strategies = {"CULT-QA-B": "expand", "CULT-QA": "expand"}
		var first: Dictionary = original.turn.submit(request)
		var second: Dictionary = reversed.turn.submit(reverse_request)
		ok = first.get("ok", false) and second.get("ok", false) and World.canonical(first) == World.canonical(second) and ok
	var world: RefCounted = original.world
	var ordering: bool = world.state.economy.effective.get("CULT-QA") == "expand" and world.state.economy.effective.get("CULT-QA-B") == "hold" and world.state.anchors["ANCHOR-QA"].state == "active" and world.state.anchors["ANCHOR-Z"].state == "dormant" and world.state.domains["DOMAIN-001"].unnamed_followers > 36 and world.state.domains["DOMAIN-007"].unnamed_followers == 36
	var same: bool = original.turn.snapshot() == reversed.turn.snapshot()
	_check("ECON-QA-019", "稀缺资金下反转世界集合与计划插入顺序仍按稳定ID支付和演化", ok and ordering and same,
		{"initial_semantic_state_equal": initial_equal, "starting_faith": 3, "first_cult_paid_then_first_omitted_anchor": ordering, "same_receipts_and_whole_snapshot": same, "reordered_collections": ["cults", "anchors", "domains", "npcs", "institutions", "plan_strategies"]})
