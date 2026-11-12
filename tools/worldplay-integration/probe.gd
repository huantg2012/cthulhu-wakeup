extends "res://tools/ui-art-production/scene_probe.gd"
## Formal entry, isolated real Sessions. No production save or gameplay rule mutation.
var checks := 0
func require(ok: bool, detail: String) -> bool:
	checks += 1
	return super.require(ok, detail)

func click(path: String) -> bool:
	await process_frame
	var scope: Control = app._surface if is_instance_valid(app._surface) else app
	var control := scope.find_child(path,true,false) as Button
	if not require(control != null and not control.disabled and control.is_visible_in_tree(),"Unavailable: "+path+" dialog="+app._dialog): return false
	await ensure_button(control)
	control.grab_focus()
	await press_key(KEY_ENTER)
	return true

func play(id: String) -> bool:
	var index := -1
	for i: int in app._hand_cards.size():
		if app._hand_cards[i].id == id: index = i; break
	if not require(index >= 0, "Missing hand card: "+id): return false
	app._fan.set_focus(index,false)
	app._fan.grab_focus()
	await press_key(KEY_ENTER)
	return require(app._played.get("id") == id, "Card didn't play: "+id)

func art_capture(label: String) -> void:
	var deadline := Time.get_ticks_msec()+60000
	while (app._portraits._running or not app._portraits._jobs.is_empty()) and Time.get_ticks_msec()<deadline:
		await process_frame
	if not require(not app._portraits._running and app._portraits._jobs.is_empty(), "Art delivery timed out"): return
	await capture(label)

func inspect_hand() -> bool:
	var fan: Control = app._fan
	for focus: float in [0.,.5,float(fan.cards.size()/2),float(fan.cards.size()-1)]:
		fan._visual_focus = focus
		fan._layout_cards()
		var reached := {}
		for x: int in int(fan.size.x*2):
			var i: int = fan._card_at(Vector2(x*.5,90))
			if i>=0: reached[i] = true
		for i: int in fan.cards.size():
			if not require(fan.cards[i].visible and fan.cards[i].modulate.a==1.0 and Rect2(Vector2.ZERO,fan.size).encloses(fan.cards[i].get_rect()) and reached.has(i), "Card hidden/off-table/unreachable: %d" % i): return false
	fan.set_focus(0,false)
	return true

func run() -> void:
	output = "res://docs/art/visual-generation/production-evidence/worldplay"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await setup([]): return
	if not require(app.get_script().resource_path.ends_with("production/worldplay/view.gd"),"Formal root didn't use card table"): return
	if not require(app._dialog.is_empty() and app._world_id.is_empty() and app._library.is_empty(),"Fresh game didn't start at overview"): return
	var prayer: Dictionary = {}
	var largest := 0
	for item: Dictionary in app.projection.prayers:
		var stored: Dictionary = app.session.world.state.prayer_system.space.scenes.get(str(item.id),{})
		var count: int = app.session.prayer_space_choices(str(item.id)).size()
		if item.status == "open" and stored.has("situation_id") and count > largest:
			prayer = item
			largest = count
	if not require(not prayer.is_empty(), "Fresh seed 1 has no compositional prayer"): return
	var domain: String = prayer.descriptor.domain
	if not await world(domain): return
	if not await play("prayer/"+str(prayer.id)): return
	var options: Array = app._prayer_options()
	var approaches := {}
	for option: Dictionary in options:
		if not str(option.approach).is_empty(): approaches[option.approach] = true
	if not require(approaches.size()>=2 and options.size()>2 and not options.any(func(o: Dictionary)->bool:return str(o.id).ends_with("/shallow") or str(o.id).ends_with("/deep")),"Generated options were not passed through"): return
	print("GENERATED_RESPONSES ",JSON.stringify(options.map(func(o: Dictionary)->String:return o.label)))
	await art_capture("new-game-prayer-choices")
	if "--capture-only" in OS.get_cmdline_user_args(): quit(); return
	var chosen := -1
	for i: int in options.size():
		if options[i].approach.is_empty(): continue
		var preview: Dictionary = app.session.preview_action(str(options[i].id))
		if preview.get("ok",false): chosen = i; break
	if not require(chosen>=0,"No affordable generated response for seed 1"): return
	var before: String = app.session.turn.snapshot()
	var sequence: int = app.session.turn.commit_sequence
	while app._picker_page<int(chosen/5):
		if not await click("OptionsNext"): return
	if not await click("Choice___prayer_"+str(chosen)): return
	if not require(app._entry==options[chosen].id and before==app.session.turn.snapshot(),"Selecting response mutated Session or wrong entry"): return
	var draft: Dictionary = app._selection.duplicate(true)
	var entry: String = app._entry
	if not await click("PowerIndex"): return
	if not await play("record/POWER_ANCHOR"): return
	app._execute()
	app._save_plan({})
	if not require(app._table.get_node_or_null("Execute")==null and before==app.session.turn.snapshot(),"Read-only catalog executed"): return
	if not await click("BackToTable"): return
	if not require(app._entry==entry and app._selection==draft and app._played.get("id")=="prayer/"+str(prayer.id),"Catalog lost draft"): return
	await art_capture("new-game-prayer-preview")
	if not await click("Execute"): return
	if app._confirmed and app._result_text.is_empty():
		if not require(sequence==app.session.turn.commit_sequence,"Confirmation paid before submit"): return
		if not await click("Execute"): return
	if not require(app._result_text.begins_with("已施行") and app.session.turn.commit_sequence==sequence+1 and app.projection.prayer_response_spent,"Actual response did not commit exactly once: "+app._result_text): return
	app._execute()
	if not require(app.session.turn.commit_sequence==sequence+1,"Receipt repeated execution"): return
	await capture("new-game-prayer-receipt")
	var saved: Dictionary = app.session.save_game()
	if not require(saved.get("ok",false),"Save failed: "+str(saved)): return
	var resumed := Session.new(app.session.save_directory)
	var restored: Dictionary = resumed.continue_game()
	if not require(restored.get("ok",false) and resumed.turn.snapshot()==app.session.turn.snapshot(),"New save replay lost state"): return
	# Copy the approved mature fixture; opening never writes its source file.
	var isolated := "user://worldplay-integration-old/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	var save := isolated.path_join("campaign.json")
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path("res://docs/qa/ui-manifest/saves/local-contacts-five-worlds.json"),ProjectSettings.globalize_path(save))==OK,"Fixture copy failed"): return
	app._open_library("person")
	app.session = Session.new(isolated)
	app._open_campaign(app.session.continue_game(save))
	if not require(app._library.is_empty() and app._played.is_empty() and app._world_id.is_empty() and app._scope_memory.is_empty(),"Campaign switch leaked table state"): return
	if not require(app.projection.domains.size()==5,"Five-world old save incompatible"): return
	if not await world("DOMAIN-001"): return
	if not inspect_hand(): return
	print("MATURE_SAVE_TABLE cards=",app._deck.size()," worlds=",app.projection.domains.size()," people=",app.projection.people.size())
	await art_capture("saved-world-table")
	if not await play("cult/CULT/DOMAIN-001"): return
	if not await click("EnterCult"): return
	if not require(app._study_cult=="CULT/DOMAIN-001" and app._master.get_meta("scope_id")=="cult/CULT/DOMAIN-001","Cult table identity mismatch"): return
	if not await play("order/CULT/DOMAIN-001/expand"): return
	sequence = app.session.turn.commit_sequence
	if not await click("Execute"): return
	if not require(app.session.turn.commit_sequence==sequence+1 and app.projection.economy_plan.strategies.get("CULT/DOMAIN-001")=="expand","Cult order did not register"): return
	await art_capture("saved-cult-table")
	if not await click("PhaseAction"): return
	if not require(app._dialog=="end" and app._persistent_dock.get_node("People").disabled,"Modal failed to block persistent dock"): return
	var old_card: Dictionary = app._played.duplicate(true)
	app._open_library("person")
	app._play_card(app._deck[0])
	if not require(app._dialog=="end" and app._library.is_empty() and app._played==old_card,"Modal was bypassed"): return
	await press_key(KEY_ESCAPE)
	if not require(app._dialog.is_empty() and not app._persistent_dock.get_node("People").disabled,"Dock stayed locked after modal"): return
	# Actual turn progression, then check that draft reconciliation reads the new state.
	var turn: int = app.projection.turn
	app._reset_draft()
	for step: int in 12:
		var progress: Dictionary = app.session.progress(true)
		if not require(progress.get("ok",false),"Progress failed: "+str(progress)): return
		app._refresh()
		if app.projection.phase=="events" and not app._pending_events().is_empty():
			app._enter_boundary()
			if not require(app._dialog=="event" and app._persistent_dock.get_node("People").disabled,"Event boundary can be bypassed"): return
			app._close_surface()
		if app.projection.phase=="actions" and app.projection.turn>turn: break
	if not require(app.projection.phase=="actions" and app.projection.turn>turn,"Next turn not reached"): return
	print("WORLDPLAY_FORMAL_OK ",checks," checks; fresh dynamic prayer committed, new save replayed, mature save/cult/catalog/modal/turn verified")
	quit()
