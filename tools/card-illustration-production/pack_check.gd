extends SceneTree
const Library=preload("res://src/presentation/production/worldplay/illustrations/library.gd")
func _initialize() -> void:
	var start:=Time.get_ticks_msec()
	var hashes:={}
	for key: String in Library.Registry.KEYS:
		var tex:=Library.texture(0,key)
		if tex==null or tex.get_size()!=Vector2(512,512) or not tex.resource_path.ends_with(".res"):
			push_error("Packed art missing: "+key); quit(1); return
		var fingerprint:=hash(tex.get_image().get_data())
		if hashes.has(fingerprint): push_error("Duplicate image: "+key); quit(1); return
		hashes[fingerprint]=true
	if FileAccess.file_exists("res://tools/card-illustration-production/bake.gd") or FileAccess.file_exists("res://docs/art/visual-generation/card-illustration-study/full-deck-drafts/manifest.json"):
		push_error("Production depends on authoring files"); quit(1); return
	print("PACKED_ART_OK ",hashes.size()," distinct 512px resources; no drafts/baker; cold resource loading ",Time.get_ticks_msec()-start,"ms")
	quit()
