extends RefCounted
## Finite current origin producers. No record wrapper, witness, faith or identity
## is manufactured by selecting a known source.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const EventRules = preload("res://src/game/event_rules.gd")
const ID: String = "prayer_producers"
const SCHEMA: int = 1
const ROOTS: Dictionary = {"ROOT_KNOWN_RECORD": "PRAYER_04", "ROOT_CURRENT_RITUAL": "PRAYER_05", "ROOT_CURRENT_APPEAL": "PRAYER_08", "ROOT_CURRENT_PASSAGE": "PRAYER_09"}
const B_ROOTS: Array[String] = ["ROOT_CURRENT_RITUAL", "ROOT_CURRENT_APPEAL", "ROOT_CURRENT_PASSAGE"]

static func version(content: RefCounted) -> String:
	return "producer/1/" + Knowledge.version(content)

static func _fact(state: Dictionary, source: String, reader: RefCounted = null) -> Dictionary:
	return Knowledge._fact(state, source, reader)

static func _person(state: Dictionary, person: String, reader: RefCounted = null) -> Dictionary:
	return Knowledge._person(state, person, reader)

static func _knows(state: Dictionary, person: String, source: String, reader: RefCounted = null) -> bool:
	if reader != null and reader.has_method("knows"): return reader.knows(person, source)
	var npc: Dictionary = _person(state, person)
	return not npc.is_empty() and History.has(npc.get("known_facts", []), source)

static func _valid(state: Dictionary, source: String, reader: RefCounted = null) -> bool:
	return not _fact(state, source, reader).is_empty() and (not reader.invalidated(source) if reader != null and reader.has_method("invalidated") else not Store.has(state.invalid_records, source))

static func canonical_record(state: Dictionary, source: String, reader: RefCounted = null) -> String:
	var fact: Dictionary = _fact(state, source, reader)
	if fact.get("kind") == "exposure" and fact.causal_parents.size() == 1:
		var original: Dictionary = _fact(state, fact.causal_parents[0], reader)
		if original.get("kind") in ["exception", "prayer_fact", "miracle", "law_observation"]: return str(original.id)
	return str(fact.get("id", ""))

static func record_eligible(state: Dictionary, source: String, person: String, reader: RefCounted = null) -> bool:
	if not _valid(state, source, reader) or not _knows(state, person, source, reader): return false
	var original: String = canonical_record(state, source, reader)
	if original.is_empty() or not _valid(state, original, reader): return false
	var fact: Dictionary = _fact(state, original, reader)
	var npc: Dictionary = _person(state, person, reader)
	if fact.get("domain") != npc.get("domain"): return false
	var resolved: String = str(Store.entry(state.get("applied_authorizations", {}), "producer/resolved/" + original, ""))
	if reader != null and reader.has_method("authorization"):
		var indexed: Dictionary = reader.authorization("producer/resolved/" + original)
		if indexed.get("ok", false): resolved = str(indexed.get("source", ""))
	if not resolved.is_empty(): return false
	match str(fact.get("kind", "")):
		"exposure", "exception": return fact.changes.get("unexplained", true) != false
		"prayer_fact":
			if not fact.changes.get("tag") in ["anomaly_record", "public_anomaly"]: return false
			return not EventRules.actual_prayer(state, original, reader).is_empty()
		"miracle":
			if fact.changes.get("power") != "POWER_DREAM" or fact.actor != person or not person in fact.targets: return false
			for parent: String in fact.causal_parents:
				var result: Dictionary = _fact(state, parent, reader)
				if result.get("kind") == "power_result" and result.changes.get("power") == "POWER_DREAM" and result.actor == person and person in result.targets and result.changes.get("outcome") in ["success", "deep"]: return true
			return false
		"law_observation":
			var data: Dictionary = fact.changes
			if data.get("scene_rule") == "ROOT_COSMIC_OBSERVATION": return data.get("observer") == person and _fact(state, str(data.get("exception", "")), reader).get("kind") == "exception"
			return data.get("observer") == person and data.get("axiom_key") == "single_valued_archive" and data.get("reading_a") == "present" and data.get("reading_b") == "absent" and not str(data.get("probe", "")).is_empty() and state.domains[fact.domain].tier == "cosmic"
	return false

static func install(world: RefCounted) -> bool:
	if world.state.has(ID): return world.state[ID].version == version(world.catalog)
	var heads: Dictionary = {}
	for domain: String in world.state.domains: heads[domain] = {}
	var source: String = world._record("prayer_producer_installed", "", "", [], [], {"version": version(world.catalog)})
	world.stage_collections([ID])
	world.state[ID] = {"schema": SCHEMA, "version": version(world.catalog), "installed": source, "heads": heads, "scans": {}, "dirty": {}}
	for person: String in world.history.ids("living"):
		var npc: Dictionary = _person(world.state, person)
		for known: String in History.values(npc.known_facts): observe_knowledge(world, person, known)
	return true

static func _update(world: RefCounted, collection: String, key: String, value: Variant, parents: Array, snapshot: Dictionary = {}) -> String:
	world.stage_collections([ID])
	var target: Dictionary = world.state[ID][collection]
	var before: Variant = target.get(key)
	var domain: String = key.get_slice("|", 0) if collection == "heads" else str(_person(world.state, key).get("domain", ""))
	if collection == "heads":
		var pair: String = key.get_slice("|", 1)
		target = world.state[ID].heads[domain]; before = target.get(pair)
		if before == value: return ""
		if value == null: target.erase(pair)
		else: target[pair] = value.duplicate(true)
	else:
		if before == value: return ""
		if value == null: target.erase(key)
		else: target[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return world._record("prayer_producer_update", domain, "", [], parents, {"version": world.state[ID].version, "collection": collection, "key": key, "before": before, "after": value, "snapshot": snapshot.duplicate(true)})

static func observe_knowledge(world: RefCounted, person: String, source: String) -> void:
	if not world.state.has(ID): return
	var fact: Dictionary = _fact(world.state, source)
	if not fact.get("kind") in ["exposure", "exception", "prayer_fact", "miracle", "law_observation"]: return
	if fact.kind == "prayer_fact" and not fact.changes.get("tag") in ["anomaly_record", "public_anomaly"]: return
	var key: String = "producer/knowledge/" + person + "/" + source
	if Store.has(world.state.applied_authorizations, key): return
	var acquired: String = _update(world, "dirty", person, source, [source])
	if not acquired.is_empty():
		world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, key, acquired)

static func observe(world: RefCounted, source: String) -> void:
	if not world.state.has(ID): return
	var fact: Dictionary = _fact(world.state, source)
	if fact.get("kind") == "status_change" and fact.changes.get("to") == "dead":
		var person: String = str(fact.actor)
		_update(world, "dirty", person, null, [source]); _update(world, "scans", person, null, [source])
		for pair: String in world.state[ID].heads.get(fact.domain, {}).keys():
			if pair.begins_with(person + "/"): _update(world, "heads", fact.domain + "|" + pair, null, [source])
	elif fact.get("kind") == "anomaly_resolved":
		var original: String = canonical_record(world.state, str(fact.changes.get("source", "")))
		if not original.is_empty():
			world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, "producer/resolved/" + original, source)

static func _descriptor(state: Dictionary, person: String, content: String, source: String, proof: String = "") -> Dictionary:
	var npc: Dictionary = _person(state, person)
	var field: String = "record" if content == "PRAYER_04" else ("ritual" if content == "PRAYER_05" else "contact")
	var result: Dictionary = {"content_id": content, "domain": npc.domain, "institution": npc.institution, "actors": [person], "subjects": {"petitioner": person}, "facts": {field: source}, "crisis": {}}
	if content == "PRAYER_04" and not proof.is_empty(): result["record_knowledge"] = proof
	return result

static func _root_key(descriptor: Dictionary) -> String:
	return str(descriptor.subjects.petitioner) + "/" + str(descriptor.content_id)

static func _called(state: Dictionary, descriptor: Dictionary, content: RefCounted) -> bool:
	var binding: Dictionary = Knowledge._binding(state, descriptor, content)
	return not binding.is_empty() and Store.has(state.applied_authorizations, "knowledge/call/" + str(binding.occurrence))

static func _busy(state: Dictionary, person: String, content: String) -> bool:
	var pair: String = person + "/" + content
	var domain: String = str(_person(state, person).get("domain", ""))
	if state.get(ID, {}).get("heads", {}).get(domain, {}).has(pair): return true
	for source: String in state.get("prayer_dispatch", {}).get("pending", {}).get(domain, {}).values():
		var data: Dictionary = _fact(state, source).get("changes", {})
		if data.get("subjects", {}).get("petitioner") == person:
			if content == "PRAYER_08" and data.get("need") == "devotion": return true
			if content == "PRAYER_09" and data.get("need") == "escape": return true
			if content == "PRAYER_05" and data.get("need") == "belonging": return true
			if content == "PRAYER_04" and data.get("need") == "knowledge": return true
	for card: Dictionary in state.get("simulation", {}).get("candidates", {}).values():
		if card.get("content_id") == content and card.get("subjects", {}).get("petitioner", "") == person: return true
	return false

static func _current(state: Dictionary, descriptor: Dictionary, content: RefCounted, reader: RefCounted = null) -> bool:
	var person: Dictionary = _person(state, str(descriptor.get("subjects", {}).get("petitioner", "")), reader)
	var domain: String = str(descriptor.get("domain", "")); var institution: String = str(descriptor.get("institution", ""))
	if person.is_empty() or person.status != "active" or person.domain != domain or person.institution != institution or not state.institutions.get(institution, {}).get("active", false): return false
	if descriptor.content_id == "PRAYER_04":
		var proof: String = str(descriptor.get("record_knowledge", descriptor.facts.record))
		return record_eligible(state, proof, person.id, reader) and canonical_record(state, proof, reader) == descriptor.facts.record
	if descriptor.content_id == "PRAYER_05":
		var root: Dictionary = _fact(state, str(descriptor.facts.ritual), reader)
		return root.get("kind") == "ritual_context" and root.actor == person.id and root.changes.get("subject") == person.id and root.changes.get("institution") == institution and PrayerRules.ritual_keeper(state, person) and int(state.domains[domain].occult) + int(state.domains[domain].faith) > 0
	return false

static func prepare_existing(world: RefCounted, view: Dictionary, domain: String, sample: Dictionary) -> Dictionary:
	var result: Dictionary = {"domain": domain, "scan": {}, "remove": [], "selected": {}}
	var heads: Dictionary = view[ID].heads[domain].duplicate(true)
	var people: Array = view._history_snapshot.ids("active/" + domain); people.sort()
	var dirty: Array = view[ID].dirty.keys(); dirty.sort()
	var selected_person: String = ""
	for person: String in dirty:
		if person in people and not _busy(view, person, "PRAYER_04"): selected_person = person; break
	if selected_person.is_empty():
		var cursor_people: Array = people.duplicate()
		cursor_people.sort_custom(func(a: String, b: String) -> bool: return int(view[ID].scans.get(a, 0)) < int(view[ID].scans.get(b, 0)) if int(view[ID].scans.get(a, 0)) != int(view[ID].scans.get(b, 0)) else a < b)
		for person: String in cursor_people:
			if not _busy(view, person, "PRAYER_04"): selected_person = person; break
	if not selected_person.is_empty():
		var person: Dictionary = _person(view, selected_person)
		var page: Dictionary = view._history_snapshot.prayer_record_page(selected_person, int(sample.fact_cutoff), int(view[ID].scans.get(selected_person, 0)))
		var start: int = int(page.start); var count: int = int(page.count)
		var end: int = start + page.items.size()
		var scanned: Array = []; var chosen: Dictionary = {}; var deferred: bool = false
		for index: int in page.items.size():
			var source: String = str(page.items[index].source)
			scanned.append(source)
			var fact: Dictionary = _fact(view, source)
			if not record_eligible(view, source, selected_person): continue
			if int(fact.get("turn", sample.turn)) >= int(sample.turn): deferred = true; continue
			var descriptor: Dictionary = _descriptor(view, selected_person, "PRAYER_04", canonical_record(view, source), source)
			if _called(view, descriptor, world.catalog): continue
			for second: String in people:
				if second != selected_person:
					descriptor.actors.append(second); descriptor.subjects["second"] = second; break
			chosen = descriptor; end = start + index + 1; break
		result.scan = {"person": selected_person, "before": int(view[ID].scans.get(selected_person, 0)), "start": start, "count": count, "after": 0 if end == count else end, "checked": scanned, "head": chosen, "complete": end == count, "deferred": deferred}
		if not chosen.is_empty(): heads[_root_key(chosen)] = chosen
	var keys: Array = heads.keys(); keys.sort_custom(func(a: String, b: String) -> bool: return _order(view, heads[a], world.catalog) < _order(view, heads[b], world.catalog))
	for key: String in keys.slice(0, mini(keys.size(), world.history.page_limit)):
		var descriptor: Dictionary = heads[key]
		var binding: Dictionary = Knowledge._binding(view, descriptor, world.catalog)
		if not _current(view, descriptor, world.catalog) or _called(view, descriptor, world.catalog): result.remove.append(key); continue
		if binding.is_empty() or int(_fact(view, binding.source).get("turn", sample.turn)) >= int(sample.turn): continue
		result.selected = {"key": key, "descriptor": descriptor, "order": _order(view, descriptor, world.catalog)}; break
	return result

static func _order(state: Dictionary, descriptor: Dictionary, content: RefCounted) -> String:
	var binding: Dictionary = Knowledge._binding(state, descriptor, content)
	return "002147483647/" + str(binding.get("occurrence", "")) + "/" + str(binding.get("source", ""))

static func commit_scan(world: RefCounted, plan: Dictionary, sample: Dictionary) -> void:
	var scan: Dictionary = plan.scan
	if not scan.is_empty():
		_update(world, "scans", scan.person, scan.after, scan.checked, sample)
		if scan.complete and not scan.deferred: _update(world, "dirty", scan.person, null, scan.checked, sample)
		if not scan.head.is_empty(): _update(world, "heads", str(scan.head.domain) + "|" + _root_key(scan.head), scan.head, scan.checked, sample)
	for key: String in plan.remove: _update(world, "heads", str(plan.domain) + "|" + key, null, [], sample)

static func prepare_options(world: RefCounted, view: Dictionary, domain: String, sample: Dictionary) -> Array:
	var result: Array = []
	var people: Array = view._history_snapshot.ids("active/" + domain); people.sort()
	var tick: int = int(view.simulation.cursors[domain].next_turn)
	for root: String in B_ROOTS:
		var content: String = ROOTS[root]; var person: String = ""; var institution: String = ""; var profile: String = ""
		for id: String in people:
			var npc: Dictionary = _person(view, id)
			if _busy(view, id, content): continue
			if content == "PRAYER_05" and PrayerRules.ritual_keeper(view, npc) and int(view.domains[domain].occult) + int(view.domains[domain].faith) > 0: person = id; institution = npc.institution; break
			if content == "PRAYER_08" and not npc.get("bound_member", false): person = id; institution = npc.institution; break
			if content == "PRAYER_09" and "messenger" in npc.get("role_tags", []) and npc.institution == domain + "/propagation" and not view.institutions[npc.institution].links.is_empty(): person = id; institution = npc.institution; break
		if content == "PRAYER_09" and int(view.domains[domain].barrier) <= 0: continue
		if person.is_empty() and content in ["PRAYER_08", "PRAYER_09"]:
			var template: Dictionary = world.abstract_sim.templates["BG_CONTACT" if content == "PRAYER_08" else "BG_ESCAPE"]
			institution = domain + "/" + str(template.institution_role); profile = str(template.profile)
			if int(view.domains[domain].unnamed_nonfollowers) <= 0 or not world._profile_legal(world.catalog.tables.npc_profiles[profile], domain, institution): continue
		if institution.is_empty() or not view.institutions.get(institution, {}).get("active", false): continue
		if content == "PRAYER_09" and view.institutions[institution].links.is_empty(): continue
		var proposal: Dictionary = {"root": root, "domain": domain, "profile": profile, "institution": institution, "content_id": content, "source_ids": [view.domains[domain].origin, view.institutions[institution].source], "once_key": root + "/" + domain + "/" + str(tick) + "/0", "petitioner": person, "bootstrap": false}
		if content == "PRAYER_09":
			proposal["barrier_source"] = view.domains[domain].barrier_source
			proposal.source_ids.append(proposal.barrier_source)
		result.append({"root": root, "legacy": false, "proposal": proposal, "snapshot": sample.duplicate(true)})
	return result

static func commit_contact(world: RefCounted, person: String, proposal: Dictionary, sample: Dictionary, owner: Object, nomination: String = "") -> Dictionary:
	if not Knowledge._managed(world, owner) or sample != Knowledge.capture(world, owner) or not proposal.content_id in ["PRAYER_08", "PRAYER_09"]: return {"ok": false, "error": "Contact requires its managed frozen input"}
	var npc: Dictionary = _person(world.state, person)
	if npc.get("status") != "active" or npc.get("domain") != proposal.domain or npc.get("institution") != proposal.institution: return {"ok": false, "error": "Contact petitioner is not its real current person"}
	if proposal.content_id == "PRAYER_08" and npc.get("bound_member", false): return {"ok": false, "error": "A bound member cannot offer a new devotion"}
	if proposal.content_id == "PRAYER_09" and (int(world.state.domains[proposal.domain].barrier) <= 0 or world.state.institutions[proposal.institution].links.is_empty() or proposal.get("barrier_source", "") != world.state.domains[proposal.domain].barrier_source): return {"ok": false, "error": "Passage lost its sampled barrier or route"}
	var parents: Array = proposal.source_ids.duplicate()
	if not str(npc.get("status_source", "")).is_empty(): parents.append(npc.status_source)
	if not nomination.is_empty(): parents.append(nomination)
	var selected: String = world._record("prayer_contact_selected", proposal.domain, person, [person], world._unique_sorted(parents), {"version": version(world.catalog), "proposal": proposal.duplicate(true), "person": person, "snapshot": sample.duplicate(true), "position": {"commit_seq": int(world.transaction.sequence) + 1, "fact_before": int(world.transaction.base_state.next_fact)}})
	var details: Dictionary = {"subject": person, "institution": proposal.institution}
	if proposal.content_id == "PRAYER_09": details["barrier_source"] = proposal.barrier_source
	var root: String = world._record("devotion_contact" if proposal.content_id == "PRAYER_08" else "barrier_contact", proposal.domain, person, [person], world._unique_sorted(parents + [selected]), details)
	return materialize(world, _descriptor(world.state, person, proposal.content_id, root), sample, owner)

static func materialize(world: RefCounted, descriptor: Dictionary, sample: Dictionary, owner: Object) -> Dictionary:
	var called: Dictionary = Knowledge.create_call(world, descriptor, sample, owner)
	if not called.get("ok", false): return called
	var changes: Dictionary = {"issuer": "events", "version": world.state.event_system.version, "need": world.catalog.tables.prayers[descriptor.content_id].need, "domain": descriptor.domain, "institution": descriptor.institution, "actors": descriptor.actors.duplicate(), "subjects": descriptor.subjects.duplicate(true), "facts": descriptor.facts.duplicate(true), "crisis": descriptor.crisis.duplicate(true), "call": called.source}
	if descriptor.has("record_knowledge"): changes["record_knowledge"] = descriptor.record_knowledge
	var parents: Array = [called.source]
	for value: Variant in descriptor.facts.values():
		for source: String in ([value] if value is String else value): parents.append(source)
	if descriptor.has("record_knowledge"): parents.append(descriptor.record_knowledge)
	var source: String = world._record("prayer_situation", descriptor.domain, descriptor.subjects.petitioner, descriptor.actors, world._unique_sorted(parents), changes)
	return {"ok": true, "source": source, "descriptor": descriptor, "call": called.source}

static func commit_existing(world: RefCounted, selected: Dictionary, sample: Dictionary, owner: Object) -> Dictionary:
	var descriptor: Dictionary = selected.descriptor
	if not _current(world.state, descriptor, world.catalog): return {"ok": true, "outcome": "source_changed"}
	var result: Dictionary = materialize(world, descriptor, sample, owner)
	if not result.get("ok", false): return result
	_update(world, "heads", descriptor.domain + "|" + selected.key, null, [result.source], sample)
	var preview: Dictionary = world.preview_prayer_fix(result.source, owner)
	if not preview.ok:
		if preview.outcome == "no_action_window": world.close_prayer_source(result.source, "no_action_window", owner)
		return {"ok": true, "outcome": preview.outcome, "source": result.source}
	if not world.fix_prayer_source(result.source, owner): return {"ok": false, "error": "Admitted origin fixation failed"}
	return {"ok": true, "outcome": "fixed", "source": result.source}

static func commit(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	if not choice.get("proposal") is Dictionary or choice.get("snapshot") != Knowledge.capture(world, owner): return {"ok": false, "error": "Origin proposal lost its frozen input"}
	var proposal: Dictionary = choice.proposal; var sample: Dictionary = choice.snapshot
	if proposal.content_id == "PRAYER_05":
		var person: Dictionary = _person(world.state, proposal.petitioner)
		if not PrayerRules.ritual_keeper(world.state, person) or _busy(world.state, proposal.petitioner, "PRAYER_05"): return {"ok": true, "outcome": "source_changed"}
		var root: String = world._record("ritual_context", proposal.domain, person.id, [person.id], world._unique_sorted(proposal.source_ids + [person.status_source]), {"subject": person.id, "institution": person.institution, "turn": int(world.state.turn)})
		var descriptor: Dictionary = _descriptor(world.state, person.id, "PRAYER_05", root)
		_update(world, "heads", proposal.domain + "|" + _root_key(descriptor), descriptor, [root], sample)
		return {"ok": true, "outcome": "root_published", "source": root}
	var person: String = str(proposal.petitioner); var token: String = ""; var nomination_source: String = ""
	# A frozen choice can lose its prerequisite to an earlier intent. Reject it
	# before writing any contact; a normal empty result must not poison the turn.
	var office: Dictionary = world.state.institutions.get(str(proposal.institution), {})
	if not office.get("active", false) or office.get("domain") != proposal.domain: return {"ok": true, "outcome": "source_changed"}
	if proposal.content_id == "PRAYER_09" and (int(world.state.domains[proposal.domain].barrier) <= 0 or office.links.is_empty() or proposal.get("barrier_source", "") != world.state.domains[proposal.domain].barrier_source): return {"ok": true, "outcome": "source_changed"}
	if not person.is_empty():
		var current: Dictionary = _person(world.state, person)
		if current.get("status") != "active" or current.get("domain") != proposal.domain or current.get("institution") != proposal.institution or (proposal.content_id == "PRAYER_08" and current.get("bound_member", false)): return {"ok": true, "outcome": "source_changed"}
	if person.is_empty():
		var nomination: Dictionary = world.nominate_prayer_contact(proposal, sample, owner)
		if not nomination.get("ok", false) or nomination.get("outcome") != "nominated": return nomination
		person = nomination.person; token = nomination.token; nomination_source = nomination.nomination
	var result: Dictionary = commit_contact(world, person, proposal, sample, owner, nomination_source)
	if not result.get("ok", false): return result
	var preview: Dictionary = world.preview_prayer_fix(result.source, owner, token)
	if not preview.ok:
		if not token.is_empty(): return {"ok": false, "error": "Anonymous contact failed after full admission: " + str(preview.outcome)}
		if preview.outcome == "no_action_window": world.close_prayer_source(result.source, "no_action_window", owner)
		return {"ok": true, "outcome": preview.outcome, "source": result.source}
	if not world.fix_prayer_source(result.source, owner, token): return {"ok": false, "error": "Admitted contact could not be fixed atomically"}
	return {"ok": true, "outcome": "fixed", "source": result.source}

static func bootstrap(world: RefCounted, owner: Object) -> Dictionary:
	if world.transaction == null or world.state.turn != 0 or Store.size(owner.context.receipts) != 0 or not world.state.has(ID): return {"ok": false, "error": "Bootstrap requires the independent initialization transaction"}
	var domains: Array = world.state.simulation.focused.duplicate(); domains.sort()
	if domains.is_empty(): return {"ok": false, "error": "Bootstrap has no legal initial focused domain"}
	var domain: String = str(domains[0]); var template: Dictionary = world.abstract_sim.templates.BG_CONTACT
	var sample: Dictionary = Knowledge.capture(world, owner)
	var proposal: Dictionary = {"root": "ROOT_CURRENT_APPEAL", "domain": domain, "profile": template.profile, "institution": domain + "/" + str(template.institution_role), "content_id": "PRAYER_08", "source_ids": [world.state.domains[domain].origin], "once_key": "ROOT_CURRENT_APPEAL/" + domain + "/bootstrap/0", "petitioner": "", "bootstrap": true}
	var result: Dictionary = commit(world, {"root": "ROOT_CURRENT_APPEAL", "legacy": false, "proposal": proposal, "snapshot": sample}, owner)
	if result.get("outcome") != "fixed": return {"ok": false, "error": "Initial undirected devotion could not be admitted: " + str(result.get("outcome", result.get("error", "unknown")))}
	return result

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, source_index: RefCounted = null) -> Array[String]:
	if not state.has(ID):
		if trusted.has(ID) or state.has("prayer_dispatch"): return ["Prayer origin producer disappeared"]
		return []
	var ledger: Variant = state[ID]
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != version(content) or not ledger.get("heads") is Dictionary or not ledger.get("scans") is Dictionary or not ledger.get("dirty") is Dictionary: return ["Invalid prayer producer state"]
	var installed: Dictionary = _fact(state, str(ledger.get("installed", "")))
	if installed.get("kind") != "prayer_producer_installed" or installed.turn != 0 or installed.changes.get("version") != ledger.version: return ["Prayer producer installation is not its current policy"]
	var expected: Dictionary = {"heads": {}, "scans": {}, "dirty": {}}
	for domain: String in state.domains: expected.heads[domain] = {}
	if trusted.has(ID):
		for field: String in expected: expected[field] = trusted[ID][field].duplicate(true)
	var first: int = int(trusted.next_fact) if trusted.has(ID) else Knowledge._number(installed.id) + 1
	var plans: Dictionary = {}
	var index: RefCounted = source_index
	if index == null:
		if not trusted.is_empty(): return ["Incremental origin validation needs its actual knowledge index"]
		index = History.new()
		for fact: Dictionary in Store.values(state.facts):
			if fact.get("kind") == "prayer_producer_update" and fact.changes.get("collection") == "dirty" and fact.changes.get("after") is String: index._add("prayer_record_knowledge/" + str(fact.changes.key), fact.id, str(fact.changes.after))
	for number: int in range(first, int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		if fact.get("kind") == "prayer_dispatch_tick":
			var data: Dictionary = fact.changes
			if not data.get("origins") is Dictionary: return ["Dispatch omitted the actual origin-selection input"]
			plans[str(data.snapshot.fact_cutoff) + "|" + fact.domain] = fact
			var scan_errors: Array[String] = _validate_scan(state, data.origins.get("scan", {}), data.snapshot, fact.domain, content, index)
			if not scan_errors.is_empty(): return scan_errors
	for number: int in range(first, int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		if fact.get("kind") == "prayer_producer_update":
			var data: Dictionary = fact.changes; var collection: String = str(data.get("collection", "")); var key: String = str(data.get("key", ""))
			if data.get("version") != ledger.version or not collection in expected: return ["Invented prayer producer update"]
			var target: Dictionary = expected[collection]
			if collection == "heads":
				if not key.contains("|") or not target.has(key.get_slice("|", 0)): return ["Invalid current origin partition"]
				target = target[key.get_slice("|", 0)]; key = key.get_slice("|", 1)
			elif not Store.has(state.npcs, key): return ["Origin pagination invented an identity"]
			if target.get(key) != data.get("before"): return ["Origin current index lost its previous value"]
			if data.get("after") == null: target.erase(key)
			else: target[key] = data.after
			if collection == "dirty" and data.get("after") != null and (not data.after is String or not _knows(state, key, data.after)): return ["Origin scan was granted knowledge the person never acquired"]
			if collection == "dirty" and data.get("after") != null and Store.entry(state.applied_authorizations, "producer/knowledge/" + key + "/" + str(data.after), "") != fact.id: return ["Original record-knowledge acquisition lost its exact index"]
			if collection in ["dirty", "heads"] and data.get("after") == null:
				var person: String = key.get_slice("/", 0) if collection == "heads" else key
				var death: bool = false
				for parent: String in fact.causal_parents:
					var cause: Dictionary = _fact(state, parent)
					if cause.get("kind") == "status_change" and cause.get("actor") == person and cause.changes.get("to") == "dead": death = true
				var tick: Dictionary = plans.get(str(data.get("snapshot", {}).get("fact_cutoff", -1)) + "|" + fact.domain, {})
				var plan: Dictionary = tick.get("changes", {}).get("origins", {})
				if collection == "dirty" and not death:
					var scan: Dictionary = plan.get("scan", {})
					var checked: Array = scan.get("checked", []).duplicate(); checked.sort()
					if scan.get("person") != key or not scan.get("complete", false) or scan.get("deferred", true) or checked != fact.causal_parents: return ["Origin knowledge marker cleared without its completed finite page"]
				if collection == "heads" and not death and not key in plan.get("remove", []):
					if tick.get("changes", {}).get("origin_selected", {}).get("key") != key: return ["Origin head cleared without its original selection or invalidation"]
					var published: bool = false
					for parent: String in fact.causal_parents:
						var cause: Dictionary = _fact(state, parent)
						if cause.get("kind") == "prayer_situation" and cause.changes.get("subjects", {}).get("petitioner") == person and cause.changes.get("facts") == data.before.get("facts"): published = true
					if not published: return ["Origin head disappeared before its complete sourced call"]
			if collection == "scans" and data.get("after") != null and (not data.after is int or data.after < 0): return ["Invalid origin knowledge page offset"]
			if collection == "scans" and data.get("after") != null:
				var tick: Dictionary = plans.get(str(data.get("snapshot", {}).get("fact_cutoff", -1)) + "|" + fact.domain, {})
				var scan: Dictionary = tick.get("changes", {}).get("origins", {}).get("scan", {})
				var checked: Array = scan.get("checked", []).duplicate(); checked.sort()
				var prior_offset: int = 0 if data.before == null else int(data.before)
				if scan.get("person") != key or scan.get("after") != data.after or scan.get("before") != prior_offset or checked != fact.causal_parents: return ["Origin page update is not its actual inspected input"]
			if collection == "heads" and data.get("after") != null:
				var descriptor: Variant = data.after
				if not descriptor is Dictionary or not descriptor.get("content_id") in ["PRAYER_04", "PRAYER_05"] or _root_key(descriptor) != key or descriptor.get("domain") != fact.domain or Knowledge._binding(state, descriptor, content).is_empty(): return ["Origin head has no original finite object bundle"]
				var tick: Dictionary = plans.get(str(data.get("snapshot", {}).get("fact_cutoff", -1)) + "|" + fact.domain, {})
				if descriptor.content_id == "PRAYER_04":
					if tick.get("changes", {}).get("origins", {}).get("scan", {}).get("head") != descriptor or not descriptor.get("record_knowledge", "") in fact.causal_parents or not Knowledge._record_known_at(state, descriptor.subjects.petitioner, descriptor.record_knowledge, data.snapshot): return ["Known-record head did not come from the actual informed selector"]
				else:
					var root: Dictionary = _fact(state, str(descriptor.facts.ritual))
					var proposal: Dictionary = tick.get("changes", {}).get("choice", {}).get("proposal", {})
					if root.get("kind") != "ritual_context" or root.turn != fact.turn or not root.id in fact.causal_parents or proposal.get("petitioner") != descriptor.subjects.petitioner or proposal.get("root") != "ROOT_CURRENT_RITUAL" or proposal.get("institution") != descriptor.institution: return ["Ritual origin was not the selected current activity"]
		if fact.get("kind") == "prayer_contact_selected":
			var data: Dictionary = fact.changes
			if data.get("version") != ledger.version or not data.get("proposal") is Dictionary or not data.get("snapshot") is Dictionary or not data.get("person") is String or data.person != fact.actor or not data.person in fact.targets or data.proposal.get("content_id") not in ["PRAYER_08", "PRAYER_09"] or data.proposal.get("domain") != fact.domain: return ["Contact lost its real selected origin"]
			if data.get("position") != {"commit_seq": int(data.snapshot.get("commit_seq", -1)) + 1, "fact_before": int(data.snapshot.get("fact_cutoff", -1)) + 1}: return ["Contact changed its actual transaction boundary"]
			if data.proposal.get("bootstrap", false):
				var bootstrap: Dictionary = _fact(state, str(Store.entry(state.applied_authorizations, "prayer/bootstrap", "")))
				if bootstrap.get("kind") != "prayer_bootstrap" or bootstrap.turn != 0 or data.snapshot.get("phase") != "bootstrap" or data.proposal.get("content_id") != "PRAYER_08": return ["Anonymous bootstrap contact has no actual initial admission"]
			else:
				var tick: Dictionary = plans.get(str(data.snapshot.get("fact_cutoff", -1)) + "|" + fact.domain, {})
				if tick.get("changes", {}).get("choice", {}).get("proposal") != data.proposal or tick.changes.get("snapshot") != data.snapshot: return ["Current contact was not the selected shared opportunity"]
	for field: String in expected:
		if expected[field] != ledger[field]: return ["Prayer origin current projection differs from its managed updates"]
	return []

static func _validate_scan(state: Dictionary, scan: Dictionary, sample: Dictionary, domain: String, content: RefCounted, index: RefCounted) -> Array[String]:
	if scan.is_empty(): return []
	if not scan.get("person") is String or not Store.has(state.npcs, scan.person) or not scan.get("checked") is Array or not scan.get("count") is int or not scan.get("before") is int or not scan.get("start") is int or not scan.get("after") is int or scan.count < 0 or scan.before < 0 or scan.checked.size() > index.page_limit: return ["Invalid finite record-selector input"]
	var actual: Dictionary = index.prayer_record_page(scan.person, int(sample.fact_cutoff), int(scan.before))
	var sources: Array = []
	for item: Dictionary in actual.get("items", []): sources.append(item.source)
	if not actual.get("ok", false) or actual.count != scan.count or actual.start != scan.start or scan.checked != sources.slice(0, scan.checked.size()): return ["Record-selector page differs from its actual acquired-knowledge index"]
	var expected_start: int = 0 if scan.before >= scan.count else scan.before
	var end: int = expected_start + scan.checked.size()
	if scan.start != expected_start or end > scan.count or scan.after != (0 if end == scan.count else end) or scan.get("complete") != (end == scan.count): return ["Record-selector page did not continue its exact prior position"]
	for source: Variant in scan.checked:
		if not source is String or Knowledge._number(source) > int(sample.fact_cutoff) or not _knows(state, scan.person, source): return ["Record-selector inspected an unknown or future source"]
	var descriptor: Variant = scan.get("head")
	if not descriptor is Dictionary: return ["Invalid selected original record"]
	if descriptor.is_empty() and scan.checked.size() != sources.size(): return ["Record-selector stopped its finite page without selecting a source"]
	if not descriptor.is_empty():
		var proof: String = str(descriptor.get("record_knowledge", ""))
		if scan.checked.is_empty() or proof != scan.checked.back() or descriptor.get("domain") != domain or descriptor.get("subjects", {}).get("petitioner") != scan.person or descriptor.get("content_id") != "PRAYER_04" or canonical_record(state, proof) != descriptor.get("facts", {}).get("record") or not Knowledge._record_known_at(state, scan.person, proof, sample): return ["Record-selector head differs from its true sampled knowledge"]
		if _fact(state, descriptor.facts.record).get("turn", sample.turn) >= sample.turn or Knowledge._binding(state, descriptor, content).is_empty(): return ["Record-selector used a new-batch or untyped origin"]
	return []
