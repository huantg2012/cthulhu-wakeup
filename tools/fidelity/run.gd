extends "res://tools/attention/run.gd"
# Deliberate contract fixtures; all settlement remains production code.
class Integrated extends Participant:
	var fault: bool = false
	var stimulate: bool = false
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var result: Dictionary = super.handle(view, input)
		if input.slot == "deadlines" and fault: result.ok = false
		if input.operation == "due" and input.action == "witness":
			var person: String = input.payload.npc
			result.effects = [{"type": "fact", "kind": "message", "source": input.source, "domain": input.payload.domain, "actor": person, "targets": [person], "observers": [person], "institutions": [], "details": {"job": input.action}}]
			result.erase("attention")
		if input.operation == "due" and input.action == "focus_work":
			result.attention = {"family": "prayer", "content_id": "PRAYER_01", "variant": "deep", "target": input.payload.domain, "participants": [input.payload.npc]}
			result.effects = [{"type": "membership", "operation": "enroll", "npc": input.payload.npc, "source": input.source}]
			result.attention["nominees"] = [input.payload.npc]
			result.attention.content_id = "PRAYER_08"
		if input.operation == "due" and input.action == "plain_focus":
			result.attention = {"family": "prayer", "content_id": "PRAYER_01", "variant": "deep", "target": input.payload.domain, "participants": [input.payload.npc]}
			result.effects = [{"type": "fact", "kind": "message", "source": input.source, "domain": input.payload.domain, "actor": input.payload.npc, "targets": [input.payload.npc], "observers": [input.payload.npc], "institutions": [], "details": {"job": input.action}}]
		if input.slot == "events" and input.operation == "gather" and stimulate and (int(view.turn.turn) - 1) % 6 == 0:
			for domain: Dictionary in view.world.domains.values():
				var observers: Array = []
				for npc: Dictionary in Store.values(view.world.npcs):
					if npc.domain == domain.id and npc.status == "active": observers.append(npc.id)
				if observers.is_empty(): continue
				var actor: String = observers[0]
				result.effects.append({"type": "fact", "source": domain.origin, "kind": "miracle", "domain": domain.id, "actor": actor, "targets": observers, "observers": observers, "institutions": [], "details": {"witnesses": observers, "public": true}})
				result.effects.append({"type": "fact", "source": domain.origin, "kind": "exposure", "domain": domain.id, "actor": actor, "targets": [actor], "observers": observers, "institutions": [domain.id + "/order"], "details": {"public": true}})
			result.empty = result.effects.is_empty()
		return result
class FaultEconomy extends "res://src/game/economy.gd":
	var fault: bool = false
	func build_batch(state: Dictionary) -> Dictionary:
		var result: Dictionary = super.build_batch(state)
		if fault and not result.entries.is_empty(): result.entries[0].growth = int(state.domains[result.entries[0].domain].unnamed_nonfollowers) + 1
		return result
class MeasuredHistory extends "res://src/simulation/history_index.gd":
	static var copied_payload_bytes: int = 0
	static func payload(value: Variant) -> Variant:
		if is_history(value): return null # Shared immutable reference, never enumerate its nodes.
		if value is Dictionary:
			var result: Dictionary = {}
			for key: Variant in value: result[key] = payload(value[key])
			return result
		if value is Array:
			var result: Array = []
			for item: Variant in value: result.append(payload(item))
			return result
		return value
	func copy_collection(state: Dictionary, collection: String) -> Dictionary:
		var result: Dictionary = super.copy_collection(state, collection)
		for id: String in current_ids(state, collection): copied_payload_bytes += var_to_bytes(payload(root_entry(result, id))).size()
		return result
var samples: Array = []
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives-" + str(Time.get_ticks_usec()))
	_future_obligations()
	_integration()
	_full_capacity()
	_identity_anchor()
	_evolution_rollback()
	_order_independence()
	_start_focus()
	_start_focus("plain_focus")
	if not "smoke" in OS.get_cmdline_user_args():
		if not "axes" in OS.get_cmdline_user_args():
			for seed_value: int in [7919, 1981, 104729]: _long_run(seed_value)
		_axes()
	var ok: bool = true
	for record: Dictionary in records: ok = ok and record.status == "pass"
	DirAccess.make_dir_recursive_absolute(OS.get_cmdline_user_args()[0].get_base_dir())
	var output: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	output.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "platform": OS.get_name(), "checks": records, "samples": samples, "memory_static_peak": OS.get_static_memory_peak_usage()}, "\t", true, true)); output.close()
	quit(0 if ok else 1)
func _integrated(world: RefCounted, economy: RefCounted, stimulus: bool = false) -> Dictionary:
	var turn: RefCounted = Turn.new(world)
	assert(economy.install(turn))
	var agent: RefCounted = Integrated.new(); agent.stimulate = stimulus
	assert(turn.register_participant("attention-fixture", "1", ["events", "actions", "start", "deadlines", "ending"], ["fact", "world_command", "check", "membership", "schedule", "wounds"], agent.handle))
	return {"world": world, "turn": turn, "agent": agent, "economy": economy}
func _base_hybrid(seed_value: int = 7919, k: int = 0, f: int = 1, attach: bool = true) -> Dictionary:
	var world: RefCounted = _new_hybrid(seed_value)
	for i: int in range(2, f + 1):
		var needs: Dictionary = {"focus": ["DOMAIN-%03d" % i], "people": [], "members": [], "identities": [], "source": world.state.domains["DOMAIN-001"].origin}
		var reservation: Dictionary = world.attention.reserve(world, needs)
		assert(reservation.ok)
		world.attention.finish(world, reservation.token)
	if k > world.state.attention.living_count:
		for i: int in k - int(world.state.attention.living_count):
			assert(world._nominate_local("DOMAIN-012", "DOMAIN-012/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-012"].origin))
		world.attention.sync(world)
	var economy: RefCounted = FaultEconomy.new(catalog, {"attention-fixture": "1"}); assert(economy.initialize(world))
	var domain: String = "DOMAIN-001"
	var leader: String = world.state.institutions[domain + "/propagation"].representative
	_bind(world, leader)
	var origin: String = world.state.domains[domain].origin
	assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [origin], {"issuer": "attention-fixture", "version": "1", "cult": "CULT-FID", "domain": domain, "leader": leader, "cohesion": 80}, [])
	assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
	assert(world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": "CULT-FID", "institution": domain + "/propagation", "allowed": true, "issuer": "attention-fixture", "version": "1", "parents": [authorization]}))
	# World-only preparation is at an action boundary; return to a legal unopened turn.
	world.state.turn = 0; world.state.phase = "between"
	world.attention.sync(world)
	return _integrated(world, economy) if attach else {"world": world, "economy": economy}
func _future_obligations() -> void:
	for nested: bool in [false, true]:
		var data: Dictionary = _base_hybrid()
		assert(_open(data))
		var actor: String = data.world.state.simulation.candidates.values()[0].actors[0]
		var source: String = Store.entry(data.world.state.npcs, actor).status_source
		var job: Dictionary = {"id": "FUTURE", "due": 3, "phase": "start", "action": "witness", "payload": {"npc": actor, "domain": "DOMAIN-001"}, "source": source}
		var effects: Array = [{"type": "schedule", "job": job}]
		if nested: effects = [{"type": "check", "source": source, "npc": actor, "domain": "DOMAIN-001", "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": effects, "success": effects, "failure": effects, "disaster": effects}}]
		var before: String = data.turn.snapshot()
		var result: Dictionary = _act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": [actor]}, effects, {"source": source, "cost": 1})
		_check("FID-002" if nested else "FID-001", "未来主体义务无持久预留在付费/随机前拒绝（嵌套=%s）" % nested, not result.ok and data.turn.snapshot() == before)
func _integration() -> void:
	var data: Dictionary = _base_hybrid()
	assert(_open(data))
	var person: String = data.world.state.simulation.candidates.values()[0].actors[0]
	var source: String = Store.entry(data.world.state.npcs, person).status_source
	var job: Dictionary = {"id": "FID-WITNESS", "due": 3, "phase": "start", "action": "witness", "payload": {"npc": person, "domain": "DOMAIN-001"}, "source": source}
	assert(_act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": [person], "persistent": true}, [{"type": "schedule", "job": job}], {"source": source}).ok)
	assert(_submit(data, "set_plan", {"participant": Economy.ID, "payload": {"strategies": {"CULT-FID": "expand"}}}).ok)
	assert(_evolve(data))
	var before: String = data.turn.snapshot()
	data.agent.fault = true
	var request: Dictionary = {"id": "FID-FAIL-INCOME", "op": "advance", "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	var rejected: bool = not data.turn.submit(request).ok and data.turn.snapshot() == before
	data.agent.fault = false
	var path: String = scratch.path_join("combination")
	assert(data.turn.save_archive(path), data.turn.last_error)
	var restored: Dictionary = _base_hybrid(); assert(restored.turn.load_archive(path))
	var equal: bool = restored.turn.snapshot() == before
	var response: Dictionary = data.turn.submit(request)
	equal = restored.turn.submit(request) == response and equal and data.turn.snapshot() == restored.turn.snapshot()
	var committed: String = data.turn.snapshot()
	equal = data.turn.submit(request) == response and data.turn.snapshot() == committed and equal
	var faults: Dictionary = {}
	for fault: String in ["segments", "commit", "manifest"]:
		var rescue: Dictionary = _base_hybrid()
		faults[fault] = not data.turn.save_archive(path, fault) and rescue.turn.load_archive(path) and rescue.turn.snapshot() == before
	_check("FID-003", "收入后失败整批回滚，存档中断保留上次提交，恢复重试费用/随机/回执一致", rejected and equal and response.ok and not false in faults.values(), faults)
	assert(data.turn.save_archive(path), data.turn.last_error)
	assert(restored.turn.load_archive(path))
	for op: String in ["advance", "advance", "finish_events", "end_actions", "advance", "advance", "advance", "advance"]:
		request_sequence += 1
		request = {"id": "FID-RESUME-" + str(request_sequence), "op": op, "turn": data.turn.context.turn, "phase": data.turn.context.phase}
		var a: Dictionary = data.turn.submit(request); var b: Dictionary = restored.turn.submit(request)
		equal = a.ok and a == b and data.turn.snapshot() == restored.turn.snapshot() and equal
	_check("FID-004", "后台候选到期与预留工程跨轮恢复，全部后果结清且释放令牌", equal and Store.has(data.turn.context.completed_jobs, "FID-WITNESS") and data.world.state.attention.reservations.is_empty())
func _full_capacity() -> void:
	var data: Dictionary = _base_hybrid(7919, 72, 3, false)
	var world: RefCounted = data.world
	# Prepared identities are real; capacities are acquired by production reservations.
	var ids: Array = world.history.ids("living")
	ids.sort_custom(func(a: String, b: String) -> bool: return ("0" if Store.entry(world.state.npcs, a).domain == "DOMAIN-012" else "1") + a < ("0" if Store.entry(world.state.npcs, b).domain == "DOMAIN-012" else "1") + b)
	var members: Array = world.state.simulation.persistent.duplicate()
	for id: String in ids:
		if members.size() == 12: break
		if not id in members: _bind(world, id); members.append(id)
	var people: Array = world.attention.occupied(world.state, "people")
	for id: String in ids:
		if people.size() == 12: break
		if not id in members and not id in people: people.append(id)
	var origin: String = world.state.domains["DOMAIN-001"].origin
	var held: Dictionary = world.attention.reserve(world, {"focus": [], "people": people, "members": [], "identities": [], "source": origin}, true)
	assert(held.ok)
	data = _integrated(world, data.economy)
	assert(_open(data))
	var detailed: int = world.attention.detailed_ids(world.state).size()
	var witness: Dictionary = {"id": "FULL-DUE", "due": 2, "phase": "start", "action": "witness", "payload": {"npc": people[0], "domain": "DOMAIN-001"}, "source": origin}
	assert(_act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": [people[0]], "persistent": true}, [{"type": "schedule", "job": witness}], {"source": origin}).ok)
	var before_updates: int = world.stats.npc_updates
	var blocked: bool = not _control(data, {"kind": "focus", "domain": "DOMAIN-004"}).ok
	var before: String = data.turn.snapshot()
	var duplicate: Dictionary = _act(data, {"family": "prayer", "content_id": "PRAYER_08", "variant": "deep", "target": "DOMAIN-001", "nominees": [ids[-1]], "participants": [ids[-1]]}, [], {"cost": 1})
	var rejected: bool = not duplicate.ok and before == data.turn.snapshot()
	var ok: bool = _evolve(data) and _finish(data)
	_check("FID-005", "真实F3/N12/P12满载拒绝额外申请，详细并集每人只更新一次且共同经济结算", blocked and rejected and ok and world.stats.npc_updates - before_updates == detailed and world.state.economy.income_sources.has("CULT-FID"), {"F": world.state.simulation.focused.size(), "N": members.size(), "P": people.size(), "detailed": detailed, "updates": world.stats.npc_updates - before_updates})
	assert(_open(data))
	_check("FID-012", "满载下已承诺主体到期后果完整执行，不因新工作预算拒绝", Store.has(data.turn.context.completed_jobs, "FULL-DUE") and _facts(world, "message").any(func(fact: Dictionary) -> bool: return fact.actor == people[0] and Store.entry(data.turn.context.completed_jobs, "FULL-DUE").source in fact.causal_parents))
func _distribution(values: Array) -> Dictionary:
	var ordered: Array = values.duplicate(); ordered.sort()
	return {"p50": ordered[int(ordered.size() * 0.5)], "p95": ordered[mini(ordered.size() - 1, int(ordered.size() * 0.95))], "max": ordered.back()}
func _totals(world: RefCounted) -> Dictionary:
	var result: Dictionary = {"income": 0, "paid": 0, "growth": 0, "learning": 0}
	for fact: Dictionary in Store.values(world.state.facts):
		if fact.kind == "economy_income": result.income += int(fact.changes.actual)
		if fact.kind in ["economy_strategy_payment", "economy_anchor_payment"]: result.paid += int(fact.changes.fee)
		if fact.kind == "attribute_growth": result.growth += 1
	for npc: Dictionary in Store.values(world.state.npcs):
		for sources: Variant in npc.growth_sources.values(): result.learning += History.size(sources)
	return result
func _long_run(seed_value: int) -> void:
	var data: Dictionary = _base_hybrid(seed_value, 0, 3); data.agent.stimulate = true
	var times: Array = []; var windows: Array = []; var stages: Array = []
	var prior_actions: int = 0; var prior_income: int = 0
	var valid: bool = true
	for index: int in 60:
		var started: int = Time.get_ticks_usec()
		for phase: int in 6:
			data.world.history.reset_metrics()
			var counts: Dictionary = {"facts": Store.size(data.world.state.facts), "actions": data.world.stats.actions, "updates": data.world.stats.npc_updates}
			var at: int = Time.get_ticks_usec()
			if phase == 2 and index == 0: assert(_submit(data, "set_plan", {"participant": Economy.ID, "payload": {"strategies": {"CULT-FID": "expand"}}}).ok)
			valid = _submit(data, ["advance", "finish_events", "end_actions", "advance", "advance", "advance"][phase]).ok and valid
			stages.append({"turn": index + 1, "phase": phase + 1, "ms": (Time.get_ticks_usec() - at) / 1000.0, "transaction": data.turn.last_transaction_metrics.duplicate(true), "history_work": data.world.history.metrics.duplicate(true), "facts_added": Store.size(data.world.state.facts) - counts.facts, "actions": data.world.stats.actions - counts.actions, "updates": data.world.stats.npc_updates - counts.updates, "candidates": data.world.state.simulation.candidates.size(), "K": data.world.state.attention.living_count, "detailed": data.world.attention.detailed_ids(data.world.state).size()})
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		if (index + 1) % 10 == 0:
			var totals: Dictionary = _totals(data.world)
			var window: Dictionary = {"turn": index + 1, "actions": data.world.stats.actions - prior_actions, "income": totals.income - prior_income, "living": data.world.state.attention.living_count, "facts": Store.size(data.world.state.facts), "totals": totals, "plans_resolved": data.world.stats.plans_resolved}
			valid = valid and window.actions > 0 and window.income > 0
			windows.append(window); prior_actions = data.world.stats.actions; prior_income = totals.income
			print("FID LOAD ", seed_value, " ", window)
	var totals: Dictionary = _totals(data.world)
	var timing: Dictionary = _distribution(times)
	var metrics: Dictionary = {"seed": seed_value, "turns": 60, "windows": windows, "stages": stages, "turn_ms": timing, "stats": data.world.stats.duplicate(true), "totals": totals, "save": _save_cost(data, "long-" + str(seed_value))}
	samples.append(metrics)
	_check("FID-LONG-" + str(seed_value), "60轮真实混合/经济/风险/成长且尾窗仍活动，事前工程预算", valid and totals.growth > 0 and totals.paid > 0 and data.world.stats.plans_resolved > 0 and timing.p95 <= 1000 and timing.max <= 5000 and metrics.save.ok and metrics.save.load_ms <= 10000 and OS.get_static_memory_peak_usage() <= 512 * 1024 * 1024, {"turn_ms": timing, "totals": totals})
func _save_cost(data: Dictionary, label: String) -> Dictionary:
	var path: String = scratch.path_join(label)
	var at: int = Time.get_ticks_usec()
	var ok: bool = data.turn.save_archive(path)
	if not ok: print("SAVE ERROR ", data.turn.last_error)
	var initial: Dictionary = data.turn.last_save_metrics.duplicate(true)
	var save_ms: float = (Time.get_ticks_usec() - at) / 1000.0
	at = Time.get_ticks_usec(); var snapshot: String = data.turn.snapshot()
	var export_ms: float = (Time.get_ticks_usec() - at) / 1000.0
	var restore: Dictionary = _base_hybrid()
	at = Time.get_ticks_usec(); ok = restore.turn.load_archive(path) and ok
	var load_ms: float = (Time.get_ticks_usec() - at) / 1000.0
	ok = restore.turn.snapshot() == snapshot and ok
	return {"ok": ok, "initial": initial, "save_ms": save_ms, "export_ms": export_ms, "export_bytes": snapshot.to_utf8_buffer().size(), "load_ms": load_ms}
func _axis_case(label: String, k: int, f: int, h: int = 0, q: int = 0) -> Dictionary:
	var data: Dictionary = _base_hybrid(7919, k, f, false)
	var world: RefCounted = data.world
	var origin: String = world.state.domains["DOMAIN-001"].origin
	for i: int in h:
		var fact_id: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, fact_id, {"id": fact_id, "turn": 0, "kind": "message", "domain": "DOMAIN-001", "actor": "", "targets": [], "causal_parents": [origin], "changes": {"irrelevant": i}})
	world.state = History.export_value(world.state)
	world.history = MeasuredHistory.new(); world.history.configure(catalog.tables.npc_behaviors); world.history.rebuild(world.state)
	data = _integrated(world, data.economy)
	assert(_open(data))
	var actor: String = world.state.simulation.candidates.values()[0].actors[0]
	var policies: Array = []
	for policy: Dictionary in world.attention.policies.values():
		if policy.family == "prayer": policies.append(policy)
	for i: int in q:
		var policy: Dictionary = policies[i]
		var job: Dictionary = {"id": "Q-" + str(i), "due": 2, "phase": "start", "action": "witness", "payload": {"npc": actor, "domain": "DOMAIN-001"}, "source": origin}
		assert(_act(data, {"family": policy.family, "content_id": policy.content_id, "variant": policy.variant, "target": "DOMAIN-001", "participants": [actor], "nominees": [actor] if policy.member_scope != "none" else [], "persistent": true}, [{"type": "schedule", "job": job}], {"source": origin}).ok)
	var snapshot_path: String = scratch.path_join(label)
	assert(data.turn.save_archive(snapshot_path))
	var initial: Dictionary = data.turn.last_save_metrics.duplicate(true)
	world.history.reset_metrics(); MeasuredHistory.copied_payload_bytes = 0
	var update_before: int = world.stats.npc_updates
	var detailed: int = world.attention.detailed_ids(world.state).size()
	var started: int = Time.get_ticks_usec()
	assert(_evolve(data) and _finish(data))
	var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
	var work: Dictionary = world.history.metrics.duplicate(true)
	var copy_bytes: int = MeasuredHistory.copied_payload_bytes
	started = Time.get_ticks_usec(); assert(data.turn.save_archive(snapshot_path))
	var save_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var delta: Dictionary = data.turn.last_save_metrics.duplicate(true)
	var result: Dictionary = {"label": label, "requested_K": k, "K": world.state.attention.living_count, "F": f, "added_H": h, "Q": q, "detailed": detailed, "updates": world.stats.npc_updates - update_before, "ms": elapsed, "work": work, "copied_current_payload_bytes": copy_bytes, "initial": initial, "delta": delta, "incremental_save_ms": save_ms}
	if label.begins_with("H-"):
		var audit: Dictionary = _base_hybrid()
		assert(audit.turn.restore(data.turn.snapshot()))
		result["full_io"] = _save_cost(audit, label + "-audit")
		world.history.reset_metrics()
		var query_at: int = Time.get_ticks_usec()
		var page: Dictionary = world.history.query(world.state, "person_knowledge", actor)
		result["cold_page"] = {"ok": page.ok, "items": page.items.size(), "complete": page.complete, "ms": (Time.get_ticks_usec() - query_at) / 1000.0, "work": world.history.metrics.duplicate(true)}
	if q > 0:
		assert(_open(data))
		result["jobs_completed"] = Store.size(data.turn.context.completed_jobs)
		result["reservations_remaining"] = world.state.attention.reservations.size()
	samples.append(result)
	return result
func _axes() -> void:
	var hs: Array = []
	for h: int in [0, 2000, 10000]: hs.append(_axis_case("H-" + str(h), 7, 1, h))
	var valid: bool = true
	for row: Dictionary in hs: valid = valid and row.work.history_scanned == 0 and row.work.root_identity_entries == 0 and row.work.copied_history_values == 0 and row.delta.nodes_encoded <= hs[0].delta.nodes_encoded * 4 and row.incremental_save_ms <= 2000 and row.copied_current_payload_bytes == hs[0].copied_current_payload_bytes and row.full_io.ok and row.cold_page.ok
	_check("FID-006", "固定当前态增H至10000，热路径不全扫描/复制历史，增量保存只写新路径", valid)
	var ks: Array = []
	for k: int in [7, 72, 144]: ks.append(_axis_case("K-" + str(k), k, 1))
	_check("FID-007", "K独立增大，详细更新不随非活动活身份膨胀；披露保守复制成本", ks[0].updates == ks[1].updates and ks[1].updates == ks[2].updates and ks[2].copied_current_payload_bytes > ks[0].copied_current_payload_bytes)
	var fs: Array = []
	for f: int in [1, 2, 3]: fs.append(_axis_case("F-" + str(f), 72, f))
	_check("FID-008", "固定K增加F，详细并集真实增加，未冻结后台职责", fs[0].K == fs[2].K and fs[0].updates < fs[1].updates and fs[1].updates < fs[2].updates)
	valid = true
	for q: int in [1, 8, 16]:
		var row: Dictionary = _axis_case("Q-" + str(q), 7, 1, 0, q)
		valid = valid and row.jobs_completed == q and row.reservations_remaining == 0
	_check("FID-009", "共享主体多职责工程Q独立增长，所有到期任务结清后才释放", valid)
func _evolution_rollback() -> void:
	var data: Dictionary = _base_hybrid(1981, 0, 3); data.agent.stimulate = true
	assert(_open(data))
	assert(_submit(data, "set_plan", {"participant": Economy.ID, "payload": {"strategies": {"CULT-FID": "expand"}}}).ok)
	assert(_submit(data, "end_actions").ok)
	var before: String = data.turn.snapshot()
	var request: Dictionary = {"id": "FID-MERGE", "op": "advance", "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	data.economy.fault = true
	var rejected: bool = not data.turn.submit(request).ok and data.turn.snapshot() == before
	data.economy.fault = false
	var clean: Dictionary = _base_hybrid(1981, 0, 3); clean.agent.stimulate = true
	assert(clean.turn.restore(before))
	var a: Dictionary = data.turn.submit(request); var b: Dictionary = clean.turn.submit(request)
	_check("FID-010", "详细/概略/经济同批超量人口拒绝，索引随机候选回滚后与干净恢复一致", rejected and a.ok and a == b and data.turn.snapshot() == clean.turn.snapshot())
func _identity_anchor() -> void:
	var data: Dictionary = _base_hybrid(7919, 0, 1, false)
	var world: RefCounted = data.world
	var cult: Dictionary = world.state.cults["CULT-FID"]
	var origin: String = cult.established_source
	world.state.domains[cult.domain].pollution = 50
	Store.put(world.state.relics, "RELIC-FID", {"id": "RELIC-FID", "domain": cult.domain, "placement": "bound", "holder": "", "anchor": "ANCHOR-FID"})
	world.state.anchors["ANCHOR-FID"] = {"id": "ANCHOR-FID", "domain": cult.domain, "institution": cult.domain + "/interpretation", "guardian": cult.leader, "relic": "RELIC-FID", "state": "active", "needs_rebind": false, "origin": origin, "ordinal": 1, "cult": cult.id}
	assert(world.submit({"kind": "economy_qualification", "rule": "anchor", "subject": "ANCHOR-FID", "institution": cult.domain + "/interpretation", "allowed": true, "issuer": "attention-fixture", "version": "1", "parents": [origin]}))
	world._refresh_anchors()
	data = _integrated(world, data.economy)
	assert(_open(data))
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-001"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	var background: bool = not "DOMAIN-001" in world.state.simulation.focused
	assert(_evolve(data) and _finish(data) and _open(data))
	var paid: Array = _facts(world, "economy_anchor_payment")
	var leader: String = world.state.cults["CULT-FID"].leader
	var destination: String = world.state.domains["DOMAIN-001"].neighbors[0]
	var population: int = 0
	for domain: Dictionary in world.state.domains.values(): population += int(domain.population)
	var move: Dictionary = {"type": "world_command", "source": origin, "command": {"kind": "migrate", "npc": leader, "domain": destination, "parents": [origin]}}
	var moved: bool = _act(data, {"family": "power", "content_id": "POWER_TRANSFER", "variant": "use", "source_domain": "DOMAIN-001", "target": destination, "participants": [leader]}, [move], {"source": origin}).ok
	var after_move: int = 0
	for domain: Dictionary in world.state.domains.values(): after_move += int(domain.population)
	var dormant: bool = world.state.anchors["ANCHOR-FID"].state != "active"
	var death: Dictionary = {"type": "world_command", "source": origin, "command": {"kind": "status", "npc": leader, "status": "dead", "parents": [origin]}}
	var dead: bool = _act(data, {"family": "prayer", "content_id": "PRAYER_01", "variant": "shallow", "participants": [leader]}, [death], {"source": origin}).ok
	var after_death: int = 0
	for domain: Dictionary in world.state.domains.values(): after_death += int(domain.population)
	var path: String = scratch.path_join("identity")
	var saved: bool = data.turn.save_archive(path)
	var restored: Dictionary = _base_hybrid()
	_check("FID-011", "后台供奉仍支付，护持者迁移/死亡即时失去锚点贡献且人口/旧身份保存连续", background and paid.size() >= 2 and moved and dormant and population == after_move and dead and after_death == population - 1 and saved and restored.turn.load_archive(path) and restored.turn.snapshot() == data.turn.snapshot(), {"background": background, "payments": paid.size(), "moved": moved, "dormant": dormant, "dead": dead, "populations": [population, after_move, after_death]})

func _order_independence() -> void:
	var first: Dictionary = _base_hybrid(1981, 72, 3, false)
	var second: Dictionary = _base_hybrid(1981, 72, 3, false)
	for field: String in ["domains", "institutions", "cults"]:
		var reordered: Dictionary = {}
		var ids: Array = second.world.state[field].keys(); ids.reverse()
		for id: String in ids: reordered[id] = second.world.state[field][id]
		second.world.state[field] = reordered
	first = _integrated(first.world, first.economy); second = _integrated(second.world, second.economy)
	var equal: bool = true
	for round_index: int in 3:
		for op: String in ["advance", "finish_events", "end_actions", "advance", "advance", "advance"]:
			request_sequence += 1
			var request: Dictionary = {"id": "ORDER-" + str(request_sequence), "op": op, "turn": first.turn.context.turn, "phase": first.turn.context.phase}
			var a: Dictionary = first.turn.submit(request); var b: Dictionary = second.turn.submit(request)
			equal = equal and a.ok and a == b and first.turn.snapshot() == second.turn.snapshot()
	_check("FID-013", "真实混合多重点/经济/候选在域机构教团逆序枚举下逐阶段一致", equal)
func _start_focus(action: String = "focus_work") -> void:
	var data: Dictionary = _base_hybrid(7919, 0, 3, false)
	var world: RefCounted = data.world
	var actor: String = world.state.institutions["DOMAIN-002/propagation"].representative
	var source: String = _dedicate(world, actor)
	data = _integrated(world, data.economy); assert(_open(data))
	var job: Dictionary = {"id": "FOCUS-DUE", "due": 2, "phase": "start", "action": action, "payload": {"npc": actor, "domain": "DOMAIN-002"}, "source": source}
	assert(_act(data, {"family": "prayer", "content_id": "PRAYER_08", "variant": "deep", "target": "DOMAIN-002", "participants": [actor], "nominees": [actor], "persistent": true}, [{"type": "schedule", "job": job}], {"source": source}).ok)
	assert(_control(data, {"kind": "release_focus", "domain": "DOMAIN-002"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	var retained: bool = "DOMAIN-002" in world.state.simulation.focused
	var before: String = data.turn.snapshot()
	var blocked: bool = not _control(data, {"kind": "focus", "domain": "DOMAIN-004"}).ok and before == data.turn.snapshot()
	_check("FID-014" if action == "focus_work" else "FID-015", "轮初工程实际使用F后保留本轮占用，不能同轮切换第四域（" + action + "）", retained and blocked and (Store.entry(world.state.npcs, actor).bound_member if action == "focus_work" else _facts(world, "message").any(func(fact: Dictionary) -> bool: return fact.changes.get("job") == "plain_focus")) and Store.has(data.turn.context.completed_jobs, "FOCUS-DUE"), {"retained": retained, "blocked": blocked})
