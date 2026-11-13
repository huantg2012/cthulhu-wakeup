extends "res://tools/worldplay-integration/probe.gd"
## Same formal root, actual public cast; all play happens in a copy of the save.
const PaletteStudy = preload("res://tools/palette-study/controller.gd")
var study: Node

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var initial := 1
	var setup_args := PackedStringArray()
	for arg: String in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--save="): setup_args.append(arg)
		if arg.begins_with("--palette="): initial = int(arg.trim_prefix("--palette="))
	if setup_args.is_empty():
		var save := _five_world_save()
		if not require(not save.is_empty(),"未找到五世界存档，请用 --save=绝对路径 指定。"): return
		setup_args.append("--save="+save)
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await setup(setup_args): return
	study = PaletteStudy.new()
	root.add_child(study)
	study.start(app)
	study.select(initial)
	var fan: Control = app.find_child("WorldFan",true,false)
	if fan != null:
		fan.set_focus(mini(2,fan.cards.size()-1),false)
	print("PALETTE_READY: turn=",app.projection.turn," public_worlds=",app.projection.domains.size()," copy=",app.session.save_directory)
	if "--capture" in args:
		await _evidence()
		if not "--leave-open" in args: quit()

func _five_world_save() -> String:
	var directory := "user://production-ui-campaigns"
	var newest := ""
	var modified := 0
	for file: String in DirAccess.get_files_at(directory):
		if not file.ends_with(".json"): continue
		var path := directory.path_join(file)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary: continue
		var domains: Array = data.get("body",{}).get("knowledge",{}).get("domains",[])
		if domains.size() != 5: continue
		var time := FileAccess.get_modified_time(path)
		if time > modified: newest = ProjectSettings.globalize_path(path); modified = time
	return newest

func _evidence() -> void:
	var before: String = app.session.turn.snapshot()
	var stats: Dictionary = {"generated":app._portraits.generated_count,"disk_reads":app._portraits.disk_read_count}
	var metadata := {}
	study._badge.hide()
	app._atmosphere.paused = true
	app._atmosphere.set_sample_time(6.0)
	for index: int in 2:
		await press_key(KEY_0+index)
		if not require(study.choice == index,"Numeric palette shortcut failed"): return
		await capture("worlds-%d" % index)
	var world_fan: Control = app.find_child("WorldFan",true,false)
	var front: Control = world_fan.cards[world_fan.focus_index]
	metadata["world_art"] = _screen_box(front.get_node("WorldArt"),Rect2(12,12,216,216))
	metadata["paper"] = _screen_box(front,Rect2(14,280,230,95))
	metadata["background"] = _screen_box(app,Rect2(540,550,480,66))
	var domain: String = app.projection.cults[0].domain if not app.projection.cults.is_empty() else app.projection.domains[0].id
	if not await world(domain): return
	var action: String = ""
	for card: Dictionary in app._hand_cards:
		if card.group == "power" and card.get("verb","") == "dream": action = card.id; break
	if action.is_empty():
		for card: Dictionary in app._hand_cards:
			if card.type == "action": action = card.id; break
	if not action.is_empty() and not await play(action): return
	for index: int in 2:
		study.select(index)
		await _park_pointer()
		await capture("table-%d" % index)
	metadata["table_art"] = []
	var master_art: TextureRect = app._master.find_child("ScopeArt",true,false)
	if master_art != null: metadata.table_art.append(_portrait_box(master_art))
	var table_art: TextureRect = app._table.find_child("Illustration",true,false)
	if table_art != null: metadata.table_art.append(_portrait_box(table_art))
	if card_index("POWER_APPOINT") >= 0:
		if not await play("POWER_APPOINT"): return
		for index: int in 2:
			study.select(index)
			await _park_pointer()
			await capture("slots-%d" % index)
	var meta_file := FileAccess.open(output.path_join("regions.json"),FileAccess.WRITE)
	meta_file.store_string(JSON.stringify(metadata,"  "))
	if not require(before == app.session.turn.snapshot(),"Palette navigation mutated the Session"): return
	print("PALETTE_STUDY: printed card finish; portrait RGB preserved, alpha rim narrowed; Session unchanged.")
	print("PORTRAITS_BEFORE ",stats)
	print("PORTRAITS_AFTER ",{"generated":app._portraits.generated_count,"disk_reads":app._portraits.disk_read_count})
	study.select(1)
	study._badge.show()
	app._atmosphere.paused = false

func _park_pointer() -> void:
	var move := InputEventMouseMotion.new()
	move.position = app.get_global_transform_with_canvas()*Vector2(1240,90)
	move.global_position = move.position
	root.push_input(move,true)
	await create_timer(.25).timeout

func _portrait_box(control: Control) -> Array:
	# Portraits are square and KEEP_ASPECT_CENTERED. Exclude letterboxing as
	# well as the existing transparent 4% rim when checking original RGB.
	var inside := Vector2.ONE * minf(control.size.x,control.size.y) * 0.88
	return _screen_box(control,Rect2((control.size-inside)*0.5,inside))

func _screen_box(control: Control, bounds: Rect2) -> Array:
	# Express the control in the fixed logical canvas first. On Retina the
	# native viewport texture's reported size can differ from its PNG image.
	var local := app.get_global_transform_with_canvas().affine_inverse() * control.get_global_transform_with_canvas()
	var area: Rect2 = local * bounds
	var captured := Image.load_from_file(output.path_join("worlds-1.png"))
	var scale_factor := Vector2(captured.get_size()) / Vector2(1280,720)
	area.position *= scale_factor
	area.size *= scale_factor
	return [int(area.position.x),int(area.position.y),int(area.end.x),int(area.end.y)]
