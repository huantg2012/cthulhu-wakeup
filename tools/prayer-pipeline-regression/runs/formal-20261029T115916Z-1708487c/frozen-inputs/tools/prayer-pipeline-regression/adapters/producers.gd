extends "res://tools/prayer-producers/run.gd"
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")
var ppr_kinship_prerequisites: Array = []

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PP-CATALOG", "Current formal CSV Catalog loads", loaded, {"errors": catalog.errors})
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	if loaded: run_producer_cases()
	_write_producer_report()

func _producer_native(seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = Support.new_world(catalog, seed_value)
	return {"world": world, "source": world.state.domains["DOMAIN-001"].origin}

func _write_producer_report() -> void:
	Support.write_report(records, "current_origin_component_regression", ["Standalone source-backed named prerequisites; source generation uses the actual registered pipeline.", {"kinshipInputs": ppr_kinship_prerequisites}], ["Conditional component production; no five new root families or natural campaign guarantee."])
	quit(0 if records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _local_people(world: RefCounted) -> Array:
	return Support.ordered_people(world)

func _given_relation(data: Dictionary, first: String, second: String, kind: String) -> String:
	return Support.existing_relation(data.world, first, second, kind)

func _rescue_prerequisite(data: Dictionary, petitioner: String, patient: String, due: int, delayed: bool = false, empty_crisis: bool = false) -> Dictionary:
	var result: Dictionary = super._rescue_prerequisite(data, petitioner, patient, due, delayed, empty_crisis)
	result["explicitPrerequisite"] = {"seed": str(data.world.randoms.generation.seed), "patient": patient, "petitioner": petitioner, "source": Support.existing_relation(data.world, petitioner, patient, "family"), "scope": "Actual initial graph kinship and explicit existing injury consumer input; no natural injury producer claim."}
	ppr_kinship_prerequisites.append(result.explicitPrerequisite.duplicate(true))
	return result
