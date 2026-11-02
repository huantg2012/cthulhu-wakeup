extends SceneTree
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app
var captures: Array = []
func _initialize() -> void:
	_capture.call_deferred()
func snap(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(path)
	captures.append({"path":path,"error":error,"frame":str(app._frame.get_global_rect())})
func _capture() -> void:
	app = Experience.instantiate()
	app.session = Session.new("res://.godot/ui-experience-render")
	root.add_child(app)
	await process_frame
	app.start_new(1)
	if app.projection.phase == "events": app.close_modal(); app._advance(false)
	if app.projection.prayers.is_empty(): quit(1); return
	var prayer_id: String = str(app.projection.prayers[0].id)
	app.show_subject("prayer", prayer_id)
	await snap("res://docs/game-state/ui-experience-native.png")
	var deep: Button = app._work_box.find_child("PrayerChoice_deep",true,false)
	deep.pressed.emit()
	await snap("res://docs/game-state/ui-experience-preview.png")
	app.open_action("prayer/" + prayer_id + "/shallow")
	app.run_action(str(app.draft.key), app.draft.selection, true)
	await snap("res://docs/game-state/ui-experience-result.png")
	app.open_action("POWER_MANIFEST")
	await snap("res://docs/game-state/ui-experience-unavailable.png")
	app.load_save("res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json")
	app.close_modal()
	if app.projection.cults.is_empty(): quit(1); return
	app.show_subject("cult", str(app.projection.cults[0].id))
	await snap("res://docs/game-state/ui-experience-subject.png")
	app.pin_subject()
	app.show_subject("person", str(app.projection.people[0].id))
	app.pin_subject()
	app.show_comparison()
	await snap("res://docs/game-state/ui-experience-comparison.png")
	print("INTERACTION_CAPTURES: " + JSON.stringify(captures))
	app.queue_free()
	await process_frame
	quit(0)
