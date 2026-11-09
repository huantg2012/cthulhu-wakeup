extends RefCounted
## Native production surfaces using the shared action and knowledge presenters.
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Availability = preload("res://src/presentation/action_availability.gd")

var _owner: WeakRef
var host: Control:
	get: return _owner.get_ref()
var session: RefCounted:
	get: return host.session
var projection: Dictionary:
	get: return host.projection
var draft: Dictionary = {}
var _memory: Dictionary = {}
var _turn := -1
var _key := ""
var _return_to := Callable()
var _subject_return := Callable()
var _return_name := ""
var _return_scroll := 0
var _review := 0
var _subject: Dictionary = {}
var _reading_origin: Dictionary = {}
var _budget_draft: Dictionary = {}
var _budget_anchor := ""
var _anchor_return := Callable()
var _anchor_detail_return := Callable()
var _anchor_initial: Dictionary = {}
var _comparison: Array = []
var _candidate_generation := 0
var _running_generation := -1
var _candidate_queue: Array = []
var _candidate_cache: Dictionary = {}
var _candidate_stamp := 0
var _candidate_job: RefCounted
var _current_fields: Array = []
const WORDS = preload("res://src/presentation/player_terms.gd").WORDS
const RECORD_WORDS := {
	"message":"消息", "power":"权能", "power_effect":"权能影响", "power_attempt":"施展权能",
	"turn_action":"行动支出", "route_material":"活动所得材料", "route_result":"活动结果",
	"relic_operation":"圣物处置", "institution_relic_opportunity":"圣物获取机会",
	"prayer_registered":"收到祈求", "prayer_response":"祈求已回应",
	"prayer_attempt":"尝试回应", "prayer_check":"祈求判定", "turn_wounds":"创伤变化",
	"background_fixed":"处境已形成", "prayer_fixed":"诉求已形成",
	"economy_prepay":"轮末支出", "economy_income":"教团收入", "economy_anchor_payment":"锚点供奉",
	"economy_strategy_payment":"教团经营支出", "economy_rest":"敛息",
	"event_result":"事件结果", "event_fact":"事件影响",
	"population_transfer":"信众变化", "ending_assessed":"存续评估", "ending_sealed":"本局封存",
	"material_received":"收到记录", "progression_result":"活动结果",
	"extinction":"消亡", "awakened":"苏醒", "voluntary":"主动封存",
	"awakening_zero":"苏醒归零", "disconnected":"失去现实联系",
	"manifest_failure":"降临失败", "manifest_completed":"降临完成",
	"reason":"原因", "outcome":"结果", "phase":"阶段",
	"prayer":"祈求", "produced":"实际生成", "whispers_cost":"低语费用",
	"anchor_basis":"扎根依据", "institution_recognized":"机构承认", "anchor_institution_bound":"机构锚定",
	"tag":"材料类别", "originals":"原参与者", "data":"材料内容", "dependencies":"依据记录",
	"operator":"操作者", "series":"连续记录", "uses":"使用记录", "profile":"文明", "rule":"依据类型",
	"relic_type":"媒介类别", "created_turn":"形成回合", "record_series":"连续档案", "record_use":"档案使用",
	"record_dependency":"档案依托", "dual_testimony":"双重见证", "institution":"机构",
}

func _init(owner: Control) -> void:
	_owner = weakref(owner)

func reset() -> void:
	_cancel_candidates()
	_candidate_cache.clear()
	_memory.clear()
	draft = {}
	_turn = -1
	_subject.clear()
	_budget_draft.clear()
	_comparison.clear()
	_reading_origin.clear()
	_return_to = Callable()
	_subject_return = Callable()
	_anchor_return = Callable()
	_anchor_detail_return = Callable()
	_anchor_initial.clear()

func title(id: String) -> String:
	if id.is_empty(): return "未掌握"
	if id.begins_with("ANCHOR/"):
		var anchor: Dictionary = host._views._find(self, "anchors", id)
		if not anchor.is_empty(): return host.title(anchor.institution) + "锚点"
	if id.begins_with("CULT"):
		var cult: Dictionary = host._views._find(self, "cults", id)
		if not cult.is_empty(): return host._views._cult_name(self, cult)
	return host.title(id)

func label(value: String, heading := false) -> Label:
	var text := Label.new()
	text.text = value
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", host._size(18 if heading else 16))
	text.add_theme_color_override("font_color", UI.GOLD_HI if heading else UI.BONE)
	return text

func button(caption: String, callback: Callable) -> Button:
	var control: Button = host._ui.button(null, "TaskButton_%d" % caption.hash(), caption, Rect2(), callback, false, true, host._size(16))
	control.custom_minimum_size.y = 38
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control

func align_person_entry(control: Button) -> void:
	control.custom_minimum_size.y = 30
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = control.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 0.0
		control.add_theme_stylebox_override(state, style)

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func open_action(key: String, initial: Dictionary = {}, on_return := Callable(), switching := false, scope := "") -> void:
	if host._busy or not projection.get("active", false): return
	if key == "POWER_ANCHOR" and not switching and not initial.has("qualification"):
		if not str(initial.get("institution", "")).is_empty(): open_anchor_goal(str(initial.institution), initial, on_return)
		else: open_subject("anchors", str(initial.get("domain", "")), on_return, {"anchor_initial": initial})
		return
	if key == "cults/transfer_material":
		if not str(initial.get("target_institution", "")).is_empty(): open_anchor_goal(str(initial.target_institution))
		else: open_subject("anchors", str(initial.get("domain", "")))
		return
	if not switching and _reading_origin.get("action", false) and host._dialog == "task_related":
		var page := _page_position(_subject)
		_subject = page
		host._open_surface("task_switch", "切换任务", "离开当前行动准备？")
		host._line(host._body, "当前选择会保留到本轮结束。确认后转去准备新行动。")
		host._footer_button("CancelTaskSwitch", "返回资料", _render_subject.bind(page)).grab_focus()
		host._footer_button("ConfirmTaskSwitch", "切换任务", func() -> void:
			_reading_origin.clear()
			open_action(key, initial, on_return, true, scope), true)
		return
	if _turn != projection.turn:
		_memory.clear()
		_turn = projection.turn
	_remember_position()
	var fixed_anchor: bool = key == "POWER_ANCHOR" and host._dialog == "anchor_goal"
	var origin := get_focus()
	var subject := _page_position(_subject) if host._dialog in ["task_subject", "task_related"] else {}
	_return_to = on_return
	if host._dialog in ["task_subject", "task_related"] and not subject.is_empty():
		_return_to = _render_subject.bind(subject)
	host._close_inline()
	var names := initial.keys()
	names.sort()
	_key = key + ("|scope=" + scope if not scope.is_empty() else "")
	for field: String in names: _key += "|" + field + "=" + str(initial[field])
	if not _memory.has(_key):
		var person_scope := scope.begins_with("NPC-")
		_memory[_key] = {"key":key, "selection":initial.duplicate(true), "scroll":0,
			"activity_cult": "" if person_scope else scope, "activity_person": scope if person_scope else ""}
	draft = _memory[_key]
	if key == "POWER_ANCHOR": draft["fixed_anchor"] = fixed_anchor
	if key == "route/context":
		draft["fixed_activity"] = not str(initial.get("domain", "")).is_empty()
		if not draft.has("config_tab"): draft["config_tab"] = "operation"
	host._open_surface("task_action", "行动准备", _action_title(key))
	if is_instance_valid(origin) and host._stage.is_ancestor_of(origin): host._return_focus = origin
	render_workbench(false)

func _action_title(key: String) -> String:
	if session.catalog.display_tables.powers.has(key): return str(session.catalog.display_tables.powers[key].name)
	if key == "cults/transfer_material": return "补齐锚定材料"
	if key == "route/context" and not draft.get("selection", {}).has("operation"): return "持续活动"
	if key == "route/context" and draft.get("selection", {}).has("operation"):
		var row: Dictionary = host._actions.resolve_row(self, key, draft.get("selection", {}))
		return str(row.get("details", {}).get("行动", row.get("title", "当前活动")))
	for item: Dictionary in session.action_entries(key):
		if item.key == key: return str(item.title)
	return "行动准备"

func get_focus() -> Control:
	return host.get_viewport().gui_get_focus_owner()

func _remember_position() -> void:
	if host._dialog != "task_action" or draft.is_empty() or not is_instance_valid(host._body_scroll): return
	draft.scroll = host._body_scroll.scroll_vertical
	var focus := get_focus()
	if is_instance_valid(focus): draft.focus = str(focus.name)

func _restore_action_focus() -> void:
	var replacement: Control = host._surface.find_child(str(draft.get("focus", "ReturnAction")), true, false)
	if not is_instance_valid(replacement) or not replacement.is_visible_in_tree() or (replacement is Button and replacement.disabled):
		replacement = host._surface.find_child("ReturnAction", true, false)
	if is_instance_valid(replacement): replacement.grab_focus()
	host._body_scroll.set_deferred("scroll_vertical", int(draft.get("scroll", 0)))

func render_workbench(remember := true) -> void:
	if host._dialog != "task_action": return
	if remember: _remember_position()
	begin_candidates()
	# The bestow tableau has its own bounded candidate scroller. Keep the
	# surrounding title and navigation fixed instead of nesting page scrolling.
	var key: String = str(draft.get("key", ""))
	var definition: Dictionary = session.catalog.display_tables.powers.get(key, {})
	var locked: bool = not definition.is_empty() and int(projection.get("awakening", 0)) < int(definition.unlock_awakening)
	var current_row: Dictionary = {} if locked else session.action_entry(key, draft.get("selection", {}))
	var fixed: bool = not locked and (key == "POWER_BESTOW" or (not key.begins_with("prayer/") and not key.begins_with("event/") and not current_row.is_empty()))
	host._body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if fixed else ScrollContainer.SCROLL_MODE_AUTO
	if fixed: draft.scroll = 0
	_clear_children(host._body)
	_clear_children(host._footer)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 20)
	host._footer.add_child(controls)
	host._actions.render(self, host._body, controls, true, current_row)
	for control: Control in controls.get_children():
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		control.custom_minimum_size.x = 230 if control is Label else 206
		if control is Button: host._ui.scene_submit(control)
	host._footer_button("ReturnAction", "收起候选" if draft.get("picker_open", false) else "返回", back)
	_restore_action_focus()
	scan_candidates()

func close_picker() -> void:
	draft.picker_open = false
	var key: String = str(draft.get("bestow_tab", "domain")) if draft.get("key") == "POWER_BESTOW" else str(draft.get("config_tab", ""))
	draft.focus = ("BestowTab_" if draft.get("key") == "POWER_BESTOW" else "ActionTab_") + key
	render_workbench(false)

func _resume_action() -> void:
	host._open_surface("task_action", "行动准备", _action_title(draft.key))
	render_workbench(false)

func show_invalid_selection(box: VBoxContainer, row: Dictionary, selection: Dictionary) -> bool:
	var invalid: Array[String] = []
	for field: Dictionary in row.fields:
		if not host._actions._has_value(selection.get(field.key)): continue
		var chosen: Array = selection[field.key] if field.get("multiple", false) else [selection[field.key]]
		if chosen.any(func(value: Variant) -> bool:
			return not field.options.any(func(option: Dictionary) -> bool: return typeof(option.id) == typeof(value) and option.id == value)):
			invalid.append(field.key)
	if invalid.is_empty(): return false
	if draft.get("fixed_activity", false) and "domain" in invalid:
		box.add_child(label("你还没有看清这个世界，无法在此召集人手。"))
		return true
	box.add_child(label("先前选择已不符合当前条件。请清除失效项，再重新选择。"))
	box.add_child(button("清除失效选择", func() -> void:
		for field: String in invalid: selection.erase(field)
		render_workbench()))
	return true

func render_evidence_read(box: VBoxContainer, field: Dictionary, selection: Dictionary) -> void:
	var source: String = str(selection.get(field.key, ""))
	if not session.is_known_source(source): return
	for prior: Node in box.find_children("*", "Button", true, false):
		if prior.get_meta("read_subject", "") == source: return
	var read := button("依据 · " + str(field.options[0].label), show_subject.bind("fact", source))
	read.name = "Read_" + str(field.key)
	read.set_meta("read_subject", source)
	box.add_child(read)

func render_selector(box: VBoxContainer, field: Dictionary, selection: Dictionary) -> void:
	var key: String = field.key
	var chosen: Variant = selection.get(key, [] if field.get("multiple", false) else "")
	var captions: PackedStringArray = []
	for option: Dictionary in field.options:
		if option.id == chosen or (chosen is Array and option.id in chosen):
			captions.append(host._actions._option_title(self, option))
	var expanded: bool = draft.get("expanded_field", "") == key
	var caption := str(field.label).replace("时空", "世界") + " · " + ("请选择" if captions.is_empty() else "、".join(captions))
	var opener := button(caption + ("  ▴" if expanded else "  ▾"), func() -> void:
		draft.expanded_field = "" if expanded else key
		render_workbench())
	opener.name = "Field_" + key
	opener.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	opener.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opener)
	var values: Array = chosen if chosen is Array else [chosen]
	for value: Variant in values:
		if not value is String or value.is_empty(): continue
		var kind := "fact" if session.is_known_source(value) else ""
		for pair: Array in [["people", "person"], ["domains", "world"], ["cults", "cult"], ["institutions", "institution"], ["anchors", "anchor"], ["relics", "relic"]]:
			if not host._views._find(self, pair[0], value).is_empty(): kind = pair[1]; break
		if kind.is_empty(): continue
		var read := button("查阅" if values.size() == 1 else "查看 · " + title(value), show_subject.bind(kind, value))
		read.name = "Read_" + key + ("_%d" % values.find(value) if values.size() > 1 else "")
		read.tooltip_text = "查看 · " + title(value)
		read.set_meta("read_subject", value)
		if values.size() == 1:
			read.custom_minimum_size.x = 74
			row.add_child(read)
		else: box.add_child(read)
	if not expanded: return
	if field.get("optional", false):
		box.add_child(button("不使用", _choose.bind(field, "", selection)))
	for index: int in field.options.size():
		var option: Dictionary = field.options[index]
		var entry := button(host._actions._option_title(self, option), _choose.bind(field, option.id, selection))
		entry.name = "Choice_%s_%d" % [key, index]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		host._ui.select_entry(entry, option.id == chosen or (chosen is Array and option.id in chosen))
		box.add_child(entry)
		guard_choice(entry, box, field, option.id, selection)

func _choose(field: Dictionary, value: Variant, selection: Dictionary) -> void:
	var updated: Dictionary = _choice_selection(field, value, selection)
	selection.clear()
	selection.merge(updated)
	draft.expanded_field = ""
	render_workbench()

func _choice_selection(field: Dictionary, value: Variant, selection: Dictionary) -> Dictionary:
	var candidate: Dictionary = Availability.selection_for(_current_fields, selection, field, value)
	if draft.get("fixed_anchor", false):
		# The institution and its material basis are independent of the guardian.
		for key: String in ["institution", "source", "qualification"]:
			if selection.has(key) and not candidate.has(key): candidate[key] = selection[key]
		if field.key == "qualification": candidate["source"] = value
	if not str(draft.get("activity_person", "")).is_empty(): candidate["npc"] = draft.activity_person
	return candidate

func _cancel_candidates() -> void:
	_candidate_generation += 1
	_candidate_queue.clear()
	if _candidate_job != null: _candidate_job.close(); _candidate_job = null

func begin_candidates() -> void:
	_cancel_candidates()
	var stamp: int = hash([projection, session.knowledge_snapshot()])
	if stamp != _candidate_stamp:
		_candidate_cache.clear()
		_candidate_stamp = stamp

func scan_candidates() -> void:
	_scan_candidates.call_deferred(_candidate_generation, host._dialog)

func activity_actors() -> Array:
	if not str(draft.get("activity_person", "")).is_empty(): return [draft.activity_person]
	if str(draft.get("activity_cult", "")).is_empty(): return []
	var result: Array = []
	for person: Dictionary in projection.get("people", []):
		if person.get("cult_id", "") == draft.activity_cult: result.append(person.id)
	return result if not result.is_empty() else ["__none__"]

func guard_choice(control: Button, words: Container, field: Dictionary, value: Variant, selection: Dictionary) -> void:
	var candidate: Dictionary = _choice_selection(field, value, selection)
	if field.get("multiple", false) and value in selection.get(field.key, []): return
	guard_action(control, words, str(draft.key), candidate, activity_actors() if draft.key == "route/context" else [])

func guard_action(control: Button, words: Container, key: String, candidate: Dictionary, actors: Array = []) -> void:
	var note := label("正在核对当前条件…")
	note.name = "CandidateStatus"
	note.add_theme_font_size_override("font_size", host._size(12))
	note.add_theme_color_override("font_color", UI.MUTED)
	words.add_child(note)
	var token: String = key + "/" + str(actors) + "/" + JSON.stringify(candidate, "", true)
	if not control.has_meta("candidate_description"):
		control.set_meta("candidate_description", control.accessibility_description)
		control.set_meta("candidate_tooltip", control.tooltip_text)
	var item := {"control":weakref(control), "note":weakref(note), "selection":candidate, "key":key, "token":token, "actors":actors,
		"description":control.get_meta("candidate_description"), "tooltip":control.get_meta("candidate_tooltip")}
	host._ui.set_available(control, false)
	control.accessibility_description = (str(item.description) + "\n" + note.text).strip_edges()
	control.tooltip_text = (str(item.tooltip) + "\n" + note.text).strip_edges()
	if _candidate_cache.has(token): _apply_candidate(item, _candidate_cache[token])
	else: _candidate_queue.append(item)

func _apply_candidate(item: Dictionary, result: Dictionary) -> void:
	var control: Button = item.control.get_ref()
	var note: Label = item.note.get_ref()
	if not is_instance_valid(control) or not is_instance_valid(note): return
	host._ui.set_available(control, result.get("ok", false))
	note.text = "" if not control.disabled else session.explain_error(str(result.get("error", "当前没有可执行的组合")))
	note.visible = control.disabled
	note.max_lines_visible = 2
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.tooltip_text = (str(item.tooltip) + "\n" + note.text).strip_edges()
	if control.disabled:
		if control.is_ancestor_of(note): control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 84)
	control.accessibility_description = (str(item.description) + "\n" + note.text).strip_edges()
	control.set_meta("availability", result.duplicate(true))

func _scan_candidates(generation: int, dialog: String) -> void:
	if _running_generation == generation: return
	_running_generation = generation
	while generation == _candidate_generation and not _candidate_queue.is_empty():
		if not is_instance_valid(host) or host._dialog != dialog: _cancel_candidates(); return
		var item: Dictionary = _candidate_queue.pop_front()
		_candidate_job = session.action_candidate(item.key, item.selection, item.actors)
		while not _candidate_job.step():
			await host.get_tree().process_frame
			if generation != _candidate_generation: return
			if not is_instance_valid(host) or host._dialog != dialog: _cancel_candidates(); return
		var result: Dictionary = _candidate_job.result
		_candidate_cache[item.token] = result
		_apply_candidate(item, result)
		_candidate_job = null
		await host.get_tree().process_frame

func run_action(key: String, selection: Dictionary, confirmed := false, review := -1) -> void:
	var expected := "task_confirm" if confirmed else "task_action"
	if host._busy or host._dialog != expected or draft.get("key") != key: return
	if not confirmed and draft.selection != selection: return
	if confirmed and review != _review: return
	var prepared: Dictionary = session.preview_action(key, selection)
	if not prepared.get("ok", false):
		if draft.has("anchor_goal"):
			host._set_notice(prepared)
			_return_to.call()
			return
		_resume_action()
		host._body.add_child(label(session.explain_error(str(prepared.get("error", "")))))
		return
	if not confirmed: _remember_position()
	if not confirmed and (prepared.get("irreversible", false) or key == "POWER_MANIFEST_CANCEL"):
		_review += 1
		host._open_surface("task_confirm", "确认行动", _action_title(key))
		if key == "POWER_ANCHOR":
			var grid := HBoxContainer.new()
			grid.add_theme_constant_override("separation", 34)
			host._body.add_child(grid)
			var target := _summary_column(grid, "目标与人物", title(str(selection.get("institution", ""))))
			host._line(target, "护持 · " + title(str(selection.get("npc", ""))), 14)
			host._line(target, "媒介 · " + title(str(selection.get("relic", ""))), 14)
			var costs: Dictionary = prepared.get("preview", {})
			_summary_column(grid, "本次始终支付", "%s 低语 / %s 信仰" % [costs.get("whispers", 0), costs.get("faith", costs.get("faith_cost", 0))])
			var upkeep := _summary_column(grid, "成功后仍需承担", "本轮供奉")
			host._line(upkeep, "按实际维护条件与支付结果判断锚点是否有效。", 14, UI.MUTED)
		host._line(host._body, host._actions.confirmation_text(self, key, selection))
		host._footer_button("CancelAction", "取消", _resume_action).grab_focus()
		host._footer_button("ConfirmAction", "确认执行", run_action.bind(key, selection.duplicate(true), true, _review), true)
		return
	var before := projection
	var requirement_before: Array = host._actions.requirement_groups(self, before, session.action_entry(key, selection), selection)
	var caption := _action_title(key)
	host._busy = true
	var result: Dictionary = session.execute_action(key, selection, confirmed)
	host._busy = false
	host._set_notice(result)
	if not result.get("ok", false):
		if draft.has("anchor_goal"):
			_return_to.call()
			return
		_resume_action()
		host._body.add_child(label(session.explain_error(str(result.get("error", "")))))
		return
	var after: Dictionary = session.project()
	host._receipt = host._feedback.build(host, result, before, after, caption)
	var requirement_after: Array = host._actions.requirement_groups(self, after, session.action_entry(key, selection), selection)
	host._receipt_requirements = host._actions.Requirements.changes(requirement_before, requirement_after)
	host._resource_delta = host._feedback.resource_summary(before, after)
	var receipt_return := _return_to
	if key == "route/context":
		var scope: String = str(draft.get("activity_person", ""))
		if scope.is_empty(): scope = str(draft.get("activity_cult", ""))
		receipt_return = open_action.bind(key, selection, _return_to, true, scope)
	_memory.erase(_key)
	draft = {}
	var anchor_action := key == "POWER_ANCHOR"
	var domain: String = str(selection.get("domain", ""))
	if anchor_action and not host._views._find(self, "domains", domain).is_empty(): host._world_id = domain
	host._refresh()
	host._show_receipt(receipt_return, domain if anchor_action else str(selection.get("npc", domain)) if key.begins_with("POWER_") else "", anchor_action)

func show_subject(kind: String, id := "") -> void:
	if not projection.get("active", false): return
	if kind == "materials": open_activities(id); return
	if kind == "people" and _subject.get("kind") == kind and _subject.get("id") == id and host._dialog == "task_subject":
		var page := _page_position(_subject)
		page.scroll = 0
		_render_subject(page)
		return
	if host._dialog in ["task_subject", "task_related"] and _subject.get("kind") == "history" and kind == "fact":
		_select_record(id, true)
		return
	_remember_position()
	if host._dialog == "task_action":
		_return_name = str(draft.get("focus", "ReturnAction"))
		_return_scroll = int(draft.get("scroll", 0))
		_reading_origin = {"action":true}
		if kind == "budget": _budget_draft = {}
	elif host._dialog == "task_subject" and (kind != _subject.get("kind") or id != _subject.get("id")):
		_reading_origin = _page_position(_subject)
	else:
		if host._dialog != "task_related": _reading_origin.clear()
		host._close_inline()
	_render_subject({"kind":kind, "id":id})

func open_subject(kind: String, id := "", on_return := Callable(), context: Dictionary = {}) -> void:
	if not projection.get("active", false): return
	if kind == "materials": open_activities(id, on_return); return
	if kind == "budget": _budget_draft = {}
	var origin := get_focus()
	_remember_position()
	host._close_inline()
	_reading_origin.clear()
	_subject_return = on_return
	_render_subject({"kind":kind, "id":id}.merged(context))
	if is_instance_valid(origin) and host._stage.is_ancestor_of(origin): host._return_focus = origin

func open_activities(id := "", on_return := Callable()) -> void:
	var cult: Dictionary = host._views._find(self, "cults", id)
	var domain: String = str(cult.domain) if not cult.is_empty() else (id if not id.is_empty() else host._world_id)
	open_action("route/context", {"domain":domain}, on_return, false, str(cult.get("id", "")))

func open_person_activity(selection: Dictionary) -> void:
	open_action("route/context", selection, Callable(), false, str(selection.get("npc", "")))

func _page_position(page: Dictionary) -> Dictionary:
	var saved := page.duplicate()
	saved.scroll = host._body_scroll.scroll_vertical
	var focus := get_focus()
	if is_instance_valid(focus): saved.focus = str(focus.name)
	return saved

func _render_subject(page: Dictionary) -> void:
	begin_candidates()
	_subject = page.duplicate()
	var kind: String = page.kind
	var id: String = page.id
	var heading: String = {
		"opportunities":"限时圣物机会", "people":"人物", "relics":"圣物", "anchors":"锚点与护持", "materials":"活动与进展",
		"budget":"本轮收支", "attention":"关注与成员名额", "history":"编年史",
		"comparison":"已知对象对照", "fact":"事情经过", "self":"本体与苏醒",
		"ending":"本局已封存", "cults":"教团", "institutions":"世界机构",
	}.get(kind, title(id))
	if kind == "people" and not id.is_empty(): heading = title(id) + "的人物"
	if kind == "institution":
		var institution: Dictionary = host._views._find(self, "institutions", id)
		heading = preload("res://src/presentation/player_record_text.gd").entity_name(self, id, str(institution.get("domain", "")))
	host._open_surface("task_related" if not _reading_origin.is_empty() else "task_subject", "回顾" if kind in ["history", "fact"] else "当前事务", heading)
	if _reading_origin.get("action", false):
		host._line(host._body, "为「%s」查看" % _action_title(draft.key), 15, UI.CYAN)
	match kind:
		"budget": _render_budget()
		"people":
			if _reading_origin.get("action", false): host._views._people(self, host._body, id)
			else: _render_people(page)
		"person":
			if not _reading_origin.is_empty():
				_person_art(host._body, id, Vector2(104, 136))
				host._views.render(self, host._body, kind, id)
			else:
				var right := _right_column()
				_person_art(host._body, id, Vector2(326, 232))
				host._views.render(self, right, kind, id)
		"relic":
			_render_relic_icon(id)
			host._views.render(self, host._body, kind, id)
		"history": _render_history(page)
		"relics": _render_relic_comparison(id)
		"self": _render_progress()
		"ending":
			host._line(host._body, "结局 · " + describe(projection.outcome), 19, UI.GOLD_HI)
			if projection.has("ending_reason"):
				host._line(host._body, "原因 · " + describe(projection.ending_reason))
			host._line(host._body, "第 %s 轮 · 最终苏醒 %s" % [projection.turn, projection.awakening])
			host._line(host._body, "本局只读。可查阅已知资料，或返回菜单开始新局。", 16, UI.MUTED)
			host._body.add_child(button("回顾编年史", show_subject.bind("history", "")))
			host._body.add_child(button("返回游戏菜单", host._show_menu))
		"comparison": host._views.render_comparison(self, host._body, _comparison)
		"cults":
			for cult: Dictionary in projection.cults:
				var entry := button(host._views._cult_name(self, cult), _open_cult.bind(cult.domain))
				host._body.add_child(entry)
			if projection.cults.is_empty(): host._line(host._body, "尚无已知教团。")
		_: host._views.render(self, host._body, kind, id)
	if kind in ["person", "relic", "anchor"] and not id.is_empty() and not _reading_origin.get("action", false):
		host._body.add_child(button("留作对照", _pin_comparison.bind(kind, id)))
		if not _comparison.is_empty(): host._body.add_child(button("查看对照", show_subject.bind("comparison", "")))
	var caption := str(page.get("return_caption", "返回当前场景 ↩"))
	if _reading_origin.get("action", false): caption = "返回行动 ↩"
	if page.has("original_record"): caption = "返回原记录 ↩"
	host._footer_button("ReturnSubject", caption, back).grab_focus()
	_restore_page(page)
	scan_candidates()

func _person_art(parent: VBoxContainer, id: String, extent: Vector2) -> void:
	var slot := Control.new()
	slot.custom_minimum_size.y = extent.y
	parent.add_child(slot)
	host._ui.image(slot, "PersonPlaceholder", Rect2(Vector2.ZERO, extent), host._interaction.picture("person_portrait")).set_meta("subject_id", id)

func _render_people(page: Dictionary) -> void:
	var directory := Layout.box(Rect2(82, 400, 350, 296))
	host._body_scroll.position = directory.position
	host._body_scroll.size = directory.size
	var filters := VBoxContainer.new()
	host._ui.rect(filters, Layout.box(Rect2(82, 294, 350, 100)))
	filters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._surface.add_child(filters)
	host._scroll_cue(host._body_scroll, host._surface, Layout.box(Rect2(231, 712, 201, 20)))
	host._ui.fill(host._surface, "DirectoryDivider", Layout.box(Rect2(432, 294, 1, 402)), UI.LINE)
	var id: String = str(page.get("person", ""))
	var filter := "people/" + str(page.id)
	var people: Array = projection.people.filter(func(person: Dictionary) -> bool:
		return (str(page.id).is_empty() or person.get("domain", "") == page.id) and host._views._person_matches(self, person, str(host._views.queries.get(filter, "")).strip_edges(), bool(host._views.person_filters.get(filter, false))))
	if not people.any(func(person: Dictionary) -> bool: return person.id == id):
		id = str(people[0].id) if not people.is_empty() else ""
	host._views._people(self, host._body, page.id, id, _read_person_in_directory, filters)
	if id.is_empty():
		host._reference(host._surface, "NoPerson", "尚无匹配人物。", Rect2(487, 294, 500, 49), 17, UI.MUTED)
		return
	host._ui.image(host._surface, "DirectoryPortrait", Layout.box(Rect2(487, 294, 270, 365)), host._interaction.picture("person_portrait")).set_meta("subject_id", id)
	host._reference(host._surface, "DirectoryPerson", title(id), Rect2(787, 294, 731, 47), 29, UI.BONE, true, 2)
	var reading: VBoxContainer = host._surface_column(host._surface, Rect2(787, 393, 731, 303))
	var person_tab: String = str(page.get("person_tab", "duties"))
	var tabs: Array = [["duties", "职责"], ["ability", "能力"], ["carried", "携带物"], ["history", "经历"], ["actions", "适用行动"]]
	for index: int in tabs.size():
		var spec: Array = tabs[index]
		var control: Button = host._stage_button(host._surface, "DirectoryTab_" + spec[0], spec[1], Rect2(787 + 104 * index, 345, 99, 34), _directory_tab.bind(id, spec[0]))
		host._ui.choice_style(control, spec[0] == person_tab)
	host._views._person(self, reading, id, person_tab)

func _directory_tab(id: String, tab: String) -> void:
	var page := _page_position(_subject)
	page.person = id
	page.person_tab = tab
	_render_subject(page)

func _read_person_in_directory(id: String) -> void:
	_directory_tab(id, "duties")

func _render_relic_comparison(domain: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 16)
	host._body.add_child(grid)
	for item: Dictionary in projection.relics:
		if item.get("placement") == "consumed" or (not domain.is_empty() and item.get("domain") != domain): continue
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 300
		grid.add_child(column)
		var figure := Control.new()
		figure.custom_minimum_size.y = 90
		column.add_child(figure)
		host._ui.icon(figure, "RelicPlaceholder", "relic", Rect2(0, 0, 90, 90))
		host._line(column, title(item.id), 20)
		var definition: Dictionary = session.catalog.display_tables.relics.get(str(item.get("type", "")), {})
		host._line(column, str(definition.get("anchor_role", "")), 14, UI.MUTED)
		host._line(column, str(host._views.PLACEMENTS.get(item.get("placement"), "仅有请求线索")), 14)
		column.add_child(button("查看用途与代价 ↗", show_subject.bind("relic", item.id)))
	if grid.get_child_count() == 0: host._line(host._body, "此范围内没有当前已知的圣物。", 16, UI.MUTED)
	host._views._opportunities(self, host._body, domain)

func _render_progress() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 34)
	host._body.add_child(columns)
	var current := _summary_column(columns, "当前苏醒", str(projection.awakening))
	host._line(current, host._views.next_power_hint(session.catalog, int(projection.awakening)), 14)
	var rest := button("查看敛息与恢复代价", request_rest)
	rest.disabled = projection.phase != "actions" or projection.get("terminal", false)
	current.add_child(rest)
	var sources := _summary_column(columns, "现实依托", "苏醒来源")
	for value: Dictionary in projection.get("awakening_sources", []):
		host._line(sources, "%s · %s" % [title(str(value.title)) if value.get("kind") == "anchor" else str(value.get("title", "来源")), value.get("value", 0)], 14)
	var ritual := _summary_column(columns, "终极降临", "降临进行中" if not projection.get("manifest", {}).is_empty() else "尚未开始")
	host._views._self(self, ritual, true)

func _summary_column(parent: HBoxContainer, eyebrow: String, value: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	parent.add_child(column)
	host._line(column, eyebrow, 13, UI.CYAN)
	var amount: Label = host._line(column, value, 25, UI.GOLD)
	amount.add_theme_font_override("font", host._ui.reference_font(true, 1.0))
	return column

func _render_relic_icon(id: String) -> void:
	if host._views._find(self, "relics", id).is_empty(): return
	var symbol := Control.new()
	symbol.custom_minimum_size.y = 56
	host._body.add_child(symbol)
	host._ui.icon(symbol, "RelicSymbol", "relic", Rect2(0, 0, 46, 46))

func _open_cult(domain: String) -> void:
	var page := _page_position(_subject)
	host._world_management.open_cult(domain, _render_subject.bind(page))

func manage_cult(id: String, switching := false) -> void:
	var cult: Dictionary = host._views._current_cult(self, id)
	if cult.is_empty(): return
	var page := _page_position(_subject)
	_subject = page
	if _reading_origin.get("action", false) and not switching:
		host._open_surface("task_switch", "切换任务", "转去管理教团？")
		host._line(host._body, "当前行动的选择会保留到本轮结束。")
		host._footer_button("CancelTaskSwitch", "返回资料", _render_subject.bind(page)).grab_focus()
		host._footer_button("ConfirmTaskSwitch", "管理教团", manage_cult.bind(id, true), true)
		return
	if switching: _reading_origin.clear()
	host._world_management.open_cult(cult.domain, _render_subject.bind(page))

func _responded() -> bool:
	return projection.get("prayer_response_spent", false)

func crisis_summary(plan: Dictionary) -> String:
	var rule: Dictionary = session.catalog.display_tables.resistance_plans.get(str(plan.get("rule", "")), {})
	return "%s · %s · 第%s轮到期" % [title(str(plan.get("target", plan.get("domain", "")))), rule.get("name", "已知反制"), plan.get("due", "?")]

func start_new(seed_value: int) -> void:
	host._confirm_switch("开始新局", host._start_new.bind(seed_value))

func search_field(box: VBoxContainer, key: String, value: String) -> LineEdit:
	var field: LineEdit = host._ui.search_field(box, "SubjectSearch_" + key.replace("/", "_"), "名称或编号 · 回车查找", Rect2())
	field.custom_minimum_size.y = 36
	field.text = value
	return field

func _restore_page(page: Dictionary) -> void:
	host._body_scroll.set_deferred("scroll_vertical", int(page.get("scroll", 0)))
	if not page.has("focus"): return
	var focus: Control = host._surface.find_child(str(page.focus), true, false)
	if is_instance_valid(focus) and (not focus is Button or not focus.disabled): focus.grab_focus()

func describe(value: Variant, depth := 0) -> String:
	if value == null: return "未掌握"
	if value is bool: return "是" if value else "否"
	var lines: PackedStringArray = []
	if value is Dictionary:
		for key: Variant in value:
			if str(key) in ["ok","preview","issuer","version","declaration","source_ids","once_key","mutex","basis","outcomes","descriptor"]: continue
			var field := "深应" if key == "variant" and value[key] == "deep" else describe(value[key], depth + 1)
			var line := describe(str(key), depth + 1) + "：" + field
			if line not in lines: lines.append(line)
		return "\n".join(lines) if not lines.is_empty() else "无"
	if value is Array:
		for item: Variant in value: lines.append(describe(item, depth + 1))
		return ("、" if depth > 1 else "\n").join(lines) if not lines.is_empty() else "无"
	var word := str(value)
	if RECORD_WORDS.has(word): return RECORD_WORDS[word]
	if WORDS.has(word): return WORDS[word]
	var definition: Dictionary = session.catalog.display_tables.powers.get(word, {})
	if not definition.is_empty(): return str(definition.name)
	definition = session.catalog.display_tables.prayers.get(word, {})
	if not definition.is_empty(): return str(definition.title)
	for table: String in ["civilization_profiles", "relics"]:
		definition = session.catalog.display_tables[table].get(word, {})
		if not definition.is_empty(): return str(definition.get("name", word))
	definition = session.catalog.display_tables.progression_route_operations.get(word, {})
	if not definition.is_empty(): return str(definition.get("title", definition.get("name", "活动")))
	if word.begins_with("BACKGROUND-"):
		for prayer: Dictionary in projection.prayers:
			if prayer.id == word: return str(prayer.title)
		return "原祈求"
	if word.begins_with("FACT-"):
		return title(word) if session.is_known_source(word) else "尚未获知的前因"
	if word.begins_with("DOMAIN-") or word.begins_with("NPC-") or word.begins_with("RELIC/") or word.begins_with("CULT/") or word.begins_with("ANCHOR/"):
		return title(word)
	return word

func back() -> void:
	match host._dialog:
		"anchor_goal":
			if _anchor_return.is_valid(): _anchor_return.call()
			else: host._close_surface()
		"anchor_materials":
			if _anchor_detail_return.is_valid(): _anchor_detail_return.call()
			else: host._close_surface()
		"task_confirm": _resume_action()
		"task_switch": _render_subject(_subject)
		"task_plan_confirm": _render_subject(_subject)
		"task_rest_confirm": _render_subject(_subject)
		"task_related":
			if _subject.get("kind") == "history" and _subject.has("original_record"):
				_return_record()
				return
			var origin := _reading_origin.duplicate()
			_reading_origin.clear()
			if origin.get("action", false):
				draft.scroll = _return_scroll
				draft.focus = _return_name
				_resume_action()
			elif origin.has("kind"): _render_subject(origin)
			else: host._close_surface()
		"task_action":
			if draft.get("picker_open", false):
				close_picker()
				return
			_remember_position()
			if _return_to.is_valid(): _return_to.call()
			else: host._close_surface()
		"task_subject":
			if _subject.get("kind") == "history" and _subject.has("original_record"):
				_return_record()
				return
			if _subject_return.is_valid():
				var restore := _subject_return
				_subject_return = Callable()
				restore.call()
			else: host._close_surface()
		_: host._close_surface()


func _pin_comparison(kind: String, id: String) -> void:
	var entry := {"kind":kind, "id":id}
	if entry not in _comparison:
		if _comparison.size() == 2: _comparison.pop_front()
		_comparison.append(entry)
	show_subject("comparison")

func _right_column() -> VBoxContainer:
	host._body_scroll.size.x = 336
	var scroll: ScrollContainer = host._scroller(host._surface, Rect2(457, 207, 748, 327))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	return column

func _render_budget() -> void:
	var plan: Dictionary = _budget_draft if not _budget_draft.is_empty() else host._views._plan(self)
	var result: Dictionary = session.preview_plan(plan) if projection.phase == "actions" else session.economy_preview()
	var preview: Dictionary = result.get("preview", {})
	var summaries := HBoxContainer.new()
	summaries.add_theme_constant_override("separation", 34)
	host._body.add_child(summaries)
	var balance := _summary_column(summaries, "当前信仰", str(projection.faith))
	host._line(balance, "当前可用于行动与先付支出的储备。", 14, UI.MUTED)
	var after: int = int(preview.get("faith_after_prepay", projection.faith))
	var upkeep := _summary_column(summaries, "本轮先付责任", str(int(preview.get("faith_before", projection.faith)) - after))
	host._line(upkeep, "支出后预计余量 · %s" % after, 14, UI.MUTED)
	var income := 0
	for row: Dictionary in preview.get("cults", []): income += int(row.get("income_if_unchanged", 0))
	var earnings := _summary_column(summaries, "条件收入", str(income))
	host._line(earnings, "按当前局势预计，轮末实际入账。", 14, UI.MUTED)
	var right: VBoxContainer = host._body
	for row: Dictionary in preview.get("cults", []):
		if host._views._find(self, "cults", str(row.cult)).is_empty(): continue
		host._views._object_link(self, right, title(row.cult), "支出 %s · 预计收入 %s" % [row.fee, row.income_if_unchanged], "cult", row.cult, "management")
	if _reading_origin.get("action", false):
		var row: Dictionary = host._actions.resolve_row(self, draft.key, draft.selection)
		var payment: Dictionary = host._actions.payment_projection(self, row)
		if payment.get("ok", false):
			host._line(host._body, "若先执行「%s」
行动后 %s · 轮末先付后 %s（现有安排）" % [row.title, payment.faith_after_action, payment.faith_after_prepay], 15, UI.CYAN)
	host._body.add_child(button("查看实际结算记录", show_subject.bind("history", "")))
	host._line(right, "供奉顺序", 19, UI.GOLD_HI)
	var known: Array = plan.anchor_priority.filter(func(id: String) -> bool: return not host._views._find(self, "anchors", id).is_empty())
	if known.is_empty(): host._line(right, "当前没有已知锚点。", 16, UI.MUTED)
	for id: String in known:
		var forecast: Dictionary = {}
		for row: Dictionary in preview.get("anchors", []):
			if row.anchor == id: forecast = row; break
		var reason: String = str(forecast.get("reason", ""))
		var state: String = "本轮停供" if id in plan.refuse_anchors else ("轮末待结算" if forecast.is_empty() else ("%s 信仰" % forecast.get("fee", 0) if reason.is_empty() else host._views._economy_reason(self, reason)))
		var caption := "%d · %s" % [known.find(id) + 1, title(id)]
		var entry := button("", _pick_budget_anchor.bind(id))
		entry.custom_minimum_size.y = 64
		entry.tooltip_text = caption + " · " + state
		host._ui.select_entry(entry, id == _budget_anchor)
		right.add_child(entry)
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8; content.offset_right = -8; content.offset_top = 4; content.offset_bottom = -4
		content.add_theme_constant_override("separation", 8)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(content)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(42, 44)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		host._ui.icon(icon, "AnchorSymbol", "anchor_status", Rect2(5, 5, 30, 32))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(words)
		var label: Label = host._line(words, caption, 16, UI.GOLD_HI if id == _budget_anchor else UI.BONE)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		host._line(words, state, 14, UI.MUTED)
		if id == _budget_anchor:
			right.add_child(button("查阅锚点", show_subject.bind("anchor", id)))
			if projection.phase == "actions":
				var controls := HBoxContainer.new()
				right.add_child(controls)
				var up := button("上移", _edit_supply.bind(id, -1))
				var down := button("下移", _edit_supply.bind(id, 1))
				var toggle := button("恢复供奉" if id in plan.refuse_anchors else "本轮停供", _edit_supply.bind(id, 0))
				up.disabled = known.find(id) == 0
				down.disabled = known.find(id) == known.size() - 1
				for control: Button in [up, down, toggle]:
					control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					controls.add_child(control)
	if not _budget_draft.is_empty():
		host._line(right, "拟定安排尚未登记。", 16, UI.CYAN)
		host._footer_button("SaveSupply", "登记安排", _review_plan, true).disabled = not result.get("ok", false)

func _pick_budget_anchor(id: String) -> void:
	_budget_anchor = id
	_render_subject(_page_position(_subject))

func _edit_supply(id: String, step: int) -> void:
	var plan: Dictionary = host._views._plan(self) if _budget_draft.is_empty() else _budget_draft.duplicate(true)
	if step == 0:
		if id in plan.refuse_anchors: plan.refuse_anchors.erase(id)
		else: plan.refuse_anchors.append(id)
	else:
		var ordered: Array = plan.anchor_priority
		var old: int = ordered.find(id)
		var next := old + step
		while next >= 0 and next < ordered.size() and host._views._find(self, "anchors", ordered[next]).is_empty(): next += step
		if next < 0 or next >= ordered.size(): return
		ordered[old] = ordered[next]
		ordered[next] = id
	_budget_draft = plan
	_render_subject(_page_position(_subject))

func _review_plan() -> void:
	_subject = _page_position(_subject)
	host._open_surface("task_plan_confirm", "轮末安排", "登记供奉安排")
	host._line(host._body, "登记后按这份顺序与停供选择预览轮末支付。现在不会扣除信仰。")
	host._footer_button("CancelSupply", "取消", back).grab_focus()
	host._footer_button("ConfirmSupply", "登记", _commit_plan, true)

func _commit_plan() -> void:
	if host._dialog != "task_plan_confirm" or host._busy or _budget_draft.is_empty(): return
	host._busy = true
	var result: Dictionary = session.set_plan(_budget_draft)
	host._busy = false
	host._set_notice(result)
	if result.get("ok", false):
		_budget_draft = {}
		host._refresh()
	_render_subject(_subject)
	if not result.get("ok", false): host._line(host._body, str(result.get("error", "")), 16, UI.RISK)

func _render_history(page: Dictionary) -> void:
	var filter: String = page.id
	var bounds := Layout.box(Rect2(82, 354, 981, 342))
	host._body_scroll.position = bounds.position
	host._body_scroll.size = bounds.size
	var tools := HBoxContainer.new()
	host._ui.rect(tools, Layout.box(Rect2(82, 294, 981, 45)))
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_theme_constant_override("separation", 10)
	host._surface.add_child(tools)
	if not filter.is_empty(): host._line(tools, title(filter), 16, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
	var search: LineEdit = host._ui.search_field(tools, "HistoryFilter", "名称或轮次 · 回车查找", Rect2())
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 37
	search.text = str(page.get("query", ""))
	search.text_submitted.connect(func(value: String) -> void:
		_history_page(page.merged({"query":value.strip_edges()}, true), 0, "HistoryFilter"))
	var offset: int = int(page.get("offset", 0))
	var facts: Dictionary = host._views._history_slice(self, filter, offset, 12, str(page.get("query", "")))
	for fact: Dictionary in facts.facts:
		var text: Dictionary = preload("res://src/presentation/player_record_text.gd").summarize(self, fact)
		var caption := "第%s轮 · %s\n%s" % [fact.turn, text.title, text.summary]
		var entry := button(caption, _select_record.bind(fact.id))
		entry.name = "Record_" + str(fact.id)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		host._ui.select_entry(entry, fact.id == page.get("record", ""))
		host._body.add_child(entry)
	if facts.facts.is_empty(): host._line(host._body, "没有匹配的已知记录。", 16, UI.MUTED)
	if offset > 0: host._button(tools, "HistoryNewer", "较新", Rect2(), _history_page.bind(page, offset - 12, "HistoryNewer"))
	if facts.has_older: host._button(tools, "HistoryOlder", "更早", Rect2(), _history_page.bind(page, offset + 12, "HistoryOlder"))
	host._scroll_cue(host._body_scroll, host._surface, Layout.box(Rect2(863, 712, 200, 20)))
	var record: String = page.get("record", "")
	if not record.is_empty():
		var right: VBoxContainer = host._peek_content("编年史 / 已知记录", title(record))
		host._views.render(self, right, "fact", record)

func _select_record(id: String, related := false) -> void:
	var page := _page_position(_subject)
	if related and page.has("record") and not page.has("original_record"):
		page.original_record = page.record
		page.original_focus = page.get("focus", "")
	elif not related:
		page.erase("original_record")
		page.erase("original_focus")
	page.record = id
	_render_subject(page)

func _return_record() -> void:
	var page := _page_position(_subject)
	page.record = page.original_record
	page.focus = page.get("original_focus", "")
	page.erase("original_record")
	page.erase("original_focus")
	_render_subject(page)

func _history_page(page: Dictionary, offset: int, focus: String) -> void:
	var next := page.merged({"offset":offset, "scroll":0, "focus":focus}, true)
	for key: String in ["record", "original_record", "original_focus"]: next.erase(key)
	_render_subject(next)
	if host._surface.find_child(focus, true, false) == null: host._focus_surface_control("HistoryFilter")

func request_rest() -> void:
	var prepared: Dictionary = session.rest()
	if not prepared.get("confirmation", false):
		host._line(host._body, str(prepared.get("error", "当前无法敛息。")), 16, UI.RISK)
		return
	var preview: Dictionary = prepared.preview
	_subject = _page_position(_subject)
	host._open_surface("task_rest_confirm", "结束本轮", "敛息")
	host._line(host._body, "花费 %s 信仰，恢复 %s 创伤。
敛息将结束本轮行动，并开始下一轮。" % [preview.get("faith_cost", 0), preview.get("wounds_recovered", 0)])
	host._footer_button("CancelRest", "取消", back).grab_focus()
	host._footer_button("ConfirmRest", "确认敛息", _commit_rest, true)

func _commit_rest() -> void:
	if host._dialog != "task_rest_confirm" or host._busy: return
	host._close_surface()
	host._advance(true, true)

func set_strategy(cult_id: String, strategy: String) -> void:
	var plan: Dictionary = host._views._plan(self)
	plan.strategies[cult_id] = strategy
	save_plan(plan)

func save_plan(plan: Dictionary) -> void:
	var result: Dictionary = session.set_plan(plan)
	host._set_notice(result)
	var page := _page_position(_subject)
	host._refresh()
	_render_subject(page)
	if not result.get("ok", false): host._line(host._body, str(result.get("error", "")), 16, UI.RISK)

const AnchorPreparation = preload("res://src/presentation/anchor_preparation.gd")

func open_anchor_goal(institution: String, initial: Dictionary = {}, on_return := Callable()) -> void:
	var office: Dictionary = host._views._find(self, "institutions", institution)
	if office.is_empty(): return
	_anchor_return = on_return if on_return.is_valid() else host._close_surface
	_anchor_initial = initial.duplicate()
	if host._dialog in ["task_subject", "task_related"]:
		var page := _page_position(_subject)
		if page.kind == "anchors":
			page.focus = "AnchorGoal_" + institution.replace("/", "_")
			_anchor_initial.merge(page.get("anchor_initial", {}))
		_anchor_return = _restore_anchor_origin.bind(page, _reading_origin.duplicate(), _subject_return, _return_to, draft)
	_reading_origin.clear()
	draft = {}
	_render_anchor_goal(institution)

func _restore_anchor_origin(page: Dictionary, reading: Dictionary, subject_return: Callable, action_return: Callable, action_draft: Dictionary) -> void:
	_reading_origin = reading.duplicate()
	_subject_return = subject_return
	_return_to = action_return
	draft = action_draft
	_render_subject(page)

func _render_anchor_goal(institution: String, focus := "ReturnAnchorGoal") -> void:
	var office: Dictionary = host._views._find(self, "institutions", institution)
	if office.is_empty():
		if _anchor_return.is_valid(): _anchor_return.call()
		return
	_cancel_candidates()
	var known: Array = projection.anchors.filter(func(anchor: Dictionary) -> bool: return anchor.institution == institution)
	var anchor: Dictionary = known[0] if not known.is_empty() else {}
	var state: String = "尚未建立锚点" if anchor.is_empty() else "锚点" + host._views._anchor_state(anchor)
	host._open_surface("anchor_goal", state, preload("res://src/presentation/player_record_text.gd").entity_name(self, institution))
	var plan: Dictionary = AnchorPreparation.plan(session, institution)
	var conditions: Array = host._actions.Requirements.anchor(session, projection, {"institution":institution})
	var items := {}
	for section: Dictionary in conditions:
		for item: Dictionary in section.items:
			items[item.id] = item
			if plan.is_empty(): continue
			if item.id == "basis_records" and plan.after > plan.before: item["projected"] = "%s / %s" % [plan.after, item.required]
			if item.id == "anchor_material" and plan.complete: item["projected"] = "齐备"
	var materials: Dictionary = items.anchor_material
	var ready: bool = materials.state == "met"
	var material_status: String = str(materials.value)
	if items.has("basis_records"):
		material_status += "\n独立见证 %s / %s" % [items.basis_records.current, items.basis_records.required]
	var organization: String = "尚未建立"
	if items.has("followers"):
		organization = "信众 %s / %s\n凝聚 %s / %s" % [items.followers.current, items.followers.required, items.cohesion.current, items.cohesion.required]
	var summary := [
		["Materials", "锚定材料", material_status],
		["Guardian", "护持者", "%s 位可用" % items.guardian.current],
		["Relic", "绑定圣物", "%s 件可用" % items.medium.current],
		["Cult", "当地教团", organization],
	]
	host._reference(host._surface, "AnchorPurpose", "护持者与圣物维系锚点。实际供奉后，锚点才贡献苏醒。", Rect2(384, 478, 580, 32), 15, UI.MUTED)
	var pollution: PackedStringArray = str(items.anchor_pollution.value).split(" / ", false, 1)
	var pollution_text: String = "已知污染 %s · 锚定需 %s" % [pollution[0], pollution[1]] if pollution.size() == 2 else pollution[0]
	host._reference(host._surface, "AnchorPollution", pollution_text, Rect2(980, 478, 398, 32), 15, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index: int in summary.size():
		var part: Array = summary[index]
		var x: float = 384 + index * 251
		host._ui.fill(host._surface, "AnchorRule_" + part[0], Layout.box(Rect2(x, 526, 224, 1)), UI.LINE)
		host._reference(host._surface, "AnchorLabel_" + part[0], part[1], Rect2(x, 535, 224, 30), 16, UI.CYAN, false, 1)
		var value: Label = host._text(host._surface, part[2], Layout.box(Rect2(x, 570, 224, 53)), 16)
		value.name = "AnchorStatus_" + part[0]
		value.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if not anchor.is_empty():
		host._reference(host._surface, "AnchorUpkeep", _anchor_upkeep(anchor), Rect2(384, 626, 785, 28), 15, UI.MUTED)
		host._stage_button(host._surface, "InspectCurrentAnchor", "查阅这处锚点 ↗", Rect2(1162, 622, 216, 33),
			open_subject.bind("anchor", anchor.id, _resume_anchor_goal(institution, "InspectCurrentAnchor"), {"anchor_overview":true}), 16)
	var guide := "进入仪式后，选择护持者和圣物，再核对本轮能否施展。"
	var phase_ready: bool = projection.phase == "actions"
	var power: Dictionary = session.catalog.display_tables.powers.POWER_ANCHOR
	var awake: bool = int(projection.awakening) >= int(power.unlock_awakening)
	if not phase_ready:
		guide = "进入神意行动后，才能准备这次锚定。"
	elif not awake:
		guide = "施展锚定需 %s 苏醒。你目前有 %s。" % [power.unlock_awakening, projection.awakening]
	elif not plan.is_empty():
		guide = "可把现有记录交到此处，%s。" % ("见证预计由 %s 增至 %s" % [plan.before, plan.after] if plan.before >= 0 else "补齐这里缺少的材料")
	elif not ready:
		guide = "这里尚缺能维系锚点的材料。可回当地「持续活动」，积累这里需要的见证或实践。"
	elif items.guardian.current == 0:
		guide = "还没有可护持的信徒。" if anchor.is_empty() else "原护持者目前不能履职。若要换人，先任命继任者。"
	elif items.medium.current == 0:
		guide = "还没有可绑定的圣物。回当地「当地圣物」查看可用物件与回收机会。"
	var next_width := 994 if plan.is_empty() or not phase_ready else 760
	host._text(host._surface, guide, Layout.box(Rect2(384, 657, next_width, 50)), 16, UI.BONE)
	if not plan.is_empty() and phase_ready:
		var price := "%s 低语" % plan.cost.get("whispers", 0)
		if int(plan.cost.get("faith", 0)) > 0: price += " / %s 信仰" % plan.cost.faith
		var gather: Button = host._stage_button(host._surface, "GatherAnchorMaterial", "汇集记录 · " + price,
			Rect2(1150, 657, 228, 40), _gather_anchor_material.bind(institution, plan.selection), 17)
		host._ui.scene_submit(gather)
	var back_button: Button = host._footer_button("ReturnAnchorGoal", "返回上一级", back)
	host._footer_button("AnchorConditions", "锚定条件 ↗", _anchor_details.bind(institution, conditions, "AnchorConditions"))
	host._footer_button("AnchorRisks", "费用与风险 ↗", _anchor_details.bind(institution, [], "AnchorRisks"))
	var configure: Button = host._footer_button("ConfigureAnchor", "准备施展锚定 →", _prepare_anchor.bind(office), true)
	configure.custom_minimum_size.x = 176
	configure.disabled = not (phase_ready and awake and ready)
	configure.tooltip_text = guide if configure.disabled else "选择本处的护持者与绑定圣物。"
	host._ui.scene_submit(configure)
	var target: Control = host._surface.find_child(focus, true, false)
	if target == null or (target is Button and target.disabled): target = back_button
	target.grab_focus()

func _anchor_upkeep(anchor: Dictionary) -> String:
	for forecast: Dictionary in session.economy_preview().get("preview", {}).get("anchors", []):
		if forecast.anchor != anchor.id: continue
		var reason: String = str(forecast.get("reason", ""))
		return "本轮供奉 · " + ("%s 信仰，待轮末支付" % forecast.fee if reason.is_empty() else host._views._economy_reason(self, reason))
	return "本轮供奉 · 暂无预计支付"

func _anchor_details(institution: String, conditions: Array, focus: String) -> void:
	var risks := focus == "AnchorRisks"
	_anchor_detail_return = _resume_anchor_goal(institution, focus)
	host._begin_peek("anchor_materials")
	var body: VBoxContainer = host._peek_content("锚定", "费用与风险" if risks else "锚定条件")
	if risks:
		var definition: Dictionary = session.catalog.display_tables.powers.POWER_ANCHOR
		for field: Array in [["基础支出", "%s 低语 · %s 信仰" % [definition.whispers, definition.faith]], ["必付", definition.always_cost], ["失败", definition.failure], ["灾变", definition.disaster]]:
			host._line(body, field[0], 13, UI.CYAN)
			host._line(body, field[1], 14)
	else:
		host._line(body, "向下查看材料、护持和教团的具体条件。", 14, UI.MUTED)
		host._actions.RequirementList.render(body, conditions, host._size(16) > 16, host._ui)
	host._stage_button(host._surface, "ReturnAnchorMaterials", "回到机构 ↩", Rect2(1130, 661, 393, 38), back).grab_focus()

func _resume_anchor_goal(institution: String, focus := "ReturnAnchorGoal") -> Callable:
	return _restore_anchor_goal.bind(institution, focus, _anchor_return, _anchor_initial.duplicate())

func _restore_anchor_goal(institution: String, focus: String, previous: Callable, initial: Dictionary) -> void:
	_anchor_return = previous
	_anchor_initial = initial.duplicate()
	_render_anchor_goal(institution, focus)

func _prepare_anchor(office: Dictionary) -> void:
	var selection: Dictionary = {"domain":office.domain, "institution":office.id}
	var materials: Array = session.anchor_source_options(office.id)
	if materials.is_empty():
		_render_anchor_goal(office.id)
		return
	selection["source"] = materials[0].id
	if materials.size() == 1: selection["qualification"] = materials[0].id
	if _anchor_initial.get("domain", office.domain) == office.domain:
		for key: String in ["npc", "relic"]:
			if not str(_anchor_initial.get(key, "")).is_empty(): selection[key] = _anchor_initial[key]
	open_action("POWER_ANCHOR", selection, _resume_anchor_goal(office.id, "ConfigureAnchor"), true)

func _gather_anchor_material(institution: String, expected: Dictionary) -> void:
	if host._busy or host._dialog != "anchor_goal": return
	var current: Dictionary = AnchorPreparation.plan(session, institution)
	if current.get("selection", {}) != expected:
		_render_anchor_goal(institution)
		return
	_return_to = _resume_anchor_goal(institution)
	draft = {"key":"cults/transfer_material", "selection":expected.duplicate(true), "anchor_goal":institution}
	host._dialog = "task_action"
	run_action("cults/transfer_material", expected)
