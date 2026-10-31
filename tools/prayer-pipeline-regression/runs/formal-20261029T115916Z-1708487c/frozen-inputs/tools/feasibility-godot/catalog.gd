extends RefCounted
## Validated, data-driven fixture catalog. No generated prose can execute code.

const FILES: Dictionary = {
	"axes": "feasibility_axes.csv",
	"npcs": "feasibility_npcs.csv",
	"events": "feasibility_events.csv",
	"parameters": "feasibility_parameters.csv",
}
const HEADERS: Dictionary = {
	"axes": ["dimension", "id", "requires_paradigm", "barrier", "stability"],
	"npcs": ["id", "competence", "resolve", "sanity", "faith"],
	"events": ["id", "min_alert", "max_alert", "min_pollution", "max_pollution", "requires_alive", "cooldown", "exclusive_group", "priority", "once", "effect", "delta", "delay", "chance", "followup"],
	"parameters": ["id", "value"],
}
const EFFECTS: Array[String] = ["faith", "alert", "pollution", "kill"]
const DIMENSIONS: Array[String] = ["paradigm", "government", "channel", "institution", "anchor", "tier"]
const PARAMETERS: Array[String] = ["initial_faith", "initial_pollution", "initial_alert", "action_cost", "action_pollution_gain", "action_alert_gain", "conceal_alert_reduction", "action_success_percent", "passive_alert_decay", "passive_pollution_decay", "faith_per_alive_npc", "faith_cap", "max_events_per_civilization_turn", "generation_attempt_limit", "event_expiry_turns", "history_full_retention_turns", "history_compact_after_records"]
var rows: Dictionary = {}
var parameters: Dictionary = {}
var events: Dictionary = {}
var version: String = ""
var errors: Array[String] = []

func load_files(data_dir: String) -> bool:
	rows.clear()
	errors.clear()
	var source: String = ""
	for key: String in FILES:
		var path: String = data_dir.path_join(str(FILES[key]))
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			errors.append("missing file: " + path)
			continue
		source += str(FILES[key]) + "\n" + file.get_as_text() + "\n"
		file.seek(0)
		var header: PackedStringArray = file.get_csv_line()
		if Array(header) != HEADERS[key]:
			errors.append("unexpected header: " + path)
			continue
		var entries: Array = []
		while not file.eof_reached():
			var cells: PackedStringArray = file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty():
				continue
			if cells.size() != header.size():
				errors.append("column count: " + path)
				continue
			var row: Dictionary = {}
			for index: int in header.size():
				row[header[index]] = cells[index]
			entries.append(row)
		rows[key] = entries
	version = source.sha256_text()
	errors.append_array(validate_rows(rows))
	if not errors.is_empty():
		return false
	parameters.clear()
	for row: Dictionary in rows.parameters:
		parameters[row.id] = int(row.value)
	events.clear()
	for row: Dictionary in rows.events:
		var converted: Dictionary = row.duplicate(true)
		for field: String in HEADERS.events:
			if not field in ["id", "exclusive_group", "effect", "followup"]:
				converted[field] = int(row[field])
		events[row.id] = converted
	return true

func validate_rows(input: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key: String in FILES:
		if not input.has(key) or not input[key] is Array or input[key].is_empty():
			found.append("missing/empty collection: " + key)
			continue
		var seen: Dictionary = {}
		for row: Variant in input[key]:
			if not row is Dictionary:
				found.append("non-object row: " + key)
				continue
			if row.size() != HEADERS[key].size():
				found.append("unexpected fields: " + key)
			for field: String in HEADERS[key]:
				if not row.has(field) or not row[field] is String:
					found.append("missing/string field: " + key + "." + field)
			if not row.has("id") or str(row.id).is_empty():
				found.append("missing ID: " + key)
				continue
			if seen.has(row.id):
				found.append("duplicate ID: " + str(row.id))
			seen[row.id] = true
	if not found.is_empty():
		return found
	var paradigms: Array[String] = []
	var dimensions_found: Dictionary = {}
	for row: Dictionary in input.axes:
		dimensions_found[row.dimension] = true
		if row.dimension == "paradigm":
			paradigms.append(row.id)
		if not row.dimension in DIMENSIONS:
			found.append("unknown dimension: " + row.dimension)
		for key: String in ["barrier", "stability"]:
			if not row[key].is_valid_int() or int(row[key]) < 0 or int(row[key]) > 100:
				found.append("axis range: " + key)
	for dimension: String in DIMENSIONS:
		if not dimensions_found.has(dimension):
			found.append("missing dimension: " + dimension)
	for row: Dictionary in input.axes:
		if not row.requires_paradigm.is_empty():
			for requirement: String in row.requires_paradigm.split("|"):
				if not requirement in paradigms:
					found.append("unknown paradigm reference: " + requirement)
	for row: Dictionary in input.npcs:
		for key: String in ["competence", "resolve", "sanity", "faith"]:
			if not row[key].is_valid_int() or int(row[key]) < 0 or int(row[key]) > 100:
				found.append("NPC range: " + key)
	var event_ids: Array[String] = []
	var followups: Dictionary = {}
	for row: Dictionary in input.events:
		event_ids.append(row.id)
		followups[row.id] = row.followup
	for row: Dictionary in input.events:
		for key: String in HEADERS.events:
			if not key in ["id", "exclusive_group", "effect", "followup"] and not row[key].is_valid_int():
				found.append("event integer: " + key)
		if not row.effect in EFFECTS:
			found.append("unknown effect: " + row.effect)
		if not row.followup.is_empty() and not row.followup in event_ids:
			found.append("unknown followup: " + row.followup)
		for metric: String in ["alert", "pollution"]:
			if int(row["min_" + metric]) > int(row["max_" + metric]) or int(row["min_" + metric]) < 0 or int(row["max_" + metric]) > 100:
				found.append("contradictory condition: " + row.id)
		if int(row.chance) < 0 or int(row.chance) > 100 or int(row.cooldown) < 0 or int(row.delay) < 0:
			found.append("event scheduling range: " + row.id)
		if not int(row.requires_alive) in [0, 1] or not int(row.once) in [0, 1]:
			found.append("event boolean range: " + row.id)
		var visited: Dictionary = {}
		var next: String = row.id
		while not next.is_empty() and followups.has(next):
			if visited.has(next):
				found.append("cyclic followup: " + row.id)
				break
			visited[next] = true
			next = followups[next]
	var parameter_ids: Array[String] = []
	for row: Dictionary in input.parameters:
		parameter_ids.append(row.id)
		if not row.value.is_valid_int() or int(row.value) < 0:
			found.append("invalid parameter: " + row.id)
		if not row.id in PARAMETERS:
			found.append("unknown parameter: " + row.id)
	for key: String in PARAMETERS:
		if not key in parameter_ids:
			found.append("missing parameter: " + key)
	return found

func choices(dimension: String, paradigms: Array = []) -> Array:
	var result: Array = []
	for row: Dictionary in rows.axes:
		if row.dimension != dimension:
			continue
		if row.requires_paradigm.is_empty():
			result.append(row)
			continue
		for requirement: String in row.requires_paradigm.split("|"):
			if requirement in paradigms:
				result.append(row)
				break
	return result
