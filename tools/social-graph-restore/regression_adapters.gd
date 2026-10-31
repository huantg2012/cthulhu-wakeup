extends "res://tools/social-graph-relations/run.gd"
## Fresh prerequisite adaptation only; original assertions retained verbatim.
func _standalone_nomination(world: RefCounted, domain: String, institution: String, profile: String, source: String) -> bool:
	var identity: String = "restore-qa-prior/" + domain + "/" + str(world.state.next_npc)
	var needs: Dictionary = {"focus": [], "people": [identity], "members": [], "identities": [identity], "source": source}
	var reserved: Dictionary = world.attention.reserve(world, needs)
	if not reserved.get("ok", false): return false
	var accepted: bool = world.submit({"kind": "nominate", "domain": domain, "institution": institution, "profile": profile, "group": "unnamed_nonfollowers", "parents": [source], "identity_key": identity, "attention_token": reserved.token})
	world.attention.finish(world, reserved.token)
	return accepted

func _first_focus_cases() -> void:
	var world: RefCounted = World.new(catalog)
	var valid: bool = world.generate_hybrid(7919)
	if not valid:
		_check("SGI-WORLD/ACTUAL-FIRST-FOCUS", false, {"error": world.last_error})
		return
	var domain: String = "DOMAIN-002"
	var old_person: String = "NPC-%08d" % int(world.state.next_npc)
	# Explicit pre-existing named-identity prerequisite through the original
	# real nomination kernel. This does not claim PR08 bootstrap was executed.
	valid = valid and _standalone_nomination(world, domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin)
	# A real status command supplies an explicit vacancy for the later refocus
	# check. Death-source production and full lifecycle behavior are not tested.
	var vacancy_person: String = str(_people(world, "DOMAIN-001")[-1])
	valid = valid and world.submit({"kind": "status", "npc": vacancy_person, "status": "dead", "parents": [world.state.domains["DOMAIN-001"].origin]})
	var before_old: String = World.canonical(Store.entry(world.state.npcs, old_person).relations)
	var named_before: Array = _people(world, domain)
	var population_before: int = int(world.state.domains[domain].unnamed_nonfollowers)
	var data: Dictionary = _clock(world)
	valid = valid and _open(data)
	var focused: Dictionary = _focus(data, domain) if valid else {}
	var cohort: Dictionary = world.state.get("social_graph", {}).get("cohorts", {}).get(domain + "/first_focus", {})
	var newcomers: Array = _people(world, domain).filter(func(id: String) -> bool: return not id in named_before)
	var expected: Array = newcomers.duplicate(); expected.sort()
	var actual: Array = cohort.get("member_ids", []).duplicate(); actual.sort()
	var delta: int = population_before - int(world.state.domains[domain].unnamed_nonfollowers)
	_check("SGI-WORLD/ACTUAL-FIRST-FOCUS", focused.get("ok", false) and cohort.get("completed") == true and actual == expected and delta == newcomers.size(), {"request": focused, "newcomers": newcomers, "cohort": History.export_value(cohort), "populationDelta": delta, "scope": "Actual Turn attention command with an explicitly declared unrelated-slot harness; not a complete Session."})
	_check("SGI-WORLD/OLD-BOOTSTRAP-EXCLUDED", focused.get("ok", false) and not old_person in actual and World.canonical(Store.entry(world.state.npcs, old_person).relations) == before_old, {"existingPerson": old_person, "cohortMembers": actual, "prerequisite": "Actual pre-focus nomination, not injected identity/relationship or claimed PR08 execution."})
	var graph_before: String = World.canonical(world.state.social_graph)
	var repeat: Dictionary = _focus(data, domain) if focused.get("ok", false) else {}
	var immediate_stable: bool = repeat.get("ok", false) and graph_before == World.canonical(world.state.social_graph)
	var released: Dictionary = _request(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}) if immediate_stable else {}
	var later: bool = released.get("ok", false) and _finish(data) and _open(data)
	var old_initial: Array = _people(world, "DOMAIN-001")
	var graph_later: String = World.canonical(world.state.social_graph)
	var reacquired: Dictionary = _focus(data, "DOMAIN-001") if later else {}
	var new_initial: Array = _people(world, "DOMAIN-001").filter(func(id: String) -> bool: return not id in old_initial)
	var refocus_stable: bool = reacquired.get("ok", false) and not world.state.social_graph.cohorts.has("DOMAIN-001/first_focus") and graph_later == World.canonical(world.state.social_graph) and not new_initial.is_empty()
	_check("SGI-WORLD/REPEATED-FOCUS", immediate_stable and refocus_stable, {"request": repeat, "initiallyExpandedDomainRefocus": reacquired, "refocusNewNominees": new_initial, "alreadyFocusedDoesNotReroll": immediate_stable, "laterNomineesDoNotAcquireInitialEdges": refocus_stable, "vacancyPrerequisite": vacancy_person})
	# This later identity is explicit component setup through the same actual
	# nomination kernel; graph publication must not be triggered by it.
	var standalone: RefCounted = World.new(catalog)
	var own: bool = standalone.generate_hybrid(11)
	var old_graph: String = World.canonical(standalone.state.social_graph) if own else ""
	var next: String = "NPC-%08d" % int(standalone.state.next_npc) if own else ""
	own = own and _standalone_nomination(standalone, "DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", standalone.state.domains["DOMAIN-002"].origin)
	_check("SGI-WORLD/NOMINATION-NO-GRAPH", own and Store.has(standalone.state.npcs, next) and old_graph == World.canonical(standalone.state.social_graph), {"newPerson": next, "noCohortOrRelationship": old_graph == World.canonical(standalone.state.social_graph)})
	_write(scratch.path_join("first-focus-world.json"), {"snapshot": JSON.parse_string(world.snapshot()), "newcomers": newcomers, "preexisting": old_person})
	var empty_cases: Array = []
	var complete: bool = true
	var local_limit: int = int(world.attention.parameters.local_actor_limit)
	for old_count: int in [local_limit - 1, local_limit]:
		var current: RefCounted = World.new(catalog)
		var allowed: bool = current.generate_hybrid(17)
		for ignored: int in old_count: allowed = allowed and _standalone_nomination(current, domain, domain + "/interpretation", "NPC_PROFILE_01", current.state.domains[domain].origin)
		var pending: Dictionary = _clock(current)
		allowed = allowed and _open(pending)
		var acquired: Dictionary = _focus(pending, domain) if allowed else {}
		var result: Dictionary = current.state.social_graph.cohorts.get(domain + "/first_focus", {})
		var wanted: int = local_limit - old_count
		var saved: String = current.snapshot()
		var restored: RefCounted = World.new(catalog)
		var survives: bool = acquired.get("ok", false) and result.get("completed") == true and result.get("member_ids", []).size() == wanted and not str(result.get("empty_reason", "")).is_empty() and restored.restore(saved) and World.canonical(restored.state.social_graph) == World.canonical(current.state.social_graph)
		complete = complete and survives
		empty_cases.append({"oldNamed": old_count, "expectedNew": wanted, "cohort": History.export_value(result), "focus": acquired, "saveRoundtrip": survives})
	_check("SGI-WORLD/EMPTY-FIRST-FOCUS", complete, {"cases": empty_cases, "prerequisites": "Real prior nominations leave only 0/1 first-focus identities; no graph facts injected."})


func _plan_fixture() -> Dictionary:
	var world: RefCounted = FaultWorld.new(catalog)
	var valid: bool = world.generate_hybrid(29)
	var economy: RefCounted = ControlledPlanEconomy.new(catalog, {"graph-plan-fixture": "1"})
	valid = valid and economy.initialize(world)
	var domain: String = "DOMAIN-002"
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	valid = valid and _standalone_nomination(world, domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin)
	world.mutable_npc(person).loyalty = 80 # Explicit eligible pre-existing leader.
	var origin: String = str(world.state.domains[domain].origin)
	var member_needs: Dictionary = world.attention.preview_needs(world.state, {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [person], "nominees": [person], "source": origin})
	var member_reservation: Dictionary = world.attention.reserve(world, member_needs) if member_needs.get("ok", false) else {}
	valid = valid and member_reservation.get("ok", false) and world.attention.enroll(world, person, origin, str(member_reservation.get("token", "")))
	if member_reservation.get("ok", false): world.attention.finish(world, member_reservation.token)
	valid = valid and world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 6, "parents": [origin]})
	var cult: String = "CULT-" + domain
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, person, [person], [origin], {"issuer": "graph-plan-fixture", "version": "1", "cult": cult, "domain": domain, "leader": person, "cohesion": 80}, []) if valid else ""
	valid = valid and not authorization.is_empty() and world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]})
	economy.fixture_cult = cult
	economy.fixture_source = world.state.cults.get(cult, {}).get("established_source", "")
	var data: Dictionary = _clock(world, economy)
	data["economy"] = economy; data["cult"] = cult
	data.valid = data.valid and valid
	data["fixtureDiagnostics"] = {"initialized": valid, "worldError": world.last_error, "turnError": data.turn.last_error, "memberNeeds": member_needs, "memberReservation": member_reservation, "authorization": authorization}
	return data
