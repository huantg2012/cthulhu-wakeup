extends RefCounted
## Identity recognition and individual calls. This module does not schedule roots.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const SCHEMA: int = 1
const ID: String = "prayer_knowledge"
const TABLES: Array[String] = ["prayer_addressing_modes", "prayer_knowledge_rules", "prayer_origin_rules", "prayer_root_rules"]

static func version(content: RefCounted) -> String:
	var parts: Array = ["knowledge/2", content.version]
	for table: String in TABLES:
		if not content.tables.has(table) or not content.extension_versions.has(table): return ""
		parts.append(content.extension_versions[table])
	return "/".join(parts)

static func _canonical(value: Variant) -> String:
	return JSON.stringify(History.export_value(value), "", true, true)

static func _identity(state: Dictionary, seed: String) -> String:
	var origins: Array = []
	var domains: Array = state.domains.keys(); domains.sort()
	for domain: String in domains: origins.append([domain, state.domains[domain].origin])
	return "DEITY/" + _canonical(["world/1", seed, origins]).sha256_text()

static func install(world: RefCounted) -> bool:
	var policy: String = version(world.catalog)
	if policy.is_empty(): return false
	if world.state.has(ID): return world.state[ID].version == policy
	world.stage_collections([ID])
	var seed: String = str(world.randoms.generation.seed)
	world.state[ID] = {"schema": SCHEMA, "version": policy, "seed": seed, "identity": _identity(world.state, seed), "heads": {}}
	return true

static func _number(source: String) -> int:
	return int(source.trim_prefix("FACT-")) if source.begins_with("FACT-") else -1

static func _fact(state: Dictionary, source: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.facts, source): return Store.entry(state.facts, source)
	if reader != null:
		var found: Dictionary = reader.fact(source)
		if found.get("ok", false): return found.item
	return {}

static func _person(state: Dictionary, person: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.npcs, person): return Store.entry(state.npcs, person)
	if reader != null:
		var found: Dictionary = reader.entity("npcs", person)
		if found.get("ok", false): return found.item
	return {}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _managed(world: RefCounted, owner: Object) -> bool:
	return owner != null and world._driver_allowed(owner) and world.transaction != null and not world.participant_read and world.state.has(ID)

static func capture(world: RefCounted, owner: Object) -> Dictionary:
	if not _managed(world, owner): return {}
	var bootstrap: bool = world.state.turn == 0 and Store.size(owner.context.receipts) == 0
	var phase: Variant = "bootstrap" if bootstrap else 4
	if not bootstrap and owner.context.phase != "evolution": return {}
	return {"turn": int(world.state.turn), "phase": phase, "commit_seq": int(world.transaction.sequence), "fact_cutoff": int(world.transaction.base_state.next_fact) - 1}

static func known(state: Dictionary, person: String, snapshot: Dictionary = {}, reader: RefCounted = null) -> Dictionary:
	if reader != null and reader.has_method("identity_knowledge"): return reader.identity_knowledge(person, snapshot)
	if not state.has(ID): return {"known": false}
	var entry: Dictionary = state[ID].heads.get(person, {})
	if entry.is_empty():
		var original: String = str(Store.entry(state.get("applied_authorizations", {}), "knowledge/person/" + person, ""))
		if not original.is_empty(): entry = {"source": original, "position": _acquisition_position(state, _fact(state, original))}
	if entry.is_empty(): return {"known": false, "identity": state[ID].identity}
	var position: Dictionary = entry.position
	if not snapshot.is_empty() and (int(position.commit_seq) > int(snapshot.get("commit_seq", -1)) or _number(entry.source) > int(snapshot.get("fact_cutoff", -1)) or int(position.turn) > int(snapshot.get("turn", -1))): return {"known": false, "identity": state[ID].identity}
	return {"known": true, "identity": state[ID].identity, "source": entry.source, "position": position.duplicate(true)}

static func recognition(world: RefCounted, person: String, rule: String, owner: Object) -> Dictionary:
	if not _managed(world, owner): return {}
	return {"identity": world.state[ID].identity, "person": person, "rule": rule, "position": {"turn": int(world.state.turn), "phase": owner.context.phase, "commit_seq": int(world.transaction.sequence) + 1, "fact_cutoff": int(world.state.next_fact)}}

static func _direct(state: Dictionary, source: String, person: String, rule: String, identity: String) -> bool:
	var fact: Dictionary = _fact(state, source)
	if fact.is_empty() or not fact.changes.get("outcome", "") in ["success", "deep"]: return false
	var marker: Variant = fact.changes.get("recognition")
	if not marker is Dictionary or marker.get("identity") != identity or marker.get("person") != person or marker.get("rule") != rule: return false
	if not marker.get("position") is Dictionary or marker.position.get("turn") != fact.turn or marker.position.get("fact_cutoff") != _number(source) or not marker.position.get("commit_seq") is int or marker.position.commit_seq < 1: return false
	if rule in ["KNOW_DREAM", "KNOW_ORACLE"]:
		return fact.kind == "power_result" and fact.actor == person and person in fact.targets and fact.changes.get("power") == ("POWER_DREAM" if rule == "KNOW_DREAM" else "POWER_ORACLE")
	if rule != "KNOW_DEVOTION" or fact.kind != "prayer_result" or fact.changes.get("prayer") != "PRAYER_08": return false
	var joined: Dictionary = _fact(state, str(marker.get("membership", "")))
	if joined.get("kind") not in ["member_enrolled", "cult_member_joined"] or joined.actor != person or joined.turn != fact.turn: return false
	for parent: String in joined.causal_parents:
		var dedication: Dictionary = _fact(state, parent)
		if dedication.get("kind") != "member_dedication" or dedication.changes.get("request") != fact.changes.get("request"): continue
		for cause: String in dedication.causal_parents:
			if cause in fact.causal_parents: return true
	return false

static func _remember(world: RefCounted, person: String, source: String, position: Dictionary) -> void:
	world.stage_collections([ID, "applied_authorizations"])
	var key: String = "knowledge/person/" + person
	if not Store.has(world.state.applied_authorizations, key): Store.put(world.state.applied_authorizations, key, source)
	if not world.state[ID].heads.has(person) and _person(world.state, person).get("status") != "dead":
		var original: String = Store.entry(world.state.applied_authorizations, key)
		world.state[ID].heads[person] = {"source": original, "position": position.duplicate(true) if original == source else _acquisition_position(world.state, _fact(world.state, original))}
	world._know(person, source)

static func retire(world: RefCounted, person: String) -> void:
	if world.state.has(ID) and world.state[ID].heads.has(person):
		world.stage_collections([ID]); world.state[ID].heads.erase(person)

static func identify(world: RefCounted, person: String, result_source: String, rule: String, owner: Object) -> Dictionary:
	if not _managed(world, owner) or not world.catalog.tables.prayer_knowledge_rules.has(rule): return _fail("Identity recognition capability unavailable")
	var identity: String = world.state[ID].identity
	if not _direct(world.state, result_source, person, rule, identity): return _fail("Identity recognition lacks its actual perceived result")
	var once: String = "knowledge/direct/" + result_source + "/" + person
	if Store.has(world.state.applied_authorizations, once): return {"ok": true, "source": Store.entry(world.state.applied_authorizations, once)}
	var result: Dictionary = _fact(world.state, result_source)
	var position: Dictionary = result.changes.recognition.position.duplicate(true)
	var fact: String = world._record("deity_identified", result.domain, person, [person], [result_source], {"issuer": ID, "version": version(world.catalog), "person": person, "identity": identity, "source": result_source, "recognition": result.changes.recognition.duplicate(true), "acquired_turn": int(world.state.turn)})
	position.fact_cutoff = _number(fact)
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, once, fact)
	_remember(world, person, fact, position)
	return {"ok": true, "source": fact}

static func _primary(content: String) -> String:
	return {"PRAYER_01": "condition", "PRAYER_02": "conflict", "PRAYER_03": "pursuit", "PRAYER_04": "record", "PRAYER_05": "ritual", "PRAYER_06": "contract", "PRAYER_07": "memory", "PRAYER_08": "contact", "PRAYER_09": "contact", "PRAYER_10": "conflict", "PRAYER_11": "claim", "PRAYER_12": "exception"}.get(content, "")

static func _root(state: Dictionary, source: String, reader: RefCounted = null) -> Dictionary:
	var fact: Dictionary = _fact(state, source, reader)
	# Exposure/publication is a wrapper, not an independent original occurrence.
	if fact.get("kind") == "exposure":
		for parent: String in fact.get("causal_parents", []):
			var original: Dictionary = _fact(state, parent, reader)
			if original.get("kind") in ["prayer_fact", "miracle", "exception", "law_observation"]: return original
	return fact

static func _root_signature(fact: Dictionary) -> Dictionary:
	var result: Dictionary = fact.duplicate(true)
	result.erase("id")
	return result

const FACT_FIELDS: Dictionary = {"PRAYER_01": ["condition", "relation"], "PRAYER_02": ["relation", "conflict"], "PRAYER_03": ["pursuit"], "PRAYER_04": ["record"], "PRAYER_05": ["ritual"], "PRAYER_06": ["contract"], "PRAYER_07": ["memory", "relations"], "PRAYER_08": ["contact"], "PRAYER_09": ["contact"], "PRAYER_10": ["conflict", "relation"], "PRAYER_11": ["claim"], "PRAYER_12": ["exception"]}

static func _keys(data: Dictionary, expected: Array) -> bool:
	var actual: Array = data.keys(); actual.sort()
	var wanted: Array = expected.duplicate(); wanted.sort()
	return actual == wanted

static func _binding(state: Dictionary, descriptor: Dictionary, content: RefCounted, reader: RefCounted = null) -> Dictionary:
	var prayer: String = str(descriptor.get("content_id", ""))
	if not content.tables.prayer_origin_rules.has(prayer) or not descriptor.get("subjects") is Dictionary or not descriptor.get("facts") is Dictionary: return {}
	var rule: Dictionary = content.tables.prayer_origin_rules[prayer]
	for field: Variant in descriptor.facts:
		if not field in FACT_FIELDS.get(prayer, []): return {}
	var person: String = str(descriptor.subjects.get("petitioner", ""))
	var domain: String = str(descriptor.get("domain", ""))
	var original: Dictionary = _root(state, str(descriptor.facts.get(_primary(prayer), "")), reader)
	if original.is_empty() or original.domain != domain or not str(original.kind) in str(rule.root_kind).split("|"): return {}
	var roots: Array = []
	var signatures: Array = []
	var unique_signatures: Dictionary = {}
	for value: Variant in descriptor.facts.values():
		var values: Array = [value] if value is String else value
		for source: Variant in values:
			if not source is String: return {}
			var fact: Dictionary = _root(state, source, reader)
			if fact.is_empty() or fact.domain != domain: return {}
			var signature: Dictionary = _root_signature(fact)
			var fingerprint: String = _canonical(signature)
			if not unique_signatures.has(fingerprint):
				unique_signatures[fingerprint] = true
				roots.append(fact.id); signatures.append(signature)
	roots.sort()
	signatures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _canonical(a) < _canonical(b))
	var occurrence: String = "prayer/occurrence2/" + _canonical([domain, rule.root_rule, signatures, person, rule.need, _root_signature(original)]).sha256_text()
	var proof: String = str(descriptor.get("record_knowledge", ""))
	if not proof.is_empty():
		var known_record: Dictionary = _root(state, proof, reader)
		if prayer != "PRAYER_04" or known_record.get("id") != original.id: return {}
	return {"person": person, "domain": domain, "source": original.id, "roots": roots, "need": rule.need, "rule": rule, "occurrence": occurrence}

static func _new_contact(state: Dictionary, root: Dictionary, person: String, sample: Dictionary, content: RefCounted, reader: RefCounted = null) -> bool:
	if root.get("kind") == "dying_condition" and root.changes.get("rule") == "kinship_rescue_scene":
		if root.changes.get("petitioner") != person or root.actor != person or root.turn != sample.turn or root.changes.get("snapshot") != sample or root.changes.get("relationship") != "family": return false
		for participant: String in [person, str(root.changes.get("patient", ""))]:
			var npc: Dictionary = _person(state, participant, reader)
			if npc.is_empty() or not participant in root.targets or npc.domain != root.domain or _number(str(npc.identity_source)) > int(sample.fact_cutoff): return false
		return true
	if not root.get("kind") in ["devotion_contact", "barrier_contact"] or root.changes.get("subject") != person or root.actor != person or root.turn != sample.turn: return false
	for parent: String in root.causal_parents:
		var selected: Dictionary = _fact(state, parent, reader)
		if selected.get("kind") != "prayer_contact_selected": continue
		var data: Dictionary = selected.changes
		if data.get("version") != "producer/1/" + version(content) or data.get("person") != person or data.get("snapshot") != sample or not data.get("proposal") is Dictionary or selected.turn != root.turn or selected.domain != root.domain: return false
		var prayer: String = "PRAYER_08" if root.kind == "devotion_contact" else "PRAYER_09"
		if data.proposal.get("content_id") != prayer or data.proposal.get("institution") != root.changes.get("institution") or data.proposal.get("domain") != root.domain or data.get("position", {}).get("commit_seq") != int(sample.commit_seq) + 1: return false
		if prayer == "PRAYER_09":
			var wall: String = str(data.proposal.get("barrier_source", ""))
			if wall.is_empty() or wall != root.changes.get("barrier_source") or _number(wall) > int(sample.fact_cutoff) or not wall in selected.causal_parents or _fact(state, wall, reader).get("domain") != root.domain: return false
		var petitioner: String = str(data.proposal.get("petitioner", ""))
		if not petitioner.is_empty(): return petitioner == person
		# The only post-snapshot person is the actual nominee whose population
		# receipt precedes this contact in the same transaction.
		for cause: String in selected.causal_parents:
			var nomination: Dictionary = _fact(state, cause, reader)
			if nomination.get("kind") == "nomination" and nomination.actor == person and nomination.domain == root.domain and nomination.turn == root.turn and nomination.changes.get("from_group") == "unnamed_nonfollowers" and _number(cause) > int(sample.fact_cutoff) and _number(cause) < _number(selected.id): return true
		return false
	return false

static func _record_known_at(state: Dictionary, person: String, proof: String, sample: Dictionary, reader: RefCounted = null) -> bool:
	var key: String = "producer/knowledge/" + person + "/" + proof
	var acquired: String = str(Store.entry(state.get("applied_authorizations", {}), key, ""))
	if reader != null and reader.has_method("authorization"):
		var indexed: Dictionary = reader.authorization(key)
		if indexed.get("ok", false): acquired = str(indexed.get("source", ""))
	var fact: Dictionary = _fact(state, acquired, reader)
	return fact.get("kind") == "prayer_producer_update" and fact.changes.get("collection") == "dirty" and fact.changes.get("key") == person and fact.changes.get("after") == proof and proof in fact.causal_parents and _number(acquired) <= int(sample.fact_cutoff) and fact.turn <= int(sample.turn)

static func _mode(state: Dictionary, occurrence: String, knowledge: Dictionary, content: RefCounted) -> String:
	var choices: Array = ["undirected"]
	if knowledge.get("known", false): choices.append("directed")
	choices.sort()
	var sample: int = int(("prayer-addressing/1/" + state[ID].seed + "/" + version(content) + "/" + occurrence).sha256_text().substr(0, 15).hex_to_int())
	return choices[sample % choices.size()]

static func create_call(world: RefCounted, descriptor: Dictionary, snapshot: Dictionary, owner: Object) -> Dictionary:
	if world.transaction == null:
		if owner == null or not world._driver_allowed(owner) or world.state.turn != 0 or Store.size(owner.context.receipts) != 0: return _fail("Calls require a managed evolution or initialization transaction")
		var initial: RefCounted = Transaction.new(world, owner.context, owner.commit_sequence)
		if not initial.activate(): return _fail("Call initialization transaction unavailable")
		var result: Dictionary = create_call(world, descriptor, capture(world, owner) if snapshot.is_empty() else snapshot, owner)
		if result.ok and initial.validate_world().is_empty():
			initial.publish(); owner.context = initial.context
		else:
			initial.rollback(); return _fail(result.get("error", "Call initialization audit failed"))
		return result
	if not _managed(world, owner) or snapshot.is_empty() or snapshot != capture(world, owner): return _fail("Call sampling position is not the current frozen input")
	var binding: Dictionary = _binding(world.state, descriptor, world.catalog)
	if binding.is_empty(): return _fail("Call has no canonical authored situation")
	var person: Dictionary = _person(world.state, binding.person)
	if person.is_empty() or person.status != "active" or person.domain != binding.domain: return _fail("Call petitioner is not active in its original domain")
	for root: String in binding.roots:
		if (_number(root) > int(snapshot.fact_cutoff) and not _new_contact(world.state, _fact(world.state, root), binding.person, snapshot, world.catalog)) or Store.has(world.state.invalid_records, root): return _fail("Call root was not available at sampling")
	var record_proof: String = str(descriptor.get("record_knowledge", ""))
	if not record_proof.is_empty() and (_number(record_proof) > int(snapshot.fact_cutoff) or not world.history.knows(world.state, binding.person, record_proof) or not _record_known_at(world.state, binding.person, record_proof, snapshot) or Store.has(world.state.invalid_records, record_proof)): return _fail("Known-record selector lacks its actual sampled knowledge proof")
	var once: String = "knowledge/call/" + binding.occurrence
	if Store.has(world.state.applied_authorizations, once):
		var prior: String = Store.entry(world.state.applied_authorizations, once)
		return {"ok": true, "source": prior, "call": prior, "addressing": _fact(world.state, prior).changes.addressing}
	if binding.rule.get("exclusive_group", "") == "conflict_petitioner":
		var key: String = "knowledge/need/" + _canonical([_root_signature(_fact(world.state, binding.source)), binding.person]).sha256_text()
		var selected: String = str(Store.entry(world.state.applied_authorizations, key, ""))
		if selected.is_empty():
			var needs: Array = []
			for candidate: String in ["recognition", "judgment"]:
				if candidate in person.get("need_tags", []): needs.append(candidate)
			if needs.is_empty(): return _fail("Conflict petitioner has no applicable current need")
			var index: int = int(("prayer-need/1/" + world.state[ID].seed + "/" + key).sha256_text().substr(0, 15).hex_to_int()) % needs.size()
			if binding.need != needs[index]: return _fail("Conflict occurrence selected its other need")
			selected = world._record("prayer_need_selected", binding.domain, binding.person, [binding.person], [binding.source], {"person": binding.person, "conflict": binding.source, "need": binding.need, "snapshot": snapshot})
			world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, key, selected)
		elif _fact(world.state, selected).changes.get("need") != binding.need: return _fail("Conflict occurrence already selected its other need")
	var knowledge: Dictionary = known(world.state, binding.person, snapshot)
	var mode: String = _mode(world.state, binding.occurrence, knowledge, world.catalog)
	var parents: Array = binding.roots.duplicate()
	if not record_proof.is_empty() and not record_proof in parents: parents.append(record_proof)
	if mode == "directed": parents.append(knowledge.source)
	var data: Dictionary = {"issuer": ID, "version": version(world.catalog), "occurrence": binding.occurrence, "source": binding.source, "petitioner": binding.person, "need": binding.need, "addressing": mode, "identity": world.state[ID].identity if mode == "directed" else "", "knowledge": knowledge.source if mode == "directed" else "", "intent_rule": world.catalog.tables.prayer_addressing_modes[mode].intent_rule, "snapshot": snapshot.duplicate(true)}
	var canonical_descriptor: Dictionary = {}
	for field: String in ["content_id", "domain", "institution", "actors", "subjects", "facts", "crisis", "record_knowledge"]:
		if descriptor.has(field): canonical_descriptor[field] = descriptor[field].duplicate(true) if descriptor[field] is Dictionary or descriptor[field] is Array else descriptor[field]
	var basis: String = world._record("prayer_call_basis", binding.domain, binding.person, [binding.person], parents, {"descriptor": canonical_descriptor, "snapshot": snapshot.duplicate(true), "version": version(world.catalog)})
	parents.append(basis)
	var source: String = world._record("prayer_call", binding.domain, binding.person, [binding.person], parents, data)
	world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, once, source)
	return {"ok": true, "source": source, "call": source, "addressing": mode}

static func validate_call(state: Dictionary, source: String, descriptor: Dictionary, content: RefCounted, reader: RefCounted = null) -> bool:
	if not state.has(ID): return false
	var fact: Dictionary = _fact(state, source, reader)
	var binding: Dictionary = _binding(state, descriptor, content, reader)
	if binding.is_empty() or fact.get("kind") != "prayer_call" or fact.actor != binding.person or fact.domain != binding.domain: return false
	var data: Dictionary = fact.changes
	if not _keys(data, ["issuer", "version", "occurrence", "source", "petitioner", "need", "addressing", "identity", "knowledge", "intent_rule", "snapshot"]) or data.get("issuer") != ID or data.get("version") != version(content) or data.get("occurrence") != binding.occurrence or data.get("source") != binding.source or data.get("petitioner") != binding.person or data.get("need") != binding.need or not data.get("snapshot") is Dictionary: return false
	var sample: Dictionary = data.snapshot
	if sample.keys().size() != 4 or not sample.get("turn") is int or not sample.get("commit_seq") is int or not sample.get("fact_cutoff") is int or not sample.get("phase") in [4, "bootstrap"] or sample.turn > fact.turn or sample.fact_cutoff >= _number(source) or sample.commit_seq < 0: return false
	for root: String in binding.roots:
		if not root in fact.causal_parents or (_number(root) > sample.fact_cutoff and not _new_contact(state, _fact(state, root, reader), binding.person, sample, content, reader)): return false
	var proof: String = str(descriptor.get("record_knowledge", ""))
	if not proof.is_empty():
		var npc: Dictionary = _person(state, binding.person, reader)
		var knows_proof: bool = reader.knows(binding.person, proof) if reader != null and reader.has_method("knows") else History.has(npc.get("known_facts", []), proof)
		if _number(proof) > sample.fact_cutoff or not proof in fact.causal_parents or not knows_proof or not _record_known_at(state, binding.person, proof, sample, reader): return false
	var knowledge: Dictionary = known(state, binding.person, sample, reader)
	var mode: String = _mode(state, binding.occurrence, knowledge, content)
	if data.get("addressing") != mode or data.get("intent_rule") != content.tables.prayer_addressing_modes[mode].intent_rule: return false
	if mode == "directed":
		if data.get("identity") != state[ID].identity or data.get("knowledge") != knowledge.get("source") or not data.knowledge in fact.causal_parents: return false
	elif data.get("identity") != "" or data.get("knowledge") != "": return false
	var basis_valid: bool = false
	for parent: String in fact.causal_parents:
		var basis: Dictionary = _fact(state, parent, reader)
		if basis.get("kind") != "prayer_call_basis": continue
		if basis.changes.get("snapshot") != sample or basis.changes.get("version") != version(content): return false
		var original_binding: Dictionary = _binding(state, basis.changes.get("descriptor", {}), content, reader)
		if original_binding.get("occurrence") != binding.occurrence: return false
		for field: String in ["content_id", "domain", "institution", "actors", "subjects", "facts", "record_knowledge"]:
			if basis.changes.descriptor.get(field) != descriptor.get(field): return false
		basis_valid = true
	if not basis_valid: return false
	if reader != null and reader.has_method("authorization"):
		var indexed: Dictionary = reader.authorization("knowledge/call/" + binding.occurrence)
		return indexed.get("ok", false) and indexed.get("source") == source
	return Store.entry(state.get("applied_authorizations", {}), "knowledge/call/" + binding.occurrence, "") == source

static func _notice_objects(world: RefCounted, selection: Dictionary) -> bool:
	var state: Dictionary = world.state
	var sender: Dictionary = _person(state, str(selection.get("sender", "")))
	var recipient: Dictionary = _person(state, str(selection.get("recipient", "")))
	if sender.is_empty() or recipient.is_empty() or sender.id == recipient.id or sender.status != "active" or recipient.status != "active" or sender.domain != recipient.domain or sender.domain != selection.get("domain"): return false
	var knowledge: Dictionary = known(state, sender.id, selection.snapshot)
	if not knowledge.get("known", false) or knowledge.source != selection.get("knowledge"): return false
	var relation: String = str(selection.get("relation", ""))
	if Store.has(state.invalid_records, relation) or _number(relation) > int(selection.snapshot.fact_cutoff): return false
	var actual: Dictionary = world.history.relation(sender.id, recipient.id, relation)
	if actual.is_empty(): actual = world.history.relation(recipient.id, sender.id, relation)
	if not actual.get("kind", "") in ["support", "cooperation"]: return false
	if sender.institution == recipient.institution: return selection.get("route") == "" and state.institutions.has(sender.institution)
	return selection.get("route") == recipient.institution and state.institutions.has(sender.institution) and state.institutions.has(recipient.institution) and recipient.institution in state.institutions[sender.institution].links

static func authorize_notice(world: RefCounted, selection: Dictionary, coordinator: Object, owner: Object) -> Dictionary:
	if not _managed(world, owner) or owner.context.phase != "evolution" or coordinator == null or not owner._participants.has("events") or owner._participants.events.instance != coordinator or coordinator.get_script().resource_path != "res://src/game/events.gd": return _fail("Identity notice needs the registered managed Events coordinator")
	if not _keys(selection, ["root_rule", "domain", "snapshot", "once", "sender", "recipient", "relation", "route", "knowledge"]) or selection.root_rule != "ROOT_IDENTITY_NOTICE" or selection.snapshot != capture(world, owner): return _fail("Identity notice selection is not bound to this frozen input")
	var domain: String = str(selection.domain)
	var simulation: Dictionary = world.transaction.base_state.get("simulation", {})
	if not simulation.get("cursors", {}).has(domain): return _fail("Identity notice has no shared opportunity cursor")
	var tick: int = int(simulation.cursors[domain].next_turn)
	if tick > int(selection.snapshot.turn) or selection.once != "ROOT_IDENTITY_NOTICE/" + domain + "/" + str(tick) + "/0": return _fail("Identity notice is not the selected shared tick/trial")
	var key: String = "knowledge/notice-selection/" + str(selection.once)
	if Store.has(world.state.applied_authorizations, key):
		var prior: String = Store.entry(world.state.applied_authorizations, key)
		if _fact(world.state, prior).changes.get("selection") != selection: return _fail("Identity notice opportunity was used for another selection")
		return {"ok": true, "authorization": prior}
	if not _notice_objects(world, selection): return _fail("Identity notice has no current informed sender, relationship or route")
	var parents: Array = [selection.knowledge, selection.relation]
	var route_basis: Array = []
	for person: String in [selection.sender, selection.recipient]:
		var institution: String = _person(world.state, person).institution
		var source: String = world.state.institutions[institution].source
		if not source in route_basis: route_basis.append(source); parents.append(source)
	var position: Dictionary = {"turn": int(world.state.turn), "phase": "evolution", "commit_seq": int(world.transaction.sequence) + 1, "fact_cutoff": int(world.state.next_fact)}
	var source: String = world._record("identity_notice_selected", domain, selection.sender, [selection.sender, selection.recipient], parents, {"issuer": "events", "version": coordinator.version, "selection": selection.duplicate(true), "route_basis": route_basis, "position": position})
	world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, key, source)
	return {"ok": true, "authorization": source}

static func tell(world: RefCounted, authorization: String, owner: Object) -> Dictionary:
	if not _managed(world, owner) or owner.context.phase != "evolution": return _fail("Identity notice requires its managed evolution transaction")
	var fact: Dictionary = _fact(world.state, authorization)
	if fact.get("kind") != "identity_notice_selected" or not owner._participants.has("events") or fact.changes.get("issuer") != "events" or fact.changes.get("version") != owner._participants.events.instance.version: return _fail("Identity notice selection was not issued by the coordinator")
	if _number(authorization) < int(world.transaction.base_state.next_fact) or fact.changes.get("position", {}).get("commit_seq") != int(world.transaction.sequence) + 1: return _fail("Identity notice authorization cannot cross transaction boundaries")
	var selection: Dictionary = fact.changes.get("selection", {})
	if Store.entry(world.state.applied_authorizations, "knowledge/notice-selection/" + str(selection.get("once", "")), "") != authorization: return _fail("Identity notice selection is not the original committed opportunity")
	var key: String = "knowledge/notice/" + authorization
	if Store.has(world.state.applied_authorizations, key): return {"ok": true, "source": Store.entry(world.state.applied_authorizations, key)}
	if fact.turn != world.state.turn or selection.get("snapshot") != capture(world, owner) or not _notice_objects(world, selection): return _fail("Identity notice original parties or sampling position changed")
	var parents: Array = [authorization, selection.knowledge, selection.relation]
	parents.append_array(fact.changes.route_basis)
	var received: String = world._record("deity_identity_received", selection.domain, selection.sender, [selection.recipient], parents, {"issuer": ID, "version": version(world.catalog), "sender": selection.sender, "person": selection.recipient, "identity": world.state[ID].identity, "source": selection.knowledge, "relation": selection.relation, "route": selection.route, "acquired_turn": int(world.state.turn)})
	var position: Dictionary = fact.changes.position.duplicate(true); position.fact_cutoff = _number(received)
	world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, key, received)
	_remember(world, selection.recipient, received, position)
	return {"ok": true, "source": received}

static func _acquisition_position(state: Dictionary, fact: Dictionary) -> Dictionary:
	var position: Dictionary = {}
	if fact.get("kind") == "deity_identified": position = fact.get("changes", {}).get("recognition", {}).get("position", {}).duplicate(true)
	elif fact.get("kind") == "deity_identity_received":
		for parent: String in fact.get("causal_parents", []):
			var selected: Dictionary = _fact(state, parent)
			if selected.get("kind") == "identity_notice_selected": position = selected.changes.get("position", {}).duplicate(true); break
	if not position.is_empty(): position.fact_cutoff = _number(str(fact.get("id", "")))
	return position

static func _acquisition_valid(state: Dictionary, fact: Dictionary, content: RefCounted) -> bool:
	var data: Dictionary = fact.get("changes", {})
	var person: String = str(data.get("person", ""))
	if not Store.has(state.npcs, person) or data.get("issuer") != ID or data.get("version") != version(content) or data.get("identity") != state[ID].identity or data.get("acquired_turn") != fact.turn or not person in fact.targets: return false
	if fact.kind == "deity_identified":
		if not _keys(data, ["issuer", "version", "person", "identity", "source", "recognition", "acquired_turn"]) or not data.get("recognition") is Dictionary: return false
		var original: Dictionary = _fact(state, str(data.get("source", "")))
		if original.is_empty() or not data.source in fact.causal_parents or original.changes.get("recognition") != data.recognition or not _direct(state, data.source, person, str(data.recognition.get("rule", "")), state[ID].identity): return false
		return Store.entry(state.applied_authorizations, "knowledge/direct/" + data.source + "/" + person, "") == fact.id
	if fact.kind != "deity_identity_received" or not _keys(data, ["issuer", "version", "sender", "person", "identity", "source", "relation", "route", "acquired_turn"]): return false
	var sender_fact: Dictionary = _fact(state, str(data.get("source", "")))
	if not sender_fact.get("kind") in ["deity_identified", "deity_identity_received"] or sender_fact.changes.get("person") != data.get("sender") or sender_fact.changes.get("identity") != data.identity or not data.source in fact.causal_parents: return false
	var relation: Dictionary = _fact(state, str(data.get("relation", "")))
	if not relation.get("kind") in ["relationship", "initial_relationship"] or not relation.changes.get("kind", relation.changes.get("type", "")) in ["support", "cooperation"] or not data.relation in fact.causal_parents: return false
	var parties: Array = relation.get("targets", []).duplicate(); parties.append(str(relation.get("actor", "")))
	if not person in parties or not data.sender in parties: return false
	for parent: String in fact.causal_parents:
		var selected: Dictionary = _fact(state, parent)
		if selected.get("kind") != "identity_notice_selected": continue
		var pick: Dictionary = selected.changes.get("selection", {})
		if selected.changes.get("issuer") != "events" or selected.changes.get("version") != state.get("event_system", {}).get("version") or pick.get("sender") != data.sender or pick.get("recipient") != person or pick.get("knowledge") != data.source or pick.get("relation") != data.relation or pick.get("route") != data.route or pick.get("domain") != fact.domain or selected.turn != fact.turn: return false
		if not pick.get("snapshot") is Dictionary or _number(data.source) > int(pick.snapshot.get("fact_cutoff", -1)): return false
		if Store.entry(state.applied_authorizations, "knowledge/notice-selection/" + str(pick.get("once", "")), "") != selected.id: return false
		return Store.entry(state.applied_authorizations, "knowledge/notice/" + selected.id, "") == fact.id
	return false

static func _facts_since(state: Dictionary, first: int) -> Array:
	var result: Array = []
	if first == 0:
		for fact: Dictionary in Store.values(state.facts): result.append(fact)
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	else:
		for number: int in range(first, int(state.next_fact)):
			var fact: Dictionary = _fact(state, "FACT-%08d" % number)
			if not fact.is_empty(): result.append(fact)
	return result

static func _basis_descriptor(state: Dictionary, call: Dictionary) -> Dictionary:
	for parent: String in call.get("causal_parents", []):
		var fact: Dictionary = _fact(state, parent)
		if fact.get("kind") == "prayer_call_basis": return fact.changes.get("descriptor", {})
	return {}

static func _fact_indexes(state: Dictionary, fact: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	var data: Dictionary = fact.get("changes", {})
	match str(fact.kind):
		"deity_identified": keys["knowledge/direct/" + str(data.get("source", "")) + "/" + str(data.get("person", ""))] = fact.id
		"deity_identity_received":
			for parent: String in fact.causal_parents:
				if _fact(state, parent).get("kind") == "identity_notice_selected": keys["knowledge/notice/" + parent] = fact.id
		"identity_notice_selected": keys["knowledge/notice-selection/" + str(data.get("selection", {}).get("once", ""))] = fact.id
		"prayer_call": keys["knowledge/call/" + str(data.get("occurrence", ""))] = fact.id
		"prayer_need_selected":
			var conflict: Dictionary = _fact(state, str(data.get("conflict", "")))
			keys["knowledge/need/" + _canonical([_root_signature(conflict), str(data.get("person", ""))]).sha256_text()] = fact.id
	return keys

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not state.has(ID):
		if trusted.has(ID) or state.has("power_system") or state.has("prayer_system"): return ["Identity knowledge state disappeared"]
		return []
	var ledger: Variant = state[ID]
	if not ledger is Dictionary or not _keys(ledger, ["schema", "version", "seed", "identity", "heads"]) or ledger.get("schema") != SCHEMA or ledger.get("version") != version(content) or not ledger.get("seed") is String or ledger.get("identity") != _identity(state, str(ledger.get("seed", ""))) or not ledger.get("heads") is Dictionary: return ["Invalid identity knowledge policy"]
	if trusted.has(ID) and (ledger.identity != trusted[ID].identity or ledger.seed != trusted[ID].seed): return ["Identity knowledge changed campaign identity"]
	var first: int = int(trusted.next_fact) if trusted.has(ID) else 0
	var expected: Dictionary = trusted[ID].heads.duplicate(true) if trusted.has(ID) else {}
	var earliest: Dictionary = {}
	var indexes: Dictionary = {}
	for person: String in expected.keys():
		if _person(state, person).get("status") == "dead": expected.erase(person)
	var facts: Array = _facts_since(state, first)
	for fact: Dictionary in facts:
		for key: String in _fact_indexes(state, fact):
			if indexes.has(key): return ["Identity occurrence has more than one committed fact"]
			indexes[key] = fact.id
		if not fact.kind in ["deity_identified", "deity_identity_received"]: continue
		if not _acquisition_valid(state, fact, content): return ["Identity acquisition has no matching managed behavior or notice"]
		var person: String = fact.changes.person
		var position: Dictionary = _acquisition_position(state, fact)
		if not _keys(position, ["turn", "phase", "commit_seq", "fact_cutoff"]) or position.get("turn") != fact.turn or not position.get("commit_seq") is int or position.commit_seq < 1: return ["Invalid identity acquisition position"]
		if not History.has(Store.entry(state.npcs, person).known_facts, fact.id): return ["Identity recipient does not know its acquisition"]
		var person_key: String = "knowledge/person/" + person
		if not earliest.has(person): earliest[person] = str(Store.entry(trusted.get("applied_authorizations", {}), person_key, fact.id))
		indexes[person_key] = earliest[person]
		if Store.entry(state.applied_authorizations, person_key, "") != earliest[person]: return ["Identity first-acquisition key changed"]
		if not expected.has(person) and _person(state, person).status != "dead": expected[person] = {"source": fact.id, "position": position}
	# Restore may traverse history; ordinary commits inspect only the explicit
	# persistent-map write set, never all prior acquisition/once keys.
	var index_keys: Array = Store.keys(state.applied_authorizations) if first == 0 else Store.changed(state.applied_authorizations)
	for key: String in index_keys:
		if not key.begins_with("knowledge/"): continue
		var current: Variant = Store.entry(state.applied_authorizations, key)
		if first > 0 and Store.has(trusted.applied_authorizations, key):
			if current != Store.entry(trusted.applied_authorizations, key): return ["Committed identity occurrence index was replaced"]
		elif not indexes.has(key) or indexes[key] != current: return ["Identity occurrence index has no matching fact"]
	for key: String in indexes:
		if Store.entry(state.applied_authorizations, key, "") != indexes[key]: return ["Identity fact lost its occurrence index"]
	if ledger.heads != expected: return ["Identity current projection differs from acquisition history"]
	for person: String in ledger.heads:
		var entry: Variant = ledger.heads[person]
		if not entry is Dictionary or not _keys(entry, ["source", "position"]) or not Store.has(state.npcs, person): return ["Invalid identity current head"]
		var original: Dictionary = _fact(state, str(entry.get("source", "")))
		if original.get("changes", {}).get("person") != person or entry.get("position") != _acquisition_position(state, original): return ["Identity acquisition position changed"]
	for fact: Dictionary in facts:
		if fact.kind == "identity_notice_selected":
			var received: Dictionary = _fact(state, str(Store.entry(state.applied_authorizations, "knowledge/notice/" + fact.id, "")))
			if received.get("kind") != "deity_identity_received" or not fact.id in received.causal_parents or _acquisition_position(state, received).get("commit_seq") != fact.changes.get("position", {}).get("commit_seq"): return ["Identity notice selection was committed without its same-transaction recipient"]
		if fact.kind == "prayer_call" and not validate_call(state, fact.id, _basis_descriptor(state, fact), content): return ["Prayer call changed its original situation, mode or sampling proof"]
		if fact.kind == "prayer_call_basis":
			var binding: Dictionary = _binding(state, fact.changes.get("descriptor", {}), content)
			if binding.is_empty() or not Store.has(state.applied_authorizations, "knowledge/call/" + str(binding.get("occurrence", ""))): return ["Orphaned prayer call basis"]
	return []

static func validate_context(state: Dictionary, context: Dictionary, content: RefCounted, first_new_fact: int = 0, receipt_by_sequence: Dictionary = {}) -> Array[String]:
	if not state.has(ID): return []
	var receipts: Dictionary = receipt_by_sequence.duplicate(false)
	if first_new_fact == 0:
		for receipt: Dictionary in Store.values(context.get("receipts", {})):
			if not receipt.get("sequence") is int: return ["Knowledge context lacks commit sequence"]
			receipts[receipt.sequence] = receipt
	for fact: Dictionary in _facts_since(state, first_new_fact):
		if fact.kind in ["deity_identified", "deity_identity_received"]:
			var position: Dictionary = _acquisition_position(state, fact)
			var receipt: Dictionary = receipts.get(int(position.get("commit_seq", -1)), {})
			if receipt.is_empty() or _number(fact.id) < int(receipt.fact_before) or _number(fact.id) >= int(receipt.fact_after) or receipt.request.get("turn") != fact.turn or receipt.request.get("phase") != position.get("phase"): return ["Knowledge acquisition is outside its actual commit"]
			if fact.kind == "deity_identified":
				var source_number: int = _number(str(fact.changes.source))
				if source_number < int(receipt.fact_before) or source_number >= int(receipt.fact_after): return ["Recognition result and acquisition have different commits"]
				if fact.changes.get("recognition", {}).get("rule") == "KNOW_DEVOTION":
					var membership_number: int = _number(str(fact.changes.recognition.get("membership", "")))
					if membership_number < int(receipt.fact_before) or membership_number >= int(receipt.fact_after): return ["Devotion enrollment and recognition have different commits"]
			else:
				var selection_number: int = -1
				for parent: String in fact.causal_parents:
					if _fact(state, parent).get("kind") == "identity_notice_selected": selection_number = _number(parent); break
				if selection_number < int(receipt.fact_before) or selection_number >= int(receipt.fact_after): return ["Identity selection and recipient have different commits"]
		if fact.kind == "prayer_producer_update" and fact.changes.get("snapshot", {}).is_empty(): continue
		if fact.kind not in ["prayer_call", "identity_notice_selected", "prayer_need_selected", "prayer_dispatch_tick", "prayer_contact_selected", "prayer_producer_update"]: continue
		var sample: Dictionary = fact.changes.get("snapshot", {}) if fact.kind != "identity_notice_selected" else fact.changes.get("selection", {}).get("snapshot", {})
		if sample.get("phase") is String and sample.phase == "bootstrap":
			var first_receipt: Dictionary = receipts.get(1, {})
			var end: int = int(state.next_fact) if first_receipt.is_empty() else int(first_receipt.fact_before)
			if sample.get("commit_seq") != 0 or sample.get("turn") != 0 or fact.turn != 0 or int(sample.get("fact_cutoff", -1)) >= _number(fact.id) or _number(fact.id) >= end: return ["Invalid initialization sampling boundary"]
			continue
		var sequence: int = int(sample.get("commit_seq", -1)) + 1
		var receipt: Dictionary = receipts.get(sequence, {})
		if receipt.is_empty() or receipt.request.get("phase") != "evolution" or receipt.request.get("turn") != sample.get("turn") or int(sample.get("fact_cutoff", -1)) != int(receipt.fact_before) - 1 or _number(fact.id) < int(receipt.fact_before) or _number(fact.id) >= int(receipt.fact_after): return ["Sampling cutoff does not match the actual transaction input"]
	return []
