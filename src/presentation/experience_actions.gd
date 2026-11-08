extends RefCounted
## The workbench keeps only input drafts. Rules, selectors and payment stay in Session.
const Requirements = preload("res://src/presentation/gameplay_requirements.gd")
const RequirementList = preload("res://src/presentation/ui/requirement_list.gd")
const OUTCOMES: Array[String] = ["deep", "success", "failure", "disaster"]
const OUTCOME_NAMES: Dictionary = {"deep": "深刻成功", "success": "成功", "failure": "失败", "disaster": "灾变"}
const RecordText = preload("res://src/presentation/player_record_text.gd")
var _source_cache: Dictionary = {}

const Semantics = preload("res://src/presentation/experience_semantics.gd")
var semantics: RefCounted = Semantics.new()
var bestow_view: RefCounted = preload("res://src/presentation/production/bestow_view.gd").new()
var action_workbench: RefCounted = preload("res://src/presentation/production/action_workbench.gd").new()

func resolve_row(host, key: String, selection: Dictionary) -> Dictionary:
	return host.session.action_entry(key, selection)

func render(host, box: VBoxContainer, footer: Container = null, production := false, current_row: Dictionary = {}) -> void:
	_source_cache.clear()
	var controls: Container = footer if footer != null else box
	if host.draft.is_empty():
		return
	var key: String = str(host.draft.get("key", ""))
	var selection: Dictionary = host.draft.get("selection", {})
	var definition: Dictionary = host.session.catalog.display_tables.powers.get(key, {})
	if not definition.is_empty() and int(host.projection.get("awakening", 0)) < int(definition.unlock_awakening):
		box.add_child(host.label(str(definition.name), true))
		RequirementList.render(box, [Requirements.group("权能解锁", [Requirements.quantity("awakening", "苏醒", int(host.projection.get("awakening", 0)), int(definition.unlock_awakening))])], _large(host))
		_render_power_description(host, box, definition)
		return
	var row: Dictionary = decision_row(host, current_row if not current_row.is_empty() else resolve_row(host, key, selection), selection)
	if row.is_empty():
		_render_unavailable(host, box, key)
		return
	if production and host.show_invalid_selection(box, row, selection): return
	# The engine can infer the first candidate; the UI deliberately does not.
	# Only a unique, mandatory candidate is filled without an explicit selection.
	for pass_number: int in range(4):
		var changed: bool = _normalize_unique(row.get("fields", []), selection)
		if not changed: break
		host.draft["review"] = false
		row = decision_row(host, resolve_row(host, key, selection), selection)
		if row.is_empty(): break
	host.draft["selection"] = selection
	if row.is_empty():
		_render_unavailable(host, box, key)
		return
	var prayer: bool = key.begins_with("prayer/")
	var details: Dictionary = row.get("details", {})
	if not production: box.add_child(host.label(str(details.get("当前诉求", row.title)) if prayer else str(row.title), true))
	var preview: Dictionary = row.get("preview", {})
	var costs: Dictionary = preview.get("preview", {})
	var fields: Array = row.get("fields", [])
	var missing: Array[String] = _missing_fields(fields, selection)
	if production: host._current_fields = fields
	if production and key == "POWER_BESTOW":
		bestow_view.render(host, box, controls, row, selection, self)
		return
	if production and not key.begins_with("prayer/") and not key.begins_with("event/"):
		action_workbench.render(host, box, controls, row, selection, self)
		return
	if not missing.is_empty():
		var choices_needed: Array[String] = []
		var unavailable: Array[String] = []
		for field: Dictionary in fields:
			if field.get("optional", false) or _has_value(selection.get(field.key)): continue
			var field_name: String = str(field.label).replace("时空", "世界")
			if field.get("options", []).is_empty(): unavailable.append(field_name)
			else: choices_needed.append(field_name)
		if not choices_needed.is_empty(): box.add_child(host.label("请先选择：" + "、".join(choices_needed)))
		else: box.add_child(host.label("当前不可用 · 暂无符合条件的" + "、".join(unavailable)))
	elif not preview.get("ok", false):
		box.add_child(host.label("当前不可用 · " + host.session.explain_error(str(preview.get("error", "条件尚未满足")))))
	for line: String in context_lines(row, selection, host.title, host): box.add_child(host.label(line))
	if prayer: _render_prayer_choices(host, box, key, selection)
	_render_preparation(host, box, row, selection)
	if missing.is_empty():
		_render_consequences(host, box, row, selection)
		if preview.get("ok", false): _render_payment(host, box, row)
	if preview.get("ok", false) and missing.is_empty():
		controls.add_child(host.label("消耗 %s 低语 · %s 信仰%s" % [costs.get("whispers", 0), costs.get("faith", costs.get("faith_cost", 0)), " · 本轮唯一回应机会" if prayer else ""]))
		var irreversible: String = _irreversible_summary(host, row, selection)
		if not irreversible.is_empty(): (box if production else controls).add_child(host.label(irreversible))
	var submitted_key: String = key
	var submitted_selection: Dictionary = selection.duplicate(true)
	var title_value: String = ("以浅触回应" if key.ends_with("/shallow") else "以深应回应") if prayer else "执行 · " + str(row.title)
	if preview.get("irreversible", false) or key == "POWER_MANIFEST_CANCEL": title_value += "…"
	var execute: Button = host.button(title_value, func() -> void:
		host.run_action(submitted_key, submitted_selection))
	execute.name = "ExecuteDraft"
	execute.disabled = not preview.get("ok", false) or not missing.is_empty() or host.projection.get("terminal", false)
	controls.add_child(execute)

func _render_prayer_choices(host, box: VBoxContainer, key: String, selection: Dictionary) -> void:
	var parts: PackedStringArray = key.split("/")
	var choices := HBoxContainer.new()
	box.add_child(choices)
	for variant: String in ["shallow", "deep"]:
		var next_key: String = "prayer/" + parts[1] + "/" + variant
		var selected: bool = variant == parts[2]
		var choice: Button = host.button(("✓ " if selected else "") + ("浅触" if variant == "shallow" else "深应"), func() -> void:
			host.draft["key"] = next_key
			host.draft["selection"] = selection.duplicate(true)
			host.draft["scroll"] = 0
			host.render_workbench())
		choice.name = "PrayerChoice_" + variant
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(choice)

func context_lines(row: Dictionary, selection: Dictionary = {}, title_for: Callable = Callable(), context_host = null) -> Array[String]:
	var details: Dictionary = row.get("details", {})
	var identities: Array[String] = []
	var places: Array[String] = []
	var deadlines: Array[String] = []
	var seen: Array[String] = []
	# ActionCatalog has already applied knowledge boundaries. Only explicit
	# player identities are displayed here, never its provenance/debug fields.
	for key: String in ["祈求人", "濒死亲属", "对手", "追查者", "第二见证者", "契约另一方", "记忆持有人", "争端另一方", "原圣物", "关联机构", "幸存者", "见证者", "原祭司", "契约承担者", "继任者", "合作者", "合作机构", "接收者", "接收机构", "交予记录", "固定仪式主体", "当前参加者", "原记录"]:
		if not details.has(key): continue
		var value: Variant = details[key]
		var text: String = "、".join(value) if value is Array else str(value)
		if context_host != null: text = readable_reference(context_host, text)
		if text.is_empty() or text in seen: continue
		seen.append(text)
		identities.append(("求告者" if key == "祈求人" else key) + "：" + text)
	for field: Dictionary in row.get("fields", []):
		if row.get("key") == "POWER_LISTEN" and field.key == "source":
			for option: Dictionary in field.get("options", []):
				var source_label: String = str(option.get("label", ""))
				if option.id == selection.get("source") and source_label.begins_with("聆听世界态势 · "):
					identities.append("世界态势来源：" + source_label.trim_prefix("聆听世界态势 · "))
		if not str(field.key) in ["npc", "other", "participants", "witness", "escort", "relic", "record", "second_record", "institution", "cult", "anchor", "domain", "target_domain", "cosmic_anchor", "system_anchor"]: continue
		var selected: Variant = selection.get(field.key)
		var values: Array = selected if selected is Array else [selected]
		var labels: Array[String] = []
		for option: Dictionary in field.get("options", []):
			if not option.id in values: continue
			var label_value: String = _option_title(context_host, option) if context_host != null else (str(title_for.call(str(option.id))) if title_for.is_valid() else str(option.get("label", "")))
			if label_value.is_empty() or label_value == str(option.id) or label_value in seen: continue
			seen.append(label_value); labels.append(label_value)
		if not labels.is_empty(): identities.append(str(field.label).replace("时空", "世界") + "：" + "、".join(labels))
	for key: String in ["所在时空", "所在机构"]:
		if details.has(key) and not str(details[key]) in seen: places.append(str(details[key]))
	for key: String in ["请求期限", "事件期限", "原请求期限", "原危机期限"]:
		if details.has(key): deadlines.append(key + "：" + str(details[key]))
	var lines: Array[String] = []
	if details.has("已付仪式轮次"):
		for key: String in ["固定宇宙锚点", "固定星系锚点"]:
			var id: String = str(details.get(key, ""))
			if not id.is_empty(): lines.append(key + "：" + (str(title_for.call(id)) if title_for.is_valid() else id))
	for index: int in range(0, identities.size(), 2): lines.append(" · ".join(identities.slice(index, index + 2)))
	if not places.is_empty(): lines.append(" · ".join(places))
	if details.has("原事件"): lines.append(str(details["原事件"]))
	if not deadlines.is_empty(): lines.append(" · ".join(deadlines))
	return lines

func _render_preparation(host, box: VBoxContainer, row: Dictionary, selection: Dictionary) -> void:
	var fields: Array = row.get("fields", [])
	var optional_count: int = fields.filter(func(field: Dictionary) -> bool: return field.get("optional", false) and not field.get("options", []).is_empty()).size()
	for field: Dictionary in fields:
		if field.get("optional", false) or field.get("options", []).is_empty(): continue
		# A unique provenance record is not a player decision. It is still passed
		# to Session, but its technical identifier does not become a UI field.
		if str(field.key) in ["source", "qualification"] and field.get("options", []).size() == 1:
			render_fixed_evidence(host, box, [field])
			continue
		if str(row.key).begins_with("prayer/") and str(field.key) in ["domain", "npc", "other"] and field.get("options", []).size() == 1: continue
		_render_field(host, box, field, selection)
	if optional_count > 0:
		var expanded: bool = host.draft.get("preparations_open", false)
		if not host.draft.has("preparations_open"):
			for field: Dictionary in fields:
				if field.get("optional", false) and _has_value(selection.get(field.key)): expanded = true
		var toggle: Button = host.button(("收起" if expanded else "选择") + "协助与准备", func() -> void:
			host.draft["preparations_open"] = not expanded
			host.render_workbench())
		toggle.name = "PreparationsToggle"
		box.add_child(toggle)
		if expanded:
			for field: Dictionary in fields:
				if field.get("optional", false) and not field.get("options", []).is_empty(): _render_field(host, box, field, selection)
	render_activity_progress(host, box, row)

func render_requirements(host, box: VBoxContainer, row: Dictionary, selection: Dictionary) -> void:
	RequirementList.render(box, requirement_groups(host, host.projection, row, selection), _large(host))

func requirement_groups(host, public: Dictionary, row: Dictionary, selection: Dictionary) -> Array:
	return Requirements.action(host.session, public, row, selection, func(text: String) -> String: return readable_reference(host, text))

func _large(host) -> bool:
	if host is RefCounted: return host.host._size(16) > 16
	return host._size(16) > 16 if host.has_method("_size") else false

func render_activity_progress(host, box: VBoxContainer, row: Dictionary) -> void:
	var items: Array = Requirements.activity(row.get("details", {}), func(text: String) -> String: return readable_reference(host, text))
	if not items.is_empty(): RequirementList.render(box, [Requirements.group("实际进展", items)], _large(host))

func _render_unavailable(host, box: VBoxContainer, key: String) -> void:
	var definition: Dictionary = host.session.catalog.display_tables.powers.get(key, {}) if host.session.catalog != null else {}
	box.add_child(host.label(str(definition.get("name", "当前行动")), true))
	var reason: String = "这项行动或请求已经失效"
	if host.projection.get("terminal", false): reason = "本局已结束"
	elif host.projection.get("phase") == "events": reason = "请先处理当前事件"
	elif host.projection.get("phase") != "actions": reason = "当前不是行动阶段"
	box.add_child(host.label("当前不可用 · " + reason))
	if not definition.is_empty():
		_render_power_description(host, box, definition)

func _render_power_description(host, box: VBoxContainer, definition: Dictionary) -> void:
	box.add_child(host.label(str(definition.success)))
	var expanded: bool = host.draft.get("details_open", false)
	var toggle: Button = host.button("收起使用条件" if expanded else "查看使用条件", func() -> void:
		host.draft["details_open"] = not expanded
		host.render_workbench())
	toggle.name = "PowerDetailsToggle"
	box.add_child(toggle)
	if expanded:
		box.add_child(host.label(str(definition.target_requirement)))
		box.add_child(host.label("消耗 %s 低语 · %s 信仰" % [definition.whispers, definition.faith]))

func _normalize_unique(fields: Array, selection: Dictionary) -> bool:
	var changed: bool = false
	for field: Dictionary in fields:
		var options: Array = field.get("options", [])
		var field_key: String = str(field.key)
		if field.get("multiple", false):
			if not selection.has(field_key): continue
			var old: Array = selection[field_key] if selection[field_key] is Array else []
			var kept: Array = old.filter(func(value: Variant) -> bool: return options.any(func(option: Dictionary) -> bool: return typeof(option.id) == typeof(value) and option.id == value))
			if kept != old: selection[field_key] = kept; changed = true
		elif selection.has(field_key) and _has_value(selection[field_key]) and not options.any(func(option: Dictionary) -> bool: return typeof(option.id) == typeof(selection[field_key]) and option.id == selection[field_key]):
			selection.erase(field_key); changed = true
		if not field.get("optional", false) and not field.get("multiple", false) and options.size() == 1 and not _has_value(selection.get(field_key)):
			selection[field_key] = options[0].id; changed = true
	return changed

func _has_value(value: Variant) -> bool:
	return value != null and not (value is String and value.is_empty()) and not (value is Array and value.is_empty())

func _missing_fields(fields: Array, selection: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for field: Dictionary in fields:
		if not field.get("optional", false) and not _has_value(selection.get(field.key)): result.append(str(field.label).replace("时空", "世界"))
	return result

func _render_field(host, box: VBoxContainer, field: Dictionary, selection: Dictionary) -> void:
	if host.has_method("render_selector"):
		host.render_selector(box, field, selection)
		return
	var key: String = str(field.key)
	box.add_child(host.label(str(field.label).replace("时空", "世界")))
	var options: Array = field.get("options", [])
	if options.is_empty():
		box.add_child(host.label("暂无符合条件的已知对象。" if not field.get("optional", false) else "当前没有此类可用准备。"))
		return
	if field.get("multiple", false):
		var scroller := ScrollContainer.new()
		scroller.custom_minimum_size.y = minf(170.0, 36.0 * options.size())
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var choices := VBoxContainer.new(); choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.add_child(choices); box.add_child(scroller)
		for option: Dictionary in options:
			var id: Variant = option.id
			var check := CheckBox.new(); check.text = _option_title(host, option); check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			check.name = "Field_" + key + "_" + str(choices.get_child_count())
			check.set_pressed_no_signal(id in selection.get(key, [])); choices.add_child(check)
			check.toggled.connect(func(on: bool) -> void:
				var values: Array = host.draft.selection.get(key, []).duplicate()
				if on and not id in values: values.append(id)
				elif not on: values.erase(id)
				host.draft.selection[key] = values
				host.draft["review"] = false
				host.render_workbench())
	else:
		var picker := OptionButton.new(); picker.name = "Field_" + key
		picker.custom_minimum_size = Vector2(120, 36); picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; picker.clip_text = true; picker.fit_to_longest_item = false
		picker.add_item("不用" if field.get("optional", false) else "请选择"); picker.set_item_metadata(0, "")
		for option: Dictionary in options:
			picker.add_item(_option_title(host, option)); var index: int = picker.item_count - 1; picker.set_item_metadata(index, option.id)
			if selection.get(key) == option.id: picker.select(index)
		picker.item_selected.connect(func(index: int) -> void:
			var value: Variant = picker.get_item_metadata(index)
			if value is String and value.is_empty(): host.draft.selection.erase(key)
			else: host.draft.selection[key] = value
			host.draft["review"] = false
			if key == "domain":
				for child: String in ["npc", "source", "cult", "anchor", "relic", "institution", "qualification", "other", "participants", "operation", "record", "second_record", "target", "preparations", "preparation_relic"]: host.draft.selection.erase(child)
			elif key == "npc":
				for child: String in ["source", "other", "participants", "operation", "record", "second_record", "target", "preparations", "preparation_relic"]: host.draft.selection.erase(child)
			elif key == "operation":
				for child: String in ["source", "other", "participants", "record", "second_record", "target", "stage"]: host.draft.selection.erase(child)
			host.render_workbench())
		box.add_child(picker)

func _option_title(host, option: Dictionary) -> String:
	var id: String = str(option.id)
	if id.begins_with("ROUTE_"):
		return str(host.session.catalog.display_tables.progression_route_operations.get(id, {}).get("name", option.get("label", "活动")))
	if id.begins_with("FACT-"):
		var record: Dictionary = source_info(host, id)
		if not record.is_empty(): return str(record.title) + " · 第%d轮" % int(record.get("turn", 0))
	if id.begins_with("PRAYER/"):
		var parts: PackedStringArray = id.split("/")
		if parts.size() == 3:
			var request: Dictionary = host.session.prayer_entry(parts[1])
			if not request.is_empty():
				if request.descriptor.get("space", false):
					for choice: Dictionary in host.session.modules.prayers.space_choices(host.session.world.state, parts[1]):
						if choice.id == parts[2]: return host.session.prayer_title(request.descriptor, request.card) + " · " + str(choice.label)
				elif parts[2] in ["shallow", "deep"]: return host.session.prayer_title(request.descriptor, request.card) + (" · 浅触" if parts[2] == "shallow" else " · 深应")
	for collection: String in ["domains", "people", "cults", "relics", "institutions", "anchors"]:
		for object: Dictionary in host.projection.get(collection, []):
			if str(object.id) == id: return RecordText.entity_name(host, id)
	return str(option.get("label", id)).replace("时空", "世界")


func readable_reference(host, text: String) -> String:
	# ActionCatalog currently publishes some source identities as public titles.
	# Resolve only that exact known-record form; never search or reveal parents.
	var id: String = "FACT-" + text.trim_prefix("已知事实 · ") if text.begins_with("已知事实 · ") else text
	if id.begins_with("FACT-"):
		var info: Dictionary = source_info(host, id)
		if not info.is_empty(): return str(info.summary)
	for person: Dictionary in host.projection.get("people", []):
		text = text.replace(str(host.title(person.id)), RecordText.entity_name(host, person.id))
	return text

func decision_row(host, row: Dictionary, selection: Dictionary) -> Dictionary:
	if row.get("key") == "route/context" and host.has_method("activity_actors") and not host.activity_actors().is_empty():
		row = row.duplicate(true)
		for field: Dictionary in row.get("fields", []):
			if field.key == "npc": field.options = field.options.filter(func(option: Dictionary) -> bool: return option.id in host.activity_actors())
	if row.get("key") == "route/context":
		# Route source is a non-consumed local contact, not the material being
		# practiced. Preserve a valid chosen contact; otherwise use known origin.
		row = row.duplicate(true)
		for field: Dictionary in row.get("fields", []):
			if field.key != "source": continue
			var preferred: Array = field.options.filter(func(option: Dictionary) -> bool: return option.id == selection.get("source"))
			if preferred.is_empty(): preferred = field.options.filter(func(option: Dictionary) -> bool: return str(option.get("label", "")).begins_with("初识时空"))
			if not preferred.is_empty(): field.options = [preferred[0]]
		return row
	# Dream qualifications are reusable contact proofs. Once the same person is
	# chosen, duplicates change only the audit parent, never costs, cooldown,
	# target or outcome. Keep a valid remembered proof; do not generalize this
	# reduction to Listen, evidence destruction or any consumable source.
	if row.get("key") != "POWER_DREAM" or str(selection.get("npc", "")).is_empty(): return row
	var result: Dictionary = row.duplicate(true)
	for field: Dictionary in result.get("fields", []):
		if not str(field.key) in ["source", "qualification"] or field.get("optional", false) or field.get("multiple", false) or field.get("options", []).size() < 2: continue
		var identity: Dictionary = {}
		var equivalent := true
		for option: Dictionary in field.options:
			var qualification: Dictionary = source_info(host, str(option.id)).get("qualification", {})
			if qualification.get("rule") != "dream" or qualification.get("actor") != selection.npc or qualification.get("target") != selection.npc:
				equivalent = false; break
			if identity.is_empty(): identity = qualification
			elif identity != qualification: equivalent = false; break
		if not equivalent: continue
		var chosen: Dictionary = field.options[0]
		for option: Dictionary in field.options:
			if option.id == selection.get(field.key): chosen = option; break
		field.options = [chosen]
	return result

func fixed_evidence(field: Dictionary) -> bool:
	return str(field.get("key", "")) in ["source", "qualification"] and not field.get("optional", false) and not field.get("multiple", false) and field.get("options", []).size() == 1

func visible_fields(fields: Array) -> Array:
	return fields.filter(func(field: Dictionary) -> bool: return not fixed_evidence(field) and not (field.get("optional", false) and field.get("options", []).is_empty()))

func source_info(host, id: String) -> Dictionary:
	if _source_cache.has(id): return _source_cache[id]
	var result: Dictionary = {}
	if host.session.is_known_source(id):
		var index: int = host.session.known_sources().find(id)
		if index >= 0:
			var page: Dictionary = host.session.history_page(index, 1)
			if not page.get("facts", []).is_empty():
				var fact: Dictionary = page.facts[0]
				result = RecordText.summarize(host, fact)
				result["turn"] = int(fact.get("turn", 0))
				if fact.get("kind") == "power_qualification":
					var data: Dictionary = fact.get("changes", {})
					result["qualification"] = {"rule":data.get("rule", ""), "actor":data.get("actor", ""), "target":data.get("target", ""), "domain":fact.get("domain", "")}
	_source_cache[id] = result
	return result

func render_fixed_evidence(host, box: VBoxContainer, fields: Array) -> void:
	var seen := {}
	for field: Dictionary in fields:
		if not fixed_evidence(field): continue
		var option: Dictionary = field.options[0]
		var id: String = str(option.id)
		if seen.has(id): continue
		seen[id] = true
		var record: Dictionary = source_info(host, id)
		if record.get("qualification", {}).get("rule") == "dream":
			box.add_child(host.label("可通过已有联系进入梦境；这份联系不会被消耗。"))
		else:
			box.add_child(host.label("行动依据 · " + str(record.get("summary", _option_title(host, option)))))

func action_purpose(row: Dictionary) -> String:
	var key: String = str(row.key)
	return {
		"route/context":"组织当地的合作与实践", "POWER_LISTEN":"查明一条线索背后的事实", "POWER_DREAM":"在梦中影响一位人物",
		"cults/transfer_material":"将记录交予另一位人物",
		"POWER_ORACLE":"为下一次行动传达神谕", "POWER_APPOINT":"安排领袖或锚点护持者",
		"POWER_SACRIFICE":"以献祭换取力量", "POWER_BREACH":"利用弱点削弱世界屏障",
		"POWER_SEED":"通过秘密渠道扩大信众", "POWER_VEIL":"销毁传播证据，掩藏教团踪迹", "POWER_ANCHOR":"建立或修复现实中的锚点",
		"POWER_TRANSFER":"将人物与随行信众迁往另一世界", "POWER_MANIFEST":"借助锚点维持降临仪式",
		"POWER_MANIFEST_CONTINUE":"维持正在进行的降临", "POWER_MANIFEST_CANCEL":"结束正在进行的降临",
		"relic/equip":"让成员携带这件圣物", "relic/unequip":"将圣物交回当地教团",
		"relic/unbind":"解除圣物与锚点的绑定", "relic/recover":"收回这件圣物",
		"relic/disassemble":"消耗圣物，换取所需资源", "attention/focus":"将一个世界纳入持续关注",
		"attention/release_focus":"安排下轮释放世界关注", "attention/enroll":"接纳人物成为正式成员",
		"attention/leave":"让成员离开教团", "attention/release_project":"释放未使用的活动名额"
	}.get(key, str(row.get("details", {}).get("requirement", "选择行动对象与做法")))

func outcome_groups(probabilities: Dictionary, effects: Dictionary) -> Array:
	var result: Array = []
	var combine: bool = not str(effects.get("success", "")).is_empty() and effects.get("deep") == effects.get("success")
	for outcome: String in OUTCOMES:
		if combine and outcome == "deep": continue
		var heading: String = "%s  %s%%" % [OUTCOME_NAMES[outcome], probabilities.get(outcome, 0)]
		if combine and outcome == "success": heading = "成功 %s%%（含深刻成功 %s%%）" % [int(probabilities.get("deep", 0)) + int(probabilities.get("success", 0)), probabilities.get("deep", 0)]
		result.append({"title":heading, "effect":str(effects.get(outcome, ""))})
	return result

func _render_consequences(host, box: VBoxContainer, row: Dictionary, selection: Dictionary) -> void:
	var details: Dictionary = row.get("details", {})
	var preview: Dictionary = row.get("preview", {})
	var costs: Dictionary = preview.get("preview", {})
	var always: String = _always_cost(host, row, selection)
	var effects: Dictionary = _outcome_effects(host, row, selection)
	var probabilities: Dictionary = costs.get("outcomes", {})
	if not always.is_empty() and not always in ["低语和信仰", "低语"]:
		box.add_child(host.label("必付代价：" + always))
	if not probabilities.is_empty():
		var success: int = int(probabilities.get("deep", 0)) + int(probabilities.get("success", 0))
		box.add_child(host.label("成功 %s%% · 失败 %s%% · 灾变 %s%%" % [success, probabilities.get("failure", 0), probabilities.get("disaster", 0)]))
		box.add_child(host.label("成功：" + str(effects.get("summary", effects.get("success", "")))))
		box.add_child(host.label("失败：" + str(effects.get("failure", ""))))
		if int(probabilities.get("disaster", 0)) > 0:
			box.add_child(host.label("灾变：" + str(effects.get("disaster", ""))))
		var expanded: bool = host.draft.get("outcomes_open", false)
		var toggle: Button = host.button("收起详细结果" if expanded else "详细结果（含深刻成功）", func() -> void:
			host.draft["outcomes_open"] = not expanded
			host.render_workbench())
		toggle.name = "OutcomeDetailsToggle"
		box.add_child(toggle)
		if expanded:
			for outcome: String in OUTCOMES:
				box.add_child(host.label("%s %s%%：%s" % [OUTCOME_NAMES[outcome], probabilities.get(outcome, 0), effects.get(outcome, "")]))
	else:
		if row.key in ["POWER_MANIFEST", "POWER_MANIFEST_CONTINUE"]: box.add_child(host.label(str(effects.get("success", ""))))
		else: box.add_child(host.label(str(effects.get("success", details.get("选择后果", "")))))

func _always_cost(host, row: Dictionary, selection: Dictionary) -> String:
	var details: Dictionary = row.get("details", {})
	if str(row.key).begins_with("prayer/"):
		var request: Dictionary = _prayer_context(host, str(row.key))
		return str(semantics.prayer(host.session.catalog, request.content, request.variant).always)
	if row.key != "route/context":
		return str(details.get("always", details.get("始终代价", details.get("不可逆代价", ""))))
	var operation: Dictionary = host.session.catalog.display_tables.progression_route_operations.get(str(selection.get("operation", "")), {})
	var parts: Array[String] = ["参加者本轮行动机会"]
	if int(operation.get("always_alert", 0)) > 0: parts.append("当地察觉 +" + str(operation.always_alert))
	if int(operation.get("always_sanity_loss", 0)) > 0: parts.append("参加者理智 −" + str(operation.always_sanity_loss))
	return "、".join(parts)

func _prayer_context(host, key: String) -> Dictionary:
	var parts: PackedStringArray = key.split("/")
	var entry: Dictionary = host.session.prayer_entry(parts[1])
	return {"content": str(entry.get("card", {}).get("content_id", "")), "variant": parts[2]}

func _irreversible_summary(host, row: Dictionary, selection: Dictionary) -> String:
	var costs: Dictionary = row.get("preview", {}).get("preview", {})
	var warnings: Array[String] = []
	if str(row.key).begins_with("prayer/"):
		var request: Dictionary = _prayer_context(host, str(row.key))
		return str(semantics.prayer(host.session.catalog, request.content, request.variant).warning)
	if row.key == "POWER_MANIFEST_CANCEL": return _manifest_cancel_loss(row)
	if costs.get("consumes", false):
		var id: String = str(selection.get("relic", selection.get("npc", "")))
		warnings.append("将失去：" + host.title(id) if not id.is_empty() else "本次将消耗选中的对象")
	if int(costs.get("awakening_loss", 0)) > 0: warnings.append("苏醒 −" + str(costs.awakening_loss))
	return "；".join(warnings)

func confirmation_text(host, key: String, selection: Dictionary) -> String:
	var row: Dictionary = resolve_row(host, key, selection)
	if row.is_empty(): return "当前行动条件已经改变，请重新选择。"
	var costs: Dictionary = row.get("preview", {}).get("preview", {})
	var lines: Array[String] = [str(row.title)]
	lines.append_array(context_lines(row, selection, host.title, host))
	lines.append("消耗 %s 低语 · %s 信仰" % [costs.get("whispers", 0), costs.get("faith", costs.get("faith_cost", 0))])
	var always: String = _always_cost(host, row, selection)
	if not always.is_empty(): lines.append("必付代价：" + always)
	var irreversible: String = _irreversible_summary(host, row, selection)
	if not irreversible.is_empty(): lines.append(irreversible)
	var effects: Dictionary = _outcome_effects(host, row, selection)
	if not str(effects.get("success", "")).is_empty(): lines.append(("执行后：" if costs.get("outcomes", {}).is_empty() else "成功：") + str(effects.get("summary", effects.success)))
	if key.begins_with("prayer/"): lines.append("无论成功与否，本轮都不能再回应其他祈求。")
	return "\n".join(lines)

func _manifest_cancel_loss(row: Dictionary) -> String:
	return "终止本次降临；已支付的 %s 轮进度不保留，费用不退还。" % row.get("details", {}).get("已付仪式轮次", 0)

func _outcome_effects(host, row: Dictionary, selection: Dictionary) -> Dictionary:
	var details: Dictionary = row.get("details", {})
	var ritual: Dictionary = row.get("preview", {}).get("preview", {})
	if ritual.get("ritual_pending", false):
		return {"success": "支付第 %s / %s 轮仪式费用并保留原主体和两锚点；本轮不作最终判定。须连续维持至第%s轮轮末，届时才决定成败。" % [ritual.ritual_step, ritual.ritual_duration, ritual.ritual_duration]}
	if row.key == "POWER_MANIFEST_CANCEL": return {"success": "结束本次仪式并释放预留，相关公开异常随之结束。"}
	if str(row.key).begins_with("relic/"):
		var result: String = {
			"relic/equip": "交由所选人物携带。",
			"relic/unequip": "从携带者身上卸下，交回当地教团保管。",
			"relic/unbind": "交回当地教团保管；失去媒介的锚点休眠，需要重新绑定。",
			"relic/recover": "收回圣物，交由所选人物携带或当地教团保管。",
			"relic/disassemble": "永久消耗这件圣物。"
		}.get(str(row.key), "")
		if row.key == "relic/disassemble":
			var costs: Dictionary = row.get("preview", {}).get("preview", {})
			var unit: String = {"faith": "信仰", "insight": "洞见", "followers": "信众", "whispers": "低语"}.get(str(selection.get("mode", "")), "")
			if costs.has("net_gain"): result += " 获得 %s %s。" % [costs.net_gain, unit]
		return {"success": result}
	if str(row.key) == "POWER_MANIFEST_CONTINUE":
		var definition: Dictionary = host.session.catalog.display_tables.powers.POWER_MANIFEST
		return {"deep": definition.deep_success, "success": definition.success, "failure": definition.failure, "disaster": definition.disaster}
	if str(row.key).begins_with("POWER_") and details.has("success"):
		return {"deep": details.get("deep", details.success), "success": details.success, "failure": details.get("failure", ""), "disaster": details.get("disaster", "")}
	if str(row.key).begins_with("prayer/"):
		var request: Dictionary = _prayer_context(host, str(row.key))
		return semantics.prayer(host.session.catalog, request.content, request.variant)
	if str(row.key) == "route/context":
		var operation: Dictionary = host.session.catalog.display_tables.progression_route_operations.get(str(selection.get("operation", "")), {})
		var success: String = "完成当前实际活动，按原参加者与记录推进本轮进展。"
		if operation.get("mode") == "private_devotion": success = "当前知晓且自愿的人物实际献身，按原资格接纳为成员并留下持续联系。"
		elif operation.get("mode") == "joint_work": success = "两位参加者完成结伴协作，建立当前合作联系。"
		elif operation.get("mode") in ["covert_gathering", "calendar_rite"]:
			var parameter: String = "gathering_followers" if operation.mode == "covert_gathering" else "rite_followers"
			success = "从当地可接触人群转化至多 %d 名信众；首个教团仍在轮末核验形成。" % host.session.catalog.integer(parameter)
		elif operation.get("mode") in ["memory_circle", "pact_agreement"]: success = "建立本次共同情境或原约定；之后从相应祈求回应，不立即完成其后续结果。"
		elif operation.get("mode") == "axiom_probe": success = "记录本次观察到的法则例外，为后续验证和利用留下依据。"
		elif operation.get("mode") == "axiom_recheck": success = "在另一节点独立核验同一异常，取得第二份观察记录。"
		elif operation.get("mode") == "network_exchange": success = "完成两端的实际共同使用，建立两处机构之间的持续依托。"
		elif operation.get("mode") in ["axiom_repeat", "record_practice", "calendar_keeping", "memory_practice", "dissent_practice"]:
			var practice: String = {"axiom_repeat":"再次使用同一异常", "record_practice":"使用同一组档案", "calendar_keeping":"依照超常节拍记录", "memory_practice":"共同再现同一段记忆", "dissent_practice":"共同保留相斥的记忆视角"}[operation.mode]
			success = practice + "，计入一次成功实践；达到所需的不同回合次数后形成持续依托。"
		elif operation.get("mode") == "ritual_transmission": success = "按当前步骤完成教习或原学徒施行；另一回合的步骤仍须原人物完成。"
		elif operation.get("mode") == "reciprocal_covenant": success = "固定原两项约定或完成当前一项交付；剩余交付仍受原条款约束。"
		if int(operation.get("success_pollution", 0)) > 0: success += " 当地污染 +" + str(operation.success_pollution) + "。"
		return {"deep": success, "success": success, "failure": "本轮未取得成功进展；资源、执行机会及该活动必付后果仍消耗。", "disaster": "本轮未取得成功进展；资源、执行机会及该活动必付后果仍消耗。"}
	return {"success": str(details.get("选择后果", details.get("取得内容", "按所选处置更新原对象，实际结果进入编年史。")))}

func payment_projection(host, row: Dictionary) -> Dictionary:
	var action_preview: Dictionary = row.get("preview", {})
	if not action_preview.get("ok", false) or host.session.turn == null: return {"ok": false}
	var costs: Dictionary = action_preview.get("preview", {})
	var fee: int = int(costs.get("faith", costs.get("faith_cost", 0)))
	var view: Dictionary = host.session.turn._read_view("economy", "prepay")
	var state: Dictionary = view.world.duplicate(false)
	var plan: Dictionary = host.session.turn.context.plans.get("economy", {}).duplicate(true)
	var before: Dictionary = host.session.modules.economy.preview(view.world, plan, view.reader)
	state["faith"] = maxi(0, int(state.faith) - fee)
	var after: Dictionary = host.session.modules.economy.preview(state, plan, view.reader)
	view.reader.close()
	if not before.get("ok", false) or not after.get("ok", false): return {"ok": false, "error": host.session.explain_error(str(after.get("error", before.get("error", "当前无法预览供奉"))))}
	var known_cults: Dictionary = {}; var known_anchors: Dictionary = {}; var contributions: Dictionary = {}
	for object: Dictionary in host.projection.get("cults", []): known_cults[object.id] = object
	for object: Dictionary in host.projection.get("anchors", []): known_anchors[object.id] = object
	for source: Dictionary in host.projection.get("awakening_sources", []):
		if source.get("kind") == "anchor" and known_anchors.has(source.get("title")): contributions[source.title] = int(source.value)
	var changes: Array = []; var lost: int = 0
	for cult_after: Dictionary in after.preview.get("cults", []):
		if not known_cults.has(cult_after.cult): continue
		for cult_before: Dictionary in before.preview.get("cults", []):
			if cult_before.cult == cult_after.cult and (cult_before.fee != cult_after.fee or cult_before.effective != cult_after.effective):
				changes.append({"kind": "cult", "id": cult_after.cult, "before": cult_before.effective, "after": cult_after.effective, "reason": cult_after.reason})
	for anchor_after: Dictionary in after.preview.get("anchors", []):
		if not known_anchors.has(anchor_after.anchor): continue
		for anchor_before: Dictionary in before.preview.get("anchors", []):
			if anchor_before.anchor == anchor_after.anchor and anchor_before.expected != anchor_after.expected:
				var contribution: int = int(contributions.get(anchor_after.anchor, 0)) if anchor_after.expected == "dormant" else 0
				lost += contribution
				changes.append({"kind": "anchor", "id": anchor_after.anchor, "before": anchor_before.expected, "after": anchor_after.expected, "reason": anchor_after.reason, "awakening_loss": contribution})
	return host.session._public({"ok": true, "faith_before": int(host.projection.get("faith", 0)), "fee": fee, "faith_after_action": state.faith, "faith_after_prepay": after.preview.faith_after_prepay, "changes": changes, "additional_awakening_loss": lost})

func _render_payment(host, box: VBoxContainer, row: Dictionary) -> void:
	var projection: Dictionary = payment_projection(host, row)
	if not projection.get("ok", false):
		box.add_child(host.label("本次付款对维持费用的影响暂时无法计算。"))
		return
	if int(projection.fee) == 0 and projection.changes.is_empty(): return
	box.add_child(host.label("行动后剩余信仰 %s（未计行动收益）" % projection.faith_after_action))
	var maintenance: int = int(projection.faith_after_action) - int(projection.faith_after_prepay)
	if maintenance > 0:
		box.add_child(host.label("按现有安排，轮末传教与锚点维护还将支付 %s。" % maintenance))
	for change: Dictionary in projection.changes:
		var summary: String = "将付不起传教费用，本轮改为守持" if change.kind == "cult" else "将付不起维护费用，本轮休眠"
		if int(change.get("awakening_loss", 0)) > 0: summary += "；苏醒 −" + str(change.awakening_loss)
		box.add_child(host.label(host.title(str(change.id)) + "：" + summary))
	if not projection.changes.is_empty():
		box.add_child(host.button("调整本轮支出", func() -> void: host.show_subject("budget")))
