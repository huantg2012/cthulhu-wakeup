extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const Economy = preload("res://src/game/economy.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
class RejectWorld extends "res://src/simulation/world.gd":
	var reject_evolution: bool = false
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var result: Array[String] = super.validate_increment(candidate, trusted)
		if reject_evolution and candidate.phase == "between": result.append("Injected final merge rejection")
		return result
class Consumer extends RefCounted:
	var reject_deadline: bool = false
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": view.participant_state}
		if input.slot == "events" and input.operation == "gather": result.events = []
		if input.slot == "deadlines" and reject_deadline: result.ok = false
		if input.slot == "actions":
			var source: String = str(input.payload.get("source", view.world.domains["DOMAIN-001"].origin))
			result.meta = {"faith_cost": 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": source, "outcome": "candidate_protocol_fixture", "responds": false, "used_power": false, "used_relic": false}
			if input.action == "kill": result.effects.append({"type": "world_command", "source": source, "command": {"kind": "status", "npc": input.payload.actor, "status": "dead", "parents": [source]}})
			if input.action in ["authorize_successor", "successor", "replay_successor"]:
				var authorization: String = str(input.payload.get("authorization", "FACT-%08d" % int(view.world.next_fact)))
				if input.action == "authorize_successor": result.effects.append({"type": "fact", "source": source, "kind": "background_successor_authorized", "domain": input.payload.domain, "actor": "", "targets": input.payload.actors, "observers": [], "institutions": [], "details": {"parent": source, "snapshot_version": view.version}})
				if input.action != "authorize_successor": result.effects.append({"type": "world_command", "source": source, "command": {"kind": "background_successor", "authorization": authorization, "parents": [source, authorization]}})
			result.empty = result.effects.is_empty()
		return result
var catalog: RefCounted
var records: Array = []
var request_sequence: int = 0
var scratch: String
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("cthulhu-abstract-" + str(Time.get_ticks_usec()))
	_bootstrap()
	_routine()
	_actors()
	_risk()
	_source_rules()
	_capacity()
	_lifecycle()
	_rollback()
	_identity()
	_successor()
	_determinism()
	_economy()
	_pool_full()
	_shared_sources()
	_bad_saves()
	_reader()
	_stream_order()
	var ok: bool = true
	for check: Dictionary in records: ok = ok and check.status == "pass"
	var output: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	output.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records}, "\t", true, true)); output.close()
	quit(0 if ok else 1)
func _check(id: String, name: String, ok: bool, details: Dictionary = {}) -> void:
	records.append({"id": id, "name": name, "status": "pass" if ok else "fail", "details": details})
	print("PASS " if ok else "FAIL ", id, " ", name, " ", details)
func _world(seed_value: int = 7919) -> RefCounted:
	var world: RefCounted = RejectWorld.new(catalog)
	assert(world.generate(seed_value))
	return world
func _attach(world: RefCounted, economy: RefCounted = null) -> Dictionary:
	var turn: RefCounted = Turn.new(world)
	var consumer: RefCounted = Consumer.new()
	if economy != null: assert(economy.install(turn))
	var slots: Array = ["events", "actions", "deadlines", "ending"] if economy != null else ["events", "actions", "prepay", "income", "deadlines", "ending"]
	assert(turn.register_participant("abstract-fixture", "1", slots, ["world_command", "fact"], consumer.handle))
	return {"world": world, "turn": turn, "consumer": consumer}
func _setup(bootstrap: bool = false, seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = _world(seed_value)
	assert(world.configure_assigned_simulation(["DOMAIN-001"], [], [], "DOMAIN-002" if bootstrap else ""))
	return _attach(world)
func _submit(data: Dictionary, op: String, payload: Dictionary = {}) -> Dictionary:
	request_sequence += 1
	var request: Dictionary = {"id": "ABS-" + str(request_sequence), "op": op, "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	request.merge(payload)
	var result: Dictionary = data.turn.submit(request)
	if not result.ok: print("REQUEST_REJECTED ", op, " ", result)
	return result
func _open(data: Dictionary) -> bool:
	return _submit(data, "advance").ok and _submit(data, "finish_events").ok
func _evolve(data: Dictionary) -> bool:
	return _submit(data, "end_actions").ok and _submit(data, "advance").ok
func _finish(data: Dictionary) -> bool:
	return _submit(data, "advance").ok and _submit(data, "advance").ok
func _round(data: Dictionary) -> bool:
	return _open(data) and _evolve(data) and _finish(data)
func _facts(world: RefCounted, kind: String) -> Array:
	return Store.values(world.state.facts).filter(func(fact: Dictionary) -> bool: return fact.kind == kind)
func _bootstrap() -> void:
	var world: RefCounted = _world()
	var before: int = world.state.domains["DOMAIN-002"].unnamed_nonfollowers
	var count: int = Store.size(world.state.npcs)
	var enabled: bool = world.configure_assigned_simulation(["DOMAIN-001"], [], [], "DOMAIN-002")
	var sim: Dictionary = world.state.simulation
	var card: Dictionary = sim.candidates.values()[0]
	var person: Dictionary = Store.entry(world.state.npcs, card.actors[0])
	_check("ABS-001", "正式模板与独立策略可用；bootstrap原子扣人口、保留持久身份和当前来源", enabled and not world.abstract_sim.version.is_empty() and sim.bootstrap and card.visible_turn == 1 and card.due_turn == int(world.abstract_sim.templates[card.template].lifetime) and world.state.domains[card.domain].unnamed_nonfollowers == before - 1 and Store.size(world.state.npcs) == count + 1 and person.relations.is_empty() and world.validate_state(world.state).is_empty(), {"candidate": card.id, "actor": person.id, "policy": sim.policy})
	var data: Dictionary = _attach(world)
	var saved: String = data.turn.snapshot()
	_check("ABS-002", "固定候选读取不抽样；阶段二只读已固化记录", data.turn.fixed_background_candidates().is_empty() and _open(data) and data.turn.fixed_background_candidates().size() == 1 and data.turn.fixed_background_candidates()[0] == card and saved != data.turn.snapshot() and not world.configure_assigned_simulation([]))
func _routine() -> void:
	var world: RefCounted = _world()
	for id: String in ["DOMAIN-001", "DOMAIN-002"]:
		world.state.domains[id].pollution = 10; world.state.domains[id].barrier = 40
	assert(world.configure_assigned_simulation(["DOMAIN-001"]))
	world.state.simulation.cursors["DOMAIN-002"].next_turn = 1
	world.state.simulation.cursors["DOMAIN-001"].next_turn = 1
	var data: Dictionary = _attach(world)
	var ok: bool = _round(data)
	var first: int = world.state.domains["DOMAIN-002"].pollution
	ok = _round(data) and ok
	_check("ABS-003", "重点逐轮与后台低频日常择一；不补算漏过轮数且不随机漂移稳定", ok and first == 10 - catalog.integer("pollution_base_decay") and world.state.domains["DOMAIN-002"].pollution == first and world.state.domains["DOMAIN-001"].pollution == 10 - 2 * catalog.integer("pollution_base_decay") and world.state.simulation.cursors["DOMAIN-002"].next_turn == 5 and world.state.simulation.cursors["DOMAIN-001"].next_turn == 5, {"focusedPollution": world.state.domains["DOMAIN-001"].pollution, "backgroundPollution": world.state.domains["DOMAIN-002"].pollution})
func _actors() -> void:
	var world: RefCounted = _world()
	var actors: Array = [world.state.institutions["DOMAIN-002/order"].representative, world.state.institutions["DOMAIN-003/order"].representative]
	for actor: String in actors:
		Store.entry(world.state.npcs, actor).sanity = 1
		world.introduce_fact("strain", Store.entry(world.state.npcs, actor).domain, actor, [actor], [Store.entry(world.state.npcs, actor).status_source], {"sanity": 1}, [actor])
	assert(world.configure_assigned_simulation(["DOMAIN-001"], [actors[0]]))
	var data: Dictionary = _attach(world)
	var ok: bool = _round(data)
	_check("ABS-004", "后台必要详细主体照常真实行动，普通后台人物保持属性与历史不逐人演化", ok and Store.entry(world.state.npcs, actors[0]).sanity > 1 and Store.entry(world.state.npcs, actors[1]).sanity == 1, {"selectedSanity": Store.entry(world.state.npcs, actors[0]).sanity, "unselectedSanity": Store.entry(world.state.npcs, actors[1]).sanity})
func _risk() -> void:
	var world: RefCounted = _world()
	var domain: String = "DOMAIN-002"
	var actor: String = world.state.institutions[domain + "/propagation"].representative
	var origin: String = world.state.domains[domain].origin
	world.state.domains[domain].alert = 100
	world.introduce_fact("exposure", domain, actor, [actor], [origin], {"public": true}, [], [domain + "/order"])
	assert(world.configure_assigned_simulation(["DOMAIN-001"]))
	var data: Dictionary = _attach(world)
	var ok: bool = _round(data)
	var plan: Dictionary = world.state.domains[domain].pending_plan.duplicate(true)
	while data.turn.context.turn < int(plan.get("due", 1)): ok = _round(data) and ok
	_check("ABS-005", "后台未确认暴露仍发动预告查证并按原期限结算，未依赖匿名侦探", ok and plan.get("rule") == "RESIST_TRACE" and _facts(world, "resistance_resolved").any(func(fact: Dictionary) -> bool: return fact.domain == domain and fact.changes.rule == "RESIST_TRACE"), {"announced": plan})
	world = _world()
	world.state.domains[domain].barrier = 0; world.state.domains[domain].alert = 100
	world.state.institutions[domain + "/order"].representative = ""
	world.state.institutions[domain + "/order"]["occupancy"] = "occupied_abstract"
	assert(world.configure_assigned_simulation(["DOMAIN-001"]))
	var anonymous: bool = world._institution_operational(world.state, domain + "/order")
	world.state.institutions[domain + "/order"].occupancy = "vacant"
	_check("ABS-006", "匿名在任与真实空缺不同；空缺/失能机构不获得宏观新计划资格", anonymous and not world._institution_operational(world.state, domain + "/order") and world.choose_plan(domain).is_empty())
func _source_rules() -> void:
	var data: Dictionary = _setup()
	var world: RefCounted = data.world
	var view: Dictionary = world._background_snapshot(world._evolution_snapshot())
	var rule: Dictionary = world.abstract_sim.templates["BG_RECORD"]
	var silent: bool = world.abstract_sim.proposal(view, "DOMAIN-002", rule).is_empty()
	var before: String = data.turn.snapshot()
	var no_random: bool = before == data.turn.snapshot()
	_check("ABS-007", "无真实知情来源时历史回调保持静默，不倒造证言、亲属或神迹", silent and no_random)
func _capacity() -> void:
	var world: RefCounted = _world()
	# This case tests a new nominee at full P, not reuse of a practicing keeper
	# already in P. Exclude that separate valid current-ritual branch in this
	# explicit initial situation; CONTACT/ESCAPE nomination remains enabled.
	for person: Dictionary in Store.values(world.state.npcs):
		if person.domain == "DOMAIN-002": person.role_tags.erase("ritual_keeper")
	var before: String = world.snapshot()
	var temporary: Array = Store.keys(world.state.npcs).slice(0, world.abstract_sim.parameters.temporary_actor_limit)
	var rejected: bool = not world.configure_assigned_simulation(["DOMAIN-001"], [], temporary, "DOMAIN-002")
	_check("ABS-008", "bootstrap主体容量不足整体撤回，人口/ID/事实/RNG无半笔", rejected and before == world.snapshot())
func _lifecycle() -> void:
	var data: Dictionary = _setup(true)
	var card: Dictionary = data.world.state.simulation.candidates.values()[0]
	var same: bool = _open(data)
	var snapshot: String = data.turn.snapshot()
	for ignored: int in 3: same = data.turn.fixed_background_candidates()[0] == card and data.turn.snapshot() == snapshot and same
	var path: String = scratch.path_join("roundtrip")
	same = data.turn.save_archive(path) and same
	var restored: Dictionary = _setup(true)
	same = restored.turn.load_archive(path) and restored.turn.snapshot() == snapshot and same
	_check("ABS-009", "固定人物/来源/期限及域RNG完整存档恢复；反复读取零状态变化", same)
	var ok: bool = _evolve(data) and _finish(data)
	while data.turn.context.turn < card.due_turn: ok = _round(data) and ok
	var expired: Array = _facts(data.world, "background_expired").filter(func(fact: Dictionary) -> bool: return fact.changes.candidate == card.id)
	_check("ABS-010", "未展示/未选择的请求仍在固定阶段五到期，默认后果只执行一次且释放引用", ok and expired.size() == 1 and expired[0].turn == card.due_turn and not data.world.state.simulation.candidates.has(card.id) and not data.world.state.simulation.holds.get(card.actors[0], []).has(card.id), {"due": card.due_turn, "expiredCount": expired.size()})
func _rollback() -> void:
	var data: Dictionary = _setup()
	assert(_open(data)); assert(_submit(data, "end_actions").ok)
	var snapshot: String = data.turn.snapshot()
	data.world.reject_evolution = true
	var rejected: bool = not _submit(data, "advance").ok
	data.world.reject_evolution = false
	var control: Dictionary = _setup()
	assert(control.turn.restore(snapshot))
	var request: Dictionary = {"id": "ABS-EXACT-RETRY", "op": "advance", "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	var same: bool = data.turn.snapshot() == snapshot
	var a: Dictionary = data.turn.submit(request); var b: Dictionary = control.turn.submit(request)
	_check("ABS-011", "阶段四最终拒绝回滚日常/提名/游标/事实/随机；重试与未失败会话一致", rejected and same and a.ok and a == b and data.turn.snapshot() == control.turn.snapshot())
	data = _setup(true)
	var due: int = data.world.state.simulation.candidates.values()[0].due_turn
	while data.turn.context.turn < due - 1: assert(_round(data))
	assert(_open(data) and _evolve(data))
	data.consumer.reject_deadline = true
	snapshot = data.turn.snapshot()
	rejected = not _submit(data, "advance").ok
	_check("ABS-012", "期限消费者失败时整阶段五撤回，之前成功阶段及固定请求保持", rejected and data.turn.snapshot() == snapshot)
func _identity() -> void:
	var data: Dictionary = _setup(true)
	var card: Dictionary = data.world.state.simulation.candidates.values()[0]
	assert(_open(data))
	var killed: Dictionary = _submit(data, "act", {"participant": "abstract-fixture", "action": "kill", "payload": {"actor": card.actors[0], "source": card.fact}})
	var invisible: bool = data.turn.fixed_background_candidates().is_empty()
	var ok: bool = _evolve(data) and _finish(data)
	_check("ABS-013", "固定主体死亡优先；旧候选取消而不重定向到随机活人或延长期限", killed.ok and invisible and ok and not data.world.state.simulation.candidates.has(card.id) and _facts(data.world, "background_cancelled").any(func(fact: Dictionary) -> bool: return fact.changes.candidate == card.id))
func _successor() -> void:
	var data: Dictionary = _setup(true)
	var parent: Dictionary = data.world.state.simulation.candidates.values()[0]
	assert(_open(data))
	var next_fact: String = "FACT-%08d" % int(data.world.state.next_fact)
	var request: Dictionary = {"participant": "abstract-fixture", "action": "authorize_successor", "payload": {"source": parent.fact, "domain": parent.domain, "actors": parent.actors}}
	assert(_submit(data, "act", request).ok)
	next_fact = _facts(data.world, "background_successor_authorized")[-1].id
	request.action = "successor"; request.payload.authorization = next_fact
	var result: Dictionary = _submit(data, "act", request)
	var cards: Array = data.world.state.simulation.candidates.values()
	var continued: bool = result.ok and cards.size() >= 1 and not data.world.state.simulation.candidates.has(parent.id)
	var before: String = data.turn.snapshot()
	var retry: Dictionary = _submit(data, "act", {"participant": "abstract-fixture", "action": "replay_successor", "payload": {"source": parent.fact, "authorization": next_fact}})
	var no_rewrite: bool = retry.ok and World.canonical(data.world.state.simulation.candidates) == World.canonical(cards.reduce(func(acc: Dictionary, card: Dictionary) -> Dictionary: acc[card.id] = card; return acc, {}))
	_check("ABS-014", "阶段二/三确定性后继沿原主体和来源，授权只消费一次且不重抽后台流", continued and no_rewrite and cards[0].actors == parent.actors and cards[0].visible_turn == data.turn.context.turn + 1, {"response": result, "retry": retry, "receiptAdded": before != data.turn.snapshot()})
func _determinism() -> void:
	var first: Dictionary = _setup(true, 1981)
	var second: Dictionary = _setup(true, 1981)
	var same: bool = true
	var steps: int = 0
	for ignored: int in 8:
		for op: String in ["advance", "finish_events", "end_actions", "advance", "advance", "advance"]:
			steps += 1
			var request: Dictionary = {"id": "DETERMINISTIC-" + str(steps), "op": op, "turn": first.turn.context.turn, "phase": first.turn.context.phase}
			same = first.turn.submit(request) == second.turn.submit(request) and first.turn.snapshot() == second.turn.snapshot() and same
	_check("ABS-015", "混合分配连续八轮48阶段逐请求确定重放，详细/概略共用准确结算", same, {"checkpoints": steps, "candidates": first.world.state.simulation.candidates.size()})
func _economy() -> void:
	var world: RefCounted = _world()
	var economy: RefCounted = Economy.new(catalog, {"abstract-fixture": "1"})
	assert(economy.initialize(world))
	var domain: String = "DOMAIN-002"
	var origin: String = world.state.domains[domain].origin
	var leader: String = world.state.institutions[domain + "/propagation"].representative
	Store.entry(world.state.npcs, leader).loyalty = 100
	assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [origin], {"issuer": "abstract-fixture", "version": "1", "cult": "CULT-ABS", "domain": domain, "leader": leader, "cohesion": 80}, [])
	assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
	assert(world.configure_assigned_simulation(["DOMAIN-001"], [leader]))
	var data: Dictionary = _attach(world, economy)
	var ok: bool = _open(data) and _evolve(data)
	var request: Dictionary = {"id": "ECON-EXACT", "op": "advance", "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	var settled: Dictionary = data.turn.submit(request)
	var before: String = data.turn.snapshot()
	_check("ABS-016", "后台教团仍由唯一正式经济生产者结算；同请求不重复收入或人口", ok and settled.ok and data.turn.submit(request) == settled and data.turn.snapshot() == before and world.validate_state(world.state).is_empty(), {"faith": world.state.faith, "population": world.state.domains[domain].population})
func _pool_full() -> void:
	var world: RefCounted = _world()
	assert(world.configure_assigned_simulation(["DOMAIN-001"]))
	for index: int in world.abstract_sim.parameters.pending_candidate_limit:
		var view: Dictionary = world._background_snapshot(world._evolution_snapshot())
		var proposal: Dictionary = world.abstract_sim.proposal(view, "DOMAIN-002", world.abstract_sim.templates["BG_CONTACT"])
		proposal.once_key += "/fixture/" + str(index); proposal.sample_before = "0"; proposal.sample_after = "0"
		assert(world._fix_background(proposal, 1))
	world.state.domains["DOMAIN-002"].pollution = 10; world.state.simulation.cursors["DOMAIN-002"].next_turn = 1
	var rng: String = world.state.simulation.cursors["DOMAIN-002"].state
	var data: Dictionary = _attach(world)
	var ok: bool = _round(data)
	_check("ABS-017", "固定池满不挤掉旧承诺、不补抽；后台日常和风险职责仍推进", ok and world.state.simulation.candidates.size() == world.abstract_sim.parameters.pending_candidate_limit and world.state.simulation.cursors["DOMAIN-002"].state == rng and world.state.simulation.cursors["DOMAIN-002"].next_turn == 5 and world.state.domains["DOMAIN-002"].pollution == 10 - catalog.integer("pollution_base_decay"))

func _shared_sources() -> void:
	var world: RefCounted = _world()
	var actor: String = world.state.institutions["DOMAIN-002/interpretation"].representative
	var source: String = world.introduce_fact("exposure", "DOMAIN-002", actor, [actor], [world.state.domains["DOMAIN-002"].origin], {"public": true}, [actor], ["DOMAIN-002/interpretation"])
	assert(world.configure_assigned_simulation(["DOMAIN-001"]))
	var view: Dictionary = world._background_snapshot(world._evolution_snapshot())
	var proposal: Dictionary = world.abstract_sim.proposal(view, "DOMAIN-002", world.abstract_sim.templates["BG_RECORD"])
	proposal.sample_before = "0"; proposal.sample_after = "0"
	var first: bool = world._fix_background(proposal, 1)
	proposal.once_key += "/second"
	var second: bool = world._fix_background(proposal, 1)
	var cards: Array = world.state.simulation.candidates.values()
	world._close_background(cards[0], "cancelled")
	_check("ABS-018", "真实已知暴露可固化历史回调；两候选共享同一主体，关闭一项不释放另一项引用", first and second and proposal.actors == [actor] and source in cards[0].source_ids and world.state.simulation.holds[actor] == [cards[1].id] and world.validate_state(world.state).is_empty())
func _bad_saves() -> void:
	var data: Dictionary = _setup(true)
	var target: Dictionary = _setup()
	var before: String = target.turn.snapshot()
	var envelope: Dictionary = JSON.parse_string(data.world.snapshot())
	envelope.body.state.erase("simulation")
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var missing: bool = not target.world.restore(World.canonical(envelope), target.turn) and target.turn.snapshot() == before
	envelope = JSON.parse_string(data.world.snapshot())
	envelope.body.state.simulation.policy = "unknown-policy"
	envelope.body.simulation_policy = "unknown-policy"
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var incompatible: bool = not target.world.restore(World.canonical(envelope), target.turn) and target.turn.snapshot() == before
	envelope = JSON.parse_string(data.world.snapshot())
	var card: Dictionary = envelope.body.state.simulation.candidates.values()[0]
	card.due_turn += 1
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var deadline: bool = not target.world.restore(World.canonical(envelope), target.turn) and target.turn.snapshot() == before
	envelope = JSON.parse_string(data.world.snapshot())
	envelope.body.state.facts[card.fact].changes = []
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var malformed: bool = not target.world.restore(World.canonical(envelope), target.turn) and target.turn.snapshot() == before
	_check("ABS-019", "重签校验和不能隐藏模式、换策略、重置期限或插入坏事实结构；失败保留原会话", missing and incompatible and deadline and malformed)
func _reader() -> void:
	var data: Dictionary = _setup(true)
	assert(_open(data))
	var before: String = data.turn.snapshot()
	var reader: RefCounted = preload("res://src/simulation/state_view.gd").new(data.world.state, data.turn.context, data.turn.commit_sequence, data.world.history)
	var result: Dictionary = reader.background_candidates()
	var original: Array = data.turn.fixed_background_candidates()
	if not result.items.is_empty(): result.items[0].due_turn += 100
	reader.close()
	_check("ABS-020", "候选消费者只获本轮冻结副本，改副本不污染期限，过期reader拒绝复用", result.ok and original.size() == 1 and data.turn.fixed_background_candidates() == original and data.turn.snapshot() == before and not reader.background_candidates().ok)
func _stream_order() -> void:
	var data: Dictionary = _setup()
	var view: Dictionary = data.world._background_snapshot(data.world._evolution_snapshot())
	var ids: Array = view.domains.keys(); ids.sort()
	var reversed: Array = ids.duplicate(); reversed.reverse()
	var before: String = data.turn.snapshot()
	var first: Dictionary = data.world.abstract_sim.propose(view, ids)
	var second: Dictionary = data.world.abstract_sim.propose(view, reversed)
	_check("ABS-021", "每域稳定派生流与遍历/页面顺序无关，纯提议不改变世界、人口或随机", first == second and before == data.turn.snapshot() and view.simulation.cursors[ids[0]].seed != view.simulation.cursors[ids[1]].seed)
