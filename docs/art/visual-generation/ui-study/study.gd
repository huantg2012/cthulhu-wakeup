extends SceneTree
## Independent exploration. Production navigation and Session remain the source.
const Scene=preload("res://src/presentation/production/game_root.tscn")
const Session=preload("res://src/presentation/session.gd")
const Paint=preload("res://docs/art/visual-generation/ui-study/painted_material.gd")
const Card=preload("res://docs/art/visual-generation/ui-study/painted_card.gd")
const Fan=preload("res://docs/art/visual-generation/ui-study/card_fan.gd")
const FIXTURE="res://docs/qa/ui-manifest/saves/ongoing.json"
const SOURCES=["tide","fire","frozen","bone-watercolor"]
const SHOTS=["01-three-worlds","02-twelve-worlds","03-twenty-four-worlds","04-shared-world-art"]
class StudyKeys extends Node:
 signal chosen(value:int)
 func _input(event:InputEvent)->void:
  if event is InputEventKey and event.pressed and not event.echo:
   var value: int=[KEY_F1,KEY_F2,KEY_F3,KEY_F4].find(event.keycode)
   if value>=0:get_viewport().set_input_as_handled();chosen.emit(value)
var app:Control
var fan:Control
var mode:=0
var stage_id:=0
var surface_id:=0
var ready_to_style:=false
var output:=""
var mode_label:Label
var position_label:Label
var recipes:Array[Dictionary]=[]
var _fixed_before:Dictionary={}
var _capture_evidence:Dictionary={}

func _initialize()->void:_run.call_deferred()
func _process(_delta:float)->bool:
 if ready_to_style and is_instance_valid(app):
  var stage:int=app._stage.get_instance_id() if is_instance_valid(app._stage) else 0
  var surface:int=app._surface.get_instance_id() if is_instance_valid(app._surface) else 0
  if stage!=stage_id or surface!=surface_id:_apply()
 return false

func _run()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--capture="):output=argument.trim_prefix("--capture=")
  if argument.begins_with("--mode="):mode=clampi(argument.trim_prefix("--mode=").to_int()-1,0,3)
 var isolated:="user://ui-visual-study/%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
 var fixture:=isolated.path_join("fixture.json")
 var err:=DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE),ProjectSettings.globalize_path(fixture))
 if err!=OK:push_error("Could not copy isolated fixture");quit(1);return
 var game:=Scene.instantiate();app=game.get_node("Presentation/CanvasLayer/OverlayRoot")
 app.session=Session.new(isolated);root.add_child(game);app._load_saved(fixture)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);root.move_to_center()
 var keys:=StudyKeys.new();keys.chosen.connect(_select);root.add_child(keys)
 await process_frame
 _fixed_before=_fixed_buttons()
 ready_to_style=true;_apply()
 if not output.is_empty():await _capture()

func _select(value:int)->void:
 mode=value
 if not app._world_id.is_empty():app._inspect_world("");return
 if is_instance_valid(fan):_populate()
 _title()

func _title()->void:
 root.title="邪神苏醒 · 粗印画牌 · F1 三界 / F2 十二张 / F3 二十四张 / F4 三类立绘 · 独立预览"

func _apply()->void:
 stage_id=app._stage.get_instance_id() if is_instance_valid(app._stage) else 0
 surface_id=app._surface.get_instance_id() if is_instance_valid(app._surface) else 0
 if not app._world_id.is_empty() or not app._dialog.is_empty():return
 var stage:Control=app._stage
 if stage.has_node("PaintedFan"):return
 Paint.style_buttons(app)
 var night:=stage.get_node_or_null("Night") as TextureRect
 if night:night.texture=Paint.pigment("sky");night.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 # Only the producer-authorized world-card carrier changes geometry/input.
 for node:Node in stage.get_children():
  if str(node.name).begins_with("WorldPlaceholder_") or str(node.name).begins_with("World_"):node.hide()
  if str(node.name)=="MetricLegend":node.hide()
 fan=Fan.new();fan.name="PaintedFan";fan.position=Vector2(318,126);fan.size=Vector2(920,450)
 stage.add_child(fan)
 fan.card_chosen.connect(_enter)
 fan.focus_changed.connect(_focus_changed)
 mode_label=Paint.label(stage,"",Rect2(355,591,800,24),12,Paint.MUTED)
 position_label=Paint.label(stage,"",Rect2(345,558,870,28),16,Paint.BONE)
 position_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _populate();_title()

func _populate()->void:
 recipes.clear()
 var count:int=[3,12,24,3][mode]
 var worlds:Array=app._interaction._ranked_worlds(app._pending_prayers())
 for i in count:
  if mode==3:
   recipes.append([
    {"title":"潮汐世界","kind":"世界","subtitle":"原型 0 · 深渊翠","metrics":"世界种子 1339","art":Paint.ART+"tide/world.png"},
    {"title":"听潮密会","kind":"教团","subtitle":"持灯入会与潮水量测","metrics":"潮蚀双岸 · 下沉环井","art":Paint.ART+"tide/cult.png"},
    {"title":"裁判者","kind":"人物","subtitle":"受贿书信外泄","metrics":"人物种子 1000","art":Paint.ART+"tide/person-0-1000.png"}
   ][i])
  else:
   var w:Dictionary=worlds[i%worlds.size()]
   var values:Array[String]=[]
   for field:String in ["barrier","pollution","alert","stability"]:
    values.append(str(app._views.metric_display(w,field).value))
   recipes.append({
    "title":str(w.title) if i<worlds.size() else "排布样牌 %02d"%(i+1),
    "kind":"已关注 / 世界" if i<worlds.size() else "排布样牌",
    "subtitle":app._interaction._world_status(w) if i<worlds.size() else "重复立绘 · 仅验证叠放",
    "metrics":"屏障%s  污染%s\n察觉%s  稳定%s"%values,
    "world_id":str(w.id) if i<worlds.size() else "",
    "art":Paint.ART+SOURCES[i%SOURCES.size()]+"/world.png"})
 var cards:Array[Control]=[]
 for i in recipes.size():
  var card:=Card.new();card.setup(recipes[i],i);cards.append(card)
 fan.configure(cards);fan.set_focus(0,false);fan.grab_focus()
 mode_label.text="同世界三类立绘的材质对照 · 独立美术样板" if mode==3 else ("左右拖动 / 滚轮翻动 / 方向键 · 点按当前卡进入世界" if mode==0 else "%d 张排布样板，扩展卡重复使用已有立绘 · 未增加真实世界" % count)
 _focus_changed(fan.focus_index)

func _focus_changed(index:int)->void:
 if is_instance_valid(position_label):
  position_label.text="<   %02d / %02d   >" % [index+1,recipes.size()]

func _enter(index:int)->void:
 if mode==3:return
 var id:String=recipes[index].get("world_id","")
 if not id.is_empty():app._inspect_world(id)

func _fixed_buttons()->Dictionary:
 var result:Dictionary={}
 for node:Node in app.find_children("*","Button",true,false):
  if str(node.name).begins_with("World_"):continue
  var rect:Rect2=node.get_global_rect()
  result[str(node.name)]={"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"visible":node.is_visible_in_tree(),"pressed":node.pressed.get_connections().size()}
 return result

func _capture()->void:
 if not output.is_absolute_path() or DisplayServer.get_name()=="headless":push_error("Capture needs graphical renderer and absolute directory");quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 var shots:Array=[]
 for value in 4:
  _select(value)
  if value==1:fan.set_focus(5,false)
  if value==2:fan.set_focus(14,false)
  await process_frame
  await create_timer(.3).timeout
  RenderingServer.force_draw(false)
  await RenderingServer.frame_post_draw
  var path:String=output.path_join(SHOTS[value]+".png")
  root.get_texture().get_image().save_png(path)
  shots.append({"image":SHOTS[value]+".png","count":recipes.size(),"focus":fan.focus_index,"stacked":fan.is_stacked()})
  print("PAINTED_UI_CAPTURE ",SHOTS[value]," cards=",recipes.size()," stacked=",fan.is_stacked())
 var fixed_same:bool=_fixed_before==_fixed_buttons()
 var resource_fit:bool=true
 var resource_evidence:Array=[]
 for node:Node in app.find_children("ResourceAmount","Label",true,false):
  if not node.is_visible_in_tree():continue
  var measured:float=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
  var fits:bool=measured<=node.size.x
  resource_fit=resource_fit and fits
  resource_evidence.append({"text":node.text,"needed_width":measured,"available_width":node.size.x,"fits":fits})
 var file:=FileAccess.open(output.path_join("painted-evidence.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"shots":shots,"unchanged_non_world_buttons":fixed_same,"resource_text_fits":resource_fit,"resource_text":resource_evidence,"button_count":_fixed_before.size(),"before":_fixed_before,"after":_fixed_buttons(),"scope":"world card carrier and appearance only; sample copies are not Session worlds"},"\t"));file.close()
 print("NON_WORLD_BUTTONS_UNCHANGED ",fixed_same)
 print("RESOURCE_TEXT_FITS ",resource_fit)
 quit(0 if fixed_same and resource_fit else 2)
