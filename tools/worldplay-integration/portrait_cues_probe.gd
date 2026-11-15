extends "res://tools/worldplay-integration/portrait_probe.gd"
## Regression: real seed 3 reaches anonymous prayer worlds in round 3.
## Uses a copied Session and a cold cache, never the player's active save/cache.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size() == 2, "Need real cue save and evidence folder"): return
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	var isolated := "user://portrait-cues-probe/%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	var copy := isolated.path_join("campaign.json")
	if args[0] == "--seed=3":
		var fixture := Session.new(isolated)
		if not require(fixture.start_new(3).ok, "Fixture new game failed"): return
		for step: int in 16:
			if int(fixture.project().turn) >= 3: break
			if not require(fixture.progress(true).ok, "Fixture round advance failed"): return
		if not require(fixture.save_game(copy).ok, "Fixture save failed"): return
	elif not require(DirAccess.copy_absolute(args[0], ProjectSettings.globalize_path(copy)) == OK, "Copy save failed"): return
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(isolated)
	app.display_settings_path = isolated.path_join("display.cfg")
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	scratch = isolated.path_join("portraits")
	app._portraits.cache_directory = scratch
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	auto_arrivals = false
	var loaded: Dictionary = app.session.continue_game(copy)
	if not require(loaded.ok, "Load failed: " + str(loaded)): return
	var before: String = app.session.turn.snapshot()
	var public_before: Dictionary = app.session.project()
	var expected: int = public_before.domains.size() + public_before.people.size() + public_before.cults.size()
	var cues: Array = public_before.domains.filter(func(w: Dictionary) -> bool: return w.has("已知范围"))
	if not require(not cues.is_empty(), "Fixture has no anonymous worlds"): return
	if not identity_checks(public_before): return
	var started := Time.get_ticks_msec()
	measuring = true
	app._open_campaign(loaded)
	if not require(app._portraits.preparing and app._portrait_transition.visible and not app._arrival.visible, "Cold entry failed to hold the table behind preparation"): return
	if not await wait_preparation(): return
	measuring = false
	frame_ms.sort()
	print("CUES_COLD ms=", Time.get_ticks_msec()-started, " generated=", app._portraits.generated_count, " expected=", expected, " frame_p95=", frame_ms[int(frame_ms.size()*.95)])
	if not require(app._portraits.generated_count == expected and app._portraits._textures.size() == expected, "Prewarm omitted visible identities"): return
	if not require(app._arrival.visible and not app._portraits._running, "Arrivals did not wait for all art"): return
	if not complete_slots(): return
	if not require(app.session.turn.snapshot() == before and app.session.project() == public_before, "Art changed gameplay or public knowledge"): return
	var generated: int = app._portraits.generated_count
	var reads: int = app._portraits.disk_read_count
	for i: int in app._arrival._cards.size():
		var card: Dictionary = app._arrival._cards[i]
		if card.get("group") == "prayer" and card.get("domain") == cues[0].id:
			app._arrival._select(i)
			await create_timer(0.9).timeout
			if not complete_slots(): return
			await capture("anonymous-prayer-ready")
			break
	if not await click("EnterRound"): return
	# Both tiny related-reading portraits and full card faces bind synchronously.
	var proof := Control.new()
	app.add_child(proof)
	for pair: Array in [["world", "domains"], ["person", "people"], ["cult", "cults"]]:
		for subject: Dictionary in app.projection[pair[1]]:
			var slot: TextureRect = app._object_art(proof, "Proof", Rect2(0,0,80,80), pair[0], str(subject.id), true)
			if not require(slot.texture != null, "Related reader deferred art: " + str(subject.id)): return
	proof.queue_free()
	await process_frame
	if not complete_slots(): return
	await capture("anonymous-worlds-ready")
	if not require(app._portraits.generated_count == generated and app._portraits.disk_read_count == reads and app._portraits._jobs.is_empty(), "Browsing scheduled generation or disk reads"): return
	# Fresh provider: persistent cache must decode/upload before presentation.
	replace_provider()
	started = Time.get_ticks_msec()
	app._refresh()
	if not await wait_preparation(): return
	if not complete_slots(): return
	if not require(app._portraits.generated_count == 0 and app._portraits.disk_read_count == expected, "Warm cache re-generated or omitted portraits"): return
	print("CUES_WARM ms=",Time.get_ticks_msec()-started," disk_reads=",app._portraits.disk_read_count," generated=0")
	# Exercise the actual next-round boundary, including newly heard people.
	auto_arrivals = true
	while app._event_table():
		var event: Dictionary = app._pending_events()[0]
		if not await play(event.key): return
		if not await click("Option_"+str(event.descriptor.default_action)): return
		if not await click("ConfirmEvent"): return
		if not await wait_preparation(): return
	if not await click("PhaseAction"): return
	auto_arrivals = false
	if not await click("ConfirmEnd"): return
	if app._portraits.preparing and not require(app._portrait_transition.visible and not app._arrival.visible, "New round exposed incomplete art"): return
	if not await wait_preparation(): return
	if not complete_slots(): return
	if not require(app.projection.turn == 4, "Real round did not advance"): return
	var manifest: Array = app._portraits.manifest(app.session, app.projection)
	for art: Dictionary in manifest:
		if not require(app._portraits._textures.has(art.key), "Round omitted manifest image"): return
	print("CUES_ROUND turn=",app.projection.turn," prepared=",manifest.size()," new_generated=",app._portraits.generated_count)
	print("PORTRAIT_CUES_OK ",checks," checks; anonymous identity, cold/warm, birth/discovery stability, no knowledge/RNG mutation, no click-time generation, real next round")
	quit()

func identity_checks(p: Dictionary) -> bool:
	var portraits: Node = app._portraits
	var s: RefCounted = app.session
	var expected: int = p.domains.size()+p.people.size()+p.cults.size()
	var manifest: Array = portraits.manifest(s,p)
	if not require(manifest.size() == expected, "Identity manifest incomplete"): return false
	for hidden_id: String in s.world.state.domains:
		if hidden_id not in s.focus_domains():
			if not require(s.portrait_identity("world",hidden_id).is_empty(), "Unseen world is drawable via public resolver"): return false
			break
	# Isolated knowledge-adapter fixtures, immediately restored. No Turn state edit.
	var known_worlds: Dictionary = s._known_domains.duplicate()
	var known_people: Dictionary = s._known_people.duplicate()
	var keys: Array = manifest.map(func(a: Dictionary) -> String: return a.key)
	for w: Dictionary in p.domains: s._known_domains[w.id] = true
	for person: Dictionary in p.people: s._known_people[person.id] = true
	var after: Array = portraits.manifest(s,p).map(func(a: Dictionary) -> String: return a.key)
	s._known_domains = known_worlds
	s._known_people = known_people
	return require(keys == after, "Discovery rerolled an existing portrait")
