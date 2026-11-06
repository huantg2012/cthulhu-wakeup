extends RefCounted
## Incremental existential query over the original finite selectors and admission.
## A positive result always carries a fully validated completion. Pending is not
## rejection. Callers must close cancelled jobs and revalidate before execution.
const Eligibility = preload("res://src/game/opportunity_eligibility.gd")
const Selectors = preload("res://src/game/entry_selectors.gd")
var view: Dictionary
var knowledge: Dictionary
var modules: Dictionary
var entry: String
var stack: Array = []
var result: Dictionary = {}
var last_error := "当前没有符合条件的组合"
var queries := 0
var closed := false
var actor_scope: Array = []

func _init(session: RefCounted, key: String, selection: Dictionary, allowed_actors: Array = []) -> void:
	actor_scope = allowed_actors
	entry = key
	view = session.turn._read_view(Eligibility.participant(key), session.turn.context.phase)
	knowledge = session.knowledge_snapshot()
	modules = session.modules
	stack.append({"selection":selection.duplicate(true), "decided":selection.keys()})

func close() -> void:
	if closed: return
	closed = true
	view.reader.close()
	stack.clear()

func step(budget_usec: int = 4000) -> bool:
	if closed: return true
	var until: int = Time.get_ticks_usec() + budget_usec
	while not stack.is_empty():
		var frame: Dictionary = stack.back()
		if frame.has("field"):
			var next: Dictionary = _next(frame)
			if not next.exists: stack.pop_back()
			else:
				var chosen: Dictionary = frame.selection.duplicate(true)
				if next.value != null: chosen[frame.field.key] = next.value
				var decided: Array = frame.decided.duplicate()
				decided.append(frame.field.key)
				stack.append({"selection":chosen, "decided":decided})
		else:
			stack.pop_back()
			_expand(frame)
		if not result.is_empty(): close(); return true
		if Time.get_ticks_usec() >= until: return false
	result = {"ok":false, "error":last_error, "queries":queries}
	close()
	return true

func _expand(frame: Dictionary) -> void:
	var chosen: Dictionary = frame.selection
	var resolved: Dictionary = Selectors.fields(Selectors.context(view, knowledge, modules), entry, chosen)
	if not resolved.get("ok", false): last_error = str(resolved.get("error", last_error)); return
	var fields: Array = resolved.fields
	# Validate the known prefix before consulting private rule predicates. A
	# supplied later value must never disclose an unknown object's condition.
	var safe: Dictionary = {}
	var safe_decided: Array = []
	for field: Dictionary in fields:
		if not field.key in frame.decided:
			if not field.optional: break
			continue
		if not chosen.has(field.key): safe_decided.append(field.key); continue
		var values: Array = chosen[field.key] if field.multiple else [chosen[field.key]]
		if values.any(func(value: Variant) -> bool: return not field.options.any(func(option: Dictionary) -> bool: return typeof(option.id) == typeof(value) and option.id == value)):
			last_error = "当前没有符合条件的" + str(field.label); return
		safe[field.key] = chosen[field.key]
		safe_decided.append(field.key)
	# This is the same predicate invoked by execution, with absent inputs deferred.
	if entry == "route/context" and safe.has("operation"):
		var payload: Dictionary = safe.duplicate(true)
		payload.erase("domain"); payload.erase("operation")
		var prefix: Dictionary = modules.progression_routes.prepare(view, safe.operation, payload, true, safe_decided)
		if not prefix.get("ok", false): last_error = str(prefix.error); return
	if entry.begins_with("POWER_") and entry != "POWER_APPOINT":
		var prefix: Dictionary = modules.powers.prepare(view, entry, safe, true)
		if not prefix.get("ok", false): last_error = str(prefix.error); return
	if entry.begins_with("relic/"):
		var state: Dictionary = modules.relics._hydrate(view, safe)
		var prefix: Dictionary = modules.relics.preview(state, entry.get_slice("/", 1), safe, int(view.turn.whispers_budget), true, true)
		if not prefix.get("ok", false): last_error = str(prefix.get("error", "圣物的当前状态不支持此操作")); return
	for field: Dictionary in fields:
		if field.key == "npc" and not actor_scope.is_empty(): field.options = field.options.filter(func(option: Dictionary) -> bool: return option.id in actor_scope)
		if field.key in frame.decided:
			if not chosen.has(field.key): continue
			var values: Array = chosen[field.key] if field.multiple else [chosen[field.key]]
			if values.any(func(value: Variant) -> bool: return not field.options.any(func(option: Dictionary) -> bool: return typeof(option.id) == typeof(value) and option.id == value)):
				last_error = "当前没有符合条件的" + str(field.label); return
			# A multi-select candidate means a feasible extension of this subset.
			if field.multiple and field.has("count") and values.size() < int(field.count):
				var decision: Array = frame.decided.duplicate(); decision.erase(field.key)
				_branch(chosen, decision, field, values); return
			continue
		_branch(chosen, frame.decided, field); return
	queries += 1
	var answer: Dictionary = Eligibility.query(view, knowledge, modules, entry, chosen)
	if answer.get("ok", false): result = {"ok":true, "selection":chosen.duplicate(true), "queries":queries}
	else: last_error = str(answer.get("error", last_error))

func _branch(chosen: Dictionary, decided: Array, field: Dictionary, fixed: Array = []) -> void:
	var options: Array = field.options.filter(func(option: Dictionary) -> bool: return not option.id in fixed)
	if options.is_empty() and not field.optional and fixed.is_empty():
		last_error = "当前没有符合条件的" + str(field.label); return
	var branch := {"selection":chosen, "decided":decided, "field":field, "options":options, "index":-1, "fixed":fixed}
	if field.multiple:
		var minimum: int = maxi(0, int(field.get("count", 0 if field.optional else 1)) - fixed.size())
		branch["k"] = minimum
		branch["max_k"] = mini(options.size(), int(field.get("count", options.size())) - fixed.size())
		branch["indices"] = []
	stack.append(branch)

func _next(frame: Dictionary) -> Dictionary:
	if not frame.field.multiple:
		frame.index += 1
		if frame.field.optional and frame.index == 0: return {"exists":true, "value":null}
		var index: int = int(frame.index) - (1 if frame.field.optional else 0)
		return {"exists":true, "value":frame.options[index].id} if index < frame.options.size() else {"exists":false}
	var k: int = frame.k
	if k > int(frame.max_k): return {"exists":false}
	var indices: Array = frame.indices
	if indices.is_empty() and k > 0:
		for index: int in k: indices.append(index)
	var values: Array = frame.fixed.duplicate()
	for index: int in indices: values.append(frame.options[index].id)
	var cursor: int = k - 1
	while cursor >= 0 and int(indices[cursor]) == frame.options.size() - k + cursor: cursor -= 1
	if cursor < 0:
		frame.k = k + 1; frame.indices = []
	else:
		indices[cursor] += 1
		for index: int in range(cursor + 1, k): indices[index] = int(indices[index - 1]) + 1
	return {"exists":true, "value":values}

static func selection_for(fields: Array, selection: Dictionary, field: Dictionary, value: Variant) -> Dictionary:
	# Changing an earlier decision clears its suffix, both here and on click.
	# Optional modifiers retain the actual chosen base action and one another.
	var result: Dictionary = selection.duplicate(true)
	if not field.get("optional", false):
		var after := false
		for current: Dictionary in fields:
			if after: result.erase(current.key)
			if current.key == field.key: after = true
	if field.key == "agent": result.erase("agent_source")
	if field.get("multiple", false):
		var values: Array = selection.get(field.key, []).duplicate()
		if value in values: values.erase(value)
		else: values.append(value)
		result[field.key] = values
	elif value is String and value.is_empty(): result.erase(field.key)
	else: result[field.key] = value
	return result
