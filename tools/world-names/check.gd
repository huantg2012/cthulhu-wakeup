extends SceneTree
## One short generator and complete Session persistence check; no editor scan.
const Catalog = preload("res://src/simulation/catalog.gd")
const Session = preload("res://src/presentation/session.gd")
const Names = preload("res://src/content/world_names.gd")
const World = preload("res://src/simulation/world.gd")
const DIRECTORY: String = "/tmp/cthulhu-world-names-check"
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: check(false, "fixture writes " + path); return
	file.store_string(value); file.close()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var session := Session.new(DIRECTORY)
	var started: Dictionary = session.start_new(1)
	check(started.ok, "new Session starts")
	if not started.ok:
		print(JSON.stringify({"ok":false, "failures":failures, "error":started.get("error")})); quit(1); return
	var naming: RefCounted = session.catalog.player_text.world_names
	var domains: Dictionary = session.world.state.domains
	var original: String = session.turn.snapshot()
	var all_runs: Dictionary = {}; var examples: Dictionary = {}
	for seed_value: int in range(1, 101):
		var generated: Dictionary = naming.generate(seed_value, domains)
		check(generated.ok, "seed %d generates" % seed_value)
		if not generated.ok: continue
		check(generated == naming.generate(seed_value, domains), "seed %d repeats" % seed_value)
		check(Names.restore({"version":Names.VERSION, "worlds":generated.names, "backgrounds":generated.backgrounds}, domains).ok, "seed %d complete unique names" % seed_value)
		var families: Dictionary = {}
		for family: String in generated.families.values(): families[family] = true
		check(families.size() >= 2, "seed %d mixes naming families" % seed_value)
		var signature: String = World.canonical(generated.names)
		check(not all_runs.has(signature), "seed %d changes names" % seed_value)
		all_runs[signature] = true
		if seed_value <= 2: examples[str(seed_value)] = generated.names
	check(session.turn.snapshot() == original, "naming does not consume gameplay state or RNG")
	var baseline: Dictionary = session._build(1)
	check(baseline.ok, "comparison campaign builds")
	if baseline.ok:
		check(baseline.turn.submit({"id":"session/open/1", "turn":0, "phase":"between", "op":"advance"}).ok, "comparison campaign opens")
		check(baseline.turn.snapshot() == original, "same seeded rules run identically without naming calls")
	var second_world := World.new(session.catalog)
	check(second_world.generate_hybrid(2), "second seeded world builds")
	examples["2"] = naming.generate(2, second_world.state.domains).names
	for tier: String in ["planet", "system", "cosmic"]:
		check(int(naming.capacities.get(tier, 0)) >= 10000, "authored combination capacity " + tier)
	for id: String in domains:
		if session.known_domains().has(id):
			check(session.object_title(id) == session._world_names[id], "known world uses frozen name")
			check(session.world_name_background(id) == session._world_name_backgrounds[id], "known world background reachable")
		else:
			check(session.object_title(id) != session._world_names[id], "unknown world does not leak its name")
			check(session.world_name_background(id).is_empty(), "unknown world does not leak background")
	var saved: Dictionary = session.save_game(DIRECTORY + "/current.json")
	check(saved.ok, "new campaign saves")
	var loaded := Session.new(DIRECTORY)
	check(loaded.continue_game(DIRECTORY + "/current.json").ok, "new campaign continues")
	check(loaded._world_names == session._world_names, "saved names restored exactly")
	check(loaded._world_name_backgrounds == session._world_name_backgrounds, "backgrounds restored exactly")
	check(not Names.restore({"version":Names.VERSION, "worlds":session._world_names, "backgrounds":{"INVALID":"背景"}}, domains).ok, "incomplete context rejected")
	check(not Names.restore({"version":Names.VERSION, "worlds":session._world_names, "unknown":{}}, domains).ok, "unknown identity field rejected")
	var v1: Dictionary = World._normalize_numbers(JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/current.json")))
	v1.body.display_names.version = "world-names/1"
	v1.body.display_names.erase("backgrounds")
	v1.checksum = World.canonical(v1.body).sha256_text()
	write_text(DIRECTORY + "/v1.json", World.canonical(v1))
	var old := Session.new(DIRECTORY)
	check(old.continue_game(DIRECTORY + "/v1.json").ok and old._world_names == session._world_names and old._world_name_backgrounds.is_empty(), "v1 names preserved without fabricated background")
	check(old.save_game(DIRECTORY + "/v1-resaved.json").ok, "v1 resaves")
	check(old.continue_game(DIRECTORY + "/v1-resaved.json").ok and old._world_names == session._world_names, "v1 resaved names preserved")
	check(loaded.turn != null and loaded.turn.snapshot() == original, "save restore retains rule snapshot and RNG")
	# Persisted names intentionally need not exist in the current lexicon.
	var frozen: Dictionary = session._world_names.duplicate(true)
	frozen[frozen.keys()[0]] = "旧词库留下的恒星共同体"
	check(Names.restore({"version":Names.VERSION, "worlds":frozen}, domains).ok, "old lexicon names survive without regeneration")
	var invalid: Dictionary = frozen.duplicate(true)
	invalid[invalid.keys()[1]] = invalid[invalid.keys()[0]]
	check(not Names.restore({"version":Names.VERSION, "worlds":invalid}, domains).ok, "duplicate saved names rejected")
	var envelope: Dictionary = World._normalize_numbers(JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/current.json")))
	envelope.body.erase("display_names")
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	write_text(DIRECTORY + "/legacy.json", World.canonical(envelope))
	var legacy := Session.new(DIRECTORY)
	check(legacy.continue_game(DIRECTORY + "/legacy.json").ok, "save without naming field continues")
	for id: String in domains:
		check(legacy._world_names.get(id) == session.catalog.display_tables.world_names[id].name, "legacy name retained " + id)
	check(legacy.turn != null and legacy.turn.snapshot() == original, "legacy name adoption leaves snapshot intact")
	check(legacy.save_game(DIRECTORY + "/legacy-resaved.json").ok, "legacy name map frozen on resave")
	var legacy_again := Session.new(DIRECTORY)
	check(legacy_again.continue_game(DIRECTORY + "/legacy-resaved.json").ok and legacy_again._world_names == legacy._world_names, "legacy resave continues with same names")
	var parts: String = FileAccess.get_file_as_string("res://data/world_name_parts.csv")
	var patterns: String = FileAccess.get_file_as_string("res://data/world_name_patterns.csv")
	var rows: PackedStringArray = parts.split("\n", false)
	var bad_parts: Array[String] = ["id,pool,text\n", parts + rows[1] + "\n", parts + "DUP_" + rows[1] + "\n"]
	for index: int in bad_parts.size():
		write_text(DIRECTORY + "/world_name_parts.csv", bad_parts[index])
		write_text(DIRECTORY + "/world_name_patterns.csv", patterns)
		check(not naming.load_files(session.catalog.tables.civilization_profiles, DIRECTORY), "bad parts rejected %d" % index)
	write_text(DIRECTORY + "/world_name_parts.csv", parts)
	for suffix: String in ["INVALID,planet,council,formal,{missing_pool}星球议会,背景,2\n", "INVALID,planet,unified,formal,{missing_pool}星球共同体,背景,2\n", "INVALID,planet,council,formal,{bad-token}星球议会,背景,2\n"]:
		write_text(DIRECTORY + "/world_name_patterns.csv", patterns + suffix)
		check(not naming.load_files(session.catalog.tables.civilization_profiles, DIRECTORY), "bad structure rejected " + suffix.strip_edges())
	check(naming.generate(1, domains).names == examples["1"], "invalid catalog load preserves previous naming catalog")
	print(JSON.stringify({"ok":failures.is_empty(), "checks":checks, "failures":failures, "combination_capacity":naming.capacities, "seeds":examples, "save":DIRECTORY + "/current.json"}))
	quit(0 if failures.is_empty() else 1)
