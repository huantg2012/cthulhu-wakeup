extends RefCounted
## Formal cult lifecycle. Durable identity, membership and capacity remain owned by
## World/Attention; this adapter only declares and commits cult-specific rules.
const Materials = preload("res://src/simulation/material_transfer.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const ID: String = "cults"
const SCHEMA: int = 1
var catalog: RefCounted
var version: String

func _init(content: RefCounted) -> void:
	catalog = content
	version = rule_version(catalog)

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.catalog.version != catalog.version: return false
	for slot: String in ["actions", "start", "cult_start", "cult_end"]:
		if turn._owners.has(slot) and not (slot == "actions" and turn._managed_actions(ID, self) and turn._managed_actions(turn._owners[slot], turn._participants[turn._owners[slot]].instance)): return false
	if turn.world.state.has("cult_system"): return false
	if turn.world.state.has("attention"):
		var combined: Dictionary = {"focus": [], "people": [], "members": [], "identities": [], "source": ""}
		for cult: Dictionary in turn.world.state.cults.values():
			if cult.status == "destroyed" or cult.leader.is_empty(): continue
			if not cult.leader in combined.members: combined.members.append(cult.leader); combined.people.append(cult.leader)
			combined.source = cult.established_source
		if not turn.world.attention.preview(turn.world.state, combined).ok: return false
	turn.world.state["cult_system"] = {"schema": SCHEMA, "version": version, "spend": {}, "dormancy": {}}
	for id: String in turn.world._living_ids():
		var person: Dictionary = turn.world.mutable_npc(id)
		if not person.has("bound_member"):
			person["bound_member"] = false; person["cult_id"] = ""; person["binding_source"] = person.status_source; person["dedication_source"] = ""
	# A turn-zero imported organization already has a sourced office. Preserve
	# that identity when attaching this lifecycle, rather than vacating it.
	for cult: Dictionary in turn.world.state.cults.values():
		if cult.status == "destroyed" or cult.leader.is_empty(): continue
		var token: String = ""
		if turn.world.state.has("attention"):
			var needs: Dictionary = turn.world.attention.preview_needs(turn.world.state, descriptor(cult.leader, cult.domain, cult.established_source, "CULT_FORM"))
			if not needs.ok: return false
			var reserved: Dictionary = turn.world.attention.reserve(turn.world, needs)
			if not reserved.ok: return false
			token = reserved.token
		if not membership(turn.world, "enroll", cult.leader, cult.established_source, token, cult.id): return false
		if not token.is_empty(): turn.world.attention.finish(turn.world, token)
	return turn.register_participant(ID, version, ["actions", "start", "cult_start", "cult_end"], ["cults", "schedule", "membership"], handle)

static func rule_version(content: RefCounted) -> String:
	return "2/material-transfer/" + content.version + "/" + str(content.extension_versions.get("powers", "missing")) + "/" + content.material_transfer_version()

static func descriptor(person: String, domain: String, source: String, content: String = "POWER_APPOINT") -> Dictionary:
	return {"family": "power" if content == "POWER_APPOINT" else "system", "content_id": content, "variant": "use", "participants": [person], "nominees": [person], "target": domain, "source": source}

static func willing(state: Dictionary, person: Dictionary, source: String = "") -> bool:
	if person.get("bound_member", false): return true
	var current: String = str(person.get("dedication_source", "")) if source.is_empty() else source
	if not Store.has(state.facts, current): return false
	var fact: Dictionary = Store.entry(state.facts, current)
	if fact.kind != "member_dedication" or fact.domain != person.domain or not person.id in fact.targets: return false
	var binding: Dictionary = Store.entry(state.facts, str(person.get("binding_source", person.status_source)))
	return binding.get("kind") != "member_left" or current > str(person.binding_source)

static func eligible(state: Dictionary, person: Dictionary, content: RefCounted) -> bool:
	return person.status == "active" and person.loyalty >= content.integer("cult_form_loyalty") and willing(state, person)

func _reply(effects: Array = []) -> Dictionary:
	return {"ok": true, "empty": effects.is_empty(), "effects": effects, "state": {}}

func _denied() -> Dictionary:
	return {"ok": false, "empty": true, "effects": [], "state": {}}

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	var state: Dictionary = view.world
	if input.slot in ["cult_start", "cult_end"]:
		return _reply([{"type": "cults", "operation": input.slot}])
	var payload: Dictionary = input.get("payload", {})
	if input.slot == "actions" and input.get("operation") == "act" and input.get("action") == "transfer_material": return _transfer_declaration(state, payload, view.reader)
	var references: Array = [payload.get("source", ""), input.get("source", ""), payload.get("binding", ""), payload.get("establishment", "")]
	if payload.get("npc") is String:
		var queried: Dictionary = view.reader.entity("npcs", payload.npc)
		if queried.ok:
			state.npcs[payload.npc] = queried.item
			references.append(queried.item.get("binding_source", queried.item.status_source))
			references.append(queried.item.get("dedication_source", ""))
	if payload.get("cult") is String and state.cults.has(payload.cult): references.append(state.cults[payload.cult].established_source)
	for source: String in references:
		if source.is_empty(): continue
		var queried: Dictionary = view.reader.fact(source)
		if queried.ok: state.facts[source] = queried.item
	if input.slot == "start":
		if input.get("operation") != "due" or input.get("action") != "appointment" or not valid_appointment_shape(state, payload): return _denied()
		var effect: Dictionary = {"type": "cults", "operation": "appointment", "payload": payload, "source": input.source}
		var result: Dictionary = _reply([effect])
		# Invalidated appointments settle as a sourced cancellation, without asking
		# for capacity again or silently substituting another person.
		if appointment_live(state, payload, catalog.integer("loyalty_follower_threshold")):
			result["attention"] = descriptor(payload.npc, state.cults[payload.cult].domain, input.source)
		return result
	if input.get("operation") != "act" or not payload.get("npc") is String or not Store.has(state.npcs, payload.npc) or not Store.has(state.facts, payload.get("source", "")): return _denied()
	var person: Dictionary = Store.entry(state.npcs, payload.npc)
	var action: String = str(input.action)
	var effects: Array = []
	var policy: Dictionary = {}
	var faith: int = 0; var whispers: int = 0; var threshold: int = 0
	if action == "enroll":
		if not eligible(state, person, catalog) or not willing(state, person, payload.source): return _denied()
		if state.has("attention"):
			var reachable: bool = person.domain in state.simulation.focused
			for domain: String in state.simulation.focused: reachable = reachable or person.domain in state.domains[domain].neighbors
			if not reachable: return _denied()
		var cult: String = str(payload.get("cult", ""))
		if not cult.is_empty() and (not state.cults.has(cult) or state.cults[cult].domain != person.domain or state.cults[cult].status == "destroyed"): return _denied()
		effects = [{"type": "membership", "operation": "enroll", "npc": person.id, "cult": cult, "source": payload.source}]
		policy = descriptor(person.id, person.domain, payload.source, "MEMBER_ENROLL")
	elif action == "leave":
		var fact: Dictionary = Store.entry(state.facts, payload.source)
		if not person.get("bound_member", false) or fact.kind != "member_leave_authorized" or not person.id in fact.targets: return _denied()
		effects = [{"type": "membership", "operation": "leave", "npc": person.id, "source": payload.source}]
		# Voluntary departure is an already authorized identity consequence. It
		# never needs a new P slot just to leave when both budgets are full.
		policy = {"family": "system", "content_id": "MEMBER_LEAVE", "variant": "use", "source": payload.source}
	elif action == "appoint":
		if not eligible(state, person, catalog) or not payload.get("cult") is String or not state.cults.has(payload.cult) or state.cults[payload.cult].status == "destroyed" or state.cults[payload.cult].domain != person.domain or not payload.get("role", "") in ["leader", "guardian"]: return _denied()
		var appointment: Dictionary = payload.duplicate(true)
		appointment["anchor"] = str(payload.get("anchor", ""))
		appointment["binding"] = str(person.get("binding_source", person.status_source))
		appointment["establishment"] = state.cults[payload.cult].established_source
		if not appointment_live(state, appointment, catalog.integer("loyalty_follower_threshold")): return _denied()
		for job: Dictionary in view.get("cult_jobs", []):
			if job.participant == ID and (job.payload.npc == person.id or (job.payload.cult == appointment.cult and job.payload.role == appointment.role and job.payload.anchor == appointment.anchor)): return _denied()
		var row: Dictionary = catalog.tables.powers.POWER_APPOINT
		faith = int(row.faith); whispers = int(row.whispers); threshold = int(row.unlock_awakening)
		policy = descriptor(person.id, person.domain, payload.source)
		policy["persistent"] = true
		var job: Dictionary = {"id": "CULT-APPOINT/" + str(state.turn) + "/" + person.id + "/" + payload.source, "due": state.turn + 1, "phase": "start", "action": "appointment", "payload": appointment, "source": payload.source}
		effects = [{"type": "schedule", "job": job}]
	else: return _denied()
	var result: Dictionary = _reply(effects)
	result["meta"] = {"faith_cost": faith, "whispers_cost": whispers, "min_awakening": threshold, "responds": false, "used_power": action == "appoint", "used_relic": false, "actor": "", "source": payload.source, "outcome": action, "target": person.domain, "attention": policy}
	return result

static func valid_appointment_shape(state: Dictionary, payload: Dictionary) -> bool:
	return payload.get("npc") is String and Store.has(state.npcs, payload.npc) and payload.get("cult") is String and state.cults.has(payload.cult) and payload.get("role", "") in ["leader", "guardian"] and payload.get("anchor") is String and (payload.role != "leader" or payload.anchor.is_empty()) and payload.get("binding") is String and Store.has(state.facts, payload.binding) and payload.get("establishment") is String and Store.has(state.facts, payload.establishment)

static func appointment_live(state: Dictionary, payload: Dictionary, loyalty: int) -> bool:
	if not valid_appointment_shape(state, payload) or PrayerRules.blocked(state, str(payload.get("npc", "")), "appointment"): return false
	var person: Dictionary = Store.entry(state.npcs, payload.npc)
	var cult: Dictionary = state.cults[payload.cult]
	if person.status != "active" or person.loyalty < loyalty or person.domain != cult.domain or cult.status == "destroyed" or cult.established_source != payload.establishment or str(person.get("binding_source", person.status_source)) != payload.binding: return false
	if not person.get("cult_id", "").is_empty() and person.cult_id != cult.id: return false
	if payload.role == "guardian":
		if not state.anchors.has(payload.anchor): return false
		var anchor: Dictionary = state.anchors[payload.anchor]
		if anchor.domain != cult.domain or anchor.get("cult", "") != cult.id or anchor.state in ["absent", "destroyed"]: return false
		for other: Dictionary in state.anchors.values():
			if other.id != anchor.id and other.guardian == person.id and other.state != "destroyed": return false
	return true

func validate_effect(state: Dictionary, slot: String, effect: Dictionary, reader: RefCounted = null) -> bool:
	if not state.has("cult_system") or state.cult_system.version != version: return false
	if slot == "actions" and effect.get("operation") == "transfer_material":
		return effect.get("payload") is Dictionary and Materials.preview(state, effect.payload, catalog, reader).get("ok", false)
	if effect.get("operation") == slot and slot in ["cult_start", "cult_end"]: return true
	return slot == "start" and effect.get("operation") == "appointment" and effect.get("payload") is Dictionary and valid_appointment_shape(state, effect.payload) and Store.has(state.facts, effect.get("source", ""))

static func membership(world: RefCounted, operation: String, npc: String, source: String, token: String = "", cult: String = "") -> bool:
	var prior_cult: String = str(Store.entry(world.state.npcs, npc).get("cult_id", ""))
	if world.state.has("attention"):
		var ok: bool = world.attention.enroll(world, npc, source, token, cult) if operation == "enroll" else world.attention.leave(world, npc, source)
		if ok and operation == "enroll" and not cult.is_empty():
			var person: Dictionary = world.mutable_npc(npc)
			person.cult_id = cult
			if prior_cult != cult:
				person["joined_turn"] = world.state.turn; person["joined_source"] = world._record("cult_member_joined", person.domain, npc, [npc], [source], {"cult": cult})
		return ok
	world.stage_current()
	var person: Dictionary = world.mutable_npc(npc)
	if operation == "enroll":
		if person.status == "dead" or person.loyalty < world.catalog.integer("loyalty_follower_threshold"): return false
		if not person.get("bound_member", false):
			person.bound_member = true
			person["binding_source"] = world._record("member_enrolled", person.domain, npc, [npc], [source], {"cult": cult})
		if not cult.is_empty():
			person.cult_id = cult
			if prior_cult != cult:
				person["joined_turn"] = world.state.turn; person["joined_source"] = world._record("cult_member_joined", person.domain, npc, [npc], [source], {"cult": cult})
	else:
		if person.get("bound_member", false):
			person.bound_member = false; person.cult_id = ""
			person["binding_source"] = world._record("member_left", person.domain, npc, [npc], [source])
			world._detach_roles(person, person.binding_source)
	return true

func commit(world: RefCounted, effect: Dictionary, owner: Object, token: String = "", payment: String = "") -> bool:
	if not world._driver_allowed(owner): return false
	world.stage_current()
	match effect.operation:
		"transfer_material": return world.receive_material(effect.payload, payment, owner).get("ok", false)
		"cult_start": return _start(world)
		"cult_end": return _end(world)
		"appointment":
			var payload: Dictionary = effect.payload
			var cult: Dictionary = world.state.cults[payload.cult]
			if not appointment_live(world.state, payload, catalog.integer("loyalty_follower_threshold")):
				world._record("cult_appointment_cancelled", cult.domain, payload.npc, [payload.npc], [effect.source, Store.entry(world.state.npcs, payload.npc).status_source], {"cult": cult.id, "role": payload.role})
				return true
			if not membership(world, "enroll", payload.npc, effect.source, token, cult.id): return false
			# Refresh first-write collections after membership may have staged them.
			cult = world.state.cults[payload.cult]
			var replaced: String = cult.leader if payload.role == "leader" else world.state.anchors[payload.anchor].guardian
			var cost: int = catalog.integer("cult_replace_leader_cohesion_cost") if payload.role == "leader" and not replaced.is_empty() and replaced != payload.npc else 0
			var source: String = world._record("cult_appointed", cult.domain, payload.npc, [payload.npc], [effect.source, cult.established_source], {"cult": cult.id, "role": payload.role, "anchor": payload.anchor, "replaced": replaced, "cohesion_cost": cost})
			if payload.role == "leader":
				cult.leader = payload.npc; cult.cohesion = maxi(0, cult.cohesion - cost); cult.succession_source = source
			else:
				world.state.anchors[payload.anchor].guardian = payload.npc
			reconcile(world)
			return true
	return false

static func record_payment(world: RefCounted, domain: String, amount: int, source: String) -> bool:
	if amount == 0: return true
	if amount < 0 or not world.state.domains.has(domain) or not Store.has(world.state.facts, source): return false
	var paid: Dictionary = Store.entry(world.state.facts, source)
	var actual: int = int(paid.changes.get("faith_cost", paid.changes.get("fee", -1)))
	if paid.domain != domain or paid.kind not in ["turn_action", "economy_strategy_payment", "economy_anchor_payment"] or actual != amount: return false
	world.stage_collections(["cult_system"])
	var prior: Dictionary = world.state.cult_system.spend.get(domain, {"amount": 0, "source": world.state.domains[domain].origin})
	if source <= str(prior.source): return false
	var total: int = int(prior.amount) + amount
	var fact: String = world._record("cult_local_payment", domain, "", [], [prior.source, source], {"amount": amount, "total": total, "payment": source, "previous": prior.source, "previous_total": prior.amount})
	world.state.cult_system.spend[domain] = {"amount": total, "source": fact}
	return true

static func reconcile(world: RefCounted) -> void:
	if not world.state.has("cult_system"): return
	world.stage_collections(["cults", "cult_system"])
	for cult: Dictionary in world.state.cults.values():
		if cult.status != "destroyed" and (world.state.domains[cult.domain].unnamed_followers == 0 or cult.cohesion == 0): cult.status = "destroyed"
		if cult.status == "destroyed":
			if not cult.has("destroyed_source") or int(cult.get("destroyed_turn", -1)) < int(cult.established_turn):
				cult["destroyed_source"] = world._record("cult_destroyed", cult.domain, "", [], [cult.established_source, cult.get("succession_source", cult.established_source)], {"cult": cult.id, "reason": "population_cohesion_or_dormancy"})
				cult["destroyed_turn"] = world.state.turn
			continue
		if not cult.leader.is_empty():
			var leader: Dictionary = Store.entry(world.state.npcs, cult.leader)
			if leader.status == "dead" or leader.domain != cult.domain or not leader.get("bound_member", false):
				cult.succession_source = leader.get("binding_source", leader.status_source); cult.leader = ""
		var operational: bool = not cult.leader.is_empty() and Store.entry(world.state.npcs, cult.leader).status == "active" and Store.entry(world.state.npcs, cult.leader).loyalty >= world.catalog.integer("loyalty_follower_threshold")
		cult.status = "active" if operational else "dormant"
		var dormant: Dictionary = world.state.cult_system.dormancy.get(cult.id, {})
		if operational and int(dormant.get("turns", 0)) > 0:
			var leader: Dictionary = Store.entry(world.state.npcs, cult.leader)
			var resumed: String = world._record("cult_dormancy_reset", cult.domain, cult.leader, [cult.leader], [dormant.source, leader.status_source], {"cult": cult.id, "turns": 0})
			world.state.cult_system.dormancy[cult.id] = {"turns": 0, "last_turn": dormant.last_turn, "source": resumed}

func _choose(world: RefCounted, domain: String, source: String, content: String, cult: String) -> String:
	var candidates: Array = []
	for id: String in world.history.ids("active/" + domain):
		var person: Dictionary = Store.entry(world.state.npcs, id)
		if eligible(world.state, person, catalog) and (person.get("cult_id", "").is_empty() or person.cult_id == cult): candidates.append(person)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.influence != b.influence: return a.influence > b.influence
		if a.loyalty != b.loyalty: return a.loyalty > b.loyalty
		return a.id < b.id)
	for person: Dictionary in candidates:
		var token: String = ""
		if world.state.has("attention"):
			var needs: Dictionary = world.attention.preview_needs(world.state, descriptor(person.id, domain, source, content))
			if not needs.ok: continue
			var reserved: Dictionary = world.attention.reserve(world, needs)
			if not reserved.ok: continue
			token = reserved.token
		if not membership(world, "enroll", person.id, source, token, cult): return ""
		if not token.is_empty(): world.attention.finish(world, token)
		return person.id
	return ""

func _start(world: RefCounted) -> bool:
	reconcile(world)
	for id: String in world._keys(world.state.cults):
		var cult: Dictionary = world.state.cults[id]
		if cult.status == "destroyed" or not cult.leader.is_empty(): continue
		var successor: String = _choose(world, cult.domain, cult.get("succession_source", cult.established_source), "CULT_SUCCESSION", cult.id)
		if successor.is_empty(): continue
		cult = world.state.cults[id]
		cult.leader = successor
		cult.cohesion = maxi(0, cult.cohesion - catalog.integer("cult_succession_cohesion_cost"))
		cult.succession_source = world._record("cult_succeeded", cult.domain, successor, [successor], [cult.get("succession_source", cult.established_source)], {"cult": id, "cohesion_delta": -catalog.integer("cult_succession_cohesion_cost")})
	reconcile(world)
	return true

func _end(world: RefCounted) -> bool:
	reconcile(world)
	for id: String in world._keys(world.state.cults):
		var cult: Dictionary = world.state.cults[id]
		var prior: Dictionary = world.state.cult_system.dormancy.get(id, {"turns": 0, "last_turn": -1, "source": cult.established_source})
		if prior.last_turn == world.state.turn: continue
		var count: int = int(prior.turns) + 1 if cult.status == "dormant" else 0
		var source: String = world._record("cult_dormancy", cult.domain, "", [], [prior.source, cult.get("succession_source", cult.established_source)], {"cult": id, "turns": count})
		world.state.cult_system.dormancy[id] = {"turns": count, "last_turn": world.state.turn, "source": source}
		if cult.status == "dormant" and count >= catalog.integer("cult_dormant_max_turns"): cult.status = "destroyed"
	reconcile(world)
	for domain: String in world._keys(world.state.domains):
		if world.state.domains[domain].unnamed_followers < catalog.integer("cult_form_followers") or int(world.state.cult_system.spend.get(domain, {}).get("amount", 0)) < catalog.integer("cult_form_local_spend"): continue
		var existing: String = ""
		for id: String in world._keys(world.state.cults):
			if world.state.cults[id].domain == domain: existing = id; break
		if not existing.is_empty() and (world.state.cults[existing].status != "destroyed" or int(world.state.cults[existing].get("destroyed_turn", world.state.turn)) >= int(world.state.turn)): continue
		var id: String = "CULT/" + domain if existing.is_empty() else existing
		var source: String = world.state.cult_system.spend[domain].source
		var leader: String = _choose(world, domain, source, "CULT_FORM", id)
		if leader.is_empty(): continue
		var origin: String = "" if existing.is_empty() else world.state.cults[existing].origin
		var established: String = world._record("cult_established", domain, leader, [leader], [source, Store.entry(world.state.npcs, leader).binding_source], {"cult": id, "natural": true, "rebuild": not existing.is_empty()})
		world.state.cults[id] = {"id": id, "domain": domain, "leader": leader, "cohesion": catalog.integer("cult_initial_cohesion"), "status": "active", "origin": established if origin.is_empty() else origin, "established_turn": world.state.turn, "established_source": established, "strategy": "hold", "succession_source": established}
		world.mutable_npc(leader).cult_id = id
		world.state.cult_system.dormancy[id] = {"turns": 0, "last_turn": world.state.turn, "source": established}
		if world.state.has("economy") and not world.state.economy.remainders.has(id): world.state.economy.remainders[id] = 0
	return true

static func _validate_payments(state: Dictionary, trusted: Dictionary) -> Array[String]:
	# Loading is an audit boundary: inspect the complete payment chain, including
	# facts no longer named by the current ledger. Ordinary transactions extend
	# immutable, already audited heads and inspect only their new fact suffix.
	var heads: Dictionary = {}
	var incremental: bool = trusted.has("cult_system")
	if incremental:
		for domain: String in trusted.cult_system.spend: heads[domain] = trusted.cult_system.spend[domain]
	var ids: Array = []
	if incremental:
		if not trusted.get("next_fact") is int or not state.get("next_fact") is int or state.next_fact < trusted.next_fact: return ["Invalid payment audit boundary"]
		for sequence: int in range(trusted.next_fact, state.next_fact): ids.append("FACT-%08d" % sequence)
	else:
		ids = Store.keys(state.facts); ids.sort()
	var payments: Dictionary = {}
	for id: String in ids:
		var fact: Variant = Store.entry(state.facts, id)
		if not fact is Dictionary: return ["Missing payment audit fact"]
		if fact.get("kind") != "cult_local_payment": continue
		var domain: Variant = fact.get("domain")
		if not domain is String or not state.domains.has(domain) or not fact.get("changes") is Dictionary: return ["Invalid local payment domain or data"]
		var data: Dictionary = fact.changes
		if not data.get("amount") is int or data.amount <= 0 or not data.get("total") is int or not data.get("previous_total") is int or data.previous_total < 0 or not data.get("payment") is String or not data.get("previous") is String: return ["Invalid local payment amount or references"]
		var previous: Dictionary = heads.get(domain, {"amount": 0, "source": state.domains[domain].origin})
		if data.previous != previous.source or data.previous_total != previous.amount or data.total != int(previous.amount) + int(data.amount): return ["Local payment chain or cumulative total disagrees"]
		if data.payment <= data.previous or id <= data.payment or payments.has(data.payment): return ["Actual payment was reused or reordered"]
		var payment: Variant = Store.entry(state.facts, data.payment)
		if not payment is Dictionary or payment.get("domain") != domain or not payment.get("kind", "") in ["turn_action", "economy_strategy_payment", "economy_anchor_payment"] or not payment.get("changes") is Dictionary: return ["Local payment has no actual paid action"]
		var actual: Variant = payment.changes.get("faith_cost") if payment.kind == "turn_action" else payment.changes.get("fee")
		if not actual is int or actual != data.amount or fact.get("turn") != payment.get("turn") or not fact.get("causal_parents") is Array or not data.previous in fact.causal_parents or not data.payment in fact.causal_parents: return ["Local payment has no matching paid amount and causes"]
		payments[data.payment] = true
		heads[domain] = {"amount": data.total, "source": id}
	var ledger: Dictionary = state.cult_system.spend
	if ledger.size() != heads.size(): return ["Local payment ledger omitted or invented a chain"]
	for domain: Variant in ledger:
		var entry: Variant = ledger[domain]
		if not domain is String or not heads.has(domain) or not entry is Dictionary or not entry.get("amount") is int or not entry.get("source") is String or entry.amount != heads[domain].amount or entry.source != heads[domain].source: return ["Local payment ledger does not match its audited chain"]
	return []

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not state.has("cult_system"):
		if trusted.has("cult_system"): return ["Cult system cannot disappear"]
		return []
	var ledger: Variant = state.cult_system
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content) or not ledger.get("spend") is Dictionary or not ledger.get("dormancy") is Dictionary: return ["Invalid cult schema/content version"]
	var payment_errors: Array[String] = _validate_payments(state, trusted)
	if not payment_errors.is_empty(): return payment_errors
	for id: Variant in ledger.dormancy:
		var entry: Variant = ledger.dormancy[id]
		if not state.cults.has(id) or not entry is Dictionary or not entry.get("turns") is int or entry.turns < 0 or not entry.get("last_turn") is int or entry.last_turn > state.turn or not Store.has(state.facts, entry.get("source", "")): return ["Invalid cult dormancy record"]
		var fact: Dictionary = Store.entry(state.facts, entry.source)
		if fact.kind not in ["cult_established", "cult_dormancy", "cult_dormancy_reset"] or fact.changes.get("cult") != id or (fact.kind != "cult_dormancy_reset" and fact.turn != entry.last_turn) or (fact.kind == "cult_dormancy_reset" and (fact.turn < entry.last_turn or entry.turns != 0)) or (fact.kind == "cult_dormancy" and fact.changes.get("turns") != entry.turns): return ["Cult dormancy source disagrees"]
	return []

static func validate_context(state: Dictionary, context: Dictionary) -> Array[String]:
	if not state.has("cult_system"): return []
	var duties: Dictionary = {}; var people: Dictionary = {}
	for job: Dictionary in context.get("queued", []):
		if job.get("participant") != ID: continue
		if job.get("action") != "appointment" or job.get("phase") != "start" or not job.get("payload") is Dictionary or not valid_appointment_shape(state, job.payload): return ["Invalid pending cult appointment"]
		var payload: Dictionary = job.payload
		var duty: String = payload.cult + "/" + payload.role + "/" + (payload.anchor if payload.role == "guardian" else "")
		if duties.has(duty) or people.has(payload.npc): return ["Duplicate pending cult duty or person"]
		duties[duty] = true; people[payload.npc] = true
		if state.has("attention"):
			var token: String = str(job.get("attention_token", ""))
			if not state.attention.reservations.has(token): return ["Appointment lost its persistent capacity"]
			var claim: Dictionary = state.attention.reservations[token]
			if not claim.persistent or claim.owner != ID or not payload.npc in claim.members or not state.cults[payload.cult].domain in claim.focus: return ["Appointment capacity does not match fixed duty"]
	return []

func _transfer_declaration(state: Dictionary, payload: Dictionary, reader: RefCounted = null) -> Dictionary:
	if payload.size() != 5: return {"ok": false, "error": "invalid_material_request"}
	var plan: Dictionary = Materials.preview(state, payload, catalog, reader)
	if not plan.ok: return plan
	var policy: Dictionary = {"family": "system", "content_id": "CULT_TRANSFER_MATERIAL", "variant": "use", "participants": [plan.sender, plan.recipient], "target": state.institutions[plan.target_institution].domain, "source": payload.source}
	var result: Dictionary = _reply([{"type": "cults", "operation": "transfer_material", "payload": payload.duplicate(true)}])
	result["meta"] = {"faith_cost": plan.faith, "whispers_cost": plan.whispers, "min_awakening": 0, "responds": false, "used_power": false, "used_relic": false, "actor": "", "source": payload.source, "outcome": "transfer_material", "target": policy.target, "attention": policy, "material": {"sender": plan.sender, "recipient": plan.recipient, "source": plan.source, "target_institution": plan.target_institution, "grant": plan.grant}}
	result["preview"] = {"faith": plan.faith, "whispers": plan.whispers, "grant": plan.grant, "source": plan.source, "recipient": plan.recipient, "target_institution": plan.target_institution}
	return result

func preview_transfer(turn: RefCounted, payload: Dictionary) -> Dictionary:
	if turn.context.phase != "actions": return {"ok": false, "error": "Material transfer requires the action phase"}
	var declaration: Dictionary = _transfer_declaration(turn.world.state, payload, turn.world.history)
	if not declaration.get("ok", false): return declaration
	var needs: Dictionary = turn.world.attention.preview_needs(turn.world.state, declaration.meta.attention, declaration.effects)
	if not needs.ok: return needs
	if turn.world.state.faith < declaration.meta.faith_cost or turn.world.state.whispers < declaration.meta.whispers_cost: return {"ok": false, "error": "Material transfer is not affordable"}
	return {"ok": true, "preview": declaration.preview.merged({"needs": needs})}
