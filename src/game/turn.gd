extends RefCounted
const Store = preload("res://src/simulation/archive_store.gd")
## The only session-level clock. Participants are stateless, versioned rule adapters:
## they read copies and return allowed declarations; they never receive mutable World.
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const StateView = preload("res://src/simulation/state_view.gd")
const World = preload("res://src/simulation/world.gd")
const Economy = preload("res://src/game/economy.gd")
const SCHEMA_VERSION: int = 1
const SLOTS: Array[String] = ["events", "actions", "prepay", "income", "deadlines", "ending", "start", "round_start", "evolution"]
const REQUIRED: Array[String] = ["events", "prepay", "income", "deadlines", "ending"]
const EFFECTS: Array[String] = ["world_command", "fact", "resource", "wounds", "schedule", "check", "end", "economy"]
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

func register_participant(id: String, version: String, slots: Array, allowed_effects: Array, handler: Callable, plan_validator: Callable = Callable()) -> bool:
	if not _attached or _in_transaction or _in_participant or int(context.turn) != 0 or not (Store.size(context.receipts) == 0) or id.is_empty() or version.is_empty() or not handler.is_valid() or _participants.has(id) or slots.is_empty():
		return false
	for slot: Variant in slots:
		if not slot is String or not slot in SLOTS or _owners.has(slot):
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
		_owners[slot] = id
	return true

func capabilities() -> Dictionary:
	var manifest: Dictionary = {}
	for id: String in _participants:
		var entry: Dictionary = _participants[id]
		manifest[id] = {"version": entry.version, "slots": entry.slots.duplicate(), "effects": entry.effects.duplicate(), "plan_validation": entry.plan_validator.is_valid()}
	return manifest

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
	var allowed_keys: Dictionary = {"advance": [], "finish_events": [], "resolve_event": ["event", "action"], "act": ["participant", "action", "payload"], "set_plan": ["participant", "payload"], "end_actions": []}
	if not allowed_keys.has(request.op):
		return _reject("Unknown operation")
	for key: String in request:
		if not key in ["id", "op", "turn", "phase"] and not key in allowed_keys[request.op]:
			return _reject("Unknown request field")
	if context.phase == "ended":
		return _reject("Ended sessions are read-only")
	for slot: String in REQUIRED:
		if not _owners.has(slot):
			return _reject("Missing required participant: " + slot)
	_transaction = Transaction.new(world, context, commit_sequence)
	if not _transaction.activate():
		var reason: String = _transaction.error
		_transaction = null
		return _reject(reason)
	context = _transaction.context
	_in_transaction = true
	_checks = []
	var valid: bool = _dispatch(request)
	var response: Dictionary = {}
	if valid:
		world._refresh_anchors()
		response = {"ok": true, "phase": context.phase, "turn": context.turn, "result": {"checks": _checks.duplicate(true), "outcome": context.outcome}}
		_transaction.touch_context(["receipts"])
		_transaction.new_receipts.append(request.id)
		Store.put(context.receipts, request.id, {"fingerprint": fingerprint, "request": request.duplicate(true), "response": response.duplicate(true)})
		valid = _transaction.validate_world().is_empty() and _validate_context(context, world.state, _transaction.base_context).is_empty()
		if not valid:
			last_error = "Transaction violated world or turn invariants"
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

func _reject(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "error": reason}

func _fail(reason: String) -> bool:
	last_error = reason
	return false

func _dispatch(request: Dictionary) -> bool:
	match request.op:
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
			return context.phase == "events" and request.get("event") is String and request.get("action") is String and _resolve_event(request.event, request.action, false)
		"act":
			if context.phase != "actions" or not request.get("participant") is String or not request.get("action") is String or not request.get("payload", {}) is Dictionary:
				return _fail("Illegal action window or payload")
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
			context.locked_plans = context.plans.duplicate(true)
			_complete(3, "evolution")
			return true
	return _fail("Unknown operation")

func _advance() -> bool:
	match context.phase:
		"between":
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
			if not _run_due("start") or not world.finish_turn_start(self):
				return false
			context.whispers_budget = world.state.whispers
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
			_complete(4, "settlement")
			return true
		"settlement":
			if not _invoke(_owners.income, "income", {"operation": "settle"}) or not _run_due("deadlines") or not _invoke(_owners.deadlines, "deadlines", {"operation": "settle"}):
				return false
			_complete(5, "ending")
			return true
		"ending":
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

func _read_view(id: String, slot: String) -> Dictionary:
	var reader: RefCounted = StateView.new(world.state, context, commit_sequence, world.history)
	var view: Dictionary = reader.participant(id, slot)
	if _transaction != null:
		_transaction.metrics["view_objects"] = int(_transaction.metrics.get("view_objects", 0)) + int(reader.metrics.objects)
		_transaction.metrics["view_facts"] = int(_transaction.metrics.get("view_facts", 0)) + int(reader.metrics.facts)
	return view

func _call_guarded(callback: Callable, view: Dictionary, input: Dictionary) -> Dictionary:
	# A participant receives only detached projections. Capturing the coordinator
	# does not expose its candidate either: direct reads during callbacks see a
	# separate guarded projection. Previously published aliases are immutable.
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
	var clean: bool = is_same(world, saved_world) and is_same(world.history, guard_history) and is_same(saved_history.rules, saved_history_rules) and is_same(guard_history.rules, saved_history_rules) and is_same(saved_history.source_root, saved_history_source) and is_same(guard_history.source_root, saved_history_source) and guard_history.policy == saved_history_policy and guard_history.page_limit == saved_history_limit and guard_history.incarnation == saved_history_incarnation and is_same(saved_history.data, saved_history_data) and saved_history.version == saved_history_version and saved_history.policy == saved_history_policy and saved_history.page_limit == saved_history_limit and saved_history.incarnation == saved_history_incarnation and HistoryIndex.same_roots(world.history.data, saved_history_data) and world.history.version == saved_history_version and commit_sequence == saved_sequence and is_same(world, saved_world) and world.state == before_state and context == before_context and world.stats == before_stats and Transaction.random_positions(world.randoms) == before_randoms and Transaction.random_positions(saved_randoms) == before_randoms
	for name: String in saved_rng_objects:
		saved_rng_objects[name].seed = int(before_randoms[name][0])
		saved_rng_objects[name].state = int(before_randoms[name][1])
	commit_sequence = saved_sequence
	world = saved_world
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
	if action and not _apply_action_meta(result.get("meta", {}), default_choice):
		return false
	if slot == "events" and input.operation == "gather":
		if not result.get("events") is Array or not _freeze_events(id, result.events):
			return _fail("Invalid event selection")
	elif result.has("events"):
		return _fail("Events can only be selected at the frozen boundary")
	if defer_effects:
		prepared.append({"participant": id, "slot": slot, "effects": result.effects.duplicate(true)})
		context.participant_state[id] = result.state.duplicate(true)
		return true
	for effect: Variant in result.effects:
		if not effect is Dictionary or not _effect(id, slot, effect):
			return false
	context.participant_state[id] = result.state.duplicate(true)
	world._refresh_anchors()
	return true

func _apply_action_meta(meta: Variant, default_choice: bool) -> bool:
	if not meta is Dictionary:
		return _fail("Missing action metadata")
	for field: String in ["faith_cost", "whispers_cost", "min_awakening"]:
		if not meta.get(field) is int or int(meta[field]) < 0:
			return _fail("Invalid action cost or threshold")
	for field: String in ["responds", "used_power", "used_relic"]:
		if not meta.get(field) is bool:
			return _fail("Invalid action opportunity metadata")
	if not meta.get("actor") is String or not meta.get("source") is String or not Store.has(world.state.facts, meta.source) or not meta.get("outcome") is String:
		return _fail("Action needs actor, source and explicit outcome")
	if default_choice and (meta.faith_cost != 0 or meta.whispers_cost != 0):
		return _fail("Mandatory default must cost zero resources")
	if int(world.state.awakening) < int(meta.min_awakening) or int(world.state.faith) < int(meta.faith_cost) or int(world.state.whispers) < int(meta.whispers_cost):
		return _fail("Action no longer eligible or affordable")
	if meta.responds and int(context.responses) >= world.catalog.integer("prayer_response_limit"):
		return _fail("Prayer response opportunity already spent")
	if not str(meta.actor).is_empty() and not world.mark_player_task(meta.actor, self):
		return _fail("Person cannot execute another task")
	world.state.faith -= int(meta.faith_cost)
	world.state.whispers -= int(meta.whispers_cost)
	context.responses += 1 if meta.responds else 0
	context.power_used = context.power_used or meta.used_power
	context.relic_used = context.relic_used or meta.used_relic
	world._record("turn_action", "", meta.actor, [], [meta.source], {"faith_cost": meta.faith_cost, "whispers_cost": meta.whispers_cost, "outcome": meta.outcome})
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

func _resolve_event(id: String, action_name: String, default_choice: bool) -> bool:
	for event: Dictionary in context.events:
		if event.id == id:
			if event.resolved:
				return _fail("Event already resolved")
			if not _invoke(event.participant, "events", {"operation": "resolve_event", "action": action_name, "payload": event.payload, "event": id, "source": event.source}, true, default_choice or action_name == event.default_action):
				return false
			event.resolved = true
			return true
	return _fail("Unknown frozen event")

func _valid_effect(id: String, slot: String, value: Variant, depth: int = 0) -> bool:
	if not value is Dictionary or not value.get("type") is String or not value.type in _participants[id].effects:
		return false
	var effect: Dictionary = value
	if effect.type == "economy":
		return _participants[id].instance is Economy and _participants[id].instance.validate_effect(world.state, slot, effect)
	if not effect.get("parents", []) is Array:
		return false
	for parent: Variant in effect.get("parents", []):
		if not parent is String or not Store.has(world.state.facts, parent):
			return false
	if effect.type == "schedule":
		var job: Variant = effect.get("job")
		return job is Dictionary and job.get("id") is String and not str(job.id).is_empty() and _valid_job_time(job) and job.phase in _participants[id].slots and job.get("action") is String and not str(job.action).is_empty() and job.get("payload") is Dictionary and Store.has(world.state.facts, job.get("source", ""))
	if not effect.get("source") is String or not Store.has(world.state.facts, effect.source) or not effect.get("parents", []) is Array:
		return false
	for parent: Variant in effect.get("parents", []):
		if not parent is String or not Store.has(world.state.facts, parent):
			return false
	match effect.type:
		"world_command":
			var command: Variant = effect.get("command")
			if not command is Dictionary or not command.get("kind", "") in ["status", "migrate", "nominate", "population", "establish_cult", "economy_qualification"] or not command.get("parents") is Array:
				return false
			for parent: Variant in command.parents:
				if not parent is String or not Store.has(world.state.facts, parent):
					return false
			if command.kind == "status":
				return command.get("npc") is String and Store.has(world.state.npcs, command.npc) and command.get("status", "") in World.STATUSES
			if command.kind == "migrate":
				return command.get("npc") is String and Store.has(world.state.npcs, command.npc) and command.get("domain") is String and world.state.domains.has(command.domain)
			if command.kind in ["population", "establish_cult", "economy_qualification"]:
				return world.valid_economy_command(command)
			return command.get("domain") is String and world.state.domains.has(command.domain) and command.get("profile") is String and world.catalog.tables.npc_profiles.has(command.profile) and command.get("group", "") in ["unnamed_nonfollowers", "unnamed_followers"] and command.get("institution", "") is String
		"fact":
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
				if not Store.has(world.state.npcs, target) and not Store.has(world.state.relics, target) and not world.state.anchors.has(target) and not world.state.institutions.has(target) and not (effect.kind == "exception_confirmation_authorized" and Store.has(world.state.facts, target) and Store.entry(world.state.facts, target).kind == "exception"):
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

func _effect(id: String, slot: String, effect: Dictionary, depth: int = 0, inherited_parents: Array = []) -> bool:
	if not effect.get("type") is String or not effect.type in _participants[id].effects:
		return _fail("Undeclared or unknown effect")
	var kind: String = effect.type
	if kind == "economy":
		return _participants[id].instance.commit(world, effect, self)
	if kind == "schedule":
		return _schedule(id, effect.get("job"), inherited_parents + effect.get("parents", []))
	if not effect.get("source") is String or not Store.has(world.state.facts, effect.source):
		return _fail("Effect has no valid causal source")
	var source: String = effect.source
	var parents: Array = world._unique_sorted([source] + effect.get("parents", []) + inherited_parents)
	match kind:
		"world_command":
			if not effect.get("command") is Dictionary:
				return _fail("Invalid world command")
			var command: Dictionary = effect.command.duplicate(true)
			command.parents = world._unique_sorted(command.get("parents", []) + parents)
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
				if not nested is Dictionary or not _effect(id, slot, nested, depth + 1, [check_fact]):
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
		if not _invoke(job.participant, phase, {"operation": "due", "action": job.action, "payload": job.payload, "source": job.source}, false, false, batches, true):
			return false
		batches.back()["job"] = job
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
				if not _effect(job.participant, phase, effect, 0, [job.source]):
					return false
	if not due.is_empty():
		_transaction.touch_context(["completed_jobs"])
	for job: Dictionary in due:
		_transaction.new_completed.append(job.id)
		world.history.consume_job(job)
		Store.put(context.completed_jobs, job.id, {"turn": context.turn, "phase": phase, "source": job.source, "participant": job.participant})
		context.queued = context.queued.filter(func(item: Dictionary) -> bool: return item.id != job.id)
	return true

func _due_profile(effects: Array) -> Dictionary:
	var profile: Dictionary = {"check": false, "identity": false, "death": false, "ordinary": false, "targets": []}
	for effect: Dictionary in effects:
		if effect.type == "check":
			profile.check = true
			for branch: Array in effect.branches.values():
				var nested: Dictionary = _due_profile(branch)
				profile.identity = profile.identity or nested.identity
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
	var restored_sequence: Variant = body.get("commit_sequence", Store.size(body.context.receipts))
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
	if int(value.turn) > 0:
		for slot: String in REQUIRED:
			if not _owners.has(slot):
				errors.append("Started session lacks a required capability")
	if not Economy.valid_phase(world_state, value):
		errors.append("Economy receipts disagree with turn phase")
	var internal: String = "actions" if value.phase in ["events", "actions", "evolution"] else "between"
	if world_state.phase != internal or int(world_state.whispers) > int(value.whispers_budget) or int(value.whispers_budget) > world.catalog.integer("whisper_cap") or int(value.responses) > world.catalog.integer("prayer_response_limit"):
		errors.append("World clock or budget differs from coordinator")
	if not value.outcome in ["", "extinction", "awakened"] or (value.phase == "ended") != (not str(value.outcome).is_empty()):
		errors.append("Ending state differs from phase")
	var expected: int = {"between": 6, "events": 1, "actions": 2, "evolution": 3, "settlement": 4, "ending": 5, "ended": 6}[value.phase]
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
		if not (Store.size(value.journal) == 0) or value.phase != "between":
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
	if int(value.turn) > 0 and value.phase in ["evolution", "settlement", "ending", "between", "ended"] and World.canonical(value.plans) != World.canonical(value.locked_plans):
		errors.append("Locked plans differ after action closure")
	if value.events.size() > world.catalog.integer("major_event_limit") or (int(value.turn) == 0 and not value.events.is_empty()):
		errors.append("Frozen event count is invalid")
	var ids: Dictionary = {}
	for event: Variant in value.events:
		if not event is Dictionary or not event.get("id") is String or str(event.id).is_empty() or ids.has(event.id) or not _participants.has(event.get("participant", "")) or not event.get("resolved") is bool or not event.get("payload") is Dictionary or not event.get("default_action") is String or str(event.default_action).is_empty() or not Store.has(world_state.facts, event.get("source", "")):
			errors.append("Invalid frozen event")
		else:
			ids[event.id] = true
			if not "events" in _participants[event.participant].slots or (value.phase != "events" and not event.resolved):
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
			if int(job.due) < int(value.turn) or (int(job.due) == int(value.turn) and (job.phase == "start" or not value.phase in ["events", "actions", "evolution", "settlement"])):
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
	var phase_receipts: Dictionary = {}
	if not trusted.is_empty() and Store.size(value.receipts) != Store.size(trusted.receipts) + 1:
		errors.append("Transaction must append exactly one durable receipt")
	for id: String in (Store.keys(value.receipts) if trusted.is_empty() else _transaction.new_receipts):
		if not _plain(Store.entry(value.receipts, id)) or not _valid_receipt(id, Store.entry(value.receipts, id), value):
			errors.append("Invalid request receipt")
		else:
			var receipt: Dictionary = Store.entry(value.receipts, id)
			if not trusted.is_empty() and (receipt.request.turn != trusted.turn or receipt.request.phase != trusted.phase or receipt.response.turn != value.turn or receipt.response.phase != value.phase):
				errors.append("New receipt does not connect the committed and candidate cursors")
			if receipt.request.op in ["advance", "finish_events", "end_actions"]:
				var phase_number: int = {"events": 1, "actions": 2, "evolution": 3, "settlement": 4, "ending": 5, "between": 6, "ended": 6}[receipt.response.phase]
				var key: String = "%d/%d" % [receipt.response.turn, phase_number]
				if phase_receipts.has(key):
					errors.append("Duplicate phase completion receipts")
				phase_receipts[key] = true
	for index: int in range(journal_start, Store.size(value.journal)):
		var entry: Variant = Store.entry(value.journal, index)
		if entry is Dictionary and entry.get("turn") is int and entry.get("phase") is int and not phase_receipts.has("%d/%d" % [entry.turn, entry.phase]):
			errors.append("Completed phase has no durable request receipt")
	return errors

func _valid_receipt(id: String, receipt: Variant, saved: Dictionary) -> bool:
	if id.is_empty() or not receipt is Dictionary or not receipt.get("request") is Dictionary or receipt.request.get("id") != id or not receipt.get("response") is Dictionary or receipt.response.get("ok") != true or not receipt.get("fingerprint") is String or receipt.fingerprint != World.canonical(receipt.request).sha256_text():
		return false
	var request: Dictionary = receipt.request
	var response: Dictionary = receipt.response
	if not request.get("turn") is int or int(request.turn) < 0 or not request.get("phase", "") in PHASES or not response.get("turn") is int or int(response.turn) < 1 or int(response.turn) > int(saved.turn) or not response.get("phase", "") in PHASES or not response.get("result") is Dictionary or not response.result.get("checks") is Array or not response.result.get("outcome", "INVALID") in ["", "extinction", "awakened"]:
		return false
	var allowed_keys: Dictionary = {"advance": [], "finish_events": [], "resolve_event": ["event", "action"], "act": ["participant", "action", "payload"], "set_plan": ["participant", "payload"], "end_actions": []}
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
		"end_actions":
			if request.phase == "actions": next_phase = "evolution"
		"resolve_event":
			if request.phase == "events" and request.get("event") is String and not str(request.event).is_empty() and request.get("action") is String and not str(request.action).is_empty(): next_phase = "events"
		"act", "set_plan":
			if request.phase == "actions" and _participants.has(request.get("participant", "")) and request.get("payload", {}) is Dictionary:
				if (request.op == "set_plan" and request.get("payload") is Dictionary) or (request.op == "act" and "actions" in _participants[request.participant].slots and request.get("action") is String and not str(request.action).is_empty()): next_phase = "actions"
	if next_phase.is_empty() or response.phase != next_phase or response.turn != next_turn or (response.phase == "ended") != (response.result.outcome != ""):
		return false
	if response.phase == "ended" and (saved.phase != "ended" or response.turn != saved.turn or response.result.outcome != saved.outcome):
		return false
	if saved.phase == "ended" and response.turn == saved.turn and request.op == "advance" and request.phase == "ending" and response.phase != "ended":
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
	return {"schema": 2, "sequence": commit_sequence, "index_sequence": commit_sequence, "content": world.catalog.version, "engine": Engine.get_version_info().string, "participants": capabilities(), "world": {"schema": World.SCHEMA_VERSION, "content": world.catalog.version, "engine": Engine.get_version_info().string, "state": world.state, "randoms": streams, "stats": world.stats}, "context": context}

func _adopt_archive(checkpoint: Dictionary) -> bool:
	if checkpoint.get("schema") != 2 or checkpoint.get("index_sequence") != checkpoint.get("sequence") or not checkpoint.get("world") is Dictionary or not checkpoint.get("context") is Dictionary: return _fail("Invalid archive checkpoint")
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
