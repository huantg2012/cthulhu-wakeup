extends SceneTree
const Session = preload("res://src/presentation/session.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	var app: Control = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new("user://worldplay-pack/%d" % Time.get_ticks_usec())
	app.display_settings_path = app.session.save_directory.path_join("display.cfg")
	root.add_child(game)
	root.size = Vector2i(1920,1080)
	app._start_new(1)
	if not app.projection.get("active",false): push_error("Packed new game failed"); quit(1); return
	app._inspect_world(str(app.projection.domains[0].id))
	if app._deck.is_empty(): push_error("Packed table missing"); quit(1); return
	if FileAccess.file_exists("res://docs/qa/ui-manifest/saves/local-contacts-five-worlds.json"):
		push_error("Packed build contains test fixture"); quit(1); return
	var deadline := Time.get_ticks_msec()+60000
	await process_frame
	while Time.get_ticks_msec()<deadline and (app._portraits._running or not app._portraits._jobs.is_empty()): await process_frame
	var art: TextureRect = app._master.find_child("ScopeArt",true,false)
	if art == null or art.texture == null: push_error("Packed procedural art unavailable"); quit(1); return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/worldplay-pack.png")
	print("WORLDPLAY_PACK_OK formal root, fresh Session, procedural art, no study fixture")
	quit()
