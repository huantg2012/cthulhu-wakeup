extends "res://tools/card-carrier-study/preview.gd"
## Selected shoulder imprint, using the same one-way hand as the real game.
const Marks = preload("res://tools/card-carrier-study/category_marks.gd")
const Fan = preload("res://src/presentation/production/worldplay/hand_fan.gd")
const Table = preload("res://src/presentation/production/worldplay/table_drop.gd")
const SymbolArt = preload("res://src/presentation/production/worldplay/card_illustration.gd")
const CATEGORY_OUT := "res://docs/art/visual-generation/card-design-study/shoulder-hand/"
const ORDER := ["event", "prayer", "cult", "power", "activity", "person", "anchor", "relic", "action"]
var _deck: Array[Dictionary] = []
var _fan: Control
var _table: Control
var _hint: Label
var _detail: Control
var _shown: Dictionary = {}
var _count := 18
var _interactive := false
var _failures: Array[String] = []

func _run() -> void:
	_interactive = "--interactive" in OS.get_cmdline_user_args()
	_output = CATEGORY_OUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _load_sources():
		quit(1)
		return
	root.title = "邪神苏醒 · 肩位牌堆"
	root.size = VIEW
	root.content_scale_size = VIEW
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.disable_3d = true
	_canvas = Control.new()
	_canvas.size = Vector2(VIEW)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_canvas)
	_build_environment()
	await _prepare_deck()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_build_selected_page()
	await _settle(.4)
	await _capture("shoulder-hand.png")
	if "--cancel-only" in OS.get_cmdline_user_args():
		await _cancel_probe()
		quit(0 if _failures.is_empty() else 1)
	elif "--motion" in OS.get_cmdline_user_args():
		await _motion_sample()
		quit()
	elif "--probe" in OS.get_cmdline_user_args():
		await _probe()
		quit(0 if _failures.is_empty() else 1)
	elif not _interactive:
		quit()
	print("SHOULDER_HAND_READY: ", ProjectSettings.globalize_path(_output))

func _prepare_deck() -> void:
	for motif: String in ["event", "power", "activity", "anchor", "relic", "action"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256, 256)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var symbol := SymbolArt.new()
		symbol.size = Vector2(256, 256)
		symbol.motif = motif
		symbol.seed_value = 31
		viewport.add_child(symbol)
		await process_frame
		await RenderingServer.frame_post_draw
		_textures["symbol:" + motif] = ImageTexture.create_from_image(viewport.get_texture().get_image())
		viewport.queue_free()
	var definitions := {
		"event": ["活下来的代价", "事件", "symbol:event", "本轮事件"],
		"prayer": ["受贿书信外泄的裁判者", "祈求", _alternate.path, "等待回应"],
		"cult": [_samples[4].title, "教团", _samples[4].path, "所属：骸骨之月"],
		"power": ["入梦", "权能", "symbol:power", "选择对象"],
		"activity": ["秘密祈祷", "活动", "symbol:activity", "配置后核算"],
		"person": [_samples[5].title, "人物", _samples[5].path, "受贿书信外泄"],
		"anchor": ["锚定", "锚点", "symbol:anchor", "选择锚点与护持"],
		"relic": ["余响铃", "圣物", "symbol:relic", "查看圣物"],
		"action": ["回收", "行为", "symbol:action", "选择当地圣物"],
	}
	for repeat_index: int in 2:
		for category: String in ORDER:
			var entry: Array = definitions[category]
			var sample := _sample(str(entry[0]), str(entry[1]), str(entry[2]), str(entry[3]), "", "")
			sample.category_id = category
			if repeat_index == 1 and category == "cult":
				sample.title = _samples[3].title
				sample.path = _samples[3].path
				sample.line1 = "所属：溺亡之海"
			if repeat_index == 1 and category == "person":
				sample.path = _alternate.path
			_deck.append(sample)



func _build_selected_page() -> void:
	_page = Control.new()
	_page.size = Vector2(VIEW)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_page)
	_label(_page, "溺亡之海  /  世界玩法", Rect2(40,26,1180,40),28,Paint.BONE,true)
	_label(_page, "肩位牌堆 · 交互样板",Rect2(40,78,1180,24),16,Paint.MUTED)
	var master: Dictionary = _samples[0].duplicate()
	master.identity_variant = 2
	master.category_id = "world"
	_add_card(_page, master, LARGE, Vector2(42,156))
	_label(_page,"世界、教团与人物
沿用原生成图",Rect2(46,464,228,54),17,Paint.MUTED)
	_table = Table.new()
	_table.position = Vector2(304,134)
	_table.size = Vector2(936,420)
	_table.accepts_card = func(data: Dictionary) -> bool: return data.has("sample_index")
	_table.card_dropped.connect(_place)
	_page.add_child(_table)
	_empty_table()
	for entry: Array in [["全部 18",18],["密叠 48",48],["平铺 5",5]]:
		var button := Button.new()
		button.text = entry[0]
		button.theme = Paint.native_theme()
		button.position = Vector2(304+([18,48,5].find(entry[1]))*135,580)
		button.size = Vector2(121,32)
		button.add_theme_font_size_override("font_size",16)
		button.pressed.connect(_set_count.bind(int(entry[1])))
		_page.add_child(button)
	_hint = _label(_page,"",Rect2(306,884,936,24),16,Paint.BONE)
	_label(_page,"左右划牌 / 滚轮浏览 · 向上拖出查看 · 点击不会出牌",Rect2(306,917,936,22),14,Paint.MUTED)
	_label(_page,"原图样本
不读写存档",Rect2(46,857,228,52),14,Paint.MUTED)
	_set_count(_count)

func _set_count(count: int) -> void:
	_count = count
	if is_instance_valid(_fan):
		_page.remove_child(_fan)
		_fan.queue_free()
	_fan = Fan.new()
	_fan.name = "SelectedShoulderHand"
	_fan.position = Vector2(304,622)
	_fan.size = Vector2(936,260)
	_page.add_child(_fan)
	var faces: Array[Control] = []
	for i: int in count:
		var sample: Dictionary = _deck[i % _deck.size()].duplicate()
		sample.identity_variant = 2
		var card := _add_card(_fan,sample,SMALL,Vector2.ZERO)
		card.payload = {"sample_index":i % _deck.size(), "id":str(i)}
		faces.append(card)
	_fan.focus_changed.connect(_focused)
	_fan.card_hovered.connect(_focused)
	_fan.configure(faces)
	_fan.set_focus(1 if count > 1 else 0)
	_focused(_fan.focus_index)

func _focused(index: int) -> void:
	if index < 0 or index >= _fan.cards.size(): return
	var sample: Dictionary = _deck[index % _deck.size()]
	_hint.text = "%s · %s  /  %d张中的第%d张" % [sample.kind,sample.title,_count,index+1]

func _clear_table() -> void:
	for child: Node in _table.get_children():
		_table.remove_child(child)
		child.queue_free()

func _empty_table() -> void:
	_clear_table()
	_label(_table,"将一张牌拖到这里",Rect2(40,82,820,46),29,Paint.BONE,true)
	_label(_table,"牌堆中抬起的是线索。
拖出后，才在这里展开完整卡面。",Rect2(43,154,830,80),20,Paint.MUTED)

func _place(data: Dictionary) -> void:
	_shown = data
	_clear_table()
	var sample: Dictionary = _deck[int(data.sample_index)].duplicate()
	sample.identity_variant = 2
	_add_card(_table,sample,FULL_SIZE,Vector2(12,5))
	_label(_table,str(sample.title),Rect2(307,52,600,76),28,Paint.BONE,true)
	_label(_table,"%s · 完整查阅" % sample.kind,Rect2(310,149,590,28),19,Paint.BONE)
	_label(_table,str(sample.line1),Rect2(310,199,590,40),19,Paint.MUTED)
	_label(_table,"此处验证出牌与材质承载。
正式行动仍由游戏牌桌提供。",Rect2(310,267,590,62),17,Paint.MUTED)
	var recall := Button.new()
	recall.text = "收回 ↓"
	recall.theme = Paint.native_theme()
	recall.position = Vector2(736,358)
	recall.size = Vector2(166,36)
	recall.pressed.connect(_empty_table)
	_table.add_child(recall)

func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_output.path_join(file_name))
	print("CAPTURE: ",_output.path_join(file_name))

func _settle(seconds: float) -> void:
	await create_timer(seconds).timeout

func _pointer(at: Vector2, previous: Vector2, down := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - previous
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)
	await process_frame

func _button_input(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event,true)
	await process_frame

func _point(index: int) -> Vector2:
	var card: Control = _fan.cards[index]
	var gap: float = _fan.cards[index+1].position.x-card.position.x if index < _fan.cards.size()-1 else card.size.x
	return _fan.position+Vector2(card.position.x+minf(gap*.5,13),160)

func _check(ok: bool, detail: String) -> void:
	if not ok:
		_failures.append(detail)
		push_error(detail)

func _probe() -> void:
	var samples: Array = []
	for count: int in [5,18,48]:
		_set_count(count)
		await _settle(.3)
		var positions: Array = []
		for card: Control in _fan.cards: positions.append(card.position.x)
		var at := Vector2(310,800)
		for index: int in count:
			var target := _point(index)
			await _pointer(target,at)
			at = target
			await _settle(.07)
			_check(_fan.focus_index==index,"Stable edge hit %d/%d" % [index,count])
			for i: int in count:
				_check(is_equal_approx(_fan.cards[i].position.x,positions[i]),"Hand shifted horizontally")
				_check(_fan.cards[i].z_index==0,"Browse changed depth")
				_check(_fan.cards[i].visible,"Card disappeared")
				samples.append({"count":count,"focus":index,"card":i,"y":_fan.cards[i].position.y})
		_fan.set_focus(1)
		await _settle(.4)
		await _capture("hand-%d.png" % count)
	_set_count(18)
	await _settle(.3)
	# Quick reversals exercise interrupted lift motion without rearranging cards.
	for index: int in [2,3,4,7,11,15,13,10,8,5,3,1]:
		await _pointer(_point(index),Vector2.ZERO)
		await _settle(.025)
	await _settle(.3)
	var point := _point(1)
	await _pointer(point,Vector2.ZERO)
	await _button_input(point,true)
	await _button_input(point,false)
	_check(_shown.is_empty(),"Click played a card")
	await _settle(.3)
	await _button_input(point,true)
	await _pointer(point+Vector2(0,-46),point,true)
	await _pointer(Vector2(825,350),point+Vector2(0,-46),true)
	_check(root.gui_is_dragging(),"Native upward drag did not start")
	await _button_input(Vector2(825,350),false)
	_check(_shown.get("sample_index",-1)==1,"Wrong card on table")
	await _settle(.4)
	await _capture("placed-card.png")
	var report := {"failures":_failures,"motion_samples":samples.size(),"checks":"5/18/48; all edges hit; fixed x/z; click does not play; native upward drop"}
	FileAccess.open(_output.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SHOULDER_PROBE: ",JSON.stringify(report))

func _motion_sample() -> void:
	_set_count(18)
	await _settle(.35)
	var previous := _point(0)
	for index: int in range(18):
		await _pointer(_point(index),previous)
		previous = _point(index)
		await _settle(.13)
	for index: int in range(17,-1,-1):
		await _pointer(_point(index),previous)
		previous = _point(index)
		await _settle(.10)
	await _settle(.25)
	# Release outside the table: the full drag image returns to its slot.
	var cancel_start := _point(5)
	await _pointer(cancel_start,previous)
	await _settle(.3)
	await _button_input(cancel_start,true)
	await _pointer(cancel_start+Vector2(0,-46),cancel_start,true)
	var cancel_at := Vector2(250,520)
	for step: int in 30:
		await _pointer((cancel_start+Vector2(0,-46)).lerp(cancel_at,float(step+1)/30),cancel_start,true)
	await _button_input(cancel_at,false)
	_check(_shown.is_empty(),"Invalid drop placed a card")
	await _settle(.3)
	var start := _point(8)
	await _pointer(start,previous)
	await _settle(.3)
	await _button_input(start,true)
	var target := Vector2(1000,460)
	for step: int in 24:
		var point := start.lerp(start+Vector2(0,-80),float(step+1)/24.0)
		await _pointer(point,start,true)
	for step: int in 24:
		var point := (start+Vector2(0,-80)).lerp(target,float(step+1)/24.0)
		await _pointer(point,start,true)
	await _button_input(target,false)
	await _settle(.5)
	_set_count(48)
	await _settle(.3)
	for index: int in range(0,48,2):
		await _pointer(_point(index),previous)
		previous = _point(index)
		await _settle(.09)
	await _settle(.4)

func _cancel_probe() -> void:
	_set_count(18)
	await _settle(.2)
	for cancel_with_escape: bool in [false,true]:
		var start := _point(4)
		await _pointer(start,Vector2.ZERO)
		await _button_input(start,true)
		await _pointer(start+Vector2(0,-46),start,true)
		var outside := Vector2(260,490)
		await _pointer(outside,start,true)
		_check(root.gui_is_dragging(),"Cancellation never started dragging")
		if cancel_with_escape:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.pressed = true
			root.push_input(key,true)
			await process_frame
		else:
			await _button_input(outside,false)
		_check(is_instance_valid(_fan._return_layer),"Missing return ghost (escape=%s)" % cancel_with_escape)
		await _settle(.25)
		_check(not is_instance_valid(_fan._return_layer),"Return ghost remained after settling")
		_check(_shown.is_empty(),"Cancellation placed a card")
		await _button_input(outside,false)
	print("CANCEL_PROBE: ",JSON.stringify(_failures))
