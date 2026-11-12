extends "res://src/presentation/production/worldplay/view.gd"
const FIXTURE := "res://docs/qa/ui-manifest/saves/local-contacts-five-worlds.json"
var _capture_path := ""
var _capture_card := ""

func _ready() -> void:
	var directory := "user://worldplay-study/table-%s" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var save := directory.path_join("campaign.json")
	var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE),ProjectSettings.globalize_path(save))
	session = Session.new(directory)
	display_settings_path = "user://worldplay-study/display.cfg"
	super._ready()
	if copied != OK:
		push_error("Study save copy failed")
		return
	var loaded: Dictionary = session.continue_game(save)
	_open_campaign(loaded)
	if not loaded.get("ok", false): return
	_close_surface()
	_world_id = "DOMAIN-001"
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--study-cult": _study_cult = "CULT/DOMAIN-001"
		elif arg.begins_with("--library="): _library = arg.trim_prefix("--library=")
		elif arg.begins_with("--world="): _world_id = arg.trim_prefix("--world=")
		elif arg.begins_with("--category="): _category = arg.trim_prefix("--category=")
		elif arg.begins_with("--play="): _capture_card = arg.trim_prefix("--play=")
		elif arg.begins_with("--capture="): _capture_path = arg.trim_prefix("--capture=")
	_refresh()
	if not _capture_card.is_empty():
		for card: Dictionary in _deck:
			if card.id == _capture_card: _play_card(card); break
	get_window().title = "邪神苏醒 · 世界玩法牌桌"
	if not _capture_path.is_empty():
		get_window().size = Vector2i(1920,1080)
		_capture_when_ready.call_deferred()

func _capture_when_ready() -> void:
	var limit: int = Time.get_ticks_msec()+55000
	await get_tree().process_frame
	while Time.get_ticks_msec()<limit and (_portraits._running or not _portraits._jobs.is_empty()):
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(_capture_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result: int = get_viewport().get_texture().get_image().save_png(path)
	print("WORLDPLAY_CAPTURE ",path," ",result)
	if "--quit-after-capture" in OS.get_cmdline_user_args(): get_tree().quit()
