extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Abstract = preload("res://src/simulation/abstract_sim.gd")
func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text); file.close()
func _initialize() -> void:
	if not FileAccess.file_exists("res://abstract-policy-scratch-only"): quit(2); return
	var catalog: RefCounted = Catalog.new(); assert(catalog.load_files())
	var original: RefCounted = World.new(catalog); assert(original.generate(7919))
	assert(original.configure_assigned_simulation(["DOMAIN-001"], [], [], "DOMAIN-002"))
	var saved: String = original.snapshot()
	var cases: Array = [
		["fidelity_parameters", "background_tick_interval,4,turn,hybrid", "background_tick_interval,0,turn,hybrid"],
		["fidelity_parameters", "background_candidate_trials,1,trial_per_due_domain,hybrid", "background_candidate_trials,1.5,trial_per_due_domain,hybrid"],
		["fidelity_parameters", "pending_candidate_limit,8,candidate,hybrid", "pending_candidate_limit,8,candidate,indexed"],
		["simulation_responsibilities", "civilization_routine,detailed,abstract_due,world,4", "civilization_routine,detailed,abstract_due,economy,4"],
		["background_templates", "BG_CONTACT,PRAYER_08", "BG_CONTACT,PRAYER_99"],
		["background_templates", "BG_RECORD,PRAYER_04,known_history", "BG_RECORD,PRAYER_04,current_background"]]
	var checks: Array = []
	var valid: bool = true
	for row: Array in cases:
		var path: String = "res://data/" + row[0] + ".csv"
		var text: String = FileAccess.get_file_as_string(path)
		assert(text.contains(row[1]))
		_write(path, text.replace(row[1], row[2]))
		var policy: RefCounted = Abstract.new(catalog)
		var target: RefCounted = World.new(catalog); assert(target.generate(1981))
		var before: String = target.snapshot()
		var rejected: bool = policy.version.is_empty() and not policy.errors.is_empty() and not target.restore(saved) and before == target.snapshot()
		checks.append({"table": row[0], "mutation": row[2], "rejectedWithoutSessionChange": rejected})
		valid = valid and rejected
		_write(path, text)
		assert(Abstract.new(catalog).version == original.abstract_sim.version)
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if valid else "fail", "cases": checks}, "\t", true, true)); file.close()
	quit(0 if valid else 1)
