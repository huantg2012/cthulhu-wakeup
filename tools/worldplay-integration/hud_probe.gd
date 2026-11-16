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
	output = "res://docs/art/visual-generation/hud-study/evidence/unique-entries"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await setup([]): return
	if not require(app._hud != null,"Formal entry did not build selected HUD"): return
	if not await inspect_hud(): return
	await capture("overview")
	var id: String = app.projection.domains[0].id
	if not await world(id): return
	await create_timer(.4).timeout
	await capture("world")
	var next_button: Control = app._persistent_dock.get_node("PhaseAction")
	var point: Vector2 = next_button.get_global_transform_with_canvas()*(next_button.size*.5)
	await pointer_move(point,Vector2.ZERO)
	await create_timer(.35).timeout
	await capture("next-hover")
	await pointer_move(Vector2(900,500),point)
	await create_timer(.35).timeout
	if not await inspect_hud(): return
	if "--live" in OS.get_cmdline_user_args():
		print("HUD_READY: selected production HUD; isolated real Session.")
		return
	var snapshot: String = app.session.turn.snapshot()
	for route: Array in [["Faith","budget"],["AwakeningReadout","self"]]:
		if not await click(route[0]): return
		if not require(app._dialog=="task_subject" and app._tasks._subject.get("kind")==route[1],"Wrong subject from top entry: "+route[0]): return
		await press_key(KEY_ESCAPE)
		if not require(app._dialog.is_empty() and app._world_id==id and app.session.turn.snapshot()==snapshot,"Top entry did not return to the same world"): return
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
	if not await inspect_action_width("action"): return
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
	if not await inspect_action_width("action-large"): return
	if not await inspect_resource_widths(): return
	if not await click("PhaseAction"): return
	if not await click("ConfirmEnd"): return
	if not require(int(app.projection.turn)>1,"Confirmed next turn did not advance Session"): return
	await capture("next-round")
	print("HUD_OK: formal default; standard/large; consistent type hierarchy; footer centers and inner clearance; resource gaps; one/three-digit geometry; overview/world/library; responsibility read-only; cancel; actual next turn.")
	quit()

func inspect_hud() -> bool:
	var top: Control = app._stage.find_child("Top",true,false)
	var faith_value: Control = top.get_node("FaithAmount")
	if not require(absf(faith_value.position.x+faith_value.size.x-1274.)<.5,"Top resource retains right gutter"): return false
	if not require(top.get_node("Pigment_epoch").position.x==6. and top.get_node("Menu").position.x+top.get_node("Menu").size.x==1274.,"Header edges diverged"): return false
	if is_instance_valid(app._hand) and app._hand.is_inside_tree():
		if not require(app._master.position.x==6. and app._table.position.x==272. and app._table.size.x==1002.,"Main area retains page gutters"): return false
		if not require(app._hand.position.x==app._table.position.x and app._hand.size.x==app._table.size.x and app._fan.size.x==app._hand.size.x,"Hand failed to use reclaimed width"): return false
		var search: Control = app._hand.get_node("FindCard")
		if not require(search.position.x+search.size.x==app._hand.size.x,"Search isn't right-anchored"): return false
	var rim: Control = app._stage.get_node("UpperRim")
	if not require(rim.get_index()==0 and rim.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Top carrier hides or blocks the context path"): return false
	var lower: Control = app._persistent_dock.get_node("LowerRim")
	if not require(lower.get_index()==0 and lower.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Bottom carrier blocks navigation"): return false
	var turn_button: Control = app._persistent_dock.get_node("PhaseAction")
	if not require(turn_button.position.y>=0 and turn_button.position.y+turn_button.size.y<=app._persistent_dock.size.y,"Next-turn protrudes from its carrier"): return false
	var dock: Control = app._persistent_dock
	if not require(dock.position.x==0. and dock.size.x==1280. and lower.position.x==0. and lower.size.x==1280.,"Footer retains page gutters"): return false
	var right_gap := dock.size.x-turn_button.position.x-turn_button.size.x
	if not require(is_equal_approx(right_gap,6.) and is_equal_approx(dock.get_node("PowerIndex").position.x,6.),"Footer edge gap changed"): return false
	if not require(is_equal_approx(lower.position.y,0.) and is_equal_approx(lower.size.y,dock.size.y) and is_equal_approx(dock.position.y+dock.size.y,720.),"Footer carrier and layout disagree"): return false
	# All groups share the visible body's center below the six-pixel worn lip.
	var center := (6.+dock.size.y)*.5
	for key: String in ["PowerIndex","RelicIndex","People","History","RoundResponsibilities","WhisperInfo","WhisperCaption","WhisperAmount","Pigment_whispers","PhaseAction","Pigment_turn"]:
		var item: Control = dock.get_node(key)
		if not require(absf(item.position.y+item.size.y*.5-center)<=.5,"Footer group off-center: "+key): return false
	var next_caption: Control = turn_button.get_node("NextTurnCaption")
	if not require(absf(next_caption.position.y+next_caption.size.y*.5-turn_button.size.y*.5)<=.5,"Next-turn caption off-center"): return false
	var top_clearance := turn_button.position.y-6.
	var bottom_clearance := dock.size.y-turn_button.position.y-turn_button.size.y
	if not require(top_clearance>=5. and absf(top_clearance-bottom_clearance)<=1.,"Next-turn clearance is unbalanced"): return false

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
		if not require(path.position.x==6.,"Context path retains left gutter"): return false
		if not require(path.global_position.y>=rim.global_position.y+rim.size.y,"Context navigation belongs below the global header"): return false
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

func inspect_action_width(label: String) -> bool:
	var action := ""
	for card: Dictionary in app._hand_cards:
		if card.get("group")=="power":
			action = str(card.id)
			break
	if not require(not action.is_empty(),"No action for execution-width review"): return false
	if not await play(action): return false
	await create_timer(.4).timeout
	for child: Node in app._table.get_children():
		if child is Control and child.visible:
			if not require(child.position.x>=0. and child.position.x+child.size.x<=app._table.size.x+.5,"Execution control exceeded full-width table: "+child.name): return false
	await capture(label)
	return await click("Recall")
