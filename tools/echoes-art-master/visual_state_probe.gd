extends SceneTree
## Input and state evidence for the isolated art fixture, not aesthetic approval.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT := "res://tools/echoes-art-master/evidence/"
var app: Control
var checks: Array[String] = []
var captures: Array[String] = []
var observations: Dictionary = {}

func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()

func report(status: String, failure: String = "") -> void:
	var file := FileAccess.open(OUT + "visual-state-probe-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"status": status, "checks": checks, "failure": failure,
		"captures": captures, "observations": observations,
		"scope": "Actual Godot input and rendered screenshots in the isolated T46 display fixture. Checks the named controls and the listed states, stylebox types, keyboard focus, and relic inventory scrolling. Does not establish alpha quality of every icon, formal Session behavior, or aesthetic acceptance."
	}, "\t"))

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("VISUAL_STATE_PROBE: " + message)
		report("FAIL", message)
		quit(1)
		return false
	checks.append(message)
	return true

func snap(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var name_file := "visual-state-" + name_value + ".png"
	var result := root.get_texture().get_image().save_png(OUT + name_file)
	if result == OK: captures.append(name_file)
	else: push_error("Could not save " + name_file)

func move_to(position_value: Vector2, held: bool = false, relative_value: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position_value
	event.global_position = position_value
	event.relative = relative_value
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await process_frame

func mouse_button(position_value: Vector2, button_value: MouseButton, pressed_value: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position_value
	event.global_position = position_value
	event.button_index = button_value
	event.pressed = pressed_value
	Input.parse_input_event(event)
	await process_frame

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	await move_to(at)
	await mouse_button(at, MOUSE_BUTTON_LEFT, true)
	await mouse_button(at, MOUSE_BUTTON_LEFT, false)

func transparent_style(button: Button) -> bool:
	if not button.get_theme_stylebox("normal") is StyleBoxEmpty: return false
	for state in ["hover", "pressed"]:
		var style: StyleBox = button.get_theme_stylebox(state)
		if button.has_node("Icon"):
			if not style is StyleBoxEmpty: return false
		elif not (style is StyleBoxFlat and style.bg_color.a < 0.3): return false
	return true

func capture_mouse_states(button: Button, name_value: String) -> bool:
	if not require(transparent_style(button), name_value + " normal/hover/pressed 均不使用源图纹理边框"): return false
	if not require(button.tooltip_text.is_empty(), name_value + " 不显示会遮住底栏的原生 tooltip"): return false
	var at := button.get_global_rect().get_center()
	await move_to(at)
	if root.gui_get_hovered_control() != button:
		print("HOVER_DIAGNOSTIC target=",button.get_path()," at=",at," actual=",root.gui_get_hovered_control())
	if not require(root.gui_get_hovered_control() == button, name_value + " 真实鼠标悬停到目标按钮"): return false
	if button.has_node("Icon") and not require(button.get_node("Icon").scale.x > 1.0, name_value + " 悬停改变图标本身"): return false
	await snap(name_value + "-hover")
	await mouse_button(at, MOUSE_BUTTON_LEFT, true)
	if not require(button.button_pressed, name_value + " 真实鼠标按下状态"): return false
	await snap(name_value + "-pressed")
	# Cancel by releasing away from the button, avoiding navigation to a modal.
	await move_to(Vector2(840, 300), true, Vector2(840, 300)-at)
	await mouse_button(Vector2(840, 300), MOUSE_BUTTON_LEFT, false)
	return true

func _run() -> void:
	app = Scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	if not require(app.root_ready, "独立夹具初始化"): return
	var power: Button = app.get_node("Interface/Dock/PowerScroll/Items/Power_POWER_LISTEN")
	var relic: Button = app.get_node("Interface/Dock/RelicScroll/Items/Relic_0")
	var notice: Button = app.get_node("Interface/Prayers/OtherWorldNotice/Notice")
	if not await capture_mouse_states(power, "power"): return
	if not await capture_mouse_states(relic, "relic"): return
	if not await capture_mouse_states(notice, "notice"): return

	# Navigate by actual Tab events, never invoking grab_focus as a shortcut.
	var prayer: Button = app.get_node("Interface/Prayers/PrayerCard_1")
	var reached := false
	for i in range(150):
		await key(KEY_TAB)
		if root.gui_get_focus_owner() == prayer:
			reached = true
			observations["tab_events_to_prayer"] = i+1
			break
	if not require(reached, "使用 Tab 导航到祈求摘要焦点"): return
	if not require(prayer.get_theme_stylebox("focus") is StyleBoxFlat, "祈求焦点使用独立非源图边框"): return
	await snap("prayer-keyboard-focus")

	# Tab traversal can move the horizontal inventory viewport away from item 0.
	app.get_node("Interface/Dock/RelicScroll").scroll_horizontal = 0
	await process_frame
	await click(app.get_node("Interface/Dock/RelicScroll/Items/Relic_0"))
	if not require(app.modal_kind == "relics", "鼠标打开圣物展示弹窗"): return
	var inventory: ScrollContainer = app.get_node("PreviewLayer/Dialog/InventoryScroll")
	var scroll_bar := inventory.get_v_scroll_bar()
	await process_frame
	var scroll_at: Vector2 = inventory.get_global_rect().get_center()
	await move_to(scroll_at)
	await mouse_button(scroll_at, MOUSE_BUTTON_WHEEL_DOWN, true)
	await mouse_button(scroll_at, MOUSE_BUTTON_WHEEL_DOWN, false)
	var wheel_value := inventory.scroll_vertical
	observations["relic_scroll_after_wheel"] = wheel_value
	if not require(wheel_value > 0, "圣物弹窗真实滚轮向下访问超屏内容"): return
	await snap("relic-inventory-wheel")

	# Rewind by wheel, then drag the vertical scrollbar thumb from its first page.
	for i in range(10):
		await mouse_button(scroll_at, MOUSE_BUTTON_WHEEL_UP, true)
		await mouse_button(scroll_at, MOUSE_BUTTON_WHEEL_UP, false)
		if inventory.scroll_vertical == 0: break
	if not require(inventory.scroll_vertical == 0, "圣物弹窗滚轮返回顶部"): return
	var bar_rect := scroll_bar.get_global_rect()
	var thumb_height: float = bar_rect.size.y * scroll_bar.page / (scroll_bar.max_value - scroll_bar.min_value)
	var thumb_at := Vector2(bar_rect.get_center().x, bar_rect.position.y + maxf(8.0, thumb_height * 0.5))
	var end_at := Vector2(thumb_at.x, minf(bar_rect.end.y - 4.0, thumb_at.y + 120.0))
	await move_to(thumb_at)
	await mouse_button(thumb_at, MOUSE_BUTTON_LEFT, true)
	await move_to(end_at, true, end_at - thumb_at)
	await mouse_button(end_at, MOUSE_BUTTON_LEFT, false)
	observations["relic_scroll_after_thumb_drag"] = inventory.scroll_vertical
	observations["relic_scrollbar_rect"] = [bar_rect.position.x,bar_rect.position.y,bar_rect.size.x,bar_rect.size.y]
	if not require(inventory.scroll_vertical > 0, "圣物弹窗真实滚动条拖动访问超屏内容"): return
	await snap("relic-inventory-drag")
	await key(KEY_ESCAPE)
	if not require(not app.get_node("PreviewLayer").visible, "Escape 关闭圣物弹窗"): return
	report("PASS")
	print("VISUAL_STATE_PROBE_OK ", checks.size(), " checks; ", captures.size(), " native captures")
	quit(0)
