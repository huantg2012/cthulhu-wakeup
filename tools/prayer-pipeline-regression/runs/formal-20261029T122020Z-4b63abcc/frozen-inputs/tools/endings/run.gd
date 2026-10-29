extends "res://tools/resistance/review_cases.gd"
const Endings = preload("res://src/game/endings.gd")
const EndingTransaction = preload("res://src/simulation/transaction.gd")
class FailingEndings extends Endings:
	var fault: bool = false
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		if fault: return {"ok": false}
		return super.handle(view, input)
	var fault_after_commit: bool = false
	func commit(world: RefCounted, effect: Dictionary, owner: RefCounted) -> bool:
		var accepted: bool = super.commit(world, effect, owner)
		return accepted and not fault_after_commit

# Keep every production participant. The test event source owns deadlines only;
# the production Endings participant is the sole terminal-phase owner.
func _attach_powers(data: Dictionary) -> Dictionary:
	var accepted: Dictionary = _event_issuers()
	if data.get("profile") == "CIV_07":
		data.world.state.domains[data.domain].alert = 85
		data.world.state.insight = 20
		data.world._refresh_anchors()
	data.world.state.economy.issuers = accepted.duplicate(true)
	data.economy = Economy.new(catalog, accepted)
	var turn: RefCounted = Turn.new(data.world); assert(turn._attached)
	assert(data.economy.install(turn))
	var fixture: RefCounted = EventFixture.new()
	assert(turn.register_participant("event-fixture", "1", ["deadlines"], ["fact", "world_command", "resource", "schedule", "check", "wounds"], fixture.handle))
	var cults: RefCounted = Cults.new(catalog); assert(cults.install(turn))
	var relics: RefCounted = Relics.new(catalog, accepted); assert(relics.install(turn))
	var powers: RefCounted = Powers.new(catalog, accepted); assert(powers.install(turn))
	data.turn = turn; data.fixture = fixture; data.cults = cults; data.relics = relics; data.powers = powers
	return data

func _attach_prayers(data: Dictionary) -> Dictionary:
	super._attach_prayers(data)
	data.endings = FailingEndings.new(catalog); assert(data.endings.install(data.turn))
	return data

func run_propagation() -> void:
	super.run_propagation()
	_end_disconnected()
	_end_contact_recovery()
	_end_future_prayer()
	_end_detention_boundaries()
	_end_zero()
	_end_abandon()
	_end_abandon_phases()
	if has_method("run_manifest_endings"): call("run_manifest_endings")

func _end_empty() -> Dictionary:
	# This midgame no-contact fixture deliberately keeps living people and their
	# old histories. No cult, fixed prayer, revealed contact or future promise is
	# invented. Assigned simulation with no bootstrap is an existing formal API.
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	assert(world.configure_assigned_simulation(["DOMAIN-001"]))
	var data: Dictionary = {"world": world, "domain": "DOMAIN-001", "source": world.state.domains["DOMAIN-001"].origin, "leader": world.state.institutions["DOMAIN-001/interpretation"].representative}
	var economy: RefCounted = Economy.new(catalog, _event_issuers()); assert(economy.initialize(world)); data.economy = economy
	# A genuinely contactless current situation, without disabling proposals:
	# no barrier to escape and no unnamed nonfollowers for a devotion nominee.
	# Existing living people and total populations remain intact.
	for domain: String in world.state.domains:
		world.state.domains[domain].barrier = 0
		var amount: int = world.state.domains[domain].unnamed_nonfollowers
		assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": amount, "parents": [world.state.domains[domain].origin]}))
	# Current rituals are a real additional contact path. This explicit initial
	# situation has no practicing ritual keeper; living people, valid institutions
	# and ordinary background proposal processing remain enabled.
	for person: Dictionary in Store.values(world.state.npcs):
		person.role_tags.erase("ritual_keeper")
	world.history.rebuild(world.state)
	_attach_prayers(data)
	return data

func _end_disconnected() -> void:
	var data: Dictionary = _end_empty()
	var observations: Array = []
	for i: int in catalog.integer("disconnection_limit"):
		assert(_round(data))
		observations.append({"turn": data.world.state.turn, "phase": data.turn.context.phase, "preview": data.endings.preview(data.turn)})
	var exact: bool = observations.size() == 3 and observations[0].phase == "between" and observations[1].phase == "between" and observations[2].phase == "ended"
	_check("END-CONTACT-001", "活人及既有历史不永久续命，连续断联第三轮结束而前两轮仍可操作", exact and Store.values(data.world.state.npcs).any(func(n: Dictionary) -> bool: return n.status == "active"), {"observations": observations})
	_end_archive(data)

func _end_zero() -> void:
	var data: Dictionary = _end_empty()
	# Initial sourced wounds are a preexisting condition; the ending itself must
	# be chosen by the real sixth stage, not by test-setting the ended flag.
	data.fixture.gather = [{"type": "wounds", "source": data.source, "delta": catalog.integer("initial_awakening")}]
	assert(_open(data) and _evolve(data))
	var before_ending: bool = data.turn.context.phase != "ended"
	assert(_finish(data))
	_check("END-LIFE-001", "世界到期伤害使当前苏醒归零，统一轮末终局而不提前截断输入", before_ending and data.world.state.awakening == 0 and data.turn.context.phase == "ended", {"phase": data.turn.context.phase, "preview": data.endings.preview(data.turn)})

func _end_abandon() -> void:
	var data: Dictionary = _res_base("RESIST_TRACE")
	assert(_open(data))
	var result: Dictionary = _submit(data, "abandon")
	var snapshot: String = data.turn.snapshot()
	var rejected: bool = true
	for operation: String in ["advance", "end_actions", "finish_events", "abandon"]:
		var response: Dictionary = _submit(data, operation)
		rejected = not response.ok and data.turn.snapshot() == snapshot and rejected
	var review: Dictionary = data.endings.review(data.turn)
	_check("END-LIFE-002", "主动自弃独立结束，已结束世界拒绝全部普通操作且回顾纯读", result.ok and data.turn.context.phase == "ended" and rejected and snapshot == data.turn.snapshot() and review.get("ok", false), {"result": result, "review": review, "rejected": rejected})

func _end_archive(data: Dictionary) -> void:
	var snapshot: String = data.turn.snapshot()
	var review: Dictionary = data.endings.review(data.turn)
	var pure: bool = snapshot == data.turn.snapshot()
	var restored: bool = data.turn.restore(snapshot)
	var again: Dictionary = data.endings.review(data.turn)
	var archive: String = scratch.path_join("ended-" + str(Time.get_ticks_usec()))
	var saved: bool = data.turn.save_archive(archive)
	var loaded: bool = data.turn.load_archive(archive) if saved else false
	_check("END-SAVE-001", "已结束世界快照与分页存档恢复仍为回顾，原身份历史与摘要一致", pure and restored and review == again and saved and loaded and data.turn.context.phase == "ended" and data.turn.snapshot() == snapshot, {"restored": restored, "saved": saved, "loaded": loaded, "review": review})
	var denied: bool = true
	for field: String in ["disconnected", "terminal", "last_turn"]:
		var envelope: Dictionary = JSON.parse_string(snapshot)
		var world: Dictionary = JSON.parse_string(envelope.body.world)
		if field == "terminal": world.body.state.ending_system.terminal = ""
		else: world.body.state.ending_system[field] = 0
		world.checksum = World.canonical(world.body).sha256_text(); envelope.body.world = World.canonical(world)
		envelope.checksum = World.canonical(envelope.body).sha256_text()
		denied = not data.turn.restore(World.canonical(envelope)) and data.turn.snapshot() == snapshot and denied
	var contacted: Dictionary = _res_base("RESIST_TRACE")
	assert(_round(contacted))
	var contact_saved: String = contacted.turn.snapshot()
	for field: String in ["kind", "subject"]:
		var envelope: Dictionary = JSON.parse_string(contact_saved)
		var world: Dictionary = JSON.parse_string(envelope.body.world)
		var source: String = world.body.state.ending_system.assessment
		var contact: Dictionary = world.body.state.facts[source].changes.contacts[0]
		contact[field] = "medium" if field == "kind" else "CULT-DOES-NOT-EXIST"
		world.checksum = World.canonical(world.body).sha256_text(); envelope.body.world = World.canonical(world)
		envelope.checksum = World.canonical(envelope.body).sha256_text()
		denied = not contacted.turn.restore(World.canonical(envelope)) and contacted.turn.snapshot() == contact_saved and denied
	_check("END-SAVE-004", "重算checksum的封存/计数/时间及有效联系kind/subject伪造拒绝且不半覆盖", denied)

func _end_listen_source(data: Dictionary) -> Dictionary:
	var hidden: String = data.world.introduce_fact("message", data.domain, "", [], [data.source], {"fixture": "unrevealed_finite_fact"}, [], [], data.turn)
	var clue: String = data.world.introduce_fact("message", data.domain, "", [], [data.source], {"target_fact": hidden, "fixture": "actual_current_medium_clue"}, [], [], data.turn)
	var source: String = _qualification(data, "listen", hidden, "", data.domain, {"clue": clue, "fact": hidden})
	return {"domain": data.domain, "source": source, "qualification": source}

func _end_contact_recovery() -> void:
	var data: Dictionary = _end_empty()
	# Initial unknown fact and clue are not yet an authorized executable contact.
	var hidden: String = data.world.introduce_fact("message", data.domain, "", [], [data.source], {"fixture": "unrevealed_finite_fact"}, [], [], data.turn)
	var clue: String = data.world.introduce_fact("message", data.domain, "", [], [data.source], {"target_fact": hidden}, [], [], data.turn)
	assert(_round(data) and _round(data))
	var before: int = data.world.state.ending_system.disconnected
	# The upstream source contract creates the authorization inside the actual
	# deadline transaction, never mutating an already published World root.
	data.fixture.gather = [{"type": "fact", "kind": "power_qualification", "source": data.source, "domain": data.domain, "actor": "", "targets": [hidden], "parents": [data.source, clue, hidden], "details": {"issuer": "cult-fixture", "version": "1", "rule": "listen", "target": hidden, "actor": "", "institution": "", "basis": {"clue": clue, "fact": hidden}}, "observers": [], "institutions": []}]
	assert(_round(data))
	data.fixture.gather = []
	var sources: Array = _facts(data.world, "power_qualification").filter(func(f: Dictionary) -> bool: return f.changes.rule == "listen" and f.changes.target == hidden)
	assert(sources.size() == 1)
	var payload: Dictionary = {"domain": data.domain, "source": sources[0].id, "qualification": sources[0].id}
	var snapshot: String = data.turn.snapshot()
	var preview: Dictionary = data.endings.preview(data.turn)
	var pure: bool = snapshot == data.turn.snapshot()
	var reset: bool = data.world.state.ending_system.disconnected == 0
	assert(_open(data))
	var consumed: Dictionary = _power(data, "POWER_LISTEN", payload)
	assert(_evolve(data) and _finish(data))
	var consumed_saved: String = data.turn.snapshot()
	var historical_valid: bool = data.turn.restore(consumed_saved)
	_check("END-CONTACT-002", "第二轮后实际合法零信仰线索恢复清零，真实聆听消费后历史不续命但历史评估仍可读档", before == 2 and pure and preview.contacts.any(func(c: Dictionary) -> bool: return c.kind == "medium" and c.source == payload.source) and reset and consumed.ok and data.world.state.ending_system.disconnected == 1 and historical_valid, {"before": before, "preview": preview, "reset": reset, "consumed": consumed, "after": data.world.state.ending_system.disconnected, "historical_restore": historical_valid})

func _end_fixed_prayer() -> Dictionary:
	var data: Dictionary = _end_empty()
	data.world.state.faith = 0
	var domain: String = "DOMAIN-002"
	var actor: String = data.world.state.institutions[domain + "/interpretation"].representative
	var origin: String = data.world.state.domains[domain].origin
	var record: String = data.world.introduce_fact("exposure", domain, actor, [actor], [origin], {"public": false, "fixture": "existing_personal_unexplained_record"}, [actor], [], data.turn)
	var descriptor: Dictionary = {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers.PRAYER_04.need, "domain": domain, "institution": domain + "/interpretation", "actors": [actor], "subjects": {"petitioner": actor}, "facts": {"record": record}, "crisis": {}}
	var source: String = data.world.introduce_fact("prayer_situation", domain, actor, [actor], [record], descriptor, [actor], [], data.turn)
	assert(not source.is_empty() and data.world.fix_prayer_source(source, data.turn))
	data.contact_domain = domain; data.contact_actor = actor; data.contact_record = record
	return data

func _end_future_prayer() -> void:
	var data: Dictionary = _end_fixed_prayer()
	var domain: String = data.contact_domain
	var actor: String = data.contact_actor
	var record: String = data.contact_record
	var preview: Dictionary = data.endings.preview(data.turn)
	var has_future: bool = preview.contacts.any(func(c: Dictionary) -> bool: return c.kind == "prayer" and c.due >= 1)
	assert(_round(data))
	var protected: bool = data.world.state.ending_system.disconnected == 0
	# The real person's subsequent death invalidates this specific promise.
	data.fixture.deadlines = [{"type": "world_command", "source": record, "command": {"kind": "status", "npc": actor, "status": "dead", "parents": [record]}}]
	assert(_round(data)); data.fixture.deadlines = []
	_check("END-CONTACT-003", "未观察后台的真实固化祈求有对象与期限可续联，主体死亡立即失效", has_future and protected and not domain in data.world.state.simulation.focused and data.world.state.ending_system.disconnected == 1, {"future": preview, "protected": protected, "after_death": data.endings.preview(data.turn), "domain": domain})

func _end_detention_boundaries() -> void:
	var valid: bool = true
	var cases: Array = []
	for mode: String in ["within", "late", "wrong_source"]:
		var data: Dictionary = _end_fixed_prayer()
		# Explicit initial timed detention contract before any player receipt.
		# Use an actual overlay and actual identity transition; never unseal a
		# published root or mutate a running session's status without a command.
		assert(Store.size(data.turn.context.receipts) == 0)
		var tx: RefCounted = EndingTransaction.new(data.world, data.turn.context, data.turn.commit_sequence)
		assert(tx.activate())
		assert(data.world.submit({"kind": "status", "npc": data.contact_actor, "status": "detained", "parents": [data.contact_record]}, data.turn))
		var source: String = Store.entry(data.world.state.npcs, data.contact_actor).status_source
		data.world.stage_collections(["power_system"])
		data.world.state.power_system.detentions[data.contact_actor] = {"due": 4 if mode == "late" else 2, "source": source}
		if mode == "wrong_source":
			assert(data.world.submit({"kind": "status", "npc": data.contact_actor, "status": "active", "parents": [source]}, data.turn))
			assert(data.world.submit({"kind": "status", "npc": data.contact_actor, "status": "detained", "parents": [source]}, data.turn))
		var errors: Array = tx.validate_world()
		assert(errors.is_empty(), str(errors))
		tx.publish(); data.turn.context = tx.context
		var before: String = data.turn.snapshot()
		var preview: Dictionary = data.endings.preview(data.turn)
		var contact: bool = preview.contacts.any(func(c: Dictionary) -> bool: return c.kind == "prayer" and source in c.get("releases", []))
		var one: bool = data.turn.snapshot() == before and contact == (mode == "within")
		valid = valid and one
		cases.append({"mode": mode, "preview": preview, "source": source, "valid_world": errors.is_empty(), "pure": data.turn.snapshot() == before})
	_check("END-CONTACT-004", "真实既存拘禁期限须覆盖同一祈求窗口，晚释放或身份source不符不得虚假续联", valid, {"cases": cases})

func _end_abandon_phases() -> void:
	var valid: bool = true
	var cases: Array = []
	for phase: String in ["between", "events", "actions", "evolution", "settlement", "ending"]:
		var data: Dictionary = _res_base("RESIST_TRACE")
		var recovered: Dictionary = _res_base("RESIST_TRACE")
		if phase != "between": assert(_submit(data, "advance").ok)
		if phase in ["actions", "evolution", "settlement", "ending"]: assert(_submit(data, "finish_events").ok)
		if phase in ["evolution", "settlement", "ending"]: assert(_submit(data, "end_actions").ok)
		if phase in ["settlement", "ending"]: assert(_submit(data, "advance").ok)
		if phase == "ending": assert(_submit(data, "advance").ok)
		assert(data.turn.context.phase == phase)
		var faith: int = data.world.state.faith
		var rng: int = data.world.randoms.checks.state
		var turn: int = data.world.state.turn
		var result: Dictionary = _submit(data, "abandon")
		var snapshot: String = data.turn.snapshot()
		var restored: bool = data.turn.restore(snapshot)
		var replayed: bool = _replay_missing(data, recovered)
		var one: bool = result.ok and restored and replayed and data.turn.context.phase == "ended" and data.world.state.turn == turn and data.world.state.faith == faith and data.world.randoms.checks.state == rng
		valid = valid and one
		cases.append({"phase": phase, "turn": turn, "result": result, "restored": restored, "replayed": replayed, "no_extra_income_or_roll": data.world.state.faith == faith and data.world.randoms.checks.state == rng})
	_check("END-LIFE-003", "包括turn0在内六个未结束阶段自弃都可保存/重放，不多推进收入或随机", valid, {"cases": cases})
