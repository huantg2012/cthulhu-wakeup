extends "res://tools/worldplay-integration/probe.gd"
## Read-only production card routes, using an isolated copy of a real save.
func drag_card(index: int) -> bool:
	await process_frame
	var at := card_point(index)
	# Use the table's open title band, outside the current action's pickers.
	var target: Vector2 = app._table.get_global_transform_with_canvas() * (app._table.size * Vector2(.7,.08))
	await pointer_move(Vector2(20,20),at)
	await pointer_move(at,Vector2(20,20))
	await pointer_button(at,true)
	await pointer_move(at+Vector2(0,-42),at,true)
	await pointer_move(target,at+Vector2(0,-42),true)
	var dragged := root.gui_is_dragging()
	await pointer_button(target,false)
	return dragged

func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	if not await setup(PackedStringArray(["--save="+args[1]])): return
	var before: String = app.session.turn.snapshot()
	await capture("overview")
	var domain: String = app.projection.cults[0].domain
	if not await world(domain): return
	# Main world card uses the same native upward drag as the hand.
	var master: Control = app._master
	var at: Vector2 = master.get_global_transform_with_canvas() * (master.size*.5)
	var target: Vector2 = app._table.get_global_transform_with_canvas() * (app._table.size*.5)
	await pointer_move(at,Vector2.ZERO)
	await pointer_button(at,true)
	await pointer_move(at+Vector2(0,-42),at,true)
	await pointer_move(target,at+Vector2(0,-42),true)
	await pointer_button(target,false)
	if not require(app._played.get("kind")=="world","Master drag did not open world"): return
	await capture("world")
	for kind: String in ["person","cult","relic","anchor","prayer","activity"]:
		var rows: Array = app._deck.filter(func(c: Dictionary):return (c.get("kind")==kind and (kind=="prayer" or c.get("type")=="object")) or (kind=="activity" and c.group==kind))
		if rows.is_empty():
			print("NOT_IN_SAVE ",kind)
			continue
		if not await play(str(rows[0].id)): return
		await capture(kind)
		if kind=="person":
			var face: Control = app._table.find_child("Card_*",true,false)
			if not require(face!=null,"Reading card missing for hover"): return
			var hover_at: Vector2 = face.get_global_transform_with_canvas() * (face.size*.5)
			await pointer_move(hover_at,Vector2.ZERO)
			await create_timer(1).timeout
			await capture("person-hover")
			await pointer_move(Vector2(20,20),hover_at)
		if kind=="prayer":
			var story: RichTextLabel = app._table.find_child("PrayerStory",true,false)
			if not require(story!=null and str(rows[0].effect) in story.get_parsed_text(),"Prayer text lost or parsed as markup"): return
			if not await click("Choice___prayer_0"): return
			await capture("prayer-response")
	if not await click("PowerIndex"): return
	if not await play("record/POWER_DREAM"): return
	await capture("power-library")
	if not await click("BackToTable"): return
	await create_timer(.7).timeout
	var cults: Array = app._deck.filter(func(c: Dictionary):return c.get("kind")=="cult")
	if not await play(str(cults[0].id)): return
	if not await click("EnterCult"): return
	var orders: Array = app._deck.filter(func(c: Dictionary):return c.get("kind")=="order")
	if not require(not orders.is_empty(),"Cult missing order card"): return
	if not await play(str(orders[0].id)): return
	await capture("cult-order")
	if not require(app.session.turn.snapshot()==before,"Reading fields changed Session"): return
	print("CARD_FIELDS_OK ",checks)
	quit()
