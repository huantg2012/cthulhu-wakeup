extends RefCounted
## Archive, local organization, and one related reading position. All objects
## here come from the public projection, and strategy changes go through Session.
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const UI = preload("res://src/presentation/production/locked_controls.gd")
const RecordText = preload("res://src/presentation/player_record_text.gd")
const STRATEGIES := ["expand", "conceal", "hold"]
const STRATEGY_INTENT := {
	"expand": "招募新信众；扩张也可能增加当地察觉。",
	"conceal": "付出信仰，压低当地察觉。",
	"hold": "维持组织现状，等待合适的时机。",
}
const SCOPES := ["全部", "已关注", "未关注"]

var _host: WeakRef
var host: Control:
	get: return _host.get_ref()
var _page := ""
var _domain := ""
var _metric_field := ""
var _member := ""
var _tab := "duties"
var _query := ""
var _scope := 0
var _archive_scroll := 0
var _archive_full_scroll := 0
var _intelligence_scrolls := {}
var _from_archive := false
var _relation := ""
var _source := ""
var _return_control := ""
var _reading_position := 0
var _draft_turn := -1
var _drafts := {}
var _settlements := {}
var _plan_notice := ""
var _list: ScrollContainer
var _rows: VBoxContainer
var _matches: Label
var _reading: ScrollContainer
var _cult_reading: ScrollContainer
var _column: Control
var _list_buttons := {}
var _external_return := Callable()

func _init(root: Control) -> void:
	_host = weakref(root)

func reset() -> void:
	_page = ""
	_domain = ""
	_member = ""
	_tab = "duties"
	_query = ""
	_scope = 0
	_archive_scroll = 0
	_archive_full_scroll = 0
	_intelligence_scrolls.clear()
	_drafts.clear()
	_draft_turn = -1
	_settlements.clear()
	_plan_notice = ""
	_external_return = Callable()

func open_archive(id := "", on_return := Callable()) -> void:
	if not _start(on_return.is_valid()): return
	_external_return = on_return
	_domain = id
	if not id.is_empty():
		_scope = 0
		_query = ""
		_archive_scroll = 0
	_show_archive("ArchiveSearch" if id.is_empty() else "WorldRecord_" + id)

func open_cult(domain: String, on_return := Callable()) -> void:
	if not _start(on_return.is_valid()): return
	_external_return = on_return
	_domain = domain
	_from_archive = false
	_plan_notice = ""
	_show_cult("Roster")

func open_intelligence(domain: String, field := "") -> void:
	if host._views._find(host, "domains", domain).is_empty() or not _start(): return
	_external_return = Callable()
	_domain = domain
	_metric_field = field
	_show_intelligence()

func _remember_intelligence_scroll() -> void:
	if _page == "intelligence" and is_instance_valid(_reading):
		_intelligence_scrolls[_domain + "/" + _metric_field] = _reading.scroll_vertical

func _show_intelligence() -> void:
	_shell("intelligence", "世界情报", host.title(_domain), "当地机构的作用与已知反制。")
	var body := _right()
	var summary: VBoxContainer = host._surface_column(host._surface, Rect2(82, 294, 380, 400))
	var observed: Dictionary = host._views._find(host, "domains", _domain)
	if not _metric_field.is_empty():
		_metric(summary, observed, _metric_field)
		host._line(summary, host._views.WORLD_METRIC_MEANINGS[_metric_field], 16, UI.MUTED)
		_action(summary, "ListenLocalObservation", "聆听当地已知记录", _listen_local)
	host._line(body, "文明与当地机构", 20)
	var background: String = host.session.world_name_background(_domain)
	if not background.is_empty():
		var section := _intelligence_section(body, "CivilizationBackground")
		var world: Dictionary = host._views._find(host, "domains", _domain)
		if world.has("tier"):
			host._line(section, "文明层级 · " + {"planet":"星球", "system":"星系", "cosmic":"宇宙"}.get(world.tier, "未掌握"), 16, UI.MUTED)
		host._line(section, background, 17, UI.MUTED)
	for field: String in host._views.WORLD_METRICS:
		if field != _metric_field: _metric(summary, observed, field)
	if _metric_field.is_empty(): _action(summary, "ListenLocalObservation", "聆听当地已知记录", _listen_local)
	_local_institutions(body)
	_reading.set_deferred("scroll_vertical", int(_intelligence_scrolls.get(_domain + "/" + _metric_field, 0)))
	_fixed("WorldBack", "返回世界", close, 64, 232)
	_focus("WorldBack")

func _listen_local() -> void:
	_remember_intelligence_scroll()
	host._tasks.open_action("POWER_LISTEN", {"domain": _domain}, _show_intelligence)

func _intelligence_section(body: VBoxContainer, node_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_bottom", 15)
	body.add_child(margin)
	var section := VBoxContainer.new()
	section.name = node_name
	section.add_theme_constant_override("separation", 6)
	margin.add_child(section)
	return section

func _local_institutions(body: VBoxContainer) -> void:
	var plans: Array = host._views.world_plans(host, _domain)
	if plans.is_empty(): host._line(body, "暂无已知反制计划。", 16, UI.MUTED)
	for plan: Dictionary in plans:
		var rule: Dictionary = host.session.catalog.display_tables.resistance_plans.get(plan.get("rule", ""), {})
		var section := _intelligence_section(body, "Resistance_" + str(plan.get("id", "")))
		host._line(section, "%s · 第 %s 轮到期" % [rule.get("name", "已知反制"), plan.get("due", "?")], 18, UI.RISK)
		var target: String = RecordText.entity_name(host, str(plan.get("target", "")), _domain)
		if not target.is_empty(): host._line(section, "目标 · " + target, 16)
		if rule.has("result"): host._line(section, rule.result, 16, UI.MUTED)
	var count := 0
	for item: Dictionary in host.projection.get("institutions", []):
		if item.get("domain") != _domain: continue
		count += 1
		var section := _intelligence_section(body, "Institution_" + str(item.id))
		host._line(section, RecordText.entity_name(host, item.id, _domain), 19, UI.GOLD)
		host._line(section, host._views._institution_role(item), 16)
		var details: PackedStringArray = []
		if item.has("active"): details.append("运作中" if item.active else "当前停用")
		var representative: Variant = item.get("representative")
		if representative is String:
			var name_value := RecordText.entity_name(host, representative, _domain)
			if not name_value.is_empty(): details.append("代表 · " + name_value)
		if not details.is_empty(): host._line(section, "　".join(details), 15, UI.MUTED)
	if count == 0: host._line(body, "尚未掌握当地机构。", 17, UI.MUTED)

func _start(from_parent := false) -> bool:
	if host._busy: return false
	if host._dialog not in ["", "world_management", "prayer_detail", "prayer_person", "prayer_result"]:
		return from_parent and host._dialog in ["menu", "task_subject", "task_related", "task_switch"]
	if host._dialog == "world_management": _remember_intelligence_scroll()
	if host._dialog != "world_management": host._close_inline()
	return true

func _shell(page: String, eyebrow: String, title_value: String, hint: String) -> void:
	_page = page
	_relation = ""
	_source = ""
	host._begin_surface("world_management", false, true)
	host._reading_frame(eyebrow, title_value)
	host._reference(host._surface, "ReadingHint", hint, Rect2(82, 250, 1436, 25), 14, UI.MUTED)
	_column = null

func _focus(node_name: String) -> void:
	var target: Control = host._surface.find_child(node_name, true, false)
	if target == null: target = host._surface.find_child("WorldBack", true, false)
	if target != null and (not target is Button or not target.disabled): target.grab_focus()

func _body(scroll: ScrollContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column

func _right(top := 229) -> VBoxContainer:
	if is_instance_valid(_column):
		host._surface.remove_child(_column)
		_column.queue_free()
	var left := 390 if _page == "archive" else 406 if _page == "intelligence" else 66
	_column = host._region(host._surface, "Reading", Rect2(left, 235, 1214 - left, 374))
	_reading = host._scroller(_column, Rect2(0, maxf(0, top - 235), 1214 - left, 555 - maxf(top, 235)))
	return _body(_reading)

func _action(parent: Node, node_name: String, value: String, callback: Callable, primary := false) -> Button:
	var button: Button = host._button(parent, node_name, value, Rect2(), callback, primary)
	button.custom_minimum_size.y = 37
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func _fixed(node_name: String, value: String, callback: Callable, x := 980, width := 218, primary := false) -> Button:
	var parent: Control = _column if is_instance_valid(_column) and x >= _column.position.x else host._surface
	var origin := parent.position if parent == _column else Vector2.ZERO
	return host._button(parent, node_name, value, Rect2(Vector2(x, 576) - origin, Vector2(width, 38)), callback, primary)

func _show_archive(focus_name: String) -> void:
	_shell("archive", "世界档案 / 已知范围", "从哪里继续介入", "查看所知世界与请求线索。查阅不改变关注。")
	var full := _domain.is_empty()
	var search: LineEdit = host._ui.search_field(host._surface, "ArchiveSearch", "搜索世界", Rect2(66, 235, 222, 37))
	search.add_theme_font_size_override("font_size", host._size(16))
	search.text = _query
	search.text_changed.connect(func(value: String) -> void:
		_query = value
		_archive_scroll = 0
		_archive_full_scroll = 0
		_archive_rows())
	var clear: Button = host._button(host._surface, "ClearArchiveSearch", "清", Rect2(291, 235, 43, 37), func() -> void:
		search.clear()
		_query = ""
		_archive_scroll = 0
		_archive_full_scroll = 0
		_archive_rows()
		search.grab_focus())
	clear.accessibility_name = "清除搜索"
	host._button(host._surface, "ArchiveScope", "范围 · " + SCOPES[_scope], Rect2(349, 235, 155, 37) if full else Rect2(66, 275, 268, 34), func() -> void:
		_scope = (_scope + 1) % SCOPES.size()
		_archive_scroll = 0
		_archive_full_scroll = 0
		_show_archive("ArchiveScope"))
	_matches = host._text(host._surface, "", Rect2(522, 240, 268, 25) if full else Rect2(66, 313, 268, 25), 14, UI.MUTED)
	_list = host._scroller(host._surface, Rect2(66, 286, 1148, 268) if full else Rect2(66, 342, 268, 212))
	if not full: host._ui.fill(host._surface, "ArchiveDivider", Layout.box(Rect2(432, 294, 1, 397)), UI.LINE)
	_archive_rows()
	var back_caption := "返回档案总览" if not full else ("返回菜单" if _external_return.is_valid() else "收起档案")
	_fixed("WorldBack", back_caption, back, 64, 232)
	_focus(focus_name)

func _archive_rows() -> void:
	if is_instance_valid(_rows) and _rows.get_parent() == _list:
		_list.remove_child(_rows)
		_rows.queue_free()
	_rows = _body(_list)
	_list_buttons.clear()
	var query := _query.strip_edges().to_lower()
	var worlds: Array = host.projection.domains
	var matched := 0
	for world: Dictionary in worlds:
		if _scope != 0 and bool(world.get("focused", false)) != (_scope == 1): continue
		if not query.is_empty() and not (str(world.title) + " " + str(world.id)).to_lower().contains(query): continue
		matched += 1
		var source := "已关注" if world.get("focused", false) else ("仅请求线索" if world.has("已知范围") else "未关注")
		var row := _action(_rows, "WorldRecord_" + world.id, "", _pick_world.bind(world.id))
		row.custom_minimum_size.y = 57
		row.accessibility_name = str(world.title) + " · " + source
		row.tooltip_text = world.title
		host._object_art(row, "ArchiveWorldArt", Rect2(9, 6, 44, 44), "world", world.id)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(copy)
		copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		copy.offset_left = 62
		copy.offset_top = 3
		copy.offset_right = -8
		copy.add_theme_constant_override("separation", 0)
		for line: Label in [host._line(copy, world.title, 16), host._line(copy, source, 14, UI.MUTED)]:
			line.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if _domain.is_empty():
			var rule := HSeparator.new()
			_rows.add_child(rule)
		_list_buttons[world.id] = row
	_matches.text = "匹配 %d / %d 个世界" % [matched, worlds.size()]
	if matched == 0: host._line(_rows, "没有匹配的已知世界。", 16, UI.MUTED)
	_update_selection(_domain)
	_list.set_deferred("scroll_vertical", _archive_scroll)
	if not _domain.is_empty(): _world_details()

func _pick_world(id: String) -> void:
	var was_full := _domain.is_empty()
	if was_full: _archive_full_scroll = _list.scroll_vertical
	_domain = id
	_archive_scroll = 0 if was_full else _list.scroll_vertical
	if was_full:
		_show_archive("WorldRecord_" + id)
		return
	_update_selection(id)
	_world_details()

func _update_selection(id: String) -> void:
	for key: String in _list_buttons:
		var button: Button = _list_buttons[key]
		host._ui.select_entry(button, key == id)

func _world_details() -> void:
	var body := _right()
	var world: Dictionary = host._views._find(host, "domains", _domain)
	if not _list_buttons.has(_domain):
		host._line(body, "试试其他搜索词或范围。" if _list_buttons.is_empty() else "选择一个世界以查看所知情报。", 18, UI.MUTED)
		return
	host._line(body, world.title, 23, UI.GOLD_HI)
	_action(body, "EnterLocalWorld", "进入当地联系 ›", _enter_local.bind(_domain))
	if world.has("已知范围"): host._line(body, world["已知范围"], 16, UI.MUTED)
	else: host._line(body, "观察记录 · 以标注轮次为准", 15, UI.CYAN)
	if world.has("tier"): host._line(body, "文明层级 · " + {"planet":"星球", "system":"星系", "cosmic":"宇宙"}.get(world.tier, "未掌握"), 16, UI.MUTED)
	for field: String in host._views.WORLD_METRICS:
		_metric(body, world, field)
	for plan: Dictionary in host._views.world_plans(host, _domain):
		var rule: Dictionary = host.session.catalog.display_tables.resistance_plans.get(plan.get("rule", ""), {})
		host._line(body, "%s · %s · 第 %s 轮到期" % [rule.get("name", "已知反制"), host.title(plan.get("target", _domain)), plan.get("due", "?")], 16, UI.RISK)
		if rule.has("result"): host._line(body, rule.result, 15, UI.MUTED)
	var attention_action := "attention/release_focus" if world.get("focused", false) else "attention/focus"
	_action(body, "WorldAttention", "安排下轮释放关注" if world.get("focused", false) else "关注这个世界", _archive_action.bind(attention_action))
	_action(body, "WorldAnchors", "锚点与护持", _archive_subject.bind("anchors", "WorldAnchors"))
	for entry: Array in [["WorldPeople", "当地人物", "people"], ["WorldInstitutions", "世界机构与抵抗", "institutions"], ["WorldMaterials", "当地持续活动", "materials"]]:
		_action(body, entry[0], entry[1], _archive_subject.bind(entry[2], entry[0]))
	_action(body, "WorldRelics", "当地圣物与获取机会", _archive_subject.bind("relics", "WorldRelics"))
	_action(body, "WorldHistory", "当地编年史", _archive_subject.bind("history", "WorldHistory"))
	var cult: Dictionary = host._views._current_cult(host, _domain)
	if cult.is_empty():
		host._line(body, "尚无已知教团。", 16, UI.MUTED)
	else:
		_fixed("ArchiveCult", "管理当地教团", _enter_cult_from_archive)

func _enter_local(id: String) -> void:
	_external_return = Callable()
	close(false)
	host._inspect_world(id)

func _archive_subject(kind: String, focus_name: String) -> void:
	_archive_scroll = _list.scroll_vertical
	host._tasks.open_subject(kind, _domain, _restore_archive.bind(_domain, focus_name, _reading.scroll_vertical))

func _archive_action(key: String) -> void:
	_archive_scroll = _list.scroll_vertical
	host._tasks.open_action(key, {"domain":_domain}, _restore_archive.bind(_domain, "WorldAttention", _reading.scroll_vertical))

func _restore_archive(domain: String, focus_name: String, reading_scroll := 0) -> void:
	_domain = domain
	_show_archive(focus_name)
	_reading.set_deferred("scroll_vertical", reading_scroll)

func _metric(body: VBoxContainer, world: Dictionary, field: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	var symbol := Control.new()
	symbol.custom_minimum_size = Vector2(25, 25)
	row.add_child(symbol)
	host._ui.icon(symbol, "MetricSign", field, Rect2(1, 2, 21, 21), UI.GOLD)
	var label: Label = host._line(row, "%s　%s" % [host._views.WORLD_METRICS[field], host._views.metric_text(world, field)], 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = host._views.metric_help_text(world, field)

func _enter_cult_from_archive() -> void:
	_archive_scroll = _list.scroll_vertical
	_from_archive = true
	_plan_notice = ""
	_show_cult("Roster")

func _cult() -> Dictionary:
	return host._views._current_cult(host, _domain)

func _show_cult(focus_name: String, reading_scroll := 0) -> void:
	var cult := _cult()
	if cult.is_empty():
		_show_archive("WorldRecord_" + _domain)
		return
	var cult_title: String = host._views._cult_name(host, cult)
	_page = "cult"
	_relation = ""
	_source = ""
	host._begin_surface("world_management", false, true)
	host._scene_plate(host._surface, "CultFocus", Rect2(352, 558, 1058, 217), Color("#11212bf7"))
	host._reference(host._surface, "CultTitle", cult_title, Rect2(384, 576, 719, 40), 26, UI.BONE, true, 2)
	host._reference(host._surface, "CultSection", "组织 / 当前安排", Rect2(1105, 578, 267, 34), 13, UI.MUTED)
	_cult_reading = host._scroller(host._surface, Layout.box(Rect2(384, 621, 994, 83)))
	var body := _body(_cult_reading)
	host._line(body, "信众 %s  ·  凝聚 %s" % [cult.followers, cult.cohesion], 19, UI.GOLD_HI)
	host._line(body, "具名成员 %s  ·  %s" % [host._views._members_for(host, cult).size(), {"active":"运作中", "dormant":"休眠", "destroyed":"已毁"}.get(cult.status, "状态未掌握")], 16)
	if not str(cult.get("leader", "")).is_empty(): host._line(body, "领袖 · " + host.title(cult.leader), 16)
	var order: String = host.projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy)
	host._line(body, "已登记指令 · " + host._views._strategy_name(order), 17, UI.GOLD)
	if cult.has("pollution_preview"):
		host._line(body, "持续污染预估", 16, UI.CYAN)
		for line: String in host._feedback.pollution_lines(cult.pollution_preview): host._line(body, line, 16)
	var last: Array = _settlements.get(cult.id, [])
	if not last.is_empty():
		host._line(body, "第 %s 轮实际经营" % last[0].turn, 15, UI.CYAN)
		for line: String in host._feedback.cult_settlement_lines(host, last, false): host._line(body, line, 16)
	host._stage_button(host._surface, "Roster", "查看成员与职责 →", Rect2(384, 712, 178, 37), _open_roster)
	host._stage_button(host._surface, "Orders", "比较并安排指令 →", Rect2(568, 712, 192, 37), _show_orders)
	host._stage_button(host._surface, "CultBudget", "查看供奉 →", Rect2(764, 712, 138, 37), _cult_subject.bind("budget", "CultBudget"))
	host._stage_button(host._surface, "CultMaterials", "推进本团成员活动 →", Rect2(903, 712, 205, 37), _cult_subject.bind("materials", "CultMaterials"))
	host._stage_button(host._surface, "WorldBack", "返回资料" if _external_return.is_valid() and not _from_archive else "返回世界", Rect2(1243, 712, 135, 37), back)
	_focus(focus_name)
	_cult_reading.set_deferred("scroll_vertical", reading_scroll)

func _cult_subject(kind: String, focus_name: String) -> void:
	host._tasks.open_subject(kind, str(_cult().id) if kind == "materials" else "", _show_cult.bind(focus_name, _cult_reading.scroll_vertical))

func _show_orders() -> void:
	var cult := _cult()
	_shell("policy", "教团 / 跨轮安排", "让组织沿着一种方向行动", "比较指令后登记。实际支付、转化与收入在轮末结算。")
	host._stage_button(host._surface, "Roster", "成员名册 →", Rect2(82, 722, 167, 39), _open_roster)
	host._stage_button(host._surface, "WorldBack", "返回教团", Rect2(265, 722, 150, 39), _show_cult.bind("Orders"))
	_plan_details(cult)
	_focus("Strategy_" + str(_drafts.get(cult.id, host.projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy))))

func _plan_details(cult: Dictionary) -> void:
	if _draft_turn != host.projection.turn:
		_drafts.clear()
		_draft_turn = host.projection.turn
	var plan: Dictionary = host.projection.economy_plan.duplicate(true)
	var strategies: Dictionary = plan.get("strategies", {})
	var current: String = strategies.get(cult.id, cult.get("strategy", "hold"))
	var chosen: String = _drafts.get(cult.id, current)
	var body := _right()
	host._line(body, "已登记指令 · " + host._views._strategy_name(current), 20, UI.GOLD_HI)
	host._line(body, "轮末按正式资格与资源复核。", 15, UI.MUTED)
	if not _plan_notice.is_empty(): host._line(body, _plan_notice, 16, UI.CYAN)
	var last: Array = _settlements.get(cult.id, [])
	if not last.is_empty():
		host._line(body, "第 %s 轮实际经营" % last[0].turn, 16, UI.CYAN)
		for line: String in host._feedback.cult_settlement_lines(host, last, false): host._line(body, line, 16)
	if host.projection.phase != "actions" or cult.status == "destroyed":
		host._line(body, "当前只能查阅登记的指令。", 16, UI.MUTED)
		return
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	body.add_child(choices)
	for strategy: String in STRATEGIES:
		var name_value := "Strategy_" + strategy
		var caption: String = host._views._strategy_name(strategy)
		var button := _action(choices, name_value, "", func() -> void:
			_drafts[cult.id] = strategy
			_plan_notice = ""
			_plan_details(_cult())
			_focus(name_value), strategy == chosen)
		button.accessibility_name = caption
		button.accessibility_description = STRATEGY_INTENT[strategy]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 72
		host._ui.choice_style(button, strategy == chosen)
		var words := VBoxContainer.new()
		words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		words.offset_left = 14
		words.offset_top = 8
		words.offset_right = -14
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(words)
		host._line(words, caption, 17)
		host._line(words, STRATEGY_INTENT[strategy], 13, UI.MUTED)
	var saved: Dictionary = host.session.economy_preview().get("preview", {})
	plan["strategies"] = strategies
	strategies[cult.id] = chosen
	var preview: Dictionary = host.session.preview_plan(plan)
	var forecast: Dictionary = preview.get("preview", {})
	var row: Dictionary = host._views._cult_forecast(forecast, cult.id)
	host._line(body, "拟定 · " + host._views._strategy_name(chosen), 18, UI.GOLD)
	if preview.get("ok", false) and not row.is_empty():
		host._line(body, host._views._strategy_summary(host, row, "\n"), 17)
		if saved.has("faith_after_prepay"):
			host._line(body, "轮末预计支出后 · %s → %s 信仰" % [saved.faith_after_prepay, forecast.faith_after_prepay], 15, UI.MUTED)
		for anchor: Dictionary in forecast.get("anchors", []):
			if anchor.get("reason") != "insufficient_faith" or host._views._find(host, "anchors", anchor.anchor).is_empty(): continue
			host._line(body, host.title(anchor.anchor) + " · 预计供奉不足", 15, UI.RISK)
		host._line(body, "预计收入取决于轮末局势，当前尚未入账。", 15, UI.MUTED)
	else:
		host._line(body, host.session.explain_error(str(preview.get("error", "当前没有可预览的指令"))), 16, UI.RISK)
	var submit := _fixed("SaveCultPlan", "登记本轮指令", _submit_plan.bind(cult.id, chosen), 980, 218, true)
	submit.disabled = not preview.get("ok", false) or row.is_empty() or not str(row.get("reason", "")).is_empty() or chosen == current

func _submit_plan(cult_id: String, strategy: String) -> void:
	if host._busy or _page != "policy" or host._dialog != "world_management" or _cult().get("id") != cult_id: return
	var plan: Dictionary = host.projection.economy_plan.duplicate(true)
	var strategies: Dictionary = plan.get("strategies", {})
	if strategies.get(cult_id, _cult().strategy) == strategy: return
	strategies[cult_id] = strategy
	plan["strategies"] = strategies
	var preview: Dictionary = host.session.preview_plan(plan)
	var row: Dictionary = host._views._cult_forecast(preview.get("preview", {}), cult_id)
	if not preview.get("ok", false) or row.is_empty() or not str(row.get("reason", "")).is_empty():
		_plan_details(_cult())
		return
	host._busy = true
	var result: Dictionary = host.session.set_plan(plan)
	host._busy = false
	if result.get("ok", false):
		_drafts.erase(cult_id)
		_plan_notice = "本轮指令已登记，将在轮末执行。"
		host._refresh()
	else:
		_plan_notice = host.session.explain_error(str(result.get("error", "未能登记指令")))
	_plan_details(_cult())
	_focus("Strategy_" + strategy)

func _open_roster() -> void:
	var cult := _cult()
	_member = ""
	_tab = "duties"
	_shell("roster", "所属世界 · " + host.title(_domain), host._views._cult_name(host, cult), "成员名册 · 已登记 " + host._views._strategy_name(host.projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy)))
	_list = host._scroller(host._surface, Layout.box(Rect2(82, 294, 1250, 402)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 16)
	_list.add_child(grid)
	_list_buttons.clear()
	var members: Array = host._views._members_for(host, cult)
	for person: Dictionary in members:
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 300
		grid.add_child(card)
		var figure := Control.new()
		figure.custom_minimum_size.y = 92
		card.add_child(figure)
		host._object_art(figure, "MemberArt", Rect2(0, 0, 91, 92), "person", person.id)
		host._line(card, host.title(person.id), 20)
		host._line(card, host._views._role(host, person), 15, UI.MUTED)
		host._line(card, host._views._execution_status(host, person), 14, UI.MUTED)
		var row := _action(card, "Member_" + person.id, "查看人物 ↗", _pick_member.bind(person.id))
		_list_buttons[person.id] = row
	_fixed("WorldBack", "返回教团", back, 64, 232)
	if members.is_empty(): host._reference(host._surface, "RosterEmpty", "当前没有已知具名成员。", Rect2(82, 294, 500, 49), 17, UI.MUTED)
	_focus("WorldBack")

func _pick_member(id: String) -> void:
	_member = id
	_source = ""
	_relation = ""
	_update_selection(id)
	_member_details("")

func _member_details(focus_name: String, scroll_position := 0) -> void:
	var person: Dictionary = host._views._find(host, "people", _member)
	if is_instance_valid(_column):
		host._surface.remove_child(_column)
		_column.queue_free()
	_column = host._scene_plate(host._surface, "MemberPeek", Layout.PEEK, Color("#1a2b34fa"), SIDE_LEFT)
	host._reference(_column, "MemberName", host.title(_member), Rect2(28, 48, 394, 45), 28, UI.BONE, true, 2)
	var body: VBoxContainer = host._surface_column(_column, Rect2(29, 144, 392, 290))
	_reading = body.get_parent()
	if person.is_empty():
		host._line(body, "这位成员的资料当前不可用。", 17, UI.MUTED)
		return
	host._line(body, "所属 · " + host._views._cult_name(host, _cult()), 15, UI.MUTED)
	if _tab == "duties":
		host._line(body, host._views._role(host, person) + " · " + host._views._state(person.status), 18)
		host._line(body, host._views._execution_status(host, person), 16, UI.CYAN)
		_action(body, "MemberActions", "查看人物行动与活动", host._tasks.open_subject.bind("person", _member, _restore_member.bind(_member, _tab, "MemberActions")))
		for pair: Array in [["will", "意志"], ["insight", "洞察"], ["influence", "影响"], ["adaptation", "适应"], ["loyalty", "忠诚"], ["sanity", "理智"]]:
			if person.has(pair[0]): host._line(body, "%s　%s" % [pair[1], person[pair[0]]], 17)
	else:
		var items: Array = host.projection.relics.filter(func(r: Dictionary) -> bool: return r.get("holder") == _member and r.get("placement") == "carried")
		if items.is_empty(): host._line(body, "未见这位成员携带圣物。", 17, UI.MUTED)
		for item: Dictionary in items:
			_action(body, "Carried_" + item.id, host.title(item.id), _read_relic.bind(item.id))
	host._stage_button(_column, "MemberDuties", "职责", Rect2(29, 103, 135, 36), _choose_tab.bind("duties", "MemberDuties"))
	host._stage_button(_column, "MemberCarried", "携带物", Rect2(173, 103, 147, 36), _choose_tab.bind("carried", "MemberCarried"))
	host._stage_button(_column, "CloseMemberPeek", "收起查阅 ←", Rect2(29, 447, 392, 35), _open_roster)
	_reading.set_deferred("scroll_vertical", scroll_position)
	if not focus_name.is_empty(): _focus(focus_name)

func _restore_member(id: String, tab: String, focus_name: String) -> void:
	_open_roster()
	_tab = tab
	_pick_member(id)
	_focus(focus_name)

func _choose_tab(tab: String, focus_name: String) -> void:
	_tab = tab
	_member_details(focus_name)

func _read_relic(id: String) -> void:
	_remember_reading("Carried_" + id)
	_relation = id
	var body := _related_body(host.title(id))
	var item: Dictionary = host._views._find(host, "relics", id)
	host._line(body, host.title(id), 23, UI.GOLD_HI)
	if item.is_empty(): host._line(body, "这项物件的资料当前不可用。", 16, UI.MUTED)
	else:
		host._line(body, "状态 · " + str(host._views.PLACEMENTS.get(item.get("placement"), "未掌握")), 17)
		if item.has("holder"): host._line(body, "持有者 · " + host.title(item.holder), 17)
		var definition: Dictionary = host.session.catalog.display_tables.relics.get(item.get("type", ""), {})
		for field: String in ["carry_effect", "carry_cost"]:
			if definition.has(field): host._line(body, definition[field], 17)
		_action(body, "OpenRelic", "查看圣物处置", host._tasks.open_subject.bind("relic", id, _restore_member.bind(_member, "carried", "Carried_" + id)))
		var origin: String = item.get("origin", "")
		if not origin.is_empty() and host.session.is_known_source(origin):
			_action(body, "RelicOrigin", "查看已知来历", _read_source.bind(origin, ""))
	_related_return("返回 " + host.title(_member))

func _remember_reading(origin: String) -> void:
	_return_control = origin
	_reading_position = _reading.scroll_vertical

func _read_source(source: String, origin: String) -> void:
	if not origin.is_empty(): _remember_reading(origin)
	_source = source
	var fact: Dictionary = host._views._known_fact(host, source)
	var observation: bool = not fact.is_empty() and host._views._world_observation_fact(fact)
	var heading: String = host.title(source)
	if observation: heading = "世界态势记录" if fact.kind == "world_observation" else "世界态势线索"
	var body := _related_body(heading)
	if fact.is_empty():
		host._line(body, "来源详情尚未掌握。", 17, UI.MUTED)
	else:
		host._line(body, "第 %s 轮 · 已知记录" % fact.turn, 16, UI.CYAN)
		if observation:
			var metrics: Dictionary = fact.changes.get("intelligence", {}).duplicate(true)
			if fact.kind == "world_observation":
				for field: String in host._views.WORLD_METRICS:
					if fact.changes.get("metrics", {}).get(field) is int:
						metrics[field] = {"precision": "exact", "value": fact.changes.metrics[field], "turn": fact.turn}
			for field: String in host._views.WORLD_METRICS:
				_metric(body, {"metric_sources": metrics}, field)
			host._line(body, "记录反映当时所知。", 15, UI.MUTED)
			host._line(body, host.title(source), 15, UI.MUTED)
		elif _page == "archive":
			var world: Dictionary = host._views._find(host, "domains", _domain)
			for field: String in host._views.WORLD_METRICS:
				if world.get("metric_sources", {}).get(field, {}).get("source") == source:
					_metric(body, world, field)
		if not observation:
			var text: Dictionary = preload("res://src/presentation/player_record_text.gd").summarize(host, fact)
			host._line(body, text.summary, 17)
			for line: String in text.lines: host._line(body, line, 16, UI.MUTED)
	_related_return("返回 " + host.title(_member if _page == "roster" else _domain))

func _related_body(heading: String) -> VBoxContainer:
	if is_instance_valid(_column):
		host._surface.remove_child(_column)
		_column.queue_free()
	_column = host._scene_plate(host._surface, "RelatedPeek", Layout.PEEK, Color("#1a2b34fa"), SIDE_LEFT)
	host._reference(_column, "RelatedKicker", "关联查阅 / 原对象保留", Rect2(29, 21, 392, 32), 12, UI.CYAN, false, 2)
	host._reference(_column, "RelatedTitle", heading, Rect2(29, 60, 392, 49), 28, UI.BONE, true)
	var body: VBoxContainer = host._surface_column(_column, Rect2(29, 123, 392, 302))
	_reading = body.get_parent()
	return body

func _related_return(caption: String) -> void:
	host._stage_button(_column, "ReturnReading", caption, Rect2(29, 443, 392, 37), back).grab_focus()

func back() -> void:
	if not _relation.is_empty() or not _source.is_empty():
		_relation = ""
		_source = ""
		if _page == "roster": _member_details(_return_control, _reading_position)
		else:
			_world_details()
			_reading.set_deferred("scroll_vertical", _reading_position)
			_focus(_return_control)
	elif _page in ["roster", "policy"]:
		_show_cult("Roster" if _page == "roster" else "Orders")
	elif _page == "cult" and _from_archive:
		_show_archive("ArchiveCult")
	elif _page == "archive" and not _domain.is_empty():
		var selected := _domain
		_domain = ""
		_archive_scroll = _archive_full_scroll
		_show_archive("WorldRecord_" + selected if _list_buttons.has(selected) else "ArchiveSearch")
	else:
		close()

func close(restore_parent := true) -> void:
	if _page == "archive" and is_instance_valid(_list): _archive_scroll = _list.scroll_vertical
	_remember_intelligence_scroll()
	_page = ""
	if restore_parent and _external_return.is_valid():
		var restore := _external_return
		_external_return = Callable()
		restore.call()
	else:
		host._close_surface()

func record_settlement(records: Array) -> void:
	if records.is_empty(): return
	_settlements.clear()
	for record: Dictionary in records:
		if not _settlements.has(record.cult): _settlements[record.cult] = []
		_settlements[record.cult].append(record)
