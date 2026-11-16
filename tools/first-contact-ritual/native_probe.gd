extends "res://tools/worldplay-integration/probe.gd"
func run() -> void:
	var seed_value := 7 if "--failure" in OS.get_cmdline_user_args() else 2
	var large := "--large" in OS.get_cmdline_user_args()
	output = "res://docs/art/visual-generation/production-evidence/first-contact-ritual/" + ("failure" if seed_value==7 else ("large" if large else "standard"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	auto_arrivals = false
	var args: PackedStringArray = ["--seed=%d" % seed_value,"--keep-arrival"]
	if large: args.append("--large")
	if not await setup(args): return
	if not require(app._arrival_model.counts.person==0 and app._arrival_model.counts.prayer==2,"New petitioner duplicated in arrival"): return
	await create_timer(.8).timeout
	await capture("arrival")
	await press_key(KEY_ENTER)
	auto_arrivals = true
	if not await world(str(app.projection.domains[0].id)): return
	if not require(app._hand_cards.all(func(c: Dictionary)->bool:return c.kind!="person"),"Hidden petitioner remains in actual hand"): return
	if not require(app._deck.size()==app._hand_cards.size() and app._hand.find_child("Pile_person",true,false)==null,"Category count contains hidden people"): return
	app._find_card(str(app.projection.people[0].title))
	if not require(app._hand_cards.all(func(c: Dictionary)->bool:return c.kind!="person"),"Search bypassed carrier suppression"): return
	app._find_card("")
	await art_capture("world-hand")
	var prayer_id := str(app.projection.prayers[0].key)
	if not await play(prayer_id): return
	var before: String = app.session.turn.snapshot()
	if not await click("InspectPetitioner"): return
	if not require(app._dialog=="task_subject","Petitioner read-only view unavailable"): return
	await capture("petitioner-record")
	if not await click("ReturnSubject"): return
	if not require(app._played.get("id")==prayer_id and before==app.session.turn.snapshot(),"Reading lost prayer or changed simulation"): return
	app._open_library("person")
	await process_frame
	if not require(app._hand_cards.size()==app.projection.people.size(),"Read-only people library lost prayer carriers"): return
	if not await play("person/"+str(app.projection.people[0].id)): return
	if not require(app._entry.is_empty() and app._played.type=="object","Library offers an action"): return
	app._close_library()
	await process_frame
	if not require(app._played.id==prayer_id and app.session.turn.snapshot()==before,"Library return lost prior card or mutated gameplay"): return
	if not await play("ROUTE_CALENDAR_RITE"): return
	if not require(app._selection.get("npc")==("NPC-00000002" if seed_value==2 else "NPC-00000004"),"Sole eligible ritualist not auto-filled"): return
	if not require(app._display_fields(app._fields()).all(func(f: Dictionary)->bool:return f.key!="source"),"Causal-record picker still shown"): return
	await capture("ritual-preparation")
	if not await click("Execute"): return
	if not require(app._dice_active(),"Real ritual die presentation absent"): return
	await create_timer(4.0).timeout
	await capture("ritual-result")
	var batch: Dictionary = app._dice._batches[0]
	if not require(batch.checks[0].roll==(45 if seed_value==2 else 85) and batch.checks[0].target==(60 if seed_value==2 else 62),"Displayed die differs from actual seed 2 receipt"): return
	if not require(str(batch.lines).contains("3 名普通居民" if seed_value==2 else "未能转化信众") and str(batch.lines).contains("理智 -2"),"Result omits actual consequences"): return
	await press_key(KEY_ENTER)
	if not require(not app._dice_active(),"Result did not finish"): return
	if not require(app._hand_cards.all(func(c: Dictionary)->bool:return c.kind!="person"),"Action reintroduced petitioner hand"): return
	print("FIRST_CONTACT_NATIVE_OK ",checks," checks; large=",large)
	quit()
