extends "res://tools/prayers/reopen_cases.gd"

func run_integration_cases() -> void:
	_integration_propagation()
	_integration_appointment()
	_integration_concealment()
	_integration_oracle()

func _integration_propagation() -> void:
	var data: Dictionary = _prayer_case("PRAYER_03")
	data.fixture.gather = [
		{"type": "world_command", "source": data.source, "command": {"kind": "economy_qualification", "rule": "propagation", "subject": data.cult, "institution": data.domain + "/propagation", "allowed": true, "issuer": "cult-fixture", "version": "1", "parents": [data.source]}},
		{"type": "fact", "source": data.source, "parents": [data.source], "kind": "power_qualification", "domain": data.domain, "actor": data.petitioner, "targets": [data.cult, data.petitioner], "details": {"issuer": "cult-fixture", "version": "1", "rule": "spread", "target": data.cult, "actor": data.petitioner, "institution": data.domain + "/propagation", "basis": {"institution": data.domain + "/propagation", "sources": [data.source]}}, "observers": [], "institutions": []}
	]
	_choose_prayer_seed(data, "failure", data.petitioner, data.domain)
	assert(_open(data)); data.fixture.gather = []
	var sources: Array = _facts(data.world, "power_qualification").filter(func(f: Dictionary) -> bool: return f.changes.get("rule") == "spread")
	var payload: Dictionary = {"npc": data.petitioner, "source": data.source, "qualification": sources[-1].id}
	var plan: Dictionary = {"strategies": {data.cult: "expand"}}
	var baseline: Dictionary = data.powers.preview(data.turn, "POWER_SEED", payload)
	var before_economy: Dictionary = data.economy.preview(data.world.state, plan)
	var baseline_row: Dictionary = _integration_cult_row(before_economy, data.cult)
	var response: Dictionary = _response(data, data.request, "shallow")
	var before: String = data.turn.snapshot()
	var denied: Dictionary = _power(data, "POWER_SEED", payload)
	var pure_denial: bool = not denied.ok and before == data.turn.snapshot()
	var blocked: Dictionary = _integration_cult_row(data.economy.preview(data.world.state, plan), data.cult)
	var planned: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": plan})
	assert(_evolve(data) and _finish(data))
	var work: Array = _facts(data.world, "economy_work").filter(func(f: Dictionary) -> bool: return f.changes.get("cult") == data.cult)
	var income: Array = _facts(data.world, "economy_income").filter(func(f: Dictionary) -> bool: return f.changes.get("cult") == data.cult)
	var valid: bool = baseline.ok and baseline_row.get("effective") == "expand" and response.ok and pure_denial and blocked.get("reason") == "prayer_propagation_restricted" and blocked.get("effective") == "hold" and blocked.get("fee", -1) == 0 and planned.ok and not work.is_empty() and work[-1].changes.get("growth", -1) == 0 and not income.is_empty() and income[-1].changes.actual > 0
	_check("PRY-INTEGRATION-001", "浅追查同轮禁止真实播种与经济扩张，正常收入继续", valid, {"baseline": baseline, "before": baseline_row, "blocked": blocked, "denied": denied, "work": work[-1].changes if not work.is_empty() else {}, "income": income[-1].changes if not income.is_empty() else {}})

func _integration_cult_row(preview: Dictionary, cult: String) -> Dictionary:
	for row: Dictionary in preview.get("preview", {}).get("cults", []):
		if row.cult == cult: return row
	return {}

func _integration_appointment() -> void:
	var data: Dictionary = _prayer_case("PRAYER_06")
	_choose_prayer_seed(data, "failure", data.petitioner, data.domain)
	assert(_open(data))
	var payload: Dictionary = {"npc": data.petitioner, "cult": data.cult, "role": "leader", "source": data.source}
	var baseline: Dictionary = data.powers.preview(data.turn, "POWER_APPOINT", payload)
	var response: Dictionary = _response(data, data.request, "shallow")
	var first: bool = _integration_appointment_denied(data, payload)
	assert(_evolve(data) and _finish(data) and _open(data))
	var second: bool = _integration_appointment_denied(data, payload)
	assert(_evolve(data) and _finish(data) and _open(data))
	var reopened: Dictionary = data.powers.preview(data.turn, "POWER_APPOINT", payload)
	var appointed: Dictionary = _action(data, "appoint", payload)
	_check("PRY-INTEGRATION-002", "契约限制覆盖回应本轮及后续完整轮，教团与代理任命同路拒绝并到期恢复", baseline.ok and response.ok and first and second and reopened.ok and appointed.ok, {"baseline": baseline, "first": first, "second": second, "expired_preview": reopened, "appointed": appointed})

func _integration_appointment_denied(data: Dictionary, payload: Dictionary) -> bool:
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.powers.preview(data.turn, "POWER_APPOINT", payload)
	var cult: Dictionary = _action(data, "appoint", payload)
	var first: bool = not preview.ok and not cult.ok and before == data.turn.snapshot()
	before = data.turn.snapshot()
	var power: Dictionary = _power(data, "POWER_APPOINT", payload)
	return first and not power.ok and before == data.turn.snapshot()

func _integration_concealment() -> void:
	var data: Dictionary = _prayer_case("PRAYER_03", false)
	var world: RefCounted = data.world
	var investigator: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local(data.domain, data.domain + "/order", "NPC_PROFILE_05", world.state.domains[data.domain].origin))
	world.state.domains[data.domain].alert = 40
	var exposure: String = world.introduce_fact("exposure", data.domain, data.petitioner, [data.petitioner], [data.situation], {"public": false}, [], [data.domain + "/order"], data.turn)
	assert(not exposure.is_empty())
	world.attention.sync(world); world.history.rebuild(world.state)
	assert(world.fix_prayer_source(data.situation, data.turn))
	for id: String in world.state.simulation.candidates:
		if world.state.simulation.candidates[id].get("source") == data.situation: data.request = id
	for value: int in range(1, 10001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = value
		if rng.randi_range(1, 100) == 1:
			world.randoms.checks.seed = value; break
	assert(_open(data) and _evolve(data))
	var pending: Dictionary = world.state.domains[data.domain].pending_plan.duplicate(true)
	assert(_finish(data))
	data.fixture.gather = [{"type": "fact", "source": data.situation, "parents": [data.situation], "kind": "exposure", "domain": data.domain, "actor": data.petitioner, "targets": [data.petitioner], "details": {"public": false}, "observers": [investigator], "institutions": [data.domain + "/order"]}]
	assert(_open(data)); data.fixture.gather = []
	var ordinary_before: Dictionary = world.choose_behavior(investigator)
	var response: Dictionary = _response(data, data.request, "deep")
	var ordinary_after: Dictionary = world.choose_behavior(investigator)
	var hidden: Dictionary = world.state.prayer_system.hidden.get(data.petitioner, {})
	var anchor_id: String = data.anchors[data.domain + "/interpretation"]
	var active: bool = Store.entry(world.state.npcs, data.petitioner).status == "active"
	var vacated: bool = world.state.institutions[data.institution].representative != data.petitioner and world.state.anchors[anchor_id].guardian.is_empty() and world.state.anchors[anchor_id].needs_rebind
	var kept_plan: bool = not pending.is_empty() and World.canonical(pending) == World.canonical(world.state.domains[data.domain].pending_plan)
	assert(_evolve(data) and _finish(data) and _open(data))
	var resolved: Array = _facts(world, "resistance_resolved").filter(func(f: Dictionary) -> bool: return not pending.is_empty() and pending.started_fact in f.causal_parents and data.petitioner in f.targets)
	var first_full: bool = world.state.prayer_system.hidden.has(data.petitioner)
	assert(_evolve(data) and _finish(data) and _open(data))
	var second_full: bool = world.state.prayer_system.hidden.has(data.petitioner)
	assert(_evolve(data) and _finish(data) and _open(data))
	var expired: bool = not world.state.prayer_system.hidden.has(data.petitioner)
	var unrestored: bool = world.state.institutions[data.institution].representative != data.petitioner and world.state.anchors[anchor_id].guardian != data.petitioner and world.state.anchors[anchor_id].state != "active" and world.state.anchors[anchor_id].needs_rebind
	_check("PRY-INTEGRATION-003", "隐匿仅撤新普通追查资格，已预告抵抗保留；两完整轮后到期且岗位锚点不免费恢复", response.ok and active and hidden.get("until", -1) == 4 and ordinary_before.get("target") == data.petitioner and ordinary_after.get("target") != data.petitioner and vacated and kept_plan and not resolved.is_empty() and first_full and second_full and expired and unrestored, {"before": ordinary_before, "after": ordinary_after, "hidden": hidden, "plan": pending, "response": response, "vacated": vacated, "resolved": resolved.size(), "full_turns": [first_full, second_full], "expired": expired, "unrestored": unrestored})

func _integration_oracle() -> void:
	var data: Dictionary = _prayer_case("PRAYER_04")
	var payload: Dictionary = {"npc": data.petitioner, "source": data.source, "declared_action": "PRAYER/" + data.request + "/shallow"}
	_seed(data, "POWER_ORACLE", "success", payload)
	assert(_open(data))
	var oracle: Dictionary = _power(data, "POWER_ORACLE", payload)
	assert(oracle.ok and data.world.state.power_system.preparations.size() == 1)
	var preparation: String = data.world.state.power_system.preparations.keys()[0]
	var before: String = data.turn.snapshot()
	var plain: Dictionary = data.prayers.preview(data.turn, data.request, "shallow")
	var improved: Dictionary = data.prayers.preview(data.turn, data.request, "shallow", {"preparations": [preparation]})
	var pure: bool = before == data.turn.snapshot()
	var wrong_branch: bool = _reject_response(data, data.request, "deep", {"preparations": [preparation]})
	var duplicate: bool = _reject_response(data, data.request, "shallow", {"preparations": [preparation, preparation]})
	var response: Dictionary = _response(data, data.request, "shallow", {"preparations": [preparation]})
	var consumer: String = str(Store.entry(data.world.state.applied_authorizations, "power/preparation/" + preparation))
	var consumed: bool = data.world.state.power_system.preparations.is_empty() and Store.entry(data.world.state.facts, consumer).get("kind") == "prayer_attempt"
	var audit: Array = data.world.validate_state(data.world.state)
	var snapshot: String = data.turn.snapshot()
	var restored: Dictionary = _attach_prayers(_high())
	var restored_ok: bool = restored.turn.restore(snapshot) and restored.turn.snapshot() == snapshot
	_check("PRY-INTEGRATION-004", "神谕限定同请求同浅深分支加10，错分支/重复源无副作用拒绝，实际尝试唯一消费并完整恢复", oracle.ok and plain.ok and improved.ok and improved.probability == mini(catalog.integer("check_probability_max"), plain.probability + 10) and pure and wrong_branch and duplicate and response.ok and consumed and audit.is_empty() and restored_ok, {"plain": plain.get("probability"), "prepared": improved.get("probability"), "wrong_branch": wrong_branch, "duplicate": duplicate, "consumer": consumer, "audit": audit, "restored": restored_ok})
