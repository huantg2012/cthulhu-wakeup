extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const Eligibility = preload("res://src/game/opportunity_eligibility.gd")
const PlayerKnowledge = preload("res://src/game/player_knowledge.gd")
var session: RefCounted
var records: Array = []
var scratch: String
var request_id: String = ""
var entry: String = ""
var phase_control: Dictionary = {}
var resource_control: Dictionary = {}

func _check(id: String, name: String, passed: bool, details: Dictionary) -> void:
	records.append({"id": id, "name": name, "status": "pass" if passed else "fail", "details": details})

func _initialize() -> void:
	scratch = OS.get_cmdline_user_args()[0].get_base_dir()
	session = Session.new(scratch.path_join("session-campaigns"))
	var opened: Dictionary = session.start_new(1)
	if opened.get("ok", false):
		_current_entry(opened)
		_privacy_and_purity()
		_knowledge_and_round()
		_rejections()
	else: _check("OE-SESSION", "Actual new game starts", false, {"startup": opened})
	var passed: bool = records.size() == 4 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "scope": "four_bounded_shared_eligibility_groups", "checks": records, "fixtures": ["Actual eleven-module Session.start_new(1), original bootstrap PR08 and normal round advancement. Successful check roll is controlled, not a natural success-rate claim.", "Copied read-view budget and offered-list controls are read-only consumer inputs; they do not claim actual world resource changes or hidden request production.", "Detached player knowledge reducer reconstruction is a component check, not complete Session save/continue.", "No goal registration, next-step planning, FIFO, dispatch compensation, service receipt, pipeline bound, all-route closure or human UI acceptance."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _view(participant: String = "prayers") -> Dictionary:
	return session.turn._read_view(participant, "actions")

func _query(key: String, payload: Dictionary = {}) -> Dictionary:
	var view: Dictionary = _view()
	var result: Dictionary = Eligibility.query(view, _ledger(), session.modules, key, payload)
	view.reader.close()
	return result

func _same_rejection(shared: Dictionary, public_result: Dictionary) -> bool:
	return not shared.get("ok", false) and not public_result.get("ok", false) and session.explain_error(str(shared.get("error", ""))) == public_result.get("error", "")

func _seed_success(probability: int) -> void:
	for value: int in range(1, 101):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = value
		if session.world.check_result(probability, rng.randi_range(1,100)) == "success": session.world.randoms.checks.seed = value; return

func _round() -> Array:
	var results: Array = [session._submit("end_actions")]
	for step: int in 4: results.append(session._submit("advance"))
	results.append(session._submit("finish_events"))
	return results

func _ledger() -> Dictionary:
	return session.knowledge_snapshot()

func _current_entry(opened: Dictionary) -> void:
	for id: String in session.world.state.prayer_system.offered:
		if session.prayer_entry(id).get("descriptor", {}).get("content_id") == "PRAYER_08": request_id = id; break
	entry = "prayer/" + request_id + "/shallow"
	var phase_query: Dictionary = _query(entry)
	var phase_public: Dictionary = session.preview_action(entry)
	phase_control = {"shared": phase_query, "public": phase_public, "actualPhase": session.turn.context.phase, "bothRejected": not phase_query.get("ok", false) and not phase_public.get("ok", false)}
	var advanced: Dictionary = session._submit("finish_events")
	var before: String = session.turn.snapshot()
	var knowledge_before: Dictionary = _ledger()
	var shared: Dictionary = _query(entry)
	var public_preview: Dictionary = session.preview_action(entry)
	var command: Dictionary = Session.Actions.new().command(session, entry, {})
	var view: Dictionary = _view()
	var original: Dictionary = session.modules.prayers.prepare(view, request_id, "shallow")
	var attention: Dictionary = session.world.attention.preview_needs(view.world, original.get("attention", {}), [], "") if original.get("ok", false) else {}
	var poor: Dictionary = view.duplicate(true); poor.world.whispers = 0
	var poor_query: Dictionary = Eligibility.query(poor, knowledge_before, session.modules, entry, {})
	var poor_original: Dictionary = session.modules.prayers.prepare(poor, request_id, "shallow")
	resource_control = {"kind": "read_only_current_budget_counterfactual", "shared": poor_query, "original": poor_original, "sameReason": not poor_query.get("ok", false) and poor_query.get("error") == poor_original.get("error")}
	view.reader.close()
	var plan: Dictionary = shared.get("plan", shared.get("preview", {}))
	var pure: bool = before == session.turn.snapshot() and knowledge_before == _ledger()
	var valid: bool = not request_id.is_empty() and session.modules.size() == 11 and advanced.get("ok", false) and shared.get("ok", false) and public_preview.get("ok", false) and original.get("ok", false) and attention.get("ok", false)
	valid = valid and shared.get("op") == command.get("op") and shared.get("fields") == command.get("fields") and int(plan.get("faith", -1)) == int(original.get("faith", -2)) and int(plan.get("whispers", -1)) == int(original.get("whispers", -2)) and pure
	_check("OE-CURRENT", "Actual eleven-module new game uses shared entry query and original prepare/Attention", valid, {"startup": opened, "installed": session.modules.keys(), "entry": entry, "shared": shared, "publicPreview": public_preview, "command": command, "originalCosts": {"faith": original.get("faith"), "whispers": original.get("whispers")}, "attention": attention, "pure": pure})

func _privacy_and_purity() -> void:
	var knowledge: Dictionary = _ledger()
	var unknown_person: String = ""; var unknown_source: String = ""
	for id: String in session.world.history.ids("living"):
		if not session._identity_known(id): unknown_person = id; break
	for number: int in range(1, int(session.world.state.next_fact)):
		var id: String = "FACT-%08d" % number
		if not session.is_known_source(id): unknown_source = id; break
	var before: String = session.turn.snapshot(); var knowledge_before: String = JSON.stringify(knowledge)
	var source: String = session.world.state.domains["DOMAIN-001"].origin
	var selected_person: String = str(session.prayer_entry(request_id).descriptor.subjects.petitioner)
	var hidden_person: Dictionary = _query("route/context", {"domain": "DOMAIN-001", "operation": "ROUTE_RECORD_PRACTICE", "npc": unknown_person, "source": source})
	var hidden_source: Dictionary = _query("POWER_LISTEN", {"domain": "DOMAIN-001", "source": unknown_source})
	var view: Dictionary = _view()
	var input_before: String = JSON.stringify(view.world)
	var hidden: Dictionary = view.duplicate(true); hidden.world.prayer_system.offered = []
	var absent: Dictionary = Eligibility.query(hidden, knowledge, session.modules, entry, {})
	var no_player_clue: Dictionary = Eligibility.query(view, PlayerKnowledge.empty_ledger(), session.modules, entry, {})
	var repeated: Dictionary = Eligibility.query(view, knowledge, session.modules, entry, {})
	var again: Dictionary = Eligibility.query(view, knowledge, session.modules, entry, {})
	var snapshot: Dictionary = PlayerKnowledge.empty_ledger()
	snapshot.known_domains = knowledge.known_domains.duplicate(true)
	# Preserve sealed archive roots; only the controlled offered list is detached.
	var hidden_state: Dictionary = session.world.state.duplicate(false)
	hidden_state.prayer_system = session.world.state.prayer_system.duplicate(true)
	hidden_state.prayer_system.offered = []
	var hidden_knowledge: Dictionary = PlayerKnowledge.reduce(hidden_state, hidden.turn, snapshot, session.catalog, session.world.history, [], {})
	var no_clue: bool = not hidden_knowledge.known_prayers.has(request_id) and not hidden_knowledge.request_people.has(selected_person) and int(hidden_knowledge.cursor) == int(hidden_state.next_fact)
	var input_pure: bool = input_before == JSON.stringify(view.world) and knowledge_before == JSON.stringify(knowledge)
	view.reader.close()
	var no_disclosure: bool = not str(hidden_person.get("error", "")).contains(unknown_person) and not str(hidden_source.get("error", "")).contains(unknown_source)
	var valid: bool = not unknown_person.is_empty() and not unknown_source.is_empty() and not hidden_person.get("ok", false) and not hidden_source.get("ok", false) and hidden_source.get("error", "") == "缺少或已失效：资格来源 · 聆听痕迹" and not absent.get("ok", false) and not no_player_clue.get("ok", false) and repeated == again and input_pure and before == session.turn.snapshot() and no_clue and no_disclosure
	_check("OE-PRIVACY", "Unknown people/sources and an unoffered request remain hidden; queries preserve all authoritative inputs", valid, {"unknownPersonRejected": hidden_person, "unknownSourceRejected": hidden_source, "unknownSourceEntry": "POWER_LISTEN", "unknownSourceRejectedAtSourceField": hidden_source.get("error", "") == "缺少或已失效：资格来源 · 聆听痕迹", "unofferedRequest": absent, "actualOfferWithoutPlayerClue": no_player_clue, "unofferedControl": "read_only_offered_list_control_over_actual_request", "unofferedDoesNotGrantClue": no_clue, "privateIdentifiersNotInError": no_disclosure, "sameRepeatedQuery": repeated == again, "inputViewAndLedgerUnchanged": input_pure, "worldRngFeesCandidatesAttentionUnchanged": before == session.turn.snapshot()})

func _knowledge_and_round() -> void:
	var prior: Dictionary = _ledger()
	var first_fact: int = int(session.world.state.next_fact)
	var request: Dictionary = {"op": "act", "participant": "prayers", "action": "respond", "payload": {"request": request_id, "variant": "shallow"}}
	var roots: Dictionary = PlayerKnowledge.command_roots(session.world.state, session.turn.context, prior, session.catalog, session.world.history, request)
	var prepared: Dictionary = session.modules.prayers.preview(session.turn, request_id, "shallow")
	if prepared.get("ok", false): _seed_success(int(prepared.probability))
	var responded: Dictionary = session.execute_action(entry, {}, true, "OE-ORIGINAL-PR08")
	var after: Dictionary = _ledger()
	var proofs: Array = session.modules.player_sources.available(session.turn)
	var serialized_prior: String = JSON.stringify(prior)
	var reduced: Dictionary = PlayerKnowledge.reduce(session.world.state, session.turn.context, prior, session.catalog, session.world.history, proofs, {"own_action": true, "first_fact": first_fact, "roots": roots})
	var before_repeat: String = session.turn.snapshot()
	var repeated: Dictionary = PlayerKnowledge.reduce(session.world.state, session.turn.context, after, session.catalog, session.world.history, proofs, {})
	var saved: Dictionary = {"domains": session.known_domains(), "people": session.known_people(), "facts": session.known_sources(), "cursor": after.cursor}
	var rebuilt: Dictionary = PlayerKnowledge.restore_ledger(session.world.state, session.turn.context, saved, session.catalog, session.world.history)
	var repeated_result: Dictionary = session.execute_action(entry, {}, true, "OE-ORIGINAL-PR08")
	var once: bool = responded.get("ok", false) and repeated_result.get("ok", false) and before_repeat == session.turn.snapshot()
	var actual_result_known: bool = false
	for number: int in range(first_fact, int(session.world.state.next_fact)):
		var fact: Dictionary = Store.entry(session.world.state.facts, "FACT-%08d" % number)
		if fact.kind == "prayer_result" and after.known_facts.has(fact.id): actual_result_known = true
	var restored_shape: bool = rebuilt.known_domains == after.known_domains and rebuilt.known_people == after.known_people and rebuilt.known_facts == after.known_facts
	var valid: bool = restored_shape and responded.get("ok", false) and after.known_facts.size() > prior.known_facts.size() and actual_result_known and reduced == after and repeated == after and JSON.stringify(prior) == serialized_prior and once
	var cycle: Array = _round()
	valid = valid and cycle.all(func(value: Dictionary) -> bool: return value.get("ok", false)) and session.turn.context.turn == 2 and session.turn.context.phase == "actions"
	var view: Dictionary = _view()
	var original_query: Dictionary = Eligibility.query(view, after, session.modules, "SESSION_REST", {})
	var rebuilt_query: Dictionary = Eligibility.query(view, rebuilt, session.modules, "SESSION_REST", {})
	var plan_command: Dictionary = Eligibility.query(view, after, session.modules, "SESSION_SET_ECONOMY_PLAN", {})
	var original_rest: Dictionary = session.modules.economy.preview_rest(view.world, view.turn)
	view.reader.close()
	valid = valid and original_query == rebuilt_query and plan_command.get("ok", false) and plan_command.get("op") == "set_plan" and plan_command.get("fields", {}).get("participant") == "economy" and original_query.get("ok") == original_rest.get("ok") and original_query.get("error") == original_rest.get("error")
	_check("OE-REDUCER", "Actual PR08 result advances the original ledger; detached reducer, replay and normal Session round agree", valid, {"response": responded, "knownFactCountBefore": prior.known_facts.size(), "knownFactCountAfter": after.known_facts.size(), "actualResultKnown": actual_result_known, "reducerMatchesSession": reduced == after, "repeatReducerStable": repeated == after, "componentRebuildQueryMatches": original_query == rebuilt_query, "componentSavedKnowledgePreserved": restored_shape, "componentRebuildScope": "original_saved_knowledge_shape_only_no_complete_Session_restore", "durableResultOnce": once, "planCommand": plan_command, "restQuery": original_query, "originalRest": original_rest, "aliasScope": "DREAM and PR06 aliases statically reviewed; no alias parameter matrix", "fullRound": cycle, "finalTurn": session.turn.context.turn, "finalPhase": session.turn.context.phase})

func _route_choice() -> Dictionary:
	for id: String in session.current_people():
		var person: Dictionary = Store.entry(session.world.state.npcs, id)
		if not "record_keeper" in person.role_tags: continue
		for source: String in session.current_sources():
			if Store.entry(session.world.state.facts, source).domain != person.domain: continue
			var choice: Dictionary = {"domain": person.domain, "npc": id, "source": source, "operation": "ROUTE_RECORD_PRACTICE"}
			if session.preview_action("route/context", choice).get("ok", false): return choice
	return {}

func _rejections() -> void:
	var choice: Dictionary = _route_choice()
	var prepared: Dictionary = _query("route/context", choice)
	var plan: Dictionary = prepared.get("plan", prepared.get("preview", {}))
	if prepared.get("ok", false): _seed_success(int(plan.get("probability", 100)))
	var performed: Dictionary = session.execute_action("route/context", choice, true, "OE-RECORD-PRACTICE")
	var before: String = session.turn.snapshot(); var knowledge: Dictionary = _ledger()
	var acted: Dictionary = _query("route/context", choice)
	var public_acted: Dictionary = session.preview_action("route/context", choice)
	var again: Dictionary = _query("route/context", choice)
	var pure: bool = before == session.turn.snapshot() and knowledge == _ledger()
	var valid: bool = not choice.is_empty() and performed.get("ok", false) and _same_rejection(acted, public_acted) and acted == again and phase_control.get("bothRejected", false) and resource_control.get("sameReason", false) and pure
	_check("OE-REJECTIONS", "Actual already-acted and initial stage rejection match the UI; copied budget control preserves original refusal", valid, {"actualRouteAction": performed, "alreadyActedShared": acted, "alreadyActedPublic": public_acted, "phaseControl": phase_control, "budgetControl": resource_control, "pureRepeatedReject": pure})
