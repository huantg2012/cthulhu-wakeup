extends "res://tools/resistance/run.gd"

var propagation_setup: bool = false

func _attach_prayers(data: Dictionary) -> Dictionary:
	if propagation_setup:
		# Legal preexisting midgame conditions, before the first Turn receipt.
		# The cosmic anchor and its proof will be produced through real play.
		data.world.state.insight = catalog.integer("insight_cap")
		data.receiving = data.world.state.domains[data.domain].neighbors[0]
		data.unreachable = ""
		for id: String in data.world.state.domains:
			if id != data.domain and not id in data.world.state.domains[data.domain].neighbors:
				data.unreachable = id
				break
		assert(not data.unreachable.is_empty())
		for domain: String in [data.receiving, data.unreachable]:
			var person: String = _local_person(data.world, domain, domain + "/interpretation")
			var origin: String = data.world.state.domains[domain].origin
			assert(data.world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
			var auth: String = data.world.introduce_fact("cult_establishment_authorized", domain, person, [person], [origin], {"issuer": "cult-fixture", "version": "1", "cult": "CULT/" + domain, "domain": domain, "leader": person, "cohesion": 100}, [])
			assert(data.world.submit({"kind": "establish_cult", "authorization": auth, "parents": [auth]}))
		data.traveler = data.people[1]
		data.secret = data.world.introduce_fact("message", data.domain, data.traveler, [data.traveler], [data.source], {"fixture": "existing_private_knowledge"}, [data.traveler], [])
		data.world.state.domains[data.receiving].barrier = 80
		data.world.state.domains[data.receiving].alert = 20
		data.world._refresh_anchors()
		data.world.attention.sync(data.world)
		data.world.history.rebuild(data.world.state)
	return super._attach_prayers(data)

func _produce_support(data: Dictionary) -> void:
	if not propagation_setup:
		super._produce_support(data)
		return
	# Choose the initial stream once for prayer, anchoring, then migration.
	# No RNG changes after the first command, and no injected success results.
	assert(data.requests.size() == 1)
	var found: bool = false
	for seed_value: int in range(1, 1000001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var usable: bool = true
		for step: int in 3:
			usable = rng.randi_range(1, 100) <= catalog.integer("check_probability_min") and usable
		if usable:
			data.world.randoms.checks.seed = seed_value
			data.check_seed = seed_value
			found = true
			break
	assert(found)
	assert(_open(data) and _response(data, data.requests[0], "deep").ok)
	data.outputs.append(data.requests[0])
	assert(_evolve(data) and _finish(data))

func run_propagation() -> void:
	propagation_setup = true
	var data: Dictionary = _actual_recognition("CIV_08")
	propagation_setup = false
	var proofs: Array = _facts(data.world, "institution_event_result").filter(func(f: Dictionary) -> bool: return f.changes.institution == data.institution)
	assert(not proofs.is_empty())
	data.proof = proofs[-1].id
	assert(_create_anchor(data).ok and _evolve(data) and _finish(data))
	assert(data.world.state.anchors[data.anchor].state == "active")
	assert(data.world.state.awakening >= int(catalog.tables.powers.POWER_TRANSFER.unlock_awakening))
	assert(_open(data))
	var payload: Dictionary = {"npc": data.traveler, "source": data.secret, "target_domain": data.receiving, "escort": 4}
	var before: String = data.turn.snapshot()
	var good: Dictionary = data.powers.preview(data.turn, "POWER_TRANSFER", payload)
	var bad_payload: Dictionary = payload.duplicate(true)
	bad_payload.target_domain = data.unreachable
	var bad: Dictionary = data.powers.preview(data.turn, "POWER_TRANSFER", bad_payload)
	var denied: Dictionary = _power(data, "POWER_TRANSFER", bad_payload)
	_check("RES-PROP-001", "真实宇宙锚达到原解锁门槛；有接收教团但无通路仍原子拒绝迁引", good.ok and not bad.ok and not denied.ok and data.turn.snapshot() == before and str(bad.get("error", "")).contains("reachable"), {"good": good, "bad": bad, "result": denied, "anchor": data.anchor, "insight": data.world.state.insight, "awakening": data.world.state.awakening})
	var person: Dictionary = Store.entry(data.world.state.npcs, data.traveler)
	var expected: int = data.powers.probability(person, data.world.state.domains[data.receiving], catalog.tables.powers.POWER_TRANSFER, 0)
	var populations: int = data.world.state.domains[data.domain].population + data.world.state.domains[data.receiving].population
	var count: int = Store.size(data.world.state.npcs)
	var result: Dictionary = _power(data, "POWER_TRANSFER", payload)
	var checks: Array = _facts(data.world, "turn_check").filter(func(f: Dictionary) -> bool: return f.domain == data.receiving and f.actor == data.traveler)
	var migrated: Dictionary = Store.entry(data.world.state.npcs, data.traveler)
	# Taking focus may lawfully nominate destination officials from its unnamed
	# population. Total population, not named-row count, is the invariant here.
	_check("RES-PROP-002", "迁引实际使用目标域屏障与察觉检定，沿合法通路移动同一人物并守恒人口", result.ok and good.get("probability") == expected and not checks.is_empty() and checks[-1].changes.probability == expected and migrated.domain == data.receiving and migrated.id == data.traveler and populations == data.world.state.domains[data.domain].population + data.world.state.domains[data.receiving].population, {"result": result, "expected_probability": expected, "check": checks[-1] if not checks.is_empty() else {}, "destination": migrated.domain, "population_before": populations, "population_after": data.world.state.domains[data.domain].population + data.world.state.domains[data.receiving].population, "named_before": count, "named_after": Store.size(data.world.state.npcs)})
	var private: bool = History.has(migrated.known_facts, data.secret)
	for domain: String in [data.receiving, data.unreachable]:
		for institution: String in data.world.state.domains[domain].institutions:
			private = private and not History.has(data.world.state.institutions[institution].known_facts, data.secret)
	_check("RES-PROP-003", "迁移保留个人知识，通路/邻接及因果父项不自动授予目标或未知文明机构全知", result.ok and private, {"source": data.secret, "traveler": data.traveler, "target": data.receiving, "unreachable": data.unreachable})
