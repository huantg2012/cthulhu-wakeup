extends "res://tools/prayer-producers/run.gd"
## Binding controls use actual installed modules and the formal Events table.
## Mutations are local fixture counterfactuals, restored before each next check.
var policy_world: RefCounted

func _replace_policy(_view: Dictionary, _input: Dictionary) -> Dictionary:
	policy_world.abstract_sim.responsibilities = {}
	return {"ok": true}

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files():
		_check("CG-CATALOG", "Current content loads", false, {"errors": catalog.errors})
	else:
		var data: Dictionary = _producer_world()
		policy_world = data.world
		var policy: Dictionary = data.world.abstract_sim.responsibilities
		var replacement: Dictionary = data.turn._call_guarded(_replace_policy, data.turn._read_view("events", "preview"), {})
		_check("CG-RUNTIME-WIRING", "Installed binding is valid; authored policy is sealed and replacement is rejected", not replacement.ok and is_same(policy, data.world.abstract_sim.responsibilities) and data.events.generation_binding_errors(data.world, data.turn).is_empty() and policy.is_read_only() and policy.candidate_generation.is_read_only())
		var modes: Dictionary = data.events.mode_handlers.duplicate()
		data.events.mode_handlers.erase("detailed_candidates")
		_check("CG-RUNTIME-MISSING", "Missing detailed mode is identified", "; ".join(data.events.generation_binding_errors(data.world, data.turn)).contains("detailed_candidates"))
		data.events.mode_handlers = modes.duplicate()
		data.events.mode_handlers.detailed_candidates = Callable(data.events, "abstract_candidates_due")
		_check("CG-RUNTIME-WRONG", "Wrong detailed callable is identified", "; ".join(data.events.generation_binding_errors(data.world, data.turn)).contains("detailed_candidates"))
		data.events.mode_handlers = modes.duplicate()
		data.turn._participants["duplicate-fixture"] = {"slots": ["candidate_generation"]}
		_check("CG-RUNTIME-DUPLICATE", "Duplicate registered owner is identified", "; ".join(data.events.generation_binding_errors(data.world, data.turn)).contains("one registered Events owner"))
		data.turn._participants.erase("duplicate-fixture")
		var roots: Dictionary = data.events.candidate_handlers.duplicate()
		var missing: Array = []; var wrong: Array = []
		for root: String in roots:
			data.events.candidate_handlers.erase(root)
			if not "; ".join(data.events.generation_binding_errors(data.world, data.turn)).contains(root): missing.append(root)
			data.events.candidate_handlers = roots.duplicate()
			data.events.candidate_handlers[root] = Callable(data.events, "detailed_candidates")
			if not "; ".join(data.events.generation_binding_errors(data.world, data.turn)).contains(root): wrong.append(root)
			data.events.candidate_handlers = roots.duplicate()
		_check("CG-RUNTIME-ROOTS", "All installed root bindings reject removal and wrong methods", missing.is_empty() and wrong.is_empty(), {"count": roots.size(), "missingUndetected": missing, "wrongUndetected": wrong})
		# Simulate a producer declaration disappearing while authored CSV remains.
		# Producers.ROOTS is a read-only constant: an Events subclass cannot alter
		# it at runtime, so static CG-STATIC-DECLARED-ROOT supplies that mutation.
		var declared: Array = []
		for root: String in catalog.tables.prayer_root_rules:
			if not root in ["ROOT_INITIAL_TIES", "ROOT_SHARED_OBSERVATION"]: declared.append(root)
		_check("CG-RUNTIME-DECLARED-ROOTS", "Installed direct roots match independent authored CSV", declared.size() == roots.size() and declared.all(func(root: String) -> bool: return roots.has(root)))
	var passed: bool = records.size() == 6 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "scope": "installed_candidate_binding_controls", "limitations": ["Counterfactual wiring checks; no candidate-output or full Session acceptance."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)
