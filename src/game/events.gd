extends RefCounted
## Managed event pool. Handlers only declare effects; all selection and writes
## occur in the Turn transaction using the independent events random stream.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Rules = preload("res://src/game/event_rules.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Relics = preload("res://src/game/relics.gd")
const Prayers = preload("res://src/game/prayers.gd")
const Cults = preload("res://src/game/cults.gd")
const Economy = preload("res://src/game/economy.gd")
const Dispatch = preload("res://src/game/prayer_dispatch.gd")
const ID: String = "events"
const SCHEMA: int = 1
var catalog: RefCounted
var version: String
var mode_handlers: Dictionary
var candidate_handlers: Dictionary

func _init(content: RefCounted) -> void:
	catalog = content; version = rule_version(content)
	mode_handlers = {"detailed_candidates": Callable(self, "detailed_candidates"), "abstract_candidates_due": Callable(self, "abstract_candidates_due")}
	candidate_handlers = {"ROOT_CURRENT_APPEAL": Callable(self, "_legacy_candidate"), "ROOT_CURRENT_PASSAGE": Callable(self, "_legacy_candidate"), "ROOT_KNOWN_RECORD": Callable(self, "_legacy_candidate"), "ROOT_CURRENT_RITUAL": Callable(self, "_legacy_candidate"), "ROOT_IDENTITY_NOTICE": Callable(self, "_identity_notice")}

static func rule_version(content: RefCounted) -> String:
	var parts: Array = ["2/dispatch1", content.version]
	for key: String in ["events", "event_effects", "event_sources", "event_operations", "anchor_conditions", "anchor_restrictions", "prayer_effects", "relics", "relic_effects"]: parts.append(str(content.extension_versions.get(key, "missing")))
	return "/".join(parts)

static func issuer_capability(content: RefCounted) -> Dictionary:
	return {ID: rule_version(content)}

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("event_system") or not turn.world.state.has("simulation"): return false
	for root: String in ["prayer_system", "anchor_system", "relic_system", "economy"]:
		if turn.world.state.has(root) and turn.world.state[root].get("issuers", {}).get(ID) != version: return false
	for table: String in ["event_sources", "event_operations"]:
		if not catalog.tables.has(table): return false
	turn.world.state["event_system"] = {"schema": SCHEMA, "version": version, "pending": {}, "records": {}, "cards": {}, "cooldowns": {}, "selected": [], "selected_turn": 0, "prophets": {}, "permits": {}}
	if not turn.register_participant(ID, version, ["events", "events_collect", "events_deadlines", "actions", "candidate_generation"], ["events"], handle):
		turn.world.state.erase("event_system"); return false
	# Installation is the sole full-history intake. Normal turns receive only
	# newly committed sources; inactive history never reenters the hot queue.
	for fact: Dictionary in Store.values(turn.world.state.facts): observe(turn.world, fact.id)
	return Dispatch.install(turn.world)

func prepare_generation(world: RefCounted, view: Dictionary, owner: Object) -> Dictionary:
	return Dispatch.prepare(world, view, self, owner)

func commit_generation(world: RefCounted, plan: Dictionary, owner: Object) -> bool:
	return Dispatch.commit(world, plan, self, owner)

func detailed_candidates(world: RefCounted, view: Dictionary, summaries: Dictionary, domain: String, sample: Dictionary) -> Dictionary:
	return Dispatch.prepare_domain(world, view, summaries, domain, sample, "detailed_candidates")

func abstract_candidates_due(world: RefCounted, view: Dictionary, summaries: Dictionary, domain: String, sample: Dictionary) -> Dictionary:
	return Dispatch.prepare_domain(world, view, summaries, domain, sample, "abstract_candidates_due")

func _legacy_candidate(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	return Dispatch.legacy(world, choice, owner)

func _identity_notice(world: RefCounted, choice: Dictionary, owner: Object) -> Dictionary:
	return Dispatch.notice(world, choice, self, owner)

static func observe(world: RefCounted, source: String) -> void:
	if not world.state.has("event_system"): return
	var fact: Dictionary = Rules.fact(world.state, source)
	if fact.is_empty(): return
	var pending: bool = (fact.kind == "prayer_fact" and fact.changes.get("tag") == "future_callback") or fact.kind in ["prayer_window_due", "resistance_started"] or (fact.kind == "miracle" and fact.changes.get("power") == "POWER_DREAM")
	if not pending: return
	world.stage_collections(["event_system"])
	if pending: world.state.event_system.pending[source] = fact.turn

func _result(effects: Array, meta: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {"ok": true, "empty": effects.is_empty(), "effects": effects, "state": {}}
	if not meta.is_empty(): value["meta"] = meta
	return value

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	var slot: String = str(input.get("slot", ""))
	if slot in ["events_collect", "events_deadlines"]: return _result([{"type": "events", "operation": slot}])
	if slot == "events" and input.get("operation") == "gather": return _result([{"type": "events", "operation": "gather"}])
	if slot == "events" and input.get("operation") == "resolve_event":
		var prepared: Dictionary = prepare(view, str(input.get("event", "")), str(input.get("action", "")), false, input.get("selection", {}))
		if not prepared.ok:
			var id: String = str(input.get("event", ""))
			var entry: Dictionary = view.world.get("event_system", {}).get("cards", {}).get(id, {})
			if input.get("default_choice", false) and not entry.is_empty() and input.get("action") == entry.descriptor.default_action:
				var descriptor: Dictionary = entry.descriptor
				var attention: Dictionary = {"family": "event", "content_id": descriptor.content_id, "variant": descriptor.default_action, "target": descriptor.domain, "candidate": id, "fixed": descriptor.actors.duplicate(), "participants": []}
				return _result([{"type": "events", "operation": "cancel", "event": id}], _meta(entry.card.fact, descriptor.domain, 0, attention))
			return prepared
		return _result([{"type": "events", "operation": "resolve", "plan": prepared.plan}], prepared.meta)
	if slot == "actions" and input.get("action") == "opportunity":
		var prepared: Dictionary = prepare_opportunity(view, input.get("payload", {}))
		if not prepared.ok: return prepared
		return _result([{"type": "events", "operation": "opportunity", "plan": prepared.plan}], prepared.meta)
	return {"ok": false}

func _view(turn: RefCounted) -> Dictionary:
	return turn._read_view(ID, "events")

func preview(turn: RefCounted, event: String, option: String, options: Dictionary = {}) -> Dictionary:
	if turn._in_transaction or turn._in_participant: return {"ok": false, "error": "Unavailable during transaction"}
	var prepared: Dictionary = prepare(_view(turn), event, option, false, options)
	if not prepared.ok: return prepared
	return {"ok": true, "preview": prepared.plan.duplicate(true)}

func preview_opportunity(turn: RefCounted, payload: Dictionary) -> Dictionary:
	if turn._in_transaction or turn._in_participant: return {"ok": false, "error": "Unavailable during transaction"}
	var prepared: Dictionary = prepare_opportunity(_view(turn), payload)
	return {"ok": true, "preview": prepared.plan.duplicate(true)} if prepared.ok else prepared

func _meta(source: String, domain: String, cost: int, attention: Dictionary) -> Dictionary:
	return {"faith_cost": cost, "whispers_cost": 0, "min_awakening": 0, "responds": false, "used_power": false, "used_relic": false, "actor": "", "source": source, "target": domain, "outcome": "event_choice", "attention": attention}

func _operations(content_id: String, option: String) -> Array:
	var found: Array = []
	for row: Dictionary in catalog.tables.event_operations.values():
		if row.event_id == content_id and row.option == option: found.append(row.duplicate(true))
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return found

func prepare(view: Dictionary, id: String, option: String, automated: bool = false, selection: Dictionary = {}) -> Dictionary:
	var state: Dictionary = view.world; var reader: RefCounted = view.get("reader")
	var ledger: Dictionary = state.get("event_system", {})
	if not ledger.get("cards", {}).has(id): return {"ok": false, "error": "Unknown fixed event"}
	var entry: Dictionary = ledger.cards[id]; var descriptor: Dictionary = entry.descriptor
	if not automated and (not id in ledger.get("selected", []) or ledger.selected_turn != state.turn): return {"ok": false, "error": "Event is not in this frozen offer"}
	if not Rules.auth(state, "event/resolved/" + id, reader).is_empty(): return {"ok": false, "error": "Event was already resolved"}
	var valid: Dictionary = Rules.legal(state, descriptor, option, catalog, reader)
	if not valid.ok: return valid
	if (descriptor.content_id == "EVENT_02" and option == "B") or (descriptor.content_id == "EVENT_04" and option == "A"):
		var recognition: Dictionary = Rules.prospective_recognition(state, descriptor, catalog, reader)
		if not recognition.ok: return recognition
	if descriptor.content_id == "EVENT_12" and option == "B":
		var reopened: Dictionary = Prayers.new(catalog, state.prayer_system.issuers).preview_reopen(state, descriptor.facts.registration, descriptor.facts.expiry, reader)
		if not reopened.ok: return reopened
	var selected: Dictionary = {}
	if descriptor.content_id == "EVENT_06" and option == "B":
		for key: Variant in selection:
			if key != "qualification" or not selection[key] is String or str(selection[key]).is_empty(): return {"ok": false, "error": "Only a fixed memory qualification can be selected"}
		var chosen: String = str(selection.get("qualification", ""))
		if chosen.is_empty():
			for source: String in descriptor.facts.qualifications:
				if Rules.current(state, source, reader): chosen = source; break
		if not chosen in descriptor.facts.qualifications or not Rules.current(state, chosen, reader): return {"ok": false, "error": "Selected memory qualification is not current in this fixed event"}
		selected["qualification"] = chosen
	elif not selection.is_empty(): return {"ok": false, "error": "This event option does not accept a qualification selection"}
	var rows: Array = _operations(descriptor.content_id, option)
	if rows.is_empty(): return {"ok": false, "error": "Event option has no operations"}
	var rule: Dictionary = catalog.tables.event_effects[descriptor.content_id + "/" + option]
	var fee: int = int(rule.faith_cost)
	if int(state.faith) < fee: return {"ok": false, "error": "Insufficient faith"}
	var participants: Array = descriptor.actors.filter(func(npc: String) -> bool: return Rules.alive(state, npc, reader))
	var attention: Dictionary = {"family": "event", "content_id": descriptor.content_id, "variant": option, "target": descriptor.domain, "candidate": id, "fixed": descriptor.actors.duplicate(), "participants": participants}
	var plan: Dictionary = {"event": id, "content_id": descriptor.content_id, "option": option, "domain": descriptor.domain, "institution": descriptor.institution, "subjects": descriptor.subjects.duplicate(true), "facts": descriptor.facts.duplicate(true), "source": descriptor.source, "descriptor": descriptor.duplicate(true), "faith_cost": fee, "operations": rows, "attention": attention, "irreversible": rule.irreversible_cost, "selection": selected}
	return {"ok": true, "plan": plan, "meta": _meta(entry.card.fact, descriptor.domain, fee, attention)}

func prepare_opportunity(view: Dictionary, payload: Dictionary) -> Dictionary:
	var state: Dictionary = view.world; var index: RefCounted = view.get("reader")
	if not payload.get("opportunity") is String or not payload.get("option") in ["recover", "public", "wait"]: return {"ok": false, "error": "Unknown opportunity action"}
	for key: Variant in payload:
		if not key in ["opportunity", "option", "npc"]: return {"ok": false, "error": "Unknown opportunity argument"}
	var source: Dictionary = Rules.fact(state, payload.opportunity, index)
	if source.get("kind") != "institution_relic_opportunity" or int(source.changes.due) < int(state.turn) or state.get("anchor_system", {}).get("opportunities", {}).get(source.changes.institution) != source.id or not Rules.auth(state, "anchor/opportunity/" + source.id, index).is_empty(): return {"ok": false, "error": "Opportunity is closed or unknown"}
	var npc: String = str(payload.get("npc", "")); var placement: String = "controlled"
	if payload.option == "recover" and Rules.cult(state, source.domain).is_empty():
		placement = "carried"
		if not Rules.alive(state, npc, index, true) or Rules.person(state, npc, index).domain != source.domain or not Rules.person(state, npc, index).get("bound_member", false): return {"ok": false, "error": "Recovery needs a local cult inventory or actual member carrier"}
	var fee: int = catalog.integer("relic_recovery_faith") if payload.option == "recover" else 0
	if int(state.faith) < fee: return {"ok": false, "error": "Insufficient recovery faith"}
	var attention: Dictionary = {"family": "system", "content_id": "RELIC_RECOVER" if payload.option == "recover" else ("RELIC_PUBLIC" if payload.option == "public" else "REST"), "variant": "use", "target": source.domain, "participants": [npc] if placement == "carried" else [], "fixed": [npc] if placement == "carried" else []}
	var plan: Dictionary = {"opportunity": source.id, "option": payload.option, "npc": npc, "placement": placement, "institution": source.changes.institution, "domain": source.domain, "relic_type": source.changes.relic_type, "faith_cost": fee, "attention": attention}
	return {"ok": true, "plan": plan, "meta": _meta(source.id, source.domain, fee, attention)}

static func offered(world: RefCounted) -> Array:
	var result: Array = []
	for id: String in world.state.event_system.selected:
		if not world.state.event_system.cards.has(id): continue
		var entry: Dictionary = world.state.event_system.cards[id]
		result.append({"id": id, "default_action": entry.descriptor.default_action, "source": entry.card.fact, "payload": {"candidate": id}})
	return result

func validate_effect(state: Dictionary, slot: String, effect: Dictionary, index: RefCounted = null) -> bool:
	if state.get("event_system", {}).get("version") != version: return false
	var operation: String = str(effect.get("operation", ""))
	if operation in ["gather", "events_collect", "events_deadlines"]: return operation == "gather" and slot == "events" or operation == slot
	if operation == "cancel" and slot == "events":
		var id: String = str(effect.get("event", "")); var entry: Dictionary = state.event_system.cards.get(id, {})
		return not entry.is_empty() and id in state.event_system.selected and not prepare({"world": state, "reader": index}, id, entry.descriptor.default_action, true).ok
	if not effect.get("plan") is Dictionary: return false
	var view: Dictionary = {"world": state, "reader": index}
	if operation == "resolve" and slot == "events":
		var actual: Dictionary = prepare(view, str(effect.plan.get("event", "")), str(effect.plan.get("option", "")), false, effect.plan.get("selection", {}))
		return actual.ok and actual.plan == effect.plan
	if operation == "opportunity" and slot == "actions":
		var actual: Dictionary = prepare_opportunity(view, {"opportunity": effect.plan.get("opportunity"), "option": effect.plan.get("option"), "npc": effect.plan.get("npc", "")})
		return actual.ok and actual.plan == effect.plan
	return false

func _proof_record_bundle(state: Dictionary, ids: Array, descriptor: Dictionary, family: String, required: int, index: RefCounted) -> Array:
	var candidates: Array = []
	var network: bool = state.domains[descriptor.domain].profile == "CIV_05" and descriptor.content_id == "EVENT_02"
	for id: String in ids:
		var record: Dictionary = Anchors._evidence_record(state, id, index, true) if descriptor.content_id == "EVENT_02" else Rules.actual_prayer(state, id, index)
		if record.is_empty() or not Rules.current(state, id, index) or not Rules.alive(state, Rules.record_witness(record), index): continue
		if descriptor.content_id == "EVENT_02":
			if not record.tag in Anchors.EVIDENCE + ["dream"] or record.family != family: continue
			if record.institution != descriptor.institution and not (network and Anchors._connected(state, descriptor.institution, record.institution)): continue
		else:
			if record.institution != descriptor.institution or record.base.changes.prayer != "PRAYER_05" or not record.tag in ["ritual_witness", "public_ritual"] or Rules.record_witness(record) != descriptor.subjects.get("priest"): continue
		candidates.append(record)
	return _record_combination(candidates, [], 0, required, descriptor.content_id == "EVENT_02", network, descriptor.institution)

func _record_combination(candidates: Array, selected: Array, offset: int, required: int, evidence: bool, network: bool, institution: String) -> Array:
	if selected.size() >= required: return selected
	var best: Array = selected
	for position: int in range(offset, candidates.size()):
		var record: Dictionary = candidates[position]
		if network and selected.is_empty() and record.institution != institution: continue
		var independent: bool = true
		for previous: Dictionary in selected:
			if previous.base.id == record.base.id or (evidence and Rules.record_witness(previous) == Rules.record_witness(record)) or (network and previous.institution == record.institution) or (not network and int(previous.base.turn) == int(record.base.turn)): independent = false; break
		if not independent: continue
		var next: Array = selected.duplicate(); next.append(record)
		var found: Array = _record_combination(candidates, next, position + 1, required, evidence, network, institution)
		if found.size() >= required: return found
		if found.size() > best.size(): best = found
	return best

func _enrich(world: RefCounted, descriptor: Dictionary) -> void:
	var state: Dictionary = world.state; var facts: Dictionary = descriptor.facts; var subjects: Dictionary = descriptor.subjects
	var institution: String = descriptor.institution; var profile: String = state.domains[descriptor.domain].profile
	if descriptor.content_id in ["EVENT_02", "EVENT_04"]:
		var collected: Array = []; var witnesses: Array = []; var turns: Array = []; var recipients: Array = []
		var desired_family: String = Rules.record_family(state, str(facts.get("records", [""])[0]), world.history) if descriptor.content_id == "EVENT_02" else ""
		var ids: Array = []
		var institutions: Array = [institution]
		if profile == "CIV_05":
			for other: String in state.institutions[institution].links:
				if Anchors._connected(state, institution, other): institutions.append(other)
		var family: String = "evidence" if descriptor.content_id == "EVENT_02" else "ritual"
		var blueprint: Dictionary = Anchors._row(state, institution, catalog)
		var required: int = 1
		if blueprint.get("event_id") == descriptor.content_id:
			if not str(blueprint.get("count_parameter", "")).is_empty(): required = catalog.integer(blueprint.count_parameter)
			elif blueprint.get("rule") == "network_evidence": required = 2
		for office: String in institutions:
			for npc: String in world._living_ids():
				for id: String in world.history.event_record_heads(office, npc, family):
					if not id in ids: ids.append(id)
				if descriptor.content_id == "EVENT_02":
					for id: String in world.history.event_record_heads(office, npc, "dream"):
						if not id in ids: ids.append(id)
		ids.sort_custom(func(a: String, b: String) -> bool:
			if profile == "CIV_05":
				var left: Dictionary = Anchors._evidence_record(state, a, world.history, true); var right: Dictionary = Anchors._evidence_record(state, b, world.history, true)
				if left.get("institution") == institution and right.get("institution") != institution: return true
				if left.get("institution") != institution and right.get("institution") == institution: return false
			return a < b)
		var bundle: Array = _proof_record_bundle(state, ids, descriptor, desired_family, required, world.history)
		for record: Dictionary in bundle:
			collected.append(record.record.id); witnesses.append(Rules.record_witness(record)); turns.append(int(record.base.turn)); recipients.append(record.institution)
			if profile == "CIV_05" and record.institution != institution: subjects["other_institution"] = record.institution
		if descriptor.content_id == "EVENT_02" and not collected.is_empty():
			# Local record comes first for the network blueprint.
			if profile == "CIV_05" and recipients[0] != institution and recipients.has(institution):
				var local: int = recipients.find(institution); collected.push_front(collected.pop_at(local)); witnesses.push_front(witnesses.pop_at(local))
			facts.records = collected; subjects.witnesses = witnesses
		elif descriptor.content_id == "EVENT_04" and not collected.is_empty(): facts.rituals = collected
	if descriptor.content_id == "EVENT_03":
		var former: String = str(descriptor.get("prayer_descriptor", {}).get("subjects", {}).get("petitioner", "")); subjects["former"] = former
		for id: String in world.institution_successors(institution):
			if id == former: continue
			for role: String in ["cooperator", "opponent"]:
				if subjects.has(role): continue
				var kinds: Array = ["support", "cooperation"] if role == "cooperator" else ["rival", "hostile"]
				var relation: Dictionary = world.history.relation_head(former, id, kinds)
				if relation.is_empty(): relation = world.history.relation_head(id, former, kinds)
				if not relation.is_empty() and Rules.relation_current(state, relation.source, former, id, kinds, world.history):
					subjects[role] = id
					if not relation.source in facts.relations: facts.relations.append(relation.source)
	if descriptor.content_id == "EVENT_04":
		var priest: String = str(subjects.get("priest", ""))
		for id: String in world._living_ids():
			if id == priest: continue
			var relation: Dictionary = world.history.relation_head(priest, id, ["support", "cooperation"])
			if relation.is_empty(): relation = world.history.relation_head(id, priest, ["support", "cooperation"])
			if relation.is_empty(): continue
			var proposed: Dictionary = descriptor.duplicate(true)
			proposed.subjects["heretic"] = id; proposed.facts["relation"] = relation.source
			for ritual: String in facts.get("rituals", []):
				var record: Dictionary = Rules.actual_prayer(state, ritual, world.history)
				if record.is_empty(): continue
				proposed.facts["knowledge"] = Rules.auth(state, "prayer/response/" + str(record.base.changes.request))
				if Rules.heretic_legal(state, proposed, catalog, world.history):
					subjects["heretic"] = id; facts["relation"] = relation.source; facts["knowledge"] = proposed.facts.knowledge; break
			if subjects.has("heretic"): break
	if descriptor.content_id == "EVENT_05":
		for document: String in world.history.event_inheritance(facts.contract):
			var inheritance: Dictionary = Rules.inheritance(state, document, facts.contract, world.history)
			if inheritance.is_empty(): continue
			subjects["successor"] = inheritance.successor; facts["inheritance"] = document; facts["relation"] = inheritance.relation; break
	if descriptor.content_id == "EVENT_07":
		for document: String in world.history.event_will(subjects.prophet, facts.prophet):
			var legacy: Dictionary = Rules.will(state, document, subjects.prophet, facts.prophet, world.history)
			if legacy.is_empty(): continue
			subjects["successor"] = legacy.successor; facts["will"] = document; facts["succession"] = document; break
	if descriptor.content_id == "EVENT_11":
		var exception: String = facts.record
		if Rules.fact(state, exception).get("kind") == "exception":
			for other: String in state.institutions[institution].links:
				if not Anchors._connected(state, institution, other): continue
				var local: String = ""; var remote: String = ""
				for id: String in world.history.event_record_heads(institution, "", "exception/" + exception):
					var record: Dictionary = Anchors._evidence_record(state, id, world.history)
					if not record.is_empty() and record.institution == institution and world.history.knows(state, institution, id, true): local = id; break
				for id: String in world.history.event_record_heads(other, "", "exception/" + exception):
					var record: Dictionary = Anchors._evidence_record(state, id, world.history)
					if not record.is_empty() and record.institution == other and world.history.knows(state, other, id, true): remote = id; break
				if local.is_empty() or remote.is_empty(): continue
				var first: Dictionary = Rules.actual_prayer(state, local, world.history); var second: Dictionary = Rules.actual_prayer(state, remote, world.history)
				if first.is_empty() or second.is_empty() or first.base.id == second.base.id: continue
				subjects["other_institution"] = other; facts["exception"] = exception; facts["records"] = [local, remote]; break
	var actors: Array = descriptor.actors.duplicate()
	for value: Variant in subjects.values():
		var values: Array = value if value is Array else [value]
		for id: Variant in values:
			if id is String and Store.has(state.npcs, id) and not id in actors: actors.append(id)
	actors = actors.filter(func(id: String) -> bool: return Rules.alive(state, id))
	actors.sort(); descriptor.actors = actors
	descriptor.source_ids = Rules.roots(facts)
	if not descriptor.source in descriptor.source_ids: descriptor.source_ids.append(descriptor.source)
	descriptor["basis"] = Rules.proof_basis(state, descriptor, catalog, world.history)

func _collect(world: RefCounted, owner: Object) -> bool:
	var ledger: Dictionary = world.state.event_system
	var pending: Array = ledger.pending.keys(); pending.sort()
	for source: String in pending:
		if not _confirm_exception(world, source, owner): return false
		var descriptor: Dictionary = Rules.descriptor(world.state, source, catalog, world.history)
		if descriptor.is_empty(): ledger.pending.erase(source); continue
		if not catalog.tables.event_sources.has(descriptor.content_id): return false
		if Rules.fact(world.state, source).kind != "resistance_started" and int(descriptor.visible_turn) > int(world.state.turn): continue
		if not Rules.auth(world.state, descriptor.once_key).is_empty(): ledger.pending.erase(source); continue
		if descriptor.due_turn < world.state.turn:
			var expired: String = world._record("event_source_expired", descriptor.domain, "", descriptor.actors, [source], {"descriptor": descriptor})
			Store.put(world.state.applied_authorizations, descriptor.once_key, expired); ledger.pending.erase(source); continue
		_enrich(world, descriptor)
		var fixed: Dictionary = world.fix_event_candidate(descriptor, owner)
		if not fixed.get("ok", false):
			# Capacity is a real admission failure; leave the source pending until
			# its original window ends rather than deleting causal work.
			continue
		var card: Dictionary = world.state.simulation.candidates[fixed.id]
		ledger.cards[fixed.id] = {"card": card.duplicate(true), "descriptor": descriptor.duplicate(true), "status": "pending"}
		ledger.pending.erase(source)
	return true

func _finish(world: RefCounted, id: String, source: String, reason: String) -> void:
	var entry: Dictionary = world.state.event_system.cards[id]
	Store.put(world.state.applied_authorizations, "event/resolved/" + id, source)
	world.state.event_system.cooldowns[entry.descriptor.content_id + "/" + entry.descriptor.mutex] = world.state.turn + int(catalog.tables.events[entry.descriptor.content_id].cooldown)
	if world.state.simulation.candidates.has(id): world._close_background(world.state.simulation.candidates[id], "event_" + reason)
	world.state.event_system.cards.erase(id)

func _cancel(world: RefCounted, id: String, reason: String) -> void:
	var entry: Dictionary = world.state.event_system.cards[id]
	var result: String = world._record("event_cancelled", entry.descriptor.domain, "", entry.descriptor.actors, [entry.card.fact, entry.descriptor.source], {"event": id, "content_id": entry.descriptor.content_id, "reason": reason, "descriptor": entry.descriptor})
	_finish(world, id, result, reason)

func _gather(world: RefCounted, owner: Object) -> bool:
	if not _collect(world, owner): return false
	var ledger: Dictionary = world.state.event_system
	if ledger.selected_turn == world.state.turn: return false
	ledger.selected = []; ledger.selected_turn = world.state.turn
	for key: String in ledger.cooldowns.keys():
		if int(ledger.cooldowns[key]) < int(world.state.turn): ledger.cooldowns.erase(key)
	var choices: Array = []
	var ids: Array = ledger.cards.keys(); ids.sort()
	for id: String in ids:
		var entry: Dictionary = ledger.cards[id]; var descriptor: Dictionary = entry.descriptor
		var eligibility_view: Dictionary = {"world": world.state, "reader": world.history}
		var allowed: bool = prepare(eligibility_view, id, "A", true).ok or prepare(eligibility_view, id, "B", true).ok
		if not allowed: _cancel(world, id, "fixed_target_unavailable"); continue
		if int(descriptor.due_turn) < int(world.state.turn): _cancel(world, id, "window_expired"); continue
		if int(descriptor.visible_turn) > int(world.state.turn): continue
		if ledger.cooldowns.has(descriptor.content_id + "/" + descriptor.mutex): continue
		choices.append(id)
	choices.sort_custom(func(a: String, b: String) -> bool:
		var left: Dictionary = ledger.cards[a].descriptor; var right: Dictionary = ledger.cards[b].descriptor
		var left_layer: int = _layer(left, int(world.state.turn)); var right_layer: int = _layer(right, int(world.state.turn))
		if left_layer != right_layer: return left_layer < right_layer
		if int(left.priority) != int(right.priority): return int(left.priority) > int(right.priority)
		if int(left.due_turn) != int(right.due_turn): return int(left.due_turn) < int(right.due_turn)
		if left.source != right.source: return str(left.source) < str(right.source)
		return a < b)
	var mutexes: Array = []
	while not choices.is_empty() and ledger.selected.size() < catalog.integer("major_event_limit"):
		var first: Dictionary = ledger.cards[choices[0]].descriptor; var peers: Array = []
		for id: String in choices:
			var candidate: Dictionary = ledger.cards[id].descriptor
			if _layer(candidate, int(world.state.turn)) == _layer(first, int(world.state.turn)) and candidate.due_turn == first.due_turn and candidate.priority == first.priority: peers.append(id)
		var selected: String = peers[world.randoms.events.randi_range(0, peers.size() - 1)] if peers.size() > 1 else peers[0]
		choices.erase(selected)
		var group: String = ledger.cards[selected].descriptor.mutex
		if group in mutexes: continue
		mutexes.append(group); ledger.selected.append(selected)
		ledger.cards[selected].status = "offered"
	return _due_plans(world, owner, true)

func _layer(descriptor: Dictionary, turn: int) -> int:
	if descriptor.content_id in ["EVENT_08", "EVENT_11"] and int(descriptor.due_turn) <= turn: return 0
	if catalog.tables.events[descriptor.content_id].family == "ambient": return 3
	return 1 if int(descriptor.due_turn) <= turn else 2

func _deadlines(world: RefCounted, owner: Object) -> bool:
	var ids: Array = world.state.event_system.cards.keys(); ids.sort()
	for id: String in ids:
		var entry: Dictionary = world.state.event_system.cards[id]
		if entry.descriptor.due_turn <= world.state.turn and not entry.descriptor.content_id in ["EVENT_08", "EVENT_11"]: _cancel(world, id, "window_expired")
	return _due_plans(world, owner, false)

func _due_plans(world: RefCounted, owner: Object, skip_selected: bool) -> bool:
	var ids: Array = world.state.event_system.cards.keys(); ids.sort()
	for id: String in ids:
		if not world.state.event_system.cards.has(id): continue
		var entry: Dictionary = world.state.event_system.cards[id]
		if entry.descriptor.due_turn > world.state.turn or not entry.descriptor.content_id in ["EVENT_08", "EVENT_11"]: continue
		if skip_selected and id in world.state.event_system.selected: continue
		var prepared: Dictionary = prepare({"world": world.state}, id, entry.descriptor.default_action, true)
		if prepared.ok:
			prepared.plan["default"] = true
			if not _resolve(world, prepared.plan, owner): return false
		else: _cancel(world, id, "deadline_target_unavailable")
	for domain: Dictionary in world.state.domains.values():
		var pending: Dictionary = domain.pending_plan
		if pending.is_empty() or int(pending.due) > int(world.state.turn) or not (pending.rule == "RESIST_REWRITE" or (pending.rule == "RESIST_TRACE" and Store.has(world.state.relics, pending.target))): continue
		var selected_plan: bool = false
		if skip_selected:
			for id: String in world.state.event_system.selected:
				if world.state.event_system.cards.has(id) and world.state.event_system.cards[id].descriptor.source == pending.started_fact: selected_plan = true; break
		if selected_plan: continue
		var descriptor: Dictionary = Rules.descriptor(world.state, pending.started_fact, catalog, world.history)
		if descriptor.is_empty(): return false
		var id: String = "PLAN/" + pending.started_fact
		if not Rules.auth(world.state, "event/resolved/" + id).is_empty(): return false
		var operations: Array = _operations(descriptor.content_id, descriptor.default_action)
		var names: Array = []
		for row: Dictionary in operations: names.append(row.id)
		var result: String = world._record("event_result", descriptor.domain, "", [], [pending.started_fact], {"event": id, "content_id": descriptor.content_id, "option": descriptor.default_action, "descriptor": descriptor, "operations": names, "payment": "", "default": true, "handoff": true})
		Store.put(world.state.applied_authorizations, "event/resolved/" + id, result)
		for row: Dictionary in operations:
			if not _operation(world, descriptor, descriptor.default_action, row, result, owner, ""): return false
		if descriptor.content_id == "EVENT_11" and not world.settle_event_rewrite(descriptor.facts.plan, result, owner): return false
	return true

func _write(world: RefCounted, descriptor: Dictionary, tag: String, targets: Array, source: String, extra: Dictionary = {}) -> String:
	var changes: Dictionary = {"event": descriptor.content_id, "tag": tag, "institution": descriptor.institution, "subjects": descriptor.subjects.duplicate(true), "facts": descriptor.facts.duplicate(true)}
	changes.merge(extra)
	var result: String = world._record("event_fact", descriptor.domain, "", targets, [source] + descriptor.source_ids, changes)
	for target: String in targets:
		if Store.has(world.state.npcs, target): world._know(target, result)
		elif world.state.institutions.has(target): world._institution_know(target, result)
	return result

func _targets(descriptor: Dictionary, subject: String, state: Dictionary = {}) -> Array:
	if subject in ["prophet", "obligor"] and not state.is_empty() and descriptor.subjects.has("successor") and not Rules.alive(state, str(descriptor.subjects.get(subject, ""))): return [descriptor.subjects.successor]
	if subject == "domain": return [descriptor.domain]
	if subject == "institution": return [descriptor.institution]
	if subject == "cult":
		return [] # The caller resolves the current continuous local cult.
	var value: Variant = descriptor.subjects.get(subject, "")
	return value.duplicate() if value is Array else ([value] if value is String and not value.is_empty() else [])

func _invalidate(world: RefCounted, original: String, source: String) -> bool:
	if original.is_empty() or not Store.has(world.state.facts, original): return false
	if Store.has(world.state.invalid_records, original): return true
	Store.put(world.state.invalid_records, original, source)
	world._record("event_source_withdrawn", Rules.fact(world.state, original).domain, "", [original], [original, source], {"source": original})
	return true

func _delta(world: RefCounted, descriptor: Dictionary, row: Dictionary, source: String, owner: Object) -> bool:
	var amount: int = catalog.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)
	var field: String = row.field; var targets: Array = _targets(descriptor, row.subject, world.state)
	if row.subject == "global":
		if field == "faith": world.state.faith = mini(Economy.capacity(world.state, catalog), int(world.state.faith) + amount)
		elif field == "wounds": world.state.wounds = maxi(0, int(world.state.wounds) + amount)
		else: return false
	elif row.subject == "cult":
		var cult: String = Rules.cult(world.state, descriptor.domain)
		if not cult.is_empty(): world.state.cults[cult][field] = clampi(int(world.state.cults[cult][field]) + amount, 0, catalog.integer("attribute_max"))
	elif row.subject == "domain":
		var domain: Dictionary = world.state.domains[descriptor.domain]
		if field == "followers":
			var actual: int = mini(absi(amount), int(domain.unnamed_nonfollowers) if amount >= 0 else int(domain.unnamed_followers))
			if actual > 0 and not world.submit({"kind": "population", "domain": descriptor.domain, "mode": "convert" if amount > 0 else "leave", "amount": actual, "parents": [source]}, owner, true): return false
		else:
			domain[field] = clampi(int(domain[field]) + amount, 0, catalog.integer("attribute_max"))
			if field == "alert" and amount > 0: domain.exposure_turn = world.state.turn
			if field == "pollution" and amount > 0: domain.pollution_changed_turn = world.state.turn
	else:
		for id: String in targets:
			var person: Dictionary = world.mutable_npc(id)
			person[field] = clampi(int(person[field]) + amount, 0, catalog.integer("attribute_max"))
	world._record("event_delta", descriptor.domain, "", targets, [source], {"field": field, "subject": row.subject, "amount": amount})
	return true

func _deliver(world: RefCounted, institution: String, source: String, actors: Array, result: String, owner: Object) -> bool:
	if world.history.knows(world.state, institution, source, true): return true
	for actor: String in actors:
		if not Rules.alive(world.state, actor, null, true) or not world.history.knows(world.state, actor, source): continue
		if world.submit({"kind": "share_record", "npc": actor, "institution": institution, "source": source, "parents": [source, result]}, owner): return true
	return false

func _recognize(world: RefCounted, descriptor: Dictionary, option: String, result: String, owner: Object) -> bool:
	var row: Dictionary = Anchors._row(world.state, descriptor.institution, catalog)
	if row.is_empty() or row.event_id != descriptor.content_id or (row.event_option != "*" and row.event_option != option): return true
	var basis: Dictionary = descriptor.get("basis", {}).duplicate(true)
	if basis.is_empty(): return true
	if row.rule == "contract_dependency" and not Rules.alive(world.state, descriptor.subjects.obligor) and descriptor.facts.has("inheritance"):
		var inherited: Dictionary = Rules.inheritance(world.state, descriptor.facts.inheritance, descriptor.facts.contract, world.history)
		if inherited.is_empty(): return false
		var successor: String = world.introduce_fact("contract_successor_authorized", descriptor.domain, "", [inherited.obligor, inherited.successor, descriptor.institution], [result, descriptor.facts.inheritance, inherited.relation], {"issuer": ID, "version": version, "contract": inherited.contract, "obligor": inherited.obligor, "successor": inherited.successor, "fixed": descriptor.facts.inheritance, "relation": inherited.relation}, [], [], owner)
		if successor.is_empty(): return false
		basis["successor"] = successor
	if descriptor.content_id in ["EVENT_05", "EVENT_06"]:
		var proposed: Dictionary = descriptor.duplicate(true); proposed.basis = basis
		if not Rules.prospective_recognition(world.state, proposed, catalog, world.history, false).ok: return true
	var sources: Array = Anchors._basis_sources(row.rule, basis)
	for source: String in sources:
		if source == basis.get("memory") or source == basis.get("contract") or source == basis.get("exception"): continue
		var recipient: String = descriptor.institution
		if row.rule in ["network_evidence", "axiom_exception"] and source == basis.records[1]: recipient = basis.other_institution
		if not _deliver(world, recipient, source, descriptor.actors, result, owner):
			return descriptor.content_id in ["EVENT_05", "EVENT_06"]
	var changes: Dictionary = {"issuer": ID, "version": version, "event": descriptor.content_id, "option": option, "institution": descriptor.institution, "basis": basis}
	var targets: Array = [descriptor.institution] + descriptor.actors
	if row.rule == "contract_dependency":
		for person: String in [descriptor.subjects.obligor, descriptor.subjects.counterparty]:
			if not person in targets: targets.append(person)
	var simulated: Dictionary = {"changes": changes, "targets": targets}
	var unavailable: String = Anchors._check_basis(world.state, descriptor.institution, simulated, row, catalog, world.history)
	if not unavailable.is_empty():
		if descriptor.content_id in ["EVENT_02", "EVENT_04"]:
			world.last_error = "Institution recognition rejected: " + unavailable
			return false
		# Preserving an already living dependency/memory is independent of a
		# larger civilization blueprint; it never invents its missing grant.
		return true
	var granted: String = world.introduce_fact("institution_event_result", descriptor.domain, "", targets, [result] + sources, changes, descriptor.actors, [descriptor.institution], owner)
	if granted.is_empty(): return false
	if descriptor.content_id == "EVENT_04" and option == "A" and basis.has("priest"):
		var rituals: Array = basis.get("rituals", [basis.get("ritual", "")])
		var parents: Array = [granted]
		for ritual: String in rituals:
			var restricted: String = world.history.institution_ritual_restriction(descriptor.institution, basis.priest, ritual)
			if not restricted.is_empty() and not restricted in parents: parents.append(restricted)
		world._record("institution_recognition_clear", descriptor.domain, "", [descriptor.institution, basis.priest], parents, {"institution": descriptor.institution, "priest": basis.priest, "rituals": rituals, "grant": granted})
		if not Anchors.observe(world, granted, owner): return false
	return true

func _deny(world: RefCounted, descriptor: Dictionary, result: String, owner: Object) -> bool:
	var basis: Dictionary = descriptor.get("basis", {}).duplicate(true)
	if descriptor.content_id == "EVENT_04" and basis.is_empty(): basis = {"priest": descriptor.subjects.get("priest", ""), "rituals": descriptor.facts.get("rituals", []).duplicate()}
	var changes: Dictionary = {"issuer": ID, "version": version, "event": descriptor.content_id, "option": "B", "institution": descriptor.institution, "basis": basis}
	var event_source: String = world.introduce_fact("institution_event_result", descriptor.domain, "", [descriptor.institution] + descriptor.actors, [result] + descriptor.source_ids, changes, [], [descriptor.institution], owner)
	if event_source.is_empty(): return false
	var denied: String = world.introduce_fact("institution_restriction", descriptor.domain, "", [descriptor.institution], [event_source, result], {"issuer": ID, "version": version, "institution": descriptor.institution, "reason": "denied"}, [], [descriptor.institution], owner)
	return not denied.is_empty()

func _publish(world: RefCounted, descriptor: Dictionary, field: String, result: String, owner: Object) -> bool:
	if field == "records":
		var publications: Array = []
		for original: String in descriptor.facts.records:
			var record: Dictionary = Anchors._evidence_record(world.state, original, world.history, true)
			if record.is_empty(): return false
			var recipient: String = record.institution
			if not _deliver(world, recipient, original, descriptor.actors, result, owner): return false
			if record.public:
				publications.append(original); continue
			var publication: String = world._record("event_publication", descriptor.domain, "", [recipient] + record.base.targets, [result, original], {"event": descriptor.content_id, "option": "B", "institution": recipient, "record": original})
			world._institution_know(recipient, publication)
			for id: String in record.base.targets:
				if Store.has(world.state.npcs, id): world._know(id, publication)
			if world.introduce_fact("exposure", descriptor.domain, "", record.base.targets, [publication, result], {"public": true, "event": descriptor.content_id, "record": original}, [], [recipient], owner).is_empty(): return false
			publications.append(publication)
		if descriptor.get("basis", {}).has("records"): descriptor.basis.records = publications.slice(0, descriptor.basis.records.size())
	else:
		var targets: Array = [descriptor.subjects.survivor]
		if world.introduce_fact("exposure", descriptor.domain, descriptor.subjects.survivor, targets, [result, descriptor.facts.miracle], {"public": true, "event": descriptor.content_id}, targets, [descriptor.institution], owner).is_empty(): return false
	return true

func _custody(world: RefCounted, descriptor: Dictionary, result: String, recover: bool, owner: Object) -> bool:
	var id: String = descriptor.subjects.relic
	var relic: Dictionary = Store.entry(world.state.relics, id)
	var service: RefCounted = Relics.new(catalog, world.state.relic_system.issuers)
	if not recover:
		if relic.placement == "bound": return service.commit(world, {"operation": "unbind", "payload": {"relic": id, "source": result}}, owner)
		if relic.placement == "carried": return service.commit(world, {"operation": "unequip", "payload": {"relic": id, "source": result}}, owner)
		return relic.placement == "controlled" and not Rules.cult(world.state, descriptor.domain).is_empty()
	var proof: Dictionary = {"schema": 1, "issuer": ID, "version": version, "domain": descriptor.domain, "target": id, "holder": "", "status_source": relic.status_source}
	var authorized: String = world.introduce_fact("relic_recover_authorized", descriptor.domain, "", [id, descriptor.institution], [result, relic.status_source], {"holder": "", "proof": proof}, [], [], owner)
	return not authorized.is_empty() and service.commit(world, {"operation": "recover", "payload": {"relic": id, "source": authorized}}, owner)

func _operation(world: RefCounted, descriptor: Dictionary, option: String, row: Dictionary, result: String, owner: Object, token: String, selection: Dictionary = {}) -> bool:
	var subjects: Dictionary = descriptor.subjects; var facts: Dictionary = descriptor.facts
	var targets: Array = _targets(descriptor, row.subject, world.state)
	if row.condition == "heretic_exists" and not Rules.heretic_legal(world.state, descriptor, catalog, world.history): return true
	if row.condition == "opponent_exists" and (not Rules.successor_legal(world.state, str(subjects.get("opponent", "")), descriptor.institution, catalog, world.history) or not Rules.related_any(world.state, facts.get("relations", []), str(subjects.get("former", "")), str(subjects.get("opponent", "")), ["rival", "hostile"], world.history)): return true
	if row.condition == "was_member" and (targets.is_empty() or not Rules.person(world.state, targets[0]).get("bound_member", false)): return true
	match str(row.operation):
		"delta": return _delta(world, descriptor, row, result, owner)
		"record":
			var tag: String = row.field
			if tag == "favor_owed":
				var relation: String = world._record("relationship", descriptor.domain, subjects.former, [subjects.cooperator], [result] + facts.relations, {"kind": "favor_owed"})
				return world.add_relation(subjects.former, subjects.cooperator, "favor_owed", relation, owner)
			_write(world, descriptor, tag, targets, result)
		"publish": return _publish(world, descriptor, row.field, result, owner)
		"recognize", "retain_dependency", "preserve_memory": return _recognize(world, descriptor, option, result, owner)
		"deny": return _deny(world, descriptor, result, owner)
		"succeed":
			if targets.is_empty(): return false
			var authorization: String = world.introduce_fact("institution_succession_authorized", descriptor.domain, "", [descriptor.institution, targets[0]], [result] + descriptor.source_ids, {"institution": descriptor.institution, "successor": targets[0]}, [], [], owner)
			return not authorization.is_empty() and world.succeed_institution(descriptor.institution, targets[0], authorization, owner)
		"release_contract":
			_write(world, descriptor, "contract_released", [subjects.obligor, subjects.counterparty], result)
			return _invalidate(world, facts.dependency, result)
		"drop_memory":
			for qualification: String in facts.qualifications:
				if qualification != selection.get("qualification", "") or not Rules.current(world.state, qualification): continue
				var memory: Dictionary = Rules.fact(world.state, qualification)
				var person: String = memory.targets[0]
				var lost: String = _write(world, descriptor, "memory_qualification_lost", [person], result, {"qualification": qualification, "memory": facts.memory})
				Store.put(world.state.applied_authorizations, "prayer/memory_lost/" + memory.changes.original + "/" + person, lost)
				return _invalidate(world, qualification, lost)
			return false
		"prophet":
			if row.field == "correct":
				world.state.event_system.prophets.erase(subjects.prophet)
				if subjects.has("successor"): world.state.event_system.prophets.erase(subjects.successor)
				return _invalidate(world, facts.prophet, result)
			var actual: String = targets[0]
			var declared: String = _write(world, descriptor, "prophet_allowed", [actual], result, {"binding_source": Rules.person(world.state, actual).get("binding_source", ""), "cult": Rules.cult(world.state, descriptor.domain), "bonus": int(row.value)})
			world.state.event_system.prophets[actual] = {"source": result, "declaration": declared, "prophet": facts.prophet, "domain": descriptor.domain, "cult": Rules.cult(world.state, descriptor.domain), "binding_source": Rules.person(world.state, actual).get("binding_source", ""), "bonus": int(row.value)}
		"move_medium": return _custody(world, descriptor, result, false, owner)
		"recover_relic": return _custody(world, descriptor, result, true, owner)
		"evidence":
			return world.settle_event_trace(facts.investigation, result, owner)
		"permit":
			var cult: String = Rules.cult(world.state, descriptor.domain)
			if cult.is_empty(): return false
			var parents: Array = [result, facts.conflict, facts.relation]
			var prior: String = world.state.economy_qualifications.get("propagation|" + cult, "")
			if not prior.is_empty(): parents.append(prior)
			if not world.submit({"kind": "economy_qualification", "issuer": ID, "version": version, "rule": "propagation", "subject": cult, "allowed": true, "institution": subjects.cooperating_institution, "parents": parents}, owner): return false
			var permit: String = world.state.economy_qualifications["propagation|" + cult]
			world.state.event_system.permits[subjects.cooperating_institution] = {"source": permit, "cooperator": subjects.cooperator}
		"relation":
			if row.subject == "opponent":
				var relation: String = world._record("relationship", descriptor.domain, subjects.cooperator, [subjects.opponent], [result, facts.relation], {"kind": "hostile"})
				return world.add_relation(subjects.cooperator, subjects.opponent, "hostile", relation, owner)
			_write(world, descriptor, "institution_hostile", targets, result)
		"cancel_plan":
			if row.field == "investigation": return world.cancel_event_trace(facts.investigation, result, owner)
			# The following erase_record operation makes the original plan invalid;
			# final arbitration happens after every table operation was applied.
		"erase_record": return _invalidate(world, facts.record, result)
		"resolve_plan": pass
		"leave": return Cults.membership(world, "leave", subjects.petitioner, result, token)
		"reopen":
			if not owner._participants.has("prayers"): return false
			var registered: Dictionary = Rules.fact(world.state, facts.registration)
			var reopened: Dictionary = owner._participants.prayers.instance.reopen_event(world, result, registered.changes.request, owner)
			return reopened.get("ok", false)
		"close": _write(world, descriptor, row.field + "_closed", targets, result)
		_: return false
	return true

func _payment(world: RefCounted, plan: Dictionary) -> String:
	if plan.get("default", false): return ""
	var latest: Dictionary = Rules.fact(world.state, "FACT-%08d" % (int(world.state.next_fact) - 1))
	if latest.get("kind") == "cult_local_payment": latest = Rules.fact(world.state, latest.changes.payment)
	if latest.get("kind") != "turn_action" or latest.changes.get("faith_cost") != plan.faith_cost or latest.changes.get("outcome") != "event_choice": return ""
	return latest.id

func _resolve(world: RefCounted, plan: Dictionary, owner: Object, token: String = "") -> bool:
	var id: String = plan.event
	if not world.state.event_system.cards.has(id) or not Rules.auth(world.state, "event/resolved/" + id).is_empty(): return false
	var descriptor: Dictionary = plan.descriptor.duplicate(true)
	var payment: String = _payment(world, plan)
	if payment.is_empty() and not plan.get("default", false): return false
	var operations: Array = []
	for row: Dictionary in plan.operations: operations.append(row.id)
	var entry: Dictionary = world.state.event_system.cards[id]
	var result: String = world._record("event_result", descriptor.domain, "", descriptor.actors, [entry.card.fact, descriptor.source] + ([] if payment.is_empty() else [payment]), {"event": id, "content_id": descriptor.content_id, "option": plan.option, "descriptor": descriptor.duplicate(true), "operations": operations, "payment": payment, "default": plan.get("default", false), "selection": plan.get("selection", {})})
	# Reopening and cross-module consumers validate this precise committed
	# choice. The outer transaction rolls both marker and every effect back.
	Store.put(world.state.applied_authorizations, "event/resolved/" + id, result)
	for row: Dictionary in plan.operations:
		if not _operation(world, descriptor, plan.option, row, result, owner, token, plan.get("selection", {})): return false
	if descriptor.content_id == "EVENT_11":
		if not world.settle_event_rewrite(descriptor.facts.plan, result, owner): return false
		if not _recognize(world, descriptor, plan.option, result, owner): return false
	for actor: String in descriptor.actors:
		if Store.has(world.state.npcs, actor): world._know(actor, result)
	_finish(world, id, result, "resolved")
	world._refresh_anchors()
	return true

func _opportunity(world: RefCounted, plan: Dictionary, owner: Object) -> bool:
	var original: Dictionary = Rules.fact(world.state, plan.opportunity)
	if original.is_empty() or not Rules.auth(world.state, "anchor/opportunity/" + plan.opportunity).is_empty(): return false
	var result: String = world._record("institution_relic_" + plan.option, plan.domain, plan.npc, [plan.institution] + ([] if plan.npc.is_empty() else [plan.npc]), [plan.opportunity], {"opportunity": plan.opportunity, "institution": plan.institution, "relic_type": plan.relic_type, "placement": plan.placement, "npc": plan.npc})
	if plan.option == "wait": return true
	if plan.option == "recover":
		var holder: String = plan.npc if plan.placement == "carried" else ""
		var proof: Dictionary = {"schema": 1, "issuer": ID, "version": version, "domain": plan.domain, "target": plan.relic_type, "holder": holder}
		var source: String = world.introduce_fact("relic_create_authorized", plan.domain, holder, [plan.institution] + ([] if holder.is_empty() else [holder]), [plan.opportunity, result], {"relic_type": plan.relic_type, "placement": plan.placement, "holder": holder, "proof": proof}, [], [], owner)
		if source.is_empty() or not Relics.new(catalog, world.state.relic_system.issuers).commit(world, {"operation": "create", "payload": {"source": source}}, owner): return false
	else:
		world.state.faith = mini(Economy.capacity(world.state, catalog), int(world.state.faith) + catalog.integer("relic_public_faith"))
		world.state.domains[plan.domain].alert = mini(catalog.integer("attribute_max"), int(world.state.domains[plan.domain].alert) + catalog.integer("relic_public_alert"))
		world.state.domains[plan.domain].exposure_turn = world.state.turn
		if world.introduce_fact("exposure", plan.domain, "", [plan.institution], [result, plan.opportunity], {"public": true, "rule": "institution_relic_public"}, [], [plan.institution], owner).is_empty(): return false
	Store.put(world.state.applied_authorizations, "anchor/opportunity/" + plan.opportunity, result)
	world.state.anchor_system.opportunities.erase(plan.institution)
	return true

func commit(world: RefCounted, effect: Dictionary, owner: Object, token: String = "") -> bool:
	if not world._driver_allowed(owner) or world.transaction == null: return false
	world.stage_current(); world.stage_collections(["event_system", "applied_authorizations", "invalid_records", "economy_qualifications", "anchor_system", "relics"])
	match str(effect.operation):
		"events_collect": return _collect(world, owner)
		"events_deadlines": return _deadlines(world, owner)
		"gather": return _gather(world, owner)
		"resolve": return _resolve(world, effect.plan, owner, token)
		"cancel":
			_cancel(world, effect.event, "default_target_unavailable"); return true
		"opportunity": return _opportunity(world, effect.plan, owner)
	return false

static func _new_facts(state: Dictionary, trusted: Dictionary) -> Array:
	if trusted.is_empty(): return Store.values(state.facts)
	var result: Array = []
	if Store.overlay(state.facts):
		for id: String in Store.changed(state.facts): result.append(Store.entry(state.facts, id))
	elif not is_same(state.facts, trusted.facts):
		for item: Dictionary in History.changed_entries(state.facts, trusted.facts):
			if Store.has(state.facts, item.key): result.append(Store.entry(state.facts, item.key))
	return result

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}, _index: RefCounted = null) -> Array[String]:
	if not state.has("event_system"):
		if trusted.has("event_system"): return ["Installed events disappeared"]
		return []
	var ledger: Variant = state.event_system
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content): return ["Invalid event rule version"]
	for field: String in ["pending", "records", "cards", "cooldowns", "prophets", "permits"]:
		if not ledger.get(field) is Dictionary: return ["Invalid event ledger collection"]
	if not ledger.get("selected") is Array or not ledger.get("selected_turn") is int or ledger.selected_turn < 0 or ledger.selected_turn > state.turn or ledger.selected.size() > content.integer("major_event_limit"): return ["Invalid frozen event offer"]
	if trusted.has("event_system") and trusted.event_system.version != ledger.version: return ["Event rules changed during transaction"]
	var seen: Dictionary = {}
	for id: Variant in ledger.selected:
		if not id is String or seen.has(id) or (not ledger.cards.has(id) and Rules.auth(state, "event/resolved/" + id).is_empty()): return ["Invalid frozen event reference"]
		seen[id] = true
	for id: String in ledger.cards:
		var entry: Variant = ledger.cards[id]
		if not entry is Dictionary or not entry.get("card") is Dictionary or not entry.get("descriptor") is Dictionary or entry.card.get("id") != id or not entry.get("status") in ["pending", "offered"]: return ["Invalid fixed event ledger entry"]
		if not state.simulation.candidates.has(id) or state.simulation.candidates[id] != entry.card or entry.card.get("origin") != "event": return ["Event lost its unique simulation candidate"]
		var fixed: Dictionary = Rules.fact(state, entry.card.get("fact", ""))
		if fixed.get("kind") != "event_fixed" or fixed.changes.get("candidate", {}).get("descriptor") != entry.descriptor or fixed.changes.get("candidate") != entry.card: return ["Fixed event source or objects changed"]
		if not _descriptor_contract(state, entry.descriptor, content): return ["Invalid fixed event source contract"]
	for source: String in ledger.pending:
		var fact: Dictionary = Rules.fact(state, source)
		if fact.is_empty() or fact.turn != ledger.pending[source] or not (fact.kind in ["prayer_window_due", "resistance_started"] or (fact.kind == "prayer_fact" and fact.changes.get("tag") == "future_callback") or (fact.kind == "miracle" and fact.changes.get("power") == "POWER_DREAM")): return ["Invented pending event source"]
	for source: String in ledger.records:
		var fact: Dictionary = Rules.fact(state, source)
		if fact.get("kind") != "prayer_fact" or fact.turn != ledger.records[source]: return ["Invalid bounded event record intake"]
	for key: String in ledger.cooldowns:
		if not ledger.cooldowns[key] is int or ledger.cooldowns[key] < 0: return ["Invalid event cooldown"]
	for npc: String in ledger.prophets:
		var entry: Variant = ledger.prophets[npc]
		if not entry is Dictionary or not Anchors._shape(entry, ["source", "declaration", "prophet", "domain", "cult", "binding_source", "bonus"]) or not entry.bonus is int or not Store.has(state.npcs, npc): return ["Invalid current prophet declaration"]
		var result: Dictionary = Rules.fact(state, str(entry.source)); var declared: Dictionary = Rules.fact(state, str(entry.declaration))
		if result.get("kind") != "event_result" or result.changes.get("content_id") != "EVENT_07" or result.changes.get("option") != "B" or result.domain != entry.domain or result.changes.get("descriptor", {}).get("facts", {}).get("prophet") != entry.prophet or Rules.auth(state, "event/resolved/" + str(result.changes.get("event", ""))) != result.id: return ["Prophet bonus is not the actual chosen event"]
		if declared.get("kind") != "event_fact" or declared.changes.get("tag") != "prophet_allowed" or declared.targets != [npc] or not result.id in declared.causal_parents or declared.changes.get("binding_source") != entry.binding_source or declared.changes.get("cult") != entry.cult or declared.changes.get("bonus") != entry.bonus: return ["Prophet current position or bonus was rewritten"]
		var operation: Dictionary = content.tables.event_operations.get("EVENT_07/B/02", {})
		if int(operation.get("value", -1)) != entry.bonus: return ["Prophet bonus differs from formal content"]
	for institution: String in ledger.permits:
		var entry: Variant = ledger.permits[institution]
		if not entry is Dictionary or not Anchors._shape(entry, ["source", "cooperator"]): return ["Invalid event propagation permission"]
		var permit: Dictionary = Rules.fact(state, str(entry.source)); var origin: Dictionary = {}
		for parent: String in permit.get("causal_parents", []):
			var candidate: Dictionary = Rules.fact(state, parent)
			if candidate.get("kind") == "event_result" and candidate.changes.get("content_id") == "EVENT_09" and candidate.changes.get("option") == "A": origin = candidate
		if permit.get("kind") != "economy_qualification" or permit.changes.get("issuer") != ID or permit.changes.get("version") != ledger.version or permit.changes.get("institution") != institution or origin.is_empty() or origin.changes.get("descriptor", {}).get("subjects", {}).get("cooperator") != entry.cooperator: return ["Permission lost the actual cooperative event source"]
	for fact: Dictionary in _new_facts(state, trusted):
		if fact.kind == "event_result":
			var data: Dictionary = fact.changes
			if not content.tables.events.has(data.get("content_id", "")) or not data.get("option") in ["A", "B"] or not data.get("event") is String or not data.get("descriptor") is Dictionary or not data.get("operations") is Array or not data.get("payment") is String: return ["Invalid event result schema"]
			var fixed: Dictionary = {}
			for parent: String in fact.causal_parents:
				var source: Dictionary = Rules.fact(state, parent)
				if source.get("kind") == "event_fixed": fixed = source
			if data.get("handoff", false):
				var started: Dictionary = Rules.fact(state, str(data.descriptor.get("source", "")))
				if not data.get("default", false) or not data.content_id in ["EVENT_08", "EVENT_11"] or data.event != "PLAN/" + str(data.descriptor.get("source", "")) or started.get("kind") != "resistance_started" or int(started.changes.get("due", -1)) != int(fact.turn) or not started.id in fact.causal_parents: return ["Invalid due-plan default handoff"]
			elif fixed.is_empty() or fixed.changes.get("candidate", {}).get("descriptor") != data.descriptor or fixed.changes.get("candidate", {}).get("id") != data.event: return ["Event result lost its original fixed graph"]
			if data.descriptor.get("content_id") != data.content_id or not _descriptor_contract(state, data.descriptor, content): return ["Event result source contract changed"]
			var selection: Variant = data.get("selection", {})
			if not selection is Dictionary: return ["Invalid event selection"]
			if data.content_id == "EVENT_06" and data.option == "B":
				if not Anchors._shape(selection, ["qualification"]) or not selection.qualification is String or not selection.qualification in data.descriptor.facts.get("qualifications", []): return ["Memory choice changed the original fixed qualification"]
			elif not selection.is_empty(): return ["Unexpected event selection"]
			var expected: Array = []
			for row: Dictionary in content.tables.event_operations.values():
				if row.event_id == data.content_id and row.option == data.option: expected.append(row.id)
			expected.sort()
			if data.operations != expected or Rules.auth(state, "event/resolved/" + data.event) != fact.id: return ["Event result or permanent consumption changed"]
			if data.payment.is_empty():
				if not data.get("default", false) or data.option != data.descriptor.default_action or int(content.tables.event_effects[data.content_id + "/" + data.option].faith_cost) != 0: return ["Event payment was omitted"]
			else:
				var payment: Dictionary = Rules.fact(state, data.payment)
				if payment.get("kind") != "turn_action" or payment.turn != fact.turn or payment.changes.get("faith_cost") != int(content.tables.event_effects[data.content_id + "/" + data.option].faith_cost) or payment.changes.get("outcome") != "event_choice" or not data.payment in fact.causal_parents: return ["Event lacks its actual exact payment"]
		if fact.kind == "event_fact" and fact.changes.get("tag") == "memory_qualification_lost":
			var result: Dictionary = {}
			for parent: String in fact.causal_parents:
				var candidate: Dictionary = Rules.fact(state, parent)
				if candidate.get("kind") == "event_result": result = candidate; break
			var qualification: String = str(fact.changes.get("qualification", ""))
			var original: Dictionary = Rules.fact(state, qualification)
			if result.is_empty() or result.changes.get("content_id") != "EVENT_06" or result.changes.get("option") != "B" or result.changes.get("selection", {}).get("qualification") != qualification or original.get("kind") != "prayer_fact" or original.changes.get("tag") != "memory_preserved" or fact.targets != original.targets or str(Store.entry(state.invalid_records, qualification, "")) != fact.id: return ["Memory withdrawal differs from the actual selected original qualification"]
		if fact.kind == "institution_recognition_clear":
			var data: Dictionary = fact.changes
			if not Anchors._shape(data, ["institution", "priest", "rituals", "grant"]) or not data.rituals is Array or data.rituals.is_empty() or not data.grant in fact.causal_parents: return ["Invalid scoped institution recognition clear"]
			var grant: Dictionary = Rules.fact(state, str(data.grant))
			if grant.get("kind") != "institution_event_result" or grant.changes.get("issuer") != ID or grant.changes.get("version") != ledger.version or grant.changes.get("event") != "EVENT_04" or grant.changes.get("option") != "A" or grant.changes.get("institution") != data.institution or grant.changes.get("basis", {}).get("priest") != data.priest: return ["Institution clear is not a complete actual recognition"]
			var rituals: Array = grant.changes.basis.get("rituals", [grant.changes.basis.get("ritual", "")])
			if data.rituals != rituals: return ["Institution clear changed its exact ritual scope"]
		if fact.kind == "event_fixed":
			if not fact.changes.get("candidate") is Dictionary or not fact.changes.candidate.get("descriptor") is Dictionary or not _descriptor_contract(state, fact.changes.candidate.descriptor, content): return ["Invalid event fixed source"]
			if Rules.auth(state, fact.changes.candidate.descriptor.once_key) != fact.id: return ["Event source was not uniquely consumed"]
	return []

static func _descriptor_contract(state: Dictionary, descriptor: Dictionary, content: RefCounted) -> bool:
	if not content.tables.events.has(descriptor.get("content_id", "")) or not descriptor.get("source") is String or not descriptor.get("facts") is Dictionary or not descriptor.get("subjects") is Dictionary or not descriptor.get("actors") is Array or not descriptor.get("source_ids") is Array: return false
	var source: Dictionary = Rules.fact(state, descriptor.source)
	if source.is_empty() or descriptor.get("domain") != source.domain or not state.institutions.has(descriptor.get("institution", "")): return false
	var row: Dictionary = content.tables.events[descriptor.content_id]
	if descriptor.get("once_key") != "event/source/" + descriptor.content_id + "/" + descriptor.source or descriptor.get("default_action") != str(row.default_result).trim_prefix("option:"): return false
	for id: String in descriptor.source_ids:
		if not Store.has(state.facts, id): return false
	if source.kind == "prayer_fact":
		var actual: Dictionary = Rules.actual_prayer(state, source.id)
		if actual.is_empty() or source.changes.get("tag") != "future_callback" or source.changes.get("event") != descriptor.content_id or descriptor.get("prayer_descriptor") != actual.attempt.changes.descriptor: return false
	elif source.kind == "miracle":
		if descriptor.content_id != "EVENT_02" or Anchors._dream_record(state, source.id, null, false).is_empty(): return false
	elif source.kind == "resistance_started":
		if not descriptor.content_id in ["EVENT_08", "EVENT_11"] or source.changes.get("institution") != descriptor.institution or source.changes.get("plan") != ("RESIST_TRACE" if descriptor.content_id == "EVENT_08" else "RESIST_REWRITE"): return false
	elif source.kind == "prayer_window_due":
		if descriptor.content_id != "EVENT_12" or source.changes.get("answered", true) or descriptor.get("prayer_descriptor") != source.changes.get("descriptor"): return false
	else: return false
	return Rules.historical_objects(state, descriptor, content)

static func validate_context(state: Dictionary, context: Dictionary) -> Array[String]:
	if not state.has("event_system"): return []
	var seen: Dictionary = {}
	for event: Variant in context.get("events", []):
		if not event is Dictionary or event.get("participant") != ID: continue
		if seen.has(event.id) or not event.id in state.event_system.selected or state.event_system.selected_turn != context.turn: return ["Turn events differ from the frozen event pool"]
		seen[event.id] = true
		if not event.resolved and (not state.event_system.cards.has(event.id) or state.event_system.cards[event.id].card.fact != event.source): return ["Unresolved event lost its fixed candidate"]
	return []

func _confirm_exception(world: RefCounted, source: String, owner: Object) -> bool:
	var callback: Dictionary = Rules.fact(world.state, source)
	if callback.get("kind") != "prayer_fact" or callback.changes.get("prayer") != "PRAYER_12" or callback.changes.get("tag") != "future_callback": return true
	var actual: Dictionary = Rules.actual_prayer(world.state, source, world.history)
	if actual.is_empty(): return true
	var descriptor: Dictionary = actual.attempt.changes.descriptor
	var exception: String = descriptor.facts.exception
	if not Rules.current(world.state, exception): return true
	var own: String = descriptor.institution
	var sources: Array = world.history.event_record_heads(own, "", "exception/" + exception)
	for other: String in world.state.institutions[own].links:
		if not Anchors._connected(world.state, own, other): continue
		var others: Array = world.history.event_record_heads(other, "", "exception/" + exception)
		for first: String in sources:
			var primary: Dictionary = Rules.actual_prayer(world.state, first, world.history)
			if primary.is_empty() or not primary.tag in ["exception_record", "exception_learned", "public_exception_qualification"] or not world.history.knows(world.state, own, first, true): continue
			for second: String in others:
				var secondary: Dictionary = Rules.actual_prayer(world.state, second, world.history)
				if secondary.is_empty() or not secondary.tag in ["exception_record", "exception_learned", "public_exception_qualification"] or primary.base.id == secondary.base.id or primary.base.changes.request == secondary.base.changes.request or not world.history.knows(world.state, other, second, true): continue
				for institution: String in [own, other]:
					var office: Dictionary = world.state.institutions[institution]
					if office.role != "interpretation" or not office.active or not Rules.alive(world.state, office.representative, null, true) or not world.history.knows(world.state, institution, exception, true): continue
					var key: String = "event/exception/" + institution + "/" + exception
					if not Rules.auth(world.state, key).is_empty(): continue
					var parents: Array = [exception, first, second]
					var authorized: String = world.introduce_fact("exception_confirmation_authorized", descriptor.domain, "", [institution, exception], parents, {"issuer": ID, "version": version, "institution": institution, "record": exception, "records": [first, second]}, [], [], owner)
					if authorized.is_empty() or not world.confirm_exception(institution, exception, authorized, owner): return false
					Store.put(world.state.applied_authorizations, key, authorized)
	return true
