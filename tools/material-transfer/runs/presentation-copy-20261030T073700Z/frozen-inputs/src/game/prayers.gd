extends RefCounted
## One source-bound request lifecycle and one response transaction. Fixed subjects
## and independent crises never change identity or deadline when a window closes.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Cults = preload("res://src/game/cults.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Powers = preload("res://src/game/powers.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Producers = preload("res://src/game/prayer_producers.gd")
const Sources = preload("res://src/game/prayer_sources.gd")
const ID: String = "prayers"
const Materials = preload("res://src/simulation/material_transfer.gd")
const SCHEMA: int = 1
var catalog: RefCounted
var issuers: Dictionary
var version: String
var checks: RefCounted

func _init(content: RefCounted, accepted_issuers: Dictionary = {}) -> void:
	catalog = content; issuers = accepted_issuers.duplicate(true)
	version = rule_version(content); checks = Powers.new(content, accepted_issuers)

static func rule_version(content: RefCounted) -> String:
	return "4/sources-scenes6/" + content.version + "/" + str(content.extension_versions.get("prayers", "missing")) + "/" + str(content.extension_versions.get("prayer_facts", "missing")) + "/" + str(content.extension_versions.get("prayer_effects", "missing")) + "/" + str(content.extension_versions.get("events", "missing")) + "/" + Knowledge.version(content)

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("prayer_system") or not turn.world.state.has("simulation"): return false
	if not Knowledge.install(turn.world): return false
	for key: Variant in issuers:
		if not key is String or key.is_empty() or not issuers[key] is String or str(issuers[key]).is_empty(): return false
	turn.world.state["prayer_system"] = {"schema": SCHEMA, "version": version, "issuers": issuers.duplicate(true), "requests": {}, "crises": {}, "offered": [], "offer_turn": 0, "restrictions": {}, "hidden": {}}
	if not turn.register_participant(ID, version + "/" + JSON.stringify(issuers, "", true, true).sha256_text(), ["actions", "prayer_freeze", "prayer_deadlines"], ["prayers"], handle):
		turn.world.state.erase("prayer_system"); return false
	if turn._participants.has("events") and not turn._participants.events.instance.install_rescue_sources(turn): return false
	return true

func _error(message: String, permanent: bool = true) -> Dictionary:
	return {"ok": false, "error": message, "permanent": permanent}

func _fact(state: Dictionary, source: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.facts, source): return Store.entry(state.facts, source)
	if reader == null or not reader.has_method("fact"): return {}
	var queried: Dictionary = reader.fact(source)
	return queried.item if queried.ok else {}

func _person(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.npcs, id): return Store.entry(state.npcs, id)
	if reader == null or not reader.has_method("entity"): return {}
	var queried: Dictionary = reader.entity("npcs", id)
	return queried.item if queried.ok else {}

func _valid(state: Dictionary, source: String, reader: RefCounted = null) -> bool:
	if _fact(state, source, reader).is_empty(): return false
	return not reader.invalidated(source) if reader != null and reader.has_method("invalidated") else not Store.has(state.invalid_records, source)

func _knows(state: Dictionary, person: String, source: String, reader: RefCounted = null, history: RefCounted = null, institution: bool = false) -> bool:
	if reader != null: return reader.knows(person, source, institution) if reader.has_method("fact") else reader.knows(state, person, source, institution)
	if history != null: return history.knows(state, person, source, institution)
	var item: Dictionary = state.institutions.get(person, {}) if institution else _person(state, person)
	return not item.is_empty() and History.has(item.get("known_facts", []), source)

func _alive(state: Dictionary, person: String, domain: String, reader: RefCounted = null) -> bool:
	var npc: Dictionary = _person(state, person, reader)
	return not npc.is_empty() and npc.status == "active" and npc.domain == domain

func _relation(state: Dictionary, source: String, first: String, second: String, reader: RefCounted = null, kinds: Array = [], history: RefCounted = null) -> bool:
	var fact: Dictionary = _fact(state, source, reader)
	if not _valid(state, source, reader) or fact.is_empty() or first == second or not fact.kind in ["relationship", "initial_relationship"]: return false
	var relation: Dictionary = {}
	if reader != null:
		relation = reader.relation(first, second, source)
		if relation.is_empty(): relation = reader.relation(second, first, source)
	elif history != null:
		relation = history.relation(first, second, source)
		if relation.is_empty(): relation = history.relation(second, first, source)
	if relation.is_empty(): return false
	var kind: String = str(relation.get("kind", relation.get("type", "")))
	return (kinds.is_empty() or kind in kinds) and fact.changes.get("kind", fact.changes.get("type", "")) == kind

func _roots(facts: Dictionary) -> Array:
	var found: Array = []
	for value: Variant in facts.values():
		if value is String:
			if not value in found: found.append(value)
		elif value is Array:
			for source: Variant in value:
				if not source is String: return []
				if not source in found: found.append(source)
		else: return []
	found.sort(); return found

func validate_situation(world: RefCounted, source: String) -> Dictionary:
	return _situation(world.state, source, null, world.history)

func create_call(world: RefCounted, descriptor: Dictionary, owner: Object, sample: Dictionary = {}) -> Dictionary:
	return Knowledge.create_call(world, descriptor, sample if not sample.is_empty() else Knowledge.capture(world, owner), owner)

func _situation(state: Dictionary, source: String, reader: RefCounted = null, history: RefCounted = null) -> Dictionary:
	var fact: Dictionary = _fact(state, source, reader)
	if fact.is_empty() or fact.kind != "prayer_situation" or not _valid(state, source, reader): return _error("Missing current prayer situation")
	var data: Dictionary = fact.changes
	for key: Variant in data:
		if not key in ["issuer", "version", "need", "domain", "institution", "actors", "subjects", "facts", "crisis", "reopen", "call", "record_knowledge"]: return _error("Unknown prayer situation field")
	if data.has("reopen") and (not data.reopen is String or data.reopen.is_empty()): return _error("Invalid reopening reference")
	if not issuers.has(data.get("issuer", "")) or issuers[data.issuer] != data.get("version") or data.get("domain") != fact.domain or not state.domains.has(fact.domain) or not data.get("institution") is String or not data.get("subjects") is Dictionary or not data.get("facts") is Dictionary or not data.get("actors") is Array or data.actors.is_empty() or not data.get("crisis") is Dictionary: return _error("Incompatible prayer situation contract")
	var content: String = ""
	for id: String in catalog.tables.prayers:
		if catalog.tables.prayers[id].need == data.get("need"): content = id; break
	if content.is_empty() or not data.subjects.get("petitioner") is String or data.actors[0] != data.subjects.petitioner: return _error("Prayer need or petitioner does not match")
	var domain: String = fact.domain; var subjects: Dictionary = data.subjects; var facts: Dictionary = data.facts
	var subject_keys: Dictionary = {"PRAYER_01": ["petitioner", "relative"], "PRAYER_02": ["petitioner", "rival"], "PRAYER_03": ["petitioner", "pursuer"], "PRAYER_04": ["petitioner", "second"], "PRAYER_05": ["petitioner"], "PRAYER_06": ["petitioner", "counterparty"], "PRAYER_07": ["petitioner", "memory_people"], "PRAYER_08": ["petitioner"], "PRAYER_09": ["petitioner"], "PRAYER_10": ["petitioner", "opponent", "relation_other"], "PRAYER_11": ["petitioner", "relic"], "PRAYER_12": ["petitioner", "other_institution"]}
	var fact_keys: Dictionary = Knowledge.FACT_FIELDS
	for key: Variant in subjects:
		if not key in subject_keys[content]: return _error("Unknown fixed prayer subject")
	for key: Variant in facts:
		if not key in fact_keys[content]: return _error("Unknown prayer cause key")
	for key: Variant in data.crisis:
		if not key in ["source", "due"]: return _error("Unknown original crisis field")
	var roots: Array = _roots(facts)
	var fixed: bool = not _authorization(state, "prayer/source/" + source, reader).is_empty()
	var deep_error: String = ""
	if roots.is_empty(): return _error("Prayer needs concrete preceding facts")
	for root: String in roots:
		if not root in fact.causal_parents or _fact(state, root, reader).is_empty() or _fact(state, root, reader).domain != domain: return _error("Prayer has a missing or wrong-domain cause")
		if not _valid(state, root, reader):
			if fixed and content == "PRAYER_07" and facts.get("relations") is Array and root in facts.relations.slice(1): deep_error = "A fixed deep memory tie is no longer current"
			else: return _error("Prayer has a revoked cause")
	var seen: Dictionary = {}
	for id: Variant in data.actors:
		if not id is String or seen.has(id) or not id in fact.targets or _person(state, id, reader).is_empty(): return _error("Prayer fixed subjects are not unique real people")
		if not _alive(state, id, domain, reader):
			var optional: bool = (content == "PRAYER_04" and id == subjects.get("second")) or (content == "PRAYER_07" and subjects.get("memory_people") is Array and id in subjects.memory_people.slice(1))
			if fixed and optional: deep_error = "A fixed deep witness is no longer active locally"
			else: return _error("Prayer required subject is no longer active locally")
		seen[id] = true
	if data.institution.is_empty() or not state.institutions.has(data.institution) or not state.institutions[data.institution].active or state.institutions[data.institution].domain != domain: return _error("Prayer institution is unavailable")
	var petitioner: String = subjects.petitioner
	var expected: Array = [petitioner]
	var crisis_root: String = ""
	match content:
		"PRAYER_01":
			if not subjects.get("relative") is String or not facts.get("condition") is String or not facts.get("relation") is String: return _error("Rescue needs a real relative and dying condition")
			expected.append(subjects.relative)
			var condition: Dictionary = _fact(state, facts.condition, reader)
			var scene: bool = condition.changes.get("rule") == "kinship_rescue_scene" and condition.changes.get("petitioner") == petitioner and condition.changes.get("relationship") == "family" and facts.relation == facts.condition
			if condition.kind != "dying_condition" or condition.changes.get("patient") != subjects.relative or not subjects.relative in condition.targets or not condition.changes.get("due") is int or (not scene and not _relation(state, facts.relation, petitioner, subjects.relative, reader, ["family", "kin", "parent", "child", "sibling", "spouse", "relative"], history)): return _error("Dying patient or kin relation does not match")
			if condition.changes.get("rule") != "kinship_rescue_scene":
				var injury: bool = false
				for parent: String in condition.causal_parents:
					var cause: Dictionary = _fact(state, parent, reader)
					injury = injury or (cause.get("kind") in ["harm", "crisis"] and subjects.relative in cause.get("targets", []))
				if not injury: return _error("Dying condition has no actual injury or crisis")
			crisis_root = facts.condition
		"PRAYER_02":
			if data.institution.is_empty() or not subjects.get("rival") is String or not facts.get("relation") is String or not facts.get("conflict") is String or (facts.relation != facts.conflict and not _relation(state, facts.relation, petitioner, subjects.rival, reader, ["rival", "hostile", "enemy"], history)): return _error("Recognition needs an existing institution rival")
			expected.append(subjects.rival)
			var conflict: Dictionary = _fact(state, facts.conflict, reader)
			if conflict.kind != "faction_conflict" or conflict.changes.get("institution") != data.institution or not petitioner in conflict.changes.get("parties", []) or not subjects.rival in conflict.changes.get("parties", []): return _error("Recognition conflict is not current")
			if not _conflict(state, conflict, petitioner, subjects.rival, data.institution, reader, history): return _error("Conflict has no actual default stance")
			crisis_root = facts.conflict
		"PRAYER_03":
			if not subjects.get("pursuer") is String or not facts.get("pursuit") is String: return _error("Concealment needs its real pursuer")
			expected.append(subjects.pursuer)
			var pursuit: Dictionary = _fact(state, facts.pursuit, reader)
			if pursuit.kind != "pursuit_condition" or pursuit.changes.get("subject") != petitioner or pursuit.changes.get("pursuer") != subjects.pursuer or pursuit.changes.get("institution") != data.institution or not pursuit.changes.get("clue") is String or not pursuit.changes.get("relation") is String or not _valid(state, pursuit.changes.clue, reader) or (pursuit.changes.get("scene_rule") != "ROOT_PURSUIT" and not _relation(state, pursuit.changes.relation, petitioner, subjects.pursuer, reader, [], history)): return _error("Ordinary pursuit condition has no matching clue/relationship")
			crisis_root = facts.pursuit
		"PRAYER_04":
			var proof: String = str(data.get("record_knowledge", facts.get("record", "")))
			if not facts.get("record") is String or not Producers.record_eligible(state, proof, petitioner, reader) or Producers.canonical_record(state, proof, reader) != facts.record: return _error("Petitioner lacks the actual current unexplained record knowledge")
			if subjects.has("second"): expected.append(subjects.second)
		"PRAYER_05":
			if data.institution.is_empty() or not facts.get("ritual") is String: return _error("Ritual needs its real institution and occasion")
			var ritual: Dictionary = _fact(state, facts.ritual, reader)
			if ritual.kind != "ritual_context" or ritual.changes.get("subject") != petitioner or ritual.changes.get("institution") != data.institution or ritual.changes.get("turn") != ritual.turn or not _ritual(state, data.institution, reader): return _error("Institution has no current ritual capacity")
		"PRAYER_06":
			if not subjects.get("counterparty") is String or not facts.get("contract") is String: return _error("Obligation needs both real parties")
			expected.append(subjects.counterparty)
			var contract: Dictionary = _fact(state, facts.contract, reader)
			if contract.kind != "contract_obligation" or contract.changes.get("obligor") != petitioner or contract.changes.get("counterparty") != subjects.counterparty or contract.changes.get("institution") != data.institution: return _error("Contract obligation does not match")
			crisis_root = facts.contract
		"PRAYER_07":
			if not subjects.get("memory_people") is Array or subjects.memory_people.is_empty() or not facts.get("memory") is String or not facts.get("relations") is Array or facts.relations.size() != subjects.memory_people.size(): return _error("Memory needs its existing social ties")
			var memory: Dictionary = _fact(state, facts.memory, reader)
			if memory.kind != "memory_at_risk" or not memory.changes.get("memory") is String or not _valid(state, memory.changes.memory, reader): return _error("Memory has no preceding remembered fact")
			for index: int in subjects.memory_people.size():
				var person: String = subjects.memory_people[index]
				if person == petitioner or not person in memory.changes.get("holders", []): return _error("Memory holder graph does not match")
				if not _knows(state, person, memory.changes.memory, reader, history) or not ((memory.changes.get("scene_rule") == "ROOT_MEMORY_REVIEW" and facts.relations[index] == facts.memory) or _relation(state, facts.relations[index], petitioner, person, reader, [], history)):
					if fixed and index > 0: deep_error = "A fixed deep memory tie or witness qualification was lost"
					else: return _error("Memory ties or actual knowledge do not match")
				expected.append(person)
			crisis_root = facts.memory
		"PRAYER_08":
			if not facts.get("contact") is String: return _error("Devotion needs a current willingness source")
			var contact: Dictionary = _fact(state, facts.contact, reader)
			if contact.kind != "devotion_contact" or contact.changes.get("subject") != petitioner or contact.changes.get("institution") != data.institution or not _devotion_current(state, _person(state, petitioner, reader), contact, reader): return _error("Potential follower is not offering a new devotion")
		"PRAYER_09":
			if not facts.get("contact") is String or int(state.domains[domain].barrier) <= 0: return _error("No actual barrier contact")
			var contact: Dictionary = _fact(state, facts.contact, reader)
			if contact.kind != "barrier_contact" or contact.changes.get("subject") != petitioner or contact.changes.get("institution") != data.institution or contact.changes.get("barrier_source") != state.domains[domain].barrier_source: return _error("Barrier contact refers to a different current wall")
		"PRAYER_10":
			if not subjects.get("opponent") is String or not facts.get("conflict") is String or not facts.get("relation") is String or data.institution.is_empty(): return _error("Judgment needs an existing conflict and relationship")
			expected.append(subjects.opponent)
			var conflict: Dictionary = _fact(state, facts.conflict, reader)
			if conflict.changes.get("scene_rule") == "ROOT_DISPUTE":
				if not subjects.get("relation_other") is String or subjects.relation_other in [petitioner, subjects.opponent] or conflict.changes.get("secret", {}).get("b") != subjects.relation_other: return _error("Judgment scene needs its fixed third person")
				expected.append(subjects.relation_other)
			if conflict.kind != "faction_conflict" or conflict.changes.get("institution") != data.institution or not petitioner in conflict.changes.get("parties", []) or not subjects.opponent in conflict.changes.get("parties", []) or (facts.relation != facts.conflict and not _relation(state, facts.relation, petitioner, subjects.opponent, reader, [], history)): return _error("Dispute or relationship is not genuine")
			if not _conflict(state, conflict, petitioner, subjects.opponent, data.institution, reader, history): return _error("Conflict has no actual default stance")
			crisis_root = facts.conflict
		"PRAYER_11":
			if not subjects.get("relic") is String or not Store.has(state.relics, subjects.relic) or not facts.get("claim") is String: return _error("Recovery needs its actual seized relic")
			var relic: Dictionary = Store.entry(state.relics, subjects.relic)
			var claim: Dictionary = _fact(state, facts.claim, reader)
			if relic.placement != "seized" or relic.get("captor") != data.institution or relic.domain != domain or claim.kind != "message" or claim.changes.get("relic") != subjects.relic or claim.changes.get("status_source") != relic.get("status_source") or not subjects.relic in claim.targets or not petitioner in claim.targets: return _error("Relic custody or claimant link changed")
		"PRAYER_12":
			if state.domains[domain].tier != "cosmic" or not facts.get("exception") is String or data.institution.is_empty(): return _error("Law exception needs a cosmic institution")
			if _fact(state, facts.exception, reader).kind != "exception" or not _knows(state, data.institution, facts.exception, reader, history, true): return _error("Institution does not possess the actual exception")
			if facts.has("observation"):
				var observation: Dictionary = _fact(state, str(facts.observation), reader)
				if observation.get("kind") != "law_observation" or observation.changes.get("exception") != facts.exception or observation.changes.get("observer") != petitioner or observation.changes.get("node") != data.institution or not _knows(state, petitioner, str(facts.observation), reader, history): return _error("Anomaly record lost its original observation")
			if subjects.has("other_institution"):
				var other: String = subjects.other_institution
				if other == data.institution or not state.institutions.has(other): return _error("Second institution is not real or different")
				if not state.institutions[other].active or state.institutions[other].domain != domain or not other in state.institutions[data.institution].links:
					if fixed: deep_error = "Second institution is no longer active in real communication"
					else: return _error("Second institution is not in real communication")
	var expected_sorted: Array = expected.duplicate(); expected_sorted.sort()
	var actual_sorted: Array = data.actors.duplicate(); actual_sorted.sort()
	if expected_sorted != actual_sorted: return _error("Prayer fixed actor graph omits or adds a subject")
	var crisis: Dictionary = {}
	if not crisis_root.is_empty():
		var root: Dictionary = _fact(state, crisis_root, reader)
		if not root.changes.get("due") is int or root.changes.due < state.turn: return _error("Original crisis has already ended")
		crisis = {"id": "CRISIS/" + crisis_root, "source": crisis_root, "due": root.changes.due}
	if not data.get("crisis", {}).is_empty() and (data.crisis.get("source") != crisis.get("source") or data.crisis.get("due") != crisis.get("due")): return _error("Request cannot replace the original crisis deadline")
	var descriptor: Dictionary = {"ok": true, "content_id": content, "domain": domain, "actors": data.actors.duplicate(), "institution": data.institution, "subjects": subjects.duplicate(true), "facts": facts.duplicate(true), "source_ids": roots, "crisis": crisis, "source": source}
	if data.has("record_knowledge"):
		if content != "PRAYER_04" or not data.record_knowledge is String or not data.record_knowledge in fact.causal_parents: return _error("Known-record proof is not the original exact input")
		descriptor["record_knowledge"] = data.record_knowledge
	if data.has("call"):
		if not data.call is String or not data.call in fact.causal_parents or not Knowledge.validate_call(state, data.call, descriptor, catalog, reader): return _error("Prayer situation lacks its original sourced call")
		descriptor["call"] = data.call
		var called: Dictionary = _fact(state, data.call, reader)
		descriptor["addressing"] = called.changes.addressing; descriptor["knowledge"] = called.changes.knowledge
	elif data.issuer in ["events", "player_sources", Knowledge.ID]: return _error("Formal prayer producer must supply its original call")
	else: descriptor["legacy_source"] = true # Explicitly configured external consumer contracts only; never a formal producer.
	var validated: Dictionary = _reopening(state, descriptor, data, reader)
	if validated.ok and not deep_error.is_empty(): validated["deep_error"] = deep_error
	return validated

func _conflict(state: Dictionary, conflict: Dictionary, first: String, second: String, institution: String, reader: RefCounted, history: RefCounted) -> bool:
	if conflict.changes.get("scene_rule") == "ROOT_DISPUTE":
		if conflict.changes.get("parties") != [first, second] or conflict.changes.get("default_stance") != "existing_order": return false
		if conflict.changes.get("selected_need") == "judgment":
			var secret: Dictionary = conflict.changes.get("secret", {})
			return secret.get("a") == second and secret.get("b") in conflict.targets and not secret.get("b") in [first, second] and secret.get("kind") == "concealed_agreement"
		return conflict.changes.get("selected_need") == "recognition"
	var original: String = str(conflict.changes.get("default_stance", ""))
	var stance: Dictionary = _fact(state, original, reader)
	return _valid(state, original, reader) and original in conflict.causal_parents and not stance.is_empty() and first in ([stance.actor] + stance.targets) and second in ([stance.actor] + stance.targets) and _knows(state, institution, original, reader, history, true)

func _ritual(state: Dictionary, institution: String, reader: RefCounted = null) -> bool:
	var office: Dictionary = state.institutions[institution]
	var ids: Array = [str(office.get("representative", ""))]
	for id: String in state.npcs:
		var person: Dictionary = _person(state, id, reader)
		if person.get("institution") == institution and not id in ids: ids.append(id)
	for id: String in ids:
		var person: Dictionary = _person(state, id, reader)
		if not person.is_empty() and person.status == "active" and person.domain == office.domain and "ritual_keeper" in person.get("role_tags", []): return true
	return false

func _devotion_current(state: Dictionary, person: Dictionary, contact: Dictionary, reader: RefCounted = null) -> bool:
	if person.get("bound_member", false): return false
	var binding: Dictionary = _fact(state, str(person.get("binding_source", "")), reader)
	return binding.is_empty() or binding.get("kind") != "member_left" or str(binding.id) < str(contact.id)

func _background(state: Dictionary, card: Dictionary, reader: RefCounted = null, history: RefCounted = null) -> Dictionary:
	if not card.get("template", "") in ["BG_CONTACT", "BG_ESCAPE", "BG_RECORD", "BG_RITUAL"] or not card.get("actors") is Array or card.actors.is_empty(): return _error("Unknown background prayer template")
	var domain: String = card.domain; var petitioner: String = card.actors[0]
	if not state.domains.has(domain) or not _alive(state, petitioner, domain, reader): return _error("Background petitioner is no longer active locally")
	for source: String in card.source_ids:
		if not _valid(state, source, reader): return _error("Background request source was revoked")
	var person: Dictionary = _person(state, petitioner, reader)
	var institution: String = str(person.institution)
	if institution.is_empty() or not state.institutions.has(institution) or state.institutions[institution].domain != domain or not state.institutions[institution].active: return _error("Background request lost its institution")
	var facts: Dictionary = {}
	match str(card.template):
		"BG_CONTACT":
			if not _devotion_current(state, person, _fact(state, card.fact, reader), reader): return _error("Devotion already resolved by an actual membership or later departure")
			facts.contact = card.fact
		"BG_ESCAPE":
			if state.domains[domain].barrier <= 0 or state.institutions[institution].links.is_empty(): return _error("Actual barrier contact is no longer present")
			facts.contact = card.fact
		"BG_RITUAL":
			if not PrayerRules.ritual_keeper(state, person): return _error("Ritual keeper or institution is no longer available")
			for source: String in card.source_ids:
				var ritual: Dictionary = _fact(state, source, reader)
				if ritual.get("kind") == "ritual_context" and ritual.actor == petitioner and ritual.changes.get("subject") == petitioner and ritual.changes.get("institution") == institution and ritual.changes.get("turn") == card.created_turn and ritual.turn == card.created_turn: facts.ritual = source; break
			if not facts.has("ritual"): return _error("Background ritual lacks its actual current occasion")
		"BG_RECORD":
			for source: String in card.source_ids:
				var fact: Dictionary = _fact(state, source, reader)
				if fact.kind == "exposure" and fact.domain == domain and _knows(state, petitioner, source, reader, history): facts.record = source; break
			if not facts.has("record"): return _error("Background record has no genuinely known exposure")
	return {"ok": true, "content_id": card.content_id, "domain": domain, "actors": card.actors.duplicate(), "institution": institution, "subjects": {"petitioner": petitioner}, "facts": facts, "crisis": {}, "source": card.fact, "legacy_source": true}

func _descriptor(state: Dictionary, card: Dictionary, reader: RefCounted = null, history: RefCounted = null) -> Dictionary:
	return _situation(state, str(card.source), reader, history) if card.get("origin") == "prayer_situation" else _background(state, card, reader, history)

func _import(world: RefCounted, owner: Object) -> bool:
	world.stage_collections(["prayer_system"])
	var ledger: Dictionary = world.state.prayer_system
	var cards: Array = world.state.simulation.candidates.keys(); cards.sort()
	for id: String in cards:
		var card: Dictionary = world.state.simulation.candidates[id]
		if not str(card.get("content_id", "")).begins_with("PRAYER_") or ledger.requests.has(id): continue
		var descriptor: Dictionary = _descriptor(world.state, card, null, world.history)
		if not descriptor.ok:
			world._close_background(card, "cancelled"); continue
		if not world.claim_prayer_occurrence(card, descriptor, owner): world._close_background(card, "duplicate_situation"); continue
		var imported: String = world._record("prayer_registered", card.domain, descriptor.subjects.petitioner, card.actors, [card.fact], {"request": id, "source": descriptor.source, "descriptor": descriptor, "due": card.due_turn})
		ledger.requests[id] = {"card": card.duplicate(true), "descriptor": descriptor, "status": "open", "source": imported, "crisis": descriptor.crisis.get("id", "")}
		if not descriptor.crisis.is_empty():
			var crisis: Dictionary = descriptor.crisis
			if Store.has(world.state.applied_authorizations, "prayer/crisis/" + crisis.id): _close(world, id, "crisis_already_ended", imported); continue
			if not ledger.crises.has(crisis.id): ledger.crises[crisis.id] = {"source": crisis.source, "due": crisis.due, "requests": [], "registered": imported, "descriptor": descriptor.duplicate(true), "card": card.duplicate(true)}
			if ledger.crises[crisis.id].source != crisis.source or ledger.crises[crisis.id].due != crisis.due: return false
			ledger.crises[crisis.id].requests.append(id)
	return true

func _close(world: RefCounted, id: String, reason: String, source: String) -> void:
	if not world.state.prayer_system.requests.has(id): return
	var request: Dictionary = world.state.prayer_system.requests[id]
	var closed: String = world._record("prayer_closed", request.card.domain, request.descriptor.subjects.petitioner, request.card.actors, [request.source, source], {"request": id, "reason": reason, "crisis": request.crisis})
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, "prayer/closed/" + id, closed)
	if world.state.simulation.candidates.has(id): world._close_background(world.state.simulation.candidates[id], "prayer_closed")
	world.state.prayer_system.requests.erase(id)

func _crisis_done(world: RefCounted, id: String, result: String, source: String) -> void:
	if not world.state.prayer_system.crises.has(id): return
	var crisis: Dictionary = world.state.prayer_system.crises[id]
	var closed: String = world._record("prayer_crisis_" + result, _fact(world.state, crisis.source).domain, "", [], [crisis.source, source], {"crisis": id, "due": crisis.due})
	world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, "prayer/crisis/" + id, closed)
	for request: String in crisis.requests.duplicate(): _close(world, request, result, closed)
	world.state.prayer_system.crises.erase(id)

func _freeze(world: RefCounted, owner: Object) -> bool:
	var ledger: Dictionary = world.state.prayer_system
	for id: String in ledger.hidden.keys():
		var entry: Dictionary = ledger.hidden[id]
		if entry.until >= world.state.turn: continue
		ledger.hidden.erase(id)
	for id: String in ledger.restrictions.keys():
		for kind: String in ledger.restrictions[id].keys():
			if ledger.restrictions[id][kind].until < world.state.turn: ledger.restrictions[id].erase(kind)
		if ledger.restrictions[id].is_empty(): ledger.restrictions.erase(id)
	# Only pre-existing source IDs are considered. Deterministic fixation does not
	# make a newly produced ordinary request visible in this same turn.
	for source: String in ([] if world.state.has("prayer_dispatch") else world.history.ids("prayer_sources")):
		var valid: Dictionary = validate_situation(world, source)
		if not valid.ok:
			if valid.get("permanent", true): world.close_prayer_source(source, valid.error, owner)
			continue
		world.fix_prayer_source(source, owner)
	if not _import(world, owner): return false
	ledger.offered = []; ledger.offer_turn = world.state.turn
	var ids: Array = ledger.requests.keys(); ids.sort()
	for id: String in ids:
		var request: Dictionary = ledger.requests[id]
		if request.status != "open" or request.card.visible_turn > world.state.turn or request.card.due_turn < world.state.turn: continue
		var current: Dictionary = _descriptor(world.state, request.card, null, world.history)
		if not current.ok: _close(world, id, "subject_or_situation_invalid", request.source); continue
		if ledger.offered.size() < catalog.integer("prayer_offer_limit"): ledger.offered.append(id)
	return true

func prepare(view: Dictionary, request_id: String, variant: String, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = view.world
	for key: Variant in options:
		if not key in ["agent", "agent_source", "preparations"]: return _error("Unknown prayer option")
	if not variant in ["shallow", "deep"] or not state.has("prayer_system") or state.prayer_system.version != version: return _error("Prayer variant or policy unavailable")
	var ledger: Dictionary = state.prayer_system
	if not ledger.requests.has(request_id) or not request_id in ledger.offered or ledger.offer_turn != state.turn: return _error("Request is not in this turn's frozen offers")
	var request: Dictionary = ledger.requests[request_id]
	if request.status != "open" or request.card.visible_turn > state.turn or request.card.due_turn < state.turn: return _error("Request response window is closed")
	if int(view.turn.get("responses", 0)) >= catalog.integer("prayer_response_limit"): return _error("Prayer response opportunity already spent")
	var descriptor: Dictionary = _descriptor(state, request.card, view.reader)
	if not descriptor.ok: return descriptor
	var subjects: Dictionary = descriptor.subjects
	if variant == "deep":
		if descriptor.has("deep_error"): return _error(descriptor.deep_error)
		if descriptor.content_id == "PRAYER_04" and not subjects.has("second"): return _error("Deep knowledge needs its fixed second witness")
		if descriptor.content_id == "PRAYER_07" and subjects.memory_people.size() != 3: return _error("Deep memory needs three fixed different ties")
		if descriptor.content_id == "PRAYER_12" and not subjects.has("other_institution"): return _error("Deep exception needs its fixed connected institution")
	var actor: String = str(options.get("agent", subjects.petitioner))
	var person: Dictionary = _person(state, actor, view.reader)
	if not _alive(state, actor, descriptor.domain, view.reader): return _error("Response subject is not active in the target domain")
	var agent_source: String = str(options.get("agent_source", ""))
	if actor != subjects.petitioner:
		var authorization: Dictionary = _fact(state, agent_source, view.reader)
		if not person.get("bound_member", false) or person.loyalty < catalog.integer("loyalty_follower_threshold") or authorization.is_empty() or not _valid(state, agent_source, view.reader) or authorization.kind != "message" or not actor in authorization.targets or not subjects.petitioner in authorization.targets or not descriptor.source in authorization.causal_parents: return _error("Agent lacks actual membership and the petitioner's sourced delegation")
	elif not agent_source.is_empty(): return _error("Petitioner does not need an agent authorization")
	var faith: int = catalog.integer("prayer_" + variant + "_faith")
	var whispers: int = catalog.integer("prayer_" + variant + "_whispers")
	if state.faith < faith or state.whispers < whispers: return _error("Prayer response is not affordable")
	var preparation: int = 0; var preparations: Array = []
	if not options.get("preparations", []) is Array: return _error("Invalid prayer preparation sources")
	for selected: Variant in options.get("preparations", []):
		if not selected is String or selected in preparations or not state.has("power_system") or not state.power_system.preparations.has(selected): return _error("Unknown or repeated preparation")
		var entry: Dictionary = state.power_system.preparations[selected]
		if entry.npc != actor or entry.action != "PRAYER/" + request_id + "/" + variant or entry.expires < state.turn or not _valid(state, selected, view.reader): return _error("Preparation belongs to another subject, declaration or turn")
		preparation += int(entry.amount); preparations.append(selected)
	var probability: int = checks.probability(person, state.domains[descriptor.domain], {"attribute": "adaptation", "check_kind": "occult"}, preparation)
	var participants: Array = descriptor.actors.duplicate()
	if variant == "shallow" and descriptor.content_id == "PRAYER_04": participants = [subjects.petitioner]
	if variant == "shallow" and descriptor.content_id == "PRAYER_07": participants = [subjects.petitioner, subjects.memory_people[0]]
	if not actor in participants: participants.append(actor)
	var attention: Dictionary = {"family": "prayer", "content_id": descriptor.content_id, "variant": variant, "participants": participants, "target": descriptor.domain, "nominees": [subjects.petitioner] if descriptor.content_id == "PRAYER_08" else []}
	return {"ok": true, "request": request_id, "variant": variant, "descriptor": descriptor, "actor": actor, "agent_source": agent_source, "faith": faith, "whispers": whispers, "probability": probability, "p": probability, "preparations": preparations, "attention": attention}

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	if input.slot in ["prayer_freeze", "prayer_deadlines"]: return {"ok": true, "empty": false, "effects": [{"type": "prayers", "operation": input.slot}], "state": {}}
	if input.get("action") != "respond" or not input.get("payload") is Dictionary: return _error("Unknown prayer action")
	var payload: Dictionary = input.payload
	if not payload.get("request") is String or not payload.get("variant") is String: return _error("Prayer needs its fixed request and variant")
	var options: Dictionary = payload.duplicate(true); options.erase("request"); options.erase("variant")
	var plan: Dictionary = prepare(view, payload.request, payload.variant, options)
	if not plan.ok: return {"ok": false, "empty": true, "effects": [], "state": {}, "error": plan.error}
	return {"ok": true, "empty": false, "effects": [{"type": "prayers", "operation": "respond", "plan": plan}], "state": {}, "meta": {"faith_cost": plan.faith, "whispers_cost": plan.whispers, "min_awakening": 0, "actor": "", "source": plan.descriptor.source, "outcome": "prayer_attempt", "responds": true, "used_power": false, "used_relic": false, "target": plan.descriptor.domain, "attention": plan.attention}}

func preview(turn: RefCounted, request_id: String, variant: String, options: Dictionary = {}) -> Dictionary:
	if not turn._attached or turn._in_transaction or turn._in_participant or turn.context.phase != "actions": return _error("Prayer preview requires the action phase")
	var view: Dictionary = turn._read_view(ID, "actions")
	var plan: Dictionary = prepare(view, request_id, variant, options)
	if plan.ok and turn.world.state.has("attention"):
		var needs: Dictionary = turn.world.attention.preview_needs(turn.world.state, plan.attention, [], "")
		if not needs.ok: view.reader.close(); return needs
		plan["needs"] = needs
	view.reader.close(); return plan

func validate_effect(state: Dictionary, slot: String, effect: Dictionary) -> bool:
	if not state.has("prayer_system") or state.prayer_system.version != version: return false
	if slot in ["prayer_freeze", "prayer_deadlines"]: return effect.get("operation") == slot
	return slot == "actions" and effect.get("operation") == "respond" and effect.get("plan") is Dictionary and effect.plan.get("ok") == true

func _rows(content: String, variant: String, stage: String) -> Array:
	var rows: Array = []
	for row: Dictionary in catalog.tables.prayer_effects.values():
		if row.prayer_id in [content, "*"] and row.variant in [variant, "both"] and row.stage == stage: rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return rows

func _subjects(plan: Dictionary, subject: String) -> Array:
	var descriptor: Dictionary = plan.descriptor
	if subject == "actor": return [plan.actor]
	if subject == "request": return [plan.request]
	if subject == "domain": return [descriptor.domain]
	if subject == "institution": return [descriptor.institution]
	if subject == "memory_people": return descriptor.subjects.memory_people.slice(0, 1) if plan.variant == "shallow" else descriptor.subjects.memory_people.duplicate()
	return [descriptor.subjects[subject]] if descriptor.subjects.has(subject) else []

func _amount(row: Dictionary, outcome: String) -> int:
	var amount: int = catalog.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)
	if outcome == "deep" and row.scale == "count": amount = signi(amount) * maxi(1, int(floor(absi(amount) * catalog.number("prayer_deep_success_multiplier"))))
	return amount

func _invalidate(world: RefCounted, original: String, source: String) -> void:
	if original.is_empty() or Store.has(world.state.invalid_records, original): return
	world.stage_collections(["invalid_records"]); Store.put(world.state.invalid_records, original, source)
	world._record("prayer_source_withdrawn", _fact(world.state, original).domain, "", [original], [original, source], {"source": original})
	if world._turn_owner != null and not Sources.resolve(world, original, source, world._turn_owner.get_ref()):
		if world.transaction != null: world.transaction.error = "Independent source resolution rejected its original cure"

func _delta(world: RefCounted, plan: Dictionary, row: Dictionary, amount: int, source: String, owner: Object) -> bool:
	var field: String = row.field
	for id: String in _subjects(plan, row.subject):
		if row.subject == "domain":
			var domain: Dictionary = world.state.domains[id]
			if field == "followers":
				var actual: int = mini(absi(amount), domain.unnamed_nonfollowers if amount >= 0 else domain.unnamed_followers)
				if actual > 0 and not world.submit({"kind": "population", "domain": id, "mode": "convert" if amount > 0 else "leave", "amount": actual, "parents": [source]}, owner, true): return false
			else:
				var before: int = domain[field]
				domain[field] = clampi(before + amount, 0, catalog.integer("attribute_max"))
				if field == "pollution" and domain[field] > before: domain.pollution_changed_turn = world.state.turn
				if field == "alert" and domain[field] > before: domain.exposure_turn = world.state.turn
				if field == "barrier" and domain[field] != before: domain.barrier_source = source
		else:
			var person: Dictionary = world.mutable_npc(id)
			var actual_field: String = "sanity" if field == "sanity_loss" else field
			person[actual_field] = clampi(int(person[actual_field]) + (-amount if field == "sanity_loss" else amount), 0, catalog.integer("attribute_max"))
		world._record("prayer_delta", plan.descriptor.domain, plan.actor, [id], [source], {"request": plan.request, "field": field, "amount": amount})
	return true

func _write(world: RefCounted, plan: Dictionary, tag: String, targets: Array, source: String, extra: Dictionary = {}) -> String:
	var changes: Dictionary = {"request": plan.request, "prayer": plan.descriptor.content_id, "variant": plan.variant, "tag": tag, "institution": plan.descriptor.institution, "subjects": plan.descriptor.subjects, "facts": plan.descriptor.facts}
	changes.merge(extra)
	var parents: Array = [source, plan.descriptor.source]
	parents.append_array(_roots(plan.descriptor.facts))
	var result: String = world._record("prayer_fact", plan.descriptor.domain, plan.actor, targets, parents, changes)
	plan.produced[tag] = result
	for target: String in targets:
		if Store.has(world.state.npcs, target): world._know(target, result)
		elif world.state.institutions.has(target): world._institution_know(target, result)
	return result

func _learned_source(plan: Dictionary, field: String) -> String:
	var facts: Dictionary = plan.descriptor.facts
	match field:
		"testimony": return str(plan.produced.get("private_testimony", ""))
		"relic_holder": return str(facts.claim)
	return str(facts.get(field, ""))

func _apply_rows(world: RefCounted, plan: Dictionary, stage: String, outcome: String, source: String, owner: Object, token: String = "") -> bool:
	var facts: Dictionary = plan.descriptor.facts; var subjects: Dictionary = plan.descriptor.subjects
	for row: Dictionary in _rows(plan.descriptor.content_id, plan.variant, stage):
		var targets: Array = _subjects(plan, row.subject)
		if row.condition == "subject_alive":
			targets = targets.filter(func(id: String) -> bool: return Store.has(world.state.npcs, id) and Store.entry(world.state.npcs, id).status != "dead")
			if targets.is_empty(): continue
		if row.condition == "knows_disclosure" and not _knows(world.state, subjects.opponent, facts.relation, null, world.history): continue
		match str(row.operation):
			"delta":
				if not _delta(world, plan, row, _amount(row, outcome), source, owner): return false
			"set_min":
				for id: String in targets: world.mutable_npc(id)[row.field] = maxi(int(world.mutable_npc(id)[row.field]), _amount(row, outcome))
			"cure", "fulfill":
				var root: String = facts.condition if row.operation == "cure" else facts.contract
				var result: String = _write(world, plan, "condition_cured" if row.operation == "cure" else "contract_fulfilled", targets, source, {"original": root})
				_invalidate(world, root, result)
			"record":
				var result: String = _write(world, plan, row.field, targets, source)
				if row.field in ["public_witness", "public_prophet", "public_ritual", "public_evidence", "public_exception_qualification", "anomaly_evidence"]:
					var witnesses: Array = []
					for target: String in targets:
						if Store.has(world.state.npcs, target) and Store.entry(world.state.npcs, target).status == "active": witnesses.append(target)
					var institution: String = plan.descriptor.institution if row.subject != "other_institution" else subjects.other_institution
					var exposure: String = world.introduce_fact("exposure", plan.descriptor.domain, plan.actor, targets, [result], {"public": true, "prayer": plan.descriptor.content_id, "tag": row.field, "request": plan.request, "institution": institution}, witnesses, [institution], owner)
					if exposure.is_empty(): return false
					plan.produced[row.field + "_exposure"] = exposure
				if row.field == "hostility":
					if not world.establish_relation(targets[0], subjects.petitioner, "hostile", [result, facts.relation], [], owner).ok: return false
			"learn":
				var original: String = _learned_source(plan, row.field)
				if original.is_empty() or not Store.has(world.state.facts, original): return false
				var material: Dictionary = Materials.resolve(world.state, original, catalog, world.history)
				var deferred: Array = []
				for target: String in targets:
					if world.state.institutions.has(target): world._institution_know(target, original)
					elif material.get("ok", false) and target != subjects.petitioner:
						var recipient: Dictionary = Store.entry(world.state.npcs, target)
						var reception: Dictionary = {"sender": subjects.petitioner, "recipient": target, "source": original, "target_institution": recipient.institution, "grant": "knowledge", "channel": {"kind": "declared_result", "source": source, "from_institution": Store.entry(world.state.npcs, subjects.petitioner).institution, "to_institution": recipient.institution}}
						var candidate: Dictionary = Materials.preview(world.state, reception, catalog, world.history, "declared_result")
						if candidate.get("ok", false): deferred.append(reception)
						else: world._know(target, original)
					else: world._know(target, original)
				var learned: String = _write(world, plan, row.field + "_learned", targets, source, {"original": original})
				for reception: Dictionary in deferred:
					reception.channel.source = learned
					if not world.receive_material(reception, learned, owner, "declared_result").get("ok", false): return false
			"withdraw":
				var original: String = ""
				if row.field in ["pursuit_clue", "pursuit_relation"]:
					var pursuit: Dictionary = _fact(world.state, facts.pursuit)
					original = str(pursuit.changes["clue" if row.field == "pursuit_clue" else "relation"])
					if pursuit.changes.get("scene_rule") == "ROOT_PURSUIT" and (row.field == "pursuit_clue" or original.is_empty()):
						# End this investigation; its public exposure remains historical fact.
						_write(world, plan, "pursuit_scene_withdrawn", targets, source, {"original": facts.pursuit})
						_invalidate(world, facts.pursuit, source)
						continue
					if row.field == "pursuit_relation":
						var receipt: String = _write(world, plan, "pursuit_relation_withdrawn", targets, source, {"original": original})
						if not world.retire_relation(original, receipt, owner).ok: return false
					else: _invalidate(world, original, source)
					_invalidate(world, facts.pursuit, source)
				else:
					var support: Dictionary = world.history.support(subjects.petitioner, plan.descriptor.institution)
					if not support.is_empty(): _invalidate(world, str(support.source), source)
				if row.field != "pursuit_relation": _write(world, plan, row.field + "_withdrawn", targets, source, {"original": original})
			"restrict":
				var kind: String = "propagation" if row.field == "spread" else "appointment"
				var until: int = world.state.turn + (0 if row.value == "current_turn" else int(row.value))
				var result: String = _write(world, plan, kind + "_restricted", targets, source, {"until": until})
				for target: String in targets:
					if not world.state.prayer_system.restrictions.has(target): world.state.prayer_system.restrictions[target] = {}
					world.state.prayer_system.restrictions[target][kind] = {"until": until, "source": result}
			"conceal":
				var result: String = _write(world, plan, "concealed", targets, source, {"until": world.state.turn + _amount(row, outcome)})
				world.state.prayer_system.hidden[subjects.petitioner] = {"until": world.state.turn + _amount(row, outcome), "source": result}
			"vacate": world._detach_roles(world.mutable_npc(subjects.petitioner), source)
			"memory":
				for target: String in targets:
					var result: String = _write(world, plan, "memory_preserved", [target], source, {"original": facts.memory, "memory": _fact(world.state, facts.memory).changes.memory})
					world._know(target, _fact(world.state, facts.memory).changes.memory)
					Store.put(world.state.applied_authorizations, "prayer/memory/" + facts.memory + "/" + target, result)
			"enroll":
				var dedication: String = world._record("member_dedication", plan.descriptor.domain, subjects.petitioner, [subjects.petitioner], [source, plan.descriptor.source], {"request": plan.request})
				world.mutable_npc(subjects.petitioner).dedication_source = dedication
				if not Cults.membership(world, "enroll", subjects.petitioner, dedication, token, checks._cult(world.state, plan.descriptor.domain)): return false
			"route": _write(world, plan, "escape_route", targets, source, {"barrier_source": world.state.domains[plan.descriptor.domain].barrier_source})
			"recovery":
				var relic: Dictionary = Store.entry(world.state.relics, subjects.relic)
				var event: Dictionary = catalog.tables.events[row.value]
				_write(world, plan, "relic_recovery_opportunity", targets, source, {"relic": subjects.relic, "captor": relic.captor, "status_source": relic.status_source, "earliest": world.state.turn + int(event.min_age), "due": world.state.turn + int(event.max_age)})
			"callback": _write(world, plan, "future_callback", [subjects.petitioner], source, {"event": row.value, "earliest": world.state.turn + 1})
			"succeed":
				if subjects.rival in world.institution_successors(plan.descriptor.institution):
					var authorized: String = world._record("institution_succession_authorized", plan.descriptor.domain, subjects.rival, [subjects.rival, plan.descriptor.institution], [source, facts.conflict], {"request": plan.request})
					if not world.succeed_institution(plan.descriptor.institution, subjects.rival, authorized, owner): return false
			"kill_if_dying":
				if _valid(world.state, facts.condition) and Store.entry(world.state.npcs, subjects.relative).status != "dead":
					if not world.submit({"kind": "status", "npc": subjects.relative, "status": "dead", "parents": [source, facts.condition]}, owner): return false
					_invalidate(world, facts.condition, source)
			"drop_memory":
				for target: String in subjects.memory_people:
					if not Store.has(world.state.applied_authorizations, "prayer/memory/" + facts.memory + "/" + target):
						var lost: String = _write(world, plan, "memory_qualification_lost", [target], source, {"original": facts.memory, "memory": _fact(world.state, facts.memory).changes.memory})
						Store.put(world.state.applied_authorizations, "prayer/memory_lost/" + facts.memory + "/" + target, lost)
			"close_cooperation":
				_write(world, plan, "cooperation_closed", targets, source, {"original": facts.contract}); _invalidate(world, facts.contract, source)
			"settle_dispute":
				var conflict: Dictionary = _fact(world.state, facts.conflict)
				var stance: String = str(conflict.changes.default_stance)
				_write(world, plan, "dispute_settled", targets, source, {"original": facts.conflict, "stance": stance}); _invalidate(world, facts.conflict, source)
			"close": pass
			_: return false
	return true

func _expiry(world: RefCounted, request: Dictionary, source: String, owner: Object) -> bool:
	var plan: Dictionary = {"request": request.card.id, "variant": "shallow", "descriptor": request.descriptor, "actor": request.descriptor.subjects.petitioner, "produced": {}}
	if request.card.get("default_result") == "unanswered_request":
		if request.status != "open": return true
		var person: Dictionary = world.mutable_npc(plan.actor)
		if person.status != "active" or person.domain != plan.descriptor.domain: return true
		var loss: int = catalog.integer("request_unanswered_trust_loss") if person.loyalty >= catalog.integer("loyalty_follower_threshold") else 0
		person.loyalty = maxi(0, int(person.loyalty) - loss)
		var domain: Dictionary = world.state.domains[plan.descriptor.domain]
		domain.alert = mini(catalog.integer("attribute_max"), int(domain.alert) + catalog.integer("request_unanswered_alert")); domain.exposure_turn = world.state.turn
		return not world.introduce_fact("exposure", plan.descriptor.domain, person.id, [person.id], [source, request.card.fact], {"public": true, "rule": "unanswered_request"}, [], [plan.descriptor.domain + "/order"], owner).is_empty()
	return _apply_rows(world, plan, "expiry", "expiry", source, owner)

func _deadlines(world: RefCounted, owner: Object) -> bool:
	if not _import(world, owner) or not Sources.phase5(world, owner): return false
	var ledger: Dictionary = world.state.prayer_system
	var crises: Array = ledger.crises.keys(); crises.sort()
	for id: String in crises:
		var crisis: Dictionary = ledger.crises[id]
		if not _valid(world.state, crisis.source): _crisis_done(world, id, "resolved", crisis.source); continue
		if crisis.due > world.state.turn: continue
		var expired: String = world._record("prayer_crisis_due", crisis.descriptor.domain, crisis.descriptor.subjects.petitioner, crisis.card.actors, [crisis.source, crisis.registered], {"crisis": id, "due": crisis.due})
		var request: Dictionary = {"card": crisis.card, "descriptor": crisis.descriptor, "status": "answered"}
		if not _expiry(world, request, expired, owner): return false
		_crisis_done(world, id, "expired", expired)
	var ids: Array = ledger.requests.keys(); ids.sort()
	for id: String in ids:
		var request: Dictionary = ledger.requests[id]
		if request.card.due_turn > world.state.turn: continue
		var expired: String = str(Store.entry(world.state.applied_authorizations, "prayer/window/" + id, ""))
		if world.state.has("event_system") and expired.is_empty():
			expired = _window_due(world, request)
		if not request.crisis.is_empty() and ledger.crises.has(request.crisis):
			if request.status == "open": request.status = "expired"
			continue
		if expired.is_empty(): expired = _window_due(world, request)
		if request.status == "open" and not _expiry(world, request, expired, owner): return false
		_close(world, id, "expired", expired)
	return Sources.finish_deadlines(world)

func commit(world: RefCounted, effect: Dictionary, owner: Object, token: String = "") -> bool:
	if not world._driver_allowed(owner): return false
	world.stage_current(); world.stage_collections(["applied_authorizations", "invalid_records"])
	if effect.operation == "prayer_freeze": return _freeze(world, owner)
	if effect.operation == "prayer_deadlines": return _deadlines(world, owner)
	var plan: Dictionary = effect.plan.duplicate(true)
	if not world.state.prayer_system.requests.has(plan.request): return false
	var request: Dictionary = world.state.prayer_system.requests[plan.request]
	if request.status != "open": return false
	var paid_id: String = "FACT-%08d" % (int(world.state.next_fact) - 1)
	var paid: Dictionary = _fact(world.state, paid_id)
	if paid.kind == "cult_local_payment": paid_id = paid.changes.payment; paid = _fact(world.state, paid_id)
	if paid.kind != "turn_action" or paid.changes.get("outcome") != "prayer_attempt" or paid.changes.get("faith_cost") != plan.faith or paid.changes.get("whispers_cost") != plan.whispers: return false
	var source: String = world._record("prayer_attempt", plan.descriptor.domain, plan.actor, plan.attention.participants, [request.source, plan.descriptor.source, paid_id] + ([] if plan.agent_source.is_empty() else [plan.agent_source]), {"request": plan.request, "variant": plan.variant, "actor": plan.actor, "descriptor": plan.descriptor, "p": plan.probability, "probability": plan.probability, "preparations": plan.preparations, "faith_cost": plan.faith, "whispers_cost": plan.whispers, "payment": paid_id})
	for selected: String in plan.preparations:
		Store.put(world.state.applied_authorizations, "power/preparation/" + selected, source); world.state.power_system.preparations.erase(selected)
	plan["produced"] = {}
	if not _apply_rows(world, plan, "always", "always", source, owner, token): return false
	var roll: int = world.randoms.checks.randi_range(1, 100)
	var outcome: String = world.check_result(plan.probability, roll)
	owner._checks.append({"probability": plan.probability, "roll": roll, "outcome": outcome})
	var checked: String = world._record("turn_check", plan.descriptor.domain, plan.actor, [plan.actor], [source], {"probability": plan.probability, "roll": roll, "outcome": outcome, "snapshot_before_always": true})
	if outcome in ["deep", "success"]:
		if not _apply_rows(world, plan, "success", outcome, checked, owner, token): return false
	elif outcome == "disaster":
		if not _apply_rows(world, plan, "disaster", outcome, checked, owner, token): return false
	var result_data: Dictionary = {"request": plan.request, "prayer": plan.descriptor.content_id, "variant": plan.variant, "actor": plan.actor, "p": plan.probability, "roll": roll, "outcome": outcome, "produced": plan.produced}
	if plan.descriptor.content_id == "PRAYER_08" and outcome in ["deep", "success"]:
		result_data["recognition"] = Knowledge.recognition(world, plan.descriptor.subjects.petitioner, "KNOW_DEVOTION", owner)
		# A first follower has a real membership binding before a cult exists.
		# This is the current dedication's enrollment, not an old cult tenure.
		result_data.recognition["membership"] = str(Store.entry(world.state.npcs, plan.descriptor.subjects.petitioner).get("binding_source", ""))
	var result: String = world._record("prayer_result", plan.descriptor.domain, plan.actor, plan.attention.participants, [source, checked], result_data)
	if result_data.has("recognition") and not Knowledge.identify(world, plan.descriptor.subjects.petitioner, result, "KNOW_DEVOTION", owner).ok: return false
	Store.put(world.state.applied_authorizations, "prayer/response/" + plan.request, result)
	world._know(plan.actor, result)
	if outcome in ["deep", "success"]:
		if world.introduce_fact("miracle", plan.descriptor.domain, plan.actor, [plan.actor], [checked, result], {"prayer": plan.descriptor.content_id, "request": plan.request, "institution": plan.descriptor.institution, "witnesses": [plan.actor], "public": false}, [plan.actor], [], owner).is_empty(): return false
	request.status = "answered"; request["result"] = result
	var remaining_crisis: bool = not request.crisis.is_empty() and world.state.prayer_system.crises.has(request.crisis)
	if outcome in ["deep", "success"] and remaining_crisis and (plan.descriptor.content_id != "PRAYER_10" or _fact(world.state, str(plan.descriptor.facts.get("conflict", ""))).changes.get("scene_rule") == "ROOT_DISPUTE"):
		if plan.descriptor.content_id != "PRAYER_07" or plan.variant == "deep":
			var root: String = world.state.prayer_system.crises[request.crisis].source
			if (plan.descriptor.content_id == "PRAYER_10" and _fact(world.state, root).changes.get("scene_rule") == "ROOT_DISPUTE") or (plan.descriptor.content_id == "PRAYER_07" and _fact(world.state, root).changes.get("scene_rule") == "ROOT_MEMORY_REVIEW"):
				# Consuming this crisis preserves the fixed history for its callback.
				if not Sources._close_situation(world, root, result): return false
			else: _invalidate(world, root, result)
			_crisis_done(world, request.crisis, "resolved", result); remaining_crisis = false
	if plan.descriptor.content_id == "PRAYER_11" and outcome in ["deep", "success"]:
		if not Sources._close_situation(world, str(plan.descriptor.facts.claim), result): return false
	if plan.descriptor.content_id == "PRAYER_06" and outcome in ["deep", "success"]:
		if not Sources._close_situation(world, str(plan.descriptor.facts.contract), result): return false
	if plan.descriptor.content_id == "PRAYER_12" and plan.descriptor.facts.has("observation"):
		if not Sources._close_situation(world, str(plan.descriptor.facts.observation), result): return false
	if not remaining_crisis: _close(world, plan.request, "answered", result)
	return true

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not state.has("prayer_system"):
		if trusted.has("prayer_system"): return ["Installed prayer policy disappeared"]
		return []
	var ledger: Variant = state.prayer_system
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content) or not ledger.get("issuers") is Dictionary: return ["Invalid prayer policy/schema"]
	if trusted.has("prayer_system") and (ledger.version != trusted.prayer_system.version or ledger.issuers != trusted.prayer_system.issuers): return ["Prayer source capabilities changed"]
	for field: String in ["requests", "crises", "restrictions", "hidden"]:
		if not ledger.get(field) is Dictionary: return ["Invalid prayer current ledger"]
	if not ledger.get("offered") is Array or not ledger.get("offer_turn") is int or ledger.offer_turn < 0 or ledger.offer_turn > state.turn or ledger.offered.size() > content.integer("prayer_offer_limit"): return ["Invalid frozen prayer offer list"]
	var seen: Dictionary = {}
	for id: Variant in ledger.offered:
		if not id is String or seen.has(id) or (not ledger.requests.has(id) and not Store.has(state.applied_authorizations, "prayer/closed/" + id)): return ["Invented or duplicate frozen offer"]
		seen[id] = true
	for id: String in ledger.requests:
		var entry: Variant = ledger.requests[id]
		if not entry is Dictionary or not entry.get("card") is Dictionary or entry.card.get("id") != id or not entry.get("descriptor") is Dictionary or not entry.get("status") in ["open", "answered", "expired"] or not entry.get("crisis") is String or not entry.get("source") is String or not Store.has(state.facts, entry.source): return ["Invalid live prayer request"]
		if not state.simulation.candidates.has(id) or state.simulation.candidates[id] != entry.card: return ["Prayer request lost its original fixed candidate"]
		var registration: Dictionary = Store.entry(state.facts, entry.source)
		if registration.kind != "prayer_registered" or registration.changes.get("request") != id or registration.changes.get("descriptor") != entry.descriptor or registration.changes.get("due") != entry.card.due_turn or not entry.card.fact in registration.causal_parents: return ["Prayer request changed its fixed source, subjects or deadline"]
		if entry.status == "answered":
			if not entry.get("result") is String or not Store.has(state.facts, entry.result) or Store.entry(state.facts, entry.result).kind != "prayer_result" or Store.entry(state.facts, entry.result).changes.get("request") != id or not Store.has(state.applied_authorizations, "prayer/response/" + id) or Store.entry(state.applied_authorizations, "prayer/response/" + id) != entry.result: return ["Answered prayer has no unique actual result"]
		if not entry.crisis.is_empty() and (not ledger.crises.has(entry.crisis) or not id in ledger.crises[entry.crisis].requests): return ["Prayer lost its independent crisis"]
	for id: String in ledger.crises:
		var entry: Variant = ledger.crises[id]
		if not entry is Dictionary or not entry.get("source") is String or id != "CRISIS/" + entry.source or not Store.has(state.facts, entry.source) or not entry.get("due") is int or not entry.get("requests") is Array or not entry.get("descriptor") is Dictionary or not entry.get("card") is Dictionary or not entry.get("registered") is String or not Store.has(state.facts, entry.registered): return ["Invalid independent prayer crisis"]
		var original: Dictionary = Store.entry(state.facts, entry.source)
		var registered: Dictionary = Store.entry(state.facts, entry.registered)
		if original.changes.get("due") != entry.due or registered.kind != "prayer_registered" or registered.changes.get("descriptor") != entry.descriptor or entry.descriptor.crisis.get("source") != entry.source or entry.descriptor.crisis.get("due") != entry.due: return ["Prayer crisis deadline or source was rewritten"]
		seen = {}
		for request: Variant in entry.requests:
			if not request is String or seen.has(request): return ["Duplicate crisis request"]
			seen[request] = true
	for npc: String in ledger.restrictions:
		if not Store.has(state.npcs, npc) or not ledger.restrictions[npc] is Dictionary: return ["Invalid restricted prayer subject"]
		for kind: String in ledger.restrictions[npc]:
			var entry: Variant = ledger.restrictions[npc][kind]
			if not kind in ["propagation", "appointment"] or not entry is Dictionary or not entry.get("until") is int or not entry.get("source") is String or not Store.has(state.facts, entry.source): return ["Invalid prayer restriction"]
			var fact: Dictionary = Store.entry(state.facts, entry.source)
			if fact.kind != "prayer_fact" or fact.changes.get("tag") != kind + "_restricted" or fact.changes.get("until") != entry.until or not npc in fact.targets: return ["Prayer restriction is not its actual finite result"]
	for npc: String in ledger.hidden:
		var entry: Variant = ledger.hidden[npc]
		if not Store.has(state.npcs, npc) or not entry is Dictionary or not entry.get("until") is int or not entry.get("source") is String or not Store.has(state.facts, entry.source): return ["Invalid prayer concealment"]
		var fact: Dictionary = Store.entry(state.facts, entry.source)
		if fact.kind != "prayer_fact" or fact.changes.get("tag") != "concealed" or fact.changes.get("until") != entry.until or not npc in fact.targets: return ["Prayer concealment changed original person or duration"]
	# Restore audits all source history. A normal transaction audits only the new
	# suffix over immutable trusted archive roots, and validates hot references.
	var expected_requests: Dictionary = {}
	var expected_restrictions: Dictionary = {}
	var expected_hidden: Dictionary = {}
	var facts: Array = []
	if trusted.is_empty(): facts = Store.values(state.facts)
	elif Store.overlay(state.facts):
		for id: String in Store.changed(state.facts): facts.append(Store.entry(state.facts, id))
	elif not is_same(state.facts, trusted.facts):
		for entry: Dictionary in History.changed_entries(state.facts, trusted.facts):
			if entry.has("after") and entry.after is Dictionary: facts.append(entry.after)
			elif Store.has(state.facts, str(entry.get("key", ""))): facts.append(Store.entry(state.facts, entry.key))
	facts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for fact: Dictionary in facts:
		if fact.kind == "prayer_registered":
			var data: Dictionary = fact.changes
			if not data.get("request") is String or not data.get("descriptor") is Dictionary or not data.get("source") is String or not Store.has(state.facts, data.source): return ["Invalid original prayer registration"]
			var descriptor: Dictionary = data.descriptor
			var original: Dictionary = Store.entry(state.facts, data.source)
			if descriptor.get("source") != data.source or not content.tables.prayers.has(descriptor.get("content_id", "")) or descriptor.get("domain") != fact.domain or not descriptor.get("actors") is Array or not descriptor.get("subjects") is Dictionary or not descriptor.get("facts") is Dictionary: return ["Registration changed its source-bound object graph"]
			if original.kind == "prayer_situation":
				var basis: Dictionary = original.changes
				if not ledger.issuers.has(basis.get("issuer", "")) or ledger.issuers[basis.issuer] != basis.get("version") or basis.get("need") != content.tables.prayers[descriptor.content_id].need or basis.get("domain") != descriptor.domain or basis.get("actors") != descriptor.actors or basis.get("subjects") != descriptor.subjects or basis.get("institution") != descriptor.institution or basis.get("facts") != descriptor.facts: return ["Registered prayer does not match its authored situation"]
				if basis.has("call"):
					if descriptor.get("call") != basis.call or descriptor.get("record_knowledge", "") != basis.get("record_knowledge", "") or not basis.call in original.causal_parents or not Knowledge.validate_call(state, basis.call, descriptor, content): return ["Registered prayer changed its original call"]
					var call: Dictionary = Store.entry(state.facts, basis.call)
					if descriptor.get("addressing") != call.changes.addressing or descriptor.get("knowledge") != call.changes.knowledge: return ["Registered prayer changed its original addressing knowledge"]
				elif basis.get("issuer") in ["events", "player_sources", Knowledge.ID] or not descriptor.get("legacy_source", false): return ["Formal prayer registration omitted its original call"]
				if basis.has("reopen"):
					var auth: Dictionary = Store.entry(state.facts, str(basis.reopen), {})
					if auth.get("changes", {}).get("issuer") == "events":
						var event: Dictionary = PrayerRules.event_reopen_result(state, auth)
						if event.is_empty() or event.result.turn != original.turn or descriptor.get("event_reopen") != event.result.id or PrayerRules.sourced_occurrence_key(state, descriptor) != PrayerRules.sourced_occurrence_key(state, event.registration.changes.descriptor) or Store.entry(state.applied_authorizations, "prayer/event_reopen/" + PrayerRules.sourced_occurrence_key(state, descriptor), "") != event.result.id: return ["Prayer event reopening lost its exact once-only original situation"]
			elif original.kind != "background_fixed": return ["Prayer registration has no real situation or background root"]
			expected_requests[data.request] = fact.id
		if fact.kind == "prayer_window_due" and (state.has("event_system") or fact.changes.has("registration")):
			var data: Dictionary = fact.changes
			var registration: Dictionary = Store.entry(state.facts, str(data.get("registration", "")), {})
			if registration.get("kind") != "prayer_registered" or data.get("request") != registration.changes.get("request") or data.get("descriptor") != registration.changes.get("descriptor") or not data.get("answered") is bool or data.get("due") != registration.changes.get("due") or fact.turn < int(data.get("due", -1)) or not registration.id in fact.causal_parents or Store.entry(state.applied_authorizations, "prayer/window/" + str(data.request), "") != fact.id: return ["Prayer window lost its exact original registration or unique deadline"]
		if fact.kind == "prayer_closed":
			if not fact.changes.get("request") is String or not Store.has(state.applied_authorizations, "prayer/closed/" + fact.changes.request) or Store.entry(state.applied_authorizations, "prayer/closed/" + fact.changes.request) != fact.id: return ["Closed prayer lost its unique lifecycle marker"]
		if fact.kind == "prayer_fact" and fact.changes.get("tag") in ["propagation_restricted", "appointment_restricted", "concealed"]:
			if not fact.changes.get("until") is int or fact.targets.size() != 1: return ["Malformed finite prayer consequence"]
			if fact.changes.until >= state.turn:
				var target: String = fact.targets[0]
				if fact.changes.tag == "concealed": expected_hidden[target] = fact.id
				else:
					if not expected_restrictions.has(target): expected_restrictions[target] = {}
					expected_restrictions[target][str(fact.changes.tag).trim_suffix("_restricted")] = fact.id
		if fact.kind == "prayer_attempt":
			var data: Dictionary = fact.changes
			if not data.get("request") is String or not data.get("variant") in ["shallow", "deep"] or not data.get("actor") is String or data.actor != fact.actor or not data.get("descriptor") is Dictionary or not data.get("p") is int or data.p < content.integer("check_probability_min") or data.p > content.integer("check_probability_max") or not data.get("payment") is String or not Store.has(state.facts, data.payment) or not data.get("preparations") is Array: return ["Malformed real prayer attempt"]
			var payment: Dictionary = Store.entry(state.facts, data.payment)
			if payment.kind != "turn_action" or payment.turn != fact.turn or payment.actor != "" or payment.changes.get("outcome") != "prayer_attempt" or payment.changes.get("faith_cost") != content.integer("prayer_" + data.variant + "_faith") or payment.changes.get("whispers_cost") != content.integer("prayer_" + data.variant + "_whispers") or not data.payment in fact.causal_parents: return ["Prayer response has no actual authored payment"]
			seen = {}
			for selected: Variant in data.preparations:
				if not selected is String or seen.has(selected) or not Store.has(state.facts, selected) or not Store.has(state.applied_authorizations, "power/preparation/" + selected) or Store.entry(state.applied_authorizations, "power/preparation/" + selected) != fact.id: return ["Prayer preparation not consumed by the real attempt"]
				seen[selected] = true
		if fact.kind == "prayer_result":
			var data: Dictionary = fact.changes
			if not data.get("request") is String or not data.get("variant") in ["shallow", "deep"] or not data.get("p") is int or not data.get("roll") is int or data.roll < 1 or data.roll > 100 or not data.get("outcome") in ["deep", "success", "failure", "disaster"] or fact.causal_parents.size() != 2: return ["Malformed prayer result"]
			var attempt: Dictionary = Store.entry(state.facts, fact.causal_parents[0])
			var checked: Dictionary = Store.entry(state.facts, fact.causal_parents[1])
			if attempt.get("kind") != "prayer_attempt" or checked.get("kind") != "turn_check" or attempt.changes.request != data.request or attempt.changes.variant != data.variant or attempt.changes.p != data.p or checked.changes.get("probability") != data.p or checked.changes.get("roll") != data.roll or checked.changes.get("outcome") != data.outcome or not attempt.id in checked.causal_parents: return ["Prayer result does not match its actual check and fixed attempt"]
			var edge: int = maxi(1, int(floor(float(data.p) / content.number("check_critical_divisor"))))
			var disaster: int = maxi(1, int(ceil(float(100 - data.p) / content.number("check_critical_divisor"))))
			var expected: String = "deep" if data.roll <= edge else ("success" if data.roll <= data.p else ("disaster" if data.roll > 100 - disaster else "failure"))
			if data.outcome != expected: return ["Prayer result fabricated a check outcome"]
	if trusted.is_empty():
		for id: String in expected_requests:
			var closed: String = str(Store.entry(state.applied_authorizations, "prayer/closed/" + id, ""))
			if closed.is_empty():
				if not ledger.requests.has(id) or ledger.requests[id].source != expected_requests[id]: return ["Live source-bound prayer disappeared from the current ledger"]
			elif not Store.has(state.facts, closed) or Store.entry(state.facts, closed).kind != "prayer_closed" or Store.entry(state.facts, closed).changes.get("request") != id: return ["Prayer closure marker has no actual closure"]
		for npc: String in expected_restrictions:
			for kind: String in expected_restrictions[npc]:
				if ledger.restrictions.get(npc, {}).get(kind, {}).get("source") != expected_restrictions[npc][kind]: return ["Active sourced prayer restriction disappeared"]
		for npc: String in expected_hidden:
			if ledger.hidden.get(npc, {}).get("source") != expected_hidden[npc]: return ["Active sourced concealment disappeared"]

	return []

func _authorization(state: Dictionary, key: String, reader: RefCounted = null) -> String:
	if reader != null and reader.has_method("authorization"):
		var result: Dictionary = reader.authorization(key)
		return str(result.source) if result.ok and result.used else ""
	return str(Store.entry(state.applied_authorizations, key, ""))

func _reopening(state: Dictionary, descriptor: Dictionary, data: Dictionary, reader: RefCounted = null) -> Dictionary:
	var occurrence: String = _authorization(state, PrayerRules.sourced_occurrence_key(state, descriptor, reader), reader)
	var current: String = _authorization(state, "prayer/source/" + descriptor.source, reader)
	var reopening: String = str(data.get("reopen", ""))
	if occurrence.is_empty() and reopening.is_empty(): return descriptor
	if reopening.is_empty():
		if not current.is_empty() and current == occurrence: return descriptor
		return _error("This exact situation was already fixed and needs a sourced reopening")
	var auth: Dictionary = _fact(state, reopening, reader)
	if auth.is_empty() or auth.kind != "prayer_reopen_authorized" or not _valid(state, reopening, reader) or auth.domain != descriptor.domain or not auth.changes.get("parent") is String or auth.changes.size() != 3 or not issuers.has(auth.changes.get("issuer", "")) or issuers[auth.changes.issuer] != auth.changes.get("version") or not auth.changes.parent in auth.causal_parents or not reopening in _fact(state, descriptor.source, reader).causal_parents: return _error("Reopening lacks its exact versioned source and original cause")
	var consumed: String = _authorization(state, "prayer/reopen/" + reopening, reader)
	if not consumed.is_empty() and consumed != current: return _error("Reopening authorization already consumed")
	var parent: Dictionary = _fact(state, auth.changes.parent, reader)
	var fixed_id: String = auth.changes.parent if parent.get("kind") == "background_fixed" else _authorization(state, "prayer/source/" + auth.changes.parent, reader)
	var fixed: Dictionary = _fact(state, fixed_id, reader)
	if fixed.is_empty() or not fixed.changes.get("candidate") is Dictionary: return _error("Reopening has no actual original fixed request")
	var card: Dictionary = fixed.changes.candidate
	var prior: Dictionary = {}
	for cause: String in auth.causal_parents:
		var closed: Dictionary = _fact(state, cause, reader)
		if closed.get("kind") == "prayer_result" and closed.changes.get("request") == card.id and _authorization(state, "prayer/response/" + card.id, reader) == cause:
			for original: String in closed.causal_parents:
				var attempt: Dictionary = _fact(state, original, reader)
				if attempt.get("kind") == "prayer_attempt": prior = attempt.changes.descriptor
		if closed.get("kind") == "prayer_closed" and closed.changes.get("request") == card.id and _authorization(state, "prayer/closed/" + card.id, reader) == cause:
			for original: String in closed.causal_parents:
				var registration: Dictionary = _fact(state, original, reader)
				if registration.get("kind") == "prayer_registered": prior = registration.changes.descriptor
	var event: Dictionary = PrayerRules.event_reopen_result(state, auth, reader)
	if not event.is_empty():
		prior = event.registration.changes.descriptor
		var fixed_current: bool = not current.is_empty()
		if PrayerRules.sourced_occurrence_key(state, prior, reader) != PrayerRules.sourced_occurrence_key(state, descriptor, reader) or (not fixed_current and event.result.turn != state.turn): return _error("Event reopening changed its exact original request")
		if not descriptor.crisis.is_empty() and (not _valid(state, descriptor.crisis.source, reader) or (not fixed_current and state.turn > descriptor.crisis.due)): return _error("Event reopening cannot restore an ended crisis")
		var unique: String = _authorization(state, "prayer/event_reopen/" + PrayerRules.sourced_occurrence_key(state, descriptor, reader), reader)
		if not unique.is_empty() and unique != event.result.id: return _error("This original situation already used its event reopening")
		descriptor["reopen"] = reopening; descriptor["event_reopen"] = event.result.id
		return descriptor
	if prior.is_empty() or PrayerRules.sourced_occurrence_key(state, prior, reader) != PrayerRules.sourced_occurrence_key(state, descriptor, reader) or descriptor.crisis.is_empty() or state.turn + (0 if not current.is_empty() else 1) > descriptor.crisis.due or not _valid(state, descriptor.crisis.source, reader): return _error("Reopening changed fixed objects or the original crisis is no longer available")
	descriptor["reopen"] = reopening
	return descriptor

func _window_due(world: RefCounted, request: Dictionary) -> String:
	var expired: String = world._record("prayer_window_due", request.card.domain, request.descriptor.subjects.petitioner, request.card.actors, [request.source, request.descriptor.source], {"request": request.card.id, "due": request.card.due_turn, "answered": request.status == "answered", "registration": request.source, "descriptor": request.descriptor.duplicate(true)})
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, "prayer/window/" + request.card.id, expired)
	return expired

func preview_reopen(state: Dictionary, registration_id: String, window_id: String, reader: RefCounted = null) -> Dictionary:
	var registration: Dictionary = _fact(state, registration_id, reader)
	var window: Dictionary = _fact(state, window_id, reader)
	if registration.get("kind") != "prayer_registered" or window.get("kind") != "prayer_window_due" or window.changes.get("registration") != registration_id or window.changes.get("request") != registration.changes.get("request") or window.changes.get("answered", true) or window.changes.get("descriptor") != registration.changes.get("descriptor") or _authorization(state, "prayer/window/" + str(registration.changes.request), reader) != window_id: return _error("Reopening requires the actual unanswered window")
	var descriptor: Dictionary = registration.changes.descriptor.duplicate(true)
	if not _authorization(state, "prayer/event_reopen/" + PrayerRules.sourced_occurrence_key(state, descriptor, reader), reader).is_empty(): return _error("The same situation already used EVENT_12B")
	if not descriptor.crisis.is_empty() and (not _valid(state, descriptor.crisis.source, reader) or state.turn > descriptor.crisis.due or not _authorization(state, "prayer/crisis/" + str(descriptor.crisis.id), reader).is_empty()): return _error("The original crisis is no longer open")
	var petitioner: Dictionary = _person(state, str(descriptor.subjects.petitioner), reader)
	if petitioner.is_empty() or petitioner.status != "active" or petitioner.domain != descriptor.domain: return _error("The original petitioner is no longer available")
	var offered: Array = state.get("prayer_system", {}).get("offered", [])
	var available: bool = registration.changes.request in offered or offered.size() < catalog.integer("prayer_offer_limit")
	return {"ok": true, "descriptor": descriptor, "offer_capacity": "available" if available else "full", "will_offer": available}

func reopen_event(world: RefCounted, result_id: String, original_request: String, owner: Object) -> Dictionary:
	if not world._driver_allowed(owner) or world.transaction == null or not world.state.has("event_system"): return _error("Reopening requires the actual event transaction")
	var result: Dictionary = _fact(world.state, result_id)
	if result.get("kind") != "event_result" or result.changes.get("content_id") != "EVENT_12" or result.changes.get("option") != "B" or result.turn != world.state.turn or _authorization(world.state, "event/resolved/" + str(result.changes.get("event", ""))) != result_id: return _error("Only the committed EVENT_12B grants this reopening")
	var event_descriptor: Dictionary = result.changes.get("descriptor", {})
	var registration_id: String = str(event_descriptor.get("facts", {}).get("registration", ""))
	var window_id: String = str(event_descriptor.get("source", ""))
	var previewed: Dictionary = preview_reopen(world.state, registration_id, window_id)
	if not previewed.ok or _fact(world.state, registration_id).changes.request != original_request: return previewed if not previewed.ok else _error("Wrong original request")
	var descriptor: Dictionary = previewed.descriptor
	if str(descriptor.get("call", "")).is_empty(): return _error("Legacy prayer sources require ORIGINS before formal event reopening")
	if not issuers.has("events") or issuers.events != world.state.event_system.version: return _error("Event reopening issuer was not declared")
	world.stage_current(); world.stage_collections(["applied_authorizations"])
	var parents: Array = [descriptor.source, window_id, result_id]
	var authorized: String = world.introduce_fact("prayer_reopen_authorized", descriptor.domain, descriptor.subjects.petitioner, descriptor.actors, parents, {"issuer": "events", "version": world.state.event_system.version, "parent": descriptor.source}, [], [], owner)
	if authorized.is_empty(): return _error("Could not record the exact reopening authority")
	var changes: Dictionary = {"issuer": "events", "version": world.state.event_system.version, "need": catalog.tables.prayers[descriptor.content_id].need, "domain": descriptor.domain, "institution": descriptor.institution, "actors": descriptor.actors.duplicate(), "subjects": descriptor.subjects.duplicate(true), "facts": descriptor.facts.duplicate(true), "crisis": {}, "reopen": authorized, "call": str(descriptor.get("call", ""))}
	if descriptor.has("record_knowledge"): changes["record_knowledge"] = descriptor.record_knowledge
	if not descriptor.crisis.is_empty(): changes.crisis = {"source": descriptor.crisis.source, "due": descriptor.crisis.due}
	var situation_parents: Array = [authorized, descriptor.call] + _roots(descriptor.facts)
	if descriptor.has("record_knowledge") and not descriptor.record_knowledge in situation_parents:
		situation_parents.append(descriptor.record_knowledge)
	var source: String = world.introduce_fact("prayer_situation", descriptor.domain, descriptor.subjects.petitioner, descriptor.actors, situation_parents, changes, [], [], owner)
	if source.is_empty(): return _error("Could not record the same reopened situation")
	# Replace the expired request inside this transaction before reserving its
	# replacement. A full candidate pool must not charge a second slot for the
	# same request; any later failure restores the original card and holds.
	_close(world, original_request, "event_reopened", result_id)
	if not world.fix_prayer_source(source, owner) or not _import(world, owner): return _error("Could not fix the same reopened situation")
	var fixed: Dictionary = _fact(world.state, _authorization(world.state, "prayer/source/" + source))
	var request: String = fixed.changes.candidate.id
	Store.put(world.state.applied_authorizations, "prayer/event_reopen/" + PrayerRules.sourced_occurrence_key(world.state, descriptor), result_id)
	var offered: Array = world.state.prayer_system.offered
	var position: int = offered.find(original_request)
	if position >= 0: offered[position] = request
	elif offered.size() < catalog.integer("prayer_offer_limit"): offered.append(request)
	if not request in owner.context.background_ids: owner.context.background_ids.append(request)
	return {"ok": true, "request": request, "offered": request in offered}
