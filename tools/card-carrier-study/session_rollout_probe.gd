extends "res://tools/worldplay-integration/probe.gd"
## Production-only coverage: copied save, normal turn boundary, real navigation.
## Reading and choosing do not mutate the snapshot; only events are submitted.
const Carrier = preload("res://src/presentation/production/painted/card_carrier/card.gd")

func check_faces(scope: Node) -> bool:
	for node: Node in scope.find_children("*", "Button", true, false):
		if not node is StudyCardType or not node.is_visible_in_tree(): continue
		if not require(is_instance_valid(node.carrier), "Legacy card without carrier: " + str(node.get_path())): return false
		if not require(node.carrier.get_node_or_null("CardCutEdge") != null and node.carrier.get_node_or_null("CategoryMarks") != null, "Missing card layers"): return false
	for slot: Node in scope.find_children("*", "TextureRect", true, false):
		if slot.is_visible_in_tree() and not str(slot.get_meta("art_key", "")).is_empty():
			if not require(slot.texture != null, "Visible unprepared art: " + str(slot.get_path())): return false
	return true

const StudyCardType = preload("res://src/presentation/production/worldplay/study_card.gd")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size() >= 2, "Need source save and output directory"): return
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	auto_arrivals = false
	if "--new" in args:
		if not await setup(PackedStringArray(["--keep-arrival"])): return
		if not require(app._arrival_model.counts.unlock > 0, "Fresh game missing initial unlocked cards"): return
		if not await click("ArrivalGroup_unlock"): return
		await create_timer(.9).timeout
		if not check_faces(app._arrival): return
		await capture("arrival-initial-unlocks")
		if not await click("EnterRound"): return
		print("CARD_INITIAL_UNLOCKS_OK ", checks)
		quit()
		return
	if not await setup(PackedStringArray(["--save=" + args[0], "--keep-arrival"])): return
	if not check_faces(app._arrival): return
	if not await click("EnterRound"): return
	if "--details" in args:
		await verify_details()
		return
	if not await click("PhaseAction"): return
	if not await click("ConfirmEnd"): return
	var deadline := Time.get_ticks_msec() + 90000
	while (app._portraits.preparing or not app._arrival.visible) and Time.get_ticks_msec() < deadline: await process_frame
	if not require(app._arrival.visible and not app._portraits.preparing, "Arrival did not follow preparation"): return
	if "--review" in args:
		if not await click("ArrivalGroup_prayer"): return
		print("CARD_REVIEW_READY turn=", app.projection.turn, " save_copy=", app.session.save_directory)
		return
	var snapshot: String = app.session.turn.snapshot()
	var generated: int = app._portraits.generated_count
	for group: String in ["event", "prayer", "person", "unlock"]:
		if app._arrival_model.counts.get(group, 0) == 0: continue
		if not await click("ArrivalGroup_" + group): return
		await create_timer(.9).timeout
		if not check_faces(app._arrival): return
		await capture("arrival-" + group)
	if not require(app.session.turn.snapshot() == snapshot and app._portraits.generated_count == generated, "Arrival mutated Session or generated art"): return
	if not await click("EnterRound"): return
	if not require(app._event_table(), "Expected natural pending events"): return
	if not check_faces(app): return
	await capture("event-table")
	while app._event_table():
		var event: Dictionary = app._pending_events()[0]
		if not await play(event.key): return
		if not await click("Option_" + str(event.descriptor.default_action)): return
		if not await click("ConfirmEvent"): return
		while app._portraits.preparing: await process_frame
		await process_frame
		if not require(not app._arrival.visible, "Event resolution replayed arrival"): return
	snapshot = app.session.turn.snapshot()
	generated = app._portraits.generated_count
	if not require(app._world_id.is_empty(), "Expected overview after events"): return
	if not check_faces(app): return
	await capture("world-overview")
	var fan: Control = app.find_child("WorldFan", true, false)
	var positions: Array = []
	for card: Control in fan.cards: positions.append(card.position.x)
	for index: int in [0, fan.cards.size() - 1]:
		fan.grab_focus()
		while fan.focus_index != index: await press_key(KEY_RIGHT if index > fan.focus_index else KEY_LEFT)
		await create_timer(.25).timeout
		for i: int in fan.cards.size():
			if not require(fan.cards[i].visible and fan.cards[i].z_index == 0 and fan.cards[i].position.x == positions[i], "Home browse changed order or hid card"): return
	var domain: String = app.projection.cults[0].domain
	if not await world(domain): return
	if not check_faces(app): return
	if not inspect_hand(): return
	await capture("world-table")
	if not await play("POWER_APPOINT"): return
	if not check_faces(app): return
	await capture("action-candidates")
	var choices: Array = app._table.find_children("Choice_*", "Button", true, false)
	if not choices.is_empty():
		if not await click(str(choices[0].name)): return
		if not require(app.session.turn.snapshot() == snapshot, "Candidate selection executed action"): return
	app._recall()
	var prayer: Dictionary = {}
	for card: Dictionary in app._deck:
		if card.group == "prayer": prayer = card; break
	if not prayer.is_empty():
		if not await play(prayer.id): return
		if not check_faces(app): return
		await capture("prayer-choices")
		var responses: Array = app._table.find_children("Choice_*", "Button", true, false)
		if not responses.is_empty():
			if not await click(str(responses[0].name)): return
			if not check_faces(app): return
			await capture("prayer-selected")
		app._recall()
	var cult: Dictionary = app._deck.filter(func(c: Dictionary) -> bool: return c.group == "cult")[0]
	if not await play(cult.id): return
	if not await click("EnterCult"): return
	if not check_faces(app): return
	await capture("cult-table")
	for route: Array in [["People", "person"], ["RelicIndex", "relic"], ["PowerIndex", "power"]]:
		if not await click(route[0]): return
		if not check_faces(app): return
		if not app._hand_cards.is_empty():
			if not await play(app._hand_cards[0].id): return
			if not check_faces(app): return
		if not require(app._table.get_node_or_null("Execute") == null, "Read-only library exposed Execute"): return
		await capture("library-" + route[1])
		if not await click("BackToTable"): return
	# Return through the breadcrumbs, then enter the retained prayer path.
	for step: int in 5:
		if app._world_id.is_empty(): break
		await press_key(KEY_ESCAPE)
	if not await click("PhaseAction"): return
	if not await click("ReviewPrayers"): return
	if app._dialog == "prayer_intro":
		var intro: Array = app._surface.find_children("IntroPrayer_*", "Button", true, false)
		if not require(not intro.is_empty(), "No retained prayer entry"): return
		if not await click(str(intro[0].name)): return
	if not check_faces(app): return
	await capture("related-prayer")
	if not require(app.session.turn.snapshot() == snapshot and app._portraits.generated_count == generated, "Reading/navigation mutated Session or generated portraits"): return
	print("CARD_SESSION_ROLLOUT_OK ", checks, " checks; turn-10 arrival, event handoff, five worlds, action choices, cult, libraries, legacy prayer; source save unchanged")
	if "--stay" not in args: quit()

func verify_details() -> void:
	var snapshot: String = app.session.turn.snapshot()
	var domain: String = app.projection.cults[0].domain
	if not await world(domain): return
	if not check_faces(app): return
	await capture("empty-drop-slot")
	if not await play("POWER_APPOINT"): return
	if app._picker != "npc" and not await click("Slot_npc"): return
	if not await click("Choice_npc_0"): return
	if app._picker != "npc" and not await click("Slot_npc"): return
	var chosen: Button = app._table.get_node("Choice_npc_0")
	if not require(chosen.selected and chosen.carrier.get_node("SelectionImprint").chosen, "Candidate lost selected imprint"): return
	var at: Vector2 = chosen.get_global_transform_with_canvas() * (chosen.size * .5)
	await pointer_move(Vector2(20,20), at)
	Input.warp_mouse(root.get_stretch_transform() * at)
	await pointer_move(at, Vector2(20,20))
	await create_timer(.26).timeout
	print("HOVER_CANDIDATE ", root.gui_get_hovered_control(), " expected=", chosen, " at=", at, " scale=", chosen.scale, " amount=", chosen._hover.amount, " enabled=", chosen.hover_enabled)
	if not require(chosen.scale.x > 1.0, "Standalone candidate has no hover response"): return
	if not check_faces(app): return
	await capture("candidate-filled-hover")
	if not require(app.session.turn.snapshot() == snapshot, "Choosing/hovering candidate submitted an action"): return
	print("CARD_COMPACT_DETAILS_OK ", checks, " checks; opaque selection ink, empty drop slot, hover, no action commit")
	quit()
