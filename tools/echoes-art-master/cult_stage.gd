extends RefCounted
## Isolated T46 art fixture. Member identities and relationships are examples.

const MEMBERS := [
	{"name":"示例成员 甲", "role":"记录者", "status":"整理镜证议会的见闻", "duty":"整理记录，核对来往见证", "relic":"示例透镜"},
	{"name":"示例成员 乙", "role":"护持者", "status":"留意场所的仪式准备", "duty":"协助护持，照看仪式用物", "relic":"示例圣印"},
	{"name":"示例成员 丙", "role":"传信者", "status":"等待回应", "duty":"递送消息，整理往来", "relic":"示例信物"},
	{"name":"示例成员 丁", "role":"见证者", "status":"留在教团场所", "duty":"记录所见", "relic":"示例透镜"},
	{"name":"示例成员 戊", "role":"见证者", "status":"留在教团场所", "duty":"记录所见", "relic":"示例信物"},
	{"name":"示例成员 己", "role":"记录者", "status":"整理见闻", "duty":"核对记录", "relic":"示例透镜"},
	{"name":"示例成员 庚", "role":"护持者", "status":"留意仪式", "duty":"照看用物", "relic":"示例圣印"},
	{"name":"示例成员 辛", "role":"传信者", "status":"等待回应", "duty":"递送消息", "relic":"示例信物"},
]

static func build(app: Control, box: Control) -> void:
	if app.selected_world != 3:
		app._soft_support(box,"ManagementSupport",Rect2(-8,-8,570,665),Color(0.006,0.018,0.019,0.94))
		app._label(box,"Heading","教团管理",Rect2(26,20,480,43),27,app.GOLD_HI,true)
		app._label(box,"Unknown","此世界的教团资料尚未配置。",Rect2(26,90,475,50),21,app.MUTED)
		app._label(box,"FixtureScope","单场景展示夹具 · 未接入 Session",Rect2(26,145,475,35),17,app.MUTED)
		app._button(box,"ReturnWorld","返回世界",Rect2(26,220,165,46),func(): app.show_world(app.selected_world),false,true,20)
		_restore_focus(app,box,"ReturnWorld")
		return
	if bool(app.get_meta("s1_roster",false)):
		_build_roster(app,box)
		var reading: String=str(app.get_meta("s1_read",""))
		var fallback: String="InspectRelic" if reading.is_empty() else ("RelicSource" if reading=="relic" else "ReturnMember")
		_restore_focus(app,box,fallback)
	else:
		_build_overview(app,box)
		_restore_focus(app,box,"Members")

static func _build_overview(app: Control, box: Control) -> void:
	app._soft_support(box,"ManagementSupport",Rect2(-8,-8,570,665),Color(0.006,0.018,0.019,0.94))
	app._label(box,"Heading","教团管理 · 镜证议会04",Rect2(26,20,510,43),27,app.GOLD_HI,true)
	app._label(box,"WorldObservation","镜证04 · 第45轮世界观察",Rect2(26,71,510,32),18,app.CYAN)
	app._label(box,"Metrics","屏障 28　污染 50–74\n察觉 50–74　稳定 50–74",Rect2(26,104,510,68),20,app.BONE,false,true)
	app._label(box,"CultSummary","信众 64　 ·　 凝聚 70",Rect2(26,191,510,35),23,app.BONE,true)
	app._label(box,"Strategy","本轮指令　传教中",Rect2(26,233,510,32),20,app.GOLD,true)
	app._label(box,"Offering","有效锚点 1　 ·　 供奉缺口 1",Rect2(26,273,510,32),19,app.RISK)
	app._label(box,"ManagementScope","成员名单为交互展示，实际成员与经营以 Session 为准。",Rect2(26,318,490,60),18,app.MUTED,false,true)
	app._button(box,"Members","成员与职责",Rect2(26,393,190,45),func():
		app.set_meta("s1_roster",true)
		app.set_meta("s1_read","")
		app.set_meta("s1_focus","Member_%d"%int(app.get_meta("s1_member",0)))
		app.show_cult_stage(),false,true,19)
	app._button(box,"Orders","指令与安排",Rect2(231,393,190,45),func(): app.open_info("指令与安排","当前为传教展示状态；实际指令及其费用需由 Session 查询和结算。"),false,true,19)
	app._button(box,"Offerings","锚点与供奉",Rect2(26,448,190,45),func(): app.open_info("锚点与供奉","镜证04展示记录：有效锚点1、供奉缺口1；本样板不执行调整。"),false,true,19)
	app._label(box,"FixtureScope","展示夹具 · 不执行教团经营",Rect2(26,520,490,30),16,app.MUTED)
	app._button(box,"ReturnWorld","返回世界",Rect2(26,565,170,45),func(): app.show_world(app.selected_world),false,true,20)

static func _build_roster(app: Control, box: Control) -> void:
	var selected: int = clampi(int(app.get_meta("s1_member",0)),0,MEMBERS.size()-1)
	var member: Dictionary = MEMBERS[selected]
	var tab: String = str(app.get_meta("s1_tab","status"))
	var reading: String = str(app.get_meta("s1_read",""))
	if reading=="object":
		_build_relic_task(app,box,member)
		return
	app._soft_support(box,"RosterSupport",Rect2(-18,-10,938,690),Color(0.006,0.018,0.019,0.89))
	app._label(box,"Heading","镜证议会 · 成员",Rect2(28,18,420,44),28,app.GOLD_HI,true)
	app._label(box,"WorldObservation","镜证04　·　传教中　·　信众 64　·　凝聚 70",Rect2(30,64,760,30),18,app.CYAN)
	app._label(box,"FixtureScope","成员与持有关系为展示夹具 · 未接入 Session",Rect2(30,101,800,28),16,app.MUTED)
	app._label(box,"MemberHeading","成员名册",Rect2(30,148,245,32),22,app.GOLD,true)
	var scroll := ScrollContainer.new()
	scroll.name="MemberScroll"
	app._rect(scroll,Rect2(28,190,245,368))
	scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	box.add_child(scroll)
	var bar: VScrollBar=scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x=8
	for style_name: String in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.58,0.49,0.32,0.68) if style_name.begins_with("grabber") else Color(0.03,0.04,0.035,0.25)
		if style_name=="grabber_highlight": style.bg_color=Color(0.80,0.67,0.45,0.9)
		if style_name=="grabber_pressed": style.bg_color=Color(0.91,0.77,0.52,1.0)
		style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(style_name,style)
	var list := VBoxContainer.new()
	list.name="MemberList"
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	scroll.add_child(list)
	for i: int in MEMBERS.size():
		var row: Button=app._button(list,"Member_%d"%i,"%s   ·   %s"%[MEMBERS[i].name,MEMBERS[i].role],Rect2(0,0,228,48),func():
			app.set_meta("s1_member",i)
			app.set_meta("s1_read","")
			app.set_meta("s1_focus","Member_%d"%i)
			_redraw(app,scroll),false,true,18)
		row.custom_minimum_size=Vector2(0,48)
		row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if i==selected:
			row.add_theme_stylebox_override("normal",app._unframed_style("pressed"))
			row.add_theme_color_override("font_color",app.GOLD_HI)
	scroll.set_deferred("scroll_vertical",int(app.get_meta("s1_scroll",0)))
	app._button(box,"ReturnCult","返回教团概况",Rect2(30,604,205,45),func():
		app.set_meta("s1_roster",false)
		app.set_meta("s1_read","")
		app.set_meta("s1_focus","Members")
		_redraw(app,scroll),false,true,19)
	app._label(box,"MemberName",str(member.name),Rect2(315,150,480,40),26,app.GOLD_HI,true)
	app._label(box,"MemberRole",str(member.role)+" · 镜证议会",Rect2(315,195,470,31),19,app.BONE)
	if reading.is_empty():
		_build_member(app,box,scroll,member,tab)
	else:
		_build_related(app,box,scroll,member,reading)

static func _build_member(app: Control, box: Control, scroll: ScrollContainer, member: Dictionary, tab: String) -> void:
	var labels := [["status","TabStatus","处境"],["duties","TabDuties","职责"],["records","TabRecords","记录"]]
	for i: int in labels.size():
		var entry: Array=labels[i]
		var button: Button=app._button(box,entry[1],entry[2],Rect2(315+i*110,247,100,40),func():
			app.set_meta("s1_tab",entry[0])
			app.set_meta("s1_focus",entry[1])
			_redraw(app,scroll),false,true,19)
		if tab==entry[0]: button.add_theme_stylebox_override("normal",app._unframed_style("pressed"))
	var body: String = ""
	match tab:
		"duties": body="当前职责\n"+str(member.duty)+"\n\n携带物可能影响这项职责，可查看关联资料。"
		"records": body="近期记录\n此人为展示示例，暂无正式经历记录。"
		_: body="当前处境\n"+str(member.status)+"\n\n与教团的联系\n"+str(member.duty)
	app._label(box,"MemberDetails",body,Rect2(315,310,550,165),21,app.BONE,false,true)
	app._label(box,"RelicHint","携带物　"+str(member.relic),Rect2(315,495,380,34),20,app.GOLD)
	app._button(box,"InspectRelic","查看携带物 ›",Rect2(315,544,190,45),func():
		app.set_meta("s1_read","relic")
		app.set_meta("s1_focus","RelicSource")
		_redraw(app,scroll),false,true,19)

static func _build_related(app: Control, box: Control, scroll: ScrollContainer, member: Dictionary, reading: String) -> void:
	if reading=="source":
		app._label(box,"RelatedHeading","携带物的来源 · 展示示意",Rect2(315,252,540,40),22,app.GOLD,true)
		app._label(box,"RelatedDetails","来源记录仅用于展示阅读关系。\n\n这条记录与成员的职责和持有关系相连。",Rect2(315,312,525,150),20,app.BONE,false,true)
	else:
		app._label(box,"RelatedHeading",str(member.name)+" 的携带物",Rect2(315,252,540,40),22,app.GOLD,true)
		app._label(box,"RelatedDetails",str(member.relic)+" · 展示示意\n\n当前持有："+str(member.name)+"\n关联职责："+str(member.duty)+"\n\n此关系仅用于样板，未接入实际物件。",Rect2(315,310,540,183),20,app.BONE,false,true)
		app._button(box,"RelicSource","查看已知来源 ›",Rect2(315,510,200,45),func():
			app.set_meta("s1_read","source")
			app.set_meta("s1_focus","ReturnMember")
			_redraw(app,scroll),false,true,19)
		app._button(box,"OpenRelicTask","查看圣物 ›",Rect2(535,510,180,45),func():
			app.set_meta("s1_read","object")
			app.set_meta("s1_focus","ReturnMember")
			_redraw(app,scroll),false,true,19)
	app._button(box,"ReturnMember","返回 "+str(member.name),Rect2(315,574,255,45),func():
		app.set_meta("s1_read","")
		app.set_meta("s1_focus","InspectRelic")
		_redraw(app,scroll),false,true,19)

static func _build_relic_task(app: Control, box: Control, member: Dictionary) -> void:
	app._soft_support(box,"RelicTaskSupport",Rect2(-18,-10,850,690),Color(0.006,0.018,0.019,0.89))
	app._label(box,"Heading",str(member.relic),Rect2(30,28,650,44),28,app.GOLD_HI,true)
	app._label(box,"RelicTaskContext","圣物详情 · 持有者 "+str(member.name),Rect2(30,84,650,32),20,app.CYAN)
	app._label(box,"FixtureScope","展示夹具 · 未接入实际圣物与处置",Rect2(30,127,650,28),16,app.MUTED)
	app._label(box,"RelicTaskDetails","当前持有　"+str(member.name)+"\n\n关联职责　"+str(member.duty)+"\n\n此处只展示物件身份及关系。",Rect2(30,200,680,200),22,app.BONE,false,true)
	app._button(box,"ReturnMember","返回镜证议会 · "+str(member.name),Rect2(30,565,360,45),func():
		app.set_meta("s1_read","")
		app.set_meta("s1_focus","InspectRelic")
		app.show_cult_stage(),false,true,19)

static func _restore_focus(app: Control, box: Control, fallback: String) -> void:
	var target: Node=box.find_child(str(app.get_meta("s1_focus",fallback)),true,false)
	if not target is Control:
		target=box.find_child(fallback,true,false)
	if target is Control:
		target.call_deferred("grab_focus")

static func _redraw(app: Control, scroll: ScrollContainer) -> void:
	app.set_meta("s1_scroll",scroll.scroll_vertical)
	app.show_cult_stage()
