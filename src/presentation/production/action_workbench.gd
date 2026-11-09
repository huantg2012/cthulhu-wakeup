extends RefCounted
## General production action configuration: decisions are the original fields,
## eligibility and execution remain the existing Session and TaskView paths.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const CONDITIONS := "__requirements"
const OUTCOME := "__outcomes"

func render(task, box: VBoxContainer, footer: Container, row: Dictionary, selection: Dictionary, actions) -> void:
	var host: Control = task.host
	var fields: Array = row.get("fields", [])
	var missing: Array = actions._missing_fields(fields, selection)
	var preview: Dictionary = row.get("preview", {})
	var tabs: Array = []
	for field: Dictionary in actions.visible_fields(fields):
		if task.draft.get("fixed_anchor", false) and field.key in ["domain", "institution", "source"]: continue
		if task.draft.get("fixed_activity", false) and field.key == "domain": continue
		if not str(task.draft.get("activity_person", "")).is_empty() and field.key == "npc": continue
		tabs.append(str(field.key))
	if task.draft.get("fixed_anchor", false) and "npc" in tabs:
		tabs.erase("npc")
		tabs.push_front("npc")
	tabs.append(CONDITIONS)
	tabs.append(OUTCOME)
	var tab: String = str(task.draft.get("config_tab", tabs[0]))
	if not tab in tabs: tab = tabs[0]
	var key: String = str(row.key)
	var note: String = "选择本次行动的对象，查看条件与代价。"
	if key == "route/context":
		var operation: Dictionary = task.session.catalog.display_tables.progression_route_operations.get(selection.get("operation", ""), {})
		note = str(operation.get("description", "先选要促成的活动，再安排参加者。"))
	elif task.draft.get("fixed_anchor", false):
		note = "确认后在所选机构施展锚定。" if missing.is_empty() else "选择护持者和绑定圣物。"
	if key in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]:
		note = "维持原主体与固定锚点 · 仅实际付款推进仪式"
	if missing.is_empty() and not preview.get("ok", false): note = task.session.explain_error(str(preview.get("error", "条件尚未满足")))
	var layout: Dictionary = host._interaction.action_layout(task, box, row, selection, actions, note)
	var nav: VBoxContainer = layout.nav
	var reading: VBoxContainer = layout.costs
	if key == "route/context" and row.details.has("最近行动回合"):
		host._line(reading, "已知进展 · 第 %s 轮" % row.details["最近行动回合"], 16, UI.CYAN).name = "ActivityProgress"
		for item: Dictionary in actions.Requirements.activity(row.details):
			var value: String = "%s / %s" % [item.current, item.required] if item.has("current") else str(item.get("value", ""))
			if not value.is_empty(): host._line(reading, "%s  %s" % [item.title, value], 14)
	var compare := key == "POWER_ANCHOR" and tab in ["npc", "relic"]
	var pane: Control = host._interaction.candidate_layer(layout.canvas, bool(task.draft.get("picker_open", false)), task.close_picker, compare)
	var list: ScrollContainer = host._scroller(pane, Rect2(33, 91, 1082, 277) if compare else Rect2(20, 63, 512, 246))
	list.name = "ActionOptionsScroll"
	host._scroll_cue(list, pane, Rect2(33, 368, 1082, 14) if compare else Rect2(20, 309, 512, 16))
	for field_id: String in tabs:
		var field: Dictionary = _field(fields, field_id)
		var caption: String = ("结果预览" if field_id == OUTCOME else ("条件与进展" if field_id == CONDITIONS else _field_label(task, field))) + " · " + _summary(task, field, selection, preview, field_id, actions)
		var button: Button = task.button(caption, _switch.bind(task, field_id, tab, list))
		button.name = "ActionTab_" + field_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", host._size(14))
		button.clip_text = true
		button.tooltip_text = caption
		button.custom_minimum_size.y = 43
		host._ui.choice_style(button, false)
		if field_id == tab:
			host._ui.choice_style(button, true)
		if field_id in [CONDITIONS, OUTCOME]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reading.add_child(button)
		else: nav.add_child(button)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	host._ui.rect(header, Rect2(20, 13, 464, 45))
	pane.add_child(header)
	var field: Dictionary = _field(fields, tab)
	var title: Label = host._line(header, "本次结果" if tab == OUTCOME else ("条件与进展" if tab == CONDITIONS else "选择" + _field_label(task, field)), 18, UI.GOLD_HI)
	title.name = "ActionListTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = title.text
	var selected: Variant = selection.get(tab, "")
	var kind: String = _subject_kind(task, tab, selected)
	if not kind.is_empty() and kind != "fact":
		var read: Button = task.button("查阅资料", task.show_subject.bind(kind, str(selected)))
		read.name = "Read_" + tab
		read.autowrap_mode = TextServer.AUTOWRAP_OFF
		read.custom_minimum_size.x = 110
		header.add_child(read)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	list.add_child(rows)
	if tab == CONDITIONS:
		actions.render_requirements(task, rows, row, selection)
		if rows.get_child_count() == 0: rows.add_child(task.label("当前没有额外的材料或跨轮进度要求。"))
	elif tab == OUTCOME:
		var context: Dictionary = row.duplicate()
		context.fields = [] # Selected configurable objects already remain in the navigation.
		for line: String in actions.context_lines(context, selection, task.title, task): rows.add_child(task.label(line))
		actions.render_fixed_evidence(task, rows, fields)
		if not missing.is_empty(): rows.add_child(task.label("请先选择：" + "、".join(missing)))
		elif not preview.get("ok", false): rows.add_child(task.label("当前不可用 · " + task.session.explain_error(str(preview.get("error", "条件尚未满足")))))
		if missing.is_empty():
			var probabilities: Dictionary = preview.get("preview", {}).get("outcomes", {})
			if probabilities.is_empty(): actions._render_consequences(task, rows, row, selection)
			else:
				var always: String = actions._always_cost(task, row, selection)
				if not always.is_empty() and not always in ["低语", "低语和信仰"]: rows.add_child(task.label("必付代价：" + always))
				var effects: Dictionary = actions._outcome_effects(task, row, selection)
				for outcome: Dictionary in actions.outcome_groups(probabilities, effects):
					rows.add_child(task.label(outcome.title, true))
					rows.add_child(task.label(actions.bestow_view._format_effect(outcome.effect)))
			if preview.get("ok", false): actions._render_payment(task, rows, row)
		var irreversible: String = actions._irreversible_summary(task, row, selection)
		if not irreversible.is_empty(): rows.add_child(task.label(irreversible))
	elif field.get("options", []).is_empty():
		rows.add_child(task.label("当地暂无可交予的记录或合格接收人。交予者须实际掌握记录，双方须存在可用联系。" if key == "cults/transfer_material" else "当前没有符合条件的候选。"))
	elif tab == "escort" and _numeric(field.options):
		_number(task, rows, list, tab, field, selection)
	elif compare:
		_anchor_candidates(task, rows, list, field, selection, actions)
	else:
		if field.get("optional", false) and not field.get("multiple", false):
			var clear: Button = task.button("不使用此项", _choose.bind(task, tab, list, field, "", selection))
			clear.name = "Clear_" + tab
			rows.add_child(clear)
		for i: int in field.options.size():
			_option(task, rows, list, tab, field, selection, field.options[i], i, actions)
	var evidence: String = str(selection.get("source", ""))
	if not evidence.is_empty() and tab in ["source", OUTCOME]:
		var explanation: Dictionary = actions.source_info(task, evidence)
		if not explanation.is_empty(): rows.add_child(task.label(str(explanation.summary)))
	var offsets: Dictionary = task.draft.get("config_scroll", {})
	if offsets.has(tab): list.set_deferred("scroll_vertical", int(offsets[tab]))
	elif not kind.is_empty():
		for i: int in field.get("options", []).size():
			if field.options[i].id == selected:
				var card: Control = rows.find_child("Choice_%s_%d" % [tab, i], true, false)
				if is_instance_valid(card): list.call_deferred("ensure_control_visible", card)
				break
	if preview.get("ok", false) and missing.is_empty():
		var costs: Dictionary = preview.get("preview", {})
		var summary: String = "%s 低语 · %s 信仰" % [costs.get("whispers", 0), costs.get("faith", costs.get("faith_cost", 0))]
		footer.add_child(task.label(summary))
	var choice: Dictionary = selection.duplicate(true)
	var action_name: String = str(row.title)
	if key == "route/context": action_name = str(row.get("details", {}).get("行动", "开展活动")) if selection.has("operation") else "开展活动"
	var caption: String = ("施展 · " if key.begins_with("POWER_") else "执行 · ") + action_name + ("…" if preview.get("irreversible", false) else "")
	var execute: Button = task.button(caption, func() -> void: task.run_action(key, choice))
	execute.name = "ExecuteDraft"
	execute.disabled = not preview.get("ok", false) or not missing.is_empty() or task.projection.get("terminal", false)
	footer.add_child(execute)

func _anchor_candidates(task, rows: VBoxContainer, list: ScrollContainer, field: Dictionary, selection: Dictionary, actions) -> void:
	var host: Control = task.host
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 16)
	rows.add_child(grid)
	var kind := "person" if field.key == "npc" else "relic"
	for index: int in field.options.size():
		var option: Dictionary = field.options[index]
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 302
		grid.add_child(column)
		var figure := Control.new()
		figure.custom_minimum_size.y = 90
		column.add_child(figure)
		if kind == "person":
			host._ui.image(figure, "CandidatePortrait", Rect2(106, 0, 90, 90), host._interaction.picture("person_portrait"))
		else:
			host._ui.icon(figure, "CandidateMark", kind, Rect2(106, 0, 90, 90))
		host._line(column, actions._option_title(task, option), 18)
		var data: Dictionary = host._views._find(task, "people" if kind == "person" else "relics", str(option.id))
		if kind == "person" and not data.is_empty(): host._line(column, host._views._role(task, data), 14, UI.MUTED)
		elif kind == "relic" and not data.is_empty(): host._line(column, str(host._views.PLACEMENTS.get(data.get("placement"), "仅有线索")), 14, UI.MUTED)
		var select: Button = task.button("选为护持者" if kind == "person" else "用于这次锚定", _choose.bind(task, field.key, list, field, option.id, selection))
		select.name = "Choice_%s_%d" % [field.key, index]
		column.add_child(select)
		task.guard_choice(select, column, field, option.id, selection)
		var read: Button = task.button("查阅 ↗", task.show_subject.bind(kind, str(option.id)))
		read.name = "AnchorCandidateRead_%s_%d" % [field.key, index]
		column.add_child(read)

func _field(fields: Array, key: String) -> Dictionary:
	for field: Dictionary in fields:
		if str(field.key) == key: return field
	return {}

func _field_label(task, field: Dictionary) -> String:
	var label: String = str(field.label).replace("时空", "世界")
	if task.draft.get("fixed_anchor", false):
		return {"npc":"护持者", "qualification":"锚定材料", "relic":"绑定圣物"}.get(field.key, label)
	return label

func _summary(task, field: Dictionary, selection: Dictionary, preview: Dictionary, key: String, actions) -> String:
	if key == CONDITIONS: return "查看缺口"
	if key == OUTCOME:
		if not preview.get("ok", false): return "待选择"
		var probability: int = int(preview.get("preview", {}).get("probability", -1))
		return "成功 %d%%" % probability if probability >= 0 else "可查看"
	var chosen: Variant = selection.get(key, [] if field.get("multiple", false) else "")
	if chosen is Array: return "已选择 %d 项" % chosen.size() if not chosen.is_empty() else ("未使用" if field.get("optional", false) else "待选择")
	for option: Dictionary in field.get("options", []):
		if typeof(option.id) == typeof(chosen) and option.id == chosen and str(chosen) != "": return actions._option_title(task, option)
	return "未使用" if field.get("optional", false) else "待选择"

func _subject_kind(task, field: String, value: Variant) -> String:
	if not value is String or value.is_empty(): return ""
	for pair: Array in [["people", "person"], ["domains", "world"], ["cults", "cult"], ["institutions", "institution"], ["anchors", "anchor"], ["relics", "relic"]]:
		if not task.host._views._find(task, pair[0], value).is_empty(): return pair[1]
	return "fact" if task.session.is_known_source(value) else ""

func _save_scroll(task, tab: String, list: ScrollContainer) -> void:
	var offsets: Dictionary = task.draft.get("config_scroll", {})
	offsets[tab] = list.scroll_vertical
	task.draft.config_scroll = offsets

func _switch(task, next: String, current: String, list: ScrollContainer) -> void:
	_save_scroll(task, current, list)
	task.draft.config_tab = next
	task.draft.picker_open = true
	task.render_workbench()
	var picker: Control = task.host._body.find_child("ClosePicker", true, false)
	if is_instance_valid(picker): picker.grab_focus()

func _choose(task, tab: String, list: ScrollContainer, field: Dictionary, value: Variant, selection: Dictionary) -> void:
	_save_scroll(task, tab, list)
	if field.key in ["domain", "npc", "operation"] and selection.get(field.key) != value:
		var offsets: Dictionary = task.draft.get("config_scroll", {})
		for dependent: String in ["npc", "source", "qualification", "institution", "relic", "anchor", "target_domain", "participants", "record", "second_record"]: offsets.erase(dependent)
		task.draft.config_scroll = offsets
	if not field.get("multiple", false): task.draft.picker_open = false
	task._choose(field, value, selection)

func _numeric(options: Array) -> bool:
	return not options.is_empty() and options[0].id is int and options[-1].id is int

func _number(task, rows: VBoxContainer, list: ScrollContainer, tab: String, field: Dictionary, selection: Dictionary) -> void:
	var spinner := SpinBox.new()
	spinner.name = "Field_" + tab
	spinner.min_value = int(field.options[0].id)
	spinner.max_value = int(field.options[-1].id)
	spinner.step = 1
	spinner.value = int(selection.get(tab, spinner.min_value))
	spinner.custom_minimum_size.y = 44
	rows.add_child(spinner)
	rows.add_child(task.label("可选范围 %s–%s" % [spinner.min_value, spinner.max_value]))
	var apply: Button = task.button("确认数量", func() -> void:
		var value: int = int(spinner.value)
		if field.options.any(func(option: Dictionary) -> bool: return option.id == value): _choose(task, tab, list, field, value, selection))
	apply.name = "Apply_" + tab
	rows.add_child(apply)
	var status := VBoxContainer.new(); rows.add_child(status)
	var update := func(_value: float = 0.0) -> void:
		task.begin_candidates()
		task._clear_children(status)
		task.guard_choice(apply, status, field, int(spinner.value), selection)
		task.scan_candidates()
	spinner.value_changed.connect(update)
	update.call()

func _option(task, parent: VBoxContainer, list: ScrollContainer, tab: String, field: Dictionary, selection: Dictionary, option: Dictionary, index: int, actions) -> void:
	var current: Variant = selection.get(tab, []) if field.get("multiple", false) else selection.get(tab, "")
	var selected: bool = option.id in current if current is Array else (typeof(option.id) == typeof(current) and option.id == current)
	var card: Button = task.button("", _choose.bind(task, tab, list, field, option.id, selection))
	card.name = "Choice_%s_%d" % [tab, index]
	card.custom_minimum_size.y = 64
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = actions._option_title(task, option)
	if selected:
		card.add_theme_stylebox_override("normal", task.host._ui.button_style("hover", false, true))
	parent.add_child(card)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8; content.offset_right = -8; content.offset_top = 5; content.offset_bottom = -5
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var kind: String = _subject_kind(task, tab, option.id)
	if kind in ["world", "person", "relic", "cult", "institution", "anchor", "fact"]:
		var artwork := Control.new()
		artwork.custom_minimum_size = Vector2(70, 50)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(artwork)
		if kind == "world": task.host._ui.image(artwork, "WorldArt", Rect2(0, 0, 70, 50), task.host._world_picture(str(option.id)))
		elif kind == "relic":
			task.host._ui.icon(artwork, "RelicSymbol", "relic", Rect2(12, 4, 42, 42))
		else:
			var symbol: String = {"person":"person", "cult":"management", "institution":"stability", "anchor":"anchor_status", "fact":"evidence"}[kind]
			task.host._ui.icon(artwork, "SubjectSymbol", symbol, Rect2(12, 4, 42, 42), UI.CYAN)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(words)
	var label: Label = task.host._line(words, ("◆ " if selected else "") + actions._option_title(task, option), 15, UI.GOLD_HI if selected else UI.BONE)
	label.name = "ChoiceCaption"
	card.accessibility_name = actions._option_title(task, option)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = card.tooltip_text
	if tab == "operation":
		var definition: Dictionary = task.session.catalog.display_tables.progression_route_operations.get(option.id, {})
		var purpose: Label = task.host._line(words, str(definition.get("description", "选择参加者，查看条件、代价与后果。")), 13, UI.MUTED)
		purpose.max_lines_visible = 2
		purpose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.custom_minimum_size.y = 90
	if kind == "person":
		var person: Dictionary = task.host._views._find(task, "people", str(option.id))
		task.host._line(words, str(person.get("role_name", "身份待了解")) + " · 符号示意", 12, UI.MUTED)
	elif kind == "world": task.host._line(words, "世界情境示意", 12, UI.MUTED)
	if kind == "fact":
		var record: Dictionary = actions.source_info(task, str(option.id))
		if not record.is_empty():
			card.custom_minimum_size.y = 100
			var explanation: Label = task.host._line(words, str(record.summary), 13, UI.MUTED)
			explanation.max_lines_visible = 3
			explanation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			card.tooltip_text = str(record.summary)
	task.guard_choice(card, words, field, option.id, selection)
	if selected and field.get("multiple", false) and not kind.is_empty() and kind != "fact":
		var read: Button = task.button("查阅 · " + actions._option_title(task, option), task.show_subject.bind(kind, str(option.id)))
		read.name = "Read_%s_%d" % [tab, index]
		parent.add_child(read)
