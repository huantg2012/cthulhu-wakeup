extends RefCounted
## The one read-only route evaluator. Its inputs are normalized by Anchors from
## actual owned results; evaluate_normalized is also the explicit consumer-only
## test seam. It never issues facts, grants knowledge or consumes random streams.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const SELECTORS: Array[String] = ["testimonies", "operator_dependency", "rites", "keeper", "ritual_practice", "memory_circle", "pair_dependency", "network_independent", "network_exchange", "contract_performance", "contract_reciprocal", "axiom_nodes"]

static func fields(row: Dictionary) -> Array:
	return Array(str(row.get("required", "")).split("|", false))

static func strings(value: Variant, count: int = -1, unique: bool = true) -> bool:
	if not value is Array or (count >= 0 and value.size() != count): return false
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is String or item.is_empty() or (unique and seen.has(item)): return false
		seen[item] = true
	return true

static func number(row: Dictionary, parameter: String, literal: String, catalog: RefCounted) -> int:
	return catalog.integer(row[parameter]) if not str(row.get(parameter, "")).is_empty() else int(row.get(literal, 0))

static func _person(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.get("npcs", {}), id): return Store.entry(state.npcs, id)
	if reader != null and reader.has_method("entity"):
		var found: Dictionary = reader.entity("npcs", id)
		if found.get("ok", false): return found.item
	return {}

static func active(state: Dictionary, id: String, domain: String, reader: RefCounted = null) -> bool:
	var person: Dictionary = _person(state, id, reader)
	return person.get("status") == "active" and person.get("domain") == domain

static func connected(state: Dictionary, a: String, b: String) -> bool:
	return a != b and state.institutions.has(a) and state.institutions.has(b) and state.institutions[a].domain == state.institutions[b].domain and b in state.institutions[a].get("links", []) and a in state.institutions[b].get("links", [])

static func _known(state: Dictionary, person: String, material: Dictionary, reader: RefCounted = null) -> bool:
	for source: String in material.get("knowledge", [str(material.get("id", ""))]):
		if reader != null:
			if reader.has_method("fact"):
				if reader.knows(person, source): return true
			elif reader.knows(state, person, source): return true
		elif History.has(_person(state, person).get("known_facts", []), source): return true
	return false

static func held(state: Dictionary, material: Dictionary, person: String, institution: String, reader: RefCounted = null) -> bool:
	if material.is_empty() or not material.get("current", false) or not state.institutions.has(institution): return false
	var npc: Dictionary = _person(state, person, reader)
	return active(state, person, state.institutions[institution].domain, reader) and npc.get("institution") == institution and person in material.get("owners", []) and _known(state, person, material, reader)

static func _material(materials: Dictionary, id: Variant, kinds: Array = [], current: bool = true) -> Dictionary:
	if not id is String or not materials.get(id) is Dictionary: return {}
	var item: Dictionary = materials[id]
	if item.get("id") != id or (current and not item.get("current", false)) or (not kinds.is_empty() and not item.get("kind") in kinds): return {}
	return item

static func _deny(reason: String, missing: Array = []) -> Dictionary:
	return {"ok": true, "allowed": false, "reason": reason, "missing": [reason] if missing.is_empty() else missing}

static func _references(basis: Dictionary, materials: Dictionary) -> Array:
	var result: Array = []
	for value: Variant in basis.values():
		if value is String and materials.has(value): result.append(value)
		elif value is Array:
			for item: Variant in value:
				if item is String and materials.has(item) and not item in result: result.append(item)
	for carrier: Dictionary in basis.get("carriers", []):
		for source: String in carrier.sources:
			if materials.has(source) and not source in result: result.append(source)
	for id: String in result.duplicate():
		for cause: String in materials[id].get("causes", []):
			if not cause.is_empty() and not cause in result: result.append(cause)
	result.sort()
	return result

static func _cover(state: Dictionary, materials: Dictionary, required: Array, institution: String, forced: Dictionary, reader: RefCounted = null) -> Array:
	var sources: Array = []
	for source: String in required:
		if not source in sources: sources.append(source)
	if sources.is_empty() or sources.size() > 30: return []
	var candidates: Dictionary = {}
	for position: int in sources.size():
		var item: Dictionary = _material(materials, sources[position])
		if item.is_empty(): return []
		var office: String = str(forced.get(item.id, {}).get("institution", institution))
		var owner: String = str(forced.get(item.id, {}).get("person", ""))
		for person: String in ([owner] if not owner.is_empty() else item.get("owners", [])):
			if not held(state, item, person, office, reader): continue
			var key: String = office + "|" + person
			if not candidates.has(key): candidates[key] = {"institution": office, "person": person, "mask": 0}
			candidates[key].mask |= 1 << position
	# Exact small set cover over only this route's necessary material IDs. The
	# finite source bound is a parser guard, not an authored population limit.
	var states: Dictionary = {0: []}; var keys: Array = candidates.keys(); keys.sort()
	for key: String in keys:
		for mask: int in states.keys():
			var next: int = mask | int(candidates[key].mask)
			var chosen: Array = states[mask].duplicate(); chosen.append(key)
			if not states.has(next) or chosen.size() < states[next].size() or (chosen.size() == states[next].size() and JSON.stringify(chosen) < JSON.stringify(states[next])): states[next] = chosen
	var complete: int = (1 << sources.size()) - 1
	if not states.has(complete): return []
	var result: Array = []
	for key: String in states[complete]: result.append({"institution": candidates[key].institution, "person": candidates[key].person, "sources": []})
	for position: int in sources.size():
		for carrier: Dictionary in result:
			if int(candidates[carrier.institution + "|" + carrier.person].mask) & (1 << position): carrier.sources.append(sources[position]); break
	for carrier: Dictionary in result: carrier.sources.sort()
	return result

static func evaluate_normalized(state: Dictionary, institution: String, basis: Dictionary, materials: Dictionary, catalog: RefCounted, reader: RefCounted = null, purpose: String = "anchor", actor: String = "") -> Dictionary:
	if not purpose in ["anchor", "spread"] or not state.get("institutions", {}).has(institution): return _deny("missing_institution_slot")
	var route: String = str(basis.get("route", ""))
	var row: Dictionary = catalog.tables.get("anchor_route_rules", {}).get(route, {})
	var domain: String = state.institutions[institution].domain
	if row.is_empty() or not state.domains.has(domain) or row.profile != state.domains[domain].profile: return _deny("route_blueprint_mismatch")
	var required_fields: Array = fields(row) + ["route"]
	var optional: Array = Array(str(row.optional).split("|", false)) + ["carriers"]
	for key: Variant in basis:
		if not key in required_fields + optional: return _deny("unexpected_route_field")
	for key: String in required_fields:
		if not basis.has(key): return _deny("missing_route_field", [key])
	var count: int = number(row, "count_parameter", "count", catalog)
	var turns_required: int = number(row, "turn_parameter", "turns", catalog)
	var alive_min: int = number(row, "alive_parameter", "alive_min", catalog)
	if purpose == "spread" and not str(row.spread_alive_parameter).is_empty(): alive_min = catalog.integer(row.spread_alive_parameter)
	var current: Array = []; var forced: Dictionary = {}; var original: Array = []; var personal_sources: Array = []
	var route_error: String = ""
	match str(row.selector):
		"testimonies", "network_independent", "axiom_nodes":
			if not strings(basis.get("records"), count): return _deny("distinct_record_count_unmet")
			var witnesses: Array = basis.get("witnesses", [])
			if row.selector != "axiom_nodes" and not strings(witnesses, count): return _deny("distinct_witness_count_unmet")
			if row.selector != "testimonies" and not connected(state, institution, str(basis.get("other_institution", ""))): return _deny("current_two_node_contact_missing")
			var roots: Dictionary = {}; var turns: Dictionary = {}; var family: String = ""; var observers: Dictionary = {}
			for position: int in count:
				var item: Dictionary = _material(materials, basis.records[position], ["evidence", "dream"] if row.selector != "axiom_nodes" else ["exception_record"])
				if item.is_empty(): return _deny("record_not_actual_success_material")
				var person: String = str(item.data.get("observer", "")) if row.selector == "axiom_nodes" else str(witnesses[position])
				var office: String = institution if row.selector == "testimonies" or position == 0 else str(basis.other_institution)
				if not person in item.get("originals", []) or not active(state, person, domain, reader): return _deny("original_witness_unavailable")
				if roots.has(item.root) or observers.has(person): return _deny("records_not_independent")
				if row.selector == "axiom_nodes":
					if item.data.get("exception") != basis.exception or item.institution != office or not _material(materials, basis.exception, ["exception"]).get("current", false): return _deny("original_exception_observer_node_mismatch")
				elif row.selector == "network_independent":
					if not family.is_empty() and family != item.kind: return _deny("network_records_not_same_family")
					family = item.kind
				elif purpose == "anchor" and turns.has(item.turn): return _deny("testimony_turns_not_distinct")
				roots[item.root] = true; turns[item.turn] = true; observers[person] = true
				current.append(item.id); original.append(person)
				if row.selector != "testimonies": forced[item.id] = {"institution": office, "person": person}
		"operator_dependency":
			var kind: String = {"record_dependency": "record_dependency", "calendar_dependency": "calendar_dependency", "axiom_archive": "axiom_dependency"}[route]
			var dependency: Dictionary = _material(materials, basis.dependency, [kind])
			if dependency.is_empty() or dependency.institution != institution or dependency.data.get("operator") != basis.operator or dependency.data.get("uses") != basis.uses: return _deny("actual_operator_dependency_missing")
			var series_key: String = "exception" if route == "axiom_archive" else "series"
			if dependency.data.get(series_key) != basis[series_key] or not strings(basis.uses, turns_required): return _deny("dependency_series_or_use_count_mismatch")
			var series: Dictionary = _material(materials, basis[series_key], ["exception" if route == "axiom_archive" else ("record_series" if route == "record_dependency" else "calendar_pulse")])
			if series.is_empty(): return _deny("dependency_origin_unavailable")
			var turns: Dictionary = {}; var previous_use: String = ""
			for id: String in basis.uses:
				var item: Dictionary = _material(materials, id, ["axiom_use" if route == "axiom_archive" else ("record_use" if route == "record_dependency" else "calendar_use")])
				if item.is_empty() or item.data.get("operator") != basis.operator or item.data.get(series_key) != basis[series_key] or item.institution != institution or turns.has(item.turn) or not basis.operator in item.get("originals", []): return _deny("use_not_original_operator_or_distinct_turn")
				var ordered: String = "%012d/" % int(item.turn) + item.id
				if not previous_use.is_empty() and ordered <= previous_use: return _deny("use_order_is_not_original_turn_order")
				previous_use = ordered; turns[item.turn] = true; current.append(id)
			current.append(basis.dependency); original = [basis.operator]
			for id: String in current: forced[id] = {"institution": institution, "person": basis.operator}
		"rites", "keeper":
			var rituals: Array = basis.get("rituals", [basis.get("ritual", "")])
			if not strings(rituals, count): return _deny("actual_ritual_count_unmet")
			var turns: Dictionary = {}
			for id: String in rituals:
				var item: Dictionary = _material(materials, id, ["ritual"])
				if item.is_empty() or not basis.priest in item.get("originals", []) or item.data.get("priest") != basis.priest or item.institution != institution: return _deny("actual_ritual_keeper_missing")
				if turns.has(item.turn): return _deny("ritual_turns_not_distinct")
				turns[item.turn] = true; current.append(id); forced[id] = {"institution": institution, "person": basis.priest}
			original = [basis.priest]
		"ritual_practice":
			var lesson: Dictionary = _material(materials, basis.lesson, ["ritual_lesson"])
			var ritual: Dictionary = _material(materials, basis.ritual, ["practiced_rite"])
			if lesson.is_empty() or ritual.is_empty() or lesson.data.get("student") != basis.practitioner or ritual.data.get("practitioner") != basis.practitioner or ritual.data.get("lesson") != basis.lesson or ritual.turn <= lesson.turn or not lesson.data.get("teacher_qualified", false) or not basis.practitioner in ritual.get("originals", []): return _deny("actual_lesson_then_practice_missing")
			current = [basis.lesson, basis.ritual]; original = [basis.practitioner]
			for id: String in current: forced[id] = {"institution": institution, "person": basis.practitioner}
		"memory_circle":
			if not strings(basis.witnesses, count) or not strings(basis.qualifications, count): return _deny("original_memory_history_count_unmet")
			var memory: Dictionary = _material(materials, basis.memory, ["shared_memory"])
			var review: Dictionary = _material(materials, basis.review, ["memory_review"], false)
			if memory.is_empty() or review.is_empty() or review.data.get("memory") != basis.memory: return _deny("actual_shared_memory_review_missing")
			if route == "dissent_circle" and not strings(basis.get("conflicts"), count, false): return _deny("original_three_dissent_histories_missing")
			var alive: int = 0; var local_holders: Array = []
			for position: int in count:
				var person: String = basis.witnesses[position]
				var item: Dictionary = _material(materials, basis.qualifications[position], ["memory_qualification"], false)
				if item.is_empty() or item.data.get("memory") != basis.memory or item.data.get("review") != basis.review or item.data.get("person") != person or not person in item.get("originals", []) or not person in memory.get("originals", []) or not person in review.data.get("holders", []) or person == memory.data.get("host", ""): return _deny("memory_person_not_original_registered_witness")
				var conflict: Dictionary = {}
				if route == "dissent_circle":
					conflict = _material(materials, basis.conflicts[position], ["memory_conflict"], false)
					if conflict.is_empty() or conflict.data.get("memory") != basis.memory or conflict.data.get("review") != basis.review or not person in conflict.get("originals", []): return _deny("dissent_history_not_same_person_memory_review")
				if active(state, person, domain, reader) and item.current and (route != "dissent_circle" or conflict.current):
					var office: String = str(_person(state, person, reader).get("institution", ""))
					if not held(state, item, person, office, reader) or (not conflict.is_empty() and not held(state, conflict, person, office, reader)): return _deny("original_memory_holder_no_longer_holds_personal_material")
					alive += 1; current.append(item.id); forced[item.id] = {"institution": office, "person": person}
					if office == institution and held(state, memory, person, institution, reader): local_holders.append(person)
					if not conflict.is_empty():
						current.append(conflict.id); personal_sources.append({"institution": office, "person": person, "source": conflict.id})
				original.append(person)
			if alive < alive_min: return _deny("current_memory_witness_count_unmet")
			if local_holders.is_empty(): return _deny("target_has_no_original_shared_memory_carrier")
			local_holders.sort(); current.append(basis.memory); forced[basis.memory] = {"institution": institution, "person": local_holders[0]}
			# The same group-conflict result may be held by several actual people.
			# Pin its set-cover slot to one of them, then retain each person's
			# required holding without inventing additional source facts.
			for personal: Dictionary in personal_sources:
				if not forced.has(personal.source): forced[personal.source] = {"institution": personal.institution, "person": personal.person}
		"pair_dependency":
			var kind: String = "recollection_dependency" if route == "memory_practice" else "dissent_dependency"
			var dependency: Dictionary = _material(materials, basis.dependency, [kind])
			if dependency.is_empty() or not strings(basis.participants, count) or not strings(basis.registrations, count) or not strings(basis.uses, turns_required) or dependency.data.get("session") != basis.session or dependency.data.get("participants") != basis.participants or dependency.data.get("registrations") != basis.registrations or dependency.data.get("uses") != basis.uses: return _deny("actual_pair_dependency_missing")
			var session: Dictionary = _material(materials, basis.session, ["practice_session"])
			if session.is_empty() or session.get("originals", []) != basis.participants: return _deny("original_practice_session_missing")
			var views: Dictionary = {}; var turns: Dictionary = {}; var local: bool = false
			for position: int in count:
				var person: String = basis.participants[position]
				var registration: Dictionary = _material(materials, basis.registrations[position], ["practice_registration"])
				if registration.is_empty() or registration.data.get("person") != person or registration.data.get("session") != basis.session or not person in registration.get("originals", []) or not active(state, person, domain, reader): return _deny("pair_original_personal_qualification_missing")
				var office: String = str(_person(state, person, reader).get("institution", ""))
				local = local or office == institution
				if office != institution and not connected(state, institution, office): return _deny("pair_current_contact_missing")
				views[str(registration.data.get("viewpoint", ""))] = true
				for id: String in [registration.id] + basis.uses + [basis.dependency]:
					if not held(state, _material(materials, id), person, office, reader): return _deny("pair_original_person_no_longer_holds_practice")
					personal_sources.append({"institution": office, "person": person, "source": id})
				current.append(registration.id); forced[registration.id] = {"institution": office, "person": person}
			if not local or (route == "dissent_practice" and not (views.has("intact") and views.has("broken"))): return _deny("pair_local_carrier_or_opposed_views_missing")
			for id: String in basis.uses:
				var item: Dictionary = _material(materials, id, ["recollection_use" if route == "memory_practice" else "dissent_use"])
				if item.is_empty() or item.data.get("session") != basis.session or item.data.get("participants") != basis.participants or turns.has(item.turn): return _deny("pair_uses_not_distinct_actual_turns")
				turns[item.turn] = true; current.append(id)
			current.append(basis.dependency); original = basis.participants.duplicate()
		"network_exchange":
			if not connected(state, institution, str(basis.other_institution)): return _deny("current_two_node_contact_missing")
			var dependency: Dictionary = _material(materials, basis.exchange, ["network_dependency"])
			if dependency.is_empty() or not strings(dependency.data.get("endpoints"), count) or not strings(dependency.data.get("operators"), count) or dependency.data.get("institutions") != [institution, basis.other_institution]: return _deny("actual_network_two_endpoints_missing")
			for position: int in count:
				var person: String = dependency.data.operators[position]
				var office: String = dependency.data.institutions[position]
				var endpoint: Dictionary = _material(materials, dependency.data.endpoints[position], ["network_endpoint_use"])
				if endpoint.is_empty() or endpoint.data.get("operator") != person or endpoint.data.get("exchange") != dependency.data.get("exchange") or endpoint.institution != office or not person in endpoint.get("originals", []) or not held(state, dependency, person, office, reader): return _deny("network_original_endpoint_operator_missing")
				personal_sources.append({"institution": office, "person": person, "source": dependency.id})
				current.append(endpoint.id); forced[endpoint.id] = {"institution": office, "person": person}; original.append(person)
			current.append(basis.exchange)
		"contract_performance":
			var dependency: Dictionary = _material(materials, basis.dependency, ["contract_dependency"])
			var contract: Dictionary = _material(materials, basis.contract, ["contract"], false)
			if dependency.is_empty() or contract.is_empty() or dependency.data.get("contract") != basis.contract or (dependency.data.get("origin") != "prayer" and (dependency.data.get("term") != "preserve_record" or contract.data.get("term") != "preserve_record")) or not strings(basis.witnesses, count): return _deny("specific_preserve_record_dependency_missing")
			var parties: Array = contract.data.get("parties", [])
			if not strings(parties, count): return _deny("original_contract_parties_missing")
			var obligor: String = str(parties[0])
			if not active(state, obligor, domain, reader):
				var successor: Dictionary = _material(materials, basis.get("successor", ""), ["contract_successor"])
				if successor.is_empty() or successor.data.get("contract") != basis.contract or successor.data.get("obligor") != obligor or not active(state, str(successor.data.get("successor", "")), domain, reader): return _deny("actual_contract_successor_missing")
				current.append(successor.id)
			var witnessed: Dictionary = {}
			for id: String in basis.witnesses:
				var item: Dictionary = _material(materials, id, ["contract_witness"])
				if item.is_empty() or item.data.get("contract") != basis.contract or item.data.get("performance") != dependency.data.get("performance"): return _deny("contract_actual_two_end_witness_missing")
				for person: String in parties:
					if not person in item.get("originals", []): continue
					witnessed[person] = true
					if active(state, person, domain, reader):
						var office: String = str(_person(state, person, reader).get("institution", ""))
						if not held(state, item, person, office, reader): return _deny("living_contract_party_no_longer_holds_own_witness")
						current.append(id); forced[id] = {"institution": office, "person": person}
			if witnessed.size() != count: return _deny("contract_actual_two_end_witness_missing")
			current.append(basis.dependency); original = parties.duplicate()
		"contract_reciprocal":
			var dependency: Dictionary = _material(materials, basis.dependency, ["reciprocal_dependency"])
			var covenant: Dictionary = _material(materials, basis.covenant, ["reciprocal_covenant"], false)
			if dependency.is_empty() or covenant.is_empty() or not strings(basis.legs, count) or not strings(basis.parties, count) or not connected(state, institution, str(basis.other_institution)) or dependency.data.get("legs") != basis.legs or dependency.data.get("covenant") != basis.covenant or covenant.data.get("parties") != basis.parties or not strings(covenant.data.get("record_roots"), count): return _deny("actual_reciprocal_covenant_missing")
			var roots: Array = []; var turns: Dictionary = {}
			for position: int in count:
				var leg: Dictionary = _material(materials, basis.legs[position], ["reciprocal_leg"])
				var office: String = institution if position == 0 else str(basis.other_institution)
				var recipient: String = basis.parties[position]
				var record: Dictionary = _material(materials, leg.get("data", {}).get("record", ""), ["evidence", "dream"])
				if leg.is_empty() or leg.data.get("term") != "deliver_record" or leg.data.get("index") != position or leg.data.get("covenant") != basis.covenant or leg.data.get("recipient") != recipient or record.is_empty() or record.root != covenant.data.record_roots[position] or record.root in roots or turns.has(leg.turn) or not held(state, record, recipient, office, reader) or not held(state, dependency, recipient, office, reader): return _deny("reciprocal_leg_not_actual_distinct_delivery")
				personal_sources.append({"institution": office, "person": recipient, "source": dependency.id})
				roots.append(record.root); turns[leg.turn] = true; current.append(leg.id); current.append(record.id); forced[record.id] = {"institution": office, "person": recipient}; forced[leg.id] = {"institution": office, "person": recipient}
			current.append(basis.dependency); original = basis.parties.duplicate()
		_: return _deny("unsupported_route_selector")
	if not route_error.is_empty(): return _deny(route_error)
	if purpose == "spread" and row.profile == "CIV_04" and not actor.is_empty():
		var keeper: String = str(basis.get("priest", basis.get("practitioner", "")))
		if actor != keeper:
			var contact: Dictionary = reader.contact_context(actor, keeper) if reader != null and reader.has_method("contact_context") else {}
			if contact.is_empty(): return _deny("executing_person_has_no_current_ritual_contact")
	var carriers: Array = _cover(state, materials, current, institution, forced, reader)
	if carriers.is_empty(): return _deny("current_actual_material_carrier_missing", current)
	for personal: Dictionary in personal_sources:
		for carrier: Dictionary in carriers:
			if carrier.institution == personal.institution and carrier.person == personal.person and not personal.source in carrier.sources: carrier.sources.append(personal.source); carrier.sources.sort()
	var canonical: Dictionary = basis.duplicate(true); canonical["carriers"] = carriers
	return {"ok": true, "allowed": true, "reason": "", "missing": [], "institution": institution, "route": route, "profile": row.profile, "rule": row.rule, "basis": canonical, "dependencies": _references(canonical, materials), "originals": original}
