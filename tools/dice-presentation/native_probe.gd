extends "res://tools/worldplay-integration/probe.gd"
## Native formal card-table flow, using a genuinely generated prayer and its
## unmodified committed die. Optional frame recording is presentation evidence.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "/tmp/dice-native"
	var seed_value := args[1] if args.size()>1 else "5"
	var recording := "--record" in args
	DirAccess.make_dir_recursive_absolute(output)
	if recording: DirAccess.make_dir_recursive_absolute(output+"/frames")
	if not await setup(PackedStringArray(["--seed="+seed_value])): return
	var prayer: Dictionary = {}
	var choice := -1
	var most := 0
	for item: Dictionary in app.projection.prayers:
		var options: Array = app.session.prayer_response_choices(item.id)
		for index: int in options.size():
			if options.size()>most and app.session.preview_action(options[index].key).get("ok",false):
				prayer = item; choice = index; most = options.size()
				break
	if not require(not prayer.is_empty(),"No executable generated prayer"): return
	if not await world(str(prayer.descriptor.domain)): return
	if not await play("prayer/"+str(prayer.id)): return
	while app._picker_page<int(choice/5):
		if not await click("OptionsNext"): return
	if not await click("Choice___prayer_"+str(choice)): return
	await capture("before")
	var sequence: int = app.session.turn.commit_sequence
	app._table.get_node("Execute").grab_focus()
	await press_key(KEY_ENTER)
	if app._confirmed and app._result_text.is_empty(): await press_key(KEY_ENTER)
	if not require(app._dice.is_active() and app.session.turn.commit_sequence==sequence+1,"Execution did not enter shared dice once"): return
	var committed: String = app.session.turn.snapshot()
	var pair: Control = app._dice._dice_pair
	var frame := 0
	var captured_motion := false
	var captured_settle := false
	while pair.rolling or frame<(85 if recording else 5):
		await process_frame
		await RenderingServer.frame_post_draw
		if recording:
			root.get_texture().get_image().save_png(output+"/frames/%04d.png" % frame)
		if pair.elapsed>=.65 and not captured_motion:
			root.get_texture().get_image().save_png(output+"/rolling.png")
			captured_motion = true
			if "--accelerate" in args:
				await press_key(KEY_ESCAPE)
				if not require(app._dice.is_active() and app.session.turn.snapshot()==committed,"Acceleration cancelled/replayed committed action"): return
		if not pair.rolling and not captured_settle:
			captured_settle = true
			await capture("landed")
		frame += 1
		if frame>300: break
	if not require(app._dice._revealed and not pair.rolling,"Dice failed to settle"): return
	await capture("result")
	var check: Dictionary = app.session.turn._checks[0]
	var shown: Dictionary = app._dice._batches[0].checks[0]
	if not require(shown.roll==check.roll and shown.target==check.probability and pair.value==check.roll,"Performance differs from actual committed die"): return
	if not require(app._dice._total.text=="%02d 点" % check.roll,"Final points hidden or incorrect"): return
	if not require(not app._arrival.visible and not app._stage.visible and not app._persistent_dock.visible,"Underlying interactive scene visible during resolution"): return
	app._execute()
	app._phase_intent()
	if not require(app.session.turn.snapshot()==committed,"Blocked controls replayed or advanced the action"): return
	await press_key(KEY_ESCAPE)
	if not require(not app._dice.is_active() and app._played.is_empty() and app._stage.visible and app._persistent_dock.visible,"Result exit repeated receipt or left scene hidden"): return
	if not require(app.session.turn.snapshot()==committed,"Closing dice changed the committed world"): return
	await capture("returned")
	print("DICE_NATIVE_OK ",checks," seed=",seed_value," roll=",check.roll," target=",check.probability," outcome=",check.outcome," recorded=",recording)
	quit()
