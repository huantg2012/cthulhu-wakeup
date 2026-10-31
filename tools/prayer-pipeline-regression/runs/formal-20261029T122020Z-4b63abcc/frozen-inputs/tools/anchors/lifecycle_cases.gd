extends "res://tools/anchors/run.gd"
## Real hybrid lifecycle runs. Narrative authorization facts are explicit fixtures;
## all payments, status changes, relic custody and power outcomes use production Turn.
func run_anchor_lifecycle() -> void:
	_life_tiers()
	_life_refusal()
	_life_poverty()
	_life_proof_loss()
	_life_guardian()
	_life_medium()
	_life_save()
	_life_rollback()
	_life_opportunities()
	_life_legacy_ordinals()

func _life_active(profile: String = "CIV_01") -> Dictionary:
	var data: Dictionary = _ready_anchor(profile)
	assert(_create_anchor(data).ok)
	assert(data.world.state.anchors.has(data.anchor))
	assert(_evolve(data) and _finish(data))
	assert(data.world.state.anchors[data.anchor].state == "active")
	return data

func _life_next(data: Dictionary, effects: Array = []) -> void:
	data.fixture.gather = effects
	assert(_open(data)); data.fixture.gather = []

func _life_relic(data: Dictionary, action: String, payload: Dictionary) -> Dictionary:
	return _submit(data, "act", {"participant": "relics", "action": "relic_" + action, "payload": payload})

func _life_qualification(data: Dictionary, rule: String, basis: Dictionary) -> Dictionary:
	var parents: Array = [data.source]
	for id: String in [basis.get("source", "")] + basis.get("benefits", []) + basis.get("sources", []):
		if not id.is_empty() and not id in parents: parents.append(id)
	return {"type": "fact", "kind": "power_qualification", "source": data.source, "parents": parents, "domain": data.domain, "actor": data.guardian, "targets": [data.cult, data.guardian], "details": {"issuer": "cult-fixture", "version": "1", "rule": rule, "target": data.cult, "actor": data.guardian, "institution": data.institution, "basis": basis}, "observers": [], "institutions": []}

func _life_qualification_id(data: Dictionary, rule: String) -> String:
	return str(_facts(data.world, "power_qualification").filter(func(f: Dictionary) -> bool: return f.changes.get("rule") == rule)[-1].id)

func _life_status(data: Dictionary, status: String) -> Dictionary:
	return {"type": "world_command", "source": data.proof, "command": {"kind": "status", "npc": data.guardian, "status": status, "parents": [data.proof]}}

func _life_tiers() -> void:
	var rows: Array = []
	for profile: String in ["CIV_01", "CIV_04", "CIV_08"]:
		var data: Dictionary = _ready_anchor(profile)
		var tier: String = data.world.state.domains[data.domain].tier
		var awakening: int = data.world.state.awakening
		assert(_create_anchor(data).ok)
		var dormant: bool = data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.awakening == awakening
		assert(_evolve(data))
		var payments: Array = _facts(data.world, "economy_anchor_payment").filter(func(f: Dictionary) -> bool: return f.changes.anchor == data.anchor)
		var active: bool = data.world.state.anchors[data.anchor].state == "active"
		var fee: int = int(payments[-1].changes.fee)
		rows.append({"tier": tier, "dormant_before_payment": dormant, "active": active, "fee": fee, "contribution": int(data.world.state.awakening) - awakening, "valid": dormant and active and fee == catalog.integer("anchor_" + tier + "_upkeep") and int(data.world.state.awakening) - awakening == catalog.integer("anchor_" + tier + "_contribution")})
	_check("ANC-LIFE-001", "三个文明层级新建先休眠，真实供奉费用与有效贡献均取正式数据", rows.all(func(row: Dictionary) -> bool: return row.valid), {"tiers": rows})

func _life_refusal() -> void:
	var data: Dictionary = _life_active()
	_life_next(data)
	var awakening: int = data.world.state.awakening
	var budget: int = data.turn.context.whispers_budget
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.economy.preview(data.world.state, {"refuse_anchors": [data.anchor]})
	var pure: bool = before == data.turn.snapshot()
	var planned: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": [data.anchor]}})
	_check("ANC-LIFE-002", "预览及预编辑拒付不提前撤回上轮有效贡献或重发低语", preview.ok and pure and planned.ok and data.world.state.anchors[data.anchor].state == "active" and data.world.state.awakening == awakening and data.turn.context.whispers_budget == budget, {"awakening": awakening, "budget": budget})
	assert(_evolve(data))
	var stopped: bool = data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.awakening == awakening - catalog.integer("anchor_planet_contribution")
	var payments: Array = _facts(data.world, "economy_anchor_payment").filter(func(f: Dictionary) -> bool: return f.changes.anchor == data.anchor)
	var refused: bool = payments[-1].changes.reason == "explicit_refusal" and payments[-1].changes.fee == 0
	assert(_finish(data)); _life_next(data)
	assert(_submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": []}}).ok)
	var dormant: bool = data.world.state.anchors[data.anchor].state == "dormant"
	assert(_evolve(data) and _finish(data))
	_check("ANC-LIFE-003", "实际拒付才休眠，原结构同人同物恢复供奉后直接有效", stopped and refused and dormant and data.world.state.anchors[data.anchor].state == "active" and data.world.state.awakening == awakening, {"refused": refused, "stopped": stopped, "restored": data.world.state.anchors[data.anchor].state})

func _life_poverty() -> void:
	var data: Dictionary = _life_active()
	var balance: int = data.world.state.faith
	assert(_paid_open(data, balance))
	var before: bool = data.world.state.faith == 0 and data.world.state.anchors[data.anchor].state == "active"
	assert(_evolve(data) and _finish(data))
	var payments: Array = _facts(data.world, "economy_anchor_payment").filter(func(f: Dictionary) -> bool: return f.changes.anchor == data.anchor)
	_check("ANC-LIFE-004", "真实事件支付清空现钱，供奉缺款不借未来收入；收入到账也不免费补激活", before and payments[-1].changes.reason == "insufficient_faith" and payments[-1].changes.fee == 0 and data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.faith > 0, {"payment": payments[-1].changes, "income_balance": data.world.state.faith})

func _life_proof_loss() -> void:
	var data: Dictionary = _life_active()
	_life_next(data, [_life_qualification(data, "evidence", {"source": data.proof, "benefits": []})])
	var awakening: int = data.world.state.awakening
	var peak: int = data.world.state.peak_awakening
	var budget: int = data.turn.context.whispers_budget
	var result: Dictionary = _power(data, "POWER_VEIL", {"npc": data.guardian, "source": data.source, "qualification": _life_qualification_id(data, "evidence")})
	var current: Dictionary = Anchors.maintenance(data.world.state, data.institution, catalog, data.world.history)
	_check("ANC-LIFE-005", "真实掩迹撤销绑定证明立即停贡献，历史峰值保留且轮初低语预算锁定", result.ok and Store.has(data.world.state.invalid_records, data.proof) and not current.allowed and data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.awakening == awakening - catalog.integer("anchor_planet_contribution") and data.world.state.peak_awakening == peak and data.turn.context.whispers_budget == budget and data.world.state.whispers == budget - int(catalog.tables.powers.POWER_VEIL.whispers), {"maintenance": current, "result": result, "budget": budget})

func _life_guardian() -> void:
	var data: Dictionary = _life_active()
	var old: Dictionary = data.world.state.anchors[data.anchor].duplicate(true)
	var awakening: int = data.world.state.awakening
	_life_next(data, [_life_status(data, "detained")])
	var anchor: Dictionary = data.world.state.anchors[data.anchor]
	_check("ANC-LIFE-006", "实际拘禁立即撤护持贡献并保留原名义绑定", Store.entry(data.world.state.npcs, data.guardian).status == "detained" and anchor.state == "dormant" and anchor.guardian == old.guardian and anchor.relic == old.relic and anchor.origin == old.origin and data.world.state.awakening == awakening - catalog.integer("anchor_planet_contribution"))
	assert(_evolve(data) and _finish(data))
	_life_next(data, [_life_status(data, "active")])
	var dormant: bool = data.world.state.anchors[data.anchor].state == "dormant"
	assert(_evolve(data) and _finish(data))
	_check("ANC-LIFE-007", "护持者原人归来不免供奉，实际重新支付后原锚恢复", dormant and data.world.state.anchors[data.anchor].state == "active" and data.world.state.anchors[data.anchor].guardian == old.guardian and data.world.state.anchors[data.anchor].origin == old.origin)

func _life_authorization(data: Dictionary, action: String, relic: String, details: Dictionary = {}) -> Dictionary:
	var item: Dictionary = Store.entry(data.world.state.relics, relic)
	var changes: Dictionary = details.duplicate(true)
	changes.proof = {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": data.domain, "target": relic, "holder": "", "status_source": item.status_source}
	return {"type": "fact", "kind": "relic_" + action + "_authorized", "source": data.source, "domain": data.domain, "actor": "", "targets": [relic], "parents": [item.status_source], "details": changes, "observers": [], "institutions": []}

func _life_medium() -> void:
	var data: Dictionary = _life_active()
	var old: Dictionary = data.world.state.anchors[data.anchor].duplicate(true)
	var creation: Dictionary = {"type": "fact", "kind": "relic_create_authorized", "source": data.source, "domain": data.domain, "actor": "", "targets": [data.institution], "parents": [data.source], "details": {"relic_type": "RELIC_ROOT_NAIL", "placement": "controlled", "holder": "", "proof": {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": data.domain, "target": "RELIC_ROOT_NAIL", "holder": ""}}, "observers": [], "institutions": []}
	_life_next(data, [_life_authorization(data, "destroy", data.medium), creation])
	var source: String = str(_facts(data.world, "relic_destroy_authorized")[-1].id)
	var destroyed: Dictionary = _life_relic(data, "destroy", {"source": source, "relic": data.medium})
	var stopped: bool = destroyed.ok and data.world.state.anchors[data.anchor].state == "destroyed" and Store.entry(data.world.state.relics, data.medium).placement == "consumed"
	var create_source: String = str(_facts(data.world, "relic_create_authorized")[-1].id)
	var made: Dictionary = _life_relic(data, "create", {"source": create_source})
	data.medium = Relics.instance_id(create_source)
	_check("ANC-LIFE-008", "真实毁灭绑定媒介立即毁锚停贡献，新有源媒介仍须另行修复", stopped and made.ok and data.world.state.anchors[data.anchor].state == "destroyed" and data.world.state.anchors[data.anchor].origin == old.origin, {"destroyed": destroyed, "new_medium": data.medium})
	assert(_evolve(data) and _finish(data)); _life_next(data)
	var repaired: bool = false
	for attempt: int in 12:
		var preview: Dictionary = data.powers.preview(data.turn, "POWER_ANCHOR", _anchor_payload(data))
		if preview.ok:
			var result: Dictionary = _create_anchor(data)
			if result.ok and data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.anchors[data.anchor].relic == data.medium:
				repaired = true; break
		assert(_evolve(data) and _finish(data)); _life_next(data)
	var anchor: Dictionary = data.world.state.anchors[data.anchor]
	var identity: bool = anchor.id == old.id and anchor.ordinal == old.ordinal and anchor.origin == old.origin
	var before_payment: bool = repaired and anchor.state == "dormant"
	assert(_evolve(data) and _finish(data))
	_check("ANC-LIFE-009", "实际更换媒介修复沿用原ID序号来源，修复先休眠且供奉后才贡献", identity and before_payment and data.world.state.anchors[data.anchor].state == "active" and data.world.state.anchors[data.anchor].relic == data.medium, {"identity": identity, "repaired": repaired, "anchor": anchor})

func _life_clone(data: Dictionary) -> Dictionary:
	var clone: Dictionary = _anchor_base(data.profile)
	assert(clone.turn.restore(data.turn.snapshot()))
	return clone

func _life_save() -> void:
	var data: Dictionary = _life_active()
	var clone: Dictionary = _life_clone(data)
	var same: bool = clone.turn.snapshot() == data.turn.snapshot()
	var sequence: int = request_sequence
	assert(_round(data))
	var after_sequence: int = request_sequence
	request_sequence = sequence
	assert(_round(clone))
	request_sequence = after_sequence
	_check("ANC-LIFE-010", "真实有效锚保存恢复后整轮供奉演化续跑完全一致", same and clone.turn.snapshot() == data.turn.snapshot() and data.world.validate_state(data.world.state).is_empty())
	_life_next(data)
	assert(_submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": [data.anchor]}}).ok)
	assert(_evolve(data) and _finish(data))
	assert(data.world.state.anchors[data.anchor].state == "dormant")
	var saved: String = data.turn.snapshot()
	assert(clone.turn.restore(saved) and clone.turn.snapshot() == saved)
	var denied: Array = []
	for field: String in ["version", "proof", "ordinal", "origin", "source_issuer", "source_version", "source_option", "source_basis"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var state: Dictionary = world_envelope.body.state
		match field:
			"version": state.anchor_system.version += "/corrupt"
			"proof": state.anchor_system.proofs[data.institution] = data.source
			"ordinal": state.anchors[data.anchor].ordinal = 3
			"origin": state.anchors[data.anchor].origin = data.source
			"source_issuer": state.facts[data.proof].changes.issuer = "unknown"
			"source_version": state.facts[data.proof].changes.version = "wrong"
			"source_option": state.facts[data.proof].changes.option = "A"
			"source_basis": state.facts[data.proof].changes.basis.records[1] = state.facts[data.proof].changes.basis.records[0]
		denied.append(not data.turn.restore(_rewrap_turn(envelope, world_envelope)) and data.turn.snapshot() == saved)
	_check("ANC-LIFE-011", "真实休眠绑定保存拒schema/身份及源事件发行方、版本、选项、basis语义伪造，原会话不变", not false in denied, {"corruptions": denied})

func _life_rollback() -> void:
	var data: Dictionary = _life_active()
	_life_next(data); assert(_evolve(data))
	data.fixture.deadlines = [{"type": "resource", "source": data.proof, "field": "faith", "delta": -1}, _life_status(data, "detained"), {"type": "resource", "source": data.proof, "field": "faith", "delta": -1000000}]
	var before: String = data.turn.snapshot()
	var result: Dictionary = _submit(data, "advance")
	var rolled_back: bool = not result.ok and before == data.turn.snapshot()
	data.fixture.deadlines = []
	assert(_finish(data))
	_check("ANC-LIFE-012", "阶段5收入与先成功的扣款/拘禁后遇不可支付效果，事实资格资源回执随机整笔回滚", rolled_back and Store.entry(data.world.state.npcs, data.guardian).status == "active" and data.world.state.anchors[data.anchor].state == "active", {"rejected": result, "snapshot_unchanged": rolled_back})

func _life_opportunities() -> void:
	var data: Dictionary = _ready_anchor("CIV_03")
	var opportunity: String = str(data.world.state.anchor_system.opportunities[data.institution])
	var original: Dictionary = Store.entry(data.world.state.facts, opportunity).changes.duplicate(true)
	assert(data.world.state.anchors.is_empty())
	assert(_evolve(data) and _finish(data))
	_life_next(data, [_event_effect(data, data.basis)])
	_check("ANC-LIFE-013", "锚定前首承认只生一份固定池内遗物机会，重复真实事件源不重抽或重发", _facts(data.world, "institution_recognized").size() == 1 and _facts(data.world, "institution_relic_opportunity").size() == 1 and data.world.state.anchor_system.opportunities.get(data.institution) == opportunity and Store.entry(data.world.state.facts, opportunity).changes == original and data.world.state.anchors.is_empty(), {"opportunity": opportunity, "fixed": original})
	while data.world.state.turn <= original.due:
		assert(_evolve(data) and _finish(data))
		if data.world.state.turn < original.due: _life_next(data)
		else: break
	var expired: bool = not data.world.state.anchor_system.opportunities.has(data.institution) and Store.has(data.world.state.applied_authorizations, "anchor/opportunity/" + opportunity) and _facts(data.world, "institution_relic_expired").size() == 1
	var clone: Dictionary = _life_clone(data)
	var restored: bool = clone.turn.snapshot() == data.turn.snapshot()
	_life_next(data, [_event_effect(data, data.basis)])
	_check("ANC-LIFE-014", "原机会到期一次消费，完整恢复保留墓碑，后来相同承认不重开期限", expired and restored and _facts(data.world, "institution_relic_opportunity").size() == 1 and not data.world.state.anchor_system.opportunities.has(data.institution), {"due": original.due, "expired": expired, "restored": restored})

func _life_legacy_ordinals() -> void:
	# Explicit preexisting legacy-world fixture: the three structures and their
	# positions come from _high before any receipt, not manufactured formal results.
	var data: Dictionary = _high()
	data.domain = "DOMAIN-001"; data.guardian = data.leader; data.institution = "DOMAIN-001/interpretation"
	data.world.state.domains[data.domain].pollution = catalog.integer("anchor_maintain_pollution_3") + 1
	var first: String = data.anchors[data.institution]
	var third: String = data.anchors[data.domain + "/order"]
	var old: Dictionary = data.world.state.anchors[third].duplicate(true)
	var relic: String = data.world.state.anchors[first].relic
	var status: String = Store.entry(data.world.state.relics, relic).status_source
	var destroy: String = data.world.introduce_fact("relic_destroy_authorized", data.domain, "", [relic], [status], {"proof": {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": data.domain, "target": relic, "holder": "", "status_source": status}}, [])
	var exposure: String = data.world.introduce_fact("exposure", data.domain, data.guardian, [data.guardian], [data.source], {"public": false}, [data.guardian])
	var veil: String = _qualification(data, "evidence", data.cult, data.guardian, data.domain, {"source": exposure, "benefits": []})
	var spread: String = _qualification(data, "spread", data.cult, data.guardian, data.domain, {"institution": data.domain + "/propagation", "sources": [data.source]}, data.domain + "/propagation")
	_attach_powers(data)
	var payload: Dictionary = {"npc": data.guardian, "source": data.source, "qualification": veil}
	_seed(data, "POWER_VEIL", "success", payload)
	assert(_open(data))
	assert(_life_relic(data, "destroy", {"source": destroy, "relic": relic}).ok)
	var stable: bool = data.world.state.anchors[first].state == "destroyed" and data.world.state.anchors[third].ordinal == 3 and data.world.state.anchors[third].origin == old.origin
	var lowered: Dictionary = _power(data, "POWER_VEIL", payload)
	var low: bool = data.world.state.domains[data.domain].pollution < catalog.integer("anchor_maintain_pollution_3") and data.world.state.domains[data.domain].pollution >= catalog.integer("anchor_maintain_pollution_2")
	_check("ANC-LIFE-015", "明确旧结构夹具：第一锚实际毁灭不重排第三序号，第三按原较高门槛失效", stable and lowered.ok and low and data.world.state.anchors[third].state == "dormant" and data.world.state.anchors[data.anchors[data.domain + "/propagation"]].state == "active", {"fixture": "preexisting legacy anchors", "pollution": data.world.state.domains[data.domain].pollution, "ordinal": data.world.state.anchors[third].ordinal})
	assert(_evolve(data) and _finish(data))
	var raised: bool = false
	for attempt: int in 8:
		assert(_open(data))
		var seed_payload: Dictionary = {"npc": data.guardian, "source": data.source, "qualification": spread}
		var seed_preview: Dictionary = data.powers.preview(data.turn, "POWER_SEED", seed_payload)
		if not seed_preview.ok:
			assert(_evolve(data) and _finish(data)); continue
		assert(_power(data, "POWER_SEED", seed_payload).ok)
		if data.world.state.domains[data.domain].pollution >= catalog.integer("anchor_maintain_pollution_3"):
			raised = data.world.state.anchors[third].state == "dormant"
			assert(_evolve(data) and _finish(data)); break
		assert(_evolve(data) and _finish(data))
	_check("ANC-LIFE-016", "真实污染回落保留绑定，真实播种恢复污染后仍先休眠并经供奉恢复第三锚", raised and data.world.state.anchors[third].state == "active" and data.world.state.anchors[third].ordinal == old.ordinal and data.world.state.anchors[third].origin == old.origin, {"fixture": "preexisting legacy anchors", "raised": raised, "state": data.world.state.anchors[third].state})
