extends "res://tools/worldplay-integration/probe.gd"
## Read-only catalogue lesson. Production card/fan/drop/portrait renderers;
## only the two-up before/current layout is special to this art study.
const Catalogue = preload("res://tools/card-illustration-study/catalogue.gd")
const Library = preload("res://src/presentation/production/worldplay/illustrations/library.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Atmosphere = preload("res://src/presentation/production/painted/peripheral_atmosphere.gd")
const Fan = preload("res://src/presentation/production/worldplay/hand_fan.gd")
const Table = preload("res://src/presentation/production/worldplay/table_drop.gd")
const StudyCard = preload("res://src/presentation/production/worldplay/study_card.gd")
const REFERENCE_PATH := "res://docs/art/visual-generation/procedural-study/native-evidence/tide/"
const SECTIONS := {"mixed":"六张样牌", "powers":"权能", "activities":"活动", "relics":"圣物"}
const MIXED := ["record/POWER_DREAM", "ROUTE_COVERT_GATHERING", "relic/RELIC_ECHO_BELL",
	"record/POWER_BREACH", "ROUTE_RECORD_PRACTICE", "relic/RELIC_LIVING_SCRIPT"]
var canvas: Control
var page: Control
var desk: Control
var study_fan: Control
var deck: Array[Dictionary] = []
var visible_deck: Array[Dictionary] = []
var variant := 2
var section := "mixed"
var selected: Dictionary = {}
var status: Label
var snapshot := ""
var environment: Control
class Inputs extends Control:
	signal variant_requested(index: int)
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1,KEY_2]:
			variant_requested.emit(event.keycode-KEY_1+1)
			get_viewport().set_input_as_handled()

func run() -> void:
	output = "res://docs/art/visual-generation/card-illustration-study/b-refinement"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await setup(PackedStringArray(["--seed=5"])): return
	snapshot = app.session.turn.snapshot()
	deck = Catalogue.cards(app.session.catalog)
	if not require(deck.size()==64,"Catalogue incomplete: "+str(deck.size())): return
	deck = deck.filter(func(card: Dictionary)->bool: return card.id in MIXED)
	if not require(deck.size()==6,"Category art samples incomplete"): return
	app.hide()
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	root.title = "邪神苏醒 · B 梦中残迹 / 打磨对照"
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	canvas = Inputs.new()
	canvas.variant_requested.connect(_set_variant)
	canvas.size = Vector2(1280,720)
	canvas.theme = Paint.native_theme()
	root.add_child(canvas)
	var night := TextureRect.new()
	night.size = canvas.size
	night.texture = Paint.MaterialSource.pigment("sky")
	night.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(night)
	environment = Atmosphere.new()
	canvas.add_child(environment)
	environment.paused = true
	environment.set_sample_time(6.0)
	selected = _find("record/POWER_DREAM")
	if "--capture" in OS.get_cmdline_user_args():
		await _evidence()
		if "--exit" in OS.get_cmdline_user_args(): quit(); return
	_interactive()
	if "--verify" in OS.get_cmdline_user_args():
		if not await _verify_lesson(): return
	environment.paused = false
	print("ILLUSTRATION_STUDY_READY | selected B / 6 before-current samples | ",ProjectSettings.globalize_path(output))

func _clear() -> void:
	if is_instance_valid(page):
		canvas.remove_child(page)
		page.queue_free()
	page = Control.new()
	page.size = canvas.size
	canvas.add_child(page)

func _interactive() -> void:
	_clear()
	_label(page,"梦中残迹 / B 打磨",Rect2(30,14,250,34),22,true)
	_label(page,"权能异象 · 活动符文 · 圣物器形",Rect2(31,48,260,24),13)
	_context()
	for i: int in range(1,3):
		_button(page,Library.VARIANTS[i],Rect2(375+(i-1)*465,43,230,30),_set_variant.bind(i))
	desk = Table.new()
	desk.position = Vector2(282,78)
	desk.size = Vector2(965,325)
	desk.accepts_card = func(card: Dictionary)->bool: return card.get("catalogue_only",false)
	desk.card_dropped.connect(_place)
	page.add_child(desk)
	_render_desk()
	var x := 304.0
	for key: String in SECTIONS:
		_button(page,SECTIONS[key],Rect2(x,415,73,27),_filter_study.bind(key))
		x += 79
	_label(page,"1 前版 / 2 当前打磨",Rect2(950,416,300,24),13)
	study_fan = Fan.new()
	study_fan.position = Vector2(296,444)
	study_fan.size = Vector2(950,242)
	page.add_child(study_fan)
	study_fan.focus_changed.connect(_focus_study)
	study_fan.card_hovered.connect(_focus_study)
	status = _label(page,"",Rect2(304,690,940,24),13)
	_render_study_hand()

func _context() -> void:
	_sheet_context()

func _render_desk() -> void:
	for child: Node in desk.get_children():
		desk.remove_child(child)
		child.queue_free()
	for i: int in range(1,3):
		var face: Control = app._face(desk,selected,Rect2(93+(i-1)*465,0,210,315),{"illustration_variant":i})
		# The desk receives the drop; the before/current cards are display-only.
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.hover_enabled = false

func _render_study_hand() -> void:
	visible_deck = _cards_for(section)
	for child: Node in study_fan.get_children():
		study_fan.remove_child(child)
		child.queue_free()
	var faces: Array[Control] = []
	for card: Dictionary in visible_deck:
		faces.append(app._face(study_fan,card,Rect2(Vector2.ZERO,Fan.HAND_SIZE),{"illustration_variant":variant}))
	study_fan.configure(faces)
	study_fan.set_focus(0,false)
	_focus_study(0)

func _focus_study(index: int) -> void:
	if index>=0 and index<visible_deck.size():
		status.text = "%s · %s  /  %d 张    左右划牌 · 向上拖到桌面，比较打磨前后" % [Library.VARIANTS[variant],visible_deck[index].title,visible_deck.size()]

func _place(card: Dictionary) -> void:
	selected = card
	_render_desk()
	if not require(snapshot==app.session.turn.snapshot(),"Art lesson changed Session"): return

func _set_variant(next: int) -> void:
	variant = next
	if is_instance_valid(study_fan): _render_study_hand()

func _filter_study(next: String) -> void:
	section = next
	_render_study_hand()

func _cards_for(key: String) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if key=="mixed":
		for id: String in MIXED: cards.append(_find(id))
	else:
		for card: Dictionary in deck:
			if key=="all" or card.catalogue_section==key: cards.append(card)
	return cards

func _find(id: String) -> Dictionary:
	for card: Dictionary in deck:
		if card.id==id: return card
	push_error("Unknown illustration catalogue identity: "+id)
	return {}

func _sheet(cards: Array[Dictionary], caption: String) -> void:
	_clear()
	_label(page,"梦中残迹 / "+Library.VARIANTS[variant],Rect2(36,16,560,38),27,true)
	_label(page,caption,Rect2(620,22,620,28),16)
	_sheet_context()
	var columns := ["权能 / 单一印记", "活动 / 仪式痕迹", "圣物 / 可辨器形"]
	for i: int in range(3):
		_label(page,columns[i],Rect2(300+i*320,57,280,24),15)
	for i: int in cards.size():
		app._face(page,cards[i],Rect2(300+(i%3)*320,88+(i/3)*309,180,270),{"illustration_variant":variant})
	_label(page,"三类各两张 · 同一正式卡壳 / 肩签 / 厚度 / 融接遮罩 · 美术候选，未替换正式游戏",Rect2(300,688,950,25),13)

func _sheet_context() -> void:
	# Accepted generator evidence, NOT objects invented in this isolated Session.
	# Render original pixels with the same production carrier as the actual cards.
	var references := [
		["world","世界","塔穆什","world.png"],
		["cult","教团","听潮密会","cult.png"],
		["person","人物","受贿的裁判者","person-0-1000.png"]]
	for i: int in references.size():
		var data: Array = references[i]
		var face := StudyCard.new()
		face.position = Vector2(40,68+i*209)
		face.size = Vector2(128,192)
		face.custom_minimum_size = face.size
		face.palette = data[0]
		face.hover_enabled = false
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(face)
		var image := Image.load_from_file(REFERENCE_PATH+str(data[3]))
		face.configure_carrier({"kind":data[1],"art_kind":data[0],"category_id":data[0],"identity_variant":2,
			"title":data[2],"line1":"原生成图 · 画法参考","line2":"","paper_backed":false},ImageTexture.create_from_image(image))

func _evidence() -> void:
	for i: int in range(1,3):
		variant = i
		section = "mixed"
		_sheet(_cards_for("mixed"),"参考原立绘笔触 / B 六张精修")
		await capture("before-categories" if i==1 else "refined-categories")
		_interactive()
		await capture("before-table" if i==1 else "refined-table")
	if not require(snapshot==app.session.turn.snapshot(),"Captures changed Session"): return
	variant = 2
	print("ILLUSTRATION_SHEETS_DONE")

func _verify_lesson() -> bool:
	for code: Key in [KEY_1,KEY_2]:
		await press_key(code)
		if not require(variant==code-KEY_1+1,"Comparison number key did not switch art"): return false
	_filter_study("relics")
	await process_frame
	study_fan.set_focus(0,false)
	var card: Control = study_fan.cards[0]
	var start: Vector2 = study_fan.get_global_transform_with_canvas()*(card.position+Vector2(10,130))
	var target: Vector2 = desk.get_global_transform_with_canvas()*Vector2(130,190)
	await pointer_move(start,Vector2.ZERO)
	await pointer_button(start,true)
	await pointer_move(start+Vector2(0,-46),start,true)
	await pointer_move(target,start+Vector2(0,-46),true)
	if not require(root.gui_is_dragging(),"Native art-study drag did not start"): return false
	await pointer_button(target,false)
	if not require(selected.id==visible_deck[0].id,"Native art-study drop did not select matching card"): return false
	if not require(snapshot==app.session.turn.snapshot(),"Read-only art comparison changed Session"): return false
	await capture("relic-before-after")
	_filter_study("mixed")
	_place(_find("record/POWER_DREAM"))
	print("ART_LESSON_INPUT_OK: 1/2 + native hand drag/drop + unchanged isolated Session")
	return true

func _label(parent: Node, value: String, rect: Rect2, pixels: int, heading := false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font",Paint.fonts().heading if heading else Paint.fonts().body)
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",Paint.BONE if heading else Paint.MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,Paint.button_style(state,Paint.Role.NAVIGATION))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
