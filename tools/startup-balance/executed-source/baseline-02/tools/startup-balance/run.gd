extends SceneTree
## One controlled source regression, then six fixed natural fresh sessions.
const Session = preload("res://src/presentation/session.gd")
const Actions = preload("res://src/presentation/action_catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
var error: String = ""
var folder: String
var counter: int = 0
var rows: Array = []

func need(ok: bool, why: String) -> bool:
	if not ok and error.is_empty(): error = why
	return ok

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(World.canonical(History.export_value(value))); file.close()

func state(s: RefCounted, domain: String = "") -> Dictionary:
	var d: Dictionary = s.world.state.domains.get(domain, {})
	return {"turn": s.turn.context.turn, "phase": s.turn.context.phase, "faith": s.world.state.faith, "whispers": s.world.state.whispers, "followers": d.get("unnamed_followers", 0), "disconnected": s.world.state.ending_system.disconnected, "terminal": s.world.state.ending_system.terminal}

func command(s: RefCounted, key: String, selection: Dictionary, log: Array, controlled: bool = false) -> bool:
	var before: Dictionary = state(s, str(selection.get("domain", "")))
	var preview: Dictionary = s.preview_action(key, selection)
	if not need(preview.get("ok", false), "Selected public command unavailable: " + key + " " + str(preview)): return false
	counter += 1
	var result: Dictionary = s.execute_action(key, selection, true, "STARTUP/" + str(counter))
	if not need(result.get("ok", false), "Original Session action rejected: " + str(result)): return false
	log.append({"key": key, "selection": selection.duplicate(true), "before": before, "after": state(s, str(selection.get("domain", ""))), "preview": preview, "checks": result.get("result", {}).get("checks", []), "controlled": controlled})
	return true

func selection_for(s: RefCounted, key: String, npc: String) -> Dictionary:
	var person: Dictionary = Store.entry(s.world.state.npcs, npc, {})
	if person.is_empty(): return {}
	var selection: Dictionary = {"domain": person.domain, "npc": npc}
	var fields: Array = Actions.new()._fields_for(s, key, selection)
	for field: Dictionary in fields:
		if field.key != "source": continue
		for option: Dictionary in field.options:
			var candidate: Dictionary = selection.duplicate(true); candidate.source = option.id
			if s.preview_action(key, candidate).get("ok", false): return candidate
	return {}

func first_operation(s: RefCounted, key: String, domain: String) -> Dictionary:
	for npc: String in s.current_people():
		if Store.entry(s.world.state.npcs, npc, {}).get("domain") != domain: continue
		var selected: Dictionary = selection_for(s, key, npc)
		if not selected.is_empty(): return selected
	return {}

func advance_to_actions(s: RefCounted, end_current: bool) -> bool:
	if end_current and s.turn.context.phase == "actions":
		if not need(s.progress(true).get("ok", false), "Original end_actions rejected"): return false
	for unused: int in 7:
		if s.turn.context.phase in ["actions", "ended"]: return true
		var result: Dictionary = s.progress()
		if not need(result.get("ok", false), "Original phase advance rejected: " + str(result)): return false
	return need(false, "Finite phase progression did not reach actions")

func offered(s: RefCounted, prayer: String, domain: String) -> String:
	for id: String in s.world.state.prayer_system.offered:
		var request: Dictionary = s.world.state.prayer_system.requests.get(id, {})
		if request.get("card", {}).get("content_id") == prayer and request.card.domain == domain:
			if s.preview_action("prayer/" + id + "/shallow", {}).get("ok", false): return id
	return ""

func bootstrap(s: RefCounted) -> Dictionary:
	for id: String in s.world.state.prayer_system.offered:
		var request: Dictionary = s.world.state.prayer_system.requests.get(id, {})
		if request.get("card", {}).get("content_id") == "PRAYER_08": return {"id": id, "npc": request.descriptor.subjects.petitioner, "domain": request.card.domain}
	return {}

func member(s: RefCounted, domain: String) -> bool:
	for id: String in s.current_people():
		var p: Dictionary = Store.entry(s.world.state.npcs, id)
		if p.domain == domain and p.get("bound_member", false) and p.status == "active": return true
	return false

func cult(s: RefCounted, domain: String) -> Dictionary:
	for c: Dictionary in s.world.state.cults.values():
		if c.domain == domain and c.status in ["active", "dormant"]: return c
	return {}

func controlled_deep(s: RefCounted) -> void:
	# Only the separately labelled source regression calls this; fresh natural
	# sessions below retain every original RNG stream and never call this helper.
	for seed_value: int in range(1, 10001):
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randi_range(1, 100) == 1: s.world.randoms.checks.seed = seed_value; return

func source_regression() -> bool:
	var s := Session.new(folder.path_join("functional"))
	if not need(s.start_new(1).get("ok", false) and advance_to_actions(s, false), "Functional formal startup failed"): return false
	var first: Dictionary = bootstrap(s)
	if not need(not first.is_empty(), "Functional bootstrap missing"): return false
	var log: Array = []; var dreams: int = 0
	for window: int in 6:
		if int(Store.entry(s.world.state.npcs, first.npc).loyalty) >= s.catalog.integer("loyalty_follower_threshold"): break
		var chosen: Dictionary = selection_for(s, "POWER_DREAM", first.npc)
		if not chosen.is_empty():
			controlled_deep(s)
			if not command(s, "POWER_DREAM", chosen, log, true): return false
			dreams += 1
		if not advance_to_actions(s, true): return false
	var person: Dictionary = Store.entry(s.world.state.npcs, first.npc)
	if not need(dreams > 0 and not person.bound_member and person.dedication_source.is_empty() and Knowledge.known(s.world.state, first.npc).known and person.loyalty >= s.catalog.integer("loyalty_follower_threshold"), "Actual dreams did not create an eligible unbound known person"): return false
	var selected: Dictionary = selection_for(s, "route/ROUTE_PRIVATE_DEVOTION", first.npc)
	if not need(not selected.is_empty(), "Public private-devotion selector omitted new applicant"): return false
	var known: Dictionary = Knowledge.known(s.world.state, first.npc)
	if not command(s, "route/ROUTE_PRIVATE_DEVOTION", selected, log, true): return false
	person = Store.entry(s.world.state.npcs, first.npc)
	var dedication: Dictionary = Store.entry(s.world.state.facts, person.dedication_source, {})
	var joined: Dictionary = Store.entry(s.world.state.facts, person.binding_source, {})
	if not need(person.bound_member and dedication.get("kind") == "member_dedication" and known.source in dedication.causal_parents and dedication.id in joined.causal_parents, "Private devotion lacks its actual new dedication/enrollment"): return false
	if not advance_to_actions(s, true): return false
	var gathering: Dictionary = selection_for(s, "route/ROUTE_COVERT_GATHERING", first.npc)
	if not need(not gathering.is_empty(), "Original organization unavailable after actual enrollment"): return false
	var before: Dictionary = state(s, first.domain)
	var first_fact: int = s.world.state.next_fact
	controlled_deep(s)
	if not command(s, "route/ROUTE_COVERT_GATHERING", gathering, log, true): return false
	var attempt: Dictionary = {}
	for number: int in range(first_fact, int(s.world.state.next_fact)):
		var fact: Dictionary = Store.entry(s.world.state.facts, "FACT-%08d" % number, {})
		if fact.get("kind") == "route_attempt": attempt = fact
	if not need(before.faith - s.world.state.faith == s.catalog.integer("gathering_faith") and s.world.state.domains[first.domain].unnamed_followers - before.followers == s.catalog.integer("gathering_followers") and attempt.get("changes", {}).get("outcome") in ["success", "deep"], "Original gathering lost payment, conversion or successful attempt"): return false
	rows.append({"id": "STARTUP-PRIVATE-SOURCE", "status": "pass", "controlledOutcomeNotNaturalSample": true, "dreams": dreams, "newDedication": dedication, "enrollment": joined, "publicOrganization": gathering, "organizationAttempt": attempt, "actions": log})
	return true

func trajectory(seed_value: int, prefer_rite: bool) -> bool:
	var s := Session.new(folder.path_join("natural-" + str(seed_value)))
	var started: int = Time.get_ticks_msec()
	if not need(s.start_new(seed_value).get("ok", false) and advance_to_actions(s, false), "Natural formal startup rejected"): return false
	var first: Dictionary = bootstrap(s)
	if not need(not first.is_empty() and s.world.state.faith == s.catalog.integer("initial_faith"), "Natural original initial budget/bootstrap mismatch"): return false
	var domain: String = first.domain
	var log: Array = []; var windows: Array = []; var formed: Dictionary = {}; var status: String = "horizon_censored"
	for number: int in 8:
		if s.turn.context.phase == "ended": status = "disconnected" if s.world.state.ending_system.disconnected >= s.catalog.integer("disconnection_limit") else "other_terminal"; break
		var entry: Dictionary = {"state": state(s, domain), "number": number + 1, "roleWaiting": false, "opportunityWaiting": false, "resourceBlocked": false}
		var before_count: int = log.size()
		if not member(s, domain):
			var request: String = offered(s, "PRAYER_08", domain)
			if not request.is_empty() and not command(s, "prayer/" + request + "/shallow", {}, log): return false
		if not member(s, domain):
			var private_choice: Dictionary = first_operation(s, "route/ROUTE_PRIVATE_DEVOTION", domain)
			if not private_choice.is_empty():
				if not command(s, "route/ROUTE_PRIVATE_DEVOTION", private_choice, log): return false
			else:
				var dream: Dictionary = first_operation(s, "POWER_DREAM", domain)
				if not dream.is_empty() and not command(s, "POWER_DREAM", dream, log): return false
		if int(s.world.state.domains[domain].unnamed_followers) < s.catalog.integer("cult_form_followers"):
			var rescue: String = offered(s, "PRAYER_01", domain)
			if not rescue.is_empty() and not command(s, "prayer/" + rescue + "/shallow", {}, log): return false
		var rite: Dictionary = first_operation(s, "route/ROUTE_CALENDAR_RITE", domain)
		var gathering: Dictionary = first_operation(s, "route/ROUTE_COVERT_GATHERING", domain)
		var key: String = "route/ROUTE_CALENDAR_RITE" if prefer_rite and not rite.is_empty() else "route/ROUTE_COVERT_GATHERING"
		var selected: Dictionary = rite if key.ends_with("CALENDAR_RITE") else gathering
		if selected.is_empty() and not rite.is_empty(): key = "route/ROUTE_CALENDAR_RITE"; selected = rite
		entry.roleWaiting = prefer_rite and rite.is_empty()
		if not selected.is_empty():
			if not command(s, key, selected, log): return false
		else:
			entry.resourceBlocked = s.world.state.faith < s.catalog.integer("gathering_faith")
			entry.opportunityWaiting = not entry.resourceBlocked
		entry.actions = log.size() - before_count
		windows.append(entry)
		if not advance_to_actions(s, true): return false
		formed = cult(s, domain)
		if not formed.is_empty(): status = "formed"; break
		if entry.resourceBlocked and entry.actions == 0: status = "resource_censored"; break
	rows.append({"id": "STARTUP-NATURAL/" + str(seed_value), "status": "pass", "sampleStatus": status, "seed": seed_value, "preferredRoute": "calendar_rite" if prefer_rite else "covert_gathering", "horizonActionWindows": 8, "controlledRolls": false, "domain": domain, "windows": windows, "actions": log, "cult": formed, "final": state(s, domain), "opportunities": s.world.state.opportunities, "incomePreview": s.economy_preview() if s.turn.context.phase == "actions" else {}, "seconds": float(Time.get_ticks_msec() - started) / 1000.0})
	return true

func _initialize() -> void:
	var output: String = OS.get_cmdline_user_args()[0]; folder = output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var started: int = Time.get_ticks_msec(); var valid: bool = source_regression()
	if valid:
		for seed_value: int in range(1, 7):
			if not trajectory(seed_value, seed_value >= 5): valid = false; break
	write_json(output, {"status": "pass" if valid else "fail", "error": error, "seconds": float(Time.get_ticks_msec() - started) / 1000.0, "checks": rows, "scope": "One labelled controlled private-devotion source regression plus six fixed fresh natural Session trajectories; no population/faith/qualification injection and no natural RNG mutation. Censored samples are data, not gate failures."})
	quit(0 if valid else 1)
