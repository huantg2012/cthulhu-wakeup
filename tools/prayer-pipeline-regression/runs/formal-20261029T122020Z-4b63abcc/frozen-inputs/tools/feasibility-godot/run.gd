extends SceneTree

const Catalog = preload("res://catalog.gd")
const Simulation = preload("res://simulation.gd")
var content: RefCounted
var results: Array = []
var failed: int = 0
var repo: String = ""

func _init() -> void:
	repo = ProjectSettings.globalize_path("res://../..").simplify_path()
	content = Catalog.new()
	var started: int = Time.get_ticks_usec()
	check("CSV valid content", content.load_files(repo.path_join("data")), {"errors": content.errors})
	if failed > 0:
		finish(started)
		return
	test_bad_content()
	test_generation()
	test_events()
	test_determinism_and_saves()
	test_performance(6, 20, 1000, 8317)
	test_performance(100, 20, 1000, 92031)
	finish(started)

func check(name: String, passed: bool, detail: Dictionary = {}) -> void:
	results.append({"name": name, "status": "PASS" if passed else "FAIL", "detail": detail})
	if not passed:
		failed += 1
	print(("PASS " if passed else "FAIL ") + name + (" " + JSON.stringify(detail) if not detail.is_empty() else ""))

func fixture(seed_value: int = 73, civilizations: int = 1, npcs: int = 4) -> RefCounted:
	var simulation: RefCounted = Simulation.new(content)
	if not simulation.new_run(seed_value, civilizations, npcs):
		push_error(simulation.last_error)
	return simulation

func test_bad_content() -> void:
	var mutations: Array = []
	var rows: Dictionary = content.rows.duplicate(true)
	rows.events[0].effect = "execute_script"
	mutations.append({"name": "unknown effect", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.events[0].min_alert = "90"
	rows.events[0].max_alert = "10"
	mutations.append({"name": "contradictory range", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.events[0].followup = "missing_event"
	mutations.append({"name": "missing event reference", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.events[0].followup = "prayer"
	mutations.append({"name": "cyclic followup", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.parameters.remove_at(0)
	mutations.append({"name": "missing required parameter", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.axes = rows.axes.filter(func(row: Dictionary) -> bool: return row.dimension != "channel")
	mutations.append({"name": "missing dimension", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.npcs.append(rows.npcs[0].duplicate(true))
	mutations.append({"name": "duplicate ID", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.npcs[0].sanity = "NaN"
	mutations.append({"name": "noninteger NPC attribute", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.axes[6].requires_paradigm = "missing_paradigm"
	mutations.append({"name": "missing paradigm reference", "rows": rows})
	rows = content.rows.duplicate(true)
	rows.events[0].unexpected = "injected"
	mutations.append({"name": "unknown schema field", "rows": rows})
	var rejected: int = 0
	var details: Array = []
	for mutation: Dictionary in mutations:
		var errors: Array = content.validate_rows(mutation.rows)
		if not errors.is_empty():
			rejected += 1
		details.append({"name": mutation.name, "errors": errors})
	check("Malformed offline generated content rejected", rejected == mutations.size(), {"cases": mutations.size(), "rejected": rejected, "cases_detail": details})

func test_generation() -> void:
	var start: int = Time.get_ticks_usec()
	var signatures: Dictionary = {}
	var valid: int = 0
	var civs: int = 0
	var npc_count: int = 0
	var max_attempts: int = 0
	for seed_value: int in range(1000, 2000):
		var simulation: RefCounted = fixture(seed_value, 6, 20)
		if simulation.last_error.is_empty() and simulation.validate_state(simulation.state).is_empty():
			valid += 1
		max_attempts = maxi(max_attempts, simulation.generation_attempts)
		civs += simulation.state.civilizations.size()
		npc_count += simulation.state.npcs.size()
		for id: String in simulation.state.civilizations:
			var civ: Dictionary = simulation.state.civilizations[id].duplicate(true)
			civ.erase("id")
			civ.erase("members")
			signatures[JSON.stringify(civ, "", true)] = true
	check("1000 seeded civilization generations", valid == 1000, {"valid_seeds": valid, "civilizations": civs, "npcs": npc_count, "unique_configuration_signatures": signatures.size(), "max_attempts_per_6_civilizations": max_attempts, "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0})
	var broken: RefCounted = Catalog.new()
	broken.load_files(repo.path_join("data"))
	# A structurally valid pool can still be globally unsatisfiable. Runtime remains bounded.
	for row: Dictionary in broken.rows.axes:
		if row.dimension == "paradigm":
			row.id = "tech" if row.id == "tech" else "unused_" + str(row.id)
		if row.dimension == "channel":
			row.requires_paradigm = "unreachable"
	var simulation: RefCounted = Simulation.new(broken)
	var success: bool = simulation.new_run(42, 1, 4)
	check("Unsatisfiable generator terminates", not success and simulation.generation_attempts == int(broken.parameters.generation_attempt_limit), {"attempts": simulation.generation_attempts, "reason": simulation.last_error})

func event_ids(events: Array) -> Array:
	var output: Array = []
	for event: Dictionary in events:
		output.append(event.id)
	return output

func test_events() -> void:
	var simulation: RefCounted = fixture()
	var civ: Dictionary = simulation.state.civilizations.civ_0000
	civ.alert = 40
	civ.pollution = 30
	var ids: Array = event_ids(simulation.eligible_events("civ_0000"))
	check("Event eligibility and priority", ids == ["investigation", "quarantine", "revelation", "prayer"], {"eligible_order": ids})
	simulation.state.fired["civ_0000:investigation"] = 0
	simulation.state.fired["civ_0000:revelation"] = 0
	ids = event_ids(simulation.eligible_events("civ_0000"))
	check("Cooldown and once-only filtering", not "investigation" in ids and not "revelation" in ids, {"eligible_order": ids})
	simulation.state.turn = 6
	ids = event_ids(simulation.eligible_events("civ_0000"))
	check("Cooldown reopens while once-only stays closed", "investigation" in ids and not "revelation" in ids)
	# Equal-priority candidates must resolve by ID, independent of data insertion order.
	var priority: int = content.events.quarantine.priority
	content.events.quarantine.priority = content.events.investigation.priority
	ids = event_ids(simulation.eligible_events("civ_0000"))
	check("Stable tie ordering", ids.find("investigation") < ids.find("quarantine"))
	content.events.quarantine.priority = priority
	# Multiple event budget exercises the exclusion group separately from the cap.
	var saved_chances: Dictionary = {}
	for key: String in content.events:
		saved_chances[key] = content.events[key].chance
		content.events[key].chance = 100
	var budget: int = content.parameters.max_events_per_civilization_turn
	content.parameters.max_events_per_civilization_turn = 3
	simulation = fixture()
	simulation.state.civilizations.civ_0000.alert = 40
	simulation.state.civilizations.civ_0000.pollution = 30
	simulation.advance()
	var fired_kinds: Array = []
	for record: Dictionary in simulation.state.history.values():
		fired_kinds.append(record.kind)
	check("Mutual exclusion under multi-event budget", "investigation" in fired_kinds and not "quarantine" in fired_kinds and "revelation" in fired_kinds and not "prayer" in fired_kinds, {"fired": fired_kinds})
	content.parameters.max_events_per_civilization_turn = budget
	for key: String in content.events:
		content.events[key].chance = 0
	simulation = fixture()
	for turn: int in 20:
		simulation.advance()
	check("Turns may contain zero events", simulation.stats.executed == 0 and simulation.stats.blank_turns == 20)
	for key: String in content.events:
		content.events[key].chance = saved_chances[key]
	simulation = fixture()
	simulation.state.civilizations.civ_0000.alert = 40
	simulation.state.civilizations.civ_0000.pollution = 30
	simulation._execute(content.events.investigation, "civ_0000", "npc_0000_0000", "")
	var parent: String = simulation.state.pending[0].parent
	simulation.advance()
	simulation.advance()
	var linked: bool = false
	for record: Dictionary in simulation.state.history.values():
		if record.kind == "echo" and record.parent == parent and int(record.turn) == 2:
			linked = true
	check("Delayed causal consequence retains parent", linked, {"parent": parent, "records": simulation.state.history.size()})
	simulation = fixture()
	simulation._execute(content.events.investigation, "civ_0000", "npc_0000_0000", "")
	simulation._apply_command({"kind": "kill", "civilization": "civ_0000", "npc": "npc_0000_0000"})
	simulation.advance()
	simulation.advance()
	check("Dead scheduled target cancels and relic detaches", simulation.stats.cancelled_dead == 1 and simulation.state.relics.relic_0000.holder == "" and not simulation.state.npcs.npc_0000_0000.alive)
	for npc: Dictionary in simulation.state.npcs.values():
		npc.alive = false
	check("Dead population cannot issue prayer", simulation.eligible_events("civ_0000").is_empty())
	simulation = fixture()
	simulation._execute(content.events.investigation, "civ_0000", "npc_0000_0000", "")
	simulation.state.pending[0].expires = 0
	simulation.advance()
	check("Expired queue entry is discarded", simulation.stats.cancelled_expired == 1)
	simulation = fixture()
	simulation.state.faith = 0
	var before: String = JSON.stringify(simulation.state, "", true)
	var accepted: bool = simulation._apply_command({"kind": "intervene", "civilization": "civ_0000"})
	check("Unaffordable action is atomic rejection", not accepted and JSON.stringify(simulation.state, "", true) == before)
	simulation = fixture()
	var record_id: String = simulation._record("intervention", "civ_0000", "", "", {"success": false, "effect": "alert", "delta": 6})
	simulation.state.turn = 100
	simulation._compact_history()
	var compacted: Dictionary = simulation.state.history[record_id]
	check("History compaction preserves outcome and effect facts", compacted.facts == {"success": false, "effect": "alert", "delta": 6} and not compacted.has("detail"))

func commands_for(simulation: RefCounted, _turn: int) -> Array:
	var commands: Array = []
	# The load driver deliberately preserves active people and event eligibility.
	# This is a test driver, not an evaluated gameplay strategy.
	for civ_id: String in simulation.state.civilizations:
		var kind: String = "conceal" if int(simulation.state.civilizations[civ_id].alert) >= 45 else "intervene"
		commands.append({"kind": kind, "civilization": civ_id})
	return commands

func test_determinism_and_saves() -> void:
	var a: RefCounted = fixture(984153, 6, 20)
	var b: RefCounted = fixture(984153, 6, 20)
	var generation_before: Dictionary = a.rng_snapshot().generation
	var cosmetic: RandomNumberGenerator = RandomNumberGenerator.new()
	cosmetic.seed = 123
	for turn: int in 70:
		a.advance(commands_for(a, turn))
		for draw: int in 37:
			cosmetic.randf()
		b.advance(commands_for(b, turn))
	check("Same seed and commands reproduce despite cosmetic RNG", a.save_text() == b.save_text(), {"turns": 70, "extra_cosmetic_draws": 2590})
	check("Simulation does not consume generation stream", a.rng_snapshot().generation == generation_before)
	var c: RefCounted = fixture(984154, 6, 20)
	check("Different seed changes generated state", c.state.civilizations != fixture(984153, 6, 20).state.civilizations)
	# Include persistent deaths, relocated relic, and an unresolved consequence in the snapshot.
	a._apply_command({"kind": "kill", "civilization": "civ_0000", "npc": "npc_0000_0000"})
	a.state.npcs.npc_0000_0001.alive = true
	a._execute(content.events.investigation, "civ_0000", "npc_0000_0001", str(a.state.last_causes.get("civ_0000", "")))
	var snapshot: String = a.save_text()
	var restored: RefCounted = Simulation.new(content)
	var loaded: bool = restored.load_text(snapshot)
	check("Save restores exact state with deaths and pending effects", loaded and a.save_text() == restored.save_text(), {"bytes": snapshot.to_utf8_buffer().size(), "pending": a.state.pending.size(), "error": restored.last_error})
	var big_rng: bool = false
	for record: Dictionary in a.rng_snapshot().values():
		if abs(int(record.state)) > 9007199254740991:
			big_rng = true
	check("RNG snapshot exercises integers larger than 2^53", big_rng)
	if loaded:
		for turn: int in range(70, 170):
			a.advance(commands_for(a, turn))
			restored.advance(commands_for(restored, turn))
	check("100-turn resumed continuation is byte-identical", loaded and a.save_text() == restored.save_text())
	var corruptions: Array = []
	corruptions.append({"name": "truncated", "text": snapshot.substr(0, snapshot.length() / 2)})
	var envelope: Dictionary = JSON.parse_string(snapshot)
	var payload: Dictionary = JSON.parse_string(envelope.payload)
	var changed: Dictionary = payload.duplicate(true)
	changed.content = "unsupported_content"
	corruptions.append({"name": "content version", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.schema = 999
	corruptions.append({"name": "schema version", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.engine = "unknown-engine"
	corruptions.append({"name": "engine version", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.npcs.erase("npc_0000_0001")
	corruptions.append({"name": "missing referenced person", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.relics.relic_0000.holder = "not_a_person"
	corruptions.append({"name": "missing relic owner", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.rng.events.state = 42
	corruptions.append({"name": "non-string RNG state", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.pending[0].parent = "missing_parent"
	corruptions.append({"name": "missing causal parent", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.faith = -1
	corruptions.append({"name": "negative resource", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.next_event = 1
	corruptions.append({"name": "reused next event ID", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.last_causes.civ_0000 = "missing_event"
	corruptions.append({"name": "orphan last cause", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.fired["civ_0000:unknown"] = 9999
	corruptions.append({"name": "invalid cooldown history", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.stats.erase("executed")
	corruptions.append({"name": "missing statistics counter", "text": wrap_payload(changed)})
	changed = payload.duplicate(true)
	changed.state.civilizations.civ_0001.members.append("npc_0000_0001")
	corruptions.append({"name": "duplicate cross-civilization membership", "text": wrap_payload(changed)})
	corruptions.append({"name": "checksum", "text": JSON.stringify({"payload": envelope.payload, "checksum": "wrong"})})
	var rejected: int = 0
	var details: Array = []
	for corruption: Dictionary in corruptions:
		var before: String = restored.save_text()
		var success: bool = restored.load_text(corruption.text)
		if not success and restored.save_text() == before:
			rejected += 1
		details.append({"case": corruption.name, "reason": restored.last_error})
	check("Corrupt/incompatible saves rejected without mutating session", rejected == corruptions.size(), {"cases": corruptions.size(), "rejected": rejected, "cases_detail": details})
	var output_dir: String = ProjectSettings.globalize_path("res://outputs")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file: FileAccess = FileAccess.open(output_dir.path_join("roundtrip.save.json"), FileAccess.WRITE)
	file.store_string(snapshot)
	file.close()
	file = FileAccess.open(output_dir.path_join("roundtrip.save.json"), FileAccess.READ)
	var disk_restored: RefCounted = Simulation.new(content)
	check("FileAccess disk roundtrip", disk_restored.load_text(file.get_as_text()) and disk_restored.save_text() == snapshot)

func wrap_payload(payload: Dictionary) -> String:
	var text: String = JSON.stringify(payload, "", true, true)
	return JSON.stringify({"payload": text, "checksum": text.sha256_text()})

func test_performance(civilizations: int, npcs_per_civilization: int, turns: int, seed_value: int) -> void:
	var start: int = Time.get_ticks_usec()
	var simulation: RefCounted = fixture(seed_value, civilizations, npcs_per_civilization)
	var generation_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var durations: Array[float] = []
	var invariant_failures: Array[String] = []
	var full_checks: int = 0
	var max_pending: int = 0
	var alive_min: int = simulation.state.npcs.size()
	for turn: int in turns:
		var commands: Array = commands_for(simulation, turn)
		var tick: int = Time.get_ticks_usec()
		simulation.advance(commands)
		durations.append((Time.get_ticks_usec() - tick) / 1000.0)
		max_pending = maxi(max_pending, simulation.state.pending.size())
		if int(simulation.state.faith) < 0:
			invariant_failures.append("negative faith")
		for civ: Dictionary in simulation.state.civilizations.values():
			for metric: String in ["barrier", "pollution", "alert", "stability"]:
				if int(civ[metric]) < 0 or int(civ[metric]) > 100:
					invariant_failures.append("out-of-range metric")
		if turn % 50 == 0 or turn == turns - 1:
			invariant_failures.append_array(simulation.validate_state(simulation.state))
			full_checks += 1
			var alive: int = 0
			for npc: Dictionary in simulation.state.npcs.values():
				if npc.alive:
					alive += 1
			alive_min = mini(alive_min, alive)
	var save_start: int = Time.get_ticks_usec()
	var saved: String = simulation.save_text()
	var save_ms: float = (Time.get_ticks_usec() - save_start) / 1000.0
	durations.sort()
	var detail: Dictionary = {
		"seed": seed_value, "civilizations": civilizations, "npcs": civilizations * npcs_per_civilization, "turns": turns,
		"generation_ms": generation_ms, "turn_p50_ms": durations[int(turns * 0.50)], "turn_p95_ms": durations[int(turns * 0.95)], "turn_max_ms": durations[-1],
		"serialize_ms": save_ms, "save_bytes": saved.to_utf8_buffer().size(), "history_records": simulation.state.history.size(), "compacted_records": simulation.stats.compact_records,
		"events_executed": simulation.stats.executed, "event_candidate_checks": simulation.stats.candidate_checks, "npc_updates": simulation.stats.npc_updates,
		"max_pending": max_pending, "minimum_alive_at_checkpoints": alive_min, "full_invariant_checks": full_checks,
		"per_turn_range_checks": turns, "elapsed_ms_including_checks": (Time.get_ticks_usec() - start) / 1000.0, "invariant_errors": invariant_failures,
	}
	check("Evolution load %d civilizations / %d NPCs / %d turns" % [civilizations, civilizations * npcs_per_civilization, turns], invariant_failures.is_empty() and simulation.stats.npc_updates == civilizations * npcs_per_civilization * turns and max_pending <= civilizations * 4 and alive_min == civilizations * npcs_per_civilization and simulation.stats.candidate_checks == civilizations * turns * content.events.size(), detail)
	var reloaded: RefCounted = Simulation.new(content)
	var loaded: bool = reloaded.load_text(saved)
	check("Load compacted long-history state %d civilizations" % civilizations, loaded and reloaded.save_text() == saved, {"error": reloaded.last_error, "compacted_records": simulation.stats.compact_records})

func finish(started: int) -> void:
	var report: Dictionary = {
		"status": "PASS" if failed == 0 else "FAIL", "failed_checks": failed, "total_checks": results.size(),
		"engine": Engine.get_version_info().string, "os": OS.get_name(), "processor": OS.get_processor_name(), "processor_count": OS.get_processor_count(),
		"content_hash": content.version if content != null else "", "duration_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"scope": "Technical fixture only. Not a playable loop, full game implementation, balance proof, generative prose quality proof, or exported-build benchmark.",
		"checks": results,
	}
	var path: String = repo.path_join("docs/qa/technical-feasibility-results.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write report: " + path)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	print("REPORT " + path)
	quit(0 if failed == 0 else 1)
