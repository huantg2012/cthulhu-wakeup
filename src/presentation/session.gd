extends RefCounted
## Presentation owns no rule values. Every lasting input is a Turn request.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Economy = preload("res://src/game/economy.gd")
const Cults = preload("res://src/game/cults.gd")
const Relics = preload("res://src/game/relics.gd")
const Powers = preload("res://src/game/powers.gd")
const Prayers = preload("res://src/game/prayers.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Events = preload("res://src/game/events.gd")
const Resistance = preload("res://src/game/resistance.gd")
const Endings = preload("res://src/game/endings.gd")
const PlayerSources = preload("res://src/game/player_sources.gd")
const Actions = preload("res://src/presentation/action_catalog.gd")
const PlayerKnowledge = preload("res://src/game/player_knowledge.gd")
const Opportunities = preload("res://src/game/opportunity_service.gd")
const Eligibility = preload("res://src/game/opportunity_eligibility.gd")
const EntrySelectors = preload("res://src/game/entry_selectors.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const Progression = preload("res://src/game/progression_routes.gd")
const SAVE_SCHEMA: int = 2
const SAVE_DIRECTORY: String = "user://campaigns"
const LATEST: String = "user://campaigns/latest.json"
var catalog: RefCounted
var world: RefCounted
var turn: RefCounted
var modules: Dictionary = {}
var last_error: String = ""
var last_result: Dictionary = {}
var slot: String = ""
var _busy: bool = false
var _request_sequence: int = 0
var _known_domains: Dictionary = {}
var _known_people: Dictionary = {}
var _known_facts: Dictionary = {}
var _knowledge_cursor: int = 1
var _campaign: String = ""
var _action_inputs: Dictionary = {}
var _known_kinds: Dictionary = {}
var _known_relics: Dictionary = {}
var _domain_intelligence: Dictionary = {}
var _known_prayers: Dictionary = {}
var _known_events: Dictionary = {}
# Request identities are clues, never full world/person intelligence.
var _request_domains: Dictionary = {}
var _request_people: Dictionary = {}
var _request_objects: Dictionary = {}
var save_directory: String
var latest_path: String
var _identity_pattern: RegEx

func _init(directory: String = SAVE_DIRECTORY, latest: String = "") -> void:
	save_directory = directory
	latest_path = directory.path_join("latest.json") if latest.is_empty() else latest
	_identity_pattern = RegEx.new()
	_identity_pattern.compile("DOMAIN-[0-9]{3}/(?:interpretation|propagation|order)|RELIC/FACT-[0-9]{8}|ANCHOR/DOMAIN-[0-9]{3}/(?:interpretation|propagation|order)|CULT/DOMAIN-[0-9]{3}|FACT-[0-9]{8}|NPC-[0-9]{8}|DOMAIN-[0-9]{3}")

func explain_error(message: String) -> String:
	var translations: Dictionary = {
		"Progression preview requires actions": "请先处理轮初事件，进入行动阶段",
		"Progression operation is not affordable": "信仰或低语不足，无法进行本次行动",
		"A later turn is required": "本次行动需要等到下一回合，不能在同一回合继续",
		"Participant unavailable or already acted": "参加者当前无法行动，或本轮已经执行过任务",
		"Original student must personally perform on a later turn": "须由原学徒在教习后的回合亲自施行，并保留有效教习来源",
		"Select the original lesson as its student for independent performance": "教习已完成，请选择原学徒和原教习，独自施行祭仪",
		"Continue the fixed covenant rather than replace its terms": "两项交付约定已经固定，请按原条款继续履行",
		"Outstanding original reciprocal leg required": "需要尚未完成的原交付条款；两项均完成后不能再次履行",
		"Private devotion needs actual deity knowledge": "该人物尚未真正知晓邪神身份，不能进行当下私祷",
		"Private devotion needs current willingness": "该人物当前没有献身意愿，不能进行当下私祷",
		"No current capacity for this fixed request": "当前没有容纳这项固定祈求的名额",
		"Actual teacher and current cooperation required": "需要合格的原祭仪者，以及双方当前有效的支持或合作联系",
		"Original participants must continue their own operation": "须由原参加者继续原行动，不能替换参加者",
		"Respond to the existing fixed request before preparing another": "原请求仍有效，请先从祈求入口回应，不要重复准备",
		"Operator must know an actual current record": "执行者需要确知所选的当前有效记录",
		"Actual record keeper required": "需要实际具备记录者资格的人物",
		"Actual ritual keeper required": "需要实际具备祭仪者资格的人物",
		"Original member admission requirements unmet": "该人物尚未满足原成员准入条件",
		"Current two-way contact required": "双方机构当前需要有效的双向联系",
		"Current shared need required": "双方当前需要一项共同需求",
		"Two original distinct records in actual custody required": "双方须分别实际保管不同原根的记录，并来自不同机构",
		"Obligor must actually hold the preserved record": "承担保管义务的人物须实际持有所选记录",
		"Prayer preview requires the action phase": "请先处理轮初事件，进入行动阶段",
		"Power preview requires the action phase": "请先处理轮初事件，进入行动阶段",
		"Prayer response opportunity already spent": "本轮唯一的祈求回应已使用",
		"Request response window is closed": "这项祈求的回应窗口已关闭",
		"Request is not in this turn's frozen offers": "这项祈求已不在本轮展示中",
		"Prayer response is not affordable": "信仰或低语不足，无法回应",
		"Power is not affordable": "信仰或低语不足，无法施展",
		"Current awakening is below the power threshold": "当前苏醒尚未达到权能门槛",
		"Power needs a loyal bound member": "需要一位当前忠诚的已绑定成员",
		"Power needs its local active cult": "该时空需要一个活跃教团",
		"Power needs an actual current source": "缺少当前有效的真实来源",
		"Power subject unavailable or in another domain": "原人物已无法行动或已不在目标时空",
		"Person already executed this turn": "该人物本轮已执行过任务",
		"Power target is still cooling down": "该目标的权能冷却尚未结束",
		"Transfer needs a reachable receiving cult and existing escort": "需要可达的接收教团及现有随行信众",
		"Anchor organization, slot or pollution threshold unmet": "锚点所需信众、凝聚、序号或污染条件尚未满足",
		"Fixed ritual anchors, subject or awakening unavailable": "固定仪式锚点、护持者或苏醒条件尚未满足",
		"Ritual is not awaiting continuation": "当前仪式尚不需要续付",
		"No ongoing ritual": "当前没有进行中的降临仪式",
		"Event was already resolved": "此事件已处理",
		"Insufficient recovery faith": "信仰不足，无法回收媒介",
		"Recovery carrier already carries a relic": "该信徒已携带一件圣物",
		"Recovery needs a local cult inventory or actual member carrier": "需要本域教团库藏或可携带圣物的本域信徒",
		"Opportunity is closed or unknown": "原媒介机会已关闭或失效",
		"Institution recognition unavailable": "尚未取得该机构的正式承认",
		"Missing current dream qualification": "缺少仍有效的梦境或祈求联系",
		"Missing current listen qualification": "缺少指向具体未知事实的痕迹",
		"Missing current weakness qualification": "缺少仍有效的屏障弱点情报",
		"Missing current spread qualification": "缺少该教团的真实传播媒介",
		"Missing current evidence qualification": "缺少可销毁的传播证据",
		"Missing current tenure qualification": "缺少满足期限的真实入团经历",
		"Missing current witness qualification": "缺少该人物的独特见证",
		"Tenure needs a joined source": "需要该人物真实的当前入团记录",
		"Current cult tenure is too short or invalid": "该人物当前入团时间不足或资格已失效",
		"Lifetime bestowal or attribute unavailable": "该人物已获终生赐予，或所选属性已达上限",
		"Anchor guardian cannot join": "护持者尚不具备加入条件",
		"Appointment does not satisfy current cult eligibility": "人物、教团或岗位不符合当前任命条件",
		"Appointment is not affordable or unlocked": "任命所需信仰、低语或苏醒条件不足",
		"Material transfer requires the action phase": "请先处理轮初事件，进入行动阶段",
		"Material transfer is not affordable": "交予所需的信仰或低语不足",
		"stale_target": "接收者所属机构已变化，请重新选择",
		"already_held": "接收者已经持有所选记录或知识，无需再次交予",
		"invalid_material": "原记录已失效，请重新选择",
		"no_internal_contact": "双方目前没有可用的教团内联系",
		"unsupported_material": "此记录或对象不能通过此方式交予",
		"unavailable_material_participant": "发送者或接收者当前无法参与转交",
		"sender_lacks_material": "发送者尚未持有所选记录或准确知识",
		"nontransferable_qualification": "此项个人资格只能告知，不能交予他人持有",
		"invalid_material_request": "请选择有效的记录、发送者与接收者",
		"invalid_material_grant": "请选择本记录允许的取得方式"
	}
	if translations.has(message): return translations[message]
	if message.begins_with("Insufficient ") and message.ends_with(" capacity"): return "注意力容量不足，请查看已占用与预留"
	if message.to_lower().contains("afford") or message.to_lower().contains("insufficient faith"): return "当前资源不足"
	if message.to_lower().contains("source") or message.to_lower().contains("qualification"): return "所选真实来源、资格或原对象当前已失效"
	if message.to_lower().contains("unavailable") or message.to_lower().contains("unmet"): return "当前对象或必要条件尚未满足"
	if message.is_empty(): return "当前条件不允许执行"
	# Technical identities and implementation wording are diagnostic data only.
	for index: int in message.length():
		if message.unicode_at(index) > 127: return message
	return "当前对象、来源、资源或阶段不符合执行条件"

func _failure(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}

func _build(seed_value: int) -> Dictionary:
	var content: RefCounted = Catalog.new()
	if not content.load_files(): return {"ok": false, "error": "; ".join(content.errors)}
	var fresh: RefCounted = World.new(content)
	if not fresh.generate_hybrid(seed_value): return {"ok": false, "error": fresh.last_error}
	var clock: RefCounted = Turn.new(fresh)
	if not clock._attached: return {"ok": false, "error": clock.last_error}
	var issuers: Dictionary = Events.issuer_capability(content)
	issuers.merge(PlayerSources.issuer_capability(content))
	var services: Dictionary = {"economy": Economy.new(content, issuers), "cults": Cults.new(content), "relics": Relics.new(content, issuers), "powers": Powers.new(content, issuers), "prayers": Prayers.new(content, issuers), "anchors": Anchors.new(content, issuers), "events": Events.new(content), "resistance": Resistance.new(content), "endings": Endings.new(content), "player_sources": PlayerSources.new(content), "progression_routes": Progression.new(content)}
	for name: String in services:
		if not services[name].install(clock): return {"ok": false, "error": "无法安装正式能力：" + name}
	if not Opportunities.install(clock): return {"ok": false, "error": "无法安装直接行动服务"}
	var initial: Dictionary = clock.bootstrap_prayers()
	if not initial.get("ok", false): return {"ok": false, "error": str(initial.get("error", "初始求告不可用"))}
	return {"ok": true, "catalog": content, "world": fresh, "turn": clock, "modules": services}

func start_new(seed_value: int) -> Dictionary:
	if _busy: return _failure("正在结算")
	var built: Dictionary = _build(seed_value)
	if not built.ok: return _failure(built.error)
	# Prove the real first boundary before replacing an existing campaign.
	var opened: Dictionary = built.turn.submit({"id": "session/open/1", "turn": 0, "phase": "between", "op": "advance"})
	if not opened.ok: return _failure(opened.error)
	catalog = built.catalog; world = built.world; turn = built.turn; modules = built.modules
	_campaign = "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	slot = save_directory + "/" + _campaign + ".json"
	_request_sequence = 1; _knowledge_cursor = 1
	_known_domains = {}; _known_people = {}; _known_facts = {}; _known_kinds = {}; _known_relics = {}; _domain_intelligence = {}; _known_prayers = {}; _known_events = {}; _request_domains = {}; _request_people = {}; _request_objects = {}; _action_inputs = {}; last_result = opened.duplicate(true)
	_refresh_knowledge(false)
	var autosave: Dictionary = save_game()
	return {"ok": true, "phase": turn.context.phase, "turn": turn.context.turn, "slot": slot, "autosave": autosave}

func _submit(op: String, fields: Dictionary = {}, durable_id: String = "") -> Dictionary:
	if turn == null: return _failure("尚未开启一局")
	if _busy: return _failure("正在结算")
	_busy = true
	var request: Dictionary = fields.duplicate(true)
	request.merge({"id": durable_id if not durable_id.is_empty() else "session/" + _campaign + "/" + str(_request_sequence + 1), "op": op, "turn": turn.context.turn, "phase": turn.context.phase}, true)
	if not durable_id.is_empty() and Store.has(turn.context.receipts, durable_id):
		var previous: Dictionary = Store.entry(turn.context.receipts, durable_id).request
		var prior_fields: Dictionary = previous.duplicate(true)
		for key: String in ["id", "op", "turn", "phase"]: prior_fields.erase(key)
		if previous.op != op or prior_fields != fields:
			_busy = false
			return _failure("相同请求身份不能提交不同内容")
		var replayed: Dictionary = turn.submit(previous)
		_busy = false
		return _public(replayed)
	var first_fact: int = int(world.state.next_fact)
	var knowledge_roots: Dictionary = _command_knowledge_roots(request)
	var resources_before: Dictionary = {}
	for field: String in ["faith", "whispers", "awakening", "insight", "wounds"]: resources_before[field] = world.state[field]
	var result: Dictionary = turn.submit(request)
	if result.ok:
		_request_sequence += 1
		_refresh_knowledge(op in ["act", "resolve_event", "finish_events", "abandon", "attention", "rest"], first_fact, knowledge_roots)
		var changes: Dictionary = {}
		for field: String in resources_before:
			if resources_before[field] != world.state[field]: changes[field] = {"before": resources_before[field], "after": world.state[field], "delta": int(world.state[field]) - int(resources_before[field])}
		var facts: Array = []
		for number: int in range(first_fact, int(world.state.next_fact)):
			var source: String = "FACT-%08d" % number
			if _known_facts.has(source): facts.append(_public(Store.entry(world.state.facts, source)))
		result["changes"] = changes; result["facts"] = facts
		last_result = result.duplicate(true)
		if turn.context.phase in ["between", "ended"]:
			_busy = false
			var autosave: Dictionary = save_game()
			result["autosave"] = autosave
			_busy = true
	else:
		last_error = explain_error(str(result.get("error", "输入被拒绝")))
		result["error"] = last_error
	_busy = false
	return _public(result)

func progress(confirm_end: bool = false) -> Dictionary:
	if turn == null: return _failure("尚未开启一局")
	match str(turn.context.phase):
		"events": return _submit("finish_events")
		"actions":
			if not confirm_end: return {"ok": false, "confirmation": true, "error": "请确认轮末收入与供奉计划", "preview": economy_preview()}
			return _submit("end_actions")
		"between", "evolution", "settlement", "ending": return _submit("advance")
	return _failure("本局已封存，只可回顾或开启新局")

func set_plan(plan: Dictionary) -> Dictionary:
	var prepared: Dictionary = entry_eligibility("SESSION_SET_ECONOMY_PLAN", plan)
	return _submit(prepared.op, prepared.fields) if prepared.ok else _failure(explain_error(str(prepared.get("error", ""))))

func economy_preview() -> Dictionary:
	if turn == null: return _failure("尚未开启一局")
	var prepared: Dictionary = entry_eligibility("SESSION_SET_ECONOMY_PLAN", turn.context.plans.get("economy", {}))
	return prepared.preview if prepared.ok else prepared

func preview_plan(plan: Dictionary) -> Dictionary:
	var prepared: Dictionary = entry_eligibility("SESSION_SET_ECONOMY_PLAN", plan)
	return prepared.preview if prepared.ok else prepared

func abandon(confirmed: bool = false) -> Dictionary:
	return _submit("abandon") if confirmed else {"ok": false, "confirmation": true, "error": "自弃将立即封存本局"}

func rest(confirmed: bool = false) -> Dictionary:
	if turn == null: return _failure("尚未开启一局")
	var prepared: Dictionary = entry_eligibility("SESSION_REST")
	var preview: Dictionary = prepared.preview if prepared.ok else prepared
	if not preview.ok: return preview
	if not confirmed: return {"ok": false, "confirmation": true, "error": "敛息支付信仰并立即结束行动", "preview": preview}
	return _submit("rest")

func action_catalog(selection: Dictionary = {}) -> Array:
	return Actions.new().list_actions(self, selection) if turn != null else []

func preview_action(key: String, selection: Dictionary = {}) -> Dictionary:
	return Actions.new().preview(self, key, selection) if turn != null else _failure("尚未开启一局")

func execute_action(key: String, selection: Dictionary = {}, confirmed: bool = false, durable_id: String = "") -> Dictionary:
	if turn == null: return _failure("尚未开启一局")
	var signature: String = World.canonical({"key": key, "selection": selection})
	if not durable_id.is_empty() and _action_inputs.has(durable_id):
		var prior: Dictionary = _action_inputs[durable_id]
		if prior.signature != signature: return _failure("相同请求身份不能提交不同选择")
		var replayed: Dictionary = _submit(prior.op, prior.fields, durable_id)
		return _public(prior.get("response", replayed)) if replayed.ok else _public(replayed)
	var prepared: Dictionary = Actions.new().command(self, key, selection)
	if not prepared.ok: return _failure(prepared.get("error", "当前选择不可执行"))
	if prepared.get("irreversible", false) and not confirmed: return {"ok": false, "confirmation": true, "error": "此行动含不可逆代价，请确认", "preview": prepared.preview}
	var response: Dictionary = _submit(prepared.op, prepared.fields, durable_id)
	if response.ok and not durable_id.is_empty(): _action_inputs[durable_id] = {"signature": signature, "op": prepared.op, "fields": prepared.fields.duplicate(true), "response": response.duplicate(true)}
	return response

func known_domains() -> Array:
	var result: Array = _known_domains.keys(); result.sort(); return result

func focus_domains() -> Array:
	var identities: Dictionary = _known_domains.duplicate()
	identities.merge(_request_domains)
	var result: Array = identities.keys(); result.sort(); return result

func known_people() -> Array:
	var result: Array = _known_people.keys(); result.sort(); return result

func current_people() -> Array:
	var result: Array = world.history.ids("living").filter(func(id: String) -> bool: return _known_people.has(id))
	result.sort(); return result

func known_sources() -> Array:
	var result: Array = _known_facts.keys(); result.sort(); return result

func is_known_source(id: String) -> bool:
	return _known_facts.has(id)

func sources_of_kind(kind: String) -> Array:
	var result: Array = _known_kinds.get(kind, {}).keys(); result.sort(); return result

func known_relics() -> Array:
	var result: Array = world.history.ids("relics").filter(func(id: String) -> bool: return _known_relics.has(id))
	result.sort(); return result

func prayer_entry(id: String) -> Dictionary:
	var current: Dictionary = Store.entry(world.state.prayer_system.requests, id, {})
	if not current.is_empty(): return current
	if not _known_prayers.has(id): return {}
	var remembered: Dictionary = _known_prayers[id].duplicate(true)
	remembered["status"] = "closed"
	remembered["reason"] = "原请求已关闭；人物、处境与原期限保留在历史中"
	return remembered

func event_entry(id: String) -> Dictionary:
	var current: Dictionary = Store.entry(world.state.event_system.cards, id, {})
	if not current.is_empty(): return current
	if not _known_events.has(id): return {}
	return _known_events[id].duplicate(true)

func current_sources() -> Array:
	if turn == null: return []
	var view: Dictionary = turn._read_view("economy", turn.context.phase)
	var context: Dictionary = EntrySelectors.context(view, knowledge_snapshot(), modules)
	var result: Array = EntrySelectors._current_sources(context)
	view.reader.close()
	return result

func _internal_fact(kind: String) -> bool:
	return PlayerKnowledge._internal_fact(kind)

func _learn(source: String, _restoring: bool = false) -> void:
	# Compatibility for presentation readers: authority is updated only by Turn.
	_refresh_knowledge(false)

func request_subjects(descriptor: Dictionary, card: Dictionary = {}) -> Dictionary:
	return PlayerKnowledge.request_subjects(descriptor, card)



func _command_knowledge_roots(request: Dictionary) -> Dictionary:
	return PlayerKnowledge.command_roots(world.state, turn.context, knowledge_snapshot(), catalog, world.history, request)

func _refresh_knowledge(own_action: bool, first_fact: int = -1, roots: Dictionary = {}) -> void:
	_adopt_knowledge(knowledge_snapshot())


func prayer_title(descriptor: Dictionary, card: Dictionary = {}) -> String:
	var content: String = str(descriptor.get("content_id", card.get("content_id", "")))
	if content == "PRAYER_08":
		var mode: Dictionary = catalog.tables.prayer_addressing_modes.get(str(descriptor.get("addressing", "undirected")), {})
		return str(mode.get("devotion_title", catalog.tables.prayers[content].title))
	return str(catalog.tables.prayers.get(content, {}).get("title", "祈求"))

func _prayer_projection(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ["id", "content_id", "domain", "visible_turn", "due_turn", "status", "addressing"]:
		if value.has(field): result[field] = _public(value[field])
	var subjects: Dictionary = request_subjects(value)
	if not subjects.is_empty(): result["subjects"] = _public(subjects)
	if value.get("crisis") is Dictionary and value.crisis.has("due"): result["crisis"] = {"due": value.crisis.due}
	return result

func _public(value: Variant) -> Variant:
	if value is Dictionary:
		if _internal_fact(str(value.get("kind", ""))): return {}
		# Endings forecasts future contacts to determine disconnection. Those
		# internal candidates are not a player disclosure before visibility.
		if value.get("kind") == "ending_assessed":
			var visible: Dictionary = {}
			for field: String in ["id", "turn", "kind"]:
				if value.has(field): visible[field] = value[field]
			visible["changes"] = {}
			for field: String in ["before", "count", "awakening"]:
				if value.get("changes", {}).has(field): visible.changes[field] = value.changes[field]
			visible["causal_parents"] = value.get("causal_parents", []).filter(func(id: String) -> bool: return _known_facts.has(id))
			return visible
		if str(value.get("content_id", "")).begins_with("PRAYER_"): return _prayer_projection(value)
		var result: Dictionary = {}
		for key: String in value:
			if key in ["issuer", "version", "schema", "proof", "proofs", "token", "attention_token", "policy", "sample_before", "sample_after", "proposal_hash", "snapshot_version", "holds", "fallback_ids", "call", "knowledge", "record_knowledge", "admission_token", "recognition", "snapshot", "occurrence", "identity", "intent_rule"]: continue
			if _public_string(key) != key: continue
			result[key] = _public(value[key])
		if value.get("kind") in ["prayer_fixed", "background_fixed", "prayer_registered", "prayer_attempt"]:
			var context: Dictionary = value.get("changes", {}).get("descriptor", value.get("changes", {}).get("candidate", {}))
			if str(context.get("content_id", "")).begins_with("PRAYER_"):
				var petitioner: String = str(context.get("subjects", {}).get("petitioner", ""))
				result["actor"] = _public_string(petitioner)
				result["targets"] = [_public_string(petitioner)] if not petitioner.is_empty() else []
		return result
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _public(item))
	if value is String: return _public_string(value)
	return value

func _identity_known(id: String) -> bool:
	if id.begins_with("RELIC/"): return _known_relics.has(id) or _request_objects.has(id)
	if id.begins_with("ANCHOR/"):
		var anchor: Dictionary = world.state.anchors.get(id, {})
		return not anchor.is_empty() and (_known_facts.has(anchor.get("established_source", "")) or _known_people.has(anchor.guardian))
	if id.begins_with("CULT/"):
		var cult: Dictionary = world.state.cults.get(id, {})
		return not cult.is_empty() and (_known_facts.has(cult.established_source) or _known_people.has(cult.leader))
	if id.begins_with("FACT-"): return _known_facts.has(id)
	if id.begins_with("NPC-"): return _known_people.has(id) or _request_people.has(id)
	if world.state.institutions.has(id): return _known_domains.has(world.state.institutions[id].domain) or _request_objects.has(id)
	if id.begins_with("DOMAIN-"): return _known_domains.has(id) or _request_domains.has(id)
	return true

func _public_string(value: String) -> String:
	var result: String = value
	for token: String in world.state.attention.reservations:
		if world.state.attention.reservations[token].get("owner") == "prayers": result = result.replace(token, "尚未知晓")
	for found: RegExMatch in _identity_pattern.search_all(value):
		var id: String = found.get_string()
		if not _identity_known(id): result = result.replace(id, "尚未知晓")
	return result

func object_title(id: String) -> String:
	if _request_objects.has(id) and not _known_relics.has(id) and not (world.state.institutions.has(id) and _known_domains.has(world.state.institutions[id].domain)):
		return ("请求所指媒介 · " if _request_objects[id].kind == "relic" else "请求所指机构 · ") + id
	if _request_people.has(id) and not _known_people.has(id): return "请求所涉人物 · " + id.trim_prefix("NPC-")
	if _request_domains.has(id) and not _known_domains.has(id): return "请求所指时空 · " + id.trim_prefix("DOMAIN-")
	if _known_people.has(id):
		var person: Dictionary = Store.entry(world.state.npcs, id)
		return catalog.tables.npc_profiles[person.profile].name + " · " + id.trim_prefix("NPC-")
	if _known_domains.has(id): return catalog.tables.civilization_profiles[world.state.domains[id].profile].name + " · " + id.trim_prefix("DOMAIN-")
	if _known_relics.has(id):
		var relic: Dictionary = Store.entry(world.state.relics, id)
		return str(catalog.tables.relics.get(relic.type, {}).get("name", "圣物")) + " · " + id.trim_prefix("RELIC/FACT-")
	if _known_facts.has(id):
		var fact: Dictionary = Store.entry(world.state.facts, id)
		var content: String = str(fact.changes.get("content_id", fact.changes.get("prayer", "")))
		for field: String in ["candidate", "descriptor"]:
			var nested: Variant = fact.changes.get(field, {})
			if content.is_empty() and nested is Dictionary: content = str(nested.get("content_id", ""))
		if catalog.tables.prayers.has(content): return catalog.tables.prayers[content].title + " · 第 %d 轮" % int(fact.turn)
		if catalog.tables.events.has(content): return catalog.tables.events[content].title + " · 第 %d 轮" % int(fact.turn)
		return "已知事实 · " + id.trim_prefix("FACT-")
	if world.state.institutions.has(id) and _known_domains.has(world.state.institutions[id].domain):
		var institution: Dictionary = world.state.institutions[id]
		return {"interpretation": "解释机构", "propagation": "传播机构", "order": "秩序机构"}.get(str(institution.role), "机构") + " · " + object_title(institution.domain)
	return _public_string(id)

func project() -> Dictionary:
	if turn == null: return {"ok": false, "active": false, "error": last_error}
	var state: Dictionary = world.state
	var domains: Array = []; var institutions: Array = []; var people: Array = []; var relics: Array = []; var cults: Array = []; var anchors: Array = []
	for id: String in known_domains():
		var domain: Dictionary = state.domains[id]
		var intelligence: Dictionary = _domain_intelligence.get(id, {})
		domains.append({"id": id, "title": catalog.tables.civilization_profiles[domain.profile].name + " · " + id.trim_prefix("DOMAIN-"), "profile": domain.profile, "tier": domain.tier, "focused": id in state.simulation.focused, "barrier": intelligence.get("barrier", {}).get("value"), "pollution": null, "alert": null, "stability": null, "metric_sources": intelligence.duplicate(true), "neighbors": domain.neighbors.filter(func(other: String) -> bool: return _known_domains.has(other)), "institutions": domain.institutions.duplicate()})
		for institution_id: String in domain.institutions:
			var institution: Dictionary = state.institutions[institution_id]
			institutions.append({"id": institution_id, "title": {"interpretation": "解释机构", "propagation": "传播机构", "order": "秩序机构"}.get(str(institution.role), "机构"), "domain": id, "role": institution.role, "active": institution.active, "representative": institution.representative if _known_people.has(institution.representative) else null})
	for id: String in _request_domains:
		if not _known_domains.has(id): domains.append({"id": id, "title": object_title(id), "已知范围": "仅本次请求线索"})
	for id: String in _request_people:
		if not _known_people.has(id): people.append({"id": id, "title": object_title(id), "domain": _request_people[id], "已知范围": "仅本次请求线索"})
	for id: String in _request_objects:
		var cue: Dictionary = _request_objects[id]
		if cue.kind == "relic" and not _known_relics.has(id): relics.append({"id": id, "title": object_title(id), "domain": cue.domain, "已知范围": "仅本次请求线索"})
		elif cue.kind == "institution" and not _known_domains.has(cue.domain): institutions.append({"id": id, "title": object_title(id), "domain": cue.domain, "已知范围": "仅本次请求线索"})
	for id: String in known_people():
		var person: Dictionary = Store.entry(state.npcs, id, {})
		if person.is_empty(): continue
		var row: Dictionary = {}
		for field: String in ["id", "name", "domain", "status", "profile", "institution", "bound_member", "cult_id"]:
			if person.has(field): row[field] = person[field]
		if person.get("bound_member", false):
			for field: String in ["will", "insight", "influence", "adaptation", "loyalty", "sanity", "acted_turn"]: row[field] = person[field]
		row["title"] = str(person.get("name", catalog.tables.npc_profiles[person.profile].name + " · " + id.trim_prefix("NPC-"))); people.append(row)
	for id: String in known_relics():
		var item: Dictionary = Store.entry(state.relics, id)
		relics.append(item.duplicate(true))
	for cult: Dictionary in state.cults.values():
		if _known_facts.has(cult.established_source) or _known_people.has(cult.leader): cults.append(cult.duplicate(true))
	for anchor: Dictionary in state.anchors.values():
		if _known_facts.has(anchor.get("established_source", "")) or _known_people.has(anchor.guardian): anchors.append(anchor.duplicate(true))
	var prayers: Array = []
	for id: String in state.prayer_system.offered:
		var request: Dictionary = prayer_entry(id)
		prayers.append({"id": id, "key": "prayer/" + id, "title": prayer_title(request.descriptor, request.card), "card": _public(request.card), "descriptor": _public(request.get("descriptor", {})), "status": request.status})
	var events: Array = []
	for row: Dictionary in turn.context.events:
		var event: Dictionary = event_entry(row.id)
		var content: String = str(event.get("descriptor", {}).get("content_id", ""))
		events.append({"id": row.id, "key": "event/" + row.id, "title": catalog.tables.events[content].title if catalog.tables.events.has(content) else row.id, "resolved": row.resolved, "descriptor": _public(event.get("descriptor", {}))})
	var attention: Dictionary = {}
	for budget: String in ["focus", "people", "members", "identities"]: attention[budget] = world.attention.occupied(state, budget).size()
	attention["limits"] = {"focus": int(world.attention.parameters.focused_domain_limit), "members": int(world.attention.parameters.bound_member_limit), "people": int(world.attention.parameters.temporary_actor_limit), "identities": catalog.integer("living_named_global_limit")}
	attention["reservations"] = _public(state.attention.reservations)
	var awakening_sources: Array = [{"kind": "initial", "title": "初始", "value": catalog.integer("initial_awakening")}, {"kind": "insight", "title": "洞见", "value": state.insight}, {"kind": "wounds", "title": "创伤", "value": -int(state.wounds)}]
	for anchor: Dictionary in state.anchors.values():
		if anchor.state == "active": awakening_sources.append({"kind": "anchor", "title": anchor.id, "value": catalog.integer("anchor_" + str(state.domains[anchor.domain].tier) + "_contribution")})
	var resistance: Array = []
	for plan: Dictionary in modules.resistance.preview(turn).get("plans", []):
		if _known_domains.has(plan.domain): resistance.append(_public(plan))
	return {"ok": true, "active": true, "turn": turn.context.turn, "phase": turn.context.phase, "phase_title": {"between": "轮间", "events": "轮初事件", "actions": "神意行动", "evolution": "共同演化", "settlement": "轮末结算", "ending": "终局检查", "ended": "本局封存"}.get(str(turn.context.phase), ""), "busy": _busy, "terminal": turn.context.phase == "ended", "outcome": turn.context.outcome, "awakening": state.awakening, "awakening_sources": awakening_sources, "faith": state.faith, "capacity": Economy.capacity(state, catalog), "whispers": state.whispers, "insight": state.insight, "wounds": state.wounds, "disconnected": state.ending_system.disconnected, "manifest": _public(state.power_system.manifest), "domains": domains, "institutions": institutions, "people": people, "relics": _public(relics), "cults": _public(cults), "anchors": _public(anchors), "prayers": prayers, "events": events, "resistance": resistance, "attention": attention, "last_result": _public(last_result), "economy_plan": _public(turn.context.plans.get("economy", {})), "summary_income": _public(economy_preview()), "slot": slot}

func history_page(cursor: int = 0, limit: int = 20) -> Dictionary:
	if turn == null or cursor < 0 or limit < 1 or limit > 100: return _failure("无效历史页")
	var ids: Array = known_sources()
	if cursor > ids.size(): return _failure("无效历史位置")
	var rows: Array = []; var end: int = mini(ids.size(), cursor + limit)
	for index: int in range(cursor, end):
		var fact: Dictionary = Store.entry(world.state.facts, ids[index]).duplicate(true)
		fact.causal_parents = fact.causal_parents.map(func(source: String) -> String: return source if _known_facts.has(source) else "尚未知晓")
		rows.append(_public(fact))
	return {"ok": true, "facts": rows, "cursor": end, "complete": end == ids.size(), "total": ids.size(), "seed": str(world.randoms.generation.seed)}

func save_game(path: String = "") -> Dictionary:
	if turn == null or _busy: return _failure("当前不能保存")
	var destination: String = slot if path.is_empty() else path
	var body: Dictionary = {"schema": SAVE_SCHEMA, "campaign": _campaign, "request_sequence": _request_sequence, "snapshot": turn.snapshot(), "action_inputs": _action_inputs, "material_version": catalog.material_transfer_version(), "eligibility_version": Eligibility.VERSION, "knowledge": {"domains": known_domains(), "people": known_people(), "facts": known_sources(), "cursor": _knowledge_cursor}}
	body["knowledge_version"] = PlayerKnowledge.VERSION
	body["opportunity_version"] = Opportunities.version(catalog)
	var saved: Dictionary = _atomic_write(destination, World.canonical({"body": body, "checksum": World.canonical(body).sha256_text()}))
	if not saved.ok: return saved
	slot = destination
	var pointer: Dictionary = _atomic_write(latest_path, World.canonical({"path": destination}))
	return {"ok": true, "path": destination, "latest": pointer.ok}

func saved_games() -> Array:
	var result: Array = []
	var directory: DirAccess = DirAccess.open(save_directory)
	if directory == null: return result
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var identity: PackedStringArray = name.get_basename().split("-")
		if not directory.current_is_dir() and name.ends_with(".json") and identity.size() == 2 and identity[0].is_valid_int() and identity[1].is_valid_int():
			result.append({"path":save_directory.path_join(name), "title":"存档 · " + Time.get_datetime_string_from_unix_time(identity[0].to_int()).replace("T", " ") + " UTC · " + identity[1].right(6)})
		name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.path > second.path)
	return result

func _atomic_write(path: String, text_value: String) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return _failure("无法创建存档目录")
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _failure("无法写入临时存档")
	file.store_string(text_value); file.flush()
	var error: Error = file.get_error(); file.close()
	if error != OK: return _failure("存档写入失败，原文件保留")
	var backup: String = absolute + ".bak"
	if FileAccess.file_exists(absolute):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK: return _failure("无法轮换存档备份")
		if DirAccess.rename_absolute(absolute, backup) != OK: return _failure("无法保留原存档")
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, absolute)
		return _failure("无法替换存档，原文件已保留")
	return {"ok": true}

func continue_game(path: String = "") -> Dictionary:
	if _busy: return _failure("正在结算")
	var source: String = path
	if source.is_empty():
		if not FileAccess.file_exists(latest_path): return _failure("没有可继续的存档")
		var pointer: Variant = JSON.parse_string(FileAccess.get_file_as_string(latest_path))
		if not pointer is Dictionary or not pointer.get("path") is String: return _failure("没有可继续的存档")
		source = pointer.path
	if not FileAccess.file_exists(source): return _failure("存档文件不存在")
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not envelope is Dictionary or not envelope.get("body") is Dictionary: return _failure("存档格式不正确")
	var body: Dictionary = World._normalize_numbers(envelope.body)
	if envelope.get("checksum") != World.canonical(body).sha256_text() or body.get("schema") != SAVE_SCHEMA or not body.get("snapshot") is String or not body.get("campaign") is String or not body.get("request_sequence") is int or not body.get("knowledge") is Dictionary: return _failure("存档校验失败")
	var built: Dictionary = _build(1)
	if not built.ok: return _failure(built.error)
	if not built.turn.restore(body.snapshot): return _failure(built.turn.last_error)
	if body.get("material_version") != built.catalog.material_transfer_version(): return _failure("存档材料规则版本不兼容")
	if body.get("eligibility_version") != Eligibility.VERSION: return _failure("存档知情与入口规则版本不兼容")
	if body.get("knowledge_version") != PlayerKnowledge.VERSION or body.get("opportunity_version") != Opportunities.version(built.catalog): return _failure("存档行动服务规则版本不兼容")
	if body.campaign.is_empty() or body.request_sequence != built.turn.commit_sequence: return _failure("存档请求序号与正式回执不一致")
	var knowledge: Dictionary = body.knowledge
	for field: String in ["domains", "people", "facts"]:
		if not knowledge.get(field) is Array: return _failure("存档知识格式不正确")
		for id: Variant in knowledge[field]:
			if not id is String: return _failure("存档知识身份不正确")
			var exists: bool = built.world.state.domains.has(id) if field == "domains" else Store.has(built.world.state.npcs if field == "people" else built.world.state.facts, id)
			if not exists: return _failure("存档知识引用已失效")
	if not knowledge.get("cursor") is int or knowledge.cursor != built.world.state.next_fact: return _failure("存档知识位置不正确")
	var authoritative: Dictionary = built.turn.context.player_knowledge
	for pair: Array in [["domains", "known_domains"], ["people", "known_people"], ["facts", "known_facts"]]:
		var expected: Array = authoritative[pair[1]].keys(); expected.sort()
		if knowledge[pair[0]] != expected: return _failure("存档知识与正式账本不一致")
	if knowledge.cursor != authoritative.cursor: return _failure("存档知识位置与正式账本不一致")
	if not body.get("action_inputs", {}) is Dictionary: return _failure("存档输入凭据不正确")
	for id: String in body.get("action_inputs", {}):
		if not body.action_inputs[id] is Dictionary: return _failure("存档输入凭据格式不正确")
		var input: Dictionary = body.action_inputs[id]
		if not Store.has(built.turn.context.receipts, id) or not input.get("signature") is String or not input.get("fields") is Dictionary: return _failure("存档输入凭据缺少正式回执")
		var receipt: Dictionary = Store.entry(built.turn.context.receipts, id).request
		var fields: Dictionary = receipt.duplicate(true)
		for key: String in ["id", "op", "turn", "phase"]: fields.erase(key)
		if receipt.op != input.get("op") or fields != input.fields: return _failure("存档输入凭据内容不一致")
	catalog = built.catalog; world = built.world; turn = built.turn; modules = built.modules
	_campaign = body.campaign; _request_sequence = body.request_sequence; _knowledge_cursor = knowledge.cursor; slot = source
	_action_inputs = body.get("action_inputs", {}).duplicate(true)
	_rebuild_knowledge(knowledge)
	last_result = {}; last_error = ""
	return {"ok": true, "path": source, "turn": turn.context.turn, "phase": turn.context.phase}

func _rebuild_knowledge(knowledge: Dictionary) -> void:
	_adopt_knowledge(knowledge_snapshot())


func anchor_source_options(institution: String) -> Array:
	if turn == null: return []
	var view: Dictionary = turn._read_view("economy", turn.context.phase)
	var context: Dictionary = EntrySelectors.context(view, knowledge_snapshot(), modules)
	var result: Array = EntrySelectors._anchor_sources(context, institution)
	view.reader.close()
	return result

func material_transfer_options() -> Array:
	if turn == null: return []
	var view: Dictionary = turn._read_view("economy", turn.context.phase)
	var context: Dictionary = EntrySelectors.context(view, knowledge_snapshot(), modules)
	var result: Array = EntrySelectors.transfer_options(context)
	view.reader.close()
	return result

func knowledge_snapshot() -> Dictionary:
	return turn.context.player_knowledge.duplicate(true) if turn != null else PlayerKnowledge.empty_ledger()

func _adopt_knowledge(ledger: Dictionary) -> void:
	_knowledge_cursor = int(ledger.cursor)
	_known_domains = ledger.known_domains
	_known_people = ledger.known_people
	_known_facts = ledger.known_facts
	_known_kinds = ledger.known_kinds
	_known_relics = ledger.known_relics
	_domain_intelligence = ledger.domain_intelligence
	_known_prayers = ledger.known_prayers
	_known_events = ledger.known_events
	_request_domains = ledger.request_domains
	_request_people = ledger.request_people
	_request_objects = ledger.request_objects

func entry_eligibility(entry: String, selection: Dictionary = {}) -> Dictionary:
	if turn == null: return {"ok": false, "error": "尚未开启一局"}
	var participant: String = Eligibility.participant(entry)
	if not modules.has(participant): return {"ok": false, "error": "当前没有此行动"}
	var view: Dictionary = turn._read_view(participant, turn.context.phase)
	var result: Dictionary = Eligibility.query(view, knowledge_snapshot(), modules, entry, selection)
	view.reader.close()
	return result
