extends Control
## Editable art master. Fixture data is isolated; no Session, save, or rule writes.
const RestorationSkin = preload("res://tools/echoes-art-master/restoration_skin.gd")
const DockContent = preload("res://tools/echoes-art-master/dock_content.gd")
const RoundAction = preload("res://tools/echoes-art-master/round_action_button.gd")
const RESTORED: String = "res://docs/art/echoes-ui/round-start-master/restoration-assets/"
const SOURCE_HOME: String = "res://docs/game-state/presentation-refinement-2026-11-03/echoes-home.png"
const SOURCE_OVERFLOW: String = "res://docs/game-state/ui-overflow-a.png"
const VIEW := Vector2(1672,941)
const Catalog = preload("res://src/simulation/catalog.gd")
const Semantics = preload("res://src/presentation/experience_semantics.gd")
const ROOT_ASSETS: String = "res://docs/art/echoes-ui/round-start-master/assets/"
const FALLBACK_ASSETS: String = "res://docs/art/echoes-ui/assets/"
const LOCAL: String = "res://tools/echoes-art-master/"
const GOLD := Color("e5c98d")
const GOLD_HI := Color("f2dba8")
const BONE := Color("e6ddc8")
const MUTED := Color("a9afa5")
const CYAN := Color("92c2c5")
const RISK := Color("ed9b81")
const VIOLET := Color("c4acdc")
const POWER_ICONS: Array[String] = ["listen","dream","oracle","bestow","appoint","sacrifice","breach","seed","anchor","veil","transfer","manifest"]
# Display fixtures only. Content IDs, names, costs and effects are read from CSV.
const PRAYERS: Array[Dictionary] = [
	{"id":"PRAYER_01","person":"米拉","role":"幸存者","world":"千面06","due":"本轮到期","line":"她还活着。让这口气留在她的身体里。","relation":"亲属：伊莲 · 原病危至第47轮末","icon":"relatives"},
	{"id":"PRAYER_05","person":"塞拉","role":"祭司","world":"盐梦02","due":"第48轮到期","line":"祭日将至。请在仪式结束前，留下可见的见证。","relation":"所属机构的仪式求告","icon":"ritual"},
	{"id":"PRAYER_04","person":"伊文","role":"领袖","world":"镜证04","due":"第47轮到期","line":"记录没有改变。为何只有我看见其中的异样？","relation":"祈求身份与已有记录相连","icon":"evidence"},
]
var skin := RestorationSkin.new()
@export var prayer_sidebar_rect := Rect2(1292,70,370,548)
@export var adjusted_dock_rect := Rect2(0,761,1672,180)
@export var adjusted_chronicle_rect := Rect2(0,889,1445,40)
@export var sanctuary_rect := Rect2(480,270,610,264)
var reference_layout: bool = false
var catalog: RefCounted
var semantics: RefCounted = Semantics.new()
var fonts: Dictionary = {}
var font_resolution: Dictionary = {}
var textures: Dictionary = {}
var atlas: Dictionary = {"regions": {
	"panel_frame":{"file":"ui-ornaments.png","rect":[24,24,1488,300],"margin":84},
	"button_normal":{"file":"ui-ornaments.png","rect":[24,24,1488,300],"margin":84},
	"button_hover":{"file":"ui-ornaments.png","rect":[24,365,1488,300],"margin":84},
	"button_selected":{"file":"ui-ornaments.png","rect":[24,706,1488,300],"margin":84}
}}
var selected_world: int = 3
var current_mode: String = "world"
var modal_kind: String = ""
var return_focus: Control
var root_ready: bool = false
var interaction_log: Array[String] = []
var current_prayer: int = -1
var current_variant: String = ""
var keyboard_input: bool = false
var modal_return_keyboard: bool = false
var remembered_prayer_variants: Dictionary = {}
var fixture_state: Dictionary = {"turn":46,"whispers":5,"faith":18,"capacity":125,"awakening":65,"cults":12,"relics":18,"worlds":12}

func _ready() -> void:
	get_window().title = "幽界群像 · 还原与布局调整 · 人工T46（F1图层 / F2对照）"
	get_window().content_scale_size = Vector2i(1672,941)
	get_window().size = Vector2i(1672,941)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	catalog = Catalog.new()
	if not catalog.load_files():
		push_error("Echoes art master: formal CSV catalog failed to load")
		return
	var regular:Font=preload("res://tools/echoes-art-master/restoration_font.gd").regular()
	fonts={"body":regular,"heading":regular}
	font_resolution={"body":{"resolved":regular.get_font_name(),"style":regular.get_font_style_name(),"supports_yuan":regular.has_char("远".unicode_at(0))},"heading":{"resolved":regular.get_font_name(),"style":regular.get_font_style_name()}}
	var base := Theme.new()
	base.default_font = fonts.heading
	base.default_font_size = 20
	base.set_color("font_color","Label",BONE)
	theme = base
	if FileAccess.file_exists(ROOT_ASSETS + "atlas.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT_ASSETS + "atlas.json"))
		if parsed is Dictionary: atlas = parsed
	_layout_regions()
	_build_world()
	_build_top()
	_build_world_index()
	_build_context()
	_build_prayers()
	_build_chronicle()
	_build_dock()
	_build_layer_inspector()
	root_ready = true

func _rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _texture(path: String) -> Texture2D:
	if textures.has(path): return textures[path]
	if not FileAccess.file_exists(path): return null
	var image := Image.new()
	if image.load(path) != OK: return null
	var texture := ImageTexture.create_from_image(image)
	textures[path] = texture
	return texture

func _atlas_texture(key: String) -> Texture2D:
	var regions: Dictionary = atlas.get("regions", {})
	if not regions.has(key): return null
	var entry: Dictionary = regions[key]
	var source: Texture2D = _texture(ROOT_ASSETS + str(entry.get("file", "ui-ornaments.png")))
	if source == null: return null
	var coords: Array = entry.get("rect", [])
	if coords.size() != 4: return null
	var region := AtlasTexture.new()
	region.atlas = source
	region.region = Rect2(float(coords[0]),float(coords[1]),float(coords[2]),float(coords[3]))
	return region

func _power_grid_texture(key: String) -> Texture2D:
	var index: int = POWER_ICONS.find(key)
	if index < 0: return null
	var grid: Dictionary = atlas.get("power_grid",{})
	var source: Texture2D = _texture(ROOT_ASSETS + str(grid.get("file","power-sigils.png")))
	if source == null: return null
	var columns: int = int(grid.get("columns",4))
	var rows: int = int(grid.get("rows",3))
	if columns < 1 or rows < 1 or index >= columns*rows: return null
	var cell := Vector2(float(source.get_width())/columns,float(source.get_height())/rows)
	var region := AtlasTexture.new()
	region.atlas = source
	region.region = Rect2(Vector2(index%columns,index/columns)*cell,cell)
	return region

func _image(parent: Node, title: String, rect: Rect2, texture: Texture2D, tint: Color = Color.WHITE, stretch: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var image := TextureRect.new()
	image.name = title
	_rect(image,rect)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = stretch
	image.texture = texture
	image.modulate = tint
	parent.add_child(image)
	return image

func _icon(parent: Node, title: String, key: String, rect: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var tex: Texture2D = skin.icon(key)
	if tex == null: tex = _atlas_texture("power_" + key)
	if tex == null: tex = _texture(LOCAL + "icons/" + key + ".svg")
	var item:=_image(parent,title,rect,tex,tint)
	if tex is AtlasTexture and key!="cult_selected":
		var shader:=Shader.new()
		if key == "seizure":
			shader.code="shader_type canvas_item;uniform vec4 icon_tint: source_color=vec4(1.0);void fragment(){vec4 c=texture(TEXTURE,UV);float a=smoothstep(0.24,0.58,c.r);COLOR=vec4(c.rgb,a*c.a)*icon_tint;}"
		else:
			shader.code="shader_type canvas_item;uniform vec4 icon_tint: source_color=vec4(1.0);void fragment(){vec4 c=texture(TEXTURE,UV);float a=smoothstep(0.04,0.16,max(c.r,max(c.g,c.b)));COLOR=vec4(c.rgb,a*c.a)*icon_tint;}"
		var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("icon_tint",tint);item.material=material
	return item

func _label(parent: Node, title: String, text_value: String, rect: Rect2, font_size: int = 20, color: Color = BONE, heading: bool = false, wrap: bool = false) -> Label:
	var item := Label.new()
	item.name = title
	_rect(item,rect)
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

func _fill(parent: Node, title: String, rect: Rect2, color: Color) -> ColorRect:
	var item := ColorRect.new()
	item.name = title
	_rect(item,rect)
	item.color = color
	parent.add_child(item)
	return item

func _gradient(parent: Node, title: String, rect: Rect2, top: Color, bottom: Color, horizontal: bool = false) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([top,bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2(1,0) if horizontal else Vector2(0,1)
	return _image(parent,title,rect,tex,Color.WHITE,TextureRect.STRETCH_SCALE)

func _separator(parent: Node, title: String, rect: Rect2, kind: String) -> TextureRect:
	# Extract only the warm, two-pixel metal seam from the auxiliary reference;
	# the transparent fringe keeps its original uneven wear without baking the
	# reference scene into the UI. Each edge samples a different source seam.
	var key := "separator:"+kind
	if not textures.has(key):
		var reference: Image = _texture(SOURCE_OVERFLOW).get_image()
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
	return _image(parent,title,rect,textures[key],Color.WHITE,TextureRect.STRETCH_TILE)

func _soft_support(parent: Node, title: String, rect: Rect2, tint: Color) -> ColorRect:
	var support := _fill(parent,title,rect,tint)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { float x = smoothstep(0.0,0.16,UV.x)*(1.0-smoothstep(0.84,1.0,UV.x)); float y = smoothstep(0.0,0.24,UV.y)*(1.0-smoothstep(0.76,1.0,UV.y)); COLOR.a *= x*y; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	support.material = material
	return support

func _frame(parent: Node, title: String, rect: Rect2, region: String = "group", _thickness: int = 0) -> Control:
	var frame := Panel.new()
	frame.name=title
	_rect(frame,rect)
	frame.add_theme_stylebox_override("panel",skin.frame(region))
	parent.add_child(frame)
	return frame

func _panel(parent: Node, title: String, rect: Rect2, opacity: float = 0.92, _ornament: bool = false) -> Control:
	var panel := Panel.new()
	panel.name=title
	_rect(panel,rect)
	var surface := StyleBoxFlat.new()
	surface.bg_color=Color(0.012,0.023,0.026,opacity)
	surface.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",surface)
	parent.add_child(panel)
	return panel

func _button_style(state: String, bone: bool = false, quiet: bool = false) -> StyleBox:
	return skin.style("quiet" if quiet else ("primary" if bone else "dark"),state)

func _unframed_style(state: String, dark_action: bool = false) -> StyleBox:
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

func _transparent_button(button: Button) -> void:
	# Preserve focus and a restrained hover without resurrecting the normal frame.
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	for state: String in ["hover", "pressed"]:
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color(0.64,0.55,0.38,0.09 if state == "hover" else 0.16)
		surface.set_corner_radius_all(roundi(minf(button.size.x,button.size.y)*0.48))
		button.add_theme_stylebox_override(state,surface)

func _button(parent: Node, title: String, text_value: String, rect: Rect2, callback: Callable, bone: bool = false, quiet: bool = false, font_size: int = 20) -> Button:
	var button := Button.new()
	button.name = title
	_rect(button,rect)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font",fonts.heading)
	button.add_theme_font_size_override("font_size",font_size)
	button.add_theme_color_override("font_color",Color("272219") if bone else GOLD)
	button.add_theme_color_override("font_hover_color",Color("211e17") if bone else Color("ffe6b3"))
	button.add_theme_color_override("font_pressed_color",Color("211e17") if bone else GOLD)
	button.add_theme_color_override("font_focus_color",Color("211e17") if bone else BONE)
	var dock_control: bool = parent == $Interface/Dock or $Interface/Dock.is_ancestor_of(parent)
	var top_control: bool = parent == $Interface/TopBar or $Interface/TopBar.is_ancestor_of(parent)
	for state: String in ["normal","hover","pressed","focus"]:
		var old_style: bool = dock_control or top_control or (bone and state != "focus")
		button.add_theme_stylebox_override(state,_button_style(state,bone,quiet) if old_style else _unframed_style(state,not quiet))
	button.pressed.connect(callback)
	button.focus_entered.connect(func(): _sync_focus_style(button))
	parent.add_child(button)
	return button

func _sync_focus_style(button: Button) -> void:
	if keyboard_input:
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

func _build_world() -> void:
	$World/Background.texture=_texture(RESTORED+"sea-mist.png")
	# Source contains no UI in this crop. Preserve the actual painted place and
	# its local atmosphere; edge blending is independent of the UI and sea.
	$World/Sanctuary.texture=_source_region(Rect2(480,270,610,264))
	$World/Sanctuary.material=_fragment_material(Rect2(480,270,610,264),0.12,1.0)
	var fragments: Array=[Rect2(335,192,149,113),Rect2(1113,274,143,88),Rect2(1345,465,179,108),Rect2(267,464,121,88)]
	for i: int in range(fragments.size()):
		var fragment:=_image($World/DistantFragments,"Contact_%d"%i,fragments[i],_source_region(fragments[i]))
		fragment.material=_fragment_material(fragments[i],0.30,0.78)
	_create_fog("DistantFog",Rect2(245,125,1427,430),0.08,3.0)
	_create_fog("ForegroundFog",Rect2(245,450,1427,355),0.055,7.0)
	_gradient($Interface/ReadingSupport,"LeftShade",Rect2(0,50,265,750),Color(0,0.005,0.008,0.75),Color(0,0.005,0.008,0.03),true)
	_gradient($Interface/ReadingSupport,"TopShade",Rect2(0,0,1672,170),Color(0,0.008,0.012,0.38),Color(0,0.008,0.012,0))

func _fragment_material(region:Rect2,feather:float, strength:float) -> ShaderMaterial:
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
	material.set_shader_parameter("tile_rect",Vector4(region.position.x/VIEW.x,region.position.y/VIEW.y,region.size.x/VIEW.x,region.size.y/VIEW.y))
	material.set_shader_parameter("feather",feather)
	material.set_shader_parameter("strength",strength)
	return material

func _create_fog(title: String, rect: Rect2, amount: float, seed_value: float) -> void:
	var fog := _fill($World/Atmosphere,title,rect,Color.WHITE)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float opacity = 0.08;
uniform float seed_offset = 3.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);}
void fragment(){vec2 p=UV*vec2(5.0,17.0)+vec2(seed_offset);float n=noise(p)*0.62+noise(p*2.1)*0.26+noise(p*4.2)*0.12;float edge=smoothstep(0.0,0.2,UV.y)*(1.0-smoothstep(0.75,1.0,UV.y));COLOR=vec4(vec3(0.26,0.42,0.46),max(0.0,n-0.35)*opacity*edge);}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("opacity",amount)
	material.set_shader_parameter("seed_offset",seed_value)
	fog.material = material

func set_layer_visible(path: String, value: bool) -> void:
	var layer: CanvasItem = get_node_or_null(path)
	if layer != null:
		layer.visible = value
		interaction_log.append("layer:%s:%s"%[path,value])

func _build_top() -> void:
	var box:Control=$Interface/TopBar
	_clear(box)
	_fill(box,"TopMaterial",Rect2(0,0,1672,31),Color(0.008,0.018,0.020,0.79))
	_gradient(box,"TopFade",Rect2(0,31,1672,26),Color(0.008,0.018,0.020,0.79),Color(0.008,0.018,0.020,0.0))
	_separator(box,"TopEdge",Rect2(0,46,1672,6),"top")
	_label(box,"Turn","第46回合 ·",Rect2(29,4,108,41),22,BONE,true)
	_label(box,"Phase","神意行动",Rect2(138,4,114,41),22,GOLD,true)
	var resources:Array=[["whispers","低语","5/5",281,315,366],["faith","信仰","18/125",447,481,532],["awakening","苏醒",str(fixture_state.awakening),635,680,731]]
	for item:Array in resources:
		_icon(box,str(item[0])+"Icon",item[0],Rect2(item[3],8,29,31))
		_label(box,str(item[0])+"Label",item[1],Rect2(item[4],3,52,42),21,BONE,true)
		_label(box,str(item[0])+"Value",item[2],Rect2(item[5],3,92,42),24,BONE,true)
	_button(box,"CultsIndex","教团 12",Rect2(945,7,90,36),show_cult_stage,false,true,20)
	_button(box,"RelicsIndex","圣物 %d"%int(fixture_state.relics),Rect2(1040,7,90,36),open_relics,false,true,20)
	_button(box,"WorldIndex","世界档案 12",Rect2(1137,7,135,36),func(): open_info("世界档案","已知世界包含尚无教团或锚点的世界；本单场景不展开全部业务页面。"),false,true,20)
	_button(box,"PeopleIndex","人物",Rect2(1280,7,64,36),func(): open_info("人物","具名人物与无名信众分别计数；正式原型保留全部成员入口。"),false,true,20)
	_button(box,"FocusCapacity","关注世界 3/3",Rect2(1350,7,160,36),func(): open_info("关注与名额","查看与定位不自动改变机制关注。"),false,true,20)
	_button(box,"Income","收支",Rect2(1515,7,63,36),func(): open_info("收支","低语5，信仰18/125。当前是人工展示局面；正式原型提供实际收支。"),false,true,19)
	_button(box,"Deity","本体",Rect2(1583,7,66,36),func(): open_info("本体","当前展示苏醒65；降临需苏醒90。"),false,true,19)
	for node:Node in box.get_children():
		if node is Button:
			_transparent_button(node)
			node.add_theme_color_override("font_color",BONE)
			_fill(box,"NavDivider"+str(node.name),Rect2(node.position.x-4,16,1,19),Color(0.40,0.35,0.26,0.65))

# The index is a display fixture: only entries 02 and 04 have associated
# observation data. Other entries remain selectable but their data is unknown.
const WORLD_CONTACTS: Array[Dictionary] = [
	{"id":1,"name":"盐梦02","hint":"祭日祈求 · 第48轮", "art":"sela.png"},
	{"id":3,"name":"镜证04","hint":"已知教团 · 传教中", "art":"mirror"},
	{"id":5,"name":"千面06","hint":"祈求 · 本轮到期", "art":"mila.png"}
]

func _world_row_style(state: String, selected: bool) -> StyleBox:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.22,0.17,0.10,0.68) if selected else Color(0.015,0.035,0.038,0.68)
	if state == "hover": surface.bg_color = Color(0.19,0.16,0.10,0.76)
	elif state == "pressed": surface.bg_color = Color(0.27,0.22,0.13,0.82)
	surface.set_corner_radius_all(4)
	return surface

func _build_world_index() -> void:
	var box: Control = $Interface/WorldIndex
	_clear(box)
	_gradient(box,"IndexSupport",Rect2(-18,-5,316,560),Color(0.015,0.031,0.034,0.78),Color(0.015,0.031,0.034,0.0),true)
	_label(box,"Heading","世界",Rect2(12,2,110,42),30,GOLD,true)
	_label(box,"Scope","已建立联系 · 展示",Rect2(112,10,175,30),17,MUTED)
	var search := LineEdit.new()
	search.name="SearchWorlds"; _rect(search,Rect2(8,51,272,37)); search.mouse_filter=Control.MOUSE_FILTER_STOP
	search.placeholder_text="查找已联系世界"; search.add_theme_font_override("font",fonts.heading); search.add_theme_font_size_override("font_size",18)
	search.add_theme_color_override("font_placeholder_color",Color("a9a69a"))
	var field:StyleBox=_unframed_style("normal"); field.set_content_margin(SIDE_LEFT,34)
	search.add_theme_stylebox_override("normal",field); search.add_theme_stylebox_override("focus",_unframed_style("focus"))
	box.add_child(search); search.text_changed.connect(_filter_worlds)
	_icon(box,"SearchIcon","search",Rect2(18,58,22,22))
	var scroll:=ScrollContainer.new(); scroll.name="WorldScroll"; _rect(scroll,Rect2(4,101,282,373))
	scroll.mouse_filter=Control.MOUSE_FILTER_STOP; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO; scroll.follow_focus=true; box.add_child(scroll)
	var list:=VBoxContainer.new(); list.name="WorldList"; list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8); scroll.add_child(list)
	for contact:Dictionary in WORLD_CONTACTS:
		var id:int=contact.id
		var row:=_button(list,"World_%02d"%(id+1),"",Rect2(0,0,270,96),func(): show_world(id),false,true)
		row.custom_minimum_size=Vector2(0,96); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.set_meta("search_text",str(contact.name))
		var tex:Texture2D=_source_region(Rect2(480,270,610,264)) if contact.art=="mirror" else _texture(RESTORED+"prayer-scenes/"+str(contact.art))
		_image(row,"Portrait",Rect2(0,0,91,96),tex,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		_gradient(row,"PortraitFade",Rect2(70,0,32,96),Color(0.02,0.033,0.032,0),Color(0.02,0.033,0.032,0.83),true)
		_label(row,"Name",str(contact.name),Rect2(105,8,156,31),22,GOLD_HI,true)
		_label(row,"Hint",str(contact.hint),Rect2(105,44,162,28),17,RISK if id==5 else BONE)
		_label(row,"Tag","概念示意",Rect2(105,70,142,23),14,MUTED)
	_label(box,"Count","3处联系 · 展示",Rect2(12,482,240,32),17,MUTED)
	_filter_worlds("")

func _filter_worlds(query:String) -> void:
	var list:VBoxContainer=$Interface/WorldIndex/WorldScroll/WorldList
	var matches:=0
	for row:Node in list.get_children():
		row.visible=query.strip_edges().is_empty() or str(row.get_meta("search_text")).findn(query.strip_edges())>=0
		if row.visible: matches+=1
	$Interface/WorldIndex/WorldScroll.scroll_vertical=0
	$Interface/WorldIndex/Count.text=("无匹配 · 展示" if matches==0 else "%d处联系 · 展示"%matches)
	_refresh_world_rows()

func _refresh_world_rows() -> void:
	var list:VBoxContainer=$Interface/WorldIndex/WorldScroll/WorldList
	for contact:Dictionary in WORLD_CONTACTS:
		var row:Button=list.get_node("World_%02d"%(int(contact.id)+1))
		var selected:bool=int(contact.id)==selected_world and current_mode in ["world","cult"]
		for state:String in ["normal","hover","pressed"]: row.add_theme_stylebox_override(state,_world_row_style(state,selected))
		row.add_theme_stylebox_override("focus",_unframed_style("focus"))
		row.get_node("Name").add_theme_color_override("font_color",GOLD_HI if selected else BONE)

func show_world(index:int) -> void:
	if not WORLD_CONTACTS.any(func(contact:Dictionary)->bool: return int(contact.id)==index): return
	set_meta("s1_read", "")
	set_meta("s1_roster", false)
	selected_world=index
	current_mode="world"
	current_prayer=-1
	interaction_log.append("world:%d"%index)
	$Interface/PrimaryStage.hide()
	$Interface/WorldContext.show()
	_refresh_world_rows()
	_build_context()
	_build_prayers()

func show_prayer_stage(index:int,variant:String="") -> void:
	if index<0 or index>=PRAYERS.size(): return
	if variant.is_empty(): variant=str(remembered_prayer_variants.get(index,"shallow"))
	if variant not in ["shallow","deep"]: return
	remembered_prayer_variants[index]=variant
	current_mode="prayer"
	current_prayer=index
	current_variant=variant
	interaction_log.append("prayer:%d:%s"%[index,variant])
	$World/Sanctuary.modulate.a=0.0
	$Interface/WorldContext.hide()
	var stage:Control=$Interface/PrimaryStage
	_clear(stage)
	stage.show()
	load("res://tools/echoes-art-master/prayer_stage.gd").build(self,stage,index,variant)
	_refresh_world_rows()
	_build_prayers()

func show_prayer_person(index:int, possessions:bool=false) -> void:
	if index<0 or index>=PRAYERS.size(): return
	current_mode="prayer_person_item" if possessions else "prayer_person"
	current_prayer=index
	interaction_log.append("prayer_person:%d:%s"%[index,"possessions" if possessions else "person"])
	$World/Sanctuary.modulate.a=0.0
	$Interface/WorldContext.hide()
	var stage:Control=$Interface/PrimaryStage
	_clear(stage)
	stage.show()
	load("res://tools/echoes-art-master/prayer_stage.gd").build_related(self,stage,index,possessions)
	_refresh_world_rows()
	_build_prayers()

func return_to_prayer() -> void:
	if current_prayer>=0: show_prayer_stage(current_prayer)

func close_prayer_stage() -> void:
	var closed_index:int=current_prayer
	show_world(selected_world)
	var card:Control=$Interface/Prayers.get_node_or_null("PrayerCard_%d"%closed_index)
	if card!=null: card.grab_focus()

func show_cult_stage() -> void:
	current_mode="cult"
	current_prayer=-1
	interaction_log.append("cult_view:%d"%selected_world)
	$Interface/WorldContext.hide()
	$World/Sanctuary.modulate.a=1.0 if selected_world==3 else 0.0
	var stage:Control=$Interface/PrimaryStage
	_clear(stage)
	stage.show()
	load("res://tools/echoes-art-master/cult_stage.gd").build(self,stage)
	_refresh_world_rows()
	_build_prayers()


func _build_context() -> void:
	var box:Control=$Interface/WorldContext
	_clear(box)
	var names: Dictionary = {1:"盐梦02",3:"镜证议会 · 04",5:"千面06"}
	var known_fixture:bool=selected_world in [1,3]
	# Only the current master scene has a sanctuary image. Do not attach it to
	# a different selected cult merely because its name changed.
	$World/Sanctuary.modulate.a = 1.0 if selected_world == 3 else 0.0
	var values:Array[String]=["未掌握","未掌握","未掌握","未掌握"]
	if selected_world==3:values=["28","50–74","50–74","50–74"]
	elif selected_world==1:values=["50","25–49","25–49","75–100"]
	# Current cult identity and its actions share a local, fading support over the sanctuary.
	_soft_support(box,"SubjectSupport",Rect2(290,344,635,124),Color(0.008,0.016,0.018,0.70))
	_icon(box,"WorldSigil","world",Rect2(324,359,48,48))
	_label(box,"WorldName",names[selected_world],Rect2(380,353,300,35),24,GOLD_HI,true)
	_label(box,"CultNumbers","信众 64   ·   凝聚 70" if selected_world==3 else "此世界的教团信息未配置",Rect2(380,390,300,30),19,BONE if selected_world==3 else MUTED,true)
	_label(box,"CultActivity","传教中" if selected_world==3 else "世界场所未配置 · 展示",Rect2(380,420,310,27),18,GOLD if selected_world==3 else MUTED,true)
	var world_title:String="镜证04 · 世界观察" if selected_world==3 else ("盐梦02 · 世界观察" if selected_world==1 else "千面06 · 观察未配置")
	_label(box,"WorldMetricsTitle",world_title,Rect2(0,7,260,44),19,MUTED,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_soft_support(box,"WorldBand",Rect2(266,-4,748,76),Color(0.008,0.020,0.023,0.80))
	var metrics:Array=[["barrier","屏障"],["pollution","污染"],["alert","察觉"],["stability","稳定"]]
	for i:int in range(4):
		var x:float=293+i*179
		_icon(box,"MetricIcon_%d"%i,metrics[i][0],Rect2(x,11,37,39))
		_label(box,"MetricName_%d"%i,metrics[i][1],Rect2(x+43,2,48,32),21,GOLD,true)
		_label(box,"MetricValue_%d"%i,values[i],Rect2(x+93,2,90,32),22,GOLD if known_fixture else MUTED,true)
		_label(box,"MetricSource_%d"%i,("45轮确知" if i==0 else "45轮估计") if known_fixture else "未有记录",Rect2(x+43,34,135,26),19,MUTED,true)
	var warning:=Control.new()
	warning.name="ResistanceBand"; _rect(warning,Rect2(276,75,728,38)); box.add_child(warning)
	_soft_support(warning,"RiskSupport",Rect2(-12,-5,752,48),Color(0.12,0.022,0.018,0.86))
	var resistance:String="反制展示未配置"
	if selected_world==3:resistance="清洗教团 · 第47轮末　　目标：镜证04的教团　　无名信众−20% · 凝聚−10"
	elif selected_world==1:resistance="查证异常 · 第47轮末　　目标：祭司塞拉　　普通匿名保护失效"
	_icon(warning,"WarningIcon","countermeasure",Rect2(17,7,27,24))
	_label(warning,"Resistance",resistance,Rect2(50,0,670,38),18,RISK if known_fixture else MUTED,true)
	_button(box,"AnchorStatus","有效锚点 1    ·     供奉缺口 1" if selected_world==3 else "锚点与供奉 · 展示未配置",Rect2(276,120,320,37),func(): open_info("锚点与供奉","镜证04：1个有效锚点及1个供奉缺口。展示记录。" if selected_world==3 else names[selected_world]+"：本展示未配置该世界的锚点与供奉记录，不能借用镜证04的数量。"),false,true,19)
	_button(box,"ObservationSource","来源 / 观测记录",Rect2(828,120,176,37),func(): open_info("世界观察来源","第45轮观察。确知、估计与未掌握分别保留；不是当前实时扫描。" if known_fixture else "暂无此世界的已掌握观察。"),false,true,18)
	box.get_node("AnchorStatus").alignment=HORIZONTAL_ALIGNMENT_RIGHT
	box.get_node("ObservationSource").alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if selected_world==3:
		_icon(box,"AnchorIcon","anchor_status",Rect2(291,126,24,26))
		_icon(box,"OfferingIcon","offering",Rect2(450,126,24,25))
	_icon(box,"SourceIcon","source_book",Rect2(839,127,26,23))
	if selected_world==3:
		var mx:float=690
		var my:float=384
		_button(box,"ManageCult","管理教团",Rect2(mx,my,174,46),show_cult_stage,false,false,22)
		_icon(box,"ManagementIcon","management",Rect2(mx+12,my+9,38,26))
		box.get_node("ManageCult").alignment=HORIZONTAL_ALIGNMENT_RIGHT

const PRAYER_SCENES: Array[String] = ["mila.png","sela.png","ivan.png"]

func _build_prayers() -> void:
	var box:Control=$Interface/Prayers
	_clear(box)
	_soft_support(box,"PrayerSupport",Rect2(-12,-8,394,530),Color(0.005,0.018,0.021,0.83))
	_label(box,"PrayersTitle","待处理祈求",Rect2(16,0,230,38),25,GOLD_HI,true)
	_label(box,"Opportunity","本轮可回应一次",Rect2(16,36,270,27),17,MUTED)
	var order:Array[int]=[1,2,0]
	for row:int in range(order.size()):
		var i:int=order[row]
		var fixture:Dictionary=PRAYERS[i]
		var definition:Dictionary=catalog.tables.prayers[fixture.id]
		var card:=_button(box,"PrayerCard_%d"%i,"",Rect2(8,72+row*120,354,112),func(): show_prayer_stage(i),false,true)
		var active:bool=current_mode.begins_with("prayer") and current_prayer==i
		for state:String in ["normal","hover","pressed"]: card.add_theme_stylebox_override(state,_world_row_style(state,active))
		card.add_theme_stylebox_override("focus",_unframed_style("focus"))
		var picture:=_image(card,"SceneImage",Rect2(0,0,105,112),_texture(RESTORED+"prayer-scenes/"+PRAYER_SCENES[i]),Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		picture.material=_fragment_material(Rect2(0,0,1672,941),0.10,1.0)
		_label(card,"Person",fixture.person+" · "+fixture.role,Rect2(116,4,223,27),19,BONE,true)
		var kind:String=str({"rescue":"救助","knowledge":"求证","belonging":"仪式"}.get(str(definition.need),"祈求"))
		_label(card,"Kind",kind+" · "+str(fixture.world),Rect2(116,33,224,25),17,CYAN)
		_label(card,"Title",str(definition.title),Rect2(116,59,224,26),19,GOLD_HI,true)
		_label(card,"Due",fixture.due,Rect2(116,85,224,23),16,RISK if i==0 else MUTED)
	var notice:=Control.new(); notice.name="OtherWorldNotice"; _rect(notice,Rect2(8,448,354,54)); box.add_child(notice)
	_soft_support(notice,"RiskFade",Rect2(-5,-3,364,60),Color(0.15,0.018,0.014,0.83))
	_icon(notice,"NoticeIcon","seizure",Rect2(12,4,47,47))
	_button(notice,"Notice","焚星10：本轮末扣押空名印 ›",Rect2(51,4,295,46),func(): open_info("扣押预告","第46轮，焚星10的扣押预告。展示记录不代表本次浏览触发行动。"),false,true,18)
	_transparent_button(notice.get_node("Notice"))
	_label(box,"ArtScope","画面为场景概念示意 · 展示夹具",Rect2(17,508,320,27),15,MUTED)


func _build_chronicle() -> void:
	var box:Control=$Interface/Chronicle
	_clear(box)
	# The shared dock surface sits underneath; only the text and hit area live here.
	var history:=_button(box,"History","",Rect2(16,0,155,40),open_chronicle,false,true)
	history.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	_icon(box,"HistoryIcon","history",Rect2(24,7,27,25))
	_label(box,"HistoryLabel","编年史",Rect2(60,0,105,40),20,GOLD,true)
	_label(box,"Record","45轮 盐梦02：仪式见证留存　 ·　 46轮 焚星10：扣押预告",Rect2(203,0,1210,40),20,BONE,true)

func _build_dock() -> void:
	var box: Control = $Interface/Dock
	_clear(box)
	# One continuous surface serves both the scrollable collections and history.
	_fill(box,"DockMaterial",Rect2(Vector2.ZERO,box.size),Color(0.006,0.016,0.018,0.78))
	_separator(box,"DockUpperEdge",Rect2(0,0,box.size.x,6),"dock_top")
	_separator(box,"DockLowerEdge",Rect2(0,box.size.y-6,box.size.x,6),"dock_bottom")
	DockContent.build(self,box,Rect2(0,0,1445,128))
	var action: Button = RoundAction.new()
	action.name = "EndTurn"
	action.keyboard_focus_query = func() -> bool: return keyboard_input
	_rect(action,Rect2(1450,19,222,150))
	action.mouse_filter = Control.MOUSE_FILTER_STOP
	action.focus_mode = Control.FOCUS_ALL
	action.pressed.connect(func(): open_info("轮末确认","本轮仍有祈求可回应。本美术样板不支付、不推进正式回合。"))
	box.add_child(action)

func _dialog_focus_targets(dialog: Control) -> Array[Control]:
	var targets: Array[Control] = []
	for node: Node in dialog.find_children("*", "Control", true, false):
		if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
			if node is BaseButton and node.disabled: continue
			targets.append(node)
	return targets

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		var is_escape: bool = event is InputEventKey and event.keycode == KEY_ESCAPE
		if not is_escape:
			keyboard_input = event is InputEventKey
			if $PreviewLayer.visible: modal_return_keyboard = keyboard_input
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button: _sync_focus_style(focus)
		if focus is Button: focus.queue_redraw()
	# PreviewLayer is a mouse shield, but the scene tree still contains the
	# underlying focusable controls. Keep keyboard traversal inside the dialog.
	if not $PreviewLayer.visible or not (event is InputEventKey) or not event.pressed:
		return
	var dialog: Control = $PreviewLayer.get_node_or_null("Dialog")
	if dialog == null: return
	if event.keycode == KEY_TAB and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var targets := _dialog_focus_targets(dialog)
		if not targets.is_empty():
			var current := targets.find(get_viewport().gui_get_focus_owner())
			var next := (current - 1 if event.shift_pressed else current + 1)
			if current < 0: next = targets.size() - 1 if event.shift_pressed else 0
			targets[posmod(next, targets.size())].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not dialog.is_ancestor_of(focused):
			dialog.get_node("ClosePreview").grab_focus()
			get_viewport().set_input_as_handled()
		elif focused is Button:
			# Button arrow navigation may otherwise find a nearer control below the
			# overlay. Use directional geometry among dialog controls only.
			var direction := Vector2.ZERO
			match event.keycode:
				KEY_UP: direction = Vector2.UP
				KEY_DOWN: direction = Vector2.DOWN
				KEY_LEFT: direction = Vector2.LEFT
				KEY_RIGHT: direction = Vector2.RIGHT
			var best: Control = focused
			var best_score := INF
			var origin := focused.get_global_rect().get_center()
			for target: Control in _dialog_focus_targets(dialog):
				if target == focused: continue
				var delta := target.get_global_rect().get_center() - origin
				var forward := delta.dot(direction)
				if forward <= 1.0: continue
				var score := forward + absf(delta.cross(direction)) * 1.8
				if score < best_score:
					best = target
					best_score = score
			best.grab_focus()
			get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not dialog.is_ancestor_of(focused):
			dialog.get_node("ClosePreview").grab_focus()
			get_viewport().set_input_as_handled()

func _modal(title: String, kind: String, height: float = 620) -> Control:
	if current_mode.begins_with("prayer"): show_world(selected_world)
	var layer: Control = $PreviewLayer
	if not layer.visible:
		return_focus = get_viewport().gui_get_focus_owner()
		modal_return_keyboard = keyboard_input
	_clear(layer)
	layer.visible = true
	modal_kind = kind
	_fill(layer,"Backdrop",Rect2(0,0,1672,941),Color(0.0,0.012,0.02,0.64))
	var box := _panel(layer,"Dialog",Rect2(356,(941-height)/2,960,height),0.93,true)
	_label(box,"Heading",title,Rect2(34,21,820,47),28,GOLD,true)
	var close := _button(box,"ClosePreview","×",Rect2(878,22,48,42),close_modal,false,true,28)
	close.grab_focus()
	interaction_log.append("open:"+kind)
	return box

func close_modal() -> void:
	$PreviewLayer.hide()
	modal_kind = ""
	interaction_log.append("close")
	keyboard_input = modal_return_keyboard
	if is_instance_valid(return_focus) and return_focus.is_inside_tree(): return_focus.grab_focus()

func open_prayer(index: int, variant: String) -> void:
	show_prayer_stage(index,variant)

func open_power(id: String) -> void:
	var power: Dictionary = catalog.tables.powers[id]
	var box := _modal(str(power.name),"power",480)
	var locked: bool=int(power.unlock_awakening)>int(fixture_state.awakening)
	_label(box,"Availability","尚未解锁 · 需要苏醒 %s（当前%s）"%[power.unlock_awakening,fixture_state.awakening] if locked else "%s低语 · %s信仰"%[power.whispers,power.faith],Rect2(36,109,880,42),23,RISK if locked else GOLD,true)
	_label(box,"Requirement","条件　"+str(power.target_requirement),Rect2(36,171,880,80),20,BONE,false,true)
	_label(box,"Description","作用　"+str(power.success),Rect2(36,271,880,85),20,BONE,false,true)
	_button(box,"ReturnToPowers","返回",Rect2(724,395,200,48),close_modal,true)

func open_relics() -> void:
	var total: int = maxi(0,int(fixture_state.relics))
	var box := _modal("圣物 · 当前%d件"%total,"relics",650)
	_label(box,"InventoryScope","当前持有与历史记录分开；以下为人工展示实例。",Rect2(36,95,890,34),20,MUTED)
	var scroll := ScrollContainer.new()
	scroll.name="InventoryScroll"
	_rect(scroll,Rect2(35,145,890,410))
	scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	var item_ids: Array[String] = ["RELIC_ROOT_NAIL","RELIC_ECHO_BELL","RELIC_HOLLOW_SEAL","RELIC_WITNESS_LENS","RELIC_LIVING_SCRIPT","RELIC_LAST_EMBER"]
	if total == 0:
		var empty:=Label.new()
		empty.text="尚无圣物 · 这是展示夹具"
		empty.add_theme_color_override("font_color",MUTED)
		list.add_child(empty)
	for i: int in range(total):
		var row:=HBoxContainer.new()
		row.custom_minimum_size.y=42
		list.add_child(row)
		var name_label:=Label.new()
		name_label.text = "%s  R%02d"%[catalog.tables.relics[item_ids[i%item_ids.size()]].name,i+1]
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color",GOLD)
		row.add_child(name_label)
		var state_label:=Label.new()
		state_label.text = ["绑定","携带","携带","保管"][i] if i < 4 else ("绑定" if i%4==0 else ("保管" if i%3==0 else "携带"))
		state_label.custom_minimum_size.x=125
		row.add_child(state_label)
	_button(box,"ReturnToRelics","返回",Rect2(724,574,200,46),close_modal,true)

func open_info(title: String, body: String) -> void:
	var box := _modal(title,"info",360)
	_label(box,"Content",body,Rect2(36,105,885,140),22,BONE,false,true)
	_button(box,"ReturnFromInfo","返回",Rect2(724,274,200,46),close_modal,true)

func open_chronicle() -> void:
	var box := _modal("编年史","chronicle",430)
	_label(box,"Scope","展示记录 · 尚未接入实际 Session",Rect2(36,96,850,35),19,MUTED)
	_label(box,"Entry45","第45轮　盐梦02 · 仪式见证留存",Rect2(36,155,850,44),22,BONE)
	_label(box,"Entry46","第46轮　焚星10 · 扣押预告",Rect2(36,216,850,44),22,BONE)
	_button(box,"ReturnFromChronicle","返回",Rect2(724,344,200,46),close_modal,true)

func _build_layer_inspector() -> void:
	var layer := _panel($FeedbackLayer,"LayerInspector",Rect2(1160,196,480,520),0.99)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(layer,"Heading","分层检查 · F1关闭",Rect2(28,18,424,42),25,GOLD,true)
	var paths: Array[String] = ["World/Background","World/Sanctuary","World/Atmosphere/DistantFog","World/Atmosphere/ForegroundFog","Interface","World/DistantFragments"]
	var names: Array[String] = ["深渊海面","教团场所","远雾","前雾","原生界面与文字","远处现实联系"]
	for i: int in range(paths.size()):
		var toggle := CheckButton.new()
		toggle.name = "LayerToggle_%d"%i
		_rect(toggle,Rect2(28,78+i*57,424,48))
		toggle.mouse_filter=Control.MOUSE_FILTER_STOP
		toggle.text=names[i]
		toggle.button_pressed=true
		toggle.add_theme_font_override("font",fonts.body)
		toggle.add_theme_font_size_override("font_size",21)
		layer.add_child(toggle)
		toggle.toggled.connect(func(enabled:bool): set_layer_visible(paths[i],enabled))
	_label(layer,"Scope","仅切换画面层；不改变游戏规则。",Rect2(28,448,424,40),18,MUTED)
	layer.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2:
		set_reference_layout(not reference_layout)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F1:
		var inspector:Control=$FeedbackLayer/LayerInspector
		inspector.visible=not inspector.visible
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if $PreviewLayer.visible:
			close_modal()
			get_viewport().set_input_as_handled()
		elif current_mode in ["prayer_person","prayer_person_item"]:
			return_to_prayer()
			get_viewport().set_input_as_handled()
		elif current_mode=="cult" and not str(get_meta("s1_read", "")).is_empty():
			set_meta("s1_read", "")
			show_cult_stage()
			get_viewport().set_input_as_handled()
		elif current_mode!="world":
			show_world(selected_world)
			get_viewport().set_input_as_handled()

func font_report() -> Dictionary:
	var available: PackedStringArray = OS.get_system_fonts()
	return {"selected":font_resolution,"songti_available":available.has("Songti SC"),"pingfang_available":available.has("PingFang SC"),"system_fallback":fonts.heading is SystemFont,"font_files_copied":false}

func _source_region(region:Rect2) -> AtlasTexture:
	var atlas_texture:=AtlasTexture.new()
	atlas_texture.atlas=_texture(SOURCE_HOME)
	atlas_texture.region=region
	return atlas_texture

func _layout_regions() -> void:
	_rect($Interface/TopBar,Rect2(0,0,1672,50))
	_rect($Interface/WorldIndex,Rect2(22,60,292,570))
	_rect($Interface/WorldContext,Rect2(254,60,1418,665))
	_rect($World/Sanctuary,sanctuary_rect)
	_rect($Interface/Prayers,prayer_sidebar_rect)
	_rect($Interface/PrimaryStage,Rect2(320,70,960,700))
	_rect($Interface/Chronicle,adjusted_chronicle_rect)
	_rect($Interface/Dock,adjusted_dock_rect)
	# Draw the recent-history content above the common dock surface.
	$Interface.move_child($Interface/Chronicle,-1)

func set_reference_layout(value:bool) -> void:
	close_modal()
	reference_layout=value
	_layout_regions()
	if current_mode=="prayer": show_prayer_stage(current_prayer,current_variant)
	elif current_mode in ["prayer_person","prayer_person_item"]: show_prayer_person(current_prayer,current_mode=="prayer_person_item")
	elif current_mode=="cult": show_cult_stage()
	else:
		_build_context()
		_build_prayers()
	_build_chronicle()
	_build_dock()
	get_window().title="幽界群像 · 原稿比例对照（F2切换）" if value else "幽界群像 · 还原与布局调整 · 人工T46（F1图层 / F2对照）"
