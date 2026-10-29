extends RefCounted
## Policy has no world/Turn reference. Input is Session's public projection,
## catalog choices, and explicitly known source facts only.
var strategy: String
var attempted: Dictionary = {}

func _init(name: String) -> void:
	strategy = name

func prayer_candidates(view: Dictionary) -> Array:
	var result: Array = []
	if strategy == "baseline": return result
	for prayer: Dictionary in view.prayers:
		var content: String = prayer.card.content_id
		var domain: String = prayer.card.domain
		var member: bool = view.people.any(func(person: Dictionary) -> bool: return person.domain == domain and person.get("bound_member", false) and person.status == "active")
		var variant: String = "shallow"
		var rank: int = 0
		match strategy:
			"expansion":
				if content == "PRAYER_05" and member: rank = 100; variant = "deep"
				elif content == "PRAYER_08" and not member: rank = 80
				elif content == "PRAYER_01" and member: rank = 60; variant = "deep"
				elif content == "PRAYER_02" and member: rank = 50; variant = "deep"
			"aggressive":
				variant = "deep"
				rank = 100 if content == "PRAYER_05" and member else (80 if content == "PRAYER_08" else 40)
			"conceal":
				rank = 100 if content == "PRAYER_03" else (80 if content == "PRAYER_08" and not member else (50 if content in ["PRAYER_01", "PRAYER_05"] and member else 0))
		if rank > 0: result.append({"key": prayer.key + "/" + variant, "selection": {}, "rank": rank, "domain": domain, "content": content})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank > b.rank if a.rank != b.rank else a.key < b.key)
	return result

func event_candidates(view: Dictionary, choices: Array) -> Array:
	if strategy == "baseline": return []
	var result: Array = []
	for row: Dictionary in choices:
		if not row.key.begins_with("event/") or not row.available: continue
		var option: String = row.key.get_slice("/", 2)
		var rank: int = 20 if option == ("B" if strategy == "aggressive" else "A") else 10
		# Purely visible outcomes/costs; no future candidate or RNG inspection.
		if strategy == "conceal" and int(row.details.get("信仰费用", 0)) > 0: rank -= 15
		result.append({"key": row.key, "selection": {}, "rank": rank})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank > b.rank if a.rank != b.rank else a.key < b.key)
	return result

func power_candidates(view: Dictionary, facts: Array) -> Array:
	var result: Array = []
	if strategy in ["baseline", "conceal"]: return result
	for fact: Dictionary in facts:
		if fact.kind != "power_qualification": continue
		var rule: String = str(fact.changes.get("rule", ""))
		var power: String = {"dream": "POWER_DREAM", "spread": "POWER_SEED", "weakness": "POWER_BREACH", "evidence": "POWER_VEIL", "listen": "POWER_LISTEN"}.get(rule, "")
		if power.is_empty(): continue
		var actor: String = str(fact.changes.get("actor", ""))
		var local_member: bool = view.people.any(func(person: Dictionary) -> bool: return person.domain == fact.domain and person.get("bound_member", false) and person.status == "active")
		if strategy == "expansion" and (not local_member or power not in ["POWER_DREAM", "POWER_SEED", "POWER_LISTEN"]): continue
		# Expansion preserves four faith for the next ritual unless it has income.
		if strategy == "expansion" and view.cults.is_empty() and int(view.faith) < 6: continue
		var selection: Dictionary = {"domain": fact.domain, "source": fact.id}
		if power != "POWER_LISTEN": selection["npc"] = actor
		result.append({"key": power, "selection": selection, "domain": fact.domain})
	return result

func preparation_candidate(view: Dictionary, facts: Array, prayer: Dictionary) -> Dictionary:
	if strategy not in ["expansion", "aggressive"] or prayer.content != "PRAYER_05" or int(view.faith) < 8: return {}
	for person: Dictionary in view.people:
		if person.domain != prayer.domain or not person.get("bound_member", false) or person.status != "active": continue
		for fact: Dictionary in facts:
			if fact.domain != prayer.domain: continue
			return {"key": "POWER_ORACLE", "selection": {"domain": prayer.domain, "npc": person.id, "source": fact.id, "declared_action": "POWER_DREAM"}, "domain": prayer.domain}
	return {}

func plan(view: Dictionary) -> Dictionary:
	var strategies: Dictionary = {}
	for cult: Dictionary in view.cults:
		strategies[cult.id] = {"aggressive": "expand", "expansion": "expand", "conceal": "conceal", "baseline": "hold"}[strategy]
	return {"strategies": strategies, "anchor_priority": [], "refuse_anchors": []}

func attention_candidates(view: Dictionary) -> Array:
	if strategy == "baseline": return []
	var result: Array = []
	for domain: Dictionary in view.domains:
		var member: bool = view.people.any(func(person: Dictionary) -> bool: return person.domain == domain.id and person.get("bound_member", false))
		# Released focus actually takes effect next round; never delete holds.
		var has_cult: bool = view.cults.any(func(cult: Dictionary) -> bool: return cult.domain == domain.id and cult.status != "destroyed")
		if domain.focused and (not has_cult or strategy == "conceal"):
			result.append({"key": "attention/release_focus", "selection": {"domain": domain.id}})
		elif not domain.focused and member and has_cult and strategy != "conceal":
			result.append({"key": "attention/focus", "selection": {"domain": domain.id}})
	return result
