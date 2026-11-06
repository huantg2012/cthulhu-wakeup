extends RefCounted
## Archive, local organization, and one related reading position. All objects
## here come from the public projection, and strategy changes go through Session.
const UI = preload("res://src/presentation/ui/ui_components.gd")
const RecordText = preload("res://src/presentation/player_record_text.gd")
const STRATEGIES := ["expand", "conceal", "hold"]
const SCOPES := ["全部", "已关注", "未关注"]

var _host: WeakRef
var host: Control:
	get: return _host.get_ref()
var _page := ""
var _domain := ""
var _member := ""
var _tab := "duties"
var _query := ""
var _scope := 0
var _archive_scroll := 0
var _intelligence_tabs := {}
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
	_intelligence_tabs.clear()
	_intelligence_scrolls.clear()
	_drafts.clear()
	_draft_turn = -1
	_settlements.clear()
	_plan_notice = ""
	_external_return = Callable()

func open_archive(id := "") -> void:
	if not _start(): return
	_external_return = Callable()
	_domain = id
	if not id.is_empty():
		_scope = 0
		_query = ""
		_archive_scroll = 0
	_show_archive("ArchiveSearch" if id.is_empty() else "WorldRecord_" + id)

func open_cult(domain: String, on_return := Callable()) -> void:
	if not _start(): return
	_external_return = on_return
	_domain = domain
	_from_archive = false
	_plan_notice = ""
	_show_cult("Roster")

func open_intelligence(domain: String) -> void:
	if host._views._find(host, "domains", domain).is_empty() or not _start(): return
	_external_return = Callable()
	_domain = domain
	_show_intelligence(str(_intelligence_tabs.get(domain, "institutions")))

func _remember_intelligence_scroll() -> void:
	if _page == "intelligence" and is_instance_valid(_reading):
		_intelligence_scrolls[_domain + ":" + str(_intelligence_tabs.get(_domain, "institutions"))] = _reading.scroll_vertical

func _choose_intelligence_tab(tab: String) -> void:
	_remember_intelligence_scroll()
	_show_intelligence(tab)

func _show_intelligence(tab: String) -> void:
	_intelligence_tabs[_domain] = tab
	_shell("intelligence", "世界情报", host.title(_domain), "了解当地社会与已掌握的观察依据。")
	for index: int in 2:
		var key: String = ["institutions", "observations"][index]
		var button: Button = host._button(host._surface, "Intelligence_" + key, ["机构与反制", "观察依据"][index], Rect2(279, 190 + index * 51, 221, 43), _choose_intelligence_tab.bind(key))
		button.add_theme_stylebox_override("normal", host._ui.world_row_style("normal", tab == key))
	var body := _right(237)
	host._text(_column, "当地机构与已知反制" if tab == "institutions" else "当前态势的观察依据", Rect2(0, 0, 427, 39), 20, UI.GOLD_HI)
	if tab == "institutions": _local_institutions(body)
	else: _local_observations(body)
	_reading.set_deferred("scroll_vertical", int(_intelligence_scrolls.get(_domain + ":" + tab, 0)))
	_fixed("WorldBack", "返回世界", close, 279, 221)
	_focus("Intelligence_" + tab)

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
		var rule: Dictionary = host.session.catalog.tables.resistance_plans.get(plan.get("rule", ""), {})
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

func _local_observations(body: VBoxContainer) -> void:
	var world: Dictionary = host._views._find(host, "domains", _domain)
	var sources := {}
	for field: String in host._views.WORLD_METRICS:
		var metric: Dictionary = world.get("metric_sources", {}).get(field, {})
		var source: String = str(metric.get("source", ""))
		if source.is_empty() or not host.session.is_known_source(source): continue
		if not sources.has(source): sources[source] = []
		sources[source].append(field)
	if sources.is_empty():
		host._line(body, "尚无可查阅的态势观察依据。", 17, UI.MUTED)
		return
	host._line(body, "仅列支撑当前判断的记录，反映当时所知。", 15, UI.MUTED)
	for source: String in sources:
		var fact: Dictionary = host._views._known_fact(host, source)
		var section := _intelligence_section(body, "IntelligenceSource_" + source)
		var heading := "第 %s 轮" % fact.turn if fact.has("turn") else "轮次未掌握"
		host._line(section, heading + " · " + ("直接观察" if fact.get("kind") == "world_observation" else "已知线索"), 19, UI.GOLD)
		var readings := GridContainer.new()
		readings.columns = 3
		readings.add_theme_constant_override("h_separation", 16)
		readings.add_theme_constant_override("v_separation", 6)
		section.add_child(readings)
		for field: String in sources[source]:
			var display: Dictionary = host._views.metric_display(world, field)
			var metric: Dictionary = world.get("metric_sources", {}).get(field, {})
			var precision: String = display.source
			if fact.has("turn") and metric.get("turn") == fact.turn and display.known:
				precision = "估计" if metric.get("precision") == "range" else "确知"
			var name_label: Label = host._line(readings, host._views.WORLD_METRICS[field], 16)
			name_label.custom_minimum_size.x = 56
			var value_label: Label = host._line(readings, display.value, 16)
			value_label.custom_minimum_size.x = 100
			var precision_label: Label = host._line(readings, precision, 16, UI.MUTED)
			precision_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not fact.is_empty() and not host._views._world_observation_fact(fact):
			var record := RecordText.summarize(host, fact)
			host._line(section, record.summary, 15, UI.MUTED)

func _start() -> bool:
	if host._busy or host._dialog not in ["", "world_management", "prayer_detail", "prayer_person", "prayer_result"]: return false
	if host._dialog == "world_management": _remember_intelligence_scroll()
	if host._dialog != "world_management": host._close_inline()
	return true

func _shell(page: String, eyebrow: String, title_value: String, hint: String) -> void:
	_page = page
	_relation = ""
	_source = ""
	host._begin_surface("world_management", false)
	host._ui.soft_support(host._surface, "StudySupport", Rect2(247, 58, 723, 510), Color(0.004, 0.014, 0.017, 0.98))
	host._text(host._surface, eyebrow, Rect2(279, 69, 666, 29), 15, UI.CYAN)
	host._text(host._surface, title_value, Rect2(277, 101, 666, 49), 27, UI.GOLD_HI)
	host._text(host._surface, hint, Rect2(279, 149, 662, 35), 15, UI.MUTED)
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

func _right(top := 190, bottom := 502) -> VBoxContainer:
	if is_instance_valid(_column):
		host._surface.remove_child(_column)
		_column.queue_free()
	if _page == "cult":
		_column = host._region(host._surface, "Reading", Rect2(267, 190, 389, 373))
		_reading = host._scroller(_column, Rect2(0, 0, 389, 280))
	else:
		_column = host._region(host._surface, "Reading", Rect2(516, 187, 427, 369))
		_reading = host._scroller(_column, Rect2(0, top - 187, 427, bottom - top))
	return _body(_reading)

func _action(parent: Node, node_name: String, value: String, callback: Callable, primary := false) -> Button:
	var button: Button = host._button(parent, node_name, value, Rect2(), callback, primary)
	button.custom_minimum_size.y = 37
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func _fixed(node_name: String, value: String, callback: Callable, x := 516, width := 206, primary := false) -> Button:
	if _page == "cult" and node_name == "SaveCultPlan":
		return host._button(_column, node_name, value, Rect2(169, 336, 220, 37), callback, primary)
	var parent: Control = _column if is_instance_valid(_column) and x >= 516 else host._surface
	var origin := parent.position if parent == _column else Vector2.ZERO
	return host._button(parent, node_name, value, Rect2(Vector2(x, 514) - origin, Vector2(width, 40)), callback, primary)

func _show_archive(focus_name: String) -> void:
	_shell("archive", "世界 · 已知范围", "世界档案", "查看所知世界与请求线索。查阅不改变关注。")
	var search: LineEdit = host._ui.search_field(host._surface, "ArchiveSearch", "搜索世界", Rect2(279, 189, 177, 37))
	search.add_theme_font_size_override("font_size", host._size(16))
	search.text = _query
	host._ui.icon(search, "SearchSign", "search", Rect2(8, 8, 21, 21), UI.MUTED)
	search.text_changed.connect(func(value: String) -> void:
		_query = value
		_archive_scroll = 0
		_archive_rows())
	var clear: Button = host._button(host._surface, "ClearArchiveSearch", "清", Rect2(462, 189, 38, 37), func() -> void:
		search.clear()
		_query = ""
		_archive_scroll = 0
		_archive_rows()
		search.grab_focus())
	clear.accessibility_name = "清除搜索"
	host._button(host._surface, "ArchiveScope", "范围 · " + SCOPES[_scope], Rect2(279, 232, 221, 34), func() -> void:
		_scope = (_scope + 1) % SCOPES.size()
		_archive_scroll = 0
		_show_archive("ArchiveScope"))
	_matches = host._text(host._surface, "", Rect2(282, 272, 214, 28), 14, UI.MUTED)
	_list = host._scroller(host._surface, Rect2(279, 307, 221, 194))
	_archive_rows()
	_fixed("WorldBack", "收起档案", close, 279, 221)
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
		var row := _action(_rows, "WorldRecord_" + world.id, "%s\n%s" % [world.title, source], _pick_world.bind(world.id))
		row.custom_minimum_size.y = 57
		_list_buttons[world.id] = row
	_matches.text = "匹配 %d / %d 个世界" % [matched, worlds.size()]
	if matched == 0: host._line(_rows, "没有匹配的已知世界。", 16, UI.MUTED)
	_update_selection(_domain)
	_list.set_deferred("scroll_vertical", _archive_scroll)
	_world_details()

func _pick_world(id: String) -> void:
	_domain = id
	_archive_scroll = _list.scroll_vertical
	_update_selection(id)
	_world_details()

func _update_selection(id: String) -> void:
	for key: String in _list_buttons:
		var button: Button = _list_buttons[key]
		button.add_theme_stylebox_override("normal", host._ui.world_row_style("normal", key == id))

func _world_details() -> void:
	var body := _right()
	var world: Dictionary = host._views._find(host, "domains", _domain)
	if not _list_buttons.has(_domain):
		host._line(body, "试试其他搜索词或范围。" if _list_buttons.is_empty() else "选择一个世界以查看所知情报。", 18, UI.MUTED)
		return
	host._line(body, world.title, 23, UI.GOLD_HI)
	if world.has("已知范围"): host._line(body, world["已知范围"], 16, UI.MUTED)
	else: host._line(body, "观察记录 · 以标注轮次为准", 15, UI.CYAN)
	if world.has("tier"): host._line(body, "文明层级 · " + {"planet":"星球", "system":"星系", "cosmic":"宇宙"}.get(world.tier, "未掌握"), 16, UI.MUTED)
	var sources := {}
	for field: String in host._views.WORLD_METRICS:
		var metric: Dictionary = world.get("metric_sources", {}).get(field, {})
		_metric(body, world, field)
		var source: String = metric.get("source", "")
		if not source.is_empty() and host.session.is_known_source(source):
			if not sources.has(source): sources[source] = {"turn": metric.get("turn"), "fields": []}
			sources[source].fields.append(host._views.WORLD_METRICS[field])
	for source: String in sources:
		var record: Dictionary = sources[source]
		var heading := "第 %d 轮观察来源" % record.turn if record.turn is int else "观察来源"
		var caption := heading + " · " + "／".join(record.fields)
		var control := _action(body, "Observation_" + source, caption, _read_source.bind(source, "Observation_" + source))
		control.custom_minimum_size.y = 40
	for plan: Dictionary in host._views.world_plans(host, _domain):
		var rule: Dictionary = host.session.catalog.tables.resistance_plans.get(plan.get("rule", ""), {})
		host._line(body, "%s · %s · 第 %s 轮到期" % [rule.get("name", "已知反制"), host.title(plan.get("target", _domain)), plan.get("due", "?")], 16, UI.RISK)
		if rule.has("result"): host._line(body, rule.result, 15, UI.MUTED)
	var attention_action := "attention/release_focus" if world.get("focused", false) else "attention/focus"
	_action(body, "WorldAttention", "安排下轮释放关注" if world.get("focused", false) else "关注这个世界", _archive_action.bind(attention_action))
	_action(body, "WorldAnchors", "锚点与护持", _archive_subject.bind("anchors", "WorldAnchors"))
	for entry: Array in [["WorldPeople", "当地人物", "people"], ["WorldInstitutions", "世界机构与抵抗", "institutions"], ["WorldMaterials", "推进当地活动", "materials"]]:
		_action(body, entry[0], entry[1], _archive_subject.bind(entry[2], entry[0]))
	_action(body, "WorldRelics", "当地圣物与获取机会", _archive_subject.bind("relics", "WorldRelics"))
	_action(body, "WorldHistory", "当地编年史", _archive_subject.bind("history", "WorldHistory"))
	var cult: Dictionary = host._views._current_cult(host, _domain)
	if cult.is_empty():
		host._line(body, "尚无已知教团。", 16, UI.MUTED)
	else:
		_fixed("ArchiveCult", "管理当地教团", _enter_cult_from_archive)

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
	_shell("cult", "教团经营" if cult_title.contains(host.title(_domain)) else "所属世界 · " + host.title(_domain), cult_title, "组织现状与本轮指令")
	var support: Control = host._surface.get_node("StudySupport")
	host._ui.rect(support, Rect2(239, 47, 444, 516))
	var art: TextureRect = host._ui.image(host._surface, "CultScene", Rect2(367, 207, 467, 202), host._ui.skin.source_region(Rect2(480,270,610,264)), Color.WHITE)
	art.material = host._ui.fragment_material(Rect2(480,270,610,264), 0.12, 1.0)
	art.set_meta("subject_id", cult.id)
	host._surface.move_child(art, 0)
	host._text(host._surface, "教团场所 · 场景示意", Rect2(688, 427, 257, 30), 14, UI.MUTED)
	_cult_reading = host._scroller(host._surface, Rect2(267, 192, 389, 278))
	var body := _body(_cult_reading)
	host._line(body, "信众 %s  ·  凝聚 %s" % [cult.followers, cult.cohesion], 19, UI.GOLD_HI)
	host._line(body, "具名成员 %s  ·  %s" % [host._views._members_for(host, cult).size(), {"active":"运作中", "dormant":"休眠", "destroyed":"已毁"}.get(cult.status, "状态未掌握")], 16)
	if not str(cult.get("leader", "")).is_empty(): host._line(body, "领袖 · " + host.title(cult.leader), 16)
	var order: String = host.projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy)
	host._line(body, "已登记指令 · " + host._views._strategy_name(order), 17, UI.GOLD)
	var last: Array = _settlements.get(cult.id, [])
	if not last.is_empty():
		host._line(body, "第 %s 轮实际经营" % last[0].turn, 15, UI.CYAN)
		for line: String in host._feedback.cult_settlement_lines(host, last, false): host._line(body, line, 16)
	for entry: Array in [["CultMaterials", "推进本团成员活动", "materials"], ["CultBudget", "统筹全局收支与供奉", "budget"]]:
		_action(body, entry[0], entry[1], _cult_subject.bind(entry[2], entry[0]))
	host._button(host._surface, "Roster", "成员名册", Rect2(267, 481, 150, 37), _open_roster)
	host._button(host._surface, "Orders", "指令与安排", Rect2(435, 481, 164, 37), _show_orders)
	host._button(host._surface, "WorldBack", "返回资料" if _external_return.is_valid() and not _from_archive else "返回世界", Rect2(267, 526, 150, 37), back)
	_focus(focus_name)
	_cult_reading.set_deferred("scroll_vertical", reading_scroll)

func _cult_subject(kind: String, focus_name: String) -> void:
	host._tasks.open_subject(kind, str(_cult().id) if kind == "materials" else "", _show_cult.bind(focus_name, _cult_reading.scroll_vertical))

func _show_orders() -> void:
	_show_cult("Orders")
	for node: Node in host._surface.get_children():
		if node is ScrollContainer or node.name in ["Orders", "WorldBack"]:
			host._surface.remove_child(node)
			node.queue_free()
	host._surface.get_node("Roster").position = Vector2(267, 481)
	host._button(host._surface, "WorldBack", "返回教团", Rect2(267, 526, 150, 37), _show_cult.bind("Orders"))
	_plan_details(_cult())
	_focus("Strategy_" + str(_drafts.get(_cult().id, host.projection.economy_plan.get("strategies", {}).get(_cult().id, _cult().strategy))))

func _plan_details(cult: Dictionary) -> void:
	if _draft_turn != host.projection.turn:
		_drafts.clear()
		_draft_turn = host.projection.turn
	var plan: Dictionary = host.projection.economy_plan.duplicate(true)
	var strategies: Dictionary = plan.get("strategies", {})
	var current: String = strategies.get(cult.id, cult.get("strategy", "hold"))
	var chosen: String = _drafts.get(cult.id, current)
	var body := _right(190, 500)
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
		var button := _action(choices, name_value, host._views._strategy_name(strategy), func() -> void:
			_drafts[cult.id] = strategy
			_plan_notice = ""
			_plan_details(_cult())
			_focus(name_value), strategy == chosen)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var submit := _fixed("SaveCultPlan", "登记本轮指令", _submit_plan.bind(cult.id, chosen), 715, 226, true)
	submit.disabled = not preview.get("ok", false) or row.is_empty() or not str(row.get("reason", "")).is_empty() or chosen == current

func _submit_plan(cult_id: String, strategy: String) -> void:
	if host._busy or _page != "cult" or host._dialog != "world_management" or _cult().get("id") != cult_id: return
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
		host._world_body.hide()
	else:
		_plan_notice = host.session.explain_error(str(result.get("error", "未能登记指令")))
	_plan_details(_cult())
	_focus("Strategy_" + strategy)

func _open_roster() -> void:
	var cult := _cult()
	_member = ""
	_tab = "duties"
	_shell("roster", "所属世界 · " + host.title(_domain), host._views._cult_name(host, cult), "成员名册 · 已登记 " + host._views._strategy_name(host.projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy)))
	_list = host._scroller(host._surface, Rect2(279, 191, 221, 310))
	var rows := _body(_list)
	_list_buttons.clear()
	var members: Array = host._views._members_for(host, cult)
	for person: Dictionary in members:
		var row := _action(rows, "Member_" + person.id, "%s\n%s" % [host.title(person.id), host._views._role(host, person)], _pick_member.bind(person.id))
		row.custom_minimum_size.y = 59
		_list_buttons[person.id] = row
	_fixed("WorldBack", "返回教团", back, 279, 221)
	var body := _right()
	host._line(body, "当前没有已知具名成员。" if members.is_empty() else "选择一位成员，查阅职责与携带物。", 18, UI.MUTED)
	if members.is_empty(): _focus("WorldBack")
	else: _pick_member(members[0].id); _focus("Member_" + _member)

func _pick_member(id: String) -> void:
	_member = id
	_source = ""
	_relation = ""
	_update_selection(id)
	_member_details("")

func _member_details(focus_name: String, scroll_position := 0) -> void:
	var body := _right(240)
	var person: Dictionary = host._views._find(host, "people", _member)
	if person.is_empty():
		host._line(body, "这位成员的资料当前不可用。", 17, UI.MUTED)
		return
	host._text(_column, host.title(_member), Rect2(0, 0, 427, 45), 22, UI.GOLD_HI)
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
	_fixed("MemberDuties", "职责", _choose_tab.bind("duties", "MemberDuties"), 516, 199, _tab == "duties")
	_fixed("MemberCarried", "携带物", _choose_tab.bind("carried", "MemberCarried"), 732, 206, _tab == "carried")
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
	var body := _right()
	var item: Dictionary = host._views._find(host, "relics", id)
	host._line(body, host.title(id), 23, UI.GOLD_HI)
	if item.is_empty(): host._line(body, "这项物件的资料当前不可用。", 16, UI.MUTED)
	else:
		host._line(body, "状态 · " + str(host._views.PLACEMENTS.get(item.get("placement"), "未掌握")), 17)
		if item.has("holder"): host._line(body, "持有者 · " + host.title(item.holder), 17)
		var definition: Dictionary = host.session.catalog.tables.relics.get(item.get("type", ""), {})
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
	var body := _right()
	var fact: Dictionary = host._views._known_fact(host, source)
	var observation: bool = not fact.is_empty() and host._views._world_observation_fact(fact)
	var heading: String = host.title(source)
	if observation: heading = "世界态势记录" if fact.kind == "world_observation" else "世界态势线索"
	host._line(body, heading, 22, UI.GOLD_HI)
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

func _related_return(caption: String) -> void:
	_fixed("ReturnReading", caption, back, 516, 427).grab_focus()

func back() -> void:
	if not _relation.is_empty() or not _source.is_empty():
		_relation = ""
		_source = ""
		if _page == "roster": _member_details(_return_control, _reading_position)
		else:
			_world_details()
			_reading.set_deferred("scroll_vertical", _reading_position)
			_focus(_return_control)
	elif _page == "roster":
		_show_cult("Roster")
	elif _page == "cult" and _from_archive:
		_show_archive("ArchiveCult")
	else:
		close()

func close() -> void:
	if _page == "archive" and is_instance_valid(_list): _archive_scroll = _list.scroll_vertical
	_remember_intelligence_scroll()
	_page = ""
	host._close_surface()
	if _external_return.is_valid():
		var restore := _external_return
		_external_return = Callable()
		restore.call()

func record_settlement(records: Array) -> void:
	if records.is_empty(): return
	_settlements.clear()
	for record: Dictionary in records:
		if not _settlements.has(record.cult): _settlements[record.cult] = []
		_settlements[record.cult].append(record)
