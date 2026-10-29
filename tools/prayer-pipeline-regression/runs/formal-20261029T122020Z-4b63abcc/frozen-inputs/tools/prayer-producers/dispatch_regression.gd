extends "res://tools/prayer-dispatch/run.gd"
## All inherited 55 dispatch behavior assertions remain unchanged. This adapter
## changes setup only to honor the new explicit bootstrap boundary.

func _attach_dispatch(data: Dictionary) -> Dictionary:
	super._attach_dispatch(data)
	var result: Dictionary = data.turn.bootstrap_prayers()
	assert(result.get("ok", false))
	return data

func _notice_fixture(mode: String, variant: String, seed_value: int) -> Dictionary:
	var data: Dictionary = _dispatch_native(seed_value)
	var people: Array = _local_people(data.world)
	data.sender = people[0]
	data.recipient = people[1] if variant not in ["no_relation", "wrong_relation"] else people[3]
	var world: RefCounted = data.world
	var origin: String = world.state.domains["DOMAIN-001"].origin
	if variant == "cross_domain":
		data.recipient = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-002"].origin))
	if variant == "same_institution":
		data.recipient = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", origin))
		_given_relation(data, data.sender, data.recipient, "support")
		# Keep a real unrelated passage competitor, as in the cross-institution
		# positive. New lawful-source filtering otherwise removes PR09 after the
		# original messenger is detained and anonymous population is exhausted.
		assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/propagation", "NPC_PROFILE_03", origin))
	for person: String in people:
		if person not in [data.sender, data.recipient]: assert(world.submit({"kind": "status", "npc": person, "status": "detained", "parents": [origin]}))
	if variant in ["dead", "detained", "missing"]:
		assert(world.submit({"kind": "status", "npc": data.recipient, "status": variant, "parents": [origin]}))
	if variant == "wrong_relation": _given_relation(data, data.sender, data.recipient, "rival")
	if variant == "no_route":
		var sender_institution: String = Store.entry(world.state.npcs, data.sender).institution
		var recipient_institution: String = Store.entry(world.state.npcs, data.recipient).institution
		world.state.institutions[sender_institution].links.erase(recipient_institution)
	var contact: String = _given_fact(data, "devotion_contact", data.sender, [data.sender], {"subject": data.sender, "institution": Store.entry(world.state.npcs, data.sender).institution})
	if variant == "anomaly_only": _given_fact(data, "exposure", data.sender, [data.sender], {"public": false, "unexplained": true})
	# Keep exactly one lawful bootstrap nominee, then let the real bootstrap
	# consume it. The notice snapshot still has no anonymous population.
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog))
	var prerequisite_economy: RefCounted = Economy.new(catalog, accepted)
	assert(prerequisite_economy.initialize(world))
	var available: int = int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers)
	assert(available > 0)
	if available > 1: assert(world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": available - 1, "parents": [origin]}))
	var qualification: String = _qualification(data, "dream", data.sender, data.sender, "DOMAIN-001", {"contact": contact})
	data.dream = {"npc": data.sender, "source": contact, "qualification": qualification}
	_attach_dispatch(data)
	assert(world.state.domains["DOMAIN-001"].unnamed_nonfollowers == 0)
	assert(_open(data))
	if variant not in ["unidentified", "anomaly_only"]:
		assert(_seed(data, "POWER_DREAM", "success", data.dream) > 0)
		var response: Dictionary = _power(data, "POWER_DREAM", data.dream)
		assert(response.ok and Knowledge.known(world.state, data.sender).get("known", false))
	if mode == "background":
		assert(_submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}).ok)
		assert(_evolve(data) and _finish(data) and _open(data))
	return data
