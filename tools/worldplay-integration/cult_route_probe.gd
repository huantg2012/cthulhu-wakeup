extends SceneTree
const Session = preload("res://src/presentation/session.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var directory := "user://worldplay-route/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var save := directory.path_join("campaign.json")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://docs/qa/ui-manifest/saves/local-contacts-five-worlds.json"),ProjectSettings.globalize_path(save))
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	var app: Control = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = Session.new(directory)
	app.display_settings_path = directory.path_join("display.cfg")
	root.add_child(game)
	app._open_campaign(app.session.continue_game(save))
	var before: String = app.session.turn.snapshot()
	app._select_world("DOMAIN-001")
	var count := 0
	for cult: Dictionary in app.projection.cults:
		app._world_management.open_cult(str(cult.domain))
		if app._world_id!=cult.domain or app._study_cult!=cult.id or app._master.get_meta("scope_id")!="cult/"+str(cult.id):
			push_error("Cross-world cult mismatch"); quit(1); return
		count+=1
	if before!=app.session.turn.snapshot(): push_error("Cult navigation mutated state"); quit(1); return
	print("WORLDPLAY_CULT_ROUTE_OK ",count," cults; scope and master identity correct; no mutation")
	quit()
