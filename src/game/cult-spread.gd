extends RefCounted
## Current local recruitment sources. This is a bounded Cults-owned projection,
## not a social simulation or an additional material receipt authority.
const Store = preload("res://src/simulation/archive_store.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const ID: String = "cult_spread/schema2"

static func version(content: RefCounted) -> String:
	return ID + "/" + content.version + "/" + str(content.extension_versions.get("cult_spread_routes", "missing")) + "/" + str(content.extension_versions.get("cult_spread_conditions", "missing"))

static func fact(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	return Materials._fact(state, id, reader)

static func live(state: Dictionary, id: String, reader: RefCounted = null) -> bool:
	return not fact(state, id, reader).is_empty() and not (reader.invalidated(id) if reader != null and reader.has_method("invalidated") else Store.has(state.invalid_records, id))

static func cell_data(state: Dictionary, cult: Dictionary, content: RefCounted) -> Dictionary:
	var leader: Dictionary = Store.entry(state.npcs, str(cult.leader), {})
	if cult.status != "active" or state.domains[cult.domain].unnamed_followers <= 0 or cult.cohesion <= 0 or leader.get("status") != "active" or leader.get("domain") != cult.domain or not leader.get("bound_member", false) or leader.get("cult_id") != cult.id or int(leader.get("loyalty", 0)) < content.integer("loyalty_follower_threshold"): return {}
	var established: Dictionary = fact(state, cult.established_source)
	var joined: Dictionary = fact(state, str(leader.get("joined_source", "")))
	if established.get("kind") != "cult_established" or established.changes.get("cult") != cult.id or joined.get("kind") != "cult_member_joined" or joined.changes.get("cult") != cult.id or joined.actor != leader.id: return {}
	return {"issuer": "cults", "version": version(content), "route_id": "COVERT_CELL", "cult": cult.id, "domain": cult.domain, "operator": leader.id, "via": cult.id, "origin": cult.established_source, "material": "", "recipient": ""}

static func route_valid(state: Dictionary, source: String, reader: RefCounted = null) -> bool:
	var route: Dictionary = fact(state, source, reader); var data: Dictionary = route.get("changes", {})
	if route.get("kind") != "cult_contact_route" or data.size() != 10 or data.get("version") != state.get("cult_system", {}).get("spread_version") or not state.cults.has(data.get("cult", "")) or not live(state, source, reader): return false
	var cult: Dictionary = state.cults[data.cult]
	if route.domain != cult.domain or data.get("domain") != cult.domain or cult.status != "active" or state.domains[cult.domain].unnamed_followers <= 0 or cult.cohesion <= 0: return false
	var person: Dictionary = Materials._person(state, str(data.get("operator", "")), reader)
	if person.get("status") != "active" or person.get("domain") != cult.domain or not live(state, str(data.get("origin", "")), reader): return false
	if data.get("route_id") == "COVERT_CELL":
		return data.get("issuer") == "cults" and data.get("via") == cult.id and data.get("origin") == cult.established_source and data.get("operator") == cult.leader and data.get("material") == "" and data.get("recipient") == "" and person.get("bound_member", false) and person.get("cult_id") == cult.id and person.get("joined_source", "") in route.causal_parents and cult.get("succession_source", cult.established_source) in route.causal_parents and person.get("binding_source", "") in route.causal_parents
	if data.get("route_id") != "ALLIED_CHANNEL" or data.get("issuer") != "events" or person.get("institution") != data.get("via") or not state.institutions.has(data.get("via", "")): return false
	var result: Dictionary = fact(state, data.origin, reader)
	var descriptor: Dictionary = result.get("changes", {}).get("descriptor", {})
	if result.get("kind") != "event_result" or result.changes.get("content_id") != "EVENT_09" or result.changes.get("option") != "A" or descriptor.get("subjects", {}).get("cooperator") != data.operator or descriptor.get("subjects", {}).get("recipient") != data.recipient or descriptor.get("facts", {}).get("material") != data.material: return false
	if not live(state, str(descriptor.get("facts", {}).get("relation", "")), reader): return false
	var recipient: Dictionary = Materials._person(state, data.recipient, reader)
	var target: String = str(descriptor.get("subjects", {}).get("target_institution", ""))
	if recipient.get("status") != "active" or recipient.get("domain") != cult.domain or recipient.get("cult_id") != cult.id or not recipient.get("bound_member", false) or recipient.get("institution") != target: return false
	if data.via != target and not Anchors.Routes.connected(state, data.via, target): return false
	return true

static func receipt(state: Dictionary, route: Dictionary, reader: RefCounted = null) -> String:
	if route.changes.route_id == "COVERT_CELL": return ""
	for id: String in Materials._receipts(state, route.changes.material, reader):
		var data: Dictionary = fact(state, id, reader).get("changes", {})
		if data.get("recipient") == route.changes.recipient and data.get("channel", {}).get("source") == route.id and data.get("trigger") == route.changes.origin and live(state, data.source, reader): return id
	return ""

static func select(state: Dictionary, cult: String, reader: RefCounted = null) -> Dictionary:
	var candidates: Array = []
	for id: String in state.get("cult_system", {}).get("spread_routes", {}).get(cult, []):
		if not route_valid(state, id, reader): continue
		var route: Dictionary = fact(state, id, reader)
		var received: String = receipt(state, route, reader)
		if route.changes.route_id == "ALLIED_CHANNEL" and received.is_empty(): continue
		candidates.append({"source": id, "route": route, "receipt": received})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.route.changes.route_id != b.route.changes.route_id: return a.route.changes.route_id < b.route.changes.route_id
		return a.route.changes.origin < b.route.changes.origin)
	return candidates[0] if not candidates.is_empty() else {}

static func refresh(world: RefCounted, owner: Object = null) -> bool:
	if not world.state.has("cult_system") or not world.state.has("economy"): return true
	if not world._driver_allowed(owner): return false
	world.stage_collections(["cult_system", "economy_qualifications", "applied_authorizations"])
	var state: Dictionary = world.state; var ledger: Dictionary = state.cult_system
	for cult: Dictionary in state.cults.values():
		var data: Dictionary = cell_data(state, cult, world.catalog)
		var current: Array = []
		for id: String in ledger.spread_routes.get(cult.id, []):
			if fact(state, id).changes.route_id == "ALLIED_CHANNEL": current.append(id)
		if not data.is_empty():
			var leader: Dictionary = Store.entry(state.npcs, cult.leader)
			var parents: Array = world._unique_sorted([cult.established_source, cult.get("succession_source", cult.established_source), leader.joined_source, leader.binding_source])
			var identity: String = "cult/cell/" + JSON.stringify([data, parents], "", true, true).sha256_text()
			var source: String = Store.entry(state.applied_authorizations, identity, "")
			if source.is_empty():
				source = world._record("cult_contact_route", cult.domain, cult.leader, [cult.id, cult.leader], parents, data)
				Store.put(state.applied_authorizations, identity, source)
			current.append(source)
		ledger.spread_routes[cult.id] = current
		var selected: Dictionary = select(state, cult.id, world.history)
		var basis: Dictionary = {"channel": selected.get("source", ""), "established": cult.established_source, "leader": cult.get("succession_source", cult.established_source), "receipt": selected.get("receipt", "")}
		var institution: String = "" if selected.is_empty() or selected.route.changes.route_id == "COVERT_CELL" else selected.route.changes.via
		var proof: Dictionary = {"issuer": ID, "version": version(world.catalog), "rule": "propagation", "subject": cult.id, "allowed": not selected.is_empty(), "institution": institution, "population_scope": "local_unnamed_nonfollowers", "basis": basis}
		var identity: String = "cult/recruitment/" + JSON.stringify(proof, "", true, true).sha256_text()
		var source: String = Store.entry(state.applied_authorizations, identity, "")
		if source.is_empty():
			var parents: Array = [cult.established_source, basis.leader]
			for id: String in [basis.channel, basis.receipt]:
				if not id.is_empty(): parents.append(id)
			source = world._record("economy_qualification", cult.domain, "", [cult.id] + ([] if institution.is_empty() else [institution]), world._unique_sorted(parents), proof)
			Store.put(state.applied_authorizations, identity, source)
		state.economy_qualifications["propagation|" + cult.id] = source
	return true

static func qualification(state: Dictionary, cult: String, reader: RefCounted = null) -> Dictionary:
	var source: String = state.get("economy_qualifications", {}).get("propagation|" + cult, "")
	var proof: Dictionary = fact(state, source, reader); var data: Dictionary = proof.get("changes", {})
	if proof.get("kind") != "economy_qualification" or data.get("issuer") != ID or data.get("version") != state.cult_system.spread_version or data.get("subject") != cult or data.get("population_scope") != "local_unnamed_nonfollowers" or not data.get("basis") is Dictionary: return {"ok": false, "error": "Missing current secret recruitment capability"}
	var selected: Dictionary = select(state, cult, reader)
	return {"ok": true, "allowed": not selected.is_empty(), "reason": "no_current_cult_channel" if selected.is_empty() else "", "source": source, "channel": selected.get("source", "")}

static func validate(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if state.cult_system.get("spread_version") != version(content) or not state.cult_system.get("spread_routes") is Dictionary: return ["Invalid secret recruitment capability"]
	for cult: String in state.cult_system.spread_routes:
		if not state.cults.has(cult) or not state.cult_system.spread_routes[cult] is Array: return ["Invalid current cult source index"]
		for id: Variant in state.cult_system.spread_routes[cult]:
			if not id is String or fact(state, id).get("kind") != "cult_contact_route" or fact(state, id).changes.get("cult") != cult: return ["Cult source index changed its owner"]
	for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
		var item: Dictionary = fact(state, "FACT-%08d" % number); var data: Dictionary = item.get("changes", {})
		if item.get("kind") == "cult_contact_route":
			if data.size() != 10 or data.get("version") != version(content) or not content.tables.cult_spread_routes.has(data.get("route_id", "")) or not data.get("origin", "") in item.causal_parents or not data.get("cult", "") in item.targets: return ["Invalid secret source history"]
			var origin: Dictionary = fact(state, str(data.origin))
			if data.route_id == "COVERT_CELL" and (data.issuer != "cults" or origin.get("kind") != "cult_established" or origin.changes.get("cult") != data.cult): return ["Cell lacks actual cult establishment"]
			if data.route_id == "ALLIED_CHANNEL" and (data.issuer != "events" or origin.get("kind") != "event_result" or origin.changes.get("content_id") != "EVENT_09" or origin.changes.get("option") != "A"): return ["Cooperation lacks actual event result"]
		if item.get("kind") == "economy_qualification" and data.get("issuer") == ID:
			if data.size() != 8 or data.get("version") != version(content) or data.get("rule") != "propagation" or not state.cults.has(data.get("subject", "")) or not data.get("allowed") is bool or data.get("population_scope") != "local_unnamed_nonfollowers" or not data.get("basis") is Dictionary or data.basis.size() != 4: return ["Invalid secret recruitment proof"]
	return []
