extends SceneTree
## One real listen path, then real legacy-save offerings to check named provenance.
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const LEGACY := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
var app
var checks: Array[String] = []
var examples: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func need(value: bool, description: String) -> bool:
	if not value:
		push_error("OBSERVATION_UI: " + description); quit(1); return false
	checks.append(description); return true

func text_of(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += text_of(child)
	return result

func actions() -> bool:
	for step: int in range(8):
		if app.session.turn.context.phase == "actions":
			app.refresh(); app.close_modal(); return true
		if not app.session.progress().get("ok", false): return false
	return false

func choice(named: bool = false) -> Dictionary:
	for world: Dictionary in app.session.project().domains:
		for row: Dictionary in app.session.action_catalog({"domain":world.id}):
			if row.key != "POWER_LISTEN": continue
			for field: Dictionary in row.fields:
				if field.key != "source": continue
				for option: Dictionary in field.options:
					if not str(option.label).begins_with("聆听世界态势 · "): continue
					var proof: Dictionary = Store.entry(app.session.world.state.facts, option.id)
					var message: Dictionary = Store.entry(app.session.world.state.facts, proof.changes.origin)
					if named and (str(message.changes.get("observer", "")).is_empty() or str(message.changes.get("cult", "")).is_empty()): continue
					return {"selection":{"domain":world.id, "source":option.id}, "message":message, "label":option.label, "options":field.options.size()}
	return {}

func capture(name_value: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/observation-ui-" + name_value + ".png")

func _run() -> void:
	app = Experience.instantiate()
	app.session = Session.new("res://.godot/observation-ui-campaigns")
	root.add_child(app)
	await process_frame
	app.start_new(1)
	if not need(actions(), "真实新局进入行动阶段"): return
	var source: Dictionary = choice()
	if not need(not source.is_empty(), "现有聆听 selector 可识别公开世界态势来源"): return
	var selected: Dictionary = source.selection
	var message: Dictionary = source.message
	var target: String = str(message.changes.fact)
	examples.initial_selector = source.label
	if not need(not app.session.is_known_source(target) and "第%d轮" % int(message.turn) in str(source.label) and not "未揭示的具体事实" in str(source.label), "聆听前标签只使用公开世界和观测回合而不暴露私有快照"): return
	app.show_subject("world", str(selected.domain))
	app.open_action("POWER_LISTEN", selected)
	if not need(source.options == 1 and app._work_box.find_child("Field_source", true, false) == null and "世界态势来源：" in text_of(app._work_box) and "第%d轮" % int(message.turn) in text_of(app._work_box), "唯一来源无需重复选择但仍常显世界和观测回合"): return
	await capture("listen")
	var before: String = app.session.turn.snapshot()
	var original_subject: Dictionary = app.subject.duplicate(true)
	var original_draft: Dictionary = app.draft.duplicate(true)
	app.show_subject("fact", str(message.id))
	var text_value: String = text_of(app._modal_box)
	examples.public_detail = text_value
	if not need("估计区间" in text_value and "屏障" in text_value and "稳定" in text_value and not "observation_version" in text_value and not "intelligence" in text_value and not "metrics" in text_value, "公开来源临时窗只呈四项区间及可读说明"): return
	app.close_modal()
	if not need(app.subject == original_subject and app.draft == original_draft and app.session.turn.snapshot() == before, "查看来源不改变主区层级草稿或模拟"): return
	var execute: Button = app._work_footer.find_child("ExecuteDraft", true, false)
	if not need(execute != null and not execute.disabled, "既有聆听动作可直接提交此来源"): return
	execute.pressed.emit()
	if not need(app.session.is_known_source(target), "真实执行聆听后获得相应快照"): return
	app.show_subject("fact", target)
	text_value = text_of(app._modal_box)
	examples.exact_detail = text_value
	if not need("世界态势记录" in text_value and "第%d轮确知" % int(message.turn) in text_value and not "sources_version" in text_value and not "first_contact" in text_value and not "metrics" in text_value, "已听来源窗呈历史确值而非原始内部字典"): return
	await capture("exact-source")
	app.close_modal()

	app.load_save(LEGACY)
	if not need(actions(), "真实第三轮旧档可续玩"): return
	var named: Dictionary = {}
	for round_index: int in range(3):
		if not app.session.progress(true).get("ok", false) or not actions(): break
		named = choice(true)
		if not named.is_empty(): break
	if not need(not named.is_empty(), "真实教团供奉产生具名来源"): return
	examples.offering_selector = named.label
	var observer: String = str(named.message.changes.observer)
	if not need(app.session.object_title(observer) in str(named.label) and "的教团" in str(named.label) and "第%d轮" % int(named.message.turn) in str(named.label), "来源选项同时辨识世界教团具名联系人和观测回合"): return
	app.show_subject("world", str(named.selection.domain))
	app.open_action("POWER_LISTEN", named.selection)
	if not need(app.session.object_title(observer) in text_of(app._work_box) and "的教团" in text_of(app._work_box), "实际工作台显示具名教团来源"): return
	await capture("offering")
	var report := FileAccess.open("res://.godot/observation-ui-checks.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok":true, "checks":checks, "examples":examples}, "\t")); report.close()
	print("OBSERVATION_UI_OK ", checks.size(), " checks")
	app.queue_free()
	await process_frame
	quit(0)
