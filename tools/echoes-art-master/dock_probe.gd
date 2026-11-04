extends SceneTree
## Native-input checks for this isolated art fixture; not Session or aesthetic acceptance.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT = "res://tools/echoes-art-master/evidence/"
var app: Control
var checks: Array[String] = []
func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()
func require(ok: bool, description: String) -> bool:
	if not ok:
		push_error("DOCK_PROBE: "+description)
		quit(1)
		return false
	checks.append(description)
	return true
func frame() -> void:
	await process_frame
	await process_frame
func move_to(at: Vector2, held: bool = false, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position=at; event.global_position=at; event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await frame()
func mouse(at: Vector2, button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=at; event.global_position=at; event.button_index=button; event.pressed=down
	Input.parse_input_event(event)
	await frame()
func click(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	await move_to(at)
	await mouse(at,MOUSE_BUTTON_LEFT,true)
	await mouse(at,MOUSE_BUTTON_LEFT,false)
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=down
		Input.parse_input_event(event)
		await frame()
func snap(name_value: String) -> void:
	await frame()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"dock-check-"+name_value+".png")
func wheel(scroll: ScrollContainer) -> bool:
	var rect := scroll.get_global_rect()
	var at := rect.position + Vector2(35,24)
	await move_to(at)
	await mouse(at,MOUSE_BUTTON_WHEEL_DOWN,true)
	await mouse(at,MOUSE_BUTTON_WHEEL_DOWN,false)
	return scroll.scroll_horizontal > 0
func drag_to_end(scroll: ScrollContainer) -> bool:
	scroll.scroll_horizontal=0
	await frame()
	var bar: HScrollBar = scroll.get_h_scroll_bar()
	var rect := bar.get_global_rect()
	var range_width := bar.max_value-bar.min_value
	if range_width <= 0 or rect.size.x <= 0: return false
	var thumb_width: float = rect.size.x * bar.page / range_width
	var start := Vector2(rect.position.x+maxf(5,thumb_width*0.5),rect.get_center().y)
	var finish := Vector2(rect.end.x-5,rect.get_center().y)
	await move_to(start)
	await mouse(start,MOUSE_BUTTON_LEFT,true)
	await move_to(finish,true,finish-start)
	await mouse(finish,MOUSE_BUTTON_LEFT,false)
	return scroll.scroll_horizontal >= int(bar.max_value-bar.page)-3
func _run() -> void:
	app=Scene.instantiate(); root.add_child(app)
	await frame()
	if not require(app.root_ready,"场景初始化"): return
	var dock: Control=app.get_node("Interface/Dock")
	var history: Control=app.get_node("Interface/Chronicle")
	var powers: ScrollContainer=dock.get_node("PowerScroll")
	var relics: ScrollContainer=dock.get_node("RelicScroll")
	var action: Button=dock.get_node("EndTurn")
	if not require(dock.position.x==0 and history.position.x==0 and dock.get_global_rect().encloses(history.get_global_rect()),"底面及近况贯通左侧并共用承载"): return
	if not require(not dock.has_node("Overview") and not dock.has_node("NextPowers") and not dock.has_node("DockMidEdge"),"无多余总览、分页和中间分界线"): return
	if not require(not action.get_global_rect().intersects(history.get_global_rect()) and not action.get_global_rect().intersects(powers.get_global_rect()) and not action.get_global_rect().intersects(relics.get_global_rect()),"右侧按钮与近况及滚动区不重叠"): return
	if not require(powers.get_node("Items").get_child_count()==12 and relics.get_node("Items").get_child_count()==18,"展示列表包含十二权能和十八件展示圣物"): return
	for item: Control in relics.get_node("Items").get_children():
		var item_rect := item.get_global_rect()
		if not require(item_rect.encloses(item.get_node("Icon").get_global_rect()) and item_rect.encloses(item.get_node("RelicName").get_global_rect()) and item_rect.encloses(item.get_node("RelicState").get_global_rect()) and not item.get_node("RelicName").get_global_rect().intersects(item.get_node("RelicState").get_global_rect()),"%s 图标、名称与状态位于项内且文字不重叠"%item.name): return
	if not require(await wheel(powers),"真实滚轮可水平移动权能"): return
	if not require(await drag_to_end(powers),"拖动权能滚动条可到末尾"): return
	var locked: Button=powers.get_node("Items/Power_POWER_MANIFEST")
	if not require(locked.get_node("LockReason").text=="需苏醒90", "未解锁权能可见真实门槛"): return
	if not require(powers.get_global_rect().encloses(locked.get_global_rect()) and locked.get_global_rect().encloses(locked.get_node("LockReason").get_global_rect()) and not locked.get_node("PowerName").get_global_rect().intersects(locked.get_node("LockReason").get_global_rect()), "末项及锁定说明完整显示且不与名称重叠"): return
	powers.scroll_horizontal=0
	powers.get_node("Items/Power_POWER_LISTEN").grab_focus()
	await frame()
	for i: int in range(11): await key(KEY_TAB)
	if not require(root.gui_get_focus_owner()==locked and powers.scroll_horizontal>0,"键盘可逐项到达末项且权能滚动跟随焦点"): return
	await click(locked)
	if not require(app.modal_kind=="power" and "90" in app.get_node("PreviewLayer/Dialog/Availability").text,"未解锁权能仍能打开门槛说明"): return
	await key(KEY_ESCAPE)
	if not require(await wheel(relics),"真实滚轮可水平移动圣物"): return
	if not require(await drag_to_end(relics),"拖动圣物滚动条可到末尾"): return
	if not require(relics.get_node("Items/Relic_17/RelicName").text != "" and relics.get_global_rect().encloses(relics.get_node("Items/Relic_17").get_global_rect()),"超屏末件展示圣物可完整访问"): return
	relics.scroll_horizontal=0
	relics.get_node("Items/Relic_0").grab_focus()
	await frame()
	for i: int in range(17): await key(KEY_TAB)
	if not require(root.gui_get_focus_owner()==relics.get_node("Items/Relic_17") and relics.scroll_horizontal>0,"键盘可逐项到达末件圣物且滚动跟随焦点"): return
	relics.scroll_horizontal=0; powers.scroll_horizontal=0
	await frame()
	for pair: Array in [[powers.get_node("Items/Power_POWER_LISTEN"),"power"],[relics.get_node("Items/Relic_0"),"relic"]]:
		var button: Button=pair[0]
		var icon: TextureRect=button.get_node("Icon")
		await move_to(button.get_global_rect().get_center())
		if not require(root.gui_get_hovered_control()==button and icon.scale.x>1.0 and button.get_theme_stylebox("hover") is StyleBoxEmpty, str(pair[1])+" 悬停改变图标且不画背景"): return
		var material: ShaderMaterial=icon.material
		var brightness: float = material.get_shader_parameter("icon_tint").r if pair[1] == "power" else material.get_shader_parameter("highlight")
		if not require(brightness>1.0,str(pair[1])+" 悬停提高图标亮度"): return
		await snap(str(pair[1])+"-hover")
		await move_to(Vector2(830,300))
		if not require(icon.scale==Vector2.ONE,str(pair[1])+" 移出后恢复图标尺寸"): return
	await click(history.get_node("History"))
	if not require(app.modal_kind=="chronicle","近况入口打开编年史展示"): return
	await key(KEY_ESCAPE)
	await click(action)
	if not require(app.modal_kind=="info" and "不支付" in app.get_node("PreviewLayer/Dialog/Content").text,"下一回合打开夹具说明，不推进"): return
	await key(KEY_ESCAPE)
	app.fixture_state.relics=0
	app.fixture_state.awakening=0
	app._build_top()
	app._build_dock()
	await frame()
	if not require(dock.has_node("RelicEmpty") and not dock.has_node("RelicScroll") and "尚无" in dock.get_node("RelicEmpty").text,"零圣物显示空态且不伪造收藏"): return
	if not require("3 / 12" in dock.get_node("PowerCount").text,"零苏醒时按 CSV 门槛更新解锁数量"): return
	if not require(app.get_node("Interface/TopBar/awakeningValue").text=="0" and "0" in app.get_node("Interface/TopBar/RelicsIndex").text,"空态时顶部苏醒与圣物数量和展示夹具一致"): return
	await snap("empty")
	app.open_power("POWER_MANIFEST")
	if not require("当前0" in app.get_node("PreviewLayer/Dialog/Availability").text,"未解锁预览引用当前展示苏醒值"): return
	app.close_modal()
	app.open_relics()
	if not require(app.get_node("PreviewLayer/Dialog/InventoryScroll").get_child(0).get_child_count()==1,"空圣物预览不构造虚假实例"): return
	await snap("empty-preview")
	print("DOCK_PROBE_OK ",checks.size()," checks")
	quit(0)
