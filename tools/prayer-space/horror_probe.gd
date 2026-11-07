extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Space = preload("res://src/game/prayer_space.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var count := 0

func require(value: bool, message: String) -> bool:
	count += 1
	if not value:
		push_error("PRAYER_HORROR: " + message)
		quit(1)
	return value

func _initialize() -> void:
	run.call_deferred()

func private_fields(value: Variant) -> bool:
	if value is Dictionary:
		for key: String in value:
			if key in ["contracts", "objects", "objects_before", "updates", "scene_after", "branch", "twist", "seed", "ranges", "outcomes", "effect", "tradeoff", "pollution", "alert", "disaster", "disaster_text"]: return true
			if private_fields(value[key]): return true
	elif value is Array:
		for child: Variant in value:
			if private_fields(child): return true
	return false

func run() -> void:
	var selected: Dictionary = {}
	var session: RefCounted
	# Find a bounded natural new-game fixture whose next real check manifests.
	# This does not alter a world, its random stream, or any authored condition.
	for seed_value: int in range(1, 13):
		var trial := Session.new("user://prayer-horror-probe/%d/%d" % [Time.get_ticks_usec(), seed_value])
		var opened: Dictionary = trial.start_new(seed_value)
		if not require(opened.get("ok", false), "new Session failed: " + str(opened)): return
		if trial.turn.context.phase == "events":
			if not require(trial.progress().get("ok", false), "event handoff failed"): return
		for entry: Dictionary in trial.modules.prayers.space_entries(trial.world.state):
			for choice: Dictionary in trial.modules.prayers.space_choices(trial.world.state, entry.id):
				if choice.get("disclosure") != "unknown": continue
				var key: String = "prayer/" + entry.id + "/" + choice.id
				var preview: Dictionary = trial.preview_action(key)
				if not preview.get("ok", false): continue
				var rng := RandomNumberGenerator.new()
				rng.state = trial.world.randoms.checks.state
				var probability := int(preview.preview.get("probability", -1))
				if probability >= 0 and not trial.world.check_result(probability, rng.randi_range(1, 100)) in ["success", "deep"]: continue
				selected = {"id": entry.id, "key": key, "choice": choice.id, "case": entry.descriptor.content_id, "seed": seed_value}
				session = trial
				break
			if not selected.is_empty(): break
		if not selected.is_empty(): break
	if not require(not selected.is_empty(), "no natural unknown-response fixture in twelve seeds"): return
	print("HORROR_FIXTURE ", selected)
	var sizes: Dictionary = {}
	for row: Dictionary in session.catalog.prayer_space.tables.cases.values(): sizes[row.choices.size()] = true
	if not require(sizes.has(2) and sizes.has(3) and sizes.has(4) and sizes.has(5), "content is not variable two through five choices"): return
	var before: String = session.world.snapshot()
	var preview: Dictionary = session.preview_action(selected.key)
	if not require(preview.get("ok", false) and session.preview_action(selected.key).get("ok", false), "unknown preview unavailable"): return
	if not require(session.world.snapshot() == before, "preview changed state or random stream"): return
	if not require(not private_fields(preview) and not private_fields(session.modules.prayers.space_choices(session.world.state, selected.id)), "hidden branch leaked before execution"): return
	var scene: Dictionary = session.world.state.prayer_system.space.scenes[selected.id]
	var objects_before: Dictionary = scene.objects.duplicate(true)
	# The same prepare path must reject a formerly available card once every
	# hidden branch loses a prerequisite; use a detached read view only.
	var view: Dictionary = session.turn._read_view("prayers", "actions")
	view.world = view.world.duplicate(true)
	var impossible: Dictionary = view.world.prayer_system.space.scenes[selected.id].contracts[selected.choice]
	var object_key: String = objects_before.keys()[0]
	var field_key: String = objects_before[object_key].keys()[0]
	var actual: Variant = objects_before[object_key][field_key]
	for effect: Dictionary in impossible.outcomes:
		effect.requires = {object_key + "." + field_key: not actual if actual is bool else (actual + 1 if actual is int else str(actual) + "_unavailable")}
	var denied: Dictionary = session.modules.prayers.space.prepare(view, selected.id, selected.choice, {})
	view.reader.close()
	if not require(not denied.get("ok", false) and session.world.snapshot() == before, "all-invalid branch pool did not reject without payment"): return
	var faith: int = session.world.state.faith
	var whispers: int = session.world.state.whispers
	var metrics_before := Space._metrics(session.world.state, scene)
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = session.world.randoms.checks.state
	var expected_roll := expected_rng.randi_range(1, 100)
	var response: Dictionary = session.execute_action(selected.key, {}, true, "horror-probe-response")
	if not require(response.get("ok", false), "unknown response transaction rejected: " + str(response)): return
	scene = session.world.state.prayer_system.space.scenes[selected.id]
	if not require(scene.status == "answered" and scene.has("selected_outcome") and scene.objects != objects_before, "unknown branch did not change actual objects"): return
	if not require(session.world.state.faith == faith - int(preview.preview.faith) - int(preview.preview.get("first_upkeep", 0)) and session.world.state.whispers == whispers - int(preview.preview.whispers), "unknown charged hidden resources"): return
	var fact: Dictionary = Store.entry(session.world.state.facts, scene.response, {})
	if not require(fact.changes.disclosure == "unknown" and fact.changes.effect == scene.selected_effect and not fact.changes.effect.is_empty(), "committed outcome did not produce its own receipt"): return
	if not require(fact.changes.roll == expected_roll and session.world.randoms.checks.state == expected_rng.state and fact.changes.success_target == preview.preview.success_target, "response did not use exactly its one action D100"): return
	var twist: Dictionary = Store.entry(session.world.state.facts, fact.changes.twist, {}).changes
	if not require(twist.method == "action_d100" and twist.roll == expected_roll and not twist.has("seed"), "unknown result used an independent draw"): return
	var metrics_after := Space._metrics(session.world.state, scene)
	for field: String in metrics_before:
		if not require(fact.changes.actual_deltas[field] == int(metrics_after[field]) - int(metrics_before[field]), "receipt delta differs from actual " + field): return
	if not require(not session.preview_action(selected.key).get("ok", false), "response remained executable"): return
	var after: String = session.world.snapshot()
	if not require(session.execute_action(selected.key, {}, true, "horror-probe-response").get("ok", false) and session.world.snapshot() == after, "idempotent replay rerolled or repaid"): return
	var saved: Dictionary = session.save_game()
	if not require(saved.get("ok", false), "save failed"): return
	var restored := Session.new("user://prayer-horror-probe/restored")
	if not require(restored.continue_game(saved.path).get("ok", false), "restore failed"): return
	if not require(restored.world.snapshot() == after, "restore changed hidden draw or state"): return
	if not require(Space.validate(restored.world.state, restored.catalog).is_empty(), "restored frozen result failed validation"): return
	print("PRAYER_HORROR_OK ", count, " checks; ", selected)
	quit(0)
