extends RefCounted
## Formal resistance binds the existing World producer to a saved capability.
## World remains the sole effect writer; Events owns only its original handoffs.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const ID: String = "resistance"
const SCHEMA: int = 1
var catalog: RefCounted
var version: String

func _init(content: RefCounted) -> void:
	catalog = content
	version = rule_version(content)

static func rule_version(content: RefCounted) -> String:
	return "1/" + content.version

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("resistance_system") or not turn.world.state.has("event_system"): return false
	for domain: Dictionary in turn.world.state.domains.values():
		if not domain.pending_plan.is_empty(): return false
	var breaches: Dictionary = {}
	for domain: Dictionary in turn.world.state.domains.values(): breaches[domain.id] = int(domain.barrier) <= catalog.integer("first_breach_threshold")
	turn.world.state["resistance_system"] = {"schema": SCHEMA, "version": version, "breaches": breaches, "breach_sources": {}}
	refresh_breaches(turn.world)
	if not turn.register_participant(ID, version, ["resistance_start"], [], handle):
		turn.world.state.erase("resistance_system")
		return false
	return turn.world.ensure_history(true)

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	return {"ok": input.get("slot") == "resistance_start" and view.world.get("resistance_system", {}).get("version") == version, "empty": true, "effects": [], "state": {}}

func preview(turn: RefCounted) -> Dictionary:
	if turn._in_transaction or turn._in_participant or turn.world.state.get("resistance_system", {}).get("version") != version: return {"ok": false}
	var plans: Array = []
	var ids: Array = turn.world.state.domains.keys()
	ids.sort()
	for id: String in ids:
		var plan: Dictionary = turn.world.state.domains[id].pending_plan
		if not plan.is_empty(): plans.append(plan.duplicate(true))
	return {"ok": true, "plans": plans}

static func sources_valid(state: Dictionary, sources: Array) -> bool:
	if sources.is_empty(): return false
	for source: Variant in sources:
		if not source is String or not Store.has(state.facts, source) or Store.has(state.invalid_records, source): return false
	return true

static func usable_confirmations(_state: Dictionary, evidence: Dictionary, index: RefCounted) -> Array:
	var current: Dictionary = index.sources("resistance_confirmations/" + str(evidence.institution) + "|" + str(evidence.subject))
	return [] if History.size(current) == 0 else [str(History.at(current, History.size(current) - 1).key)]

static func basis_valid(state: Dictionary, plan: Dictionary) -> bool:
	if not sources_valid(state, plan.parents): return false
	if plan.rule == "RESIST_REPAIR": return true
	var subject: String = str(plan.get("evidence_subject", ""))
	if subject.is_empty(): return false
	if plan.rule == "RESIST_TRACE": return subject == plan.target
	var key: String = str(plan.institution) + "|" + subject
	if not Store.has(state.evidence, key): return false
	var confirmations: Variant = Store.entry(state.evidence, key).confirmations
	for source: String in plan.parents:
		if not History.has(confirmations, source) or not sources_valid(state, Store.entry(state.facts, source).causal_parents): return false
	if plan.rule == "RESIST_PURGE":
		if not Store.has(state.npcs, subject): return false
		var npc: Dictionary = Store.entry(state.npcs, subject)
		return npc.status == "active" and npc.domain == plan.domain and npc.get("cult_id", "") == plan.target
	if plan.rule == "RESIST_ERASE":
		var anchor: Dictionary = state.anchors.get(plan.target, {})
		return not anchor.is_empty() and subject in [anchor.guardian, anchor.relic]
	return subject == plan.target

static func refresh_breaches(world: RefCounted, domain_id: String = "", trigger: String = "") -> void:
	if not world.state.has("resistance_system"): return
	world.stage_collections(["resistance_system"])
	for domain: Dictionary in ([world.state.domains[domain_id]] if world.state.domains.has(domain_id) else world.state.domains.values()):
		var before: bool = world.state.resistance_system.breaches[domain.id]
		if int(domain.barrier) <= world.catalog.integer("first_breach_threshold"): world.state.resistance_system.breaches[domain.id] = true
		elif int(domain.barrier) >= world.catalog.integer("breach_close_threshold"): world.state.resistance_system.breaches[domain.id] = false
		var prior: String = world.state.resistance_system.breach_sources.get(domain.id, "")
		if prior.is_empty() or before != world.state.resistance_system.breaches[domain.id]:
			var cause: String = trigger if not trigger.is_empty() else str(domain.barrier_source)
			var source: String = world._record("resistance_breach", domain.id, "", [domain.id], [cause] if prior.is_empty() else [cause, prior], {"open": world.state.resistance_system.breaches[domain.id], "barrier": domain.barrier, "previous": prior, "initial": prior.is_empty()})
			world.state.resistance_system.breach_sources[domain.id] = source

static func validate_state(state: Dictionary, content: RefCounted, index: RefCounted = null) -> Array[String]:
	if not state.has("resistance_system"): return []
	var ledger: Variant = state.resistance_system
	if not ledger is Dictionary or ledger.size() != 4 or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content) or not state.has("event_system") or not ledger.get("breaches") is Dictionary or ledger.breaches.size() != state.domains.size() or not ledger.get("breach_sources") is Dictionary or ledger.breach_sources.size() != state.domains.size(): return ["Invalid resistance capability"]
	var latest: Dictionary = {}
	if index == null:
		for fact: Dictionary in Store.values(state.facts):
			if fact.kind == "resistance_breach" and str(fact.id) > str(latest.get(fact.domain, "")): latest[fact.domain] = fact.id
	for domain: Dictionary in state.domains.values():
		if not ledger.breaches.get(domain.id) is bool: return ["Missing resistance breach state"]
		if (int(domain.barrier) <= content.integer("first_breach_threshold") and not ledger.breaches[domain.id]) or (int(domain.barrier) >= content.integer("breach_close_threshold") and ledger.breaches[domain.id]): return ["Resistance breach contradicts barrier"]
		var source: String = str(ledger.breach_sources.get(domain.id, ""))
		var breach: Dictionary = Store.entry(state.facts, source, {})
		var head: String = str(History.mapget(index.data.get("resistance_breaches", History.from_value({}, "map")), domain.id, "")) if index != null else str(latest.get(domain.id, ""))
		if source != head or breach.get("kind") != "resistance_breach" or breach.get("domain") != domain.id or breach.get("changes", {}).get("open") != ledger.breaches[domain.id]: return ["Resistance breach history mismatch"]
		var crossing: Dictionary = breach.changes
		if not crossing.get("barrier") is int or not crossing.get("initial") is bool or not crossing.get("previous") is String: return ["Invalid resistance crossing"]
		if crossing.initial:
			if not crossing.previous.is_empty() or breach.turn != 0 or crossing.open != (crossing.barrier <= content.integer("first_breach_threshold")): return ["Invalid initial resistance crossing"]
		elif (crossing.open and crossing.barrier > content.integer("first_breach_threshold")) or (not crossing.open and crossing.barrier < content.integer("breach_close_threshold")) or not crossing.previous in breach.causal_parents: return ["Invalid resistance crossing threshold"]
		var plan: Variant = domain.get("pending_plan", {})
		if not plan is Dictionary: return ["Invalid fixed resistance plan"]
		if plan.is_empty(): continue
		if not content.tables.resistance_plans.has(plan.get("rule", "")) or not plan.get("parents") is Array or not plan.get("due") is int or not plan.get("evidence_subject") is String: return ["Invalid fixed resistance plan"]
		var fact: Variant = Store.entry(state.facts, str(plan.get("started_fact", "")), {})
		var rule: Dictionary = content.tables.resistance_plans[plan.rule]
		var effect: Dictionary = content.tables.civilization_actions[plan.rule]
		if fact.get("kind") != "resistance_started" or fact.get("domain") != domain.id or plan.get("domain") != domain.id or fact.get("targets") != [plan.get("target")] or fact.get("causal_parents") != plan.parents: return ["Resistance announcement identity mismatch"]
		if plan.due != int(fact.turn) + int(rule.warning_turns) or plan.get("institution") != domain.id + "/" + str(effect.institution_role) or plan.get("default_effect") != effect: return ["Resistance announcement timing or effect mismatch"]
		if fact.changes != {"plan": plan.rule, "due": plan.due, "institution": plan.institution, "default_effect": plan.default_effect, "evidence_subject": plan.evidence_subject}: return ["Resistance announcement changed after fixation"]
	return []
