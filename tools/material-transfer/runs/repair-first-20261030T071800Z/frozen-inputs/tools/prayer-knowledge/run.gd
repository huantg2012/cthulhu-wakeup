extends "res://tools/prayers/run.gd"
const Knowledge = preload("res://src/game/prayer_knowledge.gd")

class KnowledgeRejectWorld extends "res://src/simulation/world.gd":
	var reject_knowledge: bool = false
	var qa_calls: Array = []
	var qa_call_results: Array = []
	var qa_snapshot: Dictionary = {}
	var qa_call_marker: String = ""
	var qa_add_marker: bool = false
	var qa_notice: Dictionary = {}
	var qa_notice_result: Dictionary = {}
	var qa_notice_late_relation: bool = false
	var qa_notice_bad_coordinator: bool = false
	# Explicit consumer instrumentation at a real managed evolution boundary.
	# This is not an implementation or reachability claim for ORIGINS scheduling.
	func evolve(owner: Object = null, economic_batch: Dictionary = {}) -> Array:
		qa_snapshot = Knowledge.capture(self, owner)
		var result: Array = super.evolve(owner, economic_batch)
		qa_call_results = []
		if qa_add_marker:
			qa_call_marker = _record("message", "DOMAIN-001", "", [], [state.domains["DOMAIN-001"].origin], {"fixture": "same_batch_unrelated_record"})
		for descriptor: Dictionary in qa_calls:
			qa_call_results.append(Knowledge.create_call(self, descriptor, qa_snapshot, owner))
		qa_notice_result = {}
		if not qa_notice.is_empty():
			var selection: Dictionary = qa_notice.duplicate(true)
			selection["snapshot"] = qa_snapshot.duplicate(true)
			var tick: int = int(transaction.base_state.simulation.cursors[selection.domain].next_turn)
			selection["once"] = "ROOT_IDENTITY_NOTICE/" + selection.domain + "/" + str(tick) + "/0"
			if not selection.has("knowledge"):
				selection["knowledge"] = Knowledge.known(state, selection.sender, qa_snapshot).get("source", "")
			if qa_notice_late_relation:
				var relation: String = _record("relationship", selection.domain, selection.sender, [selection.sender, selection.recipient], [state.domains[selection.domain].origin], {"type": "support", "fixture": "relation_created_after_frozen_snapshot"})
				add_relation(selection.sender, selection.recipient, "support", relation)
				add_relation(selection.recipient, selection.sender, "support", relation)
				selection.relation = relation
			var coordinator: Object = owner._participants.events.instance if owner._participants.has("events") else null
			if qa_notice_bad_coordinator:
				coordinator = owner
			var authorization: Dictionary = Knowledge.authorize_notice(self, selection, coordinator, owner)
			qa_notice_result = {"authorization": authorization, "selection": selection}
			if authorization.get("ok", false):
				qa_notice_result["tell"] = Knowledge.tell(self, authorization.authorization, owner)
				qa_notice_result["retry"] = Knowledge.tell(self, authorization.authorization, owner)
		return result
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_knowledge and candidate.has("prayer_knowledge") and not candidate.prayer_knowledge.heads.is_empty() and trusted.get("prayer_knowledge", {}).get("heads", {}).is_empty():
			issues.append("Injected knowledge publication failure")
		return issues

var qa_seed_override: int = -1

func _new_hybrid(seed_value: int = 7919) -> RefCounted:
	var world: RefCounted = KnowledgeRejectWorld.new(catalog)
	assert(world.generate_hybrid(seed_value if qa_seed_override < 0 else qa_seed_override))
	return world

# Only source prerequisites are fixtures. Knowledge must come from real behavior.
func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PK-CATALOG", "Formal current Catalog loads", loaded, {"errors": catalog.errors})
	if not loaded:
		_write_knowledge_report()
		return
	scratch = ProjectSettings.globalize_path("res://.godot/prayer-knowledge/" + OS.get_cmdline_user_args()[0].get_base_dir().get_file() + "/archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	for power: String in ["POWER_DREAM", "POWER_ORACLE"]:
		for outcome: String in ["deep", "success", "failure", "disaster"]:
			_knowledge_power(power, outcome)
		_knowledge_preview(power)
	for variant: String in ["shallow", "deep"]:
		for outcome: String in ["deep", "success", "failure", "disaster"]:
			_knowledge_devotion(variant, outcome)
	_knowledge_legacy()
	_knowledge_nonfollower()
	_knowledge_identity_replay()
	_knowledge_transaction_failure()
	if has_method("run_knowledge_source_cases"):
		call("run_knowledge_source_cases")
	_write_knowledge_report()

func _write_knowledge_report() -> void:
	var passed: bool = true
	for row: Dictionary in records:
		passed = passed and row.status == "pass"
	var result: Dictionary = {"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "executionScope": "prayer_knowledge_modules", "limitations": ["Prepared high-tier worlds and contact facts are explicit prerequisites, not natural root production.", "This suite does not implement or prove detailed/background scheduling, full Session restore, natural reachability, or balance."]}
	var output: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write fresh prayer knowledge result")
		quit(2)
		return
	output.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	output.close()
	quit(0 if passed else 1)

func _identity_facts(world: RefCounted, person: String = "") -> Array:
	var result: Array = []
	for kind: String in ["deity_identified", "deity_identity_received"]:
		for fact: Dictionary in _facts(world, kind):
			if person.is_empty() or fact.changes.get("person") == person:
				result.append(fact)
	return result

func _knowledge_power(power: String, outcome: String) -> void:
	var data: Dictionary = _high()
	_attach_prayers(data)
	var payload: Dictionary = _payload(data, power)
	var seeded: int = _seed(data, power, outcome, payload)
	assert(_open(data))
	var before: Array = _identity_facts(data.world)
	var cutoff: Dictionary = {"turn": data.world.state.turn, "phase": 4, "commit_seq": data.turn.commit_sequence, "fact_cutoff": int(data.world.state.next_fact) - 1}
	var response: Dictionary = _power(data, power, payload)
	var added: Array = _identity_facts(data.world).filter(func(fact: Dictionary) -> bool: return not fact in before)
	var results: Array = _facts(data.world, "power_result")
	var actual: String = results[-1].changes.get("outcome", "") if not results.is_empty() else "missing"
	var success: bool = outcome in ["deep", "success"]
	var valid: bool = seeded > 0 and response.ok and actual == outcome and added.size() == (1 if success else 0)
	if success and added.size() == 1:
		var knowledge: Dictionary = added[0]
		valid = valid and knowledge.kind == "deity_identified" and knowledge.changes.get("person") == payload.npc and not str(knowledge.changes.get("identity", "")).is_empty() and knowledge.changes.get("acquired_turn") == data.world.state.turn and knowledge.changes.get("source") == results[-1].id and results[-1].id in knowledge.causal_parents
		var current: Dictionary = Knowledge.known(data.world.state, payload.npc)
		var earlier: Dictionary = Knowledge.known(data.world.state, payload.npc, cutoff)
		valid = valid and current.get("known", false) and current.get("source") == knowledge.id and not earlier.get("known", false)
	_check("PK-POWER/" + power + "/" + outcome, "Real power outcome grants only the original recipient on success", valid, {"response": response, "actual": actual, "seed": seeded, "added": added, "result": results[-1] if not results.is_empty() else {}})

func _knowledge_preview(power: String) -> void:
	var data: Dictionary = _high()
	_attach_prayers(data)
	var payload: Dictionary = _payload(data, power)
	assert(_open(data))
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.powers.preview(data.turn, power, payload)
	_check("PK-PREVIEW/" + power, "Canceled pure preview does not identify the deity", preview.ok and before == data.turn.snapshot() and _identity_facts(data.world).is_empty(), {"preview": preview})

func _knowledge_devotion(variant: String, outcome: String) -> void:
	var data: Dictionary = _prayer_case("PRAYER_08")
	var seeded: int = _choose_prayer_seed(data, outcome, data.petitioner, data.domain)
	assert(_open(data))
	var before: Array = _identity_facts(data.world)
	var unbound: bool = not Store.entry(data.world.state.npcs, data.petitioner).get("bound_member", false)
	var response: Dictionary = _response(data, data.request, variant)
	var added: Array = _identity_facts(data.world).filter(func(fact: Dictionary) -> bool: return not fact in before)
	var results: Array = _facts(data.world, "prayer_result")
	var actual: String = results[-1].changes.get("outcome", "") if not results.is_empty() else "missing"
	var success: bool = outcome in ["deep", "success"]
	var member: bool = Store.entry(data.world.state.npcs, data.petitioner).get("bound_member", false)
	var valid: bool = seeded > 0 and unbound and before.is_empty() and response.ok and actual == outcome and member == success and added.size() == (1 if success else 0)
	if success and added.size() == 1:
		valid = valid and added[0].changes.get("person") == data.petitioner and added[0].changes.get("source") == results[-1].id and results[-1].id in added[0].causal_parents
	_check("PK-DEVOTION/" + variant + "/" + outcome, "Actual PR08 member conversion grants identity only on successful acceptance", valid, {"response": response, "actual": actual, "member": member, "added": added})

func _knowledge_legacy() -> void:
	var data: Dictionary = _high()
	var world: RefCounted = data.world
	var person: String = data.leader
	var origin: String = world.state.domains["DOMAIN-001"].origin
	# Explicit negative fixtures: a same-named result without a real attempt,
	# result-owned recognition signal or knowledge acquisition cannot confer identity.
	var legacy: String = world._record("power_result", "DOMAIN-001", person, [person], [origin], {"power": "POWER_DREAM", "outcome": "success"})
	world._know(person, legacy)
	var anomaly: String = world._record("miracle", "DOMAIN-001", person, [person], [origin], {"power": "POWER_DREAM", "public": false})
	world._know(person, anomaly)
	_attach_prayers(data)
	_check("PK-NO-RETROACTIVE", "Old success and anomaly labels do not backfill deity identity", _identity_facts(world).is_empty(), {"legacy": legacy, "anomaly": anomaly})

func _knowledge_nonfollower() -> void:
	var data: Dictionary = _high()
	var world: RefCounted = data.world
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-001"].origin))
	world.mutable_npc(person).loyalty = 0
	data.domain = "DOMAIN-001"
	var contact: String = _given_fact(data, "devotion_contact", person, [person], {"subject": person, "institution": "DOMAIN-001/interpretation"})
	_attach_prayers(data)
	var proof: String = _qualification(data, "dream", person, person, "DOMAIN-001", {"contact": contact})
	var payload: Dictionary = {"npc": person, "source": contact, "qualification": proof}
	_seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data))
	var response: Dictionary = _power(data, "POWER_DREAM", payload)
	var current: Dictionary = Knowledge.known(world.state, person)
	var npc: Dictionary = Store.entry(world.state.npcs, person)
	_check("PK-NONFOLLOWER", "Actual dream recipient can identify the deity while unbound and below belief threshold", response.ok and current.get("known", false) and not npc.get("bound_member", false) and npc.loyalty < catalog.integer("loyalty_follower_threshold"), {"response": response, "knowledge": current, "loyalty": npc.loyalty, "member": npc.get("bound_member", false)})

func _knowledge_identity_replay() -> void:
	var identities: Array = []
	var pure: bool = true
	for seed_value: int in [7919, 7919, 42]:
		var world: RefCounted = World.new(catalog)
		assert(world.generate_hybrid(seed_value))
		var before: Array = [str(world.randoms.checks.state), str(world.randoms.events.state)]
		assert(Knowledge.install(world))
		identities.append(world.state.prayer_knowledge.identity)
		pure = pure and before == [str(world.randoms.checks.state), str(world.randoms.events.state)]
	_check("PK-IDENTITY-REPLAY", "Same world replay has identical deity identity and installation does not advance checks/events RNG", pure and identities[0] == identities[1] and identities[0] != identities[2], {"identities": identities, "rngUnchanged": pure})

func _knowledge_transaction_failure() -> void:
	var data: Dictionary = _high()
	_attach_prayers(data)
	var payload: Dictionary = _payload(data, "POWER_DREAM")
	_seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data))
	data.world.reject_knowledge = true
	var before: String = data.turn.snapshot()
	var denied: Dictionary = _power(data, "POWER_DREAM", payload)
	var rolled_back: bool = not denied.ok and before == data.turn.snapshot() and _identity_facts(data.world).is_empty() and not Knowledge.known(data.world.state, payload.npc).get("known", false)
	data.world.reject_knowledge = false
	var retried: Dictionary = _power(data, "POWER_DREAM", payload)
	_check("PK-ROLLBACK-ACQUISITION", "Publication failure rolls back real successful recognition, payment, RNG and permits a single clean retry", rolled_back and retried.ok and _identity_facts(data.world, payload.npc).size() == 1, {"rejected": denied, "fullyRolledBack": rolled_back, "retry": retried})
