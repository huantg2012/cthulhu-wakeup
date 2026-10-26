extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## One synchronous candidate, published only after the owner validates its closure.
## Current collections use first-write copies; append-only history copies its root
## once on first append. Segmented history storage is a later migration.
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const HISTORY_WORLD: Array[String] = ["facts", "applied_authorizations", "invalid_records"]
const HISTORY_CONTEXT: Array[String] = ["receipts", "completed_jobs", "journal"]
var world: RefCounted
var base_state: Dictionary
var base_context: Dictionary
var candidate: Dictionary
var context: Dictionary
var randoms: Dictionary
var stats: Dictionary
var base_randoms: Dictionary
var base_history: RefCounted
var base_history_data: Dictionary
var base_history_rules: Dictionary
var base_history_policy: String
var base_history_limit: int
var base_history_incarnation: String
var base_history_version: int
var candidate_history: RefCounted
var base_stats: Dictionary
var sequence: int
var world_writes: Dictionary = {}
var context_writes: Dictionary = {}
var metrics: Dictionary = {"copied_collections": [], "history_root_entries": 0, "new_facts_validated": 0}
var ready: bool = false
var error: String = ""
var active: bool = false
var new_receipts: Array = []
var new_completed: Array = []

func _init(rule_world: RefCounted, turn_context: Dictionary, commit_sequence: int = 0) -> void:
	world = rule_world
	if not world.ensure_history():
		error = world.last_error
		return
	base_history = world.history
	base_history_data = base_history.data
	base_history_version = base_history.version
	base_history_rules = base_history.rules
	base_history_policy = base_history.policy
	base_history_limit = base_history.page_limit
	base_history_incarnation = base_history.incarnation
	candidate_history = base_history.fork()
	freeze(world.state)
	freeze(turn_context)
	base_state = Store.pack_state(world.state)
	world.state = base_state
	base_context = Store.pack_context(turn_context)
	# First adoption / full restore is an audit boundary, not an ordinary action.
	# Subsequent commits already froze their new objects; this is O(1) then.
	freeze(base_state)
	freeze(base_context)
	candidate = base_state.duplicate(false)
	context = base_context.duplicate(false)
	for key: String in context:
		if key not in HISTORY_CONTEXT and (context[key] is Dictionary or context[key] is Array):
			context[key] = context[key].duplicate(true)
	base_randoms = clone_randoms(world.randoms)
	randoms = clone_randoms(base_randoms)
	freeze(world.stats)
	base_stats = world.stats
	stats = base_stats.duplicate(true)
	sequence = commit_sequence
	ready = true

static func freeze(value: Variant, audit: bool = false) -> void:
	if value is Dictionary:
		if value.is_read_only() and not audit:
			return
		for child: Variant in value.values():
			freeze(child, audit)
		value.make_read_only()
	elif value is Array:
		if value.is_read_only() and not audit:
			return
		for child: Variant in value:
			freeze(child, audit)
		value.make_read_only()

static func clone_randoms(streams: Dictionary) -> Dictionary:
	var copies: Dictionary = {}
	for name: String in streams:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = streams[name].seed
		rng.state = streams[name].state
		copies[name] = rng
	return copies

static func random_positions(streams: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	for name: String in streams:
		positions[name] = [str(streams[name].seed), str(streams[name].state)]
	return positions

func activate() -> bool:
	if not ready or active: return false
	world.state = candidate
	world.history = candidate_history
	world.history.source_root = candidate
	world.randoms = randoms
	world.stats = stats
	world.transaction = self
	active = true
	return true

func touch_world(fields: Array) -> void:
	if not ready: return
	for field: String in fields:
		if world_writes.has(field) or not candidate.has(field):
			continue
		if candidate[field] is Dictionary or candidate[field] is Array:
			if field in HistoryIndex.COLD_FIELDS:
				candidate[field] = world.history.copy_collection(candidate, field)
			elif Store.packed(candidate[field]):
				candidate[field] = Store.begin(candidate[field])
			else:
				candidate[field] = candidate[field].duplicate(field not in HISTORY_WORLD)
		world_writes[field] = true
		metrics.copied_collections.append(field)

func touch_context(fields: Array) -> void:
	if not ready: return
	for field: String in fields:
		if context_writes.has(field) or not context.has(field):
			continue
		if field in Store.CONTEXT_ROOTS:
			context[field] = Store.begin(context[field])
		elif field != "journal" and (context[field] is Dictionary or context[field] is Array):
			context[field] = context[field].duplicate(true)
		context_writes[field] = true

func validate_world() -> Array[String]:
	if not ready: return [error]
	var errors: Array[String] = append_only_errors(candidate.get("facts", {}), base_state.facts)
	if not errors.is_empty():
		return errors
	metrics.new_facts_validated = maxi(0, int(candidate.get("next_fact", 0)) - int(base_state.next_fact))
	return world.validate_increment(candidate, base_state)

static func append_only_errors(after: Variant, before: Variant) -> Array[String]:
	if is_same(after, before): return []
	if Store.packed(before): return Store.retained(after, before, true)
	if HistoryIndex.is_history(before) and before.kind == "sequence":
		if not HistoryIndex.is_history(after) or after.kind != "sequence": return ["Invalid phase history"]
		var changes: Array = HistoryIndex.changed_entries(after, before)
		var added: int = 0
		for item: Dictionary in changes:
			if HistoryIndex.has(before, item.key): return ["Committed phase history was replaced"]
			added += 1
		return [] if HistoryIndex.size(after) == HistoryIndex.size(before) + added else ["Committed phase history disappeared"]
	return ["Untrusted append-only history replacement"]

func publish() -> void:
	assert(active)
	# Only new current collections / new records are mutable. Shared old objects
	# short-circuit in freeze; no old fact payload is traversed again.
	for field: String in Store.WORLD_ROOTS:
		candidate[field] = Store.finish(candidate[field])
	for field: String in Store.CONTEXT_ROOTS:
		context[field] = Store.finish(context[field])
	freeze(world.history.data)
	world.history.source_root = candidate
	freeze(candidate)
	freeze(context)
	freeze(stats)
	world.transaction = null
	active = false

func rollback() -> void:
	if not ready: return
	world.state = base_state
	world.history = base_history
	world.history.data = base_history_data
	world.history.version = base_history_version
	world.history.rules = base_history_rules
	world.history.policy = base_history_policy
	world.history.page_limit = base_history_limit
	world.history.incarnation = base_history_incarnation
	world.history.source_root = base_state
	world.randoms = base_randoms
	world.stats = base_stats
	world.transaction = null
	active = false
