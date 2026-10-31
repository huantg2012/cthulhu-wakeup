extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE); file.store_string(text); file.close()
func _initialize() -> void:
	if not FileAccess.file_exists("res://attention-policy-scratch-only"): quit(2); return
	var catalog: RefCounted = Catalog.new(); assert(catalog.load_files())
	var original: RefCounted = World.new(catalog); assert(original.generate_hybrid(7919))
	var saved: String = original.snapshot()
	var cases: Array = [
		["intervention_policies", "PRAYER_09,shallow,target,participants", "PRAYER_09,shallow,unknown_scope,participants"],
		["intervention_policies", "system,MEMBER_ENROLL,use", "system,UNKNOWN_ENROLL,use"],
		["intervention_policies", "prayer,PRAYER_09,shallow", "prayer,PRAYER_01,shallow"],
		["intervention_policies", "power,POWER_DREAM,use", "power,POWER_UNKNOWN,use"],
		["fidelity_parameters", "temporary_actor_limit,12,person,hybrid", "temporary_actor_limit,0,person,hybrid"],
		["fidelity_parameters", "local_actor_limit,6,person_per_focused_domain,hybrid", "local_actor_limit,2,person_per_focused_domain,hybrid"]]
	var checks: Array = []; var ok: bool = true
	for row: Array in cases:
		var path: String = "res://data/" + row[0] + ".csv"
		var text: String = FileAccess.get_file_as_string(path); assert(text.contains(row[1]))
		_write(path, text.replace(row[1], row[2]))
		var target: RefCounted = World.new(catalog); assert(target.generate(1981))
		var before: String = target.snapshot()
		var rejected: bool = target.attention.version.is_empty() and not target.restore(saved) and before == target.snapshot() and not target.generate_hybrid(7919) and before == target.snapshot()
		checks.append({"table": row[0], "mutation": row[2], "restoreAndGenerationRejectedWithoutChanges": rejected})
		ok = ok and rejected
		_write(path, text)
		assert(World.new(catalog).attention.version == original.attention.version)
	var output: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	output.store_string(JSON.stringify({"status": "pass" if ok else "fail", "cases": checks}, "\t", true, true)); output.close()
	quit(0 if ok else 1)
