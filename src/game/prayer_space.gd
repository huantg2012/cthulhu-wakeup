extends RefCounted
## Versioned lightweight situations. Every result mutates authored objects; timers
## consume those same states rather than narrating a second imaginary outcome.
const Store = preload("res://src/simulation/archive_store.gd")
const Powers = preload("res://src/game/powers.gd")
const SCHEMA := 1
const PREFIX := "PS-"
# Frozen schema-one contracts from the previous release remain executable.
const LEGACY_VERSIONS := ["5cb2fdef47e1cf68d173799cebb8c76503ea862f549113edfb855a9d603a7f3c", "f807ece037281daa504966f359818488991e79bf092f251601c8cd6892c865df", "17962fc214af5ab983b91e60ce5699caf7a536288da51cebced0b03a0c2f95f5", "a974406fe693f8c1343552eb0df1d601d965b065e1c1f38a25a63f7aa472476d", "47ec59f04c84674a3d056ff6bf8f8b3199eb8a013afeb68d8248454cb69db20c"]
var catalog: RefCounted
var content: RefCounted
var checks: RefCounted

func _init(source: RefCounted) -> void:
	catalog = source
	content = source.prayer_space
	checks = Powers.new(source)

static func is_request(id: String) -> bool:
	return id.begins_with(PREFIX)

static func ledger(state: Dictionary) -> Dictionary:
	return state.get("prayer_system", {}).get("space", {})

static func entries(state: Dictionary) -> Array:
	var result: Array = []
	var data := ledger(state)
	for id: String in data.get("offered", []):
		var scene: Dictionary = data.get("scenes", {}).get(id, {})
		if not scene.is_empty() and scene.status == "open": result.append(entry(scene))
	return result

static func entry(scene: Dictionary) -> Dictionary:
	return {"id": scene.id, "card": {"id": scene.id, "content_id": scene.case_id, "visible_turn": scene.created, "due_turn": scene.due, "domain": scene.domain, "actors": scene.actors, "fact": scene.source}, "descriptor": {"space": true, "content_id": scene.case_id, "domain": scene.domain, "actors": scene.actors, "subjects": {"petitioner": scene.roles.petitioner}, "source": scene.source, "title": scene.title, "context": scene.context, "appeal": scene.appeal, "goal": scene.goal_text, "petitioner_role": scene.petitioner_role, "crisis": {"due": scene.crisis_due} if scene.crisis_due >= 0 else {}}, "status": scene.status, "source": scene.source}

static func choices(state: Dictionary, id: String) -> Array:
	var scene: Dictionary = ledger(state).get("scenes", {}).get(id, {})
	var visible: Array = []
	for choice: Dictionary in scene.get("choices", {}).values():
		var item: Dictionary = {}
		for field: String in ["id", "label", "operator", "cost", "whispers", "faith", "first_upkeep", "check_kind", "attribute", "difficulty", "hint", "irreversible", "duration", "approach", "intensity", "disclosure"]:
			if choice.has(field): item[field] = choice[field]
		visible.append(item)
	return visible

static func _deny(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _read_path(objects: Dictionary, path: String) -> Variant:
	var value: Variant = objects
	for key: String in path.split("."):
		if not value is Dictionary or not value.has(key): return null
		value = value[key]
	return value

static func matches(objects: Dictionary, predicates: Dictionary) -> bool:
	for path: String in predicates:
		var actual: Variant = _read_path(objects, path)
		var expected: Variant = predicates[path]
		if expected is Dictionary:
			for operation: String in expected:
				match operation:
					"gte":
						if not (actual is int or actual is float) or actual < expected[operation]: return false
					"lte":
						if not (actual is int or actual is float) or actual > expected[operation]: return false
					"eq":
						if actual != expected[operation]: return false
					"ne":
						if actual == expected[operation]: return false
					_: return false
		elif actual != expected: return false
	return true

static func updated(objects: Dictionary, updates: Dictionary) -> Dictionary:
	var next := objects.duplicate(true)
	var changes: Array = []
	var delay := 0
	for path: String in updates:
		if path == "$crisis.delay":
			delay += int(updates[path]); continue
		var parts := path.split(".")
		if parts.size() < 2: return _deny("无效的情境对象路径")
		var target: Dictionary = next
		for part: String in parts.slice(0, parts.size() - 1):
			if not target.get(part) is Dictionary: return _deny("情境对象已不存在")
			target = target[part]
		var field: String = parts[-1]
		if not target.has(field): return _deny("情境属性不存在")
		var before: Variant = target[field]
		var after: Variant = updates[path]
		if after is Dictionary and after.has("add"):
			if not (before is int or before is float): return _deny("情境数量类型不符")
			after = before + after.add
			if after < 0: return _deny("可交付的数量不足")
		if before == after: continue
		target[field] = after.duplicate(true) if after is Dictionary or after is Array else after
		changes.append({"object": parts[0], "name": str(next[parts[0]].get("name", "")), "field": field, "before": before, "after": after})
	return {"ok": true, "objects": next, "changes": changes, "delay": delay}

func _alive(state: Dictionary, actors: Array, domain: String, reader: RefCounted = null) -> bool:
	for id: String in actors:
		var npc: Dictionary = Store.entry(state.npcs, id, {})
		if npc.is_empty() and reader != null:
			var found: Dictionary = reader.entity("npcs", id)
			if found.get("ok", false): npc = found.item
		if npc.get("status") != "active" or npc.get("domain") != domain: return false
	return true

func prepare(view: Dictionary, id: String, variant: String, options: Dictionary) -> Dictionary:
	if view.turn.get("phase") != "actions": return _deny("轮初事件处理完毕后才能回应")
	for field: String in options:
		if field != "preparations": return _deny("本项回应没有这项准备")
	var state: Dictionary = view.world
	var data := ledger(state)
	var scene: Dictionary = data.get("scenes", {}).get(id, {})
	if scene.is_empty() or not id in data.offered or scene.status != "open" or scene.due < state.turn or int(data.offer_turn) != int(state.turn): return _deny("这项祈求已不在当前回应窗口")
	if not _alive(state, scene.actors, scene.domain, view.get("reader")): return _deny("原参与者已无法参与这项回应")
	var dismiss := variant == "dismiss"
	if not dismiss and int(view.turn.get("responses", 0)) >= catalog.integer("prayer_response_limit"): return _deny("本轮回应机会已用")
	if not dismiss and not scene.choices.has(variant): return _deny("此处境没有这项回应")
	var selected: Dictionary = scene.choices.get(variant, {})
	var contract: Dictionary = scene.contracts.get(variant, {})
	var modern := selected.has("difficulty")
	if (dismiss or not modern) and not options.is_empty(): return _deny("本项回应无需额外配置对象")
	if not dismiss:
		if not matches(scene.objects, contract.requires): return _deny("此回应需要的对象或条件已改变")
		if _possible_effects(scene.objects, contract).is_empty(): return _deny("此处境已经改变，无法再如此回应")
	var faith := 0 if dismiss else int(selected.faith)
	var first_upkeep := 0 if dismiss else int(selected.get("first_upkeep", 0))
	var whispers := 0 if dismiss else int(selected.whispers)
	if state.faith < faith + first_upkeep or state.whispers < whispers: return _deny("需要 %d 低语、%d 信仰" % [whispers, faith + first_upkeep])
	var actor: String = scene.roles.petitioner
	var npc: Dictionary = Store.entry(state.npcs, actor, {})
	if npc.is_empty() and view.has("reader"): npc = view.reader.entity("npcs", actor).get("item", {})
	var preparation := 0
	var preparations: Array = []
	if not options.get("preparations", []) is Array: return _deny("准备来源格式无效")
	for source: Variant in options.get("preparations", []):
		if not source is String or source in preparations or not state.get("power_system", {}).get("preparations", {}).has(source): return _deny("准备已使用或不存在")
		var item: Dictionary = state.power_system.preparations[source]
		var invalid: bool = view.reader.invalidated(source) if view.get("reader") != null else Store.has(state.invalid_records, source)
		if item.npc != actor or item.action != "PRAYER/" + id + "/" + variant or item.expires < state.turn or invalid: return _deny("准备不属于本次祈求人、回应或回合")
		preparation += int(item.amount); preparations.append(source)
	var probability := -1
	if not dismiss and selected.check_kind != "deterministic": probability = checks.probability(npc, state.domains[scene.domain], selected, preparation)
	if modern and contract.get("disclosure") == "unknown" and _effect_ranges(_possible_effects(scene.objects, contract), probability).is_empty(): return _deny("当前合法结果无法分配检定区间")
	var attention := {"family": "prayer", "content_id": "SPACE_" + scene.case_id, "request": id, "variant": variant, "participants": [] if dismiss else scene.actors, "target": scene.domain, "source": scene.source}
	return {"ok": true, "space": true, "request": id, "variant": variant, "actor": actor, "faith": faith, "first_upkeep": first_upkeep, "whispers": whispers, "probability": probability, "success_target": probability, "p": probability, "preparation": preparation, "preparations": preparations, "agent_source": "", "descriptor": entry(scene).descriptor, "hint": str(selected.get("hint", "")), "dismiss": dismiss, "disclosure": selected.get("disclosure", "clear"), "approach": selected.get("approach", ""), "intensity": selected.get("intensity", 0), "attention": attention}

func _snapshot(world: RefCounted, scene: Dictionary, kind: String, parents: Array, extra: Dictionary = {}) -> String:
	var copy := scene.duplicate(true)
	copy.erase("last_event")
	var data: Dictionary = {"request": scene.id, "version": scene.get("content_version", ledger(world.state).version), "scene_after": copy}
	data.merge(extra, true)
	var source: String = world._record(kind, scene.domain, scene.roles.petitioner, scene.actors, parents, data)
	scene.last_event = source
	return source

func _apply(scene: Dictionary, updates: Dictionary) -> Dictionary:
	var result := updated(scene.objects, updates)
	if result.ok:
		scene.objects = result.objects
		if scene.crisis_due >= 0: scene.crisis_due += int(result.delay)
	return result

func _manifested(applied: Dictionary) -> bool:
	return not applied.changes.is_empty() or int(applied.delay) != 0

func _record_miracle(world: RefCounted, scene: Dictionary, effect: Dictionary, source: String, owner: Object) -> bool:
	var witnesses: Array = []
	for id: String in effect.witnesses:
		var person: Dictionary = Store.entry(world.state.npcs, id, {})
		if id in scene.actors and person.get("status") == "active" and person.get("domain") == scene.domain:
			witnesses.append(id)
	# The response or consumed scheduled step owns the occurrence. No new roll,
	# witnesses from the participant list, institutional record, or anchor award.
	return not world.introduce_fact("miracle", scene.domain, "", witnesses, [source], {
		"witnesses": witnesses, "public": effect.public, "prayer_space_source": source,
	}, witnesses, [], owner).is_empty()

func _metric(world: RefCounted, scene: Dictionary, field: String, amount: int, source: String) -> String:
	var domain: Dictionary = world.state.domains[scene.domain]
	var before: int = domain[field]
	if field == "pollution":
		world.change_pollution(scene.domain, amount)
	else:
		domain[field] = clampi(before + amount, 0, catalog.integer("attribute_max"))
	if field == "pollution" and domain[field] > before: domain.pollution_changed_turn = world.state.turn
	if field == "alert" and domain[field] > before: domain.exposure_turn = world.state.turn
	return world._record("prayer_delta", scene.domain, scene.roles.petitioner, [scene.domain], [source], {"request": scene.id, "field": field, "before": before, "after": int(domain[field]), "amount": int(domain[field]) - before})

func commit(world: RefCounted, plan: Dictionary, owner: Object) -> bool:
	var data := ledger(world.state)
	if not data.scenes.has(plan.request): return false
	var scene: Dictionary = data.scenes[plan.request]
	if scene.status != "open": return false
	var paid_id := "FACT-%08d" % (int(world.state.next_fact) - 1)
	var paid: Dictionary = Store.entry(world.state.facts, paid_id, {})
	if paid.get("kind") == "cult_local_payment":
		paid_id = str(paid.changes.payment); paid = Store.entry(world.state.facts, paid_id, {})
	if paid.get("kind") != "turn_action" or paid.changes.get("faith_cost") != plan.faith or paid.changes.get("whispers_cost") != plan.whispers or paid.changes.get("outcome") != "prayer_space_attempt": return false
	if plan.dismiss:
		scene.status = "dismissed"
		_snapshot(world, scene, "prayer_space_closed", [scene.source, paid_id], {"reason": "dismissed", "title": scene.title})
		data.offered.erase(scene.id)
		return true
	var selected: Dictionary = scene.choices[plan.variant]
	var contract: Dictionary = scene.contracts[plan.variant]
	var alternatives := _possible_effects(scene.objects, contract)
	if alternatives.is_empty(): return false
	var modern := selected.has("difficulty")
	var ranges: Array = _effect_ranges(alternatives, int(plan.probability)) if modern and contract.get("disclosure") == "unknown" else []
	if modern and (plan.probability < 0 or (contract.get("disclosure") == "unknown" and ranges.is_empty())): return false
	var before_metrics := _metrics(world.state, scene)
	var attempt := ""
	if modern:
		var person: Dictionary = Store.entry(world.state.npcs, plan.actor, {})
		var domain: Dictionary = world.state.domains[scene.domain]
		var check_inputs := {"person": {"sanity": person.sanity, selected.attribute: person[selected.attribute]}, "domain": {"tier": domain.tier, "barrier": domain.barrier, "alert": domain.alert}, "preparation": int(plan.preparation)}
		attempt = world._record("prayer_space_attempt", scene.domain, plan.actor, scene.actors, [scene.source, paid_id] + plan.preparations, {"request": scene.id, "variant": plan.variant, "payment": paid_id, "probability": plan.probability, "preparations": plan.preparations, "check_inputs": check_inputs, "objects_before": scene.objects.duplicate(true), "metrics_before": before_metrics, "ranges": ranges})
		for source: String in plan.preparations:
			Store.put(world.state.applied_authorizations, "power/preparation/" + source, attempt)
			world.state.power_system.preparations.erase(source)
	var revealed_effect: String = selected.effect
	var revealed_tradeoff: String = selected.tradeoff
	var twist := ""
	var checked := ""
	var roll := 0
	var outcome := "success"
	if plan.probability >= 0:
		roll = world.randoms.checks.randi_range(1, 100)
		outcome = world.check_result(plan.probability, roll)
		owner._checks.append({"probability": plan.probability, "roll": roll, "outcome": outcome})
		checked = world._record("turn_check", scene.domain, plan.actor, [plan.actor], [scene.source, paid_id] + ([] if attempt.is_empty() else [attempt]), {"probability": plan.probability, "roll": roll, "outcome": outcome})
	var changes: Array = []
	var upkeep_payment := ""
	var manifestation: Dictionary = {}
	if outcome in ["success", "deep"]:
		if contract.get("disclosure", "clear") == "unknown":
			var before: Dictionary = scene.objects.duplicate(true)
			var seed_text := "" if modern else _twist_seed(data, scene, plan.variant)
			var draw := _effect_for_roll(alternatives, ranges, roll) if modern else _draw_effect(alternatives, seed_text)
			if draw.is_empty(): return false
			contract = draw.effect
			revealed_effect = contract.effect; revealed_tradeoff = contract.tradeoff
			scene["selected_outcome"] = contract.id
			var detail := {"request": scene.id, "variant": plan.variant, "branch": contract.id, "roll": draw.roll, "total": draw.total, "objects_before": before}
			if modern: detail.merge({"method": "action_d100", "ranges": ranges, "check": checked, "attempt": attempt})
			else: detail["seed"] = seed_text
			twist = world._record("prayer_space_twist", scene.domain, plan.actor, scene.actors, [scene.source, paid_id] + ([] if checked.is_empty() else [checked]), detail)
		var applied := _apply(scene, contract.updates)
		if not applied.ok: return false
		changes.append_array(applied.changes)
		if _manifested(applied): manifestation = contract.get("miracle", {})
		for next: Dictionary in contract.get("followup", []):
			var scheduled := next.duplicate(true)
			scheduled["due"] = int(world.state.turn) + int(next.delay)
			scene.pending.append(scheduled)
		var maintenance: Dictionary = contract.get("maintenance", {})
		if not maintenance.is_empty():
			var upkeep := int(maintenance.get("faith", 0))
			if world.state.faith < upkeep: return false
			world.state.faith -= upkeep
			upkeep_payment = world._record("prayer_space_maintenance", scene.domain, scene.roles.petitioner, scene.actors, [paid_id], {"request": scene.id, "faith_cost": upkeep, "turn": int(world.state.turn), "installment": 1, "effect": "已履行本轮约定。"})
			var first := _apply(scene, maintenance.get("updates", {}))
			if not first.ok: return false
			changes.append_array(first.changes)
			scene.maintenance = maintenance.duplicate(true)
			scene.maintenance["remaining"] = maxi(0, int(maintenance.turns) - 1)
			scene.maintenance["next"] = int(world.state.turn) + 1
			scene.maintenance["paid"] = 1
		scene.goal_reached = not contract.goal.is_empty() and matches(scene.objects, contract.goal)
		scene["selected_goal"] = contract.goal.duplicate(true)
		scene["selected_choice"] = plan.variant
		scene["selected_effect"] = revealed_effect
		scene["selected_tradeoff"] = revealed_tradeoff
	var metric_sources: Array = []
	var metric_parent := checked if not checked.is_empty() else paid_id
	if outcome in ["success", "deep"]:
		metric_sources.append(_metric(world, scene, "pollution", int(selected.pollution), metric_parent))
		metric_sources.append(_metric(world, scene, "alert", int(selected.alert), metric_parent))
	elif outcome == "disaster":
		var person: Dictionary = world.mutable_npc(plan.actor)
		person.sanity = maxi(0, int(person.sanity) - int(selected.disaster_sanity))
		metric_sources.append(world._record("prayer_delta", scene.domain, plan.actor, [plan.actor], [metric_parent], {"request": scene.id, "field": "sanity", "before": before_metrics.sanity, "after": person.sanity, "amount": int(person.sanity) - int(before_metrics.sanity)}))
		metric_sources.append(_metric(world, scene, "alert", int(selected.disaster_alert), metric_parent))
	var after_metrics := _metrics(world.state, scene)
	var actual_deltas := {}
	for field: String in before_metrics: actual_deltas[field] = int(after_metrics[field]) - int(before_metrics[field])
	scene.status = "answered"
	scene["response"] = "FACT-%08d" % int(world.state.next_fact)
	var result := _snapshot(world, scene, "prayer_space_result", [scene.source, paid_id] + ([] if checked.is_empty() else [checked]) + ([] if upkeep_payment.is_empty() else [upkeep_payment]) + ([] if twist.is_empty() else [twist]) + metric_sources, {"attempt": attempt, "check": checked, "twist": twist, "disclosure": selected.get("disclosure", "clear"), "title": scene.title, "choice_label": selected.label, "variant": plan.variant, "outcome": outcome, "probability": plan.probability, "success_target": plan.probability, "roll": roll, "actual_deltas": actual_deltas, "metric_sources": metric_sources, "effect": revealed_effect if outcome in ["success", "deep"] else "此次介入未生效，原处境继续。", "tradeoff": revealed_tradeoff if outcome in ["success", "deep"] else (selected.disaster if outcome == "disaster" else "已付费用不返还。"), "state_changes": changes, "goal_reached": scene.goal_reached, "pending_count": scene.pending.size(), "maintenance_remaining": int(scene.maintenance.get("remaining", 0)), "maintenance_payment": upkeep_payment, "payment": paid_id, "faith_cost": plan.faith, "whispers_cost": plan.whispers})
	for person: String in scene.actors: world._know(person, result)
	if not manifestation.is_empty() and not _record_miracle(world, scene, manifestation, result, owner): return false
	data.offered.erase(scene.id)
	return true

static func _metrics(state: Dictionary, scene: Dictionary) -> Dictionary:
	return {"pollution": int(state.domains[scene.domain].pollution), "alert": int(state.domains[scene.domain].alert), "sanity": int(Store.entry(state.npcs, scene.roles.petitioner, {}).get("sanity", 0))}

static func _bind(value: Variant, roles: Dictionary) -> Variant:
	if value is String: return roles.get(value, value)
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(_bind(child, roles))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = _bind(value[key], roles)
		return result
	return value

static func _needs_missing_cult(objects: Dictionary, contract: Dictionary) -> bool:
	for key: String in objects:
		if objects[key].get("owner") != "cult": continue
		for field: String in ["requires", "updates", "goal"]:
			for path: String in contract.get(field, {}):
				if path.begins_with(key + "."): return true
	for outcome: Dictionary in contract.get("outcomes", []):
		if _needs_missing_cult(objects, outcome): return true
	return false

func _compatible_people(state: Dictionary, objects: Dictionary) -> bool:
	# A newly generated background may not erase an existing bodily change,
	# obligation or disability belonging to the same actual person.
	for previous: Dictionary in ledger(state).get("scenes", {}).values():
		if previous.status != "answered": continue
		for known: Dictionary in previous.objects.values():
			if not known.has("role"): continue
			for candidate: Dictionary in objects.values():
				if candidate.get("role") != known.role: continue
				for field: String in candidate:
					if field in ["name", "role", "location"]: continue
					if known.has(field) and known[field] != candidate[field]: return false
	return true

func _new_scene(world: RefCounted, case_id: String, people: Array, domain: String) -> Dictionary:
	var row: Dictionary = content.tables.cases[case_id]
	var runtime: Dictionary = content.tables.runtime[case_id]
	var roles: Dictionary = {"petitioner": people[0], "institution": domain + "/order"}
	if people.size() > 1: roles["other"] = people[1]
	if people.size() > 2: roles["third"] = people[2]
	for cult: Dictionary in world.state.get("cults", {}).values():
		if cult.domain == domain and cult.status != "destroyed":
			roles["cult"] = cult.id; break
	var objects: Dictionary = _bind(runtime.objects, roles)
	if not _compatible_people(world.state, objects): return {}
	var available: Dictionary = {}; var contracts: Dictionary = {}
	for choice_id: String in row.choices:
		var contract_key := case_id + "/" + choice_id
		if not content.tables.response_contracts.has(contract_key): continue
		var contract: Dictionary = _bind(content.tables.response_contracts[contract_key], roles)
		if not roles.has("cult") and _needs_missing_cult(runtime.objects, contract): continue
		if not matches(objects, contract.requires) or _possible_effects(objects, contract).is_empty(): continue
		var option: Dictionary = row.choices[choice_id].duplicate(true)
		var costs: Dictionary = content.tables.costs[option.cost]
		for key: String in ["whispers", "faith", "pollution", "alert", "disaster_sanity", "disaster_alert"]: option[key] = int(costs[key])
		var quote: Dictionary = contract.outcomes[0] if contract.get("disclosure", "clear") == "unknown" else contract
		option["first_upkeep"] = int(quote.get("maintenance", {}).get("faith", 0))
		for field: String in ["approach", "intensity", "disclosure", "omen"]: option[field] = contract.get(field, 0 if field == "intensity" else "")
		for key: String in ["check_kind", "attribute", "difficulty", "hint"]: option[key] = contract[key]
		option["disaster"] = costs.disaster
		option["irreversible"] = contract.irreversible
		option["duration"] = str(quote.get("maintenance", {}).get("turns", ""))
		available[choice_id] = option; contracts[choice_id] = contract
	if available.is_empty(): return {}
	var affordable: bool = available.values().any(func(option: Dictionary) -> bool: return world.state.faith >= option.faith + int(option.first_upkeep) and world.state.whispers >= option.whispers)
	if not affordable: return {}
	var data := ledger(world.state)
	var id := PREFIX + "%08d" % int(data.next_id)
	var crisis: Dictionary = _bind(runtime.crisis, roles)
	var due: int = int(world.state.turn) + int(row.deadline) - 1
	var scene: Dictionary = {"id": id, "content_version": content.version, "case_id": case_id, "domain": domain, "actors": people.duplicate(), "roles": roles, "created": int(world.state.turn), "due": due, "status": "open", "objects": objects, "choices": available, "contracts": contracts, "crisis": crisis, "crisis_due": int(world.state.turn) + int(crisis.get("delay", -1)) - 1 if not crisis.is_empty() else -1, "crisis_done": false, "pending": [], "maintenance": {}, "goal_reached": false, "title": row.title, "context": row.context, "appeal": row.appeal, "goal_text": row.goal, "petitioner_role": row.petitioner, "expiry": row.expiry, "expiry_updates": _bind(runtime.expiry_updates, roles), "source": ""}
	var source: String = world._record("prayer_space_situation", domain, people[0], people, [world.state.domains[domain].origin], {"request": id, "version": content.version, "case_id": case_id, "roles": roles, "objects": objects, "created": int(world.state.turn), "due": due, "background": true})
	scene.source = source
	scene["registration"] = "FACT-%08d" % int(world.state.next_fact)
	_snapshot(world, scene, "prayer_space_registered", [source], {"title": row.title})
	data.next_id += 1
	return scene

func _bind_candidate(people: Array, required: int, occurrence_prefix: String, data: Dictionary, turn: int) -> Array:
	var available := people.filter(func(id: String) -> bool: return int(data.people_cooldowns.get(id, -1)) <= turn)
	if available.size() < required: return []
	for id: String in available:
		if data.used.has(occurrence_prefix + id): continue
		var participants: Array = [id]
		for other: String in available:
			if participants.size() == required: break
			if other != id: participants.append(other)
		return participants
	return []

func freeze(world: RefCounted, new_limit: int) -> bool:
	world.stage_collections(["prayer_system"])
	if ledger(world.state).is_empty():
		var installed: String = world._record("prayer_space_adopted", "", "", [], [], {"version": content.version, "schema": SCHEMA, "turn": int(world.state.turn)})
		world.state.prayer_system["space"] = {"schema": SCHEMA, "version": content.version, "installed": installed, "offer_turn": int(world.state.turn), "scenes": {}, "offered": [], "next_id": 1, "cooldowns": {}, "people_cooldowns": {}, "used": {}, "recent": [], "rng_seed": str(world.randoms.generation.seed), "draw": 0}
	var data := ledger(world.state)
	if not _supported_version(str(data.version), content.version): return false
	data.offered = []
	data.offer_turn = int(world.state.turn)
	for id: String in data.scenes:
		var scene: Dictionary = data.scenes[id]
		if scene.status != "open": continue
		if not _alive(world.state, scene.actors, scene.domain):
			scene.status = "unavailable"
			_snapshot(world, scene, "prayer_space_closed", [scene.last_event], {"reason": "subject_changed"})
		elif scene.due >= world.state.turn and data.offered.size() < 2: data.offered.append(id)
	var domains: Array = world.state.simulation.get("focused", []).duplicate()
	domains.sort()
	var candidates: Array = []
	var residents: Dictionary = {}
	var recent: Array = []
	for item: Dictionary in data.recent:
		if int(item.turn) + content.parameter("recent_memory") >= int(world.state.turn): recent.append(item)
	data.recent = recent
	for domain: String in domains:
		var people: Array = world.history.ids("living").filter(func(id: String) -> bool:
			var person: Dictionary = Store.entry(world.state.npcs, id)
			return person.status == "active" and person.domain == domain and int(data.people_cooldowns.get(id, -1)) <= int(world.state.turn))
		people.sort()
		if people.is_empty(): continue
		residents[domain] = people
		for case_id: String in content.tables.runtime:
			var row: Dictionary = content.tables.cases[case_id]
			var runtime: Dictionary = content.tables.runtime[case_id]
			if not str(world.state.domains[domain].profile) in str(runtime.profiles).split("|", false) or people.size() < int(runtime.people): continue
			var cooldown := domain + "/" + str(row.scene)
			if int(data.cooldowns.get(cooldown, -1)) > int(world.state.turn): continue
			var occurrence_prefix := domain + "/" + case_id + "/"
			if _bind_candidate(people, int(runtime.people), occurrence_prefix, data, int(world.state.turn)).is_empty(): continue
			var signature := str(row.frame) + "/" + str(row.scene) + "/" + str(row.concern)
			var repeated: bool = data.recent.any(func(item: Dictionary) -> bool: return item.signature == signature)
			candidates.append({"domain": domain, "case_id": case_id, "required": int(runtime.people), "occurrence_prefix": occurrence_prefix, "signature": signature, "cooldown": cooldown, "weight": content.parameter("seen_signature_weight" if repeated else "new_signature_weight")})
	# Shuffle the bounded binding page independently of legacy random streams.
	var rng := RandomNumberGenerator.new()
	rng.seed = (str(data.rng_seed) + "/prayer-space/" + str(data.draw)).hash()
	while data.offered.size() < new_limit and not candidates.is_empty() and int(data.get("attempted_turn", -1)) != int(world.state.turn):
		var tried := 0
		while data.offered.size() < new_limit and not candidates.is_empty() and tried < content.parameter("candidate_budget"):
			var total := 0
			for candidate: Dictionary in candidates: total += int(candidate.weight)
			var pick := rng.randi_range(1, total)
			var index := 0
			while index < candidates.size() - 1 and pick > int(candidates[index].weight):
				pick -= int(candidates[index].weight); index += 1
			var candidate: Dictionary = candidates.pop_at(index)
			tried += 1; data.draw += 1
			if int(data.cooldowns.get(candidate.cooldown, -1)) > int(world.state.turn): continue
			# A previous offer in this window may have reserved the original
			# participants. Rebind before freezing, never after an offer exists.
			var participants := _bind_candidate(residents[candidate.domain], candidate.required, candidate.occurrence_prefix, data, int(world.state.turn))
			if participants.is_empty(): continue
			var scene := _new_scene(world, candidate.case_id, participants, candidate.domain)
			if scene.is_empty(): continue
			data.scenes[scene.id] = scene; data.offered.append(scene.id)
			data.used[candidate.occurrence_prefix + str(participants[0])] = scene.source
			data.cooldowns[candidate.cooldown] = int(world.state.turn) + content.parameter("scene_cooldown")
			for person: String in participants: data.people_cooldowns[person] = int(world.state.turn) + content.parameter("petitioner_cooldown")
			data.recent.append({"turn": int(world.state.turn), "signature": candidate.signature})
		data["attempted_turn"] = int(world.state.turn)
	return true

func deadlines(world: RefCounted, owner: Object) -> bool:
	var data := ledger(world.state)
	if data.is_empty(): return true
	world.stage_collections(["prayer_system", "domains", "npcs"])
	for scene: Dictionary in data.scenes.values():
		var changes: Array = []
		var changed := false
		var manifestations: Array = []
		var descriptions: Array[String] = []
		var parents: Array = [scene.last_event]
		var active := _alive(world.state, scene.actors, scene.domain)
		var maintenance: Dictionary = scene.maintenance
		if not maintenance.is_empty() and int(maintenance.next) <= int(world.state.turn):
			var can_pay: bool = active and matches(scene.objects, maintenance.get("requires", {})) and world.state.faith >= int(maintenance.get("faith", 0))
			if int(maintenance.remaining) > 0 and can_pay:
				var applied := _apply(scene, maintenance.get("updates", {}))
				if not applied.ok: return false
				var amount := int(maintenance.get("faith", 0))
				world.state.faith -= amount
				parents.append(world._record("prayer_space_maintenance", scene.domain, scene.roles.petitioner, scene.actors, [scene.last_event], {"request": scene.id, "faith_cost": amount, "turn": int(world.state.turn), "installment": int(maintenance.paid) + 1, "effect": "已履行本轮约定。"}))
				maintenance.paid += 1; maintenance.remaining -= 1; maintenance.next += 1
				changes.append_array(applied.changes)
			else:
				var applied := _apply(scene, maintenance.get("on_end", maintenance.get("on_stop", {})) if int(maintenance.remaining) <= 0 else maintenance.get("on_stop", {}))
				if not applied.ok: return false
				changes.append_array(applied.changes); scene.maintenance = {}
			changed = true
		var pending: Array = []
		for item: Dictionary in scene.pending:
			if int(item.due) > int(world.state.turn): pending.append(item); continue
			if active and matches(scene.objects, item.get("requires", {})):
				var applied := _apply(scene, item.get("updates", {}))
				if not applied.ok: return false
				changes.append_array(applied.changes)
				var manifestation: Dictionary = item.get("miracle", {})
				if not manifestation.is_empty() and _manifested(applied):
					manifestations.append(manifestation)
					descriptions.append(item.effect)
			changed = true
		scene.pending = pending
		if not scene.crisis_done and scene.crisis_due >= 0 and int(scene.crisis_due) <= int(world.state.turn):
			if matches(scene.objects, scene.crisis.get("requires", {})):
				var applied := _apply(scene, scene.crisis.get("updates", {}))
				if not applied.ok: return false
				changes.append_array(applied.changes)
			scene.crisis_done = true; changed = true
		if scene.status == "open" and (scene.due <= world.state.turn or not active):
			if active:
				var expired := _apply(scene, scene.expiry_updates)
				if not expired.ok: return false
				changes.append_array(expired.changes)
			scene.status = "expired" if active else "unavailable"
			data.offered.erase(scene.id); changed = true
		if scene.has("selected_goal") and not scene.selected_goal.is_empty():
			var reached: bool = matches(scene.objects, scene.selected_goal)
			if reached != scene.goal_reached: scene.goal_reached = reached; changed = true
		if changed:
			var description: String = scene.expiry if scene.status == "expired" else ("祈求的目标已达成。" if scene.goal_reached else "当地处境发生变化，约定已按本轮条件处理。")
			var progress := {"title": scene.title, "state_changes": changes, "goal_reached": scene.goal_reached, "pending_count": scene.pending.size(), "maintenance_remaining": int(scene.maintenance.get("remaining", 0)), "effect": description}
			if not manifestations.is_empty():
				progress["effect"] = " ".join(descriptions)
				progress["manifestation_of"] = scene.response
				parents.append(scene.response)
			var source := _snapshot(world, scene, "prayer_space_progress", parents, progress)
			for manifestation: Dictionary in manifestations:
				if not _record_miracle(world, scene, manifestation, source, owner): return false
	return true

static func validate(state: Dictionary, content_source: RefCounted) -> Array[String]:
	var data := ledger(state)
	if data.is_empty(): return []
	if data.get("schema") != SCHEMA or not _supported_version(str(data.get("version", "")), content_source.prayer_space.version): return ["Prayer space schema/content version changed"]
	for field: String in ["scenes", "used", "cooldowns", "people_cooldowns"]:
		if not data.get(field) is Dictionary: return ["Malformed prayer space ledger"]
	if not data.get("offered") is Array or not data.get("offer_turn") is int or not data.get("next_id") is int: return ["Malformed prayer space window"]
	if data.offered.size() + state.prayer_system.offered.size() > content_source.integer("prayer_offer_limit"): return ["Combined prayer offer limit exceeded"]
	var installed: Dictionary = Store.entry(state.facts, str(data.get("installed", "")), {})
	if installed.get("kind") != "prayer_space_adopted" or installed.changes.get("version") != data.version: return ["Prayer space adoption lost its original policy"]
	var seen: Dictionary = {}
	for id: Variant in data.offered:
		if not id is String or seen.has(id) or not data.scenes.has(id) or data.scenes[id].status != "open": return ["Invalid prayer space offer"]
		seen[id] = true
	for id: String in data.scenes:
		var scene: Variant = data.scenes[id]
		if not scene is Dictionary or scene.get("id") != id or not scene.get("status") in ["open", "answered", "dismissed", "expired", "unavailable"]: return ["Invalid prayer space situation"]
		var original: Dictionary = Store.entry(state.facts, str(scene.get("source", "")), {})
		var latest: Dictionary = Store.entry(state.facts, str(scene.get("last_event", "")), {})
		if original.get("kind") != "prayer_space_situation" or original.changes.get("request") != id or latest.get("kind") not in ["prayer_space_registered", "prayer_space_result", "prayer_space_progress", "prayer_space_closed"] or latest.changes.get("request") != id: return ["Prayer space lost its actual state transition"]
		var current: Dictionary = scene.duplicate(true); current.erase("last_event")
		if latest.changes.get("scene_after") != current: return ["Prayer space state changed without an actual result"]
		if not _supported_version(str(original.changes.get("version", "")), content_source.prayer_space.version) or original.changes.get("version") != scene.get("content_version", data.version) or latest.changes.get("version") != original.changes.get("version"): return ["Prayer space lost its frozen content version"]
		if scene.get("case_id") != original.changes.get("case_id") or scene.get("roles") != original.changes.get("roles") or scene.get("due") != original.changes.get("due"): return ["Prayer space changed its original subjects or request deadline"]
		if scene.has("registration"):
			var registration: Dictionary = Store.entry(state.facts, str(scene.registration), {})
			if registration.get("kind") != "prayer_space_registered" or not scene.source in registration.get("causal_parents", []) or registration.changes.get("request") != id: return ["Prayer space lost its frozen registration"]
			for field: String in ["choices", "contracts"]:
				if registration.changes.get("scene_after", {}).get(field) != scene.get(field): return ["Prayer space changed its frozen response contract"]
		if scene.status == "answered":
			var response: Dictionary = Store.entry(state.facts, str(scene.get("response", "")), {})
			if response.get("kind") != "prayer_space_result" or response.changes.get("request") != id: return ["Answered prayer has no original result"]
			var result: Dictionary = response.changes
			if not scene.choices.has(result.get("variant")): return ["Prayer response invented a choice"]
			var option: Dictionary = scene.choices[result.variant]
			var modern := option.has("difficulty")
			if modern:
				var errors := _validate_attempt(state, content_source, scene, response, option)
				if not errors.is_empty(): return errors
			var payment: Dictionary = Store.entry(state.facts, str(result.get("payment", "")), {})
			if payment.get("kind") != "turn_action" or payment.turn != response.turn or payment.changes.get("outcome") != "prayer_space_attempt" or payment.changes.get("faith_cost") != option.faith or payment.changes.get("whispers_cost") != option.whispers: return ["Prayer response lost its authored payment"]
			if option.get("disclosure", "clear") == "unknown" and result.outcome in ["success", "deep"]:
				var twist: Dictionary = Store.entry(state.facts, str(result.get("twist", "")), {})
				if twist.get("kind") != "prayer_space_twist" or twist.changes.get("request") != id or twist.changes.get("variant") != result.variant: return ["Unknown prayer lost its committed draw"]
				var detail: Dictionary = twist.changes
				if not detail.get("objects_before") is Dictionary: return ["Unknown prayer lost its original circumstances"]
				var alternatives := _possible_effects(detail.objects_before, scene.contracts[result.variant])
				if alternatives.is_empty(): return ["Unknown prayer fabricated its draw inputs"]
				var draw: Dictionary
				if modern:
					var ranges := _effect_ranges(alternatives, int(result.probability))
					var attempt: Dictionary = Store.entry(state.facts, result.attempt, {})
					if detail.get("method") != "action_d100" or detail.get("check") != result.check or detail.get("attempt") != result.attempt or detail.objects_before != attempt.changes.objects_before or detail.get("ranges") != ranges or detail.has("seed"): return ["Unknown prayer did not use its action die"]
					draw = _effect_for_roll(alternatives, ranges, int(result.roll))
				else:
					if detail.get("seed") != _twist_seed(data, scene, result.variant): return ["Unknown prayer fabricated its draw inputs"]
					draw = _draw_effect(alternatives, detail.seed)
				if draw.is_empty(): return ["Unknown prayer has no interval for its action die"]
				if detail.get("branch") != draw.effect.id or detail.get("roll") != draw.roll or detail.get("total") != draw.total or scene.get("selected_outcome") != draw.effect.id or result.effect != draw.effect.effect or result.tradeoff != draw.effect.tradeoff: return ["Unknown prayer changed its committed outcome"]
			if option.check_kind == "deterministic":
				if result.get("probability") != -1 or result.get("roll") != 0 or result.get("outcome") != "success": return ["Deterministic prayer fabricated a check"]
			else:
				var checked: Dictionary = Store.entry(state.facts, str(result.get("check", "")), {})
				if checked.get("kind") != "turn_check" or checked.changes.get("probability") != result.get("probability") or checked.changes.get("roll") != result.get("roll") or checked.changes.get("outcome") != result.get("outcome"): return ["Prayer response lost its actual check"]
				var probability: int = int(result.probability)
				var roll: int = int(result.roll)
				if probability < content_source.integer("check_probability_min") or probability > content_source.integer("check_probability_max") or roll < 1 or roll > 100: return ["Invalid prayer check bounds"]
				var edge := maxi(1, int(floor(float(probability) / content_source.number("check_critical_divisor"))))
				var disaster := maxi(1, int(ceil(float(100 - probability) / content_source.number("check_critical_divisor"))))
				var expected := "deep" if roll <= edge else ("success" if roll <= probability else ("disaster" if roll > 100 - disaster else "failure"))
				if result.outcome != expected: return ["Prayer response fabricated its outcome"]
		for person: Variant in scene.get("actors", []):
			if not person is String or not Store.has(state.npcs, person): return ["Prayer space references an invented person"]
	return []

static func _validate_attempt(state: Dictionary, source: RefCounted, scene: Dictionary, response: Dictionary, option: Dictionary) -> Array[String]:
	var result: Dictionary = response.changes
	if not scene.has("registration") or not option.get("difficulty") is int or option.difficulty < -20 or option.difficulty > 30 or not option.get("check_kind") in ["occult", "social"] or not option.get("attribute") in ["insight", "adaptation", "will", "influence"]: return ["Invalid authored prayer check"]
	var attempt: Dictionary = Store.entry(state.facts, str(result.get("attempt", "")), {})
	if attempt.get("kind") != "prayer_space_attempt" or attempt.get("actor") != scene.roles.petitioner or attempt.get("turn") != response.turn: return ["Prayer response lost its committed attempt"]
	var data: Dictionary = attempt.changes
	if data.get("request") != scene.id or data.get("variant") != result.variant or data.get("payment") != result.payment or data.get("probability") != result.probability or result.get("success_target") != result.probability: return ["Prayer response changed its committed target"]
	var checked: Dictionary = Store.entry(state.facts, str(result.get("check", "")), {})
	if not attempt.id in checked.get("causal_parents", []): return ["Prayer check lost its attempt"]
	if not data.get("check_inputs") is Dictionary or not data.get("preparations") is Array or not data.get("objects_before") is Dictionary: return ["Prayer attempt lost its original inputs"]
	var inputs: Dictionary = data.check_inputs
	if not inputs.get("person") is Dictionary or not inputs.get("domain") is Dictionary or not inputs.get("preparation") is int: return ["Prayer attempt has malformed check inputs"]
	if not inputs.person.get("sanity") is int or not inputs.person.get(option.attribute) is int or not inputs.domain.get("tier") in ["planet", "system", "cosmic"] or not inputs.domain.get("barrier") is int or not inputs.domain.get("alert") is int: return ["Prayer attempt lost its original actor or world"]
	var preparation := 0
	var seen: Dictionary = {}
	for id: Variant in data.preparations:
		if not id is String or seen.has(id) or Store.entry(state.applied_authorizations, "power/preparation/" + id, "") != attempt.id or not Powers._valid_preparation_consumer(state, id, attempt.id): return ["Prayer preparation did not have one valid consumer"]
		seen[id] = true
		var check: Dictionary = Store.entry(state.facts, id, {})
		var outcome := "deep_success" if check.get("changes", {}).get("outcome") == "deep" else "success"
		for row: Dictionary in source.tables.power_effects.values():
			if row.power_id == "POWER_ORACLE" and row.outcome == outcome and row.operation == "grant_preparation": preparation += source.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)
	if inputs.preparation != preparation or Powers.new(source).probability(inputs.person, inputs.domain, option, preparation) != result.probability: return ["Prayer response changed its calculated target"]
	var contract: Dictionary = scene.contracts[result.variant]
	var alternatives := _possible_effects(data.objects_before, contract)
	if alternatives.is_empty(): return ["Prayer attempt had no legal result"]
	var ranges: Array = _effect_ranges(alternatives, int(result.probability)) if option.get("disclosure") == "unknown" else []
	if data.get("ranges") != ranges or (option.get("disclosure") == "unknown" and ranges.is_empty()): return ["Prayer attempt changed its committed ranges"]
	if not data.get("metrics_before") is Dictionary or not result.get("actual_deltas") is Dictionary or not result.get("metric_sources") is Array: return ["Prayer result lost its actual deltas"]
	var before: Dictionary = data.metrics_before
	var expected := {"pollution": 0, "alert": 0, "sanity": 0}
	for field: String in expected:
		if not before.get(field) is int: return ["Prayer result lost its original metrics"]
	if result.outcome in ["success", "deep"]:
		for field: String in ["pollution", "alert"]: expected[field] = clampi(int(before[field]) + int(option[field]), 0, source.integer("attribute_max")) - int(before[field])
	elif result.outcome == "disaster":
		expected.alert = clampi(int(before.alert) + int(option.disaster_alert), 0, source.integer("attribute_max")) - int(before.alert)
		expected.sanity = maxi(0, int(before.sanity) - int(option.disaster_sanity)) - int(before.sanity)
	if result.actual_deltas != expected: return ["Prayer result reports requested rather than actual changes"]
	var actual := {"pollution": 0, "alert": 0, "sanity": 0}
	seen = {}
	for id: Variant in result.metric_sources:
		var metric: Dictionary = Store.entry(state.facts, str(id), {})
		var delta: Dictionary = metric.get("changes", {})
		var field: String = str(delta.get("field", ""))
		if metric.get("kind") != "prayer_delta" or metric.get("turn") != response.turn or delta.get("request") != scene.id or not field in actual or seen.has(field) or not id in response.causal_parents or delta.get("before") != before[field] or delta.get("after") != int(before[field]) + int(expected[field]) or delta.get("amount") != expected[field]: return ["Prayer result lost its actual metric receipt"]
		seen[field] = true; actual[field] = int(delta.amount)
	if actual != expected: return ["Prayer result omitted its actual metric receipt"]
	return []

static func _supported_version(value: String, current: String) -> bool:
	return value == current or value in LEGACY_VERSIONS

static func _possible_effects(objects: Dictionary, contract: Dictionary) -> Array:
	var result: Array = []
	if not matches(objects, contract.get("requires", {})): return result
	var effects: Array = contract.get("outcomes", []) if contract.get("disclosure", "clear") == "unknown" else [contract]
	for effect: Dictionary in effects:
		if not matches(objects, effect.get("requires", {})): continue
		var applied := updated(objects, effect.get("updates", {}))
		if not applied.ok: continue
		var maintenance: Dictionary = effect.get("maintenance", {})
		if not maintenance.is_empty():
			if not matches(applied.objects, maintenance.get("requires", {})): continue
			if not updated(applied.objects, maintenance.get("updates", {})).ok: continue
		result.append(effect)
	return result

static func _twist_seed(data: Dictionary, scene: Dictionary, variant: String) -> String:
	return str(data.rng_seed) + "/prayer-twist/" + str(scene.id) + "/" + str(scene.source) + "/" + variant + "/" + str(scene.get("content_version", data.version))

# Reserve one point per legal branch, then distribute the remaining points by
# largest remainder. Authored order breaks ties without any additional draw.
static func _effect_ranges(effects: Array, probability: int) -> Array:
	if effects.is_empty() or effects.size() > probability: return []
	var total := 0
	for effect: Dictionary in effects:
		if not effect.get("weight") is int or effect.weight < 1: return []
		total += int(effect.weight)
	var remaining := probability - effects.size()
	var counts: Array[int] = []
	var remainders: Array[int] = []
	var assigned := 0
	for effect: Dictionary in effects:
		var numerator := remaining * int(effect.weight)
		var share := int(floor(float(numerator) / float(total)))
		counts.append(1 + share); remainders.append(numerator % total); assigned += share
	for point: int in remaining - assigned:
		var best := 0
		for index: int in remainders.size():
			if remainders[index] > remainders[best]: best = index
		counts[best] += 1; remainders[best] = -1
	var ranges: Array = []
	var first := 1
	for index: int in effects.size():
		ranges.append({"id": effects[index].id, "first": first, "last": first + counts[index] - 1})
		first += counts[index]
	return ranges

static func _effect_for_roll(effects: Array, ranges: Array, roll: int) -> Dictionary:
	if ranges.is_empty(): return {}
	for index: int in ranges.size():
		if roll >= int(ranges[index].first) and roll <= int(ranges[index].last): return {"effect": effects[index], "roll": roll, "total": int(ranges[-1].last)}
	return {}

static func _draw_effect(effects: Array, seed_text: String) -> Dictionary:
	var total := 0
	for effect: Dictionary in effects: total += int(effect.weight)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_text.sha256_text().substr(0, 15).hex_to_int()
	var roll := rng.randi_range(1, total)
	var remaining := roll
	for effect: Dictionary in effects:
		remaining -= int(effect.weight)
		if remaining <= 0: return {"effect": effect, "roll": roll, "total": total}
	return {}
