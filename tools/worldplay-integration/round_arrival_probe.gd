extends "res://tools/worldplay-integration/probe.gd"
const ArrivalModel = preload("res://src/presentation/production/worldplay/round_arrival_model.gd")

func check_ready() -> bool:
	for slot: Node in app._arrival.find_children("*","TextureRect",true,false):
		if not str(slot.get_meta("art_key", "")).is_empty() and not require(slot.texture != null,"Arrival exposed an unprepared portrait"): return false
	return true

func check_delta() -> bool:
	var ledger := ArrivalModel.new()
	ledger.reset(false)
	var source: Dictionary = app.session.project()
	ledger.observe(app.session,source)
	if not require(ledger.counts.person==0 and ledger.counts.unlock==0,"Resume advertised historical identities as new"): return false
	# Explicit projection fixtures exercise threshold and identity comparisons;
	# they are never installed in Session or rendered as actual game events.
	var after := source.duplicate(true)
	after.turn += 1
	after.awakening = 100
	var petitioner: Dictionary = after.people.filter(func(p: Dictionary) -> bool:return not p.has("已知范围"))[0].duplicate(true)
	petitioner.id = "arrival-fixture-petitioner"
	after.people.append(petitioner)
	var person: Dictionary = petitioner.duplicate(true)
	person.id = "arrival-fixture-person"
	after.people.append(person)
	var cue := {"id":"arrival-fixture-cue","title":"Unknown fixture","已知范围":"仅本次请求线索"}
	after.people.append(cue)
	var prayer: Dictionary = after.prayers[0].duplicate(true)
	prayer.id = "arrival-fixture-prayer"
	prayer.key = "prayer/" + prayer.id
	prayer.descriptor.subjects.petitioner = petitioner.id
	after.prayers.append(prayer)
	ledger.observe(app.session,after)
	if not require(ledger.counts.person==1 and ledger.cards.filter(func(c: Dictionary) -> bool:return c.arrival=="person")[0].subject.id==person.id,"Prayer priority or unknown-person exclusion failed"): return false
	var unlocks := ledger.cards.filter(func(c: Dictionary) -> bool:return c.arrival=="unlock")
	if not require(unlocks.any(func(c: Dictionary) -> bool:return c.id=="POWER_BESTOW") and unlocks.any(func(c: Dictionary) -> bool:return c.id=="POWER_MANIFEST"),"Actual power thresholds didn't produce new unlock cards"): return false
	if not require(not ledger.observe(app.session,after),"Same-round refresh repeated arrival"): return false
	after.turn += 1
	after.faith += 100
	ledger.observe(app.session,after)
	if not require(ledger.counts.unlock==0 and ledger.counts.person==0,"Resource changes or another round repeated already-seen content"): return false
	return true

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size()>=2,"Need save and evidence directory"): return
	auto_arrivals = false
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	if not await setup(PackedStringArray(["--save="+args[0],"--keep-arrival"])): return
	var snapshot: String = app.session.turn.snapshot()
	if not require(app._arrival.visible and app._arrival_model.counts.person==0 and app._arrival_model.counts.unlock==0,"Resume missed current tasks or invented newcomers"): return
	if not check_delta(): return
	if not check_ready(): return
	if not require(app.session.turn.snapshot()==snapshot,"Read-only arrival queries changed Session"): return
	await capture("resume")
	await press_key(KEY_ESCAPE)
	await process_frame
	if not require(not app._arrival.visible and app._stage.visible,"Escape failed to return to the same scene"): return
	if not await click("RoundEcho"): return
	if not require(app._arrival.visible,"Round replay missing"): return
	if not await click("EnterRound"): return
	if not require(app.session.turn.snapshot()==snapshot,"Replaying/closing arrival executed a game decision"): return
	if not await click("PhaseAction"): return
	if not await click("ConfirmEnd"): return
	var deadline := Time.get_ticks_msec()+90000
	while (app._portraits.preparing or not app._arrival.visible) and Time.get_ticks_msec()<deadline: await process_frame
	if not require(app._arrival.visible and not app._portraits.preparing,"Round arrival did not follow portrait preparation"): return
	snapshot = app.session.turn.snapshot()
	var generated: int = app._portraits.generated_count
	var reads: int = app._portraits.disk_read_count
	var cards: Array = app._arrival_model.cards
	print("ROUND_ARRIVAL counts=",app._arrival_model.counts," turn=",app.projection.turn)
	if not require(app._arrival_model.counts.event>0 and app._arrival_model.counts.prayer>0,"Natural turn omitted event/prayer cards"): return
	var petitioners := {}
	var priorities := {"event":0,"prayer":1,"person":2,"unlock":3}
	var last := -1
	for card: Dictionary in cards:
		if not require(priorities[card.arrival]>=last,"Arrival order changed"): return
		last = priorities[card.arrival]
		if card.arrival=="prayer": petitioners[card.petitioner] = true
		if card.arrival=="person" and not require(not petitioners.has(card.subject.id),"Petitioner appeared twice"): return
	await create_timer(.85).timeout
	await capture("events")
	for group: String in ["prayer","person"]:
		if app._arrival_model.counts[group]>0:
			if not await click("ArrivalGroup_"+group): return
			await create_timer(.9).timeout
			if not check_ready(): return
			await capture(group)
	if not require(not app._arrival._fan.allow_play and app._arrival._fan._get_drag_data(Vector2.ZERO)==null,"Arrival cards could execute/drag"): return
	if not require(app.session.turn.snapshot()==snapshot and app._portraits.generated_count==generated and app._portraits.disk_read_count==reads,"Reading arrival changed game state or generated art"): return
	if not await click("EnterRound"): return
	await process_frame
	if not require(app._event_table() and app._persistent_dock.get_node("People").disabled,"Closing arrival bypassed event stage"): return
	var before_prayers := cards.filter(func(c: Dictionary) -> bool:return c.arrival=="prayer").map(func(c: Dictionary):return c.id)
	while app._event_table():
		var event: Dictionary = app._pending_events()[0]
		if not await play(event.key): return
		if not await click("Option_"+str(event.descriptor.default_action)): return
		if not await click("ConfirmEvent"): return
		while app._portraits.preparing: await process_frame
		await process_frame
		if not require(not app._arrival.visible,"Resolving an event repeated the round arrival"): return
	print("ACTION_PHASE_NEW_PRAYERS ",app.projection.prayers.filter(func(p: Dictionary)->bool:return p.status=="open" and p.key not in before_prayers).map(func(p):return p.key))
	if not require(app.projection.phase=="actions" and not app._persistent_dock.get_node("People").disabled,"Events did not hand over to actions"): return
	print("ROUND_ARRIVAL_OK ",checks," checks; public sources, prayer priority, unlock diff, read-only/skip/replay, preloaded art, actual event/action handoff")
	quit()
