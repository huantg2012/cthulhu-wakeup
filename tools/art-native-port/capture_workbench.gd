extends SceneTree
func _init():run.call_deferred()
func run():
	var scene=load("res://src/art_generation/workbench/workbench.tscn").instantiate()
	root.add_child(scene)
	await scene.generation_finished
	for frame in 3:await _draw_frame()
	var folder="res://docs/art/visual-generation/procedural-study/native-evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder.path_join("workbench.png"))
	# Exercise the displayed material selector without rerunning generation.
	scene.pass_choice.select(2);scene.pass_choice.item_selected.emit(2)
	for frame in 2:await _draw_frame()
	root.get_texture().get_image().save_png(folder.path_join("workbench-material.png"))
	print("WORKBENCH_CAPTURE_COMPLETE")
	quit()

func _draw_frame():
	await process_frame
	RenderingServer.force_draw(false)
