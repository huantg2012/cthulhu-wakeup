extends "res://tools/events/run.gd"
const Resistance = preload("res://src/game/resistance.gd")
var erase_fixture: bool = false
# Only existing world conditions are fixtures. No test inserts a pending plan,
# advances a deadline manually, or prewrites a resistance result.

func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	for rule: String in ["RESIST_TRACE", "RESIST_PURGE", "RESIST_SEIZE", "RESIST_REPAIR"]:
		_res_case(rule, false)
		_res_case(rule, true)
	_rewrite_case()
	_erase_case(false)
	_erase_case(true)
	_res_persistence()
	_res_no_money()
	_res_tamper()
	_res_background()
	if has_method("run_propagation"): call("run_propagation")
	var ok: bool = true
	for row: Dictionary in records: ok = ok and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records}, "\t", true, true)); file.close()
	quit(0 if ok else 1)

func _res_attach(data: Dictionary) -> void:
	_attach_prayers(data)

func _attach_prayers(data: Dictionary) -> Dictionary:
	if erase_fixture:
		data.world.state.domains[data.domain].alert = 100
		data.order_witness = _local_person(data.world, data.domain, data.domain + "/order", "NPC_PROFILE_05")
		data.world.mutable_npc(data.order_witness).insight = catalog.integer("npc_attribute_max")
		data.world.attention.sync(data.world)
		data.world.history.rebuild(data.world.state)
	super._attach_prayers(data)
	data.resistance = Resistance.new(catalog); assert(data.resistance.install(data.turn))
	return data

func _res_base(rule: String) -> Dictionary:
	var data: Dictionary = _high()
	data.domain = "DOMAIN-007" if rule == "RESIST_ERASE" else "DOMAIN-001"
	data.institution = data.domain + "/order"
	data.subject = data.guardians[data.domain][0]
	data.anchor = data.anchors[data.domain + "/interpretation"]
	if rule == "RESIST_SEIZE": data.subject = data.world.state.anchors[data.anchor].relic
	data.target = data.subject
	if rule == "RESIST_ERASE": data.target = data.anchor
	if rule == "RESIST_PURGE": data.target = data.cult
	if rule == "RESIST_REPAIR": data.target = data.domain
	# These values describe a preexisting situation before any Turn receipt.
	data.world.state.domains[data.domain].alert = int(catalog.tables.resistance_plans[rule].min_alert) + 5
	if rule != "RESIST_REPAIR": data.world.state.domains[data.domain].barrier = 40
	if rule != "RESIST_REPAIR":
		data.evidence = data.world.introduce_fact("exposure", data.domain, data.subject if Store.has(data.world.state.npcs, data.subject) else "", [data.subject], [data.world.state.domains[data.domain].origin], {"fixture": "existing_specific_exposure", "public": false}, [], [data.institution])
		assert(not data.evidence.is_empty())
		if rule != "RESIST_TRACE":
			var confirmation: String = data.world._record("evidence_confirmed", data.domain, "", [data.subject], [data.evidence], {"fixture": "existing_independent_confirmation", "institution": data.institution})
			Store.put(data.world.state.evidence, data.institution + "|" + data.subject, {"institution": data.institution, "subject": data.subject, "strength": catalog.integer("evidence_confirmation_strength"), "sources": [data.evidence], "confirmations": [confirmation]})
	# Disable unrelated NPC autonomous publication through calm initial attributes.
	for person: Dictionary in Store.values(data.world.state.npcs):
		data.world.mutable_npc(person.id).sanity = 80
	data.world.history.rebuild(data.world.state)
	_res_attach(data)
	return data

func _res_start(data: Dictionary) -> Dictionary:
	assert(_open(data) and _evolve(data))
	var plan: Dictionary = data.world.state.domains[data.domain].pending_plan.duplicate(true)
	assert(_finish(data))
	return plan

func _res_results(data: Dictionary, plan: Dictionary, cancelled: bool = false) -> Array:
	return _facts(data.world, "resistance_cancelled" if cancelled else "resistance_resolved").filter(func(f: Dictionary) -> bool: return plan.get("started_fact", "") in f.causal_parents)

func _res_case(rule: String, cancel: bool) -> void:
	var data: Dictionary = _res_base(rule)
	var plan: Dictionary = _res_start(data)
	var selected: bool = plan.get("rule") == rule and plan.get("target") == data.target and plan.get("due") == 1 + int(catalog.tables.resistance_plans[rule].warning_turns)
	if not selected:
		_check("RES/" + rule + ("/cancel" if cancel else "/resolve"), "真实启动指定计划", false, {"plan": plan, "target": data.target}); return
	var snapshot: String = data.turn.snapshot()
	var preview: Variant = data.resistance.preview(data.turn)
	var pure: bool = snapshot == data.turn.snapshot()
	# Dedicated upstream identity event fixture: an actual status command,
	# never deleting the pending plan or replacing its target.
	if cancel:
		var representative: String = data.world.state.institutions[data.institution].representative
		data.fixture.gather = [{"type": "world_command", "source": plan.started_fact, "command": {"kind": "status", "npc": representative, "status": "dead", "parents": [plan.started_fact]}}]
	assert(_round(data))
	data.fixture.gather = []
	var early: bool = _res_results(data, plan).is_empty() and _res_results(data, plan, true).is_empty()
	var domain: Dictionary = data.world.state.domains[data.domain]
	var before: Dictionary = {"population": domain.population, "followers": domain.unnamed_followers, "barrier": domain.barrier, "pollution": domain.pollution, "wounds": data.world.state.wounds}
	assert(_open(data))
	var outcomes: Array = _res_results(data, plan, cancel)
	var applied: bool = outcomes.size() == 1
	domain = data.world.state.domains[data.domain]
	if not cancel:
		match rule:
			"RESIST_TRACE": applied = applied and History.size(Store.entry(data.world.state.evidence, data.institution + "|" + data.subject).confirmations) > 0
			"RESIST_PURGE": applied = applied and before.population - domain.population == int(ceil(float(before.followers) * float(catalog.tables.civilization_actions[rule].followers_loss_ratio)))
			"RESIST_SEIZE": applied = applied and Store.entry(data.world.state.relics, data.subject).placement == "seized" and Store.entry(data.world.state.relics, data.subject).captor == data.institution and data.world.state.anchors[data.anchor].state == "dormant"
			"RESIST_REPAIR": applied = applied and domain.barrier >= before.barrier + int(catalog.tables.civilization_actions[rule].barrier_delta) and domain.pollution == maxi(0, before.pollution + int(catalog.tables.civilization_actions[rule].pollution_delta))
			"RESIST_ERASE": applied = applied and data.world.state.anchors[data.anchor].state == "destroyed" and Store.entry(data.world.state.npcs, data.subject).status == "active" and Store.has(data.world.state.relics, data.world.state.anchors[data.anchor].relic)
	var cooldown: bool = int(domain.plan_cooldowns.get(rule, -1)) == int(plan.due) + int(catalog.tables.resistance_plans[rule].cooldown_turns)
	_check("RES/" + rule + ("/cancel" if cancel else "/resolve"), "真实预告、原对象、到期" + ("机构死亡取消" if cancel else "按表结算") + "与完整冷却", selected and pure and early and applied and cooldown and domain.pending_plan.is_empty() and data.world.validate_state(data.world.state).is_empty(), {"plan": plan, "pure": pure, "early": early, "outcomes": outcomes.size(), "applied": applied, "cooldown": cooldown, "errors": data.world.validate_state(data.world.state), "preview": preview, "before": before, "after": {"population": domain.population, "followers": domain.unnamed_followers, "barrier": domain.barrier, "pollution": domain.pollution}})

func _rewrite_case() -> void:
	var data: Dictionary = _event_rewrite_case()
	var card: Dictionary = _event_wait(data, "EVENT_11", "B")
	var plan: Dictionary = data.world.state.domains[data.domain].pending_plan.duplicate(true)
	var before: int = data.world.state.wounds
	var result: Dictionary = _event_resolve(data, card.id, "B") if not card.is_empty() else {"ok": false}
	var count: int = _res_results(data, plan).size()
	assert(_submit(data, "finish_events").ok and _evolve(data) and _finish(data))
	_check("RES/RESIST_REWRITE/resolve", "正式祈求与例外记录产生修正，EVENT_11仅结算同一伤害一次", result.ok and plan.get("rule") == "RESIST_REWRITE" and data.world.state.wounds == before + int(catalog.tables.civilization_actions.RESIST_REWRITE.wounds_delta) and count == 1 and _res_results(data, plan).size() == 1, {"plan": plan, "result": result, "wounds_before": before, "wounds_after": data.world.state.wounds})

func _res_persistence() -> void:
	var data: Dictionary = _res_base("RESIST_PURGE")
	var plan: Dictionary = _res_start(data)
	var saved: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(saved)
	assert(_round(data) and _open(data))
	var before: String = data.turn.snapshot()
	data.fixture.fault = true
	# stage four succeeds; fault at stage five must restore the entire due phase.
	assert(_evolve(data))
	before = data.turn.snapshot()
	var failed: Dictionary = _submit(data, "advance")
	var atomic: bool = not failed.ok and data.turn.snapshot() == before
	data.fixture.fault = false
	assert(_finish(data))
	var final: String = data.turn.snapshot()
	assert(data.turn.restore(saved) and _round(data) and _round(data))
	_check("RES-LIFE-001", "活动计划存档保留原目标/证据/期限，到期轮事务故障回滚与重放", restored and atomic and _res_results(data, plan).size() == 1, {"atomic": atomic, "failure": failed, "plan": plan, "final_bytes": final.length()})

func _res_no_money() -> void:
	var data: Dictionary = _res_base("RESIST_TRACE")
	# Initial poverty, no later fixture grants resources.
	data.world.state.faith = 0
	var plan: Dictionary = _res_start(data)
	assert(_round(data) and _round(data))
	_check("RES-LIFE-002", "初始无信仰仍可接受调查后果并继续完整回合", plan.get("rule") == "RESIST_TRACE" and _res_results(data, plan).size() == 1 and data.turn.context.phase == "between", {"plan": plan, "turn": data.world.state.turn})

func _res_propagation() -> void:
	var data: Dictionary = _high()
	_res_attach(data)
	var payload: Dictionary = _payload(data, "POWER_TRANSFER")
	assert(_open(data))
	var before: String = data.turn.snapshot()
	var good: Dictionary = data.powers.preview(data.turn, "POWER_TRANSFER", payload)
	var bad_payload: Dictionary = payload.duplicate(true)
	for domain: String in data.world.state.domains:
		if domain != "DOMAIN-001" and not domain in data.world.state.domains["DOMAIN-001"].neighbors: bad_payload.target_domain = domain; break
	var bad: Dictionary = data.powers.preview(data.turn, "POWER_TRANSFER", bad_payload)
	var rejected: Dictionary = _power(data, "POWER_TRANSFER", bad_payload)
	_check("RES-PROP-001", "真实通路准入，无通路拒绝且不花费/不抽骰", good.ok and not bad.ok and not rejected.ok and data.turn.snapshot() == before, {"good": good, "bad": bad, "result": rejected})
	var expected: int = data.powers.probability(Store.entry(data.world.state.npcs, data.leader), data.world.state.domains[data.receiving], catalog.tables.powers.POWER_TRANSFER, 0)
	var executed: Dictionary = _power(data, "POWER_TRANSFER", payload)
	var check_facts: Array = _facts(data.world, "turn_check").filter(func(f: Dictionary) -> bool: return f.domain == data.receiving)
	_check("RES-PROP-002", "真实迁引重新承受目标域屏障/察觉检定，结果有原人物来源", executed.ok and good.get("probability") == expected and not check_facts.is_empty() and check_facts[-1].changes.probability == expected, {"expected": expected, "preview": good, "result": executed})

func _res_tamper() -> void:
	var data: Dictionary = _res_base("RESIST_TRACE")
	var plan: Dictionary = _res_start(data)
	var saved: String = data.turn.snapshot()
	var denied: bool = true
	for field: String in ["due", "default_effect", "target", "evidence_subject", "parents"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world: Dictionary = JSON.parse_string(envelope.body.world)
		var forged: Dictionary = world.body.state.domains[data.domain].pending_plan
		match field:
			"due": forged.due += 1
			"default_effect": forged.default_effect.wounds_delta = "99"
			"target": forged.target = data.guardians[data.domain][1]
			"evidence_subject": forged.evidence_subject = data.guardians[data.domain][1]
			"parents": forged.parents = [data.source]
		world.checksum = World.canonical(world.body).sha256_text(); envelope.body.world = World.canonical(world)
		envelope.checksum = World.canonical(envelope.body).sha256_text()
		denied = not data.turn.restore(World.canonical(envelope)) and data.turn.snapshot() == saved and denied
	_check("RES-LIFE-003", "重算checksum也不能篡改原预告due/后果/对象/证据，坏档不半覆盖", denied, {"fields": ["due", "default_effect", "target", "evidence_subject", "parents"], "original": plan})

func _res_background() -> void:
	var data: Dictionary = _res_base("RESIST_TRACE")
	var plan: Dictionary = _res_start(data)
	assert(_open(data))
	var released: Dictionary = _control(data, {"kind": "release_focus", "domain": data.domain})
	assert(_evolve(data) and _finish(data))
	var low: bool = data.world.state.domains[data.domain].alert < int(catalog.tables.resistance_plans.RESIST_TRACE.min_alert)
	var fixed: bool = data.world.state.domains[data.domain].pending_plan == plan
	assert(_round(data))
	_check("RES-LIFE-004", "真实撤关注进入后台，低察觉不撤销原预告且原due仍结算", released.ok and low and fixed and not data.domain in data.world.state.simulation.focused and _res_results(data, plan).size() == 1 and _res_results(data, plan)[0].turn == plan.due, {"release": released, "low_alert": low, "fixed": fixed, "plan": plan, "focused": data.world.state.simulation.focused})

func _erase_case(cancel: bool) -> void:
	erase_fixture = true
	var data: Dictionary = _actual_recognition("CIV_04")
	erase_fixture = false
	var proofs: Array = _facts(data.world, "institution_event_result").filter(func(f: Dictionary) -> bool: return f.changes.institution == data.institution)
	data.proof = proofs[-1].id
	assert(_create_anchor(data).ok and _evolve(data) and _finish(data))
	var active: bool = data.world.state.anchors[data.anchor].state == "active"
	# An explicit current exposure from the actual new anchor. The institution
	# still has to investigate it through the production NPC/TRACE chain.
	var source: String = data.world.state.anchors[data.anchor].established_source
	data.fixture.gather = [
		{"type": "fact", "kind": "public_anomaly", "source": source, "domain": data.domain, "actor": data.guardian, "targets": [data.guardian], "parents": [source], "details": {"fixture": "new_anchor_publicly_manifesting"}, "observers": [data.order_witness], "institutions": [data.domain + "/order"]},
		{"type": "fact", "kind": "exposure", "source": source, "domain": data.domain, "actor": data.guardian, "targets": [data.guardian], "parents": [source], "details": {"public": true}, "observers": [data.order_witness], "institutions": [data.domain + "/order"]}
	]
	assert(_round(data))
	data.fixture.gather = []
	var plan: Dictionary = {}
	for i: int in 10:
		assert(_round(data))
		var current: Dictionary = data.world.state.domains[data.domain].pending_plan
		if current.get("rule") == "RESIST_ERASE": plan = current.duplicate(true); break
	if plan.is_empty():
		_check("RES/RESIST_ERASE/" + ("cancel" if cancel else "resolve"), "真实锚点与实际查证产生抹除计划", false, {"active_initial": active, "anchor": data.world.state.anchors[data.anchor], "domain": data.world.state.domains[data.domain]}); return
	if cancel:
		data.fixture.gather = [{"type": "world_command", "source": plan.started_fact, "command": {"kind": "status", "npc": data.guardian, "status": "detained", "parents": [plan.started_fact]}}]
	assert(_round(data)); data.fixture.gather = []
	var early: bool = _res_results(data, plan).is_empty() and _res_results(data, plan, true).is_empty()
	assert(_round(data))
	var results: Array = _res_results(data, plan, cancel)
	var expected_state: String = "dormant" if cancel else "destroyed"
	_check("RES/RESIST_ERASE/" + ("cancel" if cancel else "resolve"), "真实制度锚定/供奉/查证链，抹除只毁指定结构或失效取消", active and early and results.size() == 1 and results[0].turn == plan.due and data.world.state.anchors[data.anchor].state == expected_state and Store.entry(data.world.state.npcs, data.guardian).status != "dead" and Store.has(data.world.state.relics, data.medium), {"plan": plan, "results": results.size(), "active_initial": active, "anchor": data.world.state.anchors[data.anchor]})
