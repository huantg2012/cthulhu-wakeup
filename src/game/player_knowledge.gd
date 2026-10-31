extends RefCounted
## Detached reducer for the existing player ledger. No world, clock or random writes.
const Store = preload("res://src/simulation/archive_store.gd")
const Anchors = preload("res://src/game/anchors.gd")
const VERSION: String = "player-knowledge/2/turn-owned"
const PRAYER_SUBJECTS: Dictionary = {"PRAYER_01": ["petitioner", "relative"], "PRAYER_02": ["petitioner", "rival"], "PRAYER_03": ["petitioner", "pursuer"], "PRAYER_04": ["petitioner", "second"], "PRAYER_05": ["petitioner"], "PRAYER_06": ["petitioner", "counterparty"], "PRAYER_07": ["petitioner", "memory_people"], "PRAYER_08": ["petitioner"], "PRAYER_09": ["petitioner"], "PRAYER_10": ["petitioner", "opponent"], "PRAYER_11": ["petitioner", "relic"], "PRAYER_12": ["petitioner", "other_institution"]}
var state: Dictionary
var cursor: Dictionary
var catalog: RefCounted
var history: RefCounted
var proofs: Array
var _knowledge_cursor: int = 1
var _known_domains: Dictionary = {}
var _known_people: Dictionary = {}
var _known_facts: Dictionary = {}
var _known_kinds: Dictionary = {}
var _known_relics: Dictionary = {}
var _domain_intelligence: Dictionary = {}
var _known_prayers: Dictionary = {}
var _known_events: Dictionary = {}
var _request_domains: Dictionary = {}
var _request_people: Dictionary = {}
var _request_objects: Dictionary = {}

static func empty_ledger() -> Dictionary:
	return {"cursor": 1, "known_domains": {}, "known_people": {}, "known_facts": {}, "known_kinds": {}, "known_relics": {}, "domain_intelligence": {}, "known_prayers": {}, "known_events": {}, "request_domains": {}, "request_people": {}, "request_objects": {}}

func _init(world_state: Dictionary, turn_context: Dictionary, ledger: Dictionary, content: RefCounted, index: RefCounted, available_proofs: Array = []) -> void:
	state = world_state; cursor = turn_context; catalog = content; history = index; proofs = available_proofs
	_knowledge_cursor = int(ledger.get("cursor", 1))
	_known_domains = ledger.get("known_domains", {}).duplicate(true)
	_known_people = ledger.get("known_people", {}).duplicate(true)
	_known_facts = ledger.get("known_facts", {}).duplicate(true)
	_known_kinds = ledger.get("known_kinds", {}).duplicate(true)
	_known_relics = ledger.get("known_relics", {}).duplicate(true)
	_domain_intelligence = ledger.get("domain_intelligence", {}).duplicate(true)
	_known_prayers = ledger.get("known_prayers", {}).duplicate(true)
	_known_events = ledger.get("known_events", {}).duplicate(true)
	_request_domains = ledger.get("request_domains", {}).duplicate(true)
	_request_people = ledger.get("request_people", {}).duplicate(true)
	_request_objects = ledger.get("request_objects", {}).duplicate(true)

func snapshot() -> Dictionary:
	return {"cursor": _knowledge_cursor, "known_domains": _known_domains.duplicate(true), "known_people": _known_people.duplicate(true), "known_facts": _known_facts.duplicate(true), "known_kinds": _known_kinds.duplicate(true), "known_relics": _known_relics.duplicate(true), "domain_intelligence": _domain_intelligence.duplicate(true), "known_prayers": _known_prayers.duplicate(true), "known_events": _known_events.duplicate(true), "request_domains": _request_domains.duplicate(true), "request_people": _request_people.duplicate(true), "request_objects": _request_objects.duplicate(true)}

static func reduce(world_state: Dictionary, turn_context: Dictionary, ledger: Dictionary, content: RefCounted, index: RefCounted, available_proofs: Array, update: Dictionary = {}) -> Dictionary:
	var projection: RefCounted = load("res://src/game/player_knowledge.gd").new(world_state, turn_context, ledger, content, index, available_proofs)
	projection._refresh_knowledge(bool(update.get("own_action", false)), int(update.get("first_fact", -1)), update.get("roots", {}))
	return projection.snapshot()

static func learn(world_state: Dictionary, turn_context: Dictionary, ledger: Dictionary, content: RefCounted, index: RefCounted, source: String, restoring: bool = false) -> Dictionary:
	var projection: RefCounted = load("res://src/game/player_knowledge.gd").new(world_state, turn_context, ledger, content, index)
	projection._learn(source, restoring)
	return projection.snapshot()

static func restore_ledger(world_state: Dictionary, turn_context: Dictionary, saved: Dictionary, content: RefCounted, index: RefCounted) -> Dictionary:
	var projection: RefCounted = load("res://src/game/player_knowledge.gd").new(world_state, turn_context, empty_ledger(), content, index)
	projection._rebuild_knowledge(saved)
	return projection.snapshot()

static func command_roots(world_state: Dictionary, turn_context: Dictionary, ledger: Dictionary, content: RefCounted, index: RefCounted, request: Dictionary) -> Dictionary:
	return load("res://src/game/player_knowledge.gd").new(world_state, turn_context, ledger, content, index)._command_knowledge_roots(request)

static func _internal_fact(kind: String) -> bool:
	return kind.begins_with("opportunity_") or kind in ["route_attempt", "route_progress", "prayer_call", "prayer_call_basis", "prayer_need_selected", "prayer_dispatch_tick", "prayer_contact_selected", "prayer_producer_update", "identity_notice_selected", "deity_identified", "deity_identity_received", "prayer_bootstrap"]

static func validate_ledger(state: Dictionary, ledger: Dictionary) -> Array[String]:
	if not ledger.get("cursor") is int or ledger.cursor < 1 or ledger.cursor > int(state.next_fact): return ["Invalid player knowledge cursor"]
	for field: String in empty_ledger():
		if field == "cursor": continue
		if not ledger.get(field) is Dictionary: return ["Missing player knowledge field: " + field]
	for source: String in ledger.known_facts:
		if not Store.has(state.facts, source) or _internal_fact(str(Store.entry(state.facts, source).kind)): return ["Invalid player knowledge source"]
	for pair: Array in [["known_domains", "domains"], ["known_people", "npcs"], ["known_relics", "relics"]]:
		for id: String in ledger[pair[0]]:
			if not Store.has(state.get(pair[1], {}), id): return ["Invalid known entity"]
	return []

func _learn(source: String, restoring: bool = false) -> void:
	if not Store.has(state.facts, source): return
	var fact: Dictionary = Store.entry(state.facts, source)
	if _internal_fact(str(fact.kind)): return
	if fact.kind == "anchor_basis" and not restoring and not _basis_visible(fact): return
	var limited: bool = fact.kind in ["prayer_fixed", "prayer_registered", "prayer_attempt"] or (fact.kind == "background_fixed" and str(fact.changes.get("candidate", {}).get("content_id", "")).begins_with("PRAYER_"))
	if limited:
		var fixed: Dictionary = fact.changes.get("candidate", {})
		var request_id: String = str(fixed.get("id", fact.changes.get("request", "")))
		if not restoring and not request_id in state.prayer_system.offered and not _known_prayers.has(request_id): return
		if not fixed.is_empty() and int(fixed.get("visible_turn", 0)) > int(cursor.turn): return
	_known_facts[source] = true
	if not _known_kinds.has(fact.kind): _known_kinds[fact.kind] = {}
	_known_kinds[fact.kind][source] = true
	if fact.kind in ["background_fixed", "prayer_fixed", "event_fixed"]:
		var card: Variant = fact.changes.get("candidate", {})
		if card is Dictionary and card.has("id"):
			if str(card.get("content_id", "")).begins_with("PRAYER_"):
				var remembered: Dictionary = _known_prayers.get(card.id, {})
				remembered["card"] = card.duplicate(true); _known_prayers[card.id] = remembered
			elif str(card.get("content_id", "")).begins_with("EVENT_"): _known_events[card.id] = {"card": card.duplicate(true), "descriptor": card.get("descriptor", {}).duplicate(true)}
	if fact.kind in ["prayer_registered", "prayer_attempt"] and fact.changes.get("descriptor") is Dictionary:
		var request_id: String = str(fact.changes.get("request", ""))
		var remembered: Dictionary = _known_prayers.get(request_id, {})
		remembered["descriptor"] = fact.changes.descriptor.duplicate(true)
		if fact.kind == "prayer_registered": remembered["source"] = source
		_known_prayers[request_id] = remembered
	if limited:
		var remembered: Dictionary = _known_prayers.get(str(fact.changes.get("candidate", {}).get("id", fact.changes.get("request", ""))), {})
		_request_clues(remembered.get("descriptor", {}), remembered.get("card", {}))
		return
	var request_only: bool = _request_domains.has(fact.domain) and not _known_domains.has(fact.domain) and fact.kind != "world_origin"
	if not request_only and state.domains.has(fact.domain): _known_domains[fact.domain] = true
	# Knowledge never follows causal parents or another person's memory.
	for person: String in [str(fact.get("actor", ""))] + fact.get("targets", []):
		if not request_only and Store.has(state.npcs, person): _known_people[person] = true
		if Store.has(state.relics, person): _known_relics[person] = true
	for field: String in ["relic", "relic_id"]:
		var relic: String = str(fact.changes.get(field, ""))
		if Store.has(state.relics, relic): _known_relics[relic] = true
	var subject_sets: Array = [fact.changes.get("subjects", {})]
	for field: String in ["candidate", "descriptor"]:
		var nested: Variant = fact.changes.get(field, {})
		if nested is Dictionary: subject_sets.append(nested.get("subjects", {}))
	for subjects: Variant in subject_sets:
		if not subjects is Dictionary: continue
		var relic: String = str(subjects.get("relic", ""))
		if Store.has(state.relics, relic): _known_relics[relic] = true
	var created_relic: String = "RELIC/" + source
	if fact.kind == "relic_create_authorized" and Store.has(state.relics, created_relic): _known_relics[created_relic] = true
	# This existing typed fact records an exact observed wall value. Power and
	# prayer deltas alone do not reveal the hidden initial or current total.
	if fact.kind == "resistance_breach" and fact.changes.get("barrier") is int:
		if not _domain_intelligence.has(fact.domain): _domain_intelligence[fact.domain] = {}
		var previous: Dictionary = _domain_intelligence[fact.domain].get("barrier", {})
		if previous.is_empty() or source > str(previous.source): _domain_intelligence[fact.domain].barrier = {"value": fact.changes.barrier, "source": source, "turn": fact.turn, "label": "最后获知"}

static func request_subjects(descriptor: Dictionary, card: Dictionary = {}) -> Dictionary:
	var content: String = str(descriptor.get("content_id", card.get("content_id", "")))
	var subjects: Dictionary = descriptor.get("subjects", card.get("subjects", {}))
	var result: Dictionary = {}
	for role: String in PRAYER_SUBJECTS.get(content, ["petitioner"]):
		if subjects.has(role): result[role] = subjects[role].duplicate(true) if subjects[role] is Array else subjects[role]
	return result

func _request_clues(descriptor: Dictionary, card: Dictionary) -> void:
	var domain: String = str(descriptor.get("domain", card.get("domain", "")))
	if state.domains.has(domain): _request_domains[domain] = true
	for value: Variant in request_subjects(descriptor, card).values():
		var ids: Array = value if value is Array else [value]
		for id: Variant in ids:
			if not id is String: continue
			if Store.has(state.npcs, id): _request_people[id] = domain
			elif Store.has(state.relics, id): _request_objects[id] = {"kind": "relic", "domain": domain}
			elif state.institutions.has(id): _request_objects[id] = {"kind": "institution", "domain": domain}

func _learn_card(descriptor: Dictionary, card: Dictionary) -> void:
	var prayer: bool = str(card.get("content_id", descriptor.get("content_id", ""))).begins_with("PRAYER_")
	if prayer and (not card.get("id", "") in state.prayer_system.offered or int(card.get("visible_turn", 0)) > int(cursor.turn)): return
	if card.has("id"):
		var remembered: Dictionary = {"card": card.duplicate(true), "descriptor": descriptor.duplicate(true)}
		if prayer:
			remembered.merge(_known_prayers.get(card.id, {})); _known_prayers[card.id] = remembered
		elif str(card.get("content_id", "")).begins_with("EVENT_"): _known_events[card.id] = remembered
	if prayer:
		_request_clues(descriptor, card)
		for source: String in [str(card.get("fact", "")), str(descriptor.get("source", ""))]:
			# The world source/knowledge chain stays private. Only visible receipts
			# enter history, and can seed the existing response disclosure chain.
			if Store.has(state.facts, source) and Store.entry(state.facts, source).kind in ["prayer_fixed", "background_fixed", "prayer_registered"]: _learn(source)
		return
	if descriptor.get("prayer_descriptor") is Dictionary:
		_request_clues(descriptor.prayer_descriptor, card)
		for source: String in [str(card.get("fact", "")), str(descriptor.get("source", ""))]: _learn(source)
		return
	var domain: String = str(descriptor.get("domain", card.get("domain", "")))
	if state.domains.has(domain): _known_domains[domain] = true
	for person: String in descriptor.get("actors", card.get("actors", [])):
		if Store.has(state.npcs, person): _known_people[person] = true
	for value: Variant in descriptor.get("subjects", {}).values():
		var values: Array = value if value is Array else [value]
		for person: Variant in values:
			if person is String and Store.has(state.npcs, person): _known_people[person] = true
			if person is String and Store.has(state.relics, person): _known_relics[person] = true
	for source: String in [str(card.get("fact", "")), str(descriptor.get("source", card.get("source", "")))]: _learn(source)
	for value: Variant in descriptor.get("facts", {}).values():
		var values: Array = value if value is Array else [value]
		for source: Variant in values:
			if source is String: _learn(source)

func _command_knowledge_roots(request: Dictionary) -> Dictionary:
	var roots: Dictionary = {}
	for input: Dictionary in [request.get("payload", {}), request.get("command", {})]:
		var source: String = str(input.get("source", ""))
		if _known_facts.has(source): roots[source] = true
	if request.op == "act" and request.get("participant") == "prayers":
		var prayer: Dictionary = Store.entry(state.prayer_system.requests, request.get("payload", {}).get("request", ""), {})
		if not prayer.is_empty():
			for source: String in [prayer.card.fact, str(prayer.descriptor.source), str(prayer.get("source", ""))]:
				if _known_facts.has(source): roots[source] = true
	var events: Array = []
	if request.op == "resolve_event": events = [str(request.get("event", ""))]
	if request.op == "finish_events": events = state.event_system.selected
	for id: String in events:
		var event: Dictionary = event_entry(id)
		if event.is_empty(): continue
		for source: String in [event.card.fact, str(event.descriptor.source)]:
			if _known_facts.has(source): roots[source] = true
	return roots

func _refresh_knowledge(own_action: bool, first_fact: int = -1, roots: Dictionary = {}) -> void:
	for id: String in state.attention.members:
		var person: Dictionary = Store.entry(state.npcs, id)
		_known_people[id] = true
		for relic_id: String in history.ids("holder/" + id): _known_relics[relic_id] = true
	for id: String in state.prayer_system.offered:
		var request: Dictionary = prayer_entry(id)
		if request.has("source"): _learn(str(request.source))
		_learn_card(request.get("descriptor", {}), request.get("card", {}))
	for id: String in state.event_system.selected:
		var event: Dictionary = event_entry(id)
		_learn_card(event.get("descriptor", {}), event.get("card", {}))
	var start: int = _knowledge_cursor if first_fact < 0 else mini(_knowledge_cursor, first_fact)
	var action_chain: Dictionary = roots.duplicate()
	for number: int in range(start, int(state.next_fact)):
		var source: String = "FACT-%08d" % number
		var fact: Dictionary = Store.entry(state.facts, source)
		# Automatically derived qualifications are never command disclosures. Their
		# exact original fact must already be known before availability can expose it.
		if fact.kind == "power_qualification": continue
		var command_result: bool = own_action and number >= first_fact and fact.causal_parents.any(func(parent: String) -> bool: return action_chain.has(parent))
		if command_result:
			_learn(source); action_chain[source] = true
		elif own_action and fact.kind == "economy_rest": _learn(source)
		elif fact.kind in ["ending_assessed", "ending_sealed"]: _learn(source)
		elif _known_domains.has(fact.domain) and fact.get("changes", {}).get("public", false): _learn(source)
		elif fact.kind == "cult_established" and _known_people.has(fact.actor): _learn(source)
		elif fact.kind == "resistance_started" and _known_domains.has(fact.domain): _learn(source)
		if fact.kind == "power_attempt" and fact.changes.get("power") == "POWER_LISTEN" and _known_facts.has(source):
			_learn(str(fact.changes.get("proofs", {}).get("listen", {}).get("basis", {}).get("fact", "")))
	# Availability is a rule query. A proof only enters player knowledge after
	# its exact production origin has actually been exposed to this player.
	for proof: Dictionary in proofs:
		if proof.changes.get("rule") == "spread":
			if _spread_visible(proof): _learn(proof.id)
		elif _known_facts.has(str(proof.changes.get("origin", ""))): _learn(proof.id)
	for sources: Dictionary in state.get("anchor_system", {}).get("routes", {}).values():
		for source: String in sources.values():
			var basis: Dictionary = Store.entry(state.facts, source, {})
			if _basis_visible(basis): _learn(source)
	_knowledge_cursor = int(state.next_fact)

func _spread_visible(proof: Dictionary) -> bool:
	if not _known_people.has(proof.actor) or not _known_domains.has(proof.domain): return false
	var cult: Dictionary = state.cults.get(proof.changes.target, {})
	if not _known_facts.has(str(cult.get("established_source", ""))) or not _known_people.has(str(cult.get("leader", ""))): return false
	var origin: Dictionary = Store.entry(state.facts, proof.changes.origin, {})
	var channel: Dictionary = Store.entry(state.facts, origin.get("changes", {}).get("basis", {}).get("channel", ""), {})
	if channel.get("changes", {}).get("route_id") == "ALLIED_CHANNEL" and not _known_facts.has(str(channel.changes.origin)): return false
	var permission: Dictionary = Anchors.evaluate(state, proof.changes.institution, proof.changes.basis.profile_rule, catalog, history, "spread", proof.actor)
	if not permission.get("allowed", false): return false
	for original: String in permission.originals:
		if not _known_people.has(original): return false
	for carrier: Dictionary in permission.basis.carriers:
		if not _known_people.has(carrier.person): return false
	for dependency: String in permission.dependencies:
		if not _known_facts.has(dependency): return false
	return true

func _basis_visible(fact: Dictionary) -> bool:
	if fact.get("kind") != "anchor_basis" or not _known_domains.has(fact.get("domain", "")): return false
	for target: String in fact.get("targets", []):
		if Store.has(state.npcs, target) and not _known_people.has(target): return false
	for source: String in fact.get("causal_parents", []):
		if not _known_facts.has(source): return false
	var permission: Dictionary = Anchors.qualify(state, str(fact.changes.get("institution", "")), str(fact.get("id", "")), catalog, history)
	return permission.get("allowed", false)

func prayer_entry(id: String) -> Dictionary:
	var current: Dictionary = Store.entry(state.prayer_system.requests, id, {})
	if not current.is_empty(): return current
	if not _known_prayers.has(id): return {}
	var remembered: Dictionary = _known_prayers[id].duplicate(true)
	remembered["status"] = "closed"
	remembered["reason"] = "原请求已关闭；人物、处境与原期限保留在历史中"
	return remembered

func event_entry(id: String) -> Dictionary:
	var current: Dictionary = Store.entry(state.event_system.cards, id, {})
	if not current.is_empty(): return current
	if not _known_events.has(id): return {}
	return _known_events[id].duplicate(true)

func _rebuild_knowledge(knowledge: Dictionary) -> void:
	_knowledge_cursor = int(knowledge.cursor)
	_known_domains = {}; _known_people = {}; _known_facts = {}; _known_kinds = {}; _known_relics = {}; _domain_intelligence = {}; _known_prayers = {}; _known_events = {}; _request_domains = {}; _request_people = {}; _request_objects = {}
	for id: String in knowledge.domains: _known_domains[id] = true
	for id: String in knowledge.people: _known_people[id] = true
	# Seed request clues only from facts already saved in this player's ledger.
	# Results are read afterwards so reverse ordering cannot promote a clue domain.
	for id: String in knowledge.facts:
		var fact: Dictionary = Store.entry(state.facts, id)
		var changes: Dictionary = fact.get("changes", {})
		if fact.kind in ["prayer_registered", "prayer_attempt"]:
			_request_clues(changes.get("descriptor", {}), {})
		elif fact.kind in ["prayer_fixed", "background_fixed"]:
			var card: Dictionary = changes.get("candidate", {})
			if str(card.get("content_id", "")).begins_with("PRAYER_") and int(card.get("visible_turn", 0)) <= int(cursor.turn): _request_clues({}, card)
	for id: String in knowledge.facts: _learn(id, true)
	for id: String in state.attention.members:
		for relic_id: String in history.ids("holder/" + id): _known_relics[relic_id] = true

## A derived basis reveals no additional person or material. It becomes selectable
## only after those concrete inputs were already disclosed by their own rules.
