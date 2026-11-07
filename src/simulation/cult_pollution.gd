extends RefCounted

const Store = preload("res://src/simulation/archive_store.gd")
const CAPABILITY := "cult-pollution-v1"
const BASIS_POINTS := 10000
const SCHEMA := ["id", "value", "unit", "status", "rationale"]
const PARAMETER_LIMITS := {
	"fixed_scale": [1000, 1000],
	"size_share_reference": [0.0001, 1],
	"size_rate_cap": [0, 100],
	"member_rate_per_adaptation": [0, 100],
	"member_rate_cap": [0, 100],
	"support_at_reference_share": [0, 100],
	"support_per_adaptation": [0, 100],
	"conceal_multiplier": [0, 1],
	"hold_multiplier": [0, 1],
	"expand_multiplier": [0, 1],
}

var version: String
var values: Dictionary = {}
var errors: Array[String] = []

func load_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or Array(file.get_csv_line()) != SCHEMA:
		errors.append("Missing or malformed cult pollution CSV")
		return false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty(): continue
		if row.size() != SCHEMA.size() or not PARAMETER_LIMITS.has(row[0]) or values.has(row[0]) or not row[1].is_valid_float():
			errors.append("Invalid cult pollution parameter row")
			return false
		var value := float(row[1])
		var limits: Array = PARAMETER_LIMITS[row[0]]
		var scale := BASIS_POINTS if row[0] == "size_share_reference" else 1000
		if not is_finite(value) or value < limits[0] or value > limits[1] or not is_equal_approx(value * scale, roundf(value * scale)):
			errors.append("Invalid cult pollution parameter: " + row[0])
			return false
		values[row[0]] = roundi(value * scale)
	if values.size() != PARAMETER_LIMITS.size():
		errors.append("Incomplete cult pollution parameters")
		return false
	values.fixed_scale /= 1000
	version = CAPABILITY + "/" + FileAccess.get_file_as_string(path).sha256_text()
	return true

static func integer_sqrt(value: int) -> int:
	if value < 2: return value
	var root: int = value
	var next: int = (root + 1) / 2
	while next < root:
		root = next
		next = (root + value / root) / 2
	return root

func inputs(state: Dictionary, cult: Dictionary, catalog: RefCounted, working: bool, strategy: String) -> Dictionary:
	var domain: Dictionary = state.domains[cult.domain]
	var members: Dictionary = {}
	# The persistent membership index is bounded. The fallback supports
	# non-hybrid simulations that use the same authoritative membership fields.
	var ids: Array = state.attention.members.keys() if state.has("attention") else Store.keys(state.npcs)
	if cult.status != "destroyed":
		for id: String in ids:
			var person: Dictionary = Store.entry(state.npcs, id, {})
			if not eligible(person, cult, catalog): continue
			var joined_id: String = person.get("joined_source", "")
			if Store.has(state.invalid_records, joined_id): continue
			var joined: Dictionary = Store.entry(state.facts, joined_id, {})
			if joined.get("kind") != "cult_member_joined" or joined.get("changes", {}).get("cult") != cult.id or joined.get("actor") != id: continue
			members[id] = int(person.adaptation)
	return {
		"cult": cult.id, "members": members, "working": working and members.has(cult.leader),
		"followers": int(domain.unnamed_followers),
		"population": int(domain.unnamed_followers) + int(domain.unnamed_nonfollowers),
		"cohesion": int(cult.cohesion), "strategy": strategy,
	}

static func eligible(person: Dictionary, cult: Dictionary, catalog: RefCounted) -> bool:
	return not person.is_empty() and cult.status != "destroyed" and person.get("bound_member", false) and person.get("cult_id") == cult.id and person.get("domain") == cult.domain and person.get("status") == "active" and int(person.get("loyalty", 0)) >= catalog.integer("loyalty_follower_threshold")

func production(input: Dictionary, maximum: int) -> Dictionary:
	var scale: int = values.fixed_scale
	var factor := 0
	if input.working and input.population > 0:
		factor = integer_sqrt(int(input.followers) * BASIS_POINTS * scale * scale / (int(input.population) * int(values.size_share_reference)))
	var adaptation := 0
	for value: int in input.members.values(): adaptation += value
	var multiplier: int = values.get(input.strategy + "_multiplier", scale) if input.working else scale
	var size: int = int(values.size_rate_cap) * mini(scale, factor) / scale
	size = size * int(input.cohesion) / maximum * multiplier / scale
	var named: int = mini(values.member_rate_cap, int(values.member_rate_per_adaptation) * adaptation) * multiplier / scale
	var support: int = int(values.support_at_reference_share) * factor / scale + int(values.support_per_adaptation) * adaptation
	return {"size": size, "named": named, "support": mini(maximum * scale, support)}

func total(domain: Dictionary) -> int:
	return int(domain.pollution) * int(values.fixed_scale) + int(domain.pollution_remainder)

func write_total(domain: Dictionary, value: int, maximum: int) -> void:
	var scale: int = values.fixed_scale
	var bounded := clampi(value, 0, maximum * scale)
	domain.pollution = bounded / scale
	domain.pollution_remainder = bounded % scale

func settlement(before: int, produced: Dictionary, decay: int, maximum: int) -> Dictionary:
	var raw: int = produced.size + produced.named
	var growth: int = mini(raw, maxi(0, int(produced.support) - before))
	var size: int = growth * int(produced.size) / raw if raw > 0 else 0
	var after := clampi(before + growth - decay, 0, maximum * int(values.fixed_scale))
	return {"size": size, "named": growth - size, "decay": before + growth - after, "net": after - before}

func valid_state(domain: Dictionary, turn: int, maximum: int) -> bool:
	var remainder: Variant = domain.get("pollution_remainder")
	var settled: Variant = domain.get("pollution_settled_turn")
	return remainder is int and remainder >= 0 and remainder < values.fixed_scale and (int(domain.get("pollution", maximum)) < maximum or remainder == 0) and settled is int and settled >= -1 and settled <= turn

func valid_receipt(receipt: Dictionary, sequence: int, maximum: int, base_decay: int) -> bool:
	if receipt.get("version") != version or not receipt.get("cult") is String or not receipt.get("produced") is Dictionary:
		return false
	for key: String in ["before", "before_revision", "decay_rate", "size", "named", "decay", "net"]:
		if not receipt.get(key) is int: return false
	var scale: int = values.fixed_scale
	if receipt.before < 0 or receipt.before > maximum * scale or receipt.before_revision < 0 or receipt.before_revision >= sequence or receipt.decay_rate not in [0, base_decay * scale]:
		return false
	var produced: Dictionary = receipt.produced
	for key: String in ["size", "named", "support"]:
		if not produced.get(key) is int or produced[key] < 0: return false
	if produced.size > values.size_rate_cap or produced.named > values.member_rate_cap or produced.support > maximum * scale:
		return false
	var expected := settlement(receipt.before, produced, receipt.decay_rate, maximum)
	for key: String in expected:
		if expected[key] != receipt[key]: return false
	return true
