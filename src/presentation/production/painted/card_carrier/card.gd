extends Control
## Continuous carrier with one selected left shoulder and one left side name.
## Parent controllers own overlap, movement, drag submission and game state.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Fields = preload("res://src/presentation/production/painted/card_fields.gd")
const Surface = preload("res://src/presentation/production/painted/card_carrier/stock_surface.gdshader")
const Blend = preload("res://src/presentation/production/painted/card_carrier/art_blend.gdshader")
const CategoryMarks = preload("res://src/presentation/production/painted/card_carrier/category_marks.gd")
const SelectionMark = preload("res://src/presentation/production/painted/card_carrier/selection_mark.gd")
const Edge = preload("res://src/presentation/production/painted/card_carrier/card_edge.gdshader")
const INK := Color("#211c20")
const DETAIL := Color("#302a29")

var payload: Dictionary = {}
var hover_enabled := true
var art: TextureRect:
	get: return _picture
var source_sample: Dictionary:
	get: return _sample.duplicate(true)

var _stock: Texture2D
var _sample: Dictionary = {}
var _options: Dictionary = {}
var _identity_variant := 2
var _category_id := "world"
var _paper_backed := false
var _peek_amount := 0.0
var _side := 0
var _exposed := 0.0
var _lower := Color("#ac8d61")
var _upper := Color("#302426")
var _surface: ShaderMaterial
var _blend: ShaderMaterial
var _edge_material: ShaderMaterial
var _edge: TextureRect
var _substrate: TextureRect
var _picture: TextureRect
var _marks: Control
var _selection_mark: Control
var art_status: Label
var _header: Label
var _heading: Label
var _information_one: RichTextLabel
var _information_two: RichTextLabel
var _left_name: Label
var _copy: Array[Control] = []


## The four original arguments remain valid. Optional host overrides include
## paper_backed, payload, font_extra, title_font_size, title_y, info_y, title_max_lines,
## show_header, reading_colour, ink_colour and the Blend uniform names.
## Artwork may be null: OriginalImage stays visible for a later portrait bind.
func configure(sample: Dictionary, stock: Texture2D, artwork: Texture2D,
		card_size: Vector2, options: Dictionary = {}) -> void:
	_sample = sample.duplicate(true)
	_options = options.duplicate(true)
	_stock = stock
	size = card_size
	mouse_filter = int(options.get("mouse_filter", Control.MOUSE_FILTER_IGNORE))
	focus_mode = Control.FOCUS_NONE
	_identity_variant = 0 if int(options.get("identity_variant", sample.get("identity_variant", 2))) == 0 else 2
	_category_id = _resolve_category(sample)
	_paper_backed = bool(options.get("paper_backed", sample.get("paper_backed", "bone-watercolor" in str(sample.get("path", "")))))
	var data: Variant = options.get("payload", sample.get("payload", {}))
	payload = data.duplicate(true) if data is Dictionary else {}
	_ensure_nodes()
	_edge.position = Vector2(-4.0, -4.0)
	_edge.size = size + Vector2(8.0, 8.0)
	_edge.texture = stock
	_edge_material.set_shader_parameter("card_mask", stock)
	_edge_material.set_shader_parameter("face_size", size)
	_edge_material.set_shader_parameter("thickness", clampf(size.x / 148.0, 1.0, 1.33) * 1.8)
	_substrate.size = size
	_substrate.texture = stock
	_picture.position = Vector2.ZERO
	var art_height := float(options.get("art_height", size.x))
	_picture.size = Vector2(size.x, art_height)
	_picture.texture = artwork
	_picture.visible = bool(options.get("show_art", true))
	_blend.set_shader_parameter("carrier_mask", stock)
	_blend.set_shader_parameter("art_card_fraction", art_height / maxf(size.y, 1.0))
	_blend.set_shader_parameter("source_aspect", size.x / maxf(art_height, 1.0))
	_surface.set_shader_parameter("reading_onset", float(options.get("reading_onset", 0.52)))
	_blend.set_shader_parameter("fade_bottom", float(options.get("fade_bottom", 0.29)))
	_blend.set_shader_parameter("grain_scale", float(options.get("grain_scale", 8.0)))
	_blend.set_shader_parameter("seed_value", float(options.get("seed_value", sample.get("seed_value", 4.0))))
	var center := Vector2(0.50, 0.51)
	var radius := Vector2(0.36, 0.37)
	var art_kind := str(options.get("art_kind", sample.get("art_kind", "person" if _category_id == "prayer" else _category_id)))
	if art_kind == "cult":
		center = Vector2(0.50, 0.58)
		radius = Vector2(0.43, 0.43)
	elif art_kind == "person":
		center = Vector2(0.50, 0.54)
		radius = Vector2(0.32, 0.38)
	_blend.set_shader_parameter("protected_center", options.get("protected_center", center))
	_blend.set_shader_parameter("protected_radius", options.get("protected_radius", radius))
	_marks.configure(_category_id, _identity_variant, size)
	_marks.visible = bool(options.get("show_identity", true))
	_selection_mark.size = size
	art_status.position = Vector2(10, minf(art_height * 0.52, size.y * 0.4))
	art_status.size = Vector2(size.x - 20, 28)
	_layout_copy()
	_update_paper()
	set_exposure(0, size.x)
	queue_redraw()


func _resolve_category(sample: Dictionary) -> String:
	var explicit := str(sample.get("category_id", ""))
	if explicit in CategoryMarks.IDS:
		return explicit
	var kind := str(sample.get("kind", "世界"))
	if kind in CategoryMarks.IDS:
		return kind
	for id: String in CategoryMarks.IDS:
		if str(CategoryMarks.info(id).label) == kind:
			return id
	return "action"


func _ensure_nodes() -> void:
	if is_instance_valid(_picture):
		return
	_edge = TextureRect.new()
	_edge.name = "CardCutEdge"
	_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_material = ShaderMaterial.new()
	_edge_material.shader = Edge
	_edge.material = _edge_material
	add_child(_edge)
	_substrate = TextureRect.new()
	_substrate.name = "ContinuousPrintedStock"
	_substrate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_substrate.stretch_mode = TextureRect.STRETCH_SCALE
	_substrate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface = ShaderMaterial.new()
	_surface.shader = Surface
	_substrate.material = _surface
	add_child(_substrate)
	_picture = TextureRect.new()
	_picture.name = "OriginalImage"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blend = ShaderMaterial.new()
	_blend.shader = Blend
	_picture.material = _blend
	add_child(_picture)
	_marks = CategoryMarks.new()
	_marks.name = "CategoryMarks"
	add_child(_marks)
	_header = _new_label("Category")
	_heading = _new_label("Title", true)
	_information_one = Fields.at(self,"InformationOne",[],Rect2(),14,true)
	_information_two = Fields.at(self,"InformationTwo",[],Rect2(),14,true)
	_copy = [_header, _heading, _information_one, _information_two]
	_left_name = _new_label("LeftSideName")
	_left_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_name.add_theme_constant_override("line_spacing", -1)
	_left_name.visible = false
	art_status = _new_label("ArtStatus")
	art_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_status.add_theme_font_size_override("font_size", 14)
	art_status.add_theme_color_override("font_color", Color("#e8d9bc"))
	_selection_mark = SelectionMark.new()
	_selection_mark.name = "SelectionImprint"
	add_child(_selection_mark)


func _layout_copy() -> void:
	var compact := size.x < 170.0
	var full_size := size.x >= 250.0
	var margin := float(_options.get("text_margin", 13.0 if compact else 16.0))
	var extra := int(_options.get("font_extra", 0))
	var title_px := (24 if size.x >= 220.0 else (20 if not compact else 18)) + extra
	title_px = int(_options.get("title_font_size", title_px))
	var text_px := int(_options.get("body_font_size", (16 if full_size else 14) + extra))
	var title_left := float(_options.get("title_left", margin))
	var title_width := size.x - title_left - margin
	var title := str(_sample.get("title", ""))
	var maximum_lines := int(_options.get("title_max_lines", 1 if compact else 2))
	var long_title: bool = maximum_lines > 1 and Paint.fonts().heading.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > title_width
	var title_height := float(title_px * maximum_lines + 4) if long_title else float(title_px + 6)
	var line1 := str(_sample.get("line1", ""))
	var body_row_height: float = ceilf(Paint.fonts().body.get_height(text_px))
	var long_info: bool = _identity_variant != 0 and ("\n" in line1 or Paint.fonts().body.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px).x > title_width)
	var info_height := body_row_height * (2.0 if long_info else 1.0)
	var title_y := size.y * 0.71
	var info_y := size.y * 0.84
	if _identity_variant == 0:
		# Retain the accepted reference geometry for the no-imprint snapshot.
		title_y = 287.0 if full_size else (211.0 if not compact else 140.0)
		info_y = 326.0 if full_size else (241.0 if not compact else 165.0)
	else:
		title_height = maxf(title_height, ceilf(Paint.fonts().heading.get_height(title_px)) * (float(maximum_lines) if long_title else 1.0))
		# The full-width square image usually ends its blend before 90% of its
		# width. Executing / arrival cards use their actual height, not 190x285.
		title_y = maxf(title_y, size.x * 0.88 + 6.0)
		title_y = minf(title_y, size.y - title_height - info_height - 8.0)
		info_y = minf(maxf(info_y, title_y + title_height + 3.0), size.y - info_height - 5.0)
	title_y = float(_options.get("title_y", title_y))
	info_y = float(_options.get("info_y", info_y))
	if long_title and _identity_variant == 0 and not _options.has("info_y"):
		info_y = title_y + title_height + 2.0
	_header.text = str(_sample.get("kind", CategoryMarks.info(_category_id).label))
	_header.visible = bool(_options.get("show_header", _identity_variant == 0))
	_set_label_box(_header, Rect2(34.0 if _identity_variant != 0 else margin, 10.0 if not compact else 7.0,
		size.x - (34.0 if _identity_variant != 0 else margin) - margin, 19.0), (13 if not compact else 12) + extra)
	_heading.text = title
	_heading.max_lines_visible = maximum_lines if long_title else 1
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long_title else TextServer.AUTOWRAP_OFF
	_set_label_box(_heading, Rect2(title_left, title_y, title_width, title_height), title_px)
	_heading.add_theme_color_override("font_color", INK)
	_information_one.content(_sample.get("line1_fields",[line1]),text_px,true)
	_information_one.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long_info else TextServer.AUTOWRAP_OFF
	_set_label_box(_information_one, Rect2(margin, info_y, title_width, maxf(info_height, float(text_px + 6)) if _identity_variant == 0 else info_height), text_px)
	_information_one.add_theme_color_override("font_color", DETAIL)
	_information_two.content(_sample.get("line2_fields",[str(_sample.get("line2", ""))]),text_px,true)
	var second_y := info_y + (float(text_px + 7) if _identity_variant == 0 else info_height + 3.0)
	_information_two.visible = not _information_two.text.is_empty() and second_y + body_row_height <= size.y - 5.0
	_set_label_box(_information_two, Rect2(margin, second_y, title_width, body_row_height), text_px)
	_information_two.add_theme_color_override("font_color", DETAIL)
	var spine_y := 64.0 if _identity_variant != 0 else 30.0
	var characters := title.split("")
	var limit := clampi(floori((size.y - spine_y - 10.0) / 17.0), 1, 8)
	if characters.size() > limit:
		characters.resize(maxi(0, limit - 1))
		characters.append("…")
	_left_name.text = "\n".join(characters)
	_set_label_box(_left_name, Rect2(6.0, spine_y, 18.0, maxf(1.0, size.y - spine_y - 10.0)), 13)
	if not bool(_options.get("show_copy", true)):
		for label: Control in _copy: label.hide()


func _new_label(label_name: String, heading := false) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Paint.fonts().heading if heading else Paint.fonts().body)
	label.add_theme_constant_override("outline_size", 0)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if heading else CanvasItem.TEXTURE_FILTER_LINEAR
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label


func _set_label_box(label: Control, rect: Rect2, px: int) -> void:
	label.add_theme_font_size_override("normal_font_size" if label is RichTextLabel else "font_size", px)
	label.position = rect.position
	label.size = rect.size


func _update_paper() -> void:
	_lower = Color("#ac8d61")
	_upper = Color("#302426")
	if _category_id == "cult":
		_lower = Color("#9e956d")
		_upper = Color("#26302d")
	elif _category_id in ["person", "prayer"]:
		_lower = Color("#a58a7d")
		_upper = Color("#302834")
	_lower = _options.get("reading_colour", _lower)
	_upper = _options.get("ink_colour", _lower.darkened(0.16) if _paper_backed else _upper)
	_edge_material.set_shader_parameter("core_colour", _lower.darkened(0.28))
	_header.add_theme_color_override("font_color", INK if _paper_backed else _lower.lightened(0.48))
	var spine_ink := INK if _paper_backed else Color("#e8d9bc")
	_left_name.add_theme_color_override("font_color", spine_ink)
	_left_name.add_theme_color_override("font_outline_color", Color("#171615"))
	_left_name.add_theme_constant_override("outline_size", 0 if _paper_backed else 1)
	_marks.set("short_text_colour", spine_ink)
	_apply_peek()


func set_artwork(texture: Texture2D, paper_backed_override: Variant = null) -> void:
	_ensure_nodes()
	_picture.texture = texture
	_picture.visible = true
	if paper_backed_override != null:
		_paper_backed = bool(paper_backed_override)
		_update_paper()


static func face_copy_visible(side: int, exposed: float) -> bool:
	# Match the accepted overview's readable fragments: a broad exposed face
	# retains solid printed ink, naturally occluded by its right-hand neighbour.
	# Only a genuinely narrow edge switches to the vertical name treatment.
	return side == 0 or exposed >= 70.0


func set_exposure(side: int, exposed: float) -> void:
	_side = -1 if side != 0 else 0
	_exposed = maxf(0.0, exposed)
	if not is_instance_valid(_picture):
		return
	_marks.set_exposure(_side, _exposed)
	# Exposure is a layout state, NOT an opacity. At 9 arrival cards the old
	# smoothstep left 118px visible but erased 89% of every covered card's ink.
	var reading := 1.0 if face_copy_visible(_side, _exposed) else 0.0
	for label: Control in _copy:
		label.modulate.a = reading
	_left_name.visible = _side != 0 and _exposed >= 23.0 and reading == 0.0
	_left_name.modulate.a = 1.0


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_mark):
		_selection_mark.chosen = value
		_selection_mark.queue_redraw()


func set_card_hover(hovered: bool) -> void:
	set_peek_amount(1.0 if hovered and hover_enabled else 0.0)


func set_peek_amount(amount: float) -> void:
	var next := clampf(amount, 0.0, 1.0)
	if is_equal_approx(_peek_amount, next):
		return
	_peek_amount = next
	_apply_peek()


func _apply_peek() -> void:
	if _surface == null:
		return
	# Only the paper and shoulder brighten. Never modulate the carrier root:
	# the original picture RGB, transforms and sibling z-order stay untouched.
	_surface.set_shader_parameter("reading_colour", _lower.lightened(_peek_amount * 0.035))
	_surface.set_shader_parameter("ink_colour", _upper.lightened(_peek_amount * 0.018))
	_surface.set_shader_parameter("edge_colour", _lower.lightened(0.14 + _peek_amount * 0.025))
	var light := 1.0 + _peek_amount * 0.035
	_marks.set_peek_amount(_peek_amount)
	_marks.modulate = Color(light, light, light, 1.0)
	queue_redraw()


func make_drag_preview() -> Control:
	# Every drag owns a new complete card. Textures remain shared resources;
	# no cached preview node is returned or freed by a later drag.
	var preview: Control = get_script().new()
	var options := _options.duplicate(true)
	options["paper_backed"] = _paper_backed
	options["payload"] = payload.duplicate(true)
	options["mouse_filter"] = Control.MOUSE_FILTER_IGNORE
	preview.configure(_sample, _stock, _picture.texture if is_instance_valid(_picture) else null, size, options)
	preview.name = "CompleteCardDragPreview"
	preview.set_exposure(0, size.x)
	preview.set_peek_amount(0.0)
	preview.tooltip_text = tooltip_text
	return preview


func _draw() -> void:
	if _stock == null:
		return
	# Light falls from upper left. The cut stays the same thickness when lifted;
	# only its close, attached shadow opens a little beneath it.
	var lift_shadow := _peek_amount * 1.4
	draw_texture_rect(_stock, Rect2(Vector2(0.5, 3.0 + lift_shadow), size), false, Color(0.0, 0.0, 0.0, 0.30))
	draw_texture_rect(_stock, Rect2(Vector2(1.4, 4.1 + lift_shadow), size), false, Color(0.0, 0.0, 0.0, 0.17))
	draw_texture_rect(_stock, Rect2(Vector2(1.0, 5.2 + lift_shadow), size), false, Color(0.0, 0.0, 0.0, 0.09))
