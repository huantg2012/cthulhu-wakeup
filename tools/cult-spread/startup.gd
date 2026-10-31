extends SceneTree
const Session = preload("res://src/presentation/session.gd")

func _initialize() -> void:
	var directory: String = OS.get_cmdline_user_args()[0]
	var session: RefCounted = Session.new(directory.path_join("campaigns"))
	var opened: Dictionary = session.start_new(1)
	var result: Dictionary = {"startup": opened}
	if opened.get("ok", false):
		result["installed"] = session.modules.keys()
		result["bootstrap"] = session.world.state.simulation.bootstrap
		result["finish_events"] = session._submit("finish_events") if session.turn.context.phase == "events" else {"ok": session.turn.context.phase == "actions"}
		result["phase"] = session.turn.context.phase
		result["project"] = session.project()
	result["ok"] = opened.get("ok", false) and result.get("phase") == "actions"
	var file: FileAccess = FileAccess.open(directory.path_join("startup.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	print(JSON.stringify({"startup": opened, "ok": result.ok}))
	quit(0 if result.ok else 1)
