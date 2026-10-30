extends RefCounted
## The existing Turn payment/execution predicate, shared with read-only queries.
## Reservation, payment, marking actors and recording outcomes remain with Turn.
const Store = preload("res://src/simulation/archive_store.gd")

static func can_execute(state: Dictionary, actor: String, reader: RefCounted = null) -> bool:
	var person: Dictionary = Store.entry(state.get("npcs", {}), actor, {})
	if person.is_empty() and reader != null:
		var found: Dictionary = reader.entity("npcs", actor)
		if found.get("ok", false): person = found.item
	return state.get("phase") == "actions" and person.get("status") == "active" and int(person.get("acted_turn", -1)) != int(state.turn)

static func validate(state: Dictionary, cursor: Dictionary, meta: Variant, content: RefCounted, default_choice: bool = false, reader: RefCounted = null) -> Dictionary:
	if not meta is Dictionary: return _deny("Missing action metadata")
	for field: String in ["faith_cost", "whispers_cost", "min_awakening"]:
		if not meta.get(field) is int or int(meta[field]) < 0: return _deny("Invalid action cost or threshold")
	for field: String in ["responds", "used_power", "used_relic"]:
		if not meta.get(field) is bool: return _deny("Invalid action opportunity metadata")
	if not meta.get("actor") is String or not meta.get("source") is String or not meta.get("outcome") is String: return _deny("Action needs actor, source and explicit outcome")
	var sourced: bool = Store.has(state.get("facts", {}), meta.source)
	if not sourced and reader != null: sourced = reader.fact(meta.source).get("ok", false)
	if not sourced: return _deny("Action needs actor, source and explicit outcome")
	if default_choice and (meta.faith_cost != 0 or meta.whispers_cost != 0): return _deny("Mandatory default must cost zero resources")
	if int(state.awakening) < int(meta.min_awakening) or int(state.faith) < int(meta.faith_cost) or int(state.whispers) < int(meta.whispers_cost): return _deny("Action no longer eligible or affordable")
	if meta.responds and int(cursor.get("responses", 0)) >= content.integer("prayer_response_limit"): return _deny("Prayer response opportunity already spent")
	if not str(meta.actor).is_empty() and not can_execute(state, meta.actor, reader): return _deny("Person cannot execute another task")
	var domain: String = str(meta.get("target", meta.get("attention", {}).get("target", ""))) if state.has("cult_system") else ""
	if state.has("cult_system") and int(meta.faith_cost) > 0 and not state.domains.has(domain): return _deny("Paid action requires an explicit target domain")
	if meta.outcome == "transfer_material" and not meta.get("material") is Dictionary: return _deny("Material action needs its exact endpoint")
	return {"ok": true, "payment_domain": domain}

static func _deny(message: String) -> Dictionary:
	return {"ok": false, "error": message}
