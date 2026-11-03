extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const Semantics = preload("res://src/presentation/experience_semantics.gd")
func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_files():
		push_error("Could not load formal catalog")
		quit(1)
		return
	var semantics := Semantics.new()
	var result: Dictionary = {"scope":"CSV-derived presentation semantics only; no T46 world or outcome probabilities are implied", "content":"PRAYER_05", "definition":catalog.tables.prayers["PRAYER_05"], "shallow":semantics.prayer(catalog, "PRAYER_05", "shallow"), "deep":semantics.prayer(catalog, "PRAYER_05", "deep")}
	var file := FileAccess.open("res://docs/art/echoes-ui/runtime/semantic-sample.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("SEMANTIC_SAMPLE_OK")
	quit(0)
