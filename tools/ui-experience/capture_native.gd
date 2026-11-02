extends SceneTree
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
func _initialize() -> void:
	_capture.call_deferred()
func _capture() -> void:
	var app = Experience.instantiate()
	app.session = Session.new("user://ui-experience-render")
	root.add_child(app)
	await process_frame
	app.load_save("res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json")
	if not app.projection.get("active",false) or app.projection.cults.is_empty(): quit(1); return
	app._advance(false)
	app.close_modal()
	var cult: Dictionary = app.projection.cults[0]
	app.show_subject("cult", str(cult.id))
	app.open_action("POWER_DREAM", {"domain":cult.domain,"npc":cult.leader})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var result: Error = picture.save_png("res://docs/game-state/ui-experience-native.png")
	print("NATIVE_CAPTURE: " + str(result))
	app.draft.review = true
	app.render_workbench()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/game-state/ui-experience-preview.png")
	print("FRAME_BOUNDS: " + str(app._frame.get_global_rect()))
	app.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
