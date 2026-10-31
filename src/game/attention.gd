extends RefCounted
## One admission predicate; all mutations below belong to the owner's transaction.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
var parameters: Dictionary
var policies: Dictionary = {}
var version: String = ""
var errors: Array[String] = []
var catalog: RefCounted

func _init(content: RefCounted, background: RefCounted) -> void:
	catalog = content; parameters = background.parameters
	if background.version.is_empty(): errors.append("Background policy unavailable"); return
	var file: FileAccess = FileAccess.open("res://data/intervention_policies.csv", FileAccess.READ)
	if file == null: errors.append("Missing admission policies"); return
	var raw: String = file.get_as_text(); file.seek(0)
	var header: Array = ["id", "family", "content_id", "variant", "focus_scope", "person_scope", "member_scope", "rationale"]
	if Array(file.get_csv_line()) != header: errors.append("Admission header mismatch"); return
	var ids: Dictionary = {}
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != header.size(): errors.append("Invalid admission row"); continue
		var row: Dictionary = {}
		for i: int in header.size(): row[header[i]] = cells[i]
		var key: String = row.family + "/" + row.content_id + "/" + row.variant
		if ids.has(row.id) or policies.has(key) or str(row.id).is_empty() or not row.family in ["power", "prayer", "event", "strategy", "system"] or not row.focus_scope in ["none", "target", "source_and_target", "ritual_domains"] or not row.person_scope in ["none", "participants", "fixed"] or not row.member_scope in ["none", "nominees"]: errors.append("Invalid/duplicate admission policy"); continue
		ids[row.id] = true; policies[key] = row
	var expected: Dictionary = {}
	for family: String in ["power", "prayer", "event"]:
		var name: String = {"power": "powers", "prayer": "prayers", "event": "events"}[family]
		var content_file: FileAccess = FileAccess.open("res://data/" + name + ".csv", FileAccess.READ)
		if content_file == null: errors.append("Missing intervention content registry"); continue
		var fields: PackedStringArray = content_file.get_csv_line()
		if fields.is_empty() or fields[0] != "id": errors.append("Invalid content identity registry"); continue
		var seen: Dictionary = {}
		while not content_file.eof_reached():
			var cells: PackedStringArray = content_file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty(): continue
			if cells.size() != fields.size() or seen.has(cells[0]): errors.append("Invalid content registry row"); continue
			seen[cells[0]] = true
			var variants: Array = {"power": ["use"], "prayer": ["shallow", "deep"], "event": ["A", "B"]}[family]
			for variant: String in variants: expected[family + "/" + cells[0] + "/" + variant] = true
	for content_id: String in ["CULT_TRANSFER_MATERIAL", "CULT_FORM", "CULT_SUCCESSION", "MEMBER_ENROLL", "MEMBER_LEAVE", "RELIC_EQUIP", "RELIC_UNBIND", "RELIC_FAITH", "RELIC_INSIGHT", "RELIC_FOLLOWERS", "RELIC_WHISPERS", "RELIC_RECOVER", "RELIC_PUBLIC", "MANIFEST_CONTINUE", "REST"]: expected["system/" + content_id + "/use"] = true
	for content_id: String in content.tables.get("progression_route_operations", {}):
		if content.tables.progression_route_operations[content_id].mode != "guided_dream": expected["system/" + content_id + "/use"] = true
	for content_id: String in ["proselytize", "maintain", "conceal"]: expected["strategy/" + content_id + "/plan"] = true
	if expected.size() != policies.size(): errors.append("Incomplete or unknown intervention classification")
	for key: String in expected:
		if not policies.has(key): errors.append("Required admission policy missing: " + key)
	if int(parameters.local_actor_limit) < catalog.integer("institutions_per_domain") or int(parameters.initial_focused_domains) > int(parameters.focused_domain_limit): errors.append("Incompatible initial focus/local budget")
	if not errors.is_empty(): return
	version = ("attention-v1/" + background.version + "/" + raw).sha256_text()
	History._seal(policies)

static func enabled(state: Dictionary) -> bool:
	return state.has("attention") and state.has("simulation") and state.simulation.get("mode") == "hybrid"

func initialize() -> Dictionary:
	return {"schema": 1, "policy": version, "used_n": {}, "used_p": {}, "members": {}, "living_count": 0, "retired": {}, "release": {}, "reservations": {}, "local": {}, "next_reservation": 1}

func _error(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _add(target: Array, values: Array) -> void:
	for value: Variant in values:
		if not value in target: target.append(value)

func _effect_people(state: Dictionary, effects: Array, people: Array, nominees: Array, identities: Array) -> void:
	for effect: Dictionary in effects:
		if effect.get("type") == "schedule": _payload_people(state, effect.get("job", {}).get("payload", {}), people)
		if effect.get("type") == "check":
			_add(people, [effect.get("npc", "")])
			for branch: Array in effect.branches.values(): _effect_people(state, branch, people, nominees, identities)
		if effect.get("type") == "membership":
			_add(people, [effect.get("npc", "")])
			if effect.get("operation") == "enroll": _add(nominees, [effect.get("npc", "")])
		if effect.get("type") == "world_command":
			var command: Dictionary = effect.command
			if command.has("npc"): _add(people, [command.npc])
			if command.get("kind") == "nominate":
				_add(identities, [command.get("identity_key", "")]); _add(people, [command.get("identity_key", "")])
		for id: Variant in effect.get("targets", []) + effect.get("observers", []):
			if Store.has(state.npcs, id): _add(people, [id])

## A fixed prayer may nominate its original actors under either response branch.
func prayer_members(content: String, actors: Array) -> Array:
	for variant: String in ["shallow", "deep"]:
		if policies.get("prayer/" + content + "/" + variant, {}).get("member_scope") == "nominees": return actors.duplicate()
	return []

func preview_needs(state: Dictionary, request: Dictionary, effects: Array = [], actor: String = "", depth: int = 0) -> Dictionary:
	if version.is_empty() or not enabled(state) or depth > 8: return _error("Attention unavailable or cyclic effect description")
	var key: String = str(request.get("family", "")) + "/" + str(request.get("content_id", "")) + "/" + str(request.get("variant", ""))
	if not policies.has(key): return _error("Unregistered intervention")
	var rule: Dictionary = policies[key]
	var needs: Dictionary = {"ok": true, "focus": [], "people": [], "members": [], "identities": [], "source": request.get("source", "")}
	for field: String in ["participants", "nominees", "new_people", "fixed", "ritual_domains", "calls"]:
		if request.has(field) and not request[field] is Array: return _error("Invalid intervention dependency graph")
	var nested_needs: Dictionary = {"focus": [], "people": [], "members": [], "identities": []}
	for call: Variant in request.get("calls", []):
		if not call is Dictionary: return _error("Invalid invoked intervention")
		var nested: Dictionary = preview_needs(state, call, [], "", depth + 1)
		if not nested.ok: return nested
		for field: String in nested_needs: _add(nested_needs[field], nested[field])
	var actual_people: Array = [] if actor.is_empty() else [actor]
	var actual_members: Array = []; var new_people: Array = []
	_effect_people(state, effects, actual_people, actual_members, new_people)
	_add(actual_people, request.get("participants", [])); _add(actual_members, request.get("nominees", []))
	_add(new_people, request.get("new_people", [])); _add(actual_people, actual_members); _add(actual_people, new_people)
	if "" in actual_people or "" in new_people: return _error("Identity-producing branches need stable reservation keys")
	if rule.person_scope == "none" and (not actual_people.filter(func(id: String) -> bool: return not id in nested_needs.people).is_empty() or not new_people.filter(func(id: String) -> bool: return not id in nested_needs.identities).is_empty()): return _error("Policy forbids additional actors")
	if rule.member_scope == "none" and not actual_members.filter(func(id: String) -> bool: return not id in nested_needs.members).is_empty(): return _error("Policy forbids membership grants")
	if rule.person_scope == "fixed":
		if not new_people.filter(func(id: String) -> bool: return not id in nested_needs.identities).is_empty(): return _error("Fixed branch cannot nominate new actors")
		var fixed: Array = request.get("fixed", [])
		# A fixed list is a reference to an already committed candidate, never a
		# caller-supplied substitute for one.
		var candidate: Variant = state.simulation.candidates.get(str(request.get("candidate", "")))
		if not candidate is Dictionary or candidate.actors != fixed: return _error("Branch needs original fixed actors")
		for id: String in actual_people:
			if not id in fixed and not id in nested_needs.people: return _error("Branch exceeds fixed actor dependencies")
		_add(actual_people, fixed)
	for id: Variant in new_people:
		if not id is String or not str(id).begins_with("new:") or Store.has(state.npcs, id): return _error("Invalid new identity key")
	for id: Variant in actual_people + actual_members:
		if not id is String or (not id in new_people and (not Store.has(state.npcs, id) or Store.entry(state.npcs, id).status == "dead")): return _error("Unknown or dead intervention actor")
	match str(rule.focus_scope):
		"target": needs.focus = [request.get("target", "")]
		"source_and_target": needs.focus = [request.get("source_domain", ""), request.get("target", "")]
		"ritual_domains": needs.focus = request.get("ritual_domains", []).duplicate()
	if rule.focus_scope != "none" and needs.focus.is_empty(): return _error("Missing affected domains")
	for domain: Variant in needs.focus:
		if not domain is String or not state.domains.has(domain): return _error("Unknown affected domain")
	needs.people = actual_people; needs.members = actual_members; needs.identities = new_people
	for field: String in nested_needs: _add(needs[field], nested_needs[field])
	needs["persistent"] = request.get("persistent", false)
	var candidate: String = str(request.get("candidate", ""))
	if not candidate.is_empty() and not state.simulation.candidates.has(candidate): return _error("Unknown fixed interaction")
	needs["claim_key"] = _claim_key(needs, key)
	return preview(state, needs, str(request.get("_reservation", "")))

func occupied(state: Dictionary, budget: String, ignore_token: String = "") -> Array:
	var result: Array = []
	var att: Dictionary = state.attention
	if budget == "focus": _add(result, state.simulation.focused)
	if budget == "members": _add(result, att.members.keys() + att.retired.keys() + att.used_n.keys())
	if budget == "people": _add(result, state.simulation.temporary + state.simulation.holds.keys() + att.used_p.keys())
	for token: String in att.reservations:
		if token != ignore_token: _add(result, att.reservations[token][budget])
	if budget == "people": result = result.filter(func(id: String) -> bool: return not id in att.members and not id in att.retired and not id in att.used_n)
	return result

func preview(state: Dictionary, needs: Dictionary, ignore_token: String = "") -> Dictionary:
	for field: String in ["focus", "members", "people", "identities"]:
		if not needs.get(field) is Array: return _error("Invalid reservation needs")
	if needs.get("persistent", false):
		for token: String in state.attention.reservations:
			if token != ignore_token and state.attention.reservations[token].persistent and state.attention.reservations[token].claim_key == needs.get("claim_key", ""): return _error("Unfinished project already owns this duty/object")
	var limits: Dictionary = {"focus": parameters.focused_domain_limit, "members": parameters.bound_member_limit, "people": parameters.temporary_actor_limit}
	var budgets: Dictionary = {}
	for field: String in limits:
		var reserved_ids: Array = []
		for claim: Dictionary in state.attention.reservations.values(): _add(reserved_ids, claim[field])
		var pending: Array = state.attention.release.keys()
		if field == "members": pending = state.attention.used_n.keys().filter(func(id: String) -> bool: return not state.attention.members.has(id) and not state.attention.retired.has(id))
		if field == "people":
			reserved_ids = reserved_ids.filter(func(id: String) -> bool: return not state.attention.members.has(id) and not state.attention.retired.has(id) and not state.attention.used_n.has(id))
			pending = state.attention.used_p.keys().filter(func(id: String) -> bool: return id in occupied(state, "people") and not state.simulation.holds.has(id) and not id in state.simulation.temporary)
		budgets[field] = {"occupied": occupied(state, field).size(), "reserved": reserved_ids.size(), "limit": limits[field], "pending_release": pending}
	for field: String in limits:
		var ids: Array = occupied(state, field)
		_add(ids, needs[field])
		if field == "people": ids = ids.filter(func(id: String) -> bool: return not id in state.attention.members and not id in state.attention.retired and not id in state.attention.used_n)
		if ids.size() > int(limits[field]): return _error("Insufficient " + field + " capacity").merged({"budgets": budgets})
	var identities: Array = []
	for token: String in state.attention.reservations:
		if token != ignore_token: _add(identities, state.attention.reservations[token].identities)
	for key: String in needs.identities:
		if key in identities or Store.has(state.applied_authorizations, "identity/" + key): return _error("Identity reservation key was already used")
	_add(identities, needs.identities)
	var living: int = int(state.attention.living_count)
	if living + identities.size() > catalog.integer("living_named_global_limit"): return _error("Insufficient live identity capacity")
	return needs.duplicate(true).merged({"ok": true, "budgets": budgets}, true)

func reserve(world: RefCounted, needs: Dictionary, persistent: bool = false, caller: Dictionary = {}) -> Dictionary:
	needs = needs.duplicate(true)
	needs["persistent"] = persistent
	if not needs.has("claim_key"): needs["claim_key"] = _claim_key(needs, "internal")
	var check: Dictionary = preview(world.state, needs)
	if not check.ok: return check
	if not Store.has(world.state.facts, str(needs.get("source", ""))): return _error("Reservation needs a real source")
	world.stage_collections(["attention", "simulation"])
	var att: Dictionary = world.state.attention
	var token: String = "RESERVE-%08d" % int(att.next_reservation)
	att.next_reservation += 1
	var entry: Dictionary = check.duplicate(true); entry.erase("ok"); entry.erase("budgets"); entry["persistent"] = persistent
	att.reservations[token] = entry
	var admission: String = ""
	if not needs.focus.filter(func(domain: String) -> bool: return not domain in world.state.simulation.focused).is_empty():
		# This is the actual successful reservation, before its expansions. It is
		# not an independently consumable permit or a replacement for payment.
		admission = world._record("attention_admitted", "", "", needs.focus, [needs.source], {"schema": 1, "position": world._birth_position(), "source": needs.source, "focus": world._unique_sorted(needs.focus), "caller": caller.duplicate(true)})
	for domain: String in needs.focus:
		if not domain in world.state.simulation.focused:
			world.state.simulation.focused.append(domain)
			if not world.expand_admitted_domain(domain, admission):
				var message: String = "Focused domain social initialization failed: " + world.last_error
				# Unlike a preflight capacity refusal this failure follows writes.
				# Latch the outer transaction even when an internal caller tries hold.
				if world.transaction != null: world.transaction.error = message
				return {"ok": false, "error": message, "hard_failure": true}
	sync(world)
	return {"ok": true, "token": token, "admission": admission}

func claim_identity(world: RefCounted, token: String, key: String, id: String) -> bool:
	world.stage_collections(["attention", "simulation"])
	if not world.state.attention.reservations.has(token): return false
	var entry: Dictionary = world.state.attention.reservations[token]
	if not key in entry.identities: return false
	entry.identities.erase(key)
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, "identity/" + key, id)
	for field: String in ["people", "members"]:
		var at: int = entry[field].find(key)
		if at >= 0: entry[field][at] = id
	return true

func finish(world: RefCounted, token: String) -> void:
	world.stage_collections(["attention", "simulation"])
	if not world.state.attention.reservations.has(token): return
	var entry: Dictionary = world.state.attention.reservations[token]
	if entry.persistent: return
	for id: String in entry.people:
		if Store.has(world.state.npcs, id) and not id in world.state.simulation.persistent: world.state.attention.used_p[id] = world.state.turn
	world.state.attention.reservations.erase(token)
	sync(world)

func enroll(world: RefCounted, id: String, source: String, token: String, cult: String = "") -> bool:
	world.stage_current()
	if not Store.has(world.state.npcs, id) or not Store.has(world.state.facts, source): return false
	var person: Dictionary = Store.entry(world.state.npcs, id)
	if person.status == "dead" or person.loyalty < catalog.integer("loyalty_follower_threshold"): return false
	if person.get("bound_member", false): return true
	if not world.state.attention.reservations.has(token) or not id in world.state.attention.reservations[token].members: return false
	person = world.mutable_npc(id)
	person.bound_member = true; person.cult_id = cult
	var result: String = world._record("member_enrolled", person.domain, id, [id], [source], {"cult": cult})
	person["binding_source"] = result
	world.state.attention.retired.erase(id); world.state.attention.used_n[id] = world.state.turn; world.state.attention.members[id] = result
	world.state.attention.used_p.erase(id)
	sync(world)
	return true

func leave(world: RefCounted, id: String, source: String) -> bool:
	world.stage_current()
	if not Store.has(world.state.npcs, id) or not Store.has(world.state.facts, source): return false
	var person: Dictionary = world.mutable_npc(id)
	if not person.get("bound_member", false): return true
	person.bound_member = false; person.cult_id = ""
	var result: String = world._record("member_left", person.domain, id, [id], [source])
	person.binding_source = result
	world.state.attention.members.erase(id)
	world._detach_roles(person, result)
	world.state.attention.used_n[id] = world.state.turn
	if person.status != "dead" and referenced(world.state, id): world.state.attention.retired[id] = result
	sync(world)
	return true

func referenced(state: Dictionary, id: String) -> bool:
	if state.simulation.holds.has(id): return true
	for entry: Dictionary in state.attention.reservations.values():
		if id in entry.people or id in entry.members: return true
	return false

func sync(world: RefCounted) -> void:
	world.stage_collections(["attention", "simulation"])
	sync_state(world.state, world.history)

func sync_state(state: Dictionary, history: RefCounted) -> void:
	for id: String in state.attention.used_n:
		if Store.has(state.npcs, id) and Store.entry(state.npcs, id).status != "dead" and not Store.entry(state.npcs, id).bound_member and referenced(state, id): state.attention.retired[id] = Store.entry(state.npcs, id).binding_source
	var members: Array = state.attention.members.keys()
	_add(members, state.attention.retired.keys()); members.sort()
	state.simulation.persistent = members
	var people: Array = []
	for entry: Dictionary in state.attention.reservations.values(): _add(people, entry.people)
	state.simulation.temporary = people.filter(func(id: String) -> bool: return Store.has(state.npcs, id) and not id in members)
	var local: Dictionary = {}
	for domain: String in state.simulation.focused:
		var chosen: Array = []
		for institution: String in state.domains[domain].institutions:
			var id: String = state.institutions[institution].representative
			if Store.has(state.npcs, id) and Store.entry(state.npcs, id).status != "dead" and not id in members and not id in occupied(state, "people"): _add(chosen, [id])
		for id: String in history.ids("active/" + domain):
			if not id in members and not id in occupied(state, "people"): _add(chosen, [id])
		local[domain] = chosen.slice(0, int(parameters.local_actor_limit))
	state.attention.local = local

func detailed_ids(state: Dictionary) -> Array:
	var ids: Array = occupied(state, "members")
	_add(ids, occupied(state, "people"))
	for rows: Array in state.attention.local.values(): _add(ids, rows)
	ids = ids.filter(func(id: String) -> bool: return Store.has(state.npcs, id) and Store.entry(state.npcs, id).status != "dead")
	ids.sort(); return ids

func round_start(world: RefCounted) -> void:
	world.stage_collections(["attention", "simulation"])
	round_start_state(world.state, world.history)

## Shared deterministic reset for the live transaction and detached forecasts.
func round_start_state(state: Dictionary, history: RefCounted) -> void:
	var att: Dictionary = state.attention
	for field: String in ["used_n", "used_p"]:
		for id: String in att[field].keys():
			if int(att[field][id]) < int(state.turn): att[field].erase(id)
	for id: String in att.retired.keys():
		if not Store.has(state.npcs, id) or Store.entry(state.npcs, id).status == "dead" or not referenced(state, id): att.retired.erase(id); continue
		var people: Array = occupied(state, "people"); _add(people, [id])
		if people.size() <= int(parameters.temporary_actor_limit): att.retired.erase(id)
	for domain: String in att.release.keys():
		var held: bool = false
		for entry: Dictionary in att.reservations.values(): held = held or domain in entry.focus
		if int(att.release[domain]) < int(state.turn) and not held:
			state.simulation.focused.erase(domain); att.release.erase(domain)
	sync_state(state, history)

func validate(state: Dictionary, trusted: Dictionary = {}) -> Array[String]:
	if not state.has("attention"):
		var missing: Array[String] = []
		if state.has("simulation") and state.simulation.get("mode") == "hybrid": missing.append("Hybrid world needs attention state")
		return missing
	var att: Variant = state.attention
	if not enabled(state) or not att is Dictionary or att.get("schema") != 1 or version.is_empty() or att.get("policy") != version: return ["Incompatible attention policy/schema"]
	for field: String in ["used_n", "used_p", "members", "retired", "release", "reservations", "local"]:
		if not att.get(field) is Dictionary: return ["Invalid attention collection"]
	if not att.get("next_reservation") is int or att.next_reservation < 1: return ["Invalid reservation sequence"]
	var issues: Array[String] = []
	var identity_claims: Dictionary = {}
	var project_claims: Dictionary = {}
	for field: String in ["used_n", "used_p"]:
		for id: String in att[field]:
			if not Store.has(state.npcs, id) or not att[field][id] is int or att[field][id] < 0 or att[field][id] > state.turn: return ["Invalid activity usage mark"]
	for token: String in att.reservations:
		var entry: Variant = att.reservations[token]
		if not entry is Dictionary or not entry.get("persistent") is bool or not entry.get("claim_key") is String or str(entry.claim_key).is_empty() or token != "RESERVE-%08d" % int(token.get_slice("-", 1)) or int(token.get_slice("-", 1)) < 1 or int(token.get_slice("-", 1)) >= att.next_reservation or not entry.get("source") is String or not Store.has(state.facts, entry.source): return ["Invalid reservation"]
		if entry.persistent:
			if project_claims.has(entry.claim_key): return ["Duplicate duty/object project"]
			project_claims[entry.claim_key] = true
		for field: String in ["focus", "people", "members", "identities"]:
			if not entry.get(field) is Array: return ["Invalid reservation dependencies"]
			var unique: Dictionary = {}
			for value: Variant in entry[field]:
				if not value is String or unique.has(value): return ["Invalid or duplicate reservation identity"]
				unique[value] = true
		for key: String in entry.identities:
			if identity_claims.has(key): return ["Identity key reserved by multiple owners"]
			identity_claims[key] = token
			if not key.begins_with("new:") or Store.has(state.applied_authorizations, "identity/" + key) or (not key in entry.people and not key in entry.members): return ["Invalid unclaimed identity"]
		for id: Variant in entry.focus:
			if not id is String or not id in state.simulation.focused: return ["Unknown reserved domain"]
		for id: Variant in entry.people + entry.members:
			if not id is String or (not id in entry.identities and not Store.has(state.npcs, id)): return ["Unknown reserved actor"]
	for domain: Variant in att.release:
		if not domain is String or not domain in state.simulation.focused or not att.release[domain] is int or att.release[domain] > state.turn: issues.append("Invalid pending focus release")
	for domain: String in att.local:
		if not domain in state.simulation.focused or not att.local[domain] is Array or att.local[domain].size() > int(parameters.local_actor_limit): return ["Invalid local activation"]
		for id: Variant in att.local[domain]:
			if not id is String or not Store.has(state.npcs, id) or Store.entry(state.npcs, id).domain != domain: return ["Unknown local actor"]
	if not att.get("living_count") is int or att.living_count < 0: return ["Invalid live identity projection"]
	var expected: Array = att.members.keys()
	var inspected: Array = Store.keys(state.npcs) if trusted.is_empty() else Store.changed(state.npcs)
	_add(inspected, att.members.keys() + att.retired.keys())
	var living: int = 0 if trusted.is_empty() else int(trusted.attention.living_count)
	for id: String in inspected:
		var person: Dictionary = Store.entry(state.npcs, id)
		if not person.get("bound_member") is bool or not person.get("cult_id") is String or not person.get("binding_source") is String or not Store.has(state.facts, person.binding_source): return ["Invalid membership state"]
		if trusted.is_empty(): living += 0 if person.status == "dead" else 1
		elif id in Store.changed(state.npcs):
			var old: Dictionary = Store.entry(trusted.npcs, id, {})
			living += (0 if person.status == "dead" else 1) - (0 if old.is_empty() or old.status == "dead" else 1)
		if not person.get("dedication_source") is String or (not person.dedication_source.is_empty() and (not Store.has(state.facts, person.dedication_source) or Store.entry(state.facts, person.dedication_source).kind != "member_dedication" or not id in Store.entry(state.facts, person.dedication_source).targets)): return ["Invalid current dedication projection"]
		if not person.cult_id.is_empty() and (not person.bound_member or not state.cults.has(person.cult_id)): issues.append("Unknown membership cult")
		if person.bound_member != att.members.has(id) or (person.bound_member and att.members[id] != person.binding_source): issues.append("Membership index disagrees")
		if person.bound_member:
			if person.status == "dead" or att.retired.has(id): issues.append("Dead/retired member retains permissions")
	if living != att.living_count: issues.append("Live identity projection disagrees")
	_add(expected, att.retired.keys()); expected.sort()
	if expected != state.simulation.persistent: issues.append("Member activation disagrees")
	for id: String in att.retired:
		if not Store.has(state.npcs, id) or Store.entry(state.npcs, id).get("bound_member", false) or not att.retired[id] is String or not Store.has(state.facts, att.retired[id]): issues.append("Invalid retired identity")
	var empty: Dictionary = {"focus": [], "people": [], "members": [], "identities": []}
	var capacity: Dictionary = preview(state, empty)
	if not capacity.ok: issues.append(capacity.error)
	if detailed_ids(state).size() > int(parameters.bound_member_limit) + int(parameters.temporary_actor_limit) + int(parameters.focused_domain_limit) * int(parameters.local_actor_limit): issues.append("Detailed activation upper bound exceeded")
	return issues

func release_reservation(world: RefCounted, token: String) -> bool:
	world.stage_collections(["attention", "simulation"])
	if not world.state.attention.reservations.has(token): return false
	world.state.attention.reservations[token].persistent = false
	finish(world, token)
	return true

func preview_reserved(state: Dictionary, token: String, needs: Dictionary, owner: String) -> Dictionary:
	if not state.attention.reservations.has(token): return _error("Missing promised reservation")
	var entry: Dictionary = state.attention.reservations[token]
	if not entry.persistent or entry.get("owner", "") != owner: return _error("Reservation is not owned by this participant")
	for field: String in ["focus", "members", "people", "identities"]:
		for id: String in needs[field]:
			if not id in entry[field] and not (field == "people" and id in entry.members): return _error("Due effect exceeds its promised capacity")
	return {"ok": true, "token": token}

func _payload_people(state: Dictionary, value: Variant, people: Array) -> void:
	if value is String and (Store.has(state.npcs, value) or value.begins_with("new:")): _add(people, [value])
	elif value is Dictionary:
		for key: Variant in value:
			_payload_people(state, key, people); _payload_people(state, value[key], people)
	elif value is Array:
		for item: Variant in value: _payload_people(state, item, people)

func _claim_key(needs: Dictionary, purpose: String) -> String:
	var primary: Array = []
	if not needs.focus.is_empty(): primary = needs.focus.duplicate(); primary.sort()
	elif not needs.members.is_empty(): primary = [needs.members[0]]
	elif not needs.people.is_empty(): primary = [needs.people[0]]
	return (purpose + "/" + JSON.stringify(primary)).sha256_text()
