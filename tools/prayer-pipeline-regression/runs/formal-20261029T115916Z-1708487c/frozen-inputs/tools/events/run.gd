extends "res://tools/anchors/run.gd"
const Events = preload("res://src/game/events.gd")
var event_rows: Array = []
var initial_conflict_due: int = 3
var review_role_fixture: String = ""
class EventFixture extends Fixture:
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		if input.operation == "due": return {"ok": true, "empty": input.payload.effects.is_empty(), "effects": input.payload.effects.duplicate(true), "state": {}}
		if input.slot == "deadlines":
			return {"ok": not fault, "empty": gather.is_empty() and deadlines.is_empty(), "effects": gather.duplicate(true) + deadlines.duplicate(true), "state": {}}
		return super.handle(view, input)
func _initialize() -> void:
	catalog = Catalog.new(); assert(catalog.load_files())
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	for event: String in ["EVENT_01", "EVENT_02", "EVENT_03", "EVENT_04", "EVENT_05", "EVENT_06", "EVENT_07", "EVENT_08", "EVENT_09", "EVENT_10", "EVENT_11", "EVENT_12"]:
		for option: String in ["A", "B"]: _event_branch(event, option)
	for profile: String in catalog.tables.anchor_conditions: _event_blueprint(profile)
	_event_review_cases()
	_event_cold_evidence()
	_event_pressure()
	_event_pool_contracts()
	_event_opportunities()
	if has_method("run_event_lifecycle"): call("run_event_lifecycle")
	var ok: bool = true
	for row: Dictionary in records: ok = ok and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "engine": Engine.get_version_info().string, "checks": records, "cases": event_rows}, "\t", true, true)); file.close()
	quit(0 if ok else 1)
func _event_issuers() -> Dictionary:
	var accepted: Dictionary = ISSUERS.duplicate(true); accepted.merge(Events.issuer_capability(catalog))
	return accepted
func _attach_powers(data: Dictionary) -> Dictionary:
	var accepted: Dictionary = _event_issuers()
	if data.get("profile") == "CIV_07":
		data.world.state.domains[data.domain].alert = 85
		# Explicit already-unlocked midgame insight absorbs the real eight wounds.
		data.world.state.insight = 20
		data.world._refresh_anchors()
	# Explicit initial capability configuration before any authoritative receipt.
	data.world.state.economy.issuers = accepted.duplicate(true)
	data.economy = Economy.new(catalog, accepted)
	var turn: RefCounted = Turn.new(data.world); assert(turn._attached)
	assert(data.economy.install(turn))
	var fixture: RefCounted = EventFixture.new()
	assert(turn.register_participant("event-fixture", "1", ["deadlines", "ending"], ["fact", "world_command", "resource", "schedule", "check", "wounds"], fixture.handle))
	var cults: RefCounted = Cults.new(catalog); assert(cults.install(turn))
	var relics: RefCounted = Relics.new(catalog, accepted); assert(relics.install(turn))
	var powers: RefCounted = Powers.new(catalog, accepted); assert(powers.install(turn))
	data.turn = turn; data.fixture = fixture; data.cults = cults; data.relics = relics; data.powers = powers
	return data
func _attach_prayers(data: Dictionary) -> Dictionary:
	_attach_powers(data)
	var accepted: Dictionary = _event_issuers()
	data.prayers = Prayers.new(catalog, accepted); assert(data.prayers.install(data.turn))
	data.anchors = Anchors.new(catalog, accepted); assert(data.anchors.install(data.turn))
	data.events = Events.new(catalog); assert(data.events.install(data.turn))
	return data
func _install_anchors(data: Dictionary) -> void:
	_attach_prayers(data)
func _event_resolve(data: Dictionary, id: String, option: String) -> Dictionary:
	return _submit(data, "resolve_event", {"event": id, "action": option})
func _event_opportunity(data: Dictionary, id: String, option: String) -> Dictionary:
	return _submit(data, "act", {"participant": "events", "action": "opportunity", "payload": {"opportunity": id, "option": option}})
func _event_context(data: Dictionary, content: String, institution: String = "") -> Dictionary:
	for card: Dictionary in data.turn.context.events:
		if card.resolved or not data.world.state.event_system.cards.has(card.id): continue
		var descriptor: Dictionary = data.world.state.event_system.cards[card.id].descriptor
		if descriptor.content_id != content or descriptor.domain != data.domain: continue
		if not institution.is_empty() and descriptor.institution != institution: continue
		if data.has("situation") and content == "EVENT_12" and descriptor.get("prayer_descriptor", {}).get("source") != data.situation: continue
		return card
	return {}
func _given_fact(data: Dictionary, kind: String, actor: String, targets: Array, details: Dictionary, parents: Array = []) -> String:
	var values: Dictionary = details.duplicate(true)
	if kind == "faction_conflict": values.due = initial_conflict_due
	if kind == "pursuit_condition":
		var successors: Array = data.world.institution_successors(data.institution).filter(func(id: String) -> bool: return id != actor and id != values.get("pursuer"))
		if successors.is_empty():
			var role: String = data.world.state.institutions[data.institution].role
			var profile: String = {"interpretation": "NPC_PROFILE_01", "propagation": "NPC_PROFILE_03", "order": "NPC_PROFILE_05"}[role]
			var id: String = "NPC-%08d" % data.world.state.next_npc
			assert(data.world._nominate_local(data.domain, data.institution, profile, data.world.state.domains[data.domain].origin)); successors.append(id)
		if not successors.is_empty():
			data["cooperator"] = successors[0]
			_given_relation(data, actor, successors[0], "support")
	if review_role_fixture == "opponent" and kind == "pursuit_condition":
		var role: String = data.world.state.institutions[data.institution].role
		var profile: String = {"interpretation": "NPC_PROFILE_01", "propagation": "NPC_PROFILE_03", "order": "NPC_PROFILE_05"}[role]
		data.opponent = "NPC-%08d" % int(data.world.state.next_npc)
		assert(data.world._nominate_local(data.domain, data.institution, profile, data.world.state.domains[data.domain].origin))
		_given_relation(data, actor, data.opponent, "rival")
	if review_role_fixture == "heretic" and kind == "ritual_context" and not data.has("heretic"):
		data.heretic = _local_person(data.world, data.domain, data.domain + "/propagation", "NPC_PROFILE_03")
		_given_relation(data, actor, data.heretic, "support")
	if review_role_fixture == "custody" and kind == "message" and details.has("relic") and details.has("status_source"):
		var medium: Dictionary = Store.entry(data.world.state.relics, details.relic)
		data.recovery_authorization = data.world.introduce_fact("relic_recover_authorized", medium.domain, "", [medium.id], [details.status_source], {"proof": {"schema": 1, "issuer": "cult-fixture", "version": "1", "domain": medium.domain, "target": medium.id, "holder": "", "status_source": details.status_source}}, [])
	if review_role_fixture == "prophet_economy" and kind == "devotion_contact":
		assert(data.world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": data.cult, "institution": data.domain + "/propagation", "allowed": true, "issuer": "cult-fixture", "version": "1", "parents": [data.source]}))
	return super._given_fact(data, kind, actor, targets, values, parents)
func _event_wait(data: Dictionary, content: String, option: String, limit: int = 12) -> Dictionary:
	for attempt: int in limit:
		if data.turn.context.phase == "actions": assert(_evolve(data) and _finish(data))
		if data.turn.context.phase == "between": assert(_submit(data, "advance").ok)
		var card: Dictionary = _event_context(data, content, data.get("institution", ""))
		if not card.is_empty() and data.events.preview(data.turn, card.id, option).ok: return card
		assert(_submit(data, "finish_events").ok)
	return {}
func _event_support(data: Dictionary, variant: String = "deep") -> void:
	_choose_prayer_seed(data, "success", data.petitioner, data.domain)
	assert(_open(data))
	assert(_response(data, data.request, variant).ok)
	assert(_evolve(data) and _finish(data))
func _event_case(content: String) -> Dictionary:
	initial_conflict_due = 8 if content == "EVENT_09" else 3
	match content:
		"EVENT_02", "EVENT_04", "EVENT_05", "EVENT_06":
			var profile: String = {"EVENT_02": "CIV_01", "EVENT_04": "CIV_02", "EVENT_05": "CIV_06", "EVENT_06": "CIV_03"}[content]
			var data: Dictionary = _anchor_base(profile); _produce_support(data); return data
		"EVENT_08": return _event_trace_case()
		"EVENT_11": return _event_rewrite_case()
		"EVENT_12":
			var data: Dictionary = _prayer_case("PRAYER_04")
			return data
	var prayer: String = {"EVENT_01": "PRAYER_01", "EVENT_03": "PRAYER_03", "EVENT_07": "PRAYER_08", "EVENT_09": "PRAYER_10", "EVENT_10": "PRAYER_11"}[content]
	var data: Dictionary = _prayer_case(prayer)
	_event_support(data)
	return data
func _event_trace_case() -> Dictionary:
	# Existing movable medium and actual local evidence are initial conditions;
	# the resistance plan and event fixation are produced by World/Events.
	var data: Dictionary = _high()
	data.domain = "DOMAIN-001"; data.institution = data.domain + "/order"
	data.medium = data.world.state.anchors[data.anchors[data.domain + "/interpretation"]].relic
	data.world.state.domains[data.domain].alert = 35
	var exposure: String = data.world.introduce_fact("exposure", data.domain, data.leader, [data.medium], [data.source], {"public": false}, [data.leader], [data.institution])
	assert(not exposure.is_empty())
	data.world.history.rebuild(data.world.state); _attach_prayers(data)
	return data
func _event_rewrite_case() -> Dictionary:
	var data: Dictionary = _anchor_base("CIV_07")
	# Reach the original alert threshold through an explicit initial condition;
	# dual actual PR12 records must still produce the exception confirmation.
	# _anchor_base has attached but has no durable request receipt yet.
	_produce_support(data)
	return data
func _event_observe(data: Dictionary, preview: Dictionary) -> Dictionary:
	var people: Dictionary = {}
	for person: String in preview.descriptor.actors:
		people[person] = Store.entry(data.world.state.npcs, person).duplicate(true)
	return {"people": people, "domain": data.world.state.domains[data.domain].duplicate(true), "faith": data.world.state.faith, "whispers": data.world.state.whispers, "wounds": data.world.state.wounds, "cult": data.world.state.cults.get(data.get("cult", ""), {}).duplicate(true), "responses": data.turn.context.responses, "checks": _facts(data.world, "turn_check").size(), "relic": Store.entry(data.world.state.relics, preview.subjects.get("relic", ""), {}).duplicate(true)}
func _event_branch(content: String, option: String) -> void:
	var data: Dictionary = _event_case(content)
	var card: Dictionary = _event_wait(data, content, option)
	if card.is_empty():
		_check("EVENT/" + content + "/" + option, "真实来源到选项完整执行 " + content + option, false, {"reason": "No eligible actual event in bounded window", "ledger": data.world.state.event_system}); return
	var snapshot: String = data.turn.snapshot()
	var preview: Dictionary = data.events.preview(data.turn, card.id, option)
	var pure: bool = snapshot == data.turn.snapshot()
	var before: Dictionary = _event_observe(data, preview.preview)
	var result: Dictionary = _event_resolve(data, card.id, option)
	var outcomes: Array = _facts(data.world, "event_result").filter(func(f: Dictionary) -> bool: return f.changes.get("event") == card.id)
	var paid: int = int(catalog.tables.event_effects[content + "/" + option].faith_cost)
	var fee: bool = data.world.state.faith == before.faith - paid
	if content == "EVENT_01" and option == "B": fee = data.world.state.faith == mini(Economy.capacity(data.world.state, catalog), before.faith + 4)
	var effects: bool = result.ok and not outcomes.is_empty() and _event_effect_match(data, content, option, preview.preview, before, outcomes[0])
	event_rows.append({"content": content, "option": option, "turn": data.world.state.turn, "event": card.id, "source": preview.preview.source, "descriptor": preview.preview.descriptor, "cost": paid, "result": result})
	_check("EVENT/" + content + "/" + option, "真实来源/固定对象/确定性选项/精确费用/因果后果 " + content + option, pure and fee and effects and _facts(data.world, "turn_check").size() == before.checks and data.world.state.whispers == before.whispers and data.turn.context.responses == before.responses, event_rows[-1])
func _event_tag(data: Dictionary, outcome: String, tag: String) -> bool:
	return _facts(data.world, "event_fact").any(func(f: Dictionary) -> bool: return outcome in f.causal_parents and f.changes.get("tag") == tag)
func _event_effect_match(data: Dictionary, content: String, option: String, preview: Dictionary, before: Dictionary, outcome: Dictionary) -> bool:
	# Explicit behavior assertions are independent of the effect executor.
	if outcome.changes.content_id != content or outcome.changes.option != option: return false
	var world: RefCounted = data.world
	var domain: Dictionary = world.state.domains[data.domain]
	var subjects: Dictionary = preview.subjects; var facts: Dictionary = preview.facts
	var result: String = outcome.id
	match content:
		"EVENT_01":
			var person: Dictionary = Store.entry(world.state.npcs, subjects.survivor)
			return person.sanity == clampi(before.people[subjects.survivor].sanity + (5 if option == "A" else -10), 0, 100) and (_event_tag(data, result, "ordinary_life") if option == "A" else _event_tag(data, result, "mutated") and domain.alert == mini(100, before.domain.alert + 4) and _facts(world, "exposure").any(func(f: Dictionary) -> bool: return result in f.causal_parents and subjects.survivor in f.targets))
		"EVENT_02":
			if option == "A": return _event_tag(data, result, "private_records") and domain.alert == before.domain.alert
			var recognized: Array = _facts(world, "institution_event_result").filter(func(f: Dictionary) -> bool: return result in f.causal_parents and f.changes.get("event") == content)
			return domain.alert == mini(100, before.domain.alert + 6) and not recognized.is_empty() and Anchors.qualify(world.state, preview.institution, recognized[-1].id, catalog, world.history).allowed
		"EVENT_03":
			if option == "A": return world.state.institutions[preview.institution].representative == subjects.cooperator and domain.alert == mini(100, before.domain.alert + 2) and _facts(world, "relationship").any(func(f: Dictionary) -> bool: return result in f.causal_parents and f.changes.get("kind") == "favor_owed")
			return world.state.anchor_system.restrictions.has(preview.institution) and world.state.institutions[preview.institution].representative == subjects.get("opponent", "")
		"EVENT_04":
			if option == "A":
				var recognized: Array = _facts(world, "institution_event_result").filter(func(f: Dictionary) -> bool: return result in f.causal_parents and f.changes.get("event") == content)
				return not recognized.is_empty() and Anchors.qualify(world.state, preview.institution, recognized[-1].id, catalog, world.history).allowed and world.state.cults[data.cult].cohesion == maxi(0, before.cult.cohesion - 3) and domain.alert == mini(100, before.domain.alert + 4)
			var received: int = mini(4, before.domain.unnamed_nonfollowers) if subjects.has("heretic") else 0
			return domain.unnamed_followers == before.domain.unnamed_followers + received and not Anchors._current_restriction(world.state, preview.institution, preview.descriptor.basis, world.history).is_empty()
		"EVENT_05":
			if option == "A": return Store.has(world.state.invalid_records, facts.dependency) and _event_tag(data, result, "contract_released")
			return not Store.has(world.state.invalid_records, facts.dependency) and domain.alert == mini(100, before.domain.alert + 4) and _event_tag(data, result, "hostile_witness")
		"EVENT_06":
			if option == "A": return domain.stability == maxi(0, before.domain.stability - 6) and domain.alert == mini(100, before.domain.alert + 3) and facts.qualifications.all(func(id: String) -> bool: return not Store.has(world.state.invalid_records, id))
			return domain.stability == mini(100, before.domain.stability + 4) and facts.qualifications.filter(func(id: String) -> bool: return Store.has(world.state.invalid_records, id)).size() == 1 and _event_tag(data, result, "memory_dispute_closed")
		"EVENT_07":
			if option == "A": return Store.entry(world.state.npcs, subjects.prophet).loyalty == maxi(0, before.people[subjects.prophet].loyalty - 10) and Store.has(world.state.invalid_records, facts.prophet) and not world.state.event_system.prophets.has(subjects.prophet)
			return world.state.event_system.prophets.has(subjects.prophet) and world.state.cults[data.cult].cohesion == mini(100, before.cult.cohesion + 5)
		"EVENT_08":
			var relic: Dictionary = Store.entry(world.state.relics, subjects.relic)
			if option == "A": return relic.placement == "controlled" and relic.anchor.is_empty() and relic.holder.is_empty() and domain.pending_plan.is_empty() and _facts(world, "resistance_cancelled").any(func(f: Dictionary) -> bool: return result in f.causal_parents)
			var key: String = preview.institution + "|" + subjects.relic
			return relic.placement == before.relic.placement and relic.get("anchor") == before.relic.get("anchor") and domain.alert == mini(100, before.domain.alert + 6) and Store.has(world.state.evidence, key) and History.size(Store.entry(world.state.evidence, key).confirmations) > 0 and domain.pending_plan.is_empty()
		"EVENT_09":
			if option == "B": return _event_tag(data, result, "permission_opportunity_closed") and domain.alert == before.domain.alert
			return world.state.economy_qualifications.has("propagation|" + data.cult) and domain.alert == mini(100, before.domain.alert + 3) and _facts(world, "relationship").any(func(f: Dictionary) -> bool: return result in f.causal_parents and f.changes.get("kind") == "hostile")
		"EVENT_10":
			var relic: Dictionary = Store.entry(world.state.relics, subjects.relic)
			return relic.placement == "controlled" and relic.holder.is_empty() and domain.alert == mini(100, before.domain.alert + 8) and _event_tag(data, result, "institution_hostile") if option == "A" else relic.placement == "seized" and relic.captor == before.relic.captor and _event_tag(data, result, "recovery_opportunity_closed")
		"EVENT_11":
			if option == "A": return world.state.wounds == before.wounds and Store.has(world.state.invalid_records, facts.record) and domain.pending_plan.is_empty()
			return world.state.wounds == before.wounds + 8 and domain.pollution == maxi(0, before.domain.pollution - 10) and domain.pending_plan.is_empty()
		"EVENT_12":
			if option == "A": return not Store.entry(world.state.npcs, subjects.petitioner).get("bound_member", false) and _event_tag(data, result, "departed")
			var original: Dictionary = preview.descriptor.prayer_descriptor
			var reopened: Array = world.state.prayer_system.requests.values().filter(func(q: Dictionary) -> bool: return q.descriptor.subjects == original.subjects and q.descriptor.facts == original.facts and q.card.visible_turn == world.state.turn and q.status == "open")
			return reopened.size() == 1 and Store.entry(world.state.npcs, subjects.petitioner).loyalty == maxi(0, before.people[subjects.petitioner].loyalty - 5) and reopened[0].descriptor.crisis == original.crisis
	return false

func _event_blueprint(profile: String) -> void:
	var data: Dictionary = _anchor_base(profile)
	_produce_support(data)
	var row: Dictionary = catalog.tables.anchor_conditions[profile]
	var option: String = "B" if row.event_option == "*" else row.event_option
	var card: Dictionary = _event_wait(data, row.event_id, option)
	if card.is_empty():
		_check("EVENT-BLUEPRINT/" + profile, "真实祈求/事件/机构/机会/回收/锚定 " + profile, false, {"reason": "No current qualified event", "ledger": data.world.state.event_system}); return
	var secret_guard: bool = not data.events.preview(data.turn, card.id, "A").ok if profile == "CIV_05" else true
	var resolved: Dictionary = _event_resolve(data, card.id, option)
	var proofs: Array = _facts(data.world, "institution_event_result").filter(func(f: Dictionary) -> bool: return f.changes.institution == data.institution and f.changes.event == row.event_id)
	if not resolved.ok or proofs.is_empty():
		_check("EVENT-BLUEPRINT/" + profile, "真实祈求/事件/机构/机会/回收/锚定 " + profile, false, {"resolve": resolved, "proofs": proofs}); return
	data.proof = proofs[-1].id
	var qualified: bool = Anchors.qualify(data.world.state, data.institution, data.proof, catalog, data.world.history).allowed
	var opportunity: String = data.world.state.anchor_system.opportunities.get(data.institution, "")
	var offered: bool = not opportunity.is_empty()
	assert(_submit(data, "finish_events").ok)
	var recovery: Dictionary = _event_opportunity(data, opportunity, "recover") if offered else {"ok": false}
	var new_media: Array = []
	# The new medium has an authorization whose parents contain the opportunity.
	if new_media.is_empty():
		for medium: Dictionary in Store.values(data.world.state.relics):
			var origin: Dictionary = Store.entry(data.world.state.facts, medium.origin, {})
			if opportunity in data.world.history.export_value(origin.get("causal_parents", [])): new_media.append(medium)
	var created: Dictionary = {"ok": false}
	var paid: bool = false
	if recovery.ok and new_media.size() == 1:
		data.medium = new_media[0].id
		var before_faith: int = data.world.state.faith
		created = _create_anchor(data)
		paid = created.ok and data.world.state.faith < before_faith
	var anchored: bool = created.ok and data.world.state.anchors.has("ANCHOR/" + data.institution) and data.world.state.anchors["ANCHOR/" + data.institution].relic == data.medium
	_check("EVENT-BLUEPRINT/" + profile, "八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 " + profile, qualified and offered and recovery.ok and new_media.size() == 1 and anchored and paid and secret_guard, {"event": card.id, "proof": data.proof, "opportunity": opportunity, "recovery": recovery, "media": new_media.size(), "anchor": created})

func _actual_recognition(profile: String = "CIV_04") -> Dictionary:
	var data: Dictionary = _anchor_base(profile); _produce_support(data)
	var row: Dictionary = catalog.tables.anchor_conditions[profile]
	var option: String = "B" if row.event_option == "*" else row.event_option
	var card: Dictionary = _event_wait(data, row.event_id, option)
	assert(not card.is_empty() and _event_resolve(data, card.id, option).ok)
	data.event = card.id
	data.opportunity = data.world.state.anchor_system.opportunities.get(data.institution, "")
	assert(not data.opportunity.is_empty() and _submit(data, "finish_events").ok)
	return data
func _event_opportunities() -> void:
	for option: String in ["public", "wait", "recover"]:
		var data: Dictionary = _actual_recognition()
		var before: String = data.turn.snapshot()
		var preview: Dictionary = data.events.preview_opportunity(data.turn, {"opportunity": data.opportunity, "option": option})
		var pure: bool = before == data.turn.snapshot()
		var faith: int = data.world.state.faith; var alert: int = data.world.state.domains[data.domain].alert
		var relics: int = Store.size(data.world.state.relics)
		var result: Dictionary = _event_opportunity(data, data.opportunity, option)
		var effects: bool = false
		if option == "public": effects = data.world.state.faith == mini(Economy.capacity(data.world.state, catalog), faith + catalog.integer("relic_public_faith")) and data.world.state.domains[data.domain].alert == mini(100, alert + catalog.integer("relic_public_alert")) and Store.size(data.world.state.relics) == relics
		elif option == "recover": effects = data.world.state.faith == faith - catalog.integer("relic_recovery_faith") and Store.size(data.world.state.relics) == relics + 1
		else: effects = data.world.state.faith == faith and Store.size(data.world.state.relics) == relics and data.world.state.anchor_system.opportunities.get(data.institution) == data.opportunity
		var unique: bool = true
		if option != "wait":
			before = data.turn.snapshot()
			unique = not _event_opportunity(data, data.opportunity, "recover" if option == "public" else "public").ok and before == data.turn.snapshot()
		_check("EVT-OPPORTUNITY/" + option, "实际首次承认机会：" + option + "精确资源、唯一产物与互斥", preview.ok and pure and result.ok and effects and unique, {"opportunity": data.opportunity, "option": option, "result": result})
	var expired: Dictionary = _actual_recognition()
	var source: Dictionary = Store.entry(expired.world.state.facts, expired.opportunity)
	while expired.world.state.turn <= int(source.changes.due):
		if expired.turn.context.phase == "actions": assert(_evolve(expired) and _finish(expired))
		else: assert(_round(expired))
	var saved: String = expired.turn.snapshot()
	var denied: bool = not _event_opportunity(expired, expired.opportunity, "recover").ok and expired.turn.snapshot() == saved
	_check("EVT-OPPORTUNITY/expiry", "等待不刷新原due，到期无重复媒介和资源收益", denied and not expired.world.state.anchor_system.opportunities.has(expired.institution), {"original_due": source.changes.due, "turn": expired.world.state.turn})
func _event_pool_contracts() -> void:
	var data: Dictionary = _native()
	var rng: int = data.world.randoms.events.state
	assert(_submit(data, "advance").ok)
	var no_cards: bool = data.turn.context.events.is_empty()
	var snapshot: String = data.turn.snapshot()
	var invalid: bool = not _event_resolve(data, "nonexistent", "A").ok and snapshot == data.turn.snapshot()
	_check("EVT-POOL-001", "真实混合无重大来源允许零事件，不消耗events流或凭空补卡，未知请求原子拒绝", no_cards and invalid and rng == data.world.randoms.events.state)
	var lost: Dictionary = _event_case("EVENT_01")
	var original: String = lost.subjects.relative
	lost.fixture.deadlines = [_status(lost, original, "dead")]
	assert(_round(lost)); lost.fixture.deadlines = []
	for i: int in 4: assert(_round(lost))
	var candidates: Array = lost.world.state.event_system.cards.values().filter(func(entry: Dictionary) -> bool: return entry.descriptor.content_id == "EVENT_01")
	var results: Array = _facts(lost.world, "event_result").filter(func(f: Dictionary) -> bool: return f.changes.content_id == "EVENT_01")
	_check("EVT-POOL-002", "回调原幸存者在可见前死亡后不换人、不生成替代结果", Store.entry(lost.world.state.npcs, original).status == "dead" and results.is_empty() and candidates.all(func(entry: Dictionary) -> bool: return entry.descriptor.subjects.survivor == original and entry.status != "open"), {"original": original, "remaining": candidates.size()})
	var chosen: Dictionary = _event_case("EVENT_01")
	var card: Dictionary = _event_wait(chosen, "EVENT_01", "A")
	var first: Dictionary = _event_resolve(chosen, card.id, "A")
	snapshot = chosen.turn.snapshot()
	var duplicate: bool = not _event_resolve(chosen, card.id, "B").ok and snapshot == chosen.turn.snapshot()
	assert(_submit(chosen, "finish_events").ok)
	snapshot = chosen.turn.snapshot()
	var phase: bool = not _event_resolve(chosen, card.id, "A").ok and snapshot == chosen.turn.snapshot()
	_check("EVT-POOL-003", "同一已固化事件不重复选择，跨阶段请求不重付费或重放后果", first.ok and duplicate and phase and chosen.turn.context.events.size() <= catalog.integer("major_event_limit"))

func _event_pressure() -> void:
	var data: Dictionary = _high()
	data.domain = "DOMAIN-001"; data.institution = data.domain + "/order"
	var originals: Dictionary = {}
	for domain: String in ["DOMAIN-001", "DOMAIN-007", "DOMAIN-011"]:
		var institution: String = domain + "/order"
		var medium: String = data.world.state.anchors[data.anchors[domain + "/interpretation"]].relic
		data.world.state.domains[domain].alert = 35
		assert(not data.world.introduce_fact("exposure", domain, data.guardians[domain][2], [medium], [data.world.state.domains[domain].origin], {"public": false}, [data.guardians[domain][2]], [institution]).is_empty())
	data.world.history.rebuild(data.world.state); _attach_prayers(data)
	assert(_round(data))
	for domain: String in ["DOMAIN-001", "DOMAIN-007", "DOMAIN-011"]:
		var pending: Dictionary = data.world.state.domains[domain].pending_plan
		if not pending.is_empty() and pending.rule == "RESIST_TRACE": originals[domain] = pending.duplicate(true)
	assert(_round(data))
	var before: String = data.turn.snapshot()
	var rng: int = data.world.randoms.events.state
	assert(_submit(data, "advance").ok)
	var selected: Array = data.turn.context.events.map(func(card: Dictionary) -> String: return card.id)
	var chosen: Array = []
	for id: String in selected:
		var entry: Dictionary = data.world.state.event_system.cards[id]
		if entry.descriptor.content_id == "EVENT_08": chosen.append(id)
	var overflow_now: Array = _facts(data.world, "event_result").filter(func(f: Dictionary) -> bool: return f.changes.content_id == "EVENT_08" and f.turn == data.world.state.turn)
	var early: bool = data.turn.context.phase == "events" and overflow_now.size() == 1
	var after_rng: int = data.world.randoms.events.state
	var restored: bool = data.turn.restore(before)
	assert(_submit(data, "advance").ok)
	var repeat: Array = data.turn.context.events.map(func(card: Dictionary) -> String: return card.id)
	var deterministic: bool = restored and selected == repeat and after_rng == data.world.randoms.events.state
	assert(_submit(data, "finish_events").ok and _evolve(data) and _finish(data))
	var outcomes: Array = _facts(data.world, "event_result").filter(func(f: Dictionary) -> bool: return f.changes.content_id == "EVENT_08")
	var exact: bool = originals.size() == 3 and outcomes.size() == 3
	for domain: String in originals:
		var one: Array = outcomes.filter(func(f: Dictionary) -> bool: return f.domain == domain and f.changes.descriptor.facts.investigation == originals[domain].started_fact)
		exact = exact and one.size() == 1 and one[0].turn == originals[domain].due and one[0].changes.option == "B" and data.world.state.domains[domain].pending_plan.is_empty()
	_check("EVT-POOL-004", "三个真实调查同due仅占两主要位，第三原期限默认一次；同档独立events流存档复现", exact and early and chosen.size() == catalog.integer("major_event_limit") and deterministic and rng != after_rng, {"original_plans": originals, "chosen": chosen, "results": outcomes.size(), "deterministic": deterministic, "settled_in_phase_two": early})

func _event_cold_evidence() -> void:
	var data: Dictionary = _generated_profile("CIV_05")
	data.institution = data.domain + "/interpretation"; data.other = data.domain + "/propagation"; data.source = data.world.state.domains[data.domain].origin
	data.people = [_local_person(data.world, data.domain, data.institution), _local_person(data.world, data.domain, data.other, "NPC_PROFILE_03")]
	data.leader = data.people[0]
	data.economy = Economy.new(catalog, ISSUERS); assert(data.economy.initialize(data.world))
	data.world.state.faith = 80; data.world.state.domains[data.domain].alert = 0
	# Real initial contact qualifications; two subsequent dreams/checks are production.
	var contacts: Array = []
	for person: String in data.people: contacts.append(_given_fact(data, "message", person, [person], {"fixture": "existing_dream_contact", "institution": Store.entry(data.world.state.npcs, person).institution}))
	for seed_value: int in range(1, 100000):
		var random: RandomNumberGenerator = RandomNumberGenerator.new(); random.seed = seed_value
		if random.randi_range(1, 100) <= 10 and random.randi_range(1, 100) <= 10:
			data.world.randoms.checks.seed = seed_value; break
	_attach_prayers(data)
	var payloads: Array = []
	for i: int in 2:
		payloads.append({"npc": data.people[i], "source": contacts[i], "qualification": _qualification(data, "dream", data.people[i], data.people[i], data.domain, {"contact": contacts[i]}, Store.entry(data.world.state.npcs, data.people[i]).institution)})
	assert(_open(data) and _power(data, "POWER_DREAM", payloads[0]).ok)
	var first: Dictionary = _facts(data.world, "miracle").filter(func(f: Dictionary) -> bool: return f.changes.get("power") == "POWER_DREAM")[0]
	assert(_evolve(data) and _finish(data))
	for i: int in 9: assert(_round(data))
	var before: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(before)
	assert(_open(data) and _power(data, "POWER_DREAM", payloads[1]).ok and _evolve(data) and _finish(data))
	data.institution = data.other
	var card: Dictionary = _event_wait(data, "EVENT_02", "B")
	var descriptor: Dictionary = data.world.state.event_system.cards[card.id].descriptor if not card.is_empty() else {}
	var result: Dictionary = _event_resolve(data, card.id, "B") if not card.is_empty() else {"ok": false}
	var grants: Array = _facts(data.world, "institution_event_result").filter(func(f: Dictionary) -> bool: return f.changes.institution == data.institution and f.changes.event == "EVENT_02")
	_check("EVT-POOL-005", "旧真实梦境超过回调窗口仍可与新证词组合；冷索引存档恢复且不伪造第二见证", restored and result.ok and data.world.state.turn - first.turn > catalog.integer("history_callback_max_age") and first.id in descriptor.get("facts", {}).get("records", []) and grants.size() == 1 and Anchors.qualify(data.world.state, data.institution, grants[0].id, catalog, data.world.history).allowed, {"first": first.id, "age": data.world.state.turn - first.turn, "turn": data.world.state.turn, "event": card.get("id", ""), "result": result, "grants": grants.size()})

func _event_two_success_seed(data: Dictionary) -> void:
	for seed_value: int in range(1, 100000):
		var random: RandomNumberGenerator = RandomNumberGenerator.new(); random.seed = seed_value
		if random.randi_range(1, 100) <= 10 and random.randi_range(1, 100) <= 10:
			data.world.randoms.checks.seed = seed_value; return
	assert(false)
func _event_review_cases() -> void:
	_event_priority_layers()
	_event_economy_consumers()
	_event_selected_memory()
	_event_changed_custody()
	_event_existing_roles()
	_event_scoped_ritual()
	_event_one_memory_witness()
func _event_scoped_ritual() -> void:
	var data: Dictionary = _anchor_base("CIV_02")
	_event_two_success_seed(data)
	assert(_open(data) and _response(data, data.requests[0], "shallow").ok and _evolve(data) and _finish(data))
	data.outputs.append(data.requests[0])
	assert(_round(data))
	assert(_submit(data, "advance").ok)
	var first: Dictionary = _event_context(data, "EVENT_04", data.institution)
	var incomplete: bool = not first.is_empty() and not data.events.preview(data.turn, first.id, "A").ok
	var denied: Dictionary = _event_resolve(data, first.id, "B") if not first.is_empty() else {"ok": false}
	var ritual: String = _tag(data, data.requests[0], "ritual_witness")
	var restriction: String = Anchors._current_restriction(data.world.state, data.institution, {"priest": data.petitioner, "rituals": [ritual]}, data.world.history)
	assert(_submit(data, "finish_events").ok and _response(data, data.requests[1], "shallow").ok and _evolve(data) and _finish(data))
	data.outputs.append(data.requests[1])
	var next: Dictionary = _event_wait(data, "EVENT_04", "A")
	var granted: Dictionary = _event_resolve(data, next.id, "A") if not next.is_empty() else {"ok": false}
	var proofs: Array = _facts(data.world, "institution_event_result").filter(func(f: Dictionary) -> bool: return f.changes.get("event") == "EVENT_04" and f.changes.get("option") == "A")
	var qualified: bool = proofs.size() == 1 and Anchors.qualify(data.world.state, data.institution, proofs[0].id, catalog, data.world.history).allowed
	_check("EVT-REVIEW-001", "不完整首次仪式不能承认；原否认保留历史，跨轮完整同basis04A有源恢复", incomplete and denied.ok and not restriction.is_empty() and granted.ok and qualified and not Store.has(data.world.state.invalid_records, restriction), {"first": first.get("id", ""), "restriction": restriction, "later": next.get("id", ""), "grant": granted})
func _event_one_memory_witness() -> void:
	var data: Dictionary = _event_case("EVENT_06")
	data.fixture.deadlines = [_status(data, data.people[1], "dead"), _status(data, data.people[2], "dead")]
	assert(_round(data)); data.fixture.deadlines = []
	var card: Dictionary = _event_wait(data, "EVENT_06", "A")
	var stability: int = data.world.state.domains[data.domain].stability
	var result: Dictionary = _event_resolve(data, card.id, "A") if not card.is_empty() else {"ok": false}
	var proofs: Array = _facts(data.world, "institution_event_result").filter(func(f: Dictionary) -> bool: return f.changes.get("event") == "EVENT_06")
	_check("EVT-REVIEW-002", "原三人仅一存活仍可保存记忆分歧，不以不足完整蓝本伪造制度承认", result.ok and proofs.is_empty() and data.world.state.domains[data.domain].stability == maxi(0, stability - 6), {"event": card.get("id", ""), "result": result, "grants": proofs.size()})

func _event_existing_roles() -> void:
	review_role_fixture = "opponent"
	var opponent: Dictionary = _event_case("EVENT_03")
	review_role_fixture = ""
	var card: Dictionary = _event_wait(opponent, "EVENT_03", "B")
	var descriptor: Dictionary = opponent.world.state.event_system.cards[card.id].descriptor if not card.is_empty() else {}
	var result: Dictionary = _event_resolve(opponent, card.id, "B") if not card.is_empty() else {"ok": false}
	_check("EVT-REVIEW-003", "原处境真实rival且岗位合法的既存对手在03B实际继任", result.ok and descriptor.get("subjects", {}).get("opponent") == opponent.opponent and opponent.world.state.institutions[opponent.institution].representative == opponent.opponent, {"descriptor": descriptor, "result": result})
	review_role_fixture = "heretic"
	var heretic: Dictionary = _event_case("EVENT_04")
	heretic.fixture.deadlines = []
	review_role_fixture = ""
	card = _event_wait(heretic, "EVENT_04", "B")
	descriptor = heretic.world.state.event_system.cards[card.id].descriptor if not card.is_empty() else {}
	var followers: int = heretic.world.state.domains[heretic.domain].unnamed_followers
	var available: int = heretic.world.state.domains[heretic.domain].unnamed_nonfollowers
	result = _event_resolve(heretic, card.id, "B") if not card.is_empty() else {"ok": false}
	_check("EVT-REVIEW-004", "04B原关系里的合法传播合作者被固化并实际接收四名信众", result.ok and descriptor.get("subjects", {}).get("heretic") == heretic.heretic and heretic.world.state.domains[heretic.domain].unnamed_followers == followers + mini(4, available), {"descriptor": descriptor, "result": result})

func _event_changed_custody() -> void:
	review_role_fixture = "custody"
	var data: Dictionary = _prayer_case("PRAYER_11")
	review_role_fixture = ""
	_choose_prayer_seed(data, "success", data.petitioner, data.domain)
	assert(_open(data) and _response(data, data.request, "deep").ok)
	var recovered: Dictionary = _submit(data, "act", {"participant": "relics", "action": "relic_recover", "payload": {"relic": data.subjects.relic, "source": data.recovery_authorization}})
	assert(_evolve(data) and _finish(data) and _round(data))
	var results: Array = _facts(data.world, "event_result").filter(func(f: Dictionary) -> bool: return f.changes.content_id == "EVENT_10")
	var cancelled: Array = _facts(data.world, "event_cancelled").filter(func(f: Dictionary) -> bool: return f.changes.content_id == "EVENT_10")
	_check("EVT-REVIEW-005", "真实回收改变原持有版本，旧10A/B均失格并结案、不换媒介或发放重复收益", recovered.ok and Store.entry(data.world.state.relics, data.subjects.relic).placement == "controlled" and results.is_empty() and cancelled.size() == 1, {"recovery": recovered, "old_results": results.size(), "cancelled": cancelled.size()})

func _event_selected_memory() -> void:
	var data: Dictionary = _event_case("EVENT_06")
	var card: Dictionary = _event_wait(data, "EVENT_06", "B")
	assert(not card.is_empty())
	var descriptor: Dictionary = data.world.state.event_system.cards[card.id].descriptor
	var chosen: String = descriptor.facts.qualifications[-1]
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.events.preview(data.turn, card.id, "B", {"qualification": chosen})
	var pure: bool = before == data.turn.snapshot()
	var invalid: Dictionary = _submit(data, "resolve_event", {"event": card.id, "action": "B", "payload": {"qualification": data.source}})
	var rejects: bool = not invalid.ok and before == data.turn.snapshot()
	var result: Dictionary = _submit(data, "resolve_event", {"event": card.id, "action": "B", "payload": {"qualification": chosen}})
	var dropped: Array = descriptor.facts.qualifications.filter(func(id: String) -> bool: return Store.has(data.world.state.invalid_records, id))
	_check("EVT-REVIEW-006", "06B纯预览明确选择非首份原资格，陌生ID拒绝且只撤所选一份", preview.ok and pure and rejects and result.ok and dropped == [chosen], {"chosen": chosen, "dropped": dropped, "result": result})

func _response(data: Dictionary, request: String, variant: String, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super._response(data, request, variant, options)
	if result.ok and data.has("heretic"):
		var actual: Array = _prayer_outputs(data, request, "prayer_result")
		if not actual.is_empty():
			var source: String = actual[0].id
			data.fixture.deadlines = [{"type": "world_command", "source": source, "command": {"kind": "share_record", "npc": data.petitioner, "institution": Store.entry(data.world.state.npcs, data.heretic).institution, "source": source, "parents": [source]}}]
	return result

func _event_expand(data: Dictionary) -> Dictionary:
	assert(_submit(data, "finish_events").ok)
	var plan: Dictionary = {"strategies": {data.cult: "expand"}, "anchor_priority": [], "refuse_anchors": []}
	var before: String = data.turn.snapshot()
	var preview: Dictionary = data.turn.preview_plan("economy", plan)
	var pure: bool = before == data.turn.snapshot()
	var planned: Dictionary = _submit(data, "set_plan", {"participant": "economy", "payload": plan})
	var evolved: bool = _evolve(data) if planned.ok else false
	var work: Array = _facts(data.world, "economy_work").filter(func(f: Dictionary) -> bool: return f.turn == data.world.state.turn and f.changes.cult == data.cult)
	return {"ok": preview.ok and pure and planned.ok and evolved and work.size() == 1, "preview": preview, "work": work[0] if work.size() == 1 else {}}
func _event_economy_consumers() -> void:
	var cases: Array = []
	for option: String in ["A", "B"]:
		review_role_fixture = "prophet_economy"
		var data: Dictionary = _event_case("EVENT_07")
		review_role_fixture = ""
		var card: Dictionary = _event_wait(data, "EVENT_07", option)
		var resolved: Dictionary = _event_resolve(data, card.id, option) if not card.is_empty() else {"ok": false}
		var work: Dictionary = _event_expand(data)
		var actual: Dictionary = work.get("work", {})
		var wanted: int = catalog.integer("expansion_alert") + (1 if option == "B" else 0)
		cases.append(resolved.ok and work.ok and actual.changes.growth > 0 and actual.changes.alert == wanted)
	_check("EVT-REVIEW-007", "明示既有传播资格合同：实际07B仅传教时加一察觉，07A无该加成", not false in cases, {"cases": cases})
	var data: Dictionary = _event_case("EVENT_09")
	var card: Dictionary = _event_wait(data, "EVENT_09", "A")
	var resolved: Dictionary = _event_resolve(data, card.id, "A") if not card.is_empty() else {"ok": false}
	var permit: String = data.world.state.economy_qualifications.get("propagation|" + data.cult, "")
	var work: Dictionary = _event_expand(data)
	_check("EVT-REVIEW-008", "真实09A许可进入经济预览/计划与实际传播，原许可保留直接因果父项", resolved.ok and work.ok and work.work.changes.growth > 0 and permit in work.work.causal_parents, {"permit": permit, "work": work.get("work", {}), "resolved": resolved})

func _event_priority_layers() -> void:
	var data: Dictionary = _anchor_base("CIV_02")
	# A third explicit, independent initial situation makes two real unanswered
	# requests expire. Ambient candidate sampling must not supply this premise.
	assert(Store.size(data.turn.context.receipts) == 0)
	var initial: RefCounted = preload("res://src/simulation/transaction.gd").new(data.world, data.turn.context, data.turn.commit_sequence)
	assert(initial.activate())
	var actor: String = data.people[1]
	var ritual: String = data.world.introduce_fact("ritual_context", data.domain, actor, [actor], [data.source], {"subject": actor, "institution": data.institution, "turn": 0}, [actor], [], data.turn)
	assert(not ritual.is_empty())
	var situation: String = data.world.introduce_fact("prayer_situation", data.domain, actor, [actor], [ritual], {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers.PRAYER_05.need, "domain": data.domain, "institution": data.institution, "actors": [actor], "subjects": {"petitioner": actor}, "facts": {"ritual": ritual}, "crisis": {}}, [actor], [], data.turn)
	assert(not situation.is_empty() and data.world.fix_prayer_source(situation, data.turn))
	data.world.attention.sync(data.world)
	var initial_errors: Array = initial.validate_world()
	assert(initial_errors.is_empty(), str(initial_errors))
	initial.publish(); data.turn.context = initial.context
	_choose_prayer_seed(data, "success", data.petitioner, data.domain)
	assert(_round(data) and _open(data) and _response(data, data.requests[1], "shallow").ok and _evolve(data) and _finish(data) and _round(data))
	assert(_submit(data, "advance").ok)
	var selected: Array = data.turn.context.events
	var high: Dictionary = {}
	var earlier: Array = []
	for entry: Dictionary in data.world.state.event_system.cards.values():
		if entry.descriptor.content_id == "EVENT_04": high = entry.descriptor
		elif entry.descriptor.content_id == "EVENT_12" and entry.descriptor.due_turn > data.world.state.turn: earlier.append(entry.descriptor)
	var first: Dictionary = data.world.state.event_system.cards[selected[0].id].descriptor if not selected.is_empty() else {}
	_check("EVT-REVIEW-009", "同为窗口内第三层，较高原priority先于更近due；不能仅按due压掉人物机构事件", not high.is_empty() and earlier.size() >= 2 and first.get("content_id") == "EVENT_04" and earlier.all(func(d: Dictionary) -> bool: return d.due_turn < high.due_turn), {"first": first, "earlier_low_priority": earlier.size(), "selected": selected.size()})
