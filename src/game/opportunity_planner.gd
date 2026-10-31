extends RefCounted
## Finite route-stage interpretation. Business admission remains in the installed
## handlers; this module never produces material or searches the action menu.
const Store = preload("res://src/simulation/archive_store.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const Selectors = preload("res://src/game/entry_selectors.gd")
const Eligibility = preload("res://src/game/opportunity_eligibility.gd")
const Economy = preload("res://src/game/economy.gd")
const VERSION: String = "direct-planner/1"

static func key(goal: String, domain: String = "", institution: String = "") -> String:
	return JSON.stringify([goal, "run"] if institution.is_empty() else [goal, domain, institution])

static func _fact(view: Dictionary, source: String) -> Dictionary:
	if Store.has(view.world.facts, source): return Store.entry(view.world.facts, source)
	var found: Dictionary = view.reader.fact(source)
	return found.get("item", {}) if found.get("ok", false) else {}

static func _people(view: Dictionary, ledger: Dictionary, domain: String, office: String = "") -> Array:
	var result: Array = []
	for id: String in ledger.known_people:
		var person: Dictionary = Store.entry(view.world.npcs, id, {})
		if person.get("status") == "active" and person.get("domain") == domain and (office.is_empty() or person.get("institution") == office): result.append(id)
	result.sort(); return result

static func _sources(view: Dictionary, ledger: Dictionary, domain: String) -> Array:
	var result: Array = []
	var origin: String = str(view.world.domains.get(domain, {}).get("origin", ""))
	if ledger.known_facts.has(origin): result.append(origin)
	for npc: String in _people(view, ledger, domain):
		var person: Dictionary = Store.entry(view.world.npcs, npc)
		for field: String in ["binding_source", "status_source", "dedication_source"]:
			var source: String = str(person.get(field, ""))
			if ledger.known_facts.has(source) and not source in result: result.append(source)
	return result

static func _materials(view: Dictionary, ledger: Dictionary, domain: String) -> Array:
	var result: Array = []; var roots: Dictionary = {}
	var current_ids: Array = view.reader.anchor_material_heads(domain, view.catalog.integer("collective_required_witnesses"))
	# The legacy head index covers prayer/dream records. Route observations are
	# owned by the current original operation, so read that exact bound record.
	for progress: Dictionary in view.world.progression_routes.progress.values():
		var person: Dictionary = Store.entry(view.world.npcs, str(progress.get("npc", "")), {})
		var record: String = str(progress.get("record", ""))
		if person.get("status") == "active" and person.get("domain") == domain and not record.is_empty() and not record in current_ids: current_ids.append(record)
	for source: String in current_ids:
		if not ledger.known_facts.has(source): continue
		var material: Dictionary = Anchors.material(view.world, source, view.catalog, view.reader)
		if material.is_empty() or not material.current or roots.has(material.canonical): continue
		roots[material.canonical] = true; result.append(material)
	return result

static func _proposal(route: Dictionary, stage: String, entry: String, selection: Dictionary, sources: Array = [], occurrence: String = "") -> Dictionary:
	var references: Array = sources.duplicate()
	for field: String in ["source", "record", "second_record", "qualification"]:
		var source: String = str(selection.get(field, ""))
		if source.begins_with("FACT-") and not source in references: references.append(source)
	references.sort()
	return {"id": stage, "route_id": route.id, "entry_id": entry, "selection": selection.duplicate(true), "source_ids": references, "occurrence_key": occurrence, "producer_task": route.producer_task, "host_domain": str(selection.get("domain", "")), "mode": "direct_action", "delivery_bound": 0}

static func _operation(view: Dictionary, ledger: Dictionary, route: Dictionary, operation: String, domain: String, office: String, stage: String, inputs: Dictionary = {}) -> Array:
	var result: Array = []
	var people: Array = _people(view, ledger, domain, office)
	if inputs.has("npc"): people = [inputs.npc] if inputs.npc in people else []
	var origins: Array = _sources(view, ledger, domain)
	if not origins.is_empty(): origins = [origins[0]]
	for npc: String in people:
		for source: String in origins:
			var selection: Dictionary = inputs.duplicate(true)
			selection.merge({"domain": domain, "npc": npc, "source": source}, true)
			result.append(_proposal(route, stage, operation, selection))
	return result

static func _prayers(view: Dictionary, ledger: Dictionary, route: Dictionary, content: String, domain: String, stage: String, original: String = "") -> Array:
	var result: Array = []
	for id: String in view.world.prayer_system.offered:
		var request: Dictionary = view.world.prayer_system.requests.get(id, {})
		if request.get("card", {}).get("content_id") != content or request.card.domain != domain or not ledger.known_prayers.has(id): continue
		if not original.is_empty() and not original in [str(request.get("source", "")), str(request.get("descriptor", {}).get("source", ""))]: continue
		for branch: String in (["shallow", "deep"] if content == "PRAYER_08" else ["deep"]):
			var proposal: Dictionary = _proposal(route, stage + "/" + id, "prayer/" + id + "/" + branch, {}, [request.card.fact, str(request.source)], str(request.get("descriptor", {}).get("occurrence", request.get("descriptor", {}).get("call", ""))))
			proposal.host_domain = domain; result.append(proposal)
	return result

static func _first_cult(view: Dictionary, ledger: Dictionary, route: Dictionary, domain: String) -> Array:
	var has_member: bool = _people(view, ledger, domain).any(func(id: String) -> bool: return Store.entry(view.world.npcs, id).get("bound_member", false))
	if not has_member:
		var contacts: Array = _prayers(view, ledger, route, "PRAYER_08", domain, "contact")
		contacts.append_array(_operation(view, ledger, route, "ROUTE_PRIVATE_DEVOTION", domain, "", "contact"))
		return contacts
	var result: Array = []
	var entry: String = "ROUTE_COVERT_GATHERING" if route.material_rule == "true_cult_gathering" else "ROUTE_CALENDAR_RITE"
	var population_gap: int = maxi(0, view.catalog.integer("cult_form_followers") - int(view.world.domains[domain].unnamed_followers))
	var paid_gap: int = maxi(0, view.catalog.integer("cult_form_local_spend") - int(view.world.cult_system.spend.get(domain, {}).get("amount", 0)))
	result.append_array(_operation(view, ledger, route, entry, domain, "", "organize/" + str(population_gap) + "/" + str(paid_gap)))
	return result

static func _dreams(view: Dictionary, ledger: Dictionary, modules: Dictionary, route: Dictionary, domain: String, office: String, network: bool) -> Array:
	var result: Array = []; var prior: Array = []
	for material: Dictionary in _materials(view, ledger, domain):
		if material.kind in ["dream", "evidence"] and material.institution == office: prior.append(material)
	for npc: String in _people(view, ledger, domain):
		var person: Dictionary = Store.entry(view.world.npcs, npc)
		var target_office: String = str(person.institution)
		if network:
			if prior.is_empty() and target_office != office: continue
			if not prior.is_empty() and (target_office == office or not Anchors._connected(view.world, office, target_office)): continue
		elif target_office != office: continue
		if prior.any(func(material: Dictionary) -> bool: return npc in material.originals): continue
		var selection: Dictionary = {"domain": domain, "npc": npc}
		var fields: Dictionary = Eligibility.fields(view, ledger, modules, "POWER_DREAM", selection)
		for field: Dictionary in fields.get("fields", []):
			if field.key != "source": continue
			for option: Dictionary in field.options:
				selection.source = option.id
				result.append(_proposal(route, "independent_record/" + ("first" if prior.is_empty() else str(prior[0].canonical)), "ROUTE_GUIDED_DREAM", selection, [] if prior.is_empty() else [prior[0].id]))
	return result

static func _continuations(view: Dictionary, ledger: Dictionary, route: Dictionary, operation: String, domain: String, office: String) -> Array:
	var result: Array = []
	for progress_key: String in view.world.progression_routes.progress:
		var progress: Dictionary = view.world.progression_routes.progress[progress_key]
		if progress.operation != operation: continue
		var person: Dictionary = Store.entry(view.world.npcs, progress.npc, {})
		if person.get("institution") != office or progress.get("completed", false): continue
		var original: Dictionary = _fact(view, str(progress.source))
		var selection: Dictionary = original.get("changes", {}).get("payload", {}).duplicate(true)
		selection["target"] = progress_key
		if operation == "ROUTE_AXIOM_REPEAT": selection.target = str(progress.get("exception", ""))
		var stage: String = "use/" + str(progress.uses.size()) + "/" + progress_key
		if operation in ["ROUTE_MEMORY_CIRCLE", "ROUTE_PACT_AGREEMENT"] and progress.has("context"):
			result.append_array(_prayers(view, ledger, route, "PRAYER_07" if operation == "ROUTE_MEMORY_CIRCLE" else "PRAYER_06", domain, "respond", str(progress.context)))
			continue
		if operation == "ROUTE_RECIPROCAL_COVENANT" and progress.has("covenant"):
			if progress.legs.size() >= view.catalog.integer("reciprocal_legs"): continue
			selection.stage = "perform"; stage = "leg/" + str(progress.legs.size()) + "/" + str(progress.covenant)
		if operation == "ROUTE_RITUAL_TRANSMISSION" and progress.has("lesson"):
			var lesson: Dictionary = _fact(view, str(progress.lesson))
			selection = {"npc": str(lesson.get("changes", {}).get("data", {}).get("student", "")), "target": progress_key}
			stage = "student/" + str(progress.lesson)
		result.append_array(_operation(view, ledger, route, operation, domain, office, stage, selection))
	return result

static func _pairs(view: Dictionary, ledger: Dictionary, route: Dictionary, operation: String, domain: String, office: String) -> Array:
	var result: Array = []; var materials: Array = _materials(view, ledger, domain)
	for npc: String in _people(view, ledger, domain, office):
		for other: String in _people(view, ledger, domain):
			if npc == other: continue
			var other_office: String = str(Store.entry(view.world.npcs, other).institution)
			if other_office != office and not Anchors._connected(view.world, office, other_office): continue
			var inputs: Dictionary = {"npc": npc, "other": other}
			if operation == "ROUTE_JOINT_WORK":
				if not "ritual_keeper" in Store.entry(view.world.npcs, npc).role_tags: continue
				if not view.reader.contact_context(npc, other).is_empty() and not view.reader.relation_between(npc, other, ["support", "cooperation"]).is_empty(): continue
			if operation in ["ROUTE_NETWORK_EXCHANGE", "ROUTE_RITUAL_TRANSMISSION", "ROUTE_JOINT_WORK"]:
				result.append_array(_operation(view, ledger, route, operation, domain, office, "begin", inputs)); continue
			for material: Dictionary in materials:
				if not material.kind in ["dream", "evidence"] or not npc in material.owners: continue
				inputs.record = material.id
				if operation == "ROUTE_RECIPROCAL_COVENANT":
					for second: Dictionary in materials:
						if second.root == material.root or not other in second.owners or not second.kind in ["dream", "evidence"]: continue
						inputs.second_record = second.id; inputs.stage = "prepare"
						result.append_array(_operation(view, ledger, route, operation, domain, office, "prepare", inputs))
				else: result.append_array(_operation(view, ledger, route, operation, domain, office, "begin", inputs))
	return result

static func _route(view: Dictionary, ledger: Dictionary, modules: Dictionary, route: Dictionary, domain: String, office: String) -> Array:
	var entries: Array = Array(str(route.entry_ids).split("|")); var rule: String = route.material_rule
	if rule in ["true_cult_gathering", "true_cult_rites"]: return _first_cult(view, ledger, route, domain)
	if rule in ["record_testimonies", "network_independent"]: return _dreams(view, ledger, modules, route, domain, office, rule == "network_independent")
	var operation: String = "ROUTE_RITUAL_TRANSMISSION" if rule == "ritual_practice" else ("ROUTE_AXIOM_REPEAT" if rule == "axiom_archive" else str(entries[0]))
	var progress: Array = [] if rule == "axiom_nodes" else _continuations(view, ledger, route, operation, domain, office)
	# A route with an outstanding original operation must continue that original
	# situation/series/parties; a fresh preparation cannot substitute for it.
	if not progress.is_empty(): return progress
	for original: Dictionary in ([] if rule == "axiom_nodes" else view.world.progression_routes.progress.values()):
		if original.operation == operation and Store.entry(view.world.npcs, original.npc, {}).get("institution") == office and not original.get("completed", false): return []
	if rule == "ritual_practice":
		var transmission: Array = _continuations(view, ledger, route, "ROUTE_RITUAL_TRANSMISSION", domain, office)
		if not transmission.is_empty(): return transmission
		var paired: Array = _pairs(view, ledger, route, "ROUTE_RITUAL_TRANSMISSION", domain, office)
		paired.append_array(_pairs(view, ledger, route, "ROUTE_JOINT_WORK", domain, office)); return paired
	if rule in ["axiom_nodes", "axiom_archive"]:
		var result: Array = []; var has_observation: bool = false
		for material: Dictionary in _materials(view, ledger, domain):
			if material.kind != "exception_record" or material.institution != office: continue
			has_observation = true
			var exception: String = str(material.data.get("exception", ""))
			if rule == "axiom_archive": result.append_array(_operation(view, ledger, route, "ROUTE_AXIOM_REPEAT", domain, office, "repeat/" + exception, {"npc": str(material.data.observer), "target": exception}))
			else:
				for other_office: String in view.world.institutions[office].links:
					if Anchors._connected(view.world, office, other_office): result.append_array(_operation(view, ledger, route, "ROUTE_AXIOM_RECHECK", domain, other_office, "second_node/" + exception, {"target": exception}))
		if has_observation: return result
		return _operation(view, ledger, route, "ROUTE_AXIOM_PROBE", domain, office, "first_observation")
	if operation == "ROUTE_MEMORY_CIRCLE":
		var result: Array = []
		for npc: String in _people(view, ledger, domain, office):
			var others: Array = _people(view, ledger, domain).filter(func(id: String) -> bool: return id != npc and int(Store.entry(view.world.npcs, id).acted_turn) != int(view.world.turn))
			for material: Dictionary in _materials(view, ledger, domain):
				if material.kind in ["evidence", "dream"] and npc in material.owners and others.size() >= view.catalog.integer("collective_required_witnesses"):
					result.append_array(_operation(view, ledger, route, operation, domain, office, "prepare_circle", {"npc": npc, "record": material.id, "participants": others.slice(0, view.catalog.integer("collective_required_witnesses"))}))
		return result
	if operation in ["ROUTE_NETWORK_EXCHANGE", "ROUTE_MEMORY_PRACTICE", "ROUTE_DISSENT_PRACTICE", "ROUTE_PACT_AGREEMENT", "ROUTE_RECIPROCAL_COVENANT"]: return _pairs(view, ledger, route, operation, domain, office)
	return _operation(view, ledger, route, operation, domain, office, "begin")

static func _tail(view: Dictionary, ledger: Dictionary, modules: Dictionary, route: Dictionary, domain: String, office: String, available: Array, anchor: Dictionary) -> Array:
	var result: Array = []
	if not anchor.is_empty() and not anchor.get("needs_rebind", false):
		var plan: Dictionary = view.turn.plans.get("economy", {}).duplicate(true)
		plan.anchor_priority = [anchor.id]; plan.refuse_anchors = Array(plan.get("refuse_anchors", [])).filter(func(id: String) -> bool: return id != anchor.id)
		var preview: Dictionary = modules.economy.validate_plan(view, plan)
		if preview.get("ok", false):
			for row: Dictionary in preview.preview.anchors:
				if row.anchor == anchor.id and row.reason.is_empty():
					var lapse: String = str(view.world.economy.get("prepay_source", anchor.established_source))
					result.append(_proposal(route, "upkeep/" + str(anchor.established_source) + "/" + lapse, "SESSION_SET_ECONOMY_PLAN", plan, [row.source] + ([] if lapse.is_empty() else [lapse])))
		return result
	var cult: String = modules.powers._cult(view.world, domain)
	if cult.is_empty():
		var organization: Dictionary = route.duplicate(true); organization.material_rule = "true_cult_gathering"
		result.append_array(_first_cult(view, ledger, organization, domain))
		organization.material_rule = "true_cult_rites"
		result.append_array(_first_cult(view, ledger, organization, domain)); return result
	var opportunity: String = str(view.world.anchor_system.opportunities.get(office, ""))
	if not opportunity.is_empty() and ledger.known_facts.has(opportunity):
		result.append(_proposal(route, "medium/" + opportunity, "opportunity/" + opportunity + "/recover", {}, [opportunity]))
	for npc: String in _people(view, ledger, domain):
		for proof: Dictionary in available:
			if not ledger.known_facts.has(proof.source): continue
			for relic: String in ledger.known_relics:
				var medium: Dictionary = Store.entry(view.world.relics, relic, {})
				if medium.get("domain") != domain: continue
				var inputs: Dictionary = {"domain": domain, "npc": npc, "institution": office, "qualification": proof.source, "relic": relic}
				for source: String in _sources(view, ledger, domain):
					inputs.source = source; result.append(_proposal(route, "anchor/" + str(proof.source), "POWER_ANCHOR", inputs, [proof.source]))
	return result

static func _manifest(view: Dictionary, ledger: Dictionary, modules: Dictionary, route: Dictionary) -> Array:
	var result: Array = []; var ritual: Dictionary = view.world.power_system.manifest
	if not ritual.is_empty(): return [_proposal(route, "continue/" + str(ritual.source), "POWER_MANIFEST_CONTINUE", {"source": ritual.source}, [ritual.source])]
	var context: Dictionary = Selectors.context(view, ledger, modules)
	var known: Array = Selectors._objects(context, "anchors", "")
	for cosmic_id: String in known:
		var cosmic: Dictionary = view.world.anchors[cosmic_id]
		for system_id: String in known:
			var data: Dictionary = {"cosmic_anchor": cosmic_id, "system_anchor": system_id, "npc": cosmic.guardian}
			if not modules.powers.manifest_configuration_valid(view.world, data): continue
			for source: String in _sources(view, ledger, cosmic.domain):
				var inputs: Dictionary = data.duplicate(); inputs.domain = cosmic.domain; inputs.source = source
				result.append(_proposal(route, "start", "POWER_MANIFEST", inputs, [source]))
			var contribution: int = 0
			for anchor: Dictionary in view.world.anchors.values():
				if anchor.state == "active": contribution += view.catalog.integer("anchor_" + str(view.world.domains[anchor.domain].tier) + "_contribution")
			if route.id == "ROUTE_MANIFEST_WOUNDS" and int(view.world.wounds) > 0:
				var healed: Dictionary = view.world.duplicate(false); healed.wounds = 0
				if Economy.awakening_value(healed, view.catalog, contribution) >= view.catalog.integer("manifest_requirement"): result.append(_proposal(route, "recover_wounds", "SESSION_REST", {}, [cosmic.established_source, view.world.anchors[system_id].established_source]))
			if route.id == "ROUTE_MANIFEST_ANCHOR":
				for id: String in known:
					var anchor: Dictionary = view.world.anchors[id]
					if anchor.state != "dormant" or id in [cosmic_id, system_id]: continue
					var planned: Dictionary = view.turn.plans.get("economy", {}).duplicate(true)
					planned.anchor_priority = [id]; planned.refuse_anchors = Array(planned.get("refuse_anchors", [])).filter(func(item: String) -> bool: return item != id)
					var check: Dictionary = modules.economy.validate_plan(view, planned)
					for row: Dictionary in check.get("preview", {}).get("anchors", []):
						if row.anchor == id and row.reason.is_empty() and Economy.awakening_value(view.world, view.catalog, contribution + view.catalog.integer("anchor_" + str(view.world.domains[anchor.domain].tier) + "_contribution")) >= view.catalog.integer("manifest_requirement"):
							result.append(_proposal(route, "recover_contribution/" + id, "SESSION_SET_ECONOMY_PLAN", planned, [row.source]))
	return result

static func current(view: Dictionary, ledger: Dictionary, modules: Dictionary, requested: Dictionary = {}) -> Dictionary:
	var goals: Array = []; var errors: Array = []
	for dependency: String in ["economy", "powers", "prayers", "events", "cults", "relics", "progression_routes", "player_sources"]:
		if not modules.has(dependency): errors.append("missing_delivery_contract: " + dependency)
	if not errors.is_empty(): return {"ok": false, "goals": [], "errors": errors, "version": VERSION}
	for row: Dictionary in view.catalog.tables.progression_opportunity_goals.values():
		var slots: Array = [""] if row.instance_scope == "run" else view.world.institutions.keys()
		for office: String in slots:
			var domain: String = "" if office.is_empty() else str(view.world.institutions[office].domain)
			if not office.is_empty() and view.world.domains[domain].profile != row.profile_id: continue
			var goal: Dictionary = {"goal_key": key(row.id, domain, office), "goal_id": row.id, "domain": domain, "institution": office, "status": "waiting", "completion_source": "", "step": {}, "block": {"reason": "blocked_world", "details": "Current route inputs, knowledge or participants unavailable", "sources": []}}
			var anchor: Dictionary = view.world.anchors.get("ANCHOR/" + office, {}) if not office.is_empty() else {}
			if row.id == "GOAL_FIRST_CULT" and not view.world.cults.is_empty(): goal.completion_source = str(view.world.cults.values()[0].established_source)
			elif row.id == "GOAL_MANIFEST": goal.completion_source = str(view.world.power_system.completion)
			elif not anchor.is_empty() and anchor.state == "active": goal.completion_source = str(view.world.economy.paid.get(anchor.id, anchor.established_source))
			if not goal.completion_source.is_empty(): goal.status = "satisfied"; goal.block = {}; goals.append(goal); continue
			var candidates: Array = []
			var available: Array = [] if office.is_empty() else Anchors.available(view.world, office, view.catalog, view.reader)
			for route: Dictionary in view.catalog.tables.progression_routes.values():
				if route.goal_id != row.id: continue
				if route.delivery_mode != "direct_action" or int(route.delivery_bound) != 0: errors.append("Unsupported direct route contract: " + str(route.id)); continue
				if row.id == "GOAL_MANIFEST": candidates.append_array(_manifest(view, ledger, modules, route))
				elif office.is_empty():
					for known_domain: String in ledger.known_domains: candidates.append_array(_route(view, ledger, modules, route, known_domain, ""))
				elif not available.is_empty() or not anchor.is_empty(): candidates.append_array(_tail(view, ledger, modules, route, domain, office, available, anchor))
				elif ledger.known_domains.has(domain): candidates.append_array(_route(view, ledger, modules, route, domain, office))
			for candidate: Dictionary in candidates:
				if candidate.host_domain.is_empty():
					candidate.host_domain = domain
					if candidate.host_domain.is_empty() and not candidate.source_ids.is_empty(): candidate.host_domain = str(_fact(view, candidate.source_ids[0]).get("domain", ""))
				var checked: Dictionary = Eligibility.query(view, ledger, modules, candidate.entry_id, candidate.selection)
				if checked.get("ok", false):
					if not requested.is_empty() and not matches(checked, requested): continue
					candidate["query"] = checked; goal.step = candidate; goal.status = "ready"; goal.block = {}; break
				var reason: String = block_reason(str(checked.get("error", "")))
				if goal.block.reason == "blocked_world" or reason != "blocked_world": goal.block = {"reason": reason, "details": str(checked.get("error", "")), "sources": candidate.source_ids}
			if candidates.is_empty() and not office.is_empty(): goal.block.sources = [view.world.institutions[office].source]
			goals.append(goal)
	return {"ok": errors.is_empty(), "goals": goals, "errors": errors, "version": VERSION}

static func matches(query: Dictionary, request: Dictionary) -> bool:
	if query.get("op") != request.get("op"): return false
	for field: String in query.get("fields", {}):
		if query.fields[field] != request.get(field): return false
	return true

static func block_reason(error: String) -> String:
	var message: String = error.to_lower()
	if message.contains("capacity") or message.contains("focus") or message.contains("budget") or message.contains("pool"): return "blocked_capacity"
	if message.contains("afford") or message.contains("faith") or message.contains("whisper") or message.contains("response") or message.contains("already acted") or message.contains("opportunity used"): return "blocked_resource"
	return "blocked_world"
