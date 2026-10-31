extends RefCounted
## Owns terminal priority and the sourced disconnection clock. Business
## eligibility remains in Prayers/Powers/Events and their shared admission gate.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const ID: String = "endings"
const SCHEMA: int = 1
var catalog: RefCounted
var version: String

func _init(content: RefCounted) -> void:
	catalog = content; version = rule_version(content)

static func rule_version(content: RefCounted) -> String:
	return "1/" + content.version + "/" + str(content.extension_versions.get("powers", "")) + "/" + str(content.extension_versions.get("prayer_effects", ""))

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("ending_system") or turn._owners.has("ending"): return false
	for dependency: String in ["powers", "prayers", "events", "resistance"]:
		if not turn._participants.has(dependency): return false
	if not turn.world.state.power_system.completion.is_empty(): return false
	turn.world.state["ending_system"] = {"schema": SCHEMA, "version": version, "last_turn": 0, "disconnected": 0, "assessment": "", "terminal": ""}
	if not turn.register_participant(ID, version, ["ending"], ["endings"], handle):
		turn.world.state.erase("ending_system"); return false
	return turn.world.ensure_history(true)

func handle(_view: Dictionary, input: Dictionary) -> Dictionary:
	return {"ok": input.get("slot") == "ending", "empty": false, "effects": [{"type": "endings", "operation": "settle"}], "state": {}}

func validate_effect(state: Dictionary, slot: String, effect: Dictionary) -> bool:
	return slot == "ending" and effect == {"type": "endings", "operation": "settle"} and state.get("ending_system", {}).get("version") == version

func _next_view(turn: RefCounted) -> Dictionary:
	var view: Dictionary = turn._read_view(ID, "ending")
	view.world.turn += 1
	view.world.whispers = mini(catalog.integer("whisper_cap"), catalog.integer("whisper_base") + int(floor(float(view.world.awakening) / catalog.number("whisper_growth_step"))))
	view.turn.responses = 0; view.turn.power_used = false; view.turn.relic_used = false
	if view.world.has("attention"): turn.world.attention.round_start_state(view.world, turn.world.history)
	return view

func _admitted(turn: RefCounted, state: Dictionary, request: Dictionary) -> bool:
	return not state.has("attention") or turn.world.attention.preview_needs(state, request, [], "").ok

func contacts(turn: RefCounted) -> Array:
	var state: Dictionary = turn.world.state
	for cult: Dictionary in state.cults.values():
		if cult.status in ["active", "dormant"]: return [{"kind": "cult", "subject": cult.id, "source": cult.established_source}]
	var view: Dictionary = _next_view(turn)
	var result: Array = []
	var prayers: RefCounted = turn._participants.prayers.instance
	var cards: Array = view.world.get("simulation", {}).get("candidates", {}).keys(); cards.sort()
	for id: String in cards:
		var card: Dictionary = view.world.simulation.candidates[id]
		if not str(card.get("content_id", "")).begins_with("PRAYER_") or int(card.due_turn) < int(view.world.turn): continue
		var when: int = maxi(int(view.world.turn), int(card.visible_turn))
		for actor: String in card.get("actors", []):
			var detention: Dictionary = state.power_system.detentions.get(actor, {})
			var person: Dictionary = Store.entry(state.npcs, actor, {})
			if person.get("status") == "detained" and detention.get("source") == person.get("status_source"):
				when = maxi(when, int(detention.due))
		if when > int(card.due_turn): continue
		var query: Dictionary = view.duplicate(false); query.world = view.world.duplicate(true); query.turn = view.turn.duplicate(true)
		query.world.turn = when
		var releases: Array = []
		for actor: String in card.get("actors", []):
			if not state.power_system.detentions.has(actor): continue
			var detention: Dictionary = state.power_system.detentions[actor]
			var person: Dictionary = Store.entry(state.npcs, actor, {})
			if int(detention.due) <= when and person.get("status") == "detained" and person.get("status_source") == detention.source:
				var projected: Dictionary = view.reader.entity("npcs", actor).item
				projected.status = "active"; query.world.npcs[actor] = projected
				releases.append(detention.source)
		if query.world.has("attention"): turn.world.attention.round_start_state(query.world, turn.world.history)
		query.world.prayer_system.offer_turn = when; query.world.prayer_system.offered = [id]
		if not query.world.prayer_system.requests.has(id): query.world.prayer_system.requests[id] = {"card": card, "status": "open"}
		var prepared: Dictionary = prayers.prepare(query, id, "shallow")
		if prepared.ok and _admitted(turn, query.world, prepared.attention):
			result.append({"kind": "prayer", "subject": id, "source": card.fact, "visible": card.visible_turn, "due": card.due_turn, "when": when, "releases": releases}); break
	if result.is_empty():
		for source: String in turn.world.history.ids("ending_listen"):
			var fact: Dictionary = Store.entry(state.facts, source)
			var prepared: Dictionary = turn._participants.powers.instance.prepare(view, "POWER_LISTEN", {"domain": fact.domain, "source": source, "qualification": source})
			if prepared.ok and prepared.faith == 0 and _admitted(turn, view.world, prepared.attention):
				result.append({"kind": "medium", "subject": str(fact.changes.target), "source": source}); break
	if result.is_empty():
		for source: String in state.anchor_system.opportunities.values():
			var opportunity: Dictionary = Store.entry(state.facts, source)
			var members: Array = view.world.attention.members.keys() if view.world.has("attention") else turn.world.history.ids("active/" + str(opportunity.domain))
			for npc: String in members:
				var prepared: Dictionary = turn._participants.events.instance.prepare_opportunity(view, {"opportunity": source, "option": "recover", "npc": npc})
				if prepared.ok and _admitted(turn, view.world, prepared.plan.attention):
					result.append({"kind": "opportunity", "subject": prepared.plan.institution, "source": source}); break
			if not result.is_empty(): break
	view.reader.close()
	return result

func preview(turn: RefCounted) -> Dictionary:
	if turn._in_transaction or turn._in_participant or turn.world.state.get("ending_system", {}).get("version") != version: return {"ok": false}
	var ledger: Dictionary = turn.world.state.ending_system
	return {"ok": true, "disconnected": ledger.disconnected, "limit": catalog.integer("disconnection_limit"), "contacts": contacts(turn) if ledger.terminal.is_empty() else [], "ritual": turn.world.state.power_system.manifest.duplicate(true), "terminal": ledger.terminal}

func commit(world: RefCounted, _effect: Dictionary, owner: RefCounted) -> bool:
	if not world._driver_allowed(owner) or owner.context.phase != "ending": return false
	world.stage_current(); world.stage_collections(["ending_system"])
	world._refresh_anchors()
	var ledger: Dictionary = world.state.ending_system
	if not ledger.terminal.is_empty() or ledger.last_turn != int(world.state.turn) - 1: return false
	var reachable: Array = contacts(owner)
	var before: int = ledger.disconnected
	var parents: Array = [] if ledger.assessment.is_empty() else [ledger.assessment]
	for entry: Dictionary in reachable:
		parents.append(entry.source)
		for source: String in entry.get("releases", []):
			if not source in parents: parents.append(source)
	var count: int = before + 1 if reachable.is_empty() else 0
	var assessed: String = world._record("ending_assessed", "", "", [], parents, {"previous": ledger.assessment, "before": before, "count": count, "contacts": reachable, "awakening": world.state.awakening})
	ledger.last_turn = world.state.turn; ledger.disconnected = count; ledger.assessment = assessed
	var powers: RefCounted = owner._participants.powers.instance
	if int(world.state.awakening) <= 0 or count >= catalog.integer("disconnection_limit"):
		powers._interrupt(world, "extinction_priority")
		return _seal(world, owner, "extinction", "awakening_zero" if int(world.state.awakening) <= 0 else "disconnected")
	if not powers.finish_manifest(world, owner): return false
	world._refresh_anchors()
	if not world.state.power_system.completion.is_empty(): return _seal(world, owner, "awakened", "manifest_completed")
	if int(world.state.awakening) <= 0: return _seal(world, owner, "extinction", "manifest_failure")
	return true

func abandon(world: RefCounted, owner: RefCounted) -> bool:
	if not world._driver_allowed(owner) or not world.state.get("ending_system", {}).get("terminal", "").is_empty(): return false
	world.stage_current(); world.stage_collections(["ending_system"])
	owner._participants.powers.instance._interrupt(world, "voluntary_extinction")
	return _seal(world, owner, "extinction", "voluntary")

func _seal(world: RefCounted, owner: RefCounted, outcome: String, reason: String) -> bool:
	var ledger: Dictionary = world.state.ending_system
	var parents: Array = [] if ledger.assessment.is_empty() else [ledger.assessment]
	var completion: String = world.state.power_system.completion
	if not completion.is_empty(): parents.append(completion)
	var source: String = world._record("ending_sealed", "", "", [], parents, {"outcome": outcome, "reason": reason, "phase": owner.context.phase, "assessment": ledger.assessment, "completion": completion, "disconnected": ledger.disconnected, "awakening": world.state.awakening})
	ledger.terminal = source
	owner.context.outcome = outcome
	world.state.phase = "between"
	if reason == "voluntary": owner.context.phase = "ended"
	return true

func review(turn: RefCounted, cursor: int = 0, limit: int = 20) -> Dictionary:
	if turn._in_transaction or turn._in_participant or cursor < 0 or limit < 1 or limit > turn.world.history.page_limit or turn.world.state.get("ending_system", {}).get("terminal", "").is_empty(): return {"ok": false}
	var facts: Array = []
	var total: int = int(turn.world.state.next_fact) - 1
	if cursor > total: return {"ok": false}
	var end: int = mini(total, cursor + limit)
	for offset: int in range(cursor, end): facts.append(Store.entry(turn.world.state.facts, "FACT-%08d" % (offset + 1)).duplicate(true))
	return {"ok": true, "outcome": turn.context.outcome, "seed": str(turn.world.randoms.generation.seed), "terminal": Store.entry(turn.world.state.facts, turn.world.state.ending_system.terminal).duplicate(true), "facts": facts, "cursor": end, "complete": end == total}

static func validate_state(state: Dictionary, content: RefCounted, index: RefCounted = null) -> Array[String]:
	if not state.has("ending_system"): return []
	var ledger: Variant = state.ending_system
	if not ledger is Dictionary or ledger.size() != 6 or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content) or not ledger.get("last_turn") is int or not ledger.get("disconnected") is int or ledger.disconnected < 0 or not ledger.get("assessment") is String or not ledger.get("terminal") is String: return ["Invalid endings schema/capability"]
	if ledger.last_turn < 0 or ledger.last_turn > state.turn: return ["Invalid assessment round"]
	if ledger.terminal.is_empty() and not state.power_system.completion.is_empty(): return ["Completed manifest has no terminal seal"]
	var heads: Dictionary = {}
	if index == null:
		for fact: Dictionary in Store.values(state.facts):
			if fact.kind == "ending_assessed":
				var issues: Array[String] = _assessment_errors(state, fact)
				if not issues.is_empty(): return issues
			if fact.kind in ["ending_assessed", "ending_sealed"] and str(fact.id) > str(heads.get(fact.kind, "")): heads[fact.kind] = fact.id
	else:
		for kind: String in ["ending_assessed", "ending_sealed"]: heads[kind] = History.mapget(index.data.get("ending_heads", History.from_value({}, "map")), kind, "")
	if ledger.assessment != heads.get("ending_assessed", "") or ledger.terminal != heads.get("ending_sealed", ""): return ["Endings current head differs from recorded history"]
	if ledger.assessment.is_empty():
		if ledger.last_turn != 0 or ledger.disconnected != 0: return ["Unfounded disconnection count"]
	else:
		var fact: Dictionary = Store.entry(state.facts, ledger.assessment, {})
		if fact.get("kind") != "ending_assessed" or fact.turn != ledger.last_turn or fact.changes.get("count") != ledger.disconnected: return ["Disconnection differs from its assessment"]
		var issues: Array[String] = _assessment_errors(state, fact)
		if not issues.is_empty(): return issues
	if not ledger.terminal.is_empty():
		var terminal: Dictionary = Store.entry(state.facts, ledger.terminal, {})
		if terminal.get("kind") != "ending_sealed" or terminal.turn != state.turn or terminal.changes.get("assessment") != ledger.assessment or terminal.changes.get("disconnected") != ledger.disconnected or terminal.changes.get("awakening") != state.awakening or not state.power_system.manifest.is_empty(): return ["Terminal seal disagrees with current state"]
		var data: Dictionary = terminal.changes
		if not data.get("outcome") in ["extinction", "awakened"] or not data.get("reason") in ["voluntary", "awakening_zero", "disconnected", "manifest_failure", "manifest_completed"] or not data.get("phase") in ["between", "events", "actions", "evolution", "settlement", "ending"]: return ["Invalid ending reason"]
		if data.reason == "manifest_completed":
			if data.outcome != "awakened" or data.completion != state.power_system.completion or data.completion.is_empty() or not data.completion in terminal.causal_parents or state.awakening != content.integer("awakening_terminal"): return ["Victory lacks its real manifest completion"]
		elif data.outcome != "extinction" or (data.reason in ["awakening_zero", "manifest_failure"] and state.awakening > 0) or (data.reason == "disconnected" and ledger.disconnected < content.integer("disconnection_limit")): return ["Extinction has no qualifying cause"]
	return []

static func _assessment_errors(state: Dictionary, fact: Dictionary) -> Array[String]:
	var data: Dictionary = fact.changes
	if not data.get("count") is int or data.count < 0 or not data.get("contacts") is Array or not data.get("previous") is String or not data.get("before") is int or not data.get("awakening") is int: return ["Invalid disconnection assessment"]
	if data.count != (data.before + 1 if data.contacts.is_empty() else 0): return ["Disconnection does not follow contact state"]
	if data.previous.is_empty():
		if fact.turn != 1 or data.before != 0: return ["Disconnection history did not begin at first round"]
	else:
		var prior: Dictionary = Store.entry(state.facts, data.previous, {})
		if prior.get("kind") != "ending_assessed" or int(prior.turn) != int(fact.turn) - 1 or prior.changes.get("count") != data.before or not data.previous in fact.causal_parents: return ["Disconnection history skipped a round"]
	for contact: Variant in data.contacts:
		if not contact is Dictionary or not contact.get("kind") in ["cult", "prayer", "medium", "opportunity"] or not contact.get("subject") is String or not contact.get("source") in fact.causal_parents: return ["Contact lacks its actual source"]
		var source: Dictionary = Store.entry(state.facts, contact.source, {})
		if source.is_empty() or int(source.turn) > int(fact.turn): return ["Contact source is absent or from the future"]
		match contact.kind:
			"cult":
				if source.kind != "cult_established" or source.changes.get("cult") != contact.subject: return ["Cult contact changed its establishment"]
			"medium":
				if source.kind != "power_qualification" or source.changes.get("rule") != "listen" or source.changes.get("target") != contact.subject: return ["Medium contact changed its qualification"]
			"opportunity":
				if source.kind != "institution_relic_opportunity" or source.changes.get("institution") != contact.subject or int(source.changes.due) < int(fact.turn) + 1: return ["Opportunity contact changed its source or deadline"]
			"prayer":
				var card: Dictionary = source.changes.get("candidate", {})
				if not source.kind in ["prayer_fixed", "background_fixed"] or card.get("id") != contact.subject or not str(card.get("content_id", "")).begins_with("PRAYER_") or card.get("visible_turn") != contact.get("visible") or card.get("due_turn") != contact.get("due") or not contact.get("when") is int or contact.when < maxi(int(fact.turn) + 1, int(contact.visible)) or contact.when > int(contact.due) or not contact.get("releases") is Array: return ["Prayer contact changed its fixed candidate or window"]
				for release: Variant in contact.releases:
					if not release is String or not release in fact.causal_parents: return ["Future contact lacks its release source"]
					var detention: Dictionary = Store.entry(state.facts, release, {})
					if detention.get("kind") != "status_change" or detention.changes.get("to") != "detained" or not detention.actor in card.actors: return ["Future contact release belongs to another subject"]
	return []
