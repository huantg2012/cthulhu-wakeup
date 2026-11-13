extends "res://tools/ui-art-production/scene_probe.gd"
## Formal entry, isolated real Sessions. No production save or gameplay rule mutation.
var checks := 0
var auto_arrivals := true
func require(ok: bool, detail: String) -> bool:
	checks += 1
	return super.require(ok, detail)

func click(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 180000
	while app._portraits.preparing and Time.get_ticks_msec() < deadline: await process_frame
	if not require(not app._portraits.preparing, "Portrait preparation timed out before " + path): return false
	if auto_arrivals and app._arrival.visible: await press_key(KEY_ENTER)
	await process_frame
	var scope: Control = app._surface if is_instance_valid(app._surface) else app
	var control := scope.find_child(path,true,false) as Button
	if not require(control != null and not control.disabled and control.is_visible_in_tree(),"Unavailable: "+path+" dialog="+app._dialog): return false
	await ensure_button(control)
	control.grab_focus()
	await press_key(KEY_ENTER)
	if auto_arrivals:
		while app._portraits.preparing and Time.get_ticks_msec() < deadline: await process_frame
		await process_frame
		if app._arrival.visible: await press_key(KEY_ENTER)
	return true

func pointer_button(at: Vector2, down: bool) -> void:
	var input := InputEventMouseButton.new()
	input.position = at
	input.global_position = at
	input.button_index = MOUSE_BUTTON_LEFT
	input.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	input.pressed = down
	root.push_input(input,true)
	await process_frame

func pointer_move(at: Vector2, from: Vector2, held := false) -> void:
	var input := InputEventMouseMotion.new()
	input.position = at
	input.global_position = at
	input.relative = at - from
	input.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(input,true)
	await process_frame

func card_index(id: String) -> int:
	for i: int in app._hand_cards.size():
		if app._hand_cards[i].id == id: return i
	return -1

func card_point(index: int) -> Vector2:
	app._fan.set_focus(index,false)
	var card: Control = app._fan.cards[index]
	# The card to the right owns the covered face; hit the exposed left edge.
	var gap: float = app._fan.cards[index+1].position.x-card.position.x if index < app._fan.cards.size()-1 else card.size.x
	return app._fan.get_global_transform_with_canvas() * Vector2(card.position.x+minf(gap*.5,13.0),140.0)

func drag_card(index: int) -> bool:
	await process_frame
	var at := card_point(index)
	var target: Vector2 = app._table.get_global_transform_with_canvas() * (app._table.size * 0.5)
	var away := Vector2(20,20)
	await pointer_move(away,at)
	await pointer_move(at,away)
	await pointer_button(at,true)
	var lift := at + Vector2(0,-42)
	await pointer_move(lift,at,true)
	await pointer_move(target,lift,true)
	var dragged := root.gui_is_dragging()
	await pointer_button(target,false)
	return dragged

func play(id: String) -> bool:
	if auto_arrivals and app._arrival.visible:
		await press_key(KEY_ESCAPE)
		await process_frame
	var index := card_index(id)
	if not require(index >= 0, "Missing hand card: "+id): return false
	if not require(await drag_card(index), "Native drag did not start: "+id): return false
	if app._dialog == "event":
		return require(app._current_event().key == id, "Wrong event opened: "+id)
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
	var current_save := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--current-save="): current_save = arg.trim_prefix("--current-save=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not current_save.is_empty():
		await verify_current_save(current_save)
		return
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
	if not require(approaches.size()>=2 and options.size()==largest and not options.any(func(o: Dictionary)->bool:return str(o.id).ends_with("/shallow") or str(o.id).ends_with("/deep") or str(o.id).ends_with("/dismiss")),"Generated options were not passed through"): return
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
	if not await play("record/POWER_DREAM"): return
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
	for request: Dictionary in app.projection.prayers:
		if request.status != "open" or request.descriptor.get("space",false) or request.descriptor.domain != "DOMAIN-001": continue
		if not await play(str(request.key)): return
		var story: Label = app._table.find_child("PrayerStory",true,false)
		var quote: String = app.session.prayer_appeal(request.descriptor,request.card)
		if not require(story != null and not quote.is_empty() and quote in story.text, "Legacy request lost its displayed appeal"): return
		app._recall()
		break
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
			if not require(app._event_table() and app._persistent_dock.get_node("People").disabled,"Event boundary can be bypassed"): return
			app._close_surface()
		if app.projection.phase=="actions" and app.projection.turn>turn: break
	if not require(app.projection.phase=="actions" and app.projection.turn>turn,"Next turn not reached"): return
	print("WORLDPLAY_FORMAL_OK ",checks," checks; fresh dynamic prayer committed, new save replayed, mature save/cult/catalog/modal/turn verified")
	quit()


func verify_current_save(path: String) -> void:
	if not await setup(PackedStringArray(["--save="+path])): return
	var fan: Control = app.find_child("WorldFan",true,false)
	if not require(fan.cards.size()==5 and app.session.known_domains().size()==5 and not app.projection.cults.is_empty(), "Expected five full worlds and a cult"): return
	fan.set_focus(4,false)
	await art_capture("world-card-at-rest")
	var front: Control = fan.cards[4]
	var world_at: Vector2 = front.get_global_transform_with_canvas() * (front.size * 0.5)
	await pointer_move(Vector2(20,20),world_at)
	await pointer_move(world_at,Vector2(20,20))
	var peak := 1.0
	var hover_until := Time.get_ticks_msec() + 320
	while Time.get_ticks_msec() < hover_until:
		peak = maxf(peak,front.scale.x)
		await process_frame
	if not require(peak > 1.014 and front.self_modulate.r > 1.0, "Stacked world card did not overshoot or brighten: %.4f, %.4f" % [peak, front.self_modulate.r]): return
	if not require(is_equal_approx(front.scale.x,1.014) and fan.focus_index==4, "World card did not settle or hover moved focus"): return
	await pointer_move(Vector2(20,20),world_at)
	await create_timer(0.18).timeout
	if not require(front.scale.is_equal_approx(Vector2.ONE) and front.self_modulate.is_equal_approx(Color.WHITE), "World card did not return to rest"): return
	var active: Dictionary = {}
	var ledger: Dictionary = app.session.world.state.prayer_system.space
	for prayer: Dictionary in app.projection.prayers:
		var frozen: Dictionary = ledger.scenes.get(prayer.id,{})
		if int(frozen.get("schema",0)) != 2 or str(frozen.get("appeal","")).is_empty(): continue
		if app.session.prayer_response_choices(prayer.id).any(func(c: Dictionary) -> bool: return app.session.preview_action(c.key).ok):
			active = prayer
			break
	if not require(not active.is_empty(), "No executable composed prayer in the new save"): return
	if not await world(active.descriptor.domain): return
	var last_group := -1
	var groups := ["event","cult","power","activity","person","anchor","action","relic"]
	for item: Dictionary in app._deck:
		var index: int = groups.find(app._category_of(item))
		if not require(index >= last_group, "Cards are not grouped in the requested order"): return
		last_group = index
	if not require(not app._hand.has_node("Pile_object") and not app._hand.has_node("Pile_prayer"), "Unexpected group tabs"): return
	var unlocked := card_index("POWER_DREAM")
	if not require(card_index("POWER_MANIFEST") == -1 and card_index("POWER_BESTOW") == -1 and unlocked >= 0, "Power admission disagrees with awakening"): return
	for item: Dictionary in app._deck:
		if item.group != "power": continue
		if not require(int(app.projection.awakening) >= int(app.session.catalog.display_tables.powers[item.id].unlock_awakening), "Locked power in deck: " + item.id): return
	await art_capture("selected-hand")
	if not await click("PowerIndex"): return
	if not require(card_index("record/POWER_MANIFEST") == -1 and card_index("record/POWER_DREAM") >= 0, "Locked card appeared in the archive pile"): return
	if not require(app._table.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "降临  90"), "Locked threshold missing from read-only notes"): return
	await press_key(KEY_ESCAPE)
	unlocked = card_index("POWER_DREAM")
	var at := card_point(unlocked)
	await pointer_move(at,at)
	await create_timer(0.14).timeout
	if not require(app._fan.cards[unlocked].scale.x>1.0, "Hand card did not lift on hover"): return
	await pointer_button(at,true)
	await pointer_button(at,false)
	await press_key(KEY_ENTER)
	if not require(app._played.is_empty(), "Click or keyboard placed a card"): return
	if not await play("POWER_DREAM"): return
	if not require(app._table.has_node("Execute") and app._table.get_node("Execute").disabled,"Incomplete unlocked power should open a disabled draft"): return
	app._recall()
	if not await play("POWER_APPOINT"): return
	var filled := app._table.get_node_or_null("Slot_npc") as Button
	if filled != null and filled.accessibility_description.begins_with("空槽"):
		if app._picker != "npc" and not await click("Slot_npc"): return
		if not await click("Choice_npc_0"): return
		filled = app._table.get_node_or_null("Slot_npc") as Button
	var empty := app._table.get_node_or_null("Slot_source") as Button
	if not require(filled != null and filled.accessibility_description.begins_with("已填入") and empty != null and empty.accessibility_description.begins_with("空槽"), "Appointment did not show distinct filled and empty slot states: " + str(app._selection) + "; " + str(app._fields().map(func(field: Dictionary) -> String: return "%s:%s" % [field.key, field.options.size()]))): return
	if not require(filled.get_theme_stylebox("normal").texture != empty.get_theme_stylebox("normal").texture, "Slot stock was identical in both states"): return
	await art_capture("appointment-slots")
	if app._picker != "role" and not await click("Slot_role"): return
	if not await click("Choice_role_0"): return
	if not require(app._table.get_node("Slot_role").accessibility_description.begins_with("已填入"), "Selected role did not update slot state"): return
	app._recall()
	if not await play(str(active.key)): return
	var prayer_story: Label = app._table.find_child("PrayerStory",true,false)
	if not require(prayer_story != null and str(ledger.scenes[active.id].appeal) in prayer_story.text, "Prayer story does not come from the generated request"): return
	var options: Array = app._prayer_options()
	var expected: Array = app.session.prayer_response_choices(active.id)
	if not require(options.size()==expected.size() and not options.is_empty(), "Prayer picker diverges from the contract"): return
	for i: int in options.size():
		if not require(options[i].id==expected[i].key and str(expected[i].label) in options[i].label,"Wrong response identity or copy"): return
	await art_capture("five-world-prayer")
	var chosen := 0
	while not app.session.preview_action(options[chosen].id).ok: chosen += 1
	if not await click("Choice___prayer_"+str(chosen)): return
	var before: int = app.session.turn.commit_sequence
	if not await click("Execute"): return
	if app._confirmed and app._result_text.is_empty():
		if not await click("Execute"): return
	if not require(app.session.turn.commit_sequence==before+1 and app.projection.prayer_response_spent and app._result_text.begins_with("已施行"), "Response did not commit through Session"): return
	print("FIVE_WORLD_DETAILS_OK ",checks," checks; actual generated prayer ",active.title," from ",active.descriptor.domain)
	quit()
