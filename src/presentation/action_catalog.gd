extends RefCounted
## Finite selectors translate known identities into production-rule inputs.
## Eligibility and payment are queried from the original module, never rebuilt.
const Store = preload("res://src/simulation/archive_store.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")

func _choice(id: Variant, label: String = "") -> Dictionary:
	return {"id": id, "label": str(id) if label.is_empty() else label}

func _field(key: String, label: String, options: Array, optional: bool = false, multiple: bool = false) -> Dictionary:
	return {"key": key, "label": label, "options": options, "optional": optional, "multiple": multiple}

func _options(ids: Array) -> Array:
	return ids.map(func(id: Variant) -> Dictionary: return _choice(id))

func _source_options(session: RefCounted, domain: String, rule: String = "", kind: String = "", actor: String = "") -> Array:
	var rows: Array = []
	var candidates: Array = session.current_sources() if kind.is_empty() else session.sources_of_kind(kind)
	for id: String in candidates:
		var fact: Dictionary = Store.entry(session.world.state.facts, id)
		if not domain.is_empty() and fact.domain != domain: continue
		if not kind.is_empty() and fact.kind != kind: continue
		if not rule.is_empty() and (fact.kind != "power_qualification" or fact.changes.get("rule") != rule): continue
		if not rule.is_empty() and not actor.is_empty() and fact.changes.get("actor") != actor: continue
		if Store.has(session.world.state.invalid_records, id): continue
		var title: String = {"world_origin": "初识时空", "background_fixed": "已展示的祈求", "prayer_fixed": "固定诉求", "prayer_registered": "祈求联系", "prayer_result": "回应结果", "prayer_fact": "回应见证", "member_dedication": "献身意愿", "member_enrolled": "成员联系", "power_qualification": "已具备的资格", "institution_event_result": "历史事件结果", "anchor_basis": "当前扎根依据", "relic_recover_authorized": "回收机会", "exposure": "暴露记录"}.get(str(fact.kind), "已知事实")
		if fact.kind == "power_qualification":
			var target: String = str(fact.changes.get("actor", fact.changes.get("target", "")))
			if target.is_empty(): target = str(fact.changes.get("target", ""))
			var target_title: String = session.object_title(target) if session._identity_known(target) else "未揭示的具体事实"
			var origin: String = str(fact.changes.get("origin", ""))
			if not target_title.is_empty(): title += " · " + target_title
			if session.is_known_source(origin): title += " · " + session.object_title(origin)
		rows.append(_choice(id, title + " · " + id.trim_prefix("FACT-")))
	return rows

func _local(session: RefCounted, domain: String) -> Array:
	var ids: Array = []
	for id: String in session.current_people():
		if Store.entry(session.world.state.npcs, id).domain == domain: ids.append(id)
	return ids

func _objects(session: RefCounted, collection: String, domain: String) -> Array:
	var result: Array = []
	var projected: Dictionary = session.project()
	for row: Dictionary in projected.get(collection, []):
		if not row.has("已知范围") and (domain.is_empty() or row.domain == domain): result.append(row.id)
	return result

func _selected(selection: Dictionary, key: String, options: Array) -> Variant:
	if selection.has(key): return selection[key] if options.any(func(option: Dictionary) -> bool: return option.id == selection[key]) else ""
	return options[0].id if options.size() == 1 else ""

func _base_fields(session: RefCounted, selection: Dictionary, needs_person: bool = true) -> Array:
	var fields: Array = [_field("domain", "时空", _options(session.known_domains()))]
	var domain: String = str(_selected(selection, "domain", fields[0].options))
	if needs_person: fields.append(_field("npc", "人物", _options(_local(session, domain))))
	return fields

func _preparations(session: RefCounted, npc: String, declaration: String) -> Array:
	var result: Array = []
	for id: String in session.world.state.power_system.preparations:
		var item: Dictionary = session.world.state.power_system.preparations[id]
		if item.npc == npc and item.action == declaration and item.expires >= session.world.state.turn and session.is_known_source(id): result.append(_choice(id))
	return result

func _power_fields(session: RefCounted, power: String, selection: Dictionary) -> Array:
	if power in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]:
		var manifest: Dictionary = session.world.state.power_system.manifest
		var source: String = str(manifest.get("source", ""))
		var fields: Array = [_field("source", "原仪式来源", [_choice(source, session.object_title(source))] if session.is_known_source(source) else [])]
		if power == "POWER_MANIFEST_CONTINUE" and not manifest.is_empty():
			var domain: String = session.world.state.anchors[manifest.cosmic_anchor].domain
			fields.append(_field("preparations", "谕言准备", _preparations(session, manifest.npc, "POWER_MANIFEST"), true, true))
			fields.append(_field("preparation_relic", "圣物准备", _options(_objects(session, "relics", domain)), true))
		return fields
	var fields: Array = _base_fields(session, selection, power != "POWER_LISTEN")
	var domain: String = str(_selected(selection, "domain", fields[0].options))
	var npc: String = str(_selected(selection, "npc", fields[1].options)) if power != "POWER_LISTEN" else ""
	var rule: String = {"POWER_LISTEN": "listen", "POWER_DREAM": "dream", "POWER_BREACH": "weakness", "POWER_SEED": "spread", "POWER_VEIL": "evidence", "POWER_SACRIFICE": "tenure"}.get(power, "")
	var sources: Array = _source_options(session, domain, rule, "", npc)
	fields.append(_field("source", "真实来源" if rule.is_empty() else "资格来源 · " + {"listen": "聆听痕迹", "dream": "梦境联系", "weakness": "屏障弱点", "spread": "传播媒介", "evidence": "传播证据", "tenure": "入团经历"}.get(rule, "见证"), sources))
	match power:
		"POWER_ORACLE":
			var declarations: Array = []
			for row: Dictionary in session.catalog.tables.powers.values():
				if row.check_kind != "deterministic": declarations.append(_choice(row.id, row.name))
			for id: String in session.world.state.prayer_system.offered:
				for variant: String in ["shallow", "deep"]: declarations.append(_choice("PRAYER/" + id + "/" + variant))
			fields.append(_field("declared_action", "要准备的检定", declarations))
		"POWER_BESTOW": fields.append(_field("attribute", "属性", [_choice("will", "意志"), _choice("insight", "洞察"), _choice("influence", "影响"), _choice("adaptation", "适应")]))
		"POWER_TRANSFER":
			var reachable: Array = []
			if session.world.state.domains.has(domain):
				for id: String in session.known_domains():
					if id in session.world.state.domains[domain].neighbors: reachable.append(id)
			fields.append(_field("target_domain", "接收时空", _options(reachable)))
			var escorts: Array = []
			var maximum: int = int(session.world.state.domains[domain].unnamed_followers) if session.world.state.domains.has(domain) else 0
			for amount: int in range(maximum + 1): escorts.append(_choice(amount))
			fields.append(_field("escort", "随行信众", escorts))
		"POWER_ANCHOR":
			var institutions: Array = session.world.state.domains[domain].institutions if session.world.state.domains.has(domain) else []
			fields.append(_field("institution", "扎根机构", _options(institutions)))
			var institution: String = str(_selected(selection, "institution", fields[fields.size() - 1].options))
			fields.append(_field("qualification", "当前扎根依据", session.anchor_source_options(institution)))
			fields.append(_field("relic", "绑定媒介", _options(_objects(session, "relics", domain))))
		"POWER_SACRIFICE":
			fields.append(_field("mode", "献祭所求", [_choice("faith", "信仰"), _choice("insight", "洞见"), _choice("heal", "愈合")]))
			fields.append(_field("witness", "独特见证", _source_options(session, domain, "witness", "", npc), true))
			fields.append(_field("milestones", "真实经历", _source_options(session, domain, "milestone", "", npc), true, true))
		"POWER_APPOINT":
			fields.append(_field("cult", "教团", _options(_objects(session, "cults", domain))))
			fields.append(_field("role", "岗位", [_choice("leader", "领袖"), _choice("guardian", "护持者")]))
			if selection.get("role") == "guardian": fields.append(_field("anchor", "护持锚点", _options(_objects(session, "anchors", domain))))
		"POWER_MANIFEST":
			var cosmic: Array = []; var system: Array = []
			for anchor: Dictionary in session.project().anchors:
				if session.world.state.domains[anchor.domain].tier == "cosmic": cosmic.append(anchor.id)
				if session.world.state.domains[anchor.domain].tier == "system": system.append(anchor.id)
			fields.append(_field("cosmic_anchor", "宇宙锚点", _options(cosmic)))
			fields.append(_field("system_anchor", "星系锚点", _options(system)))
	if not power in ["POWER_LISTEN", "POWER_APPOINT", "POWER_MANIFEST_CANCEL"]:
		fields.append(_field("preparations", "谕言准备", _preparations(session, npc, "POWER_MANIFEST" if power == "POWER_MANIFEST_CONTINUE" else power), true, true))
		fields.append(_field("preparation_relic", "圣物准备", _options(_objects(session, "relics", domain)), true))
	return fields

func _row(session: RefCounted, key: String, title: String, fields: Array, selection: Dictionary, details: Dictionary = {}) -> Dictionary:
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

func _prayer_irreversible(session: RefCounted, request_id: String, variant: String) -> bool:
	if variant == "deep": return true
	var request: Dictionary = session.prayer_entry(request_id)
	if request.is_empty(): return false
	for row: Dictionary in session.catalog.tables.prayer_effects.values():
		if not row.prayer_id in [request.card.content_id, "*"] or not row.variant in [variant, "both"] or row.stage == "expiry": continue
		if row.operation in ["enroll", "withdraw", "vacate", "learn", "fulfill", "memory", "recovery"]: return true
	return false

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
				var fields: Array = []
				if descriptor.content_id == "EVENT_06" and option == "B": fields.append(_field("qualification", "撤回的记忆资格", _options(descriptor.facts.get("qualifications", []).filter(func(id: String) -> bool: return session.is_known_source(id)))))
				var effect: Dictionary = session.catalog.tables.event_effects[descriptor.content_id + "/" + option]
				var details: Dictionary = _context(session, descriptor, entry.card)
				details.merge({"选择后果": effect.on_choose, "不可逆代价": effect.irreversible_cost, "信仰费用": int(effect.faith_cost)})
				rows.append(_row(session, "event/" + event.id + "/" + option, session.catalog.tables.events[descriptor.content_id].title + " · " + option, fields, selection, details))
		return rows
	if session.turn.context.phase != "actions": return rows
	if session.modules.has("progression_routes"):
		rows.append(_row(session, "route/context", "促成当前进展", _route_fields(session, selection), selection, {"行动": "选择当前人物可促成的组织、实践或约定。准备完成的记忆与保管约定从原祈求回应。"}))
	for id: String in session.world.state.prayer_system.offered:
		var request: Dictionary = session.prayer_entry(id)
		var content: String = request.card.content_id
		for variant: String in ["shallow", "deep"]:
			var fields: Array = [_field("preparations", "谕言准备", _preparations(session, str(request.get("descriptor", {}).get("subjects", {}).get("petitioner", request.card.actors[0])), "PRAYER/" + id + "/" + variant), true, true)]
			var agents: Array = []; var authorizations: Array = []
			for source: String in session.sources_of_kind("message"):
				var fact: Dictionary = Store.entry(session.world.state.facts, source)
				if fact.kind != "message" or not request.get("descriptor", {}).get("source", request.card.fact) in fact.causal_parents: continue
				for person: String in fact.targets:
					if person in session.known_people() and Store.entry(session.world.state.npcs, person).get("bound_member", false):
						if not person in agents: agents.append(person)
						authorizations.append(source)
			fields.append(_field("agent", "受托回应者", _options(agents), true)); fields.append(_field("agent_source", "实际委托", _options(authorizations), true))
			var prayer: Dictionary = session.catalog.tables.prayers[content]
			var details: Dictionary = _context(session, request.descriptor, request.card)
			details.merge({"回应所得": prayer[variant + "_gain"], "始终代价": prayer[variant + "_cost"]})
			rows.append(_row(session, "prayer/" + id + "/" + variant, session.prayer_title(request.descriptor, request.card) + (" · 浅触" if variant == "shallow" else " · 深应"), fields, selection, details))
	for power: Dictionary in session.catalog.tables.powers.values(): rows.append(_row(session, power.id, power.name, _power_fields(session, power.id, selection), selection, {"requirement": power.target_requirement, "always": power.always_cost, "success": power.success, "deep": power.deep_success, "failure": power.failure, "disaster": power.disaster}))
	if not session.world.state.power_system.manifest.is_empty():
		for id: String in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]: rows.append(_row(session, id, "继续降临" if id.ends_with("CONTINUE") else "中止降临", _power_fields(session, id, selection), selection, _manifest_context(session)))
	for action: String in ["equip", "unequip", "unbind", "recover", "disassemble"]:
		var fields: Array = _base_fields(session, selection, action in ["equip", "recover"])
		var domain: String = str(_selected(selection, "domain", fields[0].options))
		fields.append(_field("relic", "圣物", _options(_objects(session, "relics", domain))))
		fields.append(_field("source", "当前来源", _source_options(session, domain, "", "relic_recover_authorized" if action == "recover" else "")))
		if action == "disassemble": fields.append(_field("mode", "分解所求", [_choice("faith", "信仰"), _choice("insight", "洞见"), _choice("followers", "信众"), _choice("whispers", "低语")]))
		rows.append(_row(session, "relic/" + action, {"equip": "携带圣物", "unequip": "卸下圣物", "unbind": "解除媒介绑定", "recover": "回收圣物", "disassemble": "分解圣物"}[action], fields, selection))
	for source: String in session.world.state.anchor_system.opportunities.values():
		if not session.is_known_source(source): continue
		var fact: Dictionary = Store.entry(session.world.state.facts, source)
		for option: String in ["recover", "public", "wait"]:
			var fields: Array = [_field("npc", "实际携带者（有教团库存时可不选）", _options(_local(session, fact.domain)), true)] if option == "recover" else []
			rows.append(_row(session, "opportunity/" + source + "/" + option, {"recover": "回收机构媒介", "public": "公开机构媒介", "wait": "等待"}[option], fields, selection))
	var transfers: Array = session.material_transfer_options()
	if not transfers.is_empty(): rows.append(_row(session, "cults/transfer_material", "交予记录", _transfer_fields(session, transfers, selection), selection, {"取得内容": "取得指定记录副本或准确知识；不增加见证、实践或契约责任。"}))
	for kind: String in ["focus", "release_focus", "enroll", "leave", "release_project"]:
		var fields: Array = []
		if kind in ["focus", "release_focus"]: fields.append(_field("domain", "时空", _options(session.focus_domains())))
		elif kind == "release_project": fields.append(_field("token", "持有的预留", _options(session.world.state.attention.reservations.keys().filter(func(token: String) -> bool: return session.world.state.attention.reservations[token].get("owner") != "prayers"))))
		else:
			fields.append(_field("npc", "人物", _options(session.known_people())))
			fields.append(_field("source", "实际身份来源", _source_options(session, "", "", "member_dedication" if kind == "enroll" else "member_leave_authorized")))
		rows.append(_row(session, "attention/" + kind, {"focus": "关注时空", "release_focus": "下轮释放关注", "enroll": "接纳成员", "leave": "确认离团", "release_project": "释放未用预留"}[kind], fields, selection))
	return rows

func _fields_for(session: RefCounted, key: String, selection: Dictionary) -> Array:
	# Catalog construction validates the same finite options as the controls.
	for row: Dictionary in list_actions(session, selection):
		if row.key == key: return row.fields
	return []

func preview(session: RefCounted, key: String, selection: Dictionary = {}) -> Dictionary:
	for row: Dictionary in list_actions(session, selection):
		if row.key == key: return row.preview.duplicate(true)
	return {"ok": false, "error": "当前没有此行动"}

func command(session: RefCounted, key: String, selection: Dictionary = {}) -> Dictionary:
	for row: Dictionary in list_actions(session, selection):
		if row.key == key: return _prepare(session, key, selection, row.fields)
	return {"ok": false, "error": "当前没有此行动"}

func _prepare(session: RefCounted, key: String, selection: Dictionary, fields: Array) -> Dictionary:
	var payload: Dictionary = {}
	for field: Dictionary in fields:
		var value: Variant = selection.get(field.key, [] if field.multiple else ("" if field.optional else _selected(selection, field.key, field.options)))
		if field.optional and ((value is String and value.is_empty()) or (value is Array and value.is_empty())): continue
		var values: Array = value if field.multiple and value is Array else [value]
		if field.multiple and not value is Array: return {"ok": false, "error": "请选择有效的" + field.label}
		for item: Variant in values:
			if not field.options.any(func(option: Dictionary) -> bool: return option.id == item): return {"ok": false, "error": "缺少或已失效：" + field.label}
		payload[field.key] = value
	var previewed: Dictionary = {}; var op: String = "act"; var submission: Dictionary = {}; var irreversible: bool = false
	var parts: PackedStringArray = key.split("/")
	if key.begins_with("POWER_"):
		previewed = session.modules.powers.preview(session.turn, key, payload)
		submission = {"participant": "powers", "action": key, "payload": payload}
		irreversible = key in ["POWER_SACRIFICE", "POWER_MANIFEST", "POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]
	elif parts[0] == "route" and parts.size() == 2:
		var operation: String = str(payload.get("operation", parts[1]))
		payload.erase("operation"); payload.erase("domain")
		previewed = session.modules.progression_routes.preview(session.turn, operation, payload)
		submission = {"participant": "progression_routes", "action": operation, "payload": payload}
	elif parts[0] == "prayer" and parts.size() == 3:
		previewed = session.modules.prayers.preview(session.turn, parts[1], parts[2], payload)
		payload["request"] = parts[1]; payload["variant"] = parts[2]
		submission = {"participant": "prayers", "action": "respond", "payload": payload}
		irreversible = _prayer_irreversible(session, parts[1], parts[2])
	elif parts[0] == "event" and parts.size() == 3:
		previewed = session.modules.events.preview(session.turn, parts[1], parts[2], payload)
		op = "resolve_event"; submission = {"event": parts[1], "action": parts[2], "payload": payload}
		irreversible = true
	elif parts[0] == "relic" and parts.size() == 2:
		payload.erase("domain")
		var view: Dictionary = session.turn._read_view("relics", "actions")
		var result: Dictionary = session.modules.relics.handle(view, {"slot": "actions", "operation": "act", "action": parts[1], "payload": payload})
		view.reader.close()
		previewed = _declaration_preview(session, result)
		submission = {"participant": "relics", "action": parts[1], "payload": payload}
		irreversible = parts[1] in ["disassemble", "unbind"]
	elif parts[0] == "opportunity" and parts.size() == 3:
		payload["opportunity"] = parts[1]; payload["option"] = parts[2]
		previewed = session.modules.events.preview_opportunity(session.turn, payload)
		submission = {"participant": "events", "action": "opportunity", "payload": payload}
	elif key == "cults/transfer_material":
		previewed = session.modules.cults.preview_transfer(session.turn, payload)
		submission = {"participant": "cults", "action": "transfer_material", "payload": payload}
	elif parts[0] == "attention" and parts.size() == 2:
		payload["kind"] = parts[1]
		previewed = session.turn.preview_attention(payload)
		op = "attention"; submission = {"command": payload}
	else: return {"ok": false, "error": "未知行动"}
	if not previewed.get("ok", false): return {"ok": false, "error": session.explain_error(str(previewed.get("error", "当前对象、来源或资源不符合条件")))}
	# A public preview includes only what the player must decide. Raw plans and
	# qualification internals remain in the rule layer.
	var plan: Dictionary = previewed.get("preview", previewed)
	var visible: Dictionary = {}
	for field: String in ["faith", "whispers", "faith_cost", "probability", "net_gain", "awakening_loss", "consumes", "needs"]:
		if plan.has(field): visible[field] = plan[field].duplicate(true) if plan[field] is Dictionary or plan[field] is Array else plan[field]
	if visible.has("probability") and int(visible.probability) >= 0:
		var outcomes: Dictionary = {"deep": 0, "success": 0, "failure": 0, "disaster": 0}
		for roll: int in range(1, 101): outcomes[session.world.check_result(int(visible.probability), roll)] += 1
		visible["outcomes"] = outcomes
	if visible.has("needs"):
		visible.needs = {"budgets": visible.needs.get("budgets", {})}
	return {"ok": true, "op": op, "fields": submission, "preview": visible, "irreversible": irreversible}

func _declaration_preview(session: RefCounted, declaration: Dictionary) -> Dictionary:
	if not declaration.get("ok", false): return {"ok": false, "error": declaration.get("error", "当前圣物不可执行此操作")}
	var meta: Dictionary = declaration.get("meta", {})
	var admission: Dictionary = session.world.attention.preview_needs(session.world.state, meta.get("attention", {}), declaration.get("effects", []))
	if not admission.ok: return admission
	return {"ok": true, "preview": declaration.get("preview", {}).merged({"faith": meta.get("faith_cost", 0), "whispers": meta.get("whispers_cost", 0), "needs": admission})}

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

func _route_fields(session: RefCounted, selection: Dictionary) -> Array:
	var fields: Array = _base_fields(session, selection)
	var domain: String = str(_selected(selection, "domain", fields[0].options))
	var npc: String = str(_selected(selection, "npc", fields[1].options))
	var person: Dictionary = Store.entry(session.world.state.npcs, npc, {})
	var lessons: Array = []
	for key: String in session.world.state.progression_routes.progress:
		var entry: Dictionary = session.world.state.progression_routes.progress[key]
		if entry.operation != "ROUTE_RITUAL_TRANSMISSION" or not entry.has("lesson") or entry.get("completed", false) or not session.is_known_source(entry.lesson): continue
		var lesson: Dictionary = Store.entry(session.world.state.facts, entry.lesson)
		if lesson.changes.data.get("student") == npc: lessons.append(_choice(key, session.object_title(entry.lesson)))
	var labels: Dictionary = {"private_devotion": "当下私祷", "joint_work": "共同工作", "covert_gathering": "秘密集会", "calendar_rite": "主持祭仪", "record_practice": "记录实践", "calendar_keeping": "历法实践", "ritual_transmission": "祭仪教习", "memory_circle": "共同见闻", "memory_practice": "共同回忆实践", "dissent_practice": "异议实践", "pact_agreement": "保管约定", "reciprocal_covenant": "互惠交付", "network_exchange": "网络交换", "axiom_probe": "观察异常", "axiom_recheck": "独立观察同一异常", "axiom_repeat": "使用同一例外"}
	var operations: Array = []
	if person.get("status") == "active":
		for row: Dictionary in session.catalog.tables.progression_route_operations.values():
			if not labels.has(row.mode): continue
			var output_route: String = {"record_practice": "record_dependency", "calendar_keeping": "calendar_dependency", "memory_practice": "memory_practice", "dissent_practice": "dissent_practice", "pact_agreement": "contract_performance", "reciprocal_covenant": "contract_reciprocal", "network_exchange": "network_exchange", "ritual_transmission": "ritual_practice", "axiom_probe": "axiom_nodes", "axiom_recheck": "axiom_nodes", "axiom_repeat": "axiom_archive"}.get(row.mode, "")
			if not output_route.is_empty() and session.catalog.tables.anchor_route_rules[output_route].profile != session.world.state.domains[domain].profile: continue
			if row.mode == "memory_circle" and not session.catalog.tables.anchor_route_rules.values().any(func(route: Dictionary) -> bool: return route.selector == "memory_circle" and route.profile == session.world.state.domains[domain].profile): continue
			if row.mode in ["record_practice", "calendar_keeping"] and not "record_keeper" in person.role_tags: continue
			if row.mode == "calendar_rite" and not "ritual_keeper" in person.role_tags: continue
			if row.mode == "ritual_transmission" and not "ritual_keeper" in person.role_tags and lessons.is_empty(): continue
			if row.mode == "covert_gathering" and not person.get("bound_member", false): continue
			if row.mode.begins_with("axiom_") and session.world.state.domains[domain].tier != "cosmic": continue
			if row.mode == "memory_circle" and session.world.state.institutions[person.institution].role != "interpretation": continue
			operations.append(_choice(row.id, labels[row.mode]))
	fields.append(_field("operation", "促成方式", operations))
	var operation: String = str(_selected(selection, "operation", operations))
	var mode: String = str(session.catalog.tables.progression_route_operations.get(operation, {}).get("mode", ""))
	fields.append(_field("source", "当前来源", _source_options(session, domain)))
	var student_performance: bool = false
	if mode == "ritual_transmission" and not lessons.is_empty():
		fields.append(_field("target", "独自施行已教祭仪", lessons, "ritual_keeper" in person.get("role_tags", [])))
		student_performance = not str(_selected(selection, "target", lessons)).is_empty()
	var others: Array = _local(session, domain).filter(func(id: String) -> bool: return id != npc)
	if mode in ["joint_work", "ritual_transmission", "memory_practice", "dissent_practice", "pact_agreement", "reciprocal_covenant", "network_exchange"] and not student_performance: fields.append(_field("other", "另一参加者", _options(others)))
	if mode == "memory_circle": fields.append(_field("participants", "三位见闻参加者", _options(others), false, true))
	if mode in ["memory_circle", "memory_practice", "dissent_practice", "pact_agreement", "reciprocal_covenant"]:
		var records: Array = []
		for id: String in session.known_sources():
			var resolved: Dictionary = session.modules.progression_routes.Materials.resolve(session.world.state, id, session.catalog, session.world.history)
			if resolved.get("ok", false) and resolved.material.kind in ["evidence", "dream"]: records.append(id)
		fields.append(_field("record", "实际记录", _options(records), mode in ["memory_practice", "dissent_practice"]))
		if mode == "reciprocal_covenant":
			fields.append(_field("second_record", "另一端的记录", _options(records), true))
			fields.append(_field("stage", "履行进度", [_choice("prepare", "固定两项约定"), _choice("perform", "履行下一项交付")]))
	if mode in ["axiom_recheck", "axiom_repeat"]: fields.append(_field("target", "同一实际例外", _options(session.sources_of_kind("exception"))))
	return fields

func _transfer_fields(session: RefCounted, available: Array, selection: Dictionary) -> Array:
	var fields: Array = []; var candidates: Array = available.duplicate()
	var labels: Dictionary = {"target_institution": "目标机构", "source": "原记录", "sender": "交予者", "recipient": "接收者", "grant": "取得内容"}
	for key: String in ["target_institution", "source", "sender", "recipient", "grant"]:
		var options: Array = []; var seen: Dictionary = {}
		for candidate: Dictionary in candidates:
			var value: String = candidate[key]
			if seen.has(value): continue
			seen[value] = true
			options.append(_choice(value, ("记录保管（含知晓）" if value == "custody" else "准确知晓") if key == "grant" else session.object_title(value)))
		var field: Dictionary = _field(key, labels[key], options)
		fields.append(field)
		var chosen: String = str(_selected(selection, key, options))
		if not chosen.is_empty(): candidates = candidates.filter(func(candidate: Dictionary) -> bool: return candidate[key] == chosen)
	return fields
