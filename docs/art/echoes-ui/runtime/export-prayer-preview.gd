extends SceneTree
## Restore the isolated T3 copy via existing UI lifecycle, then read T4 previews.
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
const World = preload("res://src/simulation/world.gd")
const SOURCE: String = "res://.godot/echoes-ui-inspection-20261103/1793688880-2918854.json"
const OUT: String = "res://docs/art/echoes-ui/runtime/prayer-preview.json"
var app
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var source_hash: String = FileAccess.get_sha256(SOURCE)
	app = Experience.instantiate()
	app.session = Session.new("res://.godot/echoes-ui-prayer-preview-20261103")
	root.add_child(app)
	await process_frame
	app.load_save(SOURCE)
	app.close_modal()
	if app.projection.get("phase", "") == "events": app._advance(false)
	if app.projection.get("turn", 0) != 4 or app.projection.get("phase", "") != "actions":
		push_error("PREVIEW_EXPORT: expected T4/actions after normal restore boundary")
		quit(1)
		return
	var request: Dictionary = {}
	for entry: Dictionary in app.projection.prayers:
		if entry.card.content_id == "PRAYER_05": request = entry; break
	if request.is_empty(): push_error("PREVIEW_EXPORT: PRAYER_05 missing"); quit(1); return
	var before: String = World.canonical({"state":app.session.world.state, "context":app.session.turn.context})
	var outputs: Dictionary = {}
	for variant: String in ["shallow", "deep"]:
		var key: String = "prayer/" + str(request.id) + "/" + variant
		app.open_action(key)
		var selection: Dictionary = app.draft.selection.duplicate(true)
		var row: Dictionary = {}
		for candidate: Dictionary in app.session.action_catalog(selection):
			if candidate.key == key: row = candidate; break
		outputs[variant] = {"selection": selection, "session_preview":app.session.preview_action(key, selection), "action_row":row}
	var after: String = World.canonical({"state":app.session.world.state, "context":app.session.turn.context})
	var result: Dictionary = {"scope":"Actual T4 first-cult projection restored from isolated T3 copy via existing lifecycle. No response or turn advance after reaching actions. Preview reads only.","source_isolated_copy":SOURCE,"source_sha256_before":source_hash,"source_sha256_after":FileAccess.get_sha256(SOURCE),"preview_state_unchanged":before == after,"projection":app.projection.duplicate(true),"request":request,"variants":outputs}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("PRAYER_PREVIEW_EXPORT_OK turn=", app.projection.turn, " phase=",app.projection.phase," pure=",before == after," source_unchanged=",source_hash == FileAccess.get_sha256(SOURCE))
	app.queue_free()
	await process_frame
	quit(0)
