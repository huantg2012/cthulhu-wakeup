extends SceneTree
## Actual Godot GUI input dispatch, not native OS automation or human play.
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var scene: Node
var checks: Array = []
var output: String
var capture_directory: String
var canceled_executed: bool = false

func _initialize() -> void: call_deferred("run")

func check(id: String, condition: bool, evidence: Dictionary = {}) -> void:
	checks.append({"id":id, "status":"pass" if condition else "fail", "evidence":evidence}); print(id, " ", condition)

func key(code: int, shift: bool = false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; event.shift_pressed = shift; event.window_id = root.get_window_id(); Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new(); event.keycode = code; event.pressed = false; event.shift_pressed = shift; event.window_id = root.get_window_id(); Input.parse_input_event(event)
	await process_frame

func click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	var event := InputEventMouseButton.new(); event.position = position; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.window_id = root.get_window_id(); Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new(); event.position = position; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = false; event.window_id = root.get_window_id(); Input.parse_input_event(event)
	await process_frame

func tab_to(control: Control) -> bool:
	for count: int in 100:
		if root.gui_get_focus_owner() == control: return true
		await key(KEY_TAB)
	return false

func navigate(title: String) -> void:
	await tab_to(scene._nav.get_node("Nav" + title))
	await key(KEY_ENTER)

func capture(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(capture_directory.path_join(name + ".png"))

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output = args[0]; capture_directory = args[1]; DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	scene = load("res://src/presentation/game_root.tscn").instantiate()
	scene.session = Session.new("res://.godot/ui-input-saves/" + str(Time.get_ticks_usec()))
	root.add_child(scene)
	await process_frame
	await process_frame
	await capture("menu-19")
	scene._seed.text = "7919" # Explicit UI field fixture, no rule state injection.
	await key(KEY_TAB)
	var new_focus: bool = root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().text == "新局"
	await key(KEY_ENTER)
	await process_frame
	check("UI-INPUT-001", new_focus and scene.projection.get("active", false) and scene.projection.turn == 1, {"tab_to_new":new_focus})
	var reached: bool = await tab_to(scene._progress)
	await key(KEY_ENTER)
	check("UI-INPUT-002", reached and scene.projection.phase == "actions", {"tab_to_progress":reached})
	await navigate("权能")
	var dream_index: int = -1
	for index: int in range(scene.rows.size()):
		if scene.rows[index].key == "POWER_DREAM": dream_index = index
	if dream_index >= 0: await click(scene._items.get_child(dream_index))
	await capture("power-preview-19")
	var faith: int = scene.session.project().faith
	var receipt_count: int = Store.size(scene.session.turn.context.receipts)
	var dream_ready: bool = not scene._execute.disabled
	if dream_ready: await click(scene._execute)
	check("UI-INPUT-003", dream_ready and scene.session.project().faith == faith - 2 and Store.size(scene.session.turn.context.receipts) == receipt_count + 1, {"actual_preview":dream_ready,"faith_before":faith,"faith_after":scene.session.project().faith})
	var committed: String = scene.session.turn.snapshot()
	await click(scene._execute)
	check("UI-INPUT-004", scene.session.turn.snapshot() == committed, {"repeat_input_atomic":true})
	await navigate("祈求")
	reached = await tab_to(scene._execute)
	var before: String = scene.session.turn.snapshot()
	await key(KEY_ENTER)
	check("UI-INPUT-005", reached and scene._confirm.visible and scene.session.turn.snapshot() == before, {"confirmation_pure":scene.session.turn.snapshot() == before})
	await capture("prayer-confirm-19")
	# Cancel is the default focus; Tab moves to explicit confirmation.
	await key(KEY_TAB)
	var explicit: bool = root.gui_get_focus_owner() == scene._confirm.get_ok_button()
	await key(KEY_ENTER)
	await process_frame
	check("UI-INPUT-006", explicit and not scene._confirm.visible and scene.session.turn.snapshot() != before, {"explicit_confirm_focus":explicit,"feedback":scene._status.text})
	await capture("prayer-result-19")
	await navigate("菜单")
	var size_control: SpinBox
	for child: Node in scene._detail.get_children():
		if child is SpinBox: size_control = child
	if size_control == null: check("UI-LAYOUT-001", false); finish(); return
	size_control.value = 28 # Real setting signal; font fixture, not keyboard typing.
	await navigate("经营")
	await capture("economy-28")
	var progress_rect: Rect2 = scene._progress.get_global_rect()
	check("UI-LAYOUT-001", root.size == Vector2i(1280, 720) and progress_rect.position.y >= 0 and progress_rect.end.y <= 720 and scene._detail_scroll.get_global_rect().end.y < progress_rect.position.y, {"progress_rect":str(progress_rect),"font":scene.font_size})
	before = scene.session.turn.snapshot()
	scene._ask("长确认布局夹具\n" + "对象与不可逆代价必须可读，动作保持可达。\n".repeat(100), func() -> void: canceled_executed = true)
	await capture("long-confirm-28")
	await key(KEY_PAGEDOWN)
	var scroll: int = scene._confirm.scroll.scroll_vertical
	await key(KEY_TAB)
	var trapped: bool = root.gui_get_focus_owner() == scene._confirm.get_ok_button()
	await key(KEY_TAB, true)
	var reverse_focus: bool = root.gui_get_focus_owner() == scene._confirm.get_cancel_button()
	await key(KEY_ESCAPE)
	check("UI-INPUT-007", scroll > 0 and trapped and reverse_focus and not scene._confirm.visible and not canceled_executed and scene.session.turn.snapshot() == before, {"modal_scroll":scroll,"focus_trapped":trapped,"reverse_focus":reverse_focus,"cancel_pure":scene.session.turn.snapshot() == before})
	await navigate("编年史")
	await key(KEY_PAGEDOWN)
	await capture("history-28")
	var history_scroll: int = scene._detail_scroll.scroll_vertical
	var old_slot: String = scene.session.slot
	var old_snapshot: String = scene.session.turn.snapshot()
	await navigate("菜单")
	scene._seed.text = "9739"
	var new_button: Button
	for child: Node in scene._detail.get_children():
		if child is Button and child.text == "新局": new_button = child
	await tab_to(new_button); await key(KEY_ENTER); await key(KEY_TAB); await key(KEY_ENTER)
	await process_frame
	var new_slot: String = scene.session.slot
	await navigate("菜单")
	var picker: OptionButton = scene._detail.get_node("SavedGames")
	var old_found: bool = false
	for index: int in range(picker.item_count):
		if picker.get_item_metadata(index) == old_slot: picker.select(index); old_found = true; break
	await tab_to(scene._detail.get_node("LoadSelected")); await key(KEY_ENTER); await key(KEY_TAB); await key(KEY_ENTER)
	check("UI-INPUT-008", history_scroll > 0 and old_found and new_slot != old_slot and scene.session.slot == old_slot and scene.session.turn.snapshot() == old_snapshot, {"history_scroll":history_scroll, "old_slot_available":old_found, "new_slot_distinct":new_slot != old_slot, "old_restored":scene.session.slot == old_slot})
	check("UI-THEME-001", scene.BasicTheme.readability_issues().is_empty() and scene.overlay.theme.default_font_size == 28, {"issues":scene.BasicTheme.readability_issues()})
	finish()

func finish() -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	var passed: bool = checks.all(func(row: Dictionary) -> bool: return row.status == "pass")
	file.store_string(JSON.stringify({"status":"pass" if passed else "fail", "checks":checks, "engine":Engine.get_version_info().string}, "\t")); file.close()
	quit(0 if passed else 1)
