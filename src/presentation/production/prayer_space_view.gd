extends RefCounted
## A concrete decision in the existing prayer scene. Only Session can execute it.
const UI = preload("res://src/presentation/ui/ui_components.gd")
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
	return host.session.modules.prayers.space_choices(host.session.world.state, str(parent._prayer.id))

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
		host._line(context, "原危机至第 %s 轮" % data.crisis.due, 15, UI.RISK)
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
	host._text(panel, "选择如何介入", Rect2(0, 0, 420, 31), 19, UI.GOLD)
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
		var button: Button = parent._row_button(body, "SpaceChoice_" + id, str(choice.label), func() -> void:
			draft.mode = id
			parent._error = ""
			update("SpaceChoice_" + id), active)
		button.custom_minimum_size.y = 43
		button.disabled = not enabled
		button.accessibility_description = str(choice.get("effect", "")) + "；" + str(choice.get("tradeoff", ""))
		if not enabled:
			host._line(body, str(preview.get("error", "当前条件不满足")), 14, UI.MUTED)
		var quoted: Dictionary = preview.get("preview", choice)
		host._line(body, "低语 %s · 信仰 %s" % [quoted.get("whispers", choice.get("whispers", 0)), quoted.get("faith", choice.get("faith", 0))], 14, UI.CYAN)
		if int(quoted.get("first_upkeep", 0)) > 0: host._line(body, "成功后首份供奉 · %s 信仰" % quoted.first_upkeep, 14, UI.CYAN)
		host._line(body, str(choice.get("effect", "")), 16)
		host._line(body, str(choice.get("tradeoff", "")), 15, UI.RISK)
		if active:
			host._line(body, "成功后 · 污染 +%s · 察觉 +%s" % [choice.get("pollution", 0), choice.get("alert", 0)], 14, UI.CYAN)
			selected = choice
			selected_row = row
			var price: Dictionary = preview.get("preview", {})
			var outcomes: Dictionary = price.get("outcomes", {})
			if enabled and not outcomes.is_empty():
				host._line(body, "成功 %d%% · 灾变 %d%%" % [int(outcomes.get("success", 0)) + int(outcomes.get("deep", 0)), int(outcomes.get("disaster", 0))], 15, UI.CYAN)
			elif enabled: host._line(body, "条件满足后确定结算", 15, UI.CYAN)
			if enabled and not outcomes.is_empty():
				host._line(body, "失败仍消耗费用，原处境继续。", 14, UI.MUTED)
				var disaster: String = str(price.get("disaster_text", choice.get("disaster", "")))
				if not disaster.is_empty(): host._line(body, "灾变 · " + disaster, 14, UI.RISK)
	if available.is_empty(): host._line(body, "当前没有可用回应。可以暂缓，或不再回应。", 17, UI.MUTED)
	parent._people_links(body)
	var ready: bool = not selected.is_empty() and selected_row.get("preview", {}).get("ok", false)
	var footer := "请选择一种介入方式"
	if not selected.is_empty():
		var price: Dictionary = selected_row.get("preview", {}).get("preview", {})
		footer = "消耗 %s 低语 · %s 信仰" % [price.get("whispers", 0), price.get("faith", 0)] if ready else str(selected_row.get("preview", {}).get("error", "原选择已不可用"))
		if ready and int(price.get("first_upkeep", 0)) > 0: footer += " · 成功另付 %s" % price.first_upkeep
	host._text(panel, footer, Rect2(0, 287, 420, 30), 17, UI.GOLD_HI if ready else UI.MUTED)
	host._button(panel, "ClosePrayer", "暂缓", Rect2(0, 331, 88, 39), parent.close)
	host._button(panel, "DismissPrayer", "不再回应", Rect2(96, 331, 116, 39), dismiss)
	var submit: Button = host._button(panel, "Respond", "施行回应", Rect2(224, 331, 196, 39), respond.bind(selected_row, selected, false), true)
	submit.disabled = not ready
	_choices_scroll.set_deferred("scroll_vertical", position)
	var focus: Control = panel.find_child(focus_name, true, false)
	if is_instance_valid(focus) and not (focus is Button and focus.disabled): focus.grab_focus()
	else: panel.get_node("ClosePrayer").grab_focus()

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
