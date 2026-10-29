extends SceneTree
## Independent tests call the production planner and real World entry points.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Graph = preload("res://src/simulation/social_graph.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Turn = preload("res://src/game/turn.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const Prayers = preload("res://src/game/prayers.gd")
const Economy = preload("res://src/game/economy.gd")
var catalog: RefCounted
var checks: Array = []
var scratch: String = ""
var sample_results: Array = []

class PhaseHarness extends RefCounted:
	## Only supplies unrelated clock slots in a graph-component test. It is not
	## Economy, Events or Endings and makes no full-Session capability claim.
	func handle(_view: Dictionary, input: Dictionary) -> Dictionary:
		var value: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
		if input.slot == "events": value["events"] = []
		return value

class FaultWorld extends World:
	var reject_generation: bool = false
	var reject_focus: bool = false
	var fail_expansion: bool = false
	func expand_focused_domain(domain: String) -> bool:
		var accepted: bool = super.expand_focused_domain(domain)
		if accepted and fail_expansion:
			last_error = "QA injected post-write first-focus publication failure"
			return false
		return accepted
	func validate_state(candidate: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_state(candidate)
		if reject_generation and candidate.has("social_graph"):
			issues.append("QA injected graph initialization publication rejection")
		return issues
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_focus and candidate.get("social_graph", {}).get("cohorts", {}).size() > trusted.get("social_graph", {}).get("cohorts", {}).size():
			issues.append("QA injected first-focus publication rejection")
		return issues

class ControlledPlanEconomy extends Economy:
	## Solely forces one otherwise valid expansion preview into the Turn plan
	## reservation branch. This is not acceptance of economic qualification.
	var fixture_cult: String = ""
	var fixture_source: String = ""
	func preview(_state: Dictionary, _plan: Dictionary, _index: RefCounted = null) -> Dictionary:
		return {"ok": true, "preview": {"cults": [{"cult": fixture_cult, "intent": "expand", "effective": "expand", "reason": "", "source": fixture_source}], "anchors": []}}

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("SGI-CATALOG", loaded, {"errors": catalog.errors})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	scratch = args[0].get_base_dir()
	if loaded:
		_catalog_cases()
		_control_cases()
		_world_cases()
	var passed: bool = checks.all(func(row: Dictionary) -> bool: return row.status == "pass")
	_write(args[0], {"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string,
		"checks": checks, "executionScope": "real_graph_algorithm_and_world_initialization_components",
		"limitations": ["Controlled A-F planner statistics are not natural-world frequencies.", "World integration and explicit prerequisites are reported separately.", "Full lifecycle, complete historical audit, old consumer semantics and complete Session remain downstream."]})
	quit(0 if passed else 1)

func _check(id: String, ok: bool, details: Dictionary = {}) -> void:
	checks.append({"id": id, "status": "pass" if ok else "fail", "details": details})
	print("PASS " if ok else "FAIL ", id, " ", JSON.stringify(details))

func _write(path: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create evidence: " + path)
		return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.close()

func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _write_text(path: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create fixture: " + path)
		return
	file.store_string(value)
	file.close()

func _catalog_cases() -> void:
	var directory: String = scratch.path_join("catalog-fixture")
	DirAccess.make_dir_recursive_absolute(directory)
	for file: String in DirAccess.get_files_at("res://data"):
		if file.ends_with(".csv"):
			_write_text(directory.path_join(file), _text("res://data/" + file))
	var param: String = _text("res://data/social_graph_parameters.csv")
	var types: String = _text("res://data/social_relation_types.csv")
	var root: String = _text("res://data/prayer_root_rules.csv")
	var simulation: String = _text("res://data/simulation_parameters.csv")
	var variants: Dictionary = {
		"duplicate_parameter": {"file": "social_graph_parameters", "text": param + "model_version,1,version,duplicate\n"},
		"zero_denominator": {"file": "social_graph_parameters", "text": _cell(param, "initial_edge_denominator", "value", "0")},
		"negative_weight": {"file": "social_relation_types", "text": _cell(types, "support", "initial_weight", "-1")},
		"invalid_percent": {"file": "social_graph_parameters", "text": _cell(param, "validation_triangle_min_percent", "value", "101")},
		"missing_type": {"file": "social_relation_types", "text": _without(types, "family")},
		"wrong_direction": {"file": "social_relation_types", "text": _cell(types, "family", "direction", "directed")},
		"unknown_need": {"file": "social_relation_types", "text": _cell(types, "rival", "initial_need_tags", "not_authored")},
		"duplicate_need": {"file": "social_relation_types", "text": _cell(types, "rival", "initial_need_tags", "knowledge|knowledge")},
		"asymmetric_coexistence": {"file": "social_relation_types", "text": _cell(types, "family", "coexists_with", "family|support")},
		"wrong_duplicate_policy": {"file": "social_relation_types", "text": _cell(types, "support", "duplicate_policy", "append_every_time")},
		"wrong_root_owner": {"file": "prayer_root_rules", "text": _cell(root, "ROOT_INITIAL_TIES", "producer_task", "TASK-SOURCE-LOCAL-TIES")},
		"negative_legacy_count": {"file": "simulation_parameters", "text": _cell(simulation, "initial_generic_relation_count", "value", "-1")},
		"fractional_legacy_count": {"file": "simulation_parameters", "text": _cell(simulation, "initial_generic_relation_count", "value", "0.5")},
		"no_contact_type": {"file": "social_relation_types", "text": _cell(_cell(types, "family", "initial_weight", "0"), "support", "initial_weight", "0")},
	}
	var trial: RefCounted = Catalog.new()
	var ready: bool = trial.load_files()
	var original_version: String = str(trial.version)
	var original_tables: String = World.canonical(trial.tables)
	var atomic: bool = ready
	for name: String in variants:
		var item: Dictionary = variants[name]
		var filename: String = str(item.file) + ".csv"
		_write_text(directory.path_join(filename), str(item.text))
		_write_text(scratch.path_join("catalog-" + name + ".csv"), str(item.text))
		var accepted: bool = trial.load_files(directory)
		atomic = atomic and str(trial.version) == original_version and World.canonical(trial.tables) == original_tables
		_check("SGI-CATALOG/" + name, not accepted and not trial.errors.is_empty(), {"accepted": accepted, "errors": trial.errors.duplicate()})
		_write_text(directory.path_join(filename), _text("res://data/" + filename))
	_check("SGI-CATALOG/TRANSACTIONAL", atomic, {"rejections": variants.size(), "previousTablesAndVersionRetained": atomic})
	var alternate: String = _cell(_cell(param, "initial_edge_numerator", "value", "1"), "initial_edge_denominator", "value", "1")
	alternate = _cell(alternate, "initial_degree_base", "value", "1")
	_write_text(directory.path_join("social_graph_parameters.csv"), alternate)
	_write_text(scratch.path_join("catalog-alternate.csv"), alternate)
	var valid: RefCounted = Catalog.new()
	var allowed: bool = valid.load_files(directory)
	var result: Dictionary = Graph.plan(valid, "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", _controlled()) if allowed else {}
	_check("SGI-CATALOG/ALTERNATE", allowed and result.get("ok", false) and result.get("edges", []).size() <= 6, {"loaded": allowed, "errors": valid.errors, "edgeCount": result.get("edges", []).size(), "explicitPrerequisite": "Alternate legal CSV copy; formal repository data unchanged."})
	_write_text(directory.path_join("social_graph_parameters.csv"), param)
	var zero_types: String = _cell(_cell(_cell(types, "cooperation", "initial_weight", "0"), "rival", "initial_weight", "0"), "support", "initial_weight", "0")
	_write_text(directory.path_join("social_relation_types.csv"), zero_types)
	_write_text(scratch.path_join("catalog-zero-types.csv"), zero_types)
	var zero_catalog: RefCounted = Catalog.new()
	var zero_valid: bool = zero_catalog.load_files(directory)
	var zero_plan: Dictionary = Graph.plan(zero_catalog, "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", _controlled()) if zero_valid else {}
	_check("SGI-CATALOG/ZERO-TYPES", zero_valid and zero_plan.get("ok", false) and not zero_plan.get("edges", []).is_empty() and zero_plan.edges.all(func(edge: Dictionary) -> bool: return edge.kind == "family"), {"loaded": zero_valid, "errors": zero_catalog.errors, "edgeCount": zero_plan.get("edges", []).size(), "zeroWeightTypesNeverDrawn": true})
	_write_text(directory.path_join("social_relation_types.csv"), types)
	var ignored: bool = true
	var legacy_details: Array = []
	var reference: Dictionary = Graph.plan(catalog, "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", _controlled())
	for count: String in ["0", "2"]:
		var legacy: String = _cell(simulation, "initial_generic_relation_count", "value", count)
		_write_text(directory.path_join("simulation_parameters.csv"), legacy)
		_write_text(scratch.path_join("catalog-legacy-" + count + ".csv"), legacy)
		var candidate: RefCounted = Catalog.new()
		var accepted: bool = candidate.load_files(directory)
		var planned: Dictionary = Graph.plan(candidate, "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", _controlled()) if accepted else {}
		ignored = ignored and accepted and World.canonical(reference) == World.canonical(planned)
		legacy_details.append({"value": count, "accepted": accepted, "errors": candidate.errors, "sameGraph": World.canonical(reference) == World.canonical(planned)})
	_check("SGI-CATALOG/LEGACY-IGNORED", ignored, {"variants": legacy_details, "newGraphBudgetOnly": ignored})

func _cell(text: String, id: String, field: String, replacement: String) -> String:
	var lines: PackedStringArray = text.strip_edges().split("\n")
	var headers: PackedStringArray = lines[0].trim_suffix("\r").split(",")
	var index: int = headers.find(field)
	assert(index >= 0)
	for at: int in range(1, lines.size()):
		var cells: PackedStringArray = lines[at].trim_suffix("\r").split(",")
		if cells[0] == id:
			cells[index] = replacement
			lines[at] = ",".join(cells)
	return "\n".join(lines) + "\n"

func _without(text: String, id: String) -> String:
	var lines: PackedStringArray = []
	for line: String in text.strip_edges().split("\n"):
		if not line.begins_with(id + ","): lines.append(line.trim_suffix("\r"))
	return "\n".join(lines) + "\n"

func _controlled() -> Dictionary:
	var domain: String = "DOMAIN-001"
	var offices: Dictionary = {}
	for role: String in ["interpretation", "propagation", "order"]:
		var id: String = domain + "/" + role
		var links: Array = []
		for other: String in ["interpretation", "propagation", "order"]:
			if other != role: links.append(domain + "/" + other)
		offices[id] = {"active": true, "domain": domain, "links": links, "source": "CONTROLLED-WORLD-ORIGIN"}
	var members: Dictionary = {}
	var profiles: Array = ["NPC_PROFILE_01", "NPC_PROFILE_02", "NPC_PROFILE_03", "NPC_PROFILE_03", "NPC_PROFILE_05", "NPC_PROFILE_05"]
	for at: int in profiles.size():
		var profile: Dictionary = catalog.tables.npc_profiles[profiles[at]]
		var institution: String = domain + "/" + ["interpretation", "propagation", "order"][at / 2]
		members[String.chr(65 + at)] = {"profile": profile.id, "influence": int(profile.influence), "role_tags": Array(str(profile.role_tags).split(";")), "need_tags": Array(str(profile.need_tags).split(";")), "institution": institution, "identity_source": "CONTROLLED-WORLD-ORIGIN"}
	return {"members": members, "institutions": offices, "expanded_at_creation": true}

func _metrics(edges: Array, snapshot: Dictionary) -> Dictionary:
	var neighbors: Dictionary = {}
	for id: String in snapshot.members: neighbors[id] = []
	var types: Dictionary = {}
	var cross: bool = false
	for edge: Dictionary in edges:
		if not edge.b in neighbors[edge.a]: neighbors[edge.a].append(edge.b)
		if not edge.a in neighbors[edge.b]: neighbors[edge.b].append(edge.a)
		types[edge.kind] = int(types.get(edge.kind, 0)) + 1
		cross = cross or snapshot.members[edge.a].institution != snapshot.members[edge.b].institution
	var degrees: Array = []
	var triangle: bool = false
	var branch: bool = false
	for id: String in neighbors:
		if not neighbors[id].size() in degrees: degrees.append(neighbors[id].size())
		branch = branch or neighbors[id].size() >= 3
		for b: String in neighbors[id]:
			for c: String in neighbors[id]:
				triangle = triangle or (b != c and c in neighbors[b])
	return {"heterogeneous": degrees.size() > 1, "triangle": triangle, "cross": cross, "branch": branch, "types": types, "neighbors": neighbors}

func _control_cases() -> void:
	var snapshot: Dictionary = _controlled()
	_write(scratch.path_join("controlled-input.json"), {"civilization": "CIV_02", "phase": "world_start", "snapshot": snapshot, "scope": "Exact six-person controlled production-planner inputs; placeholder source labels do not constitute World facts."})
	var valid: bool = true
	var deterministic: bool = true
	var categories: Dictionary = {"heterogeneous": 0, "triangle": 0, "cross": 0, "branch": 0}
	var all_types: Dictionary = {}
	var count: int = catalog.integer("validation_seed_count")
	var first: int = catalog.integer("validation_seed_first")
	for seed_value: int in range(first, first + count):
		var result: Dictionary = Graph.plan(catalog, str(seed_value), "DOMAIN-001", "world_start", "DOMAIN-001/world_start", snapshot)
		var metric: Dictionary = _metrics(result.get("edges", []), snapshot)
		valid = valid and result.get("ok", false)
		var reordered: Dictionary = {"members": {}, "institutions": {}, "expanded_at_creation": true}
		var ids: Array = snapshot.members.keys(); ids.reverse()
		for id: String in ids: reordered.members[id] = snapshot.members[id].duplicate(true)
		var office_ids: Array = snapshot.institutions.keys(); office_ids.reverse()
		for id: String in office_ids: reordered.institutions[id] = snapshot.institutions[id].duplicate(true)
		deterministic = deterministic and World.canonical(result) == World.canonical(Graph.plan(catalog, str(seed_value), "DOMAIN-001", "world_start", "DOMAIN-001/world_start", reordered))
		for key: String in categories:
			if metric[key]: categories[key] += 1
		for key: String in metric.types: all_types[key] = int(all_types.get(key, 0)) + int(metric.types[key])
		sample_results.append({"seed": str(seed_value), "result": result, "metrics": metric})
	_write(scratch.path_join("controlled-seeds.json"), sample_results)
	_check("SGI-CONTROL/SEEDS-128", valid and count == 128 and first == 0 and sample_results.size() == count, {"first": first, "count": count, "failedOrEmptySamplesExcluded": false, "scope": "Actual production planner, controlled inputs; not 128 natural campaigns."})
	var names: Dictionary = {"heterogeneous": "validation_heterogeneous_min_percent", "triangle": "validation_triangle_min_percent", "cross": "validation_cross_institution_min_percent", "branch": "validation_branch_min_percent"}
	var thresholds: Dictionary = {}
	var met: bool = valid
	for key: String in names:
		thresholds[key] = catalog.integer(names[key])
		met = met and int(categories[key]) * 100 >= int(thresholds[key]) * count
	_check("SGI-CONTROL/METRICS", met, {"numerators": categories, "denominator": count, "requiredPercent": thresholds})
	var type_ok: bool = valid
	for kind: String in ["family", "support", "cooperation", "rival"]: type_ok = type_ok and int(all_types.get(kind, 0)) >= catalog.integer("validation_type_occurrences_min")
	_check("SGI-CONTROL/TYPES", type_ok and not all_types.has("hostile") and not all_types.has("favor_owed"), {"occurrences": all_types})
	_check("SGI-CONTROL/DETERMINISM", deterministic, {"reversedDictionaryInsertionOrder": true, "sameSeedSameOutput": deterministic})
	_hash_case(snapshot)
	var empty: Dictionary = snapshot.duplicate(true); empty.members = {}
	var one: Dictionary = snapshot.duplicate(true); one.members = {"A": one.members.A}
	var none: Dictionary = Graph.plan(catalog, "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", empty)
	var single: Dictionary = Graph.plan(catalog, "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", one)
	_check("SGI-CONTROL/EMPTY-SINGLE", none.get("ok", false) and single.get("ok", false) and none.edges.is_empty() and single.edges.is_empty() and not none.empty_reason.is_empty() and not single.empty_reason.is_empty(), {"empty": none, "single": single})
	var rejected: Array = []
	for seed: String in ["00", "+1", "-0", " 1", "1 "]:
		rejected.append(not Graph.plan(catalog, seed, "DOMAIN-001", "world_start", "DOMAIN-001/world_start", snapshot).get("ok", true))
	rejected.append(not Graph.plan(catalog, "0", "DOMAIN-001", "ordinary_turn", "DOMAIN-001/ordinary_turn", snapshot).get("ok", true))
	rejected.append(not Graph.plan(catalog, "0", "DOMAIN-001", "world_start", "wrong", snapshot).get("ok", true))
	_check("SGI-CONTROL/INVALID-INPUTS", rejected.all(func(v: bool) -> bool: return v), {"rejections": rejected})

func _hash_case(snapshot: Dictionary) -> void:
	# Independently audit only the first edge draw. No second graph generator.
	var candidates: Array = []
	var total: int = 0
	var ids: Array = snapshot.members.keys(); ids.sort()
	for left: int in ids.size():
		for right: int in range(left + 1, ids.size()):
			var a: Dictionary = snapshot.members[ids[left]]; var b: Dictionary = snapshot.members[ids[right]]
			var common_roles: Array = a.role_tags.filter(func(v: String) -> bool: return v in b.role_tags)
			var common_needs: Array = a.need_tags.filter(func(v: String) -> bool: return v in b.need_tags)
			var weight: int = catalog.integer("contact_weight_base")
			weight += catalog.integer("same_institution_bonus") if a.institution == b.institution else catalog.integer("institution_bridge_bonus")
			if not common_roles.is_empty(): weight += catalog.integer("shared_role_bonus")
			weight += mini(common_needs.size(), catalog.integer("shared_need_count_cap")) * catalog.integer("shared_need_bonus")
			candidates.append({"a": ids[left], "b": ids[right], "weight": weight}); total += weight
	var encoded: String = JSON.stringify([catalog.integer("model_version"), "0", "DOMAIN-001", "world_start", "DOMAIN-001/world_start", "edge", 0], "", false)
	var draw: int = int(encoded.sha256_text().substr(0, 8).hex_to_int() % total)
	var selected: Dictionary = {}
	for row: Dictionary in candidates:
		if draw < int(row.weight): selected = row; break
		draw -= int(row.weight)
	var actual: Dictionary = sample_results[0].result.edges[0] if not sample_results.is_empty() and not sample_results[0].result.get("edges", []).is_empty() else {}
	var direction_ok: bool = true
	var directions: Dictionary = {"0": 0, "1": 0}
	for sample: Dictionary in sample_results:
		var edges: Array = sample.result.get("edges", [])
		for index: int in edges.size():
			var edge: Dictionary = edges[index]
			if edge.get("direction") != "directed": continue
			var key: String = JSON.stringify([catalog.integer("model_version"), sample.seed, "DOMAIN-001", "world_start", "DOMAIN-001/world_start", "direction", index], "", false)
			var flip: int = int(key.sha256_text().substr(0, 8).hex_to_int() % 2)
			directions[str(flip)] += 1
			direction_ok = direction_ok and edge.a == (edge.contact_a if flip == 0 else edge.contact_b) and edge.b == (edge.contact_b if flip == 0 else edge.contact_a)
	_check("SGI-CONTROL/HASH-GRAMMAR", actual.get("contact_a") == selected.get("a") and actual.get("contact_b") == selected.get("b") and direction_ok and int(directions["0"]) > 0 and int(directions["1"]) > 0, {"encoded": encoded, "expectedFirstPair": selected, "actual": actual, "auditedSupportDirectionBits": directions, "scope": "Independent first edge weighted boundary and actual directed-edge hash transcript audit; no second graph producer."})

func _world_cases() -> void:
	var worlds: Array = []
	var summaries: Array = []
	var generated: bool = true
	var closed: bool = true
	var endpoint_privacy: bool = true
	var no_spread: bool = true
	var population: bool = true
	for seed_value: int in [0, 1, 7, 7919]:
		for hybrid: bool in [false, true]:
			var world: RefCounted = World.new(catalog)
			var accepted: bool = world.generate(seed_value, null, hybrid)
			generated = generated and accepted
			if not accepted:
				summaries.append({"seed": seed_value, "hybrid": hybrid, "error": world.last_error})
				continue
			worlds.append(world)
			var audit: Dictionary = _audit_graph(world)
			closed = closed and audit.ok
			endpoint_privacy = endpoint_privacy and audit.endpoint_privacy
			no_spread = no_spread and audit.no_spread
			population = population and audit.population
			summaries.append({"seed": seed_value, "hybrid": hybrid, "cohorts": History.export_value(world.state.social_graph.cohorts), "profiles": _profile_summary(world), "audit": audit})
	_write(scratch.path_join("actual-world-initializations.json"), summaries)
	_check("SGI-WORLD/ACTUAL-GENERATE", generated and worlds.size() == 8, {"worlds": worlds.size(), "scope": "Actual World.generate, four seeds in full and hybrid mode, ordinary authored profile selection; not natural requests or full Session."})
	_check("SGI-WORLD/SOURCE-CLOSURE", closed and generated, {"actualWorlds": worlds.size(), "schemaParentsHeadsAndHistoricalIdentityChecked": closed})
	_check("SGI-PRIVACY/ONLY-ENDS", endpoint_privacy and generated, {"onlyActualRelationEndsKnowInitialRelationship": endpoint_privacy})
	_check("SGI-PRIVACY/NO-DATA-SPREAD", no_spread and generated, {"noIdentityKnowledgeOrUnrelatedFacts": no_spread, "scope": "World facts and actual recipient ledgers; full player UI remains outside this component."})
	_check("SGI-WORLD/CAPACITY-POPULATION", population and generated, {"originalPopulationAndNamedBudgets": population})
	if worlds.is_empty(): return
	_query_cases(worlds[0])
	_save_cases(worlds[0])
	_writer_cases()
	_first_focus_cases()
	_atomic_cases()
	_plan_reserve_cases()

func _people(world: RefCounted, domain: String = "") -> Array:
	var result: Array = []
	for id: String in Store.keys(world.state.npcs):
		if domain.is_empty() or Store.entry(world.state.npcs, id).domain == domain: result.append(id)
	result.sort()
	return result

func _facts(world: RefCounted, kind: String) -> Array:
	var result: Array = []
	for fact: Dictionary in Store.values(world.state.facts):
		if fact.kind == kind: result.append(fact)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return result

func _profile_summary(world: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for domain: String in world.state.domains:
		var profiles: Array = []
		for id: String in _people(world, domain): profiles.append(Store.entry(world.state.npcs, id).profile)
		result[domain] = {"civilization": world.state.domains[domain].profile, "peopleProfiles": profiles}
	return result

func _audit_graph(world: RefCounted) -> Dictionary:
	var graph: Dictionary = world.state.get("social_graph", {})
	var ok: bool = graph.get("schema") == 1 and graph.get("model_version") == catalog.integer("model_version")
	var endpoint_privacy: bool = true
	var no_spread: bool = true
	var population: bool = true
	var heads: Dictionary = History.export_value(graph.get("edge_heads", {}))
	var initial: Array = _facts(world, "initial_relationship")
	var generation: Array = _facts(world, "social_graph_generation")
	ok = ok and heads.size() == initial.size() and generation.size() == world.state.domains.size()
	for cohort_id: String in graph.get("cohorts", {}):
		var cohort: Dictionary = graph.cohorts[cohort_id]
		var source: Dictionary = Store.entry(world.state.facts, str(cohort.get("generation_source", "")), {})
		ok = ok and cohort.get("completed") == true and cohort_id == str(cohort.get("domain", cohort_id.get_slice("/", 0))) + "/" + str(cohort.get("phase", "")) and source.get("kind") == "social_graph_generation"
		if source.is_empty(): continue
		var snapshot: Dictionary = source.changes.get("input_snapshot", {})
		ok = ok and snapshot.get("expanded_at_creation") is bool and source.changes.get("phase") == cohort.phase and source.turn == cohort.turn
		for version: Variant in source.changes.get("data_versions", {}).values(): ok = ok and version is String and version.length() == 64
		for id: String in cohort.get("member_ids", []):
			var identity: String = str(snapshot.get("members", {}).get(id, {}).get("identity_source", ""))
			var fact: Dictionary = Store.entry(world.state.facts, identity, {})
			ok = ok and fact.get("kind") == ("world_origin" if cohort.phase == "world_start" else "nomination")
			if cohort.phase == "first_focus": ok = ok and fact.get("actor") == id
	for fact: Dictionary in initial:
		var fields: Array = fact.changes.keys(); fields.sort()
		var expected: Array = ["schema", "kind", "a", "b", "direction", "cohort", "contact"]; expected.sort()
		ok = ok and fields == expected and fact.changes.schema == 1 and fact.actor == fact.changes.a and fact.targets == [fact.changes.b]
		var key: String = JSON.stringify([fact.changes.a, fact.changes.b, fact.changes.kind, fact.changes.direction], "", false)
		ok = ok and heads.get(key) == fact.id
		var contact: Dictionary = Store.entry(world.state.facts, str(fact.changes.contact), {})
		ok = ok and contact.get("kind") == "social_contact" and fact.causal_parents == [fact.changes.contact] and contact.get("changes", {}).get("cohort") == fact.changes.cohort
		var a: String = str(fact.changes.a); var b: String = str(fact.changes.b)
		for id: String in _people(world):
			var knows: bool = History.has(Store.entry(world.state.npcs, id).known_facts, fact.id)
			endpoint_privacy = endpoint_privacy and knows == (id == a or id == b)
		for office: Dictionary in world.state.institutions.values(): endpoint_privacy = endpoint_privacy and not History.has(office.known_facts, fact.id)
	for fact: Dictionary in Store.values(world.state.facts):
		no_spread = no_spread and not fact.kind in ["identity_learned", "deity_identity_learned", "record_knowledge", "memory_preserved", "prayer_call", "prayer_situation"]
	for domain: Dictionary in world.state.domains.values():
		population = population and int(domain.population) == catalog.integer("domain_population") and int(domain.unnamed_nonfollowers) + int(domain.unnamed_followers) + _people(world, domain.id).size() == int(domain.population)
	return {"ok": ok, "endpoint_privacy": endpoint_privacy, "no_spread": no_spread, "population": population, "initialRelationships": initial.size(), "heads": heads.size(), "generationFacts": generation.size()}

func _clock(world: RefCounted, economy: RefCounted = null) -> Dictionary:
	var clock: RefCounted = Turn.new(world)
	var harness: RefCounted = PhaseHarness.new()
	var slots: Array = ["events", "prepay", "income", "deadlines", "ending"] if economy == null else ["events", "deadlines", "ending"]
	var valid: bool = clock._attached and (economy == null or economy.install(clock)) and clock.register_participant("graph-clock-fixture", "1", slots, [], harness.handle)
	return {"world": world, "turn": clock, "harness": harness, "valid": valid, "next_request": 0}

func _request(data: Dictionary, op: String, fields: Dictionary = {}) -> Dictionary:
	data.next_request += 1
	var request: Dictionary = {"id": "graph-qa-" + str(data.next_request), "turn": int(data.turn.context.turn), "phase": str(data.turn.context.phase), "op": op}
	request.merge(fields)
	return data.turn.submit(request)

func _open(data: Dictionary) -> bool:
	return data.valid and _request(data, "advance").get("ok", false) and _request(data, "finish_events").get("ok", false)

func _finish(data: Dictionary) -> bool:
	if not _request(data, "end_actions").get("ok", false): return false
	for ignored: int in 3:
		if not _request(data, "advance").get("ok", false): return false
	return data.turn.context.phase == "between"

func _focus(data: Dictionary, domain: String) -> Dictionary:
	return _request(data, "attention", {"command": {"kind": "focus", "domain": domain}})

func _first_focus_cases() -> void:
	var world: RefCounted = World.new(catalog)
	var valid: bool = world.generate_hybrid(7919)
	if not valid:
		_check("SGI-WORLD/ACTUAL-FIRST-FOCUS", false, {"error": world.last_error})
		return
	var domain: String = "DOMAIN-002"
	var old_person: String = "NPC-%08d" % int(world.state.next_npc)
	# Explicit pre-existing named-identity prerequisite through the original
	# real nomination kernel. This does not claim PR08 bootstrap was executed.
	valid = valid and world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin)
	# A real status command supplies an explicit vacancy for the later refocus
	# check. Death-source production and full lifecycle behavior are not tested.
	var vacancy_person: String = str(_people(world, "DOMAIN-001")[-1])
	valid = valid and world.submit({"kind": "status", "npc": vacancy_person, "status": "dead", "parents": [world.state.domains["DOMAIN-001"].origin]})
	var before_old: String = World.canonical(Store.entry(world.state.npcs, old_person).relations)
	var named_before: Array = _people(world, domain)
	var population_before: int = int(world.state.domains[domain].unnamed_nonfollowers)
	var data: Dictionary = _clock(world)
	valid = valid and _open(data)
	var focused: Dictionary = _focus(data, domain) if valid else {}
	var cohort: Dictionary = world.state.get("social_graph", {}).get("cohorts", {}).get(domain + "/first_focus", {})
	var newcomers: Array = _people(world, domain).filter(func(id: String) -> bool: return not id in named_before)
	var expected: Array = newcomers.duplicate(); expected.sort()
	var actual: Array = cohort.get("member_ids", []).duplicate(); actual.sort()
	var delta: int = population_before - int(world.state.domains[domain].unnamed_nonfollowers)
	_check("SGI-WORLD/ACTUAL-FIRST-FOCUS", focused.get("ok", false) and cohort.get("completed") == true and actual == expected and delta == newcomers.size(), {"request": focused, "newcomers": newcomers, "cohort": History.export_value(cohort), "populationDelta": delta, "scope": "Actual Turn attention command with an explicitly declared unrelated-slot harness; not a complete Session."})
	_check("SGI-WORLD/OLD-BOOTSTRAP-EXCLUDED", focused.get("ok", false) and not old_person in actual and World.canonical(Store.entry(world.state.npcs, old_person).relations) == before_old, {"existingPerson": old_person, "cohortMembers": actual, "prerequisite": "Actual pre-focus nomination, not injected identity/relationship or claimed PR08 execution."})
	var graph_before: String = World.canonical(world.state.social_graph)
	var repeat: Dictionary = _focus(data, domain) if focused.get("ok", false) else {}
	var immediate_stable: bool = repeat.get("ok", false) and graph_before == World.canonical(world.state.social_graph)
	var released: Dictionary = _request(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}}) if immediate_stable else {}
	var later: bool = released.get("ok", false) and _finish(data) and _open(data)
	var old_initial: Array = _people(world, "DOMAIN-001")
	var graph_later: String = World.canonical(world.state.social_graph)
	var reacquired: Dictionary = _focus(data, "DOMAIN-001") if later else {}
	var new_initial: Array = _people(world, "DOMAIN-001").filter(func(id: String) -> bool: return not id in old_initial)
	var refocus_stable: bool = reacquired.get("ok", false) and not world.state.social_graph.cohorts.has("DOMAIN-001/first_focus") and graph_later == World.canonical(world.state.social_graph) and not new_initial.is_empty()
	_check("SGI-WORLD/REPEATED-FOCUS", immediate_stable and refocus_stable, {"request": repeat, "initiallyExpandedDomainRefocus": reacquired, "refocusNewNominees": new_initial, "alreadyFocusedDoesNotReroll": immediate_stable, "laterNomineesDoNotAcquireInitialEdges": refocus_stable, "vacancyPrerequisite": vacancy_person})
	# This later identity is explicit component setup through the same actual
	# nomination kernel; graph publication must not be triggered by it.
	var standalone: RefCounted = World.new(catalog)
	var own: bool = standalone.generate_hybrid(11)
	var old_graph: String = World.canonical(standalone.state.social_graph) if own else ""
	var next: String = "NPC-%08d" % int(standalone.state.next_npc) if own else ""
	own = own and standalone._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", standalone.state.domains["DOMAIN-002"].origin)
	_check("SGI-WORLD/NOMINATION-NO-GRAPH", own and Store.has(standalone.state.npcs, next) and old_graph == World.canonical(standalone.state.social_graph), {"newPerson": next, "noCohortOrRelationship": old_graph == World.canonical(standalone.state.social_graph)})
	_write(scratch.path_join("first-focus-world.json"), {"snapshot": JSON.parse_string(world.snapshot()), "newcomers": newcomers, "preexisting": old_person})
	var empty_cases: Array = []
	var complete: bool = true
	var local_limit: int = int(world.attention.parameters.local_actor_limit)
	for old_count: int in [local_limit - 1, local_limit]:
		var current: RefCounted = World.new(catalog)
		var allowed: bool = current.generate_hybrid(17)
		for ignored: int in old_count: allowed = allowed and current._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", current.state.domains[domain].origin)
		var pending: Dictionary = _clock(current)
		allowed = allowed and _open(pending)
		var acquired: Dictionary = _focus(pending, domain) if allowed else {}
		var result: Dictionary = current.state.social_graph.cohorts.get(domain + "/first_focus", {})
		var wanted: int = local_limit - old_count
		var saved: String = current.snapshot()
		var restored: RefCounted = World.new(catalog)
		var survives: bool = acquired.get("ok", false) and result.get("completed") == true and result.get("member_ids", []).size() == wanted and not str(result.get("empty_reason", "")).is_empty() and restored.restore(saved) and World.canonical(restored.state.social_graph) == World.canonical(current.state.social_graph)
		complete = complete and survives
		empty_cases.append({"oldNamed": old_count, "expectedNew": wanted, "cohort": History.export_value(result), "focus": acquired, "saveRoundtrip": survives})
	_check("SGI-WORLD/EMPTY-FIRST-FOCUS", complete, {"cases": empty_cases, "prerequisites": "Real prior nominations leave only 0/1 first-focus identities; no graph facts injected."})

func _query_cases(world: RefCounted) -> void:
	var relations: Array = _facts(world, "initial_relationship")
	if relations.is_empty(): return
	var fact: Dictionary = relations[0]
	var a: String = fact.changes.a; var b: String = fact.changes.b
	var before: String = world.snapshot()
	var forward: Array = world.relation_between(a, b, [])
	var backward: Array = world.relation_between(b, a, [])
	var projected: Array = forward.filter(func(row: Dictionary) -> bool: return row.get("source") == fact.id)
	var directional: bool = projected.size() == 1 and projected[0] == {"source": fact.id, "kind": fact.changes.kind, "a": a, "b": b, "direction": fact.changes.direction}
	directional = directional and backward.any(func(row: Dictionary) -> bool: return row.get("source") == fact.id and row.get("a") == a and row.get("b") == b)
	_check("SGI-RELATION/DIRECTION-HEADS", directional, {"source": fact.id, "forward": forward.duplicate(true), "reverseQuery": backward.duplicate(true), "originalDirectionNotRewritten": directional})
	var attached: bool = world.add_relation(a, b, fact.changes.kind, fact.id)
	var again: bool = world.add_relation(a, b, fact.changes.kind, fact.id)
	_check("SGI-RELATION/IDEMPOTENCE", attached and again and before == world.snapshot(), {"first": attached, "second": again, "snapshotUnchanged": before == world.snapshot()})
	if not forward.is_empty(): forward[0]["kind"] = "QA_MUTATION"
	forward.append({"source": "QA_FAKE"})
	var context: Dictionary = world.contact_context(a, b)
	if not context.is_empty(): context["channel_sources"].append("QA_FAKE")
	_check("SGI-RELATION/DETACHED-READS", before == world.snapshot() and not world.relation_between(a, b, []).any(func(row: Dictionary) -> bool: return row.get("kind") == "QA_MUTATION" or row.get("source") == "QA_FAKE"), {"snapshotUnchanged": before == world.snapshot()})
	world.ensure_history()
	world.history.reset_metrics()
	var all: Dictionary = world.contact_page(a, 0, 0)
	var paged: Array = []
	var cursor: int = 0
	var paging: bool = all.get("ok", false)
	for ignored: int in 8:
		var page: Dictionary = world.contact_page(a, cursor, 1)
		paging = paging and page.get("ok", false) and page.get("items", []).size() <= 1
		paged.append_array(page.get("items", []))
		if page.get("complete", false): break
		var following: int = int(page.get("cursor", -1))
		paging = paging and following > cursor
		cursor = following
	paging = paging and World.canonical(paged) == World.canonical(all.get("items", [])) and before == world.snapshot()
	_check("SGI-RELATION/LOCAL-PAGE", paging and int(world.history.metrics.history_scanned) == 0 and int(world.history.metrics.rebuild_records) == 0, {"wholeLocalPage": all, "singleItemPages": paged, "metrics": world.history.metrics.duplicate(), "scope": "Minimum local read/pagination; large-history performance remains deferred."})
	var no_source: bool = not world.add_relation(a, b, fact.changes.kind, "FACT-99999999")
	var wrong: bool = not world.add_relation(a, b, "not_authored", fact.id)
	_check("SGI-RELATION/LEGACY-ADAPTER", no_source and wrong and before == world.snapshot(), {"missingSourceRejected": no_source, "mismatchedTypeRejected": wrong, "noOrphanOrHeadMutation": before == world.snapshot()})

func _resign(envelope: Dictionary) -> String:
	envelope.body = World._normalize_numbers(envelope.body)
	envelope.checksum = World.canonical(envelope.body).sha256_text()
	return World.canonical(envelope)

func _writer_cases() -> void:
	var world: RefCounted = World.new(catalog)
	var ready: bool = world.generate(7)
	var initial: Array = _facts(world, "initial_relationship") if ready else []
	if initial.is_empty():
		_check("SGI-RELATION/MANAGED-WRITER", false, {"error": world.last_error})
		return
	var input: Dictionary = initial[0]
	var a: String = input.changes.a; var b: String = input.changes.b
	var owner: RefCounted = Turn.new(world)
	ready = ready and owner._attached
	var service: RefCounted = Prayers.new(catalog)
	var plan: Dictionary = {"request": "controlled-hostility-business-adapter", "variant": "shallow", "actor": b, "produced": {}, "descriptor": {"content_id": "PRAYER_10", "institution": Store.entry(world.state.npcs, b).institution, "domain": input.domain, "source": input.id, "subjects": {"petitioner": b, "opponent": a}, "facts": {"relation": input.id}}}
	var first_head: String = ""
	var first_count: int = 0
	var results: Array = []
	var sources: Array = []
	for at: int in 2:
		var tx: RefCounted = Transaction.new(world, owner.context.duplicate(true), at)
		var active: bool = ready and tx.activate()
		var response: Dictionary = {}
		var issues: Array = []
		if active:
			world.stage_current()
			var source: String = service._write(world, plan, "hostility", [a], input.id)
			sources.append(source)
			response = world.establish_relation(a, b, "hostile", [source, input.id], [], owner)
			issues = tx.validate_world()
			if response.get("ok", false) and issues.is_empty(): tx.publish()
			else: tx.rollback()
		ready = ready and active and response.get("ok", false) and issues.is_empty()
		if at == 0:
			first_head = str(response.get("source", "")); first_count = _facts(world, "relationship").size()
		else:
			ready = ready and response.get("source") == first_head and response.get("existing") == true and _facts(world, "relationship").size() == first_count
		results.append({"response": response, "issues": issues})
	ready = ready and sources.size() == 2 and sources[0] != sources[1] and first_count == 1
	_check("SGI-RELATION/MANAGED-WRITER", ready, {"businessSources": sources, "relationshipSource": first_head, "relationshipCount": first_count, "attempts": results, "scope": "Actual Transaction + Prayers._write hostility adapter + sole World writer, controlled source prerequisites; not a generated PR10 request, response or full Session."})
	var rejection_tx: RefCounted = Transaction.new(world, owner.context.duplicate(true), 2)
	var activated: bool = rejection_tx.activate()
	var rejected: bool = activated
	var before: String = world.snapshot()
	var negatives: Array = []
	if activated:
		var invalid: Dictionary = world.establish_relation(a, b, "cooperation", [world.state.domains[input.domain].origin], [], owner)
		var self_edge: Dictionary = world.establish_relation(a, a, "hostile", sources, [], owner)
		var outsider: String = str(_people(world, "DOMAIN-002")[0])
		var recipient: Dictionary = world.establish_relation(a, b, "hostile", sources, [outsider], owner)
		negatives = [invalid, self_edge, recipient]
		rejected = negatives.all(func(value: Dictionary) -> bool: return not value.get("ok", true)) and world.snapshot() == before
		rejection_tx.rollback()
	_check("SGI-RELATION/WRITER-REJECT-SOURCE", rejected, {"responses": negatives, "snapshotUnchanged": rejected})

func _save_cases(world: RefCounted) -> void:
	var serialized: String = world.snapshot()
	_write_text(scratch.path_join("current-world-save.json"), serialized)
	var receiver: RefCounted = World.new(catalog)
	var accepted: bool = receiver.restore(serialized)
	var roundtrip: bool = accepted and receiver.snapshot() == serialized and receiver.ensure_history()
	_check("SGI-SAVE/CURRENT-ROUNDTRIP", roundtrip, {"restored": accepted, "error": receiver.last_error, "scope": "World current-version local snapshot; full Session continuation and complete historical audit remain deferred."})
	if not accepted: return
	var envelope: Dictionary = JSON.parse_string(serialized)
	var head_keys: Array = envelope.body.state.social_graph.edge_heads.keys(); head_keys.sort()
	if head_keys.is_empty(): return
	var key: String = str(head_keys[0])
	var missing: Dictionary = envelope.duplicate(true); missing.body.state.social_graph.edge_heads.erase(key)
	var orphan: Dictionary = envelope.duplicate(true); orphan.body.state.social_graph.edge_heads[key] = "FACT-99999999"
	var old: Dictionary = envelope.duplicate(true); old.body.state.erase("social_graph")
	for item: Dictionary in [{"name": "REJECT-MISSING-HEAD", "value": missing}, {"name": "REJECT-ORPHAN", "value": orphan}, {"name": "REJECT-OLD-SCHEMA", "value": old}]:
		var before: String = receiver.snapshot()
		var input: String = _resign(item.value)
		_write_text(scratch.path_join("bad-save-" + str(item.name) + ".json"), input)
		var valid: bool = receiver.restore(input)
		_check("SGI-SAVE/" + str(item.name), not valid and before == receiver.snapshot(), {"accepted": valid, "error": receiver.last_error, "correctChecksum": true, "oldStateRetained": before == receiver.snapshot()})

func _atomic_cases() -> void:
	var world: RefCounted = FaultWorld.new(catalog)
	var valid: bool = world.generate(7)
	var before: String = world.snapshot() if valid else ""
	world.reject_generation = true
	var next: bool = world.generate(8) if valid else true
	var generation_atomic: bool = valid and not next and before == world.snapshot()
	var focused: RefCounted = FaultWorld.new(catalog)
	valid = focused.generate_hybrid(7)
	var data: Dictionary = _clock(focused)
	valid = valid and _open(data)
	var initial: String = data.turn.snapshot() if valid else ""
	focused.reject_focus = true
	var result: Dictionary = _focus(data, "DOMAIN-002") if valid else {}
	var focus_atomic: bool = valid and not result.get("ok", true) and initial == data.turn.snapshot()
	_check("SGI-ATOMIC/GENERATION-FAULT", generation_atomic and focus_atomic, {"worldInitializationRolledBack": generation_atomic, "firstFocusTurnRolledBack": focus_atomic, "focusResponse": result, "scope": "Injected invariant-publication failure; no validation bypass or target graph fixture."})

func _plan_fixture() -> Dictionary:
	var world: RefCounted = FaultWorld.new(catalog)
	var valid: bool = world.generate_hybrid(29)
	var economy: RefCounted = ControlledPlanEconomy.new(catalog, {"graph-plan-fixture": "1"})
	valid = valid and economy.initialize(world)
	var domain: String = "DOMAIN-002"
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	valid = valid and world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin)
	world.mutable_npc(person).loyalty = 80 # Explicit eligible pre-existing leader.
	var origin: String = str(world.state.domains[domain].origin)
	var member_needs: Dictionary = world.attention.preview_needs(world.state, {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [person], "nominees": [person], "source": origin})
	var member_reservation: Dictionary = world.attention.reserve(world, member_needs) if member_needs.get("ok", false) else {}
	valid = valid and member_reservation.get("ok", false) and world.attention.enroll(world, person, origin, str(member_reservation.get("token", "")))
	if member_reservation.get("ok", false): world.attention.finish(world, member_reservation.token)
	valid = valid and world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 6, "parents": [origin]})
	var cult: String = "CULT-" + domain
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, person, [person], [origin], {"issuer": "graph-plan-fixture", "version": "1", "cult": cult, "domain": domain, "leader": person, "cohesion": 80}, []) if valid else ""
	valid = valid and not authorization.is_empty() and world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]})
	economy.fixture_cult = cult
	economy.fixture_source = world.state.cults.get(cult, {}).get("established_source", "")
	var data: Dictionary = _clock(world, economy)
	data["economy"] = economy; data["cult"] = cult
	data.valid = data.valid and valid
	data["fixtureDiagnostics"] = {"initialized": valid, "worldError": world.last_error, "turnError": data.turn.last_error, "memberNeeds": member_needs, "memberReservation": member_reservation, "authorization": authorization}
	return data

func _plan_reserve_cases() -> void:
	var data: Dictionary = _plan_fixture()
	var valid: bool = _open(data)
	var plan: Dictionary = {"strategies": {data.cult: "expand"}, "anchor_priority": [], "refuse_anchors": []}
	valid = valid and _request(data, "set_plan", {"participant": "economy", "payload": plan}).get("ok", false)
	var before: String = data.turn.snapshot() if valid else ""
	data.world.fail_expansion = true
	var failed: Dictionary = _request(data, "end_actions") if valid else {}
	var rolled_back: bool = valid and not failed.get("ok", true) and data.turn.snapshot() == before and data.world.transaction == null
	data.world.fail_expansion = false
	var retried: Dictionary = _request(data, "end_actions") if rolled_back else {}
	var clean_retry: bool = retried.get("ok", false) and "DOMAIN-002" in data.world.state.simulation.focused and data.world.state.social_graph.cohorts.has("DOMAIN-002/first_focus") and data.world.transaction == null
	_check("SGI-ATOMIC/PLAN-RESERVE", rolled_back and clean_retry, {"fixture": data.fixtureDiagnostics, "failure": failed, "allStateRolledBack": rolled_back, "retry": retried, "errorLatchCleared": clean_retry, "scope": "Controlled Economy preview supplies an expansion intent; actual Turn._lock_attention_plans, Attention.reserve, World expansion and Transaction run. Legacy cult prerequisites are produced via accepted fixture issuer and real World commands. No full economic/Session integration claim."})
	var full: Dictionary = _plan_fixture()
	var legal: bool = _open(full)
	for index: int in range(3, 3 + int(full.world.attention.parameters.focused_domain_limit) - 1):
		legal = legal and _focus(full, "DOMAIN-%03d" % index).get("ok", false)
	legal = legal and _request(full, "set_plan", {"participant": "economy", "payload": {"strategies": {full.cult: "expand"}, "anchor_priority": [], "refuse_anchors": []}}).get("ok", false)
	var graph_before: String = World.canonical(full.world.state.social_graph)
	var held: Dictionary = _request(full, "end_actions") if legal else {}
	var normal: bool = held.get("ok", false) and full.turn.context.get("locked_plans", {}).get("economy", {}).get("strategies", {}).get(full.cult) == "hold" and not "DOMAIN-002" in full.world.state.simulation.focused and graph_before == World.canonical(full.world.state.social_graph)
	_check("SGI-ATOMIC/CAPACITY-HOLD", normal, {"fixture": full.fixtureDiagnostics, "endActions": held, "focused": full.world.state.simulation.focused, "reasons": full.turn.context.get("attention_plan_reasons", {}), "noPartialGraph": graph_before == World.canonical(full.world.state.social_graph), "scope": "Same controlled preview, actual capacity preflight remains an ordinary hold rather than a hard error."})
