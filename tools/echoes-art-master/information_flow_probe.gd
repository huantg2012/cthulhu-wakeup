extends SceneTree
## Input-driven checks for S1/S2 in the isolated display fixture.
const Scene = preload("res://tools/echoes-art-master/scene.tscn")
const OUT = "res://tools/echoes-art-master/evidence/info-flow-"
var app: Control
var checks: Array[String] = []

func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()

func frame() -> void:
	await process_frame
	await process_frame

func require(ok: bool, description: String) -> bool:
	if not ok:
		push_error("INFO_FLOW_PROBE: " + description)
		quit(1)
		return false
	checks.append(description)
	return true

func click(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(4, 4)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await frame()
	motion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await frame()
	await create_timer(0.08).timeout
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frame()
		await create_timer(0.08).timeout

func wheel(node: Control, count: int) -> void:
	var at := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await frame()
	for i in count:
		for down: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = at
			event.global_position = at
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = down
			Input.parse_input_event(event)
			await frame()

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await frame()

func snap(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frame()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name_value + ".png")

func card(index: int) -> Control:
	return app.get_node("Interface/Prayers/PrayerCard_%d" % index)

func _run() -> void:
	app = Scene.instantiate()
	app.show_opening_on_start = false
	root.add_child(app)
	await frame()
	root.position = Vector2i(0, 0)
	root.grab_focus()
	await create_timer(0.4).timeout
	print("PROBE_WINDOW focused=", root.has_focus(), " pos=", root.position, " size=", root.size)
	if not require(app.root_ready, "fixture scene initialized"): return
	var before := JSON.stringify(app.fixture_state)
	var stage: Control = app.get_node("Interface/PrimaryStage")
	var context: Control = app.get_node("Interface/WorldContext")
	var worlds: VBoxContainer = app.get_node("Interface/WorldIndex/WorldScroll/WorldList")
	await snap("world")
	await click(worlds.get_node("World_04"))
	await click(context.get_node("ManageCult"))
	if not require(app.current_mode == "cult" and stage.has_node("Members"), "enter cult overview from world"): return
	await snap("cult")
	await click(stage.get_node("Members"))
	if not require(stage.has_node("MemberScroll/MemberList/Member_0"), "roster and selected member visible together"): return
	await click(stage.get_node("MemberScroll/MemberList/Member_1"))
	if not require(int(app.get_meta("s1_member", -1)) == 1, "select a member using roster"): return
	await click(stage.get_node("TabDuties"))
	if not require(str(app.get_meta("s1_tab", "")) == "duties", "switch same member to duties"): return
	if not require(root.gui_get_focus_owner() == stage.get_node("TabDuties"), "same-object tab retains keyboard focus after rebuilding"): return
	await snap("member")
	var list_scroll: ScrollContainer = stage.get_node("MemberScroll")
	await wheel(list_scroll, 4)
	var scroll_before := list_scroll.scroll_vertical
	if not require(scroll_before > 0, "member list actually scrolls with wheel"): return
	await click(stage.get_node("InspectRelic"))
	if not require(str(app.get_meta("s1_read", "")) == "relic" and stage.has_node("MemberScroll/MemberList"), "associated object replaces detail while roster remains"): return
	await snap("member-relic")
	await click(stage.get_node("RelicSource"))
	if not require(str(app.get_meta("s1_read", "")) == "source" and stage.has_node("MemberScroll/MemberList"), "source replaces same related reading area"): return
	await snap("member-source")
	await key(KEY_ESCAPE)
	if not require(stage.has_node("TabDuties") and str(app.get_meta("s1_tab", "")) == "duties" and int(app.get_meta("s1_member", -1)) == 1 and stage.get_node("MemberScroll").scroll_vertical == scroll_before, "escape once from related source restores original member, tab and scroll"): return
	if not require(root.gui_get_focus_owner() == stage.get_node("InspectRelic"), "escape restores focus to the related-object entry"): return
	await click(stage.get_node("InspectRelic"))
	if not require(stage.has_node("RelicSource"), "reopen related object after escape"): return
	await click(stage.get_node("RelicSource"))
	await click(stage.get_node("ReturnMember"))
	if not require(int(app.get_meta("s1_member", -1)) == 1 and str(app.get_meta("s1_tab", "")) == "duties" and str(app.get_meta("s1_read", "x")) == "", "one return restores selected member and same-object tab"): return
	if not require(stage.get_node("MemberScroll").scroll_vertical == scroll_before, "one return restores roster scroll position"): return
	await snap("member-return")
	await click(stage.get_node("InspectRelic"))
	await click(stage.get_node("OpenRelicTask"))
	if not require(str(app.get_meta("s1_read", "")) == "object" and stage.has_node("RelicTaskDetails") and not stage.has_node("MemberScroll"), "explicit object task replaces the roster view"): return
	await snap("relic-task")
	await click(stage.get_node("ReturnMember"))
	if not require(int(app.get_meta("s1_member", -1)) == 1 and str(app.get_meta("s1_tab", "")) == "duties" and stage.get_node("MemberScroll").scroll_vertical == scroll_before, "return from object task restores member, tab and roster scroll"): return
	await click(stage.get_node("InspectRelic"))
	await click(stage.get_node("OpenRelicTask"))
	await click(worlds.get_node("World_06"))
	if not require(app.current_mode == "world" and app.selected_world == 5 and str(app.get_meta("s1_read", "x")) == "" and not bool(app.get_meta("s1_roster", true)), "choosing another world ends prior related-object origin"): return
	var mirror_card: Control = worlds.get_node("World_04")
	print("WORLD04_BEFORE rect=", mirror_card.get_global_rect(), " visible=", mirror_card.is_visible_in_tree(), " scroll=", app.get_node("Interface/WorldIndex/WorldScroll").scroll_vertical, " viewport=", root.get_visible_rect())
	await click(mirror_card)
	var hovered: Control = root.gui_get_hovered_control()
	print("WORLD04_AFTER selected=", app.selected_world, " mouse=", root.get_mouse_position(), " hovered=", hovered.get_path() if hovered != null else "none", " focus=", root.gui_get_focus_owner().get_path() if root.gui_get_focus_owner() != null else "none", " modal=", app.modal_kind)
	if not require(app.selected_world == 3, "selecting mirror world by card"): return
	await click(context.get_node("ManageCult"))
	if not require(stage.has_node("Members") and not stage.has_node("ReturnMember"), "returning to world starts cult overview without stale return origin"): return
	await click(stage.get_node("Members"))
	await click(stage.get_node("ReturnCult"))
	if not require(stage.has_node("Members"), "return to cult overview"): return
	await click(card(1))
	if not require(app.current_mode == "prayer" and app.current_prayer == 1, "open prayer by its summary"): return
	await click(stage.get_node("ChooseDeep"))
	if not require(app.current_variant == "deep", "choose deep response"): return
	await wheel(stage.get_node("EffectScroll"), 4)
	if not require(app.current_mode == "prayer" and stage.has_node("ChooseDeep") and stage.get_node("EffectScroll").scroll_vertical > 0, "scrolling remains in response task"): return
	await key(KEY_TAB)
	if not require(app.current_mode == "prayer" and stage.has_node("ChooseDeep"), "keyboard focus movement keeps the response controls"): return
	await snap("prayer-deep")
	await click(stage.get_node("InspectPerson"))
	if not require(app.current_mode == "prayer_person" and not stage.has_node("ChooseDeep") and not stage.has_node("Payment") and not stage.has_node("EffectScroll"), "person inspection hides response controls and costs"): return
	await snap("prayer-person")
	await click(stage.get_node("InspectPossessions"))
	if not require(app.current_mode == "prayer_person_item" and not stage.has_node("ChooseDeep"), "related record uses the reading area"): return
	await snap("prayer-person-item")
	await key(KEY_ESCAPE)
	if not require(app.current_mode == "prayer" and app.current_variant == "deep", "escape once from related record returns to original prayer choice"): return
	await click(stage.get_node("InspectPerson"))
	await click(stage.get_node("InspectPossessions"))
	await click(stage.get_node("ReturnPrayer"))
	if not require(app.current_mode == "prayer" and app.current_variant == "deep", "single named return restores response choice"): return
	await snap("prayer-return")
	await click(worlds.get_node("World_06"))
	if not require(app.current_mode == "world" and not stage.visible, "changing world dismisses response panel"): return
	await click(card(2))
	if not require(app.current_prayer == 2 and app.current_variant == "shallow", "another prayer retains an independent default"): return
	await click(card(1))
	if not require(app.current_prayer == 1 and app.current_variant == "deep", "reopening original prayer remembers its choice"): return
	await key(KEY_ESCAPE)
	if not require(app.current_mode == "world" and not stage.visible, "escape leaves the prayer"): return
	if not require(before == JSON.stringify(app.fixture_state), "inspection and choice do not mutate fixture resources"): return
	print("INFORMATION_FLOW_PROBE_OK ", checks.size(), " checks")
	quit(0)
