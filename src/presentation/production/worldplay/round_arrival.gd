extends CanvasLayer
## An arrival of public cards, above the existing living atmosphere. Read-only.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Fan = preload("res://src/presentation/production/worldplay/hand_fan.gd")
const Veil = preload("res://src/presentation/production/painted/arrival_veil.gdshader")
const NAMES := {"event":"世界异动", "prayer":"祈求", "person":"新知人物", "unlock":"新启权能／行为"}
signal finished
var _host: WeakRef
var _body: Control
var _hero: Control
var _reading: Control
var _fan: Control
var _hint: Label
var _cards: Array = []
var _motion: Tween
var _entrance: Tween
var _focus_before: WeakRef
var _hidden_layers: Array[WeakRef] = []
var selected := -1

func _ready() -> void:
	layer = 19
	hide()

func open(host: Control, cards: Array, counts: Dictionary, turn: int, replay := false) -> void:
	_host = weakref(host)
	_cards = cards
	selected = -1
	var focus := get_viewport().gui_get_focus_owner()
	_focus_before = weakref(focus) if focus != null else null
	_hidden_layers.clear()
	for surface: Control in [host._stage, host._persistent_dock]:
		if is_instance_valid(surface) and surface.visible:
			_hidden_layers.append(weakref(surface))
			surface.hide()
	if _body != null:
		remove_child(_body)
		_body.queue_free()
	_body = Control.new()
	_body.name = "RoundArrival"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.theme = Paint.native_theme()
	add_child(_body)
	host._ui.fill(_body,"Shade",Rect2(0,0,1280,720),Color("0a1216",.70))
	host._ui.image(_body,"Pigment",Rect2(0,0,1280,720),Paint.MaterialSource.pigment("sky"),Color(1,1,1,.32),TextureRect.STRETCH_SCALE)
	host._text(_body,"第 %s 轮 · 诸界回响" % turn,Rect2(86,40,900,48),30)
	host._text(_body,"轮初记录 · 以当前牌桌状态为准" if replay else "新的波澜，已触及你的感知。",Rect2(795,55,400,24),16,Paint.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var x := 87.0
	for category: String in NAMES:
		if counts.get(category,0)==0: continue
		var first := -1
		for i: int in cards.size():
			if cards[i].arrival == category: first = i; break
		var button: Button = host._button(_body,"ArrivalGroup_"+category,"%s  %s" % [NAMES[category],counts[category]],Rect2(x,98,158,28),_focus.bind(first))
		button.add_theme_font_size_override("font_size",15)
		x += 174
	_hero = host._region(_body,"FeaturedCard",Rect2(98,139,244,250))
	_reading = host._region(_body,"Reading",Rect2(390,149,788,241))
	_fan = Fan.new()
	_fan.name = "ArrivingCards"
	_fan.allow_play = false
	_fan.position = Vector2(86,400)
	_fan.size = Vector2(1108,260)
	_body.add_child(_fan)
	var faces: Array[Control] = []
	for card: Dictionary in cards:
		var face: Control = host._face(_fan,card,Rect2(0,0,148,198))
		face.payload = {}
		host._spines(face,host._spine_caption(card))
		faces.append(face)
	_hint = host._text(_body,"",Rect2(88,677,740,24),14,Paint.MUTED)
	var caption := "进入本轮 · 先处理事件 →" if counts.get("event",0)>0 else "进入本轮 →"
	if replay: caption = "返回牌桌 →"
	host._button(_body,"EnterRound",caption,Rect2(923,670,271,34),close,true)
	_fan.focus_changed.connect(_select)
	_fan.configure(faces)
	show()
	_fan.grab_focus()
	_body.modulate.a = 0.0
	_fan.position.y = 420
	_fan.modulate.a = 0.0
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(_body,"modulate:a",1.0,.26)
	_entrance.tween_property(_fan,"position:y",400.0,.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance.tween_property(_fan,"modulate:a",1.0,.48).set_delay(.13)

func _focus(index: int) -> void:
	if index>=0:
		_fan.set_focus(index)
		_fan.grab_focus()

func _select(index: int) -> void:
	if index == selected or index < 0 or index >= _cards.size(): return
	selected = index
	if _motion != null: _motion.kill()
	var host: Control = _host.get_ref()
	for parent: Control in [_hero,_reading]:
		for child: Node in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var card: Dictionary = _cards[index]
	# The artwork is smaller, the type is not. The complete title also stays
	# beside it in the reading area; this face retains its 24px heading.
	var face: Control = host._face(_hero,card,Rect2(22,0,200,250),{"title_font_size":24,"title_max_lines":1})
	face.payload = {}
	face.hover_enabled = false
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.focus_mode = Control.FOCUS_NONE
	# The same continuous carrier adapts its image and reading area to this
	# larger face. No second image rectangle or label offsets are overlaid.
	var veil := ColorRect.new()
	veil.position = Vector2(7,-11)
	veil.size = Vector2(230,272)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Veil
	veil.material = material
	_hero.add_child(veil)
	var tint: Color = face.stock_tint().lerp(Color.WHITE,.75) * Paint.BONE
	host._text(_reading,card.eyebrow,Rect2(0,0,788,27),16,tint)
	var world := str(card.get("domain",""))
	var place: String = host.title(world) if not world.is_empty() else "诸界之间"
	if place.strip_edges().is_empty(): place = "尚未知晓的世界"
	if card.arrival == "unlock" and (card.group == "power" or card.id == "anchor/bind"): place = "你的神意，触及更远处"
	host._text(_reading,place,Rect2(0,34,788,25),15,Paint.MUTED)
	var title: Label = host._text(_reading,str(card.title),Rect2(0,70,788,64),27)
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var scroll: ScrollContainer = host._scroller(_reading,Rect2(0,140,788,56))
	var text := Label.new()
	text.name = "ArrivalStory"
	text.text = str(card.story)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size",host._size(18))
	text.add_theme_color_override("font_color",Paint.BONE)
	scroll.add_child(text)
	host._text(_reading,str(card.guidance),Rect2(0,205,788,36),15,Paint.MUTED)
	_hint.text = "%02d / %02d   ·   横向翻阅，或点选上方类别   ·   此处只查阅" % [index+1,_cards.size()]
	_hero.position = Vector2(98,146)
	_hero.rotation = -.018
	_hero.modulate.a = .12
	_reading.modulate.a = 0.0
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(_hero,"position",Vector2(98,139),.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_hero,"rotation",0.0,.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_hero,"modulate:a",1.0,.38)
	_motion.tween_method(func(value: float) -> void: material.set_shader_parameter("opening",value),0.0,1.0,.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_reading,"modulate:a",1.0,.35).set_delay(.12)

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or (event.keycode in [KEY_ENTER,KEY_KP_ENTER] and get_viewport().gui_get_focus_owner() == _fan):
			get_viewport().set_input_as_handled()
			close()

func close() -> void:
	if not visible: return
	if _motion != null: _motion.kill()
	if _entrance != null: _entrance.kill()
	hide()
	_fan.set_blocked(true)
	for reference: WeakRef in _hidden_layers:
		var surface := reference.get_ref() as Control
		if surface != null: surface.show()
	_hidden_layers.clear()
	if _focus_before != null:
		var focus := _focus_before.get_ref() as Control
		if focus != null and focus.is_visible_in_tree(): focus.grab_focus()
	finished.emit()
