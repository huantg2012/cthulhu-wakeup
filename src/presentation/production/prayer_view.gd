extends RefCounted
## The current request and its UI choices live here. Session owns every decision.
const Composites = preload("res://src/presentation/ui/ui_composites.gd")
const UI = preload("res://src/presentation/ui/ui_components.gd")
const Dock = preload("res://src/presentation/ui/dock_content.gd")
const Modes := {"shallow": "浅触", "deep": "深应"}
const SCENE := "res://docs/art/echoes-ui/round-start-master/assets/abyss-sea.png"

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

func _init(root: Control) -> void:
	_host = weakref(root)

func reset() -> void:
	_turn = -1
	_drafts.clear()
	_prayer = {}

func introduce() -> void:
	var turn: int = host.projection.turn
	if _turn == turn: return
	_turn = turn
	_drafts.clear()
	if host.projection.get("prayer_response_spent", false): return
	var fresh: Array = host._pending_prayers().filter(func(p: Dictionary) -> bool:
		return p.card.get("visible_turn", -1) == turn)
	if fresh.is_empty(): return
	host._open_surface("prayer_intro", "第 %s 轮 · 神意所闻" % turn, "本轮新祈求")
	host._body_scroll.hide()
	var width := 220
	var gap := 19
	var start := (1280 - (width * fresh.size() + gap * (fresh.size() - 1))) * 0.5
	for index: int in fresh.size():
		var prayer: Dictionary = fresh[index]
		var card: Button = host._button(host._surface, "IntroPrayer_" + prayer.id, "", Rect2(start + index * (width + gap), 202, width, 308), func() -> void:
			open(prayer, cards.get(prayer.id)))
		card.accessibility_name = prayer.title
		_scene_art(card, prayer.id, Rect2(0, 0, width, 155))
		host._text(card, "场景示意", Rect2(17, 133, 186, 25), 14, UI.MUTED)
		host._text(card, _identity(prayer), Rect2(17, 159, 186, 31), 16)
		host._text(card, _kind(prayer), Rect2(17, 191, 186, 24), 14, UI.CYAN)
		host._text(card, prayer.title, Rect2(17, 216, 186, 48), 19, UI.GOLD_HI)
		host._text(card, _deadline(prayer), Rect2(17, 267, 186, 28), 15, UI.CYAN)
		card.modulate.a = 0.0
		card.position.y += host._motion.params.card_offset_px
		host._motion.animate(card, "modulate:a", 1.0, host._motion.params.card_entrance_s, index * host._motion.params.card_stagger_s)
		host._motion.animate(card, "position:y", 202.0, host._motion.params.card_entrance_s, index * host._motion.params.card_stagger_s)
	host._footer_button("DismissPrayers", "先查看世界", host._close_surface).grab_focus()

func build_sidebar() -> void:
	cards.clear()
	var prayers: Array = host._pending_prayers()
	var phase: String = host.projection.phase
	var state := "%d 项待回应" % prayers.size()
	if phase == "events": state = "轮初事件处理后可回应"
	elif host.projection.get("prayer_response_spent", false): state = "本轮回应已用 · 只读"
	elif prayers.is_empty(): state = "当前没有待回应祈求"
	host._text(host._stage, state, Rect2(1001, 85, 266, 25), 16, UI.MUTED)
	var scroll: ScrollContainer = host._scroller(host._stage, Rect2(994, 110, 274, 325))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for prayer: Dictionary in prayers:
		cards[prayer.id] = _card(list, prayer, "PrayerCard", 271)
		cards[prayer.id].disabled = phase == "events"

func picture(prayer: Dictionary) -> Texture2D:
	var content: String = prayer.card.get("content_id", "")
	var file: String = {"PRAYER_01":"mila.png", "PRAYER_04":"ivan.png", "PRAYER_05":"sela.png"}.get(content, "")
	return host._ui.texture(host.ART + "restoration-assets/prayer-scenes/" + file if not file.is_empty() else SCENE)

func _identity(prayer: Dictionary) -> String:
	var person: Dictionary = host._views._find(host, "people", str(prayer.descriptor.get("subjects", {}).get("petitioner", "")))
	return _person_title(prayer) + (" · " + host._views._role(host, person) if not person.is_empty() else "")

func _kind(prayer: Dictionary) -> String:
	var data: Dictionary = host.session.catalog.tables.prayers.get(str(prayer.card.get("content_id", "")), {})
	return str({"rescue":"救助", "knowledge":"求证", "belonging":"仪式"}.get(str(data.get("need", "")), "祈求"))

func _card(parent: VBoxContainer, prayer: Dictionary, node_name: String, width: int) -> Button:
	var data := {"person":_identity(prayer), "kind":_kind(prayer) + " · " + host.title(str(prayer.descriptor.get("domain", ""))), "title":prayer.title, "due":_deadline(prayer), "urgent":int(prayer.card.get("due_turn", -1)) == host.projection.turn}
	var button := Composites.prayer_card(host._ui, parent, node_name + "_" + prayer.id, Rect2(0,0,width,90), data, picture(prayer), null, func() -> void: open(prayer, cards.get(prayer.id)), 0.77, 3 if host._large_text else 0)
	button.custom_minimum_size.y = 90
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.accessibility_name = _identity(prayer) + " · " + str(prayer.title)
	var art: TextureRect = button.get_node("SceneImage")
	art.material = host._ui.cropped_scene_material(art.texture, art.size, 0.10)
	return button

func _person_title(prayer: Dictionary) -> String:
	var id: String = prayer.descriptor.get("subjects", {}).get("petitioner", "")
	return host.title(id) if not id.is_empty() else "求告者尚不明"

func _deadline(prayer: Dictionary) -> String:
	var due: int = int(prayer.card.get("due_turn", -1))
	if due < 0: return "期限未明"
	return "本轮到期" if due == host.projection.turn else "请求至第 %d 轮" % due

func open(prayer: Dictionary, source: Button) -> void:
	if host._busy or host.projection.phase != "actions": return
	if host._dialog == "world_management": host._close_inline()
	if host._dialog not in ["", "prayer_intro", "prayer_detail", "prayer_person", "prayer_result"]: return
	_remember_scroll()
	_prayer = prayer
	_error = ""
	_stage("prayer_detail", true)
	if is_instance_valid(source): host._return_focus = source
	for id: String in cards:
		cards[id].add_theme_stylebox_override("normal", host._ui.world_row_style("normal", id == prayer.id))
	_update_detail("Mode_" + _draft().mode)

func _stage(kind: String, reveal := false) -> void:
	host._begin_surface(kind, false)
	var surface: Control = host._surface
	host._ui.soft_support(surface, "PrayerSupport", Rect2(644, 47, 338, 520), Color(0.005,0.018,0.021,0.94))
	host._text(surface, _prayer.title, Rect2(677, 54, 292, 58), 21, UI.GOLD_HI)
	host._text(surface, _identity(_prayer), Rect2(677, 112, 292, 56), 16)
	host._text(surface, "请求期限 · " + _deadline(_prayer), Rect2(677, 170, 292, 29), 15, UI.GOLD)
	host._text(surface, host.title(str(_prayer.descriptor.get("domain", ""))), Rect2(677, 200, 292, 27), 14, UI.CYAN)
	var art := _scene_art(surface, _prayer.id, Rect2(245, 86, 421, 414))
	if reveal:
		art.modulate.a = 0.0
		host._motion.animate(art, "modulate:a", 1.0, host._motion.params.scene_reveal_s)
	host._text(surface, "祈求者场景 · 示意", Rect2(265, 508, 352, 28), 14, UI.MUTED)
	if kind == "prayer_result": host._text(surface, "回应已结算", Rect2(265, 539, 352, 28), 16, UI.GOLD)
	elif _prayer.descriptor.get("crisis", {}).has("due"):
		host._text(surface, "原危机至第 %s 轮" % _prayer.descriptor.crisis.due, Rect2(265, 539, 352, 28), 15, UI.RISK)
	_right = null

func _scene_art(parent: Control, id: String, bounds: Rect2) -> TextureRect:
	var prayer: Dictionary = host._views._find(host, "prayers", id)
	var art: TextureRect = host._ui.image(parent, "SceneSlot", bounds, picture(prayer), Color.WHITE, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.set_meta("subject_id", id)
	art.material = host._ui.cropped_scene_material(art.texture, bounds.size, 0.17)
	return art

func _draft() -> Dictionary:
	if not _drafts.has(_prayer.id):
		_drafts[_prayer.id] = {"mode": "shallow", "inputs": {}, "expanded": false, "scroll": 0}
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
	var had_panel := is_instance_valid(_right)
	var position := _scroll.scroll_vertical if had_panel else int(_draft().scroll)
	if scroll_position >= 0: position = scroll_position
	if had_panel:
		host._surface.remove_child(_right)
		_right.queue_free()
	_right = host._region(host._surface, "Response", Rect2(677, 236, 292, 329))
	var draft := _draft()
	for index: int in Modes.size():
		var mode: String = Modes.keys()[index]
		host._button(_right, "Mode_" + mode, Modes[mode], Rect2(index * 148, 0, 140, 34), func() -> void:
			draft.mode = mode
			_error = ""
			_update_detail("Mode_" + mode, 0), mode == draft.mode)
	_scroll = host._scroller(_right, Rect2(0, 89, 292, 189))
	var body := _column(_scroll)
	var row := _row()
	var preview: Dictionary = row.get("preview", {})
	var costs: Dictionary = preview.get("preview", {})
	var selection: Dictionary = draft.inputs[draft.mode]
	var missing: Array[String] = host._actions._missing_fields(row.get("fields", []), selection)
	var ready: bool = preview.get("ok", false) and missing.is_empty()
	if not _error.is_empty(): host._line(body, _error, 16, UI.RISK)
	if preview.get("selection_lost", false):
		_row_button(body, "ClearUnavailable", "清除失效的选择", func() -> void:
			selection.clear()
			_update_detail("Mode_" + draft.mode))
	if row.is_empty():
		_drafts.erase(_prayer.id)
		host._line(body, "这项祈求已离开当前展示。", 17, UI.RISK)
	else:
		var request: Dictionary = host._actions._prayer_context(host, row.key)
		var effects: Dictionary = host._actions.semantics.prayer(host.session.catalog, request.content, draft.mode)
		if row.details.has("本次求告"): host._line(body, row.details["本次求告"])
		var context: Dictionary = row.duplicate()
		context.details = row.details.duplicate()
		for key: String in ["祈求人", "所在时空", "请求期限", "原危机期限"]:
			context.details.erase(key)
		for line: String in host._actions.context_lines(context, selection, host.title):
			host._line(body, line, 15, UI.MUTED)
		_people_links(body)
		_fields(body, row.fields, selection)
		if not effects.always.is_empty():
			host._line(body, "必付 · " + effects.always, 17, UI.RISK)
		elif ready:
			host._line(body, "必付 · 底栏所列资源", 16, UI.MUTED)
		var probabilities: Dictionary = costs.get("outcomes", {})
		if not probabilities.is_empty():
			var bands: PackedStringArray = []
			for outcome: String in host._actions.OUTCOMES:
				bands.append("%s %d%%" % [host._actions.OUTCOME_NAMES[outcome], probabilities.get(outcome, 0)])
			host._line(body, " · ".join(bands), 15, UI.GOLD)
			for outcome: String in host._actions.OUTCOMES:
				host._line(body, host._actions.OUTCOME_NAMES[outcome], 16, UI.GOLD)
				host._line(body, effects[outcome], 16)
		elif preview.get("ok", false):
			host._line(body, "确定结算 · " + effects.success, 16)
		for warning: String in effects.warning.split("\n", false):
			if not warning.begins_with("必付："): host._line(body, warning, 16, UI.RISK)
		var payment: Dictionary = host._actions.payment_projection(host, row)
		for change: Dictionary in payment.get("changes", []):
			host._line(body, "%s · 轮末预计 %s → %s" % [host.title(change.id), host._views._state(change.before), host._views._state(change.after)], 15, UI.RISK)
	var footer_text := "消耗 %s 低语 · %s 信仰" % [costs.get("whispers", 0), costs.get("faith", costs.get("faith_cost", 0))]
	if not ready:
		footer_text = "请先选择" + "、".join(missing) if not missing.is_empty() else str(preview.get("error", "当前不可回应"))
	host._text(_right, footer_text, Rect2(0, 39, 292, 45), 17, UI.GOLD_HI if ready else UI.RISK)
	host._button(_right, "ClosePrayer", "收起", Rect2(0, 288, 91, 36), close)
	var execute: Button = host._button(_right, "Respond", "以%s回应%s" % [Modes[draft.mode], "…" if preview.get("irreversible", false) else ""], Rect2(108, 288, 180, 36), _respond.bind(row, selection.duplicate(true), false), true)
	execute.disabled = not ready
	var focus: Control = _right.find_child(focus_name, true, false)
	if focus != null and (not focus is Button or not focus.disabled): focus.grab_focus()
	else: _right.get_node("Mode_" + draft.mode).grab_focus()
	_scroll.set_deferred("scroll_vertical", position)
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
	else:
		var index: int = Dock.RELIC_IDS.find(str(relic.get("type", "")))
		if index >= 0: Dock._relic_icon(host._ui, art, index)
		else: host._ui.icon(art, "RelicSymbol", "ritual", Rect2(8, 3, 38, 38))
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
			_object_choice(body, name_value, host._actions._option_title(host, option), str(option.id), func() -> void:
				if field.multiple:
					var values: Array = selection.get(field.key, []).duplicate()
					if selected: values.erase(option.id)
					else: values.append(option.id)
					if values.is_empty(): selection.erase(field.key)
					else: selection[field.key] = values
				else: selection[field.key] = option.id
				_error = ""
				_update_detail(name_value), selected)

func _people_links(body: VBoxContainer) -> void:
	var linked := {}
	for value: Variant in _prayer.descriptor.get("subjects", {}).values():
		var ids: Array = value if value is Array else [value]
		for id: Variant in ids:
			var person: Dictionary = host._views._find(host, "people", str(id))
			if person.is_empty() or linked.has(id): continue
			linked[id] = true
			var name_value := "Person_%d" % linked.size()
			_object_choice(body, name_value, "查看 " + host.title(id), str(id), _show_person.bind(person, name_value))

func _show_person(person: Dictionary, origin: String) -> void:
	_remember_return(origin)
	_stage("prayer_person")
	var body := _reading()
	host._line(body, host.title(person.id), 24, UI.GOLD_HI)
	host._line(body, "与本次祈求相关的人物", 16, UI.CYAN)
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
	host._button(host._surface, "BackToPrayer", "返回原祈求", Rect2(677, 524, 240, 36), back_to_detail).grab_focus()
	body.modulate.a = 0.0
	host._motion.animate(body, "modulate:a", 1.0, host._motion.params.related_s)

func _reading() -> VBoxContainer:
	return _column(host._scroller(host._surface, Rect2(677, 236, 292, 273)))

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

func close() -> void:
	_remember_scroll()
	for card: Button in cards.values():
		card.add_theme_stylebox_override("normal", host._ui.world_row_style("normal", false))
	host._close_surface()

func _respond(row: Dictionary, selection: Dictionary, confirmed: bool) -> void:
	var expected := "prayer_confirm" if confirmed else "prayer_detail"
	if host._busy or host._dialog != expected or row.is_empty() or row.key != _prayer.key + "/" + _draft().mode: return
	if not row.preview.get("ok", false) or not host._actions._missing_fields(row.fields, selection).is_empty(): return
	host._busy = true
	var before: Dictionary = host.projection
	var result: Dictionary = host.session.execute_action(row.key, selection, confirmed)
	host._busy = false
	if result.get("confirmation", false):
		_remember_return("Respond")
		host._open_surface("prayer_confirm", "回应 · 不可撤回", _prayer.title)
		for line: String in host._actions.confirmation_text(host, row.key, selection).split("\n"):
			host._line(host._body, line)
		host._footer_button("CancelPrayer", "返回祈求", back_to_detail).grab_focus()
		host._footer_button("ConfirmPrayer", "确认回应", _respond.bind(row, selection, true), true)
		return
	if not result.get("ok", false):
		host.projection = host.session.project()
		_error = str(result.get("error", "当前条件不允许执行"))
		if confirmed: back_to_detail()
		else: _update_detail("Respond")
		return
	var after: Dictionary = host.session.project()
	_drafts.erase(_prayer.id)
	host._receipt = host._feedback.build(host, result, before, after, row.title)
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
	host._button(host._surface, "ClosePrayerResult", "返回现状", Rect2(677, 524, 240, 36), close).grab_focus()
