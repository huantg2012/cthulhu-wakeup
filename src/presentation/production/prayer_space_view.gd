extends RefCounted
## A concrete decision in the existing prayer scene. Only Session can execute it.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const APPROACHES := {"mercy": "施恩", "bargain": "交易", "horror": "亵变", "twist": "曲解", "reveal": "启示", "coerce": "支配"}
var _parent: WeakRef
var parent: RefCounted:
	get: return _parent.get_ref()
var host: Control:
	get: return parent.host
var _choices_scroll: ScrollContainer

func _init(owner: RefCounted) -> void:
	_parent = weakref(owner)

func choices() -> Array:
	var result: Array = host.session.prayer_space_choices(str(parent._prayer.id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("intensity", 0)) != int(b.get("intensity", 0)): return int(a.get("intensity", 0)) < int(b.get("intensity", 0))
		return str(a.id) < str(b.id))
	return result

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
	parent._right = parent.response_panel()
	var panel: Control = parent._right
	var body: VBoxContainer = parent.response_rows(panel)
	_choices_scroll = parent._scroll
	if not parent._error.is_empty(): host._line(body, parent._error, 13, UI.RISK)
	var selected: Dictionary = {}
	var selected_row: Dictionary = {}
	var first_ready: Button
	var available := choices()
	var spent: bool = host.projection.get("prayer_response_spent", false)
	var window := "本轮回应机会已用" if spent else "本轮可回应一次"
	host._reference(panel, "ResponseIndex", "%d 种回应 · %s" % [available.size(), window], Rect2(25, 4, 290, 24), 13, UI.CYAN)
	host._scroll_cue(_choices_scroll, panel, Layout.box(Rect2(315, 4, 125, 24)))
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
		var approach: String = str(APPROACHES.get(str(choice.get("approach", "")), ""))
		var hint := str(choice.get("hint", "具体后果未知。" if unknown else ""))
		var quoted: Dictionary = preview.get("preview", choice)
		var short_cost := _cost_text(quoted) + (" · " + _check_text(quoted) if enabled else "")
		var notes: Array[String] = [hint, short_cost]
		var upkeep := _upkeep_text(choice)
		if not upkeep.is_empty(): notes.append(upkeep)
		if not enabled: notes.append(str(preview.get("error", "当前条件不满足")))
		var caption := str(choice.label) if approach.is_empty() else approach + " · " + str(choice.label)
		var button: Button = parent.response_card(body, "SpaceChoice_" + id, caption, notes, func() -> void:
			draft.mode = id
			parent._error = ""
			update("SpaceChoice_" + id), active)
		host._ui.set_available(button, enabled)
		if first_ready == null and enabled: first_ready = button
		if active:
			parent._fields(body, row.get("fields", []), selection)
			selected = choice
			selected_row = row
	if available.is_empty(): host._line(body, "当前没有可用回应。可以暂缓，或不再回应。", 17, UI.MUTED)
	var ready: bool = not selected.is_empty() and selected_row.get("preview", {}).get("ok", false)
	var footer := "可查阅其他回应" if spent else "选择你的回应"
	if not selected.is_empty():
		var price: Dictionary = selected_row.get("preview", {}).get("preview", {})
		footer = str(selected.label) + "\n" + (_cost_text(price) + " · 行动费成败皆付" if ready else str(selected_row.get("preview", {}).get("error", "原选择已不可用")))
	host._stage_button(panel, "DeferPrayer", "暂缓", Rect2(248, 320, 78, 29), parent.close, 13)
	var dismiss_button: Button = host._stage_button(panel, "DismissPrayer", "不再回应…", Rect2(333, 320, 107, 29), _review_dismiss, 13)
	dismiss_button.disabled = not host.session.preview_action(str(parent._prayer.key) + "/dismiss").get("ok", false)
	var submit: Button = parent.response_footer(panel, footer, "回应这声祈求", respond.bind(selected_row, selected, false))
	submit.disabled = not ready
	_choices_scroll.set_deferred("scroll_vertical", position)
	var focus: Control = host._surface.find_child(focus_name, true, false)
	if is_instance_valid(focus) and not (focus is Button and focus.disabled):
		focus.grab_focus()
		if focus_name.begins_with("SpaceChoice_") and scroll_position < 0: _reveal_choice(focus, _choices_scroll)
	elif first_ready != null: first_ready.grab_focus()
	else: host._surface.get_node("ClosePrayer").grab_focus()
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
		parent._stage("prayer_confirm")
		var body: VBoxContainer = parent._reading()
		host._line(body, "确认 · " + str(choice.label), 21, UI.GOLD_HI)
		host._line(body, str(choice.get("hint", "具体后果未知。")), 18, UI.VIOLET if choice.get("disclosure") == "unknown" else UI.BONE)
		var price: Dictionary = row.get("preview", {}).get("preview", {})
		host._line(body, _cost_text(price), 16, UI.CYAN)
		host._line(body, _check_text(price), 18, UI.GOLD)
		var upkeep := _upkeep_text(choice)
		if not upkeep.is_empty(): host._line(body, upkeep, 15, UI.MUTED)
		host._line(body, "无法撤回；未生效也消耗费用。", 15, UI.RISK)
		host._button(host._surface, "BackToPrayer", "返回祈求", Layout.box(Rect2(1078, 594, 140, 44)), parent.back_to_detail).grab_focus()
		host._button(host._surface, "ConfirmPrayer", "确认回应", Layout.box(Rect2(1230, 594, 263, 44)), respond.bind(row, choice, true), true)
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
	parent._stage("prayer_result")
	var body: VBoxContainer = parent._reading()
	for index: int in host._receipt.size(): host._line(body, host._receipt[index], 20 if index == 0 else 17, UI.GOLD_HI if index == 0 else UI.BONE)
	host._reference(host._surface, "ResponseSpent", "本轮回应机会已用。", Rect2(1078, 568, 415, 24), 14, UI.CYAN)
	host._button(host._surface, "ClosePrayerResult", parent.result_return_caption(), Layout.box(Rect2(1078, 594, 415, 44)), parent.close).grab_focus()

func _cost_text(price: Dictionary) -> String:
	var text := "低语 %s · 信仰 %s" % [price.get("whispers", 0), price.get("faith", price.get("faith_cost", 0))]
	if int(price.get("first_upkeep", 0)) > 0: text += " · 生效另付 %s 信仰" % price.first_upkeep
	return text

func _check_text(price: Dictionary) -> String:
	var target := int(price.get("success_target", price.get("probability", -1)))
	return "掷出 1–%d 成功" % target if target >= 0 else "按原约定生效"

func _upkeep_text(choice: Dictionary) -> String:
	var turns := int(choice.get("maintenance_turns", 0))
	if turns < 2: return ""
	return "生效后需供奉 %d 轮（含本轮），停供则中断。" % turns

func _receipt(result: Dictionary, before: Dictionary, after: Dictionary, action: String) -> Array[String]:
	var lines: Array[String] = []
	for fact: Dictionary in result.get("facts", []):
		if fact.get("kind") != "prayer_space_result": continue
		var data: Dictionary = fact.get("changes", {})
		var outcome: String = str(data.get("outcome", ""))
		var succeeded := outcome in ["success", "deep", "deterministic"]
		var status := "已显现" if data.get("disclosure") == "unknown" else "已生效"
		if not succeeded: status = "灾变" if outcome == "disaster" else "未生效"
		lines.append(action + " · " + status)
		if int(data.get("roll", -1)) > 0:
			lines.append("骰点 %s · 成功点数 1–%s" % [data.roll, data.get("success_target", data.get("probability", 0))])
		var aftermath: Array[String] = []
		for field: String in ["effect", "tradeoff"]:
			var text := str(data.get(field, ""))
			if not text.is_empty() and not aftermath.has(text): aftermath.append(text)
		if not aftermath.is_empty(): lines.append(" ".join(aftermath))
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

func _review_dismiss() -> void:
	if host._busy or host._dialog != "prayer_detail": return
	var key: String = str(parent._prayer.key) + "/dismiss"
	if not host.session.preview_action(key).get("ok", false): return
	parent._remember_return("DismissPrayer")
	parent._stage("prayer_confirm")
	var body: VBoxContainer = parent._reading()
	host._line(body, "就此断开这声祈求？", 21, UI.GOLD_HI)
	host._line(body, "一旦断开，便不能再回应这声祈求。求告者的处境仍会继续。", 17)
	host._line(body, "无需支付，也不占用本轮回应机会。", 15, UI.MUTED)
	host._stage_button(host._surface, "BackToPrayer", "返回祈求", Rect2(1078, 594, 140, 44), parent.back_to_detail).grab_focus()
	host._ui.scene_submit(host._stage_button(host._surface, "ConfirmDismissPrayer", "确认不再回应", Rect2(1230, 594, 263, 44), _dismiss.bind(key)))

func _dismiss(key: String) -> void:
	if host._busy or host._dialog != "prayer_confirm" or key != str(parent._prayer.key) + "/dismiss": return
	host._busy = true
	var result: Dictionary = host.session.execute_action(key, {}, true)
	host._busy = false
	if not result.get("ok", false):
		parent._error = str(result.get("error", "当前不能关闭此祈求"))
		host.projection = host.session.project()
		parent.back_to_detail()
		return
	parent._drafts.erase(parent._prayer.id)
	host._set_notice(result)
	host._receipt_requirements = []
	host._receipt.assign(["已断开这声祈求", "这声祈求已关闭，本轮回应机会未受影响。"])
	host._resource_delta = ""
	host._refresh()
	parent._stage("prayer_result")
	var body: VBoxContainer = parent._reading()
	host._line(body, host._receipt[0], 21, UI.GOLD_HI)
	host._line(body, host._receipt[1], 16, UI.MUTED)
	host._button(host._surface, "ClosePrayerResult", parent.result_return_caption(), Layout.box(Rect2(1078, 594, 415, 44)), parent.close).grab_focus()
