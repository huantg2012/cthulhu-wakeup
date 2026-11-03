extends SceneTree
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
var app
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	app=Scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://tools/echoes-art-master/evidence/polish-01-native.png")
	print("ART_MASTER_CAPTURE ",result," controls=",app.get_child_count())
	app.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
