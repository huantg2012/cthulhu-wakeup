extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const Qa = preload("res://tools/turn-cycle/qa_cases.gd")
var catalog: RefCounted
var checks: Array = []
var sequence: int = 0
var metrics: Dictionary = {}

class ContractParticipant extends RefCounted:
	# Explicit integration fixture: not authored prayer/economy/ending content.
	var mode: String
	func _init(scenario: String) -> void:
		mode = scenario
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var source: String = view.world.domains["DOMAIN-001"].origin
		var actor: String = view.world.institutions["DOMAIN-001/order"].representative
		var target: String = view.world.institutions["DOMAIN-001/interpretation"].representative
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": view.participant_state.duplicate(true)}
		var trace: Array = result.state.get("trace", [])
		trace.append(str(input.slot) + "/" + str(input.operation))
		result.state.trace = trace
		if input.slot == "events" and input.operation == "gather":
			result.events = []
			if mode in ["integration", "opportunity"]:
				result.events.append({"id": "EVENT-CONTRACT", "default_action": "accept", "source": source, "payload": {"actor": actor}})
		if input.operation in ["act", "resolve_event"]:
			result.meta = {"faith_cost": 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": source, "outcome": "success", "responds": false, "used_power": false, "used_relic": false}
			match input.action:
				"paid":
					result.meta.faith_cost = 2
					result.meta.whispers_cost = 1
					result.meta.outcome = "failure" # Valid gameplay failure still consumes costs.
				"execute":
					result.meta.actor = actor
					result.meta.used_power = true
				"respond":
					result.meta.responds = true
				"kill_guardian":
					result.effects = [{"type": "world_command", "source": source, "command": {"kind": "status", "npc": target, "status": "dead", "parents": [source]}}]
				"high_power":
					result.meta.min_awakening = 30
				"schedule":
					result.effects = [{"type": "schedule", "job": {"id": "DUE-CONTRACT", "due": view.turn.turn + 1, "phase": "start", "source": source, "action": "kill", "payload": {"npc": target}}}]
				"urgent":
					result.effects = [{"type": "schedule", "job": {"id": "URGENT-CONTRACT", "due": view.turn.turn, "phase": "deadlines", "source": source, "action": "kill", "payload": {"npc": target}}}]
				"conflict":
					for job_id: String in ["A", "Z"]:
						var restore_first: bool = mode == "restore_first"
						var action: String = "restore" if (job_id == "A") == restore_first else "kill"
						result.effects.append({"type": "schedule", "job": {"id": job_id, "due": view.turn.turn + 1, "phase": "start", "source": source, "action": action, "payload": {"npc": target}}})
				"roll":
					result.meta.faith_cost = 1
					var branch: Array = [{"type": "wounds", "source": source, "delta": 1}]
					result.effects = [{"type": "check", "source": source, "npc": actor, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": branch, "success": branch, "failure": branch, "disaster": branch}}]
				"bad_roll":
					result.meta.faith_cost = 1
					result.effects = [{"type": "check", "source": source, "npc": actor, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": [{"type": "unknown"}], "success": [], "failure": [], "disaster": []}}]
				"event_response":
					result.meta.responds = true
				"accept":
					if mode == "integration":
						var strained: String = view.world.institutions["DOMAIN-002/order"].representative
						result.effects = [{"type": "fact", "source": source, "parents": [view.world.domains["DOMAIN-002"].origin], "kind": "strain", "domain": "DOMAIN-002", "actor": strained, "targets": [strained], "observers": [strained], "institutions": [], "details": {"origin": "explicit_event_contract"}}]
				_:
					result.ok = false
		if input.slot == "prepay" and mode == "integration":
			result.effects = [{"type": "resource", "source": source, "field": "faith", "delta": -2}]
		if input.slot == "income" and mode == "integration":
			result.effects = [{"type": "resource", "source": source, "field": "faith", "delta": 6, "basis": {"cult": "CULT-CONTRACT", "eligible": 81, "rule": "verification-basis-only"}}]
		if input.slot == "deadlines" and mode == "integration":
			result.effects = [{"type": "world_command", "source": source, "command": {"kind": "status", "npc": target, "status": "dead", "parents": [source]}}]
		if input.slot in ["start", "deadlines"] and input.operation == "due":
			result.effects = [{"type": "world_command", "source": input.source, "command": {"kind": "status", "npc": input.payload.npc, "status": "active" if input.action == "restore" else "dead", "parents": [input.source]}}]
			if input.action == "restore":
				result.effects.push_front({"type": "resource", "source": input.source, "field": "faith", "delta": -1})
			if mode in ["mixed_branch", "mixed_direct"]:
				var branch: Array = result.effects.duplicate(true) if mode == "mixed_branch" else []
				var rolled: Dictionary = {"type": "check", "source": input.source, "npc": actor, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": branch, "success": branch, "failure": branch, "disaster": branch}}
				result.effects = [rolled] if mode == "mixed_branch" else [rolled] + result.effects
		if input.slot == "deadlines" and input.operation == "settle" and mode == "recursive":
			result.effects = [{"type": "schedule", "job": {"id": "ILLEGAL-RECURSION", "due": view.turn.turn, "phase": "deadlines", "source": source, "action": "kill", "payload": {"npc": target}}}]
		if input.slot == "events" and input.operation == "gather" and mode == "active" and (int(view.turn.turn) - 1) % 6 == 0:
			for domain: Dictionary in view.world.domains.values():
				var carrier: String = view.world.institutions[domain.id + "/propagation"].representative
				var witness: String = view.world.institutions[domain.id + "/order"].representative
				if view.world.npcs.has(carrier) and view.world.npcs[carrier].status == "active" and view.world.npcs.has(witness) and view.world.npcs[witness].status == "active":
					result.effects.append({"type": "fact", "source": domain.origin, "kind": "miracle", "domain": domain.id, "actor": carrier, "targets": [carrier], "observers": [carrier], "institutions": [], "details": {"witnesses": [carrier], "public": true}})
					result.effects.append({"type": "fact", "source": domain.origin, "kind": "exposure", "domain": domain.id, "actor": carrier, "targets": [carrier], "observers": [witness], "institutions": [domain.id + "/order"], "details": {"public": true}})
		if input.slot == "ending":
			result.state.ending_read_awakening = view.world.awakening
			if int(view.world.awakening) == 0:
				result.effects = [{"type": "end", "source": source, "outcome": "extinction"}]
		if input.slot == "prepay" and mode == "atomic":
			var plan: Dictionary = view.turn.locked_plans.get("contract", {})
			if plan.get("fail", false):
				result.effects = [{"type": "resource", "source": source, "field": "faith", "delta": -1}, {"type": "world_command", "source": source, "command": {"kind": "status", "npc": actor, "status": "active", "parents": [source]}}]
		result.empty = result.effects.is_empty()
		return result

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files():
		_check("TURN-000", "Formal catalog", false, {"errors": catalog.errors})
		_finish()
		return
	_integration()
	_budget()
	_opportunities()
	_atomic()
	_check_replay()
	_due_start()
	_zero()
	_lifetime()
	_urgent()
	_due_identity_conflict()
	_no_recursive_deadlines()
	_no_probabilistic_due_identity()
	checks.append_array(Qa.new().run(catalog))
	_measure_turns()
	_finish()

func _check(id: String, name: String, valid: bool, detail: Dictionary = {}) -> void:
	checks.append({"id": id, "name": name, "status": "pass" if valid else "fail", "details": detail})
	print(("PASS " if valid else "FAIL ") + id + " " + name)

func _world() -> RefCounted:
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	return world

func _attach(world: RefCounted, mode: String = "empty") -> RefCounted:
	var turn: RefCounted = Turn.new(world)
	var fixture: RefCounted = ContractParticipant.new(mode)
	assert(turn.register_participant("contract", "fixture-" + mode, Turn.SLOTS, Turn.EFFECTS, fixture.handle))
	return turn

func _request(turn: RefCounted, op: String, extra: Dictionary = {}) -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "RUN-%d" % sequence, "op": op, "turn": turn.context.turn, "phase": turn.context.phase}
	request.merge(extra)
	return request

func _do(turn: RefCounted, op: String, extra: Dictionary = {}) -> bool:
	var result: Dictionary = turn.submit(_request(turn, op, extra))
	if not result.ok:
		print("  REJECT ", result.error)
	return result.ok

func _action(turn: RefCounted, action: String) -> bool:
	return _do(turn, "act", {"participant": "contract", "action": action, "payload": {}})

func _open(turn: RefCounted) -> bool:
	return _do(turn, "advance") and _do(turn, "finish_events")

func _close(turn: RefCounted) -> bool:
	return _do(turn, "end_actions") and _do(turn, "advance") and _do(turn, "advance") and _do(turn, "advance")

func _anchor(world: RefCounted) -> String:
	var person: String = world.state.institutions["DOMAIN-001/interpretation"].representative
	world.state.relics["RELIC-CONTRACT"] = {"id": "RELIC-CONTRACT", "domain": "DOMAIN-001", "placement": "bound", "holder": "", "anchor": "ANCHOR-CONTRACT"}
	world.state.anchors["ANCHOR-CONTRACT"] = {"id": "ANCHOR-CONTRACT", "domain": "DOMAIN-001", "institution": "DOMAIN-001/interpretation", "guardian": person, "relic": "RELIC-CONTRACT", "state": "active", "needs_rebind": false}
	world._refresh_anchors()
	return person

func _integration() -> void:
	var world: RefCounted = _world()
	_anchor(world)
	world.state.wounds = 10
	world._refresh_anchors()
	var source: String = world.state.domains["DOMAIN-001"].origin
	var person: String = world.state.institutions["DOMAIN-002/order"].representative
	world.state.npcs[person].sanity = 20
	world.state.cults["CULT-CONTRACT"] = {"id": "CULT-CONTRACT", "domain": "DOMAIN-001", "leader": world.state.institutions["DOMAIN-001/order"].representative, "status": "active", "cohesion": 80, "succession_source": source}
	var before_barrier: int = world.state.domains["DOMAIN-002"].barrier
	var turn: RefCounted = _attach(world, "integration")
	var valid: bool = _open(turn) and _action(turn, "paid") and _do(turn, "end_actions") and _do(turn, "advance")
	var paid_before_income: int = world.state.faith
	var real_updates: int = world.stats.npc_updates
	var real_actions: int = world.stats.actions
	var event_cause: bool = false
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "npc_behavior" and fact.actor == person:
			for parent: String in fact.causal_parents:
				event_cause = event_cause or world.state.facts[parent].changes.get("origin") == "explicit_event_contract"
	valid = valid and _do(turn, "advance")
	var post_deadline: int = world.state.awakening
	valid = valid and _do(turn, "advance")
	valid = valid and paid_before_income == catalog.integer("initial_faith") - 4 and world.state.faith == paid_before_income + 6 and real_updates == 72 and real_actions > 0
	valid = valid and int(world.state.npcs[person].sanity) > 20 and int(world.state.domains["DOMAIN-002"].barrier) > before_barrier and event_cause
	valid = valid and post_deadline == 0 and turn.context.outcome == "extinction" and turn.context.participant_state.contract.ending_read_awakening == 0 and turn.context.journal.size() == 6
	var ended: String = turn.snapshot()
	valid = valid and not turn.submit(_request(turn, "advance")).ok and turn.snapshot() == ended
	_check("TURN-001", "六阶段真实接合：预付、正式NPC/文明、收入、到期失锚再终局", valid, {"paid_before_income": paid_before_income, "npc_updates": real_updates, "npc_actions": real_actions, "post_deadline_awakening": post_deadline, "adapter_scope": "事件/经济/期限/终局为合约验证参与器，NPC与文明为正式核心", "phase_trace": turn.context.journal})

func _budget() -> void:
	var world: RefCounted = _world()
	_anchor(world)
	world.state.insight = 20
	world._refresh_anchors()
	var turn: RefCounted = _attach(world)
	var valid: bool = _open(turn)
	var initial: int = world.state.whispers
	valid = valid and _action(turn, "kill_guardian")
	var after: int = world.state.whispers
	_check("TURN-002", "当前苏醒改变不会重发或回收本轮低语", valid and initial == after and turn.context.whispers_budget == initial, {"initial_budget": initial, "after_loss": after, "awakening": world.state.awakening})
	world = _world()
	_anchor(world)
	world.state.insight = 19
	world._refresh_anchors()
	turn = _attach(world)
	valid = _open(turn) and _action(turn, "kill_guardian")
	var no_high: bool = not _action(turn, "high_power")
	valid = valid and world.state.whispers == 4 and world.state.awakening == 29 and no_high and _close(turn) and _do(turn, "advance") and world.state.whispers == 3
	_check("TURN-003", "失锚即时撤销高阶资格，下轮才按新进度刷新预算", valid)

func _opportunities() -> void:
	var world: RefCounted = _world()
	var actor: String = world.state.institutions["DOMAIN-001/order"].representative
	world.state.npcs[actor].sanity = 20
	world.introduce_fact("strain", "DOMAIN-001", actor, [actor], [world.state.domains["DOMAIN-001"].origin], {}, [actor])
	var turn: RefCounted = _attach(world, "opportunity")
	var valid: bool = _do(turn, "advance")
	var before: String = turn.snapshot()
	valid = valid and not turn.submit(_request(turn, "resolve_event", {"event": "EVENT-CONTRACT", "action": "event_response"})).ok and turn.snapshot() == before
	valid = valid and _do(turn, "resolve_event", {"event": "EVENT-CONTRACT", "action": "execute"}) and _do(turn, "finish_events")
	valid = valid and not _action(turn, "execute") and _action(turn, "respond") and not _action(turn, "respond")
	valid = valid and _close(turn) and world.state.npcs[actor].sanity == 20
	valid = valid and _open(turn) and _action(turn, "execute")
	_check("TURN-004", "事件与行动共享人物机会，回应独立且下一轮重置", valid)

func _atomic() -> void:
	var world: RefCounted = _world()
	var turn: RefCounted = _attach(world, "atomic")
	var valid: bool = _open(turn) and _action(turn, "paid")
	valid = valid and _do(turn, "set_plan", {"participant": "contract", "payload": {"fail": true}}) and _do(turn, "end_actions")
	var before: String = turn.snapshot()
	var request: Dictionary = _request(turn, "advance")
	valid = valid and not turn.submit(request).ok and turn.snapshot() == before and world.state.faith == 16
	valid = valid and not turn.submit(request).ok and turn.snapshot() == before
	valid = valid and not _do(turn, "set_plan", {"participant": "contract", "payload": {"fail": false}})
	_check("TURN-005", "阶段四预付后真实效果失败整阶段回滚，已提交行动保留", valid)

func _check_replay() -> void:
	var world: RefCounted = _world()
	var turn: RefCounted = _attach(world)
	var valid: bool = _open(turn)
	var before: String = turn.snapshot()
	valid = valid and not _action(turn, "bad_roll") and turn.snapshot() == before
	var request: Dictionary = _request(turn, "act", {"participant": "contract", "action": "roll", "payload": {}})
	var result: Dictionary = turn.submit(request)
	var after: String = turn.snapshot()
	valid = valid and result.ok and not result.result.checks.is_empty() and World.canonical(turn.submit(request)) == World.canonical(result) and turn.snapshot() == after
	var resumed_world: RefCounted = _world()
	var resumed: RefCounted = _attach(resumed_world)
	valid = valid and resumed.restore(after) and World.canonical(resumed.submit(request)) == World.canonical(result) and resumed.snapshot() == after
	var check_cause: bool = false
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "turn_wounds":
			for parent: String in fact.causal_parents:
				check_cause = check_cause or world.state.facts[parent].kind == "turn_check"
	_check("TURN-006", "完整四档声明先校验；合法检定保留成本、真因与读档幂等回执", valid and check_cause)

func _due_start() -> void:
	var world: RefCounted = _world()
	var target: String = _anchor(world)
	world.state.insight = 19
	world._refresh_anchors()
	var turn: RefCounted = _attach(world)
	var valid: bool = _open(turn) and _action(turn, "schedule") and _close(turn)
	var before: String = turn.snapshot()
	var resumed: RefCounted = _attach(_world())
	valid = valid and resumed.restore(before)
	var request: Dictionary = _request(turn, "advance")
	valid = valid and turn.submit(request).ok and resumed.submit(request).ok and turn.snapshot() == resumed.snapshot()
	valid = valid and world.state.npcs[target].status == "dead" and world.state.whispers == 3 and turn.context.completed_jobs.has("DUE-CONTRACT")
	_check("TURN-007", "轮初到期身份先于绑定与预算刷新，待决队列保存续跑", valid)

func _zero() -> void:
	var world: RefCounted = _world()
	world.state.faith = 0
	var turn: RefCounted = _attach(world)
	var valid: bool = _open(turn) and _close(turn)
	valid = valid and world.state.faith == 0 and world.stats.npc_updates == 72 and turn.context.phase == "between"
	_check("TURN-008", "合法零事件零资源回合照常推进正式世界，不伪造事件", valid, {"scope": "空集合由明确注册验证参与器声明，未注册能力不视为空集合"})

func _lifetime() -> void:
	var world: RefCounted = _world()
	var turn: RefCounted = _attach(world)
	var weak: WeakRef = weakref(turn)
	var valid: bool = _open(turn) and _close(turn)
	turn = null
	valid = valid and weak.get_ref() == null and world.begin_turn()
	_check("TURN-009", "协调器保留参与者生命周期，释放会话不留下World引用环", valid)

func _urgent() -> void:
	var world: RefCounted = _world()
	var target: String = _anchor(world)
	var turn: RefCounted = _attach(world)
	var valid: bool = _open(turn) and _action(turn, "urgent") and _do(turn, "end_actions") and _do(turn, "advance")
	var saved: String = turn.snapshot()
	var resumed: RefCounted = _attach(_world())
	valid = valid and resumed.restore(saved)
	var request: Dictionary = _request(turn, "advance")
	valid = valid and turn.submit(request).ok and resumed.submit(request).ok and turn.snapshot() == resumed.snapshot() and world.state.npcs[target].status == "dead" and turn.context.completed_jobs.has("URGENT-CONTRACT")
	_check("TURN-011", "行动中登记寿命一轮的期限可本轮阶段五结算并保存恢复", valid)

func _due_identity_conflict() -> void:
	var valid: bool = true
	var cases: Array = []
	for mode: String in ["restore_first", "death_first"]:
		var world: RefCounted = _world()
		var target: String = world.state.institutions["DOMAIN-001/interpretation"].representative
		var origin: String = world.state.domains["DOMAIN-001"].origin
		world.submit({"kind": "status", "npc": target, "status": "missing", "parents": [origin]})
		var population: int = world.state.domains["DOMAIN-001"].population
		var turn: RefCounted = _attach(world, mode)
		var ok: bool = _open(turn) and _action(turn, "conflict") and _close(turn) and _do(turn, "advance")
		var cancelled: int = 0
		var causal: bool = false
		for fact: Dictionary in world.state.facts.values():
			if fact.kind == "turn_consequence_cancelled" and fact.changes.reason == "target_dead":
				cancelled += 1
				causal = world.state.npcs[target].status_source in fact.causal_parents
		ok = ok and world.state.npcs[target].status == "dead" and world.state.domains["DOMAIN-001"].population == population - 1 and world.state.faith == catalog.integer("initial_faith") and turn.context.completed_jobs.size() == 2 and cancelled == 1 and causal
		cases.append({"job_id_order": mode, "death_wins": ok, "cancelled": cancelled, "consumed": turn.context.completed_jobs.size(), "faith_after_cancelled_restore": world.state.faith})
		valid = valid and ok
	_check("TURN-012", "同批死亡压过普通恢复，调换期限ID一致且整项费用效果取消", valid, {"cases": cases})

func _no_recursive_deadlines() -> void:
	var turn: RefCounted = _attach(_world(), "recursive")
	var valid: bool = _open(turn) and _do(turn, "end_actions") and _do(turn, "advance")
	var saved: String = turn.snapshot()
	valid = valid and not _do(turn, "advance") and turn.snapshot() == saved and turn.world.stats.npc_updates == 72
	_check("TURN-013", "阶段五内新增同轮期限拒绝且不递归消费，阶段四保持完成", valid)

func _no_probabilistic_due_identity() -> void:
	var valid: bool = true
	var cases: Array = []
	for mode: String in ["mixed_branch", "mixed_direct"]:
		var turn: RefCounted = _attach(_world(), mode)
		var opened: bool = _open(turn) and _action(turn, "schedule") and _close(turn)
		var before: String = turn.snapshot()
		var rejected: bool = not _do(turn, "advance") and turn.snapshot() == before
		valid = valid and opened and rejected
		cases.append({"declaration": mode, "rejected_before_rng": rejected})
	_check("TURN-014", "当前到期身份能力明确拒绝混合检定，含分支身份且不消耗随机流", valid, {"cases": cases})

func _measure_turns() -> void:
	var world: RefCounted = _world()
	for domain: Dictionary in world.state.domains.values():
		var carrier: String = world.state.institutions[domain.id + "/propagation"].representative
		world.introduce_fact("public_anomaly", domain.id, carrier, [carrier], [domain.origin], {}, [carrier])
		domain.alert = catalog.integer("alert_investigation")
	var turn: RefCounted = _attach(world, "active")
	var durations: Array = []
	var stages: Dictionary = {"1": [], "2": [], "3": [], "4": [], "5": [], "6": []}
	var history: Array = []
	var previous_actions: int = 0
	var valid: bool = true
	for index: int in 50:
		var start: int = Time.get_ticks_usec()
		var operations: Array = ["advance", "finish_events", "end_actions", "advance", "advance", "advance"]
		for stage: int in 6:
			var stage_start: int = Time.get_ticks_usec()
			valid = _do(turn, operations[stage]) and valid
			stages[str(stage + 1)].append(float(Time.get_ticks_usec() - stage_start) / 1000.0)
		durations.append(float(Time.get_ticks_usec() - start) / 1000.0)
		if (index + 1) % 10 == 0:
			history.append({"turn": index + 1, "facts": world.state.facts.size(), "actions_in_10_turns": int(world.stats.actions) - previous_actions, "last_turn_ms": durations.back()})
			previous_actions = world.stats.actions
			print("  MEASURE ", index + 1, "/50 ", durations.back(), " ms")
		if not valid:
			break
	var save_start: int = Time.get_ticks_usec()
	var saved: String = turn.snapshot()
	var save_ms: float = float(Time.get_ticks_usec() - save_start) / 1000.0
	var stage_metrics: Dictionary = {}
	for stage: String in stages:
		stage_metrics[stage] = _distribution(stages[stage])
	metrics = {"turns": world.state.turn, "seed": 7919, "domains": world.state.domains.size(), "named_people": world.state.npcs.size(), "npc_updates": world.stats.npc_updates, "npc_actions": world.stats.actions, "plans_resolved": world.stats.plans_resolved, "complete_turn_ms": _distribution(durations), "stage_ms": stage_metrics, "history": history, "save_bytes": saved.to_utf8_buffer().size(), "save_ms": save_ms, "driver": "正式12域72人，持续公开异常起点；每6轮通过显式验证参与者传播神迹及暴露，不含正式随机事件抽样与经济。每轮经6次公开事务提交，计时含序列化和校验。", "threshold": "没有人为性能通过阈值；pass仅表示50轮真实活动及阶段均成功"}
	_check("TURN-010", "正式规模完整回合有限成本实测，公开历史增长与分阶段耗时", valid and world.state.turn == 50 and world.stats.npc_updates == 3600 and int(world.stats.actions) > 0 and not history.is_empty() and int(history.back().actions_in_10_turns) > 0, metrics)

func _distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted: Array = values.duplicate()
	sorted.sort()
	return {"p50": sorted[int(floor(sorted.size() * 0.5))], "p95": sorted[int(floor(sorted.size() * 0.95))], "max": sorted.back()}

func _finish() -> void:
	var passed: int = 0
	for check: Dictionary in checks:
		if check.status == "pass":
			passed += 1
		if str(check.id).begins_with("TURN-QA"):
			print(("PASS " if check.status == "pass" else "FAIL ") + check.id + " " + check.name)
	checks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var report: Dictionary = {"schemaVersion": 1, "suite": "turn-cycle", "generatedAt": Time.get_datetime_string_from_system(true) + "Z", "status": "pass" if passed == checks.size() else "fail", "checks": checks, "metrics": metrics, "sourceHashes": {}, "environment": {"engine": Engine.get_version_info().string, "platform": OS.get_name(), "headless": true}, "scope": ["持久六阶段编排与正式NPC/文明核心", "阶段事务、请求幂等、预算与执行机会", "显式参与能力、队列与阶段存档"], "limitations": ["本套事件、权能、经济、锚点维护及终局使用合约验证参与器；生产经济另由tools/economy验证，本套不替代其证据", "验证参与器产生真实支付、收入、身份后果与结束；生产参与器仍归后续任务", "尚无正式随机事件抽样能力，后续TASK-EVENTS须接入受管理events随机流", "到期身份工作仅支持确定性仲裁；身份效果与检定混合（包括分支内身份）、同项死亡与普通身份恢复混合明确拒绝，后续概率身份冲突需扩展能力合同", "无游戏内界面、真人体验、长期平衡或跨平台证据", "成本为单机无渲染50轮有限实测，不含存档迁移；未新增短体验前置阶段"]}
	var file: FileAccess = FileAccess.open("res://docs/qa/turn-cycle-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	print("TURN RESULT ", passed, "/", checks.size())
	quit(0 if passed == checks.size() else 1)
