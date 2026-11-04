extends SceneTree
## Native input checks for the isolated display index, not an aesthetic approval.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT = "res://tools/echoes-art-master/evidence/"
var app: Control
var checks: Array[String] = []

func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()

func verify(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CULT_INDEX_PROBE: " + message)
		quit(1)
		return false
	checks.append(message)
	return true

func mouse_at(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func move_to(pos: Vector2, previous: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = pos - previous
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await process_frame

func click(pos: Vector2) -> void:
	await move_to(pos, pos)
	await mouse_at(pos, MOUSE_BUTTON_LEFT, true)
	await mouse_at(pos, MOUSE_BUTTON_LEFT, false)

func key(code: Key, unicode_value: int = 0) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.unicode = unicode_value
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func snap(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "cult-index-" + name_value + ".png")

func _run() -> void:
	app = Scene.instantiate()
	root.add_child(app)
	for i in range(5): await process_frame
	if not verify(app.root_ready, "fixture initialised"): return
	var scroll: ScrollContainer = app.get_node("Interface/CultIndex/CultScroll")
	var list: VBoxContainer = scroll.get_node("CultList")
	var search: LineEdit = app.get_node("Interface/CultIndex/SearchCults")
	if not verify(list.get_child_count() == 12 and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "12 fixture entries overflow a native scroll container"): return
	var over_list := scroll.get_global_rect().get_center()
	await move_to(over_list, over_list)
	await mouse_at(over_list, MOUSE_BUTTON_WHEEL_DOWN, true)
	await mouse_at(over_list, MOUSE_BUTTON_WHEEL_DOWN, false)
	if not verify(scroll.scroll_vertical > 0, "actual mouse wheel moves index"): return
	await snap("wheel")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var rect := bar.get_global_rect()
	var thumb_h: float = maxf(16.0, rect.size.y * bar.page / (bar.max_value - bar.min_value))
	var available: float = rect.size.y - thumb_h
	var top := Vector2(rect.get_center().x, rect.position.y + thumb_h / 2.0 + available * bar.value / (bar.max_value - bar.min_value - bar.page))
	var bottom := Vector2(top.x, rect.end.y + 20.0)
	await move_to(top, top)
	await mouse_at(top, MOUSE_BUTTON_LEFT, true)
	await move_to(top.lerp(bottom, 0.5), top, true)
	await move_to(bottom, top.lerp(bottom, 0.5), true)
	await mouse_at(bottom, MOUSE_BUTTON_LEFT, false)
	for i in range(3): await process_frame
	if not verify(scroll.scroll_vertical >= int(bar.max_value-bar.page)-3, "actual thumb drag reaches last entry"): return
	await snap("drag-bottom")
	await click(list.get_node("Cult_11").get_global_rect().get_center())
	if not verify(app.selected_cult == 11 and app.get_node("Interface/WorldContext/MetricValue_0").text == "未掌握", "last entry selectable; unconfigured observation stays unknown"): return
	if not verify(scroll.scroll_vertical > 0, "selection preserves scroll position"): return
	await click(search.get_global_rect().get_center())
	await key(KEY_0, 48)
	await key(KEY_2, 50)
	for i in range(3): await process_frame
	if not verify(search.text == "02" and root.gui_get_focus_owner() == search, "typing in search retains keyboard focus"): return
	var visible: Array = list.get_children().filter(func(n: Node) -> bool: return n.visible)
	if not verify(visible.size() == 1 and visible[0].name == "Cult_1" and absf(visible[0].position.y) < 1.0, "search filters and packs the remaining entry"): return
	await snap("search")
	await click(visible[0].get_global_rect().get_center())
	if not verify(app.selected_cult == 1 and search.text == "02" and app.get_node("Interface/WorldContext/MetricValue_0").text == "50", "selecting filtered entry preserves query and correct observed data"): return
	await click(search.get_global_rect().get_center())
	await key(KEY_BACKSPACE)
	await key(KEY_BACKSPACE)
	if not verify(search.text.is_empty() and list.get_children().filter(func(n: Node) -> bool: return n.visible).size() == 12, "clearing search restores all entries"): return
	for i in range(12): await key(KEY_TAB)
	if not verify(root.gui_get_focus_owner() == list.get_node("Cult_11") and scroll.scroll_vertical > 0, "keyboard tab reaches offscreen entry and scroll follows focus"): return
	print("CULT_INDEX_PROBE_OK ", checks)
	quit(0)
