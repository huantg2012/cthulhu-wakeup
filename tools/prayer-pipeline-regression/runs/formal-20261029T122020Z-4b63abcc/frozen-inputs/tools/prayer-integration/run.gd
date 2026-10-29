extends "res://tools/prayer-producers/run.gd"
const Anchors = preload("res://src/game/anchors.gd")
const Resistance = preload("res://src/game/resistance.gd")
const Endings = preload("res://src/game/endings.gd")
const PlayerSources = preload("res://src/game/player_sources.gd")

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PI-CATALOG", "Formal current Catalog loads", loaded, {"errors": catalog.errors})
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	if loaded:
		for mode: String in ["focused", "background"]:
			for addressing: String in ["directed", "undirected"]:
				_matrix(mode, addressing, false)
				_matrix(mode, addressing, true)
			_known_undirected(mode)
		_existing_call_capacity()
		for variant: String in ["deadlines_equal", "start_equal", "start_parent", "already_due"]: _action_window(variant)
		_wrapped_record_reopening()
		_session_boundary()
		_projection()
		_member_projection()
	var passed: bool = records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "executionScope": "bounded_prayer_integration_components", "limitations": ["Explicit record/contact prerequisites; actual dream recognition and runtime request production.", "Projection component uses real modules but keeps PlayerSources uninstalled; formal new Session/continue remain rejected.", "No natural new game, five new root families, campaign balance or visual acceptance."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _matrix(mode: String, addressing: String, missing: bool) -> void:
	var data: Dictionary = _producer_native(7919)
	var person: String = _local_people(data.world)[0 if addressing == "directed" else 1]
	var root: String = ""
	var payload: Dictionary = {}
	if addressing == "undirected" or missing: root = _record_input(data, person, "unknown" if missing else "valid")
	if addressing == "directed":
		var contact: String = _given_fact(data, "message", person, [person], {"fixture": "actual_dream_contact"})
		var qualification: String = _qualification(data, "dream", person, person, "DOMAIN-001", {"contact": contact})
		payload = {"npc": person, "source": contact, "qualification": qualification}
	_attach_dispatch(data)
	var valid: bool = _boot(data).get("ok", false) and _open(data)
	var response: Dictionary = {}
	if addressing == "directed" and valid:
		valid = _seed(data, "POWER_DREAM", "success", payload) > 0
		response = _power(data, "POWER_DREAM", payload)
		valid = valid and response.ok and Knowledge.known(data.world.state, person).get("known", false)
		if not missing:
			var miracles: Array = _facts(data.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.actor == person and fact.changes.get("power") == "POWER_DREAM")
			root = miracles[0].id if miracles.size() == 1 else ""
			valid = valid and not root.is_empty()
	if mode == "background" and valid: valid = _submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}).ok
	var observed: Array = []
	for step: int in 4:
		valid = valid and _evolve(data)
		observed.append({"turn": data.world.state.turn, "focused": "DOMAIN-001" in data.world.state.simulation.focused, "calls": _content_calls(data.world, "PRAYER_04", person, root)})
		if not missing and not _content_cards(data.world, "PRAYER_04", person, root).is_empty(): break
		if step < 3 and valid: valid = _finish(data) and _open(data)
	var calls: Array = _content_calls(data.world, "PRAYER_04", person, root)
	var cards: Array = _content_cards(data.world, "PRAYER_04", person, root)
	if missing: valid = valid and calls.is_empty() and cards.is_empty()
	else:
		valid = valid and calls.size() == 1 and cards.size() == 1 and calls[0].changes.addressing == addressing and cards[0].addressing == addressing and cards[0].call == calls[0].id and not cards[0].get("legacy_source", false)
		if valid:
			var original: String = World.canonical(calls[0])
			var saved: String = data.turn.snapshot()
			valid = data.turn.restore(saved) and saved == data.turn.snapshot() and _finish(data) and _open(data) and cards[0].id in data.world.state.prayer_system.offered and World.canonical(Store.entry(data.world.state.facts, calls[0].id)) == original
		valid = valid and (("DOMAIN-001" in data.world.state.simulation.focused) == (mode == "focused"))
	_check("PI-MATRIX/" + mode + "/" + addressing + ("/missing-record" if missing else "/production"), "Real evolve produces each addressing/mode cell, while missing exact record knowledge cannot produce that source", valid, {"root": root, "person": person, "calls": calls, "cards": cards, "actualDream": response, "observed": observed, "scope": "Prepared record or dream contact; no target-call/situation/card injection"})
	if addressing == "undirected" and not missing:
		_check("PI-IDENTITY-GATE/" + mode, "A person who knows an anomaly but does not identify the deity cannot direct this real request", valid and not Knowledge.known(data.world.state, person).get("known", false) and calls.size() == 1 and calls[0].changes.identity == "" and calls[0].changes.knowledge == "", {"call": calls})

func _known_undirected(mode: String) -> void:
	var trials: Array = []
	var found: Dictionary = {}
	for seed_value: int in range(1, 17):
		var data: Dictionary = _producer_native(seed_value)
		var person: String = _local_people(data.world)[0]
		var contact: String = _given_fact(data, "message", person, [person], {"fixture": "actual_dream_contact"})
		var qualification: String = _qualification(data, "dream", person, person, "DOMAIN-001", {"contact": contact})
		var payload: Dictionary = {"npc": person, "source": contact, "qualification": qualification}
		_attach_dispatch(data)
		var valid: bool = _boot(data).get("ok", false) and _open(data) and _seed(data, "POWER_DREAM", "success", payload) > 0
		var response: Dictionary = _power(data, "POWER_DREAM", payload) if valid else {}
		valid = valid and response.get("ok", false)
		var miracles: Array = _facts(data.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.actor == person and fact.changes.get("power") == "POWER_DREAM")
		var root: String = miracles[0].id if miracles.size() == 1 else ""
		if valid and mode == "background": valid = _submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}).ok
		for step: int in 3:
			valid = valid and _evolve(data)
			if not _content_cards(data.world, "PRAYER_04", person, root).is_empty(): break
			if step < 2 and valid: valid = _finish(data) and _open(data)
		var cards: Array = _content_cards(data.world, "PRAYER_04", person, root)
		var calls: Array = _content_calls(data.world, "PRAYER_04", person, root)
		trials.append({"seed": seed_value, "valid": valid, "addressing": calls[0].changes.addressing if calls.size() == 1 else "absent"})
		if valid and cards.size() == 1 and calls.size() == 1 and calls[0].changes.addressing == "undirected":
			found = {"seed": seed_value, "card": cards[0], "call": calls[0], "knowledge": Knowledge.known(data.world.state, person)}
			break
	_check("PI-KNOWN-UNDIRECTED/" + mode, "Actual identity recognition still permits a distinct runtime undirected intent", not found.is_empty() and found.knowledge.get("known", false) and found.call.changes.knowledge == "" and found.call.changes.identity == "", {"found": found, "trials": trials, "scope": "Finite deterministic seed selection, not frequency or balance"})

func _attach_projection(data: Dictionary) -> void:
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog))
	accepted.merge(PlayerSources.issuer_capability(catalog))
	var clock: RefCounted = Turn.new(data.world)
	data.turn = clock
	data.economy = Economy.new(catalog, accepted)
	assert(clock._attached and data.economy.install(clock))
	data.fixture = Fixture.new()
	assert(clock.register_participant("cult-fixture", "1", ["deadlines"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog)
	data.relics = Relics.new(catalog, accepted)
	data.powers = Powers.new(catalog, accepted)
	data.prayers = Prayers.new(catalog, accepted)
	data.anchors = Anchors.new(catalog, accepted)
	data.events = Events.new(catalog)
	data.resistance = Resistance.new(catalog)
	data.endings = Endings.new(catalog)
	data.player_sources = PlayerSources.new(catalog)
	for name: String in ["cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings"]: assert(data[name].install(clock))
	assert(not data.player_sources.error.is_empty() and data.player_sources.available(clock).is_empty())

func _component_session(data: Dictionary) -> RefCounted:
	var directory: String = scratch.path_join(str(data.get("projection_tag", "projection-session")))
	var session: RefCounted = Session.new(directory)
	session.catalog = catalog; session.world = data.world; session.turn = data.turn
	for name: String in ["economy", "cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources"]: session.modules[name] = data[name]
	session._campaign = "component-only"
	session.slot = directory.path_join("current.json")
	session._request_sequence = data.turn.commit_sequence
	return session

func _surface(session: RefCounted) -> Dictionary:
	var history: Array = []
	var cursor: int = 0
	for page_number: int in 20:
		var page: Dictionary = session.history_page(cursor, 100)
		history.append(page)
		if page.get("complete", false): break
		cursor = page.cursor
	return {"project": session.project(), "actions": session.action_catalog(), "guessedSelection": session.action_catalog({"domain": "DOMAIN-002"}), "history": history, "currentSources": session.current_sources()}

func _forbidden(value: Variant, ids: Array, path: String = "") -> Array:
	var issues: Array = []
	if value is Dictionary:
		for key: String in value:
			if key in ["call", "knowledge", "record_knowledge", "admission_token", "snapshot", "occurrence", "intent_rule", "identity", "sample_before", "sample_after", "proposal_hash", "acquired_turn", "recognition", "position", "commit_seq", "fact_cutoff"]: issues.append(path + "/" + key)
			for id: String in ids:
				if not id.is_empty() and id in key: issues.append(path + "/key=" + id)
			issues.append_array(_forbidden(value[key], ids, path + "/" + key))
	elif value is Array:
		for index: int in value.size(): issues.append_array(_forbidden(value[index], ids, path + "/" + str(index)))
	elif value is String:
		for id: String in ids:
			if not id.is_empty() and id in value: issues.append(path + "=" + id)
	return issues

func _projection() -> void:
	var data: Dictionary = _producer_native(7919)
	var world: RefCounted = data.world
	var domain: String = "DOMAIN-002"
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin))
	var second: String = "NPC-%08d" % int(world.state.next_npc)
	assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin))
	var root: String = world._record("exception", domain, person, [person], [world.state.domains[domain].origin], {"unexplained": true})
	var proof: String = world._record("exposure", domain, person, [person], [root], {"unexplained": true, "public": false})
	world._know(person, proof)
	var familiar: String = _local_people(world)[0]
	var retained: String = _given_fact(data, "message", familiar, [familiar], {"fixture": "explicit_player_known_fact"})
	_attach_projection(data)
	var valid: bool = _boot(data).get("ok", false)
	var session: RefCounted = _component_session(data)
	session._learn(world.state.domains["DOMAIN-001"].origin)
	session._learn(retained)
	session._refresh_knowledge(false)
	var before: Dictionary = _surface(session)
	valid = valid and not domain in session.known_domains() and not person in session.known_people() and not domain in JSON.stringify(before) and not person in JSON.stringify(before) and not second in JSON.stringify(before)
	_check("PI-PROJECTION/UNFIXED-HIDDEN", "A real unknown-domain source does not expose its people or domain before fixed visibility", valid, {"surface": before, "scope": "Known source fixture in DOMAIN-002; player explicitly knows only original DOMAIN-001 facts"})
	valid = valid and _open(data)
	session._refresh_knowledge(false)
	# Endings keeps the first reachable contact. Close the real bootstrap with
	# an actual T1 response so the future remote request becomes that contact.
	var bootstrap: Dictionary = _facts(world, "prayer_bootstrap")[0]
	_choose_prayer_seed(data, "success", str(bootstrap.changes.petitioner), "DOMAIN-001")
	session._request_sequence = data.turn.commit_sequence
	var bootstrap_response: Dictionary = session.execute_action("prayer/" + str(bootstrap.changes.candidate) + "/shallow", {}, true, "component/close-bootstrap")
	valid = valid and bootstrap_response.get("ok", false) and not world.state.simulation.candidates.has(bootstrap.changes.candidate)
	var cards: Array = []
	for step: int in 8:
		valid = valid and _evolve(data)
		cards = _content_cards(world, "PRAYER_04", person, root)
		if not cards.is_empty(): break
		if valid: valid = _finish(data) and _open(data)
	var card: Dictionary = cards[0] if cards.size() == 1 else {}
	session._refresh_knowledge(false)
	var early: Dictionary = _surface(session)
	var hidden: bool = valid and cards.size() == 1 and not card.id in world.state.prayer_system.offered and not person in JSON.stringify(early) and not second in JSON.stringify(early) and not domain in JSON.stringify(early)
	_check("PI-PROJECTION/FIXED-NOT-VISIBLE", "A formally fixed future request grants no domain/person clue before its original visible turn", hidden, {"card": card, "surface": early})
	valid = valid and cards.size() == 1 and _finish(data)
	session._refresh_knowledge(false)
	var end_hidden: Dictionary = _surface(session)
	var end_assessments: Array = _facts(world, "ending_assessed")
	var forecasts_target: bool = end_assessments.any(func(fact: Dictionary) -> bool: return fact.changes.get("contacts", []).any(func(contact: Dictionary) -> bool: return contact.get("subject") == card.get("id")))
	_check("PI-PROJECTION/FIXED-ROUND-END-HIDDEN", "Real ending assessment may forecast a future card without exposing its identity or hidden contact list in any player surface", valid and forecasts_target and not card.get("id", "no-card") in JSON.stringify(end_hidden) and not domain in JSON.stringify(end_hidden) and not person in JSON.stringify(end_hidden) and not second in JSON.stringify(end_hidden), {"forecastContainsTarget": forecasts_target, "surface": end_hidden, "scope": "Actual Endings assessment retained in world; player sees disconnection count, not private future-contact forecasts"})
	valid = valid and _open(data)
	session._refresh_knowledge(false)
	var visible: Dictionary = _surface(session)
	var project: Dictionary = visible.project
	var domain_rows: Array = project.get("domains", []).filter(func(row: Dictionary) -> bool: return row.id == domain)
	var people_rows: Array = project.get("people", []).filter(func(row: Dictionary) -> bool: return row.id == person)
	var minimal: bool = valid and domain_rows.size() == 1 and domain_rows[0].get("已知范围") == "仅本次请求线索" and people_rows.size() == 1 and people_rows[0].get("已知范围") == "仅本次请求线索" and not domain in session.known_domains() and not person in session.known_people()
	for row: Dictionary in domain_rows + people_rows:
		for field: String in ["profile", "tier", "institutions", "institution", "neighbors", "role_tags", "will", "loyalty", "sanity", "known_facts"]: minimal = minimal and not row.has(field)
	minimal = minimal and project.get("institutions", []).all(func(row: Dictionary) -> bool: return row.domain != domain)
	_check("PI-PROJECTION/MINIMAL-CLUES", "Visible request supplies one neutral domain/person clue without a civilization blueprint, institutions, attributes or complete knowledge", minimal, {"domainRows": domain_rows, "peopleRows": people_rows, "knownDomains": session.known_domains(), "knownPeople": session.known_people(), "surface": visible})
	var second_rows: Array = project.get("people", []).filter(func(row: Dictionary) -> bool: return row.id == second)
	var necessary_second: bool = valid and card.get("subjects", {}).get("second") == second and second_rows.size() == 1 and second_rows[0].get("已知范围") == "仅本次请求线索" and not second in session.known_people() and not second in session.current_people() and session.object_title(second) in JSON.stringify(visible.actions)
	if second_rows.size() == 1:
		for field: String in ["profile", "institution", "will", "loyalty", "sanity", "known_facts"]: necessary_second = necessary_second and not second_rows[0].has(field)
	_check("PI-PROJECTION/NECESSARY-SECOND", "The actual PR04 second witness remains a necessary limited request object without becoming a fully known actor", necessary_second, {"preparedSecond": second, "cardSubjects": card.get("subjects", {}), "projectedSecond": second_rows})
	var calls: Array = _content_calls(world, "PRAYER_04", person, root)
	var internal: Array = [proof, card.get("call", ""), card.get("admission_token", "")]
	if calls.size() == 1: internal.append(calls[0].changes.get("knowledge", ""))
	for fixed: Dictionary in world.state.simulation.candidates.values():
		for field: String in ["call", "knowledge", "record_knowledge", "admission_token"]:
			var id: String = str(fixed.get(field, ""))
			if not id.is_empty() and not id in internal: internal.append(id)
	var leaked: Array = _forbidden(visible, internal)
	_check("PI-PROJECTION/ALL-SURFACES-PRIVATE", "Project, ActionCatalog fields/details, histories and current-source selectors hide proof fields and their concrete IDs", valid and leaked.is_empty(), {"leaks": leaked, "internalIDs": internal})
	var prayer_key: String = "prayer/" + str(card.get("id", "")) + "/deep"
	var free_snapshot: String = data.turn.snapshot()
	var free_preview: Dictionary = session.preview_action(prayer_key)
	_check("PI-PROJECTION/ORIGINAL-FOCUS-ADMISSION", "An unfocused request previews its original automatic F admission when space exists; preview grants no F and changes no state", valid and free_preview.get("ok", false) and not domain in world.state.simulation.focused and data.turn.snapshot() == free_snapshot and _forbidden(free_preview, internal).is_empty(), {"preview": free_preview, "focused": world.state.simulation.focused})
	# Fill real F through actual commands; the lack of current focus alone is
	# not a rejection under the existing admission policy.
	for extra: String in ["DOMAIN-003", "DOMAIN-004"]:
		session._learn(world.state.domains[extra].origin)
		session._request_sequence = data.turn.commit_sequence
		var focused: Dictionary = session.execute_action("attention/focus", {"domain": extra}, true, "component/fill-focus/" + extra)
		valid = valid and focused.get("ok", false)
	var preview: Dictionary = session.preview_action(prayer_key)
	var no_focus: bool = valid and not domain in world.state.simulation.focused and domain in session.focus_domains() and not preview.get("ok", false)
	_check("PI-PROJECTION/FOCUS-NOT-GRANTED", "The visible domain can be explicitly selected for focus, but request delivery itself never grants F or deep intervention", no_focus and _forbidden(preview, internal).is_empty(), {"preview": preview, "focused": world.state.simulation.focused, "focusOptions": session.focus_domains()})
	var shallow_key: String = "prayer/" + str(card.get("id", "")) + "/shallow"
	var shallow_preview: Dictionary = session.preview_action(shallow_key)
	var before_snapshot: String = data.turn.snapshot()
	var deep_response: Dictionary = session.execute_action(prayer_key, {}, true, "component/denied-deep")
	_check("PI-PROJECTION/PREVIEW-AND-REJECTION", "Actual ActionCatalog preview and denied execution reveal no internal proof and preserve the official state", valid and not deep_response.get("ok", false) and before_snapshot == data.turn.snapshot() and _forbidden([preview, shallow_preview, deep_response, session.last_result, session.project()], internal).is_empty(), {"deepResponse": deep_response, "shallowPreview": shallow_preview})
	if valid and shallow_preview.get("ok", false): _choose_prayer_seed(data, "success", person, domain)
	var response: Dictionary = session.execute_action(shallow_key, {}, true, "component/actual-shallow") if valid and shallow_preview.get("ok", false) else {}
	var saved_after: String = data.turn.snapshot()
	var replay: Dictionary = session.execute_action(shallow_key, {}, true, "component/actual-shallow") if response.get("ok", false) else {}
	var response_surface: Dictionary = _surface(session)
	_check("PI-PROJECTION/RESULT-AND-REPLAY", "A real shallow response, last_result, history and durable cached replay remain private and duplicate no official effect", valid and response.get("ok", false) and replay.get("ok", false) and data.turn.snapshot() == saved_after and _forbidden([response, replay, session.last_result, response_surface], internal).is_empty(), {"response": response, "replay": replay, "leaks": _forbidden([response, replay, session.last_result, response_surface], internal)})
	session._request_sequence = data.turn.commit_sequence
	var saved: Dictionary = session.save_game()
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.slot)) if saved.get("ok", false) else {}
	var restored: bool = data.turn.restore(envelope.get("body", {}).get("snapshot", "")) if saved.get("ok", false) else false
	var rebuilt: RefCounted = _component_session(data)
	var saved_knowledge: Dictionary = envelope.get("body", {}).get("knowledge", {})
	var reversed_knowledge: Dictionary = saved_knowledge.duplicate(true)
	if reversed_knowledge.has("facts"): reversed_knowledge.facts.reverse()
	rebuilt._rebuild_knowledge(reversed_knowledge)
	var rebuilt_surface: Dictionary = _surface(rebuilt)
	var same_rights: bool = rebuilt.known_domains() == session.known_domains() and rebuilt.known_people() == session.known_people() and rebuilt.known_sources() == session.known_sources()
	_check("PI-PROJECTION/LOCAL-SAVE-REBUILD", "Current Turn restore plus real Session knowledge reconstruction preserves limited clues without expanding full knowledge", valid and saved.get("ok", false) and restored and same_rights and int(envelope.get("body", {}).get("schema", -1)) == Session.SAVE_SCHEMA and not domain in rebuilt.known_domains() and _forbidden(rebuilt_surface, internal).is_empty(), {"save": saved, "restored": restored, "restoreError": data.turn.last_error, "sameRights": same_rights, "surface": rebuilt_surface, "scope": "Actual local save and Turn restore; explicit Session reconstruction, not full continue_game acceptance"})
	_check("PI-PROJECTION/KNOWN-INFORMATION-RETAINED", "Previously legitimate full domain/person/fact knowledge is retained across request disclosure and local rebuild", rebuilt.is_known_source(retained) and "DOMAIN-001" in rebuilt.known_domains() and familiar in rebuilt.known_people(), {"retainedFact": retained, "knownDomains": rebuilt.known_domains(), "knownPeople": rebuilt.known_people()})
	var actual_continue: Dictionary = rebuilt.continue_game(session.slot)
	var normalized: Dictionary = World._normalize_numbers(envelope.get("body", {}))
	var valid_envelope: bool = envelope.get("checksum") == World.canonical(normalized).sha256_text()
	_check("PI-PROJECTION/FULL-CONTINUE-STILL-REJECTED", "A correctly signed current component save reaches the real CULT installation guard in full continue_game", saved.get("ok", false) and valid_envelope and not actual_continue.get("ok", false) and "player_sources" in str(actual_continue.get("error", "")), {"result": actual_continue, "normalizedChecksumValid": valid_envelope})
	var old_body: Dictionary = normalized.duplicate(true)
	old_body.schema = 1
	var old_path: String = session.slot.get_base_dir().path_join("old-session-schema.json")
	var old_file: FileAccess = FileAccess.open(old_path, FileAccess.WRITE)
	assert(old_file != null)
	old_file.store_string(World.canonical({"body": old_body, "checksum": World.canonical(old_body).sha256_text()})); old_file.close()
	var before_old: String = data.turn.snapshot()
	var old_result: Dictionary = rebuilt.continue_game(old_path)
	var old_roundtrip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_path))
	var old_checksum: bool = old_roundtrip.checksum == World.canonical(World._normalize_numbers(old_roundtrip.body)).sha256_text()
	_check("PI-PROJECTION/OLD-SESSION-SCHEMA", "A correctly re-signed schema1 shell is rejected before module construction, without replacing the current local world", valid_envelope and old_checksum and not old_result.get("ok", false) and old_result.get("error") == "存档校验失败" and data.turn.snapshot() == before_old and rebuilt.world == world, {"currentControl": actual_continue, "oldSchema": old_result, "normalizedOldChecksumValid": old_checksum, "scope": "Session outer-schema boundary only; full current campaign restoration remains CULT-SAVE-COMPAT"})
	_projection_event(session, data, internal)

func _projection_event(session: RefCounted, data: Dictionary, internal: Array) -> void:
	var valid: bool = true
	var selected: Dictionary = {}
	for step: int in 8:
		if data.turn.context.phase == "actions": valid = valid and _evolve(data) and _finish(data)
		if valid and data.turn.context.phase == "between": valid = _submit(data, "advance").ok
		if not valid: break
		for row: Dictionary in data.turn.context.events:
			var entry: Dictionary = data.world.state.event_system.cards.get(row.id, {})
			if not row.resolved and entry.get("descriptor", {}).get("content_id") == "EVENT_12" and not entry.descriptor.get("prayer_descriptor", {}).is_empty():
				selected = row
				break
		if not selected.is_empty(): break
		valid = _submit(data, "finish_events").ok
	session._refresh_knowledge(false)
	var before: Dictionary = _surface(session)
	var key: String = "event/" + str(selected.get("id", "")) + "/B"
	var preview: Dictionary = session.preview_action(key) if not selected.is_empty() else {}
	session._request_sequence = data.turn.commit_sequence
	var response: Dictionary = session.execute_action(key, {}, true, "component/actual-event-reopen") if preview.get("ok", false) else {}
	session._refresh_knowledge(false)
	for fixed: Dictionary in data.world.state.simulation.candidates.values():
		for field: String in ["call", "knowledge", "record_knowledge", "admission_token"]:
			var id: String = str(fixed.get(field, ""))
			if not id.is_empty() and not id in internal: internal.append(id)
	var leaked: Array = _forbidden([before, preview, response, session.last_result, _surface(session)], internal)
	_check("PI-PROJECTION/NESTED-EVENT-AND-RESULT", "An actual expired-request EVENT12 and real option B keep nested prayer descriptors, previews and result history private", valid and not selected.is_empty() and preview.get("ok", false) and response.get("ok", false) and leaked.is_empty(), {"event": selected, "preview": preview, "response": response, "leaks": leaked, "scope": "Actual existing bootstrap request expiry/reopen, not a newly injected event"})

func _member_projection() -> void:
	var data: Dictionary = {}
	var seed_value: int = -1
	var trials: Array = []
	var card: Dictionary = {}
	for candidate: int in range(1, 33):
		var proposed: Dictionary = _producer_native(candidate)
		if int(proposed.world.state.simulation.cursors["DOMAIN-002"].next_turn) != 1: continue
		var trial_world: RefCounted = proposed.world
		var trial_domain: String = "DOMAIN-002"
		trial_world.state.domains[trial_domain].barrier = 0
		assert(trial_world._nominate_local(trial_domain, trial_domain + "/interpretation", "NPC_PROFILE_01", trial_world.state.domains[trial_domain].origin))
		proposed.projection_tag = "member-session"
		_attach_projection(proposed)
		var evolved: bool = _boot(proposed).get("ok", false) and _open(proposed) and _evolve(proposed)
		var tick: Dictionary = Store.entry(trial_world.state.facts, trial_world.state.prayer_dispatch.last.get(trial_domain, ""), {})
		var candidates: Array = _content_cards(trial_world, "PRAYER_08").filter(func(value: Dictionary) -> bool: return value.domain == trial_domain and int(value.created_turn) > 0)
		trials.append({"seed": candidate, "evolved": evolved, "tick": tick, "cards": candidates})
		if evolved and candidates.size() == 1:
			data = proposed; seed_value = candidate; card = candidates[0]
			break
	var valid: bool = not data.is_empty()
	if not valid:
		for name: String in ["ACTUAL-DEVOTION", "MEMBER-NOT-WORLD", "MEMBER-SAVE-REBUILD"]: _check("PI-PROJECTION/" + name, "A lawful current appeal fixture exists", false)
		return
	var world: RefCounted = data.world
	var domain: String = "DOMAIN-002"
	var person: String = str(card.get("subjects", {}).get("petitioner", ""))
	var session: RefCounted = _component_session(data)
	session._learn(world.state.domains["DOMAIN-001"].origin)
	session._refresh_knowledge(false)
	valid = valid and card.get("addressing") == "undirected" and not card.get("legacy_source", false) and _finish(data) and _open(data)
	session._refresh_knowledge(false)
	person = str(card.get("subjects", {}).get("petitioner", person))
	var key: String = "prayer/" + str(card.get("id", "")) + "/shallow"
	var preview: Dictionary = session.preview_action(key) if valid else {}
	if valid and preview.get("ok", false): _choose_prayer_seed(data, "success", person, domain)
	session._request_sequence = data.turn.commit_sequence
	var response: Dictionary = session.execute_action(key, {}, true, "component/unknown-domain-devotion") if valid and preview.get("ok", false) else {}
	var member: Dictionary = Store.entry(world.state.npcs, person, {})
	valid = valid and response.get("ok", false) and member.get("bound_member", false) and Knowledge.known(world.state, person).get("known", false)
	_check("PI-PROJECTION/ACTUAL-DEVOTION", "An actually generated unknown-domain undirected appeal can receive a real shallow membership response", valid, {"seed": seed_value, "trials": trials, "card": card, "preview": preview, "response": response, "scope": "Finite seed trials with explicit existing person, zero initial wall and due tick; actual source/call/fix and response, not a natural frequency estimate"})
	var surface: Dictionary = _surface(session)
	var rows: Array = surface.project.get("people", []).filter(func(row: Dictionary) -> bool: return row.id == person)
	var domains: Array = surface.project.get("domains", []).filter(func(row: Dictionary) -> bool: return row.id == domain)
	var rights: bool = valid and person in session.known_people() and rows.size() == 1 and rows[0].has("loyalty") and rows[0].has("will") and not domain in session.known_domains() and domains.size() == 1 and domains[0].get("已知范围") == "仅本次请求线索" and not domain in world.state.simulation.focused and surface.project.get("institutions", []).all(func(row: Dictionary) -> bool: return row.domain != domain)
	var internal: Array = [str(card.get("call", "")), str(card.get("admission_token", ""))]
	for acquisition: Dictionary in _facts(world, "deity_identified") + _facts(world, "deity_identity_received"):
		if acquisition.changes.get("person") == person: internal.append(acquisition.id)
	_check("PI-PROJECTION/MEMBER-NOT-WORLD", "Actual bound membership exposes that member's legitimate attributes while the remote domain stays a request clue without automatic F or institutions", rights and _forbidden(surface, internal).is_empty(), {"personRows": rows, "domainRows": domains, "knownDomains": session.known_domains(), "knownPeople": session.known_people(), "leaks": _forbidden(surface, internal)})
	var saved: Dictionary = session.save_game()
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.slot)) if saved.get("ok", false) else {}
	var restored: bool = data.turn.restore(envelope.get("body", {}).get("snapshot", "")) if saved.get("ok", false) else false
	var rebuilt: RefCounted = _component_session(data)
	var knowledge: Dictionary = envelope.get("body", {}).get("knowledge", {})
	var reverse_knowledge: Dictionary = knowledge.duplicate(true)
	if reverse_knowledge.has("facts"): reverse_knowledge.facts.reverse()
	rebuilt._rebuild_knowledge(reverse_knowledge)
	var rebuilt_ok: bool = rebuilt.known_sources() == session.known_sources()
	var rebuilt_surface: Dictionary = _surface(rebuilt)
	_check("PI-PROJECTION/MEMBER-SAVE-REBUILD", "The shared real knowledge-rebuild path preserves the member's rights without upgrading the remote world on local continuation", rights and saved.get("ok", false) and restored and rebuilt_ok and rebuilt.known_people() == session.known_people() and rebuilt.known_domains() == session.known_domains() and not domain in rebuilt.known_domains() and _forbidden(rebuilt_surface, internal).is_empty(), {"saved": saved, "restored": restored, "rebuilt": rebuilt_ok, "knownDomains": rebuilt.known_domains(), "knownPeople": rebuilt.known_people(), "surface": rebuilt_surface, "scope": "Real current save/Turn restore/shared projection rebuild; complete Session continue remains rejected"})
	var focus_preview: Dictionary = rebuilt.preview_action("attention/focus", {"domain": domain})
	var focus: Dictionary = rebuilt.execute_action("attention/focus", {"domain": domain}, true, "component/explicit-focus")
	var after_focus: Dictionary = _surface(rebuilt)
	_check("PI-PROJECTION/EXPLICIT-FOCUS", "An explicit original attention command can focus the request clue and then retain its legitimate full-domain disclosure", rights and focus_preview.get("ok", false) and focus.get("ok", false) and domain in world.state.simulation.focused and domain in rebuilt.known_domains() and after_focus.project.get("domains", []).any(func(row: Dictionary) -> bool: return row.id == domain and row.has("profile")) and _forbidden([focus_preview, focus, after_focus], internal).is_empty(), {"preview": focus_preview, "response": focus, "knownDomains": rebuilt.known_domains(), "focused": world.state.simulation.focused})
