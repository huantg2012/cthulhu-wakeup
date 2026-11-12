extends SceneTree
## Follows the normal prayer → person activity flow with a focused generation fixture.
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const Capabilities = preload("res://src/game/prayer_capabilities.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Events = preload("res://src/game/event_rules.gd")

# Keep actual initial state, effects and transactions. Restrict the generator's
# candidate index to the tested authored intent before opening the first turn.
class CapabilitySession extends Session:
	func _build(seed_value: int, powers_revision: String = "", sustained_pollution := true) -> Dictionary:
		var built := super(seed_value, powers_revision, sustained_pollution)
		if not built.ok: return built
		var generator: RefCounted = built.modules.prayers.space.generator
		for profile: String in generator.combinations:
			generator.combinations[profile] = generator.combinations[profile].filter(func(plan: Dictionary) -> bool:
				return plan.intent == "understand_anomaly")
		return built

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, detail: String) -> bool:
	if condition: return true
	push_error("PRAYER_CAPABILITY: " + detail)
	quit(1)
	return false

func successful_check(session: RefCounted, preview: Dictionary) -> bool:
	if not preview.get("ok", false): return false
	var rng := RandomNumberGenerator.new()
	rng.state = session.world.randoms.checks.state
	return session.world.check_result(int(preview.preview.probability), rng.randi_range(1, 100)) in ["success", "deep"]

func candidate(session: RefCounted) -> Dictionary:
	for scene: Dictionary in session.world.state.prayer_system.space.scenes.values():
		if not scene.id in session.world.state.prayer_system.space.offered: continue
		for choice: String in scene.contracts:
			var capability: Dictionary = scene.contracts[choice].get("capability", {})
			if capability.is_empty(): continue
			var action: String = "prayer/" + scene.id + "/" + choice
			if successful_check(session, session.preview_action(action)):
				return {"action": action, "scene": scene.id, "person": capability.person}
	return {}

func advance_to_actions(session: RefCounted, next_turn: bool = false) -> bool:
	var minimum: int = int(session.turn.context.turn) + int(next_turn)
	for _step: int in range(8):
		if session.turn.context.phase == "actions" and int(session.turn.context.turn) >= minimum: return true
		var result: Dictionary = session.progress(true)
		if not result.get("ok", false):
			push_error(str(result))
			return false
	return false

func run() -> void:
	var chosen := {}
	var session: RefCounted
	var active_seed := 0
	var args := OS.get_cmdline_user_args()
	var seeds: Array = [int(args[0])] if not args.is_empty() else range(1, 13)
	var probe_path := "user://prayer-capability-probe/%d" % Time.get_ticks_usec()
	for seed_value: int in seeds:
		var trial := CapabilitySession.new(probe_path.path_join(str(seed_value)))
		var opening: Dictionary = trial.start_new(seed_value)
		if not require(opening.get("ok", false), str(opening)): return
		if not require(advance_to_actions(trial), "could not finish introductory events"): return
		chosen = candidate(trial)
		if chosen.is_empty(): continue
		active_seed = seed_value
		session = trial
		break
	if not require(not chosen.is_empty(), "no successful specialized alteration in the supplied seeds"): return
	var npc: String = chosen.person
	var person: Dictionary = Store.entry(session.world.state.npcs, npc)
	var domain: String = person.domain
	var office: String = person.institution
	var profile: String = session.world.state.domains[domain].profile
	var operation := "ROUTE_RECORD_PRACTICE" if profile == "CIV_01" else "ROUTE_CALENDAR_KEEPING"
	var source: String = session.world.state.domains[domain].origin
	var payload := {"domain": domain, "npc": npc, "source": source, "operation": operation}
	if not require(PrayerRules.can_hold_office(session.world.state, npc) and not session.preview_action("route/context", payload).get("ok", false), "native eligibility did not start without the specialization"): return
	var previously_held: bool = session.world.state.institutions[office].representative == npc
	print("CAPABILITY_FIXTURE seed=", active_seed, " profile=", profile, " prior_office=", previously_held)
	var receipt: Dictionary = session.execute_action(chosen.action, {}, true, "specialization")
	if not require(receipt.get("ok", false), "alteration refused: " + str(receipt)): return
	var granted: String = Capabilities.grant_source(session.world.state, npc, Capabilities.RECORD_PRACTICE)
	if not require(not granted.is_empty() and session.is_known_source(granted), "no actual known grant after response"): return
	if not require(not PrayerRules.can_hold_office(session.world.state, npc) and not Events.successor_legal(session.world.state, npc, office, session.catalog) and session.world.state.institutions[office].representative != npc, "altered person still holds or can acquire office"): return
	var known: Array = session.project().people.filter(func(row: Dictionary) -> bool: return row.id == npc and row.get("prayer_capabilities", []).size() == 2)
	if not require(not known.is_empty(), "original person view did not show both changes"): return
	if not require(advance_to_actions(session, true), "could not reach next activity window"): return
	var save: Dictionary = session.save_game()
	if not require(save.get("ok", false), "save failed"): return
	var restored := Session.new(probe_path.path_join("restore"))
	var reopened: Dictionary = restored.continue_game(save.path)
	if not require(reopened.get("ok", false), "save with altered ability failed to restore: " + str(reopened)): return
	if not require(Capabilities.grant_source(restored.world.state, npc, Capabilities.RECORD_PRACTICE) == granted and not PrayerRules.can_hold_office(restored.world.state, npc), "restore lost either side of the ability change"): return
	payload["source"] = granted
	var task: Dictionary = restored.preview_action("route/context", payload)
	if not require(task.get("ok", false), "new ability could not open normal activity: " + str(task)): return
	var first_fact: int = restored.world.state.next_fact
	var result: Dictionary = restored.execute_action("route/context", payload, true, "capability-activity")
	if not require(result.get("ok", false), "new activity could not execute: " + str(result)): return
	var actual: Dictionary = {}
	for number: int in range(first_fact, int(restored.world.state.next_fact)):
		var fact: Dictionary = Store.entry(restored.world.state.facts, "FACT-%08d" % number, {})
		if fact.get("kind") == "route_attempt":
			actual = fact
			break
	if not require(not actual.is_empty(), "normal activity produced no action receipt"): return
	if not require(actual.actor == npc and actual.changes.get("capability_source") == granted and granted in actual.causal_parents, "activity did not consume its original ability"): return
	print("PRAYER_CAPABILITY_OK seed=", active_seed, " prior_office=", previously_held, " operation=", operation, " outcome=", actual.changes.outcome)
	quit(0)
