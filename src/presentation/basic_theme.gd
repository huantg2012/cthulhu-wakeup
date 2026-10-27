extends RefCounted
## Replaceable functional presentation for DEC-011; no final art direction implied.
## Attach the returned Theme to GameRoot/Presentation/CanvasLayer/OverlayRoot.
## Selection and unavailability also need explicit text in the owning view.

const BASE_FONT_SIZE := 19
const MIN_FONT_SIZE := 18
const BUTTON_MIN_HEIGHT := 38
const BACKGROUND := Color("#181818")
const SURFACE := Color("#242424")
const CONTROL := Color("#303030")
const SELECTION := Color("#414141")
const TEXT := Color("#ededed")
const SECONDARY_TEXT := Color("#c2c2c2")
const UNAVAILABLE_TEXT := Color("#b8b8b8")
const FOCUS := Color("#ffffff")
const BORDER := Color("#737373")


static func create(font_size: int = BASE_FONT_SIZE) -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
		"Source Han Sans SC", "sans-serif",
	])
	font.allow_system_fallback = true
	theme.default_font = font
	theme.default_font_size = clampi(font_size, MIN_FONT_SIZE, 28)
	theme.set_type_variation("Heading", "Label")
	theme.set_font_size("font_size", "Heading", theme.default_font_size + 5)
	theme.set_type_variation("Secondary", "Label")
	theme.set_font_size("font_size", "Secondary", maxi(MIN_FONT_SIZE, theme.default_font_size - 1))
	theme.set_color("font_color", "Secondary", SECONDARY_TEXT)
	for control_type in ["Label", "RichTextLabel", "Button", "CheckButton", "CheckBox", "OptionButton", "LineEdit", "SpinBox", "ItemList", "PopupMenu", "TabBar"]:
		theme.set_color("font_color", control_type, TEXT)
		theme.set_color("font_disabled_color", control_type, UNAVAILABLE_TEXT)
		theme.set_color("font_hover_color", control_type, TEXT)
		theme.set_color("font_focus_color", control_type, TEXT)
		theme.set_color("font_pressed_color", control_type, TEXT)
		theme.set_constant("outline_size", control_type, 0)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_constant("line_separation", "RichTextLabel", 5)
	theme.set_constant("line_spacing", "Label", 3)
	theme.set_stylebox("panel", "Panel", _box(BACKGROUND))
	theme.set_stylebox("panel", "PanelContainer", _box(SURFACE))
	for control_type in ["Button", "CheckButton", "CheckBox", "OptionButton"]:
		theme.set_stylebox("normal", control_type, _box(CONTROL, BORDER, 1))
		theme.set_stylebox("hover", control_type, _box(CONTROL, TEXT, 1))
		theme.set_stylebox("pressed", control_type, _box(SELECTION, TEXT, 1))
		theme.set_stylebox("disabled", control_type, _box(SURFACE, BORDER, 1))
		theme.set_stylebox("focus", control_type, _focus_box())
	theme.set_type_variation("SelectedAction", "Button")
	theme.set_stylebox("normal", "SelectedAction", _box(SELECTION, TEXT, 1))
	theme.set_stylebox("hover", "SelectedAction", _box(SELECTION, TEXT, 1))
	theme.set_stylebox("pressed", "SelectedAction", _box(SELECTION, TEXT, 1))
	theme.set_stylebox("panel", "ItemList", _box(BACKGROUND, BORDER, 1))
	theme.set_stylebox("selected", "ItemList", _box(SELECTION, TEXT, 1))
	theme.set_stylebox("selected_focus", "ItemList", _box(SELECTION, FOCUS, 2))
	theme.set_stylebox("focus", "ItemList", _focus_box())
	theme.set_color("font_selected_color", "ItemList", TEXT)
	theme.set_constant("v_separation", "ItemList", 8)
	theme.set_stylebox("normal", "LineEdit", _box(BACKGROUND, BORDER, 1))
	theme.set_stylebox("read_only", "LineEdit", _box(SURFACE, BORDER, 1))
	theme.set_stylebox("focus", "LineEdit", _focus_box())
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", SELECTION)
	theme.set_color("font_selected_color", "LineEdit", TEXT)
	theme.set_stylebox("panel", "PopupMenu", _box(SURFACE, BORDER, 1))
	theme.set_stylebox("hover", "PopupMenu", _box(SELECTION, FOCUS, 1))
	for container_type in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		theme.set_constant("separation", container_type, 8)
	theme.set_constant("h_separation", "GridContainer", 12)
	theme.set_constant("v_separation", "GridContainer", 8)
	return theme


## Machine gate for this temporary grayscale presentation, not aesthetic approval.
## Text >= 4.5:1 and focus indication >= 3:1 against every control background.
static func readability_issues() -> Array[String]:
	var issues: Array[String] = []
	for ink in [TEXT, SECONDARY_TEXT, UNAVAILABLE_TEXT]:
		for paper in [BACKGROUND, SURFACE, CONTROL, SELECTION]:
			if contrast_ratio(ink, paper) < 4.5:
				issues.append("Text contrast below 4.5:1: %s on %s" % [ink.to_html(), paper.to_html()])
	for paper in [BACKGROUND, SURFACE, CONTROL, SELECTION]:
		if contrast_ratio(FOCUS, paper) < 3.0:
			issues.append("Focus contrast below 3:1 on %s" % paper.to_html())
	return issues


static func contrast_ratio(first: Color, second: Color) -> float:
	var a := first.srgb_to_linear().get_luminance()
	var b := second.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


static func _box(fill: Color, edge: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = FOCUS
	box.set_border_width_all(2)
	return box
