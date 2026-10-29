extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const Policy = preload("res://tools/balance/policy.gd")
var output: String
var trace_path: String
var seed_value: int = 19
var strategy: String = "expansion"
var turn_limit: int = 60
var rows: Array = []
var checks: Array = []
var command_number: int = 0
var first_cult: int = -1
var duplicate_done: bool = false
var diagnostic: Dictionary = {}

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2: push_error("output directory and seed required"); quit(2); return
	output = args[0]; seed_value = int(args[1])
	if args.size() > 2: strategy = args[2]
	if args.size() > 3: turn_limit = int(args[3])
	DirAccess.make_dir_recursive_absolute(output)
	trace_path = output.path_join("trace.jsonl")
	var file: FileAccess = FileAccess.open(trace_path, FileAccess.WRITE); file.close()
	call_deferred("run")

func emit(row: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(trace_path, FileAccess.READ_WRITE)
	file.seek_end(); file.store_line(JSON.stringify(row)); file.flush(); file.close()

func check(id: String, condition: bool, evidence: Dictionary = {}) -> void:
	checks.append({"id": id, "status": "pass" if condition else "fail", "evidence": evidence})

func observe(s: RefCounted) -> Dictionary:
	# Diagnostics are written only; never passed to Policy.
	var domains: Array = []
	for id: String in s.world.state.domains:
		var domain: Dictionary = s.world.state.domains[id]
		domains.append({"id": id, "followers": domain.unnamed_followers, "nonfollowers": domain.unnamed_nonfollowers, "alert": domain.alert, "barrier": domain.barrier, "pollution": domain.pollution, "stability": domain.stability, "spend": s.world.state.cult_system.spend.get(id, {})})
	return {"turn": s.turn.context.turn, "phase": s.turn.context.phase, "faith": s.world.state.faith, "whispers": s.world.state.whispers, "awakening": s.world.state.awakening, "insight": s.world.state.insight, "wounds": s.world.state.wounds, "disconnected": s.world.state.ending_system.disconnected, "members": s.world.state.attention.members.keys(), "living": s.world.history.ids("living").size(), "facts": int(s.world.state.next_fact) - 1, "focused": s.world.state.simulation.focused.duplicate(), "temporary": s.world.state.attention.get("temporary", {}).size(), "reservations": s.world.state.attention.reservations.size(), "cults": s.world.state.cults.duplicate(true), "anchors": s.world.state.anchors.duplicate(true), "domains": domains, "outcome": s.turn.context.outcome, "static_memory_bytes": OS.get_static_memory_usage()}

func act(s: RefCounted, candidate: Dictionary) -> Dictionary:
	command_number += 1
	var identity: String = "balance/%d/%s/%d" % [seed_value, strategy, command_number]
	var before: String = s.turn.snapshot()
	var started: int = Time.get_ticks_usec()
	var preview: Dictionary = s.preview_action(candidate.key, candidate.selection)
	var pure: bool = before == s.turn.snapshot()
	var result: Dictionary = {"ok": false, "error": preview.get("error", "Preview rejected")}
	if preview.ok: result = s.execute_action(candidate.key, candidate.selection, true, identity)
	var duration: float = (Time.get_ticks_usec() - started) / 1000.0
	var atomic: bool = result.ok or s.turn.snapshot() == before
	emit({"type": "action", "turn": s.turn.context.turn, "phase": s.turn.context.phase, "key": candidate.key, "selection": candidate.selection, "durable_id": identity, "preview": preview, "preview_pure": pure, "result": result, "rejected_atomic": atomic, "elapsed_ms": duration})
	if not pure or not atomic: check("BAL-INVARIANT-" + str(command_number), false)
	if result.ok and not duplicate_done:
		var committed: String = s.turn.snapshot()
		var duplicate: Dictionary = s.execute_action(candidate.key, candidate.selection, true, identity)
		check("BAL-DUPLICATE-001", duplicate.ok and s.turn.snapshot() == committed, {"key": candidate.key, "retry": duplicate})
		duplicate_done = true
	return result

func progress(s: RefCounted) -> Dictionary:
	var phase: String = s.turn.context.phase
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = s.progress(true)
	emit({"type": "progress", "turn": s.turn.context.turn, "from": phase, "to": s.turn.context.phase, "result": result, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0})
	return result

func run() -> void:
	var s: RefCounted = Session.new(output.path_join("saves"))
	var started: int = Time.get_ticks_usec()
	var opened: Dictionary = s.start_new(seed_value)
	emit({"type": "start", "seed": seed_value, "strategy": strategy, "limit": turn_limit, "result": opened, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0})
	check("BAL-SESSION-001", opened.ok)
	if not opened.ok: finish(s, "error"); return
	var opened_snapshot: String = s.turn.snapshot()
	var original_open: Dictionary = Store.entry(s.turn.context.receipts, "session/open/1").request
	var retried_open: Dictionary = s.turn.submit(original_open)
	check("BAL-DUPLICATE-000", retried_open.ok and opened_snapshot == s.turn.snapshot(), {"first_boundary_retry": retried_open})
	var policy: RefCounted = Policy.new(strategy)
	var rejected_checked: bool = false
	for iteration: int in turn_limit:
		if s.turn.context.phase == "ended": break
		var round_started: int = Time.get_ticks_usec()
		var prior_turn: int = s.turn.context.turn
		var before_metrics: Dictionary = observe(s)
		var bounded: int = 0
		while s.turn.context.phase != "actions" and s.turn.context.phase != "ended":
			bounded += 1
			if bounded > 6: finish(s, "phase_bound"); return
			if s.turn.context.phase == "events":
				var events: Array = policy.event_candidates(s.project(), s.action_catalog())
				for candidate: Dictionary in events:
					if act(s, candidate).ok: break
			if not progress(s).ok: finish(s, "progress_error"); return
		if s.turn.context.phase == "ended": break
		if not rejected_checked:
			var before: String = s.turn.snapshot()
			var invalid: Dictionary = s.execute_action("POWER_DREAM", {"domain": "DOMAIN-UNKNOWN", "npc": "NPC-UNKNOWN", "source": "FACT-UNKNOWN"}, true)
			var unchanged: bool = before == s.turn.snapshot()
			check("BAL-ATOMIC-001", not invalid.ok and unchanged, {"result": invalid})
			var invalid_plan: Dictionary = s.set_plan({"strategies": {"CULT-UNKNOWN": "expand"}})
			check("BAL-ATOMIC-002", not invalid_plan.ok and before == s.turn.snapshot(), {"result": invalid_plan})
			rejected_checked = true
		var player_view: Dictionary = s.project()
		emit({"type": "decision_view", "turn": s.turn.context.turn, "public": player_view})
		var known_facts: Array = []
		for source: String in s.current_sources():
			if s.is_known_source(source): known_facts.append(Store.entry(s.world.state.facts, source).duplicate(true))
		for candidate: Dictionary in policy.prayer_candidates(player_view):
			var prepared: Dictionary = policy.preparation_candidate(s.project(), known_facts, candidate)
			if not prepared.is_empty(): act(s, prepared)
			if act(s, candidate).ok: break
		known_facts.clear()
		for source: String in s.current_sources():
			if s.is_known_source(source): known_facts.append(Store.entry(s.world.state.facts, source).duplicate(true))
		var power_attempts: int = 0
		for candidate: Dictionary in policy.power_candidates(s.project(), known_facts):
			power_attempts += 1
			if act(s, candidate).ok or power_attempts >= 4: break
		var view: Dictionary = s.project()
		if not view.cults.is_empty():
			var plan: Dictionary = policy.plan(view)
			var plan_started: int = Time.get_ticks_usec()
			var planned: Dictionary = s.set_plan(plan)
			emit({"type": "plan", "turn": s.turn.context.turn, "plan": plan, "result": planned, "elapsed_ms": (Time.get_ticks_usec() - plan_started) / 1000.0})
		for candidate: Dictionary in policy.attention_candidates(s.project()): act(s, candidate)
		if not progress(s).ok: finish(s, "end_actions_error"); return
		for stage: int in 3:
			if s.turn.context.phase in ["between", "ended"]: break
			if not progress(s).ok: finish(s, "settlement_error"); return
		var metrics: Dictionary = observe(s)
		if first_cult < 0 and not metrics.cults.is_empty(): first_cult = int(metrics.turn)
		var row: Dictionary = {"type": "round", "iteration": iteration + 1, "turn": prior_turn, "before": before_metrics, "after": metrics, "elapsed_ms": (Time.get_ticks_usec() - round_started) / 1000.0}
		rows.append(row); emit(row)
		print("BAL ", seed_value, " ", strategy, " t", metrics.turn, " faith=", metrics.faith, " members=", metrics.members.size(), " cults=", metrics.cults.size(), " phase=", metrics.phase, " ms=", row.elapsed_ms)
		if s.turn.context.phase == "ended": break
	finish(s, "ended" if s.turn.context.phase == "ended" else "censored")

func finish(s: RefCounted, status: String) -> void:
	var save_started: int = Time.get_ticks_usec()
	var saved: Dictionary = s.save_game() if s.turn != null else {"ok": false}
	var save_ms: float = (Time.get_ticks_usec() - save_started) / 1000.0
	var load_started: int = Time.get_ticks_usec()
	var restored: RefCounted = Session.new(s.save_directory)
	var loaded: Dictionary = restored.continue_game() if saved.ok else {"ok": false}
	var load_ms: float = (Time.get_ticks_usec() - load_started) / 1000.0
	var equivalent: bool = loaded.ok and restored.turn.snapshot() == s.turn.snapshot() and restored.known_sources() == s.known_sources()
	check("BAL-SAVE-001", saved.ok and equivalent, {"save": saved, "load": loaded, "save_ms": save_ms, "load_ms": load_ms, "bytes": FileAccess.get_file_as_bytes(s.slot).size() if saved.ok else 0})
	check("BAL-BOUNDED-001", status in ["ended", "censored"], {"status": status, "rounds": rows.size()})
	var result: Dictionary = {"seed": seed_value, "strategy": strategy, "limit": turn_limit, "status": status, "first_cult_turn": first_cult, "rounds": rows.size(), "checks": checks, "engine": Engine.get_version_info().string, "final": observe(s) if s.turn != null else {}, "save_ms": save_ms, "load_ms": load_ms, "save_equivalent": equivalent, "trace": trace_path}
	var file: FileAccess = FileAccess.open(output.path_join("result.json"), FileAccess.WRITE); file.store_string(JSON.stringify(result, "\t")); file.close()
	print("BAL FINAL ", JSON.stringify(result))
	quit(0 if checks.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)
