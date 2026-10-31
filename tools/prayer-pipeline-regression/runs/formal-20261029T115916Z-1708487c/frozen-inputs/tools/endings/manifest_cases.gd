extends "res://tools/endings/high_fixture.gd"

func run_manifest_endings() -> void:
	for outcome: String in ["deep", "success", "failure", "disaster"]: _end_manifest_branch(outcome)
	for kind: String in ["death", "anchor", "zero", "upkeep"]: _end_priority(kind)
	_end_lock_and_focus()
	_end_interrupt(true)
	_end_interrupt(false)
	_end_ritual_save()
	_end_ending_rollback()

func _end_high(outcome: String = "success") -> Dictionary:
	var data: Dictionary = _ending_high()
	data.manifest_payload = _payload(data, "POWER_MANIFEST")
	var actor: String = data.manifest_payload.npc
	var domain: String = Store.entry(data.world.state.npcs, actor).domain
	var p: int = data.powers.probability(Store.entry(data.world.state.npcs, actor), data.world.state.domains[domain], catalog.tables.powers.POWER_MANIFEST, 0)
	var wanted: int = {"deep": 1, "success": maxi(3, int(p / 2.0)), "failure": int((p + 100) / 2.0), "disaster": 100}[outcome]
	# Set the initial stream once, before the first authoritative request.
	assert(Store.size(data.turn.context.receipts) == 0)
	for seed_value: int in range(1, 100000):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randi_range(1, 100) == wanted:
			data.world.randoms.checks.seed = seed_value; data.check_seed = seed_value; break
	return data

func _end_start(data: Dictionary) -> void:
	assert(_open(data) and _power(data, "POWER_MANIFEST", data.manifest_payload).ok)

func _end_third(data: Dictionary) -> void:
	_end_start(data)
	for i: int in 2:
		assert(_evolve(data) and _finish(data) and _open(data))
		assert(_power(data, "POWER_MANIFEST_CONTINUE", {"source": data.source}).ok)

func _end_ritual_checks(data: Dictionary) -> Array:
	return _facts(data.world, "turn_check").filter(func(f: Dictionary) -> bool: return f.changes.get("locked", false))

func _end_manifest_branch(outcome: String) -> void:
	var data: Dictionary = _end_high(outcome)
	_end_start(data)
	var early: bool = _end_ritual_checks(data).is_empty()
	for i: int in 2:
		assert(_evolve(data) and _finish(data) and _open(data))
		early = early and _end_ritual_checks(data).is_empty() and data.turn.context.phase != "ended"
		assert(_power(data, "POWER_MANIFEST_CONTINUE", {"source": data.source}).ok)
	var locked: int = data.world.state.power_system.manifest.probability
	var wounds: int = data.world.state.wounds
	assert(_evolve(data) and _finish(data))
	var checks: Array = _end_ritual_checks(data)
	var won: bool = outcome in ["deep", "success"]
	var effect: bool = data.turn.context.phase == "ended" and data.world.state.awakening == catalog.integer("awakening_terminal") if won else data.turn.context.phase == "between" and data.world.state.wounds == wounds + catalog.integer("manifest_failure_wounds" if outcome == "failure" else "manifest_disaster_wounds")
	if outcome == "disaster": effect = effect and data.world.state.anchors[data.manifest_payload.cosmic_anchor].state == "dormant"
	_check("END-MANIFEST/" + outcome, "真实连续三轮支付，前两轮无终骰，第三轮唯一锁定检定与正式结局 " + outcome, early and checks.size() == 1 and checks[0].changes.outcome == outcome and checks[0].changes.probability == locked and effect, {"early": early, "locked": locked, "checks": checks, "phase": data.turn.context.phase, "awakening": data.world.state.awakening, "wounds": data.world.state.wounds, "seed": data.check_seed})

func _end_priority(kind: String) -> void:
	var data: Dictionary = _end_high()
	_end_third(data)
	var ritual: Dictionary = data.world.state.power_system.manifest.duplicate(true)
	var rng: int = data.world.randoms.checks.state
	var subject: String = ritual.npc if kind == "death" else data.world.state.anchors[ritual.system_anchor].guardian
	var effect: Dictionary = {"type": "wounds", "source": ritual.source, "delta": data.world.state.awakening} if kind == "zero" else {"type": "world_command", "source": ritual.source, "command": {"kind": "status", "npc": subject, "status": "dead" if kind == "death" else "detained", "parents": [ritual.source]}}
	if kind == "upkeep":
		assert(_submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": [ritual.cosmic_anchor]}}).ok)
	else: data.fixture.deadlines = [effect]
	assert(_evolve(data) and _finish(data))
	var upkeep_failed: bool = kind != "upkeep" or data.world.state.anchors[ritual.cosmic_anchor].state == "dormant"
	_check("END-PRIORITY/" + kind, "第三轮已付后真实到期或供奉" + kind + "优先于终局骰且不退款", upkeep_failed and data.world.randoms.checks.state == rng and _end_ritual_checks(data).is_empty() and data.world.state.power_system.manifest.is_empty() and data.world.state.power_system.completion.is_empty() and (data.turn.context.phase == "ended" if kind == "zero" else data.turn.context.phase == "between"), {"ritual": ritual, "phase": data.turn.context.phase, "awakening": data.world.state.awakening, "rng_unchanged": data.world.randoms.checks.state == rng, "cosmic_anchor": data.world.state.anchors[ritual.cosmic_anchor].state})

func _end_lock_and_focus() -> void:
	var data: Dictionary = _end_high()
	_end_start(data)
	var ritual: Dictionary = data.world.state.power_system.manifest
	var cosmic: String = data.world.state.anchors[ritual.cosmic_anchor].domain
	var system: String = data.world.state.anchors[ritual.system_anchor].domain
	var occupied: bool = cosmic in data.world.state.simulation.focused and system in data.world.state.simulation.focused
	var release: Dictionary = _control(data, {"kind": "release_focus", "domain": cosmic})
	# Release is a scheduled request. The active ritual must keep its two
	# reservations through the next round, rather than require the request fail.
	var held: bool = release.ok and cosmic in data.world.state.simulation.focused
	for i: int in 2:
		assert(_evolve(data) and _finish(data) and _open(data) and _power(data, "POWER_MANIFEST_CONTINUE", {"source": data.source}).ok)
		held = held and cosmic in data.world.state.simulation.focused and system in data.world.state.simulation.focused and data.world.state.attention.reservations.has(data.world.state.power_system.manifest.token)
	var probability: int = data.world.state.power_system.manifest.probability
	var extra: String = ""
	for domain: String in data.world.state.domains:
		if not domain in data.world.state.simulation.focused: extra = domain; break
	var before_extra: String = data.turn.snapshot()
	var exceeded: Dictionary = _control(data, {"kind": "focus", "domain": extra})
	var budget_held: bool = not exceeded.ok and data.turn.snapshot() == before_extra
	var snapshot: String = data.turn.snapshot()
	var preview: Dictionary = data.endings.preview(data.turn)
	var pure: bool = snapshot == data.turn.snapshot()
	assert(_evolve(data) and _finish(data))
	var checks: Array = _end_ritual_checks(data)
	_check("END-MANIFEST-LOCK", "跨轮两域F不能免费撤回，第三轮概率预览纯读并在唯一终骰使用原值", occupied and held and budget_held and pure and checks.size() == 1 and checks[0].changes.probability == probability, {"occupied": occupied, "release": release, "extra_focus": exceeded, "preview": preview, "probability": probability})

func _end_interrupt(cancel: bool) -> void:
	var data: Dictionary = _end_high()
	_end_start(data)
	var paid: int = data.world.state.faith
	var rng: int = data.world.randoms.checks.state
	var result: Dictionary = {"ok": true}
	if cancel:
		result = _power(data, "POWER_MANIFEST_CANCEL", {"source": data.source})
	else:
		assert(_evolve(data) and _finish(data) and _round(data))
	_check("END-MANIFEST-CANCEL" if cancel else "END-MANIFEST-UNPAID", "真实仪式" + ("主动取消不退款" if cancel else "漏付第二轮中断") + "且无终骰和附赠创伤", result.ok and data.world.state.power_system.manifest.is_empty() and _end_ritual_checks(data).is_empty() and data.world.randoms.checks.state == rng and data.world.state.wounds == 0 and (data.world.state.faith == paid if cancel else true), {"result": result, "phase": data.turn.context.phase, "wounds": data.world.state.wounds})

func _end_ritual_save() -> void:
	var data: Dictionary = _end_high()
	_end_third(data)
	var saved: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(saved)
	var denied: bool = true
	for field: String in ["probability", "progress", "npc", "token"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world: Dictionary = JSON.parse_string(envelope.body.world)
		var ritual: Dictionary = world.body.state.power_system.manifest
		match field:
			"probability": ritual.probability = 90 if ritual.probability != 90 else 10
			"progress": ritual.progress = 2
			"npc": ritual.npc = data.leader
			"token": ritual.token = "forged"
		world.checksum = World.canonical(world.body).sha256_text(); envelope.body.world = World.canonical(world)
		envelope.checksum = World.canonical(envelope.body).sha256_text()
		denied = not data.turn.restore(World.canonical(envelope)) and data.turn.snapshot() == saved and denied
	assert(_evolve(data) and _finish(data))
	var result: String = data.world.snapshot()
	assert(data.turn.restore(saved) and _evolve(data) and _finish(data))
	_check("END-SAVE-002", "第三轮活动仪式存档重放同一终局，重算checksum篡改主体/概率/进度/预留仍拒绝", restored and denied and data.world.snapshot() == result, {"restored": restored, "denied": denied})

func _end_ending_rollback() -> void:
	var data: Dictionary = _end_high()
	_end_third(data)
	assert(_evolve(data) and _submit(data, "advance").ok)
	var before: String = data.turn.snapshot()
	data.endings.fault_after_commit = true
	var failed: Dictionary = _submit(data, "advance")
	var atomic: bool = not failed.ok and data.turn.snapshot() == before
	data.endings.fault_after_commit = false
	var retried: Dictionary = _submit(data, "advance")
	_check("END-SAVE-003", "真实第六阶段故障整批回滚不留半终局，重试只投一次骰并封存", atomic and retried.ok and _end_ritual_checks(data).size() == 1 and data.turn.context.phase == "ended", {"atomic": atomic, "failed": failed, "retried": retried})
