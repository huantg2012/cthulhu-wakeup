extends SceneTree
## Exercises actual Session commands with a narrowed authored candidate index.
const Session = preload("res://src/presentation/session.gd")
const Space = preload("res://src/game/prayer_space.gd")
const Store = preload("res://src/simulation/archive_store.gd")

class HazardSession extends Session:
	var profile_filter := ""
	func _build(seed_value: int, powers_revision: String = "", sustained_pollution := true) -> Dictionary:
		var built := super(seed_value, powers_revision, sustained_pollution)
		if not built.ok: return built
		var generator: RefCounted = built.modules.prayers.space.generator
		for profile: String in generator.combinations:
			generator.combinations[profile] = generator.combinations[profile].filter(func(plan: Dictionary) -> bool:
				return plan.intent == "escape_alive" and plan.frame == "coast")
		if not profile_filter.is_empty():
			generator.effect_ids = generator.effect_ids.filter(func(id: String) -> bool:
				return generator.content.generator_tables.effects[id].profile == profile_filter)
			generator.twist_ids = []
		return built

var checks := 0

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, message: String) -> bool:
	checks += 1
	if condition: return true
	push_error(message)
	quit(1)
	return false

func _advance(session: RefCounted, target: int) -> bool:
	for _step: int in range(16):
		if session.turn.context.phase == "actions" and int(session.world.state.turn) >= target: return true
		var progress: Dictionary = session.progress(true)
		if not progress.ok:
			push_error(str(progress))
			return false
	return false

func _successful_rng(session: RefCounted, limit: int) -> int:
	var rng := RandomNumberGenerator.new()
	for seed: int in range(1, 100):
		rng.seed = seed
		var before := rng.state
		if rng.randi_range(1, 100) <= limit:
			session.world.randoms.checks.state = before
			return rng.state
	return -1

func _fixture(profile: String) -> Dictionary:
	var game := HazardSession.new("user://generator-probe/%d/%s" % [Time.get_ticks_usec(), profile])
	if profile != "ambiguous": game.profile_filter = profile
	var opened := game.start_new(1)
	if not require(opened.ok and _advance(game, 1), "Generated opening failed: " + str(opened)): return {}
	var data := Space.ledger(game.world.state)
	for id: String in data.offered:
		var scene: Dictionary = data.scenes[id]
		for option: Dictionary in scene.choices.values():
			if option.cost != profile: continue
			var key: String = "prayer/%s/%s" % [id, option.id]
			var preview := game.preview_action(key)
			if preview.ok: return {"game": game, "id": id, "key": key, "option": option, "preview": preview.preview}
	if not require(false, "Opening lacked the requested profile: " + profile + " / " + str(data.offered)): return {}
	return {}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if not _old_archives(args): return
	var twist := _fixture("ambiguous")
	if twist.is_empty() or not _twist(twist): return
	var upkeep := _fixture("maintained_alteration")
	if upkeep.is_empty() or not _upkeep(upkeep): return
	var sanity := _fixture("covert_psychic_burden")
	if sanity.is_empty() or not _sanity_and_followup(sanity): return
	print("PRAYER_GENERATOR_SESSION_OK ", checks, " checks")
	quit()

func _execute(fixture: Dictionary, id: String) -> Dictionary:
	var game: RefCounted = fixture.game
	var next_rng := _successful_rng(game, int(fixture.preview.success_target))
	if not require(next_rng != -1, "Could not select a successful fixture die"): return {}
	var result: Dictionary = game.execute_action(fixture.key, {}, true, id, fixture.preview)
	if not require(result.ok, "Generated response refused: " + str(result)): return {}
	if not require(game.world.randoms.checks.state == next_rng and game.turn.context.responses == 1, "Generated response did not consume exactly one roll and one opportunity"): return {}
	var data := Space.ledger(game.world.state)
	return Store.entry(game.world.state.facts, data.scenes[fixture.id].response).changes

func _restore(game: RefCounted, label: String) -> RefCounted:
	var saved: Dictionary = game.save_game()
	var restored := Session.new("user://generator-probe/restore-" + label)
	var loaded := restored.continue_game(saved.path) if saved.ok else saved
	if not require(loaded.ok, "Generated save failed to restore: " + str(loaded)): return null
	if not require(Space.ledger(game.world.state) == Space.ledger(restored.world.state), "Restored shared situation or cursor changed"): return null
	return restored

func _twist(fixture: Dictionary) -> bool:
	var game: RefCounted = fixture.game
	var before: String = game.world.snapshot()
	var preview: Dictionary = game.preview_action(fixture.key)
	if not require(preview.ok and game.world.snapshot() == before, "Unknown preview wrote world state"): return false
	for field: String in ["outcomes", "ranges", "effect", "pollution", "alert", "metrics"]:
		if not require(not preview.preview.has(field), "Unknown preview exposed " + field): return false
	var stale: Dictionary = fixture.preview.duplicate(true)
	stale.situation_revision += 1
	if not require(not game.execute_action(fixture.key, {}, true, "", stale).ok and game.world.snapshot() == before, "Stale shared revision paid or mutated state"): return false
	var result := _execute(fixture, "generated-twist")
	if result.is_empty(): return false
	var fact: Dictionary = Store.entry(game.world.state.facts, result.twist, {})
	var containing: Array = fact.changes.ranges.filter(func(value: Dictionary) -> bool: return result.roll >= value.first and result.roll <= value.last)
	if not require(containing.size() == 1 and containing[0].id == fact.changes.branch, "Unknown result did not match its one D100 interval"): return false
	var after: String = game.world.snapshot()
	if not require(game.execute_action(fixture.key, {}, true, "generated-twist").ok and game.world.snapshot() == after, "Retry rolled or charged again"): return false
	return _restore(game, "unknown") != null

func _upkeep(fixture: Dictionary) -> bool:
	var game: RefCounted = fixture.game
	var faith: int = game.world.state.faith
	if not require(fixture.preview.upkeep_turns == 3 and not fixture.preview.upkeep_stop.is_empty(), "Upkeep preview did not disclose its whole schedule"): return false
	var result := _execute(fixture, "generated-upkeep")
	if result.is_empty(): return false
	if not require(game.world.state.faith == faith - fixture.preview.faith - fixture.preview.first_upkeep and result.maintenance_remaining == 2, "Upkeep did not charge its first installment on success"): return false
	var restored := _restore(game, "upkeep")
	if restored == null or not require(_advance(restored, 3), "Upkeep failed to advance after load"): return false
	var data := Space.ledger(restored.world.state)
	return require(data.scenes[fixture.id].maintenance.paid == 2 and data.scenes[fixture.id].maintenance.remaining == 1, "Upkeep failed to resume from the next installment")

func _sanity_and_followup(fixture: Dictionary) -> bool:
	var game: RefCounted = fixture.game
	var result := _execute(fixture, "generated-sanity")
	if result.is_empty(): return false
	if not require(result.actual_deltas.sanity < 0 and result.outcome in ["success", "deep"], "Success sanity loss was omitted or treated as disaster"): return false
	var data := Space.ledger(game.world.state)
	var root: Dictionary = data.generation.situations[data.scenes[fixture.id].situation_id]
	if not require(root.objects.incident.status == "safe" and root.has("opportunity"), "Real rescue did not update the shared incident and follow-up"): return false
	var root_id: String = root.id
	# The fixture narrows the initial rescue. Let the next round see the authored
	# follow-up recipes through the ordinary generator after that rescue.
	var generator: RefCounted = game.modules.prayers.space.generator
	generator.effect_ids = generator.content.generator_tables.effects.keys()
	generator.effect_ids.sort()
	var source: String = root.opportunity.source
	if not require(_advance(game, 2), "Could not advance rescued incident"): return false
	data = Space.ledger(game.world.state)
	for next: Dictionary in data.scenes.values():
		if next.generation_meta.get("followup_source", "") == source:
			return require(next.situation_id == root_id and next.generation_meta.depth == 1 and not data.generation.situations[root_id].has("opportunity"), "Follow-up cloned the root or left a second offer")
	return require(false, "Rescue did not produce its authored next decision")

func _old_archives(paths: Array) -> bool:
	for path: String in paths:
		var game := Session.new("user://generator-probe/legacy")
		var copy := "user://generator-probe/legacy-%d.json" % Time.get_ticks_usec()
		if not require(DirAccess.copy_absolute(path, ProjectSettings.globalize_path(copy)) == OK, "Could not isolate the old archive"): return false
		var loaded := game.continue_game(copy)
		if not require(loaded.ok, "Old contract could not load: " + str(loaded)): return false
		var data := Space.ledger(game.world.state)
		if not require(not data.scenes.is_empty() and not data.has("generation"), "Old contracts changed on load"): return false
		if not require(_advance(game, int(game.world.state.turn) + 1), "Old contract could not continue with generator installed"): return false
		if not require(Space.ledger(game.world.state).has("generation"), "Old save did not adopt generator after advance"): return false
	return true
