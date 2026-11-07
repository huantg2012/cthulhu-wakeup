extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var checks := 0

func require(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		return false
	return true

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session := Session.new("user://prayer-space-probe/%d" % Time.get_ticks_usec())
	var opened: Dictionary = session.start_new(1)
	if not require(opened.get("ok", false), "Session start: " + str(opened)): return
	if session.turn.context.phase == "events":
		if not require(session.progress().get("ok", false), "finish events"): return
	var entries: Array = session.modules.prayers.space_entries(session.world.state)
	print("SPACE_ENTRIES ", entries.map(func(item: Dictionary) -> String: return item.id + ":" + item.descriptor.content_id))
	if not require(not entries.is_empty(), "New situations were not supplied"): return
	if not require(entries.size() + session.world.state.prayer_system.offered.size() <= 3, "Combined offer overflow"): return
	var chosen: Dictionary = entries[0]
	var options: Array = session.modules.prayers.space_choices(session.world.state, chosen.id)
	var key := "prayer/" + str(chosen.id) + "/" + str(options[1].id)
	var before: String = session.world.snapshot()
	var preview: Dictionary = session.preview_action(key)
	if not require(preview.get("ok", false), "Response preview: " + str(preview)): return
	if not require(session.world.snapshot() == before, "Preview mutated world or random stream"): return
	var faith: int = session.world.state.faith
	var whispers: int = session.world.state.whispers
	var response: Dictionary = session.execute_action(key, {}, true)
	if not require(response.get("ok", false), "Response rejected: " + str(response) + " / " + str(session.turn.last_error)): return
	if not require(session.world.state.faith == faith - int(preview.preview.faith), "Faith payment mismatch"): return
	if not require(session.world.state.whispers == whispers - int(preview.preview.whispers), "Whisper payment mismatch"): return
	if not require(session.turn.context.responses == 1, "Response slot was not consumed"): return
	if not require(not session.preview_action(key).get("ok", false), "Answered prayer reopened"): return
	var scene: Dictionary = session.world.state.prayer_system.space.scenes[chosen.id]
	if not require(scene.objects.property.quantity == 2 and scene.objects.property.delivered == 1, "First actual maintenance delivery"): return
	var initial_turn: int = session.world.state.turn
	for step: int in range(12):
		if session.world.state.turn > initial_turn + 1 and session.turn.context.phase == "actions": break
		if not require(session.progress(true).get("ok", false), "Deadline transition: " + session.turn.last_error): return
	scene = session.world.state.prayer_system.space.scenes[chosen.id]
	if not require(scene.objects.property.quantity == 1 and scene.objects.property.delivered == 2, "Next maintenance did not consume real inventory"): return
	var saved: Dictionary = session.save_game()
	if not require(saved.get("ok", false), "Save failed: " + str(saved)): return
	var restored := Session.new("user://prayer-space-probe/receiver")
	var loaded: Dictionary = restored.continue_game(saved.path)
	if not require(loaded.get("ok", false), "Restore failed: " + str(loaded)): return
	if not require(restored.world.state.prayer_system.space == session.world.state.prayer_system.space, "Restored situation state differs"): return
	print("PRAYER_SPACE_RUNTIME_OK ", checks, " checks; ", chosen.descriptor.content_id)
	quit(0)
