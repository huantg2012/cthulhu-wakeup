extends SceneTree
## Independent adversarial tests of the declared transaction/read contracts.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const Economy = preload("res://src/game/economy.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const StateView = preload("res://src/simulation/state_view.gd")
var catalog: RefCounted
var checks: Array = []
var sequence: int = 0

class ObservedWorld extends World:
	var snapshot_calls: int = 0
	var audit_calls: int = 0
	func snapshot() -> String:
		snapshot_calls += 1
		return super.snapshot()
	func validate_state(candidate: Dictionary) -> Array[String]:
		audit_calls += 1
		return super.validate_state(candidate)

class Adapter extends RefCounted:
	var captured_world: RefCounted
	var captured_turn: RefCounted
	var captured_rng: RandomNumberGenerator
	var mode: String = "empty"
	var returned: Dictionary = {}
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var source: String = view.world.domains["DOMAIN-001"].origin
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {"nested": {"value": 1}}}
		if input.slot == "events" and input.operation == "gather":
			result.events = []
		if input.slot == "actions":
			result.meta = {"faith_cost": 1 if input.action == "paid" else 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": source, "outcome": "qa", "responds": false, "used_power": false, "used_relic": false}
			if input.action == "batch":
				var actor: String = view.world.institutions["DOMAIN-001/order"].representative
				var branch: Array = [{"type": "wounds", "source": source, "delta": 1}]
				result.effects.append({"type": "check", "source": source, "npc": actor, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": branch, "success": branch, "failure": branch, "disaster": branch}})
				for ignored: int in 2:
					result.effects.append({"type": "resource", "source": source, "field": "faith", "delta": -(int(view.world.faith) / 2 + 1)})
			if input.action == "mutate_view":
				view.world.faith = 999999
				view.world.npcs[view.world.institutions["DOMAIN-001/order"].representative].relations.clear()
				view.turn.plans["injected"] = {"nested": [1]}
			if input.action == "captured":
				captured_world.state.faith += 1000
				captured_world.state.npcs[captured_world.state.institutions["DOMAIN-001/order"].representative].relations.clear()
				captured_turn.context.plans["injected"] = {"nested": [1]}
			if input.action == "captured_rng":
				captured_world.randoms.checks.randi()
			if input.action == "captured_sequence":
				captured_turn.commit_sequence = 999
		result.empty = result.effects.is_empty()
		returned = result
		return result
	func preview(_view: Dictionary, _plan: Dictionary) -> Dictionary:
		if mode == "preview_mutation":
			captured_world.randoms.events.randi()
			captured_world.state.faith += 1000
			captured_turn.context.plans["injected"] = {"nested": [1]}
		if mode == "preview_old_rng":
			captured_rng.randi()
		if mode == "preview_sequence":
			captured_turn.commit_sequence = 999
		return {"ok": true, "preview": {"nested": {"value": 1}}}

func _initialize() -> void:
	catalog = Catalog.new()
	assert(catalog.load_files())
	_atomic()
	_isolation()
	_preview()
	_merged_candidates()
	_views()
	_load_audit()
	_hot_path()
	_adoption()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var ok: bool = true
	for check: Dictionary in checks:
		ok = ok and check.status == "pass"
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": checks}, "\t", true, true))
	file.close()
	quit(0 if ok else 1)

func _check(id: String, name: String, ok: bool, details: Dictionary = {}) -> void:
	checks.append({"id": id, "name": name, "status": "pass" if ok else "fail", "details": details})
	print("PASS " if ok else "FAIL ", id, " ", name, " ", details)

func _world() -> RefCounted:
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	return world

func _setup() -> Dictionary:
	var world: RefCounted = _world()
	var turn: RefCounted = Turn.new(world)
	var adapter: RefCounted = Adapter.new()
	adapter.captured_world = world
	adapter.captured_turn = turn
	adapter.captured_rng = world.randoms.checks
	assert(turn.register_participant("tx-fixture", "1", Turn.SLOTS, Turn.EFFECTS, adapter.handle, adapter.preview))
	return {"world": world, "turn": turn, "adapter": adapter}

func _request(data: Dictionary, op: String, action: String = "") -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "TX-QA-%d" % sequence, "op": op, "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	if not action.is_empty():
		request.merge({"participant": "tx-fixture", "action": action, "payload": {}})
	return request

func _open(data: Dictionary) -> void:
	assert(data.turn.submit(_request(data, "advance")).ok)
	assert(data.turn.submit(_request(data, "finish_events")).ok)

func _atomic() -> void:
	var data: Dictionary = _setup()
	_open(data)
	var paid: Dictionary = _request(data, "act", "paid")
	assert(data.turn.submit(paid).ok)
	var before: String = data.turn.snapshot()
	var bad: Dictionary = data.turn.submit(_request(data, "act", "batch"))
	var after_failed: String = data.turn.snapshot()
	var again: Dictionary = data.turn.submit(paid)
	_check("TX-002", "合并超支回滚本笔费用、事实、ID、随机和上下文；先前成功动作及回执保留", not bad.ok and before == after_failed and again.ok and before == data.turn.snapshot(), {"rejection": bad.get("error", ""), "prior_receipt": paid.id})
	data.adapter.captured_turn = null

func _isolation() -> void:
	var data: Dictionary = _setup()
	_open(data)
	var before_state: String = data.world.snapshot()
	var result: Dictionary = data.turn.submit(_request(data, "act", "mutate_view"))
	# Successful empty action creates its ordinary action fact; test the intended fields.
	var parsed: Dictionary = JSON.parse_string(before_state).body.state
	var npc: String = parsed.institutions["DOMAIN-001/order"].representative
	_check("TX-003", "修改参与者副本的嵌套人物、计划和资源不修改权威状态", result.ok and data.world.state.faith == parsed.faith and data.world.state.npcs[npc].relations == parsed.npcs[npc].relations and not data.turn.context.plans.has("injected"))
	var before: String = data.turn.snapshot()
	result = data.turn.submit(_request(data, "act", "captured"))
	_check("TX-004", "捕获协调器和世界引用的越权写入整笔拒绝并隔离", not result.ok and before == data.turn.snapshot(), {"rejection": result.get("error", "")})
	before = data.turn.snapshot()
	result = data.turn.submit(_request(data, "act", "captured_rng"))
	_check("TX-005", "参与者绕过声明消耗随机流被拒绝且恢复随机位置", not result.ok and before == data.turn.snapshot(), {"rejection": result.get("error", "")})
	result = data.turn.submit(_request(data, "act", "paid"))
	before = data.turn.snapshot()
	data.adapter.returned.state.nested.value = 999
	data.adapter.returned.effects.append({"type": "forged"})
	_check("TX-006", "返回声明在提交后被修改不会改写已发布参与者状态", result.ok and before == data.turn.snapshot())
	data.adapter.captured_turn = null

func _preview() -> void:
	var data: Dictionary = _setup()
	_open(data)
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.turn.preview_plan("tx-fixture", {})
	_check("TX-007", "纯预览不产生回执、随机消耗或提交", preview.ok and before == data.turn.snapshot())
	data.adapter.mode = "preview_mutation"
	preview = data.turn.preview_plan("tx-fixture", {})
	_check("TX-008", "恶意预览的资源、计划及随机写入被拒绝并恢复", not preview.ok and before == data.turn.snapshot(), {"rejection": preview.get("error", "")})
	data.adapter.mode = "preview_old_rng"
	# Capture the CURRENT authoritative RNG before preview swaps its guarded field.
	data.adapter.captured_rng = data.world.randoms.checks
	preview = data.turn.preview_plan("tx-fixture", {})
	_check("TX-019", "预览前捕获的随机对象不能绕过字段隔离改变随机位置", not preview.ok and before == data.turn.snapshot(), {"rejection": preview.get("error", "")})
	data.adapter.captured_turn = null

func _merged_candidates() -> void:
	var world: RefCounted = _world()
	var before: String = world.snapshot()
	var tx: RefCounted = Transaction.new(world, {})
	tx.touch_world(["domains"])
	var domain: Dictionary = tx.candidate.domains["DOMAIN-001"]
	var amount: int = int(domain.unnamed_nonfollowers) / 2 + 1
	domain.unnamed_nonfollowers -= amount
	domain.unnamed_followers += amount
	var first_valid: bool = tx.validate_world().is_empty()
	domain.unnamed_nonfollowers -= amount
	domain.unnamed_followers += amount
	var invalid: Array = tx.validate_world()
	_check("TX-009", "单笔合法人口转换合并后超额消耗人口被最终候选校验拒绝", first_valid and not invalid.is_empty() and before == world.snapshot(), {"errors": invalid})
	# Independently valid same-domain establishments cannot both own that domain.
	world = _world()
	var economy: RefCounted = Economy.new(catalog, {"tx-fixture": "1"})
	assert(economy.initialize(world))
	var origin: String = world.state.domains["DOMAIN-001"].origin
	var actor: String = world.state.institutions["DOMAIN-001/propagation"].representative
	world.state.npcs[actor].loyalty = 100
	assert(world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": 81, "parents": [origin]}))
	var establishments: Dictionary = {}
	for id: String in ["CULT-TX-A", "CULT-TX-B"]:
		establishments[id] = world._record("cult_established", "DOMAIN-001", actor, [actor], [origin], {"cult": id, "authorization": origin})
	tx = Transaction.new(world, {})
	tx.touch_world(["cults", "economy"])
	var valid_alone: bool = true
	for id: String in establishments:
		tx.candidate.cults.clear()
		tx.candidate.economy.remainders.clear()
		tx.candidate.economy.remainders[id] = 0
		tx.candidate.cults[id] = {"id": id, "domain": "DOMAIN-001", "leader": actor, "cohesion": 80, "status": "active", "origin": establishments[id], "established_turn": 0, "established_source": establishments[id], "strategy": "hold", "succession_source": establishments[id]}
		valid_alone = valid_alone and tx.validate_world().is_empty()
	tx.candidate.cults["CULT-TX-A"] = tx.candidate.cults["CULT-TX-B"].duplicate(true)
	tx.candidate.cults["CULT-TX-A"].id = "CULT-TX-A"
	tx.candidate.cults["CULT-TX-A"].origin = establishments["CULT-TX-A"]
	tx.candidate.cults["CULT-TX-A"].established_source = establishments["CULT-TX-A"]
	tx.candidate.cults["CULT-TX-A"].succession_source = establishments["CULT-TX-A"]
	tx.candidate.economy.remainders["CULT-TX-A"] = 0
	invalid = tx.validate_world()
	_check("TX-010", "各自合法的同域教团合并后唯一归属冲突被拒绝", valid_alone and not invalid.is_empty() and world.state.cults.is_empty(), {"errors": invalid})

func _views() -> void:
	var world: RefCounted = _world()
	var before: String = world.snapshot()
	var view: RefCounted = StateView.new(world.state, {}, 17)
	var fact_id: String = world.state.domains["DOMAIN-001"].origin
	var record: Variant = view.fact(fact_id)
	var page: Dictionary = view.query("npcs", [], 2)
	var bad: Dictionary = view.query("facts", [], 24)
	var unknown: Dictionary = view.query("undeclared", [], 24)
	var oversized: Dictionary = view.query("npcs", [], 65)
	var scope: Dictionary = view.participant("test", "actions", ["history"])
	var npc: Dictionary = view.entity("npcs", world.state.npcs.keys()[0])
	var isolated: bool = record.ok and npc.ok
	if isolated:
		record.item.changes["injected"] = true
		npc.item.relations.clear()
	isolated = isolated and before == world.snapshot()
	_check("TX-011", "按ID事实读取与有限分页隔离嵌套数据，完整历史、超页及未知范围拒绝", isolated and page.ok and page.items.size() == 2 and page.cursor == 2 and not page.complete and page.version == 17 and not bad.ok and not unknown.ok and not oversized.ok and not scope.ok and not npc.item.has("known_facts") and view.metrics.facts == 1 and view.metrics.pages == 1 and view.metrics.objects == 3, {"metrics": view.metrics.duplicate(), "historicalFacts": world.state.facts.size()})
	var projected: Dictionary = view.participant("test", "actions")
	_check("TX-013", "当前参与者投影不携带历史全集或旧回执，仅按声明读取", projected.ok and projected.world.facts.is_empty() and not projected.world.npcs.values()[0].has("known_facts") and not projected.turn.has("receipts") and not projected.turn.has("journal") and view.metrics.facts == 1, {"historicalFacts": world.state.facts.size(), "projectedFacts": projected.world.facts.size()})

func _load_audit() -> void:
	var data: Dictionary = _setup()
	_open(data)
	assert(data.turn.submit(_request(data, "act", "paid")).ok)
	var before: String = data.turn.snapshot()
	var encoded: Dictionary = JSON.parse_string(before)
	var world_body: Dictionary = JSON.parse_string(encoded.body.world)
	var origin: String = world_body.body.state.domains["DOMAIN-001"].origin
	world_body.body.state.facts[origin].causal_parents = [origin]
	world_body.checksum = World.canonical(World._normalize_numbers(world_body.body)).sha256_text()
	encoded.body.world = World.canonical(world_body)
	encoded.checksum = World.canonical(World._normalize_numbers(encoded.body)).sha256_text()
	var restored: bool = data.turn.restore(World.canonical(encoded))
	_check("TX-012", "读档全量审计拒绝重签校验和的旧事实自引用，保留当前会话", not restored and before == data.turn.snapshot())
	data.adapter.captured_turn = null

func _hot_path() -> void:
	var world: RefCounted = ObservedWorld.new(catalog)
	assert(world.generate(7919))
	var turn: RefCounted = Turn.new(world)
	var adapter: RefCounted = Adapter.new()
	adapter.captured_world = world
	adapter.captured_turn = turn
	assert(turn.register_participant("tx-fixture", "1", Turn.SLOTS, Turn.EFFECTS, adapter.handle, adapter.preview))
	var data: Dictionary = {"world": world, "turn": turn, "adapter": adapter}
	_open(data)
	var old_sequence: int = int(JSON.parse_string(turn.snapshot()).body.get("commit_sequence", -1))
	world.snapshot_calls = 0
	world.audit_calls = 0
	var request: Dictionary = _request(data, "act", "paid")
	var result: Dictionary = turn.submit(request)
	var preview: Dictionary = turn.preview_plan("tx-fixture", {})
	var hot_snapshots: int = world.snapshot_calls
	var hot_audits: int = world.audit_calls
	_check("TX-014", "普通行动与预览不调用整世界序列化或全历史语义审计", result.ok and preview.ok and hot_snapshots == 0 and hot_audits == 0, {"snapshotCalls": hot_snapshots, "fullAuditCalls": hot_audits})
	var published: int = int(JSON.parse_string(turn.snapshot()).body.get("commit_sequence", -1))
	var replayed: Dictionary = turn.submit(request)
	var bad: Dictionary = turn.submit(_request(data, "act", "batch"))
	var after: int = int(JSON.parse_string(turn.snapshot()).body.get("commit_sequence", -1))
	_check("TX-015", "成功事务仅发布一次序号，预览、重复请求与失败不发布", old_sequence >= 0 and published == old_sequence + 1 and replayed.ok and not bad.ok and after == published, {"before": old_sequence, "afterSuccessfulAction": published, "afterRetryAndFailure": after})
	var before: String = turn.snapshot()
	var corrupted_action: Dictionary = turn.submit(_request(data, "act", "captured_sequence"))
	var action_blocked: bool = not corrupted_action.ok and turn.snapshot() == before
	adapter.mode = "preview_sequence"
	var corrupted_preview: Dictionary = turn.preview_plan("tx-fixture", {})
	_check("TX-020", "参与者与预览不能污染提交序号并制造不可恢复存档", action_blocked and not corrupted_preview.ok and turn.snapshot() == before and turn.restore(before) and turn.snapshot() == before, {"actionRejected": action_blocked, "previewRejected": not corrupted_preview.ok})
	adapter.captured_turn = null

func _adoption() -> void:
	var data: Dictionary = _setup()
	_open(data)
	var next: Dictionary = data.world.state.duplicate(true)
	var origin: String = next.domains["DOMAIN-001"].origin
	next.facts[origin].causal_parents = [origin]
	Transaction.freeze(next)
	data.world.state = next
	var before: String = data.turn.snapshot()
	var result: Dictionary = data.turn.submit(_request(data, "act", "paid"))
	var world_rejected: bool = not result.ok and before == data.turn.snapshot()
	var world_error: String = result.get("error", "")
	data.adapter.captured_turn = null
	data = _setup()
	_open(data)
	var paid: Dictionary = _request(data, "act", "paid")
	assert(data.turn.submit(paid).ok)
	var original_context: Dictionary = data.turn.context
	var forged_context: Dictionary = original_context.duplicate(true)
	forged_context.receipts[paid.id].response.result.outcome = "forged_receipt"
	forged_context.receipts[paid.id].fingerprint = World.canonical(paid).sha256_text()
	Transaction.freeze(forged_context)
	data.turn.context = forged_context
	before = data.turn.snapshot()
	result = data.turn.submit(paid.duplicate(true))
	var forged_rejected: bool = not result.ok and before == data.turn.snapshot()
	var malformed_context: Dictionary = original_context.duplicate(true)
	malformed_context.receipts = []
	data.turn.context = malformed_context
	before = data.turn.snapshot()
	result = data.turn.submit(paid.duplicate(true))
	var malformed_rejected: bool = not result.ok and before == data.turn.snapshot()
	_check("TX-017", "陌生根须先完整审计；旧事实、伪造重复回执和错误回执类型不能绕过", world_rejected and forged_rejected and malformed_rejected, {"worldRejection": world_error, "forgedDuplicateReceiptRejected": forged_rejected, "nonDictionaryReceiptsRejected": malformed_rejected})
	data.adapter.captured_turn = null
	data = _setup()
	var nested: Dictionary = data.world.state.npcs.values()[0]
	var nested_array: Array = nested.relations
	data.world.state.make_read_only()
	data.turn.context.make_read_only()
	result = data.turn.submit(_request(data, "advance"))
	_check("TX-018", "浅只读新根首次接管后递归冻结原始嵌套引用", result.ok and nested.is_read_only() and nested_array.is_read_only(), {"npcFrozen": nested.is_read_only(), "relationsFrozen": nested_array.is_read_only()})
	data.adapter.captured_turn = null
