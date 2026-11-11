extends RefCounted
## Original art remains untouched. UI paint and type have separate readability roles.
const FONT_PATH := "res://docs/art/visual-generation/ui-study/type/fusion-pixel-12px-proportional-zh_hans.ttf"
const BODY_PATH := "res://docs/art/visual-generation/ui-study/type/LXGWWenKaiScreen.ttf"
const Backdrop = preload("res://docs/art/visual-generation/ui-study/painted_backdrop.gd")
const ART := "res://docs/art/visual-generation/procedural-study/native-evidence/"
const INK := Color("#101719")
const BONE := Color("#d9d7be")
const MUTED := Color("#b4bdaa")
const ACCENT := Color("#b7c3a0")
static var cache: Dictionary = {}
static var title_face: FontFile
static var body_face: FontFile

static func font(heading: bool = false) -> FontFile:
 if heading:
  if title_face == null:
   title_face=FontFile.new()
   title_face.data=FileAccess.get_file_as_bytes(FONT_PATH)
   title_face.antialiasing=TextServer.FONT_ANTIALIASING_NONE
   title_face.hinting=TextServer.HINTING_NONE
   title_face.multichannel_signed_distance_field=false
   title_face.oversampling=1.0
  return title_face
 if body_face == null:
  body_face=FontFile.new()
  body_face.data=FileAccess.get_file_as_bytes(BODY_PATH)
  body_face.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
  body_face.hinting=TextServer.HINTING_LIGHT
  body_face.multichannel_signed_distance_field=false
  body_face.oversampling=2.0
 return body_face

static func image(path: String) -> Texture2D:
 if not cache.has(path):
  var bitmap:=Image.load_from_file(path)
  if bitmap==null:return null
  cache[path]=ImageTexture.create_from_image(bitmap)
 return cache[path]

static func noise(seed_value: int, frequency: float) -> FastNoiseLite:
 var n:=FastNoiseLite.new()
 n.seed=seed_value;n.frequency=frequency
 n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;n.fractal_octaves=2
 return n

static func pigment(kind: String, seed_value: int=31) -> Texture2D:
 if kind=="sky":return Backdrop.texture()
 var key:=kind+str(seed_value)
 if cache.has(key):return cache[key]
 var is_card:=kind=="card"
 var extent:=Vector2i(260,390) if is_card else Vector2i(240,40)
 var bitmap:=Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
 var broad:=noise(seed_value,.026)
 var stroke:=noise(seed_value+92,.095)
 var grain:=RandomNumberGenerator.new();grain.seed=seed_value
 for y in extent.y:
  for x in extent.x:
   var patch:=broad.get_noise_2d(x,y)
   var drag:=stroke.get_noise_2d(x*.35,y*1.6)
   var dx:=minf(x,extent.x-1-x)
   var dy:=minf(y,extent.y-1-y)
   var edge:=minf(dx,dy)
   var corner:=1.0-smoothstep(8.0,30.0,Vector2(dx,dy).length())
   var tear:=1.0+absf(patch)*1.7+corner*(2.0+absf(drag)*5.0)
   if edge<tear:
    bitmap.set_pixel(x,y,Color.TRANSPARENT);continue
   var color:Color
   if is_card:
    var field:=clampf(.24+floorf(patch*8.0)/8.0*.28+drag*.035,0,1)
    color=Color("#19282a").lerp(Color("#34443e"),field)
    # Image and caption belong to one painted substrate, not three framed panels.
    var caption_weight:=smoothstep(270.0,292.0,float(y)+patch*12.0)
    var caption:=Color("#26362f").lerp(Color("#38473b"),.15+patch*.12)
    color=color.lerp(caption,caption_weight)
    if edge<5.5+patch*1.5:
     var light:=.45 if x<8 or y<8 else .12
     color=Color("#34483f").lerp(Color("#829078"),clampf(light+patch*.27+drag*.035,0,1))
    elif edge<9.0:
     color=color.darkened(.18)
    # Occasional dry pigment at two corners; long edges stay quiet.
    if corner>.45 and edge<11.0 and drag>.12:color=color.lightened(.1)
   else:
    color=Color("#24342f").lerp(Color("#586952"),clampf(.28+patch*.24+drag*.065,0,1))
    if edge<2.4+patch:color=color.lightened(.07)
   var grit:=grain.randf_range(-.004,.004)
   color=Color(color.r+grit,color.g+grit,color.b+grit,1)
   bitmap.set_pixel(x,y,color)
 var texture:=ImageTexture.create_from_image(bitmap)
 cache[key]=texture
 return texture

static func label(parent: Node, value: String, rect: Rect2, px: int=14, color: Color=BONE) -> Label:
 var heading:=px>=24
 var node:=Label.new();node.text=value;node.position=rect.position;node.size=rect.size
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 node.add_theme_font_override("font",font(heading))
 node.add_theme_font_size_override("font_size",px if heading else maxi(px,14))
 node.add_theme_color_override("font_color",color)
 node.add_theme_constant_override("outline_size",0)
 node.add_theme_constant_override("line_spacing",1)
 node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if heading else CanvasItem.TEXTURE_FILTER_LINEAR
 parent.add_child(node)
 return node

static func style_buttons(app: Control) -> void:
 for node: Node in app.find_children("*","Control",true,false):
  if node is Label:
   var old:Color=node.get_theme_color("font_color")
   var heading:bool=str(node.name) in ["GameTitle","PerceptionTitle"]
   var px:=36 if str(node.name)=="PerceptionTitle" else (24 if heading else (20 if str(node.name)=="ResourceAmount" else 14))
   node.add_theme_font_override("font",font(heading))
   node.add_theme_font_size_override("font_size",px)
   node.add_theme_constant_override("outline_size",0)
   node.add_theme_constant_override("shadow_outline_size",0)
   node.add_theme_constant_override("font_spacing",0)
   node.add_theme_color_override("font_color",BONE if maxf(old.r,maxf(old.g,old.b))>.7 else MUTED)
   node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if heading else CanvasItem.TEXTURE_FILTER_LINEAR
   node.modulate=Color.WHITE
  elif node is Button:
   node.add_theme_font_override("font",font());node.add_theme_font_size_override("font_size",12)
   node.add_theme_color_override("font_color",BONE)
   node.add_theme_color_override("font_hover_color",Color("#eee8cc"))
   var primary:bool=str(node.name)=="PhaseAction"
   var obligation:bool=str(node.name) in ["AllAnchors","PrayerIndex","ResistanceIndex","AllWorlds"]
   for state in ["normal","hover","pressed","focus","disabled"]:
    var box:=StyleBoxTexture.new();box.texture=pigment("button")
    box.texture_margin_left=5;box.texture_margin_right=5;box.texture_margin_top=5;box.texture_margin_bottom=5
    box.content_margin_left=9;box.content_margin_right=9;box.content_margin_top=2;box.content_margin_bottom=2
    var opacity:float=.88 if primary else (.38 if obligation else .16)
    if state in ["hover","focus"]:opacity=.93 if primary else .66
    if state=="pressed":opacity=1.0
    if state=="disabled":opacity=.1
    box.modulate_color=Color(.8,.88,.8,opacity) if state=="pressed" else Color(1,1,1,opacity)
    node.add_theme_stylebox_override(state,box)
  elif node is ColorRect:
   node.color=Color("#4b5549")
   if str(node.name) in ["HorizonRule","LinkRule","ResourceRule","TurnRule"]:node.hide()
