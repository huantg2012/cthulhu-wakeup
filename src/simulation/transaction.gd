extends RefCounted
## One synchronous candidate, published only after the owner validates its closure.
## Current collections use first-write copies; append-only history copies its root
## once on first append. Segmented history storage is a later migration.
const HISTORY_WORLD: Array[String] = ["facts"]
const HISTORY_CONTEXT: Array[String] = ["receipts", "completed_jobs", "journal"]
var world: RefCounted
var base_state: Dictionary
var base_context: Dictionary
var candidate: Dictionary
var context: Dictionary
var randoms: Dictionary
var stats: Dictionary
var base_randoms: Dictionary
var base_stats: Dictionary
var sequence: int
var world_writes: Dictionary = {}
var context_writes: Dictionary = {}
var metrics: Dictionary = {"copied_collections": [], "history_root_entries": 0, "new_facts_validated": 0}
var active: bool = false

func _init(rule_world: RefCounted, turn_context: Dictionary, commit_sequence: int = 0) -> void:
	world = rule_world
	base_state = world.state
	base_context = turn_context
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

func activate() -> void:
	assert(not active)
	world.state = candidate
	world.randoms = randoms
	world.stats = stats
	world.transaction = self
	active = true

func touch_world(fields: Array) -> void:
	for field: String in fields:
		if world_writes.has(field) or not candidate.has(field):
			continue
		if candidate[field] is Dictionary or candidate[field] is Array:
			candidate[field] = candidate[field].duplicate(field not in HISTORY_WORLD)
			if field in HISTORY_WORLD:
				metrics.history_root_entries += candidate[field].size()
		world_writes[field] = true
		metrics.copied_collections.append(field)

func touch_context(fields: Array) -> void:
	for field: String in fields:
		if context_writes.has(field) or not context.has(field):
			continue
		if context[field] is Dictionary or context[field] is Array:
			context[field] = context[field].duplicate(field not in HISTORY_CONTEXT)
			if field in HISTORY_CONTEXT:
				metrics.history_root_entries += context[field].size()
		context_writes[field] = true

func validate_world() -> Array[String]:
	var errors: Array[String] = append_only_errors(candidate.get("facts", {}), base_state.facts)
	if not errors.is_empty():
		return errors
	metrics.new_facts_validated = maxi(0, int(candidate.get("next_fact", 0)) - int(base_state.next_fact))
	return world.validate_increment(candidate, base_state)

static func append_only_errors(after: Variant, before: Variant) -> Array[String]:
	if typeof(after) != typeof(before) or after.size() < before.size():
		return ["Append-only history shrank or changed type"]
	if is_same(after, before):
		return []
	# Root identity checks are intentionally still O(history keys), but never
	# recurse into historical payloads or serialize them. Archive task removes it.
	if before is Dictionary:
		for key: Variant in before:
			if not after.has(key) or not is_same(after[key], before[key]):
				return ["Previously committed history was replaced"]
	elif before is Array:
		for index: int in before.size():
			if not is_same(after[index], before[index]):
				return ["Previously committed journal was replaced"]
	return []

func publish() -> void:
	assert(active)
	# Only new current collections / new records are mutable. Shared old objects
	# short-circuit in freeze; no old fact payload is traversed again.
	freeze(candidate)
	freeze(context)
	freeze(stats)
	world.transaction = null
	active = false

func rollback() -> void:
	world.state = base_state
	world.randoms = base_randoms
	world.stats = base_stats
	world.transaction = null
	active = false
