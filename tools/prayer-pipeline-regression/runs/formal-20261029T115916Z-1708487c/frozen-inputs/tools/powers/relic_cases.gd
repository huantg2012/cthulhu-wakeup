extends "res://tools/powers/power_cases.gd"
## Actual hybrid sessions. Only upstream narrative grants and the explicitly
## preexisting high-world inventory are fixtures; all tested changes use Turn.
func run_relic_cases() -> void:
	for type: String in catalog.tables.relics:
		for mode: String in ["faith", "insight", "followers", "whispers"]: _conversion_case(type, mode)
	for mode: String in ["faith", "insight", "followers", "whispers"]: _capacity_case(mode)
	_inventory_case()
	_binding_case()
	_seal_case()
	_seizure_case()
	_transfer_case()
	_death_case()
	for type: String in catalog.tables.relics: _carry_case(type)

func _relic_act(data: Dictionary, action: String, payload: Dictionary) -> Dictionary:
	return _submit(data, "act", {"participant": "relics", "action": "relic_" + action, "payload": payload})

func _item(data: Dictionary, id: String) -> Dictionary:
	return Store.entry(data.world.state.relics, id)

func _rejected(data: Dictionary, action: String, payload: Dictionary) -> bool:
	var before: String = data.turn.snapshot()
	return not _relic_act(data, action, payload).ok and before == data.turn.snapshot()

func _conversion_case(type: String, mode: String) -> void:
	var data: Dictionary = _high()
	data.world.state.insight = 0; data.world._refresh_anchors()
	var source: String = _relic_source(data.world, "DOMAIN-001", type)
	_attach_powers(data); assert(_open(data))
	var made: bool = _relic_act(data, "create", {"source": source}).ok
	var id: String = Relics.instance_id(source)
	# Leave enough real action-budget headroom to observe the full table value,
	# including the Ember's release of two; no direct whisper mutation.
	if mode == "whispers" and made:
		made = _relic_act(data, "equip", {"source": source, "relic": id, "npc": data.leader}).ok and made
		made = _relic_act(data, "unequip", {"source": source, "relic": id}).ok and made
	var state: Dictionary = data.world.state
	var before: Dictionary = {"faith": state.faith, "insight": state.insight, "followers": state.domains["DOMAIN-001"].unnamed_followers, "whispers": state.whispers, "population": state.domains["DOMAIN-001"].population, "alert": state.domains["DOMAIN-001"].alert}
	var payload: Dictionary = {"source": source, "relic": id, "mode": mode}
	var saved: String = data.turn.snapshot()
	var preview: Dictionary = data.relics.preview(state, "disassemble", payload, data.turn.context.whispers_budget)
	var pure: bool = saved == data.turn.snapshot()
	var result: Dictionary = _relic_act(data, "disassemble", payload)
	var row: Dictionary = catalog.tables.relics[type]
	var value: int = int(row[{"faith": "faith_disassembly", "insight": "insight_disassembly", "followers": "follower_gift", "whispers": "whisper_release"}[mode]])
	var actual: int = int(data.world.state.domains["DOMAIN-001"].unnamed_followers) - int(before.followers) if mode == "followers" else int(data.world.state[mode]) - int(before[mode])
	var valid: bool = made and preview.ok and pure and result.ok and preview.preview.net_gain == value and actual == value and _item(data, id).placement == "consumed"
	valid = valid and int(data.world.state.whispers) == int(before.whispers) + (value if mode == "whispers" else -catalog.integer("relic_operation_whispers"))
	valid = valid and int(data.world.state.domains["DOMAIN-001"].population) == int(before.population)
	if mode == "followers":
		var fact: Dictionary = Store.entry(data.world.state.facts, data.world.state.domains["DOMAIN-001"].population_source)
		valid = valid and fact.kind == "population_transfer" and _item(data, id).status_source in fact.causal_parents
	if mode == "whispers": valid = valid and int(data.world.state.domains["DOMAIN-001"].alert) - int(before.alert) == int(catalog.tables.relic_effects[type].release_alert) and data.world.state.domains["DOMAIN-001"].exposure_turn == data.world.state.turn
	valid = valid and _rejected(data, "disassemble", payload) and _rejected(data, "create", {"source": source})
	_check("RELIC/convert/" + type + "/" + mode, "真实CSV转化、人口/低语口径及同源唯一消费", valid, {"type": type, "mode": mode, "expected": value, "actual": actual, "pure": pure, "error": result.get("error", "")})

func _capacity_case(mode: String) -> void:
	var data: Dictionary = _high()
	var id: String = _given_relic(data.world, "DOMAIN-001", "RELIC_LAST_EMBER")
	if mode == "faith": data.world.state.faith = Economy.capacity(data.world.state, catalog)
	if mode == "insight": data.world.state.insight = catalog.integer("insight_cap")
	if mode == "followers":
		var available: int = data.world.state.domains["DOMAIN-001"].unnamed_nonfollowers
		assert(data.world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": available, "parents": [data.source]}))
	_attach_powers(data); assert(_open(data))
	var payload: Dictionary = {"source": data.source, "relic": id, "mode": mode}
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.relics.preview(data.world.state, "disassemble", payload, data.turn.context.whispers_budget)
	var preserved: bool = preview.ok and preview.preview.net_gain == 0 and before == data.turn.snapshot() and _item(data, id).placement == "controlled"
	var executed: Dictionary = _relic_act(data, "disassemble", payload)
	_check("RELIC/capacity/" + mode, "满容量净零只预览不消费，明确执行才解离", preserved and executed.ok and _item(data, id).placement == "consumed", {"mode": mode, "preview": preview.get("preview", {}), "preserved": preserved, "executed": executed.ok})

func _inventory_case() -> void:
	var data: Dictionary = _high()
	var source: String = _relic_source(data.world, "DOMAIN-001", "RELIC_ECHO_BELL")
	var second: String = _given_relic(data.world, "DOMAIN-001", "RELIC_LIVING_SCRIPT")
	_attach_powers(data); assert(_open(data))
	var id: String = Relics.instance_id(source)
	var created: bool = _relic_act(data, "create", {"source": source}).ok
	var once: bool = _rejected(data, "create", {"source": source})
	var equipped: bool = _relic_act(data, "equip", {"source": source, "relic": id, "npc": data.leader}).ok
	var denied: bool = _rejected(data, "equip", {"source": data.source, "relic": second, "npc": data.leader})
	var unequipped: bool = _relic_act(data, "unequip", {"source": source, "relic": id}).ok
	_check("RELIC/inventory", "来源只发一件、携带位唯一、明确卸下回本域库藏", created and once and equipped and denied and unequipped and _item(data, id).placement == "controlled" and _item(data, id).holder.is_empty(), {"created": created, "unique": once, "equipped": equipped, "occupied_rejected": denied, "unequipped": unequipped})

func _binding_case() -> void:
	var data: Dictionary = _high(true)
	var source: String = _relic_source(data.world, "DOMAIN-001", "RELIC_ECHO_BELL", "carried", data.leader)
	var id: String = Relics.instance_id(source)
	var payload: Dictionary = _payload(data, "POWER_ANCHOR"); payload.relic = id
	_seed(data, "POWER_ANCHOR", "success", payload)
	_attach_powers(data); assert(_open(data))
	var made: bool = _relic_act(data, "create", {"source": source}).ok
	var bound: bool = _power(data, "POWER_ANCHOR", payload).ok and _item(data, id).placement == "bound"
	var anchor: String = "ANCHOR/DOMAIN-001/interpretation"
	var denied: bool = _rejected(data, "equip", {"source": source, "relic": id, "npc": data.leader}) and _rejected(data, "disassemble", {"source": source, "relic": id, "mode": "faith"})
	denied = denied and not data.relics.preparation(data.world.state, id, "POWER_DREAM", data.leader).ok
	var snapshot: String = data.turn.snapshot()
	var restored: Dictionary = _attach_powers(_high())
	var archive_path: String = scratch.path_join("relic-binding-" + str(Time.get_ticks_usec()))
	var saved: bool = data.turn.save_archive(archive_path)
	var loaded: bool = saved and restored.turn.load_archive(archive_path) and restored.turn.snapshot() == snapshot
	var envelope: Dictionary = JSON.parse_string(snapshot)
	var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
	world_envelope.body.state.relics[id].placement = "remote_inventory"
	world_envelope.checksum = World.canonical(world_envelope.body).sha256_text()
	envelope.body.world = World.canonical(world_envelope); envelope.checksum = World.canonical(envelope.body).sha256_text()
	var corrupt: bool = not data.turn.restore(World.canonical(envelope)) and data.turn.snapshot() == snapshot
	_check("RELIC/binding-save", "真实锚定绑定互斥、分段恢复一致及正确校验和非法归属拒绝", made and bound and denied and loaded and corrupt, {"bound": bound, "exclusive": denied, "archive": loaded, "bad_placement_rejected": corrupt})
	var unbound: bool = _relic_act(data, "unbind", {"source": source, "relic": id}).ok
	_check("RELIC/unbind", "解绑立即休眠且必须重新锚定，普通供奉不能免费重绑", unbound and _item(data, id).placement == "controlled" and data.world.state.anchors[anchor].state == "dormant" and data.world.state.anchors[anchor].needs_rebind and not Economy.anchor_eligibility(data.world.state, data.world.state.anchors[anchor], catalog).reason.is_empty(), {"unbound": unbound})

func _authorization_effect(data: Dictionary, operation: String, id: String, details: Dictionary = {}, version_source: String = "") -> Dictionary:
	var relic: Dictionary = _item(data, id)
	var status: String = relic.status_source if version_source.is_empty() else version_source
	var changes: Dictionary = details.duplicate(true)
	changes["proof"] = {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": relic.domain, "target": id, "holder": str(details.get("holder", "")), "status_source": status}
	return {"type": "fact", "source": data.source, "parents": [status], "kind": "relic_" + operation + "_authorized", "domain": relic.domain, "actor": "", "targets": [id], "details": changes, "observers": [], "institutions": []}

func _next_authorizations(data: Dictionary, effects: Array) -> void:
	data.fixture.gather = effects
	assert(_evolve(data) and _finish(data) and _open(data))
	data.fixture.gather = []

func _seal_case() -> void:
	var data: Dictionary = _high()
	var id: String = _given_relic(data.world, "DOMAIN-001", "RELIC_ECHO_BELL")
	var status: String = _item(data, id).status_source
	var source: String = data.world.introduce_fact("relic_seal_authorized", "DOMAIN-001", "", [id], [status], {"duration": 2, "proof": {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": "DOMAIN-001", "target": id, "holder": "", "status_source": status}}, [])
	_attach_powers(data); assert(_open(data))
	var sealed: bool = _relic_act(data, "seal", {"source": source, "relic": id}).ok
	var until: int = _item(data, id).get("sealed_until", -1)
	var first: bool = _rejected(data, "equip", {"source": data.source, "relic": id, "npc": data.leader})
	assert(_evolve(data) and _finish(data) and _open(data))
	var second: bool = _item(data, id).placement == "sealed"
	assert(_evolve(data) and _finish(data) and _open(data))
	var third: bool = _item(data, id).placement == "sealed"
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("RELIC/seal-expiry", "封存覆盖后续完整两轮，到期原位置重查后回库", sealed and until == 4 and first and second and third and _item(data, id).placement == "controlled", {"until": until, "second": second, "third": third, "released": _item(data, id).placement})

func _seizure_case() -> void:
	var data: Dictionary = _high()
	var source: String = _relic_source(data.world, "DOMAIN-001", "RELIC_WITNESS_LENS")
	_attach_powers(data); assert(_open(data))
	var id: String = Relics.instance_id(source)
	assert(_relic_act(data, "create", {"source": source}).ok)
	_next_authorizations(data, [_authorization_effect(data, "recover", id), _authorization_effect(data, "seize", id, {"institution": "DOMAIN-001/order"})])
	var stale: String = _facts(data.world, "relic_recover_authorized")[-1].id
	var seize: String = _facts(data.world, "relic_seize_authorized")[-1].id
	var seized: bool = _relic_act(data, "seize", {"source": seize, "relic": id}).ok and _item(data, id).placement == "seized"
	var rejected: bool = _rejected(data, "recover", {"source": stale, "relic": id})
	_next_authorizations(data, [_authorization_effect(data, "recover", id)])
	var current: String = _facts(data.world, "relic_recover_authorized")[-1].id
	var recovered: bool = _relic_act(data, "recover", {"source": current, "relic": id}).ok and _item(data, id).placement == "controlled"
	_check("RELIC/seize-recover", "扣押后旧未用证明失效，当前状态授权才可回收且不换实例", seized and rejected and recovered and _rejected(data, "recover", {"source": current, "relic": id}), {"seized": seized, "stale_rejected": rejected, "recovered": recovered})
	_next_authorizations(data, [_authorization_effect(data, "destroy", id)])
	var destroy: String = _facts(data.world, "relic_destroy_authorized")[-1].id
	var destroyed: bool = _relic_act(data, "destroy", {"source": destroy, "relic": id}).ok and _item(data, id).placement == "consumed"
	_check("RELIC/destroy", "真实毁灭保留墓碑，旧创建源和回收证明均不能复用", destroyed and _rejected(data, "create", {"source": source}) and _rejected(data, "recover", {"source": current, "relic": id}), {"destroyed": destroyed})

func _carry_value(data: Dictionary, row: Dictionary, actor: String, domain: String) -> int:
	if row.carry_subject in ["actor", "holder"]: return int(Store.entry(data.world.state.npcs, actor)[row.carry_field])
	if row.carry_subject == "domain": return int(data.world.state.domains[domain][row.carry_field])
	for cult: Dictionary in data.world.state.cults.values():
		if cult.domain == domain: return int(cult[row.carry_field])
	return -999

func _roll_one(world: RefCounted) -> void:
	for seed_value: int in range(1, 10001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randi_range(1, 100) == 1: world.randoms.checks.seed = seed_value; return
	assert(false)

func _carry_trial(type: String, use_preparation: bool) -> Dictionary:
	var row: Dictionary = catalog.tables.relic_effects[type]
	var power: String = "POWER_MANIFEST" if type == "RELIC_LAST_EMBER" else str(row.powers).split("|")[0]
	var data: Dictionary = _high(power == "POWER_ANCHOR")
	var payload: Dictionary = _payload(data, power)
	var actor: String = payload.npc
	var domain: String = Store.entry(data.world.state.npcs, actor).domain
	var source: String = _relic_source(data.world, domain, type, "carried", actor)
	var id: String = Relics.instance_id(source)
	_roll_one(data.world)
	_attach_powers(data); assert(_open(data))
	var made: bool = _relic_act(data, "create", {"source": source}).ok
	if use_preparation: payload.preparation_relic = id
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.powers.preview(data.turn, power, payload)
	var pure: bool = before == data.turn.snapshot()
	var result: Dictionary = _power(data, power, payload)
	var paid: Array = _facts(data.world, "relic_preparation_paid")
	var bound_to_attempt: bool = false
	for fact: Dictionary in paid:
		for parent: String in fact.causal_parents:
			var cause: Dictionary = Store.entry(data.world.state.facts, parent)
			if cause.kind == "power_attempt" and cause.changes.payload.get("preparation_relic") == id: bound_to_attempt = true
	return {"bound_to_attempt": bound_to_attempt, "ok": made and preview.ok and pure and result.ok, "value": _carry_value(data, row, actor, domain), "paid": paid, "probability": preview.get("probability", -1), "error": result.get("error", ""), "exposure": data.world.state.domains[domain].exposure_turn, "turn": data.world.state.turn}

func _carry_case(type: String) -> void:
	var baseline: Dictionary = _carry_trial(type, false)
	var selected: Dictionary = _carry_trial(type, true)
	var row: Dictionary = catalog.tables.relic_effects[type]
	var delta: int = int(selected.value) - int(baseline.value)
	var paid: bool = baseline.paid.is_empty() and selected.paid.size() == 1 and selected.bound_to_attempt
	if paid: paid = selected.paid[0].changes.field == row.carry_field and int(selected.paid[0].changes.delta) == int(row.carry_delta)
	if row.carry_subject == "domain" and row.carry_field == "alert" and int(row.carry_delta) > 0: paid = paid and selected.exposure == selected.turn
	_check("RELIC/carry/" + type, "真实权能对照：选中准备才付一次携带代价，预览纯读", baseline.ok and selected.ok and paid and delta == int(row.carry_delta), {"type": type, "baseline": baseline.value, "selected": selected.value, "delta": delta, "expected_delta": int(row.carry_delta), "baseline_probability": baseline.probability, "selected_probability": selected.probability, "paid_count": selected.paid.size(), "baseline_error": baseline.error, "selected_error": selected.error})

func _transfer_case() -> void:
	var data: Dictionary = _high()
	var source: String = _relic_source(data.world, "DOMAIN-001", "RELIC_WITNESS_LENS", "carried", data.leader)
	var id: String = Relics.instance_id(source)
	var payload: Dictionary = _payload(data, "POWER_TRANSFER")
	_roll_one(data.world)
	_attach_powers(data); assert(_open(data))
	var made: bool = _relic_act(data, "create", {"source": source}).ok
	var moved: Dictionary = _power(data, "POWER_TRANSFER", payload)
	var relic: Dictionary = _item(data, id)
	var person: Dictionary = Store.entry(data.world.state.npcs, data.leader)
	var source_fact: Dictionary = Store.entry(data.world.state.facts, relic.status_source)
	var valid: bool = made and moved.ok and relic.id == id and relic.origin == source and relic.placement == "carried" and relic.holder == data.leader and relic.domain == payload.target_domain and person.domain == payload.target_domain and relic.status_source == person.status_source and source_fact.kind == "migration"
	var before: String = data.turn.snapshot()
	var restored: Dictionary = _attach_powers(_high())
	valid = valid and restored.turn.restore(before) and restored.turn.snapshot() == before and _item(restored, id).domain == payload.target_domain
	_check("RELIC/transfer-carry", "真实迁引携带同一物件与持有人迁域，当前迁移源保存恢复一致", valid, {"moved": moved.ok, "domain": relic.domain, "holder_domain": person.domain, "status_source": relic.status_source, "source_kind": source_fact.kind})

func _death_case() -> void:
	var data: Dictionary = _high()
	var domain: String = ""
	for candidate: String in data.world.state.domains:
		var has_cult: bool = false
		for cult: Dictionary in data.world.state.cults.values(): has_cult = has_cult or cult.domain == candidate
		if not has_cult: domain = candidate; break
	assert(not domain.is_empty())
	var carriers: Array = []
	for i: int in 2:
		var person: String = "NPC-%08d" % int(data.world.state.next_npc)
		assert(data.world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", data.world.state.domains[domain].origin))
		_bind(data.world, person); carriers.append(person)
	var source: String = _relic_source(data.world, domain, "RELIC_LAST_EMBER", "carried", carriers[0])
	var id: String = Relics.instance_id(source)
	_attach_powers(data); assert(_open(data))
	assert(_relic_act(data, "create", {"source": source}).ok)
	_next_authorizations(data, [{"type": "world_command", "source": source, "command": {"kind": "status", "npc": carriers[0], "status": "dead", "parents": [source]}}])
	var relic: Dictionary = _item(data, id)
	var person: Dictionary = Store.entry(data.world.state.npcs, carriers[0])
	var death: Dictionary = Store.entry(data.world.state.facts, relic.status_source)
	var dropped: bool = relic.placement == "ground" and relic.holder.is_empty() and relic.domain == domain and relic.status_source == person.status_source and death.kind == "status_change" and death.changes.to == "dead"
	var before: String = data.turn.snapshot()
	var restored: Dictionary = _attach_powers(_high())
	var path: String = scratch.path_join("relic-death-" + str(Time.get_ticks_usec()))
	var loaded: bool = data.turn.save_archive(path) and restored.turn.load_archive(path) and restored.turn.snapshot() == before and _item(restored, id).placement == "ground"
	_next_authorizations(data, [_authorization_effect(data, "recover", id, {"holder": carriers[1]})])
	var authorization: String = _facts(data.world, "relic_recover_authorized")[-1].id
	var recovered: Dictionary = _relic_act(data, "recover", {"source": authorization, "relic": id, "npc": carriers[1]})
	var current: Dictionary = _item(data, id)
	_check("RELIC/death-ground", "实际死亡无教团时落地，死亡当前源归档恢复后可凭新授权本地回收", dropped and loaded and recovered.ok and current.id == id and current.origin == source and current.placement == "carried" and current.holder == carriers[1], {"dropped": dropped, "death_source": person.status_source, "archive": loaded, "recovered": recovered.ok, "placement": current.placement, "error": recovered.get("error", "")})
