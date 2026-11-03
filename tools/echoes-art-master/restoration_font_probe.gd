extends SceneTree
## Diagnostic only: system TTC is read in memory, never copied into the project.
const SOURCE := "/System/Library/Fonts/Supplemental/Songti.ttc"
const HOME := "res://docs/game-state/presentation-refinement-2026-11-03/echoes-home.png"
var board:Control
var label_font:Font
var report:Dictionary={"source":SOURCE,"copied_font_files":false,"ttc_faces":{"0":"SC Black","1":"SC Bold","2":"TC Bold","3":"SC Light","6":"SC Regular","7":"TC Regular"},"samples":[]}
func _initialize()->void:_run.call_deferred()
func text(value:String,rect:Rect2,font:Font,size:int=20,color:Color=Color("e8dfce"))->void:
 var label:=Label.new();label.position=rect.position;label.size=rect.size;label.text=value
 label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color)
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;board.add_child(label)
func image(texture:Texture2D,rect:Rect2)->void:
 var node:=TextureRect.new();node.position=rect.position;node.size=rect.size;node.texture=texture
 node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;board.add_child(node)
func variant(base:FontFile,face:int)->FontVariation:
 var font:=FontVariation.new();font.base_font=base;font.variation_face_index=face;return font
func remapped_face(face:int)->FontFile:
 var bytes:PackedByteArray=FileAccess.get_file_as_bytes(SOURCE)
 assert(bytes.size()>16 and bytes.slice(0,4).get_string_from_ascii()=="ttcf", "Expected macOS Songti TTC")
 var count:int=(int(bytes[8])<<24)|(int(bytes[9])<<16)|(int(bytes[10])<<8)|int(bytes[11])
 assert(face>=0 and face<count and bytes.size()>16+face*4, "TTC face out of range")
 # Keep all shared TTC tables untouched; point face0 at the selected existing SFNT.
 for i:int in range(4):bytes[12+i]=bytes[12+face*4+i]
 var font:=FontFile.new();font.data=bytes;return font
func details(label_value:String,font:Font)->void:
 var faces:Array[int]=[]
 for rid:RID in font.get_rids():faces.append(TextServerManager.get_primary_interface().font_get_face_index(rid))
 report.samples.append({"sample":label_value,"reported_family":font.get_font_name(),"reported_style":font.get_font_style_name(),"rid_faces":faces,"supports_yuan":font.has_char("远".unicode_at(0))})
func _run()->void:
 root.title="Songti TTC 字重诊断：原稿 / 系统默认 / 显式face"
 root.size=Vector2i(1180,880);root.content_scale_size=Vector2i(1180,880);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 board=Control.new();board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(board)
 var background:=ColorRect.new();background.size=Vector2(1180,880);background.color=Color("071317");board.add_child(background)
 var base:=FontFile.new();base.data=FileAccess.get_file_as_bytes(SOURCE)
 var regular:FontFile=remapped_face(6)
 var declared_regular:FontVariation=variant(base,6)
 var light:FontFile=remapped_face(3)
 var default_font:=SystemFont.new();default_font.font_names=PackedStringArray(["Songti SC"])
 var requested_light:=SystemFont.new();requested_light.font_names=PackedStringArray(["Songti SC"]);requested_light.font_weight=300
 label_font=regular
 details("Additional check: SystemFont font_weight300",requested_light)
 text("Songti.ttc：系统默认 Black 与实际 Regular / Light 对照",Rect2(24,12,1135,40),regular,25)
 text("以下原生样例均为同尺寸、同文字、同颜色；未复制任何商业字体文件。",Rect2(24,54,1100,30),regular,19)
 var source_image:=Image.new();source_image.load(HOME)
 var source_texture:=ImageTexture.create_from_image(source_image)
 var crop:=AtlasTexture.new();crop.atlas=source_texture;crop.region=Rect2(530,62,728,65)
 text("原稿四维读数，原尺寸",Rect2(24,96,1100,26),regular,18,Color("b4b5a8"))
 image(crop,Rect2(24,128,728,65))
 var samples:Array=[{"name":"SystemFont默认 / 实际RID face0 = Black","font":default_font},{"name":"FontVariation声明face6 / 检查实际渲染是否改变","font":declared_regular},{"name":"内存重定向首face → face6 / SC Regular","font":regular},{"name":"内存重定向首face → face3 / SC Light","font":light}]
 for i:int in range(samples.size()):
  var font:Font=samples[i].font;var y:float=218+i*151
  details(samples[i].name,font)
  text(samples[i].name,Rect2(24,y,1110,27),regular,18,Color("d7be91"))
  text("教团 12    镜证议会 · 04    个人祈求（3）",Rect2(24,y+32,1100,36),font,28)
  text("屏障  28     污染 50–74     察觉 50–74     稳定 50–74",Rect2(24,y+72,1100,31),font,21)
  text("45轮确知    塞拉 · 祭司 · 盐梦02    请回应我们的祭日。    远处仍有微光",Rect2(24,y+109,1120,28),font,19)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var capture:Image=root.get_texture().get_image()
 var error:Error=capture.save_png("res://tools/echoes-art-master/evidence/restoration-font-comparison.png")
 var file:=FileAccess.open("res://tools/echoes-art-master/evidence/restoration-font-resolution.json",FileAccess.WRITE)
 report["capture_error"]=error
 var black_pixels:PackedByteArray=capture.get_region(Rect2i(24,250,1076,36)).get_data()
 report["render_pixel_comparison"]={
  "FontVariation_face6_identical_to_default_black":black_pixels==capture.get_region(Rect2i(24,401,1076,36)).get_data(),
  "memory_Regular6_identical_to_default_black":black_pixels==capture.get_region(Rect2i(24,552,1076,36)).get_data(),
  "memory_Light3_identical_to_default_black":black_pixels==capture.get_region(Rect2i(24,703,1076,36)).get_data()
 }
 report["metadata_note"]="FontVariation face6 renders identical to default Black in this runtime. Pointing the in-memory TTC face0 entry at existing face6 or face3 selects actual Regular or Light; all shared tables retained. No font is written to disk."
 file.store_string(JSON.stringify(report,"\t"));file.close()
 if regular.get_font_style_name()!="Regular" or light.get_font_style_name()!="Light" or not regular.has_char("远".unicode_at(0)) or report.render_pixel_comparison.memory_Regular6_identical_to_default_black or report.render_pixel_comparison.memory_Light3_identical_to_default_black:
  push_error("Songti face verification failed");quit(1);return
 print("RESTORATION_FONT_PROBE_OK ",JSON.stringify(report))
 quit(0 if error==OK else 1)
