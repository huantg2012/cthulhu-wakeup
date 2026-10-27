extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## Shared read contract for sourced, finite prayer consequences. The Prayers
## adapter owns their creation, expiry and audit; consumers only ask eligibility.
static func ritual_keeper(state: Dictionary, person: Dictionary) -> bool:
	var institution: Dictionary = state.institutions.get(str(person.get("institution", "")), {})
	return not person.is_empty() and person.get("status") == "active" and "ritual_keeper" in person.get("role_tags", []) and institution.get("active", false) and institution.get("domain") == person.get("domain") and institution.get("role") in ["interpretation", "propagation"]

static func blocked(state: Dictionary, npc: String, kind: String) -> bool:
	var entry: Variant = state.get("prayer_system", {}).get("restrictions", {}).get(npc, {}).get(kind)
	return entry is Dictionary and entry.get("until") is int and int(state.turn) <= int(entry.until)

static func prayer_action(action: String) -> Dictionary:
	var parts: PackedStringArray = action.split("/")
	if parts.size() != 3 or parts[0] != "PRAYER" or not parts[2] in ["shallow", "deep"] or not parts[1].begins_with("BACKGROUND-"): return {"ok": false}
	var number: String = parts[1].trim_prefix("BACKGROUND-")
	if not number.is_valid_int() or int(number) < 1 or parts[1] != "BACKGROUND-%08d" % int(number): return {"ok": false}
	return {"ok": true, "request": parts[1], "variant": parts[2]}

static func prayer_target(state: Dictionary, action: String, actor: String) -> bool:
	var parsed: Dictionary = prayer_action(action)
	if not parsed.ok: return false
	var request: Dictionary = state.get("prayer_system", {}).get("requests", {}).get(parsed.request, {})
	if request.is_empty() or request.get("status") != "open": return false
	var card: Dictionary = request.get("card", {})
	return card.get("visible_turn", 2147483647) <= state.turn and card.get("due_turn", -1) >= state.turn and request.get("descriptor", {}).get("subjects", {}).get("petitioner") == actor

static func occurrence_key(descriptor: Dictionary) -> String:
	var actors: Array = descriptor.get("actors", []).duplicate(); actors.sort()
	var crisis: Dictionary = descriptor.get("crisis", {})
	var root: Dictionary = {} if crisis.is_empty() else {"source": crisis.get("source", ""), "due": crisis.get("due", -1)}
	var identity: Dictionary = {"content_id": descriptor.get("content_id", ""), "domain": descriptor.get("domain", ""), "institution": descriptor.get("institution", ""), "actors": actors, "subjects": descriptor.get("subjects", {}), "facts": descriptor.get("facts", {}), "crisis": root}
	return "prayer/occurrence/" + JSON.stringify(identity, "", true, true).sha256_text()

static func concealed(state: Dictionary, npc: String) -> bool:
	var entry: Variant = state.get("prayer_system", {}).get("hidden", {}).get(npc)
	return entry is Dictionary and entry.get("until") is int and int(state.turn) <= int(entry.until) and Store.has(state.npcs, npc) and Store.entry(state.npcs, npc).status == "active" and not Store.has(state.get("invalid_records", {}), str(entry.get("source", "")))

## Exact EVENT_12B authority, shared by fixation and restore audits. A caller
## cannot turn an ordinary reopening into a current-turn exception with a flag.
static func event_reopen_result(state: Dictionary, authorization: Dictionary, reader: RefCounted = null) -> Dictionary:
	if not state.has("event_system") or authorization.get("kind") != "prayer_reopen_authorized": return {}
	if authorization.get("changes", {}).get("issuer") != "events" or authorization.changes.get("version") != state.event_system.get("version"): return {}
	for id: String in authorization.get("causal_parents", []):
		var result: Dictionary = _source(state, id, reader)
		if result.get("kind") != "event_result" or result.changes.get("content_id") != "EVENT_12" or result.changes.get("option") != "B": continue
		var key: String = "event/resolved/" + str(result.changes.get("event", ""))
		if _used(state, key, reader) != id: continue
		var descriptor: Dictionary = result.changes.get("descriptor", {})
		var window: Dictionary = _source(state, str(descriptor.get("source", "")), reader)
		var registered: Dictionary = _source(state, str(descriptor.get("facts", {}).get("registration", "")), reader)
		if window.get("kind") != "prayer_window_due" or window.changes.get("answered", true) or registered.get("kind") != "prayer_registered": continue
		if window.changes.get("registration") != registered.id or window.changes.get("request") != registered.changes.get("request") or window.changes.get("descriptor") != registered.changes.get("descriptor"): continue
		if _used(state, "prayer/window/" + str(registered.changes.request), reader) != window.id or not window.id in authorization.causal_parents or authorization.changes.get("parent") != registered.changes.get("source"): continue
		return {"result": result, "window": window, "registration": registered}
	return {}

static func event_reopen_card(state: Dictionary, card: Dictionary) -> bool:
	if card.get("origin") != "prayer_situation": return false
	var source: Dictionary = _source(state, str(card.get("source", "")))
	var authorization: Dictionary = _source(state, str(source.get("changes", {}).get("reopen", "")))
	var actual: Dictionary = event_reopen_result(state, authorization)
	return not actual.is_empty() and actual.result.turn == card.get("created_turn") and source.get("turn") == card.get("created_turn") and _used(state, "prayer/reopen/" + str(authorization.id)) == card.get("fact")

static func _source(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if reader != null and reader.has_method("fact"):
		var found: Dictionary = reader.fact(id)
		return found.item if found.get("ok", false) else {}
	return Store.entry(state.get("facts", {}), id, {})

static func _used(state: Dictionary, key: String, reader: RefCounted = null) -> String:
	if reader != null and reader.has_method("authorization"):
		var found: Dictionary = reader.authorization(key)
		return str(found.source) if found.get("ok", false) and found.get("used", false) else ""
	return str(Store.entry(state.get("applied_authorizations", {}), key, ""))
