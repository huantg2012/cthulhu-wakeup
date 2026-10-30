extends RefCounted
## Pure arithmetic for the original B dispatcher and its replay audit. Producers
## retain every eligibility, call, nomination and material rule.
const Producers = preload("res://src/game/prayer_producers.gd")
const Sources = preload("res://src/game/prayer_sources.gd")

static func binding_errors() -> Array[String]:
	var expected: Array = Producers.ROOTS.keys(); expected.erase("ROOT_KNOWN_RECORD"); expected.sort()
	var installed: Array = Producers.B_ROOTS.duplicate(); installed.sort()
	var all_roots: Array = roots(); var unique: Dictionary = {}
	for root: String in all_roots: unique[root] = true
	var issues: Array[String] = []
	if expected != installed or unique.size() != all_roots.size(): issues.append("Incomplete or repeated installed B family bindings")
	return issues

static func roots() -> Array:
	var result: Array = Producers.B_ROOTS.duplicate()
	result.append_array(Sources.ROOTS); result.append("ROOT_IDENTITY_NOTICE")
	return result

static func key(domain: String, root: String) -> String:
	return JSON.stringify([domain, root])

static func initial() -> Dictionary:
	var result: Dictionary = {}
	for root: String in roots(): result[root] = {"missed_due_slots": 0, "queue_seq": 0, "cooldown": 0, "last_source": "", "last_due": -1, "block": {"reason": "no_current_proposal"}}
	return result

static func weighted_choice(options: Array, weights: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for option: Dictionary in options: total += int(weights[option.root])
	if total <= 0: return {}
	var roll: int = rng.randi_range(1, total)
	for option: Dictionary in options:
		roll -= int(weights[option.root])
		if roll <= 0: return option.duplicate(true)
	return {}

static func select(before: Dictionary, eligible: Array, cursor: Dictionary, due: bool, content: RefCounted) -> Dictionary:
	var result: Dictionary = {"ok": true, "mode": "not_due", "choice": {}, "weights": {}, "forced_roots": [], "cooling": [], "random_after": str(cursor.state)}
	if not due: return result
	var ready: Array = []; var seen: Dictionary = {}
	for option: Variant in eligible:
		if not option is Dictionary: return {"ok": false, "error": "Invalid B family proposal"}
		var root: String = str(option.get("root", ""))
		if not before.has(root) or seen.has(root): return {"ok": false, "error": "Uninstalled or repeated B family"}
		seen[root] = true
		if int(before[root].cooldown) > 0: continue
		var base: int = int(option.get("weight", 1))
		if base <= 0: return {"ok": false, "error": "Invalid original B family weight"}
		result.weights[root] = base * content.integer("base_source_weight_scale") + int(before[root].missed_due_slots) * content.integer("missed_slot_weight_step")
		ready.append(option)
	for root: String in before:
		if int(before[root].cooldown) > 0: result.cooling.append(root)
		elif int(before[root].queue_seq) > 0: result.forced_roots.append(root)
	result.forced_roots.sort_custom(func(left: String, right: String) -> bool: return int(before[left].queue_seq) < int(before[right].queue_seq))
	result.cooling.sort()
	if not result.forced_roots.is_empty(): result.mode = "forced"; return result
	result.mode = "ordinary"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = int(cursor.seed); rng.state = int(cursor.state)
	if not ready.is_empty() and rng.randi_range(1, 100) <= content.integer("ambient_event_chance"):
		result.choice = weighted_choice(ready, result.weights, rng)
	result.random_after = str(rng.state)
	return result

static func finish(before: Dictionary, next_sequence: int, eligible: Array, attempts: Array, success_root: String, source: String, turn: int, due: bool, content: RefCounted) -> Dictionary:
	var after: Dictionary = before.duplicate(true)
	if not due: return {"sources": after, "next_queue_seq": next_sequence}
	var available: Dictionary = {}; var checked: Dictionary = {}
	for option: Dictionary in eligible: available[str(option.root)] = true
	for attempt: Dictionary in attempts: checked[str(attempt.root)] = attempt
	# Stable root order breaks simultaneous threshold ties. Once issued, tickets
	# are ordered only by this monotonic sequence, including after temporary loss.
	var names: Array = after.keys(); names.sort()
	for root: String in names:
		var row: Dictionary = after[root]; row.last_due = turn
		if int(before[root].cooldown) > 0:
			row.cooldown = int(before[root].cooldown) - 1; row.block = {"reason": "cooldown"}; continue
		if root == success_root:
			row.missed_due_slots = 0; row.queue_seq = 0
			row.cooldown = content.integer("retry_cooldown_due_slots"); row.last_source = source; row.block = {}; continue
		if checked.has(root):
			row.block = {"reason": str(checked[root].outcome)}; continue
		if not available.has(root): row.block = {"reason": "no_current_proposal"}; continue
		row.missed_due_slots = int(before[root].missed_due_slots) + 1; row.block = {}
		if row.missed_due_slots >= content.integer("forced_after_missed_slots") and int(row.queue_seq) == 0:
			row.queue_seq = next_sequence; next_sequence += 1
	return {"sources": after, "next_queue_seq": next_sequence}

static func validate_shape(sources: Dictionary, next_sequence: int) -> Array[String]:
	var actual: Array = sources.keys(); actual.sort(); var expected: Array = roots(); expected.sort()
	if actual != expected or next_sequence < 1: return ["Invalid B family partition"]
	var tickets: Dictionary = {}
	for root: String in actual:
		var row: Variant = sources[root]
		if not row is Dictionary: return ["Invalid B family state"]
		var fields: Array = row.keys(); fields.sort()
		if fields != ["block", "cooldown", "last_due", "last_source", "missed_due_slots", "queue_seq"]: return ["Invalid B family state shape"]
		for field: String in ["missed_due_slots", "queue_seq", "cooldown"]:
			if not row.get(field) is int or row[field] < 0: return ["Invalid B family counter"]
		if not row.get("last_due") is int or row.last_due < -1 or not row.get("last_source") is String or not row.get("block") is Dictionary: return ["Invalid B family observation"]
		if int(row.queue_seq) > 0:
			if row.queue_seq >= next_sequence or tickets.has(row.queue_seq) or row.cooldown > 0: return ["Repeated or invalid B FIFO ticket"]
			tickets[row.queue_seq] = true
	return []
