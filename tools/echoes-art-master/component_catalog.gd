extends Control
## Live catalogue of the same components used by the scene. No screenshot tiles.
const Components = preload("res://src/presentation/ui/ui_components.gd")
const Composites = preload("res://src/presentation/ui/ui_composites.gd")
const DockEntries = preload("res://src/presentation/ui/dock_content.gd")
const RoundAction = preload("res://src/presentation/ui/round_action_button.gd")
const FontSource = preload("res://src/presentation/ui/restoration_font.gd")
var ui: RefCounted
var content: Control
var keyboard_input := false
var page := 0

func _ready() -> void:
	get_window().title = "幽界群像 · 共源控件展示 · 规范 V2 / V6"
	get_window().size = Vector2i(1672,941)
	get_window().content_scale_size = Vector2i(1672,941)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_setup_components()
	ui.fill(self,"Background",Rect2(0,0,1672,941),Color("081316"))
	ui.label(self,"Title","幽界群像 · 共源控件展示",Rect2(32,18,900,45),28,Color("f2dba8"))
	ui.label(self,"Authority","唯一规范 visual-system.md · V2 / V6　　控件可直接悬停、点击和键盘操作",Rect2(32,64,1500,32),18,Color("a9afa5"))
	ui.button(self,"BasicPage","基础与状态",Rect2(1140,20,210,44),func(): show_page(0))
	ui.button(self,"CompositionPage","内容组合",Rect2(1370,20,210,44),func(): show_page(1))
	content = Control.new()
	content.position = Vector2(32,118)
	content.size = Vector2(1608,780)
	add_child(content)
	show_page(0)

func _setup_components() -> void:
	ui = Components.new(FontSource.regular(),func() -> bool: return keyboard_input)
	var base := Theme.new()
	base.default_font = ui.fonts.heading
	base.default_font_size = 20
	theme = base

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		keyboard_input = false
	elif event is InputEventKey and event.pressed and not event.meta_pressed and not event.ctrl_pressed and not event.alt_pressed:
		if event.keycode in [KEY_TAB,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ENTER,KEY_SPACE]:
			keyboard_input = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button:
		ui.sync_focus_style(focused)
		focused.queue_redraw()

func show_page(index: int) -> void:
	page = index
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if page == 0:
		_build_basics()
	else:
		_build_compositions()

func _heading(title: String, at: Vector2) -> void:
	ui.label(content,"Heading",title,Rect2(at,Vector2(1500,32)),21,Color("e5c98d"))

func _build_basics() -> void:
	_heading("V2 · 实际文字色与图标语义",Vector2.ZERO)
	var colors: Array[Color] = [Components.BONE,Components.MUTED,Components.GOLD,Components.GOLD_HI,Components.CYAN,Components.RISK,Components.VIOLET,Components.BOUND]
	var names: Array[String] = ["正文","辅助","操作","强调","世界关联","风险","神意","绑定"]
	for i: int in range(colors.size()):
		var x := float(i*193)
		ui.fill(content,"Swatch",Rect2(x,42,174,33),colors[i])
		ui.label(content,"ColorName",names[i]+"  #"+colors[i].to_html(false),Rect2(x,78,192,27),16,colors[i])
	_heading("C04 · 普通按钮状态（固定外观陈列，取自同一控件样式）",Vector2(0,128))
	var states: Array[String] = ["normal","hover","pressed","focus","disabled"]
	var captions: Array[String] = ["普通","悬停","按住","键盘焦点","不可用"]
	for i: int in range(states.size()):
		var x := float(i*250)
		ui.label(content,"StateName",captions[i],Rect2(x,168,220,28),17,Components.MUTED)
		var button: Button = ui.button(content,"State_"+states[i],"管理教团",Rect2(x,203,210,45),func(): pass)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal",ui.unframed_style(states[i],true))
		if states[i] == "disabled": button.disabled = true
	_heading("C03 / C04 · 真实输入区（可操作）",Vector2(0,282))
	ui.button(content,"LiveAction","查看来源",Rect2(0,326,210,45),func():
		content.get_node("LiveResult").text = "已触发查看意图 · 展示")
	ui.label(content,"LiveResult","点击后松开恢复，Tab 显示焦点",Rect2(0,380,410,32),17,Components.MUTED)
	ui.search_field(content,"Search","查找已联系世界",Rect2(450,326,300,40))
	ui.icon(content,"SearchIcon","search",Rect2(460,334,22,22))
	var action: Button = RoundAction.new()
	action.name = "RoundAction"
	action.position = Vector2(1280,282)
	action.size = Vector2(222,150)
	action.keyboard_focus_query = func() -> bool: return keyboard_input
	content.add_child(action)
	_heading("C19 · 共用图标　　C20 · 实际承托与边界",Vector2(0,460))
	var icons: Array[String] = ["whispers","faith","awakening","barrier","pollution","alert","stability","listen","dream","sacrifice"]
	for i: int in range(icons.size()):
		ui.icon(content,"Icon_"+icons[i],icons[i],Rect2(i*76,510,48,48))
	ui.soft_support(content,"Support",Rect2(0,585,730,100),Color(0.008,0.016,0.018,0.7))
	ui.label(content,"SupportCaption","局部渐隐承托 · 文字与图形保持独立",Rect2(40,616,650,35),22,Components.BONE)
	ui.separator(content,"MetalTop",Rect2(830,525,650,6),"dock_top")
	ui.separator(content,"MetalBottom",Rect2(830,626,650,6),"dock_bottom")
	ui.label(content,"BoundaryCaption","上下边界来自不同纹理采样",Rect2(850,560,570,34),20,Components.BONE)

func _build_compositions() -> void:
	_heading("C02 / C06 · 图文条目与祈求摘要",Vector2.ZERO)
	_build_shared_examples()
	_heading("尚待提取／制作的内容组合",Vector2(0,600))
	ui.label(content,"Pending","C09 结果预览　C10 行动底部　C11 关系阅读　C12 进度条款　C13 维护清单\nC15 回执　C16 完整对话框　C17 对照　C18 历史列表\n现有流程局部仍在样板中；此处保留制作缺口，按唯一规范 V6 继续提取。",Rect2(0,642,1500,110),19,Components.MUTED,false,true)

func _build_shared_examples() -> void:
	var landscape: Texture2D = ui.skin.source_region(Rect2(480,270,610,264))
	for i: int in range(2):
		var row: Button = Composites.world_entry(ui,content,"WorldExample_%d"%i,{"name":"镜证04","hint":"已知教团 · 传教中","tag":"展示数据","selected":i==1},landscape,func(): pass)
		row.position = Vector2(i*320,64)
		ui.label(content,"StateCaption","普通" if i==0 else "选中",Rect2(i*320,170,260,28),17,Components.MUTED)
	var prayer_data := {"person":"塞拉 · 祭司","kind":"仪式 · 盐梦02","title":"请回应我们的祭日","due":"第48轮到期"}
	var art: Texture2D = ui.texture("res://docs/art/echoes-ui/round-start-master/restoration-assets/prayer-scenes/sela.png")
	Composites.prayer_card(ui,content,"PrayerExample",Rect2(720,64,354,112),prayer_data,art,ui.fragment_material(Rect2(0,0,1672,941),0.1,1.0),func(): pass)
	_heading("C07 · 世界观察读数",Vector2(0,230))
	Composites.metric(ui,content,"Known",Vector2(0,280),"barrier","屏障","28","45轮确知",true)
	Composites.metric(ui,content,"Estimate",Vector2(240,280),"pollution","污染","50–74","45轮估计",true)
	Composites.metric(ui,content,"Unknown",Vector2(480,280),"alert","察觉","未掌握","未有记录",false)
	ui.label(content,"DockHeading","C14 / C19 · 权能与圣物实例",Rect2(900,230,650,32),21,Components.GOLD)
	var power: Button = DockEntries.power_entry(ui,content,"POWER_LISTEN",{"name":"聆听","unlock_awakening":0},false,func(): pass)
	power.position = Vector2(900,285)
	DockEntries.bind_icon(power,power.get_node("Icon"),func() -> bool: return keyboard_input)
	var locked: Button = DockEntries.power_entry(ui,content,"POWER_MANIFEST",{"name":"降临","unlock_awakening":90},true,func(): pass)
	locked.position = Vector2(1030,285)
	DockEntries.bind_icon(locked,locked.get_node("Icon"),func() -> bool: return keyboard_input,null,Color(0.55,0.58,0.60,0.95))
	var relic: Button = DockEntries.relic_entry(ui,content,0,"根钉","绑定",func(): pass)
	relic.position = Vector2(1160,285)
	DockEntries.bind_icon(relic,relic.get_node("Icon"),func() -> bool: return keyboard_input)
	_heading("C08 · 已知威胁摘要",Vector2(0,390))
	Composites.threat(ui,content,"ThreatExample",Vector2(0,444),"清洗教团 · 第47轮末　　目标：镜证04的教团　　无名信众−20% · 凝聚−10",true)
	ui.label(content,"Semantics","显示数据由调用方提供；图形、承托、排版和交互实例由共用实现生成。",Rect2(0,520,1480,35),19,Components.MUTED)
