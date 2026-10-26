extends "res://tools/abstract-sim/run.gd"
const Attention = preload("res://src/game/attention.gd")
class Participant extends RefCounted:
	var events: Array = []
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": view.participant_state}
		if input.slot == "events" and input.operation == "gather": result.events = events.duplicate(true)
		if input.operation == "due":
			var person: String = input.payload.npc
			result.effects = [{"type": "membership", "operation": "enroll", "npc": person, "source": input.source}]
			result.attention = {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [person], "nominees": [person], "source": input.source}
			result.empty = false
			if input.action == "death":
				result.effects = [{"type": "world_command", "source": input.source, "command": {"kind": "status", "npc": person, "status": "dead", "parents": [input.source]}}]
				result.erase("attention")
		if input.slot == "actions" or (input.slot == "events" and input.operation == "resolve_event"):
			var payload: Dictionary = input.payload
			var source: String = payload.get("source", view.world.domains["DOMAIN-001"].origin)
			result.meta = {"faith_cost": payload.get("cost", 0), "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": source, "outcome": "attention_contract_fixture", "responds": false, "used_power": false, "used_relic": false, "attention": payload.get("admission", {"family": "system", "content_id": "REST", "variant": "use"})}
			result.effects = payload.get("effects", []).duplicate(true)
			if input.action == "missing": result.meta.erase("attention")
			result.empty = result.effects.is_empty()
		return result
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("cthulhu-attention-" + str(Time.get_ticks_usec()))
	_opening()
	_focus_limits()
	_classification()
	_membership()
	_retirement()
	_promises()
	_local_and_identity()
	_persistence()
	_economy_focus()
	_project_focus()
	_branch_and_identity()
	_background_member()
	_failure_and_retry()
	_corrupt_claims()
	_current_round_marks()
	_current_dedication()
	_due_identity_priority()
	_nested_and_duplicate_projects()
	_conversion_keeps_project_references()
	var ok: bool = true
	for record: Dictionary in records: ok = ok and record.status == "pass"
	var output: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	output.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records}, "\t", true, true)); output.close()
	quit(0 if ok else 1)
func _new_hybrid(seed_value: int = 7919) -> RefCounted:
	var world: RefCounted = World.new(catalog)
	assert(world.generate_hybrid(seed_value))
	return world
func _session(world: RefCounted, economy: RefCounted = null) -> Dictionary:
	var turn: RefCounted = Turn.new(world)
	var agent: RefCounted = Participant.new()
	if economy != null: assert(economy.install(turn))
	var slots: Array = ["events", "actions", "start", "deadlines", "ending"] if economy != null else ["events", "actions", "start", "prepay", "income", "deadlines", "ending"]
	assert(turn.register_participant("attention-fixture", "1", slots, ["fact", "world_command", "check", "membership", "schedule", "wounds"], agent.handle))
	return {"world": world, "turn": turn, "agent": agent}
func _control(data: Dictionary, command: Dictionary) -> Dictionary:
	return _submit(data, "attention", {"command": command})
func _act(data: Dictionary, admission: Dictionary, effects: Array = [], extra: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {"admission": admission, "effects": effects}; payload.merge(extra)
	return _submit(data, "act", {"participant": "attention-fixture", "action": "contract", "payload": payload})
func _extra(world: RefCounted, count: int) -> Array:
	var ids: Array = []
	for i: int in count:
		var id: String = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-001"].origin))
		ids.append(id)
	world.attention.sync(world)
	return ids
func _dedicate(world: RefCounted, id: String) -> String:
	world.mutable_npc(id).loyalty = 100
	return world.introduce_fact("member_dedication", Store.entry(world.state.npcs, id).domain, id, [id], [Store.entry(world.state.npcs, id).status_source], {}, [id])
func _bind(world: RefCounted, id: String) -> void:
	var source: String = _dedicate(world, id)
	var needs: Dictionary = {"focus": [], "people": [id], "members": [id], "identities": [], "source": source}
	var reservation: Dictionary = world.attention.reserve(world, needs)
	assert(reservation.ok and world.attention.enroll(world, id, source, reservation.token))
	world.attention.finish(world, reservation.token)
	world.introduce_fact("member_leave_authorized", Store.entry(world.state.npcs, id).domain, id, [id], [Store.entry(world.state.npcs, id).binding_source], {}, [id])
func _leave_source(world: RefCounted, id: String) -> String:
	return _facts(world, "member_leave_authorized").filter(func(fact: Dictionary) -> bool: return id in fact.targets)[-1].id
func _opening() -> void:
	var world: RefCounted = _new_hybrid()
	var background_named: int = 0
	for person: Dictionary in Store.values(world.state.npcs):
		if not person.domain in world.state.simulation.focused: background_named += 1
	_check("ATT-001", "实际混合开局仅提名重点本地及初始接触，不先生成全居民；人口与模式可审计", world.state.simulation.mode == "hybrid" and world.state.simulation.schema == 2 and background_named == 0 and world.state.attention.living_count == int(world.attention.parameters.local_actor_limit) + 1 and world.validate_state(world.state).is_empty(), {"living": world.state.attention.living_count, "backgroundNamed": background_named})
	_check("ATT-002", "后台机构匿名在任可做宏观风险；首次重点化使用当前提名而非旧见闻", world.state.institutions["DOMAIN-002/order"].occupancy == "occupied_abstract" and world._institution_operational(world.state, "DOMAIN-002/order"))
func _focus_limits() -> void:
	var data: Dictionary = _session(_new_hybrid())
	assert(_open(data))
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.turn.preview_attention({"kind": "focus", "domain": "DOMAIN-002"})
	var pure: bool = before == data.turn.snapshot()
	var first: bool = _control(data, {"kind": "focus", "domain": "DOMAIN-002"}).ok
	var second: bool = _control(data, {"kind": "focus", "domain": "DOMAIN-003"}).ok
	var rng: String = World.canonical(data.world.state.simulation.cursors)
	var release: bool = _control(data, {"kind": "release_focus", "domain": "DOMAIN-002"}).ok
	before = data.turn.snapshot()
	var blocked: bool = not _control(data, {"kind": "focus", "domain": "DOMAIN-004"}).ok
	_check("ATT-003", "同一预览/执行谓词；撤关注本轮不腾位，满F拒绝且不改变状态或随机", preview.ok and preview.needs.budgets.focus.limit == int(data.world.attention.parameters.focused_domain_limit) and pure and first and second and release and blocked and before == data.turn.snapshot() and rng == World.canonical(data.world.state.simulation.cursors))
	assert(_evolve(data) and _finish(data))
	assert(_open(data))
	_check("ATT-004", "下轮身份/期限整理后释放关注；不重置原域人物、游标与冷却", not "DOMAIN-002" in data.world.state.simulation.focused and _control(data, {"kind": "focus", "domain": "DOMAIN-004"}).ok and data.world.state.institutions["DOMAIN-002/order"].representative != "")
func _classification() -> void:
	var data: Dictionary = _session(_new_hybrid())
	assert(_open(data))
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-002"}).ok)
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-003"}).ok)
	var before: String = data.turn.snapshot()
	var deep: Dictionary = {"family": "prayer", "content_id": "PRAYER_01", "variant": "deep", "target": "DOMAIN-004"}
	var blocked: bool = not _act(data, deep, [], {"cost": 1}).ok
	var shallow: Dictionary = {"family": "prayer", "content_id": "PRAYER_09", "variant": "shallow", "target": "DOMAIN-004"}
	blocked = not _act(data, shallow, [], {"cost": 1}).ok and blocked
	_check("ATT-005", "一次性深污染与PRAYER_09浅破屏障同样需F，满额在扣费前拒绝", blocked and before == data.turn.snapshot())
	var missing: Dictionary = _submit(data, "act", {"participant": "attention-fixture", "action": "missing", "payload": {}})
	var unknown: Dictionary = _act(data, {"family": "prayer", "content_id": "PRAYER_UNKNOWN", "variant": "deep"})
	var malformed: Dictionary = _act(data, {"family": "system", "content_id": "REST", "variant": "use", "persistent": "yes"})
	_check("ATT-006", "缺失/错误/未登记分类默认拒绝，不回退为无需关注", not missing.ok and not unknown.ok and not malformed.ok and before == data.turn.snapshot())
	var needs: Dictionary = data.world.attention.preview_needs(data.world.state, {"family": "power", "content_id": "POWER_TRANSFER", "variant": "use", "source_domain": "DOMAIN-002", "target": "DOMAIN-004"})
	_check("ATT-007", "双域迁引与事件调用权能按实际依赖并集预留，不只计算名义目标", not needs.ok and not data.world.attention.preview_needs(data.world.state, {"family": "event", "content_id": "EVENT_12", "variant": "B", "candidate": "bad", "fixed": [], "calls": [{"family": "power", "content_id": "POWER_MANIFEST", "variant": "use", "ritual_domains": ["DOMAIN-004"]}]}).ok)
func _membership() -> void:
	var world: RefCounted = _new_hybrid()
	var actor: String = world.state.simulation.candidates.values()[0].actors[0]
	var source: String = _dedicate(world, actor)
	var data: Dictionary = _session(world); assert(_open(data))
	_check("ATT-008", "忠诚达标不自动入团；自愿申请还需真实献身来源与可达当前身份", not Store.entry(world.state.npcs, actor).bound_member and not data.turn.preview_attention({"kind": "enroll", "npc": actor, "source": world.state.domains["DOMAIN-001"].origin}).ok)
	var joined: bool = _control(data, {"kind": "enroll", "npc": actor, "source": source}).ok
	_check("ATT-009", "同一人物P→N原子转换，共享候选仍持引用但不再占P", joined and Store.entry(world.state.npcs, actor).bound_member and actor in world.state.simulation.persistent and not actor in world.attention.occupied(world.state, "people") and world.state.simulation.holds.has(actor))
	world = _new_hybrid(); var extras: Array = _extra(world, 14)
	for id: String in extras.slice(0, 12): _bind(world, id)
	var applicant: String = extras[12]; _dedicate(world, applicant)
	data = _session(world); assert(_open(data))
	var origin: String = world.state.domains["DOMAIN-001"].origin
	var branch: Array = [{"type": "membership", "operation": "enroll", "npc": applicant, "source": origin}]
	var check: Dictionary = {"type": "check", "source": origin, "npc": applicant, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": branch, "success": branch, "failure": [], "disaster": []}}
	var before: String = data.turn.snapshot()
	var request: Dictionary = {"family": "prayer", "content_id": "PRAYER_08", "variant": "deep", "target": "DOMAIN-001", "participants": [applicant]}
	_check("ATT-010", "随机分支可能入团时在付费/投骰前取得最大N，满员不吞已付结果", not _act(data, request, [check], {"cost": 1}).ok and data.turn.snapshot() == before)
	var left: bool = _control(data, {"kind": "leave", "npc": extras[0], "source": _leave_source(world, extras[0])}).ok
	before = data.turn.snapshot()
	_check("ATT-011", "本轮离团/死亡占用记号保留，不能反复招入换人绕过N", left and not _control(data, {"kind": "enroll", "npc": applicant, "source": _facts(world, "member_dedication")[-1].id}).ok and before == data.turn.snapshot())
func _retirement() -> void:
	var world: RefCounted = _new_hybrid(); var extras: Array = _extra(world, 26)
	for id: String in extras.slice(0, 12): _bind(world, id)
	var member: String = extras[0]
	var exposure: String = world.introduce_fact("exposure", "DOMAIN-001", member, [member], [world.state.domains["DOMAIN-001"].origin], {"public": true}, [member])
	for i: int in 2:
		var proposal: Dictionary = {"object": "DOMAIN-001", "template": "BG_RECORD", "source_ids": [exposure], "actors": [member], "once_key": "retired/" + str(i), "snapshot_version": 0, "sample_before": "0", "sample_after": "0"}
		assert(world._fix_background(proposal, 1))
	var people: Array = extras.slice(12, 23) # 11 + the initial non-member contact = 12 P.
	var promise: Dictionary = world.attention.reserve(world, {"focus": [], "people": people, "members": [], "identities": [], "source": exposure}, true)
	assert(promise.ok)
	var card: Dictionary = world.state.simulation.candidates.values().filter(func(item: Dictionary) -> bool: return item.actors == [member])[0]
	var data: Dictionary = _session(world)
	data.agent.events = [{"id": "LEAVE-DEFAULT", "default_action": "leave", "source": card.fact, "payload": {"source": card.fact, "admission": {"family": "event", "content_id": "EVENT_12", "variant": "B", "candidate": card.id, "fixed": card.actors}, "effects": [{"type": "membership", "operation": "leave", "npc": member, "source": card.fact}]}}]
	var ok: bool = _open(data)
	_check("ATT-012", "N/P双满默认离团立即失权，多互动引用转原N退役保护而不阻塞", ok and not Store.entry(world.state.npcs, member).bound_member and world.state.attention.retired.has(member) and world.attention.occupied(world.state, "members").size() == 12 and world.state.simulation.holds[member].size() == 2)
	data.agent.events = []
	assert(_control(data, {"kind": "release_project", "token": promise.token}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("ATT-013", "轮初有P空间时退役N→P原子转换，保持原ID及所有引用", not world.state.attention.retired.has(member) and member in world.attention.occupied(world.state, "people") and world.state.simulation.holds[member].size() == 2 and not member in world.attention.occupied(world.state, "members"))
func _promises() -> void:
	var world: RefCounted = _new_hybrid(); var extras: Array = _extra(world, 13)
	for id: String in extras.slice(0, 11): _bind(world, id)
	var applicant: String = extras[11]; _dedicate(world, applicant)
	var data: Dictionary = _session(world); assert(_open(data))
	var source: String = world.state.domains["DOMAIN-001"].origin
	var policy: Dictionary = {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [applicant], "nominees": [applicant], "persistent": true}
	var job: Dictionary = {"id": "PROMISED-JOIN", "due": 2, "phase": "start", "action": "join", "payload": {"npc": applicant}, "source": source}
	var promised: bool = _act(data, policy, [{"type": "schedule", "job": job}]).ok
	var before: String = data.turn.snapshot()
	var other: String = extras[12]
	var denied: bool = not _act(data, {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [other], "nominees": [other]}, []).ok
	_check("ATT-014", "未来入团在承诺时持有指定N，其他申请不能偷占", promised and denied and before == data.turn.snapshot() and world.attention.occupied(world.state, "members").size() == 12)
	var ok: bool = _evolve(data) and _finish(data) and _open(data)
	_check("ATT-015", "既有到期消费者使用原预留入团，结清后释放工程令牌且只生效一次", ok and Store.entry(world.state.npcs, applicant).bound_member and world.state.attention.reservations.is_empty() and Store.has(data.turn.context.completed_jobs, "PROMISED-JOIN"))
func _local_and_identity() -> void:
	var data: Dictionary = _session(_new_hybrid()); assert(_open(data))
	var before: Dictionary = data.world.state.simulation.cursors.duplicate(true)
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-002"}).ok)
	var ids: Array = data.world.attention.detailed_ids(data.world.state)
	var source: String = data.world.state.domains["DOMAIN-002"].origin
	_check("ATT-016", "展开本地L有预算、优先真实机构代表；新人物只知当前提名，不倒造旧见证", data.world.state.attention.local["DOMAIN-002"].size() == 6 and ids.size() <= 42 and data.world.state.simulation.cursors == before and data.world.state.institutions["DOMAIN-002/order"].representative != "")
	var id: String = data.world.state.institutions["DOMAIN-002/order"].representative
	var before_person: String = World.canonical(Store.entry(data.world.state.npcs, id))
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-002"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	var stats: int = data.world.stats.npc_updates
	assert(_evolve(data) and _finish(data))
	_check("ATT-017", "退回后台保留原身份/属性/历史，详细集合不递归展开亲友", Store.has(data.world.state.npcs, id) and not id in data.world.attention.detailed_ids(data.world.state) and data.world.stats.npc_updates - stats <= 42, {"beforePersonBytes": before_person.length(), "updates": data.world.stats.npc_updates - stats})
func _persistence() -> void:
	var data: Dictionary = _session(_new_hybrid()); assert(_open(data))
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-002"}).ok)
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-002"}).ok)
	var before: String = data.turn.snapshot(); var path: String = scratch.path_join("save")
	var saved: bool = data.turn.save_archive(path)
	var restored: Dictionary = _session(_new_hybrid())
	_check("ATT-018", "混合模式的预算/释放/候选/随机同序分段恢复，未知策略不猜测迁移", saved and restored.turn.load_archive(path) and restored.turn.snapshot() == before)
	var bad: Dictionary = JSON.parse_string(data.world.snapshot())
	bad.body.state.attention.policy = "unknown"; bad.body.attention_policy = "unknown"; bad.checksum = World.canonical(bad.body).sha256_text()
	before = restored.turn.snapshot()
	_check("ATT-019", "重签校验和不能绕过准入策略版本，坏恢复保持原会话", not restored.world.restore(World.canonical(bad), restored.turn) and before == restored.turn.snapshot())
func _economy_focus() -> void:
	var world: RefCounted = _new_hybrid()
	var economy: RefCounted = Economy.new(catalog, {"attention-fixture": "1"}); assert(economy.initialize(world))
	# Explicit upstream fixtures: complete founding and propagation proofs are
	# still TASK-CULTS/POWERS; these are authoritative, sourced test boundaries.
	for domain: String in ["DOMAIN-001", "DOMAIN-002", "DOMAIN-003", "DOMAIN-004"]:
		if not domain in world.state.simulation.focused:
			world.state.simulation.focused = [domain]; world.expand_focused_domain(domain)
		var leader: String = world.state.institutions[domain + "/propagation"].representative
		_bind(world, leader)
		var origin: String = world.state.domains[domain].origin
		assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
		var cult: String = "CULT-" + domain
		var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [origin], {"issuer": "attention-fixture", "version": "1", "cult": cult, "domain": domain, "leader": leader, "cohesion": 80}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
		assert(world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": cult, "institution": domain + "/propagation", "allowed": true, "issuer": "attention-fixture", "version": "1", "parents": [authorization]}))
	world.state.simulation.focused = ["DOMAIN-001"]
	world.attention.sync(world)
	var data: Dictionary = _session(world, economy); assert(_open(data))
	var strategies: Dictionary = {}
	for cult: String in world.state.cults: strategies[cult] = "expand"
	var plan: Dictionary = {"strategies": strategies}
	var preview: Dictionary = data.turn.preview_plan(Economy.ID, plan)
	assert(_submit(data, "set_plan", {"participant": Economy.ID, "payload": plan}).ok)
	assert(_submit(data, "end_actions").ok)
	var refused: String = "CULT-DOMAIN-004"
	_check("ATT-020", "传教在锁定前按稳定教团ID取得F，满额转守持；预览和实际使用同一判断", preview.ok and data.turn.context.locked_plans[Economy.ID].strategies[refused] == "hold" and data.turn.context.attention_plan_reasons[refused] == "attention_focus_capacity" and world.state.simulation.focused.size() == 3)
	var detached: Dictionary = World._normalize_numbers(JSON.parse_string(World.canonical(world.state)))
	detached.npcs[detached.cults[refused].leader].bound_member = false
	var membership_required: bool = not Economy.operational_reason(detached, detached.cults[refused], catalog).is_empty()
	_check("ATT-021", "后台守持/敛藏/供奉不申请新F；高忠诚非成员不冒充领袖资格", _submit(data, "advance").ok and world.state.economy.effective[refused] == "hold" and membership_required)
	assert(_finish(data) and _open(data))
	var departed: String = world.state.cults["CULT-DOMAIN-001"].leader
	assert(_control(data, {"kind": "leave", "npc": departed, "source": _leave_source(world, departed)}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("ATT-032", "自动继任不能仅凭旧忠诚和离团前意愿把已离团者自动拉回", not Store.entry(world.state.npcs, departed).bound_member and world.state.cults["CULT-DOMAIN-001"].leader.is_empty())

func _project_focus() -> void:
	var world: RefCounted = _new_hybrid()
	var source: String = world.state.domains["DOMAIN-001"].origin
	var held: Dictionary = world.attention.reserve(world, {"focus": ["DOMAIN-002"], "people": [], "members": [], "identities": [], "source": source}, true)
	assert(held.ok)
	var data: Dictionary = _session(world); assert(_open(data))
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-002"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	var retained: bool = "DOMAIN-002" in world.state.simulation.focused
	assert(_control(data, {"kind": "release_project", "token": held.token}).ok)
	var still_this_round: bool = "DOMAIN-002" in world.state.simulation.focused
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("ATT-022", "跨轮工程持有F，撤关注不能丢工程；结束后仍按轮初释放", retained and still_this_round and not "DOMAIN-002" in world.state.simulation.focused)
func _branch_and_identity() -> void:
	var world: RefCounted = _new_hybrid()
	var person: String = world.state.simulation.candidates.values()[0].actors[0]
	var source: String = _dedicate(world, person)
	var data: Dictionary = _session(world); assert(_open(data))
	var grant: Array = [{"type": "membership", "operation": "enroll", "npc": person, "source": source}]
	var roll: Dictionary = {"type": "check", "source": source, "npc": person, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": grant, "success": grant, "failure": grant, "disaster": grant}}
	var joined: Dictionary = _act(data, {"family": "prayer", "content_id": "PRAYER_08", "variant": "deep", "target": "DOMAIN-001"}, [roll], {"source": source})
	_check("ATT-023", "检定所有分支共用预留，选中分支原子提交成员身份而非投骰后再申请", joined.ok and Store.entry(world.state.npcs, person).bound_member and world.state.attention.reservations.is_empty())
	var next: int = world.state.next_npc
	var key: String = "new:identity-fixture"
	var effect: Dictionary = {"type": "world_command", "source": source, "command": {"kind": "nominate", "domain": "DOMAIN-002", "profile": "NPC_PROFILE_01", "institution": "DOMAIN-002/interpretation", "group": "unnamed_nonfollowers", "parents": [source], "identity_key": key}}
	var policy: Dictionary = {"family": "power", "content_id": "POWER_SEED", "variant": "use", "target": "DOMAIN-002"}
	var nominated: Dictionary = _act(data, policy, [effect], {"source": source})
	var before: String = data.turn.snapshot()
	var duplicate: Dictionary = _act(data, policy, [effect], {"source": source, "cost": 1})
	_check("ATT-024", "未知身份先预留稳定键并原子换真实ID；已用键不能复用以绕人口或名额", nominated.ok and world.state.next_npc > next and Store.has(world.state.applied_authorizations, "identity/" + key) and not duplicate.ok and before == data.turn.snapshot())
func _background_member() -> void:
	var world: RefCounted = _new_hybrid()
	var person: String = world.state.institutions["DOMAIN-001/interpretation"].representative
	_bind(world, person)
	var data: Dictionary = _session(world); assert(_open(data))
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-002"}).ok)
	var old_id: String = world.state.institutions["DOMAIN-002/order"].representative
	var source: String = world.state.domains["DOMAIN-001"].origin
	var effect: Dictionary = {"type": "world_command", "source": source, "command": {"kind": "migrate", "npc": person, "domain": "DOMAIN-002", "parents": [source]}}
	var moved: Dictionary = _act(data, {"family": "power", "content_id": "POWER_TRANSFER", "variant": "use", "source_domain": "DOMAIN-001", "target": "DOMAIN-002"}, [effect])
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-002"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	var ids: Array = world.attention.detailed_ids(world.state)
	_check("ATT-025", "成员迁入后台仍持续详细，所在地不拉起整个域或关系链；原持久ID不变", moved.ok and Store.entry(world.state.npcs, person).domain == "DOMAIN-002" and person in ids and not old_id in ids and not "DOMAIN-002" in world.state.simulation.focused)
func _failure_and_retry() -> void:
	var data: Dictionary = _session(_new_hybrid()); assert(_open(data))
	assert(_control(data, {"kind": "focus", "domain": "DOMAIN-003"}).ok)
	var source: String = data.world.state.domains["DOMAIN-001"].origin
	var person: String = data.world.state.institutions["DOMAIN-001/order"].representative
	var before: String = data.turn.snapshot()
	var result: Dictionary = _act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "deep", "target": "DOMAIN-002"}, [{"type": "world_command", "source": source, "command": {"kind": "status", "npc": person, "status": "active", "parents": [source]}}], {"cost": 1})
	_check("ATT-026", "效果拒绝时新关注/展开人物/人口/预留/费用/随机一起回滚，先前成功关注保留", not result.ok and before == data.turn.snapshot() and "DOMAIN-003" in data.world.state.simulation.focused)
	var request: Dictionary = {"id": "ATT-EXACT", "op": "attention", "turn": data.turn.context.turn, "phase": data.turn.context.phase, "command": {"kind": "focus", "domain": "DOMAIN-002"}}
	var first: Dictionary = data.turn.submit(request)
	before = data.turn.snapshot()
	var same: bool = data.turn.submit(request) == first and before == data.turn.snapshot()
	request.command.domain = "DOMAIN-004"
	_check("ATT-027", "同请求重放不重复展开或占位，复用ID改目标拒绝", first.ok and same and not data.turn.submit(request).ok and before == data.turn.snapshot())
func _corrupt_claims() -> void:
	var world: RefCounted = _new_hybrid()
	var source: String = world.state.domains["DOMAIN-001"].origin
	var held: Dictionary = world.attention.reserve(world, {"focus": [], "people": ["new:future"], "members": [], "identities": ["new:future"], "source": source}, true)
	assert(held.ok)
	var data: Dictionary = _session(world)
	var original: String = data.world.snapshot()
	var before: String = data.turn.snapshot()
	var envelope: Dictionary = JSON.parse_string(original)
	envelope.body.state.attention.reservations[held.token].identities = [123]
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var bad_type: bool = not world.restore(World.canonical(envelope), data.turn) and before == data.turn.snapshot()
	envelope = JSON.parse_string(original)
	envelope.body.state.attention.next_reservation += 1
	envelope.body.state.attention.reservations["RESERVE-00000003"] = envelope.body.state.attention.reservations[held.token].duplicate(true)
	envelope.body.state.attention.next_reservation = 4
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	_check("ATT-028", "合法校验和也不能伪造预留类型或让多个预留重复认领同一未知身份", bad_type and not world.restore(World.canonical(envelope), data.turn) and before == data.turn.snapshot())

func _current_round_marks() -> void:
	var world: RefCounted = _new_hybrid()
	var ids: Array = world.history.ids("living").slice(0, 2)
	world.state.attention.used_p[ids[0]] = 0
	assert(world.prepare_turn())
	world.state.attention.used_p[ids[1]] = world.state.turn
	world.attention.round_start(world)
	_check("ATT-029", "轮初只回收旧轮标记，到期处理中本轮新增占用不能被清理掉", not world.state.attention.used_p.has(ids[0]) and world.state.attention.used_p.has(ids[1]))
func _current_dedication() -> void:
	var world: RefCounted = _new_hybrid()
	var id: String = world.state.simulation.candidates.values()[0].actors[0]
	_bind(world, id)
	var old_source: String = _facts(world, "member_dedication")[-1].id
	var data: Dictionary = _session(world); assert(_open(data))
	assert(_control(data, {"kind": "leave", "npc": id, "source": _leave_source(world, id)}).ok)
	var old_denied: bool = not data.turn.preview_attention({"kind": "enroll", "npc": id, "source": old_source}).ok
	var effect: Dictionary = {"type": "fact", "source": old_source, "kind": "member_dedication", "domain": "DOMAIN-001", "actor": id, "targets": [id], "observers": [id], "institutions": [], "details": {}}
	var pledged: bool = _act(data, {"family": "prayer", "content_id": "PRAYER_08", "variant": "shallow"}, [effect], {"source": old_source}).ok
	var fresh: String = _facts(world, "member_dedication")[-1].id
	_check("ATT-030", "自愿离团后的旧献身事实不能反复用；新当前意愿可重新申请同一身份", old_denied and pledged and data.turn.preview_attention({"kind": "enroll", "npc": id, "source": fresh}).ok)

func _due_identity_priority() -> void:
	var world: RefCounted = _new_hybrid()
	var id: String = world.state.simulation.candidates.values()[0].actors[0]
	var source: String = _dedicate(world, id)
	var data: Dictionary = _session(world); assert(_open(data))
	var policy: Dictionary = {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [id], "nominees": [id], "persistent": true}
	var job: Dictionary = {"id": "Z-JOIN", "due": 2, "phase": "start", "action": "join", "payload": {"npc": id}, "source": source}
	assert(_act(data, policy, [{"type": "schedule", "job": job}], {"source": source}).ok)
	job.id = "A-DEATH"; job.action = "death"
	assert(_act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": [id], "persistent": true}, [{"type": "schedule", "job": job}], {"source": source}).ok)
	var ok: bool = _evolve(data) and _finish(data) and _open(data)
	_check("ATT-031", "同批死亡优先于已预留入团，取消失效整项而不阻塞轮初或复活死者", ok and Store.entry(world.state.npcs, id).status == "dead" and not Store.entry(world.state.npcs, id).bound_member and Store.has(data.turn.context.completed_jobs, "Z-JOIN") and world.state.attention.reservations.is_empty())

func _nested_and_duplicate_projects() -> void:
	var world: RefCounted = _new_hybrid()
	var extra: String = _extra(world, 1)[0]
	var source: String = _dedicate(world, extra)
	var card: Dictionary = world.state.simulation.candidates.values()[0]
	var data: Dictionary = _session(world); assert(_open(data))
	var nested: Dictionary = {"family": "event", "content_id": "EVENT_12", "variant": "B", "candidate": card.id, "fixed": card.actors, "calls": [{"family": "power", "content_id": "POWER_APPOINT", "variant": "use", "target": "DOMAIN-002", "participants": [extra], "nominees": [extra]}]}
	var granted: Dictionary = _act(data, nested, [{"type": "membership", "operation": "enroll", "npc": extra, "source": source}], {"source": source})
	_check("ATT-033", "事件调用权能按真实子图合并F/N/P，允许已声明的额外主体而不受外层fixed误拒绝", granted.ok and Store.entry(world.state.npcs, extra).bound_member and "DOMAIN-002" in world.state.simulation.focused)
	var policy: Dictionary = {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": card.actors, "persistent": true}
	assert(_act(data, policy, [], {"source": card.fact}).ok)
	var before: String = data.turn.snapshot()
	var duplicate: Dictionary = _act(data, policy, [], {"source": card.fact, "cost": 1})
	var separate: Dictionary = policy.duplicate(true); separate.content_id = "PRAYER_02"
	_check("ATT-034", "同对象同职责未结工程不能重复发布；不同真实职责可共享主体而不互相覆盖", not duplicate.ok and before == data.turn.snapshot() and _act(data, separate, [], {"source": card.fact}).ok and world.state.attention.reservations.size() == 2)

func _conversion_keeps_project_references() -> void:
	var world: RefCounted = _new_hybrid()
	var actor: String = world.state.simulation.candidates.values()[0].actors[0]
	var source: String = _dedicate(world, actor)
	var data: Dictionary = _session(world); assert(_open(data))
	assert(_act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": [actor], "persistent": true}, [], {"source": source}).ok)
	assert(_control(data, {"kind": "enroll", "npc": actor, "source": source}).ok)
	var project: Dictionary = world.state.attention.reservations.values()[0]
	var preserved: bool = actor in project.people and not actor in world.attention.occupied(world.state, "people")
	assert(_evolve(data) and _finish(data))
	while data.turn.context.turn < 3: assert(_round(data))
	assert(_open(data))
	var fact: Dictionary = {"type": "fact", "source": source, "kind": "member_leave_authorized", "domain": "DOMAIN-001", "actor": actor, "targets": [actor], "observers": [], "institutions": [], "details": {}}
	assert(_act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow"}, [fact], {"source": source}).ok)
	var authorization: String = _facts(world, "member_leave_authorized")[-1].id
	assert(_control(data, {"kind": "leave", "npc": actor, "source": authorization}).ok)
	_check("ATT-035", "P转N只换预算不删除未结工程的主体引用；随后离团仍有退役保护", preserved and not world.state.simulation.holds.has(actor) and world.state.attention.retired.has(actor) and actor in world.state.attention.reservations.values()[0].people)
