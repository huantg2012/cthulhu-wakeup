extends RefCounted
## Pure-data rule core. UI and prose may not mutate the state directly.
## The public state is inspectable for tools; game adapters submit validated commands.

const Transaction = preload("res://src/simulation/transaction.gd")
const Catalog = preload("res://src/simulation/catalog.gd")
const Economy = preload("res://src/game/economy.gd")
const ATTRIBUTES: Array[String] = ["will", "insight", "influence", "adaptation"]
const STATUSES: Array[String] = ["active", "detained", "missing", "dead"]
const INTEGRATION_FACTS: Array[String] = ["miracle", "exposure", "harm", "strain", "crisis", "exception", "message", "institution_succession_authorized", "exception_confirmation_authorized", "public_anomaly", "anomaly_resolved", "cult_establishment_authorized"]
const SCHEMA_VERSION: int = 1
var catalog: RefCounted
var state: Dictionary = {}
var randoms: Dictionary = {}
var last_error: String = ""
var _turn_owner: WeakRef = null
var transaction: RefCounted = null
var participant_read: bool = false
var stats: Dictionary = {"npc_updates": 0, "actions": 0, "plans_started": 0, "plans_resolved": 0, "plans_cancelled": 0}

func _init(content: RefCounted) -> void:
	catalog = content

static func canonical(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)

func _keys(collection: Dictionary) -> Array:
	var ids: Array = collection.keys()
	ids.sort()
	return ids

func _unique_sorted(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		if not value in result:
			result.append(value)
	result.sort()
	return result

func stage_collections(fields: Array) -> void:
	if transaction != null:
		transaction.touch_world(fields)

func stage_current() -> void:
	stage_collections(["domains", "institutions", "npcs", "evidence", "cults", "relics", "anchors", "applied_authorizations", "invalid_records", "economy", "economy_qualifications"])

func _next_id(prefix: String, counter: String) -> String:
	var id: String = "%s-%08d" % [prefix, int(state[counter])]
	state[counter] += 1
	return id

func _record(kind: String, domain: String, actor: String, targets: Array, parents: Array, changes: Dictionary = {}) -> String:
	# Parents are explicit causes, never the last historical record.
	for parent: String in parents:
		assert(state.facts.has(parent), "Unknown cause: " + parent)
	stage_collections(["facts"])
	var id: String = _next_id("FACT", "next_fact")
	state.facts[id] = {"id": id, "turn": state.turn, "kind": kind, "domain": domain, "actor": actor, "targets": _unique_sorted(targets), "causal_parents": _unique_sorted(parents), "changes": changes.duplicate(true)}
	Transaction.freeze(state.facts[id])
	return id

func _know(npc_id: String, fact: String) -> void:
	if state.npcs.has(npc_id) and not fact in state.npcs[npc_id].known_facts:
		state.npcs[npc_id].known_facts.append(fact)
		state.npcs[npc_id].known_facts.sort()

func _institution_know(institution_id: String, fact: String) -> void:
	if state.institutions.has(institution_id) and not fact in state.institutions[institution_id].known_facts:
		state.institutions[institution_id].known_facts.append(fact)
		state.institutions[institution_id].known_facts.sort()

func check_probability(npc_id: String, attribute: String, domain_id: String, mode: String = "occult", preparation: int = 0) -> int:
	if not state.npcs.has(npc_id) or not state.domains.has(domain_id) or not attribute in ATTRIBUTES or not mode in ["social", "occult"]:
		return -1
	var npc: Dictionary = state.npcs[npc_id]
	var domain: Dictionary = state.domains[domain_id]
	var modifier: int = 0
	if int(npc.sanity) >= catalog.integer("sanity_stable_threshold"):
		modifier = catalog.integer("sanity_stable_" + mode + "_modifier")
	elif int(npc.sanity) < catalog.integer("sanity_fractured_threshold"):
		modifier = catalog.integer("sanity_disordered_" + mode + "_modifier")
	var p: int = catalog.integer("check_base") + catalog.integer("check_attribute_step") * (int(npc[attribute]) - catalog.integer("check_" + str(domain.tier) + "_difficulty"))
	p += clampi(preparation, -catalog.integer("check_preparation_limit"), catalog.integer("check_preparation_limit")) + modifier
	p -= int(floor(float(domain.barrier) / catalog.number("check_barrier_divisor")))
	p -= int(floor(float(domain.alert) / catalog.number("check_alert_divisor")))
	return clampi(p, catalog.integer("check_probability_min"), catalog.integer("check_probability_max"))

func check_result(probability: int, roll: int) -> String:
	if probability < 0 or probability > 100 or roll < 1 or roll > 100:
		return "invalid"
	var divisor: float = catalog.number("check_critical_divisor")
	if roll <= int(floor(float(probability) / divisor)):
		return "deep"
	if roll <= probability:
		return "success"
	if roll > 100 - int(ceil(float(100 - probability) / divisor)):
		return "disaster"
	return "failure"

func _active(npc: Dictionary) -> bool:
	return npc.status == "active"

func _living_count() -> int:
	var total: int = 0
	for npc: Dictionary in state.npcs.values():
		if npc.status != "dead":
			total += 1
	return total

func _new_npc(profile: Dictionary, domain_id: String, institution_id: String, source: String) -> String:
	var id: String = _next_id("NPC", "next_npc")
	var npc: Dictionary = {"id": id, "profile": profile.id, "domain": domain_id, "institution": institution_id, "status": "active", "known_facts": [source], "relations": [], "consumed_sources": {}, "growth_sources": {}, "acted_turn": -1, "status_source": source, "role_tags": str(profile.role_tags).split(";"), "need_tags": str(profile.need_tags).split(";")}
	for attribute: String in ATTRIBUTES + ["sanity", "loyalty"]:
		npc[attribute] = int(profile[attribute])
	state.npcs[id] = npc
	return id

func claim_turn_driver(owner: Object) -> bool:
	if owner == null or (_turn_owner != null and _turn_owner.get_ref() != null and _turn_owner.get_ref() != owner):
		return false
	_turn_owner = weakref(owner)
	return true

func _driver_allowed(owner: Object) -> bool:
	if participant_read:
		return false
	if _turn_owner != null and _turn_owner.get_ref() == null:
		# Releasing the sole coordinator returns ownership to standalone tooling.
		# This infrequent ownership boundary detaches the immutable published root.
		state = state.duplicate(true)
		stats = stats.duplicate(true)
		_turn_owner = null
	return _turn_owner == null or _turn_owner.get_ref() == owner

func submit(command: Dictionary, owner: Object = null, defer_lifecycle: bool = false) -> bool:
	stage_current()
	if not _driver_allowed(owner):
		return false
	# Boundary commands represent already-authorized rule effects, not free player powers.
	# All preconditions are checked before writes and no rejected command draws RNG.
	last_error = ""
	if not command.has("kind") or not command.has("parents") or not command.parents is Array:
		last_error = "Command requires kind and explicit parents"
		return false
	for parent: Variant in command.parents:
		if not parent is String or not state.facts.has(parent):
			last_error = "Missing cause"
			return false
	var kind: String = str(command.kind)
	if kind in ["population", "establish_cult", "economy_qualification"]:
		var accepted: bool = _economy_command(command)
		if accepted and not defer_lifecycle:
			Economy.refresh_cults(self)
			_refresh_anchors()
		return accepted
	if kind == "nominate":
		return _nominate(command)
	if not command.has("npc") or not state.npcs.has(command.npc):
		last_error = "Unknown person"
		return false
	var npc: Dictionary = state.npcs[command.npc]
	if npc.status == "dead":
		last_error = "Dead person cannot receive this effect"
		return false
	if kind == "status":
		if not command.get("status", "") in STATUSES or command.status == npc.status or command.parents.is_empty():
			last_error = "Invalid status transition or missing cause"
			return false
		_change_status(npc, str(command.status), command.parents)
		return true
	if kind == "migrate":
		var target: String = str(command.get("domain", ""))
		if npc.status != "active" or not state.domains.has(target) or target == npc.domain or not target in state.domains[npc.domain].neighbors or command.parents.is_empty():
			last_error = "Migration requires active person, reachable target and cause"
			return false
		if int(state.domains[target].population) >= catalog.integer("domain_population_capacity"):
			last_error = "Destination population full"
			return false
		var previous: String = str(npc.domain)
		state.domains[previous].population -= 1
		state.domains[target].population += 1
		var fact: String = _record("migration", target, npc.id, [npc.id], command.parents, {"from": previous, "to": target})
		npc.status_source = fact
		_detach_roles(npc)
		npc.domain = target
		npc.institution = ""
		for relic: Dictionary in state.relics.values():
			if relic.holder == npc.id and relic.placement == "carried":
				relic.domain = target
		_know(npc.id, fact)
		_refresh_anchors()
		return true
	last_error = "Unknown effect kind"
	return false

func _consume_income_cohort(domain_id: String, amount: int) -> int:
	if not state.has("economy") or not state.economy.eligible.has(domain_id):
		return 0
	var removed: int = mini(amount, int(state.economy.eligible[domain_id]))
	state.economy.eligible[domain_id] -= removed
	return removed

func _population_cause(domain_id: String, fact: String) -> void:
	state.domains[domain_id]["population_source"] = fact
	if state.has("economy") and state.economy.cohort_sources.has(domain_id):
		state.economy.cohort_sources[domain_id] = fact

func _cohort_values(domains: Array) -> Dictionary:
	var values: Dictionary = {}
	if state.has("economy"):
		for id: String in domains:
			if state.economy.eligible.has(id):
				values[id] = state.economy.eligible[id]
	return values

func valid_economy_command(command: Dictionary) -> bool:
	if not state.has("economy") or not command.get("parents") is Array or command.parents.is_empty():
		return false
	for parent: Variant in command.parents:
		if not parent is String or not state.facts.has(parent):
			return false
	match command.get("kind", ""):
		"population":
			if not command.get("domain") is String or not state.domains.has(command.domain) or not command.get("amount") is int or int(command.amount) <= 0 or not command.get("mode", "") in ["convert", "leave", "death", "migrate"]:
				return false
			var domain: Dictionary = state.domains[command.domain]
			var available: int = domain.unnamed_nonfollowers if command.mode == "convert" else domain.unnamed_followers
			if int(command.amount) > available:
				return false
			if command.mode == "migrate":
				return command.get("target") is String and state.domains.has(command.target) and command.target in domain.neighbors and int(state.domains[command.target].population) + int(command.amount) <= catalog.integer("domain_population_capacity")
			return true
		"establish_cult":
			if not command.get("authorization") is String or not command.authorization in command.parents or not state.facts.has(command.authorization) or state.applied_authorizations.has(command.authorization):
				return false
			var fact: Dictionary = state.facts[command.authorization]
			var data: Dictionary = fact.changes
			if fact.kind != "cult_establishment_authorized" or not data.get("cult") is String or str(data.cult).is_empty() or not state.domains.has(data.get("domain", "")) or fact.domain != data.domain or not state.npcs.has(data.get("leader", "")) or not data.get("cohesion") is int or int(data.cohesion) <= 0 or int(data.cohesion) > catalog.integer("attribute_max") or state.economy.issuers.get(data.get("issuer", ""), null) != data.get("version", "INVALID"):
				return false
			var leader: Dictionary = state.npcs[data.leader]
			if leader.status != "active" or leader.domain != data.domain or int(leader.loyalty) < catalog.integer("loyalty_follower_threshold") or int(state.domains[data.domain].unnamed_followers) <= 0:
				return false
			for cult: Dictionary in state.cults.values():
				if cult.domain == data.domain and (cult.id != data.cult or cult.status != "destroyed"):
					return false
			return not state.cults.has(data.cult) or (state.cults[data.cult].domain == data.domain and state.cults[data.cult].status == "destroyed")
		"economy_qualification":
			if not command.get("rule", "") in ["propagation", "anchor"] or not command.get("subject") is String or not command.get("allowed") is bool or not state.institutions.has(command.get("institution", "")) or not command.get("issuer") is String or not command.get("version") is String or state.economy.issuers.get(command.issuer, null) != command.version:
				return false
			var collection: Dictionary = state.cults if command.rule == "propagation" else state.anchors
			if not collection.has(command.subject) or collection[command.subject].domain != state.institutions[command.institution].domain or (command.rule == "anchor" and collection[command.subject].institution != command.institution):
				return false
			var prior: String = state.economy_qualifications.get(command.rule + "|" + command.subject, "")
			return prior.is_empty() or prior in command.parents
	return false

func _economy_command(command: Dictionary) -> bool:
	if not valid_economy_command(command):
		last_error = "Invalid economic boundary command or upstream authorization"
		return false
	match command.kind:
		"population":
			var domain: Dictionary = state.domains[command.domain]
			var amount: int = command.amount
			var removed: int = 0
			var parents: Array = command.parents.duplicate()
			if state.economy.cohort_sources.has(domain.id):
				parents.append(state.economy.cohort_sources[domain.id])
			if command.mode == "migrate" and state.economy.cohort_sources.has(command.target):
				parents.append(state.economy.cohort_sources[command.target])
			if command.mode == "convert":
				domain.unnamed_nonfollowers -= amount
				domain.unnamed_followers += amount
			else:
				domain.unnamed_followers -= amount
				removed = _consume_income_cohort(domain.id, amount)
				if command.mode == "leave":
					domain.unnamed_nonfollowers += amount
				elif command.mode == "death":
					domain.population -= amount
				elif command.mode == "migrate":
					domain.population -= amount
					state.domains[command.target].population += amount
					state.domains[command.target].unnamed_followers += amount
			var fact: String = _record("population_transfer", domain.id, "", [command.get("target", domain.id)], _unique_sorted(parents), {"mode": command.mode, "amount": amount, "eligible_removed": removed, "eligible_added": 0, "eligible_after": _cohort_values([domain.id, command.target] if command.mode == "migrate" else [domain.id]), "target": command.get("target", "")})
			_population_cause(domain.id, fact)
			if command.mode == "migrate":
				_population_cause(command.target, fact)
		"establish_cult":
			var data: Dictionary = state.facts[command.authorization].changes
			var source: String = _record("cult_established", data.domain, data.leader, [data.leader], command.parents, {"cult": data.cult, "authorization": command.authorization})
			var origin: String = state.cults[data.cult].origin if state.cults.has(data.cult) else source
			state.cults[data.cult] = {"id": data.cult, "domain": data.domain, "leader": data.leader, "cohesion": data.cohesion, "status": "active", "origin": origin, "established_turn": state.turn, "established_source": source, "strategy": "hold", "succession_source": source}
			if not state.economy.remainders.has(data.cult):
				state.economy.remainders[data.cult] = 0
			state.applied_authorizations[command.authorization] = source
		"economy_qualification":
			var collection: Dictionary = state.cults if command.rule == "propagation" else state.anchors
			var data: Dictionary = command.duplicate(true)
			data.erase("kind")
			data.erase("parents")
			var source: String = _record("economy_qualification", collection[command.subject].domain, "", [command.subject, command.institution], command.parents, data)
			state.economy_qualifications[command.rule + "|" + command.subject] = source
	return true

func _nominate(command: Dictionary) -> bool:
	var domain_id: String = str(command.get("domain", ""))
	var profile_id: String = str(command.get("profile", ""))
	var group: String = str(command.get("group", ""))
	if not state.domains.has(domain_id) or not catalog.tables.npc_profiles.has(profile_id) or not group in ["unnamed_nonfollowers", "unnamed_followers"] or command.parents.is_empty():
		last_error = "Invalid nomination references"
		return false
	if _living_count() >= catalog.integer("living_named_global_limit") or int(state.domains[domain_id][group]) <= 0:
		last_error = "Named budget or source population exhausted"
		return false
	var institution: String = str(command.get("institution", ""))
	if not _profile_legal(catalog.tables.npc_profiles[profile_id], domain_id, institution):
		last_error = "Profile has no legal social context"
		return false
	state.domains[domain_id][group] -= 1
	var eligible_removed: int = 0
	if group == "unnamed_followers":
		eligible_removed = _consume_income_cohort(domain_id, 1)
	var id: String = _new_npc(catalog.tables.npc_profiles[profile_id], domain_id, institution, command.parents[0])
	if group == "unnamed_followers":
		state.npcs[id].loyalty = maxi(int(state.npcs[id].loyalty), catalog.integer("loyalty_follower_threshold"))
	var parents: Array = command.parents.duplicate()
	if state.has("economy") and state.economy.cohort_sources.has(domain_id):
		parents.append(state.economy.cohort_sources[domain_id])
	var fact: String = _record("nomination", domain_id, id, [id], _unique_sorted(parents), {"from_group": group, "eligible_removed": eligible_removed, "eligible_after": _cohort_values([domain_id])})
	_population_cause(domain_id, fact)
	_know(id, fact)
	Economy.refresh_cults(self)
	_refresh_anchors()
	return true

func _detach_roles(npc: Dictionary) -> void:
	for institution: Dictionary in state.institutions.values():
		if institution.representative == npc.id:
			institution.representative = ""
	for cult: Dictionary in state.cults.values():
		if cult.leader == npc.id:
			cult.leader = ""
			cult.succession_source = npc.status_source
			cult.status = "dormant"
	for anchor: Dictionary in state.anchors.values():
		if anchor.guardian == npc.id:
			anchor.guardian = ""
			if anchor.state != "destroyed":
				anchor.state = "dormant"
			anchor.needs_rebind = true

func _change_status(npc: Dictionary, next_status: String, parents: Array) -> void:
	var old: String = str(npc.status)
	var fact: String = _record("status_change", npc.domain, npc.id, [npc.id], parents, {"from": old, "to": next_status})
	npc.status = next_status
	npc.status_source = fact
	_know(npc.id, fact)
	if next_status == "dead":
		_detach_roles(npc)
	if next_status == "dead":
		state.domains[npc.domain].population -= 1
		for relic: Dictionary in state.relics.values():
			if relic.holder == npc.id:
				relic.holder = ""
				relic.placement = "controlled" if _has_cult(npc.domain) else "ground"
	_refresh_anchors()

func _has_cult(domain: String) -> bool:
	for cult: Dictionary in state.cults.values():
		if cult.domain == domain and cult.status != "destroyed":
			return true
	return false

func _refresh_anchors() -> void:
	stage_collections(["anchors"])
	var contribution: int = 0
	for anchor: Dictionary in state.anchors.values():
		if anchor.state != "active":
			continue
		var valid: bool = state.npcs.has(anchor.guardian) and _active(state.npcs[anchor.guardian]) and state.npcs[anchor.guardian].domain == anchor.domain
		valid = valid and state.relics.has(anchor.relic) and state.relics[anchor.relic].placement == "bound" and state.relics[anchor.relic].get("anchor", "") == anchor.id
		valid = valid and state.institutions.has(anchor.institution) and state.institutions[anchor.institution].active
		if valid and state.has("economy"):
			var qualified: Dictionary = Economy.anchor_eligibility(state, anchor, catalog)
			valid = qualified.reason.is_empty() if qualified.ok else Economy.anchor_physical_reason(state, anchor, catalog).is_empty()
		if not valid:
			anchor.state = "dormant"
		else:
			contribution += catalog.integer("anchor_" + str(state.domains[anchor.domain].tier) + "_contribution")
	state.awakening = clampi(catalog.integer("initial_awakening") + int(state.insight) + contribution - int(state.wounds), 0, catalog.integer("awakening_before_final_cap"))
	state.peak_awakening = maxi(int(state.peak_awakening), int(state.awakening))

func snapshot() -> String:
	var streams: Dictionary = {}
	for name: String in _keys(randoms):
		streams[name] = {"seed": str(randoms[name].seed), "state": str(randoms[name].state)}
	var body: Dictionary = {"schema": SCHEMA_VERSION, "content": catalog.version, "engine": Engine.get_version_info().string, "state": state, "randoms": streams, "stats": stats}
	var payload: String = canonical(body)
	return canonical({"body": body, "checksum": payload.sha256_text()})

func restore(serialized: String, owner: Object = null) -> bool:
	if not _driver_allowed(owner):
		return false
	last_error = ""
	var json: JSON = JSON.new()
	if json.parse(serialized) != OK or not json.data is Dictionary:
		last_error = "Malformed save"
		return false
	var envelope: Dictionary = json.data
	if not envelope.get("body") is Dictionary or not envelope.get("checksum") is String:
		last_error = "Missing envelope"
		return false
	var body: Dictionary = _normalize_numbers(envelope.body)
	if canonical(body).sha256_text() != envelope.checksum or body.get("schema") != SCHEMA_VERSION or body.get("content") != catalog.version or body.get("engine") != Engine.get_version_info().string:
		last_error = "Incompatible or damaged save"
		return false
	if not body.get("state") is Dictionary or not body.get("randoms") is Dictionary or not body.get("stats") is Dictionary:
		last_error = "Incomplete save"
		return false
	var issues: Array[String] = validate_state(body.state)
	if not issues.is_empty():
		last_error = "; ".join(issues)
		return false
	for name: String in ["generation", "checks", "events"]:
		if not body.randoms.get(name) is Dictionary:
			last_error = "Missing RNG stream"
			return false
		for key: String in ["seed", "state"]:
			if not body.randoms[name].get(key) is String or not str(body.randoms[name][key]).is_valid_int():
				last_error = "RNG integer must be a decimal string"
				return false
	for field: String in stats:
		if not body.stats.get(field) is int or int(body.stats[field]) < 0:
			last_error = "Invalid counters"
			return false
	state = body.state
	stats = body.stats
	randoms.clear()
	for name: String in ["generation", "checks", "events"]:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(body.randoms[name].seed)
		rng.state = int(body.randoms[name].state)
		randoms[name] = rng
	return true

static func _normalize_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and floor(value) == value:
		return int(value)
	if value is Dictionary:
		var converted: Dictionary = {}
		for key: String in value:
			converted[key] = _normalize_numbers(value[key])
		return converted
	if value is Array:
		var converted: Array = []
		for entry: Variant in value:
			converted.append(_normalize_numbers(entry))
		return converted
	return value

func generate(seed_value: int, owner: Object = null) -> bool:
	if not _driver_allowed(owner):
		return false
	# Authored tier budgets and lawful jobs are generated before any requests.
	var old_state: Dictionary = state
	var old_randoms: Dictionary = randoms
	state = {"turn": 0, "phase": "between", "applied_authorizations": {}, "invalid_records": {}, "domains": {}, "institutions": {}, "npcs": {}, "facts": {}, "evidence": {}, "cults": {}, "relics": {}, "anchors": {}, "next_npc": 1, "next_fact": 1, "faith": catalog.integer("initial_faith"), "insight": catalog.integer("initial_insight"), "wounds": catalog.integer("initial_wounds"), "awakening": catalog.integer("initial_awakening"), "peak_awakening": catalog.integer("initial_awakening"), "whispers": catalog.integer("whisper_base")}
	randoms = {}
	var stream_index: int = 0
	for name: String in ["generation", "checks", "events"]:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value + stream_index
		randoms[name] = rng
		stream_index += 1
	var tiers: Array = []
	for tier: String in ["planet", "system", "cosmic"]:
		for index: int in catalog.integer(tier + "_domains"):
			tiers.append(tier)
	for index: int in tiers.size():
		var tier: String = tiers[index]
		var candidates: Array = []
		for profile: Dictionary in catalog.tables.civilization_profiles.values():
			if profile.tier == tier:
				candidates.append(profile)
		if candidates.is_empty():
			state = old_state
			randoms = old_randoms
			last_error = "No authored civilization for tier " + tier
			return false
		var profile: Dictionary = candidates[randoms.generation.randi_range(0, candidates.size() - 1)]
		var id: String = "DOMAIN-%03d" % (index + 1)
		var domain: Dictionary = {"id": id, "profile": profile.id, "tier": tier, "communication": profile.communication, "authority": profile.authority, "barrier": int(profile.barrier), "stability": int(profile.stability), "pollution": 0, "alert": 0, "population": catalog.integer("domain_population"), "unnamed_nonfollowers": catalog.integer("domain_population") - catalog.integer("initial_named_per_domain"), "unnamed_followers": 0, "neighbors": [], "institutions": [], "crisis_facts": [], "public_facts": [], "public_anomalies": {}, "pending_plan": {}, "plan_cooldowns": {}, "barrier_source": "", "pollution_changed_turn": -1, "exposure_turn": -1}
		for paradigm: String in ["tech", "occult", "faith", "meme"]:
			domain[paradigm] = int(profile[paradigm])
		state.domains[id] = domain
		var origin: String = _record("world_origin", id, "", [], [], {"profile": profile.id})
		domain.origin = origin
		domain.barrier_source = origin
		for role: String in ["interpretation", "propagation", "order"]:
			var institution_id: String = id + "/" + role
			state.institutions[institution_id] = {"id": institution_id, "domain": id, "role": role, "active": true, "representative": "", "known_facts": [origin], "links": [], "source": origin}
			domain.institutions.append(institution_id)
		for institution_id: String in domain.institutions:
			for other: String in domain.institutions:
				if other != institution_id:
					state.institutions[institution_id].links.append(other)
		# A context is not fabricated after selecting an incompatible profile.
		for institution_id: String in domain.institutions:
			var lawful: Array = _profiles_for(id, institution_id)
			if lawful.is_empty():
				state = old_state
				randoms = old_randoms
				last_error = "No legal institution representative"
				return false
			var person_id: String = _new_npc(lawful[randoms.generation.randi_range(0, lawful.size() - 1)], id, institution_id, origin)
			state.institutions[institution_id].representative = person_id
		for index_npc: int in catalog.integer("initial_named_per_domain") - catalog.integer("institutions_per_domain"):
			var institution_id: String = domain.institutions[index_npc % domain.institutions.size()]
			var lawful: Array = _profiles_for(id, institution_id)
			_new_npc(lawful[randoms.generation.randi_range(0, lawful.size() - 1)], id, institution_id, origin)
		var residents: Array = []
		for person_id: String in _keys(state.npcs):
			if state.npcs[person_id].domain == id:
				residents.append(person_id)
		for resident_index: int in residents.size():
			var person: Dictionary = state.npcs[residents[resident_index]]
			var relative: String = residents[(resident_index + 1) % residents.size()]
			var relation_fact: String = _record("initial_relationship", id, person.id, [relative], [origin], {"kind": "support"})
			person.relations.append({"target": relative, "kind": "support", "source": relation_fact})
			_know(person.id, relation_fact)
			_know(relative, relation_fact)
			if int(person.sanity) < catalog.integer("autonomous_recovery_threshold"):
				var strain: String = _record("strain", id, person.id, [person.id], [origin], {"sanity": person.sanity})
				_know(person.id, strain)
	# A chain gives a sparse, reachable world without freezing unobserved domains.
	var domain_ids: Array = _keys(state.domains)
	for index: int in domain_ids.size() - 1:
		state.domains[domain_ids[index]].neighbors.append(domain_ids[index + 1])
		state.domains[domain_ids[index + 1]].neighbors.append(domain_ids[index])
	var issues: Array[String] = validate_state(state)
	if not issues.is_empty():
		state = old_state
		randoms = old_randoms
		last_error = "; ".join(issues)
		return false
	stats = {"npc_updates": 0, "actions": 0, "plans_started": 0, "plans_resolved": 0, "plans_cancelled": 0}
	return true

func _profiles_for(domain_id: String, institution_id: String) -> Array:
	var result: Array = []
	for id: String in _keys(catalog.tables.npc_profiles):
		var profile: Dictionary = catalog.tables.npc_profiles[id]
		if _profile_legal(profile, domain_id, institution_id):
			result.append(profile)
	return result

func _profile_legal(profile: Dictionary, domain_id: String, institution_id: String) -> bool:
	if not state.domains.has(domain_id):
		return false
	var domain: Dictionary = state.domains[domain_id]
	var role: String = "none"
	if not institution_id.is_empty():
		if not state.institutions.has(institution_id) or state.institutions[institution_id].domain != domain_id:
			return false
		role = state.institutions[institution_id].role
	if not role in str(profile.institution_roles).split("|"):
		return false
	if int(profile.requires_ritual) and int(domain.occult) + int(domain.faith) <= 0:
		return false
	if int(profile.requires_route) and (institution_id.is_empty() or state.institutions[institution_id].links.is_empty()):
		return false
	if int(profile.requires_crisis) and domain.crisis_facts.is_empty():
		return false
	if int(profile.requires_listener):
		# Nomination must supply a relation first; do not generate a phantom audience.
		return false
	return true

func introduce_fact(kind: String, domain_id: String, actor: String, targets: Array, parents: Array, details: Dictionary, observers: Array, institutions: Array = [], owner: Object = null) -> String:
	stage_collections(["domains", "npcs", "institutions", "invalid_records", "applied_authorizations"])
	if not _driver_allowed(owner):
		return ""
	# Trusted integration boundary for actual player/event outcomes. It does not
	# implement the originating prayer or power, nor grant its rewards.
	if not kind in INTEGRATION_FACTS or not state.domains.has(domain_id) or parents.is_empty():
		return ""
	for parent: Variant in parents:
		if not parent is String or not state.facts.has(parent):
			return ""
	for person_id: String in observers:
		if not state.npcs.has(person_id) or state.npcs[person_id].status != "active" or (kind != "message" and state.npcs[person_id].domain != domain_id):
			return ""
	for institution_id: String in institutions:
		if not state.institutions.has(institution_id):
			return ""
	if not actor.is_empty() and not state.npcs.has(actor):
		return ""
	for target: String in targets:
		if not state.npcs.has(target) and not state.relics.has(target) and not state.anchors.has(target) and not state.institutions.has(target) and not (kind == "exception_confirmation_authorized" and state.facts.has(target) and state.facts[target].kind == "exception"):
			return ""
	if kind == "public_anomaly" and (targets.size() != 1 or not _public_carrier_valid(state, targets[0], domain_id)):
		return ""
	if kind == "anomaly_resolved" and (not state.domains[domain_id].public_anomalies.has(str(details.get("source", ""))) or not str(details.get("source", "")) in parents):
		return ""
	if kind == "miracle":
		for witness: Variant in details.get("witnesses", []):
			if not witness is String or not state.npcs.has(witness) or state.npcs[witness].status != "active" or not witness in observers:
				return ""
	var fact: String = _record(kind, domain_id, actor, targets, parents, details)
	for person_id: String in observers:
		_know(person_id, fact)
	for institution_id: String in institutions:
		_institution_know(institution_id, fact)
	if kind == "exposure" and details.get("public", false):
		state.domains[domain_id].public_facts.append(fact)
		state.domains[domain_id].exposure_turn = state.turn
	if kind == "public_anomaly":
		state.domains[domain_id].public_anomalies[fact] = targets[0]
	if kind == "anomaly_resolved":
		state.domains[domain_id].public_anomalies.erase(details.source)
	if kind == "crisis":
		state.domains[domain_id].crisis_facts.append(fact)
	return fact

func choose_behavior(npc_id: String, view: Dictionary = {}) -> Dictionary:
	var current: Dictionary = state if view.is_empty() else view
	if not current.npcs.has(npc_id):
		return {}
	var npc: Dictionary = current.npcs[npc_id]
	if npc.status != "active" or int(npc.acted_turn) == int(current.turn):
		return {}
	var recovery_source: String = ""
	for known: String in npc.known_facts:
		var known_fact: Dictionary = current.facts[known]
		if known_fact.kind in ["strain", "harm"] and npc_id in known_fact.targets and known > recovery_source:
			recovery_source = known
	var candidates: Array = []
	for behavior_id: String in _keys(catalog.tables.npc_behaviors):
		var rule: Dictionary = catalog.tables.npc_behaviors[behavior_id]
		if int(npc.sanity) < int(rule.sanity_cost) or int(npc.get("cooldowns", {}).get(behavior_id, -1)) >= int(current.turn):
			continue
		for source: String in npc.known_facts:
			var fact: Dictionary = current.facts[source]
			var targets: Array = []
			var additional: Dictionary = {}
			match str(rule.eligibility):
				"strained_self":
					if int(npc.sanity) < catalog.integer("autonomous_recovery_threshold") and source == recovery_source:
						targets.append(npc_id)
				"known_local_exposure":
					if fact.kind == "exposure" and fact.domain == npc.domain and current.institutions.has(npc.institution) and _institution_operational(current, npc.institution):
						for target: String in fact.targets:
							if (current.npcs.has(target) or current.relics.has(target)) and _subject_valid(current, target, npc.domain):
								targets.append(target)
				"related_harmed_follower":
					if fact.kind == "harm" and int(npc.loyalty) >= catalog.integer("loyalty_follower_threshold"):
						for relation: Dictionary in npc.relations:
							if relation.kind != "support" or not current.npcs.has(relation.target) or not relation.target in fact.targets:
								continue
							var other: Dictionary = current.npcs[relation.target]
							if other.status == "active" and other.domain == npc.domain and int(other.loyalty) >= catalog.integer("loyalty_follower_threshold") and int(other.sanity) < catalog.integer("autonomous_recovery_threshold") and source in other.known_facts:
								targets.append(other.id)
								additional[other.id] = relation.source
				"personally_witnessed_miracle":
					if fact.kind == "miracle" and npc_id in fact.changes.get("witnesses", []) and int(npc.loyalty) < catalog.integer("attribute_max"):
						targets.append(npc_id)
			for target: String in targets:
				var consumed_key: String = behavior_id + "/" + source
				if rule.repeat_policy == "once_per_actor_source_target":
					consumed_key += "/" + target
				if rule.repeat_policy != "repeat_until_threshold" and npc.consumed_sources.has(consumed_key):
					continue
				var score: int = int(rule.base_score) + int(npc[rule.attribute]) * int(rule.attribute_weight)
				for need: String in str(rule.need_tags).split("|"):
					if need in npc.need_tags:
						score += int(rule.need_bonus)
						break
				var parents: Array = [source]
				if additional.has(target):
					parents.append(additional[target])
				candidates.append({"actor": npc_id, "behavior": behavior_id, "target": target, "source": source, "parents": _unique_sorted(parents), "score": score, "consumed_key": consumed_key, "amount": int(rule.effect_base) + int(floor(float(npc[rule.attribute]) / float(rule.effect_divisor)))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score:
			return a.score > b.score
		return str(a.behavior) + "/" + str(a.target) + "/" + str(a.source) < str(b.behavior) + "/" + str(b.target) + "/" + str(b.source)
	)
	return {} if candidates.is_empty() else candidates[0]

func _subject_valid(view: Dictionary, subject: String, domain: String) -> bool:
	if view.npcs.has(subject):
		return view.npcs[subject].status == "active" and view.npcs[subject].domain == domain
	if view.relics.has(subject):
		return view.relics[subject].domain == domain and not view.relics[subject].placement in ["consumed", "seized"]
	if view.anchors.has(subject):
		return view.anchors[subject].domain == domain and view.anchors[subject].state == "active"
	return false

func _add_delta(deltas: Dictionary, target: String, field: String, amount: int) -> void:
	if not deltas.has(target):
		deltas[target] = {}
	deltas[target][field] = int(deltas[target].get(field, 0)) + amount

func _apply_behaviors(actions: Array, view: Dictionary) -> Dictionary:
	var deltas: Dictionary = {}
	var domain_deltas: Dictionary = {}
	var healing: Dictionary = {}
	for action: Dictionary in actions:
		var rule: Dictionary = catalog.tables.npc_behaviors[action.behavior]
		_add_delta(deltas, action.actor, "sanity", -int(rule.sanity_cost))
		match str(rule.effect):
			"restore_self_sanity", "restore_target_sanity":
				healing[action.target] = int(healing.get(action.target, 0)) + int(action.amount)
				_add_delta(deltas, action.target, "loyalty", int(rule.target_loyalty_delta))
			"increase_self_loyalty":
				_add_delta(deltas, action.actor, "loyalty", int(action.amount))
	for id: String in _keys(healing):
		_add_delta(deltas, id, "sanity", mini(int(healing[id]), maxi(0, catalog.integer("autonomous_recovery_threshold") - int(view.npcs[id].sanity))))
	for id: String in _keys(deltas):
		for field: String in _keys(deltas[id]):
			state.npcs[id][field] = clampi(int(view.npcs[id][field]) + int(deltas[id][field]), 0, catalog.integer("attribute_max"))
	var touched_evidence: Array = []
	var batch_sources: Dictionary = {}
	for action: Dictionary in actions:
		var rule: Dictionary = catalog.tables.npc_behaviors[action.behavior]
		var npc: Dictionary = state.npcs[action.actor]
		npc.acted_turn = state.turn
		if not npc.has("cooldowns"):
			npc.cooldowns = {}
		npc.cooldowns[action.behavior] = int(state.turn) + int(rule.cooldown_turns)
		if rule.repeat_policy != "repeat_until_threshold":
			npc.consumed_sources[action.consumed_key] = action.source
		var result: String = _record("npc_behavior", npc.domain, npc.id, [action.target], action.parents, {"behavior": action.behavior, "requested_amount": action.amount, "sanity_cost": int(rule.sanity_cost)})
		if not batch_sources.has(npc.domain):
			batch_sources[npc.domain] = []
		batch_sources[npc.domain].append(result)
		_know(npc.id, result)
		_know(action.target, result)
		if int(rule.sanity_cost) > 0:
			var strain: String = _record("strain", npc.domain, npc.id, [npc.id], [result], {"sanity_delta": -int(rule.sanity_cost)})
			_know(npc.id, strain)
		if rule.effect != "restore_self_sanity":
			_register_growth(npc, str(rule.attribute), action.source, result)
		if rule.effect == "gather_evidence":
			var institution_id: String = str(view.npcs[action.actor].institution)
			var key: String = institution_id + "|" + str(action.target)
			if not state.evidence.has(key):
				state.evidence[key] = {"institution": institution_id, "subject": action.target, "strength": 0, "sources": [], "confirmations": [], "contributions": {}}
			var evidence: Dictionary = state.evidence[key]
			if not evidence.has("contributions"):
				evidence.contributions = {}
			var contribution_key: String = str(action.actor) + "/" + str(action.source)
			if not evidence.contributions.has(contribution_key):
				evidence.contributions[contribution_key] = result
				evidence.strength += int(action.amount)
				evidence.sources = _unique_sorted(evidence.sources + [result])
				_institution_know(institution_id, action.source)
				_institution_know(institution_id, result)
				if not key in touched_evidence:
					touched_evidence.append(key)
		if rule.effect == "increase_self_loyalty" and view.facts[action.source].changes.get("public", false):
			var exposure: String = _record("exposure", npc.domain, npc.id, [npc.id], [action.source, result], {"public": true})
			state.domains[npc.domain].public_facts.append(exposure)
			state.domains[npc.domain].exposure_turn = state.turn
			if not domain_deltas.has(npc.domain):
				domain_deltas[npc.domain] = {"alert": 0, "sources": []}
			domain_deltas[npc.domain].alert += catalog.integer("interpretation_public_alert")
			domain_deltas[npc.domain].sources.append(exposure)
			for institution_id: String in state.domains[npc.domain].institutions:
				if not _institution_operational(state, institution_id):
					continue
				_institution_know(institution_id, exposure)
				var representative: String = state.institutions[institution_id].representative
				_know(representative, exposure)
		stats.actions += 1
	for domain_id: String in _keys(batch_sources):
		var actual: Dictionary = {}
		for id: String in _keys(deltas):
			if state.npcs[id].domain == domain_id:
				actual[id] = {}
				for field: String in _keys(deltas[id]):
					actual[id][field] = int(state.npcs[id][field]) - int(view.npcs[id][field])
		_record("npc_batch_applied", domain_id, "", actual.keys(), batch_sources[domain_id], {"actual_deltas": actual, "snapshot_turn": view.turn})
	touched_evidence.sort()
	for key: String in touched_evidence:
		var evidence: Dictionary = state.evidence[key]
		if int(evidence.strength) >= catalog.integer("evidence_confirmation_strength") and evidence.confirmations.is_empty():
			var institution: Dictionary = state.institutions[evidence.institution]
			var fact: String = _record("evidence_confirmed", institution.domain, "", [evidence.subject], evidence.sources, {"institution": institution.id, "strength": evidence.strength})
			evidence.confirmations.append(fact)
			_institution_know(institution.id, fact)
	return domain_deltas

func _register_growth(npc: Dictionary, attribute: String, source: String, result: String) -> void:
	if not npc.growth_sources.has(attribute):
		npc.growth_sources[attribute] = []
	if source in npc.growth_sources[attribute]:
		return
	npc.growth_sources[attribute].append(source)
	npc.growth_sources[attribute].sort()
	if npc.growth_sources[attribute].size() % catalog.integer("growth_distinct_sources_per_point") == 0 and int(npc[attribute]) < catalog.integer("npc_attribute_max"):
		npc[attribute] = mini(catalog.integer("npc_attribute_max"), int(npc[attribute]) + catalog.integer("growth_attribute_increment"))
		var growth: String = _record("attribute_growth", npc.domain, npc.id, [npc.id], npc.growth_sources[attribute] + [result], {"attribute": attribute, "value": npc[attribute]})
		_know(npc.id, growth)

func prepare_turn(owner: Object = null) -> bool:
	if not _driver_allowed(owner) or state.phase != "between" or (state.has("economy") and owner == null):
		return false
	state.turn += 1
	state.phase = "starting"
	return true

func finish_turn_start(owner: Object = null) -> bool:
	stage_current()
	if not _driver_allowed(owner) or state.phase != "starting":
		return false
	_resolve_plans()
	_succeed_cults()
	_refresh_anchors()
	state.whispers = mini(catalog.integer("whisper_cap"), catalog.integer("whisper_base") + int(floor(float(state.awakening) / catalog.number("whisper_growth_step"))))
	state.phase = "actions"
	return true

func begin_turn(owner: Object = null) -> bool:
	return prepare_turn(owner) and finish_turn_start(owner)

func mark_player_task(npc_id: String, owner: Object = null) -> bool:
	stage_collections(["npcs"])
	# Called after the actual player task has passed its own cost/eligibility checks.
	if not _driver_allowed(owner) or state.phase != "actions" or not state.npcs.has(npc_id) or state.npcs[npc_id].status != "active" or int(state.npcs[npc_id].acted_turn) == int(state.turn):
		return false
	state.npcs[npc_id].acted_turn = state.turn
	return true

func advance(owner: Object = null) -> Array:
	if not begin_turn(owner):
		return []
	return evolve(owner)

func _evolution_snapshot() -> Dictionary:
	# Facts are immutable, append-only records. Freeze mutable eligibility state,
	# including each reader's known fact IDs, without copying all archived history.
	# New facts are never scanned here: all candidates finish before batch writes.
	var view: Dictionary = state.duplicate(false)
	for field: String in ["domains", "institutions", "npcs", "evidence", "cults", "relics", "anchors", "invalid_records"]:
		view[field] = state[field].duplicate(true)
	if state.has("economy"):
		view.economy = state.economy.duplicate(true)
		view.economy_qualifications = state.economy_qualifications.duplicate(true)
	return view

func evolve(owner: Object = null, economic_batch: Dictionary = {}) -> Array:
	stage_current()
	# This is the autonomous evolution phase, not the entire six-phase game loop.
	if not _driver_allowed(owner) or state.phase != "actions" or (state.has("economy") and (economic_batch.is_empty() or economic_batch.get("turn") != state.turn)):
		return []
	var view: Dictionary = _evolution_snapshot()
	var actions: Array = []
	for npc_id: String in _keys(view.npcs):
		stats.npc_updates += 1
		var action: Dictionary = choose_behavior(npc_id, view)
		if not action.is_empty():
			actions.append(action)
	# Institution decisions also read this same snapshot; new NPC evidence is next-turn input.
	var plans: Array = []
	for domain_id: String in _keys(view.domains):
		var plan: Dictionary = choose_plan(domain_id, view)
		if not plan.is_empty():
			plans.append(plan)
	var npc_deltas: Dictionary = _apply_behaviors(actions, view)
	var economic_result: Dictionary = Economy.apply_batch(self, economic_batch, owner) if not economic_batch.is_empty() else {"ok": true, "changes": {}}
	if not economic_result.ok:
		return []
	var economic_deltas: Dictionary = economic_result.changes
	for domain_id: String in _keys(view.domains):
		var before: Dictionary = view.domains[domain_id]
		var domain: Dictionary = state.domains[domain_id]
		var changes: Dictionary = {}
		var parents: Array = [before.origin]
		var has_active_anchor: bool = false
		for anchor: Dictionary in view.anchors.values():
			if anchor.domain == domain_id and anchor.state == "active":
				has_active_anchor = true
		if not has_active_anchor and int(before.pollution_changed_turn) < int(state.turn):
			var prior: int = int(domain.pollution)
			domain.pollution = maxi(0, prior - catalog.integer("pollution_base_decay"))
			if prior != int(domain.pollution):
				changes.pollution_delta = int(domain.pollution) - prior
		var ongoing_public: bool = _has_public_anomaly(view, domain_id)
		var alert_delta: int = int(npc_deltas.get(domain_id, {}).get("alert", 0)) + int(economic_deltas.get(domain_id, {}).get("alert", 0))
		if int(domain.exposure_turn) < int(state.turn) and not ongoing_public:
			alert_delta -= catalog.integer("alert_quiet_decay")
		domain.alert = clampi(int(before.alert) + alert_delta, 0, catalog.integer("attribute_max"))
		if domain.alert != before.alert:
			changes.alert_delta = int(domain.alert) - int(before.alert)
			parents.append_array(npc_deltas.get(domain_id, {}).get("sources", []))
			if economic_deltas.has(domain_id):
				parents.append(economic_deltas[domain_id].source)
		var order_id: String = domain_id + "/order"
		if _institution_operational(view, order_id) and int(before.pollution_changed_turn) < int(state.turn) and not ongoing_public:
			var prior: int = int(domain.barrier)
			domain.barrier = mini(catalog.integer("attribute_max"), prior + catalog.integer("barrier_base_recovery"))
			if prior != int(domain.barrier):
				changes.barrier_delta = int(domain.barrier) - prior
				parents.append(before.barrier_source)
		if not changes.is_empty():
			changes.rule = "natural_evolution"
			changes.snapshot_turn = view.turn
			var fact: String = _record("natural_evolution", domain_id, "", [domain_id], parents, changes)
			if changes.has("barrier_delta"):
				domain.barrier_source = fact
	for plan: Dictionary in plans:
		var started: String = _record("resistance_started", plan.domain, "", [plan.target], plan.parents, {"plan": plan.rule, "due": plan.due, "institution": plan.institution})
		plan.started_fact = started
		state.domains[plan.domain].pending_plan = plan
		stats.plans_started += 1
	Economy.finalize(self)
	_refresh_anchors()
	state.phase = "between"
	return actions

func _public_carrier_valid(view: Dictionary, target: String, domain: String) -> bool:
	if view.npcs.has(target):
		return view.npcs[target].domain == domain and view.npcs[target].status == "active"
	if view.relics.has(target):
		return view.relics[target].domain == domain and not view.relics[target].placement in ["consumed", "sealed", "seized"]
	if view.institutions.has(target):
		return view.institutions[target].domain == domain and view.institutions[target].active
	return false

func _has_public_anomaly(view: Dictionary, domain_id: String) -> bool:
	for target: String in view.domains[domain_id].public_anomalies.values():
		if _public_carrier_valid(view, target, domain_id):
			return true
	return false

func _institution_operational(view: Dictionary, id: String) -> bool:
	if not view.institutions.has(id) or not view.institutions[id].active:
		return false
	var representative: String = str(view.institutions[id].representative)
	return view.npcs.has(representative) and view.npcs[representative].status == "active" and view.npcs[representative].domain == view.institutions[id].domain

func _succeed_cults() -> void:
	for cult_id: String in _keys(state.cults):
		var cult: Dictionary = state.cults[cult_id]
		if not cult.leader.is_empty() or cult.status == "destroyed":
			continue
		var eligible: Array = []
		for npc: Dictionary in state.npcs.values():
			if npc.domain == cult.domain and npc.status == "active" and int(npc.loyalty) >= catalog.integer("loyalty_follower_threshold"):
				eligible.append(npc)
		eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.influence != b.influence:
				return a.influence > b.influence
			if a.loyalty != b.loyalty:
				return a.loyalty > b.loyalty
			return a.id < b.id
		)
		if not eligible.is_empty():
			cult.leader = eligible[0].id
			cult.cohesion = maxi(0, int(cult.cohesion) - catalog.integer("cult_succession_cohesion_cost"))
			cult.status = "active" if cult.cohesion > 0 else "destroyed"
			if cult.has("succession_source"):
				_record("cult_succeeded", cult.domain, cult.leader, [cult.id], [cult.succession_source], {"cohesion_delta": -catalog.integer("cult_succession_cohesion_cost")})

func institution_successors(institution_id: String) -> Array:
	var eligible: Array = []
	if not state.institutions.has(institution_id):
		return eligible
	for id: String in _keys(state.npcs):
		var npc: Dictionary = state.npcs[id]
		if npc.status == "active" and npc.domain == state.institutions[institution_id].domain and int(npc.sanity) >= catalog.integer("institution_successor_min_sanity") and _profile_legal(catalog.tables.npc_profiles[npc.profile], npc.domain, institution_id):
			eligible.append(id)
	return eligible

func succeed_institution(institution_id: String, npc_id: String, cause: String, owner: Object = null) -> bool:
	if not _driver_allowed(owner):
		return false
	if not state.institutions.has(institution_id) or not state.facts.has(cause) or not npc_id in institution_successors(institution_id):
		return false
	# This effect is only callable by an authorized succession event, not NPC autonomy.
	if state.facts[cause].kind != "institution_succession_authorized" or state.facts[cause].domain != state.institutions[institution_id].domain or not institution_id in state.facts[cause].targets or not npc_id in state.facts[cause].targets:
		return false
	if state.applied_authorizations.has(cause):
		return state.applied_authorizations[cause] == "succession/" + institution_id + "/" + npc_id
	state.applied_authorizations[cause] = "succession/" + institution_id + "/" + npc_id
	state.institutions[institution_id].representative = npc_id
	state.npcs[npc_id].institution = institution_id
	_record("institution_succeeded", state.institutions[institution_id].domain, npc_id, [institution_id], [cause])
	return true

func confirm_exception(institution_id: String, record: String, authorization: String, owner: Object = null) -> bool:
	if not _driver_allowed(owner):
		return false
	if not _institution_operational(state, institution_id) or not state.facts.has(record) or not state.facts.has(authorization):
		return false
	var institution: Dictionary = state.institutions[institution_id]
	var fact: Dictionary = state.facts[record]
	var permit: Dictionary = state.facts[authorization]
	if institution.role != "interpretation" or fact.kind != "exception" or fact.domain != institution.domain or state.invalid_records.has(record) or not record in institution.known_facts:
		return false
	if permit.kind != "exception_confirmation_authorized" or permit.domain != institution.domain or not institution_id in permit.targets or not record in permit.targets or not record in permit.causal_parents:
		return false
	var key: String = institution_id + "|" + record
	if state.applied_authorizations.has(authorization):
		return state.applied_authorizations[authorization] == "confirm/" + key
	var confirmation: String = _record("evidence_confirmed", institution.domain, "", [record], [record, authorization], {"institution": institution_id, "strength": catalog.integer("evidence_confirmation_strength")})
	state.evidence[key] = {"institution": institution_id, "subject": record, "strength": catalog.integer("evidence_confirmation_strength"), "sources": [authorization], "confirmations": [confirmation]}
	state.applied_authorizations[authorization] = "confirm/" + key
	_institution_know(institution_id, confirmation)
	return true

func choose_plan(domain_id: String, view: Dictionary = {}) -> Dictionary:
	var current: Dictionary = state if view.is_empty() else view
	var domain: Dictionary = current.domains[domain_id]
	if not domain.pending_plan.is_empty():
		return {}
	var candidates: Array = []
	for rule_id: String in _keys(catalog.tables.resistance_plans):
		var rule: Dictionary = catalog.tables.resistance_plans[rule_id]
		var effect: Dictionary = catalog.tables.civilization_actions[rule_id]
		var institution_id: String = domain_id + "/" + str(effect.institution_role)
		if not _institution_operational(current, institution_id) or int(domain.alert) < int(rule.min_alert) or not domain.tier in str(rule.tier).split("|") or int(domain.plan_cooldowns.get(rule_id, -1)) >= int(current.turn):
			continue
		var institution: Dictionary = current.institutions[institution_id]
		var targets: Dictionary = {}
		if effect.evidence_requirement == "breach" and int(domain.barrier) <= catalog.integer("first_breach_threshold"):
			targets[domain_id] = [domain.barrier_source]
		elif effect.evidence_requirement == "exposed":
			for fact_id: String in institution.known_facts:
				var fact: Dictionary = current.facts[fact_id]
				if fact.kind != "exposure" or fact.domain != domain_id:
					continue
				for subject: String in fact.targets:
					var key: String = institution_id + "|" + subject
					if _subject_valid(current, subject, domain_id) and (not current.evidence.has(key) or current.evidence[key].confirmations.is_empty()):
						if not targets.has(subject):
							targets[subject] = []
						targets[subject].append(fact_id)
		else:
			for key: String in _keys(current.evidence):
				var evidence: Dictionary = current.evidence[key]
				if evidence.institution != institution_id or evidence.confirmations.is_empty():
					continue
				var subject: String = str(evidence.subject)
				match str(effect.evidence_requirement):
					"confirmed_npc":
						if current.npcs.has(subject) and _subject_valid(current, subject, domain_id) and int(current.npcs[subject].loyalty) >= catalog.integer("loyalty_follower_threshold"):
							for cult: Dictionary in current.cults.values():
								if cult.domain == domain_id and cult.status != "destroyed":
									targets[cult.id] = evidence.confirmations
					"confirmed_relic":
						if current.relics.has(subject) and _subject_valid(current, subject, domain_id):
							targets[subject] = evidence.confirmations
					"confirmed_anchor":
						for anchor: Dictionary in current.anchors.values():
							if anchor.domain == domain_id and anchor.state == "active" and subject in [anchor.guardian, anchor.relic]:
								targets[anchor.id] = evidence.confirmations
					"confirmed_exception":
						if current.facts.has(subject) and current.facts[subject].kind == "exception" and current.facts[subject].domain == domain_id and not current.invalid_records.has(subject):
							targets[subject] = evidence.confirmations
		for target: String in _keys(targets):
			var recent: int = -1
			for parent: String in targets[target]:
				recent = maxi(recent, int(current.facts[parent].turn))
			candidates.append({"rule": rule_id, "domain": domain_id, "institution": institution_id, "target": target, "parents": _unique_sorted(targets[target]), "priority": int(rule.priority), "recent": recent, "due": int(current.turn) + int(rule.warning_turns)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.recent != b.recent:
			return a.recent > b.recent
		return str(a.target) + "/" + str(a.rule) < str(b.target) + "/" + str(b.rule)
	)
	return {} if candidates.is_empty() else candidates[0]

func _plan_valid(plan: Dictionary) -> bool:
	if not _institution_operational(state, plan.institution):
		return false
	var effect: String = str(catalog.tables.civilization_actions[plan.rule].effect)
	match effect:
		"confirm_evidence":
			return _subject_valid(state, plan.target, plan.domain)
		"purge_cult":
			return state.cults.has(plan.target) and state.cults[plan.target].status != "destroyed"
		"seize_relic":
			return state.relics.has(plan.target) and _subject_valid(state, plan.target, plan.domain)
		"repair_barrier":
			return state.domains.has(plan.target)
		"destroy_anchor":
			return state.anchors.has(plan.target) and state.anchors[plan.target].state == "active"
		"rewrite_reality":
			return state.facts.has(plan.target) and not state.invalid_records.has(plan.target)
	return false

func _resolve_plans() -> void:
	for domain_id: String in _keys(state.domains):
		var domain: Dictionary = state.domains[domain_id]
		if domain.pending_plan.is_empty() or int(domain.pending_plan.due) > int(state.turn):
			continue
		var plan: Dictionary = domain.pending_plan
		var rule: Dictionary = catalog.tables.resistance_plans[plan.rule]
		var effect: Dictionary = catalog.tables.civilization_actions[plan.rule]
		var parents: Array = plan.parents + [plan.started_fact]
		if not _plan_valid(plan):
			_record("resistance_cancelled", domain_id, "", [plan.target], parents, {"rule": plan.rule, "reason": "target_or_institution_unavailable"})
			stats.plans_cancelled += 1
		else:
			var outcome: String = _record("resistance_resolved", domain_id, "", [plan.target], parents, {"rule": plan.rule, "effect": effect.effect})
			match str(effect.effect):
				"confirm_evidence":
					var key: String = str(plan.institution) + "|" + str(plan.target)
					if not state.evidence.has(key):
						state.evidence[key] = {"institution": plan.institution, "subject": plan.target, "strength": 0, "sources": [], "confirmations": []}
					state.evidence[key].strength = maxi(int(state.evidence[key].strength), catalog.integer("evidence_confirmation_strength"))
					state.evidence[key].sources = _unique_sorted(state.evidence[key].sources + plan.parents)
					if state.evidence[key].confirmations.is_empty():
						state.evidence[key].confirmations.append(outcome)
					_institution_know(plan.institution, outcome)
				"purge_cult":
					var loss: int = int(ceil(float(domain.unnamed_followers) * float(effect.followers_loss_ratio)))
					domain.unnamed_followers -= loss
					var eligible_removed: int = _consume_income_cohort(domain_id, loss)
					domain.population -= loss
					if state.has("economy"):
						var causes: Array = [outcome]
						if state.economy.cohort_sources.has(domain_id):
							causes.append(state.economy.cohort_sources[domain_id])
						_population_cause(domain_id, _record("population_transfer", domain_id, "", [], causes, {"mode": "death", "amount": loss, "eligible_removed": eligible_removed, "eligible_added": 0, "eligible_after": _cohort_values([domain_id]), "rule": "purge_cult"}))
					var cult: Dictionary = state.cults[plan.target]
					cult.cohesion = maxi(0, int(cult.cohesion) + int(effect.cohesion_delta))
					if domain.unnamed_followers == 0 or cult.cohesion == 0:
						cult.status = "destroyed"
				"seize_relic":
					var relic: Dictionary = state.relics[plan.target]
					relic.holder = ""
					relic.placement = "seized"
					relic.captor = plan.institution
				"repair_barrier":
					domain.barrier = mini(catalog.integer("attribute_max"), int(domain.barrier) + int(effect.barrier_delta))
					domain.barrier_source = outcome
					domain.pollution = maxi(0, int(domain.pollution) + int(effect.pollution_delta))
				"destroy_anchor":
					state.anchors[plan.target].state = "destroyed"
					state.anchors[plan.target].needs_rebind = true
				"rewrite_reality":
					state.wounds += int(effect.wounds_delta)
					domain.pollution = maxi(0, int(domain.pollution) + int(effect.pollution_delta))
			stats.plans_resolved += 1
		domain.plan_cooldowns[plan.rule] = int(state.turn) + int(rule.cooldown_turns)
		domain.pending_plan = {}
	_refresh_anchors()

func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
	if not candidate.get("next_fact") is int or int(candidate.next_fact) < int(trusted.next_fact):
		return ["Fact sequence moved backwards"]
	if not candidate.get("facts") is Dictionary or candidate.facts.size() != trusted.facts.size() + int(candidate.next_fact) - int(trusted.next_fact):
		return ["Fact sequence and append count disagree"]
	return _validate_state(candidate, int(trusted.next_fact))

func validate_state(candidate: Dictionary) -> Array[String]:
	return _validate_state(candidate, 0)

func _validate_state(candidate: Dictionary, first_new_fact: int) -> Array[String]:
	var issues: Array[String] = []
	for key: String in ["domains", "institutions", "npcs", "facts", "evidence", "cults", "relics", "anchors", "applied_authorizations", "invalid_records"]:
		if not candidate.get(key) is Dictionary:
			issues.append("Missing collection: " + key)
	for key: String in ["turn", "next_npc", "next_fact", "faith", "insight", "wounds", "awakening", "peak_awakening", "whispers"]:
		if not candidate.get(key) is int or int(candidate[key]) < 0:
			issues.append("Invalid scalar: " + key)
	if not issues.is_empty():
		return issues
	if not candidate.get("phase", "") in ["between", "starting", "actions"]:
		issues.append("Invalid turn phase")
	for collection: String in ["domains", "institutions", "npcs", "facts", "evidence", "cults", "relics", "anchors"]:
		if collection == "facts" and first_new_fact > 0:
			continue
		for entry: Variant in candidate[collection].values():
			if not entry is Dictionary:
				issues.append("Non-object collection member")
	if not issues.is_empty():
		return issues
	var populations: Dictionary = {}
	var living: int = 0
	var max_npc_id: int = 0
	var max_fact_id: int = maxi(0, first_new_fact - 1)
	for id: String in candidate.domains:
		var domain: Variant = candidate.domains[id]
		if not domain is Dictionary or domain.get("id") != id or not catalog.tables.civilization_profiles.has(domain.get("profile", "")):
			issues.append("Invalid domain")
			continue
		populations[id] = 0
		for field: String in ["barrier", "pollution", "alert", "stability"]:
			if not domain.get(field) is int or int(domain[field]) < 0 or int(domain[field]) > catalog.integer("attribute_max"):
				issues.append("Invalid domain metric")
		for field: String in ["population", "unnamed_nonfollowers", "unnamed_followers"]:
			if not domain.get(field) is int or int(domain[field]) < 0:
				issues.append("Invalid population")
		for field: String in ["neighbors", "institutions", "crisis_facts", "public_facts"]:
			if not domain.get(field) is Array:
				issues.append("Invalid domain list")
		for field: String in ["pending_plan", "plan_cooldowns", "public_anomalies"]:
			if not domain.get(field) is Dictionary:
				issues.append("Invalid plan collection")
	for id: String in candidate.npcs:
		var npc: Variant = candidate.npcs[id]
		if not npc is Dictionary or npc.get("id") != id or not candidate.domains.has(npc.get("domain", "")) or not catalog.tables.npc_profiles.has(npc.get("profile", "")) or not npc.get("status", "") in STATUSES:
			issues.append("Invalid NPC")
			continue
		max_npc_id = maxi(max_npc_id, int(id.get_slice("-", 1)))
		for attribute: String in ATTRIBUTES + ["sanity", "loyalty"]:
			var maximum: int = catalog.integer("npc_attribute_max") if attribute in ATTRIBUTES else catalog.integer("attribute_max")
			if not npc.get(attribute) is int or int(npc[attribute]) < 0 or int(npc[attribute]) > maximum:
				issues.append("Invalid NPC attribute")
		for key: String in ["known_facts", "relations", "role_tags", "need_tags"]:
			if not npc.get(key) is Array and not npc.get(key) is PackedStringArray:
				issues.append("Invalid NPC list")
		for key: String in ["consumed_sources", "growth_sources"]:
			if not npc.get(key) is Dictionary:
				issues.append("Invalid NPC source collection")
		if not npc.get("acted_turn") is int or not candidate.facts.has(npc.get("status_source", "")):
			issues.append("Missing NPC execution/status state")
		if npc.status != "dead":
			populations[npc.domain] = int(populations.get(npc.domain, 0)) + 1
			living += 1
	if not issues.is_empty():
		return issues
	if living > catalog.integer("living_named_global_limit"):
		issues.append("Living named budget exceeded")
	for id: String in candidate.domains:
		var domain: Dictionary = candidate.domains[id]
		if int(domain.population) != int(domain.unnamed_nonfollowers) + int(domain.unnamed_followers) + int(populations[id]) or int(domain.population) > catalog.integer("domain_population_capacity"):
			issues.append("Population conservation failed")
		for neighbor: Variant in domain.neighbors:
			if not neighbor is String or not candidate.domains.has(neighbor) or not id in candidate.domains[neighbor].neighbors:
				issues.append("Invalid reciprocal route")
		for fact_id: Variant in domain.crisis_facts + domain.public_facts + [domain.origin, domain.barrier_source]:
			if not fact_id is String or not candidate.facts.has(fact_id):
				issues.append("Unknown domain fact")
		if not domain.pending_plan.is_empty():
			var plan: Dictionary = domain.pending_plan
			if not catalog.tables.resistance_plans.has(plan.get("rule", "")) or not candidate.institutions.has(plan.get("institution", "")) or not candidate.facts.has(plan.get("started_fact", "")) or not plan.get("due") is int or not plan.get("parents") is Array or not plan.get("target") is String:
				issues.append("Invalid pending plan")
			else:
				for parent: Variant in plan.parents:
					if not parent is String or not candidate.facts.has(parent):
						issues.append("Unknown pending cause")
	for id: String in candidate.institutions:
		var institution: Variant = candidate.institutions[id]
		if not institution is Dictionary or institution.get("id") != id or not candidate.domains.has(institution.get("domain", "")) or not institution.get("known_facts") is Array or not institution.get("active") is bool:
			issues.append("Invalid institution")
			continue
		if not institution.get("representative", "").is_empty():
			var person: String = institution.representative
			if not candidate.npcs.has(person) or candidate.npcs[person].status == "dead" or candidate.npcs[person].domain != institution.domain:
				issues.append("Invalid institution representative")
		for fact_id: Variant in institution.known_facts:
			if not fact_id is String or not candidate.facts.has(fact_id):
				issues.append("Unknown institution knowledge")
	var fact_ids: Array = candidate.facts.keys() if first_new_fact == 0 else []
	if first_new_fact > 0:
		for number: int in range(first_new_fact, int(candidate.next_fact)):
			fact_ids.append("FACT-%08d" % number)
	for id: String in fact_ids:
		if not candidate.facts.has(id):
			issues.append("Missing newly allocated fact")
			continue
		var fact: Variant = candidate.facts[id]
		if not fact is Dictionary or fact.get("id") != id or not fact.get("turn") is int or int(fact.turn) < 0 or int(fact.turn) > int(candidate.turn) or not fact.get("causal_parents") is Array or not fact.get("targets") is Array or not fact.get("changes") is Dictionary:
			issues.append("Invalid fact")
			continue
		max_fact_id = maxi(max_fact_id, int(id.get_slice("-", 1)))
		for parent: Variant in fact.causal_parents:
			if not parent is String or not candidate.facts.has(parent) or parent >= id or int(candidate.facts[parent].get("turn", -1)) > int(fact.turn):
				issues.append("Invalid causal ancestry")
	for npc: Dictionary in candidate.npcs.values():
		for fact_id: Variant in npc.known_facts:
			if not fact_id is String or not candidate.facts.has(fact_id):
				issues.append("Unknown person knowledge")
		for relation: Variant in npc.relations:
			if not relation is Dictionary or not candidate.npcs.has(relation.get("target", "")) or not candidate.facts.has(relation.get("source", "")):
				issues.append("Invalid social relationship")
		for source: Variant in npc.consumed_sources.values():
			if not source is String or not candidate.facts.has(source):
				issues.append("Invalid consumed source")
		for attribute: String in npc.growth_sources:
			if not attribute in ATTRIBUTES or not npc.growth_sources[attribute] is Array:
				issues.append("Invalid growth record")
				continue
			for source: Variant in npc.growth_sources[attribute]:
				if not source is String or not candidate.facts.has(source):
					issues.append("Invalid growth source")
	for evidence: Variant in candidate.evidence.values():
		if not evidence is Dictionary or not candidate.institutions.has(evidence.get("institution", "")) or not evidence.get("sources") is Array or not evidence.get("confirmations") is Array or not evidence.get("strength") is int:
			issues.append("Invalid evidence")
			continue
		for source: Variant in evidence.sources + evidence.confirmations:
			if not source is String or not candidate.facts.has(source):
				issues.append("Invalid evidence source")
	for relic: Dictionary in candidate.relics.values():
		if not candidate.domains.has(relic.get("domain", "")) or not relic.get("placement", "") in ["carried", "controlled", "bound", "ground", "seized", "consumed", "sealed"]:
			issues.append("Invalid relic")
		if not str(relic.get("holder", "")).is_empty() and (not candidate.npcs.has(relic.holder) or candidate.npcs[relic.holder].status == "dead"):
			issues.append("Invalid relic holder")
	for anchor: Dictionary in candidate.anchors.values():
		if not candidate.domains.has(anchor.get("domain", "")) or not candidate.institutions.has(anchor.get("institution", "")) or not anchor.get("state", "") in ["absent", "active", "dormant", "destroyed"]:
			issues.append("Invalid anchor")
		if anchor.state == "active" and (not candidate.npcs.has(anchor.get("guardian", "")) or candidate.npcs[anchor.guardian].status != "active" or not candidate.relics.has(anchor.get("relic", "")) or candidate.relics[anchor.relic].placement != "bound"):
			issues.append("Invalid active anchor")
	if int(candidate.next_npc) <= max_npc_id or int(candidate.next_fact) <= max_fact_id:
		issues.append("Identity sequence would reuse an existing ID")
	if issues.is_empty():
		issues.append_array(Economy.validate_state(candidate, catalog))
	return issues
