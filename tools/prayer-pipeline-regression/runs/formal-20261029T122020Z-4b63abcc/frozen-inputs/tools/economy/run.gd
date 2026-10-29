extends SceneTree
const Store = preload("res://src/simulation/archive_store.gd")
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const Economy = preload("res://src/game/economy.gd")
const Qa = preload("res://tools/economy/qa_cases.gd")
var catalog: RefCounted
var checks: Array = []
var sequence: int = 0
var metrics: Dictionary = {}

class Upstream extends RefCounted:
	var fault: bool = false
	var active_load: bool = false
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var origin: String = view.world.domains["DOMAIN-001"].origin
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
		if input.slot == "events" and input.operation == "gather":
			result["events"] = []
			if active_load and (int(view.turn.turn) - 1) % 6 == 0:
				for domain: Dictionary in view.world.domains.values():
					var actor: String = view.world.institutions[domain.id + "/propagation"].representative
					var observer: String = view.world.institutions[domain.id + "/order"].representative
					if Store.has(view.world.npcs, actor) and Store.entry(view.world.npcs, actor).status == "active" and Store.has(view.world.npcs, observer) and Store.entry(view.world.npcs, observer).status == "active":
						result.effects.append({"type": "fact", "source": domain.origin, "kind": "miracle", "domain": domain.id, "actor": actor, "targets": [actor], "observers": [actor], "institutions": [], "details": {"witnesses": [actor], "public": true}})
						result.effects.append({"type": "fact", "source": domain.origin, "kind": "exposure", "domain": domain.id, "actor": actor, "targets": [actor], "observers": [observer], "institutions": [domain.id + "/order"], "details": {"public": true}})
		if input.slot == "actions":
			result["meta"] = {"faith_cost": 1 if input.action == "paid" else 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": origin, "outcome": "authorized_test_boundary", "responds": false, "used_power": false, "used_relic": false}
			if input.action == "command":
				result.effects.append({"type": "world_command", "source": origin, "command": input.payload.command})
		if input.slot == "deadlines" and fault:
			var actor: String = view.world.institutions["DOMAIN-001/order"].representative
			result.effects.append({"type": "world_command", "source": origin, "command": {"kind": "status", "npc": actor, "status": "active", "parents": [origin]}})
		result.empty = result.effects.is_empty()
		return result

class BrokenBatch extends Economy:
	var fault: bool = true
	func build_batch(state: Dictionary, index: RefCounted = null) -> Dictionary:
		var batch: Dictionary = super.build_batch(state, index)
		if fault and not batch.entries.is_empty():
			batch.entries[0].growth = int(state.domains[batch.entries[0].domain].unnamed_nonfollowers) + 1
		return batch

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files():
		_check("ECON-000", "正式目录可装载", false, {"errors": catalog.errors})
		_finish()
		return
	_strategies()
	_payment_order()
	_capabilities_and_growth()
	_anchor_activation_and_capacity()
	_rebuild_window()
	_transaction_failures()
	_stage_four_save()
	checks.append_array(Qa.new().run(catalog))
	_measure()
	_finish()

func _check(id: String, name: String, ok: bool, details: Dictionary = {}) -> void:
	checks.append({"id": id, "name": name, "status": "pass" if ok else "fail", "details": details})
	print(("PASS " if ok else "FAIL ") + id + " " + name)

func _base(broken: bool = false) -> Dictionary:
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	var economy: RefCounted = BrokenBatch.new(catalog, {"fixture-upstream": "1"}) if broken else Economy.new(catalog, {"fixture-upstream": "1"})
	assert(economy.initialize(world))
	return {"world": world, "economy": economy}

func _cult(data: Dictionary, domain: String = "DOMAIN-001", amount: int = 81, cohesion: int = 80) -> String:
	var world: RefCounted = data.world
	var id: String = "CULT-" + domain
	var leader: String = world.state.institutions[domain + "/propagation"].representative
	Store.entry(world.state.npcs, leader).loyalty = 100 # Explicit existing follower precondition.
	var origin: String = world.state.domains[domain].origin
	if amount > 0:
		assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": amount, "parents": [origin]}))
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [origin], {"issuer": "fixture-upstream", "version": "1", "cult": id, "domain": domain, "leader": leader, "cohesion": cohesion}, [])
	assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
	assert(world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": id, "institution": domain + "/propagation", "allowed": true, "issuer": "fixture-upstream", "version": "1", "parents": [authorization]}))
	return id

func _anchor(data: Dictionary, cult_id: String, dormant: bool = false) -> String:
	var world: RefCounted = data.world
	var cult: Dictionary = world.state.cults[cult_id]
	var id: String = "ANCHOR-" + cult.domain
	var relic: String = "RELIC-" + cult.domain
	world.state.domains[cult.domain].pollution = 50
	Store.put(world.state.relics, relic, {"id": relic, "domain": cult.domain, "placement": "bound", "holder": "", "anchor": id})
	world.state.anchors[id] = {"id": id, "domain": cult.domain, "institution": cult.domain + "/interpretation", "guardian": cult.leader, "relic": relic, "state": "dormant" if dormant else "active", "needs_rebind": false, "origin": cult.established_source, "ordinal": 1, "cult": cult_id}
	assert(world.submit({"kind": "economy_qualification", "rule": "anchor", "subject": id, "institution": cult.domain + "/interpretation", "allowed": true, "issuer": "fixture-upstream", "version": "1", "parents": [cult.established_source]}))
	world._refresh_anchors()
	return id

func _attach(data: Dictionary, upstream: RefCounted = null) -> Dictionary:
	var turn: RefCounted = Turn.new(data.world)
	assert(data.economy.install(turn))
	var adapter: RefCounted = Upstream.new() if upstream == null else upstream
	assert(turn.register_participant("fixture-upstream", "1", ["events", "actions", "deadlines", "ending", "start"], ["world_command", "fact", "schedule"], adapter.handle))
	data["turn"] = turn
	data["upstream"] = adapter
	return data

func _request(data: Dictionary, operation: String, extra: Dictionary = {}) -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "ECON-RUN-%d" % sequence, "turn": data.turn.context.turn, "phase": data.turn.context.phase, "op": operation}
	request.merge(extra)
	return request

func _do(data: Dictionary, operation: String, extra: Dictionary = {}) -> bool:
	var result: Dictionary = data.turn.submit(_request(data, operation, extra))
	if not result.ok:
		print("  REJECT ", result.error)
	return result.ok

func _open(data: Dictionary) -> bool:
	return _do(data, "advance") and _do(data, "finish_events")

func _close(data: Dictionary) -> bool:
	return _do(data, "end_actions") and _do(data, "advance") and _do(data, "advance") and _do(data, "advance")

func _plan(data: Dictionary, strategies: Dictionary, order: Array = [], refused: Array = []) -> bool:
	return _do(data, "set_plan", {"participant": "economy", "payload": {"strategies": strategies, "anchor_priority": order, "refuse_anchors": refused}})

func _command(data: Dictionary, command: Dictionary) -> bool:
	return _do(data, "act", {"participant": "fixture-upstream", "action": "command", "payload": {"command": command}})

func _strategies() -> void:
	var valid: bool = true
	var cases: Array = []
	for strategy: String in ["expand", "conceal", "hold"]:
		var data: Dictionary = _base()
		var cult: String = _cult(data)
		data.world.state.domains["DOMAIN-001"].alert = 20
		_attach(data)
		var before: int = data.world.state.faith
		var expected_growth: int = catalog.integer("expansion_base_growth") + int(Store.entry(data.world.state.npcs, data.world.state.cults[cult].leader).influence) / catalog.integer("expansion_influence_divisor")
		var ok: bool = _open(data) and _plan(data, {cult: strategy}) and _close(data)
		var fact: Dictionary = Store.entry(data.world.state.facts, data.world.state.economy.income_sources[cult])
		var expected_income: int = 3 if strategy == "conceal" else 6
		var expected_alert: int = 20 + catalog.integer("expansion_alert") if strategy == "expand" else 20 - catalog.integer("alert_quiet_decay") + (catalog.integer("conceal_alert") if strategy == "conceal" else 0)
		ok = ok and fact.changes.gross == expected_income and data.world.state.faith == before + expected_income - (catalog.integer("expansion_faith_cost") if strategy == "expand" else 0)
		ok = ok and data.world.state.domains["DOMAIN-001"].unnamed_followers == 81 + (expected_growth if strategy == "expand" else 0) and data.world.state.economy.eligible["DOMAIN-001"] == 81 and data.world.state.domains["DOMAIN-001"].alert == expected_alert and data.world.stats.npc_updates == 72
		ok = ok and data.world.state.economy.remainders[cult] == 81 * int(round(catalog.number("cult_natural_attrition") * Economy.RATE_SCALE)) * 20
		cases.append({"strategy": strategy, "faith": data.world.state.faith, "followers": data.world.state.domains["DOMAIN-001"].unnamed_followers, "eligible": data.world.state.economy.eligible["DOMAIN-001"], "alert": data.world.state.domains["DOMAIN-001"].alert, "gross_income": fact.changes.gross})
		valid = valid and ok
	_check("ECON-001", "三种正式策略产生真实支付招募察觉收入且不让新人当轮供奉", valid, {"cases": cases})

func _payment_order() -> void:
	var valid: bool = true
	var cases: Array = []
	for first: String in ["planet", "system", "refuse"]:
		var data: Dictionary = _base()
		var planet: String = _cult(data, "DOMAIN-001", 81, 100)
		var system: String = _cult(data, "DOMAIN-007", 81, 100)
		var a: String = _anchor(data, planet)
		var b: String = _anchor(data, system)
		data.world.state.faith = 6
		_attach(data)
		var order: Array = [a, b] if first == "planet" else [b, a]
		var refused: Array = [b] if first == "refuse" else []
		var ok: bool = _open(data) and _plan(data, {system: "expand", planet: "expand"}, order, refused)
		var before: String = data.turn.snapshot()
		var preview: Dictionary = data.turn.preview_plan("economy", data.turn.context.plans.economy)
		ok = ok and preview.ok and before == data.turn.snapshot() and _do(data, "end_actions") and _do(data, "advance")
		var expected_a: String = "dormant" if first == "system" else "active"
		var expected_b: String = "active" if first == "system" else "dormant"
		ok = ok and data.world.state.anchors[a].state == expected_a and data.world.state.anchors[b].state == expected_b and data.world.state.faith == (0 if first == "system" else 1)
		cases.append({"priority": first, "planet": data.world.state.anchors[a].state, "system": data.world.state.anchors[b].state, "faith_before_income": data.world.state.faith})
		valid = valid and ok
	_check("ECON-002", "先按稳定团序付传教，再依明确锚点优先序与拒付支付且不借未来收入", valid, {"cases": cases})

func _capabilities_and_growth() -> void:
	var valid: bool = true
	var cases: Array = []
	for mode: String in ["missing", "blocked", "poor", "one_person", "loss_not_recruitable"]:
		var data: Dictionary = _base()
		var amount: int = 993 if mode == "one_person" else (994 if mode == "loss_not_recruitable" else 36)
		var cult: String = _cult(data, "DOMAIN-001", amount, 80 if mode == "loss_not_recruitable" else 100)
		if mode == "missing":
			data.world.state.economy_qualifications.erase("propagation|" + cult) # Missing upstream input precondition.
		if mode == "blocked":
			var prior: String = data.world.state.economy_qualifications["propagation|" + cult]
			assert(data.world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": cult, "institution": "DOMAIN-001/propagation", "allowed": false, "issuer": "fixture-upstream", "version": "1", "parents": [prior]}))
		if mode == "poor":
			data.world.state.faith = 0
		_attach(data)
		var ok: bool = _open(data)
		var before: String = data.turn.snapshot()
		var request: Dictionary = _request(data, "set_plan", {"participant": "economy", "payload": {"strategies": {cult: "expand"}}})
		var response: Dictionary = data.turn.submit(request)
		if mode == "missing":
			ok = ok and not response.ok and before == data.turn.snapshot()
		else:
			ok = ok and response.ok and _do(data, "end_actions") and _do(data, "advance")
			ok = ok and data.world.state.domains["DOMAIN-001"].unnamed_followers == (994 if mode == "one_person" else (991 if mode == "loss_not_recruitable" else 36)) and data.world.state.faith == (16 if mode == "one_person" else (0 if mode == "poor" else 18))
		cases.append({"case": mode, "valid": ok})
		valid = valid and ok
	_check("ECON-003", "缺资格明确拒绝，封锁与缺资正常降级，余量一人只转一人", valid, {"cases": cases})

func _anchor_activation_and_capacity() -> void:
	var valid: bool = true
	var cases: Array = []
	for pollution: int in [20, 30]:
		var data: Dictionary = _base()
		var cult: String = _cult(data)
		var anchor: String = _anchor(data, cult, true)
		data.world.state.domains["DOMAIN-001"].pollution = pollution
		data.world.state.faith = 69
		_attach(data)
		var ok: bool = _open(data) and _do(data, "end_actions") and _do(data, "advance")
		ok = ok and data.world.state.domains["DOMAIN-001"].pollution == pollution - catalog.integer("pollution_base_decay") and data.world.state.faith == 68
		ok = ok and data.world.state.anchors[anchor].state == ("active" if pollution == 30 else "dormant") and _do(data, "advance")
		ok = ok and data.world.state.faith == (74 if pollution == 30 else 70)
		var income: Dictionary = Store.entry(data.world.state.facts, data.world.state.economy.income_sources[cult]).changes
		cases.append({"initial_pollution": pollution, "final_pollution": data.world.state.domains["DOMAIN-001"].pollution, "faith": data.world.state.faith, "anchor_state": data.world.state.anchors[anchor].state, "income": income})
		valid = valid and ok
	_check("ECON-004", "休眠锚付费后才在批末重验激活，新容量供本轮收入且溢出可追溯", valid, {"cases": cases})

func _rebuild_window() -> void:
	var data: Dictionary = _base()
	var cult: String = _cult(data, "DOMAIN-001", 36, 100)
	var origin: String = data.world.state.cults[cult].origin
	var leader: String = data.world.state.cults[cult].leader
	var authorization: String = data.world.introduce_fact("cult_establishment_authorized", "DOMAIN-001", leader, [leader], [origin], {"issuer": "fixture-upstream", "version": "1", "cult": cult, "domain": "DOMAIN-001", "leader": leader, "cohesion": 100}, [])
	_attach(data)
	var ok: bool = _open(data)
	ok = _command(data, {"kind": "population", "domain": "DOMAIN-001", "mode": "leave", "amount": 36, "parents": [origin]}) and ok
	var destroyed: bool = data.world.state.cults[cult].status == "destroyed"
	ok = _command(data, {"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": 36, "parents": [origin]}) and ok
	ok = _command(data, {"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}) and ok
	ok = _close(data) and ok
	var receipt: Dictionary = Store.entry(data.world.state.facts, data.world.state.economy.income_sources[cult]).changes
	ok = ok and destroyed and data.world.state.cults[cult].origin == origin and data.world.state.cults[cult].established_turn == 1 and receipt.gross == 0 and _open(data) and _close(data)
	ok = ok and Store.entry(data.world.state.facts, data.world.state.economy.income_sources[cult]).changes.gross == 6
	_check("ECON-005", "覆灭后同身份合法重建保留历史但本轮不继承收入窗口", ok)

func _transaction_failures() -> void:
	var valid: bool = true
	var cases: Array = []
	for stage: String in ["evolution", "settlement"]:
		var data: Dictionary = _base(stage == "evolution")
		var cult: String = _cult(data)
		_attach(data)
		var ok: bool = _open(data) and _plan(data, {cult: "expand"}) and _do(data, "act", {"participant": "fixture-upstream", "action": "paid", "payload": {}}) and _do(data, "end_actions")
		if stage == "settlement":
			ok = _do(data, "advance") and ok
			data.upstream.fault = true
		var before: String = data.turn.snapshot()
		var request: Dictionary = _request(data, "advance")
		var failed: Dictionary = data.turn.submit(request)
		var rolled_back: bool = not failed.ok and before == data.turn.snapshot()
		if stage == "evolution":
			data.economy.fault = false
		else:
			data.upstream.fault = false
		var retried: Dictionary = data.turn.submit(request)
		var committed: String = data.turn.snapshot()
		var repeated: Dictionary = data.turn.submit(request)
		ok = ok and rolled_back and retried.ok and World.canonical(retried) == World.canonical(repeated) and committed == data.turn.snapshot() and data.world.stats.npc_updates == 72
		valid = valid and ok
		cases.append({"stage": stage, "whole_stage_rollback": rolled_back, "retry_once": ok, "npc_updates": data.world.stats.npc_updates})
	_check("ECON-006", "经济批次与收入后故障回滚全部费用人口资格余量，重试与回执不刷钱", valid, {"cases": cases, "fault_injection": "验证专用经济子类故意返回超量招募，以及期限adapter故障；正常公式仍为生产Economy"})

func _stage_four_save() -> void:
	var data: Dictionary = _base()
	var cult: String = _cult(data, "DOMAIN-001", 49, 50)
	_attach(data)
	var ok: bool = _open(data) and _plan(data, {cult: "expand"}) and _do(data, "end_actions") and _do(data, "advance")
	var saved: String = data.turn.snapshot()
	var resumed: Dictionary = _attach(_base())
	ok = ok and resumed.turn.restore(saved)
	for operation: String in ["advance", "advance", "advance", "finish_events", "end_actions", "advance"]:
		var request: Dictionary = _request(data, operation)
		ok = data.turn.submit(request).ok and resumed.turn.submit(request).ok and data.turn.snapshot() == resumed.turn.snapshot() and ok
	ok = ok and data.world.stats.npc_updates == 144 and data.world.state.economy.remainders[cult] > 0
	_check("ECON-008", "正式经济演化后阶段存档续算保持资格小数计划与单次NPC更新", ok, {"npc_updates": data.world.stats.npc_updates, "remainder_units": data.world.state.economy.remainders[cult]})

func _measure() -> void:
	var data: Dictionary = _base()
	var strategies: Dictionary = {}
	for domain: Dictionary in data.world.state.domains.values():
		var cult: String = _cult(data, domain.id, 81, 80)
		strategies[cult] = "expand"
		var carrier: String = data.world.state.institutions[domain.id + "/propagation"].representative
		data.world.introduce_fact("public_anomaly", domain.id, carrier, [carrier], [domain.origin], {}, [carrier])
		domain.alert = catalog.integer("alert_investigation")
	var upstream: RefCounted = Upstream.new()
	upstream.active_load = true
	_attach(data, upstream)
	var durations: Array = []
	var stages: Dictionary = {"1": [], "2": [], "3": [], "4": [], "5": [], "6": []}
	var history: Array = []
	var actions_before: int = 0
	var totals_before: Dictionary = {"total_income": 0, "total_paid": 0, "total_recruited": 0, "total_attrition": 0}
	var valid: bool = true
	for index: int in 50:
		var started: int = Time.get_ticks_usec()
		var operations: Array = ["advance", "finish_events", "end_actions", "advance", "advance", "advance"]
		for stage: int in 6:
			var at: int = Time.get_ticks_usec()
			if stage == 2 and index == 0:
				valid = _plan(data, strategies) and valid
			valid = _do(data, operations[stage]) and valid
			stages[str(stage + 1)].append(float(Time.get_ticks_usec() - at) / 1000.0)
		durations.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if (index + 1) % 10 == 0:
			var window: Dictionary = {"turn": index + 1, "facts": Store.size(data.world.state.facts), "actions_in_10_turns": int(data.world.stats.actions) - actions_before, "last_turn_ms": durations.back(), "faith": data.world.state.faith}
			var now: Dictionary = _economic_totals(data.world)
			for key: String in now:
				window[key.trim_prefix("total_") + "_in_10_turns"] = int(now[key]) - int(totals_before[key])
			totals_before = now
			history.append(window)
			actions_before = data.world.stats.actions
			print("  ECON MEASURE ", index + 1, "/50 ", durations.back(), " ms")
		if not valid:
			break
	var totals: Dictionary = _economic_totals(data.world)
	var stage_metrics: Dictionary = {}
	for stage: String in stages:
		stage_metrics[stage] = _distribution(stages[stage])
	var save_at: int = Time.get_ticks_usec()
	var saved: String = data.turn.snapshot()
	var save_ms: float = float(Time.get_ticks_usec() - save_at) / 1000.0
	metrics = {"turns": data.world.state.turn, "seed": 7919, "domains": 12, "anchor_count": 0, "named_people": Store.size(data.world.state.npcs), "npc_updates": data.world.stats.npc_updates, "npc_actions": data.world.stats.actions, "plans_resolved": data.world.stats.plans_resolved, "complete_turn_ms": _distribution(durations), "stage_ms": stage_metrics, "history": history, "save_bytes": saved.to_utf8_buffer().size(), "save_ms": save_ms, "driver": "正式12域72人、12个显式上游授权的已有教团；生产经济执行持续传教/缺资降级/流失/教团收入，50轮未准备锚点，不包含锚供奉维护负载（该规则另有实际场景覆盖）。每6轮由验证上游产生有实际见证者的神迹/暴露，NPC/CIV和经济均为正式实现。计时含计划、六阶段事务、快照和校验。", "threshold": "无人为性能通过阈值；本项仅验证50轮完整执行与真实活动"}
	metrics.merge(totals)
	_check("ECON-007", "正式经济接入后50轮完整回合成本与持续真实活动实测", valid and data.world.state.turn == 50 and data.world.stats.npc_updates == 3600 and data.world.stats.actions > 0 and totals.total_paid > 0 and totals.total_income > 0 and totals.total_recruited > 0 and totals.total_attrition > 0 and int(history.back().actions_in_10_turns) > 0 and int(history.back().income_in_10_turns) > 0 and int(history.back().paid_in_10_turns) > 0 and int(history.back().recruited_in_10_turns) > 0 and int(history.back().attrition_in_10_turns) > 0, metrics)

func _economic_totals(world: RefCounted) -> Dictionary:
	var totals: Dictionary = {"total_income": 0, "total_paid": 0, "total_recruited": 0, "total_attrition": 0}
	for fact: Dictionary in Store.values(world.state.facts):
		if fact.kind == "economy_income": totals.total_income += int(fact.changes.actual)
		if fact.kind in ["economy_strategy_payment", "economy_anchor_payment"]: totals.total_paid += int(fact.changes.fee)
		if fact.kind == "economy_work":
			totals.total_recruited += int(fact.changes.growth)
			totals.total_attrition += int(fact.changes.loss)
	return totals

func _distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted: Array = values.duplicate()
	sorted.sort()
	return {"p50": sorted[int(floor(sorted.size() * 0.5))], "p95": sorted[int(floor(sorted.size() * 0.95))], "max": sorted.back()}

func _finish() -> void:
	var passed: int = 0
	for check: Dictionary in checks:
		if check.status == "pass": passed += 1
		if str(check.id).begins_with("ECON-QA"):
			print(("PASS " if check.status == "pass" else "FAIL ") + check.id + " " + check.name)
	checks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var report: Dictionary = {"schemaVersion": 1, "suite": "economy", "generatedAt": Time.get_datetime_string_from_system(true) + "Z", "status": "pass" if passed == checks.size() else "fail", "checks": checks, "metrics": metrics, "sourceHashes": {}, "environment": {"engine": Engine.get_version_info().string, "platform": OS.get_name(), "headless": true}, "scope": ["正式经济三策略/预付/收入/人口资格与精确自然流失", "真实NPC/CIV共同快照与六阶段事务", "既有锚点收费拒付/资格重验，纯预览与阶段续存"], "limitations": ["已有教团/锚点、上游传播和蓝本许可来自明确测试前提；不是完整建团、锚定或蓝本证明玩法", "完整人物任命、权能、事件与终局仍属后续任务", "聚合人口未指定真实子群时固定先扣旧收入资格；自然流失率最多6位小数且装载时验证", "测试故障开关仅用于验证回滚，不是生产规则状态", "50轮性能观测不是长战役有界性、跨平台性能或玩法平衡证明；没有短体验前置阶段"]}
	var file: FileAccess = FileAccess.open("res://docs/qa/economy-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	print("ECONOMY RESULT ", passed, "/", checks.size())
	quit(0 if passed == checks.size() else 1)
