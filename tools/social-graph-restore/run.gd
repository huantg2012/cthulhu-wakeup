extends "res://tools/social-graph-restore/regression_adapters.gd"
## This suite owns only fresh fixtures/evidence, never its protected parents.
const Initialization = preload("res://src/simulation/world_initialization.gd")
const Powers = preload("res://src/game/powers.gd")

class ObservedBootstrapWorld extends World:
	var bootstrap_stage: String = ""
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var result: Array[String] = super.validate_increment(candidate, trusted)
		if candidate.has("simulation") and candidate.simulation.bootstrap and Store.has(candidate.applied_authorizations, "prayer/bootstrap"):
			bootstrap_stage = snapshot()
		return result

class ComponentTurn extends Turn:
	## Test command driver only. submit/transaction/receipt/context validation,
	## persistence and every World validator are production code, unchanged.
	## This bypasses no validator and never claims formal PR/Event dispatch.
	var component: Callable
	var component_result: Dictionary = {}
	func _dispatch(request: Dictionary) -> bool:
		if request.op == "act" and request.get("participant") == "graph-components" and request.get("action") == "QA_COMPONENT":
			if context.phase != "actions" or not component.is_valid(): return false
			var result: Variant = component.call()
			component_result = result if result is Dictionary else {"ok": result == true}
			return component_result.get("ok", false)
		return super._dispatch(request)

class AdmissionHarness extends RefCounted:
	var descriptor: Dictionary = {}
	func handle(_view: Dictionary, _input: Dictionary) -> Dictionary:
		return {"ok": true, "empty": true, "effects": [], "state": {}, "meta": {"faith_cost": 0, "whispers_cost": 0, "min_awakening": 0, "responds": false, "used_power": false, "used_relic": false, "actor": "", "source": descriptor.source, "outcome": "explicit admission component", "attention": descriptor.duplicate(true)}}

class StrategyFixtureEconomy extends Economy:
	## Controlled eligibility/intent preview; actual Economy phase handlers and
	## strategy writes remain unchanged, including the original default lookup.
	var fixture_cult: String = ""
	var fixture_source: String = ""
	func preview(state: Dictionary, plan: Dictionary, _index: RefCounted = null) -> Dictionary:
		var intent: String = plan.get("strategies", {}).get(fixture_cult, state.cults[fixture_cult].get("strategy", "hold"))
		var baseline: Dictionary = super.preview(state, {"strategies": {fixture_cult: "hold"}}, _index)
		if not baseline.get("ok", false): return baseline
		var row: Dictionary = baseline.preview.cults[0]
		row.intent = intent; row.effective = intent; row.reason = ""; row.source = fixture_source
		row.fee = catalog.integer("expansion_faith_cost") if intent == "expand" else 0
		row.growth = mini(int(state.domains[state.cults[fixture_cult].domain].unnamed_nonfollowers), catalog.integer("expansion_base_growth") + int(Store.entry(state.npcs, state.cults[fixture_cult].leader).influence) / catalog.integer("expansion_influence_divisor")) if intent == "expand" else 0
		return baseline

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

func _profile_baseline_cases() -> void:
	var path: String = "res://tools/social-graph-initialization/runs/formal-20261029T072954Z-e5b34c67/actual-world-initializations.json"
	var previous: Variant = JSON.parse_string(_text(path))
	var outputs: Array = []
	var identical: bool = previous is Array and previous.size() == 8
	if previous is Array:
		for entry: Dictionary in previous:
			var world: RefCounted = World.new(catalog)
			var generated: bool = world.generate(int(entry.seed), null, bool(entry.hybrid))
			var current: Dictionary = _profile_summary(world) if generated else {}
			var matches: bool = generated and current == entry.profiles
			var identities: bool = generated
			for cohort_id: String in entry.cohorts:
				var previous_cohort: Dictionary = entry.cohorts[cohort_id]
				identities = identities and world.state.social_graph.cohorts.get(cohort_id, {}).get("member_ids") == previous_cohort.member_ids
				for position: int in previous_cohort.member_ids.size():
					var person: Dictionary = Store.entry(world.state.npcs, previous_cohort.member_ids[position], {})
					identities = identities and person.get("institution") == previous_cohort.domain + "/" + ["interpretation", "propagation", "order"][position % 3]
			matches = matches and identities
			identical = identical and matches
			outputs.append({"seed": entry.seed, "hybrid": entry.hybrid, "sameProfilesAndCivilizations": matches, "sameIdentityBudgetAndOriginalRoleAllocation": identities, "current": current})
	_write(scratch.path_join("original-profile-comparison.json"), outputs)
	_check("SGS-BIRTH/ORIGINAL-PROFILES", identical, {"baseline": path.trim_prefix("res://"), "worlds": outputs, "scope": "Read-only comparison with eight earlier actual World traces, not a rerun or refresh of their old tool/report. Fact IDs may differ with the technical schema."})

func _strong_fixture() -> Dictionary:
	var data: Dictionary = _owned()
	var original: Dictionary = _first_relation(data.world)
	var a: String = original.changes.a; var b: String = original.changes.b
	var first: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, original.id))
	var head: String = str(first.value.get("head", ""))
	var retirement: Dictionary = _apply(data, func() -> Dictionary: return _retire_component(data, head))
	var fresh: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, original.id))
	var favor: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_03", a, b, original.id))
	data["fixture_ok"] = first.ok and retirement.ok and fresh.ok and favor.ok
	data["retired_head"] = head; data["current_head"] = str(fresh.value.get("head", ""))
	data["a"] = a; data["b"] = b
	return data

func _expect_restore_bad(id: String, envelope: Dictionary, receiver: RefCounted, description: String, isolate: Dictionary = {}) -> void:
	var before: String = receiver.snapshot()
	var serialized: String = _resign(envelope)
	_write_text(scratch.path_join("bad-" + id.replace("/", "-") + ".json"), serialized)
	var accepted: bool = receiver.restore(serialized)
	_check(id, not accepted and receiver.snapshot() == before, {"accepted": accepted, "correctChecksum": true, "currentWorldRetained": receiver.snapshot() == before, "error": receiver.last_error, "mutation": description, "isolation": isolate})

func _projection_rows(envelope: Dictionary, person: String) -> Array:
	return envelope.body.state.npcs[person].relations

func _row_index(rows: Array, source: String) -> int:
	for index: int in rows.size():
		if rows[index].get("source") == source: return index
	return -1

func _projection_cases() -> void:
	var data: Dictionary = _strong_fixture()
	var world: RefCounted = data.world
	var saved: String = world.snapshot()
	_write_text(scratch.path_join("full-history-projection-good.json"), saved)
	var receiver: RefCounted = World.new(catalog)
	var plain: bool = receiver.restore(saved)
	var signed: RefCounted = World.new(catalog)
	var resign: bool = signed.restore(_resign(JSON.parse_string(saved)))
	_check("SGS-PROJECTION/ROUNDTRIP", data.fixture_ok and plain and resign and receiver.snapshot() == saved and signed.snapshot() == saved, {"original": plain, "unchangedResigned": resign, "error": receiver.last_error, "containsRetiredAndCurrentEpisodes": true})
	if not plain: return
	var original: Dictionary = JSON.parse_string(saved)
	var a: String = data.a; var b: String = data.b
	var source: String = data.current_head
	var owner_rows: Array = _projection_rows(original, a)
	var index: int = _row_index(owner_rows, source)
	var retired_index: int = _row_index(owner_rows, data.retired_head)
	var third: String = ""
	for person: String in _people(world):
		if not person in [a, b]: third = person; break
	var mutations: Array = []
	var missing: Dictionary = original.duplicate(true); missing.body.state.npcs[a].relations.remove_at(index)
	mutations.append({"name": "MISSING-OWNER", "value": missing, "description": "Remove required outgoing historical row for a current actual episode."})
	var duplicate: Dictionary = original.duplicate(true); duplicate.body.state.npcs[a].relations.append(owner_rows[index].duplicate(true))
	mutations.append({"name": "DUPLICATE", "value": duplicate, "description": "Duplicate a correct row; set membership alone must not accept it."})
	var extra: Dictionary = original.duplicate(true); extra.body.state.npcs[third].relations.append(owner_rows[index].duplicate(true))
	mutations.append({"name": "EXTRA-OWNER", "value": extra, "description": "Attach a genuine relationship source to an unrelated owner."})
	var reverse: Dictionary = original.duplicate(true); reverse.body.state.npcs[b].relations.append({"target": a, "kind": "hostile", "source": source})
	mutations.append({"name": "REVERSE-DIRECTED", "value": reverse, "description": "Give a directed episode's receiver an unauthorized outgoing row."})
	var target: Dictionary = original.duplicate(true); target.body.state.npcs[a].relations[index].target = third
	mutations.append({"name": "WRONG-TARGET", "value": target, "description": "Keep a real source but project a different actual target."})
	var kind: Dictionary = original.duplicate(true); kind.body.state.npcs[a].relations[index].kind = "favor_owed"
	mutations.append({"name": "WRONG-TYPE", "value": kind, "description": "Change a row to another legal type while preserving its source."})
	var unknown: Dictionary = original.duplicate(true); unknown.body.state.npcs[a].relations[index].source = "FACT-99999999"
	mutations.append({"name": "MISSING-SOURCE", "value": unknown, "description": "Project a nonexistent source."})
	var nonrelation: Dictionary = original.duplicate(true); nonrelation.body.state.npcs[a].relations[index].source = original.body.state.domains["DOMAIN-001"].origin
	mutations.append({"name": "NONRELATION-SOURCE", "value": nonrelation, "description": "Use an existing world_origin as a relationship source."})
	var retired: Dictionary = original.duplicate(true); retired.body.state.npcs[a].relations.remove_at(retired_index)
	mutations.append({"name": "MISSING-RETIRED", "value": retired, "description": "Drop retired history while leaving every current head intact."})
	var shape: Dictionary = original.duplicate(true); shape.body.state.npcs[a].relations[index]["unexpected"] = true
	mutations.append({"name": "EXTRA-FIELD", "value": shape, "description": "Add an undeclared projection field to an otherwise correct row."})
	var mutual: Dictionary = {}
	for fact: Dictionary in _facts(world, "initial_relationship"):
		if fact.changes.direction == "mutual": mutual = fact; break
	var mutual_missing: Dictionary = original.duplicate(true)
	var right: String = mutual.changes.b
	mutual_missing.body.state.npcs[right].relations.remove_at(_row_index(_projection_rows(mutual_missing, right), mutual.id))
	mutations.append({"name": "MUTUAL-MISSING-SECOND", "value": mutual_missing, "description": "Drop only the second endpoint of a real mutual episode."})
	var joined: Dictionary = original.duplicate(true)
	joined.body.state.npcs[a].relations[index].target = third
	joined.body.state.npcs[a].relations[index].kind = "favor_owed"
	joined.body.state.npcs[third].relations.append({"target": a, "kind": "favor_owed", "source": source})
	mutations.append({"name": "JOINT-PROJECTION", "value": joined, "description": "Coordinate extra owner, target and legal-type rows around an unchanged real episode; full equality must still reject."})
	for mutation: Dictionary in mutations:
		_expect_restore_bad("SGS-PROJECTION/" + mutation.name, mutation.value, receiver, mutation.description)

func _append_bad_projection(world: RefCounted, person: String, row: Dictionary) -> void:
	var npc: Dictionary = world.mutable_npc(person)
	if History.is_history(npc.relations): npc.relations = History.set_value(npc.relations, "%012d" % History.size(npc.relations), row.duplicate(true), "sequence")
	else:
		npc.relations = npc.relations.duplicate(true)
		npc.relations.append(row.duplicate(true))

func _normal_projection_cases() -> void:
	var data: Dictionary = _owned()
	var world: RefCounted = data.world
	var original: Dictionary = _first_relation(world)
	var a: String = original.changes.a; var b: String = original.changes.b
	var before: String = world.snapshot()
	var duplicate_new: Dictionary = _apply(data, func() -> Dictionary:
		var result: Dictionary = _event_component(data, "EVENT_09", a, b, original.id)
		_append_bad_projection(world, a, {"target": b, "kind": "hostile", "source": result.head})
		return result)
	_check("SGS-NORMAL/DUPLICATE-NEW-SUFFIX", not duplicate_new.ok and not duplicate_new.issues.is_empty() and world.snapshot() == before, {"result": duplicate_new, "worldUnchanged": world.snapshot() == before, "scope": "Real new relationship and first row from the actual handler, followed by a second identical new-suffix row. Full-restore rejection alone cannot satisfy this increment gate."})
	var before_rows: Variant = Store.entry(world.state.npcs, a).relations
	var missing_new: Dictionary = _apply(data, func() -> Dictionary:
		var result: Dictionary = _event_component(data, "EVENT_09", a, b, original.id)
		world.mutable_npc(a).relations = before_rows
		return result)
	_check("SGS-NORMAL/MISSING-NEW-PROJECTION", not missing_new.ok and not missing_new.issues.is_empty() and world.snapshot() == before, {"result": missing_new, "worldUnchanged": world.snapshot() == before, "scope": "Real handler emits source/head/proof/index and new projection; adversary restores only persisted owner rows to their base root. Actual increment must reject even though in-memory relation index still has the new row."})
	var extra_old: Dictionary = _apply(data, func() -> Dictionary:
		_append_bad_projection(world, a, {"target": b, "kind": original.changes.kind, "source": original.id})
		return {"ok": true})
	_check("SGS-NORMAL/DUPLICATE-OLD-SOURCE", not extra_old.ok and world.snapshot() == before, {"result": extra_old, "worldUnchanged": world.snapshot() == before})
	var missing: Dictionary = _apply(data, func() -> Dictionary:
		var npc: Dictionary = world.mutable_npc(a)
		var rows: Array = History.export_value(npc.relations)
		rows.remove_at(_row_index(rows, original.id))
		npc.relations = rows
		return {"ok": true})
	_check("SGS-NORMAL/REMOVE-HISTORY", not missing.ok and world.snapshot() == before, {"result": missing, "worldUnchanged": world.snapshot() == before})
	var rewrite_fact: Dictionary = _apply(data, func() -> Dictionary:
		world.stage_collections(["facts"])
		var changed: Dictionary = Store.entry(world.state.facts, original.id).duplicate(true)
		changed.changes.kind = "favor_owed"
		Store.put(world.state.facts, original.id, changed)
		return {"ok": true})
	_check("SGS-NORMAL/REWRITE-OLD-SOURCE", not rewrite_fact.ok and world.snapshot() == before, {"result": rewrite_fact, "worldUnchanged": world.snapshot() == before})
	var replace_root: Dictionary = _apply(data, func() -> Dictionary:
		world.state.facts = History.from_value(History.export_value(world.state.facts), "map")
		return {"ok": true})
	_check("SGS-NORMAL/REPLACE-SOURCE-ROOT", not replace_root.ok and world.snapshot() == before, {"result": replace_root, "sameContentsUntrustedRootRefused": world.snapshot() == before})
	var rewrite_cohort: Dictionary = _apply(data, func() -> Dictionary:
		world._stage_social_graph()
		var key: String = original.changes.cohort
		var changed: Dictionary = world.state.social_graph.cohorts[key].duplicate(true)
		changed.seed_key = "999"
		world.state.social_graph.cohorts[key] = changed
		return {"ok": true})
	_check("SGS-NORMAL/REWRITE-OLD-COHORT", not rewrite_cohort.ok and world.snapshot() == before, {"result": rewrite_cohort, "worldUnchanged": world.snapshot() == before})
	var legal: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, original.id))
	_check("SGS-NORMAL/LEGAL-AFTER-ROLLBACK", legal.ok and not world.relation_source(str(legal.value.get("head", ""))).is_empty(), {"result": legal, "errorOrCandidateStateDidNotLeak": legal.ok})

func _episode_history_cases() -> void:
	var outputs: Array = []
	var valid: bool = true
	for count: int in [0, 16, 64]:
		var data: Dictionary = _owned()
		var world: RefCounted = data.world
		var initial: Dictionary = _first_relation(world)
		var a: String = initial.changes.a; var b: String = initial.changes.b
		var ready: bool = true
		for ignored: int in count:
			var created: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id))
			var removed: Dictionary = _apply(data, func() -> Dictionary: return _retire_component(data, str(created.value.get("head", ""))))
			ready = ready and created.ok and removed.ok
		# Adopt the persistent archive before measuring ordinary transactions.
		var adoption: Dictionary = _apply(data, func() -> Dictionary: return {"ok": true})
		ready = ready and adoption.ok
		world.history.reset_metrics()
		var active: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id))
		var creation_metrics: Dictionary = world.history.metrics.duplicate(true)
		world.history.reset_metrics()
		var inactive: Dictionary = _apply(data, func() -> bool: return world.submit({"kind": "status", "npc": a, "status": "missing", "parents": [initial.id]}, data.owner))
		var status_metrics: Dictionary = world.history.metrics.duplicate(true)
		ready = ready and active.ok and inactive.ok
		for metrics: Dictionary in [creation_metrics, status_metrics]:
			ready = ready and int(metrics.history_scanned) == 0 and int(metrics.rebuild_records) == 0 and int(metrics.copied_history_values) == 0
		outputs.append({"retiredEpisodes": count, "ok": ready, "creation": active, "status": inactive, "creationMetrics": creation_metrics, "statusMetrics": status_metrics})
		valid = valid and ready
	for sample: Dictionary in outputs:
		for phase: String in ["creationMetrics", "statusMetrics"]:
			valid = valid and int(sample[phase].output_sources) <= int(outputs[0][phase].output_sources) + 16 and int(sample[phase].tree_nodes_read) <= int(outputs[0][phase].tree_nodes_read) * 4 + 256
	_write(scratch.path_join("retired-episode-history-scaling.json"), outputs)
	_check("SGS-NORMAL/RETIRED-HISTORY-SCALING", valid, {"samples": outputs, "scope": "Same pair accumulates 0/16/64 retired episodes through actual event relation and exact PR03 row handlers with disclosed outer component fixtures. Current population is unchanged. New episode and state-change commits must not enumerate or copy old rows; finite counters, not an arbitrary-scale performance proof."})


func _birth_cases() -> void:
	var world: RefCounted = World.new(catalog)
	var valid: bool = world.generate(7)
	var saved: String = world.snapshot()
	var good: Dictionary = JSON.parse_string(saved)
	var receiver: RefCounted = World.new(catalog)
	var recipe: Dictionary = Initialization.plan(catalog, "7", false, int(world.attention.parameters.initial_focused_domains), int(world.attention.parameters.local_actor_limit))
	var versions: bool = good.body.schema == 4 and good.body.state.social_graph.schema == 2 and recipe.ok
	for generation: Dictionary in _facts(world, "social_graph_generation"):
		versions = versions and generation.changes.schema == 1 and generation.changes.model_version == 1
	_check("SGS-BIRTH/VERSIONS", valid and versions and receiver.generate(11) and receiver.restore(saved), {"world": good.body.schema, "graph": good.body.state.social_graph.schema, "fact": 1, "model": 1, "recipe": recipe})
	var domain: String = "DOMAIN-001"
	var cohort_key: String = domain + "/world_start"
	var cohort: Dictionary = good.body.state.social_graph.cohorts[cohort_key]
	var source: String = cohort.generation_source
	var origin: String = good.body.state.domains[domain].origin
	var person: String = cohort.member_ids[0]
	var old_profile: String = good.body.state.npcs[person].profile
	var different: String = "NPC_PROFILE_02" if old_profile != "NPC_PROFILE_02" else "NPC_PROFILE_01"
	var bad: Dictionary = good.duplicate(true)
	bad.body.state.npcs[person].profile = different
	bad.body.state.facts[origin].changes.initialization.births[0].profile = different
	var replacement: Dictionary = catalog.tables.npc_profiles[different]
	var member: Dictionary = bad.body.state.facts[source].changes.input_snapshot.members[person]
	member.profile = different; member.influence = int(replacement.influence)
	member.role_tags = Array(str(replacement.role_tags).split(";")); member.need_tags = Array(str(replacement.need_tags).split(";"))
	var rng_before: String = World.canonical(good.body.randoms)
	var recipe_errors: Array[String] = Graph.validate_births(World._normalize_numbers(bad.body.state), catalog, world.attention.parameters)
	_check("SGS-BIRTH/RECIPE-INDEPENDENT", recipe_errors == ["World origin differs from the actual shared seed recipe"] and World.canonical(JSON.parse_string(world.snapshot()).body.randoms) == rng_before, {"errors": recipe_errors, "productionAuditCalledDirectly": true, "jointCopiesAgree": true, "currentRngUnchanged": World.canonical(JSON.parse_string(world.snapshot()).body.randoms) == rng_before, "scope": "Separate real birth-audit rejection proves seed binding, without depending on a secondary graph-product mismatch in the full-restore negative."})
	_expect_restore_bad("SGS-BIRTH/JOINT-PROFILE", bad, receiver, "NPC, origin birth slot and generation member all agree on another real authored profile; actual seed recipe must still decide.", {"old": old_profile, "replacement": different, "selfReportedCopiesAgree": true})
	bad = good.duplicate(true)
	bad.body.state.npcs[person].institution = domain + "/propagation"
	bad.body.state.facts[origin].changes.initialization.births[0].institution = domain + "/propagation"
	bad.body.state.facts[source].changes.input_snapshot.members[person].institution = domain + "/propagation"
	_expect_restore_bad("SGS-BIRTH/JOINT-INSTITUTION", bad, receiver, "Current initial carrier, origin allocation and graph snapshot jointly claim another real office.")
	bad = good.duplicate(true)
	bad.body.state.facts[origin].changes.initialization.births[0].representative = false
	bad.body.state.institutions[domain + "/interpretation"].representative = ""
	_expect_restore_bad("SGS-BIRTH/JOINT-REPRESENTATIVE", bad, receiver, "Actual seed representative slot removed consistently with current office.")
	bad = good.duplicate(true)
	bad.body.state.facts[origin].changes.initialization.expanded_at_creation = false
	bad.body.state.facts[source].changes.input_snapshot.expanded_at_creation = false
	_expect_restore_bad("SGS-BIRTH/JOINT-EXPANDED", bad, receiver, "Both origin and graph snapshot deny actual full-world initial expansion.")
	bad = good.duplicate(true)
	bad.body.state.facts[source].changes.input_snapshot.institutions[domain + "/interpretation"].links = []
	_expect_restore_bad("SGS-BIRTH/INSTITUTION-SNAPSHOT", bad, receiver, "Generation snapshot invents a different initialization channel topology.")
	bad = good.duplicate(true)
	bad.body.state.npcs[person].identity_source = good.body.state.domains["DOMAIN-002"].origin
	bad.body.state.facts[source].changes.input_snapshot.members[person].identity_source = bad.body.state.npcs[person].identity_source
	_expect_restore_bad("SGS-BIRTH/JOINT-IDENTITY", bad, receiver, "Current identity and graph snapshot agree on an unrelated domain birth origin.")
	for version: int in [2, 3]:
		bad = good.duplicate(true); bad.body.schema = version
		_expect_restore_bad("SGS-BIRTH/OLD-WORLD-" + str(version), bad, receiver, "Explicit old World schema refusal; no invented migration.")
	bad = good.duplicate(true); bad.body.state.social_graph.schema = 1
	_expect_restore_bad("SGS-BIRTH/OLD-GRAPH", bad, receiver, "Current World envelope with old persistent graph schema refused.")
	bad = good.duplicate(true); bad.body.state.social_graph.erase("cohorts")
	_expect_restore_bad("SGS-BIRTH/MISSING-COHORTS", bad, receiver, "Legacy ring-like state without source-backed cohorts refused.")
	var owned: Dictionary = _owned()
	var actual: Dictionary = _first_relation(owned.world)
	var old_snapshot: String = owned.world.snapshot()
	var mutation: Dictionary = _apply(owned, func() -> Dictionary:
		var current_profile: String = Store.entry(owned.world.state.npcs, actual.changes.a).profile
		owned.world.mutable_npc(actual.changes.a).profile = "NPC_PROFILE_02" if current_profile != "NPC_PROFILE_02" else "NPC_PROFILE_01"
		return {"ok": true})
	_check("SGS-NORMAL/BIRTH-IDENTITY", not mutation.ok and owned.world.snapshot() == old_snapshot, {"result": mutation, "unchanged": owned.world.snapshot() == old_snapshot})

func _focused_fixture() -> Dictionary:
	var world: RefCounted = World.new(catalog)
	var ready: bool = world.generate_hybrid(7919)
	var data: Dictionary = _clock(world)
	ready = ready and _open(data)
	var response: Dictionary = _focus(data, "DOMAIN-002") if ready else {}
	data["ready"] = ready and response.get("ok", false)
	data["response"] = response
	return data

func _expect_turn_bad(id: String, turn_envelope: Dictionary, world_envelope: Dictionary, receiver: RefCounted, description: String, require_world_accept: bool = false) -> void:
	var serialized_world: String = _resign(world_envelope)
	var world_control: RefCounted = World.new(catalog)
	var local_ok: bool = world_control.restore(serialized_world)
	var changed: Dictionary = turn_envelope.duplicate(true)
	changed.body.world = serialized_world
	var serialized: String = _resign(changed)
	_write_text(scratch.path_join("bad-" + id.replace("/", "-") + ".json"), serialized)
	var before: String = receiver.snapshot()
	var accepted: bool = receiver.restore(serialized)
	_check(id, not accepted and receiver.snapshot() == before and (local_ok or not require_world_accept), {"accepted": accepted, "currentWorldAndTurnRetained": receiver.snapshot() == before, "correctInnerAndOuterChecksum": true, "worldOnlyAcceptsLocalChain": local_ok, "worldOnlyError": world_control.last_error, "turnError": receiver.last_error, "mutation": description, "requiresIndependentReceiptRejection": require_world_accept})

func _focus_restore_cases() -> void:
	var data: Dictionary = _focused_fixture()
	var world: RefCounted = data.world
	var saved: String = data.turn.snapshot()
	_write_text(scratch.path_join("first-focus-turn-good.json"), saved)
	var turn_envelope: Dictionary = JSON.parse_string(saved)
	var good: Dictionary = JSON.parse_string(turn_envelope.body.world)
	var receiver_data: Dictionary = _focused_fixture()
	var receiver: RefCounted = receiver_data.turn
	var roundtrip: bool = receiver.restore(saved) and receiver.snapshot() == saved and receiver.restore(_resign(turn_envelope)) and receiver.snapshot() == saved
	var cohort: Dictionary = good.body.state.social_graph.cohorts.get("DOMAIN-002/first_focus", {})
	var nominations: Array = []
	var focus: String = ""
	for id: String in good.body.state.facts:
		var fact: Dictionary = good.body.state.facts[id]
		if fact.kind == "nomination" and fact.domain == "DOMAIN-002" and fact.changes.birth.local_expansion: nominations.append(id); focus = fact.changes.birth.focus
	var generation: String = str(cohort.get("generation_source", ""))
	_check("SGS-FOCUS/ROUNDTRIP", data.ready and receiver_data.ready and roundtrip and turn_envelope.body.schema == 3 and not nominations.is_empty() and not focus.is_empty(), {"nominationFacts": nominations, "focus": focus, "generation": generation, "schema": turn_envelope.body.schema, "actualReceiptCount": turn_envelope.body.commit_sequence, "originalAndUnchangedResigned": roundtrip})
	if nominations.is_empty() or focus.is_empty(): return
	var person: String = good.body.state.facts[nominations[0]].actor
	var birth: Dictionary = good.body.state.facts[nominations[0]].changes.birth
	var bad: Dictionary = good.duplicate(true)
	bad.body.state.facts[nominations[0]].changes.birth.profile = "NPC_PROFILE_02" if birth.profile != "NPC_PROFILE_02" else "NPC_PROFILE_01"
	bad.body.state.npcs[person].profile = bad.body.state.facts[nominations[0]].changes.birth.profile
	var profile: Dictionary = catalog.tables.npc_profiles[bad.body.state.npcs[person].profile]
	var member: Dictionary = bad.body.state.facts[generation].changes.input_snapshot.members[person]
	member.profile = profile.id; member.influence = int(profile.influence); member.role_tags = Array(str(profile.role_tags).split(";")); member.need_tags = Array(str(profile.need_tags).split(";"))
	_expect_turn_bad("SGS-FOCUS/JOINT-PROFILE", turn_envelope, bad, receiver, "Actual nomination, identity and cohort snapshot agree on a different authored profile, but first-focus recipe must reject it.")
	bad = good.duplicate(true)
	bad.body.state.facts[nominations[0]].changes.birth.institution = "DOMAIN-002/order"
	bad.body.state.npcs[person].institution = "DOMAIN-002/order"
	bad.body.state.facts[generation].changes.input_snapshot.members[person].institution = "DOMAIN-002/order"
	_expect_turn_bad("SGS-FOCUS/JOINT-INSTITUTION", turn_envelope, bad, receiver, "Birth/current carrier/cohort snapshot jointly moved to a real but different office.")
	bad = good.duplicate(true)
	bad.body.state.facts[nominations[0]].changes.birth.focus = good.body.state.domains["DOMAIN-002"].origin
	_expect_turn_bad("SGS-FOCUS/WRONG-FOCUS", turn_envelope, bad, receiver, "Nomination claims an origin instead of its actual acquisition fact.")
	for variant: String in ["SEQUENCE", "PHASE", "RANGE"]:
		bad = good.duplicate(true)
		var ids: Array = nominations.duplicate(); ids.append(focus)
		if bad.body.state.facts[focus].changes.has("admission"): ids.append(bad.body.state.facts[focus].changes.admission)
		for id: String in ids:
			var position: Dictionary = bad.body.state.facts[id].changes.birth.position if id in nominations else bad.body.state.facts[id].changes.position
			if variant == "SEQUENCE": position.sequence += 100
			elif variant == "PHASE": position.entry_phase = "events"
			else: position.fact_before += 1
		_expect_turn_bad("SGS-FOCUS/JOINT-" + variant, turn_envelope, bad, receiver, "All local focus/birth positions agree, but disagree with the independently retained real Turn receipt.", variant != "RANGE")
	bad = good.duplicate(true)
	bad.body.state.facts[generation].causal_parents.erase(focus)
	_expect_turn_bad("SGS-FOCUS/MISSING-FOCUS-PARENT", turn_envelope, bad, receiver, "Generation loses the actual focus parent while cohort/snapshots remain present.")
	bad = good.duplicate(true)
	bad.body.state.facts[focus].changes.erase("admission")
	_expect_turn_bad("SGS-FOCUS/MISSING-ADMISSION", turn_envelope, bad, receiver, "Actual focus loses its preceding real reservation marker.")
	bad = good.duplicate(true)
	bad.body.state.facts[focus].changes.admission = good.body.state.domains["DOMAIN-002"].origin
	bad.body.state.facts[focus].causal_parents = [good.body.state.domains["DOMAIN-002"].origin]
	_expect_turn_bad("SGS-FOCUS/WRONG-ADMISSION", turn_envelope, bad, receiver, "A real origin replaces the exact preceding attention_admitted source.")
	var old_turn: Dictionary = turn_envelope.duplicate(true); old_turn.body.schema = 2
	var before: String = receiver.snapshot()
	var accepted: bool = receiver.restore(_resign(old_turn))
	_check("SGS-FOCUS/OLD-TURN", not accepted and receiver.snapshot() == before, {"accepted": accepted, "error": receiver.last_error, "currentTurnRetained": receiver.snapshot() == before})
	for request_kind: String in ["set_plan", "release_focus"]:
		var request_bad: Dictionary = turn_envelope.duplicate(true)
		var sequence: int = int(birth.position.sequence)
		var altered: Dictionary = {}
		for id: String in request_bad.body.context.receipts:
			if int(request_bad.body.context.receipts[id].sequence) != sequence: continue
			altered = request_bad.body.context.receipts[id]
			if request_kind == "set_plan":
				altered.request = {"id": id, "op": "set_plan", "turn": altered.request.turn, "phase": altered.request.phase, "participant": "graph-clock-fixture", "payload": {}}
			else: altered.request.command = {"kind": "release_focus", "domain": "DOMAIN-002"}
			altered.fingerprint = World.canonical(altered.request).sha256_text()
		before = receiver.snapshot()
		accepted = receiver.restore(_resign(request_bad))
		_write_text(scratch.path_join("bad-SGS-FOCUS-UNAUTHORIZED-" + request_kind + ".json"), _resign(request_bad))
		_check("SGS-FOCUS/UNAUTHORIZED-" + request_kind.to_upper(), not accepted and receiver.snapshot() == before, {"accepted": accepted, "error": receiver.last_error, "matchingRangeAndPositionsUnchanged": true, "receipt": altered, "currentTurnRetained": receiver.snapshot() == before})
	var released: Dictionary = _request(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-002"}})
	var later: bool = released.get("ok", false) and _finish(data) and _open(data)
	var repeated: Dictionary = _focus(data, "DOMAIN-002") if later else {}
	var refocus_save: String = data.turn.snapshot()
	var refocus_turn: Dictionary = JSON.parse_string(refocus_save)
	var refocus_world: Dictionary = JSON.parse_string(refocus_turn.body.world)
	var focuses: Array = _facts(world, "focus_acquired")
	var last_focus: String = str(focuses[-1].id) if not focuses.is_empty() else ""
	bad = refocus_world.duplicate(true)
	if not last_focus.is_empty():
		bad.body.state.facts[last_focus].domain = "DOMAIN-999"
		bad.body.state.facts[last_focus].targets = ["DOMAIN-999"]
	_check("SGS-FOCUS/REFOCUS-ROUNDTRIP", repeated.get("ok", false) and receiver.restore(refocus_save) and receiver.snapshot() == refocus_save, {"request": repeated, "actualRefocusFact": last_focus, "alreadyCompletedCohortUnchanged": World.canonical(world.state.social_graph.cohorts["DOMAIN-002/first_focus"]) == World.canonical(cohort)})
	_expect_turn_bad("SGS-FOCUS/REFOCUS-UNKNOWN-DOMAIN", refocus_turn, bad, receiver, "A real later refocus (without a new cohort) claims a missing domain. Must reject semantically without engine ERROR.")

func _bootstrap_cases() -> void:
	var world: RefCounted = ObservedBootstrapWorld.new(catalog)
	var ready: bool = world.generate_hybrid(7919)
	var owner: RefCounted = Turn.new(world)
	var accepted_issuers: Dictionary = Events.issuer_capability(catalog)
	var prayers: RefCounted = Prayers.new(catalog, accepted_issuers)
	var events: RefCounted = Events.new(catalog)
	var powers: RefCounted = Powers.new(catalog, accepted_issuers)
	ready = ready and owner._attached and prayers.install(owner) and events.install(owner)
	# The real callback passes exact managed action identity; Powers.install is
	# intentionally unavailable without CULT. Never manufacture either system.
	ready = ready and owner.register_participant("powers", powers.version, ["actions", "powers_start", "powers_end"], ["powers"], powers.handle)
	var before: String = world.snapshot()
	var response: Dictionary = owner.bootstrap_prayers() if ready else {}
	var stage: String = world.bootstrap_stage
	var final: Dictionary = {}
	var saved: Dictionary = JSON.parse_string(stage) if not stage.is_empty() else {}
	var births: Array = []
	if not saved.is_empty():
		final = saved.body.state.facts.get(saved.body.state.applied_authorizations.get("prayer/bootstrap", ""), {})
		for fact: Dictionary in saved.body.state.facts.values():
			if fact.kind == "nomination" and fact.changes.birth.position.scope == "bootstrap": births.append(fact)
	_write_text(scratch.path_join("bootstrap-uncommitted-stage.json"), stage)
	_write(scratch.path_join("bootstrap-outer-result.json"), {"ready": ready, "response": response, "rolledBack": world.snapshot() == before, "label": "uncommitted-stage-observation", "missingPowerSystem": not world.state.has("power_system"), "missingCultSystem": not world.state.has("cult_system"), "boundary": "Real Prayers/Events installation and real Powers.handle registration only; never Powers.install/full Session."})
	_check("SGS-BOOTSTRAP/OUTER-BOUNDARY", ready and not response.get("ok", false) and world.snapshot() == before and not stage.is_empty() and not world.state.has("cult_system") and not world.state.has("power_system"), {"response": response, "rolledBack": world.snapshot() == before, "label": "uncommitted-stage-observation", "actualFinalEmittedBeforeContextRejection": final.get("kind") == "prayer_bootstrap"})
	var receiver: RefCounted = World.new(catalog)
	var roundtrip: bool = receiver.generate_hybrid(7) and not stage.is_empty() and receiver.restore(stage) and receiver.snapshot() == stage and receiver.restore(_resign(saved)) and receiver.snapshot() == stage
	var chain: bool = final.get("kind") == "prayer_bootstrap" and births.size() == 1
	var nomination: Dictionary = births[0] if births.size() == 1 else {}
	var selected: Dictionary = {}; var contact: Dictionary = {}; var situation: Dictionary = {}; var call: Dictionary = {}; var fixed: Dictionary = {}
	if chain:
		situation = saved.body.state.facts[final.changes.source]
		contact = saved.body.state.facts[situation.changes.facts.contact]
		call = saved.body.state.facts[situation.changes.call]
		for id: String in contact.causal_parents:
			if saved.body.state.facts[id].kind == "prayer_contact_selected": selected = saved.body.state.facts[id]
		for id: String in final.causal_parents:
			if saved.body.state.facts[id].kind == "prayer_fixed": fixed = saved.body.state.facts[id]
		chain = selected.get("kind") == "prayer_contact_selected" and nomination.id in selected.causal_parents and nomination.id in contact.causal_parents and selected.id in contact.causal_parents and contact.id in situation.causal_parents and call.id in situation.causal_parents and situation.id in final.causal_parents and fixed.get("kind") == "prayer_fixed" and fixed.changes.candidate.source == situation.id and fixed.changes.candidate.actors == [nomination.actor]
	_check("SGS-BOOTSTRAP/WORLD-CHAIN", roundtrip and chain and nomination.changes.birth.position.scope == "bootstrap", {"label": "uncommitted-stage-observation", "originalAndUnchangedResigned": roundtrip, "nomination": nomination, "selected": selected, "contact": contact, "call": call, "situation": situation, "fixed": fixed, "final": final, "scope": "Actual Turn-produced uncommitted world fragment accepted by World-only audit; outer Turn bootstrap remained rejected. This is not an accepted new campaign."})
	if not chain or not roundtrip: return
	for variant: String in ["SELECTED-NOMINATION", "CONTACT-SELECTED", "CONTACT-NOMINATION", "CALL", "FIXED", "FINAL-ONCE", "BOOTSTRAP-POSITION"]:
		var bad: Dictionary = saved.duplicate(true)
		match variant:
			"SELECTED-NOMINATION": bad.body.state.facts[selected.id].causal_parents.erase(nomination.id)
			"CONTACT-SELECTED": bad.body.state.facts[contact.id].causal_parents.erase(selected.id)
			"CONTACT-NOMINATION": bad.body.state.facts[contact.id].causal_parents.erase(nomination.id)
			"CALL": bad.body.state.facts[call.id].changes.petitioner = _people(receiver)[0]
			"FIXED": bad.body.state.facts[fixed.id].changes.candidate.actors = []
			"FINAL-ONCE": bad.body.state.applied_authorizations["prayer/bootstrap"] = fixed.id
			"BOOTSTRAP-POSITION": bad.body.state.facts[nomination.id].changes.birth.position.fact_before += 1
		_expect_restore_bad("SGS-BOOTSTRAP/" + variant, bad, receiver, "One actual bootstrap-chain invariant is broken; all unrelated actual producer facts and current graph remain intact.", {"label": "uncommitted-stage-observation", "variant": variant})

func _component_clock() -> Dictionary:
	var world: RefCounted = World.new(catalog)
	var valid: bool = world.generate_hybrid(7919)
	var owner: RefCounted = ComponentTurn.new(world)
	var harness: RefCounted = PhaseHarness.new()
	valid = valid and owner._attached and owner.register_participant("graph-clock-fixture", "1", ["events", "prepay", "income", "deadlines", "ending"], [], harness.handle)
	valid = valid and owner.register_participant("graph-components", "test-driver-1", ["actions"], [], harness.handle)
	return {"world": world, "turn": owner, "owner": owner, "harness": harness, "valid": valid, "next_request": 0, "sequence": 0}

func _component_action(data: Dictionary, operation: Callable) -> Dictionary:
	data.turn.component = operation
	data.sequence = int(data.turn.commit_sequence) + 1
	var response: Dictionary = _request(data, "act", {"participant": "graph-components", "action": "QA_COMPONENT", "payload": {}})
	var value: Dictionary = data.turn.component_result.duplicate(true)
	# The closure captures data, which contains its owner. Release on success AND
	# failure so the driver cannot retain itself/World through a Callable cycle.
	data.turn.component = Callable()
	return {"ok": response.get("ok", false), "response": response, "value": value, "error": data.turn.last_error, "callbackReleased": not data.turn.component.is_valid()}

func _combination_cases() -> void:
	var data: Dictionary = _component_clock()
	var valid: bool = _open(data)
	var first: Dictionary = _focus(data, "DOMAIN-002") if valid else {}
	valid = valid and first.get("ok", false)
	var world: RefCounted = data.world
	var cohort: Dictionary = world.state.social_graph.cohorts.get("DOMAIN-002/first_focus", {})
	var relation: Dictionary = {}
	for fact: Dictionary in _facts(world, "initial_relationship"):
		if fact.domain == "DOMAIN-002": relation = fact; break
	if relation.is_empty():
		_check("SGS-COMBINED/TURN-CONTINUITY", false, {"firstFocus": first, "error": "No real initial relationship from actual first focus"})
		_check("SGS-COMBINED/RESTORE-REFOCUS-MIGRATION", false, {})
		return
	var a: String = relation.changes.a; var b: String = relation.changes.b
	var created: Dictionary = _component_action(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, relation.id))
	var retired: String = str(created.value.get("head", ""))
	var removal: Dictionary = _component_action(data, func() -> Dictionary: return _retire_component(data, retired))
	var fresh: Dictionary = _component_action(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, relation.id))
	var head: String = str(fresh.value.get("head", ""))
	valid = valid and created.ok and removal.ok and fresh.ok and created.callbackReleased and removal.callbackReleased and fresh.callbackReleased and retired != head and world.relation_source(retired).is_empty() and not world.relation_source(head).is_empty()
	var save: String = data.turn.snapshot()
	_write_text(scratch.path_join("combined-continuous-turn-good.json"), save)
	var target: Dictionary = _component_clock()
	var restored: bool = target.valid and target.turn.restore(save) and target.turn.snapshot() == save
	var unchanged_signed: Dictionary = JSON.parse_string(save)
	restored = restored and target.turn.restore(_resign(unchanged_signed)) and target.turn.snapshot() == save
	_check("SGS-COMBINED/TURN-CONTINUITY", valid and restored, {"firstFocus": first, "cohort": History.export_value(cohort), "created": created, "retirement": removal, "newEpisode": fresh, "actualReceiptCount": data.turn.commit_sequence, "originalAndUnchangedResigned": restored, "scope": "Test-driven component combination: only act/QA_COMPONENT dispatch routes to actual business handlers; production submit, Transaction, receipt, every World/context validator and Turn3 restore remain unchanged. This is not a complete PR/Event request or Session."})
	if not restored:
		_check("SGS-COMBINED/RESTORE-REFOCUS-MIGRATION", false, {"error": target.turn.last_error}); return
	# Continue with the same restored real clock, using IDs after the saved run.
	target.next_request = data.next_request
	var restored_world: RefCounted = target.world
	var old_graph: String = World.canonical(restored_world.state.social_graph)
	var historical: String = World.canonical(Store.entry(restored_world.state.facts, retired))
	var original_identity: String = Store.entry(restored_world.state.npcs, a).identity_source
	var release: Dictionary = _request(target, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-002"}})
	var later: bool = release.get("ok", false) and _finish(target) and _open(target)
	var refocus: Dictionary = _focus(target, "DOMAIN-002") if later else {}
	var destination: String = str(restored_world.state.domains["DOMAIN-002"].neighbors[0])
	var migration: Dictionary = _component_action(target, func() -> bool: return restored_world.submit({"kind": "migrate", "npc": a, "domain": destination, "parents": [head]}, target.turn)) if refocus.get("ok", false) else {}
	var stable: bool = refocus.get("ok", false) and migration.get("ok", false) and migration.get("callbackReleased", false) and World.canonical(restored_world.state.social_graph) == old_graph and World.canonical(Store.entry(restored_world.state.facts, retired)) == historical and Store.entry(restored_world.state.npcs, a).identity_source == original_identity and restored_world.contact_context(a, b).is_empty() and not restored_world.relation_source(head).is_empty()
	var final_save: String = target.turn.snapshot()
	var final_receiver: Dictionary = _component_clock()
	var final_restore: bool = stable and final_receiver.turn.restore(final_save) and final_receiver.turn.snapshot() == final_save
	_write_text(scratch.path_join("combined-after-refocus-migration-good.json"), final_save)
	_check("SGS-COMBINED/RESTORE-REFOCUS-MIGRATION", stable and final_restore, {"release": release, "refocus": refocus, "migration": migration, "identityAndBothEpisodesStable": stable, "postMigrationTurnRestore": final_restore, "finalReceiptCount": target.turn.commit_sequence, "contactEligibilityChangedWithoutErasingHistory": restored_world.contact_context(a, b).is_empty(), "scope": "Same test-driven component combination continues after genuine Turn3 restoration; actual attention release/refocus and actual World migration command, no injected target relationship or invented receipts."})

func _admission_fixture(kind: String) -> Dictionary:
	var world: RefCounted = World.new(catalog)
	var ready: bool = world.generate_hybrid(7919)
	var data: Dictionary = _clock(world)
	var actor: RefCounted = AdmissionHarness.new()
	actor.descriptor = {"family": "power", "content_id": "POWER_TRANSFER" if kind == "TRANSFER" else "POWER_MANIFEST", "variant": "use", "source_domain": "DOMAIN-006", "target": "DOMAIN-002", "source": world.state.domains["DOMAIN-006"].origin, "participants": []}
	if kind == "RITUAL": actor.descriptor["ritual_domains"] = ["DOMAIN-006", "DOMAIN-002"]
	ready = ready and data.turn.register_participant("admission-fixture", "1", ["actions"], [], actor.handle)
	data["actor"] = actor; data.valid = data.valid and ready
	return data

func _strategy_fixture() -> Dictionary:
	var world: RefCounted = World.new(catalog)
	var valid: bool = world.generate_hybrid(29)
	var economy: RefCounted = StrategyFixtureEconomy.new(catalog, {"graph-plan-fixture": "1"})
	valid = valid and economy.initialize(world)
	var domain: String = "DOMAIN-002"
	var person: String = "NPC-%08d" % int(world.state.next_npc)
	valid = valid and _standalone_nomination(world, domain, domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[domain].origin)
	world.mutable_npc(person).loyalty = 80
	var origin: String = world.state.domains[domain].origin
	var needs: Dictionary = world.attention.preview_needs(world.state, {"family": "system", "content_id": "MEMBER_ENROLL", "variant": "use", "participants": [person], "nominees": [person], "source": origin})
	var reserved: Dictionary = world.attention.reserve(world, needs) if needs.get("ok", false) else {}
	valid = valid and reserved.get("ok", false) and world.attention.enroll(world, person, origin, str(reserved.get("token", "")))
	if reserved.get("ok", false): world.attention.finish(world, reserved.token)
	valid = valid and world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 6, "parents": [origin]})
	var cult: String = "CULT-" + domain
	var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, person, [person], [origin], {"issuer": "graph-plan-fixture", "version": "1", "cult": cult, "domain": domain, "leader": person, "cohesion": 80}, []) if valid else ""
	valid = valid and not authorization.is_empty() and world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]})
	# Explicit lawful initial strategy value, before attaching the real clock.
	if valid: world.state.cults[cult].strategy = "expand"
	economy.fixture_cult = cult; economy.fixture_source = world.state.cults.get(cult, {}).get("established_source", "")
	var data: Dictionary = _clock(world, economy)
	data["economy"] = economy; data["cult"] = cult; data.valid = data.valid and valid
	return data

func _admission_cases() -> void:
	for kind: String in ["TRANSFER", "RITUAL"]:
		var data: Dictionary = _admission_fixture(kind)
		var ready: bool = _open(data)
		var response: Dictionary = _request(data, "act", {"participant": "admission-fixture", "action": "CONTROLLED_ADMISSION", "payload": {}}) if ready else {}
		var admissions: Array = _facts(data.world, "attention_admitted")
		var focuses: Array = _facts(data.world, "focus_acquired")
		var sequence: Array = focuses.map(func(fact: Dictionary) -> String: return fact.domain)
		var canonical: bool = admissions.size() == 1 and admissions[0].targets == ["DOMAIN-002", "DOMAIN-006"] and admissions[0].changes.focus == ["DOMAIN-002", "DOMAIN-006"]
		var actual_order: bool = sequence == ["DOMAIN-006", "DOMAIN-002"]
		var saved: String = data.turn.snapshot()
		_write_text(scratch.path_join("admission-" + kind.to_lower() + "-good.json"), saved)
		var receiver: Dictionary = _admission_fixture(kind)
		var restored: bool = receiver.valid and receiver.turn.restore(saved) and receiver.turn.snapshot() == saved
		_check("SGS-ADMISSION/MULTI-" + kind, ready and response.get("ok", false) and canonical and actual_order and restored, {"response": response, "admissions": admissions, "canonicalMetadata": canonical, "realExpansionOrder": sequence, "turnRestore": restored, "scope": "Ordinary registered generic component declares the existing transfer/ritual focus policy; real Turn._invoke/reserve/payment/expansion/receipt/restore. This is not a Power execution or formal ritual."})
	var planned: Dictionary = _strategy_fixture()
	var opened: bool = _open(planned)
	var selected: Dictionary = _request(planned, "set_plan", {"participant": "economy", "payload": {}}) if opened else {}
	var expanded: bool = selected.get("ok", false) and _finish(planned)
	var first_admissions: Array = _facts(planned.world, "attention_admitted")
	var next: bool = expanded and _open(planned)
	var hold: Dictionary = _request(planned, "set_plan", {"participant": "economy", "payload": {"strategies": {planned.cult: "hold"}}}) if next else {}
	var changed: bool = hold.get("ok", false) and _finish(planned) and planned.world.state.cults[planned.cult].strategy == "hold"
	var save: String = planned.turn.snapshot()
	var target: Dictionary = _strategy_fixture()
	var roundtrip: bool = changed and target.turn.restore(save) and target.turn.snapshot() == save
	_write_text(scratch.path_join("admission-default-strategy-later-hold-good.json"), save)
	_check("SGS-ADMISSION/DEFAULT-STRATEGY-HISTORY", expanded and not first_admissions.is_empty() and changed and roundtrip, {"defaultPlan": selected, "laterHoldPlan": hold, "initialAdmissions": first_admissions, "currentStrategy": planned.world.state.cults.get(planned.cult, {}).get("strategy"), "turnRestore": roundtrip, "error": target.turn.last_error, "scope": "Controlled legal expansion preview and declared initial expand strategy, same legacy establishment/member prerequisites as A. Actual Economy phase handlers later apply explicit hold. Restore must use historical locked expand rather than current hold. No full Economy/CULT installation acceptance."})

# Persistent graph schema migrated; all original fact/model/budget/privacy checks remain.
func _audit_graph(world: RefCounted) -> Dictionary:
	var graph: Dictionary = world.state.get("social_graph", {})
	var ok: bool = graph.get("schema") == 2 and graph.get("model_version") == catalog.integer("model_version")
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
