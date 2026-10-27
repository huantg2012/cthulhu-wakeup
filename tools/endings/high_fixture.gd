extends "res://tools/endings/run.gd"

# Explicit preexisting midgame, not an assertion that this suite played through
# nine anchor establishments. Every institution carries its finite source graph;
# no manifestation step, final check, completion or terminal state is supplied.
var ending_fixture_seed: int = -1

func _ending_initial_world() -> RefCounted:
	for candidate: int in ([ending_fixture_seed] if ending_fixture_seed >= 0 else range(1, 257)):
		var world: RefCounted = _new_hybrid(candidate)
		if world.state.domains["DOMAIN-001"].profile == "CIV_03" and world.state.domains["DOMAIN-007"].profile == "CIV_06" and world.state.domains["DOMAIN-011"].profile == "CIV_08":
			ending_fixture_seed = candidate
			return world
	assert(false, "No bounded generated initial world for the disclosed midgame")
	return null

func _ending_prayer_record(world: RefCounted, institution: String, actor: String, prayer: String, subjects: Dictionary, facts: Dictionary, outputs: Array) -> Array:
	var domain: String = world.state.institutions[institution].domain
	var origin: String = world.state.domains[domain].origin
	var request: String = "INITIAL/" + institution
	var payment: String = world._record("turn_action", domain, "", [], [origin], {"outcome": "prayer_attempt", "faith_cost": catalog.integer("prayer_deep_faith"), "whispers_cost": catalog.integer("prayer_deep_whispers"), "fixture": "preexisting_paid_prayer"})
	var descriptor: Dictionary = {"content_id": prayer, "institution": institution, "domain": domain, "source": origin, "subjects": subjects, "facts": facts}
	var attempt: String = world._record("prayer_attempt", domain, actor, [actor], [origin, payment], {"request": request, "variant": "deep", "actor": actor, "descriptor": descriptor, "p": 50, "probability": 50, "preparations": [], "payment": payment})
	var checked: String = world._record("turn_check", domain, actor, [actor], [attempt], {"probability": 50, "roll": 1, "outcome": "deep", "snapshot_before_always": true})
	var records: Array = []
	for output: Dictionary in outputs:
		var changes: Dictionary = {"prayer": prayer, "request": request, "institution": institution, "subjects": subjects, "facts": facts, "tag": output.tag}
		changes.merge(output.get("extra", {}))
		var source: String = world._record("prayer_fact", domain, actor, output.targets, [checked], changes)
		world._institution_know(institution, source)
		for person: String in output.targets: world._know(person, source)
		records.append(source)
	return records

func _ending_basis(world: RefCounted, institution: String, people: Array) -> Dictionary:
	var domain: String = world.state.institutions[institution].domain
	var origin: String = world.state.domains[domain].origin
	var profile: String = world.state.domains[domain].profile
	var actor: String = world.state.institutions[institution].representative
	if profile in ["CIV_03", "CIV_08"]:
		var memory: String = world._record("message", domain, actor, people, [origin], {"fixture": "preexisting_shared_memory"})
		var original: String = world._record("memory_at_risk", domain, actor, people, [memory], {"memory": memory, "holders": people, "due": 0})
		var outputs: Array = []
		for person: String in people:
			world._know(person, memory)
			outputs.append({"tag": "memory_preserved", "targets": [person], "extra": {"memory": memory, "original": original}})
		var sources: Array = _ending_prayer_record(world, institution, actor, "PRAYER_07", {"petitioner": actor, "memory_people": people}, {"memory": original}, outputs)
		for position: int in people.size(): Store.put(world.state.applied_authorizations, "prayer/memory/" + original + "/" + people[position], sources[position])
		return {"memory": memory, "witnesses": people.duplicate(), "qualifications": sources}
	var other: String = people[0] if actor != people[0] else people[1]
	var obligation: String = world._record("contract_obligation", domain, actor, [actor, other], [origin], {"obligor": actor, "counterparty": other, "institution": institution, "due": 0})
	var sources: Array = _ending_prayer_record(world, institution, actor, "PRAYER_06", {"petitioner": actor, "counterparty": other}, {"contract": obligation}, [{"tag": "contract_dependency", "targets": [actor, other]}, {"tag": "contract_fulfilled", "targets": [actor]}, {"tag": "contract_learned", "targets": [other]}])
	return {"contract": obligation, "dependency": sources[0], "witnesses": sources.slice(1)}

func _high_endings(_outcome: String = "success") -> Dictionary:
	var world: RefCounted = _ending_initial_world()
	for person: Dictionary in Store.values(world.state.npcs): world.mutable_npc(person.id).loyalty = 0
	var economy: RefCounted = Economy.new(catalog, _event_issuers()); assert(economy.initialize(world))
	var data: Dictionary = {"world": world, "economy": economy, "guardians": {}, "anchors": {}, "initial_seed": ending_fixture_seed}
	var bindings: Dictionary = {}; var proofs: Dictionary = {}; var cooldowns: Dictionary = {}; var opportunities: Dictionary = {}
	for domain: String in ["DOMAIN-001", "DOMAIN-007", "DOMAIN-011"]:
		var origin: String = world.state.domains[domain].origin
		var people: Array = []
		for position: int in 3:
			var institution: String = domain + "/" + ["interpretation", "propagation", "order"][position]
			var person: String = _local_person(world, domain, institution, ["NPC_PROFILE_01", "NPC_PROFILE_03", "NPC_PROFILE_05"][position])
			people.append(person)
			var succession: String = world.introduce_fact("institution_succession_authorized", domain, person, [institution, person], [origin], {"fixture": "preexisting_lawful_representative"}, [])
			assert(not succession.is_empty() and world.succeed_institution(institution, person, succession))
		data.guardians[domain] = people
		assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
		var cult: String = "CULT/" + domain
		var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, people[0], [people[0]], [origin], {"issuer": "cult-fixture", "version": "1", "cult": cult, "domain": domain, "leader": people[0], "cohesion": 100}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
		world.state.domains[domain].pollution = 95; world.state.domains[domain].barrier = 0; world.state.domains[domain].alert = 0
		for position: int in 3:
			var institution: String = domain + "/" + ["interpretation", "propagation", "order"][position]
			var basis: Dictionary = _ending_basis(world, institution, people)
			var row: Dictionary = catalog.tables.anchor_conditions[world.state.domains[domain].profile]
			var contract: Dictionary = {"issuer": "cult-fixture", "version": "1", "event": row.event_id, "option": row.event_option, "institution": institution, "basis": basis}
			var proof: String = world._record("institution_event_result", domain, people[position], [institution] + people, _basis_parents(basis), contract)
			world._institution_know(institution, proof)
			var recognition: String = world._record("institution_recognized", domain, "", [institution], [proof], {"institution": institution, "proof": proof, "profile": world.state.domains[domain].profile, "contract": contract})
			Store.put(world.state.applied_authorizations, "anchor/recognition/" + institution, recognition)
			var pool: PackedStringArray = str(catalog.tables.civilization_conditions[world.state.domains[domain].profile].relic_pool).split("|")
			var type: String = pool[world.randoms.events.randi_range(0, pool.size() - 1)]
			opportunities[institution] = world._record("institution_relic_opportunity", domain, "", [institution], [recognition, proof], {"institution": institution, "recognition": recognition, "proof": proof, "relic_type": type, "created_turn": 0, "due": catalog.integer("relic_opportunity_lifetime") - 1})
			var id: String = "ANCHOR/" + institution
			var relic: String = _given_relic(world, domain)
			var payload: Dictionary = {"npc": people[position], "institution": institution, "relic": relic, "source": proof, "qualification": proof}
			var permission: Dictionary = {"source": proof, "issuer": "cult-fixture", "version": "1", "institution": institution, "basis": basis}
			var payment: String = world._record("turn_action", domain, "", [id], [proof], {"outcome": "power_attempt", "faith_cost": int(catalog.tables.powers.POWER_ANCHOR.faith), "whispers_cost": int(catalog.tables.powers.POWER_ANCHOR.whispers), "fixture": "preexisting_paid_anchor"})
			var attempt: String = world._record("power_attempt", domain, people[position], [people[position]], [proof, payment], {"power": "POWER_ANCHOR", "payload": payload, "probability": 50, "preparations": [], "payment": payment, "proofs": {"anchor": permission}, "cult": cult})
			var checked: String = world._record("turn_check", domain, people[position], [people[position]], [attempt], {"probability": 50, "roll": 1, "outcome": "deep", "snapshot_before_always": true})
			world.state.anchors[id] = {"id": id, "domain": domain, "institution": institution, "guardian": people[position], "relic": relic, "state": "dormant", "needs_rebind": false, "origin": world.state.cults[cult].established_source, "established_source": checked, "ordinal": position + 1, "cult": cult}
			assert(Relics.new(catalog, _event_issuers()).bind(world, relic, id, checked, null))
			var bound: String = world._record("anchor_institution_bound", domain, people[position], [id, institution], [checked, proof], {"anchor": id, "institution": institution, "proof": proof, "contract": contract})
			bindings[id] = {"proof": proof, "source": bound}; proofs[institution] = proof
			cooldowns["POWER_ANCHOR/" + institution] = {"until": int(catalog.tables.powers.POWER_ANCHOR.cooldown_turns), "source": checked}
			data.anchors[institution] = id
	world.state.insight = catalog.integer("insight_cap"); world.state.faith = 80
	world.attention.sync(world); world.history.rebuild(world.state)
	data.source = world.state.domains["DOMAIN-001"].origin; data.leader = data.guardians["DOMAIN-001"][0]; data.cult = "CULT/DOMAIN-001"
	var ids: Dictionary = data.anchors.duplicate()
	_attach_prayers(data)
	world.state.anchor_system.proofs = proofs; world.state.anchor_system.bindings = bindings
	world.state.anchor_system.opportunities = opportunities
	world.state.power_system.cooldowns = cooldowns
	for id: String in world.state.anchors: world.state.anchors[id].state = "active"
	world.history.rebuild(world.state); world._refresh_anchors(); world.attention.sync(world)
	data.anchors = ids
	data.cosmic_anchor = ids["DOMAIN-011/interpretation"]; data.system_anchor = ids["DOMAIN-007/interpretation"]; data.actor = data.guardians["DOMAIN-011"][0]
	data.manifest_payload = {"npc": data.actor, "source": data.source, "cosmic_anchor": data.cosmic_anchor, "system_anchor": data.system_anchor}
	assert(world.state.awakening >= int(catalog.tables.powers.POWER_MANIFEST.unlock_awakening), "Disclosed initial institutions must supply real awakening")
	assert(Anchors.validate_state(world.state, catalog, {}, world.history).is_empty(), str(Anchors.validate_state(world.state, catalog, {}, world.history)))
	assert(world.validate_state(world.state).is_empty(), str(world.validate_state(world.state)))
	return data

func _ending_high() -> Dictionary:
	return _high_endings()
