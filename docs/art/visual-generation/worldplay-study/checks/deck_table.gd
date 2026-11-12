extends SceneTree
## Verify the producer's physical-deck contract against actual hit testing,
## including the intermediate frames where the front card changes.
var view: Control
var samples := 0
func _initialize() -> void: call_deferred("run")
func inspect_deck() -> bool:
	var fan: Control = view._fan
	var bounds := Rect2(Vector2(-.1,-.1),fan.size+Vector2(.2,.2))
	var reached: Dictionary = {}
	for x: int in int(fan.size.x*2):
		var index: int = fan._card_at(Vector2(x*.5,90))
		if index>=0: reached[index] = true
	for i: int in fan.cards.size():
		var card: Control = fan.cards[i]
		if not card.visible or card.modulate.a!=1 or not bounds.encloses(card.get_rect()) or not reached.has(i):
			print("DECK_FAIL card_hidden_clipped_or_unreachable ",i," focus=",fan._visual_focus)
			return false
	if fan.is_stacked():
		if absf(fan.cards[0].position.x-8)>.1 or absf(fan.cards[-1].get_rect().end.x-(fan.size.x-8))>.1:
			print("DECK_FAIL outer_edges_moved ",fan._visual_focus)
			return false
		var crossing := floori(fan._visual_focus)
		if is_equal_approx(fmod(fan._visual_focus,1),.5):
			if fan.cards[crossing+1].position.x-fan.cards[crossing].position.x<147.9:
				print("DECK_FAIL depth_exchange_overlapping")
				return false
	samples += 1
	return true
func capture(label: String,index: int) -> void:
	view._fan.set_focus(index,false)
	view._capture_path = "res://docs/art/visual-generation/worldplay-study/evidence/deck-"+label+".png"
	await view._capture_when_ready()
func run() -> void:
	root.add_child(load("res://docs/art/visual-generation/worldplay-study/worldplay.tscn").instantiate())
	view = root.get_node("GameRoot/Presentation/CanvasLayer/OverlayRoot")
	root.size = Vector2i(1920,1080)
	await process_frame
	var sequence: int = view.session.turn.commit_sequence
	# Real 41-card hand: endpoints, middle, and both sides of depth exchanges.
	for focus: float in [0.,.49,.5,.51,1.,9.,9.49,9.5,9.51,20.,20.5,39.5,40.]:
		view._fan._visual_focus = focus
		view._fan._layout_cards()
		if not inspect_deck(): quit(1); return
	await capture("first",0)
	await capture("middle",20)
	await capture("last",40)
	# Actual filtering changes deck size; small sets must remain real cards too.
	for category: String in ["person","relic","activity","power"]:
		view._filter(category)
		for index: int in [0,view._fan.cards.size()-1]:
			view._fan.set_focus(index,false)
			if not inspect_deck(): quit(1); return
	print("DECK_TABLE all_cards_opaque_inside_table_and_individually_hittable true")
	print("DECK_TABLE endpoints_fill_table_and_depth_exchange_separated true")
	print("DECK_TABLE samples ",samples," no_mutation ",sequence==view.session.turn.commit_sequence)
	quit()
