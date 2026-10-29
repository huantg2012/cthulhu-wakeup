extends "res://tools/prayers/integration_cases.gd"
const Anchors = preload("res://src/game/anchors.gd")
var anchor_rows: Array = []
var seed_cache: Dictionary = {}
var anchor_probability_cache: Dictionary = {}
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	for profile: String in catalog.tables.anchor_conditions: _blueprint(profile)
	if has_method("run_anchor_lifecycle"): call("run_anchor_lifecycle")
	_anchor_contract_negatives()
	var ok: bool = true
	for row: Dictionary in records: ok = ok and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records, "cases": anchor_rows}, "\t", true, true)); file.close()
	quit(0 if ok else 1)

func _generated_profile(profile: String) -> Dictionary:
	for seed_value: int in ([int(seed_cache[profile])] if seed_cache.has(profile) else range(1, 65)):
		var world: RefCounted = _new_hybrid(seed_value)
		for domain: String in world.state.domains:
			if world.state.domains[domain].profile == profile:
				seed_cache[profile] = seed_value
				return {"world": world, "domain": domain, "seed": seed_value}
	assert(false, "No bounded generated sample for " + profile)
	return {}
func _local_person(world: RefCounted, domain: String, institution: String, profile: String = "NPC_PROFILE_01") -> String:
	var id: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local(domain, institution, profile, world.state.domains[domain].origin))
	_bind(world, id)
	return id
func _install_anchors(data: Dictionary) -> void:
	_attach_prayers(data)
	data.anchors = Anchors.new(catalog, ISSUERS); assert(data.anchors.install(data.turn))
func _anchor_base(profile: String) -> Dictionary:
	var data: Dictionary = _generated_profile(profile)
	var world: RefCounted = data.world
	for person: Dictionary in Store.values(world.state.npcs): world.mutable_npc(person.id).loyalty = 0
	data.profile = profile; data.institution = data.domain + "/interpretation"; data.other = data.domain + "/propagation"
	data.people = []
	for index: int in 4:
		var institution: String = data.other if profile == "CIV_05" and index >= 2 else data.institution
		var npc_profile: String = "NPC_PROFILE_02" if profile in ["CIV_02", "CIV_04"] else ("NPC_PROFILE_03" if institution == data.other else "NPC_PROFILE_01")
		data.people.append(_local_person(world, data.domain, institution, npc_profile))
	data.petitioner = data.people[0]; data.guardian = data.people[0]; data.leader = data.people[0]
	data.source = world.state.domains[data.domain].origin
	var succession: String = world.introduce_fact("institution_succession_authorized", data.domain, data.petitioner, [data.institution, data.petitioner], [data.source], {"fixture": "existing_lawful_representative"}, [])
	assert(not succession.is_empty() and world.succeed_institution(data.institution, data.petitioner, succession))
	var economy: RefCounted = Economy.new(catalog, ISSUERS); assert(economy.initialize(world)); data.economy = economy
	assert(world.submit({"kind": "population", "domain": data.domain, "mode": "convert", "amount": 81, "parents": [data.source]}))
	data.cult = "CULT/" + data.domain
	var established: String = world.introduce_fact("cult_establishment_authorized", data.domain, data.leader, [data.leader], [data.source], {"issuer": "cult-fixture", "version": "1", "cult": data.cult, "domain": data.domain, "leader": data.leader, "cohesion": 100}, [])
	assert(world.submit({"kind": "establish_cult", "authorization": established, "parents": [established]}))
	# Explicit midgame bank/pollution and an already existing controlled medium.
	# No anchor, awakening, recognition, successful prayer or payment is prewritten.
	world.state.faith = 80; world.state.domains[data.domain].pollution = 95; world.state.domains[data.domain].alert = 0
	data.medium = _given_relic(world, data.domain, "RELIC_ROOT_NAIL")
	data.requests = []; data.situations = []; data.outputs = []; data.original = {}
	match profile:
		"CIV_01":
			for i: int in 2:
				var root: String = _given_fact(data, "exposure", data.people[i], [data.people[i]], {"public": false, "unexplained": true})
				_add_prayer(data, "PRAYER_04", data.people[i], data.institution, {}, {"record": root})
		"CIV_02", "CIV_04":
			for i: int in (2 if profile == "CIV_02" else 1):
				var ritual: String = _given_fact(data, "ritual_context", data.petitioner, [data.petitioner], {"subject": data.petitioner, "institution": data.institution, "turn": 0})
				_add_prayer(data, "PRAYER_05", data.petitioner, data.institution, {}, {"ritual": ritual})
		"CIV_03", "CIV_08":
			var memory: String = _given_fact(data, "message", data.petitioner, data.people, {"fixture": "existing_shared_memory"})
			var ties: Array = []
			for person: String in data.people.slice(1):
				world._know(person, memory); ties.append(_given_relation(data, data.petitioner, person, "social"))
			var risk: String = _given_fact(data, "memory_at_risk", data.petitioner, data.people, {"memory": memory, "holders": data.people.slice(1), "due": 3}, [memory])
			data.original.memory = memory
			_add_prayer(data, "PRAYER_07", data.petitioner, data.institution, {"memory_people": data.people.slice(1)}, {"memory": risk, "relations": ties}, {"source": risk, "due": 3})
		"CIV_05":
			for i: int in 2:
				var actor: String = data.people[i * 2]; var rival: String = data.people[i * 2 + 1]
				var institution: String = data.institution if i == 0 else data.other
				var relation: String = _given_relation(data, actor, rival, "rival")
				var stance: String = _given_fact(data, "message", actor, [actor, rival], {"institution": institution, "stance": "existing_dispute"})
				world._institution_know(institution, stance)
				var conflict: String = _given_fact(data, "faction_conflict", actor, [actor, rival], {"parties": [actor, rival], "institution": institution, "default_stance": stance, "due": 3}, [relation, stance])
				_add_prayer(data, "PRAYER_02", actor, institution, {"rival": rival}, {"relation": relation, "conflict": conflict})
		"CIV_06":
			var contract: String = _given_fact(data, "contract_obligation", data.petitioner, data.people.slice(0, 2), {"obligor": data.petitioner, "counterparty": data.people[1], "institution": data.institution, "due": 3})
			data.original.contract = contract
			data.original.inheritance_relation = _given_relation(data, data.petitioner, data.people[2], "social")
			data.original.inheritance_fixed = _given_fact(data, "contract_inheritance_fixed", data.petitioner, [data.petitioner, data.people[2]], {"issuer": "cult-fixture", "version": "1", "contract": contract, "obligor": data.petitioner, "successor": data.people[2], "relation": data.original.inheritance_relation}, [contract, data.original.inheritance_relation])
			_add_prayer(data, "PRAYER_06", data.petitioner, data.institution, {"counterparty": data.people[1]}, {"contract": contract}, {"source": contract, "due": 3})
		"CIV_07":
			var exception: String = _given_fact(data, "exception", data.petitioner, [data.petitioner], {"institution": data.institution, "public": false})
			world._institution_know(data.institution, exception); data.original.exception = exception
			_add_prayer(data, "PRAYER_12", data.people[0], data.institution, {}, {"exception": exception})
			_add_prayer(data, "PRAYER_12", data.people[1], data.institution, {"other_institution": data.other}, {"exception": exception})
	world.attention.sync(world); world.history.rebuild(world.state)
	_install_anchors(data)
	for source: String in data.situations:
		assert(world.fix_prayer_source(source, data.turn))
		for id: String in world.state.simulation.candidates:
			if world.state.simulation.candidates[id].get("source") == source: data.requests.append(id)
	assert(data.requests.size() == data.situations.size())
	return data

func _add_prayer(data: Dictionary, prayer: String, person: String, institution: String, extra_subjects: Dictionary, facts: Dictionary, crisis: Dictionary = {}) -> void:
	var subjects: Dictionary = {"petitioner": person}; subjects.merge(extra_subjects)
	var actors: Array = [person]
	for value: Variant in extra_subjects.values():
		if value is Array: actors.append_array(value)
		elif value is String and Store.has(data.world.state.npcs, value): actors.append(value)
	var parents: Array = []
	for value: Variant in facts.values():
		if value is Array: parents.append_array(value)
		else: parents.append(value)
	var source: String = data.world.introduce_fact("prayer_situation", data.domain, person, actors, parents, {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers[prayer].need, "domain": data.domain, "institution": institution, "actors": actors, "subjects": subjects, "facts": facts, "crisis": crisis}, actors)
	assert(not source.is_empty()); data.situations.append(source)

func _prayer_outputs(data: Dictionary, request: String, kind: String = "prayer_fact") -> Array:
	return _facts(data.world, kind).filter(func(f: Dictionary) -> bool: return f.changes.get("request") == request)
func _tag(data: Dictionary, request: String, tag: String, kind: String = "prayer_fact") -> String:
	var facts: Array = _prayer_outputs(data, request, kind).filter(func(f: Dictionary) -> bool: return f.changes.get("tag") == tag)
	assert(not facts.is_empty(), "Missing actual prayer output " + tag)
	return str(facts[0].id)
func _produce_support(data: Dictionary) -> void:
	var found: bool = false
	for seed_value: int in range(1, 1000001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = seed_value
		var usable: bool = true
		for index: int in data.requests.size():
			var roll: int = rng.randi_range(1, 100)
			usable = usable and roll <= catalog.integer("check_probability_min")
		var anchor_roll: int = rng.randi_range(1, 100)
		var wanted: String = data.get("wanted_outcome", "successful")
		if wanted == "successful": usable = usable and anchor_roll <= catalog.integer("check_probability_min")
		else: usable = usable and data.world.check_result(anchor_probability_cache[data.profile], anchor_roll) == wanted
		if usable:
			data.world.randoms.checks.seed = seed_value; data.check_seed = seed_value; found = true; break
	assert(found, "No bounded initial seed for actual scheduled checks")
	for index: int in data.requests.size():
		var request: String = data.requests[index]
		var card: Dictionary = data.world.state.simulation.candidates[request]
		var person: String = card.actors[0]
		assert(_open(data))
		var variant: String = "shallow" if data.profile in ["CIV_01", "CIV_02"] or data.profile == "CIV_07" and index == 0 else "deep"
		var response: Dictionary = _response(data, request, variant)
		assert(response.ok, "Real support prayer failed qualification")
		var result: Dictionary = _prayer_outputs(data, request, "prayer_result")[0]
		assert(result.changes.outcome in ["deep", "success"], "Initial seed must cover the scheduled support responses")
		data.outputs.append(request)
		assert(_evolve(data) and _finish(data))

func _support_basis(data: Dictionary) -> Dictionary:
	var first: String = data.outputs[0]
	match data.profile:
		"CIV_01": return {"records": [_tag(data, first, "anomaly_record"), _tag(data, data.outputs[1], "anomaly_record")], "witnesses": data.people.slice(0, 2)}
		"CIV_02": return {"rituals": [_tag(data, first, "ritual_witness"), _tag(data, data.outputs[1], "ritual_witness")], "priest": data.petitioner}
		"CIV_03", "CIV_08":
			var preserved: Array = _prayer_outputs(data, first).filter(func(f: Dictionary) -> bool: return f.changes.tag == "memory_preserved")
			var qualifications: Array = []
			for person: String in data.people.slice(1):
				qualifications.append(preserved.filter(func(f: Dictionary) -> bool: return person in f.targets)[0].id)
			return {"memory": data.original.memory, "witnesses": data.people.slice(1), "qualifications": qualifications}
		"CIV_04":
			var ritual: String = _tag(data, first, "public_ritual")
			return {"ritual": ritual, "public": ritual, "priest": data.petitioner}
		"CIV_05": return {"other_institution": data.other, "records": [_tag(data, first, "public_witness", "exposure"), _tag(data, data.outputs[1], "public_witness", "exposure")], "witnesses": [data.people[0], data.people[2]]}
		"CIV_06": return {"contract": data.original.contract, "dependency": _tag(data, first, "contract_dependency"), "witnesses": [_tag(data, first, "contract_fulfilled"), _tag(data, first, "contract_learned")]}
		"CIV_07": return {"exception": data.original.exception, "other_institution": data.other, "records": [_tag(data, first, "exception_record"), _tag(data, data.outputs[1], "exception_learned")]}
	return {}
func _basis_parents(basis: Dictionary) -> Array:
	var parents: Array = []
	for value: Variant in basis.values():
		for id: Variant in (value if value is Array else [value]):
			if id is String and id.begins_with("FACT-") and not id in parents: parents.append(id)
	return parents
func _event_effect(data: Dictionary, basis: Dictionary, settings: Dictionary = {}) -> Dictionary:
	var row: Dictionary = catalog.tables.anchor_conditions[data.profile]
	var institution: String = settings.get("institution", data.institution)
	var changes: Dictionary = {"issuer": settings.get("issuer", "cult-fixture"), "version": "1", "event": settings.get("event", row.event_id), "option": settings.get("option", "B" if row.event_option == "*" else row.event_option), "institution": institution, "basis": basis}
	var targets: Array = [institution]
	for value: Variant in basis.values():
		for id: Variant in (value if value is Array else [value]):
			if id is String and Store.has(data.world.state.npcs, id) and not id in targets: targets.append(id)
	for person: String in data.people:
		if not person in targets: targets.append(person)
	return {"type": "fact", "kind": "institution_event_result", "source": data.source, "domain": data.domain, "actor": data.petitioner, "targets": targets, "parents": _basis_parents(basis), "details": changes, "observers": [], "institutions": [institution]}
func _anchor_payload(data: Dictionary, proof: String = "") -> Dictionary:
	return {"npc": data.guardian, "source": data.proof if proof.is_empty() else proof, "qualification": data.proof if proof.is_empty() else proof, "institution": data.institution, "relic": data.medium}
func _ready_anchor(profile: String, wanted_outcome: String = "successful") -> Dictionary:
	var data: Dictionary = _anchor_base(profile); data.wanted_outcome = wanted_outcome
	_produce_support(data)
	data.basis = _support_basis(data)
	data.fixture.gather = _event_transfers(data, data.basis) + [_event_effect(data, data.basis)]
	assert(_open(data)); data.fixture.gather = []
	var results: Array = _facts(data.world, "institution_event_result")
	assert(not results.is_empty()); data.proof = results[-1].id
	var preview: Dictionary = data.powers.preview(data.turn, "POWER_ANCHOR", _anchor_payload(data))
	assert(preview.ok, str(preview))
	if anchor_probability_cache.has(profile): assert(anchor_probability_cache[profile] == preview.probability)
	anchor_probability_cache[profile] = preview.probability
	return data
func _create_anchor(data: Dictionary) -> Dictionary:
	var result: Dictionary = _power(data, "POWER_ANCHOR", _anchor_payload(data))
	data.anchor = "ANCHOR/" + data.institution
	return result
func _blueprint(profile: String) -> void:
	var data: Dictionary = _ready_anchor(profile)
	var before: String = data.turn.snapshot()
	var qualified: Dictionary = Anchors.qualify(data.world.state, data.institution, data.proof, catalog, data.world.history)
	var preview: Dictionary = data.powers.preview(data.turn, "POWER_ANCHOR", _anchor_payload(data))
	var pure: bool = before == data.turn.snapshot()
	anchor_rows.append({"profile": profile, "seed": data.seed, "domain": data.domain, "proof": data.proof, "qualified": qualified, "preview": preview.get("error", "")})
	_check("ANC-PROFILE/" + profile, "真实祈求结果接具体事件结果合同，蓝本全部实际制度条件确定性满足 " + profile, qualified.get("ok", false) and preview.ok and pure, anchor_rows[-1])
	_profile_negatives(data)
	var awakening: int = data.world.state.awakening
	var faith: int = data.world.state.faith
	var created: Dictionary = _create_anchor(data)
	var dormant: bool = created.ok and data.world.state.anchors.has(data.anchor) and data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.awakening == awakening and data.world.state.faith == faith - preview.faith
	var finished: bool = _evolve(data) and _finish(data)
	var anchor: Dictionary = data.world.state.anchors.get(data.anchor, {})
	var tier: String = data.world.state.domains[data.domain].tier
	_check("ANC-BUILD/" + profile, "正式锚定完整扣费检定与媒介绑定，新建休眠经实际供奉终检激活 " + profile, dormant and finished and anchor.get("state") == "active" and data.world.state.awakening == awakening + catalog.integer("anchor_" + tier + "_contribution"), {"created": created, "anchor": anchor, "faith_before": faith, "faith_after": data.world.state.faith})

func _anchor_contract_negatives() -> void:
	_contract_successor_case()
	_late_knowledge_case()
	_restriction_case()
	for outcome: String in ["deep", "success", "failure", "disaster"]:
		var data: Dictionary = _ready_anchor("CIV_01", outcome)
		var preview: Dictionary = data.powers.preview(data.turn, "POWER_ANCHOR", _anchor_payload(data))
		var faith: int = data.world.state.faith; var whispers: int = data.world.state.whispers
		var result: Dictionary = _create_anchor(data)
		var actual: Dictionary = _facts(data.world, "power_result").filter(func(f: Dictionary) -> bool: return f.changes.get("power") == "POWER_ANCHOR")[-1]
		var exists: bool = data.world.state.anchors.has(data.anchor)
		_check("ANC-OUTCOME/" + outcome, "初始种子一次固定，真实支援回应后锚定四档完整扣费且失败不造锚 " + outcome, result.ok and actual.changes.outcome == outcome and data.world.state.faith == faith - preview.faith and data.world.state.whispers == whispers - preview.whispers and exists == (outcome in ["deep", "success"]), {"check_seed": data.check_seed, "result": actual, "exists": exists})

func _copy_qualify(data: Dictionary, mutation: Callable) -> Dictionary:
	# Deliberately detached malformed/current-condition samples; never adopt them.
	var state: Dictionary = History.export_value(data.world.state)
	mutation.call(state)
	var history: RefCounted = History.new(); history.configure(catalog.tables.npc_behaviors, Anchors.valid_restriction.bind(catalog)); history.rebuild(state)
	return Anchors.qualify(state, data.institution, data.proof, catalog, history)
func _profile_negatives(data: Dictionary) -> void:
	var before: String = data.turn.snapshot()
	var invalid_contracts: Array = [
		func(s: Dictionary): s.facts[data.proof].changes.issuer = "unknown",
		func(s: Dictionary): s.facts[data.proof].changes.version = "wrong",
		func(s: Dictionary): s.facts[data.proof].changes.allowed = true,
		func(s: Dictionary): s.facts[data.proof].changes.option = "not-an-option",
		func(s: Dictionary): s.facts[data.proof].causal_parents = [],
		func(s: Dictionary): s.facts[data.proof].targets = [],
		func(s: Dictionary): s.invalid_records[data.proof] = data.source,
		func(s: Dictionary): s.institutions[data.institution].known_facts.erase(data.proof)
	]
	var denied: bool = true; var reasons: Array = []
	for mutation: Callable in invalid_contracts:
		var q: Dictionary = _copy_qualify(data, mutation); denied = denied and not q.get("allowed", false); reasons.append(q.get("reason"))
	_check("ANC-CONTRACT/" + data.profile, "严格来源版本/选项/字段/目标/父项/当前性/实际知情，布尔捷径不能替代制度证明 " + data.profile, denied and before == data.turn.snapshot(), {"reasons": reasons})
	var probes: Array = []
	match data.profile:
		"CIV_01":
			probes = [
				[func(s: Dictionary): s.facts[data.proof].changes.basis.records[1] = data.basis.records[0], false],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.witnesses[1] = data.basis.witnesses[0], false],
				[func(s: Dictionary): s.facts[data.basis.records[1]].turn = s.facts[data.basis.records[0]].turn, false],
				[func(s: Dictionary): s.npcs[data.basis.witnesses[1]].status = "dead", false],
				[func(s: Dictionary): s.npcs[data.basis.witnesses[1]].status = "detained", true]]
		"CIV_02":
			probes = [
				[func(s: Dictionary): s.facts[data.proof].changes.basis.rituals[1] = data.basis.rituals[0], false],
				[func(s: Dictionary): s.facts[data.basis.rituals[1]].turn = s.facts[data.basis.rituals[0]].turn, false],
				[func(s: Dictionary): s.npcs[data.petitioner].status = "detained", false],
				[func(s: Dictionary): s.institutions[data.institution].representative = data.people[1], false],
				[func(s: Dictionary): s.npcs[data.petitioner].role_tags = [], false]]
		"CIV_03", "CIV_08":
			var survives: bool = data.profile == "CIV_08"
			probes = [
				[func(s: Dictionary): s.npcs[data.basis.witnesses[2]].status = "dead", survives],
				[func(s: Dictionary): s.invalid_records[data.basis.qualifications[2]] = data.source, survives],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.witnesses[2] = data.people[0], false],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.qualifications[2] = data.basis.qualifications[0], false],
				[func(s: Dictionary): s.npcs[data.basis.witnesses[1]].status = "detained", true]]
		"CIV_04":
			probes = [
				[func(s: Dictionary): s.facts[data.proof].changes.basis.public = data.source, false],
				[func(s: Dictionary): s.npcs[data.petitioner].status = "detained", false],
				[func(s: Dictionary): s.institutions[data.institution].representative = data.people[1], false],
				[func(s: Dictionary): s.npcs[data.petitioner].role_tags = [], false]]
		"CIV_05":
			probes = [
				[func(s: Dictionary): s.institutions[data.institution].links = [], false],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.other_institution = data.institution, false],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.records[1] = data.basis.records[0], false],
				[func(s: Dictionary): s.institutions[data.other].known_facts.erase(data.basis.records[1]), false],
				[func(s: Dictionary): s.npcs[data.basis.witnesses[1]].status = "detained", true]]
		"CIV_06":
			probes = [
				[func(s: Dictionary): s.invalid_records[data.basis.dependency] = data.source, false],
				[func(s: Dictionary): s.npcs[data.petitioner].status = "dead", false],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.witnesses[1] = data.basis.witnesses[0], false],
				[func(s: Dictionary): s.npcs[data.petitioner].status = "detained", true]]
		"CIV_07":
			probes = [
				[func(s: Dictionary): s.invalid_records[data.basis.exception] = data.source, false],
				[func(s: Dictionary): s.institutions[data.institution].links = [], false],
				[func(s: Dictionary): s.facts[data.proof].changes.basis.records[1] = data.basis.records[0], false],
				[func(s: Dictionary): s.institutions[data.other].known_facts.erase(data.basis.records[1]), false]]
	var conditions: bool = true; var details: Array = []
	for probe: Array in probes:
		var q: Dictionary = _copy_qualify(data, probe[0]); conditions = conditions and q.get("allowed", false) == probe[1]; details.append({"expected": probe[1], "actual": q.get("allowed"), "reason": q.get("reason")})
	_check("ANC-CONDITION/" + data.profile, "蓝本当前主体/记录/跨轮/通信/职分正反边界，存活与在场分开 " + data.profile, conditions and before == data.turn.snapshot(), {"probes": details})
	var bad: Dictionary = _anchor_payload(data); bad.qualification = data.source
	var reject: bool = _reject_unchanged(data, "POWER_ANCHOR", bad)
	bad = _anchor_payload(data); bad.institution = data.other
	reject = _reject_unchanged(data, "POWER_ANCHOR", bad) and reject
	_check("ANC-ADMISSION/" + data.profile, "机构错配及非制度源在扣费/骰/身份预算之前无副作用拒绝 " + data.profile, reject and before == data.turn.snapshot())

func _event_transfers(data: Dictionary, basis: Dictionary) -> Array:
	var deliveries: Array = []
	for source: String in _basis_parents(basis):
		if Store.has(data.world.state.invalid_records, source): continue
		var institution: String = data.other if data.profile in ["CIV_05", "CIV_07"] and source == basis.records[1] else data.institution
		if data.world.history.knows(data.world.state, institution, source, true): continue
		var sender: String = ""
		for person: String in data.people:
			if data.world.history.knows(data.world.state, person, source): sender = person; break
		assert(not sender.is_empty(), "A specific record cannot be delivered by an omniscient fixture")
		deliveries.append({"type": "world_command", "source": source, "command": {"kind": "share_record", "npc": sender, "source": source, "institution": institution, "parents": [source]}})
	return deliveries

func _contract_successor_case() -> void:
	var data: Dictionary = _ready_anchor("CIV_06")
	var relation: String = data.original.inheritance_relation
	var fixed: String = data.original.inheritance_fixed
	assert(_evolve(data) and _finish(data))
	data.fixture.gather = [
		{"type": "world_command", "source": data.proof, "command": {"kind": "status", "npc": data.petitioner, "status": "dead", "parents": [data.proof]}},
		{"type": "fact", "kind": "contract_successor_authorized", "source": fixed, "domain": data.domain, "actor": data.people[2], "targets": [data.petitioner, data.people[2]], "parents": [fixed, relation], "details": {"issuer": "cult-fixture", "version": "1", "contract": data.original.contract, "obligor": data.petitioner, "successor": data.people[2], "fixed": fixed, "relation": relation}, "observers": [data.people[2]], "institutions": [data.institution]}]
	assert(_open(data)); data.fixture.gather = []
	var authorization: String = _facts(data.world, "contract_successor_authorized")[-1].id
	var no_successor: Dictionary = Anchors.qualify(data.world.state, data.institution, data.proof, catalog, data.world.history)
	assert(_evolve(data) and _finish(data))
	data.basis["successor"] = authorization
	data.fixture.gather = [_event_effect(data, data.basis)]
	assert(_open(data)); data.fixture.gather = []
	data.proof = _facts(data.world, "institution_event_result")[-1].id
	var allowed: Dictionary = Anchors.qualify(data.world.state, data.institution, data.proof, catalog, data.world.history)
	var death: String = Store.entry(data.world.state.npcs, data.petitioner).status_source
	var same_turn: Dictionary = _copy_qualify(data, func(s: Dictionary): s.facts[fixed].turn = s.facts[death].turn)
	var invalid_relation: Dictionary = _copy_qualify(data, func(s: Dictionary): s.invalid_records[relation] = death)
	var unknown: Dictionary = _copy_qualify(data, func(s: Dictionary): s.facts[authorization].changes.version = "wrong")
	_check("ANC-SUCCESSOR", "原契约依赖不随履约撤销；原承诺人生前固定关系的活承继者有效，死后补造/断关系/错版本拒绝", not no_successor.allowed and allowed.allowed and not same_turn.allowed and not invalid_relation.allowed and not unknown.allowed, {"allowed": allowed, "late": same_turn, "relation": invalid_relation, "version": unknown, "proof": Store.entry(data.world.state.facts, data.proof), "profile": data.world.state.domains[data.domain].profile})

func _late_knowledge_case() -> void:
	var data: Dictionary = _anchor_base("CIV_03")
	_produce_support(data); data.basis = _support_basis(data)
	data.fixture.gather = [_event_effect(data, data.basis)]
	assert(_open(data)); data.fixture.gather = []
	data.proof = _facts(data.world, "institution_event_result")[-1].id
	var denied: bool = not Anchors.qualify(data.world.state, data.institution, data.proof, catalog, data.world.history).allowed and not data.world.state.anchor_system.opportunities.has(data.institution)
	assert(_evolve(data) and _finish(data))
	var deliveries: Array = _event_transfers(data, data.basis)
	for effect: Dictionary in deliveries:
		effect.command["result"] = data.proof; effect.command.parents.append(data.proof)
	data.fixture.gather = deliveries
	assert(_open(data)); data.fixture.gather = []
	var recognized: bool = Anchors.qualify(data.world.state, data.institution, data.proof, catalog, data.world.history).allowed
	var opportunities: Array = _facts(data.world, "institution_relic_opportunity")
	var once: bool = opportunities.size() == 1 and data.world.state.anchor_system.opportunities.get(data.institution) == opportunities[0].id and data.world.state.anchors.is_empty()
	assert(_evolve(data) and _finish(data))
	data.fixture.gather = deliveries
	assert(_open(data)); data.fixture.gather = []
	_check("ANC-LATE-KNOWLEDGE", "事件先到而记录后交，精确result重检在锚前发唯一原期限机会；重复分享不重发", denied and recognized and once and _facts(data.world, "institution_relic_opportunity").size() == 1 and _facts(data.world, "institution_recognized").size() == 1, {"deliveries": deliveries.size(), "opportunities": opportunities})

func _restriction_probe(data: Dictionary, event: String, option: String, reason: String) -> bool:
	var state: Dictionary = History.export_value(data.world.state)
	state.facts[data.proof].changes.event = event; state.facts[data.proof].changes.option = option
	var id: String = "FACT-%08d" % state.next_fact
	state.facts[id] = {"id": id, "kind": "institution_restriction", "turn": state.turn, "domain": data.domain, "actor": "", "targets": [data.institution], "causal_parents": [data.proof], "changes": {"issuer": "cult-fixture", "version": "1", "institution": data.institution, "reason": reason}}
	return Anchors.valid_restriction(state, id, catalog)
func _restriction_case() -> void:
	var data: Dictionary = _ready_anchor("CIV_04")
	var mapping: bool = not _restriction_probe(data, "EVENT_04", "A", "denied") and _restriction_probe(data, "EVENT_04", "B", "denied") and _restriction_probe(data, "EVENT_03", "B", "denied") and not _restriction_probe(data, "EVENT_04", "B", "blocked") and not _restriction_probe(data, "EVENT_02", "B", "denied")
	assert(_create_anchor(data).ok and _evolve(data) and _finish(data))
	var active: bool = data.world.state.anchors[data.anchor].state == "active"
	data.fixture.gather = [_event_effect(data, data.basis, {"option": "B"})]
	assert(_open(data)); data.fixture.gather = []
	var denial: String = _facts(data.world, "institution_event_result")[-1].id
	assert(_evolve(data) and _finish(data))
	data.fixture.gather = [{"type": "fact", "kind": "institution_restriction", "source": denial, "domain": data.domain, "actor": "", "targets": [data.institution], "parents": [denial], "details": {"issuer": "cult-fixture", "version": "1", "institution": data.institution, "reason": "denied"}, "observers": [], "institutions": [data.institution]}]
	assert(_open(data)); data.fixture.gather = []
	var source: String = _facts(data.world, "institution_restriction")[-1].id
	var maintenance: Dictionary = Anchors.maintenance(data.world.state, data.institution, catalog, data.world.history)
	_check("ANC-RESTRICTION", "正面选项不能反造否认/封锁；原03B/04B明确否认来源才限制该机构并即时休眠", mapping and active and Anchors.valid_restriction(data.world.state, source, catalog) and not maintenance.allowed and data.world.state.anchors[data.anchor].state == "dormant", {"mapping": mapping, "source": source, "maintenance": maintenance})
