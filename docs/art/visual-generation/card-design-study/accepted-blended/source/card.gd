extends Control
## A continuous printed carrier: coloured stock and edge-only art blending.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Surface = preload("res://tools/card-carrier-study/stock_surface.gdshader")
const Blend = preload("res://tools/card-carrier-study/art_blend.gdshader")
const INK := Color("#211c20")
const DETAIL := Color("#302a29")

var _stock: Texture2D
var _category := Color("#73594e")
var _copy: Array[Label] = []
var _left_name: Label
var _right_name: Label


func configure(sample: Dictionary, stock: Texture2D, artwork: Texture2D, card_size: Vector2) -> void:
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock = stock
	_category = sample.colour
	var compact := card_size.x < 170.0
	var full_size := card_size.x >= 250.0
	var margin := 13.0 if compact else 16.0
	var substrate := TextureRect.new()
	substrate.name = "ContinuousPrintedStock"
	substrate.size = size
	substrate.texture = stock
	substrate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	substrate.stretch_mode = TextureRect.STRETCH_SCALE
	substrate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := ShaderMaterial.new()
	surface.shader = Surface
	var lower := Color("#ac8d61")
	var upper := Color("#302426")
	if str(sample.kind) == "教团":
		lower = Color("#9e956d")
		upper = Color("#26302d")
	elif str(sample.kind) == "人物":
		lower = Color("#a58a7d")
		upper = Color("#302834")
	var paper_backed := "bone-watercolor" in str(sample.path)
	# A pale original must fade into its paper underpainting, not through a
	# charcoal halo. This changes the carrier below the image, never its RGB.
	if paper_backed:
		upper = lower.darkened(0.16)
	surface.set_shader_parameter("reading_colour", lower)
	surface.set_shader_parameter("ink_colour", upper)
	surface.set_shader_parameter("edge_colour", lower.lightened(0.14))
	substrate.material = surface
	add_child(substrate)
	var image_side := card_size.x
	var image_top := 0.0
	var picture := TextureRect.new()
	picture.name = "OriginalImage"
	picture.position = Vector2((size.x - image_side) * 0.5, image_top)
	picture.size = Vector2.ONE * image_side
	picture.texture = artwork
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := ShaderMaterial.new()
	blend.shader = Blend
	blend.set_shader_parameter("carrier_mask", stock)
	blend.set_shader_parameter("art_card_fraction", image_side / size.y)
	blend.set_shader_parameter("fade_bottom", 0.29)
	blend.set_shader_parameter("grain_scale", 8.0)
	blend.set_shader_parameter("seed_value", 4.0)
	if str(sample.kind) == "教团":
		blend.set_shader_parameter("protected_center", Vector2(0.50, 0.58))
		blend.set_shader_parameter("protected_radius", Vector2(0.43, 0.43))
	elif str(sample.kind) == "人物":
		blend.set_shader_parameter("protected_center", Vector2(0.50, 0.54))
		blend.set_shader_parameter("protected_radius", Vector2(0.32, 0.38))
	picture.material = blend
	add_child(picture)
	var header_ink := INK if paper_backed else lower.lightened(0.48)
	_copy.append(_label("Category", str(sample.kind), Rect2(margin, 10.0 if not compact else 7.0, size.x - margin * 2.0, 19.0), 13 if not compact else 12, header_ink))
	var title_px := 24 if full_size else (20 if not compact else 18)
	var title_y := 287.0 if full_size else (211.0 if not compact else 140.0)
	var title_width := size.x - margin * 2.0
	var long_title: bool = not compact and Paint.fonts().heading.get_string_size(str(sample.title), HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > title_width
	var title_height := float(title_px * 2 + 4) if long_title else float(title_px + 6)
	var heading := _label("Title", str(sample.title), Rect2(margin, title_y, title_width, title_height), title_px, INK, true)
	heading.max_lines_visible = 2 if long_title else 1
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long_title else TextServer.AUTOWRAP_OFF
	_copy.append(heading)
	var info_y := 326.0 if full_size else (241.0 if not compact else 165.0)
	if long_title:
		info_y = title_y + title_height + 2.0
	var text_px := 16 if full_size else 14
	_copy.append(_label("InformationOne", str(sample.line1), Rect2(margin, info_y, title_width, 22.0), text_px, DETAIL))
	if not str(sample.line2).is_empty() and info_y + 41.0 <= size.y - 5.0:
		_copy.append(_label("InformationTwo", str(sample.line2), Rect2(margin, info_y + 21.0, title_width, 20.0), text_px, DETAIL))
	var side_name := "\n".join(str(sample.title).split(""))
	var spine_ink := INK if paper_backed else Color("#e8d9bc")
	_left_name = _label("LeftSideName", side_name, Rect2(5.0, 30.0, 17.0, size.y - 40.0), 13, spine_ink)
	_right_name = _label("RightSideName", side_name, Rect2(size.x - 22.0, 30.0, 17.0, size.y - 40.0), 13, spine_ink)
	for label: Label in [_left_name, _right_name]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("line_spacing", -1)
		if not paper_backed:
			# A one-pixel ink edge keeps the same name legible when it crosses
			# image and stock; no separate rectangular spine is introduced.
			label.add_theme_color_override("font_outline_color", Color("#171615"))
			label.add_theme_constant_override("outline_size", 1)
		label.visible = false
	queue_redraw()


func set_exposure(side: int, exposed: float) -> void:
	var reading := smoothstep(size.x - 37.0, size.x - 3.0, exposed)
	for label: Label in _copy:
		label.modulate.a = reading
	_left_name.visible = side < 0 and exposed >= 23.0 and reading < 0.96
	_right_name.visible = side > 0 and exposed >= 23.0 and reading < 0.96
	_left_name.modulate.a = 1.0 - reading
	_right_name.modulate.a = 1.0 - reading


func _label(label_name: String, value: String, rect: Rect2, px: int, colour: Color, title := false) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Paint.fonts().heading if title else Paint.fonts().body)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", 0)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if title else CanvasItem.TEXTURE_FILTER_LINEAR
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label


func _draw() -> void:
	if _stock == null:
		return
	# Three small offsets retain the original paper silhouette. Their overlap
	# is hidden by this opaque sheet, leaving contact shade on the card below.
	draw_texture_rect(_stock, Rect2(Vector2(-4.0, 2.0), size), false, Color(0.0, 0.0, 0.0, 0.29))
	draw_texture_rect(_stock, Rect2(Vector2(3.0, 3.0), size), false, Color(0.0, 0.0, 0.0, 0.32))
	draw_texture_rect(_stock, Rect2(Vector2(0.0, 5.0), size), false, Color(0.0, 0.0, 0.0, 0.20))
