extends Control
## Editable art master. Fixture data is isolated; no Session, save, or rule writes.
const RestorationSkin = preload("res://tools/echoes-art-master/restoration_skin.gd")
const RESTORED: String = "res://docs/art/echoes-ui/round-start-master/restoration-assets/"
const SOURCE_HOME: String = "res://docs/game-state/presentation-refinement-2026-11-03/echoes-home.png"
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
@export var adjusted_prayer_rect := Rect2(501,527,670,198)
@export var adjusted_dock_rect := Rect2(11,815,1650,112)
@export var adjusted_chronicle_rect := Rect2(21,727,1650,84)
@export var sanctuary_rect := Rect2(480,270,610,264)
var reference_layout: bool = false
var power_page: int = 0
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
var selected_cult: int = 3
var modal_kind: String = ""
var return_focus: Control
var root_ready: bool = false
var interaction_log: Array[String] = []
var current_prayer: int = -1
var current_variant: String = ""
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
	_build_cults()
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

func _frame(parent: Node, title: String, rect: Rect2, region: String = "group", _thickness: int = 0) -> Control:
	var frame := Panel.new()
	frame.name=title
	_rect(frame,rect)
	frame.add_theme_stylebox_override("panel",skin.frame(region))
	parent.add_child(frame)
	return frame

func _panel(parent: Node, title: String, rect: Rect2, opacity: float = 0.92, ornament: bool = false) -> Control:
	var panel := Panel.new()
	panel.name=title
	_rect(panel,rect)
	var surface := StyleBoxFlat.new()
	surface.bg_color=Color(0.012,0.023,0.026,opacity)
	surface.border_color=Color(0.36,0.30,0.19,0.65)
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",surface)
	parent.add_child(panel)
	if ornament: _frame(panel,"CornerFrame",Rect2(Vector2.ZERO,rect.size))
	return panel

func _button_style(state: String, bone: bool = false, quiet: bool = false) -> StyleBox:
	return skin.style("quiet" if quiet else ("primary" if bone else "dark"),state)

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
	for state: String in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,_button_style(state,bone,quiet))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

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
	_frame($Interface/ReadingSupport,"OriginalOuterFrame",Rect2(0,0,1672,941),"outer")

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
	_panel(box,"TopMaterial",Rect2(13,0,1646,50),0.82)
	_label(box,"Turn","第46回合 ·",Rect2(29,4,108,41),22,BONE,true)
	_label(box,"Phase","神意行动",Rect2(138,4,114,41),22,GOLD,true)
	var resources:Array=[["whispers","低语","5/5",281,315,366],["faith","信仰","18/125",447,481,532],["awakening","苏醒","65",635,680,731]]
	for item:Array in resources:
		_icon(box,str(item[0])+"Icon",item[0],Rect2(item[3],8,29,31))
		_label(box,str(item[0])+"Label",item[1],Rect2(item[4],3,52,42),21,BONE,true)
		_label(box,str(item[0])+"Value",item[2],Rect2(item[5],3,92,42),24,BONE,true)
	_button(box,"CultsIndex","教团 12",Rect2(945,7,90,36),func(): open_info("教团","已知教团可从左侧查询与选择。"),false,true,20)
	_button(box,"RelicsIndex","圣物 18",Rect2(1040,7,90,36),open_relics,false,true,20)
	_button(box,"WorldIndex","世界档案 12",Rect2(1137,7,135,36),func(): open_info("世界档案","已知世界包含尚无教团或锚点的世界；本单场景不展开全部业务页面。"),false,true,20)
	_button(box,"PeopleIndex","人物",Rect2(1280,7,64,36),func(): open_info("人物","具名人物与无名信众分别计数；正式原型保留全部成员入口。"),false,true,20)
	_button(box,"FocusCapacity","关注世界 3/3",Rect2(1350,7,160,36),func(): open_info("关注与名额","查看与定位不自动改变机制关注。"),false,true,20)
	_button(box,"Income","收支",Rect2(1515,7,63,36),func(): open_info("收支","低语5，信仰18/125。当前是人工展示局面；正式原型提供实际收支。"),false,true,19)
	_button(box,"Deity","本体",Rect2(1583,7,66,36),func(): open_info("本体","当前展示苏醒65；降临需苏醒90。"),false,true,19)
	for node:Node in box.get_children():
		if node is Button:
			node.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			node.add_theme_color_override("font_color",BONE)
			_fill(box,"NavDivider"+str(node.name),Rect2(node.position.x-4,16,1,19),Color(0.40,0.35,0.26,0.65))

func _build_cults() -> void:
	var box:Control=$Interface/CultIndex
	_clear(box)
	_label(box,"Heading","教团 12",Rect2(12,4,180,42),30,GOLD,true)
	var search:=LineEdit.new()
	search.name="SearchCults"; _rect(search,Rect2(8,51,195,37)); search.mouse_filter=Control.MOUSE_FILTER_STOP
	search.placeholder_text="查找教团名称"; search.add_theme_font_override("font",fonts.heading); search.add_theme_font_size_override("font_size",19)
	search.add_theme_color_override("font_placeholder_color",Color("a9a69a"))
	var field:StyleBox=skin.style("quiet");field.set_content_margin(SIDE_LEFT,34)
	search.add_theme_stylebox_override("normal",field);search.add_theme_stylebox_override("focus",skin.style("quiet","focus"))
	box.add_child(search);search.text_changed.connect(_filter_cults)
	_icon(box,"SearchIcon","search",Rect2(18,58,22,22))
	var names:Array[String]=["镜证议会","盐梦诸邦","千面公社","镜证议会","盐梦诸邦","千面公社"]
	for i:int in range(6):
		var selected:bool=i==selected_cult
		var control:=_button(box,"Cult_%d"%i,"",Rect2(4,101+i*65,202,58 if i<5 else 78),func(): select_cult(i))
		for state:String in ["normal","hover","pressed","focus"]:control.add_theme_stylebox_override(state,skin.style("selected" if selected else "cult",state))
		control.tooltip_text=names[i]+" · %02d"%(i+1)
		var ink:=Color("24221d") if selected else BONE
		if selected:_icon(control,"SelectedEye","cult_selected",Rect2(13,15,29,28))
		else:_label(control,"Number",str(i+1),Rect2(15,7,26,40),21,GOLD,true)
		_label(control,"Name",names[i]+" · %02d"%(i+1),Rect2(48,7,150,40),21,ink,true)
		if i==5:_label(control,"State","祈求余1轮",Rect2(48,41,143,30),20,Color("edb25d"),true)
	_button(box,"PreviousCults","‹",Rect2(16,515,30,30),func(): open_info("教团索引","人工展示1–6/12；本稿不模拟其余教团业务。"),false,true,25)
	_label(box,"Count","1–6 /12",Rect2(63,514,93,32),20,BONE,true)
	_button(box,"NextCults","›",Rect2(165,515,30,30),func(): open_info("教团索引","完整教团范围及查询由正式原型提供。"),false,true,25)

func _filter_cults(query: String) -> void:
	for i: int in range(6):
		var node: Button = $Interface/CultIndex.get_node("Cult_%d"%i)
		node.visible = query.is_empty() or query in node.tooltip_text

func select_cult(index: int) -> void:
	selected_cult = index
	interaction_log.append("cult:%d"%index)
	_build_cults()
	_build_context()

func _build_context() -> void:
	var box:Control=$Interface/WorldContext
	_clear(box)
	var names:Array[String]=["镜证议会 · 01","盐梦诸邦 · 02","千面公社 · 03","镜证议会 · 04","盐梦诸邦 · 05","千面公社 · 06"]
	var known_fixture:bool=selected_cult in [1,3]
	var values:Array[String]=["未掌握","未掌握","未掌握","未掌握"]
	if selected_cult==3:values=["28","50–74","50–74","50–74"]
	elif selected_cult==1:values=["50","25–49","25–49","75–100"]
	var subject:=_panel(box,"SubjectPlate",Rect2(0,0,270,67),0.53)
	subject.add_theme_stylebox_override("panel",skin.style("cult"))
	_icon(box,"WorldSigil","world",Rect2(18,7,55,53))
	_label(box,"WorldName",names[selected_cult],Rect2(86,5,190,54),26,GOLD_HI,true)
	_panel(box,"WorldBand",Rect2(276,1,728,66),0.73)
	_frame(box,"WorldBandEdge",Rect2(276,1,728,66),"world")
	var metrics:Array=[["barrier","屏障"],["pollution","污染"],["alert","察觉"],["stability","稳定"]]
	for i:int in range(4):
		var x:float=293+i*179
		_icon(box,"MetricIcon_%d"%i,metrics[i][0],Rect2(x,11,37,39))
		_label(box,"MetricName_%d"%i,metrics[i][1],Rect2(x+43,2,48,32),21,GOLD,true)
		_label(box,"MetricValue_%d"%i,values[i],Rect2(x+93,2,90,32),22,GOLD if known_fixture else MUTED,true)
		_label(box,"MetricSource_%d"%i,("45轮确知" if i==0 else "45轮估计") if known_fixture else "未有记录",Rect2(x+43,34,135,26),19,MUTED,true)
	var warning:=_panel(box,"ResistanceBand",Rect2(276,75,728,38),0.80)
	warning.add_theme_stylebox_override("panel",skin.style("risk"))
	var resistance:String="暂无已知反制"
	if selected_cult==3:resistance="清洗教团 · 第47轮末　│　目标：镜证04的教团　│　无名信众−20% · 凝聚−10"
	elif selected_cult==1:resistance="查证异常 · 第47轮末　│　目标：祭司塞拉　│　普通匿名保护失效"
	_icon(warning,"WarningIcon","countermeasure",Rect2(17,7,27,24))
	_label(warning,"Resistance",resistance,Rect2(50,0,670,38),17,RISK if known_fixture else MUTED,true)
	_button(box,"AnchorStatus","有效锚点 1    │     供奉缺口 1" if selected_cult==3 else "锚点与供奉 · 查看已知记录",Rect2(276,120,320,37),func(): open_info("锚点与供奉","镜证04：1个有效锚点及1个供奉缺口。展示记录。" if selected_cult==3 else names[selected_cult]+"：本展示未配置该世界的锚点与供奉记录，不能借用镜证04的数量。"),false,true,19)
	_button(box,"ObservationSource","来源 / 观测记录",Rect2(828,120,176,37),func(): open_info("世界观察来源","第45轮观察。确知、估计与未掌握分别保留；不是当前实时扫描。" if known_fixture else "暂无此世界的已掌握观察。"),false,true,18)
	box.get_node("AnchorStatus").alignment=HORIZONTAL_ALIGNMENT_RIGHT
	box.get_node("ObservationSource").alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if selected_cult==3:
		_icon(box,"AnchorIcon","anchor_status",Rect2(291,126,24,26))
		_icon(box,"OfferingIcon","offering",Rect2(450,126,24,25))
	_icon(box,"SourceIcon","source_book",Rect2(839,127,26,23))
	var right_x:float=1044
	var notice:=_panel(box,"OtherWorldNotice",Rect2(right_x,315,370,54),0.82)
	notice.add_theme_stylebox_override("panel",skin.style("risk"))
	_frame(notice,"RiskEdge",Rect2(-8,0,378,54),"risk")
	_icon(notice,"NoticeIcon","seizure",Rect2(12,4,47,47))
	_button(notice,"Notice","焚星10：本轮末扣押空名印 ›",Rect2(51,4,310,46),func(): open_info("扣押预告","第46轮，焚星10的扣押预告。展示记录不代表本次浏览触发行动。"),false,true,19)
	notice.get_node("Notice").add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	notice.get_node("Notice").add_theme_color_override("font_color",BONE)
	var mx:float=1048 if not reference_layout else 285
	var my:float=420 if not reference_layout else 475
	_button(box,"ManageCult","管理教团",Rect2(mx,my,174,46),func(): open_info("管理教团",names[selected_cult]+"；正式原型提供成员、策略、供奉与关联对象。本稿验证入口及控件，不执行经营。"),false,false,22)
	_icon(box,"ManagementIcon","management",Rect2(mx+12,my+9,38,26))
	box.get_node("ManageCult").alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_label(box,"CultActivity","传教中" if selected_cult==3 else "查看教团状态",Rect2(mx+186,my+2,170,40),21,GOLD,true)
	_label(box,"CultNumbers","信众 64   │   凝聚 70" if selected_cult==3 else "详情按当前教团查询",Rect2(mx+4,my+57,350,34),21,BONE,true)

func _build_prayers() -> void:
	var box:Control=$Interface/Prayers
	_clear(box)
	var width:float=box.size.x
	_panel(box,"PrayersMaterial",Rect2(Vector2.ZERO,box.size),0.88,true)
	_label(box,"PrayersTitle","待处理祈求（3）",Rect2(24,5,width-40,34),26,GOLD_HI,true)
	if not reference_layout:_label(box,"Opportunity","本轮可回应一次",Rect2(width-210,8,185,30),18,MUTED,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var order:Array[int]=[1,2,0]
	for row:int in range(order.size()):
		var i:int=order[row]
		var fixture:Dictionary=PRAYERS[i]
		var definition:Dictionary=catalog.tables.prayers[fixture.id]
		var h:float=67 if reference_layout else 48
		var card:=_panel(box,"PrayerCard_%d"%i,Rect2(12,44+row*(h+(7 if reference_layout else 3)),width-24,h),0.90)
		card.add_theme_stylebox_override("panel",skin.style("row"))
		_icon(card,"PrayerIdentity",fixture.icon,Rect2(10,5,35,38))
		_label(card,"Person",fixture.person+" · "+fixture.role,Rect2(52,1,133,23),19,BONE,true)
		_label(card,"World",fixture.world,Rect2(187,1,83,23),19,CYAN,true)
		_label(card,"Title",str(definition.title),Rect2(52,24,328 if not reference_layout else 240,24),20,BONE,true)
		if reference_layout:
			_button(card,"Shallow_%d"%i,"",Rect2(0,0,width-24,h),func(): open_prayer(i,"shallow"),false,true)
			card.get_node("Shallow_%d"%i).add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			_label(card,"Due",fixture.due,Rect2(width-110,29,72,26),17,RISK if i==0 else GOLD,true)
		else:
			_label(card,"Due",fixture.due,Rect2(277,1,108,23),18,RISK if i==0 else GOLD,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			_prayer_choice(card,"Shallow_%d"%i,Rect2(414,6,104,36),i,"shallow")
			_prayer_choice(card,"Deep_%d"%i,Rect2(528,6,104,36),i,"deep")

func _prayer_choice(parent: Control, title: String, rect: Rect2, prayer_index: int, variant: String) -> Button:
	var choice:String="浅触" if variant=="shallow" else "深应"
	var button:=_button(parent,title,choice+" ›",rect,func(): open_prayer(prayer_index,variant),false,true,20)
	button.tooltip_text="%s · 费用：%d低语 / %d信仰；点击查看必付与各档后果"%[choice,catalog.integer("prayer_"+variant+"_whispers"),catalog.integer("prayer_"+variant+"_faith")]
	return button

func _build_chronicle() -> void:
	var box:Control=$Interface/Chronicle
	_clear(box)
	_button(box,"CompareWorlds","世界对照",Rect2(0,0,143,38),func(): open_info("世界对照","此行是盐梦02第45轮已知记录。屏障是当时确值，其余三个维度是当时估计区间；与上方当前教团世界分别标注。"),false,true,21)
	box.get_node("CompareWorlds").alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_icon(box,"CompareIcon","comparison",Rect2(13,7,26,24))
	var compare:=_panel(box,"ComparedWorld",Rect2(153,0,1220,38),0.79)
	_frame(compare,"ComparisonEdge",Rect2(0,0,1220,38),"comparison")
	_label(compare,"Name","盐梦02",Rect2(24,2,100,34),21,CYAN,true)
	_label(compare,"Metrics","45轮：屏障确值50 · 污染25–49 / 察觉25–49 / 稳定75–100（估）",Rect2(117,2,575,34),17,GOLD,true)
	_label(compare,"Resistance","查证异常 · 47轮末 │ 祭司塞拉 │ 普通匿名保护失效",Rect2(702,2,510,34),17,BONE,true)
	_panel(box,"ChronicleMaterial",Rect2(0,46,1390,34),0.76)
	_icon(box,"HistoryIcon","history",Rect2(18,52,27,25))
	_button(box,"History","近况",Rect2(48,46,72,34),func(): open_info("近况与编年史","记录按发生回合与具体对象保存；当前展示人工成熟局面。"),false,true,21)
	_label(box,"Record","45轮 盐梦02：仪式见证留存　 │　 46轮 焚星10：扣押预告",Rect2(144,46,1125,34),20,BONE,true)
	_button(box,"EndTurn","进入下一回合",Rect2(1425,29,215,54),func(): open_info("轮末确认","本轮仍有祈求可回应。本美术样板不支付、不推进正式回合。"),true,false,24)

func _build_dock() -> void:
	var box:Control=$Interface/Dock
	_clear(box)
	_panel(box,"DockMaterial",Rect2(0,0,1650,box.size.y),0.78)
	_button(box,"Overview","总览",Rect2(7,32,120,49),func(): close_modal(),true,false,23)
	var y:float=18 if reference_layout else 5
	for i:int in range(POWER_ICONS.size()):
		var power:Dictionary=catalog.tables.powers["POWER_"+POWER_ICONS[i].to_upper()]
		var locked:bool=int(power.unlock_awakening)>int(fixture_state.awakening)
		var control:=_button(box,"Power_%s"%power.id,"",Rect2(154+(i%8)*109,y,90,91),func(): open_power(str(power.id)),false,true)
		control.visible=i/8==power_page
		control.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		control.tooltip_text=("需苏醒 %s · 当前65"%power.unlock_awakening) if locked else "%s · %s低语 / %s信仰"%[power.name,power.whispers,power.faith]
		_icon(control,"PowerIcon",POWER_ICONS[i],Rect2(14,1,62,62),Color(0.50,0.53,0.55,1) if locked else Color.WHITE)
		_label(control,"PowerName",str(power.name),Rect2(0,64,90,27),20,MUTED if locked else BONE,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if locked:_label(control,"LockReason","苏醒%s"%power.unlock_awakening,Rect2(0,44,90,23),17,RISK,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var page_y:float=139 if reference_layout else 25
	var page_x:float=144 if reference_layout else 1040
	_button(box,"PreviousPowers","‹",Rect2(page_x,page_y,32,33),func(): set_power_page(0),false,true,25)
	_button(box,"NextPowers","›",Rect2(page_x+(135 if reference_layout else 93),page_y,32,33),func(): set_power_page(1),false,true,25)
	_label(box,"PowerRange","1–8 /12" if power_page==0 else "9–12 /12",Rect2(page_x+36,page_y,94,33) if reference_layout else Rect2(page_x-3,page_y+36,135,28),18,MUTED,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var relics:=_panel(box,"RelicMaterial",Rect2(1184,0,466,box.size.y),0.74,true)
	_label(relics,"RelicsTitle","圣物 18",Rect2(22,3,135,30),25,GOLD,true)
	_button(relics,"AllRelics","全部 ›",Rect2(356,3,88,29),open_relics,false,true,19)
	var relic_ids:Array[String]=["RELIC_ROOT_NAIL","RELIC_ECHO_BELL","RELIC_HOLLOW_SEAL","RELIC_WITNESS_LENS"]
	var regions:Array[Rect2]=[Rect2(1230,786,70,70),Rect2(1338,786,70,70),Rect2(1440,786,80,72),Rect2(1540,780,80,78)]
	for i:int in range(4):
		var control:=_button(relics,"Relic_%d"%i,"",Rect2(23+i*108,34 if reference_layout else 30,100,box.size.y-34),open_relics,false,true)
		control.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		var icon_rect:=Rect2(14,0,72,78) if reference_layout else Rect2(29,0,42,36)
		_image(control,"RelicImage",icon_rect,_source_region(regions[i]))
		var name_rect:=Rect2(0,78,100,23) if reference_layout else Rect2(0,36,100,22)
		_label(control,"RelicName",str(catalog.tables.relics[relic_ids[i]].name),name_rect,20 if reference_layout else 18,BONE,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var state_rect:=Rect2(0,102,100,25) if reference_layout else Rect2(0,57,100,22)
		_label(control,"RelicState",["绑定","携带","携带","保管"][i],state_rect,16,Color("b4ce76") if i==0 else MUTED,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func _modal(title: String, kind: String, height: float = 620) -> Control:
	var layer: Control = $PreviewLayer
	if not layer.visible:
		return_focus = get_viewport().gui_get_focus_owner()
	_clear(layer)
	layer.visible = true
	modal_kind = kind
	_fill(layer,"Backdrop",Rect2(0,0,1672,941),Color(0.0,0.012,0.02,0.72))
	var box := _panel(layer,"Dialog",Rect2(356,(941-height)/2,960,height),0.99,true)
	_label(box,"Heading",title,Rect2(34,21,820,47),28,GOLD,true)
	var close := _button(box,"ClosePreview","×",Rect2(878,22,48,42),close_modal,false,true,28)
	close.grab_focus()
	_fill(box,"Divider",Rect2(33,81,894,1),Color("897347"))
	interaction_log.append("open:"+kind)
	return box

func close_modal() -> void:
	$PreviewLayer.hide()
	modal_kind = ""
	interaction_log.append("close")
	if is_instance_valid(return_focus) and return_focus.is_inside_tree(): return_focus.grab_focus()

func open_prayer(index: int, variant: String) -> void:
	current_prayer = index
	current_variant = variant
	var fixture: Dictionary = PRAYERS[index]
	var data: Dictionary = catalog.tables.prayers[fixture.id]
	var meaning: Dictionary = semantics.prayer(catalog,fixture.id,variant)
	var box := _modal(str(data.title),"prayer",660)
	_icon(box,"SubjectIcon",fixture.icon,Rect2(36,104,68,68))
	_label(box,"Subject",fixture.person+" · "+fixture.role+"　"+fixture.world,Rect2(126,100,610,37),23,BONE,true)
	_label(box,"Deadline","请求期限："+fixture.due+"　·　本轮唯一回应机会",Rect2(126,139,650,27),20,MUTED)
	_label(box,"OriginalCrisis",fixture.relation,Rect2(126,169,740,26),18,RISK if index==0 else MUTED)
	_button(box,"ChooseShallow","浅触",Rect2(36,197,160,44),func(): open_prayer(index,"shallow"),variant=="shallow")
	_button(box,"ChooseDeep","深应",Rect2(208,197,160,44),func(): open_prayer(index,"deep"),variant=="deep")
	_label(box,"Payment","费用　%s低语 · %s信仰"%[catalog.integer("prayer_"+variant+"_whispers"),catalog.integer("prayer_"+variant+"_faith")],Rect2(420,199,460,42),23,GOLD,true)
	var scroll := ScrollContainer.new()
	scroll.name="EffectScroll"
	_rect(scroll,Rect2(36,264,888,270))
	scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",13)
	scroll.add_child(content)
	for pair: Array in [["必付代价",meaning.always], ["成功",meaning.summary], ["失败",meaning.failure], ["灾变",meaning.disaster]]:
		if str(pair[1]).is_empty():continue
		var line := Label.new()
		line.name = "Effect"+str(pair[0])
		line.text = str(pair[0])+"　"+str(pair[1])
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_theme_font_size_override("font_size",20)
		line.add_theme_color_override("font_color",RISK if pair[0] in ["必付代价","灾变"] else BONE)
		content.add_child(line)
	_label(box,"PreviewScope","效果说明 · 未代入实际对象判定",Rect2(36,560,610,42),18,MUTED)
	_button(box,"ReturnToPrayers","返回祈求",Rect2(724,557,200,48),close_modal,true)

func open_power(id: String) -> void:
	var power: Dictionary = catalog.tables.powers[id]
	var box := _modal(str(power.name),"power",480)
	var locked: bool=int(power.unlock_awakening)>int(fixture_state.awakening)
	_label(box,"Availability","尚未解锁 · 需要苏醒 %s（当前65）"%power.unlock_awakening if locked else "%s低语 · %s信仰"%[power.whispers,power.faith],Rect2(36,109,880,42),23,RISK if locked else GOLD,true)
	_label(box,"Requirement","条件　"+str(power.target_requirement),Rect2(36,171,880,80),20,BONE,false,true)
	_label(box,"Description","作用　"+str(power.success),Rect2(36,271,880,85),20,BONE,false,true)
	_button(box,"ReturnToPowers","返回",Rect2(724,395,200,48),close_modal,true)

func open_relics() -> void:
	var box := _modal("圣物 · 当前18件","relics",650)
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
	for i: int in range(18):
		var row:=HBoxContainer.new()
		row.custom_minimum_size.y=42
		list.add_child(row)
		var name_label:=Label.new()
		name_label.text = "%s  R%02d"%[catalog.tables.relics[item_ids[i%item_ids.size()]].name,i+1]
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color",GOLD)
		row.add_child(name_label)
		var state_label:=Label.new()
		state_label.text = ["绑定","携带","保管"][i] if i < 3 else ("绑定" if i%4==0 else ("保管" if i%3==0 else "携带"))
		state_label.custom_minimum_size.x=125
		row.add_child(state_label)
	_button(box,"ReturnToRelics","返回",Rect2(724,574,200,46),close_modal,true)

func open_info(title: String, body: String) -> void:
	var box := _modal(title,"info",360)
	_label(box,"Content",body,Rect2(36,105,885,140),22,BONE,false,true)
	_button(box,"ReturnFromInfo","返回",Rect2(724,274,200,46),close_modal,true)

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

func font_report() -> Dictionary:
	var available: PackedStringArray = OS.get_system_fonts()
	return {"selected":font_resolution,"songti_available":available.has("Songti SC"),"pingfang_available":available.has("PingFang SC"),"system_fallback":fonts.heading is SystemFont,"font_files_copied":false}

func _source_region(region:Rect2) -> AtlasTexture:
	var atlas_texture:=AtlasTexture.new()
	atlas_texture.atlas=_texture(SOURCE_HOME)
	atlas_texture.region=region
	return atlas_texture

func set_power_page(page:int) -> void:
	power_page=clampi(page,0,1)
	for i:int in range(POWER_ICONS.size()):
		var node:Control=$Interface/Dock.get_node("Power_POWER_"+POWER_ICONS[i].to_upper())
		node.visible=i/8==power_page
	$Interface/Dock/PowerRange.text="1–8 /12" if power_page==0 else "9–12 /12"
	interaction_log.append("power_page:%d"%power_page)

func _layout_regions() -> void:
	_rect($Interface/TopBar,Rect2(0,0,1672,50))
	_rect($Interface/CultIndex,Rect2(22,60,216,570))
	_rect($Interface/WorldContext,Rect2(254,60,1418,665))
	_rect($World/Sanctuary,sanctuary_rect)
	_rect($Interface/Prayers,Rect2(1295,70,370,288) if reference_layout else adjusted_prayer_rect)
	_rect($Interface/Chronicle,Rect2(21,640,1650,84) if reference_layout else adjusted_chronicle_rect)
	_rect($Interface/Dock,Rect2(11,741,1650,186) if reference_layout else adjusted_dock_rect)

func set_reference_layout(value:bool) -> void:
	close_modal()
	reference_layout=value
	_layout_regions()
	_build_context()
	_build_prayers()
	_build_chronicle()
	_build_dock()
	get_window().title="幽界群像 · 原稿比例对照（F2切换）" if value else "幽界群像 · 还原与布局调整 · 人工T46（F1图层 / F2对照）"
