extends RefCounted
## Bounded, read-only bridge from a committed command to its public consequences.
## Never changes the simulation or refreshes intelligence. Only the acting target's
## *delta* is disclosed; unobserved attribute totals remain private.
const Store = preload("res://src/simulation/archive_store.gd")
const ATTRIBUTES := ["sanity", "loyalty", "will", "insight", "influence", "adaptation"]

static func capture(session, request: Dictionary) -> Dictionary:
	if request.get("op") != "act": return {}
	if request.get("participant") == "progression_routes": return _capture_activity(session, request)
	if request.get("participant") != "powers": return {}
	var payload: Dictionary = request.get("payload", {})
	var id := str(payload.get("npc", ""))
	var person: Dictionary = Store.entry(session.world.state.npcs, id, {})
	var values := {}
	for field: String in ATTRIBUTES:
		if person.has(field): values[field] = person[field]
	var cults := {}
	for cult: Dictionary in session.world.state.cults.values():
		if cult.domain == person.get("domain", ""): cults[cult.id] = cult.cohesion
	var populations := {}
	for domain: String in [str(payload.get("domain",person.get("domain",""))), str(payload.get("target_domain",""))]:
		if session.world.state.domains.has(domain): populations[domain] = session.world.state.domains[domain].unnamed_followers
	return {"actor":id, "values":values, "cults":cults, "populations":populations}

static func collect(session, request: Dictionary, before: Dictionary, first_fact: int) -> Dictionary:
	if before.get("activity", false): return _activity_receipt(session, request, before, first_fact)
	var receipt := {"deltas":[], "revealed":[], "developments":[]}
	var state: Dictionary = session.world.state
	var attempts: Array[Dictionary] = []
	var outcomes := {}
	var reactions := {}
	var affected_followers := {}
	for number: int in range(first_fact, int(state.next_fact)):
		var id := "FACT-%08d" % number
		if not session._known_facts.has(id): continue
		var fact: Dictionary = Store.entry(state.facts, id)
		var data: Dictionary = fact.changes
		if fact.kind == "power_attempt": attempts.append(fact)
		elif fact.kind == "power_result": outcomes[data.power] = data.outcome
		elif fact.kind == "power_effect":
			_add_delta(receipt, fact.domain, data.field, int(data.actual))
		elif fact.kind == "npc_miracle_response":
			if not reactions.has(fact.actor): reactions[fact.actor] = {}
			for field: String in data.get("actual_deltas", {}):
				reactions[fact.actor][field] = int(reactions[fact.actor].get(field,0)) + int(data.actual_deltas[field])
		elif fact.kind == "turn_scheduled" and data.get("participant") == "cults":
			for job: Dictionary in session.turn.context.queued:
				if job.id == data.id and job.action == "appointment":
					receipt.developments.append({"kind":"appointment", "actor":job.payload.npc, "cult":job.payload.cult, "role":job.payload.role, "due":job.due})
	for attempt: Dictionary in attempts:
		var data: Dictionary = attempt.changes
		var proofs: Dictionary = data.get("proofs", {})
		var outcome := str(outcomes.get(data.power,""))
		if outcome == "deep": outcome = "deep_success"
		for row: Dictionary in session.catalog.tables.power_effects.values():
			if row.power_id == data.power and row.operation == "delta" and row.field == "followers" and row.outcome in ["always",outcome]:
				var domain := str(data.payload.get("target_domain","")) if row.subject == "target_domain" else str(attempt.domain)
				affected_followers[domain] = true
		if data.power == "POWER_LISTEN" and outcomes.get(data.power) == "success":
			var revealed := str(proofs.get("listen", {}).get("basis", {}).get("fact", ""))
			if session._known_facts.has(revealed): receipt.revealed.append(session._public(Store.entry(state.facts, revealed)))
		var preparation: Dictionary = state.power_system.preparations.get(attempt.id, {})
		if not preparation.is_empty(): receipt.developments.append({"kind":"preparation", "actor":preparation.npc, "action":preparation.action, "amount":preparation.amount, "expires":preparation.expires})
		if data.power == "POWER_VEIL":
			var basis: Dictionary = proofs.get("evidence", {}).get("basis", {})
			var count := 0
			for source: String in [str(basis.get("source", ""))] + basis.get("benefits", []):
				if Store.entry(state.invalid_records, source) == attempt.id: count += 1
			if count > 0: receipt.developments.append({"kind":"evidence", "count":count})
		var manifest: Dictionary = state.power_system.manifest
		if manifest.get("source") == attempt.id:
			receipt.developments.append({"kind":"manifest", "progress":manifest.progress, "duration":session.catalog.integer("manifest_duration")})
	for domain: String in affected_followers:
		if before.get("populations",{}).has(domain) and session._identity_known(domain):
			_add_delta(receipt,domain,"followers",int(state.domains[domain].unnamed_followers)-int(before.populations[domain]))
	# Compare only participants of this power, not the whole live world. Include
	# zero deltas for attributes actually affected (e.g. a capped bestow).
	if not before.is_empty() and session._identity_known(before.actor):
		var person: Dictionary = Store.entry(state.npcs, before.actor, {})
		var affected := {}
		for attempt: Dictionary in attempts:
			if attempt.actor != before.actor: continue
			var power := str(attempt.changes.power)
			var outcome := str(outcomes.get(power, ""))
			if outcome == "deep": outcome = "deep_success"
			for row: Dictionary in session.catalog.tables.power_effects.values():
				if row.power_id != power or row.operation != "delta" or row.subject != "actor" or not row.outcome in ["always", outcome]: continue
				var field := str(attempt.changes.payload.get("attribute", "")) if row.field == "selected_attribute" else str(row.field)
				affected[field] = true
		for field: String in before["values"]:
			if not person.has(field): continue
			# Miracle reactions have their own public cause/effect row.
			var delta := int(person[field]) - int(before["values"][field]) - int(reactions.get(before.actor,{}).get(field,0))
			if delta != 0 or affected.has(field): _add_delta(receipt, before.actor, field, delta)
		for cult: String in before.cults:
			if state.cults.has(cult) and session._identity_known(cult):
				var delta := int(state.cults[cult].cohesion) - int(before.cults[cult])
				if delta != 0: _add_delta(receipt, cult, "cohesion", delta)
	return session._public(receipt)

static func _add_delta(receipt: Dictionary, subject: String, field: String, delta: int) -> void:
	for row: Dictionary in receipt.deltas:
		if row.subject == subject and row.field == field:
			row.delta += delta
			return
	receipt.deltas.append({"subject":subject, "field":field, "delta":delta})

static func _capture_activity(session, request: Dictionary) -> Dictionary:
	var payload: Dictionary = request.get("payload", {})
	var people: Array = [str(payload.get("npc", ""))] + payload.get("participants", [])
	if not str(payload.get("other", "")).is_empty(): people.append(payload.other)
	var values := {}
	var domain := ""
	for id: String in people:
		if not session._identity_known(id): continue
		var person: Dictionary = Store.entry(session.world.state.npcs, id, {})
		if person.is_empty(): continue
		values[id] = {"sanity":person.sanity}
		domain = str(person.domain)
	return {"activity":true,"people":values,"domain":domain,"world":session.world.state.domains.get(domain,{}).duplicate(true)}

static func _activity_receipt(session, request: Dictionary, before: Dictionary, first_fact: int) -> Dictionary:
	var receipt := {"deltas":[],"revealed":[],"developments":[]}
	var state: Dictionary = session.world.state
	for id: String in before.people:
		if not session._identity_known(id): continue
		var person: Dictionary = Store.entry(state.npcs, id, {})
		for field: String in before.people[id]:
			var change := int(person.get(field,0))-int(before.people[id][field])
			if change != 0: _add_delta(receipt,id,field,change)
	var domain := str(before.domain)
	if session._identity_known(domain) and state.domains.has(domain):
		for field: String in ["pollution","alert","unnamed_followers"]:
			var change := int(state.domains[domain][field])-int(before.world.get(field,0))
			if change != 0: _add_delta(receipt,domain,"followers" if field=="unnamed_followers" else field,change)
	# Describe only this command's committed practice; do not report projected rewards.
	for number: int in range(first_fact,int(state.next_fact)):
		var fact: Dictionary = Store.entry(state.facts,"FACT-%08d" % number,{})
		if fact.get("kind") != "route_attempt" or fact.changes.get("operation") != request.get("action"): continue
		if fact.changes.operation == "ROUTE_CALENDAR_RITE":
			var success: bool = fact.changes.outcome in ["success","deep"]
			var text := "祭仪未能转化信众，也未积累成功实践；本次施行的消耗与影响已经发生。"
			if success:
				var count := int(state.domains[domain].unnamed_followers)-int(before.world.unnamed_followers)
				text = "祭仪已受你的影响，%d 名普通居民转向你的信仰。未直接建立教团或锚点。" % count
				var profile: String = state.domains[domain].profile
				if session.catalog.tables.anchor_route_rules.calendar_rites.profile == profile:
					for progress: Dictionary in state.progression_routes.progress.values():
						if progress.get("source") == fact.id: text += "\n跨轮祭仪实践 %d / %d；可用于准备此文明的锚定。" % [progress.uses.size(),session.catalog.integer("ritual_required_turns")]
				elif session.catalog.tables.anchor_route_rules.ritual_keeper.profile == profile: text += "\n已留下祭仪见证，可用于准备祭仪者锚定。"
			receipt.developments.append({"kind":"activity","text":text})
	return session._public(receipt)
