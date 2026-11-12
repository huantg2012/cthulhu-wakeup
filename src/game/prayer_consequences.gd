extends RefCounted
## Typed consequences of a committed prayer outcome. The frozen contract and
## actual effect receipt together prove what changed and who received it.
const Store = preload("res://src/simulation/archive_store.gd")

static func selected(response: Dictionary) -> Dictionary:
	var scene: Dictionary = response.get("changes", {}).get("scene_after", {})
	var contract: Dictionary = scene.get("contracts", {}).get(response.changes.get("variant", ""), {})
	if contract.get("disclosure") != "unknown": return contract
	for branch: Dictionary in contract.get("outcomes", []):
		if branch.id == scene.get("selected_outcome"): return branch
	return {}

static func key(request: String, rule: Dictionary) -> String:
	return "prayer/space/consequence/" + request + "/" + str(rule.change)

static func matched(change: String, changes: Array) -> bool:
	for delta: Dictionary in changes:
		if str(delta.object) + "." + str(delta.field) == change: return true
	return false

static func _fact(state: Dictionary, id: String, reader: RefCounted) -> Dictionary:
	if Store.has(state.get("facts", {}), id): return Store.entry(state.facts, id)
	if reader != null and reader.has_method("fact"): return reader.fact(id).get("item", {})
	return {}

static func proof(state: Dictionary, item: Dictionary, reader: RefCounted = null) -> Dictionary:
	if item.get("kind") != "prayer_space_consequence": return {}
	var data: Dictionary = item.changes
	var origin := _fact(state, str(data.get("result", "")), reader)
	var effect := _fact(state, str(data.get("effect_source", "")), reader)
	if origin.get("kind") != "prayer_space_result" or not origin.changes.get("outcome") in ["success", "deep"]: return {}
	if not effect.get("kind") in ["prayer_space_result", "prayer_space_progress"] or not effect.id in item.causal_parents: return {}
	var scene: Dictionary = origin.changes.scene_after
	var current: Dictionary = state.get("prayer_system", {}).get("space", {}).get("scenes", {}).get(scene.id, {})
	if current.get("response") != origin.id or current.get("contracts") != scene.contracts or current.get("roles") != scene.roles: return {}
	var contract := selected(origin)
	var rule: Dictionary = contract.get("consequence", {})
	if effect.id != origin.id:
		if effect.changes.get("consequence_of") != origin.id: return {}
		var step: int = int(data.get("step", -1))
		if step < 0 or step >= contract.get("followup", []).size(): return {}
		var scheduled: Dictionary = contract.followup[step]
		if effect.turn != int(origin.turn) + int(scheduled.delay): return {}
		rule = scheduled.get("consequence", {})
	elif data.get("step") != -1: return {}
	if rule.is_empty() or data.get("rule") != rule or not matched(rule.change, effect.changes.get("state_changes", [])): return {}
	if item.domain != scene.domain or item.actor != rule.person or item.targets != [rule.person] or not rule.person in scene.actors or item.turn != effect.turn: return {}
	var institution: Dictionary = state.institutions.get(data.get("institution", ""), {})
	if institution.get("domain") != scene.domain: return {}
	var once := key(scene.id, rule)
	var authorized: String = str(Store.entry(state.get("applied_authorizations", {}), once, ""))
	if authorized.is_empty() and reader != null and reader.has_method("authorization"):
		authorized = str(reader.authorization(once).get("source", ""))
	if authorized != item.id: return {}
	if rule.kind in ["evidence", "rescue"]:
		var miracle := _fact(state, str(data.get("miracle", "")), reader)
		if miracle.get("kind") != "miracle" or not miracle.id in item.causal_parents or miracle.changes.get("prayer_space_source") != origin.id or miracle.domain != item.domain or not rule.witness in miracle.changes.get("witnesses", []): return {}
	return data

static func publish(world: RefCounted, scene: Dictionary, rule: Dictionary, source: String, step: int) -> bool:
	if rule.is_empty(): return true
	var parent: Dictionary = Store.entry(world.state.facts, source)
	if not matched(rule.change, parent.changes.state_changes): return true
	var once := key(scene.id, rule)
	if Store.has(world.state.applied_authorizations, once): return true
	var person: Dictionary = Store.entry(world.state.npcs, rule.person, {})
	if person.get("status") != "active" or person.get("domain") != scene.domain: return true
	var institution: String = str(person.get("institution", ""))
	if not world.state.institutions.has(institution): return true
	var miracle: String = str(Store.entry(world.state.applied_authorizations, "prayer/space/miracle/" + scene.response, ""))
	if rule.kind in ["evidence", "rescue"] and miracle.is_empty(): return false
	var parents: Array = [source]
	if source != scene.response: parents.append(scene.response)
	if not miracle.is_empty(): parents.append(miracle)
	world.stage_collections(["applied_authorizations", "npcs"])
	var id: String = world._record("prayer_space_consequence", scene.domain, rule.person, [rule.person], parents, {"result": scene.response, "effect_source": source, "step": step, "rule": rule, "institution": institution, "miracle": miracle})
	Store.put(world.state.applied_authorizations, once, id)
	world._know(rule.person, id)
	return not proof(world.state, Store.entry(world.state.facts, id)).is_empty()
