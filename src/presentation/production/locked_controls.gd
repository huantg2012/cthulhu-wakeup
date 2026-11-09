extends RefCounted
## Native primitives for interaction-slice.html. No legacy theme or assets.
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const INK := Color("#090f18")
const BONE := Color("#e2e3d8")
const MUTED := Color("#9baeb8")
const CYAN := Color("#92b5c2")
const GOLD := Color("#d8bc85")
const GOLD_HI := BONE
const RISK := Color("#d5a28d")
const VIOLET := Color("#afa9c6")
const BOUND := CYAN
const LINE := Color("#354d59")
const FIELD := Color("#101b28")
const POWER_ORDER: Array[String] = ["listen", "dream", "oracle", "bestow", "appoint", "sacrifice", "breach", "seed", "anchor", "veil", "transfer", "manifest"]
const SIGIL_PATHS := [
	"M10 32Q32 3 54 32Q32 61 10 32ZM32 18V46",
	"M16 44L32 13 48 44ZM22 34H42",
	"M15 15L49 49M49 15L15 49M18 32H46",
	"M17 45V19L32 10 47 19V45L32 54Z",
]
const SIGNS := {
	"person": "M19 53V48Q19 39 32 39Q45 39 45 48V53ZM32 15A8 8 0 1 0 32 31A8 8 0 1 0 32 15",
	"relic": "M32 9L50 32 32 55 14 32ZM14 32H50",
	"anchor_status": "M12 32H52M32 12V52M20 43L44 21",
	"history": "M17 12H47V52H17ZM24 23H40M24 32H40M24 41H35",
	"evidence": "M17 12H47V52H17ZM24 23H40M24 32H40M24 41H35",
	"search": "M28 13A15 15 0 1 0 28 43A15 15 0 1 0 28 13M39 39L51 51",
	"cult": "M14 48L23 27 32 40 41 27 50 48ZM32 13V25",
	"ritual": "M32 8L53 43H11ZM23 34H41M32 44V56",
}
var fonts: Dictionary
var keyboard_focus_query: Callable
var _glyphs := {}
var _tracking := {}
var _reference_serif: FontFile

func _init(_font: Font = null, focus_query := Callable()) -> void:
	var body := SystemFont.new()
	body.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "Hiragino Sans GB", "Heiti SC", "Arial Unicode MS"])
	var heading := SystemFont.new()
	heading.font_names = PackedStringArray(["Songti SC", "STSong", "Noto Serif CJK SC", "Hiragino Sans GB", "Arial Unicode MS"])
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Arial Unicode MS"])
	body.fallbacks = [fallback]
	heading.fallbacks = [fallback]
	fonts = {"body": body, "heading": heading}
	# CoreText's Songti SC name is resolved by Godot to face 0 (Black).
	# Use the browser sample’s regular face on macOS, without bundling an OS font.
	const SONGTI := "/System/Library/Fonts/Supplemental/Songti.ttc"
	if OS.get_name() == "macOS" and FileAccess.file_exists(SONGTI):
		var collection := FontFile.new()
		if collection.load_dynamic_font(SONGTI) == OK and collection.get_face_count() == 8:
			collection.fallbacks = [fallback]
			_reference_serif = collection
	keyboard_focus_query = focus_query

func rect(control: Control, bounds: Rect2) -> void:
	control.position = bounds.position
	control.size = bounds.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func image(parent: Node, node_name: String, bounds: Rect2, texture: Texture2D, tint := Color.WHITE, stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var slot := TextureRect.new()
	slot.name = node_name
	rect(slot, bounds)
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = stretch
	slot.texture = texture
	slot.modulate = tint
	parent.add_child(slot)
	return slot

func icon(parent: Node, node_name: String, key: String, bounds: Rect2, tint := CYAN) -> TextureRect:
	if not _glyphs.has(key):
		var index := POWER_ORDER.find(key)
		var glyph := '<circle cx="32" cy="32" r="28" opacity=".48"/><path d="%s"/>' % SIGNS.get(key, "M32 15L49 32 32 49 15 32Z")
		if key == "attention_dot": glyph = '<circle cx="32" cy="32" r="24" fill="white" stroke="none"/>'
		if index >= 0:
			glyph = '<circle cx="32" cy="32" r="25" opacity=".4"/><path d="M32 3V15M32 49V61M3 32H15M49 32H61"/><path d="%s"/><circle cx="32" cy="32" r="%d"/>' % [SIGIL_PATHS[index % 4], 4 + int(index / 4.0) * 3]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><g fill="none" stroke="white" stroke-width="1.55">%s</g></svg>' % glyph
		var bitmap := Image.new()
		bitmap.load_svg_from_string(svg)
		_glyphs[key] = ImageTexture.create_from_image(bitmap)
	return image(parent, node_name, bounds, _glyphs[key], tint)

func label(parent: Node, node_name: String, value: String, bounds: Rect2, font_size := 20, color := BONE, heading := false, wrap := false) -> Label:
	var item := Label.new()
	item.name = node_name
	rect(item, bounds)
	item.text = value
	item.add_theme_font_override("font", fonts.heading if heading else fonts.body)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func reference_label(parent: Node, node_name: String, value: String, bounds: Rect2, px: float, color := BONE, heading := false, tracking := 0.0, extra_size := 0, emphasis := false) -> Label:
	var item := label(parent, node_name, value, Layout.box(bounds), Layout.type_size(px) + extra_size, color, heading)
	item.clip_text = true
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.add_theme_font_override("font", reference_font(heading, tracking, emphasis))
	return item

func reference_font(heading: bool, tracking := 0.0, emphasis := false) -> Font:
	var key := Vector3(float(heading), tracking, float(emphasis))
	if not _tracking.has(key):
		var spaced := FontVariation.new()
		spaced.base_font = fonts.heading if heading else fonts.body
		if heading and _reference_serif != null:
			spaced.base_font = _reference_serif
			spaced.variation_face_index = 6 # STSongti-SC-Regular
		spaced.spacing_glyph = Layout.type_size(tracking)
		if emphasis: spaced.variation_embolden = 0.3
		_tracking[key] = spaced
	return _tracking[key]

func fill(parent: Node, node_name: String, bounds: Rect2, color: Color) -> ColorRect:
	var plate := ColorRect.new()
	plate.name = node_name
	rect(plate, bounds)
	plate.color = color
	parent.add_child(plate)
	return plate

func button_style(state: String, primary := false, quiet := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.bg_color = Color.TRANSPARENT
	if state == "focus":
		style.set_border_width_all(1)
		style.border_color = GOLD
		style.draw_center = false
		return style
	if state == "hover": style.bg_color = Color(CYAN, 0.09)
	if state == "pressed": style.bg_color = Color(CYAN, 0.17)
	if primary and state != "disabled":
		style.border_width_bottom = 1
		style.border_color = GOLD
	elif not quiet and state != "disabled":
		style.border_width_bottom = 1
		style.border_color = LINE
	return style

func world_row_style(state: String, selected: bool) -> StyleBoxFlat:
	var style := button_style(state, false, true)
	if selected:
		style.bg_color = Color(CYAN, 0.1)
		style.border_width_left = 1
		style.border_color = CYAN
	return style

func select_entry(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", world_row_style("normal", selected))

func button(parent: Node, node_name: String, caption: String, bounds: Rect2, callback: Callable, primary := false, quiet := true, font_size := 17) -> Button:
	var control := Button.new()
	control.name = node_name
	rect(control, bounds)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.text = caption
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.add_theme_font_override("font", fonts.body)
	control.add_theme_font_size_override("font_size", font_size)
	style_action(control, primary, quiet)
	control.pressed.connect(callback)
	control.focus_entered.connect(func(): sync_focus_style(control))
	if parent != null: parent.add_child(control)
	return control

func style_action(control: Button, primary: bool, quiet := true) -> void:
	control.add_theme_color_override("font_color", GOLD if primary else BONE)
	control.add_theme_color_override("font_hover_color", Color("#fff3d1"))
	control.add_theme_color_override("font_pressed_color", GOLD)
	control.add_theme_color_override("font_focus_color", GOLD if primary else BONE)
	control.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		control.add_theme_stylebox_override(state, button_style(state, primary, quiet))
	sync_focus_style(control)

func sync_focus_style(control: Button) -> void:
	var keyboard: bool = keyboard_focus_query.is_valid() and keyboard_focus_query.call()
	control.add_theme_stylebox_override("focus", button_style("focus") if keyboard else StyleBoxEmpty.new())

func set_available(control: Button, available: bool) -> void:
	control.disabled = not available
	var caption := control.find_child("ChoiceCaption", true, false) as Label
	if caption == null: return
	if not caption.has_meta("available_color"):
		caption.set_meta("available_color", caption.get_theme_color("font_color"))
	caption.add_theme_color_override("font_color", caption.get_meta("available_color") if available else MUTED)

func search_field(parent: Node, node_name: String, placeholder: String, bounds: Rect2) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	rect(field, bounds)
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.placeholder_text = placeholder
	field.add_theme_color_override("font_color", BONE)
	field.add_theme_color_override("font_placeholder_color", MUTED)
	field.add_theme_color_override("caret_color", CYAN)
	field.add_theme_color_override("selection_color", LINE)
	field.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, button_style(state, false, false))
	parent.add_child(field)
	return field

func choice_style(control: Button, selected: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := button_style(state, false, true)
		style.border_width_left = 1
		style.border_color = GOLD if selected else Color(CYAN, 0.55)
		if selected and state == "normal": style.bg_color = Color(CYAN, 0.09)
		control.add_theme_stylebox_override(state, style)

func scene_submit(control: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := button_style(state, false, true)
		style.set_border_width_all(1)
		style.border_color = Color(GOLD, 0.55 if state != "disabled" else 0.22)
		style.bg_color = Color(GOLD, 0.06 if state == "normal" or state == "disabled" else 0.13)
		control.add_theme_stylebox_override(state, style)
	control.add_theme_color_override("font_color", GOLD)
