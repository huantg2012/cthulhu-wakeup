extends RefCounted
## Append-only observations at real contact boundaries. No RNG or extra action.
const Store = preload("res://src/simulation/archive_store.gd")
const Intel = preload("res://src/game/world_intelligence.gd")
const Economy = preload("res://src/game/economy.gd")
const VERSION := "world-observation/1"

static func _root(fact: Dictionary) -> String:
	if fact.kind in ["power_effect", "prayer_delta", "event_delta"] and not fact.causal_parents.is_empty(): return str(fact.causal_parents[0])
	if fact.kind in ["event_fixed", "background_fixed"]:
		var card: Dictionary = fact.changes.get("candidate", {})
		return str(card.get("descriptor", {}).get("source", card.get("source", fact.id)))
	return str(fact.id)

static func _source_key(domain: String, root: String) -> String:
	return Intel.observation_source_key(domain, root)

static func _contact(state: Dictionary, fact: Dictionary, row: Dictionary, ledger: Dictionary, catalog: RefCounted, baseline: Dictionary = {}) -> Dictionary:
	if fact.kind != row.source_kind or not ledger.known_domains.has(fact.domain): return {}
	if row.selector != "cult_offering" and not ledger.known_facts.has(fact.id): return {}
	match str(row.selector):
		"world_delta":
			var field: String = str(fact.changes.get("field", ""))
			if not field in Intel.FIELDS or fact.changes.get("power") == "POWER_LISTEN": return {}
			if fact.kind == "prayer_delta" and not str(fact.domain) in fact.targets: return {}
			if fact.kind == "event_delta" and fact.changes.get("subject") != "domain": return {}
			if fact.kind == "power_effect":
				if int(fact.changes.get("actual", 0)) == 0: return {}
			else:
				# Legacy prayer/event receipts record requested amounts, not clamped
				# actual changes. Require a changed field at this transaction boundary;
				# capped or mutually cancelling requests cannot mint a new observation.
				var prior: Dictionary = baseline.get("domains", {}).get(fact.domain, {})
				if not prior.has(field) or int(prior[field]) == int(state.domains[fact.domain][field]): return {}
		"event_contact":
			var card: Dictionary = fact.changes.get("candidate", {})
			var content: String = str(card.get("content_id", ""))
			if catalog.tables.events.get(content, {}).get("scope") != "institution" or not str(card.get("id", "")) in state.event_system.selected: return {}
		"resistance_notice": pass
		"cult_offering":
			var cult: Dictionary = state.cults.get(str(fact.changes.get("cult", "")), {})
			if cult.is_empty() or not str(fact.changes.get("reason", "missing")).is_empty() or not Economy.operational_reason(state, cult, catalog).is_empty(): return {}
			var person: Dictionary = Store.entry(state.npcs, str(cult.get("leader", "")), {})
			if person.get("status") != "active" or not person.get("bound_member", false) or person.get("domain") != fact.domain or person.get("cult_id") != cult.id: return {}
			return {"observer": str(person.id), "cult": str(cult.id)}
		_: return {}
	return {"observer": str(fact.actor), "cult": ""}

static func publish(world: RefCounted, owner: RefCounted, before: Dictionary, ledger: Dictionary, first_fact: int) -> Array[String]:
	if world.transaction == null or not world._driver_allowed(owner): return []
	var groups: Dictionary = {}
	# A first complete encounter is already authorized by the knowledge reducer.
	for domain: String in ledger.known_domains:
		if before.known_domains.has(domain): continue
		var observation: Dictionary = ledger.domain_intelligence.get(domain, {}).get("pollution", {})
		var source: String = str(observation.get("source", ""))
		if Store.has(world.state.facts, source):
			var root: String = _root(Store.entry(world.state.facts, source))
			if not Store.has(world.state.applied_authorizations, _source_key(domain, root)): groups[domain] = {"sources": [source], "roots": [root], "observer": "", "cult": "", "first_contact": true}
	var incoming: Dictionary = {}
	for number: int in range(first_fact, int(world.state.next_fact)): incoming["FACT-%08d" % number] = true
	# Event cards can be frozen before their actual presentation. Only a newly
	# learned, currently selected institution event counts as this new contact.
	for source: String in ledger.known_facts:
		if before.known_facts.has(source): continue
		if Store.entry(world.state.facts, source).kind in ["event_fixed", "background_fixed"]: incoming[source] = true
	var sources: Array = incoming.keys(); sources.sort()
	for source: String in sources:
		var fact: Dictionary = Store.entry(world.state.facts, source)
		for row: Dictionary in world.catalog.tables.world_observation_sources.values():
			var contact: Dictionary = _contact(world.state, fact, row, ledger, world.catalog, world.transaction.base_state)
			if contact.is_empty(): continue
			var root: String = _root(fact)
			if root.is_empty() or not Store.has(world.state.facts, root) or Store.has(world.state.applied_authorizations, _source_key(str(fact.domain), root)): continue
			if not groups.has(fact.domain): groups[fact.domain] = {"sources": [], "roots": [], "observer": "", "cult": "", "first_contact": false}
			if not fact.id in groups[fact.domain].sources: groups[fact.domain].sources.append(fact.id)
			if not root in groups[fact.domain].roots: groups[fact.domain].roots.append(root)
			if not str(contact.observer).is_empty(): groups[fact.domain].observer = contact.observer
			if not str(contact.cult).is_empty(): groups[fact.domain].cult = contact.cult
	var messages: Array[String] = []
	var domains: Array = groups.keys(); domains.sort()
	for domain: String in domains:
		var group: Dictionary = groups[domain]; group.sources.sort(); group.roots.sort()
		var key: String = "world/observation/" + domain + "/" + JSON.stringify(group.roots).sha256_text()
		if Store.has(world.state.applied_authorizations, key): continue
		var metrics: Dictionary = {}
		for field: String in Intel.FIELDS: metrics[field] = int(world.state.domains[domain][field])
		var data: Dictionary = {"version": VERSION, "sources_version": world.catalog.extension_versions.world_observation_sources, "sources": group.sources, "roots": group.roots, "first_contact": group.first_contact, "observer": group.observer, "cult": group.cult, "phase": str(owner.context.phase), "metrics": metrics}
		var observation: String = world._record("world_observation", domain, group.observer, [], group.sources, data)
		var message_id: String = "FACT-%08d" % int(world.state.next_fact)
		var ranges: Dictionary = Intel.first_observation(metrics, world.catalog, message_id, owner.context, int(observation.trim_prefix("FACT-")))
		for field: String in ranges: ranges[field]["observation"] = observation
		var message: String = world._record("message", domain, group.observer, [], group.sources + [observation], {"public": true, "observation_version": VERSION, "fact": observation, "intelligence": ranges, "observer": group.observer, "cult": group.cult})
		world.stage_collections(["applied_authorizations"])
		Store.put(world.state.applied_authorizations, key, message)
		for root: String in group.roots: Store.put(world.state.applied_authorizations, _source_key(domain, root), message)
		messages.append(message)
	return messages
