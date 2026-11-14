extends RichTextLabel
## Explicit field/value typography shared by card faces and their reading areas.
## Plain prose is never parsed for punctuation or presumed to contain fields.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const PAPER_LABEL := Color("#66391e")
const PAPER_VALUE := Color("#211c20")

static func field(caption: String, value: Variant) -> Dictionary:
	return {"caption":caption,"value":str(value)}

static func plain(parts: Array) -> String:
	var result := ""
	for part: Variant in parts:
		result += str(part.caption)+"  "+str(part.value) if part is Dictionary else str(part)
	return result

static func escaped(value: String) -> String:
	return value.replace("[", "[lb]")

func _init() -> void:
	bbcode_enabled = true
	scroll_active = false
	selection_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_theme_font_override("normal_font",Paint.fonts().body)
	add_theme_constant_override("outline_size",0)

func content(parts: Array, px: int, paper := false) -> void:
	add_theme_font_size_override("normal_font_size",px)
	add_theme_color_override("default_color",PAPER_VALUE if paper else Paint.BONE)
	var ink: Color = PAPER_LABEL if paper else Paint.WARM
	text = ""
	for part: Variant in parts:
		if part is Dictionary:
			text += "[color=#%s]%s[/color]  %s" % [ink.to_html(false),escaped(str(part.caption)),escaped(str(part.value))]
		else: text += escaped(str(part))
	accessibility_name = plain(parts)

static func at(parent: Node, node_name: String, parts: Array, bounds: Rect2, px: int, paper := false) -> RichTextLabel:
	var control := new()
	control.name = node_name
	control.position = bounds.position
	control.size = bounds.size
	control.content(parts,px,paper)
	parent.add_child(control)
	return control

static func line(parent: Container, parts: Array, px := 17) -> RichTextLabel:
	var control := new()
	control.fit_content = true
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.content(parts,px)
	parent.add_child(control)
	return control

static func row(parent: Container, caption: String, value: String, px := 17) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = "Field_"+caption
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",14)
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 78
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",px)
	label.add_theme_color_override("font_color",Paint.WARM)
	box.add_child(label)
	var body := Label.new()
	body.text = value
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size",px)
	body.add_theme_color_override("font_color",Paint.BONE)
	box.add_child(body)
	return box
