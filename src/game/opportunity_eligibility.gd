extends RefCounted
## Pure interpretation of one existing entry. The caller supplies the actual
## ledger; this is neither an authorization issuer nor an opportunity scheduler.
const Selectors = preload("res://src/game/entry_selectors.gd")
const Sources = preload("res://src/game/prayer_sources.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const Admission = preload("res://src/game/action_admission.gd")
const VERSION: String = "opportunity-eligibility/1"

static func _deny(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _detached(view: Dictionary) -> Dictionary:
	var copy: Dictionary = view.duplicate(true)
	copy.world = view.world.duplicate(true)
	copy.turn = view.turn.duplicate(true)
	return copy

static func fields(view: Dictionary, knowledge: Dictionary, modules: Dictionary, entry: String, selection: Dictionary = {}, label: Callable = Callable()) -> Dictionary:
	return Selectors.fields(Selectors.context(_detached(view), knowledge, modules, label), entry, selection)

static func query(view: Dictionary, knowledge: Dictionary, modules: Dictionary, entry: String, selection: Dictionary = {}) -> Dictionary:
	if not view.get("world") is Dictionary or not view.get("turn") is Dictionary or not view.has("catalog") or not view.has("attention"): return _deny("Missing formal eligibility read view")
	var current: Dictionary = _detached(view)
	var key: String = entry
	var chosen: Dictionary = selection.duplicate(true)
	# Stable route IDs are aliases of installed original handlers, not new rules.
	if key in ["ROUTE_GUIDED_DREAM", "route/ROUTE_GUIDED_DREAM"]:
		key = "POWER_DREAM"
	elif key in ["ROUTE_PACT_PERFORMANCE", "route/ROUTE_PACT_PERFORMANCE"]:
		var request: String = str(chosen.get("target", ""))
		var fixed: Dictionary = current.world.get("prayer_system", {}).get("requests", {}).get(request, {})
		if fixed.get("card", {}).get("content_id") != "PRAYER_06": return _deny("当前没有此行动")
		key = "prayer/" + request + "/deep"; chosen = {}
	elif key.begins_with("ROUTE_"):
		key = "route/" + key
	if key in ["SESSION_REST", "SESSION_SET_ECONOMY_PLAN"]:
		return _command(current, knowledge, modules, key, chosen)
	if key.begins_with("route/") and key != "route/context": chosen["operation"] = key.trim_prefix("route/")
	var options: Dictionary = Selectors.fields(Selectors.context(current, knowledge, modules), key, chosen)
	if not options.ok: return options
	var selected: Dictionary = Selectors.select(options.fields, chosen)
	if not selected.ok: return selected
	var payload: Dictionary = selected.payload
	var parts: PackedStringArray = key.split("/")
	var participant: String = ""; var action: String = ""; var op: String = "act"
	var result: Dictionary = {}; var irreversible: bool = false
	if key.begins_with("POWER_"):
		participant = "cults" if key == "POWER_APPOINT" else "powers"
		action = "appoint" if key == "POWER_APPOINT" else key
		result = modules[participant].handle(current, {"slot": "actions", "operation": "act", "action": action, "payload": payload})
		irreversible = key in ["POWER_SACRIFICE", "POWER_MANIFEST", "POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]
	elif parts[0] == "route":
		participant = "progression_routes"; action = str(payload.get("operation", ""))
		payload.erase("operation"); payload.erase("domain")
		result = modules[participant].handle(current, {"slot": "actions", "operation": "act", "action": action, "payload": payload})
		if result.get("ok", false):
			var plan: Dictionary = result.effects[0].plan
			if plan.mode in ["memory_circle", "pact_agreement"] and Sources.capacity_blocked(current.world, plan.people, "PRAYER_07" if plan.mode == "memory_circle" else "PRAYER_06", current.catalog, current.attention): return _deny("No current capacity for this fixed request")
	elif parts[0] == "prayer":
		participant = "prayers"; action = "respond"
		payload["request"] = parts[1]; payload["variant"] = parts[2]
		result = modules.prayers.handle(current, {"slot": "actions", "operation": "act", "action": action, "payload": payload})
		irreversible = _prayer_irreversible(current, parts[1], parts[2])
	elif parts[0] == "event":
		participant = "events"; action = parts[2]; op = "resolve_event"
		result = modules.events.prepare(current, parts[1], action, false, payload)
		irreversible = true
	elif parts[0] == "relic":
		participant = "relics"; action = parts[1]; payload.erase("domain")
		result = modules.relics.handle(current, {"slot": "actions", "operation": "act", "action": action, "payload": payload})
		irreversible = action in ["disassemble", "unbind"]
	elif parts[0] == "opportunity":
		participant = "events"; action = "opportunity"
		payload["opportunity"] = parts[1]; payload["option"] = parts[2]
		result = modules.events.prepare_opportunity(current, payload)
	elif key == "cults/transfer_material":
		participant = "cults"; action = "transfer_material"
		result = modules.cults.handle(current, {"slot": "actions", "operation": "act", "action": action, "payload": payload})
	elif parts[0] == "attention":
		payload["kind"] = parts[1]
		result = attention(current, payload)
		return {"ok": true, "op": "attention", "fields": {"command": payload}, "preview": result, "irreversible": false, "version": VERSION} if result.ok else result
	else: return _deny("Unknown action entry")
	if not result.get("ok", false): return _deny(str(result.get("error", "Current subject, source or resources do not meet the action requirements")))
	var prepared: Dictionary = _admitted(current, result)
	if not prepared.ok: return prepared
	var command: Dictionary = {"participant": participant, "action": action, "payload": payload}
	if op == "resolve_event": command = {"event": parts[1], "action": action, "payload": payload}
	return {"ok": true, "op": op, "fields": command, "preview": prepared.preview, "plan": prepared.plan, "irreversible": irreversible, "version": VERSION}

static func _admitted(view: Dictionary, declaration: Dictionary) -> Dictionary:
	var meta: Dictionary = declaration.get("meta", {})
	var state: Dictionary = view.world
	var valid: Dictionary = Admission.validate(state, view.turn, meta, view.catalog, false, view.get("reader"))
	if not valid.ok: return valid
	var actor: String = str(meta.get("actor", ""))
	var needs: Dictionary = view.attention.preview_needs(state, meta.get("attention", {}), declaration.get("effects", []), actor)
	if not needs.ok: return needs
	var plan: Dictionary = declaration.get("plan", {})
	if plan.is_empty() and not declaration.get("effects", []).is_empty(): plan = declaration.effects[0].get("plan", {})
	var preview: Dictionary = declaration.get("preview", plan).duplicate(true)
	if not preview.has("faith") and not preview.has("faith_cost"): preview["faith"] = int(meta.get("faith_cost", 0))
	if not preview.has("whispers"): preview["whispers"] = int(meta.get("whispers_cost", 0))
	preview["needs"] = needs
	return {"ok": true, "preview": preview, "plan": plan.duplicate(true)}

static func _prayer_irreversible(view: Dictionary, request: String, variant: String) -> bool:
	if variant == "deep": return true
	var entry: Dictionary = view.world.prayer_system.requests.get(request, {})
	for row: Dictionary in view.catalog.tables.prayer_effects.values():
		if not row.prayer_id in [entry.get("card", {}).get("content_id", ""), "*"] or not row.variant in [variant, "both"] or row.stage == "expiry": continue
		if row.operation in ["enroll", "withdraw", "vacate", "learn", "fulfill", "memory", "recovery"]: return true
	return false

static func _command(view: Dictionary, knowledge: Dictionary, modules: Dictionary, entry: String, payload: Dictionary) -> Dictionary:
	if view.turn.get("phase") != "actions" or not modules.has("economy"): return _deny("当前没有此行动")
	if entry == "SESSION_REST":
		if not payload.is_empty(): return _deny("Unknown rest argument")
		var rest: Dictionary = modules.economy.preview_rest(view.world, view.turn)
		return {"ok": true, "op": "rest", "fields": {}, "preview": rest, "irreversible": false, "version": VERSION} if rest.ok else rest
	var plan: Dictionary = modules.economy.validate_plan(view, payload)
	if not plan.ok: return plan
	var context: Dictionary = Selectors.context(view, knowledge, modules)
	for id: String in payload.get("strategies", {}):
		if not id in Selectors._objects(context, "cults", ""): return _deny("Unknown cult or strategy")
	for field: String in ["anchor_priority", "refuse_anchors"]:
		for id: String in payload.get(field, []):
			if not id in Selectors._objects(context, "anchors", ""): return _deny("Unknown or repeated anchor")
	return {"ok": true, "op": "set_plan", "fields": {"participant": "economy", "payload": payload.duplicate(true)}, "preview": plan, "irreversible": false, "version": VERSION} if plan.ok else plan

static func attention(view: Dictionary, command: Dictionary) -> Dictionary:
	# Original attention predicate over this detached read view.
	if view.has("reader"):
		var id: String = str(command.get("npc", ""))
		if not id.is_empty():
			var person: Dictionary = view.reader.entity("npcs", id)
			if person.get("ok", false): view.world.npcs[id] = person.item
		var references: Array = [str(command.get("source", "")), str(Store.entry(view.world.npcs, id, {}).get("binding_source", ""))]
		for source: String in references:
			if source.is_empty(): continue
			var fact: Dictionary = view.reader.fact(source)
			if fact.get("ok", false): view.world.facts[source] = fact.item
	if not view.attention.enabled(view.world): return {"ok": false, "error": "Hybrid attention unavailable"}
	var kind: String = str(command.get("kind", ""))
	if kind in ["release_focus", "release_project"]:
		var valid: bool = command.get("domain", "") in view.world.simulation.focused if kind == "release_focus" else view.world.attention.reservations.has(str(command.get("token", "")))
		return {"ok": valid, "error": "Unknown held focus/project" if not valid else ""}
	var needs: Dictionary = {"focus": [], "people": [], "members": [], "identities": [], "source": command.get("source", "")}
	if kind == "focus":
		if not view.world.domains.has(str(command.get("domain", ""))): return {"ok": false, "error": "Unknown focus domain"}
		needs.focus = [command.domain]; needs.source = view.world.domains[command.domain].origin
	elif kind == "enroll":
		var id: String = str(command.get("npc", ""))
		if not Store.has(view.world.npcs, id) or not Store.has(view.world.facts, str(needs.source)): return {"ok": false, "error": "Missing applicant or dedication"}
		var person: Dictionary = Store.entry(view.world.npcs, id)
		var fact: Dictionary = Store.entry(view.world.facts, needs.source)
		var reachable: bool = person.domain in view.world.simulation.focused
		for domain: String in view.world.simulation.focused: reachable = reachable or person.domain in view.world.domains[domain].neighbors
		if person.status != "active" or person.loyalty < view.catalog.integer("loyalty_follower_threshold") or fact.kind != "member_dedication" or (Store.entry(view.world.facts, person.binding_source).kind == "member_left" and str(needs.source) <= str(person.binding_source)) or fact.domain != person.domain or not id in fact.targets or not reachable: return {"ok": false, "error": "Applicant needs living reachable identity, loyalty and real dedication"}
		needs.people = [id]; needs.members = [id]
		command = command.duplicate(true); command["domain"] = person.domain
	elif kind == "leave":
		if not Store.has(view.world.npcs, str(command.get("npc", ""))) or not Store.has(view.world.facts, str(needs.source)): return {"ok": false, "error": "Missing member or departure source"}
		var fact: Dictionary = Store.entry(view.world.facts, str(needs.source))
		if fact.kind != "member_leave_authorized" or not command.npc in fact.targets: return {"ok": false, "error": "Departure needs an actual identity authorization"}
		return {"ok": true, "needs": needs}
	else: return {"ok": false, "error": "Unknown attention operation"}
	var check: Dictionary = view.attention.preview_needs(view.world, {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": needs.people, "nominees": needs.members, "target": command.get("domain", ""), "source": needs.source}) if kind == "enroll" else view.attention.preview(view.world, needs)
	if check.ok: needs = check
	return {"ok": check.ok, "needs": needs, "error": check.get("error", "")}


static func participant(entry: String) -> String:
	if entry == "SESSION_REST" or entry == "SESSION_SET_ECONOMY_PLAN": return "economy"
	if entry == "POWER_APPOINT" or entry.begins_with("cults/") or entry.begins_with("attention/"): return "cults"
	if entry.begins_with("POWER_") or entry in ["ROUTE_GUIDED_DREAM", "route/ROUTE_GUIDED_DREAM"]: return "powers"
	if entry.begins_with("prayer/") or entry in ["ROUTE_PACT_PERFORMANCE", "route/ROUTE_PACT_PERFORMANCE"]: return "prayers"
	if entry.begins_with("route/") or entry.begins_with("ROUTE_"): return "progression_routes"
	if entry.begins_with("relic/"): return "relics"
	return "events"
