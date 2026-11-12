extends "res://tools/ui-art-production/overview_probe.gd"
## Real save and keyboard/mouse actions; does not patch the Session or card data.

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	var isolated := "user://ui-art-production-probe/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	if "--saved" in args:
		var fixture := "res://docs/qa/ui-manifest/saves/ongoing.json"
		var path := isolated.path_join("1793836800-7001.json")
		if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(fixture), ProjectSettings.globalize_path(path)) == OK, "Could not stage existing Session save"): return
	var main := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if not require(main != null, "Cannot load production main scene"): return
	var game := main.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(isolated)
	app.display_settings_path = isolated.path_join("display.cfg")
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	app._large_text = "--large" in args
	if "--saved" in args:
		if not await click("SavedGames"): return
		if not await click("SavedGame_0"): return
	else:
		if not await click("NewGameOptions"): return
		(app.find_child("Seed", true, false) as LineEdit).text = "1"
		if not await click("NewGame"): return
	if not require(app.projection.get("active", false) and app._dialog.is_empty() and app._world_id.is_empty(), "Did not reach 诸界: " + str(app._notice_text)): return
	var fan: Control = app.find_child("WorldFan", true, false)
	if not require(fan.cards.size() == app.projection.domains.size(), "Shown card count is not the public world count"): return
	var before: String = app.session.turn.snapshot()
	var knowledge: Dictionary = app.session.knowledge_snapshot()
	fan.grab_focus()
	await press_key(KEY_RIGHT)
	var selected: Control = fan.cards[fan.focus_index]
	var id: String = selected.get_meta("subject_id")
	var art: TextureRect = selected.art
	var key: String = art.get_meta("art_key")
	if not require(not key.is_empty(), "No art recipe for selected public world " + id): return
	var deadline := Time.get_ticks_msec() + 45000
	while art.texture == null and Time.get_ticks_msec() < deadline:
		await process_frame
	if not require(art.texture != null and art.texture.get_size() == Vector2(960, 960), "Selected world image never arrived " + id): return
	if not output.is_empty():
		RenderingServer.force_draw(false)
		if not require(root.get_texture().get_image().save_png(output) == OK, "Could not capture cards"): return
	if "--saved" in args:
		var dragged: bool = await drag_card(fan, selected)
		if not require(dragged and app._world_id.is_empty(), "Releasing a drag entered a world"): return
		fan.set_focus(fan.cards.find(selected), false) # Restore the earlier selection for the keyboard path.
		fan.grab_focus()
	await press_key(KEY_ENTER)
	if not require(app._world_id == id and app._dialog.is_empty(), "Enter opened the wrong world"): return
	await press_key(KEY_ESCAPE)
	fan = app.find_child("WorldFan", true, false)
	selected = fan.cards[fan.focus_index]
	if not require(selected.get_meta("subject_id") == id and selected.art.get_meta("art_key") == key and selected.art.texture != null, "Returning changed card identity or lost its image"): return
	if not require(app.session.turn.snapshot() == before and app.session.knowledge_snapshot() == knowledge, "Reading cards changed game or knowledge state"): return
	print("PASS: card count=", fan.cards.size(), " stacked=", fan.is_stacked(), " id=", id, " key=", key, " known_worlds=", app.session.known_domains().size())
	quit()


func drag_card(fan: Control, card: Control) -> bool:
	var at := card.get_global_transform_with_canvas() * Vector2(130, 195)
	var away := at - Vector2(80, 0)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	await process_frame
	move = InputEventMouseMotion.new()
	move.position = away
	move.global_position = away
	move.relative = away - at
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await process_frame
	var dragging: bool = fan._dragging
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = away
	up.global_position = away
	root.push_input(up, true)
	await process_frame
	return dragging
