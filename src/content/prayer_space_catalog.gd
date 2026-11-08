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
			var fields: Array = ["objects", "crisis", "expiry_updates"] if table == "runtime" else ["requires", "updates", "goal", "followup", "maintenance", "outcomes", "miracle", "consequence"]
			for field: String in fields:
				var parsed := JSON.new()
				if parsed.parse(str(row.get(field, "[]" if field == "outcomes" else ""))) != OK:
					errors.append("Invalid prayer contract JSON: " + str(row.id) + "/" + field)
					continue
				row[field] = _numbers(parsed.data)
			if table == "response_contracts":
				row.irreversible = str(row.irreversible) in ["1", "true"]
				row["disclosure"] = str(row.get("disclosure", "clear"))
				row["approach"] = str(row.get("approach", ""))
				row["omen"] = str(row.get("omen", ""))
				var intensity := str(row.get("intensity", "0"))
				if not intensity.is_valid_int() or int(intensity) < 0 or int(intensity) > 3: errors.append("Invalid prayer intensity: " + str(row.id))
				row["intensity"] = int(intensity)
				var difficulty := str(row.get("difficulty", ""))
				if not difficulty.is_valid_int() or int(difficulty) < -20 or int(difficulty) > 30: errors.append("Invalid prayer difficulty: " + str(row.id))
				row["difficulty"] = int(difficulty)
				if not row.get("check_kind", "") in ["occult", "social"]: errors.append("Invalid prayer check kind: " + str(row.id))
				if not row.get("attribute", "") in ["insight", "adaptation", "will", "influence"]: errors.append("Invalid prayer attribute: " + str(row.id))
				if str(row.get("hint", "")).strip_edges().is_empty(): errors.append("Missing prayer hint: " + str(row.id))
				_check_response(row)
	if not errors.is_empty(): return false
	var contracts: Dictionary = {}
	for row: Dictionary in candidate.response_contracts.values():
		contracts[str(row.case_id) + "/" + str(row.choice)] = row
	candidate.response_contracts = contracts
	for row: Dictionary in candidate.cases.values():
		if not candidate.frames.has(row.frame) or not candidate.scenes.has(row.scene) or not str(row.deadline).is_valid_int() or int(row.deadline) < 1:
			errors.append("祈求处境引用无效：" + str(row.id))
		var choices: Dictionary = {}
		var choice_fields: Array = row.keys().filter(func(field: String) -> bool: return field.begins_with("choice_"))
		choice_fields.sort()
		for field: String in choice_fields:
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
		if choices.size() < 2 or choices.size() > 5: errors.append("祈求缺少回应：" + str(row.id))
	for row: Dictionary in candidate.costs.values():
		for field: String in ["whispers", "faith", "pollution", "alert", "disaster_sanity", "disaster_alert"]:
			if not str(row[field]).is_valid_int() or int(row[field]) < 0: errors.append("祈求费用无效：" + str(row.id))
	for row: Dictionary in candidate.runtime.values():
		_check_paths(row.objects, {"crisis": row.crisis, "expiry_updates": row.expiry_updates}, str(row.id))
	for row: Dictionary in candidate.response_contracts.values():
		if not candidate.runtime.has(row.case_id):
			errors.append("Unknown situation in contract: " + str(row.id)); continue
		var runtime: Dictionary = candidate.runtime[row.case_id]
		_check_paths(runtime.objects, row, str(row.id))
		var effects: Array = row.outcomes if row.disclosure == "unknown" else [row]
		if row.disclosure == "unknown" and row.miracle != {}:
			errors.append("Hidden prayer witnesses belong to its selected outcome: " + str(row.id))
		for effect: Dictionary in effects:
			_check_miracle(effect, int(runtime.people), str(row.id))
			_check_consequence(effect, effect, int(runtime.people), str(row.id))
			for step: Dictionary in effect.followup:
				_check_consequence(step, effect, int(runtime.people), str(row.id))
				if step.has("miracle"):
					_check_miracle(step, int(runtime.people), str(row.id))
					if not step.get("effect") is String or step.effect.strip_edges().is_empty():
						errors.append("Delayed manifestation needs a visible result: " + str(row.id))
	if not errors.is_empty(): return false
	tables = candidate
	version = digest.sha256_text()
	return true

func parameter(id: String) -> int:
	return int(tables.parameters[id].value)

func _check_consequence(effect: Dictionary, origin: Dictionary, people: int, label: String) -> void:
	var rule: Variant = effect.get("consequence", {})
	if rule == {}: return
	var roles := ["petitioner", "other", "third"].slice(0, people)
	if not rule is Dictionary or rule.size() != (7 if rule.has("altered") else 6) or not rule.get("kind") in ["account", "document", "evidence", "rescue"] or not rule.get("change") in effect.updates or not rule.get("person") in roles or not rule.get("title") is String or rule.title.strip_edges().is_empty():
		errors.append("Invalid prayer consequence: " + label); return
	if rule.has("altered") and (rule.kind != "rescue" or rule.altered != true):
		errors.append("Invalid surviving transformation: " + label)
	var event: Variant = rule.get("event")
	var witness: Variant = rule.get("witness")
	var actual: Array = origin.get("miracle", {}).get("witnesses", [])
	if (rule.kind == "rescue" and (event != "EVENT_01" or witness != rule.person or not witness in actual)) or (rule.kind == "evidence" and (event != "" or witness != rule.person or not witness in actual)) or (rule.kind in ["account", "document"] and not (event == "" or (rule.kind == "account" and event == "EVENT_02" and witness in roles))):
		errors.append("Invalid prayer consequence source or event: " + label)

func _check_miracle(effect: Dictionary, people: int, label: String) -> void:
	var witness: Variant = effect.get("miracle")
	if not witness is Dictionary:
		errors.append("Missing manifestation contract: " + label); return
	if witness.is_empty(): return
	if witness.size() != 2 or not witness.get("public") is bool or not witness.get("witnesses") is Array or effect.updates.is_empty():
		errors.append("Invalid manifestation contract: " + label); return
	var roles := ["petitioner", "other", "third"].slice(0, people)
	var seen := {}
	for role: Variant in witness.witnesses:
		if not role in roles or seen.has(role):
			errors.append("Invalid manifestation witness: " + label); return
		seen[role] = true

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
				if node != null and path != "$crisis.delay": _check_value(node, child[path], key in ["requires", "goal"], label + "/" + path)
		elif child is Dictionary: _check_paths(objects, child, label)
		elif child is Array:
			for item: Variant in child:
				if item is Dictionary: _check_paths(objects, item, label)

func _check_response(row: Dictionary) -> void:
	var label := str(row.id)
	_check_effect(row, label)
	if not row.outcomes is Array:
		errors.append("Prayer outcomes must be an array: " + label); return
	if not row.disclosure in ["clear", "unknown"]:
		errors.append("Invalid prayer disclosure: " + label); return
	if row.disclosure == "clear":
		if not row.outcomes.is_empty(): errors.append("Clear response cannot hide outcomes: " + label)
		return
	if row.outcomes.size() < 2 or row.outcomes.size() > 4 or row.omen.is_empty(): errors.append("Unknown response needs two through four alternatives and an omen: " + label)
	for field: String in ["updates", "goal", "followup", "maintenance"]:
		if not row[field].is_empty(): errors.append("Unknown response must place effects in its outcomes: " + label)
	var ids: Dictionary = {}
	var upkeep := -1
	var installments := -1
	for outcome: Variant in row.outcomes:
		if not outcome is Dictionary:
			errors.append("Malformed hidden outcome: " + label); continue
		var id: Variant = outcome.get("id")
		if not id is String or id.is_empty() or ids.has(id): errors.append("Invalid or duplicate hidden outcome: " + label)
		else: ids[id] = true
		if not outcome.get("weight") is int or int(outcome.weight) < 1: errors.append("Invalid hidden outcome weight: " + label)
		for field: String in ["effect", "tradeoff"]:
			if not outcome.get(field) is String or outcome[field].is_empty(): errors.append("Missing revealed outcome text: " + label + "/" + field)
		_check_effect(outcome, label + "/" + str(id))
		if outcome.get("maintenance") is Dictionary:
			var amount := int(outcome.maintenance.get("faith", 0))
			if upkeep >= 0 and upkeep != amount: errors.append("Hidden outcomes cannot change the quoted upkeep: " + label)
			var turns := int(outcome.maintenance.get("turns", 0))
			if amount > 0 and installments >= 0 and installments != turns: errors.append("Hidden outcomes cannot change the quoted installment count: " + label)
			upkeep = amount
			installments = turns

func _check_effect(value: Dictionary, label: String) -> void:
	for field: String in ["requires", "updates", "goal", "maintenance"]:
		if not value.get(field) is Dictionary: errors.append("Malformed effect dictionary: " + label + "/" + field)
	if not value.get("followup") is Array:
		errors.append("Malformed followup list: " + label); return
	for step: Variant in value.followup:
		if not step is Dictionary or not step.get("delay") is int or int(step.delay) < 1 or not step.get("requires") is Dictionary or not step.get("updates") is Dictionary:
			errors.append("Malformed scheduled effect: " + label)
	var maintenance: Variant = value.get("maintenance")
	if maintenance is Dictionary and not maintenance.is_empty():
		if not maintenance.get("turns") is int or int(maintenance.turns) < 1 or not maintenance.get("faith", 0) is int or int(maintenance.get("faith", 0)) < 0:
			errors.append("Malformed maintenance terms: " + label)
		for field: String in ["requires", "updates"]:
			if not maintenance.get(field) is Dictionary: errors.append("Malformed maintenance effect: " + label)

func _check_value(initial: Variant, value: Variant, predicate: bool, label: String) -> void:
	if value is Dictionary:
		var allowed: Array = ["gte", "lte", "eq", "ne"] if predicate else ["add"]
		if value.is_empty(): errors.append("Empty field operation: " + label)
		for operation: String in value:
			if not operation in allowed:
				errors.append("Unknown field operation: " + label); continue
			if operation in ["gte", "lte", "add"] and not (initial is int and value[operation] is int): errors.append("Numeric operation needs integers: " + label)
			elif operation in ["eq", "ne"] and typeof(initial) != typeof(value[operation]): errors.append("Predicate changes field type: " + label)
	elif typeof(initial) != typeof(value): errors.append("Effect changes field type: " + label)
