extends SceneTree
## Native T46 fixture checks. Does not execute Session actions or judge aesthetics.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT = "res://tools/echoes-art-master/evidence/"
var app: Control
var checks: Array[String] = []
func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()
func require(ok: bool, description: String) -> bool:
	if not ok:
		push_error("WORLD_PRAYER_PROBE: "+description)
		quit(1)
		return false
	checks.append(description)
	return true
func frame() -> void:
	await process_frame
	await process_frame
func click(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=at; motion.global_position=at
	Input.parse_input_event(motion); await frame()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.position=at; event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		Input.parse_input_event(event); await frame()
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=down
		Input.parse_input_event(event); await frame()
func type_digit(code: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.unicode=int(code); event.pressed=down
		Input.parse_input_event(event); await frame()
func snap(name_value: String) -> void:
	await frame(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"world-prayer-"+name_value+".png")
func _run() -> void:
	app=Scene.instantiate(); root.add_child(app); await frame()
	if not require(app.root_ready,"独立场景初始化"): return
	var before:=JSON.stringify(app.fixture_state)
	var index: Control=app.get_node("Interface/WorldIndex")
	var list: VBoxContainer=index.get_node("WorldScroll/WorldList")
	var cards: Control=app.get_node("Interface/Prayers")
	var stage: Control=app.get_node("Interface/PrimaryStage")
	var context: Control=app.get_node("Interface/WorldContext")
	if not require(index.get_node("Heading").text=="世界" and list.get_child_count()==3,"左侧为三个已联系世界展示项"): return
	if not require(not stage.visible and context.visible and app.current_mode=="world", "默认世界主区与右侧祈求摘要并存"): return
	await click(index.get_node("SearchWorlds"))
	await type_digit(KEY_0); await type_digit(KEY_6)
	if not require(list.get_node("World_06").visible and not list.get_node("World_02").visible and not list.get_node("World_04").visible,"输入搜索可筛选已联系世界"): return
	await key(KEY_BACKSPACE); await key(KEY_BACKSPACE)
	if not require(list.get_node("World_02").visible and list.get_node("World_04").visible,"清除搜索恢复世界清单"): return
	for i:int in range(3):
		var card:Control=cards.get_node("PrayerCard_%d"%i)
		if not require(card is Button and card.get_node("SceneImage").texture!=null and not card.get_node("Kind").text.is_empty(),"祈求 %d 含概念图与身份类型"%i): return
	await snap("world")
	await click(cards.get_node("PrayerCard_1"))
	if not require(app.current_mode=="prayer" and app.current_prayer==1 and stage.visible and not context.visible and not app.get_node("PreviewLayer").visible,"点击右侧祭日祈求以中央主区打开，世界内容互斥"): return
	if not require(stage.get_node("PrayerScene").texture!=null and "塞拉" in stage.get_node("Subject").text and "祭日" in stage.get_node("Title").text,"主区显示对应概念场景、身份和诉求"): return
	if not require("第48轮" in stage.get_node("Deadline").text and not stage.get_node("Request").text.is_empty(),"请求期限和原诉求可见"): return
	if not require("1低语" in stage.get_node("Payment").text and "0信仰" in stage.get_node("Payment").text,"浅触费用来自正式 CSV"): return
	if not require(stage.get_node("EffectScroll/Effects").get_child_count()>=4 and "未接入" in stage.get_node("FixtureScope").text,"必付和多档后果可滚动，明确未接结算"): return
	await snap("prayer-shallow")
	var effect_scroll:ScrollContainer=stage.get_node("EffectScroll")
	var scroll_at:=effect_scroll.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=scroll_at; motion.global_position=scroll_at
	Input.parse_input_event(motion); await frame()
	for i in range(4):
		for down:bool in [true,false]:
			var wheel:=InputEventMouseButton.new(); wheel.position=scroll_at; wheel.global_position=scroll_at
			wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=down
			Input.parse_input_event(wheel); await frame()
	if not require(effect_scroll.scroll_vertical>0,"长祈求后果可通过鼠标滚轮访问"): return
	await click(stage.get_node("ChooseDeep"))
	if not require(app.current_variant=="deep" and "2低语" in stage.get_node("Payment").text and "4信仰" in stage.get_node("Payment").text,"深应切换并更新费用"): return
	if not require(root.gui_get_focus_owner()==stage.get_node("ChooseDeep"),"切换回应方式后焦点留在相应选择"): return
	await snap("prayer-deep")
	await click(stage.get_node("ClosePrayer"))
	if not require(app.current_mode=="world" and context.visible and not stage.visible and app.current_prayer==-1,"不回应即可收起并恢复世界主区"): return
	if not require(root.gui_get_focus_owner()==cards.get_node("PrayerCard_1"),"收起后焦点回到对应摘要"): return
	await click(cards.get_node("PrayerCard_2"))
	if not require(app.current_mode=="prayer" and app.current_prayer==2 and "伊文" in stage.get_node("Subject").text,"可直接选择另一条祈求"): return
	await snap("prayer-ivan")
	await click(list.get_node("World_06"))
	if not require(app.current_mode=="world" and app.selected_world==5 and not stage.visible and context.visible,"查看其他世界会替换祈求主区"): return
	if not require("未掌握" in context.get_node("MetricValue_0").text and app.get_node("World/Sanctuary").modulate.a==0.0,"未配置世界不借用镜证观察与场所"): return
	await snap("unknown-world")
	await click(list.get_node("World_02"))
	if not require(app.selected_world==1 and context.get_node("MetricValue_0").text=="50", "盐梦世界呈现自身展示观察"): return
	await click(list.get_node("World_04"))
	await click(context.get_node("ManageCult"))
	if not require(app.current_mode=="cult" and stage.visible and not context.visible and "镜证" in stage.get_node("Heading").text,"教团管理在中央主区展开"): return
	if not require("64" in stage.get_node("CultSummary").text and "70" in stage.get_node("CultSummary").text and "不执行" in stage.get_node("FixtureScope").text,"教团已知状态与展示边界清晰"): return
	await snap("cult")
	await click(stage.get_node("ReturnWorld"))
	if not require(app.current_mode=="world" and context.visible,"教团管理可返回世界"): return
	await click(cards.get_node("PrayerCard_0"))
	await key(KEY_ESCAPE)
	if not require(app.current_mode=="world" and context.visible,"Escape 可不回应收起祈求"): return
	await click(cards.get_node("PrayerCard_1"))
	await click(app.get_node("Interface/Dock/PowerScroll/Items/Power_POWER_LISTEN"))
	if not require(app.current_mode=="world" and app.modal_kind=="power" and not stage.visible,"祈求中选择权能会离开祈求主区并展示该功能"): return
	await key(KEY_ESCAPE)
	if not require(app.current_mode=="world" and context.visible and not app.get_node("PreviewLayer").visible,"关闭其他功能后不自动重开祈求"): return
	if not require(before==JSON.stringify(app.fixture_state),"查看、切换和收起不支付、不推进且不改变夹具"): return
	print("WORLD_PRAYER_PROBE_OK ",checks.size()," checks")
	quit(0)
