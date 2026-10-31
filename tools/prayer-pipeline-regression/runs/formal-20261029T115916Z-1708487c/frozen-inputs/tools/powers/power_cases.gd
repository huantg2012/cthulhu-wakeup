extends "res://tools/cults/run.gd"
const Powers = preload("res://src/game/powers.gd")
const Relics = preload("res://src/game/relics.gd")
var branch_rows: Array = []
const ISSUERS: Dictionary = {"cult-fixture": "1"}
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	for power: String in catalog.tables.powers:
		if power == "POWER_MANIFEST": continue
		for outcome: String in (["success"] if catalog.tables.powers[power].check_kind == "deterministic" else ["deep", "success", "failure", "disaster"]):
			_branch(power, outcome)
	for outcome: String in ["deep", "success", "failure", "disaster"]: _manifest_branch(outcome)
	_special_cases()
	if has_method("run_relic_cases"): call("run_relic_cases")
	var ok: bool = true
	for record: Dictionary in records: ok = ok and record.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records, "branches": branch_rows}, "\t", true, true)); file.close()
	quit(0 if ok else 1)
func _relic_source(world: RefCounted, domain: String, type: String, placement: String = "controlled", holder: String = "", owner: Object = null) -> String:
	var proof: Dictionary = {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": domain, "target": type, "holder": holder}
	return world.introduce_fact("relic_create_authorized", domain, holder, [holder] if not holder.is_empty() else [domain + "/interpretation"], [world.state.domains[domain].origin], {"relic_type": type, "placement": placement, "holder": holder, "proof": proof}, [], [], owner)
func _given_relic(world: RefCounted, domain: String, type: String = "RELIC_ROOT_NAIL") -> String:
	# Existing high-tier world condition, not a claim of a new relic drop.
	var source: String = world._record("message", domain, "", [], [world.state.domains[domain].origin], {"fixture": "preexisting_high_world_medium"})
	var id: String = "GIVEN/" + source
	Store.put(world.state.relics, id, {"id": id, "type": type, "domain": domain, "placement": "controlled", "holder": "", "anchor": "", "origin": source, "status_source": source})
	world.history.refresh_relic(world.state, id)
	return id
func _high(omit_anchor: bool = false) -> Dictionary:
	var data: Dictionary = _prepare(true, 81, 100)
	var world: RefCounted = data.world
	data["guardians"] = {}; data["anchors"] = {}; data["medium"] = ""
	for domain: String in ["DOMAIN-001", "DOMAIN-007", "DOMAIN-011"]:
		if domain != "DOMAIN-001":
			var leader_id: String = "NPC-%08d" % int(world.state.next_npc)
			assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin))
			_bind(world, leader_id)
			assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [world.state.domains[domain].origin]}))
			var auth: String = world.introduce_fact("cult_establishment_authorized", domain, leader_id, [leader_id], [world.state.domains[domain].origin], {"issuer": "cult-fixture", "version": "1", "cult": "CULT/" + domain, "domain": domain, "leader": leader_id, "cohesion": 100}, [])
			assert(world.submit({"kind": "establish_cult", "authorization": auth, "parents": [auth]}))
		world.state.domains[domain].pollution = 95
		world.state.domains[domain].barrier = 0; world.state.domains[domain].alert = 0
		var cult_id: String = data.cult if domain == "DOMAIN-001" else "CULT/" + domain
		var people: Array = [world.state.cults[cult_id].leader]
		for i: int in 2:
			var npc: String = "NPC-%08d" % int(world.state.next_npc)
			assert(world._nominate_local(domain, domain + "/" + ["propagation", "order"][i], ["NPC_PROFILE_03", "NPC_PROFILE_05"][i], world.state.domains[domain].origin))
			_bind(world, npc); people.append(npc)
		data.guardians[domain] = people
		for i: int in 3:
			var institution: String = domain + "/" + ["interpretation", "propagation", "order"][i]
			# Named representatives are existing qualified source conditions.
			if world.state.institutions[institution].representative.is_empty():
				world.state.institutions[institution].representative = people[i]
				world.state.institutions[institution].occupancy = "represented"
				world.mutable_npc(people[i]).institution = institution
			var relic: String = _given_relic(world, domain)
			if omit_anchor and domain == "DOMAIN-001" and i == 0:
				data.medium = relic; continue
			var id: String = "ANCHOR/" + institution
			world.state.anchors[id] = {"id": id, "domain": domain, "institution": institution, "guardian": people[i], "relic": relic, "state": "dormant", "needs_rebind": false, "origin": world.state.cults[cult_id].established_source, "ordinal": i + 1, "cult": cult_id}
			assert(Relics.new(catalog, ISSUERS).bind(world, relic, id, world.state.cults[cult_id].established_source, null))
			assert(world.submit({"kind": "economy_qualification", "rule": "anchor", "subject": id, "institution": institution, "allowed": true, "issuer": "cult-fixture", "version": "1", "parents": [world.state.cults[cult_id].established_source]}))
			world.state.anchors[id].state = "active"
			data.anchors[institution] = id
	var receiving: String = world.state.domains["DOMAIN-001"].neighbors[0]
	data["receiving"] = receiving
	if not receiving in ["DOMAIN-001", "DOMAIN-007", "DOMAIN-011"]:
		var person: String = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local(receiving, receiving + "/interpretation", "NPC_PROFILE_01", world.state.domains[receiving].origin))
		_bind(world, person)
		assert(world.submit({"kind": "population", "domain": receiving, "mode": "convert", "amount": 81, "parents": [world.state.domains[receiving].origin]}))
		var auth: String = world.introduce_fact("cult_establishment_authorized", receiving, person, [person], [world.state.domains[receiving].origin], {"issuer": "cult-fixture", "version": "1", "cult": "CULT/" + receiving, "domain": receiving, "leader": person, "cohesion": 100}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": auth, "parents": [auth]}))
	world.state.insight = 20
	world._refresh_anchors(); world.state.faith = 80
	world.state.turn = 0; world.state.phase = "between"
	world.attention.sync(world); world.history.rebuild(world.state)
	return data
func _attach_powers(data: Dictionary) -> Dictionary:
	var turn: RefCounted = Turn.new(data.world)
	assert(turn._attached)
	assert(data.economy.install(turn))
	var fixture: RefCounted = Fixture.new()
	assert(turn.register_participant("cult-fixture", "1", ["events", "deadlines", "ending"], ["fact", "world_command", "resource", "schedule"], fixture.handle))
	var cults: RefCounted = Cults.new(catalog); assert(cults.install(turn))
	var relics: RefCounted = Relics.new(catalog, ISSUERS); assert(relics.install(turn))
	var powers: RefCounted = Powers.new(catalog, ISSUERS); assert(powers.install(turn))
	data.turn = turn; data.fixture = fixture; data.cults = cults; data.relics = relics; data.powers = powers
	return data
func _qualification(data: Dictionary, rule: String, target: String, actor: String, domain: String, basis: Dictionary, institution: String = "") -> String:
	var parents: Array = [data.world.state.domains[domain].origin]
	for field: String in ["clue", "fact", "contact", "source", "joined"]:
		if basis.has(field) and not basis[field] in parents: parents.append(basis[field])
	for id: String in basis.get("sources", []) + basis.get("benefits", []):
		if not id in parents: parents.append(id)
	return data.world.introduce_fact("power_qualification", domain, actor, [target, actor] if not actor.is_empty() else [target], parents, {"issuer": "cult-fixture", "version": "1", "rule": rule, "target": target, "actor": actor, "institution": institution, "basis": basis}, [], [], data.turn if data.has("turn") else null)
func _payload(data: Dictionary, power: String) -> Dictionary:
	var npc: String = data.leader
	var domain: String = "DOMAIN-001"
	var source: String = data.source
	var payload: Dictionary = {"npc": npc, "source": source}
	match power:
		"POWER_LISTEN":
			var hidden: String = data.world.introduce_fact("message", domain, "", [], [source], {"hidden": true}, [], [], data.turn)
			var clue: String = data.world.introduce_fact("message", domain, "", [], [source], {"target_fact": hidden}, [], [], data.turn)
			payload = {"domain": domain, "source": _qualification(data, "listen", hidden, "", domain, {"clue": clue, "fact": hidden})}
		"POWER_DREAM": payload.qualification = _qualification(data, "dream", npc, npc, domain, {"contact": source})
		"POWER_ORACLE": payload.declared_action = "POWER_BREACH"
		"POWER_BESTOW": payload.attribute = "adaptation"
		"POWER_APPOINT": payload.npc = data.guardians[domain][1]; payload.cult = data.cult; payload.role = "leader"
		"POWER_SACRIFICE":
			payload.mode = "faith"
			payload.qualification = _qualification(data, "tenure", data.cult, npc, domain, {"joined": Store.entry(data.world.state.npcs, npc).joined_source})
		"POWER_BREACH": payload.qualification = _qualification(data, "weakness", npc, npc, domain, {"source": source})
		"POWER_SEED": payload.qualification = _qualification(data, "spread", data.cult, npc, domain, {"institution": domain + "/propagation", "sources": [source]}, domain + "/propagation")
		"POWER_ANCHOR":
			payload.institution = domain + "/interpretation"; payload.relic = data.medium
			payload.qualification = _qualification(data, "anchor", payload.institution, npc, domain, {"institution": payload.institution, "sources": [source]}, payload.institution)
		"POWER_VEIL": payload.qualification = _qualification(data, "evidence", data.cult, npc, domain, {"source": source, "benefits": []})
		"POWER_TRANSFER": payload.target_domain = data.receiving; payload.escort = 6
		"POWER_MANIFEST":
			payload.npc = data.guardians["DOMAIN-011"][0]
			payload.cosmic_anchor = data.anchors["DOMAIN-011/interpretation"]
			payload.system_anchor = data.anchors["DOMAIN-007/interpretation"]
	return payload
func _seed(data: Dictionary, power: String, outcome: String, payload: Dictionary) -> int:
	var row: Dictionary = catalog.tables.powers[power]
	if row.check_kind == "deterministic": return 0
	var domain: String = Store.entry(data.world.state.npcs, payload.npc).domain
	var probability: int = data.world.check_probability(payload.npc, row.attribute, domain, row.check_kind)
	for value: int in range(1, 10001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = value
		var roll: int = rng.randi_range(1, 100)
		if data.world.check_result(probability, roll) == outcome:
			data.world.randoms.checks.seed = value
			return value
	return -1
func _power(data: Dictionary, id: String, payload: Dictionary) -> Dictionary:
	return _submit(data, "act", {"participant": "powers", "action": id, "payload": payload})
func _branch(power: String, outcome: String) -> void:
	var data: Dictionary = _high(power == "POWER_ANCHOR")
	if power == "POWER_BREACH": data.world.state.domains["DOMAIN-001"].barrier = 40
	if power == "POWER_VEIL": data.world.state.domains["DOMAIN-001"].alert = 20
	_attach_powers(data)
	var payload: Dictionary = _payload(data, power)
	var seed_value: int = _seed(data, power, outcome, payload)
	if power == "POWER_SACRIFICE":
		assert(_round(data) and _round(data))
	assert(_open(data))
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.powers.preview(data.turn, power, payload)
	var pure: bool = before == data.turn.snapshot()
	var observed: Dictionary = _observe(data, payload)
	var response: Dictionary = _power(data, power, payload)
	var checks: Array = _facts(data.world, "turn_check")
	var results: Array = _facts(data.world, "power_result")
	var actual: String = results[-1].changes.outcome if not results.is_empty() else "missing"
	var effects_ok: bool = response.ok and _effects_match(data, power, outcome, payload, observed)
	var valid: bool = preview.ok and pure and response.ok and actual == outcome and effects_ok
	if power == "POWER_APPOINT":
		assert(_evolve(data) and _finish(data) and _open(data))
		valid = response.ok and pure and data.world.state.cults[data.cult].leader == payload.npc
	if row_is_random(power): valid = valid and not checks.is_empty() and checks[-1].changes.outcome == outcome and checks[-1].changes.snapshot_before_always
	branch_rows.append({"power": power, "expected": outcome, "actual": actual, "seed": seed_value, "check": checks[-1].changes if not checks.is_empty() else {}, "error": response.get("error", ""), "effects": effects_ok, "preview_error": preview.get("error", "")})
	_check("PWR/" + power + "/" + outcome, "真实权能预览纯读与正式执行 " + power + " " + outcome, valid, branch_rows[-1])
func row_is_random(power: String) -> bool:
	return catalog.tables.powers[power].check_kind != "deterministic"
func _manifest_branch(outcome: String) -> void:
	var data: Dictionary = _high()
	_attach_powers(data)
	var payload: Dictionary = _payload(data, "POWER_MANIFEST")
	var seed_value: int = _seed(data, "POWER_MANIFEST", outcome, payload)
	assert(_open(data))
	var paid: bool = _power(data, "POWER_MANIFEST", payload).ok
	var early: bool = _facts(data.world, "turn_check").is_empty()
	for i: int in 2:
		assert(_evolve(data) and _finish(data) and _open(data))
		paid = _power(data, "POWER_MANIFEST_CONTINUE", {"source": data.source}).ok and paid
		if i == 0: early = early and _facts(data.world, "turn_check").is_empty()
	assert(_evolve(data) and _finish(data))
	var checks: Array = _facts(data.world, "turn_check")
	var actual: String = checks[-1].changes.outcome if not checks.is_empty() else "missing"
	var effect_ok: bool = data.world.state.awakening == 100 and not data.world.state.power_system.completion.is_empty() if outcome in ["deep", "success"] else data.world.state.wounds == (10 if outcome == "failure" else 20)
	if outcome == "disaster": effect_ok = effect_ok and data.world.state.anchors[payload.cosmic_anchor].state == "dormant"
	var valid: bool = paid and early and checks.size() == 1 and actual == outcome and effect_ok
	branch_rows.append({"power": "POWER_MANIFEST", "expected": outcome, "actual": actual, "seed": seed_value, "checks": checks})
	_check("PWR/POWER_MANIFEST/" + outcome, "三轮降临前两轮不骰，第三轮锁概率后轮末唯一检定 " + outcome, valid, {"paid": paid, "early": early, "actual": actual})

func _observe(data: Dictionary, payload: Dictionary) -> Dictionary:
	var state: Dictionary = data.world.state
	var npc: Dictionary = Store.entry(state.npcs, payload.get("npc", "")) if Store.has(state.npcs, payload.get("npc", "")) else {}
	var domain: String = payload.get("domain", npc.get("domain", "DOMAIN-001"))
	return {"actor": npc.duplicate(true), "domain": state.domains[domain].duplicate(true), "cult": state.cults.get(data.cult, {}).duplicate(true), "target_domain": state.domains[payload.get("target_domain", domain)].duplicate(true), "faith": state.faith, "whispers": state.whispers, "wounds": state.wounds}
func _effects_match(data: Dictionary, power: String, outcome: String, payload: Dictionary, before: Dictionary) -> bool:
	var stable_payload: Dictionary = payload.duplicate(true); stable_payload["domain"] = before.domain.id
	var after: Dictionary = _observe(data, stable_payload)
	# Record actual externally visible state against authored result deltas. This
	# also checks clamping; RNG/outcome assertions alone cannot certify effects.
	var deltas: Dictionary = {}
	var applicable: String = "deep_success" if outcome == "deep" else outcome
	for row: Dictionary in catalog.tables.power_effects.values():
		if row.power_id != power or not row.outcome in ["always", applicable] or row.operation != "delta": continue
		if not row.subject in ["actor", "domain", "source_domain", "target_domain", "cult"]: continue
		var subject: String = "domain" if row.subject == "source_domain" else row.subject
		var field: String = payload.get("attribute", "adaptation") if row.field == "selected_attribute" else row.field
		var amount: int = catalog.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)
		if field == "cohesion_loss": field = "cohesion"; amount = -amount
		var key: String = subject + "/" + field
		deltas[key] = int(deltas.get(key, 0)) + amount
	for key: String in deltas:
		var parts: PackedStringArray = key.split("/"); var subject: String = parts[0]; var field: String = parts[1]
		# followers are represented by cohort and named-person operations. Their
		# independent conservation assertions are below.
		if field == "followers": continue
		var maximum: int = catalog.integer("npc_attribute_max") if field in Powers.ATTRIBUTES else 100
		if int(after[subject][field]) != clampi(int(before[subject][field]) + int(deltas[key]), 0, maximum): return false
	if power == "POWER_LISTEN":
		var proof: Dictionary = Store.entry(data.world.state.facts, payload.source)
		return Store.has(data.world.state.applied_authorizations, "power/revealed/" + proof.changes.basis.fact)
	if power == "POWER_ORACLE" and outcome in ["deep", "success"]:
		var entries: Array = data.world.state.power_system.preparations.values()
		return entries.size() == 1 and entries[0].amount == (15 if outcome == "deep" else 10) and entries[0].expires == data.world.state.turn + 1 and entries[0].action == payload.declared_action
	if power == "POWER_SACRIFICE":
		var rank: int = 1; var gain: int = 0
		if outcome in ["deep", "success"]:
			var name: String = "deep" if outcome == "deep" else "success"
			gain = catalog.integer("sacrifice_faith_" + name + "_base") + rank * catalog.integer("sacrifice_faith_" + name + "_per_rank")
		elif outcome == "failure": gain = catalog.integer("sacrifice_faith_failure")
		return after.actor.status == "dead" and int(after.domain.population) == int(before.domain.population) - 1 and data.world.state.faith == mini(Economy.capacity(data.world.state, catalog), int(before.faith) + gain) and data.world.state.whispers == int(before.whispers) - 2
	if power in ["POWER_SEED", "POWER_VEIL"]:
		var amount: int = int(deltas.get("domain/followers", 0))
		var valid: bool = int(after.domain.unnamed_followers) == int(before.domain.unnamed_followers) + amount and after.domain.population == before.domain.population
		if power == "POWER_VEIL": valid = valid and Store.has(data.world.state.invalid_records, data.source) and Store.has(data.world.state.facts, data.source)
		return valid
	if power == "POWER_TRANSFER":
		if outcome in ["deep", "success"]:
			var count: int = 1 + mini(int(payload.escort), 6 if outcome == "deep" else 4)
			return after.actor.id == before.actor.id and after.actor.domain == payload.target_domain and int(after.domain.population) == int(before.domain.population) - count and int(after.target_domain.population) == int(before.target_domain.population) + count and not after.actor.cult_id == data.cult
		return after.actor.status == ("detained" if outcome == "disaster" else "active") and after.actor.domain == before.actor.domain
	if power == "POWER_ANCHOR":
		var medium: Dictionary = Store.entry(data.world.state.relics, payload.relic)
		if outcome in ["deep", "success"]:
			var anchor: Dictionary = data.world.state.anchors["ANCHOR/" + payload.institution]
			return anchor.ordinal == 1 and anchor.state == "dormant" and medium.placement == "bound" and anchor.relic == medium.id and data.world.state.faith == int(before.faith) - 12 and not data.world.state.economy_qualifications.get("anchor|" + anchor.id, "").is_empty()
		return medium.placement == ("sealed" if outcome == "disaster" else "controlled")
	return true

func _reject_unchanged(data: Dictionary, power: String, payload: Dictionary) -> bool:
	var before: String = data.turn.snapshot()
	var denied: Dictionary = _power(data, power, payload)
	return not denied.ok and before == data.turn.snapshot()
func _special_cases() -> void:
	_illegal_powers()
	_costs_and_cooldowns()
	_preparations_and_gifts()
	_manifest_lifecycle()
	_attention_boundaries()
	_sacrifice_modes()
	_power_projection_and_corruption()
	_anchor_repair_and_detention()
	_catalog_contracts()
	_evidence_economy_projection()
func _illegal_powers() -> void:
	for power: String in catalog.tables.powers:
		var data: Dictionary = _high(power == "POWER_ANCHOR"); _attach_powers(data)
		var payload: Dictionary = _payload(data, power)
		match power:
			"POWER_LISTEN": payload.source = data.source
			"POWER_DREAM", "POWER_BREACH", "POWER_SEED", "POWER_VEIL": payload.qualification = ""
			"POWER_ORACLE": payload.declared_action = ""
			"POWER_BESTOW": payload.attribute = "sanity"
			"POWER_APPOINT": payload.role = "invented"
			"POWER_SACRIFICE": payload.mode = "all"
			"POWER_ANCHOR": payload.institution = ""
			"POWER_TRANSFER": payload.target_domain = "DOMAIN-001"
			"POWER_MANIFEST": payload.cosmic_anchor = ""
		assert(_open(data))
		_check("INVALID/" + power, "专属资格非法时不扣费、不骰、不改任务机会 " + power, _reject_unchanged(data, power, payload))
func _costs_and_cooldowns() -> void:
	var data: Dictionary = _high(); _attach_powers(data)
	var payload: Dictionary = _payload(data, "POWER_DREAM"); _seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data))
	var forged: Dictionary = payload.duplicate(true); forged.roll = 1
	var denied: bool = _reject_unchanged(data, "POWER_DREAM", forged)
	var before: Dictionary = _observe(data, payload)
	assert(_power(data, "POWER_DREAM", payload).ok)
	var paid: bool = data.world.state.faith == int(before.faith) - 2 and data.world.state.whispers == int(before.whispers) - 1
	var same: bool = _reject_unchanged(data, "POWER_DREAM", payload)
	var saved: String = data.turn.snapshot()
	var recovered: bool = data.turn.restore(saved) and data.turn.snapshot() == saved
	assert(_evolve(data) and _finish(data) and _open(data))
	var next: bool = _reject_unchanged(data, "POWER_DREAM", payload)
	assert(_evolve(data) and _finish(data) and _open(data))
	_check("PWR-001", "真实费用唯一扣除、拒绝注骰、同轮与完整下一轮冷却及存档", denied and paid and same and recovered and next and data.powers.preview(data.turn, "POWER_DREAM", payload).ok)
	data = _high(); _attach_powers(data); payload = _payload(data, "POWER_DREAM")
	data.fixture.cost = 1
	assert(_submit(data, "advance").ok)
	data.fixture.cost = data.world.state.faith
	assert(_submit(data, "resolve_event", {"event": "payment", "action": "pay"}).ok)
	data.fixture.cost = 0
	assert(_submit(data, "finish_events").ok)
	_check("PWR-002", "真实上游支付耗尽信仰后动作预览/执行共同拒绝，不消费RNG", not data.powers.preview(data.turn, "POWER_DREAM", payload).ok and _reject_unchanged(data, "POWER_DREAM", payload))
	data = _high(); _attach_powers(data)
	var breach: Dictionary = _payload(data, "POWER_BREACH"); var seed_payload: Dictionary = _payload(data, "POWER_SEED")
	assert(_open(data) and _power(data, "POWER_BREACH", breach).ok)
	_check("PWR-003", "实际执行占本轮唯一任务；另项权能不可重复用同一人或弱点", Store.entry(data.world.state.npcs, data.leader).acted_turn == data.world.state.turn and _reject_unchanged(data, "POWER_SEED", seed_payload) and Store.has(data.world.state.applied_authorizations, "power/weakness/" + data.source))
func _preparations_and_gifts() -> void:
	var data: Dictionary = _high(); _attach_powers(data)
	var oracle: Dictionary = _payload(data, "POWER_ORACLE"); var breach: Dictionary = _payload(data, "POWER_BREACH")
	var wrong: Dictionary = _payload(data, "POWER_DREAM")
	_seed(data, "POWER_ORACLE", "success", oracle); assert(_open(data) and _power(data, "POWER_ORACLE", oracle).ok)
	var preparation: String = data.world.state.power_system.preparations.keys()[0]
	var plain: Dictionary = data.powers.preview(data.turn, "POWER_BREACH", breach)
	breach.preparations = [preparation]
	var improved: Dictionary = data.powers.preview(data.turn, "POWER_BREACH", breach)
	var duplicate: Dictionary = breach.duplicate(true); duplicate.preparations = [preparation, preparation]
	var duplicate_denied: bool = _reject_unchanged(data, "POWER_BREACH", duplicate)
	wrong.preparations = [preparation]
	var wrong_denied: bool = _reject_unchanged(data, "POWER_DREAM", wrong)
	var snapshot: String = data.turn.snapshot(); var restored: bool = data.turn.restore(snapshot)
	assert(_power(data, "POWER_BREACH", breach).ok)
	_check("PWR-004", "神谕准备仅指定行动加10，重复/错目标拒绝，读档保留且实际尝试唯一消费", restored and snapshot != data.turn.snapshot() and improved.probability == mini(95, int(plain.probability) + 10) and duplicate_denied and wrong_denied and data.world.state.power_system.preparations.is_empty() and Store.has(data.world.state.applied_authorizations, "power/preparation/" + preparation))
	data = _high(); _attach_powers(data); oracle = _payload(data, "POWER_ORACLE"); _seed(data, "POWER_ORACLE", "success", oracle)
	assert(_open(data) and _power(data, "POWER_ORACLE", oracle).ok)
	assert(_evolve(data) and _finish(data) and _round(data) and _open(data))
	_check("PWR-005", "神谕未使用准备于下一轮行动结束后过期，不累积永久加成", data.world.state.power_system.preparations.is_empty())
	data = _high(); _attach_powers(data)
	var gift: Dictionary = _payload(data, "POWER_BESTOW"); _seed(data, "POWER_BESTOW", "success", gift)
	assert(_open(data) and _power(data, "POWER_BESTOW", gift).ok)
	gift.attribute = "will"
	_check("PWR-006", "终生赐予成功后换属性也不得再授，失败分支不预占终生键", Store.has(data.world.state.applied_authorizations, "power/bestow/" + data.leader) and _reject_unchanged(data, "POWER_BESTOW", gift))
func _replay_missing(data: Dictionary, recovered: Dictionary) -> bool:
	var receipts: Array = Store.values(data.turn.context.receipts)
	receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.request.id).trim_prefix("ABS-").to_int() < str(b.request.id).trim_prefix("ABS-").to_int())
	for receipt: Dictionary in receipts:
		if not Store.has(recovered.turn.context.receipts, receipt.request.id) and not recovered.turn.submit(receipt.request).ok: return false
	return recovered.turn.snapshot() == data.turn.snapshot()
func _manifest_lifecycle() -> void:
	var data: Dictionary = _high(); _attach_powers(data)
	var payload: Dictionary = _payload(data, "POWER_MANIFEST"); _seed(data, "POWER_MANIFEST", "success", payload)
	assert(_open(data) and _power(data, "POWER_MANIFEST", payload).ok)
	var token: String = data.world.state.power_system.manifest.token
	var reserved: bool = data.world.state.attention.reservations.has(token)
	var recovered: Dictionary = _high(); _attach_powers(recovered)
	var archive_path: String = scratch.path_join("manifest-" + str(Time.get_ticks_usec()))
	var persisted: bool = data.turn.save_archive(archive_path) and recovered.turn.load_archive(archive_path) and data.turn.snapshot() == recovered.turn.snapshot()
	assert(_evolve(data) and _finish(data) and _open(data))
	assert(_power(data, "POWER_MANIFEST_CONTINUE", {"source": data.source}).ok)
	var same_token: bool = data.world.state.power_system.manifest.token == token
	assert(_evolve(data) and _finish(data) and _open(data))
	assert(_power(data, "POWER_MANIFEST_CONTINUE", {"source": data.source}).ok)
	var locked: int = data.world.state.power_system.manifest.probability
	var before: String = data.turn.snapshot()
	data.fixture.fault = true
	assert(_evolve(data))
	var pre_failure: String = data.turn.snapshot()
	var rolled_back: bool = not _finish(data) and pre_failure == data.turn.snapshot()
	data.fixture.fault = false
	assert(_finish(data))
	var checks: Array = _facts(data.world, "turn_check")
	var complete: bool = checks.size() == 1 and checks[0].changes.probability == locked and checks[0].changes.locked and data.world.state.awakening == 100 and not data.world.state.power_system.completion.is_empty()
	_check("PWR-007", "降临原令牌跨轮/分段存档重放一致；第三轮锁概率、组合故障回滚后唯一终检", reserved and persisted and same_token and rolled_back and complete and _replay_missing(data, recovered) and before != data.turn.snapshot(), {"reserved": reserved, "persisted": persisted, "same_token": same_token, "rolled_back": rolled_back, "complete": complete, "checks": checks, "awakening": data.world.state.awakening})
	assert(_open(recovered))
	var active_snapshot: String = recovered.turn.snapshot()
	var completed_blocks: bool = _reject_unchanged(recovered, "POWER_DREAM", {"npc": recovered.leader, "source": recovered.source})
	_check("PWR-008", "降临达100保留完成事实，后续权能不能越过待消费结果；终局优先级仍归ENDINGS", completed_blocks and not recovered.turn.context.get("outcome", "") == "awakening" and active_snapshot == recovered.turn.snapshot())
	for cancel: bool in [false, true]:
		data = _high(); _attach_powers(data); payload = _payload(data, "POWER_MANIFEST")
		assert(_open(data))
		var faith: int = data.world.state.faith
		assert(_power(data, "POWER_MANIFEST", payload).ok)
		var paid: bool = data.world.state.faith == faith - 20
		if cancel:
			assert(_power(data, "POWER_MANIFEST_CANCEL", {"source": data.source}).ok)
		else:
			assert(_evolve(data) and _finish(data) and _open(data) and _evolve(data) and _finish(data))
		_check("PWR-009" if cancel else "PWR-010", "主动取消/漏付中断不返费用不投骰，释放未来预留", paid and data.world.state.power_system.manifest.is_empty() and data.world.state.attention.reservations.is_empty() and _facts(data.world, "turn_check").is_empty() and not _facts(data.world, "manifest_interrupted").is_empty())
	data = _high(); _attach_powers(data); payload = _payload(data, "POWER_MANIFEST")
	assert(_open(data) and _power(data, "POWER_MANIFEST", payload).ok)
	var saved: String = data.turn.snapshot()
	var envelope: Dictionary = JSON.parse_string(saved); var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
	world_envelope.body.state.attention.reservations.erase(data.world.state.power_system.manifest.token)
	_check("PWR-011", "正确校验和也不接收失去仪式未来容量令牌的坏档", not data.turn.restore(_rewrap_turn(envelope, world_envelope)) and data.turn.snapshot() == saved)
func _attention_boundaries() -> void:
	var data: Dictionary = _high(); _attach_powers(data); var payload: Dictionary = _payload(data, "POWER_DREAM")
	assert(_open(data) and _control(data, {"kind": "release_focus", "domain": "DOMAIN-001"}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	for domain: String in ["DOMAIN-002", "DOMAIN-003", "DOMAIN-004"]: assert(_control(data, {"kind": "focus", "domain": domain}).ok)
	_check("PWR-012", "真实权能F已满且目标未关注，扣费/骰/效果之前整体拒绝", _reject_unchanged(data, "POWER_DREAM", payload))
	data = _high(true)
	var extras: Array = _extra(data.world, 3)
	_bind(data.world, extras[0]); _bind(data.world, extras[1])
	_dedicate(data.world, extras[2])
	_attach_powers(data); payload = _payload(data, "POWER_ANCHOR")
	payload.npc = extras[2]
	payload.qualification = _qualification(data, "anchor", payload.institution, payload.npc, "DOMAIN-001", {"institution": payload.institution, "sources": [data.source]}, payload.institution)
	assert(_open(data))
	_check("PWR-013", "锚定成功分支需新N时按全分支先预留，N满不能先扣费或骰失败档", not Store.entry(data.world.state.npcs, payload.npc).bound_member and _reject_unchanged(data, "POWER_ANCHOR", payload))
func _sacrifice_modes() -> void:
	for mode: String in ["heal", "insight"]:
		var data: Dictionary = _high()
		# Given wounds/insight are explicit initial world conditions, not results.
		data.world.state.wounds = 10
		data.world.state.insight = 10; data.world._refresh_anchors()
		_attach_powers(data)
		var payload: Dictionary = _payload(data, "POWER_SACRIFICE"); payload.mode = mode
		if mode == "insight": payload.witness = _qualification(data, "witness", payload.npc, payload.npc, "DOMAIN-001", {"source": data.source})
		_seed(data, "POWER_SACRIFICE", "success", payload)
		assert(_round(data) and _round(data) and _open(data))
		var before: int = data.world.state.wounds if mode == "heal" else data.world.state.insight
		var faith: int = data.world.state.faith
		assert(_power(data, "POWER_SACRIFICE", payload).ok)
		var after: int = data.world.state.wounds if mode == "heal" else data.world.state.insight
		_check("PWR-014/" + mode, "正式献祭只结算所选模式、见证一次消费且无额外信仰收益 " + mode, after == (maxi(0, before - 6) if mode == "heal" else mini(20, before + 1)) and data.world.state.faith == faith and Store.entry(data.world.state.npcs, payload.npc).status == "dead")

func _power_projection_and_corruption() -> void:
	var data: Dictionary = _high()
	var people: Array = _extra(data.world, 13)
	for person: String in people: _dedicate(data.world, person)
	var held: Dictionary = data.world.attention.reserve(data.world, {"focus": [], "people": people.slice(0, 12 - data.world.attention.occupied(data.world.state, "people").size()), "members": [], "identities": [], "source": data.source}, true)
	assert(held.ok)
	_attach_powers(data)
	var payload: Dictionary = {"npc": people[12], "source": data.source, "qualification": _qualification(data, "dream", people[12], people[12], "DOMAIN-001", {"contact": Store.entry(data.world.state.npcs, people[12]).dedication_source})}
	assert(_open(data))
	_check("PWR-015", "真实入梦新增互动主体受P满额限制，已有工程保留且付费骰前拒绝", _reject_unchanged(data, "POWER_DREAM", payload) and data.world.state.attention.reservations.has(held.token))
	data = _high(); _attach_powers(data); payload = _payload(data, "POWER_ORACLE"); _seed(data, "POWER_ORACLE", "success", payload)
	assert(_open(data) and _power(data, "POWER_ORACLE", payload).ok)
	var saved: String = data.turn.snapshot(); var envelope: Dictionary = JSON.parse_string(saved); var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
	var prepared: String = world_envelope.body.state.power_system.preparations.keys()[0]
	world_envelope.body.state.power_system.preparations[prepared].amount = 999
	var bad: bool = not data.turn.restore(_rewrap_turn(envelope, world_envelope)) and data.turn.snapshot() == saved
	_check("PWR-016", "准备金额伪造即使重算校验和也拒绝，原会话完整保留", bad)
	data = _high(); _attach_powers(data); payload = _payload(data, "POWER_DREAM"); _seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data) and _power(data, "POWER_DREAM", payload).ok)
	var changed: int = data.world.state.domains["DOMAIN-001"].pollution_changed_turn
	var exposed: int = data.world.state.domains["DOMAIN-001"].exposure_turn
	_check("PWR-017", "实际正污染/暴露保留本轮标记并进入既有文明反馈；不被当静默回落", changed == data.world.state.turn and exposed == data.world.state.turn)

func _anchor_repair_and_detention() -> void:
	var data: Dictionary = _high(true); _attach_powers(data)
	var payload: Dictionary = _payload(data, "POWER_ANCHOR")
	_seed(data, "POWER_ANCHOR", "success", payload)
	assert(_open(data) and _power(data, "POWER_ANCHOR", payload).ok)
	var id: String = "ANCHOR/" + payload.institution
	var origin: String = data.world.state.anchors[id].origin
	var ordinal: int = data.world.state.anchors[id].ordinal
	var count: int = data.world.state.anchors.size()
	var insight: int = data.world.state.insight
	assert(_submit(data, "act", {"participant": "relics", "action": "relic_unbind", "payload": {"source": data.source, "relic": payload.relic}}).ok)
	assert(_evolve(data) and _finish(data) and _open(data))
	var denied: bool = _reject_unchanged(data, "POWER_ANCHOR", payload)
	assert(_evolve(data) and _finish(data) and _open(data))
	# Any real result is acceptable on repair attempt; only successful outcomes
	# may bind. The structure's identity and ordinal must survive all outcomes.
	var attempted: bool = _power(data, "POWER_ANCHOR", payload).ok
	var repaired: Dictionary = data.world.state.anchors[id]
	_check("PWR-018", "解绑不免费恢复；同机构冷却后修复保留ID/序号/origin，不重复历史奖励", denied and attempted and repaired.origin == origin and repaired.ordinal == ordinal and data.world.state.anchors.size() == count and data.world.state.insight == insight and data.world.validate_state(data.world.state).is_empty())
	data = _high(); _attach_powers(data); payload = _payload(data, "POWER_TRANSFER"); _seed(data, "POWER_TRANSFER", "disaster", payload)
	assert(_open(data) and _power(data, "POWER_TRANSFER", payload).ok)
	var states: Array = [Store.entry(data.world.state.npcs, payload.npc).status]
	for i: int in 3:
		assert(_evolve(data) and _finish(data) and _open(data)); states.append(Store.entry(data.world.state.npcs, payload.npc).status)
	_check("PWR-019", "迁引灾变拘禁后续两完整轮，按原状态来源恢复，不复制身份或提前复职", states == ["detained", "detained", "detained", "active"] and Store.entry(data.world.state.npcs, payload.npc).domain == "DOMAIN-001" and data.world.state.power_system.detentions.is_empty(), {"states": states})

func _catalog_contracts() -> void:
	var cases: Array = []
	for variant: int in 4:
		var directory: String = scratch.path_join("bad-content-" + str(variant) + "-" + str(Time.get_ticks_usec()))
		DirAccess.make_dir_recursive_absolute(directory)
		for table: String in Catalog.FILES + Catalog.EXTENSIONS:
			var text: String = FileAccess.get_file_as_string("res://data/" + table + ".csv")
			if variant == 0 and table == "power_effects": text = text.replace("delta,actor,loyalty,15,", "delta,actor,unknown,15,")
			if variant == 1 and table == "relic_effects": text = text.replace("holder,sanity,-2,3", "unowned,sanity,-2,3")
			if variant == 2 and table == "relic_effects": text = text.replace(text.split("\n")[1] + "\n", "")
			if variant == 3 and table == "relics": text = text.replace(",8,1,4,1,", ",-8,1,4,1,")
			var file: FileAccess = FileAccess.open(directory.path_join(table + ".csv"), FileAccess.WRITE); file.store_string(text); file.close()
		var content: RefCounted = Catalog.new(); assert(content.load_files())
		var version: String = content.version; var ext: Dictionary = content.extension_versions.duplicate(true)
		cases.append(not content.load_files(directory) and content.version == version and content.extension_versions == ext)
	_check("PWR-020", "新机器表未知字段/无代价主体/缺圣物映射/负转化值原子拒绝，旧目录不被替换", not false in cases, {"cases": cases})

func _evidence_economy_projection() -> void:
	var data: Dictionary = _high()
	assert(data.world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": data.cult, "institution": "DOMAIN-001/propagation", "allowed": true, "issuer": "cult-fixture", "version": "1", "parents": [data.source]}))
	var benefit: String = data.world.state.economy_qualifications["propagation|" + data.cult]
	_attach_powers(data)
	var payload: Dictionary = {"npc": data.leader, "source": data.source, "qualification": _qualification(data, "evidence", data.cult, data.leader, "DOMAIN-001", {"source": data.source, "benefits": [benefit]})}
	_seed(data, "POWER_VEIL", "failure", payload)
	assert(_open(data))
	var plan: Dictionary = {"strategies": {data.cult: "expand"}}
	var before: Dictionary = data.turn.preview_plan("economy", plan)
	assert(_power(data, "POWER_VEIL", payload).ok)
	var after: Dictionary = data.turn.preview_plan("economy", plan)
	var prior: Dictionary = {}; var current: Dictionary = {}
	if before.ok:
		for cult: Dictionary in before.preview.cults:
			if cult.cult == data.cult: prior = cult
	if after.ok:
		for cult: Dictionary in after.preview.cults:
			if cult.cult == data.cult: current = cult
	_check("PWR-021", "掩迹即使检定失败也撤销真实传播收益；受限经济预览准确降为守持、不删历史", before.ok and after.ok and prior.get("effective") == "expand" and current.get("effective") == "hold" and current.get("reason") == "propagation_evidence_destroyed" and current.get("fee") == 0 and Store.has(data.world.state.facts, benefit) and Store.has(data.world.state.invalid_records, benefit), {"before": prior, "after": current})
