extends RefCounted
## Native production surfaces using the shared action and knowledge presenters.
const UI = preload("res://src/presentation/ui/ui_components.gd")
const Composites = preload("res://src/presentation/ui/ui_composites.gd")

var _owner: WeakRef
var host: Control:
	get: return _owner.get_ref()
var session: RefCounted:
	get: return host.session
var projection: Dictionary:
	get: return host.projection
var draft: Dictionary = {}
var _memory: Dictionary = {}
var _turn := -1
var _key := ""
var _return_to := Callable()
var _subject_return := Callable()
var _return_name := ""
var _return_scroll := 0
var _review := 0
var _subject: Dictionary = {}
var _reading_origin: Dictionary = {}
var _budget_draft: Dictionary = {}
var _budget_anchor := ""
var _comparison: Array = []
const WORDS = preload("res://src/presentation/game_root.gd").WORDS
const RECORD_WORDS := {
	"message":"消息", "power":"权能", "power_effect":"权能影响", "power_attempt":"施展权能",
	"turn_action":"行动支出", "route_material":"活动所得材料", "route_result":"活动结果",
	"relic_operation":"圣物处置", "institution_relic_opportunity":"媒介机会",
	"prayer_registered":"收到祈求", "prayer_response":"祈求已回应",
	"prayer_attempt":"尝试回应", "prayer_check":"祈求判定", "turn_wounds":"创伤变化",
	"background_fixed":"处境已形成", "prayer_fixed":"诉求已形成",
	"economy_prepay":"轮末支出", "economy_income":"教团收入", "economy_anchor_payment":"锚点供奉",
	"economy_strategy_payment":"教团经营支出", "economy_rest":"敛息",
	"event_result":"事件结果", "event_fact":"事件影响",
	"population_transfer":"信众变化", "ending_assessed":"存续评估", "ending_sealed":"本局封存",
	"material_received":"收到记录", "progression_result":"活动结果",
	"extinction":"消亡", "awakened":"苏醒", "voluntary":"主动封存",
	"awakening_zero":"苏醒归零", "disconnected":"失去现实联系",
	"manifest_failure":"降临失败", "manifest_completed":"降临完成",
	"reason":"原因", "outcome":"结果", "phase":"阶段",
	"prayer":"祈求", "produced":"实际生成", "whispers_cost":"低语费用",
	"anchor_basis":"扎根依据", "institution_recognized":"机构承认", "anchor_institution_bound":"机构锚定",
	"tag":"材料类别", "originals":"原参与者", "data":"材料内容", "dependencies":"依据记录",
	"operator":"操作者", "series":"连续记录", "uses":"使用记录", "profile":"文明", "rule":"依据类型",
	"relic_type":"媒介类别", "created_turn":"形成回合", "record_series":"连续档案", "record_use":"档案使用",
	"record_dependency":"档案依托", "dual_testimony":"双重见证", "institution":"机构",
}

func _init(owner: Control) -> void:
	_owner = weakref(owner)

func reset() -> void:
	_memory.clear()
	draft = {}
	_turn = -1
	_subject.clear()
	_budget_draft.clear()
	_comparison.clear()
	_reading_origin.clear()
	_return_to = Callable()
	_subject_return = Callable()

func title(id: String) -> String:
	if id.is_empty(): return "未掌握"
	if id.begins_with("ANCHOR/"):
		var anchor: Dictionary = host._views._find(self, "anchors", id)
		if not anchor.is_empty(): return "第%s锚点 · %s" % [anchor.ordinal, host.title(anchor.institution)]
	if id.begins_with("CULT"):
		var cult: Dictionary = host._views._find(self, "cults", id)
		if not cult.is_empty(): return host._views._cult_name(self, cult)
	return host.title(id)

func label(value: String, heading := false) -> Label:
	var text := Label.new()
	text.text = value
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", host._size(18 if heading else 16))
	text.add_theme_color_override("font_color", UI.GOLD_HI if heading else UI.BONE)
	return text

func button(caption: String, callback: Callable) -> Button:
	var control: Button = host._ui.button(null, "TaskButton_%d" % caption.hash(), caption, Rect2(), callback, false, true, host._size(16))
	control.custom_minimum_size.y = 38
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func open_action(key: String, initial: Dictionary = {}, on_return := Callable(), switching := false) -> void:
	if host._busy or not projection.get("active", false): return
	if not switching and _reading_origin.get("action", false) and host._dialog == "task_related":
		var page := _page_position(_subject)
		_subject = page
		host._open_surface("task_switch", "切换任务", "离开当前行动准备？")
		host._line(host._body, "当前选择会保留到本轮结束。确认后转去准备新行动。")
		host._footer_button("CancelTaskSwitch", "返回资料", _render_subject.bind(page)).grab_focus()
		host._footer_button("ConfirmTaskSwitch", "切换任务", func() -> void:
			_reading_origin.clear()
			open_action(key, initial, on_return, true), true)
		return
	if _turn != projection.turn:
		_memory.clear()
		_turn = projection.turn
	_remember_position()
	var origin := get_focus()
	var subject := _page_position(_subject) if host._dialog in ["task_subject", "task_related"] else {}
	_return_to = on_return
	if host._dialog in ["task_subject", "task_related"] and not subject.is_empty():
		_return_to = _render_subject.bind(subject)
	host._close_inline()
	var names := initial.keys()
	names.sort()
	_key = key
	for field: String in names: _key += "|" + field + "=" + str(initial[field])
	if not _memory.has(_key):
		_memory[_key] = {"key":key, "selection":initial.duplicate(true), "scroll":0}
	draft = _memory[_key]
	host._open_surface("task_action", "行动准备", _action_title(key))
	if is_instance_valid(origin) and host._stage.is_ancestor_of(origin): host._return_focus = origin
	render_workbench(false)

func _action_title(key: String) -> String:
	if session.catalog.tables.powers.has(key): return str(session.catalog.tables.powers[key].name)
	if key == "route/context" and draft.get("selection", {}).has("operation"):
		var row: Dictionary = host._actions.resolve_row(self, key, draft.get("selection", {}))
		return str(row.get("details", {}).get("行动", row.get("title", "当前活动")))
	for item: Dictionary in session.action_entries(key):
		if item.key == key: return str(item.title)
	return "行动准备"

func get_focus() -> Control:
	return host.get_viewport().gui_get_focus_owner()

func _remember_position() -> void:
	if host._dialog != "task_action" or draft.is_empty(): return
	draft.scroll = host._body_scroll.scroll_vertical
	var focus := get_focus()
	if is_instance_valid(focus): draft.focus = str(focus.name)

func _restore_action_focus() -> void:
	var replacement: Control = host._surface.find_child(str(draft.get("focus", "ReturnAction")), true, false)
	if not is_instance_valid(replacement) or (replacement is Button and replacement.disabled):
		replacement = host._surface.find_child("ReturnAction", true, false)
	if is_instance_valid(replacement): replacement.grab_focus()
	host._body_scroll.set_deferred("scroll_vertical", int(draft.get("scroll", 0)))

func render_workbench(remember := true) -> void:
	if host._dialog != "task_action": return
	if remember: _remember_position()
	_clear_children(host._body)
	_clear_children(host._footer)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 20)
	host._footer.add_child(controls)
	host._actions.render(self, host._body, controls, true)
	for control: Control in controls.get_children():
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		control.custom_minimum_size.x = 230 if control is Label else 206
		if control is Button and not control.disabled:
			control.add_theme_color_override("font_color", Color("272219"))
			for state: String in ["normal", "hover", "pressed"]:
				control.add_theme_stylebox_override(state, host._ui.button_style(state, true))
	host._footer_button("ReturnAction", "返回", back)
	_restore_action_focus()

func _resume_action() -> void:
	host._open_surface("task_action", "行动准备", _action_title(draft.key))
	render_workbench(false)

func show_invalid_selection(box: VBoxContainer, row: Dictionary, selection: Dictionary) -> bool:
	var invalid: Array[String] = []
	for field: Dictionary in row.fields:
		if not host._actions._has_value(selection.get(field.key)): continue
		var chosen: Array = selection[field.key] if field.get("multiple", false) else [selection[field.key]]
		if chosen.any(func(value: Variant) -> bool:
			return not field.options.any(func(option: Dictionary) -> bool: return option.id == value)):
			invalid.append(field.key)
	if invalid.is_empty(): return false
	box.add_child(label("先前选择已不符合当前条件。请清除失效项，再重新选择。"))
	box.add_child(button("清除失效选择", func() -> void:
		for field: String in invalid: selection.erase(field)
		render_workbench()))
	return true

func render_evidence_read(box: VBoxContainer, field: Dictionary, selection: Dictionary) -> void:
	var source: String = str(selection.get(field.key, ""))
	if not session.is_known_source(source): return
	for prior: Node in box.find_children("*", "Button", true, false):
		if prior.get_meta("read_subject", "") == source: return
	var read := button("依据 · " + str(field.options[0].label), show_subject.bind("fact", source))
	read.name = "Read_" + str(field.key)
	read.set_meta("read_subject", source)
	box.add_child(read)

func render_selector(box: VBoxContainer, field: Dictionary, selection: Dictionary) -> void:
	var key: String = field.key
	var chosen: Variant = selection.get(key, [] if field.get("multiple", false) else "")
	var captions: PackedStringArray = []
	for option: Dictionary in field.options:
		if option.id == chosen or (chosen is Array and option.id in chosen):
			captions.append(host._actions._option_title(self, option))
	var expanded: bool = draft.get("expanded_field", "") == key
	var caption := str(field.label).replace("时空", "世界") + " · " + ("请选择" if captions.is_empty() else "、".join(captions))
	var opener := button(caption + ("  ▴" if expanded else "  ▾"), func() -> void:
		draft.expanded_field = "" if expanded else key
		render_workbench())
	opener.name = "Field_" + key
	opener.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	opener.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opener)
	var values: Array = chosen if chosen is Array else [chosen]
	for value: Variant in values:
		if not value is String or value.is_empty(): continue
		var kind := "fact" if session.is_known_source(value) else ""
		for pair: Array in [["people", "person"], ["domains", "world"], ["cults", "cult"], ["institutions", "institution"], ["anchors", "anchor"], ["relics", "relic"]]:
			if not host._views._find(self, pair[0], value).is_empty(): kind = pair[1]; break
		if kind.is_empty(): continue
		var read := button("查阅" if values.size() == 1 else "查看 · " + title(value), show_subject.bind(kind, value))
		read.name = "Read_" + key + ("_%d" % values.find(value) if values.size() > 1 else "")
		read.tooltip_text = "查看 · " + title(value)
		read.set_meta("read_subject", value)
		if values.size() == 1:
			read.custom_minimum_size.x = 74
			row.add_child(read)
		else: box.add_child(read)
	if not expanded: return
	if field.get("optional", false):
		box.add_child(button("不使用", _choose.bind(field, "", selection)))
	for index: int in field.options.size():
		var option: Dictionary = field.options[index]
		var entry := button(host._actions._option_title(self, option), _choose.bind(field, option.id, selection))
		entry.name = "Choice_%s_%d" % [key, index]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Composites.select_entry(host._ui, entry, option.id == chosen or (chosen is Array and option.id in chosen))
		box.add_child(entry)

func _choose(field: Dictionary, value: Variant, selection: Dictionary) -> void:
	var key: String = field.key
	if field.get("multiple", false) and value != "":
		var values: Array = selection.get(key, []).duplicate()
		if value in values: values.erase(value)
		else: values.append(value)
		selection[key] = values
	else:
		if value == "": selection.erase(key)
		else: selection[key] = value
		# A new parent choice discards only dependent input fields.
		var dependents: Array = {
			"domain":["npc", "source", "cult", "anchor", "relic", "institution", "qualification", "other", "participants", "operation", "record", "second_record", "target", "preparations", "preparation_relic"],
			"npc":["source", "other", "participants", "operation", "record", "second_record", "target", "preparations", "preparation_relic"],
			"operation":["source", "other", "participants", "record", "second_record", "target", "stage"],
		}.get(key, [])
		for dependent: String in dependents: selection.erase(dependent)
		draft.expanded_field = ""
	render_workbench()
	var opener: Control = host._body.find_child("Field_" + key, true, false)
	if is_instance_valid(opener): opener.grab_focus()

func run_action(key: String, selection: Dictionary, confirmed := false, review := -1) -> void:
	var expected := "task_confirm" if confirmed else "task_action"
	if host._busy or host._dialog != expected or draft.get("key") != key: return
	if not confirmed and draft.selection != selection: return
	if confirmed and review != _review: return
	var prepared: Dictionary = session.preview_action(key, selection)
	if not prepared.get("ok", false):
		_resume_action()
		host._body.add_child(label(session.explain_error(str(prepared.get("error", "")))))
		return
	if not confirmed: _remember_position()
	if not confirmed and (prepared.get("irreversible", false) or key == "POWER_MANIFEST_CANCEL"):
		_review += 1
		host._open_surface("task_confirm", "确认行动", _action_title(key))
		host._line(host._body, host._actions.confirmation_text(self, key, selection))
		host._footer_button("CancelAction", "取消", _resume_action).grab_focus()
		host._footer_button("ConfirmAction", "确认执行", run_action.bind(key, selection.duplicate(true), true, _review), true)
		return
	var before := projection
	var caption := _action_title(key)
	host._busy = true
	var result: Dictionary = session.execute_action(key, selection, confirmed)
	host._busy = false
	host._set_notice(result)
	if not result.get("ok", false):
		_resume_action()
		host._body.add_child(label(session.explain_error(str(result.get("error", "")))))
		return
	var after: Dictionary = session.project()
	host._receipt = host._feedback.build(host, result, before, after, caption)
	host._resource_delta = host._feedback.resource_summary(before, after)
	_memory.erase(_key)
	draft = {}
	host._refresh()
	host._show_receipt(_return_to)

func show_subject(kind: String, id := "") -> void:
	if not projection.get("active", false): return
	if host._dialog in ["task_subject", "task_related"] and _subject.get("kind") == "history" and kind == "fact":
		_select_record(id, true)
		return
	_remember_position()
	if host._dialog == "task_action":
		_return_name = str(draft.get("focus", "ReturnAction"))
		_return_scroll = int(draft.get("scroll", 0))
		_reading_origin = {"action":true}
		if kind == "budget": _budget_draft = {}
	elif host._dialog == "task_subject" and (kind != _subject.get("kind") or id != _subject.get("id")):
		_reading_origin = _page_position(_subject)
	else:
		if host._dialog != "task_related": _reading_origin.clear()
		host._close_inline()
	_render_subject({"kind":kind, "id":id})

func open_subject(kind: String, id := "", on_return := Callable()) -> void:
	if not projection.get("active", false): return
	if kind == "budget": _budget_draft = {}
	var origin := get_focus()
	_remember_position()
	host._close_inline()
	_reading_origin.clear()
	_subject_return = on_return
	_render_subject({"kind":kind, "id":id})
	if is_instance_valid(origin) and host._stage.is_ancestor_of(origin): host._return_focus = origin

func _page_position(page: Dictionary) -> Dictionary:
	var saved := page.duplicate()
	saved.scroll = host._body_scroll.scroll_vertical
	var focus := get_focus()
	if is_instance_valid(focus): saved.focus = str(focus.name)
	return saved

func _render_subject(page: Dictionary) -> void:
	_subject = page.duplicate()
	var kind: String = page.kind
	var id: String = page.id
	var heading: String = {
		"people":"人物", "relics":"圣物", "anchors":"锚点与护持", "materials":"材料与实践",
		"budget":"本轮收支", "attention":"关注与成员名额", "history":"编年史",
		"comparison":"已知对象对照", "fact":"已知记录", "self":"本体与苏醒",
		"ending":"本局已封存", "cults":"教团", "institutions":"当地机构",
	}.get(kind, title(id))
	host._open_surface("task_related" if not _reading_origin.is_empty() else "task_subject", "已知资料", heading)
	if _reading_origin.get("action", false):
		host._line(host._body, "为「%s」查看" % _action_title(draft.key), 15, UI.CYAN)
	match kind:
		"budget": _render_budget()
		"relic":
			_render_relic_icon(id)
			host._views.render(self, host._body, kind, id)
		"history": _render_history(page)
		"ending":
			host._line(host._body, "结局 · " + describe(projection.outcome), 19, UI.GOLD_HI)
			if projection.has("ending_reason"):
				host._line(host._body, "原因 · " + describe(projection.ending_reason))
			host._line(host._body, "第 %s 轮 · 最终苏醒 %s" % [projection.turn, projection.awakening])
			host._line(host._body, "本局只读。可查阅已知资料，或返回菜单开始新局。", 16, UI.MUTED)
			host._body.add_child(button("回顾编年史", show_subject.bind("history", "")))
			host._body.add_child(button("返回游戏菜单", host._show_menu))
		"comparison": host._views.render_comparison(self, host._body, _comparison)
		"cults":
			for cult: Dictionary in projection.cults:
				var entry := button(host._views._cult_name(self, cult), _open_cult.bind(cult.domain))
				host._body.add_child(entry)
			if projection.cults.is_empty(): host._line(host._body, "尚无已知教团。")
		_: host._views.render(self, host._body, kind, id)
	if kind in ["world", "person", "cult", "relic", "anchor", "institution"] and not id.is_empty() and not _reading_origin.get("action", false):
		host._body.add_child(button("留作对照", _pin_comparison.bind(kind, id)))
		if not _comparison.is_empty(): host._body.add_child(button("查看对照", show_subject.bind("comparison", "")))
	host._footer_button("ReturnSubject", "返回行动" if _reading_origin.get("action", false) else "返回", back).grab_focus()
	_restore_page(page)

func _render_relic_icon(id: String) -> void:
	var item: Dictionary = host._views._find(self, "relics", id)
	var index: int = host.Dock.RELIC_IDS.find(str(item.get("type", "")))
	if item.is_empty(): return
	var symbol: Control = host._region(host._surface, "RelicSymbol", Rect2(900, 124, 90, 53))
	var icon: TextureRect = host.Dock._relic_icon(host._ui, symbol, index if index >= 0 else 4)
	icon.position = Vector2.ZERO
	icon.size = Vector2(60, 53)

func _open_cult(domain: String) -> void:
	var page := _page_position(_subject)
	host._close_surface()
	host._world_management.open_cult(domain, _render_subject.bind(page))

func manage_cult(id: String, switching := false) -> void:
	var cult: Dictionary = host._views._current_cult(self, id)
	if cult.is_empty(): return
	var page := _page_position(_subject)
	_subject = page
	if _reading_origin.get("action", false) and not switching:
		host._open_surface("task_switch", "切换任务", "转去管理教团？")
		host._line(host._body, "当前行动的选择会保留到本轮结束。")
		host._footer_button("CancelTaskSwitch", "返回资料", _render_subject.bind(page)).grab_focus()
		host._footer_button("ConfirmTaskSwitch", "管理教团", manage_cult.bind(id, true), true)
		return
	if switching: _reading_origin.clear()
	host._close_surface()
	host._world_management.open_cult(cult.domain, _render_subject.bind(page))

func _responded() -> bool:
	return projection.get("prayer_response_spent", false)

func crisis_summary(plan: Dictionary) -> String:
	var rule: Dictionary = session.catalog.tables.resistance_plans.get(str(plan.get("rule", "")), {})
	return "%s · %s · 第%s轮到期" % [title(str(plan.get("target", plan.get("domain", "")))), rule.get("name", "已知反制"), plan.get("due", "?")]

func start_new(seed_value: int) -> void:
	host._confirm_switch("开始新局", host._start_new.bind(seed_value))

func search_field(box: VBoxContainer, key: String, value: String) -> LineEdit:
	var field: LineEdit = host._ui.search_field(box, "SubjectSearch_" + key.replace("/", "_"), "查找名称或编号", Rect2())
	field.custom_minimum_size.y = 36
	field.text = value
	return field

func _restore_page(page: Dictionary) -> void:
	host._body_scroll.set_deferred("scroll_vertical", int(page.get("scroll", 0)))
	if not page.has("focus"): return
	var focus: Control = host._surface.find_child(str(page.focus), true, false)
	if is_instance_valid(focus) and (not focus is Button or not focus.disabled): focus.grab_focus()

func describe(value: Variant, depth := 0) -> String:
	if value == null: return "未掌握"
	if value is bool: return "是" if value else "否"
	var lines: PackedStringArray = []
	if value is Dictionary:
		for key: Variant in value:
			if str(key) in ["ok","preview","issuer","version","declaration","source_ids","once_key","mutex","basis","outcomes","descriptor"]: continue
			var field := "深应" if key == "variant" and value[key] == "deep" else describe(value[key], depth + 1)
			var line := describe(str(key), depth + 1) + "：" + field
			if line not in lines: lines.append(line)
		return "\n".join(lines) if not lines.is_empty() else "无"
	if value is Array:
		for item: Variant in value: lines.append(describe(item, depth + 1))
		return ("、" if depth > 1 else "\n").join(lines) if not lines.is_empty() else "无"
	var word := str(value)
	if RECORD_WORDS.has(word): return RECORD_WORDS[word]
	if WORDS.has(word): return WORDS[word]
	var definition: Dictionary = session.catalog.tables.powers.get(word, {})
	if not definition.is_empty(): return str(definition.name)
	definition = session.catalog.tables.prayers.get(word, {})
	if not definition.is_empty(): return str(definition.title)
	for table: String in ["civilization_profiles", "relics"]:
		definition = session.catalog.tables[table].get(word, {})
		if not definition.is_empty(): return str(definition.get("name", word))
	definition = session.catalog.tables.progression_route_operations.get(word, {})
	if not definition.is_empty(): return str(definition.get("title", definition.get("name", "活动")))
	if word.begins_with("BACKGROUND-"):
		for prayer: Dictionary in projection.prayers:
			if prayer.id == word: return str(prayer.title)
		return "原祈求"
	if word.begins_with("FACT-"):
		return title(word) if session.is_known_source(word) else "尚未获知的前因"
	if word.begins_with("DOMAIN-") or word.begins_with("NPC-") or word.begins_with("RELIC/") or word.begins_with("CULT/") or word.begins_with("ANCHOR/"):
		return title(word)
	return word

func back() -> void:
	match host._dialog:
		"task_confirm": _resume_action()
		"task_switch": _render_subject(_subject)
		"task_plan_confirm": _render_subject(_subject)
		"task_rest_confirm": _render_subject({"kind":"self", "id":""})
		"task_related":
			if _subject.get("kind") == "history" and _subject.has("original_record"):
				_return_record()
				return
			var origin := _reading_origin.duplicate()
			_reading_origin.clear()
			if origin.get("action", false):
				draft.scroll = _return_scroll
				draft.focus = _return_name
				_resume_action()
			elif origin.has("kind"): _render_subject(origin)
			else: host._close_surface()
		"task_action":
			_remember_position()
			if _return_to.is_valid(): _return_to.call()
			else: host._close_surface()
		"task_subject":
			if _subject.get("kind") == "history" and _subject.has("original_record"):
				_return_record()
				return
			if _subject_return.is_valid():
				var restore := _subject_return
				_subject_return = Callable()
				restore.call()
			else: host._close_surface()
		_: host._close_surface()


func _pin_comparison(kind: String, id: String) -> void:
	var entry := {"kind":kind, "id":id}
	if entry not in _comparison:
		if _comparison.size() == 2: _comparison.pop_front()
		_comparison.append(entry)
	show_subject("comparison")

func _right_column() -> VBoxContainer:
	host._body_scroll.size.x = 320
	var scroll: ScrollContainer = host._scroller(host._surface, Rect2(646, 199, 344, 328))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	return column

func _render_budget() -> void:
	var right := _right_column()
	var plan: Dictionary = _budget_draft if not _budget_draft.is_empty() else host._views._plan(self)
	var result: Dictionary = session.preview_plan(plan) if projection.phase == "actions" else session.economy_preview()
	var preview: Dictionary = result.get("preview", {})
	host._line(host._body, "当前信仰　%s" % projection.faith, 18, UI.GOLD_HI)
	if not preview.is_empty():
		var after: int = int(preview.faith_after_prepay)
		host._line(host._body, "轮末先付　%s
支出后余量　%s" % [int(preview.faith_before) - after, after])
		var income := 0
		for row: Dictionary in preview.get("cults", []):
			income += int(row.get("income_if_unchanged", 0))
			if host._views._find(self, "cults", str(row.cult)).is_empty(): continue
			host._body.add_child(button("%s\n支出 %s · 预计收入 %s" % [title(row.cult), row.fee, row.income_if_unchanged], show_subject.bind("cult", row.cult)))
		host._line(host._body, "条件收入　%s
按当前局势预计，轮末实际入账。" % income, 16, UI.MUTED)
	else: host._line(host._body, "查看实际支出与收入", 16, UI.MUTED)
	if _reading_origin.get("action", false):
		var row: Dictionary = host._actions.resolve_row(self, draft.key, draft.selection)
		var payment: Dictionary = host._actions.payment_projection(self, row)
		if payment.get("ok", false):
			host._line(host._body, "若先执行「%s」
行动后 %s · 轮末先付后 %s（现有安排）" % [row.title, payment.faith_after_action, payment.faith_after_prepay], 15, UI.CYAN)
	host._body.add_child(button("查看实际结算记录", show_subject.bind("history", "")))
	host._line(right, "供奉顺序", 19, UI.GOLD_HI)
	var known: Array = plan.anchor_priority.filter(func(id: String) -> bool: return not host._views._find(self, "anchors", id).is_empty())
	if known.is_empty(): host._line(right, "当前没有已知锚点。", 16, UI.MUTED)
	for id: String in known:
		var forecast: Dictionary = {}
		for row: Dictionary in preview.get("anchors", []):
			if row.anchor == id: forecast = row; break
		var reason: String = str(forecast.get("reason", ""))
		var state: String = "本轮停供" if id in plan.refuse_anchors else ("轮末待结算" if forecast.is_empty() else ("%s 信仰" % forecast.get("fee", 0) if reason.is_empty() else host._views._economy_reason(self, reason)))
		var entry := button("%d · %s
%s" % [known.find(id) + 1, title(id), state], _pick_budget_anchor.bind(id))
		Composites.select_entry(host._ui, entry, id == _budget_anchor)
		right.add_child(entry)
		if id == _budget_anchor:
			right.add_child(button("查阅锚点", show_subject.bind("anchor", id)))
			if projection.phase == "actions":
				var controls := HBoxContainer.new()
				right.add_child(controls)
				var up := button("上移", _edit_supply.bind(id, -1))
				var down := button("下移", _edit_supply.bind(id, 1))
				var toggle := button("恢复供奉" if id in plan.refuse_anchors else "本轮停供", _edit_supply.bind(id, 0))
				up.disabled = known.find(id) == 0
				down.disabled = known.find(id) == known.size() - 1
				for control: Button in [up, down, toggle]:
					control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					controls.add_child(control)
	if not _budget_draft.is_empty():
		host._line(right, "拟定安排尚未登记。", 16, UI.CYAN)
		host._footer_button("SaveSupply", "登记安排", _review_plan, true).disabled = not result.get("ok", false)

func _pick_budget_anchor(id: String) -> void:
	_budget_anchor = id
	_render_subject(_page_position(_subject))

func _edit_supply(id: String, step: int) -> void:
	var plan: Dictionary = host._views._plan(self) if _budget_draft.is_empty() else _budget_draft.duplicate(true)
	if step == 0:
		if id in plan.refuse_anchors: plan.refuse_anchors.erase(id)
		else: plan.refuse_anchors.append(id)
	else:
		var ordered: Array = plan.anchor_priority
		var old: int = ordered.find(id)
		var next := old + step
		while next >= 0 and next < ordered.size() and host._views._find(self, "anchors", ordered[next]).is_empty(): next += step
		if next < 0 or next >= ordered.size(): return
		ordered[old] = ordered[next]
		ordered[next] = id
	_budget_draft = plan
	_render_subject(_page_position(_subject))

func _review_plan() -> void:
	host._open_surface("task_plan_confirm", "轮末安排", "登记供奉安排")
	host._line(host._body, "登记后按这份顺序与停供选择预览轮末支付。现在不会扣除信仰。")
	host._footer_button("CancelSupply", "取消", back).grab_focus()
	host._footer_button("ConfirmSupply", "登记", _commit_plan, true)

func _commit_plan() -> void:
	if host._dialog != "task_plan_confirm" or host._busy or _budget_draft.is_empty(): return
	host._busy = true
	var result: Dictionary = session.set_plan(_budget_draft)
	host._busy = false
	host._set_notice(result)
	if result.get("ok", false):
		_budget_draft = {}
		host._refresh()
	_render_subject({"kind":"budget", "id":""})
	if not result.get("ok", false): host._line(host._body, str(result.get("error", "")), 16, UI.RISK)

func _render_history(page: Dictionary) -> void:
	var right := _right_column()
	var filter: String = page.id
	if not filter.is_empty(): host._line(host._body, title(filter) + " · 已知经历", 17, UI.CYAN)
	var search: LineEdit = host._ui.search_field(host._body, "HistoryFilter", "名称／轮次", Rect2())
	search.custom_minimum_size.y = 37
	search.text = str(page.get("query", ""))
	search.text_submitted.connect(func(value: String) -> void:
		_render_subject({"kind":"history", "id":filter, "query":value.strip_edges(), "focus":"HistoryFilter"}))
	var offset: int = int(page.get("offset", 0))
	var facts: Dictionary = host._views._history_slice(self, filter, offset, 12, str(page.get("query", "")))
	for fact: Dictionary in facts.facts:
		var caption := "第%s轮 · %s
%s" % [fact.turn, describe(fact.kind), host._views._fact_summary(self, fact)]
		var entry := button(caption, _select_record.bind(fact.id))
		entry.name = "Record_" + str(fact.id)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Composites.select_entry(host._ui, entry, fact.id == page.get("record", ""))
		host._body.add_child(entry)
	if facts.facts.is_empty(): host._line(host._body, "没有匹配的已知记录。", 16, UI.MUTED)
	var pagination := HBoxContainer.new()
	host._body.add_child(pagination)
	if offset > 0: pagination.add_child(button("较新", _history_page.bind(page, offset - 12)))
	if facts.has_older: pagination.add_child(button("更早", _history_page.bind(page, offset + 12)))
	var record: String = page.get("record", "")
	if record.is_empty(): host._line(right, "选择记录以查看实际变化及已知前因。", 17, UI.MUTED)
	else:
		if page.has("original_record"):
			right.add_child(button("返回原记录", _return_record))
		host._views.render(self, right, "fact", record)

func _select_record(id: String, related := false) -> void:
	var page := _page_position(_subject)
	if related and page.has("record") and not page.has("original_record"):
		page.original_record = page.record
		page.original_focus = page.get("focus", "")
	elif not related:
		page.erase("original_record")
		page.erase("original_focus")
	page.record = id
	_render_subject(page)

func _return_record() -> void:
	var page := _page_position(_subject)
	page.record = page.original_record
	page.focus = page.get("original_focus", "")
	page.erase("original_record")
	page.erase("original_focus")
	_render_subject(page)

func _history_page(page: Dictionary, offset: int) -> void:
	_render_subject({"kind":"history", "id":page.id, "query":page.get("query", ""), "offset":offset})

func request_rest() -> void:
	var prepared: Dictionary = session.rest()
	if not prepared.get("confirmation", false):
		host._line(host._body, str(prepared.get("error", "当前无法敛息。")), 16, UI.RISK)
		return
	var preview: Dictionary = prepared.preview
	host._open_surface("task_rest_confirm", "结束本轮", "敛息")
	host._line(host._body, "花费 %s 信仰，恢复 %s 创伤。
敛息将结束本轮行动，并开始下一轮。" % [preview.get("faith_cost", 0), preview.get("wounds_recovered", 0)])
	host._footer_button("CancelRest", "取消", back).grab_focus()
	host._footer_button("ConfirmRest", "确认敛息", _commit_rest, true)

func _commit_rest() -> void:
	if host._dialog != "task_rest_confirm" or host._busy: return
	host._close_surface()
	host._advance(true, true)

func set_strategy(cult_id: String, strategy: String) -> void:
	var plan: Dictionary = host._views._plan(self)
	plan.strategies[cult_id] = strategy
	save_plan(plan)

func save_plan(plan: Dictionary) -> void:
	var result: Dictionary = session.set_plan(plan)
	host._set_notice(result)
	var page := _page_position(_subject)
	host._refresh()
	_render_subject(page)
	if not result.get("ok", false): host._line(host._body, str(result.get("error", "")), 16, UI.RISK)
