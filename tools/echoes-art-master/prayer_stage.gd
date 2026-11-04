extends RefCounted
## Current-prayer presentation for the isolated T46 fixture. No Session writes.

static func build(app: Control, box: Control, index: int, variant: String) -> void:
	var fixture: Dictionary=app.PRAYERS[index]
	var data: Dictionary=app.catalog.tables.prayers[fixture.id]
	var meaning: Dictionary=app.semantics.prayer(app.catalog,fixture.id,variant)
	var art: Texture2D=app._texture(app.RESTORED+"prayer-scenes/"+app.PRAYER_SCENES[index])
	var image: TextureRect=app._image(box,"PrayerScene",Rect2(0,42,550,540),art,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	# COVER samples only the central part of the horizontal source; fade the
	# visible crop, not the bounds of the full image, to avoid a hard seam.
	var visible_width:float=941.0*550.0/540.0
	image.material=app._fragment_material(Rect2((1672.0-visible_width)/2.0,0,visible_width,941),0.17,0.96)
	app._soft_support(box,"ReadingSupport",Rect2(514,-8,454,691),Color(0.005,0.018,0.021,0.94))
	app._label(box,"SceneScope","祈求者场景 · 概念示意",Rect2(26,586,420,28),16,app.MUTED)
	app._button(box,"InspectPerson","查看祈求者资料 ›",Rect2(26,628,244,45),func(): app.show_prayer_person(index),false,true,19)
	app._label(box,"Title",str(data.title),Rect2(565,4,362,41),26,app.GOLD_HI,true)
	app._label(box,"Subject",str(fixture.person)+" · "+str(fixture.role)+"　"+str(fixture.world),Rect2(565,50,365,30),20,app.BONE,true)
	app._label(box,"Deadline","请求期限："+str(fixture.due),Rect2(565,84,365,29),18,app.RISK if index==0 else app.GOLD)
	app._label(box,"OriginalCrisis",str(fixture.relation),Rect2(565,115,365,45),17,app.MUTED,false,true)
	app._label(box,"Request",str(fixture.line),Rect2(565,164,365,70),19,app.BONE,false,true)
	var shallow:Button=app._button(box,"ChooseShallow","浅触",Rect2(565,244,150,42),func(): app.show_prayer_stage(index,"shallow"),variant=="shallow",false,20)
	var deep:Button=app._button(box,"ChooseDeep","深应",Rect2(727,244,150,42),func(): app.show_prayer_stage(index,"deep"),variant=="deep",false,20)
	app._label(box,"Payment","费用　%d低语 · %d信仰"%[app.catalog.integer("prayer_"+variant+"_whispers"),app.catalog.integer("prayer_"+variant+"_faith")],Rect2(565,297,365,33),20,app.GOLD,true)
	var scroll:=ScrollContainer.new(); scroll.name="EffectScroll"; app._rect(scroll,Rect2(565,338,365,244))
	scroll.mouse_filter=Control.MOUSE_FILTER_STOP; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var bar:VScrollBar=scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x=8
	for style_name:String in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.58,0.49,0.32,0.68) if style_name.begins_with("grabber") else Color(0.03,0.04,0.035,0.25)
		if style_name=="grabber_highlight": style.bg_color=Color(0.80,0.67,0.45,0.9)
		if style_name=="grabber_pressed": style.bg_color=Color(0.91,0.77,0.52,1.0)
		style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(style_name,style)
	var content:=VBoxContainer.new(); content.name="Effects"; content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10); scroll.add_child(content)
	for pair:Array in [["必付代价",meaning.always],["成功",meaning.summary],["深成",meaning.deep],["失败",meaning.failure],["灾变",meaning.disaster]]:
		if str(pair[1]).is_empty(): continue
		var item:=Label.new(); item.name="Effect"+str(pair[0]); item.text=str(pair[0])+"　"+str(pair[1])
		item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		item.add_theme_font_override("font",app.fonts.heading); item.add_theme_font_size_override("font_size",18)
		item.add_theme_color_override("font_color",app.RISK if pair[0] in ["必付代价","灾变"] else app.BONE)
		content.add_child(item)
	app._label(box,"FixtureScope","展示预览 · 未接入回应结算",Rect2(565,590,365,29),16,app.MUTED)
	app._button(box,"ClosePrayer","收起祈求",Rect2(565,628,166,45),app.close_prayer_stage,false,true,20)
	(shallow if variant=="shallow" else deep).grab_focus()

static func build_related(app: Control, box: Control, index: int, possessions: bool) -> void:
	var fixture: Dictionary=app.PRAYERS[index]
	var data: Dictionary=app.catalog.tables.prayers[fixture.id]
	var art: Texture2D=app._texture(app.RESTORED+"prayer-scenes/"+app.PRAYER_SCENES[index])
	var image: TextureRect=app._image(box,"PrayerScene",Rect2(0,42,550,540),art,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var visible_width:float=941.0*550.0/540.0
	image.material=app._fragment_material(Rect2((1672.0-visible_width)/2.0,0,visible_width,941),0.17,0.96)
	app._soft_support(box,"ReadingSupport",Rect2(514,-8,454,691),Color(0.005,0.018,0.021,0.94))
	app._label(box,"SceneScope","祈求者场景 · 概念示意",Rect2(26,586,420,28),16,app.MUTED)
	app._label(box,"Origin","当前祈求 · "+str(data.title),Rect2(26,625,455,38),20,app.GOLD)
	app._label(box,"RelatedHeading",str(fixture.person)+( " · 携带记录" if possessions else " · 人物资料"),Rect2(565,4,365,41),26,app.GOLD_HI,true)
	app._label(box,"RelatedContext","为「"+str(data.title)+"」查看",Rect2(565,55,365,34),19,app.CYAN)
	app._label(box,"Subject",str(fixture.person)+" · "+str(fixture.role)+"　"+str(fixture.world),Rect2(565,115,365,34),21,app.BONE,true)
	app._label(box,"Deadline","请求期限："+str(fixture.due),Rect2(565,155,365,30),18,app.RISK if index==0 else app.GOLD)
	if possessions:
		app._label(box,"RelatedDetail","该人物的携带记录尚未配置。\n当前无法由展示夹具判断关联物件。",Rect2(565,218,365,100),20,app.MUTED,false,true)
	else:
		app._label(box,"RelatedDetail",str(fixture.relation)+"\n\n诉求："+str(fixture.line),Rect2(565,218,365,150),20,app.BONE,false,true)
		app._button(box,"InspectPossessions","查看携带记录 ›",Rect2(565,398,230,45),func(): app.show_prayer_person(index,true),false,true,19)
	app._label(box,"FixtureScope","展示资料 · 未接入人物及持有记录",Rect2(565,580,365,40),16,app.MUTED,false,true)
	var back:Button=app._button(box,"ReturnPrayer","返回"+str(fixture.person)+"的祈求",Rect2(565,628,300,45),app.return_to_prayer,false,true,20)
	back.grab_focus()
