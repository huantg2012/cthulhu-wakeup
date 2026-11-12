extends SceneTree
var view: Control
var count := 0
func _initialize() -> void: call_deferred("run")
func check(okay: bool,label: String) -> bool:
	count += 1
	print("FOUR_ZONE ",label," ",okay)
	if not okay: quit(1)
	return okay
func run() -> void:
	root.add_child(load("res://docs/art/visual-generation/worldplay-study/worldplay.tscn").instantiate())
	view = root.get_node("GameRoot/Presentation/CanvasLayer/OverlayRoot")
	await process_frame
	var sequence: int = view.session.turn.commit_sequence
	if not check(view._deck.size()==41 and not view._hand.has_node("Next"),"main_card_removed_from_hand_no_pages"): return
	if not check(view._fan.cards.size()==41 and view._fan.is_stacked(),"all_cards_in_continuous_fan"): return
	view._fan.set_focus(40,false)
	if not check(view._fan.focus_index==40 and view._fan.cards[40].visible,"last_card_reachable"): return
	var corners: Array = [view._master.get_global_rect(),view._table.get_global_rect(),view._hand.get_global_rect(),view._persistent_dock.get_global_rect()]
	for a: int in corners.size():
		for b: int in range(a+1,corners.size()):
			if not check(not corners[a].intersects(corners[b]),"zones_%s_%s_separate" % [a,b]): return
	var dream: Dictionary = view._deck.filter(func(c: Dictionary)->bool:return c.id=="POWER_DREAM")[0]
	view._play_card(dream)
	var person_field: Dictionary = view._fields().filter(func(f: Dictionary)->bool:return f.key=="npc")[0]
	view._choose_inline(person_field,person_field.options[0].id)
	var saved: Dictionary = view._selection.duplicate(true)
	for kind: String in ["power","relic","person"]:
		view._open_library(kind)
		if not check(not view._deck.is_empty() and view._deck.all(func(c: Dictionary)->bool:return c.type=="object"),"readonly_"+kind+"_deck"): return
		view._play_card(view._deck[0])
		if not check(not view._table.has_node("Execute") and view._persistent_dock.is_visible_in_tree(),"readonly_"+kind+"_no_execute_dock_present"): return
		view._execute()
		view._save_plan(view._views._plan(view))
		if not check(view.session.turn.commit_sequence==sequence,"readonly_"+kind+"_guarded"): return
	view._close_library()
	if not check(view._played.id=="POWER_DREAM" and view._selection==saved,"return_restores_execution_draft"): return
	view._enter_cult("CULT/DOMAIN-001")
	if not check(view._master.get_meta("scope_id")=="cult/CULT/DOMAIN-001","cult_permanent_main_card"): return
	view._find_card("传教")
	if not check(view._hand_cards.size()==1,"search_reaches_card_without_paging"): return
	view._play_card(view._hand_cards[0])
	if not check(view._table.has_node("Execute"),"cult_order_remains_executable"): return
	view._open_library("person")
	view._close_library()
	if not check(view._study_cult=="CULT/DOMAIN-001" and view._search=="传教","return_restores_cult_and_search"): return
	view._dock_subject("history")
	if not check(view._persistent_dock.get_index()>view._surface.get_index(),"dock_remains_above_history"): return
	view._tasks.back()
	print("FOUR_ZONE_CHECKS ",count)
	quit()
