extends "res://tools/cult-spread/run.gd"
const LifecycleResistance = preload("res://src/game/resistance.gd")
const LifecycleEndings = preload("res://src/game/endings.gd")
var lifecycle: Dictionary = {}
class ContactQuery extends RefCounted:
	const View = preload("res://src/simulation/state_view.gd")
	var world: RefCounted
	var context: Dictionary
	var _participants: Dictionary
	func _read_view(id: String, slot: String) -> Dictionary:
		return View.new(world.state, context, 0, world.history).participant(id, slot)

func _initialize() -> void:
	catalog = Catalog.new()
	if catalog.load_files():
		_discovery_to_structure()
		_paid_lifecycle()
		_loss_repair_restore()
		_known_resistance_endings()
	else: _check("AL-CATALOG", "Current authored content loads", false, {"errors": catalog.errors})
	var passed: bool = records.size() == 4 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "scope": "four_bounded_actual_material_lifecycle_groups", "fixtures": ["Existing sourced cult, 81 followers, dedicated guardian, 70 initial faith, 10 insight and 80 pollution are controlled campaign prerequisites.", "Original dream contacts/knowledge and successful power checks are controlled; dream materials, transfer, basis, opportunity, relic, anchor and payment are actual production outputs.", "Temporary status changes use the existing typed deadline fixture. Counterfactual consumer controls are identified individually; they do not prove alternate raw producers or active routes.", "Full Session continuation, all eight alternate routes, first-cult reachability, natural balance and human UX remain downstream."]}, "\t", true, true) + "\n")
	file.close(); quit(0 if passed else 1)

func _attach_dispatch(data: Dictionary) -> Dictionary:
	var world: RefCounted = data.world
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog)); accepted.merge(PlayerSources.issuer_capability(catalog))
	world.state.economy.issuers = accepted.duplicate(true)
	world.state.insight = 10; world.state.faith = 70; world.state.domains["DOMAIN-001"].pollution = 80
	world._refresh_anchors()
	data.domain = "DOMAIN-001"; data.guardian = data.recipient
	data.economy = Economy.new(catalog, accepted)
	data.turn = Turn.new(world)
	assert(data.turn._attached and data.economy.install(data.turn))
	data.fixture = Fixture.new()
	assert(data.turn.register_participant("cult-fixture", "1", ["deadlines"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog); data.relics = Relics.new(catalog, accepted); data.powers = Powers.new(catalog, accepted); data.prayers = Prayers.new(catalog, accepted); data.events = Events.new(catalog); data.player_sources = PlayerSources.new(catalog)
	assert(data.cults.install(data.turn) and data.relics.install(data.turn) and data.powers.install(data.turn) and data.prayers.install(data.turn) and data.events.install(data.turn) and data.player_sources.install(data.turn))
	data.resistance = LifecycleResistance.new(catalog); data.endings = LifecycleEndings.new(catalog)
	# _setup_materials installs the actual Anchors capability immediately after
	# this hook, before bootstrap. Endings reads it only during actual rounds.
	assert(data.resistance.install(data.turn) and data.endings.install(data.turn))
	var session: RefCounted = Session.new()
	session.catalog = catalog; session.world = world; session.turn = data.turn
	session.modules = {"economy": data.economy, "cults": data.cults, "relics": data.relics, "powers": data.powers, "prayers": data.prayers, "events": data.events, "resistance": data.resistance, "endings": data.endings, "player_sources": data.player_sources}
	session._known_domains[data.domain] = true
	# Explicit original contacts/qualification are given knowledge prerequisites;
	# target dream/material/basis/opportunity results do not yet exist.
	for fact: Dictionary in Store.values(world.state.facts):
		if fact.kind == "devotion_contact" or (fact.kind == "power_qualification" and fact.changes.get("rule") == "dream"): session._learn(fact.id)
	session._refresh_knowledge(false)
	data.player_session = session
	return data

func _power(data: Dictionary, id: String, payload: Dictionary) -> Dictionary:
	var session: RefCounted = data.player_session
	var first_fact: int = data.world.state.next_fact
	var roots: Dictionary = session._command_knowledge_roots({"op": "act", "participant": "powers", "action": id, "payload": payload})
	var result: Dictionary = super._power(data, id, payload)
	if result.ok: session._refresh_knowledge(true, first_fact, roots)
	return result

func _lifecycle_open(data: Dictionary) -> bool:
	if not _submit(data, "advance").ok: return false
	for id: String in data.world.state.event_system.selected.duplicate():
		var entry: Dictionary = data.world.state.event_system.cards.get(id, {})
		if entry.get("descriptor", {}).get("content_id") == "EVENT_05":
			if not _submit(data, "resolve_event", {"event": id, "action": "B"}).ok: return false
	return _submit(data, "finish_events").ok

func _lifecycle_next(data: Dictionary, effects: Array = []) -> bool:
	data.fixture.deadlines = effects
	var valid: bool = _evolve(data) and _finish(data)
	data.fixture.deadlines = []
	return valid and _lifecycle_open(data)

func _lifecycle_anchor(data: Dictionary) -> Dictionary:
	var permission: Dictionary = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history)[0]
	var payload: Dictionary = {"npc": data.guardian, "institution": data.institution, "relic": data.medium, "source": permission.source, "qualification": permission.source}
	_seed(data, "POWER_ANCHOR", "success", payload)
	return _power(data, "POWER_ANCHOR", payload)

func _discovery_to_structure() -> void:
	_setup_materials()
	var prerequisites: Array = records.duplicate(true); records.clear()
	if prerequisites.size() == 1: prerequisites[0].details.fixtures.funding = 70
	var data: Dictionary = transfer_data; lifecycle = data
	var session: RefCounted = data.player_session
	# The shared setup installs this same instance after _attach_dispatch.
	session.modules.anchors = data.anchors
	assert(session.modules.size() == 10)
	var before: String = data.turn.snapshot()
	var hidden: bool = not data.world.state.anchor_system.opportunities.has(data.institution)
	var first_fact: int = data.world.state.next_fact
	var roots: Dictionary = session._command_knowledge_roots({"op": "act", "participant": "cults", "action": "transfer_material", "payload": data.payload})
	var delivered: Dictionary = _submit(data, "act", {"participant": "cults", "action": "transfer_material", "payload": data.payload})
	if delivered.ok: session._refresh_knowledge(true, first_fact, roots)
	var permissions: Array = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history)
	var valid: bool = prerequisites.size() == 1 and prerequisites[0].status == "pass" and hidden and delivered.ok and permissions.size() == 1
	var recovery: Dictionary = {}; var created: Dictionary = {}; var duplicate: Dictionary = {}; var projection: Dictionary = {}
	if valid:
		data.proof = permissions[0].source; data.dependency = data.material
		data.opportunity = str(data.world.state.anchor_system.opportunities.get(data.institution, ""))
		data.original_opportunity = Store.entry(data.world.state.facts, data.opportunity).duplicate(true)
		data.opportunity_state = History.export_value(data.world.state)
		data.opportunity_context = History.export_value(data.turn.context)
		before = data.turn.snapshot()
		var preview: Dictionary = data.events.preview_opportunity(data.turn, {"opportunity": data.opportunity, "option": "recover"})
		var action_key: String = "opportunity/" + data.opportunity + "/recover"
		var actions: Array = Session.Actions.new().list_actions(session)
		var available: Array = actions.filter(func(row: Dictionary) -> bool: return row.key == action_key)
		projection = {"knownOpportunity": session.is_known_source(data.opportunity), "realCatalogRow": available, "knowledgeWasCommandProjection": true}
		valid = preview.ok and before == data.turn.snapshot() and session.is_known_source(data.opportunity) and available.size() == 1 and available[0].available
		recovery = _submit(data, "act", {"participant": "events", "action": "opportunity", "payload": {"opportunity": data.opportunity, "option": "recover"}})
		var relics: Array = Store.values(data.world.state.relics).filter(func(item: Dictionary) -> bool: return item.get("formal", false))
		valid = valid and recovery.ok and relics.size() == 1
		if valid:
			data.medium = relics[0].id
			before = data.turn.snapshot()
			duplicate = _submit(data, "act", {"participant": "events", "action": "opportunity", "payload": {"opportunity": data.opportunity, "option": "public"}})
			valid = not duplicate.ok and before == data.turn.snapshot() and _lifecycle_next(data)
			if valid: created = _lifecycle_anchor(data); valid = created.ok
	if valid:
		data.anchor = "ANCHOR/" + data.institution
		valid = data.world.state.anchors[data.anchor].state == "dormant" and _facts(data.world, "institution_relic_opportunity").filter(func(fact: Dictionary) -> bool: return fact.changes.institution == data.institution).size() == 1
	data.valid = valid
	_check("AL-CREATE", "Actual two dreams and material delivery issue one current basis, stable opportunity, recovered relic and successful anchor structure", valid, {"sourcePrerequisites": prerequisites, "delivery": delivered, "playerProjection": projection, "recovery": recovery, "duplicate": duplicate, "created": created, "opportunities": _facts(data.world, "institution_relic_opportunity"), "anchor": data.world.state.anchors.get(data.get("anchor", ""), "")})

func _paid_lifecycle() -> void:
	var data: Dictionary = lifecycle
	if not data.get("valid", false): _check("AL-PAY", "Actual upkeep and no free recovery", false, {"reason": "create_prerequisite"}); return
	var baseline: int = data.world.state.awakening
	var faith: int = data.world.state.faith
	var valid: bool = _evolve(data)
	var payment: Array = _facts(data.world, "economy_anchor_payment").filter(func(fact: Dictionary) -> bool: return fact.changes.anchor == data.anchor)
	var contribution: int = catalog.integer("anchor_" + str(data.world.state.domains[data.domain].tier) + "_contribution")
	valid = valid and payment.size() == 1 and payment[0].changes.fee == catalog.integer("anchor_" + str(data.world.state.domains[data.domain].tier) + "_upkeep") and data.world.state.faith == faith - payment[0].changes.fee and data.world.state.anchors[data.anchor].state == "active" and data.world.state.awakening == baseline + contribution
	valid = valid and _finish(data) and _lifecycle_open(data)
	var active_before: bool = data.world.state.anchors[data.anchor].state == "active"
	var planned: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": [data.anchor]}})
	var plan_kept: bool = data.world.state.anchors[data.anchor].state == "active"
	valid = valid and planned.ok and plan_kept and _evolve(data)
	var refused: bool = data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.awakening == baseline
	valid = valid and refused and _finish(data) and _lifecycle_open(data)
	var resume: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": {"refuse_anchors": []}})
	var no_free: bool = data.world.state.anchors[data.anchor].state == "dormant"
	valid = valid and resume.ok and no_free and _evolve(data) and data.world.state.anchors[data.anchor].state == "active" and _finish(data) and _lifecycle_open(data)
	data.valid = valid
	_check("AL-PAY", "Payment alone activates; planned refusal keeps prior contribution, actual refusal removes it, resumed plan waits for real payment", valid, {"firstPayment": payment, "baseline": baseline, "contribution": contribution, "activeBeforeRefusal": active_before, "plannedKeptContribution": plan_kept, "actualRefusal": refused, "noFreeResume": no_free, "payments": _facts(data.world, "economy_anchor_payment")})

func _loss_repair_restore() -> void:
	var data: Dictionary = lifecycle
	if not data.get("valid", false): _check("AL-LOSS", "Actual binding loss, restoration, repair and component continuation", false, {"reason": "pay_prerequisite"}); return
	var original: Dictionary = data.world.state.anchors[data.anchor].duplicate(true)
	var peak: int = data.world.state.peak_awakening
	var valid: bool = _lifecycle_next(data, [_status(data, data.guardian, "detained")])
	var stopped: bool = valid and data.world.state.anchors[data.anchor].state == "dormant" and data.world.state.anchors[data.anchor].guardian == original.guardian
	valid = valid and _lifecycle_next(data, [_status(data, data.guardian, "active")])
	var dormant_return: bool = valid and data.world.state.anchors[data.anchor].state == "dormant"
	valid = valid and dormant_return and _lifecycle_next(data) and data.world.state.anchors[data.anchor].state == "active"
	var unbound: Dictionary = _submit(data, "act", {"participant": "relics", "action": "relic_unbind", "payload": {"relic": data.medium, "source": data.proof}})
	var needs_repair: bool = unbound.ok and data.world.state.anchors[data.anchor].needs_rebind and data.world.state.anchors[data.anchor].state == "dormant"
	valid = valid and needs_repair and _lifecycle_next(data) and data.world.state.anchors[data.anchor].state == "dormant"
	var repaired: Dictionary = _lifecycle_anchor(data) if valid else {}
	var repaired_dormant: bool = repaired.get("ok", false) and data.world.state.anchors[data.anchor].state == "dormant"
	valid = valid and repaired_dormant and _evolve(data) and data.world.state.anchors[data.anchor].state == "active"
	var saved: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(saved) and saved == data.turn.snapshot()
	var native: Dictionary = History.export_value(data.world.state)
	native.anchor_system.version += "/old"
	var old_rejected: bool = not ActualAnchors.validate_state(native, catalog).is_empty()
	native = History.export_value(data.world.state)
	native.applied_authorizations["anchor/opportunity/" + data.opportunity] = data.source
	var consumption_rejected: bool = not ActualAnchors.validate_state(native, catalog).is_empty()
	var current: Dictionary = data.world.state.anchors[data.anchor]
	valid = valid and restored and old_rejected and consumption_rejected and current.id == original.id and current.ordinal == original.ordinal and current.origin == original.origin and current.relic == original.relic and data.world.state.peak_awakening >= peak and Store.entry(data.world.state.facts, data.opportunity) == data.original_opportunity and _facts(data.world, "institution_relic_opportunity").filter(func(fact: Dictionary) -> bool: return fact.changes.institution == data.institution).size() == 1
	data.valid = valid
	_check("AL-LOSS", "Real detention/return needs payment; unbind cannot auto-repair, successful repair preserves slot/relic/origin; component restore rejects old capability and false consumption", valid, {"detentionStopped": stopped, "returnStillDormant": dormant_return, "unbound": unbound, "requiresRepair": needs_repair, "repair": repaired, "repairInitiallyDormant": repaired_dormant, "sameSlot": current.id == original.id and current.ordinal == original.ordinal and current.origin == original.origin, "componentRestored": restored, "oldVersionRejected": old_rejected, "falseConsumptionRejected": consumption_rejected})

func _known_resistance_endings() -> void:
	var data: Dictionary = lifecycle
	if not data.get("valid", false): _check("AL-CURRENT", "Known-only resistance and current contact/manifest consumers", false, {"reason": "loss_prerequisite"}); return
	var world: RefCounted = data.world
	var secret: bool = true
	for institution: String in world.state.domains[data.domain].institutions:
		secret = secret and not world.history.knows(world.state, institution, data.proof, true)
	var original: String = data.turn.snapshot()
	var contacts: Array = data.endings.contacts(data.turn)
	var pure: bool = original == data.turn.snapshot()
	var native: Dictionary = History.export_value(world.state)
	var lost: Dictionary = native.duplicate(true)
	lost.invalid_records[data.dependency] = data.source
	var material_lost: Dictionary = ActualAnchors.maintenance(lost, data.institution, catalog)
	var official: Dictionary = native.duplicate(true)
	official.institutions[data.institution].active = false
	official.institutions[data.institution].representative = ""
	var hostile: Dictionary = ActualAnchors.maintenance(official, data.institution, catalog)
	var controlled: Dictionary = Store.entry(native.relics, data.medium).duplicate(true)
	controlled.placement = "controlled"; controlled.anchor = ""
	official.relics[data.medium] = controlled
	var allowed_control: bool = Relics._controlled(official, controlled)
	var occupied: Dictionary = data.opportunity_state.duplicate(true)
	occupied.cults = {}
	var carried: Dictionary = controlled.duplicate(true)
	carried.placement = "carried"; carried.holder = data.guardian
	occupied.relics[data.medium] = carried
	var occupied_preview: Dictionary = data.events.prepare_opportunity({"world": occupied}, {"opportunity": data.opportunity, "option": "recover", "npc": data.guardian})
	var occupied_explanation: String = data.player_session.explain_error(str(occupied_preview.get("error", "")))
	var inventory: Dictionary = data.opportunity_state.duplicate(true)
	inventory.institutions[data.institution].active = false
	var inventory_preview: Dictionary = data.events.prepare_opportunity({"world": inventory}, {"opportunity": data.opportunity, "option": "recover"})
	var contact_controls: Dictionary = _opportunity_contacts(data)
	# These are explicit consumer counterfactuals, not produced cosmic/system
	# anchors or evidence of a reachable final campaign.
	var ritual: Dictionary = native.duplicate(true)
	ritual.awakening = catalog.integer("manifest_requirement")
	ritual.anchors["test-system"] = ritual.anchors[data.anchor].duplicate(true)
	ritual.anchors["test-system"].domain = "DOMAIN-002"
	ritual.domains[data.domain].tier = "cosmic"; ritual.domains["DOMAIN-002"].tier = "system"
	var payload: Dictionary = {"cosmic_anchor": data.anchor, "system_anchor": "test-system", "npc": data.guardian}
	var active_ok: bool = data.powers._manifest_valid(ritual, payload)
	ritual.anchors[data.anchor].state = "dormant"
	var dormant_rejected: bool = not data.powers._manifest_valid(ritual, payload)
	var valid: bool = secret and pure and contacts.size() == 1 and contacts[0].kind == "cult" and not material_lost.get("allowed", false) and hostile.get("allowed", false) and allowed_control and active_ok and dormant_rejected and not occupied_preview.ok and occupied_explanation == "该信徒已携带一件圣物" and inventory_preview.ok and contact_controls.pass
	_check("AL-CURRENT", "Secret basis gives no institution knowledge; real cult contact remains, material loss is current, official hostility does not remove control and manifest requires current active anchors", valid, {"secretBasis": secret, "realContacts": contacts, "queryPure": pure, "materialLossCounterfactual": material_lost, "hostileCounterfactual": hostile, "actualCultControl": allowed_control, "occupiedCarrierRejected": occupied_preview, "occupiedCarrierExplanation": occupied_explanation, "hostileInventory": inventory_preview, "nextOpportunityContacts": contact_controls, "activeManifestConsumer": active_ok, "dormantManifestRejected": dormant_rejected, "counterfactualScope": "Consumer controls only; no future Private Devotion, member/goal/debt/future-income contact or full cosmic active-route claim."})

func _opportunity_contacts(data: Dictionary) -> Dictionary:
	# Isolated query copies remove the other existing contact paths. They retain
	# actual opportunity/member identities, original due, fees and next budgets.
	var native: Dictionary = data.opportunity_state.duplicate(true)
	native.cults = {}; native.simulation.candidates = {}; native.prayer_system.offered = []
	# Single designated carrier control; the real campaign retains both members.
	native.attention.members = {data.guardian: native.attention.members[data.guardian]}
	for fact: Dictionary in Store.values(native.facts):
		if fact.kind == "power_qualification" and fact.changes.get("rule") == "listen": native.invalid_records[fact.id] = data.source
	var query: RefCounted = ContactQuery.new()
	query.world = World.new(catalog); query.context = data.opportunity_context.duplicate(true); query._participants = data.turn._participants
	query.world.state = native
	assert(query.world.ensure_history(true))
	var available: Array = data.endings.contacts(query)
	query.world.state.faith = 0
	var no_funds: Array = data.endings.contacts(query)
	query.world.state.faith = data.opportunity_state.faith
	var carried: Dictionary = Store.entry(data.world.state.relics, data.medium).duplicate(true)
	carried.placement = "carried"; carried.holder = data.guardian; carried.anchor = ""
	Store.put(query.world.state.relics, data.medium, carried)
	assert(query.world.ensure_history(true))
	var occupied: Array = data.endings.contacts(query)
	return {"pass": available.size() == 1 and available[0].kind == "opportunity" and no_funds.is_empty() and occupied.is_empty(), "available": available, "noFaithEvenWithLivingMember": no_funds, "occupiedCarrier": occupied, "evidence": "Read-only consumer counterfactuals from the actual pre-recovery snapshot; no synthetic source or future production."}
