extends SceneTree
## Real-save availability: every enabled candidate has a formal completion;
## rejected choices, local ownership, cancellation and paid execution are tested.
const Session = preload("res://src/presentation/session.gd")
const Search = preload("res://src/presentation/action_availability.gd")
const Scene = preload("res://src/presentation/production/game_root.tscn")
var app: Control
var s: RefCounted
var shots := ""
var passed := 0
func _initialize() -> void: run.call_deferred()
func need(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1); return false
	passed += 1; return true
func press(id: String) -> void:
	var button: Button = app.find_child(id, true, false)
	assert(button != null and not button.disabled, id)
	button.pressed.emit()
func settle() -> void:
	var start := Time.get_ticks_msec()
	await process_frame
	while not app._tasks._candidate_queue.is_empty() or app._tasks._candidate_job != null:
		if not need(Time.get_ticks_msec() - start < 15000, "candidate queries finish without a hanging input"): return
		await process_frame
func shoot(name_value: String) -> void:
	if shots.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name_value + ".png"))
func search(key: String, selection: Dictionary) -> Dictionary:
	var job := Search.new(s, key, selection)
	var start := Time.get_ticks_msec()
	while true:
		var slice_start := Time.get_ticks_usec()
		var done: bool = job.step()
		assert(Time.get_ticks_usec() - slice_start < 250000, "candidate search blocked a frame")
		if done: break
		assert(Time.get_ticks_msec() - start < 15000, "unbounded search: " + key)
		await process_frame
	if job.result.ok: assert(s.preview_action(key, job.result.selection).ok, "positive result must be a valid full completion")
	return job.result
func verify_cards() -> void:
	for button: Node in app._body.find_children("Choice_*", "Button", true, false):
		if button.disabled: continue
		var completion: Dictionary = button.get_meta("availability", {})
		assert(completion.get("ok", false) and s.preview_action(app._tasks.draft.key, completion.selection).ok, str(button.name))
func verify_prefixes(key: String, complete: Dictionary) -> void:
	# A valid full action must remain reachable from each preceding decision.
	# This catches overly eager partial predicates that hide legitimate play.
	var prefix := {}
	for field: Dictionary in s.action_entry(key, complete).fields:
		if not complete.has(field.key): continue
		prefix[field.key] = complete[field.key]
		var answer: Dictionary = await search(key, prefix)
		assert(answer.ok, "valid action hidden at " + key + "/" + field.key + ": " + str(answer))
func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		shots = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(shots)
	s = Session.new("/tmp/availability-review")
	assert(s.continue_game("res://docs/qa/ui-manifest/saves/ongoing.json").ok)
	s.slot = "/tmp/availability-review-working.json"
	var game := Scene.instantiate(); app = game.get_node("Presentation/CanvasLayer/OverlayRoot"); app.session = s; root.add_child(game); app._close_surface()
	var before: String = s.turn.snapshot(); var knowledge: Dictionary = s.knowledge_snapshot()
	assert(app._world_body.is_ancestor_of(app.find_child("Activities", true, false)))
	assert(app._world_body.is_ancestor_of(app.find_child("AnchorIndex", true, false)))
	assert(app.find_child("MaterialTransfer", true, false) == null)
	assert(app.find_child("WorldOpportunities", true, false) != null)
	await shoot("01-world-gameplay")
	press("AnchorIndex"); await settle()
	assert(app._tasks._subject.kind == "anchors")
	app._close_surface()
	press("WorldOpportunities"); await settle()
	assert(app._tasks._subject.id == "DOMAIN-001")
	await shoot("02-local-opportunities")
	app._close_surface(); press("Activities"); await settle()
	assert(app._dialog == "task_action" and app._tasks.draft.key == "route/context")
	assert(app.find_child("PrepareActivity", true, false) == null)
	assert(app.find_child("ActionTab_operation", true, false) != null)
	verify_cards()
	await shoot("03-activities")
	var rejected: Array = [
		{"domain":"DOMAIN-001", "operation":"ROUTE_PRIVATE_DEVOTION", "npc":"NPC-00000001"},
		{"domain":"DOMAIN-001", "operation":"ROUTE_JOINT_WORK", "npc":"NPC-00000007", "other":"NPC-00000001"},
		{"domain":"DOMAIN-001", "operation":"ROUTE_MEMORY_PRACTICE", "npc":"NPC-00000001", "other":"NPC-00000002"}]
	for selection: Dictionary in rejected:
		var answer: Dictionary = await search("route/context", selection)
		assert(not answer.ok, "infeasible activity offered " + str(selection))
		print("REJECTED ", selection.operation, " ", s.explain_error(answer.error))
	var chosen := {"domain":"DOMAIN-001", "operation":"ROUTE_JOINT_WORK"}
	app._tasks.open_action("route/context", chosen)
	app._tasks.draft.config_tab = "npc"; app._tasks.render_workbench(); await settle(); verify_cards()
	await shoot("04-eligible-people")
	var action: Dictionary = await search("route/context", chosen)
	assert(action.ok)
	await verify_prefixes("route/context", action.selection)
	for field: String in ["npc", "source"]:
		var unknown: Dictionary = action.selection.duplicate(true)
		unknown[field] = "unknown-to-player"
		var answer: Dictionary = await search("route/context", unknown)
		assert(not answer.ok and str(answer.error).begins_with("当前没有符合条件的"), "unknown references must not disclose private rule conditions")
	for key: String in ["POWER_BESTOW", "POWER_DREAM", "POWER_ANCHOR", "relic/equip", "relic/disassemble", "attention/enroll"]:
		var answer: Dictionary = await search(key, {"domain":"DOMAIN-001"} if not key.begins_with("attention/") else {})
		print("SCAN ", key, " ", answer.ok, " queries=", answer.queries)
		if answer.ok:
			await verify_prefixes(key, answer.selection)
			app._tasks.open_action(key, answer.selection)
			assert(not app.find_child("ExecuteDraft", true, false).disabled)
	app._tasks.open_subject("materials", app.projection.cults[0].id); await settle()
	assert(not app._tasks.activity_actors().is_empty())
	# Closing while checks are pending must cancel their reader and ignore output.
	app._tasks.open_action("POWER_BESTOW"); app._close_surface(); await process_frame; await process_frame
	assert(app._tasks._candidate_job == null)
	assert(s.turn.snapshot() == before and s.knowledge_snapshot() == knowledge, "browsing cannot spend, roll or reveal")
	app._tasks.open_action("route/context", action.selection)
	app._tasks.draft.config_tab = "__outcomes"; app._tasks.render_workbench(); await settle()
	await shoot("05-ready-and-cost")
	# Walk the real cards, preserving one configuration from operation to submit.
	app._tasks.open_activities("DOMAIN-001"); await settle()
	for field_key: String in ["operation", "npc", "other"]:
		press("ActionTab_" + field_key); await settle()
		var selected := false
		for field: Dictionary in app._tasks._current_fields:
			if field.key != field_key: continue
			for index: int in field.options.size():
				if field.options[index].id == action.selection.get(field_key):
					press("Choice_%s_%d" % [field_key, index]); selected = true; break
		assert(selected, "ready candidate lost while configuring " + field_key)
		await settle()
	assert(s.preview_action("route/context", app._tasks.draft.selection).ok)
	assert(app._tasks.draft.selection == action.selection)
	var faith: int = s.world.state.faith
	var preview: Dictionary = s.preview_action("route/context", action.selection)
	press("ExecuteDraft")
	assert(app._dialog == "receipt")
	assert(s.world.state.faith == faith - int(preview.preview.faith))
	await shoot("06-paid-result")
	var spent: Dictionary = await search("route/context", action.selection)
	assert(not spent.ok, "same-turn participants must not be offered again")
	app._tasks.open_action("route/context", chosen); app._tasks.draft.config_tab = "npc"; app._tasks.render_workbench(); await settle(); verify_cards()
	await shoot("07-refreshed-people")
	app._large_text = true; app._refresh(); app._tasks.open_activities("DOMAIN-001"); await settle()
	assert(app.find_child("ActionListTitle", true, false) != null and app.find_child("ReturnAction", true, false) != null)
	await shoot("08-large-text")
	print("AVAILABILITY_OK real save, local entrances, no duplicate preparation, formal completions, rejection, purity, cancellation and actual payment")
	quit()
