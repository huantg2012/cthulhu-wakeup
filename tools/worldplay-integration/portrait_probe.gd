extends "res://tools/worldplay-integration/probe.gd"
## Cold/warm preparation through the formal entry and real public identities.
var frame_ms: Array[float] = []
var last_frame := 0
var measuring := false
var scratch := ""

func _process(_delta: float) -> bool:
	if measuring:
		var now := Time.get_ticks_usec()
		if last_frame > 0: frame_ms.append((now-last_frame)/1000.0)
		last_frame = now
	return false

func replace_provider() -> void:
	var old: Node = app._portraits
	app.remove_child(old)
	old.free()
	app._portraits = app.Portraits.new()
	app._portraits.cache_directory = scratch
	app.add_child(app._portraits)
	app._portraits.preparation_progress.connect(app._portrait_transition.report)
	app._portraits.preparation_finished.connect(app._finish_portraits)

func wait_preparation() -> bool:
	var deadline := Time.get_ticks_msec()+180000
	while app._portraits.preparing and Time.get_ticks_msec()<deadline: await process_frame
	await process_frame
	return require(not app._portraits.preparing and not app._portrait_transition.visible, "Preparation did not reveal the ready scene")

func complete_slots() -> bool:
	for slot: Node in app.find_children("*", "TextureRect", true, false):
		if not str(slot.get_meta("art_key", "")).is_empty():
			if not require(slot.texture != null, "A bound portrait was empty on scene construction: "+str(slot.get_path())): return false
	return true

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not require(args.size()>=2,"Need save and evidence folder"): return
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	if not await setup(PackedStringArray(["--save="+args[0]])): return
	var snapshot: String = app.session.turn.snapshot()
	scratch = "user://portrait-performance-probe/%s" % OS.get_process_id()
	replace_provider()
	var started := Time.get_ticks_msec()
	measuring = true
	app._refresh()
	if not require(app._portraits.preparing and app._portrait_transition.visible,"Cold entry did not open its transition"): return
	await capture("preparation")
	await press_key(KEY_ESCAPE)
	if not require(app._dialog.is_empty(), "Loading admitted a keyboard navigation"): return
	if not await wait_preparation(): return
	measuring = false
	frame_ms.sort()
	print("PORTRAITS_COLD ms=",Time.get_ticks_msec()-started," generated=",app._portraits.generated_count," loaded=",app._portraits._textures.size()," frame_p95=",frame_ms[int(frame_ms.size()*.95)]," max=",frame_ms[-1])
	if not require(app._portraits.generated_count==17 and app._portraits._textures.size()==17,"Five-world public cast was incomplete"): return
	if not complete_slots(): return
	await capture("ready-worlds")
	var generated: int = app._portraits.generated_count
	var reads: int = app._portraits.disk_read_count
	var maximum_navigation_ms := 0
	for id: String in app.session.known_domains():
		if not app._world_id.is_empty(): await press_key(KEY_ESCAPE)
		started = Time.get_ticks_msec()
		if not await world(id): return
		maximum_navigation_ms = maxi(maximum_navigation_ms, Time.get_ticks_msec()-started)
		if not complete_slots(): return
	if not await click("People"): return
	var ids: Array = app._deck.map(func(card: Dictionary) -> String: return card.id)
	for id: String in ids:
		if not await play(id): return
		if not complete_slots(): return
	if not require(app._portraits.generated_count==generated and app._portraits.disk_read_count==reads and not app._portraits.preparing,"Navigation caused new drawing or disk reads"): return
	print("PORTRAITS_NAVIGATION worlds=5 people=",ids.size()," generate_delta=0 read_delta=0 max_world_ms=",maximum_navigation_ms)
	if not require(app.session.turn.snapshot()==snapshot,"Preparing/navigating changed gameplay state"): return
	# Exceed the old 24-texture eviction threshold without inventing game objects.
	var actual: Dictionary = app._portraits._textures.duplicate()
	for i: int in 30:
		var key := "cache-lifetime-probe-%d" % i
		app._portraits._textures[key] = actual.values()[0]
		app._portraits._touch(key)
	app._portraits._trim_memory()
	for key: String in actual:
		if not require(app._portraits._textures.has(key),"Public cast was evicted by unrelated texture traffic"): return
	# A fresh provider proves persistent decode and GPU upload occur in preparation.
	replace_provider()
	started = Time.get_ticks_msec()
	app._refresh()
	if not await wait_preparation(): return
	print("PORTRAITS_DISK ms=",Time.get_ticks_msec()-started," generated=",app._portraits.generated_count," reads=",app._portraits.disk_read_count)
	if not require(app._portraits.generated_count==0 and app._portraits.disk_read_count==17,"Warm entry regenerated portraits"): return
	if not complete_slots(): return
	var key: String = app._portraits._textures.keys()[0]
	var file := FileAccess.open(scratch.path_join(key+".png"),FileAccess.WRITE)
	file.store_string("corrupt cache fixture")
	file.close()
	replace_provider()
	app._refresh()
	if not await wait_preparation(): return
	if not require(app._portraits.generated_count==1,"Damaged cache did not repair exactly its missing portrait"): return
	if not complete_slots(): return
	print("PORTRAITS_READY_OK ",checks," checks; cold, disk, all worlds/people, pinning, corrupted cache, gameplay identity")
	quit()
