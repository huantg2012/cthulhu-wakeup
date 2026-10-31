extends RefCounted
## The single original world-birth recipe. Production and explicit restore
## replay use this function; ordinary transactions never replay the world.

static func profile_legal(profile: Dictionary, domain: Dictionary, role: String, has_links: bool, crisis_count: int) -> bool:
	if not role in str(profile.institution_roles).split("|"): return false
	if int(profile.requires_ritual) and int(domain.occult) + int(domain.faith) <= 0: return false
	if int(profile.requires_route) and not has_links: return false
	if int(profile.requires_crisis) and crisis_count == 0: return false
	return not int(profile.requires_listener)

static func profiles(catalog: RefCounted, domain: Dictionary, role: String) -> Array:
	var result: Array = []; var ids: Array = catalog.tables.npc_profiles.keys(); ids.sort()
	for id: String in ids:
		var profile: Dictionary = catalog.tables.npc_profiles[id]
		if profile_legal(profile, domain, role, true, 0): result.append(profile)
	return result

static func plan(catalog: RefCounted, seed: String, hybrid: bool, initial_focused: int, local_limit: int) -> Dictionary:
	if not seed.is_valid_int() or str(int(seed)) != seed: return {"ok": false, "error": "Invalid world-birth seed"}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = int(seed)
	var tiers: Array = []; var domains: Array = []; var next_person: int = 1
	for tier: String in ["planet", "system", "cosmic"]:
		for index: int in catalog.integer(tier + "_domains"): tiers.append(tier)
	for index: int in tiers.size():
		var candidates: Array = []
		# Preserve authored insertion order, including the original RNG call
		# for a singleton candidate. Sorting here would change existing seeds.
		for row: Dictionary in catalog.tables.civilization_profiles.values():
			if row.tier == tiers[index]: candidates.append(row)
		if candidates.is_empty(): return {"ok": false, "error": "No authored civilization for tier " + tiers[index]}
		var profile: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var id: String = "DOMAIN-%03d" % (index + 1)
		var expanded: bool = not hybrid or index < initial_focused
		var budget: int = (local_limit if expanded else 0) if hybrid else catalog.integer("initial_named_per_domain")
		var people: Array = []; var roles: Array = ["interpretation", "propagation", "order"]
		for role: String in roles:
			if hybrid and budget <= 0: continue
			var lawful: Array = profiles(catalog, profile, role)
			if lawful.is_empty(): return {"ok": false, "error": "No legal institution representative"}
			var chosen: Dictionary = lawful[rng.randi_range(0, lawful.size() - 1)]
			people.append({"id": "NPC-%08d" % next_person, "profile": chosen.id, "institution": id + "/" + role, "representative": true}); next_person += 1
		for extra: int in maxi(0, budget - catalog.integer("institutions_per_domain")):
			var role: String = roles[extra % roles.size()]
			var lawful: Array = profiles(catalog, profile, role)
			if lawful.is_empty(): return {"ok": false, "error": "No legal additional resident"}
			var chosen: Dictionary = lawful[rng.randi_range(0, lawful.size() - 1)]
			people.append({"id": "NPC-%08d" % next_person, "profile": chosen.id, "institution": id + "/" + role, "representative": false}); next_person += 1
		domains.append({"id": id, "profile": profile.id, "named_budget": budget, "expanded_at_creation": expanded, "people": people})
	return {"ok": true, "domains": domains, "rng_state": str(rng.state)}

static func origin_data(row: Dictionary, hybrid: bool, index: int) -> Dictionary:
	return {"schema": 1, "mode": "hybrid" if hybrid else "full", "domain_index": index, "births": row.people.duplicate(true), "expanded_at_creation": row.expanded_at_creation}

static func institutions(domain: String, origin: String, hybrid: bool) -> Dictionary:
	var result: Dictionary = {}
	for role: String in ["interpretation", "propagation", "order"]:
		var id: String = domain + "/" + role
		result[id] = {"id": id, "domain": domain, "role": role, "active": true, "representative": "", "known_facts": [origin], "links": [], "source": origin}
		if hybrid: result[id]["occupancy"] = "occupied_abstract"
	for id: String in result:
		for other: String in result:
			if other != id: result[id].links.append(other)
	return result

static func institution_snapshot(domain: String, origin: String) -> Dictionary:
	var result: Dictionary = {}
	var offices: Dictionary = institutions(domain, origin, false)
	for id: String in offices:
		var row: Dictionary = offices[id]
		result[id] = {"active": row.active, "domain": row.domain, "links": row.links, "source": row.source}
	return result
