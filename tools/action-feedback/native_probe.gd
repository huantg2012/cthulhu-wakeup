extends "res://tools/worldplay-integration/probe.gd"
## Real new-game UI commits, no injected outcomes or edits to a production save.
func run() -> void:
	output = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/action-feedback-native"
	DirAccess.make_dir_recursive_absolute(output)
	var seed_value := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size()>1 else "1"
	if not await setup(PackedStringArray(["--seed="+seed_value])): return
	if not await world(str(app.projection.domains[0].id)): return
	if not await play("POWER_LISTEN"): return
	while not app._picker.is_empty():
		if not await click("Choice_"+app._picker+"_0"): return
	if not await click("Execute"): return
	if not require(not app._dice.is_active(),"Deterministic listen fabricated a die"): return
	var listen: Dictionary = app.session.last_result
	var words := JSON.stringify(app._result_rows)
	if not require(not listen.action_effects.revealed.is_empty() and "聆听所得" in words and "当时" in words and "察觉 +1" in words, "Listen omitted revealed record or actual exposure: "+words): return
	await pointer_move(Vector2(20,20),Vector2(20,20))
	await capture("listen-result")
	if not await click("Recall"): return
	if not await play("POWER_DREAM"): return
	# Listen can reveal additional people without giving each a dream contact.
	# Select the first actually executable public candidate through normal UI.
	var npc_index := -1
	for field: Dictionary in app.session.action_choices(app._entry,app._selection).fields:
		if field.key!="npc": continue
		for i: int in field.options.size():
			var selection: Dictionary = app._selection.duplicate(true)
			selection.npc=field.options[i].id
			for source_field: Dictionary in app.session.action_choices(app._entry,selection).fields:
				if source_field.key!="source": continue
				for source: Dictionary in source_field.options:
					selection.source=source.id
					if app.session.preview_action(app._entry,selection).get("ok",false): npc_index=i; break
			if npc_index>=0: break
	if not require(npc_index>=0,"No executable public dream target"): return
	if app._picker!="npc":
		if not await click("Slot_npc"): return
	while not app._picker.is_empty():
		var index := str(npc_index) if app._picker=="npc" else "0"
		if not await click("Choice_"+app._picker+"_"+index): return
	if not await click("Execute"): return
	if not require(app._dice.is_active(),"Dream did not enter shared dice"): return
	var settled: String = app.session.turn.snapshot()
	while app._dice._dice_pair.rolling: await process_frame
	await create_timer(.4).timeout
	var response: Dictionary = app.session.last_result
	var shown: Dictionary = app._dice._batches[0]
	words = JSON.stringify(shown.lines)
	if not require("理智" in words and "察觉" in words and not "此次检定已结算" in words,"Dream omitted actual changes: "+words): return
	if not require(shown.checks[0].roll==response.result.checks[0].roll,"Wrong committed die"): return
	await capture("dream-result")
	await press_key(KEY_ESCAPE)
	if not require(not app._dice.is_active() and app._played.is_empty() and app.session.turn.snapshot()==settled,"Result close repeated commit or receipt"): return
	var evidence := {"listen":listen.action_effects,"dream":response.action_effects,"check":response.result.checks,"shown":shown.lines}
	FileAccess.open(output+"/receipts.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("ACTION_FEEDBACK_NATIVE_OK ",checks, " checks")
	quit()
