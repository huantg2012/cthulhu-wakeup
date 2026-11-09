extends Control
## Production view. Decisions and persistence go through Session.
const Session = preload("res://src/presentation/session.gd")
const TaskView = preload("res://src/presentation/production/task_view.gd")
const Views = preload("res://src/presentation/experience_views.gd")
const Actions = preload("res://src/presentation/experience_actions.gd")
const Feedback = preload("res://src/presentation/experience_feedback.gd")
const UI = preload("res://src/presentation/production/locked_controls.gd")
const WorldManagement = preload("res://src/presentation/production/world_management.gd")
const PrayerView = preload("res://src/presentation/production/prayer_view.gd")
const InteractionStage = preload("res://src/presentation/production/interaction_stage.gd")
const PowerStage = preload("res://src/presentation/production/power_stage.gd")
const Motion = preload("res://src/presentation/ui/motion.gd")
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const VIEW := Vector2(1280, 720)
const DISPLAY_SETTINGS := "user://echoes-display.cfg"
const SAVE_DIRECTORY := "user://production-ui-campaigns"
const INTERNAL_PHASES := ["between", "evolution", "settlement", "ending"]

var session: RefCounted = Session.new(SAVE_DIRECTORY)
var projection: Dictionary = {}
var _tasks := TaskView.new(self)
var _world_management := WorldManagement.new(self)
var _interaction := InteractionStage.new(self)
var _powers := PowerStage.new(self)
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
var _peek_origin: Control
var _receipt_return := Callable()
var _body: VBoxContainer
var _body_scroll: ScrollContainer
var _footer: HBoxContainer
var _dialog := ""
var _return_focus: Control
var _phase_plate: Button
var _menu_button: Button
var _worlds: Array = []
var _world_id := ""
var _world_body: Control
var _world_buttons: Dictionary = {}
var _receipt: Array[String] = []
var _receipt_requirements: Array = []
var _resource_delta := ""
var _notice: Label
var _notice_text := ""
var _notice_color := UI.RISK
var _event_key := ""
var _event_scroll := 0
var _event_selection: Dictionary = {}
var _switch_back: Callable

func _ready() -> void:
	var window := get_window()
	window.title = "邪神苏醒 · 幽界群像"
	var settings := ConfigFile.new()
	if settings.load(DISPLAY_SETTINGS) == OK:
		_large_text = bool(settings.get_value("display", "large_text", false))
	_apply_window_mode(bool(settings.get_value("display", "fullscreen", false)))
	window.focus_exited.connect(func(): _set_keyboard(false))
	_motion.params = {"scene_reveal_s": 0.32, "variant_s": 0.16, "related_s": 0.18, "opening_exit_s": 0.22}
	add_child(_motion)
	_ui = UI.new(null, func() -> bool: return _keyboard)
	var base := Theme.new()
	_apply_scroll_theme(base)
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
	_open_menu_panel("settings", "显示设置", "调整文字大小与窗口模式。")
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
	_footer_button("Return", "返回菜单", _show_menu.bind("Settings")).grab_focus()

func title(id: String) -> String:
	return session.object_title(id)

func _size(standard: int) -> int:
	return standard + (3 if _large_text else 0)

func _text(parent: Node, value: String, bounds: Rect2, font_size: int, color: Color = UI.BONE) -> Label:
	return _ui.label(parent, "Text", value, bounds, _size(font_size), color, font_size >= 23, true)

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
	return scroll

func _scroll_cue(scroll: ScrollContainer, parent: Control, bounds: Rect2) -> void:
	var cue := _text(parent, "", bounds, 12, UI.MUTED)
	cue.name = "ScrollCue"
	cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar := scroll.get_v_scroll_bar()
	var update := func() -> void:
		var more_below := bar.value + bar.page < bar.max_value - 1.0
		var more_above := bar.value > bar.min_value + 1.0
		cue.text = "还有下文 ↓" if more_below else ("上文 ↑" if more_above else "")
	bar.changed.connect(update)
	bar.value_changed.connect(func(_value: float) -> void: update.call())
	update.call()

func _apply_scroll_theme(base: Theme) -> void:
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 4
	base.set_stylebox("scroll", "VScrollBar", track)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color(UI.CYAN, 0.32 if state == "grabber" else 0.68)
		grip.content_margin_left = 4
		base.set_stylebox(state, "VScrollBar", grip)

func _refresh() -> void:
	projection = session.project()
	var return_path := NodePath()
	if is_instance_valid(_stage):
		if is_instance_valid(_return_focus) and _stage.is_ancestor_of(_return_focus):
			return_path = _stage.get_path_to(_return_focus)
		remove_child(_stage)
		_stage.queue_free()
	_stage = _region(self, "Perception", Rect2(Vector2.ZERO, VIEW))
	move_child(_stage, 0)
	_interaction.backdrop(_stage)
	_prayers.cards.clear()
	if projection.get("active", false):
		_build_worlds()
		_build_top()
		_build_dock()
	if not return_path.is_empty(): _return_focus = _stage.get_node_or_null(return_path) as Control

func _build_top() -> void:
	var top := _region(_stage, "Top", Rect2(Vector2.ZERO, VIEW))
	_reference(top, "GameTitle", "邪神苏醒", Rect2(46, 36, 140, 37), 23, Color("#bdc8c7"), true, 7)
	if projection.get("active", false):
		_ui.fill(top, "TurnRule", Layout.box(Rect2(193, 44, 1, 22)), UI.LINE)
		_reference(top, "Turn", "第 %s 轮 · %s" % [projection.turn, projection.phase_title], Rect2(218, 37, 438, 37), 15, UI.MUTED, false, 2)
		var whispers := str(projection.whispers)
		var faith := str(projection.faith)
		var awakening := str(projection.awakening)
		var awakening_x := 1554.0 - _resource_width(awakening)
		var faith_x := awakening_x - 23 - _resource_width(faith)
		var whispers_x := faith_x - 24 - _resource_width(whispers)
		_resource(top, "Whispers", "低语", whispers, whispers_x)
		_resource(top, "Faith", "信仰", faith, faith_x, _tasks.open_subject.bind("budget", "")).tooltip_text = "信仰 %s / %s" % [projection.faith, projection.capacity]
		_resource(top, "AwakeningReadout", "苏醒", awakening, awakening_x, _tasks.open_subject.bind("self", "")).tooltip_text = Views.next_power_hint(session.catalog, int(projection.awakening))
	_menu_button = _stage_button(top, "Menu", "⋯", Rect2(1515, 99, 39, 33), _show_menu, 17)
	_menu_button.accessibility_name = "游戏菜单及全局目录"

func _resource_width(value: String) -> float:
	return maxf(66, 38 + (16 + _size(0)) * value.length())

func _resource(parent: Control, node_name: String, caption: String, value: String, x: float, callback := Callable()) -> Control:
	var bounds := Rect2(x, 34, _resource_width(value), 40)
	var entry: Control
	if callback.is_valid():
		entry = _stage_button(parent, node_name, "", bounds, callback)
		entry.accessibility_name = caption + " " + value
		_ui.fill(entry, "ResourceRule", Layout.box(Rect2(0, 39, bounds.size.x, 1)), UI.LINE)
	else:
		entry = _region(parent, node_name, Layout.box(bounds))
	_reference(entry, "ResourceName", caption, Rect2(0, 0, 36, 40), 15, UI.MUTED)
	_reference(entry, "ResourceAmount", value, Rect2(37, -2, bounds.size.x - 37, 43), 26, UI.BONE, true)
	return entry

func _reference(parent: Node, node_name: String, value: String, bounds: Rect2, px: float, color := UI.BONE, heading := false, tracking := 0.0) -> Label:
	return _ui.reference_label(parent, node_name, value, bounds, px, color, heading, tracking, _size(0))

func _stage_button(parent: Node, node_name: String, caption: String, bounds: Rect2, handler: Callable, px := 15) -> Button:
	return _ui.button(parent, node_name, caption, Layout.box(bounds), handler, false, true, _size(Layout.type_size(px)))

func _build_dock() -> void:
	var dock := _region(_stage, "Dock", Rect2(Vector2.ZERO, VIEW))
	_ui.fill(dock, "HorizonRule", Layout.box(Rect2(48, 801, 1504, 1)), Color(UI.LINE, 0.55))
	var summary := "尚有 %d 项轮初事件" % _pending_events().size() if projection.get("phase") == "events" else ""
	if not _receipt.is_empty():
		summary = _receipt[0] + (" · " + _resource_delta if not _resource_delta.is_empty() else "")
	_notice = _reference(dock, "StageNotice", _notice_text if not _notice_text.is_empty() else summary, Rect2(652, 808, 586, 42), 13, _notice_color if not _notice_text.is_empty() else UI.MUTED)
	_notice.tooltip_text = _notice.text
	_phase_plate = null
	if not projection.get("active", false): return
	var power := _stage_button(dock, "PowerIndex", "", Rect2(48, 803, 122, 53), _powers.open)
	power.accessibility_name = "十二权能"
	_interaction.seal(power, "PowerSeal", "⌁", Rect2(0, 10, 32, 32), 17, true)
	_reference(power, "PowerTitle", "十二权能", Rect2(41, 0, 80, 53), 15)
	_dock_entry(dock, "RelicIndex", "圣物", 177, 51, _tasks.open_subject.bind("relics", ""))
	_dock_entry(dock, "People", "人物档案", 235, 81, _tasks.open_subject.bind("people", ""))
	_dock_entry(dock, "Budget", "供奉与收支", 323, 95, _tasks.open_subject.bind("budget", ""))
	_dock_entry(dock, "Self", "苏醒与降临", 426, 95, _tasks.open_subject.bind("self", ""))
	_dock_entry(dock, "History", "编年史", 1338, 64, _tasks.open_subject.bind("history", ""))
	if not _receipt.is_empty(): _dock_entry(dock, "Receipt", "回执", 1256, 64, _show_receipt)

	var caption: String = {"events": "处理事件", "actions": "回合责任", "ended": "回顾本局"}.get(str(projection.phase), "继续轮次")
	_phase_plate = _stage_button(dock, "PhaseAction", "", Rect2(1410, 806, 142, 47), _phase_intent)
	_phase_plate.accessibility_name = caption
	var border := StyleBoxFlat.new()
	border.bg_color = Color(UI.INK, 0.08)
	border.border_color = UI.MUTED
	border.set_border_width_all(1)
	_phase_plate.add_theme_stylebox_override("normal", border)
	_reference(_phase_plate, "PhaseTitle", caption + " →", Rect2(0, 0, 142, 47), 15, UI.BONE, false, 2).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _dock_entry(parent: Control, node_name: String, caption: String, x: float, width: float, callback: Callable) -> void:
	var control := _stage_button(parent, node_name, "", Rect2(x, 809, width, 41), callback)
	control.accessibility_name = caption
	_reference(control, "ToolName", caption, Rect2(0, 0, width, 41), 15)

func _world_picture(id: String) -> Texture2D:
	return _interaction.world_picture(id)

func _build_worlds() -> void:
	_worlds = projection.domains
	_interaction.register_worlds(_worlds)
	_world_buttons.clear()
	_world_body = null
	var world: Dictionary = _views._find(self, "domains", _world_id)
	if world.is_empty():
		_world_id = ""
		_interaction.overview()
	else:
		_world_body = _region(_stage, "World", Rect2(Vector2.ZERO, VIEW))
		_interaction.local(world)

func _close_inline() -> void:
	if _dialog == "world_management": _world_management.close(false)
	elif _dialog in ["prayer_detail", "prayer_person", "prayer_result"]: _prayers.close(false)

func _inspect_world(id: String) -> void:
	if _busy or projection.get("phase") == "events": return
	_close_inline()
	if is_instance_valid(_surface): return
	_select_world(id)

func _select_world(id: String) -> void:
	var previous := _world_id
	_world_id = id
	_refresh()
	var target: Control = _stage.find_child("WorldOverview" if not id.is_empty() else "World_" + previous, true, false)
	if target == null: target = _stage.find_child("AllWorlds", true, false)
	if is_instance_valid(target) and _can_focus(target): target.grab_focus()

func _update_metric_hint() -> void:
	if not is_instance_valid(_world_body): return
	var note: Label = _world_body.get_node("MetricHint")
	var hovered := ""
	var focused := ""
	for child: Node in _world_body.get_children():
		if not child is Button or not str(child.name).begins_with("MetricHelp_"): continue
		if child.is_hovered(): hovered = child.accessibility_description
		if child.has_focus(): focused = child.accessibility_description
	note.text = focused if _keyboard and not focused.is_empty() else (hovered if not hovered.is_empty() else focused)

func _pending_prayers() -> Array:
	return projection.get("prayers", []).filter(func(prayer: Dictionary) -> bool: return prayer.status == "open")

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

func _begin_surface(kind: String, mist := true, preserve_world := false) -> void:
	var intro_exit := _dialog == "prayer_intro" and not mist
	if not is_instance_valid(_surface):
		_return_focus = get_viewport().gui_get_focus_owner()
	else:
		_remove_surface(intro_exit)
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()
	if not intro_exit:
		for layer: Node in get_children():
			if layer.is_in_group("motion_retiring"):
				remove_child(layer)
				layer.queue_free()
	_dialog = kind
	_surface = _region(self, "Decision", Rect2(Vector2.ZERO, VIEW))
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	if not preserve_world:
		_ui.fill(_surface, "Shade", Rect2(0, 70, 1280, 552), Color(UI.INK, 0.91 if mist else 0.7))
		if is_instance_valid(_world_body): _world_body.hide()

func _scene_frame(kind: String, node_name: String, color: Color) -> Control:
	_begin_surface(kind, false, true)
	var frame := _region(_surface, node_name, Layout.box(Layout.SCENE))
	frame.clip_contents = true
	_ui.fill(frame, "SceneBackdrop", Rect2(Vector2.ZERO, frame.size), color)
	return frame

func _scene_plate(parent: Control, node_name: String, bounds: Rect2, color: Color, edge := SIDE_TOP) -> Control:
	var plate := Panel.new()
	plate.name = node_name
	_ui.rect(plate, Layout.box(bounds))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(UI.CYAN, 0.4)
	style.set_border_width(edge, 1)
	plate.add_theme_stylebox_override("panel", style)
	parent.add_child(plate)
	return plate

func _surface_column(parent: Control, bounds: Rect2) -> VBoxContainer:
	var scroll := _scroller(parent, Layout.box(bounds))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 8)
	scroll.add_child(words)
	return words

func _peek_content(eyebrow: String, heading: String) -> VBoxContainer:
	var panel := _scene_plate(_surface, "RelatedPeek", Layout.PEEK, Color("#1a2b34fa"), SIDE_LEFT)
	_reference(panel, "PeekEyebrow", eyebrow, Rect2(29, 21, 364, 35), 12, UI.CYAN, false, 2)
	_reference(panel, "PeekHeading", heading, Rect2(29, 65, 388, 49), 28, UI.BONE, true, 2)
	return _surface_column(panel, Rect2(29, 128, 392, 302))

func _open_surface(kind: String, eyebrow: String, heading: String, event_art := false) -> void:
	if kind == "task_related" and _tasks._subject.kind not in ["budget", "history", "people"]:
		_begin_peek(kind)
		_body = _peek_content(eyebrow, heading)
		_body_scroll = _body.get_parent()
		_make_footer(Rect2(1130, 661, 393, 38))
		return
	if kind in ["event", "event_review"]:
		_event_frame(kind, eyebrow, heading)
		return
	var focal := kind in ["anchor_goal", "anchor_receipt"]
	var ritual := kind in ["task_action", "power_receipt"]
	if focal:
		_begin_surface(kind, false, true)
		var focus_box := Rect2(352, 491, 1058, 284) if kind == "anchor_receipt" else Rect2(352, 398, 1058, 377)
		_scene_plate(_surface, "LocalFocus", focus_box, Color("#11212bf7"))
		_reference(_surface, "ReadingHeading", heading, Rect2(384, focus_box.position.y + 20, 735, 48), 26, UI.BONE, true, 2)
		_reference(_surface, "ReadingEyebrow", eyebrow, Rect2(1130, focus_box.position.y + 20, 244, 48), 14, UI.CYAN).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if kind == "anchor_receipt": _set_reading(Rect2(384, focus_box.position.y + 66, 994, focus_box.size.y - 131))
		_make_footer(Rect2(384, 715, 994, 43))
		return
	if ritual:
		var frame := _scene_frame("receipt" if kind == "power_receipt" else kind, "RitualStage", Color("#0a1421"))
		_ritual_placeholder(frame)
		_reference(_surface, "SceneHeading", heading + " / " + eyebrow, Rect2(78, 167, 1040, 38), 14, UI.MUTED)
		if kind == "task_action":
			_stage_button(_surface, "CloseRitual", "×", Rect2(1484, 167, 38, 38), _tasks.back, 22)
			var power: String = str(_tasks.draft.get("key", ""))
			if session.catalog.display_tables.powers.has(power):
				_stage_button(_surface, "PowerCatalog", "权能全览 →", Rect2(1290, 167, 162, 38), _powers.open.bind(power))
		_set_reading(Rect2(85, 214, 1430, 477))
		_ui.fill(_surface, "FooterRule", Layout.box(Rect2(85, 704, 1430, 1)), UI.LINE)
		_make_footer(Rect2(85, 718, 1430, 45))
		return
	_begin_surface(kind, false, true)
	_reading_frame(eyebrow, heading)
	if event_art: _ui.image(_surface, "SceneSlot", Layout.box(Rect2(82, 294, 380, 390)), _interaction.picture("contact"))
	_set_reading(Rect2(502 if event_art else 82, 294, 1016 if event_art else 1436, 402))
	_make_footer(Rect2(82, 722, 1436, 39))

func _begin_peek(kind: String) -> void:
	var target := _return_focus
	if is_instance_valid(_peek_origin):
		if is_instance_valid(_surface):
			remove_child(_surface)
			_surface.queue_free()
		_surface = null
	else:
		_peek_origin = _surface
		if is_instance_valid(_peek_origin):
			_peek_origin.name = "ReadingOrigin"
			for control: Control in _peek_origin.find_children("*", "Control", true, false):
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
				control.focus_mode = Control.FOCUS_NONE
				if control is Button: control.name = "Origin_" + str(control.name)
			_peek_origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_surface = null
	var origin := _peek_origin
	_peek_origin = null
	_begin_surface(kind, false, true)
	_peek_origin = origin
	_return_focus = target

func _reading_frame(eyebrow: String, heading: String) -> void:
	_scene_plate(_surface, "ReadingField", Layout.SCENE, Color("#09131df8"))
	_reference(_surface, "ReadingEyebrow", eyebrow, Rect2(82, 176, 1300, 21), 12, UI.CYAN, false, 3)
	_reference(_surface, "ReadingHeading", heading, Rect2(82, 201, 1380, 48), 31, UI.BONE, true, 4)
	_ui.fill(_surface, "ReadingRule", Layout.box(Rect2(82, 708, 1436, 1)), UI.LINE)

func _set_reading(bounds: Rect2) -> void:
	_body = _surface_column(_surface, bounds)
	_body_scroll = _body.get_parent()

func _make_footer(bounds: Rect2) -> void:
	_footer = HBoxContainer.new()
	_ui.rect(_footer, Layout.box(bounds))
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 12)
	_surface.add_child(_footer)

func _ritual_placeholder(frame: Control) -> void:
	_ui.image(frame, "RitualAtmosphere", Rect2(Vector2.ZERO, frame.size), _interaction.picture("atmosphere"), Color(0.76, 0.87, 1, 0.55), TextureRect.STRETCH_SCALE)

func _event_frame(kind: String, eyebrow: String, heading: String) -> void:
	_begin_surface(kind, false, true)
	_ui.fill(_surface, "EventField", Layout.box(Layout.EVENT), Color("#050b14eb"))
	_ui.image(_surface, "SceneSlot", Layout.box(Layout.EVENT_ART), _interaction.picture("world"), Color(1, 1, 1, 0.55))
	_reference(_surface, "EventStage", eyebrow, Rect2(565, 143, 910, 24), 13, UI.GOLD, false, 3)
	_reference(_surface, "EventTitle", heading, Rect2(565, 176, 910, 65), 38, UI.BONE, true, 5)
	_set_reading(Layout.EVENT_COPY)
	_ui.fill(_surface, "EventDivider", Layout.box(Rect2(565, 530, 910, 1)), UI.LINE)
	_make_footer(Layout.EVENT_FOOT)
	var gate := "先选择处理方式。事件未决时，普通行动暂停。" if kind == "event" else "此事件未决时，普通行动暂停。"
	_reference(_surface, "EventGate", gate, Rect2(565, 610 if kind == "event" else 832, 910, 28), 13, UI.MUTED)

func _footer_button(node_name: String, caption: String, handler: Callable, primary := false) -> Button:
	var control := _button(_footer, node_name, caption, Rect2(), handler, primary)
	var font := control.get_theme_font("font")
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x
	control.custom_minimum_size = Vector2(maxf(146, ceilf(width) + control.get_theme_stylebox("normal").get_minimum_size().x), 42)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return control

func _remove_surface(fade: bool) -> void:
	if is_instance_valid(_peek_origin):
		remove_child(_peek_origin)
		_peek_origin.queue_free()
		_peek_origin = null
	if not is_instance_valid(_surface): return
	if fade:
		# Only the backdrop fades. The outgoing controls release their input
		# before a new modal or the world can receive focus.
		for child: Node in _surface.get_children():
			if child.name != "Shade":
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
	if not is_instance_valid(target) or not _can_focus(target): target = _phase_plate
	if not is_instance_valid(target) or not _can_focus(target): target = _menu_button
	if is_instance_valid(target) and _can_focus(target): target.grab_focus()
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
	_event_options(choices, "")
	var waiting := _footer_button("ConfirmEvent", "确认处理此事件 →", func(): pass, true)
	waiting.custom_minimum_size.x = 183
	_ui.scene_submit(waiting)
	waiting.disabled = true
	waiting.accessibility_description = "先选择事件的处理方式。"
	waiting.tooltip_text = waiting.accessibility_description
	_footer_button("InspectWorld", "查看当前态势", _show_event_context)
	var prior := _body.find_child("Option_" + _event_key.get_slice("/", 2), true, false) as Button
	if return_to_option and prior != null:
		_body_scroll.set_deferred("scroll_vertical", _event_scroll)
		prior.grab_focus()
	elif _body.get_child_count() > 0:
		for control: Node in _body.find_children("Option_*", "Button", true, false):
			if not control.disabled:
				control.grab_focus()
				break
	if not _notice_text.is_empty(): _line(_body, _notice_text, 16, _notice_color)

func _event_options(choices: Array, selected: String) -> void:
	if choices.is_empty(): return
	for line: String in _actions.context_lines(choices[0], {}, title, self): _line(_body, line, 13, UI.MUTED)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	_body.add_child(columns)
	for row: Dictionary in choices:
		var details: Dictionary = row.details
		var note := "%s 信仰 · %s" % [details["信仰费用"], details["选择后果"]]
		if not row.available and row.fields.is_empty():
			note += "\n" + session.explain_error(str(row.preview.get("error", "")))
		var button := _button(columns, "Option_" + str(row.key).get_slice("/", 2), "", Rect2(), _review_event.bind(row, true))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.accessibility_name = str(details["选项名称"])
		button.accessibility_description = note
		button.custom_minimum_size.y = 115
		_ui.choice_style(button, row.key == selected)
		var words := VBoxContainer.new()
		words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		words.offset_left = 15
		words.offset_right = -15
		words.offset_top = 9
		words.offset_bottom = -9
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(words)
		_line(words, str(details["选项名称"]), 15)
		_line(words, note, 12, UI.MUTED)
		var irreversible := str(details.get("不可逆代价", ""))
		if not irreversible.is_empty(): _line(words, irreversible, 12, UI.GOLD)

func _show_event_context() -> void:
	if projection.get("phase") != "events": return
	_event_scroll = _body_scroll.scroll_vertical
	_begin_peek("event_context")
	_body = _peek_content("轮初事件 / 关联查阅", "当前已知态势")
	_body_scroll = _body.get_parent()
	_make_footer(Rect2(1130, 661, 393, 38))
	for world: Dictionary in projection.domains:
		_line(_body, str(world.title), 20, UI.GOLD_HI)
		_line(_body, _views.world_metrics_text(self, world.id, true), 16)
		_line(_body, _views.world_resistance_text(_tasks, world.id), 15, UI.MUTED)
	_footer_button("ReturnEvent", "返回轮初事件", _close_event_context, true).grab_focus()

func _close_event_context() -> void:
	_show_event()
	_focus_surface_control("InspectWorld")
	_body_scroll.set_deferred("scroll_vertical", _event_scroll)

func _review_event(row: Dictionary, reset: bool) -> void:
	_tasks.begin_candidates()
	_actions._source_cache.clear()
	if reset: _event_scroll = _body_scroll.scroll_vertical
	_event_key = row.key
	var selection: Dictionary = _event_selection.get(row.key, {})
	var event: Dictionary = _pending_events()[0]
	_open_surface("event_review", "轮初事件 / 确认处理", event.title)
	_event_options(session.action_catalog({}, str(event.key) + "/"), row.key)
	_set_reading(Rect2(565, 602, 910, 217))
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
	_reference(_surface, "EventCost", "支付 %s 信仰 · 确定结算" % preview.get("preview", {}).get("faith_cost", row.details["信仰费用"]), Rect2(565, 538, 410, 44), 17, UI.GOLD)
	_line(_body, str(row.details["选择后果"]))
	_line(_body, str(row.details["不可逆代价"]), 17, UI.RISK)
	if complete and not preview.get("ok", false):
		_line(_body, session.explain_error(str(preview.get("error", ""))), 17, UI.RISK)
	elif not complete:
		_line(_body, "请选择本次处理所依据的经历。", 16, UI.MUTED)
	var cancel := _footer_button("Cancel", "返回事件", _show_event.bind(true))
	var submit := _footer_button("ConfirmEvent", "确认处理此事件 →", _commit_event.bind(row, selection.duplicate(), int(projection.turn)), true)
	submit.custom_minimum_size.x = 183
	_ui.scene_submit(submit)
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
	_receipt_requirements = []
	_receipt = _feedback.build(self, result, before, after, row.details["选项名称"])
	_resource_delta = _feedback.resource_summary(before, after)
	_set_notice(result)
	_close_surface()
	_refresh()
	_enter_boundary()

func _show_end(focus_name := "Cancel") -> void:
	var preview: Dictionary = session.progress()
	_open_surface("end", "第 %s 轮 / 回合边界" % projection.turn, "还有哪些责任值得回看")
	if preview.get("confirmation", false) and preview.get("preview", {}).get("ok", false):
		_line(_body, _views.budget_summary(self), 19)
	elif preview.get("confirmation", false):
		_line(_body, session.explain_error(str(preview.get("preview", {}).get("error", ""))), 17, UI.RISK)
	else:
		_line(_body, session.explain_error(str(preview.get("error", ""))), 17, UI.RISK)
	var count := _pending_prayers().size()
	var context := {"return_caption":"返回回合责任"}
	_responsibility("ReviewSupply", "锚点与供奉", "%d 处已知锚点 · 查看轮末先付责任" % projection.get("anchors", []).size(),
		_tasks.open_subject.bind("budget", "", _show_end.bind("ReviewSupply"), context))
	_responsibility("ReviewPrayers", "本轮祈求", "%d 项未回应 · 到期请求将失去回应机会" % count, _prayers.browse.bind("", _show_end.bind("ReviewPrayers")))
	_responsibility("ReviewCult", "组织计划", "查看已登记指令和当地组织", _tasks.open_subject.bind("cults", "", _show_end.bind("ReviewCult"), context))
	_line(_body, "确认后结算本轮，并直接进入下一轮。", 17, UI.MUTED)
	var cancel := _footer_button("Cancel", "留在本轮", _close_surface)
	var confirm := _footer_button("ConfirmEnd", "结束本轮", _commit_end.bind(int(projection.turn)), true)
	confirm.disabled = not preview.get("confirmation", false) or not preview.get("preview", {}).get("ok", false)
	cancel.grab_focus()
	_focus_surface_control(focus_name)

func _responsibility(node_name: String, caption: String, detail: String, callback: Callable) -> void:
	var action := _button(_body, node_name, caption, Rect2(), callback)
	action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.custom_minimum_size.y = 38
	_ui.choice_style(action, false)
	_line(_body, detail, 13, UI.MUTED)

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
		_receipt_requirements = []
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
		"actions": _prayers.begin_turn()
		"ended": _tasks.open_subject("ending")
		_:
			if is_instance_valid(_phase_plate): _phase_plate.grab_focus()

func _show_receipt(on_return := Callable(), contact := "", anchor_receipt := false) -> void:
	_close_inline()
	_receipt_return = on_return if on_return.is_valid() else _close_surface
	if not contact.is_empty():
		_open_surface("anchor_receipt" if anchor_receipt else "power_receipt", "神意回响 / 实际结果", _receipt[0])
		_dialog = "receipt"
		if not anchor_receipt:
			_reference(_surface, "ReceiptOutcome", _receipt[0], Rect2(86, 259, 405, 54), 28, UI.BONE, true, 2)
			_set_reading(Rect2(86, 324, 375, 359))
			var person: Dictionary = _views._find(self, "people", contact)
			var texture: Texture2D = _interaction.picture("person_portrait") if not person.is_empty() else _world_picture(contact)
			_ui.image(_surface, "ReceiptRings", Layout.box(Rect2(619, 506, 361, 97)), _interaction.picture("rings"), Color.WHITE, TextureRect.STRETCH_SCALE)
			_ui.image(_surface, "SceneSlot", Layout.box(Rect2(631, 217, 340, 405)), texture).set_meta("subject_id", contact)
			_reference(_surface, "ReceiptContact", title(contact), Rect2(550, 583, 500, 48), 23, UI.BONE, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var cost := _surface_column(_surface, Rect2(1163, 325, 352, 316))
			_line(cost, "实际支付与当前资源", 19, UI.GOLD)
			if not _resource_delta.is_empty(): _line(cost, _resource_delta, 16)
			_line(cost, "低语 %s · 信仰 %s" % [projection.whispers, projection.faith], 15, UI.MUTED)
	else:
		_open_surface("receipt", "近况 · 实际结果", _receipt[0])
	_actions.RequirementList.render(_body, _receipt_requirements, _size(16) > 16, _ui)
	for line: String in _receipt.slice(1): _line(_body, line)
	if _receipt.size() == 1: _line(_body, "当前可见资源与对象状态没有变化。")
	if anchor_receipt: _line(_body, "本处供奉状态可在机构查看。全局顺序在底栏「供奉与收支」安排。", 14, UI.MUTED)
	_footer_button("Return", "返回机构" if anchor_receipt else "返回", _receipt_return).grab_focus()

func _show_menu(focus_name := "") -> void:
	if _busy: return
	_close_inline()
	_begin_surface("menu", false, true)
	if projection.get("active", false): _pause_menu()
	else: _title_menu()
	if not focus_name.is_empty(): _focus_surface_control(focus_name)

func _title_menu() -> void:
	_reference(_surface, "TitleBrand", "邪神苏醒", Rect2(460, 183, 680, 86), 57, UI.BONE, true, 10).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reference(_surface, "TitleSubtitle", "幽界群像", Rect2(460, 269, 680, 35), 17, UI.CYAN, false, 7).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var options := _surface_column(_surface, Rect2(640, 348, 320, 338))
	var focus: Button
	if FileAccess.file_exists(session.latest_path):
		focus = _menu_action(options, "Continue", "继续游戏", _load_recent, true)
	var new_game := _menu_action(options, "NewGameOptions", "开始新局…", _show_new_game, focus == null)
	_menu_action(options, "SavedGames", "存档管理", _show_saved_games)
	_menu_action(options, "Settings", "显示设置", _show_settings)
	_menu_action(options, "Exit", "退出游戏", func() -> void: get_tree().quit())
	for action: Button in options.get_children(): action.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not _notice_text.is_empty():
		_reference(_surface, "MenuNotice", _notice_text, Rect2(460, 697, 680, 56), 16, _notice_color).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if focus == null: focus = new_game
	focus.grab_focus()

func _pause_menu() -> void:
	_ui.fill(_surface, "PauseShade", Rect2(Vector2.ZERO, VIEW), Color(UI.INK, 0.46))
	_scene_plate(_surface, "PauseField", Rect2(300, 152, 1000, 591), Color("#0c1721fd"))
	_reference(_surface, "PauseHeading", "游戏暂停", Rect2(350, 186, 900, 64), 38, UI.BONE, true, 4)
	_reference(_surface, "PauseTurn", "第 %s 轮 · %s" % [projection.turn, projection.phase_title], Rect2(350, 250, 900, 31), 17, UI.MUTED)
	_ui.fill(_surface, "PauseRule", Layout.box(Rect2(350, 298, 900, 1)), UI.LINE)
	var current := _surface_column(_surface, Rect2(350, 325, 394, 376))
	_line(current, "当前游戏", 16, UI.CYAN)
	var resume := _menu_action(current, "Return", "返回游戏", _close_surface, true)
	_menu_action(current, "Save", "保存当前局", _save.bind(false))
	_menu_action(current, "SaveExit", "保存并退出", _save.bind(true))
	if not _notice_text.is_empty(): _line(current, _notice_text, 15, _notice_color)
	if not projection.get("terminal", false):
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 12
		current.add_child(spacer)
		var seal := _menu_action(current, "SealGame", "主动封存本局…", _show_seal)
		seal.add_theme_color_override("font_color", UI.RISK)
		seal.add_theme_color_override("font_focus_color", UI.RISK)
	var tools := _surface_column(_surface, Rect2(838, 325, 412, 394))
	tools.add_theme_constant_override("separation", 2)
	_line(tools, "本局资料", 16, UI.CYAN)
	_menu_action(tools, "WorldArchive", "世界档案", _world_management.open_archive.bind("", _show_menu.bind("WorldArchive")))
	var context := {"return_caption":"返回菜单"}
	_menu_action(tools, "CultIndex", "教团", _tasks.open_subject.bind("cults", "", _show_menu.bind("CultIndex"), context))
	_menu_action(tools, "Attention", "关注与成员名额", _tasks.open_subject.bind("attention", "", _show_menu.bind("Attention"), context))
	var group_gap := Control.new()
	group_gap.custom_minimum_size.y = 10
	tools.add_child(group_gap)
	_line(tools, "游戏管理", 16, UI.CYAN)
	_menu_action(tools, "SavedGames", "存档管理", _show_saved_games)
	_menu_action(tools, "NewGameOptions", "开始新局…", _show_new_game)
	_menu_action(tools, "Settings", "显示设置", _show_settings)
	resume.grab_focus()

func _menu_action(parent: VBoxContainer, node_name: String, caption: String, handler: Callable, primary := false) -> Button:
	var control := _button(parent, node_name, caption, Rect2(), handler, primary)
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.custom_minimum_size.y = 36
	if primary: _ui.scene_submit(control)
	return control

func _open_menu_panel(kind: String, heading: String, subtitle: String) -> void:
	_begin_surface(kind, false, true)
	_ui.fill(_surface, "MenuShade", Rect2(Vector2.ZERO, VIEW), Color(UI.INK, 0.46))
	_scene_plate(_surface, "MenuField", Rect2(460, 165, 680, 570), Color("#0c1721fd"))
	_reference(_surface, "MenuHeading", heading, Rect2(500, 202, 600, 60), 36, UI.BONE, true, 3)
	_reference(_surface, "MenuHint", subtitle, Rect2(500, 263, 600, 36), 16, UI.MUTED)
	_set_reading(Rect2(500, 321, 600, 307))
	_ui.fill(_surface, "MenuRule", Layout.box(Rect2(500, 650, 600, 1)), UI.LINE)
	_make_footer(Rect2(500, 668, 600, 46))

func _show_new_game(seed_text := "") -> void:
	_open_menu_panel("new_game", "开始新局", "留空将随机生成世界。")
	_line(_body, "世界种子（可选）", 16, UI.MUTED)
	var seed_field: LineEdit = _ui.search_field(_body, "Seed", "输入整数", Rect2())
	seed_field.accessibility_name = "世界种子"
	seed_field.custom_minimum_size.y = 42
	seed_field.text = seed_text
	var status := _line(_body, "", 16, UI.RISK)
	var start := func() -> void:
		var value := seed_field.text.strip_edges()
		if not value.is_empty() and not value.is_valid_int():
			status.text = "请输入整数种子。"
			seed_field.grab_focus()
			return
		var seed_value: int = randi_range(1, 2147483647) if value.is_empty() else value.to_int()
		_confirm_switch("开始新局", _start_new.bind(seed_value), _show_new_game.bind(value))
	seed_field.text_submitted.connect(func(_value: String) -> void: start.call())
	_footer_button("Return", "返回菜单", _show_menu.bind("NewGameOptions"))
	_footer_button("NewGame", "开始新局", start, true).grab_focus()

func _confirm_switch(heading: String, callback: Callable, on_cancel := Callable()) -> void:
	if not projection.get("active", false):
		callback.call()
		return
	_switch_back = on_cancel if on_cancel.is_valid() else _show_menu
	_open_menu_panel("switch", heading, "切换会离开当前局。请先保存需要保留的进度。")
	_footer_button("Cancel", "取消", _cancel_switch).grab_focus()
	_footer_button("Switch", "确认切换", callback, true)

func _cancel_switch() -> void:
	var back := _switch_back
	_switch_back = Callable()
	back.call()

func _show_seal() -> void:
	_open_menu_panel("seal", "主动封存本局", "封存后只能回顾本局与已知记录。仍可另开新局。")
	_footer_button("CancelSeal", "返回菜单", _show_menu.bind("SealGame")).grab_focus()
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
	_receipt_requirements.clear()
	_refresh()
	_enter_boundary()

func _start_new(seed_value: int) -> void:
	if _busy: return
	_busy = true
	var result: Dictionary = session.start_new(seed_value)
	_busy = false
	_open_campaign(result)

func _choose_import(restore: Callable) -> void:
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
		restore.call())
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

func _review_save_choice(heading: String, callback: Callable, entry: String) -> void:
	var restore := _show_saved_games.bind(entry, _body_scroll.scroll_vertical)
	_confirm_switch(heading, callback.bind(restore) if entry == "Import" else callback, restore)

func _show_saved_games(focus_name := "ReturnSaves", scroll_position := 0) -> void:
	_open_menu_panel("saved_games", "存档管理", "选择已有存档，或导入一份存档副本。")
	if projection.get("active", false) and FileAccess.file_exists(session.latest_path):
		_menu_action(_body, "Continue", "载入最近存档…", _review_save_choice.bind("载入最近存档", _load_recent, "Continue"))
	var saves: Array = session.saved_games()
	if saves.is_empty(): _line(_body, "尚无已保存的游戏。", 17, UI.MUTED)
	for index: int in saves.size():
		var saved: Dictionary = saves[index]
		var id := "SavedGame_%d" % index
		var card := _button(_body, id, "", Rect2(), _review_save_choice.bind("载入所选存档", _load_saved.bind(saved.path), id))
		card.custom_minimum_size.y = 50
		card.tooltip_text = saved.title
		card.accessibility_name = saved.title
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
	_footer_button("ReturnSaves", "返回菜单", _show_menu.bind("SavedGames")).grab_focus()
	_footer_button("Import", "导入存档副本…", _review_save_choice.bind("导入存档副本", _choose_import, "Import"))
	_focus_surface_control(focus_name)
	_body_scroll.set_deferred("scroll_vertical", scroll_position)

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
	_receipt_requirements.clear()
	_resource_delta = ""
	_world_id = ""
	_interaction.reset_worlds()
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
		_surface.find_child("Save", true, false).grab_focus()
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

func _focus_surface_control(node_name: String) -> void:
	var control := _surface.find_child(node_name, true, false) as Control
	if control != null and _can_focus(control): control.grab_focus()

func _can_focus(control: Control) -> bool:
	return control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and (not control is Button or not control.disabled)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_set_keyboard(false)
	if not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_ESCAPE:
			if event.echo: return
			get_viewport().set_input_as_handled()
			match _dialog:
				"event": pass
				"event_review": _show_event(true)
				"event_context": _close_event_context()
				"world_management": _world_management.back()
				"task_action", "task_confirm", "task_subject", "task_related", "task_plan_confirm", "task_rest_confirm", "task_switch": _tasks.back()
				"prayer_person", "prayer_confirm": _prayers.back_to_detail()
				"power_rules": _powers.close_rules()
				"anchor_goal", "anchor_materials": _tasks.back()
				"receipt": _receipt_return.call() if _receipt_return.is_valid() else _close_surface()
				"prayer_intro": _prayers.close_list()
				"prayer_detail", "prayer_result": _prayers.close()
				"switch": _cancel_switch()
				"new_game": _show_menu("NewGameOptions")
				"settings": _show_menu("Settings")
				"seal": _show_menu("SealGame")
				"saved_games": _show_menu("SavedGames")
				"menu":
					if projection.get("active", false): _close_surface()
				"":
					if not _world_id.is_empty(): _inspect_world("")
					else: _show_menu()
				_: _close_surface()
		KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_SPACE:
			if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
			_set_keyboard(true)
			if not is_instance_valid(_surface): return
			var focus := get_viewport().gui_get_focus_owner()
			var inside := is_instance_valid(focus) and _surface.is_ancestor_of(focus) and _can_focus(focus)
			if inside and focus is LineEdit and event.keycode != KEY_TAB: return
			if event.keycode in [KEY_ENTER, KEY_SPACE]:
				if event.echo or not inside: get_viewport().set_input_as_handled()
				return
			var targets: Array[Node] = _surface.find_children("*", "Control", true, false).filter(func(control: Control) -> bool:
				return _can_focus(control) and (control is LineEdit or control is Button))
			get_viewport().set_input_as_handled()
			if targets.is_empty(): return
			var index := targets.find(focus)
			var offset := -1 if event.shift_pressed or event.keycode in [KEY_UP, KEY_LEFT] else 1
			if index == -1 and offset < 0: index = 0
			targets[posmod(index + offset, targets.size())].grab_focus()
		KEY_F5:
			if not event.echo and projection.get("active", false):
				get_viewport().set_input_as_handled()
				_save(false)
