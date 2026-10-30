extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## Bounded, detached current projections and explicit ID reads. This adapter never
## returns the authoritative root or an enumerable archive to a rule participant.
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const SocialGraph = preload("res://src/simulation/social_graph.gd")
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
	for field: String in ["power_system", "relic_system", "prayer_system", "anchor_system", "event_system", "resistance_system", "ending_system", "player_sources", "cult_system"]:
		if _state.has(field): projected[field] = _state[field].duplicate(true)
	if _state.has("prayer_knowledge"):
		projected["prayer_knowledge"] = {}
		for field: String in ["schema", "version", "seed", "identity"]: projected.prayer_knowledge[field] = _state.prayer_knowledge[field]
		projected.prayer_knowledge["heads"] = {}
		for person: String in projected.get("npcs", {}):
			if _state.prayer_knowledge.heads.has(person): projected.prayer_knowledge.heads[person] = _state.prayer_knowledge.heads[person].duplicate(true)
	if _state.has("attention"):
		projected["attention"] = _state.attention.duplicate(true)
	if _state.has("simulation"):
		projected["simulation"] = _state.simulation.duplicate(true)
	projected["facts"] = {}
	if "economy" in scopes and _state.has("economy"):
		projected["economy"] = _state.economy.duplicate(true)
		projected["economy_qualifications"] = _state.economy_qualifications.duplicate(true)
		# Only current economic capability IDs are relevant to this projection.
		# Query their authoritative revocation keys; never enumerate archived H.
		projected["invalid_records"] = {}
		for source: String in _state.economy_qualifications.values():
			if invalidated(source): projected.invalid_records[source] = Store.entry(_state.invalid_records, source)
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

func background_candidates() -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	var items: Array = []
	if not _state.has("simulation"): return {"ok": true, "items": items, "version": version}
	for id: String in _context.get("background_ids", []):
		if not _state.simulation.candidates.has(id): continue
		var card: Dictionary = _state.simulation.candidates[id]
		var valid: bool = card.visible_turn <= _context.turn and card.due_turn >= _context.turn
		for actor: String in card.actors:
			valid = valid and Store.has(_state.npcs, actor) and Store.entry(_state.npcs, actor).status == "active" and Store.entry(_state.npcs, actor).domain == card.domain
		for source: String in card.source_ids: valid = valid and Store.has(_state.facts, source) and not Store.has(_state.invalid_records, source)
		if valid: items.append(card.duplicate(true))
	return {"ok": true, "items": items, "version": version}

func authorization(key: String) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	return {"ok": true, "used": Store.has(_state.applied_authorizations, key), "source": Store.entry(_state.applied_authorizations, key, "")}

func invalidated(source: String) -> bool:
	return not _open or _index_version != _index.version or Store.has(_state.invalid_records, source)

func prayer_candidates() -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	var items: Array = []
	for id: String in _state.get("simulation", {}).get("candidates", {}):
		var card: Dictionary = _state.simulation.candidates[id]
		if str(card.get("content_id", "")).begins_with("PRAYER_"): items.append(card.duplicate(true))
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return {"ok": true, "items": items, "version": version}

func prayer_sources() -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	return {"ok": true, "items": _index.ids("prayer_sources"), "version": version}

func identity_knowledge(person: String, sample: Dictionary = {}) -> Dictionary:
	if not _open or _index_version != _index.version: return {"known": false, "error": "Expired read view"}
	return Knowledge.known(_state, person, sample)

func knows(owner: String, source: String, institution: bool = false) -> bool:
	if not _open or _index_version != _index.version: return false
	return _index.knows(_state, owner, source, institution)

func relation(owner: String, target: String, source: String) -> Dictionary:
	if not _open or _index_version != _index.version: return {}
	return _index.relation(owner, target, source)

func relation_between(a: String, b: String, types: Array = []) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.relation_between(a, b, types)

func relation_source(source: String) -> Dictionary:
	if not _open or _index_version != _index.version: return {}
	return _index.relation_source(source)

func contact_context(a: String, b: String) -> Dictionary:
	if not _open or _index_version != _index.version: return {}
	return SocialGraph.contact_context(_state, a, b).duplicate(true)

func contact_page(person: String, cursor: int = 0, limit: int = 0) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	return _index.contact_page(person, cursor, limit)

func institution_results(institution: String, cursor: Dictionary = {}, limit: int = 0) -> Dictionary:
	if not _open or _index_version != _index.version: return {"ok": false, "error": "Expired read view"}
	return _index.query(_state, "institution_results", institution, cursor, limit)

func institution_restriction(institution: String) -> String:
	if not _open or _index_version != _index.version or not _state.institutions.has(institution): return ""
	return _index.institution_restriction(institution)

func event_record_heads(institution: String, person: String, family: String) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.event_record_heads(institution, person, family)

func event_inheritance(contract: String) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.event_inheritance(contract)

func event_will(prophet: String, prophet_source: String) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.event_will(prophet, prophet_source)

func institution_ritual_restriction(institution: String, priest: String, ritual: String, after: String = "") -> String:
	if not _open or _index_version != _index.version: return ""
	return _index.institution_ritual_restriction(institution, priest, ritual, after)

func institution_ritual_clear(institution: String, priest: String, ritual: String) -> String:
	if not _open or _index_version != _index.version: return ""
	return _index.institution_ritual_clear(institution, priest, ritual)

func relation_head(owner: String, target: String, kinds: Array) -> Dictionary:
	if not _open or _index_version != _index.version: return {}
	return _index.relation_head(owner, target, kinds)

func event_record_public(source: String) -> bool:
	if not _open or _index_version != _index.version: return false
	return _index.event_record_public(source)

func anchor_material_heads(domain: String, limit: int) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.anchor_material_heads(domain, limit)

func anchor_successors(contract: String) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.anchor_successors(contract)

func anchor_basis_source(institution: String, basis: Dictionary) -> String:
	if not _open or _index_version != _index.version: return ""
	return _index.anchor_basis_source(institution, basis)

func material_receipts(source: String) -> Array:
	if not _open or _index_version != _index.version: return []
	return _index.material_receipts(source)
