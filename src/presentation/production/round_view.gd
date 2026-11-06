extends Control
## Production view. Decisions and persistence go through Session.
const Session = preload("res://src/presentation/session.gd")
const TaskView = preload("res://src/presentation/production/task_view.gd")
const Views = preload("res://src/presentation/experience_views.gd")
const Actions = preload("res://src/presentation/experience_actions.gd")
const Feedback = preload("res://src/presentation/experience_feedback.gd")
const Composites = preload("res://src/presentation/ui/ui_composites.gd")
const Dock = preload("res://src/presentation/ui/dock_content.gd")
const UI = preload("res://src/presentation/ui/ui_components.gd")
const WorldManagement = preload("res://src/presentation/production/world_management.gd")
const PrayerView = preload("res://src/presentation/production/prayer_view.gd")
const RoundAction = preload("res://src/presentation/ui/round_action_button.gd")
const Motion = preload("res://src/presentation/ui/motion.gd")
const Veil = preload("res://src/presentation/ui/opening_veil.gd")
const VIEW := Vector2(1280, 720)
const ART := "res://docs/art/echoes-ui/round-start-master/"
const DISPLAY_SETTINGS := "user://echoes-display.cfg"
const SAVE_DIRECTORY := "user://production-ui-campaigns"
const INTERNAL_PHASES := ["between", "evolution", "settlement", "ending"]

var session: RefCounted = Session.new(SAVE_DIRECTORY)
var projection: Dictionary = {}
var _tasks := TaskView.new(self)
var _world_management := WorldManagement.new(self)
var _prayers := PrayerView.new(self)
var _views := Views.new()
var _actions := Actions.new()
var _feedback := Feedback.new()
var _ui: RefCounted
var _motion := Motion.new()
var _large_text := false
var _keyboard := false
var _busy := false
var _stage: Control
var _surface: Control
var _body: VBoxContainer
var _body_scroll: ScrollContainer
var _footer: HBoxContainer
var _dialog := ""
var _return_focus: Control
var _phase_plate: Button
var _menu_button: Button
var _worlds: Array = []
var _world_id := ""
var _world_query := ""
var _world_matches: Label
var _world_body: Control
var _world_buttons: Dictionary = {}
var _world_scroll: ScrollContainer
var _receipt: Array[String] = []
var _resource_delta := ""
var _notice: Label
var _notice_text := ""
var _notice_color := UI.RISK
var _event_key := ""
var _event_scroll := 0
var _event_selection: Dictionary = {}

func _ready() -> void:
	var window := get_window()
	window.title = "邪神苏醒 · 幽界群像"
	var settings := ConfigFile.new()
	if settings.load(DISPLAY_SETTINGS) == OK:
		_large_text = bool(settings.get_value("display", "large_text", false))
	_apply_window_mode(bool(settings.get_value("display", "fullscreen", false)))
	window.focus_exited.connect(func(): _set_keyboard(false))
	add_child(_motion)
	_ui = UI.new(null, func() -> bool: return _keyboard)
	var base := Theme.new()
	base.default_font = _ui.fonts.body
	base.set_color("font_color", "Label", UI.BONE)
	base.set_stylebox("separator", "HSeparator", StyleBoxEmpty.new())
	theme = base
	_refresh()
	_show_menu()

func _apply_window_mode(fullscreen: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	var window := get_window()
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if fullscreen: return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var available := usable.size - Vector2i(32, 96)
	var width := mini(1920 if available.x >= 1920 and available.y >= 1080 else 1280, mini(available.x, available.y * 16 / 9))
	window.size = Vector2i(width, width * 9 / 16)
	window.move_to_center()

func _write_display_settings() -> void:
	var settings := ConfigFile.new()
	settings.set_value("display", "large_text", _large_text)
	settings.set_value("display", "fullscreen", get_window().mode == Window.MODE_FULLSCREEN)
	if settings.save(DISPLAY_SETTINGS) != OK:
		_notice_text = "无法保存显示设置。"

func _show_settings() -> void:
	_open_surface("settings", "显示", "显示设置")
	var text := _button(_body, "TextSize", "文字 · " + ("放大" if _large_text else "标准"), Rect2(), func() -> void:
		_large_text = not _large_text
		_write_display_settings()
		_refresh()
		_show_settings()
		_body.get_node("TextSize").grab_focus())
	text.custom_minimum_size.y = 42
	var fullscreen := get_window().mode == Window.MODE_FULLSCREEN
	var mode := _button(_body, "WindowMode", "显示 · " + ("全屏" if fullscreen else "窗口"), Rect2(), func() -> void:
		_apply_window_mode(not fullscreen)
		_write_display_settings()
		_show_settings()
		_body.get_node("WindowMode").grab_focus())
	mode.custom_minimum_size.y = 42
	if not _notice_text.is_empty(): _line(_body, _notice_text, 16, _notice_color)
	_footer_button("Return", "返回菜单", _show_menu).grab_focus()

func title(id: String) -> String:
	return session.object_title(id)

func _size(standard: int) -> int:
	return standard + (3 if _large_text else 0)

func _text(parent: Node, value: String, bounds: Rect2, font_size: int, color: Color = UI.BONE) -> Label:
	return _ui.label(parent, "Text", value, bounds, _size(font_size), color, false, true)

func _line(parent: Container, value: String, font_size: int = 17, color: Color = UI.BONE) -> Label:
	var line := Label.new()
	line.text = value
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", _size(font_size))
	line.add_theme_color_override("font_color", color)
	parent.add_child(line)
	return line

func _button(parent: Node, node_name: String, caption: String, bounds: Rect2, handler: Callable, primary := false) -> Button:
	return _ui.button(parent, node_name, caption, bounds, handler, primary, not primary, _size(17))

func _region(parent: Node, node_name: String, bounds: Rect2) -> Control:
	var region := Control.new()
	region.name = node_name
	_ui.rect(region, bounds)
	parent.add_child(region)
	return region

func _scroller(parent: Control, bounds: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	_ui.rect(scroll, bounds)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	parent.add_child(scroll)
	var bar := scroll.get_v_scroll_bar()
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 6
	bar.add_theme_stylebox_override("scroll", track)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color(UI.GOLD, 0.35 if state == "grabber" else 0.65)
		grip.set_corner_radius_all(3)
		grip.content_margin_left = 6
		bar.add_theme_stylebox_override(state, grip)
	return scroll

func _refresh() -> void:
	projection = session.project()
	var scroll_position := _world_scroll.scroll_vertical if is_instance_valid(_world_scroll) else 0
	var return_path := NodePath()
	if is_instance_valid(_stage):
		if is_instance_valid(_return_focus) and _stage.is_ancestor_of(_return_focus):
			return_path = _stage.get_path_to(_return_focus)
		remove_child(_stage)
		_stage.queue_free()
	_stage = _region(self, "Perception", Rect2(Vector2.ZERO, VIEW))
	move_child(_stage, 0)
	_ui.image(_stage, "Sea", Rect2(Vector2.ZERO, VIEW), _ui.texture(ART + "restoration-assets/sea-mist.png"), Color.WHITE, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	# Distant fragments keep the approved common scene, without object controls.
	var fragments := [Rect2(335,192,149,113),Rect2(1113,274,143,88),Rect2(1345,465,179,108),Rect2(267,464,121,88)]
	for index: int in fragments.size():
		var crop: Rect2 = fragments[index]
		var fragment: TextureRect = _ui.image(_stage, "DistantFragment", Rect2(crop.position * 0.766, crop.size * 0.766), _ui.skin.source_region(crop))
		fragment.material = _ui.fragment_material(crop, 0.30, 0.78)
	_ui.gradient(_stage, "LeftShade", Rect2(0, 38, 245, 545), Color(0.005, 0.014, 0.017, 0.93), Color(0.005, 0.014, 0.017, 0), true)
	_ui.gradient(_stage, "RightShade", Rect2(980, 38, 300, 545), Color(0.005, 0.014, 0.017, 0), Color(0.005, 0.014, 0.017, 0.88), true)
	_build_top()
	_build_dock()
	if projection.get("active", false):
		_build_worlds()
		_world_scroll.set_deferred("scroll_vertical", scroll_position)
		_build_prayers()
	else:
		_text(_stage, "幽界群像", Rect2(479, 268, 322, 62), 43, UI.GOLD_HI).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not return_path.is_empty(): _return_focus = _stage.get_node_or_null(return_path) as Control

func _build_top() -> void:
	var top := _region(_stage, "Top", Rect2(0, 0, 1280, 40))
	_ui.fill(top, "Material", Rect2(0, 0, 1280, 25), Color(0.008, 0.018, 0.020, 0.79))
	_ui.gradient(top, "Fade", Rect2(0,25,1280,20), Color(0.008,0.018,0.020,0.79), Color(0.008,0.018,0.020,0))
	_ui.separator(top, "MetalEdge", Rect2(0, 35, 1280, 5), "top")
	var active: bool = projection.get("active", false)
	_text(top, "第%s回合 · %s" % [projection.turn, projection.phase_title] if active else "幽界群像", Rect2(22, 0, 234, 36), 17, UI.GOLD_HI)
	if active:
		var resources := [["whispers", "低语", str(projection.whispers)], ["faith", "信仰", "%s/%s" % [projection.faith, projection.capacity]], ["awakening", "苏醒", str(projection.awakening)]]
		for index in resources.size():
			var readout: Array = resources[index]
			var x := 268 + index * 148
			_ui.icon(top, "ResourceIcon", readout[0], Rect2(x, 6, 23, 25))
			_text(top, readout[1] + " " + readout[2], Rect2(x + 28, 0, 120, 36), 17)
		var entries: Array = [
			["CultIndex", "教团", _tasks.open_subject.bind("cults", ""), "教团 %d" % projection.cults.size()],
			["RelicIndex", "圣物", _tasks.open_subject.bind("relics", ""), "圣物 %d" % projection.relics.filter(func(item: Dictionary) -> bool: return item.get("placement") != "consumed").size()],
			["WorldArchive", "世界档案", _world_management.open_archive, "检索全部已知世界 · %d" % projection.domains.size()],
			["People", "人物", _tasks.open_subject.bind("people", ""), "查看已知人物"],
			["Attention", "关注", _tasks.open_subject.bind("attention", ""), "关注 %s/%s" % [projection.attention.focus, projection.attention.limits.focus]],
			["Budget", "收支", _tasks.open_subject.bind("budget", ""), "安排本轮支出与供奉"],
			["Self", "本体", _tasks.open_subject.bind("self", ""), "查看苏醒与降临"]
		]
		for index: int in entries.size():
			var entry: Array = entries[index]
			_top_entry(top, entry[0], entry[1], 708 + index * 70, 70, entry[2]).tooltip_text = entry[3]
	_menu_button = _top_entry(top, "Menu", "菜单", 1212, 56, _show_menu)

func _open_activities() -> void:
	_tasks.open_activities(_world_id)

func _top_entry(top: Control, node_name: String, caption: String, x: int, width: int, callback: Callable) -> Button:
	var control := _button(top, node_name, caption, Rect2(x, 3, width, 31), callback)
	control.add_theme_font_size_override("font_size", _size(14))
	return control

func _build_dock() -> void:
	var dock := _region(_stage, "Dock", Rect2(0, 582, 1280, 138))
	_ui.fill(dock, "Material", Rect2(0, 0, 1280, 138), Color(0.006, 0.016, 0.018, 0.78))
	_ui.separator(dock, "UpperEdge", Rect2(0, 0, 1280, 5), "dock_top")
	_ui.separator(dock, "LowerEdge", Rect2(0, 133, 1280, 5), "dock_bottom")
	if projection.get("active", false):
		_text(dock, "权能", Rect2(16, 36, 49, 27), 17, UI.GOLD)
		var powers: Dictionary = Dock._scroll(_ui, dock, "PowerScroll", Rect2(105, 15, 469, 79))
		var unlocked := 0
		for icon_key: String in UI.POWER_ICONS:
			var key := "POWER_" + icon_key.to_upper()
			var data: Dictionary = session.catalog.tables.powers[key]
			var locked := int(data.unlock_awakening) > int(projection.awakening)
			if not locked: unlocked += 1
			var item: Button = Dock.power_entry(_ui, powers.row, key, data, locked, _show_power_reference.bind(key))
			Dock.fit_entry(item, 0.76, 2 if _large_text else 0)
			item.tooltip_text = "需苏醒 %s" % data.unlock_awakening if locked else str(data.name)
			item.mouse_default_cursor_shape = Control.CURSOR_HELP
			Dock.bind_icon(item, item.get_node("Icon"), func() -> bool: return _keyboard, powers.scroll)
		_text(dock, "%d/12" % unlocked, Rect2(65, 39, 39, 23), 12, UI.MUTED)
		_text(dock, "圣物", Rect2(603, 36, 53, 27), 17, UI.GOLD)
		var relics: Array = projection.relics.filter(func(r: Dictionary) -> bool: return r.get("placement") != "consumed")
		if relics.is_empty():
			_text(dock, "尚无圣物", Rect2(681, 32, 220, 38), 16, UI.MUTED)
		else:
			var collection: Dictionary = Dock._scroll(_ui, dock, "RelicScroll", Rect2(669, 15, 405, 79))
			for index: int in relics.size():
				var relic: Dictionary = relics[index]
				var art_index: int = Dock.RELIC_IDS.find(str(relic.get("type", "")))
				var definition: Dictionary = session.catalog.tables.relics.get(relic.get("type", ""), {})
				var state: String = Views.PLACEMENTS.get(relic.get("placement", ""), "未掌握")
				var serial: String = str(relic.id).trim_prefix("RELIC/FACT-")
				serial = str(serial.to_int()) if serial.is_valid_int() else "实例"
				var item: Button = Dock.relic_entry(_ui, collection.row, index, definition.get("name", "圣物"), state, _show_relic_reference.bind(relic.id), art_index if art_index >= 0 else 4, serial)
				Dock.fit_entry(item, 0.76, 2 if _large_text else 0)
				item.tooltip_text = "%s · %s" % [title(relic.id), state]
				Dock.bind_icon(item, item.get_node("Icon"), func() -> bool: return _keyboard, collection.scroll)
	_ui.icon(dock, "ReceiptIcon", "history", Rect2(18, 104, 23, 22))
	_button(dock, "History", "编年史", Rect2(12, 100, 123, 31), _tasks.open_subject.bind("history", ""))
	var chronicle: Button = dock.get_node("History")
	chronicle.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var emblem: Control = dock.get_node("ReceiptIcon")
	dock.move_child(emblem, chronicle.get_index())
	if not _receipt.is_empty(): _button(dock, "Receipt", "回执", Rect2(1019, 100, 64, 31), _show_receipt)
	var summary := "静候世界的回响。"
	if projection.get("active", false):
		summary = "尚有 %d 项事件待处理。" % _pending_events().size() if projection.phase == "events" else "本轮尚无行动回执。"
	if not _receipt.is_empty(): summary = _receipt[0] + (" · " + _resource_delta if not _resource_delta.is_empty() else "")
	_notice = _text(dock, _notice_text if not _notice_text.is_empty() else summary, Rect2(155, 100, 853, 31), 15)
	_notice.autowrap_mode = TextServer.AUTOWRAP_OFF
	_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_notice.tooltip_text = _notice.text
	_notice.add_theme_color_override("font_color", _notice_color if not _notice_text.is_empty() else UI.BONE)
	_phase_plate = null
	if not projection.get("active", false): return
	var caption: String = {"events": "恢复事件", "actions": "结束本轮", "ended": "回顾本局"}.get(str(projection.phase), "继续轮次")
	var plate := RoundAction.new()
	plate.name = "PhaseAction"
	plate.caption = caption
	plate.caption_size = _size(18)
	plate.accessibility_name = caption
	plate.tooltip_text = caption
	plate.keyboard_focus_query = func() -> bool: return _keyboard
	_ui.rect(plate, Rect2(1110, 15, 170, 115))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.pressed.connect(_phase_intent)
	dock.add_child(plate)
	_phase_plate = plate

func _show_power_reference(id: String) -> void:
	if id == "POWER_MANIFEST":
		_tasks.open_subject("self")
		return
	_tasks.open_action(id)

func _show_relic_reference(id: String) -> void:
	_tasks.open_subject("relic", id)

func _world_picture(id: String) -> Texture2D:
	# Art slots are illustrative, never a claim about the world's actual culture.
	for prayer: Dictionary in _pending_prayers():
		if str(prayer.descriptor.get("domain", "")) == id: return _prayers.picture(prayer)
	return _ui.skin.source_region(Rect2(480,270,610,264))

func _build_worlds() -> void:
	var cues: Dictionary = {}
	for prayer: Dictionary in _pending_prayers():
		cues[str(prayer.descriptor.get("domain", prayer.card.get("domain", "")))] = true
	_worlds = projection.domains.filter(func(world: Dictionary) -> bool:
		return world.get("focused", false) or cues.has(world.id))
	if not _worlds.any(func(world: Dictionary) -> bool: return world.id == _world_id):
		_world_id = str(_worlds[0].id) if not _worlds.is_empty() else ""
	_text(_stage, "世界", Rect2(26, 49, 68, 31), 23, UI.GOLD)
	_text(_stage, "关注与祈求线索", Rect2(99, 52, 141, 29), 13, UI.MUTED)
	var search: LineEdit = _ui.search_field(_stage, "WorldSearch", "查找已联系世界", Rect2(23, 85, 210, 30))
	search.add_theme_font_size_override("font_size", _size(14))
	search.text = _world_query
	_ui.icon(search, "SearchSign", "search", Rect2(8,7,17,17))
	search.text_changed.connect(_filter_worlds)
	_world_scroll = _scroller(_stage, Rect2(20, 123, 220, 286))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	_world_scroll.add_child(rows)
	_world_buttons.clear()
	for world: Dictionary in _worlds:
		var source := "已关注" if world.get("focused", false) else "祈求所指 · 有限线索"
		var cult: Dictionary = _views._current_cult(self, world.id)
		if not cult.is_empty(): source = "已知教团 · " + _views._strategy_name(str(projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy)))
		var row := Composites.world_entry(_ui, rows, "World_" + world.id, {"name":world.title,"hint":source,"tag":"场景示意"}, _world_picture(world.id), _inspect_world.bind(world.id), 0.80, 3 if _large_text else 0)
		row.accessibility_name = world.title
		_world_buttons[world.id] = row
	_world_matches = _text(_stage, "", Rect2(26, 416, 208, 30), 13, UI.MUTED)
	_filter_worlds(_world_query)
	_world_body = null
	_select_world(_world_id)

func _filter_worlds(query: String) -> void:
	_world_query = query
	var matches := 0
	for id: String in _world_buttons:
		var row: Button = _world_buttons[id]
		row.visible = query.strip_edges().is_empty() or (title(id) + " " + id).contains(query.strip_edges())
		if row.visible: matches += 1
	if is_instance_valid(_world_matches): _world_matches.text = "%d处联系" % matches if matches else "没有匹配的世界"
	_world_scroll.scroll_vertical = 0

func _close_inline() -> void:
	if _dialog == "world_management": _world_management.close()
	elif _dialog in ["prayer_detail", "prayer_person", "prayer_result"]: _prayers.close()

func _inspect_world(id: String) -> void:
	_close_inline()
	_select_world(id)

func _select_world(id: String) -> void:
	_world_id = id
	for other: String in _world_buttons:
		Composites.select_entry(_ui, _world_buttons[other], other == id)
	if is_instance_valid(_world_body):
		_stage.remove_child(_world_body)
		_world_body.queue_free()
	_world_body = _region(_stage, "World", Rect2(258, 49, 719, 515))
	var world: Dictionary = _views._find(self, "domains", id)
	_text(_world_body, str(world.get("title", "世界")), Rect2(0, 4, 154, 42), 14, UI.MUTED)
	_ui.soft_support(_world_body, "WorldBand", Rect2(148,-3,575,58), Color(0.008,0.020,0.023,0.80))
	var fields := [["barrier", "屏障"], ["pollution", "污染"], ["alert", "察觉"], ["stability", "稳定"]]
	for index in fields.size():
		var metric: Array = fields[index]
		var display: Dictionary = _views.metric_display(world, metric[0])
		Composites.metric(_ui, _world_body, str(index), Vector2(157 + index * 140, 0), metric[0], metric[1], display.value, display.source, display.known, 0.75, 2 if _large_text else 0)
	var source := _button(_world_body, "WorldObservations", "世界情报", Rect2(565, 89, 150, 32), _world_management.open_intelligence.bind(id))
	source.add_theme_font_size_override("font_size", _size(14))
	source.disabled = world.is_empty()
	var cult: Dictionary = _views._current_cult(self, id)
	if world.is_empty():
		_text(_world_body, "当前没有已关注世界或祈求线索。", Rect2(140, 200, 460, 54), 17, UI.MUTED)
		return
	_button(_world_body, "Activities", "当地活动", Rect2(148, 89, 124, 32), _open_activities)
	_button(_world_body, "AnchorIndex", "锚点与护持", Rect2(280, 89, 144, 32), _tasks.open_subject.bind("anchors", id))
	_button(_world_body, "MaterialTransfer", "交予记录", Rect2(432, 89, 128, 32), _tasks.open_action.bind("cults/transfer_material", {"domain":id}))
	var opportunities: Array = _views.current_opportunities(self, id)
	if not opportunities.is_empty():
		var soonest: int = int(opportunities[0].get("changes", {}).get("due", projection.turn))
		for opportunity: Dictionary in opportunities: soonest = mini(soonest, int(opportunity.get("changes", {}).get("due", soonest)))
		var due: String = "本轮到期" if soonest == int(projection.turn) else "最近第 %d 轮到期" % soonest
		var notice := _button(_world_body, "WorldOpportunities", "限时圣物机会 %d · %s  ›" % [opportunities.size(), due], Rect2(148, 130, 567, 32), _tasks.open_subject.bind("opportunities", id))
		notice.add_theme_color_override("font_color", UI.GOLD_HI)
	var art: TextureRect = _ui.image(_world_body, "SceneSlot", Rect2(109, 158, 467, 202), _ui.skin.source_region(Rect2(480,270,610,264)), Color.WHITE)
	art.material = _ui.fragment_material(Rect2(480,270,610,264), 0.12, 1.0)
	art.set_meta("subject_id", id)
	_ui.soft_support(_world_body, "SubjectSupport", Rect2(156, 365, 490, 98), Color(0.008,0.016,0.018,0.70))
	_ui.icon(_world_body, "WorldSigil", "world", Rect2(186, 377, 37, 37))
	_text(_world_body, _views._cult_name(self, cult) if not cult.is_empty() else world.title, Rect2(230, 372, 302, 34), 19, UI.GOLD_HI)
	if cult.is_empty():
		_text(_world_body, "尚无已知教团", Rect2(230, 408, 285, 27), 15, UI.MUTED)
	else:
		_text(_world_body, "信众 %s  ·  凝聚 %s" % [cult.followers, cult.cohesion], Rect2(230, 407, 274, 27), 15)
		var order: String = projection.economy_plan.get("strategies", {}).get(cult.id, cult.strategy)
		_text(_world_body, "本轮指令 · " + _views._strategy_name(order), Rect2(230, 436, 270, 24), 14, UI.GOLD)
		var manage := _button(_world_body, "LocalCult", "管理教团", Rect2(477, 396, 145, 38), _world_management.open_cult.bind(id))
		manage.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_ui.icon(manage, "ManagementIcon", "management", Rect2(9,8,28,22))
	_text(_world_body, "场景示意", Rect2(530, 455, 122, 24), 12, UI.MUTED)

func _pending_prayers() -> Array:
	return projection.get("prayers", []).filter(func(prayer: Dictionary) -> bool: return prayer.status == "open")

func _build_prayers() -> void:
	_text(_stage, "待处理祈求", Rect2(1001, 54, 274, 31), 20, UI.GOLD_HI)
	if projection.get("terminal", false):
		_text(_stage, "本局已封存，可从菜单开启新局。", Rect2(1001, 108, 249, 75), 17, UI.MUTED)
		return
	_prayers.build_sidebar()

func _pending_events() -> Array:
	return projection.get("events", []).filter(func(event: Dictionary) -> bool: return not event.resolved)

func _phase_intent() -> void:
	if _busy: return
	_close_inline()
	if is_instance_valid(_surface): return
	match str(projection.get("phase", "")):
		"events": _show_event()
		"actions": _show_end()
		"ended": _tasks.open_subject("ending")
		_: _advance()

func _begin_surface(kind: String, mist := true) -> void:
	var intro_exit := _dialog == "prayer_intro" and not mist
	if not is_instance_valid(_surface):
		_return_focus = get_viewport().gui_get_focus_owner()
	else:
		_remove_surface(intro_exit)
	if not intro_exit:
		for layer: Node in get_children():
			if layer.is_in_group("motion_retiring"):
				remove_child(layer)
				layer.queue_free()
	_dialog = kind
	_surface = Veil.build(self, "Decision", VIEW, _motion) if mist else _region(self, "PrayerStage", Rect2(Vector2.ZERO, VIEW))
	if is_instance_valid(_world_body): _world_body.visible = mist

func _open_surface(kind: String, eyebrow: String, heading: String, event_art := false) -> void:
	_begin_surface(kind)
	var width := 988 if event_art else 778
	var left := (1280 - width) / 2.0
	_ui.soft_support(_surface, "ReadingSupport", Rect2(left - 37, 81, width + 74, 561), Color(0.003, 0.011, 0.014, 0.97))
	var heading_inset := 48 if kind.begins_with("task_") else 0
	var alignment := HORIZONTAL_ALIGNMENT_LEFT if heading_inset > 0 else HORIZONTAL_ALIGNMENT_CENTER
	_text(_surface, eyebrow, Rect2(left + heading_inset, 83, width - heading_inset * 2, 29), 16, UI.CYAN).horizontal_alignment = alignment
	_text(_surface, heading, Rect2(left + heading_inset, 113, width - heading_inset * 2, 73), 29, UI.GOLD_HI).horizontal_alignment = alignment
	var reading_left := left + 48
	if event_art:
		var bounds := Rect2(left + 18, 201, 355, 323)
		var texture: Texture2D = _ui.texture(ART + "assets/abyss-sea.png")
		var art: TextureRect = _ui.image(_surface, "SceneSlot", bounds, texture, Color.WHITE, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		var visible_uv := bounds.size / (texture.get_size() * maxf(bounds.size.x / texture.get_width(), bounds.size.y / texture.get_height()))
		art.material = _ui.feather_material(Rect2((Vector2.ONE - visible_uv) * 0.5, visible_uv), 0.21)
		_text(_surface, "场景示意", Rect2(left + 87, 470, 217, 32), 14, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reading_left = left + 412
	_body_scroll = _scroller(_surface, Rect2(reading_left, 199, left + width - 38 - reading_left, 328))
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_body_scroll.add_child(_body)
	_footer = HBoxContainer.new()
	_ui.rect(_footer, Rect2(left + 44, 535 if kind.begins_with("task_") else 543, width - 88, 42 if kind.begins_with("task_") else 50))
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 15)
	_surface.add_child(_footer)

func _footer_button(node_name: String, caption: String, handler: Callable, primary := false) -> Button:
	var control := _button(_footer, node_name, caption, Rect2(), handler, primary)
	control.custom_minimum_size = Vector2(146, 42)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return control

func _remove_surface(fade: bool) -> void:
	if not is_instance_valid(_surface): return
	if fade:
		# Only the fog leaves gradually. The old content and its input are gone
		# before a new modal or the world can receive focus.
		for child: Node in _surface.get_children():
			if child.name != "Veil":
				_surface.remove_child(child)
				child.queue_free()
		_motion.retire(_surface, float(_motion.params.opening_exit_s))
	else:
		remove_child(_surface)
		_surface.queue_free()
	_surface = null
	_dialog = ""
	if is_instance_valid(_world_body): _world_body.show()

func _close_surface() -> void:
	_remove_surface(_dialog in ["event", "prayer_intro"])
	var target := _return_focus if is_instance_valid(_return_focus) and _return_focus.is_inside_tree() else _phase_plate
	if not is_instance_valid(target): target = _menu_button
	if is_instance_valid(target): target.grab_focus()
	_return_focus = null

func _show_event(return_to_option := false) -> void:
	if _busy or projection.get("phase") != "events": return
	var events := _pending_events()
	if events.is_empty():
		_advance()
		return
	var event: Dictionary = events[0]
	var choices: Array = session.action_catalog({}, str(event.key) + "/")
	_open_surface("event", "第 %s 轮 · 待处理事件 %d 项" % [projection.turn, events.size()], event.title, true)
	_surface.get_node("SceneSlot").set_meta("subject_id", event.id)
	if not choices.is_empty():
		for line: String in _actions.context_lines(choices[0], {}, title, self): _line(_body, line)
	_line(_body, "处理本轮事件后，即可进入神意行动。", 16, UI.MUTED)
	for row: Dictionary in choices:
		var details: Dictionary = row.details
		var button := _button(_body, "Option_" + str(row.key).get_slice("/", 2), details["选项名称"], Rect2(), _review_event.bind(row, true))
		button.custom_minimum_size.y = 42
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line(_body, "%s 信仰 · %s" % [details["信仰费用"], details["选择后果"]], 16)
		if not row.available and row.fields.is_empty():
			_line(_body, session.explain_error(str(row.preview.get("error", ""))), 16, UI.RISK)
	var inspect := _footer_button("InspectWorld", "先查看现状", _close_surface)
	var prior := _body.get_node_or_null("Option_" + _event_key.get_slice("/", 2)) as Button
	if return_to_option and prior != null:
		_body_scroll.set_deferred("scroll_vertical", _event_scroll)
		prior.grab_focus()
	else:
		inspect.grab_focus()
	if not _notice_text.is_empty(): _line(_body, _notice_text, 16, _notice_color)

func _review_event(row: Dictionary, reset: bool) -> void:
	_tasks.begin_candidates()
	_actions._source_cache.clear()
	if reset: _event_scroll = _body_scroll.scroll_vertical
	_event_key = row.key
	var selection: Dictionary = _event_selection.get(row.key, {})
	_open_surface("event_review", "第 %s 轮 · 确认事件选择" % projection.turn, row.details["选项名称"])
	for line: String in _actions.context_lines(row, {}, title, self): _line(_body, line, 16, UI.MUTED)
	var complete := true
	for field: Dictionary in row.fields:
		if _actions.fixed_evidence(field):
			selection[field.key] = field.options[0].id
			var evidence: Dictionary = _actions.source_info(self, str(field.options[0].id))
			_line(_body, str(evidence.get("summary", _actions._option_title(self, field.options[0]))), 16)
			continue
		_line(_body, field.label, 17, UI.GOLD)
		var options: Array = field.options
		if options.is_empty():
			complete = false
			_line(_body, "当前没有满足这项处理条件的依据。", 17, UI.RISK)
			continue
		for option: Dictionary in options:
			var selected: bool = selection.get(field.key) == option.id
			var choice := _button(_body, "SourceChoice", "", Rect2(), func() -> void:
				selection[field.key] = option.id
				_event_selection[row.key] = selection
				_review_event(row, false))
			choice.custom_minimum_size.y = 48
			choice.tooltip_text = _actions._option_title(self, option)
			var content := HBoxContainer.new()
			content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			content.offset_left = 8; content.offset_right = -8; content.offset_top = 4; content.offset_bottom = -4
			content.add_theme_constant_override("separation", 8)
			content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			choice.add_child(content)
			var art := Control.new()
			art.custom_minimum_size = Vector2(38, 38)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(art)
			_ui.icon(art, "EvidenceSymbol", "evidence", Rect2(4, 3, 29, 31))
			var label := _line(content, ("已选 · " if selected else "") + _actions._option_title(self, option), 16, UI.GOLD_HI if selected else UI.BONE)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var evidence: Dictionary = _actions.source_info(self, str(option.id))
			if not evidence.is_empty(): _line(_body, str(evidence.summary), 15, UI.MUTED)
			var candidate: Dictionary = selection.duplicate(true); candidate[field.key] = option.id
			_tasks.guard_action(choice, _body, row.key, candidate)
			if selected and not reset: choice.grab_focus()
		if not selection.has(field.key): complete = false
	var preview: Dictionary = session.preview_action(row.key, selection) if complete else {}
	_line(_body, "确定结算 · 不投骰", 16, UI.MUTED)
	_line(_body, "支付 %s 信仰" % preview.get("preview", {}).get("faith_cost", row.details["信仰费用"]), 19, UI.GOLD)
	_line(_body, str(row.details["选择后果"]))
	_line(_body, str(row.details["不可逆代价"]), 17, UI.RISK)
	if complete and not preview.get("ok", false):
		_line(_body, session.explain_error(str(preview.get("error", ""))), 17, UI.RISK)
	elif not complete:
		_line(_body, "请选择本次处理所依据的经历。", 16, UI.MUTED)
	var cancel := _footer_button("Cancel", "返回事件", _show_event.bind(true))
	var submit := _footer_button("ConfirmEvent", "确认处理", _commit_event.bind(row, selection.duplicate(), int(projection.turn)), true)
	submit.disabled = not preview.get("ok", false)
	if reset: cancel.grab_focus()
	_tasks.scan_candidates()

func _commit_event(row: Dictionary, selection: Dictionary, expected_turn: int) -> void:
	if _busy or _dialog != "event_review" or projection.get("turn") != expected_turn or projection.get("phase") != "events": return
	_busy = true
	var before := projection
	var result: Dictionary = session.execute_action(row.key, selection, true)
	_busy = false
	if not result.get("ok", false):
		_set_notice(result)
		_show_event()
		return
	_event_selection.clear()
	_event_key = ""
	var after: Dictionary = session.project()
	_receipt = _feedback.build(self, result, before, after, row.details["选项名称"])
	_resource_delta = _feedback.resource_summary(before, after)
	_set_notice(result)
	_close_surface()
	_refresh()
	_enter_boundary()

func _show_end() -> void:
	var preview: Dictionary = session.progress()
	_open_surface("end", "第 %s 轮 · 轮末结算预览" % projection.turn, "结束本轮")
	if preview.get("confirmation", false) and preview.get("preview", {}).get("ok", false):
		_line(_body, _views.budget_summary(self), 19)
	elif preview.get("confirmation", false):
		_line(_body, session.explain_error(str(preview.get("preview", {}).get("error", ""))), 17, UI.RISK)
	else:
		_line(_body, session.explain_error(str(preview.get("error", ""))), 17, UI.RISK)
	var count := _pending_prayers().size()
	if count > 0:
		_line(_body, "还有 %d 项未回应祈求。到期请求将失去回应机会。" % count, 18, UI.RISK)
	_line(_body, "确认后结算本轮，并直接进入下一轮。", 17, UI.MUTED)
	var cancel := _footer_button("Cancel", "留在本轮", _close_surface)
	var confirm := _footer_button("ConfirmEnd", "结束本轮", _commit_end.bind(int(projection.turn)), true)
	confirm.disabled = not preview.get("confirmation", false) or not preview.get("preview", {}).get("ok", false)
	cancel.grab_focus()

func _commit_end(expected_turn: int) -> void:
	if _busy or _dialog != "end" or projection.get("turn") != expected_turn or projection.get("phase") != "actions": return
	_close_surface()
	_advance(true)

func _advance(confirmed := false, rest := false) -> void:
	if _busy: return
	# Session's finish_events can resolve defaults. B01 calls it only when all
	# actual decisions are already resolved, including an empty opening queue.
	if projection.get("phase") == "events" and not _pending_events().is_empty(): return
	_busy = true
	var before := projection
	var result: Dictionary = session.rest(true) if rest else session.progress(confirmed)
	var facts: Array = result.get("facts", []).duplicate()
	var cult_records: Array = result.get("cult_settlement", []).duplicate()
	var save_failed: bool = _save_warning(result)
	var after: Dictionary = session.project()
	var steps := 0
	while result.get("ok", false) and str(after.get("phase", "")) in INTERNAL_PHASES and steps < INTERNAL_PHASES.size():
		result = session.progress()
		facts.append_array(result.get("facts", []))
		cult_records.append_array(result.get("cult_settlement", []))
		save_failed = save_failed or _save_warning(result)
		after = session.project()
		steps += 1
	_busy = false
	if result.get("ok", false) and str(after.get("phase", "")) in INTERNAL_PHASES:
		result = {"ok": false, "error": "轮次交接未完成，可从阶段牌重试。"}
	if confirmed or before.get("turn") != after.get("turn"):
		var caption := "敛息 · 第 %s 轮结算" % before.turn if rest else ("第 %s 轮结算" % before.turn if confirmed else "已进入第 %s 轮" % after.turn)
		if not result.get("ok", false): caption = "第 %s 轮 · 已实际发生的变化" % before.turn
		_receipt = _feedback.build(self, {"ok": true, "facts": facts, "cult_settlement": cult_records}, before, after, caption)
		_world_management.record_settlement(cult_records)
		_resource_delta = _feedback.resource_summary(before, after)
	_set_notice(result)
	if save_failed and result.get("ok", false):
		_notice_text = "自动保存未完成，请从菜单手动保存。"
	_refresh()
	if is_instance_valid(_phase_plate): _phase_plate.grab_focus()
	if result.get("ok", false): _enter_boundary()

func _enter_boundary() -> void:
	match str(projection.get("phase", "")):
		"events":
			if _pending_events().is_empty(): _advance()
			else: _show_event()
		"between", "evolution", "settlement", "ending": _advance()
		"actions": _prayers.introduce()
		"ended": _tasks.open_subject("ending")
		_:
			if is_instance_valid(_phase_plate): _phase_plate.grab_focus()

func _show_receipt(on_return := Callable()) -> void:
	_close_inline()
	_open_surface("receipt", "近况 · 实际结果", _receipt[0])
	for line: String in _receipt.slice(1): _line(_body, line)
	if _receipt.size() == 1: _line(_body, "当前可见资源与对象状态没有变化。")
	_footer_button("Return", "返回", on_return if on_return.is_valid() else _close_surface).grab_focus()

func _show_menu() -> void:
	if _busy: return
	_close_inline()
	var active: bool = projection.get("active", false)
	_open_surface("menu", "暂停" if active else "邪神苏醒", "幽界群像")
	var menu_stage := HBoxContainer.new()
	menu_stage.add_theme_constant_override("separation", 24)
	_body.add_child(menu_stage)
	var journey := VBoxContainer.new()
	journey.custom_minimum_size.x = 230
	journey.add_theme_constant_override("separation", 8)
	menu_stage.add_child(journey)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(220, 72)
	journey.add_child(emblem)
	_ui.icon(emblem, "MenuEmblem", "awakening", Rect2(6, 6, 56, 52))
	_text(emblem, "本局旅程" if active else "开启旅程", Rect2(74, 4, 145, 30), 19, UI.GOLD_HI)
	_text(emblem, "第 %s 回合 · %s" % [projection.turn, projection.phase_title] if active else "世界尚未展开", Rect2(74, 33, 150, 28), 14, UI.MUTED)
	_line(journey, "新局种子", 16, UI.MUTED)
	var seed_field := LineEdit.new()
	seed_field.name = "Seed"
	seed_field.text = "1"
	seed_field.accessibility_name = "世界种子"
	seed_field.custom_minimum_size.y = 39
	seed_field.add_theme_font_size_override("font_size", _size(17))
	seed_field.add_theme_stylebox_override("normal", _ui.unframed_style("normal"))
	seed_field.add_theme_stylebox_override("focus", _ui.unframed_style("focus"))
	journey.add_child(seed_field)
	var status := _line(journey, _notice_text, 16, _notice_color)
	var new_game := _button(journey, "NewGame", "开始新局", Rect2(), func() -> void:
		if not seed_field.text.is_valid_int():
			status.add_theme_color_override("font_color", UI.RISK)
			status.text = "请输入整数种子。"
			return
		_confirm_switch("开始新局", _start_new.bind(seed_field.text.to_int())))
	new_game.custom_minimum_size = Vector2(145, 40)
	var menu_items := VBoxContainer.new()
	menu_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_items.add_theme_constant_override("separation", 7)
	menu_stage.add_child(menu_items)
	_line(menu_items, "继续与管理", 17, UI.GOLD)
	var resume := _button(menu_items, "Continue", "继续最近存档", Rect2(), func() -> void:
		_confirm_switch("继续最近存档", _load_recent))
	resume.custom_minimum_size = Vector2(163, 40)
	resume.disabled = not FileAccess.file_exists(session.latest_path)
	var import := _button(menu_items, "Import", "导入存档副本", Rect2(), func() -> void:
		_confirm_switch("导入存档副本", _choose_import))
	import.custom_minimum_size = Vector2(157, 40)
	_button(menu_items, "SavedGames", "选择已有存档", Rect2(), _show_saved_games).custom_minimum_size.y = 39
	var settings := _button(menu_items, "Settings", "显示设置", Rect2(), _show_settings)
	settings.custom_minimum_size.y = 39
	if active:
		if not projection.get("terminal", false):
			_button(menu_items, "SealGame", "主动封存本局…", Rect2(), _show_seal).custom_minimum_size.y = 39
		_footer_button("Return", "返回游戏", _close_surface).grab_focus()
		_footer_button("Save", "保存当前局", func() -> void: _save(false))
		_footer_button("SaveExit", "保存并退出", func() -> void: _save(true))
	else:
		new_game.grab_focus()
		_footer_button("Exit", "退出游戏", func() -> void: get_tree().quit())

func _confirm_switch(heading: String, callback: Callable) -> void:
	if not projection.get("active", false):
		callback.call()
		return
	_open_surface("switch", "切换局面", heading)
	_line(_body, "切换会离开当前局。如需保留最新进度，请返回菜单保存。")
	_footer_button("Cancel", "返回菜单", _show_menu).grab_focus()
	_footer_button("Switch", "确认切换", callback, true)

func _show_seal() -> void:
	_open_surface("seal", "结束本局", "主动封存")
	_line(_body, "封存后只能回顾本局与已知记录。仍可另开新局。")
	_footer_button("CancelSeal", "返回菜单", _show_menu).grab_focus()
	_footer_button("ConfirmSeal", "确认封存", _seal, true)

func _seal() -> void:
	if _busy or _dialog != "seal": return
	_busy = true
	var result: Dictionary = session.abandon(true)
	_busy = false
	_set_notice(result)
	if not result.get("ok", false):
		_show_menu()
		return
	if _save_warning(result): _notice_text = "自动保存未完成，请从菜单手动保存。"
	_receipt.clear()
	_refresh()
	_enter_boundary()

func _start_new(seed_value: int) -> void:
	if _busy: return
	_busy = true
	var result: Dictionary = session.start_new(seed_value)
	_busy = false
	_open_campaign(result)

func _choose_import() -> void:
	var picker := FileDialog.new()
	picker.title = "选择现有游戏存档"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.add_filter("*.json", "游戏存档")
	add_child(picker)
	picker.file_selected.connect(func(path: String) -> void:
		picker.queue_free()
		_import_copy(path))
	picker.canceled.connect(func() -> void:
		picker.queue_free()
		_show_menu())
	picker.popup_centered(Vector2i(740, 470))

func _import_copy(path: String) -> void:
	if _busy: return
	var folder := ProjectSettings.globalize_path(session.save_directory)
	var copy := folder.path_join("%d-%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(folder) != OK or DirAccess.copy_absolute(path, copy) != OK:
		_open_campaign({"ok": false, "error": "未能复制存档。"})
		return
	_busy = true
	var result: Dictionary = session.continue_game(copy)
	_busy = false
	if not result.get("ok", false): DirAccess.remove_absolute(copy)
	_open_campaign(result)

func _show_saved_games() -> void:
	_open_surface("saved_games", "继续旅程", "已有存档")
	var saves: Array = session.saved_games()
	if saves.is_empty(): _line(_body, "尚无已保存的游戏。", 17, UI.MUTED)
	for index: int in saves.size():
		var saved: Dictionary = saves[index]
		var card := _button(_body, "SavedGame_%d" % index, "", Rect2(), _confirm_switch.bind("载入所选存档", _load_saved.bind(saved.path)))
		card.custom_minimum_size.y = 50
		card.tooltip_text = saved.title
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 10; content.offset_right = -10; content.offset_top = 4; content.offset_bottom = -4
		content.add_theme_constant_override("separation", 10)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(40, 38)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		_ui.icon(icon, "SaveSymbol", "history", Rect2(3, 5, 30, 27))
		var title := _line(content, saved.title, 16, UI.BONE)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_footer_button("ReturnSaves", "返回菜单", _show_menu).grab_focus()

func _load_recent() -> void:
	_load_saved()

func _load_saved(path := "") -> void:
	if _busy: return
	_busy = true
	var result: Dictionary = session.continue_game(path)
	_busy = false
	_open_campaign(result)

func _open_campaign(result: Dictionary) -> void:
	_set_notice(result)
	if not result.get("ok", false):
		_show_menu()
		return
	_receipt.clear()
	_resource_delta = ""
	_world_id = ""
	_world_query = ""
	_event_key = ""
	_event_selection.clear()
	_tasks.reset()
	_prayers.reset()
	_world_management.reset()
	_close_surface()
	_refresh()
	_enter_boundary()

func _save(exit_after: bool) -> void:
	if _busy or not projection.get("active", false): return
	_busy = true
	var result: Dictionary = session.save_game()
	_busy = false
	if exit_after and result.get("ok", false) and result.get("latest", false):
		get_tree().quit()
		return
	_set_notice(result)
	if result.get("ok", false) and _notice_text.is_empty():
		_notice_text = "已保存 · 第 %s 轮 · %s" % [projection.turn, projection.phase_title]
		_notice_color = UI.CYAN
	if _dialog == "menu":
		_show_menu()
		_footer.get_node("Save").grab_focus()
	else:
		if is_instance_valid(_notice):
			_notice.text = _notice_text
			_notice.add_theme_color_override("font_color", _notice_color)
		if is_instance_valid(_surface):
			var status := _surface.get_node_or_null("SaveNotice") as Label
			if status == null:
				status = _text(_surface, "", Rect2(290, 599, 700, 36), 16)
				status.name = "SaveNotice"
				status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status.text = _notice_text
			status.add_theme_color_override("font_color", _notice_color)

func _save_warning(result: Dictionary) -> bool:
	var saved: Dictionary = result.get("autosave", {})
	return result.get("ok", false) and result.has("autosave") and (not saved.get("ok", false) or not saved.get("latest", false))

func _set_notice(result: Dictionary) -> void:
	_notice_text = ""
	_notice_color = UI.RISK
	if not result.get("ok", false):
		_notice_text = session.explain_error(str(result.get("error", "")))
	elif not result.get("latest", true) or _save_warning(result):
		_notice_text = "未能更新最近存档，请重新保存。"

func _set_keyboard(value: bool) -> void:
	_keyboard = value
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button and focus != _phase_plate: _ui.sync_focus_style(focus)
	if is_instance_valid(_phase_plate): _phase_plate.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_set_keyboard(false)
	if not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_ESCAPE:
			if event.echo: return
			get_viewport().set_input_as_handled()
			match _dialog:
				"event_review": _show_event(true)
				"world_management": _world_management.back()
				"task_action", "task_confirm", "task_subject", "task_related", "task_plan_confirm", "task_rest_confirm", "task_switch": _tasks.back()
				"prayer_person", "prayer_confirm": _prayers.back_to_detail()
				"prayer_detail", "prayer_result": _prayers.close()
				"switch", "settings", "seal", "saved_games": _show_menu()
				"menu":
					if projection.get("active", false): _close_surface()
				"": _show_menu()
				_: _close_surface()
		KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_SPACE:
			if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
			_set_keyboard(true)
			if not is_instance_valid(_surface): return
			var focus := get_viewport().gui_get_focus_owner()
			if focus is LineEdit and event.keycode != KEY_TAB: return
			if event.keycode in [KEY_ENTER, KEY_SPACE]:
				if event.echo: get_viewport().set_input_as_handled()
				return
			var targets: Array[Node] = _surface.find_children("*", "Control", true, false).filter(func(control: Control) -> bool:
				return control.is_visible_in_tree() and (control is LineEdit or (control is Button and not control.disabled)))
			if _dialog in ["prayer_detail", "prayer_person", "prayer_result"]:
				targets.append_array(_prayers.cards.values())
			if targets.is_empty(): return
			get_viewport().set_input_as_handled()
			var index := targets.find(focus)
			var offset := -1 if event.shift_pressed or event.keycode in [KEY_UP, KEY_LEFT] else 1
			targets[posmod(index + offset, targets.size())].grab_focus()
		KEY_F5:
			if not event.echo and projection.get("active", false):
				get_viewport().set_input_as_handled()
				_save(false)
