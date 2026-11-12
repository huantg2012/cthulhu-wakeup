extends RefCounted
## Turns authored component rows into the frozen writes understood by PrayerSpace.
const Store = preload("res://src/simulation/archive_store.gd")
const Voice = preload("res://src/presentation/prayer_response_voice.gd")
const Rules = preload("res://src/game/prayer_rules.gd")
const ATTRIBUTES := ["insight", "adaptation", "will", "influence"]
const CHECKS := ["occult", "social"]
const APPROACHES := ["mercy", "bargain", "coerce", "horror", "twist", "reveal"]
const COMPARISONS := ["eq", "ne", "gt", "gte", "lt", "lte"]
const ADAPTERS := ["situation", "clock", "maintenance", "capability", "miracle", "consequence", "followup"]
const Capabilities = preload("res://src/game/prayer_capabilities.gd")

var content: RefCounted

func _init(source: RefCounted) -> void:
	content = source

static func split(value: Variant) -> Array:
	if value is Array: return value
	if value is PackedStringArray: return Array(value)
	var result: Array = []
	for part: String in str(value).split("|", false):
		if not part.strip_edges().is_empty(): result.append(part.strip_edges())
	return result

static func resolve(value: Variant, context: Dictionary) -> Variant:
	if value is String:
		if value == "$role.neighbor": return context.get("neighbor")
		if value.begins_with("$role."): return context.roles.get(value.substr(6))
		if value.begins_with("$noun."): return context.nouns.get(value.substr(6))
		return value
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(resolve(item, context))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = resolve(value[key], context)
		return result
	return value

static func read_path(objects: Dictionary, path: String) -> Variant:
	var current: Variant = objects
	for part: String in path.split("."):
		if not current is Dictionary or not current.has(part): return null
		current = current[part]
	return current

static func _compare(actual: Variant, op: String, wanted: Variant) -> bool:
	if actual == null or wanted == null: return false
	if op == "eq": return actual == wanted
	if op == "ne": return actual != wanted
	if not (actual is int or actual is float) or not (wanted is int or wanted is float): return false
	match op:
		"gt": return actual > wanted
		"gte": return actual >= wanted
		"lt": return actual < wanted
		"lte": return actual <= wanted
	return false

static func matches(objects: Dictionary, requirements: Dictionary) -> bool:
	for path: String in requirements:
		var value: Variant = read_path(objects, path)
		var wanted: Variant = requirements[path]
		if wanted is Dictionary:
			for op: String in wanted:
				if not _compare(value, op, wanted[op]): return false
		elif not _compare(value, "eq", wanted): return false
	return true

static func valid_predicate(node: Variant, depth: int = 0) -> bool:
	if not node is Dictionary or depth > 8: return false
	if node.is_empty(): return true
	var op: Variant = node.get("op")
	if op in ["all", "any"]:
		var args: Variant = node.get("args")
		if not args is Array or args.is_empty() or args.size() > 16: return false
		for child: Variant in args:
			if not valid_predicate(child, depth + 1): return false
		return true
	if op == "not": return valid_predicate(node.get("arg"), depth + 1)
	if op in COMPARISONS: return node.get("path") is String and node.has("value")
	if op == "has_tag": return node.get("tag") is String
	if op == "exists_relation": return node.get("a") is String and node.get("b") is String and node.get("kinds", []) is Array
	if op == "knows": return node.get("actor") is String and node.get("fact") is String
	if op == "can_reach": return node.get("actor") is String and node.get("place") is String
	if op == "owns": return node.get("actor") is String and node.get("object") is String
	if op == "can_execute": return node.get("actor") is String and node.get("capability") is String
	return false

static func predicate(node: Dictionary, context: Dictionary) -> bool:
	if node.is_empty(): return true
	var op: String = node.op
	if op in ["all", "any"]:
		for child: Dictionary in node.args:
			var passed := predicate(child, context)
			if op == "all" and not passed: return false
			if op == "any" and passed: return true
		return op == "all"
	if op == "not": return not predicate(node.arg, context)
	if op in COMPARISONS: return _compare(read_path(context.objects, node.path), op, resolve(node.value, context))
	if op == "has_tag": return node.tag in context.tags
	var state: Dictionary = context.state
	var history: RefCounted = context.get("history")
	if op == "exists_relation":
		var a: Variant = resolve(node.a, context)
		var b: Variant = resolve(node.b, context)
		if not a is String or not b is String or a == b or history == null: return false
		for relation: Dictionary in history.relation_between(a, b, node.get("kinds", [])):
			if relation.direction == "mutual" or (relation.a == a and relation.b == b): return true
		return false
	var actor: Variant = resolve(node.actor, context)
	if not actor is String: return false
	var person: Dictionary = Store.entry(state.get("npcs", {}), actor, {})
	if person.get("status") != "active": return false
	match op:
		"knows":
			var fact: Variant = resolve(node.fact, context)
			return fact is String and history != null and history.knows(state, actor, fact)
		"can_reach":
			var place: Variant = resolve(node.place, context)
			if not place is String or place.is_empty(): return false
			if place == person.get("domain"): return true
			return place in state.get("domains", {}).get(person.get("domain"), {}).get("neighbors", [])
		"owns": return read_path(context.objects, node.object + ".owner") == actor
		"can_execute":
			if node.capability in ["can_act", "can_sleep"]:
				return Rules.space_allows(state, actor, node.capability)
			if node.capability == "record_practice":
				return not Capabilities.grant_source(state, actor, node.capability).is_empty() or "record_keeper" in person.get("role_tags", [])
			return node.capability == "office_holding" and Capabilities.allows(state, actor, node.capability)
	return false

static func valid_capability(contract: Dictionary, bound: bool) -> bool:
	return contract.is_empty() or Capabilities.valid_contract(contract, bound)

static func render(template: String, bindings: Dictionary) -> String:
	var result := template
	for key: String in bindings:
		result = result.replace("{" + key + "}", str(bindings[key]))
	return "" if result.contains("{") or result.contains("}") else result.strip_edges()

static func _write_shape(write: Variant) -> bool:
	if not write is Dictionary or not write.get("op") is String or not write.get("path") is String or not write.has("value"): return false
	if not write.op in ["set", "add", "link", "unlink", "schedule"]: return false
	if write.op == "schedule":
		return write.path == "$crisis.delay" and write.value is int and write.value > 0
	var parts: PackedStringArray = write.path.split(".")
	if parts.size() < 2 or parts[0].begins_with("$") or parts[-1] in ["role", "name", "id"]: return false
	for part: String in parts:
		if part.is_empty() or not part.is_valid_identifier(): return false
	return true

static func translate_writes(objects: Dictionary, writes: Array, context: Dictionary) -> Dictionary:
	var updates: Dictionary = {}
	var changed := false
	for write: Variant in writes:
		if not _write_shape(write) or updates.has(write.path): return {}
		var value: Variant = resolve(write.value, context)
		if write.op == "schedule":
			updates[write.path] = value
			changed = true
			continue
		var initial: Variant = read_path(objects, write.path)
		if initial == null or value == null: return {}
		match str(write.op):
			"set":
				if typeof(initial) != typeof(value): return {}
				updates[write.path] = value
				changed = changed or initial != value
			"add":
				if not initial is int or not value is int or initial + value < 0: return {}
				updates[write.path] = {"add": value}
				changed = changed or value != 0
			"link", "unlink":
				if not initial is bool or not value is bool or value != (write.op == "link"): return {}
				updates[write.path] = value
				changed = changed or initial != value
	return updates if changed else {}

static func valid_writes(writes: Variant) -> bool:
	if not writes is Array or writes.is_empty(): return false
	var paths: Dictionary = {}
	for write: Variant in writes:
		if not _write_shape(write) or paths.has(write.path): return false
		paths[write.path] = true
	return true

static func render_language(row: Dictionary, context: Dictionary, bindings: Dictionary) -> String:
	if row.is_empty(): return ""
	for field: String in row.required_slots:
		if str(bindings.get(field, "")).is_empty(): return ""
	for tag: String in split(row.get("forbidden_tags", "")):
		if tag in context.tags: return ""
	if not predicate(row.required_facts, context): return ""
	return render(row.text, bindings)

func parameter(key: String) -> int:
	return int(content.generator_tables.parameters[key].value)

static func valid_dimensions(dimensions: Dictionary) -> bool:
	for key: String in dimensions:
		if key == "subjects":
			if not dimensions[key] is Array or dimensions[key].is_empty(): return false
			for role: Variant in dimensions[key]:
				if not role is String or not role.is_valid_identifier(): return false
		elif key in ["public", "secrecy", "persistence", "resistance", "help"]:
			var limit := 1 if key in ["public", "secrecy"] else 2
			if not dimensions[key] is int or dimensions[key] < 0 or dimensions[key] > limit: return false
		else: return false
	return int(dimensions.get("public", 0)) + int(dimensions.get("secrecy", 0)) <= 1

func quote(profile: Dictionary, dimensions: Dictionary, roles: Dictionary) -> Dictionary:
	var people: Array = []
	for role: String in dimensions.get("subjects", ["subject"]):
		var person: Variant = roles.get(role)
		if not person is String or person in people: return {}
		people.append(person)
	var scale := ceili(float(maxi(0, people.size() - 1)) / parameter("scale_group_size"))
	var persistence: int = dimensions.get("persistence", profile.base_persistence)
	var public: int = dimensions.get("public", 0)
	var secret: int = dimensions.get("secrecy", 0)
	var resist: int = dimensions.get("resistance", 0)
	var help: int = dimensions.get("help", 0)
	if scale > parameter("scale_max") or scale < int(profile.base_scale) or persistence < int(profile.base_persistence) or persistence > 2 or public + secret > 1: return {}
	var ds := scale - int(profile.base_scale)
	var dp := persistence - int(profile.base_persistence)
	var difficulty := int(profile.base_difficulty) + parameter("scale_difficulty") * ds + parameter("persistence_difficulty") * dp
	difficulty += parameter("secrecy_difficulty") * secret + parameter("resistance_difficulty") * resist - parameter("precondition_help") * help
	return {
		"difficulty": clampi(difficulty, parameter("response_difficulty_min"), parameter("response_difficulty_max")),
		"faith": int(profile.faith) + parameter("scale_faith") * ds + parameter("persistence_faith") * dp,
		"whispers": int(profile.whispers),
		"pollution": int(profile.pollution) + parameter("scale_pollution") * ds + parameter("persistence_pollution") * dp,
		"alert": maxi(0, int(profile.alert) + parameter("public_alert") * public + parameter("scale_alert") * ds - parameter("secrecy_alert_reduction") * secret),
		"success_sanity": int(profile.success_sanity_loss), "disaster_sanity": int(profile.disaster_sanity_loss), "disaster_alert": int(profile.disaster_alert),
		"first_upkeep": int(profile.upkeep_faith), "duration": int(profile.upkeep_installments), "stop_rule": str(profile.upkeep_on_stop),
		"upkeep_turns": int(profile.upkeep_installments), "upkeep_stop": str(profile.get("upkeep_stop_text", "")),
		"persistence": persistence, "target_roles": dimensions.get("subjects", ["subject"]).duplicate(),
		"quote_inputs": {"scale": scale, "persistence": persistence, "public": public, "secrecy": secret, "resistance": resist, "help": help, "profile": profile.id},
	}

static func project_writes(objects: Dictionary, updates: Dictionary) -> Dictionary:
	var result := objects.duplicate(true)
	for path: String in updates:
		if path == "$crisis.delay": continue
		var parts := path.split(".")
		if parts.size() < 2: return {}
		var node := result
		for part: String in parts.slice(0, parts.size() - 1):
			if not node.get(part) is Dictionary: return {}
			node = node[part]
		var field: String = parts[-1]
		if not node.has(field): return {}
		var value: Variant = updates[path]
		if value is Dictionary and value.has("add"):
			if not node[field] is int or not value.add is int: return {}
			value = node[field] + value.add
			if value < 0: return {}
		if typeof(node[field]) != typeof(value): return {}
		node[field] = value
	return result

func compile(row: Dictionary, intent: Dictionary, context: Dictionary, bindings: Dictionary) -> Dictionary:
	var profile: Dictionary = content.generator_tables.tradeoffs[row.profile]
	if not profile.approach in split(intent.approaches) and str(row.get("hidden_only", "false")).to_lower() not in ["1", "true"]: return {}
	for tag: String in split(row.get("requires_tags", "")) + split(profile.requires_tags):
		if not tag in context.tags: return {}
	var requirements: Dictionary = resolve(row.requires, context)
	if not matches(context.objects, requirements) or not predicate(row.predicates, context): return {}
	var updates := translate_writes(context.objects, row.writes, context)
	if updates.is_empty(): return {}
	if updates.has("$crisis.delay") and int(context.get("crisis_due", -1)) < int(context.state.get("turn", 0)): return {}
	var terms := quote(profile, row.dimensions, context.roles)
	if terms.is_empty(): return {}
	var upkeep: Dictionary = resolve(row.upkeep, context)
	if int(terms.duration) > 0:
		if upkeep.is_empty(): return {}
		upkeep.merge({"faith": terms.first_upkeep, "turns": terms.duration}, true)
		var on_success := project_writes(context.objects, updates)
		if on_success.is_empty() or not matches(on_success, upkeep.requires) or project_writes(on_success, upkeep.updates).is_empty(): return {}
	elif not upkeep.is_empty(): return {}
	var capability: Dictionary = resolve(row.capability, context)
	if not capability.is_empty():
		var actor: Variant = context.roles.get(capability.get("role"))
		capability.erase("role")
		capability["person"] = actor
		if not valid_capability(capability, true): return {}
		if context.get("catalog") == null or not Capabilities.can_apply(context.state, capability, context.catalog): return {}
	var revealed := render_language(content.generator_tables.language[row.result_text_id], context, bindings)
	if revealed.is_empty(): return {}
	var miracle: Dictionary = row.miracle.duplicate(true)
	var actual_witnesses: Array = []
	for role: String in miracle.get("witnesses", []):
		var witness: Variant = resolve(role, context) if role.begins_with("$role.") else context.roles.get(role)
		if witness == null: return {}
		actual_witnesses.append(witness)
	if not miracle.is_empty(): miracle["witnesses"] = actual_witnesses
	var consequence: Dictionary = resolve(row.consequence, context)
	var outcome := {
		"id": row.id, "operator": row.operator, "requires": requirements, "updates": updates,
		"goal": resolve(row.goal if not row.goal.is_empty() else intent.goal, context),
		"followup": resolve(row.followup, context), "maintenance": upkeep,
		"disclosure": "clear", "outcomes": [], "effect": revealed, "tradeoff": "",
		"capability": capability, "miracle": miracle, "consequence": consequence,
		"followup_intents": split(row.get("followup_intents", "")),
		"predicates": row.predicates.duplicate(true), "typed_writes": row.writes.duplicate(true),
		"metrics": terms.duplicate(true), "sanity_target": context.roles.get(row.get("sanity_role", "subject"), context.roles.subject),
	}
	terms.merge({
		"operator": row.operator, "cost": profile.id, "approach": profile.approach, "intensity": int(row.get("intensity", 0)),
		"attribute": row.attribute, "check_kind": row.check_kind, "effect": revealed, "tradeoff": "",
		"irreversible": int(terms.persistence) == 2, "disclosure": "clear", "disaster": "此次介入失控。",
	})
	return {"choice": terms, "contract": outcome}

func twist(row: Dictionary, parts: Dictionary) -> Dictionary:
	var effects: Array = split(row.effects)
	effects.sort()
	var alternatives: Array = []
	var choice: Dictionary = {}
	var signatures: Dictionary = {}
	var sanity_target := ""
	var configured_weights := split(row.weight)
	var authored_ids := split(row.effects)
	for effect_id: String in effects:
		var part: Dictionary = parts.get(effect_id, {})
		if part.is_empty(): continue
		var terms: Dictionary = part.choice
		var effect: Dictionary = part.contract.duplicate(true)
		var terms_signature := [terms.faith, terms.whispers, terms.first_upkeep, terms.duration, terms.stop_rule, terms.attribute, terms.check_kind, terms.difficulty, effect.sanity_target]
		if choice.is_empty():
			choice = terms.duplicate(true)
			sanity_target = str(effect.sanity_target)
		elif terms_signature != [choice.faith, choice.whispers, choice.first_upkeep, choice.duration, choice.stop_rule, choice.attribute, choice.check_kind, choice.difficulty, sanity_target]: continue
		var key := JSON.stringify([effect.updates, effect.goal, effect.maintenance, effect.followup, effect.capability, effect.consequence], "", true)
		if signatures.has(key): continue
		signatures[key] = true
		effect["weight"] = int(configured_weights[0] if configured_weights.size() == 1 else configured_weights[authored_ids.find(effect_id)])
		alternatives.append(effect)
		for field: String in ["pollution", "alert", "success_sanity", "disaster_sanity", "disaster_alert"]:
			choice[field] = maxi(int(choice[field]), int(terms[field]))
		choice.irreversible = choice.irreversible or terms.irreversible
	if alternatives.size() < 2: return {}
	choice["approach"] = "twist"
	choice["operator"] = "twist"
	choice["effect"] = ""
	choice["tradeoff"] = ""
	choice["disclosure"] = "unknown"
	var contract := {"id": row.id, "concept": row.concept, "requires": {}, "updates": {}, "goal": {}, "followup": [], "maintenance": {},
		"miracle": {}, "consequence": {}, "disclosure": "unknown", "outcomes": alternatives, "capability": {}, "followup_intents": [], "sanity_target": sanity_target}
	return {"choice": choice, "contract": contract}

func band(field: String, value: int) -> int:
	if value == 0: return 0
	if value <= parameter("preview_" + field + "_low_max"): return 1
	if value <= parameter("preview_" + field + "_medium_max"): return 2
	return 3

func wording(choice: Dictionary, contract: Dictionary, title_key: String, variant: String) -> Dictionary:
	var display := Voice.wording(choice, title_key, variant)
	var hints: Array[String] = []
	var unknown: bool = choice.disclosure == "unknown"
	if unknown: hints.append("后果未知")
	var possible: String = "可能" if unknown else ""
	var success_sanity := int(choice.success_sanity)
	var pollution := band("pollution", int(choice.pollution))
	var alert := band("alert", int(choice.alert))
	if success_sanity > 0:
		var loss := band("sanity", success_sanity)
		hints.append("生效时%s%s" % [possible, "重创理智" if loss == 3 else "损失理智"])
	if success_sanity > 0 and alert == 0 and not unknown: hints.append("不增加察觉")
	elif pollution > 0: hints.append(possible + ["", "留下轻微污染", "增加污染", "带来重度污染"][pollution])
	if hints.size() < (3 if unknown else 2):
		if alert > 0: hints.append(possible + ["", "略露行迹", "容易暴露", "引来强烈察觉"][alert])
		elif int(choice.disaster_sanity) > 0: hints.append("失控会损伤理智")
	if int(choice.first_upkeep) > 0: hints.append("停止供奉会撤去效力")
	if not contract.get("capability", {}).is_empty() or (unknown and contract.outcomes.any(func(outcome: Dictionary) -> bool: return not outcome.get("capability", {}).is_empty())): hints.append(possible + "改变此人日后的职责")
	if hints.is_empty(): hints.append("不增加污染或察觉")
	return {"label": display.label, "hint": "，".join(hints) + "。"}
