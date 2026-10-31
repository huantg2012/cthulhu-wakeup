extends "res://tools/anchor-production-closure/run.gd"
## One fixed world and a finite command schedule. All gameplay uses Turn.
const MATURE_DOMAINS: Array[String] = ["DOMAIN-005", "DOMAIN-007", "DOMAIN-011"]
const MATURE_PROFILES: Array[String] = ["CIV_01", "CIV_05", "CIV_08"]
const MATURE_ROUTES: Array[String] = ["record_testimonies", "network_exchange", "dissent_practice"]
const MATURE_ROLES: Array[String] = ["interpretation", "propagation", "order"]
var stage_actions: Array = []
var stage_error: String = ""
var diagnostic_trace: FileAccess = null
var diagnostic_started: int = 0

func _mature_mark(boundary: String, details: Dictionary = {}) -> void:
	if diagnostic_trace == null: return
	var row: Dictionary = {"boundary": boundary, "seconds": float(Time.get_ticks_msec() - diagnostic_started) / 1000.0}
	row.merge(details)
	var line: String = JSON.stringify(row, "", true, true)
	diagnostic_trace.store_line(line)
	diagnostic_trace.flush()
	print("MATURE_TRACE ", line)

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0]; var number: int = int(args[1])
	var part: int = int(args[3]) if args.size() > 3 else -1
	scratch = output.get_base_dir()
	var plan: Array = _mature_plan()
	var started: int = Time.get_ticks_msec()
	if args.has("--diagnostic"):
		diagnostic_started = started
		diagnostic_trace = FileAccess.open(output.trim_suffix(".json") + "-trace.jsonl", FileAccess.WRITE)
	_mature_mark("receiver.begin")
	var data: Dictionary = _mature_initial()
	_mature_mark("receiver.end")
	var parent: Dictionary = {}; var restored: bool = number == 0
	var prior_snapshot: String = ""
	if number > 0:
		_mature_mark("parent_read_hash.begin")
		parent = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
		prior_snapshot = FileAccess.get_file_as_string(parent.snapshot)
		var parent_matches: bool = parent.get("stage") == number - 1 if part <= 0 else parent.get("stage") == number and parent.get("roundPart", -1) == part - 1
		restored = parent.get("status") == "pass" and parent_matches and prior_snapshot.sha256_text() == parent.get("snapshotSha256")
		_mature_mark("parent_read_hash.end", {"valid": restored})
		_mature_mark("restore.begin")
		restored = restored and data.turn.restore(prior_snapshot)
		_mature_mark("restore.end", {"valid": restored})
		if restored:
			_mature_mark("snapshot_equality.begin")
			restored = data.turn.snapshot() == prior_snapshot
			_mature_mark("snapshot_equality.end", {"exact": restored})
			data.people = parent.fixture.people; data.slots = parent.fixture.slots; data.contacts = parent.fixture.contacts; data.dreams = parent.fixture.dreams
		request_sequence = data.turn.commit_sequence + 1000 * number
		if part > 0: request_sequence = int(parent.nextRequestSequence)
	var passed: bool = restored and number >= 0 and number < plan.size()
	if passed:
		if number == 55 and part == 2: passed = _mature_rescue(data, "BACKGROUND-00000045")
		elif part >= 0 and plan[number].kind == "round": passed = _mature_round_part(data, part)
		elif part >= 0: passed = _mature_action_part(data, plan[number], part)
		else: passed = _mature_stage(data, plan[number])
	_mature_mark("final_snapshot.begin")
	var snapshot: String = data.turn.snapshot()
	_mature_mark("final_snapshot.end")
	var path: String = output.trim_suffix(".json") + ".turn.json"
	var state: Dictionary = _mature_summary(data)
	var report: Dictionary = {"status": "pass" if passed else "fail", "stage": number, "roundPart": part, "nextRequestSequence": request_sequence, "step": plan[number], "totalStages": plan.size(), "seconds": float(Time.get_ticks_msec() - started) / 1000.0, "error": stage_error, "engine": Engine.get_version_info().string,
		"snapshot": path, "snapshotSha256": snapshot.sha256_text(), "parentReport": args[2] if number > 0 else "", "parentSnapshotSha256": prior_snapshot.sha256_text() if number > 0 else "", "restoreAttempted": number > 0, "restoreExact": restored if number > 0 else null, "continuationKind": "original_restore" if number > 0 else "initial_baseline",
		"fixture": {"seed": 1, "people": data.people, "slots": data.slots, "contacts": data.contacts, "dreams": data.dreams}, "actions": stage_actions, "state": state,
		"controlledPrerequisites": "One generated hybrid seed 1; lawful existing named profiles and sourced membership/cults; 81 unnamed followers per target domain, cohesion 100, pollution 95, insight 20 and initial faith 90. Success check RNG is controlled. Full Catalog, ordinary production, resistance, deadlines and costs remain enabled. No target material/basis/relic/anchor/payment/terminal is supplied.",
		"scope": "Native eleven-module Turn/Service component continuation, not complete Session save, natural progression, recovery branches or manifestation completion."}
	if passed:
		_mature_mark("snapshot_write.begin")
		var saved: FileAccess = FileAccess.open(path, FileAccess.WRITE); saved.store_string(snapshot); saved.close()
		_mature_mark("snapshot_write.end")
	_mature_mark("report_write.begin")
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t", true, true) + "\n"); file.close()
	_mature_mark("report_write.end")
	print("MATURE_STAGE ", number, " ", plan[number], " ", passed, " ", stage_error, " A=", state.awakening)
	quit(0 if passed else 1)

func _mature_plan() -> Array:
	var plan: Array = [{"group": "planet", "kind": "init"}]
	for position: int in 2:
		plan.append({"group": "planet", "kind": "dream", "slot": position})
		plan.append({"group": "planet", "kind": "round"})
	for slot: int in 9:
		var group: String = ["planet", "system", "cosmic"][slot / 3]
		var kinds: Array = ["deliver"] if slot < 3 else (["exchange"] if slot < 6 else ["dream", "practice", "practice"])
		kinds.append_array(["recover", "anchor"])
		for kind: String in kinds:
			plan.append({"group": group, "kind": kind, "slot": slot})
			plan.append({"group": group, "kind": "round"})
	plan.append({"group": "final", "kind": "final"})
	assert(plan.size() == 72)
	return plan

func _mature_initial() -> Dictionary:
	_mature_mark("catalog.begin")
	catalog = Catalog.new(); assert(catalog.load_files())
	_mature_mark("catalog.end")
	_mature_mark("generation.begin")
	var world: RefCounted = Support.CompatibleWorld.new(catalog); assert(world.generate_hybrid(1))
	_mature_mark("generation.end")
	var accepted: Dictionary = ISSUERS.duplicate(true); accepted.merge(Events.issuer_capability(catalog)); accepted.merge(PlayerSources.issuer_capability(catalog))
	_mature_mark("economy_init.begin")
	var economy: RefCounted = Economy.new(catalog, accepted); assert(economy.initialize(world))
	_mature_mark("economy_init.end")
	var data: Dictionary = {"world": world, "economy": economy, "people": [], "slots": [], "contacts": {}, "dreams": {}}
	_mature_mark("fixture_setup.begin")
	for tier: int in 3:
		var domain: String = MATURE_DOMAINS[tier]; var origin: String = world.state.domains[domain].origin
		assert(world.state.domains[domain].profile == MATURE_PROFILES[tier])
		assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [origin]}))
		var guardians: Array = []
		for position: int in 3:
			var person: String = _named(world, domain, MATURE_ROLES[position], ["NPC_PROFILE_01", "NPC_PROFILE_03", "NPC_PROFILE_05"][position], origin)
			guardians.append(person)
			data.slots.append({"domain": domain, "institution": domain + "/" + MATURE_ROLES[position], "guardian": person, "partner": "", "route": MATURE_ROUTES[tier], "cult": "CULT-MATURE/" + domain})
		var leader: String = guardians[0]; var cult: String = "CULT-MATURE/" + domain
		_bind(world, leader)
		var authorized: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [origin], {"issuer": "cult-fixture", "version": "1", "cult": cult, "domain": domain, "leader": leader, "cohesion": 100}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": authorized, "parents": [authorized]}))
		for position: int in 3:
			var person: String = guardians[position]
			if position > 0: _member(world, person, cult)
			data.people.append(person)
			if tier == 2:
				var partner: String = _named(world, domain, MATURE_ROLES[position], ["NPC_PROFILE_01", "NPC_PROFILE_03", "NPC_PROFILE_05"][position], origin)
				_dedicate(world, partner); data.people.append(partner); data.slots[tier * 3 + position].partner = partner
			var contact: String = world._record("devotion_contact", domain, person, [person], [origin], {"subject": person, "institution": domain + "/" + MATURE_ROLES[position]})
			world._know(person, contact); data.contacts[person] = contact
			data.dreams[person] = _qualification({"world": world}, "dream", person, person, domain, {"contact": contact}, domain + "/" + MATURE_ROLES[position])
		world.state.domains[domain].pollution = 95; world.state.domains[domain].alert = 0
	world.state.faith = 90; world.state.insight = 20; world._refresh_anchors()
	assert(world.validate_state(world.state).is_empty(), str(world.validate_state(world.state)))
	_mature_mark("fixture_setup.end")
	_mature_mark("turn_install.begin")
	data.turn = Turn.new(world); assert(data.turn._attached and economy.install(data.turn))
	data.fixture = Fixture.new(); data.fixture.domain = MATURE_DOMAINS[0]
	assert(data.turn.register_participant("cult-fixture", "1", ["deadlines"], ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog); data.relics = Relics.new(catalog, accepted); data.powers = Powers.new(catalog, accepted); data.prayers = Prayers.new(catalog, accepted); data.anchors = ActualAnchors.new(catalog, accepted); data.events = Events.new(catalog); data.resistance = RouteResistance.new(catalog); data.endings = RouteEndings.new(catalog); data.player_sources = PlayerSources.new(catalog); data.routes = Routes.new(catalog)
	for name: String in ["cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources", "routes"]: assert(data[name].install(data.turn))
	assert(Service.install(data.turn))
	_mature_mark("turn_install.end")
	return data

func _mature_ok(result: Dictionary, stage: String) -> bool:
	stage_actions.append({"stage": stage, "result": result})
	if result.get("ok", false): return true
	stage_error = stage + ": " + str(result.get("error", result)); return false

func _mature_open(data: Dictionary) -> bool:
	if not _mature_ok(_submit(data, "advance"), "open_turn"): return false
	return _mature_finish_events(data)

func _mature_finish_events(data: Dictionary) -> bool:
	for id: String in data.world.state.event_system.selected.duplicate():
		var descriptor: Dictionary = data.world.state.event_system.cards[id].descriptor
		if descriptor.content_id == "EVENT_12" and descriptor.subjects.get("petitioner", "") in data.people:
			if not _mature_ok(_submit(data, "resolve_event", {"event": id, "action": "B"}), "existing_paid_request_reopen"): return false
	return _mature_ok(_submit(data, "finish_events"), "enter_actions")

func _mature_round_part(data: Dictionary, part: int) -> bool:
	var phases: Array[String] = ["actions", "evolution", "settlement", "ending", "between", "events"]
	if part < 0 or part >= phases.size() or data.turn.context.phase != phases[part]:
		stage_error = "Original round continuation phase mismatch"; return false
	if part == 0:
		return _mature_response(data) and _mature_ok(_submit(data, "end_actions"), "original_round/end_actions")
	if part == 5: return _mature_finish_events(data)
	return _mature_ok(_submit(data, "advance"), "open_turn" if part == 4 else "original_round/advance")

func _mature_response(data: Dictionary) -> bool:
	if data.turn.context.responses > 0 or data.world.state.whispers < catalog.integer("prayer_shallow_whispers"): return true
	var offered: Array = data.world.state.prayer_system.offered.duplicate()
	offered.sort_custom(func(a: String, b: String) -> bool:
		var first: Dictionary = data.world.state.prayer_system.requests[a]
		var second: Dictionary = data.world.state.prayer_system.requests[b]
		var first_rescue: bool = _mature_required_rescue(data, first.descriptor)
		var second_rescue: bool = _mature_required_rescue(data, second.descriptor)
		if first_rescue != second_rescue: return first_rescue
		var first_due: int = first.descriptor.crisis.get("due", first.card.due_turn)
		var second_due: int = second.descriptor.crisis.get("due", second.card.due_turn)
		return a < b if first_due == second_due else first_due < second_due)
	for id: String in offered:
		var entry: Dictionary = data.world.state.prayer_system.requests[id]
		if entry.status != "open": continue
		if _mature_required_rescue(data, entry.descriptor): return _mature_rescue(data, id)
		if not entry.descriptor.subjects.petitioner in data.people: continue
		var preview: Dictionary = data.prayers.preview(data.turn, id, "shallow")
		if not preview.get("ok", false): continue
		_choose_prayer_seed(data, "success", entry.descriptor.subjects.petitioner, entry.descriptor.domain)
		return _mature_ok(_response(data, id, "shallow"), "actual_required_person_response")
	return true

func _mature_required_rescue(data: Dictionary, descriptor: Dictionary) -> bool:
	return descriptor.content_id == "PRAYER_01" and descriptor.subjects.get("relative", "") in data.people

func _mature_rescue(data: Dictionary, id: String) -> bool:
	var ledger: Dictionary = data.world.state.prayer_system
	var entry: Dictionary = ledger.requests.get(id, {})
	if data.turn.context.phase != "actions" or data.turn.context.responses != 0 or not id in ledger.offered or entry.get("status") != "open" or not _mature_required_rescue(data, entry.descriptor):
		stage_error = "Required guardian rescue is not a current legal offered request"; return false
	var descriptor: Dictionary = entry.descriptor
	var root: String = descriptor.facts.condition; var patient: String = descriptor.subjects.relative
	var registered: String = entry.source; var crisis: Dictionary = descriptor.crisis.duplicate(true)
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.prayers.preview(data.turn, id, "shallow")
	var pure: bool = before == data.turn.snapshot()
	stage_actions.append({"stage": "required_guardian_rescue_prepare", "request": id, "patient": patient, "root": root, "result": preview, "pure": pure})
	if not preview.get("ok", false) or not pure:
		stage_error = "Original guardian rescue prepare unavailable or not pure"; return false
	var faith: int = data.world.state.faith; var whispers: int = data.world.state.whispers
	_choose_prayer_seed(data, "success", descriptor.subjects.petitioner, descriptor.domain)
	if not _mature_ok(_response(data, id, "shallow"), "actual_required_person_response"): return false
	var cure: String = str(Store.entry(data.world.state.invalid_records, root, ""))
	var fact: Dictionary = Store.entry(data.world.state.facts, cure, {})
	var result_id: String = str(Store.entry(data.world.state.applied_authorizations, "prayer/response/" + id, ""))
	var closed_id: String = str(Store.entry(data.world.state.applied_authorizations, "prayer/closed/" + id, ""))
	var resolution_id: String = str(Store.entry(data.world.state.applied_authorizations, "prayer/crisis/" + crisis.id, ""))
	var result: Dictionary = Store.entry(data.world.state.facts, result_id, {})
	var closed: Dictionary = Store.entry(data.world.state.facts, closed_id, {})
	var resolution: Dictionary = Store.entry(data.world.state.facts, resolution_id, {})
	var result_valid: bool = result.get("kind") == "prayer_result" and result.changes.get("request") == id and result.changes.get("prayer") == "PRAYER_01" and result.changes.get("variant") == "shallow" and result.changes.get("outcome") == "success" and result.changes.get("actor") == descriptor.subjects.petitioner and result.changes.get("produced", {}).get("condition_cured") == cure
	var predicates: Dictionary = _mature_rescue_closure(id, registered, crisis, root, result_id, resolution_id, resolution, closed, data.world.state.prayer_system)
	predicates.merge({"response_result": result_valid and result.get("id") == result_id, "root_invalidated_to_cure": not cure.is_empty() and fact.get("id") == cure and result.get("changes", {}).get("produced", {}).get("condition_cured") == cure, "resolution_identity": resolution.get("id") == resolution_id, "closed_identity": closed.get("id") == closed_id, "original_condition_cured": fact.get("kind") == "prayer_fact" and fact.changes.get("tag") == "condition_cured" and fact.changes.get("original") == root and patient in fact.targets, "patient_active": Store.entry(data.world.state.npcs, patient).status == "active", "one_response": data.turn.context.responses == 1, "original_faith_cost": int(preview.faith) == 0 and data.world.state.faith == faith - int(preview.faith), "original_whispers_cost": int(preview.whispers) == 1 and data.world.state.whispers == whispers - int(preview.whispers)})
	# Counterexamples only mutate detached fact copies; no additional engine scenario or world write.
	var wrong_result: Dictionary = resolution.duplicate(true); wrong_result["causal_parents"] = [root, "WRONG-RESULT-PARENT"]
	var wrong_closed: Dictionary = closed.duplicate(true); wrong_closed["causal_parents"] = [registered, "WRONG-CLOSED-RESOLUTION"]
	var counterexamples: Dictionary = {"wrong-result-parent": _mature_failed_predicates(_mature_rescue_closure(id, registered, crisis, root, result_id, resolution_id, wrong_result, closed, data.world.state.prayer_system)), "wrong-closed-resolution": _mature_failed_predicates(_mature_rescue_closure(id, registered, crisis, root, result_id, resolution_id, resolution, wrong_closed, data.world.state.prayer_system))}
	predicates["wrong_result_parent_rejected"] = counterexamples["wrong-result-parent"] == ["resolution_parents"]
	predicates["wrong_closed_resolution_rejected"] = counterexamples["wrong-closed-resolution"] == ["closed_parents"]
	var failures: Array[String] = _mature_failed_predicates(predicates)
	var valid: bool = failures.is_empty()
	stage_actions.append({"stage": "actual_required_guardian_cure", "request": id, "patient": patient, "root": root, "rootInvalidatedBy": cure, "registered": registered, "crisis": crisis, "resultId": result_id, "resolutionId": resolution_id, "closedId": closed_id, "cure": fact, "responseResult": result, "crisisResolution": resolution, "closedReceipt": closed, "faithPaid": faith - data.world.state.faith, "whispersPaid": whispers - data.world.state.whispers, "predicates": predicates, "failedPredicates": failures, "counterexamples": counterexamples, "valid": valid})
	if not valid: stage_error = "Actual guardian rescue failed predicates: " + ", ".join(failures)
	return valid

func _mature_rescue_closure(id: String, registered: String, crisis: Dictionary, root: String, result_id: String, resolution_id: String, resolution: Dictionary, closed: Dictionary, ledger: Dictionary) -> Dictionary:
	var resolved: Dictionary = resolution.get("changes", {}); var closure: Dictionary = closed.get("changes", {})
	return {"resolution_kind": resolution.get("kind") == "prayer_crisis_resolved", "resolution_crisis": resolved.get("crisis") == crisis.id, "resolution_due": resolved.get("due") == crisis.due, "resolution_root": crisis.source == root, "resolution_parents": resolution.get("causal_parents", []) == [root, result_id], "closed_kind": closed.get("kind") == "prayer_closed", "closed_request": closure.get("request") == id, "closed_crisis": closure.get("crisis") == crisis.id, "closed_reason": closure.get("reason") == "resolved", "closed_parents": closed.get("causal_parents", []) == [registered, resolution_id], "request_removed": not ledger.requests.has(id), "crisis_removed": not ledger.crises.has(crisis.id)}

func _mature_failed_predicates(predicates: Dictionary) -> Array[String]:
	var failed: Array[String] = []
	for predicate: String in predicates:
		if not predicates[predicate]: failed.append(predicate)
	return failed

func _mature_action_part(data: Dictionary, step: Dictionary, part: int) -> bool:
	if data.turn.context.phase != "actions" or step.kind in ["init", "round", "final"] or part < 0 or part > 1:
		stage_error = "Original action continuation phase or part mismatch"; return false
	if part == 0: return _mature_response(data)
	return _mature_stage(data, step, false)

func _mature_stage(data: Dictionary, step: Dictionary, respond: bool = true) -> bool:
	if step.kind == "init":
		return _mature_ok(_boot(data), "original_bootstrap") and _mature_open(data) and _mature_ok(_submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}), "original_release_initial_focus")
	if step.kind == "round":
		if not _mature_response(data): return false
		for op: String in ["end_actions", "advance", "advance", "advance"]:
			if not _mature_ok(_submit(data, op), "original_round/" + op): return false
		return _mature_open(data)
	if step.kind == "final": return _mature_final(data)
	if respond:
		_mature_mark("response.begin")
		if not _mature_response(data): return false
		_mature_mark("response.end")
	var slot: Dictionary = data.slots[step.slot]
	data.domain = slot.domain; data.institution = slot.institution; data.guardian = slot.guardian; data.actor = slot.guardian; data.route = slot.route; data.cult = slot.cult; data.source = data.world.state.domains[slot.domain].origin
	if step.kind == "dream":
		var payload: Dictionary = {"npc": slot.guardian, "source": data.contacts[slot.guardian], "qualification": data.dreams[slot.guardian]}
		_seed(data, "POWER_DREAM", "success", payload)
		return _mature_ok(_power(data, "POWER_DREAM", payload), "actual_dream")
	if step.kind == "deliver":
		for original: Dictionary in data.slots.slice(0, 2):
			if original.guardian == slot.guardian: continue
			var source: String = _mature_dream(data, original.guardian)
			if source.is_empty(): stage_error = "Missing actual original dream"; return false
			if not _mature_ok(_submit(data, "act", {"participant": "cults", "action": "transfer_material", "payload": {"sender": original.guardian, "recipient": slot.guardian, "source": source, "target_institution": slot.institution, "grant": "custody"}}), "actual_custody_delivery"): return false
		return true
	if step.kind == "exchange":
		var other: String = data.slots[3 + ((int(step.slot) - 3 + 1) % 3)].guardian
		if not _mature_ok(_route(data, "ROUTE_NETWORK_EXCHANGE", {"other": other}), "actual_network_exchange"): return false
		if int(step.slot) == 3:
			var before: String = data.turn.snapshot()
			var repeated: Dictionary = data.turn.submit(data.last_request)
			var exact: bool = before == data.turn.snapshot()
			stage_actions.append({"stage": "same_actual_request_replay", "result": repeated, "snapshotUnchanged": exact})
			if not repeated.get("ok", false) or not exact: stage_error = "Actual request replay changed source, payment or RNG"; return false
		return true
	if step.kind == "practice":
		return _mature_ok(_route(data, "ROUTE_DISSENT_PRACTICE", {"other": slot.partner, "record": _mature_dream(data, slot.guardian)}), "actual_dissent_practice")
	if step.kind == "recover":
		var opportunity: String = str(data.world.state.anchor_system.opportunities.get(slot.institution, ""))
		if opportunity.is_empty(): stage_error = "Current basis did not issue an available first opportunity"; return false
		return _mature_ok(_submit(data, "act", {"participant": "events", "action": "opportunity", "payload": {"opportunity": opportunity, "option": "recover"}}), "actual_first_relic_recovery")
	if step.kind == "anchor":
		_mature_mark("anchor_selection.begin")
		var options: Array = ActualAnchors.available(data.world.state, slot.institution, catalog, data.world.history).filter(func(item: Dictionary) -> bool: return item.route == slot.route)
		var media: Array = Store.values(data.world.state.relics).filter(func(item: Dictionary) -> bool: return item.domain == slot.domain and item.get("formal", false) and item.placement == "controlled")
		if options.size() != 1 or media.size() != 1: stage_error = "Expected one actual current proof and unbound recovered relic"; return false
		var payload: Dictionary = {"npc": slot.guardian, "institution": slot.institution, "relic": media[0].id, "source": options[0].source, "qualification": options[0].source}
		_mature_mark("anchor_selection.end")
		_mature_mark("anchor_preview.begin")
		var preview: Dictionary = data.powers.preview(data.turn, "POWER_ANCHOR", payload)
		_mature_mark("anchor_preview.end", {"ok": preview.get("ok", false)})
		if not preview.get("ok", false): stage_error = "Current original anchor prepare: " + str(preview); return false
		_mature_mark("anchor_seed.begin")
		_seed(data, "POWER_ANCHOR", "success", payload)
		_mature_mark("anchor_seed.end")
		_mature_mark("anchor_submit.begin")
		var submitted: Dictionary = _power(data, "POWER_ANCHOR", payload)
		_mature_mark("anchor_submit.end", {"ok": submitted.get("ok", false), "metrics": data.turn.last_transaction_metrics})
		return _mature_ok(submitted, "actual_anchor_binding")
	stage_error = "Unknown fixed step"; return false

func _mature_dream(data: Dictionary, person: String) -> String:
	for source: String in data.world.history.anchor_material_heads(Store.entry(data.world.state.npcs, person).domain, 2):
		var fact: Dictionary = Store.entry(data.world.state.facts, source, {})
		if fact.get("kind") == "miracle" and fact.changes.get("power") == "POWER_DREAM" and fact.actor == person: return source
	return ""

func _mature_summary(data: Dictionary) -> Dictionary:
	var anchors: Array = []
	for slot: Dictionary in data.slots:
		var id: String = "ANCHOR/" + slot.institution
		if data.world.state.anchors.has(id):
			anchors.append({"anchor": data.world.state.anchors[id].duplicate(true), "binding": data.world.state.anchor_system.bindings.get(id, {}).duplicate(true)})
	return {"turn": data.turn.context.turn, "phase": data.turn.context.phase, "awakening": data.world.state.awakening, "insight": data.world.state.insight, "wounds": data.world.state.wounds, "faith": data.world.state.faith, "anchors": anchors, "commitSequence": data.turn.commit_sequence, "factCount": Store.size(data.world.state.facts), "catalog": catalog.version, "participants": data.turn.capabilities()}

func _mature_final(data: Dictionary) -> bool:
	var state: Dictionary = _mature_summary(data)
	if state.anchors.size() != 9 or state.awakening != 93 or state.insight != 20 or state.wounds != 0: stage_error = "Mature world does not have nine anchors and actual A93"; return false
	var payments: Array = _facts(data.world, "economy_anchor_payment")
	var opportunities: Array = _facts(data.world, "institution_relic_opportunity")
	var evidence: Array = []
	for slot: Dictionary in data.slots:
		var id: String = "ANCHOR/" + slot.institution; var anchor: Dictionary = data.world.state.anchors[id]
		var binding: Dictionary = data.world.state.anchor_system.bindings[id]
		if anchor.state != "active" or anchor.route != slot.route or binding.route != slot.route or anchor.ordinal != MATURE_ROLES.find(slot.institution.get_file()) + 1: stage_error = "Final active/binding/ordinal invariant failed"; return false
		if opportunities.filter(func(f: Dictionary) -> bool: return f.changes.institution == slot.institution).size() != 1: stage_error = "First opportunity identity is not unique"; return false
		if payments.filter(func(f: Dictionary) -> bool: return f.changes.anchor == id and f.turn == data.world.state.economy.prepay_turn and f.changes.fee == catalog.integer("anchor_" + str(data.world.state.domains[slot.domain].tier) + "_upkeep")).size() != 1: stage_error = "Current real upkeep payment missing"; return false
		evidence.append({"anchor": anchor.duplicate(true), "binding": binding.duplicate(true), "basis": Store.entry(data.world.state.facts, binding.proof), "relic": Store.entry(data.world.state.relics, anchor.relic), "opportunity": opportunities.filter(func(f: Dictionary) -> bool: return f.changes.institution == slot.institution)[0], "currentPayment": payments.filter(func(f: Dictionary) -> bool: return f.changes.anchor == id and f.turn == data.world.state.economy.prepay_turn)[0]})
	stage_actions.append({"stage": "actual_nine_current_anchor_chains", "evidence": evidence})
	var cosmic: String = "ANCHOR/" + data.slots[6].institution; var system: String = "ANCHOR/" + data.slots[3].institution
	var payload: Dictionary = {"npc": data.slots[6].guardian, "source": data.world.state.anchors[cosmic].established_source, "cosmic_anchor": cosmic, "system_anchor": system}
	var before: String = data.turn.snapshot(); var prepared: Dictionary = data.powers.preview(data.turn, "POWER_MANIFEST", payload)
	stage_actions.append({"stage": "final_original_manifest_prepare_only", "payload": payload, "result": prepared, "pure": before == data.turn.snapshot()})
	if not prepared.get("ok", false) or before != data.turn.snapshot(): stage_error = "Final shared manifestation prepare unavailable or not pure"; return false
	return true
