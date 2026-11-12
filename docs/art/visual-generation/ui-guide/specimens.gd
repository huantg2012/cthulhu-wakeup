extends SceneTree
## Documentation specimens only. Reuses the accepted painters without altering them.
const Paint = preload("res://docs/art/visual-generation/ui-study/painted_material.gd")
const Card = preload("res://docs/art/visual-generation/ui-study/painted_card.gd")
const Locked = preload("res://src/presentation/production/locked_controls.gd")
const OUT = "res://docs/art/visual-generation/ui-guide/images/"
const DIM = Color("#7f928a")
const RULE = Color("#293b35")
const WARM = Color("#c7b08a")
const ERROR = Color("#c49e91")
var page: Control
var sample_viewports: Array[SubViewport] = []
var sample_buttons: Array[Dictionary] = []

class Surface extends Control:
	var plate: StyleBox
	var focus_plate: StyleBox
	func _draw() -> void:
		if plate != null: draw_style_box(plate, Rect2(Vector2.ZERO, size))
		if focus_plate != null: draw_style_box(focus_plate, Rect2(Vector2.ZERO, size))

class ChoiceMark extends Control:
	var selected := false
	var multiple := false
	func _draw() -> void:
		var c := Color("#b1c09b") if selected else Color("#758879")
		if multiple:
			draw_polyline(PackedVector2Array([Vector2(2,3),Vector2(18,2),Vector2(19,18),Vector2(3,19),Vector2(2,3)]),c,1.2,true)
			if selected: draw_polyline(PackedVector2Array([Vector2(6,10),Vector2(10,15),Vector2(17,6)]),c,2,true)
		else:
			draw_arc(Vector2(11,11),8.0,0,TAU,22,c,1.2,true)
			if selected: draw_circle(Vector2(11,11),3.3,c)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title = "邪神苏醒 · 规范实物捕获"
	root.move_to_center()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var entries := ["controls-approved", "controls-extension", "type-approved", "cards-approved", "fields-extension", "fields-feedback"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			var requested := argument.trim_prefix("--only=")
			if not requested in entries:
				push_error("Unknown specimen: "+requested)
				quit(1)
				return
			entries = [requested]
	for entry in entries:
		if is_instance_valid(page):
			page.queue_free()
			await process_frame
		sample_viewports.clear()
		sample_buttons.clear()
		page = Control.new()
		page.size = Vector2(1280,720)
		root.add_child(page)
		_fill(Rect2(0,0,1280,720),Color("#0b1215"))
		match entry:
			"controls-approved": _controls()
			"controls-extension": _controls(true)
			"type-approved": _type()
			"cards-approved": _cards()
			"fields-extension": _fields()
			"fields-feedback": _feedback()
		await process_frame
		await _activate_samples()
		await process_frame
		RenderingServer.force_draw(false)
		var shot := root.get_texture().get_image()
		var result := shot.save_png(ProjectSettings.globalize_path(OUT.path_join(entry+".png")))
		if result != OK:
			push_error("Capture failed: "+entry)
			quit(1)
			return
		print("SPECIMEN ",entry," ",shot.get_size())
	quit()

func _fill(r: Rect2, color: Color) -> ColorRect:
	var n := ColorRect.new()
	n.position = r.position
	n.size = r.size
	n.color = color
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(n)
	return n

func _text(value: String, r: Rect2, px := 14, color := Paint.BONE, heading := false) -> Label:
	var n := Label.new()
	n.text = value
	n.position = r.position
	n.size = r.size
	n.add_theme_font_override("font",Paint.font(heading))
	n.add_theme_font_size_override("font_size",px)
	n.add_theme_color_override("font_color",color)
	n.add_theme_constant_override("outline_size",0)
	n.add_theme_constant_override("line_spacing",3)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if heading else CanvasItem.TEXTURE_FILTER_LINEAR
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(n)
	return n

func _header(code: String, title: String, description: String, extension := false) -> void:
	_text(code+"  /  界面美术规范 · 原生实物",Rect2(44,24,820,24),13,DIM)
	_text(title,Rect2(44,62,1192,44),28,Paint.BONE)
	_text(description,Rect2(44,116,1192,24),14,Paint.MUTED)
	_text("衍生设计 · 待审" if extension else "来源：当前母版代码",Rect2(982,24,254,24),14,WARM if extension else Paint.MUTED)
	_fill(Rect2(44,153,1192,1),RULE)

func _footer(value: String) -> void:
	_fill(Rect2(44,657,1192,1),RULE)
	_text(value,Rect2(44,676,1192,24),13,DIM)

func _button_sample(parent: Node, role: String, state: String, position: Vector2, caption: String, extent := Vector2(178,40), unified := false) -> void:
	var container := SubViewportContainer.new()
	container.position = position
	container.size = extent
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(extent)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	container.add_child(viewport)
	sample_viewports.append(viewport)
	var host := Control.new()
	host.size = extent
	viewport.add_child(host)
	var ui := Locked.new(null,func(): return true)
	var name_value := "PhaseAction" if role == "primary" else ("AllWorlds" if role == "obligation" else "PlainNavigation")
	var b: Button = ui.button(host,name_value,caption,Rect2(Vector2.ZERO,extent),func(): pass,role == "primary")
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	Paint.style_buttons(host)
	sample_buttons.append({"button":b,"viewport":viewport,"host":host,"state":state,"extent":extent,"unified":unified})

func _activate_samples() -> void:
	for sample in sample_buttons:
		var b: Button = sample.button
		var viewport: SubViewport = sample.viewport
		if sample.state == "disabled":
			b.disabled = true
		elif sample.state == "focus":
			b.grab_focus()
		elif sample.state == "hover":
			b.notification(Control.NOTIFICATION_MOUSE_ENTER)
		elif sample.state == "pressed":
			b.toggle_mode = true
			b.set_pressed_no_signal(true)
			b.release_focus()
		# Focus_entered may have set a pre-skin focus box. Apply the actual accepted
		# stylesheet after state setup, exactly as its scene-level injection does.
		Paint.style_buttons(sample.host)
		if sample.unified:
			b.add_theme_color_override("font_color",Paint.BONE)
			b.add_theme_color_override("font_hover_color",Color("#eee8cc"))
			b.add_theme_color_override("font_focus_color",Paint.BONE)
			b.add_theme_color_override("font_pressed_color",Paint.BONE)
			b.add_theme_color_override("font_disabled_color",Paint.MUTED)
		await process_frame
		RenderingServer.force_draw(false)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		print("BUTTON ",b.name," ",sample.state," draw=",b.get_draw_mode()," focus=",b.has_focus())

func _controls(extension := false) -> void:
	if extension:
		_header("X03","按钮状态补齐 · 同源衍生设计 · 待审","同一原生按钮、同一母版底材；明确补齐文字角色，保留禁用原因的可读性。",true)
	else:
		_header("C01","按钮实物与状态复现","同一个原生 Button：正式构建器 → 母版 Paint.style_buttons；不是重新画的示意按钮。")
	var states := ["normal","hover","focus","pressed","disabled"]
	var names := ["常态","悬停","键盘焦点","按下","不可用"]
	for i in states.size():
		var x := 252+i*190
		_text(names[i],Rect2(x,180,178,24),16)
		_text("同源补齐 · 待审" if extension else ("母版常用状态" if i<2 else "代码复现 · 非逐态验收"),Rect2(x,208,178,22),12,DIM)
	var roles := ["plain","obligation","primary"]
	var role_names := ["普通导航","责任入口","主要操作"]
	var captions := ["人物档案","展开全部世界 →","回合责任 →"]
	var alpha := ["底材 0.16","底材 0.38","底材 0.88"]
	for row in roles.size():
		var y := 262+row*112
		_text(role_names[row],Rect2(44,y-3,180,28),20)
		_text(alpha[row],Rect2(44,y+32,180,23),13,DIM)
		for column in states.size():
			_button_sample(page,roles[row],states[column],Vector2(252+column*190,y),captions[row],Vector2(178,40),extension)
	if extension:
		_text("禁用原因示例：尚未满足条件。保留正式原因与补齐路径，不降低整段文字透明度。",Rect2(44,594,1192,24),14,Paint.MUTED)
		_text("常态／焦点／按下 #d9d7be　悬停 #eee8cc　禁用 #b4bdaa（不透明）；底材强度沿母版。",Rect2(44,625,1192,24),14,Paint.MUTED)
		_footer("X03 / 同源衍生设计待制作人审阅 · 只补齐视觉状态；不改变命中范围、焦点行为、资格或业务规则")
	else:
		_text("焦点 = 常态底材 + focus 叠层；不可用仍须保留可读的原因。",Rect2(44,594,1192,24),14,Paint.MUTED)
		_text("按下／焦点／禁用字色有生产继承残留，不作为新主题色依据；本图忠实保留以便接入时识别。",Rect2(44,625,1192,24),14,WARM)
		_footer("C01 / 材料：painted_material.gd · 构建器：locked_controls.gd · 逻辑 1280×720，展示 1920×1080")

func _type() -> void:
	_header("T01","字形、字号与阅读层级","这里的字由项目自带字体直接渲染；数字为逻辑字号，图片以 1.5 倍画幅输出。")
	var rows := [
		["场景标题", "36 px · Fusion Pixel", "诸界态势",36,true],
		["主要卡名", "24 px · Fusion Pixel", "塔穆什 · 潮汐世界",24,true],
		["资源数值", "20 px · WenKai Screen", "低语 6     信仰 63     苏醒 93",20,false],
		["正文与说明", "14 px · WenKai Screen", "机会尚未消失，责任仍在延续。\n屏障 0–24　污染 75–100　剩余 2 轮",14,false]
	]
	for i in rows.size():
		var y := 185+i*88
		_text(rows[i][0],Rect2(44,y,244,27),17)
		_text(rows[i][1],Rect2(44,y+31,244,22),12,DIM)
		_text(rows[i][2],Rect2(326,y-4,890,74),rows[i][3],Paint.BONE,rows[i][4])
	_text("窄按钮文字",Rect2(44,547,244,27),17)
	_text("12 px · WenKai Screen",Rect2(44,578,244,22),12,DIM)
	_button_sample(page,"obligation","normal",Vector2(326,550),"供奉与收支",Vector2(170,40))
	_text("标题保持点阵边；正文保留完整连续笔形。长段落不可降到窄按钮字号。",Rect2(548,550,675,52),14,Paint.MUTED)
	_text("ABC 0123456789  −12  0–24  75–100  （已知）",Rect2(326,610,890,26),14,Paint.BONE)
	_footer("T01 / 标题 nearest，无抗锯齿；正文 linear，灰度抗锯齿 · 无描边、无随机缺墨、无系统字体依赖")

func _image(texture: Texture2D, r: Rect2, filtering := CanvasItem.TEXTURE_FILTER_LINEAR) -> TextureRect:
	var item := TextureRect.new()
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.texture = texture
	item.position = r.position
	item.size = r.size
	item.texture_filter = filtering
	page.add_child(item)
	return item

func _cards() -> void:
	_header("K01","同一张世界卡：未聚焦 / 聚焦","直接实例化 PaintedCard；同一图、同一种子、同一底材，只改变既有焦点状态。")
	var recipe := {"kind":"世界", "title":"潮汐世界", "subtitle":"原生样本 · 非 Session", "metrics":"原型 0 · 画风 sid 0\n色板 0 · 种子 1339", "art":Paint.ART+"tide/world.png"}
	for i in 2:
		var x := 48+i*312
		_text("未聚焦" if i == 0 else "聚焦 / 悬停",Rect2(x,174,260,28),17)
		var card := Card.new()
		card.setup(recipe,0)
		card.position = Vector2(x,214)
		card.set_meta("fan_focused",i==1)
		page.add_child(card)
	_text("原图 · 960×960",Rect2(724,174,260,28),17)
	_image(Paint.image(recipe.art),Rect2(724,214,240,240))
	_text("颜料基底局部",Rect2(992,174,244,28),17)
	var paper := AtlasTexture.new()
	paper.atlas = Paint.pigment("card",31)
	paper.region = Rect2(14,278,232,106)
	_image(paper,Rect2(992,214,232,106),CanvasItem.TEXTURE_FILTER_NEAREST)
	_text("文字底板压低暗纹，\n不再叠一层独立框。",Rect2(992,334,244,54),14,Paint.MUTED)
	_image(Paint.Marks.seal(false),Rect2(1000,411,80,36),CanvasItem.TEXTURE_FILTER_NEAREST)
	_image(Paint.Marks.seal(true),Rect2(1120,411,80,36),CanvasItem.TEXTURE_FILTER_NEAREST)
	_text("卡头印记：收敛 → 显现",Rect2(992,458,244,24),13,Paint.MUTED)
	_text("焦点只加三处短亮边与印记。\n不旋转卡片，不连续发光描边。",Rect2(724,502,480,56),16,Paint.BONE)
	_text("tide / 溺亡之海 · 原型 0\n暗黑厚涂 sid 0 · 深渊翠色板 0\n世界种子 1339 · 原生样本",Rect2(724,568,480,76),14,Paint.MUTED)
	_footer("K01 / 图窗 240×240、linear 收边；卡片 260×390 · 元数据：native-evidence/tide/parameters.json")

func _field_box(r: Rect2, focused := false) -> Surface:
	var box := StyleBoxTexture.new()
	box.texture = Paint.pigment("button")
	box.texture_margin_left = 5
	box.texture_margin_top = 5
	box.texture_margin_right = 5
	box.texture_margin_bottom = 5
	box.modulate_color = Color(1,1,1,0.38 if focused else 0.16)
	var surface := Surface.new()
	surface.position = r.position
	surface.size = r.size
	surface.plate = box
	if focused:
		var edge := StyleBoxFlat.new()
		edge.bg_color = Color.TRANSPARENT
		edge.border_color = Color("#7b9078")
		edge.border_width_left = 2
		surface.focus_plate = edge
	page.add_child(surface)
	return surface

func _edit(r: Rect2, value: String, placeholder: String, focused := false, select_text := false) -> void:
	_field_box(r,focused)
	var input := LineEdit.new()
	input.position = r.position+Vector2(10,0)
	input.size = r.size-Vector2(20,0)
	input.text = value
	input.placeholder_text = placeholder
	input.add_theme_font_override("font",Paint.font())
	input.add_theme_font_size_override("font_size",14)
	input.add_theme_color_override("font_color",Paint.BONE)
	input.add_theme_color_override("font_placeholder_color",DIM)
	input.add_theme_color_override("caret_color",Paint.BONE)
	input.add_theme_color_override("selection_color",Color("#485d49"))
	input.add_theme_color_override("font_selected_color",Paint.BONE)
	input.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	input.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	input.caret_blink = false
	page.add_child(input)
	if focused: input.grab_focus()
	if select_text: input.select(0,2)

func _choice(r: Rect2, caption: String, selected: bool, multiple := false) -> void:
	_field_box(r,selected)
	var mark := ChoiceMark.new()
	mark.position = r.position+Vector2(14,9)
	mark.size = Vector2(22,22)
	mark.selected = selected
	mark.multiple = multiple
	page.add_child(mark)
	_text(caption,Rect2(r.position+Vector2(52,6),r.size-Vector2(64,6)),14,Paint.BONE if selected else Paint.MUTED)

func _fields() -> void:
	_header("X01","输入、选择与列表：同源衍生小样","用于补齐母版未覆盖的控件；只展示视觉，不接业务、不改变正式交互。",true)
	_text("输入框",Rect2(44,178,560,28),20)
	_text("常态 / 占位提示",Rect2(44,218,560,24),13,DIM)
	_edit(Rect2(44,249,560,42),"","查找已知世界")
	_text("输入焦点 / 选中文字",Rect2(44,314,560,24),13,DIM)
	_edit(Rect2(44,345,560,42),"塔穆什","",true,true)
	_text("多选 · 独立材料",Rect2(44,425,560,28),20)
	_choice(Rect2(44,468,560,42),"仪式记录",true,true)
	_choice(Rect2(44,522,560,42),"见证材料",false,true)
	_text("单选 · 当前对象",Rect2(660,178,576,28),20)
	_choice(Rect2(660,224,576,42),"潮汐世界",true)
	_choice(Rect2(660,278,576,42),"冷原世界",false)
	_text("列表选中 · 保留名称与状态",Rect2(660,366,576,28),20)
	_field_box(Rect2(660,414,576,58),true)
	_text("听潮密会",Rect2(680,420,345,26),17)
	_text("当前查看",Rect2(1060,425,150,24),13,Paint.MUTED)
	_text("组织与现实联系",Rect2(680,446,455,24),13,DIM)
	_field_box(Rect2(660,486,576,58))
	_text("测风誓约会",Rect2(680,492,345,26),17,Paint.MUTED)
	_text("可查阅",Rect2(1060,497,150,24),13,DIM)
	_text("世界归属与公开状态",Rect2(680,518,455,24),13,DIM)
	_text("选中靠稳定的窄印边和符号；输入保留插入点、选区与清楚的文字，不靠整行发光。",Rect2(44,608,1192,28),14,Paint.MUTED)
	_footer("X01 / 衍生设计待制作人审阅 · 字体与颜料直接复用母版，选择标记／输入状态为本次补充")

func _feedback() -> void:
	_header("X02","状态说明与反馈：同源衍生小样","警告、失败、锁定、空态分别有明确信息；装饰不能代替原因和下一步。",true)
	var specs := [
		["警告", "仍有祈求未回应", "本轮结束后，剩余期限会继续推进。",WARM],
		["错误", "保存失败", "原存档保持不变。请检查目标位置后重试。",ERROR],
		["锁定", "尚未满足条件", "保留正式门槛与缺失原因，不只降低透明度。",Paint.MUTED],
		["空态", "没有匹配的已知人物", "缩短检索词，或返回全部已知人物。",Paint.MUTED]
	]
	for i in specs.size():
		var x := 44+616*(i%2)
		var y := 188+216*int(i/2)
		_text(specs[i][0],Rect2(x,y,560,28),17,specs[i][3])
		_field_box(Rect2(x,y+41,576,132))
		_text(specs[i][1],Rect2(x+18,y+55,540,32),20,Paint.BONE)
		var description := _text(specs[i][2],Rect2(x+18,y+100,532,58),14,Paint.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text("这两种暖色仅为衍生提议；已知规则和实际原因必须由正式投影提供，图册文案不成为规则。",Rect2(44,625,1192,26),14,WARM)
	_footer("X02 / 衍生设计待制作人审阅 · 示例用于控件状态规范，不代表真实游戏中的资格、费用或存档结果")
