extends "res://tools/worldplay-integration/probe.gd"
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not await setup([]): return
	var domain: String = app.projection.domains[0].id
	if not await world(domain): return
	# Generate natural events by normal turn confirmation, without injected event facts.
	for i: int in 8:
		if app._event_table(): break
		if not require(app._dialog.is_empty(),"Unexpected phase surface: "+app._dialog): return
		if not await click("PhaseAction"): return
		if not await click("ConfirmEnd"): return
	if not require(app._event_table() and app._dialog.is_empty(),"No natural event cards within eight turns"): return
	if not require(app._deck.size()==app._pending_events().size(),"Pending event missing its card"): return
	if not require(app._persistent_dock.get_node("People").disabled,"Event dock unlocked"): return
	await press_key(KEY_ESCAPE)
	app._open_library("person")
	if not require(app._dialog.is_empty() and app._library.is_empty(),"Event bypassed"): return
	await capture("event-cards")
	var item: Dictionary = app._pending_events().back()
	if not await play(item.key): return
	await press_key(KEY_ESCAPE)
	if not require(app._event_table() and app._dialog.is_empty(),"Esc did not return to event cards"): return
	if not await play(item.key): return
	if not await click("Option_"+str(item.descriptor.default_action)): return
	var sequence: int = app.session.turn.commit_sequence
	if not await click("ConfirmEvent"): return
	if not require(app.session.turn.commit_sequence>sequence,"Event did not commit"): return
	if not require(app.projection.phase=="actions" or app._event_table(),"Event left invalid boundary"): return
	print("WORLDPLAY_EVENT_OK natural event turn=",app.projection.turn,"; modal block, Esc, choice and actual confirmation")
	quit()
