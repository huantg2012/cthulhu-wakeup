extends "res://tools/resistance/propagation_cases.gd"

# Explicit rule-boundary fixtures below isolate confirmation ordering, cold
# indexes and barrier transitions. They do not claim that the fixture's fact
# producer is a new player action. TRACE settlement itself uses real Turn.
func run_propagation() -> void:
	super.run_propagation()
	_review_recent()
	_review_reconfirm()
	_review_cold()
	_review_breach()

func _review_confirmation(data: Dictionary, subject: String, source: String) -> String:
	var key: String = data.institution + "|" + subject
	var confirmation: String = data.world._record("evidence_confirmed", data.domain, "", [subject], [source], {"institution": data.institution, "fixture": "independent_confirmation_contract"})
	if not Store.has(data.world.state.evidence, key):
		Store.put(data.world.state.evidence, key, {"institution": data.institution, "subject": subject, "strength": catalog.integer("evidence_confirmation_strength"), "sources": [], "confirmations": []})
	var evidence: Dictionary = Store.entry(data.world.state.evidence, key)
	evidence.sources = data.world.history.set_value(evidence.sources, source)
	evidence.confirmations = data.world.history.set_value(evidence.confirmations, confirmation)
	data.world._history_evidence(key)
	return confirmation

func _review_exposure(data: Dictionary, person: String) -> String:
	return data.world.introduce_fact("exposure", data.domain, person, [person], [data.source], {"public": false, "fixture": "independent_current_exposure"}, [], [data.institution], data.turn)

func _review_recent() -> void:
	var data: Dictionary = _res_base("RESIST_PURGE")
	var other: String = data.guardians[data.domain][1]
	# An explicit existing member for this pure selector fixture. No Turn
	# command is executed from this independent altered membership initial state.
	data.world.mutable_npc(other).cult_id = data.cult
	var older: String = _review_confirmation(data, other, _review_exposure(data, other))
	data.world.state.turn = 1
	var recent: String = _review_confirmation(data, data.subject, _review_exposure(data, data.subject))
	var plan: Dictionary = data.world.choose_plan(data.domain)
	_check("RES-REVIEW-001", "同团多对象先按实际证据最近轮绑定，不被后遍历旧证据覆盖（独立选择合同）", plan.get("rule") == "RESIST_PURGE" and plan.get("target") == data.cult and plan.get("evidence_subject") == data.subject and plan.get("parents") == [recent] and plan.get("recent") == 1, {"older": older, "recent": recent, "selected": plan})

func _review_reconfirm() -> void:
	var data: Dictionary = _res_base("RESIST_PURGE")
	data.world.state.domains[data.domain].alert = 100
	var key: String = data.institution + "|" + data.subject
	var old: Array = data.world.history.values(Store.entry(data.world.state.evidence, key).confirmations)
	var new_exposure: String = _review_exposure(data, data.subject)
	# Source withdrawal is an explicit pre-command upstream contract fixture.
	# Rebuild is the normal initial adoption path, not a fake confirmation.
	Store.put(data.world.state.invalid_records, data.evidence, new_exposure)
	data.world.history.rebuild(data.world.state)
	var plan: Dictionary = _res_start(data)
	var traced: bool = plan.get("rule") == "RESIST_TRACE" and plan.get("parents") == [new_exposure]
	var advanced: bool = _round(data) and _round(data)
	var results: Array = _res_results(data, plan)
	var next: Dictionary = data.world.state.domains[data.domain].pending_plan
	var retained: bool = true
	for source: String in old: retained = retained and data.world.history.has(Store.entry(data.world.state.evidence, key).confirmations, source)
	var confirmed: bool = results.size() == 1 and data.world.history.has(Store.entry(data.world.state.evidence, key).confirmations, results[0].id)
	_check("RES-REVIEW-002", "撤销旧支持后真实TRACE重新确认，保留旧历史并允许后续PURGE", traced and advanced and retained and confirmed and next.get("rule") == "RESIST_PURGE" and next.get("parents") == [results[0].id], {"trace": plan, "resolved": results.size(), "old_retained": retained, "next": next})

func _review_cold_sample(count: int) -> Dictionary:
	var data: Dictionary = _res_base("RESIST_PURGE")
	for number: int in count:
		var exposure: String = _review_exposure(data, data.subject)
		var confirmation: String = _review_confirmation(data, data.subject, exposure)
		Store.put(data.world.state.invalid_records, confirmation, data.source)
	var current: String = _review_confirmation(data, data.subject, _review_exposure(data, data.subject))
	data.world.history.rebuild(data.world.state)
	data.world.history.reset_metrics()
	var plan: Dictionary = data.world.choose_plan(data.domain)
	var metrics: Dictionary = data.world.history.metrics.duplicate(true)
	return {"count": count, "selected": plan.get("parents") == [current], "metrics": metrics}

func _review_cold() -> void:
	var short: Dictionary = _review_cold_sample(8)
	var long: Dictionary = _review_cold_sample(512)
	var bounded: bool = short.selected and long.selected
	for metric: String in ["history_scanned", "copied_history_values", "output_sources", "current_entities", "decision_reads"]:
		bounded = bounded and short.metrics[metric] == long.metrics[metric]
	bounded = bounded and long.metrics.history_scanned == 0 and long.metrics.copied_history_values == 0 and int(long.metrics.tree_nodes_read) <= int(short.metrics.tree_nodes_read) * 4 + 64
	_check("RES-REVIEW-003", "旧确认从8增到512，热选择不展开冷H、仅允许持久树对数读取", bounded, {"short": short, "long": long, "fixture": "initial historical confirmations; no claimed player content"})

func _review_barrier(data: Dictionary, value: int) -> String:
	var before: int = data.world.state.domains[data.domain].barrier
	data.world.state.domains[data.domain].barrier = value
	var cause: String = data.world._record("power_effect", data.domain, "", [data.domain], [data.source], {"field": "barrier", "requested": value - before, "actual": value - before, "fixture": "shared_delta_boundary"})
	data.world.state.domains[data.domain].barrier_source = cause
	return cause

func _review_breach() -> void:
	var data: Dictionary = _res_base("RESIST_REPAIR")
	_review_barrier(data, 30)
	_review_barrier(data, 40)
	var gray: bool = data.world.state.resistance_system.breaches[data.domain] and data.world.choose_plan(data.domain).get("rule") == "RESIST_REPAIR"
	var saved: String = data.turn.snapshot()
	var envelope: Dictionary = JSON.parse_string(saved)
	var world: Dictionary = JSON.parse_string(envelope.body.world)
	world.body.state.resistance_system.breaches[data.domain] = false
	world.checksum = World.canonical(world.body).sha256_text(); envelope.body.world = World.canonical(world)
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	var rejected: bool = not data.turn.restore(World.canonical(envelope)) and data.turn.snapshot() == saved
	var cause: String = _review_barrier(data, 45)
	var source: String = data.world.state.resistance_system.breach_sources[data.domain]
	var transition: Dictionary = Store.entry(data.world.state.facts, source)
	var closed: bool = not data.world.state.resistance_system.breaches[data.domain] and data.world.choose_plan(data.domain).get("rule", "") != "RESIST_REPAIR"
	_check("RES-REVIEW-004", "原30开40保持45闭，有源状态与灰区坏档拒绝（共享增量合同）", gray and rejected and closed and cause in transition.causal_parents and transition.changes.barrier == 45 and not transition.changes.open and data.world.validate_state(data.world.state).is_empty(), {"gray_open": gray, "forged_rejected": rejected, "closed": closed, "transition": transition})
