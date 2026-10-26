extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## Pure-data rule core. UI and prose may not mutate the state directly.
## The public state is inspectable for tools; game adapters submit validated commands.

const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const Attention = preload("res://src/game/attention.gd")
const AbstractSim = preload("res://src/simulation/abstract_sim.gd")
const Catalog = preload("res://src/simulation/catalog.gd")
const Economy = preload("res://src/game/economy.gd")
const ATTRIBUTES: Array[String] = ["will", "insight", "influence", "adaptation"]
const STATUSES: Array[String] = ["active", "detained", "missing", "dead"]
const Cults = preload("res://src/game/cults.gd")
const Powers = preload("res://src/game/powers.gd")
const Relics = preload("res://src/game/relics.gd")
const INTEGRATION_FACTS: Array[String] = ["member_dedication", "member_leave_authorized", "background_successor_authorized", "miracle", "exposure", "harm", "strain", "crisis", "exception", "message", "institution_succession_authorized", "exception_confirmation_authorized", "public_anomaly", "anomaly_resolved", "cult_establishment_authorized", "power_qualification", "relic_create_authorized", "relic_recover_authorized", "relic_seize_authorized", "relic_seal_authorized", "relic_destroy_authorized"]
const SCHEMA_VERSION: int = 1
var attention: RefCounted
var abstract_sim: RefCounted
var catalog: RefCounted
var state: Dictionary = {}
var randoms: Dictionary = {}
var last_error: String = ""
var _turn_owner: WeakRef = null
var transaction: RefCounted = null
var participant_read: bool = false
var history: RefCounted = null
var stats: Dictionary = {"npc_updates": 0, "actions": 0, "plans_started": 0, "plans_resolved": 0, "plans_cancelled": 0}

func _init(content: RefCounted) -> void:
	catalog = content
	abstract_sim = AbstractSim.new(content)
	attention = Attention.new(content, abstract_sim)

static func canonical(value: Variant) -> String:
	return JSON.stringify(HistoryIndex.export_value(value), "", true, true)

func ensure_history(force: bool = false) -> bool:
	if participant_read:
		return false
	if not force and history != null and is_same(history.source_root, state):
		HistoryIndex.work_metrics = history.metrics
		return true
	var next_history: RefCounted = HistoryIndex.new()
	if next_history.page_limit <= 0:
		last_error = "Invalid authored history query policy"
		return false
	state = HistoryIndex.export_value(state)
	history = next_history
	history.configure(catalog.tables.npc_behaviors)
	history.rebuild(state)
	return true

func _history_learn(owner: String, source: String, institution: bool = false) -> void:
	if history != null:
		history.learn(state, owner, source, institution)

func _history_person(id: String) -> void:
	if history != null:
		history.refresh_person(state, id)

func _history_evidence(key: String) -> void:
	if history != null:
		history.refresh_evidence(state, key)

func _held_relic_ids(person: String) -> Array:
	return _keys(state.relics) if history == null else history.ids("holder/" + person)

func _living_ids() -> Array:
	return _keys(state.npcs) if history == null else history.ids("living")

func _keys(collection: Dictionary) -> Array:
	var ids: Array = Store.keys(collection)
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
	stage_collections(["domains", "institutions", "npcs", "evidence", "cults", "relics", "anchors", "economy", "economy_qualifications", "simulation", "attention", "cult_system", "power_system", "relic_system"])

func _next_id(prefix: String, counter: String) -> String:
	var id: String = "%s-%08d" % [prefix, int(state[counter])]
	state[counter] += 1
	return id

func _record(kind: String, domain: String, actor: String, targets: Array, parents: Array, changes: Dictionary = {}) -> String:
	# Parents are explicit causes, never the last historical record.
	for parent: String in parents:
		assert(Store.has(state.facts, parent), "Unknown cause: " + parent)
	stage_collections(["facts"])
	var id: String = _next_id("FACT", "next_fact")
	Store.put(state.facts, id, {"id": id, "turn": state.turn, "kind": kind, "domain": domain, "actor": actor, "targets": _unique_sorted(targets), "causal_parents": _unique_sorted(parents), "changes": changes.duplicate(true)})
	Transaction.freeze(Store.entry(state.facts, id))
	return id

func _know(npc_id: String, fact: String) -> void:
	if Store.has(state.npcs, npc_id) and not HistoryIndex.has(Store.entry(state.npcs, npc_id).known_facts, fact):
		Store.entry(state.npcs, npc_id).known_facts = HistoryIndex.set_value(Store.entry(state.npcs, npc_id).known_facts, fact)
		_history_learn(npc_id, fact)

func _institution_know(institution_id: String, fact: String) -> void:
	if state.institutions.has(institution_id) and not HistoryIndex.has(state.institutions[institution_id].known_facts, fact):
		state.institutions[institution_id].known_facts = HistoryIndex.set_value(state.institutions[institution_id].known_facts, fact)
		_history_learn(institution_id, fact, true)

func check_probability(npc_id: String, attribute: String, domain_id: String, mode: String = "occult", preparation: int = 0) -> int:
	if not Store.has(state.npcs, npc_id) or not state.domains.has(domain_id) or not attribute in ATTRIBUTES or not mode in ["social", "occult"]:
		return -1
	var npc: Dictionary = Store.entry(state.npcs, npc_id)
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
	for npc_id: String in _living_ids():
		var npc: Dictionary = Store.entry(state.npcs, npc_id)
		if npc.status != "dead":
			total += 1
	return total

func _new_npc(profile: Dictionary, domain_id: String, institution_id: String, source: String) -> String:
	var id: String = _next_id("NPC", "next_npc")
	var npc: Dictionary = {"id": id, "profile": profile.id, "domain": domain_id, "institution": institution_id, "status": "active", "known_facts": [source], "relations": [], "consumed_sources": {}, "growth_sources": {}, "acted_turn": -1, "status_source": source, "role_tags": str(profile.role_tags).split(";"), "need_tags": str(profile.need_tags).split(";")}
	for attribute: String in ATTRIBUTES + ["sanity", "loyalty"]:
		npc[attribute] = int(profile[attribute])
	if state.has("attention") or state.has("cult_system"):
		npc["bound_member"] = false; npc["cult_id"] = ""; npc["binding_source"] = source; npc["dedication_source"] = ""
		if state.has("attention"): state.attention.living_count += 1
	Store.put(state.npcs, id, npc)
	_history_person(id)
	_history_learn(id, source)
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
		state = HistoryIndex.export_value(state)
		history = null
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
		if not parent is String or not Store.has(state.facts, parent):
			last_error = "Missing cause"
			return false
	var kind: String = str(command.kind)
	if kind in ["population", "establish_cult", "economy_qualification"]:
		var accepted: bool = _economy_command(command)
		if accepted and not defer_lifecycle:
			Economy.refresh_cults(self)
			_refresh_anchors()
		return accepted
	if kind == "background_successor":
		return fix_background_successor(str(command.get("authorization", "")), owner)
	if kind == "nominate":
		return _nominate(command)
	if not command.has("npc") or not Store.has(state.npcs, command.npc):
		last_error = "Unknown person"
		return false
	var npc: Dictionary = Store.entry(state.npcs, command.npc)
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
		_history_person(npc.id)
		_detach_roles(npc)
		npc.domain = target
		_history_person(npc.id)
		npc.institution = ""
		for relic_id: String in _held_relic_ids(npc.id):
			var relic: Dictionary = Store.entry(state.relics, relic_id)
			if relic.holder == npc.id and relic.placement == "carried":
				relic.domain = target
				if relic.get("formal", false): relic.status_source = fact
				if history != null: history.refresh_relic(state, relic_id)
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
		if not parent is String or not Store.has(state.facts, parent):
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
			if not command.get("authorization") is String or not command.authorization in command.parents or not Store.has(state.facts, command.authorization) or Store.has(state.applied_authorizations, command.authorization):
				return false
			var fact: Dictionary = Store.entry(state.facts, command.authorization)
			var data: Dictionary = fact.changes
			if fact.kind != "cult_establishment_authorized" or not data.get("cult") is String or str(data.cult).is_empty() or not state.domains.has(data.get("domain", "")) or fact.domain != data.domain or not Store.has(state.npcs, data.get("leader", "")) or not data.get("cohesion") is int or int(data.cohesion) <= 0 or int(data.cohesion) > catalog.integer("attribute_max") or state.economy.issuers.get(data.get("issuer", ""), null) != data.get("version", "INVALID"):
				return false
			var leader: Dictionary = Store.entry(state.npcs, data.leader)
			if (Attention.enabled(state) and not leader.get("bound_member", false)) or leader.status != "active" or leader.domain != data.domain or int(leader.loyalty) < catalog.integer("loyalty_follower_threshold") or int(state.domains[data.domain].unnamed_followers) <= 0:
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
			var data: Dictionary = Store.entry(state.facts, command.authorization).changes
			var source: String = _record("cult_established", data.domain, data.leader, [data.leader], command.parents, {"cult": data.cult, "authorization": command.authorization})
			var origin: String = state.cults[data.cult].origin if state.cults.has(data.cult) else source
			state.cults[data.cult] = {"id": data.cult, "domain": data.domain, "leader": data.leader, "cohesion": data.cohesion, "status": "active", "origin": origin, "established_turn": state.turn, "established_source": source, "strategy": "hold", "succession_source": source}
			if not state.economy.remainders.has(data.cult):
				state.economy.remainders[data.cult] = 0
			stage_collections(["applied_authorizations"])
			Store.put(state.applied_authorizations, command.authorization, source)
		"economy_qualification":
			var collection: Dictionary = state.cults if command.rule == "propagation" else state.anchors
			var data: Dictionary = command.duplicate(true)
			data.erase("kind")
			data.erase("parents")
			var source: String = _record("economy_qualification", collection[command.subject].domain, "", [command.subject, command.institution], command.parents, data)
			state.economy_qualifications[command.rule + "|" + command.subject] = source
	return true

func _nominate(command: Dictionary, local_expansion: bool = false) -> bool:
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
	if Attention.enabled(state) and not local_expansion:
		if not attention.claim_identity(self, str(command.get("attention_token", "")), str(command.get("identity_key", "")), "NPC-%08d" % int(state.next_npc)): return false
	state.domains[domain_id][group] -= 1
	var eligible_removed: int = 0
	if group == "unnamed_followers":
		eligible_removed = _consume_income_cohort(domain_id, 1)
	var id: String = _new_npc(catalog.tables.npc_profiles[profile_id], domain_id, institution, command.parents[0])
	if group == "unnamed_followers":
		Store.entry(state.npcs, id).loyalty = maxi(int(Store.entry(state.npcs, id).loyalty), catalog.integer("loyalty_follower_threshold"))
	var parents: Array = command.parents.duplicate()
	if state.has("economy") and state.economy.cohort_sources.has(domain_id):
		parents.append(state.economy.cohort_sources[domain_id])
	var fact: String = _record("nomination", domain_id, id, [id], _unique_sorted(parents), {"from_group": group, "eligible_removed": eligible_removed, "eligible_after": _cohort_values([domain_id])})
	_population_cause(domain_id, fact)
	_know(id, fact)
	Economy.refresh_cults(self)
	_refresh_anchors()
	return true

func _detach_roles(npc: Dictionary, source: String = "") -> void:
	for institution: Dictionary in state.institutions.values():
		if institution.representative == npc.id:
			institution.representative = ""
			if institution.has("occupancy"): institution.occupancy = "vacant"
	for cult: Dictionary in state.cults.values():
		if cult.leader == npc.id:
			cult.leader = ""
			cult.succession_source = npc.status_source if source.is_empty() else source
			cult.status = "dormant"
	for anchor: Dictionary in state.anchors.values():
		if anchor.guardian == npc.id:
			anchor.guardian = ""
			if anchor.state != "destroyed":
				anchor.state = "dormant"
			anchor.needs_rebind = true

func _change_status(npc: Dictionary, next_status: String, parents: Array) -> void:
	var old: String = str(npc.status)
	if Attention.enabled(state) and next_status == "dead" and npc.id in attention.occupied(state, "people"): state.attention.used_p[npc.id] = state.turn
	var fact: String = _record("status_change", npc.domain, npc.id, [npc.id], parents, {"from": old, "to": next_status})
	npc.status = next_status
	npc.status_source = fact
	_history_person(npc.id)
	_know(npc.id, fact)
	if next_status == "dead" and Attention.enabled(state):
		state.attention.living_count -= 1
		attention.leave(self, npc.id, fact)
	if next_status == "dead" and state.has("cult_system") and not Attention.enabled(state):
		Cults.membership(self, "leave", npc.id, fact)
	if next_status == "dead":
		_detach_roles(npc)
	if next_status == "dead":
		state.domains[npc.domain].population -= 1
		for relic_id: String in _held_relic_ids(npc.id):
			var relic: Dictionary = Store.entry(state.relics, relic_id)
			if relic.holder == npc.id:
				relic.holder = ""
				relic.placement = "controlled" if _has_cult(npc.domain) else "ground"
				if relic.get("formal", false): relic.status_source = fact
				if history != null: history.refresh_relic(state, relic_id)
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
		var valid: bool = Store.has(state.npcs, anchor.guardian) and _active(Store.entry(state.npcs, anchor.guardian)) and Store.entry(state.npcs, anchor.guardian).domain == anchor.domain
		if Attention.enabled(state) and valid: valid = Store.entry(state.npcs, anchor.guardian).get("bound_member", false)
		valid = valid and Store.has(state.relics, anchor.relic) and Store.entry(state.relics, anchor.relic).placement == "bound" and Store.entry(state.relics, anchor.relic).get("anchor", "") == anchor.id
		valid = valid and state.institutions.has(anchor.institution) and state.institutions[anchor.institution].active
		if valid and state.has("economy"):
			var qualified: Dictionary = Economy.anchor_eligibility(state, anchor, catalog)
			valid = qualified.reason.is_empty() if qualified.ok else Economy.anchor_physical_reason(state, anchor, catalog).is_empty()
		if not valid:
			anchor.state = "dormant"
		else:
			contribution += catalog.integer("anchor_" + str(state.domains[anchor.domain].tier) + "_contribution")
	state.awakening = clampi(catalog.integer("initial_awakening") + int(state.insight) + contribution - int(state.wounds), 0, catalog.integer("awakening_before_final_cap"))
	if state.has("power_system") and not state.power_system.get("completion", "").is_empty():
		state.awakening = catalog.integer("awakening_terminal")
	state.peak_awakening = maxi(int(state.peak_awakening), int(state.awakening))

func snapshot() -> String:
	var streams: Dictionary = {}
	for name: String in _keys(randoms):
		streams[name] = {"seed": str(randoms[name].seed), "state": str(randoms[name].state)}
	var body: Dictionary = {"schema": SCHEMA_VERSION, "content": catalog.version, "engine": Engine.get_version_info().string, "state": state, "randoms": streams, "stats": stats}
	if state.has("simulation"): body["simulation_policy"] = state.simulation.policy
	if state.has("attention"): body["attention_policy"] = state.attention.policy
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
	if HistoryIndex.contains_reserved(envelope.body):
		last_error = "Internal history marker in serialized input"
		return false
	var body: Dictionary = _normalize_numbers(envelope.body)
	if canonical(body).sha256_text() != envelope.checksum or body.get("schema") != SCHEMA_VERSION or body.get("content") != catalog.version or body.get("engine") != Engine.get_version_info().string:
		last_error = "Incompatible or damaged save"
		return false
	if not body.get("state") is Dictionary or not body.get("randoms") is Dictionary or not body.get("stats") is Dictionary:
		last_error = "Incomplete save"
		return false
	if body.has("simulation_policy") != body.state.has("simulation") or (body.state.has("simulation") and (not body.state.simulation is Dictionary or body.get("simulation_policy") != body.state.simulation.get("policy"))):
		last_error = "Snapshot simulation marker disagrees"
		return false
	if body.has("attention_policy") != body.state.has("attention") or (body.state.has("attention") and (not body.state.attention is Dictionary or body.get("attention_policy") != body.state.attention.get("policy"))):
		last_error = "Snapshot attention marker disagrees"
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
	history = null
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

func generate(seed_value: int, owner: Object = null, hybrid: bool = false) -> bool:
	if hybrid and attention.version.is_empty():
		last_error = "Invalid attention policy"
		return false
	var query_policy: RefCounted = HistoryIndex.new()
	if query_policy.page_limit <= 0:
		last_error = "Invalid authored history query policy"
		return false
	if not _driver_allowed(owner):
		return false
	# Authored tier budgets and lawful jobs are generated before any requests.
	var old_state: Dictionary = state
	var old_randoms: Dictionary = randoms
	history = null
	state = {"turn": 0, "phase": "between", "applied_authorizations": {}, "invalid_records": {}, "domains": {}, "institutions": {}, "npcs": {}, "facts": {}, "evidence": {}, "cults": {}, "relics": {}, "anchors": {}, "next_npc": 1, "next_fact": 1, "faith": catalog.integer("initial_faith"), "insight": catalog.integer("initial_insight"), "wounds": catalog.integer("initial_wounds"), "awakening": catalog.integer("initial_awakening"), "peak_awakening": catalog.integer("initial_awakening"), "whispers": catalog.integer("whisper_base")}
	if hybrid: state["attention"] = attention.initialize()
	var focused: Array = []
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
		var named_budget: int = catalog.integer("initial_named_per_domain")
		if hybrid:
			if index < int(attention.parameters.initial_focused_domains): focused.append(id)
			named_budget = int(attention.parameters.local_actor_limit) if id in focused else 0
		var domain: Dictionary = {"id": id, "profile": profile.id, "tier": tier, "communication": profile.communication, "authority": profile.authority, "barrier": int(profile.barrier), "stability": int(profile.stability), "pollution": 0, "alert": 0, "population": catalog.integer("domain_population"), "unnamed_nonfollowers": catalog.integer("domain_population") - named_budget, "unnamed_followers": 0, "neighbors": [], "institutions": [], "crisis_facts": [], "public_facts": [], "public_anomalies": {}, "pending_plan": {}, "plan_cooldowns": {}, "barrier_source": "", "pollution_changed_turn": -1, "exposure_turn": -1}
		for paradigm: String in ["tech", "occult", "faith", "meme"]:
			domain[paradigm] = int(profile[paradigm])
		state.domains[id] = domain
		var origin: String = _record("world_origin", id, "", [], [], {"profile": profile.id})
		domain.origin = origin
		domain.barrier_source = origin
		for role: String in ["interpretation", "propagation", "order"]:
			var institution_id: String = id + "/" + role
			state.institutions[institution_id] = {"id": institution_id, "domain": id, "role": role, "active": true, "representative": "", "known_facts": [origin], "links": [], "source": origin}
			if hybrid: state.institutions[institution_id]["occupancy"] = "occupied_abstract"
			domain.institutions.append(institution_id)
		for institution_id: String in domain.institutions:
			for other: String in domain.institutions:
				if other != institution_id:
					state.institutions[institution_id].links.append(other)
		# A context is not fabricated after selecting an incompatible profile.
		for institution_id: String in domain.institutions:
			if hybrid and named_budget <= 0: continue
			var lawful: Array = _profiles_for(id, institution_id)
			if lawful.is_empty():
				state = old_state
				randoms = old_randoms
				last_error = "No legal institution representative"
				return false
			var person_id: String = _new_npc(lawful[randoms.generation.randi_range(0, lawful.size() - 1)], id, institution_id, origin)
			state.institutions[institution_id].representative = person_id
			if hybrid: state.institutions[institution_id].occupancy = "represented"
		for index_npc: int in maxi(0, named_budget - catalog.integer("institutions_per_domain")):
			var institution_id: String = domain.institutions[index_npc % domain.institutions.size()]
			var lawful: Array = _profiles_for(id, institution_id)
			_new_npc(lawful[randoms.generation.randi_range(0, lawful.size() - 1)], id, institution_id, origin)
		var residents: Array = []
		for person_id: String in _keys(state.npcs):
			if Store.entry(state.npcs, person_id).domain == id:
				residents.append(person_id)
		for resident_index: int in residents.size():
			var person: Dictionary = Store.entry(state.npcs, residents[resident_index])
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
	if hybrid:
		state["simulation"] = abstract_sim.initialize(state, str(randoms.generation.seed), focused, [], [])
		state.simulation.mode = "hybrid"; state.simulation.schema = 2
		if not ensure_history(): state = old_state; randoms = old_randoms; return false
		attention.sync(self)
		var summary: Dictionary = _background_snapshot(_evolution_snapshot())
		var contact: Dictionary = abstract_sim.propose(summary, [focused[0]], "candidate_generation", true)
		if not contact.ok or contact.proposals.is_empty() or not _fix_background(contact.proposals[0], 1):
			state = old_state; randoms = old_randoms; history = null; last_error = "Hybrid initial contact unavailable"; return false
		state.simulation.cursors[focused[0]] = contact.cursors[focused[0]]
		state.simulation.bootstrap = true
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
	if int(profile.requires_crisis) and HistoryIndex.size(domain.crisis_facts) == 0:
		return false
	if int(profile.requires_listener):
		# Nomination must supply a relation first; do not generate a phantom audience.
		return false
	return true

func introduce_fact(kind: String, domain_id: String, actor: String, targets: Array, parents: Array, details: Dictionary, observers: Array, institutions: Array = [], owner: Object = null) -> String:
	stage_collections(["domains", "npcs", "institutions"])
	if not _driver_allowed(owner) or HistoryIndex.contains_reserved(details):
		return ""
	# Trusted integration boundary for actual player/event outcomes. It does not
	# implement the originating prayer or power, nor grant its rewards.
	if not kind in INTEGRATION_FACTS or not state.domains.has(domain_id) or parents.is_empty():
		return ""
	for parent: Variant in parents:
		if not parent is String or not Store.has(state.facts, parent):
			return ""
	for person_id: String in observers:
		if not Store.has(state.npcs, person_id) or Store.entry(state.npcs, person_id).status != "active" or (kind != "message" and Store.entry(state.npcs, person_id).domain != domain_id):
			return ""
	for institution_id: String in institutions:
		if not state.institutions.has(institution_id):
			return ""
	if not actor.is_empty() and not Store.has(state.npcs, actor):
		return ""
	for target: String in targets:
		if not Store.has(state.npcs, target) and not Store.has(state.relics, target) and not state.anchors.has(target) and not state.institutions.has(target) and not (kind == "exception_confirmation_authorized" and Store.has(state.facts, target) and Store.entry(state.facts, target).kind == "exception") and not (kind == "power_qualification" and (state.cults.has(target) or Store.has(state.facts, target))):
			return ""
	if kind == "public_anomaly" and (targets.size() != 1 or not _public_carrier_valid(state, targets[0], domain_id)):
		return ""
	if kind == "anomaly_resolved" and (not HistoryIndex.has(state.domains[domain_id].public_anomalies, str(details.get("source", ""))) or not str(details.get("source", "")) in parents):
		return ""
	if kind == "miracle":
		for witness: Variant in details.get("witnesses", []):
			if not witness is String or not Store.has(state.npcs, witness) or Store.entry(state.npcs, witness).status != "active" or not witness in observers:
				return ""
	var fact: String = _record(kind, domain_id, actor, targets, parents, details)
	if kind == "member_dedication" and (Attention.enabled(state) or state.has("cult_system")):
		for person_id: String in targets:
			if Store.has(state.npcs, person_id): mutable_npc(person_id).dedication_source = fact
	for person_id: String in observers:
		_know(person_id, fact)
	for institution_id: String in institutions:
		_institution_know(institution_id, fact)
	if kind == "exposure" and details.get("public", false):
		state.domains[domain_id].public_facts = HistoryIndex.set_value(state.domains[domain_id].public_facts, fact)
		state.domains[domain_id].exposure_turn = state.turn
	if kind == "public_anomaly":
		state.domains[domain_id].public_anomalies = HistoryIndex.set_value(state.domains[domain_id].public_anomalies, fact, targets[0], "map")
		if history != null: history.add_anomaly(domain_id, fact, targets[0])
	if kind == "anomaly_resolved":
		var carrier: String = str(HistoryIndex.mapget(state.domains[domain_id].public_anomalies, details.source))
		state.domains[domain_id].public_anomalies = HistoryIndex.erase(state.domains[domain_id].public_anomalies, details.source)
		if history != null: history.remove_anomaly(domain_id, details.source, carrier)
	if kind == "crisis":
		state.domains[domain_id].crisis_facts = HistoryIndex.set_value(state.domains[domain_id].crisis_facts, fact)
	return fact

func choose_behavior(npc_id: String, view: Dictionary = {}) -> Dictionary:
	if not ensure_history(): return {}
	var current: Dictionary = state if view.is_empty() else view
	var index: RefCounted = history
	if not view.is_empty():
		if view.has("_history_snapshot"):
			index = view._history_snapshot
		else:
			current = HistoryIndex.export_value(view)
			index = HistoryIndex.new()
			if index.page_limit <= 0: return {}
			index.configure(catalog.tables.npc_behaviors)
			index.rebuild(current)
	if not Store.has(current.npcs, npc_id):
		return {}
	var npc: Dictionary = Store.entry(current.npcs, npc_id)
	if npc.status != "active" or int(npc.acted_turn) == int(current.turn):
		return {}
	index.metrics.current_entities += 1
	var candidates: Array = []
	for behavior_id: String in _keys(catalog.tables.npc_behaviors):
		var rule: Dictionary = catalog.tables.npc_behaviors[behavior_id]
		if int(npc.sanity) < int(rule.sanity_cost) or int(npc.get("cooldowns", {}).get(behavior_id, -1)) >= int(current.turn):
			continue
		var options: Array = []
		match str(rule.eligibility):
			"strained_self":
				var source: String = index.recovery(npc_id)
				if not source.is_empty() and int(npc.sanity) < catalog.integer("autonomous_recovery_threshold"):
					options.append({"target": npc_id, "source": source})
			"known_local_exposure":
				if current.institutions.has(npc.institution) and _institution_operational(current, npc.institution):
					var subjects: Array = index.ids("active/" + npc.domain) + index.ids("subject_relics/" + npc.domain)
					for target: String in subjects:
						if not _subject_valid(current, target, npc.domain): continue
						var source: String = index.first(index.behavior_bucket(rule, npc_id, npc.domain, target))
						if not source.is_empty(): options.append({"target": target, "source": source})
			"related_harmed_follower":
				if int(npc.loyalty) >= catalog.integer("loyalty_follower_threshold"):
					for related_id: String in index.ids("active/" + npc.domain):
						var relation: Dictionary = index.support(npc_id, related_id)
						if relation.is_empty(): continue
						if relation.kind != "support" or not Store.has(current.npcs, relation.target): continue
						var other: Dictionary = Store.entry(current.npcs, relation.target)
						if other.status != "active" or other.domain != npc.domain or int(other.loyalty) < catalog.integer("loyalty_follower_threshold") or int(other.sanity) >= catalog.integer("autonomous_recovery_threshold"): continue
						var source: String = index.first(index.behavior_bucket(rule, npc_id, "", other.id))
						if not source.is_empty(): options.append({"target": other.id, "source": source, "relation": relation.source})
			"personally_witnessed_miracle":
				if int(npc.loyalty) < catalog.integer("attribute_max"):
					var source: String = index.first(index.behavior_bucket(rule, npc_id, "", npc_id))
					if not source.is_empty(): options.append({"target": npc_id, "source": source})
		for option: Dictionary in options:
			var consumed_key: String = behavior_id + "/" + option.source
			if rule.repeat_policy == "once_per_actor_source_target": consumed_key += "/" + option.target
			if rule.repeat_policy != "repeat_until_threshold" and HistoryIndex.has(npc.consumed_sources, consumed_key): continue
			var score: int = int(rule.base_score) + int(npc[rule.attribute]) * int(rule.attribute_weight)
			for need: String in str(rule.need_tags).split("|"):
				if need in npc.need_tags:
					score += int(rule.need_bonus)
					break
			var parents: Array = [option.source]
			if option.has("relation"): parents.append(option.relation)
			candidates.append({"actor": npc_id, "behavior": behavior_id, "target": option.target, "source": option.source, "parents": _unique_sorted(parents), "score": score, "consumed_key": consumed_key, "amount": int(rule.effect_base) + int(floor(float(npc[rule.attribute]) / float(rule.effect_divisor)))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score: return a.score > b.score
		return str(a.behavior) + "/" + str(a.target) + "/" + str(a.source) < str(b.behavior) + "/" + str(b.target) + "/" + str(b.source))
	return {} if candidates.is_empty() else candidates[0]

func _subject_valid(view: Dictionary, subject: String, domain: String) -> bool:
	if Store.has(view.npcs, subject):
		return Store.entry(view.npcs, subject).status == "active" and Store.entry(view.npcs, subject).domain == domain
	if Store.has(view.relics, subject):
		return Store.entry(view.relics, subject).domain == domain and not Store.entry(view.relics, subject).placement in ["consumed", "seized"]
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
		_add_delta(deltas, id, "sanity", mini(int(healing[id]), maxi(0, catalog.integer("autonomous_recovery_threshold") - int(Store.entry(view.npcs, id).sanity))))
	for id: String in _keys(deltas):
		for field: String in _keys(deltas[id]):
			Store.entry(state.npcs, id)[field] = clampi(int(Store.entry(view.npcs, id)[field]) + int(deltas[id][field]), 0, catalog.integer("attribute_max"))
	var touched_evidence: Array = []
	var batch_sources: Dictionary = {}
	for action: Dictionary in actions:
		var rule: Dictionary = catalog.tables.npc_behaviors[action.behavior]
		var npc: Dictionary = Store.entry(state.npcs, action.actor)
		npc.acted_turn = state.turn
		if not npc.has("cooldowns"):
			npc.cooldowns = {}
		npc.cooldowns[action.behavior] = int(state.turn) + int(rule.cooldown_turns)
		if rule.repeat_policy != "repeat_until_threshold":
			npc.consumed_sources = HistoryIndex.set_value(npc.consumed_sources, action.consumed_key, action.source, "map")
			if history != null:
				history.consume(state, action.actor, action.behavior, action.source, action.target)
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
			var institution_id: String = str(Store.entry(view.npcs, action.actor).institution)
			var key: String = institution_id + "|" + str(action.target)
			if not Store.has(state.evidence, key):
				Store.put(state.evidence, key, {"institution": institution_id, "subject": action.target, "strength": 0, "sources": [], "confirmations": [], "contributions": {}})
			var evidence: Dictionary = Store.entry(state.evidence, key)
			if not evidence.has("contributions"):
				evidence.contributions = {}
			var contribution_key: String = str(action.actor) + "/" + str(action.source)
			if not HistoryIndex.has(evidence.contributions, contribution_key):
				evidence.contributions = HistoryIndex.set_value(evidence.contributions, contribution_key, result, "map")
				evidence.strength += int(action.amount)
				evidence.sources = HistoryIndex.set_value(evidence.sources, result)
				_institution_know(institution_id, action.source)
				_institution_know(institution_id, result)
				if not key in touched_evidence:
					touched_evidence.append(key)
		if rule.effect == "increase_self_loyalty" and Store.entry(view.facts, action.source).changes.get("public", false):
			var exposure: String = _record("exposure", npc.domain, npc.id, [npc.id], [action.source, result], {"public": true})
			state.domains[npc.domain].public_facts = HistoryIndex.set_value(state.domains[npc.domain].public_facts, exposure)
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
			if Store.entry(state.npcs, id).domain == domain_id:
				actual[id] = {}
				for field: String in _keys(deltas[id]):
					actual[id][field] = int(Store.entry(state.npcs, id)[field]) - int(Store.entry(view.npcs, id)[field])
		_record("npc_batch_applied", domain_id, "", actual.keys(), batch_sources[domain_id], {"actual_deltas": actual, "snapshot_turn": view.turn})
	touched_evidence.sort()
	for key: String in touched_evidence:
		var evidence: Dictionary = Store.entry(state.evidence, key)
		if int(evidence.strength) >= catalog.integer("evidence_confirmation_strength") and HistoryIndex.size(evidence.confirmations) == 0:
			var institution: Dictionary = state.institutions[evidence.institution]
			var fact: String = _record("evidence_confirmed", institution.domain, "", [evidence.subject], HistoryIndex.values(evidence.sources), {"institution": institution.id, "strength": evidence.strength})
			evidence.confirmations = HistoryIndex.set_value(evidence.confirmations, fact)
			_history_evidence(key)
			_institution_know(institution.id, fact)
	return domain_deltas

func _register_growth(npc: Dictionary, attribute: String, source: String, result: String) -> void:
	if not npc.growth_sources.has(attribute):
		npc.growth_sources[attribute] = []
	if HistoryIndex.has(npc.growth_sources[attribute], source):
		return
	npc.growth_sources[attribute] = HistoryIndex.set_value(npc.growth_sources[attribute], source)
	if HistoryIndex.size(npc.growth_sources[attribute]) % catalog.integer("growth_distinct_sources_per_point") == 0 and int(npc[attribute]) < catalog.integer("npc_attribute_max"):
		npc[attribute] = mini(catalog.integer("npc_attribute_max"), int(npc[attribute]) + catalog.integer("growth_attribute_increment"))
		var growth: String = _record("attribute_growth", npc.domain, npc.id, [npc.id], HistoryIndex.values(npc.growth_sources[attribute]) + [result], {"attribute": attribute, "value": npc[attribute]})
		_know(npc.id, growth)

func prepare_turn(owner: Object = null) -> bool:
	if not ensure_history(): return false
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
	if not Attention.enabled(state) and not state.has("cult_system"): _succeed_cults()
	_refresh_anchors()
	state.whispers = mini(catalog.integer("whisper_cap"), catalog.integer("whisper_base") + int(floor(float(state.awakening) / catalog.number("whisper_growth_step"))))
	state.phase = "actions"
	return true

func begin_turn(owner: Object = null) -> bool:
	return prepare_turn(owner) and finish_turn_start(owner)

func mark_player_task(npc_id: String, owner: Object = null) -> bool:
	stage_collections(["npcs"])
	# Called after the actual player task has passed its own cost/eligibility checks.
	if not _driver_allowed(owner) or state.phase != "actions" or not Store.has(state.npcs, npc_id) or Store.entry(state.npcs, npc_id).status != "active" or int(Store.entry(state.npcs, npc_id).acted_turn) == int(state.turn):
		return false
	Store.entry(state.npcs, npc_id).acted_turn = state.turn
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
	for field: String in ["domains", "institutions", "npcs", "evidence", "cults", "relics", "anchors"]:
		view[field] = history.copy_collection(state, field) if field in HistoryIndex.COLD_FIELDS else HistoryIndex.copy_current(state[field])
	if state.has("economy"):
		view.economy = state.economy.duplicate(true)
		view.economy_qualifications = state.economy_qualifications.duplicate(true)
	view["_history_snapshot"] = history.fork()
	return view

func evolve(owner: Object = null, economic_batch: Dictionary = {}) -> Array:
	if not ensure_history(): return []
	stage_current()
	# This is the autonomous evolution phase, not the entire six-phase game loop.
	if not _driver_allowed(owner) or state.phase != "actions" or (state.has("economy") and (economic_batch.is_empty() or economic_batch.get("turn") != state.turn)):
		return []
	var view: Dictionary = _evolution_snapshot()
	var actions: Array = []
	var assigned: bool = state.has("simulation")
	var due: Array = []
	var background: Dictionary = {}
	if assigned:
		for domain: String in _keys(view.domains):
			if not domain in view.simulation.focused and int(view.simulation.cursors[domain].next_turn) <= int(view.turn): due.append(domain)
		background = abstract_sim.propose(_background_snapshot(view), due)
		if not background.ok: return []
	var actors: Array = (attention.detailed_ids(view) if Attention.enabled(view) else abstract_sim.detailed_ids(view, history)) if assigned else history.ids("living")
	stats.npc_updates += actors.size() if assigned else Store.size(view.npcs)
	for npc_id: String in actors:
		history.metrics.current_entities += 1
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
		var routine_due: bool = not assigned or domain_id in view.simulation.focused or domain_id in due
		if routine_due and not has_active_anchor and int(before.pollution_changed_turn) < int(state.turn):
			var prior: int = int(domain.pollution)
			domain.pollution = maxi(0, prior - catalog.integer("pollution_base_decay"))
			if prior != int(domain.pollution):
				changes.pollution_delta = int(domain.pollution) - prior
		var ongoing_public: bool = _has_public_anomaly(view, domain_id)
		var alert_delta: int = int(npc_deltas.get(domain_id, {}).get("alert", 0)) + int(economic_deltas.get(domain_id, {}).get("alert", 0))
		if routine_due and int(domain.exposure_turn) < int(state.turn) and not ongoing_public:
			alert_delta -= catalog.integer("alert_quiet_decay")
		domain.alert = clampi(int(before.alert) + alert_delta, 0, catalog.integer("attribute_max"))
		if domain.alert != before.alert:
			changes.alert_delta = int(domain.alert) - int(before.alert)
			parents.append_array(npc_deltas.get(domain_id, {}).get("sources", []))
			if economic_deltas.has(domain_id):
				parents.append(economic_deltas[domain_id].source)
		var order_id: String = domain_id + "/order"
		if routine_due and _institution_operational(view, order_id) and int(before.pollution_changed_turn) < int(state.turn) and not ongoing_public:
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
	if assigned:
		stage_collections(["simulation"])
		# Focused periods consume the scheduled background opportunity without
		# drawing it; a later downgrade must not collect missed opportunities.
		for domain: String in view.simulation.focused:
			if int(view.simulation.cursors[domain].next_turn) <= int(view.turn): state.simulation.cursors[domain].next_turn = int(view.turn) + int(abstract_sim.parameters.background_tick_interval)
		for domain: String in background.cursors: state.simulation.cursors[domain] = background.cursors[domain]
		for proposal: Dictionary in background.proposals: _fix_background(proposal, int(state.turn) + 1)
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
	if Store.has(view.npcs, target):
		return Store.entry(view.npcs, target).domain == domain and Store.entry(view.npcs, target).status == "active"
	if Store.has(view.relics, target):
		return Store.entry(view.relics, target).domain == domain and not Store.entry(view.relics, target).placement in ["consumed", "sealed", "seized"]
	if view.institutions.has(target):
		return view.institutions[target].domain == domain and view.institutions[target].active
	return false

func _has_public_anomaly(view: Dictionary, domain_id: String) -> bool:
	if not ensure_history(): return false
	var index: RefCounted = history
	var current: Dictionary = view
	if view.has("_history_snapshot"):
		index = view._history_snapshot
	elif not is_same(view, state):
		current = HistoryIndex.export_value(view)
		index = HistoryIndex.new()
		if index.page_limit <= 0: return false
		index.configure(catalog.tables.npc_behaviors)
		index.rebuild(current)
	var carriers: Array = index.ids("active/" + domain_id) + index.ids("public_relics/" + domain_id) + current.domains[domain_id].institutions
	for carrier: String in carriers:
		if _public_carrier_valid(current, carrier, domain_id) and index.anomaly_count(domain_id, carrier) > 0: return true
	return false

func _institution_operational(view: Dictionary, id: String) -> bool:
	if not view.institutions.has(id) or not view.institutions[id].active:
		return false
	var representative: String = str(view.institutions[id].representative)
	if view.has("simulation"):
		if view.institutions[id].get("occupancy") in ["vacant", "disabled"]: return false
		if representative.is_empty() and view.institutions[id].get("occupancy") == "occupied_abstract" and not view.institutions[id].domain in view.simulation.focused: return true
	return Store.has(view.npcs, representative) and Store.entry(view.npcs, representative).status == "active" and Store.entry(view.npcs, representative).domain == view.institutions[id].domain

func _succeed_cults() -> void:
	for cult_id: String in _keys(state.cults):
		var cult: Dictionary = state.cults[cult_id]
		if not cult.leader.is_empty() or cult.status == "destroyed":
			continue
		var eligible: Array = []
		for npc_id: String in _living_ids():
			var npc: Dictionary = Store.entry(state.npcs, npc_id)
			if npc.domain == cult.domain and npc.status == "active" and int(npc.loyalty) >= catalog.integer("loyalty_follower_threshold"):
				if Attention.enabled(state) and not npc.get("bound_member", false):
					var willingness: String = str(npc.get("dedication_source", ""))
					if willingness.is_empty() or not Store.has(state.facts, willingness) or (Store.entry(state.facts, npc.binding_source).kind == "member_left" and willingness <= str(npc.binding_source)): continue
				eligible.append(npc)
		eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.influence != b.influence:
				return a.influence > b.influence
			if a.loyalty != b.loyalty:
				return a.loyalty > b.loyalty
			return a.id < b.id
		)
		if not eligible.is_empty():
			if Attention.enabled(state) and not eligible[0].get("bound_member", false):
				var needs: Dictionary = attention.preview_needs(state, {"family": "system", "content_id": "CULT_SUCCESSION", "variant": "use", "participants": [eligible[0].id], "nominees": [eligible[0].id], "target": cult.domain, "source": cult.get("succession_source", cult.established_source)})
				if not needs.ok: continue
				var reserved: Dictionary = attention.reserve(self, needs)
				if not reserved.ok: continue
				if not attention.enroll(self, eligible[0].id, needs.source, reserved.token, cult_id): return
				attention.finish(self, reserved.token)
			cult.leader = eligible[0].id
			cult.cohesion = maxi(0, int(cult.cohesion) - catalog.integer("cult_succession_cohesion_cost"))
			cult.status = "active" if cult.cohesion > 0 else "destroyed"
			if cult.has("succession_source"):
				_record("cult_succeeded", cult.domain, cult.leader, [cult.id], [cult.succession_source], {"cohesion_delta": -catalog.integer("cult_succession_cohesion_cost")})

func institution_successors(institution_id: String) -> Array:
	var eligible: Array = []
	if not state.institutions.has(institution_id):
		return eligible
	for id: String in _living_ids():
		var npc: Dictionary = Store.entry(state.npcs, id)
		if npc.status == "active" and npc.domain == state.institutions[institution_id].domain and int(npc.sanity) >= catalog.integer("institution_successor_min_sanity") and _profile_legal(catalog.tables.npc_profiles[npc.profile], npc.domain, institution_id):
			eligible.append(id)
	return eligible

func succeed_institution(institution_id: String, npc_id: String, cause: String, owner: Object = null) -> bool:
	if not _driver_allowed(owner):
		return false
	if not state.institutions.has(institution_id) or not Store.has(state.facts, cause) or not npc_id in institution_successors(institution_id):
		return false
	# This effect is only callable by an authorized succession event, not NPC autonomy.
	if Store.entry(state.facts, cause).kind != "institution_succession_authorized" or Store.entry(state.facts, cause).domain != state.institutions[institution_id].domain or not institution_id in Store.entry(state.facts, cause).targets or not npc_id in Store.entry(state.facts, cause).targets:
		return false
	if Store.has(state.applied_authorizations, cause):
		return Store.entry(state.applied_authorizations, cause) == "succession/" + institution_id + "/" + npc_id
	stage_collections(["applied_authorizations"])
	Store.put(state.applied_authorizations, cause, "succession/" + institution_id + "/" + npc_id)
	state.institutions[institution_id].representative = npc_id
	if state.institutions[institution_id].has("occupancy"): state.institutions[institution_id].occupancy = "represented"
	Store.entry(state.npcs, npc_id).institution = institution_id
	_record("institution_succeeded", state.institutions[institution_id].domain, npc_id, [institution_id], [cause])
	return true

func confirm_exception(institution_id: String, record: String, authorization: String, owner: Object = null) -> bool:
	if not _driver_allowed(owner):
		return false
	if not _institution_operational(state, institution_id) or not Store.has(state.facts, record) or not Store.has(state.facts, authorization):
		return false
	var institution: Dictionary = state.institutions[institution_id]
	var fact: Dictionary = Store.entry(state.facts, record)
	var permit: Dictionary = Store.entry(state.facts, authorization)
	if institution.role != "interpretation" or fact.kind != "exception" or fact.domain != institution.domain or Store.has(state.invalid_records, record) or not HistoryIndex.has(institution.known_facts, record):
		return false
	if permit.kind != "exception_confirmation_authorized" or permit.domain != institution.domain or not institution_id in permit.targets or not record in permit.targets or not record in permit.causal_parents:
		return false
	var key: String = institution_id + "|" + record
	if Store.has(state.applied_authorizations, authorization):
		return Store.entry(state.applied_authorizations, authorization) == "confirm/" + key
	var confirmation: String = _record("evidence_confirmed", institution.domain, "", [record], [record, authorization], {"institution": institution_id, "strength": catalog.integer("evidence_confirmation_strength")})
	Store.put(state.evidence, key, {"institution": institution_id, "subject": record, "strength": catalog.integer("evidence_confirmation_strength"), "sources": [authorization], "confirmations": [confirmation]})
	_history_evidence(key)
	stage_collections(["applied_authorizations"])
	Store.put(state.applied_authorizations, authorization, "confirm/" + key)
	_institution_know(institution_id, confirmation)
	return true

func choose_plan(domain_id: String, view: Dictionary = {}) -> Dictionary:
	if not ensure_history(): return {}
	var current: Dictionary = state if view.is_empty() else view
	var index: RefCounted = history
	if not view.is_empty():
		if view.has("_history_snapshot"):
			index = view._history_snapshot
		else:
			current = HistoryIndex.export_value(view)
			index = HistoryIndex.new()
			if index.page_limit <= 0: return {}
			index.configure(catalog.tables.npc_behaviors)
			index.rebuild(current)
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
			var subjects: Array = index.ids("active/" + domain_id) + index.ids("subject_relics/" + domain_id) + _keys(current.anchors)
			for subject: String in subjects:
				var key: String = institution_id + "|" + subject
				if _subject_valid(current, subject, domain_id) and (not Store.has(current.evidence, key) or HistoryIndex.size(Store.entry(current.evidence, key).confirmations) == 0):
					var sources: Dictionary = index.sources("exposed/" + institution_id + "/" + domain_id + "/" + subject)
					if HistoryIndex.size(sources) > 0: targets[subject] = sources
		else:
			var evidence_subjects: Array = index.ids("active/" + domain_id) + index.current_ids(current, "relics")
			if effect.evidence_requirement == "confirmed_exception":
				evidence_subjects = index.ids("exceptions/" + institution_id)
			evidence_subjects.sort()
			for subject_id: String in evidence_subjects:
				var key: String = institution_id + "|" + subject_id
				if not Store.has(current.evidence, key): continue
				var evidence: Dictionary = Store.entry(current.evidence, key)
				if evidence.institution != institution_id or HistoryIndex.size(evidence.confirmations) == 0:
					continue
				var subject: String = str(evidence.subject)
				match str(effect.evidence_requirement):
					"confirmed_npc":
						if Store.has(current.npcs, subject) and _subject_valid(current, subject, domain_id) and int(Store.entry(current.npcs, subject).loyalty) >= catalog.integer("loyalty_follower_threshold"):
							for cult: Dictionary in current.cults.values():
								if cult.domain == domain_id and cult.status != "destroyed":
									targets[cult.id] = evidence.confirmations
					"confirmed_relic":
						if Store.has(current.relics, subject) and _subject_valid(current, subject, domain_id):
							targets[subject] = evidence.confirmations
					"confirmed_anchor":
						for anchor: Dictionary in current.anchors.values():
							if anchor.domain == domain_id and anchor.state == "active" and subject in [anchor.guardian, anchor.relic]:
								targets[anchor.id] = evidence.confirmations
					"confirmed_exception":
						if Store.has(current.facts, subject) and Store.entry(current.facts, subject).kind == "exception" and Store.entry(current.facts, subject).domain == domain_id and not Store.has(current.invalid_records, subject):
							targets[subject] = evidence.confirmations
		for target: String in _keys(targets):
			var recent: int = -1
			if HistoryIndex.is_history(targets[target]) and int(targets[target].root.get("recent", -1)) >= 0:
				recent = int(targets[target].root.recent)
			else:
				for parent: String in HistoryIndex.values(targets[target]):
					recent = maxi(recent, int(Store.entry(current.facts, parent).turn))
			candidates.append({"rule": rule_id, "domain": domain_id, "institution": institution_id, "target": target, "parents": targets[target], "priority": int(rule.priority), "recent": recent, "due": int(current.turn) + int(rule.warning_turns)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.recent != b.recent:
			return a.recent > b.recent
		return str(a.target) + "/" + str(a.rule) < str(b.target) + "/" + str(b.rule)
	)
	if candidates.is_empty(): return {}
	var selected: Dictionary = candidates[0]
	selected.parents = _unique_sorted(HistoryIndex.values(selected.parents))
	return selected

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
			return Store.has(state.relics, plan.target) and _subject_valid(state, plan.target, plan.domain)
		"repair_barrier":
			return state.domains.has(plan.target)
		"destroy_anchor":
			return state.anchors.has(plan.target) and state.anchors[plan.target].state == "active"
		"rewrite_reality":
			return Store.has(state.facts, plan.target) and not Store.has(state.invalid_records, plan.target)
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
					if not Store.has(state.evidence, key):
						Store.put(state.evidence, key, {"institution": plan.institution, "subject": plan.target, "strength": 0, "sources": [], "confirmations": []})
					Store.entry(state.evidence, key).strength = maxi(int(Store.entry(state.evidence, key).strength), catalog.integer("evidence_confirmation_strength"))
					for parent: String in plan.parents:
						Store.entry(state.evidence, key).sources = HistoryIndex.set_value(Store.entry(state.evidence, key).sources, parent)
					if HistoryIndex.size(Store.entry(state.evidence, key).confirmations) == 0:
						Store.entry(state.evidence, key).confirmations = HistoryIndex.set_value(Store.entry(state.evidence, key).confirmations, outcome)
					_history_evidence(key)
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
					var relic: Dictionary = Store.entry(state.relics, plan.target)
					relic.holder = ""
					relic.placement = "seized"
					relic.captor = plan.institution
					if relic.get("formal", false): relic.status_source = outcome
					if history != null: history.refresh_relic(state, plan.target)
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

func _anomaly_entry_valid(candidate: Dictionary, domain: String, source: String, carrier: Variant) -> bool:
	var fact: Variant = Store.entry(candidate.facts, source)
	return carrier is String and fact is Dictionary and fact.get("kind") == "public_anomaly" and fact.get("domain") == domain and fact.get("targets") == [carrier] and (Store.has(candidate.npcs, carrier) or Store.has(candidate.relics, carrier) or candidate.institutions.has(carrier))

func _validate_anomaly_delta(candidate: Dictionary, trusted: Dictionary, domain: String, after: Variant, before: Variant) -> Array[String]:
	var errors: Array[String] = []
	var added: int = 0
	var removed: int = 0
	for entry: Dictionary in HistoryIndex.changed_entries(after, before):
		if not _anomaly_entry_valid(candidate, domain, entry.key, entry.value): errors.append("Invalid public anomaly source/carrier")
		if HistoryIndex.has(before, entry.key): errors.append("Anomaly cannot silently retarget its carrier")
		else:
			added += 1
			if not str(entry.key).begins_with("FACT-") or int(str(entry.key).get_slice("-", 1)) < int(trusted.next_fact) or int(str(entry.key).get_slice("-", 1)) >= int(candidate.next_fact): errors.append("Anomaly admission requires a newly established source")
	for entry: Dictionary in HistoryIndex.changed_entries(before, after):
		if HistoryIndex.has(after, entry.key): continue
		removed += 1
		var resolved: bool = false
		for number: int in range(int(trusted.next_fact), int(candidate.next_fact)):
			var fact: Variant = Store.entry(candidate.facts, "FACT-%08d" % number, {})
			if not fact is Dictionary or not fact.get("changes") is Dictionary or not fact.get("causal_parents") is Array: continue
			if fact.get("kind") == "anomaly_resolved" and fact.get("domain") == domain and fact.get("changes", {}).get("source") == entry.key and entry.key in fact.get("causal_parents", []): resolved = true
		if not resolved: errors.append("Anomaly source removed without a real resolution")
	if HistoryIndex.size(after) != HistoryIndex.size(before) + added - removed: errors.append("Anomaly projection count disagrees")
	return errors

func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
	if candidate.has("simulation") != trusted.has("simulation"): return ["Simulation mode cannot change during a transaction"]
	for field: String in ["domains", "institutions", "npcs", "facts", "evidence", "cults", "relics", "anchors", "applied_authorizations", "invalid_records"]:
		if not candidate.get(field) is Dictionary: return ["Missing or invalid candidate collection: " + field]
	if not candidate.get("next_fact") is int or int(candidate.next_fact) < int(trusted.next_fact) or not candidate.get("next_npc") is int or int(candidate.next_npc) < int(trusted.next_npc):
		return ["Identity sequence moved backwards"]
	if not candidate.get("facts") is Dictionary or Store.size(candidate.facts) != Store.size(trusted.facts) + int(candidate.next_fact) - int(trusted.next_fact):
		return ["Fact sequence and append count disagree"]
	var inspected: Dictionary = candidate.duplicate(false)
	var errors: Array[String] = []
	for collection: String in HistoryIndex.COLD_FIELDS:
		var ids: Dictionary = {}
		for id: String in history.current_ids(candidate, collection): ids[id] = true
		# Shared persistent roots are checked by identity and explicit writes;
		# archived records do not require a complete old-key walk.
		var inserted: int = 0
		if Store.packed(trusted[collection]):
			errors.append_array(Store.retained(candidate[collection], trusted[collection]))
			for id: String in Store.changed(candidate[collection]):
				if not Store.has(trusted[collection], id): inserted += 1
				ids[id] = true
		else:
			for id: String in candidate[collection]:
				if not trusted[collection].has(id): inserted += 1
				if not trusted[collection].has(id) or not is_same(candidate[collection][id], trusted[collection][id]): ids[id] = true
			if candidate[collection].size() != trusted[collection].size() + inserted: errors.append("Persistent collection entry was deleted: " + collection)
		if collection == "npcs" and inserted != int(candidate.next_npc) - int(trusted.next_npc):
			errors.append("Identity sequence disagrees with new people")
		inspected[collection] = {}
		for id: String in ids:
			if not Store.has(candidate[collection], id) or not Store.entry(candidate[collection], id) is Dictionary:
				errors.append("Invalid candidate entity: " + collection + "/" + id)
				continue
			var item: Dictionary = Store.entry(candidate[collection], id).duplicate(false)
			var prior: Dictionary = Store.entry(trusted[collection], id, {})
			history.metrics.current_entities += 1
			for field: String in HistoryIndex.COLD_FIELDS[collection]:
				if not item.has(field): continue
				if field == "growth_sources":
					if not item[field] is Dictionary or HistoryIndex.is_history(item[field]):
						errors.append("Invalid growth source collection")
						continue
					for old_attribute: String in prior.get(field, {}):
						if not item[field].has(old_attribute): errors.append("Growth history cannot disappear")
					for attribute: String in item.growth_sources:
						if not attribute in ATTRIBUTES: errors.append("Invalid growth record")
						var after_growth: Variant = item.growth_sources[attribute]
						var before_growth: Variant = prior.get(field, {}).get(attribute, [])
						if not HistoryIndex.valid_shape(after_growth, "list"):
							errors.append("Invalid growth source list")
							continue
						var growth_delta: Array = HistoryIndex.changed_entries(after_growth, before_growth)
						var growth_added: int = 0
						for entry: Dictionary in growth_delta:
							if not HistoryIndex.has(before_growth, entry.key): growth_added += 1
						if HistoryIndex.size(after_growth) != HistoryIndex.size(before_growth) + growth_added: errors.append("Growth sources cannot disappear")
						for entry: Dictionary in growth_delta:
							if not Store.has(candidate.facts, entry.key): errors.append("Invalid new growth source")
					item[field] = {}
				else:
					var kind: String = "map" if field in ["consumed_sources", "contributions", "public_anomalies"] else ("sequence" if field == "relations" else "list")
					if not HistoryIndex.valid_shape(item[field], kind):
						errors.append("Invalid historical field shape: " + field)
						continue
					var before_field: Variant = prior.get(field, {} if kind == "map" else [])
					if field == "public_anomalies":
						errors.append_array(_validate_anomaly_delta(candidate, trusted, id, item[field], before_field))
						item[field] = {}
						continue
					var delta: Array = HistoryIndex.changed_entries(item[field], before_field)
					var added: int = 0
					for entry: Dictionary in delta:
						if not HistoryIndex.has(before_field, entry.key): added += 1
						elif collection != "evidence" and HistoryIndex.mapget(before_field, entry.key) != entry.value: errors.append("Committed history cannot be rewritten")
					if collection != "evidence" and HistoryIndex.size(item[field]) != HistoryIndex.size(before_field) + added: errors.append("Committed history cannot disappear")
					for entry: Dictionary in delta:
						if field == "relations":
							if not entry.value is Dictionary or not Store.has(candidate.npcs, entry.value.get("target", "")) or not Store.has(candidate.facts, entry.value.get("source", "")): errors.append("Invalid new relationship")
						elif not Store.has(candidate.facts, entry.value if field in ["consumed_sources", "contributions"] else entry.key):
							errors.append("Invalid new historical source")
					item[field] = {} if field in ["consumed_sources", "contributions"] else []
			inspected[collection][id] = item
	if not errors.is_empty(): return errors
	var power_errors: Array[String] = Powers.validate_state(candidate, catalog, trusted)
	if not power_errors.is_empty(): return power_errors
	var relic_errors: Array[String] = Relics.validate_state(candidate, catalog, trusted, history)
	if not relic_errors.is_empty(): return relic_errors
	var cult_errors: Array[String] = Cults.validate_state(candidate, catalog, trusted)
	if not cult_errors.is_empty(): return cult_errors
	var base_errors: Array[String] = _validate_state(inspected, int(trusted.next_fact))
	if not base_errors.is_empty(): return base_errors
	var simulation_errors: Array[String] = abstract_sim.validate(candidate)
	return simulation_errors if not simulation_errors.is_empty() else attention.validate(candidate, trusted)

func validate_state(candidate: Dictionary) -> Array[String]:
	var power_errors: Array[String] = Powers.validate_state(candidate, catalog)
	if not power_errors.is_empty(): return power_errors
	var relic_errors: Array[String] = Relics.validate_state(candidate, catalog)
	if not relic_errors.is_empty(): return relic_errors
	var cult_errors: Array[String] = Cults.validate_state(candidate, catalog)
	if not cult_errors.is_empty(): return cult_errors
	var expanded: Dictionary = HistoryIndex.export_value(candidate)
	var cold_errors: Array[String] = []
	for collection: String in HistoryIndex.COLD_FIELDS:
		if not expanded.get(collection) is Dictionary: continue
		for item: Variant in expanded[collection].values():
			if not item is Dictionary: continue
			for field: String in HistoryIndex.COLD_FIELDS[collection]:
				if not item.has(field) or field in ["relations", "contributions", "consumed_sources", "public_anomalies"]: continue
				var lists: Array = []
				if field == "growth_sources":
					if not item[field] is Dictionary:
						cold_errors.append("Invalid growth source collection")
						continue
					lists = item[field].values()
				else: lists = [item[field]]
				for list: Variant in lists:
					if not list is Array:
						cold_errors.append("Invalid historical source list")
						continue
					var previous: String = ""
					for id: Variant in list:
						if not id is String or str(id) <= previous: cold_errors.append("Historical source sets must be unique and sorted")
						previous = str(id)
	if not cold_errors.is_empty(): return cold_errors
	var base_errors: Array[String] = _validate_state(expanded, 0)
	if not base_errors.is_empty(): return base_errors
	var simulation_errors: Array[String] = abstract_sim.validate(candidate)
	if not simulation_errors.is_empty(): return simulation_errors
	var attention_errors: Array[String] = attention.validate(candidate)
	if not attention_errors.is_empty(): return attention_errors
	for domain: String in expanded.domains:
		for source: Variant in expanded.domains[domain].public_anomalies:
			if not source is String or not _anomaly_entry_valid(expanded, domain, source, expanded.domains[domain].public_anomalies[source]): cold_errors.append("Invalid public anomaly source/carrier")
	return cold_errors

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
	for id: String in Store.keys(candidate.npcs):
		var npc: Variant = Store.entry(candidate.npcs, id)
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
		if not npc.get("acted_turn") is int or not Store.has(candidate.facts, npc.get("status_source", "")):
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
			if not fact_id is String or not Store.has(candidate.facts, fact_id):
				issues.append("Unknown domain fact")
		if not domain.pending_plan.is_empty():
			var plan: Dictionary = domain.pending_plan
			if not catalog.tables.resistance_plans.has(plan.get("rule", "")) or not candidate.institutions.has(plan.get("institution", "")) or not Store.has(candidate.facts, plan.get("started_fact", "")) or not plan.get("due") is int or not plan.get("parents") is Array or not plan.get("target") is String:
				issues.append("Invalid pending plan")
			else:
				for parent: Variant in plan.parents:
					if not parent is String or not Store.has(candidate.facts, parent):
						issues.append("Unknown pending cause")
	for id: String in candidate.institutions:
		var institution: Variant = candidate.institutions[id]
		if not institution is Dictionary or institution.get("id") != id or not candidate.domains.has(institution.get("domain", "")) or not institution.get("known_facts") is Array or not institution.get("active") is bool:
			issues.append("Invalid institution")
			continue
		if not institution.get("representative", "").is_empty():
			var person: String = institution.representative
			if not Store.has(candidate.npcs, person) or Store.entry(candidate.npcs, person).status == "dead" or Store.entry(candidate.npcs, person).domain != institution.domain:
				issues.append("Invalid institution representative")
		for fact_id: Variant in institution.known_facts:
			if not fact_id is String or not Store.has(candidate.facts, fact_id):
				issues.append("Unknown institution knowledge")
	var fact_ids: Array = Store.keys(candidate.facts) if first_new_fact == 0 else []
	if first_new_fact > 0:
		for number: int in range(first_new_fact, int(candidate.next_fact)):
			fact_ids.append("FACT-%08d" % number)
	for id: String in fact_ids:
		if not Store.has(candidate.facts, id):
			issues.append("Missing newly allocated fact")
			continue
		var fact: Variant = Store.entry(candidate.facts, id)
		if not fact is Dictionary or fact.get("id") != id or not fact.get("turn") is int or int(fact.turn) < 0 or int(fact.turn) > int(candidate.turn) or not fact.get("causal_parents") is Array or not fact.get("targets") is Array or not fact.get("changes") is Dictionary:
			issues.append("Invalid fact")
			continue
		max_fact_id = maxi(max_fact_id, int(id.get_slice("-", 1)))
		for parent: Variant in fact.causal_parents:
			if not parent is String or not Store.has(candidate.facts, parent) or parent >= id or int(Store.entry(candidate.facts, parent).get("turn", -1)) > int(fact.turn):
				issues.append("Invalid causal ancestry")
	for npc: Dictionary in Store.values(candidate.npcs):
		for fact_id: Variant in npc.known_facts:
			if not fact_id is String or not Store.has(candidate.facts, fact_id):
				issues.append("Unknown person knowledge")
		for relation: Variant in npc.relations:
			if not relation is Dictionary or not Store.has(candidate.npcs, relation.get("target", "")) or not Store.has(candidate.facts, relation.get("source", "")):
				issues.append("Invalid social relationship")
		for source: Variant in npc.consumed_sources.values():
			if not source is String or not Store.has(candidate.facts, source):
				issues.append("Invalid consumed source")
		for attribute: String in npc.growth_sources:
			if not attribute in ATTRIBUTES or not npc.growth_sources[attribute] is Array:
				issues.append("Invalid growth record")
				continue
			for source: Variant in npc.growth_sources[attribute]:
				if not source is String or not Store.has(candidate.facts, source):
					issues.append("Invalid growth source")
	for evidence: Variant in Store.values(candidate.evidence):
		if not evidence is Dictionary or not candidate.institutions.has(evidence.get("institution", "")) or not evidence.get("sources") is Array or not evidence.get("confirmations") is Array or not evidence.get("strength") is int:
			issues.append("Invalid evidence")
			continue
		for source: Variant in evidence.sources + evidence.confirmations:
			if not source is String or not Store.has(candidate.facts, source):
				issues.append("Invalid evidence source")
	for relic: Dictionary in Store.values(candidate.relics):
		if not candidate.domains.has(relic.get("domain", "")) or not relic.get("placement", "") in ["carried", "controlled", "bound", "ground", "seized", "consumed", "sealed"]:
			issues.append("Invalid relic")
		if not str(relic.get("holder", "")).is_empty() and (not Store.has(candidate.npcs, relic.holder) or Store.entry(candidate.npcs, relic.holder).status == "dead"):
			issues.append("Invalid relic holder")
	for anchor: Dictionary in candidate.anchors.values():
		if not candidate.domains.has(anchor.get("domain", "")) or not candidate.institutions.has(anchor.get("institution", "")) or not anchor.get("state", "") in ["absent", "active", "dormant", "destroyed"]:
			issues.append("Invalid anchor")
		if anchor.state == "active" and (not Store.has(candidate.npcs, anchor.get("guardian", "")) or Store.entry(candidate.npcs, anchor.guardian).status != "active" or not Store.has(candidate.relics, anchor.get("relic", "")) or Store.entry(candidate.relics, anchor.relic).placement != "bound"):
			issues.append("Invalid active anchor")
	if int(candidate.next_npc) <= max_npc_id or int(candidate.next_fact) <= max_fact_id:
		issues.append("Identity sequence would reuse an existing ID")
	if issues.is_empty():
		issues.append_array(Economy.validate_state(candidate, catalog))
	return issues

# Assigned mode is a pre-session integration seam. Player admission is owned by
# TASK-ATTENTION; this seam cannot change a running session's allocation.
func configure_assigned_simulation(focused: Array, persistent: Array = [], temporary: Array = [], bootstrap_domain: String = "") -> bool:
	if _turn_owner != null or state.get("turn") != 0 or state.has("simulation") or abstract_sim.version.is_empty(): return false
	var original: Dictionary = state
	var old_history: RefCounted = history
	state = HistoryIndex.export_value(state)
	history = null
	state.simulation = abstract_sim.initialize(state, str(randoms.generation.seed), focused, persistent, temporary)
	var valid: bool = abstract_sim.validate(state).is_empty() and ensure_history()
	if valid and not bootstrap_domain.is_empty():
		valid = state.domains.has(bootstrap_domain)
		if valid:
			var view: Dictionary = _background_snapshot(_evolution_snapshot())
			var batch: Dictionary = abstract_sim.propose(view, [bootstrap_domain], "candidate_generation", true)
			valid = batch.ok and not batch.proposals.is_empty()
			if valid:
				for proposal: Dictionary in batch.proposals:
					if not _fix_background(proposal, 1): valid = false; break
				if valid:
					state.simulation.cursors[bootstrap_domain] = batch.cursors[bootstrap_domain]
					state.simulation.bootstrap = true
	if valid: valid = validate_state(state).is_empty()
	if not valid:
		state = original; history = old_history
		last_error = "Assigned simulation/initial contact could not be committed"
	return valid

func _background_snapshot(view: Dictionary) -> Dictionary:
	var summaries: Dictionary = {}
	var index: RefCounted = view._history_snapshot
	for domain: String in _keys(view.domains):
		var row: Dictionary = view.domains[domain]
		var legal: Array = []
		for id: String in abstract_sim.templates:
			var rule: Dictionary = abstract_sim.templates[id]
			if rule.actor_policy == "nominate" and _profile_legal(catalog.tables.npc_profiles[rule.profile], domain, domain + "/" + rule.institution_role): legal.append(id)
		var actor: String = str(view.institutions[domain + "/interpretation"].representative)
		var source: String = ""
		if Store.has(view.npcs, actor) and _active(Store.entry(view.npcs, actor)):
			for behavior: Dictionary in catalog.tables.npc_behaviors.values():
				if behavior.eligibility != "known_local_exposure": continue
				for target: String in index.ids("active/" + domain) + index.ids("subject_relics/" + domain):
					if not _subject_valid(view, target, domain): continue
					var found: String = index.first(index.behavior_bucket(behavior, actor, domain, target))
					if not found.is_empty() and not Store.has(view.invalid_records, found): source = found; break
				if not source.is_empty(): break
		summaries[domain] = {"origin": row.origin, "profile": row.profile, "barrier": row.barrier, "pollution": row.pollution, "alert": row.alert, "stability": row.stability, "unnamed_nonfollowers": row.unnamed_nonfollowers, "route": not view.institutions[domain + "/propagation"].links.is_empty(), "legal_templates": legal, "exposure_actor": actor, "exposure_source": source}
	return {"version": transaction.sequence if transaction != null else 0, "turn": view.turn, "domains": summaries, "simulation": view.simulation.duplicate(true), "chance": catalog.integer("ambient_event_chance"), "living": history.ids("living").size(), "living_limit": catalog.integer("living_named_global_limit")}

func _temporary_actors() -> Dictionary:
	var result: Dictionary = {}
	for id: String in state.simulation.temporary + state.simulation.holds.keys():
		if not id in state.simulation.persistent: result[id] = true
	return result

func _fix_background(proposal: Dictionary, visible: int, reuse_existing: bool = false) -> bool:
	var sim: Dictionary = state.simulation
	var once: String = "background/" + str(proposal.get("once_key", ""))
	var fingerprint: String = canonical(proposal).sha256_text()
	if Store.has(state.applied_authorizations, once):
		var prior: String = Store.entry(state.applied_authorizations, once)
		return Store.has(state.facts, prior) and Store.entry(state.facts, prior).changes.get("candidate", {}).get("proposal_hash") == fingerprint
	if not abstract_sim.templates.has(proposal.get("template", "")) or sim.candidates.size() >= abstract_sim.parameters.pending_candidate_limit: return false
	var rule: Dictionary = abstract_sim.templates[proposal.template]
	var domain: String = proposal.object
	if not state.domains.has(domain) or not proposal.get("source_ids") is Array or proposal.source_ids.is_empty(): return false
	var people: Dictionary = _temporary_actors()
	var actors: Array = proposal.actors.duplicate()
	if actors.size() > abstract_sim.parameters.candidate_actor_limit: return false
	for id: String in actors:
		if not Store.has(state.npcs, id) or not _active(Store.entry(state.npcs, id)) or Store.entry(state.npcs, id).domain != domain: return false
		if not id in sim.persistent: people[id] = true
	if rule.actor_policy == "nominate" and not reuse_existing:
		if people.size() >= abstract_sim.parameters.temporary_actor_limit or _living_count() >= catalog.integer("living_named_global_limit") or state.domains[domain].unnamed_nonfollowers <= 0: return false
		if not _profile_legal(catalog.tables.npc_profiles[rule.profile], domain, domain + "/" + rule.institution_role): return false
	elif people.size() > abstract_sim.parameters.temporary_actor_limit: return false
	for source: String in proposal.source_ids:
		if not Store.has(state.facts, source) or Store.has(state.invalid_records, source): return false
		if not reuse_existing and rule.source_mode == "known_history" and (actors.is_empty() or not history.knows(state, actors[0], source) or Store.entry(state.facts, source).domain != domain or Store.entry(state.facts, source).kind != "exposure"): return false
	var token: String = ""
	var identity_key: String = "new:background/" + str(proposal.once_key)
	if Attention.enabled(state):
		var requested: Array = actors.duplicate()
		var identities: Array = []
		if rule.actor_policy == "nominate" and not reuse_existing: requested.append(identity_key); identities.append(identity_key)
		var needs: Dictionary = {"focus": [], "people": requested, "members": [], "identities": identities, "source": proposal.source_ids[0]}
		var reserved: Dictionary = attention.reserve(self, needs)
		if not reserved.ok: return false
		token = reserved.token
	var parents: Array = proposal.source_ids.duplicate()
	var opportunity: String = ""
	if rule.source_mode == "current_background" and not reuse_existing:
		opportunity = _record("background_opportunity", domain, "", [domain], parents, {"template": rule.id, "source_mode": rule.source_mode, "current_turn": state.turn})
		parents = [opportunity]
	if rule.actor_policy == "nominate" and not reuse_existing:
		var actor: String = "NPC-%08d" % int(state.next_npc)
		if not _nominate({"domain": domain, "profile": rule.profile, "institution": domain + "/" + rule.institution_role, "group": rule.population_group, "parents": parents, "attention_token": token, "identity_key": identity_key}): return false
		actors.append(actor)
		parents.append("FACT-%08d" % (int(state.next_fact) - 1))
	var id: String = "BACKGROUND-%08d" % int(sim.next_candidate)
	sim.next_candidate += 1
	var fact: String = "FACT-%08d" % int(state.next_fact)
	var card: Dictionary = {"id": id, "template": rule.id, "content_id": rule.content_id, "domain": domain, "actors": actors, "fallback_ids": [], "source_ids": _unique_sorted(parents), "source_mode": rule.source_mode, "once_key": proposal.once_key, "proposal_hash": fingerprint, "policy": abstract_sim.version, "snapshot_version": proposal.snapshot_version, "sample_before": proposal.sample_before, "sample_after": proposal.sample_after, "created_turn": state.turn, "visible_turn": visible, "due_turn": visible + int(rule.lifetime) - 1, "default_result": rule.expiry_rule, "crisis": "CRISIS/" + id, "fact": fact}
	_record("background_fixed", domain, "", actors, parents, {"candidate": card})
	stage_collections(["applied_authorizations"])
	Store.put(state.applied_authorizations, once, fact)
	sim.candidates[id] = card
	for actor: String in actors:
		if not sim.holds.has(actor): sim.holds[actor] = []
		sim.holds[actor].append(id)
	if not token.is_empty(): attention.finish(self, token)
	return true

func background_candidates(owner: Object = null) -> Array:
	if not _driver_allowed(owner) or not state.has("simulation"): return []
	var result: Array = []
	for id: String in _keys(state.simulation.candidates):
		var card: Dictionary = state.simulation.candidates[id]
		if card.visible_turn <= state.turn and card.due_turn >= state.turn and _background_valid(card): result.append(card.duplicate(true))
	return result

func _background_valid(card: Dictionary) -> bool:
	for actor: String in card.actors:
		if not Store.has(state.npcs, actor) or not _active(Store.entry(state.npcs, actor)) or Store.entry(state.npcs, actor).domain != card.domain: return false
	for source: String in card.source_ids:
		if not Store.has(state.facts, source) or Store.has(state.invalid_records, source): return false
	return true

func _close_background(card: Dictionary, result: String) -> void:
	stage_collections(["attention", "simulation"])
	_record("background_" + result, card.domain, "", card.actors, [card.fact], {"candidate": card.id, "crisis": card.crisis, "due_turn": card.due_turn, "rule": card.default_result})
	for actor: String in card.actors:
		if Attention.enabled(state) and Store.has(state.npcs, actor) and Store.entry(state.npcs, actor).status != "dead":
			if actor in attention.occupied(state, "members"): state.attention.used_n[actor] = state.turn
			else: state.attention.used_p[actor] = state.turn
		state.simulation.holds[actor].erase(card.id)
		if state.simulation.holds[actor].is_empty(): state.simulation.holds.erase(actor)
	state.simulation.candidates.erase(card.id)

func settle_background(owner: Object = null, invalid_only: bool = false) -> bool:
	if not _driver_allowed(owner): return false
	if not state.has("simulation"): return true
	stage_collections(["simulation", "npcs", "domains"])
	for id: String in _keys(state.simulation.candidates):
		var card: Dictionary = state.simulation.candidates[id]
		if not _background_valid(card): _close_background(card, "cancelled"); continue
		if invalid_only or int(card.due_turn) > int(state.turn): continue
		var actor: Dictionary = Store.entry(state.npcs, card.actors[0])
		var loss: int = catalog.integer("request_unanswered_trust_loss") if actor.loyalty >= catalog.integer("loyalty_follower_threshold") else 0
		actor.loyalty = maxi(0, int(actor.loyalty) - loss)
		_history_person(actor.id)
		var domain: Dictionary = state.domains[card.domain]
		domain.alert = mini(catalog.integer("attribute_max"), int(domain.alert) + catalog.integer("request_unanswered_alert"))
		domain.exposure_turn = state.turn
		if introduce_fact("exposure", card.domain, actor.id, [actor.id], [card.fact], {"public": true, "rule": "unanswered_request"}, [], [card.domain + "/order"], owner).is_empty(): return false
		_close_background(card, "expired")
	return true

func fix_background_successor(authorization: String, owner: Object = null) -> bool:
	if not _driver_allowed(owner) or owner == null or transaction == null or not owner.context.phase in ["events", "actions"] or not state.has("simulation") or not Store.has(state.facts, authorization): return false
	var fact: Dictionary = Store.entry(state.facts, authorization)
	if fact.kind != "background_successor_authorized" or not fact.changes.get("parent") is String or not Store.has(state.facts, fact.changes.parent): return false
	var parent_fact: Dictionary = Store.entry(state.facts, fact.changes.parent)
	if parent_fact.kind != "background_fixed" or not parent_fact.changes.get("candidate") is Dictionary or not fact.changes.parent in fact.causal_parents: return false
	var card: Dictionary = parent_fact.changes.candidate
	if fact.domain != card.domain or fact.targets != card.actors: return false
	stage_current()
	var proposal: Dictionary = {"snapshot_version": transaction.sequence, "producer": "deterministic", "object": card.domain, "duty": "candidate_fixation", "template": card.template, "source_ids": _unique_sorted([card.fact, authorization]), "actors": card.actors.duplicate(), "once_key": "successor/" + authorization, "sample_before": card.sample_after, "sample_after": card.sample_after}
	# Use the authorization's immutable position, so exact replay after later
	# commits has the same proposal fingerprint and does not reset its deadline.
	proposal.snapshot_version = int(fact.changes.get("snapshot_version", 0))
	if not _fix_background(proposal, int(state.turn) + 1, true): return false
	if state.simulation.candidates.has(card.id): _close_background(card, "continued")
	return true

func mutable_npc(id: String) -> Dictionary:
	stage_collections(["npcs"])
	var person: Dictionary = Store.entry(state.npcs, id)
	if person.is_read_only():
		person = HistoryIndex.copy_current(person)
		Store.put(state.npcs, id, person)
	return person

func expand_focused_domain(domain_id: String) -> void:
	if not Attention.enabled(state): return
	stage_current()
	var origin: String = _record("focus_acquired", domain_id, "", [domain_id], [state.domains[domain_id].origin], {"turn": state.turn})
	var remaining: int = int(attention.parameters.local_actor_limit)
	var named: Array = history.ids("active/" + domain_id)
	remaining -= named.filter(func(id: String) -> bool: return not id in state.simulation.persistent and not id in attention.occupied(state, "people")).size()
	for institution_id: String in state.domains[domain_id].institutions:
		var institution: Dictionary = state.institutions[institution_id]
		if institution.get("occupancy") != "occupied_abstract" or not str(institution.representative).is_empty() or remaining <= 0: continue
		var lawful: Array = _profiles_for(domain_id, institution_id)
		if lawful.is_empty() or not _attention_identity_available(): continue
		var id: String = "NPC-%08d" % int(state.next_npc)
		var profile: Dictionary = lawful[0] # Stable lawful selection, no refresh roll.
		if not _nominate_local(domain_id, institution_id, profile.id, origin): continue
		institution.representative = id; institution.occupancy = "represented"; remaining -= 1
	while remaining > 0 and _attention_identity_available() and state.domains[domain_id].unnamed_nonfollowers > 0:
		var institution_id: String = domain_id + "/interpretation"
		var lawful: Array = _profiles_for(domain_id, institution_id)
		if lawful.is_empty() or not _nominate_local(domain_id, institution_id, lawful[0].id, origin): break
		remaining -= 1
	attention.sync(self)

func _attention_identity_available() -> bool:
	var reserved: Array = []
	for entry: Dictionary in state.attention.reservations.values(): Attention._add(reserved, entry.identities)
	return int(state.attention.living_count) + reserved.size() < catalog.integer("living_named_global_limit")

func _nominate_local(domain: String, institution: String, profile: String, source: String) -> bool:
	# Local L is reserved by the focused domain itself. It never grants N or P.
	return _nominate({"domain": domain, "institution": institution, "profile": profile, "group": "unnamed_nonfollowers", "parents": [source]}, true)

func generate_hybrid(seed_value: int) -> bool:
	return generate(seed_value, null, true)
