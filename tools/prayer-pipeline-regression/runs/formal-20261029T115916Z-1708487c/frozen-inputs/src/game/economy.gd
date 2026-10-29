extends RefCounted
const EventRules = preload("res://src/game/event_rules.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Cults = preload("res://src/game/cults.gd")
const Attention = preload("res://src/game/attention.gd")
const AbstractSim = preload("res://src/simulation/abstract_sim.gd")
const Store = preload("res://src/simulation/archive_store.gd")
## Production economy. Authored values come only from Catalog; upstream proofs are
## explicitly versioned capabilities, never inferred from a test's reward number.
const ID: String = "economy"
const SCHEMA: int = 1
const RATE_SCALE: int = 1000000
const ATTRITION_UNIT: int = RATE_SCALE * 100
const STRATEGIES: Array[String] = ["expand", "conceal", "hold"]
var attention: RefCounted
var catalog: RefCounted
var issuers: Dictionary
var last_error: String = ""

func _init(content: RefCounted, accepted_issuers: Dictionary = {}) -> void:
	catalog = content
	attention = Attention.new(content, AbstractSim.new(content))
	issuers = accepted_issuers.duplicate(true)

func initialize(world: RefCounted, owner: Object = null) -> bool:
	if not world._driver_allowed(owner) or world.state.turn != 0 or world.state.phase != "between" or world.catalog.version != catalog.version:
		return false
	for id: Variant in issuers:
		if not id is String or id.is_empty() or not issuers[id] is String or str(issuers[id]).is_empty():
			return false
	if world.state.has("economy"):
		return world.state.economy.issuers == issuers and validate_state(world.state, catalog).is_empty()
	var ledger: Dictionary = {"schema": SCHEMA, "issuers": issuers.duplicate(true), "turn": 0, "eligible": {}, "cohort_sources": {}, "round_cults": {}, "remainders": {}, "effective": {}, "paid": {}, "prepay_turn": -1, "income_turn": -1, "prepay_source": "", "income_sources": {}}
	world.state["economy"] = ledger
	world.state["economy_qualifications"] = {}
	if not validate_state(world.state, catalog).is_empty():
		world.state.erase("economy")
		world.state.erase("economy_qualifications")
		return false
	return true

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or not (Store.size(turn.context.receipts) == 0):
		return false
	for slot: String in ["round_start", "prepay", "evolution", "income"]:
		if turn._owners.has(slot):
			return false
	if not initialize(turn.world, turn):
		return false
	var version: String = "1/" + JSON.stringify(issuers, "", true, true).sha256_text()
	return turn.register_participant(ID, version, ["round_start", "prepay", "evolution", "income"], ["economy"], handle, validate_plan)

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	var effect: Dictionary = {"type": "economy", "operation": input.slot}
	if input.slot == "prepay":
		effect["plan"] = view.turn.locked_plans.get(ID, {})
	if input.slot == "evolution":
		effect["batch"] = build_batch(view.world, view.get("reader"))
	return {"ok": true, "empty": false, "effects": [effect], "state": {}}

func preview_rest(state: Dictionary, cursor: Dictionary) -> Dictionary:
	if not state.has("economy") or state.economy.issuers != issuers or cursor.get("phase") != "actions": return _error("Rest is only available in the action phase")
	if int(cursor.get("responses", 0)) != 0 or cursor.get("power_used", false) or cursor.get("relic_used", false): return _error("Rest requires an unused prayer, power and relic window")
	if int(state.wounds) <= 0: return _error("There are no wounds to recover")
	var fee: int = catalog.integer("rest_faith_cost")
	if int(state.faith) < fee: return _error("Insufficient faith for rest")
	return {"ok": true, "faith_cost": fee, "wounds_recovered": mini(int(state.wounds), catalog.integer("rest_wound_recovery")), "ends_actions": true}

func rest(world: RefCounted, owner: RefCounted, request_id: String) -> bool:
	if not world._driver_allowed(owner): return false
	var result: Dictionary = preview_rest(world.state, owner.context)
	var key: String = "economy/rest/" + request_id
	if not result.ok or Store.has(world.state.applied_authorizations, key): return false
	world.stage_collections(["applied_authorizations"])
	var data: Dictionary = {"request": request_id, "faith_before": world.state.faith, "wounds_before": world.state.wounds, "faith_cost": result.faith_cost, "recovered": result.wounds_recovered, "responses": owner.context.responses, "power_used": owner.context.power_used, "relic_used": owner.context.relic_used}
	world.state.faith -= result.faith_cost; world.state.wounds -= result.wounds_recovered
	var source: String = world._record("economy_rest", "", "", [], [], data)
	Store.put(world.state.applied_authorizations, key, source)
	return true

static func valid_rest_receipt(state: Dictionary, request: Dictionary, content: RefCounted) -> bool:
	var source: String = Store.entry(state.applied_authorizations, "economy/rest/" + str(request.id), "")
	var fact: Dictionary = Store.entry(state.facts, source, {})
	if fact.get("kind") != "economy_rest" or fact.get("turn") != request.turn: return false
	var data: Dictionary = fact.changes
	return data.get("request") == request.id and data.get("faith_before") is int and data.faith_before >= content.integer("rest_faith_cost") and data.get("wounds_before") is int and data.wounds_before > 0 and data.get("faith_cost") == content.integer("rest_faith_cost") and data.get("recovered") == mini(int(data.wounds_before), content.integer("rest_wound_recovery")) and data.get("responses") == 0 and data.get("power_used") == false and data.get("relic_used") == false

func validate_plan(view: Dictionary, plan: Dictionary) -> Dictionary:
	for key: Variant in plan:
		if not str(key) in ["strategies", "anchor_priority", "refuse_anchors"]:
			return _error("Unknown economy plan field")
	if not plan.get("strategies", {}) is Dictionary or not plan.get("anchor_priority", []) is Array or not plan.get("refuse_anchors", []) is Array:
		return _error("Invalid economy plan shape")
	for id: Variant in plan.get("strategies", {}):
		if not id is String or not view.world.cults.has(id) or not plan.strategies[id] in STRATEGIES:
			return _error("Unknown cult or strategy")
	for field: String in ["anchor_priority", "refuse_anchors"]:
		var seen: Dictionary = {}
		for id: Variant in plan.get(field, []):
			if not id is String or not view.world.anchors.has(id) or seen.has(id):
				return _error("Unknown or repeated anchor")
			seen[id] = true
	return preview(view.world, plan, view.get("reader"))

func preview(state: Dictionary, plan: Dictionary, index: RefCounted = null) -> Dictionary:
	if not state.has("economy") or state.economy.issuers != issuers:
		return _error("Economy or upstream capabilities unavailable")
	if Attention.enabled(state) and attention.version != state.attention.policy: return _error("Economy admission policy mismatch")
	var focus: Array = attention.occupied(state, "focus") if Attention.enabled(state) else []
	var focused_strategy: bool = Attention.enabled(state) and attention.policies["strategy/proselytize/plan"].focus_scope != "none"
	var balance: int = state.faith
	var cults: Array = []
	for id: String in _keys(state.cults):
		var cult: Dictionary = state.cults[id]
		var strategy: String = plan.get("strategies", {}).get(id, cult.get("strategy", "hold"))
		var effective: String = strategy
		var reason: String = operational_reason(state, cult, catalog)
		var fee: int = 0
		var growth: int = 0
		var source: String = cult.established_source
		if not reason.is_empty():
			effective = "hold"
		elif strategy == "expand":
			var permission: Dictionary = qualification(state, "propagation", id, index)
			if not permission.ok:
				return permission
			source = permission.source
			if PrayerRules.blocked(state, cult.leader, "propagation"):
				reason = "prayer_propagation_restricted"
			elif not permission.allowed:
				reason = permission.reason
			elif state.domains[cult.domain].unnamed_nonfollowers == 0:
				reason = "no_recruitable_population"
			elif balance < catalog.integer("expansion_faith_cost"):
				reason = "insufficient_faith"
			elif focused_strategy and not cult.domain in focus and focus.size() >= int(attention.parameters.focused_domain_limit):
				reason = "attention_focus_capacity"
			else:
				if focused_strategy and not cult.domain in focus: focus.append(cult.domain)
				fee = catalog.integer("expansion_faith_cost")
				growth = mini(int(state.domains[cult.domain].unnamed_nonfollowers), catalog.integer("expansion_base_growth") + int(Store.entry(state.npcs, cult.leader).influence) / catalog.integer("expansion_influence_divisor"))
				balance -= fee
			if not reason.is_empty():
				effective = "hold"
		var attrition: Dictionary = attrition_for(state, cult, catalog)
		var eligible: int = int(state.economy.eligible.get(cult.domain, state.domains[cult.domain].unnamed_followers))
		var income_window: bool = state.turn == 0 or (state.economy.round_cults.get(id, "") == cult.established_source and int(cult.established_turn) < int(state.turn))
		var after_known_loss: int = maxi(0, eligible - int(attrition.loss))
		var income: int = income_amount(after_known_loss, int(cult.cohesion), effective, catalog) if income_window and operational_reason(state, cult, catalog).is_empty() else 0
		cults.append({"cult": id, "intent": strategy, "effective": effective, "reason": reason, "fee": fee, "growth": growth, "attrition": attrition.loss, "remainder_units": attrition.remainder, "income_basis_now": eligible, "income_basis_after_work": after_known_loss, "income_if_unchanged": income, "source": source})
	var order: Array = plan.get("anchor_priority", []).duplicate()
	for id: String in _keys(state.anchors):
		if not id in order:
			order.append(id)
	var anchors: Array = []
	for id: String in order:
		var anchor: Dictionary = state.anchors[id]
		var reason: String = ""
		var fee: int = 0
		var source: String = anchor.get("origin", "")
		if id in plan.get("refuse_anchors", []):
			reason = "explicit_refusal"
		else:
			var valid: Dictionary = anchor_eligibility(state, anchor, catalog, index)
			if not valid.ok:
				return valid
			reason = valid.reason
			source = valid.source
			if reason.is_empty():
				fee = catalog.integer("anchor_" + str(state.domains[anchor.domain].tier) + "_upkeep")
				if balance < fee:
					fee = 0
					reason = "insufficient_faith"
				else:
					balance -= fee
		anchors.append({"anchor": id, "fee": fee, "reason": reason, "source": source, "expected": "paid_pending_final_check" if reason.is_empty() else "dormant", "known_plan": state.domains[anchor.domain].pending_plan.duplicate(true)})
	return {"ok": true, "preview": {"cults": cults, "anchors": anchors, "faith_before": state.faith, "faith_after_prepay": balance, "capacity": capacity(state, catalog), "conditional": "Income and paid anchor activation still depend on shared evolution and revalidation; future income is unavailable for prepay."}}

func validate_effect(state: Dictionary, slot: String, effect: Dictionary) -> bool:
	if effect.get("operation") != slot or not slot in ["round_start", "prepay", "evolution", "income"] or not state.has("economy") or state.economy.issuers != issuers:
		return false
	if slot == "prepay":
		return effect.get("plan") is Dictionary and validate_plan({"world": state}, effect.plan).ok
	if slot == "evolution":
		return effect.get("batch") is Dictionary and JSON.stringify(effect.batch, "", true, true) == JSON.stringify(build_batch(state), "", true, true)
	return true

func commit(world: RefCounted, effect: Dictionary, owner: Object) -> bool:
	if not world._driver_allowed(owner):
		return false
	world.stage_collections(["economy", "cults", "anchors"] if effect.operation == "prepay" else ["economy"])
	var state: Dictionary = world.state
	var ledger: Dictionary = state.economy
	match effect.operation:
		"round_start":
			if ledger.turn >= state.turn:
				return false
			ledger.turn = state.turn
			ledger.eligible = {}
			ledger.cohort_sources = {}
			ledger.round_cults = {}
			ledger.effective = {}
			ledger.paid = {}
			ledger.income_sources = {}
			for domain_id: String in _keys(state.domains):
				var domain: Dictionary = state.domains[domain_id]
				ledger.eligible[domain.id] = domain.unnamed_followers
				ledger.cohort_sources[domain.id] = world._record("economy_income_cohort", domain.id, "", [], [domain.get("population_source", domain.origin)], {"eligible": domain.unnamed_followers, "turn": state.turn})
			for cult: Dictionary in state.cults.values():
				if cult.status != "destroyed" and int(cult.established_turn) < int(state.turn):
					ledger.round_cults[cult.id] = cult.established_source
			return true
		"prepay":
			if ledger.turn != state.turn or ledger.prepay_turn >= state.turn:
				return false
			var result: Dictionary = validate_plan({"world": state}, effect.plan)
			if not result.ok:
				return false
			var causes: Array = []
			for row: Dictionary in result.preview.cults:
				state.faith -= row.fee
				state.cults[row.cult]["strategy"] = row.intent
				ledger.effective[row.cult] = row.effective
				var fact: String = world._record("economy_strategy_payment", state.cults[row.cult].domain, "", [], [row.source, state.cults[row.cult].established_source], row)
				if state.has("cult_system") and not Cults.record_payment(world, state.cults[row.cult].domain, row.fee, fact): return false
				causes.append(fact)
			for row: Dictionary in result.preview.anchors:
				state.faith -= row.fee
				var anchor: Dictionary = state.anchors[row.anchor]
				var fact: String = world._record("economy_anchor_payment", anchor.domain, "", [row.anchor], [row.source] if not row.source.is_empty() else [state.domains[anchor.domain].origin], row)
				if state.has("cult_system") and not Cults.record_payment(world, anchor.domain, row.fee, fact): return false
				causes.append(fact)
				if row.reason.is_empty():
					ledger.paid[row.anchor] = fact
				elif not anchor.state in ["absent", "destroyed"]:
					anchor.state = "dormant"
			ledger.prepay_source = world._record("economy_prepay", "", "", [], world._unique_sorted(causes), {"turn": state.turn, "faith_after": state.faith})
			ledger.prepay_turn = state.turn
			return true
		"income":
			if ledger.prepay_turn != state.turn or ledger.income_turn >= state.turn or state.phase != "between":
				return false
			for id: String in _keys(state.cults):
				var cult: Dictionary = state.cults[id]
				var eligible: int = int(ledger.eligible.get(cult.domain, 0))
				var reason: String = operational_reason(state, cult, catalog)
				if ledger.round_cults.get(id, "") != cult.established_source or int(cult.established_turn) >= int(state.turn):
					reason = "established_this_turn"
				var gross: int = income_amount(eligible, int(cult.cohesion), ledger.effective.get(id, "hold"), catalog) if reason.is_empty() else 0
				var actual: int = mini(gross, maxi(0, capacity(state, catalog) - int(state.faith)))
				state.faith += actual
				ledger.income_sources[id] = world._record("economy_income", cult.domain, "", [], [cult.established_source, ledger.prepay_source, ledger.cohort_sources[cult.domain]], {"cult": id, "eligible": eligible, "cohesion": cult.cohesion, "strategy": ledger.effective.get(id, "hold"), "gross": gross, "actual": actual, "overflow": gross - actual, "reason": reason})
			ledger.income_turn = state.turn
			return true
	return false

func build_batch(state: Dictionary, index: RefCounted = null) -> Dictionary:
	var entries: Array = []
	for id: String in _keys(state.cults):
		var cult: Dictionary = state.cults[id]
		if cult.status == "destroyed":
			continue
		var strategy: String = state.economy.effective.get(id, "hold")
		var growth: int = 0
		var alert: int = 0
		var source: String = cult.established_source
		if operational_reason(state, cult, catalog).is_empty():
			if strategy == "expand":
				var permission: Dictionary = qualification(state, "propagation", id, index)
				if permission.ok and permission.allowed and not PrayerRules.blocked(state, cult.leader, "propagation"):
					source = permission.source
					growth = mini(int(state.domains[cult.domain].unnamed_nonfollowers), catalog.integer("expansion_base_growth") + int(Store.entry(state.npcs, cult.leader).influence) / catalog.integer("expansion_influence_divisor"))
					alert = catalog.integer("expansion_alert") + EventRules.propagation_bonus(state, cult.domain, index) if growth > 0 else 0
			elif strategy == "conceal":
				alert = catalog.integer("conceal_alert")
		var attrition: Dictionary = attrition_for(state, cult, catalog)
		var entry: Dictionary = {"cult": id, "domain": cult.domain, "leader": cult.leader, "growth": growth, "loss": attrition.loss, "remainder": attrition.remainder, "alert": alert, "exposed": growth > 0, "source": source}
		if state.has("event_system") and growth > 0: entry["event_sources"] = EventRules.propagation_sources(state, cult.domain, index)
		entries.append(entry)
	return {"turn": state.turn, "entries": entries}

static func apply_batch(world: RefCounted, batch: Dictionary, owner: Object) -> Dictionary:
	var changes: Dictionary = {}
	for row: Dictionary in batch.get("entries", []):
		var cult: Dictionary = world.state.cults[row.cult]
		var parents: Array = world._unique_sorted([row.source, world.state.economy.prepay_source, cult.established_source] + row.get("event_sources", []))
		var source: String = world._record("economy_work", row.domain, row.leader, [], parents, row)
		if row.loss > 0:
			if not world.submit({"kind": "population", "domain": row.domain, "mode": "leave", "amount": row.loss, "parents": [source]}, owner, true):
				return {"ok": false}
		if row.growth > 0:
			if not world.submit({"kind": "population", "domain": row.domain, "mode": "convert", "amount": row.growth, "parents": [source]}, owner, true):
				return {"ok": false}
			# Growth exposes activity, not an omniscient list of named suspects.
			# Specific witnesses and institution knowledge require their own facts.
			if world.introduce_fact("exposure", row.domain, "", [], [source], {"public": true, "rule": "expansion"}, [], [], owner).is_empty():
				return {"ok": false}
		world.state.economy.remainders[row.cult] = row.remainder
		changes[row.domain] = {"alert": row.alert, "source": source, "exposed": row.exposed}
	return {"ok": true, "changes": changes}

static func refresh_cults(world: RefCounted) -> void:
	if not world.state.has("economy"):
		return
	for cult: Dictionary in world.state.cults.values():
		if cult.status != "destroyed" and (world.state.domains[cult.domain].unnamed_followers == 0 or cult.cohesion == 0):
			cult.status = "destroyed"

static func finalize(world: RefCounted) -> void:
	if not world.state.has("economy"):
		return
	refresh_cults(world)
	for id: String in world.state.economy.paid:
		if not world.state.anchors.has(id):
			continue
		var anchor: Dictionary = world.state.anchors[id]
		var valid: Dictionary = anchor_eligibility(world.state, anchor, world.catalog, world.history)
		anchor.state = "active" if valid.ok and valid.reason.is_empty() else (anchor.state if anchor.state in ["absent", "destroyed"] else "dormant")

static func operational_reason(state: Dictionary, cult: Dictionary, content: RefCounted) -> String:
	if cult.status != "active":
		return "cult_" + str(cult.status)
	if int(cult.cohesion) <= 0 or int(state.domains[cult.domain].unnamed_followers) <= 0:
		return "no_organization_base"
	if not Store.has(state.npcs, cult.leader):
		return "no_leader"
	var leader: Dictionary = Store.entry(state.npcs, cult.leader)
	if (Attention.enabled(state) and not leader.get("bound_member", false)) or leader.status != "active" or leader.domain != cult.domain or int(leader.loyalty) < content.integer("loyalty_follower_threshold"):
		return "leader_unavailable"
	return ""

static func qualification(state: Dictionary, rule: String, subject: String, index: RefCounted = null) -> Dictionary:
	var key: String = rule + "|" + subject
	if not state.get("economy_qualifications", {}).has(key):
		return _error("Missing upstream qualification: " + key)
	var source: String = state.economy_qualifications[key]
	if not state.get("invalid_records") is Dictionary: return _error("Qualification invalidation projection is unavailable")
	if Store.has(state.invalid_records, source): return {"ok": true, "allowed": false, "reason": "propagation_evidence_destroyed", "source": source}
	if not Store.has(state.facts, source):
		return _error("Qualification source is missing")
	var fact: Dictionary = Store.entry(state.facts, source)
	var data: Dictionary = fact.changes
	if fact.kind != "economy_qualification" or data.get("rule") != rule or data.get("subject") != subject or not data.get("allowed") is bool or not state.economy.issuers.has(data.get("issuer", "")) or state.economy.issuers[data.issuer] != data.get("version") or not state.institutions.has(data.get("institution", "")):
		return _error("Incompatible upstream qualification")
	var domain: String = state.cults[subject].domain if rule == "propagation" else state.anchors[subject].domain
	var institution: Dictionary = state.institutions[data.institution]
	if fact.domain != domain or institution.domain != domain or (rule == "anchor" and state.anchors[subject].institution != institution.id):
		return _error("Qualification subject and object disagree")
	if state.has("event_system") and data.get("issuer") == "events" and not EventRules.permit_valid(state, subject, source, index): return {"ok": true, "allowed": false, "reason": "event_permit_no_longer_current", "source": source}
	var operational: bool = institution.active and Store.has(state.npcs, institution.representative) and Store.entry(state.npcs, institution.representative).status == "active" and Store.entry(state.npcs, institution.representative).domain == domain
	return {"ok": true, "allowed": data.allowed and operational, "reason": "upstream_denied" if not data.allowed else ("" if operational else "propagation_object_unavailable"), "source": source}

static func anchor_eligibility(state: Dictionary, anchor: Dictionary, content: RefCounted, index: RefCounted = null) -> Dictionary:
	var source: String = anchor.get("origin", "")
	if anchor.state in ["absent", "destroyed"] or anchor.get("needs_rebind", true):
		return {"ok": true, "reason": "structure_unavailable", "source": source}
	var permission: Dictionary
	if state.has("anchor_system"):
		# Formal institutions use their exact event-result proof, rechecked now.
		# A legacy issuer's allowed=true never substitutes for those conditions.
		permission = Anchors.maintenance(state, anchor.institution, content, index)
	else:
		permission = qualification(state, "anchor", anchor.id)
	if not permission.ok: return permission
	if not permission.allowed:
		return {"ok": true, "reason": permission.reason, "source": permission.source, "missing": permission.get("missing", [])}
	var physical: String = anchor_physical_reason(state, anchor, content)
	return {"ok": true, "reason": physical, "source": permission.source}

static func anchor_physical_reason(state: Dictionary, anchor: Dictionary, content: RefCounted) -> String:
	if not anchor.get("ordinal") is int or not int(anchor.ordinal) in [1, 2, 3] or not state.cults.has(anchor.get("cult", "")):
		return "missing_structure_metadata"
	var cult: Dictionary = state.cults[anchor.cult]
	if cult.domain != anchor.domain or not operational_reason(state, cult, content).is_empty() or int(cult.cohesion) < content.integer("anchor_cohesion_min") or int(state.domains[anchor.domain].unnamed_followers) < content.integer("anchor_followers_min"):
		return "organization_unavailable"
	if int(state.domains[anchor.domain].pollution) < content.integer("anchor_maintain_pollution_" + str(anchor.ordinal)):
		return "pollution_below_threshold"
	if not Store.has(state.npcs, anchor.get("guardian", "")) or not Store.has(state.relics, anchor.get("relic", "")) or not state.institutions.has(anchor.get("institution", "")):
		return "binding_unavailable"
	var guardian: Dictionary = Store.entry(state.npcs, anchor.guardian)
	var relic: Dictionary = Store.entry(state.relics, anchor.relic)
	if (Attention.enabled(state) and not guardian.get("bound_member", false)) or guardian.status != "active" or guardian.domain != anchor.domain or int(guardian.loyalty) < content.integer("loyalty_follower_threshold") or not state.institutions[anchor.institution].active:
		return "guardian_or_institution_unavailable"
	if relic.placement != "bound" or relic.get("anchor", "") != anchor.id or relic.domain != anchor.domain:
		return "binding_unavailable"
	return ""

static func attrition_for(state: Dictionary, cult: Dictionary, content: RefCounted) -> Dictionary:
	var previous: int = int(state.economy.remainders.get(cult.id, 0))
	if cult.status == "destroyed":
		return {"loss": 0, "remainder": previous}
	var rate: int = int(round(content.number("cult_natural_attrition") * RATE_SCALE))
	var units: int = int(state.domains[cult.domain].unnamed_followers) * rate * (100 - int(cult.cohesion)) + previous
	return {"loss": units / ATTRITION_UNIT, "remainder": units % ATTRITION_UNIT}

static func income_amount(eligible: int, cohesion: int, strategy: String, content: RefCounted) -> int:
	var raw: float = minf(content.number("cult_income_cap"), sqrt(float(eligible))) * float(cohesion) / 100.0
	if strategy == "conceal":
		raw *= content.number("conceal_income_multiplier")
	return int(floor(raw))

static func capacity(state: Dictionary, content: RefCounted) -> int:
	return content.integer("faith_capacity_base") + int(state.peak_awakening) * content.integer("faith_capacity_per_peak_awakening")

static func _error(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

static func _keys(values: Dictionary) -> Array:
	var result: Array = Store.keys(values)
	result.sort()
	return result

static func validate_state(state: Dictionary, content: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("economy"):
		return errors
	var ledger: Variant = state.economy
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or not ledger.get("issuers") is Dictionary or not state.get("economy_qualifications") is Dictionary:
		return ["Invalid economy schema"]
	for field: String in ["eligible", "cohort_sources", "round_cults", "remainders", "effective", "paid", "income_sources"]:
		if not ledger.get(field) is Dictionary:
			errors.append("Missing economy collection")
	for field: String in ["turn", "prepay_turn", "income_turn"]:
		if not ledger.get(field) is int:
			errors.append("Invalid economy clock")
	if not ledger.get("prepay_source") is String:
		errors.append("Invalid economy source")
	if not errors.is_empty():
		return errors
	if int(ledger.turn) != int(state.turn) or int(ledger.prepay_turn) > int(state.turn) or int(ledger.income_turn) > int(state.turn):
		errors.append("Economy clock mismatch")
	for id: Variant in ledger.issuers:
		if not id is String or id.is_empty() or not ledger.issuers[id] is String or str(ledger.issuers[id]).is_empty():
			errors.append("Invalid upstream capability registry")
	for id: String in ledger.eligible:
		if not state.domains.has(id) or not ledger.eligible[id] is int or int(ledger.eligible[id]) < 0 or int(ledger.eligible[id]) > int(state.domains[id].unnamed_followers):
			errors.append("Income cohort exceeds actual followers")
	if int(state.turn) > 0 and ledger.eligible.size() != state.domains.size():
		errors.append("Missing income cohort")
	for id: String in ledger.eligible:
		if not Store.has(state.facts, ledger.cohort_sources.get(id, "")):
			errors.append("Missing income cohort cause")
		else:
			var fact: Dictionary = Store.entry(state.facts, ledger.cohort_sources[id])
			var actual: Variant = null
			if fact.kind == "economy_income_cohort":
				actual = fact.changes.get("eligible")
			elif fact.changes.get("eligible_after") is Dictionary:
				actual = fact.changes.eligible_after.get(id)
			if not fact.kind in ["economy_income_cohort", "population_transfer", "nomination"] or fact.turn != state.turn or not actual is int or actual != ledger.eligible[id]:
				errors.append("Income cohort contradicts its recorded population flow")
	for domain: Dictionary in state.domains.values():
		if domain.has("population_source") and not Store.has(state.facts, domain.population_source):
			errors.append("Unknown population flow source")
	var domains: Dictionary = {}
	for id: String in state.cults:
		var cult: Variant = state.cults[id]
		if not cult is Dictionary:
			errors.append("Invalid cult record")
			continue
		if cult.get("id") != id or not state.domains.has(cult.get("domain", "")) or domains.has(cult.get("domain", "")) or not cult.get("leader") is String or not cult.get("status", "") in ["active", "dormant", "destroyed"] or not cult.get("cohesion") is int or int(cult.cohesion) < 0 or int(cult.cohesion) > content.integer("attribute_max") or not cult.get("established_turn") is int or int(cult.established_turn) < 0 or int(cult.established_turn) > int(state.turn) or not Store.has(state.facts, cult.get("origin", "")) or not Store.has(state.facts, cult.get("established_source", "")) or not cult.get("strategy", "hold") in STRATEGIES:
			errors.append("Invalid established cult")
		else:
			domains[cult.domain] = true
			var fact: Dictionary = Store.entry(state.facts, cult.established_source)
			if fact.kind != "cult_established" or fact.turn != cult.established_turn or fact.changes.get("cult") != id:
				errors.append("Cult has no matching establishment fact")
	if not errors.is_empty():
		return errors
	var positions: Dictionary = {}
	for id: String in state.anchors:
		var anchor: Dictionary = state.anchors[id]
		if anchor.state == "absent":
			continue
		if anchor.get("id") != id or not anchor.get("ordinal") is int or not int(anchor.ordinal) in [1, 2, 3] or not state.cults.has(anchor.get("cult", "")) or not Store.has(state.facts, anchor.get("origin", "")) or not anchor.get("needs_rebind") is bool:
			errors.append("Invalid existing anchor metadata")
			continue
		var key: String = anchor.domain + "/" + str(anchor.ordinal)
		if positions.has(key) or state.cults[anchor.cult].domain != anchor.domain:
			errors.append("Invalid persistent anchor position or cult")
		positions[key] = true
	for id: String in ledger.remainders:
		if not state.cults.has(id) or not ledger.remainders[id] is int or int(ledger.remainders[id]) < 0 or int(ledger.remainders[id]) >= ATTRITION_UNIT:
			errors.append("Invalid exact attrition remainder")
	for id: String in ledger.effective:
		if not state.cults.has(id) or not ledger.effective[id] in STRATEGIES:
			errors.append("Invalid effective strategy")
	for id: String in ledger.round_cults:
		if not state.cults.has(id) or not Store.has(state.facts, ledger.round_cults[id]):
			errors.append("Invalid original cult window")
	for field: String in ["paid", "income_sources"]:
		for id: String in ledger[field]:
			if not Store.has(state.facts, ledger[field][id]) or not (state.anchors.has(id) if field == "paid" else state.cults.has(id)):
				errors.append("Invalid economy transaction source")
	for id: String in state.cults:
		if not ledger.remainders.has(id):
			errors.append("Missing persistent attrition remainder")
	if not ledger.prepay_source.is_empty() and (not Store.has(state.facts, ledger.prepay_source) or Store.entry(state.facts, ledger.prepay_source).kind != "economy_prepay" or Store.entry(state.facts, ledger.prepay_source).turn != ledger.prepay_turn):
		errors.append("Invalid prepayment receipt")
	for id: String in ledger.income_sources:
		var source: Variant = ledger.income_sources[id]
		if Store.has(state.facts, source):
			var fact: Dictionary = Store.entry(state.facts, source)
			if fact.kind != "economy_income" or fact.turn != ledger.income_turn or fact.changes.get("cult") != id:
				errors.append("Invalid income receipt")
	for id: String in ledger.paid:
		var source: Variant = ledger.paid[id]
		if Store.has(state.facts, source):
			var fact: Dictionary = Store.entry(state.facts, source)
			if fact.kind != "economy_anchor_payment" or fact.turn != ledger.prepay_turn or fact.changes.get("anchor") != id or fact.changes.get("reason") != "":
				errors.append("Invalid anchor payment receipt")
	for key: String in state.economy_qualifications:
		var pieces: PackedStringArray = key.split("|")
		if not state.economy_qualifications[key] is String or pieces.size() != 2 or not pieces[0] in ["propagation", "anchor"] or not (state.cults.has(pieces[1]) if pieces[0] == "propagation" else state.anchors.has(pieces[1])):
			errors.append("Invalid upstream qualification subject")
		elif not qualification(state, pieces[0], pieces[1]).ok:
			errors.append("Invalid upstream qualification proof")
	return errors

static func valid_phase(state: Dictionary, turn: Dictionary) -> bool:
	if not state.has("economy"):
		return true
	var ledger: Dictionary = state.economy
	if int(turn.turn) == 0:
		return ledger.prepay_turn == -1 and ledger.income_turn == -1 and ledger.eligible.is_empty() and ledger.paid.is_empty() and ledger.income_sources.is_empty()
	var previous: int = -1 if int(turn.turn) == 1 else int(turn.turn) - 1
	var paid: int = int(turn.turn) if turn.phase in ["settlement", "ending", "between", "ended"] else previous
	var received: int = int(turn.turn) if turn.phase in ["ending", "between", "ended"] else previous
	return ledger.turn == turn.turn and ledger.prepay_turn == paid and ledger.income_turn == received
