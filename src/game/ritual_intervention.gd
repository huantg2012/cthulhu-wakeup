extends RefCounted
## One structural policy shared by discovery, selectors and the commit authority.
const Store = preload("res://src/simulation/archive_store.gd")

static var _rules: Array = []

static func rules() -> Array:
	if not _rules.is_empty(): return _rules
	var file := FileAccess.open("res://data/ritual_interventions.csv", FileAccess.READ)
	var keys := file.get_csv_line()
	var rows: Array = []
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() != keys.size(): continue
		var row := {}
		for i: int in keys.size(): row[keys[i]] = cells[i]
		rows.append(row)
	_rules = rows
	return _rules

static func fact(state: Dictionary, id: String, reader: Variant) -> Dictionary:
	if Store.has(state.facts, id): return Store.entry(state.facts, id)
	return reader.fact(id).get("item", {}) if reader != null else {}

static func source_valid(state: Dictionary, person: Dictionary, source: String, catalog: RefCounted, reader: Variant = null) -> bool:
	if person.get("status") != "active" or "ritual_keeper" not in person.get("role_tags", []): return false
	if Store.has(state.invalid_records, source) or (reader != null and reader.invalidated(source)): return false
	var record := fact(state, source, reader)
	if record.is_empty() or record.get("domain") != person.get("domain"): return false
	for rule: Dictionary in rules():
		match str(rule.qualification):
			"open_petitioner":
				if record.kind != rule.producer or record.get("actor") != person.id: continue
				for scene: Dictionary in state.get("prayer_system", {}).get("space", {}).get("scenes", {}).values():
					if scene.get("source") == source and scene.get("roles", {}).get("petitioner") == person.id and scene.get("status") == "open": return true
			"successful_dream":
				if record.kind == rule.producer and record.get("actor") == person.id and record.changes.get("power") == "POWER_DREAM" and record.changes.get("outcome") in ["success", "deep"]: return true
			"loyal_member":
				if not person.get("bound_member", false) or int(person.get("loyalty", 0)) < catalog.integer("loyalty_follower_threshold"): continue
				if record.kind == rule.producer and record.get("actor") == person.id and source == person.get("binding_source", ""): return true
	return false

static func sources(state: Dictionary, person: Dictionary, known: Dictionary, catalog: RefCounted, reader: Variant = null) -> Array:
	var result: Array = []
	if person.is_empty() or "ritual_keeper" not in person.get("role_tags", []): return result
	# The ledger bounds this query; hidden facts cannot admit an action.
	for id: String in known:
		if source_valid(state, person, id, catalog, reader): result.append(id)
	result.sort()
	return result
