extends RefCounted
## All-definition art catalogue, not a Session deck or an eligibility claim.
## Display names and authored descriptions are the CSV-backed display catalogue.
const Library = preload("res://src/presentation/production/worldplay/illustrations/library.gd")
const Actions = preload("res://src/presentation/production/worldplay/action_model.gd")
const Management = preload("res://src/presentation/production/world_management.gd")

static func cards(catalog: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tables: Dictionary = catalog.display_tables
	for id: String in Library.POWERS:
		var definition: Dictionary = tables.get("powers", {}).get(id, {})
		if definition.is_empty(): continue
		var card := _card("record/" + id, str(definition.name), "power", "powers", str(definition.get("success", "")))
		card.merge({"type": "object", "kind": "power", "entry": id,
			"subject": definition.merged({"id": id}, true),
			"requirement": str(definition.get("target_requirement", "")),
			"risk": str(definition.get("always_cost", ""))}, true)
		result.append(card)
	for id: String in Library.ROUTES:
		# These two definitions execute through powers/prayer responses, not the
		# sixteen activity verbs exposed by entry_selectors._route_fields().
		if id in ["ROUTE_GUIDED_DREAM", "ROUTE_PACT_PERFORMANCE"]: continue
		var definition: Dictionary = tables.get("progression_route_operations", {}).get(id, {})
		if definition.is_empty(): continue
		var card := _card(id, str(definition.name), "activity", "activities", str(definition.get("description", "")))
		card.entry = "route/context"
		card.selection = {"operation": id}
		result.append(card)
	for id: String in Library.RELICS:
		var definition: Dictionary = tables.get("relics", {}).get(id, {})
		if definition.is_empty(): continue
		var card := _card("relic/" + id, str(definition.name), "relic", "relics", str(definition.get("description", definition.get("carry_effect", ""))))
		# A type definition has no owned placement/holder state. Keep its real
		# description rather than asking the Session-object formatter for status.
		card.merge({"type": "information", "kind": "relic", "subject": definition.merged({"id": id, "type": id}, true)}, true)
		result.append(card)
	for id: String in Library.RESISTANCE:
		var definition: Dictionary = tables.get("resistance_plans", {}).get(id, {})
		if definition.is_empty(): continue
		var card := _card("resistance/" + id, str(definition.name), "resistance", "previews", str(definition.get("preview_impact", definition.get("result", ""))))
		card.merge({"type": "information", "kind": "resistance", "subject": {"rule": id}}, true)
		result.append(card)
	var relic_names: Dictionary = Actions.RELIC_NAMES.merged({"public": "公开", "wait": "等待"})
	for verb: String in Library.VERBS:
		var card := _card("relic/" + verb, str(relic_names[verb]), "relic", "actions", "")
		card.entry = "relic/" + verb
		card.detail = "圣物处置"
		result.append(card)
	var anchor: Dictionary = tables.get("powers", {}).get("POWER_ANCHOR", {})
	if not anchor.is_empty():
		var bind := _card("anchor/bind", str(anchor.name), "anchor", "actions", str(anchor.get("success", "")))
		bind.entry = "POWER_ANCHOR"
		bind.requirement = str(anchor.get("target_requirement", ""))
		result.append(bind)
		# Existing production verb/copy; no invented target, upkeep amount or state.
		var maintain := _card("anchor/maintain", "维系", "anchor", "actions", "护持与实际供奉维系锚点，贡献苏醒。")
		maintain.entry = "POWER_ANCHOR"
		result.append(maintain)
	for strategy: String in Actions.ORDER_NAMES:
		var card := _card("order/" + strategy, str(Actions.ORDER_NAMES[strategy]), "cult", "actions", str(Management.STRATEGY_INTENT[strategy]))
		card.kind = "order"
		card.entry = "SESSION_SET_ECONOMY_PLAN"
		card.selection = {"strategy": strategy}
		result.append(card)
	for id: String in Library.EVENTS:
		var definition: Dictionary = tables.get("events", {}).get(id, {})
		if definition.is_empty(): continue
		var choices := PackedStringArray()
		for key: String in ["choice_a", "choice_b"]:
			var choice := str(definition.get(key, ""))
			if not choice.is_empty(): choices.append(choice)
		var card := _card("event/" + id, str(definition.title), "event", "events", " / ".join(choices))
		card.kind = "event"
		card.content_id = id
		card.subject = {"content_id": id}
		result.append(card)
	return result

static func _card(id: String, title: String, group: String, section: String, effect: String) -> Dictionary:
	return {"id": id, "title": title, "type": "action", "kind": "action", "group": group,
		"entry": "", "selection": {}, "subject": {}, "detail": _short(effect),
		"effect": effect, "catalogue_section": section, "catalogue_only": true}

static func _short(value: String) -> String:
	var line := value.replace("\n", " ").strip_edges()
	return line if line.length() <= 26 else line.left(25) + "…"
