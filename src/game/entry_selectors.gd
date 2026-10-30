extends RefCounted
## Exact finite selectors shared by presentation and read-view eligibility.
## Only the requested entry is resolved; this module never enumerates action combinations.
const Store = preload("res://src/simulation/archive_store.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const Knowledge = preload("res://src/game/player_knowledge.gd")

static func context(view: Dictionary, knowledge: Dictionary, modules: Dictionary, label: Callable = Callable()) -> Dictionary:
	if view.get("reader") != null:
		for id: String in knowledge.get("known_relics", {}):
			if not Store.has(view.world.relics, id):
				var found: Dictionary = view.reader.entity("relics", id)
				if found.get("ok", false): view.world.relics[id] = found.item
	return {"world": view.world, "turn": view.turn, "reader": view.get("reader"), "catalog": view.catalog, "knowledge": knowledge, "modules": modules, "label": label}

static func _keys(context: Dictionary, field: String) -> Array:
	var result: Array = context.knowledge.get(field, {}).keys(); result.sort(); return result

static func _fact(context: Dictionary, source: String) -> Dictionary:
	if Store.has(context.world.facts, source): return Store.entry(context.world.facts, source)
	if context.reader == null: return {}
	var found: Dictionary = context.reader.fact(source)
	return found.get("item", {}) if found.get("ok", false) else {}

static func _title(context: Dictionary, id: String) -> String:
	return context.label.call(id) if context.label.is_valid() else id

static func _known(context: Dictionary, id: String) -> bool:
	return context.knowledge.get("known_facts", {}).has(id)

static func _identity_known(context: Dictionary, id: String) -> bool:
	if id.begins_with("NPC-"): return context.knowledge.known_people.has(id) or context.knowledge.request_people.has(id)
	if id.begins_with("DOMAIN-") and not context.world.institutions.has(id): return context.knowledge.known_domains.has(id) or context.knowledge.request_domains.has(id)
	if context.world.institutions.has(id): return context.knowledge.known_domains.has(context.world.institutions[id].domain) or context.knowledge.request_objects.has(id)
	if id.begins_with("FACT-"): return _known(context, id)
	if id.begins_with("RELIC/"): return context.knowledge.known_relics.has(id) or context.knowledge.request_objects.has(id)
	return false

static func _current_people(context: Dictionary) -> Array:
	var result: Array = []
	for id: String in _keys(context, "known_people"):
		if Store.has(context.world.npcs, id) and Store.entry(context.world.npcs, id).status != "dead": result.append(id)
	return result

static func _kind(context: Dictionary, kind: String) -> Array:
	var result: Array = context.knowledge.get("known_kinds", {}).get(kind, {}).keys(); result.sort(); return result

static func _current_sources(context: Dictionary) -> Array:
	var result: Dictionary = {}
	for domain: String in _keys(context, "known_domains"): result[context.world.domains[domain].origin] = true
	for id: String in _current_people(context):
		var person: Dictionary = Store.entry(context.world.npcs, id)
		for field: String in ["status_source", "binding_source", "dedication_source", "joined_source"]:
			if _known(context, str(person.get(field, ""))): result[person[field]] = true
	for request: Dictionary in Store.values(context.world.prayer_system.requests):
		for id: String in [request.card.fact, request.source, str(request.descriptor.get("source", ""))]:
			if _known(context, id): result[id] = true
	for proof: Dictionary in context.modules.player_sources.available_state(context.world, context.reader):
		if _known(context, proof.id): result[proof.id] = true
	for sources: Dictionary in context.world.anchor_system.get("routes", {}).values():
		for source: String in sources.values():
			if _known(context, source): result[source] = true
	for relic_id: String in _keys(context, "known_relics"):
		var relic: Dictionary = Store.entry(context.world.relics, relic_id)
		for id: String in [relic.origin, relic.status_source]:
			if _known(context, id): result[id] = true
	var ids: Array = result.keys(); ids.sort(); return ids

static func _objects(context: Dictionary, collection: String, domain: String) -> Array:
	var result: Array = []
	for id: String in Store.keys(context.world.get(collection, {})):
		var row: Dictionary = Store.entry(context.world[collection], id)
		var visible: bool = false
		if collection == "relics": visible = context.knowledge.known_relics.has(id)
		elif collection == "cults": visible = _known(context, str(row.get("established_source", ""))) or context.knowledge.known_people.has(str(row.get("leader", "")))
		elif collection == "anchors": visible = _known(context, str(row.get("established_source", ""))) or context.knowledge.known_people.has(str(row.get("guardian", "")))
		if visible and (domain.is_empty() or row.domain == domain): result.append(id)
	return result

static func _anchor_sources(context: Dictionary, institution: String) -> Array:
	var result: Array = []
	if not context.world.institutions.has(institution): return result
	for permission: Dictionary in Anchors.available(context.world, institution, context.catalog, context.reader):
		if _known(context, permission.source): result.append({"id": permission.source, "label": "当前扎根依据 · " + str(permission.source).trim_prefix("FACT-")})
	return result

static func _choice(id: Variant, label: String = "") -> Dictionary:
	return {"id": id, "label": str(id) if label.is_empty() else label}

static func _field(key: String, label: String, options: Array, optional: bool = false, multiple: bool = false) -> Dictionary:
	return {"key": key, "label": label, "options": options, "optional": optional, "multiple": multiple}

static func _options(ids: Array) -> Array:
	return ids.map(func(id: Variant) -> Dictionary: return _choice(id))

static func _source_options(context: Dictionary, domain: String, rule: String = "", kind: String = "", actor: String = "") -> Array:
	var rows: Array = []
	var candidates: Array = _current_sources(context) if kind.is_empty() else _kind(context, kind)
	for id: String in candidates:
		var fact: Dictionary = _fact(context, id)
		if not domain.is_empty() and fact.domain != domain: continue
		if not kind.is_empty() and fact.kind != kind: continue
		if not rule.is_empty() and (fact.kind != "power_qualification" or fact.changes.get("rule") != rule): continue
		if not rule.is_empty() and not actor.is_empty() and fact.changes.get("actor") != actor: continue
		if Store.has(context.world.invalid_records, id): continue
		var title: String = {"world_origin": "初识时空", "background_fixed": "已展示的祈求", "prayer_fixed": "固定诉求", "prayer_registered": "祈求联系", "prayer_result": "回应结果", "prayer_fact": "回应见证", "member_dedication": "献身意愿", "member_enrolled": "成员联系", "power_qualification": "已具备的资格", "institution_event_result": "历史事件结果", "anchor_basis": "当前扎根依据", "relic_recover_authorized": "回收机会", "exposure": "暴露记录"}.get(str(fact.kind), "已知事实")
		if fact.kind == "power_qualification":
			var target: String = str(fact.changes.get("actor", fact.changes.get("target", "")))
			if target.is_empty(): target = str(fact.changes.get("target", ""))
			var target_title: String = _title(context, target) if _identity_known(context, target) else "未揭示的具体事实"
			var origin: String = str(fact.changes.get("origin", ""))
			if not target_title.is_empty(): title += " · " + target_title
			if _known(context, origin): title += " · " + _title(context, origin)
		rows.append(_choice(id, title + " · " + id.trim_prefix("FACT-")))
	return rows

static func _local(context: Dictionary, domain: String) -> Array:
	var ids: Array = []
	for id: String in _current_people(context):
		if Store.entry(context.world.npcs, id).domain == domain: ids.append(id)
	return ids

static func _selected(selection: Dictionary, key: String, options: Array) -> Variant:
	if selection.has(key): return selection[key] if options.any(func(option: Dictionary) -> bool: return option.id == selection[key]) else ""
	return options[0].id if options.size() == 1 else ""

static func _base_fields(context: Dictionary, selection: Dictionary, needs_person: bool = true) -> Array:
	var fields: Array = [_field("domain", "时空", _options(_keys(context, "known_domains")))]
	var domain: String = str(_selected(selection, "domain", fields[0].options))
	if needs_person: fields.append(_field("npc", "人物", _options(_local(context, domain))))
	return fields

static func _preparations(context: Dictionary, npc: String, declaration: String) -> Array:
	var result: Array = []
	for id: String in context.world.power_system.preparations:
		var item: Dictionary = context.world.power_system.preparations[id]
		if item.npc == npc and item.action == declaration and item.expires >= context.world.turn and _known(context, id): result.append(_choice(id))
	return result

static func _power_fields(context: Dictionary, power: String, selection: Dictionary) -> Array:
	if power in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]:
		var manifest: Dictionary = context.world.power_system.manifest
		var source: String = str(manifest.get("source", ""))
		var fields: Array = [_field("source", "原仪式来源", [_choice(source, _title(context, source))] if _known(context, source) else [])]
		if power == "POWER_MANIFEST_CONTINUE" and not manifest.is_empty():
			var domain: String = context.world.anchors[manifest.cosmic_anchor].domain
			fields.append(_field("preparations", "谕言准备", _preparations(context, manifest.npc, "POWER_MANIFEST"), true, true))
			fields.append(_field("preparation_relic", "圣物准备", _options(_objects(context, "relics", domain)), true))
		return fields
	var fields: Array = _base_fields(context, selection, power != "POWER_LISTEN")
	var domain: String = str(_selected(selection, "domain", fields[0].options))
	var npc: String = str(_selected(selection, "npc", fields[1].options)) if power != "POWER_LISTEN" else ""
	var rule: String = {"POWER_LISTEN": "listen", "POWER_DREAM": "dream", "POWER_BREACH": "weakness", "POWER_SEED": "spread", "POWER_VEIL": "evidence", "POWER_SACRIFICE": "tenure"}.get(power, "")
	var sources: Array = _source_options(context, domain, rule, "", npc)
	fields.append(_field("source", "真实来源" if rule.is_empty() else "资格来源 · " + {"listen": "聆听痕迹", "dream": "梦境联系", "weakness": "屏障弱点", "spread": "传播媒介", "evidence": "传播证据", "tenure": "入团经历"}.get(rule, "见证"), sources))
	match power:
		"POWER_ORACLE":
			var declarations: Array = []
			for row: Dictionary in context.catalog.tables.powers.values():
				if row.check_kind != "deterministic": declarations.append(_choice(row.id, row.name))
			for id: String in context.world.prayer_system.offered:
				for variant: String in ["shallow", "deep"]: declarations.append(_choice("PRAYER/" + id + "/" + variant))
			fields.append(_field("declared_action", "要准备的检定", declarations))
		"POWER_BESTOW": fields.append(_field("attribute", "属性", [_choice("will", "意志"), _choice("insight", "洞察"), _choice("influence", "影响"), _choice("adaptation", "适应")]))
		"POWER_TRANSFER":
			var reachable: Array = []
			if context.world.domains.has(domain):
				for id: String in _keys(context, "known_domains"):
					if id in context.world.domains[domain].neighbors: reachable.append(id)
			fields.append(_field("target_domain", "接收时空", _options(reachable)))
			var escorts: Array = []
			var maximum: int = int(context.world.domains[domain].unnamed_followers) if context.world.domains.has(domain) else 0
			for amount: int in range(maximum + 1): escorts.append(_choice(amount))
			fields.append(_field("escort", "随行信众", escorts))
		"POWER_ANCHOR":
			var institutions: Array = context.world.domains[domain].institutions if context.world.domains.has(domain) else []
			fields.append(_field("institution", "扎根机构", _options(institutions)))
			var institution: String = str(_selected(selection, "institution", fields[fields.size() - 1].options))
			fields.append(_field("qualification", "当前扎根依据", _anchor_sources(context, institution)))
			fields.append(_field("relic", "绑定媒介", _options(_objects(context, "relics", domain))))
		"POWER_SACRIFICE":
			fields.append(_field("mode", "献祭所求", [_choice("faith", "信仰"), _choice("insight", "洞见"), _choice("heal", "愈合")]))
			fields.append(_field("witness", "独特见证", _source_options(context, domain, "witness", "", npc), true))
			fields.append(_field("milestones", "真实经历", _source_options(context, domain, "milestone", "", npc), true, true))
		"POWER_APPOINT":
			fields.append(_field("cult", "教团", _options(_objects(context, "cults", domain))))
			fields.append(_field("role", "岗位", [_choice("leader", "领袖"), _choice("guardian", "护持者")]))
			if selection.get("role") == "guardian": fields.append(_field("anchor", "护持锚点", _options(_objects(context, "anchors", domain))))
		"POWER_MANIFEST":
			var cosmic: Array = []; var system: Array = []
			for anchor_id: String in _objects(context, "anchors", ""):
				var anchor: Dictionary = context.world.anchors[anchor_id]
				if context.world.domains[anchor.domain].tier == "cosmic": cosmic.append(anchor.id)
				if context.world.domains[anchor.domain].tier == "system": system.append(anchor.id)
			fields.append(_field("cosmic_anchor", "宇宙锚点", _options(cosmic)))
			fields.append(_field("system_anchor", "星系锚点", _options(system)))
	if not power in ["POWER_LISTEN", "POWER_APPOINT", "POWER_MANIFEST_CANCEL"]:
		fields.append(_field("preparations", "谕言准备", _preparations(context, npc, "POWER_MANIFEST" if power == "POWER_MANIFEST_CONTINUE" else power), true, true))
		fields.append(_field("preparation_relic", "圣物准备", _options(_objects(context, "relics", domain)), true))
	return fields

static func _route_fields(context: Dictionary, selection: Dictionary) -> Array:
	var fields: Array = _base_fields(context, selection)
	var domain: String = str(_selected(selection, "domain", fields[0].options))
	var npc: String = str(_selected(selection, "npc", fields[1].options))
	var person: Dictionary = Store.entry(context.world.npcs, npc, {})
	var lessons: Array = []
	for key: String in context.world.progression_routes.progress:
		var entry: Dictionary = context.world.progression_routes.progress[key]
		if entry.operation != "ROUTE_RITUAL_TRANSMISSION" or not entry.has("lesson") or entry.get("completed", false) or not _known(context, entry.lesson): continue
		var lesson: Dictionary = _fact(context, entry.lesson)
		if lesson.changes.data.get("student") == npc: lessons.append(_choice(key, _title(context, entry.lesson)))
	var labels: Dictionary = {"private_devotion": "当下私祷", "joint_work": "共同工作", "covert_gathering": "秘密集会", "calendar_rite": "主持祭仪", "record_practice": "记录实践", "calendar_keeping": "历法实践", "ritual_transmission": "祭仪教习", "memory_circle": "共同见闻", "memory_practice": "共同回忆实践", "dissent_practice": "异议实践", "pact_agreement": "保管约定", "reciprocal_covenant": "互惠交付", "network_exchange": "网络交换", "axiom_probe": "观察异常", "axiom_recheck": "独立观察同一异常", "axiom_repeat": "使用同一例外"}
	var operations: Array = []
	if person.get("status") == "active":
		for row: Dictionary in context.catalog.tables.progression_route_operations.values():
			if not labels.has(row.mode): continue
			var output_route: String = {"record_practice": "record_dependency", "calendar_keeping": "calendar_dependency", "memory_practice": "memory_practice", "dissent_practice": "dissent_practice", "pact_agreement": "contract_performance", "reciprocal_covenant": "contract_reciprocal", "network_exchange": "network_exchange", "ritual_transmission": "ritual_practice", "axiom_probe": "axiom_nodes", "axiom_recheck": "axiom_nodes", "axiom_repeat": "axiom_archive"}.get(row.mode, "")
			if not output_route.is_empty() and context.catalog.tables.anchor_route_rules[output_route].profile != context.world.domains[domain].profile: continue
			if row.mode == "memory_circle" and not context.catalog.tables.anchor_route_rules.values().any(func(route: Dictionary) -> bool: return route.selector == "memory_circle" and route.profile == context.world.domains[domain].profile): continue
			if row.mode in ["record_practice", "calendar_keeping"] and not "record_keeper" in person.role_tags: continue
			if row.mode == "calendar_rite" and not "ritual_keeper" in person.role_tags: continue
			if row.mode == "ritual_transmission" and not "ritual_keeper" in person.role_tags and lessons.is_empty(): continue
			if row.mode == "covert_gathering" and not person.get("bound_member", false): continue
			if row.mode.begins_with("axiom_") and context.world.domains[domain].tier != "cosmic": continue
			if row.mode == "memory_circle" and context.world.institutions[person.institution].role != "interpretation": continue
			operations.append(_choice(row.id, labels[row.mode]))
	fields.append(_field("operation", "促成方式", operations))
	var operation: String = str(_selected(selection, "operation", operations))
	var mode: String = str(context.catalog.tables.progression_route_operations.get(operation, {}).get("mode", ""))
	fields.append(_field("source", "当前来源", _source_options(context, domain)))
	var student_performance: bool = false
	if mode == "ritual_transmission" and not lessons.is_empty():
		fields.append(_field("target", "独自施行已教祭仪", lessons, "ritual_keeper" in person.get("role_tags", [])))
		student_performance = not str(_selected(selection, "target", lessons)).is_empty()
	var others: Array = _local(context, domain).filter(func(id: String) -> bool: return id != npc)
	if mode in ["joint_work", "ritual_transmission", "memory_practice", "dissent_practice", "pact_agreement", "reciprocal_covenant", "network_exchange"] and not student_performance: fields.append(_field("other", "另一参加者", _options(others)))
	if mode == "memory_circle": fields.append(_field("participants", "三位见闻参加者", _options(others), false, true))
	if mode in ["memory_circle", "memory_practice", "dissent_practice", "pact_agreement", "reciprocal_covenant"]:
		var records: Array = []
		for id: String in _keys(context, "known_facts"):
			var resolved: Dictionary = context.modules.progression_routes.Materials.resolve(context.world, id, context.catalog, context.reader)
			if resolved.get("ok", false) and resolved.material.kind in ["evidence", "dream"]: records.append(id)
		fields.append(_field("record", "实际记录", _options(records), mode in ["memory_practice", "dissent_practice"]))
		if mode == "reciprocal_covenant":
			fields.append(_field("second_record", "另一端的记录", _options(records), true))
			fields.append(_field("stage", "履行进度", [_choice("prepare", "固定两项约定"), _choice("perform", "履行下一项交付")]))
	if mode in ["axiom_recheck", "axiom_repeat"]: fields.append(_field("target", "同一实际例外", _options(_kind(context, "exception"))))
	return fields

static func _transfer_fields(context: Dictionary, available: Array, selection: Dictionary) -> Array:
	var fields: Array = []; var candidates: Array = available.duplicate()
	var labels: Dictionary = {"target_institution": "目标机构", "source": "原记录", "sender": "交予者", "recipient": "接收者", "grant": "取得内容"}
	for key: String in ["target_institution", "source", "sender", "recipient", "grant"]:
		var options: Array = []; var seen: Dictionary = {}
		for candidate: Dictionary in candidates:
			var value: String = candidate[key]
			if seen.has(value): continue
			seen[value] = true
			options.append(_choice(value, ("记录保管（含知晓）" if value == "custody" else "准确知晓") if key == "grant" else _title(context, value)))
		var field: Dictionary = _field(key, labels[key], options)
		fields.append(field)
		var chosen: String = str(_selected(selection, key, options))
		if not chosen.is_empty(): candidates = candidates.filter(func(candidate: Dictionary) -> bool: return candidate[key] == chosen)
	return fields


static func fields(context: Dictionary, entry: String, selection: Dictionary) -> Dictionary:
	var parts: PackedStringArray = entry.split("/")
	var phase: String = str(context.turn.get("phase", ""))
	var output: Array = []
	if parts[0] == "event" and parts.size() == 3:
		if phase != "events" or not context.modules.has("events"): return {"ok": false, "error": "当前没有此行动"}
		var event: Dictionary = context.world.event_system.cards.get(parts[1], {})
		if event.is_empty() or not context.knowledge.known_events.has(parts[1]) or not parts[1] in context.world.event_system.selected or not context.modules.events.Rules.active_choices(context.catalog, event.descriptor.content_id).has(parts[2]): return {"ok": false, "error": "当前没有此行动"}
		if event.descriptor.content_id == "EVENT_06" and parts[2] == "B": output.append(_field("qualification", "撤回的记忆资格", _options(event.descriptor.facts.get("qualifications", []).filter(func(id: String) -> bool: return _known(context, id)))))
		return {"ok": true, "fields": output}
	if phase != "actions": return {"ok": false, "error": "当前没有此行动"}
	if entry.begins_with("POWER_"):
		if not context.modules.has("powers") or (not context.catalog.tables.powers.has(entry) and not entry in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]): return {"ok": false, "error": "当前没有此行动"}
		if entry in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"] and context.world.power_system.manifest.is_empty(): return {"ok": false, "error": "当前没有此行动"}
		output = _power_fields(context, entry, selection)
	elif parts[0] == "route" and parts.size() == 2:
		if not context.modules.has("progression_routes"): return {"ok": false, "error": "当前没有此行动"}
		output = _route_fields(context, selection)
	elif parts[0] == "prayer" and parts.size() == 3:
		if not context.modules.has("prayers") or not parts[1] in context.world.prayer_system.offered or not parts[2] in ["shallow", "deep"]: return {"ok": false, "error": "当前没有此行动"}
		var request: Dictionary = context.world.prayer_system.requests.get(parts[1], {})
		if request.is_empty() or not context.knowledge.known_prayers.has(parts[1]): return {"ok": false, "error": "当前没有此行动"}
		var descriptor: Dictionary = request.get("descriptor", {})
		var npc: String = str(descriptor.get("subjects", {}).get("petitioner", request.card.actors[0]))
		output.append(_field("preparations", "谕言准备", _preparations(context, npc, "PRAYER/" + parts[1] + "/" + parts[2]), true, true))
		var agents: Array = []; var authorizations: Array = []
		for source: String in _kind(context, "message"):
			var fact: Dictionary = _fact(context, source)
			if fact.get("kind") != "message" or not descriptor.get("source", request.card.fact) in fact.causal_parents: continue
			for person: String in fact.targets:
				if context.knowledge.known_people.has(person) and Store.entry(context.world.npcs, person, {}).get("bound_member", false):
					if not person in agents: agents.append(person)
					authorizations.append(source)
		output.append(_field("agent", "受托回应者", _options(agents), true))
		output.append(_field("agent_source", "实际委托", _options(authorizations), true))
	elif parts[0] == "relic" and parts.size() == 2 and parts[1] in ["equip", "unequip", "unbind", "recover", "disassemble"]:
		output = _base_fields(context, selection, parts[1] in ["equip", "recover"])
		var domain: String = str(_selected(selection, "domain", output[0].options))
		output.append(_field("relic", "圣物", _options(_objects(context, "relics", domain))))
		output.append(_field("source", "当前来源", _source_options(context, domain, "", "relic_recover_authorized" if parts[1] == "recover" else "")))
		if parts[1] == "disassemble": output.append(_field("mode", "分解所求", [_choice("faith", "信仰"), _choice("insight", "洞见"), _choice("followers", "信众"), _choice("whispers", "低语")]))
	elif parts[0] == "opportunity" and parts.size() == 3 and parts[2] in ["recover", "public", "wait"]:
		if not _known(context, parts[1]) or not parts[1] in context.world.anchor_system.opportunities.values(): return {"ok": false, "error": "当前没有此行动"}
		var fact: Dictionary = _fact(context, parts[1])
		if parts[2] == "recover": output.append(_field("npc", "实际携带者（有教团库存时可不选）", _options(_local(context, fact.domain)), true))
	elif entry == "cults/transfer_material":
		if not context.modules.has("cults"): return {"ok": false, "error": "当前没有此行动"}
		if ["source", "sender", "recipient", "target_institution", "grant"].all(func(field: String) -> bool: return selection.get(field) is String and not str(selection[field]).is_empty()):
			# Resolve only the supplied transfer, not the full person/material product.
			if not _known(context, str(selection.get("source", ""))) or not selection.get("sender", "") in _current_people(context) or not selection.get("recipient", "") in _current_people(context) or not _identity_known(context, str(selection.get("target_institution", ""))): return {"ok": false, "error": "缺少或已失效：交予记录"}
			var source: String = str(selection.source)
			var source_fact: Dictionary = _fact(context, source)
			if not context.knowledge.known_domains.has(str(source_fact.get("domain", ""))) or not source in context.reader.anchor_material_heads(source_fact.domain, context.catalog.integer("collective_required_witnesses")): return {"ok": false, "error": "缺少或已失效：交予记录"}
			var material: Dictionary = Materials.resolve(context.world, source, context.catalog, context.reader)
			if not material.get("ok", false) or not _known(context, material.source): return {"ok": false, "error": "缺少或已失效：交予记录"}
			var grant: String = "custody" if material.row.custody == "1" else "knowledge"
			if selection.get("grant") != grant: return {"ok": false, "error": "缺少或已失效：取得内容"}
			output = _transfer_fields(context, [selection], selection)
		else: output = _transfer_fields(context, transfer_options(context), selection)
	elif parts[0] == "attention" and parts.size() == 2 and parts[1] in ["focus", "release_focus", "enroll", "leave", "release_project"]:
		if parts[1] in ["focus", "release_focus"]:
			var domains: Dictionary = context.knowledge.known_domains.duplicate(); domains.merge(context.knowledge.request_domains)
			var ids: Array = domains.keys(); ids.sort(); output.append(_field("domain", "时空", _options(ids)))
		elif parts[1] == "release_project": output.append(_field("token", "持有的预留", _options(context.world.attention.reservations.keys().filter(func(token: String) -> bool: return context.world.attention.reservations[token].get("owner") != "prayers"))))
		else:
			output.append(_field("npc", "人物", _options(_keys(context, "known_people"))))
			output.append(_field("source", "实际身份来源", _source_options(context, "", "", "member_dedication" if parts[1] == "enroll" else "member_leave_authorized")))
	else: return {"ok": false, "error": "当前没有此行动"}
	return {"ok": true, "fields": output}

static func select(fields_value: Array, selection: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	for field: Dictionary in fields_value:
		var value: Variant = selection.get(field.key, [] if field.multiple else ("" if field.optional else _selected(selection, field.key, field.options)))
		if field.optional and ((value is String and value.is_empty()) or (value is Array and value.is_empty())): continue
		var values: Array = value if field.multiple and value is Array else [value]
		if field.multiple and not value is Array: return {"ok": false, "error": "请选择有效的" + field.label}
		for item: Variant in values:
			if not field.options.any(func(option: Dictionary) -> bool: return option.id == item): return {"ok": false, "error": "缺少或已失效：" + field.label}
		payload[field.key] = value
	return {"ok": true, "payload": payload}

static func transfer_options(context: Dictionary) -> Array:
	var result: Array = []
	if not context.modules.has("cults") or context.turn.get("phase") != "actions": return result
	var sources: Dictionary = {}
	for domain: String in context.knowledge.known_domains:
		for id: String in context.reader.anchor_material_heads(domain, context.catalog.integer("collective_required_witnesses")):
			if _known(context, id): sources[id] = true
	var people: Array = _current_people(context)
	for id: String in sources:
		var resolved: Dictionary = Materials.resolve(context.world, id, context.catalog, context.reader)
		if not resolved.get("ok", false) or not _known(context, resolved.source): continue
		var grants: Array = ["custody"] if resolved.row.custody == "1" else ["knowledge"]
		for recipient: String in people:
			var person: Dictionary = Store.entry(context.world.npcs, recipient)
			if not _identity_known(context, str(person.get("institution", ""))): continue
			for sender: String in people:
				for grant: String in grants:
					var request: Dictionary = {"sender": sender, "recipient": recipient, "source": resolved.source, "target_institution": person.institution, "grant": grant}
					if Materials.preview(context.world, request, context.catalog, context.reader).get("ok", false) and not request in result: result.append(request)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a, "", true, true) < JSON.stringify(b, "", true, true))
	return result
