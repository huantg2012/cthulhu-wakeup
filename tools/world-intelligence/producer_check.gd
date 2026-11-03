extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Knowledge = preload("res://src/game/player_knowledge.gd")
const Producer = preload("res://src/game/world_observations.gd")
const Intel = preload("res://src/game/world_intelligence.gd")
const World = preload("res://src/simulation/world.gd")
const DIRECTORY := "res://.godot/world-observation-check"
const LEGACY := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
var checks: Array[String] = []

class ContactTransaction extends RefCounted:
	var base_state: Dictionary = {}

class ContactFixture extends RefCounted:
	var state: Dictionary
	var catalog: RefCounted
	var transaction := ContactTransaction.new()
	func _driver_allowed(_owner: Object) -> bool: return true
	func stage_collections(_names: Array) -> void: pass
	func _record(kind: String, domain: String, actor: String, targets: Array, parents: Array, changes: Dictionary) -> String:
		var id: String = "FACT-%08d" % int(state.next_fact)
		state.next_fact += 1
		state.facts[id] = {"id": id, "turn": state.turn, "kind": kind, "domain": domain, "actor": actor, "targets": targets, "causal_parents": parents, "changes": changes.duplicate(true)}
		return id

class ContactOwner extends RefCounted:
	var context: Dictionary

func _initialize() -> void: _run.call_deferred()
func need(ok: bool, label_value: String, detail: Variant = "") -> bool:
	if not ok:
		push_error("OBSERVATION_CHECK " + label_value + ": " + str(detail)); quit(1); return false
	checks.append(label_value); return true

func observations(session: RefCounted) -> Array:
	return Store.values(session.world.state.facts).filter(func(fact: Dictionary) -> bool: return fact.kind == "world_observation")

func actions(session: RefCounted) -> bool:
	for step: int in range(8):
		if session.turn.context.phase == "actions": return true
		if not need(session.progress().get("ok", false), "正式阶段推进", session.last_error): return false
	return need(false, "抵达行动阶段")

func listen_selection(session: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for proof: Dictionary in session.modules.player_sources.available(session.turn):
		var target: Dictionary = Store.entry(session.world.state.facts, str(proof.changes.get("basis", {}).get("fact", "")), {})
		if proof.changes.get("rule") == "listen" and target.get("kind") == "world_observation" and session.is_known_source(proof.id): result = {"domain": proof.domain, "source": proof.id, "target": target.id}
	return result

func response(session: RefCounted) -> String:
	for prayer: Dictionary in session.project().prayers:
		for variant: String in ["deep", "shallow"]:
			var key: String = str(prayer.key) + "/" + variant
			if session.preview_action(key, {}).get("ok", false): return key
	return ""

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var fresh := Session.new(DIRECTORY + "/fresh")
	if not need(fresh.start_new(1).get("ok", false), "新局真实首次接触生成来源", fresh.last_error): return
	if not need(not observations(fresh).is_empty(), "初见有冻结私有四维快照"): return
	for snapshot: Dictionary in observations(fresh):
		if not need(not fresh.is_known_source(snapshot.id), "初见精确快照不会直接公开"): return
	if not actions(fresh): return
	var choice: Dictionary = listen_selection(fresh)
	if not need(not choice.is_empty(), "公开 message 沿原 player_sources 产生可见聆听资格"): return
	var target: String = choice.target; choice.erase("target")
	var illicit: Dictionary = fresh.knowledge_snapshot()
	illicit.known_facts[target] = true
	if not need(not Knowledge.validate_ledger(fresh.world.state, illicit, fresh.catalog).is_empty(), "恢复校验拒绝未聆听却注入知情表的私有快照"): return
	var captured: Dictionary = Store.entry(fresh.world.state.facts, target).changes.metrics.duplicate(true)
	var count: int = observations(fresh).size()
	var whispers: int = fresh.world.state.whispers; var faith: int = fresh.world.state.faith
	var entropy: Dictionary = {}
	for stream: String in fresh.world.randoms: entropy[stream] = fresh.world.randoms[stream].state
	if not need(fresh.preview_action("POWER_LISTEN", choice).get("ok", false), "原聆听动作可预览此来源", choice): return
	var heard: Dictionary = fresh.execute_action("POWER_LISTEN", choice, true, "OBS/LISTEN")
	if not need(heard.get("ok", false), "通过正式动作聆听真实世界快照", heard): return
	if not need(fresh.is_known_source(target) and observations(fresh).size() == count, "聆听显式揭示目标且自身察觉不循环生产"): return
	var visible: Dictionary = fresh.project().domains.filter(func(row: Dictionary) -> bool: return row.id == choice.domain)[0]
	for field: String in captured:
		if not need(visible[field] == captured[field] and visible.metric_sources[field].precision == "exact", "聆听揭示历史 " + field): return
	if not need(visible.alert != fresh.world.state.domains[choice.domain].alert, "聆听显示冻结察觉而不是付费后实时察觉"): return
	if not need(fresh.world.state.whispers == whispers - int(fresh.catalog.tables.powers.POWER_LISTEN.whispers) and fresh.world.state.faith == faith, "只收原聆听费用"): return
	for stream: String in entropy:
		if not need(fresh.world.randoms[stream].state == entropy[stream], "观测/确定性聆听不消费随机流 " + stream): return
	var after_listen: String = fresh.turn.snapshot()
	if not need(fresh.execute_action("POWER_LISTEN", choice, true, "OBS/LISTEN").get("ok", false) and fresh.turn.snapshot() == after_listen and not fresh.preview_action("POWER_LISTEN", choice).get("ok", false), "持久动作重放幂等且快照只能聆听一次"): return
	var response_key: String = response(fresh)
	if not need(not response_key.is_empty(), "可实际回应当前具体人的祈求"): return
	var acted: Dictionary = fresh.execute_action(response_key, {}, true, "OBS/PRAYER")
	if not need(acted.get("ok", false) and observations(fresh).size() > count, "真实回应的四维干预产生后续接触快照", acted): return
	var newest: Dictionary = observations(fresh)[-1]
	if not need(not fresh.is_known_source(newest.id) and not acted.get("facts", []).any(func(fact: Dictionary) -> bool: return fact.kind == "world_observation"), "自己的行动因果后代及行动回执不泄露新精确快照"): return
	var ledger: Dictionary = Knowledge.learn(fresh.world.state, fresh.turn.context, fresh.knowledge_snapshot(), fresh.catalog, fresh.world.history, newest.id)
	if not need(not ledger.known_facts.has(newest.id), "普通 learn 调用不能绕过显式聆听"): return
	var stable: String = fresh.turn.snapshot()
	fresh.project(); fresh.action_catalog(); fresh.project()
	if not need(fresh.turn.snapshot() == stable, "浏览不会生产或刷新快照"): return
	var saved: Dictionary = fresh.save_game()
	var restored := Session.new(DIRECTORY + "/fresh")
	if not need(restored.continue_game(saved.path).get("ok", false) and restored.turn.snapshot() == stable, "公开区间/私有快照/已听确值/消费记录保存恢复等值", restored.last_error): return
	var forged_save: Dictionary = World._normalize_numbers(JSON.parse_string(stable))
	forged_save.body.context.player_knowledge.known_facts[newest.id] = true
	forged_save.checksum = World.canonical(forged_save.body).sha256_text()
	if not need(not restored.turn.restore(World.canonical(forged_save)) and restored.turn.snapshot() == stable, "重签存档也不能越过付费聆听来源且失败完整回滚"): return
	# Restore an unchanged real T3 save, then observe recurring actual offerings.
	var legacy_hash: String = FileAccess.get_sha256(LEGACY)
	var copy: String = DIRECTORY + "/legacy-t3.json"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY), ProjectSettings.globalize_path(copy))
	var old := Session.new(DIRECTORY)
	if not need(old.continue_game(copy).get("ok", false) and observations(old).is_empty(), "旧 T3 恢复时不回填快照", old.last_error): return
	if not actions(old): return
	for round_index: int in range(3):
		if not need(old.progress(true).get("ok", false), "真实结束第 " + str(old.turn.context.turn) + " 轮", old.last_error): return
		if not actions(old): return
	var offerings: Array = observations(old).filter(func(snapshot: Dictionary) -> bool:
		return snapshot.changes.sources.any(func(source: String) -> bool: return Store.entry(old.world.state.facts, source).kind == "economy_income"))
	if not need(offerings.size() >= 2, "真实教团供奉在多个回合持续产生来源", observations(old)): return
	if not need(not offerings[0].changes.observer.is_empty() and not offerings[0].changes.cult.is_empty() and offerings[0].turn < offerings[-1].turn, "持续来源绑定具名领袖/教团与不同真实回合"): return
	if not need(FileAccess.get_sha256(LEGACY) == legacy_hash, "T3 原证据字节未变"): return
	var next_choice: Dictionary = listen_selection(old)
	if not need(not next_choice.is_empty(), "旧局后续真实接触出现可用聆听来源"): return
	next_choice.erase("target")
	var old_save: Dictionary = old.save_game()
	var old_restored := Session.new(DIRECTORY)
	if not need(old_restored.continue_game(old_save.path).get("ok", false), "续玩生成的观测可存读", old_restored.last_error): return
	var left: Dictionary = old.execute_action("POWER_LISTEN", next_choice, true, "OBS/OLD/LISTEN")
	var right: Dictionary = old_restored.execute_action("POWER_LISTEN", next_choice, true, "OBS/OLD/LISTEN")
	if not need(left.get("ok", false) and right.get("ok", false) and old.turn.snapshot() == old_restored.turn.snapshot(), "旧局存读后聆听同一新快照结果等值", [left, right]): return
	# Explicit contact eligibility fixtures, independent of economic RNG/balance.
	var sample: Dictionary = offerings[-1]
	var income: Dictionary = {}
	for source: String in sample.changes.sources:
		if Store.entry(old.world.state.facts, source).kind == "economy_income": income = Store.entry(old.world.state.facts, source).duplicate(true)
	var model: Dictionary = History.export_value(old.world.state)
	var row: Dictionary = old.catalog.tables.world_observation_sources.OBS_OFFERING
	income.changes.actual = 0; income.changes.reason = ""
	if not need(not Producer._contact(model, income, row, old.knowledge_snapshot(), old.catalog).is_empty(), "容量已满 actual=0 不抹掉真实供奉联系"): return
	income.changes.reason = "leader_unavailable"
	if not need(Producer._contact(model, income, row, old.knowledge_snapshot(), old.catalog).is_empty(), "明确未能供奉的回执不提供观测"): return
	income.changes.reason = ""; model.cults[income.changes.cult].leader = ""
	if not need(Producer._contact(model, income, row, old.knowledge_snapshot(), old.catalog).is_empty(), "无有效领袖不虚构观测联系人"): return
	# Detached producer contracts: empty input, wrapping, grouping and same-turn order.
	var fixture := ContactFixture.new(); fixture.state = History.export_value(old.world.state); fixture.catalog = old.catalog
	fixture.transaction.base_state = fixture.state.duplicate(true)
	var owner := ContactOwner.new(); owner.context = {"turn": old.turn.context.turn, "phase": "actions"}
	var prior: Dictionary = old.knowledge_snapshot()
	var baseline: String = World.canonical(fixture.state)
	if not need(Producer.publish(fixture, owner, prior, prior, fixture.state.next_fact).is_empty() and World.canonical(fixture.state) == baseline, "没有合法新来源时安静退化且不写世界"): return
	var domain: String = str(income.domain)
	var first: int = fixture.state.next_fact
	var wrapper: String = fixture._record("event_fixed", domain, "", [], [income.id], {"candidate": {"id": "FIXTURE-EVENT-1", "content_id": "EVENT_02", "descriptor": {"source": income.id}}})
	fixture.state.event_system.selected.append("FIXTURE-EVENT-1")
	var known: Dictionary = prior.duplicate(true); known.known_facts[wrapper] = true
	baseline = World.canonical(fixture.state)
	if not need(Producer.publish(fixture, owner, prior, known, first).is_empty() and World.canonical(fixture.state) == baseline, "已观察原来源被事件重新包装不会另造快照/资格"): return
	var personal: Dictionary = fixture.state.facts[wrapper].duplicate(true)
	personal.changes.candidate.content_id = "EVENT_01"
	if not need(Producer._contact(fixture.state, personal, old.catalog.tables.world_observation_sources.OBS_EVENT, known, old.catalog).is_empty(), "人物个人事件不被当作整个世界观测"): return
	first = fixture.state.next_fact
	var action_root: String = fixture._record("power_attempt", domain, "", [], [], {"power": "POWER_DREAM"})
	known.known_facts[action_root] = true
	for field: String in ["pollution", "alert"]:
		var delta: String = fixture._record("power_effect", domain, "", [], [action_root], {"power": "POWER_DREAM", "field": field, "actual": 1})
		known.known_facts[delta] = true
	var generated: Array[String] = Producer.publish(fixture, owner, prior, known, first)
	if not need(generated.size() == 1, "同事务同域的多个真实干预合为一条有源线索"): return
	var message: Dictionary = fixture.state.facts[generated[0]]
	var frozen: Dictionary = fixture.state.facts[message.changes.fact]
	if not need(Intel.valid_snapshot(fixture.state, frozen, old.catalog), "合并快照保留全部真实原因和公开消息绑定"): return
	var broken_index: Dictionary = fixture.state.duplicate(true)
	broken_index.applied_authorizations.erase(Intel.observation_source_key(domain, action_root))
	if not need(not Intel.valid_snapshot(broken_index, frozen, old.catalog), "删除原来源消费索引会被恢复校验拒绝"): return
	var exact: Dictionary = Intel.observed_fact(frozen)
	var estimate: Dictionary = message.changes.intelligence
	if not need(Intel.newer(exact.pollution, estimate.pollution) and not Intel.newer(estimate.pollution, exact.pollution), "同一快照的精确揭示优先于较晚包装的粗略消息"): return
	baseline = World.canonical(fixture.state)
	if not need(Producer.publish(fixture, owner, prior, known, first).is_empty() and World.canonical(fixture.state) == baseline, "再次分发同批来源不重复产出"): return
	var stale: Dictionary = frozen.duplicate(true); stale.turn -= 1
	if not need(not Intel.newer(Intel.observed_fact(stale).pollution, estimate.pollution), "旧快照精确值不覆盖新轮区间"): return
	var event_root: String = fixture._record("miracle", domain, "", [], [], {})
	var delayed: String = fixture._record("event_fixed", domain, "", [], [event_root], {"candidate": {"id": "FIXTURE-EVENT-2", "content_id": "EVENT_02", "descriptor": {"source": event_root}}})
	fixture.state.event_system.selected.append("FIXTURE-EVENT-2")
	known.known_facts[delayed] = true
	if not need(Producer.publish(fixture, owner, prior, known, fixture.state.next_fact).size() == 1, "早已冻结但本次才正式呈现的机构事件可产生有源观测"): return
	fixture.state.event_system.selected.erase("FIXTURE-EVENT-2")
	if not need(Producer._contact(fixture.state, fixture.state.facts[delayed], old.catalog.tables.world_observation_sources.OBS_EVENT, known, old.catalog).is_empty(), "历史事件回看不算当前世界接触"): return
	fixture.state.domains[domain].alert = old.catalog.integer("attribute_max")
	var capped_before: Dictionary = fixture.state.duplicate(true)
	for pair: Array in [["prayer_delta", "OBS_PRAYER"], ["event_delta", "OBS_EVENT_DELTA"]]:
		var capped_id: String = fixture._record(pair[0], domain, "", [domain], [], {"field": "alert", "subject": "domain", "amount": 10})
		known.known_facts[capped_id] = true
		if not need(Producer._contact(fixture.state, fixture.state.facts[capped_id], old.catalog.tables.world_observation_sources[pair[1]], known, old.catalog, capped_before).is_empty(), pair[0] + " 请求非零但封顶/净零时不触发观测"): return
		fixture.state.domains[domain].alert -= 1
		if not need(not Producer._contact(fixture.state, fixture.state.facts[capped_id], old.catalog.tables.world_observation_sources[pair[1]], known, old.catalog, capped_before).is_empty(), pair[0] + " 事务前后确实改变的字段保留真实接触"): return
		fixture.state.domains[domain].alert += 1
	var file := FileAccess.open(DIRECTORY + "/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": checks.size(), "checks": checks, "offering_turns": offerings.map(func(snapshot: Dictionary) -> int: return snapshot.turn)}, "\t"))
	print("WORLD_OBSERVATION_OK ", checks.size(), " checks; ", DIRECTORY + "/results.json")
	quit(0)
