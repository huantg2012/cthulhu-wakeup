extends RefCounted
## Source-faithful shared skins. Source-image regions never include live text.
const HOME := "res://docs/game-state/presentation-refinement-2026-11-03/echoes-home.png"
const SKINS := "res://docs/art/echoes-ui/round-start-master/restoration-assets/control-skins.png"
const ICONS := {
 "whispers":Rect2(279,7,30,34), "faith":Rect2(441,7,31,35), "awakening":Rect2(635,8,35,29),
 "barrier":Rect2(557,69,33,41), "pollution":Rect2(708,70,38,38), "alert":Rect2(895,72,40,36), "stability":Rect2(1085,70,34,38),
 "cult_selected":Rect2(38,368,29,28), "management":Rect2(553,545,44,29), "broadcast":Rect2(747,544,30,35),
 "countermeasure":Rect2(548,141,27,24), "seizure":Rect2(1313,378,47,47),
 "anchor_status":Rect2(548,185,24,26), "offering":Rect2(709,185,24,25), "source_book":Rect2(1095,186,26,23), "comparison":Rect2(37,648,26,24),
 "world":Rect2(272,66,56,59), "cult":Rect2(272,66,56,59), "prayer":Rect2(1322,136,36,49),
 "ritual":Rect2(1322,136,36,49), "evidence":Rect2(1323,207,35,51), "relatives":Rect2(1323,282,35,54),
 "history":Rect2(41,701,25,22), "listen":Rect2(179,764,70,69), "dream":Rect2(291,764,69,69),
 "oracle":Rect2(402,764,70,69), "bestow":Rect2(514,764,70,69), "appoint":Rect2(627,764,70,69),
 "sacrifice":Rect2(740,764,70,69), "breach":Rect2(852,764,70,69), "seed":Rect2(966,764,70,69)
}
var _textures:Dictionary={}
var _icons:Dictionary={}

func _load_texture(path:String)->Texture2D:
 if _textures.has(path):return _textures[path]
 if ResourceLoader.exists(path, "Texture2D"):
  var imported:=load(path) as Texture2D
  if imported!=null:
   _textures[path]=imported
   return imported
 var image:=Image.new()
 if image.load(path)!=OK:return null
 var texture:=ImageTexture.create_from_image(image)
 _textures[path]=texture
 return texture

func icon(key:String)->Texture2D:
 if not ICONS.has(key):return null
 if _icons.has(key):return _icons[key]
 var tile:=AtlasTexture.new()
 tile.atlas=_load_texture(HOME)
 tile.region=ICONS[key]
 tile.filter_clip=true
 _icons[key]=tile
 return tile

func source_region(rect:Rect2)->Texture2D:
 var tile:=AtlasTexture.new()
 tile.atlas=_load_texture(HOME)
 tile.region=rect
 tile.filter_clip=true
 return tile

func _scaled_skin(kind:String)->Texture2D:
 var key:String="scaled:"+kind
 if _textures.has(key):return _textures[key]
 var source:Texture2D=_load_texture(SKINS)
 if source==null:return null
 var region:Rect2i=Rect2i(70,80,1240,275)
 if kind=="selected":region=Rect2i(70,420,1235,308)
 elif kind=="primary":region=Rect2i(80,797,1220,280)
 # Sampling into display-density texture is runtime rendering preparation;
 # source files are kept intact and the artistic crop remains independently editable.
 var image:Image=source.get_image().get_region(region)
 image.resize(roundi(region.size.x*0.2),roundi(region.size.y*0.2),Image.INTERPOLATE_LANCZOS)
 var texture:=ImageTexture.create_from_image(image)
 _textures[key]=texture
 return texture

func _margins(box:StyleBox,x:float=12.0,y:float=2.0)->void:
 box.content_margin_left=x;box.content_margin_right=x
 box.content_margin_top=y;box.content_margin_bottom=y

# HOME is an opaque screenshot, not an alpha atlas. Keeping even a narrow
# strip of it as a nine-patch also keeps the old sea/black panel behind the
# ornament. Isolate the warm edge marks once, leaving the new scene visible
# through the rest. Coordinates and nine-patch margins remain editable here.
# This is an extraction, not a replacement for a hand-painted transparent edge:
# dim neutral detail can be lost and must be judged against the reference.
func _edge_texture(kind:String, region:Rect2i, margins:Vector4i)->Texture2D:
 var cache_key:String="edge:"+kind
 if _textures.has(cache_key):return _textures[cache_key]
 var source:Texture2D=_load_texture(HOME)
 if source==null:return null
 var original:Image=source.get_image().get_region(region)
 var size:Vector2i=region.size
 var output:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
 output.fill(Color.TRANSPARENT)
 for y:int in range(size.y):
  if y<margins.y or y>=size.y-margins.w:
   for x:int in range(size.x):_copy_edge_pixel(output,original,x,y,kind)
  else:
   for x:int in range(margins.x):_copy_edge_pixel(output,original,x,y,kind)
   for x:int in range(size.x-margins.z,size.x):_copy_edge_pixel(output,original,x,y,kind)
 var texture:=ImageTexture.create_from_image(output)
 _textures[cache_key]=texture
 return texture

func _copy_edge_pixel(output:Image,original:Image,x:int,y:int,kind:String)->void:
 # The screenshot's right edge intersects an unrelated red notice. That is
 # not part of the screen surround, even though it falls in the edge strip.
 if kind=="outer" and x>=original.get_width()-15 and y>=374 and y<430:return
 var c:Color=original.get_pixel(x,y)
 var warm:float=c.r-c.b
 var light:float=maxf(c.r,maxf(c.g,c.b))
 c.a=smoothstep(0.015,0.105,warm)*smoothstep(0.09,0.19,light)
 output.set_pixel(x,y,c)

func style(kind:String,state:String="normal")->StyleBox:
 if state=="focus":
  var focus:=StyleBoxFlat.new()
  focus.bg_color=Color.TRANSPARENT
  focus.border_color=Color("c1e1de")
  focus.set_border_width_all(1)
  focus.set_corner_radius_all(3)
  _margins(focus,0,0)
  return focus
 var chosen:String=kind
 if kind=="cult" and state=="selected":chosen="selected"
 if chosen in ["cult","selected","primary"]:
  var box:=StyleBoxTexture.new()
  box.texture=_scaled_skin(chosen)
  box.texture_margin_left=18;box.texture_margin_right=18
  box.texture_margin_top=9;box.texture_margin_bottom=9
  _margins(box)
  if chosen=="selected":
   box.expand_margin_top=2;box.expand_margin_bottom=2
  if state=="hover":box.modulate_color=Color(1.12,1.1,1.04,1)
  elif state=="pressed":box.modulate_color=Color(0.82,0.79,0.73,1)
  elif state=="disabled":box.modulate_color=Color(0.6,0.62,0.59,0.85)
  return box
 if chosen=="dark":
  var box:=StyleBoxTexture.new()
  box.texture=_edge_texture("dark",Rect2i(537,534,174,51),Vector4i(11,10,11,9))
  box.texture_margin_left=11;box.texture_margin_right=11
  box.texture_margin_top=10;box.texture_margin_bottom=9
  box.draw_center=false
  _margins(box,12,3)
  if state=="hover":box.modulate_color=Color(1.18,1.12,1.02,1)
  elif state=="pressed":box.modulate_color=Color(0.72,0.72,0.68,1)
  elif state=="disabled":box.modulate_color=Color(0.5,0.5,0.5,0.8)
  return box
 if chosen=="quiet":
  # Quiet actions need a legible hit surface over both light and dark scenery.
  # Unlike the old source screenshot's field crop, this surface has no baked
  # background and its hover/pressed states do not reveal a rectangular tile.
  var box:=StyleBoxFlat.new()
  box.bg_color=Color(0.012,0.028,0.03,0.72)
  box.border_color=Color(0.37,0.31,0.21,0.62)
  box.set_border_width_all(1)
  box.set_corner_radius_all(4)
  _margins(box,10,2)
  if state=="hover":
   box.bg_color=Color(0.075,0.096,0.091,0.86)
   box.border_color=Color(0.72,0.59,0.37,0.9)
  elif state=="pressed":
   box.bg_color=Color(0.008,0.018,0.019,0.92)
   box.border_color=Color(0.48,0.4,0.27,0.9)
  elif state=="disabled":
   box.bg_color=Color(0.012,0.022,0.023,0.45)
   box.border_color=Color(0.30,0.28,0.24,0.4)
  return box
 var box:=StyleBoxFlat.new()
 box.bg_color=Color(0.018,0.036,0.039,0.86)
 box.border_color=Color(0.35,0.3,0.19,0.8)
 box.set_border_width_all(1)
 box.set_corner_radius_all(4)
 if chosen=="row":
  box.bg_color=Color(0.055,0.071,0.071,0.94)
  box.border_color=Color(0.23,0.23,0.18,0.85)
 elif chosen=="risk":
  box.bg_color=Color(0.075,0.02,0.017,0.91)
  box.border_color=Color(0.43,0.13,0.08,0.85)
 if state=="hover":box.bg_color=box.bg_color.lightened(0.06)
 elif state=="pressed":box.bg_color=box.bg_color.darkened(0.15)
 _margins(box)
 return box

func frame(kind:String)->StyleBoxTexture:
 var box:=StyleBoxTexture.new()
 box.draw_center=false
 if kind=="outer":
  box.texture=_edge_texture("outer",Rect2i(0,0,1672,941),Vector4i(15,7,15,15))
  box.texture_margin_left=15;box.texture_margin_right=15
  box.texture_margin_top=7;box.texture_margin_bottom=15
 elif kind=="world":
  box.texture=_edge_texture("world",Rect2i(530,60,728,67),Vector4i(10,7,10,7))
  box.texture_margin_left=10;box.texture_margin_right=10
  box.texture_margin_top=7;box.texture_margin_bottom=7
 elif kind=="field":
  box.texture=_edge_texture("field",Rect2i(1082,180,175,37),Vector4i(9,6,9,6))
  box.texture_margin_left=9;box.texture_margin_right=9
  box.texture_margin_top=6;box.texture_margin_bottom=6
 elif kind=="comparison":
  box.texture=_edge_texture("comparison",Rect2i(174,640,1222,40),Vector4i(12,6,12,6))
  box.texture_margin_left=12;box.texture_margin_right=12
  box.texture_margin_top=6;box.texture_margin_bottom=6
 elif kind=="risk":
  box.texture=_edge_texture("risk",Rect2i(1290,374,376,54),Vector4i(22,9,17,9))
  box.texture_margin_left=22;box.texture_margin_right=17
  box.texture_margin_top=9;box.texture_margin_bottom=9
 else:
  box.texture=_edge_texture("group",Rect2i(1295,68,372,292),Vector4i(17,12,15,12))
  box.texture_margin_left=17;box.texture_margin_right=15
  box.texture_margin_top=12;box.texture_margin_bottom=12
 _margins(box,0,0)
 return box
