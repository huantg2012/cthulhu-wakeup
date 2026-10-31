extends RefCounted
## Actual material dependency is a current, source-bound condition. Power execution,
## relic custody and upkeep remain owned by their existing production modules.
const Routes = preload("res://src/game/anchor_routes.gd")
const ID: String = "civilization_dependency/schema2/routes3"
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const SCHEMA: int = 2
const BASIS: Dictionary = {"dual_testimony": ["records", "witnesses"], "calendar_ritual": ["rituals", "priest"], "shared_memory": ["memory", "witnesses", "qualifications"], "orthodox_witness": ["ritual", "public", "priest"], "network_evidence": ["other_institution", "records", "witnesses"], "contract_dependency": ["contract", "dependency", "witnesses", "successor"], "axiom_exception": ["exception", "other_institution", "records"], "collective_dissent": ["memory", "witnesses", "qualifications"]}
const EVIDENCE: Array[String] = ["private_testimony", "anomaly_record", "public_witness", "public_evidence", "exception_record", "exception_learned"]
const PUBLIC: Array[String] = ["public_witness", "public_ritual", "public_evidence", "public_exception_qualification", "anomaly_evidence"]
var catalog: RefCounted
var issuers: Dictionary
var version: String

func _init(content: RefCounted, accepted_issuers: Dictionary = {}) -> void:
	catalog = content; issuers = accepted_issuers.duplicate(true); version = rule_version(content)

static func rule_version(content: RefCounted) -> String:
	var parts: Array = [ID, "lifecycle1/route-materials1/personal-holdings1", content.version]
	for extension: String in ["anchor_conditions", "anchor_route_rules", "progression_route_operations", "foundation_route_parameters", "memory_contract_route_parameters", "anchor_restrictions", "material_transfer_families", "material_transfer_parameters", "material_transfer_rules", "events", "event_effects", "prayer_effects", "power_effects"]: parts.append(str(content.extension_versions.get(extension, "missing")))
	return "/".join(parts)

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("anchor_system") or not turn.world.state.has("power_system") or not catalog.tables.has("anchor_conditions"): return false
	for issuer: Variant in issuers:
		if not issuer is String or issuer.is_empty() or not issuers[issuer] is String or str(issuers[issuer]).is_empty(): return false
	turn.world.state["anchor_system"] = {"schema": SCHEMA, "version": version, "issuers": issuers.duplicate(true), "proofs": {}, "routes": {}, "bindings": {}, "restrictions": {}, "opportunities": {}}
	if not turn.register_participant("anchors", version + "/" + JSON.stringify(issuers, "", true, true).sha256_text(), ["anchors_start"], [], handle):
		turn.world.state.erase("anchor_system"); return false
	if not turn.world.ensure_history(true): return false
	refresh_restriction_heads(turn.world)
	turn.world._refresh_anchors()
	return true

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	var ok: bool = input.get("slot") == "anchors_start" and view.world.get("anchor_system", {}).get("version") == version
	return {"ok": ok, "empty": true, "effects": [], "state": {}}

static func _denied(reason: String, source: String = "", missing: Array = []) -> Dictionary:
	return {"ok": true, "allowed": false, "reason": reason, "source": source, "missing": missing if not missing.is_empty() else [reason]}

static func _fact(state: Dictionary, id: String, index: RefCounted = null) -> Dictionary:
	if Store.has(state.get("facts", {}), id): return Store.entry(state.facts, id)
	if index != null and index.has_method("fact"):
		var result: Dictionary = index.fact(id)
		if result.ok: return result.item
	return {}

static func _npc(state: Dictionary, id: String, index: RefCounted = null) -> Dictionary:
	if Store.has(state.get("npcs", {}), id): return Store.entry(state.npcs, id)
	if index != null and index.has_method("entity"):
		var result: Dictionary = index.entity("npcs", id)
		if result.ok: return result.item
	return {}

static func _invalid(state: Dictionary, id: String, index: RefCounted = null) -> bool:
	return index.invalidated(id) if index != null and index.has_method("invalidated") else Store.has(state.get("invalid_records", {}), id)

static func _current(state: Dictionary, id: String, index: RefCounted = null) -> bool:
	return not _fact(state, id, index).is_empty() and not _invalid(state, id, index)

static func _knows(state: Dictionary, owner: String, source: String, index: RefCounted = null, institution: bool = false) -> bool:
	if index != null:
		if index.has_method("fact"): return index.knows(owner, source, institution)
		return index.knows(state, owner, source, institution)
	var person: Dictionary = state.get("institutions", {}).get(owner, {}) if institution else _npc(state, owner)
	return not person.is_empty() and History.has(person.get("known_facts", []), source)

static func _authorization(state: Dictionary, key: String, index: RefCounted = null) -> String:
	if index != null and index.has_method("authorization"):
		var result: Dictionary = index.authorization(key)
		return str(result.source) if result.ok and result.used else ""
	return str(Store.entry(state.get("applied_authorizations", {}), key, ""))

static func _shape(data: Dictionary, required: Array, optional: Array = []) -> bool:
	for key: Variant in data:
		if not key is String or not key in required + optional: return false
	for key: String in required:
		if not data.has(key): return false
	return true

static func _strings(value: Variant, count: int = -1, unique: bool = true) -> bool:
	if not value is Array or (count >= 0 and value.size() != count): return false
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is String or item.is_empty() or (unique and seen.has(item)): return false
		seen[item] = true
	return true

static func _row(state: Dictionary, institution: String, content: RefCounted) -> Dictionary:
	if not state.get("institutions", {}).has(institution): return {}
	var office: Dictionary = state.institutions[institution]
	if not state.get("domains", {}).has(office.get("domain", "")): return {}
	return content.tables.get("anchor_conditions", {}).get(state.domains[office.domain].profile, {})

static func _alive(state: Dictionary, person: String, index: RefCounted = null) -> bool:
	var npc: Dictionary = _npc(state, person, index)
	return not npc.is_empty() and npc.get("status") != "dead"

static func _priest(state: Dictionary, person: String, institution: String, index: RefCounted = null) -> bool:
	var npc: Dictionary = _npc(state, person, index)
	return not npc.is_empty() and npc.status == "active" and npc.domain == state.institutions[institution].domain and npc.get("institution") == institution and "ritual_keeper" in npc.get("role_tags", [])

static func _connected(state: Dictionary, first: String, second: String) -> bool:
	if first == second or not state.institutions.has(second): return false
	var other: Dictionary = state.institutions[second]
	return other.active and other.domain == state.institutions[first].domain and second in state.institutions[first].links

static func _prayer_record(state: Dictionary, id: String, index: RefCounted = null, require_current: bool = true) -> Dictionary:
	var record: Dictionary = _fact(state, id, index)
	if record.is_empty() or (require_current and not _current(state, id, index)): return {}
	var event_publication: bool = record.kind == "event_publication"
	var publication: Dictionary = record
	if event_publication:
		var result: Dictionary = {}
		for parent: String in record.causal_parents:
			var candidate: Dictionary = _fact(state, parent, index)
			if candidate.get("kind") == "event_result": result = candidate
		var original: String = str(record.changes.get("record", ""))
		if result.is_empty() or result.changes.get("content_id") != "EVENT_02" or result.changes.get("option") != "B" or not original in record.causal_parents or not original in result.changes.get("descriptor", {}).get("facts", {}).get("records", []) or record.changes.get("event") != "EVENT_02" or record.changes.get("option") != "B" or _authorization(state, "event/resolved/" + str(result.changes.get("event", "")), index) != result.id: return {}
		record = _fact(state, original, index)
		if record.is_empty() or (require_current and not _current(state, original, index)): return {}
	var public_exposure: bool = record.kind == "exposure"
	var published: Dictionary = publication if event_publication else record
	if public_exposure:
		if record.changes.get("public") != true or record.causal_parents.size() != 1: return {}
		record = _fact(state, record.causal_parents[0], index)
		if record.is_empty() or (require_current and not _current(state, record.id, index)) or not record.changes.get("tag") in PUBLIC or published.changes.get("tag") != record.changes.tag or published.changes.get("request") != record.changes.get("request"): return {}
	if record.kind != "prayer_fact" or not record.changes.get("tag") is String or not record.changes.get("prayer") is String or not record.changes.get("request") is String or not record.changes.get("subjects") is Dictionary or not record.changes.get("facts") is Dictionary: return {}
	var checked: Dictionary = {}
	for parent: String in record.causal_parents:
		var fact: Dictionary = _fact(state, parent, index)
		if fact.get("kind") == "turn_check" and fact.changes.get("outcome") in ["deep", "success"]: checked = fact; break
	if checked.is_empty(): return {}
	var attempt: Dictionary = {}
	for parent: String in checked.causal_parents:
		var fact: Dictionary = _fact(state, parent, index)
		if fact.get("kind") == "prayer_attempt": attempt = fact; break
	if attempt.is_empty() or attempt.changes.get("request") != record.changes.request or attempt.changes.get("descriptor", {}).get("content_id") != record.changes.prayer or attempt.changes.get("descriptor", {}).get("institution") != record.changes.get("institution") or attempt.changes.get("descriptor", {}).get("subjects") != record.changes.subjects or attempt.changes.get("descriptor", {}).get("facts") != record.changes.facts or checked.actor != attempt.actor: return {}
	var institution: String = record.changes.institution
	if record.changes.tag in ["exception_learned", "public_exception_qualification"]:
		var recipient: String = str(record.changes.subjects.get("other_institution", ""))
		if recipient.is_empty() or not recipient in record.targets: return {}
		institution = recipient
	if event_publication and publication.changes.get("institution") != institution: return {}
	return {"record": published, "base": record, "attempt": attempt, "check": checked, "tag": record.changes.tag, "institution": institution, "public": event_publication or public_exposure or record.changes.tag in PUBLIC, "family": "evidence"}

static func _witness(state: Dictionary, source: Dictionary, person: String, index: RefCounted = null) -> bool:
	if source.is_empty(): return false
	var base: Dictionary = source.base
	var subjects: Dictionary = base.changes.subjects
	var real: bool = person == subjects.get("petitioner") or person in base.targets
	if not real: return false
	if _knows(state, person, source.record.id, index) or _knows(state, person, base.id, index): return true
	var result_id: String = _authorization(state, "prayer/response/" + base.changes.request, index)
	var result: Dictionary = _fact(state, result_id, index)
	return not result.is_empty() and result.kind == "prayer_result" and base.id in result.changes.get("produced", {}).values() and _knows(state, person, result_id, index)

static func _received(state: Dictionary, source: Dictionary, institution: String, index: RefCounted = null) -> bool:
	return not source.is_empty() and source.institution == institution and _knows(state, institution, source.record.id, index, true)

static func _basis_sources(rule: String, basis: Dictionary) -> Array:
	var fields: Array = []
	match rule:
		"dual_testimony", "network_evidence": fields = ["records"]
		"calendar_ritual": fields = ["rituals"]
		"shared_memory", "collective_dissent": fields = ["memory", "qualifications"]
		"orthodox_witness": fields = ["ritual", "public"]
		"contract_dependency": fields = ["contract", "dependency", "witnesses", "successor"]
		"axiom_exception": fields = ["exception", "records"]
	var result: Array = []
	for key: String in fields:
		if not basis.has(key): continue
		var values: Array = basis[key] if basis[key] is Array else [basis[key]]
		for value: Variant in values:
			if not value is String or value.is_empty(): return []
			if not value in result: result.append(value)
	return result

static func qualify(state: Dictionary, institution: String, source: String, content: RefCounted, index: RefCounted = null, purpose: String = "anchor", actor: String = "") -> Dictionary:
	if state.get("anchor_system", {}).get("schema") != SCHEMA: return {"ok": false, "error": "Current material dependency capability unavailable"}
	var fact: Dictionary = _fact(state, source, index)
	if not _basis_contract(state, institution, fact, content, index) or not _current(state, source, index): return _denied("missing_current_anchor_basis", source)
	var result: Dictionary = evaluate(state, institution, fact.changes.basis, content, index, purpose, actor)
	result["source"] = source
	if result.get("allowed", false) and result.basis != fact.changes.basis: return _denied("current_basis_material_bundle_changed", source)
	if result.get("allowed", false):
		result["issuer"] = ID; result["version"] = rule_version(content)
	return result

static func maintenance(state: Dictionary, institution: String, content: RefCounted, index: RefCounted = null) -> Dictionary:
	var bound: String = ""
	for anchor: Dictionary in state.get("anchors", {}).values():
		if anchor.institution == institution: bound = str(anchor.get("route", "")); break
	var source: String = str(state.get("anchor_system", {}).get("routes", {}).get(institution, {}).get(bound, "")) if not bound.is_empty() else str(state.get("anchor_system", {}).get("proofs", {}).get(institution, ""))
	return _denied("missing_current_bound_route") if source.is_empty() else qualify(state, institution, source, content, index)

static func _dream_record(state: Dictionary, id: String, index: RefCounted = null, require_current: bool = true) -> Dictionary:
	var fact: Dictionary = _fact(state, id, index)
	var published: Dictionary = fact
	var event_publication: bool = fact.get("kind") == "event_publication"
	if event_publication:
		if require_current and not _current(state, id, index): return {}
		var result: Dictionary = {}
		for parent: String in fact.causal_parents:
			var candidate: Dictionary = _fact(state, parent, index)
			if candidate.get("kind") == "event_result": result = candidate
		var original: String = str(fact.changes.get("record", ""))
		if result.is_empty() or result.changes.get("content_id") != "EVENT_02" or result.changes.get("option") != "B" or not original in fact.causal_parents or not original in result.changes.get("descriptor", {}).get("facts", {}).get("records", []) or _authorization(state, "event/resolved/" + str(result.changes.get("event", "")), index) != result.id: return {}
		fact = _fact(state, original, index)
	if fact.get("kind") != "miracle" or fact.changes.get("power") != "POWER_DREAM" or (require_current and not _current(state, fact.get("id", ""), index)): return {}
	var attempt: Dictionary = {}; var check: Dictionary = {}
	for parent: String in fact.causal_parents:
		var cause: Dictionary = _fact(state, parent, index)
		if cause.get("kind") == "power_result":
			for original: String in cause.causal_parents:
				var checked: Dictionary = _fact(state, original, index)
				if checked.get("kind") == "turn_check": check = checked
		if cause.get("kind") == "turn_check": check = cause
	if check.is_empty() or not check.changes.get("outcome") in ["deep", "success"]: return {}
	for parent: String in check.causal_parents:
		var cause: Dictionary = _fact(state, parent, index)
		if cause.get("kind") == "power_attempt" and cause.changes.get("power") == "POWER_DREAM": attempt = cause
	if attempt.is_empty() or attempt.actor != fact.actor or not fact.actor in fact.changes.get("witnesses", []): return {}
	var proof: Dictionary = attempt.changes.get("proofs", {}).get("dream", {})
	var contact: Dictionary = _fact(state, str(proof.get("basis", {}).get("contact", "")), index)
	var institution: String = str(proof.get("institution", ""))
	if contact.is_empty() or institution.is_empty(): return {}
	var member_contact: bool = contact.kind in ["member_enrolled", "cult_member_joined"] and contact.actor == fact.actor and fact.actor in contact.targets and proof.get("issuer") == "player_sources"
	if not member_contact and contact.changes.get("institution", contact.changes.get("descriptor", {}).get("institution", "")) != institution: return {}
	if event_publication and published.changes.get("institution") != institution: return {}
	return {"record": published, "base": fact, "attempt": attempt, "check": check, "institution": institution, "tag": "dream", "family": "dream", "public": event_publication}

static func exception_observation(state: Dictionary, record: String, index: RefCounted = null) -> Dictionary:
	var source: Dictionary = _prayer_record(state, record, index)
	if source.is_empty() or not source.tag in ["exception_record", "exception_learned", "public_exception_qualification"]: return {}
	var facts: Dictionary = source.base.changes.facts
	var observation: Dictionary = _fact(state, str(facts.get("observation", "")), index)
	if observation.get("kind") != "law_observation" or observation.changes.get("scene_rule") != "ROOT_COSMIC_OBSERVATION" or observation.changes.get("exception") != facts.get("exception") or observation.changes.get("observer") != source.base.changes.subjects.get("petitioner") or not state.institutions.has(observation.changes.get("node", "")): return {}
	return {"id": observation.id, "exception": observation.changes.exception, "observer": observation.changes.observer, "node": observation.changes.node}

static func independent_exception_records(state: Dictionary, first: String, second: String, index: RefCounted = null) -> bool:
	var a: Dictionary = exception_observation(state, first, index)
	var b: Dictionary = exception_observation(state, second, index)
	return not a.is_empty() and not b.is_empty() and a.exception == b.exception and a.observer != b.observer and a.node != b.node

static func _evidence_record(state: Dictionary, id: String, index: RefCounted = null, dreams: bool = false) -> Dictionary:
	var source: Dictionary = _prayer_record(state, id, index)
	if not source.is_empty() and (source.tag in EVIDENCE or (source.record.kind == "exposure" and source.public)): return source
	return _dream_record(state, id, index) if dreams else {}

static func _record_witness(state: Dictionary, source: Dictionary, person: String, index: RefCounted = null) -> bool:
	if source.is_empty(): return false
	if source.family == "dream": return person in source.base.changes.get("witnesses", []) and _knows(state, person, source.record.id, index)
	return _witness(state, source, person, index)

static func _memory_qualification(state: Dictionary, id: String, memory: String, witness: String, index: RefCounted = null) -> Dictionary:
	var record: Dictionary = _prayer_record(state, id, index)
	if record.is_empty() or record.tag != "memory_preserved" or record.base.changes.prayer != "PRAYER_07" or record.base.changes.get("memory") != memory or not witness in record.base.targets: return {}
	var original: Dictionary = _fact(state, str(record.base.changes.get("original", "")), index)
	if original.get("kind") != "memory_at_risk" or original.changes.get("memory") != memory or not witness in original.changes.get("holders", []) or _authorization(state, "prayer/memory/" + original.id + "/" + witness, index) != id or not _knows(state, witness, memory, index) or not _witness(state, record, witness, index): return {}
	if not _authorization(state, "prayer/memory_lost/" + original.id + "/" + witness, index).is_empty(): return {}
	return record

static func _check_basis(state: Dictionary, institution: String, result: Dictionary, row: Dictionary, content: RefCounted, index: RefCounted = null) -> String:
	var basis: Dictionary = result.changes.basis
	var count: int = content.integer(row.count_parameter) if not row.count_parameter.is_empty() else -1
	match str(row.rule):
		"dual_testimony":
			if not _strings(basis.records, count) or not _strings(basis.witnesses, count): return "distinct_testimony_count_unmet"
			var turns: Dictionary = {}; var origins: Dictionary = {}
			for position: int in count:
				var source: Dictionary = _evidence_record(state, basis.records[position], index)
				var person: String = basis.witnesses[position]
				if not person in result.targets or not _alive(state, person, index) or not _received(state, source, institution, index) or not _record_witness(state, source, person, index): return "testimony_not_received_or_witness_unavailable"
				if turns.has(source.base.turn) or origins.has(source.base.id): return "testimony_not_independent_across_turns"
				turns[source.base.turn] = true; origins[source.base.id] = true
		"calendar_ritual":
			if not _strings(basis.rituals, count) or not basis.priest is String or not basis.priest in result.targets or not _priest(state, basis.priest, institution, index): return "current_witness_priest_unavailable"
			var turns: Dictionary = {}
			for id: String in basis.rituals:
				var source: Dictionary = _prayer_record(state, id, index)
				if source.is_empty() or not source.tag in ["ritual_witness", "public_ritual"] or source.base.changes.prayer != "PRAYER_05" or not _received(state, source, institution, index) or not _witness(state, source, basis.priest, index): return "ritual_not_real_or_not_this_priest"
				if turns.has(source.base.turn): return "ritual_turns_not_distinct"
				turns[source.base.turn] = true
		"shared_memory", "collective_dissent":
			if not basis.memory is String or _fact(state, basis.memory, index).is_empty() or not _strings(basis.witnesses, count) or not _strings(basis.qualifications, count): return "memory_original_graph_unmet"
			var qualified: int = 0
			for position: int in count:
				var person: String = basis.witnesses[position]
				var id: String = basis.qualifications[position]
				var historical_source: Dictionary = _prayer_record(state, id, index, false)
				if historical_source.is_empty(): return "memory_witness_was_not_original"
				var historical: Dictionary = historical_source.base
				var original: Dictionary = _fact(state, str(historical.changes.get("original", "")), index)
				if historical.changes.get("tag") != "memory_preserved" or historical.changes.get("prayer") != "PRAYER_07" or historical.changes.get("memory") != basis.memory or not person in historical.targets or not person in result.targets or original.get("kind") != "memory_at_risk" or original.changes.get("memory") != basis.memory or not person in original.changes.get("holders", []) or not _received(state, historical_source, institution, index) or _authorization(state, "prayer/memory/" + original.id + "/" + person, index) != id: return "memory_witness_was_not_original"
				var qualification: Dictionary = _memory_qualification(state, id, basis.memory, person, index)
				if not qualification.is_empty() and _alive(state, person, index) and _received(state, qualification, institution, index): qualified += 1
			var minimum: int = content.integer(row.alive_parameter) if not row.alive_parameter.is_empty() else int(row.alive_min)
			if qualified < minimum: return "memory_current_witness_count_unmet"
		"orthodox_witness":
			if not basis.ritual is String or not basis.public is String or not basis.priest is String or not basis.priest in result.targets or not _priest(state, basis.priest, institution, index): return "current_orthodox_priest_unavailable"
			var ritual: Dictionary = _prayer_record(state, basis.ritual, index)
			var public_record: Dictionary = _prayer_record(state, basis.public, index)
			if ritual.is_empty() or ritual.base.changes.prayer != "PRAYER_05" or not ritual.tag in ["ritual_witness", "public_ritual"] or public_record.is_empty() or not public_record.public or not _received(state, ritual, institution, index) or not _received(state, public_record, institution, index) or not _witness(state, ritual, basis.priest, index) or not _witness(state, public_record, basis.priest, index): return "orthodox_ritual_or_public_witness_missing"
		"network_evidence":
			if not basis.other_institution is String or not _connected(state, institution, basis.other_institution) or not _strings(basis.records, 2) or not _strings(basis.witnesses, 2): return "communicating_independent_network_missing"
			var family: String = ""; var origins: Dictionary = {}
			for position: int in 2:
				var office: String = institution if position == 0 else basis.other_institution
				var source: Dictionary = _evidence_record(state, basis.records[position], index, true)
				var person: String = basis.witnesses[position]
				if not person in result.targets or not _alive(state, person, index) or not _received(state, source, office, index) or not _record_witness(state, source, person, index): return "network_record_or_actual_witness_missing"
				if family.is_empty(): family = source.family
				if source.family != family or origins.has(source.base.id): return "network_record_not_independent_same_kind"
				origins[source.base.id] = true
		"contract_dependency":
			return _contract_condition(state, institution, result, index)
		"axiom_exception":
			if not basis.exception is String or not _current(state, basis.exception, index) or _fact(state, basis.exception, index).kind != "exception" or not basis.other_institution is String or not _connected(state, institution, basis.other_institution) or not _strings(basis.records, 2): return "communicating_exception_records_missing"
			if not independent_exception_records(state, basis.records[0], basis.records[1], index): return "exception_observations_not_independent"
			var origins: Dictionary = {}
			for position: int in 2:
				var office: String = institution if position == 0 else basis.other_institution
				var source: Dictionary = _evidence_record(state, basis.records[position], index)
				if source.is_empty() or source.base.changes.get("facts", {}).get("exception") != basis.exception or not _received(state, source, office, index) or origins.has(source.base.id): return "exception_record_not_real_independent_or_current"
				origins[source.base.id] = true
		_: return "unknown_blueprint_condition"
	return ""

static func _contract_condition(state: Dictionary, institution: String, result: Dictionary, index: RefCounted = null) -> String:
	var basis: Dictionary = result.changes.basis
	if not basis.contract is String or not basis.dependency is String or not _strings(basis.witnesses, 2): return "contract_original_graph_missing"
	var contract: Dictionary = _fact(state, basis.contract, index)
	if contract.get("kind") != "contract_obligation" or contract.changes.get("institution") != institution or not contract.changes.get("obligor") is String or not contract.changes.get("counterparty") is String: return "contract_original_obligation_mismatch"
	var dependency: Dictionary = _prayer_record(state, basis.dependency, index)
	if dependency.is_empty() or dependency.tag != "contract_dependency" or dependency.base.changes.prayer != "PRAYER_06" or dependency.base.changes.facts.get("contract") != basis.contract or not _received(state, dependency, institution, index): return "current_contract_dependency_missing"
	var parties: Array = [contract.changes.obligor, contract.changes.counterparty]
	for person: String in parties:
		if not person in result.targets: return "contract_parties_not_bound"
	var found: Dictionary = {}
	for id: String in basis.witnesses:
		var source: Dictionary = _prayer_record(state, id, index)
		if source.is_empty() or not source.tag in ["contract_fulfilled", "contract_witness", "contract_learned", "hostile_witness"] or source.base.changes.prayer != "PRAYER_06" or source.base.changes.facts.get("contract") != basis.contract or source.base.changes.request != dependency.base.changes.request or not _received(state, source, institution, index): return "contract_end_witness_missing"
		for person: String in parties:
			if person in source.base.targets and _witness(state, source, person, index): found[person] = true
	if found.size() != parties.size(): return "contract_two_ends_not_witnessed"
	if _alive(state, contract.changes.obligor, index): return ""
	if not basis.get("successor") is String: return "living_contract_obligor_or_fixed_successor_missing"
	return "" if _successor(state, basis.successor, contract, result, index) else "contract_successor_not_actually_continued"

static func _successor(state: Dictionary, source: String, contract: Dictionary, result: Dictionary, index: RefCounted = null) -> bool:
	var auth: Dictionary = _fact(state, source, index)
	if auth.get("kind") != "contract_successor_authorized" or not _current(state, source, index) or auth.domain != contract.domain: return false
	var data: Dictionary = auth.changes
	if not _shape(data, ["issuer", "version", "contract", "obligor", "successor", "fixed", "relation"]) or not state.anchor_system.issuers.has(data.get("issuer", "")) or state.anchor_system.issuers[data.issuer] != data.get("version") or data.get("contract") != contract.id or data.get("obligor") != contract.changes.obligor or not data.get("successor") is String or data.successor == data.obligor or _npc(state, data.successor, index).get("status") != "active" or _npc(state, data.successor, index).get("domain") != contract.domain or data.successor == contract.changes.counterparty or not data.successor in result.targets: return false
	if not data.get("fixed") is String or not data.get("relation") is String or not data.fixed in auth.causal_parents or not data.relation in auth.causal_parents or not _current(state, data.fixed, index) or not _current(state, data.relation, index) or not data.obligor in auth.targets or not data.successor in auth.targets: return false
	var fixed: Dictionary = _fact(state, data.fixed, index)
	var relation: Dictionary = _fact(state, data.relation, index)
	var death: Dictionary = _fact(state, str(_npc(state, data.obligor, index).get("status_source", "")), index)
	if fixed.get("kind") != "contract_inheritance_fixed" or not _shape(fixed.changes, ["issuer", "version", "contract", "obligor", "successor", "relation"]) or not state.anchor_system.issuers.has(fixed.changes.get("issuer", "")) or state.anchor_system.issuers[fixed.changes.issuer] != fixed.changes.get("version") or fixed.changes.contract != data.contract or fixed.changes.obligor != data.obligor or fixed.changes.successor != data.successor or fixed.changes.relation != data.relation or not data.contract in fixed.causal_parents or not data.relation in fixed.causal_parents or not data.obligor in fixed.targets or not data.successor in fixed.targets: return false
	if death.get("kind") != "status_change" or death.changes.get("to") != "dead" or fixed.turn < death.turn or (fixed.turn == death.turn and fixed.id <= death.id) or not death.id in fixed.causal_parents or not relation.kind in ["relationship", "initial_relationship"] or not data.obligor in ([relation.actor] + relation.targets) or not data.successor in ([relation.actor] + relation.targets): return false
	if index == null or not index.has_method("relation"): return false
	var actual: Dictionary = index.relation(data.obligor, data.successor, data.relation)
	if actual.is_empty(): actual = index.relation(data.successor, data.obligor, data.relation)
	if actual.get("kind", actual.get("type")) not in ["family", "support", "cooperation"] or actual.get("kind", actual.get("type")) != relation.changes.get("kind", relation.changes.get("type")): return false
	if not _knows(state, data.successor, data.contract, index): return false
	for parent: String in auth.causal_parents:
		var outcome: Dictionary = _fact(state, parent, index)
		if outcome.get("kind") != "event_result" or outcome.changes.get("content_id") != "EVENT_05" or outcome.changes.get("option") != "B" or _authorization(state, "event/resolved/" + str(outcome.changes.get("event", "")), index) != outcome.id: continue
		var original: Dictionary = outcome.changes.get("descriptor", {})
		if original.get("facts", {}).get("contract") == data.contract and original.get("facts", {}).get("inheritance") == data.fixed and original.get("subjects", {}).get("successor") == data.successor and _knows(state, data.successor, str(original.get("facts", {}).get("dependency", "")), index): return true
	return false

static func valid_restriction(state: Dictionary, source: String, _content: RefCounted) -> bool:
	if not state.get("anchor_system") is Dictionary or not state.anchor_system.get("issuers") is Dictionary or not state.get("facts") is Dictionary or not state.get("institutions") is Dictionary or not Store.has(state.facts, source): return false
	var fact: Dictionary = Store.entry(state.facts, source)
	if fact.get("kind") != "institution_restriction" or not fact.get("changes") is Dictionary or not fact.get("causal_parents") is Array or not fact.get("targets") is Array: return false
	var data: Dictionary = fact.changes
	if not _shape(data, ["issuer", "version", "institution", "reason"]) or not state.anchor_system.get("issuers", {}).has(data.get("issuer", "")) or state.anchor_system.issuers[data.issuer] != data.get("version") or not data.get("reason") in ["blocked", "denied"] or not state.institutions.has(data.get("institution", "")) or not data.institution in fact.targets or fact.domain != state.institutions[data.institution].domain: return false
	for parent: String in fact.causal_parents:
		var cause: Dictionary = _fact(state, parent)
		if cause.get("kind") != "institution_event_result" or cause.domain != fact.domain or cause.changes.get("institution") != data.institution or not data.institution in cause.get("targets", []): continue
		var event: Dictionary = cause.changes
		if not _shape(event, ["issuer", "version", "event", "option", "institution", "basis"]) or not event.basis is Dictionary or not state.anchor_system.issuers.has(event.get("issuer", "")) or state.anchor_system.issuers[event.issuer] != event.get("version"): continue
		var effect: Dictionary = _content.tables.get("anchor_restrictions", {}).get(str(event.get("event")) + "/" + str(event.get("option")), {})
		if not effect.is_empty() and effect.reason == data.reason: return true
	return false

static func refresh_restriction_heads(world: RefCounted) -> void:
	if not world.state.has("anchor_system") or world.history == null: return
	world.stage_collections(["anchor_system"])
	world.state.anchor_system.restrictions = {} if world.state.anchor_system.get("schema") == SCHEMA else _restriction_heads(world.state, world.history)

static func observe(world: RefCounted, source: String, owner: Object = null) -> bool:
	if not world.state.has("anchor_system"): return true
	if world.state.anchor_system.get("schema") == SCHEMA and _fact(world.state, source).get("kind") != "anchor_basis": return true # Old approval never issues material basis or relics.
	if not world._driver_allowed(owner) or world.transaction == null: return false
	var fact: Dictionary = _fact(world.state, source)
	if fact.get("kind") == "institution_restriction":
		if valid_restriction(world.state, source, world.catalog) and not _invalid(world.state, source):
			world.history.add_institution_restriction(world.state, source); refresh_restriction_heads(world)
		return true
	if not fact.get("kind") in ["anchor_basis", "institution_event_result"] or not fact.changes.get("institution") is String: return true
	var institution: String = fact.changes.institution
	var permission: Dictionary = qualify(world.state, institution, source, world.catalog, world.history)
	if not permission.get("allowed", false): return true
	var key: String = "anchor/recognition/" + institution
	if Store.has(world.state.applied_authorizations, key): return true
	world.stage_collections(["anchor_system", "applied_authorizations"])
	var recognition: String = world._record("institution_recognized", fact.domain, "", [institution], [source], {"institution": institution, "proof": source, "profile": world.state.domains[fact.domain].profile, "contract": fact.changes.duplicate(true)})
	Store.put(world.state.applied_authorizations, key, recognition)
	var pool: PackedStringArray = str(world.catalog.tables.civilization_conditions[world.state.domains[fact.domain].profile].relic_pool).split("|")
	if pool.is_empty(): return false
	var selected: String = pool[world.randoms.events.randi_range(0, pool.size() - 1)]
	var opportunity: String = world._record("institution_relic_opportunity", fact.domain, "", [institution], [recognition, source], {"institution": institution, "recognition": recognition, "proof": source, "relic_type": selected, "created_turn": world.state.turn, "due": world.state.turn + world.catalog.integer("relic_opportunity_lifetime") - 1})
	world.state.anchor_system.opportunities[institution] = opportunity
	return true

static func bind(world: RefCounted, anchor_id: String, proof: Dictionary, source: String, owner: Object = null) -> bool:
	if not world._driver_allowed(owner) or world.transaction == null or not world.state.has("anchor_system") or not world.state.anchors.has(anchor_id) or not proof.get("source") is String: return false
	var anchor: Dictionary = world.state.anchors[anchor_id]
	var permission: Dictionary = qualify(world.state, anchor.institution, proof.source, world.catalog, world.history)
	if not permission.get("allowed", false) or not observe(world, proof.source, owner): return false
	world.stage_collections(["anchor_system"])
	var binding: String = world._record("anchor_institution_bound", anchor.domain, anchor.guardian, [anchor_id, anchor.institution], [source, proof.source], {"anchor": anchor_id, "institution": anchor.institution, "proof": proof.source, "contract": _fact(world.state, proof.source).changes.duplicate(true)})
	world.state.anchor_system.proofs[anchor.institution] = proof.source
	world.state.anchor_system.bindings[anchor_id] = {"proof": proof.source, "source": binding, "route": permission.route}
	world.state.anchors[anchor_id]["route"] = permission.route
	return true

static func expire(world: RefCounted, owner: Object = null) -> bool:
	if not world.state.has("anchor_system"): return true
	if not world._driver_allowed(owner) or world.transaction == null: return false
	world.stage_collections(["anchor_system", "applied_authorizations"])
	var ids: Array = world.state.anchor_system.opportunities.keys(); ids.sort()
	for institution: String in ids:
		var opportunity: String = str(world.state.anchor_system.opportunities[institution])
		var fact: Dictionary = _fact(world.state, opportunity)
		if fact.is_empty(): return false
		var key: String = "anchor/opportunity/" + opportunity
		if Store.has(world.state.applied_authorizations, key): world.state.anchor_system.opportunities.erase(institution); continue
		if fact.changes.due > world.state.turn: continue
		var expired: String = world._record("institution_relic_expired", fact.domain, "", [institution], [opportunity], {"opportunity": opportunity, "institution": institution, "due": fact.changes.due})
		Store.put(world.state.applied_authorizations, key, expired)
		world.state.anchor_system.opportunities.erase(institution)
	return true

static func _new_facts(state: Dictionary, trusted: Dictionary) -> Array:
	if trusted.is_empty(): return Store.values(state.facts)
	var result: Array = []
	if Store.overlay(state.facts):
		for id: String in Store.changed(state.facts): result.append(Store.entry(state.facts, id))
	elif not is_same(state.facts, trusted.facts):
		for change: Dictionary in History.changed_entries(state.facts, trusted.facts):
			if Store.has(state.facts, str(change.get("key", ""))): result.append(Store.entry(state.facts, change.key))
	return result

static func _binding_valid(state: Dictionary, id: String, binding: Dictionary, content: RefCounted) -> bool:
	if not _shape(binding, ["proof", "source"], ["route"]) or not binding.proof is String or not binding.source is String or not Store.has(state.facts, binding.proof) or not Store.has(state.facts, binding.source) or not state.anchors.has(id): return false
	var fact: Dictionary = Store.entry(state.facts, binding.source)
	var anchor: Dictionary = state.anchors[id]
	var original: Dictionary = Store.entry(state.facts, binding.proof)
	var contract_ok: bool = _basis_contract(state, anchor.institution, original, content) if original.get("kind") == "anchor_basis" else _result_contract(state, anchor.institution, original, content)
	if not contract_ok or fact.changes.get("contract") != original.changes: return false
	if original.get("kind") == "anchor_basis" and (binding.get("route") != original.changes.basis.route or anchor.get("route") != binding.get("route")): return false
	if fact.get("kind") != "anchor_institution_bound" or fact.changes.get("anchor") != id or fact.changes.get("institution") != anchor.institution or fact.changes.get("proof") != binding.proof or not binding.proof in fact.causal_parents or not anchor.get("established_source", "") in fact.causal_parents or not anchor.institution in fact.targets: return false
	var check: Dictionary = _fact(state, str(anchor.get("established_source", "")))
	if check.get("kind") != "turn_check" or not check.changes.get("outcome") in ["deep", "success"]: return false
	for parent: String in check.causal_parents:
		var attempt: Dictionary = _fact(state, parent)
		if attempt.get("kind") == "power_attempt" and attempt.changes.get("power") == "POWER_ANCHOR" and attempt.changes.get("payload", {}).get("institution") == anchor.institution and attempt.changes.get("proofs", {}).get("anchor", {}).get("source") == binding.proof:
			var snapshot: Dictionary = attempt.changes.proofs.anchor
			return snapshot.get("issuer") == original.changes.issuer and snapshot.get("version") == original.changes.version and snapshot.get("basis") == original.changes.basis and snapshot.get("institution") == anchor.institution
	return false

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, history: RefCounted = null) -> Array[String]:
	if state.get("anchor_system", {}).get("schema") == SCHEMA: return _validate_routes_state(state, content, trusted, history)
	if not state.has("anchor_system"):
		if trusted.has("anchor_system"): return ["Formal anchor capability disappeared"]
		return []
	for collection: String in ["facts", "npcs", "domains", "institutions", "anchors", "applied_authorizations", "invalid_records"]:
		if not state.get(collection) is Dictionary: return ["Missing anchor audit collection"]
	var ledger: Variant = state.anchor_system
	if not ledger is Dictionary or not _shape(ledger, ["schema", "version", "issuers", "proofs", "bindings", "restrictions", "opportunities"]) or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content): return ["Invalid formal anchor schema or content version"]
	for field: String in ["issuers", "proofs", "bindings", "restrictions", "opportunities"]:
		if not ledger[field] is Dictionary: return ["Invalid formal anchor current ledger"]
	for key: Variant in ledger.issuers:
		if not key is String or key.is_empty() or not ledger.issuers[key] is String or str(ledger.issuers[key]).is_empty(): return ["Invalid institution result issuer capability"]
	if trusted.has("anchor_system") and (trusted.anchor_system.version != ledger.version or trusted.anchor_system.issuers != ledger.issuers): return ["Installed institution rule capability changed"]
	var current: RefCounted = history
	if current == null:
		var native: Dictionary = History.export_value(state)
		current = History.new(); current.configure(content.tables.npc_behaviors, valid_restriction.bind(content)); current.rebuild(native)
	var expected_heads: Dictionary = _restriction_heads(state, current)
	if ledger.restrictions != expected_heads: return ["Current institution restrictions omitted or invented a valid source"]
	for institution: String in ledger.proofs:
		if not state.institutions.has(institution) or not ledger.proofs[institution] is String: return ["Invalid formal institution proof head"]
		var source: Dictionary = _fact(state, ledger.proofs[institution])
		var row: Dictionary = _row(state, institution, content)
		if not _result_contract(state, institution, source, content) or row.is_empty(): return ["Institution proof head lost its original event contract"]
		var required: Array = BASIS.get(row.rule, []).duplicate(); var optional: Array = []
		if row.rule == "contract_dependency": required.erase("successor"); optional = ["successor"]
		if not _shape(source.changes, ["issuer", "version", "event", "option", "institution", "basis"]) or not _shape(source.changes.basis, required, optional): return ["Institution proof changed its finite contract"]
	for id: String in ledger.bindings:
		if not ledger.bindings[id] is Dictionary or not _binding_valid(state, id, ledger.bindings[id], content): return ["Anchor binding lost its real successful power and institution source"]
		var institution: String = state.anchors[id].institution
		if ledger.proofs.get(institution) != ledger.bindings[id].proof: return ["Anchor maintenance switched to an unrelated institution proof"]
	for id: String in state.anchors:
		var anchor: Dictionary = state.anchors[id]
		if anchor.get("state") == "active":
			if not ledger.bindings.has(id): return ["Unqualified legacy anchor cannot stay active after formal installation"]
			var permission: Dictionary = maintenance(state, anchor.institution, content, current)
			if not permission.get("allowed", false): return ["Active anchor no longer meets its current institution conditions"]
	for institution: String in ledger.opportunities:
		var id: Variant = ledger.opportunities[institution]
		if not state.institutions.has(institution) or not id is String or not Store.has(state.facts, id) or Store.has(state.applied_authorizations, "anchor/opportunity/" + id): return ["Invalid current institution relic opportunity"]
		var opportunity: Dictionary = Store.entry(state.facts, id)
		if opportunity.get("kind") != "institution_relic_opportunity" or opportunity.changes.get("institution") != institution: return ["Institution opportunity was reassigned"]
	var expected_bindings: Dictionary = {}; var opportunities: Dictionary = {}; var recognitions: Dictionary = {}; var seen_recognitions: Dictionary = {}
	var facts: Array = _new_facts(state, trusted); facts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for fact: Dictionary in facts:
		if fact.get("kind") == "anchor_institution_bound": expected_bindings[str(fact.changes.get("anchor", ""))] = fact.id
		if fact.get("kind") == "institution_recognized":
			var institution: Variant = fact.changes.get("institution")
			if not institution is String or seen_recognitions.has(institution) or not state.institutions.has(institution) or not fact.changes.get("proof") is String or not fact.changes.proof in fact.causal_parents or _authorization(state, "anchor/recognition/" + institution) != fact.id: return ["Institution recognition lost its permanent unique source"]
			var original: Dictionary = _fact(state, fact.changes.proof)
			if not _result_contract(state, institution, original, content) or fact.changes.get("contract") != original.changes: return ["First recognition changed its original institution contract"]
			seen_recognitions[institution] = true; recognitions[fact.id] = institution
		if fact.get("kind") == "institution_relic_opportunity":
			var data: Dictionary = fact.changes
			if not _shape(data, ["institution", "recognition", "proof", "relic_type", "created_turn", "due"]) or not data.institution is String or not state.institutions.has(data.institution) or not data.recognition is String or not Store.has(state.facts, data.recognition) or not data.proof is String or not Store.has(state.facts, data.proof) or not data.created_turn is int or data.created_turn != fact.turn or not data.due is int or data.due != fact.turn + content.integer("relic_opportunity_lifetime") - 1 or not data.recognition in fact.causal_parents or not data.proof in fact.causal_parents: return ["Relic opportunity changed its source or original deadline"]
			var recognized: Dictionary = Store.entry(state.facts, data.recognition)
			var proof: Dictionary = Store.entry(state.facts, data.proof)
			if recognized.get("kind") != "institution_recognized" or recognized.changes.get("institution") != data.institution or recognized.changes.get("proof") != data.proof or proof.get("kind") != "institution_event_result" or proof.changes.get("institution") != data.institution or _authorization(state, "anchor/recognition/" + data.institution) != data.recognition: return ["Relic opportunity has no original institution recognition"]
			var profile: String = str(state.domains[state.institutions[data.institution].domain].profile)
			if not data.relic_type is String or not data.relic_type in str(content.tables.civilization_conditions[profile].relic_pool).split("|") or opportunities.has(data.institution): return ["Institution relic type is outside its fixed pool or duplicated"]
			opportunities[data.institution] = fact.id
		if fact.get("kind") == "institution_relic_expired":
			var id: String = str(fact.changes.get("opportunity", ""))
			var opportunity: Dictionary = _fact(state, id)
			if opportunity.get("kind") != "institution_relic_opportunity" or fact.turn != opportunity.changes.due or not id in fact.causal_parents or _authorization(state, "anchor/opportunity/" + id) != fact.id: return ["Expired institution opportunity changed original due or unique consumption"]
	for id: String in expected_bindings:
		if ledger.bindings.get(id, {}).get("source") != expected_bindings[id]: return ["Current anchor binding omitted its newest actual commitment"]
	for recognition: String in recognitions:
		if not opportunities.has(recognitions[recognition]): return ["First institution recognition lost its unique relic opportunity"]
	for institution: String in opportunities:
		var id: String = opportunities[institution]
		if _authorization(state, "anchor/opportunity/" + id).is_empty() and ledger.opportunities.get(institution) != id: return ["Unused institution relic opportunity disappeared"]
	return []

static func valid_recheck(state: Dictionary, result_id: String, institution: String, source: String, content: RefCounted, index: RefCounted = null) -> bool:
	if not state.get("anchor_system") is Dictionary or not _current(state, result_id, index): return false
	var result: Dictionary = _fact(state, result_id, index)
	if result.get("kind") != "institution_event_result" or not _knows(state, institution, result_id, index, true) or not state.institutions.has(institution) or result.domain != state.institutions[institution].domain or not institution in result.targets: return false
	var data: Dictionary = result.changes
	if not _shape(data, ["issuer", "version", "event", "option", "institution", "basis"]) or data.get("institution") != institution or not data.get("basis") is Dictionary or not state.anchor_system.issuers.has(data.get("issuer", "")) or state.anchor_system.issuers[data.issuer] != data.get("version") or not content.tables.get("event_effects", {}).has(str(data.get("event")) + "/" + str(data.get("option"))): return false
	var row: Dictionary = _row(state, institution, content)
	if row.is_empty(): return false
	return _result_contract(state, institution, result, content, index) and source in result.causal_parents and source in _basis_sources(row.rule, data.basis)

## Historical contract validation deliberately excludes present life, custody,
## knowledge revocation and office eligibility. Those belong to qualify().
static func _result_contract(state: Dictionary, institution: String, fact: Dictionary, content: RefCounted, index: RefCounted = null) -> bool:
	var row: Dictionary = _row(state, institution, content)
	if row.is_empty() or not BASIS.has(row.get("rule", "")) or fact.get("kind") != "institution_event_result" or fact.get("domain") != state.institutions[institution].domain or not institution in fact.get("targets", []) or not fact.get("changes") is Dictionary: return false
	var data: Dictionary = fact.changes
	if not _shape(data, ["issuer", "version", "event", "option", "institution", "basis"]) or not state.anchor_system.issuers.has(data.get("issuer", "")) or state.anchor_system.issuers[data.issuer] != data.get("version") or data.get("institution") != institution or data.get("event") != row.event_id or not data.get("option") in (["A", "B"] if row.event_option == "*" else [row.event_option]) or not content.tables.event_effects.has(str(data.event) + "/" + str(data.option)) or not data.basis is Dictionary: return false
	var required: Array = BASIS[row.rule].duplicate(); var optional: Array = []
	if row.rule == "contract_dependency": required.erase("successor"); optional = ["successor"]
	if not _shape(data.basis, required, optional): return false
	var basis: Dictionary = data.basis
	var count: int = content.integer(row.count_parameter) if not row.count_parameter.is_empty() else -1
	match str(row.rule):
		"dual_testimony":
			if not _strings(basis.records, count) or not _strings(basis.witnesses, count): return false
		"calendar_ritual":
			if not _strings(basis.rituals, count) or not basis.priest is String: return false
		"shared_memory", "collective_dissent":
			if not basis.memory is String or not _strings(basis.witnesses, count) or not _strings(basis.qualifications, count): return false
		"orthodox_witness":
			if not basis.ritual is String or not basis.public is String or not basis.priest is String: return false
		"network_evidence":
			if not basis.other_institution is String or not _strings(basis.records, 2) or not _strings(basis.witnesses, 2): return false
		"contract_dependency":
			if not basis.contract is String or not basis.dependency is String or not _strings(basis.witnesses, 2) or (basis.has("successor") and not basis.successor is String): return false
		"axiom_exception":
			if not basis.exception is String or not basis.other_institution is String or not _strings(basis.records, 2): return false
	var sources: Array = _basis_sources(row.rule, basis)
	if sources.is_empty(): return false
	for source: String in sources:
		if not source in fact.causal_parents or _fact(state, source, index).is_empty(): return false
	return true

static func _restriction_heads(state: Dictionary, index: RefCounted) -> Dictionary:
	var heads: Dictionary = {}
	for institution: String in state.institutions:
		var proof_id: Variant = state.anchor_system.proofs.get(institution, "")
		var proof: Dictionary = _fact(state, proof_id) if proof_id is String else {}
		var changes: Variant = proof.get("changes", {})
		var stored_basis: Variant = changes.get("basis", {}) if changes is Dictionary else {}
		# Restore checks the full proof contract below. A malformed basis must
		# produce a normal rejection there, not a type error in this projection.
		var basis: Dictionary = stored_basis if stored_basis is Dictionary else {}
		var source: String = _current_restriction(state, institution, basis, index)
		if not source.is_empty(): heads[institution] = source
	return heads

static func _current_restriction(state: Dictionary, institution: String, basis: Dictionary, index: RefCounted = null) -> String:
	if index == null or not index.has_method("institution_restriction"): return str(state.get("anchor_system", {}).get("restrictions", {}).get(institution, ""))
	var source: String = str(index.institution_restriction(institution))
	if not source.is_empty(): return source
	if not basis.get("priest") is String or not index.has_method("institution_ritual_restriction"): return ""
	var rituals: Variant = basis.get("rituals", [basis.get("ritual", "")])
	if not rituals is Array: return ""
	for ritual: Variant in rituals:
		if not ritual is String or ritual.is_empty(): continue
		var after: String = str(index.institution_ritual_clear(institution, basis.priest, ritual))
		var restricted: String = str(index.institution_ritual_restriction(institution, basis.priest, ritual, after))
		if not restricted.is_empty(): return restricted
	return ""

## Only actual, already installed Prayers/Powers producers are resolved here.
## Later route producers must add their real adapter; a kind name alone is never
## accepted as a successful progression result.
static func material(state: Dictionary, id: String, content: RefCounted, index: RefCounted = null, historical: bool = false, depth: int = 0) -> Dictionary:
	if depth > 8: return {}
	var fact: Dictionary = _fact(state, id, index)
	if fact.is_empty(): return {}
	var current: bool = _current(state, id, index)
	if not historical and not current: return {}
	var data: Dictionary = fact.get("changes", {})
	if fact.kind == "material_received":
		if data.get("schema") != 2 or data.get("issuer") != "material_reception" or data.get("version") != content.material_transfer_version() or not data.get("source") is String or not data.source in fact.causal_parents: return {}
		var received: Dictionary = material(state, data.source, content, index, historical, depth + 1)
		if received.is_empty(): return {}
		received.id = id; received.current = received.current and current
		if not id in received.knowledge: received.knowledge.append(id)
		return received
	var normalized: Dictionary = {"id": id, "canonical": id, "kind": "", "root": id, "turn": int(fact.turn), "institution": str(data.get("institution", "")), "owners": [], "originals": [], "knowledge": [id], "current": current, "data": {}, "causes": []}
	if fact.kind == "route_material":
		if data.get("issuer") != "progression_routes" or data.get("version") != state.get("progression_routes", {}).get("version") or not data.get("tag") is String or not data.get("originals") is Array or not data.get("data") is Dictionary: return {}
		normalized.kind = data.tag; normalized.originals = data.originals.duplicate(); normalized.owners = data.originals.duplicate(); normalized.data = data.data.duplicate(true); normalized.causes = data.get("dependencies", []).duplicate()
		for parent: String in normalized.causes:
			if not _current(state, parent, index): normalized.current = false
			var original: Dictionary = material(state, parent, content, index, true, depth + 1)
			if not original.is_empty() and not original.current: normalized.current = false
		if data.tag == "performed_rite": normalized.kind = "ritual"
		if data.tag == "axiom_record":
			normalized.kind = "exception_record"; normalized.root = str(data.data.exception) + "/" + str(data.data.observer) + "/" + normalized.institution
		return _received_owners(state, normalized, content, index)
	if fact.kind == "exception": normalized.kind = "exception"; return normalized
	if fact.kind == "shared_observation":
		normalized.kind = "shared_memory"; normalized.owners = data.get("participants", []).duplicate(); normalized.originals = normalized.owners.duplicate(); normalized.data = {"host": fact.actor}; return normalized
	if fact.kind == "memory_at_risk" and data.get("scene_rule") == "ROOT_MEMORY_REVIEW":
		normalized.kind = "memory_review"; normalized.data = {"memory": data.get("memory", ""), "holders": data.get("holders", [])}; return normalized
	if fact.kind == "contract_obligation":
		normalized.kind = "contract"; normalized.data = {"parties": [data.get("obligor", ""), data.get("counterparty", "")], "term": data.get("term", "")}; return normalized
	if fact.kind == "contract_successor_authorized":
		var contract: Dictionary = _fact(state, str(data.get("contract", "")), index)
		if contract.is_empty() or not _successor(state, id, contract, {"targets": fact.targets}, index): return {}
		normalized.kind = "contract_successor"; normalized.data = {"contract": contract.id, "obligor": data.obligor, "successor": data.successor}; normalized.owners = [data.successor]; normalized.originals = [data.successor]; return normalized
	var source: Dictionary = _prayer_record(state, id, index, not historical)
	if source.is_empty():
		source = _dream_record(state, id, index, not historical)
		if source.is_empty(): return {}
		normalized.current = current and _current(state, source.base.id, index)
		normalized.kind = "dream"; normalized.canonical = source.base.id; normalized.root = source.base.id; normalized.turn = source.base.turn; normalized.institution = source.institution
		normalized.originals = source.base.changes.get("witnesses", []).duplicate(); normalized.owners = normalized.originals.duplicate()
		normalized.knowledge = [id, source.base.id]; normalized.causes = [source.base.id]
		return _received_owners(state, normalized, content, index)
	var base: Dictionary = source.base
	normalized.current = current and _current(state, base.id, index)
	var facts: Dictionary = base.changes.facts
	var petitioner: String = str(base.changes.subjects.get("petitioner", ""))
	var response: String = _authorization(state, "prayer/response/" + base.changes.request, index)
	normalized.institution = source.institution; normalized.turn = base.turn; normalized.root = base.id; normalized.canonical = base.id
	normalized.knowledge = [id, base.id]
	if not response.is_empty() and base.id in _fact(state, response, index).get("changes", {}).get("produced", {}).values(): normalized.knowledge.append(response)
	normalized.causes = [base.id]
	var persons: Array = []; var added_holders: Array = []
	for person: String in base.targets:
		if not _npc(state, person, index).is_empty(): persons.append(person)
	if source.tag in ["private_testimony", "anomaly_record", "public_witness", "public_evidence"]:
		normalized.kind = "evidence"; normalized.root = str(facts.get("record", facts.get("conflict", base.id)))
		if normalized.root != base.id:
			normalized.causes.append(normalized.root)
			var original: Dictionary = material(state, normalized.root, content, index, true, depth + 1)
			if not original.is_empty() and original.kind in ["evidence", "dream"]: normalized.root = original.root; normalized.canonical = original.get("canonical", original.id); normalized.turn = original.turn; normalized.current = normalized.current and original.current
		if not petitioner in persons: persons.append(petitioner)
	elif source.tag in ["ritual_witness", "public_ritual"] and base.changes.prayer == "PRAYER_05":
		normalized.kind = "ritual"; normalized.root = str(facts.get("ritual", base.id)); normalized.data = {"priest": petitioner}; persons = [petitioner]
	elif source.tag in ["exception_record", "exception_learned", "public_exception_qualification"]:
		var observed: Dictionary = exception_observation(state, id, index)
		if observed.is_empty(): return {}
		normalized.kind = "exception_record"; normalized.root = str(observed.exception) + "/" + str(observed.observer) + "/" + str(observed.node)
		normalized.institution = observed.node; normalized.data = {"exception": observed.exception, "observation": observed.id, "observer": observed.observer}; persons = [observed.observer]
		normalized.causes.append_array([observed.exception, observed.id])
	elif source.tag in ["memory_preserved", "memory_conflict"] and base.changes.prayer == "PRAYER_07":
		var review: String = str(base.changes.get("original", facts.get("memory", "")))
		var risk: Dictionary = _fact(state, review, index)
		if risk.get("kind") != "memory_at_risk" or risk.changes.get("scene_rule") != "ROOT_MEMORY_REVIEW": return {}
		var memory: String = str(risk.changes.get("memory", ""))
		normalized.kind = "memory_qualification" if source.tag == "memory_preserved" else "memory_conflict"; normalized.data = {"memory": memory, "review": review}
		if normalized.kind == "memory_qualification":
			if persons.size() != 1 or not persons[0] in risk.changes.get("holders", []) or _authorization(state, "prayer/memory/" + review + "/" + str(persons[0]), index) != base.id: return {}
			normalized.data["person"] = persons[0]
			normalized.current = normalized.current and _authorization(state, "prayer/memory_lost/" + review + "/" + str(persons[0]), index).is_empty()
		normalized.causes.append_array([memory, review])
	elif source.tag in ["contract_dependency", "contract_fulfilled", "contract_witness", "contract_learned", "hostile_witness"] and base.changes.prayer == "PRAYER_06":
		var contract: String = str(facts.get("contract", ""))
		var obligation: Dictionary = _fact(state, contract, index)
		if obligation.get("kind") != "contract_obligation": return {}
		normalized.kind = "contract_dependency" if source.tag == "contract_dependency" else "contract_witness"
		normalized.data = {"contract": contract, "performance": base.changes.request, "term": obligation.changes.get("term", ""), "origin": "prayer"}
		if normalized.kind == "contract_dependency":
			persons = [obligation.changes.obligor]
			if index != null and index.has_method("anchor_successors"):
				for successor_id: String in index.anchor_successors(contract):
					var successor: Dictionary = material(state, successor_id, content, index)
					if not successor.is_empty() and _knows(state, successor.data.successor, id, index): added_holders.append(successor.data.successor)
		normalized.causes.append(contract)
		if obligation.changes.get("route_operation") == "ROUTE_PACT_AGREEMENT":
			var held: Dictionary = material(state, str(obligation.changes.get("record", "")), content, index, true, depth + 1)
			if held.is_empty() or not held.current: normalized.current = false
			if not held.is_empty(): normalized.causes.append(held.id)
	else: return {}
	normalized.originals = persons; normalized.owners = persons.duplicate() + added_holders
	return _received_owners(state, normalized, content, index)

static func _received_owners(state: Dictionary, material: Dictionary, content: RefCounted, index: RefCounted = null) -> Dictionary:
	var canonical: String = str(material.get("canonical", material.id))
	var receipts: Array = []
	if index != null and index.has_method("material_receipts"): receipts = index.material_receipts(canonical)
	else:
		for id: String in Store.keys(state.get("facts", {})):
			var fact: Dictionary = Store.entry(state.facts, id)
			if fact.get("kind") == "material_received" and fact.get("changes", {}).get("source") == canonical: receipts.append(id)
	for id: String in receipts:
		var receipt: Dictionary = _fact(state, id, index)
		var data: Dictionary = receipt.get("changes", {})
		if not _current(state, id, index) or data.get("schema") != 2 or data.get("issuer") != "material_reception" or data.get("version") != content.material_transfer_version() or data.get("source") != canonical or data.get("grant") != "custody": continue
		var row: Dictionary = content.tables.material_transfer_families.get(data.get("family", ""), {})
		if row.get("custody") != "1" or not data.get("recipient") is String: continue
		if not data.recipient in material.owners: material.owners.append(data.recipient)
		if not canonical in material.knowledge: material.knowledge.append(canonical)
		if not id in material.causes: material.causes.append(id)
	return material

static func _basis_materials(state: Dictionary, basis: Dictionary, content: RefCounted, index: RefCounted = null) -> Dictionary:
	var materials: Dictionary = {}
	for value: Variant in basis.values():
		for id: Variant in (value if value is Array else [value]):
			if not id is String or _fact(state, id, index).is_empty(): continue
			var item: Dictionary = material(state, id, content, index, true)
			if not item.is_empty(): materials[id] = item
	var queue: Array = materials.keys(); var visited: Dictionary = {}
	while not queue.is_empty():
		var id: String = queue.pop_back()
		if visited.has(id): continue
		visited[id] = true
		for cause: String in materials[id].get("causes", []):
			if materials.has(cause): continue
			var item: Dictionary = material(state, cause, content, index, true)
			if not item.is_empty(): materials[cause] = item; queue.append(cause)
	return materials

static func evaluate(state: Dictionary, institution: String, basis: Dictionary, content: RefCounted, index: RefCounted = null, purpose: String = "anchor", actor: String = "") -> Dictionary:
	return Routes.evaluate_normalized(state, institution, basis, _basis_materials(state, basis, content, index), content, index, purpose, actor)

static func _basis_contract(state: Dictionary, institution: String, fact: Dictionary, content: RefCounted, index: RefCounted = null) -> bool:
	if fact.get("kind") != "anchor_basis" or not state.get("institutions", {}).has(institution) or fact.domain != state.institutions[institution].domain or not institution in fact.targets: return false
	var data: Dictionary = fact.get("changes", {})
	if not _shape(data, ["issuer", "version", "institution", "profile", "rule", "basis"]) or data.get("issuer") != ID or data.get("version") != rule_version(content) or data.get("institution") != institution or not data.get("basis") is Dictionary: return false
	var row: Dictionary = content.tables.get("anchor_route_rules", {}).get(data.basis.get("route", ""), {})
	if row.is_empty() or data.profile != row.profile or data.rule != row.rule or state.domains[fact.domain].profile != row.profile or not data.basis.get("carriers") is Array: return false
	for carrier: Variant in data.basis.carriers:
		if not carrier is Dictionary or not _shape(carrier, ["institution", "person", "sources"]) or not carrier.institution in fact.targets or not carrier.person in fact.targets or not _strings(carrier.sources): return false
		for source: String in carrier.sources:
			if not source in fact.causal_parents: return false
	for field: String in Routes.fields(row):
		if not data.basis.has(field): return false
		for id: Variant in (data.basis[field] if data.basis[field] is Array else [data.basis[field]]):
			if id is String and not _fact(state, id, index).is_empty() and not id in fact.causal_parents: return false
	return true

static func available(state: Dictionary, institution: String, content: RefCounted, index: RefCounted = null, purpose: String = "anchor", actor: String = "") -> Array:
	var result: Array = []
	var routes: Dictionary = state.get("anchor_system", {}).get("routes", {}).get(institution, {})
	var names: Array = routes.keys(); names.sort()
	for route: String in names:
		var permission: Dictionary = qualify(state, institution, str(routes[route]), content, index, purpose, actor)
		if permission.get("allowed", false): result.append(permission)
	if purpose == "spread":
		var seen: Dictionary = {}
		for entry: Dictionary in result: seen[entry.route] = true
		for basis: Dictionary in _candidate_bases(state, institution, content, index):
			var permission: Dictionary = evaluate(state, institution, basis, content, index, purpose, actor)
			if permission.get("allowed", false) and not seen.has(permission.route):
				permission["source"] = "" # read-only actual materials; CULT-SPREAD issues its own capability later
				result.append(permission); seen[permission.route] = true
	return result

static func discover(state: Dictionary, institution: String, content: RefCounted, index: RefCounted = null, purpose: String = "anchor", actor: String = "") -> Dictionary:
	if not state.get("institutions", {}).has(institution): return {"ok": false, "error": "Unknown actual institution slot"}
	var missing: Array = []
	var profile: String = state.domains[state.institutions[institution].domain].profile
	for row: Dictionary in content.tables.anchor_route_rules.values():
		if not state.has("progression_routes") and row.profile == profile and row.selector in ["operator_dependency", "pair_dependency", "ritual_practice", "network_exchange", "contract_reciprocal"]: missing.append(row.id)
	missing.sort()
	return {"ok": true, "candidates": available(state, institution, content, index, purpose, actor), "missing_producer": missing}

## Candidate discovery uses bounded current material heads, not a facts scan.
static func _candidate_bases(state: Dictionary, institution: String, content: RefCounted, index: RefCounted, exact_sources: Array = []) -> Array:
	var result: Array = []
	var domain: String = state.institutions[institution].domain
	for basis: Dictionary in state.get("progression_routes", {}).get("bases", {}).get(institution, {}).values(): result.append(basis.duplicate(true))
	var items: Array = []; var source_ids: Array = exact_sources.duplicate()
	for id: String in state.get("progression_routes", {}).get("materials", []):
		if not id in source_ids: source_ids.append(id)
	if index != null and index.has_method("anchor_material_heads"):
		for id: String in index.anchor_material_heads(domain, content.integer("collective_required_witnesses")):
			if not id in source_ids: source_ids.append(id)
	for id: String in source_ids:
		var item: Dictionary = material(state, id, content, index, true)
		if not item.is_empty(): items.append(item)
	var profile: String = state.domains[domain].profile
	var local: Array = items.filter(func(x: Dictionary) -> bool: return x.institution == institution)
	if profile in ["CIV_01", "CIV_05", "CIV_07"]:
		for a: Dictionary in items:
			for b: Dictionary in items:
				if a.id >= b.id: continue
				if profile == "CIV_01" and a.kind in ["evidence", "dream"] and b.kind in ["evidence", "dream"]:
					for first: String in a.originals:
						for second: String in b.originals: result.append({"route": "record_testimonies", "records": [a.id, b.id], "witnesses": [first, second]})
				elif profile == "CIV_05" and a.kind in ["evidence", "dream"] and b.kind == a.kind:
					var first: Dictionary = a if a.institution == institution else b
					var second: Dictionary = b if first.id == a.id else a
					for one: String in first.originals:
						for two: String in second.originals: result.append({"route": "network_independent", "other_institution": second.institution, "records": [first.id, second.id], "witnesses": [one, two]})
				elif profile == "CIV_07" and a.kind == "exception_record" and b.kind == "exception_record":
					var first: Dictionary = a if a.institution == institution else b
					var second: Dictionary = b if first.id == a.id else a
					result.append({"route": "axiom_nodes", "exception": first.data.exception, "other_institution": second.institution, "records": [first.id, second.id]})
	elif profile in ["CIV_02", "CIV_04"]:
		for a: Dictionary in local:
			if a.kind != "ritual": continue
			if profile == "CIV_04": result.append({"route": "ritual_keeper", "ritual": a.id, "priest": a.data.priest})
			else:
				for b: Dictionary in local:
					if b.kind == "ritual" and a.id < b.id: result.append({"route": "calendar_rites", "rituals": [a.id, b.id], "priest": a.data.priest})
	elif profile in ["CIV_03", "CIV_08"]:
		var groups: Dictionary = {}
		for item: Dictionary in items:
			if item.kind != "memory_qualification": continue
			var review: String = item.data.review
			if not groups.has(review): groups[review] = []
			groups[review].append(item)
		for review: String in groups:
			var witnesses: Array = []; var qualifications: Array = []; var conflicts: Array = []
			groups[review].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.data.person) < str(b.data.person))
			for qualification: Dictionary in groups[review]:
				if qualification.data.person in witnesses: continue
				witnesses.append(qualification.data.person); qualifications.append(qualification.id)
				for conflict: Dictionary in items:
					if conflict.kind == "memory_conflict" and conflict.data.review == review and qualification.data.person in conflict.originals: conflicts.append(conflict.id); break
			var basis: Dictionary = {"route": "memory_circle" if profile == "CIV_03" else "dissent_circle", "memory": groups[review][0].data.memory, "review": review, "witnesses": witnesses, "qualifications": qualifications}
			if profile == "CIV_08": basis["conflicts"] = conflicts
			result.append(basis)
	elif profile == "CIV_06":
		for dependency: Dictionary in items:
			if dependency.kind != "contract_dependency": continue
			var witnesses: Array = []
			for item: Dictionary in items:
				if item.kind == "contract_witness" and item.data.get("contract") == dependency.data.contract and item.data.get("performance") == dependency.data.performance: witnesses.append(item.id)
			for a: int in witnesses.size():
				for b: int in range(a + 1, witnesses.size()):
					var basis: Dictionary = {"route": "contract_performance", "contract": dependency.data.contract, "dependency": dependency.id, "witnesses": [witnesses[a], witnesses[b]]}
					result.append(basis)
					for successor: Dictionary in items:
						if successor.kind == "contract_successor" and successor.data.contract == dependency.data.contract:
							var continued: Dictionary = basis.duplicate(true); continued["successor"] = successor.id; result.append(continued)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a, "", true, true) < JSON.stringify(b, "", true, true))
	return result

## The owner calls this once at the publication boundary, after actual effects
## and knowledge changes. Pure previews never invoke it.
static func refresh_basis(world: RefCounted, owner: Object = null, exact_sources: Array = []) -> bool:
	if not world.state.has("anchor_system"): return true
	if not world._driver_allowed(owner) or world.transaction == null or world.state.anchor_system.get("schema") != SCHEMA: return false
	world.stage_collections(["anchor_system"])
	var routes: Dictionary = {}; var preferred: Dictionary = {}
	var offices: Array = world.state.institutions.keys(); offices.sort()
	for institution: String in offices:
		var candidates: Array = []
		var prior: Dictionary = world.state.anchor_system.routes.get(institution, {})
		for source: String in prior.values():
			var existing: Dictionary = _fact(world.state, source, world.history)
			if not existing.is_empty(): candidates.append(existing.changes.basis)
		candidates.append_array(_candidate_bases(world.state, institution, world.catalog, world.history, exact_sources))
		var chosen: Dictionary = {}
		for basis: Dictionary in candidates:
			var permission: Dictionary = evaluate(world.state, institution, basis, world.catalog, world.history)
			if not permission.get("allowed", false) or chosen.has(permission.route): continue
			var previous: String = str(prior.get(permission.route, ""))
			if previous.is_empty() and world.history.has_method("anchor_basis_source"): previous = world.history.anchor_basis_source(institution, permission.basis)
			var original: Dictionary = _fact(world.state, previous, world.history)
			if original.get("changes", {}).get("basis") != permission.basis:
				var historical: String = world.history.anchor_basis_source(institution, permission.basis)
				if not historical.is_empty(): previous = historical; original = _fact(world.state, previous, world.history)
			var id: String = previous
			if original.get("changes", {}).get("basis") != permission.basis or not _current(world.state, previous, world.history):
				var targets: Array = [institution] + permission.originals
				for carrier: Dictionary in permission.basis.carriers: targets.append_array([carrier.institution, carrier.person])
				id = world._record("anchor_basis", world.state.institutions[institution].domain, "", targets, permission.dependencies, {"issuer": ID, "version": rule_version(world.catalog), "institution": institution, "profile": permission.profile, "rule": permission.rule, "basis": permission.basis})
			chosen[permission.route] = id
		if chosen.is_empty(): continue
		routes[institution] = chosen
		var ordered: Array = chosen.keys(); ordered.sort()
		var bound: String = ""
		for anchor: Dictionary in world.state.anchors.values():
			if anchor.institution == institution: bound = str(anchor.get("route", "")); break
		preferred[institution] = chosen[bound] if chosen.has(bound) else chosen[ordered[0]]
	world.state.anchor_system.routes = routes; world.state.anchor_system.proofs = preferred
	for institution: String in preferred:
		if not observe(world, preferred[institution], owner): return false
	return true

static func _validate_routes_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, index: RefCounted = null) -> Array[String]:
	var ledger: Dictionary = state.anchor_system
	if not _shape(ledger, ["schema", "version", "issuers", "proofs", "routes", "bindings", "restrictions", "opportunities"]) or ledger.version != rule_version(content): return ["Incompatible current material dependency policy"]
	for field: String in ["issuers", "proofs", "routes", "bindings", "restrictions", "opportunities"]:
		if not ledger.get(field) is Dictionary: return ["Invalid current anchor material ledger"]
	for issuer: Variant in ledger.issuers:
		if not issuer is String or issuer.is_empty() or not ledger.issuers[issuer] is String or str(ledger.issuers[issuer]).is_empty(): return ["Invalid accepted material capability"]
	if trusted.has("anchor_system") and (ledger.version != trusted.anchor_system.version or ledger.issuers != trusted.anchor_system.issuers): return ["Installed material dependency capability changed"]
	if not ledger.restrictions.is_empty(): return ["Official-denial restrictions do not grant or block material dependencies"]
	var opportunity_errors: Array[String] = _validate_opportunities(state, content, trusted)
	if not opportunity_errors.is_empty(): return opportunity_errors
	if index == null:
		var native: Dictionary = History.export_value(state)
		index = History.new(); index.configure(content.tables.npc_behaviors, valid_restriction.bind(content)); index.rebuild(native)
	var new_facts: Array = _new_facts(state, trusted)
	for fact: Dictionary in new_facts:
		if fact.get("kind") != "anchor_basis": continue
		var institution: String = str(fact.changes.get("institution", ""))
		if not _basis_contract(state, institution, fact, content, index): return ["Invalid original anchor material basis contract"]
		var permission: Dictionary = qualify(state, institution, fact.id, content, index)
		if permission.get("allowed", false) and not ledger.routes.get(institution, {}).has(permission.route): return ["Current material route head disappeared"]
	if ledger.proofs.size() != ledger.routes.size(): return ["Preferred and per-route material heads disagree"]
	for institution: String in ledger.routes:
		if not state.institutions.has(institution) or not ledger.routes[institution] is Dictionary or ledger.routes[institution].is_empty(): return ["Invalid material basis target"]
		for route: String in ledger.routes[institution]:
			var source: Variant = ledger.routes[institution][route]
			if not source is String: return ["Invalid material basis source"]
			var permission: Dictionary = qualify(state, institution, source, content, index)
			if not permission.get("allowed", false) or permission.route != route: return ["Current basis outlived its actual materials or carriers"]
	for institution: String in ledger.proofs:
		if not ledger.routes.get(institution, {}).values().has(ledger.proofs[institution]): return ["Preferred basis is not a current route source"]
	for id: String in ledger.bindings:
		var binding: Variant = ledger.bindings[id]
		if not binding is Dictionary or not _shape(binding, ["proof", "source", "route"]) or not _binding_valid(state, id, binding, content): return ["Anchor binding has no actual paid, successful material commitment"]
	for anchor: Dictionary in state.anchors.values():
		if anchor.state == "active" and (not ledger.bindings.has(anchor.id) or not maintenance(state, anchor.institution, content, index).get("allowed", false)): return ["Active anchor lost its bound current material route"]
	return []

## Permanent discovery identity survives current material loss. Only its first
## issuance requires qualification; disposal keeps the original due/type/source.
static func _opportunity_contract(state: Dictionary, fact: Dictionary, content: RefCounted) -> bool:
	var data: Dictionary = fact.get("changes", {})
	if fact.get("kind") != "institution_relic_opportunity" or not _shape(data, ["institution", "recognition", "proof", "relic_type", "created_turn", "due"]): return false
	if not data.institution is String or not state.institutions.has(data.institution) or not data.recognition is String or not data.proof is String or not data.created_turn is int or not data.due is int: return false
	if fact.domain != state.institutions[data.institution].domain or fact.targets != [data.institution] or data.created_turn != fact.turn or data.due != fact.turn + content.integer("relic_opportunity_lifetime") - 1 or fact.causal_parents != [data.proof, data.recognition]: return false
	var recognized: Dictionary = _fact(state, data.recognition)
	var original: Dictionary = _fact(state, data.proof)
	if not _discovery_contract(state, recognized, content) or recognized.changes.proof != data.proof or recognized.changes.institution != data.institution: return false
	var profile: String = str(original.changes.profile)
	return data.relic_type is String and data.relic_type in str(content.tables.civilization_conditions[profile].relic_pool).split("|")

static func _discovery_contract(state: Dictionary, fact: Dictionary, content: RefCounted) -> bool:
	var data: Dictionary = fact.get("changes", {})
	if fact.get("kind") != "institution_recognized" or not _shape(data, ["institution", "proof", "profile", "contract"]) or not data.institution is String or not data.proof is String: return false
	var original: Dictionary = _fact(state, data.proof)
	return _basis_contract(state, data.institution, original, content) and fact.domain == original.domain and fact.turn >= original.turn and fact.targets == [data.institution] and fact.causal_parents == [data.proof] and data.profile == original.changes.profile and data.contract == original.changes and _authorization(state, "anchor/recognition/" + data.institution) == fact.id

static func _validate_opportunities(state: Dictionary, content: RefCounted, trusted: Dictionary) -> Array[String]:
	var ledger: Dictionary = state.anchor_system
	var discoveries: Dictionary = {}; var opportunities: Dictionary = {}
	for fact: Dictionary in _new_facts(state, trusted):
		if fact.get("kind") == "institution_recognized":
			var institution: String = str(fact.changes.get("institution", ""))
			if not _discovery_contract(state, fact, content) or discoveries.has(institution) or (not trusted.is_empty() and not _authorization(trusted, "anchor/recognition/" + institution).is_empty()): return ["First material discovery lost its permanent institution identity"]
			discoveries[institution] = fact.id
		elif fact.get("kind") == "institution_relic_opportunity":
			var institution: String = str(fact.changes.get("institution", ""))
			if not _opportunity_contract(state, fact, content) or opportunities.has(institution) or (not trusted.is_empty() and not _authorization(trusted, "anchor/recognition/" + institution).is_empty()): return ["Material relic opportunity changed source, pool, deadline or unique slot"]
			opportunities[institution] = fact.id
		elif fact.get("kind") == "institution_relic_expired":
			var source: String = str(fact.changes.get("opportunity", ""))
			var original: Dictionary = _fact(state, source)
			if not _opportunity_contract(state, original, content) or fact.turn != original.changes.due or fact.changes.get("due") != original.changes.due or fact.changes.get("institution") != original.changes.institution or fact.causal_parents != [source] or _authorization(state, "anchor/opportunity/" + source) != fact.id: return ["Expired material opportunity changed original consumption or deadline"]
	for fact: Dictionary in _new_facts(state, trusted):
		if not fact.get("kind") in ["institution_relic_recover", "institution_relic_public", "institution_relic_expired"]: continue
		var source: String = str(fact.changes.get("opportunity", ""))
		if _authorization(state, "anchor/opportunity/" + source) != fact.id or not _opportunity_consumption(state, source, fact.id): return ["Material relic disposal lost its unique original opportunity"]
	for institution: String in discoveries:
		if not opportunities.has(institution): return ["First material discovery omitted its unique relic opportunity"]
	for institution: String in opportunities:
		var source: String = opportunities[institution]
		var consumed: String = _authorization(state, "anchor/opportunity/" + source)
		if consumed.is_empty():
			if ledger.opportunities.get(institution) != source: return ["Unused material opportunity disappeared"]
		elif not _opportunity_consumption(state, source, consumed): return ["Material opportunity consumption has no matching actual disposal"]
	for institution: String in ledger.opportunities:
		var source: Variant = ledger.opportunities[institution]
		if not source is String or not _opportunity_contract(state, _fact(state, source), content) or _fact(state, source).changes.institution != institution or not _authorization(state, "anchor/opportunity/" + source).is_empty(): return ["Invalid current material relic opportunity"]
	return []

static func _opportunity_consumption(state: Dictionary, source: String, consumed: String) -> bool:
	var opportunity: Dictionary = _fact(state, source)
	var fact: Dictionary = _fact(state, consumed)
	if opportunity.get("kind") != "institution_relic_opportunity" or not fact.get("kind") in ["institution_relic_recover", "institution_relic_public", "institution_relic_expired"] or fact.changes.get("opportunity") != source or fact.changes.get("institution") != opportunity.changes.institution or fact.domain != opportunity.domain or not source in fact.causal_parents: return false
	if fact.kind == "institution_relic_expired": return fact.turn == opportunity.changes.due and fact.changes.get("due") == opportunity.changes.due
	return fact.turn >= opportunity.turn and fact.turn <= opportunity.changes.due and fact.changes.get("relic_type") == opportunity.changes.relic_type
