extends "res://src/presentation/production/round_view.gd"
const StudyCard = preload("res://src/presentation/production/worldplay/study_card.gd")
const HandFan = preload("res://src/presentation/production/worldplay/hand_fan.gd")
const ArtStudy = preload("res://src/presentation/production/worldplay/card_illustration.gd")
const DropTable = preload("res://src/presentation/production/worldplay/table_drop.gd")
const ActionModel = preload("res://src/presentation/production/worldplay/action_model.gd")
const SpaceView = preload("res://src/presentation/production/prayer_space_view.gd")
const Availability = preload("res://src/presentation/action_availability.gd")
const GROUPS := [["all","全部"],["object","持有"],["action","行为"],["person","人物"],["cult","教团"],["relic","圣物"],["anchor","锚点"],["power","权能"],["activity","活动"],["prayer","祈求"]]
var _study_cult := ""
var _deck: Array = []
var _category := "all"
var _fan_index := 2
var _fan: Control
var _hand_cards: Array = []
var _search := ""
var _hand_hint: Label
var _master: Control
var _persistent_dock: Control
var _library := ""
var _library_memory: Dictionary = {}
var _played: Dictionary = {}
var _selection: Dictionary = {}
var _entry := ""
var _target := -1
var _picker := ""
var _picker_page := 0
var _optional := false
var _confirmed := false
var _result_text := ""
var _scope_memory: Dictionary = {}
var _table: Control
var _hand: Control
var _model: RefCounted
var _quoted: Dictionary = {}

func _ready() -> void:
	_model = ActionModel.new()
	super._ready()

func _open_campaign(result: Dictionary) -> void:
	if result.get("ok", false):
		_library = ""
		_library_memory.clear()
		_scope_memory.clear()
		_study_cult = ""
		_category = "all"
		_search = ""
		_fan_index = 0
		_reset_draft()
	super._open_campaign(result)

func _reset_draft() -> void:
	_played = {}
	_selection = {}
	_entry = ""
	_target = -1
	_picker = ""
	_picker_page = 0
	_optional = false
	_confirmed = false
	_result_text = ""
	_quoted = {}

func _refresh() -> void:
	if is_instance_valid(_persistent_dock):
		remove_child(_persistent_dock)
		_persistent_dock.queue_free()
		_persistent_dock = null
	super._refresh()

func _table_blocked() -> bool:
	return _busy or not _dialog.is_empty() or not projection.get("active", false) or projection.get("phase") == "events"

func _update_atmosphere() -> void:
	super._update_atmosphere()
	var blocked := _table_blocked()
	if is_instance_valid(_fan): _fan.set_blocked(blocked)
	if is_instance_valid(_persistent_dock):
		for button: Node in _persistent_dock.find_children("*", "Button", true, false):
			button.disabled = blocked

func _reconcile_played() -> void:
	if _played.is_empty() or not _result_text.is_empty(): return
	var fresh: Dictionary = {}
	for card: Dictionary in _deck:
		if card.id == _played.id: fresh = card; break
	if fresh.is_empty() and _library.is_empty():
		var main := _master_card()
		if main.id == _played.id: fresh = main
	if fresh.is_empty():
		_reset_draft()
		return
	_played = fresh.duplicate(true)
	if _played.has("targets") and _played.id != "anchor/bind" and _target >= 0:
		_target = -1
		for index: int in _played.targets.size():
			if _played.targets[index].entry == _entry: _target = index; break
		if _target < 0:
			_entry = ""
			_selection = {}
			_picker = "__target"
			_confirmed = false
	if _played.get("kind") == "prayer" and not _entry.is_empty():
		if not _prayer_options().any(func(option: Dictionary) -> bool: return option.id == _entry):
			_entry = ""
			_selection = {}
			_picker = "__prayer"
			_confirmed = false

func open_cult_table(domain: String) -> void:
	if _busy or projection.get("phase") == "events": return
	var cult: Dictionary = _views._current_cult(self, domain)
	if cult.is_empty(): return
	_close_surface()
	_library = ""
	_library_memory.clear()
	if _world_id != domain: _select_world(domain)
	_enter_cult(str(cult.id))

# Reflow only the execution controls' bounds, never scale text or illustrations.
func _table_box(bounds: Rect2) -> Rect2:
	return Rect2(180+(bounds.position.x-220)*.765,bounds.position.y,bounds.size.x*.765,bounds.size.y)

func _text(parent: Node,value: String,bounds: Rect2,font_size: int,color: Color=UI.BONE) -> Label:
	return super._text(parent,value,_table_box(bounds) if parent==_table else bounds,font_size,color)

func _button(parent: Node,node_name: String,caption: String,bounds: Rect2,handler: Callable,primary:=false,quiet:=true) -> Button:
	return super._button(parent,node_name,caption,_table_box(bounds) if parent==_table else bounds,handler,primary,quiet)

func _scroller(parent: Control,bounds: Rect2) -> ScrollContainer:
	return super._scroller(parent,_table_box(bounds) if parent==_table else bounds)

func _build_worlds() -> void:
	_worlds = projection.get("domains",[])
	_world_buttons.clear()
	if _world_id.is_empty() and _library.is_empty(): super._build_worlds(); return
	_world_body = _region(_stage,"WorldTable",Rect2(Vector2.ZERO,VIEW))
	if _library.is_empty(): _build_deck()
	else: _build_library_deck()
	_reconcile_played()
	_button(_world_body,"Overview","◯ 诸界",Rect2(32,56,92,28),_go_overview)
	if _library.is_empty():
		_button(_world_body,"WorldScope",title(_world_id),Rect2(138,56,164,28),_leave_cult)
		_text(_world_body,"›  "+(session.cult_title(_world_id) if not _study_cult.is_empty() else "世界玩法"),Rect2(319,56,540,28),17)
	else:
		_button(_world_body,"ReturnTable","← 返回牌桌",Rect2(140,56,164,28),_close_library)
		_text(_world_body,"›  "+_library_title()+" · 查阅",Rect2(319,56,540,28),17)
	_build_master()
	_table = DropTable.new()
	_table.name = "PlayArea"
	_table.position = Vector2(304,101)
	_table.size = Vector2(936,292)
	_table.card_dropped.connect(_play_card)
	_world_body.add_child(_table)
	_hand = _region(_world_body,"Hand",Rect2(304,409,936,255))
	_render_table()
	_render_hand()

func _build_top() -> void:
	var top := _region(_stage,"Top",Rect2(0,0,1280,49))
	_text(top,"第 %s 轮 · %s" % [projection.turn,projection.phase_title],Rect2(32,16,550,28),16,UI.MUTED)
	_text(top,"低语 %s    信仰 %s    苏醒 %s" % [projection.whispers,projection.faith,projection.awakening],Rect2(871,14,369,32),20).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_menu_button = _button(top,"Menu","⋯",Rect2(1204,55,36,28),_show_menu)

func _build_dock() -> void:
	if is_instance_valid(_persistent_dock):
		remove_child(_persistent_dock)
		_persistent_dock.queue_free()
	_persistent_dock = _region(self,"PersistentDock",Rect2(32,671,1208,36))
	_ui.fill(_persistent_dock,"DockShade",Rect2(-7,-6,1222,47),Color(UI.INK,.8))
	for item: Array in [["PowerIndex","十二权能",0,112,"power"],["RelicIndex","圣物",124,68,"relic"],["People","人物档案",204,102,"person"]]:
		var button := _button(_persistent_dock,item[0],item[1],Rect2(item[2],0,item[3],34),_open_library.bind(item[4]))
		_ui.choice_style(button,_library==item[4])
		button.tooltip_text = "只读图鉴 · 行动从世界或教团的行为牌发起"
	_button(_persistent_dock,"Budget","供奉与收支",Rect2(320,0,122,34),_dock_subject.bind("budget"))
	_button(_persistent_dock,"Self","苏醒与降临",Rect2(456,0,122,34),_dock_subject.bind("self"))
	_button(_persistent_dock,"History","编年史",Rect2(948,0,90,34),_dock_subject.bind("history"))
	_phase_plate = _button(_persistent_dock,"PhaseAction","回合责任 →",Rect2(1052,0,156,34),_phase_intent,true)

func _begin_surface(kind: String,mist:=true,preserve_world:=false) -> void:
	super._begin_surface(kind,mist,preserve_world)
	if is_instance_valid(_persistent_dock): move_child(_persistent_dock,-1)
	_update_atmosphere()

func _dock_subject(kind: String) -> void:
	if _table_blocked(): return
	_close_surface()
	_tasks.open_subject(kind,"",_return_from_history)

func _go_overview() -> void:
	_close_surface()
	_library = ""
	_library_memory = {}
	_study_cult = ""
	_played = {}
	_select_world("")

func _select_world(id: String) -> void:
	_library = ""
	_library_memory.clear()
	if id != _world_id:
		_study_cult = ""
		_played = {}
		_selection = {}
		_category = "all"
		_search = ""
		_fan_index = 2
	super._select_world(id)
	if not id.is_empty():
		var overview := _stage.find_child("Overview",true,false) as Control
		if overview != null: overview.grab_focus()

func _build_deck() -> void:
	_deck.clear()
	for object: Dictionary in _known_objects():
		var item: Dictionary = object.subject
		_deck.append({"id":str(object.kind)+"/"+str(item.id),"title":session.cult_title(_world_id) if object.kind=="cult" else title(str(item.id)),"type":"object","group":object.kind,"kind":object.kind,"subject":item,"detail":_object_status(object)})
	var rows: Array = _model.build(session,projection,_world_id,_study_cult)
	var grouped := {}
	for row: Dictionary in rows:
		if row.group in ["anchor","relic"]:
			var action_id: String
			var caption: String
			if row.group == "anchor":
				action_id = "maintain" if row.status in ["已建立","维系不足"] else "bind"
				caption = "维系" if action_id=="maintain" else "锚定"
			else:
				action_id = str(row.entry).get_slice("/",2) if str(row.entry).begins_with("opportunity/") else str(row.entry).get_slice("/",1)
				caption = {"equip":"携带","unequip":"卸下","unbind":"解绑","recover":"回收","disassemble":"分解","public":"公开","wait":"等待"}.get(action_id,action_id)
			var key: String = str(row.group)+"/"+action_id
			if not grouped.has(key):
				var card := row.duplicate(true)
				card.merge({"id":key,"title":caption,"type":"action","targets":[]},true)
				grouped[key] = card
				_deck.append(card)
			grouped[key].targets.append(row.duplicate(true))
		else:
			var card := row.duplicate(true)
			card.type = "action"
			_deck.append(card)
	# The verb remains discoverable when every existing anchor is established.
	if not grouped.has("anchor/bind"):
		var power: Dictionary = session.catalog.display_tables.powers.POWER_ANCHOR
		_deck.append({"id":"anchor/bind","title":"锚定","type":"action","group":"anchor","kind":"action","entry":"POWER_ANCHOR","selection":{"domain":_world_id},"targets":[],"cost":_model._price(int(power.faith),int(power.whispers)),"effect":str(power.success),"requirement":str(power.target_requirement),"risk":str(power.always_cost)})

	if _study_cult.is_empty():
		var featured: Array = []
		for criterion: Array in [["group","world"],["group","cult"],["group","prayer"],["id","POWER_DREAM"],["id","anchor/bind"],["group","person"],["group","relic"],["group","activity"]]:
			for card: Dictionary in _deck:
				if card.get(criterion[0])==criterion[1] and not card in featured:
					featured.append(card)
					break
		for card: Dictionary in _deck:
			if not card in featured: featured.append(card)
		_deck = featured

func _matches(card: Dictionary) -> bool:
	return (_category=="all" or card.type==_category or card.group==_category) and (_search.is_empty() or _search.to_lower() in (str(card.title)+" "+str(card.get("detail",""))).to_lower())

func _render_hand() -> void:
	_clear(_hand)
	_fan = null
	var x := 0.0
	if _library.is_empty():
		for category: Array in GROUPS:
			var count: int = _deck.filter(func(card: Dictionary)->bool:return category[0]=="all" or card.type==category[0] or card.group==category[0]).size()
			if count==0: continue
			var caption: String = "指令" if category[0]=="cult" and not _study_cult.is_empty() else str(category[1])
			var button := _button(_hand,"Pile_"+category[0],"%s%s" % [caption,count],Rect2(x,0,72,26),_filter.bind(category[0]))
			button.add_theme_font_size_override("font_size",14)
			_ui.choice_style(button,_category==category[0])
			x += 74
	else:
		_text(_hand,_library_title()+" · %s 张" % _deck.size(),Rect2(0,0,490,26),17,UI.MUTED)
	var search := LineEdit.new()
	search.name = "FindCard"
	search.position = Vector2(755,0)
	search.size = Vector2(181,26)
	search.placeholder_text = "寻牌 · 名称或关系"
	search.text = _search
	search.add_theme_font_size_override("font_size",14)
	_hand.add_child(search)
	search.text_changed.connect(_find_card)
	_hand_hint = _text(_hand,"",Rect2(0,236,936,19),13,UI.MUTED)
	_refresh_fan()

func _refresh_fan() -> void:
	if is_instance_valid(_fan):
		_hand.remove_child(_fan)
		_fan.queue_free()
	_hand_cards = _deck.filter(_matches)
	_fan = HandFan.new()
	_fan.name = "HandFan"
	_fan.position = Vector2(0,28)
	_fan.size = Vector2(936,212)
	_fan.focus_index = clampi(_fan_index,0,maxi(0,_hand_cards.size()-1))
	_hand.add_child(_fan)
	var faces: Array[Control] = []
	for card: Dictionary in _hand_cards:
		var face := _face(_fan,card,Rect2(0,0,148,198))
		_spines(face,_spine_caption(card))
		faces.append(face)
	_fan.card_chosen.connect(_fan_chosen)
	_fan.focus_changed.connect(_fan_focused)
	_fan.card_hovered.connect(_fan_hovered)
	_fan.configure(faces)
	_fan_focused(_fan.focus_index)

func _spine_caption(card: Dictionary) -> String:
	if card.get("kind")=="relic" and card.type=="object":
		var relation: PackedStringArray = str(card.get("detail","")).split(" · ")
		if relation.size()>1: return str(card.title).get_slice(" · ",0).left(4)+relation[1]
	return str(card.title)

func _spines(face: Control, caption: String) -> void:
	var short: String = caption.replace("·","").replace(" ","").left(7)
	var words := PackedStringArray()
	for character: String in short: words.append(character)
	for side: String in ["LeftSpine","RightSpine"]:
		var spine := _region(face,side,Rect2(7 if side=="LeftSpine" else 119,34,22,161))
		_ui.fill(spine,"Ink",Rect2(0,0,22,161),Color("142520e8"))
		var label := _text(spine,"\n".join(words),Rect2(2,4,18,157),14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spine.hide()

func _fan_chosen(index: int) -> void:
	if index>=0 and index<_hand_cards.size(): _play_card(_hand_cards[index])

func _fan_focused(index: int) -> void:
	_fan_index = index
	_fan_hovered(index)

func _fan_hovered(index: int) -> void:
	if not is_instance_valid(_hand_hint): return
	if _hand_cards.is_empty(): _hand_hint.text = "没有匹配的牌"; return
	index = clampi(index if index>=0 else _fan_index,0,_hand_cards.size()-1)
	_hand_hint.text = "%s · %s / %s    横向翻牌 · 向上拖出 · 点击正面出牌" % [_hand_cards[index].title,index+1,_hand_cards.size()]

func _find_card(value: String) -> void:
	_search = value.strip_edges()
	_fan_index = 0
	_refresh_fan()

func _filter(category: String) -> void:
	_category = category
	_fan_index = 2
	_render_hand()

func _step_fan(direction: int) -> void:
	if is_instance_valid(_fan):
		_fan.grab_focus()
		_fan.set_focus(_fan.focus_index+direction)

func _face(parent: Node, card: Dictionary, bounds: Rect2, hand := false) -> Button:
	var face := StudyCard.new()
	face.name = "Card_"+str(card.id).replace("/","_")
	face.position = bounds.position
	face.size = bounds.size
	face.custom_minimum_size = bounds.size
	face.seed_value = absi(str(card.id).hash())%1000
	face.hand_card = hand
	face.actionable = card.type=="action"
	face.payload = card
	parent.add_child(face)
	var w := bounds.size.x
	var h := bounds.size.y
	var image_rect := Rect2(9,28,w-18,h*.47)
	var kind: String = str(card.get("kind",card.group))
	if card.type=="object" and kind in ["world","person","cult"]:
		_object_art(face,"Illustration",image_rect,kind,str(card.subject.id),true)
	elif card.group=="prayer":
		var prayer: Dictionary = _views._find(self,"prayers",str(card.subject_id))
		var person: String = str(prayer.get("descriptor",{}).get("subjects",{}).get("petitioner",""))
		if not person.is_empty(): _object_art(face,"Illustration",image_rect,"person",person,true)
		else: _paint_study(face,image_rect,"power",face.seed_value)
	else:
		_paint_study(face,image_rect,str(card.group),face.seed_value)
	var type_label := _text(face,("联系" if kind=="person" and not card.subject.get("bound_member",false) else "对象") if card.type=="object" else ("临时 · 祈求" if card.group=="prayer" else "行为"),Rect2(12,5,w-24,21),13,UI.MUTED)
	type_label.name = "CardType"
	var heading := _text(face,str(card.title),Rect2(11,h*.64,w-22,30),18)
	heading.name = "CardTitle"
	heading.max_lines_visible = 1
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var detail: String = str(card.get("detail",card.get("cost","")))
	if card.has("targets"): detail = "%s 处目标" % card.targets.size()
	var label := _text(face,detail,Rect2(11,h-42,w-22,34),14,UI.MUTED)
	label.name = "CardDetail"
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	face.tooltip_text = str(card.title)+"\n"+detail+"\n"+str(card.get("effect",""))+"\n"+str(card.get("requirement",""))+"\n"+str(card.get("risk",""))
	face.accessibility_name = str(card.title)
	return face

func _paint_study(parent: Node, bounds: Rect2, motif: String, seed_value: int) -> void:
	var art := ArtStudy.new()
	art.position = bounds.position
	art.size = bounds.size
	art.motif = motif
	art.seed_value = seed_value
	parent.add_child(art)

func _play_card(card: Dictionary) -> void:
	if _table_blocked(): return
	if not _library.is_empty() and (card.type!="object" or card.kind!=_library): return
	if _played.get("id")==card.id and _result_text.is_empty(): return
	_played = card.duplicate(true)
	_selection = card.get("selection",{}).duplicate(true)
	_entry = str(card.get("entry",""))
	_target = -1
	_picker = ""
	_picker_page = 0
	_optional = false
	_confirmed = false
	_result_text = ""
	if card.id=="anchor/bind":
		_entry = "POWER_ANCHOR"
		_selection = {"domain":_world_id}
		_picker = "institution"
	elif card.has("targets"):
		_entry = ""
		_selection = {}
		_picker = "__target"
	elif card.get("kind")=="prayer":
		_entry = ""
		_picker = "__prayer"
	_render_table()
	_render_hand()
	var face := _table.get_node_or_null("Card_"+str(card.id).replace("/","_")) as Control
	if face != null:
		face.modulate.a = 0.3
		face.position.y += 20
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(face,"modulate:a",1.0,.2)
		tween.tween_property(face,"position:y",8.0,.2)

func _render_table() -> void:
	_clear(_table)
	if _played.is_empty():
		var ghost := StudyCard.new()
		ghost.name = "EmptyCardSlot"
		ghost.position = Vector2(12,8)
		ghost.size = Vector2(148,234)
		ghost.seed_value = 804
		ghost.modulate.a = .32
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_table.add_child(ghost)
		_text(ghost,"↓",Rect2(50,84,48,40),28,UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text(ghost,"落牌处",Rect2(28,133,92,30),17,UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text(_table,"放一张牌在这里",Rect2(220,39,850,45),26)
		_text(_table,"展开资料，查阅其身份与联系。" if not _library.is_empty() else "对象牌用于查阅。行为牌在此选择目标、施行。",Rect2(220,106,870,80),18,UI.MUTED)
		_text(_table,"只读图鉴 · 行动从世界或教团的行为牌发起" if not _library.is_empty() else "左侧始终保留当前世界或教团。下方横向翻动手牌。",Rect2(220,215,900,48),15,UI.MUTED)
		return
	var face := _face(_table,_played,Rect2(12,8,148,234))
	face.payload = {}
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button(_table,"Recall","收回 ↓",Rect2(1090,0,110,29),_recall)
	_text(_table,str(_played.title),Rect2(218,3,840,36),26)
	if not _result_text.is_empty():
		_reading(_result_text)
		_button(_table,"Done","收回卡牌",Rect2(973,242,220,40),_recall,true)
	elif _played.get("kind")=="power" and _played.type=="object": _render_power_record()
	elif _played.type=="object": _render_object()
	elif _played.get("kind")=="order": _render_plan()
	elif _played.id=="anchor/maintain": _render_maintenance()
	else: _render_action()

func _recall() -> void:
	_played = {}
	_selection = {}
	_picker = ""
	_result_text = ""
	_render_table()
	_render_hand()

func _reading(value: String) -> void:
	var scroll := _scroller(_table,Rect2(220,52,960,180))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_line(box,value,17)

func _render_object() -> void:
	var item: Dictionary = _played.subject
	var lines := PackedStringArray()
	match str(_played.kind):
		"world":
			lines.append(_views.world_metrics_text(self,str(item.id),true))
			lines.append(_views.world_resistance_text(self,str(item.id)))
			for metric: String in ["barrier","pollution","alert","stability"]: lines.append(_views.metric_help_text(item,metric))
			_button(_table,"History","查阅编年史",Rect2(973,242,220,40),_read_history)
		"person":
			lines.append(_played.detail)
			lines.append("所在机构 · "+title(str(item.get("institution",""))))
			if item.get("bound_member",false):
				lines.append("意志 %s    洞察 %s    影响 %s    适应 %s" % [item.get("will","?"),item.get("insight","?"),item.get("influence","?"),item.get("adaptation","?")])
				lines.append("忠诚 %s    理智 %s" % [item.get("loyalty","?"),item.get("sanity","?")])
				lines.append(_views._execution_status(self,item))
			else: lines.append("尚未接纳为信徒。已知的身份与联系见于此处。")
			for limitation: String in item.get("prayer_limitations",[]): lines.append(limitation)
			for change: String in item.get("prayer_capabilities",[]): lines.append(change)
			for relic: Dictionary in projection.relics:
				if relic.get("holder")==item.id: lines.append("携带 · "+title(str(relic.id)))
		"cult":
			lines.append(_played.detail)
			lines.append("领袖 · "+title(str(item.get("leader",""))))
			lines.append("本轮指令 · "+_views._strategy_name(projection.economy_plan.get("strategies",{}).get(item.id,item.get("strategy","hold"))))
			lines.append("具名成员 %s" % _views._members_for(self,item).size())
			if str(item.id)!=_study_cult: _button(_table,"EnterCult","进入教团 →",Rect2(973,242,220,40),_enter_cult.bind(str(item.id)),true)
		"relic":
			lines.append(_played.detail)
			var definition: Dictionary = session.catalog.display_tables.relics.get(str(item.get("type","")),{})
			for field: String in ["carry_effect","anchor_effect","description"]:
				if definition.has(field): lines.append(str(definition[field]))
		"anchor":
			lines.append(_played.detail)
			lines.append("机构 · "+title(str(item.get("institution",""))))
			lines.append("护持者 · "+title(str(item.get("guardian",""))))
			lines.append("媒介 · "+title(str(item.get("relic",""))))
	_reading("\n\n".join(lines))

func _read_history() -> void:
	_tasks.open_subject("history",_world_id,_return_from_history)

func _return_from_history() -> void:
	_close_surface()
	_refresh()

func _enter_cult(id: String) -> void:
	_scope_memory[_world_id] = {"category":_category,"fan":_fan_index,"search":_search}
	_study_cult = id
	_search = ""
	_played = {}
	_category = "all"
	_fan_index = 2
	_refresh()

func _leave_cult() -> void:
	_study_cult = ""
	_played = {}
	var saved: Dictionary = _scope_memory.get(_world_id,{})
	_category = saved.get("category","all")
	_fan_index = saved.get("fan",2)
	_search = saved.get("search","")
	_refresh()

# The table holds a draft only. Catalog selectors and Session remain the authority
# for prerequisites, payment, effects and mutation.
func _fields() -> Array:
	if _entry.is_empty(): return []
	var fields: Array = session.action_choices(_entry,_selection).get("fields",[])
	if _played.id=="anchor/bind":
		var offices: Array = _played.targets.map(func(row: Dictionary)->String:return str(row.subject_id))
		for field: Dictionary in fields:
			if field.key=="institution": field.options = field.options.filter(func(option: Dictionary)->bool:return str(option.id) in offices)
	if _played.get("group")=="activity" and not _study_cult.is_empty():
		for field: Dictionary in fields:
			if field.key != "npc": continue
			field.options = field.options.filter(func(option: Dictionary)->bool:
				var person: Dictionary = _views._find(self,"people",str(option.id))
				return person.get("cult_id")==_study_cult and person.get("bound_member",false))
	return fields

func _fill_single_choices() -> void:
	for iteration: int in 12:
		var changed := false
		for field: Dictionary in _fields():
			var options: Array = field.get("options",[])
			if field.get("optional",false) or field.get("multiple",false): continue
			var valid := false
			for option: Dictionary in options:
				if option.id == _selection.get(field.key): valid = true; break
			if _selection.has(field.key) and not valid:
				_selection.erase(field.key)
				changed = true
			if not _selection.has(field.key) and options.size()==1:
				_selection[field.key] = options[0].id
				changed = true
		if _entry=="POWER_ANCHOR" and _selection.has("qualification") and not _selection.has("source"):
			for field: Dictionary in _fields():
				if field.key!="source": continue
				for option: Dictionary in field.options:
					if option.id==_selection.qualification: _selection.source = option.id; changed = true; break
		if not changed: break

func _field_title(field: Dictionary) -> String:
	if _entry=="POWER_ANCHOR" and field.key=="npc": return "护持者"
	if field.key=="npc" and _played.get("group")=="activity": return "发起者"
	return str(field.label)

func _option_caption(option: Dictionary) -> String:
	return _actions._option_title(_tasks,option)

func _choice_label(field: Dictionary) -> String:
	var chosen: Variant = _entry if field.key=="__prayer" else _selection.get(field.key)
	if chosen==null: return "选择"+_field_title(field)
	var values: Array = chosen if chosen is Array else [chosen]
	var labels := PackedStringArray()
	for value: Variant in values:
		for option: Dictionary in field.options:
			if value==option.id: labels.append(_option_caption(option)); break
	return "、".join(labels) if not labels.is_empty() else "选择"+_field_title(field)

func _display_fields(fields: Array) -> Array:
	var visible: Array = []
	for field: Dictionary in fields:
		if field.key in ["domain","operation"] and _played.get("selection",{}).has(field.key): continue
		if field.key=="cult" and not _study_cult.is_empty(): continue
		if _entry=="POWER_ANCHOR" and field.key=="institution" and _target>=0: continue
		if field.get("optional",false) and not _optional: continue
		# A sole source/qualification is recorded automatically, still shown in
		# the full condition text; it does not ask the player to click again.
		if field.key in ["source","qualification"] and field.options.size()==1: continue
		visible.append(field)
	if _entry=="POWER_ANCHOR":
		var order := ["institution","relic","npc","qualification","source"]
		visible.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
			var ai: int = order.find(a.key); var bi: int = order.find(b.key)
			return (ai if ai>=0 else 99)<(bi if bi>=0 else 99))
	return visible

func _render_action() -> void:
	if _played.get("kind")=="prayer" and _entry.is_empty():
		var reading := _scroller(_table,Rect2(220,44,953,58))
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reading.add_child(body)
		_line(body,(str(_played.get("context",""))+"\n"+str(_played.effect)).strip_edges(),16,UI.MUTED)
		_render_picker({"key":"__prayer","label":"选择回应","options":_prayer_options()},109)
		return
	# A grouped verb opens its target selector immediately; targets are a choice,
	# never a separate hand card per object.
	if _played.has("targets") and _played.id!="anchor/bind" and _target<0:
		if _played.targets.size()==1:
			_set_target(0)
		else:
			_text(_table,"选择"+("机构" if _played.group=="anchor" else "圣物或机会"),Rect2(220,47,900,32),19)
			if _played.targets.is_empty():
				_reading("当地尚无需要建立或重绑的机构。\n已建立锚点的供奉请使用「维系」牌。" if _played.group=="anchor" else "当地没有这项处置的对象。")
			else: _render_picker({"key":"__target","label":"选择目标","options":_target_options()},96)
			return
	_fill_single_choices()
	var fields: Array = _fields()
	var visible: Array = _display_fields(fields)
	var optional_count: int = fields.filter(func(field: Dictionary)->bool:return field.get("optional",false)).size()
	var note := str(_played.get("effect",""))
	var note_label := _text(_table,note,Rect2(220,40,815,24),14,UI.MUTED)
	note_label.max_lines_visible = 1
	note_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note_label.tooltip_text = note+"\n"+str(_played.get("risk",""))
	note_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if optional_count>0:
		_button(_table,"Optional","辅助 −" if _optional else "辅助 +",Rect2(1094,38,100,25),_toggle_optional)
	var slots: Array = visible.duplicate()
	if _played.has("targets") and _played.id!="anchor/bind":
		slots.push_front({"key":"__target","label":"机构" if _played.group=="anchor" else "目标","options":_target_options()})
	elif _played.get("kind")=="prayer":
		slots.push_front({"key":"__prayer","label":"回应","options":_prayer_options()})
	var slot_width: float = minf(182.0,954.0/maxi(1,slots.size()))
	for index: int in slots.size():
		var field: Dictionary = slots[index]
		var caption: String = _choice_label(field)
		if field.key=="__target": caption = str(_target_options()[_target].label)
		elif field.key=="__prayer":
			for option: Dictionary in field.options:
				if option.id==_entry: caption = str(option.label)
		var label: String = str(field.label) if str(field.key).begins_with("__") else _field_title(field)
		var button := _button(_table,"Slot_"+str(field.key),label+"\n"+caption,Rect2(220+index*slot_width,67,slot_width-5,48),_open_picker.bind(str(field.key)))
		button.add_theme_font_size_override("font_size",14)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = label+"\n"+caption
		_ui.choice_style(button,_picker==str(field.key))
	var missing: Array = _actions._missing_fields(fields,_selection)
	if _picker.is_empty() and not missing.is_empty():
		for field: Dictionary in visible:
			if not field.get("optional",false) and (not _selection.has(field.key) or _selection[field.key] is Array and _selection[field.key].is_empty()):
				_picker = str(field.key); break
	var picking: Dictionary = {}
	for field: Dictionary in slots:
		if field.key==_picker: picking = field; break
	if not picking.is_empty(): _render_picker(picking,121)
	else:
		var notes := _scroller(_table,Rect2(220,124,966,109))
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notes.add_child(text_box)
		_line(text_box,_action_notes(),15,UI.MUTED)
	var prepared: Dictionary = session.preview_action(_entry,_selection)
	var costs: Dictionary = prepared.get("preview",{})
	_quoted = costs.duplicate(true)
	var info: String = _model._price(int(costs.get("faith",costs.get("faith_cost",0))),int(costs.get("whispers",0))) if prepared.get("ok",false) else str(_played.get("cost","配置后核算"))
	if int(costs.get("success_target",costs.get("probability",-1)))>=0: info += " · 成功点数 %s / 100" % int(costs.get("success_target",costs.get("probability")))
	var reason: String = "选项齐备 · 尚未执行" if prepared.get("ok",false) else session.explain_error(str(prepared.get("error","条件尚未满足")))
	if not missing.is_empty():
		var absent: Array[String] = []
		for field: Dictionary in fields:
			if not field.get("optional",false) and field.options.is_empty(): absent.append(_field_title(field))
		reason = "缺条件 · 没有可选的"+"、".join(absent) if not absent.is_empty() else "还需选择 · "+"、".join(missing)
	if _confirmed: reason = "不可逆代价 · 再次确认执行。"+str(_actions._irreversible_summary(_tasks,session.action_entry(_entry,_selection),_selection))
	var status := _text(_table,info+"\n"+reason,Rect2(220,238,739,48),15,Paint.WARM if not prepared.get("ok",false) else UI.BONE)
	status.max_lines_visible = 2
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.tooltip_text = info+"\n"+reason
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	var execute := _button(_table,"Execute",("确认回应" if _confirmed else "回应这声祈求") if _played.get("kind")=="prayer" else ("确认 · " if _confirmed else "施行 · ")+str(_played.title),Rect2(973,242,220,40),_execute,true)
	execute.disabled = not prepared.get("ok",false) or not missing.is_empty() or projection.get("phase") != "actions"


func _action_notes() -> String:
	var row: Dictionary = session.action_entry(_entry,_selection)
	if _played.get("kind")=="prayer":
		var id: String = str(_played.subject_id)
		for choice: Dictionary in session.prayer_space_choices(id):
			if str(choice.id)==_entry.get_slice("/",2):
				return str(_played.get("context",""))+"\n"+str(choice.label)+"\n"+str(choice.get("hint","具体后果尚未掌握。"))+"\n"+_upkeep_note(choice)+"\n无论结果如何，回应会使用本轮回应机会。"
	var effects: Dictionary = _actions._outcome_effects(_tasks,row,_selection)
	var lines := PackedStringArray()
	var always: String = _actions._always_cost(_tasks,row,_selection)
	if not always.is_empty(): lines.append("必付 · "+always)
	var success: String = str(effects.get("summary",effects.get("success","")))
	if not success.is_empty(): lines.append("作用 · "+success)
	for key: String in ["failure","disaster"]:
		if not str(effects.get(key,"")).is_empty(): lines.append(("失败 · " if key=="failure" else "灾变 · ")+str(effects[key]))
	if lines.is_empty(): lines.append(str(_played.get("effect",_played.get("requirement",""))))
	return "\n".join(lines)

func _target_options() -> Array:
	var options: Array = []
	for index: int in _played.get("targets",[]).size():
		var target: Dictionary = _played.targets[index]
		var caption: String = str(target.title).trim_prefix(str(target.title).get_slice(" · ",0)+" · ")
		if str(target.entry).begins_with("opportunity/"): caption += " · "+str(target.requirement).get_slice(" · ",0)
		options.append({"id":index,"label":caption,"subject":target.get("subject_id",""),"detail":target.get("requirement","")})
	return options

func _prayer_options() -> Array:
	var options: Array = []
	var id: String = str(_played.get("subject_id",""))
	var choices := {}
	for choice: Dictionary in session.prayer_space_choices(id): choices[str(choice.id)] = choice
	for entry: Dictionary in session.action_entries("prayer/"+id+"/"):
		var choice: Dictionary = choices.get(str(entry.key).get_slice("/",2),{})
		var approach: String = str(SpaceView.APPROACHES.get(str(choice.get("approach","")),""))
		var label: String = (approach+" · " if not approach.is_empty() else "")+str(entry.title)
		var detail := str(choice.get("hint","查看回应条件与代价"))
		if not choice.is_empty(): detail += "\n"+_model._price(int(choice.get("faith",0)),int(choice.get("whispers",0)))+"\n"+_upkeep_note(choice)
		options.append({"id":entry.key,"label":label,"detail":detail,"approach":approach})
	return options

func _upkeep_note(choice: Dictionary) -> String:
	var fee := int(choice.get("first_upkeep",0))
	if fee <= 0: return ""
	var turns := int(choice.get("upkeep_turns",choice.get("maintenance_turns",0)))
	if turns <= 0: return "生效另付 %s 信仰" % fee
	return "生效另付 %s 信仰；此后每轮 %s 信仰，共 %s 轮（含本轮）。停止：%s" % [fee,fee,turns,str(choice.get("upkeep_stop","后续效果停止"))]

func _set_target(index: int) -> void:
	_target = index
	var target: Dictionary = _played.targets[index]
	_entry = str(target.entry)
	_selection = target.selection.duplicate(true)
	_picker = ""
	_picker_page = 0
	_confirmed = false

func _open_picker(key: String) -> void:
	_picker = "" if _picker==key else key
	_picker_page = 0
	_render_table()

func _toggle_optional() -> void:
	_optional = not _optional
	_picker = ""
	_render_table()

func _render_picker(field: Dictionary, y: float) -> void:
	var options: Array = field.get("options",[])
	if field.key=="escort" and not options.is_empty():
		_text(_table,"随行的无名信众",Rect2(225,y+8,400,30),18)
		var amount := SpinBox.new()
		amount.position = _table_box(Rect2(225,y+48,0,0)).position
		amount.size = Vector2(220,42)
		amount.min_value = int(options[0].id)
		amount.max_value = int(options[-1].id)
		amount.value = int(_selection.get("escort",0))
		_table.add_child(amount)
		_button(_table,"SetEscort","放入随行人数",Rect2(470,y+48,220,42),func()->void:_choose_inline(field,int(amount.value)))
		return
	var start: int = _picker_page*5
	if start>=options.size(): _picker_page = 0; start = 0
	if options.is_empty():
		_text(_table,"没有可选的"+str(field.label)+"。请先检查前置选择或积累当地条件。",Rect2(227,y+20,917,65),17,Paint.WARM)
		return
	for index: int in mini(5,options.size()-start):
		var option: Dictionary = options[start+index]
		var card := StudyCard.new()
		card.name = "Choice_"+str(field.key)+"_"+str(start+index)
		card.position = Vector2(180+index*137,y)
		card.size = Vector2(124,112)
		card.seed_value = hash(str(option.id))
		_table.add_child(card)
		var subject: String = str(option.get("subject",option.id))
		var kind := ""
		for pair: Array in [["people","person"],["cults","cult"],["domains","world"]]:
			if not _views._find(self,pair[0],subject).is_empty(): kind = pair[1]; break
		if field.key=="__prayer":
			_paint_study(card,Rect2(22,3,80,45),"prayer",hash(subject))
		elif kind.is_empty(): _paint_study(card,Rect2(22,7,80,59),"relic" if field.key=="relic" else "anchor",hash(subject))
		else: _object_art(card,"ChoiceArt",Rect2(22,6,80,60),kind,subject,false)
		var label := _text(card,_option_caption(option),Rect2(9,48,106,60) if field.key=="__prayer" else Rect2(9,66,106,40),14)
		label.max_lines_visible = 3 if field.key=="__prayer" else 2
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.tooltip_text = _option_caption(option)+"\n"+str(option.get("detail","点击放入 · 不会执行行动"))
		var chosen: Variant = _entry if field.key=="__prayer" else _selection.get(field.key)
		card.actionable = option.id==chosen or (chosen is Array and option.id in chosen)
		card.pressed.connect(_choose_inline.bind(field,option.id))
	if options.size()>5:
		_button(_table,"OptionsPrev","‹",Rect2(1150,y,37,30),_page_choices.bind(-1)).disabled = _picker_page==0
		_text(_table,"%s/%s" % [_picker_page+1,ceili(options.size()/5.0)],Rect2(1147,y+38,46,30),13,UI.MUTED)
		_button(_table,"OptionsNext","›",Rect2(1150,y+79,37,30),_page_choices.bind(1)).disabled = start+5>=options.size()
	if field.get("optional",false):
		_button(_table,"ClearOptional","不使用",Rect2(1050,y-28,135,27),_clear_optional.bind(str(field.key)))

func _page_choices(direction: int) -> void:
	_picker_page = maxi(0,_picker_page+direction)
	_render_table()

func _clear_optional(key: String) -> void:
	_selection.erase(key)
	_picker = ""
	_confirmed = false
	_render_table()

func _choose_inline(field: Dictionary,value: Variant) -> void:
	if field.key=="__target":
		_set_target(int(value))
	elif field.key=="__prayer":
		_entry = str(value)
		_selection = {}
		_picker = ""
	else:
		var previous: Dictionary = _selection.duplicate(true)
		_selection = Availability.selection_for(_fields(),_selection,field,value)
		if _entry=="POWER_ANCHOR" and field.key=="npc":
			for key: String in ["institution","source","qualification","relic"]:
				if previous.has(key): _selection[key] = previous[key]
		if _entry=="POWER_ANCHOR" and field.key=="qualification": _selection.source = value
		if field.get("multiple",false):
			_picker = str(field.key)
		else: _picker = ""
	_confirmed = false
	_picker_page = 0
	_render_table()

func _execute() -> void:
	if _table_blocked() or not _library.is_empty() or not _result_text.is_empty() or projection.get("phase") != "actions": return
	var prepared: Dictionary = session.preview_action(_entry,_selection)
	if not prepared.get("ok",false): _render_table(); return
	if prepared.get("irreversible",false) and not _confirmed:
		_confirmed = true
		_picker = ""
		_render_table()
		return
	_busy = true
	var response: Dictionary = session.execute_action(_entry,_selection,_confirmed,"",_quoted)
	_busy = false
	if not response.get("ok",false):
		_result_text = "未执行 · "+session.explain_error(str(response.get("error","")))
	else:
		_result_text = "已施行 · "+str(_played.title)+"\n\n"+"\n".join(_feedback.build(self,response,projection,session.project(),str(_played.title)))
	projection = session.project()
	_refresh()

func _render_plan() -> void:
	var plan: Dictionary = _views._plan(self)
	plan.strategies[_study_cult] = _played.selection.strategy
	var result: Dictionary = session.preview_plan(plan)
	var forecast: Dictionary = _views._cult_forecast(result.get("preview",{}),_study_cult)
	var words: String = str(_played.effect)+"\n\n"+_views._strategy_summary(self,forecast,"\n") if not forecast.is_empty() else session.explain_error(str(result.get("error","无法登记指令")))
	_reading(words+"\n\n登记后在轮末执行；当前不结算收入。")
	var submit := _button(_table,"Execute","登记 · "+str(_played.title),Rect2(973,242,220,40),_save_plan.bind(plan),true)
	submit.disabled = not result.get("ok",false) or forecast.is_empty() or not str(forecast.get("reason","")).is_empty()

func _render_maintenance() -> void:
	if _target<0:
		_text(_table,"选择要维系的锚点",Rect2(220,47,900,32),19)
		_render_picker({"key":"__target","label":"锚点","options":_target_options()},96)
		return
	var institution: String = str(_played.targets[_target].subject_id)
	var anchor: Dictionary = {}
	for item: Dictionary in projection.anchors:
		if item.get("institution")==institution: anchor = item; break
	if anchor.is_empty(): _reading("此机构的锚点已不在已知联系中。"); return
	var plan: Dictionary = _views._plan(self)
	var refused: bool = bool(_selection.get("refuse",str(anchor.id) in plan.refuse_anchors))
	plan.refuse_anchors.erase(str(anchor.id))
	if refused: plan.refuse_anchors.append(str(anchor.id))
	if _selection.get("priority",false):
		plan.anchor_priority.erase(str(anchor.id))
		plan.anchor_priority.push_front(str(anchor.id))
	var preview: Dictionary = session.preview_plan(plan)
	var forecast: Dictionary = {}
	for row: Dictionary in preview.get("preview",{}).get("anchors",[]):
		if row.anchor==anchor.id: forecast = row; break
	_button(_table,"ChangeAnchor",title(institution)+" · 更换",Rect2(220,48,390,36),_maintenance_retarget)
	_text(_table,"护持者 · "+title(str(anchor.get("guardian","")))+"\n绑定圣物 · "+title(str(anchor.get("relic",""))),Rect2(224,98,530,68),18)
	var supply := _button(_table,"Supply","维持供奉",Rect2(222,177,176,42),_supply_choice.bind(false))
	var refuse := _button(_table,"Refuse","本轮停供",Rect2(410,177,176,42),_supply_choice.bind(true))
	_ui.choice_style(supply,not refused)
	_ui.choice_style(refuse,refused)
	var priority := _button(_table,"Priority","优先供奉",Rect2(600,177,176,42),_priority_choice)
	_ui.choice_style(priority,bool(_selection.get("priority",false)))
	var reason: String = str(forecast.get("reason",""))
	_text(_table,"轮末 · %s 信仰\n%s" % [forecast.get("fee",0),_views._economy_reason(self,reason) if not reason.is_empty() else "继续护持与供奉，维系锚点"],Rect2(799,98,390,112),17,Paint.WARM)
	_text(_table,"登记安排，不会立即推进回合。",Rect2(225,245,700,30),15,UI.MUTED)
	_button(_table,"Execute","登记供奉",Rect2(973,242,220,40),_save_plan.bind(plan),true).disabled = not preview.get("ok",false)

func _maintenance_retarget() -> void:
	_target = -1
	_render_table()

func _supply_choice(refused: bool) -> void:
	_selection.refuse = refused
	_render_table()

func _priority_choice() -> void:
	_selection.priority = not _selection.get("priority",false)
	_render_table()

func _save_plan(plan: Dictionary) -> void:
	if _table_blocked() or not _library.is_empty() or not _result_text.is_empty(): return
	var response: Dictionary = session.set_plan(plan)
	_result_text = "安排已登记\n\n轮末按当时局势与资源结算。你仍可更改本轮安排。" if response.get("ok",false) else session.explain_error(str(response.get("error","")))
	_refresh()

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _input(event: InputEvent) -> void:
	if _dialog.is_empty() and (not _world_id.is_empty() or not _library.is_empty()):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE and not _played.is_empty():
				_recall()
				get_viewport().set_input_as_handled()
				return
			if event.keycode==KEY_ESCAPE and not _library.is_empty():
				_close_library()
				get_viewport().set_input_as_handled()
				return
			if event.keycode==KEY_ESCAPE and not _study_cult.is_empty():
				_leave_cult()
				get_viewport().set_input_as_handled()
				return
			if event.keycode in [KEY_LEFT,KEY_RIGHT] and not get_viewport().gui_get_focus_owner() is LineEdit:
				_step_fan(-1 if event.keycode==KEY_LEFT else 1)
				get_viewport().set_input_as_handled()
				return
	super._input(event)

func _known_objects() -> Array:
	var result: Array = []
	var cult: Dictionary = _views._find(self, "cults", _study_cult)
	for kind: String in ["cult", "person", "relic", "anchor"]:
		var collection: String = {"cult": "cults", "person": "people", "relic": "relics", "anchor": "anchors"}[kind]
		for subject: Dictionary in projection.get(collection, []):
			if subject.get("domain", "") != _world_id: continue
			if not cult.is_empty():
				if kind == "cult": continue
				if kind == "person" and (subject.get("cult_id", "") != _study_cult or not subject.get("bound_member", false)): continue
				if kind == "relic" and not _cult_relic(subject, cult): continue
				if kind == "anchor": continue
			result.append({"kind": kind, "subject": subject})
	# Show the player's actual people before outside contacts, without collapsing
	# those two different relationships into an ownership claim.
	var kind_order := ["cult", "person", "relic", "anchor"]
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kind != b.kind: return kind_order.find(a.kind) < kind_order.find(b.kind)
		if a.kind == "person" and bool(a.subject.get("bound_member", false)) != bool(b.subject.get("bound_member", false)):
			return bool(a.subject.get("bound_member", false))
		return str(a.subject.id) < str(b.subject.id))
	return result

func _cult_relic(relic: Dictionary, cult: Dictionary) -> bool:
	return ActionModel.cult_relic(projection, relic, str(cult.id))

func _object_status(row: Dictionary) -> String:
	var item: Dictionary = row.subject
	match str(row.kind):
		"cult": return "%s 信众 · 凝聚 %s  ↗" % [item.get("followers", "?"), item.get("cohesion", "?")]
		"person": return ("信徒 · " if item.get("bound_member", false) else "联系 · ") + _views._role(self, item)
		"anchor": return "锚点 · " + _views._anchor_state(item)
		"relic":
			if item.get("placement") == "bound":
				var anchor: Dictionary = _views._find(self, "anchors", str(item.get("anchor", "")))
				return "绑定 · " + (title(str(anchor.institution)) if not anchor.is_empty() else "机构未掌握")
			if item.get("placement") == "carried": return "携带 · " + title(str(item.get("holder", "")))
			return "圣物 · " + str({"controlled": "库藏", "ground": "遗落", "seized": "被扣押", "sealed": "封存"}.get(item.get("placement", ""), "状态未掌握"))
	return "查看已知资料"


func _library_title() -> String:
	return str({"power":"十二权能","relic":"圣物档案","person":"人物档案"}.get(_library,"万物档案"))

func _build_master() -> void:
	_master = StudyCard.new()
	_master.name = "MasterCard"
	_master.position = Vector2(32,101)
	_master.size = Vector2(250,552)
	_master.seed_value = 472
	_master.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_body.add_child(_master)
	var subject: Dictionary = _master_card()
	var kind: String = str(subject.kind)
	_text(_master,"万物档案 · 查阅" if not _library.is_empty() else ("所属世界 · "+title(_world_id) if kind=="cult" else "当前世界"),Rect2(16,12,218,24),14,UI.MUTED)
	var heading := _text(_master,str(subject.title),Rect2(16,40,218,55),26)
	heading.max_lines_visible = 2
	heading.tooltip_text = str(subject.title)
	_master.set_meta("scope_id",subject.id)
	if _library.is_empty(): _object_art(_master,"ScopeArt",Rect2(15,103,220,220),kind,str(subject.subject.id),true)
	else: _paint_study(_master,Rect2(15,103,220,220),_library,472)
	var summaries: Array = []
	if _library=="power":
		var unlocked: int = _deck.filter(func(card: Dictionary)->bool:return int(card.subject.get("unlock_awakening",0))<=int(projection.awakening)).size()
		summaries = ["当前苏醒  %s" % projection.awakening,"已解锁  %s / %s" % [unlocked,_deck.size()],"查看条件、代价与作用","执行请回世界牌桌"]
	elif _library=="person":
		var members: int = _deck.filter(func(card: Dictionary)->bool:return card.subject.get("bound_member",false)).size()
		summaries = ["已知人物  %s" % _deck.size(),"信徒  %s · 其他联系  %s" % [members,_deck.size()-members],"跨已知世界汇集","身份不代表可支配资格"]
	elif _library=="relic":
		summaries = ["已知圣物  %s" % _deck.size(),"绑定、携带与当地保管","按当前已知关系查阅","处置请回世界牌桌"]
	elif kind=="world":
		for field: String in ["barrier","pollution","alert","stability"]:
			summaries.append(str(_views.WORLD_METRICS[field])+"    "+str(_views.metric_display(subject.subject,field).value))
	else:
		var cult: Dictionary = subject.subject
		summaries = ["信众  %s · 凝聚  %s" % [cult.get("followers","?"),cult.get("cohesion","?")],"领袖 · "+title(str(cult.get("leader",""))),"具名成员  %s" % _views._members_for(self,cult).size(),"本轮 · "+_views._strategy_name(projection.economy_plan.get("strategies",{}).get(cult.id,cult.get("strategy","hold")))]
	for index: int in summaries.size():
		var line := _text(_master,str(summaries[index]),Rect2(16,340+index*32,218,31),16,UI.MUTED)
		line.max_lines_visible = 1
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.tooltip_text = str(summaries[index])+"\n"+(_views.metric_help_text(subject.subject,["barrier","pollution","alert","stability"][index]) if _library.is_empty() and kind=="world" else "")
		line.mouse_filter = Control.MOUSE_FILTER_PASS
	if _library.is_empty() and kind=="world": _text(_master,"已知情报 · 悬停查看观测时点",Rect2(16,471,218,22),14,UI.MUTED)
	if _library.is_empty():
		_button(_master,"InspectScope","查看完整资料 →",Rect2(16,499,218,34),_play_card.bind(subject))
	else:
		_button(_master,"BackToTable","返回牌桌 →",Rect2(16,499,218,34),_close_library)

func _master_card() -> Dictionary:
	if not _library.is_empty(): return {"id":"library/"+_library,"title":_library_title(),"kind":_library,"type":"object"}
	var kind: String = "cult" if not _study_cult.is_empty() else "world"
	var subject: Dictionary = _views._find(self,"cults" if kind=="cult" else "domains",_study_cult if kind=="cult" else _world_id)
	return {"id":kind+"/"+str(subject.id),"title":session.cult_title(_world_id) if kind=="cult" else title(_world_id),"type":"object","group":kind,"kind":kind,"subject":subject,"detail":_object_status({"kind":kind,"subject":subject}) if kind=="cult" else "世界四维 · 当前已知情报"}

func _build_library_deck() -> void:
	_deck.clear()
	if _library=="power":
		var keys: Array = ActionModel.POWER_ORDER.duplicate()
		keys.insert(5,"POWER_ANCHOR")
		for key: String in keys:
			var definition: Dictionary = session.catalog.display_tables.powers.get(key,{})
			if definition.is_empty(): continue
			_deck.append({"id":"record/"+key,"title":str(definition.name),"type":"object","group":"power","kind":"power","subject":definition.merged({"id":key}),"detail":_model._price(int(definition.faith),int(definition.whispers)),"requirement":str(definition.target_requirement),"effect":str(definition.success),"risk":str(definition.always_cost)})
	else:
		for subject: Dictionary in projection.get("people" if _library=="person" else "relics",[]):
			_deck.append({"id":_library+"/"+str(subject.id),"title":title(str(subject.id)),"type":"object","group":_library,"kind":_library,"subject":subject,"detail":_object_status({"kind":_library,"subject":subject})+" · "+title(str(subject.get("domain","")))})

func _open_library(kind: String) -> void:
	if _table_blocked(): return
	if not kind in ["power","relic","person"]: return
	_close_surface()
	if _library.is_empty():
		_library_memory = {"world":_world_id,"cult":_study_cult,"played":_played.duplicate(true),"selection":_selection.duplicate(true),"entry":_entry,"target":_target,"picker":_picker,"picker_page":_picker_page,"optional":_optional,"confirmed":_confirmed,"result":_result_text,"category":_category,"search":_search,"fan":_fan_index}
	_library = kind
	_played = {}
	_selection = {}
	_entry = ""
	_picker = ""
	_result_text = ""
	_category = "all"
	_search = ""
	_fan_index = 2
	_refresh()

func _close_library() -> void:
	if _library.is_empty(): return
	_close_surface()
	_library = ""
	_world_id = _library_memory.get("world",_world_id)
	_study_cult = _library_memory.get("cult",_study_cult)
	_played = _library_memory.get("played",{})
	_selection = _library_memory.get("selection",{})
	_entry = _library_memory.get("entry","")
	_target = _library_memory.get("target",-1)
	_picker = _library_memory.get("picker","")
	_picker_page = _library_memory.get("picker_page",0)
	_optional = _library_memory.get("optional",false)
	_confirmed = _library_memory.get("confirmed",false)
	_result_text = _library_memory.get("result","")
	_category = _library_memory.get("category","all")
	_search = _library_memory.get("search","")
	_fan_index = _library_memory.get("fan",2)
	_library_memory = {}
	_refresh()

func _render_power_record() -> void:
	var definition: Dictionary = _played.subject
	var lines := PackedStringArray()
	lines.append("解锁苏醒 · %s / %s" % [projection.awakening,definition.unlock_awakening])
	lines.append("基础消耗 · "+_model._price(int(definition.faith),int(definition.whispers)))
	for pair: Array in [["target_requirement","所需条件"],["always_cost","必付代价"],["success","成功作用"],["deep_success","深刻成功"],["failure","失败"],["disaster","灾变"]]:
		if not str(definition.get(pair[0],"")).is_empty(): lines.append(pair[1]+" · "+str(definition[pair[0]]))
	_reading("\n\n".join(lines))
	_text(_table,"图鉴仅供查阅 · 从世界或教团的行为牌发起行动",Rect2(220,242,960,40),15,UI.MUTED)
