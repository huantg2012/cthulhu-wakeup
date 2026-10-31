extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var checks: Array = []
var output: String

func _initialize() -> void:
	output = OS.get_cmdline_user_args()[0]
	var catalog: RefCounted = Catalog.new()
	if not _check("CAT-CATALOG-LOAD", catalog.load_files() and Catalog.FILES.size() == 10, {"errors": catalog.errors, "tables": catalog.tables.keys()}): return
	for name: String in Catalog.FILES:
		if not _check("CAT-TABLE-" + name, catalog.tables.has(name)): return
	if not _bad_catalog(): return
	for seed_value: int in [200, 201]:
		if not _world(catalog, seed_value): return
	var altered: RefCounted = Catalog.new()
	if not _check("CAT-BOUND-LOAD", altered.load_files()): return
	var world: RefCounted = World.new(altered)
	if not _check("CAT-BOUND-BASE", world.generate(200)): return
	var before: String = world.snapshot()
	for id: String in altered.tables.civilization_profiles.keys():
		if altered.tables.civilization_profiles[id].tier == "cosmic": altered.tables.civilization_profiles.erase(id)
	var constrained: String = World.canonical(altered.tables)
	var started: int = Time.get_ticks_usec()
	var refused: bool = not world.generate(1)
	if not _check("CAT-BOUND", refused and "cosmic" in world.last_error and world.snapshot() == before and constrained == World.canonical(altered.tables), {"reason": world.last_error, "generate_calls": 1, "elapsed_usec": Time.get_ticks_usec() - started, "finite_recipe": "src/simulation/world_initialization.gd:plan; finite tier/profile/resident enumeration, empty candidate returns failure"}): return
	_finish(true)

func _check(id: String, valid: bool, details: Dictionary = {}) -> bool:
	checks.append({"id": id, "status": "pass" if valid else "fail", "details": details})
	print(("PASS " if valid else "FAIL ") + id)
	if not valid: _finish(false)
	return valid

func _finish(valid: bool) -> void:
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "ok": valid}, "  "))
	file.close()
	quit(0 if valid else 1)

func _catalog_state(content: RefCounted) -> String:
	return World.canonical({"tables": content.tables, "parameters": content.parameters, "version": content.version, "extensions": content.extension_versions})

func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _bad_catalog() -> bool:
	var directory: String = output.get_base_dir().path_join("csv-fixture")
	DirAccess.make_dir_recursive_absolute(directory)
	var originals: Dictionary = {}
	for name: String in Catalog.FILES + Catalog.EXTENSIONS + ["fidelity_parameters"]:
		originals[name] = FileAccess.get_file_as_string("res://data/" + name + ".csv")
		_write(directory.path_join(name + ".csv"), originals[name])
	var content: RefCounted = Catalog.new()
	if not _check("CAT-FIXTURE-LOAD", content.load_files(directory), {"errors": content.errors}): return false
	var before: String = _catalog_state(content)
	for mutation: Dictionary in [
		{"id": "field", "table": "npc_profiles", "from": "", "to": ""},
		{"id": "reference", "table": "civilization_conditions", "from": "CIV_01,", "to": "CIV_UNKNOWN,"},
		{"id": "value", "table": "npc_behaviors", "from": "restore_self_sanity,2,2,0", "to": "restore_self_sanity,2,0,0"}]:
		var changed: String = originals[mutation.table]
		if mutation.id == "field":
			var lines: PackedStringArray = changed.split("\n")
			lines[1] = lines[1].substr(0, lines[1].rfind(","))
			changed = "\n".join(lines)
		else: changed = changed.replace(mutation.from, mutation.to)
		if not _check("CAT-MUTATION-" + mutation.id, changed != originals[mutation.table]): return false
		_write(directory.path_join(mutation.table + ".csv"), changed)
		var refused: bool = not content.load_files(directory)
		var errors: Array = Array(content.errors)
		var missing: bool = false
		for error: String in errors: missing = missing or "Missing CSV" in error
		if not _check("CAT-REJECT-" + mutation.id, refused and not errors.is_empty() and not missing and _catalog_state(content) == before, {"errors": errors}): return false
		_write(directory.path_join(mutation.table + ".csv"), originals[mutation.table])
		if not _check("CAT-RESTORE-" + mutation.id, content.load_files(directory) and _catalog_state(content) == before): return false
	return true

func _world(catalog: RefCounted, seed_value: int) -> bool:
	var world: RefCounted = World.new(catalog)
	if not _check("CAT-GENERATE-%d" % seed_value, world.generate(seed_value), {"error": world.last_error}): return false
	var issues: Array = Array(world.validate_state(world.state))
	var valid: bool = issues.is_empty() and world.state.domains.size() == catalog.integer("domains_total") and Store.size(world.state.npcs) == catalog.integer("domains_total") * catalog.integer("initial_named_per_domain") and world.state.institutions.size() == catalog.integer("domains_total") * catalog.integer("institutions_per_domain")
	var tiers: Dictionary = {"planet": 0, "system": 0, "cosmic": 0}
	var reached: Array = ["DOMAIN-001"]
	for index: int in catalog.integer("domains_total"):
		if index >= reached.size(): break
		for neighbor: String in world.state.domains[reached[index]].neighbors:
			if not reached.has(neighbor): reached.append(neighbor)
	for domain: Dictionary in world.state.domains.values():
		tiers[domain.tier] += 1
		var named: int = 0
		for npc: Dictionary in Store.values(world.state.npcs):
			if npc.domain == domain.id:
				named += 1
				valid = valid and world._profile_legal(catalog.tables.npc_profiles[npc.profile], npc.domain, npc.institution)
		valid = valid and named == catalog.integer("initial_named_per_domain") and int(domain.population) == catalog.integer("domain_population") and int(domain.population) == named + int(domain.unnamed_nonfollowers) + int(domain.unnamed_followers) and domain.institutions.size() == catalog.integer("institutions_per_domain")
		for neighbor: String in domain.neighbors:
			valid = valid and world.state.domains.has(neighbor) and domain.id in world.state.domains[neighbor].neighbors
	for tier: String in tiers: valid = valid and tiers[tier] == catalog.integer(tier + "_domains")
	valid = valid and reached.size() == catalog.integer("domains_total") and not world._profile_legal(catalog.tables.npc_profiles.NPC_PROFILE_04, "DOMAIN-001", "") and not world._profile_legal(catalog.tables.npc_profiles.NPC_PROFILE_06, "DOMAIN-001", "DOMAIN-001/propagation")
	return _check("CAT-WORLD-%d" % seed_value, valid, {"issues": issues, "tiers": tiers, "reachable": reached.size(), "named": Store.size(world.state.npcs), "institutions": world.state.institutions.size()})
