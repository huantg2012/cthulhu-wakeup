extends RefCounted
## The current request and its UI choices live here. Session owns every decision.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const SpaceView = preload("res://src/presentation/production/prayer_space_view.gd")
const Modes := {"shallow": "浅触", "deep": "深应"}

# A weak host reference keeps the view and its callbacks from retaining the scene.
var _host: WeakRef
var host: Control:
	get: return _host.get_ref()
var cards: Dictionary = {}
var _turn := -1
var _drafts: Dictionary = {}
var _prayer: Dictionary = {}
var _right: Control
var _scroll: ScrollContainer
var _resume_scroll := 0
var _resume_focus := ""
var _error := ""
var _space_view: RefCounted
var _list_domain := ""
var _list_scroll := 0
var _list_origin := Callable()
var _from_list := false

func _init(root: Control) -> void:
	_host = weakref(root)
	_space_view = SpaceView.new(self)

func reset() -> void:
	_turn = -1
	_drafts.clear()
	_prayer = {}
	_list_origin = Callable()
	_from_list = false

func clear_stale_cards() -> void:
	for id: String in cards.keys():
		if not is_instance_valid(cards[id]): cards.erase(id)

func begin_turn() -> void:
	var turn: int = host.projection.turn
	if _turn == turn: return
	_turn = turn
	_drafts.clear()

func browse(domain := "", on_return := Callable()) -> void:
	if host._busy or host.projection.get("phase") != "actions": return
	if host._dialog != "" and not on_return.is_valid(): return
	begin_turn()
	_list_domain = domain
	_list_scroll = 0
	_list_origin = on_return
	_render_list()

func _render_list(selected := "") -> void:
	var fresh: Array = host._pending_prayers() if _list_domain.is_empty() else local_requests(_list_domain)
	host._open_surface("prayer_intro", "第 %s 轮 · 神意所闻" % host.projection.turn, "本轮祈求" if _list_domain.is_empty() else host.title(_list_domain) + " · 当地祈求")
	var caption := "返回回合责任" if _list_origin.is_valid() else ("返回诸界" if _list_domain.is_empty() else "返回当地")
	var back: Button = host._footer_button("DismissPrayers", caption, close_list)
	if fresh.is_empty():
		host._line(host._body, "没有待回应的祈求。")
		back.grab_focus()
		return
	for prayer: Dictionary in fresh:
		_card(host._body, prayer, "IntroPrayer", 566)
	host._scroll_cue(host._body_scroll, host._surface, Layout.box(Rect2(1230, 260, 286, 26)))
	var first: Control = host._body.find_child("IntroPrayer_" + (str(fresh[0].id) if selected.is_empty() else selected), false, false)
	if first == null:
		first = host._body.get_child(0)
		_list_scroll = 0
	first.grab_focus()
	host._body_scroll.set_deferred("scroll_vertical", _list_scroll)

func close_list() -> void:
	var restore := _list_origin
	_list_origin = Callable()
	if restore.is_valid(): restore.call()
	else: host._close_surface()

func local_requests(domain: String) -> Array:
	return host._pending_prayers().filter(func(prayer: Dictionary) -> bool:
		return prayer.descriptor.get("domain", prayer.card.get("domain", "")) == domain)

func build_contact(parent: Control, domain: String, requests: Array) -> void:
	if requests.is_empty() or host.projection.get("terminal", false): return
	var request: Dictionary = requests[0]
	var summary := "一声待回应的祈求" if requests.size() == 1 else "%d 声当地祈求" % requests.size()
	var detail := str(request.title)
	if host.projection.get("prayer_response_spent", false): detail = "本轮回应机会已用 · 仍可查阅"
	var callback := browse.bind(domain)
	if requests.size() == 1: callback = func(): open(request, cards.get(request.id))
	var entry: Button = host._interaction.pin(parent, "PrayerIndex", summary, detail, "≈", Layout.PIN_PRAYER, callback)
	entry.disabled = host.projection.get("phase") != "actions"
	if requests.size() == 1: cards[request.id] = entry

func _identity(prayer: Dictionary) -> String:
	if prayer.descriptor.get("space", false):
		return _person_title(prayer) + " · " + str(prayer.descriptor.get("petitioner_role", "求告者"))
	var person: Dictionary = host._views._find(host, "people", str(prayer.descriptor.get("subjects", {}).get("petitioner", "")))
	return _person_title(prayer) + (" · " + host._views._role(host, person) if not person.is_empty() else "")

func _kind(prayer: Dictionary) -> String:
	if prayer.descriptor.get("space", false): return "祈求"
	var data: Dictionary = host.session.catalog.display_tables.prayers.get(str(prayer.card.get("content_id", "")), {})
	return str({"rescue":"救助", "knowledge":"求证", "belonging":"仪式"}.get(str(data.get("need", "")), "祈求"))

func _card(parent: VBoxContainer, prayer: Dictionary, node_name: String, width: int) -> Button:
	var button: Button = host._button(parent, node_name + "_" + prayer.id, "", Rect2(0, 0, width, 82), open.bind(prayer, null))
	button.custom_minimum_size.y = 82
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.accessibility_name = str(prayer.title) + " · " + _person_title(prayer)
	button.tooltip_text = button.accessibility_name + " · " + _deadline(prayer)
	host._ui.icon(button, "PetitionerSign", "person", Rect2(8, 18, 43, 43))
	host._text(button, str(prayer.title), Rect2(58, 3, width - 69, 42), 16)
	host._text(button, _identity(prayer), Rect2(58, 43, width - 69, 18), 13, UI.MUTED)
	host._text(button, _deadline(prayer), Rect2(58, 62, width - 69, 18), 12, UI.GOLD if prayer.card.get("due_turn") == host.projection.turn else UI.MUTED)
	return button

func _person_title(prayer: Dictionary) -> String:
	var id: String = prayer.descriptor.get("subjects", {}).get("petitioner", "")
	return host.title(id) if not id.is_empty() else "求告者尚不明"

func _deadline(prayer: Dictionary) -> String:
	var due: int = int(prayer.card.get("due_turn", -1))
	if due < 0: return "期限未明"
	return "本轮到期" if due == host.projection.turn else "请求至第 %d 轮" % due

func open(prayer: Dictionary, source: Button) -> void:
	clear_stale_cards()
	if host._busy or host.projection.phase != "actions": return
	if host._dialog == "world_management": host._close_inline()
	if host._dialog not in ["", "prayer_intro", "prayer_detail", "prayer_person", "prayer_result"]: return
	if host._dialog in ["", "prayer_intro"]:
		_from_list = host._dialog == "prayer_intro"
		if _from_list: _list_scroll = host._body_scroll.scroll_vertical
	_remember_scroll()
	_prayer = prayer
	_error = ""
	_stage("prayer_detail", true)
	if is_instance_valid(source) and host._stage.is_ancestor_of(source): host._return_focus = source
	for id: String in cards:
		host._ui.select_entry(cards[id], id == prayer.id)
	_update_detail(("SpaceChoice_" if _is_space() else "Mode_") + _draft().mode)

func _is_space() -> bool:
	return _prayer.get("descriptor", {}).get("space", false)

func _stage(kind: String, reveal := false) -> void:
	prayer_scene(kind, reveal)
	_right = null

func prayer_scene(kind: String, reveal: bool) -> Control:
	var frame: Control = host._scene_frame(kind, "PrayerSpace", Color("#0a1421"))
	var surface: Control = host._surface
	host._ui.image(frame, "PrayerContact", Rect2(Vector2.ZERO, frame.size), host._interaction.picture("atmosphere"), Color(0.7, 0.8, 0.9, 0.55), TextureRect.STRETCH_SCALE)
	var art := _scene_art(surface, _prayer.id, Layout.box(Layout.PETITIONER))
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if reveal:
		art.modulate.a = 0.0
		host._motion.animate(art, "modulate:a", 1.0, host._motion.params.scene_reveal_s)
	var location: String = host.title(str(_prayer.descriptor.get("domain", "")))
	host._reference(surface, "PrayerBreadcrumb", "›    祈求", Rect2(330, 100, 123, 36), 16, UI.MUTED)
	var identity := location + " / " + _person_title(_prayer) + "的祈求"
	var title_width := clampf(identity.length() * 15, 190, 483)
	host._reference(surface, "PrayerLocation", identity, Rect2(78, 167, title_width, 32), 14, UI.MUTED)
	if kind == "prayer_detail":
		var close_button: Button = host._stage_button(surface, "ClosePrayer", "×", Rect2(92 + title_width, 167, 39, 32), close, 22)
		close_button.accessibility_name = "返回祈求列表" if _from_list else "收起祈求"
		close_button.tooltip_text = close_button.accessibility_name
	var context: VBoxContainer = host._surface_column(surface, Layout.STORY)
	context.add_theme_constant_override("separation", 16)
	var expiry: Label = host._line(context, _deadline(_prayer), 11, UI.MUTED)
	expiry.custom_minimum_size.y = 23
	var heading: Label = host._line(context, _prayer.title, 26, UI.BONE)
	heading.name = "PrayerTitle"
	heading.custom_minimum_size.y = 43
	heading.add_theme_font_override("font", host._ui.reference_font(true, 3.0))
	var data: Dictionary = _prayer.descriptor
	var appeal: String = host.session.prayer_appeal(data, _prayer.card)
	if not appeal.is_empty():
		var quote: Label = host._line(context, "“" + appeal + "”", 15, UI.BONE)
		quote.name = "PetitionerAppeal"
		quote.add_theme_constant_override("line_spacing", 8)
	if data.get("crisis", {}).has("due") and int(data.crisis.due) != int(_prayer.card.get("due_turn", -1)):
		host._line(context, "第 %s 轮前，事情将恶化" % data.crisis.due, 13, UI.RISK)
	if kind == "prayer_detail" or kind == "prayer_person": _people_links(context)
	return surface

func response_panel() -> Control:
	return host._scene_plate(host._surface, "Response", Layout.RESPONSE, Color("#0b1720e6"))

func response_rows(panel: Control, extra := 0.0) -> VBoxContainer:
	_scroll = host._scroller(panel, Layout.box(Rect2(25, 30, 415, 227 + extra)))
	return _column(_scroll)

func response_card(body: VBoxContainer, id: String, caption: String, notes: Array[String], handler: Callable, selected: bool) -> Button:
	var control: Button = host._button(body, id, "", Rect2(), handler)
	control.accessibility_name = caption
	control.accessibility_description = "\n".join(notes)
	host._ui.choice_style(control, selected)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14 if side in ["left", "right"] else 10)
	control.add_child(margin)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(words)
	host._line(words, caption, 16, UI.BONE).name = "ChoiceCaption"
	for line: String in notes:
		if not line.is_empty(): host._line(words, line, 12, UI.MUTED)
	var font: Font = host._ui.fonts.body
	var width := Layout.type_size(400) - 28
	var height: float = 20 + font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, width, host._size(16)).y
	for line: String in notes:
		if not line.is_empty():
			height += 4 + font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, host._size(14)).y
	control.custom_minimum_size.y = maxf(Layout.type_size(109), height)
	return control

func response_footer(panel: Control, summary: String, caption: String, handler: Callable) -> Button:
	var text: Label = host._text(panel, summary, Layout.box(Rect2(25, 270, 415, 69)), 12, UI.MUTED)
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var submit: Button = host._stage_button(panel, "Respond", caption, Rect2(25, 351, 415, 44), handler, 17)
	host._ui.scene_submit(submit)
	return submit

func _scene_art(parent: Control, id: String, bounds: Rect2) -> TextureRect:
	var prayer: Dictionary = host._views._find(host, "prayers", id)
	if prayer.is_empty() and str(_prayer.get("id", "")) == id: prayer = _prayer
	var person: String = prayer.get("descriptor", {}).get("subjects", {}).get("petitioner", "")
	return host._object_art(parent, "SceneSlot", bounds, "person", person, true)

func _draft() -> Dictionary:
	if not _drafts.has(_prayer.id):
		_drafts[_prayer.id] = {"mode": "" if _is_space() else "shallow", "inputs": {}, "expanded": false, "scroll": 0}
	return _drafts[_prayer.id]

func _row() -> Dictionary:
	var draft := _draft()
	var key: String = _prayer.key + "/" + draft.mode
	var selection: Dictionary = draft.inputs.get(draft.mode, {})
	draft.inputs[draft.mode] = selection
	var row: Dictionary = host._actions.resolve_row(host, key, selection)
	if row.is_empty(): return row
	# A remembered target that disappears needs an explicit replacement.
	var invalid: bool = selection.keys().any(func(key: String) -> bool: return not row.fields.any(func(field: Dictionary) -> bool: return field.key == key))
	for field: Dictionary in row.fields:
		if not selection.has(field.key): continue
		var values: Array = selection[field.key] if field.get("multiple", false) else [selection[field.key]]
		if values.any(func(value: Variant) -> bool: return not field.options.any(func(option: Dictionary) -> bool: return option.id == value)):
			invalid = true
	if invalid:
		row.preview = {"ok": false, "selection_lost": true, "error": "原选择已不可用，请重新选择。"}
		return row
	for step: int in 4:
		if not host._actions._normalize_unique(row.fields, selection): break
		row = host._actions.resolve_row(host, key, selection)
	return row

func _update_detail(focus_name: String, scroll_position := -1) -> void:
	if _is_space():
		_space_view.update(focus_name, scroll_position)
		return
	host._tasks.begin_candidates()
	host._actions._source_cache.clear()
	var had_panel := is_instance_valid(_right)
	var position := _scroll.scroll_vertical if had_panel else int(_draft().scroll)
	if scroll_position >= 0: position = scroll_position
	if had_panel:
		host._surface.remove_child(_right)
		_right.queue_free()
	_right = response_panel()
	var draft := _draft()
	var body := response_rows(_right)
	var content := str(_prayer.card.get("content_id", ""))
	var wording: Dictionary = host.session.catalog.display_tables.prayers.get(content, {})
	if not _error.is_empty(): host._line(body, _error, 13, UI.RISK)
	for mode: String in Modes:
		var notes: Array[String] = [str(wording.get(mode + "_gain", wording.get(mode + "_hint", "")))]
		var consequence := str(wording.get(mode + "_cost", ""))
		if not consequence.is_empty(): notes.append("代价 · " + consequence)
		response_card(body, "Mode_" + mode, "浅触" if mode == "shallow" else "深干预", notes, func() -> void:
			draft.mode = mode
			_error = ""
			_update_detail("Mode_" + mode), mode == draft.mode)
	var row := _row()
	var preview: Dictionary = row.get("preview", {})
	var costs: Dictionary = preview.get("preview", {})
	var selection: Dictionary = draft.inputs[draft.mode]
	var missing: Array[String] = host._actions._missing_fields(row.get("fields", []), selection)
	var ready: bool = preview.get("ok", false) and missing.is_empty()
	if preview.get("selection_lost", false):
		_row_button(body, "ClearUnavailable", "清除失效的选择", func() -> void:
			selection.clear()
			_update_detail("Mode_" + draft.mode))
	if not row.is_empty(): _fields(body, row.fields, selection)
	var footer_text: String = _space_view._cost_text(costs) + "\n" + _space_view._check_text(costs) + " · 占用本轮回应机会"
	if not ready:
		footer_text = "请先选择" + "、".join(missing) if not missing.is_empty() else str(preview.get("error", "当前不可回应"))
	var execute := response_footer(_right, footer_text, "回应这声祈求" + ("…" if preview.get("irreversible", false) else ""), _respond.bind(row, selection.duplicate(true), false))
	execute.disabled = not ready
	var focus: Control = host._surface.find_child(focus_name, true, false)
	if focus != null and (not focus is Button or not focus.disabled): focus.grab_focus()
	else: _right.get_node("Mode_" + draft.mode).grab_focus()
	_scroll.set_deferred("scroll_vertical", position)
	host._tasks.scan_candidates()
	if had_panel:
		body.modulate.a = 0.76
		host._motion.animate(body, "modulate:a", 1.0, host._motion.params.variant_s)

func _column(scroll: ScrollContainer) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	scroll.add_child(body)
	return body

func _row_button(body: VBoxContainer, node_name: String, caption: String, handler: Callable, selected := false) -> Button:
	var button: Button = host._button(body, node_name, caption, Rect2(), handler, selected)
	button.custom_minimum_size.y = 35
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func _object_choice(body: VBoxContainer, node_name: String, caption: String, id: String, handler: Callable, selected := false) -> Button:
	var person: Dictionary = host._views._find(host, "people", id)
	var relic: Dictionary = host._views._find(host, "relics", id)
	if person.is_empty() and relic.is_empty(): return _row_button(body, node_name, caption, handler, selected)
	var card: Button = _row_button(body, node_name, "", handler, selected)
	card.custom_minimum_size.y = 60
	card.tooltip_text = caption
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8; content.offset_right = -8; content.offset_top = 4; content.offset_bottom = -4
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var art := Control.new()
	art.custom_minimum_size = Vector2(56, 48)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	if not person.is_empty(): host._ui.icon(art, "PersonSymbol", "person", Rect2(8, 3, 38, 38), UI.CYAN)
	else: host._ui.icon(art, "RelicSymbol", "relic", Rect2(8, 3, 38, 38))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(words)
	var label: Label = host._line(words, caption, 16, UI.GOLD_HI if selected else UI.BONE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = caption
	if not person.is_empty(): host._line(words, "人物符号示意", 12, UI.MUTED)
	return card

func _fields(body: VBoxContainer, fields: Array, selection: Dictionary) -> void:
	var draft := _draft()
	var optional: Array = fields.filter(func(f: Dictionary) -> bool: return f.optional and (not f.options.is_empty() or selection.has(f.key)))
	if not optional.is_empty():
		_row_button(body, "Preparation", "收起准备" if draft.expanded else "选择协助与准备", func() -> void:
			draft.expanded = not draft.expanded
			_update_detail("Preparation"))
	for field: Dictionary in fields:
		if field.optional and (not draft.expanded or field.options.is_empty() and not selection.has(field.key)): continue
		if field.options.size() == 1 and not field.optional and not field.multiple and selection.get(field.key) == field.options[0].id: continue
		host._line(body, field.label, 16, UI.GOLD)
		if field.options.is_empty(): host._line(body, "当前没有符合条件的候选。", 15, UI.MUTED)
		if field.optional:
			var clear_name: String = "Clear_" + field.key
			_row_button(body, clear_name, "不使用", func() -> void:
				selection.erase(field.key)
				_update_detail(clear_name), not selection.has(field.key))
		for index: int in field.options.size():
			var option: Dictionary = field.options[index]
			var name_value: String = "Prepare_%s_%d" % [field.key, index]
			var selected: bool = option.id in selection.get(field.key, []) if field.multiple else selection.get(field.key) == option.id
			var candidate: Dictionary = host._tasks.Availability.selection_for(fields, selection, field, option.id)
			var control: Button = _object_choice(body, name_value, host._actions._option_title(host, option), str(option.id), func() -> void:
				selection.clear(); selection.merge(candidate)
				_error = ""
				_update_detail(name_value), selected)
			if not selected:
				host._tasks.guard_action(control, body, "prayer/" + str(_prayer.id) + "/" + str(draft.mode), candidate)

func _people_links(body: VBoxContainer) -> void:
	var subjects: Dictionary = _prayer.descriptor.get("subjects", {})
	var petitioner := str(subjects.get("petitioner", ""))
	var ids: Array = [petitioner]
	for value: Variant in subjects.values():
		ids.append_array(value if value is Array else [value])
	var linked := {}
	for id: Variant in ids:
		var person: Dictionary = host._views._find(host, "people", str(id))
		if person.is_empty() or linked.has(id): continue
		linked[id] = true
		var name_value := "Person_%d" % linked.size()
		var link := _row_button(body, name_value, "查求告者与携带物 ↗" if str(id) == petitioner else "查看 " + host.title(id) + " ↗", _show_person.bind(person, name_value))
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link.add_theme_color_override("font_color", UI.CYAN)

func _show_person(person: Dictionary, origin: String) -> void:
	_remember_return(origin)
	host._begin_peek("prayer_person")
	_right = null
	var body: VBoxContainer = host._peek_content("祈求 / 关联查阅", host.title(person.id))
	host._object_art(host._surface, "PeekPortrait", Layout.box(Rect2(1387, 278, 130, 170)), "person", person.id)
	var role: String = str(_prayer.descriptor.get("petitioner_role", "")) if person.id == _prayer.descriptor.get("subjects", {}).get("petitioner") else ""
	host._line(body, "在这次祈求中 · " + role if not role.is_empty() else "与本次祈求相关的人物", 16, UI.CYAN)
	if person.has("已知范围"): host._line(body, person["已知范围"], 16, UI.MUTED)
	if person.has("profile"): host._line(body, host._views._role(host, person))
	if person.has("status"): host._line(body, "当前已知处境 · " + host._views._state(person.status))
	if person.has("domain"): host._line(body, host.title(person.domain), 16, UI.MUTED)
	if person.get("bound_member", false):
		host._line(body, "正式成员")
		for field: String in ["will", "insight", "influence", "adaptation", "loyalty", "sanity"]:
			if person.has(field):
				var names := {"will":"意志", "insight":"洞察", "influence":"影响", "adaptation":"适应", "loyalty":"忠诚", "sanity":"理智"}
				host._line(body, "%s %s" % [names[field], person[field]])
	for relic: Dictionary in host.projection.get("relics", []):
		if relic.get("holder") == person.id and relic.get("placement") != "consumed":
			host._line(body, "携带 · " + host.title(relic.id))
	host._button(host._surface, "BackToPrayer", "返回原祈求", Layout.box(Rect2(1130, 661, 393, 38)), back_to_detail).grab_focus()
	body.modulate.a = 0.0
	host._motion.animate(body, "modulate:a", 1.0, host._motion.params.related_s)

func _reading() -> VBoxContainer:
	return host._surface_column(response_panel(), Rect2(25, 30, 415, 295))

func _remember_return(origin: String) -> void:
	_resume_focus = origin
	_resume_scroll = _scroll.scroll_vertical

func back_to_detail() -> void:
	_stage("prayer_detail")
	_update_detail(_resume_focus, _resume_scroll)
	_right.modulate.a = 0.8
	host._motion.animate(_right, "modulate:a", 1.0, host._motion.params.related_s)

func _remember_scroll() -> void:
	if host._dialog == "prayer_detail": _draft().scroll = _scroll.scroll_vertical

func close(restore_list := true) -> void:
	clear_stale_cards()
	_remember_scroll()
	for card: Button in cards.values():
		host._ui.select_entry(card, false)
	var return_to_list := _from_list and restore_list
	_from_list = false
	if return_to_list: _render_list(str(_prayer.id))
	else:
		_list_origin = Callable()
		host._close_surface()

func result_return_caption() -> String:
	return "返回祈求列表" if _from_list else "返回当地"

func _respond(row: Dictionary, selection: Dictionary, confirmed: bool) -> void:
	var expected := "prayer_confirm" if confirmed else "prayer_detail"
	if host._busy or host._dice_active() or host._dialog != expected or row.is_empty() or row.key != _prayer.key + "/" + _draft().mode: return
	if not row.preview.get("ok", false) or not host._actions._missing_fields(row.fields, selection).is_empty(): return
	host._busy = true
	var before: Dictionary = host.projection
	host._set_dice_context(str(row.title))
	var result: Dictionary = host.session.execute_action(row.key, selection, confirmed)
	host._busy = false
	if result.get("confirmation", false):
		_remember_return("Respond")
		_stage("prayer_confirm")
		var body := _reading()
		var wording: Dictionary = host.session.catalog.display_tables.prayers.get(str(_prayer.card.get("content_id", "")), {})
		host._line(body, str(wording.get(str(_draft().mode) + "_hint", "")), 18)
		var price: Dictionary = row.get("preview", {}).get("preview", {})
		host._line(body, _space_view._cost_text(price), 16, UI.CYAN)
		host._line(body, _space_view._check_text(price), 18, UI.GOLD)
		host._line(body, "无法撤回；未生效也消耗费用。", 15, UI.RISK)
		host._stage_button(host._surface, "CancelPrayer", "返回祈求", Rect2(1078, 594, 140, 44), back_to_detail).grab_focus()
		host._ui.scene_submit(host._stage_button(host._surface, "ConfirmPrayer", "确认回应", Rect2(1230, 594, 263, 44), _respond.bind(row, selection, true)))
		return
	if not result.get("ok", false):
		host.projection = host.session.project()
		_error = str(result.get("error", "当前条件不允许执行"))
		if confirmed: back_to_detail()
		else: _update_detail("Respond")
		return
	var after: Dictionary = host.session.project()
	_drafts.erase(_prayer.id)
	host._receipt_requirements = []
	host._receipt_checks = result.get("result", {}).get("checks", []).duplicate(true)
	host._receipt = host._feedback.build(host, result, before, after, row.title)
	for check: Dictionary in result.get("result", {}).get("checks", []):
		if int(check.get("roll", -1)) > 0:
			host._receipt.insert(mini(1, host._receipt.size()), "骰点 %s · 成功点数 1–%s" % [check.roll, check.probability])
	host._resource_delta = host._feedback.resource_summary(before, after)
	host._set_notice(result)
	host._refresh()
	if not is_instance_valid(host._return_focus):
		host._return_focus = host._phase_plate
	_stage("prayer_result")
	var body := _reading()
	host._line(body, "第 %s 轮 · 实际回应" % before.turn, 16, UI.CYAN)
	for index: int in host._receipt.size():
		host._line(body, host._receipt[index], 20 if index == 0 else 17, UI.GOLD_HI if index == 0 else UI.BONE)
	host._line(body, "本轮回应机会已用。", 16, UI.CYAN)
	host._button(host._surface, "ClosePrayerResult", result_return_caption(), Layout.box(Rect2(1078, 594, 415, 44)), close).grab_focus()
	host._set_dice_return(close)
	if host._dice_active(): host._dice.cover_current(host)
