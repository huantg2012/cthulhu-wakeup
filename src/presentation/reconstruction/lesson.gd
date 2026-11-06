extends Control
## Replacement presentation; all facts, eligibility and execution use ordinary Session.
const Session = preload("res://src/presentation/session.gd")
const Actions = preload("res://src/presentation/experience_actions.gd")
const Views = preload("res://src/presentation/experience_views.gd")
const Feedback = preload("res://src/presentation/experience_feedback.gd")
const Serif = preload("res://src/presentation/ui/restoration_font.gd")
const ART = "res://docs/art/presentation-rebuild/assets/"
const IDS = ["atlas", "chronicle", "dossier"]
const TITLES = ["谋局图谱", "神谕绘卷", "禁仪案卷"]
const READINGS = ["从联系与处境进入一场谋局", "从一个凡人的处境读到你的神谕", "翻阅人物与现实依托的案卷"]
const SAVE_DIR = "user://presentation-rebuild-review"
const POWER_ICONS = {"POWER_LISTEN":"listen", "POWER_DREAM":"dream", "POWER_ORACLE":"oracle", "POWER_BESTOW":"bestow", "POWER_APPOINT":"appoint", "POWER_SACRIFICE":"sacrifice", "POWER_BREACH":"breach", "POWER_SEED":"seed", "POWER_ANCHOR":"anchor", "POWER_VEIL":"veil", "POWER_TRANSFER":"transfer", "POWER_MANIFEST":"manifest"}
const PALETTES = [
 {"bg":Color("182420"),"paper":Color("182420"),"ink":Color("e5ddc7"),"text":Color("e5ddc7"),"muted":Color("a6b3a4"),"accent":Color("a8c5b7"),"risk":Color("e7a38b"),"surface":Color("27372f"),"line":Color("617569")},
 {"bg":Color("252c40"),"paper":Color("e8d8b6"),"ink":Color("302c35"),"text":Color("eee2c8"),"muted":Color("bdc0c8"),"accent":Color("893f32"),"risk":Color("893f32"),"surface":Color("39445d"),"line":Color("bda681")},
 {"bg":Color("16372d"),"paper":Color("eee0bb"),"ink":Color("16372d"),"text":Color("eee0bb"),"muted":Color("b6c4ae"),"accent":Color("9e3e2c"),"risk":Color("9e3e2c"),"surface":Color("294d3e"),"line":Color("91a084")},
]
var session = Session.new(SAVE_DIR)
var projection: Dictionary = {}
var _actions = Actions.new()
var _views = Views.new()
var _feedback = Feedback.new()
var variant: int = 0
var page: String = "overview"
var prayer: Dictionary = {}
var mode: String = "shallow"
var selections: Dictionary = {"shallow":{},"deep":{}}
var receipt: Array[String] = []
var error_text: String = ""
var seed_value: int = 1
var _canvas: Control
var _font: Font
var _sans: Font
var _busy: bool = false
var _textures: Dictionary = {}
var _power: String = ""
var _start_path: String = ""
var _working_path: String = ""
var _return_focus: String = ""
var _person_origin: String = "overview"
var _world_origin: String = "overview"
var _world_focus: String = "WorldInfo"

func _ready() -> void:
 _font = Serif.regular()
 var sans = SystemFont.new()
 sans.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC"])
 sans.allow_system_fallback = true
 _sans = sans
 get_window().title = "邪神苏醒 · 表现重构对比"
 if DisplayServer.get_name() != "headless":
  get_window().size = Vector2i(1920,1080)
  get_window().move_to_center()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--variant="): variant = clampi(arg.trim_prefix("--variant=").to_int(),0,2)
  if arg.begins_with("--seed="): seed_value = arg.trim_prefix("--seed=").to_int()
 reset_sample()

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 var focused = get_viewport().gui_get_focus_owner()
 if focused is LineEdit or focused is TextEdit: return
 if event.keycode in [KEY_1,KEY_2,KEY_3]:
  set_variant(int(event.keycode-KEY_1))
  get_viewport().set_input_as_handled()
 elif event.keycode == KEY_ESCAPE:
  if page == "person": back_from_person()
  elif page == "world": _back_world()
  elif page == "consequences": show_page("detail","ReadConsequences")
  elif page == "confirm": show_page("detail","Respond")
  elif page != "overview": show_page("overview")
  get_viewport().set_input_as_handled()

func title(id: String) -> String:
 return session.object_title(id)

func reset_sample() -> void:
 _busy = true
 var directory = SAVE_DIR.path_join("seed-%d-%d" % [seed_value,Time.get_ticks_usec()])
 session = Session.new(directory)
 var started: Dictionary = session.start_new(seed_value)
 if not started.get("ok",false): error_text = str(started.get("error","无法建立审阅局面"))
 else:
  var p: Dictionary = session.project()
  if p.phase == "events" and p.events.is_empty(): session.progress()
  _start_path = directory.path_join("start.json")
  session.save_game(_start_path)
  _working_path = directory.path_join("working.json")
  session.slot = _working_path
 _select_prayer()
 page = "overview"; mode = "shallow"; selections = {"shallow":{},"deep":{}}; receipt = []
 _busy = false
 render()

func _select_prayer() -> void:
 projection = session.project()
 prayer = {}
 for item: Dictionary in projection.get("prayers",[]):
  if item.get("status") == "open": prayer = item; break

func restore_sample() -> void:
 if _start_path.is_empty(): return
 var loaded: Dictionary = session.continue_game(_start_path)
 if loaded.get("ok",false):
  session.slot = _working_path
  _select_prayer()
  page = "overview"; mode = "shallow"; selections = {"shallow":{},"deep":{}}; receipt = []; error_text = ""
 else: error_text = str(loaded.get("error","恢复失败"))
 render()

func set_variant(value: int) -> void:
 if _busy or value < 0 or value > 2: return
 variant = value
 render()

func show_page(value: String, focus_id: String = "") -> void:
 page = value
 render()
 if not focus_id.is_empty(): _focus.call_deferred(focus_id)

func _focus(id: String) -> void:
 var target = _canvas.find_child(id,true,false)
 if target is Control and is_instance_valid(target): target.grab_focus()

func _palette() -> Dictionary:
 return PALETTES[variant]

func _rect(parent: Node, id: String, bounds: Rect2) -> Control:
 var c = Control.new()
 c.name = id; c.position = bounds.position; c.size = bounds.size
 parent.add_child(c)
 return c

func _paper(parent: Node, id: String, bounds: Rect2, color: Color) -> Panel:
 var c = Panel.new()
 c.name = id; c.position = bounds.position; c.size = bounds.size
 var box = StyleBoxFlat.new()
 box.bg_color = color
 c.add_theme_stylebox_override("panel",box)
 parent.add_child(c)
 return c

func _label(parent: Node, id: String, value: String, bounds: Rect2, font_size: int = 18, color: Color = Color.TRANSPARENT, serif: bool = false) -> Label:
 var c = Label.new()
 c.name = id; c.text = value; c.position = bounds.position; c.size = bounds.size
 c.add_theme_font_override("font",_font if serif else _sans)
 c.add_theme_font_size_override("font_size",font_size)
 c.add_theme_color_override("font_color",_palette().text if color == Color.TRANSPARENT else color)
 c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 c.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(c)
 c.size = bounds.size
 c.set_meta("layout_bounds",bounds)
 if id in ["MandatoryCost","OutcomeRisk"]:
  _image(parent,"RiskIcon_"+id,_icon("alert"),Rect2(bounds.position+Vector2(-21,4),Vector2(16,16)),color,false)
 return c

func _button(parent: Node, id: String, value: String, bounds: Rect2, callback: Callable, primary: bool = false, paper: bool = false) -> Button:
 var p = _palette()
 var c = Button.new()
 c.name = id; c.text = value; c.position = bounds.position; c.size = bounds.size
 c.add_theme_font_override("font",_sans)
 c.add_theme_font_size_override("font_size",16)
 var foreground: Color = p.paper if primary else (p.ink if paper else p.text)
 for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: c.add_theme_color_override(state,foreground)
 c.add_theme_color_override("font_disabled_color",foreground)
 for state: String in ["normal","hover","pressed","disabled","focus"]:
  var style = StyleBoxFlat.new()
  style.bg_color = p.ink if primary else (p.paper.darkened(.035) if paper else p.surface)
  style.content_margin_left = 8; style.content_margin_right = 8
  style.border_color = (foreground if primary else (p.ink if paper else p.text)) if state in ["hover","focus"] else p.line
  style.border_width_bottom = 3 if state in ["hover","focus"] else 0
  if state == "pressed": style.bg_color = p.ink if primary else (p.paper if paper else p.surface)
  c.add_theme_stylebox_override(state,style)
 var icon_id: String = {"InspectPerson":"person","Respond":"execute","ConfirmPrayer":"execute","BackToPrayer":"back","CancelPrayer":"back"}.get(id,"")
 if not icon_id.is_empty():
  c.icon = _texture(_icon(icon_id))
  c.expand_icon = true
  c.add_theme_constant_override("icon_max_width",20)
  for icon_state: String in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color","icon_disabled_color"]:
   c.add_theme_color_override(icon_state,foreground)
 c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 c.pressed.connect(callback)
 parent.add_child(c)
 return c

func _texture(path: String) -> Texture2D:
 if _textures.has(path): return _textures[path]
 if not FileAccess.file_exists(path): return null
 var texture: Texture2D = null
 if ResourceLoader.exists(path): texture = load(path)
 if texture == null:
  var data = Image.load_from_file(path)
  if data != null: texture = ImageTexture.create_from_image(data)
 _textures[path] = texture
 return texture

func _image(parent: Node, id: String, path: String, bounds: Rect2, tint: Color = Color.WHITE, cover: bool = true) -> TextureRect:
 var c = TextureRect.new()
 c.name = id; c.position = bounds.position; c.size = bounds.size
 c.texture = _texture(path)
 c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 c.modulate = tint; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(c)
 return c

func _line(body: VBoxContainer, value: String, font_size: int = 18, color: Color = Color.TRANSPARENT) -> Label:
 var c = Label.new()
 c.text = value
 c.add_theme_font_override("font",_sans)
 c.add_theme_font_size_override("font_size",font_size)
 c.add_theme_color_override("font_color",_palette().ink if color == Color.TRANSPARENT else color)
 c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_child(c)
 return c

func _scroll_body(parent: Control, bounds: Rect2) -> VBoxContainer:
 var scroll = ScrollContainer.new()
 scroll.name = "ReadingScroll"; scroll.position = bounds.position; scroll.size = bounds.size
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 parent.add_child(scroll)
 var body = VBoxContainer.new()
 body.add_theme_constant_override("separation",9)
 body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(body)
 return body

func _petitioner() -> String:
 return str(prayer.get("descriptor",{}).get("subjects",{}).get("petitioner",""))

func _world() -> Dictionary:
 return _views._find(self,"domains",str(prayer.get("descriptor",{}).get("domain","")))

func _row() -> Dictionary:
 if prayer.is_empty(): return {}
 var key = str(prayer.key)+"/"+mode
 var selection: Dictionary = selections[mode]
 var row: Dictionary = session.action_entry(key,selection)
 for step: int in range(4):
  if row.is_empty() or not _actions._normalize_unique(row.get("fields",[]),selection): break
  row = session.action_entry(key,selection)
 return row

func _effects() -> Dictionary:
 return _actions.semantics.prayer(session.catalog,str(prayer.get("card",{}).get("content_id","")),mode)

func render() -> void:
 if is_instance_valid(_canvas):
  remove_child(_canvas); _canvas.queue_free()
 var p = _palette()
 _canvas = _rect(self,"CandidateRoot",Rect2(0,0,1280,720))
 _paper(_canvas,"Ground",Rect2(0,0,1280,720),p.bg)
 _review_header()
 _game_header()
 _scene_composition()
 _render_reading()
 _power_dock()
 if not error_text.is_empty():
  _paper(_canvas,"ErrorSupport",Rect2(300,652,680,35),p.ink)
  _label(_canvas,"Error",error_text,Rect2(310,655,660,28),15,p.paper)
 _canvas.modulate.a = .82
 create_tween().tween_property(_canvas,"modulate:a",1.0,.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _review_header() -> void:
 _paper(_canvas,"ReviewBar",Rect2(0,0,1280,40),Color("121615"))
 _label(_canvas,"ReviewLabel","表现对比 · 独立审阅局",Rect2(18,8,194,24),13,Color("cacbbc"))
 for i: int in range(3):
  _button(_canvas,"Variant%d" % i,"%d  %s" % [i+1,TITLES[i]],Rect2(224+i*152,4,144,32),set_variant.bind(i),i==variant)
 _button(_canvas,"ResetSample","重置同一局面",Rect2(880,4,140,32),restore_sample)
 _button(_canvas,"ChangeSeed","换种子 · %d" % seed_value,Rect2(1028,4,124,32),func() -> void:
  seed_value += 1; reset_sample())
 _button(_canvas,"ProductionReference","旧版补立绘",Rect2(1160,4,110,32),func() -> void:
  OS.create_process(OS.get_executable_path(),PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tools/presentation-rebuild/baseline.gd"])))

func _game_header() -> void:
 var p = _palette()
 _label(_canvas,"GameName","邪神苏醒",Rect2(30,50,188,44),28,p.text,true)
 _label(_canvas,"Chapter","第 %s 轮 · %s" % [projection.get("turn",""),projection.get("phase_title","")],Rect2(232,61,290,30),16,p.muted)
 var names = ["低语","信仰","苏醒"]
 var values = [str(projection.get("whispers",0)),"%s / %s" % [projection.get("faith",0),projection.get("capacity",0)],str(projection.get("awakening",0))]
 var icons = ["whispers","faith","awakening"]
 for i: int in range(3):
  var x = 750+i*165
  _image(_canvas,"ResourceIcon%d" % i,_icon(icons[i]),Rect2(x,60,25,27),p.text,false)
  _label(_canvas,"Resource%d" % i,names[i]+"  "+values[i],Rect2(x+32,58,138,35),18,p.text)

func _icon(id: String) -> String:
 var path = ART+"icons/"+IDS[variant]+"/"+id+".svg"
 return path if FileAccess.file_exists(path) else "res://tools/echoes-art-master/icons/"+id+".svg"

func _open_person() -> void:
 _person_origin = page if page in ["overview","detail","result"] else "overview"
 var current = get_viewport().gui_get_focus_owner()
 _return_focus = str(current.name) if current != null else "InspectPerson"
 show_page("person")

func back_from_person() -> void:
 show_page(_person_origin,_return_focus)

func _open_world() -> void:
 _world_origin = page
 show_page("world")

func _back_world() -> void:
 show_page(_world_origin,_world_focus)

func _scene_composition() -> void:
 var p = _palette()
 var world_name = str(_world().get("title","尚未建立世界联系"))
 var person = title(_petitioner()) if not _petitioner().is_empty() else "尚无祈求者"
 var request = str(prayer.get("title","本轮未闻祈求"))
 var scene_path = ART+IDS[variant]+"-scene.png"
 var portrait_path = ART+IDS[variant]+"-portrait.png"
 if variant == 0:
  _label(_canvas,"SceneChapter","已建立的联系",Rect2(35,112,300,25),16,p.accent)
  _image(_canvas,"SceneImage",scene_path,Rect2(34,149,638,329))
  _paper(_canvas,"WorldCaption",Rect2(34,432,638,46),p.bg)
  _button(_canvas,"WorldInfo",world_name,Rect2(48,437,350,34),_open_world)
  _label(_canvas,"WorldScale","时空域 · 已知联系",Rect2(456,441,200,26),14,p.muted)
  var relation = Line2D.new()
  relation.name = "KnownPrayerContact"
  relation.points = PackedVector2Array([Vector2(360,478),Vector2(360,484),Vector2(110,484),Vector2(110,491)])
  relation.default_color = p.accent
  relation.width = 2
  _canvas.add_child(relation)
  relation.set_meta("meaning","Existing prayer contact between this world and this petitioner; no shared geography.")
  _image(_canvas,"Portrait",portrait_path,Rect2(50,491,109,115),Color.WHITE,false)
  _label(_canvas,"PersonName",person,Rect2(181,489,460,34),21,p.text,true)
  _label(_canvas,"PersonContext",request,Rect2(181,530,450,43),26,p.paper,true)
  _button(_canvas,"InspectPerson","查看此人",Rect2(181,577,155,32),_open_person)
 elif variant == 1:
  _image(_canvas,"SceneImage",scene_path,Rect2(0,106,1280,720))
  _paper(_canvas,"StoryCaption",Rect2(848,125,398,82),Color(p.bg,.94))
  _label(_canvas,"WorldScale","你感知到的现实",Rect2(866,130,360,23),15,p.muted)
  _button(_canvas,"WorldInfo",world_name,Rect2(866,164,360,34),_open_world)
  var face_safe = _rect(_canvas,"FaceSafeArea",Rect2(115,149,292,181))
  face_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
  face_safe.set_meta("purpose","Source portrait protection, observed source composition; no UI support may overlap.")
 else:
  _paper(_canvas,"PortraitPaper",Rect2(30,128,257,479),p.paper)
  _image(_canvas,"Portrait",portrait_path,Rect2(43,151,230,340),Color.WHITE,false)
  _label(_canvas,"PersonContext","求告者",Rect2(50,507,213,28),16,p.ink)
  _label(_canvas,"PersonName",person,Rect2(50,536,215,70),21,p.ink,true)
  _image(_canvas,"SceneImage",scene_path,Rect2(309,128,370,230))
  _label(_canvas,"WorldScale","来处",Rect2(314,375,310,25),15,p.muted)
  _button(_canvas,"WorldInfo",world_name,Rect2(310,409,370,38),_open_world)
  _label(_canvas,"DossierQuote",request,Rect2(314,474,352,82),30,p.text,true)
  _button(_canvas,"InspectPerson","翻阅人物卷宗",Rect2(310,565,211,37),_open_person)
 _label(_canvas,"ArtNote","人物与文化造型为候选诠释",Rect2(37,613,620,18),12,p.muted)

func _render_reading() -> void:
 if variant == 1:
  _chronicle_reading()
  return
 var p = _palette()
 var x: float = 704
 var width: float = 550
 var paper = _paper(_canvas,"ReadingPaper",Rect2(x,113,width,495),p.paper)
 _label(paper,"ReadingEyebrow",{"overview":"凡人的声音","detail":"回应祈求","confirm":"不可撤回的回应","person":"关联人物","world":"世界情报","result":"神迹回声","power":"权能查阅"}.get(page,""),Rect2(23,15,width-46,25),14,p.ink)
 match page:
  "overview": _overview(paper,width)
  "detail": _detail(paper,width)
  "confirm": _confirm(paper,width)
  "person": _person_page(paper,width)
  "world": _world_page(paper,width)
  "result": _result_page(paper,width)
  "power": _power_page(paper,width)

func _overview(parent: Control, width: float) -> void:
 var p = _palette()
 var spent: bool = projection.get("prayer_response_spent",false)
 _label(parent,"MainHeading","本轮所闻" if not spent else "回应已经发生",Rect2(23,48,width-46,45),31,p.ink,true)
 if prayer.is_empty():
  _label(parent,"NoPrayer","这段独立审阅局面当前没有可回应祈求。可换种子或返回正式版。",Rect2(23,115,width-46,130),20,p.ink)
  return
 _label(parent,"PrayerHeading",str(prayer.title),Rect2(23,113,width-46,70),29,p.ink,true)
 _label(parent,"PrayerPerson",title(_petitioner()),Rect2(23,193,width-46,36),18,p.ink)
 _label(parent,"PrayerDue","请求至第 %s 轮" % prayer.card.get("due_turn","?"),Rect2(23,237,width-46,30),16,p.risk)
 var shallow: Dictionary = session.action_entry(str(prayer.key)+"/shallow",{})
 var plea: String = str(shallow.get("details",{}).get("本次求告",""))
 if spent: plea = "本轮唯一回应机会已用。你可以查看实际结果，或重置同一局面比较另一种处理。"
 _label(parent,"PrayerVoice",plea,Rect2(23,284,width-46,95),22,p.ink,true)
 _button(parent,"OpenPrayer","查看实际结果" if spent else "倾听这项祈求",Rect2(23,413,width-46,49),show_page.bind("result" if spent else "detail"),true,true)
 _label(parent,"ResponseCount","本轮至多回应一项 · 查看与比较不消耗资源",Rect2(23,465,width-46,22),13,p.ink)

func _detail(parent: Control, width: float) -> void:
 var p = _palette()
 var row = _row()
 _label(parent,"MainHeading","成功 · "+str(_effects().get("summary","")),Rect2(23,43,width-46,58),18,p.ink)
 _label(parent,"DetailDue","请求至第 %s 轮" % prayer.card.get("due_turn","?"),Rect2(width-170,15,147,25),15,p.risk)
 _mode_buttons(parent,23,108,(width-53)/2)
 var preview: Dictionary = row.get("preview",{})
 var costs: Dictionary = preview.get("preview",{})
 var effects = _effects()
 _probabilities(parent,costs,Rect2(23,153,width-46,49))
 _label(parent,"MandatoryCost","必付 · "+str(effects.get("always","")),Rect2(23,207,width-46,47),17,p.risk)
 _label(parent,"OutcomeRisk",_risk_text(effects),Rect2(23,258,width-46,85),17,p.risk)
 var body = _scroll_body(parent,Rect2(23,351,width-46,41))
 _outcome_lines(body,row,effects)
 var ready: bool = _ready_to_respond(row)
 _label(parent,"FixedPayment",_payment_text(row),Rect2(23,402,width-46,34),16,p.ink if ready else p.risk)
 _button(parent,"BackOverview","收起",Rect2(23,445,90,36),show_page.bind("overview"),false,true)
 _button(parent,"Respond","以%s回应…" % ("浅触" if mode=="shallow" else "深应"),Rect2(125,443,width-148,40),respond.bind(false),true,true).disabled = not ready

func _mode_buttons(parent: Control, x: float, y: float, width: float) -> void:
 for i: int in range(2):
  var next_mode: String = ["shallow","deep"][i]
  var candidate: Dictionary = session.action_entry(str(prayer.key)+"/"+next_mode,selections[next_mode])
  var costs: Dictionary = candidate.get("preview",{}).get("preview",{})
  var caption: String = ("浅触" if i == 0 else "深应")+" · %s低语 / %s信仰" % [costs.get("whispers","—"),costs.get("faith","—")]
  _button(parent,"Mode_"+next_mode,caption,Rect2(x+i*(width+7),y,width,41),func() -> void:
   mode = next_mode; show_page("detail","Mode_"+next_mode),mode == next_mode,true)

func _probabilities(parent: Control, costs: Dictionary, bounds: Rect2) -> void:
 var p = _palette()
 var outcomes: Dictionary = costs.get("outcomes",{})
 for i: int in range(4):
  var outcome: String = _actions.OUTCOMES[i]
  _label(parent,"Probability_"+outcome,_actions.OUTCOME_NAMES[outcome]+"\n"+str(outcomes.get(outcome,"—"))+"%",Rect2(bounds.position+Vector2(i*bounds.size.x/4,0),Vector2(bounds.size.x/4-4,bounds.size.y)),16,p.risk if i>=2 else p.ink)

func _outcome_lines(body: VBoxContainer,row: Dictionary,effects: Dictionary) -> void:
 for label_key: String in ["success","deep"]:
  _line(body,{"success":"成功后","deep":"深刻成功","failure":"失败","disaster":"灾变"}[label_key],16,_palette().risk if label_key in ["failure","disaster"] else _palette().ink)
  _line(body,str(effects.get(label_key,"")),18)
 for field: Dictionary in row.get("fields",[]):
  if field.get("options",[]).is_empty(): continue
  _line(body,str(field.label),18)
  for option: Dictionary in field.options:
   var btn = Button.new()
   btn.text = str(option.get("label",option.id)); btn.add_theme_font_override("font",_sans); btn.add_theme_font_size_override("font_size",18)
   btn.pressed.connect(func() -> void:
    if field.get("multiple",false):
     var list: Array = selections[mode].get(field.key,[])
     if option.id in list: list.erase(option.id)
     else: list.append(option.id)
     selections[mode][field.key] = list
    else: selections[mode][field.key] = option.id
    render())
   body.add_child(btn)

func _risk_text(effects: Dictionary) -> String:
 return "失败 · "+str(effects.get("failure",""))+"\n灾变 · "+str(effects.get("disaster",""))

func _ready_to_respond(row: Dictionary) -> bool:
 return row.get("preview",{}).get("ok",false) and _actions._missing_fields(row.get("fields",[]),selections[mode]).is_empty()

func _payment_text(row: Dictionary) -> String:
 var preview: Dictionary = row.get("preview",{})
 var costs: Dictionary = preview.get("preview",{})
 var missing: Array[String] = _actions._missing_fields(row.get("fields",[]),selections[mode])
 if not _ready_to_respond(row): return "请先选择："+"、".join(missing) if not missing.is_empty() else session.explain_error(str(preview.get("error","当前不可回应")))
 return "支出 %s 低语 · %s 信仰 · 本轮唯一回应" % [costs.get("whispers",0),costs.get("faith",0)]

func respond(confirmed: bool) -> void:
 if _busy or page not in ["detail","confirm"]: return
 var row = _row()
 if row.is_empty(): return
 _busy = true
 var before: Dictionary = session.project()
 var result: Dictionary = session.execute_action(str(row.key),selections[mode].duplicate(true),confirmed)
 if result.get("confirmation",false): page = "confirm"
 elif result.get("ok",false):
  projection = session.project()
  receipt = _feedback.build(self,result,before,projection,str(row.title))
  page = "result"
 else:
  error_text = str(result.get("error","当前不可回应"))
  page = "detail"
 _busy = false
 render()

func _confirm(parent: Control, width: float) -> void:
 var p = _palette()
 _label(parent,"MainHeading","让回应进入现实",Rect2(23,48,width-46,50),29,p.ink,true)
 var body = _scroll_body(parent,Rect2(23,113,width-46,278))
 for line: String in _actions.confirmation_text(self,str(prayer.key)+"/"+mode,selections[mode]).split("\n",false): _line(body,line,18)
 _button(parent,"CancelPrayer","返回比较",Rect2(23,440,145,41),show_page.bind("detail","Respond"),false,true)
 _button(parent,"ConfirmPrayer","确认回应",Rect2(180,440,width-203,41),respond.bind(true),true,true)

func _person_lines(body: VBoxContainer) -> void:
 var person: Dictionary = _views._find(self,"people",_petitioner())
 if person.has("已知范围"): _line(body,str(person["已知范围"]),18)
 if person.has("profile"): _line(body,_views._role(self,person),20)
 if person.has("status"): _line(body,"当前已知处境 · "+str(_views.STATES.get(person.status,person.status)),18)
 if person.has("domain"): _line(body,title(person.domain),18)
 _line(body,"正式成员" if person.get("bound_member",false) else "尚非正式成员",18)
 if person.get("bound_member",false):
  for field: String in ["will","insight","influence","adaptation","loyalty","sanity"]:
   if person.has(field): _line(body,str({"will":"意志","insight":"洞察","influence":"影响","adaptation":"适应","loyalty":"忠诚","sanity":"理智"}[field])+"  "+str(person[field]),18)

func _person_page(parent: Control, width: float) -> void:
 _label(parent,"MainHeading",title(_petitioner()),Rect2(23,48,width-46,80),27,_palette().ink,true)
 _person_lines(_scroll_body(parent,Rect2(23,140,width-46,270)))
 _button(parent,"BackToPrayer","返回原任务",Rect2(23,438,width-46,43),back_from_person,true,true)

func _world_lines(body: VBoxContainer) -> void:
 var world = _world()
 for field: String in _views.WORLD_METRICS:
  var metric: Dictionary = _views.metric_display(world,field)
  _line(body,str(_views.WORLD_METRICS[field])+"  "+str(metric.get("value","未掌握")),20)
  _line(body,str(metric.get("observation",""))+" · 查看不会刷新情报",15)
 for institution: Dictionary in projection.get("institutions",[]):
  if institution.get("domain") == world.get("id"): _line(body,str(institution.get("title","")),18)

func _world_page(parent: Control, width: float) -> void:
 _label(parent,"MainHeading",str(_world().get("title","")),Rect2(23,48,width-46,55),29,_palette().ink,true)
 _world_lines(_scroll_body(parent,Rect2(23,120,width-46,280)))
 _button(parent,"BackWorld","返回现状",Rect2(23,438,width-46,43),_back_world,true,true)

func _result_page(parent: Control, width: float) -> void:
 var p = _palette()
 _label(parent,"MainHeading","回应已经发生",Rect2(23,48,width-46,54),30,p.ink,true)
 var body = _scroll_body(parent,Rect2(23,119,width-46,279))
 for line: String in receipt: _line(body,line,20)
 if receipt.is_empty(): _line(body,"此局面尚未执行新的回应。",18)
 _label(parent,"SpentResponse","本轮回应机会已用" if projection.get("prayer_response_spent",false) else "本轮尚未回应",Rect2(23,402,width-46,30),18,p.risk)
 _button(parent,"ClosePrayerResult","返回现状",Rect2(23,440,width-46,41),show_page.bind("overview"),true,true)

func _power_dock() -> void:
 var p = _palette()
 _paper(_canvas,"PowerGround",Rect2(0,632,1280,88),p.bg)
 if variant == 1:
  _button(_canvas,"ReadPowers","十二权能 · 查阅",Rect2(1033,641,219,44),func() -> void:
   _power = str(session.catalog.tables.powers.keys()[0]); show_page("powers"))
  _label(_canvas,"ReviewHint",READINGS[variant]+" · 数字键 1 / 2 / 3 切换",Rect2(32,649,900,25),15,p.muted)
  return
 _label(_canvas,"PowerLabel","权能",Rect2(28,642,52,30),18,p.text,true)
 var index: int = 0
 for id: String in session.catalog.tables.powers:
  var definition: Dictionary = session.catalog.tables.powers[id]
  var x: float = 96+index*96
  var c = _button(_canvas,"Power_"+id,"",Rect2(x,633,88,66),func() -> void:
   _power = id; show_page("power"))
  var locked: bool = int(projection.get("awakening",0)) < int(definition.unlock_awakening)
  _image(c,"PowerImage",_icon(POWER_ICONS.get(id,"ritual")),Rect2(28,4,30,30),p.muted if locked else p.text,false)
  _label(c,"PowerTitle",str(definition.name)+(" · 未启" if locked else ""),Rect2(0,38,88,22),15,p.muted if locked else p.text)
  index += 1
 _label(_canvas,"ReviewHint",READINGS[variant]+" · 数字键 1 / 2 / 3 切换",Rect2(32,701,1100,18),11,p.muted)

func _power_lines(body: VBoxContainer) -> void:
 var power: Dictionary = session.catalog.tables.powers.get(_power,{})
 _line(body,"规则查阅 · 此对比样本仅执行祈求回应",16)
 _line(body,"解锁条件  苏醒 %s / %s" % [projection.get("awakening",0),power.get("unlock_awakening",0)],18)
 _line(body,str(power.get("target_requirement","")),20)
 _line(body,"支出 %s 低语 · %s 信仰" % [power.get("whispers",0),power.get("faith",0)],18)
 _line(body,"实际作用",16)
 _line(body,str(power.get("success","")),18)
 _line(body,str(power.get("notes","")),18)

func _power_page(parent: Control, width: float) -> void:
 _label(parent,"MainHeading",str(session.catalog.tables.powers.get(_power,{}).get("name","")),Rect2(23,48,width-46,54),32,_palette().ink,true)
 _power_lines(_scroll_body(parent,Rect2(23,118,width-46,287)))
 _button(parent,"BackPower","返回现状",Rect2(23,438,width-46,43),show_page.bind("overview"),true,true)

func _chronicle_reading() -> void:
 var p = _palette()
 var sheet = _paper(_canvas,"ReadingPaper",Rect2(30,355,1220,253),p.paper)
 var titles = {"overview":"凡人的声音","detail":"回应祈求","confirm":"不可撤回的回应","person":"关联人物","world":"世界情报","result":"神迹回声","power":"权能查阅","powers":"十二权能","consequences":"回应后果与协助"}
 _label(sheet,"ReadingEyebrow",title(_petitioner()) if page == "detail" else str(titles.get(page,"")),Rect2(22,13,350,25),15,p.ink)
 _button(sheet,"InspectPerson","查看人物",Rect2(1062,10,130,32),_open_person,false,true)
 if page in ["overview","detail"]:
  _label(sheet,"MainHeading",str(prayer.get("title","本轮未闻祈求")),Rect2(22,44,350,81),31,p.ink,true)
  var spent: bool = projection.get("prayer_response_spent",false)
  var row: Dictionary = session.action_entry(str(prayer.get("key",""))+"/shallow",{})
  if page == "overview": _label(sheet,"PrayerVoice",str(row.get("details",{}).get("本次求告","本轮回应机会已用。")),Rect2(22,130,350,76),20,p.ink,true)
  _label(sheet,"PrayerDue","请求至第 %s 轮" % prayer.get("card",{}).get("due_turn","?"),Rect2(22,215,350,24),15,p.risk)
  if page == "overview":
   _label(sheet,"ResponseMeaning","你可以触碰这份欲望。\n回应的代价与后果，会在选择前展开。",Rect2(428,55,460,116),24,p.ink,true)
   _button(sheet,"OpenPrayer","查看实际结果" if spent else "倾听这项祈求",Rect2(939,99,253,58),show_page.bind("result" if spent else "detail"),true,true)
   _label(sheet,"ResponseCount","本轮至多回应一项",Rect2(939,173,253,30),17,p.ink)
  else:
   var detail_row = _row()
   var benefit = _paper(_canvas,"BenefitPaper",Rect2(847,216,399,128),p.paper)
   _label(benefit,"BenefitSummary","成功 · "+str(_effects().get("summary","")),Rect2(17,12,365,107),18,p.ink)
   _mode_buttons(sheet,411,16,226)
   _probabilities(sheet,detail_row.get("preview",{}).get("preview",{}),Rect2(411,68,462,49))
   var effects = _effects()
   _label(sheet,"OutcomeRisk",_risk_text(effects),Rect2(22,126,350,83),17,p.risk)
   _label(sheet,"MandatoryCost","必付 · "+str(effects.get("always","")),Rect2(411,129,470,68),18,p.risk)
   _button(sheet,"Respond","以%s回应…" % ("浅触" if mode=="shallow" else "深应"),Rect2(936,145,255,50),respond.bind(false),true,true).disabled = not _ready_to_respond(detail_row)
   _label(sheet,"FixedPayment",_payment_text(detail_row),Rect2(936,63,260,69),17,p.ink)
   _button(sheet,"BackOverview","收起",Rect2(936,205,255,33),show_page.bind("overview"),false,true)
   _button(sheet,"ReadConsequences","完整后果与协助",Rect2(411,202,462,36),show_page.bind("consequences"),false,true)
 elif page == "confirm":
  _label(sheet,"MainHeading","让回应进入现实",Rect2(22,48,330,105),32,p.ink,true)
  var body = _scroll_body(sheet,Rect2(406,18,486,217))
  for line: String in _actions.confirmation_text(self,str(prayer.key)+"/"+mode,selections[mode]).split("\n",false): _line(body,line,18)
  _button(sheet,"ConfirmPrayer","确认回应",Rect2(936,82,255,55),respond.bind(true),true,true)
  _button(sheet,"CancelPrayer","返回比较",Rect2(936,151,255,43),show_page.bind("detail","Respond"),false,true)
 elif page == "person":
  _label(sheet,"MainHeading",title(_petitioner()),Rect2(22,48,340,116),28,p.ink,true)
  _person_lines(_scroll_body(sheet,Rect2(406,18,486,217)))
  _button(sheet,"BackToPrayer","返回原任务",Rect2(936,145,255,50),back_from_person,true,true)
 elif page == "world":
  _label(sheet,"MainHeading",str(_world().get("title","")),Rect2(22,48,340,116),28,p.ink,true)
  _world_lines(_scroll_body(sheet,Rect2(406,18,486,217)))
  _button(sheet,"BackWorld","返回现状",Rect2(936,145,255,50),_back_world,true,true)
 elif page == "result":
  _label(sheet,"MainHeading","回应已经发生",Rect2(22,48,340,65),32,p.ink,true)
  _label(sheet,"SpentResponse","本轮回应机会已用",Rect2(22,156,340,45),18,p.risk)
  var body = _scroll_body(sheet,Rect2(406,18,486,217))
  for line: String in receipt: _line(body,line,20)
  _button(sheet,"ClosePrayerResult","返回现状",Rect2(936,145,255,50),show_page.bind("overview"),true,true)
 elif page == "consequences":
  _label(sheet,"MainHeading",str(prayer.get("title","")),Rect2(22,48,340,90),28,p.ink,true)
  _outcome_lines(_scroll_body(sheet,Rect2(406,18,486,217)),_row(),_effects())
  _button(sheet,"BackConsequences","返回回应准备",Rect2(936,145,255,50),show_page.bind("detail","ReadConsequences"),true,true)
 elif page in ["power","powers"]:
  var list = _scroll_body(sheet,Rect2(22,48,333,182))
  for id: String in session.catalog.tables.powers:
   var c = Button.new()
   c.name = "Power_"+id; c.text = session.catalog.tables.powers[id].name
   c.add_theme_font_override("font",_sans); c.add_theme_font_size_override("font_size",18)
   c.pressed.connect(func() -> void: _power=id; show_page("powers"))
   list.add_child(c)
  _power_lines(_scroll_body(sheet,Rect2(406,18,486,217)))
  _button(sheet,"BackPower","返回现状",Rect2(936,145,255,50),show_page.bind("overview"),true,true)
