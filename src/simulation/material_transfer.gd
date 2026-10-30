extends RefCounted
## Finite record reception. Facts and existing personal knowledge remain authority;
## this helper owns no participant, simulation loop or independent receipt ledger.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Anchors = preload("res://src/game/anchors.gd")
const FIELDS: Array[String] = ["schema", "issuer", "version", "sender", "recipient", "source", "family", "grant", "target_institution", "sender_basis", "channel", "trigger", "visibility"]

static func _deny(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "error": reason}

static func _person(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.get("npcs", {}), id): return Store.entry(state.npcs, id)
	if reader != null and reader.has_method("entity"):
		var found: Dictionary = reader.entity("npcs", id)
		if found.get("ok", false): return found.item
	return {}

static func _fact(state: Dictionary, id: String, reader: RefCounted = null) -> Dictionary:
	if Store.has(state.get("facts", {}), id): return Store.entry(state.facts, id)
	if reader != null and reader.has_method("fact"):
		var found: Dictionary = reader.fact(id)
		if found.get("ok", false): return found.item
	return {}

static func _known(state: Dictionary, person: String, source: String, reader: RefCounted = null) -> bool:
	if reader != null:
		return reader.knows(person, source) if reader.has_method("fact") else reader.knows(state, person, source)
	return History.has(_person(state, person).get("known_facts", []), source)

static func _receipts(state: Dictionary, source: String, reader: RefCounted = null) -> Array:
	if reader != null and reader.has_method("material_receipts"): return reader.material_receipts(source)
	var result: Array = []
	for id: String in Store.keys(state.get("facts", {})):
		var fact: Dictionary = Store.entry(state.facts, id)
		if fact.get("kind") == "material_received" and fact.get("changes", {}).get("source") == source: result.append(id)
	return result

static func resolve(state: Dictionary, source: String, content: RefCounted, reader: RefCounted = null, historical: bool = false) -> Dictionary:
	var material: Dictionary = Anchors.material(state, source, content, reader, true)
	if material.is_empty(): return _deny("unsupported_material")
	var canonical: String = str(material.get("canonical", material.id))
	var actual: Dictionary = _fact(state, canonical, reader)
	var selector: String = ""
	if actual.get("kind") == "prayer_fact": selector = "prayer:" + str(actual.changes.get("tag", ""))
	elif actual.get("kind") == "miracle" and actual.changes.get("power") == "POWER_DREAM": selector = "power:POWER_DREAM/miracle"
	var family: Dictionary = {}
	for row: Dictionary in content.tables.material_transfer_families.values():
		if row.runtime_status != "implemented" or row.knowledge != "1": continue
		var prefix: String = str(row.selector).get_slice(":", 0) + ":"
		for suffix: String in str(row.selector).trim_prefix(prefix).split("|", false):
			if selector == prefix + suffix: family = row; break
		if not family.is_empty(): break
	if family.is_empty(): return _deny("unsupported_material")
	if not historical and not material.get("current", false): return _deny("invalid_material")
	return {"ok": true, "source": canonical, "family": family.id, "row": family, "material": material}

static func possession(state: Dictionary, person: String, resolved: Dictionary, grant: String, content: RefCounted, reader: RefCounted = null) -> String:
	if not resolved.get("ok", false): return ""
	var item: Dictionary = resolved.material
	var known: bool = false
	for source: String in item.knowledge:
		if _known(state, person, source, reader): known = true; break
	if not known: return ""
	if person in item.originals and (grant == "knowledge" or person in item.owners): return resolved.source
	# EVENT05B may confer the original dependency's custody without making its
	# successor an original contracting person or historical witness.
	if person in item.owners and not person in item.originals:
		if item.kind == "contract_dependency":
			for cause: String in (reader.anchor_successors(str(item.data.contract)) if reader != null and reader.has_method("anchor_successors") else []):
				var fact: Dictionary = _fact(state, cause, reader)
				if fact.get("changes", {}).get("successor") == person: return cause
	for id: String in _receipts(state, resolved.source, reader):
		var receipt: Dictionary = _fact(state, id, reader)
		var data: Dictionary = receipt.get("changes", {})
		if data.get("schema") == 2 and data.get("issuer") == "material_reception" and data.get("version") == content.material_transfer_version() and data.get("recipient") == person and (grant == "knowledge" or data.get("grant") == "custody"):
			return id
	return ""

static func internal_channel(state: Dictionary, sender: Dictionary, recipient: Dictionary) -> Dictionary:
	var cult: String = str(sender.get("cult_id", ""))
	if cult.is_empty() or cult != recipient.get("cult_id") or not sender.get("bound_member", false) or not recipient.get("bound_member", false) or not state.get("cults", {}).has(cult): return _deny("no_internal_contact")
	var organization: Dictionary = state.cults[cult]
	if organization.status == "destroyed" or organization.domain != sender.domain or recipient.domain != sender.domain: return _deny("no_internal_contact")
	for person: Dictionary in [sender, recipient]:
		if int(person.get("joined_turn", organization.established_turn)) < int(organization.established_turn): return _deny("no_internal_contact")
	var origin: String = str(sender.get("institution", "")); var target: String = str(recipient.get("institution", ""))
	if origin.is_empty() or target.is_empty() or not state.institutions.has(origin) or not state.institutions.has(target): return _deny("no_internal_contact")
	if origin != target and (not state.institutions[origin].active or not state.institutions[target].active or not target in state.institutions[origin].get("links", []) or not origin in state.institutions[target].get("links", [])): return _deny("no_internal_contact")
	return {"ok": true, "channel": {"kind": "cult_internal", "source": organization.established_source, "from_institution": origin, "to_institution": target}}

## Ignores temporary phase/resource/P/N usage by design: those never create a
## new cooperative endpoint. Callers separately apply original action admission.
static func preview(state: Dictionary, request: Dictionary, content: RefCounted, reader: RefCounted = null, mode: String = "internal") -> Dictionary:
	for key: String in ["sender", "recipient", "source", "target_institution", "grant"]:
		if not request.get(key) is String: return _deny("invalid_material_request")
	if not request.grant in ["knowledge", "custody"]: return _deny("invalid_material_grant")
	var sender: Dictionary = _person(state, request.sender, reader); var recipient: Dictionary = _person(state, request.recipient, reader)
	if sender.is_empty() or recipient.is_empty() or sender.id == recipient.id or sender.status != "active" or recipient.status != "active" or sender.domain != recipient.domain: return _deny("unavailable_material_participant")
	if recipient.get("institution") != request.target_institution or not state.institutions.has(request.target_institution) or state.institutions[request.target_institution].domain != recipient.domain: return _deny("stale_target")
	var resolved: Dictionary = resolve(state, request.source, content, reader)
	if not resolved.ok: return resolved
	if resolved.row[request.grant] != "1": return _deny("nontransferable_qualification")
	if request.grant == "knowledge":
		for known: String in resolved.material.knowledge:
			if _known(state, recipient.id, known, reader): return _deny("already_held")
	var held: String = possession(state, recipient.id, resolved, request.grant, content, reader)
	if not held.is_empty(): return _deny("already_held")
	var sender_basis: String = possession(state, sender.id, resolved, request.grant, content, reader)
	if sender_basis.is_empty(): return _deny("sender_lacks_material")
	var channel: Dictionary = {}
	if mode == "internal":
		var contact: Dictionary = internal_channel(state, sender, recipient)
		if not contact.ok: return contact
		channel = contact.channel
	elif mode == "declared_result":
		channel = request.get("channel", {})
		if channel.get("kind") != "declared_result" or not channel.get("source") is String: return _deny("invalid_declared_result")
	elif mode == "cooperation":
		channel = request.get("channel", {})
		if channel.get("kind") != "cooperation" or not channel.get("source") is String: return _deny("invalid_cooperation")
	else: return _deny("unsupported_material_channel")
	return {"ok": true, "source": resolved.source, "family": resolved.family, "grant": request.grant, "sender": sender.id, "recipient": recipient.id, "target_institution": request.target_institution, "sender_basis": sender_basis, "channel": channel, "faith": content.integer("internal_faith_cost") if mode == "internal" else 0, "whispers": content.integer("internal_whispers_cost") if mode == "internal" else 0, "material": resolved.material}

static func endpoint_available(state: Dictionary, request: Dictionary, content: RefCounted, reader: RefCounted = null) -> bool:
	var target: Dictionary = _person(state, str(request.get("recipient", "")), reader)
	if target.is_empty(): return false
	var ids: Array = reader.ids("active/" + target.domain) if reader != null and reader.has_method("ids") else Store.keys(state.get("npcs", {}))
	for id: String in ids:
		var attempt: Dictionary = request.duplicate(true); attempt.sender = id
		if preview(state, attempt, content, reader).get("ok", false): return true
	return false

static func receive(world: RefCounted, request: Dictionary, trigger: String, owner: Object, mode: String = "internal") -> Dictionary:
	if not world._driver_allowed(owner) or world.transaction == null: return _deny("unmanaged_material_write")
	var plan: Dictionary = preview(world.state, request, world.catalog, world.history, mode)
	if not plan.ok: return plan
	var actual: Dictionary = _fact(world.state, trigger)
	if actual.is_empty() or actual.turn != world.state.turn: return _deny("invalid_material_trigger")
	if mode == "internal":
		if actual.kind != "turn_action" or actual.changes.get("outcome") != "transfer_material" or actual.changes.get("faith_cost") != plan.faith or actual.changes.get("whispers_cost") != plan.whispers or not request.source in actual.causal_parents or actual.changes.get("material") != _endpoint(plan): return _deny("invalid_material_payment")
	elif mode == "cooperation":
		var route: Dictionary = _fact(world.state, str(plan.channel.source))
		if route.get("kind") != "cult_contact_route" or not trigger in route.causal_parents or route.changes.get("recipient") != plan.recipient or route.changes.get("material") != plan.source: return _deny("invalid_cooperative_endpoint")
	else:
		var original: Dictionary = resolve(world.state, str(actual.changes.get("original", "")), world.catalog, world.history)
		if actual.kind != "prayer_fact" or not str(actual.changes.get("tag", "")).ends_with("_learned") or not plan.recipient in actual.targets or actual.changes.get("original") != request.source or not original.get("ok", false) or original.source != plan.source or plan.grant != "knowledge" or plan.channel.source != trigger: return _deny("invalid_declared_result")
	var parents: Array = [plan.source, plan.sender_basis, trigger, plan.channel.source]
	for id: String in [plan.sender, plan.recipient]:
		var person: Dictionary = Store.entry(world.state.npcs, id)
		if mode == "internal" or (mode == "cooperation" and id == plan.recipient):
			for field: String in ["binding_source", "joined_source"]:
				if not str(person.get(field, "")).is_empty(): parents.append(person[field])
	var data: Dictionary = {"schema": 2, "issuer": "material_reception", "version": world.catalog.material_transfer_version(), "sender": plan.sender, "recipient": plan.recipient, "source": plan.source, "family": plan.family, "grant": plan.grant, "target_institution": plan.target_institution, "sender_basis": plan.sender_basis, "channel": plan.channel, "trigger": trigger, "visibility": "private"}
	world.stage_current()
	var receipt: String = world._record("material_received", actual.domain, plan.sender, [plan.sender, plan.recipient, plan.target_institution], world._unique_sorted(parents), data)
	if mode == "declared_result": world._know(plan.recipient, request.source)
	world._know(plan.recipient, plan.source)
	world._know(plan.recipient, receipt)
	if not Anchors.refresh_basis(world, owner, [plan.source]): return _deny("material_basis_refresh_failed")
	return {"ok": true, "receipt": receipt, "source": plan.source, "grant": plan.grant}

static func _endpoint(plan: Dictionary) -> Dictionary:
	return {"sender": plan.sender, "recipient": plan.recipient, "source": plan.source, "target_institution": plan.target_institution, "grant": plan.grant}

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, reader: RefCounted = null) -> Array[String]:
	for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
		var receipt: Dictionary = _fact(state, "FACT-%08d" % number)
		if receipt.get("kind") != "material_received": continue
		var data: Dictionary = receipt.get("changes", {})
		if data.size() != FIELDS.size(): return ["Invalid material receipt schema"]
		for field: String in FIELDS:
			if not data.has(field): return ["Missing material receipt field: " + field]
		if data.schema != 2 or data.issuer != "material_reception" or data.version != content.material_transfer_version() or not data.grant in ["knowledge", "custody"] or not data.visibility in ["private", "public"]: return ["Incompatible material receipt policy"]
		for field: String in ["sender", "recipient", "source", "family", "target_institution", "sender_basis", "trigger"]:
			if not data[field] is String: return ["Malformed material receipt identity"]
		var resolved: Dictionary = resolve(state, data.source, content, reader, true)
		if not resolved.ok or resolved.source != data.source or resolved.family != data.family or resolved.row[data.grant] != "1": return ["Material receipt does not reference an installed canonical material"]
		if not state.institutions.has(data.target_institution) or not Store.has(state.npcs, data.sender) or not Store.has(state.npcs, data.recipient) or data.sender == data.recipient: return ["Material receipt lost actual people or original target"]
		if not data.channel is Dictionary or data.channel.size() != 4 or not data.channel.get("kind") in ["cult_internal", "existing_relation", "institution_link", "cooperation", "declared_result"] or data.channel.get("to_institution") != data.target_institution: return ["Invalid material receipt channel"]
		for field: String in ["source", "from_institution", "to_institution"]:
			if not data.channel.get(field) is String: return ["Malformed material channel"]
		for source: String in [data.source, data.sender_basis, data.trigger, data.channel.source]:
			if not source in receipt.causal_parents or _fact(state, source).is_empty() or source >= receipt.id: return ["Material receipt lost prior actual cause"]
		var basis: Dictionary = _fact(state, data.sender_basis)
		if data.sender_basis == data.source:
			if not data.sender in resolved.material.originals: return ["Material sender never held its original result"]
		elif basis.kind == "material_received":
			if basis.changes.get("recipient") != data.sender or basis.changes.get("source") != data.source or (data.grant == "custody" and basis.changes.get("grant") != "custody"): return ["Material sender's prior receipt does not confer this grant"]
		elif basis.kind != "contract_successor_authorized" or basis.changes.get("successor") != data.sender or resolved.material.kind != "contract_dependency": return ["Unsupported original sender basis"]
		var trigger: Dictionary = _fact(state, data.trigger)
		if trigger.turn != receipt.turn: return ["Material receipt changed its actual action turn"]
		if data.channel.kind == "cult_internal" and (trigger.kind != "turn_action" or trigger.changes.get("outcome") != "transfer_material" or trigger.changes.get("faith_cost") != content.integer("internal_faith_cost") or trigger.changes.get("whispers_cost") != content.integer("internal_whispers_cost") or trigger.changes.get("material") != _endpoint(data) or not data.source in trigger.causal_parents): return ["Material receipt lost its unique payment"]
		if data.channel.kind == "declared_result":
			var original: Dictionary = resolve(state, str(trigger.changes.get("original", "")), content, reader, true)
			if trigger.kind != "prayer_fact" or not str(trigger.changes.get("tag", "")).ends_with("_learned") or not original.get("ok", false) or original.source != data.source or trigger.changes.get("subjects", {}).get("petitioner") != data.sender or not data.recipient in trigger.targets or data.channel.source != trigger.id or data.grant != "knowledge": return ["Material receipt lost its declared personal result"]
		if data.channel.kind == "cooperation":
			var route: Dictionary = _fact(state, data.channel.source)
			if route.get("kind") != "cult_contact_route" or not data.trigger in route.causal_parents or route.changes.get("recipient") != data.recipient or route.changes.get("material") != data.source: return ["Material receipt lost its actual cooperative endpoint"]
		if not _known(state, data.recipient, data.source) or not _known(state, data.recipient, receipt.id): return ["Material recipient lost its exact knowledge"]
	return []
