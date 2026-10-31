extends RefCounted
## Finite selectors translate known identities into production-rule inputs.
## Eligibility and payment are queried from the original module, never rebuilt.
const Store = preload("res://src/simulation/archive_store.gd")
const Eligibility = preload("res://src/game/opportunity_eligibility.gd")
const Selectors = preload("res://src/game/entry_selectors.gd")

func _selected(selection: Dictionary, key: String, options: Array) -> Variant:
	return Selectors._selected(selection, key, options)

func _row(session: RefCounted, key: String, title: String, fields: Array, selection: Dictionary, details: Dictionary = {}) -> Dictionary:
	var view: Dictionary = session.turn._read_view(Eligibility.participant(key), session.turn.context.phase)
	var resolved: Dictionary = Eligibility.fields(view, session.knowledge_snapshot(), session.modules, key, selection, session.object_title)
	view.reader.close()
	fields = resolved.get("fields", [])
	var row: Dictionary = {"key": key, "title": title, "fields": fields, "details": session._public(details)}
	var prepared: Dictionary = _prepare(session, key, selection, fields)
	row["preview"] = _player_preview(session, prepared)
	row["available"] = row.preview.ok
	if key == "route/context":
		row.details = _route_details(session, selection, fields)
		row.preview["当前进展"] = row.details.duplicate(true)
	return row

func _player_preview(session: RefCounted, prepared: Dictionary) -> Dictionary:
	if not prepared.get("ok", false): return session._public(prepared)
	return {"ok": true, "preview": session._public(prepared.get("preview", {})), "irreversible": prepared.get("irreversible", false)}

func _context(session: RefCounted, descriptor: Dictionary, card: Dictionary) -> Dictionary:
	var content: String = str(descriptor.get("content_id", card.get("content_id", "")))
	var details: Dictionary = {}
	var prayer: Dictionary = session.catalog.tables.prayers.get(content, {})
	if not prayer.is_empty():
		details["当前诉求"] = session.prayer_title(descriptor, card)
		details["求告方向"] = "定向" if descriptor.get("addressing", "undirected") == "directed" else "无向"
		var petitioner: String = str(descriptor.get("subjects", {}).get("petitioner", ""))
		if not petitioner.is_empty(): details["祈求人"] = session.object_title(petitioner)
		var roles: Dictionary = {"relative": "濒死亲属", "rival": "对手", "pursuer": "追查者", "second": "第二见证者", "counterparty": "契约另一方", "memory_people": "记忆持有人", "opponent": "争端另一方", "relic": "原圣物", "other_institution": "关联机构"}
		for role: String in session.request_subjects(descriptor, card):
			if role == "petitioner": continue
			var subject: Variant = descriptor.subjects[role]
			details[roles[role]] = subject.map(func(id: Variant) -> String: return session.object_title(str(id))) if subject is Array else session.object_title(str(subject))
		details["所在时空"] = session.object_title(str(descriptor.get("domain", card.get("domain", ""))))
		if content == "PRAYER_08": details["本次求告"] = session.catalog.tables.prayer_addressing_modes[str(descriptor.get("addressing", "undirected"))].devotion_text
		if card.has("due_turn"): details["请求期限"] = "第 %d 轮" % int(card.due_turn)
		if descriptor.get("crisis", {}).has("due"): details["原危机期限"] = "第 %d 轮" % int(descriptor.crisis.due)
		return session._public(details)
	details["当前处境"] = session.catalog.tables.events.get(content, {}).get("title", "已固定的事件")
	if descriptor.get("prayer_descriptor") is Dictionary:
		var original: Dictionary = _context(session, descriptor.prayer_descriptor, card)
		details.merge(original)
		if content != "EVENT_09": return session._public(details)
	var roles: Dictionary = {"petitioner": "祈求人", "relative": "濒死亲属", "rival": "对手", "opponent": "争端另一方", "pursuer": "追查者", "second": "第二见证者", "counterparty": "契约另一方", "memory_people": "记忆持有人", "relic": "原圣物", "other_institution": "关联机构", "survivor": "幸存者", "witnesses": "见证者", "priest": "原祭司", "obligor": "契约承担者", "successor": "继任者", "cooperator": "合作者", "cooperating_institution": "合作机构", "recipient": "接收者", "target_institution": "接收机构", "grant": "取得方式"}
	for field: String in descriptor.get("subjects", {}):
		var subject: Variant = descriptor.subjects[field]
		if subject is String: subject = session.object_title(subject)
		elif subject is Array: subject = subject.map(func(id: Variant) -> String: return session.object_title(str(id)))
		details[roles.get(field, "关联对象 · " + field)] = subject
	if content == "EVENT_09" and descriptor.facts.has("material"):
		details["交予记录"] = session.object_title(str(descriptor.facts.material))
		details["取得方式"] = "保管与知情" if descriptor.subjects.get("grant") == "custody" else "知情"
	if descriptor.has("institution"): details["所在机构"] = session.object_title(str(descriptor.institution))
	if descriptor.has("domain"): details["所在时空"] = session.object_title(str(descriptor.domain))
	var due: Variant = card.get("due_turn", descriptor.get("due_turn"))
	if due != null: details["请求期限" if not prayer.is_empty() else "事件期限"] = "第 %d 轮" % int(due)
	var crisis: Dictionary = descriptor.get("crisis", descriptor.get("prayer_descriptor", {}).get("crisis", {}))
	if crisis.is_empty():
		var candidates: Array = [str(descriptor.get("source", ""))]
		for value: Variant in descriptor.get("facts", {}).values():
			if value is String: candidates.append(value)
			elif value is Array: candidates.append_array(value)
		for id: Variant in candidates:
			if not id is String or not session.is_known_source(id): continue
			var original: Dictionary = Store.entry(session.world.state.facts, id)
			if original.kind in ["prayer_registered", "prayer_attempt"]:
				var original_crisis: Dictionary = original.changes.get("descriptor", {}).get("crisis", {})
				if not original_crisis.is_empty(): crisis = original_crisis; break
			if original.kind in ["dying_condition", "pursuit_condition", "contract_obligation", "memory_at_risk", "faction_conflict"] and original.changes.has("due"):
				crisis = {"due": original.changes.due}; break
	if crisis.has("due"): details["原危机期限"] = "第 %d 轮" % int(crisis.due)
	if descriptor.has("source"): details["实际来源"] = descriptor.source
	return session._public(details)

func _manifest_context(session: RefCounted) -> Dictionary:
	var manifest: Dictionary = session.world.state.power_system.manifest
	if manifest.is_empty(): return {}
	return session._public({"固定仪式主体": session.object_title(manifest.npc), "固定宇宙锚点": manifest.cosmic_anchor, "固定星系锚点": manifest.system_anchor, "已付仪式轮次": manifest.progress, "最近实付回合": manifest.paid_turn, "持续规则": session.catalog.tables.powers.POWER_MANIFEST.notes})

func list_actions(session: RefCounted, selection: Dictionary = {}) -> Array:
	var rows: Array = []
	if session.turn.context.phase == "ended": return rows
	if session.turn.context.phase == "events":
		for event: Dictionary in session.turn.context.events:
			if event.resolved: continue
			var entry: Dictionary = session.event_entry(event.id)
			var descriptor: Dictionary = entry.descriptor
			for option: String in session.modules.events.Rules.active_choices(session.catalog, descriptor.content_id):
				var effect: Dictionary = session.catalog.tables.event_effects[descriptor.content_id + "/" + option]
				var details: Dictionary = _context(session, descriptor, entry.card)
				details.merge({"选择后果": effect.on_choose, "不可逆代价": effect.irreversible_cost, "信仰费用": int(effect.faith_cost)})
				rows.append(_row(session, "event/" + event.id + "/" + option, session.catalog.tables.events[descriptor.content_id].title + " · " + option, [], selection, details))
		return rows
	if session.turn.context.phase != "actions": return rows
	if session.modules.has("progression_routes"):
		rows.append(_row(session, "route/context", "促成当前进展", [], selection, {"行动": "选择当前人物可促成的组织、实践或约定。准备完成的记忆与保管约定从原祈求回应。"}))
	for id: String in session.world.state.prayer_system.offered:
		var request: Dictionary = session.prayer_entry(id)
		var content: String = request.card.content_id
		for variant: String in ["shallow", "deep"]:
			var prayer: Dictionary = session.catalog.tables.prayers[content]
			var details: Dictionary = _context(session, request.descriptor, request.card)
			details.merge({"回应所得": prayer[variant + "_gain"], "始终代价": prayer[variant + "_cost"]})
			rows.append(_row(session, "prayer/" + id + "/" + variant, session.prayer_title(request.descriptor, request.card) + (" · 浅触" if variant == "shallow" else " · 深应"), [], selection, details))
	for power: Dictionary in session.catalog.tables.powers.values(): rows.append(_row(session, power.id, power.name, [], selection, {"requirement": power.target_requirement, "always": power.always_cost, "success": power.success, "deep": power.deep_success, "failure": power.failure, "disaster": power.disaster}))
	if not session.world.state.power_system.manifest.is_empty():
		for id: String in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]: rows.append(_row(session, id, "继续降临" if id.ends_with("CONTINUE") else "中止降临", [], selection, _manifest_context(session)))
	for action: String in ["equip", "unequip", "unbind", "recover", "disassemble"]:
		rows.append(_row(session, "relic/" + action, {"equip": "携带圣物", "unequip": "卸下圣物", "unbind": "解除媒介绑定", "recover": "回收圣物", "disassemble": "分解圣物"}[action], [], selection))
	for source: String in session.world.state.anchor_system.opportunities.values():
		if not session.is_known_source(source): continue
		var fact: Dictionary = Store.entry(session.world.state.facts, source)
		for option: String in ["recover", "public", "wait"]:
			rows.append(_row(session, "opportunity/" + source + "/" + option, {"recover": "回收机构媒介", "public": "公开机构媒介", "wait": "等待"}[option], [], selection))
	var transfers: Array = session.material_transfer_options()
	if not transfers.is_empty(): rows.append(_row(session, "cults/transfer_material", "交予记录", [], selection, {"取得内容": "取得指定记录副本或准确知识；不增加见证、实践或契约责任。"}))
	for kind: String in ["focus", "release_focus", "enroll", "leave", "release_project"]:
		rows.append(_row(session, "attention/" + kind, {"focus": "关注时空", "release_focus": "下轮释放关注", "enroll": "接纳成员", "leave": "确认离团", "release_project": "释放未用预留"}[kind], [], selection))
	return rows

func _fields_for(session: RefCounted, key: String, selection: Dictionary) -> Array:
	var view: Dictionary = session.turn._read_view(Eligibility.participant(key), session.turn.context.phase)
	var resolved: Dictionary = Eligibility.fields(view, session.knowledge_snapshot(), session.modules, key, selection, session.object_title)
	view.reader.close()
	return resolved.get("fields", [])

func preview(session: RefCounted, key: String, selection: Dictionary = {}) -> Dictionary:
	var result: Dictionary = _player_preview(session, _prepare(session, key, selection, []))
	if key == "route/context": result["当前进展"] = _route_details(session, selection, _fields_for(session, key, selection))
	return result

func command(session: RefCounted, key: String, selection: Dictionary = {}) -> Dictionary:
	return _prepare(session, key, selection, [])

func _prepare(session: RefCounted, key: String, selection: Dictionary, _fields: Array) -> Dictionary:
	var prepared: Dictionary = session.entry_eligibility(key, selection)
	if not prepared.get("ok", false): return {"ok": false, "error": session.explain_error(str(prepared.get("error", "当前对象、来源或资源不符合条件")))}
	# A public preview includes only what the player must decide. Raw plans and
	# qualification internals remain in the rule layer.
	var plan: Dictionary = prepared.preview
	var visible: Dictionary = {}
	for field: String in ["faith", "whispers", "faith_cost", "probability", "net_gain", "awakening_loss", "consumes", "needs"]:
		if plan.has(field): visible[field] = plan[field].duplicate(true) if plan[field] is Dictionary or plan[field] is Array else plan[field]
	if visible.has("probability") and int(visible.probability) >= 0:
		var outcomes: Dictionary = {"deep": 0, "success": 0, "failure": 0, "disaster": 0}
		for roll: int in range(1, 101): outcomes[session.world.check_result(int(visible.probability), roll)] += 1
		visible["outcomes"] = outcomes
	if visible.has("needs"):
		visible.needs = {"budgets": visible.needs.get("budgets", {})}
	return {"ok": true, "op": prepared.op, "fields": prepared.fields, "preview": visible, "irreversible": prepared.irreversible}

func _route_details(session: RefCounted, selection: Dictionary, fields: Array) -> Dictionary:
	var chosen: Dictionary = {}; var action: String = "选择当前人物可促成的组织、实践或约定。"
	for field: Dictionary in fields:
		var value: Variant = selection.get(field.key, [] if field.multiple else _selected(selection, field.key, field.options))
		var values: Array = value if value is Array else [value]
		if values.all(func(item: Variant) -> bool: return field.options.any(func(option: Dictionary) -> bool: return option.id == item)):
			chosen[field.key] = value
			if field.key == "operation":
				for option: Dictionary in field.options:
					if option.id == value: action = option.label
	var details: Dictionary = {"行动": action}
	var npc: String = str(chosen.get("npc", "")); var operation: String = str(chosen.get("operation", ""))
	if npc.is_empty() or operation.is_empty(): return details
	var row: Dictionary = session.catalog.tables.progression_route_operations.get(operation, {})
	if row.is_empty(): return details
	var people: Array = [npc]
	people.append_array(chosen.get("participants", []))
	if not str(chosen.get("other", "")).is_empty(): people.append(chosen.other)
	var entry: Dictionary = {}
	var target: String = str(chosen.get("target", ""))
	var person: Dictionary = Store.entry(session.world.state.npcs, npc, {})
	var current_key: String = operation + "/" + "/".join(PackedStringArray(people)) + "/" + str(person.get("institution", ""))
	for key: String in session.world.state.progression_routes.progress:
		var candidate: Dictionary = session.world.state.progression_routes.progress[key]
		if candidate.operation != operation: continue
		if key == target and candidate.has("lesson") and session.is_known_source(candidate.lesson):
			var lesson: Dictionary = Store.entry(session.world.state.facts, candidate.lesson)
			if lesson.changes.data.get("student") == npc: entry = candidate; break
		elif key == current_key and candidate.npc == npc and candidate.people == people: entry = candidate; break
	var participants: Array = entry.get("people", people)
	details["当前参加者"] = participants.map(func(id: String) -> String: return session.object_title(id) if session._identity_known(id) else "尚未知晓的参加者")
	var record: String = str(entry.get("record", chosen.get("record", "")))
	if not record.is_empty(): details["原记录"] = session.object_title(record) if session.is_known_source(record) else "尚未知晓的记录"
	var required: int = int(row.repeat_turns) if not str(row.repeat_turns).is_empty() else 0
	if row.mode == "calendar_rite": required = session.catalog.integer("ritual_required_turns")
	if required > 0 and not row.mode in ["ritual_transmission", "reciprocal_covenant"]:
		details["成功回合"] = entry.get("uses", []).size()
		details["所需成功回合"] = required
		details["继续条件"] = "原参加者在不同回合实际成功"
	if row.mode == "ritual_transmission":
		details["教习"] = "已传授" if entry.has("lesson") else "尚未传授"
		details["学徒施行"] = "已完成" if entry.get("completed", false) else "由原学徒在教习后的回合独自施行"
	if row.mode == "reciprocal_covenant":
		var legs: Array = entry.get("legs", [])
		details["已完成交付"] = legs.size(); details["所需交付"] = session.catalog.integer("reciprocal_legs")
		details["约定"] = "已固定，按原条款分轮履行" if entry.has("covenant") else "尚未固定两项交付"
		var terms: Array = []; var records: Array = entry.get("records", [])
		for index: int in records.size():
			var sender: String = entry.people[1 - index]; var recipient: String = entry.people[index]
			terms.append({"交予者": session.object_title(sender) if session._identity_known(sender) else "尚未知晓的参加者", "接收者": session.object_title(recipient) if session._identity_known(recipient) else "尚未知晓的参加者", "原记录": session.object_title(records[index]) if session.is_known_source(records[index]) else "尚未知晓的记录", "要求": "实际交付原记录", "状态": "已完成" if index < legs.size() else "尚待履行"})
		if not terms.is_empty(): details["原两项条款"] = terms
	if row.mode in ["memory_circle", "pact_agreement"]:
		details["后续行动"] = "准备后从原祈求入口回应"
		for request: Dictionary in session._known_prayers.values():
			if not entry.has("context") or request.get("descriptor", {}).get("source") != entry.context: continue
			var card: Dictionary = request.get("card", {})
			if card.has("due_turn"): details["原请求期限"] = "第 %d 轮" % int(card.due_turn)
			var crisis: Dictionary = request.get("descriptor", {}).get("crisis", {})
			if crisis.has("due"): details["原危机期限"] = "第 %d 轮" % int(crisis.due)
			break
	if not entry.is_empty(): details["最近行动回合"] = int(entry.turn)
	return session._public(details)
