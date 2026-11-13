extends "res://tools/worldplay-integration/probe.gd"
## Formal UI, isolated copied Session. Optional --five checks real multi-world prayers.
## --fixture makes an explicit initial-breach Session; the actual planner creates its plan.
const FixtureSession = preload("res://tools/worldplay-integration/resistance_fixture_session.gd")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size()>=2,"Need source save and evidence directory"):return
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	var source_save := args[0]
	if source_save == "--fixture":
		var fixture := FixtureSession.new("user://resistance-ui-fixture/%d" % Time.get_ticks_usec())
		if not require(fixture.start_new(1).ok,"Could not start disclosed initial-breach fixture"):return
		for step: int in 12:
			var p: Dictionary = fixture.project()
			if p.phase == "actions" and not p.resistance.is_empty():break
			if not require(fixture.progress(true).ok,"Fixture's actual turn failed"):return
		source_save = ProjectSettings.globalize_path(fixture.slot)
	if not await setup(PackedStringArray(["--save="+source_save])):return
	var before: String = app.session.turn.snapshot()
	var fan: Control = app._stage.get_node("WorldFan")
	var order: Array = fan.cards.map(func(c: Control): return c.get_meta("subject_id"))
	var source: Array = app._pending_prayers() if "--five" in args else app.projection.resistance
	if not require(not source.is_empty(),"Fixture has no relevant public rows"):return
	var button := "PrayerIndex" if "--five" in args else "ResistanceIndex"
	var kind := "prayer" if "--five" in args else "resistance"
	if not await click(button):return
	await create_timer(.4).timeout
	var first: int = fan.focus_index
	var marked: Array = fan.cards.filter(func(c: Control):return c.get_meta("attention_kind","")==kind)
	if not require(not marked.is_empty() and app._dialog.is_empty() and app._world_id.is_empty(),"Summary opened a panel or omitted markers"):return
	for c: Control in fan.cards:
		var id: String = c.get_meta("subject_id")
		var expected := source.any(func(r: Dictionary):return r.get("descriptor",{}).get("domain",r.get("domain",""))==id)
		if not require((c in marked)==expected,"Wrong world highlighted: "+id):return
	await capture("prayer-worlds" if "--five" in args else "resistance-worlds")
	if not await click(button):return
	await create_timer(.3).timeout
	if marked.size()>1 and not require(fan.focus_index!=first,"Repeated summary failed to cycle"):return
	if not require(order==fan.cards.map(func(c: Control):return c.get_meta("subject_id")),"Highlight reordered cards"):return
	if not require(app.session.turn.snapshot()==before,"Summary mutated Session"):return
	if not await click("ClearWorldAttention"):return
	if not require(fan.cards.all(func(c: Control):return c.get_meta("attention_kind","").is_empty()),"Clear left marked worlds"):return
	if "--five" in args:
		# Explicit public-projection mapping fixture, never installed in Session.
		var anchors: Array = app.projection.anchors
		app.projection.anchors = [{"domain":order[0]},{"domain":order[0]},{"domain":order[2]},{"domain":"unknown-test-world"}]
		var linked: Array = app._interaction._related_worlds("anchor")
		app.projection.anchors = anchors
		if not require(linked.size()==2 and linked.has(order[0]) and linked.has(order[2]),"Anchor mapping failed to deduplicate or exclude unknown worlds"):return
		print("RESISTANCE_UI_MULTI_OK ",checks," marked=",marked.size());quit();return
	var domain: String = source[0].domain
	if not await world(domain):return
	var card: Dictionary = {}
	var passed_preview := false
	for row: Dictionary in app._deck:
		if row.group=="resistance":
			passed_preview = true
			card = row
		elif row.group=="prayer" and not require(not passed_preview,"Prayer sorted after preview"):return
	if not require(not card.is_empty() and card.subject==source[0],"Preview diverged from public plan"):return
	if not require(app._category_of(card)=="resistance" and app._hand.get_node_or_null("Pile_resistance")!=null,"Preview lacks independent resistance category"):return
	if not await click("Pile_resistance"):return
	if not require(app._hand_cards.all(func(c: Dictionary):return c.group=="resistance"),"Resistance filter included player actions"):return
	if not await click("Pile_all"):return
	if not await play(card.id):return
	var shown: Control = app._table.get_node("Card_"+str(card.id).replace("/","_"))
	if not require(shown.carrier._category_id=="resistance","Preview shoulder mislabeled as behavior"):return
	if not require(app._hand.get_node("Pile_resistance").text.begins_with("预告"),"Preview filter label not updated"):return
	if not require(shown.carrier.get_node("InformationOne").text==card.detail and card.detail.ends_with("触发反制"),"Card and reading countdown diverged"):return
	var origin: Node = app._table.find_child("Forecast_来源",true,false)
	var impact: Node = app._table.find_child("Forecast_预计影响",true,false)
	if not require(origin!=null and origin.get_child(1).text==app.title(str(card.subject.domain)),"Forecast source is not its originating world"):return
	if not require(impact!=null and impact.get_child(1).text==card.effect and card.effect==app.session.catalog.display_tables.resistance_plans[card.subject.rule].preview_impact,"Forecast lost editorial qualitative impact"):return
	if not require(origin.get_child(0).get_theme_color("font_color")!=origin.get_child(1).get_theme_color("font_color"),"Forecast label and value lack color distinction"):return
	if not require(app._table.get_node_or_null("Execute")==null,"Preview exposed execute"):return
	app._execute()
	if not require(app.session.turn.snapshot()==before,"Read-only preview submitted an action"):return
	await art_capture("resistance-table")
	# Follow normal Session boundaries; the real planner, not this probe, ends it.
	for step: int in 16:
		if int(app.session.project().turn)>=int(card.subject.due) and app.session.project().phase=="actions":break
		var result: Dictionary = app.session.progress(true)
		if not require(result.ok,"Could not advance actual expiry: "+str(result)):return
	app._refresh()
	if not require(not app._deck.any(func(c: Dictionary):return c.id==card.id),"Resolved preview remained on table"):return
	if not require(app._played.is_empty(),"Resolved preview left a stale played card"):return
	print("RESISTANCE_UI_OK ",checks," public plan → native drag → read only → real due removal")
	quit()
