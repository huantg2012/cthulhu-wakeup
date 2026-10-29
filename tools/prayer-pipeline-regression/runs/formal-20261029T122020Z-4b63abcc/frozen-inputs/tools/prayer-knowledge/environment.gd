extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")

func _initialize() -> void:
	var catalog: RefCounted = Catalog.new()
	var loaded: bool = catalog.load_files()
	var result: Dictionary = {
		"status": "pass" if loaded else "fail",
		"executionScope": "catalog_environment_probe",
		"engine": Engine.get_version_info().string,
		"checks": [{"id": "PK-ENV-CATALOG", "name": "Current authored Catalog loads without replacing rule data", "status": "pass" if loaded else "fail", "details": {"errors": catalog.errors, "tables": catalog.tables.keys(), "content": catalog.version}}],
		"limitations": ["No prayer knowledge behavior or natural production was exercised."]
	}
	var output: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write fresh prayer knowledge environment evidence")
		quit(2)
		return
	output.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	output.close()
	print("PRAYER-KNOWLEDGE ENVIRONMENT ", result.status, " catalog_errors=", catalog.errors.size())
	quit(0 if loaded else 1)
