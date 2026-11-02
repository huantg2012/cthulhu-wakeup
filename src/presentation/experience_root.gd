extends Control
## Alternate playable presentation. All lasting changes use the production Session.
const Session = preload("res://src/presentation/session.gd")
const BasicTheme = preload("res://src/presentation/basic_theme.gd")
const OriginalUI = preload("res://src/presentation/game_root.gd")
const Views = preload("res://src/presentation/experience_views.gd")
const Actions = preload("res://src/presentation/experience_actions.gd")
const Feedback = preload("res://src/presentation/experience_feedback.gd")
var session: RefCounted = Session.new("user://ui-experience-campaigns")
var projection: Dictionary = {}
var subject: Dictionary = {"kind":"home", "id":""}
var bookmarks: Array = []
var draft: Dictionary = {}
var receipt: Dictionary = {}
var busy: bool = false
var _sequence: int = 0
var _views: RefCounted = Views.new()
var _actions: RefCounted = Actions.new()
var _feedback_builder: RefCounted = Feedback.new()
var _header: HBoxContainer
var _attention: HBoxContainer
var _cult_list: VBoxContainer
var _relic_list: VBoxContainer
var _cult_query: LineEdit
var _relic_query: LineEdit
var _subject_box: VBoxContainer
var _subject_scroll: ScrollContainer
var _work_box: VBoxContainer
var _work_scroll: ScrollContainer
var _work_footer: VBoxContainer
var _work_panel: Control
var _tabs: HBoxContainer
var _draft_tabs: HBoxContainer
var _powers: HBoxContainer
var _chronicle: VBoxContainer
var _status: Label
var _phase_button: Button
var _modal: Control
var _modal_box: VBoxContainer
var _frame: VBoxContainer
var _modal_kind: String = ""
var _return_focus: Control
var _last_phase: String = ""

func _ready() -> void:
	get_window().title = "邪神苏醒 · 可玩结构原型"
	get_window().content_scale_size = Vector2i(1600, 900)
	get_window().size = Vector2i(1600, 900)
	theme = BasicTheme.create(18)
	theme.set_font_size("font_size", "Heading", 23)
	_build()
	refresh()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--experience-save="):
			load_save(argument.trim_prefix("--experience-save="))
		elif argument.begins_with("--experience-seed="):
			start_new(argument.trim_prefix("--experience-seed=").to_int())
	if not projection.get("active", false): show_menu()

func label(text_value: String, heading: bool = false) -> Label:
	var item := Label.new()
	item.text = text_value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if heading: item.theme_type_variation = "Heading"
	return item

func button(text_value: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text_value
	item.custom_minimum_size.y = 34
	item.custom_minimum_size.x = 100
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.pressed.connect(callback)
	return item

func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _scroll(parent: Node, minimum: float = 0) -> VBoxContainer:
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size.x = minimum
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.follow_focus = true
	parent.add_child(scroller)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(box)
	return box

func _panel(parent: Node, minimum: float = 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minimum
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box

func _build() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	_frame = VBoxContainer.new()
	margin.add_child(_frame)
	_header = HBoxContainer.new()
	_header.custom_minimum_size.y = 58
	_frame.add_child(_header)
	_attention = HBoxContainer.new()
	_frame.add_child(_attention)
	var scene := HBoxContainer.new()
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(scene)
	var cult_panel := _panel(scene, 210)
	cult_panel.get_parent().get_parent().size_flags_horizontal = Control.SIZE_FILL
	cult_panel.add_child(label("教团", true))
	_cult_query = LineEdit.new()
	_cult_query.placeholder_text = "查找教团"
	cult_panel.add_child(_cult_query)
	_cult_query.text_changed.connect(func(_value: String) -> void: _render_cults())
	_cult_list = _scroll(cult_panel)
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.add_child(center)
	var left := _panel(center, 520)
	_tabs = HBoxContainer.new()
	left.add_child(_tabs)
	_subject_box = _scroll(left)
	_subject_scroll = _subject_box.get_parent()
	var right := _panel(center, 520)
	_work_panel = right.get_parent().get_parent()
	_draft_tabs = HBoxContainer.new()
	right.add_child(_draft_tabs)
	_work_box = _scroll(right)
	_work_scroll = _work_box.get_parent()
	_work_footer = VBoxContainer.new()
	right.add_child(_work_footer)
	var relic_panel := _panel(scene, 210)
	relic_panel.get_parent().get_parent().size_flags_horizontal = Control.SIZE_FILL
	relic_panel.add_child(label("圣物", true))
	_relic_query = LineEdit.new()
	_relic_query.placeholder_text = "查找名称或持有人"
	relic_panel.add_child(_relic_query)
	_relic_query.text_changed.connect(func(_value: String) -> void: _render_relics())
	_relic_list = _scroll(relic_panel)
	var power_scroll := ScrollContainer.new()
	power_scroll.custom_minimum_size.y = 70
	power_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(power_scroll)
	_powers = HBoxContainer.new()
	_powers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_scroll.add_child(_powers)
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 66
	_frame.add_child(footer)
	footer.add_child(button("编年史", func() -> void: show_subject("history")))
	_chronicle = VBoxContainer.new()
	_chronicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_chronicle)
	_phase_button = button("开始新局", advance)
	_phase_button.custom_minimum_size.x = 170
	footer.add_child(_phase_button)
	_status = label("灰阶交互原型 · 正式规则与随机结算 · 独立存档")
	_status.custom_minimum_size.y = 27
	_status.max_lines_visible = 1
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_frame.add_child(_status)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(300, 110)
	panel.size = Vector2(1000, 680)
	_modal.add_child(panel)
	_modal_box = _scroll(panel)
	_modal.hide()

func refresh() -> void:
	projection = session.project()
	_render_header()
	_render_attention()
	_render_cults()
	_render_relics()
	_render_powers()
	_render_subject()
	render_workbench()
	_render_chronicle()
	var phase: String = str(projection.get("phase", ""))
	_phase_button.text = {"events":"处理当前事件", "actions":"结束回合", "between":"进入下一回合", "ended":"本局回顾"}.get(phase, "开始 / 继续")
	_phase_button.disabled = busy
	if phase == "ended": subject = {"kind":"ending", "id":""}; _render_subject()
	_last_phase = phase

func _render_header() -> void:
	clear(_header)
	if not projection.get("active", false):
		_header.add_child(label("邪神苏醒 · 可玩结构原型", true))
		_header.add_child(button("开始 / 继续", show_menu))
		return
	var phase_title: String = "回合已结算" if projection.phase == "between" else str(projection.phase_title)
	var resources := label("第 %s 轮 · %s\n低语 %s     信仰 %s / %s     苏醒 %s" % [projection.turn, phase_title, projection.whispers, projection.faith, projection.capacity, projection.awakening], true)
	_header.add_child(resources)
	for item: Array in [["世界 %d" % projection.domains.size(),"worlds"],["人物 %d" % projection.people.size(),"people"],["本轮收支","budget"],["关注与名额","attention"],["本体","self"]]:
		var kind: String = item[1]
		_header.add_child(button(item[0], func() -> void: show_subject(kind)))
	_header.add_child(button("暂停", show_menu))

func _responded() -> bool:
	if session.turn == null: return false
	return int(session.turn.context.get("responses", 0)) > 0

func _render_attention() -> void:
	clear(_attention)
	if not projection.get("active", false): return
	var request_count: int = projection.prayers.size()
	var request_text: String = "祈求 · 本轮已回应 · %d 项可查" % request_count if _responded() else "祈求 %d · 本轮可回应一次" % request_count
	if not _responded() and request_count == 0: request_text = "祈求 0 · 暂无待回应请求"
	elif projection.phase == "events": request_text = "祈求 %d · 处理事件后可回应" % request_count
	var soonest: int = 999999
	for prayer: Dictionary in projection.prayers:
		soonest = mini(soonest, int(prayer.get("card", {}).get("due_turn", 999999)))
	if soonest < 999999: request_text += " · 最近期限第%d轮" % soonest
	var request_button := button(request_text, func() -> void: show_subject("prayers"))
	request_button.custom_minimum_size.x = 620
	_attention.add_child(request_button)
	if projection.phase == "events": _attention.add_child(label("待处理事件 · 请先作出选择"))
	if not projection.manifest.is_empty():
		_attention.add_child(button("降临 %s / %s · %s" % [projection.manifest.get("progress", 0), session.catalog.integer("manifest_duration"), "本轮待续付" if projection.manifest.get("paid_turn", 0) != projection.turn else "本轮已付"], func() -> void: show_subject("self")))
	if not projection.resistance.is_empty():
		var plans: Array = projection.resistance.duplicate()
		plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("due", 0)) < int(b.get("due", 0)))
		_attention.add_child(button("危机 %d · %s" % [plans.size(), crisis_summary(plans[0])], func() -> void: show_subject("crises")))
	if projection.get("disconnected", 0) > 0: _attention.add_child(label("断联 %d / %d 轮" % [projection.disconnected, session.catalog.integer("disconnection_limit")]))

func _render_cults() -> void:
	clear(_cult_list)
	if not projection.get("active", false): return
	var count_label := label("")
	_cult_list.add_child(count_label)
	var count: int = 0
	for cult: Dictionary in projection.cults:
		var name_value: String = title(cult.id)
		if not _cult_query.text.is_empty() and not name_value.contains(_cult_query.text): continue
		count += 1
		var id: String = cult.id
		var row := button(name_value + "\n" + describe(cult.get("status", "")) + " · " + describe(projection.economy_plan.get("strategies", {}).get(id, cult.get("strategy", "hold"))), func() -> void: show_subject("cult", id))
		if subject.get("id", "") == id: row.theme_type_variation = "SelectedAction"
		_cult_list.add_child(row)
	count_label.text = "共 %d 个教团" % projection.cults.size() if _cult_query.text.is_empty() else "找到 %d / %d 个教团" % [count, projection.cults.size()]
	if projection.cults.is_empty():
		_cult_list.add_child(label("尚无教团\n已有联系从中央人物与祈求进入。"))
	elif count == 0: _cult_list.add_child(label("没有匹配的教团。"))

func _render_relics() -> void:
	clear(_relic_list)
	if not projection.get("active", false): return
	var visible: Array = projection.relics.filter(func(r: Dictionary) -> bool: return r.get("placement", "") != "consumed")
	var count_label := label("")
	_relic_list.add_child(count_label)
	var count: int = 0
	for relic: Dictionary in visible:
		var id: String = relic.id
		var text_value: String = title(id) + "\n" + describe(relic.get("placement", "线索"))
		if relic.get("holder", "") != "": text_value += " · " + title(str(relic.holder))
		if not _relic_query.text.is_empty() and not text_value.contains(_relic_query.text): continue
		count += 1
		var row := button(text_value, func() -> void: show_subject("relic", id))
		if subject.get("id", "") == id: row.theme_type_variation = "SelectedAction"
		_relic_list.add_child(row)
	count_label.text = "当前可查 %d 件" % visible.size() if _relic_query.text.is_empty() else "找到 %d / %d 件" % [count, visible.size()]
	if visible.is_empty(): _relic_list.add_child(label("尚无圣物\n已知取得机会出现后，可从相关世界进入。"))
	elif count == 0: _relic_list.add_child(label("没有匹配的物件。"))
	_relic_list.add_child(button("完整圣物记录", func() -> void: show_subject("relics")))

func _render_powers() -> void:
	clear(_powers)
	if session.catalog == null: return
	for power: Dictionary in session.catalog.tables.powers.values():
		var key: String = power.id
		var unlocked: bool = int(projection.get("awakening", 0)) >= int(power.unlock_awakening)
		var text_value: String = power.name + "\n" + ("%s低语·%s信仰" % [power.whispers, power.faith] if unlocked else "需苏醒 %s" % power.unlock_awakening)
		if unlocked and int(projection.get("whispers", 0)) < int(power.whispers): text_value = power.name + "\n低语不足"
		elif unlocked and int(projection.get("faith", 0)) < int(power.faith): text_value = power.name + "\n信仰不足"
		var control := button(text_value, func() -> void: open_action(key))
		control.name = "Power_" + key
		control.custom_minimum_size.x = 122
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_powers.add_child(control)

func _render_subject() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_name: String = ""
	var caret: int = -1
	if is_instance_valid(focused) and _subject_box.is_ancestor_of(focused):
		if str(focused.name).begins_with("SubjectSearch_") or str(focused.name).begins_with("PersonFilter_") or str(focused.name).begins_with("SubjectFilter_"):
			focus_name = str(focused.name)
			if focused is LineEdit: caret = focused.caret_column
	clear(_tabs)
	if subject.kind != "home" or not draft.is_empty():
		_tabs.add_child(button("回到总览", func() -> void: show_subject("home")))
	if subject.kind in ["person", "world", "cult", "relic", "anchor", "institution"]: _tabs.add_child(button("留作对照", pin_subject))
	if not bookmarks.is_empty(): _tabs.add_child(button("查看对照（%d）" % bookmarks.size(), show_comparison))
	clear(_subject_box)
	if not projection.get("active", false):
		_subject_box.add_child(label("开始一局，或继续已有的原型存档。", true))
		return
	_render_receipt()
	if subject.kind == "crises":
		_subject_box.add_child(label("已知危机与期限", true))
		for plan: Dictionary in projection.resistance:
			_subject_box.add_child(label(crisis_summary(plan), true))
			var rule: Dictionary = session.catalog.tables.resistance_plans.get(str(plan.get("rule", "")), {})
			_subject_box.add_child(label("若未阻止：" + str(rule.get("result", "后果尚未掌握"))))
			var id: String = str(plan.get("domain", ""))
			_subject_box.add_child(button("查看相关世界", func() -> void: show_subject("world", id)))
	elif subject.kind == "institution":
		for institution: Dictionary in projection.get("institutions", []):
			if institution.id != subject.get("id", ""): continue
			_subject_box.add_child(label(title(institution.id), true))
			var domain: String = str(institution.get("domain", ""))
			_subject_box.add_child(button(title(domain), func() -> void: show_subject("world", domain)))
			if institution.get("representative") != null:
				var person_id: String = str(institution.representative)
				_subject_box.add_child(button("已知代表 · " + title(person_id), func() -> void: show_subject("person", person_id)))
			for anchor: Dictionary in projection.anchors:
				if anchor.get("institution", "") == institution.id:
					var anchor_id: String = anchor.id
					_subject_box.add_child(button("查看锚点、护持与媒介", func() -> void: show_subject("anchor", anchor_id)))
			_subject_box.add_child(button("当地材料与实践", func() -> void: show_subject("materials", domain)))
	else: _views.render(self, _subject_box, str(subject.kind), str(subject.get("id", "")))
	_subject_scroll.set_deferred("scroll_vertical", int(subject.get("scroll", 0)))
	if not focus_name.is_empty():
		var replacement: Control = _subject_box.find_child(focus_name, true, false)
		if replacement != null:
			if replacement is LineEdit and caret >= 0: replacement.caret_column = caret
			focus_later(replacement)

func show_subject(kind: String, id: String = "") -> void:
	if _modal.visible and _modal_kind == "event": close_modal()
	if kind == "fact":
		_open_modal("detail", "编年史详情")
		_views.render(self, _modal_box, kind, id)
		var dismiss := button("关闭详情", close_modal)
		_modal_box.add_child(dismiss)
		focus_later(dismiss)
		return
	if _modal.visible and _modal_kind == "detail": close_modal()
	if subject.kind != kind or subject.get("id", "") != id:
		subject = {"kind":kind, "id":id}
	if kind == "home":
		draft = {}
		render_workbench()
	elif kind == "prayer":
		if not _responded() and projection.get("phase") == "actions":
			open_action("prayer/" + id + "/shallow")
	_render_subject()
	_render_cults()
	_render_relics()

func back_subject() -> void:
	show_subject("home")

func pin_subject() -> void:
	if bookmarks.any(func(entry: Dictionary) -> bool: return entry.kind == subject.kind and entry.id == subject.id): return
	bookmarks.append(subject.duplicate(true))
	if bookmarks.size() > 2: bookmarks.pop_front()
	_render_subject()

func show_comparison() -> void:
	_open_modal("comparison", "对象对照")
	_views.render_comparison(self, _modal_box, bookmarks)
	_modal_box.add_child(button("清空对照", func() -> void: bookmarks.clear(); close_modal(); _render_subject()))
	var dismiss := button("关闭对照", close_modal)
	_modal_box.add_child(dismiss)
	focus_later(dismiss)

func crisis_summary(plan: Dictionary) -> String:
	var rule: Dictionary = session.catalog.tables.resistance_plans.get(str(plan.get("rule", "")), {})
	var target: String = str(plan.get("target", plan.get("domain", "")))
	return "%s · %s · 第%s轮到期" % [title(target), rule.get("name", "已知反制"), plan.get("due", "?")]

func _render_receipt() -> void:
	if receipt.is_empty(): return
	var lines: Array = receipt.get("presentation_lines", [])
	if lines.is_empty(): return
	var summary := label("上次结果 · " + "\n".join(lines.slice(0, 3)))
	summary.name = "ActionReceipt"
	_subject_box.add_child(summary)
	var controls := HBoxContainer.new()
	_subject_box.add_child(controls)
	if lines.size() > 3:
		controls.add_child(button("查看完整结果", func() -> void:
			_open_modal("detail", str(receipt.get("presentation_title", "行动结果")))
			_modal_box.add_child(label("\n".join(lines)))
			var dismiss := button("关闭结果", close_modal)
			_modal_box.add_child(dismiss)
			focus_later(dismiss)))
	controls.add_child(button("收起结果", func() -> void: receipt = {}; _render_subject()))

func context_selection() -> Dictionary:
	var result: Dictionary = {}
	var id: String = str(subject.get("id", ""))
	match str(subject.kind):
		"person":
			result.npc = id
			for person: Dictionary in projection.get("people", []):
				if person.id == id: result.domain = person.get("domain", "")
		"world": result.domain = id
		"cult", "members":
			result.cult = id
			for cult: Dictionary in projection.get("cults", []):
				if cult.id == id: result.domain = cult.domain
		"relic":
			result.relic = id
			for relic: Dictionary in projection.get("relics", []):
				if relic.id == id: result.domain = relic.get("domain", "")
	return result

func open_action(key: String, initial: Dictionary = {}) -> void:
	if _modal_kind == "event": close_modal()
	var values: Dictionary = context_selection()
	values.merge(initial, true)
	draft = {"key":key, "selection":values, "scroll":0}
	render_workbench()
	_render_subject()

func back_action() -> void:
	var previous_key: String = str(draft.get("key", ""))
	draft = {}
	render_workbench()
	_render_subject()
	var origin: Control = _powers.find_child("Power_" + previous_key, false, false)
	if origin != null: focus_later(origin)
	elif _tabs.get_child_count() > 0: focus_later(_tabs.get_child(0))
	else: focus_later(_phase_button)

func render_workbench() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_name: String = ""
	if is_instance_valid(focused) and (_work_box.is_ancestor_of(focused) or _work_footer.is_ancestor_of(focused)):
		focus_name = str(focused.name)
	clear(_draft_tabs)
	_draft_tabs.add_child(label("当前行动", true))
	if not draft.is_empty(): _draft_tabs.add_child(button("关闭行动", back_action))
	clear(_work_box)
	clear(_work_footer)
	_work_panel.visible = projection.get("active", false) and not draft.is_empty()
	if _work_panel.visible: _actions.render(self, _work_box, _work_footer)
	_work_scroll.set_deferred("scroll_vertical", int(draft.get("scroll", 0)))
	if not focus_name.is_empty():
		var replacement: Control = _work_panel.find_child(focus_name, true, false)
		if replacement != null: focus_later(replacement)

func run_action(key: String, selection: Dictionary, confirmed: bool = false) -> void:
	if busy: return
	var chosen: Dictionary = selection.duplicate(true)
	var prepared: Dictionary = session.preview_action(key, chosen)
	if not prepared.get("ok", false): feedback(prepared); render_workbench(); return
	if (prepared.get("irreversible", false) or key == "POWER_MANIFEST_CANCEL") and not confirmed:
		ask(_actions.confirmation_text(self, key, chosen), func() -> void: run_action(key, chosen, true))
		return
	busy = true
	_sequence += 1
	var before: Dictionary = projection.duplicate(true)
	var action_title: String = _action_title(key, chosen)
	var result: Dictionary = session.execute_action(key, chosen, confirmed, "experience/%s/%s" % [Time.get_ticks_usec(), _sequence])
	busy = false
	if result.get("ok", false):
		projection = session.project()
		result.presentation_title = action_title
		result.presentation_lines = _feedback_builder.build(self, result, before, projection, action_title)
		receipt = result
		draft = {}
		if key.begins_with("prayer/"):
			var person_id: String = str(chosen.get("npc", ""))
			if not person_id.is_empty(): subject = {"kind":"person", "id":person_id}
	feedback(result)
	refresh()
	if result.get("ok", false) and projection.phase == "events": show_events()

func _action_title(key: String, chosen: Dictionary = {}) -> String:
	for row: Dictionary in session.action_catalog(chosen):
		if row.key == key: return str(row.title)
	return key

func set_strategy(cult_id: String, strategy: String) -> void:
	var plan: Dictionary = projection.economy_plan.duplicate(true)
	if not plan.has("strategies"): plan.strategies = {}
	plan.strategies[cult_id] = strategy
	save_plan(plan)

func save_plan(plan: Dictionary) -> void:
	if busy: return
	subject.scroll = _subject_scroll.scroll_vertical
	if not draft.is_empty(): draft.scroll = _work_scroll.scroll_vertical
	busy = true
	var result: Dictionary = session.set_plan(plan)
	busy = false
	feedback(result)
	refresh()

func advance() -> void:
	if not projection.get("active", false): show_menu(); return
	if busy: return
	match str(projection.phase):
		"events": show_events()
		"actions":
			var explanation: String = "结束本轮并开始下一轮？\n" + _views.budget_summary(self)
			if not _responded() and not projection.prayers.is_empty(): explanation += "\n本轮还未回应祈求。到期的请求将失去回应机会。"
			ask(explanation, func() -> void: _advance(true))
		"ended": show_subject("ending")
		_: _advance(false)

func _advance(confirmed: bool) -> void:
	if busy: return
	busy = true
	var before: Dictionary = projection.duplicate(true)
	var result: Dictionary = session.progress(confirmed)
	var steps: int = 0
	while result.get("ok", false) and session.turn.context.phase in ["evolution", "settlement", "ending", "between"] and steps < 5:
		result = session.progress()
		steps += 1
	busy = false
	if result.get("ok", false):
		_add_delta(result, before, session.project())
		receipt = result
		draft = {}
		subject = {"kind":"home", "id":""}
	feedback(result)
	refresh()
	if result.get("ok", false) and projection.phase == "events": show_events()

func request_rest() -> void:
	var prepared: Dictionary = session.rest()
	if not prepared.get("confirmation", false): feedback(prepared); return
	var preview: Dictionary = prepared.get("preview", {})
	ask("花费 %s 信仰，恢复 %s 创伤。\n敛息将结束本轮行动，并开始下一轮。" % [preview.get("faith_cost", 0), preview.get("wounds_recovered", 0)], func() -> void:
		if busy: return
		busy = true
		var before: Dictionary = projection.duplicate(true)
		var result: Dictionary = session.rest(true)
		var steps: int = 0
		while result.get("ok", false) and session.turn.context.phase in ["evolution", "settlement", "ending", "between"] and steps < 5:
			result = session.progress(); steps += 1
		busy = false
		if result.get("ok", false):
			_add_delta(result, before, session.project())
			receipt = result; draft = {}; subject = {"kind":"home", "id":""}
		feedback(result); refresh()
		if result.get("ok", false) and projection.phase == "events": show_events())

func _add_delta(result: Dictionary, before: Dictionary, after: Dictionary) -> void:
	result.changes = {}
	for key: String in ["faith","whispers","awakening","insight","wounds"]:
		if before.get(key) != after.get(key): result.changes[key] = {"before":before.get(key),"after":after.get(key)}
	projection = after
	result.presentation_title = "回合结算 · 第%s轮" % before.get("turn", "")
	if before.get("phase") == "between": result.presentation_title = "进入第%s轮" % after.get("turn", "")
	elif before.get("phase") == "events": result.presentation_title = "轮初事件处理完毕"
	result.presentation_lines = _feedback_builder.build(self, result, before, after, result.presentation_title)
	# A phase transition alone is not an action outcome worth occupying the page.
	if result.presentation_lines.size() <= 1: result.presentation_lines = []

func start_new(seed_value: int) -> void:
	if busy: return
	busy = true
	var result: Dictionary = session.start_new(seed_value)
	busy = false
	feedback(result)
	if result.get("ok", false):
		subject = {"kind":"home", "id":""}; bookmarks.clear(); draft = {}; receipt = {}
		close_modal()
	refresh()
	if result.get("ok", false) and projection.phase == "events": show_events()

func load_save(path: String = "") -> void:
	if busy: return
	if not path.is_empty() and not path.begins_with(session.save_directory):
		var original: String = ProjectSettings.globalize_path(path)
		var folder: String = ProjectSettings.globalize_path(session.save_directory)
		DirAccess.make_dir_recursive_absolute(folder)
		var copy_path: String = folder.path_join("%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		var copied: Error = DirAccess.copy_absolute(original, copy_path)
		if copied != OK:
			feedback({"ok":false,"error":"未能复制存档；原文件保持不变"})
			return
		path = copy_path
	busy = true
	var result: Dictionary = session.continue_game(path)
	busy = false
	feedback(result)
	if result.get("ok", false):
		subject = {"kind":"home", "id":""}; bookmarks.clear(); draft = {}; receipt = {}
		close_modal()
	refresh()
	if result.get("ok", false) and projection.phase == "between":
		_advance(false)
		return
	if result.get("ok", false) and projection.phase == "events": show_events()

func _open_modal(kind: String, heading: String) -> void:
	if not _modal.visible: _return_focus = get_viewport().gui_get_focus_owner()
	clear(_modal_box)
	_modal_kind = kind
	_modal_box.add_child(label(heading, true))
	_modal.show()
	_modal.move_to_front()

func close_modal() -> void:
	_modal.hide()
	_modal_kind = ""
	if is_instance_valid(_return_focus): focus_later(_return_focus)

func ask(text_value: String, callback: Callable) -> void:
	_open_modal("confirm", "确认后果")
	_modal_box.add_child(label(text_value))
	var cancel := button("返回", close_modal)
	_modal_box.add_child(cancel)
	_modal_box.add_child(button("确认", func() -> void: close_modal(); callback.call()))
	focus_later(cancel)

func show_events() -> void:
	if projection.get("phase", "") != "events": return
	var events: Array = projection.events.filter(func(e: Dictionary) -> bool: return not e.resolved)
	if events.is_empty(): _advance(false); return
	var event: Dictionary = events[0]
	_open_modal("event", str(event.title))
	_modal_box.add_child(label("未处理事件 %d · 处理后可继续自由行动" % events.size()))
	var context_shown: bool = false
	for row: Dictionary in session.action_catalog():
		if not str(row.key).begins_with(str(event.key) + "/"): continue
		if not context_shown:
			for context: String in _actions.context_lines(row): _modal_box.add_child(label(context))
			context_shown = true
		var key: String = row.key
		var details: Dictionary = row.get("details", {})
		_modal_box.add_child(label(str(details.get("选择后果", ""))))
		_modal_box.add_child(button("选择 " + key.get_slice("/", 2) + " · 查看代价", func() -> void: open_action(key)))
	var domain: String = str(event.get("descriptor", {}).get("domain", ""))
	if not domain.is_empty(): _modal_box.add_child(button("查看相关世界", func() -> void: show_subject("world", domain)))
	_modal_box.add_child(button("先查看现状", close_modal))
	var focus: Control = _modal_box.get_child(_modal_box.get_child_count() - 1)
	focus_later(focus)

func show_menu() -> void:
	_open_modal("menu", "邪神苏醒 · 开始与继续")
	_modal_box.add_child(label("本原型使用正式游戏规则与独立存档。新局从初醒开始；已保存的各局可继续。"))
	var seed_input := LineEdit.new()
	seed_input.text = "1"
	seed_input.placeholder_text = "世界种子（整数）"
	_modal_box.add_child(seed_input)
	_modal_box.add_child(button("开始新局", func() -> void:
		if not seed_input.text.is_valid_int(): _status.text = "请输入整数种子"; return
		var value: int = seed_input.text.to_int()
		if projection.get("active", false):
			ask("保存当前进度并开始新局？", func() -> void:
				var result: Dictionary = session.save_game()
				if result.get("ok", false): start_new(value)
				else: feedback(result))
		else: start_new(value)))
	var example: String = "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
	if FileAccess.file_exists(example):
		_modal_box.add_child(button("体验真实首团局面 · 第3轮", func() -> void:
			if projection.get("active", false): ask("切换到独立副本的首团局面？请先保存需要保留的当前进度。", func() -> void: load_save(example))
			else: load_save(example)))
	var saves: Array = session.saved_games()
	if not saves.is_empty():
		var choices := OptionButton.new()
		choices.fit_to_longest_item = false
		choices.clip_text = true
		for saved: Dictionary in saves:
			choices.add_item(saved.title)
			choices.set_item_metadata(choices.item_count - 1, saved.path)
		_modal_box.add_child(choices)
		_modal_box.add_child(button("继续所选存档", func() -> void:
			var path: String = str(choices.get_selected_metadata())
			if projection.get("active", false): ask("载入所选存档？未保存的行动会被舍弃。", func() -> void: load_save(path))
			else: load_save(path)))
	if projection.get("active", false):
		_modal_box.add_child(button("保存当前局", func() -> void: feedback(session.save_game())))
		_modal_box.add_child(button("返回游戏", close_modal))
		if not projection.get("terminal", false): _modal_box.add_child(button("放弃本局", func() -> void: ask("放弃后只能回顾，不能继续当前局。", func() -> void: feedback(session.abandon(true)); refresh())))
	_modal_box.add_child(label("F5 保存 · Esc 返回 · 左右两页独立滚动 · 侧栏名称可查找\n本页不会修改正式版默认存档。"))
	focus_later(seed_input)

func feedback(result: Dictionary) -> void:
	_status.text = _result_text(result).replace("\n", " · ")
	_status.tooltip_text = _result_text(result)
	if result.get("ok", false) and result.has("autosave") and not result.autosave.get("ok", false): _status.text += " · 自动保存失败，请手动保存"

func _result_text(result: Dictionary) -> String:
	if not result.get("ok", false): return "未执行：" + session.explain_error(str(result.get("error", "当前条件不满足")))
	if result.has("presentation_lines"):
		return "\n".join(result.presentation_lines) if not result.presentation_lines.is_empty() else str(result.get("presentation_title", "已完成"))
	var parts: PackedStringArray = ["已完成"]
	for key: String in result.get("changes", {}):
		var change: Dictionary = result.changes[key]
		parts.append("%s %s → %s" % [describe(key),change.get("before", ""),change.get("after", "")])
	for check: Dictionary in result.get("result", {}).get("checks", []): parts.append("%s · 骰点%s" % [describe(check.get("outcome", "")),check.get("roll", "")])
	for fact: Dictionary in result.get("facts", []).slice(-3): parts.append("第%s轮 · %s" % [fact.get("turn", ""),describe(fact.get("kind", "变化"))])
	return "\n".join(parts)

func _render_chronicle() -> void:
	clear(_chronicle)
	if session.turn == null: _chronicle.add_child(label("最新变化将持续显示在这里。")); return
	var total: int = session.known_sources().size()
	var history: Dictionary = session.history_page(maxi(0,total-50),50)
	var visible_facts: Array = history.get("facts", []).filter(func(fact: Dictionary) -> bool:
		var kind: String = str(fact.get("kind", ""))
		return describe(kind) != kind and not kind.begins_with("prayer_supply_") and kind not in ["prayer_fixed","power_qualification","ending_assessed","turn_phase_started","turn_phase_completed","background_prayer_closed"])
	var recent_lines: Array[String] = []
	var recent_keys: Array[String] = []
	for fact: Dictionary in visible_facts:
		var text_value: String = "第%s轮 · %s" % [fact.get("turn", ""),describe(fact.get("kind", ""))]
		var targets: Array = fact.get("targets", [])
		if not targets.is_empty(): text_value += " · " + title(str(targets[0]))
		var comparison_text: String = text_value
		if fact.get("kind") in ["prayer_result", "prayer_closed"]:
			comparison_text = text_value.replace(" · 祈求结束", " · 祈求结果")
		if not recent_keys.is_empty() and recent_keys[-1] == comparison_text: continue
		recent_lines.append(text_value)
		recent_keys.append(comparison_text)
	for text_value: String in recent_lines.slice(-2):
		var line := label(text_value)
		line.max_lines_visible = 1
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_chronicle.add_child(line)

func title(id: String) -> String:
	if id.is_empty(): return "未掌握"
	for kind: String in ["domains","people","institutions","cults","relics","anchors"]:
		for object: Dictionary in projection.get(kind, []):
			if str(object.id) != id: continue
			if kind == "cults": return title(str(object.domain)) + "的教团"
			if kind == "anchors": return title(str(object.get("domain", ""))) + " · " + title(str(object.get("institution", "")))
			if kind == "relics" and session.catalog != null:
				var definition: Dictionary = session.catalog.tables.relics.get(object.get("type", object.get("content_id", "")), {})
				if not definition.is_empty(): return str(definition.name) + " · " + id.get_slice("/",1).trim_prefix("FACT-")
			return str(object.get("title", object.get("name", id)))
	return session.object_title(id) if session.turn != null else id

func describe(value: Variant, depth: int = 0) -> String:
	if value == null: return "未掌握"
	if value is bool: return "是" if value else "否"
	if value is Dictionary:
		var lines: PackedStringArray = []
		for key: Variant in value:
			if str(key) in ["ok","preview","issuer","version","declaration","source_ids","once_key","mutex","basis","outcomes"]: continue
			lines.append(describe(str(key), depth+1) + "：" + describe(value[key], depth+1))
		return "\n".join(lines) if not lines.is_empty() else "无"
	if value is Array:
		var lines: PackedStringArray = []
		for item: Variant in value: lines.append(describe(item,depth+1))
		return ("、" if depth>1 else "\n").join(lines) if not lines.is_empty() else "无"
	var text_value: String = str(value)
	if text_value.begins_with("DOMAIN-") or text_value.begins_with("NPC-") or text_value.begins_with("RELIC/") or text_value.begins_with("CULT/") or text_value.begins_with("ANCHOR/"): return title(text_value)
	var words: Dictionary = OriginalUI.WORDS.duplicate()
	words.merge({"prayer_registered":"收到祈求", "population_transfer":"信众变化"}, true)
	words.merge({"domain":"所在世界","focus":"关注世界","focused":"已关注","cult_id":"所属教团","bound_member":"正式成员","acted_turn":"最近执行回合","consumed":"已消耗","stored":"当地保管","controlled":"当地保管","ground":"留在当地","placement":"所在状态","carried":"携带中","bound":"绑定中","seized":"被扣押","sealed":"封存中","free":"未绑定","initial":"初生自我","routine_activity":"日常活动","source":"来源","targets":"涉及对象","cult_established":"教团形成","ending_assessed":"本轮存续核验完成","prayer_response":"祈求已回应","prayer_closed":"祈求结束","member_joined":"成员加入","turn_started":"新回合开始","economy_income":"教团收入","economy_prepay":"本轮支出已付","material_received":"收到记录","progression_result":"活动产生结果","relic_disassembled":"圣物已解离","relic_created":"取得圣物","anchor_established":"建立锚点","cult_strategy":"教团指令已调整"},true)
	return str(words.get(text_value,text_value))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if _modal.visible: close_modal()
		elif not draft.is_empty(): back_action()
		elif subject.kind != "home": back_subject()
		else: show_menu()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F5 and session.turn != null:
		feedback(session.save_game()); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB and _modal.visible:
		var controls: Array[Control] = []
		_collect_focus(_modal_box, controls)
		if not controls.is_empty():
			var index: int = controls.find(get_viewport().gui_get_focus_owner())
			controls[posmod(index+(-1 if event.shift_pressed else 1), controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _collect_focus(node: Node, output: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
			if not child is BaseButton or not child.disabled: output.append(child)
		_collect_focus(child, output)

func focus_later(control: Control) -> void:
	(func() -> void:
		if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
			control.grab_focus()).call_deferred()
