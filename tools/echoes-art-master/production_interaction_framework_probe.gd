extends SceneTree
## Input smoke check for the migrated scene hierarchy and its real Session routes.
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app: Control
var evidence := ""

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func click(id: String) -> bool:
	await process_frame
	var button := app.find_child(id, true, false) as Button
	if not require(button != null and button.is_visible_in_tree() and not button.disabled, "Control unavailable: " + id):
		return false
	if not evidence.is_empty():
		button.pressed.emit()
		await process_frame
		return true
	var at := button.get_global_transform_with_canvas() * (button.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	if not require(hovered == button, "Pointer is intercepted on %s by %s at %s" % [id, hovered, at]): return false
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	return true

func shot(file: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(0.24).timeout
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(evidence.path_join(file + ".png"))

func require_bounds(id: String, bounds: Rect2) -> bool:
	var control := app.find_child(id, true, false) as Control
	if not require(control != null, "Missing scene element: " + id): return false
	var actual := control.get_global_rect()
	return require(actual.position.distance_to(bounds.position) <= 1.0 and actual.size.distance_to(bounds.size) <= 2.0, "Sample bounds diverged for %s: %s expected %s" % [id, actual, bounds])

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		evidence = args[0]
		DirAccess.make_dir_recursive_absolute(evidence)
	var game := Scene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new("user://interaction-framework-probe/%d" % Time.get_ticks_usec())
	root.add_child(game)
	if not await click("NewGameOptions"): return
	app.find_child("Seed", true, false).text = "1"
	if not await click("NewGame"): return
	if not require(app._dialog.is_empty() and app._world_id.is_empty(), "New game did not arrive at the overview"): return
	var before: String = app.session.turn.snapshot()
	var public_before: Dictionary = app.session.knowledge_snapshot()
	var prayer: Dictionary = app._pending_prayers()[0]
	if not require(prayer.descriptor.get("space", false), "New game did not lead with a generated situation"): return
	var domain: String = prayer.descriptor.get("domain", prayer.card.get("domain", ""))
	if not require_bounds("PerceptionTitle", Rect2(62.4, 172, 400, 47.2)): return
	if not require_bounds("WorldPlaceholder_" + domain, Rect2(348.8, 114.4, 566.4, 451.2)): return
	if not require_bounds("PhaseAction", Rect2(1128, 644.8, 113.6, 37.6)): return
	await shot("overview")
	if not await click("World_" + domain): return
	if not require(app._world_id == domain, "World entry lost the local subject"): return
	if not require_bounds("SceneSlot", Rect2(150.88, -8.96, 717.44, 571.52)): return
	if not require_bounds("PrayerIndex", Rect2(756, 346.4, 222.4, 51.2)): return
	if not require_bounds("MetricHelp_barrier", Rect2(62.4, 257.6, 212, 32)): return
	for field: String in ["barrier", "pollution", "alert", "stability"]:
		if not require(app.find_child("MetricHelp_" + field, true, false) != null, "Missing local observation: " + field): return
	await shot("local-world")
	if not await click("PrayerIndex"): return
	var from_list: bool = app._dialog == "prayer_intro"
	if from_list:
		if not await click("IntroPrayer_" + prayer.id): return
	if not require(app._dialog == "prayer_detail", "Local pin did not reach its prayer"): return
	if not require_bounds("PrayerSpace", Rect2(32, 116, 1216, 510.4)): return
	if not require_bounds("Response", Rect2(842.4, 194.4, 372, 332)): return
	var choices: Array[Node] = app._surface.find_children("SpaceChoice_*", "Button", true, false)
	if not require(choices.size() >= 2 and choices[0].position.y < choices[1].position.y and app.find_child("Mode_shallow", true, false) == null, "Generated responses must be concrete and vertically comparable"): return
	if not await click(str(choices[0].name)): return
	if not await click("ClosePrayer"): return
	if from_list and not await click("DismissPrayers"): return
	if not await click("MetricHelp_barrier"): return
	if not require(app._world_management._metric_field == "barrier", "Metric row did not reach its own explanation"): return
	if not await click("WorldBack"): return
	if not await click("WorldOverview"): return
	if not await click("PowerIndex"): return
	if not require(app._dialog == "powers" and app._surface.find_children("Sigil_*", "Button", true, false).size() == 12, "Incomplete power circle"): return
	await shot("powers")
	if not await click("PowerRules"): return
	if not require_bounds("RelatedPeek", Rect2(880.8, 175.2, 360, 402.4)): return
	if not await click("ClosePowerRules"): return
	if not require(root.gui_get_focus_owner().name == "PowerRules", "Rules return lost the power entry"): return
	if not await click("Sigil_POWER_DREAM"): return
	if not await click("PreparePower"): return
	if not require(app._dialog == "task_action" and app._tasks.draft.key == "POWER_DREAM", "Power circle did not enter real preparation"): return
	await shot("power-contact")
	if not await click("ActionTab_npc"): return
	if not require_bounds("RitualPicker", Rect2(364, 217.6, 552, 328.8)): return
	if not await click("ClosePicker"): return
	if not await click("ReturnAction"): return
	if not require(app._dialog == "powers" and root.gui_get_focus_owner().name == "PreparePower", "Preparation lost the power-circle return"): return
	if not await click("ClosePowers"): return
	if not await click("PrayerIndex"): return
	if not await click("IntroPrayer_" + prayer.id): return
	if not require(app._dialog == "prayer_detail", "Overview prayer did not enter the actual prayer scene"): return
	await shot("prayer")
	if not await click("ClosePrayer"): return
	if not await click("DismissPrayers"): return
	if not require(app.session.turn.snapshot() == before and app.session.knowledge_snapshot() == public_before, "Viewing changed rules or knowledge"): return
	for script: String in ["ui_components", "ui_composites", "restoration_font", "restoration_skin", "opening_veil", "dock_content"]:
		if not require(not ResourceLoader.has_cached("res://src/presentation/ui/" + script + ".gd"), "Legacy UI loaded: " + script): return
	if args.size() > 1:
		app._load_saved(args[1])
		if not require(app.projection.phase == "actions" and app.projection.domains.size() > 1, "Comparison save must contain known worlds and be in actions"): return
		await shot("overview-known-worlds")
		var main_world: Dictionary = app._interaction._ranked_worlds(app._pending_prayers())[0]
		var next_world: Dictionary = app._interaction._ranked_worlds(app._pending_prayers())[1]
		if not await click("World_" + main_world.id): return
		await shot("local-known-worlds")
		if not await click("World_" + next_world.id): return
		if not require(app._world_id == next_world.id, "Peripheral contact did not switch directly"): return
	print("INTERACTION_FRAMEWORK_OK overview, local observations, 12 powers, real draft return, prayer, pure browsing")
	game.free()
	quit()
