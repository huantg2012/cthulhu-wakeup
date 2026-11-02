extends SceneTree
## Bounded regression of the producer's concrete interaction failures.
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var checks: Array[String] = []
var app

func _initialize() -> void:
	_run.call_deferred()

func need(condition: bool, name_value: String) -> bool:
	if not condition:
		push_error("EXPERIENCE_SMOKE: " + name_value)
		quit(1)
		return false
	checks.append(name_value)
	return true

func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: result.append(child)
		result.append_array(buttons(child))
	return result

func _run() -> void:
	app = Experience.instantiate()
	app.session = Session.new("res://.godot/ui-experience-smoke")
	root.add_child(app)
	await process_frame
	app.start_new(1)
	if not need(app.projection.get("active", false), "真实新局可启动"): return
	if app.projection.phase == "events":
		app.close_modal()
		app._advance(false)
	if not need(app.projection.phase == "actions", "轮初进入真实行动阶段"): return
	var prayers: Array = app.projection.prayers
	if not need(not prayers.is_empty(), "初始祈求与实际对象已投影"): return
	app.show_subject("prayer", str(prayers[0].id))
	await process_frame
	await process_frame
	var key: String = app.draft.key
	var choice: Dictionary = app.draft.selection.duplicate(true)
	var execute: Button = app._work_footer.find_child("ExecuteDraft", true, false)
	if not need(execute != null and not execute.disabled and app._work_box.find_child("PrayerChoice_deep", true, false) != null, "打开祈求即有两种回应选择与实际提交按钮"): return
	var costs: Array = app._work_box.get_children().filter(func(node: Node) -> bool: return node is Label and node.text.begins_with("必付代价"))
	if not need(costs.size() == 1 and "理智" in costs[0].text and not "忠诚" in costs[0].text, "献身祈求将必付理智损耗与成功忠诚收益分开"): return
	if not need(execute.get_global_rect().end.y <= 900 and execute.get_global_rect().position.y >= 0 and not app._work_scroll.is_ancestor_of(execute), "祈求提交在画布内且不随长内容滚走"): return
	var details: Button = app._work_box.find_child("OutcomeDetailsToggle", true, false)
	details.grab_focus()
	details.pressed.emit()
	await process_frame
	await process_frame
	execute = app._work_footer.find_child("ExecuteDraft", true, false)
	if not need(execute.get_global_rect().end.y <= 900 and root.gui_get_focus_owner().name == "OutcomeDetailsToggle", "展开详细后果仍看见提交且焦点回到原控件"): return
	app.show_subject("worlds")
	if not need(app.draft.key == key and app.draft.selection == choice, "普通查看保留行动对象与选源"): return
	if not need(app._work_box.get_child(0).text == prayers[0].title and "求告者" in app._work_box.get_child(1).text, "关联查看后当前祈求仍显示请求身份"): return
	var power_keys: Array = app.session.catalog.tables.powers.keys()
	for power: String in power_keys.slice(0, 5): app.open_action(power)
	app.back_action()
	if not need(app.draft.is_empty() and not app._work_panel.visible, "浏览五权能只关闭一次且空行动区收起"): return
	await process_frame
	await process_frame
	if not need(app._subject_scroll.size.x > 950, "无行动时主体使用中央完整宽度"): return
	for kind: String in ["worlds", "people", "budget", "history", "self"]: app.show_subject(kind)
	app.back_subject()
	if not need(app.subject.kind == "home", "连续查看子页一次回到总览"): return
	var world_links: Array = buttons(app._frame).filter(func(b: Button) -> bool: return b.text.begins_with("世界 ") or b.text in ["完整世界索引", "全部已知世界"])
	if not need(world_links.size() == 1, "全局世界索引入口唯一"): return
	app.open_action("POWER_MANIFEST")
	if not need(app._work_box.get_child_count() >= 2 and "尚未解锁" in app._work_box.get_child(1).text and app._work_footer.get_child_count() == 0, "未解锁权能先说明原因且没有无效提交表单"): return
	if not need(app._powers.get_child_count() == 12, "十二权能均可浏览"): return
	app.open_action("POWER_DREAM")
	var picker: OptionButton = app._work_box.find_child("Field_domain", true, false)
	if picker != null:
		picker.grab_focus()
		picker.item_selected.emit(picker.selected)
		await process_frame
		await process_frame
		if not need(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "Field_domain", "选源重绘后保留键盘焦点"): return
	app.show_subject("worlds")
	var sources: Array = app.session.known_sources()
	if not sources.is_empty():
		var original_subject: Dictionary = app.subject.duplicate(true)
		app.show_subject("fact", str(sources[0]))
		app.show_subject("fact", str(sources[-1]))
		app.close_modal()
		if not need(app.subject == original_subject, "连续事实详情复用临时窗且不改变主区层级"): return
	app.show_subject("prayer", str(prayers[0].id))
	var before: String = JSON.stringify(app.session.world.state)
	app.ask("确认回应", func() -> void: app.run_action(key, choice, true))
	app.close_modal()
	if not need(JSON.stringify(app.session.world.state) == before and app.draft.selection == choice, "取消确认不扣费不执行且保留草稿"): return
	execute = app._work_footer.find_child("ExecuteDraft", true, false)
	execute.pressed.emit()
	if app._modal_kind == "confirm":
		for control: Button in buttons(app._modal_box):
			if control.text == "确认": control.pressed.emit(); break
	if not need(app._responded() and "本轮已回应" in app._attention.get_child(0).text, "回应后机会消耗并更新摘要"): return
	if not need(app.draft.is_empty() and not app._work_panel.visible and not app.receipt.is_empty(), "实际执行后无旧行动弹回且结果保留"): return
	var response_summary: Label = app._subject_box.find_child("ActionReceipt", true, false)
	if not need(response_summary != null and app.subject.kind != "home" and app.receipt.get("presentation_lines", []).size() > 0, "实际回应结果在当前主体可见而不要求返回总览"): return
	var receipt_copy: Dictionary = app.receipt.duplicate(true)
	app.show_subject("worlds")
	if not need(app.receipt == receipt_copy and app._subject_box.find_child("ActionReceipt", true, false) != null, "普通查看保留可收起的实际结果"): return
	app._advance(true)
	if not need(app.projection.turn == 2 and app.projection.phase in ["events", "actions", "ended"], "结束回合自动衔接次轮而不暴露轮间"): return
	var saved: Dictionary = app.session.save_game()
	var restored = Session.new("res://.godot/ui-experience-smoke-restore")
	if not need(saved.get("ok", false) and restored.continue_game(saved.path).get("ok", false), "正式Session保存恢复"): return
	app.load_save("res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json")
	if not need(app.projection.cults.size() == 1 and app.projection.turn == 4, "真实首团副本恢复并自动从结算边界进入第四轮"): return
	var valid_prayers: Array = app.session.action_catalog().filter(func(row: Dictionary) -> bool: return str(row.key).begins_with("prayer/") and row.get("available", false))
	if not need(app.projection.prayers.size() >= 1 and app.projection.prayers.size() <= 3 and not valid_prayers.is_empty(), "第四轮正式祈求已投影且存在合法回应"): return
	app.close_modal()
	var plan_before: String = JSON.stringify(app.session.world.state)
	app.show_subject("cult", str(app.projection.cults[0].id))
	if not need(app._subject_box.find_child("CultStrategy_expand", true, false) != null and app._subject_box.find_child("CultStrategy_conceal", true, false) != null and app._subject_box.find_child("CultStrategy_hold", true, false) != null and JSON.stringify(app.session.world.state) == plan_before, "真实首团三策略可预先比较且纯查看不改状态"): return
	app.pin_subject()
	app.show_subject("person", str(app.projection.people[0].id))
	app.pin_subject()
	app.open_action("POWER_DREAM")
	var comparison_draft: Dictionary = app.draft.duplicate(true)
	var comparison_subject: Dictionary = app.subject.duplicate(true)
	app.show_comparison()
	if not need(app._modal_kind == "comparison" and app._modal_box.find_child("ComparisonSlot_0", true, false) != null and app._modal_box.find_child("ComparisonSlot_1", true, false) != null, "留存两对象进入同一临时窗实际并置"): return
	app.close_modal()
	if not need(app.draft == comparison_draft and app.subject == comparison_subject, "关闭对照保持当前主体与行动草稿"): return
	app.back_action()
	# UI-only filter fixture; never inserted into world state or saved.
	var people: Array = app.projection.people.duplicate(true)
	app.projection.people = [{"id":"ui-a", "title":"本地人物", "domain":"ui-world-a"}, {"id":"ui-b", "title":"外地人物", "domain":"ui-world-b"}]
	app.show_subject("people", "ui-world-a")
	var rendered: Array = buttons(app._subject_box)
	if not need(rendered.any(func(b: Button) -> bool: return "本地人物" in b.text) and not rendered.any(func(b: Button) -> bool: return "外地人物" in b.text), "当地人物列表按世界过滤而非回退全局"): return
	app.projection.people = people
	app.show_subject("people")
	var search: LineEdit = app._subject_box.find_child("SubjectSearch_people_", true, false)
	search.grab_focus()
	search.text = "记录"; search.caret_column = 1
	search.text_submitted.emit(search.text)
	await process_frame
	await process_frame
	if not need(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "SubjectSearch_people_" and root.gui_get_focus_owner().caret_column == 1, "人物查找重绘后保留输入焦点与光标"): return
	var filter: OptionButton = app._subject_box.find_child("PersonFilter_people_", true, false)
	filter.grab_focus(); filter.item_selected.emit(1)
	await process_frame
	await process_frame
	if not need(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "PersonFilter_people_", "机会筛选重绘后保留键盘焦点"): return
	for kind: String in ["worlds", "people", "relics", "budget", "attention", "history", "self"]: app.show_subject(kind)
	var result: Dictionary = {"checks":checks, "first_cult_t4_prayers":app.projection.prayers.size(), "scope":"Bounded interaction regression and original first-cult T4 supply integration. No full-campaign, mature-route, balance or human acceptance claim."}
	var output := FileAccess.open("res://docs/game-state/ui-experience-native-checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  ")); output.close()
	print(JSON.stringify(result))
	app.queue_free()
	await process_frame
	quit(0)
