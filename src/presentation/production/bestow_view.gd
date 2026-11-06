extends RefCounted
## Bespoke presentation of one real action; selectors and payment remain in Session.
const UI = preload("res://src/presentation/ui/ui_components.gd")
const TABS := ["domain", "npc", "attribute", "source", "preparations", "requirements", "outcomes"]
const TAB_NAMES := {"domain":"世界", "npc":"人物", "attribute":"属性", "source":"依据", "preparations":"可选准备", "requirements":"所需条件", "outcomes":"结果预览"}
const RESULT_NAMES := {"deep":"深刻成功", "success":"成功", "failure":"失败", "disaster":"灾变"}

func render(task, box: VBoxContainer, footer: Container, row: Dictionary, selection: Dictionary, actions) -> void:
	var host: Control = task.host
	var fields: Array = row.get("fields", [])
	var missing: Array = actions._missing_fields(fields, selection)
	var preview: Dictionary = row.get("preview", {})
	var tabs: Array = TABS.duplicate()
	if actions.fixed_evidence(_field(fields, "source")): tabs.erase("source")
	if not fields.any(func(f: Dictionary) -> bool: return f.get("optional", false) and not f.get("options", []).is_empty()): tabs.erase("preparations")
	var tab: String = str(task.draft.get("bestow_tab", "domain"))
	if not tab in tabs: tab = tabs[0]
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(0, 54)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(banner)
	var scene: TextureRect = host._ui.image(banner, "BestowWorld", Rect2(0, 0, 600, 54), host._world_picture(str(selection.get("domain", ""))))
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.modulate = Color(0.47, 0.53, 0.50, 0.7)
	var shade: ColorRect = host._ui.fill(banner, "RitualShade", Rect2(0, 0, 600, 54), Color(0.0, 0.02, 0.02, 0.58))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host._ui.icon(banner, "BestowSigil", "bestow", Rect2(10, 2, 50, 50))
	host._ui.label(banner, "RitualTitle", "将神意赐予一位信徒", Rect2(81, 3, 520, 29), host._size(20), UI.GOLD_HI)
	var note := "每位人物一生仅能成功受赐一次 · 失败仍支付代价"
	if missing.is_empty() and not preview.get("ok", false): note = "当前不可用 · " + task.session.explain_error(str(preview.get("error", "条件尚未满足")))
	var note_label: Label = host._ui.label(banner, "RitualNote", note, Rect2(81, 29, 540, 24), host._size(14), UI.RISK if missing.is_empty() and not preview.get("ok", false) else UI.BONE)
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
	var navigation := VBoxContainer.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.custom_minimum_size.x = 205
	navigation.add_theme_constant_override("separation", 4)
	nav_scroll.add_child(navigation)
	var pane := VBoxContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_theme_constant_override("separation", 5)
	stage.add_child(pane)
	var list := ScrollContainer.new()
	list.name = "BestowOptionsScroll"
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.follow_focus = true
	list.custom_minimum_size.y = 210
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key: String in tabs:
		var caption: String = str(TAB_NAMES[key]) + "  ·  " + _summary(task, key, fields, selection, preview, actions)
		var button: Button = task.button(caption, _switch.bind(task, key, tab, list))
		button.name = "BestowTab_" + key
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", host._size(14))
		button.clip_text = true
		button.tooltip_text = caption
		button.custom_minimum_size = Vector2(205, 34)
		if key == tab:
			button.add_theme_stylebox_override("normal", host._ui.button_style("hover", false, true))
			button.modulate = Color("ffe7ae")
		navigation.add_child(button)
		if key == tab: nav_scroll.call_deferred("ensure_control_visible", button)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	pane.add_child(header)
	var title: Label = _line(task, header, _heading(tab), 18, UI.GOLD_HI)
	title.name = "BestowListTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = title.text
	var subject: String = str(selection.get(tab, ""))
	if tab in ["domain", "npc"] and not subject.is_empty():
		var read: Button = task.button("查阅资料", task.show_subject.bind("world" if tab == "domain" else "person", subject))
		read.name = "Read_" + tab
		read.autowrap_mode = TextServer.AUTOWRAP_OFF
		read.custom_minimum_size.x = 110
		header.add_child(read)
	pane.add_child(list)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(rows)
	match tab:
		"domain", "npc", "attribute", "source":
			var field: Dictionary = _field(fields, tab)
			if tab == "npc" and str(selection.get("domain", "")).is_empty():
				_line(task, rows, "请先选择世界，再查看当地已知人物。", 15, UI.MUTED)
			elif field.get("options", []).is_empty():
				_line(task, rows, "当前没有可选择的已知依据。" if tab == "source" else "当前没有可选择的已知对象。", 15, UI.MUTED)
			else: _options(task, rows, list, tab, field, selection, actions)
		"preparations":
			var optional: Array = fields.filter(func(f: Dictionary) -> bool: return f.get("optional", false) and not f.get("options", []).is_empty())
			if optional.is_empty(): _line(task, rows, "当前没有可用的协助或准备。", 15, UI.MUTED)
			for field: Dictionary in optional:
				_line(task, rows, str(field.label), 15, UI.GOLD)
				_options(task, rows, list, tab, field, selection, actions)
				if not field.get("multiple", false) and actions._has_value(selection.get(field.key)):
					var clear: Button = task.button("不使用此项", _choose.bind(task, tab, list, field, "", selection))
					clear.name = "BestowClear_" + str(field.key)
					rows.add_child(clear)
		"requirements":
			actions.render_requirements(task, rows, row, selection)
			if rows.get_child_count() == 0: _line(task, rows, "选定承受者后显示本次消耗。", 15, UI.MUTED)
		"outcomes":
			actions.render_fixed_evidence(task, rows, fields)
			if not missing.is_empty(): _line(task, rows, "请先选择：" + "、".join(missing), 15, UI.MUTED)
			elif not preview.get("ok", false): _line(task, rows, "当前不可用 · " + task.session.explain_error(str(preview.get("error", "条件尚未满足"))), 15, UI.RISK)
			else:
				var cost: Dictionary = preview.get("preview", {})
				var outcomes: Dictionary = cost.get("outcomes", {})
				var effects: Dictionary = actions._outcome_effects(task, row, selection)
				for outcome: String in ["deep", "success", "failure", "disaster"]:
					_line(task, rows, "%s  %s%%" % [RESULT_NAMES[outcome], outcomes.get(outcome, 0)], 16, UI.GOLD)
					_line(task, rows, _format_effect(str(effects.get(outcome, ""))), 15, UI.BONE)
				actions._render_payment(task, rows, row)
	var saved_offsets: Dictionary = task.draft.get("bestow_scroll", {})
	if saved_offsets.has(tab):
		list.set_deferred("scroll_vertical", int(saved_offsets[tab]))
	elif tab in ["domain", "npc", "attribute", "source"]:
		var current: Dictionary = _field(fields, tab)
		for index: int in current.get("options", []).size():
			if current.options[index].id == selection.get(tab):
				var selected_card: Control = rows.find_child("Choice_%s_%d" % [tab, index], true, false)
				if is_instance_valid(selected_card): list.call_deferred("ensure_control_visible", selected_card)
				break
	if missing.is_empty() and preview.get("ok", false):
		var cost: Dictionary = preview.get("preview", {})
		footer.add_child(task.label("%s 低语 · %s 信仰" % [cost.get("whispers", 0), cost.get("faith", cost.get("faith_cost", 0))]))
	var choice: Dictionary = selection.duplicate(true)
	var execute: Button = task.button("施行赐予", func() -> void: task.run_action("POWER_BESTOW", choice))
	execute.name = "ExecuteDraft"
	execute.disabled = not preview.get("ok", false) or not missing.is_empty() or task.projection.get("terminal", false)
	footer.add_child(execute)

func _field(fields: Array, key: String) -> Dictionary:
	for field: Dictionary in fields:
		if field.key == key: return field
	return {}

func _heading(key: String) -> String:
	return {"domain":"选择世界 · 示意", "npc":"选择承受者 · 人物符号为占位", "attribute":"选择赐予的属性", "source":"选择本次行动的已知依据", "preparations":"协助与准备", "requirements":"所需条件", "outcomes":"本次赐予的可能结果"}[key]

func _format_effect(value: String) -> String:
	# Format the original CSV tokens without inventing or dropping effects.
	# Future prose that is not fully recognized stays intact.
	var expression := RegEx.new()
	if expression.compile("(本域|当地|两域)?(选定属性|忠诚|理智|察觉|污染|屏障|稳定|凝聚|信众)(加|减)([0-9]+)") != OK: return value
	var matches: Array[RegExMatch] = expression.search_all(value)
	if matches.is_empty() or not expression.sub(value, "", true).replace("且", "").strip_edges().is_empty(): return value
	var parts: PackedStringArray = []
	for item: RegExMatch in matches:
		var field: String = "所选属性" if item.get_string(2) == "选定属性" else item.get_string(2)
		var place: String = item.get_string(1).replace("本域", "当地")
		parts.append(place + field + (" +" if item.get_string(3) == "加" else " −") + item.get_string(4))
	return " · ".join(parts)

func _summary(task, key: String, fields: Array, selection: Dictionary, preview: Dictionary, actions) -> String:
	if key == "requirements": return "查看缺口"
	if key == "outcomes":
		return "成功 %s%%" % preview.get("preview", {}).get("probability", 0) if preview.get("ok", false) else "待选择"
	if key == "preparations":
		for field: Dictionary in fields:
			if field.get("optional", false) and actions._has_value(selection.get(field.key)): return "已选择"
		return "未使用"
	var field: Dictionary = _field(fields, key)
	var chosen: Variant = selection.get(key, "")
	for option: Dictionary in field.get("options", []):
		if option.id == chosen:
			var caption: String = str(option.get("label", option.id)) if key == "attribute" else task.host._actions._option_title(task, option)
			if key == "npc" and " · " in caption:
				var parts: PackedStringArray = caption.split(" · ")
				caption = parts[0] + " " + str(parts[parts.size()-1]).right(4)
			return caption
	return "待选择"

func _line(task, parent: Container, content: String, size: int, color: Color) -> Label:
	var label: Label = task.host._line(parent, content, size, color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _save_scroll(task, tab: String, list: ScrollContainer) -> void:
	var offsets: Dictionary = task.draft.get("bestow_scroll", {})
	offsets[tab] = list.scroll_vertical
	task.draft.bestow_scroll = offsets

func _switch(task, next: String, current: String, list: ScrollContainer) -> void:
	_save_scroll(task, current, list)
	task.draft.bestow_tab = next
	task.render_workbench()

func _choose(task, tab: String, list: ScrollContainer, field: Dictionary, value: Variant, selection: Dictionary) -> void:
	_save_scroll(task, tab, list)
	if selection.get(field.key) != value and field.key in ["domain", "npc"]:
		var offsets: Dictionary = task.draft.get("bestow_scroll", {})
		if field.key == "domain": offsets.erase("npc")
		offsets.erase("source")
		task.draft.bestow_scroll = offsets
	task._choose(field, value, selection)

func _options(task, parent: VBoxContainer, list: ScrollContainer, tab: String, field: Dictionary, selection: Dictionary, actions) -> void:
	var options: Array = field.get("options", [])
	for index: int in options.size():
		var option: Dictionary = options[index]
		var chosen: Variant = selection.get(field.key, []) if field.get("multiple", false) else selection.get(field.key, "")
		var selected: bool = option.id in chosen if chosen is Array else option.id == chosen
		var card: Button = task.button("", _choose.bind(task, tab, list, field, option.id, selection))
		card.name = "Choice_%s_%d" % [field.key, index]
		card.custom_minimum_size.y = 42 if tab == "attribute" else 64
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = actions._option_title(task, option)
		if selected:
			card.add_theme_stylebox_override("normal", task.host._ui.button_style("hover", false, true))
			card.modulate = Color("ffe7ae")
		parent.add_child(card)
		var interior := HBoxContainer.new()
		interior.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		interior.offset_left = 8; interior.offset_right = -8; interior.offset_top = 5; interior.offset_bottom = -5
		interior.add_theme_constant_override("separation", 12)
		interior.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(interior)
		if tab in ["domain", "npc"]:
			var art := Control.new()
			art.custom_minimum_size = Vector2(70, 50)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			interior.add_child(art)
			if tab == "domain": task.host._ui.image(art, "WorldArt", Rect2(0, 0, 70, 50), task.host._world_picture(str(option.id)))
			else: task.host._ui.icon(art, "PersonSymbol", "person", Rect2(12, 4, 42, 42), UI.CYAN)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		interior.add_child(words)
		var name_value: String = actions._option_title(task, option)
		if tab == "attribute": name_value = str(option.get("label", option.id))
		var subtitle := ""
		if tab == "npc":
			var parts: PackedStringArray = name_value.split(" · ")
			if parts.size() > 1:
				subtitle = "已知人物 · " + str(parts[parts.size() - 1]).right(4)
				name_value = " · ".join(parts.slice(0, parts.size() - 1))
		elif tab == "domain": subtitle = "已知世界 · 示意"
		elif tab == "source":
			var record: Dictionary = actions.source_info(task, str(option.id))
			subtitle = str(record.get("summary", ""))
		var name_label: Label = _line(task, words, ("◆ " if selected else "") + name_value, 15, UI.GOLD_HI if selected else UI.BONE)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if not subtitle.is_empty():
			var detail: Label = _line(task, words, subtitle, 12, UI.MUTED)
			if tab == "source":
				card.custom_minimum_size.y = 100
				detail.max_lines_visible = 3
				detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				card.tooltip_text = subtitle

		task.guard_choice(card, words, field, option.id, selection)
