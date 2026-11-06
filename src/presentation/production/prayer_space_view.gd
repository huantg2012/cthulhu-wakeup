extends RefCounted
## A concrete decision in the existing prayer scene. Only Session can execute it.
const UI = preload("res://src/presentation/ui/ui_components.gd")
const APPROACHES := {"mercy": "施恩", "bargain": "交易", "horror": "亵变", "twist": "曲解", "reveal": "启示", "coerce": "支配"}
var _parent: WeakRef
var parent: RefCounted:
	get: return _parent.get_ref()
var host: Control:
	get: return parent.host
var _choices_scroll: ScrollContainer
var _context_scroll: ScrollContainer

func _init(owner: RefCounted) -> void:
	_parent = weakref(owner)

func choices() -> Array:
	var result: Array = host.session.modules.prayers.space_choices(host.session.world.state, str(parent._prayer.id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("intensity", 0)) != int(b.get("intensity", 0)): return int(a.get("intensity", 0)) < int(b.get("intensity", 0))
		return str(a.id) < str(b.id))
	return result

func stage(kind: String, reveal := false) -> void:
	host._begin_surface(kind, false)
	var surface: Control = host._surface
	host._ui.soft_support(surface, "PrayerSpaceSupport", Rect2(236, 46, 748, 528), Color(0.005, 0.018, 0.021, 0.96))
	var art: TextureRect = parent._scene_art(surface, parent._prayer.id, Rect2(244, 90, 281, 443))
	art.modulate.a = 0.38
	if reveal:
		art.modulate.a = 0.0
		host._motion.animate(art, "modulate:a", 0.38, host._motion.params.scene_reveal_s)
	host._text(surface, parent._prayer.title, Rect2(260, 62, 694, 54), 25, UI.GOLD_HI)
	host._text(surface, parent._identity(parent._prayer), Rect2(263, 116, 440, 38), 16)
	host._text(surface, parent._deadline(parent._prayer), Rect2(742, 116, 210, 38), 15, UI.CYAN)
	_context_scroll = host._scroller(surface, Rect2(263, 171, 244, 327))
	var context: VBoxContainer = parent._column(_context_scroll)
	var data: Dictionary = parent._prayer.descriptor
	host._line(context, host.title(str(data.get("domain", ""))), 15, UI.CYAN)
	if not str(data.get("appeal", "")).is_empty(): host._line(context, "“" + str(data.appeal) + "”", 21, UI.GOLD_HI)
	if not str(data.get("context", "")).is_empty(): host._line(context, str(data.context), 16)
	if not str(data.get("goal", "")).is_empty():
		host._line(context, "所求", 14, UI.MUTED)
		host._line(context, str(data.goal), 17)
	if data.get("crisis", {}).has("due"):
		host._line(context, "第 %s 轮前，事情将恶化" % data.crisis.due, 15, UI.RISK)
	host._text(surface, "场景示意", Rect2(263, 518, 244, 25), 13, UI.MUTED)
	parent._right = null

func update(focus_name := "", scroll_position := -1) -> void:
	var draft: Dictionary = parent._draft()
	var position: int = int(draft.get("scroll", 0))
	if is_instance_valid(parent._right):
		position = parent._scroll.scroll_vertical
		host._surface.remove_child(parent._right)
		parent._right.queue_free()
	if scroll_position >= 0: position = scroll_position
	parent._right = host._region(host._surface, "Response", Rect2(534, 171, 420, 385))
	var panel: Control = parent._right
	var heading := "如何回应 · %d 种" % choices().size()
	for option: Dictionary in choices():
		if str(option.id) == str(draft.mode): heading = str(APPROACHES.get(str(option.get("approach", "")), "回应")) + " · " + str(option.label)
	host._text(panel, heading, Rect2(0, 0, 420, 31), 19, UI.GOLD)
	_choices_scroll = host._scroller(panel, Rect2(0, 40, 420, 238))
	parent._scroll = _choices_scroll
	var body: VBoxContainer = parent._column(_choices_scroll)
	if not parent._error.is_empty(): host._line(body, parent._error, 16, UI.RISK)
	var selected: Dictionary = {}
	var selected_row: Dictionary = {}
	var available := choices()
	for choice: Dictionary in available:
		var id: String = str(choice.id)
		var key: String = str(parent._prayer.key) + "/" + id
		var row: Dictionary = host._actions.resolve_row(host, key, {})
		var preview: Dictionary = row.get("preview", {})
		var enabled: bool = preview.get("ok", false)
		var active: bool = str(draft.mode) == id
		var unknown: bool = choice.get("disclosure", "clear") == "unknown"
		var accent: Color = UI.VIOLET if unknown else (UI.RISK if int(choice.get("intensity", 0)) >= 2 else UI.GOLD)
		var approach: String = str(APPROACHES.get(str(choice.get("approach", "")), ""))
		if not approach.is_empty(): host._line(body, approach + (" · 后果未知" if unknown else ""), 14, accent)
		var button: Button = parent._row_button(body, "SpaceChoice_" + id, str(choice.label), func() -> void:
			draft.mode = id
			parent._error = ""
			update("SpaceChoice_" + id), active)
		button.custom_minimum_size.y = 43
		button.disabled = not enabled
		button.accessibility_description = ("后果未知。" + str(choice.get("omen", ""))) if unknown else str(choice.get("effect", "")) + "；" + str(choice.get("tradeoff", ""))
		if not enabled:
			host._line(body, str(preview.get("error", "当前条件不满足")), 14, UI.MUTED)
		var quoted: Dictionary = preview.get("preview", choice)
		host._line(body, "低语 %s · 信仰 %s" % [quoted.get("whispers", choice.get("whispers", 0)), quoted.get("faith", choice.get("faith", 0))], 14, UI.CYAN)
		if int(quoted.get("first_upkeep", 0)) > 0: host._line(body, "成功后首份供奉 · %s 信仰" % quoted.first_upkeep, 14, UI.CYAN)
		if unknown:
			host._line(body, str(choice.get("omen", "无人知道这句话会被如何听懂。")), 17, UI.VIOLET)
		else:
			host._line(body, str(choice.get("effect", "")), 16)
			if active: host._line(body, str(choice.get("tradeoff", "")), 15, UI.RISK)
		if active:
			host._line(body, ("显现后 · 污染 +%s · 察觉 +%s" if unknown else "成功后 · 污染 +%s · 察觉 +%s") % [choice.get("pollution", 0), choice.get("alert", 0)], 14, UI.CYAN)
			selected = choice
			selected_row = row
			var price: Dictionary = preview.get("preview", {})
			var outcomes: Dictionary = price.get("outcomes", {})
			if enabled and not outcomes.is_empty():
				host._line(body, ("显现 %d%% · 灾变 %d%%" if unknown else "成功 %d%% · 灾变 %d%%") % [int(outcomes.get("success", 0)) + int(outcomes.get("deep", 0)), int(outcomes.get("disaster", 0))], 15, UI.CYAN)
			elif enabled: host._line(body, "必有回应 · 结局未知" if unknown else "无需检定", 15, UI.VIOLET if unknown else UI.CYAN)
			if enabled and not outcomes.is_empty():
				host._line(body, "未能显现也会消耗费用。", 14, UI.MUTED)
				var disaster: String = str(price.get("disaster_text", choice.get("disaster", "")))
				if not disaster.is_empty(): host._line(body, "灾变 · " + disaster, 14, UI.RISK)
	if available.is_empty(): host._line(body, "当前没有可用回应。可以暂缓，或不再回应。", 17, UI.MUTED)
	parent._people_links(body)
	var ready: bool = not selected.is_empty() and selected_row.get("preview", {}).get("ok", false)
	var footer := "选择你的回应"
	if not selected.is_empty():
		var price: Dictionary = selected_row.get("preview", {}).get("preview", {})
		footer = "消耗 %s 低语 · %s 信仰" % [price.get("whispers", 0), price.get("faith", 0)] if ready else str(selected_row.get("preview", {}).get("error", "原选择已不可用"))
		if ready and int(price.get("first_upkeep", 0)) > 0: footer += " · 成功另付 %s" % price.first_upkeep
	host._text(panel, footer, Rect2(0, 287, 420, 30), 17, UI.GOLD_HI if ready else UI.MUTED)
	host._button(panel, "ClosePrayer", "暂缓", Rect2(0, 331, 88, 39), parent.close)
	host._button(panel, "DismissPrayer", "不再回应", Rect2(96, 331, 116, 39), dismiss)
	var submit: Button = host._button(panel, "Respond", "回应", Rect2(224, 331, 196, 39), respond.bind(selected_row, selected, false), true)
	submit.disabled = not ready
	_choices_scroll.set_deferred("scroll_vertical", position)
	var focus: Control = panel.find_child(focus_name, true, false)
	if is_instance_valid(focus) and not (focus is Button and focus.disabled):
		focus.grab_focus()
		if focus_name.begins_with("SpaceChoice_") and scroll_position < 0: _reveal_choice(focus, _choices_scroll)
	else: panel.get_node("ClosePrayer").grab_focus()

func _reveal_choice(control: Control, scroll: ScrollContainer) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if not is_instance_valid(control) or not is_instance_valid(scroll) or scroll != _choices_scroll or host._dialog != "prayer_detail": return
	scroll.scroll_vertical = maxi(0, int(control.position.y) - 28)

func respond(row: Dictionary, choice: Dictionary, confirmed: bool) -> void:
	if host._busy or row.is_empty() or choice.is_empty() or host._dialog != ("prayer_confirm" if confirmed else "prayer_detail"): return
	if row.key != parent._prayer.key + "/" + str(parent._draft().mode): return
	var before: Dictionary = host.projection
	host._busy = true
	var result: Dictionary = host.session.execute_action(row.key, {}, confirmed)
	host._busy = false
	if result.get("confirmation", false):
		parent._remember_return("Respond")
		stage("prayer_confirm")
		var body: VBoxContainer = parent._column(host._scroller(host._surface, Rect2(534, 171, 420, 325)))
		host._line(body, "确认 · " + str(choice.label), 21, UI.GOLD_HI)
		if choice.get("disclosure", "clear") == "unknown":
			host._line(body, str(choice.get("omen", "")), 19, UI.VIOLET)
			host._line(body, "后果未知，改变可能无法挽回。", 17, UI.RISK)
		else:
			host._line(body, str(choice.effect), 18)
			host._line(body, str(choice.tradeoff), 17, UI.RISK)
		host._line(body, "确认后支付费用，并使用本轮回应机会。", 15, UI.MUTED)
		host._button(host._surface, "BackToPrayer", "返回祈求", Rect2(534, 516, 180, 40), parent.back_to_detail).grab_focus()
		host._button(host._surface, "ConfirmPrayer", "确认回应", Rect2(734, 516, 220, 40), respond.bind(row, choice, true), true)
		return
	if not result.get("ok", false):
		parent._error = str(result.get("error", "条件已变化，未执行"))
		host.projection = host.session.project()
		if confirmed: parent.back_to_detail()
		else: update("Respond")
		return
	var after: Dictionary = host.session.project()
	parent._drafts.erase(parent._prayer.id)
	host._receipt_requirements = []
	host._receipt = host._feedback.build(host, result, before, after, str(choice.label))
	host._resource_delta = host._feedback.resource_summary(before, after)
	host._set_notice(result)
	host._refresh()
	stage("prayer_result")
	var body: VBoxContainer = parent._column(host._scroller(host._surface, Rect2(534, 171, 420, 325)))
	for index: int in host._receipt.size(): host._line(body, host._receipt[index], 20 if index == 0 else 17, UI.GOLD_HI if index == 0 else UI.BONE)
	host._line(body, "本轮回应机会已用。", 15, UI.CYAN)
	host._button(host._surface, "ClosePrayerResult", "返回现状", Rect2(534, 516, 420, 40), parent.close).grab_focus()

func dismiss() -> void:
	if host._busy or host._dialog != "prayer_detail": return
	host._busy = true
	var result: Dictionary = host.session.execute_action(str(parent._prayer.key) + "/dismiss", {}, true)
	host._busy = false
	if not result.get("ok", false):
		parent._error = str(result.get("error", "当前不能关闭此祈求"))
		update("DismissPrayer")
		return
	parent.close()
	host._refresh()
