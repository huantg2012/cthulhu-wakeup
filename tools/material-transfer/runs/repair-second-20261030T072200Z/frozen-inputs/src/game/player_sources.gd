extends RefCounted
## Converts authored, object-bound production facts into existing power proofs.
## Presentation can enumerate these facts, but cannot mint them.
const Store = preload("res://src/simulation/archive_store.gd")
const ID: String = "player_sources"
const PATH: String = "res://data/player_source_rules.csv"
var catalog: RefCounted
var version: String
var rules: Dictionary = {}
var error: String = ""

func _init(content: RefCounted) -> void:
	catalog = content; version = rule_version(content)
	if content.tables.has("cult_spread_routes"):
		error = "PlayerSources does not implement CULT schema2 covert_spread_basis; TASK-CULT-SPREAD required"
		return
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null: error = "Missing player source rules"; return
	if Array(file.get_csv_line()) != ["id", "rule", "source_kind", "tag", "selector"]: error = "Invalid player source header"; return
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != 5 or rules.has(cells[0]): error = "Invalid player source rule"; return
		var row: Dictionary = {"id": cells[0], "rule": cells[1], "source_kind": cells[2], "tag": cells[3], "selector": cells[4]}
		if not row.rule in ["dream", "listen", "weakness", "spread", "evidence", "tenure", "witness", "milestone"] or not row.selector in ["fixed_prayer_actor", "barrier_subject", "joined_member", "propagation_permit", "clue_fact", "propagation_evidence", "prayer_actor"]: error = "Unsupported player source rule"; return
		rules[row.id] = row

static func rule_version(content: RefCounted) -> String:
	return "1/" + content.version + "/" + FileAccess.get_file_as_string(PATH).sha256_text()

static func issuer_capability(content: RefCounted) -> Dictionary:
	return {ID: rule_version(content)}

func install(turn: RefCounted) -> bool:
	if not error.is_empty() or not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has(ID): return false
	if turn.world.state.get("power_system", {}).get("issuers", {}).get(ID) != version: return false
	turn.world.state[ID] = {"schema": 1, "version": version, "origins": {}, "proofs": {}, "derivatives": {}}
	if not turn.register_participant(ID, version, [ID], [], handle): turn.world.state.erase(ID); return false
	if not refresh(turn.world, turn, 1): return false
	return turn.world.ensure_history(true)

func handle(_view: Dictionary, _input: Dictionary) -> Dictionary:
	return {"ok": false, "error": "Source production has no player action"}

func _fact(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.facts, id): return Store.entry(state.facts, id)
	if reader == null: return {}
	var found: Dictionary = reader.fact(id)
	return found.item if found.ok else {}

func _person(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.npcs, id): return Store.entry(state.npcs, id)
	if reader == null: return {}
	var found: Dictionary = reader.entity("npcs", id)
	return found.item if found.ok else {}

func _invalid(state: Dictionary, id: String, reader: RefCounted = null) -> bool:
	return reader.invalidated(id) if reader != null else Store.has(state.invalid_records, id)

func _used(state: Dictionary, key: String, reader: RefCounted = null) -> bool:
	if reader == null: return Store.has(state.applied_authorizations, key)
	var result: Dictionary = reader.authorization(key)
	return not result.ok or result.used

func _matches(fact: Dictionary, row: Dictionary) -> bool:
	return fact.get("kind") == row.source_kind and (row.tag.is_empty() or fact.changes.get("tag") == row.tag)

func _propagation_benefit(fact: Dictionary) -> bool:
	return (fact.get("kind") == "economy_qualification" and fact.changes.get("rule") == "propagation" and fact.changes.get("allowed") == true) or (fact.get("kind") == "power_qualification" and fact.changes.get("rule") == "spread" and fact.changes.get("issuer") != ID)

func _actors(state: Dictionary, fact: Dictionary, row: Dictionary, history: RefCounted) -> Array:
	match row.selector:
		"fixed_prayer_actor": return fact.changes.get("candidate", {}).get("actors", []).slice(0, 1)
		"barrier_subject": return fact.changes.get("candidate", {}).get("actors", []).slice(0, 1) if fact.kind == "background_fixed" else [str(fact.changes.get("subject", ""))]
		"joined_member": return [str(fact.actor)]
		"prayer_actor": return [str(fact.changes.get("subjects", {}).get("petitioner", ""))]
		"clue_fact": return [""]
		"propagation_permit", "propagation_evidence":
			return state.attention.members.keys() if state.has("attention") else history.ids("active/" + str(fact.domain))
	return []

func _plan(state: Dictionary, fact: Dictionary, row: Dictionary, actor: String, reader: RefCounted = null, current: bool = true) -> Dictionary:
	if not _matches(fact, row) or (current and _invalid(state, str(fact.id), reader)): return {}
	var person: Dictionary = _person(state, actor, reader)
	if not actor.is_empty() and (person.is_empty() or (current and (person.status == "dead" or person.domain != fact.domain))): return {}
	var target: String = actor
	var institution: String = str(fact.changes.get("institution", ""))
	var basis: Dictionary = {}
	match row.selector:
		"fixed_prayer_actor":
			var card: Dictionary = fact.changes.get("candidate", {})
			if not str(card.get("content_id", "")).begins_with("PRAYER_") or card.get("actors", []).is_empty() or actor != card.actors[0]: return {}
			if current and (not state.get("simulation", {}).get("candidates", {}).has(card.id) or int(card.due_turn) < int(state.turn)): return {}
			basis = {"contact": fact.id}
		"barrier_subject":
			if fact.kind == "background_fixed":
				var card: Dictionary = fact.changes.get("candidate", {})
				if card.get("template") != "BG_ESCAPE" or card.get("actors", []).is_empty() or card.actors[0] != actor: return {}
				if current and (not state.simulation.candidates.has(card.id) or int(card.due_turn) < int(state.turn) or int(state.domains[fact.domain].barrier) <= 0 or state.institutions.get(str(person.get("institution", "")), {}).get("links", []).is_empty()): return {}
			else:
				if fact.changes.get("subject") != actor or not fact.changes.get("barrier_source") is String: return {}
				if current and state.domains[fact.domain].barrier_source != fact.changes.barrier_source: return {}
			basis = {"source": fact.id}
		"joined_member":
			target = str(fact.changes.get("cult", ""))
			if fact.actor != actor or not actor in fact.targets or target.is_empty(): return {}
			if current and (person.get("joined_source") != fact.id or person.get("cult_id") != target or not person.get("bound_member", false) or int(state.turn) - int(fact.turn) < catalog.integer("sacrifice_min_tenure")): return {}
			basis = {"joined": fact.id}
		"propagation_permit":
			target = str(fact.changes.get("subject", ""))
			if fact.changes.get("rule") != "propagation" or fact.changes.get("allowed") != true or institution.is_empty(): return {}
			if current and (state.economy_qualifications.get("propagation|" + target) != fact.id or not person.get("bound_member", false) or person.get("cult_id") != target): return {}
			basis = {"institution": institution, "sources": [fact.id]}
		"clue_fact":
			target = str(fact.changes.get("fact", fact.changes.get("target_fact", "")))
			if target.is_empty():
				var pointers: Array = []
				for pointer: String in fact.targets:
					if not _fact(state, pointer, reader).is_empty(): pointers.append(pointer)
				if pointers.size() == 1: target = pointers[0]
			if not actor.is_empty() or target.is_empty() or _fact(state, target, reader).is_empty() or (current and _invalid(state, target, reader)): return {}
			basis = {"clue": fact.id, "fact": target}
		"prayer_actor":
			if fact.changes.get("subjects", {}).get("petitioner") != actor or not actor in fact.targets or not row.rule in ["witness", "milestone"]: return {}
			basis = {"source": fact.id}
		"propagation_evidence":
			target = str(person.get("cult_id", ""))
			if target.is_empty() or (current and (not person.get("bound_member", false) or state.cults.get(target, {}).get("status") != "active")): return {}
			var benefits: Array = state.get(ID, {}).get("derivatives", {}).get(fact.id, []).duplicate()
			for derivative: String in benefits:
				if not fact.id in _fact(state, derivative, reader).get("causal_parents", []): return {}
			basis = {"source": fact.id, "benefits": benefits, "member": str(person.get("joined_source", ""))}
	if basis.is_empty(): return {}
	if current:
		var consumed: String = ""
		if row.rule == "listen": consumed = "power/revealed/" + target
		elif row.rule in ["evidence", "weakness", "witness"]: consumed = "power/" + str(row.rule) + "/" + str(fact.id)
		if not consumed.is_empty() and _used(state, consumed, reader): return {}
	return {"issuer": ID, "version": version, "rule": row.rule, "actor": actor, "target": target, "institution": institution, "basis": basis, "origin": fact.id, "rule_id": row.id}

func refresh(world: RefCounted, owner: RefCounted, first_fact: int) -> bool:
	if not error.is_empty() or not world._driver_allowed(owner) or world.state.get(ID, {}).get("version") != version: return false
	world.stage_collections([ID, "applied_authorizations"])
	var ledger: Dictionary = world.state[ID]
	var last: int = int(world.state.next_fact)
	for number: int in range(first_fact, last):
		var fact: Dictionary = Store.entry(world.state.facts, "FACT-%08d" % number)
		for row: Dictionary in rules.values():
			if _matches(fact, row): ledger.origins[str(fact.id) + "/" + str(row.id)] = {"source": fact.id, "rule": row.id}
	# Each incoming fact is visited once; dependencies of active roots stay current.
	var roots: Dictionary = {}
	for entry: Dictionary in ledger.origins.values():
		if rules[entry.rule].selector == "propagation_evidence": roots[entry.source] = true
	for source: String in ledger.derivatives.keys():
		if not roots.has(source): ledger.derivatives.erase(source)
	for source: String in roots:
		if not ledger.derivatives.has(source): ledger.derivatives[source] = []
	for number: int in range(first_fact, last):
		var child: Dictionary = Store.entry(world.state.facts, "FACT-%08d" % number)
		if not _propagation_benefit(child): continue
		for parent: String in child.causal_parents:
			if roots.has(parent) and not child.id in ledger.derivatives[parent]: ledger.derivatives[parent].append(child.id)
	var proofs: Dictionary = {}
	for key: String in ledger.origins.keys():
		var entry: Dictionary = ledger.origins[key]
		var fact: Dictionary = Store.entry(world.state.facts, entry.source)
		var row: Dictionary = rules[entry.rule]
		var retained: bool = false
		for actor: String in _actors(world.state, fact, row, world.history):
			var plan: Dictionary = _plan(world.state, fact, row, actor)
			if plan.is_empty(): continue
			retained = true
			var identity: String = "player-source/" + JSON.stringify(plan, "", true, true).sha256_text()
			var source: String = Store.entry(world.state.applied_authorizations, identity, "")
			if source.is_empty():
				var parents: Array = [fact.id]
				if row.rule == "listen" and not plan.target in parents: parents.append(plan.target)
				if row.rule == "evidence":
					parents.append_array(plan.basis.benefits)
					if not str(plan.basis.member).is_empty(): parents.append(plan.basis.member)
				var targets: Array = [plan.target]
				if not actor.is_empty() and not actor in targets: targets.append(actor)
				source = world.introduce_fact("power_qualification", fact.domain, actor, targets, parents, plan, [], [], owner)
				if source.is_empty(): return false
				Store.put(world.state.applied_authorizations, identity, source)
			proofs[identity] = source
		# No current candidate/person remains: cold proofs stay only in history.
		if not retained:
			var pending: bool = row.selector in ["propagation_permit", "propagation_evidence"] and not _invalid(world.state, fact.id)
			if row.selector == "propagation_permit": pending = pending and world.state.economy_qualifications.get("propagation|" + str(fact.changes.get("subject", ""))) == fact.id
			if row.selector == "joined_member":
				var person: Dictionary = Store.entry(world.state.npcs, str(fact.actor), {})
				pending = person.get("status") != "dead" and person.get("joined_source") == fact.id and person.get("cult_id") == fact.changes.get("cult") and person.get("bound_member", false)
			if not pending: ledger.origins.erase(key)
	ledger.proofs = proofs
	return true

func valid_proof(state: Dictionary, proof: Dictionary, reader: RefCounted = null, current: bool = true) -> bool:
	var data: Dictionary = proof.get("changes", {})
	if proof.get("kind") != "power_qualification" or data.get("issuer") != ID or data.get("version") != version or not rules.has(data.get("rule_id", "")): return false
	var origin: Dictionary = _fact(state, str(data.get("origin", "")), reader)
	if origin.is_empty() or not _matches(origin, rules[data.rule_id]) or not origin.id in proof.causal_parents or proof.domain != origin.domain or proof.actor != data.get("actor"): return false
	var targets: Array = [data.get("target", "")]
	if not str(data.get("actor", "")).is_empty() and not data.actor in targets: targets.append(data.actor)
	targets.sort()
	if proof.targets != targets: return false
	if data.rule == "tenure" and int(proof.turn) - int(origin.turn) < catalog.integer("sacrifice_min_tenure"): return false
	var expected: Dictionary = _plan(state, origin, rules[data.rule_id], str(data.get("actor", "")), reader, current)
	if not current and rules[data.rule_id].selector == "propagation_evidence":
		if not data.get("basis", {}).get("benefits") is Array or data.basis.get("source") != origin.id: return false
		for benefit: Variant in data.basis.benefits:
			if not benefit is String or not origin.id in _fact(state, benefit, reader).get("causal_parents", []) or benefit >= proof.id or not _propagation_benefit(_fact(state, benefit, reader)): return false
		var joined: Dictionary = _fact(state, str(data.basis.get("member", "")), reader)
		if joined.get("kind") != "cult_member_joined" or joined.actor != data.actor or joined.changes.get("cult") != data.target or not joined.id in proof.causal_parents: return false
		expected = {"issuer": ID, "version": version, "rule": rules[data.rule_id].rule, "actor": data.actor, "target": data.target, "institution": str(origin.changes.get("institution", "")), "basis": {"source": origin.id, "benefits": data.basis.benefits, "member": joined.id}, "origin": origin.id, "rule_id": data.rule_id}
	return expected == data

func available(turn: RefCounted) -> Array:
	if not error.is_empty() or turn._in_transaction or turn._in_participant or turn.world.state.get(ID, {}).get("version") != version: return []
	var result: Array = []
	for source: String in turn.world.state[ID].proofs.values():
		var fact: Dictionary = Store.entry(turn.world.state.facts, source)
		if valid_proof(turn.world.state, fact): result.append(fact.duplicate(true))
	return result

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not state.has(ID): return []
	var policy: RefCounted = load("res://src/game/player_sources.gd").new(content)
	var ledger: Variant = state[ID]
	if not policy.error.is_empty() or not ledger is Dictionary or ledger.size() != 5 or ledger.get("schema") != 1 or ledger.get("version") != policy.version or not ledger.get("origins") is Dictionary or not ledger.get("proofs") is Dictionary or not ledger.get("derivatives") is Dictionary: return ["Invalid player source capability"]
	for entry: Variant in ledger.origins.values():
		if not entry is Dictionary or not policy.rules.has(entry.get("rule", "")) or not Store.has(state.facts, entry.get("source", "")): return ["Invalid current player source origin"]
	for identity: String in ledger.proofs:
		var source: Variant = ledger.proofs[identity]
		if not source is String or not policy.valid_proof(state, Store.entry(state.facts, source, {}), null, state.get("ending_system", {}).get("terminal", "").is_empty()): return ["Invalid current player proof"]
		var plan: Dictionary = Store.entry(state.facts, source).changes
		if identity != "player-source/" + JSON.stringify(plan, "", true, true).sha256_text() or Store.entry(state.applied_authorizations, identity, "") != source: return ["Player proof lacks its unique production authorization"]
	var expected_derivatives: Dictionary = {}
	for origin: String in ledger.derivatives:
		if not Store.has(state.facts, origin) or not ledger.derivatives[origin] is Array: return ["Invalid propagation derivative index"]
		var seen: Dictionary = {}
		for child: Variant in ledger.derivatives[origin]:
			if not child is String or seen.has(child) or not origin in Store.entry(state.facts, child, {}).get("causal_parents", []) or not policy._propagation_benefit(Store.entry(state.facts, child)): return ["Propagation derivative has no direct production parent"]
			seen[child] = true
		expected_derivatives[origin] = []
	for source: String in (Store.keys(state.facts) if trusted.is_empty() else Store.changed(state.facts)):
		var fact: Dictionary = Store.entry(state.facts, source)
		if fact.kind == "power_qualification" and fact.changes.get("issuer") == ID and not policy.valid_proof(state, fact, null, false): return ["Forged player qualification history"]
		if trusted.is_empty() and policy._propagation_benefit(fact):
			for parent: String in fact.causal_parents:
				if expected_derivatives.has(parent): expected_derivatives[parent].append(fact.id)
	if trusted.is_empty():
		for origin: String in expected_derivatives:
			expected_derivatives[origin].sort()
			var actual: Array = ledger.derivatives[origin].duplicate(); actual.sort()
			if expected_derivatives[origin] != actual: return ["Propagation derivative index omitted a real child"]
	return []
