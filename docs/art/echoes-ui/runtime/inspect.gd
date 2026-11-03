extends SceneTree
## Read-only UI inspection except one real prayer response in an isolated new session.
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
const OUT: String = "res://docs/art/echoes-ui/runtime/"
var app
var frames: Array = []
func _initialize() -> void:
	_run.call_deferred()
func visible_text(node: Node) -> Array:
	var result: Array = []
	if node is Control and not node.is_visible_in_tree(): return result
	if node is Label or node is Button: result.append({"name":str(node.name),"text":str(node.text),"rect":str(node.get_global_rect())})
	for child: Node in node.get_children(): result.append_array(visible_text(child))
	return result
func snap(label_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(OUT + label_value + ".png")
	frames.append({"name":label_value,"png_error":error,"turn":app.projection.get("turn",0),"phase":app.projection.get("phase",""),"subject":app.subject.duplicate(true),"draft_key":app.draft.get("key",""),"prayers":app.projection.get("prayers",[]).duplicate(true),"cults":app.projection.get("cults",[]).size(),"relics":app.projection.get("relics",[]).size(),"controls":visible_text(app)})
	print("INSPECT_CAPTURE " + label_value)
func _run() -> void:
	app = Experience.instantiate()
	app.session = Session.new("res://.godot/echoes-ui-inspection-20261103")
	root.add_child(app)
	await process_frame
	await snap("01-start-menu")
	app.start_new(1)
	await snap("02-new-game-default")
	if app.projection.phase == "events":
		app.close_modal()
		app._advance(false)
	if app.projection.prayers.is_empty(): push_error("INSPECT: no actual prayers"); quit(1); return
	var request_id: String = str(app.projection.prayers[0].id)
	app.show_subject("prayer", request_id)
	await snap("03-prayer-shallow")
	var deep: Button = app._work_box.find_child("PrayerChoice_deep", true, false)
	if deep != null: deep.pressed.emit()
	await snap("04-prayer-deep")
	app.show_subject("worlds")
	await snap("05-worlds-with-draft")
	app.open_action("prayer/" + request_id + "/shallow")
	app.run_action(str(app.draft.key), app.draft.selection, true)
	await snap("06-prayer-result")
	app.open_action("POWER_MANIFEST")
	await snap("07-unavailable-power")
	app.load_save("res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json")
	app.close_modal()
	if app.projection.cults.is_empty(): push_error("INSPECT: no cult after restore"); quit(1); return
	app.show_subject("cult", str(app.projection.cults[0].id))
	await snap("08-first-cult")
	app.show_subject("people")
	await snap("09-people")
	app.show_subject("budget")
	await snap("10-budget")
	var file := FileAccess.open(OUT + "inspection.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"godot":Engine.get_version_info(),"scope":"current native prototype, new seed 1 plus isolated first-cult restore; one prayer response; not full playthrough","captures":frames}, "\t"))
	file.close()
	app.queue_free()
	await process_frame
	quit(0)
