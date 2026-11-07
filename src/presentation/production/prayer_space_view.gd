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
	var case_id := str(parent._prayer.descriptor.get("content_id", ""))
	for choice: Dictionary in result:
		if not choice.has("hint"):
			var text: Dictionary = host.session.catalog.prayer_space.tables.response_contracts.get(case_id + "/" + str(choice.id), {})
			choice["hint"] = str(text.get("hint", "具体后果未知。" if choice.get("disclosure") == "unknown" else ""))
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
	host._text(surface, parent._person_title(parent._prayer), Rect2(263, 116, 440, 38), 16)
	host._text(surface, parent._deadline(parent._prayer), Rect2(742, 116, 210, 38), 15, UI.CYAN)
	_context_scroll = host._scroller(surface, Rect2(263, 171, 244, 327))
	var context: VBoxContainer = parent._column(_context_scroll)
	var data: Dictionary = parent._prayer.descriptor
	host._line(context, host.title(str(data.get("domain", ""))), 15, UI.CYAN)
	if not str(data.get("appeal", "")).is_empty(): host._line(context, "“" + str(data.appeal) + "”", 21, UI.GOLD_HI)
	if data.get("crisis", {}).has("due") and int(data.crisis.due) != int(parent._prayer.card.get("due_turn", -1)):
		host._line(context, "第 %s 轮前，事情将恶化" % data.crisis.due, 15, UI.RISK)
	host._text(surface, "场景示意", Rect2(263, 518, 244, 25), 13, UI.MUTED)
	parent._right = null

func update(focus_name := "", scroll_position := -1) -> void:
	host._tasks.begin_candidates()
	host._actions._source_cache.clear()
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
		var selection: Dictionary = draft.inputs.get(id, {})
		draft.inputs[id] = selection
		var row: Dictionary = host._actions.resolve_row(host, key, selection)
		var preview: Dictionary = row.get("preview", {})
		var enabled: bool = preview.get("ok", false)
		var active: bool = str(draft.mode) == id
		var unknown: bool = choice.get("disclosure", "clear") == "unknown"
		var accent: Color = UI.VIOLET if unknown else (UI.RISK if int(choice.get("intensity", 0)) >= 2 else UI.GOLD)
		var approach: String = str(APPROACHES.get(str(choice.get("approach", "")), ""))
		var button: Button = parent._row_button(body, "SpaceChoice_" + id, approach + " · " + str(choice.label), func() -> void:
			draft.mode = id
			parent._error = ""
			update("SpaceChoice_" + id), active)
		button.custom_minimum_size.y = 43
		button.disabled = not enabled
		var hint := str(choice.get("hint", "具体后果未知。" if unknown else ""))
		button.accessibility_description = hint
		if not hint.is_empty(): host._line(body, hint, 16, accent)
		var quoted: Dictionary = preview.get("preview", choice)
		var short_cost := "低语 %s · 信仰 %s" % [quoted.get("whispers", 0), quoted.get("faith", 0)]
		host._line(body, short_cost + (" · " + _check_text(quoted) if enabled else ""), 14, UI.CYAN)
		if int(quoted.get("first_upkeep", 0)) > 0: host._line(body, "生效另付 %s 信仰" % quoted.first_upkeep, 14, UI.CYAN)
		if not enabled:
			host._line(body, str(preview.get("error", "当前条件不满足")), 14, UI.MUTED)
		if active:
			parent._fields(body, row.get("fields", []), selection)
			selected = choice
			selected_row = row
	if available.is_empty(): host._line(body, "当前没有可用回应。可以暂缓，或不再回应。", 17, UI.MUTED)
	parent._people_links(body)
	var ready: bool = not selected.is_empty() and selected_row.get("preview", {}).get("ok", false)
	var footer := "选择你的回应"
	if not selected.is_empty():
		var price: Dictionary = selected_row.get("preview", {}).get("preview", {})
		footer = _cost_text(price) + " · 行动费成败皆付" if ready else str(selected_row.get("preview", {}).get("error", "原选择已不可用"))
	host._text(panel, footer, Rect2(0, 283, 420, 43), 15, UI.GOLD_HI if ready else UI.MUTED)
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
	host._tasks.scan_candidates()

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
	var selection: Dictionary = parent._draft().inputs.get(str(choice.id), {}).duplicate(true)
	var result: Dictionary = host.session.execute_action(row.key, selection, confirmed)
	host._busy = false
	if result.get("confirmation", false):
		parent._remember_return("Respond")
		stage("prayer_confirm")
		var body: VBoxContainer = parent._column(host._scroller(host._surface, Rect2(534, 171, 420, 325)))
		host._line(body, "确认 · " + str(choice.label), 21, UI.GOLD_HI)
		host._line(body, str(choice.get("hint", "具体后果未知。")), 18, UI.VIOLET if choice.get("disclosure") == "unknown" else UI.BONE)
		var price: Dictionary = row.get("preview", {}).get("preview", {})
		host._line(body, _cost_text(price), 16, UI.CYAN)
		host._line(body, _check_text(price), 18, UI.GOLD)
		host._line(body, "无法撤回；未生效也消耗费用。", 15, UI.RISK)
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
	host._receipt = _receipt(result, before, after, str(choice.label))
	host._resource_delta = host._feedback.resource_summary(before, after)
	host._set_notice(result)
	host._refresh()
	stage("prayer_result")
	var body: VBoxContainer = parent._column(host._scroller(host._surface, Rect2(534, 171, 420, 325)))
	for index: int in host._receipt.size(): host._line(body, host._receipt[index], 20 if index == 0 else 17, UI.GOLD_HI if index == 0 else UI.BONE)
	host._line(body, "本轮回应机会已用。", 15, UI.CYAN)
	host._button(host._surface, "ClosePrayerResult", "返回现状", Rect2(534, 516, 420, 40), parent.close).grab_focus()

func _cost_text(price: Dictionary) -> String:
	var text := "低语 %s · 信仰 %s" % [price.get("whispers", 0), price.get("faith", price.get("faith_cost", 0))]
	if int(price.get("first_upkeep", 0)) > 0: text += " · 生效另付 %s 信仰" % price.first_upkeep
	return text

func _check_text(price: Dictionary) -> String:
	var target := int(price.get("success_target", price.get("probability", -1)))
	return "掷出 1–%d 成功" % target if target >= 0 else "按原约定生效"

func _receipt(result: Dictionary, before: Dictionary, after: Dictionary, action: String) -> Array[String]:
	var lines: Array[String] = []
	for fact: Dictionary in result.get("facts", []):
		if fact.get("kind") != "prayer_space_result": continue
		var data: Dictionary = fact.get("changes", {})
		var outcome: String = str(data.get("outcome", ""))
		var succeeded := outcome in ["success", "deep", "deterministic"]
		lines.append(action + " · " + ("已生效" if succeeded else ("灾变" if outcome == "disaster" else "未生效")))
		if int(data.get("roll", -1)) > 0:
			lines.append("骰点 %s · 成功点数 1–%s" % [data.roll, data.get("success_target", data.get("probability", 0))])
		if succeeded:
			var aftermath: Array[String] = []
			for field: String in ["effect", "tradeoff"]:
				var text := str(data.get(field, ""))
				if not text.is_empty() and not aftermath.has(text): aftermath.append(text)
			if not aftermath.is_empty(): lines.append("".join(aftermath))
		else:
			lines.append(str(data.get("summary", "原来的困境仍在。")))
		var numbers: Array[String] = []
		for field: String in data.get("actual_deltas", {}):
			var amount := int(data.actual_deltas[field])
			if amount != 0: numbers.append("%s %+d" % [host._feedback.ATTRIBUTES.get(field, field), amount])
		if not numbers.is_empty(): lines.append(" · ".join(numbers))
		if int(data.get("maintenance_remaining", 0)) > 0:
			lines.append("供奉还需 %d 轮" % int(data.maintenance_remaining))
	var resources: String = host._feedback.resource_summary(before, after)
	if not resources.is_empty(): lines.append(resources)
	return lines

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
