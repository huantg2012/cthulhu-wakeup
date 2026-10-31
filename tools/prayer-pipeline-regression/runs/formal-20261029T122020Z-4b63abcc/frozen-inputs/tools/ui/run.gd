extends SceneTree
const Session = preload("res://src/presentation/session.gd")
class InitialResources extends Session:
	var initial_faith: int = 12
	var initial_wounds: int = 3
	func _build(seed_value: int) -> Dictionary:
		var built: Dictionary = super._build(seed_value)
		if built.ok:
			# Explicit advanced initial condition, before the first real receipt.
			# This is not evidence that a fresh player earned wounds/resources.
			built.world.state.faith = initial_faith
			built.world.state.wounds = initial_wounds
			built.world._refresh_anchors()
		return built
var checks: Array = []
var directory: String = "res://.godot/ui-test-saves"

func check(id: String, condition: bool, evidence: Dictionary = {}) -> void:
	checks.append({"id": id, "status": "pass" if condition else "fail", "evidence": evidence})
	print(id, " ", condition)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s: RefCounted = Session.new(directory.path_join(str(Time.get_ticks_usec())))
	var opened: Dictionary = s.start_new(7919)
	check("UI-SESSION-001", opened.ok and s.turn.context.turn == 1 and s.modules.size() == 10 and opened.autosave.ok and s.slot.begins_with(directory), {"opened": opened, "modules": s.modules.keys()})
	if not opened.ok: finish(); return
	var before: String = s.turn.snapshot()
	var known: Array = s.known_sources()
	var projection: Dictionary = s.project()
	var pure: bool = true
	for i: int in 2:
		s.project(); s.history_page(); s.action_catalog(); s.economy_preview(); s.abandon(false)
		pure = pure and s.turn.snapshot() == before and s.known_sources() == known
	projection.domains.clear()
	check("UI-PURE-001", pure and not s.project().domains.is_empty(), {"snapshot_unchanged": pure})
	var unknown: String = ""
	for domain: String in s.world.state.domains:
		if not domain in s.known_domains(): unknown = domain; break
	check("UI-KNOWLEDGE-001", not unknown.is_empty() and not JSON.stringify(s.project()).contains(unknown) and s.project().domains.all(func(d: Dictionary) -> bool: return d.barrier == null and d.alert == null and d.pollution == null and d.stability == null), {"known_domain_count": s.known_domains().size()})
	var event_ran: bool = false
	for row: Dictionary in s.action_catalog():
		if row.key.begins_with("event/") and row.available:
			event_ran = exercise(s, row.key, "ui/event"); break
	check("UI-EVENT-001", event_ran or s.turn.context.events.is_empty(), {"executed": event_ran, "empty_event_boundary": s.turn.context.events.is_empty(), "seed": 7919})
	var progressed: Dictionary = s.progress()
	check("UI-TURN-001", progressed.ok and s.turn.context.phase == "actions", {"response": progressed})
	before = s.turn.snapshot()
	s.progress(false); s.rest(false); s.preview_action("POWER_DREAM"); s.preview_plan({})
	var rejected: Dictionary = s.execute_action("DOES_NOT_EXIST")
	check("UI-PURE-002", not rejected.ok and s.turn.snapshot() == before, {"rejected": rejected})
	var source_evidence: Dictionary = source_checks(s)
	var prayer_ran: bool = false
	for row: Dictionary in s.action_catalog():
		if row.key.begins_with("prayer/") and row.available:
			prayer_ran = exercise(s, row.key, "ui/prayer"); break
	check("UI-PRAYER-001", prayer_ran, {"executed": prayer_ran, "seed": 7919})
	var retired: Array = []
	var current: Array = s.current_sources()
	for source: String in source_evidence.proofs:
		if not source in current and s.is_known_source(source) and Session.Store.has(s.world.state.facts, source): retired.append(source)
	check("UI-SOURCE-001", source_evidence.valid and not retired.is_empty(), {"before_response": source_evidence, "retired_but_known_after_response": retired})
	var saved: Dictionary = s.save_game()
	var loaded: RefCounted = Session.new(s.save_directory)
	var continued: Dictionary = loaded.continue_game()
	check("UI-SAVE-001", saved.ok and continued.ok and s.turn.snapshot() == loaded.turn.snapshot() and s.known_sources() == loaded.known_sources() and s.known_people() == loaded.known_people() and s.known_domains() == loaded.known_domains(), {"loaded": continued})
	bad_load(s)
	var ended: Dictionary = s.abandon(true)
	before = s.turn.snapshot()
	var after: Dictionary = s.progress(true)
	s.project(); s.history_page()
	var terminal_load: RefCounted = Session.new(s.save_directory)
	var terminal: Dictionary = terminal_load.continue_game()
	check("UI-TERMINAL-001", ended.ok and not after.ok and s.turn.snapshot() == before and s.action_catalog().is_empty() and terminal.ok and terminal_load.project().terminal, {"terminal": terminal})
	resource_checks()
	finish()

func bad_load(s: RefCounted) -> void:
	var before: String = s.turn.snapshot()
	var knowledge: Array = s.known_sources()
	var original_slot: String = s.slot
	var path: String = s.save_directory.path_join("invalid.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"body":{"schema":1},"checksum":"forged"}'); file.close()
	var failed: Dictionary = s.continue_game(path)
	check("UI-SAVE-002", not failed.ok and before == s.turn.snapshot() and knowledge == s.known_sources() and s.slot == original_slot, {"response": failed})

func source_checks(s: RefCounted) -> Dictionary:
	var before: String = s.turn.snapshot()
	var sources: Array = s.current_sources()
	var valid: bool = not sources.is_empty()
	var proofs: Array = []
	for source: String in sources:
		valid = valid and s.is_known_source(source)
		var fact: Dictionary = Session.Store.entry(s.world.state.facts, source)
		if fact.kind == "power_qualification" and fact.changes.get("issuer") == "player_sources":
			proofs.append(source)
			valid = valid and s.is_known_source(str(fact.changes.get("origin", "")))
	return {"valid": valid and not proofs.is_empty() and before == s.turn.snapshot(), "proofs": proofs, "source_count": sources.size()}

func resource_checks() -> void:
	var rest_session: RefCounted = InitialResources.new(directory.path_join("rest-" + str(Time.get_ticks_usec())))
	var opened: Dictionary = rest_session.start_new(7919)
	if not opened.ok:
		check("UI-REST-001", false, {"opened": opened}); check("UI-ZERO-001", false); return
	var actions: Dictionary = rest_session.progress()
	var before: String = rest_session.turn.snapshot()
	var preview: Dictionary = rest_session.rest(false)
	var pure: bool = before == rest_session.turn.snapshot()
	var faith: int = rest_session.world.state.faith
	var wounds: int = rest_session.world.state.wounds
	var result: Dictionary = rest_session.rest(true)
	check("UI-REST-001", actions.ok and preview.get("confirmation", false) and pure and result.ok and rest_session.turn.context.phase == "evolution" and rest_session.world.state.faith == faith - rest_session.catalog.integer("rest_faith_cost") and rest_session.world.state.wounds == maxi(0, wounds - rest_session.catalog.integer("rest_wound_recovery")), {"preview": preview, "result": result, "fixture": "initial faith12 wounds3 before first receipt"})
	var zero: RefCounted = InitialResources.new(directory.path_join("zero-" + str(Time.get_ticks_usec())))
	zero.initial_faith = 0; zero.initial_wounds = 0
	opened = zero.start_new(7919)
	var valid: bool = opened.ok
	if valid:
		valid = zero.progress().ok and zero.world.state.faith == 0
		var refused: Dictionary = zero.rest(true)
		valid = valid and not refused.ok
		for i: int in 4:
			var moved: Dictionary = zero.progress(true)
			valid = valid and moved.ok
	check("UI-ZERO-001", valid and zero.turn.context.phase in ["between", "ended"], {"phase": zero.turn.context.phase, "fixture": "initial faith0 wounds0 before first receipt"})

func exercise(s: RefCounted, key: String, id: String) -> bool:
	var before: String = s.turn.snapshot()
	var preview: Dictionary = s.preview_action(key)
	var pure: bool = s.turn.snapshot() == before
	var result: Dictionary = s.execute_action(key, {}, true, id)
	var committed: String = s.turn.snapshot()
	var retry: Dictionary = s.execute_action(key, {}, true, id)
	var duplicate_safe: bool = committed == s.turn.snapshot()
	var wrong: Dictionary = s.execute_action(key, {"unknown": "changed"}, true, id)
	var saved: Dictionary = s.save_game()
	var restored: RefCounted = Session.new(s.save_directory)
	var loaded: Dictionary = restored.continue_game()
	var durable: Dictionary = restored.execute_action(key, {}, true, id) if loaded.ok else {"ok": false}
	return preview.ok and pure and result.ok and retry.ok and duplicate_safe and not wrong.ok and saved.ok and loaded.ok and durable.ok and restored.turn.snapshot() == committed

func finish() -> void:
	var passed: bool = checks.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "checks": checks, "engine": Engine.get_version_info().string}, "\t")); file.close()
	quit(0 if passed else 1)
