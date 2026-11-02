extends SceneTree
## Run only against the unchanged pre-supply revision to create a real old save.
const Session = preload("res://src/presentation/session.gd")

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected original save and output save paths"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output"))
	var copy: String = "res://output/input.json"
	if DirAccess.copy_absolute(args[0], ProjectSettings.globalize_path(copy)) != OK:
		push_error("Could not copy source"); quit(1); return
	var session := Session.new("res://output")
	var loaded: Dictionary = session.continue_game(copy)
	if not loaded.get("ok", false): push_error(str(loaded)); quit(1); return
	var advanced: Dictionary = session.progress()
	if not advanced.get("ok", false) or session.turn.context.phase != "events": push_error(str(advanced)); quit(1); return
	var saved: Dictionary = session.save_game()
	if not saved.get("ok", false) or DirAccess.copy_absolute(ProjectSettings.globalize_path(saved.path), args[1]) != OK:
		push_error("Could not export actual legacy event window"); quit(1); return
	print(JSON.stringify({"turn": session.project().turn, "phase": session.project().phase, "prayers": session.project().prayers.size(), "sha256": FileAccess.get_sha256(args[1])}))
	quit(0)
