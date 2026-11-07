extends RefCounted
## Display identity only: its private stream never enters World or Turn RNG.
const VERSION: String = "world-names/1"
const MAX_ATTEMPTS: int = 256
const MAX_COMBINATIONS: int = 1000000000
var errors: Array[String] = []
var capacities: Dictionary = {}
var _pools: Dictionary = {}
var _groups: Dictionary = {}

func load_files(profiles: Dictionary, directory: String) -> bool:
	errors.clear()
	var pools: Dictionary = {}; var groups: Dictionary = {}; var counts: Dictionary = {}
	var legal: Dictionary = {}
	for profile: Dictionary in profiles.values():
		legal[str(profile.tier) + "/" + str(profile.authority)] = true
	var parts: Array[Dictionary] = _read(directory.path_join("world_name_parts.csv"), ["id", "pool", "text"])
	var token := RegEx.new(); token.compile("^[a-z][a-z0-9_]*$")
	for row: Dictionary in parts:
		if token.search(row.pool) == null or not _valid_label(row.text) or row.text.contains("{") or row.text.contains("}"):
			errors.append("Invalid world name part: " + str(row.id)); continue
		if not pools.has(row.pool): pools[row.pool] = []
		if row.text in pools[row.pool]: errors.append("Duplicate world name part: " + str(row.id))
		else: pools[row.pool].append(row.text)
	var placeholders := RegEx.new(); placeholders.compile("\\{([a-z][a-z0-9_]*)\\}")
	for row: Dictionary in _read(directory.path_join("world_name_patterns.csv"), ["id", "tier", "authority", "family", "pattern"]):
		var key: String = str(row.tier) + "/" + str(row.authority)
		if not legal.has(key) or token.search(row.family) == null:
			errors.append("Invalid world name tier/authority/family: " + str(row.id)); continue
		var used: Array[String] = []; var count: int = 1
		var remainder: String = row.pattern
		for match_value: RegExMatch in placeholders.search_all(row.pattern):
			var pool: String = match_value.get_string(1)
			remainder = remainder.replace(match_value.get_string(), "")
			if not pools.has(pool): errors.append("Unknown world name pool: " + pool); continue
			if pool not in used:
				used.append(pool)
				count *= pools[pool].size()
				if count > MAX_COMBINATIONS: errors.append("World name pattern exceeds finite capacity: " + str(row.id)); break
		if used.is_empty() or remainder.contains("{") or remainder.contains("}") or (not remainder.is_empty() and not _valid_label(remainder)) or not _valid_label(row.pattern, false):
			errors.append("Invalid world name pattern: " + str(row.id)); continue
		if not groups.has(key): groups[key] = {}
		if not groups[key].has(row.family): groups[key][row.family] = []
		groups[key][row.family].append({"id":row.id, "pattern":row.pattern, "pools":used})
		counts[row.tier] = int(counts.get(row.tier, 0)) + count
	for key: String in legal:
		if groups.get(key, {}).size() < 2: errors.append("World names need multiple families for " + key)
	if not errors.is_empty(): return false
	_pools = pools; _groups = groups; capacities = counts
	return true

func _read(path: String, header: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: errors.append("Missing world name CSV: " + path); return result
	if Array(file.get_csv_line()) != header: errors.append("Invalid world name CSV header: " + path); return result
	var ids: Dictionary = {}
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != header.size() or cells[0].is_empty() or ids.has(cells[0]):
			errors.append("Invalid or duplicate world name row: " + path); continue
		ids[cells[0]] = true
		var row: Dictionary = {}
		for index: int in header.size(): row[header[index]] = cells[index]
		result.append(row)
	return result

static func _valid_label(value: String, reject_digits: bool = true) -> bool:
	if value.is_empty() or value != value.strip_edges() or value.contains("\n") or value.contains("\r") or value.contains("\t"): return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if code < 32 or (reject_digits and code >= 48 and code <= 57): return false
	return true

func generate(seed_value: int, domains: Dictionary) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = (VERSION + "/" + str(seed_value)).sha256_text().left(15).hex_to_int()
	var names: Dictionary = {}; var families: Dictionary = {}; var used: Dictionary = {}; var family_counts: Dictionary = {}
	var ids: Array = domains.keys(); ids.sort()
	for id: String in ids:
		var domain: Dictionary = domains[id]
		var key: String = str(domain.get("tier", "")) + "/" + str(domain.get("authority", ""))
		if not _groups.has(key): return {"ok":false, "error":"Missing world name structures for " + key}
		var available: Dictionary = _groups[key]
		var chosen: String = ""; var chosen_family: String = ""
		for attempt: int in MAX_ATTEMPTS:
			var least: int = 2147483647; var candidates: Array[String] = []
			for family: String in available:
				var visits: int = int(family_counts.get(family, 0))
				if visits < least: least = visits; candidates.clear()
				if visits == least: candidates.append(family)
			chosen_family = candidates[random.randi_range(0, candidates.size() - 1)]
			var patterns: Array = available[chosen_family]
			var pattern: Dictionary = patterns[random.randi_range(0, patterns.size() - 1)]
			var label: String = pattern.pattern
			for pool: String in pattern.pools:
				var words: Array = _pools[pool]
				label = label.replace("{" + pool + "}", words[random.randi_range(0, words.size() - 1)])
			if _valid_label(label) and not used.has(label): chosen = label; break
		if chosen.is_empty(): return {"ok":false, "error":"World name generation exhausted unique draws for " + id}
		names[id] = chosen; families[id] = chosen_family; used[chosen] = true
		family_counts[chosen_family] = int(family_counts.get(chosen_family, 0)) + 1
	return {"ok":true, "names":names, "families":families}

static func restore(payload: Variant, domains: Dictionary) -> Dictionary:
	if not payload is Dictionary or payload.size() != 2 or payload.get("version") != VERSION or not payload.get("worlds") is Dictionary:
		return {"ok":false, "error":"存档世界名称格式不正确"}
	var names: Dictionary = payload.worlds
	if names.size() != domains.size(): return {"ok":false, "error":"存档世界名称不完整"}
	var seen: Dictionary = {}
	for id: Variant in names:
		if not id is String or not domains.has(id) or not names[id] is String:
			return {"ok":false, "error":"存档世界名称引用不正确"}
		var label: String = names[id]
		if not _valid_label(label) or seen.has(label): return {"ok":false, "error":"存档世界名称为空或重复"}
		seen[label] = true
	return {"ok":true, "names":names.duplicate(true)}
