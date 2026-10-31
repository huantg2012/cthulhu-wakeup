extends SceneTree
## Adaptation of the original OQ-POLICY finite-options arithmetic regression.
## Consumer tokens below are fixtures, not world source production or admissions.
const Catalog = preload("res://src/simulation/catalog.gd")
const SourcePolicy = preload("res://src/game/source_fairness.gd")

func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_files(): push_error("Current CSV failed to load"); quit(1); return
	var options: Array = []
	for root: String in SourcePolicy.roots(): options.append({"root": root, "weight": 1})
	var cursor: Dictionary = {}
	for value: int in range(1, 101):
		var rng := RandomNumberGenerator.new(); rng.seed = value
		var before: String = str(rng.state)
		if rng.randi_range(1, 100) > catalog.integer("ambient_event_chance"):
			cursor = {"seed": str(value), "state": before, "next_turn": 0}; break
	if cursor.is_empty(): push_error("Original adverse policy cursor unavailable"); quit(1); return
	var threshold: int = catalog.integer("forced_after_missed_slots")
	var due_bound: int = threshold + options.size()
	var state: Dictionary = SourcePolicy.initial(); var sequence: int = 1
	var produced: Dictionary = {}; var evidence: Array = []
	var no_extra_rng: bool = true; var cooldown_exact: bool = true; var finite: bool = true
	for slot: int in range(1, due_bound + 1):
		var selected: Dictionary = SourcePolicy.select(state, options, cursor, true, catalog)
		var root: String = ""; var token: String = ""; var attempts: Array = []
		if selected.mode == "forced":
			no_extra_rng = no_extra_rng and selected.random_after == cursor.state
			root = selected.forced_roots[0]; token = "consumer/" + str(slot)
			attempts.append({"root": root, "outcome": "consumer_success"})
		elif not selected.choice.is_empty(): root = selected.choice.root; token = "consumer/" + str(slot)
		if not root.is_empty() and not produced.has(root): produced[root] = slot
		var after: Dictionary = SourcePolicy.finish(state, sequence, options, attempts, root, token, slot * catalog.integer("background_tick_interval"), true, catalog)
		for cooling: String in selected.cooling:
			cooldown_exact = cooldown_exact and after.sources[cooling].cooldown == 0 and after.sources[cooling].missed_due_slots == state[cooling].missed_due_slots and after.sources[cooling].queue_seq == 0
		finite = finite and selected.forced_roots.size() <= options.size() and SourcePolicy.validate_shape(after.sources, after.next_queue_seq).is_empty()
		evidence.append({"slot": slot, "mode": selected.mode, "forced": selected.forced_roots, "success": root, "cooling": selected.cooling})
		state = after.sources; sequence = after.next_queue_seq
	var weighted: Dictionary = SourcePolicy.initial(); weighted.ROOT_IDENTITY_NOTICE.missed_due_slots = 1
	var selection: Dictionary = SourcePolicy.select(weighted, [{"root": "ROOT_IDENTITY_NOTICE", "weight": 7}, {"root": "ROOT_CURRENT_APPEAL"}], cursor, true, catalog)
	var scale: int = catalog.integer("base_source_weight_scale")
	var weights_correct: bool = selection.weights == {"ROOT_IDENTITY_NOTICE": 7 * scale + catalog.integer("missed_slot_weight_step"), "ROOT_CURRENT_APPEAL": scale}
	var idle: Dictionary = SourcePolicy.finish(weighted, 1, options, [], "", "", 0, false, catalog)
	var unknown: Dictionary = SourcePolicy.select(weighted, [{"root": "ROOT_KNOWN_RECORD"}], cursor, true, catalog)
	var bound: bool = options.size() == 11 and produced.size() == options.size() and produced.values().all(func(value: int) -> bool: return value <= due_bound)
	var passed: bool = bound and weights_correct and finite and cooldown_exact and no_extra_rng and idle.sources == weighted and not unknown.ok and SourcePolicy.binding_errors().is_empty()
	var report: Dictionary = {"status": "pass" if passed else "fail", "checks": [{"id": "OQ-POLICY", "status": "pass" if passed else "fail", "details": {"kind": "original_finite_policy_options_not_world_production", "forcedAfterMissedSlots": threshold, "boundedProduction": bound, "firstSuccessDueSlot": produced, "conditionalBoundTurns": catalog.integer("background_tick_interval") * due_bound, "weights": selection.weights, "cooldownExact": cooldown_exact, "forcedConsumesNoRNG": no_extra_rng, "finite": finite, "unknownRootRejected": not unknown.ok, "notDueUnchanged": idle.sources == weighted, "evidence": evidence}}]}
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	quit(0 if passed else 1)
