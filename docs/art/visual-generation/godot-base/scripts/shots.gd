extends RefCounted
## Dev-only: `godot --path project -- --shots=/tmp/shots [--set=k:v,...]` renders a batch of
## configurations and writes PNGs, then quits.

static func run(main: Node, out_dir: String, configs: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var defaults: Dictionary = main.params.duplicate()
	for i in configs.size():
		var c: Dictionary = configs[i]
		main.params = defaults.duplicate()
		for k in c:
			main.params[k] = c[k]
		main._sync_controls()
		main.rebuild(false)
		for f in 4:
			await RenderingServer.frame_post_draw
		var img: Image = main.vp_final.get_texture().get_image()
		var name := "%s/%02d_s%d_st%d_%d.png" % [out_dir, i, int(main.params["scene"]), int(main.params["style"]), int(main.params["seed"])]
		img.save_png(name)
		print("SHOT ", name, " ", main.info.get("title", ""))
	if OS.get_cmdline_user_args().has("--features"):
		main._add_gallery()
		for f in 6:
			await RenderingServer.frame_post_draw
		main._export_png()
		for f in 6:
			await RenderingServer.frame_post_draw
		main._style_sheet()
		for f in 60:
			await RenderingServer.frame_post_draw
		print("GALLERY ", main.gallery.size(), " HIST ", main.history.size())
	await RenderingServer.frame_post_draw
	var win: Image = main.get_viewport().get_texture().get_image()
	win.save_png(out_dir + "/ui.png")
	main.get_tree().quit()
