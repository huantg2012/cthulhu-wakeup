extends SceneTree

const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
var catalog: RefCounted
var checks: Array = []
var metrics: Dictionary = {}
var samples: Dictionary = {}

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("SIM-001", "正式 CSV 装载与边界", loaded, {"errors": catalog.errors, "tables": catalog.tables.keys(), "content": catalog.version})
	if not loaded:
		_finish()
		return
	_test_bad_catalog()
	_test_generation()
	_test_attributes()
	_test_autonomy()
	_test_lifecycle()
	_test_causality_and_growth()
	_test_integration_boundaries()
	_test_regression_boundaries()
	_test_replay_and_save()
	_test_long_runs()
	_finish()

func _check(id: String, name: String, condition: bool, details: Dictionary = {}) -> void:
	checks.append({"id": id, "name": name, "status": "pass" if condition else "fail", "details": details})
	print(("PASS " if condition else "FAIL ") + id + " " + name)

func _new(seed_value: int = 104729) -> RefCounted:
	var world: RefCounted = World.new(catalog)
	assert(world.generate(seed_value), world.last_error)
	return world

func _clone(world: RefCounted) -> RefCounted:
	var other: RefCounted = World.new(catalog)
	assert(other.restore(world.snapshot()), other.last_error)
	return other

func _person(world: RefCounted, role: String = "order", domain_id: String = "DOMAIN-001") -> String:
	return world.state.institutions[domain_id + "/" + role].representative

func _origin(world: RefCounted, domain_id: String = "DOMAIN-001") -> String:
	return world.state.domains[domain_id].origin

func _controlled() -> RefCounted:
	var world: RefCounted = _new()
	for npc: Dictionary in world.state.npcs.values():
		npc.sanity = 80
		npc.loyalty = 40
	return world

func _fact(world: RefCounted, kind: String, person: String, targets: Array, details: Dictionary = {}, observers: Array = [], institutions: Array = []) -> String:
	var domain: String = world.state.npcs[person].domain
	return world.introduce_fact(kind, domain, person, targets, [_origin(world, domain)], details, observers, institutions)

func _test_generation() -> void:
	var valid: bool = true
	var combinations: Dictionary = {}
	for seed_value: int in range(200, 232):
		var world: RefCounted = _new(seed_value)
		valid = valid and world.validate_state(world.state).is_empty()
		valid = valid and world.state.domains.size() == catalog.integer("domains_total") and world.state.npcs.size() == catalog.integer("domains_total") * catalog.integer("initial_named_per_domain")
		combinations[World.canonical(world.state.domains).sha256_text()] = true
	_check("SIM-002", "正式配额与有限合法世界生成", valid and combinations.size() > 1, {"seeds": 32, "domains_per_seed": 12, "named_per_seed": 72, "distinct_worlds": combinations.size()})
	var world: RefCounted = _new()
	var lawful: bool = true
	for npc: Dictionary in world.state.npcs.values():
		lawful = lawful and world._profile_legal(catalog.tables.npc_profiles[npc.profile], npc.domain, npc.institution)
	lawful = lawful and not world._profile_legal(catalog.tables.npc_profiles.NPC_PROFILE_04, "DOMAIN-001", "")
	lawful = lawful and not world._profile_legal(catalog.tables.npc_profiles.NPC_PROFILE_06, "DOMAIN-001", "DOMAIN-001/propagation")
	_check("SIM-004", "岗位先于人物；无灾难/听众不凭空授予", lawful)
	var before: String = world.snapshot()
	var original: Dictionary = catalog.tables.civilization_profiles.duplicate(true)
	for key: String in original:
		if original[key].tier == "cosmic":
			catalog.tables.civilization_profiles.erase(key)
	var refused: bool = not world.generate(1)
	catalog.tables.civilization_profiles = original
	_check("SIM-021", "无合法蓝本明确失败且不半替换世界", refused and world.snapshot() == before)

func _test_attributes() -> void:
	var world: RefCounted = _controlled()
	var person: String = _person(world)
	world.state.domains["DOMAIN-001"].barrier = 0
	world.state.domains["DOMAIN-001"].alert = 0
	world.state.npcs[person].sanity = 50
	var comparisons: Dictionary = {}
	var valid: bool = true
	for attribute: String in World.ATTRIBUTES:
		world.state.npcs[person][attribute] = 1
		var low: int = world.check_probability(person, attribute, "DOMAIN-001")
		world.state.npcs[person][attribute] = 2
		var high: int = world.check_probability(person, attribute, "DOMAIN-001")
		comparisons[attribute] = [low, high]
		valid = valid and high - low == catalog.integer("check_attribute_step")
	for probability: int in range(catalog.integer("check_probability_min"), catalog.integer("check_probability_max") + 1):
		var successes: int = 0
		for roll: int in range(1, 101):
			var outcome: String = world.check_result(probability, roll)
			valid = valid and outcome in ["deep", "success", "failure", "disaster"]
			if outcome in ["deep", "success"]:
				successes += 1
		valid = valid and successes == probability
	_check("SIM-003", "四项正式属性与四档检定真实生效", valid, comparisons)

func _behavior_world(behavior: String, attribute: String, value: int) -> Dictionary:
	var world: RefCounted = _controlled()
	var actor: String = _person(world)
	var target: String = _person(world, "interpretation")
	world.state.npcs[actor][attribute] = value
	var source: String = ""
	match behavior:
		"NPC_RECOVER":
			world.state.npcs[actor].sanity = 40
			source = _fact(world, "strain", actor, [actor], {"sanity_delta": -20}, [actor])
			target = actor
		"NPC_EXAMINE":
			source = _fact(world, "exposure", target, [target], {"public": false}, [actor], ["DOMAIN-001/order"])
		"NPC_COMFORT":
			world.state.npcs[target].sanity = 40
			var relation: String = world._record("relationship", "DOMAIN-001", actor, [target], [_origin(world)], {"kind": "support"})
			world.state.npcs[actor].relations = [{"target": target, "kind": "support", "source": relation}]
			source = _fact(world, "harm", target, [target], {"sanity_delta": -20}, [actor, target])
		"NPC_INTERPRET":
			source = _fact(world, "miracle", actor, [actor], {"witnesses": [actor], "public": false}, [actor])
			target = actor
	return {"world": world, "actor": actor, "target": target, "source": source}

func _test_autonomy() -> void:
	var valid: bool = true
	var output: Dictionary = {}
	var pairs: Dictionary = {"NPC_RECOVER": "will", "NPC_EXAMINE": "insight", "NPC_COMFORT": "influence", "NPC_INTERPRET": "adaptation"}
	for behavior: String in pairs:
		var low: Dictionary = _behavior_world(behavior, pairs[behavior], 1)
		var high: Dictionary = _behavior_world(behavior, pairs[behavior], 5)
		var a: Dictionary = low.world.choose_behavior(low.actor)
		var b: Dictionary = high.world.choose_behavior(high.actor)
		valid = valid and a.get("behavior") == behavior and b.get("behavior") == behavior and int(b.get("amount", 0)) > int(a.get("amount", 0))
		low.world.advance()
		high.world.advance()
		var field: String = "loyalty" if behavior == "NPC_INTERPRET" else "sanity"
		var low_result: int = int(low.world.state.npcs[low.target][field])
		var high_result: int = int(high.world.state.npcs[high.target][field])
		if behavior == "NPC_EXAMINE":
			var key: String = "DOMAIN-001/order|" + str(low.target)
			low_result = int(low.world.state.evidence[key].strength)
			high_result = int(high.world.state.evidence[key].strength)
			valid = valid and low.world.state.evidence[key].confirmations.is_empty() and not high.world.state.evidence[key].confirmations.is_empty()
		valid = valid and high_result > low_result
		output[behavior] = {"attribute": pairs[behavior], "low_result": low_result, "high_result": high_result}
	_check("SIM-005", "四属性单变量对照改变实际行为结果", valid, output)
	var world: RefCounted = _controlled()
	world.state.domains["DOMAIN-001"].alert = 90
	var no_plan: bool = world.choose_plan("DOMAIN-001").is_empty()
	var actor: String = _person(world)
	var target: String = _person(world, "interpretation")
	var private: String = _fact(world, "exposure", target, [target], {"public": false}, [target])
	var hidden: bool = world.choose_plan("DOMAIN-001").is_empty() and world.choose_behavior(actor).is_empty()
	world._institution_know("DOMAIN-001/order", private)
	world._know(actor, private)
	_check("SIM-006", "高察觉不全知；真实机构知识改变合法行动", no_plan and hidden and world.choose_plan("DOMAIN-001").get("rule") == "RESIST_TRACE" and world.choose_behavior(actor).get("behavior") == "NPC_EXAMINE")
	var data: Dictionary = _behavior_world("NPC_INTERPRET", "adaptation", 4)
	world = data.world
	world.state.facts[data.source].changes.public = true
	world.state.domains["DOMAIN-001"].alert = catalog.integer("alert_investigation")
	world.advance()
	var not_same_turn: bool = world.state.domains["DOMAIN-001"].pending_plan.is_empty()
	world.advance()
	var starts_next: bool = not world.state.domains["DOMAIN-001"].pending_plan.is_empty()
	_check("SIM-007", "神迹改变人物投入并形成下一轮机构证据", not_same_turn and starts_next and int(world.state.npcs[data.actor].loyalty) > 40, {"plan": world.state.domains["DOMAIN-001"].pending_plan})
	var original: RefCounted = _clone(world)
	for field: String in ["domains", "npcs", "institutions", "facts"]:
		var reversed: Dictionary = {}
		var ids: Array = world.state[field].keys()
		ids.reverse()
		for id: String in ids:
			reversed[id] = world.state[field][id]
		world.state[field] = reversed
	for turn: int in 12:
		world.advance()
		original.advance()
	_check("SIM-008", "改变对象遍历顺序不改变结果", world.snapshot() == original.snapshot())

func _add_anchor(world: RefCounted, guardian: String) -> void:
	var domain: String = world.state.npcs[guardian].domain
	world.state.domains[domain].unnamed_nonfollowers -= catalog.integer("anchor_followers_min")
	world.state.domains[domain].unnamed_followers += catalog.integer("anchor_followers_min")
	world.state.domains[domain].pollution = catalog.integer("anchor_create_pollution_1")
	world.state.cults["CULT-TEST"] = {"id": "CULT-TEST", "domain": domain, "leader": guardian, "cohesion": catalog.integer("cult_initial_cohesion"), "status": "active"}
	world.state.relics["RELIC-BOUND"] = {"id": "RELIC-BOUND", "domain": domain, "holder": "", "placement": "bound", "anchor": "ANCHOR-TEST"}
	world.state.relics["RELIC-CARRIED"] = {"id": "RELIC-CARRIED", "domain": domain, "holder": guardian, "placement": "carried", "anchor": ""}
	world.state.anchors["ANCHOR-TEST"] = {"id": "ANCHOR-TEST", "domain": domain, "institution": domain + "/order", "guardian": guardian, "relic": "RELIC-BOUND", "state": "active", "needs_rebind": false, "ordinal": 1}
	world._refresh_anchors()

func _test_lifecycle() -> void:
	var world: RefCounted = _controlled()
	var actor: String = _person(world)
	_add_anchor(world, actor)
	var before_awakening: int = int(world.state.awakening)
	var budget: int = int(world.state.whispers)
	var died: bool = world.submit({"kind": "status", "npc": actor, "status": "dead", "parents": [_origin(world)]})
	var invalidated: bool = world.state.anchors["ANCHOR-TEST"].state == "dormant" and world.state.anchors["ANCHOR-TEST"].guardian.is_empty() and world.state.relics["RELIC-CARRIED"].placement == "controlled" and int(world.state.awakening) < before_awakening and int(world.state.whispers) == budget
	var death_valid: bool = world.validate_state(world.state).is_empty()
	world.advance()
	_check("SIM-009", "死亡立即解除护持/物件归属且下一轮教团继任", died and invalidated and death_valid and not world.state.cults["CULT-TEST"].leader.is_empty() and world.state.cults["CULT-TEST"].leader != actor, {"awakening_before": before_awakening, "awakening_after": world.state.awakening})
	world = _controlled()
	actor = _person(world)
	_add_anchor(world, actor)
	var old_population: int = int(world.state.domains["DOMAIN-001"].population) + int(world.state.domains["DOMAIN-002"].population)
	var count: int = world.state.npcs.size()
	var migrated: bool = world.submit({"kind": "migrate", "npc": actor, "domain": "DOMAIN-002", "parents": [_origin(world)]})
	_check("SIM-010", "迁移使用同一身份、人口守恒且不携走绑定圣物", migrated and world.state.npcs.size() == count and int(world.state.domains["DOMAIN-001"].population) + int(world.state.domains["DOMAIN-002"].population) == old_population and world.state.relics["RELIC-CARRIED"].domain == "DOMAIN-002" and world.state.relics["RELIC-BOUND"].domain == "DOMAIN-001" and world.validate_state(world.state).is_empty())
	world = _controlled()
	actor = _person(world)
	_add_anchor(world, actor)
	var detained: bool = world.submit({"kind": "status", "npc": actor, "status": "detained", "parents": [_origin(world)]})
	var temporary: bool = world.state.institutions["DOMAIN-001/order"].representative == actor and world.state.anchors["ANCHOR-TEST"].guardian == actor and world.state.anchors["ANCHOR-TEST"].state == "dormant" and world.choose_behavior(actor).is_empty()
	var released: bool = world.submit({"kind": "status", "npc": actor, "status": "active", "parents": [world.state.npcs[actor].status_source]})
	var missing: bool = world.submit({"kind": "status", "npc": actor, "status": "missing", "parents": [world.state.npcs[actor].status_source]})
	_check("SIM-011", "拘禁/失踪保留名义绑定、恢复不免费激活锚点", detained and temporary and released and missing and world.state.anchors["ANCHOR-TEST"].state == "dormant" and world.choose_behavior(actor).is_empty() and world.validate_state(world.state).is_empty())
	world = _controlled()
	var total: int = int(world.state.domains["DOMAIN-001"].population)
	var initial_named: int = world.state.npcs.size()
	var nomination: bool = world.submit({"kind": "nominate", "domain": "DOMAIN-001", "profile": "NPC_PROFILE_01", "institution": "DOMAIN-001/interpretation", "group": "unnamed_nonfollowers", "parents": [_origin(world)]})
	_check("SIM-012", "提名扣除无名来源而不创造人口", nomination and world.state.npcs.size() == initial_named + 1 and int(world.state.domains["DOMAIN-001"].population) == total and world.validate_state(world.state).is_empty())
	actor = _person(world)
	world.submit({"kind": "status", "npc": actor, "status": "dead", "parents": [_origin(world)]})
	var candidates: Array = world.institution_successors("DOMAIN-001/order")
	var no_free: bool = not candidates.is_empty() and not world.succeed_institution("DOMAIN-001/order", candidates[0], _origin(world))
	var event: String = world.introduce_fact("institution_succession_authorized", "DOMAIN-001", "", ["DOMAIN-001/order", candidates[0]], [_origin(world)], {}, [], [])
	_check("SIM-024", "机构继任需要明确事件授权而非自动任命", no_free and world.succeed_institution("DOMAIN-001/order", candidates[0], event))

func _test_causality_and_growth() -> void:
	var data: Dictionary = _behavior_world("NPC_INTERPRET", "adaptation", 1)
	var world: RefCounted = data.world
	var actor: String = data.actor
	for iteration: int in 3:
		if iteration > 0:
			_fact(world, "miracle", actor, [actor], {"witnesses": [actor], "public": false}, [actor])
		world.advance()
		world.advance()
	var grows_once: bool = int(world.state.npcs[actor].adaptation) == 2 and world.state.npcs[actor].growth_sources.adaptation.size() == 3
	_check("SIM-013", "三个独特真实来源才形成一次对应属性成长", grows_once)
	var before: int = int(world.state.npcs[actor].adaptation)
	for turn: int in 8:
		world.advance()
	_check("SIM-014", "重复消费同一神迹不再次成长或加忠诚", int(world.state.npcs[actor].adaptation) == before and world.state.npcs[actor].growth_sources.adaptation.size() == 3)
	data = _behavior_world("NPC_COMFORT", "influence", 3)
	world = data.world
	var original: Dictionary = world.choose_behavior(data.actor)
	var unrelated: String = _fact(world, "message", data.actor, [data.actor], {}, [data.actor])
	var after: Dictionary = world.choose_behavior(data.actor)
	world.advance()
	var exact_causes: bool = original.parents.size() == 2 and original.parents == after.parents and not unrelated in after.parents
	var result_found: bool = false
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "npc_behavior" and fact.actor == data.actor:
			result_found = fact.causal_parents == original.parents
	_check("SIM-015", "关系与伤害双因果；无关最近事实不串入因果", exact_causes and result_found and world.validate_state(world.state).is_empty(), {"parents": original.parents, "unrelated": unrelated})
	world = _new()
	for turn: int in 20:
		world.advance()
	_check("SIM-016", "无合法事件时可连续静默推进", int(world.state.turn) == 20 and int(world.stats.plans_started) == 0)
	# Death during a warning cancels the original target instead of retargeting.
	world = _controlled()
	actor = _person(world)
	var target: String = _person(world, "interpretation")
	world.state.domains["DOMAIN-001"].alert = 40
	_fact(world, "exposure", target, [target], {"public": false}, [], ["DOMAIN-001/order"])
	world.advance()
	var pending: bool = not world.state.domains["DOMAIN-001"].pending_plan.is_empty()
	world.submit({"kind": "status", "npc": target, "status": "dead", "parents": [_origin(world)]})
	world.advance()
	world.advance()
	_check("SIM-025", "预告目标死亡后取消、不换随机活人", pending and int(world.stats.plans_cancelled) == 1 and int(world.stats.plans_resolved) == 0)

func _test_replay_and_save() -> void:
	var first: RefCounted = _controlled()
	var second: RefCounted = _controlled()
	var presentation: RandomNumberGenerator = RandomNumberGenerator.new()
	for turn: int in 40:
		if turn % 5 == 0:
			var actor: String = _person(first)
			_fact(first, "miracle", actor, [actor], {"witnesses": [actor], "public": true}, [actor])
			_fact(second, "miracle", actor, [actor], {"witnesses": [actor], "public": true}, [actor])
		first.advance()
		for draw: int in 17:
			presentation.randi()
		second.choose_behavior(_person(second))
		second.check_probability(_person(second), "will", "DOMAIN-001")
		second.snapshot()
		second.advance()
	_check("SIM-017", "同种子命令重放不受表现随机影响", first.snapshot() == second.snapshot())
	var deceased: String = _person(first, "propagation", "DOMAIN-003")
	first.submit({"kind": "status", "npc": deceased, "status": "dead", "parents": [_origin(first, "DOMAIN-003")]})
	var warning_target: String = _person(first, "interpretation", "DOMAIN-002")
	first.state.domains["DOMAIN-002"].alert = 40
	_fact(first, "exposure", warning_target, [warning_target], {}, [], ["DOMAIN-002/order"])
	first.advance()
	var save_has_cases: bool = first.state.npcs[deceased].status == "dead" and not first.state.evidence.is_empty() and not first.state.domains["DOMAIN-002"].pending_plan.is_empty()
	var encoded: String = first.snapshot()
	var restored: RefCounted = World.new(catalog)
	var loaded: bool = restored.restore(encoded)
	var same: bool = loaded and restored.snapshot() == encoded
	var file: FileAccess = FileAccess.open("user://formal-save-test.json", FileAccess.WRITE)
	file.store_string(encoded)
	file.close()
	var from_disk: RefCounted = World.new(catalog)
	same = same and from_disk.restore(FileAccess.get_file_as_string("user://formal-save-test.json"))
	for turn: int in 100:
		if turn % 7 == 0:
			var actor: String = _person(first)
			for world: RefCounted in [first, restored, from_disk]:
				_fact(world, "miracle", actor, [actor], {"witnesses": [actor], "public": true}, [actor])
		first.advance()
		restored.advance()
		from_disk.advance()
	_check("SIM-018", "正式状态磁盘读回与继续100轮一致", save_has_cases and same and first.snapshot() == restored.snapshot() and first.snapshot() == from_disk.snapshot())
	var bad_cases: Array = []
	var envelope: Dictionary = World._normalize_numbers(JSON.parse_string(encoded))
	for mutation: String in ["missing_person", "wrong_attribute", "reused_fact_id", "unknown_parent", "unknown_knowledge", "bad_population", "missing_rng", "numeric_rng", "wrong_content", "wrong_schema", "wrong_engine", "unknown_plan", "bad_relation"]:
		var bad: Dictionary = envelope.duplicate(true)
		var person: String = _person(second)
		match mutation:
			"missing_person": bad.body.state.npcs.erase(person)
			"wrong_attribute": bad.body.state.npcs[person].will = 6
			"reused_fact_id": bad.body.state.next_fact = 1
			"unknown_parent": bad.body.state.facts[_origin(second)].causal_parents = ["missing"]
			"unknown_knowledge": bad.body.state.npcs[person].known_facts.append("missing")
			"bad_population": bad.body.state.domains["DOMAIN-001"].population += 1
			"missing_rng": bad.body.randoms.erase("checks")
			"numeric_rng": bad.body.randoms.events.state = 3
			"wrong_content": bad.body.content = "different"
			"wrong_schema": bad.body.schema = 999
			"wrong_engine": bad.body.engine = "different"
			"unknown_plan": bad.body.state.domains["DOMAIN-001"].pending_plan = {"rule": "missing"}
			"bad_relation": bad.body.state.npcs[person].relations.append({"target": "missing", "source": _origin(second)})
		bad.checksum = World.canonical(bad.body).sha256_text()
		bad_cases.append({"name": mutation, "save": World.canonical(bad)})
	bad_cases.append({"name": "truncated", "save": encoded.substr(0, encoded.length() / 2)})
	bad_cases.append({"name": "checksum", "save": encoded.replace('"checksum":"', '"checksum":"x')})
	var rejected: bool = true
	var stable: String = restored.snapshot()
	for bad: Dictionary in bad_cases:
		rejected = not restored.restore(bad.save) and restored.snapshot() == stable and rejected
	_check("SIM-019", "15类坏存档拒绝且不污染会话", rejected, {"cases": bad_cases.map(func(b: Dictionary) -> String: return b.name)})
	var invalid: Array = [{"kind": "status", "npc": "missing", "status": "dead", "parents": []}, {"kind": "status", "npc": _person(restored), "status": "dead", "parents": ["missing"]}, {"kind": "migrate", "npc": _person(restored), "domain": "DOMAIN-012", "parents": [_origin(restored)]}, {"kind": "pay", "amount": -3, "parents": []}]
	var atomic: bool = true
	for command: Dictionary in invalid:
		atomic = not restored.submit(command) and restored.snapshot() == stable and atomic
	_check("SIM-020", "非法边界命令不改状态且不消耗随机流", atomic)

func _test_long_runs() -> void:
	var natural: Array = []
	var natural_valid: bool = true
	for seed_value: int in [31, 97, 271, 809, 2423, 7283, 21851, 65543]:
		var world: RefCounted = _new(seed_value)
		var started: int = Time.get_ticks_usec()
		for turn: int in 120:
			world.advance()
			natural_valid = natural_valid and world.validate_state(world.state).is_empty()
		natural_valid = natural_valid and world.validate_state(world.state).is_empty()
		natural.append({"seed": seed_value, "turns": world.state.turn, "living": world._living_count(), "actions": world.stats.actions, "plans": world.stats.plans_started, "milliseconds": float(Time.get_ticks_usec() - started) / 1000.0})
	_check("SIM-022", "8个正式规模种子自然演化120轮", natural_valid, {"runs": natural, "driver": "无玩家/外部事实注入；初始无邪神暴露，允许稳定静默，不据此证明有戏剧性"})
	metrics.natural = natural
	var load_valid: bool = true
	var durations: Array = []
	var load_runs: Array = []
	for seed_value: int in [1009, 2027, 4057]:
		var world: RefCounted = _new(seed_value)
		for domain_id: String in world.state.domains:
			var carrier: String = _person(world, "propagation", domain_id)
			_fact(world, "public_anomaly", carrier, [carrier], {}, [carrier])
			world.state.domains[domain_id].alert = catalog.integer("alert_investigation")
		var lowest_living: int = world._living_count()
		var window_actions: Array = []
		var window_updates: Array = []
		var prior_actions: int = 0
		var prior_updates: int = 0
		for turn: int in 300:
			# Feed actual witnessed miracle facts through the integration boundary.
			# The driver does not heal, replace, revive or keep dead NPCs in the loop.
			if turn % 6 == 0:
				for domain_id: String in world.state.domains:
					var actor: String = _person(world, "propagation", domain_id)
					if world.state.npcs.has(actor) and world.state.npcs[actor].status == "active":
						_fact(world, "miracle", actor, [actor], {"witnesses": [actor], "public": true}, [actor])
						var observer: String = _person(world, "order", domain_id)
						_fact(world, "exposure", actor, [actor], {"public": true}, [observer], [domain_id + "/order"])
			var started: int = Time.get_ticks_usec()
			world.advance()
			durations.append(float(Time.get_ticks_usec() - started) / 1000.0)
			if (turn + 1) % 50 == 0:
				window_actions.append(int(world.stats.actions) - prior_actions)
				window_updates.append(int(world.stats.npc_updates) - prior_updates)
				prior_actions = int(world.stats.actions)
				prior_updates = int(world.stats.npc_updates)
			if turn % 25 == 0:
				load_valid = load_valid and world.validate_state(world.state).is_empty()
				lowest_living = mini(lowest_living, world._living_count())
		var save_started: int = Time.get_ticks_usec()
		var save: String = world.snapshot()
		var save_millis: float = float(Time.get_ticks_usec() - save_started) / 1000.0
		var again: RefCounted = World.new(catalog)
		load_valid = load_valid and again.restore(save) and again.snapshot() == save and world.validate_state(world.state).is_empty() and int(world.stats.npc_updates) == 300 * 72 and lowest_living == 72 and int(world.stats.actions) > 0 and int(world.stats.plans_resolved) > 0 and int(window_actions.back()) > 0 and int(window_updates.back()) == 50 * 72
		load_runs.append({"seed": seed_value, "turns": 300, "minimum_living": lowest_living, "npc_updates": world.stats.npc_updates, "npc_actions": world.stats.actions, "plans_started": world.stats.plans_started, "plans_resolved": world.stats.plans_resolved, "history_facts": world.state.facts.size(), "actions_per_50_turns": window_actions, "updates_per_50_turns": window_updates, "save_bytes": save.to_utf8_buffer().size(), "serialization_ms": save_millis})
	durations.sort()
	metrics.active = {"runs": load_runs, "turn_p50_ms": durations[int(floor(durations.size() * 0.5))], "turn_p95_ms": durations[int(floor(durations.size() * 0.95))], "turn_max_ms": durations.back(), "driver": "以持续公开异常与关注档位为起点，每6轮向每域传播代表注入合法公开神迹见证及新的真实暴露事实；不实现祈求成本/收益，不作为玩家策略或平衡实验"}
	_check("SIM-023", "3个正式规模种子持续活动300轮且保存可恢复", load_valid, metrics.active)

func _finish() -> void:
	var passed: int = 0
	for check: Dictionary in checks:
		if check.status == "pass":
			passed += 1
	checks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var report: Dictionary = {
		"schemaVersion": 1, "suite": "formal-simulation", "generatedAt": Time.get_datetime_string_from_system(true) + "Z",
		"status": "pass" if passed == checks.size() else "fail", "checks": checks,
		"sourceHashes": {}, "metrics": metrics,
		"environment": {"engine": Engine.get_version_info(), "platform": OS.get_name(), "processors": OS.get_processor_count(), "processor": OS.get_processor_name(), "headless": true},
		"scope": ["正式四属性检定及四类自主行为", "正式12域/72初始具名人物及聚合人口", "已知证据约束的6类抵抗计划", "持久身份、生命周期、真实父事实、同快照选择", "限定同环境的保存/重放与多种子负载"],
		"limitations": ["不包含完整玩家回合、祈求与12权能、教团经济、锚点创建维护和终局；无正式游戏UI", "事实注入边界表示其他正式系统已执行的结果，不能当作免费玩家命令", "生成使用合法蓝本选择与岗位；尚未实现全部范式权重变异、灾难背景、听众关系候选", "行为与抵抗的数字是待评审提案；测试不证明平衡、无通解、叙事品质或涌现深度", "性能仅本机无渲染、有限正式规模，不承诺跨平台/跨引擎逐位重放或无限历史", "存档包含完整事实骨架，尚未实现增量保存、断电恢复、迁移和历史裁剪"]}
	var file: FileAccess = FileAccess.open("res://docs/qa/formal-simulation-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	print("FORMAL RESULT ", passed, "/", checks.size())
	quit(0 if passed == checks.size() else 1)

func _test_integration_boundaries() -> void:
	var effects_valid: bool = true
	var effect_details: Dictionary = {}
	for rule_id: String in catalog.tables.civilization_actions:
		var world: RefCounted = _controlled()
		var domain_id: String = "DOMAIN-012" if rule_id in ["RESIST_REWRITE", "RESIST_ERASE"] else "DOMAIN-001"
		var actor: String = _person(world, "order", domain_id)
		var target: String = _person(world, "interpretation", domain_id)
		var domain: Dictionary = world.state.domains[domain_id]
		domain.alert = 100
		var source: String = ""
		var institution: String = domain_id + "/order"
		if rule_id == "RESIST_REPAIR":
			domain.barrier = catalog.integer("first_breach_threshold")
		elif rule_id == "RESIST_REWRITE":
			institution = domain_id + "/interpretation"
			source = _fact(world, "exception", target, [target], {}, [target], [institution])
			var authorization: String = world.introduce_fact("exception_confirmation_authorized", domain_id, "", [institution, source], [source], {}, [], [institution])
			effects_valid = world.confirm_exception(institution, source, authorization) and effects_valid
			var before: String = world.snapshot()
			effects_valid = world.confirm_exception(institution, source, authorization) and world.snapshot() == before and effects_valid
		else:
			if rule_id == "RESIST_PURGE":
				domain.unnamed_nonfollowers -= catalog.integer("anchor_followers_min")
				domain.unnamed_followers += catalog.integer("anchor_followers_min")
				world.state.cults["CULT-TEST"] = {"id": "CULT-TEST", "domain": domain_id, "leader": target, "cohesion": catalog.integer("cult_initial_cohesion"), "status": "active"}
			if rule_id in ["RESIST_SEIZE", "RESIST_ERASE"]:
				_add_anchor(world, target)
				if rule_id == "RESIST_SEIZE":
					target = "RELIC-BOUND"
			source = _fact(world, "exposure", actor, [target], {}, [actor], [institution])
			if rule_id != "RESIST_TRACE":
				# Execute a real authored examine action to produce confirmed evidence.
				world.begin_turn()
				world.evolve()
				domain.pending_plan = {} # Isolate the next candidate after an already settled warning.
				domain.alert = 100
		var plan: Dictionary = world.choose_plan(domain_id)
		var selected: bool = plan.get("rule") == rule_id
		var result: bool = false
		if selected:
			plan.started_fact = world._record("resistance_started", domain_id, "", [plan.target], plan.parents, {"rule": rule_id, "due": plan.due})
			domain.pending_plan = plan
			var before_population: int = int(domain.population)
			var before_followers: int = int(domain.unnamed_followers)
			var before_barrier: int = int(domain.barrier)
			var before_wounds: int = int(world.state.wounds)
			world.state.turn = plan.due
			world._resolve_plans()
			match rule_id:
				"RESIST_TRACE": result = not world.state.evidence[institution + "|" + target].confirmations.is_empty()
				"RESIST_PURGE": result = before_population - int(domain.population) == int(ceil(float(before_followers) * float(catalog.tables.civilization_actions[rule_id].followers_loss_ratio)))
				"RESIST_SEIZE": result = world.state.relics[target].placement == "seized" and world.state.anchors["ANCHOR-TEST"].state == "dormant"
				"RESIST_REPAIR": result = int(domain.barrier) - before_barrier == int(catalog.tables.civilization_actions[rule_id].barrier_delta)
				"RESIST_ERASE": result = world.state.anchors["ANCHOR-TEST"].state == "destroyed"
				"RESIST_REWRITE": result = int(world.state.wounds) - before_wounds == int(catalog.tables.civilization_actions[rule_id].wounds_delta)
			effects_valid = effects_valid and world.validate_state(world.state).is_empty()
		effect_details[rule_id] = {"selected": selected, "effect_matches_csv": result}
		effects_valid = effects_valid and selected and result
	_check("SIM-026", "六种正式抵抗资格与结构化效果", effects_valid, effect_details)
	var world: RefCounted = _controlled()
	var actor: String = _person(world)
	var second: String = ""
	for npc: Dictionary in world.state.npcs.values():
		if npc.institution == "DOMAIN-001/order" and npc.id != actor:
			second = npc.id
	var target: String = _person(world, "interpretation")
	world.state.npcs[actor].insight = 2
	world.state.npcs[second].insight = 2
	var exposure: String = _fact(world, "exposure", target, [target], {}, [actor, second])
	var member_can_report: bool = not exposure in world.state.institutions["DOMAIN-001/order"].known_facts and world.choose_behavior(actor).get("behavior") == "NPC_EXAMINE"
	world.advance()
	var evidence: Dictionary = world.state.evidence["DOMAIN-001/order|" + target]
	var confirmation: Dictionary = world.state.facts[evidence.confirmations[0]]
	var independent: bool = confirmation.causal_parents.size() == 2
	var actors: Array = []
	for parent: String in confirmation.causal_parents:
		actors.append(world.state.facts[parent].actor)
		independent = independent and world.state.facts[parent].kind == "npc_behavior" and world.state.facts[parent].causal_parents == [exposure]
	independent = independent and actor in actors and second in actors
	_check("SIM-027", "个人见闻提交机构且独立证言保留真实查证者", member_can_report and independent)
	var data: Dictionary = _behavior_world("NPC_INTERPRET", "adaptation", 3)
	world = data.world
	world.begin_turn()
	var marked: bool = world.mark_player_task(data.actor)
	var unavailable: bool = world.choose_behavior(data.actor).is_empty()
	var before_loyalty: int = int(world.state.npcs[data.actor].loyalty)
	world.evolve()
	var no_second_action: bool = int(world.state.npcs[data.actor].loyalty) == before_loyalty
	var before: String = world.snapshot()
	world.evolve()
	_check("SIM-028", "玩家任务占用本轮人物机会且演化不可重复提交", marked and unavailable and no_second_action and world.snapshot() == before)
	world = _controlled()
	actor = _person(world)
	world.state.domains["DOMAIN-001"].alert = 20
	var initial_barrier: int = int(world.state.domains["DOMAIN-001"].barrier)
	var anomaly: String = _fact(world, "public_anomaly", actor, [actor], {}, [actor])
	world.advance()
	var held: bool = int(world.state.domains["DOMAIN-001"].alert) == 20 and int(world.state.domains["DOMAIN-001"].barrier) == initial_barrier
	var resolved: String = world.introduce_fact("anomaly_resolved", "DOMAIN-001", actor, [actor], [anomaly, _origin(world)], {"source": anomaly}, [actor])
	world.advance()
	var recovers: bool = int(world.state.domains["DOMAIN-001"].alert) < 20 and int(world.state.domains["DOMAIN-001"].barrier) > initial_barrier
	_check("SIM-029", "持续公开异常有载体和解除；历史不永久锁住衰减", held and not resolved.is_empty() and recovers and world.state.facts.has(anomaly))

func _test_bad_catalog() -> void:
	var directory: String = "user://formal-catalog-invalid"
	DirAccess.make_dir_recursive_absolute(directory)
	var originals: Dictionary = {}
	for name: String in Catalog.FILES:
		originals[name] = FileAccess.get_file_as_string("res://data/" + name + ".csv")
		var file: FileAccess = FileAccess.open(directory.path_join(name + ".csv"), FileAccess.WRITE)
		file.store_string(originals[name])
		file.close()
	var invalid: Array = [
		{"name": "zero_divisor", "table": "npc_behaviors", "from": "restore_self_sanity,2,2,0", "to": "restore_self_sanity,2,0,0"},
		{"name": "negative_cost", "table": "npc_behaviors", "from": "gather_evidence,1,2,1", "to": "gather_evidence,1,2,-1"},
		{"name": "unknown_attribute", "table": "npc_behaviors", "from": ",will,", "to": ",strength,"},
		{"name": "unknown_effect", "table": "npc_behaviors", "from": "gather_evidence", "to": "execute_code"},
		{"name": "unknown_eligibility", "table": "npc_behaviors", "from": "strained_self", "to": "always"},
		{"name": "unknown_repeat_policy", "table": "npc_behaviors", "from": "once_per_actor_source_target", "to": "infinite"},
		{"name": "resistance_id_mismatch", "table": "civilization_actions", "from": "RESIST_TRACE,", "to": "RESIST_UNKNOWN,"},
		{"name": "missing_parameter", "table": "simulation_parameters", "from": "evidence_confirmation_strength,", "to": "removed_required_parameter,"},
		{"name": "incompatible_authority", "table": "civilization_conditions", "from": "CIV_01,council|hierarchy", "to": "CIV_01,unified"},
		{"name": "unknown_target_kind", "table": "civilization_actions", "from": "order,exposed,npc|relic,confirm_evidence", "to": "order,exposed,unknown,confirm_evidence"},
		{"name": "incompatible_effect_institution", "table": "civilization_actions", "from": "order,exposed,npc|relic,confirm_evidence", "to": "interpretation,exposed,npc|relic,confirm_evidence"},
		{"name": "incompatible_effect_evidence", "table": "civilization_actions", "from": "order,exposed,npc|relic,confirm_evidence", "to": "order,breach,npc|relic,confirm_evidence"},
		{"name": "incompatible_effect_target", "table": "civilization_actions", "from": "order,confirmed_npc,cult,purge_cult", "to": "order,confirmed_npc,relic,purge_cult"},
		{"name": "incompatible_effect_handler", "table": "civilization_actions", "from": "order,confirmed_npc,cult,purge_cult", "to": "order,confirmed_npc,cult,repair_barrier"},
	]
	var valid: bool = true
	var content: RefCounted = Catalog.new()
	valid = content.load_files() and valid
	var previous: String = World.canonical(content.tables)
	var version: String = content.version
	for mutation: Dictionary in invalid:
		var changed: String = str(originals[mutation.table]).replace(mutation.from, mutation.to)
		valid = changed != originals[mutation.table] and valid
		var file: FileAccess = FileAccess.open(directory.path_join(str(mutation.table) + ".csv"), FileAccess.WRITE)
		file.store_string(changed)
		file.close()
		valid = not content.load_files(directory) and World.canonical(content.tables) == previous and content.version == version and valid
		file = FileAccess.open(directory.path_join(str(mutation.table) + ".csv"), FileAccess.WRITE)
		file.store_string(originals[mutation.table])
		file.close()
	_check("SIM-030", "%d种坏正式CSV整批拒绝且旧目录不变" % invalid.size(), valid, {"cases": invalid.map(func(m: Dictionary) -> String: return m.name)})

func _test_regression_boundaries() -> void:
	var cases: Dictionary = {}
	var world: RefCounted = _controlled()
	var actor: String = _person(world)
	world.state.npcs[actor].will = 2
	world.state.npcs[actor].sanity = 50
	var p: int = world.check_probability(actor, "will", "DOMAIN-001")
	world.state.npcs[actor].influence = 5
	cases.non_primary_attribute = world.check_probability(actor, "will", "DOMAIN-001") == p
	cases.critical_boundaries = world.check_result(60, 12) == "deep" and world.check_result(60, 13) == "success" and world.check_result(60, 60) == "success" and world.check_result(60, 61) == "failure" and world.check_result(60, 92) == "failure" and world.check_result(60, 93) == "disaster"
	world.submit({"kind": "status", "npc": actor, "status": "dead", "parents": [_origin(world)]})
	var before: String = world.snapshot()
	cases.repeated_death = not world.submit({"kind": "status", "npc": actor, "status": "dead", "parents": [_origin(world)]}) and world.snapshot() == before
	world = _controlled()
	actor = _person(world)
	var destination: Dictionary = world.state.domains["DOMAIN-002"]
	destination.unnamed_nonfollowers += catalog.integer("domain_population_capacity") - int(destination.population)
	destination.population = catalog.integer("domain_population_capacity")
	before = world.snapshot()
	cases.full_destination = not world.submit({"kind": "migrate", "npc": actor, "domain": "DOMAIN-002", "parents": [_origin(world)]}) and world.snapshot() == before
	var nomination: Dictionary = {"kind": "nominate", "domain": "DOMAIN-001", "profile": "NPC_PROFILE_01", "institution": "DOMAIN-001/interpretation", "group": "unnamed_nonfollowers", "parents": [_origin(world)]}
	while world._living_count() < catalog.integer("living_named_global_limit"):
		assert(world.submit(nomination))
	before = world.snapshot()
	cases.named_limit = not world.submit(nomination) and world.snapshot() == before
	world = _controlled()
	nomination.parents = [_origin(world)]
	world.state.domains["DOMAIN-001"].unnamed_followers += int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers)
	world.state.domains["DOMAIN-001"].unnamed_nonfollowers = 0
	before = world.snapshot()
	cases.empty_source_pool = not world.submit(nomination) and world.snapshot() == before
	actor = _person(world)
	before = world.snapshot()
	cases.missing_causal_parent = world.introduce_fact("miracle", "DOMAIN-001", actor, [actor], ["missing"], {"witnesses": [actor]}, [actor]).is_empty() and world.snapshot() == before
	var data: Dictionary = _behavior_world("NPC_INTERPRET", "adaptation", catalog.integer("npc_attribute_max"))
	world = data.world
	actor = data.actor
	for round_index: int in 3:
		if round_index > 0:
			_fact(world, "miracle", actor, [actor], {"witnesses": [actor], "public": false}, [actor])
		world.advance()
		world.advance()
	cases.growth_cap = int(world.state.npcs[actor].adaptation) == catalog.integer("npc_attribute_max")
	var loyalty: int = int(world.state.npcs[actor].loyalty)
	world._know(actor, data.source)
	for turn: int in 8:
		world.advance()
	cases.repeated_learning_source = int(world.state.npcs[actor].loyalty) == loyalty and world.state.npcs[actor].growth_sources.adaptation.size() == 3
	data = _behavior_world("NPC_EXAMINE", "insight", 3)
	world = data.world
	var alternate: RefCounted = _clone(world)
	alternate.state.institutions["DOMAIN-001/order"].active = false
	world.advance()
	alternate.advance()
	cases.institution_changes_person_behavior = not world.state.evidence.is_empty() and alternate.state.evidence.is_empty() and int(world.state.npcs[data.actor].sanity) < int(alternate.state.npcs[data.actor].sanity)
	world = _controlled()
	actor = _person(world)
	var successor: String = world.institution_successors("DOMAIN-001/order")[0]
	var authorization: String = world.introduce_fact("institution_succession_authorized", "DOMAIN-001", "", ["DOMAIN-001/order", successor], [_origin(world)], {}, [])
	world.succeed_institution("DOMAIN-001/order", successor, authorization)
	before = world.snapshot()
	cases.succession_idempotent = world.succeed_institution("DOMAIN-001/order", successor, authorization) and world.snapshot() == before
	var all_valid: bool = true
	for result: bool in cases.values():
		all_valid = all_valid and result
	_check("SIM-031", "属性、人口、死亡、成长与授权关键边界", all_valid, cases)
	data = _behavior_world("NPC_COMFORT", "influence", 5)
	world = data.world
	world.state.npcs[data.target].sanity = 59
	var previous: int = int(world.state.npcs[data.target].sanity)
	world.advance()
	var actual: int = int(world.state.npcs[data.target].sanity) - previous
	var truthful: bool = false
	for fact: Dictionary in world.state.facts.values():
		if fact.kind == "npc_batch_applied" and fact.changes.actual_deltas.has(data.target):
			truthful = int(fact.changes.actual_deltas[data.target].sanity) == actual
	_check("SIM-032", "限幅后事实记录实际增量而非请求量", actual == 1 and truthful)
