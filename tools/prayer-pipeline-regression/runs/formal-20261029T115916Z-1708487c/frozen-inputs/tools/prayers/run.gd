extends "res://tools/powers/power_cases.gd"
const Prayers = preload("res://src/game/prayers.gd")
var prayer_rows: Array = []
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	for prayer: String in catalog.tables.prayers:
		for variant: String in ["shallow", "deep"]:
			for outcome: String in ["deep", "success", "failure", "disaster"]: _prayer_branch(prayer, variant, outcome)
	_prayer_specials()
	if has_method("run_reopen_cases"): call("run_reopen_cases")
	if has_method("run_integration_cases"): call("run_integration_cases")
	var ok: bool = true
	for row: Dictionary in records: ok = ok and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records, "branches": prayer_rows}, "\t", true, true)); file.close()
	quit(0 if ok else 1)
func _attach_prayers(data: Dictionary) -> Dictionary:
	_attach_powers(data)
	var prayers: RefCounted = Prayers.new(catalog, ISSUERS)
	assert(prayers.install(data.turn)); data.prayers = prayers
	return data
func _given_fact(data: Dictionary, kind: String, actor: String, targets: Array, details: Dictionary, parents: Array = []) -> String:
	var domain: String = Store.entry(data.world.state.npcs, actor).domain
	var source: String = data.world._record(kind, domain, actor, targets, [data.world.state.domains[domain].origin] if parents.is_empty() else parents, details)
	data.world._know(actor, source)
	return source
func _given_relation(data: Dictionary, first: String, second: String, type: String) -> String:
	var source: String = _given_fact(data, "relationship", first, [first, second], {"type": type})
	assert(data.world.add_relation(first, second, type, source))
	assert(data.world.add_relation(second, first, type, source))
	return source
func _response(data: Dictionary, request: String, variant: String, options: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {"request": request, "variant": variant}; payload.merge(options)
	return _submit(data, "act", {"participant": "prayers", "action": "respond", "payload": payload})
func _choose_prayer_seed(data: Dictionary, outcome: String, actor: String, domain: String) -> int:
	var p: int = data.world.check_probability(actor, "adaptation", domain, "occult")
	for value: int in range(1, 10001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = value
		if data.world.check_result(p, rng.randi_range(1, 100)) == outcome:
			data.world.randoms.checks.seed = value; return value
	return -1
func _prayer_branch(prayer: String, variant: String, outcome: String) -> void:
	var data: Dictionary = _prayer_case(prayer)
	var seed_value: int = _choose_prayer_seed(data, outcome, data.petitioner, data.domain)
	assert(_open(data))
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.prayers.preview(data.turn, data.request, variant)
	var pure: bool = before == data.turn.snapshot()
	var expected_probability: int = data.world.check_probability(data.petitioner, "adaptation", data.domain, "occult")
	var observed: Dictionary = _observe_prayer(data)
	var response: Dictionary = _response(data, data.request, variant)
	var checks: Array = _facts(data.world, "turn_check")
	var results: Array = _facts(data.world, "prayer_result")
	var actual: String = results[-1].changes.outcome if not results.is_empty() else "missing"
	var valid: bool = preview.ok and preview.get("probability", -1) == expected_probability and pure and response.ok and actual == outcome and checks.size() == 1 and checks[0].changes.probability == preview.get("probability", -1) and data.turn.context.responses == 1 and _prayer_numeric_match(data, variant, outcome, observed) and _prayer_fact_match(data, variant, outcome)
	prayer_rows.append({"prayer": prayer, "variant": variant, "expected": outcome, "actual": actual, "seed": seed_value, "preview_error": preview.get("error", ""), "error": response.get("error", ""), "check": checks[-1].changes if not checks.is_empty() else {}})
	_check("PRAYER/" + prayer + "/" + variant + "/" + outcome, "真实固定对象、纯预览、正式支付/四档回应 " + prayer + " " + variant + " " + outcome, valid, prayer_rows[-1])
func _prayer_specials() -> void:
	_native_start()
	_response_quota()
	_subject_invalidation()
	_crisis_continuity()
	_prayer_limits()
	_prayer_save_and_fault()
	_prayer_expiry()
	_prayer_agents_and_sources()
	_prayer_corruption()
	_background_defaults()
	_conditional_disclosure()
	_prayer_catalog_contract()
	_deep_subject_loss()
	_canonical_situations()

func _prayer_case(prayer: String, keep_source: bool = true, settings: Dictionary = {}) -> Dictionary:
	var data: Dictionary = _high()
	var world: RefCounted = data.world
	var domain: String = settings.get("domain", "DOMAIN-011" if prayer == "PRAYER_12" else "DOMAIN-001")
	var actor: String = data.guardians[domain][0]
	if prayer in ["PRAYER_05", "PRAYER_08"]:
		actor = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_02" if prayer == "PRAYER_05" else "NPC_PROFILE_01", world.state.domains[domain].origin))
	var institution: String = str(Store.entry(world.state.npcs, actor).institution)
	if institution.is_empty(): institution = domain + "/interpretation"
	world.state.domains[domain].pollution = 40
	world.state.domains[domain].alert = 10; world.state.domains[domain].barrier = 25
	world.mutable_npc(actor).loyalty = 50 if prayer == "PRAYER_02" else (0 if prayer == "PRAYER_08" else 80)
	world._refresh_anchors()
	var peers: Array = []
	for npc: Dictionary in Store.values(world.state.npcs):
		if npc.id != actor and npc.domain == domain and npc.status == "active": peers.append(npc.id)
	peers.sort()
	assert(peers.size() >= (3 if prayer == "PRAYER_07" else (0 if prayer == "PRAYER_12" else 1)))
	var subjects: Dictionary = {"petitioner": actor}
	var facts: Dictionary = {}
	var actors: Array = [actor]
	var crisis: Dictionary = {}
	data.petitioner = actor; data.domain = domain; data.institution = institution
	match prayer:
		"PRAYER_01":
			subjects.relative = peers[0]; actors.append(peers[0])
			var injury: String = _given_fact(data, "harm", peers[0], [peers[0]], {"fixture": "existing_injury"})
			facts.condition = _given_fact(data, "dying_condition", actor, [peers[0]], {"patient": peers[0], "due": 3}, [injury])
			facts.relation = _given_relation(data, actor, peers[0], "family")
			crisis = {"source": facts.condition, "due": 3}
		"PRAYER_02", "PRAYER_10":
			var rival: String = data.guardians[domain][1]
			if rival == actor: rival = peers[0]
			subjects["rival" if prayer == "PRAYER_02" else "opponent"] = rival; actors.append(rival)
			facts.relation = _given_relation(data, actor, rival, "rival")
			var stance: String = _given_fact(data, "message", actor, [actor, rival], {"institution": institution, "stance": "existing_dispute_position"})
			world._institution_know(institution, stance)
			facts.conflict = _given_fact(data, "faction_conflict", actor, [actor, rival], {"parties": [actor, rival], "institution": institution, "default_stance": stance, "due": 3}, [facts.relation, stance])
			if settings.get("opponent_knows", false): world._know(rival, facts.relation)
		"PRAYER_03":
			subjects.pursuer = peers[0]; actors.append(peers[0])
			var relation: String = _given_relation(data, actor, peers[0], "pursuit")
			var clue: String = _given_fact(data, "exposure", actor, [actor], {"public": false})
			facts.pursuit = _given_fact(data, "pursuit_condition", actor, [actor, peers[0]], {"subject": actor, "pursuer": peers[0], "institution": institution, "clue": clue, "relation": relation, "due": 3}, [relation, clue])
			crisis = {"source": facts.pursuit, "due": 3}
		"PRAYER_04":
			subjects.second = peers[0]; actors.append(peers[0])
			facts.record = _given_fact(data, "exposure", actor, [actor], {"public": false, "unexplained": true})
		"PRAYER_05": facts.ritual = _given_fact(data, "ritual_context", actor, [actor], {"subject": actor, "institution": institution, "turn": 0})
		"PRAYER_06":
			subjects.counterparty = peers[0]; actors.append(peers[0])
			facts.contract = _given_fact(data, "contract_obligation", actor, [actor, peers[0]], {"obligor": actor, "counterparty": peers[0], "institution": institution, "due": 3})
			crisis = {"source": facts.contract, "due": 3}
		"PRAYER_07":
			subjects.memory_people = peers.slice(0, 3); actors.append_array(subjects.memory_people)
			var memory: String = _given_fact(data, "message", actor, actors, {"fixture": "existing_shared_memory"})
			facts.relations = []
			for person: String in subjects.memory_people:
				world._know(person, memory)
				facts.relations.append(_given_relation(data, actor, person, "social"))
			facts.memory = _given_fact(data, "memory_at_risk", actor, actors, {"memory": memory, "holders": subjects.memory_people, "due": 3}, [memory])
			crisis = {"source": facts.memory, "due": 3}
		"PRAYER_08": facts.contact = _given_fact(data, "devotion_contact", actor, [actor], {"subject": actor, "institution": institution})
		"PRAYER_09": facts.contact = _given_fact(data, "barrier_contact", actor, [actor], {"subject": actor, "institution": institution, "barrier_source": world.state.domains[domain].barrier_source})
		"PRAYER_11":
			var relic: String = _given_relic(world, domain, "RELIC_WITNESS_LENS")
			var seizure: String = _given_fact(data, "message", actor, [relic], {"fixture": "preexisting_seizure", "institution": institution})
			var item: Dictionary = Store.entry(world.state.relics, relic)
			item.placement = "seized"; item.captor = institution; item.status_source = seizure
			world.history.refresh_relic(world.state, relic)
			subjects.relic = relic
			facts.claim = _given_fact(data, "message", actor, [actor, relic], {"relic": relic, "status_source": seizure}, [seizure])
		"PRAYER_12":
			subjects.other_institution = domain + "/order" if institution != domain + "/order" else domain + "/interpretation"
			facts.exception = _given_fact(data, "exception", actor, [actor], {"institution": institution, "public": false})
			world._institution_know(institution, facts.exception)
	var parents: Array = [world.state.domains[domain].origin]
	for value: Variant in facts.values():
		if value is String: parents.append(value)
		else: parents.append_array(value)
	var source: String = world.introduce_fact("prayer_situation", domain, actor, actors, parents, {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers[prayer].need, "domain": domain, "institution": institution, "actors": actors, "subjects": subjects, "facts": facts, "crisis": crisis}, actors)
	assert(not source.is_empty())
	world.attention.sync(world); world.history.rebuild(world.state)
	data.subjects = subjects; data.fact_map = facts; data.situation = source; data.prayer = prayer; data.original_crisis = crisis
	if settings.get("fill_members", false):
		var fill: Array = _extra(world, 12 - world.attention.occupied(world.state, "members").size())
		for person: String in fill: _bind(world, person)
	if settings.get("agent", false):
		data.agent = data.guardians[domain][1]
		data.agent_source = _given_fact(data, "message", actor, [actor, data.agent], {"fixture": "existing_delegation"}, [source])
	_attach_prayers(data)
	var candidates: Array = world.state.simulation.candidates.keys()
	if keep_source:
		var fixed: bool = world.fix_prayer_source(source, data.turn)
		if not fixed: print("FIXTURE_SOURCE_REJECTED ", prayer, " ", data.prayers.validate_situation(world, source))
		assert(fixed)
		for id: String in world.state.simulation.candidates:
			if not id in candidates: data.request = id
		assert(data.has("request"))
	return data

func _observe_prayer(data: Dictionary) -> Dictionary:
	var state: Dictionary = data.world.state
	var people: Dictionary = {}
	for person: String in data.subjects.values().filter(func(v: Variant) -> bool: return v is String and Store.has(state.npcs, v)):
		people[person] = Store.entry(state.npcs, person).duplicate(true)
	for person: String in data.subjects.get("memory_people", []): people[person] = Store.entry(state.npcs, person).duplicate(true)
	return {"people": people, "domain": state.domains[data.domain].duplicate(true), "faith": state.faith, "whispers": state.whispers}
func _prayer_numeric_match(data: Dictionary, variant: String, outcome: String, before: Dictionary) -> bool:
	var deltas: Dictionary = {}
	for row: Dictionary in catalog.tables.prayer_effects.values():
		if not row.prayer_id in ["*", data.prayer] or not row.variant in ["both", variant] or row.operation != "delta": continue
		if not row.stage == "always" and not (row.stage == "success" and outcome in ["deep", "success"]) and not (row.stage == "disaster" and outcome == "disaster"): continue
		var amount: int = catalog.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)
		if row.scale == "count" and outcome == "deep":
			var direction: int = -1 if amount < 0 else 1
			amount = direction * maxi(1, int(floor(absf(float(amount)) * catalog.number("prayer_deep_success_multiplier"))))
		var field: String = str(row.field)
		if field == "sanity_loss": field = "sanity"; amount = -amount
		if field == "followers": field = "unnamed_followers"
		var ids: Array = []
		if row.subject == "domain": ids = ["domain"]
		elif row.subject == "actor": ids = [data.petitioner]
		elif row.subject == "memory_people": ids = data.subjects.memory_people.slice(0, 1) if variant == "shallow" else data.subjects.memory_people
		else: ids = [data.subjects[row.subject]]
		for id: String in ids:
			var key: String = id + "/" + field
			deltas[key] = int(deltas.get(key, 0)) + amount
	for key: String in deltas:
		var id: String = key.get_slice("/", 0); var field: String = key.get_slice("/", 1)
		var old: Dictionary = before.domain if id == "domain" else before.people[id]
		var current: Dictionary = data.world.state.domains[data.domain] if id == "domain" else Store.entry(data.world.state.npcs, id)
		var expected: int = int(old[field]) + int(deltas[key])
		if field != "unnamed_followers": expected = clampi(expected, 0, 100)
		if int(current[field]) != expected:
			print("NUMERIC_MISMATCH ", data.prayer, " ", variant, " ", outcome, " ", key, " expected=", expected, " actual=", current[field]); return false
	if data.world.state.faith != int(before.faith) - catalog.integer("prayer_" + variant + "_faith") or data.world.state.whispers != int(before.whispers) - catalog.integer("prayer_" + variant + "_whispers"): return false
	if data.prayer == "PRAYER_08":
		var actor: Dictionary = Store.entry(data.world.state.npcs, data.petitioner)
		var succeeded: bool = outcome in ["deep", "success"]
		if actor.bound_member != succeeded or actor.loyalty != (40 if variant == "shallow" else 70) and succeeded: return false
	if data.prayer == "PRAYER_01":
		if Store.has(data.world.state.invalid_records, data.fact_map.condition) != (outcome in ["deep", "success"]): return false
	if data.prayer == "PRAYER_11":
		var relic: Dictionary = Store.entry(data.world.state.relics, data.subjects.relic)
		if relic.placement != "seized" or relic.captor != data.institution: return false
	if data.world.state.domains[data.domain].population != before.domain.population: return false
	return true

func _native(seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = World.new(catalog); assert(world.generate_hybrid(seed_value))
	var economy: RefCounted = Economy.new(catalog, ISSUERS); assert(economy.initialize(world))
	world.state.faith = 0
	return _attach_prayers({"world": world, "economy": economy, "source": world.state.domains["DOMAIN-001"].origin})
func _reject_response(data: Dictionary, request: String, variant: String, options: Dictionary = {}) -> bool:
	var before: String = data.turn.snapshot()
	return not _response(data, request, variant, options).ok and before == data.turn.snapshot()
func _native_start() -> void:
	for seed_value: int in [7919, 104729, 2027]: _native_seed(seed_value)
func _native_seed(seed_value: int) -> void:
	var data: Dictionary = _native(seed_value)
	var population: int = data.world.state.domains["DOMAIN-001"].population
	var named: int = Store.size(data.world.state.npcs)
	assert(_open(data))
	var offered: Array = data.world.state.prayer_system.offered
	var viable: String = ""
	for id: String in offered:
		if data.prayers.preview(data.turn, id, "shallow").ok: viable = id; break
	var before: String = data.turn.snapshot()
	var previews: bool = not viable.is_empty()
	for i: int in 3:
		if not viable.is_empty(): previews = previews and data.prayers.preview(data.turn, viable, "shallow").ok
	previews = previews and before == data.turn.snapshot()
	var acted: bool = not viable.is_empty() and _response(data, viable, "shallow").ok
	_check("PRY-001/" + str(seed_value), "真实原始混合开局零信仰有合法1低语浅触；重复读取不抽人、不扣人口或推进随机", previews and acted and data.world.state.faith == 0 and data.turn.context.responses == 1 and data.world.state.domains["DOMAIN-001"].population == population and Store.size(data.world.state.npcs) == named, {"offered": offered, "viable": viable})
func _response_quota() -> void:
	var data: Dictionary = _prayer_case("PRAYER_04")
	_choose_prayer_seed(data, "failure", data.petitioner, data.domain)
	assert(_open(data))
	var before: int = data.world.state.faith
	assert(_response(data, data.request, "shallow").ok)
	var denied: bool = _reject_response(data, data.request, "deep")
	for id: String in data.world.state.prayer_system.offered:
		if id != data.request: denied = _reject_response(data, id, "shallow") and denied
	_check("PRY-002", "失败也消费本请求与全局本轮唯一回应，不能重试或换卡；浅触不额外扣信仰", denied and data.turn.context.responses == 1 and data.world.state.faith == before and _facts(data.world, "prayer_result")[-1].changes.outcome == "failure")
func _subject_invalidation() -> void:
	for migrate: bool in [false, true]:
		var data: Dictionary = _prayer_case("PRAYER_04")
		var command: Dictionary = {"kind": "migrate", "npc": data.petitioner, "domain": data.world.state.domains[data.domain].neighbors[0], "parents": [data.situation]} if migrate else {"kind": "status", "npc": data.petitioner, "status": "dead", "parents": [data.situation]}
		data.fixture.gather = [{"type": "world_command", "source": data.situation, "command": command}]
		assert(_open(data)); data.fixture.gather = []
		_check("PRY-003/migrate" if migrate else "PRY-003/death", "冻结之后原主体死亡/迁域不换对象，不支付、不骰、不消费回应", _reject_response(data, data.request, "deep") and data.turn.context.responses == 0 and _facts(data.world, "turn_check").is_empty())
func _crisis_continuity() -> void:
	for success: bool in [false, true]:
		var data: Dictionary = _prayer_case("PRAYER_01")
		_choose_prayer_seed(data, "success" if success else "failure", data.petitioner, data.domain)
		assert(_open(data) and _response(data, data.request, "shallow").ok)
		var held: bool = data.world.state.simulation.holds.has(data.subjects.relative)
		var unaltered: bool = Store.entry(data.world.state.facts, data.fact_map.condition).changes.due == 3
		assert(_evolve(data) and _finish(data) and _round(data) and _round(data))
		var status: String = Store.entry(data.world.state.npcs, data.subjects.relative).status
		var deaths: int = _facts(data.world, "status_change").filter(func(f: Dictionary) -> bool: return f.actor == data.subjects.relative and f.changes.get("to") == "dead").size()
		assert(_round(data))
		_check("PRY-004/rescued" if success else "PRY-004/failed", "请求失败不提前解危/杀人；原due一次死亡，真实救治则保留原历史且不死亡", unaltered and (held or success) and (status == "active" if success else status == "dead") and deaths == (0 if success else 1) and _facts(data.world, "status_change").filter(func(f: Dictionary) -> bool: return f.actor == data.subjects.relative and f.changes.get("to") == "dead").size() == deaths)
func _prayer_limits() -> void:
	var data: Dictionary = _prayer_case("PRAYER_09", true, {"domain": "DOMAIN-007"})
	assert(_open(data))
	var capacity_before: bool = data.prayers.preview(data.turn, data.request, "shallow").ok
	for domain: String in ["DOMAIN-002", "DOMAIN-003"]: assert(_control(data, {"kind": "focus", "domain": domain}).ok)
	_check("PRY-005", "直接破屏障的浅触同样需F，满额在任何费用和骰之前拒绝", capacity_before and _reject_response(data, data.request, "shallow") and data.turn.context.responses == 0)
	data = _prayer_case("PRAYER_08", false, {"fill_members": true})
	assert(data.world.fix_prayer_source(data.situation, data.turn))
	for id: String in data.world.state.simulation.candidates:
		if data.world.state.simulation.candidates[id].get("source") == data.situation: data.request = id
	assert(_open(data))
	_check("PRY-006", "献身两种回应预留所有可能结果N，满额即使失败档也不得先扣费投骰", _reject_response(data, data.request, "shallow") and _reject_response(data, data.request, "deep") and not Store.entry(data.world.state.npcs, data.petitioner).bound_member)
func _prayer_save_and_fault() -> void:
	var data: Dictionary = _prayer_case("PRAYER_01")
	_choose_prayer_seed(data, "failure", data.petitioner, data.domain)
	assert(_open(data) and _response(data, data.request, "deep").ok)
	var recovered: Dictionary = _prayer_case("PRAYER_01")
	var path: String = scratch.path_join("prayer-" + str(Time.get_ticks_usec()))
	var restored: bool = data.turn.save_archive(path) and recovered.turn.load_archive(path) and recovered.turn.snapshot() == data.turn.snapshot()
	assert(_evolve(data) and _finish(data) and _round(data) and _round(data))
	_check("PRY-007", "失败已回应/原病危/主体holds及随机分段归档，同请求续跑与原due完全一致", restored and _replay_missing(data, recovered))
	data = _prayer_case("PRAYER_01")
	assert(_open(data) and _evolve(data))
	data.fixture.fault = true
	var before: String = data.turn.snapshot()
	var denied: bool = not _finish(data) and before == data.turn.snapshot()
	data.fixture.fault = false
	_check("PRY-008", "期限阶段后继参与者失败，原危机/请求/收入/随机完整回滚且可重试", denied and _finish(data))

func _prayer_fact_match(data: Dictionary, variant: String, outcome: String) -> bool:
	var facts: Array = _facts(data.world, "prayer_fact")
	var tags: Array = facts.map(func(f: Dictionary) -> String: return str(f.changes.tag))
	if not outcome in ["deep", "success"]:
		return not "future_callback" in tags
	if not "future_callback" in tags: return false
	var expected: Dictionary = {
		"PRAYER_01": ["condition_cured"] + (["miracle_witness"] if variant == "deep" else []),
		"PRAYER_02": ["private_testimony", "testimony_learned"] if variant == "shallow" else ["public_witness", "lost_anonymity"],
		"PRAYER_03": ["pursuit_clue_withdrawn", "propagation_restricted"] if variant == "shallow" else ["concealed", "pursuit_relation_withdrawn", "support_withdrawn"],
		"PRAYER_04": ["anomaly_record"] if variant == "shallow" else ["record_learned", "investigation_candidate"],
		"PRAYER_05": ["ritual_witness"] if variant == "shallow" else ["public_ritual", "orthodoxy_question"],
		"PRAYER_06": ["contract_fulfilled", "contract_witness", "appointment_restricted"] if variant == "shallow" else ["contract_fulfilled", "contract_dependency", "contract_learned", "hostile_witness"],
		"PRAYER_07": ["memory_preserved"] + (["memory_conflict"] if variant == "deep" else []),
		"PRAYER_08": ["public_prophet"] if variant == "deep" else [],
		"PRAYER_09": ["escape_route"] + (["anomaly_evidence", "missing_risk"] if variant == "deep" else []),
		"PRAYER_10": ["relation_learned"] if variant == "shallow" else ["public_evidence"],
		"PRAYER_11": ["relic_holder_learned", "relationship_exposed"] if variant == "shallow" else ["relic_recovery_opportunity"],
		"PRAYER_12": ["exception_record"] if variant == "shallow" else ["exception_learned", "public_exception_qualification"]
	}
	if data.prayer == "PRAYER_10" and variant == "shallow" and data.world.history.knows(data.world.state, data.subjects.opponent, data.fact_map.relation): expected.PRAYER_10.append("hostility")
	for tag: String in expected[data.prayer]:
		if not tag in tags: print("MISSING_PRAYER_FACT ", data.prayer, " ", tag); return false
	for tag: String in expected[data.prayer]:
		if not tag in ["public_witness", "public_prophet", "public_ritual", "public_evidence", "public_exception_qualification", "anomaly_evidence"]: continue
		var exposures: Array = _facts(data.world, "exposure").filter(func(f: Dictionary) -> bool: return f.changes.get("request") == data.request and f.changes.get("tag") == tag and f.changes.get("public") == true)
		if exposures.size() != 1: return false
		var institution: String = data.subjects.other_institution if tag == "public_exception_qualification" else data.institution
		if not data.world.history.knows(data.world.state, institution, exposures[0].id, true): return false
	if data.prayer == "PRAYER_04" and variant == "deep" and not data.world.history.knows(data.world.state, data.subjects.second, data.fact_map.record): return false
	if data.prayer == "PRAYER_07":
		var preserved: Array = facts.filter(func(f: Dictionary) -> bool: return f.changes.tag == "memory_preserved")
		if preserved.size() != (1 if variant == "shallow" else 3): return false
	if data.prayer == "PRAYER_11" and variant == "deep":
		var opportunity: Dictionary = facts.filter(func(f: Dictionary) -> bool: return f.changes.tag == "relic_recovery_opportunity")[0]
		var relic: Dictionary = Store.entry(data.world.state.relics, data.subjects.relic)
		if opportunity.changes.captor != relic.captor or opportunity.changes.status_source != relic.status_source or opportunity.changes.earliest != data.world.state.turn + int(catalog.tables.events.EVENT_10.min_age) or opportunity.changes.due != data.world.state.turn + int(catalog.tables.events.EVENT_10.max_age): return false
	return true

func _prayer_expiry() -> void:
	for prayer: String in catalog.tables.prayers:
		var data: Dictionary = _prayer_case(prayer)
		assert(_round(data) and _round(data) and _round(data))
		var closed: bool = not data.world.state.prayer_system.requests.has(data.request) and not data.world.state.simulation.candidates.has(data.request)
		var facts: Array = _facts(data.world, "prayer_fact")
		var relevant: Array = facts.filter(func(f: Dictionary) -> bool: return f.changes.get("request") == data.request)
		var tags: Array = relevant.map(func(f: Dictionary) -> String: return str(f.changes.tag))
		var specific: bool = true
		if prayer == "PRAYER_01": specific = Store.entry(data.world.state.npcs, data.subjects.relative).status == "dead"
		if prayer == "PRAYER_06": specific = "cooperation_closed" in tags and Store.has(data.world.state.invalid_records, data.fact_map.contract)
		if prayer == "PRAYER_07": specific = relevant.filter(func(f: Dictionary) -> bool: return f.changes.tag == "memory_qualification_lost").size() == 3
		if prayer == "PRAYER_10": specific = "dispute_settled" in tags and Store.has(data.world.state.invalid_records, data.fact_map.conflict)
		var count: int = facts.size()
		assert(_round(data))
		var after: Array = _facts(data.world, "prayer_fact").filter(func(f: Dictionary) -> bool: return f.changes.get("request") == data.request)
		_check("EXPIRY/" + prayer, "不回应期限真实关闭、条目特定后果一次提交且无重复背景罚款 " + prayer, closed and specific and relevant.size() == after.size() and _facts(data.world, "prayer_result").is_empty(), {"tags": tags, "factsBefore": count})

func _prayer_agents_and_sources() -> void:
	var data: Dictionary = _prayer_case("PRAYER_01", true, {"agent": true})
	_choose_prayer_seed(data, "disaster", data.agent, data.domain)
	assert(_open(data))
	var before: int = Store.entry(data.world.state.npcs, data.agent).sanity
	var relative: int = Store.entry(data.world.state.npcs, data.subjects.relative).sanity
	var petitioner: int = Store.entry(data.world.state.npcs, data.petitioner).sanity
	var denied: bool = _reject_response(data, data.request, "deep", {"agent": data.agent}) and _reject_response(data, data.request, "deep", {"agent": data.agent, "agent_source": data.fact_map.relation})
	assert(_response(data, data.request, "deep", {"agent": data.agent, "agent_source": data.agent_source}).ok)
	_check("PRY-009", "代理须正式成员及原请求有源委托；公共灾变由实际检定者承担，条目代价仍作用于原亲属", denied and Store.entry(data.world.state.npcs, data.agent).sanity == before - catalog.integer("prayer_disaster_sanity_loss") and Store.entry(data.world.state.npcs, data.subjects.relative).sanity == relative - 10 and Store.entry(data.world.state.npcs, data.petitioner).sanity == petitioner and _facts(data.world, "turn_check")[-1].actor == data.agent)
	data = _prayer_case("PRAYER_04", false)
	var original: Dictionary = Store.entry(data.world.state.facts, data.situation).changes.duplicate(true)
	original.issuer = "unknown"
	var invalid: String = data.world.introduce_fact("prayer_situation", data.domain, data.petitioner, original.actors, [data.situation], original, original.actors, [], data.turn)
	var snapshot: String = data.turn.snapshot()
	_check("PRY-010", "未知签发者/缺失原事实父链不能固定请求，拒绝完全不改变状态", not data.world.fix_prayer_source(invalid, data.turn) and snapshot == data.turn.snapshot())

func _prayer_corruption() -> void:
	var data: Dictionary = _prayer_case("PRAYER_01")
	assert(_open(data))
	var saved: String = data.turn.snapshot()
	for variant: String in ["objects", "deadline", "omitted"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var request: Dictionary = world_envelope.body.state.prayer_system.requests[data.request]
		if variant == "objects": request.descriptor.subjects.relative = data.petitioner
		elif variant == "deadline": request.card.due_turn += 1
		else: world_envelope.body.state.prayer_system.requests.erase(data.request)
		_check("PRY-011/" + variant, "重算封套校验和仍拒绝固定对象/期限/热请求遗漏伪造并完整保留会话 " + variant, not data.turn.restore(_rewrap_turn(envelope, world_envelope)) and data.turn.snapshot() == saved)

func _background_defaults() -> void:
	for answered: bool in [false, true]:
		var data: Dictionary = _native()
		if answered: _choose_prayer_seed(data, "failure", Store.entry(data.world.state.npcs, data.world.state.simulation.candidates.values()[0].actors[0]).id, "DOMAIN-001")
		assert(_open(data))
		var request: String = data.world.state.prayer_system.offered[0]
		var card: Dictionary = data.world.state.prayer_system.requests[request].card
		var person: String = data.world.state.prayer_system.requests[request].descriptor.subjects.petitioner
		var before: int = Store.entry(data.world.state.npcs, person).loyalty
		if answered: assert(_response(data, request, "shallow").ok)
		assert(_evolve(data) and _finish(data))
		while data.world.state.turn < card.due_turn: assert(_round(data))
		var exposures: Array = _facts(data.world, "exposure").filter(func(f: Dictionary) -> bool: return f.changes.get("rule") == "unanswered_request" and f.actor == person)
		var expected: int = 0 if answered else 1
		var loyalty: int = Store.entry(data.world.state.npcs, person).loyalty
		var loss: int = catalog.integer("request_unanswered_trust_loss") if before >= catalog.integer("loyalty_follower_threshold") else 0
		assert(_round(data))
		_check("PRY-012/answered" if answered else "PRY-012/unanswered", "原BG未回应罚款唯一归属；已回应失败消费请求且不再视为未回应", exposures.size() == expected and loyalty == before - (0 if answered else loss) and _facts(data.world, "exposure").filter(func(f: Dictionary) -> bool: return f.changes.get("rule") == "unanswered_request" and f.actor == person).size() == expected)

func _conditional_disclosure() -> void:
	for known: bool in [false, true]:
		var data: Dictionary = _prayer_case("PRAYER_10", true, {"opponent_knows": known})
		_choose_prayer_seed(data, "success", data.petitioner, data.domain)
		assert(_open(data) and _response(data, data.request, "shallow").ok)
		var hostile: Array = _facts(data.world, "prayer_fact").filter(func(f: Dictionary) -> bool: return f.changes.tag == "hostility")
		_check("PRY-013/known" if known else "PRY-013/private", "浅泄密敌意严格依赖原对手的真实知情；不自动全域共享", hostile.size() == (1 if known else 0) and data.world.history.knows(data.world.state, data.petitioner, data.fact_map.relation))

func _prayer_catalog_contract() -> void:
	for variant: int in 3:
		var directory: String = scratch.path_join("bad-prayer-content-" + str(variant) + "-" + str(Time.get_ticks_usec()))
		DirAccess.make_dir_recursive_absolute(directory)
		for table: String in Catalog.FILES + Catalog.EXTENSIONS:
			var text: String = FileAccess.get_file_as_string("res://data/" + table + ".csv")
			if table == "prayer_effects":
				if variant == 0: text = text.replace("delta,actor,sanity_loss,", "delta,actor,unknown,")
				elif variant == 1:
					var lines: PackedStringArray = text.split("\n")
					text = "\n".join(Array(lines).filter(func(line: String) -> bool: return not line.begins_with("PRAYER_01/") or not ",success," in line))
				else: text = text.replace("fulfill,petitioner,contract,", "fulfill,rival,contract,")
			var file: FileAccess = FileAccess.open(directory.path_join(table + ".csv"), FileAccess.WRITE); file.store_string(text); file.close()
		var content: RefCounted = Catalog.new(); assert(content.load_files())
		var version: String = content.version; var extensions: Dictionary = content.extension_versions.duplicate(true)
		_check("PRY-014/" + str(variant), "祈求未知效果字段/缺分支/非法操作主体原子拒绝且保留原目录", not content.load_files(directory) and content.version == version and content.extension_versions == extensions)

func _deep_subject_loss() -> void:
	for prayer: String in ["PRAYER_04", "PRAYER_07"]:
		var data: Dictionary = _prayer_case(prayer)
		var subject: String = data.subjects.second if prayer == "PRAYER_04" else data.subjects.memory_people[1]
		data.fixture.gather = [{"type": "world_command", "source": data.situation, "command": {"kind": "status", "npc": subject, "status": "dead", "parents": [data.situation]}}]
		assert(_open(data)); data.fixture.gather = []
		var deep_denied: bool = _reject_response(data, data.request, "deep")
		var shallow: Dictionary = data.prayers.preview(data.turn, data.request, "shallow")
		var accepted: bool = _response(data, data.request, "shallow").ok
		_check("PRY-015/" + prayer, "深分支专属固定对象死亡只禁深；原ID合法浅分支保留，不换活替身", deep_denied and shallow.ok and accepted and Store.entry(data.world.state.npcs, subject).status == "dead", {"preview": shallow.get("error", ""), "accepted": accepted})

func _canonical_situations() -> void:
	for key: String in ["subjects", "facts"]:
		var data: Dictionary = _prayer_case("PRAYER_01")
		var original: Dictionary = Store.entry(data.world.state.facts, data.situation)
		var changed: Dictionary = original.changes.duplicate(true)
		changed[key]["nonce"] = data.petitioner if key == "subjects" else data.fact_map.condition
		data.fixture.gather = [{"type": "fact", "kind": "prayer_situation", "source": data.situation, "domain": data.domain, "actor": data.petitioner, "targets": changed.actors, "parents": data.world.history.export_value(original.causal_parents), "details": changed, "observers": [], "institutions": []}]
		assert(_open(data)); data.fixture.gather = []
		var sources: Array = _facts(data.world, "prayer_situation").filter(func(f: Dictionary) -> bool: return f.changes[key].has("nonce"))
		assert(sources.size() == 1)
		var source: String = sources[0].id
		var before: String = data.turn.snapshot()
		var reason: Dictionary = data.prayers.validate_situation(data.world, source)
		var pure: bool = before == data.turn.snapshot()
		assert(_evolve(data) and _finish(data) and _open(data))
		var none_fixed: bool = data.world.state.simulation.candidates.values().all(func(c: Dictionary) -> bool: return c.get("source") != source)
		var rejected: String = Store.entry(data.world.state.applied_authorizations, "prayer/source/" + source, "")
		_check("PRY-016/" + key, "无业务额外键不能改变同处境指纹并绕过复开授权 " + key, not reason.ok and reason.error.begins_with("Unknown") and pure and none_fixed and not rejected.is_empty() and Store.entry(data.world.state.facts, rejected).kind == "prayer_source_rejected")
