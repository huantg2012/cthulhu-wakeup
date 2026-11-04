extends SceneTree
const RestorationSkin=preload("res://src/presentation/ui/restoration_skin.gd")
var skin=RestorationSkin.new()
var board:Control
var font:Font
var buttons:Array[Button]=[]
func _initialize()->void:_run.call_deferred()
func label(text:String,rect:Rect2,size:int=20,color:Color=Color("e8dec8"))->Label:
 var n:=Label.new();n.position=rect.position;n.size=rect.size;n.text=text
 n.add_theme_font_override("font",font);n.add_theme_font_size_override("font_size",size);n.add_theme_color_override("font_color",color)
 n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;board.add_child(n);return n
func image(texture:Texture2D,rect:Rect2)->void:
 var n:=TextureRect.new();n.position=rect.position;n.size=rect.size;n.texture=texture;n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;board.add_child(n)
func button(text:String,rect:Rect2,kind:String)->Button:
 var b:=Button.new();b.position=rect.position;b.size=rect.size;b.text=text
 b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",20)
 var color:=Color("201b13") if kind in ["selected","primary"] else Color("e8dec8")
 for state:String in ["normal","hover","pressed","disabled"]:
  b.add_theme_stylebox_override(state,skin.style(kind,state));b.add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),color)
 b.add_theme_stylebox_override("focus",skin.style(kind,"focus"))
 board.add_child(b);buttons.append(b);return b
func _run()->void:
 root.title="幽界群像 · 原稿/原生控件同尺度对照"
 root.size=Vector2i(1100,810);root.content_scale_size=Vector2i(1100,810)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 board=Control.new();board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(board)
 var bg:=ColorRect.new();bg.color=Color("071317");bg.size=Vector2(1100,810);board.add_child(bg)
 font=preload("res://src/presentation/ui/restoration_font.gd").regular()
 label("原稿局部（左） / 真实 Godot 控件（右）",Rect2(28,15,1000,35),25)
 label("参考区域保留原字；右侧名称、数值均为原生文字。",Rect2(28,52,1000,28),17,Color("aaa99c"))
 label("普通教团条目",Rect2(28,94,200,28),18)
 image(skin.source_region(Rect2(27,160,196,57)),Rect2(30,127,196,57))
 button("1   镜证议会 · 01",Rect2(300,127,196,57),"cult")
 label("选中教团条目",Rect2(28,200,200,28),18)
 image(skin.source_region(Rect2(26,352,200,61)),Rect2(28,231,200,61))
 var selected_button:=button("镜证议会 · 04",Rect2(300,231,200,61),"selected")
 selected_button.icon=skin.icon("cult_selected")
 selected_button.add_theme_constant_override("icon_max_width",28)
 selected_button.expand_icon=true
 label("当前选择保留浅色实体和深字",Rect2(540,238,500,34),19)
 label("资源读数",Rect2(28,309,200,28),18)
 image(skin.source_region(Rect2(275,3,123,42)),Rect2(30,346,123,42))
 image(skin.icon("whispers"),Rect2(300,348,30,34))
 label("低语  5/5",Rect2(339,346,180,42),22)
 label("世界四维：来源各自保留原稿色彩",Rect2(28,406,800,28),18)
 image(skin.source_region(Rect2(530,62,728,65)),Rect2(28,441,728,65))
 var live_metrics:=Panel.new();live_metrics.position=Vector2(28,519);live_metrics.size=Vector2(728,65)
 live_metrics.add_theme_stylebox_override("panel",skin.style("quiet"));board.add_child(live_metrics)
 var keys=["barrier","pollution","alert","stability"]
 var names=["屏障  28","污染 50–74","察觉 50–74","稳定 50–74"]
 var icon_x=[55,208,395,585]
 var text_x=[98,253,440,630]
 for i:int in range(4):
  image(skin.icon(keys[i]),Rect2(icon_x[i],526,36,40))
  label(names[i],Rect2(text_x[i],520,130,30),21,Color("e1c68e"))
  label("45轮确知" if i==0 else "45轮估计",Rect2(text_x[i],550,130,26),18,Color("b7b8ac"))
 label("动作：暗心亮边 / 浅色实体",Rect2(28,602,800,28),18)
 image(skin.source_region(Rect2(537,534,174,51)),Rect2(28,641,174,51))
 var management_button:=button("管理教团",Rect2(300,641,174,51),"dark")
 management_button.icon=skin.icon("management")
 management_button.add_theme_constant_override("icon_max_width",38)
 management_button.expand_icon=true
 image(skin.source_region(Rect2(1448,664,205,58)),Rect2(540,638,205,58))
 button("进入下一回合",Rect2(816,638,205,58),"primary")
 label("单一皮肤不会覆盖所有控件；静态原稿未提供的 hover/focus 为同源推导。",Rect2(28,738,1040,30),17,Color("aaa99c"))
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 var error:Error=root.get_texture().get_image().save_png("res://tools/echoes-art-master/evidence/restoration-components.png")
 for b:Button in buttons:
  if b.size.y>62:push_error("Component expanded unexpectedly: "+b.text);quit(1);return
 print("RESTORATION_COMPONENTS_OK native_buttons=",buttons.size()," font=",font.get_font_name()," capture=",error)
 quit(0 if error==OK else 1)
