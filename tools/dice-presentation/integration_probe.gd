extends SceneTree
## Production scene + actual Session submissions. All saves live in an isolated
## directory. Historical saves below exercise frozen-prayer and final-manifest
## compatibility only; neither the RNG nor any check result is overridden.
const Production = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app: Control
var game: Node
var checks := 0
var seen: Array = []
var returned := 0
var home := ""

func _initialize() -> void:
	run.call_deferred()

func need(condition: bool, message: String) -> bool:
	checks += 1
	if condition: return true
	push_error("DICE_INTEGRATION: " + message)
	quit(1)
	return false

func settle_frames(count := 3) -> void:
	for index: int in count: await process_frame

func wait_art() -> bool:
	var deadline := Time.get_ticks_msec()+180000
	while app._portraits.preparing and Time.get_ticks_msec()<deadline:
		await process_frame
	await settle_frames()
	return need(not app._portraits.preparing,"portrait preparation deadline")

func mount(save := "") -> bool:
	if is_instance_valid(game):
		game.free()
		await settle_frames()
	game = Production.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	var directory := home.path_join(str(Time.get_ticks_usec()))
	app.session = Session.new(directory)
	app.display_settings_path = directory.path_join("display.cfg")
	seen.clear()
	app.session.checks_committed.connect(func(receipt: Dictionary): seen.append(receipt.duplicate(true)))
	root.add_child(game)
	if save.is_empty(): app._start_new(1)
	else:
		DirAccess.make_dir_recursive_absolute(directory)
		var copy := directory.path_join("fixture.json")
		if not need(DirAccess.copy_absolute(ProjectSettings.globalize_path(save),copy)==OK,"copy historical fixture"): return false
		app._load_saved(copy)
	if not await wait_art(): return false
	if app._arrival.visible:
		app._arrival.close()
		await settle_frames()
	if not await wait_art(): return false
	return need(app.projection.get("active",false) and app.projection.phase=="actions","mount enters real action phase: "+str(app.projection.get("phase")))

func candidate(space := true) -> Dictionary:
	for prayer: Dictionary in app.projection.prayers:
		if bool(prayer.descriptor.get("space",false)) != space: continue
		for choice: Dictionary in app.session.prayer_response_choices(prayer.id):
			if app.session.preview_action(choice.key).get("ok",false): return {"prayer":prayer,"choice":choice}
	return {}

func press(id: String) -> bool:
	var button: Button = app.find_child(id,true,false)
	if not need(button!=null and not button.disabled,"enabled control "+id): return false
	button.pressed.emit()
	return true

func dice_matches() -> bool:
	if not need(app._dice_active() and app._dice.layer==30,"committed check owns dice layer"): return false
	var real: Array = []
	for response: Dictionary in seen: real.append_array(response.result.checks)
	if not need(app._dice._entries.size()==real.size(),"no omitted or duplicated check"): return false
	for index: int in real.size():
		var entry: Dictionary = app._dice._entries[index]
		var batch: Dictionary = app._dice._batches[entry.batch]
		var presented: Dictionary = batch.checks[entry.check]
		if not need(presented.roll==real[index].roll and presented.target==real[index].probability and presented.outcome==real[index].outcome,"presenter equals committed check "+str(index)): return false
	return need(not app._stage.visible and (not is_instance_valid(app._surface) or not app._surface.visible) and (not is_instance_valid(app._persistent_dock) or not app._persistent_dock.visible),"rebuilt content stays below dice")

func finish_dice() -> bool:
	var snapshot: String = app.session.turn.snapshot()
	var sequence: int = app.session.turn.commit_sequence
	var deadline := Time.get_ticks_msec()+12000
	while app._dice_active() and Time.get_ticks_msec()<deadline:
		if not app._dice._revealed:
			app._dice._advance()
			while app._dice_active() and not app._dice._revealed and Time.get_ticks_msec()<deadline: await process_frame
		else: app._dice._advance()
		await process_frame
	if not need(not app._dice_active(),"all committed dice can finish"): return false
	if not need(app.session.turn.snapshot()==snapshot and app.session.turn.commit_sequence==sequence,"performance never writes or rerolls"): return false
	await settle_frames()
	return true

func board_prayer() -> bool:
	if not await mount(): return false
	var chosen := candidate()
	if not need(not chosen.is_empty(),"natural generated prayer candidate"): return false
	app._select_world(str(chosen.prayer.descriptor.domain))
	await settle_frames()
	var selected: Dictionary = {}
	for card: Dictionary in app._deck:
		if card.id=="prayer/"+str(chosen.prayer.id): selected=card; break
	if not need(not selected.is_empty(),"generated prayer in actual deck"): return false
	app._play_card(selected)
	app._choose_inline({"key":"__prayer"},str(chosen.choice.key))
	var sequence: int = app.session.turn.commit_sequence
	app._execute()
	if app._confirmed and not app._dice_active(): app._execute()
	if not need(app.session.turn.commit_sequence==sequence+1 and seen.size()==1,"board submission commits once"): return false
	if not dice_matches(): return false
	app._execute()
	app._advance(true)
	if not need(app.session.turn.commit_sequence==sequence+1,"dice blocks repeat submit and round advance"): return false
	if not await finish_dice(): return false
	if not need(app._played.is_empty() and app._result_text.is_empty() and app._dice_return.is_null(),"board returns directly without second receipt"): return false
	print("DICE_PATH_OK board_generated_prayer")
	return true

func modern_overlay() -> bool:
	if not await mount(): return false
	var chosen := candidate()
	if not need(not chosen.is_empty(),"overlay generated prayer candidate"): return false
	app._prayers.browse(str(chosen.prayer.descriptor.domain))
	if not press("IntroPrayer_"+str(chosen.prayer.id)): return false
	if not press("SpaceChoice_"+str(chosen.choice.id)): return false
	var sequence: int = app.session.turn.commit_sequence
	if not press("Respond"): return false
	if app._dialog=="prayer_confirm":
		if not press("ConfirmPrayer"): return false
	if not need(app.session.turn.commit_sequence==sequence+1 and seen.size()==1,"modern overlay submits once"): return false
	if not dice_matches(): return false
	if not await finish_dice(): return false
	if not need(app._dialog=="prayer_intro" and app._dice_return.is_null(),"modern overlay returns once to its list"): return false
	print("DICE_PATH_OK modern_prayer_overlay")
	return true

func task_power() -> bool:
	if not await mount(): return false
	returned = 0
	var domain: String = str(app.projection.domains[0].id)
	var person: String = str(app.projection.people[0].id)
	app._tasks.open_action("POWER_DREAM",{"domain":domain,"npc":person},func():
		returned += 1
		app._close_surface())
	var selection: Dictionary = app._tasks.draft.selection.duplicate(true)
	var preview: Dictionary = app.session.preview_action("POWER_DREAM",selection)
	if not need(preview.get("ok",false),"real dream preview: "+str(preview)): return false
	var sequence: int = app.session.turn.commit_sequence
	if not press("ExecuteDraft"): return false
	if app._dialog=="task_confirm":
		if not press("ConfirmAction"): return false
	if not need(app.session.turn.commit_sequence==sequence+1 and seen.size()==1,"task power commits once"): return false
	if not dice_matches(): return false
	app._tasks.run_action("POWER_DREAM",selection)
	if not need(app.session.turn.commit_sequence==sequence+1,"task cannot resubmit during dice"): return false
	if not await finish_dice(): return false
	if not need(returned==1 and app._dialog.is_empty() and app._dice_return.is_null(),"task follows its real return exactly once"): return false
	app._dice_finished()
	if not need(returned==1,"return continuation is consumed"): return false
	print("DICE_PATH_OK task_power")
	return true

func legacy_overlay() -> bool:
	if not await mount("res://docs/qa/ui-manifest/saves/local-contacts-five-worlds.json"): return false
	var chosen := candidate(false)
	if not need(not chosen.is_empty(),"historical fixture retains executable frozen prayer"): return false
	app._prayers.browse(str(chosen.prayer.descriptor.domain))
	if not press("IntroPrayer_"+str(chosen.prayer.id)): return false
	if not press("Mode_"+str(chosen.choice.id)): return false
	var sequence: int = app.session.turn.commit_sequence
	var row: Dictionary = app._prayers._row()
	if not press("Respond"): return false
	if app._dialog=="prayer_confirm":
		if not press("ConfirmPrayer"): return false
	if not need(app.session.turn.commit_sequence==sequence+1 and seen.size()==1,"frozen prayer commits once"): return false
	if not dice_matches(): return false
	app._prayers._respond(row,{},false)
	if not need(app.session.turn.commit_sequence==sequence+1,"frozen prayer cannot resubmit during dice"): return false
	if not await finish_dice(): return false
	if not need(app._dialog=="prayer_intro" and app._dice_return.is_null(),"frozen prayer returns once to its list"): return false
	print("DICE_PATH_OK frozen_prayer_overlay")
	return true

func final_manifestation() -> bool:
	if not await mount("res://docs/qa/ui-manifest/saves/continued.json"): return false
	app._advance(true)
	if not await wait_art(): return false
	if app._arrival.visible: app._arrival.close()
	await settle_frames()
	if not need(not app._dice_active() and seen.is_empty(),"intermediate manifestation turn does not invent dice"): return false
	app._close_surface()
	app._tasks.open_action("POWER_MANIFEST_CONTINUE")
	var selection: Dictionary = app._tasks.draft.selection.duplicate(true)
	var prepared: Dictionary = app.session.preview_action("POWER_MANIFEST_CONTINUE",selection)
	if not need(prepared.get("ok",false) and int(prepared.preview.get("probability",-1))>=0,"historical fixture reaches real final payment: "+str(prepared)): return false
	if not press("ExecuteDraft") or not press("ConfirmAction"): return false
	if not need(not app._dice_active() and seen.is_empty(),"final payment locks check without premature dice"): return false
	app._close_surface()
	app._advance(true)
	if not need(seen.size()==1 and app._dice_boundary_pending,"final phase check defers boundary"): return false
	if not dice_matches(): return false
	if not need(not app._arrival.visible and app._dialog!="task_subject","arrival and terminal screen do not steal performance"): return false
	if not need(app._receipt_checks.size()==1 and app._receipt_checks[0]==seen[0].result.checks[0],"round aggregate retains actual check"): return false
	var snapshot: String = app.session.turn.snapshot()
	app._advance(true)
	if not need(app.session.turn.snapshot()==snapshot,"round end cannot double advance during dice"): return false
	if not await finish_dice(): return false
	if not await wait_art(): return false
	if app._arrival.visible:
		app._arrival.close()
		await settle_frames()
	if app.projection.phase=="ended":
		if not need(app._dialog=="task_subject" and app._tasks._subject.get("kind")=="ending","terminal screen follows settled final die: "+app._dialog+" / "+str(app._tasks._subject)): return false
	else:
		if not need(app.projection.phase in ["actions","events"] and app._dialog.is_empty(),"nonterminal failed ritual returns to next round"): return false
	print("DICE_PATH_OK final_manifestation phase=",app.projection.phase," check=",seen[0].result.checks[0])
	return true

func deterministic_event() -> bool:
	if not await mount(): return false
	for index: int in 8:
		if app._event_table(): break
		app._advance(true)
		if not await wait_art(): return false
		if app._arrival.visible:
			app._arrival.close()
			await settle_frames()
	if not need(app._event_table(),"natural event within eight ordinary turns"): return false
	var event: Dictionary = app._pending_events().back()
	for card: Dictionary in app._deck:
		if card.id==event.key:
			app._play_card(card)
			break
	if not press("Option_"+str(event.descriptor.default_action)): return false
	var sequence: int = app.session.turn.commit_sequence
	if not press("ConfirmEvent"): return false
	if not need(app.session.turn.commit_sequence>sequence,"event handler really committed"): return false
	if not need(seen.is_empty() and not app._dice_active() and app._receipt_checks.is_empty(),"deterministic event and round stages never invent dice"): return false
	if not await wait_art(): return false
	print("DICE_PATH_OK deterministic_event turn=",app.projection.turn)
	return true

func run() -> void:
	home = ProjectSettings.globalize_path("user://dice-integration-probe/%d" % Time.get_ticks_usec())
	root.size = Vector2i(1280,720)
	var cases := OS.get_cmdline_user_args()
	if (cases.is_empty() or "board" in cases) and not await board_prayer(): return
	if (cases.is_empty() or "modern" in cases) and not await modern_overlay(): return
	if (cases.is_empty() or "task" in cases) and not await task_power(): return
	if (cases.is_empty() or "legacy" in cases) and not await legacy_overlay(): return
	if (cases.is_empty() or "manifest" in cases) and not await final_manifestation(): return
	if (cases.is_empty() or "event" in cases) and not await deterministic_event(): return
	print("DICE_INTEGRATION_OK ",checks)
	game.free()
	quit()
