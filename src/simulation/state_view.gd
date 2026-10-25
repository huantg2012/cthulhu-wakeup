extends RefCounted
## Bounded, detached current projections and explicit ID reads. This adapter never
## returns the authoritative root or an enumerable archive to a rule participant.
const COLLECTIONS: Array[String] = ["domains", "institutions", "npcs", "evidence", "cults", "relics", "anchors"]
const SCOPES: Array[String] = ["current", "economy"]
const HISTORY_FIELDS: Array[String] = ["known_facts", "crisis_facts", "public_facts", "consumed_sources", "growth_sources", "sources", "confirmations"]
const PAGE_LIMIT: int = 64 # Technical current-entity response cap; not the later CSV history-page policy.
var _state: Dictionary
var _context: Dictionary
var version: int
var metrics: Dictionary = {"objects": 0, "pages": 0, "facts": 0}

func _init(state: Dictionary, turn_context: Dictionary = {}, source_version: int = 0) -> void:
	_state = state
	_context = turn_context
	version = source_version

func _project(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for field: String in value:
		if field not in HISTORY_FIELDS:
			var item: Variant = value[field]
			output[field] = item.duplicate(true) if item is Dictionary or item is Array else item
	return output

func entity(collection: String, id: String) -> Dictionary:
	if collection not in COLLECTIONS or not _state.get(collection, {}).has(id):
		return {"ok": false, "error": "Unknown entity scope or identity", "version": version}
	metrics.objects += 1
	return {"ok": true, "item": _project(_state[collection][id]), "version": version}

func fact(id: String) -> Dictionary:
	if not _state.facts.has(id):
		return {"ok": false, "error": "Unknown fact identity", "version": version}
	metrics.facts += 1
	return {"ok": true, "item": _state.facts[id].duplicate(true), "version": version}

func query(collection: String, ids: Array = [], limit: int = 1, cursor: int = 0) -> Dictionary:
	if collection not in COLLECTIONS or limit < 1 or limit > PAGE_LIMIT or cursor < 0:
		return {"ok": false, "error": "Unknown query scope or invalid page", "version": version}
	var keys: Array = _state.get(collection, {}).keys() if ids.is_empty() else ids.duplicate()
	for key: Variant in keys:
		if not key is String:
			return {"ok": false, "error": "Invalid identity", "version": version}
	keys.sort()
	if cursor > keys.size():
		return {"ok": false, "error": "Invalid query cursor", "version": version}
	var items: Array = []
	var next: int = mini(keys.size(), cursor + limit)
	for index: int in range(cursor, next):
		if not keys[index] is String:
			return {"ok": false, "error": "Invalid identity", "version": version}
		var result: Dictionary = entity(collection, keys[index])
		if not result.ok:
			return result
		items.append(result.item)
	metrics.pages += 1
	return {"ok": true, "items": items, "cursor": next, "complete": next == keys.size(), "version": version}

func participant(id: String, slot: String, scopes: Array = ["current", "economy"]) -> Dictionary:
	for scope: Variant in scopes:
		if not scope is String or scope not in SCOPES:
			return {"ok": false, "error": "Unknown participant read scope"}
	var projected: Dictionary = {}
	for field: String in _state:
		if not _state[field] is Dictionary and not _state[field] is Array:
			projected[field] = _state[field]
	if "current" in scopes:
		for collection: String in COLLECTIONS:
			projected[collection] = {}
			for key: String in _state.get(collection, {}):
				projected[collection][key] = entity(collection, key).item
	projected["facts"] = {}
	if "economy" in scopes and _state.has("economy"):
		projected["economy"] = _state.economy.duplicate(true)
		projected["economy_qualifications"] = _state.economy_qualifications.duplicate(true)
		for source: String in _state.economy_qualifications.values():
			if _state.facts.has(source):
				projected.facts[source] = fact(source).item
	var turn: Dictionary = {}
	for field: String in _context:
		if field not in ["receipts", "completed_jobs", "journal"]:
			var value: Variant = _context[field]
			turn[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"ok": true, "version": version, "slot": slot, "world": projected, "turn": turn, "participant_state": _context.get("participant_state", {}).get(id, {}).duplicate(true)}
