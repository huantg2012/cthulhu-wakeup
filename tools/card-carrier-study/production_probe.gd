extends "res://tools/worldplay-integration/probe.gd"
## Focused production proof. Copies an existing save; never submits an action.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = ProjectSettings.globalize_path("res://docs/art/visual-generation/card-design-study/shoulder-hand/production")
	DirAccess.make_dir_recursive_absolute(output)
	if not require(args.size() > 0,"Pass the existing save path"): return
	if not await setup(PackedStringArray(["--save="+args[0]])): return
	var before: String = app.session.turn.snapshot()
	var domain: String = str(app.projection.cults[0].domain) if not app.projection.cults.is_empty() else str(app.projection.domains[0].id)
	if not await world(domain): return
	if not inspect_hand(): return
	var fan: Control = app._fan
	var rest_x: Array = []
	for card: Control in fan.cards: rest_x.append(card.position.x)
	var count: int = fan.cards.size()
	for index: int in [0,mini(2,count-1),count-1,mini(3,count-1)]:
		await pointer_move(card_point(index),Vector2.ZERO)
		await create_timer(.24).timeout
		for i: int in count:
			if not require(is_equal_approx(fan.cards[i].position.x,rest_x[i]) and fan.cards[i].z_index==0,"Focus moved x/z"): return
	await capture("world-hand")
	var prayer := -1
	for i: int in app._hand_cards.size():
		if app._hand_cards[i].group == "prayer": prayer = i; break
	var chosen: int = prayer if prayer >= 0 else 0
	var at := card_point(chosen)
	await pointer_move(at,Vector2.ZERO)
	await pointer_button(at,true)
	await pointer_button(at,false)
	if not require(app._played.is_empty(),"Click played a card"): return
	if not require(await drag_card(chosen),"Native hand drag failed"): return
	if not require(app._played.get("id")==app._hand_cards[chosen].id,"Wrong card after drop"): return
	await capture("placed-card")
	fan = app._fan
	var generated: int = app._portraits.generated_count
	var blocked_at: Vector2 = fan.get_global_transform_with_canvas() * (fan.cards[-1].position+Vector2(30,100))
	fan.set_blocked(true)
	var blocked_focus: int = fan.focus_index
	await pointer_move(blocked_at,Vector2.ZERO)
	await pointer_button(blocked_at,true)
	await pointer_move(Vector2(760,300),Vector2.ZERO,true)
	await pointer_button(Vector2(760,300),false)
	if not require(not root.gui_is_dragging() and fan.focus_index==blocked_focus,"Blocked hand accepted input"): return
	fan.set_blocked(false)
	if not require(before==app.session.turn.snapshot() and generated==app._portraits.generated_count,"UI changed Session or generated portrait on browse"): return
	print("SHOULDER_PRODUCTION_OK ",checks," checks; copied save; fixed stack; click/drag; blocked; no commit")
	if "--stay" not in args: quit()
