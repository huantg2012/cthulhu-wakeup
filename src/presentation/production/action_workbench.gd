extends RefCounted
## General production action configuration: decisions are the original fields,
## eligibility and execution remain the existing Session and TaskView paths.
const UI = preload("res://src/presentation/ui/ui_components.gd")
const Dock = preload("res://src/presentation/ui/dock_content.gd")
const OUTCOME := "__outcomes"

func render(task, box: VBoxContainer, footer: Container, row: Dictionary, selection: Dictionary, actions) -> void:
	var host: Control = task.host
	var fields: Array = row.get("fields", [])
	var missing: Array = actions._missing_fields(fields, selection)
	var preview: Dictionary = row.get("preview", {})
	var tabs: Array = []
	for field: Dictionary in actions.visible_fields(fields): tabs.append(str(field.key))
	tabs.append(OUTCOME)
	var tab: String = str(task.draft.get("config_tab", tabs[0]))
	if not tab in tabs: tab = tabs[0]
	var banner := Control.new()
	banner.custom_minimum_size.y = 54
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(banner)
	var art: TextureRect = host._ui.image(banner, "ActionScene", Rect2(0, 0, 600, 54), host._world_picture(str(selection.get("domain", ""))))
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.47, 0.53, 0.50, 0.7)
	var shade: ColorRect = host._ui.fill(banner, "ActionShade", Rect2(0, 0, 600, 54), Color(0, 0.02, 0.02, 0.58))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var key: String = str(row.key)
	var icon: String = key.trim_prefix("POWER_").to_lower() if key.begins_with("POWER_") else ("ritual" if key.begins_with("relic/") else "evidence")
	host._ui.icon(banner, "ActionSigil", icon, Rect2(10, 2, 50, 50))
	host._ui.label(banner, "ActionTitle", actions.action_purpose(row), Rect2(81, 3, 520, 29), host._size(20), UI.GOLD_HI)
	var note: String = "选择对象后查看当前条件与可能结果"
	if key in ["POWER_MANIFEST_CONTINUE", "POWER_MANIFEST_CANCEL"]:
		var details: Dictionary = row.get("details", {})
		note = "已付 %s / %s 轮 · 原主体与两锚点见结果预览" % [details.get("已付仪式轮次", 0), details.get("仪式总轮次", 0)]
	if missing.is_empty() and not preview.get("ok", false): note = "当前不可用 · " + task.session.explain_error(str(preview.get("error", "条件尚未满足")))
	var note_label: Label = host._ui.label(banner, "ActionNote", note, Rect2(81, 29, 540, 24), host._size(14), UI.RISK if missing.is_empty() and not preview.get("ok", false) else UI.BONE)
	note_label.tooltip_text = note
	note_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", 18)
	box.add_child(stage)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.custom_minimum_size = Vector2(205, 240)
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	nav_scroll.follow_focus = true
	stage.add_child(nav_scroll)
	var nav := VBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_theme_constant_override("separation", 4)
	nav_scroll.add_child(nav)
	var pane := VBoxContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_theme_constant_override("separation", 5)
	stage.add_child(pane)
	var list := ScrollContainer.new()
	list.name = "ActionOptionsScroll"
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.follow_focus = true
	list.custom_minimum_size.y = 210
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var active_tab: Button
	for field_id: String in tabs:
		var field: Dictionary = _field(fields, field_id)
		var caption: String = ("结果预览" if field_id == OUTCOME else str(field.get("label", field_id)).replace("时空", "世界")) + " · " + _summary(task, field, selection, preview, field_id, actions)
		var button: Button = task.button(caption, _switch.bind(task, field_id, tab, list))
		button.name = "ActionTab_" + field_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", host._size(14))
		button.clip_text = true
		button.tooltip_text = caption
		button.custom_minimum_size = Vector2(205, 34)
		if field_id == tab:
			button.add_theme_stylebox_override("normal", host._ui.button_style("hover", false, true))
			button.modulate = Color("ffe7ae")
			active_tab = button
		nav.add_child(button)
	if is_instance_valid(active_tab): nav_scroll.call_deferred("ensure_control_visible", active_tab)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	pane.add_child(header)
	var field: Dictionary = _field(fields, tab)
	var title: Label = host._line(header, "结果与费用" if tab == OUTCOME else "选择" + str(field.get("label", tab)).replace("时空", "世界"), 18, UI.GOLD_HI)
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
	pane.add_child(list)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	list.add_child(rows)
	if tab == OUTCOME:
		var context: Dictionary = row.duplicate()
		context.fields = [] # Selected configurable objects already remain in the navigation.
		for line: String in actions.context_lines(context, selection, task.title, task): rows.add_child(task.label(line))
		actions.render_fixed_evidence(task, rows, fields)
		actions.render_activity_progress(task, rows, row)
		if not missing.is_empty(): rows.add_child(task.label("请先选择：" + "、".join(missing)))
		elif not preview.get("ok", false): rows.add_child(task.label("当前不可用 · " + task.session.explain_error(str(preview.get("error", "条件尚未满足")))))
		if missing.is_empty():
			var probabilities: Dictionary = preview.get("preview", {}).get("outcomes", {})
			if probabilities.is_empty(): actions._render_consequences(task, rows, row, selection)
			else:
				var always: String = actions._always_cost(task, row, selection)
				if not always.is_empty() and not always in ["低语", "低语和信仰"]: rows.add_child(task.label("必付代价：" + always))
				var effects: Dictionary = actions._outcome_effects(task, row, selection)
				for outcome: String in actions.OUTCOMES:
					rows.add_child(task.label("%s  %s%%" % [actions.OUTCOME_NAMES[outcome], probabilities.get(outcome, 0)], true))
					rows.add_child(task.label(actions.bestow_view._format_effect(str(effects.get(outcome, "")))))
			if preview.get("ok", false): actions._render_payment(task, rows, row)
		var irreversible: String = actions._irreversible_summary(task, row, selection)
		if not irreversible.is_empty(): rows.add_child(task.label(irreversible))
	elif field.get("options", []).is_empty():
		rows.add_child(task.label("当前没有符合条件的候选。"))
	elif tab == "escort" and _numeric(field.options):
		_number(task, rows, list, tab, field, selection)
	else:
		if field.get("optional", false) and not field.get("multiple", false):
			var clear: Button = task.button("不使用此项", _choose.bind(task, tab, list, field, "", selection))
			clear.name = "Clear_" + tab
			rows.add_child(clear)
		for i: int in field.options.size():
			_option(task, rows, list, tab, field, selection, field.options[i], i, actions)
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
	var caption: String = "执行 · " + str(row.title) + ("…" if preview.get("irreversible", false) else "")
	var execute: Button = task.button(caption, func() -> void: task.run_action(key, choice))
	execute.name = "ExecuteDraft"
	execute.disabled = not preview.get("ok", false) or not missing.is_empty() or task.projection.get("terminal", false)
	footer.add_child(execute)

func _field(fields: Array, key: String) -> Dictionary:
	for field: Dictionary in fields:
		if str(field.key) == key: return field
	return {}

func _summary(task, field: Dictionary, selection: Dictionary, preview: Dictionary, key: String, actions) -> String:
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
	task.render_workbench()

func _choose(task, tab: String, list: ScrollContainer, field: Dictionary, value: Variant, selection: Dictionary) -> void:
	_save_scroll(task, tab, list)
	if field.key in ["domain", "npc", "operation"] and selection.get(field.key) != value:
		var offsets: Dictionary = task.draft.get("config_scroll", {})
		for dependent: String in ["npc", "source", "qualification", "institution", "relic", "anchor", "target_domain", "participants", "record", "second_record"]: offsets.erase(dependent)
		task.draft.config_scroll = offsets
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
		card.modulate = Color("ffe7ae")
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
			var relic: Dictionary = task.host._views._find(task, "relics", str(option.id))
			var art_index: int = Dock.RELIC_IDS.find(str(relic.get("type", "")))
			if art_index >= 0: Dock._relic_icon(task.host._ui, artwork, art_index)
			else: task.host._ui.icon(artwork, "RelicSymbol", "ritual", Rect2(12, 4, 42, 42))
		else:
			var symbol: String = {"person":"person", "cult":"management", "institution":"stability", "anchor":"anchor_status", "fact":"evidence"}[kind]
			task.host._ui.icon(artwork, "SubjectSymbol", symbol, Rect2(12, 4, 42, 42), UI.CYAN)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(words)
	var label: Label = task.host._line(words, ("◆ " if selected else "") + actions._option_title(task, option), 15, UI.GOLD_HI if selected else UI.BONE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = card.tooltip_text
	if kind == "person": task.host._line(words, "人物符号示意", 12, UI.MUTED)
	elif kind == "world": task.host._line(words, "世界情境示意", 12, UI.MUTED)
	if kind == "fact":
		var record: Dictionary = actions.source_info(task, str(option.id))
		if not record.is_empty():
			card.custom_minimum_size.y = 100
			var explanation: Label = task.host._line(words, str(record.summary), 13, UI.MUTED)
			explanation.max_lines_visible = 3
			explanation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			card.tooltip_text = str(record.summary)
	if selected and field.get("multiple", false) and not kind.is_empty() and kind != "fact":
		var read: Button = task.button("查阅 · " + actions._option_title(task, option), task.show_subject.bind(kind, str(option.id)))
		read.name = "Read_%s_%d" % [tab, index]
		parent.add_child(read)
