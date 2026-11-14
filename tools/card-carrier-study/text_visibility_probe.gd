extends "res://tools/worldplay-integration/probe.gd"
## Reproduce the real first-turn arrival, then verify shared card reading states.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "/tmp/card-text-visibility"
	DirAccess.make_dir_recursive_absolute(output)
	auto_arrivals = false
	if not await setup(PackedStringArray(["--keep-arrival","--seed=5"])): return
	if not require(app._arrival.visible,"Fresh Session did not enter arrival"): return
	if not require(app._arrival._fan.cards.size()==9,"Seed 5 no longer reproduces the nine-card arrival"): return
	await create_timer(1.0).timeout
	var fan: Control = app._arrival._fan
	fan.grab_focus()
	for i: int in fan.cards.size()-1: await press_key(KEY_RIGHT)
	await create_timer(.9).timeout
	print("ARRIVAL_TEXT_STATE ",JSON.stringify(fan.cards.map(func(c: Control):return {
		"title":c.carrier.get_node("Title").text,"exposed":c.carrier._exposed,
		"title_alpha":c.carrier.get_node("Title").modulate.a,
		"info_alpha":c.carrier.get_node("InformationOne").modulate.a})))
	await capture("arrival-after")
	if not check_fan(fan): return
	if not check_densities(): return
	# Re-open the same public arrival; interrupted transitions must not leave ink faded.
	await press_key(KEY_ESCAPE)
	await process_frame
	# Closing the first arrival legitimately finishes the empty event boundary.
	# Read-only comparison starts AFTER that normal Session handoff.
	var before: String = app.session.turn.snapshot()
	if not check_fan(app._stage.get_node("WorldFan")): return
	if not await click("RoundEcho"): return
	await create_timer(.2).timeout
	if not await click("ArrivalGroup_person"): return
	if not await click("ArrivalGroup_unlock"): return
	await create_timer(1.0).timeout
	if not check_fan(app._arrival._fan): return
	if not await click("EnterRound"): return
	var domain: String = app.projection.domains[0].id
	if not await world(domain): return
	if not check_fan(app._fan): return
	if not await click("Pile_person"): return
	await create_timer(.3).timeout
	if not check_fan(app._fan): return
	await capture("world-person-cards")
	if not app._hand_cards.is_empty():
		if not await play(str(app._hand_cards[0].id)): return
		if not require(app._table.find_child("PrintedFace",true,false).get_node("Title").modulate.a==1.0,"Drag copied concealed/faded text into played face"): return
	if not await click("Pile_all"): return
	if not check_fan(app._fan): return
	if not require(app.session.turn.snapshot()==before,"Reading changed Session"): return
	print("CARD_TEXT_VISIBILITY_OK ", checks)
	quit()

func check_fan(fan: Control) -> bool:
	for card: Control in fan.cards:
		var carrier: Control = card.carrier
		for field: String in ["Title","InformationOne","InformationTwo"]:
			var label: Control = carrier.get_node(field)
			if not require(label.modulate.a==0.0 or label.modulate.a==1.0,"Partially erased card ink: "+field+" "+str(carrier._exposed)): return false
			if carrier._side==0 or carrier._exposed>=70.0:
				if not require(label.modulate.a==1.0,"Readable face lost its copy: "+label.text): return false
		var spine: Label = carrier.get_node("LeftSideName")
		if carrier._exposed>=70.0 and not require(not spine.visible,"Wide face also printed a duplicate vertical name"): return false
		if spine.visible and not require(spine.modulate.a==1.0,"Visible vertical name was erased"): return false
	return true

func check_densities() -> bool:
	# Disclosed presentation fixtures: same public cards / cached pictures at
	# different counts. No fabricated game objects are added to the Session.
	var examples: Array = app._arrival._cards
	for count: int in [1,5,8,9,10,12,18,48]:
		var fan: Control = app.HandFan.new()
		fan.position = Vector2(-4000,-4000)
		fan.size = Vector2(1108,260)
		fan.allow_play = false
		app.add_child(fan)
		var cards: Array[Control] = []
		for i: int in count:
			cards.append(app._face(fan,examples[i%examples.size()],Rect2(0,0,148,198)))
		fan.configure(cards)
		var good := check_fan(fan)
		app.remove_child(fan)
		fan.queue_free()
		if not good: return false
	return true
