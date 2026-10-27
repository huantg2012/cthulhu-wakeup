extends Node
## The screen only reads Session projections and submits explicit intents.
const Session = preload("res://src/presentation/session.gd")
const BasicTheme = preload("res://src/presentation/basic_theme.gd")
const Confirmation = preload("res://src/presentation/confirmation.gd")
var session: RefCounted = Session.new()
var page: String = "菜单"
var selected_key: String = ""
var selection: Dictionary = {}
var rows: Array = []
var projection: Dictionary = {}
var font_size: int = 19
var intent_sequence: int = 0
var history_cursor: int = 0
var history_stack: Array[int] = []
var pending: Callable
var return_focus: Control
var _working: bool = false
var _seed: LineEdit
var _header: Label
var _status: Label
var _items: VBoxContainer
var _list_scroll: ScrollContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _execute: Button
var _progress: Button
var _preview: Label
var _confirm: Control
var _confirmation_body: Label
var _nav: VBoxContainer
var _draft_plan: Dictionary = {}
var _page_positions: Dictionary = {}
var _completed_choice: String = ""
var _detail_open: bool = true
var _menu_return: String = "祈求"
@onready var overlay: Control = $Presentation/CanvasLayer/OverlayRoot

const WORDS: Dictionary = {
	"faith":"信仰", "whispers":"低语", "awakening":"苏醒", "insight":"洞见", "wounds":"创伤",
	"gain":"所得", "cost":"代价", "always":"必付后果", "deep":"深刻成功", "success":"成功", "failure":"失败", "disaster":"灾变",
	"requirement":"所需条件", "due":"祈求期限", "effect":"选择后果", "faith_cost":"信仰费用", "probability":"综合成功率",
	"will":"意志", "influence":"影响", "adaptation":"适应", "before":"此前", "after":"此后", "delta":"变化",
	"title":"名称", "id":"身份", "domain":"所在时空", "name":"姓名", "state":"状态", "status":"状态", "tier":"层级",
	"barrier":"屏障", "pollution":"污染", "alert":"察觉", "stability":"稳定", "institutions":"机构", "profile":"文明",
	"npc":"人物", "role":"职务", "leader":"领袖", "guardian":"护持者", "cult":"教团", "members":"成员", "strategy":"策略",
	"expand":"传教", "conceal":"敛藏", "hold":"守持", "active":"活跃", "dormant":"休眠", "alive":"生存", "dead":"死亡",
	"faith_before":"当前信仰", "faith_after_prepay":"预付后信仰", "capacity":"信仰容量", "net_gain":"实际净得", "awakening_loss":"苏醒损失",
	"faith_income":"预计收入", "income":"预计收入", "prepay":"预付", "paid":"已付", "refused":"拒付", "costs":"费用", "payment":"支付",
	"turn":"回合", "kind":"记录类型", "actor":"执行者", "targets":"涉及对象", "changes":"实际记载", "causal_parents":"已知前因",
	"focus":"重点时空", "people":"持续人物", "identities":"维持身份", "bound_member":"正式成员", "attributes":"属性",
	"loyalty":"忠诚", "relic":"圣物", "relics":"圣物", "anchors":"锚点", "cults":"教团", "holder":"持有者", "bound_to":"绑定对象",
	"outcome":"结果", "roll":"骰点", "p":"成功率", "progress":"仪式轮次", "paid_turn":"已付回合", "disconnected":"断联轮次",
	"consumes":"必失对象", "needs":"注意力占用", "budgets":"名额", "limit":"上限", "occupied":"已用", "error":"原因",
	"prayer_result":"祈求结果", "prayer_fixed":"固定祈求", "background_fixed":"已展示诉求", "turn_check":"判定", "power_result":"权能结果",
	"world_origin":"初识时空", "power_qualification":"真实资格", "ending":"封存", "source":"来源", "facts":"记载", "manifest":"降临",
	"request":"祈求", "variant":"回应", "shallow":"浅触", "deep_response":"深应", "seed":"种子", "terminal":"封存结果", "candidate":"诉求实例", "template":"处境类型", "content_id":"事由"
	,"reserved":"已预留", "pending_release":"待释放", "intent":"拟用策略", "effective":"有效策略", "reason":"原因", "fee":"本轮预付", "growth":"预计增长", "attrition":"预计流失", "remainder_units":"流失余量", "income_basis_now":"当前收入资格", "income_basis_after_work":"计入已知流失后资格", "income_if_unchanged":"条件性预计收入", "anchor":"锚点", "expected":"预计状态", "known_plan":"已知计划", "conditional":"收入条件", "condition":"条件", "deep_success":"深刻成功", "interpretation":"解释职责", "propagation":"传播职责", "order":"秩序职责", "focused":"当前重点", "neighbors":"已知邻域", "representative":"已知代表", "profile_id":"人物范式", "sanity":"理智", "local_spend":"本地投入", "whispers_cost":"低语费用", "responded":"已回应", "used_power":"已用权能", "used_relic":"已用圣物", "wounds_recovered":"恢复创伤", "ends_actions":"立即结束行动", "explicit_refusal":"已明确拒付", "insufficient_faith":"信仰不足", "no_recruitable_population":"无可转化人口", "attention_focus_capacity":"重点名额不足", "paid_pending_final_check":"已预付，仍待轮末重验", "Income and paid anchor activation still depend on shared evolution and revalidation; future income is unavailable for prepay.":"预计收入和锚点恢复仍取决于本轮演化及轮末重验，未来收入不能支付预付。"
}

func _ready() -> void:
	overlay.theme = BasicTheme.create(font_size)
	var background := Panel.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	overlay.add_child(margin)
	var frame := VBoxContainer.new(); margin.add_child(frame)
	_header = _label("邪神苏醒 · 新局或继续", true); _header.custom_minimum_size.y = 66; frame.add_child(_header)
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; frame.add_child(body)
	var nav_scroll := ScrollContainer.new(); nav_scroll.custom_minimum_size.x = 152; nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; nav_scroll.follow_focus = true; body.add_child(nav_scroll)
	_nav = VBoxContainer.new(); _nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nav_scroll.add_child(_nav)
	for title: String in ["事件", "祈求", "权能", "圣物", "经营", "注意力", "时空", "人物", "机构", "结果", "编年史", "菜单"]:
		var button := _button(title, func() -> void: show_page(title)); button.name = "Nav" + title; _nav.add_child(button)
	var list_scroll := ScrollContainer.new(); list_scroll.custom_minimum_size.x = 280; list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; list_scroll.follow_focus = true; body.add_child(list_scroll)
	_list_scroll = list_scroll
	_items = VBoxContainer.new(); _items.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list_scroll.add_child(_items)
	var decision := VBoxContainer.new(); decision.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(decision)
	_detail_scroll = ScrollContainer.new(); _detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; decision.add_child(_detail_scroll)
	_detail = VBoxContainer.new(); _detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _detail_scroll.add_child(_detail)
	_detail_scroll.focus_mode = Control.FOCUS_ALL; _detail_scroll.follow_focus = true
	_preview = _label(""); _preview.name = "DecisionPreview"; decision.add_child(_preview)
	_execute = _button("执行所选行动", _on_execute); _execute.name = "Execute"; decision.add_child(_execute)
	_status = _label("Tab / Shift+Tab 移动焦点；Enter / 空格操作；Esc 返回或取消；F5 保存。")
	_status.custom_minimum_size.y = 52; frame.add_child(_status)
	_status.max_lines_visible = 2; _status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_progress = _button("新局或继续", _on_progress); _progress.name = "Progress"; frame.add_child(_progress)
	_confirm = Confirmation.new(); _confirm.confirmed.connect(_accept_confirmation); _confirm.canceled.connect(_cancel_confirmation); overlay.add_child(_confirm)
	_confirmation_body = _confirm.body
	refresh()
	if session.turn == null: _seed.call_deferred("grab_focus")

func _label(value: String, heading: bool = false) -> Label:
	var label := Label.new(); label.text = value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if heading: label.theme_type_variation = "Heading"
	return label

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = value; button.custom_minimum_size.y = BasicTheme.BUTTON_MIN_HEIGHT; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; button.pressed.connect(callback)
	return button

func _clear(container: Node) -> void:
	for child: Node in container.get_children(): container.remove_child(child); child.queue_free()

func show_page(title: String) -> void:
	if title == "菜单" and page != "菜单": _menu_return = page
	_page_positions[page] = {"selected": selected_key, "selection": selection.duplicate(true), "scroll": _detail_scroll.scroll_vertical, "list_scroll": _list_scroll.scroll_vertical}
	page = title; selected_key = ""; selection = {}; history_cursor = 0; history_stack.clear(); _detail_open = true; refresh()
	if _page_positions.has(title):
		selected_key = _page_positions[title].selected; selection = _page_positions[title].selection.duplicate(true); refresh(); _detail_scroll.set_deferred("scroll_vertical", _page_positions[title].scroll); _list_scroll.set_deferred("scroll_vertical", _page_positions[title].list_scroll)

func refresh() -> void:
	projection = session.project()
	if page == "经营": _draft_plan = projection.get("economy_plan", {}).duplicate(true)
	var active: bool = projection.get("active", false)
	_header.text = "邪神苏醒 · 新局或继续"
	if active:
		_header.text = "第 %d 轮 · %s\n苏醒  %d     信仰  %d / %d     低语  %d     洞见  %d     创伤  %d" % [projection.turn, projection.phase_title, projection.awakening, projection.faith, projection.capacity, projection.whispers, projection.insight, projection.wounds]
		if projection.disconnected > 0: _header.text += "\n断联 %d / %d 轮" % [projection.disconnected, session.catalog.integer("disconnection_limit")]
		elif not projection.manifest.is_empty(): _header.text += "\n降临 %d / %d 轮 · 本轮%s支付" % [projection.manifest.progress, session.catalog.integer("manifest_duration"), "已" if projection.manifest.paid_turn == projection.turn else "尚未"]
		elif not projection.resistance.is_empty(): _header.text += "\n已知抵抗 %d 项 · 时空页查看目标与期限" % projection.resistance.size()
	_progress.disabled = not active or projection.get("terminal", false) or _working
	_progress.text = {"events":"承受剩余事件并进入行动", "actions":"轮末预览 / 结束回合", "between":"进入下一轮", "ended":"本局已封存 · 可回顾或重开"}.get(str(projection.get("phase", "")), "继续结算")
	if active and projection.phase == "events" and not projection.events.any(func(event: Dictionary) -> bool: return not event.resolved): _progress.text = "进入行动"
	_progress.visible = active
	for child: Button in _nav.get_children(): child.theme_type_variation = "SelectedAction" if child.text == page else ""
	_clear(_items); rows = []
	if active and page in ["事件", "祈求", "权能", "圣物", "注意力"]:
		for row: Dictionary in session.action_catalog(selection):
			if (page == "事件" and row.key.begins_with("event/")) or (page == "祈求" and row.key.begins_with("prayer/")) or (page == "权能" and row.key.begins_with("POWER_")) or (page == "圣物" and (row.key.begins_with("relic/") or row.key.begins_with("opportunity/"))) or (page == "注意力" and row.key.begins_with("attention/")): rows.append(row)
		if page == "圣物":
			for object: Dictionary in projection.relics: rows.append({"key":object.id, "title":"查看 · " + str(object.get("name", object.id)), "object":object})
	elif active:
		var collection: String = {"时空":"domains", "人物":"people", "机构":"institutions"}.get(page, "")
		if not collection.is_empty():
			for object: Dictionary in projection.get(collection, []): rows.append({"key":object.id, "title":object.get("title", object.id), "object":object})
	if not rows.is_empty() and not rows.any(func(row: Dictionary) -> bool: return row.key == selected_key): selected_key = rows[0].key
	for row: Dictionary in rows:
		var key: String = row.key
		var button := _button(("已选 · " if key == selected_key else "") + row.title, func() -> void: _select_item(key))
		button.name = "Item" + str(_items.get_child_count()); button.theme_type_variation = "SelectedAction" if key == selected_key else ""; _items.add_child(button)
	if rows.is_empty(): _items.add_child(_label("当前没有可显示的条目。\n" + ("本局已封存，仍可查看对象和编年史。" if projection.get("terminal", false) else "可查看其他页面或继续回合。")))
	_render_detail()
	if active and not projection.get("terminal", false) and overlay.get_viewport().gui_get_focus_owner() == null:
		_progress.call_deferred("grab_focus")

func _select_item(key: String) -> void:
	selected_key = key; selection = {}; _completed_choice = ""; _detail_open = true
	for index: int in range(_items.get_child_count()):
		if index < rows.size():
			var button: Button = _items.get_child(index); button.text = ("已选 · " if rows[index].key == key else "") + rows[index].title; button.theme_type_variation = "SelectedAction" if rows[index].key == key else ""
	_detail_scroll.scroll_vertical = 0; _render_detail()

func _selected_row() -> Dictionary:
	for row: Dictionary in rows:
		if row.key == selected_key and row.has("object"): return row
	for row: Dictionary in session.action_catalog(selection) if page in ["事件", "祈求", "权能", "圣物", "注意力"] else rows:
		if row.key == selected_key: return row
	return {}

func _render_detail(focus_field: String = "") -> void:
	var scroll: int = _detail_scroll.scroll_vertical
	_clear(_detail); _execute.visible = false; _execute.disabled = true; _preview.text = ""
	if page == "菜单": _render_menu(); return
	if not projection.get("active", false): _detail.add_child(_label("先在菜单开启新局或继续存档。", true)); return
	if not _detail_open: _detail.add_child(_label("从原列表选择条目，继续查看或预览。")); return
	if page == "编年史": _render_history(); return
	if page == "经营": _render_economy(focus_field); return
	if page == "结果":
		_detail.add_child(_label("最近一次实际结算", true)); _detail.add_child(_label(describe(projection.last_result))); return
	if page == "注意力": _detail.add_child(_label("当前占用\n" + describe(projection.attention)))
	var row: Dictionary = _selected_row()
	if row.is_empty():
		_detail.add_child(_label("当前阶段没有这类行动。信息查看不会推进回合。", true)); return
	_detail.add_child(_label(row.title, true))
	if row.has("object"):
		var visible: Dictionary = row.object.duplicate(true)
		if page == "人物" and visible.has("insight"): visible["洞察"] = visible.insight; visible.erase("insight")
		_detail.add_child(_label(describe(visible)))
		if page == "时空":
			for plan: Dictionary in projection.resistance:
				if plan.domain == row.object.id: _detail.add_child(_label("已知抵抗预告\n" + describe(plan)))
			for anchor: Dictionary in projection.anchors:
				if anchor.domain == row.object.id: _detail.add_child(_label("锚点\n" + describe(anchor)))
		if page == "机构":
			for anchor: Dictionary in projection.anchors:
				if anchor.get("institution", "") == row.object.id: _detail.add_child(_label("锚点\n" + describe(anchor)))
		return
	# Defaults only choose listed real identities. Rebuild dependent fields once.
	for pass_number: int in range(4):
		var changed: bool = false
		for field: Dictionary in row.fields:
			if not field.optional and not field.multiple and not selection.has(field.key) and not field.options.is_empty(): selection[field.key] = field.options[0].id; changed = true
		if not changed: break
		row = _selected_row()
	for field: Dictionary in row.fields: _render_field(field, focus_field)
	_detail.add_child(_label(describe(row.get("details", {}))))
	var preview: Dictionary = row.preview
	_preview.text = "当前不可执行：" + str(preview.get("error", "条件不满足"))
	if preview.ok:
		var costs: Dictionary = preview.preview
		_preview.text = "本次费用 · 信仰 %s · 低语 %s" % [costs.get("faith", costs.get("faith_cost", 0)), costs.get("whispers", 0)]
		if costs.has("consumes"): _preview.text += "\n必失：" + describe(costs.consumes)
		_detail.add_child(_label("占用与其他后果\n" + describe(costs)))
	if preview.ok and preview.preview.has("outcomes"):
		var odds: Dictionary = preview.preview.outcomes
		_preview.text += "\nd100：深刻成功 %d%% · 成功 %d%% · 失败 %d%% · 灾变 %d%%" % [odds.deep, odds.success, odds.failure, odds.disaster]
	elif preview.ok: _preview.text += "\n确定性操作 · 不投检定骰"
	_execute.visible = true; _execute.disabled = not preview.ok or _working or projection.get("terminal", false)
	if _completed_choice == selected_key + JSON.stringify(selection): _execute.disabled = true
	_execute.text = "执行 · " + row.title
	if not focus_field.is_empty(): _detail_scroll.set_deferred("scroll_vertical", scroll)

func _render_field(field: Dictionary, focus_field: String) -> void:
	_detail.add_child(_label(field.label + ("（可不选）" if field.optional else "")))
	if field.multiple:
		for option: Dictionary in field.options:
			var check := CheckBox.new(); check.name = "Field_" + field.key + "_" + str(option.id); check.text = _identity_title(option); check.button_pressed = option.id in selection.get(field.key, []); check.custom_minimum_size.y = 38; _detail.add_child(check)
			check.toggled.connect(func(on: bool) -> void:
				var chosen: Array = selection.get(field.key, []).duplicate()
				if on: chosen.append(option.id)
				else: chosen.erase(option.id)
				selection[field.key] = chosen; _completed_choice = ""; _render_detail(field.key + "/" + str(option.id)))
			if focus_field == field.key + "/" + str(option.id): check.call_deferred("grab_focus")
		if field.options.is_empty(): _detail.add_child(_label("暂无已知且有效的准备。"))
	else:
		var picker := OptionButton.new(); picker.custom_minimum_size.y = 38; picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; picker.clip_text = true; picker.name = "Field_" + field.key
		picker.add_item("不选" if field.optional else "请选择" ); picker.set_item_metadata(0, "")
		for option: Dictionary in field.options:
			picker.add_item(_identity_title(option)); var index: int = picker.item_count - 1; picker.set_item_metadata(index, option.id)
			if selection.get(field.key, "") == option.id: picker.select(index)
		picker.item_selected.connect(func(index: int) -> void:
			selection[field.key] = picker.get_item_metadata(index); _completed_choice = ""
			# A changed parent may invalidate downstream choices; never silently pay.
			for dependent: String in ["npc", "source", "cult", "anchor", "relic", "target_domain"]:
				if field.key == "domain" and dependent != field.key: selection.erase(dependent)
			_render_detail(field.key))
		_detail.add_child(picker)
		if focus_field == field.key: picker.call_deferred("grab_focus")

func _identity_title(option: Dictionary) -> String:
	for collection: String in ["domains", "people", "relics", "anchors", "cults"]:
		for object: Dictionary in projection.get(collection, []):
			if object.id == option.id: return str(object.get("title", object.get("name", option.label)))
	return str(option.label)

func _render_menu() -> void:
	_detail.add_child(_label("邪神苏醒", true))
	_detail.add_child(_label("新局保留旧局存档。相同种子生成相同初始世界；继续读取上次保存的局。"))
	_detail.add_child(_label("世界种子（整数）"))
	_seed = LineEdit.new(); _seed.name = "Seed"; _seed.text = str(int(Time.get_unix_time_from_system())); _seed.placeholder_text = "整数种子"; _seed.custom_minimum_size.y = 38; _detail.add_child(_seed)
	_detail.add_child(_button("新局", func() -> void:
		if not _seed.text.is_valid_int(): _status.text = "请输入整数种子。"; return
		var seed_value: int = _seed.text.to_int()
		if projection.get("active", false): _ask("保存当前局并开启新局？旧局文件会保留，保存失败时停止。", func() -> void:
			var saved: Dictionary = session.save_game()
			if saved.ok: _start(seed_value)
			else: _feedback(saved))
		else: _start(seed_value)))
	_detail.add_child(_button("继续最近存档", func() -> void: _continue()))
	var saves: Array = session.saved_games()
	if not saves.is_empty():
		_detail.add_child(_label("保存的各局（包括已封存的局）"))
		var picker := OptionButton.new(); picker.name = "SavedGames"; picker.custom_minimum_size.y = 38; picker.clip_text = true
		for saved: Dictionary in saves:
			picker.add_item(saved.title); picker.set_item_metadata(picker.item_count - 1, saved.path)
			if saved.path == session.slot: picker.select(picker.item_count - 1)
		_detail.add_child(picker)
		var load_button := _button("载入所选存档…", func() -> void:
			var path: String = picker.get_selected_metadata()
			if projection.get("active", false): _ask("载入所选旧局？当前保存后的行动会舍弃；如需保留请先返回并保存。", func() -> void: _load_saved(path))
			else: _load_saved(path))
		load_button.name = "LoadSelected"; _detail.add_child(load_button)
	if projection.get("active", false):
		_detail.add_child(_button("保存本局", func() -> void: _feedback(session.save_game())))
		_detail.add_child(_label("本局存档\n" + str(projection.slot)))
		if not projection.terminal: _detail.add_child(_button("自弃本局…", func() -> void: _ask("自弃将立即封存本局，不能继续行动。仍可回顾并另开新局。", func() -> void: _feedback(session.abandon(true)); refresh())))
	_detail.add_child(_label("文字大小（固定画布内滚动）"))
	var size := SpinBox.new(); size.min_value = 18; size.max_value = 28; size.value = font_size; size.custom_minimum_size.y = 38; _detail.add_child(size)
	size.value_changed.connect(func(value: float) -> void: font_size = int(value); overlay.theme = BasicTheme.create(font_size))
	_detail.add_child(_label("键盘：Tab / Shift+Tab 移动焦点；方向键选择；Enter / 空格执行；Esc 取消确认或返回列表；F5 保存。滚动区获得焦点后用方向键或 PageUp / PageDown 阅读。"))
	if projection.get("terminal", false): _detail.add_child(_label("本局封存\n" + describe(projection.outcome), true))

func _start(seed_value: int) -> void:
	var result: Dictionary = session.start_new(seed_value)
	_feedback(result)
	if result.ok: page = "事件"; selected_key = ""; selection = {}; _draft_plan = {}; _page_positions.clear(); _completed_choice = ""
	refresh()

func _continue() -> void:
	if projection.get("active", false):
		_ask("载入最近存档？本次保存后的行动会舍弃。如需保留，请先返回并保存本局。", _load_saved)
	else: _load_saved()

func _load_saved(path: String = "") -> void:
	var result: Dictionary = session.continue_game(path); _feedback(result)
	if result.ok: page = "编年史" if session.project().terminal else ("事件" if session.project().phase == "events" else "祈求"); selected_key = ""; selection = {}; _draft_plan = {}; _page_positions.clear(); _completed_choice = ""
	refresh()

func _ask(text_value: String, callback: Callable) -> void:
	if _working or _confirm.visible: return
	return_focus = overlay.get_viewport().gui_get_focus_owner(); pending = callback
	_confirmation_body.text = text_value; _confirm.popup_centered(Vector2i(720, 400)); _confirm.get_cancel_button().grab_focus()

func _accept_confirmation() -> void:
	var action: Callable = pending; pending = Callable()
	if action.is_valid(): action.call()

func _cancel_confirmation() -> void:
	pending = Callable()
	if is_instance_valid(return_focus): return_focus.call_deferred("grab_focus")

func _on_execute() -> void:
	if _working or _confirm.visible or selected_key.is_empty() or not _detail_open: return
	var chosen_key: String = selected_key; var chosen: Dictionary = selection.duplicate(true)
	if _completed_choice == chosen_key + JSON.stringify(chosen): return
	var preview: Dictionary = session.preview_action(chosen_key, chosen)
	if not preview.ok: _feedback(preview); _render_detail(); return
	var perform := func() -> void:
		if _working: return
		_working = true; _execute.disabled = true; intent_sequence += 1
		var result: Dictionary = session.execute_action(chosen_key, chosen, true, "ui/" + str(Time.get_ticks_usec()) + "/" + str(intent_sequence))
		if result.ok: _completed_choice = chosen_key + JSON.stringify(chosen)
		_working = false; _feedback(result); refresh()
	if preview.irreversible: _ask(_confirmation_text(_selected_row(), preview.preview), perform)
	else: perform.call()

func _confirmation_text(row: Dictionary, preview: Dictionary) -> String:
	var lines: PackedStringArray = ["执行「" + row.title + "」？"]
	var details: Dictionary = row.get("details", {})
	for field: String in ["固定角色", "固定主体", "所在时空", "机构", "不可逆代价", "始终代价", "cost", "always", "回应所得", "effect"]:
		if details.has(field): lines.append(str(WORDS.get(field, field)) + "：" + describe(details[field]))
	lines.append("本次费用 · 信仰 %s · 低语 %s" % [preview.get("faith", preview.get("faith_cost", 0)), preview.get("whispers", 0)])
	if preview.has("consumes"): lines.append("必失对象：" + describe(preview.consumes))
	if preview.has("outcomes"):
		var odds: Dictionary = preview.outcomes
		lines.append("d100：深刻成功 %d%% · 成功 %d%% · 失败 %d%% · 灾变 %d%%" % [odds.deep, odds.success, odds.failure, odds.disaster])
	return "\n".join(lines)

func _on_progress() -> void:
	if _working or _confirm.visible or session.turn == null: return
	if projection.phase == "actions":
		_ask("结束本轮行动？先付费用，演化后才结算条件性收入。\n" + describe(session.economy_preview().get("preview", {})), func() -> void: _advance(true))
	elif projection.phase == "events" and projection.events.any(func(event: Dictionary) -> bool: return not event.resolved):
		_ask("承受未选择事件的默认后果并进入行动？", func() -> void: _advance(false))
	else: _advance(false)

func _advance(confirmed: bool) -> void:
	if _working: return
	_working = true
	var before: Dictionary = session.project()
	var result: Dictionary = session.progress(confirmed)
	while result.ok and session.project().phase in ["evolution", "settlement", "ending"]: result = session.progress()
	_add_visible_changes(result, before, session.project())
	_working = false; _feedback(result)
	if result.ok:
		page = "菜单" if session.project().terminal else ("事件" if session.project().phase == "events" else "祈求")
		selected_key = ""; selection = {}
	refresh()

func _add_visible_changes(result: Dictionary, before: Dictionary, after: Dictionary) -> void:
	if not result.ok: return
	result["changes"] = {}
	for field: String in ["faith", "whispers", "awakening", "insight", "wounds"]:
		if before.get(field) != after.get(field): result.changes[field] = {"before":before[field], "after":after[field], "delta":int(after[field]) - int(before[field])}

func _rest_confirmed() -> void:
	if _working: return
	_working = true
	var before: Dictionary = session.project()
	var result: Dictionary = session.rest(true)
	while result.ok and session.project().phase in ["evolution", "settlement", "ending"]: result = session.progress()
	_add_visible_changes(result, before, session.project())
	_working = false; _feedback(result); selected_key = ""; selection = {}
	if result.ok: page = "菜单" if session.project().terminal else "经营"
	refresh()

func _feedback(result: Dictionary) -> void:
	_status.text = "完成。" if result.get("ok", false) else "未执行：" + session.explain_error(str(result.get("error", "未知原因"))).left(100)
	if result.has("changes"):
		for field: String in result.changes: _status.text += " %s %s→%s；" % [WORDS.get(field, field), result.changes[field].before, result.changes[field].after]
	if result.has("autosave") and not result.autosave.get("ok", false): _status.text += " 自动保存失败，请在菜单重试。"
	if result.get("ok", false) and result.has("result") and not result.result.get("checks", []).is_empty():
		var check: Dictionary = result.result.checks[-1]
		_status.text += " d100 %s · %s。" % [check.get("roll", ""), WORDS.get(str(check.get("outcome", "")), check.get("outcome", ""))]

func _render_history() -> void:
	var result: Dictionary = session.history_page(history_cursor, 12)
	_detail.add_child(_label("本局编年史 · 种子 " + str(result.get("seed", "")), true))
	if projection.terminal: _detail.add_child(_label("本局封存\n" + describe(projection.outcome)))
	_detail.add_child(_label("仅列已知记录。未知前因保留未知，不会因浏览而揭示。"))
	for fact: Dictionary in result.get("facts", []):
		_detail.add_child(_label("第 %s 轮 · %s · %s" % [fact.turn, WORDS.get(str(fact.kind), fact.kind), fact.id], true))
		_detail.add_child(_label(describe(fact)))
		for parent: String in fact.get("causal_parents", []):
			if parent == "尚未知晓": continue
			_detail.add_child(_button("查看已知前因 " + parent, func() -> void: _show_fact(parent)))
	var controls := HBoxContainer.new(); _detail.add_child(controls)
	if not history_stack.is_empty(): controls.add_child(_button("上一页", func() -> void: history_cursor = history_stack.pop_back(); _detail_scroll.scroll_vertical = 0; _render_detail()))
	if not result.get("complete", true): controls.add_child(_button("下一页", func() -> void: history_stack.append(history_cursor); history_cursor = result.cursor; _detail_scroll.scroll_vertical = 0; _render_detail()))

func _show_fact(id: String) -> void:
	var cursor: int = 0
	while true:
		var result: Dictionary = session.history_page(cursor, 100)
		for fact: Dictionary in result.get("facts", []):
			if fact.id == id:
				_clear(_detail); _detail.add_child(_label("已知前因 · " + id, true)); _detail.add_child(_label(describe(fact))); _detail.add_child(_button("返回原历史页", func() -> void: _render_detail())); _detail_scroll.scroll_vertical = 0; return
		if result.get("complete", true): break
		cursor = result.cursor

func _render_economy(focus_field: String = "") -> void:
	if _draft_plan.is_empty(): _draft_plan = projection.get("economy_plan", {}).duplicate(true)
	if not _draft_plan.has("strategies"): _draft_plan.strategies = {}
	if not _draft_plan.has("anchor_priority"): _draft_plan.anchor_priority = []
	if not _draft_plan.has("refuse_anchors"): _draft_plan.refuse_anchors = []
	_detail.add_child(_label("轮末经营", true))
	_detail.add_child(_label("当前可用信仰与条件性预计收入分开结算；收入不能支付预付。"))
	for cult: Dictionary in projection.cults:
		_detail.add_child(_label("教团成员与职务\n" + describe(cult)))
		_detail.add_child(_label(str(cult.get("title", cult.id)) + " · 本轮策略"))
		var picker := OptionButton.new(); picker.custom_minimum_size.y = 38
		var options: Array = ["expand", "conceal", "hold"]
		for strategy: String in options: picker.add_item(WORDS[strategy])
		picker.select(options.find(_draft_plan.strategies.get(cult.id, cult.get("strategy", "hold"))))
		picker.item_selected.connect(func(index: int) -> void: _draft_plan.strategies[cult.id] = options[index]; _render_detail("strategy/" + cult.id))
		_detail.add_child(picker)
		if focus_field == "strategy/" + cult.id: picker.call_deferred("grab_focus")
	for anchor: Dictionary in projection.anchors:
		if not anchor.id in _draft_plan.anchor_priority: _draft_plan.anchor_priority.append(anchor.id)
	for index: int in range(_draft_plan.anchor_priority.size()):
		var id: String = _draft_plan.anchor_priority[index]
		var line := HBoxContainer.new(); _detail.add_child(line)
		var refuse := CheckBox.new(); refuse.text = "%d · %s · 拒付供奉" % [index + 1, id]; refuse.button_pressed = id in _draft_plan.refuse_anchors; refuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(refuse)
		refuse.toggled.connect(func(on: bool) -> void:
			if on: _draft_plan.refuse_anchors.append(id)
			else: _draft_plan.refuse_anchors.erase(id)
			_render_detail("refuse/" + id))
		if focus_field == "refuse/" + id: refuse.call_deferred("grab_focus")
		var up := _button("提前", func() -> void: var previous: Variant = _draft_plan.anchor_priority[index - 1]; _draft_plan.anchor_priority[index - 1] = id; _draft_plan.anchor_priority[index] = previous; _render_detail("priority/" + id)); up.disabled = index == 0; line.add_child(up)
	var preview: Dictionary = session.preview_plan(_draft_plan)
	_detail.add_child(_label("本轮计划预览\n" + describe(preview.get("preview", {"error":preview.get("error", "")}))))
	var apply := _button("保存本轮经营计划", func() -> void: var result: Dictionary = session.set_plan(_draft_plan); _feedback(result); refresh())
	apply.disabled = not preview.ok or projection.phase != "actions" or projection.terminal; _detail.add_child(apply)
	if projection.cults.is_empty():
		_detail.add_child(_label("尚无已知教团。自然成团需要同一时空至少 %d 名无名信众、累计 %d 信仰的真实本地支出，以及忠诚至少 %d、有实际献身意愿且满足成员名额的合格人物。条件在轮末复查。" % [session.catalog.integer("cult_form_followers"), session.catalog.integer("cult_form_local_spend"), session.catalog.integer("cult_form_loyalty")]))
	_detail.add_child(_label("敛息会放弃本轮全部回应、权能与圣物行动，并立即结束行动。"))
	var rest: Dictionary = session.rest()
	_detail.add_child(_label(describe(rest.get("preview", {})) if rest.get("confirmation", false) else _rest_reason(str(rest.get("error", "")))))
	var button := _button("敛息…", func() -> void: _ask("确认敛息？\n" + describe(rest.get("preview", {})), _rest_confirmed))
	button.disabled = not rest.get("confirmation", false); _detail.add_child(button)
	_detail.add_child(_label("苏醒来源\n" + describe(projection.awakening_sources)))

func _rest_reason(reason: String) -> String:
	return {"Rest requires an unused prayer, power and relic window":"本轮已回应祈求或使用权能／圣物，不能敛息。", "There are no wounds to recover":"当前没有可恢复的创伤。", "Insufficient faith for rest":"信仰不足，无法支付敛息。", "Rest is only available in the action phase":"只能在行动阶段敛息。"}.get(reason, session.explain_error(reason))

func describe(value: Variant, depth: int = 0) -> String:
	if value == null: return "未掌握"
	if value is bool: return "是" if value else "否"
	if value is Dictionary:
		var lines: PackedStringArray = []
		for key: Variant in value:
			if str(key) in ["outcomes", "key", "ok", "preview", "descriptor", "issuer", "version", "declaration", "source_ids", "once_key", "mutex", "sample", "basis"]: continue
			lines.append(str(WORDS.get(str(key), key)) + "：" + describe(value[key], depth + 1))
		return "\n".join(lines) if not lines.is_empty() else "无"
	if value is Array:
		var lines: PackedStringArray = []
		for item: Variant in value: lines.append(describe(item, depth + 1))
		return ("\n" if depth < 2 else "、").join(lines) if not lines.is_empty() else "无"
	if value is String:
		for collection: String in ["domains", "people", "institutions", "relics", "cults", "anchors"]:
			for object: Dictionary in projection.get(collection, []):
				if object.id == value: return str(object.get("title", object.get("name", value)))
		if session.catalog != null:
			for table: String in ["prayers", "events", "powers", "npc_profiles", "civilization_profiles"]:
				if session.catalog.tables.get(table, {}).has(value):
					var entry: Dictionary = session.catalog.tables[table][value]
					return str(entry.get("title", entry.get("name", value)))
		if value.begins_with("BACKGROUND-"): return "诉求 " + value.trim_prefix("BACKGROUND-")
	return str(WORDS.get(str(value), {"BG_CONTACT":"当下求告", "BG_ESCAPE":"屏障往来", "BG_RECORD":"已知记录", "BG_RITUAL":"当前祭仪", "candidate":"诉求实例", "template":"处境类型", "content_id":"事由"}.get(str(value), str(value))))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F5:
		_feedback(session.save_game()); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and not _confirm.visible:
		if overlay.get_viewport().gui_get_focus_owner() is LineEdit: return
		if page == "菜单" and projection.get("active", false): show_page(_menu_return)
		elif _detail_open and not rows.is_empty():
			_detail_open = false; _render_detail()
			for index: int in range(rows.size()):
				if rows[index].key == selected_key: _items.get_child(index).grab_focus(); break
		else: show_page("菜单")
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] and not _confirm.visible:
		_detail_scroll.scroll_vertical += -300 if event.keycode == KEY_PAGEUP else 300
		get_viewport().set_input_as_handled()
