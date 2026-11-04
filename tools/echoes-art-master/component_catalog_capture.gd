extends SceneTree
## Regenerate the visual specification exhibits from shared live controls.
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Catalogue capture requires a graphics renderer.")
		quit(1)
		return
	run.call_deferred()

func run() -> void:
	var catalogue: Control = preload("res://tools/echoes-art-master/component_catalog.tscn").instantiate()
	root.add_child(catalogue)
	for page: int in [0,1]:
		catalogue.show_page(page)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/art/echoes-ui/visual-exhibits/controls-%d.png" % page
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("Cannot write " + path)
			quit(1)
			return
	print("COMPONENT_CATALOG_CAPTURE_OK 2 live pages")
	quit()
