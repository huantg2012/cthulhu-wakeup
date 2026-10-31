extends RefCounted
## Finite, source-bound event eligibility. No random numbers or world writes.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Anchors = preload("res://src/game/anchors.gd")

static func fact(state: Dictionary, id: String, index: RefCounted = null) -> Dictionary:
	if Store.has(state.get("facts", {}), id): return Store.entry(state.facts, id)
	if index != null and index.has_method("fact"):
		var result: Dictionary = index.fact(id)
		if result.ok: return result.item
	return {}

static func person(state: Dictionary, id: String, index: RefCounted = null) -> Dictionary:
	if Store.has(state.get("npcs", {}), id): return Store.entry(state.npcs, id)
	if index != null and index.has_method("entity"):
		var result: Dictionary = index.entity("npcs", id)
		if result.ok: return result.item
	return {}

static func current(state: Dictionary, id: String, index: RefCounted = null) -> bool:
	return not fact(state, id, index).is_empty() and not (index.invalidated(id) if index != null and index.has_method("invalidated") else Store.has(state.get("invalid_records", {}), id))

static func alive(state: Dictionary, id: String, index: RefCounted = null, active: bool = false) -> bool:
	var npc: Dictionary = person(state, id, index)
	return not npc.is_empty() and (npc.status == "active" if active else npc.status != "dead")

static func roots(value: Variant) -> Array:
	var result: Array = []
	if value is Dictionary:
		for item: Variant in value.values():
			for id: String in roots(item):
				if not id in result: result.append(id)
	elif value is Array:
		for item: Variant in value:
			for id: String in roots(item):
				if not id in result: result.append(id)
	elif value is String and value.begins_with("FACT-"): result.append(value)
	return result

static func auth(state: Dictionary, key: String, index: RefCounted = null) -> String:
	if index != null and index.has_method("authorization"):
		var result: Dictionary = index.authorization(key)
		return str(result.source) if result.ok and result.used else ""
	return str(Store.entry(state.get("applied_authorizations", {}), key, ""))

static func actual_prayer(state: Dictionary, source: String, index: RefCounted = null) -> Dictionary:
	return Anchors._prayer_record(state, source, index, false)

static func descriptor(state: Dictionary, source: String, content: RefCounted, index: RefCounted = null) -> Dictionary:
	var original: Dictionary = fact(state, source, index)
	if original.is_empty(): return {}
	if original.kind == "resistance_started":
		var domain: Dictionary = state.domains.get(original.domain, {})
		var plan: Dictionary = domain.get("pending_plan", {})
		if plan.get("started_fact") != source: return {}
		if plan.get("rule") == "RESIST_REWRITE": return _base(state, "EVENT_11", source, plan.institution, [], {}, {"plan": source, "record": plan.target}, content, int(plan.due))
		if plan.get("rule") == "RESIST_TRACE" and Store.has(state.relics, plan.target):
			var relic: Dictionary = Store.entry(state.relics, plan.target)
			var exposure: String = ""
			for id: String in plan.parents:
				if fact(state, id, index).get("kind") == "exposure": exposure = id; break
			if exposure.is_empty(): return {}
			var actors: Array = [relic.holder] if relic.placement == "carried" else []
			return _base(state, "EVENT_08", source, plan.institution, actors, {"relic": relic.id}, {"exposure": exposure, "investigation": source}, content, int(plan.due))
		return {}
	if original.kind == "prayer_window_due":
		if original.changes.get("answered", true) or not original.changes.get("descriptor") is Dictionary: return {}
		var prior: Dictionary = original.changes.descriptor
		var registered: String = str(original.changes.get("registration", ""))
		if registered.is_empty():
			for parent: String in original.causal_parents:
				if fact(state, parent, index).get("kind") == "prayer_registered": registered = parent; break
		if registered.is_empty(): return {}
		var result: Dictionary = _base(state, "EVENT_12", source, prior.institution, prior.actors, {"petitioner": prior.subjects.petitioner}, {"registration": registered, "expiry": source, "situation": prior.source}, content)
		result["prayer_descriptor"] = prior.duplicate(true)
		return result
	if original.kind == "miracle" and original.changes.get("power") == "POWER_DREAM":
		var dream: Dictionary = Anchors._dream_record(state, source, index)
		if dream.is_empty() or not state.institutions.has(dream.institution): return {}
		return _base(state, "EVENT_02", source, dream.institution, [dream.base.actor], {"witnesses": [dream.base.actor]}, {"records": [source]}, content)
	if original.kind != "prayer_fact" or original.changes.get("tag") != "future_callback" or not content.tables.events.has(original.changes.get("event", "")): return {}
	var proven: Dictionary = actual_prayer(state, source, index)
	if proven.is_empty(): return {}
	var prior: Dictionary = proven.attempt.changes.descriptor
	var response_id: String = auth(state, "prayer/response/" + prior.get("request", original.changes.request), index)
	var response: Dictionary = fact(state, response_id, index)
	if response.get("kind") != "prayer_result" or not response.changes.get("outcome") in ["deep", "success"]: return {}
	var produced: Dictionary = response.changes.produced
	var subjects: Dictionary = prior.subjects
	var causes: Dictionary = prior.facts
	var event: String = original.changes.event
	var people: Array = prior.actors.duplicate()
	var fixed: Dictionary = {}; var facts: Dictionary = {"callback": source}
	match event:
		"EVENT_01":
			fixed = {"survivor": subjects.relative}; facts["miracle"] = str(produced.get("miracle_witness", produced.get("condition_cured", "")))
		"EVENT_02":
			var records: Array = []
			for tag: String in ["private_testimony", "public_witness", "anomaly_record", "public_evidence"]:
				if produced.has(tag): records.append(produced[tag])
			if records.is_empty(): return {}
			fixed = {"witnesses": [subjects.petitioner]}; facts["records"] = records
		"EVENT_03":
			if not produced.has("support_withdrawn"): return {}
			facts["vacancy"] = produced.support_withdrawn; facts["relations"] = []; people = []
		"EVENT_04":
			fixed = {"priest": subjects.petitioner}; facts["rituals"] = [produced.get("ritual_witness", produced.get("public_ritual", ""))]
			if produced.has("public_ritual"): facts["public"] = produced.public_ritual
		"EVENT_05":
			if not produced.has("contract_dependency"): return {}
			fixed = {"obligor": subjects.petitioner, "counterparty": subjects.counterparty}
			facts.merge({"contract": causes.contract, "dependency": produced.contract_dependency, "witnesses": [produced.get("contract_fulfilled", ""), produced.get("contract_learned", "")]})
		"EVENT_06":
			var memory_root: Dictionary = fact(state, causes.memory, index)
			var qualifications: Array = []
			for id: String in subjects.memory_people:
				var qualification: String = auth(state, "prayer/memory/" + causes.memory + "/" + id, index)
				if not qualification.is_empty(): qualifications.append(qualification)
			if qualifications.is_empty(): return {}
			fixed = {"witnesses": subjects.memory_people.duplicate()}; facts.merge({"memory": memory_root.changes.memory, "qualifications": qualifications})
		"EVENT_07":
			if not produced.has("public_prophet"): return {}
			fixed = {"prophet": subjects.petitioner}; facts["prophet"] = produced.public_prophet
		"EVENT_08":
			# An escape route alone is not a movable medium or investigation.
			return {}
		"EVENT_09":
			fixed = {"cooperator": subjects.petitioner, "opponent": subjects.opponent, "cooperating_institution": prior.institution}
			facts.merge({"conflict": causes.conflict, "relation": causes.relation})
		"EVENT_10":
			if not produced.has("relic_recovery_opportunity"): return {}
			var opportunity: Dictionary = fact(state, produced.relic_recovery_opportunity, index)
			fixed = {"relic": subjects.relic}; facts.merge({"claim": produced.relic_recovery_opportunity, "custody": opportunity.changes.status_source})
		"EVENT_11": return {} # Only a real foretold rewrite plan is actionable.
		_: return {}
	var result: Dictionary = _base(state, event, source, prior.institution, people, fixed, facts, content)
	result["prayer_descriptor"] = prior.duplicate(true)
	return result

static func _base(state: Dictionary, event: String, source: String, institution: String, actors: Array, subjects: Dictionary, facts: Dictionary, content: RefCounted, explicit_due: int = -1) -> Dictionary:
	var original: Dictionary = fact(state, source)
	var row: Dictionary = content.tables.events[event]
	var visible: int = maxi(int(original.turn) + int(row.min_age), int(original.turn) + 1)
	var due: int = int(original.turn) + int(row.max_age) if explicit_due < 0 else explicit_due
	var object: String = str(subjects.get("relic", subjects.get("survivor", subjects.get("prophet", subjects.get("petitioner", institution)))))
	return {"content_id": event, "domain": original.domain, "institution": institution, "actors": actors.duplicate(), "subjects": subjects.duplicate(true), "facts": facts.duplicate(true), "source": source, "source_ids": roots(facts) + ([] if source in roots(facts) else [source]), "visible_turn": visible, "due_turn": due, "once_key": "event/source/" + event + "/" + source, "mutex": str(row.scope) + "/" + object, "priority": int(row.priority), "default_action": str(row.default_result).trim_prefix("option:")}

static func legal(state: Dictionary, descriptor: Dictionary, option: String, content: RefCounted, index: RefCounted = null) -> Dictionary:
	if not option in ["A", "B"] or not content.tables.events.has(descriptor.get("content_id", "")): return {"ok": false, "error": "Unknown event option"}
	var domain: String = str(descriptor.get("domain", "")); var institution: String = str(descriptor.get("institution", ""))
	if not state.domains.has(domain) or not state.institutions.has(institution) or not state.institutions[institution].active: return {"ok": false, "error": "Event institution is unavailable"}
	var subjects: Dictionary = descriptor.subjects; var facts: Dictionary = descriptor.facts
	var allowed: bool = true
	match str(descriptor.content_id):
		"EVENT_01": allowed = alive(state, subjects.get("survivor", ""), index)
		"EVENT_02":
			allowed = not facts.get("records", []).is_empty()
			var secret: bool = false
			for id: String in facts.get("records", []):
				var record: Dictionary = Anchors._evidence_record(state, id, index, true)
				allowed = allowed and current(state, id, index) and not record.is_empty()
				if not record.is_empty() and not record.public and not (index.event_record_public(id) if index != null and index.has_method("event_record_public") else false): secret = true
			if option == "A": allowed = allowed and secret
		"EVENT_03":
			allowed = state.institutions[institution].representative == ""
			if option == "A":
				allowed = allowed and successor_legal(state, str(subjects.get("cooperator", "")), institution, content, index) and related_any(state, facts.get("relations", []), str(subjects.get("former", "")), str(subjects.get("cooperator", "")), ["support", "cooperation"], index)
		"EVENT_04":
			if option == "A": allowed = Anchors._priest(state, subjects.get("priest", ""), institution, index) and not facts.get("rituals", []).is_empty()
		"EVENT_05":
			allowed = current(state, facts.get("dependency", ""), index) and fact(state, facts.get("contract", ""), index).get("kind") == "contract_obligation"
			if option == "B": allowed = allowed and (alive(state, subjects.get("obligor", ""), index) or (subjects.has("successor") and not inheritance(state, str(facts.get("inheritance", "")), str(facts.get("contract", "")), index).is_empty()))
		"EVENT_06":
			allowed = false
			for id: String in subjects.get("witnesses", []): allowed = allowed or alive(state, id, index)
			if option == "B":
				var found: bool = false
				for id: String in facts.get("qualifications", []): found = found or current(state, id, index)
				allowed = allowed and found
		"EVENT_07":
			allowed = current(state, facts.get("prophet", ""), index) and (alive(state, subjects.get("prophet", ""), index) or (subjects.has("successor") and not will(state, str(facts.get("will", "")), str(subjects.get("prophet", "")), str(facts.get("prophet", "")), index).is_empty()))
		"EVENT_08":
			var relic: Dictionary = Store.entry(state.relics, subjects.get("relic", ""), {})
			allowed = not relic.is_empty() and relic.domain == domain and not relic.placement in ["consumed", "sealed", "seized"]
			var plan: Dictionary = state.domains[domain].pending_plan
			allowed = allowed and plan.get("started_fact") == facts.get("investigation") and plan.get("target") == relic.get("id")
			if option == "A": allowed = allowed and relic.placement in ["bound", "carried"] and not cult(state, domain).is_empty()
		"EVENT_09":
			allowed = current(state, facts.get("conflict", ""), index)
			if option == "A": allowed = allowed and alive(state, subjects.get("cooperator", ""), index, true) and alive(state, subjects.get("opponent", ""), index) and state.institutions.has(subjects.get("cooperating_institution", ""))
		"EVENT_10":
			var relic: Dictionary = Store.entry(state.relics, subjects.get("relic", ""), {})
			if relic.is_empty() and index != null and index.has_method("entity"):
				var found: Dictionary = index.entity("relics", str(subjects.get("relic", "")))
				if found.ok: relic = found.item
			var claim: Dictionary = fact(state, facts.get("claim", ""), index)
			allowed = not relic.is_empty() and relic.placement == "seized" and relic.status_source == facts.get("custody") and relic.captor == claim.changes.get("captor") and relic.domain == domain
			if option == "A": allowed = allowed and not cult(state, domain).is_empty()
		"EVENT_11":
			var plan: Dictionary = state.domains[domain].pending_plan
			allowed = plan.get("started_fact") == facts.get("plan") and plan.get("rule") == "RESIST_REWRITE" and plan.get("target") == facts.get("record") and current(state, facts.get("record", ""), index)
		"EVENT_12":
			allowed = alive(state, subjects.get("petitioner", ""), index)
			if option == "B":
				var prior: Dictionary = descriptor.get("prayer_descriptor", {})
				allowed = allowed and not prior.is_empty() and current(state, prior.get("source", ""), index)
				if not prior.get("crisis", {}).is_empty(): allowed = allowed and current(state, prior.crisis.source, index) and int(state.turn) <= int(prior.crisis.due)
		_: allowed = false
	return {"ok": allowed, "error": "Fixed event option no longer qualifies" if not allowed else ""}

static func cult(state: Dictionary, domain: String) -> String:
	var ids: Array = state.get("cults", {}).keys(); ids.sort()
	for id: String in ids:
		if state.cults[id].domain == domain and state.cults[id].status != "destroyed": return id
	return ""

static func proof_basis(state: Dictionary, descriptor: Dictionary, content: RefCounted, index: RefCounted = null) -> Dictionary:
	var institution: String = descriptor.institution
	var row: Dictionary = Anchors._row(state, institution, content)
	if row.is_empty() or row.event_id != descriptor.content_id: return {}
	var facts: Dictionary = descriptor.facts; var subjects: Dictionary = descriptor.subjects
	match str(row.rule):
		"dual_testimony":
			if facts.get("records", []).size() >= content.integer(row.count_parameter) and subjects.get("witnesses", []).size() >= content.integer(row.count_parameter): return {"records": facts.records.slice(0, content.integer(row.count_parameter)), "witnesses": subjects.witnesses.slice(0, content.integer(row.count_parameter))}
		"calendar_ritual":
			if facts.get("rituals", []).size() >= content.integer(row.count_parameter): return {"rituals": facts.rituals.slice(0, content.integer(row.count_parameter)), "priest": subjects.get("priest", "")}
		"shared_memory", "collective_dissent":
			if facts.get("qualifications", []).size() == content.integer(row.count_parameter) and subjects.get("witnesses", []).size() == content.integer(row.count_parameter): return {"memory": facts.memory, "witnesses": subjects.witnesses.duplicate(), "qualifications": facts.qualifications.duplicate()}
		"orthodox_witness":
			if not facts.get("rituals", []).is_empty() and facts.has("public"): return {"ritual": facts.rituals[0], "public": facts.public, "priest": subjects.get("priest", "")}
		"network_evidence":
			if subjects.has("other_institution") and facts.get("records", []).size() >= 2 and subjects.get("witnesses", []).size() >= 2: return {"other_institution": subjects.other_institution, "records": facts.records.slice(0, 2), "witnesses": subjects.witnesses.slice(0, 2)}
		"contract_dependency":
			return {"contract": facts.contract, "dependency": facts.dependency, "witnesses": facts.witnesses.duplicate()}
		"axiom_exception":
			if facts.has("exception") and subjects.has("other_institution") and facts.get("records", []).size() >= 2: return {"exception": facts.exception, "other_institution": subjects.other_institution, "records": facts.records.slice(0, 2)}
	return {}

static func propagation_sources(state: Dictionary, domain: String, index: RefCounted = null) -> Array:
	var bonus: int = 0; var selected: String = ""
	var ids: Array = state.get("event_system", {}).get("prophets", {}).keys(); ids.sort()
	for id: String in ids:
		var entry: Dictionary = state.event_system.prophets[id]
		var npc: Dictionary = person(state, id, index)
		if entry.domain != domain or npc.is_empty() or npc.status != "active" or not npc.get("bound_member", false) or npc.get("cult_id", "") != entry.cult or npc.get("binding_source", "") != entry.binding_source or not current(state, entry.prophet, index): continue
		if int(entry.bonus) > bonus:
			bonus = int(entry.bonus); selected = entry.source
	return [] if selected.is_empty() else [selected]

static func propagation_bonus(state: Dictionary, domain: String, index: RefCounted = null) -> int:
	var sources: Array = propagation_sources(state, domain, index)
	if sources.is_empty(): return 0
	for entry: Dictionary in state.event_system.prophets.values():
		if entry.source == sources[0]: return int(entry.bonus)
	return 0

class RecognitionView extends RefCounted:
	var state: Dictionary
	var base: RefCounted
	var deliveries: Dictionary = {}
	func _init(current_state: Dictionary, index: RefCounted) -> void:
		state = current_state; base = index
	func fact(id: String) -> Dictionary:
		if Store.has(state.get("facts", {}), id): return {"ok": true, "item": Store.entry(state.facts, id)}
		return base.fact(id) if base != null and base.has_method("fact") else {"ok": false}
	func entity(collection: String, id: String) -> Dictionary:
		if Store.has(state.get(collection, {}), id): return {"ok": true, "item": Store.entry(state[collection], id)}
		return base.entity(collection, id) if base != null and base.has_method("entity") else {"ok": false}
	func knows(owner: String, source: String, institution: bool = false) -> bool:
		if institution and deliveries.has(owner + "/" + source): return true
		if base != null:
			return base.knows(owner, source, institution) if base.has_method("fact") else base.knows(state, owner, source, institution)
		var item: Dictionary = state.get("institutions", {}).get(owner, {}) if institution else Store.entry(state.get("npcs", {}), owner, {})
		return History.has(item.get("known_facts", []), source)
	func invalidated(source: String) -> bool:
		return base.invalidated(source) if base != null and base.has_method("invalidated") else Store.has(state.get("invalid_records", {}), source)
	func authorization(key: String) -> Dictionary:
		if base != null and base.has_method("authorization"): return base.authorization(key)
		return {"ok": true, "used": Store.has(state.get("applied_authorizations", {}), key), "source": str(Store.entry(state.get("applied_authorizations", {}), key, ""))}
	func relation(first: String, second: String, source: String) -> Dictionary:
		return base.relation(first, second, source) if base != null else {}

static func prospective_recognition(state: Dictionary, descriptor: Dictionary, content: RefCounted, index: RefCounted = null, strict_only: bool = true) -> Dictionary:
	var row: Dictionary = Anchors._row(state, descriptor.institution, content)
	if row.is_empty() or row.event_id != descriptor.content_id or (strict_only and not descriptor.content_id in ["EVENT_02", "EVENT_04"]): return {"ok": true}
	var basis: Dictionary = descriptor.get("basis", {})
	if basis.is_empty(): return {"ok": false, "error": "Institution recognition lacks its full fixed blueprint evidence"}
	var proxy: RefCounted = RecognitionView.new(state, index)
	for source: String in Anchors._basis_sources(row.rule, basis):
		var recipient: String = descriptor.institution
		if row.rule in ["network_evidence", "axiom_exception"] and source == basis.records[1]: recipient = basis.other_institution
		if proxy.knows(recipient, source, true): continue
		for actor: String in descriptor.actors:
			var npc: Dictionary = person(state, actor, index)
			if npc.is_empty() or npc.status != "active" or npc.domain != descriptor.domain or not proxy.knows(actor, source): continue
			if npc.institution != recipient and not Anchors._connected(state, npc.institution, recipient): continue
			proxy.deliveries[recipient + "/" + source] = true; break
	var targets: Array = [descriptor.institution] + descriptor.actors
	if row.rule == "contract_dependency":
		for id: String in [descriptor.subjects.obligor, descriptor.subjects.counterparty]:
			if not id in targets: targets.append(id)
	var expected: Dictionary = {"changes": {"basis": basis}, "targets": targets}
	var reason: String = Anchors._check_basis(state, descriptor.institution, expected, row, content, proxy)
	return {"ok": reason.is_empty(), "error": reason}

static func record_witness(record: Dictionary) -> String:
	return str(record.base.actor) if record.get("family") == "dream" else str(record.base.changes.subjects.petitioner)

static func record_family(state: Dictionary, source: String, index: RefCounted = null) -> String:
	var record: Dictionary = Anchors._evidence_record(state, source, index, true)
	return str(record.get("family", ""))

static func permit_valid(state: Dictionary, cult_id: String, source: String, index: RefCounted = null) -> bool:
	var permission: Dictionary = fact(state, source, index)
	if permission.get("kind") != "economy_qualification" or permission.changes.get("issuer") != "events" or permission.changes.get("version") != state.get("event_system", {}).get("version") or permission.changes.get("subject") != cult_id or not current(state, source, index): return false
	for parent: String in permission.causal_parents:
		var result: Dictionary = fact(state, parent, index)
		if result.get("kind") != "event_result" or result.changes.get("content_id") != "EVENT_09" or result.changes.get("option") != "A": continue
		var descriptor: Dictionary = result.changes.get("descriptor", {})
		if auth(state, "event/resolved/" + str(result.changes.get("event", "")), index) != result.id or descriptor.get("subjects", {}).get("cooperating_institution") != permission.changes.get("institution"): continue
		var cooperator: Dictionary = person(state, descriptor.subjects.cooperator, index)
		return not cooperator.is_empty() and cooperator.status == "active" and cooperator.domain == permission.domain and state.institutions.get(permission.changes.institution, {}).get("active", false) and current(state, descriptor.facts.relation, index)
	return false

static func inheritance(state: Dictionary, source: String, contract_id: String, index: RefCounted = null) -> Dictionary:
	var selected: Dictionary = fact(state, source, index); var contract: Dictionary = fact(state, contract_id, index)
	if selected.get("kind") != "contract_inheritance_fixed" or contract.get("kind") != "contract_obligation" or not current(state, source, index): return {}
	var data: Dictionary = selected.changes
	if not Anchors._shape(data, ["issuer", "version", "contract", "obligor", "successor", "relation"]) or state.get("event_system", {}).get("version") != data.get("version") or data.get("issuer") != "events" or data.get("contract") != contract_id or data.get("obligor") != contract.changes.obligor or not data.get("successor") is String or data.successor in [data.obligor, contract.changes.counterparty]: return {}
	var successor: Dictionary = person(state, data.successor, index)
	var obligor: Dictionary = person(state, data.obligor, index)
	if successor.get("status") != "active" or successor.get("domain") != contract.domain or obligor.get("status") != "dead" or selected.domain != contract.domain: return {}
	if not contract_id in selected.causal_parents or not data.get("relation") is String or not data.relation in selected.causal_parents or not data.obligor in selected.targets or not data.successor in selected.targets: return {}
	var relation: Dictionary = fact(state, data.relation, index)
	if not current(state, data.relation, index) or not relation.get("kind") in ["relationship", "initial_relationship"] or not data.obligor in [relation.actor] + relation.targets or not data.successor in [relation.actor] + relation.targets or index == null: return {}
	var actual: Dictionary = index.relation(data.obligor, data.successor, data.relation)
	if actual.is_empty(): actual = index.relation(data.successor, data.obligor, data.relation)
	if actual.get("kind") not in ["family", "support", "cooperation"] or actual.get("kind") != relation.changes.get("kind", relation.changes.get("type")): return {}
	var death: Dictionary = fact(state, str(obligor.get("status_source", "")), index)
	if death.get("kind") != "status_change" or not death.id in selected.causal_parents or selected.turn < death.turn or (selected.turn == death.turn and selected.id <= death.id): return {}
	return data.duplicate(true)

static func will(state: Dictionary, source: String, prophet: String, original: String, index: RefCounted = null) -> Dictionary:
	var document: Dictionary = fact(state, source, index)
	if document.get("kind") != "message" or not current(state, source, index): return {}
	var data: Dictionary = document.changes
	if not Anchors._shape(data, ["rule", "prophet", "successor", "prophet_source", "relation", "cult", "binding"]) or data.get("rule") != "prophet_will" or data.get("prophet") != prophet or data.get("prophet_source") != original or document.actor != prophet or not data.get("successor") is String or data.successor == prophet: return {}
	var successor: Dictionary = person(state, data.successor, index)
	if successor.is_empty() or successor.status != "active" or successor.domain != document.domain or not successor.get("bound_member", false) or successor.get("cult_id", "") != data.get("cult") or not prophet in document.targets or not data.successor in document.targets: return {}
	for cause: String in [original, str(data.get("relation", "")), str(data.get("binding", ""))]:
		if not cause in document.causal_parents or fact(state, cause, index).is_empty(): return {}
	var joined: Dictionary = fact(state, data.binding, index)
	if joined.get("kind") != "cult_member_joined" or joined.actor != prophet or joined.changes.get("cult") != data.cult: return {}
	var relation: Dictionary = fact(state, data.relation, index)
	if not current(state, data.relation, index) or not relation.get("kind") in ["relationship", "initial_relationship"] or index == null: return {}
	var actual: Dictionary = index.relation(prophet, data.successor, data.relation)
	if actual.is_empty(): actual = index.relation(data.successor, prophet, data.relation)
	if actual.is_empty() or actual.get("kind") != relation.changes.get("kind", relation.changes.get("type")): return {}
	var old: Dictionary = person(state, prophet, index)
	if old.get("status") == "dead":
		var death: Dictionary = fact(state, str(old.get("status_source", "")), index)
		if document.turn > death.get("turn", -1) or (document.turn == death.get("turn", -1) and document.id >= death.id): return {}
	var known: bool = Anchors._knows(state, prophet, source, index) or Anchors._knows(state, data.successor, source, index)
	return data.duplicate(true) if known else {}

static func historical_objects(state: Dictionary, descriptor: Dictionary, content: RefCounted) -> bool:
	var event: String = descriptor.get("content_id", "")
	var subjects: Dictionary = descriptor.get("subjects", {}); var facts: Dictionary = descriptor.get("facts", {})
	var subject_keys: Dictionary = {"EVENT_01": ["survivor", "fallbacks"], "EVENT_02": ["witnesses", "other_institution"], "EVENT_03": ["former", "cooperator", "opponent"], "EVENT_04": ["priest", "heretic"], "EVENT_05": ["obligor", "counterparty", "successor"], "EVENT_06": ["witnesses"], "EVENT_07": ["prophet", "successor"], "EVENT_08": ["relic"], "EVENT_09": ["cooperator", "opponent", "cooperating_institution"], "EVENT_10": ["relic"], "EVENT_11": ["other_institution"], "EVENT_12": ["petitioner"]}
	var fact_keys: Dictionary = {"EVENT_01": ["miracle", "callback"], "EVENT_02": ["records", "callback"], "EVENT_03": ["vacancy", "relations", "callback"], "EVENT_04": ["rituals", "public", "relation", "knowledge", "callback"], "EVENT_05": ["contract", "dependency", "witnesses", "inheritance", "relation", "callback"], "EVENT_06": ["memory", "qualifications", "callback"], "EVENT_07": ["prophet", "will", "succession", "callback"], "EVENT_08": ["exposure", "investigation", "callback"], "EVENT_09": ["conflict", "relation", "callback"], "EVENT_10": ["claim", "custody", "callback"], "EVENT_11": ["plan", "record", "records", "exception"], "EVENT_12": ["registration", "expiry", "closed", "situation"]}
	if not subject_keys.has(event): return false
	for key: Variant in subjects:
		if not key in subject_keys[event]: return false
	for key: Variant in facts:
		if not key in fact_keys[event]: return false
	var source: Dictionary = fact(state, descriptor.source)
	var prior: Dictionary = descriptor.get("prayer_descriptor", {})
	var produced: Dictionary = {}
	if source.get("kind") == "prayer_fact":
		var result: Dictionary = fact(state, auth(state, "prayer/response/" + str(source.changes.get("request", ""))))
		if result.get("kind") != "prayer_result" or result.changes.get("produced", {}).get("future_callback") != source.id: return false
		produced = result.changes.produced
		var expected: bool = false
		for row: Dictionary in content.tables.prayer_effects.values():
			if row.prayer_id == prior.get("content_id") and row.operation == "callback" and row.value == event and row.variant in ["both", result.changes.variant]: expected = true; break
		if not expected or facts.get("callback") != source.id: return false
	match event:
		"EVENT_01": return subjects.get("survivor") == prior.get("subjects", {}).get("relative") and facts.get("miracle") in [produced.get("miracle_witness"), produced.get("condition_cured")]
		"EVENT_02":
			if not facts.get("records") is Array or not subjects.get("witnesses") is Array or facts.records.size() != subjects.witnesses.size() or facts.records.is_empty(): return false
			var seen: Array = []
			for position: int in facts.records.size():
				var record: Dictionary = Anchors._prayer_record(state, facts.records[position], null, false)
				if record.is_empty(): record = Anchors._dream_record(state, facts.records[position], null, false)
				if record.is_empty() or record_witness(record) != subjects.witnesses[position] or record.base.id in seen: return false
				seen.append(record.base.id)
			return true
		"EVENT_03": return subjects.get("former") == prior.get("subjects", {}).get("petitioner") and facts.get("vacancy") == produced.get("support_withdrawn")
		"EVENT_04":
			if subjects.get("priest") != prior.get("subjects", {}).get("petitioner") or not facts.get("rituals") is Array or facts.rituals.is_empty(): return false
			for ritual: String in facts.rituals:
				var record: Dictionary = Anchors._prayer_record(state, ritual, null, false)
				if record.is_empty() or record.base.changes.prayer != "PRAYER_05" or record_witness(record) != subjects.priest or record.institution != descriptor.institution: return false
			return true
		"EVENT_05": return subjects.get("obligor") == prior.get("subjects", {}).get("petitioner") and subjects.get("counterparty") == prior.get("subjects", {}).get("counterparty") and facts.get("contract") == prior.get("facts", {}).get("contract") and facts.get("dependency") == produced.get("contract_dependency") and facts.get("witnesses") == [produced.get("contract_fulfilled"), produced.get("contract_learned")]
		"EVENT_06":
			if subjects.get("witnesses") != prior.get("subjects", {}).get("memory_people") or not facts.get("qualifications") is Array: return false
			var original: Dictionary = fact(state, str(prior.get("facts", {}).get("memory", "")))
			if original.get("kind") != "memory_at_risk" or original.changes.get("memory") != facts.get("memory"): return false
			for qualification: String in facts.qualifications:
				var record: Dictionary = Anchors._prayer_record(state, qualification, null, false)
				if record.is_empty() or record.tag != "memory_preserved" or record.base.changes.get("memory") != facts.memory or not record.base.targets[0] in subjects.witnesses: return false
			return true
		"EVENT_07": return subjects.get("prophet") == prior.get("subjects", {}).get("petitioner") and facts.get("prophet") == produced.get("public_prophet")
		"EVENT_08": return facts.get("investigation") == source.id and source.targets == [subjects.get("relic")]
		"EVENT_09": return subjects.get("cooperator") == prior.get("subjects", {}).get("petitioner") and subjects.get("opponent") == prior.get("subjects", {}).get("opponent") and subjects.get("cooperating_institution") == prior.get("institution") and facts.get("conflict") == prior.get("facts", {}).get("conflict") and facts.get("relation") == prior.get("facts", {}).get("relation")
		"EVENT_10":
			var claim: Dictionary = fact(state, str(facts.get("claim", "")))
			return subjects.get("relic") == prior.get("subjects", {}).get("relic") and facts.get("claim") == produced.get("relic_recovery_opportunity") and facts.get("custody") == claim.get("changes", {}).get("status_source")
		"EVENT_11": return facts.get("plan") == source.id and source.targets == [facts.get("record")]
		"EVENT_12":
			var registered: Dictionary = fact(state, str(facts.get("registration", "")))
			return registered.get("kind") == "prayer_registered" and registered.changes.get("descriptor") == prior and subjects.get("petitioner") == prior.get("subjects", {}).get("petitioner") and facts.get("expiry") == source.id and facts.get("situation") == prior.get("source")
	return false

static func relation_current(state: Dictionary, source: String, first: String, second: String, kinds: Array, index: RefCounted) -> bool:
	var record: Dictionary = fact(state, source, index)
	if record.is_empty() or not current(state, source, index) or not record.kind in ["relationship", "initial_relationship"] or not record.changes.get("kind", record.changes.get("type", "")) in kinds or not first in [record.actor] + record.targets or not second in [record.actor] + record.targets or index == null: return false
	var actual: Dictionary = index.relation(first, second, source)
	if actual.is_empty(): actual = index.relation(second, first, source)
	return not actual.is_empty() and actual.get("kind") == record.changes.get("kind", record.changes.get("type", ""))

static func related_any(state: Dictionary, sources: Array, first: String, second: String, kinds: Array, index: RefCounted) -> bool:
	for source: String in sources:
		if relation_current(state, source, first, second, kinds, index): return true
	return false

static func successor_legal(state: Dictionary, id: String, institution: String, content: RefCounted, index: RefCounted = null) -> bool:
	var npc: Dictionary = person(state, id, index)
	if npc.is_empty() or npc.status != "active" or not state.institutions.has(institution) or npc.domain != state.institutions[institution].domain or int(npc.sanity) < content.integer("institution_successor_min_sanity"): return false
	var profile: Dictionary = content.tables.npc_profiles.get(npc.get("profile", ""), {})
	if profile.is_empty() or not state.institutions[institution].role in str(profile.institution_roles).split("|"): return false
	var domain: Dictionary = state.domains[npc.domain]
	if int(profile.requires_ritual) and int(domain.occult) + int(domain.faith) <= 0: return false
	if int(profile.requires_route) and state.institutions[institution].links.is_empty(): return false
	if int(profile.requires_crisis) and History.size(domain.get("crisis_facts", [])) == 0: return false
	return not int(profile.requires_listener)

static func heretic_legal(state: Dictionary, descriptor: Dictionary, content: RefCounted, index: RefCounted = null) -> bool:
	var id: String = str(descriptor.subjects.get("heretic", "")); var npc: Dictionary = person(state, id, index)
	if npc.is_empty() or npc.status != "active" or npc.domain != descriptor.domain or not state.institutions.has(npc.institution): return false
	var office: Dictionary = state.institutions[npc.institution]
	var profile: Dictionary = content.tables.npc_profiles.get(npc.profile, {})
	if not office.active or office.role != "propagation" or not "propagation" in str(profile.get("institution_roles", "")).split("|") or not relation_current(state, str(descriptor.facts.get("relation", "")), str(descriptor.subjects.get("priest", "")), id, ["support", "cooperation"], index): return false
	var known: String = str(descriptor.facts.get("knowledge", "")); var result: Dictionary = fact(state, known, index)
	if result.get("kind") != "prayer_result" or result.changes.get("prayer") != "PRAYER_05" or not result.changes.get("outcome") in ["deep", "success"] or auth(state, "prayer/response/" + str(result.changes.get("request", "")), index) != known: return false
	var matches: bool = false
	for source: String in descriptor.facts.get("rituals", []):
		var ritual: Dictionary = actual_prayer(state, source, index)
		if not ritual.is_empty() and ritual.base.id in result.changes.get("produced", {}).values() and ritual.institution == descriptor.institution: matches = true
	return matches and (Anchors._knows(state, id, known, index) or Anchors._knows(state, npc.institution, known, index, true))
