extends "res://tools/worldplay-integration/probe.gd"
## Native prayer flow in an isolated, genuinely generated new Session.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0]
	var seed_value := args[1] if args.size()>1 else "1"
	var dismiss := "--dismiss" in args
	DirAccess.make_dir_recursive_absolute(output)
	if not await setup(PackedStringArray(["--seed="+seed_value])): return
	var prayer: Dictionary = {}
	var choice_index := -1
	var most := 0
	for item: Dictionary in app.projection.prayers:
		var choices: Array = app.session.prayer_response_choices(item.id)
		for index: int in choices.size():
			if app.session.preview_action(choices[index].key).get("ok",false) and choices.size()>most:
				prayer = item; choice_index = index; most = choices.size()
				break
	if not require(not prayer.is_empty(),"No executable generated prayer"): return
	var scene: Dictionary = app.session.world.state.prayer_system.space.scenes.get(prayer.id,{})
	if not require(scene.has("situation_id"),"Expected the current compositional prayer generator"): return
	if not await world(str(prayer.descriptor.domain)): return
	if not await play("prayer/"+str(prayer.id)): return
	var before: String = app.session.turn.snapshot()
	var sequence: int = app.session.turn.commit_sequence
	var story: RichTextLabel = app._table.find_child("PrayerStory",true,false)
	if not require(story!=null and not "来源" in story.get_parsed_text() and str(scene.appeal) in story.get_parsed_text(),"Browsing lost original appeal or retained source"): return
	await capture("browse")
	while app._picker_page<int(choice_index/5):
		if not await click("OptionsNext"): return
	if not await click("Choice___prayer_"+str(choice_index)): return
	if not require(app._table.find_child("Slot___prayer",true,false)==null and app._table.find_child("PrayerStory",true,false)==null,"Preparation repeats response selector or appeal"): return
	if app._table.find_child("Optional",true,false)!=null:
		if not await click("Optional"): return
		await capture("optional-inputs")
	await press_key(KEY_ESCAPE)
	if not require(app._entry.is_empty() and app._played.id=="prayer/"+str(prayer.id) and app.session.turn.snapshot()==before,"Esc recalled card or submitted instead of returning to choices"): return
	if dismiss:
		if not await click("DismissPrayer"): return
		await press_key(KEY_ESCAPE)
		if not require(app._entry.is_empty() and app.session.turn.snapshot()==before,"Cancelling dismissal wrote to Session"): return
		if not await click("DismissPrayer"): return
	else:
		if not await click("Choice___prayer_"+str(choice_index)): return
		var condition: RichTextLabel = app._table.find_child("PrayerCostAndCheck",true,false)
		var target: int = app._quoted.get("success_target",app._quoted.get("probability",-1))
		if not require(target>=0 and ("骰点 ≤ %d" % target) in condition.get_parsed_text(),"Incorrect success inequality"): return
	await capture("prepare-dismiss" if dismiss else "prepare")
	if not await click("Execute"): return
	if app._confirmed and app._result_text.is_empty():
		if not require(app.session.turn.commit_sequence==sequence,"Confirmation executed too early"): return
		if not await click("Execute"): return
	if not require(app.session.turn.commit_sequence==sequence+1 and app._prayer_result.committed,"Prayer did not commit exactly once"): return
	var receipt: Dictionary = app._prayer_result.duplicate(true)
	var dice: RichTextLabel = app._table.find_child("PrayerRoll",true,false)
	if dismiss:
		if not require(receipt.roll==0 and dice.get_parsed_text()=="未掷骰" and not app.projection.prayer_response_spent,"Dismissal invented a roll or spent a response"): return
	else:
		var check: Dictionary = app.session.turn._checks[0]
		if not require(receipt.roll==check.roll and receipt.target==check.probability and receipt.outcome==check.outcome,"Displayed check differs from committed die"): return
		if not require((str(check.roll)+" 点") in dice.get_parsed_text() and ("骰点 ≤ %d" % check.probability) in dice.get_parsed_text(),"Receipt lacks actual dice and success bound"): return
	if not require(app._table.get_node_or_null("Recall")==null and app._table.get_node("Done").text=="让回响散去","Duplicate or misleading result exit"): return
	app._execute()
	if not require(app.session.turn.commit_sequence==sequence+1,"Result allowed repeated execution"): return
	await capture("result-dismiss" if dismiss else "result")
	if not await click("PowerIndex"): return
	if not await click("BackToTable"): return
	if not require(app._prayer_result==receipt,"Read-only archive lost prayer receipt"): return
	var after: String = app.session.turn.snapshot()
	await press_key(KEY_ESCAPE)
	if not require(app._played.is_empty() and app.session.turn.snapshot()==after,"Closing receipt mutated Session"): return
	print("PRAYER_FLOW_OK ",checks," seed=",seed_value," outcome=",receipt.outcome," roll=",receipt.roll," target=",receipt.target)
	quit()
