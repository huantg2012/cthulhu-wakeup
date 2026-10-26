extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## Bounded, detached current projections and explicit ID reads. This adapter never
## returns the authoritative root or an enumerable archive to a rule participant.
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const COLLECTIONS: Array[String] = ["domains", "institutions", "npcs", "evidence", "cults", "relics", "anchors"]
const SCOPES: Array[String] = ["current", "economy"]
const HISTORY_FIELDS: Array[String] = ["known_facts", "crisis_facts", "public_facts", "consumed_sources", "growth_sources", "sources", "confirmations", "relations", "contributions", "public_anomalies"]

var _state: Dictionary
var _context: Dictionary
var _open: bool = true
var _index_version: int = 0
var _index: RefCounted
var version: int
var metrics: Dictionary = {"objects": 0, "pages": 0, "facts": 0}

func _init(state: Dictionary, turn_context: Dictionary = {}, source_version: int = 0, source_index: RefCounted = null) -> void:
	_state = state
	_context = turn_context
	version = source_version
	_index = source_index if source_index != null else HistoryIndex.new()
	_index_version = _index.version

func _project(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for field: String in value:
		if field not in HISTORY_FIELDS:
			var item: Variant = value[field]
			output[field] = item.duplicate(true) if item is Dictionary or item is Array else item
	return output

func entity(collection: String, id: String) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	if collection not in COLLECTIONS or not Store.has(_state.get(collection, {}), id):
		return {"ok": false, "error": "Unknown entity scope or identity", "version": version}
	metrics.objects += 1
	return {"ok": true, "item": _project(Store.entry(_state[collection], id)), "version": version}

func fact(id: String) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	if not Store.has(_state.facts, id):
		return {"ok": false, "error": "Unknown fact identity", "version": version}
	metrics.facts += 1
	return {"ok": true, "item": Store.entry(_state.facts, id).duplicate(true), "version": version}

func query(collection: String, ids: Array = [], limit: int = 1, cursor: int = 0) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	if collection not in COLLECTIONS or limit < 1 or limit > _index.page_limit or cursor < 0:
		return {"ok": false, "error": "Unknown query scope or invalid page", "version": version}
	var keys: Array = _current_ids(collection) if ids.is_empty() else ids.duplicate()
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
			for key: String in _current_ids(collection):
				projected[collection][key] = entity(collection, key).item
	projected["facts"] = {}
	if "economy" in scopes and _state.has("economy"):
		projected["economy"] = _state.economy.duplicate(true)
		projected["economy_qualifications"] = _state.economy_qualifications.duplicate(true)
		for source: String in _state.economy_qualifications.values():
			if Store.has(_state.facts, source):
				Store.put(projected.facts, source, fact(source).item)
	var turn: Dictionary = {}
	for field: String in _context:
		if field not in ["receipts", "completed_jobs", "journal", "queued"]:
			var value: Variant = _context[field]
			turn[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"ok": true, "reader": self, "version": version, "slot": slot, "world": projected, "turn": turn, "participant_state": _context.get("participant_state", {}).get(id, {}).duplicate(true)}

func _current_ids(collection: String) -> Array:
	if not _index.data.is_empty(): return _index.current_ids(_state, collection)
	if collection == "npcs":
		return Store.keys(_state.npcs).filter(func(id: String) -> bool: return Store.entry(_state.npcs, id).status != "dead")
	return Store.keys(_state.get(collection, {}))

func history_query(kind: String, owner: String, cursor: Dictionary = {}, limit: int = 0) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	return _index.query(_state, kind, owner, cursor, limit)

func close() -> void:
	_open = false
