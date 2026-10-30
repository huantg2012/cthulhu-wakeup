extends RefCounted
## Finite player decisions. Background context is created once; only actual
## successful uses, original participants and deliveries become route material.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Cults = preload("res://src/game/cults.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Sources = preload("res://src/game/prayer_sources.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const ID: String = "progression_routes"
const SCHEMA: int = 1
const MATERIAL_MODES: Dictionary = {
	"performed_rite": "calendar_rite", "record_series": "record_practice", "record_use": "record_practice", "record_dependency": "record_practice",
	"calendar_pulse": "calendar_keeping", "calendar_use": "calendar_keeping", "calendar_dependency": "calendar_keeping",
	"axiom_record": "axiom_probe|axiom_recheck", "axiom_use": "axiom_repeat", "axiom_dependency": "axiom_repeat",
	"network_endpoint_use": "network_exchange", "network_dependency": "network_exchange", "ritual_lesson": "ritual_transmission", "practiced_rite": "ritual_transmission",
	"practice_session": "memory_practice|dissent_practice", "practice_registration": "memory_practice|dissent_practice", "recollection_use": "memory_practice", "recollection_dependency": "memory_practice", "dissent_use": "dissent_practice", "dissent_dependency": "dissent_practice",
	"reciprocal_covenant": "reciprocal_covenant", "reciprocal_leg": "reciprocal_covenant", "reciprocal_dependency": "reciprocal_covenant"}
var catalog: RefCounted
var version: String

func _init(content: RefCounted) -> void:
	catalog = content; version = rule_version(content)

static func rule_version(content: RefCounted) -> String:
	return "routes/1/" + content.version + "/" + str(content.extension_versions.get("progression_route_operations", "")) + "/" + str(content.extension_versions.get("foundation_route_parameters", "")) + "/" + str(content.extension_versions.get("memory_contract_route_parameters", ""))

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has(ID): return false
	for dependency: String in ["cults", "powers", "prayers", "events", "player_sources"]:
		if not turn._participants.has(dependency): return false
	turn.world.state[ID] = {"schema": SCHEMA, "version": version, "progress": {}, "bases": {}, "materials": []}
	return turn.register_participant(ID, version, ["actions"], [ID], handle) and turn.world.ensure_history(true)

static func _deny(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _same_people(a: Array, b: Array) -> bool:
	var left: Array = a.duplicate(); var right: Array = b.duplicate()
	left.sort(); right.sort()
	return left == right

static func _fact(view: Dictionary, id: String) -> Dictionary:
	if view.has("reader"):
		var found: Dictionary = view.reader.fact(id)
		if found.get("ok", false): view.world.facts[id] = found.item; return found.item
	return Store.entry(view.world.get("facts", {}), id, {})

static func _person(view: Dictionary, id: String) -> Dictionary:
	if view.has("reader"):
		var found: Dictionary = view.reader.entity("npcs", id)
		if found.get("ok", false): view.world.npcs[id] = found.item; return found.item
	return Store.entry(view.world.get("npcs", {}), id, {})

func _cost(row: Dictionary, payload: Dictionary) -> Dictionary:
	var rule: String = row.cost_rule
	var prefix: String = {"foundation_private": "private", "foundation_joint_work": "joint_work", "foundation_gathering": "gathering", "memory_contract_preparation": "preparation"}.get(rule, "prayer_deep")
	if rule in ["memory_circle_stage", "reciprocal_covenant_stage"] and payload.get("stage", "prepare") == "prepare": prefix = "preparation"
	return {"faith": catalog.integer(prefix + "_faith"), "whispers": catalog.integer(prefix + "_whispers")}

func prepare(view: Dictionary, operation: String, payload: Dictionary) -> Dictionary:
	var state: Dictionary = view.world
	if not state.has(ID) or state[ID].version != version: return _deny("Progression operations unavailable")
	var row: Dictionary = catalog.tables.progression_route_operations.get(operation, {})
	if row.is_empty() or row.runtime_status != "implemented" or row.mode == "guided_dream": return _deny("Unknown progression operation")
	for field: String in payload:
		if not field in ["npc", "source", "other", "record", "second_record", "participants", "stage", "target"]: return _deny("Unknown progression input")
	if row.mode == "ritual_transmission" and state[ID].progress.has(str(payload.get("target", ""))): return _student_plan(view, operation, payload, row)
	var npc: String = str(payload.get("npc", "")); var person: Dictionary = _person(view, npc)
	var source: String = str(payload.get("source", "")); var origin: Dictionary = _fact(view, source)
	if person.get("status") != "active" or origin.is_empty() or origin.domain != person.domain or (view.has("reader") and view.reader.invalidated(source)): return _deny("Current person and source required")
	var domain: String = person.domain; var office: String = person.institution
	if not state.institutions.has(office): return _deny("Current institution required")
	var people: Array = [npc]
	var mode: String = row.mode; var stage: String = str(payload.get("stage", "prepare"))
	if not stage in ["prepare", "perform"]: return _deny("Unknown progression stage")
	if not payload.get("participants", []) is Array: return _deny("Invalid participants")
	for participant: Variant in payload.get("participants", []):
		if not participant is String or participant in people: return _deny("Participants must be distinct")
		people.append(participant)
	var other: String = str(payload.get("other", ""))
	if not other.is_empty() and not other in people: people.append(other)
	if people.size() > int(row.participants_max): return _deny("Participant limit exceeded")
	for id: String in people:
		var participant: Dictionary = _person(view, id)
		if participant.get("status") != "active" or participant.domain != domain or participant.acted_turn == state.turn: return _deny("Participant unavailable or already acted")
		if id != npc and participant.institution != office:
			var links: Array = state.institutions[office].get("links", [])
			if not participant.institution in links or not office in state.institutions[participant.institution].get("links", []): return _deny("Current two-way contact required")
	var target: String = str(payload.get("target", ""))
	var key: String = operation + "/" + "/".join(PackedStringArray(people)) + "/" + office
	if not target.is_empty() and state[ID].progress.has(target): key = target
	var progress: Dictionary = state[ID].progress.get(key, {})
	if mode == "ritual_transmission" and progress.has("lesson"): return _deny("Select the original lesson as its student for independent performance")
	if not progress.is_empty() and (progress.npc != npc or progress.people != people or progress.operation != operation): return _deny("Original participants must continue their own operation")
	if not progress.is_empty() and int(state.turn) < int(progress.turn) + maxi(1, int(row.minimum_turn_gap)): return _deny("A later turn is required")
	if mode in ["memory_circle", "pact_agreement"] and progress.has("context"):
		var situation: Dictionary = _fact(view, str(progress.context))
		var root: String = str(situation.get("changes", {}).get("crisis", {}).get("source", ""))
		if not root.is_empty() and not view.reader.invalidated(root): return _deny("Respond to the existing fixed request before preparing another")
	var record: String = str(payload.get("record", ""))
	var material: Dictionary = {} if record.is_empty() else Materials.resolve(state, record, catalog, view.get("reader"))
	if not record.is_empty() and (not material.get("ok", false) or Materials.possession(state, npc, material, "knowledge", catalog, view.get("reader")).is_empty()): return _deny("Operator must know an actual current record")
	match mode:
		"private_devotion":
			if not Knowledge.known(state, npc, {}, view.get("reader")).get("known", false): return _deny("Private devotion needs actual deity knowledge")
			_fact(view, str(person.get("dedication_source", "")))
			_fact(view, str(person.get("binding_source", person.get("status_source", ""))))
			if not Cults.willing(state, person): return _deny("Private devotion needs current willingness")
			if not person.get("bound_member", false) and not Cults.eligible(state, person, catalog): return _deny("Original member admission requirements unmet")
		"covert_gathering":
			_fact(view, str(person.get("dedication_source", "")))
			_fact(view, str(person.get("binding_source", person.get("status_source", ""))))
			if not person.get("bound_member", false) or not Cults.eligible(state, person, catalog): return _deny("A loyal actual member must organize")
			if state.domains[domain].unnamed_nonfollowers <= 0: return _deny("No actual nonfollowers remain")
		"calendar_rite":
			if not "ritual_keeper" in person.role_tags: return _deny("Actual ritual keeper required")
		"record_practice", "calendar_keeping":
			if not "record_keeper" in person.role_tags: return _deny("Actual record keeper required")
		"axiom_probe", "axiom_recheck", "axiom_repeat":
			if state.domains[domain].tier != "cosmic": return _deny("Cosmic domain required")
			if mode != "axiom_probe" and target.is_empty() and progress.is_empty(): return _deny("Same actual exception required")
			if not target.is_empty() and not state[ID].progress.has(target) and _fact(view, target).get("kind") != "exception": return _deny("Actual exception required")
		"network_exchange":
			if people.size() != 2 or _person(view, people[1]).institution == office: return _deny("Two actual network endpoints required")
			for id: String in people:
				if not _person(view, id).get("bound_member", false): return _deny("Actual network members required")
		"joint_work", "ritual_transmission", "memory_practice", "dissent_practice", "pact_agreement", "reciprocal_covenant":
			if people.size() != 2: return _deny("Two actual participants required")
			if mode == "joint_work":
				var second: Dictionary = _person(view, people[1]); var common: bool = false
				for need: String in person.need_tags: common = common or need in second.need_tags
				if not common: return _deny("Current shared need required")
			if mode == "ritual_transmission" and (not "ritual_keeper" in person.role_tags or view.reader.contact_context(npc, people[1]).is_empty() or view.reader.relation_between(npc, people[1], ["support", "cooperation"]).is_empty()): return _deny("Actual teacher and current cooperation required")
			if mode in ["memory_practice", "dissent_practice", "pact_agreement", "reciprocal_covenant"] and progress.is_empty() and record.is_empty(): return _deny("Actual initial record required")
			if mode == "pact_agreement" and Materials.possession(state, npc, material, "custody", catalog, view.get("reader")).is_empty(): return _deny("Obligor must actually hold the preserved record")
			if mode == "reciprocal_covenant" and stage == "prepare" and progress.has("covenant"): return _deny("Continue the fixed covenant rather than replace its terms")
			if mode == "reciprocal_covenant" and stage == "prepare":
				var second: Dictionary = Materials.resolve(state, str(payload.get("second_record", "")), catalog, view.get("reader"))
				if not second.get("ok", false) or not material.material.kind in ["evidence", "dream"] or not second.material.kind in ["evidence", "dream"] or material.material.root == second.material.root or _person(view, people[1]).institution == office or Materials.possession(state, people[1], second, "custody", catalog, view.get("reader")).is_empty() or Materials.possession(state, npc, material, "custody", catalog, view.get("reader")).is_empty(): return _deny("Two original distinct records in actual custody required")
			if mode == "reciprocal_covenant" and stage == "perform" and (progress.is_empty() or progress.get("legs", []).size() >= catalog.integer("reciprocal_legs")): return _deny("Outstanding original reciprocal leg required")
		"memory_circle":
			if people.size() != 1 + catalog.integer("collective_required_witnesses") or state.institutions[office].role != "interpretation": return _deny("Host and three actual memory holders required")
			if record.is_empty(): return _deny("Actual known record required")
		"pact_performance": return _deny("Use the original fixed prayer response")
	var cost: Dictionary = _cost(row, payload)
	if state.faith < cost.faith or state.whispers < cost.whispers: return _deny("Progression operation is not affordable")
	var deterministic: bool = row.check_rule == "deterministic" or (mode in ["memory_circle", "reciprocal_covenant"] and stage == "prepare")
	var probability: int = -1 if deterministic else _probability(state, person, mode)
	var attention: Dictionary = {"family": "system", "content_id": operation, "variant": "use", "participants": people.duplicate(), "target": domain, "source": source, "nominees": [npc] if mode == "private_devotion" and not person.get("bound_member", false) else []}
	return {"ok": true, "operation": operation, "mode": mode, "payload": payload.duplicate(true), "npc": npc, "domain": domain, "institution": office, "people": people, "key": key, "progress": progress.duplicate(true), "faith": cost.faith, "whispers": cost.whispers, "probability": probability, "attention": attention}

func _student_plan(view: Dictionary, operation: String, payload: Dictionary, row: Dictionary) -> Dictionary:
	var key: String = str(payload.target); var progress: Dictionary = view.world[ID].progress[key]
	var npc: String = str(payload.get("npc", "")); var person: Dictionary = _person(view, npc)
	var lesson: Dictionary = _fact(view, str(progress.get("lesson", "")))
	var source: Dictionary = _fact(view, str(payload.get("source", "")))
	if progress.get("operation") != operation or progress.get("completed", false) or person.get("status") != "active" or person.get("acted_turn") == view.world.turn or source.get("domain") != person.get("domain") or lesson.is_empty() or view.reader.invalidated(lesson.id) or view.reader.invalidated(source.id) or lesson.changes.get("data", {}).get("student") != npc or not lesson.changes.data.get("teacher_qualified", false) or int(view.world.turn) <= int(lesson.turn): return _deny("Original student must personally perform on a later turn")
	var cost: Dictionary = _cost(row, payload)
	if view.world.faith < cost.faith or view.world.whispers < cost.whispers: return _deny("Progression operation is not affordable")
	return {"ok": true, "operation": operation, "mode": "ritual_transmission", "payload": payload.duplicate(true), "npc": npc, "student": npc, "domain": person.domain, "institution": person.institution, "people": [npc], "key": key, "progress": progress.duplicate(true), "faith": cost.faith, "whispers": cost.whispers, "probability": _probability(view.world, person, "ritual_transmission"), "attention": {"family": "system", "content_id": operation, "variant": "use", "participants": [npc], "target": person.domain, "source": payload.source}}

func _probability(state: Dictionary, person: Dictionary, mode: String) -> int:
	var social: bool = mode in ["joint_work", "covert_gathering"]
	var attribute: String = "influence" if social else "adaptation"
	var domain: Dictionary = state.domains[person.domain]
	var check_mode: String = "social" if social else "occult"
	var modifier: int = 0
	if int(person.sanity) >= catalog.integer("sanity_stable_threshold"): modifier = catalog.integer("sanity_stable_" + check_mode + "_modifier")
	elif int(person.sanity) < catalog.integer("sanity_fractured_threshold"): modifier = catalog.integer("sanity_disordered_" + check_mode + "_modifier")
	var value: int = catalog.integer("check_base") + catalog.integer("check_attribute_step") * (int(person[attribute]) - catalog.integer("check_" + str(domain.tier) + "_difficulty")) + modifier
	value -= int(floor(float(domain.barrier) / catalog.number("check_barrier_divisor")))
	value -= int(floor(float(domain.alert) / catalog.number("check_alert_divisor")))
	return clampi(value, catalog.integer("check_probability_min"), catalog.integer("check_probability_max"))

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	var plan: Dictionary = prepare(view, str(input.get("action", "")), input.get("payload", {}))
	if not plan.ok: return {"ok": false, "empty": true, "effects": [], "state": {}, "error": plan.error}
	return {"ok": true, "empty": false, "effects": [{"type": ID, "plan": plan}], "state": {}, "meta": {"faith_cost": plan.faith, "whispers_cost": plan.whispers, "min_awakening": 0, "actor": plan.npc, "source": plan.payload.source, "outcome": "progression/" + plan.operation, "responds": false, "used_power": false, "used_relic": false, "target": plan.domain, "attention": plan.attention}}

func preview(turn: RefCounted, operation: String, payload: Dictionary) -> Dictionary:
	if turn.context.phase != "actions" or turn._in_transaction or turn._in_participant: return _deny("Progression preview requires actions")
	var view: Dictionary = turn._read_view(ID, "actions")
	var plan: Dictionary = prepare(view, operation, payload)
	view.reader.close()
	if plan.ok and plan.mode in ["memory_circle", "pact_agreement"] and Sources.state_capacity_blocked(turn.world, plan.people, "PRAYER_07" if plan.mode == "memory_circle" else "PRAYER_06"): return _deny("No current capacity for this fixed request")
	if plan.ok and turn.world.state.has("attention"):
		var admitted: Dictionary = turn.world.attention.preview_needs(turn.world.state, plan.attention, [], plan.npc)
		if not admitted.ok: return admitted
	return plan

func validate_effect(state: Dictionary, slot: String, effect: Dictionary) -> bool:
	return slot == "actions" and effect.get("type") == ID and effect.get("plan") is Dictionary and state.get(ID, {}).get("version") == version and catalog.tables.progression_route_operations.has(effect.plan.get("operation", ""))

func _material(world: RefCounted, tag: String, plan: Dictionary, data: Dictionary, parents: Array, originals: Array = []) -> String:
	var people: Array = plan.people if originals.is_empty() else originals
	parents = world._unique_sorted(parents)
	var source: String = world._record("route_material", plan.domain, plan.npc, people, parents, {"issuer": ID, "version": version, "tag": tag, "institution": plan.institution, "originals": people.duplicate(), "data": data.duplicate(true), "dependencies": parents.duplicate()})
	world.state[ID].materials.append(source)
	for person: String in people: world._know(person, source)
	return source

func _basis(world: RefCounted, plan: Dictionary, basis: Dictionary) -> void:
	if not world.state[ID].bases.has(plan.institution): world.state[ID].bases[plan.institution] = {}
	world.state[ID].bases[plan.institution][basis.route] = basis

func commit(world: RefCounted, effect: Dictionary, owner: Object, token: String = "", payment: String = "") -> bool:
	if not world._driver_allowed(owner) or world.transaction == null or owner.context.phase != "actions": return false
	var plan: Dictionary = effect.plan; var row: Dictionary = catalog.tables.progression_route_operations[plan.operation]
	world.stage_current(); world.stage_collections([ID])
	var outcome: String = "success"; var roll: int = 0
	if plan.probability >= 0:
		roll = world.randoms.checks.randi_range(1, 100); outcome = world.check_result(plan.probability, roll)
		owner._checks.append({"probability": plan.probability, "roll": roll, "outcome": outcome})
	var result: String = world._record("route_attempt", plan.domain, plan.npc, plan.people, [plan.payload.source, payment], {"issuer": ID, "version": version, "operation": plan.operation, "institution": plan.institution, "payload": plan.payload, "probability": plan.probability, "roll": roll, "outcome": outcome, "payment": payment})
	for person: String in plan.people:
		if person != plan.npc and not world.mark_player_task(person, owner): return false
		var npc: Dictionary = world.mutable_npc(person)
		npc.sanity = maxi(0, int(npc.sanity) - int(row.always_sanity_loss if not str(row.always_sanity_loss).is_empty() else 0))
	var domain: Dictionary = world.state.domains[plan.domain]
	domain.alert = mini(catalog.integer("attribute_max"), int(domain.alert) + int(row.always_alert if not str(row.always_alert).is_empty() else 0))
	var progress: Dictionary = plan.progress.duplicate(true)
	if progress.is_empty(): progress = {"operation": plan.operation, "npc": plan.npc, "people": plan.people.duplicate(), "turn": -1, "uses": [], "record": str(plan.payload.get("record", ""))}
	if outcome in ["success", "deep"]:
		domain.pollution = mini(catalog.integer("attribute_max"), int(domain.pollution) + int(row.success_pollution if not str(row.success_pollution).is_empty() else 0))
		if not _success(world, plan, progress, result, owner, token): return false
	progress.turn = world.state.turn; progress["source"] = result
	progress.npc = plan.npc; progress.people = plan.people.duplicate()
	world.state[ID].progress[plan.key] = progress
	world._record("route_progress", plan.domain, plan.npc, plan.people, [result], {"issuer": ID, "version": version, "key": plan.key, "progress": progress.duplicate(true), "bases": world.state[ID].bases.get(plan.institution, {}).duplicate(true)})
	return true

func _success(world: RefCounted, plan: Dictionary, progress: Dictionary, result: String, owner: Object, token: String) -> bool:
	match plan.mode:
		"private_devotion":
			if not Store.entry(world.state.npcs, plan.npc, {}).get("bound_member", false) and not Cults.membership(world, "enroll", plan.npc, str(Store.entry(world.state.npcs, plan.npc, {}).dedication_source), token): return false
			var contact: String = world._record("devotion_contact", plan.domain, plan.npc, [plan.npc], [result], {"subject": plan.npc, "route": ID, "institution": plan.institution})
			world._know(plan.npc, contact)
		"joint_work":
			if not world.establish_relation(plan.people[0], plan.people[1], "cooperation", [result], plan.people, owner).get("ok", false): return false
		"covert_gathering", "calendar_rite":
			var count: int = mini(int(world.state.domains[plan.domain].unnamed_nonfollowers), catalog.integer("gathering_followers" if plan.mode == "covert_gathering" else "rite_followers"))
			if count > 0 and not world.submit({"kind": "population", "mode": "convert", "domain": plan.domain, "amount": count, "parents": [result]}, owner): return false
			if plan.mode == "calendar_rite":
				var rite: String = _material(world, "performed_rite", plan, {"priest": plan.npc}, [result])
				progress.uses.append(rite)
				_basis(world, plan, {"route": "ritual_keeper", "ritual": rite, "priest": plan.npc})
				if progress.uses.size() >= catalog.integer("ritual_required_turns"): _basis(world, plan, {"route": "calendar_rites", "rituals": progress.uses.slice(-catalog.integer("ritual_required_turns")), "priest": plan.npc})
		"record_practice", "calendar_keeping", "axiom_repeat": _operator_practice(world, plan, progress, result)
		"memory_practice", "dissent_practice": _pair_practice(world, plan, progress, result)
		"axiom_probe", "axiom_recheck":
			var exception: String = str(plan.payload.get("target", ""))
			if exception.is_empty(): exception = world._record("exception", plan.domain, plan.npc, [plan.npc], [result], {"unexplained": true, "route": ID})
			var observed: String = world._record("law_observation", plan.domain, plan.npc, [plan.npc], [exception, result], {"scene_rule": "ROOT_COSMIC_OBSERVATION", "exception": exception, "observer": plan.npc, "node": plan.institution, "institution": plan.institution})
			var record: String = _material(world, "axiom_record", plan, {"exception": exception, "observation": observed, "observer": plan.npc}, [exception, observed, result])
			progress["exception"] = exception; progress["record"] = record
		"network_exchange":
			var endpoints: Array = []
			for person: String in plan.people:
				var local: Dictionary = plan.duplicate(); local.institution = Store.entry(world.state.npcs, person, {}).institution
				endpoints.append(_material(world, "network_endpoint_use", local, {"operator": person, "exchange": result}, [result], [person]))
			var exchange: String = _material(world, "network_dependency", plan, {"exchange": result, "endpoints": endpoints, "operators": plan.people, "institutions": plan.people.map(func(id: String) -> String: return Store.entry(world.state.npcs, id, {}).institution)}, [result] + endpoints)
			_basis(world, plan, {"route": "network_exchange", "other_institution": Store.entry(world.state.npcs, plan.people[1], {}).institution, "exchange": exchange})
		"ritual_transmission":
			if not progress.has("lesson"): progress["lesson"] = _material(world, "ritual_lesson", plan, {"teacher": plan.npc, "student": plan.people[1], "teacher_qualified": true}, [result])
			else:
				var student: String = str(plan.get("student", plan.people.back()))
				var ritual: String = _material(world, "practiced_rite", plan, {"practitioner": student, "lesson": progress.lesson}, [progress.lesson, result], [student])
				_basis(world, plan, {"route": "ritual_practice", "lesson": progress.lesson, "ritual": ritual, "practitioner": student})
				progress["completed"] = true
		"memory_circle", "pact_agreement":
			var context: Dictionary = Sources.route_context(world, plan, owner)
			if not context.get("ok", false) or context.get("outcome") != "fixed" or str(context.get("source", "")).is_empty(): return false
			progress["context"] = context.source
		"reciprocal_covenant": return _reciprocal(world, plan, progress, result, owner)
	return true

func _operator_practice(world: RefCounted, plan: Dictionary, progress: Dictionary, result: String) -> void:
	var route: String = {"record_practice": "record_dependency", "calendar_keeping": "calendar_dependency", "axiom_repeat": "axiom_archive"}[plan.mode]
	var prefix: String = {"record_practice": "record", "calendar_keeping": "calendar", "axiom_repeat": "axiom"}[plan.mode]
	var field: String = "exception" if prefix == "axiom" else "series"
	if not progress.has(field): progress[field] = str(plan.payload.get("target", "")) if prefix == "axiom" else _material(world, "record_series" if prefix == "record" else "calendar_pulse", plan, {"operator": plan.npc}, [result])
	var data: Dictionary = {"operator": plan.npc, field: progress[field]}
	var use: String = _material(world, prefix + "_use", plan, data, [progress[field], result])
	progress.uses.append(use)
	var required: int = catalog.integer("practice_required_turns")
	if progress.uses.size() < required: return
	var uses: Array = progress.uses.slice(-required); data["uses"] = uses
	var dependency: String = _material(world, prefix + "_dependency", plan, data, [progress[field], result] + uses)
	_basis(world, plan, {"route": route, field: progress[field], "uses": uses, "dependency": dependency, "operator": plan.npc})

func _pair_practice(world: RefCounted, plan: Dictionary, progress: Dictionary, result: String) -> void:
	var dissent: bool = plan.mode == "dissent_practice"; var prefix: String = "dissent" if dissent else "recollection"
	if not progress.has("session"):
		progress["session"] = _material(world, "practice_session", plan, {"participants": plan.people, "record": progress.record}, [progress.record, result])
		progress["registrations"] = []
		for position: int in plan.people.size():
			progress.registrations.append(_material(world, "practice_registration", plan, {"person": plan.people[position], "session": progress.session, "viewpoint": ("intact" if position == 0 else "broken") if dissent else "shared"}, [progress.session, result], [plan.people[position]]))
	progress.uses.append(_material(world, prefix + "_use", plan, {"participants": plan.people, "session": progress.session}, [progress.session, result] + progress.registrations))
	var required: int = catalog.integer("practice_turns")
	if progress.uses.size() < required: return
	var uses: Array = progress.uses.slice(-required)
	var dependency: String = _material(world, prefix + "_dependency", plan, {"participants": plan.people, "session": progress.session, "registrations": progress.registrations, "uses": uses}, [progress.session, result] + progress.registrations + uses)
	_basis(world, plan, {"route": "dissent_practice" if dissent else "memory_practice", "session": progress.session, "participants": plan.people, "registrations": progress.registrations, "uses": uses, "dependency": dependency})

func _reciprocal(world: RefCounted, plan: Dictionary, progress: Dictionary, result: String, owner: Object) -> bool:
	if plan.payload.get("stage", "prepare") == "prepare":
		if progress.has("covenant"): return false
		var records: Array = [Materials.resolve(world.state, str(plan.payload.second_record), catalog, world.history).source, Materials.resolve(world.state, str(plan.payload.record), catalog, world.history).source]
		var roots: Array = records.map(func(id: String) -> String: return Materials.resolve(world.state, id, catalog, world.history).material.root)
		progress["records"] = records; progress["legs"] = []
		progress["covenant"] = _material(world, "reciprocal_covenant", plan, {"parties": plan.people, "record_roots": roots, "terms": ["deliver_record", "deliver_record"]}, [result] + records)
		return true
	var position: int = progress.legs.size(); var recipient: String = plan.people[position]; var sender: String = plan.people[1 - position]
	var request: Dictionary = {"sender": sender, "recipient": recipient, "source": progress.records[position], "target_institution": Store.entry(world.state.npcs, recipient, {}).institution, "grant": "custody", "channel": {"kind": "reciprocal", "source": result, "from_institution": Store.entry(world.state.npcs, sender, {}).institution, "to_institution": Store.entry(world.state.npcs, recipient, {}).institution}}
	var received: Dictionary = world.receive_material(request, result, owner, "reciprocal")
	if not received.get("ok", false): return false
	var leg: String = _material(world, "reciprocal_leg", plan, {"covenant": progress.covenant, "index": position, "recipient": recipient, "record": progress.records[position], "term": "deliver_record", "receipt": received.get("receipt", received.get("source", ""))}, [result, progress.covenant, progress.records[position]], [recipient])
	progress.legs.append(leg)
	if progress.legs.size() == catalog.integer("reciprocal_legs"):
		var dependency: String = _material(world, "reciprocal_dependency", plan, {"covenant": progress.covenant, "legs": progress.legs}, [progress.covenant, result] + progress.legs)
		_basis(world, plan, {"route": "contract_reciprocal", "covenant": progress.covenant, "legs": progress.legs, "dependency": dependency, "parties": plan.people, "other_institution": Store.entry(world.state.npcs, plan.people[1], {}).institution})
	return true

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not state.has(ID): return []
	var ledger: Dictionary = state[ID]
	if ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content) or not ledger.get("progress") is Dictionary or not ledger.get("bases") is Dictionary or not ledger.get("materials") is Array: return ["Invalid progression operations version or state"]
	var expected_progress: Dictionary = trusted.get(ID, {}).get("progress", {}).duplicate(true)
	var expected_bases: Dictionary = trusted.get(ID, {}).get("bases", {}).duplicate(true)
	var expected_materials: Array = trusted.get(ID, {}).get("materials", []).duplicate()
	var rules: RefCounted = load("res://src/game/progression_routes.gd").new(content)
	for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
		var fact: Dictionary = Store.entry(state.facts, "FACT-%08d" % number, {})
		if fact.get("kind") == "route_material": expected_materials.append(fact.id)
		if fact.get("kind") == "route_attempt":
			var data: Dictionary = fact.changes
			var row: Dictionary = content.tables.progression_route_operations.get(data.get("operation", ""), {})
			if data.get("issuer") != ID or data.get("version") != ledger.version or row.is_empty() or not data.get("payload") is Dictionary: return ["Invalid actual route attempt"]
			var payment: Dictionary = Store.entry(state.facts, str(data.get("payment", "")), {})
			var cost: Dictionary = rules._cost(row, data.payload)
			if payment.get("kind") != "turn_action" or not payment.id in fact.causal_parents or payment.turn != fact.turn or payment.actor != fact.actor or payment.changes.get("outcome") != "progression/" + data.operation or payment.changes.get("faith_cost") != cost.faith or payment.changes.get("whispers_cost") != cost.whispers: return ["Route attempt lost its unique actual payment"]
			if not data.get("outcome") in ["success", "deep", "failure", "disaster"]: return ["Invalid route check result"]
			if int(data.probability) < 0:
				if data.outcome != "success" or data.roll != 0: return ["Deterministic route manufactured a check"]
			else:
				if not int(data.probability) in range(content.integer("check_probability_min"), content.integer("check_probability_max") + 1) or not int(data.roll) in range(1, 101): return ["Invalid actual route roll"]
				var expected: String = "deep" if int(data.roll) <= int(floor(float(data.probability) / content.number("check_critical_divisor"))) else ("success" if int(data.roll) <= int(data.probability) else ("disaster" if int(data.roll) > 100 - int(ceil(float(100 - int(data.probability)) / content.number("check_critical_divisor"))) else "failure"))
				if expected != data.outcome: return ["Route changed its actual check outcome"]
		if fact.get("kind") == "route_progress":
			var data: Dictionary = fact.changes
			if data.get("issuer") != ID or data.get("version") != ledger.version or not data.get("progress") is Dictionary or not data.get("bases") is Dictionary: return ["Invalid route progress result"]
			expected_progress[str(data.key)] = data.progress.duplicate(true)
			var person: Dictionary = Store.entry(state.npcs, fact.actor, {})
			var attempt: Dictionary = Store.entry(state.facts, str(data.progress.get("source", "")), {})
			var office: String = str(attempt.changes.get("institution", person.get("institution", "")))
			if not data.bases.is_empty(): expected_bases[office] = data.bases.duplicate(true)
	if expected_progress != ledger.progress or expected_bases != ledger.bases or expected_materials != ledger.materials: return ["Progression state differs from its actual immutable results"]
	for key: String in ledger.progress:
		var entry: Dictionary = ledger.progress[key]
		if not entry.get("source") is String or not content.tables.progression_route_operations.has(entry.get("operation", "")) or not entry.get("people") is Array: return ["Invalid original progression participants"]
		var attempt: Dictionary = Store.entry(state.facts, entry.source, {})
		if attempt.get("kind") != "route_attempt" or attempt.changes.get("version") != ledger.version or attempt.actor != entry.npc or not _same_people(attempt.targets, entry.people) or attempt.turn != entry.turn: return ["Progression lost its actual attempt"]
		if trusted.get(ID, {}).get("progress", {}).get(key) == entry: continue
		var found: bool = false
		for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
			var fact: Dictionary = Store.entry(state.facts, "FACT-%08d" % number, {})
			if fact.get("kind") == "route_progress" and fact.changes.get("key") == key and fact.changes.get("progress") == entry: found = true; break
		if not found: return ["Progression state has no actual result"]
	for id: Variant in ledger.materials:
		if not id is String: return ["Invalid progression material identity"]
		var fact: Dictionary = Store.entry(state.facts, id, {})
		if fact.get("kind") != "route_material" or fact.changes.get("version") != ledger.version or not fact.changes.get("originals") is Array or not fact.changes.get("data") is Dictionary: return ["Invalid progression material provenance"]
		var attempt: Dictionary = {}
		for parent: String in fact.causal_parents:
			var cause: Dictionary = Store.entry(state.facts, parent, {})
			if cause.get("kind") == "route_attempt": attempt = cause
		if attempt.is_empty() or not attempt.changes.get("outcome") in ["success", "deep"] or fact.domain != attempt.domain or fact.changes.get("dependencies") != fact.causal_parents: return ["Route material lacks an actual successful operation"]
		var mode: String = str(content.tables.progression_route_operations.get(attempt.changes.get("operation", ""), {}).get("mode", ""))
		if not mode in str(MATERIAL_MODES.get(fact.changes.get("tag", ""), "")).split("|", false): return ["Unsupported route material producer"]
		for person: String in fact.changes.originals:
			if not person in fact.targets or not person in attempt.targets: return ["Progression material changed original participants"]
	return []
