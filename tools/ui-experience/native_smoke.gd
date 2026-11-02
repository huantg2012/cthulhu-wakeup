extends SceneTree
## Short interaction smoke. No long simulation or natural-progression claim.
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

func _run() -> void:
	app = Experience.instantiate()
	app.session = Session.new("user://ui-experience-smoke")
	root.add_child(app)
	await process_frame
	app.start_new(1)
	if not need(app.projection.get("active", false), "真实新局可启动"): return
	if app.projection.phase == "events":
		# Only accept the existing default event transition in this controlled smoke.
		app.close_modal()
		app._advance(false)
	if not need(app.projection.phase == "actions", "轮初进入真实行动阶段"): return
	var prayers: Array = app.projection.prayers
	if not need(not prayers.is_empty(), "初始祈求与实际对象已投影"): return
	app.open_action(str(prayers[0].key) + "/shallow")
	var choice: Dictionary = app.draft.selection.duplicate(true)
	var key: String = app.draft.key
	var initial: Dictionary = app.draft.duplicate(true)
	app.show_subject("worlds")
	app.open_action("POWER_DREAM")
	app.back_action()
	if not need(app.draft.key == initial.key and app.draft.selection == initial.selection, "查看资料与另一行动返回后原草稿未改变"): return
	var prepared: Dictionary = app.session.preview_action(key, choice)
	if not need(prepared.get("ok", false), "真实祈求选源与预览可提交"): return
	app.draft.review = true
	app.render_workbench()
	var execute: Button = app._work_box.find_child("ExecuteDraft",true,false)
	if not need(execute != null and not execute.disabled, "准备进入预览后提供可用的实际执行按钮"): return
	execute.pressed.emit()
	if app._modal_kind == "confirm":
		for child: Node in app._modal_box.get_children():
			if child is Button and child.text == "确认": child.pressed.emit(); break
	if not need(app._responded(), "回应后机会已消耗并刷新常驻摘要"): return
	if not need(app._powers.get_child_count() == 12, "全部十二权能保持可查"): return
	app._advance(true)
	if not need(app.projection.phase in ["between", "ended"], "结束行动经过正式结算到轮间或终局"): return
	if app.projection.phase == "between":
		app._advance(false)
		if not need(app.projection.turn == 2, "下一回合由正式时钟推进"): return
	var saved: Dictionary = app.session.save_game()
	var restored = Session.new("user://ui-experience-smoke-restore")
	if not need(saved.get("ok", false) and restored.continue_game(saved.path).get("ok", false), "原型存档由正式Session保存并继续"): return
	var example: String = "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
	app.load_save(example)
	if not need(app.projection.cults.size() == 1 and app.projection.turn == 3, "真实首团保存兼容并复制到独立存档"): return
	var cult: Dictionary = app.projection.cults[0]
	app.show_subject("cult", cult.id)
	app.close_modal()
	# Read surfaces at the first-cult boundary without synthesizing possessions.
	for kind: String in ["worlds","people","members","relics","budget","attention","history","self"]:
		app.show_subject(kind, cult.id if kind == "members" else "")
	app.show_subject("cult", cult.id)
	checks.append("世界、全员、库存、供奉、关注、历史与本体资料可展开")
	var result: Dictionary = {"checks":checks,"scope":"One real new-game action cycle and one compatible first-cult save; not full-campaign, mature-route or balance validation."}
	var output := FileAccess.open("res://docs/game-state/ui-experience-native-checks.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"  "))
	output.close()
	print(JSON.stringify(result))
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		picture.save_png("res://docs/game-state/ui-experience-native.png")
	app.queue_free()
	await process_frame
	quit(0)
