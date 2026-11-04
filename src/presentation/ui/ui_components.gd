extends RefCounted
## Shared native controls. Visual authority: visual-system.md V2–V6.
const RestorationSkin = preload("res://src/presentation/ui/restoration_skin.gd")
const SOURCE_HOME: String = "res://docs/game-state/presentation-refinement-2026-11-03/echoes-home.png"
const SOURCE_OVERFLOW: String = "res://docs/game-state/ui-overflow-a.png"
const ROOT_ASSETS: String = "res://docs/art/echoes-ui/round-start-master/assets/"
const LOCAL: String = "res://tools/echoes-art-master/"
const GOLD := Color("e5c98d")
const GOLD_HI := Color("f2dba8")
const BONE := Color("e6ddc8")
const MUTED := Color("a9afa5")
const CYAN := Color("92c2c5")
const RISK := Color("ed9b81")
const VIOLET := Color("c4acdc")
const BOUND := Color("b4ce76")
const POWER_ICONS: Array[String] = ["listen","dream","oracle","bestow","appoint","sacrifice","breach","seed","anchor","veil","transfer","manifest"]
var skin := RestorationSkin.new()
var textures: Dictionary = {}
var atlas: Dictionary = {}
var fonts: Dictionary = {}
var keyboard_focus_query: Callable

func _init(font: Font = null, focus_query: Callable = Callable()) -> void:
	var regular: Font = font if font != null else preload("res://src/presentation/ui/restoration_font.gd").regular()
	fonts = {"body":regular,"heading":regular}
	keyboard_focus_query = focus_query
	if FileAccess.file_exists(ROOT_ASSETS+"atlas.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT_ASSETS+"atlas.json"))
		if parsed is Dictionary: atlas = parsed

func rect(control: Control, bounds: Rect2) -> void:
	control.position = bounds.position
	control.size = bounds.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func texture(path: String) -> Texture2D:
	if textures.has(path): return textures[path]
	if not FileAccess.file_exists(path): return null
	var image := Image.new()
	if image.load(path) != OK: return null
	var texture := ImageTexture.create_from_image(image)
	textures[path] = texture
	return texture

func atlas_texture(key: String) -> Texture2D:
	var regions: Dictionary = atlas.get("regions", {})
	if not regions.has(key): return null
	var entry: Dictionary = regions[key]
	var source: Texture2D = texture(ROOT_ASSETS + str(entry.get("file", "ui-ornaments.png")))
	if source == null: return null
	var coords: Array = entry.get("rect", [])
	if coords.size() != 4: return null
	var region := AtlasTexture.new()
	region.atlas = source
	region.region = Rect2(float(coords[0]),float(coords[1]),float(coords[2]),float(coords[3]))
	return region

func power_grid_texture(key: String) -> Texture2D:
	var index: int = POWER_ICONS.find(key)
	if index < 0: return null
	var grid: Dictionary = atlas.get("power_grid",{})
	var source: Texture2D = texture(ROOT_ASSETS + str(grid.get("file","power-sigils.png")))
	if source == null: return null
	var columns: int = int(grid.get("columns",4))
	var rows: int = int(grid.get("rows",3))
	if columns < 1 or rows < 1 or index >= columns*rows: return null
	var cell := Vector2(float(source.get_width())/columns,float(source.get_height())/rows)
	var region := AtlasTexture.new()
	region.atlas = source
	region.region = Rect2(Vector2(index%columns,index/columns)*cell,cell)
	return region

func image(parent: Node, title: String, rect: Rect2, texture: Texture2D, tint: Color = Color.WHITE, stretch: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var image := TextureRect.new()
	image.name = title
	rect(image,rect)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = stretch
	image.texture = texture
	image.modulate = tint
	parent.add_child(image)
	return image

func icon(parent: Node, title: String, key: String, rect: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var tex: Texture2D = skin.icon(key)
	if tex == null: tex = atlas_texture("power_" + key)
	if tex == null: tex = texture(LOCAL + "icons/" + key + ".svg")
	var item:=image(parent,title,rect,tex,tint)
	if tex is AtlasTexture and key!="cult_selected":
		var shader:=Shader.new()
		if key == "seizure":
			shader.code="shader_type canvas_item;uniform vec4 icon_tint: source_color=vec4(1.0);void fragment(){vec4 c=texture(TEXTURE,UV);float a=smoothstep(0.24,0.58,c.r);COLOR=vec4(c.rgb,a*c.a)*icon_tint;}"
		else:
			shader.code="shader_type canvas_item;uniform vec4 icon_tint: source_color=vec4(1.0);void fragment(){vec4 c=texture(TEXTURE,UV);float a=smoothstep(0.04,0.16,max(c.r,max(c.g,c.b)));COLOR=vec4(c.rgb,a*c.a)*icon_tint;}"
		var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("icon_tint",tint);item.material=material
	return item

func label(parent: Node, title: String, text_value: String, rect: Rect2, font_size: int = 20, color: Color = BONE, heading: bool = false, wrap: bool = false) -> Label:
	var item := Label.new()
	item.name = title
	rect(item,rect)
	item.text = text_value
	item.add_theme_font_override("font",fonts.heading)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	item.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.9))
	item.add_theme_constant_override("shadow_offset_y",1)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func fill(parent: Node, title: String, rect: Rect2, color: Color) -> ColorRect:
	var item := ColorRect.new()
	item.name = title
	rect(item,rect)
	item.color = color
	parent.add_child(item)
	return item

func gradient(parent: Node, title: String, rect: Rect2, top: Color, bottom: Color, horizontal: bool = false) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([top,bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2(1,0) if horizontal else Vector2(0,1)
	return image(parent,title,rect,tex,Color.WHITE,TextureRect.STRETCH_SCALE)

func separator(parent: Node, title: String, rect: Rect2, kind: String) -> TextureRect:
	# Extract only the warm, two-pixel metal seam from the auxiliary reference;
	# the transparent fringe keeps its original uneven wear without baking the
	# reference scene into the UI. Each edge samples a different source seam.
	var key := "separator:"+kind
	if not textures.has(key):
		var reference: Image = texture(SOURCE_OVERFLOW).get_image()
		var source_y: int = 47 if kind == "top" else (782 if kind == "dock_top" else 881)
		var strip := Image.create(900,6,false,Image.FORMAT_RGBA8)
		var weights: Array[float] = [0.08,0.35,0.90,0.90,0.35,0.08]
		for x: int in range(900):
			for y: int in range(6):
				var source: Color = reference.get_pixel(220+x,source_y+(1 if y >= 3 else 0))
				var warm := clampf((source.r-source.b)*8.0,0.0,1.0)
				source.a = warm*weights[y]
				strip.set_pixel(x,y,source)
		textures[key]=ImageTexture.create_from_image(strip)
	return image(parent,title,rect,textures[key],Color.WHITE,TextureRect.STRETCH_TILE)

func soft_support(parent: Node, title: String, rect: Rect2, tint: Color) -> ColorRect:
	var support := fill(parent,title,rect,tint)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { float x = smoothstep(0.0,0.16,UV.x)*(1.0-smoothstep(0.84,1.0,UV.x)); float y = smoothstep(0.0,0.24,UV.y)*(1.0-smoothstep(0.76,1.0,UV.y)); COLOR.a *= x*y; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	support.material = material
	return support

func frame(parent: Node, title: String, rect: Rect2, region: String = "group", _thickness: int = 0) -> Control:
	var frame := Panel.new()
	frame.name=title
	rect(frame,rect)
	frame.add_theme_stylebox_override("panel",skin.frame(region))
	parent.add_child(frame)
	return frame

func panel(parent: Node, title: String, rect: Rect2, opacity: float = 0.92, _ornament: bool = false) -> Control:
	var panel := Panel.new()
	panel.name=title
	rect(panel,rect)
	var surface := StyleBoxFlat.new()
	surface.bg_color=Color(0.012,0.023,0.026,opacity)
	surface.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",surface)
	parent.add_child(panel)
	return panel

func button_style(state: String, bone: bool = false, quiet: bool = false) -> StyleBox:
	return skin.style("quiet" if quiet else ("primary" if bone else "dark"),state)

func unframed_style(state: String, dark_action: bool = false) -> StyleBox:
	# Outside the top bar and dock, state is conveyed by a soft surface rather
	# than a hairline outline. Focus remains distinct from normal and hover.
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.13,0.105,0.07,0.57) if dark_action else Color(0.018,0.043,0.045,0.46)
	if state == "hover": surface.bg_color = Color(0.19,0.17,0.12,0.52)
	elif state == "pressed": surface.bg_color = Color(0.32,0.27,0.17,0.55)
	elif state == "focus": surface.bg_color = Color(0.30,0.48,0.47,0.38)
	elif state == "disabled": surface.bg_color = Color(0.018,0.03,0.03,0.24)
	surface.set_corner_radius_all(5)
	surface.content_margin_left=10; surface.content_margin_right=10
	surface.content_margin_top=2; surface.content_margin_bottom=2
	return surface

func transparent_button(button: Button) -> void:
	# Preserve focus and a restrained hover without resurrecting the normal frame.
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	for state: String in ["hover", "pressed"]:
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color(0.64,0.55,0.38,0.09 if state == "hover" else 0.16)
		surface.set_corner_radius_all(roundi(minf(button.size.x,button.size.y)*0.48))
		button.add_theme_stylebox_override(state,surface)

func button(parent: Node, title: String, text_value: String, rect: Rect2, callback: Callable, bone: bool = false, quiet: bool = false, font_size: int = 20, legacy_style: bool = false) -> Button:
	var button := Button.new()
	button.name = title
	rect(button,rect)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font",fonts.heading)
	button.add_theme_font_size_override("font_size",font_size)
	button.add_theme_color_override("font_color",Color("272219") if bone else GOLD)
	button.add_theme_color_override("font_hover_color",Color("211e17") if bone else Color("ffe6b3"))
	button.add_theme_color_override("font_pressed_color",Color("211e17") if bone else GOLD)
	button.add_theme_color_override("font_focus_color",Color("211e17") if bone else BONE)
	button.add_theme_color_override("font_disabled_color",Color(MUTED,0.55))
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var old_style: bool = legacy_style or (bone and state != "focus")
		button.add_theme_stylebox_override(state,button_style(state,bone,quiet) if old_style else unframed_style(state,not quiet))
	button.pressed.connect(callback)
	button.focus_entered.connect(func(): sync_focus_style(button))
	parent.add_child(button)
	return button

func sync_focus_style(button: Button) -> void:
	if keyboard_focus_query.is_valid() and keyboard_focus_query.call():
		if button.has_meta("keyboard_focus_style"):
			button.add_theme_stylebox_override("focus",button.get_meta("keyboard_focus_style"))
			button.remove_meta("keyboard_focus_style")
		if button.has_meta("keyboard_focus_color"):
			button.add_theme_color_override("font_focus_color",button.get_meta("keyboard_focus_color"))
			button.remove_meta("keyboard_focus_color")
	elif not button.has_meta("keyboard_focus_style"):
		button.set_meta("keyboard_focus_style",button.get_theme_stylebox("focus"))
		button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		button.set_meta("keyboard_focus_color",button.get_theme_color("font_focus_color"))
		button.add_theme_color_override("font_focus_color",button.get_theme_color("font_color"))

func world_row_style(state: String, selected: bool) -> StyleBox:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.22,0.17,0.10,0.68) if selected else Color(0.015,0.035,0.038,0.68)
	if state == "hover": surface.bg_color = Color(0.19,0.16,0.10,0.76)
	elif state == "pressed": surface.bg_color = Color(0.27,0.22,0.13,0.82)
	surface.set_corner_radius_all(4)
	return surface

func search_field(parent: Node, title: String, placeholder: String, bounds: Rect2) -> LineEdit:
	var search := LineEdit.new()
	search.name = title
	rect(search,bounds)
	search.mouse_filter = Control.MOUSE_FILTER_STOP
	search.placeholder_text = placeholder
	search.add_theme_font_override("font",fonts.heading)
	search.add_theme_font_size_override("font_size",18)
	search.add_theme_color_override("font_placeholder_color",Color("a9a69a"))
	var field := unframed_style("normal")
	field.set_content_margin(SIDE_LEFT,34)
	search.add_theme_stylebox_override("normal",field)
	search.add_theme_stylebox_override("focus",unframed_style("focus"))
	parent.add_child(search)
	return search

func fragment_material(region:Rect2,feather:float, strength:float) -> ShaderMaterial:
	return feather_material(Rect2(region.position / Vector2(1672, 941), region.size / Vector2(1672, 941)), feather, strength)

func feather_material(uv: Rect2, feather: float, strength: float = 1.0) -> ShaderMaterial:
	var shader:=Shader.new()
	# AtlasTexture UV is in the full sheet; explicitly transform it back to
	# the local tile before computing feathering. The previous plain UV use
	# kept rectangular crop edges visible.
	shader.code="""shader_type canvas_item;
uniform vec4 tile_rect=vec4(0.0,0.0,1.0,1.0);
uniform float feather=0.2;
uniform float strength=1.0;
void fragment(){vec4 c=texture(TEXTURE,UV);vec2 p=(UV-tile_rect.xy)/tile_rect.zw;float edge=smoothstep(0.0,feather,p.x)*(1.0-smoothstep(1.0-feather,1.0,p.x))*smoothstep(0.0,feather,p.y)*(1.0-smoothstep(1.0-feather,1.0,p.y));COLOR=vec4(c.rgb,c.a*edge*strength);}"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("tile_rect",Vector4(uv.position.x, uv.position.y, uv.size.x, uv.size.y))
	material.set_shader_parameter("feather",feather)
	material.set_shader_parameter("strength",strength)
	return material
