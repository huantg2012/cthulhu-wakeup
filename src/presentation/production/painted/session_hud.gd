extends Node
## Selected fissure HUD. Public resources only; interaction routes remain on the host.
const Mark = preload("res://src/presentation/production/painted/hud_mark.gd")
const Boundary = preload("res://src/presentation/production/painted/hud_boundary.gdshader")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
# Exclude the worn inward lip when centering contents on the visible carrier.
const DOCK_INNER_LIP := 6.0
const EDGE_GAP := 6.0
var host: Control
var _seen := {}
var _drawn_awakening := 0.0
var _target_awakening := 0.0
var _pulse := 0.0
var _delta := 0
var _elapsed := 0.0
var _whisper_slots := 0
var _whisper_energy: Array[float] = []
var _marks: Array[Control] = []
var _top: Control
var _dock: Control
var _awakening: Label
var _whispers: Label
var _faith: Label
var _change: Label
var _next: Button

func _process(delta: float) -> void:
	_elapsed += delta
	var visible_delta := delta if not host._table_blocked() else 0.0
	_pulse = maxf(0.0,_pulse-visible_delta*.65)
	_drawn_awakening = lerpf(_drawn_awakening,_target_awakening,1.-exp(-visible_delta*4.0))
	for i: int in range(_marks.size()-1,-1,-1):
		if not is_instance_valid(_marks[i]): _marks.remove_at(i)
	while _whisper_energy.size() < _whisper_slots: _whisper_energy.append(0.0)
	var whispers_now := int(_whispers.text) if is_instance_valid(_whispers) else 0
	for i: int in _whisper_energy.size():
		_whisper_energy[i] = lerpf(_whisper_energy[i],1.0 if i<whispers_now else 0.0,1.-exp(-visible_delta*7.0))
	for mark: Control in _marks:
		if not mark.motif in ["awakening","whispers","turn"]: continue
		mark.elapsed = _elapsed
		mark.amount = _drawn_awakening
		mark.change = _pulse*signf(_delta)
		if mark.motif == "whispers":
			mark.count = int(_whispers.text) if is_instance_valid(_whispers) else int(host.projection.get("whispers",0))
			mark.slots = _whisper_slots
			mark.energies = _whisper_energy
		if mark.motif == "turn" and is_instance_valid(_next):
			mark.hover = lerpf(mark.hover,1.0 if _next.is_hovered() or _next.has_focus() else 0.0,1.-exp(-delta*12.0))
			mark.pressed = _next.button_pressed
			mark.muted = _next.disabled
			_next.get_node("NextTurnCaption").modulate.a = .45 if _next.disabled else 1.0
		mark.queue_redraw()
	if is_instance_valid(_change):
		_change.text = ("+" if _delta>0 else "")+str(_delta) if _pulse > 0. else ""
		_change.modulate.a = minf(1.,_pulse*2.)
		_change.position.y = 10.-(1.-_pulse)*9.

func _observe() -> void:
	var p: Dictionary = host.projection
	var cap := float(host.session.catalog.integer("awakening_terminal"))
	_target_awakening = float(p.awakening)/cap
	if _seen.is_empty(): _drawn_awakening = _target_awakening
	elif int(_seen.awakening) != int(p.awakening):
		_delta = (0 if _pulse <= 0.0 else _delta)+int(p.awakening)-int(_seen.awakening)
		_pulse = 1.0
	if int(_seen.get("turn",-1)) != int(p.turn): _whisper_slots = int(p.whispers)
	_whisper_slots = maxi(_whisper_slots,int(p.whispers))
	_seen = {"turn":p.turn,"awakening":p.awakening,"faith":p.faith,"whispers":p.whispers}

func _mark(parent: Control,motif: String,bounds: Rect2) -> Control:
	var paint := Mark.new()
	paint.name = "Pigment_"+motif
	paint.motif = motif
	paint.position = bounds.position
	paint.size = bounds.size
	parent.add_child(paint)
	_marks.append(paint)
	return paint

func _boundary(parent: Control,lower: bool,bounds: Rect2) -> void:
	var surface := ColorRect.new()
	surface.name = "LowerRim" if lower else "UpperRim"
	var old := parent.get_node_or_null(NodePath(surface.name))
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	surface.position = bounds.position
	surface.size = bounds.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Boundary
	material.set_shader_parameter("ink",Paint.INK.darkened(.48))
	material.set_shader_parameter("pigment",Paint.INK.lerp(Paint.MUTED,.12))
	material.set_shader_parameter("edge_ink",Paint.MUTED)
	material.set_shader_parameter("extent",bounds.size)
	material.set_shader_parameter("lower",lower)
	surface.material = material
	parent.add_child(surface)
	parent.move_child(surface,0)

func _label(parent: Control,node_name: String,caption: String,bounds: Rect2,px: int,color:=Paint.BONE) -> Label:
	return host._ui.label(parent,node_name,caption,bounds,px+host._size(0),color)

func _hit(parent: Control,node_name: String,bounds: Rect2,callback: Callable,caption: String,px:=14) -> Button:
	var button: Button = host._ui.button(parent,node_name,caption,bounds,callback,false,true)
	button.add_theme_font_size_override("font_size",px+host._size(0))
	for state: String in ["normal","pressed","disabled"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_hover_color",Paint.HOVER)
	return button

# One type scale for the perimeter: 14 navigation, 16 resource labels,
# 24 resource values, 20 next-turn. Main card/execution headings keep their scale.
func _width(caption: String, px: int) -> float:
	return ceilf(Paint.fonts().body.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px+host._size(0)).x)

func _inline_label(parent: Control,node_name: String,caption: String,x: float,px: int,color:=Paint.BONE,center_y:=23.0) -> Label:
	return _label(parent,node_name,caption,Rect2(x,center_y-20,_width(caption,px),40),px,color)

func _dock_center() -> float:
	return roundf((DOCK_INNER_LIP+_dock.size.y)*.5)

func _dock_bounds(x: float,width: float,height: float) -> Rect2:
	return Rect2(x,_dock_center()-height*.5,width,height)

func build_top(parent: Control) -> void:
	_observe()
	_top = host._region(parent,"Top",Rect2(0,0,1280,80))
	_boundary(parent,false,Rect2(0,0,1280,52))
	var turn := _inline_label(_top,"Turn","第 %s 轮" % host.projection.turn,EDGE_GAP+34,16)
	var phase := _inline_label(_top,"Phase",str(host.projection.phase_title),turn.position.x+turn.size.x+18,14,Paint.MUTED)
	var epoch := _mark(_top,"epoch",Rect2(EDGE_GAP,2,phase.position.x+phase.size.x-EDGE_GAP+18,42))
	_top.move_child(epoch,1)
	var echo := _hit(_top,"RoundEcho",Rect2(292,8,94,30),host._show_arrival.bind(true),"本轮回响")
	echo.tooltip_text = "重看本轮新出现的事件、祈求、人物和能力"
	var caption := _inline_label(_top,"AwakeningCaption","苏醒",464,16,Paint.WARM)
	_awakening = _inline_label(_top,"AwakeningAmount",str(host.projection.awakening),caption.position.x+caption.size.x+8,24)
	var limit := _inline_label(_top,"AwakeningLimit","/ %s" % host.session.catalog.integer("awakening_terminal"),_awakening.position.x+_awakening.size.x+5,14,Paint.MUTED)
	var fissure_x := limit.position.x+limit.size.x+12
	_mark(_top,"awakening",Rect2(fissure_x,1,234,48))
	_change = _label(_top,"AwakeningChange","",Rect2(fissure_x+242,10,55,25),16,Paint.WARM)
	var awakening_hit := _hit(_top,"AwakeningReadout",Rect2(455,0,fissure_x+234-455,46),host._dock_subject.bind("self"),"")
	_top.move_child(awakening_hit,1)
	awakening_hit.accessibility_name = "苏醒与降临"
	awakening_hit.tooltip_text = "苏醒 %s / %s\n初生、洞见与现存锚点的贡献减去创伤。\n点击查阅苏醒与降临。" % [host.projection.awakening,host.session.catalog.integer("awakening_terminal")]
	var faith_value := str(host.projection.faith)
	var faith_x := 1280-EDGE_GAP-_width(faith_value,24)-8-_width("信仰",16)
	var faith_bounds := Rect2(faith_x-46,0,1280-(faith_x-46),46)
	_mark(_top,"faith",faith_bounds)
	var faith_hit := _hit(_top,"Faith",faith_bounds,host._dock_subject.bind("budget"),"")
	faith_hit.accessibility_name = "供奉与收支"
	faith_hit.tooltip_text = "信仰 %s / 容量 %s\n用于干预、活动及维持锚点；点击查阅供奉与收支。" % [host.projection.faith,host.projection.capacity]
	var faith_caption := _inline_label(_top,"FaithCaption","信仰",faith_x,16,Paint.WARM)
	_faith = _inline_label(_top,"FaithAmount",faith_value,faith_caption.position.x+faith_caption.size.x+8,24)
	host._menu_button = _hit(_top,"Menu",Rect2(1280-EDGE_GAP-36,56,36,26),host._show_menu,"⋯",16)
	host._menu_button.disabled = host._event_table()

func build_path(parent: Control,items: Array) -> void:
	var path: Control = host._region(parent,"ContextPath",Rect2(EDGE_GAP,56,1280-EDGE_GAP*2-48,26))
	var x := 0.0
	for index: int in items.size():
		var item: Dictionary = items[index]
		if index > 0:
			_label(path,"Separator"+str(index),"›",Rect2(x,0,12,26),14,Paint.MUTED)
			x += 20
		var caption: String = item.caption
		var available := path.size.x-x
		var width := minf(_width(caption,14)+18,minf(390,available))
		var callback: Callable = item.get("callback",Callable())
		if callback.is_valid():
			var button := _hit(path,item.name,Rect2(x,0,width,26),callback,caption)
			button.add_theme_color_override("font_color",Paint.MUTED)
			button.tooltip_text = caption
		else:
			var label := _label(path,item.name,caption,Rect2(x+9,0,width-18,26),14)
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = caption
			label.mouse_filter = Control.MOUSE_FILTER_PASS
		x += width+8

func build_dock(parent: Control) -> void:
	_dock = parent
	_boundary(_dock,true,Rect2(Vector2.ZERO,_dock.size))
	var x := EDGE_GAP
	for item: Array in [["PowerIndex","权能","power"],["RelicIndex","圣物","relic"],["People","人物档案","person"],["History","编年史","history"]]:
		var width := _width(item[1],14)+20
		var library: bool = item[2] in ["power","relic","person"]
		var callback: Callable = host._open_library.bind(item[2]) if library else host._dock_subject.bind(item[2])
		var button := _hit(_dock,item[0],_dock_bounds(x,width,34),callback,item[1])
		if library:
			host._ui.choice_style(button,host._library==item[2])
			if host._library!=item[2]: button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			button.tooltip_text = "只读图鉴 · 行动从世界或教团的行为牌发起"
		x += width+10
	var responsibility := _hit(_dock,"RoundResponsibilities",_dock_bounds(658,104,34),host._show_hud_responsibilities,"回合责任")
	responsibility.tooltip_text = "可选回看：供奉、未回应祈求与已登记计划。不会推进回合。"
	responsibility.add_theme_color_override("font_color",Paint.MUTED)
	# Keep the resource group together; no centering values inside oversized boxes.
	# Spent flame positions remain stable until the next turn.
	var flame_width := maxf(8,float(_whisper_slots-1)*15+8)
	var whisper_value := str(host.projection.whispers)
	var whisper_width := _width("低语",16)+8+_width(whisper_value,24)+10+flame_width
	var next_width := 197.0
	var next_x := _dock.size.x-EDGE_GAP-next_width
	var whisper_x := next_x-16.0-whisper_width
	var whisper_info: Control = host._region(_dock,"WhisperInfo",_dock_bounds(whisper_x-6,whisper_width+12,40))
	whisper_info.mouse_filter = Control.MOUSE_FILTER_PASS
	whisper_info.tooltip_text = "本轮剩余行动预算；未用低语不会结转。\n亮着的余焰表示剩余低语，熄灭痕迹表示本轮已用。"
	var caption := _inline_label(_dock,"WhisperCaption","低语",whisper_x,16,Paint.WARM,_dock_center())
	_whispers = _inline_label(_dock,"WhisperAmount",whisper_value,caption.position.x+caption.size.x+8,24,Paint.BONE,_dock_center())
	_mark(_dock,"whispers",_dock_bounds(_whispers.position.x+_whispers.size.x+10,flame_width,26))
	var button_bounds := _dock_bounds(next_x,next_width,42)
	_mark(_dock,"turn",button_bounds)
	_next = _hit(_dock,"PhaseAction",button_bounds,host._show_hud_next_turn,"",20)
	for state: String in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		_next.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	# The painted control owns all feedback; framework focus styles must not
	# reintroduce a second stock rectangle behind it. Child caption stays visible.
	_next.self_modulate = Color(1,1,1,0)
	_next.accessibility_name = "下一回合"
	_label(_next,"NextTurnCaption","下一回合" if host.projection.phase!="ended" else "回顾本局",Rect2(16,4,137,34),20)
	_next.tooltip_text = "结算本轮并进入下一轮；点击后确认。" if host.projection.phase=="actions" else "先处理轮初事件" if host.projection.phase=="events" else "回合交接"
	host._phase_plate = _next

func sync_input(blocked: bool) -> void:
	if not is_instance_valid(_top): return
	for id: String in ["Faith","AwakeningReadout"]:
		var button := _top.get_node_or_null(id) as Button
		if button != null: button.disabled = blocked

func reset() -> void:
	_seen.clear()
	_pulse = 0.
	_whisper_energy.clear()
	_whisper_slots = 0
