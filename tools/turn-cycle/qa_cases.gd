extends RefCounted
## Independent negative and continuation cases for the turn coordinator contract.
## Participants below are test adapters; none are production content/economy rules.

const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const REQUIRED: Array[String] = ["events", "prepay", "income", "deadlines", "ending"]

var content: RefCounted
var records: Array = []
var sequence: int = 0
var unselected_branch_name: String = ""
var fault_slot: String = ""
var fault_enabled: bool = false
var hidden_charge_mode: String = ""

func run(catalog: RefCounted) -> Array:
	content = catalog
	records = []
	sequence = 0
	_test_required_capabilities()
	_test_bad_participant_results()
	_test_phase_and_receipt_guards()
	_test_detached_context()
	_test_participant_version_restore()
	_test_midturn_continuation()
	_test_rejected_adoption()
	_test_event_response_guard()
	_test_unselected_check_branch()
	_test_bad_phase_snapshots()
	_test_phase_rollback()
	_test_future_income_cannot_pay()
	_test_frozen_event_boundary()
	_test_default_hidden_charge()
	return records

func _check(id: String, name: String, passed: bool, details: Dictionary = {}) -> void:
	records.append({"id": id, "name": name, "status": "pass" if passed else "fail", "details": details})

func _world(seed_value: int = 1979) -> RefCounted:
	var world: RefCounted = World.new(content)
	world.generate(seed_value)
	return world

func _empty(_context: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
	if input.slot == "events" and input.operation == "gather":
		result["events"] = []
	return result

func _setup(event_handler: Callable = Callable(), event_effects: Array = []) -> Dictionary:
	var world: RefCounted = _world()
	var turn: RefCounted = Turn.new(world)
	var registered: bool = true
	for slot: String in REQUIRED:
		var handler: Callable = event_handler if slot == "events" and event_handler.is_valid() else _empty
		registered = turn.register_participant("qa_" + slot, "1", [slot], event_effects if slot == "events" else [], handler) and registered
	return {"world": world, "turn": turn, "registered": registered}

func _request(turn: RefCounted, world: RefCounted, operation: String, extra: Dictionary = {}) -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "QA-%d" % sequence, "op": operation, "turn": world.state.turn, "phase": turn.context.phase}
	request.merge(extra)
	return request

func _test_required_capabilities() -> void:
	var world: RefCounted = _world()
	var turn: RefCounted = Turn.new(world)
	var before: String = turn.snapshot()
	var result: Dictionary = turn.submit(_request(turn, world, "advance"))
	_check("TURN-QA-001", "缺少必需规则参与能力时拒绝开轮且不消费世界或随机状态", not result.get("ok", true) and before == turn.snapshot())
	var setup: Dictionary = _setup()
	world = setup.world
	turn = setup.turn
	before = turn.snapshot()
	var began: bool = world.begin_turn()
	world.evolve()
	world.advance()
	_check("TURN-QA-002", "接管后不能通过推演核心入口绕过阶段", setup.registered and not began and before == turn.snapshot())

func _null_result(_context: Dictionary, _input: Dictionary):
	return null

func _array_result(_context: Dictionary, _input: Dictionary):
	return []

func _missing_result(_context: Dictionary, _input: Dictionary) -> Dictionary:
	return {"ok": true}

func _wrong_ok(_context: Dictionary, _input: Dictionary) -> Dictionary:
	return {"ok": "true", "empty": true, "effects": [], "state": {}, "events": []}

func _unknown_effect(_context: Dictionary, _input: Dictionary) -> Dictionary:
	return {"ok": true, "empty": false, "effects": [{"type": "qa_unknown_effect"}], "state": {}, "events": []}

func _test_bad_participant_results() -> void:
	var cases: Array = [
		{"name": "null", "handler": _null_result},
		{"name": "array", "handler": _array_result},
		{"name": "missing_fields", "handler": _missing_result},
		{"name": "non_boolean_ok", "handler": _wrong_ok},
		{"name": "unknown_effect", "handler": _unknown_effect},
	]
	var passed: bool = true
	var outcomes: Array = []
	for entry: Dictionary in cases:
		var setup: Dictionary = _setup(entry.handler)
		var before: String = setup.turn.snapshot()
		var result: Dictionary = setup.turn.submit(_request(setup.turn, setup.world, "advance"))
		var rejected: bool = not result.get("ok", true) and setup.turn.snapshot() == before
		passed = passed and setup.registered and rejected
		outcomes.append({"case": entry.name, "rejected_without_changes": rejected})
	_check("TURN-QA-003", "不合规参与者返回与未知效果整笔拒绝", passed, {"cases": outcomes})

func _test_phase_and_receipt_guards() -> void:
	var setup: Dictionary = _setup()
	var world: RefCounted = setup.world
	var turn: RefCounted = setup.turn
	var request: Dictionary = _request(turn, world, "advance")
	var result: Dictionary = turn.submit(request)
	var after: String = turn.snapshot()
	var retry: Dictionary = turn.submit(request.duplicate(true))
	var idempotent: bool = result.get("ok", false) and World.canonical(result) == World.canonical(retry) and turn.snapshot() == after
	var changed: Dictionary = request.duplicate(true)
	changed.op = "finish_events"
	var rejected: Dictionary = turn.submit(changed)
	var mismatch: bool = not rejected.get("ok", true) and turn.snapshot() == after
	var wrong_phase: Dictionary = _request(turn, world, "end_actions")
	var wrong: Dictionary = turn.submit(wrong_phase)
	var guarded: bool = not wrong.get("ok", true) and turn.snapshot() == after
	_check("TURN-QA-004", "请求重放不重复效果，同ID异内容及越阶段操作拒绝", setup.registered and idempotent and mismatch and guarded,
		{"same_receipt": idempotent, "payload_mismatch": mismatch, "wrong_phase": guarded})

func _mutate_context(context: Dictionary, _input: Dictionary) -> Dictionary:
	context.world.faith = 987654
	return {"ok": true, "empty": true, "effects": [], "state": {}, "events": []}

func _test_detached_context() -> void:
	var setup: Dictionary = _setup(_mutate_context)
	var before_faith: int = setup.world.state.faith
	var result: Dictionary = setup.turn.submit(_request(setup.turn, setup.world, "advance"))
	_check("TURN-QA-005", "参与者读取快照不获得权威世界写权限", setup.registered and result.get("ok", false) and setup.world.state.faith == before_faith)

func _test_participant_version_restore() -> void:
	var setup: Dictionary = _setup()
	var began: Dictionary = setup.turn.submit(_request(setup.turn, setup.world, "advance"))
	var encoded: String = setup.turn.snapshot()
	var receiver_world: RefCounted = _world(1981)
	var receiver: RefCounted = Turn.new(receiver_world)
	for slot: String in REQUIRED:
		receiver.register_participant("qa_" + slot, "different" if slot == "income" else "1", [slot], [], _empty)
	var before: String = receiver.snapshot()
	var restored: bool = receiver.restore(encoded)
	_check("TURN-QA-006", "参与能力版本不匹配时拒绝整体恢复且保留原会话", began.get("ok", false) and not restored and receiver.snapshot() == before)

func _test_midturn_continuation() -> void:
	var outcomes: Array = []
	var passed: bool = true
	# Each checkpoint uses a fresh real world. The adapters are intentionally empty;
	# world NPC updates, civilian recovery, facts and RNG remain real implementation.
	for prefix: Array in [[], ["finish_events"], ["finish_events", "end_actions", "advance"]]:
		var setup: Dictionary = _setup()
		var ok: bool = setup.turn.submit(_request(setup.turn, setup.world, "advance")).get("ok", false)
		for operation: String in prefix:
			ok = setup.turn.submit(_request(setup.turn, setup.world, operation)).get("ok", false) and ok
		var saved_phase: String = setup.turn.context.phase
		var encoded: String = setup.turn.snapshot()
		var resumed: Dictionary = _setup()
		ok = resumed.turn.restore(encoded) and ok
		var before_updates: int = setup.world.stats.npc_updates
		var commands: Array = []
		if saved_phase == "events":
			commands.append("finish_events")
		if saved_phase in ["events", "actions"]:
			commands.append_array(["end_actions", "advance"])
		commands.append_array(["advance", "advance"])
		for operation: String in commands:
			var request: Dictionary = _request(setup.turn, setup.world, operation)
			var original: Dictionary = setup.turn.submit(request)
			var restored: Dictionary = resumed.turn.submit(request.duplicate(true))
			ok = original.get("ok", false) and restored.get("ok", false) and World.canonical(original) == World.canonical(restored) and ok
		ok = setup.turn.snapshot() == resumed.turn.snapshot() and ok
		if saved_phase == "settlement":
			ok = setup.world.stats.npc_updates == before_updates and ok
		else:
			ok = setup.world.stats.npc_updates > before_updates and ok
		outcomes.append({"checkpoint": saved_phase, "consistent": ok, "updates_before": before_updates, "updates_after": setup.world.stats.npc_updates})
		passed = passed and ok
	_check("TURN-QA-007", "事件、行动和演化后保存续接一致且不重复人物演化", passed, {"checkpoints": outcomes})

func _test_rejected_adoption() -> void:
	var world: RefCounted = _world()
	world.advance()
	var before_turn: int = world.state.turn
	var rejected_turn: RefCounted = Turn.new(world)
	var no_snapshot: bool = rejected_turn.snapshot().is_empty()
	var still_usable: bool = world.begin_turn()
	_check("TURN-QA-008", "拒绝接管已有推演世界不锁死原会话", no_snapshot and still_usable and int(world.state.turn) == before_turn + 1)

func _source(view: Dictionary) -> String:
	return view.domains["DOMAIN-001"].origin

func _meta(view: Dictionary) -> Dictionary:
	return {"faith_cost": 0, "whispers_cost": 0, "min_awakening": 0, "responds": false, "used_power": false, "used_relic": false, "actor": "", "source": _source(view), "outcome": "test_adapter"}

func _responding_event(context: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
	if input.operation == "gather":
		result["events"] = [{"id": "QA-EVENT", "default_action": "bear", "payload": {}, "source": _source(context.world)}]
	else:
		result["meta"] = _meta(context.world)
		result.meta.responds = true
	return result

func _test_event_response_guard() -> void:
	var setup: Dictionary = _setup(_responding_event)
	var opened: Dictionary = setup.turn.submit(_request(setup.turn, setup.world, "advance"))
	var before: String = setup.turn.snapshot()
	var result: Dictionary = setup.turn.submit(_request(setup.turn, setup.world, "resolve_event", {"event": "QA-EVENT", "action": "bear"}))
	_check("TURN-QA-009", "事件参与者不能冒占唯一祈求回应机会", opened.get("ok", false) and not result.get("ok", true) and setup.turn.snapshot() == before)

func _malformed_unselected_branch(context: Dictionary, _input: Dictionary) -> Dictionary:
	var branches: Dictionary = {"deep": [], "success": [], "failure": [], "disaster": []}
	branches[unselected_branch_name] = [{"type": "unknown_branch_effect", "source": _source(context.world)}]
	var actor: String = context.world.institutions["DOMAIN-001/order"].representative
	var check: Dictionary = {"type": "check", "source": _source(context.world), "npc": actor, "attribute": "will", "domain": "DOMAIN-001", "mode": "occult", "preparation": 0, "branches": branches}
	return {"ok": true, "empty": false, "effects": [check], "state": {}, "meta": _meta(context.world)}

func _test_unselected_check_branch() -> void:
	var setup: Dictionary = _setup()
	var world: RefCounted = setup.world
	var turn: RefCounted = setup.turn
	var registered: bool = turn.register_participant("qa_actions", "1", ["actions"], ["check"], _malformed_unselected_branch)
	var actor: String = world.state.institutions["DOMAIN-001/order"].representative
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	probe.seed = world.randoms.checks.seed
	probe.state = world.randoms.checks.state
	var outcome: String = world.check_result(world.check_probability(actor, "will", "DOMAIN-001"), probe.randi_range(1, 100))
	unselected_branch_name = "failure" if outcome != "failure" else "success"
	var opened: bool = turn.submit(_request(turn, world, "advance")).get("ok", false)
	opened = turn.submit(_request(turn, world, "finish_events")).get("ok", false) and opened
	var before: String = turn.snapshot()
	var result: Dictionary = turn.submit(_request(turn, world, "act", {"participant": "qa_actions", "action": "malformed", "payload": {}}))
	_check("TURN-QA-010", "未抽中分支的不合法效果也必须在投骰前拒绝", registered and opened and not result.get("ok", true) and turn.snapshot() == before,
		{"would_draw": outcome, "invalid_branch": unselected_branch_name})

func _test_bad_phase_snapshots() -> void:
	var setup: Dictionary = _setup()
	var opened: bool = setup.turn.submit(_request(setup.turn, setup.world, "advance")).get("ok", false)
	if not opened:
		_check("TURN-QA-011", "重签校验和的阶段和凭据矛盾仍整体拒绝", false, {"precondition": "initial turn failed", "error": setup.turn.last_error})
		return
	var saved: Dictionary = World._normalize_numbers(JSON.parse_string(setup.turn.snapshot()))
	var cases: Array = ["turn_mismatch", "phase_mismatch", "journal_duplicate", "receipt_future", "receipt_future_phase", "receipt_missing_phase", "invalid_completed_job"]
	var passed: bool = opened
	var outcomes: Array = []
	for name: String in cases:
		var corrupt: Dictionary = saved.duplicate(true)
		match name:
			"turn_mismatch": corrupt.body.context.turn += 1
			"phase_mismatch": corrupt.body.context.phase = "settlement"
			"journal_duplicate": corrupt.body.context.journal.append(corrupt.body.context.journal[0].duplicate(true))
			"receipt_future":
				var id: String = corrupt.body.context.receipts.keys()[0]
				corrupt.body.context.receipts[id].response.turn += 99
			"receipt_future_phase":
				var id: String = corrupt.body.context.receipts.keys()[0]
				var receipt: Dictionary = corrupt.body.context.receipts[id]
				receipt.request.op = "advance"
				receipt.request.turn = 1
				receipt.request.phase = "evolution"
				receipt.response.turn = 1
				receipt.response.phase = "settlement"
				receipt.fingerprint = World.canonical(receipt.request).sha256_text()
			"receipt_missing_phase":
				corrupt.body.context.receipts.clear()
			"invalid_completed_job":
				corrupt.body.context.completed_jobs["IMPOSSIBLE"] = {"turn": 999, "phase": "outside", "source": "NO-FACT"}
		corrupt.checksum = World.canonical(corrupt.body).sha256_text()
		var before: String = setup.turn.snapshot()
		var restored: bool = setup.turn.restore(World.canonical(corrupt))
		var rejected: bool = not restored and setup.turn.snapshot() == before
		outcomes.append({"case": name, "rejected_without_changes": rejected})
		passed = passed and rejected
		if restored:
			# Keep subsequent independent cases on the original, known-good session.
			setup.turn.restore(World.canonical(saved))
	# A valid historic end-of-turn receipt cannot claim termination while the
	# unchanged world and journal prove that the session entered another turn.
	var progressed: bool = true
	for operation: String in ["finish_events", "end_actions", "advance", "advance", "advance", "advance"]:
		progressed = setup.turn.submit(_request(setup.turn, setup.world, operation)).get("ok", false) and progressed
	var current: String = setup.turn.snapshot()
	var later: Dictionary = World._normalize_numbers(JSON.parse_string(current))
	var replaced: bool = false
	for receipt: Dictionary in later.body.context.receipts.values():
		if receipt.request.op == "advance" and receipt.request.turn == 1 and receipt.request.phase == "ending":
			receipt.response.phase = "ended"
			receipt.response.result.outcome = "extinction"
			replaced = true
	later.checksum = World.canonical(later.body).sha256_text()
	var terminal_rejected: bool = progressed and replaced and not setup.turn.restore(World.canonical(later)) and setup.turn.snapshot() == current
	outcomes.append({"case": "receipt_past_terminal", "rejected_without_changes": terminal_rejected})
	passed = passed and terminal_rejected
	_check("TURN-QA-011", "重签校验和的阶段和凭据矛盾仍整体拒绝", passed, {"cases": outcomes})

func _transaction_setup(failure_slot: String, faith_override: int = -1) -> Dictionary:
	fault_slot = failure_slot
	fault_enabled = true
	var world: RefCounted = _world()
	if faith_override >= 0:
		world.state.faith = faith_override
	var domain: Dictionary = world.state.domains["DOMAIN-001"]
	var leader: String = world.state.institutions["DOMAIN-001/order"].representative
	# Existing-cult precondition only; this does not claim cult creation is implemented.
	world.state.cults["CULT-QA"] = {"id": "CULT-QA", "domain": domain.id, "leader": leader, "cohesion": 100, "status": "active"}
	var turn: RefCounted = Turn.new(world)
	var registered: bool = true
	for slot: String in REQUIRED + ["actions"]:
		registered = turn.register_participant("qa_" + slot, "1", [slot], ["resource", "check", "world_command"], _transaction_adapter) and registered
	return {"world": world, "turn": turn, "registered": registered}

func _transaction_adapter(context: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = _empty(context, input)
	var source: String = _source(context.world)
	if input.slot == "actions":
		result["meta"] = _meta(context.world)
		result.meta.faith_cost = 1
		result.meta.outcome = "committed_action"
	if input.slot == "prepay":
		result.effects.append({"type": "resource", "field": "faith", "delta": -1, "source": source})
	if input.slot == "income":
		result.effects.append({"type": "resource", "field": "faith", "delta": 2, "source": source, "basis": {"cult": "CULT-QA", "eligible": 0, "rule": "explicit_QA_contract_income"}})
	if input.slot == fault_slot and fault_enabled:
		var actor: String = context.world.institutions["DOMAIN-001/order"].representative
		var destination: String = context.world.domains["DOMAIN-001"].neighbors[0]
		# All four branches are legal. RNG and first death effect occur before the
		# later migration becomes invalid, exercising rollback after actual writes.
		result.effects.append({"type": "check", "source": source, "npc": actor, "attribute": "will", "domain": "DOMAIN-001", "mode": "occult", "preparation": 0, "branches": {"deep": [], "success": [], "failure": [], "disaster": []}})
		result.effects.append({"type": "world_command", "source": source, "command": {"kind": "status", "npc": actor, "status": "dead", "parents": [source]}})
		result.effects.append({"type": "world_command", "source": source, "command": {"kind": "migrate", "npc": actor, "domain": destination, "parents": [source]}})
	result.empty = result.effects.is_empty()
	return result

func _test_phase_rollback() -> void:
	var outcomes: Array = []
	var passed: bool = true
	for failure_slot: String in ["prepay", "deadlines"]:
		var setup: Dictionary = _transaction_setup(failure_slot)
		var world: RefCounted = setup.world
		var turn: RefCounted = setup.turn
		var initial_faith: int = world.state.faith
		var ok: bool = setup.registered
		ok = turn.submit(_request(turn, world, "advance")).get("ok", false) and ok
		ok = turn.submit(_request(turn, world, "finish_events")).get("ok", false) and ok
		ok = turn.submit(_request(turn, world, "act", {"participant": "qa_actions", "action": "commit", "payload": {}})).get("ok", false) and ok
		ok = int(world.state.faith) == initial_faith - 1 and ok
		ok = turn.submit(_request(turn, world, "end_actions")).get("ok", false) and ok
		if failure_slot == "deadlines":
			ok = turn.submit(_request(turn, world, "advance")).get("ok", false) and ok
		var before: String = turn.snapshot()
		var before_updates: int = world.stats.npc_updates
		var request: Dictionary = _request(turn, world, "advance")
		var failure: Dictionary = turn.submit(request)
		var restored: bool = not failure.get("ok", true) and turn.snapshot() == before
		# Repair the deliberately failing adapter, then retry the identical request.
		# The external flag is a fault-injection switch, never production rule state.
		fault_enabled = false
		var retried: Dictionary = turn.submit(request)
		var correct_updates: bool = int(world.stats.npc_updates) == before_updates if failure_slot == "deadlines" else int(world.stats.npc_updates) == before_updates + world.state.npcs.size()
		var expected_faith: int = initial_faith if failure_slot == "deadlines" else initial_faith - 2
		var successful: bool = retried.get("ok", false) and correct_updates and int(world.state.faith) == expected_faith
		var after: String = turn.snapshot()
		var repeated: Dictionary = turn.submit(request.duplicate(true))
		var idempotent: bool = World.canonical(retried) == World.canonical(repeated) and after == turn.snapshot()
		outcomes.append({"stage": failure_slot, "preconditions": ok, "whole_stage_rollback": restored, "retry_once": successful, "receipt_replay": idempotent, "updates_before": before_updates, "updates_after": world.stats.npc_updates})
		passed = passed and ok and restored and successful and idempotent
	_check("TURN-QA-012", "阶段四与五在真实支付投骰死亡后失败整阶段回滚，前阶段保留", passed, {"cases": outcomes, "scope": "真实world/NPC/CIV与受管理QA支付收入参加者；不证明正式教团经济"})

func _test_future_income_cannot_pay() -> void:
	var setup: Dictionary = _transaction_setup("none", 0)
	var world: RefCounted = setup.world
	var turn: RefCounted = setup.turn
	var ok: bool = setup.registered and turn.submit(_request(turn, world, "advance")).get("ok", false)
	ok = turn.submit(_request(turn, world, "finish_events")).get("ok", false) and ok
	ok = turn.submit(_request(turn, world, "end_actions")).get("ok", false) and ok
	var before: String = turn.snapshot()
	var result: Dictionary = turn.submit(_request(turn, world, "advance"))
	var future: Dictionary = _request(turn, world, "advance")
	future.phase = "settlement"
	var skipped: Dictionary = turn.submit(future)
	_check("TURN-QA-013", "当轮未来收入不能垫付阶段四且不能跳到收入阶段", ok and not result.get("ok", true) and not skipped.get("ok", true) and before == turn.snapshot() and world.state.faith == 0 and world.stats.npc_updates == 0,
		{"current_faith": 0, "prepay_required": 1, "later_fixture_income": 2})

func _frozen_selector(context: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = _empty(context, input)
	if input.operation == "gather":
		result.events.append({"id": "QA-ORIGINAL", "default_action": "bear", "payload": {}, "source": _source(context.world)})
		# This explicit test candidate depends on a real consequence of QA-ORIGINAL.
		# It is not a substitute for the still-pending production event selector.
		if context.world.wounds > 0:
			result.events.append({"id": "QA-SUCCESSOR", "default_action": "bear", "payload": {}, "source": _source(context.world)})
	else:
		result["meta"] = _meta(context.world)
		result.effects.append({"type": "wounds", "source": _source(context.world), "delta": 1})
		result.empty = false
		if input.action == "rescreen":
			result["events"] = []
	return result

func _test_frozen_event_boundary() -> void:
	var setup: Dictionary = _setup(_frozen_selector, ["wounds"])
	var world: RefCounted = setup.world
	var turn: RefCounted = setup.turn
	var ok: bool = setup.registered and world.state.wounds == 0
	ok = turn.submit(_request(turn, world, "advance")).get("ok", false) and ok
	var first_count: int = turn.context.events.size()
	var before: String = turn.snapshot()
	var rescreen: Dictionary = turn.submit(_request(turn, world, "resolve_event", {"event": "QA-ORIGINAL", "action": "rescreen"}))
	var rescreen_rejected: bool = not rescreen.get("ok", true) and before == turn.snapshot()
	# finish_events actually applies the zero-cost default, not merely a log entry.
	ok = turn.submit(_request(turn, world, "finish_events")).get("ok", false) and ok
	var immediate: bool = world.state.wounds == 1 and turn.context.events.size() == first_count and first_count == 1 and turn.context.events[0].resolved
	var restored: Dictionary = _setup(_frozen_selector, ["wounds"])
	var continued: bool = restored.turn.restore(turn.snapshot())
	continued = continued and restored.turn.snapshot() == turn.snapshot()
	for operation: String in ["end_actions", "advance", "advance", "advance", "advance"]:
		var request: Dictionary = _request(turn, world, operation)
		ok = turn.submit(request).get("ok", false) and ok
		continued = restored.turn.submit(request).get("ok", false) and continued
	var next_count: int = turn.context.events.size()
	continued = continued and restored.turn.snapshot() == turn.snapshot()
	_check("TURN-QA-014", "真实事件后果即时落地，冻结名单和续档不重筛，后继候选仅下轮进入", ok and rescreen_rejected and immediate and continued and next_count == 2 and world.state.turn == 2,
		{"rescreen_rejected": rescreen_rejected, "immediate_wounds": immediate, "first_event_count": first_count, "next_event_count": next_count, "continuation_equal": continued, "selector_scope": "explicit_QA_candidate_rule"})

func _hidden_default(context: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = _empty(context, input)
	var source: String = _source(context.world)
	if input.operation == "gather":
		result.events.append({"id": "QA-HIDDEN", "default_action": "bear", "payload": {}, "source": source})
		if hidden_charge_mode == "zero":
			result.events.append({"id": "QA-ZERO", "default_action": "bear", "payload": {}, "source": source})
		return result
	result["meta"] = _meta(context.world)
	if hidden_charge_mode == "zero" and input.action == "exhaust":
		result.meta.faith_cost = context.world.faith
		result.meta.whispers_cost = context.world.whispers
		return result
	var charge: Dictionary = {"type": "resource", "source": source, "field": "faith", "delta": -1}
	match hidden_charge_mode:
		"zero":
			result.effects.append({"type": "wounds", "source": source, "delta": 1})
		"meta":
			result.meta.faith_cost = 1
		"direct":
			result.effects.append(charge)
		"branch":
			var actor: String = context.world.institutions["DOMAIN-001/order"].representative
			result.effects.append({"type": "check", "source": source, "npc": actor, "attribute": "will", "domain": "DOMAIN-001", "mode": "occult", "preparation": 0,
				"branches": {"deep": [charge], "success": [], "failure": [], "disaster": []}})
	result.empty = result.effects.is_empty()
	return result

func _test_default_hidden_charge() -> void:
	var cases: Array = []
	var passed: bool = true
	for mode: String in ["meta", "direct", "branch"]:
		hidden_charge_mode = mode
		var setup: Dictionary = _setup(_hidden_default, ["resource", "check"])
		var opened: bool = setup.turn.submit(_request(setup.turn, setup.world, "advance")).get("ok", false)
		var before: String = setup.turn.snapshot()
		var result: Dictionary = setup.turn.submit(_request(setup.turn, setup.world, "finish_events"))
		var rejected: bool = opened and not result.get("ok", true) and before == setup.turn.snapshot()
		cases.append({"charge_location": mode, "rejected_without_changes": rejected})
		passed = passed and rejected
	hidden_charge_mode = "zero"
	var zero: Dictionary = _setup(_hidden_default, ["resource", "check", "wounds"])
	var zero_ok: bool = zero.turn.submit(_request(zero.turn, zero.world, "advance")).get("ok", false)
	zero_ok = zero.turn.submit(_request(zero.turn, zero.world, "resolve_event", {"event": "QA-HIDDEN", "action": "exhaust"})).get("ok", false) and zero_ok
	zero_ok = zero.world.state.faith == 0 and zero.world.state.whispers == 0 and zero_ok
	zero_ok = zero.turn.submit(_request(zero.turn, zero.world, "finish_events")).get("ok", false) and zero_ok
	zero_ok = zero.world.state.wounds == 1 and zero.turn.context.phase == "actions" and zero_ok
	_check("TURN-QA-015", "强制默认在零资源仍可结算，费用、效果或骰分支不得隐藏扣费", passed and zero_ok, {"cases": cases, "zero_resources_default_applied": zero_ok})
