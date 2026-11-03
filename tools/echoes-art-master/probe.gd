extends SceneTree
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT: String = "res://tools/echoes-art-master/evidence/"
var app
var checks: Array[String]=[]
var captures: Array[String]=[]
func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()
func require(value:bool,label_value:String) -> bool:
	if not value:
		push_error("ART_MASTER_PROBE: "+label_value)
		quit(1)
		return false
	checks.append(label_value)
	return true
func snap(label_value:String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result:Error=root.get_texture().get_image().save_png(OUT+label_value+".png")
	if result != OK: push_error("Screenshot failed: "+label_value)
	captures.append(label_value)
func click(control:Control,down_only:bool=false) -> void:
	var pos:Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=pos;motion.global_position=pos
	Input.parse_input_event(motion)
	await process_frame
	var down:=InputEventMouseButton.new()
	down.position=pos;down.global_position=pos;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	Input.parse_input_event(down)
	await process_frame
	if down_only:return
	var up:=InputEventMouseButton.new()
	up.position=pos;up.global_position=pos;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
	Input.parse_input_event(up)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func key(code:Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func walk(node:Node) -> Array:
	var nodes:Array=[node]
	for child:Node in node.get_children():nodes.append_array(walk(child))
	return nodes
func _run() -> void:
	app=Scene.instantiate();root.add_child(app)
	await process_frame;await process_frame
	if not require(app.root_ready,"正式CSV只读装载，独立场景初始化"):return
	var before:String=JSON.stringify(app.fixture_state)
	await snap("01-native-overview")
	var buttons:Array=walk(app).filter(func(node:Node)->bool:return node is Button)
	if not require(buttons.size()>=35,"实际Button控件数量足够，非图片热区"):return
	if not require(app.get_node("Interface/Dock").size.y==84,"底栏高度84px"):return
	var power_nodes:Array=app.get_node("Interface/Dock").get_children().filter(func(node:Node)->bool:return str(node.name).begins_with("Power_POWER_"))
	if not require(power_nodes.size()==12,"十二权能同时常驻"):return
	if not require(power_nodes.all(func(node:Node)->bool:return node.get_node("PowerIcon").texture is AtlasTexture),"十二权能使用新RGBA图集独立裁片"):return
	if not require(app.get_node("Interface/Prayers/PrayerCard_0/Shallow_0").size.y==48,"祈求分支为48px原生图文按钮"):return
	if not require(app.get_node("Interface/Chronicle/EndTurn").size.y==44,"结束回合热区保持44px"):return
	if not require(app.has_node("Interface/TopBar/Income") and app.has_node("Interface/TopBar/Deity"),"顶部保留收支与本体入口"):return
	await click(app.get_node("Interface/CultIndex/Cult_1"))
	if not require(app.selected_cult==1,"鼠标点击真实教团按钮改变选中态"):return
	if not require(app.get_node("Interface/WorldContext/MetricValue_0").text=="50" and app.get_node("Interface/WorldContext/MetricValue_3").text=="75–100" and "祭司塞拉" in app.get_node("Interface/WorldContext/ResistanceBand/Resistance").text,"盐梦02使用自身四维与具名反制夹具"):return
	await snap("02-cult-selected")
	await click(app.get_node("Interface/CultIndex/Cult_0"))
	if not require(app.get_node("Interface/WorldContext/MetricValue_0").text=="未掌握" and app.get_node("Interface/WorldContext/ResistanceBand/Resistance").text=="暂无已知反制","未建夹具的世界不借用其他世界数据"):return
	await click(app.get_node("Interface/CultIndex/Cult_1"))
	var shallow:Button=app.get_node("Interface/Prayers/PrayerCard_1/Shallow_1")
	var pos:Vector2=shallow.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos;Input.parse_input_event(motion)
	await snap("03-button-hover")
	await click(shallow,true)
	await snap("04-button-pressed")
	var up:=InputEventMouseButton.new();up.position=pos;up.global_position=pos;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up)
	await process_frame;await process_frame
	if not require(app.modal_kind=="prayer" and app.current_variant=="shallow","真实浅触按钮打开效果预览"):return
	await snap("05-prayer-preview")
	await click(app.get_node("PreviewLayer/Dialog/ChooseDeep"))
	if not require(app.current_variant=="deep","预览内切换深应"):return
	await key(KEY_ESCAPE)
	if not require(not app.get_node("PreviewLayer").visible,"Escape关闭临时预览"):return
	if not require(root.gui_get_focus_owner()==shallow,"浅深切换后关闭仍恢复原祈求按钮焦点"):return
	await click(app.get_node("Interface/Dock/Power_POWER_MANIFEST"))
	if not require("尚未解锁" in app.get_node("PreviewLayer/Dialog/Availability").text,"苏醒65的降临可查锁定原因"):return
	await snap("06-locked-power")
	await key(KEY_ESCAPE)
	await click(app.get_node("Interface/Dock/AllRelics"))
	if not require(app.modal_kind=="relics" and app.get_node("PreviewLayer/Dialog/InventoryScroll").get_child(0).get_child_count()==18,"全部圣物真实滚动面板含18人工实例"):return
	await snap("07-relic-panel")
	await key(KEY_ESCAPE)
	await key(KEY_F1)
	if not require(app.get_node("FeedbackLayer/LayerInspector").visible,"F1打开真实图层检查面板"):return
	await click(app.get_node("FeedbackLayer/LayerInspector/LayerToggle_4"))
	if not require(not app.get_node("Interface").visible,"真实CheckButton独立关闭全部UI层"):return
	await snap("08-world-layers")
	await click(app.get_node("FeedbackLayer/LayerInspector/LayerToggle_1"))
	if not require(not app.get_node("World/Sanctuary").visible,"教团场所独立关闭，海面保留"):return
	await click(app.get_node("FeedbackLayer/LayerInspector/LayerToggle_2"))
	await snap("09-separated-background")
	if not require(not app.get_node("World/Atmosphere/DistantFog").visible and app.get_node("World/Atmosphere/ForegroundFog").visible,"远雾与前雾独立开关（远=%s / 前=%s）"%[app.get_node("World/Atmosphere/DistantFog").visible,app.get_node("World/Atmosphere/ForegroundFog").visible]):return
	if not require(before==JSON.stringify(app.fixture_state),"所有点击不支付不推进不改夹具状态"):return
	var result:Dictionary={"scope":"Native art composition and UI paths only; not gameplay or human aesthetic acceptance", "checks":checks,"captures":captures,"node_counts":{"button":buttons.size(),"label":walk(app).filter(func(node:Node)->bool:return node is Label).size(),"texture":walk(app).filter(func(node:Node)->bool:return node is TextureRect).size()},"interaction_log":app.interaction_log,"fonts":app.font_report()}
	var file:=FileAccess.open(OUT+"probe-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ART_MASTER_PROBE_OK ",checks.size()," checks; ",captures.size()," native captures")
	app.queue_free();await process_frame;quit(0)
