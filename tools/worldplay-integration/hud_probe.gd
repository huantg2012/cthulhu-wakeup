extends "res://tools/worldplay-integration/probe.gd"
## The main scene and real Session, with a private save/settings directory.
func setup(args: PackedStringArray) -> bool:
	var isolated := "user://hud-study/%s" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(isolated)
	app.display_settings_path = isolated.path_join("display.cfg")
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	if not await click("NewGameOptions"): return false
	(app.find_child("Seed",true,false) as LineEdit).text = "1"
	if not await click("NewGame"): return false
	var deadline := Time.get_ticks_msec()+180000
	while app._portraits.preparing and Time.get_ticks_msec()<deadline: await process_frame
	if not require(not app._portraits.preparing,"Art preparation timed out"): return false
	await process_frame
	if app._arrival.visible: await press_key(KEY_ENTER)
	return true

func run() -> void:
	output = "res://docs/art/visual-generation/hud-study/evidence/final"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await setup([]): return
	if not require(app._hud != null,"Formal entry did not build selected HUD"): return
	if not await inspect_hud(): return
	await capture("overview")
	var id: String = app.projection.domains[0].id
	if not await world(id): return
	await create_timer(.4).timeout
	await capture("world")
	if not await inspect_hud(): return
	if "--live" in OS.get_cmdline_user_args():
		print("HUD_READY: selected production HUD; isolated real Session.")
		return
	var snapshot: String = app.session.turn.snapshot()
	if not await click("RoundResponsibilities"): return
	if not require(app._dialog=="round_responsibilities" and app._surface.find_child("ConfirmEnd",true,false)==null,"Responsibilities still advances the turn"): return
	await capture("responsibilities")
	await press_key(KEY_ESCAPE)
	if not require(app.session.turn.snapshot()==snapshot,"Read-only responsibilities changed the Session"): return
	if not await click("PhaseAction"): return
	if not require(app._dialog=="hud_end","Next turn did not open its own confirmation"): return
	await capture("next-confirm")
	await press_key(KEY_ESCAPE)
	if not require(app._dialog.is_empty() and app.session.turn.snapshot()==snapshot,"Cancel advanced the round"): return
	if not await click("PowerIndex"): return
	if not await inspect_hud(): return
	await capture("library")
	if not await click("ReturnTable"): return
	if not await click("Menu"): return
	if not await click("Settings"): return
	if not await click("TextSize"): return
	if not await click("Return"): return
	if not await click("Return"): return
	if not await inspect_hud(): return
	await capture("large")
	if not await inspect_resource_widths(): return
	if not await click("PhaseAction"): return
	if not await click("ConfirmEnd"): return
	if not require(int(app.projection.turn)>1,"Confirmed next turn did not advance Session"): return
	await capture("next-round")
	print("HUD_OK: formal default; standard/large; consistent type hierarchy; resource gaps; one/three-digit geometry; overview/world/library; responsibility read-only; cancel; actual next turn.")
	quit()

func inspect_hud() -> bool:
	var top: Control = app._stage.find_child("Top",true,false)
	for label: Label in top.find_children("*","Label",true,false)+app._persistent_dock.find_children("*","Label",true,false):
		var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		if not require(width <= label.size.x+.5,"HUD text clipped: "+label.name+" "+str(width)+"/"+str(label.size.x)): return false
	if not require(top.find_child("WhisperAmount",true,false)==null,"Whispers stayed at top"): return false
	if not require(app._persistent_dock.find_child("DockShade",true,false)==null,"Flat dock background remains"): return false
	var history: Button = app._persistent_dock.get_node("History")
	var responsibilities: Button = app._persistent_dock.get_node("RoundResponsibilities")
	var next: Button = app._persistent_dock.get_node("PhaseAction")
	if not require(history.position.x < responsibilities.position.x and responsibilities.position.x < next.position.x,"Incorrect footer order"): return false
	if is_instance_valid(app._hand) and not require(app._persistent_dock.position.y >= app._hand.position.y+app._hand.size.y-1.,"HUD encroaches on the hand"): return false
	for key: String in ["Awakening", "Faith"]:
		var caption: Label = top.get_node(key+"Caption")
		var value: Label = top.get_node(key+"Amount")
		if not require(is_equal_approx(value.position.x-caption.position.x-caption.size.x,8.),key+" label/value gap changed"): return false
		if not require(caption.get_theme_font_size("font_size")==16+app._size(0) and value.get_theme_font_size("font_size")==24+app._size(0),key+" resource hierarchy changed"): return false
	var whispers: Label = app._persistent_dock.get_node("WhisperAmount")
	var whisper_caption: Label = app._persistent_dock.get_node("WhisperCaption")
	var flame: Control = app._persistent_dock.get_node("Pigment_whispers")
	if not require(is_equal_approx(whispers.position.x-whisper_caption.position.x-whisper_caption.size.x,8.) and is_equal_approx(flame.position.x-whispers.position.x-whispers.size.x,10.),"Whisper group separated again"): return false
	if not require(whispers.get_theme_font_size("font_size")==top.get_node("FaithAmount").get_theme_font_size("font_size"),"Resource sizes diverged"): return false
	for button: Button in app._persistent_dock.find_children("*","Button",true,false):
		if button.name=="PhaseAction": continue
		if not require(button.get_theme_font_size("font_size")==14+app._size(0),"Auxiliary navigation type mismatch"): return false
	var path: Control = app._stage.find_child("ContextPath",true,false)
	if path != null:
		for label: Control in path.get_children():
			if not require(label.get_theme_font_size("font_size")==14+app._size(0),"Breadcrumb hierarchy mismatch"): return false
	return true

func inspect_resource_widths() -> bool:
	# Layout-only fixtures, never captured or written into Session. Restore the
	# public projection immediately; this does not claim gameplay reached 100.
	var original: Dictionary = app.projection.duplicate(true)
	for fixture: Array in [[0,0,0],[9,9,1],[99,160,6],[100,160,6]]:
		app.projection.awakening = fixture[0]
		app.projection.faith = fixture[1]
		app.projection.whispers = fixture[2]
		var top: Node = app._stage.get_node("Top")
		app._stage.remove_child(top)
		top.queue_free()
		app._build_top()
		app._build_dock()
		if not await inspect_hud(): return false
	app.projection = original
	app._hud.reset()
	app._refresh()
	await process_frame
	return true
