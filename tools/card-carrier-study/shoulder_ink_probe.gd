extends SceneTree
## Rendered-pixel regression: dense resting shoulders must contain BOTH glyphs.
## This is a presentation fixture, never a Session or fabricated game state.
const Marks = preload("res://src/presentation/production/painted/card_carrier/category_marks.gd")
const WIDTHS := [16,19,21,23,26,32]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "/tmp/shoulder-ink.png"
	# Optional original script proves that the same pixel check catches the bug.
	var script: Script = load(args[1]) if args.size()>1 else Marks
	var canvas := SubViewport.new()
	canvas.size = Vector2i(224,Marks.IDS.size()*64)
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var samples: Array = []
	for row: int in Marks.IDS.size():
		var x := 0
		for width: int in WIDTHS:
			var clip := Control.new()
			clip.position = Vector2(x,row*64)
			clip.size = Vector2(width,60)
			clip.clip_contents = true
			canvas.add_child(clip)
			var mark: Control = script.new()
			clip.add_child(mark)
			mark.configure(Marks.IDS[row],2,Vector2(148,198))
			mark.set_exposure(-1,float(width))
			samples.append({"at":Vector2i(x,row*64),"width":width,"ink":mark._contrasting_ink(),"category":Marks.IDS[row]})
			x += width+8
	await process_frame
	await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	if image.save_png(output)!=OK:
		push_error("Could not save shoulder evidence")
		quit(1)
		return
	var failures: Array = []
	for sample: Dictionary in samples:
		for glyph: int in 2:
			var pixels := 0
			for y: int in range(12+glyph*18,26+glyph*18):
				for x: int in range(3,sample.width):
					var colour := image.get_pixelv(sample.at+Vector2i(x,y))
					var expected: Color = sample.ink
					var distance := Vector3(colour.r-expected.r,colour.g-expected.g,colour.b-expected.b).length()
					if colour.a>.9 and distance<.18: pixels += 1
			if pixels<8: failures.append("%s/%spx/character%s=%s ink pixels" % [sample.category,sample.width,glyph+1,pixels])
	print("SHOULDER_INK ",samples.size()*2," glyph checks; ",failures.size()," failures")
	for failure: String in failures: print(failure)
	quit(0 if failures.is_empty() else 1)
