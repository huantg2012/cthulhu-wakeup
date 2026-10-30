extends "res://tools/attention/run.gd"
const Cults = preload("res://src/game/cults.gd")
# Upstream events supply actual payments / identity facts, not cult outcomes.
class Fixture extends RefCounted:
	var cost: int = 0
	var domain: String = "DOMAIN-001"
	var gather: Array = []
	var deadlines: Array = []
	var fault: bool = false
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
		var source: String = view.world.domains[domain].origin
		if input.slot == "events" and input.operation == "gather":
			result.events = [{"id": "payment", "default_action": "ignore", "source": source, "payload": {}}] if cost > 0 else []
			result.effects = gather.duplicate(true)
		elif input.operation == "resolve_event":
			result.meta = {"faith_cost": cost if input.action == "pay" else 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": source, "target": domain, "outcome": "upstream_payment_contract", "responds": false, "used_power": false, "used_relic": false, "attention": {"family": "system", "content_id": "REST", "variant": "use"}}
		elif input.slot == "deadlines":
			result.effects = deadlines.duplicate(true)
			result.ok = not fault
		elif input.operation == "due": result.effects = input.payload.effects.duplicate(true)
		result.empty = result.effects.is_empty()
		return result
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	_thresholds()
	_spending()
	_income()
	_succession()
	_temporary()
	_dormancy()
	_zero_and_rebuild()
	_appointment()
	_cancel()
	_members()
	_capacity()
	_persistence()
	_guardian()
	_background()
	_order()
	_corruption()
	_automatic_capacity()
	_focus_capacity()
	_detailed_and_economy()
	_payment_corruption()
	_appointment_conflict()
	var ok: bool = true
	for row: Dictionary in records: ok = ok and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records}, "\t", true, true)); file.close()
	quit(0 if ok else 1)
func _prepare(existing: bool = false, followers: int = 81, cohesion: int = 80, hybrid: bool = true) -> Dictionary:
	var world: RefCounted = _new_hybrid() if hybrid else World.new(catalog)
	if not hybrid: assert(world.generate(7919))
	for person: Dictionary in Store.values(world.state.npcs): world.mutable_npc(person.id).loyalty = 0
	var leader: String = world.state.institutions["DOMAIN-001/propagation"].representative
	var source: String = _dedicate(world, leader)
	var economy: RefCounted = Economy.new(catalog, {"cult-fixture": "1"}); assert(economy.initialize(world))
	var origin: String = world.state.domains["DOMAIN-001"].origin
	if followers > 0: assert(world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": followers, "parents": [origin]}))
	if existing:
		if hybrid: _bind(world, leader)
		var authorization: String = world.introduce_fact("cult_establishment_authorized", "DOMAIN-001", leader, [leader], [origin], {"issuer": "cult-fixture", "version": "1", "cult": "CULT-EXISTING", "domain": "DOMAIN-001", "leader": leader, "cohesion": cohesion}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
	world.state.turn = 0; world.state.phase = "between"
	if hybrid: world.attention.sync(world)
	return {"world": world, "economy": economy, "leader": leader, "source": source, "cult": "CULT-EXISTING"}
func _attach_cults(data: Dictionary) -> Dictionary:
	var turn: RefCounted = Turn.new(data.world)
	assert(data.economy.install(turn))
	var fixture: RefCounted = Fixture.new()
	assert(turn.register_participant("cult-fixture", "1", ["events", "deadlines", "ending"], ["fact", "world_command", "resource", "schedule"], fixture.handle))
	var cults: RefCounted = Cults.new(catalog); assert(cults.install(turn))
	data.turn = turn; data.fixture = fixture; data.cults = cults
	return data
func _action(data: Dictionary, action: String, payload: Dictionary) -> Dictionary:
	return _submit(data, "act", {"participant": "cults", "action": action, "payload": payload})
func _paid_open(data: Dictionary, cost: int) -> bool:
	data.fixture.cost = cost
	if not _submit(data, "advance").ok: return false
	if cost > 0 and not _submit(data, "resolve_event", {"event": "payment", "action": "pay"}).ok: return false
	data.fixture.cost = 0
	return _submit(data, "finish_events").ok
func _status(data: Dictionary, person: String, status: String) -> Dictionary:
	return {"type": "world_command", "source": data.source, "command": {"kind": "status", "npc": person, "status": status, "parents": [data.source]}}
func _population(data: Dictionary, mode: String, amount: int) -> Dictionary:
	return {"type": "world_command", "source": data.source, "command": {"kind": "population", "domain": "DOMAIN-001", "mode": mode, "amount": amount, "parents": [data.source]}}
func _new_candidate(data: Dictionary, influence: int = 5, loyalty: int = 100, bind: bool = false) -> String:
	var id: String = _extra(data.world, 1)[0] if data.world.attention.enabled(data.world.state) else Store.keys(data.world.state.npcs).filter(func(p: String) -> bool: return p != data.leader and Store.entry(data.world.state.npcs, p).domain == "DOMAIN-001")[0]
	_dedicate(data.world, id)
	data.world.mutable_npc(id).influence = influence; data.world.mutable_npc(id).loyalty = loyalty
	if bind: _bind(data.world, id)
	return id
func _thresholds() -> void:
	var cases: Array = []
	for variant: int in 4:
		var data: Dictionary = _prepare(false, 5 if variant == 1 else 6)
		if variant == 2: data.world.mutable_npc(data.leader).loyalty = 39
		_attach_cults(data)
		var cost: int = 7 if variant == 0 else 8
		var valid: bool = _paid_open(data, cost) and _evolve(data) and _finish(data)
		cases.append(valid and data.world.state.cults.size() == (1 if variant == 3 else 0))
	_check("CUL-001", "实付/信众/忠诚三门槛分别差一不成立，全满足自然成立且不再收费", not false in cases, {"cases": cases})
func _spending() -> void:
	var data: Dictionary = _attach_cults(_prepare())
	data.fixture.cost = 8
	assert(_submit(data, "advance").ok)
	var before: String = data.turn.snapshot()
	data.fixture.cost = 999
	var rejected: bool = not _submit(data, "resolve_event", {"event": "payment", "action": "pay"}).ok and before == data.turn.snapshot()
	data.fixture.cost = 8
	var faith: int = data.world.state.faith
	assert(_submit(data, "resolve_event", {"event": "payment", "action": "pay"}).ok)
	var spend: int = data.world.state.cult_system.spend["DOMAIN-001"].amount
	var source: String = data.world.state.cult_system.spend["DOMAIN-001"].source
	var fact: Dictionary = Store.entry(data.world.state.facts, source)
	_check("CUL-002", "实际支付有本域有源增量记账，拒绝事务不记款且不变世界/随机", rejected and spend == 8 and data.world.state.faith == faith - 8 and not fact.causal_parents.is_empty() and data.world.state.cult_system.spend.get("DOMAIN-002", {}).get("amount", 0) == 0)
func _income() -> void:
	var data: Dictionary = _attach_cults(_prepare())
	assert(_paid_open(data, 8) and _evolve(data) and _finish(data))
	var cult: Dictionary = data.world.state.cults.values()[0]
	var origin: String = cult.origin
	var born: int = cult.established_turn
	var before: int = data.world.state.faith
	assert(_round(data))
	_check("CUL-003", "自然建团不增人口/成员重复扣额，次轮才产正式经济收入", born == 1 and int(cult.cohesion) == catalog.integer("cult_initial_cohesion") and data.world.state.faith > before and data.world.state.cults[cult.id].origin == origin and _facts(data.world, "cult_established").size() == 1 and Store.entry(data.world.state.npcs, cult.leader).cult_id == cult.id)
func _succession() -> void:
	var data: Dictionary = _prepare(true)
	var candidate: String = _new_candidate(data)
	_attach_cults(data)
	assert(_open(data))
	data.fixture.deadlines = [_status(data, data.leader, "dead")]
	assert(_evolve(data) and _finish(data))
	var cohesion: int = data.world.state.cults[data.cult].cohesion
	data.fixture.deadlines = []
	assert(_open(data))
	var succeeded: bool = data.world.state.cults[data.cult].leader == candidate and data.world.state.cults[data.cult].cohesion == cohesion - catalog.integer("cult_succession_cohesion_cost")
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("CUL-004", "领袖死亡先失效，下轮真实继任且凝聚只扣一次，人口只死亡一次", succeeded and data.world.state.cults[data.cult].cohesion == cohesion - catalog.integer("cult_succession_cohesion_cost") and _facts(data.world, "cult_succeeded").size() == 1 and data.world.state.domains["DOMAIN-001"].population == 999 and Store.entry(data.world.state.npcs, candidate).cult_id == data.cult)
func _temporary() -> void:
	var data: Dictionary = _prepare(true); _new_candidate(data)
	_attach_cults(data); assert(_open(data))
	data.fixture.deadlines = [_status(data, data.leader, "detained")]
	assert(_evolve(data) and _finish(data)); data.fixture.deadlines = []
	assert(_open(data))
	var paused: bool = data.world.state.cults[data.cult].leader == data.leader and data.world.state.cults[data.cult].status == "dormant"
	data.fixture.deadlines = [_status(data, data.leader, "active")]
	assert(_evolve(data) and _finish(data)); data.fixture.deadlines = []
	assert(_open(data))
	_check("CUL-005", "拘禁保留名义领袖不抢继任，归来可合法恢复，活人口不变", paused and data.world.state.cults[data.cult].leader == data.leader and data.world.state.cults[data.cult].status == "active" and data.world.state.domains["DOMAIN-001"].population == 1000 and _facts(data.world, "cult_succeeded").is_empty())
func _dormancy() -> void:
	var data: Dictionary = _attach_cults(_prepare(true))
	assert(_open(data)); data.fixture.deadlines = [_status(data, data.leader, "dead")]
	assert(_evolve(data) and _finish(data)); data.fixture.deadlines = []
	var states: Array = [data.world.state.cults[data.cult].status]
	for i: int in 2:
		assert(_round(data)); states.append(data.world.state.cults[data.cult].status)
	_check("CUL-006", "连续三个完整休眠轮后覆灭，历史/人物/圣物不被伪造或清除", states == ["dormant", "dormant", "destroyed"] and _facts(data.world, "cult_destroyed").size() == 1 and Store.has(data.world.state.npcs, data.leader) and Store.size(data.world.state.relics) == 0, {"states": states})
func _zero_and_rebuild() -> void:
	var data: Dictionary = _attach_cults(_prepare(true, 81))
	assert(_open(data)); data.fixture.deadlines = [_population(data, "leave", 81)]
	assert(_evolve(data) and _finish(data)); data.fixture.deadlines = []
	var origin: String = data.world.state.cults[data.cult].origin
	var destroyed: bool = data.world.state.cults[data.cult].status == "destroyed"
	data.fixture.gather = [_population(data, "convert", 81)]
	assert(_paid_open(data, 8)); data.fixture.gather = []
	assert(_evolve(data) and _finish(data))
	var cult: Dictionary = data.world.state.cults[data.cult]
	_check("CUL-007", "零信众当轮覆灭，重建保留原ID/origin并更新收入窗口，不发圣物", destroyed and cult.status == "active" and cult.origin == origin and cult.established_turn == 2 and data.world.state.cults.size() == 1 and Store.size(data.world.state.relics) == 0)
func _appointment() -> void:
	var data: Dictionary = _prepare(true); var candidate: String = _new_candidate(data)
	_attach_cults(data); assert(_open(data))
	var faith: int = data.world.state.faith; var whispers: int = data.world.state.whispers
	var acted: int = Store.entry(data.world.state.npcs, candidate).acted_turn
	assert(_action(data, "appoint", {"npc": candidate, "cult": data.cult, "role": "leader", "source": data.source}).ok)
	var old: bool = data.world.state.cults[data.cult].leader == data.leader
	var paid: bool = data.world.state.faith == faith - 2 and data.world.state.whispers == whispers - 1
	var opportunity: bool = Store.entry(data.world.state.npcs, candidate).acted_turn == acted
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("CUL-008", "真实任命按CSV确定付费，下轮生效且撤换扣凝聚，不吞/刷新执行机会", old and paid and opportunity and data.world.state.cults[data.cult].leader == candidate and data.world.state.cults[data.cult].cohesion == 75 and Store.entry(data.world.state.npcs, candidate).cult_id == data.cult)
func _cancel() -> void:
	var data: Dictionary = _prepare(true); var candidate: String = _new_candidate(data)
	_attach_cults(data); assert(_open(data))
	assert(_action(data, "appoint", {"npc": candidate, "cult": data.cult, "role": "leader", "source": data.source}).ok)
	data.fixture.deadlines = [_status(data, candidate, "dead")]
	assert(_evolve(data) and _finish(data)); data.fixture.deadlines = []
	assert(_open(data))
	_check("CUL-009", "任命固定主体死亡取消，不换人不返费且不扣撤换凝聚", data.world.state.cults[data.cult].leader == data.leader and data.world.state.cults[data.cult].cohesion == 80 and data.turn.context.queued.is_empty())
func _members() -> void:
	var data: Dictionary = _prepare(true); var candidate: String = _new_candidate(data)
	var willing: String = Store.entry(data.world.state.npcs, candidate).dedication_source
	var leave_source: String = data.world.introduce_fact("member_leave_authorized", "DOMAIN-001", candidate, [candidate], [willing], {}, [candidate])
	_attach_cults(data); assert(_open(data))
	var people: int = data.world.state.attention.living_count
	assert(_action(data, "enroll", {"npc": candidate, "source": willing, "cult": data.cult}).ok)
	var joined: bool = Store.entry(data.world.state.npcs, candidate).bound_member and Store.entry(data.world.state.npcs, candidate).cult_id == data.cult
	assert(_action(data, "leave", {"npc": candidate, "source": leave_source}).ok)
	var before: String = data.turn.snapshot()
	var stale: bool = not _action(data, "enroll", {"npc": candidate, "source": willing, "cult": data.cult}).ok
	_check("CUL-010", "正式成员入口P→N/离团复用统一协议，旧献身不能自动重入且人口不复制", joined and stale and before == data.turn.snapshot() and not Store.entry(data.world.state.npcs, candidate).bound_member and data.world.state.attention.living_count == people)
func _capacity() -> void:
	var data: Dictionary = _prepare(true); var candidate: String = _new_candidate(data)
	var others: Array = _extra(data.world, 12)
	for i: int in 11: _bind(data.world, others[i])
	_attach_cults(data); assert(_open(data))
	var before: String = data.turn.snapshot()
	var denied: bool = not _action(data, "appoint", {"npc": candidate, "cult": data.cult, "role": "leader", "source": data.source}).ok
	_check("CUL-011", "N满的真实任命在扣费和预留前拒绝，回执/随机/世界不变", denied and before == data.turn.snapshot())
	data = _prepare(true); candidate = _new_candidate(data)
	_attach_cults(data); assert(_open(data))
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-002"}).ok and _control(data, {"kind": "focus", "domain": "DOMAIN-003"}).ok)
	# Existing source domain is focused: invalid cross-domain target still cannot pay.
	before = data.turn.snapshot()
	var bad: bool = not _action(data, "appoint", {"npc": candidate, "cult": data.cult, "role": "guardian", "anchor": "unknown", "source": data.source}).ok
	_check("CUL-012", "无合法既有锚点/职位请求明确拒绝且不支付，F满不隐藏资格失败", bad and before == data.turn.snapshot())
func _persistence() -> void:
	var data: Dictionary = _prepare(true); var candidate: String = _new_candidate(data)
	_attach_cults(data); assert(_open(data))
	assert(_action(data, "appoint", {"npc": candidate, "cult": data.cult, "role": "leader", "source": data.source}).ok)
	var pending: String = data.turn.snapshot()
	var restored: Dictionary = _prepare(true); _new_candidate(restored); _attach_cults(restored)
	var saved: bool = data.turn.save_archive(scratch.path_join("appointment"))
	var loaded: bool = restored.turn.load_archive(scratch.path_join("appointment"))
	var equal: bool = saved and loaded and restored.turn.snapshot() == pending
	if equal:
		assert(_evolve(data) and _finish(data) and _open(data))
		# Same request IDs from the committed journal are replayed to restored session.
		var receipts: Array = Store.values(data.turn.context.receipts)
		receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.request.id).trim_prefix("ABS-").to_int() < str(b.request.id).trim_prefix("ABS-").to_int())
		for receipt: Dictionary in receipts:
			if not Store.has(restored.turn.context.receipts, receipt.request.id):
				var response: Dictionary = restored.turn.submit(receipt.request)
				equal = equal and response.ok
		equal = equal and restored.turn.snapshot() == data.turn.snapshot()
	_check("CUL-013", "未来任命持久令牌与支付投影分段保存，恢复同请求续跑完全一致", equal)
	data = _attach_cults(_prepare(true)); assert(_open(data) and _evolve(data))
	data.fixture.fault = true
	var before: String = data.turn.snapshot()
	var rejected: bool = not _submit(data, "advance").ok
	data.fixture.fault = false
	_check("CUL-014", "收入/期限组合失败整阶段回滚，生命周期与支付投影无半笔，重试成功", rejected and before == data.turn.snapshot() and _finish(data))
func _guardian() -> void:
	# Existing anchor structure is an explicit upstream fixture, creation remains ANCHORS.
	var data: Dictionary = _prepare(true)
	var candidate: String = _new_candidate(data)
	var relic: String = "RELIC-CULT"; var anchor: String = "ANCHOR-CULT"
	Store.put(data.world.state.relics, relic, {"id": relic, "domain": "DOMAIN-001", "placement": "bound", "holder": "", "anchor": anchor})
	data.world.state.anchors[anchor] = {"id": anchor, "domain": "DOMAIN-001", "institution": "DOMAIN-001/interpretation", "guardian": data.leader, "relic": relic, "state": "dormant", "needs_rebind": false, "origin": data.source, "ordinal": 1, "cult": data.cult}
	_attach_cults(data); assert(_open(data))
	assert(_action(data, "appoint", {"npc": candidate, "cult": data.cult, "role": "guardian", "anchor": anchor, "source": data.source}).ok)
	# Explicitly refuse supply: changed guardian must not gain unpaid contribution.
	assert(_submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": [anchor]}}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("CUL-015", "正式护持任命下轮换既有锚点主体，拒供状态不免费激活", data.world.state.anchors[anchor].guardian == candidate and data.world.state.anchors[anchor].state == "dormant")
func _background() -> void:
	var data: Dictionary = _prepare(false)
	var person: String = _new_candidate(data)
	# Move a real identity to a legal background neighbor before attaching a driver.
	var domain: String = data.world.state.domains["DOMAIN-001"].neighbors[0]
	assert(data.world.submit({"kind": "migrate", "npc": person, "domain": domain, "parents": [data.source]}))
	_dedicate(data.world, person)
	assert(data.world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [data.source]}))
	_attach_cults(data); data.fixture.domain = domain
	var focus: Array = data.world.state.simulation.focused.duplicate()
	assert(_paid_open(data, 8) and _evolve(data) and _submit(data, "advance").ok)
	# Stage-five background candidate fixation is independent of cult formation.
	# Isolate the actual cult_end boundary rather than count it as a cult-created NPC.
	var living: int = data.world.state.attention.living_count
	assert(_submit(data, "advance").ok)
	var matches: Array = data.world.state.cults.values().filter(func(c: Dictionary) -> bool: return c.domain == domain)
	_check("CUL-016", "非重点域自然建团使用现存身份，不抢F/展开匿名机构/复制居民", matches.size() == 1 and matches[0].leader == person and data.world.state.simulation.focused == focus and data.world.state.attention.living_count == living, {"matches": matches, "focus_before": focus, "focus_after": data.world.state.simulation.focused, "living_before": living, "living_after": data.world.state.attention.living_count, "person": person, "domain": domain})
func _order() -> void:
	var first: Dictionary = _prepare(); var second: Dictionary = _prepare()
	var a: String = _new_candidate(first, 5, 100); var b: String = _new_candidate(second, 5, 100)
	assert(a == b)
	var reversed: Dictionary = {}
	var keys: Array = second.world.state.domains.keys(); keys.reverse()
	for key: String in keys: reversed[key] = second.world.state.domains[key]
	second.world.state.domains = reversed
	_attach_cults(first); _attach_cults(second)
	assert(_paid_open(first, 8) and _evolve(first) and _finish(first))
	assert(_paid_open(second, 8) and _evolve(second) and _finish(second))
	_check("CUL-017", "相同局势反转域遍历顺序，候选排序和成立事实/随机完全一致", World.canonical(first.world.state) == World.canonical(second.world.state) and first.world.state.cults.values()[0].leader == a)
func _corruption() -> void:
	var data: Dictionary = _attach_cults(_prepare(true)); assert(_open(data))
	var before: String = data.turn.snapshot()
	var envelope: Dictionary = JSON.parse_string(before)
	# Snapshot envelope is checksummed; corrupt state while recomputing only checksum.
	if envelope.has("body"):
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		world_envelope.body.state.cult_system.schema = 99
		world_envelope.checksum = World.canonical(world_envelope.body).sha256_text()
		envelope.body.world = World.canonical(world_envelope)
		envelope.checksum = World.canonical(envelope.body).sha256_text()
	var bad: bool = not data.turn.restore(World.canonical(envelope))
	_check("CUL-018", "非法生命周期schema保存即使校验和正确也拒绝，原会话不污染", bad and before == data.turn.snapshot())

func _automatic_capacity() -> void:
	var cases: Array = []
	for fallback: bool in [false, true]:
		var data: Dictionary = _prepare(false)
		data.world.mutable_npc(data.leader).influence = 5
		var members: Array = _extra(data.world, 12)
		for person: String in members:
			_bind(data.world, person); data.world.mutable_npc(person).loyalty = 0
		if fallback:
			data.world.mutable_npc(members[0]).loyalty = 100
			data.world.mutable_npc(members[0]).influence = 1
		_attach_cults(data)
		assert(_paid_open(data, 8) and _evolve(data) and _finish(data))
		cases.append(data.world.state.cults.is_empty() if not fallback else data.world.state.cults.values()[0].leader == members[0])
	_check("CUL-019", "自动建团N满延期；首选缺额时仍可选低排名已有成员，不额外占F/N", not false in cases, {"cases": cases})
func _focus_capacity() -> void:
	var data: Dictionary = _prepare(true)
	var person: String = _new_candidate(data, 5, 100, true)
	_attach_cults(data); assert(_open(data))
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-001"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	for domain: String in ["DOMAIN-002", "DOMAIN-003", "DOMAIN-004"]:
		assert(_control(data, {"kind": "focus", "domain": domain}).ok)
	var before: String = data.turn.snapshot()
	var rejected: bool = not _action(data, "appoint", {"npc": person, "cult": data.cult, "role": "leader", "source": data.source}).ok
	_check("CUL-020", "真实任命目标不在已满F时付费前拒绝，即使人物已有N", rejected and before == data.turn.snapshot())

func _detailed_and_economy() -> void:
	var data: Dictionary = _attach_cults(_prepare(true, 81, 80, false))
	assert(_round(data))
	_check("CUL-021", "正式全详细路径安装Cults后保留合法原领袖与经济，不另启活动预算", data.world.state.cults[data.cult].leader == data.leader and data.world.state.cults[data.cult].status == "active" and not data.world.state.has("attention") and Store.entry(data.world.state.npcs, data.leader).bound_member)
	data = _prepare(true)
	assert(data.world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": data.cult, "institution": "DOMAIN-001/propagation", "allowed": true, "issuer": "cult-fixture", "version": "1", "parents": [data.world.state.cults[data.cult].established_source]}))
	_attach_cults(data); assert(_open(data))
	assert(_submit(data, "set_plan", {"participant": "economy", "payload": {"strategies": {data.cult: "expand"}}}).ok)
	assert(_evolve(data))
	var paid: int = data.world.state.cult_system.spend["DOMAIN-001"].amount
	assert(_finish(data))
	_check("CUL-022", "Economy实际传教费进入本域实付，未到收入与实际收入不算支出", paid == catalog.integer("expansion_faith_cost") and data.world.state.cult_system.spend["DOMAIN-001"].amount == paid and _facts(data.world, "economy_income").size() == 1)

func _rewrap_turn(envelope: Dictionary, world_envelope: Dictionary) -> String:
	world_envelope.checksum = World.canonical(world_envelope.body).sha256_text()
	envelope.body.world = World.canonical(world_envelope)
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	return World.canonical(envelope)
func _payment_corruption() -> void:
	var data: Dictionary = _attach_cults(_prepare())
	assert(_paid_open(data, 4) and _evolve(data) and _finish(data) and _paid_open(data, 4))
	var before: String = data.turn.snapshot()
	var cases: Array = []
	for duplicate: bool in [false, true]:
		var envelope: Dictionary = JSON.parse_string(before)
		var saved: Dictionary = JSON.parse_string(envelope.body.world)
		var state: Dictionary = saved.body.state
		var head: String = state.cult_system.spend["DOMAIN-001"].source
		var previous: String = state.facts[head].changes.previous
		if duplicate:
			var old_payment: String = state.facts[previous].changes.payment
			var current_payment: String = state.facts[head].changes.payment
			state.facts[head].changes.payment = old_payment
			state.facts[head].causal_parents.erase(current_payment)
			state.facts[head].causal_parents.append(old_payment)
			state.facts[head].causal_parents.sort()
		else:
			state.facts[previous].changes.previous_total += 100
			state.facts[previous].changes.total += 100
			state.facts[head].changes.previous_total += 100
			state.facts[head].changes.total += 100
			state.cult_system.spend["DOMAIN-001"].amount += 100
		var rejected: bool = not data.turn.restore(_rewrap_turn(envelope, saved))
		cases.append(rejected and before == data.turn.snapshot())
	_check("CUL-023", "正确双层校验和不能掩盖较早实付链伪造或同笔付款重复计入", not false in cases, {"cases": cases})
func _appointment_conflict() -> void:
	var data: Dictionary = _prepare(true)
	var first: String = _new_candidate(data)
	var second: String = _new_candidate(data)
	_attach_cults(data); assert(_open(data))
	var before: String = data.turn.snapshot()
	var nonsense: bool = not _action(data, "appoint", {"npc": first, "cult": data.cult, "role": "leader", "anchor": "arbitrary", "source": data.source}).ok and before == data.turn.snapshot()
	assert(_action(data, "appoint", {"npc": first, "cult": data.cult, "role": "leader", "source": data.source}).ok)
	before = data.turn.snapshot()
	var repeated: bool = not _action(data, "appoint", {"npc": second, "cult": data.cult, "role": "leader", "source": data.source}).ok and before == data.turn.snapshot()
	_check("CUL-024", "领袖任命拒绝伪锚点和同团重复待任职位，付费/预留均不重复", nonsense and repeated and data.turn.context.queued.size() == 1)
