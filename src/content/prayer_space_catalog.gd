extends RefCounted
## Authored prayer-space content, independent of the legacy save policy hashes.
const FILES := ["cases", "costs", "frames", "operators", "parameters", "scenes", "runtime", "response_contracts"]
const Compiler = preload("res://src/game/prayer_effect_compiler.gd")
const GENERATOR_FILES := ["parameters", "tradeoffs", "frames", "scenes", "intents", "effects", "twists", "language"]
const GENERATOR_JSON := {
	"frames": {"nouns": {}, "roles": {}, "predicates": {}},
	"scenes": {"role_slots": {}, "object_slots": {}, "predicates": {}, "initial_facts": {}, "clock": {}, "allowed_goals": []},
	"intents": {"goal": {}, "requires": {}, "knowledge_predicates": {}, "desire_predicates": {}},
	"effects": {"requires": {}, "predicates": {}, "writes": [], "goal": {}, "followup": [], "upkeep": {},
		"capability": {}, "miracle": {}, "consequence": {}, "dimensions": {}},
	"language": {"required_slots": [], "required_facts": {}},
}
const REQUIRED_GENERATOR_PARAMETERS := [
	"schema", "candidate_attempt_limit", "response_attempt_limit", "background_commit_limit",
	"situation_depth_limit", "exact_repeat_window", "novelty_weight", "world_balance_weight", "followup_weight",
	"repeat_divisor", "scale_group_size", "scale_max", "scale_difficulty", "persistence_difficulty",
	"secrecy_difficulty", "resistance_difficulty", "precondition_help", "response_difficulty_min",
	"response_difficulty_max", "scale_faith", "persistence_faith", "scale_pollution", "persistence_pollution",
	"public_alert", "scale_alert", "secrecy_alert_reduction", "preview_pollution_low_max",
	"preview_pollution_medium_max", "preview_alert_low_max", "preview_alert_medium_max", "preview_sanity_low_max",
	"preview_sanity_medium_max", "capacity_attempt_limit", "capacity_situation_target", "capacity_decision_target",
]
var tables: Dictionary = {}
var generator_tables: Dictionary = {}
var generator_version := ""
var errors: Array[String] = []
var version: String = ""

func load_files(directory: String = "res://data") -> bool:
	errors.clear()
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
	var generator := _load_generator(directory, candidate)
	if not errors.is_empty(): return false
	tables = candidate
	version = digest.sha256_text()
	generator_tables = generator.tables
	generator_version = generator.version
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

func _load_generator(directory: String, legacy: Dictionary) -> Dictionary:
	var candidate: Dictionary = {}
	var digest := "prayer-generation/v2\n" + JSON.stringify(legacy.parameters, "", true) + "\n"
	digest += FileAccess.get_file_as_string(directory.path_join("prayer_response_voice.csv"))
	for table: String in GENERATOR_FILES:
		var file := FileAccess.open(directory.path_join("prayer_generator_" + table + ".csv"), FileAccess.READ)
		if file == null:
			errors.append("Missing prayer generator table: " + table)
			continue
		digest += table + "\n" + file.get_as_text()
		file.seek(0)
		var headers := file.get_csv_line()
		var rows: Dictionary = {}
		while not file.eof_reached():
			var cells := file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty(): continue
			if cells.size() != headers.size() or cells[0].is_empty() or rows.has(cells[0]):
				errors.append("Invalid prayer generator row: " + table)
				continue
			var row: Dictionary = {}
			for index: int in headers.size(): row[headers[index]] = cells[index]
			for field: String in GENERATOR_JSON.get(table, {}):
				var fallback: Variant = GENERATOR_JSON[table][field]
				var raw := str(row.get(field, ""))
				var value: Variant = fallback.duplicate(true) if raw.is_empty() else _numbers(JSON.parse_string(raw))
				if typeof(value) != typeof(fallback):
					errors.append("Invalid prayer generator JSON: " + str(row.get("id", "")) + "/" + field)
				row[field] = value
			rows[cells[0]] = row
		candidate[table] = rows
		if rows.is_empty(): errors.append("Empty prayer generator table: " + table)
	if not errors.is_empty(): return {}
	_validate_generator(candidate, legacy)
	if not errors.is_empty(): return {}
	_check_generator_bindings(candidate)
	return {"tables": candidate, "version": digest.sha256_text()}

func _validate_generator(t: Dictionary, legacy: Dictionary) -> void:
	for key: String in REQUIRED_GENERATOR_PARAMETERS:
		var raw := str(t.parameters.get(key, {}).get("value", ""))
		if not raw.is_valid_int() or (key != "response_difficulty_min" and int(raw) < 0):
			errors.append("Invalid generator parameter: " + key)
	if not errors.is_empty(): return
	if int(t.parameters.schema.value) != 2:
		errors.append("Invalid prayer generator schema")
	for key: String in ["candidate_attempt_limit", "response_attempt_limit", "scale_group_size", "capacity_attempt_limit"]:
		if int(t.parameters[key].value) < 1: errors.append("Generator budget must be positive: " + key)
	for row: Dictionary in t.tradeoffs.values():
		if not row.get("approach") in Compiler.APPROACHES: errors.append("Invalid generator approach: " + str(row.id))
		for key: String in ["base_scale", "base_persistence", "base_difficulty", "whispers", "faith", "pollution", "alert", "success_sanity_loss", "disaster_sanity_loss", "disaster_alert", "upkeep_faith", "upkeep_installments"]:
			var raw := str(row.get(key, ""))
			if not raw.is_valid_int() or (key != "base_difficulty" and int(raw) < 0): errors.append("Invalid response tradeoff: " + row.id + "/" + key)
			else: row[key] = int(raw)
		if int(row.get("base_persistence", 0)) > 2 or int(row.get("base_scale", 0)) > int(t.parameters.scale_max.value):
			errors.append("Unrepresentable response scale or permanence: " + row.id)
		if (int(row.get("upkeep_installments", 0)) > 0) != (int(row.get("upkeep_faith", 0)) > 0):
			errors.append("Incomplete upkeep quote: " + row.id)
	for row: Dictionary in t.frames.values():
		if not legacy.frames.has(row.id) or row.nouns.is_empty() or Compiler.split(row.get("profiles", "")).is_empty() or not Compiler.valid_predicate(row.predicates):
			errors.append("Invalid generator frame: " + str(row.id))
		for noun: Variant in row.nouns.values():
			if not noun is String or noun.strip_edges().is_empty(): errors.append("Invalid generator noun: " + row.id)
	for row: Dictionary in t.scenes.values():
		var grammar: String = row.get("grammar", row.id)
		if not legacy.scenes.has(grammar) or not row.role_slots.has("subject") or row.object_slots.is_empty() or not Compiler.valid_predicate(row.predicates):
			errors.append("Invalid generator scene: " + str(row.id))
		for role: Variant in row.role_slots.values():
			if not role is Dictionary or role.get("type") != "person": errors.append("Invalid generated role slot: " + row.id)
		if not row.clock.get("request_turns") is int or row.clock.request_turns < 1:
			errors.append("Invalid request clock: " + row.id)
		if row.clock.has("delay") and (not row.clock.delay is int or row.clock.delay < 1):
			errors.append("Invalid crisis clock: " + row.id)
	for row: Dictionary in t.intents.values():
		if row.goal.is_empty() or not row.has("role") or str(row.get("stance", "")).is_empty() or not Compiler.valid_predicate(row.knowledge_predicates) or not Compiler.valid_predicate(row.desire_predicates):
			errors.append("Invalid generator intent: " + str(row.id))
		for scene: String in Compiler.split(row.get("scenes", "")):
			if not _generator_has_scene(t.scenes, scene): errors.append("Unknown intent scene: " + row.id + "/" + scene)
		for approach: String in Compiler.split(row.get("approaches", "")):
			if not approach in Compiler.APPROACHES: errors.append("Unknown intent approach: " + row.id + "/" + approach)
	for row: Dictionary in t.language.values():
		if not row.get("kind") in ["title", "appeal", "result", "label"] or str(row.get("text", "")).strip_edges().is_empty() or not Compiler.valid_predicate(row.required_facts):
			errors.append("Invalid generated language: " + row.id)
		if not str(row.get("frame", "")).is_empty() and not t.frames.has(row.frame): errors.append("Unknown language frame: " + row.id)
	for row: Dictionary in t.effects.values():
		if not legacy.operators.has(row.get("operator")) or not t.tradeoffs.has(row.get("profile")) or not Compiler.valid_writes(row.writes) or not Compiler.valid_predicate(row.predicates) or not Compiler.valid_dimensions(row.dimensions):
			errors.append("Invalid executable generator effect: " + row.id)
		if not row.get("attribute") in Compiler.ATTRIBUTES or not row.get("check_kind") in Compiler.CHECKS: errors.append("Invalid generated check: " + row.id)
		if t.language.get(row.get("result_text_id"), {}).get("kind") != "result": errors.append("Missing generated result text: " + row.id)
		if not Compiler.valid_capability(row.capability, false): errors.append("Unregistered capability consumers: " + row.id)
		for intent: String in Compiler.split(row.get("intents", "")) + Compiler.split(row.get("followup_intents", "")):
			if not t.intents.has(intent): errors.append("Unknown effect intent: " + row.id + "/" + intent)
		for scene: String in Compiler.split(row.get("scenes", "")):
			if not _generator_has_scene(t.scenes, scene): errors.append("Unknown effect scene: " + row.id + "/" + scene)
		for adapter: String in Compiler.split(row.get("consumer_ids", "")):
			if not adapter in Compiler.ADAPTERS: errors.append("Unknown generator consumer: " + row.id + "/" + adapter)
		_check_effect({"requires": row.requires, "updates": {}, "goal": row.goal, "followup": row.followup, "maintenance": {}}, row.id)
		if not row.upkeep.is_empty():
			var profile: Dictionary = t.tradeoffs.get(row.get("profile"), {})
			var upkeep: Dictionary = row.upkeep.duplicate()
			upkeep.merge({"faith": profile.get("upkeep_faith", 0), "turns": profile.get("upkeep_installments", 0)}, true)
			_check_effect({"requires": {}, "updates": {}, "goal": {}, "followup": [], "maintenance": upkeep}, row.id)
	for row: Dictionary in t.twists.values():
		var ids := Compiler.split(row.get("effects", ""))
		var weights := Compiler.split(row.get("weight", ""))
		if ids.size() < 2 or ids.size() > 4 or not weights.size() in [1, ids.size()] or str(row.get("concept", "")).is_empty():
			errors.append("Invalid twist generator: " + row.id)
		for id: String in ids:
			if not t.effects.has(id): errors.append("Unknown twist effect: " + row.id + "/" + id)
		for weight: String in weights:
			if not weight.is_valid_int() or int(weight) < 1: errors.append("Invalid twist branch weight: " + row.id)
		for intent: String in Compiler.split(row.get("compatible_goals", "")):
			if not t.intents.has(intent): errors.append("Unknown twist goal: " + row.id + "/" + intent)

func _generator_has_scene(rows: Dictionary, id: String) -> bool:
	if rows.has(id): return true
	return rows.values().any(func(row: Dictionary) -> bool: return row.get("grammar", row.id) == id)

func _check_generator_bindings(tables: Dictionary) -> void:
	for scene: Dictionary in tables.scenes.values():
		var roles: Dictionary = {}
		for role: String in scene.role_slots: roles[role] = "$role." + role
		roles["petitioner"] = "$role.petitioner"
		for intent: String in Compiler.split(scene.allowed_goals):
			if not tables.intents.has(intent):
				errors.append("Unknown allowed generator intent: " + scene.id + "/" + intent)
				continue
			var row: Dictionary = tables.intents[intent]
			if not roles.has(row.role): errors.append("Missing prayer intent actor: " + scene.id + "/" + intent)
			_check_paths(scene.object_slots, {"goal": row.goal, "requires": row.requires}, scene.id + "/" + intent)
		_check_paths(scene.object_slots, scene.clock, scene.id + "/clock")
		for effect: Dictionary in tables.effects.values():
			var scenes := Compiler.split(effect.scenes)
			if not scenes.is_empty() and not scene.id in scenes and not scene.get("grammar", scene.id) in scenes: continue
			var applicable := false
			for intent: String in Compiler.split(effect.intents):
				if intent in Compiler.split(scene.allowed_goals):
					applicable = true
					break
			if not applicable: continue
			var updates: Dictionary = {}
			for write: Dictionary in effect.writes:
				updates[write.path] = {"add": write.value} if write.op == "add" else write.value
			_check_paths(scene.object_slots, {"requires": effect.requires, "goal": effect.goal, "updates": updates, "followup": effect.followup, "maintenance": effect.upkeep}, effect.id)
			var required_adapters: Array = ["situation"]
			for pair: Array in [["clock", effect.followup], ["maintenance", effect.upkeep], ["miracle", effect.miracle], ["consequence", effect.consequence], ["capability", effect.capability]]:
				if not pair[1].is_empty(): required_adapters.append(pair[0])
			if not str(effect.get("followup_intents", "")).is_empty(): required_adapters.append("followup")
			for adapter: String in required_adapters:
				if not adapter in Compiler.split(effect.consumer_ids): errors.append("Undeclared effect consumer: " + effect.id + "/" + adapter)
			for role: String in effect.miracle.get("witnesses", []) + effect.dimensions.get("subjects", []) + ([] if effect.capability.is_empty() else [effect.capability.role]):
				if not roles.has(role.trim_prefix("$role.")): errors.append("Unbound effect role: " + effect.id + "/" + role)
			_check_generator_consequence(effect.consequence, updates, roles, effect.miracle, effect.id)
			for step: Dictionary in effect.followup:
				_check_generator_consequence(step.get("consequence", {}), step.updates, roles, effect.miracle, effect.id)

func _check_generator_consequence(rule: Dictionary, updates: Dictionary, roles: Dictionary, miracle: Dictionary, label: String) -> void:
	if rule.is_empty(): return
	var person: String = str(rule.get("person", "")).trim_prefix("$role.")
	var witness: String = str(rule.get("witness", "")).trim_prefix("$role.")
	if not rule.get("kind") in ["account", "document", "evidence", "rescue"] or not updates.has(rule.get("change", "")) or not roles.has(person) or str(rule.get("title", "")).is_empty():
		errors.append("Invalid generated consequence: " + label)
		return
	var event: String = str(rule.get("event", ""))
	if not event.is_empty() and not ((event == "EVENT_01" and rule.kind == "rescue") or (event == "EVENT_02" and rule.kind == "account" and roles.has(witness))):
		errors.append("Generated consequence has no corresponding event consumer: " + label)
	if rule.kind in ["rescue", "evidence"]:
		var known: Array = miracle.get("witnesses", [])
		if witness != person or (not witness in known and not ("$role." + witness) in known):
			errors.append("Generated consequence has no actual witness: " + label)
