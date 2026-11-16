extends "res://tools/worldplay-integration/probe.gd"
## Finite visual check of percentage readings, using an isolated real campaign.
func run() -> void:
	output = "res://docs/art/visual-generation/production-evidence/world-metric-percent"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var isolated := "user://world-scale-proof/%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	var fixture := Session.new(isolated)
	if not require(fixture.start_new(3).get("ok",false),"New fixture failed"): return
	for step: int in 16:
		if int(fixture.project().turn)>=3: break
		if not require(fixture.progress(true).get("ok",false),"Fixture round advance failed"): return
	var saved: Dictionary = fixture.save_game(isolated.path_join("campaign.json"))
	if not require(saved.get("ok",false),"Fixture save failed"): return
	if not await setup(PackedStringArray(["--save="+str(saved.path)])): return
	var before: String = app.session.turn.snapshot()
	var unknown: Array = app.projection.domains.filter(func(w: Dictionary)->bool:return w.has("已知范围"))
	if not require(not unknown.is_empty(),"Expected a real prayer-only world"): return
	var world_id: String = unknown[0].id
	for large: bool in [false,true]:
		var suffix := "large" if large else "standard"
		if large:
			if not await click("Menu"): return
			if not await click("Settings"): return
			if not await click("TextSize"): return
			if not await click("Return"): return
			if not await click("Return"): return
		await capture("overview-"+suffix)
		var fan: Control = app.find_child("WorldFan",true,false)
		for card: Control in fan.cards:
			if not require(not card.carrier.has_node("WorldMetricScale"),"Redundant scale header remains"): return
			for name_value: String in ["InformationOne","WorldMetrics0","WorldMetrics1"]:
				var label: RichTextLabel = card.carrier.get_node(name_value)
				if not require(label.get_content_height() <= label.size.y,"Clipped "+suffix+" "+name_value+" "+str(label.get_content_height())+"/"+str(label.size.y)): return
				if name_value.begins_with("WorldMetrics"):
					if not require(label.get_parsed_text().contains("%") or label.get_parsed_text().contains("未掌握"),"Metric has no percentage unit"): return
		if not await world(world_id): return
		await capture("world-"+suffix)
		var at: Vector2 = app._master.get_global_transform_with_canvas() * (app._master.size*.5)
		var end: Vector2 = app._table.get_global_transform_with_canvas() * (app._table.size*.5)
		await pointer_move(at,Vector2.ZERO)
		await pointer_button(at,true)
		await pointer_move(at+Vector2(50,0),at,true)
		await pointer_move(end,at+Vector2(50,0),true)
		await pointer_button(end,false)
		if not require(app._played.get("kind")=="world","Master card did not enter reading area"): return
		await capture("reading-"+suffix)
		await press_key(KEY_ESCAPE)
		if not await click("Overview"): return
	if not await click("Menu"): return
	if not await click("WorldArchive"): return
	if not await click("WorldRecord_"+world_id): return
	await capture("archive-large")
	if not require(app.session.turn.snapshot()==before,"Reading changed Session or knowledge"): return
	print("WORLD_PERCENT_UI_OK: real prayer-only and known worlds; standard/large; native master drag; archive; Session unchanged")
	quit()
