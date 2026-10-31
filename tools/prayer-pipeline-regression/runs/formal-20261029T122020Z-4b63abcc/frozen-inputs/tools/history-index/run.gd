extends SceneTree
const Store = preload("res://src/simulation/archive_store.gd")
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const StateView = preload("res://src/simulation/state_view.gd")
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
var catalog: RefCounted
var checks: Array = []
var sequence: int = 0

class Adapter extends RefCounted:
	var saved_reader: RefCounted
	var attacked_world: RefCounted
	var reader_check: Dictionary = {}
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var source: String = view.world.domains["DOMAIN-001"].origin
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
		if input.slot == "events" and input.operation == "gather":
			result.events = []
		if input.slot == "actions":
			result.meta = {"faith_cost": 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": source, "outcome": "history_fixture", "responds": false, "used_power": false, "used_relic": false}
			if input.action == "fail_after_source":
				var person: String = view.world.institutions["DOMAIN-001/order"].representative
				result.effects.append({"type": "fact", "source": source, "kind": "miracle", "domain": "DOMAIN-001", "actor": person, "targets": [person], "observers": [person], "institutions": [], "details": {"witnesses": [person], "public": false}})
				for ignored: int in 2:
					result.effects.append({"type": "resource", "source": source, "field": "faith", "delta": -(int(view.world.faith) / 2 + 1)})
			if input.action == "cache_clear":
				attacked_world.history = null
			if input.action == "cache_replace":
				attacked_world.history = HistoryIndex.new()
			if input.action in ["reader_clear", "reader_replace"]:
				var person: String = view.world.institutions["DOMAIN-001/order"].representative
				saved_reader = view.reader
				reader_check = {"fact": saved_reader.fact(source), "page": saved_reader.history_query("person_knowledge", person, {}, 1)}
				if input.action == "reader_clear":
					view.clear()
				else:
					view.reader = null
		result.empty = result.effects.is_empty()
		return result
	func preview(view: Dictionary, _plan: Dictionary) -> Dictionary:
		return {"ok": true, "preview": {"living": Store.size(view.world.npcs), "faith": view.world.faith, "visibleRelics": Store.size(view.world.relics), "coldAnomaliesHidden": not view.world.domains["DOMAIN-001"].has("public_anomalies")}}

func _initialize() -> void:
	catalog = Catalog.new()
	assert(catalog.load_files())
	_scaling()
	_old_sources()
	_temporary_invalidation()
	_multisource()
	_growth()
	_rollback()
	_paging()
	_load_audit()
	_receipts()
	_anomaly()
	_comfort_causes()
	_persistent_tree()
	_tree_mutations()
	_policy()
	_bad_candidates()
	_reader_lifetime()
	_cache_guard()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var ok: bool = true
	for check: Dictionary in checks:
		ok = ok and check.status == "pass"
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": checks}, "\t", true, true))
	file.close()
	quit(0 if ok else 1)

func _check(id: String, name: String, ok: bool, detail: Dictionary = {}) -> void:
	checks.append({"id": id, "name": name, "status": "pass" if ok else "fail", "details": detail})
	print("PASS " if ok else "FAIL ", id, " ", name, " ", detail)

func _plain(value: Variant) -> Variant:
	return World._normalize_numbers(JSON.parse_string(World.canonical(value)))

func _world() -> RefCounted:
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	world.state = _plain(world.state)
	for npc: Dictionary in Store.values(world.state.npcs):
		npc.sanity = 80
		npc.loyalty = 40
	return world

func _person(world: RefCounted, role: String = "order") -> String:
	return world.state.institutions["DOMAIN-001/" + role].representative

func _origin(world: RefCounted) -> String:
	return world.state.domains["DOMAIN-001"].origin

func _miracle(world: RefCounted, actor: String) -> String:
	return world.introduce_fact("miracle", "DOMAIN-001", actor, [actor], [_origin(world)], {"witnesses": [actor], "public": false}, [actor])

func _padding(world: RefCounted, count: int, tombstones: int = 0) -> void:
	# Explicit already-existing, semantically irrelevant history fixture. The full
	# adoption audit and index build happen AFTER preparation, outside hot metrics.
	world.state = _plain(world.state)
	var origin: String = _origin(world)
	var old_ids: Array = []
	for i: int in count:
		var id: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, id, {"id": id, "turn": 0, "kind": "message", "domain": "DOMAIN-001", "actor": "", "targets": [], "causal_parents": [origin], "changes": {"fixture": "irrelevant_existing_history", "ordinal": i}})
		old_ids.append(id)
	for npc: Dictionary in Store.values(world.state.npcs):
		npc.known_facts.append_array(old_ids)
	for institution: Dictionary in world.state.institutions.values():
		institution.known_facts.append_array(old_ids)
	var template: Dictionary = Store.entry(world.state.npcs, _person(world)).duplicate(true)
	for i: int in tombstones:
		var id: String = "NPC-%08d" % int(world.state.next_npc)
		world.state.next_npc += 1
		var person: Dictionary = template.duplicate(true)
		person.id = id
		person.status = "dead"
		person.institution = ""
		person.relations = []
		person.known_facts = [origin]
		person.consumed_sources = {}
		person.growth_sources = {}
		person.status_source = origin
		Store.put(world.state.npcs, id, person)
		Store.put(world.state.evidence, "DOMAIN-001/order|" + id, {"institution": "DOMAIN-001/order", "subject": id, "strength": 1, "sources": [origin], "confirmations": []})
		var relation_fact: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		var actor: String = _person(world)
		Store.put(world.state.facts, relation_fact, {"id": relation_fact, "turn": 0, "kind": "relationship", "domain": "DOMAIN-001", "actor": actor, "targets": [id], "causal_parents": [origin], "changes": {"kind": "support", "fixture": "existing_dead_relationship"}})
		Store.entry(world.state.npcs, actor).relations.append({"target": id, "kind": "support", "source": relation_fact})
		var harm: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, harm, {"id": harm, "turn": 0, "kind": "harm", "domain": "DOMAIN-001", "actor": id, "targets": [id], "causal_parents": [origin], "changes": {"fixture": "historical_harm_of_dead_subject"}})
		Store.entry(world.state.npcs, actor).known_facts.append(harm)
		Store.entry(world.state.npcs, id).known_facts.append(harm)
		var confirmation: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, confirmation, {"id": confirmation, "turn": 0, "kind": "evidence_confirmed", "domain": "DOMAIN-001", "actor": "", "targets": [id], "causal_parents": [harm], "changes": {"institution": "DOMAIN-001/order", "strength": catalog.integer("evidence_confirmation_strength")}})
		Store.entry(world.state.evidence, "DOMAIN-001/order|" + id).strength = catalog.integer("evidence_confirmation_strength")
		Store.entry(world.state.evidence, "DOMAIN-001/order|" + id).confirmations = [confirmation]
		var exception: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, exception, {"id": exception, "turn": 0, "kind": "exception", "domain": "DOMAIN-001", "actor": "", "targets": [], "causal_parents": [origin], "changes": {"fixture": "already_invalid_exception"}})
		var exception_confirmation: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, exception_confirmation, {"id": exception_confirmation, "turn": 0, "kind": "evidence_confirmed", "domain": "DOMAIN-001", "actor": "", "targets": [exception], "causal_parents": [exception], "changes": {"institution": "DOMAIN-001/interpretation", "strength": catalog.integer("evidence_confirmation_strength")}})
		Store.put(world.state.evidence, "DOMAIN-001/interpretation|" + exception, {"institution": "DOMAIN-001/interpretation", "subject": exception, "strength": catalog.integer("evidence_confirmation_strength"), "sources": [exception], "confirmations": [exception_confirmation]})
		Store.put(world.state.invalid_records, exception, origin)
		var anomaly: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, anomaly, {"id": anomaly, "turn": 0, "kind": "public_anomaly", "domain": "DOMAIN-001", "actor": id, "targets": [id], "causal_parents": [origin], "changes": {"fixture": "old_anomaly_carrier_now_dead"}})
		world.state.domains["DOMAIN-001"].public_anomalies[anomaly] = id
		var relic: String = "RELIC-HIST-%04d" % i
		Store.put(world.state.relics, relic, {"id": relic, "domain": "DOMAIN-001", "holder": "", "placement": "consumed", "anchor": ""})
		var relic_anomaly: String = "FACT-%08d" % int(world.state.next_fact)
		world.state.next_fact += 1
		Store.put(world.state.facts, relic_anomaly, {"id": relic_anomaly, "turn": 0, "kind": "public_anomaly", "domain": "DOMAIN-001", "actor": "", "targets": [relic], "causal_parents": [origin], "changes": {"fixture": "old_anomaly_relic_now_consumed"}})
		world.state.domains["DOMAIN-001"].public_anomalies[relic_anomaly] = relic
	assert(world.validate_state(world.state).is_empty())
	world.ensure_history()

func _attach(world: RefCounted) -> Dictionary:
	var turn: RefCounted = Turn.new(world)
	var adapter: RefCounted = Adapter.new()
	assert(turn.register_participant("history-fixture", "1", Turn.SLOTS, ["fact", "resource"], adapter.handle, adapter.preview))
	return {"world": world, "turn": turn, "adapter": adapter}

func _request(data: Dictionary, op: String, action: String = "") -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "HIST-REQ-%d" % sequence, "op": op, "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	if not action.is_empty():
		request.merge({"participant": "history-fixture", "action": action, "payload": {}})
	return request

func _open(data: Dictionary) -> void:
	assert(data.turn.submit(_request(data, "advance")).ok)
	assert(data.turn.submit(_request(data, "finish_events")).ok)

func _scale_case(padded: bool) -> Dictionary:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	var target: String = _person(world, "interpretation")
	var miracle: String = _miracle(world, actor)
	var exposure: String = world.introduce_fact("exposure", "DOMAIN-001", target, [target], [_origin(world)], {"public": false}, [actor], ["DOMAIN-001/order"])
	world.state.domains["DOMAIN-001"].alert = 90
	_padding(world, 2000 if padded else 0, 300 if padded else 0)
	world.history.reset_metrics()
	var behavior: Dictionary = world.choose_behavior(actor)
	var plan: Dictionary = world.choose_plan("DOMAIN-001")
	var decision_metrics: Dictionary = world.history.metrics.duplicate(true)
	var data: Dictionary = _attach(world)
	_open(data)
	world.history.reset_metrics()
	var preview: Dictionary = data.turn.preview_plan("history-fixture", {})
	var preview_metrics: Dictionary = world.history.metrics.duplicate(true)
	world.history.reset_metrics()
	var response: Dictionary = data.turn.submit(_request(data, "act", "empty"))
	var action_metrics: Dictionary = world.history.metrics.duplicate(true)
	var transaction: Dictionary = data.turn.last_transaction_metrics.duplicate(true)
	assert(data.turn.submit(_request(data, "end_actions")).ok)
	world.history.reset_metrics()
	var evolved: Dictionary = data.turn.submit(_request(data, "advance"))
	var evolution_metrics: Dictionary = world.history.metrics.duplicate(true)
	return {"behavior": behavior, "plan": plan, "decision": decision_metrics, "preview": preview, "previewMetrics": preview_metrics, "action": action_metrics, "transaction": transaction, "evolution": evolution_metrics, "evolutionTransaction": data.turn.last_transaction_metrics, "ok": response.ok and evolved.ok and preview.ok and preview.preview.coldAnomaliesHidden, "facts": Store.size(world.state.facts), "allPeople": Store.size(world.state.npcs), "allRelics": Store.size(world.state.relics), "sources": [miracle, exposure]}

func _scaling() -> void:
	var small: Dictionary = _scale_case(false)
	var large: Dictionary = _scale_case(true)
	var valid: bool = small.ok and large.ok and small.behavior == large.behavior and small.plan == large.plan and small.preview == large.preview
	for field: String in ["decision", "previewMetrics", "action", "evolution"]:
		for key: String in ["history_scanned", "rebuild_records", "copied_history_values"]:
			valid = valid and int(small[field].get(key, -1)) == 0 and int(large[field].get(key, -1)) == 0
		for key: String in ["decision_reads", "current_entities", "copied_current_objects", "output_sources"]:
			valid = valid and small[field].get(key, -1) == large[field].get(key, -1)
	_check("HIST-002", "同有效状态追加2000旧消息/见闻和300墓碑关系/伤害/旧证据和已耗圣物/异常，决策预览行动及演化的有效读取复制不增长", valid, {"small": small, "large": large})

func _old_sources() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	var first: String = _miracle(world, actor)
	var second: String = _miracle(world, actor)
	world.state.turn = 50 # The sources remain valid after many turns, not merely many IDs.
	_padding(world, 2000)
	var selected: Dictionary = world.choose_behavior(actor)
	_check("HIST-003", "很旧但未消费的个人神迹仍可用且按最早合法来源选择", selected.get("behavior") == "NPC_INTERPRET" and selected.get("source") == first and first < second, {"first": first, "second": second, "selected": selected, "facts": Store.size(world.state.facts)})
	world = _world()
	actor = _person(world)
	Store.entry(world.state.npcs, actor).sanity = 20
	first = world.introduce_fact("strain", "DOMAIN-001", actor, [actor], [_origin(world)], {}, [actor])
	second = world.introduce_fact("harm", "DOMAIN-001", actor, [actor], [_origin(world)], {}, [actor])
	world.state.turn = 50
	_padding(world, 2000)
	selected = world.choose_behavior(actor)
	_check("HIST-004", "整顿仍选择最新本人创伤来源而不是最早来源或无关最近事实", selected.get("behavior") == "NPC_RECOVER" and selected.get("source") == second, {"selected": selected, "expected": second})

func _temporary_invalidation() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	var target: String = _person(world, "interpretation")
	var exposure: String = world.introduce_fact("exposure", "DOMAIN-001", target, [target], [_origin(world)], {"public": false}, [actor], ["DOMAIN-001/order"])
	_padding(world, 2000)
	var before: Dictionary = world.choose_behavior(actor)
	var destination: String = world.state.domains["DOMAIN-001"].neighbors[0]
	var moved: bool = world.submit({"kind": "migrate", "npc": target, "domain": destination, "parents": [exposure]})
	var away: Dictionary = world.choose_behavior(actor)
	var back: bool = world.submit({"kind": "migrate", "npc": target, "domain": "DOMAIN-001", "parents": [Store.entry(world.state.npcs, target).status_source]})
	var returned: Dictionary = world.choose_behavior(actor)
	var status_valid: bool = true
	for status: String in ["detained", "missing"]:
		status_valid = world.submit({"kind": "status", "npc": target, "status": status, "parents": [Store.entry(world.state.npcs, target).status_source]}) and status_valid
		status_valid = world.choose_behavior(actor).is_empty() and target in world.history.ids("living") and not target in world.history.ids("active") and status_valid
		status_valid = world.submit({"kind": "status", "npc": target, "status": "active", "parents": [Store.entry(world.state.npcs, target).status_source]}) and status_valid
		status_valid = world.choose_behavior(actor).get("source") == exposure and target in world.history.ids("active") and status_valid
	var died: bool = world.submit({"kind": "status", "npc": target, "status": "dead", "parents": [Store.entry(world.state.npcs, target).status_source]})
	var tombstone: bool = died and not target in world.history.ids("living") and not target in world.history.ids("active") and Store.has(world.state.npcs, target) and world.choose_behavior(actor).is_empty()
	_check("HIST-005", "迁出/拘禁/失踪暂撤资格，恢复后旧暴露再合法；死亡离开活动索引但保留墓碑", moved and back and before.get("source") == exposure and away.is_empty() and returned.get("source") == exposure and HistoryIndex.has(Store.entry(world.state.npcs, actor).known_facts, exposure) and status_valid and tombstone, {"before": before, "away": away, "returned": returned, "temporaryStatuses": status_valid, "deathIndex": tombstone})

func _multisource() -> void:
	var world: RefCounted = _world()
	var target: String = _person(world, "interpretation")
	world.state.domains["DOMAIN-001"].alert = 90
	var sources: Array = []
	for i: int in 31:
		sources.append(world.introduce_fact("exposure", "DOMAIN-001", target, [target], [_origin(world)], {"public": false}, [], ["DOMAIN-001/order"]))
	_padding(world, 2000)
	world.history.reset_metrics()
	var plan: Dictionary = world.choose_plan("DOMAIN-001")
	_check("HIST-006", "超过查询页长的有效暴露仍完整保留同目标全部父因果", plan.get("rule") == "RESIST_TRACE" and plan.get("target") == target and plan.get("parents") == sources, {"parentCount": plan.get("parents", []).size(), "metrics": world.history.metrics.duplicate(true)})

func _growth() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	Store.entry(world.state.npcs, actor).adaptation = 1
	var sources: Array = []
	for i: int in 3:
		sources.append(_miracle(world, actor))
	_padding(world, 2000)
	for i: int in 6:
		world.advance()
	var learned: Array = HistoryIndex.values(Store.entry(world.state.npcs, actor).growth_sources.adaptation)
	var old_value: int = Store.entry(world.state.npcs, actor).adaptation
	var restored: RefCounted = World.new(catalog)
	var loaded: bool = restored.restore(world.snapshot())
	for i: int in 8:
		restored.advance()
	_check("HIST-007", "成长与消费索引按真实不同来源去重，重建续存后旧来源不能再学习", loaded and old_value == 2 and learned == sources and Store.entry(restored.state.npcs, actor).adaptation == old_value and HistoryIndex.values(Store.entry(restored.state.npcs, actor).growth_sources.adaptation) == sources, {"sources": sources, "learned": learned, "before": old_value, "after": Store.entry(restored.state.npcs, actor).adaptation})

func _rollback() -> void:
	var data: Dictionary = _attach(_world())
	_open(data)
	var prior: Dictionary = _request(data, "act", "empty")
	assert(data.turn.submit(prior).ok)
	var before: String = data.turn.snapshot()
	var actor: String = _person(data.world)
	var chosen: Dictionary = data.world.choose_behavior(actor)
	var response: Dictionary = data.turn.submit(_request(data, "act", "fail_after_source"))
	var after: Dictionary = data.world.choose_behavior(actor)
	var retry: Dictionary = data.turn.submit(prior)
	_check("HIST-008", "产生可用来源后失败回滚索引、世界和随机，先前成功回执保持", not response.ok and before == data.turn.snapshot() and chosen == after and retry.ok, {"rejection": response.get("error", ""), "beforeCandidate": chosen, "afterCandidate": after})

func _paging() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	_padding(world, 75)
	var expected: Array = HistoryIndex.values(Store.entry(world.state.npcs, actor).known_facts)
	var first: Dictionary = world.history.query(world.state, "person_knowledge", actor)
	var another: RefCounted = _world()
	_padding(another, 75)
	var cross_world: Dictionary = another.history.query(another.state, "person_knowledge", actor, first.cursor)
	var page: Dictionary = first
	var returned: Array = []
	var valid: bool = first.ok and not first.complete and first.items.size() == world.history.page_limit
	var page_count: int = 0
	while page.ok:
		page_count += 1
		for fact: Dictionary in page.items:
			returned.append(fact.id)
		if page.complete:
			break
		page = world.history.query(world.state, "person_knowledge", actor, page.cursor)
		valid = valid and page.ok
	var oversized: Dictionary = world.history.query(world.state, "person_knowledge", actor, {}, world.history.page_limit + 1)
	var wrong: Dictionary = world.history.query(world.state, "institution_knowledge", "DOMAIN-001/order", first.cursor)
	var bad_policy: Dictionary = first.cursor.duplicate()
	bad_policy.policy = "unrelated-policy"
	var policy: Dictionary = world.history.query(world.state, "person_knowledge", actor, bad_policy)
	var source: String = world.introduce_fact("message", "DOMAIN-001", actor, [actor], [_origin(world)], {}, [actor])
	var stale: Dictionary = world.history.query(world.state, "person_knowledge", actor, first.cursor)
	var before_restore: Dictionary = world.history.query(world.state, "person_knowledge", actor)
	var loaded: bool = world.restore(world.snapshot())
	world.ensure_history()
	var stale_restore: Dictionary = world.history.query(world.state, "person_knowledge", actor, before_restore.cursor)
	_check("HIST-009", "分页完整读出全部来源；超限、错范围/策略、跨世界、更新及读档前游标拒绝", valid and returned == expected and page_count > 1 and not oversized.ok and not wrong.ok and not policy.ok and not cross_world.ok and not source.is_empty() and not stale.ok and loaded and not stale_restore.ok, {"items": returned.size(), "pages": page_count, "limit": world.history.page_limit, "complete": page.complete, "staleRejected": not stale.ok, "crossWorldRejected": not cross_world.ok, "restoreCursorRejected": not stale_restore.ok})

func _load_audit() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	_miracle(world, actor)
	_padding(world, 2000)
	var before: String = world.snapshot()
	var encoded: Dictionary = JSON.parse_string(before)
	Store.entry(encoded.body.state.npcs, actor).known_facts.append("FACT-MISSING")
	encoded.checksum = World.canonical(World._normalize_numbers(encoded.body)).sha256_text()
	var accepted: bool = world.restore(World.canonical(encoded))
	_check("HIST-010", "读档索引重建前全量审计拒绝坏历史引用，当前世界保持", not accepted and before == world.snapshot())
	var rejected: bool = true
	for malformed: Variant in [{"$history_index": 1, "kind": "list", "root": {}}, 17, [_origin(world), _origin(world)], [world.state.domains["DOMAIN-002"].origin, _origin(world)]]:
		encoded = JSON.parse_string(before)
		Store.entry(encoded.body.state.npcs, actor).known_facts = malformed
		encoded.checksum = JSON.stringify(World._normalize_numbers(encoded.body), "", true, true).sha256_text()
		rejected = not world.restore(JSON.stringify(encoded, "", true, true)) and world.snapshot() == before and rejected
	var data: Dictionary = _attach(_world())
	_open(data)
	var request: Dictionary = _request(data, "act", "empty")
	request.payload["forged"] = {"$history_index": 1, "kind": "list", "root": {}}
	before = data.turn.snapshot()
	var response: Dictionary = data.turn.submit(request)
	_check("HIST-012", "外部存档及请求不能伪装内部历史树或以错误历史类型进入权威状态", rejected and not response.ok and before == data.turn.snapshot(), {"malformedSavesRejected": rejected, "reservedMarkerRequestRejected": not response.ok})

func _receipt_case(count: int) -> Dictionary:
	var data: Dictionary = _attach(_world())
	_open(data)
	data.world.state = _plain(data.world.state)
	data.turn.context = _plain(data.turn.context)
	var replay_request: Dictionary = {}
	for i: int in count:
		var id: String = "HIST-PAST-%05d" % i
		var request: Dictionary = {"id": id, "op": "act", "turn": 1, "phase": "actions", "participant": "history-fixture", "action": "empty", "payload": {}}
		Store.put(data.turn.context.receipts, id, {"request": request, "fingerprint": World.canonical(request).sha256_text(), "response": {"ok": true, "turn": 1, "phase": "actions", "result": {"checks": [], "outcome": ""}}})
		replay_request = request
		var job: String = "HIST-DONE-%05d" % i
		var fact: String = data.world._record("turn_scheduled", "", "", [], [_origin(data.world)], {"id": job, "phase": "start", "due": 1, "participant": "history-fixture"})
		Store.put(data.turn.context.completed_jobs, job, {"turn": 1, "phase": "start", "source": fact, "participant": "history-fixture"})
	data.turn.commit_sequence = Store.size(data.turn.context.receipts)
	assert(data.turn.preview_plan("history-fixture", {}).ok) # Full external-root adoption is deliberately outside ordinary cost.
	data.world.history.reset_metrics()
	var preview: Dictionary = data.turn.preview_plan("history-fixture", {})
	var result: Dictionary = data.turn.submit(_request(data, "act", "empty"))
	var metrics: Dictionary = data.world.history.metrics.duplicate(true)
	var transaction: Dictionary = data.turn.last_transaction_metrics.duplicate(true)
	var snapshot: String = data.turn.snapshot()
	var replay_ok: bool = true
	if not replay_request.is_empty():
		replay_ok = data.turn.submit(replay_request).ok and data.turn.snapshot() == snapshot
	return {"ok": preview.ok and result.ok and replay_ok, "metrics": metrics, "transaction": transaction, "completed": Store.size(data.turn.context.completed_jobs), "receipts": Store.size(data.turn.context.receipts)}

func _receipts() -> void:
	var small: Dictionary = _receipt_case(0)
	var large: Dictionary = _receipt_case(1000)
	var valid: bool = small.ok and large.ok
	for key: String in ["history_scanned", "rebuild_records", "copied_history_values"]:
		valid = valid and small.metrics[key] == 0 and large.metrics[key] == 0
	for key: String in ["decision_reads", "current_entities", "copied_current_objects", "output_sources"]:
		valid = valid and small.metrics[key] == large.metrics[key]
	_check("HIST-011", "1000旧回执和完成工作不进入普通读取/深复制，旧请求仍按键幂等返回", valid, {"small": small, "large": large})

func _anomaly() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	var anomaly: String = world.introduce_fact("public_anomaly", "DOMAIN-001", actor, [actor], [_origin(world)], {}, [actor])
	_padding(world, 2000)
	var active: bool = world._has_public_anomaly(world.state, "DOMAIN-001")
	var missing: bool = world.submit({"kind": "status", "npc": actor, "status": "missing", "parents": [anomaly]})
	var temporarily_off: bool = not world._has_public_anomaly(world.state, "DOMAIN-001")
	var restored: bool = world.submit({"kind": "status", "npc": actor, "status": "active", "parents": [Store.entry(world.state.npcs, actor).status_source]})
	var back_on: bool = world._has_public_anomaly(world.state, "DOMAIN-001")
	var resolved: String = world.introduce_fact("anomaly_resolved", "DOMAIN-001", actor, [actor], [anomaly, _origin(world)], {"source": anomaly}, [actor])
	var off: bool = not world._has_public_anomaly(world.state, "DOMAIN-001")
	missing = world.submit({"kind": "status", "npc": actor, "status": "missing", "parents": [resolved]}) and missing
	restored = world.submit({"kind": "status", "npc": actor, "status": "active", "parents": [Store.entry(world.state.npcs, actor).status_source]}) and restored
	var normal_valid: bool = active and missing and restored and temporarily_off and back_on and off and not resolved.is_empty() and not world._has_public_anomaly(world.state, "DOMAIN-001") and Store.has(world.state.facts, anomaly) and Store.has(world.state.facts, resolved)
	var before: String = world.snapshot()
	var resurrection: RefCounted = Transaction.new(world, {"receipts": {}, "completed_jobs": {}, "journal": []})
	resurrection.touch_world(["domains"])
	resurrection.candidate.domains["DOMAIN-001"].public_anomalies = HistoryIndex.set_value(resurrection.candidate.domains["DOMAIN-001"].public_anomalies, anomaly, actor, "map")
	var resurrection_errors: Array = resurrection.validate_world()
	var resurrection_rejected: bool = not resurrection_errors.is_empty() and world.snapshot() == before
	# A direct transaction freezes its trusted base. Use a fresh standalone world
	# for the independent malformed-removal fixture, not a write into that base.
	world = _world()
	actor = _person(world)
	var second: String = world.introduce_fact("public_anomaly", "DOMAIN-001", actor, [actor], [_origin(world)], {}, [actor])
	assert(not second.is_empty())
	world.ensure_history()
	before = world.snapshot()
	var malformed: RefCounted = Transaction.new(world, {"receipts": {}, "completed_jobs": {}, "journal": []})
	malformed.touch_world(["domains", "facts"])
	malformed.candidate.domains["DOMAIN-001"].public_anomalies = HistoryIndex.erase(malformed.candidate.domains["DOMAIN-001"].public_anomalies, second)
	Store.put(malformed.candidate.facts, "FACT-%08d" % int(malformed.candidate.next_fact), "bad")
	malformed.candidate.next_fact += 1
	var malformed_errors: Array = malformed.validate_world()
	var malformed_rejected: bool = not malformed_errors.is_empty() and world.snapshot() == before
	_check("HIST-013", "异常暂失效可恢复、已解除来源不能复活；错误解除候选正常拒绝", normal_valid and resurrection_rejected and malformed_rejected, {"resolvedSourceResurrectionRejected": resurrection_rejected, "resurrectionErrors": resurrection_errors, "scalarFactRemovalRejected": malformed_rejected, "malformedErrors": malformed_errors})

func _comfort_causes() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	var target: String = _person(world, "interpretation")
	Store.entry(world.state.npcs, actor).loyalty = 80
	Store.entry(world.state.npcs, target).loyalty = 80
	Store.entry(world.state.npcs, target).sanity = 20
	var relation: String = world._record("relationship", "DOMAIN-001", actor, [target], [_origin(world)], {"kind": "support"})
	var later_relation: String = world._record("relationship", "DOMAIN-001", actor, [target], [_origin(world)], {"kind": "support"})
	Store.entry(world.state.npcs, actor).relations = [{"target": target, "kind": "support", "source": relation}, {"target": target, "kind": "support", "source": later_relation}]
	var harm: String = world.introduce_fact("harm", "DOMAIN-001", target, [target], [_origin(world)], {}, [actor, target])
	_padding(world, 2000)
	var chosen: Dictionary = world.choose_behavior(actor)
	world.advance()
	var committed: bool = false
	for fact: Dictionary in Store.values(world.state.facts):
		if fact.kind == "npc_behavior" and fact.actor == actor and fact.changes.behavior == "NPC_COMFORT":
			committed = fact.causal_parents == [later_relation, harm]
	_check("HIST-014", "安抚保留原有后关系覆盖语义与伤害双因果，无关最近历史不串入", chosen.get("behavior") == "NPC_COMFORT" and chosen.get("parents") == [later_relation, harm] and committed, {"parents": chosen.get("parents", []), "expectedLastRelation": later_relation, "committed": committed})

func _persistent_tree() -> void:
	var values: Array = []
	for i: int in 2000:
		values.append("SOURCE-%06d" % i)
	var index: RefCounted = HistoryIndex.new()
	var old: Dictionary = HistoryIndex.from_value(values)
	var container: Dictionary = {"history": old, "current": {"value": 1}}
	index.reset_metrics()
	var copy: Dictionary = HistoryIndex.copy_current(container)
	var next: Dictionary = HistoryIndex.set_value(old, "SOURCE-NEW")
	var allocated: int = index.metrics.tree_nodes_allocated
	var removed: Dictionary = HistoryIndex.erase(next, "SOURCE-000000")
	var structural: bool = old.is_read_only() and old.root.is_read_only() and is_same(copy.history, old) and not is_same(copy.current, container.current)
	var first_world: RefCounted = _world()
	var other_world: RefCounted = _world()
	_padding(first_world, 75)
	_padding(other_world, 75)
	first_world.history.reset_metrics()
	other_world.history.reset_metrics()
	var page: Dictionary = first_world.history.query(first_world.state, "person_knowledge", _person(first_world), {}, 1)
	var isolated_metrics: bool = page.ok and first_world.history.metrics.tree_nodes_read > 0 and other_world.history.metrics.tree_nodes_read == 0
	_check("HIST-015", "持久历史树共享旧节点，追加和撤销仅改新路径；跨世界查询计量隔离", isolated_metrics and structural and HistoryIndex.size(old) == 2000 and HistoryIndex.size(next) == 2001 and HistoryIndex.size(removed) == 2000 and HistoryIndex.has(old, "SOURCE-000000") and not HistoryIndex.has(old, "SOURCE-NEW") and not HistoryIndex.has(removed, "SOURCE-000000") and allocated < 64, {"oldRecords": HistoryIndex.size(old), "allocatedNodesForAppend": allocated, "immutableSharedTree": structural, "perWorldMetricsIsolated": isolated_metrics, "firstWorldTreeReads": first_world.history.metrics.tree_nodes_read, "otherWorldTreeReads": other_world.history.metrics.tree_nodes_read})

func _tree_shape(node: Dictionary) -> Dictionary:
	if node.is_empty():
		return {"ok": true, "height": 0, "count": 0, "min": "", "max": ""}
	var left: Dictionary = _tree_shape(node.left)
	var right: Dictionary = _tree_shape(node.right)
	var count: int = 1 + int(left.count) + int(right.count)
	var height: int = 1 + maxi(int(left.height), int(right.height))
	var ordered: bool = (left.count == 0 or str(left.max) < str(node.key)) and (right.count == 0 or str(node.key) < str(right.min))
	return {"ok": left.ok and right.ok and ordered and node.is_read_only() and node.count == count and node.height == height and absi(int(left.height) - int(right.height)) <= 1, "height": height, "count": count, "min": left.min if left.count > 0 else node.key, "max": right.max if right.count > 0 else node.key}

func _tree_mutations() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 20261026
	var reference: Dictionary = {}
	var tree: Dictionary = HistoryIndex.from_value(reference, "map")
	var valid: bool = true
	var maximum_height: int = 0
	for step: int in 400:
		var old: Dictionary = tree
		var before: String = World.canonical(old)
		var key: String = "KEY-%03d" % random.randi_range(0, 99)
		if random.randi_range(0, 2) == 0:
			reference.erase(key)
			tree = HistoryIndex.erase(tree, key)
		else:
			reference[key] = step
			tree = HistoryIndex.set_value(tree, key, step, "map")
		var shape: Dictionary = _tree_shape(tree.root)
		maximum_height = maxi(maximum_height, int(shape.height))
		valid = valid and shape.ok and before == World.canonical(old) and World.canonical(tree) == World.canonical(reference) and HistoryIndex.size(tree) == reference.size()
	var aliases: Array = []
	for method: String in ["from_value", "set_value"]:
		var nested: Array = []
		var input_value: Dictionary = {"items": nested}
		input_value.make_read_only()
		var sealed: Dictionary = HistoryIndex.from_value({"x": input_value}, "map") if method == "from_value" else HistoryIndex.set_value(HistoryIndex.from_value({}, "map"), "x", input_value, "map")
		var exported: String = World.canonical(sealed)
		nested.append("later")
		var unchanged: bool = World.canonical(sealed) == exported and HistoryIndex.mapget(sealed, "x").items.is_empty() and HistoryIndex.mapget(sealed, "x").items.is_read_only()
		valid = valid and unchanged
		aliases.append({"method": method, "oldTreeUnchanged": unchanged})
	_check("HIST-017", "400次确定随机增删对照与浅只读输入别名隔离，排序/计数/平衡高度和旧根不可变", valid, {"steps": 400, "remaining": reference.size(), "maximumHeight": maximum_height, "shallowReadonlyAliases": aliases})

func _policy() -> void:
	var index: RefCounted = HistoryIndex.new()
	var original: String = FileAccess.get_file_as_string("res://data/fidelity_parameters.csv")
	var path: String = "user://history-invalid-policy.csv"
	var expected: int = 0
	for line: String in original.split("\n"):
		if line.begins_with("decision_query_page_limit,"):
			expected = int(line.get_slice(",", 1))
	var valid: bool = expected > 0 and index.page_limit == expected
	var cases: Array = []
	for replacement: String in ["0", "-1", "2.5", "not-a-number"]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original.replace("decision_query_page_limit,%d," % expected, "decision_query_page_limit," + replacement + ","))
		file.close()
		var rejected: bool = not index.load_policy(path)
		valid = valid and rejected
		cases.append({"value": replacement, "rejected": rejected})
	var policy_line: String = ""
	for line: String in original.split("\n"):
		if line.begins_with("decision_query_page_limit,"):
			policy_line = line
	for fixture: Dictionary in [{"name": "duplicate", "text": original + "\n" + policy_line + "\n"}, {"name": "missing", "text": original.replace(policy_line, "")}]:
		var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		output.store_string(fixture.text)
		output.close()
		var rejected: bool = not index.load_policy(path)
		valid = valid and rejected
		cases.append({"value": fixture.name, "rejected": rejected})
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	valid = index.load_policy(path) and index.page_limit == expected and valid
	_check("HIST-016", "正式CSV查询页长策略拒绝非法数值、重复和缺失，合法策略可加载", valid, {"cases": cases, "pageLimit": index.page_limit})

func _bad_candidates() -> void:
	var world: RefCounted = _world()
	var actor: String = _person(world)
	for i: int in 3:
		_miracle(world, actor)
	for i: int in 6:
		world.advance()
	_padding(world, 0, 1)
	var dead_evidence: String = ""
	for key: String in Store.keys(world.state.evidence):
		if key not in world.history.current_ids(world.state, "evidence"):
			dead_evidence = key
			break
	assert(not dead_evidence.is_empty())
	var before: String = world.snapshot()
	var valid: bool = true
	var cases: Array = []
	for name: String in ["scalar_knowledge", "array_consumed", "wrong_kind_marker", "erase_knowledge", "erase_consumed", "erase_growth", "scalar_collection", "scalar_member", "erase_dead_evidence", "erase_institution"]:
		var tx: RefCounted = Transaction.new(world, {"receipts": {}, "completed_jobs": {}, "journal": []})
		tx.touch_world(["npcs", "evidence", "institutions"])
		match name:
			"erase_dead_evidence": Store.erase(tx.candidate.evidence, dead_evidence)
			"erase_institution": tx.candidate.institutions.erase("DOMAIN-001/order")
			"scalar_collection": tx.candidate.npcs = 42
			"scalar_member": Store.put(tx.candidate.npcs, actor, "bad")
			"scalar_knowledge": Store.entry(tx.candidate.npcs, actor).known_facts = 42
			"array_consumed": Store.entry(tx.candidate.npcs, actor).consumed_sources = []
			"wrong_kind_marker": Store.entry(tx.candidate.npcs, actor).known_facts = HistoryIndex.from_value({}, "map")
			"erase_knowledge": Store.entry(tx.candidate.npcs, actor).known_facts = HistoryIndex.from_value([])
			"erase_consumed": Store.entry(tx.candidate.npcs, actor).consumed_sources = HistoryIndex.from_value({}, "map")
			"erase_growth": Store.entry(tx.candidate.npcs, actor).growth_sources = {}
		var errors: Array = tx.validate_world()
		var rejected: bool = not errors.is_empty() and world.snapshot() == before
		valid = valid and rejected
		cases.append({"case": name, "rejected": rejected, "errors": errors})
	_check("HIST-018", "最终候选不能把错误历史形状自动清洗为空，也不能清除既成记忆/消费/成长", valid, {"cases": cases})

func _reader_lifetime() -> void:
	var data: Dictionary = _attach(_world())
	_open(data)
	var valid: bool = true
	var cases: Array = []
	for action: String in ["reader_clear", "reader_replace"]:
		var result: Dictionary = data.turn.submit(_request(data, "act", action))
		var inside: Dictionary = data.adapter.reader_check
		var before: String = data.turn.snapshot()
		var expired_fact: Dictionary = data.adapter.saved_reader.fact(_origin(data.world))
		var expired_page: Dictionary = data.adapter.saved_reader.history_query("person_knowledge", _person(data.world))
		var restored: Dictionary = _attach(_world())
		var roundtrip: bool = restored.turn.restore(before)
		var accepted: bool = result.ok and inside.fact.ok and inside.page.ok and inside.page.items.size() == 1 and not expired_fact.ok and not expired_page.ok and data.turn.snapshot() == before and roundtrip
		valid = valid and accepted
		cases.append({"action": action, "acceptedAndIsolated": accepted, "expiredFact": expired_fact, "expiredPage": expired_page, "restorable": roundtrip})
	_check("HIST-019", "回调可清空或替换自己的view，reader仍安全关闭且缓存访问被拒绝", valid, {"cases": cases})

func _cache_guard() -> void:
	var data: Dictionary = _attach(_world())
	_open(data)
	data.adapter.attacked_world = data.world
	var valid: bool = true
	var cases: Array = []
	for action: String in ["cache_clear", "cache_replace"]:
		var before: String = data.turn.snapshot()
		var index: RefCounted = data.world.history
		var selected: Dictionary = data.world.choose_behavior(_person(data.world))
		var result: Dictionary = data.turn.submit(_request(data, "act", action))
		var rejected: bool = not result.ok and is_same(index, data.world.history) and data.turn.snapshot() == before and data.world.choose_behavior(_person(data.world)) == selected
		valid = valid and rejected
		cases.append({"action": action, "rejectedAndRestored": rejected, "response": result})
	_check("HIST-020", "回调清空或替换公开索引对象被拒绝并恢复既有状态与查询", valid, {"cases": cases})
