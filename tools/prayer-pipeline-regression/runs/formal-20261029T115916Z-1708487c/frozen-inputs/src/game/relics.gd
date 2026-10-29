extends RefCounted
## Persistent relic identities and explicit, mutually exclusive placements.
## Narrative producers grant typed, versioned capabilities; this module never
## invents drops, transports, anchor structures, or narrative opportunities.
const History = preload("res://src/simulation/history_index.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const Economy = preload("res://src/game/economy.gd")
const ID: String = "relics"
const SCHEMA: int = 1
const PLACEMENTS: Array[String] = ["controlled", "ground", "carried", "bound", "seized", "sealed", "consumed"]
var catalog: RefCounted
var issuers: Dictionary
var version: String

func _init(content: RefCounted, accepted_issuers: Dictionary = {}) -> void:
	catalog = content
	issuers = accepted_issuers.duplicate(true)
	version = rule_version(content)

static func rule_version(content: RefCounted) -> String:
	return "1/" + content.version + "/" + str(content.extension_versions.get("relics", "missing")) + "/" + str(content.extension_versions.get("relic_effects", "missing"))

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("relic_system") or turn.world.catalog.version != catalog.version: return false
	for issuer: Variant in issuers:
		if not issuer is String or issuer.is_empty() or not issuers[issuer] is String or str(issuers[issuer]).is_empty(): return false
	turn.world.state["relic_system"] = {"schema": SCHEMA, "version": version, "issuers": issuers.duplicate(true)}
	if not turn.register_participant(ID, version + "/" + JSON.stringify(issuers, "", true, true).sha256_text(), ["actions", "relic_start"], ["relics"], handle):
		turn.world.state.erase("relic_system")
		return false
	return true

static func instance_id(source: String) -> String:
	return "RELIC/" + source

static func _has_cult(state: Dictionary, domain: String) -> bool:
	for cult: Dictionary in state.cults.values():
		if cult.domain == domain and cult.status != "destroyed": return true
	return false

static func _controlled(state: Dictionary, relic: Dictionary) -> bool:
	# A destroyed cult does not drop or erase its inventory. The same cult's
	# lawful reconstruction can recover control over this continuous identity.
	if relic.placement == "controlled": return _has_cult(state, relic.domain)
	if relic.placement != "carried" or not Store.has(state.npcs, relic.get("holder", "")): return false
	var person: Dictionary = Store.entry(state.npcs, relic.holder)
	return person.status == "active" and person.domain == relic.domain and person.get("bound_member", false)

static func _carrier(state: Dictionary, npc: String, domain: String, except_relic: String = "") -> bool:
	if not Store.has(state.npcs, npc): return false
	var person: Dictionary = Store.entry(state.npcs, npc)
	if person.status != "active" or person.domain != domain or not person.get("bound_member", false): return false
	for relic: Dictionary in Store.values(state.relics):
		if relic.id != except_relic and relic.placement == "carried" and relic.get("holder", "") == npc: return false
	return true

func _authorized(state: Dictionary, source: String, operation: String, relic: String = "", check_used: bool = true) -> bool:
	if not Store.has(state.facts, source) or Store.has(state.get("invalid_records", {}), source): return false
	var fact: Dictionary = Store.entry(state.facts, source)
	if fact.kind != "relic_" + operation + "_authorized" or not state.domains.has(fact.domain): return false
	if not relic.is_empty() and not relic in fact.targets: return false
	var proof: Variant = fact.changes.get("proof")
	if not proof is Dictionary or proof.get("schema") != SCHEMA or not proof.get("issuer") is String or not proof.get("version") is String: return false
	if proof.get("domain") != fact.domain or proof.get("target") != (fact.changes.get("relic_type", "") if operation == "create" else relic) or proof.get("holder", "") != fact.changes.get("holder", ""): return false
	if operation != "create":
		if not Store.has(state.relics, relic) or proof.get("status_source") != Store.entry(state.relics, relic).get("status_source", ""): return false
	if operation == "create":
		var grounded: bool = false
		for target: String in fact.targets:
			if state.institutions.has(target) and state.institutions[target].domain == fact.domain and state.institutions[target].active: grounded = true
			if target == fact.changes.get("holder", "") and Store.has(state.npcs, target) and Store.entry(state.npcs, target).domain == fact.domain and Store.entry(state.npcs, target).status == "active": grounded = true
		if not grounded: return false
	return issuers.has(proof.issuer) and issuers[proof.issuer] == proof.version and (not check_used or not Store.has(state.get("applied_authorizations", {}), "relic/" + operation + "/" + source))

func _hydrate(view: Dictionary, payload: Dictionary) -> Dictionary:
	var state: Dictionary = view.world
	for id: String in [str(payload.get("relic", "")), instance_id(str(payload.get("source", "")))]:
		var queried: Dictionary = view.reader.entity("relics", id)
		if queried.ok: state.relics[id] = queried.item
	for id: String in [str(payload.get("npc", "")), str(payload.get("holder", ""))]:
		if id.is_empty(): continue
		var queried: Dictionary = view.reader.entity("npcs", id)
		if queried.ok: state.npcs[id] = queried.item
	var source: String = str(payload.get("source", ""))
	var queried: Dictionary = view.reader.fact(source)
	if queried.ok and not view.reader.invalidated(source): state.facts[source] = queried.item
	else: state.facts.erase(source)
	state["applied_authorizations"] = {}
	for operation: String in ["create", "recover", "seize", "seal", "destroy"]:
		var key: String = "relic/" + operation + "/" + source
		var used: Dictionary = view.reader.authorization(key)
		if used.ok and used.used: state.applied_authorizations[key] = used.source
	return state

func _reply(effects: Array = []) -> Dictionary:
	return {"ok": true, "empty": effects.is_empty(), "effects": effects, "state": {}}

func _denied(reason: String = "Relic operation is not currently eligible") -> Dictionary:
	return {"ok": false, "error": reason, "empty": true, "effects": [], "state": {}}

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	if input.get("slot") == "relic_start": return _reply([{"type": "relics", "operation": "release_due"}])
	if input.get("operation") != "act" or not input.get("payload") is Dictionary: return _denied()
	var payload: Dictionary = input.payload
	var state: Dictionary = _hydrate(view, payload)
	var action: String = str(input.get("action", "")).trim_prefix("relic_")
	var operation: Dictionary = preview(state, action, payload, int(view.turn.whispers_budget))
	if not operation.ok: return _denied(str(operation.get("error", "Relic operation is not currently eligible")))
	var result: Dictionary = _reply([operation.effect])
	result["preview"] = operation.preview
	result["meta"] = {"faith_cost": 0, "whispers_cost": 0 if action == "disassemble" and payload.get("mode") == "whispers" else catalog.integer("relic_operation_whispers"), "min_awakening": 0, "responds": false, "used_power": false, "used_relic": true, "actor": "", "source": payload.source, "outcome": "relic_" + action, "target": operation.domain, "attention": operation.attention}
	return result

func preview(state: Dictionary, action: String, payload: Dictionary, whispers_budget: int = -1, include_cost: bool = true) -> Dictionary:
	if not payload.get("source") is String or not Store.has(state.facts, payload.source) or Store.has(state.get("invalid_records", {}), payload.source): return {"ok": false}
	var source: String = payload.source
	var cost: int = 0 if action == "disassemble" and payload.get("mode") == "whispers" else catalog.integer("relic_operation_whispers")
	if include_cost and int(state.whispers) < cost: return {"ok": false}
	var fact: Dictionary = Store.entry(state.facts, source)
	var id: String = instance_id(source) if action == "create" else str(payload.get("relic", ""))
	var relic: Dictionary = Store.entry(state.relics, id) if Store.has(state.relics, id) else {}
	var domain: String = str(fact.domain) if action == "create" else str(relic.get("domain", ""))
	if not state.domains.has(domain): return {"ok": false}
	if relic.get("placement") == "controlled" and not _has_cult(state, domain) and action in ["equip", "unequip", "unbind", "disassemble"]: return {"ok": false, "error": "Stored relic remains with its historical cult; lawful reconstruction is required to regain control"}
	var policy: String = "RELIC_EQUIP"
	var participants: Array = []
	var gain: int = 0
	if action == "create":
		if not relic.is_empty() or not _authorized(state, source, action): return {"ok": false}
		var changes: Dictionary = fact.changes
		if not catalog.tables.relics.has(changes.get("relic_type", "")) or not changes.get("placement") in ["controlled", "ground", "carried"]: return {"ok": false}
		if changes.placement == "controlled" and not _has_cult(state, domain): return {"ok": false}
		if changes.placement == "carried":
			if not _carrier(state, str(changes.get("holder", "")), domain) or not changes.holder in fact.targets: return {"ok": false}
			participants.append(changes.holder)
	elif relic.is_empty() or not catalog.tables.relics.has(relic.get("type", "")) or relic.placement == "consumed": return {"ok": false}
	elif action == "equip":
		if not _controlled(state, relic) or not _carrier(state, str(payload.get("npc", "")), domain, id): return {"ok": false}
		participants.append(payload.npc)
	elif action == "unequip":
		if relic.placement != "carried" or not _controlled(state, relic) or not _has_cult(state, domain): return {"ok": false}
		participants.append(relic.holder)
	elif action == "unbind":
		if relic.placement != "bound" or not state.anchors.has(relic.get("anchor", "")) or not _has_cult(state, domain): return {"ok": false}
		policy = "RELIC_UNBIND"
	elif action == "recover":
		if not relic.placement in ["ground", "seized"] or not _authorized(state, source, action, id) or fact.domain != domain: return {"ok": false}
		if not str(payload.get("npc", "")).is_empty():
			if fact.changes.get("holder", "") != payload.npc or not _carrier(state, payload.npc, domain): return {"ok": false}
			participants.append(payload.npc)
		elif not _has_cult(state, domain): return {"ok": false}
		policy = "RELIC_RECOVER"
	elif action in ["seize", "seal", "destroy"]:
		if not _authorized(state, source, action, id) or fact.domain != domain: return {"ok": false}
		if action == "seize" and (not state.institutions.has(fact.changes.get("institution", "")) or state.institutions[fact.changes.institution].domain != domain): return {"ok": false}
		if action == "seal" and (not fact.changes.get("duration") is int or fact.changes.duration <= 0 or relic.placement == "sealed"): return {"ok": false}
	elif action == "release":
		if relic.placement != "sealed" or int(relic.get("sealed_until", -1)) > int(state.turn): return {"ok": false}
	elif action == "disassemble":
		if not _controlled(state, relic) or not payload.get("mode") in ["faith", "insight", "followers", "whispers"]: return {"ok": false}
		var mode: String = payload.mode
		var row: Dictionary = catalog.tables.relics[relic.type]
		policy = "RELIC_" + mode.to_upper()
		match mode:
			"faith": gain = mini(int(row.faith_disassembly), maxi(0, Economy.capacity(state, catalog) - int(state.faith)))
			"insight": gain = mini(int(row.insight_disassembly), maxi(0, catalog.integer("insight_cap") - int(state.insight)))
			"followers": gain = mini(int(row.follower_gift), int(state.domains[domain].unnamed_nonfollowers))
			"whispers": gain = mini(int(row.whisper_release), maxi(0, whispers_budget - int(state.whispers)))
	else: return {"ok": false}
	var attention: Dictionary = {"family": "system", "content_id": policy, "variant": "use", "target": domain, "source": source}
	if not participants.is_empty(): attention["participants"] = participants
	return {"ok": true, "domain": domain, "attention": attention, "preview": {"net_gain": gain, "awakening_loss": _anchor_loss(state, relic), "consumes": action == "disassemble"}, "effect": {"type": "relics", "operation": action, "payload": payload.duplicate(true), "whispers_budget": whispers_budget}}

func validate_effect(state: Dictionary, slot: String, effect: Dictionary, index: RefCounted = null, include_cost: bool = true) -> bool:
	state = _current_view(state, index)
	if slot == "relic_start": return effect.get("operation") == "release_due"
	if slot != "actions" or not effect.get("payload") is Dictionary: return false
	if effect.get("operation") == "prepare": return preparation(state, str(effect.payload.get("relic", "")), str(effect.payload.get("power", "")), str(effect.payload.get("actor", ""))).ok
	return preview(state, str(effect.get("operation", "")), effect.payload, int(effect.get("whispers_budget", -1)), include_cost).ok

func _anchor_loss(state: Dictionary, relic: Dictionary) -> int:
	if relic.is_empty() or not state.anchors.has(relic.get("anchor", "")): return 0
	var anchor: Dictionary = state.anchors[relic.anchor]
	return catalog.integer("anchor_" + str(state.domains[anchor.domain].tier) + "_contribution") if anchor.state == "active" else 0

func commit(world: RefCounted, effect: Dictionary, owner: Object, _token: String = "") -> bool:
	if not world._driver_allowed(owner): return false
	if effect.get("operation") == "release_due": return release_due(world, owner)
	if not validate_effect(world.state, "actions", effect, world.history, false): return false
	var payload: Dictionary = effect.payload
	var action: String = effect.operation
	if action == "prepare": return _pay_preparation(world, payload)
	var source: String = payload.source
	var id: String = instance_id(source) if action == "create" else payload.relic
	var checked: Dictionary = preview(_current_view(world.state, world.history), action, payload, int(effect.get("whispers_budget", -1)), false)
	world.stage_collections(["relics", "anchors", "domains", "cults", "applied_authorizations"])
	var fact: Dictionary = Store.entry(world.state.facts, source)
	if action == "create":
		var changes: Dictionary = fact.changes
		Store.put(world.state.relics, id, {"id": id, "formal": true, "type": changes.relic_type, "domain": fact.domain, "placement": changes.placement, "holder": str(changes.get("holder", "")) if changes.placement == "carried" else "", "anchor": "", "captor": "", "origin": source, "status_source": source})
	var relic: Dictionary = Store.entry(world.state.relics, id)
	var previous: String = relic.placement
	match action:
		"equip": relic.placement = "carried"; relic.holder = payload.npc
		"unequip", "unbind":
			relic.placement = "controlled"; relic.holder = ""
			if action == "unbind" and world.state.anchors.has(relic.anchor):
				world.state.anchors[relic.anchor].state = "dormant"
				world.state.anchors[relic.anchor]["needs_rebind"] = true
			relic.anchor = ""
		"recover":
			relic.placement = "carried" if not str(payload.get("npc", "")).is_empty() else "controlled"
			relic.holder = str(payload.get("npc", "")) if relic.placement == "carried" else ""
			relic.captor = ""; relic.anchor = ""
		"seize": relic.placement = "seized"; relic.holder = ""; relic.captor = fact.changes.institution
		"seal": _seal_record(world, relic, int(fact.changes.duration))
		"release": _release_record(world, relic)
		"destroy", "disassemble":
			if action == "disassemble":
				var gain: int = checked.preview.net_gain
				match str(payload.mode):
					"faith": world.state.faith += gain
					"insight": world.state.insight += gain
					"followers": pass # Applied through the shared population protocol below.
					"whispers":
						world.state.whispers += gain
						world.state.domains[relic.domain].alert = mini(100, world.state.domains[relic.domain].alert + int(catalog.tables.relic_effects[relic.type].release_alert))
						if int(catalog.tables.relic_effects[relic.type].release_alert) > 0: world.state.domains[relic.domain].exposure_turn = world.state.turn
			if world.state.anchors.has(relic.get("anchor", "")): world.state.anchors[relic.anchor].state = "destroyed"
			relic.placement = "consumed"; relic.holder = ""; relic.captor = ""; relic.anchor = ""
	relic.status_source = world._record("relic_" + action, relic.domain, str(payload.get("npc", "")), [id], [source, relic.origin], {"relic": id, "from": previous, "to": relic.placement, "mode": payload.get("mode", ""), "net_gain": checked.preview.net_gain})
	if action == "disassemble" and payload.get("mode") == "followers" and int(checked.preview.net_gain) > 0:
		if not world.submit({"kind": "population", "mode": "convert", "domain": relic.domain, "amount": int(checked.preview.net_gain), "parents": [relic.status_source]}, owner): return false
	if action in ["create", "recover", "seize", "seal", "destroy"]: Store.put(world.state.applied_authorizations, "relic/" + action + "/" + source, relic.status_source)
	if world.history != null: world.history.refresh_relic(world.state, id)
	world._refresh_anchors()
	return true

func preparation(state: Dictionary, relic_id: String, power_id: String, actor: String) -> Dictionary:
	if not Store.has(state.relics, relic_id) or not Store.has(state.npcs, actor): return {"ok": false}
	var relic: Dictionary = Store.entry(state.relics, relic_id)
	var person: Dictionary = Store.entry(state.npcs, actor)
	if not catalog.tables.relic_effects.has(relic.get("type", "")) or relic.placement != "carried" or not _controlled(state, relic) or relic.domain != person.domain or person.status != "active": return {"ok": false}
	var row: Dictionary = catalog.tables.relic_effects[relic.type]
	if not power_id in str(row.powers).split("|"): return {"ok": false}
	if row.carry_subject == "cult" and not _has_cult(state, relic.domain): return {"ok": false}
	return {"ok": true, "bonus": int(row.preparation), "effects": [{"type": "relics", "operation": "prepare", "payload": {"relic": relic_id, "actor": actor, "power": power_id}}]}

func _pay_preparation(world: RefCounted, payload: Dictionary) -> bool:
	if not payload.get("source") is String or not Store.has(world.state.facts, payload.source): return false
	var attempt: Dictionary = Store.entry(world.state.facts, payload.source)
	if attempt.kind != "power_attempt" or attempt.actor != payload.actor or attempt.changes.get("power") != payload.power and not (payload.power == "POWER_MANIFEST" and attempt.changes.get("power") == "POWER_MANIFEST_CONTINUE"): return false
	var selection: Dictionary = attempt.changes.get("payload", {})
	if str(selection.get("preparation_relic", selection.get("relic", "") if payload.power != "POWER_ANCHOR" else "")) != payload.relic: return false
	var relic: Dictionary = Store.entry(world.state.relics, payload.relic)
	var row: Dictionary = catalog.tables.relic_effects[relic.type]
	world.stage_collections(["domains", "cults", "npcs"])
	match str(row.carry_subject):
		"actor", "holder":
			var person: Dictionary = world.mutable_npc(payload.actor if row.carry_subject == "actor" else relic.holder)
			person[row.carry_field] = clampi(int(person[row.carry_field]) + int(row.carry_delta), 0, 100)
		"domain":
			world.state.domains[relic.domain][row.carry_field] = clampi(int(world.state.domains[relic.domain][row.carry_field]) + int(row.carry_delta), 0, 100)
			if row.carry_field == "alert" and int(row.carry_delta) > 0: world.state.domains[relic.domain].exposure_turn = world.state.turn
		"cult":
			for cult: Dictionary in world.state.cults.values():
				if cult.domain == relic.domain and cult.status != "destroyed": cult[row.carry_field] = clampi(int(cult[row.carry_field]) + int(row.carry_delta), 0, 100)
	world._record("relic_preparation_paid", relic.domain, payload.actor, [relic.id], [relic.origin, payload.source], {"power": payload.power, "subject": row.carry_subject, "field": row.carry_field, "delta": int(row.carry_delta)})
	return true

func bind(world: RefCounted, relic_id: String, anchor_id: String, source: String, owner: Object) -> bool:
	if not world._driver_allowed(owner) or not Store.has(world.state.relics, relic_id) or not world.state.anchors.has(anchor_id) or not Store.has(world.state.facts, source): return false
	var relic: Dictionary = Store.entry(world.state.relics, relic_id)
	if not _controlled(world.state, relic) or relic.domain != world.state.anchors[anchor_id].domain: return false
	world.stage_collections(["relics", "anchors"])
	relic = Store.entry(world.state.relics, relic_id)
	relic.placement = "bound"; relic.holder = ""; relic.anchor = anchor_id; relic.captor = ""
	relic.status_source = world._record("relic_bound", relic.domain, "", [relic_id], [source, relic.origin], {"anchor": anchor_id})
	if world.history != null: world.history.refresh_relic(world.state, relic_id)
	world._refresh_anchors()
	return true

func seal(world: RefCounted, relic_id: String, duration: int, source: String, owner: Object) -> bool:
	if not world._driver_allowed(owner) or duration <= 0 or not Store.has(world.state.relics, relic_id) or not Store.has(world.state.facts, source): return false
	world.stage_collections(["relics", "anchors"])
	var relic: Dictionary = Store.entry(world.state.relics, relic_id)
	if relic.placement in ["consumed", "sealed", "seized"]: return false
	_seal_record(world, relic, duration)
	relic.status_source = world._record("relic_sealed", relic.domain, "", [relic_id], [source, relic.origin], {"until": relic.sealed_until})
	if world.history != null: world.history.refresh_relic(world.state, relic_id)
	world._refresh_anchors()
	return true

static func _seal_record(world: RefCounted, relic: Dictionary, duration: int) -> void:
	relic["sealed_from"] = {"placement": relic.placement, "holder": relic.get("holder", ""), "anchor": relic.get("anchor", ""), "domain": relic.domain}
	relic["sealed_until"] = int(world.state.turn) + duration + 1
	relic.placement = "sealed"; relic.holder = ""
	if world.state.anchors.has(relic.get("anchor", "")): world.state.anchors[relic.anchor].state = "dormant"

static func _release_record(world: RefCounted, relic: Dictionary) -> void:
	var prior: Dictionary = relic.get("sealed_from", {})
	relic.placement = "ground"; relic.holder = ""; relic.anchor = ""; relic.captor = ""
	if prior.get("domain") == relic.domain:
		match str(prior.get("placement", "")):
			"carried":
				if _carrier(_current_view(world.state, world.history), str(prior.get("holder", "")), relic.domain, relic.id): relic.placement = "carried"; relic.holder = prior.holder
			"controlled":
				if _has_cult(world.state, relic.domain): relic.placement = "controlled"
			"bound":
				if _has_cult(world.state, relic.domain) and world.state.anchors.has(prior.get("anchor", "")):
					var anchor: Dictionary = world.state.anchors[prior.anchor]
					if anchor.domain == relic.domain and anchor.get("relic") == relic.id and anchor.state != "destroyed" and Store.has(world.state.npcs, anchor.get("guardian", "")):
						var guardian: Dictionary = Store.entry(world.state.npcs, anchor.guardian)
						if guardian.status == "active" and guardian.domain == relic.domain and guardian.get("bound_member", false): relic.placement = "bound"; relic.anchor = prior.anchor
	relic.erase("sealed_from"); relic.erase("sealed_until")

func release_due(world: RefCounted, owner: Object) -> bool:
	if not world._driver_allowed(owner): return false
	var ids: Array = world._keys(world.state.relics) if world.history == null else world.history.ids("relics")
	for id: String in ids:
		var relic: Dictionary = Store.entry(world.state.relics, id)
		if relic.placement != "sealed" or int(relic.get("sealed_until", -1)) > int(world.state.turn): continue
		world.stage_collections(["relics", "anchors"])
		relic = Store.entry(world.state.relics, id)
		_release_record(world, relic)
		relic.status_source = world._record("relic_seal_expired", relic.domain, "", [id], [relic.status_source], {"placement": relic.placement})
		if world.history != null: world.history.refresh_relic(world.state, id)
	world._refresh_anchors()
	return true

static func _current_view(state: Dictionary, index: RefCounted) -> Dictionary:
	if index == null: return state
	var projected: Dictionary = state.duplicate(false)
	projected["relics"] = {}
	for id: String in index.current_ids(state, "relics"):
		projected.relics[id] = Store.entry(state.relics, id)
	return projected

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, index: RefCounted = null) -> Array[String]:
	var issues: Array[String] = []
	for collection: String in ["relics", "facts", "npcs", "domains", "institutions", "anchors", "applied_authorizations"]:
		if not state.get(collection) is Dictionary: return ["Missing relic identity collection: " + collection]
	if state.has("relic_system"):
		if not state.relic_system is Dictionary: return ["Invalid relic rule capabilities"]
		var system: Dictionary = state.relic_system
		if system.get("schema") != SCHEMA or system.get("version") != rule_version(content) or not system.get("issuers") is Dictionary: return ["Invalid relic rule capabilities"]
		for issuer: Variant in system.issuers:
			if not issuer is String or issuer.is_empty() or not system.issuers[issuer] is String or str(system.issuers[issuer]).is_empty(): return ["Invalid relic issuer manifest"]
	var holders: Dictionary = {}
	var origins: Dictionary = {}
	var selected: Dictionary = {}
	if trusted.is_empty():
		for id: String in Store.keys(state.relics): selected[id] = true
	else:
		if index == null: return ["Incremental relic validation requires current identity index"]
		for id: String in index.current_ids(state, "relics"): selected[id] = true
		if Store.overlay(state.relics):
			for id: String in Store.changed(state.relics): selected[id] = true
			for id: String in state.relics.removed: selected[id] = true
		elif not is_same(state.relics, trusted.relics):
			for entry: Dictionary in History.changed_entries(state.relics, trusted.relics): selected[entry.key] = true
	for id: String in selected:
		if not Store.has(state.relics, id): issues.append("Relic identities cannot disappear"); continue
		if not Store.entry(state.relics, id) is Dictionary: issues.append("Invalid relic record"); continue
		var relic: Dictionary = Store.entry(state.relics, id)
		if not trusted.is_empty() and Store.has(trusted.relics, id):
			var prior: Dictionary = Store.entry(trusted.relics, id)
			if prior.get("formal", false) and (relic.get("origin") != prior.origin or relic.get("type") != prior.type or not relic.get("formal", false) or (prior.placement == "consumed" and relic != prior)): issues.append("Relic provenance or consumed tombstone changed")
		if relic.get("placement") == "carried":
			var carrier: String = str(relic.get("holder", ""))
			if holders.has(carrier): issues.append("Repeated relic carrier")
			holders[carrier] = true
		if not relic.get("formal", false): continue
		if not content.tables.relics.has(relic.get("type", "")) or not Store.has(state.facts, relic.get("origin", "")) or not Store.has(state.facts, relic.get("status_source", "")) or not relic.get("placement") in PLACEMENTS: issues.append("Invalid formal relic identity"); continue
		if origins.has(relic.origin) or relic.id != instance_id(relic.origin): issues.append("Repeated relic source")
		origins[relic.origin] = true
		if not Store.entry(state.facts, relic.origin) is Dictionary: issues.append("Invalid relic source record"); continue
		var origin: Dictionary = Store.entry(state.facts, relic.origin)
		if not origin.get("changes") is Dictionary: issues.append("Invalid relic source changes"); continue
		var proof: Variant = origin.get("changes", {}).get("proof")
		var capabilities: Dictionary = state.get("relic_system", {}).get("issuers", {})
		if origin.get("kind") != "relic_create_authorized" or origin.changes.get("relic_type") != relic.type or not proof is Dictionary or proof.get("schema") != SCHEMA or proof.get("domain") != origin.domain or proof.get("target") != relic.type or proof.get("holder", "") != origin.changes.get("holder", "") or not capabilities.has(proof.get("issuer", "")) or capabilities.get(proof.get("issuer", "")) != proof.get("version") or not Store.has(state.applied_authorizations, "relic/create/" + relic.origin): issues.append("Invalid relic creation provenance")
		var holder: String = str(relic.get("holder", ""))
		if relic.placement == "carried":
			if not Store.has(state.npcs, holder) or Store.entry(state.npcs, holder).status == "dead" or Store.entry(state.npcs, holder).domain != relic.domain: issues.append("Invalid unique relic carrier")
		elif not holder.is_empty(): issues.append("Relic placement conflicts with carrier")
		if relic.placement == "bound" and (not state.anchors.has(relic.get("anchor", "")) or state.anchors[relic.anchor].get("relic") != relic.id or state.anchors[relic.anchor].domain != relic.domain): issues.append("Invalid relic anchor")
		if relic.placement == "sealed" and (not relic.get("sealed_from") is Dictionary or not relic.get("sealed_until") is int): issues.append("Invalid relic seal deadline")
	return issues
