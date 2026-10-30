extends "res://tools/anchor-routes/run.gd"
const PlayerSources = preload("res://src/game/player_sources.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const GameRoot = preload("res://src/presentation/game_root.gd")
const MaterialTransaction = preload("res://src/simulation/transaction.gd")
var transfer_data: Dictionary = {}

class ReceptionRejectWorld extends "res://src/simulation/world.gd":
	var reject_reception: bool = false
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_reception:
			for number: int in range(int(trusted.next_fact), int(candidate.next_fact)):
				if Store.entry(candidate.facts, "FACT-%08d" % number, {}).get("kind") == "material_received": issues.append("Injected reception publication failure"); break
		return issues

## The menu/header display projection is an explicit component prerequisite.
## Known selectors, actual action requests and all rule effects use production.
class ComponentSession extends "res://src/presentation/session.gd":
	func project() -> Dictionary:
		return {"ok": true, "active": true, "turn": turn.context.turn, "phase": turn.context.phase, "phase_title": "神意行动", "busy": false, "terminal": false, "faith": world.state.faith, "capacity": 100, "whispers": world.state.whispers, "insight": world.state.insight, "wounds": world.state.wounds, "awakening": world.state.awakening, "disconnected": 0, "manifest": {}, "resistance": [], "economy_plan": {}, "slot": slot, "awakening_sources": [{"kind": "initial", "title": "初始", "value": catalog.integer("initial_awakening")}, {"kind": "insight", "title": "洞见", "value": world.state.insight}, {"kind": "wounds", "title": "创伤", "value": -int(world.state.wounds)}], "people": current_people().map(func(id: String) -> Dictionary: return {"id": id, "domain": Store.entry(world.state.npcs, id).domain, "title": object_title(id)}), "domains": known_domains().map(func(id: String) -> Dictionary: return {"id": id, "domain": id, "title": object_title(id)}), "institutions": world.state.institutions.values().filter(func(item: Dictionary) -> bool: return item.domain in known_domains()), "cults": world.state.cults.values(), "relics": [], "anchors": []}

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files(): _check("MT-CATALOG", "Installed finite CSV loads", false, {"errors": catalog.errors})
	else:
		_setup_materials()
		_endpoint_and_ownership()
		_current_and_private()
		await _atomic_and_ui()
	var passed: bool = records.size() == 4 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "scope": "four_material_reception_component_groups", "limitations": ["Initial funding, existing cult/membership/contact prerequisites and controlled successful dream RNG are explicit fixtures, not natural first-cult reachability.", "Materials, transfers, receipts, payment, current basis and component restore are actual production outcomes.", "GameRoot uses its real scene/controllers with a controlled unrelated header projection; actual Session known selectors/action request and durable retry are exercised. No full Session startup or save claim.", "09A full execution, future route producers, relic/upkeep/ending closure and natural balance remain downstream."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _member(world: RefCounted, person: String, cult: String) -> void:
	var dedication: String = _dedicate(world, person)
	var reserved: Dictionary = world.attention.reserve(world, {"focus": [], "people": [person], "members": [person], "identities": [], "source": dedication})
	assert(reserved.ok and Cults.membership(world, "enroll", person, dedication, reserved.token, cult))
	world.attention.finish(world, reserved.token)

func _setup_materials() -> void:
	var world: RefCounted = ReceptionRejectWorld.new(catalog)
	var valid: bool = world.generate_hybrid(1)
	var domain: String = "DOMAIN-001"
	var origin: String = world.state.domains[domain].origin
	var receiver: String = world.state.institutions[domain + "/propagation"].representative
	var sender: String = world.state.institutions[domain + "/interpretation"].representative
	var cult: String = "CULT-MATERIAL"
	var economy: RefCounted = Economy.new(catalog, ISSUERS)
	valid = valid and economy.initialize(world) and world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]})
	_bind(world, receiver)
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, receiver, [receiver], [origin], {"issuer": "cult-fixture", "version": "1", "cult": cult, "domain": domain, "leader": receiver, "cohesion": 80}, [])
	valid = valid and world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]})
	_member(world, sender, cult)
	world.state.faith = 20
	var data: Dictionary = {"world": world, "source": origin, "sender": sender, "recipient": receiver, "institution": domain + "/propagation", "cult": cult}
	var contacts: Dictionary = {}; var qualifications: Dictionary = {}
	for person: String in [receiver, sender]:
		var institution: String = Store.entry(world.state.npcs, person).institution
		var contact: String = world._record("devotion_contact", domain, person, [person], [origin], {"subject": person, "institution": institution})
		world._know(person, contact); contacts[person] = contact
		qualifications[person] = _qualification(data, "dream", person, person, domain, {"contact": contact}, institution)
	_attach_dispatch(data)
	data.anchors = ActualAnchors.new(catalog, data.prayers.issuers)
	valid = valid and data.anchors.install(data.turn) and _boot(data).get("ok", false) and _open(data)
	var actions: Array = []
	for person: String in [receiver, sender]:
		var payload: Dictionary = {"npc": person, "source": contacts[person], "qualification": qualifications[person]}
		_seed(data, "POWER_DREAM", "success", payload)
		var action: Dictionary = _power(data, "POWER_DREAM", payload)
		actions.append(action); valid = valid and action.ok
		if person == receiver: valid = valid and _evolve(data) and _finish(data) and _open(data)
	var dreams: Array = _facts(world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.changes.get("power") == "POWER_DREAM")
	valid = valid and dreams.size() == 2 and dreams[0].turn != dreams[1].turn and ActualAnchors.available(world.state, data.institution, catalog, world.history).is_empty()
	data["material"] = dreams[-1].id if dreams.size() == 2 else ""
	data["payload"] = {"sender": sender, "recipient": receiver, "source": data.material, "target_institution": data.institution, "grant": "custody"}
	data["valid"] = valid
	transfer_data = data
	_check("MT-SOURCES", "Actual successful dreams in two institutions/two turns leave the target missing the remote material", valid, {"actions": actions, "dreams": dreams, "profile": world.state.domains[domain].profile, "fixtures": {"funding": 20, "cult": cult, "memberSources": [Store.entry(world.state.npcs, sender).binding_source, Store.entry(world.state.npcs, receiver).binding_source], "contacts": contacts}})

func _endpoint_and_ownership() -> void:
	var data: Dictionary = transfer_data
	if not data.get("valid", false): _check("MT-ENDPOINT", "Existing cult delivery and exact ownership", false); return
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.world.preview_material_transfer(data.payload)
	var available: bool = data.world.material_endpoint_available(data.payload)
	var pure: bool = before == data.turn.snapshot()
	var normalized: Dictionary = ActualAnchors.material(data.world.state, data.material, catalog, data.world.history)
	# A person's accurate knowledge alone never fabricates record custody.
	var shadow: Dictionary = History.export_value(data.world.state)
	shadow.npcs[data.recipient].known_facts.append(data.material)
	var still_missing: Dictionary = Materials.preview(shadow, data.payload, catalog)
	var knowledge: Dictionary = data.payload.duplicate(true); knowledge.grant = "knowledge"
	var already_known: Dictionary = Materials.preview(shadow, knowledge, catalog)
	var ordinary: Dictionary = Materials.resolve(data.world.state, data.source, catalog, data.world.history)
	var invalid: Dictionary = data.payload.duplicate(true); invalid.source = data.source
	var result: Dictionary = _submit(data, "act", {"participant": "cults", "action": "transfer_material", "payload": invalid})
	var valid: bool = preview.ok and available and pure and still_missing.ok and already_known.get("reason") == "already_held" and ordinary.get("reason") == "unsupported_material" and not result.ok and before == data.turn.snapshot() and normalized.originals == [data.sender]
	_check("MT-ENDPOINT", "Remote same-cult custody is available independent of temporary budget; knowledge and original witness identity remain distinct", valid, {"preview": preview, "existingEndpoint": available, "pure": pure, "knowledgeOnlyStillLacksCustody": still_missing, "alreadyKnown": already_known, "ordinaryRejected": ordinary, "rejectedCommand": result})

func _current_and_private() -> void:
	var data: Dictionary = transfer_data
	if not data.get("valid", false): _check("MT-CURRENT", "Current target/source and hidden selectors", false); return
	var shadow: Dictionary = History.export_value(data.world.state)
	shadow.npcs[data.recipient].institution = "DOMAIN-001/order"
	var stale: Dictionary = Materials.preview(shadow, data.payload, catalog)
	shadow = History.export_value(data.world.state); shadow.invalid_records[data.material] = data.source
	var revoked: Dictionary = Materials.preview(shadow, data.payload, catalog)
	var session: RefCounted = ComponentSession.new()
	session.catalog = catalog; session.world = data.world; session.turn = data.turn
	session.modules = {"cults": data.cults, "powers": data.powers, "prayers": data.prayers, "relics": data.relics, "events": data.events, "player_sources": PlayerSources.new(catalog)}
	var hidden: bool = session.material_transfer_options().is_empty()
	session._known_domains["DOMAIN-001"] = true; session._known_people[data.sender] = true; session._known_people[data.recipient] = true
	session._learn(data.material)
	var options: Array = session.material_transfer_options()
	var known: bool = options.has(data.payload)
	var unknown: Array = session.current_people().filter(func(id: String) -> bool: return not id in [data.sender, data.recipient])
	data["session"] = session
	var before: String = data.turn.snapshot()
	var private_ok: bool = not options.any(func(item: Dictionary) -> bool: return not session.is_known_source(item.source) or not item.sender in session.known_people() or not item.recipient in session.known_people()) and unknown.is_empty()
	_check("MT-CURRENT", "Stale target and revoked source reject; Session offers only individually known actual endpoints without writes", stale.get("reason") == "stale_target" and revoked.get("reason") == "invalid_material" and hidden and known and private_ok and before == data.turn.snapshot(), {"stale": stale, "revoked": revoked, "hiddenBeforeKnowledge": hidden, "knownOptions": options, "noUnknownEndpoints": private_ok, "migrationEvidence": "read-only current affiliation counterfactual, not a simulated travel process"})

func _atomic_and_ui() -> void:
	var data: Dictionary = transfer_data
	if not data.get("valid", false) or not data.has("session"): _check("MT-ATOMIC", "Payment rollback, receipt, basis, retry and existing UI carrier", false); return
	var session: RefCounted = data.session
	var before: String = data.turn.snapshot()
	var graph: String = _graph_fingerprint(data.world.state)
	var knowledge: Dictionary = {}
	for id: String in Store.keys(data.world.state.npcs): knowledge[id] = History.export_value(Store.entry(data.world.state.npcs, id).known_facts)
	data.world.reject_reception = true
	var rejected: Dictionary = session.execute_action("cults/transfer_material", data.payload, false, "MT-RETRY")
	data.world.reject_reception = false
	var rollback: bool = not rejected.ok and before == data.turn.snapshot()
	var scene: Node = load("res://src/presentation/game_root.tscn").instantiate()
	scene.session = session
	root.add_child(scene)
	await process_frame
	scene.show_page("经营")
	var ui: bool = scene.rows.any(func(row: Dictionary) -> bool: return row.key == "economy/plan") and scene.rows.any(func(row: Dictionary) -> bool: return row.key == "cults/transfer_material")
	scene._select_item("cults/transfer_material")
	ui = ui and scene._execute.visible and not scene._execute.disabled and scene._detail.has_node("Field_recipient")
	scene.free()
	var faith: int = data.world.state.faith; var whispers: int = data.world.state.whispers
	var result: Dictionary = session.execute_action("cults/transfer_material", data.payload, false, "MT-RETRY")
	var receipts: Array = _facts(data.world, "material_received")
	var material: Dictionary = ActualAnchors.material(data.world.state, data.material, catalog, data.world.history)
	var permission: Array = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history)
	var saved: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(saved) and saved == data.turn.snapshot()
	var replay: Dictionary = session.execute_action("cults/transfer_material", data.payload, false, "MT-RETRY")
	var duplicate: Dictionary = data.world.preview_material_transfer(data.payload)
	var bad: Dictionary = History.export_value(data.world.state)
	if not receipts.is_empty():
		var receipt: Dictionary = bad.facts[receipts[0].id]
		var payments: Array = _facts(data.world, "turn_action").filter(func(fact: Dictionary) -> bool: return fact.turn == receipt.turn and fact.id != receipt.changes.trigger)
		if not payments.is_empty():
			receipt.changes.trigger = payments[-1].id
			if not payments[-1].id in receipt.causal_parents: receipt.causal_parents.append(payments[-1].id); receipt.causal_parents.sort()
	var bad_rejected: bool = not Materials.validate_state(bad, catalog).is_empty()
	var sender_shadow: Dictionary = History.export_value(data.world.state)
	sender_shadow.npcs[data.sender].status = "dead"
	var remains: Dictionary = ActualAnchors.material(sender_shadow, data.material, catalog, null, true)
	var private_ok: bool = true
	for id: String in knowledge:
		if id != data.recipient and id != data.sender and History.export_value(Store.entry(data.world.state.npcs, id).known_facts) != knowledge[id]: private_ok = false
	var unchanged_graph: bool = graph == _graph_fingerprint(data.world.state)
	var wrapped_learn: Dictionary = _wrapped_material_learn(data, receipts[0]) if receipts.size() == 1 else {"pass": false}
	var valid: bool = rollback and ui and result.ok and receipts.size() == 1 and faith == data.world.state.faith and whispers - catalog.integer("internal_whispers_cost") == data.world.state.whispers and data.recipient in material.owners and not data.recipient in material.originals and material.root == data.material and permission.size() == 1 and restored and replay.ok and saved == data.turn.snapshot() and duplicate.get("reason") == "already_held" and bad_rejected and data.recipient in remains.owners and private_ok and unchanged_graph and wrapped_learn.get("pass", false)
	_check("MT-ATOMIC", "One actual payment/receipt and late basis; full rollback, component restore/durable replay, exact privacy and existing economy controls", valid, {"rejected": rejected, "rollback": rollback, "uiExistingPlanAndTransfer": ui, "result": result, "receipts": receipts, "material": material, "basis": permission, "componentRestore": restored, "replay": replay, "alreadyHeld": duplicate, "badReferenceRejected": bad_rejected, "senderDeathKeepsReceiptCustody": data.recipient in remains.get("owners", []), "unrelatedKnowledgeUnchanged": private_ok, "graphUnchanged": unchanged_graph, "wrappedLearn": wrapped_learn})

func _graph_fingerprint(state: Dictionary) -> String:
	var graph: Dictionary = {"people": {}, "links": {}}
	for id: String in Store.keys(state.npcs): graph.people[id] = History.export_value(Store.entry(state.npcs, id).relations)
	for id: String in state.institutions: graph.links[id] = state.institutions[id].get("links", [])
	return World.canonical(graph)

## The wrapper is the actual receipt from the preceding paid Turn action.
## Only the outer PR04 plan/request is controlled: execute the production learn
## effect in a managed component transaction, inspect its receipt validator, then
## roll it back. This does not claim a complete generated prayer response.
func _wrapped_material_learn(data: Dictionary, wrapper: Dictionary) -> Dictionary:
	var people: Array = _local_people(data.world).filter(func(id: String) -> bool: return id != data.sender and id != data.recipient and not data.world.history.knows(data.world.state, id, data.material))
	if people.is_empty(): return {"pass": false, "error": "Missing explicit unaware recipient prerequisite"}
	var recipient: String = people[0]
	var sender: String = data.recipient
	var before: String = data.turn.snapshot()
	var transaction: RefCounted = MaterialTransaction.new(data.world, data.turn.context, data.turn.commit_sequence)
	if not transaction.activate(): return {"pass": false, "error": "Component transaction activation failed"}
	data.world.stage_current()
	var plan: Dictionary = {"request": "MT-CONTROLLED-PR04-PLAN", "variant": "deep", "actor": sender, "produced": {}, "descriptor": {"content_id": "PRAYER_04", "domain": "DOMAIN-001", "institution": data.institution, "source": data.source, "subjects": {"petitioner": sender, "second": recipient}, "facts": {"record": wrapper.id}}}
	var applied: bool = data.prayers._apply_rows(data.world, plan, "success", "success", data.material, data.turn)
	var receipts: Array = _facts(data.world, "material_received").filter(func(fact: Dictionary) -> bool: return fact.changes.recipient == recipient)
	var learned: Dictionary = Store.entry(data.world.state.facts, str(plan.produced.get("record_learned", "")), {})
	var errors: Array[String] = Materials.validate_state(data.world.state, catalog)
	var exact_known: bool = data.world.history.knows(data.world.state, recipient, wrapper.id) and data.world.history.knows(data.world.state, recipient, data.material)
	var material: Dictionary = ActualAnchors.material(data.world.state, data.material, catalog, data.world.history)
	var shadow: Dictionary = History.export_value(data.world.state)
	shadow.invalid_records[data.material] = wrapper.id
	var invalid: Dictionary = Materials.resolve(shadow, wrapper.id, catalog)
	var valid: bool = applied and receipts.size() == 1 and learned.get("changes", {}).get("original") == wrapper.id and wrapper.id != data.material and receipts[0].changes.source == data.material and receipts[0].changes.grant == "knowledge" and errors.is_empty() and exact_known and not recipient in material.owners and not recipient in material.originals and invalid.get("reason") == "invalid_material"
	var details: Dictionary = {"pass": valid, "wrapper": wrapper.id, "canonical": data.material, "learned": learned, "receipts": receipts, "receiptRestoreErrors": errors, "exactWrapperAndCanonicalKnown": exact_known, "invalidUnderlying": invalid, "scope": "Actual prior wrapper plus production Prayers learn effect in a managed transaction; outer PR04 plan/request controlled, no full response or Session claim"}
	transaction.rollback()
	details["componentRollback"] = before == data.turn.snapshot()
	details["pass"] = valid and details.componentRollback
	return details
