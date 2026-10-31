extends "res://tools/social-graph-restore/run.gd"

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("SGI-CATALOG", loaded, {"errors": catalog.errors})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	scratch = args[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	if loaded:
		_catalog_cases()
		_control_cases()
		_world_cases()
		_business_cases()
		_lifecycle_cases()
		_state_cases()
		_scale_cases()
		_profile_baseline_cases()
		_projection_cases()
		_normal_projection_cases()
		_episode_history_cases()
		_birth_cases()
		_focus_restore_cases()
		_bootstrap_cases()
		_combination_cases()
		_admission_cases()
	var passed: bool = checks.all(func(row: Dictionary) -> bool: return row.status == "pass")
	_write(args[0], {"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string,
		"checks": checks, "executionScope": "real_social_graph_birth_and_restore_components",
		"currentRegression": {"total": 101, "initializationOriginalBehaviorRequirements": 50, "relationChecks": 51, "initializationWriterPrerequisiteAdaptation": 2, "additionalPersistentSchemaAuditAdaptation": "_audit_graph accepts persistent Graph2; fact/model1, source/budget/heads/privacy requirements remain. Do not describe all other 48 checks as byte-identical execution.", "explicitPrerequisiteAdaptations": {"functions": ["_first_focus_cases", "_plan_fixture"], "checks": ["SGI-WORLD/ACTUAL-FIRST-FOCUS", "SGI-WORLD/OLD-BOOTSTRAP-EXCLUDED", "SGI-WORLD/REPEATED-FOCUS", "SGI-WORLD/NOMINATION-NO-GRAPH", "SGI-WORLD/EMPTY-FIRST-FOCUS", "SGI-ATOMIC/PLAN-RESERVE", "SGI-ATOMIC/CAPACITY-HOLD"], "change": "Prior identities use actual Attention identity reservation and World.submit standalone nomination; no false first-focus provenance. Original assertions retained."}},
		"limitations": ["Protected suites execute in this new archive; their historical reports are unchanged.", "Outer relation-business fixtures remain explicit component prerequisites, not full or natural prayer/event transactions.", "Full Session and natural source production remain outside this World/Turn audit."]})
	quit(0 if passed else 1)

func _write(path: String, value: Variant) -> void:
	if path == OS.get_cmdline_user_args()[0] and value is Dictionary:
		value = value.duplicate(true)
		value["explicitPrerequisiteAdaptations"] = ["Identical Graph166 functions and assertions; artifacts redirected to this new run archives only."]
	super._write(path, value)
