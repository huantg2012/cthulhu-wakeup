extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Space = preload("res://src/game/prayer_space.gd")
const Powers = preload("res://src/game/powers.gd")
const Rules = preload("res://src/game/prayer_rules.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var count := 0

func require(value: bool, message: String) -> bool:
	count += 1
	if not value:
		push_error("PRAYER_DICE: " + message)
		quit(1)
	return value

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--legacy-only":
		if legacy(arguments[1]):
			print("PRAYER_DICE_LEGACY_OK ", count, " checks")
			quit(0)
		return
	var session := Session.new("user://prayer-dice-probe/%d" % Time.get_ticks_usec())
	var opened: Dictionary = session.start_new(1)
	if not require(opened.get("ok", false), "start: " + str(opened)): return
	if session.turn.context.phase == "events":
		if not require(session.progress().get("ok", false), "events handoff"): return
	# Raw score is 115: subtracting 30 before clamping yields 85, not 60.
	var checks := Powers.new(session.catalog)
	var person := {"sanity": 80, "insight": 8}
	var domain := {"tier": "planet", "barrier": 0, "alert": 0}
	var check := {"attribute": "insight", "check_kind": "occult", "difficulty": 30}
	if not require(checks.probability(person, domain, check, 0) == 85, "difficulty was applied after clamping"): return
	# Every authored hidden pool uses exactly 1..P, including all boundary points.
	var pool_sizes := {}
	for contract: Dictionary in session.catalog.prayer_space.tables.response_contracts.values():
		if contract.disclosure != "unknown": continue
		pool_sizes[contract.outcomes.size()] = true
		var ranges := Space._effect_ranges(contract.outcomes, 37)
		var coverage: Array[int] = []; coverage.resize(38); coverage.fill(0)
		for interval: Dictionary in ranges:
			if not require(interval.first <= interval.last, "hidden branch has no integer point"): return
			for point: int in range(interval.first, interval.last + 1): coverage[point] += 1
			if not require(Space._effect_for_roll(contract.outcomes, ranges, interval.first).effect.id == interval.id and Space._effect_for_roll(contract.outcomes, ranges, interval.last).effect.id == interval.id, "interval boundary picked a different branch"): return
		if not require(coverage.slice(1).all(func(value: int) -> bool: return value == 1) and Space._effect_for_roll(contract.outcomes, ranges, 38).is_empty(), "hidden intervals have a gap, overlap, or failure spill"): return
		if not require(Space._effect_ranges(contract.outcomes, contract.outcomes.size() - 1).is_empty(), "too many branches were accepted"): return
	if not require(pool_sizes.has(2) and pool_sizes.has(3) and pool_sizes.has(4), "authored hidden pools do not vary across 2/3/4 branches"): return
	var chosen: Dictionary = {}
	var varying := false
	for entry: Dictionary in session.modules.prayers.space_entries(session.world.state):
		var targets := {}
		for option: Dictionary in session.modules.prayers.space_choices(session.world.state, entry.id):
			var key: String = "prayer/" + entry.id + "/" + option.id
			var preview: Dictionary = session.preview_action(key)
			if not preview.get("ok", false): continue
			targets[int(preview.preview.success_target)] = true
			if option.approach == "bargain": chosen = {"id": entry.id, "choice": option.id, "key": key, "preview": preview.preview}
		if targets.size() > 1: varying = true
	if not require(varying and not chosen.is_empty(), "same-subject targets did not vary or natural bargain missing"): return
	var before: String = session.world.snapshot()
	if not require(not session.execute_action(chosen.key, {"preparations": ["missing-preparation"]}, true).get("ok", false) and session.world.snapshot() == before, "invalid preparation charged or advanced RNG"): return
	var scene: Dictionary = session.world.state.prayer_system.space.scenes[chosen.id]
	var declaration: String = "PRAYER/" + chosen.id + "/" + chosen.choice
	if not require(Rules.prayer_target(session.world.state, declaration, scene.roles.petitioner), "existing oracle cannot target new prayer"): return
	# Detached view verifies the existing preparation eligibility and cap without
	# inventing a production oracle source or changing the live campaign.
	var view: Dictionary = session.turn._read_view("prayers", "actions")
	view.world = view.world.duplicate(true)
	var unprepared: Dictionary = session.modules.prayers.space.prepare(view, chosen.id, chosen.choice, {})
	view.world.power_system.preparations[scene.source] = {"npc": scene.roles.petitioner, "action": declaration, "expires": session.world.state.turn, "amount": 100, "source": scene.source}
	var prepared: Dictionary = session.modules.prayers.space.prepare(view, chosen.id, chosen.choice, {"preparations": [scene.source]})
	if not require(prepared.get("ok", false) and prepared.preparation == 100 and prepared.probability >= unprepared.probability and prepared.preparations == [scene.source], "existing qualified preparation did not enter prayer check"): view.reader.close(); return
	view.world.power_system.preparations[scene.source].action = "PRAYER/" + chosen.id + "/choice_z"
	if not require(not session.modules.prayers.space.prepare(view, chosen.id, chosen.choice, {"preparations": [scene.source]}).get("ok", false), "preparation for another response was accepted"): view.reader.close(); return
	view.reader.close()
	var rng := RandomNumberGenerator.new(); rng.state = session.world.randoms.checks.state
	var roll := rng.randi_range(1, 100)
	var metrics_before := Space._metrics(session.world.state, scene)
	var response: Dictionary = session.execute_action(chosen.key, {}, true, "dice-trade")
	if not require(response.get("ok", false), "bargain submit: " + str(response)): return
	scene = session.world.state.prayer_system.space.scenes[chosen.id]
	var result: Dictionary = Store.entry(session.world.state.facts, scene.response).changes
	if not require(result.roll == roll and result.success_target == chosen.preview.success_target and session.world.randoms.checks.state == rng.state and not result.check.is_empty(), "bargain bypassed its D100"): return
	var after_metrics := Space._metrics(session.world.state, scene)
	for field: String in metrics_before:
		if not require(result.actual_deltas[field] == after_metrics[field] - metrics_before[field], "bargain receipt misstated actual " + field): return
	var snapshot: String = session.world.snapshot()
	if not require(session.execute_action(chosen.key, {}, true, "dice-trade").get("ok", false) and session.world.snapshot() == snapshot, "bargain replay recharged or rerolled"): return
	var saved: Dictionary = session.save_game()
	var restored := Session.new("user://prayer-dice-probe/restored")
	if not require(saved.get("ok", false) and restored.continue_game(saved.path).get("ok", false) and restored.world.snapshot() == snapshot, "bargain save/restore changed the result"): return
	var bad: Dictionary = session.world.state.duplicate(true)
	bad.facts = {}
	for id: String in Store.keys(session.world.state.facts): bad.facts[id] = Store.entry(session.world.state.facts, id).duplicate(true)
	bad.facts[scene.response].changes.actual_deltas.alert += 1
	if not require(not Space.validate(bad, session.catalog).is_empty(), "receipt tamper was accepted"): return
	var args := OS.get_cmdline_user_args()
	print("PRAYER_DICE_CORE_OK ", count, " checks; bargain seed=1 ", chosen.id, "/", chosen.choice, " target=", result.success_target, " roll=", result.roll)
	if not require(not args.is_empty(), "pass the real b9d5992 fixture path after --"): return
	if not legacy(args[0]): return
	print("PRAYER_DICE_OK ", count, " checks; bargain seed=1 ", chosen.id, "/", chosen.choice, " target=", result.success_target, " roll=", result.roll)
	quit(0)

func legacy(path: String) -> bool:
	var original := FileAccess.get_file_as_bytes(path)
	var available := {}
	var initial := Session.new("user://prayer-dice-probe/legacy-scan")
	var loaded: Dictionary = initial.continue_game(path)
	if not require(loaded.get("ok", false), "b9d5992 restore: " + str(loaded)): return false
	for scene: Dictionary in initial.world.state.prayer_system.space.scenes.values():
		for option: Dictionary in scene.choices.values():
			if option.get("check_kind") == "deterministic": available["deterministic"] = [scene.id, option.id]
			if option.get("disclosure") == "unknown": available["unknown"] = [scene.id, option.id]
	if not require(not available.is_empty(), "old fixture lacks a trade/unknown response"): return false
	for kind: String in available:
		var old := Session.new("user://prayer-dice-probe/legacy-" + kind)
		var branch_path := path + "." + kind + ".json"
		var file := FileAccess.open(branch_path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
		if not require(old.continue_game(branch_path).get("ok", false), "legacy fixture reopen"): return false
		var pair: Array = available[kind]
		var scene: Dictionary = old.world.state.prayer_system.space.scenes[pair[0]]
		if not require(not scene.choices[pair[1]].has("difficulty"), "legacy contract silently upgraded"): return false
		var rng_state: int = old.world.randoms.checks.state
		var response: Dictionary = old.execute_action("prayer/" + pair[0] + "/" + pair[1], {}, true)
		if not require(response.get("ok", false), "legacy " + kind + " submit: " + str(response)): return false
		scene = old.world.state.prayer_system.space.scenes[pair[0]]
		var result: Dictionary = Store.entry(old.world.state.facts, scene.response).changes
		if kind == "deterministic":
			if not require(result.probability == -1 and result.roll == 0 and old.world.randoms.checks.state == rng_state, "old deterministic bargain changed semantics"): return false
		else:
			var detail: Dictionary = Store.entry(old.world.state.facts, result.twist, {}).get("changes", {})
			if result.outcome in ["success", "deep"]:
				if not require(detail.has("seed") and not detail.has("method"), "old successful unknown did not retain second seeded draw"): return false
			elif not require(str(result.get("twist", "")).is_empty(), "old failed unknown invented a branch"): return false
			print("LEGACY_UNKNOWN ", result.outcome, " roll=", result.roll, " P=", result.probability)
		var saved: Dictionary = old.save_game()
		var restored := Session.new("user://prayer-dice-probe/legacy-restored-" + kind)
		if not require(saved.get("ok", false) and restored.continue_game(saved.path).get("ok", false), "old result no longer saves/restores"): return false
	return true
