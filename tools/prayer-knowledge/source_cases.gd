extends "res://tools/prayer-knowledge/run.gd"
const Session = preload("res://src/presentation/session.gd")
const Events = preload("res://src/game/events.gd")

func _rewrap_turn(envelope: Dictionary, world_envelope: Dictionary) -> String:
	# Restore canonicalizes JSON numbers before checking checksums. Re-sign the
	# same representation, so negative cases reach semantic validation.
	world_envelope.body = World._normalize_numbers(world_envelope.body)
	world_envelope.checksum = World.canonical(world_envelope.body).sha256_text()
	envelope.body.world = World.canonical(world_envelope)
	envelope.body = World._normalize_numbers(envelope.body)
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	return World.canonical(envelope)

func run_knowledge_source_cases() -> void:
	_catalog_rejections()
	_knowledge_saves()
	_session_rejects_unimplemented_consumers()
	_call_consumption()
	_call_known_modes()
	_call_rejections()
	_notice_cases()
	_lifecycle_cases()

func _catalog_rejections() -> void:
	var cases: Array = [
		["mode", "prayer_addressing_modes", "directed,1,", "sideways,1,"],
		["knowledge_boolean", "prayer_addressing_modes", "directed,1,", "directed,2,"],
		["root_reference", "prayer_origin_rules", "ROOT_INJURY", "ROOT_NONEXISTENT"],
		["exclusive_group", "prayer_origin_rules", ",conflict_petitioner", ","],
		["knowledge_owner", "prayer_knowledge_rules", "KNOW_TELL,world,", "KNOW_TELL,powers,"],
		["root_phase", "prayer_root_rules", "ROOT_CURRENT_PACT,4,", "ROOT_CURRENT_PACT,7,"]
	]
	for test: Array in cases:
		var content: RefCounted = Catalog.new()
		assert(content.load_files())
		var before: String = World.canonical({"tables": content.tables, "version": content.version, "extension_versions": content.extension_versions})
		var path: String = scratch.get_base_dir().path_join("bad-catalog-" + test[0])
		assert(DirAccess.make_dir_recursive_absolute(path) == OK)
		for file: String in DirAccess.get_files_at("res://data"):
			if not file.ends_with(".csv"):
				continue
			var text: String = FileAccess.get_file_as_string("res://data/" + file)
			if file == test[1] + ".csv":
				assert(test[2] in text)
				text = text.replace(test[2], test[3])
			var target: FileAccess = FileAccess.open(path.path_join(file), FileAccess.WRITE)
			assert(target != null)
			target.store_string(text)
			target.close()
		var accepted: bool = content.load_files(path)
		var after: String = World.canonical({"tables": content.tables, "version": content.version, "extension_versions": content.extension_versions})
		_check("PK-CATALOG-REJECT/" + test[0], "Malformed copied prayer grammar is rejected without replacing the valid current Catalog", not accepted and not content.errors.is_empty() and before == after, {"accepted": accepted, "errors": content.errors, "validCatalogPreserved": before == after})

func _recognized_world() -> Dictionary:
	var data: Dictionary = _high()
	_attach_prayers(data)
	var payload: Dictionary = _payload(data, "POWER_DREAM")
	_seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data))
	var response: Dictionary = _power(data, "POWER_DREAM", payload)
	assert(response.ok and Knowledge.known(data.world.state, payload.npc).get("known", false))
	data.person = payload.npc
	return data

func _knowledge_saves() -> void:
	var data: Dictionary = _recognized_world()
	var saved: String = data.turn.snapshot()
	var original: Dictionary = Knowledge.known(data.world.state, data.person)
	var restored: bool = data.turn.restore(saved)
	var signed_envelope: Dictionary = JSON.parse_string(saved)
	var signed_world: Dictionary = JSON.parse_string(signed_envelope.body.world)
	var signed_control: bool = data.turn.restore(_rewrap_turn(signed_envelope, signed_world))
	_check("PK-SAVE-ROUNDTRIP", "Actual module Turn snapshot and normalized re-sign control restore identity, earliest acquisition and RNG unchanged", restored and signed_control and data.turn.snapshot() == saved and Knowledge.known(data.world.state, data.person) == original, {"restored": restored, "normalizedResignControl": signed_control, "error": data.turn.last_error, "known": Knowledge.known(data.world.state, data.person)})
	for variant: String in ["identity", "identity_rekey", "knowledge_source", "position_cutoff", "position_commit", "recognition_person", "recognition_outcome", "head_person", "version", "missing_ledger", "receipt_missing", "receipt_duplicate_sequence", "receipt_reversed_range", "receipt_gap", "receipt_tail", "old_turn_schema"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var state: Dictionary = world_envelope.body.state
		var ledger: Dictionary = state.prayer_knowledge
		var acquisition: Dictionary = state.facts[original.source]
		var result: Dictionary = state.facts[acquisition.changes.source]
		var receipts: Dictionary = envelope.body.context.receipts
		var receipt_ids: Array = receipts.keys()
		receipt_ids.sort_custom(func(a: String, b: String) -> bool: return int(receipts[a].get("sequence", -1)) < int(receipts[b].get("sequence", -1)))
		match variant:
			"identity": ledger.identity += "/forged"
			"identity_rekey":
				var previous_identity: String = ledger.identity
				ledger.seed = str(int(ledger.seed) + 1)
				var domain_ids: Array = state.domains.keys()
				domain_ids.sort()
				var origins: Array = []
				for domain: String in domain_ids:
					origins.append([domain, state.domains[domain].origin])
				ledger.identity = "DEITY/" + World.canonical(["world/1", ledger.seed, origins]).sha256_text()
				for fact: Dictionary in state.facts.values():
					if fact.changes.get("identity") == previous_identity:
						fact.changes.identity = ledger.identity
					if fact.changes.get("recognition") is Dictionary and fact.changes.recognition.get("identity") == previous_identity:
						fact.changes.recognition.identity = ledger.identity
			"knowledge_source": ledger.heads[data.person].source = state.domains["DOMAIN-001"].origin
			"position_cutoff": ledger.heads[data.person].position.fact_cutoff += 1
			"position_commit": ledger.heads[data.person].position.commit_seq += 1
			"recognition_person": result.changes.recognition.person = data.guardians["DOMAIN-001"][1]
			"recognition_outcome": result.changes.outcome = "failure"
			"head_person":
				ledger.heads[data.guardians["DOMAIN-001"][1]] = ledger.heads[data.person]
				ledger.heads.erase(data.person)
			"version": ledger.version += "/forged"
			"missing_ledger": state.erase("prayer_knowledge")
			"receipt_missing": receipts[receipt_ids[0]].erase("fact_before")
			"receipt_duplicate_sequence": receipts[receipt_ids[1]].sequence = receipts[receipt_ids[0]].sequence
			"receipt_reversed_range": receipts[receipt_ids[0]].fact_after = receipts[receipt_ids[0]].fact_before - 1
			"receipt_gap": receipts[receipt_ids[1]].fact_before += 1
			"receipt_tail": receipts[receipt_ids[-1]].fact_after = int(state.next_fact) + 1
			"old_turn_schema": envelope.body.schema = 1
		var before: String = data.turn.snapshot()
		var accepted: bool = data.turn.restore(_rewrap_turn(envelope, world_envelope))
		_check("PK-SAVE-REJECT/" + variant, "Recomputed envelope checksums cannot authorize corrupted identity history", not accepted and before == data.turn.snapshot(), {"accepted": accepted, "error": data.turn.last_error, "currentUnchanged": before == data.turn.snapshot(), "savedGenerationSeed": world_envelope.body.randoms.generation.seed, "knowledgeSeed": ledger.get("seed", "")})
		if accepted:
			assert(data.turn.restore(saved))
	var envelope: Dictionary = JSON.parse_string(saved)
	var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
	world_envelope.body.state.prayer_knowledge.heads.clear()
	var before: String = data.turn.snapshot()
	var accepted: bool = data.turn.restore(_rewrap_turn(envelope, world_envelope))
	var current: Dictionary = Knowledge.known(data.world.state, data.person)
	# A derived index may be rebuilt, but acceptance cannot silently erase knowledge.
	var valid: bool = (not accepted and before == data.turn.snapshot()) or (accepted and current == original)
	_check("PK-SAVE-HEAD-OMISSION", "Missing knowledge projection is rejected or rebuilt faithfully from actual acquisition history", valid, {"accepted": accepted, "known": current, "original": original, "error": data.turn.last_error})
	if accepted:
		assert(data.turn.restore(saved))

func _session_rejects_unimplemented_consumers() -> void:
	var session: RefCounted = Session.new(scratch.get_base_dir().path_join("session-reject"))
	var previous_world: RefCounted = session.world
	var previous_turn: RefCounted = session.turn
	var previous_slot: String = session.slot
	var result: Dictionary = session.start_new(7919)
	_check("PK-SESSION-CONSUMER-BOUNDARY", "Formal Session refuses unsupported CULT consumer before replacing the empty session", not result.ok and not str(result.get("error", "")).is_empty() and session.world == previous_world and session.turn == previous_turn and session.slot == previous_slot and session.modules.is_empty(), {"result": result, "emptySessionUnchanged": session.world == previous_world and session.turn == previous_turn, "scope": "Rejection of a new empty Session only; no claim of a playable or fully restored campaign"})

func _call_fixture(identified: bool = false, seed_value: int = 7919) -> Dictionary:
	qa_seed_override = seed_value
	var data: Dictionary = _high()
	qa_seed_override = -1
	var world: RefCounted = data.world
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-001"].origin))
	world.mutable_npc(person).loyalty = 0
	data.person = person
	data.domain = "DOMAIN-001"
	data.contact = _given_fact(data, "devotion_contact", person, [person], {"subject": person, "institution": "DOMAIN-001/interpretation"})
	data.descriptor = {"content_id": "PRAYER_08", "domain": "DOMAIN-001", "institution": "DOMAIN-001/interpretation", "actors": [person], "subjects": {"petitioner": person}, "facts": {"contact": data.contact}, "source_ids": [data.contact], "crisis": {}}
	_attach_prayers(data)
	data.dream = {"npc": person, "source": data.contact, "qualification": _qualification(data, "dream", person, person, "DOMAIN-001", {"contact": data.contact})}
	assert(_open(data))
	if identified:
		_seed(data, "POWER_DREAM", "success", data.dream)
		assert(_power(data, "POWER_DREAM", data.dream).ok)
	world.qa_calls = [data.descriptor]
	return data

func _call_consumption() -> void:
	var data: Dictionary = _call_fixture()
	data.world.qa_add_marker = true
	var evolved: bool = _evolve(data)
	var result: Dictionary = data.world.qa_call_results[0] if not data.world.qa_call_results.is_empty() else {}
	var call: Dictionary = Store.entry(data.world.state.facts, str(result.get("source", "")), {})
	var valid: bool = evolved and result.get("ok", false) and call.get("kind") == "prayer_call" and call.changes.get("addressing") == "undirected" and call.changes.get("identity") == "" and call.changes.get("knowledge") == "" and Knowledge.validate_call(data.world.state, call.id, data.descriptor, catalog)
	_check("PK-CALL-UNKNOWN", "Consumer probe commits an unknown nonbeliever call as undirected in a real managed evolution", valid, {"result": result, "call": call, "scope": "Prepared current contact; not ORIGINS natural generation"})
	if not valid:
		return
	var saved: String = data.turn.snapshot()
	for variant: String in ["mode", "cutoff", "phase", "commit_seq"]:
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var changed: Dictionary = world_envelope.body.state.facts[call.id].changes
		match variant:
			"mode":
				changed.addressing = "directed"
				changed.identity = world_envelope.body.state.prayer_knowledge.identity
				changed.intent_rule = catalog.tables.prayer_addressing_modes.directed.intent_rule
			"cutoff": changed.snapshot.fact_cutoff = int(data.world.qa_call_marker.trim_prefix("FACT-"))
			"phase": changed.snapshot.phase = "actions"
			"commit_seq": changed.snapshot.commit_seq += 1
		# Alter every copied sampling proof together. A stale basis copy must not
		# be the only reason the forged transaction boundary is rejected.
		for parent: String in call.causal_parents:
			var basis: Dictionary = world_envelope.body.state.facts.get(parent, {})
			if basis.get("kind") == "prayer_call_basis":
				basis.changes.snapshot = changed.snapshot.duplicate(true)
		var before: String = data.turn.snapshot()
		var accepted: bool = data.turn.restore(_rewrap_turn(envelope, world_envelope))
		_check("PK-CALL-SAVE-REJECT/" + variant, "Restored calls cannot alter frozen intent or their actual transaction input boundary", not accepted and before == data.turn.snapshot(), {"accepted": accepted, "error": data.turn.last_error, "originalSnapshot": call.changes.snapshot, "changedSnapshot": changed.snapshot, "sameBatchMarker": data.world.qa_call_marker})
		if accepted:
			assert(data.turn.restore(saved))
	data.world.qa_add_marker = false
	assert(_finish(data) and _open(data))
	_seed(data, "POWER_DREAM", "success", data.dream)
	var dream: Dictionary = _power(data, "POWER_DREAM", data.dream)
	var known: Dictionary = Knowledge.known(data.world.state, data.person)
	var before: String = World.canonical(call)
	var reused: bool = _evolve(data)
	var same: Dictionary = data.world.qa_call_results[0] if not data.world.qa_call_results.is_empty() else {}
	_check("PK-CALL-REUSE-AFTER-KNOWLEDGE", "Unfixed committed call retains its original undirected intent after later real recognition", dream.ok and known.get("known", false) and reused and same.get("source") == call.id and before == World.canonical(Store.entry(data.world.state.facts, call.id)) and _facts(data.world, "prayer_call").size() == 1, {"dream": dream, "known": known, "originalCall": call.id, "reused": same, "scope": "Call storage/reuse; full fixed-candidate capacity flow belongs to ORIGINS"})

func _call_known_modes() -> void:
	var modes: Dictionary = {}
	var evidence: Array = []
	var valid: bool = true
	for seed_value: int in [19, 42, 7919, 2027, 1981, 104729]:
		var data: Dictionary = _call_fixture(true, seed_value)
		var evolved: bool = _evolve(data)
		var result: Dictionary = data.world.qa_call_results[0] if not data.world.qa_call_results.is_empty() else {}
		var call: Dictionary = Store.entry(data.world.state.facts, str(result.get("source", "")), {})
		var mode: String = str(call.get("changes", {}).get("addressing", "missing"))
		modes[mode] = true
		var person: Dictionary = Store.entry(data.world.state.npcs, data.person)
		valid = valid and evolved and result.get("ok", false) and not person.get("bound_member", false) and person.loyalty < catalog.integer("loyalty_follower_threshold") and Knowledge.validate_call(data.world.state, str(result.get("source", "")), data.descriptor, catalog)
		evidence.append({"seed": seed_value, "mode": mode, "call": call, "loyalty": person.loyalty, "member": person.get("bound_member", false)})
		if modes.has("directed") and modes.has("undirected"):
			break
	_check("PK-CALL-KNOWN-NONBELIEVER-MODES", "Actual known nonbelievers can produce either stable intent across finite independent worlds", valid and modes.has("directed") and modes.has("undirected"), {"observedModes": modes.keys(), "samples": evidence, "scope": "Finite call consumers, not prayer frequency or natural reachability"})

func _call_rejections() -> void:
	var data: Dictionary = _call_fixture()
	var rejected: Array = []
	for variant: String in ["missing_person", "wrong_domain", "wrong_root", "missing_root"]:
		var descriptor: Dictionary = data.descriptor.duplicate(true)
		match variant:
			"missing_person": descriptor.subjects.petitioner = "NPC-NONEXISTENT"
			"wrong_domain": descriptor.domain = "DOMAIN-002"
			"wrong_root": descriptor.facts.contact = data.world.state.domains["DOMAIN-001"].origin
			"missing_root": descriptor.facts.clear()
		rejected.append(descriptor)
	data.world.qa_calls = rejected
	var evolved: bool = _evolve(data)
	var valid: bool = evolved and data.world.qa_call_results.size() == rejected.size() and _facts(data.world, "prayer_call").is_empty()
	for result: Dictionary in data.world.qa_call_results:
		valid = valid and not result.get("ok", false)
	_check("PK-CALL-INVALID-SOURCE", "Current call admission rejects missing people and absent or wrong-domain raw roots", valid, {"results": data.world.qa_call_results})

func _attach_notice_modules(data: Dictionary) -> void:
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog))
	data.world.state.economy.issuers = accepted.duplicate(true)
	data.economy = Economy.new(catalog, accepted)
	var turn: RefCounted = Turn.new(data.world)
	assert(turn._attached and data.economy.install(turn))
	data.fixture = Fixture.new()
	assert(turn.register_participant("cult-fixture", "1", ["deadlines", "ending"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog)
	data.relics = Relics.new(catalog, accepted)
	data.powers = Powers.new(catalog, accepted)
	data.prayers = Prayers.new(catalog, accepted)
	assert(data.cults.install(turn) and data.relics.install(turn) and data.powers.install(turn) and data.prayers.install(turn))
	data.events = Events.new(catalog)
	assert(data.events.install(turn))
	data.turn = turn

func _notice_fixture(variant: String) -> Dictionary:
	var data: Dictionary = _high()
	var world: RefCounted = data.world
	data.domain = "DOMAIN-001"
	data.sender = data.leader
	data.recipient = "NPC-%08d" % int(world.state.next_npc)
	var sender_institution: String = Store.entry(world.state.npcs, data.sender).institution
	var recipient_institution: String = sender_institution if variant == "same_institution" else data.domain + "/interpretation"
	var profile: String = {"interpretation": "NPC_PROFILE_01", "propagation": "NPC_PROFILE_03", "order": "NPC_PROFILE_05"}[world.state.institutions[recipient_institution].role]
	assert(world._nominate_local(data.domain, recipient_institution, profile, world.state.domains[data.domain].origin))
	# For the late-relation counterexample there must be no older support edge
	# that could independently make the newly selected source ineligible.
	data.relation = world.state.domains[data.domain].origin if variant == "same_batch_relation" else _given_relation(data, data.sender, data.recipient, "support")
	if variant == "dead_recipient":
		assert(world.submit({"kind": "status", "npc": data.recipient, "status": "dead", "parents": [data.relation]}))
	_attach_notice_modules(data)
	var payload: Dictionary = _payload(data, "POWER_DREAM")
	_seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data))
	if variant != "unidentified_sender":
		assert(_power(data, "POWER_DREAM", payload).ok)
	var due: int = int(world.state.simulation.cursors[data.domain].next_turn)
	while world.state.turn < due:
		assert(_evolve(data) and _finish(data) and _open(data))
	var source: String = data.relation
	if variant == "no_relation":
		source = world.state.domains[data.domain].origin
	var route: String = "" if sender_institution == recipient_institution else recipient_institution
	if variant == "wrong_route":
		route = data.domain + "/order"
	world.qa_notice = {"root_rule": "ROOT_IDENTITY_NOTICE", "domain": data.domain, "sender": data.sender, "recipient": data.recipient, "relation": source, "route": route}
	world.qa_notice_late_relation = variant == "same_batch_relation"
	world.qa_notice_bad_coordinator = variant == "wrong_coordinator"
	if variant == "wrong_knowledge":
		world.qa_notice["knowledge"] = data.relation
	if variant == "cross_domain":
		world.qa_notice["recipient"] = data.guardians["DOMAIN-007"][0]
	return data

func _notice_cases() -> void:
	for variant: String in ["valid", "same_institution", "unidentified_sender", "no_relation", "wrong_route", "wrong_knowledge", "wrong_coordinator", "same_batch_relation", "dead_recipient", "cross_domain"]:
		var data: Dictionary = _notice_fixture(variant)
		var prior: Dictionary = Knowledge.known(data.world.state, data.recipient)
		var evolved: bool = _evolve(data)
		var result: Dictionary = data.world.qa_notice_result
		var received: Array = _facts(data.world, "deity_identity_received")
		var current: Dictionary = Knowledge.known(data.world.state, data.recipient)
		var valid: bool = evolved and not prior.get("known", false)
		if variant in ["valid", "same_institution"]:
			valid = valid and result.get("authorization", {}).get("ok", false) and result.get("tell", {}).get("ok", false) and result.get("retry", {}).get("source") == result.get("tell", {}).get("source") and received.size() == 1 and current.get("known", false) and received[0].changes.get("person") == data.recipient and received[0].changes.get("sender") == data.sender
			if valid:
				var saved: String = data.turn.snapshot()
				valid = data.turn.restore(saved) and data.turn.snapshot() == saved and Knowledge.known(data.world.state, data.recipient) == current
				data.world.qa_notice = {}
				data.fixture.deadlines = [{"type": "world_command", "source": data.source, "command": {"kind": "status", "npc": data.sender, "status": "dead", "parents": [data.source]}}]
				valid = _finish(data) and valid and Knowledge.known(data.world.state, data.recipient) == current
				result["recipientKnowledgeAfterSenderDeath"] = Knowledge.known(data.world.state, data.recipient)
		else:
			valid = valid and not result.get("authorization", {}).get("ok", false) and received.is_empty() and not current.get("known", false)
		_check("PK-NOTICE/" + variant, "Managed actual Events selection transfers only sourced identity with valid frozen relationship and route", valid, {"evolved": evolved, "result": result, "received": received, "knowledge": current, "scope": "Explicit coordinator selection probe; automatic shared-opportunity scheduling remains ORIGINS"})

func _lifecycle_cases() -> void:
	for variant: String in ["focus", "leave", "migrate", "dead", "detained", "missing"]:
		var data: Dictionary = _recognized_world()
		var original: Dictionary = Knowledge.known(data.world.state, data.person)
		var changed: bool = false
		var detail: Dictionary = {}
		if variant == "focus":
			detail = _submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}})
			changed = detail.ok and _evolve(data) and _finish(data) and _open(data) and not "DOMAIN-001" in data.world.state.simulation.focused
		elif variant == "leave":
			detail = _action(data, "leave", {"npc": data.person, "source": _leave_source(data.world, data.person)})
			changed = detail.ok and not Store.entry(data.world.state.npcs, data.person).get("bound_member", false)
		else:
			var command: Dictionary = {"kind": "migrate", "npc": data.person, "domain": data.world.state.domains["DOMAIN-001"].neighbors[0], "parents": [data.source]} if variant == "migrate" else {"kind": "status", "npc": data.person, "status": variant, "parents": [data.source]}
			data.fixture.deadlines = [{"type": "world_command", "source": data.source, "command": command}]
			changed = _evolve(data) and _finish(data)
			data.fixture.deadlines = []
			var person: Dictionary = Store.entry(data.world.state.npcs, data.person)
			changed = changed and (person.domain == command.domain if variant == "migrate" else person.status == variant)
			detail = {"command": command, "status": person.status, "domain": person.domain}
		var current: Dictionary = Knowledge.known(data.world.state, data.person)
		_check("PK-LIFECYCLE/" + variant, "Actual lifecycle or attention transition retains original sourced identity knowledge", changed and current == original and History.has(Store.entry(data.world.state.npcs, data.person).known_facts, original.source), {"transition": detail, "original": original, "current": current, "scope": "Explicit upstream lifecycle effects; no autonomous life or social-network claim"})
