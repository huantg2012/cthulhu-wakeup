extends RefCounted
## One finite graph algorithm and its source-backed World integration contract.
## This module has no RNG stream and never creates people or implicit knowledge.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Initialization = preload("res://src/simulation/world_initialization.gd")
const SCHEMA: int = 1
const STATE_SCHEMA: int = 2
const PARAM_UNITS: Dictionary = {
	"model_version": "version", "initial_edge_numerator": "edge_budget_numerator", "initial_edge_denominator": "edge_budget_denominator",
	"initial_degree_base": "neighbor", "initial_degree_influence_divisor": "influence_per_neighbor", "initial_degree_max": "neighbor",
	"contact_weight_base": "weight", "same_institution_bonus": "weight", "shared_role_bonus": "weight", "shared_need_bonus": "weight_per_shared_need",
	"shared_need_count_cap": "need", "common_neighbor_bonus": "weight_per_neighbor", "common_neighbor_count_cap": "neighbor", "institution_bridge_bonus": "weight",
	"initial_coverage_degree": "neighbor", "validation_seed_first": "seed", "validation_seed_count": "seed",
	"validation_heterogeneous_min_percent": "percent", "validation_triangle_min_percent": "percent", "validation_cross_institution_min_percent": "percent",
	"validation_branch_min_percent": "percent", "validation_type_occurrences_min": "edge_per_type"}
const TYPE_GRAMMAR: Dictionary = {
	"family": ["mutual", "cohort_contact", "same_pair_type_idempotent", "initial_ends_relation_only"],
	"support": ["directed", "cohort_contact", "same_ordered_pair_type_idempotent", "initial_ends_relation_only"],
	"cooperation": ["mutual", "cohort_shared_role_or_need", "same_pair_type_idempotent", "initial_ends_relation_only"],
	"rival": ["mutual", "cohort_competing_need", "same_pair_type_idempotent", "initial_ends_relation_only"],
	"hostile": ["directed", "actual_result_only", "same_ordered_pair_type_idempotent", "producer_recipients_only"],
	"favor_owed": ["directed", "actual_cooperation_result_only", "same_ordered_pair_type_idempotent", "producer_recipients_only"]}

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _keys(data: Dictionary, required: Array) -> bool:
	if data.size() != required.size(): return false
	for key: Variant in required:
		if not data.has(key): return false
	return true

static func canonical_seed(seed: String) -> bool:
	if not seed.is_valid_int(): return false
	return str(int(seed)) == seed

static func validate_catalog(tables: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var parameters: Dictionary = tables.get("social_graph_parameters", {})
	var types: Dictionary = tables.get("social_relation_types", {})
	if parameters.size() != PARAM_UNITS.size() or types.size() != TYPE_GRAMMAR.size(): return ["Incomplete social graph tables"]
	var positive: Array = ["model_version", "initial_edge_denominator", "initial_degree_influence_divisor", "contact_weight_base", "validation_seed_count"]
	for key: String in parameters:
		var row: Dictionary = parameters[key]
		if not PARAM_UNITS.has(key) or not str(row.get("value", "")).is_valid_int() or int(row.value) < 0 or row.get("unit") != PARAM_UNITS.get(key) or str(row.get("rationale", "")).is_empty():
			errors.append("Invalid social graph parameter: " + key); continue
		if key in positive and int(row.value) <= 0: errors.append("Social graph divisor/version/count must be positive: " + key)
		if row.unit == "percent" and int(row.value) > 100: errors.append("Social graph percentage exceeds 100: " + key)
	var known_needs: Array = []
	for row: Dictionary in tables.get("npc_profiles", {}).values():
		for need: String in str(row.get("need_tags", "")).split(";"):
			if not need.is_empty() and not need in known_needs: known_needs.append(need)
	for key: String in types:
		var row: Dictionary = types[key]
		if not TYPE_GRAMMAR.has(key): errors.append("Unknown social relation type: " + key); continue
		var grammar: Array = TYPE_GRAMMAR[key]
		if row.get("direction") != grammar[0] or row.get("initial_rule") != grammar[1] or row.get("duplicate_policy") != grammar[2] or row.get("knowledge_rule") != grammar[3] or row.get("retirement_rule") != "explicit_source_only": errors.append("Unsupported social relation grammar: " + key)
		if not str(row.get("initial_weight", "")).is_valid_int() or int(row.initial_weight) < 0: errors.append("Invalid social type weight: " + key)
		elif key in ["hostile", "favor_owed"] and int(row.initial_weight) != 0: errors.append("Result-only relation cannot have initial weight: " + key)
		var needs: Array = [] if str(row.get("initial_need_tags", "")).is_empty() else Array(str(row.initial_need_tags).split("|"))
		var seen: Dictionary = {}
		for need: Variant in needs:
			if not need is String or not need in known_needs or seen.has(need): errors.append("Invalid initial competing need: " + key)
			seen[need] = true
		if (key == "rival") != (not needs.is_empty()): errors.append("Social initial need tags disagree with rule: " + key)
		var coexist: Array = Array(str(row.get("coexists_with", "")).split("|"))
		if coexist.size() != TYPE_GRAMMAR.size(): errors.append("Incomplete social coexistence grammar: " + key)
		seen = {}
		for other: Variant in coexist:
			if not other is String or not TYPE_GRAMMAR.has(other) or seen.has(other): errors.append("Invalid social coexistence type: " + key)
			elif not key in str(types.get(other, {}).get("coexists_with", "")).split("|"): errors.append("Asymmetric social coexistence: " + key)
			seen[other] = true
	if types.has("family") and types.has("support") and int(types.family.get("initial_weight", 0)) + int(types.support.get("initial_weight", 0)) <= 0: errors.append("Legal contact requires a positive family or support initial weight")
	return errors

static func data_versions(catalog: RefCounted) -> Dictionary:
	return {"social_graph_parameters": catalog.extension_versions.get("social_graph_parameters", ""), "social_relation_types": catalog.extension_versions.get("social_relation_types", ""), "npc_profiles": catalog.extension_versions.get("npc_profiles", "")}

static func initialize(catalog: RefCounted, seed: String) -> Dictionary:
	if not canonical_seed(seed): return {}
	return {"schema": STATE_SCHEMA, "model_version": catalog.integer("model_version"), "data_versions": data_versions(catalog), "cohorts": {}, "edge_heads": History.from_value({}, "map")}

static func edge_key(a: String, b: String, kind: String, direction: String) -> String:
	if direction == "mutual" and a > b:
		var swap: String = a; a = b; b = swap
	return JSON.stringify([a, b, kind, direction], "", false)

static func _common(a: Variant, b: Variant) -> Array:
	var result: Array = []
	for item: Variant in a:
		if item in b and not item in result: result.append(item)
	return result

static func _context(a: Dictionary, b: Dictionary, offices: Dictionary, domain: String) -> Dictionary:
	var first: String = str(a.get("institution", "")); var second: String = str(b.get("institution", ""))
	var left: Dictionary = offices.get(first, {}); var right: Dictionary = offices.get(second, {})
	if left.is_empty() or right.is_empty() or left.get("active") != true or right.get("active") != true or left.get("domain") != domain or right.get("domain") != domain: return {}
	if first != second and (not second in left.get("links", []) or not first in right.get("links", [])): return {}
	var sources: Array = [str(left.get("source", ""))]
	if not str(right.get("source", "")) in sources: sources.append(str(right.get("source", "")))
	if "" in sources: return {}
	sources.sort()
	return {"kind": "same_institution" if first == second else "institution_link", "institutions": [first, second], "channel_sources": sources}

static func contact_context(state: Dictionary, a: String, b: String) -> Dictionary:
	if a == b or not Store.has(state.get("npcs", {}), a) or not Store.has(state.get("npcs", {}), b): return {}
	var first: Dictionary = Store.entry(state.npcs, a); var second: Dictionary = Store.entry(state.npcs, b)
	if first.get("status") != "active" or second.get("status") != "active" or first.get("domain") != second.get("domain"): return {}
	return _context(first, second, state.institutions, first.domain)

static func _draw(catalog: RefCounted, seed: String, domain: String, phase: String, cohort: String, kind: String, index: int, total: int) -> int:
	var encoded: String = JSON.stringify([catalog.integer("model_version"), seed, domain, phase, cohort, kind, index], "", false)
	return int(encoded.sha256_text().substr(0, 8).hex_to_int() % total)

static func _choose(rows: Array, draw: int) -> Dictionary:
	for row: Dictionary in rows:
		if draw < int(row.weight): return row
		draw -= int(row.weight)
	return {}

static func plan(catalog: RefCounted, seed: String, domain: String, phase: String, cohort: String, input_snapshot: Dictionary) -> Dictionary:
	if not canonical_seed(seed) or domain.is_empty() or not phase in ["world_start", "first_focus"] or cohort != domain + "/" + phase or not _keys(input_snapshot, ["members", "institutions", "expanded_at_creation"]) or not input_snapshot.members is Dictionary or not input_snapshot.institutions is Dictionary or not input_snapshot.expanded_at_creation is bool: return _failure("Invalid social cohort input")
	if (phase == "first_focus" and not input_snapshot.expanded_at_creation) or (not input_snapshot.expanded_at_creation and not input_snapshot.members.is_empty()): return _failure("Cohort expansion marker disagrees with its actual input")
	var members: Dictionary = input_snapshot.members; var offices: Dictionary = input_snapshot.institutions
	for office_id: Variant in offices:
		var office: Variant = offices[office_id]
		if not office_id is String or not office is Dictionary or not _keys(office, ["active", "domain", "links", "source"]) or not office.active is bool or office.domain != domain or not office.links is Array or not office.source is String or office.source.is_empty(): return _failure("Invalid social institution snapshot")
		for link: Variant in office.links:
			if not link is String or not offices.has(link) or link == office_id: return _failure("Invalid social institution channel")
	var ids: Array = members.keys(); ids.sort()
	var degrees: Dictionary = {}; var limits: Dictionary = {}; var neighbors: Dictionary = {}
	for id: Variant in ids:
		if not id is String or id.is_empty() or not members[id] is Dictionary: return _failure("Invalid social cohort member")
		var person: Dictionary = members[id]
		if not _keys(person, ["profile", "influence", "role_tags", "need_tags", "institution", "identity_source"]) or not catalog.tables.npc_profiles.has(person.get("profile", "")) or not person.get("influence") is int or person.influence < 0 or not person.get("role_tags") is Array or not person.get("need_tags") is Array or not person.get("institution") is String or str(person.get("identity_source", "")).is_empty(): return _failure("Invalid social member snapshot")
		degrees[id] = 0; neighbors[id] = []
		limits[id] = mini(ids.size() - 1, mini(catalog.integer("initial_degree_max"), catalog.integer("initial_degree_base") + int(floor(float(person.influence) / float(catalog.integer("initial_degree_influence_divisor"))))))
	var budget: int = mini(int(ids.size() * (ids.size() - 1) / 2), int(floor(float(ids.size() * catalog.integer("initial_edge_numerator")) / float(catalog.integer("initial_edge_denominator")))))
	var result: Array = []; var bridges: Dictionary = {}
	while result.size() < budget:
		var candidates: Array = []; var coverage: Array = []
		for left: int in ids.size():
			for right: int in range(left + 1, ids.size()):
				var a: String = ids[left]; var b: String = ids[right]
				if degrees[a] >= limits[a] or degrees[b] >= limits[b] or b in neighbors[a]: continue
				var context: Dictionary = _context(members[a], members[b], offices, domain)
				if context.is_empty(): continue
				var shared_roles: Array = _common(members[a].role_tags, members[b].role_tags)
				var shared_needs: Array = _common(members[a].need_tags, members[b].need_tags)
				var common: Array = _common(neighbors[a], neighbors[b])
				var pair: Array = [members[a].institution, members[b].institution]; pair.sort()
				var bridge: String = JSON.stringify(pair, "", false)
				var weight: int = catalog.integer("contact_weight_base")
				if pair[0] == pair[1]: weight += catalog.integer("same_institution_bonus")
				elif not bridges.has(bridge): weight += catalog.integer("institution_bridge_bonus")
				if not shared_roles.is_empty(): weight += catalog.integer("shared_role_bonus")
				weight += mini(shared_needs.size(), catalog.integer("shared_need_count_cap")) * catalog.integer("shared_need_bonus")
				weight += mini(common.size(), catalog.integer("common_neighbor_count_cap")) * catalog.integer("common_neighbor_bonus")
				var row: Dictionary = {"a": a, "b": b, "weight": weight, "context": context, "bridge": bridge, "shared_roles": shared_roles, "shared_needs": shared_needs}
				candidates.append(row)
				if degrees[a] < catalog.integer("initial_coverage_degree") or degrees[b] < catalog.integer("initial_coverage_degree"): coverage.append(row)
		if candidates.is_empty(): break
		if not coverage.is_empty(): candidates = coverage
		var total: int = 0
		for row: Dictionary in candidates: total += int(row.weight)
		var selected: Dictionary = _choose(candidates, _draw(catalog, seed, domain, phase, cohort, "edge", result.size(), total))
		var choices: Array = []; var type_ids: Array = catalog.tables.social_relation_types.keys(); type_ids.sort(); total = 0
		for kind: String in type_ids:
			var row: Dictionary = catalog.tables.social_relation_types[kind]
			var weight: int = int(row.initial_weight)
			if weight <= 0: continue
			if row.initial_rule == "cohort_shared_role_or_need" and selected.shared_roles.is_empty() and selected.shared_needs.is_empty(): continue
			if row.initial_rule == "cohort_competing_need" and _common(selected.shared_needs, Array(str(row.initial_need_tags).split("|"))).is_empty(): continue
			if not row.initial_rule in ["cohort_contact", "cohort_shared_role_or_need", "cohort_competing_need"]: continue
			choices.append({"kind": kind, "weight": weight}); total += weight
		if total <= 0: return _failure("Legal social contact has no initial type")
		var selected_type: Dictionary = _choose(choices, _draw(catalog, seed, domain, phase, cohort, "type", result.size(), total))
		var a: String = selected.a; var b: String = selected.b; var direction: String = catalog.tables.social_relation_types[selected_type.kind].direction
		if direction == "directed" and _draw(catalog, seed, domain, phase, cohort, "direction", result.size(), 2) == 1:
			var swap: String = a; a = b; b = swap
		result.append({"a": a, "b": b, "kind": selected_type.kind, "direction": direction, "contact_a": selected.a, "contact_b": selected.b, "context": selected.context})
		degrees[selected.a] += 1; degrees[selected.b] += 1
		neighbors[selected.a].append(selected.b); neighbors[selected.b].append(selected.a); bridges[selected.bridge] = true
	return {"ok": true, "edges": result, "empty_reason": ("insufficient_members" if ids.size() < 2 else "no_legal_pairs_or_budget") if result.is_empty() else "", "budget": budget, "degrees": degrees}

static func relation_data(fact: Dictionary, catalog: RefCounted) -> Dictionary:
	if not fact.get("kind") in ["initial_relationship", "relationship"] or not fact.get("changes") is Dictionary: return {}
	var data: Dictionary = fact.changes
	var kind: String = str(data.get("kind", ""))
	if not catalog.tables.social_relation_types.has(kind) or not data.get("a") is String or not data.get("b") is String or data.a.is_empty() or data.a == data.b or data.get("schema") != SCHEMA: return {}
	var direction: String = catalog.tables.social_relation_types[kind].direction
	if data.get("direction") != direction or (direction == "mutual" and data.a > data.b) or fact.get("actor") != data.a or fact.get("targets") != [data.b]: return {}
	var fields: Array = ["schema", "kind", "a", "b", "direction"]
	if fact.kind == "initial_relationship": fields.append_array(["cohort", "contact"])
	if not _keys(data, fields): return {}
	return {"source": fact.id, "kind": kind, "a": data.a, "b": data.b, "direction": direction}

static func _fact(state: Dictionary, source: String) -> Dictionary:
	var value: Variant = Store.entry(state.get("facts", {}), source, {})
	if not value is Dictionary or value.get("id") != source or not value.get("kind") is String or not value.get("changes") is Dictionary or not value.get("causal_parents") is Array or not value.get("targets") is Array or not value.get("actor") is String or not value.get("domain") is String or not value.get("turn") is int: return {}
	return value

static func _object(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _prayer_effect(state: Dictionary, receipt: Dictionary, prayer: String, tag: String, completed: bool) -> Dictionary:
	var data: Dictionary = _object(receipt.get("changes"))
	if receipt.get("kind") != "prayer_fact" or data.get("prayer") != prayer or data.get("tag") != tag or not data.get("request") is String or not data.get("facts") is Dictionary or not data.get("subjects") is Dictionary or not receipt.get("causal_parents") is Array: return {}
	var checks: Array = []
	for source: Variant in receipt.causal_parents:
		if not source is String: return {}
		var candidate: Dictionary = _fact(state, source)
		if candidate.get("kind") == "turn_check": checks.append(candidate)
	if checks.size() != 1: return {}
	var checked: Dictionary = checks[0]
	var check_data: Dictionary = _object(checked.get("changes"))
	if not check_data.get("outcome") in ["success", "deep"] or checked.get("domain") != receipt.get("domain") or checked.get("turn") != receipt.get("turn") or not checked.get("causal_parents") is Array or checked.causal_parents.size() != 1 or str(checked.get("id", "")) >= str(receipt.get("id", "")): return {}
	var attempt: Dictionary = _fact(state, str(checked.causal_parents[0]))
	var attempted: Dictionary = _object(attempt.get("changes"))
	var descriptor: Dictionary = _object(attempted.get("descriptor"))
	if attempt.get("kind") != "prayer_attempt" or attempt.get("domain") != receipt.domain or attempt.get("turn") != receipt.turn or attempt.get("actor") != checked.get("actor") or attempt.get("actor") != receipt.get("actor") or str(attempt.get("id", "")) >= str(checked.id) or attempted.get("request") != data.request or attempted.get("variant") != data.get("variant") or descriptor.get("content_id") != prayer or descriptor.get("domain") != receipt.domain or descriptor.get("institution") != data.get("institution") or descriptor.get("subjects") != data.subjects or descriptor.get("facts") != data.facts or not descriptor.get("source") in receipt.causal_parents: return {}
	var registered: bool = false
	if not attempt.get("causal_parents") is Array: return {}
	for source: Variant in attempt.causal_parents:
		var original: Dictionary = _fact(state, str(source))
		var original_data: Dictionary = _object(original.get("changes"))
		if original.get("kind") == "prayer_registered" and original_data.get("request") == data.request and original_data.get("descriptor") == descriptor: registered = true
	if not registered: return {}
	if completed:
		var result: Dictionary = _fact(state, str(Store.entry(state.get("applied_authorizations", {}), "prayer/response/" + data.request, "")))
		var result_data: Dictionary = _object(result.get("changes"))
		if result.get("kind") != "prayer_result" or result.get("domain") != receipt.domain or result.get("turn") != receipt.turn or result.get("actor") != attempt.actor or result_data.get("request") != data.request or result_data.get("prayer") != prayer or result_data.get("variant") != data.get("variant") or result_data.get("outcome") != check_data.outcome or result_data.get("roll") != check_data.get("roll") or _object(result_data.get("produced")).get(tag) != receipt.id or result.get("causal_parents") != [attempt.id, checked.id] or str(result.get("id", "")) <= str(receipt.id): return {}
	return {"attempt": attempt, "check": checked, "descriptor": descriptor}

static func establishment_proof(state: Dictionary, a: String, b: String, kind: String, parents: Array, catalog: RefCounted, completed: bool = false) -> String:
	var found: String = ""
	for source: Variant in parents:
		if not source is String: return ""
		var fact: Dictionary = _fact(state, source)
		var data: Dictionary = _object(fact.get("changes"))
		var matches: bool = false
		if kind == "cooperation" and fact.get("kind") == "route_attempt" and data.get("operation") == "ROUTE_JOINT_WORK" and data.get("outcome") in ["success", "deep"] and fact.get("targets") == [a, b] and data.get("issuer") == "progression_routes" and data.get("version") == state.get("progression_routes", {}).get("version"):
			var paid: Dictionary = _fact(state, str(data.get("payment", "")))
			matches = paid.get("kind") == "turn_action" and paid.get("turn") == fact.get("turn") and paid.get("actor") == fact.get("actor") and paid.id in fact.get("causal_parents", []) and paid.changes.get("outcome") == "progression/ROUTE_JOINT_WORK" and paid.changes.get("faith_cost") == catalog.integer("joint_work_faith") and paid.changes.get("whispers_cost") == catalog.integer("joint_work_whispers") and _object(data.get("payload")).get("npc") == fact.actor and _object(data.get("payload")).get("other") in [a, b] and fact.actor in [a, b] and data.payload.other != fact.actor
		elif kind == "hostile" and fact.get("kind") == "prayer_fact" and data.get("variant") == "shallow" and fact.get("targets") == [a] and _object(data.get("subjects")).get("petitioner") == b and _object(data.get("subjects")).get("opponent") == a:
			matches = not _prayer_effect(state, fact, "PRAYER_10", "hostility", completed).is_empty()
		elif fact.get("kind") == "event_result" and data.get("descriptor") is Dictionary and data.get("option") == "A" and data.get("operations") is Array and Store.entry(state.get("applied_authorizations", {}), "event/resolved/" + str(data.get("event", "")), "") == source:
			var subjects: Dictionary = _object(data.descriptor.get("subjects"))
			for row: Dictionary in catalog.tables.event_operations.values():
				if row.event_id != data.get("content_id") or row.option != "A" or not row.id in data.operations: continue
				if data.content_id == "EVENT_03" and kind == "favor_owed" and row.operation == "record" and row.field == "favor_owed" and subjects.get("former") == a and subjects.get("cooperator") == b: matches = true
				if data.content_id == "EVENT_09" and kind == "hostile" and row.operation == "relation" and row.subject == "opponent" and subjects.get("cooperator") == a and subjects.get("opponent") == b: matches = true
		if matches:
			if not found.is_empty() and found != source: return ""
			found = source
	return found

static func authorized_result(state: Dictionary, a: String, b: String, kind: String, parents: Array, catalog: RefCounted) -> bool:
	return not establishment_proof(state, a, b, kind, parents, catalog).is_empty()

static func retirement_valid(state: Dictionary, head: String, source: String, catalog: RefCounted, completed: bool = false) -> bool:
	var relation: Dictionary = relation_data(_fact(state, head), catalog)
	var receipt: Dictionary = _fact(state, source)
	var data: Dictionary = _object(receipt.get("changes"))
	if relation.is_empty() or data.get("variant") != "deep" or data.get("original") != head or not data.get("facts") is Dictionary or not data.facts.get("pursuit") is String: return false
	var effect: Dictionary = _prayer_effect(state, receipt, "PRAYER_03", "pursuit_relation_withdrawn", completed)
	if effect.is_empty(): return false
	var pursuit: Dictionary = _fact(state, data.facts.pursuit)
	var original: Dictionary = _object(pursuit.get("changes"))
	var petitioner: String = str(_object(data.get("subjects")).get("petitioner", ""))
	var pursuer: String = str(_object(data.get("subjects")).get("pursuer", ""))
	return pursuit.get("kind") == "pursuit_condition" and original.get("relation") == head and original.get("subject") == petitioner and original.get("pursuer") == pursuer and original.get("institution") == data.get("institution") and [relation.a, relation.b].has(petitioner) and [relation.a, relation.b].has(pursuer) and petitioner != pursuer and pursuit.get("domain") == receipt.get("domain") and _fact(state, head).get("domain") == receipt.get("domain") and pursuit.id in receipt.get("causal_parents", []) and head < str(pursuit.id) and str(pursuit.id) < str(effect.attempt.id)

static func _relation_changes_valid(state: Dictionary, catalog: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	var incremental: bool = not trusted.is_empty()
	if incremental:
		for field: String in ["applied_authorizations", "invalid_records"]:
			var after: Dictionary = state[field]; var before: Dictionary = trusted[field]
			if is_same(after, before): continue
			if not Store.overlay(after) or not is_same(after.base, before): return ["Untrusted relation provenance root replacement: " + field]
			# Only graph provenance is protected here. Unrelated systems may
			# replace their own current-head values or remove their own entries.
			for key: String in after.removed:
				if (field == "applied_authorizations" and key.begins_with("social/relation/proof/")) or (field == "invalid_records" and not relation_data(_fact(trusted, key), catalog).is_empty()): return ["Committed relation provenance cannot disappear"]
	var sources: Array = []
	for sequence: int in range(int(trusted.next_fact) if incremental else 1, int(state.next_fact)): sources.append("FACT-%08d" % sequence)
	for source: String in sources:
		var fact: Dictionary = _fact(state, source)
		var effect: Dictionary = _object(fact.get("changes"))
		var intent: Dictionary = {}
		if fact.get("kind") == "route_attempt" and effect.get("operation") == "ROUTE_JOINT_WORK" and effect.get("outcome") in ["success", "deep"]:
			intent = {"a": fact.targets[0] if fact.targets.size() == 2 else "", "b": fact.targets[1] if fact.targets.size() == 2 else "", "kind": "cooperation"}
		elif fact.get("kind") == "prayer_fact" and effect.get("prayer") == "PRAYER_10" and effect.get("tag") == "hostility":
			intent = {"a": fact.targets[0] if fact.targets.size() == 1 else "", "b": _object(effect.get("subjects")).get("petitioner", ""), "kind": "hostile"}
		elif fact.get("kind") == "event_result" and effect.get("option") == "A" and effect.get("content_id") in ["EVENT_03", "EVENT_09"]:
			var subjects: Dictionary = _object(_object(effect.get("descriptor")).get("subjects"))
			intent = {"a": subjects.get("former" if effect.content_id == "EVENT_03" else "cooperator", ""), "b": subjects.get("cooperator" if effect.content_id == "EVENT_03" else "opponent", ""), "kind": "favor_owed" if effect.content_id == "EVENT_03" else "hostile"}
		if not intent.is_empty():
			if not intent.a is String or not intent.b is String or establishment_proof(state, intent.a, intent.b, intent.kind, [source], catalog, true) != source: return ["Actual relationship effect lacks its completed business authority"]
			var bound: Dictionary = relation_data(_fact(state, str(Store.entry(state.applied_authorizations, "social/relation/proof/" + source, ""))), catalog)
			if bound.is_empty() or bound.a != intent.a or bound.b != intent.b or bound.kind != intent.kind: return ["Actual relationship effect lost its once-bound episode"]
		if fact.get("kind") == "relationship":
			var data: Dictionary = relation_data(fact, catalog)
			if data.is_empty(): return ["Invalid actual relationship episode"]
			var proof: String = establishment_proof(state, data.a, data.b, data.kind, fact.causal_parents, catalog, true)
			if proof.is_empty() or Store.entry(state.applied_authorizations, "social/relation/proof/" + proof, "") != source: return ["Relationship episode lacks its unique completed business proof"]
		elif fact.get("kind") == "prayer_fact" and fact.get("changes", {}).get("tag") == "pursuit_relation_withdrawn":
			var head: String = str(fact.changes.get("original", ""))
			if Store.entry(state.invalid_records, head, "") != source or not retirement_valid(state, head, source, catalog, true): return ["Pursuit relation withdrawal lacks its completed exact retirement"]
	var invalidated: Array = Store.changed(state.invalid_records) if incremental else Store.keys(state.invalid_records)
	for head: String in invalidated:
		if relation_data(_fact(state, head), catalog).is_empty(): continue
		var receipt: Variant = Store.entry(state.invalid_records, head)
		if not receipt is String or not retirement_valid(state, head, receipt, catalog, true): return ["Relation invalidated without its exact PR03 withdrawal receipt"]
		if incremental and Store.has(trusted.invalid_records, head) and Store.entry(trusted.invalid_records, head) != receipt: return ["Relation retirement receipt was replaced"]
	var bindings: Array = Store.changed(state.applied_authorizations) if incremental else Store.keys(state.applied_authorizations)
	for key: String in bindings:
		if not key.begins_with("social/relation/proof/"): continue
		var proof: String = key.trim_prefix("social/relation/proof/")
		var source: Variant = Store.entry(state.applied_authorizations, key)
		if not source is String: return ["Invalid relationship proof binding"]
		var episode: Dictionary = _fact(state, source)
		var data: Dictionary = relation_data(episode, catalog)
		if data.is_empty() or establishment_proof(state, data.a, data.b, data.kind, [proof], catalog, true) != proof: return ["Relationship proof does not authorize its bound episode"]
		if source > proof and not proof in episode.get("causal_parents", []): return ["Old relationship proof was rebound to a future episode"]
		var retired: String = str(Store.entry(state.invalid_records, source, ""))
		if not retired.is_empty() and retired < proof: return ["New relationship proof was bound to an already retired episode"]
		if incremental:
			if Store.has(trusted.applied_authorizations, key):
				if Store.entry(trusted.applied_authorizations, key) != source: return ["Consumed relationship proof was rebound"]
			elif _fact_number(proof) < int(trusted.next_fact): return ["Historical relationship proof was consumed later"]
	return []

static func _fact_number(source: String) -> int:
	return int(source.trim_prefix("FACT-")) if source.begins_with("FACT-") and source.trim_prefix("FACT-").is_valid_int() else -1

static func _projection_key(row: Dictionary) -> String:
	return JSON.stringify([row.target, row.kind, row.source], "", false)

static func _projection_valid(state: Dictionary, catalog: RefCounted, person: String, row: Variant, first_new_fact: int = 0) -> bool:
	if not row is Dictionary or not _keys(row, ["target", "kind", "source"]) or not row.target is String or not row.kind is String or not row.source is String: return false
	var data: Dictionary = relation_data(_fact(state, row.source), catalog)
	if data.is_empty() or data.kind != row.kind or (first_new_fact > 0 and _fact_number(row.source) < first_new_fact): return false
	return (data.a == person and data.b == row.target) or (data.direction == "mutual" and data.b == person and data.a == row.target)

static func validate_projections(state: Dictionary, catalog: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not trusted.is_empty():
		if not is_same(state.npcs, trusted.npcs) and (not Store.packed(trusted.npcs) or not Store.overlay(state.npcs) or not is_same(state.npcs.base, trusted.npcs)): return ["Incremental projection audit requires the actual managed write set"]
		var required: Dictionary = {}
		for number: int in range(int(trusted.next_fact), int(state.next_fact)):
			var data: Dictionary = relation_data(_fact(state, "FACT-%08d" % number), catalog)
			if data.is_empty(): continue
			for pair: Array in [[data.a, data.b], [data.b, data.a]]:
				if data.direction == "directed" and pair[0] != data.a: continue
				if not required.has(pair[0]): required[pair[0]] = {}
				required[pair[0]][_projection_key({"target": pair[1], "kind": data.kind, "source": data.source})] = true
		var changed: Array = Store.changed(state.npcs)
		for id: String in changed:
			var current: Dictionary = Store.entry(state.npcs, id, {}); var prior: Dictionary = Store.entry(trusted.npcs, id, {})
			var after: Variant = current.get("relations", []); var before: Variant = prior.get("relations", [])
			if not History.valid_shape(after, "sequence"): return ["Malformed relation history sequence"]
			var added: int = 0
			var seen: Dictionary = {}
			var delta: Array = History.changed_entries(after, before)
			delta.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.key) < str(right.key))
			for row: Dictionary in delta:
				if History.has(before, row.key): return ["Committed relationship projection was replaced"]
				if row.key != "%012d" % (History.size(before) + added) or not _projection_valid(state, catalog, id, row.value, int(trusted.next_fact)): return ["Extra, reversed or unsourced new relationship projection"]
				var key: String = _projection_key(row.value)
				if seen.has(key): return ["Duplicate new relationship projection"]
				if not required.get(id, {}).has(key): return ["Projection has no corresponding newly published relationship"]
				seen[key] = true
				added += 1
			if History.size(after) != History.size(before) + added: return ["Committed relationship projection disappeared"]
			if seen.size() != required.get(id, {}).size(): return ["New relationship endpoint projection is incomplete"]
			required.erase(id)
		if not required.is_empty(): return ["New relationship endpoint projection was never written"]
		return []
	var expected: Dictionary = {}
	for number: int in range(1, int(state.next_fact)):
		var data: Dictionary = relation_data(_fact(state, "FACT-%08d" % number), catalog)
		if data.is_empty(): continue
		for pair: Array in [[data.a, data.b], [data.b, data.a]]:
			if data.direction == "directed" and pair[0] != data.a: continue
			if not expected.has(pair[0]): expected[pair[0]] = {}
			expected[pair[0]][_projection_key({"target": pair[1], "kind": data.kind, "source": data.source})] = true
	for id: String in Store.keys(state.npcs):
		var raw: Variant = Store.entry(state.npcs, id)
		if not raw is Dictionary or not History.valid_shape(raw.get("relations"), "sequence"): return ["Malformed endpoint relationship history"]
		var seen: Dictionary = {}
		for row: Variant in History.values(raw.relations):
			if not _projection_valid(state, catalog, id, row): return ["Extra, reversed or unsourced endpoint relationship history"]
			var key: String = _projection_key(row)
			if seen.has(key) or not expected.get(id, {}).has(key): return ["Duplicate or extraneous endpoint relationship history"]
			seen[key] = true
		if seen.size() != expected.get(id, {}).size(): return ["Endpoint relationship history is incomplete"]
	return []

static func _position_valid(value: Variant, fact: Dictionary) -> bool:
	if not value is Dictionary or not _keys(value, ["scope", "sequence", "fact_before", "entry_phase", "entry_turn"]) or not value.scope in ["standalone", "bootstrap", "turn"] or not value.sequence is int or not value.fact_before is int or not value.entry_turn is int or not value.entry_phase is String: return false
	if value.scope == "standalone": return value.sequence == 0 and value.fact_before == 0 and value.entry_phase == "" and value.entry_turn == fact.turn
	if value.scope == "bootstrap": return value.sequence == 0 and value.fact_before > 0 and value.fact_before <= _fact_number(fact.id) and value.entry_phase == "between" and value.entry_turn == 0 and fact.turn == 0
	return value.sequence > 0 and value.fact_before > 0 and value.fact_before <= _fact_number(fact.id) and value.entry_phase in ["between", "events", "actions", "evolution", "settlement", "ending"] and value.entry_turn >= 0 and fact.turn >= value.entry_turn and fact.turn <= value.entry_turn + (1 if value.entry_phase == "between" else 0)

static func _bootstrap_birth_valid(state: Dictionary, catalog: RefCounted, nomination: Dictionary, birth: Dictionary) -> bool:
	var initial_domains: Array = []
	for key: String in state.social_graph.cohorts:
		var cohort: Dictionary = state.social_graph.cohorts[key]
		if cohort.phase != "world_start": continue
		var generation: Dictionary = _fact(state, cohort.generation_source)
		if generation.get("changes", {}).get("input_snapshot", {}).get("expanded_at_creation") == true: initial_domains.append(cohort.domain)
	initial_domains.sort()
	if initial_domains.is_empty() or nomination.domain != initial_domains[0] or nomination.changes.get("from_group") != "unnamed_nonfollowers": return false
	var bootstrap: Dictionary = _fact(state, str(Store.entry(state.applied_authorizations, "prayer/bootstrap", "")))
	if bootstrap.get("kind") != "prayer_bootstrap" or bootstrap.actor != nomination.actor or bootstrap.turn != 0 or bootstrap.id <= nomination.id: return false
	var situation: Dictionary = _fact(state, str(bootstrap.changes.get("source", "")))
	var facts: Dictionary = _object(situation.get("changes", {}).get("facts"))
	var contact: Dictionary = _fact(state, str(facts.get("contact", "")))
	var call: Dictionary = _fact(state, str(situation.get("changes", {}).get("call", "")))
	if situation.get("kind") != "prayer_situation" or situation.actor != nomination.actor or situation.domain != nomination.domain or situation.turn != 0 or situation.changes.get("need") != catalog.tables.prayers.PRAYER_08.need or situation.changes.get("institution") != birth.institution or not situation.id in bootstrap.causal_parents or contact.get("kind") != "devotion_contact" or contact.actor != nomination.actor or contact.domain != nomination.domain or contact.changes.get("institution") != birth.institution or not contact.id in situation.causal_parents or not nomination.id in contact.causal_parents or call.get("kind") != "prayer_call" or not call.id in situation.causal_parents or call.changes.get("petitioner") != nomination.actor or call.changes.get("addressing") != "undirected": return false
	if call.changes.get("source") != contact.id or not contact.id in call.causal_parents or call.changes.get("need") != catalog.tables.prayers.PRAYER_08.need: return false
	var selected: Dictionary = {}
	for source: String in contact.causal_parents:
		var parent: Dictionary = _fact(state, source)
		if parent.get("kind") == "prayer_contact_selected":
			if not selected.is_empty(): return false
			selected = parent
	if selected.is_empty() or selected.actor != nomination.actor or selected.domain != nomination.domain or selected.turn != 0 or not nomination.id in selected.causal_parents or not _keys(_object(selected.changes.get("position")), ["commit_seq", "fact_before"]) or selected.changes.position.commit_seq != 1 or selected.changes.position.fact_before != birth.position.fact_before: return false
	var proposal: Dictionary = _object(selected.changes.get("proposal")); var sample: Dictionary = _object(selected.changes.get("snapshot"))
	if proposal.get("content_id") != "PRAYER_08" or proposal.get("root") != "ROOT_CURRENT_APPEAL" or proposal.get("bootstrap") != true or proposal.get("petitioner") != "" or proposal.get("profile") != birth.profile or proposal.get("institution") != birth.institution or proposal.get("domain") != nomination.domain or sample.get("phase") != "bootstrap" or sample.get("turn") != 0 or sample.get("commit_seq") != 0 or sample.get("fact_cutoff") != birth.position.fact_before - 1: return false
	if proposal.get("source_ids") != [state.domains[nomination.domain].origin] or not state.domains[nomination.domain].origin in nomination.causal_parents: return false
	# Read the same authored bootstrap row used by the actual source handler.
	# This is bounded content grammar, not an alternative source generator.
	var file: FileAccess = FileAccess.open("res://data/background_templates.csv", FileAccess.READ)
	if file == null: return false
	var headers: PackedStringArray = file.get_csv_line(); var template: Dictionary = {}
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() != headers.size() or cells[0] != "BG_CONTACT": continue
		for index: int in headers.size(): template[headers[index]] = cells[index]
	if template.get("content_id") != "PRAYER_08" or template.get("profile") != birth.profile or birth.institution != nomination.domain + "/" + str(template.get("institution_role", "")): return false
	var fixed: Dictionary = {}
	for source: String in bootstrap.causal_parents:
		var parent: Dictionary = _fact(state, source)
		if parent.get("kind") == "prayer_fixed": fixed = parent
	var card: Dictionary = _object(fixed.get("changes", {}).get("candidate"))
	return card.get("id") == bootstrap.changes.get("candidate") and card.get("source") == situation.id and card.get("content_id") == "PRAYER_08" and card.get("actors") == [nomination.actor] and card.get("fact") == fixed.get("id") and nomination.id < selected.id and selected.id < contact.id and contact.id < call.id and call.id < situation.id and situation.id < str(fixed.get("id", "")) and str(fixed.get("id", "")) < bootstrap.id

static func _nomination_valid(state: Dictionary, catalog: RefCounted, fact: Dictionary) -> bool:
	var birth: Dictionary = _object(fact.get("changes", {}).get("birth"))
	if fact.get("kind") != "nomination" or not state.domains.has(fact.get("domain", "")) or not _keys(birth, ["schema", "profile", "institution", "local_expansion", "focus", "position"]) or birth.schema != 1 or not birth.local_expansion is bool or not birth.focus is String or not birth.institution is String or not catalog.tables.npc_profiles.has(birth.get("profile", "")) or not _position_valid(birth.position, fact) or fact.get("targets") != [fact.get("actor")]: return false
	if not state.domains[fact.domain].get("origin") is String: return false
	var person: Variant = Store.entry(state.npcs, str(fact.actor), {})
	if not person is Dictionary or person.get("identity_source") != fact.id or person.get("profile") != birth.profile: return false
	if not birth.institution.is_empty() and (not state.institutions.has(birth.institution) or state.institutions[birth.institution].domain != fact.domain): return false
	if birth.position.scope == "bootstrap":
		if not _bootstrap_birth_valid(state, catalog, fact, birth): return false
	if birth.local_expansion:
		var focus: Dictionary = _fact(state, birth.focus)
		if birth.position.scope != "turn" or focus.get("kind") != "focus_acquired" or focus.domain != fact.domain or focus.turn != fact.turn or focus.id >= fact.id or not focus.id in fact.causal_parents or focus.changes.get("position") != birth.position or fact.changes.get("from_group") != "unnamed_nonfollowers": return false
		var origin: Dictionary = _fact(state, str(state.domains[fact.domain].origin))
		if not catalog.tables.civilization_profiles.has(origin.changes.get("profile", "")): return false
		var options: Array = Initialization.profiles(catalog, catalog.tables.civilization_profiles[origin.changes.profile], birth.institution.get_slice("/", 1))
		if options.is_empty() or options[0].id != birth.profile: return false
	elif not birth.focus.is_empty(): return false
	return true

static func _admission_valid(state: Dictionary, fact: Dictionary) -> bool:
	var data: Dictionary = _object(fact.get("changes"))
	if fact.get("kind") != "attention_admitted" or not _keys(data, ["schema", "position", "source", "focus", "caller"]) or data.schema != 1 or not data.source is String or not data.focus is Array or data.focus.is_empty() or not data.caller is Dictionary or not _position_valid(data.position, fact) or data.position.scope != "turn": return false
	if fact.get("domain") != "" or fact.get("actor") != "" or fact.get("targets") != data.focus or fact.get("causal_parents") != [data.source] or _fact(state, data.source).is_empty() or data.source >= fact.id: return false
	var seen: Dictionary = {}
	for domain: Variant in data.focus:
		if not domain is String or not state.domains.has(domain) or seen.has(domain): return false
		seen[domain] = true
	return true

## World-only audit validates deterministic world births and local nomination
## provenance. Actual commit ranges are separately checked with Turn receipts.
static func validate_births(state: Dictionary, catalog: RefCounted, policy: Dictionary, trusted: Dictionary = {}) -> Array[String]:
	var incremental: bool = not trusted.is_empty()
	var first: int = int(trusted.next_fact) if incremental else 1
	var initial_people: Dictionary = {}; var focus_members: Dictionary = {}; var first_focus: Dictionary = {}
	if not incremental:
		var domains: Array = state.domains.keys(); domains.sort()
		if domains.is_empty(): return ["World has no initialization origins"]
		var first_origin: Dictionary = _fact(state, str(state.domains[domains[0]].get("origin", "")))
		var initial: Dictionary = _object(first_origin.get("changes", {}).get("initialization"))
		if not initial.get("mode") in ["full", "hybrid"]: return ["Missing actual world initialization mode"]
		var start: Dictionary = state.social_graph.cohorts.get(str(domains[0]) + "/world_start", {})
		var hybrid: bool = initial.mode == "hybrid"
		var recipe: Dictionary = Initialization.plan(catalog, str(start.get("seed_key", "")), hybrid, int(policy.initial_focused_domains), int(policy.local_actor_limit))
		if not recipe.ok or recipe.domains.size() != domains.size(): return ["World-birth recipe cannot be replayed"]
		for index: int in recipe.domains.size():
			var row: Dictionary = recipe.domains[index]
			if not state.domains.has(row.id): return ["World-birth domain order changed"]
			var origin: Dictionary = _fact(state, str(state.domains[row.id].get("origin", "")))
			var cohort: Dictionary = state.social_graph.cohorts.get(row.id + "/world_start", {})
			var generation: Dictionary = _fact(state, str(cohort.get("generation_source", "")))
			var snapshot: Dictionary = _object(generation.get("changes", {}).get("input_snapshot"))
			if origin.get("kind") != "world_origin" or origin.get("domain") != row.id or origin.get("turn") != 0 or origin.get("actor") != "" or origin.get("targets") != [] or origin.get("causal_parents") != [] or not _keys(origin.changes, ["profile", "initialization"]) or origin.changes.profile != row.profile or origin.changes.initialization != Initialization.origin_data(row, hybrid, index) or state.domains[row.id].get("profile") != row.profile: return ["World origin differs from the actual shared seed recipe"]
			if snapshot.get("expanded_at_creation") != row.expanded_at_creation or snapshot.get("institutions") != Initialization.institution_snapshot(row.id, origin.id): return ["Initial graph structure differs from initialized institutions"]
			var expected_members: Dictionary = {}
			for person: Dictionary in row.people:
				var profile: Dictionary = catalog.tables.npc_profiles[person.profile]
				expected_members[person.id] = {"profile": person.profile, "influence": int(profile.influence), "role_tags": Array(str(profile.role_tags).split(";")), "need_tags": Array(str(profile.need_tags).split(";")), "institution": person.institution, "identity_source": origin.id}
				initial_people[person.id] = {"source": origin.id, "profile": person.profile}
			if snapshot.get("members") != expected_members: return ["Initial graph birth snapshot differs from the actual shared seed recipe"]
	for number: int in range(first, int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		if fact.get("kind") == "nomination":
			if not _nomination_valid(state, catalog, fact): return ["Nomination lost its actual birth profile, institution or focus provenance"]
			var birth: Dictionary = fact.changes.birth
			if birth.local_expansion:
				if not focus_members.has(birth.focus): focus_members[birth.focus] = []
				focus_members[birth.focus].append(fact.actor)
		elif fact.get("kind") == "focus_acquired":
			if not fact.get("domain") is String or not state.domains.has(fact.domain) or not state.domains[fact.domain].get("origin") is String: return ["Focus acquisition names no actual domain origin"]
			if not _keys(fact.changes, ["turn", "position", "admission"]) or not fact.changes.admission is String or fact.changes.turn != fact.turn or not _position_valid(fact.changes.position, fact) or fact.changes.position.scope != "turn" or fact.targets != [fact.domain] or fact.actor != "" or fact.causal_parents != [state.domains[fact.domain].origin, fact.changes.admission]: return ["Focus acquisition lacks its actual managed entry position"]
			var admission: Dictionary = _fact(state, fact.changes.admission)
			if not _admission_valid(state, admission) or admission.id >= fact.id or admission.turn != fact.turn or admission.changes.position != fact.changes.position or not fact.domain in admission.changes.focus: return ["Focus acquisition has no actual preceding reservation"]
			if not first_focus.has(fact.domain): first_focus[fact.domain] = fact.id
		elif fact.get("kind") == "attention_admitted" and not _admission_valid(state, fact): return ["Malformed actual attention reservation"]
	var people: Array = Store.keys(state.npcs) if not incremental else Store.changed(state.npcs)
	for id: String in people:
		var person: Variant = Store.entry(state.npcs, id)
		if not person is Dictionary: return ["Malformed birth identity"]
		var prior: Dictionary = Store.entry(trusted.get("npcs", {}), id, {})
		if not prior.is_empty():
			if person.get("profile") != prior.get("profile") or person.get("identity_source") != prior.get("identity_source"): return ["Committed birth identity cannot change"]
			continue
		var source: Dictionary = _fact(state, str(person.get("identity_source", "")))
		if source.get("kind") == "world_origin":
			if incremental or initial_people.get(id, {}) != {"source": source.id, "profile": person.get("profile")}: return ["Person was not born in its claimed actual initialization slot"]
		elif source.get("kind") != "nomination" or source.get("actor") != id or not _nomination_valid(state, catalog, source) or (incremental and _fact_number(source.id) < first): return ["Person has no actual new nomination birth"]
	for key: String in state.social_graph.cohorts:
		if incremental and trusted.social_graph.cohorts.has(key): continue
		var cohort: Dictionary = state.social_graph.cohorts[key]
		if cohort.phase != "first_focus": continue
		var generation: Dictionary = _fact(state, cohort.generation_source)
		var focus: String = str(first_focus.get(cohort.domain, ""))
		var members: Array = focus_members.get(focus, []); members.sort()
		if focus.is_empty() or not focus in generation.causal_parents or cohort.member_ids != members: return ["First-focus cohort is not the exact new batch of its first actual expansion"]
		var origin: String = str(state.domains[cohort.domain].origin)
		if generation.changes.input_snapshot.institutions != Initialization.institution_snapshot(cohort.domain, origin): return ["First-focus graph channel snapshot lacks its real initialized sources"]
		for person: String in cohort.member_ids:
			var snapshot: Dictionary = generation.changes.input_snapshot.members[person]
			var birth: Dictionary = _fact(state, snapshot.identity_source).changes.birth
			if snapshot.profile != birth.profile or snapshot.institution != birth.institution: return ["First-focus snapshot differs from the actual nomination birth"]
	return []

## Re-evaluate only the immutable admission classification, never historical
## affordability, living state or stochastic business outcomes.
static func _policy_focus(state: Dictionary, descriptor: Dictionary, policies: Dictionary, depth: int = 0) -> Dictionary:
	if depth > 8: return {"ok": false}
	var key: String = str(descriptor.get("family", "")) + "/" + str(descriptor.get("content_id", "")) + "/" + str(descriptor.get("variant", ""))
	if not policies.has(key): return {"ok": false}
	var result: Array = []
	match str(policies[key].focus_scope):
		"target": result = [descriptor.get("target")]
		"source_and_target": result = [descriptor.get("source_domain"), descriptor.get("target")]
		"ritual_domains":
			if not descriptor.get("ritual_domains") is Array: return {"ok": false}
			result = descriptor.ritual_domains.duplicate()
	if not descriptor.get("calls", []) is Array: return {"ok": false}
	for call: Variant in descriptor.get("calls", []):
		if not call is Dictionary: return {"ok": false}
		var nested: Dictionary = _policy_focus(state, call, policies, depth + 1)
		if not nested.ok: return nested
		for domain: Variant in nested.focus:
			if not domain in result: result.append(domain)
	for domain: Variant in result:
		if not domain is String or not state.domains.has(domain): return {"ok": false}
	var unique: Array = []
	for domain: String in result:
		if not domain in unique: unique.append(domain)
	unique.sort()
	return {"ok": true, "focus": unique}

static func _action_admission_completed(state: Dictionary, admitted: Dictionary, receipt: Dictionary, caller: Dictionary) -> bool:
	var payment: Dictionary = {}; var records: Array = []
	for number: int in range(int(receipt.fact_before), int(receipt.fact_after)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		if fact.get("kind") == "turn_action" and fact.get("changes", {}).get("admission") == admitted.id:
			if not payment.is_empty(): return false
			payment = fact
		records.append(fact)
	if payment.is_empty() or payment.id <= admitted.id or payment.turn != admitted.turn or payment.causal_parents != [admitted.changes.source, admitted.id]: return false
	var input: Dictionary = caller.input; var descriptor: Dictionary = caller.descriptor
	# Generic registered components are checked against their real Turn payment.
	# Formal adapters additionally have their own actual attempt/result chain.
	if caller.participant == "prayers":
		for fact: Dictionary in records:
			var data: Dictionary = _object(fact.get("changes")); var situation: Dictionary = _object(data.get("descriptor"))
			if fact.get("kind") == "prayer_attempt" and data.get("payment") == payment.id and input.get("action") == "respond" and data.get("request") == _object(input.get("payload")).get("request") and data.get("variant") == _object(input.get("payload")).get("variant") and descriptor.get("family") == "prayer" and descriptor.get("content_id") == situation.get("content_id") and descriptor.get("variant") == data.get("variant") and descriptor.get("target") == fact.domain and situation.get("source") == admitted.changes.source: return true
		return false
	if caller.participant == "powers":
		for fact: Dictionary in records:
			var data: Dictionary = _object(fact.get("changes")); var payload: Dictionary = _object(data.get("payload"))
			if fact.get("kind") != "power_attempt" or data.get("payment") != payment.id or data.get("power") != input.get("action") or payload.get("source") != admitted.changes.source: continue
			var exact: bool = true
			for key: String in _object(input.get("payload")):
				if payload.get(key) != input.payload[key]: exact = false
			if not exact or descriptor.get("family") != "power" or descriptor.get("content_id") != ("POWER_MANIFEST" if data.power == "POWER_MANIFEST_CONTINUE" else data.power) or descriptor.get("variant") != "use" or descriptor.get("source_domain") != fact.domain: continue
			if descriptor.get("target") != (payload.get("target_domain", fact.domain) if data.power == "POWER_TRANSFER" else fact.domain): continue
			if data.power in ["POWER_MANIFEST", "POWER_MANIFEST_CONTINUE"]:
				var cosmic: Dictionary = _object(state.get("anchors", {}).get(payload.get("cosmic_anchor", ""))); var system: Dictionary = _object(state.get("anchors", {}).get(payload.get("system_anchor", "")))
				if descriptor.get("ritual_domains") != [cosmic.get("domain"), system.get("domain")]: continue
			return true
		return false
	if caller.participant == "events" and caller.slot == "events":
		var fixed: Dictionary = _fact(state, admitted.changes.source)
		var candidate: Dictionary = _object(fixed.get("changes", {}).get("candidate"))
		for fact: Dictionary in records:
			var data: Dictionary = _object(fact.get("changes")); var original: Dictionary = _object(data.get("descriptor"))
			if fact.get("kind") == "event_result" and data.get("payment") == payment.id and data.get("event") == input.get("event") and data.get("option") == input.get("action") and descriptor.get("family") == "event" and descriptor.get("variant") == data.get("option") and descriptor.get("content_id") == data.get("content_id") and descriptor.get("target") == fact.domain and fixed.get("kind") == "event_fixed" and candidate.get("id") == data.get("event") and candidate.get("descriptor") == original and admitted.changes.source in fact.causal_parents and input.get("source") == admitted.changes.source: return true
		return false
	return true

static func _admission_request_valid(state: Dictionary, context: Dictionary, fact: Dictionary, receipt: Dictionary, _catalog: RefCounted, policies: Dictionary) -> bool:
	if not _admission_valid(state, fact): return false
	var request: Dictionary = _object(receipt.get("request")); var caller: Dictionary = fact.changes.caller
	var has_expansion: bool = false
	for number: int in range(int(receipt.fact_before), int(receipt.fact_after)):
		var expanded: Dictionary = _fact(state, "FACT-%08d" % number)
		if expanded.get("kind") == "focus_acquired" and expanded.changes.get("admission") == fact.id: has_expansion = true
	if not has_expansion: return false
	if caller.get("kind") == "manual":
		var command: Dictionary = _object(request.get("command"))
		return _keys(caller, ["kind", "command"]) and request.get("op") == "attention" and request.get("phase") == "actions" and command.get("kind") == "focus" and caller.command == command and fact.changes.focus == [command.get("domain")] and fact.changes.source == state.domains[command.domain].origin
	var descriptor: Dictionary = _object(caller.get("descriptor"))
	var classification: Dictionary = _policy_focus(state, descriptor, policies)
	if not classification.ok or classification.focus != fact.changes.focus or descriptor.get("source") != fact.changes.source: return false
	if caller.get("kind") == "action":
		if not _keys(caller, ["kind", "participant", "slot", "input", "descriptor"]) or not caller.participant is String or not context.participant_state.has(caller.participant) or not caller.input is Dictionary: return false
		var input: Dictionary = caller.input
		if request.get("op") == "act":
			var participant: String = str(request.get("participant", "")); var action: String = str(request.get("action", ""))
			if participant == "powers" and action == "POWER_APPOINT": participant = "cults"; action = "appoint"
			elif participant == "powers" and action.begins_with("relic_"): participant = "relics"
			if request.get("phase") != "actions" or caller.slot != "actions" or caller.participant != participant or input.get("operation") != "act" or input.get("action") != action or input.get("payload", {}) != request.get("payload", {}): return false
		elif request.get("op") == "resolve_event":
			if request.get("phase") != "events" or caller.slot != "events" or input.get("operation") != "resolve_event" or input.get("event") != request.get("event") or input.get("action") != request.get("action") or input.get("selection", {}) != request.get("payload", {}): return false
		else: return false
		return _action_admission_completed(state, fact, receipt, caller)
	if caller.get("kind") == "strategy":
		if not _keys(caller, ["kind", "cult", "row", "descriptor"]) or not caller.cult is String or not state.get("cults", {}).has(caller.cult) or not caller.row is Dictionary or not request.get("op") in ["end_actions", "rest"] or request.get("phase") != "actions": return false
		var row: Dictionary = caller.row; var cult: Dictionary = state.cults[caller.cult]
		if row.get("cult") != caller.cult or row.get("source") != fact.changes.source or row.get("intent") != "expand" or row.get("effective") != "expand" or descriptor != {"family": "strategy", "content_id": "proselytize", "variant": "plan", "target": cult.domain, "source": fact.changes.source}: return false
		for number: int in range(int(receipt.fact_before), int(receipt.fact_after)):
			var locked: Dictionary = _fact(state, "FACT-%08d" % number)
			if locked.get("kind") == "attention_plan_locked" and locked.id > fact.id and locked.get("changes", {}).get("admissions") is Array and fact.id in locked.changes.admissions and fact.id in locked.causal_parents and _object(locked.changes.get("strategies")).get(caller.cult) == "expand": return true
	return false

static func validate_context(state: Dictionary, context: Dictionary, catalog: RefCounted, first_new_fact: int = 0, receipt_by_sequence: Dictionary = {}, policies: Dictionary = {}) -> Array[String]:
	var receipts: Dictionary = receipt_by_sequence.duplicate(false)
	if first_new_fact == 0:
		for receipt: Variant in Store.values(context.get("receipts", {})):
			if not receipt is Dictionary or not receipt.get("sequence") is int: return ["Birth context has no valid receipt sequence"]
			receipts[receipt.sequence] = receipt
	var first_receipt: Dictionary = receipts.get(1, {})
	var initialization_end: int = int(first_receipt.get("fact_before", state.next_fact))
	for number: int in range(maxi(1, first_new_fact), int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		var position: Dictionary = {}
		var related: Array = []
		if fact.get("kind") == "nomination":
			var birth: Dictionary = _object(fact.changes.get("birth")); position = _object(birth.get("position"))
			if birth.get("local_expansion", false): related.append(birth.get("focus", ""))
		elif fact.get("kind") in ["focus_acquired", "attention_admitted"]: position = _object(fact.changes.get("position"))
		elif fact.get("kind") == "social_graph_generation" and fact.changes.get("phase") == "first_focus":
			for source: String in fact.causal_parents:
				var parent: Dictionary = _fact(state, source)
				if parent.get("kind") == "focus_acquired": position = _object(parent.changes.get("position")); related.append(source)
				elif parent.get("kind") == "nomination": related.append(source)
		else: continue
		if not _position_valid(position, fact): return ["Birth/focus has no valid receipt position"]
		if position.scope in ["standalone", "bootstrap"]:
			if number >= initialization_end: return ["Standalone/bootstrap birth was inserted into a later Turn history"]
			continue
		var receipt: Dictionary = receipts.get(position.sequence, {})
		if receipt.is_empty() or not receipt.get("fact_after") is int or receipt.get("fact_before") != position.fact_before or _object(receipt.get("request")).get("phase") != position.entry_phase or _object(receipt.get("request")).get("turn") != position.entry_turn or number < int(receipt.fact_before) or number >= int(receipt.fact_after): return ["Birth/focus is outside its actual Turn receipt range/entry phase"]
		for source: String in related:
			if _fact_number(source) < int(receipt.fact_before) or _fact_number(source) >= int(receipt.fact_after): return ["First-focus birth and generation belong to different commits"]
		if fact.kind == "attention_admitted" and not _admission_request_valid(state, context, fact, receipt, catalog, policies): return ["Attention reservation does not match its actual request, source, policy or completed action"]
	return []

static func validate_state(state: Dictionary, catalog: RefCounted, trusted: Dictionary = {}, reader: RefCounted = null) -> Array[String]:
	var errors: Array[String] = []
	for field: String in ["npcs", "facts", "domains", "institutions", "invalid_records", "applied_authorizations"]:
		if not state.get(field) is Dictionary: return ["Missing social audit collection: " + field]
	if not state.get("next_fact") is int or state.next_fact < 1 or not state.get("turn") is int or state.turn < 0: return ["Invalid social audit position"]
	if not state.get("social_graph") is Dictionary: return ["Current World requires social graph schema; old fixed-ring state is incompatible"]
	var graph: Dictionary = state.social_graph
	if not _keys(graph, ["schema", "model_version", "data_versions", "cohorts", "edge_heads"]) or graph.schema != STATE_SCHEMA or graph.model_version != catalog.integer("model_version") or graph.data_versions != data_versions(catalog) or not graph.cohorts is Dictionary or not graph.edge_heads is Dictionary: return ["Invalid social graph schema/content version"]
	for value: Variant in graph.data_versions.values():
		if not value is String or value.length() != 64: return ["Social graph content fingerprint is missing"]
	if graph.cohorts.size() > catalog.integer("domains_total") * 2: return ["Too many social cohorts"]
	for domain: String in state.domains:
		if not graph.cohorts.has(domain + "/world_start"): return ["Domain has no completed world-start graph cohort"]
	var incremental: bool = trusted.has("social_graph")
	var first: int = int(trusted.next_fact) if incremental else 1
	var ids: Array = []
	for sequence: int in range(first, int(state.next_fact)): ids.append("FACT-%08d" % sequence)
	var generations: Dictionary = {}; var contacts: Dictionary = {}; var initials: Dictionary = {}; var relations: Array = []
	var expected_heads: Dictionary = trusted.social_graph.edge_heads if incremental else History.from_value({}, "map")
	if incremental:
		if trusted.social_graph.model_version != graph.model_version or trusted.social_graph.data_versions != graph.data_versions: return ["Social graph version cannot change in a transaction"]
		for key: String in trusted.social_graph.cohorts:
			if not is_same(graph.cohorts.get(key), trusted.social_graph.cohorts[key]): return ["An initialized social cohort was removed or rewritten"]
	for source: String in ids:
		var raw_fact: Variant = Store.entry(state.facts, source, {})
		if not raw_fact is Dictionary or not raw_fact.get("kind") is String or not raw_fact.get("changes") is Dictionary or not raw_fact.get("causal_parents") is Array or not raw_fact.get("targets") is Array or not raw_fact.get("actor") is String or not raw_fact.get("domain") is String or not raw_fact.get("turn") is int or raw_fact.get("id") != source: return ["Missing or malformed social audit fact"]
		var fact: Dictionary = raw_fact
		if fact.kind == "social_graph_generation":
			var key: String = str(fact.changes.get("cohort", ""))
			if generations.has(key): return ["Repeated social generation source"]
			generations[key] = fact
		elif fact.kind == "social_contact":
			var key: String = str(fact.changes.get("cohort", ""))
			if not contacts.has(key): contacts[key] = []
			contacts[key].append(fact)
		elif fact.kind in ["initial_relationship", "relationship"]:
			var data: Dictionary = relation_data(fact, catalog)
			if data.is_empty() or not Store.has(state.npcs, data.a) or not Store.has(state.npcs, data.b): return ["Invalid source-backed relationship shape"]
			var key: String = edge_key(data.a, data.b, data.kind, data.direction)
			var old: String = str(History.mapget(expected_heads, key, ""))
			if not old.is_empty():
				var retired: String = str(Store.entry(state.invalid_records, old, ""))
				if retired.is_empty() or _fact_number(retired) >= _fact_number(fact.id): return ["Duplicate current relation episode"]
			if fact.kind == "relationship" and not authorized_result(state, data.a, data.b, data.kind, fact.causal_parents, catalog): return ["Relationship has no actual authorized business result"]
			expected_heads = History.set_value(expected_heads, key, fact.id, "map")
			relations.append(data)
			if fact.kind == "initial_relationship":
				var cohort: String = str(fact.changes.cohort)
				if not initials.has(cohort): initials[cohort] = []
				initials[cohort].append(fact)
	# Only newly invalidated exact relation sources are revisited during commits.
	var invalidations: Array = []
	if incremental:
		for source: String in Store.changed(state.invalid_records): invalidations.append({"key": source})
	if not incremental:
		for key: String in History.keys(expected_heads): invalidations.append({"key": History.mapget(expected_heads, key)})
	for entry: Dictionary in invalidations:
		var original: Dictionary = Store.entry(state.facts, str(entry.key), {})
		var data: Dictionary = relation_data(original, catalog)
		if data.is_empty() or not Store.has(state.invalid_records, data.source): continue
		var key: String = edge_key(data.a, data.b, data.kind, data.direction)
		if History.mapget(expected_heads, key, "") == data.source: expected_heads = History.erase(expected_heads, key)
	if History.size(expected_heads) != History.size(graph.edge_heads) or not History.changed_entries(graph.edge_heads, expected_heads).is_empty(): return ["Social current heads disagree with actual relation history"]
	for key: String in graph.cohorts:
		if incremental and trusted.social_graph.cohorts.has(key): continue
		var cohort: Variant = graph.cohorts[key]
		if not cohort is Dictionary or not _keys(cohort, ["domain", "phase", "turn", "member_ids", "seed_key", "generation_source", "completed", "empty_reason"]) or not state.domains.has(cohort.get("domain", "")) or not cohort.get("phase") in ["world_start", "first_focus"] or key != cohort.domain + "/" + cohort.phase or not cohort.get("turn") is int or cohort.turn < 0 or cohort.turn > state.turn or cohort.get("completed") != true or not cohort.get("member_ids") is Array or not canonical_seed(str(cohort.get("seed_key", ""))): return ["Invalid completed social cohort metadata"]
		var fact: Dictionary = generations.get(key, {})
		if fact.is_empty() or fact.id != cohort.generation_source or fact.domain != cohort.domain or fact.turn != cohort.turn or not _keys(fact.changes, ["schema", "root", "source_phase", "model_version", "data_versions", "seed_key", "domain", "phase", "cohort", "member_ids", "input_snapshot"]): return ["Social cohort lacks its actual generation source"]
		var data: Dictionary = fact.changes
		if data.schema != SCHEMA or data.root != "ROOT_INITIAL_TIES" or data.source_phase != "bootstrap" or data.model_version != graph.model_version or data.data_versions != graph.data_versions or data.seed_key != cohort.seed_key or data.domain != cohort.domain or data.phase != cohort.phase or data.cohort != key or data.member_ids != cohort.member_ids or not data.input_snapshot is Dictionary: return ["Social generation source differs from its cohort"]
		if cohort.phase == "world_start" and cohort.turn != 0: return ["World-start graph generated after initialization"]
		if cohort.phase == "first_focus":
			if cohort.turn <= 0: return ["First-focus graph has no real later focus"]
			var focus: bool = false
			for parent: String in fact.causal_parents:
				var cause: Dictionary = Store.entry(state.facts, parent, {})
				if cause.get("kind") == "focus_acquired" and cause.domain == cohort.domain and cause.turn == cohort.turn: focus = true
			if not focus: return ["First-focus graph has no actual focus source"]
			var start: Dictionary = graph.cohorts.get(cohort.domain + "/world_start", {})
			var start_fact: Dictionary = Store.entry(state.facts, str(start.get("generation_source", "")), {})
			if start_fact.get("changes", {}).get("input_snapshot", {}).get("expanded_at_creation", false): return ["Already expanded world-start domain generated a second initial graph"]
		var planned: Dictionary = plan(catalog, cohort.seed_key, cohort.domain, cohort.phase, key, data.input_snapshot)
		if not planned.ok or planned.empty_reason != cohort.empty_reason: return ["Social cohort cannot replay its finite generation input"]
		var member_ids: Array = data.input_snapshot.members.keys(); member_ids.sort()
		if member_ids != cohort.member_ids: return ["Cohort member list differs from the actual snapshot"]
		for person_id: String in member_ids:
			var person: Dictionary = data.input_snapshot.members[person_id]
			var identity_value: Variant = Store.entry(state.facts, person.identity_source, {})
			var current_value: Variant = Store.entry(state.npcs, person_id, {})
			if not identity_value is Dictionary or not current_value is Dictionary: return ["Malformed social identity/birth source"]
			var identity: Dictionary = identity_value; var current: Dictionary = current_value
			var profile: Dictionary = catalog.tables.npc_profiles[person.profile]
			if current.is_empty() or current.get("identity_source") != person.identity_source or current.profile != person.profile or person.influence != int(profile.influence) or person.role_tags != Array(str(profile.role_tags).split(";")) or person.need_tags != Array(str(profile.need_tags).split(";")) or not person.identity_source in fact.causal_parents or identity.get("domain") != cohort.domain: return ["Cohort member lacks its actual birth/profile input"]
			if cohort.phase == "world_start" and identity.get("kind") != "world_origin": return ["World-start identity was not initialized from its real origin"]
			if cohort.phase == "first_focus" and (identity.get("kind") != "nomination" or identity.actor != person_id or identity.turn != cohort.turn or identity.changes.get("from_group") != "unnamed_nonfollowers"): return ["First-focus identity lacks its real new nomination"]
		var actual_contacts: Array = contacts.get(key, []); var actual_relations: Array = initials.get(key, [])
		if actual_contacts.size() != planned.edges.size() or actual_relations.size() != planned.edges.size(): return ["Initial graph contact/relation count differs from its replay"]
		var used: Dictionary = {}
		for edge: Dictionary in planned.edges:
			var contact: Dictionary = {}; var relation: Dictionary = {}
			for item: Dictionary in actual_contacts:
				if item.changes.get("a") == edge.contact_a and item.changes.get("b") == edge.contact_b: contact = item
			if contact.is_empty() or used.has(contact.id) or not _keys(contact.changes, ["cohort", "a", "b", "basis", "institutions", "channel_sources"]) or contact.changes.cohort != key or contact.changes.basis != edge.context.kind or contact.changes.institutions != edge.context.institutions or contact.changes.channel_sources != edge.context.channel_sources or contact.domain != cohort.domain or contact.turn != cohort.turn or contact.actor != edge.contact_a or contact.targets != [edge.contact_b] or not fact.id in contact.causal_parents: return ["Initial contact differs from its selected actual pair"]
			for cause: String in edge.context.channel_sources + [data.input_snapshot.members[edge.contact_a].identity_source, data.input_snapshot.members[edge.contact_b].identity_source]:
				if not cause in contact.causal_parents or not Store.has(state.facts, cause): return ["Initial contact lacks an actual identity/channel source"]
			for item: Dictionary in actual_relations:
				if item.changes.get("contact") == contact.id: relation = item
			if relation.is_empty() or relation.changes.get("a") != edge.a or relation.changes.get("b") != edge.b or relation.changes.get("kind") != edge.kind or relation.changes.get("direction") != edge.direction or relation.domain != cohort.domain or relation.turn != cohort.turn or relation.causal_parents != [contact.id]: return ["Initial relationship differs from selected type/direction"]
			used[contact.id] = true
	if generations.size() != (graph.cohorts.size() - trusted.social_graph.cohorts.size() if incremental else graph.cohorts.size()): return ["Orphan social generation source"]
	for cohort: String in contacts:
		if not generations.has(cohort): return ["Orphan initial social contact"]
	for cohort: String in initials:
		if not generations.has(cohort): return ["Initial relationship outside its one authorized cohort"]
	for data: Dictionary in relations:
		for pair: Array in [[data.a, data.b], [data.b, data.a]]:
			if data.direction == "directed" and pair[0] != data.a: continue
			var found: bool = false
			if incremental and reader != null:
				found = not reader.relation(pair[0], pair[1], data.source).is_empty()
			else:
				for item: Dictionary in History.values(Store.entry(state.npcs, pair[0]).relations):
					if item.get("source") == data.source and item.get("target") == pair[1] and item.get("kind") == data.kind: found = true; break
			if not found: return ["Relationship is missing from its endpoint's historical projection"]
	errors.append_array(_relation_changes_valid(state, catalog, trusted))
	if errors.is_empty(): errors.append_array(validate_projections(state, catalog, trusted))
	return errors
