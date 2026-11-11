extends Control
const Marks=preload("res://docs/art/visual-generation/ui-study/occult_marks.gd")
const Paint=preload("res://docs/art/visual-generation/ui-study/painted_material.gd")
var recipe: Dictionary={}
var ordinal:=0
var _art:TextureRect
var _details:Array[Label]=[]

func setup(data: Dictionary, number: int) -> void:
 recipe=data;ordinal=number
 custom_minimum_size=Vector2(260,390);size=Vector2(260,390)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
 var tag:String=recipe.get("kind","世界")
 Paint.label(self,"%02d" % (ordinal+1),Rect2(17,9,32,24),12,Paint.MUTED)
 var over:=Paint.label(self,tag+"  %02d" % (ordinal+1),Rect2(65,9,179,24),12,Paint.MUTED)
 over.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 over.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 over.clip_text=true
 _art=TextureRect.new();_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 _art.texture=Paint.image(recipe.art);_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 _art.position=Vector2(10,35);_art.size=Vector2(240,240)
 _art.mouse_filter=Control.MOUSE_FILTER_IGNORE;_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var shader:=Shader.new()
 shader.code="shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV);float e=min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y));COLOR=vec4(c.rgb,c.a*smoothstep(0.,.04,e));}"
 var material:=ShaderMaterial.new();material.shader=shader;_art.material=material
 add_child(_art)
 var title:=Paint.label(self,recipe.title,Rect2(22,284,222,32),24)
 title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var subtitle:=Paint.label(self,recipe.get("subtitle","已知联系"),Rect2(22,316,218,20),12,Paint.MUTED)
 subtitle.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 _details.append(title);_details.append(subtitle)
 var lines:PackedStringArray=str(recipe.get("metrics","")).split("\n")
 for line in lines.size():
  _details.append(Paint.label(self,lines[line],Rect2(22,339+19*line,220,20),12,Paint.BONE))

func _draw() -> void:
 var readable:bool=not get_meta("fan_stacked",false) or get_meta("fan_focused",false)
 for label in _details:label.visible=readable
 var shadow:=PackedVector2Array([Vector2(5,7),Vector2(259,8),Vector2(263,386),Vector2(7,394)])
 draw_colored_polygon(shadow,Color(0,0,0,.48))
 draw_texture_rect(Paint.pigment("card",31+ordinal%4),Rect2(Vector2.ZERO,Vector2(260,390)),false)
 var attended: bool = get_meta("fan_focused", false) or get_meta("fan_hovered", false)
 draw_texture_rect(Marks.seal(attended), Rect2(50, 10, 40, 18), false)
 if attended:
  var c:=Color("#b1c09b")
  draw_colored_polygon(PackedVector2Array([Vector2(4,52),Vector2(7,43),Vector2(9,114),Vector2(5,122)]),c)
  draw_colored_polygon(PackedVector2Array([Vector2(251,285),Vector2(256,278),Vector2(254,348),Vector2(251,354)]),Color(c,.8))
  draw_colored_polygon(PackedVector2Array([Vector2(23,4),Vector2(85,3),Vector2(92,7),Vector2(25,9)]),Color(c,.7))
