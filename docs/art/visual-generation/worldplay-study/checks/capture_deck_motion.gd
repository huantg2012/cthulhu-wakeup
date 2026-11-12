extends SceneTree
## Export actual viewport frames at a fixed timestep, not interpolated stills.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.add_child(load("res://docs/art/visual-generation/worldplay-study/worldplay.tscn").instantiate())
	var view: Control = root.get_node("GameRoot/Presentation/CanvasLayer/OverlayRoot")
	root.size = Vector2i(1280,720)
	await process_frame
	while view._portraits._running or not view._portraits._jobs.is_empty(): await process_frame
	var output := "/tmp/worldplay-deck-motion"
	DirAccess.make_dir_recursive_absolute(output)
	view._fan.set_focus(0,false)
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(700,400)
	Input.parse_input_event(mouse)
	for frame: int in 360:
		# Read the two ends, thumb through the deck, then select a distant edge.
		if frame>=30 and frame<270 and (frame-30)%6==0:
			view._fan.set_focus(1+(frame-30)/6)
		if frame==300: view._fan.set_focus(20)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image().get_region(Rect2i(300,405,944,310))
		image.save_png(output+"/frame-%04d.png" % frame)
	print("DECK_MOTION ",output," 360 viewport frames / 30 fps")
	quit()
