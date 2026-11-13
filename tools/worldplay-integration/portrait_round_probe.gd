extends "res://tools/worldplay-integration/portrait_probe.gd"
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size() >= 2, "Need save and evidence folder"): return
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	if not await setup(PackedStringArray(["--save="+OS.get_cmdline_user_args()[0]])): return
	var previous: int = app.projection.turn
	var generated: int = app._portraits.generated_count
	for cycle: int in 3:
		while app._event_table():
			var event: Dictionary = app._pending_events()[0]
			if not await play(event.key): return
			if not await click("Option_"+str(event.descriptor.default_action)): return
			if not await click("ConfirmEvent"): return
			if not await wait_preparation(): return
		if not await click("PhaseAction"): return
		if not await click("ConfirmEnd"): return
		var pending: int = app._portraits._pending.size()
		if pending > 0:
			if not require(app._portrait_transition.visible and app._art_boundary_pending,"New round exposed unprepared cards"): return
		if not await wait_preparation(): return
		if not complete_slots(): return
		if not require(not app._art_boundary_pending and (app.projection.phase=="actions" or app._event_table()),"Boundary did not resume"): return
		print("ROUND_READY turn=",app.projection.turn," new_public_art=",pending," phase=",app.projection.phase)
	if not require(app.projection.turn==previous+3,"Three real rounds did not advance"): return
	# Rebuild one missing portrait in a disposable cache for the transition evidence.
	app._portraits.cache_directory = "user://portrait-transition-probe/%s" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(app._portraits.cache_directory))
	app._portraits._textures.erase(app._portraits._textures.keys()[-1])
	app._refresh()
	await capture("preparation")
	if not await wait_preparation(): return
	print("PORTRAITS_ROUND_OK ",checks," checks; normal confirmations, new public cast, boundary resumed; generated_delta=", app._portraits.generated_count-generated)
	quit()
