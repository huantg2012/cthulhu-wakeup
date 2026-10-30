extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## The only session-level clock. Participants are stateless, versioned rule adapters:
## they read copies and return allowed declarations; they never receive mutable World.
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const StateView = preload("res://src/simulation/state_view.gd")
const World = preload("res://src/simulation/world.gd")
const Economy = preload("res://src/game/economy.gd")
const Cults = preload("res://src/game/cults.gd")
const Powers = preload("res://src/game/powers.gd")
const Relics = preload("res://src/game/relics.gd")
const Prayers = preload("res://src/game/prayers.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Events = preload("res://src/game/events.gd")
const Resistance = preload("res://src/game/resistance.gd")
const PlayerSources = preload("res://src/game/player_sources.gd")
const Endings = preload("res://src/game/endings.gd")
const PrayerProducers = preload("res://src/game/prayer_producers.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const SocialGraph = preload("res://src/simulation/social_graph.gd")
const Progression = preload("res://src/game/progression_routes.gd")
const Eligibility = preload("res://src/game/opportunity_eligibility.gd")
const Admission = preload("res://src/game/action_admission.gd")
const PlayerKnowledge = preload("res://src/game/player_knowledge.gd")
const Opportunities = preload("res://src/game/opportunity_service.gd")
const SCHEMA_VERSION: int = 3
const SLOTS: Array[String] = ["player_sources", "events", "actions", "prepay", "income", "deadlines", "ending", "start", "round_start", "evolution", "cult_start", "cult_end", "powers_start", "powers_end", "relic_start", "prayer_freeze", "prayer_deadlines", "anchors_start", "events_collect", "events_deadlines", "resistance_start", "candidate_generation"]
const REQUIRED: Array[String] = ["events", "prepay", "income", "deadlines", "ending"]
const EFFECTS: Array[String] = ["world_command", "fact", "resource", "wounds", "schedule", "check", "end", "economy", "membership", "cults", "powers", "relics", "prayers", "events", "endings", "progression_routes"]
const PHASES: Array[String] = ["between", "events", "actions", "evolution", "settlement", "ending", "ended"]
var world: RefCounted
var context: Dictionary = {}
var last_error: String = ""
var _participants: Dictionary = {}
var _owners: Dictionary = {}
var _attached: bool = false
var _in_transaction: bool = false
var _checks: Array = []
var _transaction: RefCounted = null
var _in_participant: bool = false
var route_action: String = ""
var commit_sequence: int = 0
var last_transaction_metrics: Dictionary = {}
var last_save_metrics: Dictionary = {}
var _archive: RefCounted = null
var _trusted_world: Dictionary = {}
var _trusted_context: Dictionary = {}

func _init(rule_world: RefCounted) -> void:
	world = rule_world
	if world.state.is_empty() or world.state.get("turn") != 0 or world.state.get("phase") != "between" or not world.validate_state(world.state).is_empty():
		last_error = "Turn requires a valid world between turns"
		return
	_attached = world.claim_turn_driver(self)
	context = {"turn": world.state.turn, "phase": "between", "receipts": {}, "events": [], "plans": {}, "locked_plans": {}, "queued": [], "completed_jobs": {}, "participant_state": {}, "journal": [], "whispers_budget": world.state.whispers, "responses": 0, "power_used": false, "relic_used": false, "outcome": ""}

	if world.state.has("simulation"): context["background_ids"] = []
	context["knowledge_version"] = PlayerKnowledge.VERSION
	context["player_knowledge"] = PlayerKnowledge.empty_ledger()

func register_participant(id: String, version: String, slots: Array, allowed_effects: Array, handler: Callable, plan_validator: Callable = Callable()) -> bool:
	if not _attached or _in_transaction or _in_participant or int(context.turn) != 0 or not (Store.size(context.receipts) == 0) or id.is_empty() or version.is_empty() or not handler.is_valid() or _participants.has(id) or slots.is_empty():
		return false
	for slot: Variant in slots:
		if not slot is String or not slot in SLOTS or (_owners.has(slot) and not (slot == "actions" and _managed_actions(id, handler.get_object()) and _managed_actions(_owners[slot], _participants[_owners[slot]].instance))):
			return false
	for effect: Variant in allowed_effects:
		if not effect is String or not effect in EFFECTS:
			return false
	# Callable alone does not retain a RefCounted target. Own its lifetime, while
	# World holds only a weak reference back to this coordinator.
	_participants[id] = {"version": version, "slots": slots.duplicate(), "effects": allowed_effects.duplicate(), "handler": handler, "instance": handler.get_object(), "plan_validator": plan_validator}
	if context.is_read_only():
		context = context.duplicate(true)
	context.participant_state[id] = {}
	for slot: String in slots:
		if slot != "actions" or not _owners.has(slot): _owners[slot] = id
	return true

func _managed_actions(id: String, instance: Object) -> bool:
	var scripts: Dictionary = {"progression_routes": "res://src/game/progression_routes.gd", "cults": "res://src/game/cults.gd", "powers": "res://src/game/powers.gd", "relics": "res://src/game/relics.gd", "prayers": "res://src/game/prayers.gd", "events": "res://src/game/events.gd"}
	return scripts.has(id) and instance != null and instance.get_script() != null and instance.get_script().resource_path == scripts[id]

func capabilities() -> Dictionary:
	var manifest: Dictionary = {}
	for id: String in _participants:
		var entry: Dictionary = _participants[id]
		manifest[id] = {"version": entry.version, "slots": entry.slots.duplicate(), "effects": entry.effects.duplicate(), "plan_validation": entry.plan_validator.is_valid()}
	return manifest

func _bootstrap_preview(source: String) -> Dictionary:
	var card: Dictionary = {}
	for candidate: Dictionary in world.state.simulation.candidates.values():
		if candidate.get("source") == source: card = candidate; break
	if card.is_empty() or card.get("content_id") != "PRAYER_08" or card.get("addressing") != "undirected" or card.get("visible_turn") != 1 or str(card.get("admission_token", "")).is_empty(): return {"ok": false, "error": "Bootstrap did not produce an admitted first-turn undirected devotion"}
	var prayers: RefCounted = _participants.prayers.instance
	var descriptor: Dictionary = prayers.validate_situation(world, source)
	if not descriptor.get("ok", false): return descriptor
	# This detached first-action forecast calls the real response predicates. It
	# does not open a turn, pay anything, draw RNG, or add a durable receipt.
	var shadow: Dictionary = world.state.duplicate(false)
	shadow.turn = 1; shadow.phase = "actions"
	shadow.prayer_system = world.state.prayer_system.duplicate(true)
	shadow.prayer_system.offer_turn = 1; shadow.prayer_system.offered = [card.id]
	shadow.prayer_system.requests[card.id] = {"card": card.duplicate(true), "descriptor": descriptor.duplicate(true), "status": "open", "source": card.fact, "crisis": ""}
	var shadow_context: Dictionary = context.duplicate(false)
	shadow_context.turn = 1; shadow_context.phase = "actions"; shadow_context.responses = 0
	var reader: RefCounted = StateView.new(shadow, shadow_context, 0, world.history)
	var prepared: Dictionary = prayers.prepare(reader.participant("prayers", "actions"), card.id, "shallow")
	reader.close()
	if not prepared.get("ok", false): return prepared
	var admitted: Dictionary = world.attention.preview_needs(shadow, prepared.attention)
	if not admitted.get("ok", false): return admitted
	return {"ok": true, "card": card.id, "person": descriptor.subjects.petitioner, "source": source, "faith": prepared.faith, "whispers": prepared.whispers}

func bootstrap_prayers() -> Dictionary:
	if not _attached or _in_transaction or _in_participant or commit_sequence != 0 or context.turn != 0 or context.phase != "between" or Store.size(context.receipts) != 0 or not world.attention.enabled(world.state): return {"ok": false, "error": "Initial prayer requires the committed initial world"}
	if world.state.simulation.bootstrap:
		var previous: Dictionary = Store.entry(world.state.facts, str(Store.entry(world.state.applied_authorizations, "prayer/bootstrap", "")), {})
		return {"ok": true, "source": previous.changes.source, "card": previous.changes.candidate, "person": previous.actor} if previous.get("kind") == "prayer_bootstrap" else {"ok": false, "error": "Initial prayer lost its original bootstrap"}
	for id: String in ["prayers", "events", "powers"]:
		if not _participants.has(id) or not _managed_actions(id, _participants[id].instance): return {"ok": false, "error": "Initial prayer needs installed formal " + id}
	_transaction = Transaction.new(world, context, 0)
	if not _transaction.activate():
		var error: String = _transaction.error; _transaction = null
		return {"ok": false, "error": error}
	context = _transaction.context; _in_transaction = true
	var generated: Dictionary = PrayerProducers.bootstrap(world, self)
	var checked: Dictionary = _bootstrap_preview(str(generated.get("source", ""))) if generated.get("ok", false) else generated
	if checked.get("ok", false):
		world.stage_collections(["simulation", "applied_authorizations"])
		world.state.simulation.bootstrap = true
		var source: String = world._record("prayer_bootstrap", checked.get("domain", world.state.simulation.candidates[checked.card].domain), checked.person, [checked.person], [checked.source, world.state.simulation.candidates[checked.card].fact], {"candidate": checked.card, "source": checked.source, "petitioner": checked.person, "faith": checked.faith, "whispers": checked.whispers})
		Store.put(world.state.applied_authorizations, "prayer/bootstrap", source)
		world.attention.sync(world)
		_refresh_player_knowledge({}, 1, true)
		var issues: Array[String] = _transaction.validate_world()
		if issues.is_empty(): issues = _validate_context(context, world.state)
		if not issues.is_empty(): checked = {"ok": false, "error": "; ".join(issues)}
	if checked.get("ok", false):
		_transaction.publish(); _trusted_world = world.state; _trusted_context = context
	else:
		last_error = str(checked.get("error", "Initial undirected devotion unavailable"))
		_transaction.rollback(); context = _transaction.base_context
	last_transaction_metrics = _transaction.metrics.duplicate(true)
	_transaction = null; _in_transaction = false
	return checked

func submit(request: Dictionary) -> Dictionary:
	last_error = ""
	if not _attached or _in_transaction or _in_participant:
		return _reject("Session unavailable or reentrant request")
	if not _plain(request) or not request.get("id") is String or str(request.id).is_empty():
		return _reject("Request needs a nonempty durable ID and plain data")
	if not _audit_adoption():
		return _reject("Mutable session baseline failed full audit")
	var fingerprint: String = World.canonical(request).sha256_text()
	if Store.has(context.receipts, request.id):
		var prior: Dictionary = Store.entry(context.receipts, request.id)
		if prior.fingerprint != fingerprint:
			return _reject("Request ID reused with different content")
		return prior.response.duplicate(true)
	if not request.get("turn") is int or request.turn != context.turn or request.get("phase") != context.phase or not request.get("op") is String:
		return _reject("Wrong turn, phase or operation")
	var allowed_keys: Dictionary = {"rest": [], "abandon": [], "advance": [], "finish_events": [], "resolve_event": ["event", "action", "payload"], "act": ["participant", "action", "payload"], "set_plan": ["participant", "payload"], "end_actions": [], "attention": ["command"]}
	if not allowed_keys.has(request.op):
		return _reject("Unknown operation")
	for key: String in request:
		if not key in ["id", "op", "turn", "phase"] and not key in allowed_keys[request.op]:
			return _reject("Unknown request field")
	if context.phase == "ended":
		return _reject("Ended sessions are read-only")
	for slot: String in REQUIRED:
		if not _required_available(slot):
			return _reject("Missing required participant: " + slot)
	_transaction = Transaction.new(world, context, commit_sequence)
	if not _transaction.activate():
		var reason: String = _transaction.error
		_transaction = null
		return _reject(reason)
	context = _transaction.context
	_in_transaction = true
	_checks = []
	var knowledge_roots: Dictionary = PlayerKnowledge.command_roots(world.state, context, context.player_knowledge, world.catalog, world.history, request) if world.state.has("prayer_system") else {}
	var service_before: Array = Opportunities.before_action(self, request)
	var valid: bool = _dispatch(request)
	var response: Dictionary = {}
	if valid:
		if world.state.has("cult_system") and world.state.get("ending_system", {}).get("terminal", "").is_empty():
			Cults.reconcile(world)
			if not Cults.Spread.refresh(world, self): valid = _fail("Secret recruitment refresh rejected")
		if world.attention.enabled(world.state) and world.state.get("ending_system", {}).get("terminal", "").is_empty():
			world.stage_collections(["attention", "simulation"])
			world.attention.sync(world)
		if world.state.has("anchor_system") and not Anchors.refresh_basis(world, self): valid = _fail("Actual material basis refresh rejected")
		world._refresh_anchors()
		if _participants.has("player_sources") and world.state.get("ending_system", {}).get("terminal", "").is_empty():
			valid = _participants.player_sources.instance.refresh(world, self, int(_transaction.base_state.next_fact))
		if valid:
			_refresh_player_knowledge(request, int(_transaction.base_state.next_fact), false, knowledge_roots)
			valid = Opportunities.observe(self, context.phase == "actions" and _transaction.base_context.phase != "actions", service_before, request)
			if valid: _refresh_player_knowledge({}, int(world.state.next_fact))
		response = {"ok": true, "phase": context.phase, "turn": context.turn, "result": {"checks": _checks.duplicate(true), "outcome": context.outcome}}
		_transaction.touch_context(["receipts"])
		_transaction.new_receipts.append(request.id)
		Store.put(context.receipts, request.id, {"fingerprint": fingerprint, "request": request.duplicate(true), "response": response.duplicate(true), "sequence": commit_sequence + 1, "fact_before": int(_transaction.base_state.next_fact), "fact_after": int(world.state.next_fact)})
		var world_issues: Array[String] = _transaction.validate_world()
		var context_issues: Array[String] = []
		if world_issues.is_empty(): context_issues = _validate_context(context, world.state, _transaction.base_context)
		valid = valid and world_issues.is_empty() and context_issues.is_empty()
		if not valid:
			last_error = "Transaction violated world or turn invariants: " + "; ".join(world_issues + context_issues)
	if not valid:
		var reason: String = last_error if not last_error.is_empty() else "Participant or transaction rejected"
		_transaction.rollback()
		context = _transaction.base_context
		last_transaction_metrics = _transaction.metrics.duplicate(true)
		_transaction = null
		_in_transaction = false
		return _reject(reason)
	_transaction.publish()
	_trusted_world = world.state
	_trusted_context = context
	commit_sequence += 1
	last_transaction_metrics = _transaction.metrics.duplicate(true)
	_transaction = null
	_in_transaction = false
	return response

func _required_available(slot: String) -> bool:
	if _owners.has(slot): return true
	return slot == "deadlines" and _owners.get("prayer_deadlines") == "prayers" and _owners.get("events_deadlines") == "events" and _participants.get("prayers", {}).get("instance") is Prayers and _participants.get("events", {}).get("instance") is Events

func _refresh_player_knowledge(request: Dictionary, first_fact: int, initial: bool = false, roots: Dictionary = {}) -> void:
	if not world.state.has("prayer_system") or not world.state.has("event_system") or not world.state.has("attention"): return
	var ledger: Dictionary = context.player_knowledge
	if initial:
		for domain: String in world.state.simulation.focused:
			ledger = PlayerKnowledge.learn(world.state, context, ledger, world.catalog, world.history, world.state.domains[domain].origin)
	if request.get("op") == "attention" and request.get("command", {}).get("kind") == "focus":
		ledger = PlayerKnowledge.learn(world.state, context, ledger, world.catalog, world.history, world.state.domains[request.command.domain].origin)
	var proofs: Array = _participants.player_sources.instance.available_state(world.state) if _participants.has("player_sources") else []
	context.player_knowledge = PlayerKnowledge.reduce(world.state, context, ledger, world.catalog, world.history, proofs, {"own_action": request.get("op", "") in ["act", "resolve_event", "finish_events", "abandon", "attention", "rest"], "first_fact": first_fact, "roots": roots})

func preview_rest() -> Dictionary:
	if _in_transaction or _in_participant or not _attached or not _participants.has("economy") or not _participants.economy.instance is Economy: return {"ok": false, "error": "Production economy unavailable"}
	return _participants.economy.instance.preview_rest(world.state, context)

func _reject(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "error": reason}

func _fail(reason: String) -> bool:
	last_error = reason
	return false

func _dispatch(request: Dictionary) -> bool:
	match request.op:
		"rest":
			if not _participants.has("economy") or not _participants.economy.instance is Economy or not _participants.economy.instance.rest(world, self, request.id): return _fail("Rest conditions are not satisfied")
			return _dispatch({"op": "end_actions"})
		"abandon":
			return _participants.has("endings") and _participants.endings.instance is Endings and _participants.endings.instance.abandon(world, self)
		"attention":
			return request.get("command") is Dictionary and _attention_command(request.command)
		"advance":
			return _advance()
		"finish_events":
			if context.phase != "events":
				return _fail("Event decisions are closed")
			for event: Dictionary in context.events:
				if not event.resolved and not _resolve_event(event.id, event.default_action, true):
					return false
			_complete(2, "actions")
			return true
		"resolve_event":
			return context.phase == "events" and request.get("event") is String and request.get("action") is String and _event_selection(request.get("payload", {})) and _resolve_event(request.event, request.action, false, request.get("payload", {}))
		"act":
			if context.phase != "actions" or not request.get("participant") is String or not request.get("action") is String or not request.get("payload", {}) is Dictionary:
				return _fail("Illegal action window or payload")
			if request.participant == "progression_routes" and _participants.has("progression_routes") and _participants.progression_routes.instance is Progression and request.action == "ROUTE_GUIDED_DREAM":
				return _participants.has("powers") and _invoke("powers", "actions", {"operation": "act", "action": "POWER_DREAM", "payload": request.get("payload", {})}, true)
			if request.participant == "progression_routes" and _participants.has("progression_routes") and _participants.progression_routes.instance is Progression and request.action == "ROUTE_PACT_PERFORMANCE":
				return _participants.has("prayers") and _invoke("prayers", "actions", {"operation": "act", "action": "respond", "payload": {"request": request.payload.get("target", ""), "variant": "deep"}}, true)
			if request.participant == "powers" and _participants.has("powers") and _participants.powers.instance is Powers:
				if request.action == "POWER_APPOINT":
					return _participants.has("cults") and _invoke("cults", "actions", {"operation": "act", "action": "appoint", "payload": request.get("payload", {})}, true)
				if request.action.begins_with("relic_"):
					return _participants.has("relics") and _invoke("relics", "actions", {"operation": "act", "action": request.action, "payload": request.get("payload", {})}, true)
			return _invoke(request.participant, "actions", {"operation": "act", "action": request.action, "payload": request.get("payload", {})}, true)
		"set_plan":
			if context.phase != "actions" or not request.get("participant") is String or not request.get("payload") is Dictionary or not _participants.has(request.participant):
				return _fail("Plans may only be edited in the action phase")
			var preview: Dictionary = preview_plan(request.participant, request.payload)
			if not preview.ok:
				return _fail(preview.error)
			context.plans[request.participant] = request.payload.duplicate(true)
			return true
		"end_actions":
			if context.phase != "actions":
				return _fail("Not in action phase")
			if not _lock_attention_plans(): return false
			context.locked_plans = context.plans.duplicate(true)
			_complete(3, "evolution")
			return true
	return _fail("Unknown operation")

func _advance() -> bool:
	match context.phase:
		"between":
			if context.turn == 0 and world.attention.enabled(world.state) and world.state.has("event_system") and not world.state.simulation.bootstrap: return _fail("Formal new campaign requires its initial undirected prayer")
			if not world.prepare_turn(self):
				return _fail("World clock refused turn start")
			context.turn = world.state.turn
			context.events = []
			context.responses = 0
			context.power_used = false
			context.relic_used = false
			context.locked_plans = {}
			if _owners.has("round_start") and not _invoke(_owners.round_start, "round_start", {"operation": "capture"}):
				return false
			if not _run_due("start") or not world.finish_turn_start(self) or not world.settle_background(self, true):
				return false
			if world.attention.enabled(world.state):
				world.attention.round_start(world)
				if not world.state.has("cult_system"): world._succeed_cults()
			if _owners.has("relic_start") and not _invoke(_owners.relic_start, "relic_start", {"operation": "start"}): return false
			if _owners.has("powers_start") and not _invoke(_owners.powers_start, "powers_start", {"operation": "start"}): return false
			if _owners.has("cult_start") and not _invoke(_owners.cult_start, "cult_start", {"operation": "start"}): return false
			if _owners.has("anchors_start") and not _invoke(_owners.anchors_start, "anchors_start", {"operation": "start"}): return false
			if _owners.has("resistance_start") and not _invoke(_owners.resistance_start, "resistance_start", {"operation": "start"}): return false
			if world.state.has("anchor_system"):
				# All source, role and medium changes at the start precede this lock.
				world._refresh_anchors()
				world.state.whispers = mini(world.catalog.integer("whisper_cap"), world.catalog.integer("whisper_base") + int(floor(float(world.state.awakening) / world.catalog.number("whisper_growth_step"))))
			if world.state.has("simulation"):
				context.background_ids = world.background_candidates(self).map(func(card: Dictionary) -> String: return card.id)
			context.whispers_budget = world.state.whispers
			if _owners.has("prayer_freeze") and not _invoke(_owners.prayer_freeze, "prayer_freeze", {"operation": "freeze"}): return false
			_complete(1, "events")
			return _invoke(_owners.events, "events", {"operation": "gather"})
		"evolution":
			if not _invoke(_owners.prepay, "prepay", {"operation": "settle"}):
				return false
			if world.state.phase != "actions":
				return _fail("World has already evolved")
			var batch: Dictionary = {}
			if _owners.has("evolution"):
				var prepared: Array = []
				if not _invoke(_owners.evolution, "evolution", {"operation": "prepare"}, false, false, prepared, true):
					return false
				for effect: Dictionary in prepared[0].effects:
					if effect.type != "economy" or not batch.is_empty():
						return _fail("Unsupported shared evolution declaration")
					batch = effect.batch
			world.evolve(self, batch)
			if world.state.phase != "between":
				return _fail("World evolution did not complete")
			if not _events_slot("events_collect", "collect"): return false
			_complete(4, "settlement")
			return true
		"settlement":
			if not _invoke(_owners.income, "income", {"operation": "settle"}) or not _run_due("deadlines") or not _prayer_deadlines() or not world.settle_background(self) or (_owners.has("deadlines") and not _invoke(_owners.deadlines, "deadlines", {"operation": "settle"})):
				return false
			if not _events_slot("events_deadlines", "settle") or not _events_slot("events_collect", "collect"): return false
			if world.state.has("anchor_system") and not Anchors.expire(world, self): return _fail("Institution relic opportunity expiry rejected")
			_complete(5, "ending")
			return true
		"ending":
			if _owners.has("cult_end") and not _invoke(_owners.cult_end, "cult_end", {"operation": "end"}): return false
			if _owners.has("powers_end") and not _invoke(_owners.powers_end, "powers_end", {"operation": "end"}): return false
			if not _invoke(_owners.ending, "ending", {"operation": "settle"}):
				return false
			_complete(6, "ended" if not str(context.outcome).is_empty() else "between")
			return true
	return _fail("This phase requires explicit player input")

func _complete(number: int, next_phase: String) -> void:
	_transaction.touch_context(["journal"])
	Store.append_journal(context, {"turn": context.turn, "phase": number})
	context.phase = next_phase

func _audit_adoption() -> bool:
	if not context.get("receipts") is Dictionary or commit_sequence != Store.size(context.receipts):
		return false
	# Mutable roots mean first adoption or privileged fixture replacement. Never
	# grant the incremental validator an unverified baseline.
	if not is_same(world.state, _trusted_world) or not is_same(context, _trusted_context):
		if not world.validate_state(world.state).is_empty() or not _validate_context(context, world.state).is_empty():
			return false
		Transaction.freeze(world.state, true)
		if not world.ensure_history(): return false
		if world.history.data.is_read_only(): world.history = world.history.fork()
		world.history.rebuild_jobs(context)
		Transaction.freeze(world.history.data)
		world.state = Store.pack_state(world.state)
		world.history.source_root = world.state
		context = Store.pack_context(context)
		Transaction.freeze(world.state, true)
		Transaction.freeze(context, true)
		Transaction.freeze(world.stats, true)
		_trusted_world = world.state
		_trusted_context = context
	return true

func fixed_background_candidates() -> Array:
	if _in_participant or _in_transaction or not _attached: return []
	return world.background_candidates(self).filter(func(card: Dictionary) -> bool: return card.id in context.get("background_ids", []))

func _read_view(id: String, slot: String) -> Dictionary:
	var reader: RefCounted = StateView.new(world.state, context, commit_sequence, world.history)
	var view: Dictionary = reader.participant(id, slot)
	view["catalog"] = world.catalog
	view["attention"] = world.attention
	if _participants[id].instance is Cults: view["cult_jobs"] = context.queued.filter(func(job: Dictionary) -> bool: return job.participant == id).duplicate(true)
	if _transaction != null:
		_transaction.metrics["view_objects"] = int(_transaction.metrics.get("view_objects", 0)) + int(reader.metrics.objects)
		_transaction.metrics["view_facts"] = int(_transaction.metrics.get("view_facts", 0)) + int(reader.metrics.facts)
	return view

func _call_guarded(callback: Callable, view: Dictionary, input: Dictionary) -> Dictionary:
	# A participant receives only detached projections. Capturing the coordinator
	# does not expose its candidate either: direct reads during callbacks see a
	# separate guarded projection. Previously published aliases are immutable.
	var saved_attention: RefCounted = world.attention
	var saved_attention_version: String = saved_attention.version
	var saved_attention_policies: Dictionary = saved_attention.policies
	var saved_abstract: RefCounted = world.abstract_sim
	var saved_abstract_version: String = saved_abstract.version
	var saved_abstract_templates: Dictionary = saved_abstract.templates
	var saved_abstract_parameters: Dictionary = saved_abstract.parameters
	var saved_abstract_responsibilities: Dictionary = saved_abstract.responsibilities
	var saved_world: RefCounted = world
	var saved_sequence: int = commit_sequence
	var saved_history: RefCounted = world.history
	var saved_history_data: Dictionary = saved_history.data
	var saved_history_rules: Dictionary = saved_history.rules
	var saved_history_version: int = saved_history.version
	var saved_history_source: Dictionary = saved_history.source_root
	var saved_history_policy: String = saved_history.policy
	var saved_history_limit: int = saved_history.page_limit
	var saved_history_incarnation: String = saved_history.incarnation
	var saved_state: Dictionary = world.state
	var saved_context: Dictionary = context
	var saved_randoms: Dictionary = world.randoms
	var saved_stats: Dictionary = world.stats
	var saved_rng_objects: Dictionary = saved_randoms.duplicate(false)
	var saved_transaction: RefCounted = world.transaction
	var guard_state: Dictionary = view.world.duplicate(true)
	var guard_context: Dictionary = view.turn.duplicate(true)
	var before_state: Dictionary = guard_state.duplicate(true)
	var before_context: Dictionary = guard_context.duplicate(true)
	var before_stats: Dictionary = saved_stats.duplicate(true)
	var before_randoms: Dictionary = Transaction.random_positions(saved_randoms)
	world.state = guard_state
	var guard_history: RefCounted = saved_history.fork()
	world.history = guard_history
	world.stats = before_stats.duplicate(true)
	world.randoms = Transaction.clone_randoms(saved_randoms)
	world.transaction = null
	world.participant_read = true
	context = guard_context
	_in_participant = true
	var reader: RefCounted = view.reader
	var returned: Variant = callback.call(view, input.duplicate(true))
	reader.close()
	var clean: bool = is_same(world.attention, saved_attention) and saved_attention.version == saved_attention_version and is_same(saved_attention.policies, saved_attention_policies) and is_same(world.abstract_sim, saved_abstract) and saved_abstract.version == saved_abstract_version and is_same(saved_abstract.templates, saved_abstract_templates) and is_same(saved_abstract.parameters, saved_abstract_parameters) and is_same(saved_abstract.responsibilities, saved_abstract_responsibilities) and is_same(world, saved_world) and is_same(world.history, guard_history) and is_same(saved_history.rules, saved_history_rules) and is_same(guard_history.rules, saved_history_rules) and is_same(saved_history.source_root, saved_history_source) and is_same(guard_history.source_root, saved_history_source) and guard_history.policy == saved_history_policy and guard_history.page_limit == saved_history_limit and guard_history.incarnation == saved_history_incarnation and is_same(saved_history.data, saved_history_data) and saved_history.version == saved_history_version and saved_history.policy == saved_history_policy and saved_history.page_limit == saved_history_limit and saved_history.incarnation == saved_history_incarnation and HistoryIndex.same_roots(world.history.data, saved_history_data) and world.history.version == saved_history_version and commit_sequence == saved_sequence and is_same(world, saved_world) and world.state == before_state and context == before_context and world.stats == before_stats and Transaction.random_positions(world.randoms) == before_randoms and Transaction.random_positions(saved_randoms) == before_randoms
	for name: String in saved_rng_objects:
		saved_rng_objects[name].seed = int(before_randoms[name][0])
		saved_rng_objects[name].state = int(before_randoms[name][1])
	commit_sequence = saved_sequence
	world = saved_world
	world.attention = saved_attention
	saved_attention.version = saved_attention_version
	saved_attention.policies = saved_attention_policies
	world.abstract_sim = saved_abstract
	saved_abstract.version = saved_abstract_version
	saved_abstract.templates = saved_abstract_templates
	saved_abstract.parameters = saved_abstract_parameters
	saved_abstract.responsibilities = saved_abstract_responsibilities
	world.state = saved_state
	world.history = saved_history
	world.history.data = saved_history_data
	world.history.rules = saved_history_rules
	world.history.version = saved_history_version
	world.history.source_root = saved_history_source
	world.history.policy = saved_history_policy
	world.history.page_limit = saved_history_limit
	world.history.incarnation = saved_history_incarnation
	world.stats = saved_stats
	world.randoms = saved_rng_objects
	world.transaction = saved_transaction
	world.participant_read = false
	context = saved_context
	_in_participant = false
	return {"ok": clean, "value": returned}

func preview_plan(id: String, payload: Dictionary) -> Dictionary:
	if not _attached or _in_participant or not _participants.has(id) or not _plain(payload):
		return {"ok": false, "error": "Unknown participant or invalid plan"}
	var validator: Callable = _participants[id].plan_validator
	if not validator.is_valid():
		return {"ok": true, "preview": {}}
	if not _in_transaction and not _audit_adoption():
		return {"ok": false, "error": "Mutable session baseline failed full audit"}
	var called: Dictionary = _call_guarded(validator, _read_view(id, "preview"), payload)
	if not called.ok:
		return {"ok": false, "error": "Preview attempted a mutation"}
	var result: Variant = called.value
	if not result is Dictionary or not result.get("ok") is bool or not _plain(result):
		return {"ok": false, "error": "Invalid preview response"}
	if (result.ok and not result.get("preview") is Dictionary) or (not result.ok and not result.get("error") is String):
		return {"ok": false, "error": "Incomplete preview response"}
	return result.duplicate(true)

func _invoke(id: String, slot: String, input: Dictionary, action: bool = false, default_choice: bool = false, prepared: Array = [], defer_effects: bool = false) -> bool:
	if not _participants.has(id) or not slot in _participants[id].slots:
		return _fail("Participant does not own this capability")
	var participant: Dictionary = _participants[id]
	if not participant.handler.is_valid():
		return _fail("Participant handler is no longer available")
	var view: Dictionary = _read_view(id, slot)
	var call_input: Dictionary = input.duplicate(true)
	call_input.slot = slot
	var called: Dictionary = _call_guarded(participant.handler, view, call_input)
	if not called.ok:
		return _fail("Participant mutated session instead of returning declarations")
	var returned: Variant = called.value
	if not returned is Dictionary or not _plain(returned):
		return _fail("Participant must return explicit plain data")
	var result: Dictionary = returned
	if not result.get("ok") is bool or not result.ok or not result.get("empty") is bool or not result.get("effects") is Array or not result.get("state") is Dictionary:
		return _fail("Incomplete or rejected participant result")
	if result.empty and not result.effects.is_empty():
		return _fail("Empty result cannot contain effects")
	if action and not result.get("meta") is Dictionary:
		return _fail("Missing action metadata")
	if action and slot == "events" and result.meta.get("responds", false):
		return _fail("Events cannot consume the prayer response")
	for effect: Variant in result.effects:
		if not _valid_effect(id, slot, effect) or (default_choice and _charges_resources(effect)):
			return _fail("Invalid effect declaration")
	var attention_token: String = ""
	var attention_admission: String = ""
	var attention_focus: Array = []
	if world.attention.enabled(world.state):
		var managed_departure: bool = participant.instance is Cults and input.get("operation") == "act" and input.get("action") == "leave"
		var needs_admission: bool = (action and not managed_departure) or (input.get("operation") == "due" and result.has("attention"))
		for effect: Dictionary in result.effects:
			needs_admission = needs_admission or (effect.get("type") == "membership" and effect.get("operation") == "enroll") or (effect.get("type") == "world_command" and effect.command.get("kind") == "nominate")
		if input.get("operation") == "due" and defer_effects:
			for target: String in _due_profile(result.effects).targets:
				if Store.entry(world.state.npcs, target).status == "dead": needs_admission = false
		if needs_admission:
			var descriptor: Variant = result.get("meta", {}).get("attention") if action else result.get("attention")
			if not descriptor is Dictionary: return _fail("Hybrid intervention needs registered admission metadata")
			if descriptor.has("persistent") and not descriptor.persistent is bool: return _fail("Persistent admission flag must be boolean")
			descriptor = descriptor.duplicate(true)
			descriptor.erase("_reservation")
			if input.get("operation") == "due": descriptor["_reservation"] = input.get("attention_token", "")
			if action: descriptor.source = result.meta.get("source", "")
			var needs: Dictionary = world.attention.preview_needs(world.state, descriptor, result.effects, str(result.get("meta", {}).get("actor", "")))
			if not needs.ok: return _fail(needs.error)
			if default_choice and (not needs.focus.is_empty() or not needs.members.is_empty() or not needs.identities.is_empty()): return _fail("Default consequence cannot acquire new capacity")
			if input.get("operation") != "due" and _has_scheduled_effect(result.effects) and (not needs.focus.is_empty() or not needs.people.is_empty() or not needs.members.is_empty() or not needs.identities.is_empty()) and not descriptor.get("persistent", false): return _fail("Future capacity promises need persistent reservations")
			var existing: String = str(input.get("attention_token", ""))
			var reserved: Dictionary
			if input.get("operation") == "due":
				reserved = world.attention.preview_reserved(world.state, existing, needs, id)
			else:
				reserved = world.attention.reserve(world, needs, bool(descriptor.get("persistent", false)), {"kind": "action", "participant": id, "slot": slot, "input": input.duplicate(true), "descriptor": descriptor.duplicate(true)})
			if not reserved.ok: return _fail(reserved.error)
			attention_token = reserved.token
			attention_admission = str(reserved.get("admission", ""))
			attention_focus = needs.focus.duplicate()
			if input.get("operation") != "due": world.state.attention.reservations[attention_token]["owner"] = id
	var action_payments: Array = []
	if action and not _apply_action_meta(result.get("meta", {}), default_choice, attention_admission, action_payments):
		return false
	var managed_gather: bool = slot == "events" and input.operation == "gather" and participant.instance is Events
	if managed_gather:
		if result.has("events") and result.events != []: return _fail("Managed events freeze only committed candidates")
	elif slot == "events" and input.operation == "gather":
		if not result.get("events") is Array or not _freeze_events(id, result.events):
			return _fail("Invalid event selection")
	elif result.has("events"):
		return _fail("Events can only be selected at the frozen boundary")
	if defer_effects:
		prepared.append({"participant": id, "slot": slot, "effects": result.effects.duplicate(true), "attention_focus": attention_focus})
		context.participant_state[id] = result.state.duplicate(true)
		return true
	for effect: Variant in result.effects:
		if not effect is Dictionary or not _effect(id, slot, effect, 0, action_payments if id == "progression_routes" or (id == "cults" and input.get("action") == "transfer_material") else [], attention_token):
			return false
	if managed_gather and not _freeze_events(id, Events.offered(world)): return _fail("Committed event selection is invalid")
	if not attention_token.is_empty(): world.attention.finish(world, attention_token)
	context.participant_state[id] = result.state.duplicate(true)
	world._refresh_anchors()
	return true

func _has_scheduled_effect(effects: Array) -> bool:
	for effect: Dictionary in effects:
		if effect.type == "schedule": return true
		if effect.type == "check":
			for branch: Array in effect.branches.values():
				if _has_scheduled_effect(branch): return true
	return false

func _apply_action_meta(meta: Variant, default_choice: bool, admission: String = "", payment_output: Array = []) -> bool:
	var valid: Dictionary = Admission.validate(world.state, context, meta, world.catalog, default_choice)
	if not valid.ok: return _fail(valid.error)
	if not str(meta.actor).is_empty() and not world.mark_player_task(meta.actor, self): return _fail("Person cannot execute another task")
	var payment_domain: String = valid.payment_domain
	world.state.faith -= int(meta.faith_cost)
	world.state.whispers -= int(meta.whispers_cost)
	context.responses += 1 if meta.responds else 0
	context.power_used = context.power_used or meta.used_power
	context.relic_used = context.relic_used or meta.used_relic
	var data: Dictionary = {"faith_cost": meta.faith_cost, "whispers_cost": meta.whispers_cost, "outcome": meta.outcome}
	if meta.outcome == "transfer_material":
		data["material"] = meta.material.duplicate(true)
	if not admission.is_empty(): data["admission"] = admission
	var payment: String = world._record("turn_action", payment_domain, meta.actor, [], [meta.source] + ([] if admission.is_empty() else [admission]), data)
	payment_output.append(payment)
	if world.state.has("cult_system") and not Cults.record_payment(world, payment_domain, int(meta.faith_cost), payment): return _fail("Invalid actual cult payment")
	return true

func _freeze_events(id: String, events: Array) -> bool:
	if events.size() > world.catalog.integer("major_event_limit"):
		return false
	var seen: Dictionary = {}
	for item: Variant in events:
		if not item is Dictionary or not item.get("id") is String or str(item.id).is_empty() or seen.has(item.id) or not item.get("default_action") is String or str(item.default_action).is_empty() or not item.get("payload") is Dictionary or not item.get("source") is String or not Store.has(world.state.facts, item.source):
			return false
		seen[item.id] = true
		context.events.append({"id": item.id, "participant": id, "default_action": item.default_action, "payload": item.payload.duplicate(true), "source": item.source, "resolved": false})
	return true

func _resolve_event(id: String, action_name: String, default_choice: bool, selection: Dictionary = {}) -> bool:
	for event: Dictionary in context.events:
		if event.id == id:
			if event.resolved:
				return _fail("Event already resolved")
			if not selection.is_empty() and not _participants[event.participant].instance is Events: return _fail("Only managed events accept a fixed qualification selection")
			if not _invoke(event.participant, "events", {"operation": "resolve_event", "action": action_name, "payload": event.payload, "selection": selection.duplicate(true), "default_choice": default_choice, "event": id, "source": event.source}, true, default_choice or action_name == event.default_action):
				return false
			event.resolved = true
			return true
	return _fail("Unknown frozen event")

func _events_slot(slot: String, operation: String) -> bool:
	return not _owners.has(slot) or _invoke(_owners[slot], slot, {"operation": operation})

func _prayer_deadlines() -> bool:
	return not _owners.has("prayer_deadlines") or _invoke(_owners.prayer_deadlines, "prayer_deadlines", {"operation": "settle"})

func _valid_effect(id: String, slot: String, value: Variant, depth: int = 0) -> bool:
	if not value is Dictionary or not value.get("type") is String or not value.type in _participants[id].effects:
		return false
	var effect: Dictionary = value
	if effect.type == "progression_routes": return _participants[id].instance is Progression and _participants[id].instance.validate_effect(world.state, slot, effect)
	if effect.type == "endings": return _participants[id].instance is Endings and _participants[id].instance.validate_effect(world.state, slot, effect)
	if effect.type == "events": return _participants[id].instance is Events and _participants[id].instance.validate_effect(world.state, slot, effect, world.history)
	if effect.type == "prayers": return _participants[id].instance is Prayers and _participants[id].instance.validate_effect(world.state, slot, effect)
	if effect.type == "powers": return _participants[id].instance is Powers and _participants[id].instance.validate_effect(world.state, slot, effect)
	if effect.type == "relics": return _participants[id].instance is Relics and _participants[id].instance.validate_effect(world.state, slot, effect, world.history)
	if effect.type == "cults":
		return _participants[id].instance is Cults and _participants[id].instance.validate_effect(world.state, slot, effect, world.history)
	if effect.type == "economy":
		return _participants[id].instance is Economy and _participants[id].instance.validate_effect(world.state, slot, effect)
	if not effect.get("parents", []) is Array:
		return false
	for parent: Variant in effect.get("parents", []):
		if not parent is String or not Store.has(world.state.facts, parent):
			return false
	if effect.type == "schedule":
		var job: Variant = effect.get("job")
		return job is Dictionary and not job.has("attention_token") and job.get("id") is String and not str(job.id).is_empty() and _valid_job_time(job) and job.phase in _participants[id].slots and job.get("action") is String and not str(job.action).is_empty() and job.get("payload") is Dictionary and Store.has(world.state.facts, job.get("source", ""))
	if not effect.get("source") is String or not Store.has(world.state.facts, effect.source) or not effect.get("parents", []) is Array:
		return false
	for parent: Variant in effect.get("parents", []):
		if not parent is String or not Store.has(world.state.facts, parent):
			return false
	match effect.type:
		"membership":
			return (world.attention.enabled(world.state) or world.state.has("cult_system")) and effect.get("operation") in ["enroll", "leave"] and effect.get("npc") is String and Store.has(world.state.npcs, effect.npc)
		"world_command":
			var command: Variant = effect.get("command")
			if not command is Dictionary or not command.get("kind", "") in ["status", "migrate", "nominate", "population", "establish_cult", "economy_qualification", "background_successor", "share_record"] or not command.get("parents") is Array:
				return false
			for parent: Variant in command.parents:
				if not parent is String or not Store.has(world.state.facts, parent):
					return false
			if command.kind == "share_record": return world.valid_share_record(command)
			if command.kind == "background_successor":
				return id == _owners.get("events", "") and world.state.has("simulation") and context.phase in ["events", "actions"] and command.get("authorization") is String and Store.has(world.state.facts, command.authorization)
			if command.kind == "status":
				return command.get("npc") is String and Store.has(world.state.npcs, command.npc) and command.get("status", "") in World.STATUSES
			if command.kind == "migrate":
				return command.get("npc") is String and Store.has(world.state.npcs, command.npc) and command.get("domain") is String and world.state.domains.has(command.domain)
			if command.kind in ["population", "establish_cult", "economy_qualification"]:
				return world.valid_economy_command(command)
			return command.get("domain") is String and world.state.domains.has(command.domain) and command.get("profile") is String and world.catalog.tables.npc_profiles.has(command.profile) and command.get("group", "") in ["unnamed_nonfollowers", "unnamed_followers"] and command.get("institution", "") is String
		"fact":
			if effect.get("kind") == "background_successor_authorized" and id != _owners.get("events", ""): return false
			for key: String in ["kind", "domain", "actor"]:
				if not effect.get(key) is String:
					return false
			for key: String in ["targets", "observers", "institutions"]:
				if not effect.get(key) is Array or not _strings(effect[key]):
					return false
			if not effect.kind in World.INTEGRATION_FACTS or not world.state.domains.has(effect.domain) or (not effect.actor.is_empty() and not Store.has(world.state.npcs, effect.actor)) or not effect.get("details") is Dictionary:
				return false
			for person: String in effect.observers:
				if not Store.has(world.state.npcs, person):
					return false
			for institution: String in effect.institutions:
				if not world.state.institutions.has(institution):
					return false
			for target: String in effect.targets:
				if not Store.has(world.state.npcs, target) and not Store.has(world.state.relics, target) and not world.state.anchors.has(target) and not world.state.institutions.has(target) and not (effect.kind == "exception_confirmation_authorized" and Store.has(world.state.facts, target) and Store.entry(world.state.facts, target).kind == "exception") and not (effect.kind == "power_qualification" and (world.state.cults.has(target) or Store.has(world.state.facts, target))):
					return false
			return not effect.details.has("witnesses") or (effect.details.witnesses is Array and _strings(effect.details.witnesses))
		"resource":
			if effect.get("field") != "faith" or not effect.get("delta") is int or (slot == "prepay" and int(effect.delta) > 0) or (slot == "income" and int(effect.delta) < 0):
				return false
			if slot == "income" and int(effect.delta) > 0:
				var basis: Variant = effect.get("basis")
				return basis is Dictionary and basis.get("cult") is String and world.state.cults.has(basis.cult) and basis.get("eligible") is int and int(basis.eligible) >= 0 and basis.get("rule") is String and not str(basis.rule).is_empty()
			return true
		"wounds":
			return effect.get("delta") is int
		"end":
			return slot == "ending" and effect.get("outcome", "") in ["extinction", "awakened"]
		"check":
			if depth > 0 or not effect.get("npc") is String or not Store.has(world.state.npcs, effect.npc) or Store.entry(world.state.npcs, effect.npc).status != "active" or not effect.get("attribute") is String or not effect.get("domain") is String or not effect.get("mode") is String or not effect.get("preparation") is int or not effect.get("branches") is Dictionary:
				return false
			if world.check_probability(effect.npc, effect.attribute, effect.domain, effect.mode, effect.preparation) < 0 or effect.branches.size() != 4:
				return false
			for branch: String in ["deep", "success", "failure", "disaster"]:
				if not effect.branches.get(branch) is Array:
					return false
				for nested: Variant in effect.branches[branch]:
					if not _valid_effect(id, slot, nested, depth + 1):
						return false
			return true
	return false

func _charges_resources(effect: Dictionary) -> bool:
	if effect.type == "resource" and int(effect.delta) < 0:
		return true
	if effect.type == "check":
		for branch: Array in effect.branches.values():
			for nested: Dictionary in branch:
				if _charges_resources(nested):
					return true
	return false

func _valid_job_time(job: Dictionary) -> bool:
	if not job.get("due") is int or not job.get("phase", "") in ["start", "deadlines"] or int(job.due) < int(context.turn):
		return false
	if int(job.due) > int(context.turn):
		return true
	# A one-turn request can expire in this turn's stage five. Once stage five
	# begins, new consequences must target a later turn, avoiding recursive drain.
	return job.phase == "deadlines" and (context.phase in ["events", "actions", "evolution"] or world.state.phase == "starting")

func _effect(id: String, slot: String, effect: Dictionary, depth: int = 0, inherited_parents: Array = [], attention_token: String = "") -> bool:
	if not effect.get("type") is String or not effect.type in _participants[id].effects:
		return _fail("Undeclared or unknown effect")
	var kind: String = effect.type
	if kind == "progression_routes": return _participants[id].instance.commit(world, effect, self, attention_token, str(inherited_parents[0]) if not inherited_parents.is_empty() else "")
	if kind == "endings": return _participants[id].instance.commit(world, effect, self)
	if kind == "events": return _participants[id].instance.commit(world, effect, self, attention_token)
	if kind == "powers": return _participants[id].instance.commit(world, effect, self, attention_token)
	if kind == "prayers": return _participants[id].instance.commit(world, effect, self, attention_token)
	if kind == "relics": return _participants[id].instance.commit(world, effect, self, attention_token)
	if kind == "cults":
		return _participants[id].instance.commit(world, effect, self, attention_token, str(inherited_parents[0]) if not inherited_parents.is_empty() else "")
	if kind == "economy":
		return _participants[id].instance.commit(world, effect, self)
	if kind == "schedule":
		var job: Dictionary = effect.get("job").duplicate(true)
		if not attention_token.is_empty() and world.state.attention.reservations.get(attention_token, {}).get("persistent", false):
			job["attention_token"] = attention_token
			world.state.attention.reservations[attention_token]["scheduled"] = true
		return _schedule(id, job, inherited_parents + effect.get("parents", []))
	if not effect.get("source") is String or not Store.has(world.state.facts, effect.source):
		return _fail("Effect has no valid causal source")
	var source: String = effect.source
	var parents: Array = world._unique_sorted([source] + effect.get("parents", []) + inherited_parents)
	match kind:
		"membership":
			world.stage_current()
			if world.state.has("cult_system"): return Cults.membership(world, effect.operation, effect.npc, source, attention_token, str(effect.get("cult", "")))
			return world.attention.enroll(world, effect.npc, source, attention_token, str(effect.get("cult", ""))) if effect.operation == "enroll" else world.attention.leave(world, effect.npc, source)
		"world_command":
			if not effect.get("command") is Dictionary:
				return _fail("Invalid world command")
			var command: Dictionary = effect.command.duplicate(true)
			command.parents = world._unique_sorted(command.get("parents", []) + parents)
			if command.kind == "nominate" and world.attention.enabled(world.state): command["attention_token"] = attention_token
			if not world.submit(command, self):
				return _fail("World effect rejected")
		"fact":
			for key: String in ["kind", "domain", "actor"]:
				if not effect.get(key) is String:
					return _fail("Invalid fact field")
			for key: String in ["targets", "observers", "institutions"]:
				if not effect.get(key) is Array or not _strings(effect[key]):
					return _fail("Invalid fact references")
			if not effect.get("details") is Dictionary or world.introduce_fact(effect.kind, effect.domain, effect.actor, effect.targets, parents, effect.details, effect.observers, effect.institutions, self).is_empty():
				return _fail("Fact rejected")
		"resource":
			if effect.get("field") != "faith" or not effect.get("delta") is int:
				return _fail("Invalid resource declaration")
			var delta: int = effect.delta
			if (slot == "prepay" and delta > 0) or (slot == "income" and delta < 0):
				return _fail("Payment and income declarations crossed their slots")
			if int(world.state.faith) + delta < 0:
				return _fail("Resources cannot be borrowed")
			if slot == "income" and delta > 0:
				var basis: Variant = effect.get("basis")
				if not basis is Dictionary or not basis.get("cult") is String or not world.state.cults.has(basis.cult) or not basis.get("eligible") is int or int(basis.eligible) < 0 or not basis.get("rule") is String or str(basis.rule).is_empty():
					return _fail("Income requires a registered cult and calculation basis")
			var before: int = world.state.faith
			var capacity: int = world.catalog.integer("faith_capacity_base") + int(world.state.peak_awakening) * world.catalog.integer("faith_capacity_per_peak_awakening")
			world.state.faith = mini(before + delta, capacity) if delta > 0 else before + delta
			world._record("turn_resource", "", "", [], parents, {"participant": id, "slot": slot, "requested": delta, "actual": int(world.state.faith) - before, "overflow": maxi(0, before + delta - capacity), "basis": effect.get("basis", {})})
		"wounds":
			if not effect.get("delta") is int:
				return _fail("Invalid wound declaration")
			var before: int = world.state.wounds
			world.state.wounds = maxi(0, before + int(effect.delta))
			world._record("turn_wounds", "", "", [], parents, {"requested": effect.delta, "actual": int(world.state.wounds) - before})
			world._refresh_anchors()
		"check":
			if depth != 0 or not effect.get("npc") is String or not Store.has(world.state.npcs, effect.npc) or Store.entry(world.state.npcs, effect.npc).status != "active" or not effect.get("attribute") is String or not effect.get("domain") is String or not effect.get("mode") is String or not effect.get("preparation") is int or not effect.get("branches") is Dictionary:
				return _fail("Invalid check declaration")
			for branch: String in ["deep", "success", "failure", "disaster"]:
				if not effect.branches.get(branch) is Array:
					return _fail("Check must declare all four outcomes")
			var probability: int = world.check_probability(effect.npc, effect.attribute, effect.domain, effect.mode, effect.preparation)
			if probability < 0:
				return _fail("Check actor or mode invalid")
			var roll: int = world.randoms.checks.randi_range(1, 100)
			var outcome: String = world.check_result(probability, roll)
			var check_fact: String = world._record("turn_check", effect.domain, effect.npc, [effect.npc], parents, {"probability": probability, "roll": roll, "outcome": outcome})
			_checks.append({"probability": probability, "roll": roll, "outcome": outcome})
			for nested: Variant in effect.branches[outcome]:
				if not nested is Dictionary or not _effect(id, slot, nested, depth + 1, [check_fact], attention_token):
					return false
		"end":
			if slot != "ending" or not effect.get("outcome", "") in ["extinction", "awakened"] or not str(context.outcome).is_empty():
				return _fail("Invalid terminal declaration")
			context.outcome = effect.outcome
			world._record("turn_ended", "", "", [], parents, {"outcome": effect.outcome, "participant": id})
		_:
			return _fail("Unsupported effect")
	return true

func _schedule(id: String, value: Variant, parents: Array = []) -> bool:
	if not value is Dictionary:
		return _fail("Invalid scheduled consequence")
	var job: Dictionary = value
	if not job.get("id") is String or str(job.id).is_empty() or not _valid_job_time(job) or not job.get("action") is String or str(job.action).is_empty() or not job.get("payload") is Dictionary or not job.get("source") is String or not Store.has(world.state.facts, job.source) or not job.phase in _participants[id].slots:
		return _fail("Scheduled consequence needs a future turn, owner and cause")
	if Store.has(context.completed_jobs, job.id):
		return _fail("Consequence ID already consumed")
	for existing: Dictionary in context.queued:
		if existing.id == job.id:
			return _fail("Consequence ID already queued")
	var stored: Dictionary = job.duplicate(true)
	stored.participant = id
	stored.source = world._record("turn_scheduled", "", "", [], world._unique_sorted([job.source] + parents), {"id": job.id, "due": job.due, "phase": job.phase, "participant": id})
	context.queued.append(stored)
	world.history.schedule_job(stored)
	return true

func _run_due(phase: String) -> bool:
	# Freeze the eligible IDs; newly scheduled work cannot recursively drain here.
	var due: Array = world.history.due_jobs(phase, int(context.turn))
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var batches: Array = []
	for job: Dictionary in due:
		if not _invoke(job.participant, phase, {"operation": "due", "action": job.action, "payload": job.payload, "source": job.source, "attention_token": job.get("attention_token", "")}, false, false, batches, true):
			return false
		batches.back()["job"] = job
	if world.state.has("event_system"):
		return _run_selected_due(phase, batches, due)
	# Determine deterministic identity work before any RNG or payment. Probabilistic
	# identity arbitration is deliberately not a supported participant capability.
	for index: int in batches.size():
		var batch: Dictionary = batches[index]
		var profile: Dictionary = _due_profile(batch.effects)
		if (profile.check and profile.identity) or (profile.death and profile.ordinary):
			return _fail("Due identity jobs cannot mix checks or conflicting transitions")
		batch["profile"] = profile
		batch["index"] = index
	batches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.profile.death if a.profile.death != b.profile.death else a.index < b.index)
	for batch: Dictionary in batches:
		var job: Dictionary = batch.job
		var invalid_targets: Array = []
		for target_id: String in batch.profile.targets:
			if Store.entry(world.state.npcs, target_id).status == "dead":
				invalid_targets.append(target_id)
		if not invalid_targets.is_empty():
			# Cancellation is per job, so a defeated restoration never pays its fee
			# or grants unrelated compensating effects. The terminal fact is a cause.
			var causes: Array = [job.source]
			for target_id: String in invalid_targets:
				causes.append(Store.entry(world.state.npcs, target_id).status_source)
			world._record("turn_consequence_cancelled", "", "", invalid_targets, world._unique_sorted(causes), {"job": job.id, "reason": "target_dead", "participant": job.participant, "scope": "whole_job"})
		else:
			for effect: Dictionary in batch.effects:
				if not _effect(job.participant, phase, effect, 0, [job.source], str(job.get("attention_token", ""))):
					return false
			# A successfully executed start job used this focus in the new turn.
			# Preserve that use when the final token is released before round_start;
			# cancelled jobs do not renew an old release request.
			if world.attention.enabled(world.state) and not batch.attention_focus.is_empty():
				world.stage_collections(["attention"])
				for domain: String in batch.attention_focus:
					if world.state.attention.release.has(domain): world.state.attention.release[domain] = world.state.turn
	return _complete_due_jobs(due, phase)

func _complete_due_jobs(due: Array, phase: String) -> bool:
	if not due.is_empty():
		_transaction.touch_context(["completed_jobs"])
	for job: Dictionary in due:
		_transaction.new_completed.append(job.id)
		world.history.consume_job(job)
		Store.put(context.completed_jobs, job.id, {"turn": context.turn, "phase": phase, "source": job.source, "participant": job.participant})
		context.queued = context.queued.filter(func(item: Dictionary) -> bool: return item.id != job.id)
	if world.attention.enabled(world.state):
		for token: String in world.state.attention.reservations.keys():
			if not world.state.attention.reservations[token].get("scheduled", false): continue
			if not context.queued.any(func(job: Dictionary) -> bool: return job.get("attention_token", "") == token): world.attention.release_reservation(world, token)
	return true

func _run_selected_due(phase: String, batches: Array, due: Array) -> bool:
	# Checks are facts of the common pre-identity state. Record every actual roll
	# before any death, restoration, resource effect or cancellation is applied.
	for batch: Dictionary in batches:
		batch["selected"] = []; batch["checks"] = []; batch["death_applied"] = false; batch["dead_declarations"] = []
		var job: Dictionary = batch.job
		for effect: Dictionary in batch.effects:
			if effect.type != "check":
				batch.selected.append({"effect": effect, "depth": 0, "parents": [job.source]}); continue
			var probability: int = world.check_probability(effect.npc, effect.attribute, effect.domain, effect.mode, effect.preparation)
			if probability < 0: return _fail("Due check has no current common-state probability")
			var roll: int = world.randoms.checks.randi_range(1, 100)
			var outcome: String = world.check_result(probability, roll)
			var parents: Array = world._unique_sorted([job.source, effect.source] + effect.get("parents", []))
			var checked: String = world._record("turn_check", effect.domain, effect.npc, [effect.npc], parents, {"probability": probability, "roll": roll, "outcome": outcome, "job": job.id})
			_checks.append({"probability": probability, "roll": roll, "outcome": outcome})
			batch.checks.append(checked)
			for selected: Dictionary in effect.branches[outcome]:
				batch.selected.append({"effect": selected, "depth": 1, "parents": [job.source, checked]})
		batch["profile"] = _selected_due_profile(batch.selected)
	# Only actual selected death effects participate. An unselected fatal branch
	# never changes another job's eligibility or claims death priority.
	for batch: Dictionary in batches:
		for selected: Dictionary in batch.selected:
			if not _is_due_death(selected.effect): continue
			var target: String = selected.effect.command.npc
			if Store.entry(world.state.npcs, target).status == "dead":
				batch.dead_declarations.append(target); continue
			if not _effect(batch.job.participant, phase, selected.effect, selected.depth, selected.parents, str(batch.job.get("attention_token", ""))): return false
			batch.death_applied = true
	for batch: Dictionary in batches:
		var job: Dictionary = batch.job
		var invalid_targets: Array = batch.dead_declarations.duplicate()
		for target: String in batch.profile.ordinary_targets:
			if Store.entry(world.state.npcs, target).status == "dead" and not target in invalid_targets: invalid_targets.append(target)
		if not invalid_targets.is_empty():
			var causes: Array = [job.source] + batch.checks
			for target: String in invalid_targets: causes.append(Store.entry(world.state.npcs, target).status_source)
			world._record("turn_consequence_cancelled", "", "", invalid_targets, world._unique_sorted(causes), {"job": job.id, "reason": "target_dead", "participant": job.participant, "scope": "nondeath_job_effects"})
		else:
			for selected: Dictionary in batch.selected:
				if _is_due_death(selected.effect): continue
				if not _effect(job.participant, phase, selected.effect, selected.depth, selected.parents, str(job.get("attention_token", ""))): return false
		if (batch.death_applied or invalid_targets.is_empty()) and world.attention.enabled(world.state) and not batch.attention_focus.is_empty():
			world.stage_collections(["attention"])
			for domain: String in batch.attention_focus:
				if world.state.attention.release.has(domain): world.state.attention.release[domain] = world.state.turn
	return _complete_due_jobs(due, phase)

func _is_due_death(effect: Dictionary) -> bool:
	return effect.type == "world_command" and effect.command.kind == "status" and effect.command.status == "dead"

func _selected_due_profile(selected: Array) -> Dictionary:
	var ordinary: Array = []
	for item: Dictionary in selected:
		var effect: Dictionary = item.effect
		var target: String = ""
		if effect.type == "world_command" and not _is_due_death(effect): target = str(effect.command.get("npc", ""))
		elif effect.type == "membership": target = str(effect.get("npc", ""))
		elif effect.type == "cults" and effect.get("operation") == "appointment": target = str(effect.payload.get("npc", ""))
		if not target.is_empty() and not target in ordinary: ordinary.append(target)
	return {"ordinary_targets": ordinary}

func _due_profile(effects: Array) -> Dictionary:
	var profile: Dictionary = {"check": false, "identity": false, "death": false, "ordinary": false, "targets": []}
	for effect: Dictionary in effects:
		if effect.type == "check":
			profile.check = true
			for branch: Array in effect.branches.values():
				var nested: Dictionary = _due_profile(branch)
				profile.identity = profile.identity or nested.identity
		elif effect.type == "cults" and effect.get("operation") == "appointment":
			profile.identity = true; profile.ordinary = true
			if not effect.payload.npc in profile.targets: profile.targets.append(effect.payload.npc)
		elif effect.type == "membership":
			profile.identity = true; profile.ordinary = true
			if not effect.npc in profile.targets: profile.targets.append(effect.npc)
		elif effect.type == "world_command":
			profile.identity = true
			var command: Dictionary = effect.command
			var death: bool = command.kind == "status" and command.status == "dead"
			profile.death = profile.death or death
			profile.ordinary = profile.ordinary or not death
			if command.kind in ["status", "migrate"] and not command.npc in profile.targets:
				profile.targets.append(command.npc)
	return profile

func snapshot() -> String:
	if not _attached or _in_transaction or _in_participant:
		return ""
	var body: Dictionary = {"schema": SCHEMA_VERSION, "content": world.catalog.version, "engine": Engine.get_version_info().string, "participants": capabilities(), "commit_sequence": commit_sequence, "world": world.snapshot(), "context": context}
	return World.canonical({"body": body, "checksum": World.canonical(body).sha256_text()})

func restore(serialized: String) -> bool:
	last_error = ""
	if not _attached or _in_transaction or _in_participant:
		return _fail("Cannot restore during a transaction")
	var parser: JSON = JSON.new()
	if parser.parse(serialized) != OK or not parser.data is Dictionary:
		return _fail("Malformed turn snapshot")
	var envelope: Dictionary = parser.data
	if not envelope.get("body") is Dictionary or not envelope.get("checksum") is String:
		return _fail("Missing turn envelope")
	var body: Dictionary = World._normalize_numbers(envelope.body)
	if World.canonical(body).sha256_text() != envelope.checksum or body.get("schema") != SCHEMA_VERSION or body.get("content") != world.catalog.version or body.get("engine") != Engine.get_version_info().string or not body.get("participants") is Dictionary or World.canonical(body.participants) != World.canonical(capabilities()) or not body.get("world") is String or not body.get("context") is Dictionary:
		return _fail("Incompatible turn snapshot or participants")
	var temporary: RefCounted = World.new(world.catalog)
	if not temporary.restore(body.world) or not _validate_context(body.context, temporary.state).is_empty() or not temporary.ensure_history():
		return _fail("Turn snapshot state or phase evidence is invalid")
	var restored_sequence: Variant = body.get("commit_sequence")
	if not restored_sequence is int or int(restored_sequence) != Store.size(body.context.receipts):
		return _fail("Commit sequence disagrees with durable receipts")
	if not world.restore(body.world, self):
		return _fail("World refused validated snapshot")
	context = body.context
	commit_sequence = restored_sequence
	world.state = Store.pack_state(temporary.state)
	world.history = temporary.history
	world.history.source_root = world.state
	context = Store.pack_context(context)
	world.history.rebuild_jobs(context)
	Transaction.freeze(world.history.data)
	Transaction.freeze(world.state, true)
	Transaction.freeze(context, true)
	Transaction.freeze(world.stats, true)
	_trusted_world = world.state
	_trusted_context = context
	_archive = null
	return true

func _validate_context(value: Dictionary, world_state: Dictionary, trusted: Dictionary = {}) -> Array[String]:
	if trusted.is_empty(): value = HistoryIndex.export_value(value)
	var errors: Array[String] = []
	if value.get("knowledge_version") != PlayerKnowledge.VERSION or not value.get("player_knowledge") is Dictionary: return ["Invalid authoritative player knowledge version"]
	errors.append_array(PlayerKnowledge.validate_ledger(world_state, value.player_knowledge))
	if world.state.has(Opportunities.ID) != world_state.has(Opportunities.ID): return ["Direct service installation differs from saved state"]
	if world_state.has("simulation"):
		if not value.get("background_ids") is Array: return ["Missing frozen background selection"]
		var ids: Dictionary = {}
		for id: Variant in value.background_ids:
			if not id is String or ids.has(id) or not str(id).begins_with("BACKGROUND-") or int(str(id).get_slice("-", 1)) < 1 or int(str(id).get_slice("-", 1)) >= int(world_state.simulation.next_candidate): return ["Invalid frozen background selection"]
			ids[id] = true
	for field: String in ["receipts", "plans", "locked_plans", "completed_jobs", "participant_state"]:
		if not value.get(field) is Dictionary:
			errors.append("Missing turn dictionary")
	for field: String in ["events", "queued", "journal"]:
		if not value.get(field) is Array and not (field == "journal" and HistoryIndex.is_history(value[field]) and value[field].kind == "sequence"):
			errors.append("Missing turn array")
	for field: String in ["turn", "whispers_budget", "responses"]:
		if not value.get(field) is int or int(value[field]) < 0:
			errors.append("Invalid turn number")
	for field: String in ["power_used", "relic_used"]:
		if not value.get(field) is bool:
			errors.append("Invalid opportunity state")
	var current: Dictionary = value.duplicate(false)
	if not trusted.is_empty():
		for history: String in Transaction.HISTORY_CONTEXT:
			if not value.has(history):
				continue
			errors.append_array(Transaction.append_only_errors(value[history], trusted[history]))
			current.erase(history)
	if not value.get("phase", "") in PHASES or not value.get("outcome") is String or value.get("turn") != world_state.get("turn") or not _plain(current):
		errors.append("Invalid turn identity")
	if not errors.is_empty():
		return errors
	errors.append_array(Opportunities.validate_context(world_state, value))
	if not errors.is_empty(): return errors
	if int(value.turn) > 0:
		for slot: String in REQUIRED:
			if not _required_available(slot):
				errors.append("Started session lacks a required capability")
	if world_state.has("progression_routes") != _participants.has("progression_routes"): errors.append("Progression rules and saved capability disagree")
	if world_state.has("cult_system") != _participants.has("cults"):
		errors.append("Cult rules and saved capability disagree")
	var cult_context_errors: Array[String] = Cults.validate_context(world_state, value)
	if not cult_context_errors.is_empty(): return cult_context_errors
	if world_state.has("power_system") != _participants.has("powers"): errors.append("Power rules and saved capability disagree")
	if world_state.has("anchor_system") != _participants.has("anchors"): errors.append("Anchor rules and saved capability disagree")
	if world_state.has("event_system") != _participants.has("events"): errors.append("Event rules and saved capability disagree")
	if world_state.has("resistance_system") != _participants.has("resistance"): errors.append("Resistance rules and saved capability disagree")
	if world_state.has("player_sources") != _participants.has("player_sources"): errors.append("Player source rules and saved capability disagree")
	if world_state.has("ending_system") != _participants.has("endings"): errors.append("Ending rules and saved capability disagree")
	var terminal: Dictionary = Store.entry(world_state.facts, world_state.get("ending_system", {}).get("terminal", ""), {})
	var abandoned: bool = not terminal.is_empty() and terminal.changes.get("reason") == "voluntary"
	if world_state.has("ending_system") and ((value.phase == "ended") != (not terminal.is_empty()) or (not terminal.is_empty() and terminal.changes.outcome != value.outcome)): errors.append("Terminal capability and session disagree")
	if world_state.has("ending_system"):
		var cursor_phase: String = str(terminal.changes.phase) if abandoned else str(value.phase)
		var assessed_turn: int = int(value.turn) if cursor_phase in ["between", "ended"] else maxi(0, int(value.turn) - 1)
		if int(world_state.ending_system.last_turn) != assessed_turn: errors.append("Ending assessment does not match completed rounds")
	var event_context_errors: Array[String] = Events.validate_context(world_state, value)
	if not event_context_errors.is_empty(): return event_context_errors
	var economy_context: Dictionary = value
	if abandoned:
		economy_context = value.duplicate(false); economy_context.phase = terminal.changes.phase
	if not Economy.valid_phase(world_state, economy_context):
		errors.append("Economy receipts disagree with turn phase")
	var internal: String = "actions" if value.phase in ["events", "actions", "evolution"] else "between"
	if world_state.phase != internal or int(world_state.whispers) > int(value.whispers_budget) or int(value.whispers_budget) > world.catalog.integer("whisper_cap") or int(value.responses) > world.catalog.integer("prayer_response_limit"):
		errors.append("World clock or budget differs from coordinator")
	if not value.outcome in ["", "extinction", "awakened"] or (value.phase == "ended") != (not str(value.outcome).is_empty()):
		errors.append("Ending state differs from phase")
	var expected: int = {"between": 6, "events": 1, "actions": 2, "evolution": 3, "settlement": 4, "ending": 5, "ended": 6}[value.phase]
	if abandoned: expected = {"between": 6, "events": 1, "actions": 2, "evolution": 3, "settlement": 4, "ending": 5}[terminal.changes.phase]
	var completed: Array = []
	var journal_start: int = Store.size(trusted.get("journal", []))
	var expected_turn: int = journal_start / 6 + 1
	var expected_phase: int = journal_start % 6 + 1
	for index: int in range(journal_start, Store.size(value.journal)):
		var entry: Variant = Store.entry(value.journal, index)
		if not entry is Dictionary or entry.get("turn") != expected_turn or entry.get("phase") != expected_phase:
			errors.append("Phase receipt sequence is invalid")
			break
		expected_phase += 1
		if expected_phase == 7:
			expected_phase = 1
			expected_turn += 1
		if entry.turn == value.turn:
			completed.append(entry.phase)
	if int(value.turn) == 0:
		if not (Store.size(value.journal) == 0) or (value.phase != "between" and not abandoned):
			errors.append("Initial phase is invalid")
	elif (trusted.is_empty() and completed.size() != expected) or Store.size(value.journal) != (int(value.turn) - 1) * 6 + expected:
		errors.append("Phase cursor has no matching completed stages")
	for id: String in _participants:
		if not value.participant_state.get(id) is Dictionary:
			errors.append("Missing participant state")
	if value.participant_state.size() != _participants.size():
		errors.append("Unknown participant state")
	for plan_set: String in ["plans", "locked_plans"]:
		for id: String in value[plan_set]:
			if not _participants.has(id) or not value[plan_set][id] is Dictionary:
				errors.append("Unknown or invalid participant plan")
	if not abandoned and int(value.turn) > 0 and value.phase in ["evolution", "settlement", "ending", "between", "ended"] and World.canonical(value.plans) != World.canonical(value.locked_plans):
		errors.append("Locked plans differ after action closure")
	if value.events.size() > world.catalog.integer("major_event_limit") or (int(value.turn) == 0 and not value.events.is_empty()):
		errors.append("Frozen event count is invalid")
	var ids: Dictionary = {}
	for event: Variant in value.events:
		if not event is Dictionary or not event.get("id") is String or str(event.id).is_empty() or ids.has(event.id) or not _participants.has(event.get("participant", "")) or not event.get("resolved") is bool or not event.get("payload") is Dictionary or not event.get("default_action") is String or str(event.default_action).is_empty() or not Store.has(world_state.facts, event.get("source", "")):
			errors.append("Invalid frozen event")
		else:
			ids[event.id] = true
			if not "events" in _participants[event.participant].slots or (value.phase != "events" and not abandoned and not event.resolved):
				errors.append("Unresolved event or wrong capability")
	ids = {}
	for job: Variant in value.queued:
		if not job is Dictionary or not job.get("id") is String or str(job.id).is_empty() or ids.has(job.id) or Store.has(value.completed_jobs, job.id) or not job.get("due") is int or int(job.due) < 1 or not job.get("phase", "") in ["start", "deadlines"] or not job.get("payload") is Dictionary or not job.get("action") is String or str(job.action).is_empty() or not _participants.has(job.get("participant", "")) or not Store.has(world_state.facts, job.get("source", "")):
			errors.append("Invalid queued consequence")
		else:
			ids[job.id] = true
			var fact: Dictionary = Store.entry(world_state.facts, job.source)
			if not job.phase in _participants[job.participant].slots or fact.kind != "turn_scheduled" or fact.changes.get("id") != job.id or fact.changes.get("phase") != job.phase or fact.changes.get("due") != job.due or fact.changes.get("participant") != job.participant:
				errors.append("Queued consequence has no matching ownership and cause")
			if not abandoned and (int(job.due) < int(value.turn) or (int(job.due) == int(value.turn) and (job.phase == "start" or not value.phase in ["events", "actions", "evolution", "settlement"]))):
				errors.append("Queued consequence has missed its settlement boundary")
	for id: String in (Store.keys(value.completed_jobs) if trusted.is_empty() else _transaction.new_completed):
		var job: Variant = Store.entry(value.completed_jobs, id)
		if id.is_empty() or not job is Dictionary or not job.get("turn") is int or int(job.turn) < 1 or int(job.turn) > int(value.turn) or not job.get("phase", "") in ["start", "deadlines"] or not _participants.has(job.get("participant", "")) or not Store.has(world_state.facts, job.get("source", "")):
			errors.append("Invalid consumed consequence")
		else:
			var fact: Dictionary = Store.entry(world_state.facts, job.source)
			if not job.phase in _participants[job.participant].slots or fact.kind != "turn_scheduled" or fact.changes.get("id") != id or fact.changes.get("phase") != job.phase or fact.changes.get("due") != job.turn or fact.changes.get("participant") != job.participant:
				errors.append("Consumed consequence has no matching ownership and cause")
			if int(job.turn) == int(value.turn) and job.phase == "deadlines" and expected < 5:
				errors.append("Consequence consumed before its phase")
	errors.append_array(_receipt_position_errors(value, world_state, trusted))
	if not errors.is_empty(): return errors
	errors.append_array(_prayer_window_errors(value, world_state))
	if not errors.is_empty(): return errors
	var knowledge_rules: GDScript = load("res://src/game/prayer_knowledge.gd")
	if trusted.is_empty():
		errors.append_array(knowledge_rules.validate_context(world_state, value, world.catalog))
		if errors.is_empty(): errors.append_array(SocialGraph.validate_context(world_state, value, world.catalog, 0, {}, world.attention.policies))
	else:
		var new_receipts: Dictionary = {}
		for id: String in _transaction.new_receipts:
			var receipt: Dictionary = Store.entry(value.receipts, id)
			new_receipts[receipt.sequence] = receipt
		errors.append_array(knowledge_rules.validate_context(world_state, value, world.catalog, int(_transaction.base_state.next_fact), new_receipts))
		if errors.is_empty(): errors.append_array(SocialGraph.validate_context(world_state, value, world.catalog, int(_transaction.base_state.next_fact), new_receipts, world.attention.policies))
	if not errors.is_empty(): return errors
	var terminal_receipt: bool = false
	var phase_receipts: Dictionary = {}
	if not trusted.is_empty() and Store.size(value.receipts) != Store.size(trusted.receipts) + 1:
		errors.append("Transaction must append exactly one durable receipt")
	for id: String in (Store.keys(value.receipts) if trusted.is_empty() else _transaction.new_receipts):
		if not _plain(Store.entry(value.receipts, id)) or not _valid_receipt(id, Store.entry(value.receipts, id), value):
			errors.append("Invalid request receipt")
		else:
			var receipt: Dictionary = Store.entry(value.receipts, id)
			if receipt.request.op == "rest" and not Economy.valid_rest_receipt(world_state, receipt.request, world.catalog): errors.append("Rest receipt does not match its production payment")
			if receipt.response.phase == "ended" and not terminal.is_empty():
				if terminal_receipt or receipt.request.phase != terminal.changes.phase or receipt.request.op != ("abandon" if abandoned else "advance"):
					errors.append("Terminal seal has no matching final operation")
				terminal_receipt = true
			if not trusted.is_empty() and (receipt.request.turn != trusted.turn or receipt.request.phase != trusted.phase or receipt.response.turn != value.turn or receipt.response.phase != value.phase):
				errors.append("New receipt does not connect the committed and candidate cursors")
			if receipt.request.op in ["advance", "finish_events", "end_actions", "rest"]:
				var phase_number: int = {"events": 1, "actions": 2, "evolution": 3, "settlement": 4, "ending": 5, "between": 6, "ended": 6}[receipt.response.phase]
				var key: String = "%d/%d" % [receipt.response.turn, phase_number]
				if phase_receipts.has(key):
					errors.append("Duplicate phase completion receipts")
				phase_receipts[key] = true
	if not terminal.is_empty() and not terminal_receipt: errors.append("Terminal seal lacks a durable request")
	for index: int in range(journal_start, Store.size(value.journal)):
		var entry: Variant = Store.entry(value.journal, index)
		if entry is Dictionary and entry.get("turn") is int and entry.get("phase") is int and not phase_receipts.has("%d/%d" % [entry.turn, entry.phase]):
			errors.append("Completed phase has no durable request receipt")
	return errors

## Receipt fact ranges are half-open next_fact positions. Full audit orders by
## sequence rather than request ID; normal transactions inspect only their append.
func _prayer_window_errors(value: Dictionary, state: Dictionary) -> Array[String]:
	if not state.has("simulation"): return []
	for card: Dictionary in state.simulation.candidates.values():
		if card.get("origin") != "prayer_situation": continue
		var situation: Dictionary = Store.entry(state.facts, str(card.get("source", "")), {})
		var details: Dictionary = situation.get("changes", {})
		var field: String = {"rescue": "condition", "recognition": "conflict", "concealment": "pursuit", "obligation": "contract", "memory": "memory", "judgment": "conflict"}.get(str(details.get("need", "")), "")
		if field.is_empty(): continue
		var root: String = str(details.get("facts", {}).get(field, ""))
		var original: Dictionary = Store.entry(state.facts, root, {})
		for job: Dictionary in value.queued:
			if job.phase != "start" or int(job.due) != int(original.get("changes", {}).get("due", -1)): continue
			if not PrayerRules.deadline_uses_root(state, str(job.source), root): continue
			if int(card.visible_turn) >= int(job.due): return ["Fixed prayer has no action before its original start-phase consequence"]
	return []

func _receipt_position_errors(value: Dictionary, state: Dictionary, trusted: Dictionary) -> Array[String]:
	var by_sequence: Dictionary = {}
	var count: int = Store.size(value.receipts)
	for id: String in (Store.keys(value.receipts) if trusted.is_empty() else _transaction.new_receipts):
		var receipt: Variant = Store.entry(value.receipts, id)
		if not receipt is Dictionary or not receipt.get("sequence") is int or not receipt.get("fact_before") is int or not receipt.get("fact_after") is int:
			return ["Receipt lacks transaction position"]
		if receipt.sequence < 1 or receipt.sequence > count or by_sequence.has(receipt.sequence) or receipt.fact_before < 1 or receipt.fact_after < receipt.fact_before or receipt.fact_after > int(state.next_fact):
			return ["Invalid receipt transaction range"]
		if not _valid_receipt(id, receipt, value): return ["Invalid positioned receipt"]
		by_sequence[receipt.sequence] = receipt
		if not trusted.is_empty() and (receipt.sequence != _transaction.sequence + 1 or receipt.fact_before != int(_transaction.base_state.next_fact) or receipt.fact_after != int(state.next_fact)):
			return ["Receipt does not match actual transaction range"]
	if not trusted.is_empty(): return []
	if count == 0: return []
	var previous: Dictionary = {}
	for sequence: int in range(1, count + 1):
		if not by_sequence.has(sequence): return ["Receipt sequence has a gap"]
		var receipt: Dictionary = by_sequence[sequence]
		if sequence == 1:
			if receipt.request.turn != 0 or receipt.request.phase != "between": return ["Receipt chain lacks initial cursor"]
		else:
			if receipt.fact_before != previous.fact_after or receipt.request.turn != previous.response.turn or receipt.request.phase != previous.response.phase:
				return ["Receipt chain has discontinuous facts or cursor"]
		previous = receipt
	if previous.fact_after != int(state.next_fact) or previous.response.turn != value.turn or previous.response.phase != value.phase:
		return ["Receipt chain does not reach current state"]
	# Facts before the first transaction belong to initialization; later facts
	# must lie in an actual committed turn, not in an invented future range.
	var sequence: int = 1
	for number: int in range(1, int(state.next_fact)):
		while sequence < count and number >= int(by_sequence[sequence].fact_after): sequence += 1
		var fact: Dictionary = Store.entry(state.facts, "FACT-%08d" % number, {})
		var expected_turn: int = 0 if number < int(by_sequence[1].fact_before) else int(by_sequence[sequence].response.turn)
		if fact.is_empty() or fact.get("turn") != expected_turn: return ["Receipt fact range disagrees with historical turn"]
	return []

func _valid_receipt(id: String, receipt: Variant, saved: Dictionary) -> bool:
	if id.is_empty() or not receipt is Dictionary or not receipt.get("request") is Dictionary or receipt.request.get("id") != id or not receipt.get("response") is Dictionary or receipt.response.get("ok") != true or not receipt.get("fingerprint") is String or receipt.fingerprint != World.canonical(receipt.request).sha256_text():
		return false
	var request: Dictionary = receipt.request
	var response: Dictionary = receipt.response
	if not request.get("turn") is int or int(request.turn) < 0 or not request.get("phase", "") in PHASES or not response.get("turn") is int or (int(response.turn) < 1 and not (request.op == "abandon" and int(response.turn) == 0)) or int(response.turn) > int(saved.turn) or not response.get("phase", "") in PHASES or not response.get("result") is Dictionary or not response.result.get("checks") is Array or not response.result.get("outcome", "INVALID") in ["", "extinction", "awakened"]:
		return false
	var allowed_keys: Dictionary = {"rest": [], "abandon": [], "advance": [], "finish_events": [], "resolve_event": ["event", "action", "payload"], "act": ["participant", "action", "payload"], "set_plan": ["participant", "payload"], "end_actions": [], "attention": ["command"]}
	if not allowed_keys.has(request.get("op", "")):
		return false
	for key: String in request:
		if not key in ["id", "op", "turn", "phase"] and not key in allowed_keys[request.op]:
			return false
	var stage: Dictionary = {"events": 1, "actions": 2, "evolution": 3, "settlement": 4, "ending": 5, "between": 6, "ended": 6}
	if response.turn == saved.turn and int(stage[response.phase]) > int(stage[saved.phase]):
		return false
	var next_phase: String = ""
	var next_turn: int = request.turn
	match request.get("op", ""):
		"abandon":
			if _participants.has("endings") and request.phase != "ended": next_phase = "ended"
		"advance":
			match request.phase:
				"between":
					next_phase = "events"
					next_turn += 1
				"evolution": next_phase = "settlement"
				"settlement": next_phase = "ending"
				"ending": next_phase = "ended" if response.result.outcome != "" else "between"
		"finish_events":
			if request.phase == "events": next_phase = "actions"
		"end_actions", "rest":
			if request.phase == "actions": next_phase = "evolution"
		"resolve_event":
			if request.phase == "events" and _event_selection(request.get("payload", {})) and request.get("event") is String and not str(request.event).is_empty() and request.get("action") is String and not str(request.action).is_empty(): next_phase = "events"
		"attention":
			if request.phase == "actions" and request.get("command") is Dictionary and request.command.get("kind") in ["focus", "release_focus", "enroll", "leave", "release_project"]: next_phase = "actions"
		"act", "set_plan":
			if request.phase == "actions" and _participants.has(request.get("participant", "")) and request.get("payload", {}) is Dictionary:
				if (request.op == "set_plan" and request.get("payload") is Dictionary) or (request.op == "act" and "actions" in _participants[request.participant].slots and request.get("action") is String and not str(request.action).is_empty()): next_phase = "actions"
	if next_phase.is_empty() or response.phase != next_phase or response.turn != next_turn or (response.phase == "ended") != (response.result.outcome != ""):
		return false
	if response.phase == "ended" and (saved.phase != "ended" or response.turn != saved.turn or response.result.outcome != saved.outcome):
		return false
	for check: Variant in response.result.checks:
		if not check is Dictionary or not check.get("roll") is int or int(check.roll) < 1 or int(check.roll) > 100 or not check.get("probability") is int or int(check.probability) < 0 or int(check.probability) > 100 or not check.get("outcome", "") in ["deep", "success", "failure", "disaster"]:
			return false
	return true

static func _strings(values: Array) -> bool:
	for value: Variant in values:
		if not value is String:
			return false
	return true

static func _plain(value: Variant) -> bool:
	if value is Dictionary and value.has("$history_index"): return false
	if value == null or value is bool or value is int or value is String:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for item: Variant in value:
			if not _plain(item):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if (not key is String and not key is StringName) or not _plain(value[key]):
				return false
		return true
	return false

func _archive_ready() -> bool:
	return _attached and not _in_transaction and not _in_participant and _audit_adoption()

func _archive_checkpoint() -> Dictionary:
	var streams: Dictionary = {}
	for name: String in world.randoms:
		streams[name] = {"seed": str(world.randoms[name].seed), "state": str(world.randoms[name].state)}
	var checkpoint: Dictionary = {"schema": 2, "turn_schema": SCHEMA_VERSION, "sequence": commit_sequence, "index_sequence": commit_sequence, "content": world.catalog.version, "engine": Engine.get_version_info().string, "participants": capabilities(), "world": {"schema": World.SCHEMA_VERSION, "content": world.catalog.version, "engine": Engine.get_version_info().string, "state": world.state, "randoms": streams, "stats": world.stats}, "context": context}

	if world.state.has("simulation"): checkpoint.world["simulation_policy"] = world.state.simulation.policy
	if world.state.has("attention"): checkpoint.world["attention_policy"] = world.state.attention.policy
	return checkpoint

func _adopt_archive(checkpoint: Dictionary) -> bool:
	if checkpoint.get("schema") != 2 or checkpoint.get("turn_schema") != SCHEMA_VERSION or checkpoint.get("index_sequence") != checkpoint.get("sequence") or not checkpoint.get("world") is Dictionary or not checkpoint.get("context") is Dictionary: return _fail("Invalid archive checkpoint")
	var world_body: Dictionary = HistoryIndex.export_value(checkpoint.world)
	var world_json: String = World.canonical({"body": world_body, "checksum": World.canonical(world_body).sha256_text()})
	var body: Dictionary = {"schema": SCHEMA_VERSION, "commit_sequence": checkpoint.get("sequence"), "content": checkpoint.get("content"), "engine": checkpoint.get("engine"), "participants": checkpoint.get("participants"), "world": world_json, "context": HistoryIndex.export_value(checkpoint.context)}
	if not restore(World.canonical({"body": body, "checksum": World.canonical(body).sha256_text()})): return false
	world.state = checkpoint.world.state
	context = checkpoint.context
	Transaction.freeze(world.state, true)
	Transaction.freeze(context, true)
	world.history.source_root = world.state
	_trusted_world = world.state
	_trusted_context = context
	return true

func save_archive(path: String, fault: String = "") -> bool:
	if _archive == null: _archive = Store.new()
	var ok: bool = _archive.save(self, path, fault)
	last_save_metrics = _archive.metrics.duplicate(true)
	if not ok: last_error = _archive.last_error
	return ok

func load_archive(path: String) -> bool:
	if not _attached or _in_transaction or _in_participant: return _fail("Cannot load archive now")
	var storage: RefCounted = Store.new()
	if not storage.load_session(self, path): return _fail(storage.last_error)
	_archive = storage
	return true

func preview_attention(command: Dictionary) -> Dictionary:
	if not _attached or _in_participant or not world.attention.enabled(world.state): return {"ok": false, "error": "Hybrid attention unavailable"}
	var reader: RefCounted = StateView.new(world.state, context, commit_sequence, world.history)
	var view: Dictionary = reader.participant("cults", "actions")
	view["catalog"] = world.catalog; view["attention"] = world.attention
	var result: Dictionary = Eligibility.attention(view, command)
	reader.close()
	return result

func _attention_command(command: Dictionary) -> bool:
	if not world.attention.enabled(world.state) or context.phase != "actions": return _fail("Attention commands require hybrid action phase")
	var check: Dictionary = preview_attention(command)
	if not check.ok: return _fail(check.error)
	world.stage_current()
	match str(command.kind):
		"release_focus": world.state.attention.release[command.domain] = world.state.turn
		"release_project": return world.attention.release_reservation(world, command.token)
		"leave": return world.attention.leave(world, command.npc, command.source)
		_:
			var reserved: Dictionary = world.attention.reserve(world, check.needs, false, {"kind": "manual", "command": command.duplicate(true)})
			if not reserved.ok: return _fail(reserved.error)
			if command.kind == "enroll" and not world.attention.enroll(world, command.npc, command.source, reserved.token): return _fail("Membership applicant no longer eligible")
			world.attention.finish(world, reserved.token)
	return true

func _lock_attention_plans() -> bool:
	if not world.attention.enabled(world.state) or not _participants.has(Economy.ID): return true
	var plan: Dictionary = context.plans.get(Economy.ID, {}).duplicate(true)
	var preview: Dictionary = _participants[Economy.ID].instance.preview(world.state, plan)
	if not preview.ok: return _fail(preview.error)
	if not plan.has("strategies"): plan.strategies = {}
	context["attention_plan_reasons"] = {}
	var admitted: Array = []
	var admitted_strategies: Dictionary = {}
	for row: Dictionary in preview.preview.cults:
		if row.intent != "expand": continue
		if row.effective != "expand": plan.strategies[row.cult] = "hold"; context.attention_plan_reasons[row.cult] = row.reason; continue
		var domain: String = world.state.cults[row.cult].domain
		var needs: Dictionary = world.attention.preview_needs(world.state, {"family": "strategy", "content_id": "proselytize", "variant": "plan", "target": domain, "source": row.source})
		if not needs.ok:
			plan.strategies[row.cult] = "hold"; context.attention_plan_reasons[row.cult] = needs.error; continue
		var reserved: Dictionary = world.attention.reserve(world, needs, false, {"kind": "strategy", "cult": row.cult, "row": row.duplicate(true), "descriptor": {"family": "strategy", "content_id": "proselytize", "variant": "plan", "target": domain, "source": row.source}})
		if not reserved.ok:
			if reserved.get("hard_failure", false): return _fail(reserved.error)
			plan.strategies[row.cult] = "hold"; context.attention_plan_reasons[row.cult] = reserved.error
		else:
			if not str(reserved.get("admission", "")).is_empty():
				admitted.append(reserved.admission)
				admitted_strategies[row.cult] = "expand"
			world.attention.finish(world, reserved.token)
	context.plans[Economy.ID] = plan
	if not admitted.is_empty(): world._record("attention_plan_locked", "", "", [], admitted, {"strategies": plan.strategies.merged(admitted_strategies, true), "admissions": admitted})
	return true

func _event_selection(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (value.size() == 1 and value.get("qualification") is String and not str(value.qualification).is_empty()))
