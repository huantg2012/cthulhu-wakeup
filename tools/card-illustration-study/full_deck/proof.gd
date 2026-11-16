extends SceneTree
## Isolated full-deck composition review. No Session, saves, or game actions.
const Carrier = preload("res://src/presentation/production/painted/card_carrier/card.gd")
const Stock = preload("res://assets/ui/cards/continuous-stock.png")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Atmosphere = preload("res://src/presentation/production/painted/peripheral_atmosphere.gd")
const Fan = preload("res://src/presentation/production/worldplay/hand_fan.gd")
const OUT := "res://docs/art/visual-generation/card-illustration-study/full-deck-drafts/"
const REF := "res://docs/art/visual-generation/procedural-study/native-evidence/tide/"
const SECTIONS := {"powers":"权能", "activities":"活动", "relics":"圣物", "previews":"预告", "events":"事件", "anchors":"锚点", "relic_actions":"圣物处置", "cult_orders":"教团经营", "support":"支持图面"}
var entries: Array = []
var cache: Dictionary = {}
var stage: Control
var page: Control
var screens: Array[Dictionary] = []
var screen_index := 0

func _initialize() -> void:
	call_deferred("run")

func image_at(path: String) -> Texture2D:
	if not cache.has(path):
		var source := Image.load_from_file(path)
		assert(source != null and not source.is_empty(), "Missing review image: " + path)
		cache[path] = ImageTexture.create_from_image(source)
	return cache[path]

func text(parent: Node, value: String, box: Rect2, px: int, title := false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = box.position
	label.size = box.size
	label.add_theme_font_override("font", Paint.fonts().heading if title else Paint.fonts().body)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Paint.BONE)
	parent.add_child(label)
	return label

func face(parent: Node, entry: Dictionary, box: Rect2, note := "构形色稿 · 待审") -> Control:
	var card := Carrier.new()
	card.position = box.position
	card.configure({"category_id":entry.category,"title":entry.title,"line1":note},
		Stock,image_at(OUT + str(entry.art_path)),box.size,
		{"title_font_size":20 if box.size.x < 250 else 24,"body_font_size":14})
	parent.add_child(card)
	return card

func reset_page() -> void:
	if is_instance_valid(page):
		stage.remove_child(page)
		page.queue_free()
	page = Control.new()
	page.size = Vector2(1600,1000)
	stage.add_child(page)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest.json"))
	entries = manifest.cards
	assert(entries.size() == 72)
	root.size = Vector2i(1600,1000)
	root.content_scale_size = Vector2i(1600,1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title = "邪神苏醒 · 全目录构形审阅（独立样稿）"
	stage = Control.new()
	stage.size = Vector2(1600,1000)
	stage.theme = Paint.native_theme()
	root.add_child(stage)
	var backdrop := TextureRect.new()
	backdrop.texture = Paint.MaterialSource.pigment("sky")
	backdrop.size = stage.size
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage.add_child(backdrop)
	var atmosphere := Atmosphere.new()
	atmosphere.scale = Vector2(1.25,1000.0/720.0)
	stage.add_child(atmosphere)
	atmosphere.paused = true
	atmosphere.set_sample_time(6.0)
	for section: String in SECTIONS:
		var filtered: Array = entries.filter(func(c: Dictionary)->bool: return c.section == section)
		for start in range(0,filtered.size(),12):
			screens.append({"key":section+"-"+str(start/12),"title":SECTIONS[section],"cards":filtered.slice(start,start+12),"total":filtered.size()})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"cards"))
	if "--capture" in OS.get_cmdline_user_args():
		await export_cards()
		for i in screens.size():
			show_sheet(i)
			await capture(str(screens[i].key)+".png")
		show_context()
		await capture("context.png")
		show_hand()
		await capture("hand.png")
		print("FULL_DECK_NATIVE_PROOF: 72 surfaces / 71 images / ",screens.size()," sheets")
		if "--exit" in OS.get_cmdline_user_args():
			quit()
			return
	show_sheet(0)

func show_sheet(index: int) -> void:
	screen_index = posmod(index,screens.size())
	reset_page()
	var spec: Dictionary = screens[screen_index]
	text(page,"逐卡构形 / "+str(spec.title),Rect2(50,25,1100,45),30,true)
	text(page,"64 个真实条目 + 8 个支持图面 · 手工路径绘制 · 构形待确认，未替换正式游戏",Rect2(52,72,1450,30),18)
	var list: Array = spec.cards
	for i in list.size():
		var card: Dictionary = list[i]
		var origin := Vector2(62+(i%6)*250,135+(i/6)*385)
		face(page,card,Rect2(origin,Vector2(220,330)))
		text(page,str(card.title),Rect2(origin+Vector2(0,341),Vector2(228,30)),16)
	text(page,"← / → 翻阅分类    %02d / %02d    构形审阅用目录，不代表本局已解锁" % [screen_index+1,screens.size()],Rect2(54,940,1470,32),18)

func show_context() -> void:
	reset_page()
	text(page,"同一张牌桌 / 原生成立绘与逐卡构形",Rect2(50,24,1460,44),28,true)
	text(page,"上排前三张为既有原生成图；其余为本轮构形色稿。卡壳、肩签、厚度、融接均用正式组件。",Rect2(52,72,1470,30),18)
	var refs := [["世界","world","world.png"],["教团","cult","cult.png"],["人物","person","person-0-1000.png"]]
	for i in refs.size():
		var card := Carrier.new()
		card.position = Vector2(62+i*250,135)
		card.configure({"category_id":refs[i][1],"title":refs[i][0]+" / 原生成图","line1":"原型 0 · 画风 0 · 色板 0"},Stock,image_at(REF+str(refs[i][2])),Vector2(220,330),{"title_font_size":20})
		page.add_child(card)
	var keys := ["power_listen","route_private_devotion","anchor_bind","relic_echo_bell","route_record_practice","route_ritual_transmission","event_03","event_06","resist_seize"]
	for i in keys.size():
		var entry: Dictionary = entries.filter(func(c: Dictionary)->bool: return c.illustration_key==keys[i])[0]
		var place := i+3
		face(page,entry,Rect2(Vector2(62+(place%6)*250,135+(place/6)*385),Vector2(220,330)))
	text(page,"原图参数：tide / seed 1339；人物 seed 1000。新稿尚未进入正式生成器画法与 Session。",Rect2(52,940,1460,30),18)

func show_hand() -> void:
	reset_page()
	text(page,"完整卡与手牌 / 识别尺度核对",Rect2(50,24,1460,44),28,true)
	text(page,"使用正式单向压叠组件；64 张内容卡全部在桌。此极密状态核对牌缘与肩签，完整图在查看区辨识。",Rect2(52,70,1480,30),17)
	var keys := ["route_record_practice","route_ritual_transmission","route_memory_circle","route_memory_practice","anchor_bind","anchor_maintain"]
	for i in keys.size():
		var entry: Dictionary = entries.filter(func(c: Dictionary)->bool: return c.illustration_key==keys[i])[0]
		face(page,entry,Rect2(Vector2(62+i*250,135),Vector2(220,330)))
	var hand := Fan.new()
	hand.position = Vector2(50,563)
	hand.size = Vector2(1500,300)
	hand.allow_play = false
	page.add_child(hand)
	var faces: Array[Control] = []
	for entry: Dictionary in entries:
		if entry.section == "support": continue
		faces.append(face(hand,entry,Rect2(Vector2.ZERO,Fan.HAND_SIZE),"构形稿"))
	hand.configure(faces)
	hand.set_focus(8,false)
	text(page,"本页只校对载体与辨识，不执行行动、不读写存档。",Rect2(52,915,1450,32),18)

func export_cards() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(336,496)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Control.new()
	holder.theme = Paint.native_theme()
	viewport.add_child(holder)
	for entry: Dictionary in entries:
		var card := face(holder,entry,Rect2(8,8,320,480))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var filename := str(entry.id).replace("/","__")+".png"
		var error := viewport.get_texture().get_image().save_png(OUT+"cards/"+filename)
		assert(error == OK)
		holder.remove_child(card)
		card.queue_free()
	root.remove_child(viewport)
	viewport.queue_free()

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT+filename)
	assert(error == OK)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT,KEY_PAGEDOWN]: show_sheet(screen_index+1)
		elif event.keycode in [KEY_LEFT,KEY_PAGEUP]: show_sheet(screen_index-1)
		elif event.keycode == KEY_H: show_hand()
		elif event.keycode == KEY_C: show_context()
