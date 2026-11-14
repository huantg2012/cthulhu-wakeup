extends "res://tools/worldplay-integration/probe.gd"
const Library = preload("res://src/presentation/production/worldplay/illustrations/library.gd")
const Catalogue = preload("res://tools/card-illustration-study/catalogue.gd")
func run() -> void:
	output = "res://docs/art/visual-generation/card-illustration-study/production"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	auto_arrivals = false
	if not await setup(PackedStringArray(["--seed=5","--keep-arrival"])): return
	if not require(app._illustration_variant==0,"Formal art default overridden"): return
	var snapshot: String = app.session.turn.snapshot()
	var cards := Catalogue.cards(app.session.catalog)
	for card: Dictionary in cards:
		var subject := Library.identity(card,str(card.group))
		var texture := Library.texture(0,subject)
		if not require(texture!=null and texture.get_width()>=256,"Missing illustration "+str(card.id)): return
	for subject: String in Library.SAMPLES:
		if not require(Library.texture(0,subject)==Library.texture(2,subject),"Approved sample replaced "+subject): return
	if not require(app._arrival.visible,"Expected first-turn arrival"): return
	await capture("arrival")
	await press_key(KEY_ENTER)
	snapshot = app.session.turn.snapshot() # arrival acknowledgement is a real persisted read marker
	await capture("worlds")
	if not await world(str(app.projection.domains[0].id)): return
	await capture("world-table")
	var index := card_index("POWER_DREAM")
	if index<0:
		for i: int in app._hand_cards.size():
			if app._hand_cards[i].get("entry","")=="POWER_DREAM": index=i; break
	if not require(index>=0 and await drag_card(index),"Power card drag failed"): return
	await capture("power-table")
	if not require(snapshot==app.session.turn.snapshot(),"Viewing changed Session"): return
	app.hide()
	var panel := Control.new()
	panel.size = Vector2(1280,720)
	root.add_child(panel)
	for page_no: int in range(4):
		for child: Node in panel.get_children(): child.free()
		for i: int in 16:
			app._face(panel,cards[page_no*16+i],Rect2(18+(i%8)*157,15+(i/8)*345,144,216))
		await capture("catalogue-%d" % page_no)
	print("PRODUCTION_ART_OK: ",cards.size()," definitions; approved six preserved; arrival/world/hand/drag; Session unchanged")
	quit()
