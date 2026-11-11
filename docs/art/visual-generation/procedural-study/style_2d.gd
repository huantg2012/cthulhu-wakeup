extends "res://scripts/main.gd"
## Feed directly drawn 2D images into the original viewport -> bloom -> post pipeline.
## No new meshes or 3D rendering are used for these subjects.

func _maybe_shots() -> void:
	var job_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--style-job="):
			job_path = argument.substr(12)
	if job_path.is_empty():
		push_error("Missing --style-job")
		get_tree().quit(1)
		return
	var file := FileAccess.open(job_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open 2D style job")
		get_tree().quit(1)
		return
	var job: Dictionary = JSON.parse_string(file.get_as_text())
	params.merge(job["params"], true)
	time_acc = 3.0
	await get_tree().process_frame
	rebuild(false)
	var light: Dictionary = info["light"]
	var ld: Vector3 = light["dir"]
	var rc: Color = light["rim_col"]
	var lc: Color = light["col"]
	var am: Color = light["amb"]
	var details := {"dir":[ld.x,ld.y,ld.z],"rim_col":[rc.r,rc.g,rc.b],"col":[lc.r,lc.g,lc.b],"amb":[am.r,am.g,am.b]}
	var sky_count: int = 0
	for child in world_root.get_children():
		# Keep the original generated celestial background; remove the planet
		# and other world objects. No new 3D models are created for 2D subjects.
		var mat: Material = child.material_override if child is MeshInstance3D else null
		var is_original_sky: bool = mat is ShaderMaterial and mat.shader != null and mat.shader.resource_path == "res://shaders/sky.gdshader"
		if is_original_sky:
			sky_count += 1
		else:
			world_root.remove_child(child)
			child.queue_free()
	if sky_count != 1:
		push_error("Expected exactly one original sky, found %d" % sky_count)
		get_tree().quit(1)
		return
	details["original_sky_count"] = sky_count
	var outfile := FileAccess.open(str(job["lighting"]), FileAccess.WRITE)
	outfile.store_string(JSON.stringify(details))
	outfile.close()
	var layer := CanvasLayer.new()
	layer.layer = 100
	vp3d.add_child(layer)
	var image_rect := TextureRect.new()
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image_rect.position = Vector2.ZERO
	image_rect.size = Vector2(size_out)
	layer.add_child(image_rect)
	var material := ShaderMaterial.new()
	material.shader = load("res://surface_2d.gdshader")
	material.set_shader_parameter("archetype", int(params["archetype"]))
	material.set_shader_parameter("seed_offset", float(int(params["seed"]) % 997) * 0.037)
	var palette: Dictionary = EData.pal_colors(int(info.get("pal", 0)))
	material.set_shader_parameter("palette_c1", palette["c1"])
	material.set_shader_parameter("palette_c3", palette["c3"])
	material.set_shader_parameter("palette_c4", palette["c4"])
	image_rect.material = material
	for kind: String in ["cult", "person"]:
		var input := Image.new()
		var load_error := input.load(str(job["inputs"][kind]))
		if load_error != OK:
			push_error("Cannot load 2D input: " + kind)
			get_tree().quit(1)
			return
		image_rect.texture = ImageTexture.create_from_image(input)
		var normal := Image.new()
		if normal.load(str(job["normals"][kind])) != OK:
			push_error("Cannot load 2D normal map: " + kind)
			get_tree().quit(1)
			return
		material.set_shader_parameter("normal_tex", ImageTexture.create_from_image(normal))
		for frame in 4:
			await RenderingServer.frame_post_draw
		var output: Image = vp_final.get_texture().get_image()
		var output_path: String = str(job["outputs"][kind])
		if output.save_png(output_path) != OK:
			push_error("Cannot save 2D output: " + kind)
			get_tree().quit(1)
			return
		print("STYLE2D ", kind, " style_sid=", _style_sid(), " ", output_path)
	get_tree().quit()
