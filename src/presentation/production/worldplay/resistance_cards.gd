extends RefCounted
## Read-only cards derived only from Session's public pending plans.
## Their identity ends with the announced plan; viewing never acknowledges it.

static func deadline(plan: Dictionary, turn: int) -> String:
	var due := int(plan.get("due", turn))
	var left := maxi(0, due - turn)
	return "%d 轮后触发反制" % left if left > 0 else "本轮触发反制"

static func cards(session: RefCounted, projection: Dictionary, world_id: String) -> Array:
	var result: Array = []
	for plan: Dictionary in projection.get("resistance", []):
		if plan.get("domain") != world_id: continue
		var rule: Dictionary = session.catalog.display_tables.resistance_plans.get(str(plan.get("rule", "")), {})
		var identity := str(plan.get("started_fact", ""))
		# Older projections still have a stable announced target and deadline.
		if identity.is_empty(): identity = "%s/%s/%s/%s" % [world_id, plan.get("rule", ""), plan.get("target", ""), plan.get("due", "")]
		result.append({"id":"resistance/" + world_id + "/" + identity, "title":str(rule.get("name", "反制预告")),
			"type":"information", "group":"resistance", "kind":"resistance", "subject":plan.duplicate(true),
			"detail":deadline(plan, int(projection.get("turn", 0))), "effect":str(rule.get("preview_impact", "影响尚未掌握")),
			"requirement":"预告 · 拖出查阅来源与预计影响"})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.subject.due) < int(b.subject.due) if a.subject.due != b.subject.due else str(a.id) < str(b.id))
	return result
