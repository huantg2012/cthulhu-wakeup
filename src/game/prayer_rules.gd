extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## Shared read contract for sourced, finite prayer consequences. The Prayers
## adapter owns their creation, expiry and audit; consumers only ask eligibility.
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
