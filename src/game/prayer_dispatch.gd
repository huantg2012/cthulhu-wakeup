extends RefCounted
## Phase-four coordination. Formal raw roots and existing situations share
## the registered Events handlers and the same bounded opportunity budgets.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Producers = preload("res://src/game/prayer_producers.gd")
const Sources = preload("res://src/game/prayer_sources.gd")
const ID: String = "prayer_dispatch"
const SCHEMA: int = 1
const POSITION: Dictionary = {"source_after": "", "notice_sender": "", "notice_after": ""}

static func version(content: RefCounted, policy: String) -> String:
	return "dispatch/3/sources-scenes5/" + policy + "/" + Knowledge.version(content)

static func _fact(state: Dictionary, source: String) -> Dictionary:
	return Store.entry(state.facts, source, {})

static func _key(fact: Dictionary) -> String:
	var data: Dictionary = fact.get("changes", {})
	var person: String = str(data.get("subjects", {}).get("petitioner", ""))
	return person + "/" + str(data.get("need", "")) if not person.is_empty() and not str(data.get("need", "")).is_empty() else ""

static func _replay_head(state: Dictionary, heads: Dictionary, pending: Dictionary, fact: Dictionary) -> void:
	var domain: String = str(fact.get("domain", ""))
	if not heads.has(domain): return
	if fact.kind == "prayer_situation":
		var key: String = _key(fact)
		var canonical: String = str(fact.changes.get("call", ""))
		if canonical.is_empty(): canonical = PrayerRules.occurrence_key(fact.changes)
		if not key.is_empty() and not pending[domain].has(canonical): pending[domain][canonical] = fact.id
	elif fact.kind in ["prayer_fixed", "prayer_source_rejected"]:
		var source: String = str(fact.changes.get("source", fact.changes.get("candidate", {}).get("source", "")))
		for occurrence: String in pending[domain].keys():
			if pending[domain][occurrence] == source: pending[domain].erase(occurrence)
	elif fact.kind == "status_change" and fact.changes.get("to") == "dead":
		for occurrence: String in pending[domain].keys():
			var source: String = str(pending[domain][occurrence])
			if _key(_fact(state, source)).begins_with(str(fact.actor) + "/"): pending[domain].erase(occurrence)
	# Heads are entrance pointers, not replacements for independent current roots.
	# Rebuild only this bounded current partition, never the archive.
	if fact.kind in ["prayer_fixed", "prayer_source_rejected", "status_change"]:
		for key: String in heads[domain].keys():
			if not heads[domain][key] in pending[domain].values(): heads[domain].erase(key)
	if fact.kind == "prayer_situation" and not _key(fact).is_empty() and not heads[domain].has(_key(fact)): heads[domain][_key(fact)] = fact.id

static func _refresh_heads(state: Dictionary, heads: Dictionary, pending: Dictionary, domain: String) -> void:
	var current: Dictionary = {}
	for source: String in pending[domain].values():
		var fact: Dictionary = _fact(state, source); var key: String = _key(fact)
		if key.is_empty(): continue
		if not current.has(key) or _source_order(state, source) < _source_order(state, current[key]): current[key] = source
	heads[domain] = current

static func install(world: RefCounted) -> bool:
	if world.state.has(ID) or not world.state.has("event_system") or not world.state.has("simulation") or world.state.turn != 0: return false
	if not Knowledge.install(world): return false
	world.stage_collections([ID])
	var heads: Dictionary = {}; var pending: Dictionary = {}; var positions: Dictionary = {}; var last: Dictionary = {}
	for domain: String in world.state.domains:
		heads[domain] = {}; pending[domain] = {}; positions[domain] = POSITION.duplicate(); last[domain] = ""
	# One installation/restore audit may inspect history; ordinary turns never do.
	for number: int in range(1, int(world.state.next_fact)):
		_replay_head(world.state, heads, pending, _fact(world.state, "FACT-%08d" % number))
	for domain: String in world.state.domains: _refresh_heads(world.state, heads, pending, domain)
	var source: String = world._record("prayer_dispatch_installed", "", "", [], [], {"version": version(world.catalog, world.abstract_sim.version), "heads": heads, "pending": pending, "cursors": world.state.simulation.cursors.duplicate(true)})
	world.state[ID] = {"schema": SCHEMA, "version": version(world.catalog, world.abstract_sim.version), "installed": source, "heads": heads, "pending": pending, "positions": positions, "last": last}
	return Producers.install(world)

static func observe(world: RefCounted, source: String) -> void:
	Producers.observe(world, source)
	if not world.state.has(ID): return
	var fact: Dictionary = _fact(world.state, source)
	if not fact.get("kind") in ["prayer_situation", "prayer_fixed", "prayer_source_rejected", "status_change"]: return
	world.stage_collections([ID])
	_replay_head(world.state, world.state[ID].heads, world.state[ID].pending, fact)
	if world.state.domains.has(fact.domain):
		_refresh_heads(world.state, world.state[ID].heads, world.state[ID].pending, fact.domain)
		if fact.kind == "prayer_situation": world.state[ID].positions[fact.domain].source_after = ""

static func _managed(world: RefCounted, coordinator: Object, owner: Object) -> bool:
	return owner != null and world._driver_allowed(owner) and world.transaction != null and owner.context.phase == "evolution" and owner._owners.get("candidate_generation") == "events" and owner._participants.get("events", {}).get("instance") == coordinator and coordinator.get_script().resource_path == "res://src/game/events.gd" and world.state.has(ID)

static func _source_order(state: Dictionary, source: String) -> String:
	var fact: Dictionary = _fact(state, source)
	var details: Dictionary = fact.get("changes", {})
	var due: int = int(details.get("crisis", {}).get("due", 2147483647))
	# A lawful published situation can omit the redundant crisis copy. Use its
	# existing root deadline, as Prayers._situation does; never create a new due.
	var root_key: String = ""
	match str(details.get("need", "")):
		"rescue": root_key = "condition"
		"recognition", "judgment": root_key = "conflict"
		"concealment": root_key = "pursuit"
		"obligation": root_key = "contract"
		"memory": root_key = "memory"
	if not root_key.is_empty():
		var root: Dictionary = _fact(state, str(details.get("facts", {}).get(root_key, "")))
		if root.get("changes", {}).get("due") is int:
			due = int(root.changes.due)
	var descriptor: Dictionary = fact.changes.duplicate(false)
	descriptor["content_id"] = str(fact.changes.get("need", ""))
	return "%012d/" % due + PrayerRules.occurrence_key(descriptor) + "/" + source

static func _pending(world: RefCounted, view: Dictionary, domain: String, position: Dictionary) -> Dictionary:
	var sources: Array = view[ID].pending[domain].values()
	sources.sort_custom(func(a: String, b: String) -> bool: return _source_order(view, a) < _source_order(view, b))
	var page: Array = []
	var after: String = str(position.source_after)
	for source: String in sources:
		if _source_order(view, source) > after and page.size() < world.history.page_limit: page.append(source)
	if page.is_empty() and not sources.is_empty():
		page = sources.slice(0, mini(sources.size(), world.history.page_limit)); after = ""
	var result: Dictionary = {"checked": [], "reject": [], "selected": "", "source_after": ""}
	if not world.state.has("prayer_system"): return result
	var prayers: RefCounted = world._turn_owner.get_ref()._participants.prayers.instance
	for source: String in page:
		var order: String = _source_order(view, source)
		result.checked.append(source); result.source_after = order
		if Store.has(view.applied_authorizations, "prayer/source/" + source): result.reject.append({"source": source, "reason": "already_consumed"}); continue
		var valid: Dictionary = prayers._situation(view, source, null, view._history_snapshot)
		if not valid.ok:
			if valid.get("permanent", true): result.reject.append({"source": source, "reason": valid.error})
			continue
		result.selected = source; break
	if not str(result.selected).is_empty(): result.source_after = ""
	if not sources.is_empty() and result.source_after == _source_order(view, sources.back()): result.source_after = ""
	return result

static func _notice(world: RefCounted, view: Dictionary, domain: String, position: Dictionary, sample: Dictionary, tick: int) -> Dictionary:
	var index: RefCounted = view._history_snapshot
	var people: Array = index.ids("active/" + domain); people.sort()
	var result: Dictionary = {"selection": {}, "notice_sender": "", "notice_after": "", "checked": 0, "people": people, "page": [], "sender": ""}
	if people.is_empty(): return result
	var sender: String = str(position.notice_sender)
	if not sender in people: sender = str(people[0])
	result.sender = sender
	var start: String = str(position.notice_after) if sender == position.notice_sender else ""
	var knowledge: Dictionary = Knowledge.known(view, sender, sample)
	var sender_person: Dictionary = Store.entry(view.npcs, sender)
	if knowledge.get("known", false):
		for recipient: String in people:
			if recipient <= start: continue
			result.checked += 1; result.notice_after = recipient
			result.page.append(recipient)
			if sender != recipient and not Knowledge.known(view, recipient, sample).get("known", false):
				var target: Dictionary = Store.entry(view.npcs, recipient)
				var relation: Dictionary = index.relation_head(sender, recipient, ["support", "cooperation"])
				if relation.is_empty(): relation = index.relation_head(recipient, sender, ["support", "cooperation"])
				var route: String = ""
				var reachable: bool = view.institutions.has(sender_person.institution) and view.institutions.has(target.institution)
				if reachable and sender_person.institution != target.institution:
					reachable = target.institution in view.institutions[sender_person.institution].links; route = target.institution
				if reachable and not relation.is_empty() and not Store.has(view.invalid_records, relation.source):
					result.selection = {"root_rule": "ROOT_IDENTITY_NOTICE", "domain": domain, "snapshot": sample.duplicate(true), "once": "ROOT_IDENTITY_NOTICE/" + domain + "/" + str(tick) + "/0", "sender": sender, "recipient": recipient, "relation": relation.source, "route": route, "knowledge": knowledge.source}
					break
			if result.checked >= world.history.page_limit: break
	if result.notice_after.is_empty() or result.notice_after == people.back():
		result.notice_sender = str(people[(people.find(sender) + 1) % people.size()]); result.notice_after = ""
	else: result.notice_sender = sender
	return result

static func prepare(world: RefCounted, view: Dictionary, coordinator: Object, owner: Object) -> Dictionary:
	if not _managed(world, coordinator, owner): return {"ok": false, "error": "Candidate generation needs its registered Events coordinator"}
	var sample: Dictionary = Knowledge.capture(world, owner)
	var summaries: Dictionary = world._background_snapshot(view)
	var plan: Dictionary = {"ok": true, "snapshot": sample, "domains": []}
	var domains: Array = view.domains.keys(); domains.sort()
	for domain: String in domains:
		var mode: String = "detailed_candidates" if domain in view.simulation.focused else "abstract_candidates_due"
		if not coordinator.mode_handlers.has(mode) or not coordinator.mode_handlers[mode].is_valid(): return {"ok": false, "error": "Unbound candidate mode"}
		var item: Dictionary = coordinator.mode_handlers[mode].call(world, view, summaries, domain, sample)
		if not item.get("ok", false): return item
		plan.domains.append(item)
	return plan

static func _weighted_choice(options: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for option: Dictionary in options: total += int(option.get("weight", 1))
	var roll: int = rng.randi_range(1, total)
	for option: Dictionary in options:
		roll -= int(option.get("weight", 1))
		if roll <= 0: return option.duplicate(true)
	return {}

static func prepare_domain(world: RefCounted, view: Dictionary, summaries: Dictionary, domain: String, sample: Dictionary, mode: String) -> Dictionary:
	var before: Dictionary = view.simulation.cursors[domain].duplicate(true)
	var position: Dictionary = view[ID].positions[domain].duplicate(true)
	var pending: Dictionary = _pending(world, view, domain, position)
	var origins: Dictionary = Producers.prepare_existing(world, view, domain, sample)
	var origin_selected: Dictionary = {}
	if not origins.selected.is_empty() and (str(pending.selected).is_empty() or str(origins.selected.order) < _source_order(view, str(pending.selected))):
		origin_selected = origins.selected
		pending.selected = ""; pending.source_after = ""
	position.source_after = pending.source_after
	var result: Dictionary = {"ok": true, "domain": domain, "mode": mode, "before": before, "after": before.duplicate(true), "position_before": view[ID].positions[domain].duplicate(true), "position_after": position, "pending": pending, "origins": origins, "origin_selected": origin_selected, "choice": {}, "eligible": [], "notice_scan": {}, "opportunity": int(before.next_turn) <= int(view.turn), "notice_checked": 0}
	if not result.opportunity: return result
	var eligible: Array = Producers.prepare_options(world, view, domain, sample)
	eligible.append_array(Sources.options(world, view, domain, sample))
	var notice: Dictionary = _notice(world, view, domain, position, sample, int(before.next_turn))
	position.notice_sender = notice.notice_sender; position.notice_after = notice.notice_after
	result.notice_checked = notice.checked
	result.notice_scan = notice
	if not notice.selection.is_empty(): eligible.append({"root": "ROOT_IDENTITY_NOTICE", "legacy": false, "selection": notice.selection})
	result.eligible = eligible
	var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = int(before.seed); rng.state = int(before.state)
	if not eligible.is_empty() and rng.randi_range(1, 100) <= int(summaries.chance):
		result.choice = _weighted_choice(eligible, rng)
		if result.choice.get("legacy", false):
			result.choice.proposal["sample_before"] = before.state; result.choice.proposal["sample_after"] = str(rng.state)
	result.after.state = str(rng.state)
	result.after.next_turn = int(view.turn) + int(world.abstract_sim.parameters.background_tick_interval)
	return result

static func commit(world: RefCounted, plan: Dictionary, coordinator: Object, owner: Object) -> bool:
	if not _managed(world, coordinator, owner) or plan.get("snapshot") != Knowledge.capture(world, owner): return false
	world.stage_collections([ID, "simulation"])
	for item: Dictionary in plan.domains:
		var domain: String = str(item.domain)
		if world.state[ID].last[domain] != "" and _fact(world.state, world.state[ID].last[domain]).turn == world.state.turn: return false
		var outcome: String = "none"; var produced: String = ""
		Producers.commit_scan(world, item.origins, plan.snapshot)
		for rejected: Dictionary in item.pending.reject:
			if rejected.reason != "already_consumed" and not world.close_prayer_source(rejected.source, rejected.reason, owner): return false
		var selected: String = str(item.pending.selected)
		if not item.origin_selected.is_empty():
			var root: String = "ROOT_KNOWN_RECORD" if item.origin_selected.descriptor.content_id == "PRAYER_04" else "ROOT_CURRENT_RITUAL"
			if not coordinator.candidate_handlers.has(root) or not coordinator.candidate_handlers[root].is_valid(): return false
			var originated: Dictionary = coordinator.candidate_handlers[root].call(world, {"root": root, "existing": item.origin_selected, "snapshot": plan.snapshot}, owner)
			if not originated.get("ok", false): return false
			outcome = str(originated.outcome); produced = str(originated.get("source", ""))
		if not selected.is_empty():
			var current: Dictionary = owner._participants.prayers.instance.validate_situation(world, selected)
			if current.ok:
				var preview: Dictionary = world.preview_prayer_fix(selected, owner)
				if preview.ok:
					if not world.fix_prayer_source(selected, owner): return false
					outcome = "fixed"
				else:
					outcome = str(preview.outcome)
					if outcome == "no_action_window" and not world.close_prayer_source(selected, outcome, owner): return false
			else:
				outcome = "source_changed"
				if current.get("permanent", true) and not world.close_prayer_source(selected, current.error, owner): return false
		var choice: Dictionary = item.choice
		var new_outcome: String = "not_due" if not item.opportunity else "empty"
		if not choice.is_empty():
			if not coordinator.candidate_handlers.has(choice.root) or not coordinator.candidate_handlers[choice.root].is_valid(): return false
			var applied: Dictionary = coordinator.candidate_handlers[choice.root].call(world, choice, owner)
			if not applied.get("ok", false): return false
			new_outcome = str(applied.outcome)
			if not str(applied.get("source", "")).is_empty(): produced = str(applied.source)
		world.state.simulation.cursors[domain] = item.after.duplicate(true)
		world.state[ID].positions[domain] = item.position_after.duplicate(true)
		var parents: Array = item.pending.checked.duplicate()
		if not produced.is_empty(): parents.append(produced)
		var source: String = world._record("prayer_dispatch_tick", domain, "", [domain], world._unique_sorted(parents), {"version": world.state[ID].version, "snapshot": plan.snapshot, "mode": item.mode, "before": item.before, "after": item.after, "position_before": item.position_before, "position_after": item.position_after, "checked": item.pending.checked, "selected": selected, "origins": item.origins, "origin_selected": item.origin_selected, "existing_outcome": outcome, "opportunity": item.opportunity, "eligible": item.eligible, "notice_scan": item.notice_scan, "choice": choice, "new_outcome": new_outcome, "produced": produced, "notice_checked": item.notice_checked})
		world.state[ID].last[domain] = source
	return true

static func notice(world: RefCounted, choice: Dictionary, coordinator: Object, owner: Object) -> Dictionary:
	if not Knowledge._notice_objects(world, choice.selection): return {"ok": true, "outcome": "notice_objects_changed"}
	var authorized: Dictionary = Knowledge.authorize_notice(world, choice.selection, coordinator, owner)
	if not authorized.get("ok", false): return authorized
	var result: Dictionary = Knowledge.tell(world, authorized.authorization, owner)
	if not result.get("ok", false): return result
	return {"ok": true, "outcome": "identity_received", "source": result.source}

static func _same_keys(value: Dictionary, expected: Array) -> bool:
	var keys: Array = value.keys(); keys.sort(); var wanted: Array = expected.duplicate(); wanted.sort(); return keys == wanted

static func validate_state(state: Dictionary, content: RefCounted, policy: String, parameters: Dictionary, trusted: Dictionary = {}) -> Array[String]:
	if not state.has(ID):
		if trusted.has(ID) or state.has("event_system"): return ["Installed prayer dispatcher disappeared"]
		return []
	var ledger: Variant = state[ID]
	if not ledger is Dictionary or not _same_keys(ledger, ["schema", "version", "installed", "heads", "pending", "positions", "last"]) or ledger.get("schema") != SCHEMA or ledger.get("version") != version(content, policy): return ["Invalid prayer dispatch version or shape"]
	for field: String in ["heads", "pending", "positions", "last"]:
		if not ledger.get(field) is Dictionary or not _same_keys(ledger[field], state.domains.keys()): return ["Invalid prayer dispatch domain partition"]
	var install_fact: Dictionary = _fact(state, str(ledger.get("installed", "")))
	if install_fact.get("kind") != "prayer_dispatch_installed" or install_fact.turn != 0 or install_fact.changes.get("version") != ledger.version or not install_fact.changes.get("heads") is Dictionary or not install_fact.changes.get("cursors") is Dictionary: return ["Missing prayer dispatcher installation"]
	var heads: Dictionary = trusted[ID].heads.duplicate(true) if trusted.has(ID) else install_fact.changes.heads.duplicate(true)
	var pending: Dictionary = trusted[ID].pending.duplicate(true) if trusted.has(ID) else install_fact.changes.get("pending", {}).duplicate(true)
	var positions: Dictionary = trusted[ID].positions.duplicate(true) if trusted.has(ID) else {}
	var last: Dictionary = trusted[ID].last.duplicate(true) if trusted.has(ID) else {}
	var cursors: Dictionary = trusted.simulation.cursors.duplicate(true) if trusted.has(ID) else install_fact.changes.cursors.duplicate(true)
	if not trusted.has(ID):
		var initial_heads: Dictionary = {}; var initial_pending: Dictionary = {}
		for domain: String in state.domains: initial_heads[domain] = {}; initial_pending[domain] = {}; positions[domain] = POSITION.duplicate(); last[domain] = ""
		for number: int in range(1, int(str(install_fact.id).trim_prefix("FACT-"))): _replay_head(state, initial_heads, initial_pending, _fact(state, "FACT-%08d" % number))
		for domain: String in state.domains: _refresh_heads(state, initial_heads, initial_pending, domain)
		if initial_heads != heads or initial_pending != pending: return ["Dispatcher installation invented pending sources"]
	var first: int = int(trusted.next_fact) if trusted.has(ID) else int(str(install_fact.id).trim_prefix("FACT-")) + 1
	var cutoffs: Dictionary = {}
	for number: int in range(first, int(state.next_fact)):
		var candidate: Dictionary = _fact(state, "FACT-%08d" % number)
		if candidate.get("kind") == "prayer_dispatch_tick": cutoffs[int(candidate.changes.get("snapshot", {}).get("fact_cutoff", -1))] = true
	var snapshot_pending: Dictionary = pending.duplicate(true); var snapshot_positions: Dictionary = positions.duplicate(true)
	for number: int in range(first, int(state.next_fact)):
		if cutoffs.has(number - 1): snapshot_pending = pending.duplicate(true); snapshot_positions = positions.duplicate(true)
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		_replay_head(state, heads, pending, fact)
		if fact.get("kind") == "prayer_situation": positions[fact.domain].source_after = ""
		if fact.get("kind") != "prayer_dispatch_tick": continue
		var data: Dictionary = fact.changes; var domain: String = str(fact.domain)
		if not cursors.has(domain) or data.get("version") != ledger.version or not data.get("snapshot") is Dictionary or data.snapshot.get("turn") != fact.turn or data.snapshot.get("phase") != 4 or data.get("mode") not in ["detailed_candidates", "abstract_candidates_due"]: return ["Invalid dispatch tick input"]
		if not last[domain].is_empty() and _fact(state, last[domain]).turn >= fact.turn: return ["Dispatch repeated the same domain opportunity"]
		if data.get("before") != cursors[domain] or data.get("position_before") != snapshot_positions[domain] or not data.get("position_after") is Dictionary or not _same_keys(data.position_after, POSITION.keys()): return ["Dispatch cursor does not continue its original position"]
		for field: String in POSITION:
			if not data.position_after.get(field) is String: return ["Invalid dispatch scan position"]
		var due: bool = int(cursors[domain].next_turn) <= int(fact.turn)
		if data.get("opportunity") != due or not data.get("after") is Dictionary or data.after.get("seed") != cursors[domain].seed or data.after.get("next_turn") != (fact.turn + int(parameters.background_tick_interval) if due else cursors[domain].next_turn): return ["Dispatch changed its shared opportunity phase"]
		if not data.get("checked") is Array or data.checked.size() > int(parameters.decision_query_page_limit) or not data.get("notice_checked") is int or data.notice_checked < 0 or data.notice_checked > int(parameters.decision_query_page_limit): return ["Dispatch exceeded its finite page"]
		if not data.get("selected") is String or (not data.selected.is_empty() and not data.selected in data.checked): return ["Dispatch selected a source outside its page"]
		var page_errors: Array[String] = _validate_page(state, snapshot_pending[domain], data, int(parameters.decision_query_page_limit))
		if not page_errors.is_empty(): return page_errors
		if not data.get("choice") is Dictionary or not data.get("new_outcome") is String or not data.get("produced") is String: return ["Invalid dispatch production receipt"]
		if not due and (data.after != data.before or not data.choice.is_empty() or data.notice_checked != 0): return ["Dispatch sampled outside its shared opportunity"]
		var sample_errors: Array[String] = _validate_sampling(state, data, content, int(parameters.decision_query_page_limit))
		if not sample_errors.is_empty(): return sample_errors
		if data.choice.get("root") == "ROOT_IDENTITY_NOTICE" and data.new_outcome == "identity_received":
			var received: Dictionary = _fact(state, data.produced)
			if received.get("kind") != "deity_identity_received" or received.turn != fact.turn or not data.produced in fact.causal_parents: return ["Dispatch lost its actual identity receipt"]
		positions[domain] = data.position_after.duplicate(true); cursors[domain] = data.after.duplicate(true); last[domain] = fact.id
	for domain: String in state.domains: _refresh_heads(state, heads, pending, domain)
	if heads != ledger.heads or pending != ledger.pending or positions != ledger.positions or last != ledger.last: return ["Prayer dispatch current index differs from its source history"]
	if cursors != state.simulation.cursors: return ["Shared opportunity cursor changed outside its dispatcher"]
	return []

static func _validate_page(state: Dictionary, heads: Dictionary, data: Dictionary, limit: int) -> Array[String]:
	var sources: Array = heads.values()
	sources.sort_custom(func(a: String, b: String) -> bool: return _source_order(state, a) < _source_order(state, b))
	var page: Array = []
	for source: String in sources:
		if _source_order(state, source) > str(data.position_before.source_after) and page.size() < limit: page.append(source)
	if page.is_empty() and not sources.is_empty(): page = sources.slice(0, mini(sources.size(), limit))
	var raw_selected: bool = not data.get("origin_selected", {}).is_empty()
	if data.checked != page.slice(0, data.checked.size()) or (data.selected.is_empty() and not raw_selected and not page.is_empty() and state.has("prayer_system") and data.checked.size() != page.size()): return ["Dispatch inspection skipped its original finite source page"]
	if not data.selected.is_empty() and data.checked.back() != data.selected: return ["Dispatch continued after its one legal proposal"]
	var after: String = "" if data.checked.is_empty() else _source_order(state, data.checked.back())
	if not data.selected.is_empty() or raw_selected: after = ""
	if not sources.is_empty() and after == _source_order(state, sources.back()): after = ""
	if data.position_after.source_after != after: return ["Dispatch source continuation differs from its inspected page"]
	return []

static func _validate_sampling(state: Dictionary, data: Dictionary, content: RefCounted, limit: int) -> Array[String]:
	if not data.get("eligible") is Array or not data.get("notice_scan") is Dictionary: return ["Missing finite dispatch sampling proof"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = int(data.before.seed); rng.state = int(data.before.state)
	var choice: Dictionary = {}
	if data.opportunity and not data.eligible.is_empty() and rng.randi_range(1, 100) <= content.integer("ambient_event_chance"):
		choice = _weighted_choice(data.eligible, rng)
		if choice.get("legacy", false): choice.proposal["sample_before"] = data.before.state; choice.proposal["sample_after"] = str(rng.state)
	if data.choice != choice or data.after.get("state") != str(rng.state): return ["Dispatch RNG position differs from its single sampled opportunity"]
	if not data.opportunity:
		if not data.eligible.is_empty() or not data.notice_scan.is_empty() or data.position_after.notice_sender != data.position_before.notice_sender or data.position_after.notice_after != data.position_before.notice_after: return ["Dispatch moved the notice page outside its opportunity"]
		return []
	var scan: Dictionary = data.notice_scan
	if not scan.get("people") is Array or not scan.get("page") is Array or not scan.get("sender") is String or not scan.get("selection") is Dictionary or scan.page.size() > limit or scan.page.size() != data.notice_checked: return ["Invalid bounded identity-notice sampling proof"]
	var people: Array = scan.people.duplicate(); people.sort()
	if people != scan.people or people.size() != _unique(people).size(): return ["Identity notice input is not a unique current identity page"]
	for person: Variant in people:
		if not person is String or not Store.has(state.npcs, person): return ["Identity notice input invented a person"]
	var sender: String = str(data.position_before.notice_sender)
	if not sender in people: sender = "" if people.is_empty() else str(people[0])
	if scan.sender != sender: return ["Identity notice skipped its original sender cursor"]
	var start: String = str(data.position_before.notice_after) if sender == data.position_before.notice_sender else ""
	var page: Array = []
	if not sender.is_empty() and Knowledge.known(state, sender, data.snapshot).get("known", false):
		for recipient: String in people:
			if recipient > start and page.size() < limit: page.append(recipient)
	if scan.page != page.slice(0, scan.page.size()): return ["Identity notice recipient page skipped identities"]
	if scan.selection.is_empty() and scan.page != page: return ["Identity notice abandoned an unfinished page"]
	if not scan.selection.is_empty() and (scan.page.is_empty() or scan.selection.get("recipient") != scan.page.back() or scan.selection.get("sender") != sender or scan.selection.get("snapshot") != data.snapshot): return ["Identity notice selection differs from its finite page"]
	var after: String = "" if scan.page.is_empty() else str(scan.page.back())
	var next_sender: String = sender
	if after.is_empty() or (not people.is_empty() and after == people.back()):
		next_sender = "" if people.is_empty() else str(people[(people.find(sender) + 1) % people.size()]); after = ""
	if scan.get("notice_sender") != next_sender or scan.get("notice_after") != after or data.position_after.notice_sender != next_sender or data.position_after.notice_after != after: return ["Identity notice continuation differs from its inspected page"]
	if data.eligible.size() > Producers.ROOTS.size() + Sources.ROOTS.size() + 1: return ["Dispatch opportunity contains duplicated handlers"]
	var roots: Dictionary = {}
	for option: Variant in data.eligible:
		if not option is Dictionary or roots.has(option.get("root", "")): return ["Dispatch opportunity repeated a root handler"]
		roots[option.get("root", "")] = true
		if option.get("root") == "ROOT_IDENTITY_NOTICE":
			if option.get("legacy", true) or scan.selection.is_empty() or option.get("selection") != scan.selection: return ["Dispatch notice is not its inspected identity selection"]
		elif option.get("root") in Sources.ROOTS:
			if not state.has(Sources.ID) or option.get("legacy", true) or not option.get("proposal") is Dictionary or option.proposal.get("root") != option.root or option.get("snapshot") != data.snapshot: return ["Dispatch incident proposal changed its registered root binding"]
		else:
			if option.get("legacy", true) or not option.get("proposal") is Dictionary or not Producers.ROOTS.has(option.get("root", "")) or Producers.ROOTS[option.root] != option.proposal.get("content_id") or option.proposal.get("root") != option.root or option.get("snapshot") != data.snapshot: return ["Dispatch origin proposal changed its registered root binding"]
	return []

static func _unique(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values: result[value] = true
	return result
