extends RefCounted
## Native primitives for interaction-slice.html. No legacy theme or assets.
const Layout = preload("res://src/presentation/production/perception_layout.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const INK := Paint.INK
const BONE := Paint.BONE
const MUTED := Paint.MUTED
const CYAN := Paint.MUTED # Existing secondary information role.
const GOLD := Paint.WARM
const GOLD_HI := BONE
const RISK := Paint.RISK
const VIOLET := Paint.UNKNOWN
const BOUND := Paint.ACCENT
const LINE := Paint.LINE
const FIELD := Paint.FIELD
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
func _init(_font: Font = null, focus_query := Callable()) -> void:
	fonts = Paint.fonts()
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
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><g fill="none" stroke="white" stroke-width="2.05" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % glyph
		var bitmap := Image.new()
		bitmap.load_svg_from_string(svg)
		var dry := Paint.MaterialSource.noise(int(key.hash()), 0.13)
		for y: int in bitmap.get_height():
			for x: int in bitmap.get_width():
				var pigment := bitmap.get_pixel(x, y)
				if pigment.a <= 0.0: continue
				pigment.a *= 0.85 + 0.15 * dry.get_noise_2d(x * 0.8, y * 1.7)
				bitmap.set_pixel(x, y, pigment)
		_glyphs[key] = ImageTexture.create_from_image(bitmap)
	return image(parent, node_name, bounds, _glyphs[key], tint)

func label(parent: Node, node_name: String, value: String, bounds: Rect2, font_size := 20, color := BONE, heading := false, wrap := false) -> Label:
	var item := Label.new()
	item.name = node_name
	rect(item, bounds)
	item.text = value
	item.add_theme_font_override("font", fonts.heading if heading else fonts.body)
	item.add_theme_font_size_override("font_size", font_size if heading else maxi(14, font_size))
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if heading else CanvasItem.TEXTURE_FILTER_LINEAR
	item.add_theme_color_override("font_color", color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func reference_label(parent: Node, node_name: String, value: String, bounds: Rect2, px: float, color := BONE, heading := false, _tracking := 0.0, extra_size := 0, _emphasis := false) -> Label:
	var rect_box := Layout.box(bounds)
	var font_size := maxi(14, Layout.type_size(px)) + extra_size
	var fits_heading: bool = heading and fonts.heading.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= rect_box.size.x
	var item := label(parent, node_name, value, rect_box, font_size, color, fits_heading)
	item.clip_text = true
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if item.get_theme_font("font").get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect_box.size.x:
		item.tooltip_text = value
	return item

func reference_font(heading: bool, _tracking := 0.0, _emphasis := false) -> Font:
	return fonts.heading if heading else fonts.body

func fill(parent: Node, node_name: String, bounds: Rect2, color: Color) -> ColorRect:
	var plate := ColorRect.new()
	plate.name = node_name
	rect(plate, bounds)
	plate.color = color
	parent.add_child(plate)
	return plate

func button_style(state: String, primary := false, quiet := false) -> StyleBox:
	return Paint.button_style(state, _role(primary, quiet))

func _role(primary: bool, quiet: bool) -> Paint.Role:
	return Paint.Role.PRIMARY if primary else Paint.Role.NAVIGATION if quiet else Paint.Role.RESPONSIBILITY

func world_row_style(state: String, selected: bool) -> StyleBox:
	return Paint.button_style(state, Paint.Role.NAVIGATION, selected)

func select_entry(control: Button, selected: bool) -> void:
	control.set_meta("paint_selected", selected)
	_apply_button_styles(control)

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
	control.set_meta("paint_role", _role(primary, quiet))
	for state: String in ["font_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, BONE)
	control.add_theme_color_override("font_hover_color", Paint.HOVER)
	control.add_theme_color_override("font_hover_pressed_color", BONE)
	control.add_theme_color_override("font_disabled_color", MUTED)
	_apply_button_styles(control)
	sync_focus_style(control)

func _apply_button_styles(control: Button) -> void:
	var role: Paint.Role = control.get_meta("paint_role", Paint.Role.NAVIGATION)
	var selected: bool = control.get_meta("paint_selected", false)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		control.add_theme_stylebox_override(state, Paint.button_style(state, role, selected))

func sync_focus_style(control: Button) -> void:
	var keyboard: bool = keyboard_focus_query.is_valid() and keyboard_focus_query.call()
	var role: Paint.Role = control.get_meta("paint_role", Paint.Role.NAVIGATION)
	control.add_theme_stylebox_override("focus", Paint.button_style("focus", role) if keyboard else StyleBoxEmpty.new())

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
	field.add_theme_color_override("caret_color", Paint.ACCENT)
	field.add_theme_color_override("selection_color", LINE)
	field.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, Paint.field_style(state))
	parent.add_child(field)
	return field

func choice_style(control: Button, selected: bool) -> void:
	select_entry(control, selected)

func scene_submit(control: Button) -> void:
	style_action(control, true)
