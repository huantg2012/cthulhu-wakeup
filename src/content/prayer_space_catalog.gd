extends RefCounted
## Authored prayer-space content, independent of the legacy save policy hashes.
const FILES := ["cases", "costs", "frames", "operators", "parameters", "scenes", "runtime", "response_contracts"]
var tables: Dictionary = {}
var errors: Array[String] = []
var version: String = ""

func load_files(directory: String = "res://data") -> bool:
	var candidate: Dictionary = {}
	var digest := ""
	for name: String in FILES:
		var file := FileAccess.open(directory.path_join("prayer_space_" + name + ".csv"), FileAccess.READ)
		if file == null:
			errors.append("缺少祈求内容表：" + name)
			continue
		digest += name + "\n" + file.get_as_text()
		file.seek(0)
		var headers := file.get_csv_line()
		var rows: Dictionary = {}
		while not file.eof_reached():
			var cells := file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty(): continue
			if cells.size() != headers.size() or cells[0].is_empty() or rows.has(cells[0]):
				errors.append("祈求内容行无效：" + name)
				continue
			var row: Dictionary = {}
			for index: int in headers.size(): row[headers[index]] = cells[index]
			rows[cells[0]] = row
		candidate[name] = rows
	if not errors.is_empty(): return false
	for table: String in ["runtime", "response_contracts"]:
		for row: Dictionary in candidate[table].values():
			var fields: Array = ["objects", "crisis", "expiry_updates"] if table == "runtime" else ["requires", "updates", "goal", "followup", "maintenance"]
			for field: String in fields:
				var parsed := JSON.new()
				if parsed.parse(str(row.get(field, ""))) != OK:
					errors.append("Invalid prayer contract JSON: " + str(row.id) + "/" + field)
					continue
				row[field] = _numbers(parsed.data)
			if table == "response_contracts": row.irreversible = str(row.irreversible) in ["1", "true"]
	if not errors.is_empty(): return false
	var contracts: Dictionary = {}
	for row: Dictionary in candidate.response_contracts.values():
		contracts[str(row.case_id) + "/" + str(row.choice)] = row
	candidate.response_contracts = contracts
	for row: Dictionary in candidate.cases.values():
		if not candidate.frames.has(row.frame) or not candidate.scenes.has(row.scene) or not str(row.deadline).is_valid_int() or int(row.deadline) < 1:
			errors.append("祈求处境引用无效：" + str(row.id))
		var choices: Dictionary = {}
		for field: String in ["choice_a", "choice_b", "choice_c", "choice_d"]:
			var raw: PackedStringArray = str(row[field]).split("|")
			if str(row[field]).is_empty(): continue
			if raw.size() != 5 or not candidate.operators.has(raw[1]) or not candidate.costs.has(raw[2]):
				errors.append("祈求回应引用无效：" + str(row.id) + "/" + field)
				continue
			choices[field] = {"id": field, "label": raw[0], "operator": raw[1], "cost": raw[2], "effect": raw[3], "tradeoff": raw[4]}
		row["choices"] = choices
		if not candidate.runtime.has(row.id): errors.append("Missing prayer runtime: " + str(row.id))
		for choice: String in choices:
			if not contracts.has(str(row.id) + "/" + choice): errors.append("Missing executable prayer choice: " + str(row.id) + "/" + choice)
		if choices.size() < 1 or choices.size() > 5: errors.append("祈求缺少回应：" + str(row.id))
	for row: Dictionary in candidate.costs.values():
		for field: String in ["whispers", "faith", "pollution", "alert", "disaster_sanity", "disaster_alert"]:
			if not str(row[field]).is_valid_int() or int(row[field]) < 0: errors.append("祈求费用无效：" + str(row.id))
	for row: Dictionary in candidate.runtime.values():
		_check_paths(row.objects, {"crisis": row.crisis, "expiry_updates": row.expiry_updates}, str(row.id))
	for row: Dictionary in candidate.response_contracts.values():
		if not candidate.runtime.has(row.case_id):
			errors.append("Unknown situation in contract: " + str(row.id)); continue
		_check_paths(candidate.runtime[row.case_id].objects, row, str(row.id))
	if not errors.is_empty(): return false
	tables = candidate
	version = digest.sha256_text()
	return true

func parameter(id: String) -> int:
	return int(tables.parameters[id].value)

static func _numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_numbers(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = _numbers(value[key])
		return result
	return value

func _check_paths(objects: Dictionary, value: Dictionary, label: String) -> void:
	for key: String in value:
		var child: Variant = value[key]
		if key in ["requires", "updates", "goal", "expiry_updates", "on_stop", "on_end"]:
			if not child is Dictionary:
				errors.append("Malformed situation contract: " + label + "/" + key); continue
			for path: String in child:
				if path == "$crisis.delay": continue
				var node: Variant = objects
				for part: String in path.split("."):
					if not node is Dictionary or not node.has(part):
						errors.append("Undeclared situation field: " + label + "/" + path); break
					node = node[part]
		elif child is Dictionary: _check_paths(objects, child, label)
		elif child is Array:
			for item: Variant in child:
				if item is Dictionary: _check_paths(objects, item, label)
