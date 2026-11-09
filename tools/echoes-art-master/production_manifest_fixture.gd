extends "res://tools/endings/high_fixture.gd"
## Controlled prerequisites for UI manifestation verification, never a natural campaign claim.
## Reuses the existing high fixture's finite source graph, current birth admission and
## current material rules. No manifestation step/payment, final check or outcome is supplied.
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")
const PlayerSources = preload("res://src/game/player_sources.gd")
const Progression = preload("res://src/game/progression_routes.gd")
const Opportunities = preload("res://src/game/opportunity_service.gd")
const FixtureKnowledge = preload("res://src/game/player_knowledge.gd")
const PlayerSession = preload("res://src/presentation/session.gd")

func _initialize() -> void:
	push_error("Use production_manifest_probe.gd to build and verify the isolated Session save")
	quit(1)

func _ending_initial_world() -> RefCounted:
	for candidate: int in range(1, 257):
		var world: RefCounted = Support.CompatibleWorld.new(catalog)
		assert(world.generate_hybrid(candidate))
		if world.state.domains["DOMAIN-001"].profile == "CIV_03" and world.state.domains["DOMAIN-007"].profile == "CIV_06" and world.state.domains["DOMAIN-011"].profile == "CIV_08":
			ending_fixture_seed = candidate
			return world
	assert(false, "No generated profile match in the declared finite seed range")
	return null

func _install_session_modules(data: Dictionary, accepted: Dictionary) -> void:
	data.turn = Turn.new(data.world); assert(data.turn._attached, data.turn.last_error)
	data.economy = Economy.new(catalog, accepted)
	data.cults = Cults.new(catalog); data.relics = Relics.new(catalog, accepted); data.powers = Powers.new(catalog, accepted)
	data.prayers = Prayers.new(catalog, accepted); data.anchors = Anchors.new(catalog, accepted); data.events = Events.new(catalog)
	data.resistance = Resistance.new(catalog); data.endings = Endings.new(catalog); data.player_sources = PlayerSources.new(catalog); data.progression_routes = Progression.new(catalog)
	for key: String in ["economy", "cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources", "progression_routes"]:
		assert(data[key].install(data.turn), key)
	assert(Opportunities.install(data.turn))

func _ending_basis(world: RefCounted, institution: String, people: Array) -> Dictionary:
	var domain: String = world.state.institutions[institution].domain
	var origin: String = world.state.domains[domain].origin
	var profile: String = world.state.domains[domain].profile
	var actor: String = world.state.institutions[institution].representative
	if profile in ["CIV_03", "CIV_08"]:
		var memory: String = world._record("shared_observation", domain, "", people, [origin], {"participants": people, "institution": institution, "fixture": "controlled_existing_memory"})
		var original: String = world._record("memory_at_risk", domain, actor, people, [memory], {"memory": memory, "holders": people, "due": 0, "scene_rule": "ROOT_MEMORY_REVIEW"})
		var outputs: Array = []
		for person: String in people:
			world._know(person, memory)
			outputs.append({"tag": "memory_preserved", "targets": [person], "extra": {"memory": memory, "original": original}})
		var sources: Array = _ending_prayer_record(world, institution, actor, "PRAYER_07", {"petitioner": actor, "memory_people": people}, {"memory": original}, outputs)
		for position: int in people.size(): Store.put(world.state.applied_authorizations, "prayer/memory/" + original + "/" + people[position], sources[position])
		var basis: Dictionary = {"route": "memory_circle" if profile == "CIV_03" else "dissent_circle", "memory": memory, "review": original, "witnesses": people.duplicate(), "qualifications": sources}
		if profile == "CIV_08":
			var conflicts: Array = _ending_prayer_record(world, institution, actor, "PRAYER_07", {"petitioner": actor, "memory_people": people}, {"memory": original}, [{"tag": "memory_conflict", "targets": people, "extra": {"memory": memory, "original": original}}])
			basis["conflicts"] = [conflicts[0], conflicts[0], conflicts[0]]
		return basis
	var other: String = people[0] if actor != people[0] else people[1]
	var obligation: String = world._record("contract_obligation", domain, actor, [actor, other], [origin], {"obligor": actor, "counterparty": other, "institution": institution, "due": 0})
	var sources: Array = _ending_prayer_record(world, institution, actor, "PRAYER_06", {"petitioner": actor, "counterparty": other}, {"contract": obligation}, [{"tag": "contract_dependency", "targets": [actor, other]}, {"tag": "contract_fulfilled", "targets": [actor]}, {"tag": "contract_learned", "targets": [other]}])
	return {"route": "contract_performance", "contract": obligation, "dependency": sources[0], "witnesses": sources.slice(1)}

func build_fixture() -> Dictionary:
	catalog = Catalog.new(); assert(catalog.load_files())
	var accepted: Dictionary = Events.issuer_capability(catalog); accepted.merge(PlayerSources.issuer_capability(catalog))
	var world: RefCounted = _ending_initial_world()
	for person: Dictionary in Store.values(world.state.npcs): world.mutable_npc(person.id).loyalty = 0
	var economy: RefCounted = Economy.new(catalog, accepted); assert(economy.initialize(world))
	var data: Dictionary = {"world": world, "economy": economy, "guardians": {}, "anchors": {}, "initial_seed": ending_fixture_seed}
	var bindings: Dictionary = {}; var proofs: Dictionary = {}; var cooldowns: Dictionary = {}; var opportunities: Dictionary = {}; var routes: Dictionary = {}
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
		var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, people[0], [people[0]], [origin], {"issuer": Events.ID, "version": accepted[Events.ID], "cult": cult, "domain": domain, "leader": people[0], "cohesion": 100}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
		world.state.domains[domain].pollution = 95; world.state.domains[domain].barrier = 0; world.state.domains[domain].alert = 0
		for position: int in 3:
			var institution: String = domain + "/" + ["interpretation", "propagation", "order"][position]
			var basis: Dictionary = _ending_basis(world, institution, people)
			world.history.rebuild(world.state)
			var evaluated: Dictionary = Anchors.evaluate(world.state, institution, basis, catalog, world.history)
			assert(evaluated.get("allowed", false), str(evaluated))
			basis = evaluated.basis
			var contract: Dictionary = {"issuer": Anchors.ID, "version": Anchors.rule_version(catalog), "institution": institution, "profile": evaluated.profile, "rule": evaluated.rule, "basis": basis}
			var targets: Array = [institution] + evaluated.originals
			for carrier: Dictionary in basis.carriers: targets.append_array([carrier.institution, carrier.person])
			var proof: String = world._record("anchor_basis", domain, people[position], targets, evaluated.dependencies, contract)
			routes[institution] = {evaluated.route: proof}
			world._institution_know(institution, proof)
			var id: String = "ANCHOR/" + institution
			var relic: String = _given_relic(world, domain)
			var payload: Dictionary = {"npc": people[position], "institution": institution, "relic": relic, "source": proof, "qualification": proof}
			var permission: Dictionary = {"source": proof, "issuer": Anchors.ID, "version": Anchors.rule_version(catalog), "institution": institution, "basis": basis}
			var payment: String = world._record("turn_action", domain, "", [id], [proof], {"outcome": "power_attempt", "faith_cost": int(catalog.tables.powers.POWER_ANCHOR.faith), "whispers_cost": int(catalog.tables.powers.POWER_ANCHOR.whispers), "fixture": "preexisting_paid_anchor"})
			var attempt: String = world._record("power_attempt", domain, people[position], [people[position]], [proof, payment], {"power": "POWER_ANCHOR", "payload": payload, "probability": 50, "preparations": [], "payment": payment, "proofs": {"anchor": permission}, "cult": cult})
			var checked: String = world._record("turn_check", domain, people[position], [people[position]], [attempt], {"probability": 50, "roll": 1, "outcome": "deep", "snapshot_before_always": true})
			world.state.anchors[id] = {"id": id, "domain": domain, "institution": institution, "guardian": people[position], "relic": relic, "state": "dormant", "needs_rebind": false, "origin": world.state.cults[cult].established_source, "established_source": checked, "ordinal": position + 1, "cult": cult, "route": evaluated.route}
			assert(Relics.new(catalog, accepted).bind(world, relic, id, checked, null))
			var bound: String = world._record("anchor_institution_bound", domain, people[position], [id, institution], [checked, proof], {"anchor": id, "institution": institution, "proof": proof, "contract": contract})
			bindings[id] = {"proof": proof, "source": bound, "route": evaluated.route}; proofs[institution] = proof
			cooldowns["POWER_ANCHOR/" + institution] = {"until": int(catalog.tables.powers.POWER_ANCHOR.cooldown_turns), "source": checked}
			data.anchors[institution] = id
	world.state.insight = catalog.integer("insight_cap"); world.state.faith = 80
	world.attention.sync(world); world.history.rebuild(world.state)
	data.source = world.state.domains["DOMAIN-001"].origin; data.leader = data.guardians["DOMAIN-001"][0]; data.cult = "CULT/DOMAIN-001"
	var ids: Dictionary = data.anchors.duplicate()
	_install_session_modules(data, accepted)
	world.state.anchor_system.proofs = proofs; world.state.anchor_system.bindings = bindings
	world.state.anchor_system.opportunities = opportunities; world.state.anchor_system.routes = routes
	world.state.power_system.cooldowns = cooldowns
	for id: String in world.state.anchors: world.state.anchors[id].state = "active"
	world.history.rebuild(world.state); world._refresh_anchors(); world.attention.sync(world)
	data.anchor_ids = ids
	data.cosmic_anchor = ids["DOMAIN-011/interpretation"]; data.system_anchor = ids["DOMAIN-007/interpretation"]; data.actor = data.guardians["DOMAIN-011"][0]
	data.manifest_payload = {"npc": data.actor, "source": data.source, "cosmic_anchor": data.cosmic_anchor, "system_anchor": data.system_anchor}
	assert(world.state.awakening >= int(catalog.tables.powers.POWER_MANIFEST.unlock_awakening), "Disclosed initial institutions must supply real awakening")
	assert(Anchors.validate_state(world.state, catalog, {}, world.history).is_empty(), str(Anchors.validate_state(world.state, catalog, {}, world.history)))
	assert(world.validate_state(world.state).is_empty(), str(world.validate_state(world.state)))
	return data


func create_session(directory: String) -> RefCounted:
	var data: Dictionary = build_fixture()
	var player := PlayerSession.new(directory)
	player.catalog = catalog; player.world = data.world; player.turn = data.turn
	var naming: Dictionary = catalog.player_text.world_names.generate(int(data.initial_seed), player.world.state.domains)
	assert(naming.ok, str(naming))
	player._world_names = naming.names
	player._world_name_backgrounds = naming.backgrounds
	for key: String in ["economy", "cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources", "progression_routes"]:
		player.modules[key] = data[key]
	# Explicitly known preexisting source graph, before bootstrap/first receipt.
	# The ordinary reducer builds the authoritative ledger; Session queries cannot reveal facts.
	var known: Dictionary = player.turn.context.player_knowledge
	for fact: Dictionary in Store.values(player.world.state.facts):
		if fact.domain in ["DOMAIN-001", "DOMAIN-007", "DOMAIN-011"]:
			known = FixtureKnowledge.learn(player.world.state, player.turn.context, known, catalog, player.world.history, fact.id)
	player.turn.context.player_knowledge = known
	assert(player.turn.bootstrap_prayers().get("ok", false))
	player._campaign = "1793836800-7001"
	player.slot = directory.path_join(player._campaign + ".json")
	player._request_sequence = player.turn.commit_sequence
	player._refresh_knowledge(false)
	assert(player.progress().get("ok", false))
	assert(player.progress().get("ok", false))
	assert(player.turn.context.phase == "actions")
	assert(player.save_game().get("ok", false))
	return player
