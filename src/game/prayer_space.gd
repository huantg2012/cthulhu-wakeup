extends RefCounted
## Versioned lightweight situations. Every result mutates authored objects; timers
## consume those same states rather than narrating a second imaginary outcome.
const Store = preload("res://src/simulation/archive_store.gd")
const Powers = preload("res://src/game/powers.gd")
const Consequences = preload("res://src/game/prayer_consequences.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Voice = preload("res://src/presentation/prayer_response_voice.gd")
const Generator = preload("res://src/game/prayer_generator.gd")
const Compiler = preload("res://src/game/prayer_effect_compiler.gd")
const Capabilities = preload("res://src/game/prayer_capabilities.gd")
const SCHEMA := 1
const PREFIX := "PS-"
# Frozen schema-one contracts from the previous release remain executable.
const LEGACY_VERSIONS := ["abb8cb04d9c83177752602b7d867fca1e8e49df66a91a8112f696c7a7608795c", "5cb2fdef47e1cf68d173799cebb8c76503ea862f549113edfb855a9d603a7f3c", "f807ece037281daa504966f359818488991e79bf092f251601c8cd6892c865df", "17962fc214af5ab983b91e60ce5699caf7a536288da51cebced0b03a0c2f95f5", "a974406fe693f8c1343552eb0df1d601d965b065e1c1f38a25a63f7aa472476d", "47ec59f04c84674a3d056ff6bf8f8b3199eb8a013afeb68d8248454cb69db20c"]
var catalog: RefCounted
var content: RefCounted
var checks: RefCounted
var generator: RefCounted

func _init(source: RefCounted) -> void:
	catalog = source
	content = source.prayer_space
	checks = Powers.new(source)
	generator = Generator.new(content, catalog)

static func is_request(id: String) -> bool:
	return id.begins_with(PREFIX)

static func ledger(state: Dictionary) -> Dictionary:
	return state.get("prayer_system", {}).get("space", {})

static func entries(state: Dictionary) -> Array:
	var result: Array = []
	var data := ledger(state)
	for id: String in data.get("offered", []):
		var scene: Dictionary = data.get("scenes", {}).get(id, {})
		if not scene.is_empty() and scene.status == "open": result.append(entry(_current(data, scene)))
	return result

static func entry(scene: Dictionary) -> Dictionary:
	return {"id": scene.id, "card": {"id": scene.id, "content_id": scene.case_id, "visible_turn": scene.created, "due_turn": scene.due, "domain": scene.domain, "actors": scene.actors, "fact": scene.source}, "descriptor": {"space": true, "content_id": scene.case_id, "domain": scene.domain, "actors": scene.actors, "subjects": {"petitioner": scene.roles.petitioner}, "source": scene.source, "title": scene.title, "context": scene.context, "appeal": scene.appeal, "goal": scene.goal_text, "petitioner_role": scene.petitioner_role, "crisis": {"due": scene.crisis_due} if int(scene.get("crisis_due", -1)) >= 0 else {}}, "status": scene.status, "source": scene.source}

static func choices(state: Dictionary, id: String) -> Array:
	var data := ledger(state)
	var scene := _current(data, data.get("scenes", {}).get(id, {}))
	var visible: Array = []
	for choice: Dictionary in scene.get("choices", {}).values():
		if scene.has("situation_id"):
			var contract: Dictionary = scene.contracts[choice.id]
			if _possible_effects(scene.objects, contract).size() < (2 if contract.get("disclosure") == "unknown" else 1): continue
		var item: Dictionary = {}
		for field: String in ["id", "label", "operator", "cost", "whispers", "faith", "first_upkeep", "check_kind", "attribute", "difficulty", "hint", "irreversible", "duration", "upkeep_turns", "upkeep_stop", "approach", "intensity", "disclosure"]:
			if choice.has(field): item[field] = choice[field]
		if not scene.has("situation_id"): item.merge(Voice.wording(choice, scene.case_id, choice.id), true)
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
	var scene := _current(data, data.get("scenes", {}).get(id, {}))
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
		if _obsolete(scene): return _deny("原来的困境已经改变")
		if not matches(scene.objects, contract.requires): return _deny("此回应需要的对象或条件已改变")
		var minimum := 2 if scene.has("situation_id") and contract.get("disclosure") == "unknown" else 1
		var possible := _possible_effects(scene.objects, contract)
		if possible.size() < minimum: return _deny("此处境已经改变，无法再如此回应")
		if not _still_eligible(state, scene, possible, view.get("reader")): return _deny("原参与者或能力条件已经变化")
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
	return {"ok": true, "space": true, "request": id, "variant": variant, "actor": actor, "faith": faith, "first_upkeep": first_upkeep, "whispers": whispers, "probability": probability, "success_target": probability, "p": probability, "preparation": preparation, "preparations": preparations, "agent_source": "", "descriptor": entry(scene).descriptor, "hint": "" if dismiss else (selected.hint if scene.has("situation_id") else Voice.wording(selected, scene.case_id, variant).hint), "situation_revision": _situation(data, scene).get("revision", -1), "upkeep_turns": selected.get("upkeep_turns", 0), "upkeep_stop": selected.get("upkeep_stop", ""), "dismiss": dismiss, "disclosure": selected.get("disclosure", "clear"), "approach": selected.get("approach", ""), "intensity": selected.get("intensity", 0), "attention": attention}

func _still_eligible(state: Dictionary, scene: Dictionary, effects: Array, reader: RefCounted) -> bool:
	if not scene.has("situation_id"): return true
	var frame: Dictionary = content.generator_tables.frames[scene.generation_meta.frame]
	var history: RefCounted = reader._index if reader != null and reader.has_method("history_query") else reader
	var context := {"state": state, "history": history, "objects": scene.objects, "roles": scene.roles, "nouns": frame.nouns, "tags": Compiler.split(frame.capability_tags), "neighbor": scene.generation_meta.get("neighbor", ""), "catalog": catalog}
	if not Compiler.predicate(frame.get("predicates", {}), context): return false
	for effect: Dictionary in effects:
		if not Compiler.predicate(effect.get("predicates", {}), context): return false
		var capability: Dictionary = effect.get("capability", {})
		if not capability.is_empty() and not Capabilities.can_apply(state, capability, catalog): return false
	return true

func _snapshot(world: RefCounted, scene: Dictionary, kind: String, parents: Array, extra: Dictionary = {}) -> String:
	var copy := scene.duplicate(true)
	copy.erase("last_event")
	if scene.has("situation_id"):
		for field: String in ["objects", "crisis", "crisis_due", "crisis_done"]: copy.erase(field)
	var data: Dictionary = {"request": scene.id, "version": scene.get("content_version", ledger(world.state).version), "scene_after": copy}
	data.merge(extra, true)
	var source: String = world._record(kind, scene.domain, scene.roles.petitioner, scene.actors, parents, data)
	scene.last_event = source
	if scene.has("situation_id"):
		copy["last_event"] = source
		ledger(world.state).scenes[scene.id] = copy
		_persist_situation(world, scene, source)
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
	var miracle: String = world.introduce_fact("miracle", scene.domain, "", witnesses, [source], {
		"witnesses": witnesses, "public": effect.public, "prayer_space_source": source,
	}, witnesses, [], owner)
	if miracle.is_empty(): return false
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, "prayer/space/miracle/" + source, miracle)
	return true

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
	var scene := _current(data, data.scenes[plan.request])
	if scene.is_empty() or int(_situation(data, scene).get("revision", -1)) != int(plan.get("situation_revision", -1)): return false
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
	if alternatives.size() < (2 if scene.has("situation_id") and contract.get("disclosure") == "unknown" else 1) or not _still_eligible(world.state, scene, alternatives, world.history): return false
	var modern := selected.has("difficulty")
	var ranges: Array = _effect_ranges(alternatives, int(plan.probability)) if modern and contract.get("disclosure") == "unknown" else []
	if modern and (plan.probability < 0 or (contract.get("disclosure") == "unknown" and ranges.is_empty())): return false
	var sanity_target: String = contract.get("sanity_target", plan.actor)
	var before_metrics := _metrics(world.state, scene, sanity_target)
	var attempt := ""
	if modern:
		var person: Dictionary = Store.entry(world.state.npcs, plan.actor, {})
		var domain: Dictionary = world.state.domains[scene.domain]
		var check_inputs := {"person": {"sanity": person.sanity, selected.attribute: person[selected.attribute]}, "domain": {"tier": domain.tier, "barrier": domain.barrier, "alert": domain.alert}, "preparation": int(plan.preparation)}
		attempt = world._record("prayer_space_attempt", scene.domain, plan.actor, scene.actors, [scene.source, paid_id] + plan.preparations, {"request": scene.id, "variant": plan.variant, "payment": paid_id, "probability": plan.probability, "preparations": plan.preparations, "check_inputs": check_inputs, "objects_before": scene.objects.duplicate(true), "metrics_before": before_metrics, "sanity_target": sanity_target, "ranges": ranges})
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
		for step: int in contract.get("followup", []).size():
			var next: Dictionary = contract.followup[step]
			var scheduled := next.duplicate(true)
			scheduled["due"] = int(world.state.turn) + int(next.delay)
			if next.has("consequence"): scheduled["step"] = step
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
		var metrics: Dictionary = contract.get("metrics", selected)
		metric_sources.append(_metric(world, scene, "pollution", int(metrics.pollution), metric_parent))
		metric_sources.append(_metric(world, scene, "alert", int(metrics.alert), metric_parent))
		var sanity_loss := int(metrics.get("success_sanity", selected.get("success_sanity", 0)))
		if sanity_loss > 0:
			var subject: Dictionary = world.mutable_npc(sanity_target)
			subject.sanity = maxi(0, int(subject.sanity) - sanity_loss)
			metric_sources.append(world._record("prayer_delta", scene.domain, plan.actor, [sanity_target], [metric_parent], {"request": scene.id, "field": "sanity", "before": before_metrics.sanity, "after": subject.sanity, "amount": int(subject.sanity) - int(before_metrics.sanity)}))
	elif outcome == "disaster":
		var person: Dictionary = world.mutable_npc(sanity_target)
		person.sanity = maxi(0, int(person.sanity) - int(selected.disaster_sanity))
		metric_sources.append(world._record("prayer_delta", scene.domain, plan.actor, [sanity_target], [metric_parent], {"request": scene.id, "field": "sanity", "before": before_metrics.sanity, "after": person.sanity, "amount": int(person.sanity) - int(before_metrics.sanity)}))
		metric_sources.append(_metric(world, scene, "alert", int(selected.disaster_alert), metric_parent))
	var after_metrics := _metrics(world.state, scene, sanity_target)
	var actual_deltas := {}
	for field: String in before_metrics: actual_deltas[field] = int(after_metrics[field]) - int(before_metrics[field])
	scene.status = "answered"
	scene["response"] = "FACT-%08d" % int(world.state.next_fact)
	var result := _snapshot(world, scene, "prayer_space_result", [scene.source, paid_id] + ([] if checked.is_empty() else [checked]) + ([] if upkeep_payment.is_empty() else [upkeep_payment]) + ([] if twist.is_empty() else [twist]) + metric_sources, {"attempt": attempt, "check": checked, "twist": twist, "disclosure": selected.get("disclosure", "clear"), "title": scene.title, "choice_label": selected.label, "variant": plan.variant, "outcome": outcome, "probability": plan.probability, "success_target": plan.probability, "roll": roll, "actual_deltas": actual_deltas, "metric_sources": metric_sources, "effect": revealed_effect if outcome in ["success", "deep"] else "此次介入未生效，原处境继续。", "tradeoff": revealed_tradeoff if outcome in ["success", "deep"] else (selected.disaster if outcome == "disaster" else "已付费用不返还。"), "state_changes": changes, "goal_reached": scene.goal_reached, "pending_count": scene.pending.size(), "maintenance_remaining": int(scene.maintenance.get("remaining", 0)), "maintenance_payment": upkeep_payment, "payment": paid_id, "faith_cost": plan.faith, "whispers_cost": plan.whispers, "capability": contract.get("capability", {}) if outcome in ["success", "deep"] else {}})
	if scene.has("situation_id"):
		world._know(plan.actor, result)
		for delta: Dictionary in changes:
			var affected: String = scene.objects.get(delta.object, {}).get("role", "")
			if not affected.is_empty() and affected in scene.actors: world._know(affected, result)
	else:
		for person: String in scene.actors: world._know(person, result)
	if not manifestation.is_empty() and not _record_miracle(world, scene, manifestation, result, owner): return false
	if outcome in ["success", "deep"] and not Consequences.publish(world, scene, contract.get("consequence", {}), result, -1): return false
	if scene.has("situation_id") and outcome in ["success", "deep"]:
		var capability: Dictionary = contract.get("capability", {})
		if not capability.is_empty() and not Capabilities.apply(world, capability, result): return false
		if not changes.is_empty(): _follow_up(world, scene, contract, result)
		_close_obsolete(world, scene.situation_id, result)
	data.offered.erase(scene.id)
	return true

static func _metrics(state: Dictionary, scene: Dictionary, sanity_target: String) -> Dictionary:
	return {"pollution": int(state.domains[scene.domain].pollution), "alert": int(state.domains[scene.domain].alert), "sanity": int(Store.entry(state.npcs, sanity_target, {}).get("sanity", 0))}

## The original ledger keeps its format. Generated requests own frozen choices
## and receipts, while their objects and clock live in one shared situation.
static func _situation(data: Dictionary, scene: Dictionary) -> Dictionary:
	return data.get("generation", {}).get("situations", {}).get(scene.get("situation_id", ""), {})

static func _current(data: Dictionary, scene: Dictionary) -> Dictionary:
	if not scene.has("situation_id"): return scene
	var root := _situation(data, scene)
	if root.is_empty(): return {}
	var current := scene.duplicate(true)
	for field: String in ["objects", "crisis", "crisis_due", "crisis_done"]:
		current[field] = root[field]
	return current

func _persist_situation(world: RefCounted, scene: Dictionary, cause: String) -> void:
	if not scene.has("situation_id"): return
	var root := _situation(ledger(world.state), scene)
	var changed := false
	for field: String in ["objects", "crisis_due", "crisis_done"]:
		if root[field] != scene[field]:
			root[field] = scene[field]
			changed = true
	if changed: _record_situation(world, root, cause)

func _record_situation(world: RefCounted, root: Dictionary, cause: String) -> void:
	var parent: String = root.get("last_event", "")
	root.revision += 1
	var frozen := root.duplicate(true)
	frozen.erase("last_event")
	root["last_event"] = world._record("prayer_generator_situation", root.domain, "", [], [cause] if parent.is_empty() or parent == cause else [parent, cause], {"situation": frozen})

static func draft_situation(scene: Dictionary) -> Dictionary:
	var meta: Dictionary = scene.generation_meta
	var root_id: String = meta.root_key
	return {"id": root_id, "root_id": root_id, "root_key": meta.root_key, "domain": scene.domain, "frame": meta.frame, "grammar": meta.grammar, "template": meta.get("template", ""), "neighbor": meta.get("neighbor", ""), "schema": 2, "roles": meta.get("roles", scene.roles).duplicate(true), "objects": scene.objects.duplicate(true), "facts": meta.get("facts", {}), "crisis": scene.crisis, "crisis_due": scene.crisis_due, "crisis_done": scene.crisis_done, "created": scene.created, "revision": 0, "status": "active", "source": "", "depth": 0}

func _register(world: RefCounted, draft: Dictionary) -> Dictionary:
	var data := ledger(world.state)
	var generation: Dictionary = data.generation
	var scene := draft.duplicate(true)
	var meta: Dictionary = scene.generation_meta
	var root_id: String = meta.get("situation_id", "")
	if root_id.is_empty(): root_id = str(meta.root_key)
	var root: Dictionary = generation.situations.get(root_id, {})
	if root.is_empty():
		var foundation: String = world.state.domains[scene.domain].origin
		root = draft_situation(scene)
		root.source = "FACT-%08d" % int(world.state.next_fact)
		generation.situations[root_id] = root
		_record_situation(world, root, foundation)
	if root.objects != scene.objects or root.crisis_due != scene.crisis_due: return {}
	if int(meta.get("expected_revision", -1)) >= 0 and int(meta.expected_revision) != root.revision: return {}
	for role: String in root.roles:
		if role != "petitioner" and root.roles[role] != scene.roles.get(role): return {}
	var origin: String = root.last_event
	var followup: String = meta.get("followup_source", "")
	if not followup.is_empty():
		if root.get("opportunity", {}).get("source") != followup: return {}
		root.depth = int(root.opportunity.depth)
		root.erase("opportunity")
		_record_situation(world, root, followup)
		origin = root.last_event
	scene["schema"] = 2
	scene["situation_id"] = root_id
	scene["content_version"] = generation.policy_version
	scene["id"] = PREFIX + "%08d" % int(data.next_id)
	scene["source"] = world._record("prayer_space_situation", scene.domain, scene.roles.petitioner, scene.actors, [origin], {"request": scene.id, "version": generation.policy_version, "case_id": scene.case_id, "roles": scene.roles, "created": scene.created, "due": scene.due, "situation_id": root_id, "revision": root.revision})
	scene["registration"] = "FACT-%08d" % int(world.state.next_fact)
	_snapshot(world, scene, "prayer_space_registered", [scene.source], {"title": scene.title})
	data.next_id += 1
	return data.scenes[scene.id]

func _follow_up(world: RefCounted, scene: Dictionary, contract: Dictionary, result: String) -> void:
	if not scene.has("situation_id"): return
	var intents: Array = contract.get("followup_intents", [])
	if intents.is_empty() or not str(contract.get("consequence", {}).get("event", "")).is_empty(): return
	for delayed: Dictionary in contract.get("followup", []):
		if not str(delayed.get("consequence", {}).get("event", "")).is_empty(): return
	var root := _situation(ledger(world.state), scene)
	if root.depth >= generator.parameter("situation_depth_limit") or root.has("opportunity"): return
	root["opportunity"] = {"source": result, "eligible_intents": intents.duplicate(), "depth": int(root.depth) + 1}
	_record_situation(world, root, result)

func _close_obsolete(world: RefCounted, root_id: String, cause: String) -> void:
	var data := ledger(world.state)
	for stored: Dictionary in data.scenes.values():
		if stored.get("situation_id") != root_id or stored.status != "open": continue
		var scene := _current(data, stored)
		if not _obsolete(scene): continue
		scene.status = "unavailable"
		data.offered.erase(scene.id)
		_snapshot(world, scene, "prayer_space_closed", [scene.last_event, cause], {"reason": "situation_changed"})

static func _obsolete(scene: Dictionary) -> bool:
	var goal: Dictionary = scene.get("generation_meta", {}).get("goal", {})
	if not goal.is_empty() and matches(scene.objects, goal): return true
	if not scene.has("situation_id"): return false
	for contract: Dictionary in scene.contracts.values():
		var minimum := 2 if contract.get("disclosure") == "unknown" else 1
		if _possible_effects(scene.objects, contract).size() >= minimum: return false
	return true

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
	if not data.has("generation"):
		var policy: String = world._record("prayer_generator_adopted", "", "", [], [data.installed], {"schema": 2, "version": generator.version})
		data["generation"] = {"schema": 2, "policy_version": generator.version, "source": policy, "rng_seed": data.rng_seed, "draw": 0, "situations": {}, "recent": [], "cooldowns": {}, "people_cooldowns": {}, "used": {}}
	var generation: Dictionary = data.generation
	if generation.policy_version != generator.version: return false
	data.offered = []
	data.offer_turn = int(world.state.turn)
	# Parent Prayers owns the legacy minimum supply and cross-world slots.
	var limit := new_limit
	var request_ids: Array = data.scenes.keys()
	request_ids.sort()
	for id: String in request_ids:
		var stored: Dictionary = data.scenes[id]
		if stored.status != "open": continue
		var scene := _current(data, stored)
		if scene.is_empty(): return false
		if not _alive(world.state, scene.actors, scene.domain) or _obsolete(scene):
			scene.status = "unavailable"
			_snapshot(world, scene, "prayer_space_closed", [scene.last_event], {"reason": "subject_or_situation_changed"})
		elif scene.due >= world.state.turn and data.offered.size() < limit: data.offered.append(id)
	if data.offered.size() < limit and generation.get("attempted_turn", -1) != world.state.turn:
		var recent: Array = generation.recent.filter(func(item: Dictionary) -> bool: return int(item.turn) + content.parameter("recent_memory") >= int(world.state.turn))
		generation.recent = recent
		var proposal: Dictionary = generator.propose(world.state, generation, {}, world.history)
		generation.draw = proposal.draw
		generation["attempted_turn"] = int(world.state.turn)
		var candidates: Array = proposal.candidates
		var new_roots := 0
		while data.offered.size() < limit and not candidates.is_empty():
			var index: int = generator.pick(candidates, str(generation.rng_seed), int(generation.draw))
			if index < 0 or index >= candidates.size(): break
			var draft: Dictionary = candidates.pop_at(index)
			generation.draw += 1
			var meta: Dictionary = draft.generation_meta
			var creates_root: bool = not generation.situations.has(str(meta.get("situation_id", meta.root_key))) and not generation.situations.has(str(meta.root_key))
			if creates_root and new_roots >= generator.parameter("background_commit_limit"): continue
			# Drafts have no authorization yet. Budget-check their participants
			# here; execution still uses the registered-source admission path.
			var need: Dictionary = world.attention.preview(world.state, {"focus": [draft.domain], "people": draft.actors, "members": [], "identities": []})
			if not need.get("ok", false): continue
			if int(generation.people_cooldowns.get(draft.roles.petitioner, -1)) > world.state.turn and str(meta.get("followup_source", "")).is_empty(): continue
			if creates_root and int(generation.cooldowns.get(draft.domain + "/" + str(meta.grammar), -1)) > world.state.turn: continue
			if not meta.get("urgent", false) and str(meta.get("followup_source", "")).is_empty() and generation.recent.any(func(item: Dictionary) -> bool: return item.turn == world.state.turn and item.decision_signature == meta.decision_signature): continue
			var scene := _register(world, draft)
			if scene.is_empty(): continue
			if creates_root: new_roots += 1
			data.offered.append(scene.id)
			generation.people_cooldowns[scene.roles.petitioner] = int(world.state.turn) + content.parameter("petitioner_cooldown")
			generation.cooldowns[scene.domain + "/" + str(meta.grammar)] = int(world.state.turn) + content.parameter("scene_cooldown")
			generation.used[scene.situation_id + "/" + str(scene.roles.petitioner) + "/" + str(meta.semantic_signature)] = scene.source
			generation.recent.append({"turn": int(world.state.turn), "domain": scene.domain, "semantic_signature": meta.semantic_signature, "decision_signature": meta.decision_signature})
		var batch_parent: String = generation.get("batch", generation.source)
		generation["batch"] = world._record("prayer_generator_batch", "", "", [], [batch_parent], {"turn": generation.attempted_turn, "cursor_digest": _cursor_digest(generation)})
	return true

func deadlines(world: RefCounted, owner: Object) -> bool:
	var data := ledger(world.state)
	if data.is_empty(): return true
	world.stage_collections(["prayer_system", "domains", "npcs"])
	var recovered := {}
	for stored: Dictionary in data.scenes.values():
		var scene := _current(data, stored)
		if scene.is_empty(): return false
		var changes: Array = []
		var changed := false
		var manifestations: Array = []
		var consequences: Array = []
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
			var updates: Dictionary = item.get("updates", {})
			var eligible := active and matches(scene.objects, item.get("requires", {}))
			if not eligible:
				# A person's temporary restriction expires even when another
				# participant can no longer take part in the scheduled scene.
				updates = updates.duplicate()
				for path: String in updates.keys():
					var field := path.get_slice(".", 1)
					if field not in ["can_act", "can_sleep"] or updates[path] != true:
						updates.erase(path)
				if not updates.is_empty():
					var released := _apply(scene, updates)
					if not released.ok: return false
					changes.append_array(released.changes)
			if eligible:
				var applied := _apply(scene, updates)
				if not applied.ok: return false
				changes.append_array(applied.changes)
				var manifestation: Dictionary = item.get("miracle", {})
				if not manifestation.is_empty() and _manifested(applied):
					manifestations.append(manifestation)
					descriptions.append(item.effect)
				var rule: Dictionary = item.get("consequence", {})
				if not rule.is_empty() and Consequences.matched(rule.change, applied.changes):
					consequences.append(item)
					descriptions.append(rule.title)
			changed = true
		scene.pending = pending
		if not scene.crisis_done and scene.crisis_due >= 0 and int(scene.crisis_due) <= int(world.state.turn):
			if matches(scene.objects, scene.crisis.get("requires", {})):
				var applied := _apply(scene, scene.crisis.get("updates", {}))
				if not applied.ok: return false
				changes.append_array(applied.changes)
			scene.crisis_done = true; changed = true
		if scene.status == "open" and (scene.due <= world.state.turn or not active or _obsolete(scene)):
			if active and not _obsolete(scene):
				var expired := _apply(scene, scene.expiry_updates)
				if not expired.ok: return false
				changes.append_array(expired.changes)
			scene.status = "expired" if active and not _obsolete(scene) else "unavailable"
			data.offered.erase(scene.id); changed = true
		if scene.has("selected_goal") and not scene.selected_goal.is_empty():
			var reached: bool = matches(scene.objects, scene.selected_goal)
			if reached != scene.goal_reached: scene.goal_reached = reached; changed = true
		if changed:
			for delta: Dictionary in changes:
				if delta.field not in ["can_act", "can_sleep"] or delta.before != false or delta.after != true: continue
				var person: String = str(scene.objects[delta.object].get("role", ""))
				if person.is_empty() or not scene.has("response"): continue
				if not recovered.has(person): recovered[person] = {}
				recovered[person][delta.field] = scene.response
			var description: String = scene.expiry if scene.status == "expired" else ("祈求的目标已达成。" if scene.goal_reached else "当地处境发生变化，约定已按本轮条件处理。")
			var progress := {"title": scene.title, "state_changes": changes, "goal_reached": scene.goal_reached, "pending_count": scene.pending.size(), "maintenance_remaining": int(scene.maintenance.get("remaining", 0)), "effect": description}
			if not manifestations.is_empty():
				progress["effect"] = " ".join(descriptions)
				progress["manifestation_of"] = scene.response
				parents.append(scene.response)
			if not consequences.is_empty():
				progress["effect"] = " ".join(descriptions)
				progress["consequence_of"] = scene.response
				parents.append(scene.response)
			var source := _snapshot(world, scene, "prayer_space_progress", parents, progress)
			for manifestation: Dictionary in manifestations:
				if not _record_miracle(world, scene, manifestation, source, owner): return false
			for item: Dictionary in consequences:
				if not Consequences.publish(world, scene, item.consequence, source, item.step): return false
	for id: String in recovered:
		var person: Dictionary = Store.entry(world.state.npcs, id, {})
		if person.get("status") != "active": continue
		var restored: Dictionary = {}
		for field: String in recovered[id]:
			if PrayerRules.space_allows(world.state, id, field): restored[field] = recovered[id][field]
		if not restored.is_empty():
			world._record("prayer_space_recovered", person.domain, id, [id], restored.values(), {"restored": restored})
	return true

static func _cursor_digest(generation: Dictionary) -> String:
	return JSON.stringify([generation.draw, generation.recent, generation.used, generation.cooldowns, generation.people_cooldowns]).sha256_text()

static func _validate_generation(state: Dictionary, data: Dictionary, version: String) -> Array[String]:
	if not data.has("generation"): return []
	var generation: Variant = data.generation
	if not generation is Dictionary or generation.get("schema") != 2 or generation.get("policy_version") != version: return ["Unknown prayer generator policy"]
	var policy: Dictionary = Store.entry(state.facts, str(generation.get("source", "")), {})
	if policy.get("kind") != "prayer_generator_adopted" or policy.changes.get("version") != version or not data.installed in policy.causal_parents: return ["Missing prayer generator adoption"]
	for field: String in ["situations", "cooldowns", "people_cooldowns", "used"]:
		if not generation.get(field) is Dictionary: return ["Malformed prayer generator ledger"]
	if not generation.get("draw") is int or generation.draw < 0 or generation.get("rng_seed") != data.rng_seed or not generation.get("recent") is Array: return ["Malformed prayer generator cursor"]
	if generation.has("batch"):
		var batch: Dictionary = Store.entry(state.facts, str(generation.batch), {})
		if batch.get("kind") != "prayer_generator_batch" or batch.changes.get("turn") != generation.get("attempted_turn") or batch.changes.get("cursor_digest") != _cursor_digest(generation): return ["Prayer generator cursor changed outside supply"]
	elif generation.draw != 0 or not generation.recent.is_empty() or not generation.used.is_empty(): return ["Prayer generator cursor lacks its first batch"]
	for id: String in generation.situations:
		var root: Variant = generation.situations[id]
		if not root is Dictionary or root.get("id") != id or root.get("root_id") != id or not root.get("objects") is Dictionary or not state.domains.has(root.get("domain")) or not root.get("revision") is int or root.revision < 1: return ["Invalid shared prayer situation"]
		var first: Dictionary = Store.entry(state.facts, str(root.get("source", "")), {})
		var last: Dictionary = Store.entry(state.facts, str(root.get("last_event", "")), {})
		var frozen: Dictionary = root.duplicate(true)
		frozen.erase("last_event")
		if first.get("kind") != "prayer_generator_situation" or first.changes.get("situation", {}).get("id") != id or first.changes.situation.get("revision") != 1 or last.get("kind") != "prayer_generator_situation" or last.changes.get("situation") != frozen: return ["Shared prayer situation lost its source or revision"]
		for object: Variant in root.objects.values():
			if not object is Dictionary or (object.has("role") and not Store.has(state.npcs, str(object.role))): return ["Shared prayer situation references an invented participant"]
		if root.has("opportunity"):
			var result: Dictionary = Store.entry(state.facts, str(root.opportunity.get("source", "")), {})
			if result.get("kind") != "prayer_space_result" or not result.changes.get("outcome") in ["success", "deep"] or result.changes.get("scene_after", {}).get("situation_id") != id or result.changes.get("state_changes", []).is_empty() or root.opportunity.get("eligible_intents") != Consequences.selected(result).get("followup_intents") or root.opportunity.get("depth") != root.depth + 1: return ["Invented prayer follow-up opportunity"]
	return []

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
	var generator_version := str(content_source.prayer_space.generator_version)
	var generation_errors := _validate_generation(state, data, generator_version)
	if not generation_errors.is_empty(): return generation_errors
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
		var generated: bool = scene.has("situation_id")
		var valid_version: bool = original.changes.get("version") == generator_version if generated else _supported_version(str(original.changes.get("version", "")), content_source.prayer_space.version)
		if generated:
			var root := _situation(data, scene)
			if scene.get("schema") != 2 or root.is_empty() or root.domain != scene.domain or original.changes.get("situation_id") != scene.situation_id or scene.has("objects"): return ["Prayer request lost its shared situation"]
			var root_at_admission: Dictionary = Store.entry(state.facts, str(original.causal_parents[0]), {}) if original.causal_parents.size() == 1 else {}
			if root_at_admission.get("kind") != "prayer_generator_situation" or root_at_admission.changes.get("situation", {}).get("id") != scene.situation_id or root_at_admission.changes.situation.get("revision") != original.changes.get("revision"): return ["Prayer request lost its original shared revision"]
		if not valid_version or original.changes.get("version") != scene.get("content_version", data.version) or latest.changes.get("version") != original.changes.get("version"): return ["Prayer space lost its frozen content version"]
		if scene.get("case_id") != original.changes.get("case_id") or scene.get("roles") != original.changes.get("roles") or scene.get("due") != original.changes.get("due"): return ["Prayer space changed its original subjects or request deadline"]
		if scene.has("registration"):
			var registration: Dictionary = Store.entry(state.facts, str(scene.registration), {})
			if registration.get("kind") != "prayer_space_registered" or not scene.source in registration.get("causal_parents", []) or registration.changes.get("request") != id: return ["Prayer space lost its frozen registration"]
			for field: String in (["choices", "contracts", "generation_meta", "title", "appeal", "situation_id"] if generated else ["choices", "contracts"]):
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
		var chosen := Consequences.selected(response)
		var metrics: Dictionary = chosen.get("metrics", option)
		for field: String in ["pollution", "alert"]: expected[field] = clampi(int(before[field]) + int(metrics[field]), 0, source.integer("attribute_max")) - int(before[field])
		expected.sanity = maxi(0, int(before.sanity) - int(metrics.get("success_sanity", option.get("success_sanity", 0)))) - int(before.sanity)
		if scene.has("situation_id"):
			if data.get("sanity_target") != contract.get("sanity_target", scene.roles.petitioner) or not data.sanity_target in scene.actors: return ["Generated prayer changed its sanity recipient"]
			var applied := updated(data.objects_before, chosen.get("updates", {}))
			if not applied.ok: return ["Generated prayer cannot replay its chosen writes"]
			var upkeep: Dictionary = chosen.get("maintenance", {})
			var changes: Array = applied.changes
			if not upkeep.is_empty():
				var first := updated(applied.objects, upkeep.get("updates", {}))
				var receipt: Dictionary = Store.entry(state.facts, str(result.get("maintenance_payment", "")), {})
				if not first.ok or receipt.get("kind") != "prayer_space_maintenance" or receipt.changes.get("request") != scene.id or receipt.changes.get("faith_cost") != upkeep.faith or receipt.changes.get("installment") != 1 or not receipt.id in response.causal_parents: return ["Generated prayer lost its first upkeep payment"]
				changes.append_array(first.changes)
			if _change_keys(changes) != _change_keys(result.get("state_changes", [])) or chosen.get("capability", {}) != result.get("capability", {}): return ["Generated prayer changed its actual effect receipt"]
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

static func _change_keys(changes: Array) -> Array:
	var keys := changes.map(func(change: Dictionary) -> String: return JSON.stringify(change))
	keys.sort()
	return keys

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
