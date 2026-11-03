extends SceneTree
## This checks one isolated T46 art fixture. It does not validate Session,
## phase advancement, prayer supply/settlement, or human aesthetic acceptance.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT := "res://tools/echoes-art-master/evidence/"
const EXPECTED_POWERS: Array[String] = ["POWER_LISTEN","POWER_DREAM","POWER_ORACLE","POWER_BESTOW","POWER_APPOINT","POWER_SACRIFICE","POWER_BREACH","POWER_SEED","POWER_ANCHOR","POWER_VEIL","POWER_TRANSFER","POWER_MANIFEST"]
var app: Control
var checks: Array[String] = []
var captures: Array[String] = []
var measured: Dictionary = {}

func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()

func require(value: bool, description: String) -> bool:
	if not value:
		push_error("RESTORATION_PROBE: " + description)
		_write_result("FAIL", description)
		quit(1)
		return false
	checks.append(description)
	return true

func _write_result(status: String, failure: String = "") -> void:
	var nodes: Array = walk(app) if is_instance_valid(app) else []
	var report := {
		"status": status,
		"scope": "Native layered Godot art fixture T46 only. Not formal Session, event/action phase, prayer supply, payment/settlement, or human aesthetic acceptance.",
		"checks": checks, "failure": failure, "captures": captures, "measurements": measured,
		"node_counts": {
			"button": nodes.filter(func(node: Node) -> bool: return node is Button).size(),
			"label": nodes.filter(func(node: Node) -> bool: return node is Label).size(),
			"texture": nodes.filter(func(node: Node) -> bool: return node is TextureRect).size()
		}
	}
	if is_instance_valid(app):
		report["interaction_log"] = app.interaction_log
		report["fonts"] = app.font_report()
	var file := FileAccess.open(OUT + "restoration-probe-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))

func snap(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var file_name := "restoration-check-" + name_value + ".png"
	var result: Error = root.get_texture().get_image().save_png(OUT + file_name)
	if result != OK:
		push_error("Could not save " + file_name)
	else:
		captures.append(file_name)

func click(control: Control) -> void:
	var position_value: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position_value
	motion.global_position = position_value
	Input.parse_input_event(motion)
	await process_frame
	for pressed_value: bool in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = position_value
		mouse.global_position = position_value
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed_value
		Input.parse_input_event(mouse)
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func key(code: Key) -> void:
	for pressed_value: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed_value
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func walk(node: Node) -> Array:
	var nodes: Array = [node]
	for child: Node in node.get_children(): nodes.append_array(walk(child))
	return nodes

func visible_power_ids() -> Array[String]:
	var ids: Array[String] = []
	for node: Node in app.get_node("Interface/Dock").get_children():
		if str(node.name).begins_with("Power_POWER_") and node.is_visible_in_tree():
			ids.append(str(node.name).trim_prefix("Power_"))
	return ids

func metrics() -> Array[String]:
	var values: Array[String] = []
	for i: int in range(4):
		values.append(app.get_node("Interface/WorldContext/MetricValue_%d" % i).text)
	return values

func major_regions_inside_viewport() -> bool:
	var screen: Rect2 = root.get_visible_rect()
	for path: String in ["Interface/TopBar", "Interface/CultIndex", "Interface/Prayers", "Interface/Chronicle", "Interface/Dock"]:
		var rect: Rect2 = app.get_node(path).get_global_rect()
		if not screen.encloses(rect): return false
	for node: Node in walk(app.get_node("Interface/Prayers")):
		if node is Button and node.is_visible_in_tree() and not screen.encloses(node.get_global_rect()): return false
	return true

func _run() -> void:
	app = Scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	if not require(app.root_ready, "正式 CSV 只读装载，独立 Godot 场景初始化"): return
	var before: String = JSON.stringify(app.fixture_state)
	var prayers: Control = app.get_node("Interface/Prayers")
	var dock: Control = app.get_node("Interface/Dock")
	var sanctuary: Control = app.get_node("World/Sanctuary")
	var initial_sanctuary: Rect2 = sanctuary.get_global_rect()
	var initial_prayers: Rect2 = prayers.get_global_rect()
	var initial_dock: Rect2 = dock.get_global_rect()
	var screen: Rect2 = root.get_visible_rect()
	measured["viewport"] = [screen.size.x, screen.size.y]
	measured["adjusted_dock_height"] = dock.size.y
	measured["prayers_rect"] = [prayers.position.x, prayers.position.y, prayers.size.x, prayers.size.y]
	if not require(app.get_node("Interface/CultIndex/Cult_3") is Button and app.get_node("Interface/CultIndex/Cult_3/Name") is Label and app.get_node("Interface/Prayers/PrayerCard_1/Shallow_1") is Button, "索引、祈求和文字是可编辑原生控件"): return
	if not require(not app.reference_layout and initial_prayers.get_center().x > screen.size.x / 3.0 and initial_prayers.get_center().x < screen.size.x * 2.0 / 3.0, "默认祈求处于屏幕中央区域"): return
	if not require(dock.size.y < 186.0 and not initial_dock.intersects(initial_sanctuary), "底栏低于原稿占高且不覆盖场所主体"): return
	if not require(major_regions_inside_viewport(), "调整布局主要区域和祈求按钮均在逻辑画幅内"): return
	await snap("overview")

	var first_page: Array[String] = visible_power_ids()
	if not require(first_page == EXPECTED_POWERS.slice(0, 8), "第一页按固定顺序呈现前八权能"): return
	await click(app.get_node("Interface/Dock/NextPowers"))
	var second_page: Array[String] = visible_power_ids()
	if not require(second_page == EXPECTED_POWERS.slice(8, 12), "翻页真实输入后呈现后四权能"): return
	var all_ids: Array[String] = first_page.duplicate()
	all_ids.append_array(second_page)
	if not require(all_ids == EXPECTED_POWERS and all_ids.size() == 12, "两页完整覆盖十二权能且无缺失或重复"): return
	await click(app.get_node("Interface/Dock/Power_POWER_MANIFEST"))
	var locked_text: String = app.get_node("PreviewLayer/Dialog/Availability").text
	var threshold: String = str(app.catalog.tables.powers["POWER_MANIFEST"].unlock_awakening)
	if not require(app.modal_kind == "power" and "尚未解锁" in locked_text and threshold in locked_text and "65" in locked_text, "降临可点击查看 CSV 解锁门槛和当前苏醒值"): return
	await snap("locked-power")
	await key(KEY_ESCAPE)
	await click(app.get_node("Interface/Dock/PreviousPowers"))
	if not require(visible_power_ids() == first_page, "返回第一页保持固定顺序"): return

	for i: int in range(4):
		var relic: Control = app.get_node("Interface/Dock/RelicMaterial/Relic_%d" % i)
		if not require(not relic.get_node("RelicName").text.is_empty() and not relic.get_node("RelicState").text.is_empty() and relic.get_node("RelicImage").texture != null, "压缩圣物项 %d 保留图像、名称与显式状态" % i): return
	await click(app.get_node("Interface/Dock/RelicMaterial/AllRelics"))
	var inventory: ScrollContainer = app.get_node("PreviewLayer/Dialog/InventoryScroll")
	if not require(app.modal_kind == "relics" and inventory.get_child(0).get_child_count() == 18, "全部圣物入口打开十八件人工实例"): return
	inventory.scroll_vertical = 100000
	await process_frame
	if not require(inventory.scroll_vertical > 0, "十八件圣物列表可局部滚动至超屏内容"): return
	await snap("relics")
	await key(KEY_ESCAPE)

	await click(app.get_node("Interface/CultIndex/Cult_1"))
	if not require(app.selected_cult == 1 and metrics() == ["50", "25–49", "25–49", "75–100"] and "祭司塞拉" in app.get_node("Interface/WorldContext/ResistanceBand/Resistance").text, "盐梦02使用自身四维与具名反制记录"): return
	await click(app.get_node("Interface/WorldContext/AnchorStatus"))
	var salt_anchor: String = app.get_node("PreviewLayer/Dialog/Content").text
	if not require("未配置" in salt_anchor and "盐梦" in salt_anchor, "盐梦锚点入口明确本世界未配置，不冒用镜证数据"): return
	await key(KEY_ESCAPE)
	await click(app.get_node("Interface/CultIndex/Cult_0"))
	if not require(metrics() == ["未掌握", "未掌握", "未掌握", "未掌握"] and app.get_node("Interface/WorldContext/ResistanceBand/Resistance").text == "暂无已知反制", "未知世界不借用其他世界数值或反制"): return
	await click(app.get_node("Interface/WorldContext/ObservationSource"))
	if not require("暂无" in app.get_node("PreviewLayer/Dialog/Content").text, "未知世界来源入口不伪装为第45轮已知观察"): return
	await key(KEY_ESCAPE)
	await click(app.get_node("Interface/CultIndex/Cult_3"))
	if not require(metrics() == ["28", "50–74", "50–74", "50–74"] and "无名信众" in app.get_node("Interface/WorldContext/ResistanceBand/Resistance").text, "镜证04恢复自身四维及已公告反制后果"): return
	await click(app.get_node("Interface/WorldContext/AnchorStatus"))
	if not require("镜证04" in app.get_node("PreviewLayer/Dialog/Content").text and "1个有效锚点" in app.get_node("PreviewLayer/Dialog/Content").text, "镜证锚点说明与当前选中对象一致"): return
	await key(KEY_ESCAPE)
	if not require("45轮" in app.get_node("Interface/Chronicle/ComparedWorld/Metrics").text and "普通匿名保护失效" in app.get_node("Interface/Chronicle/ComparedWorld/Resistance").text, "世界对照保留历史观察轮次和反制后果"): return

	var shallow: Button = app.get_node("Interface/Prayers/PrayerCard_1/Shallow_1")
	await click(shallow)
	if not require(app.modal_kind == "prayer" and app.current_variant == "shallow", "真实浅触按钮打开祈求预览"): return
	var shallow_fee: String = "费用　%s低语 · %s信仰" % [app.catalog.integer("prayer_shallow_whispers"), app.catalog.integer("prayer_shallow_faith")]
	if not require(app.get_node("PreviewLayer/Dialog/Payment").text == shallow_fee, "浅触费用取自正式 CSV 并在预览正文显示"): return
	var effect_labels: Array = walk(app.get_node("PreviewLayer/Dialog/EffectScroll")).filter(func(node: Node) -> bool: return node is Label)
	if not require(effect_labels.any(func(node: Node) -> bool: return str(node.text).begins_with("必付代价")) and effect_labels.any(func(node: Node) -> bool: return str(node.text).begins_with("失败")), "祈求预览分开列出必付代价和失败后果"): return
	await snap("prayer-shallow")
	await click(app.get_node("PreviewLayer/Dialog/ChooseDeep"))
	var deep_fee: String = "费用　%s低语 · %s信仰" % [app.catalog.integer("prayer_deep_whispers"), app.catalog.integer("prayer_deep_faith")]
	if not require(app.current_variant == "deep" and app.get_node("PreviewLayer/Dialog/Payment").text == deep_fee, "深应切换同步更新正式费用与内容"): return
	await key(KEY_ESCAPE)
	if not require(not app.get_node("PreviewLayer").visible and root.gui_get_focus_owner() == shallow, "Escape 关闭并恢复原祈求按钮焦点"): return

	await key(KEY_F2)
	if not require(app.reference_layout and major_regions_inside_viewport(), "F2 原稿比例对照布局可打开且主要区域无溢出"): return
	if not require(sanctuary.get_global_rect() == initial_sanctuary, "布局切换不缩小或挪动场所主体"): return
	measured["reference_dock_height"] = dock.size.y
	await snap("reference-layout")
	await key(KEY_F2)
	if not require(not app.reference_layout and prayers.get_global_rect() == initial_prayers and dock.get_global_rect() == initial_dock, "F2 可恢复中央祈求及压缩底栏布局"): return

	await key(KEY_F1)
	if not require(app.get_node("FeedbackLayer/LayerInspector").visible, "F1 打开原生图层检查控件"): return
	await click(app.get_node("FeedbackLayer/LayerInspector/LayerToggle_4"))
	if not require(not app.get_node("Interface").visible and sanctuary.visible and app.get_node("World/Background").visible, "原生界面关闭后场所与海面独立保留"): return
	await snap("world-only")
	await click(app.get_node("FeedbackLayer/LayerInspector/LayerToggle_1"))
	await click(app.get_node("FeedbackLayer/LayerInspector/LayerToggle_2"))
	if not require(not sanctuary.visible and not app.get_node("World/Atmosphere/DistantFog").visible and app.get_node("World/Atmosphere/ForegroundFog").visible and app.get_node("World/Background").visible, "场所、远雾、前雾、海面可独立开关"): return
	await snap("separated-layers")
	if not require(before == JSON.stringify(app.fixture_state), "全部预览、选择、翻页与图层操作均未支付、推进或改变人工夹具"): return
	_write_result("PASS")
	print("RESTORATION_PROBE_OK ", checks.size(), " checks; ", captures.size(), " native captures")
	app.queue_free()
	await process_frame
	quit(0)
