extends RefCounted
## Bounded, read-only construction of shared situations and their requests.
const Store = preload("res://src/simulation/archive_store.gd")
const Compiler = preload("res://src/game/prayer_effect_compiler.gd")

var content: RefCounted
var catalog: RefCounted
var compiler: RefCounted
var version: String
var combinations: Dictionary = {}
var language: Dictionary = {}
var effect_ids: Array
var twist_ids: Array

func _init(source: RefCounted, full_catalog: RefCounted = null) -> void:
	content = source
	catalog = full_catalog
	version = source.generator_version
	compiler = Compiler.new(source)
	var tables: Dictionary = source.generator_tables
	effect_ids = _keys(tables.effects)
	twist_ids = _keys(tables.twists)
	for frame_id: String in _keys(tables.frames):
		var frame: Dictionary = tables.frames[frame_id]
		var tags := Compiler.split(frame.capability_tags)
		var compatible: Array = []
		for scene_id: String in _keys(tables.scenes):
			var scene: Dictionary = tables.scenes[scene_id]
			if not _all_tags(Compiler.split(scene.get("requires_tags", "")), tags): continue
			for intent_id: String in _keys(tables.intents):
				var intent: Dictionary = tables.intents[intent_id]
				if _intent_in_scene(intent, scene) and not _is_followup(intent):
					compatible.append({"frame": frame_id, "template": scene_id, "grammar": scene.get("grammar", scene_id), "intent": intent_id})
		for profile: String in Compiler.split(frame.profiles):
			if not combinations.has(profile): combinations[profile] = []
			combinations[profile].append_array(compatible)
	for id: String in _keys(tables.language):
		var row: Dictionary = tables.language[id]
		if not language.has(row.kind): language[row.kind] = []
		language[row.kind].append(row)

func parameter(key: String) -> int:
	return compiler.parameter(key)

static func _keys(values: Dictionary) -> Array:
	var keys: Array = values.keys()
	keys.sort()
	return keys

static func _all_tags(required: Array, tags: Array) -> bool:
	for tag: String in required:
		if not tag in tags: return false
	return true

static func _is_followup(intent: Dictionary) -> bool:
	return str(intent.get("followup_only", "")).to_lower() in ["true", "1"]

static func _intent_in_scene(intent: Dictionary, scene: Dictionary) -> bool:
	var scene_ids := Compiler.split(intent.get("scenes", ""))
	return intent.id in Compiler.split(scene.allowed_goals) and (scene.id in scene_ids or scene.get("grammar", scene.id) in scene_ids)

static func _random(seed: String, draw: int, salt: String) -> int:
	var bytes := (seed + "/prayer-generation/v2/" + str(draw) + "/" + salt).sha256_buffer()
	var value := 0
	for index: int in range(7): value = (value << 8) + int(bytes[index])
	return value

static func _signature(fields: Variant) -> String:
	return JSON.stringify(fields, "", true).sha256_text()

static func _root_key(domain: String, frame: String, template: String, subject: String) -> String:
	return "SITUATION-" + _signature([domain, frame, template, subject]).substr(0, 24)

static func _filters_match(plan: Dictionary, stance: String, filters: Dictionary) -> bool:
	for field: String in ["frame", "grammar"]:
		if not str(filters.get(field, "")).is_empty() and filters[field] != plan[field]: return false
	return str(filters.get("stance", "")).is_empty() or filters.stance == stance

func _plans(state: Dictionary, generation: Dictionary, filters: Dictionary, local: Dictionary) -> Array:
	var plans: Array = []
	var tables: Dictionary = content.generator_tables
	var focus := _keys(local)
	var only_root: String = str(filters.get("root", ""))
	for root_id: String in _keys(generation.get("situations", {})):
		var root: Dictionary = generation.situations[root_id]
		if not root.get("domain") in focus or root.get("status", "active") != "active": continue
		if not only_root.is_empty() and only_root != root_id and only_root != root.get("root_key"): continue
		var template: Dictionary = tables.scenes.get(root.get("template", root.grammar), {})
		if template.is_empty() or not tables.frames.has(root.frame) or local[root.domain].size() < template.role_slots.size(): continue
		for intent_id: String in Compiler.split(template.allowed_goals):
			var intent: Dictionary = tables.intents[intent_id]
			var opportunity: Dictionary = root.get("opportunity", {})
			if _is_followup(intent) and (opportunity.is_empty() or not intent_id in opportunity.eligible_intents or int(opportunity.depth) > parameter("situation_depth_limit")): continue
			var plan := {"frame": root.frame, "template": template.id, "grammar": root.grammar, "intent": intent_id, "domain": root.domain, "root": root_id}
			if _filters_match(plan, intent.stance, filters): plans.append(plan)
	if not only_root.is_empty(): return plans
	for domain: String in focus:
		for pattern: Dictionary in combinations.get(state.domains[domain].profile, []):
			if local[domain].size() < tables.scenes[pattern.template].role_slots.size(): continue
			if not _filters_match(pattern, tables.intents[pattern.intent].stance, filters): continue
			if int(generation.get("cooldowns", {}).get(domain + "/" + str(pattern.grammar), -1)) > int(state.turn): continue
			var plan := pattern.duplicate()
			plan["domain"] = domain
			plans.append(plan)
	return plans

static func _local_people(state: Dictionary, history: RefCounted) -> Dictionary:
	var local: Dictionary = {}
	for domain: String in state.get("simulation", {}).get("focused", []):
		if state.domains.has(domain): local[domain] = []
	if local.is_empty(): return local
	if history != null:
		for domain: String in local:
			local[domain] = history.ids("active/" + domain)
			local[domain].sort()
	else:
		for id: String in Store.keys(state.get("npcs", {})):
			var person: Dictionary = Store.entry(state.npcs, id, {})
			if person.get("status") == "active" and local.has(person.get("domain")):
				local[person.domain].append(id)
		for domain: String in local: local[domain].sort()
	return local

func _role_candidates(slot: Dictionary, frame_slot: Dictionary, roles: Dictionary, local: Array, state: Dictionary, history: RefCounted) -> Array:
	var result: Array = []
	var required_tags := Compiler.split(slot.get("requires_tags", [])) + Compiler.split(frame_slot.get("requires_tags", []))
	var distinct: Array = slot.get("distinct", [])
	var relation_to: String = str(slot.get("relation_to", frame_slot.get("relation_to", "")))
	var kinds: Array = Compiler.split(slot.get("kinds", frame_slot.get("kinds", [])))
	for id: String in local:
		var unique := true
		for key: String in distinct:
			if roles.get(key) == id:
				unique = false
				break
		if not unique: continue
		var person: Dictionary = Store.entry(state.npcs, id, {})
		if not _all_tags(required_tags, Compiler.split(person.get("role_tags", []))): continue
		if not relation_to.is_empty():
			var other: String = str(roles.get(relation_to, ""))
			if other.is_empty() or other == id or history == null or history.relation_between(other, id, kinds).is_empty(): continue
		result.append(id)
	return result

func _roles(frame: Dictionary, scene: Dictionary, intent: Dictionary, local: Array, state: Dictionary, history: RefCounted, seed: String, draw: int) -> Dictionary:
	var roles: Dictionary = {}
	var keys: Array = scene.role_slots.keys()
	keys.erase("subject")
	keys.push_front("subject")
	for role: String in keys:
		var options := _role_candidates(scene.role_slots[role], frame.get("roles", {}).get(role, {}), roles, local, state, history)
		if options.is_empty(): return {}
		roles[role] = options[_random(seed, draw, "role/" + role) % options.size()]
	if not roles.has(intent.role): return {}
	return roles

func _identity(frame: Dictionary, role: String, person: Dictionary) -> String:
	var contextual: String = str(frame.nouns.get("identity_" + role, ""))
	if not contextual.is_empty(): return contextual
	if catalog != null:
		var authored: String = str(catalog.display_tables.get("npc_profiles", {}).get(person.get("profile", ""), {}).get("name", ""))
		if not authored.is_empty(): return authored
	return str(frame.nouns.get("role_" + role, ""))

func _bindings(frame: Dictionary, roles: Dictionary, intent: Dictionary, state: Dictionary) -> Dictionary:
	var result: Dictionary = frame.nouns.duplicate()
	for role: String in roles:
		var person: Dictionary = Store.entry(state.npcs, roles[role], {})
		result[role] = _identity(frame, role, person)
	result["identity"] = result.get(intent.role, "")
	result["role_label"] = frame.nouns.get("role_" + str(intent.role), "")
	return result

func _line(kind: String, frame: String, grammar: String, intent: Dictionary, context: Dictionary, bindings: Dictionary, seed: String, draw: int) -> String:
	var lines: Array = []
	var total := 0
	for row: Dictionary in language.get(kind, []):
		if row.get("frame", "") not in ["", frame] or row.get("grammar", "") not in ["", grammar] or row.get("stance", "") not in ["", intent.stance] or row.get("register", "") not in ["", intent.register]: continue
		var text := Compiler.render_language(row, context, bindings)
		if text.is_empty(): continue
		var weight := maxi(1, int(row.get("weight", 1)))
		lines.append({"text": text, "weight": weight})
		total += weight
	if total == 0: return ""
	var point := _random(seed, draw, "text/" + kind) % total
	for line: Dictionary in lines:
		if point < line.weight: return line.text
		point -= line.weight
	return ""

func _options(plan: Dictionary, intent: Dictionary, context: Dictionary, bindings: Dictionary) -> Array:
	var results: Array = []
	var parts: Dictionary = {}
	var tried := 0
	for id: String in effect_ids:
		var row: Dictionary = content.generator_tables.effects[id]
		if not intent.id in Compiler.split(row.intents): continue
		var scenes := Compiler.split(row.get("scenes", ""))
		if not scenes.is_empty() and not plan.grammar in scenes and not plan.template in scenes: continue
		if tried >= parameter("response_attempt_limit"): break
		tried += 1
		var compiled: Dictionary = compiler.compile(row, intent, context, bindings)
		if compiled.is_empty(): continue
		parts[id] = compiled
		if compiled.choice.approach != "twist" and str(row.get("hidden_only", "false")).to_lower() not in ["1", "true"]: results.append(compiled)
	if "twist" in Compiler.split(intent.approaches):
		for id: String in twist_ids:
			var twist: Dictionary = content.generator_tables.twists[id]
			if not intent.id in Compiler.split(twist.compatible_goals): continue
			if tried >= parameter("response_attempt_limit"): break
			tried += 1
			var compiled: Dictionary = compiler.twist(twist, parts)
			if not compiled.is_empty(): results.append(compiled)
	return _distinct_options(results)

static func _effect_shape(contract: Dictionary) -> Array:
	var shape: Array = [contract.get("operator", ""), contract.updates, contract.goal, contract.get("capability", {}), contract.maintenance, contract.followup, contract.consequence, contract.get("followup_intents", [])]
	if contract.disclosure == "unknown":
		for outcome: Dictionary in contract.outcomes: shape.append(_effect_shape(outcome))
	return shape

static func _risk_vector(option: Dictionary) -> Array:
	var row: Dictionary = option.choice
	return [row.whispers, row.faith, row.first_upkeep, row.difficulty, row.pollution, row.alert, row.success_sanity, row.disaster_sanity, row.disaster_alert]

static func _dominates(a: Array, b: Array) -> bool:
	for i: int in a.size():
		if a[i] > b[i]: return false
	return true

func _distinct_options(results: Array) -> Array:
	var unique: Array = []
	for candidate: Dictionary in results:
		var key := _signature(_effect_shape(candidate.contract))
		var vector := _risk_vector(candidate)
		var dominated := false
		var removed: Array[int] = []
		for i: int in unique.size():
			if unique[i].key != key: continue
			var previous: Array = unique[i].risk
			if _dominates(previous, vector):
				dominated = true
				break
			if _dominates(vector, previous): removed.push_front(i)
		if dominated: continue
		for i: int in removed: unique.remove_at(i)
		unique.append({"key": key, "risk": vector, "value": candidate})
	return unique.map(func(item: Dictionary) -> Dictionary: return item.value)

func _axes(part: Dictionary) -> Array:
	var choice: Dictionary = part.choice
	var contract: Dictionary = part.contract
	var axes := ["approach/" + str(choice.approach), "effect/" + str(choice.operator), "persistence/" + str(choice.persistence)]
	if int(choice.first_upkeep) > 0: axes.append("commitment/upkeep")
	if int(choice.success_sanity) > 0: axes.append("harm/success_sanity")
	if int(choice.pollution) > 0: axes.append("pollution/" + str(compiler.band("pollution", int(choice.pollution))))
	if int(choice.alert) == 0: axes.append("exposure/covert")
	if not contract.get("capability", {}).is_empty(): axes.append("capability/change")
	if choice.disclosure == "unknown": axes.append("uncertainty/unknown")
	return axes

func _select_responses(parts: Array, affordable: Callable, seed: String, draw: int) -> Array:
	var selection: Array = []
	var limit: int = content.parameter("response_limit")
	var covered: Dictionary = {}
	var ranked: Array = []
	for part: Dictionary in parts:
		var axes := _axes(part)
		ranked.append({"part": part, "axes": axes, "rank": _random(seed, draw, "response/" + str(part.contract.id))})
	while not ranked.is_empty() and selection.size() < limit:
		var best := -1
		var best_score := -1
		var tie := -1
		for index: int in ranked.size():
			var item: Dictionary = ranked[index]
			if selection.is_empty() and not affordable.call(item.part): continue
			var score := 0
			for axis: String in item.axes:
				if covered.has(axis): continue
				# The distinct ways of paying or changing a person's role are
				# stronger distinctions than an additional harm severity band.
				score += 3 if axis.begins_with("commitment/") or axis.begins_with("capability/") or axis.begins_with("harm/") else 1
			if score > best_score or (score == best_score and int(item.rank) > tie):
				best = index
				best_score = score
				tie = item.rank
		if best < 0: break
		var picked: Dictionary = ranked.pop_at(best)
		for axis: String in picked.axes: covered[axis] = true
		selection.append(picked.part)
	selection.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_group := Compiler.APPROACHES.find(a.choice.approach)
		var b_group := Compiler.APPROACHES.find(b.choice.approach)
		return a_group < b_group if a_group != b_group else str(a.contract.id) < str(b.contract.id))
	return selection

func _option_shape(option: Dictionary, contract: Dictionary, roles: Dictionary) -> Array:
	var capability: Dictionary = contract.get("capability", {})
	var output: Array = [
		contract.get("operator", option.get("operator", "")), option.target_roles, option.persistence,
		capability.get("granted_tags", []), capability.get("blocked_tags", []),
		int(option.first_upkeep) > 0, compiler.band("pollution", int(option.pollution)),
		compiler.band("alert", int(option.alert)), compiler.band("sanity", int(option.success_sanity)),
		compiler.band("sanity", int(option.disaster_sanity)), contract.disclosure,
		_role_reference(contract.get("sanity_target", ""), roles),
		_goal_shape(contract.get("goal", {}), roles),
	]
	if contract.disclosure == "unknown":
		var branches: Array = []
		for effect: Dictionary in contract.outcomes: branches.append(_signature(_option_shape(effect.metrics, effect, roles)))
		branches.sort()
		output.append(branches)
	return output

static func _role_reference(id: String, roles: Dictionary) -> String:
	for role: String in _keys(roles):
		if role != "petitioner" and roles[role] == id: return role
	return id

static func _goal_shape(value: Variant, roles: Dictionary) -> Variant:
	if value is String: return _role_reference(value, roles)
	if value is Dictionary:
		var output: Dictionary = {}
		for key: String in value: output[key] = _goal_shape(value[key], roles)
		return output
	if value is Array: return value.map(func(item: Variant) -> Variant: return _goal_shape(item, roles))
	return value

func _context(state: Dictionary, history: RefCounted, plan: Dictionary, generation: Dictionary, local: Array, seed: String, draw: int) -> Dictionary:
	var tables: Dictionary = content.generator_tables
	var frame: Dictionary = tables.frames[plan.frame]
	var template: Dictionary = tables.scenes[plan.template]
	var intent: Dictionary = tables.intents[plan.intent]
	var root: Dictionary = generation.get("situations", {}).get(plan.get("root", ""), {})
	var roles: Dictionary = root.get("roles", {}).duplicate()
	if roles.is_empty(): roles = _roles(frame, template, intent, local, state, history, seed, draw)
	if roles.is_empty() or not roles.has(intent.role): return {}
	roles.erase("petitioner")
	for actor: String in roles.values():
		if not actor in local: return {}
	var root_key := _root_key(plan.domain, plan.frame, plan.template, roles.subject)
	if root.is_empty() and generation.get("situations", {}).has(root_key): return {}
	roles["petitioner"] = roles[intent.role]
	var person: String = roles.petitioner
	if not _is_followup(intent) and int(generation.get("people_cooldowns", {}).get(person, -1)) > int(state.turn): return {}
	var tags := Compiler.split(frame.capability_tags)
	var known_neighbors: Array = state.domains[plan.domain].get("neighbors", []).filter(
		func(id: String) -> bool: return id in state.get("simulation", {}).get("focused", []))
	known_neighbors.sort()
	var neighbor: String = str(root.get("neighbor", ""))
	if root.is_empty() and not known_neighbors.is_empty(): neighbor = known_neighbors[_random(seed, draw, "neighbor") % known_neighbors.size()]
	if not neighbor.is_empty() and not neighbor in known_neighbors: neighbor = ""
	var context := {"neighbor": neighbor, "roles": roles, "nouns": frame.nouns, "state": state, "catalog": catalog, "history": history, "tags": tags, "objects": {}}
	context["objects"] = root.objects if not root.is_empty() else Compiler.resolve(template.object_slots, context)
	if not Compiler.predicate(template.predicates, context): return {}
	if not Compiler.predicate(frame.get("predicates", {}), context): return {}
	var clock: Dictionary = root.get("crisis", {}) if not root.is_empty() else Compiler.resolve(template.clock, context)
	clock = clock.duplicate()
	clock.erase("request_turns")
	var crisis_due: int = root.get("crisis_due", -1) if not root.is_empty() else (int(state.turn) + int(clock.delay) - 1 if clock.has("delay") else -1)
	context["crisis_due"] = crisis_due
	context["crisis"] = clock
	context["root_key"] = root.get("root_key", root_key)
	context["root"] = root
	return context

static func _relation_tests(node: Dictionary, tests: Array) -> void:
	var op: String = str(node.get("op", ""))
	if op == "exists_relation":
		tests.append(node)
	elif op in ["all", "any"]:
		for child: Dictionary in node.args: _relation_tests(child, tests)
	elif op == "not":
		_relation_tests(node.arg, tests)

func _topology(frame: Dictionary, template: Dictionary, intent: Dictionary, context: Dictionary, parts: Array) -> Array:
	var history: RefCounted = context.history
	if history == null: return []
	# Count only ties that were actually relevant to binding, an intention
	# or a response. An incidental rival in the observer slot is not a new
	# kind of request unless an authored predicate can act on the rivalry.
	var tests: Array = []
	for root: Dictionary in [frame.predicates, template.predicates, intent.knowledge_predicates, intent.desire_predicates]:
		_relation_tests(root, tests)
	for role: String in template.role_slots:
		var slot: Dictionary = template.role_slots[role]
		var override: Dictionary = frame.roles.get(role, {})
		var other: String = str(slot.get("relation_to", override.get("relation_to", "")))
		if other.is_empty(): continue
		tests.append({"a": "$role." + other, "b": "$role." + role, "kinds": Compiler.split(slot.get("kinds", override.get("kinds", []))), "binding": true})
	for part: Dictionary in parts:
		var contract: Dictionary = part.contract
		var effects: Array = contract.outcomes if contract.disclosure == "unknown" else [contract]
		for effect: Dictionary in effects: _relation_tests(effect.get("predicates", {}), tests)
	var edges: Dictionary = {}
	for test: Dictionary in tests:
		var a: Variant = Compiler.resolve(test.a, context)
		var b: Variant = Compiler.resolve(test.b, context)
		if not a is String or not b is String or a == b: continue
		for edge: Dictionary in history.relation_between(a, b, test.get("kinds", [])):
			if edge.direction != "mutual" and not test.get("binding", false) and (edge.a != a or edge.b != b): continue
			var from_role: String = _role_reference(edge.a, context.roles)
			var to_role: String = _role_reference(edge.b, context.roles)
			if edge.direction == "mutual" and from_role > to_role:
				var previous := from_role
				from_role = to_role
				to_role = previous
			edges[JSON.stringify([from_role, to_role, edge.kind, edge.direction])] = true
	return _keys(edges)

func _candidate(state: Dictionary, history: RefCounted, plan: Dictionary, generation: Dictionary, local: Array, seed: String, draw: int) -> Dictionary:
	var tables: Dictionary = content.generator_tables
	var frame: Dictionary = tables.frames[plan.frame]
	var template: Dictionary = tables.scenes[plan.template]
	var intent: Dictionary = tables.intents[plan.intent]
	var context := _context(state, history, plan, generation, local, seed, draw)
	if context.is_empty(): return {"reject": "binding"}
	var goal: Dictionary = Compiler.resolve(intent.goal, context)
	if Compiler.matches(context.objects, goal) or not Compiler.matches(context.objects, Compiler.resolve(intent.requires, context)):
		return {"reject": "goal"}
	if not Compiler.predicate(intent.knowledge_predicates, context) or not Compiler.predicate(intent.desire_predicates, context):
		return {"reject": "stance"}
	var bindings := _bindings(frame, context.roles, intent, state)
	var parts := _options(plan, intent, context, bindings)
	if parts.is_empty(): return {"reject": "response"}
	var affordable := func(part: Dictionary) -> bool:
		return state.faith >= int(part.choice.faith) + int(part.choice.first_upkeep) and state.whispers >= int(part.choice.whispers)
	if not parts.any(affordable): return {"reject": "cost"}
	parts = _select_responses(parts, affordable, seed, draw)
	var title := _line("title", plan.frame, plan.grammar, intent, context, bindings, seed, draw)
	var appeal := _line("appeal", plan.frame, plan.grammar, intent, context, bindings, seed, draw)
	if title.is_empty() or appeal.is_empty(): return {"reject": "language"}
	var options: Dictionary = {}
	var contracts: Dictionary = {}
	var shapes: Array = []
	var content_key := "GEN2_" + str(plan.frame) + "_" + str(plan.grammar) + "_" + str(intent.id)
	for index: int in parts.size():
		var option: Dictionary = parts[index].choice
		var contract: Dictionary = parts[index].contract
		var key := "choice_" + String.chr(97 + index)
		option["id"] = key
		option.merge(compiler.wording(option, contract, content_key, key), true)
		options[key] = option
		contracts[key] = contract
		shapes.append(_signature(_option_shape(option, contract, context.roles)))
	shapes.sort()
	var topology := _topology(frame, template, intent, context, parts)
	var goal_shape: Variant = _goal_shape(goal, context.roles)
	var semantic := _signature([plan.frame, plan.grammar, intent.stance, goal_shape, _goal_shape(intent.requires, context.roles), topology, intent.get("belief", "")])
	var decision := _signature([goal_shape, shapes])
	var root: Dictionary = context.root
	var existing_id: String = str(plan.get("root", ""))
	var occurrence := str(root.get("root_key", context.root_key)) + "/" + str(context.roles.petitioner) + "/" + semantic
	if generation.get("used", {}).has(occurrence): return {"reject": "used"}
	var followup: Dictionary = root.get("opportunity", {}) if _is_followup(intent) else {}
	var urgent: bool = not root.is_empty() and context.crisis_due == int(state.turn) and not root.get("crisis_done", false)
	var actors: Array = [context.roles.petitioner]
	for role: String in _keys(context.roles):
		if not context.roles[role] in actors: actors.append(context.roles[role])
	var frozen_roles: Dictionary = context.roles.duplicate()
	frozen_roles.erase("petitioner")
	var meta := {"roles": frozen_roles, "expected_revision": int(root.get("revision", -1)), "frame": plan.frame, "grammar": plan.grammar, "template": plan.template, "intent": intent.id, "stance": intent.stance,
		"root_key": context.root_key, "situation_id": existing_id, "semantic_signature": semantic, "decision_signature": decision,
		"facts": root.get("facts", template.initial_facts).duplicate(true), "goal": goal, "neighbor": context.neighbor,
		"followup_source": str(followup.get("source", "")), "depth": int(followup.get("depth", root.get("depth", 0))),
		"urgent": urgent, "base_weight": maxi(1, int(frame.get("base_weight", 1))) * maxi(1, int(intent.get("weight", 1))),
	}
	var due := int(state.turn) + int(template.clock.request_turns) - 1
	return {
		"case_id": content_key, "domain": plan.domain, "actors": actors, "roles": context.roles,
		"created": int(state.turn), "due": due, "status": "open", "objects": context.objects.duplicate(true),
		"choices": options, "contracts": contracts, "crisis": context.crisis, "crisis_due": context.crisis_due,
		"crisis_done": root.get("crisis_done", false), "pending": [], "maintenance": {},
		"goal_reached": false, "title": title, "appeal": appeal, "context": "", "goal_text": "",
		"petitioner_role": str(bindings.identity), "expiry": "", "expiry_updates": {},
		"source": "", "generation_meta": meta,
	}

func _weights(candidates: Array, generation: Dictionary, turn: int) -> Array:
	var output: Array = []
	var by_world: Dictionary = {}
	var semantic: Dictionary = {}
	var decisions: Dictionary = {}
	var last: Dictionary = {}
	for item: Dictionary in generation.get("recent", []):
		if int(item.turn) + content.parameter("recent_memory") < turn: continue
		by_world[item.domain] = int(by_world.get(item.domain, 0)) + 1
		semantic[item.semantic_signature] = int(semantic.get(item.semantic_signature, 0)) + 1
		decisions[item.decision_signature] = int(decisions.get(item.decision_signature, 0)) + 1
		last[item.decision_signature] = maxi(int(last.get(item.decision_signature, -999)), int(item.turn))
	var minimum := 2147483647
	for item: Dictionary in candidates:
		minimum = mini(minimum, int(by_world.get(item.domain, 0)))
	for item: Dictionary in candidates:
		var meta: Dictionary = item.generation_meta
		var n_s: int = int(semantic.get(meta.semantic_signature, 0))
		var n_d: int = int(decisions.get(meta.decision_signature, 0))
		if not meta.urgent and meta.followup_source.is_empty() and turn - int(last.get(meta.decision_signature, -999)) <= parameter("exact_repeat_window"): continue
		var novel_den := 1 + n_s + n_d
		var balance_den := 1 + maxi(0, int(by_world.get(item.domain, 0)) - minimum)
		var numerator: int = 1000 * int(meta.base_weight) * (novel_den + parameter("novelty_weight")) * (balance_den + parameter("world_balance_weight"))
		if meta.urgent: numerator *= content.parameter("urgent_weight")
		if not meta.followup_source.is_empty(): numerator *= 1 + parameter("followup_weight")
		var denominator := novel_den * balance_den * (1 + parameter("repeat_divisor") * n_d)
		@warning_ignore("integer_division")
		meta["weight"] = maxi(1, numerator / denominator)
		output.append(item)
	return output

func propose(state: Dictionary, generation: Dictionary, filters: Dictionary = {}, history: RefCounted = null) -> Dictionary:
	var local := _local_people(state, history)
	var plans := _plans(state, generation, filters, local)
	var draw := int(generation.get("draw", 0))
	var seed := str(filters.get("seed", generation.get("rng_seed", "0")))
	var result := {"candidates": [], "draw": draw, "attempts": 0, "rejected": {}}
	if plans.is_empty(): return result
	var limit := mini(parameter("candidate_attempt_limit"), maxi(0, int(filters.get("attempt_limit", parameter("candidate_attempt_limit")))))
	var offset := _random(seed, draw, "plan/page") % plans.size()
	var duplicates: Dictionary = {}
	var tried_roots: Dictionary = {}
	var fixed_root := not str(filters.get("root", "")).is_empty()
	if fixed_root: limit = mini(limit, plans.size())
	var candidates: Array = []
	for attempt: int in limit:
		var position := (offset + attempt) % plans.size()
		var plan: Dictionary = plans[position]
		if plan.has("root"):
			if tried_roots.has(position): continue
			tried_roots[position] = true
		var candidate := _candidate(state, history, plan, generation, local.get(plan.domain, []), seed, draw)
		draw += 1
		result.attempts += 1
		if candidate.has("reject"):
			var reason: String = candidate.reject
			result.rejected[reason] = int(result.rejected.get(reason, 0)) + 1
			continue
		var key: String = str(candidate.generation_meta.root_key) + "/" + str(candidate.roles.petitioner) + "/" + str(candidate.generation_meta.semantic_signature)
		if duplicates.has(key):
			result.rejected["duplicate"] = int(result.rejected.get("duplicate", 0)) + 1
			continue
		duplicates[key] = true
		candidates.append(candidate)
		if candidates.size() >= content.parameter("candidate_budget"): break
	result["candidates"] = _weights(candidates, generation, int(state.turn))
	var repeats: int = candidates.size() - result.candidates.size()
	if repeats > 0: result.rejected["recent_repeat"] = repeats
	result["draw"] = draw
	return result

func pick(candidates: Array, seed: String, draw: int) -> int:
	var total := 0
	for item: Dictionary in candidates: total += int(item.generation_meta.get("weight", 1))
	if total <= 0: return -1
	var point := _random(seed, draw, "publish") % total
	for index: int in candidates.size():
		var weight := int(candidates[index].generation_meta.get("weight", 1))
		if point < weight: return index
		point -= weight
	return -1
