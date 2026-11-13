extends SceneTree
## Standalone native composition proof. No Session, save, or production root.
const Card = preload("res://tools/card-carrier-study/card.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Atmosphere = preload("res://src/presentation/production/painted/peripheral_atmosphere.gd")
const VIEW := Vector2i(1280, 950)
const OUT := "res://docs/art/visual-generation/card-design-study/blended-carrier/"
const SOURCES := "res://docs/art/visual-generation/card-design-study/neutral-carrier/"
const MANIFEST := SOURCES + "source-manifest.json"
const STOCK := SOURCES + "card-stock.png"
const LARGE := Vector2(190.0, 285.0)
const FULL_SIZE := Vector2(260.0, 390.0)
const SMALL := Vector2(148.0, 198.0)
const HAND := Rect2(172.0, 654.0, 936.0, 212.0)

var _viewport: SubViewport
var _canvas: Control
var _page: Control
var _stock: Texture2D
var _textures: Dictionary = {}
var _samples: Array[Dictionary] = []
var _alternate: Dictionary
var _output := OUT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output = arg.trim_prefix("--output=")
	if not _load_sources():
		quit(1)
		return
	root.title = "邪神苏醒 · 连续印面 / 原生设计板"
	root.size = VIEW
	root.content_scale_size = VIEW
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.disable_3d = true
	_viewport = SubViewport.new()
	_viewport.size = VIEW
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_canvas = Control.new()
	_canvas.size = Vector2(VIEW)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_canvas)
	_build_environment()
	var display := TextureRect.new()
	display.size = Vector2(VIEW)
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_build_page(false)
	await _capture("mixed-styles.png")
	_build_page(true)
	await _capture("stacked-cards.png")
	print("CARRIER_PROOF_READY: ", ProjectSettings.globalize_path(_output))
	quit()


func _load_sources() -> bool:
	if not FileAccess.file_exists(STOCK) or not FileAccess.file_exists(MANIFEST):
		push_error("Carrier proof requires card-stock.png and source-manifest.json in " + OUT)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary:
		push_error("Carrier source manifest is not an object.")
		return false
	var tide: Dictionary = parsed.get("tide", {})
	var bone: Dictionary = parsed.get("bone_watercolor", {})
	var vivid: Dictionary = parsed.get("vibrant_world", {})
	if tide.is_empty() or bone.is_empty() or vivid.is_empty():
		push_error("Carrier source manifest must provide tide, bone_watercolor and vibrant_world.")
		return false
	_samples = [
		_sample(str(tide.world_title), "世界", str(tide.directory).path_join("world.png"), "潮汐世界", "", _notes(tide)),
		_sample(str(bone.world_title), "世界", str(bone.directory).path_join("world.png"), "骸骨世界", "", _notes(bone)),
		_sample(str(vivid.title), "世界", str(vivid.path), "血肉之星", "", str(vivid.notes)),
		_sample(str(tide.cult_title), "教团", str(tide.directory).path_join("cult.png"), "所属：" + str(tide.world_title), "", _notes(tide)),
		_sample(str(bone.cult_title), "教团", str(bone.directory).path_join("cult.png"), "所属：" + str(bone.world_title), "", _notes(bone)),
		_sample(str(bone.person_title), "人物", str(bone.directory).path_join("person-0-1000.png"), "受贿书信外泄", "", _notes(bone, true)),
	]
	_alternate = _sample(str(tide.person_title), "人物", str(tide.directory).path_join("person-0-1000.png"), "受贿书信外泄", "", _notes(tide, true))
	_stock = _texture(STOCK)
	if _stock == null:
		return false
	for sample: Dictionary in _samples + [_alternate]:
		if _texture(sample.path) == null:
			return false
	return true


func _notes(source: Dictionary, person := false) -> String:
	var value := "原型 %d · 画风 %d · 色板 %d\n世界种子 %d" % [int(source.archetype), int(source.styleSid), int(source.paletteId), int(source.worldSeed)]
	if person:
		value += " · 人物种子 %d" % int(source.personSeed)
	return value


func _sample(title: String, kind: String, path: String, line1: String, line2: String, notes: String) -> Dictionary:
	var colour := Color("#815a4c")
	if kind == "教团":
		colour = Color("#4d7168")
	elif kind == "人物":
		colour = Color("#756177")
	return {"title": title, "kind": kind, "path": path, "line1": line1, "line2": line2, "notes": notes, "colour": colour}


func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var resolved := path if path.is_absolute_path() or path.begins_with("res://") else "res://" + path
	var image := Image.load_from_file(resolved)
	if image == null or image.is_empty():
		push_error("Missing original image: " + resolved)
		return null
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


func _build_environment() -> void:
	var night := TextureRect.new()
	night.size = Vector2(VIEW)
	night.texture = Paint.MaterialSource.pigment("sky")
	night.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	night.stretch_mode = TextureRect.STRETCH_SCALE
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(night)
	var atmosphere := Atmosphere.new()
	_canvas.add_child(atmosphere)
	atmosphere.scale = Vector2(1.0, float(VIEW.y) / 720.0)
	atmosphere.paused = true
	atmosphere.set_sample_time(6.0)


func _build_page(alternate: bool) -> void:
	if is_instance_valid(_page):
		_canvas.remove_child(_page)
		_page.queue_free()
	_page = Control.new()
	_page.size = Vector2(VIEW)
	_canvas.add_child(_page)
	_label(_page, "完整卡 · 世界、教团与人物" if alternate else "不同画风 · 同一印面", Rect2(40, 31, 1180, 40), 30, Paint.BONE, true)
	_label(_page, "260 × 390 大牌 / 148 × 198 手牌实叠" if alternate else "原生成图承载样片 / 三世界 · 两教团 · 一人物", Rect2(43, 80, 1180, 25), 16, Paint.MUTED)
	var row: Array[Dictionary] = _samples.duplicate()
	if alternate:
		row = [_samples[0], _samples[4], _alternate]
	for index: int in row.size():
		var position_at := Vector2(190.0 + float(index) * 320.0, 125.0) if alternate else Vector2(40.0 + float(index) * 202.0, 125.0)
		var card_size := FULL_SIZE if alternate else LARGE
		_add_card(_page, row[index], card_size, position_at)
		_label(_page, row[index].notes, Rect2(position_at.x + 2.0, 526.0 if alternate else 423.0, card_size.x - 4.0, 55.0 if alternate else 88.0), 12, Color("#9fa69e"))
	_label(_page, "压叠 · 同一张完整卡面", Rect2(172, 590, 936, 31), 23, Paint.BONE, true)
	_label(_page, "148 × 198  ·  侧名印在原卡纸上  ·  20 张完整卡相互遮叠", Rect2(173, 624, 936, 22), 14, Paint.MUTED)
	var stack_samples: Array[Dictionary] = _samples.duplicate()
	if alternate:
		stack_samples[5] = _alternate
	_build_stack(stack_samples, 12 if alternate else 7)
	_label(_page, "原生成图 / 仅边缘透明过渡 / 原生字体 / 连续卡面", Rect2(172, 886, 936, 24), 14, Paint.MUTED)
	_label(_page, "独立视觉样片。名称与身份来自样本，示例处境不代表当前 Session、存档或正式页面。", Rect2(172, 916, 1010, 22), 13, Color("#87928c"))


func _add_card(parent: Control, sample: Dictionary, card_size: Vector2, at: Vector2) -> Control:
	var card := Card.new()
	card.configure(sample, _stock, _texture(sample.path), card_size)
	card.position = at
	parent.add_child(card)
	return card


func _build_stack(samples: Array[Dictionary], focus: int) -> void:
	var holder := Control.new()
	holder.position = HAND.position
	holder.size = HAND.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(holder)
	var count := 20
	var gaps := _spread_gaps(count, focus)
	var cards: Array[Control] = []
	var x := 8.0
	for index: int in count:
		var sample := samples[index % samples.size()]
		var depth := absf(float(index - focus))
		var card := _add_card(holder, sample, SMALL, Vector2(x, 3.0 + 5.0 * (1.0 - exp(-depth / 4.0))))
		cards.append(card)
		card.z_index = count - absi(index - focus)
		var exposed := SMALL.x if index == focus else gaps[index if index < focus else index - 1]
		card.set_exposure(-1 if index < focus else (1 if index > focus else 0), exposed)
		if index < count - 1:
			x += gaps[index]
	# Real complete cards determine occlusion, including their image and copy.
	# No strip snapshots, special narrow card art, or translucent spine panels.


func _spread_gaps(count: int, focus: int) -> PackedFloat32Array:
	var span := HAND.size.x - SMALL.x - 16.0
	var gap_count := count - 1
	var gaps := PackedFloat32Array()
	var weights := PackedFloat32Array()
	var pending: Array[int] = []
	var minimum := minf(9.0, span * 0.42 / float(gap_count))
	var remaining := span
	for index: int in gap_count:
		gaps.append(minimum)
		weights.append(exp(-absf(float(index) + 0.5 - float(focus)) / 2.4))
		pending.append(index)
		remaining -= minimum
	while not pending.is_empty() and remaining > 0.0001:
		var total := 0.0
		for index: int in pending:
			total += weights[index]
		var saturated: Array[int] = []
		for index: int in pending:
			if gaps[index] + remaining * weights[index] / total > SMALL.x:
				saturated.append(index)
		if saturated.is_empty():
			for index: int in pending:
				gaps[index] += remaining * weights[index] / total
			break
		for index: int in saturated:
			remaining -= SMALL.x - gaps[index]
			gaps[index] = SMALL.x
			pending.erase(index)
	return gaps


func _label(parent: Control, value: String, rect: Rect2, px: int, colour: Color, heading := false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Paint.fonts().heading if heading else Paint.fonts().body)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if heading else CanvasItem.TEXTURE_FILTER_LINEAR
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = not heading
	parent.add_child(label)
	# Apply the intended width after font and wrapping have recomputed the
	# Label minimum size; long source notes must remain inside their column.
	label.size.x = rect.size.x
	return label


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := _output.path_join(filename)
	var result := image.save_png(ProjectSettings.globalize_path(path))
	if result != OK:
		push_error("Could not save native composition: " + path)
		quit(1)
	print("CAPTURE: ", path, " ", image.get_size())
