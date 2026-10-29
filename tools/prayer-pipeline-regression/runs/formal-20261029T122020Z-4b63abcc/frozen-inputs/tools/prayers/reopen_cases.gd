extends "res://tools/prayers/run.gd"
## Upstream fixtures produce only typed authorizations/situations. The production
## freeze, source fixation, response, crisis deadline and restoration do all work.
class ReopenFixture extends Fixture:
	var resolve_facts: Array = []
	var fixed_candidate: String = ""
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var result: Dictionary = super.handle(view, input)
		if input.get("operation") == "resolve_event":
			result.effects = resolve_facts.duplicate(true)
			result.empty = result.effects.is_empty()
			if not result.effects.is_empty():
				var actors: Array = result.effects[0].targets
				result.meta.attention = {"family": "event", "content_id": "EVENT_12", "variant": "B", "target": result.effects[0].domain, "participants": actors, "fixed": actors, "candidate": fixed_candidate}
		return result

func _reopen_fact(data: Dictionary, kind: String, details: Dictionary, parents: Array) -> Dictionary:
	return {"type": "fact", "kind": kind, "domain": data.domain, "actor": data.petitioner, "targets": [data.petitioner, data.subjects.relative], "source": data.situation, "parents": parents, "details": details, "observers": [], "institutions": []}

func _reopen_given() -> Dictionary:
	var data: Dictionary = _high()
	var world: RefCounted = data.world
	data.domain = "DOMAIN-001"; data.petitioner = data.guardians[data.domain][0]
	data.institution = Store.entry(world.state.npcs, data.petitioner).institution
	var relative: String = data.guardians[data.domain][1]
	data.subjects = {"petitioner": data.petitioner, "relative": relative}
	var harm: String = _given_fact(data, "harm", relative, [relative], {"fixture": "existing_dying_condition_due_seven"})
	data.fact_map = {"condition": _given_fact(data, "dying_condition", data.petitioner, [relative], {"patient": relative, "due": 7}, [harm]), "relation": _given_relation(data, data.petitioner, relative, "family")}
	var situation: Dictionary = {"issuer": "cult-fixture", "version": "1", "need": catalog.tables.prayers.PRAYER_01.need, "domain": data.domain, "institution": data.institution, "actors": [data.petitioner, relative], "subjects": data.subjects, "facts": data.fact_map, "crisis": {"source": data.fact_map.condition, "due": 7}}
	data.situation = world.introduce_fact("prayer_situation", data.domain, data.petitioner, situation.actors, [data.fact_map.condition, data.fact_map.relation], situation, situation.actors)
	world.attention.sync(world); world.history.rebuild(world.state)
	var turn: RefCounted = Turn.new(world); assert(turn._attached and data.economy.install(turn))
	var fixture: RefCounted = ReopenFixture.new()
	assert(turn.register_participant("cult-fixture", "1", ["events", "deadlines", "ending"], ["fact", "world_command", "resource", "schedule"], fixture.handle))
	data.cults = Cults.new(catalog); assert(data.cults.install(turn))
	data.relics = Relics.new(catalog, ISSUERS); assert(data.relics.install(turn))
	data.powers = Powers.new(catalog, ISSUERS); assert(data.powers.install(turn))
	data.prayers = Prayers.new(catalog, ISSUERS); assert(data.prayers.install(turn))
	data.turn = turn; data.fixture = fixture
	assert(world.fix_prayer_source(data.situation, turn))
	for id: String in world.state.simulation.candidates:
		if world.state.simulation.candidates[id].get("source") == data.situation: data.request = id
	fixture.fixed_candidate = data.request
	return data

func run_reopen_cases() -> void:
	var data: Dictionary = _reopen_given()
	_choose_prayer_seed(data, "failure", data.petitioner, data.domain)
	assert(_open(data) and _response(data, data.request, "shallow").ok)
	var first_result: Dictionary = _facts(data.world, "prayer_result")[-1]
	assert(first_result.changes.outcome == "failure" and _evolve(data) and _finish(data))
	data.fixture.cost = 1
	data.fixture.gather = [_reopen_fact(data, "prayer_reopen_authorized", {"issuer": "cult-fixture", "version": "1", "parent": data.situation}, [data.situation, first_result.id])]
	assert(_submit(data, "advance").ok)
	var auth: String = _facts(data.world, "prayer_reopen_authorized")[-1].id
	var original: Dictionary = Store.entry(data.world.state.facts, data.situation).changes
	var authorized: Dictionary = original.duplicate(true); authorized.reopen = auth
	var no_auth: Dictionary = original.duplicate(true)
	var changed: Dictionary = authorized.duplicate(true); changed.crisis.due = 8
	var changed_subject: Dictionary = authorized.duplicate(true); changed_subject.subjects.relative = data.guardians[data.domain][2]; changed_subject.actors = [data.petitioner, changed_subject.subjects.relative]
	data.fixture.resolve_facts = [_reopen_fact(data, "prayer_situation", authorized, [auth, data.situation, data.fact_map.condition, data.fact_map.relation]), _reopen_fact(data, "prayer_situation", no_auth, [data.situation, data.fact_map.condition, data.fact_map.relation]), _reopen_fact(data, "prayer_situation", authorized, [auth, data.situation, data.fact_map.condition, data.fact_map.relation]), _reopen_fact(data, "prayer_situation", changed, [auth, data.situation, data.fact_map.condition, data.fact_map.relation]), _reopen_fact(data, "prayer_situation", changed_subject, [auth, data.situation, data.fact_map.condition, data.fact_map.relation])]
	assert(_submit(data, "resolve_event", {"event": "payment", "action": "ignore"}).ok and _submit(data, "finish_events").ok)
	data.fixture.resolve_facts = []; data.fixture.gather = []; data.fixture.cost = 0
	var sources: Array = _facts(data.world, "prayer_situation").filter(func(fact: Dictionary) -> bool: return fact.turn == 2)
	assert(sources.size() == 5 and _evolve(data) and _finish(data) and _open(data))
	var fixed: Array = data.world.state.simulation.candidates.values().filter(func(card: Dictionary) -> bool: return card.get("source") == sources[0].id)
	var legitimate: bool = fixed.size() == 1
	var request: String = fixed[0].id if legitimate else ""
	_check("PRY-REOPEN-001", "失败后上游有源复开仍固定原人物/原病危且下一轮才进入冻结名单", legitimate and fixed[0].actors == [data.petitioner, data.subjects.relative] and fixed[0].visible_turn == 4 and not request in data.world.state.prayer_system.offered and Store.entry(data.world.state.facts, data.fact_map.condition).changes.due == 7)
	var denied: bool = true
	for source: Dictionary in sources.slice(1):
		var result: Dictionary = data.prayers.validate_situation(data.world, source.id)
		denied = denied and not result.ok and data.world.state.simulation.candidates.values().all(func(card: Dictionary) -> bool: return card.get("source") != source.id)
	_check("PRY-REOPEN-002", "无授权重复、复用授权、换人或延长原危机均被真实固定入口拒绝", denied and Store.entry(data.world.state.applied_authorizations, "prayer/reopen/" + auth, "") == fixed[0].fact)
	assert(_evolve(data) and _finish(data) and _open(data))
	var frozen: Array = data.world.state.prayer_system.offered.duplicate()
	var preview: Dictionary = data.prayers.preview(data.turn, request, "shallow")
	_check("PRY-REOPEN-003", "复开在原可见轮冻结后可预览，固定主体和原危机期限不重抽", preview.ok and request in frozen and data.world.state.prayer_system.crises["CRISIS/" + data.fact_map.condition].due == 7 and frozen == data.world.state.prayer_system.offered)
	var recovered: Dictionary = _reopen_given()
	var path: String = scratch.path_join("reopen-" + str(Time.get_ticks_usec()))
	var restored: bool = data.turn.save_archive(path) and recovered.turn.load_archive(path) and recovered.turn.snapshot() == data.turn.snapshot()
	_check("PRY-REOPEN-004", "有源复开、唯一消费、冻结请求及原危机可分段归档后精确恢复", restored and recovered.world.validate_state(recovered.world.state).is_empty())
	assert(_evolve(data) and _finish(data))
	while data.world.state.turn < 7: assert(_round(data))
	var deaths: int = _facts(data.world, "status_change").filter(func(fact: Dictionary) -> bool: return fact.actor == data.subjects.relative and fact.changes.get("to") == "dead").size()
	var released: bool = not data.world.state.simulation.holds.has(data.subjects.relative)
	assert(_round(data))
	_check("PRY-REOPEN-005", "复开窗口结束仍等原危机due；原人只死亡一次并最终释放holds", deaths == 1 and released and Store.entry(data.world.state.npcs, data.subjects.relative).status == "dead" and _facts(data.world, "status_change").filter(func(fact: Dictionary) -> bool: return fact.actor == data.subjects.relative and fact.changes.get("to") == "dead").size() == deaths and data.world.validate_state(data.world.state).is_empty())
