extends RefCounted
## Durable effects of a successful generated prayer. Eligibility reads this
## projection, whose contents are replayed from the frozen response receipt.
const Store = preload("res://src/simulation/archive_store.gd")
const LEDGER := "capabilities"
const RECORD_PRACTICE := "record_practice"
const OFFICE_HOLDING := "office_holding"
const RECORD_ROUTES := {"record_practice": "record_dependency", "calendar_keeping": "calendar_dependency"}

static func valid_contract(value: Dictionary, bound: bool = true) -> bool:
	var subject := "person" if bound else "role"
	if value.size() != 5 or not value.get(subject) is String or value[subject].is_empty(): return false
	if not value.get("turns") is int or value.turns < 0: return false
	# This first pair is a physical alteration, so both effects travel with the
	# person. No conditional effect is admitted without a registered consumer.
	return value.get("conditions") == {} and value.get("granted_tags") == [RECORD_PRACTICE] and value.get("blocked_tags") == [OFFICE_HOLDING]

static func modifiers(state: Dictionary, person: String) -> Dictionary:
	return state.get("prayer_system", {}).get(LEDGER, {}).get(person, {})

static func _active(modifier: Dictionary, turn: int) -> bool:
	return int(modifier.get("since", turn + 1)) <= turn and (int(modifier.get("expires", -1)) < 0 or turn < int(modifier.expires))

static func allows(state: Dictionary, person: String, tag: String) -> bool:
	for modifier: Dictionary in modifiers(state, person).values():
		if _active(modifier, int(state.turn)) and tag in modifier.blocked_tags: return false
	return true

static func grant_source(state: Dictionary, person: String, tag: String) -> String:
	if not allows(state, person, tag): return ""
	var sources: Array = modifiers(state, person).keys()
	sources.sort()
	for source: String in sources:
		var modifier: Dictionary = modifiers(state, person)[source]
		if _active(modifier, int(state.turn)) and tag in modifier.granted_tags: return source
	return ""

static func practice_supported(state: Dictionary, person: Dictionary, content: RefCounted, mode: String = "") -> bool:
	var profile: String = str(state.domains.get(person.get("domain", ""), {}).get("profile", ""))
	for key: String in RECORD_ROUTES:
		if not mode.is_empty() and key != mode: continue
		if content.tables.get("anchor_route_rules", {}).get(RECORD_ROUTES[key], {}).get("profile", "") == profile and not profile.is_empty(): return true
	return false

static func can_apply(state: Dictionary, capability: Dictionary, content: RefCounted) -> bool:
	if not valid_contract(capability) or not state.has("progression_routes"): return false
	var person: Dictionary = Store.entry(state.npcs, capability.person, {})
	if person.get("status") != "active" or "record_keeper" in person.get("role_tags", []): return false
	var office: Dictionary = state.institutions.get(person.get("institution", ""), {})
	if office.is_empty() or office.get("domain") != person.domain: return false
	if not practice_supported(state, person, content): return false
	return grant_source(state, capability.person, RECORD_PRACTICE).is_empty() and allows(state, capability.person, OFFICE_HOLDING)

static func _modifier(capability: Dictionary, result: Dictionary) -> Dictionary:
	var value := capability.duplicate(true)
	value["source"] = result.id
	value["since"] = result.turn
	value["expires"] = int(result.turn) + int(capability.turns) if capability.turns > 0 else -1
	return value

static func _receipt_capability(receipt: Dictionary) -> Dictionary:
	if receipt.get("kind") != "prayer_space_result" or not receipt.changes.get("outcome") in ["success", "deep"]: return {}
	var scene: Variant = receipt.changes.get("scene_after", {})
	if not scene is Dictionary or not scene.get("contracts") is Dictionary: return {}
	var contract: Variant = scene.contracts.get(receipt.changes.get("variant", ""), {})
	if not contract is Dictionary: return {}
	var capability: Variant = contract.get("capability", {})
	if contract.get("disclosure") == "unknown":
		capability = {}
		for outcome: Dictionary in contract.get("outcomes", []):
			if outcome.get("id") != scene.get("selected_outcome", ""): continue
			capability = outcome.get("capability", {})
			break
	return capability if capability is Dictionary else {}

static func apply(world: RefCounted, capability: Dictionary, result: String) -> bool:
	if world.transaction == null or not valid_contract(capability): return false
	var receipt: Dictionary = Store.entry(world.state.facts, result, {})
	if _receipt_capability(receipt) != capability or receipt.changes.get("capability") != capability or not capability.person in receipt.targets: return false
	var modifier := _modifier(capability, receipt)
	var previous: Dictionary = modifiers(world.state, capability.person)
	if previous.has(result): return previous[result] == modifier
	if not can_apply(world.state, capability, world.catalog): return false
	world.stage_collections(["prayer_system", "institutions", "cults", "anchors"])
	if not world.state.prayer_system.has(LEDGER): world.state.prayer_system[LEDGER] = {}
	var ledger: Dictionary = world.state.prayer_system[LEDGER]
	if not ledger.has(capability.person): ledger[capability.person] = {}
	ledger[capability.person][result] = modifier
	var person: Dictionary = Store.entry(world.state.npcs, capability.person)
	world._detach_roles(person, result, true)
	world._refresh_anchors()
	return true

static func known_status(state: Dictionary, person: String, known_facts: Dictionary, content: RefCounted) -> Array[String]:
	var result: Array[String] = []
	var actor: Dictionary = Store.entry(state.npcs, person, {})
	if actor.get("status") == "dead": return result
	var sources: Array = modifiers(state, person).keys()
	sources.sort()
	for source: String in sources:
		var modifier: Dictionary = modifiers(state, person)[source]
		if not known_facts.has(source) or not _active(modifier, int(state.turn)): continue
		var suffix := "" if int(modifier.expires) < 0 else " · 剩余%d轮" % (int(modifier.expires) - int(state.turn))
		if RECORD_PRACTICE in modifier.granted_tags and allows(state, person, RECORD_PRACTICE):
			if practice_supported(state, actor, content, "record_practice"): result.append("可参与记录实践" + suffix)
			elif practice_supported(state, actor, content, "calendar_keeping"): result.append("可参与历法实践" + suffix)
		if OFFICE_HOLDING in modifier.blocked_tags:
			var note := "无法担任领袖、护持者或机构代表" + suffix
			if not note in result: result.append(note)
	return result

static func validate(state: Dictionary, trusted: Dictionary = {}) -> Array[String]:
	var ledger: Variant = state.get("prayer_system", {}).get(LEDGER, {})
	if not ledger is Dictionary: return ["Malformed prayer capability ledger"]
	var expected: Dictionary = trusted.get("prayer_system", {}).get(LEDGER, {}).duplicate(true)
	for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
		var fact: Dictionary = Store.entry(state.facts, "FACT-%08d" % number, {})
		if fact.get("kind") != "prayer_space_result": continue
		var capability := _receipt_capability(fact)
		if capability.is_empty() and fact.changes.get("capability", {}) == {}: continue
		if not valid_contract(capability) or fact.changes.get("capability") != capability or not capability.person in fact.targets or not Store.has(state.npcs, capability.person):
			return ["Capability result disagrees with its frozen response"]
		if not expected.has(capability.person): expected[capability.person] = {}
		expected[capability.person][fact.id] = _modifier(capability, fact)
	if ledger != expected: return ["Prayer capability history disagrees with its actual results"]
	for institution: Dictionary in state.institutions.values():
		if not allows(state, str(institution.get("representative", "")), OFFICE_HOLDING): return ["A blocked person still represents an institution"]
	for cult: Dictionary in state.cults.values():
		if cult.status != "destroyed" and not allows(state, str(cult.get("leader", "")), OFFICE_HOLDING): return ["A blocked person still leads a cult"]
	for anchor: Dictionary in state.anchors.values():
		if anchor.state != "destroyed" and not allows(state, str(anchor.get("guardian", "")), OFFICE_HOLDING): return ["A blocked person still guards an anchor"]
	return []
