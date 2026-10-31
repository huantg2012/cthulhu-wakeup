extends "res://tools/events/run.gd"
## Upstream schedule declarations and initial situations are explicit fixtures.
## Every clock, roll, branch, identity write, rollback and archive is production.

func run_event_lifecycle() -> void:
	for outcome: String in ["deep", "success", "failure", "disaster"]:
		_life_check_branch(outcome)
	_life_death_arbitration(false)
	_life_death_arbitration(true)
	_life_unselected_death()
	_life_rollback()
	_life_reopen(false)
	_life_reopen(true)
	_life_archive()
	_life_reopen_archive()

func _life_base(outcome: String = "success", initial_target_status: String = "") -> Dictionary:
	var data: Dictionary = _high()
	data.domain = "DOMAIN-001"; data.institution = data.domain + "/interpretation"
	data.actor = data.leader; data.target = data.guardians[data.domain][2]
	# Explicit initial check fixture, before any authoritative request receipt.
	data.world.mutable_npc(data.actor).adaptation = 5
	data.world.mutable_npc(data.actor).sanity = 80
	data.world.state.domains[data.domain].barrier = 25
	data.world.state.domains[data.domain].alert = 0
	var probability: int = data.world.check_probability(data.actor, "adaptation", data.domain, "occult")
	var desired: int = {"deep": 1, "success": 50, "failure": 85, "disaster": 100}[outcome]
	for value: int in range(1, 100000):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = value
		if rng.randi_range(1, 100) == desired:
			data.world.randoms.checks.seed = value; break
	if not initial_target_status.is_empty(): assert(data.world.submit({"kind": "status", "npc": data.target, "status": initial_target_status, "parents": [data.source]}))
	data.expected_probability = probability
	_attach_prayers(data)
	return data

func _life_check(data: Dictionary, branches: Dictionary) -> Dictionary:
	return {"type": "check", "source": data.source, "npc": data.actor, "domain": data.domain, "attribute": "adaptation", "mode": "occult", "preparation": 0, "branches": branches}

func _life_job(data: Dictionary, id: String, effects: Array) -> Dictionary:
	return {"type": "schedule", "job": {"id": id, "due": 2, "phase": "deadlines", "action": "fixture-selected-consequence", "source": data.source, "payload": {"effects": effects}}}

func _life_fee(data: Dictionary, amount: int) -> Dictionary:
	return {"type": "resource", "source": data.source, "field": "faith", "delta": amount}

func _life_to_due(data: Dictionary, jobs: Array) -> bool:
	data.fixture.gather = jobs
	if not _open(data) or not _evolve(data) or not _finish(data): return false
	data.fixture.gather = []
	return _open(data) and _evolve(data)

func _life_actual_check(data: Dictionary, job: String) -> Dictionary:
	var checks: Array = _facts(data.world, "turn_check").filter(func(f: Dictionary) -> bool: return f.changes.get("job") == job)
	return checks[0] if checks.size() == 1 else {}

func _life_check_branch(outcome: String) -> void:
	var data: Dictionary = _life_base(outcome)
	var target: String = data.target
	var migrate: Dictionary = {"type": "world_command", "source": data.source, "command": {"kind": "migrate", "npc": target, "domain": data.receiving, "parents": [data.source]}}
	var branches: Dictionary = {"deep": [_status(data, target, "missing")], "success": [migrate], "failure": [_status(data, target, "detained")], "disaster": [_status(data, target, "dead")]}
	var job: String = "LIFE/check/" + outcome
	var ready: bool = _life_to_due(data, [_life_job(data, job, [_life_check(data, branches)])])
	var result: Dictionary = _submit(data, "advance") if ready else {"ok": false}
	var checked: Dictionary = _life_actual_check(data, job)
	var person: Dictionary = Store.entry(data.world.state.npcs, target)
	var applied: bool = person.domain == data.receiving if outcome == "success" else person.status == {"deep": "missing", "failure": "detained", "disaster": "dead"}.get(outcome, "")
	var ids: Dictionary = {"deep": "001", "success": "002", "failure": "003", "disaster": "004"}
	_check("EVT-LIFE-" + ids[outcome], "正式到期检定真实四档身份分支 " + outcome, result.ok and not checked.is_empty() and checked.changes.outcome == outcome and applied and data.world.validate_state(data.world.state).is_empty(), {"result": result, "check": checked.get("changes", {}), "status": person.status, "domain": person.domain})

func _life_death_arbitration(same_job: bool) -> void:
	var data: Dictionary = _life_base()
	var death: Dictionary = _status(data, data.target, "dead")
	var restore: Dictionary = _status(data, data.target, "active")
	var branches: Dictionary = {}
	for outcome: String in ["deep", "success", "failure", "disaster"]: branches[outcome] = [death, restore] if same_job else [restore]
	var jobs: Array = [_life_job(data, "LIFE/arbitrated", [_life_fee(data, -2), _life_check(data, branches), _life_fee(data, 5)])]
	if not same_job: jobs.append(_life_job(data, "LIFE/death", [death]))
	var ready: bool = _life_to_due(data, jobs)
	var result: Dictionary = _submit(data, "advance") if ready else {"ok": false}
	var checked: Dictionary = _life_actual_check(data, "LIFE/arbitrated")
	var cancellations: Array = _facts(data.world, "turn_consequence_cancelled").filter(func(f: Dictionary) -> bool: return f.changes.get("job") == "LIFE/arbitrated")
	var fees: Array = _facts(data.world, "turn_resource").filter(func(f: Dictionary) -> bool: return f.turn == 2 and f.changes.get("participant") == "event-fixture" and f.changes.get("slot") == "deadlines")
	var deaths: Array = _facts(data.world, "status_change").filter(func(f: Dictionary) -> bool: return f.actor == data.target and f.changes.get("to") == "dead")
	var sourced: bool = not checked.is_empty() and cancellations.size() == 1 and checked.id in cancellations[0].causal_parents and deaths.size() == 1 and deaths[0].id in cancellations[0].causal_parents
	_check("EVT-LIFE-006" if same_job else "EVT-LIFE-005", "实际选中死亡优先、检查保留、整项非死亡费用/收益取消" + ("（同job）" if same_job else "（独立job）"), result.ok and sourced and fees.is_empty() and Store.entry(data.world.state.npcs, data.target).status == "dead" and data.world.validate_state(data.world.state).is_empty(), {"result": result, "checks": 0 if checked.is_empty() else 1, "cancelled": cancellations.size(), "deaths": deaths.size()})

func _life_unselected_death() -> void:
	var data: Dictionary = _life_base("success", "missing")
	var branches: Dictionary = {"deep": [_status(data, data.target, "dead")], "success": [_status(data, data.target, "active")], "failure": [], "disaster": []}
	var ready: bool = _life_to_due(data, [_life_job(data, "LIFE/nonfatal", [_life_check(data, branches), _life_fee(data, -2)])])
	var result: Dictionary = _submit(data, "advance") if ready else {"ok": false}
	var checked: Dictionary = _life_actual_check(data, "LIFE/nonfatal")
	var cancelled: bool = _facts(data.world, "turn_consequence_cancelled").any(func(f: Dictionary) -> bool: return f.changes.get("job") == "LIFE/nonfatal")
	_check("EVT-LIFE-007", "未选死亡分支不抢优先且实际非致死分支正常执行", result.ok and checked.get("changes", {}).get("outcome") == "success" and not cancelled and Store.entry(data.world.state.npcs, data.target).status == "active", {"result": result, "check": checked.get("changes", {})})

func _life_rollback() -> void:
	var data: Dictionary = _life_base()
	var branches: Dictionary = {}
	for outcome: String in ["deep", "success", "failure", "disaster"]: branches[outcome] = [_status(data, data.target, "missing"), _life_fee(data, -2)]
	var ready: bool = _life_to_due(data, [_life_job(data, "LIFE/rollback", [_life_check(data, branches)])])
	data.fixture.fault = true
	var before: String = data.turn.snapshot()
	var rejected: Dictionary = _submit(data, "advance") if ready else {"ok": true}
	var atomic: bool = not rejected.ok and data.turn.snapshot() == before
	data.fixture.fault = false
	var retried: Dictionary = _submit(data, "advance")
	_check("EVT-LIFE-008", "同批后续故障完整回滚检定RNG/身份/费用/完成键，重试仅发生一次", atomic and retried.ok and not _life_actual_check(data, "LIFE/rollback").is_empty() and Store.entry(data.world.state.npcs, data.target).status == "missing", {"rejected": rejected, "retried": retried, "atomic": atomic})

func _life_reopen_given(full: bool = false) -> Dictionary:
	var data: Dictionary = _high()
	data.domain = "DOMAIN-001"; data.institution = data.domain + "/interpretation"
	data.petitioner = data.guardians[data.domain][0]
	var relative: String = data.guardians[data.domain][1]
	data.subjects = {"petitioner": data.petitioner, "relative": relative}
	# Initial real dying condition deliberately outlives the request window.
	var harm: String = _given_fact(data, "harm", relative, [relative], {"fixture": "initial_dying_due_seven"})
	data.fact_map = {"condition": _given_fact(data, "dying_condition", data.petitioner, [relative], {"patient": relative, "due": 7}, [harm]), "relation": _given_relation(data, data.petitioner, relative, "family")}
	var descriptor: Dictionary = {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers.PRAYER_01.need, "domain": data.domain, "institution": data.institution, "actors": [data.petitioner, relative], "subjects": data.subjects, "facts": data.fact_map, "crisis": {"source": data.fact_map.condition, "due": 7}}
	data.situation = data.world.introduce_fact("prayer_situation", data.domain, data.petitioner, descriptor.actors, [data.fact_map.condition, data.fact_map.relation], descriptor, descriptor.actors)
	if full:
		# Three initial, distinct known anomalies are not fixed at bootstrap.
		# Production freeze in turn one fixes their windows for turns two–four.
		for index: int in 3:
			var record: String = _given_fact(data, "exposure", data.petitioner, [data.petitioner], {"public": false, "unexplained": true, "fixture": "initial_anomaly_" + str(index)})
			var offered: Dictionary = {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers.PRAYER_04.need, "domain": data.domain, "institution": data.institution, "actors": [data.petitioner], "subjects": {"petitioner": data.petitioner}, "facts": {"record": record}, "crisis": {}}
			assert(not data.world.introduce_fact("prayer_situation", data.domain, data.petitioner, [data.petitioner], [record], offered, [data.petitioner]).is_empty())
	data.world.attention.sync(data.world); data.world.history.rebuild(data.world.state)
	_choose_prayer_seed(data, "success", data.petitioner, data.domain)
	_attach_prayers(data)
	assert(data.world.fix_prayer_source(data.situation, data.turn))
	for id: String in data.world.state.simulation.candidates:
		if data.world.state.simulation.candidates[id].get("source") == data.situation: data.request = id
	return data

func _life_reopen(full: bool) -> void:
	var data: Dictionary = _life_reopen_given(full)
	var event: Dictionary = _event_wait(data, "EVENT_12", "B")
	if event.is_empty():
		_check("EVT-LIFE-010" if full else "EVT-LIFE-009", "真实窗口到期的EVENT12B重开", false, {"reason": "No real event"}); return
	var old: Dictionary = data.world.state.prayer_system.requests.get(data.request, {}).duplicate(true)
	var offered: Array = data.world.state.prayer_system.offered.duplicate()
	var result: Dictionary = _event_resolve(data, event.id, "B")
	var sources: Array = _facts(data.world, "prayer_situation").filter(func(f: Dictionary) -> bool: return f.changes.has("reopen"))
	var request: Dictionary = {}; var reopened: String = ""
	if result.ok and not sources.is_empty():
		var fixed: String = str(Store.entry(data.world.state.applied_authorizations, "prayer/source/" + sources[-1].id, ""))
		var card: Dictionary = Store.entry(data.world.state.facts, fixed, {}).get("changes", {}).get("candidate", {})
		reopened = str(card.get("id", "")); request = data.world.state.prayer_system.requests.get(reopened, {})
	var preserved: bool = not request.is_empty() and request.descriptor.subjects == data.subjects and request.descriptor.facts == data.fact_map and request.descriptor.crisis.source == data.fact_map.condition and request.descriptor.crisis.due == 7 and request.card.visible_turn == data.world.state.turn and not Store.has(data.world.state.invalid_records, data.fact_map.condition)
	var capacity: bool = data.world.state.prayer_system.offered == offered and offered.size() == 3 and not reopened in offered if full else reopened in data.world.state.prayer_system.offered
	var response: Dictionary = {"ok": true}
	if not full and result.ok:
		response = _submit(data, "finish_events")
		if response.ok: response = _response(data, reopened, "shallow")
	_check("EVT-LIFE-010" if full else "EVT-LIFE-009", "满三请求不挤旧且保留当轮可见候选" if full else "原危机同对象原due当轮重开并真实回应", result.ok and preserved and capacity and response.ok and data.world.validate_state(data.world.state).is_empty(), {"result": result, "new": reopened, "offered_before": offered, "preserved": preserved, "response": response, "old_status": old.get("status", ""), "world_error": data.world.last_error, "turn_error": data.turn.last_error})

func _life_archive() -> void:
	var data: Dictionary = _life_base()
	var branches: Dictionary = {}
	for outcome: String in ["deep", "success", "failure", "disaster"]: branches[outcome] = [_status(data, data.target, "missing")]
	var ready: bool = _life_to_due(data, [_life_job(data, "LIFE/archive", [_life_check(data, branches)])])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	var path: String = scratch.path_join("event-lifecycle")
	var saved: bool = ready and data.turn.save_archive(path)
	var first: Dictionary = _submit(data, "advance") if saved else {"ok": false}
	var expected: String = data.world.snapshot()
	var loaded: bool = data.turn.load_archive(path) if saved else false
	var second: Dictionary = _submit(data, "advance") if loaded else {"ok": false}
	_check("EVT-LIFE-011", "真实分页存档恢复待到期检查并保持相同RNG/身份/因果结果", saved and first.ok and loaded and second.ok and expected == data.world.snapshot() and not _life_actual_check(data, "LIFE/archive").is_empty(), {"saved": saved, "loaded": loaded, "first": first, "second": second})

func _life_reopen_archive() -> void:
	var data: Dictionary = _life_reopen_given()
	var event: Dictionary = _event_wait(data, "EVENT_12", "B")
	var result: Dictionary = _event_resolve(data, event.id, "B") if not event.is_empty() else {"ok": false}
	var serialized: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(serialized) if result.ok else false
	var duplicate: Dictionary = _event_resolve(data, event.id, "B") if result.ok else {"ok": true}
	var pure: bool = not duplicate.ok and data.turn.snapshot() == serialized
	var envelope: Dictionary = JSON.parse_string(serialized)
	var world: Dictionary = JSON.parse_string(envelope.body.world)
	var changed: bool = false
	for fact: Dictionary in world.body.state.facts.values():
		if fact.kind == "prayer_reopen_authorized" and fact.changes.get("issuer") == "events": fact.changes.version = "forged"; changed = true; break
	world.checksum = World.canonical(world.body).sha256_text(); envelope.body.world = World.canonical(world)
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var rejected: bool = changed and not data.turn.restore(World.canonical(envelope)) and data.turn.snapshot() == serialized
	_check("EVT-LIFE-012", "重开存档恢复、重复事件不可复用、重算checksum的伪造授权仍拒绝", restored and pure and rejected, {"event": result, "restored": restored, "duplicate": duplicate, "forged_rejected": rejected})
