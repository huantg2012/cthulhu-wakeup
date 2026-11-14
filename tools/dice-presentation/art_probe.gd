extends SceneTree
const Pair = preload("res://src/presentation/production/dice/dice_pair.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
var pair: Control

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "/tmp/dice-art"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	var scene := Control.new()
	scene.size = Vector2(960,540)
	root.add_child(scene)
	var bg := TextureRect.new()
	bg.texture = Paint.MaterialSource.pigment("sky")
	bg.size = Vector2(960,540)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	scene.add_child(bg)
	var title := Label.new()
	title.text = "刻骨之骰 · 二维程序绘制"
	title.position = Vector2(65,45)
	title.add_theme_font_override("font",Paint.fonts().heading)
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_color_override("font_color",Paint.BONE)
	scene.add_child(title)
	pair = Pair.new()
	pair.position = Vector2(120,125)
	pair.size = Vector2(720,370)
	pair.sound_enabled = false
	scene.add_child(pair)
	pair.roll_to(64,19)
	for time: float in [.25,.7,1.4,1.8,2.2]:
		while pair.elapsed<time and pair.rolling: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/roll-%03d.png" % int(time*100))
	pair.show_result(100)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/hundred.png")
	for value: int in range(1,101):
		var digits: Vector2i = Pair.final_d10(value)
		var joined := digits.x*10+digits.y
		if (100 if joined==0 else joined)!=value:
			push_error("Incorrect D100 face mapping")
			quit(1)
			return
	print("DICE_ART_OK: 100 face mappings and native frames")
	quit()
