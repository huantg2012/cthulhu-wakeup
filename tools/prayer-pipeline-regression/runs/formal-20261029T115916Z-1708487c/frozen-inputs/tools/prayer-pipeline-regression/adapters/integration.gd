extends "res://tools/prayer-integration/run.gd"
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")
var ppr_kinship_prerequisites: Array = []

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PI-CATALOG", "Formal current Catalog loads", loaded, {"errors": catalog.errors})
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	if loaded:
		for mode: String in ["focused", "background"]:
			for addressing: String in ["directed", "undirected"]:
				_matrix(mode, addressing, false)
				_matrix(mode, addressing, true)
			_known_undirected(mode)
		_existing_call_capacity()
		for variant: String in ["deadlines_equal", "start_equal", "start_parent", "already_due"]: _action_window(variant)
		_wrapped_record_reopening()
		_session_boundary()
		_projection()
		_member_projection()
	var passed: bool = records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "executionScope": "bounded_prayer_integration_components", "explicitPrerequisiteAdaptations": ["Standalone source-backed named prerequisites and current social graph", {"kinshipInputs": ppr_kinship_prerequisites}], "limitations": ["Explicit record/contact prerequisites; actual dream recognition and runtime request production.", "Projection component uses real modules but keeps PlayerSources uninstalled; formal new Session/continue remain rejected.", "No natural new game, five new root families, campaign balance or visual acceptance."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _producer_native(seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, seed_value)
	return {"world": world, "source": world.state.domains["DOMAIN-001"].origin}

func _local_people(world: RefCounted) -> Array:
	return Support.ordered_people(world)

func _given_relation(data: Dictionary, first: String, second: String, kind: String) -> String:
	return Support.existing_relation(data.world, first, second, kind)

func _rescue_prerequisite(data: Dictionary, petitioner: String, patient: String, due: int, delayed: bool = false, empty_crisis: bool = false) -> Dictionary:
	var result: Dictionary = super._rescue_prerequisite(data, petitioner, patient, due, delayed, empty_crisis)
	result["explicitPrerequisite"] = {"seed": str(data.world.randoms.generation.seed), "patient": patient, "petitioner": petitioner, "source": Support.existing_relation(data.world, petitioner, patient, "family"), "scope": "Actual initial graph kinship and explicit existing injury consumer input; no natural injury producer claim."}
	ppr_kinship_prerequisites.append(result.explicitPrerequisite.duplicate(true))
	return result
