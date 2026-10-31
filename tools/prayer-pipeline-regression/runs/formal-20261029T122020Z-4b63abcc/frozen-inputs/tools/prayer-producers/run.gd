extends "res://tools/prayer-dispatch/run.gd"
## Independent production checks. Target calls, situations and fixed cards must
## come from the registered producer and actual Turn/World entry points.
const Producers = preload("res://src/game/prayer_producers.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
var ritual_save: Dictionary = {}
var passage_save: Dictionary = {}

class WindowDeadlineFixture extends RefCounted:
	var deadlines: Array = []
	func handle(_view: Dictionary, input: Dictionary) -> Dictionary:
		var effects: Array = input.payload.effects.duplicate(true) if input.get("operation") == "due" else (deadlines.duplicate(true) if input.slot == "deadlines" else [])
		return {"ok": true, "empty": effects.is_empty(), "effects": effects, "state": {}}

class ProducerRejectWorld extends "res://src/simulation/world.gd":
	var reject_calls: bool = false
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_calls:
			for number: int in range(int(trusted.next_fact), int(candidate.next_fact)):
				var fact: Dictionary = Store.entry(candidate.facts, "FACT-%08d" % number, {})
				if fact.get("kind") == "prayer_call":
					issues.append("Injected new call publication failure")
					break
		return issues

func _producer_native(seed_value: int = 7919) -> Dictionary:
	var world: RefCounted = ProducerRejectWorld.new(catalog)
	assert(world.generate_hybrid(seed_value))
	return {"world": world, "source": world.state.domains["DOMAIN-001"].origin}

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PP-CATALOG", "Current formal CSV Catalog loads", loaded, {"errors": catalog.errors})
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	if loaded: run_producer_cases()
	_write_producer_report()

func _write_producer_report() -> void:
	var passed: bool = true
	for row: Dictionary in records: passed = passed and row.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "executionScope": "bounded_prayer_producers_modules", "limitations": ["Only the four existing root families and their call/fix pipeline are in this acceptance scope.", "Explicit source/identity/capacity prerequisites are identified separately from outputs; target calls and situations are not fixture substitutes for production.", "Five new root families, minimal player information projection, full Session restore, natural new-game reachability and balance remain downstream."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _boot(data: Dictionary) -> Dictionary:
	return data.turn.bootstrap_prayers()

func _producer_world(seed_value: int = 7919, bootstrap: bool = true) -> Dictionary:
	var data: Dictionary = _attach_dispatch(_producer_native(seed_value))
	if bootstrap:
		var result: Dictionary = _boot(data)
		assert(result.get("ok", false))
	return data

func _attach_dispatch(data: Dictionary) -> Dictionary:
	# The isolated window consumer starts with cult state produced by the real
	# initializer. Its fresh coordinator leaves lifecycle behavior out of scope
	# and gives the explicit deadline fixture sole ownership of start.
	var window_fixture: bool = data.get("window_fixture", false)
	if window_fixture:
		var initial_clock: RefCounted = Turn.new(data.world)
		var initializer: RefCounted = Cults.new(catalog)
		assert(initial_clock._attached and initializer.install(initial_clock))
		initial_clock = null
		assert(data.world._driver_allowed(null) and data.world.ensure_history(true))
	var accepted: Dictionary = ISSUERS.duplicate(true)
	accepted.merge(Events.issuer_capability(catalog))
	if data.world.state.has("economy"): data.world.state.economy.issuers = accepted.duplicate(true)
	data.economy = Economy.new(catalog, accepted)
	var turn: RefCounted = Turn.new(data.world)
	assert(turn._attached and data.economy.install(turn))
	data.fixture = WindowDeadlineFixture.new() if window_fixture else Fixture.new()
	var fixture_slots: Array = ["deadlines", "ending"]
	if window_fixture: fixture_slots.append("start")
	assert(turn.register_participant("cult-fixture", "1", fixture_slots, ["fact", "world_command", "resource", "schedule"], data.fixture.handle))
	data.cults = Cults.new(catalog)
	data.relics = Relics.new(catalog, accepted)
	data.powers = Powers.new(catalog, accepted)
	data.prayers = Prayers.new(catalog, accepted)
	if window_fixture:
		assert(turn.register_participant(Cults.ID, data.cults.version, ["actions", "cult_start", "cult_end"], ["cults", "schedule", "membership"], data.cults.handle))
	else: assert(data.cults.install(turn))
	assert(data.relics.install(turn) and data.powers.install(turn) and data.prayers.install(turn))
	data.events = Events.new(catalog)
	assert(data.events.install(turn))
	data.turn = turn
	return data

func run_producer_cases() -> void:
	_bootstrap_cases()
	_record_production()
	_wrapped_record_reopening()
	_second_witness_independent_record()
	for variant: String in ["missing", "empty"]: _producer_handler(variant)
	for variant: String in ["unknown", "explained", "message", "callback", "fake_anomaly"]: _record_rejection(variant)
	for content: String in ["PRAYER_05", "PRAYER_08", "PRAYER_09"]: _current_root_production(content)
	for variant: String in ["no_keeper", "no_route", "zero_barrier"]: _current_root_rejection(variant)
	_passage_changed()
	_existing_call_capacity()
	for variant: String in ["pool", "people", "members", "identity"]: _anonymous_capacity(variant)
	for variant: String in ["deadlines_equal", "start_equal", "start_parent", "already_due"]: _action_window(variant)
	_producer_save_cases()

func _foreign_record_fixture(data: Dictionary, second: bool = false) -> String:
	var world: RefCounted = data.world
	var domain: String = "DOMAIN-002"
	var institution: String = domain + "/interpretation"
	var people: Array = []
	for index: int in (2 if second else 1):
		var person: String = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local(domain, institution, "NPC_PROFILE_01", world.state.domains[domain].origin))
		people.append(person)
	var record: String = world._record("exposure", domain, people[0], [people[0]], [world.state.domains[domain].origin], {"unexplained": true, "public": false, "fixture": "capacity_consumer_only"})
	world._know(people[0], record)
	var subjects: Dictionary = {"petitioner": people[0]}
	if second: subjects.second = people[1]
	var source: String = world.introduce_fact("prayer_situation", domain, people[0], people, [record], {"issuer": "cult-fixture", "version": "1", "need": "knowledge", "domain": domain, "institution": institution, "actors": people, "subjects": subjects, "facts": {"record": record}, "crisis": {}}, people)
	assert(not source.is_empty())
	return source

func _domain_people(world: RefCounted, domain: String) -> int:
	var count: int = 0
	for person: Dictionary in Store.values(world.state.npcs):
		if person.domain == domain: count += 1
	return count

func _existing_call_capacity() -> void:
	var data: Dictionary = _producer_native()
	var person: String = _local_people(data.world)[0]
	var root: String = _record_input(data, person)
	var dream_qualification: String = _qualification(data, "dream", person, person, "DOMAIN-001", {"contact": root})
	var fillers: Array = []
	for index: int in 7: fillers.append(_foreign_record_fixture(data))
	_attach_dispatch(data)
	for source: String in fillers: assert(data.world.fix_prayer_source(source, data.turn))
	var boot: Dictionary = _boot(data)
	assert(boot.get("ok", false) and _open(data) and _submit(data, "end_actions").ok)
	var before: String = data.turn.snapshot()
	data.world.reject_calls = true
	var rejected: Dictionary = _submit(data, "advance")
	data.world.reject_calls = false
	var rolled_back: bool = not rejected.ok and before == data.turn.snapshot() and _content_calls(data.world, "PRAYER_04", person, root).is_empty()
	var retried: Dictionary = _submit(data, "advance")
	var calls: Array = _content_calls(data.world, "PRAYER_04", person, root)
	var tick: Dictionary = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last["DOMAIN-001"], {})
	var blocked: bool = retried.ok and calls.size() == 1 and _content_cards(data.world, "PRAYER_04", person, root).is_empty() and tick.changes.get("existing_outcome") == "capacity_blocked"
	_check("PP-CALL/REAL-FAULT-ROLLBACK", "A genuine publication failure removes the proposed call and sampling state; one clean retry can then commit the world's intent", rolled_back and blocked, {"rejected": rejected, "retry": retried, "callAfterRetry": calls, "tick": tick})
	if not blocked:
		_check("PP-CALL/CAPACITY-STABLE", "A committed capacity-blocked call must retain its original intent through later real recognition and a mode change", false)
		return
	var call_id: String = calls[0].id
	var original: String = World.canonical(calls[0])
	var valid: bool = calls[0].changes.addressing == "undirected" and _finish(data) and _open(data)
	var payload: Dictionary = {"npc": person, "source": root, "qualification": dream_qualification}
	valid = valid and _seed(data, "POWER_DREAM", "success", payload) > 0
	var response: Dictionary = _power(data, "POWER_DREAM", payload)
	var released: Dictionary = _submit(data, "attention", {"command": {"kind": "release_focus", "domain": "DOMAIN-001"}})
	valid = valid and response.ok and released.ok and Knowledge.known(data.world.state, person).get("known", false) and _evolve(data) and _finish(data) and _open(data)
	# The bootstrap is ID8 behind the explicit capacity fixtures and need not be
	# offered. Release capacity through the original windows' real stage-five
	# expiry, without bypassing either offers or the now-absent focus.
	var occupied: int = data.world.state.simulation.candidates.size()
	valid = valid and _evolve(data) and _finish(data)
	var freed: Dictionary = {"kind": "original_window_expiry", "before": occupied, "after": data.world.state.simulation.candidates.size(), "closed": _facts(data.world, "prayer_closed")}
	valid = valid and int(freed.after) < int(freed.before) and not freed.closed.is_empty() and _open(data) and _evolve(data)
	var fixed: Array = _content_cards(data.world, "PRAYER_04", person, root)
	valid = valid and not "DOMAIN-001" in data.world.state.simulation.focused and fixed.size() == 1 and fixed[0].call == call_id and fixed[0].addressing == "undirected" and _content_calls(data.world, "PRAYER_04", person, root).size() == 1 and World.canonical(Store.entry(data.world.state.facts, call_id)) == original
	_check("PP-CALL/CAPACITY-STABLE", "Normal capacity failure commits one complete call; later real recognition, focus release and free capacity reuse its original unknown intent", valid, {"originalCall": JSON.parse_string(original), "fixed": fixed, "dream": response, "capacityRelease": freed, "currentKnowledge": Knowledge.known(data.world.state, person), "scope": "Call stability/normal versus fault boundary; full four-cell player projection remains downstream"})

func _anonymous_capacity(variant: String) -> void:
	var trials: Array = []
	var found: Dictionary = {}
	for seed_value: int in range(1, 65):
		var data: Dictionary = _producer_native(seed_value)
		var world: RefCounted = data.world
		if int(world.state.simulation.cursors["DOMAIN-001"].next_turn) != 1: continue
		for person: String in _local_people(world): _bind(world, person)
		for person: Dictionary in Store.values(world.state.npcs):
			if person.domain == "DOMAIN-001" and "ritual_keeper" in person.get("role_tags", []): assert(world.submit({"kind": "status", "npc": person.id, "status": "detained", "parents": [data.source]}))
		world.state.domains["DOMAIN-001"].barrier = 0
		var fillers: Array = []
		if variant == "pool":
			for index: int in 7: fillers.append(_foreign_record_fixture(data))
		elif variant == "people":
			for index: int in 6: fillers.append(_foreign_record_fixture(data, index < 5))
		elif variant == "members":
			for index: int in 5:
				var person: String = "NPC-%08d" % int(world.state.next_npc)
				assert(world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-002"].origin))
				_bind(world, person)
		elif variant == "identity":
			while int(world.state.attention.living_count) < catalog.integer("living_named_global_limit") - 1:
				assert(world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", world.state.domains["DOMAIN-002"].origin))
		_attach_dispatch(data)
		for source: String in fillers: assert(world.fix_prayer_source(source, data.turn))
		var boot: Dictionary = _boot(data)
		if not boot.get("ok", false):
			found = {"valid": false, "bootstrap": boot, "seed": seed_value, "reason": "Prepared lawful initial free slot was rejected"}
			break
		assert(_open(data))
		var population: int = int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers)
		var people: int = _domain_people(world, "DOMAIN-001")
		var calls: int = _content_calls(world, "PRAYER_08").size()
		var cutoff: int = int(world.state.next_fact)
		var evolved: bool = _evolve(data)
		var tick: Dictionary = Store.entry(world.state.facts, world.state.prayer_dispatch.last["DOMAIN-001"], {})
		trials.append({"seed": seed_value, "choice": tick.get("changes", {}).get("choice", {}), "outcome": tick.get("changes", {}).get("new_outcome", "")})
		var choice: Dictionary = tick.get("changes", {}).get("choice", {})
		if choice.get("root") != "ROOT_CURRENT_APPEAL" or not str(choice.get("proposal", {}).get("petitioner", "")).is_empty(): continue
		var new_calls: Array = _new_facts(world, "prayer_call", cutoff).filter(func(fact: Dictionary) -> bool: return fact.domain == "DOMAIN-001" and fact.changes.need == "devotion")
		var nominees: Array = _new_facts(world, "nomination", cutoff).filter(func(fact: Dictionary) -> bool: return fact.domain == "DOMAIN-001")
		var valid: bool = evolved and tick.changes.get("new_outcome") == "capacity_blocked" and new_calls.is_empty() and nominees.is_empty() and _domain_people(world, "DOMAIN-001") == people and int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers) == population
		found = {"valid": valid, "seed": seed_value, "tick": tick, "newCalls": new_calls, "nominees": nominees, "beforeCallsAllDomains": calls, "populationUnchanged": population == int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers), "capacity": {"fixed": world.state.simulation.candidates.size(), "people": world.attention.occupied(world.state, "people").size(), "members": world.attention.occupied(world.state, "members").size(), "living": world.state.attention.living_count}}
		break
	_check("PP-ANONYMOUS-CAPACITY/" + variant, "A real anonymous contact attempt preflights the full quota before any nomination, population deduction, contact or individual call", not found.is_empty() and found.get("valid", false), {"found": found, "trials": trials, "scope": "Prepared lawful occupied quotas; no zero-budget configuration or target-call fixture"})

func _content_calls(world: RefCounted, content: String, person: String = "", root: String = "") -> Array:
	var result: Array = []
	for fact: Dictionary in _facts(world, "prayer_call"):
		if fact.changes.get("need") != catalog.tables.prayers[content].need: continue
		if not person.is_empty() and fact.changes.get("petitioner") != person: continue
		if not root.is_empty() and fact.changes.get("source") != root: continue
		result.append(fact)
	return result

func _content_cards(world: RefCounted, content: String, person: String = "", root: String = "") -> Array:
	var result: Array = []
	for fact: Dictionary in _facts(world, "prayer_fixed"):
		var card: Dictionary = fact.changes.get("candidate", {})
		if card.get("content_id") != content: continue
		if not person.is_empty() and card.get("subjects", {}).get("petitioner") != person: continue
		if not root.is_empty() and root not in card.get("facts", {}).values(): continue
		result.append(card)
	return result

func _complete_round(data: Dictionary) -> bool:
	return _evolve(data) and _finish(data) and _open(data)

func _record_input(data: Dictionary, person: String, variant: String = "valid") -> String:
	var world: RefCounted = data.world
	var kind: String = "exposure"
	var details: Dictionary = {"unexplained": variant != "explained", "public": false}
	if variant == "message": kind = "message"
	if variant in ["callback", "fake_anomaly"]:
		kind = "prayer_fact"
		details = {"tag": "future_callback" if variant == "callback" else "anomaly_record", "fixture": "not_a_successful_prayer_result"}
	var root: String = world._record(kind, "DOMAIN-001", person, [person], [data.source], details)
	if variant != "unknown": world._know(person, root)
	return root

func _record_production() -> void:
	var data: Dictionary = _producer_native()
	var person: String = _local_people(data.world)[1]
	var root: String = _record_input(data, person)
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data)
	var evidence: Array = []
	for attempt: int in 8:
		valid = valid and _evolve(data)
		var cards: Array = _content_cards(data.world, "PRAYER_04", person, root)
		evidence.append({"turn": data.world.state.turn, "cards": cards, "heads": data.world.state.get("prayer_producers", {}).get("heads", {})})
		if not cards.is_empty() or not valid: break
		valid = valid and _finish(data) and _open(data)
	var calls: Array = _content_calls(data.world, "PRAYER_04", person, root)
	var cards: Array = _content_cards(data.world, "PRAYER_04", person, root)
	valid = valid and calls.size() == 1 and cards.size() == 1 and calls[0].changes.addressing == "undirected" and calls[0].turn > Store.entry(data.world.state.facts, root).turn and cards[0].call == calls[0].id and cards[0].visible_turn == calls[0].turn + 1 and cards[0].get("record_knowledge") == root and not cards[0].get("legacy_source", false) and cards[0].get("source_mode") == "known_history"
	_check("PP-RECORD/PREEXISTING-SECOND-PERSON", "An actual preexisting record known by a later person reaches the formal call and fixed card without starving behind the first person's empty knowledge page", valid, {"person": person, "root": root, "calls": calls, "cards": cards, "evidence": evidence, "scope": "Existing record/knowledge prerequisite; target call, situation and card are runtime production"})
	data = _producer_native()
	person = _local_people(data.world)[0]
	var contact: String = _given_fact(data, "message", person, [person], {"fixture": "current_contact_for_actual_dream"})
	var qualification: String = _qualification(data, "dream", person, person, "DOMAIN-001", {"contact": contact})
	var payload: Dictionary = {"npc": person, "source": contact, "qualification": qualification}
	_attach_dispatch(data)
	boot = _boot(data)
	valid = boot.get("ok", false) and _open(data) and _seed(data, "POWER_DREAM", "success", payload) > 0
	var response: Dictionary = _power(data, "POWER_DREAM", payload)
	var records_found: Array = _facts(data.world, "miracle").filter(func(fact: Dictionary) -> bool: return fact.actor == person and fact.changes.get("power") == "POWER_DREAM")
	root = records_found[0].id if records_found.size() == 1 else ""
	valid = valid and response.ok and not root.is_empty() and Knowledge.known(data.world.state, person).get("known", false) and _evolve(data) and _content_calls(data.world, "PRAYER_04", person, root).is_empty()
	valid = valid and _finish(data) and _open(data) and _evolve(data)
	calls = _content_calls(data.world, "PRAYER_04", person, root)
	cards = _content_cards(data.world, "PRAYER_04", person, root)
	valid = valid and calls.size() == 1 and cards.size() == 1 and calls[0].turn == 2 and calls[0].changes.addressing == "directed" and not str(calls[0].changes.get("identity", "")).is_empty() and not str(calls[0].changes.get("knowledge", "")).is_empty() and cards[0].visible_turn == 3 and cards[0].call == calls[0].id and Producers.record_eligible(data.world.state, root, person)
	_check("PP-RECORD/ACTUAL-DREAM-CLOCK", "A real successful dream supplies a known record, waits past its publication turn and then produces exactly one source-bound request", valid, {"response": response, "actualDreamRecords": records_found, "calls": calls, "cards": cards, "knowledge": Knowledge.known(data.world.state, person)})

func _wrapped_record_reopening() -> void:
	var data: Dictionary = _producer_native()
	var world: RefCounted = data.world
	var person: String = _local_people(world)[1]
	var root: String = world._record("exception", "DOMAIN-001", person, [person], [data.source], {"unexplained": true})
	var wrappers: Array = []
	for index: int in 2:
		var proof: String = world._record("exposure", "DOMAIN-001", person, [person], [root], {"unexplained": true, "public": false, "wrapper": index})
		world._know(person, proof)
		wrappers.append(proof)
	_attach_dispatch(data)
	var valid: bool = _boot(data).get("ok", false) and _open(data)
	for attempt: int in 8:
		valid = valid and _evolve(data)
		if not _content_cards(world, "PRAYER_04", person, root).is_empty() or not valid: break
		valid = valid and _finish(data) and _open(data)
	var cards: Array = _content_cards(world, "PRAYER_04", person, root)
	var calls: Array = _content_calls(world, "PRAYER_04", person, root)
	var original: Dictionary = cards[0] if cards.size() == 1 else {}
	var situation: Dictionary = Store.entry(world.state.facts, original.get("source", ""), {})
	var proof: String = str(original.get("record_knowledge", ""))
	valid = valid and cards.size() == 1 and calls.size() == 1 and proof in wrappers and original.get("facts", {}).get("record") == root and proof in situation.get("causal_parents", []) and not Producers._knows(world.state, person, root)
	_check("PP-RECORD/WRAPPER-CANONICAL", "Two known exposure wrappers produce one canonical exception call without granting knowledge of their parent", valid, {"root": root, "wrappers": wrappers, "cards": cards, "calls": calls, "situation": situation, "knowsParent": Producers._knows(world.state, person, root)})
	var event_card: Dictionary = {}
	var event_preview: Dictionary = {}
	if valid: valid = _finish(data)
	for attempt: int in 12:
		if not valid: break
		if data.turn.context.phase == "actions": valid = _evolve(data) and _finish(data)
		if valid and data.turn.context.phase == "between": valid = _submit(data, "advance").ok
		if not valid: break
		for card: Dictionary in data.turn.context.events:
			if card.resolved or not world.state.event_system.cards.has(card.id): continue
			var descriptor: Dictionary = world.state.event_system.cards[card.id].descriptor
			if descriptor.content_id == "EVENT_12" and descriptor.get("prayer_descriptor", {}).get("source") == situation.get("id"):
				event_preview = data.events.preview(data.turn, card.id, "B")
				if event_preview.get("ok", false): event_card = card; break
		if not event_card.is_empty(): break
		valid = _submit(data, "finish_events").ok
	var resolution: Dictionary = _submit(data, "resolve_event", {"event": event_card.id, "action": "B"}) if valid and not event_card.is_empty() else {}
	var reopened: Dictionary = {}
	for card: Dictionary in _content_cards(world, "PRAYER_04", person, root):
		if card.get("source") != original.get("source"): reopened = card
	var reopened_source: Dictionary = Store.entry(world.state.facts, reopened.get("source", ""), {})
	valid = valid and resolution.get("ok", false) and not reopened.is_empty() and reopened.get("call") == original.get("call") and reopened.get("addressing") == original.get("addressing") and reopened.get("record_knowledge") == proof and proof in reopened_source.get("causal_parents", []) and _content_calls(world, "PRAYER_04", person, root).size() == 1 and not Producers._knows(world.state, person, root)
	if valid: valid = _submit(data, "finish_events").ok
	var saved: String = data.turn.snapshot()
	var restored: bool = data.turn.restore(saved) if valid else false
	valid = valid and restored and saved == data.turn.snapshot()
	var preview: Dictionary = data.prayers.preview(data.turn, reopened.id, "shallow") if valid else {}
	if valid and preview.get("ok", false): _choose_prayer_seed(data, "success", person, "DOMAIN-001")
	var response: Dictionary = _response(data, reopened.id, "shallow") if valid and preview.get("ok", false) else {}
	valid = valid and preview.get("ok", false) and response.get("ok", false)
	_check("PP-RECORD/WRAPPER-EVENT-REOPEN", "Actual EVENT12B reopens the produced wrapper request along its original call, proof and direction, survives current save and accepts a real shallow response", valid, {"event": event_card, "eventPreview": event_preview, "resolution": resolution, "reopened": reopened, "source": reopened_source, "restored": restored, "restoreError": data.turn.last_error, "preview": preview, "response": response, "scope": "Prepared exception/exposure prerequisites; actual production, expiry and event resolution; controlled response RNG, not natural campaign frequency"})

func _record_rejection(variant: String) -> void:
	var data: Dictionary = _producer_native()
	var person: String = _local_people(data.world)[1]
	var root: String = _record_input(data, person, variant)
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data)
	for attempt: int in 4:
		valid = valid and _evolve(data)
		if attempt < 3: valid = valid and _finish(data) and _open(data)
	var calls: Array = _content_calls(data.world, "PRAYER_04", person, root)
	var cards: Array = _content_cards(data.world, "PRAYER_04", person, root)
	_check("PP-RECORD-REJECT/" + variant, "Unknown, already explained or merely mislabeled records cannot generate a knowledge prayer", valid and calls.is_empty() and cards.is_empty(), {"source": Store.entry(data.world.state.facts, root), "person": person, "calls": calls, "cards": cards})

func _second_witness_independent_record() -> void:
	var data: Dictionary = _producer_native()
	var people: Array = _local_people(data.world)
	var first_root: String = _record_input(data, people[0])
	var second_root: String = _record_input(data, people[1])
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data)
	var observed: Array = []
	for attempt: int in 6:
		valid = valid and _evolve(data)
		var first: Array = _content_cards(data.world, "PRAYER_04", people[0], first_root)
		var second: Array = _content_cards(data.world, "PRAYER_04", people[1], second_root)
		observed.append({"turn": data.world.state.turn, "first": first, "second": second})
		if not first.is_empty() and not second.is_empty():
			valid = valid and first[0].subjects.get("second") == people[1] and first[0].call != second[0].call and first[0].facts.record != second[0].facts.record
			break
		if attempt == 5: valid = false
		else: valid = valid and _finish(data) and _open(data)
	_check("PP-RECORD/SECOND-WITNESS-INDEPENDENT", "Being the second witness in another current PR04 does not suppress the person's independently known record and own request", valid and _content_calls(data.world, "PRAYER_04", people[0], first_root).size() == 1 and _content_calls(data.world, "PRAYER_04", people[1], second_root).size() == 1, {"observed": observed, "scope": "Two lawful existing known records; both target pipelines are formal runtime production"})

func _action_window(variant: String) -> void:
	var data: Dictionary = _producer_native()
	data["window_fixture"] = true
	var people: Array = _local_people(data.world)
	var due: int = 2 if variant == "already_due" else 3
	var input: Dictionary = _rescue_prerequisite(data, people[0], people[1], due, true, true)
	var parent_job_source: String = _given_fact(data, "message", people[0], [people[1]], {"fixture": "actual_due_causal_child"}, [input.condition]) if variant == "start_parent" else ""
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data)
	var job: Dictionary = {}
	data.fixture.deadlines = [input.effect]
	if variant != "deadlines_equal":
		var job_source: String = input.condition
		if variant == "start_parent": job_source = parent_job_source
		var death: Dictionary = {"type": "world_command", "source": job_source, "command": {"kind": "status", "npc": people[1], "status": "dead", "parents": [job_source]}}
		job = {"id": "PP-WINDOW-" + variant, "due": due, "phase": "deadlines" if variant == "already_due" else "start", "source": job_source, "action": "existing_deadline", "payload": {"effects": [death]}}
		data.fixture.deadlines.append({"type": "schedule", "job": job})
	valid = valid and _evolve(data) and _finish(data)
	data.fixture.deadlines = []
	var sources: Array = _facts(data.world, "prayer_situation").filter(func(fact: Dictionary) -> bool: return fact.changes.get("facts", {}).get("condition") == input.condition)
	valid = valid and sources.size() == 1 and _open(data)
	input.source = sources[0].id if sources.size() == 1 else ""
	var original_due: int = int(Store.entry(data.world.state.facts, input.condition).changes.due)
	var resources: Dictionary = {"faith": data.world.state.faith, "whispers": data.world.state.whispers}
	var patient_holds: Array = data.world.state.simulation.holds.get(people[1], []).duplicate()
	var preview: Dictionary = data.world.preview_prayer_fix(input.source, data.turn)
	valid = valid and _evolve(data)
	var cards: Array = _content_cards(data.world, "PRAYER_01", people[0], input.condition)
	var tick: Dictionary = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last["DOMAIN-001"], {})
	var response: Dictionary = {}
	var observed: Dictionary = {"readyBeforeAssertions": valid, "faithBefore": resources.faith, "faithAfterEvolution": data.world.state.faith, "whispersBefore": resources.whispers, "whispersAfterEvolution": data.world.state.whispers, "patientHolds": data.world.state.simulation.holds.get(people[1], {})}
	if not valid or tick.is_empty() or (variant == "deadlines_equal" and cards.size() != 1):
		_check("PP-WINDOW/" + variant, "The declared window fixture reaches its actual dispatch point", false, {"bootstrap": boot, "phase": data.turn.context.phase, "error": data.turn.last_error, "cards": cards, "tick": tick, "sources": sources, "preview": preview, "observed": observed})
		return
	if variant == "deadlines_equal":
		valid = valid and preview.get("ok", false) and preview.get("due_turn") == due and cards.size() == 1 and cards[0].visible_turn == due and cards[0].due_turn == due and _finish(data) and _open(data)
		var saved: String = data.turn.snapshot()
		valid = valid and data.turn.restore(saved) and saved == data.turn.snapshot() and data.prayers.preview(data.turn, cards[0].id, "shallow").get("ok", false)
		_choose_prayer_seed(data, "success", people[0], "DOMAIN-001")
		response = _response(data, cards[0].id, "shallow")
		valid = valid and response.get("ok", false) and _evolve(data) and _finish(data) and Store.entry(data.world.state.npcs, people[1]).status == "active"
	else:
		observed["noWindow"] = not preview.get("ok", false) and preview.get("outcome") == "no_action_window"
		observed["notFixed"] = cards.is_empty()
		observed["formalOutcome"] = tick.changes.get("existing_outcome") == "no_action_window"
		observed["noPayment"] = data.world.state.faith == resources.faith and data.world.state.whispers == resources.whispers
		observed["noHold"] = data.world.state.simulation.holds.get(people[1], []) == patient_holds
		for reservation: Dictionary in data.world.state.attention.reservations.values():
			if reservation.get("source") == input.source: observed.noHold = false
		valid = valid and observed.noWindow and observed.notFixed and observed.formalOutcome and observed.noPayment and observed.noHold
		var settled: bool = _finish(data) if data.turn.context.phase == "settlement" else false
		observed["settled"] = settled
		valid = valid and settled
		if due == 3:
			var opened: bool = _open(data) if data.turn.context.phase == "between" else false
			observed["nextOpening"] = opened
			valid = valid and opened
		valid = valid and Store.entry(data.world.state.npcs, people[1]).status == "dead" and Store.has(data.turn.context.completed_jobs, job.id)
	valid = valid and Store.entry(data.world.state.facts, input.condition).changes.due == original_due
	_check("PP-WINDOW/" + variant, "Original due clamps the fixed card; phase-five equality retains an action while phase-one equality, its causal child and already-expired roots have none", valid, {"preview": preview, "card": cards, "tick": tick, "job": job, "response": response, "observed": observed, "originalDue": original_due, "patientStatus": Store.entry(data.world.state.npcs, people[1]).status, "scope": "Existing legitimate crisis/situation consumer fixture, not one of this task's four root producers; independent scheduled deadlines use actual Turn jobs"})

func _current_root_production(content: String) -> void:
	var evidence: Array = []
	var found: Dictionary = {}
	for seed_value: int in [7919, 19, 42, 2027, 1981, 104729]:
		var data: Dictionary = _producer_native(seed_value)
		if content == "PRAYER_09":
			# Authored-range initial wall at its cap: normal recovery is a no-op.
			# This is an explicit stable-origin prerequisite, not natural frequency.
			data.world.state.domains["DOMAIN-001"].barrier = 100
		if content == "PRAYER_05" and data.world._profile_legal(catalog.tables.npc_profiles.NPC_PROFILE_02, "DOMAIN-001", "DOMAIN-001/interpretation"):
			assert(data.world._nominate_local("DOMAIN-001", "DOMAIN-001/interpretation", "NPC_PROFILE_02", data.source))
		_attach_dispatch(data)
		var boot: Dictionary = _boot(data)
		var valid: bool = boot.get("ok", false) and _open(data)
		var cutoff: int = int(data.world.state.next_fact)
		for attempt: int in 16:
			valid = valid and _evolve(data)
			if content == "PRAYER_05" and ritual_save.is_empty():
				for head: Dictionary in data.world.state.prayer_producers.heads["DOMAIN-001"].values():
					if head.get("content_id") == "PRAYER_05": ritual_save = {"data": data, "saved": data.turn.snapshot(), "head": head.duplicate(true)}
			var cards: Array = _content_cards(data.world, content).filter(func(card: Dictionary) -> bool: return card.created_turn > 0 and card.domain == "DOMAIN-001")
			if not cards.is_empty():
				var card: Dictionary = cards[0]
				var call: Dictionary = Store.entry(data.world.state.facts, card.call, {})
				var source_field: String = "ritual" if content == "PRAYER_05" else "contact"
				var root: Dictionary = Store.entry(data.world.state.facts, card.facts[source_field], {})
				valid = valid and card.visible_turn == card.created_turn + 1 and card.due_turn == card.visible_turn + int(catalog.tables.prayers[content].lifetime) - 1 and call.get("kind") == "prayer_call" and call.changes.get("source") == root.id and not card.get("legacy_source", false) and card.get("source_mode") == "current_background"
				if content == "PRAYER_05": valid = valid and call.turn > root.turn and PrayerRules.ritual_keeper(data.world.state, Store.entry(data.world.state.npcs, root.actor))
				else: valid = valid and call.turn == root.turn
				if content == "PRAYER_08": valid = valid and call.changes.addressing == "undirected"
				if content == "PRAYER_09": valid = valid and root.changes.get("barrier_source") != "" and not data.world.state.institutions[root.changes.institution].links.is_empty()
				found = {"valid": valid, "seed": seed_value, "card": card, "call": call, "root": root, "newFactsAfterBootstrap": cutoff}
				if content == "PRAYER_09" and passage_save.is_empty(): passage_save = {"data": data, "saved": data.turn.snapshot(), "card": card.duplicate(true)}
				break
			if not valid: break
			valid = valid and _finish(data) and _open(data)
		evidence.append({"seed": seed_value, "lastTurn": data.world.state.turn, "evolved": valid})
		if not found.is_empty(): break
	_check("PP-ROOT/" + content, "The registered current origin produces its own real root/call/situation/fixed pipeline and original display window", not found.is_empty() and found.get("valid", false), {"found": found, "trials": evidence, "scope": "Finite formal production with lawful current people/institutions; PR09 explicitly starts with a capped stable wall. Not a natural new-game frequency or balance estimate"})

func _current_root_rejection(variant: String) -> void:
	var data: Dictionary = {}
	for seed_value: int in range(1, 17):
		var candidate: Dictionary = _producer_native(seed_value)
		if int(candidate.world.state.simulation.cursors["DOMAIN-001"].next_turn) == 1:
			data = candidate; break
	assert(not data.is_empty())
	var world: RefCounted = data.world
	if variant == "no_keeper":
		for person: Dictionary in Store.values(world.state.npcs):
			if "ritual_keeper" in person.get("role_tags", []): assert(world.submit({"kind": "status", "npc": person.id, "status": "detained", "parents": [data.source]}))
	elif variant == "no_route": world.state.institutions["DOMAIN-001/propagation"].links = []
	elif variant == "zero_barrier": world.state.domains["DOMAIN-001"].barrier = 0
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data)
	var cutoff: int = int(world.state.next_fact)
	valid = valid and _evolve(data)
	var tick: Dictionary = Store.entry(world.state.facts, world.state.prayer_dispatch.last["DOMAIN-001"], {})
	var forbidden: String = "ROOT_CURRENT_RITUAL" if variant == "no_keeper" else "ROOT_CURRENT_PASSAGE"
	var absent: bool = true
	for choice: Dictionary in tick.get("changes", {}).get("eligible", []): absent = absent and choice.get("root") != forbidden
	var kind: String = "ritual_context" if variant == "no_keeper" else "barrier_contact"
	var roots: Array = _new_facts(world, kind, cutoff).filter(func(fact: Dictionary) -> bool: return fact.domain == "DOMAIN-001")
	_check("PP-ROOT-REJECT/" + variant, "The actual due snapshot excludes a current origin whose real role, route or barrier prerequisite is absent", valid and tick.get("changes", {}).get("opportunity", false) and absent and roots.is_empty(), {"tick": tick, "newRoots": roots, "scope": "Frozen input eligibility and actual no-production; later natural barrier recovery is not retroactive input"})

func _bootstrap_cases() -> void:
	for seed_value: int in [19, 42, 7919, 2027, 1981, 104729]:
		var data: Dictionary = _producer_world(seed_value, false)
		var world: RefCounted = data.world
		var population: int = int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers)
		var people: int = Store.size(world.state.npcs)
		var before: String = data.turn.snapshot()
		var waiting: bool = not world.state.simulation.bootstrap and world.state.simulation.candidates.is_empty() and _facts(world, "prayer_call").is_empty()
		var denied: Dictionary = _submit(data, "advance")
		waiting = waiting and not denied.ok and before == data.turn.snapshot()
		var result: Dictionary = _boot(data)
		var cards: Array = world.state.simulation.candidates.values()
		var call: Dictionary = _facts(world, "prayer_call")[0] if _facts(world, "prayer_call").size() == 1 else {}
		var card: Dictionary = cards[0] if cards.size() == 1 else {}
		var person: String = str(result.get("person", ""))
		var valid: bool = waiting and result.get("ok", false) and card.get("content_id") == "PRAYER_08" and card.get("visible_turn") == 1 and card.get("due_turn") == int(catalog.tables.prayers.PRAYER_08.lifetime) and call.get("changes", {}).get("addressing") == "undirected" and call.changes.get("identity") == "" and call.changes.get("knowledge") == "" and call.changes.get("snapshot", {}).get("phase") == "bootstrap" and Store.size(world.state.npcs) == people + 1 and int(world.state.domains["DOMAIN-001"].unnamed_nonfollowers) == population - 1 and not Knowledge.known(world.state, person).get("known", false)
		var token: String = str(card.get("admission_token", ""))
		valid = valid and not token.is_empty() and world.state.attention.reservations.has(token)
		var saved: String = data.turn.snapshot()
		var retry: Dictionary = _boot(data)
		valid = valid and (not retry.get("ok", false) or retry.get("card") == result.get("card")) and data.turn.snapshot() == saved
		var opened: bool = _open(data)
		var id: String = str(card.get("id", ""))
		var preview: Dictionary = data.prayers.preview(data.turn, id, "shallow") if opened else {}
		valid = valid and opened and preview.get("ok", false)
		if opened and not person.is_empty(): _choose_prayer_seed(data, "success", person, "DOMAIN-001")
		var response: Dictionary = _response(data, id, "shallow") if opened and preview.get("ok", false) else {}
		valid = valid and response.get("ok", false) and Store.entry(world.state.npcs, person, {}).get("bound_member", false) and Knowledge.known(world.state, person).get("known", false)
		_check("PP-BOOTSTRAP/" + str(seed_value), "Explicit bootstrap atomically creates one unknown undirected PR08 with P/N, original window and a real affordable shallow membership response", valid, {"bootstrap": result, "deferredAdvance": denied, "card": card, "call": call, "preview": preview, "response": response, "memberKnowledge": Knowledge.known(world.state, person), "reservation": world.state.attention.reservations.get(token, {})})
	for variant: String in ["population", "institution", "whispers", "members", "publication_fault"]:
		var data: Dictionary = _producer_native()
		if variant == "population":
			var accepted: Dictionary = ISSUERS.duplicate(true)
			accepted.merge(Events.issuer_capability(catalog))
			var economy: RefCounted = Economy.new(catalog, accepted)
			assert(economy.initialize(data.world))
			assert(data.world.submit({"kind": "population", "domain": "DOMAIN-001", "mode": "convert", "amount": int(data.world.state.domains["DOMAIN-001"].unnamed_nonfollowers), "parents": [data.source]}))
		elif variant == "institution": data.world.state.institutions["DOMAIN-001/interpretation"].active = false
		elif variant == "whispers":
			# Valid alternate initial resource input, before Turn or any bootstrap.
			# Neither CSV nor any runtime quota/predicate is changed.
			data.world.state.whispers = 0
			assert(catalog.integer("prayer_shallow_whispers") > 0 and data.world.validate_state(data.world.state).is_empty())
		elif variant == "members":
			for person: String in _local_people(data.world): _bind(data.world, person)
			while data.world.attention.occupied(data.world.state, "members").size() < int(data.world.attention.parameters.bound_member_limit):
				var person: String = "NPC-%08d" % int(data.world.state.next_npc)
				assert(data.world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", data.world.state.domains["DOMAIN-002"].origin))
				_bind(data.world, person)
		_attach_dispatch(data)
		var before: String = data.turn.snapshot()
		if variant == "publication_fault": data.world.reject_calls = true
		var result: Dictionary = _boot(data)
		data.world.reject_calls = false
		var valid: bool = not result.get("ok", false) and before == data.turn.snapshot() and _facts(data.world, "prayer_call").is_empty() and data.world.state.simulation.candidates.is_empty() and not data.world.state.simulation.bootstrap
		var retried: Dictionary = {}
		if variant == "publication_fault":
			retried = _boot(data)
			valid = valid and retried.get("ok", false) and _facts(data.world, "prayer_call").size() == 1
		_check("PP-BOOTSTRAP-REJECT/" + variant, "Missing real anonymous population/institution or a true publication fault cannot leave a half initialized bootstrap", valid, {"result": result, "retry": retried, "rejectedStateUnchanged": before == data.turn.snapshot() if variant != "publication_fault" else not result.get("ok", false)})

func _producer_handler(variant: String) -> void:
	var data: Dictionary = _producer_native()
	var person: String = _local_people(data.world)[0]
	var root: String = _record_input(data, person)
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data) and _submit(data, "end_actions").ok
	var handlers: Dictionary = data.events.candidate_handlers.duplicate()
	var before: String = data.turn.snapshot()
	if variant == "missing": data.events.candidate_handlers.erase("ROOT_KNOWN_RECORD")
	else: data.events.candidate_handlers["ROOT_KNOWN_RECORD"] = Callable()
	var denied: Dictionary = _submit(data, "advance")
	data.events.candidate_handlers = handlers
	valid = valid and not denied.ok and before == data.turn.snapshot() and _content_calls(data.world, "PRAYER_04", person, root).is_empty()
	var retry: Dictionary = _submit(data, "advance")
	valid = valid and retry.ok and _content_calls(data.world, "PRAYER_04", person, root).size() == 1
	_check("PP-HANDLER/" + variant, "A missing actual registered record handler rolls the formal evolution back; restoring it enables one real source-bound call", valid, {"denied": denied, "retry": retry, "calls": _content_calls(data.world, "PRAYER_04", person, root)})

func _passage_changed() -> void:
	var trials: Array = []
	var found: Dictionary = {}
	for seed_value: int in range(1, 65):
		var data: Dictionary = _producer_native(seed_value)
		if int(data.world.state.simulation.cursors["DOMAIN-001"].next_turn) != 1: continue
		_attach_dispatch(data)
		var boot: Dictionary = _boot(data)
		var valid: bool = boot.get("ok", false) and _open(data)
		var cutoff: int = int(data.world.state.next_fact)
		valid = valid and _evolve(data)
		var tick: Dictionary = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last["DOMAIN-001"], {})
		var choice: Dictionary = tick.get("changes", {}).get("choice", {})
		if choice.get("root") != "ROOT_CURRENT_PASSAGE": continue
		var sampled: String = str(choice.proposal.get("barrier_source", ""))
		var actual: String = str(data.world.state.domains["DOMAIN-001"].barrier_source)
		trials.append({"seed": seed_value, "sampled": sampled, "actual": actual, "outcome": tick.changes.get("new_outcome")})
		if sampled == actual: continue
		var roots: Array = _new_facts(data.world, "barrier_contact", cutoff).filter(func(fact: Dictionary) -> bool: return fact.domain == "DOMAIN-001")
		var calls: Array = _new_facts(data.world, "prayer_call", cutoff).filter(func(fact: Dictionary) -> bool: return fact.domain == "DOMAIN-001" and fact.changes.need == "escape")
		found = {"valid": valid and not sampled.is_empty() and tick.changes.get("new_outcome") == "source_changed" and roots.is_empty() and calls.is_empty(), "tick": tick, "roots": roots, "calls": calls, "sampled": sampled, "current": actual}
		break
	_check("PP-PASSAGE/BATCH-BARRIER-CHANGED", "A real phase-four barrier change cannot backfeed a selected passage origin: the batch succeeds with source_changed and no fabricated contact/call", not found.is_empty() and found.get("valid", false), {"found": found, "trials": trials, "scope": "Actual frozen proposal versus actual World evolution; no target-candidate injection or special runtime switch"})

func _producer_save_cases() -> void:
	var data: Dictionary = _producer_native()
	# A real, distinct nomination exists for the wrong-person semantic control.
	assert(data.world._nominate_local("DOMAIN-002", "DOMAIN-002/interpretation", "NPC_PROFILE_01", data.world.state.domains["DOMAIN-002"].origin))
	var person: String = _local_people(data.world)[0]
	var roots: Array = []
	for index: int in int(data.world.history.page_limit) + 2: roots.append(_record_input(data, person, "explained"))
	_attach_dispatch(data)
	var boot: Dictionary = _boot(data)
	var valid: bool = boot.get("ok", false) and _open(data) and _evolve(data)
	var saved: String = data.turn.snapshot()
	var before: Dictionary = data.world.state.prayer_producers.duplicate(true)
	var restored: bool = data.turn.restore(saved)
	var envelope: Dictionary = JSON.parse_string(saved)
	var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
	var resigned: bool = data.turn.restore(_resign(envelope, world_envelope))
	var offset: int = int(before.scans.get(person, -1))
	var paged: bool = offset == int(data.world.history.page_limit)
	_check("PP-SAVE/ROUNDTRIP-RESIGN-CONTROL", "A real finite known-record page, bootstrap call and persistent admission restore unchanged, including an independently normalized checksum control", valid and paged and restored and resigned and data.turn.snapshot() == saved and data.world.state.prayer_producers == before, {"restored": restored, "normalizedResignControl": resigned, "error": data.turn.last_error, "ledger": before, "pageLimit": data.world.history.page_limit})
	for variant: String in ["schema", "version", "installed", "scan_joint", "scan_tick_joint", "dirty_joint", "snapshot_seq_joint", "snapshot_cutoff_joint", "bootstrap_direction", "admission_token", "nomination_missing", "nomination_other"]:
		envelope = JSON.parse_string(saved)
		world_envelope = JSON.parse_string(envelope.body.world)
		var state: Dictionary = world_envelope.body.state
		var ledger: Dictionary = state.prayer_producers
		var tick: Dictionary = state.facts[state.prayer_dispatch.last["DOMAIN-001"]].changes
		var scan_update: Dictionary = {}
		var dirty_update: Dictionary = {}
		var selected: Dictionary = {}
		var bootstrap_call: Dictionary = {}
		for fact: Dictionary in state.facts.values():
			if fact.kind == "prayer_producer_update" and fact.changes.collection == "scans" and fact.changes.key == person: scan_update = fact
			if fact.kind == "prayer_producer_update" and fact.changes.collection == "dirty" and fact.changes.key == person and fact.changes.after != null: dirty_update = fact
			if fact.kind == "prayer_contact_selected" and fact.changes.proposal.get("bootstrap", false): selected = fact
			if fact.kind == "prayer_call" and fact.turn == 0: bootstrap_call = fact
		var exercised: bool = resigned and paged and not scan_update.is_empty() and not selected.is_empty() and not bootstrap_call.is_empty()
		match variant:
			"schema": ledger.schema += 1
			"version": ledger.version += "/forged"
			"installed": ledger.installed = state.domains["DOMAIN-001"].origin
			"scan_joint", "scan_tick_joint":
				ledger.scans[person] = offset + 1
				scan_update.changes.after = offset + 1
				if variant == "scan_tick_joint": tick.origins.scan.after = offset + 1
			"dirty_joint":
				ledger.dirty[person] = roots[-2]
				dirty_update.changes.after = roots[-2]
			"snapshot_seq_joint":
				tick.snapshot.commit_seq += 1
				scan_update.changes.snapshot.commit_seq = tick.snapshot.commit_seq
			"snapshot_cutoff_joint":
				tick.snapshot.fact_cutoff += 1
				scan_update.changes.snapshot.fact_cutoff = tick.snapshot.fact_cutoff
			"bootstrap_direction": bootstrap_call.changes.addressing = "directed"
			"admission_token": state.simulation.candidates[boot.card].admission_token = "RESERVATION-FORGED"
			"nomination_missing", "nomination_other":
				var removed: String = ""
				var other: String = ""
				for source: String in selected.causal_parents:
					if state.facts[source].kind == "nomination": removed = source
				for fact: Dictionary in state.facts.values():
					if fact.kind == "nomination" and fact.actor != selected.actor: other = fact.id; break
				exercised = exercised and not removed.is_empty() and (variant == "nomination_missing" or not other.is_empty())
				selected.causal_parents.erase(removed)
				if variant == "nomination_other": selected.causal_parents.append(other); selected.causal_parents.sort()
		var current: String = data.turn.snapshot()
		var accepted: bool = data.turn.restore(_resign(envelope, world_envelope))
		_check("PP-SAVE-REJECT/" + variant, "Correct envelope signatures cannot authorize producer index/receipt joint corruption or a bootstrap contact without its real nomination and held admission", exercised and not accepted and current == data.turn.snapshot() and "checksum" not in data.turn.last_error.to_lower(), {"accepted": accepted, "error": data.turn.last_error, "currentUnchanged": current == data.turn.snapshot(), "mutationExercised": exercised, "legalRangeOffset": offset + 1, "actualKnownCount": roots.size()})
		if accepted: assert(data.turn.restore(saved))
	_ritual_head_corruption()
	_passage_proof_corruption()

func _ritual_head_corruption() -> void:
	var valid: bool = not ritual_save.is_empty()
	var details: Dictionary = {"productionHeadCaptured": valid}
	if valid:
		var data: Dictionary = ritual_save.data
		var saved: String = ritual_save.saved
		valid = data.turn.restore(saved)
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var control: bool = data.turn.restore(_resign(envelope, world_envelope))
		var state: Dictionary = world_envelope.body.state
		var head: Dictionary = ritual_save.head
		var key: String = head.subjects.petitioner + "/PRAYER_05"
		var changed: bool = false
		for fact: Dictionary in state.facts.values():
			if fact.kind == "prayer_producer_update" and fact.changes.collection == "heads" and fact.changes.key == "DOMAIN-001|" + key and fact.changes.after == head:
				fact.changes.after.facts.ritual = state.domains["DOMAIN-001"].origin
				changed = true
		state.prayer_producers.heads["DOMAIN-001"][key].facts.ritual = state.domains["DOMAIN-001"].origin
		var accepted: bool = data.turn.restore(_resign(envelope, world_envelope))
		valid = valid and control and changed and not accepted and data.turn.snapshot() == saved and "checksum" not in data.turn.last_error.to_lower()
		details.merge({"normalizedResignControl": control, "jointMutationExercised": changed, "accepted": accepted, "error": data.turn.last_error})
		if accepted: assert(data.turn.restore(saved))
	_check("PP-SAVE-REJECT/head_joint", "A real produced ritual raw head and its update cannot jointly substitute a source that never supplied that finite bundle", valid, details)

func _passage_proof_corruption() -> void:
	var valid: bool = not passage_save.is_empty()
	var details: Dictionary = {"productionPassageCaptured": valid}
	if valid:
		var data: Dictionary = passage_save.data
		var saved: String = passage_save.saved
		valid = data.turn.restore(saved)
		var envelope: Dictionary = JSON.parse_string(saved)
		var world_envelope: Dictionary = JSON.parse_string(envelope.body.world)
		var control: bool = data.turn.restore(_resign(envelope, world_envelope))
		var state: Dictionary = world_envelope.body.state
		var root: Dictionary = state.facts[passage_save.card.facts.contact]
		var selected: Dictionary = {}
		for source: String in root.causal_parents:
			if state.facts[source].kind == "prayer_contact_selected": selected = state.facts[source]
		var changed: bool = not selected.is_empty()
		var semantic_rejected: bool = false
		var old: String = str(selected.get("changes", {}).get("proposal", {}).get("barrier_source", ""))
		var fake: String = state.domains["DOMAIN-002"].barrier_source
		if changed:
			changed = fake != old and not old.is_empty()
			root.changes.barrier_source = fake
			selected.changes.proposal.barrier_source = fake
			var ids: Array = selected.changes.proposal.source_ids
			for index: int in ids.size():
				if ids[index] == old: ids[index] = fake
			if not fake in selected.causal_parents: selected.causal_parents.append(fake); selected.causal_parents.sort()
			for fact: Dictionary in state.facts.values():
				if fact.kind != "prayer_dispatch_tick": continue
				var choice: Dictionary = fact.changes.get("choice", {})
				if choice.get("proposal", {}).get("once_key") == selected.changes.proposal.once_key: choice.proposal = selected.changes.proposal.duplicate(true)
				for option: Dictionary in fact.changes.get("eligible", []):
					if option.get("proposal", {}).get("once_key") == selected.changes.proposal.once_key: option.proposal = selected.changes.proposal.duplicate(true)
			# Re-key the root occurrence as well: a copy mismatch or stale hash
			# must not be the sole reason this coordinated proof corruption fails.
			var call: Dictionary = state.facts[passage_save.card.call]
			var descriptor: Dictionary = Knowledge._basis_descriptor(state, call)
			var prior: String = call.changes.occurrence
			var binding: Dictionary = Knowledge._binding(state, descriptor, catalog)
			call.changes.occurrence = binding.occurrence
			for prefix: String in ["", "knowledge/call/"]:
				if state.applied_authorizations.has(prefix + prior):
					state.applied_authorizations[prefix + binding.occurrence] = state.applied_authorizations[prefix + prior]
					state.applied_authorizations.erase(prefix + prior)
			semantic_rejected = not Knowledge.validate_call(state, call.id, descriptor, catalog)
		var accepted: bool = data.turn.restore(_resign(envelope, world_envelope))
		valid = valid and control and changed and semantic_rejected and not accepted and data.turn.snapshot() == saved and "checksum" not in data.turn.last_error.to_lower()
		details.merge({"normalizedResignControl": control, "jointMutationExercised": changed, "originalWall": old, "forgedWall": fake, "callSemanticRejected": semantic_rejected, "accepted": accepted, "error": data.turn.last_error})
		if accepted: assert(data.turn.restore(saved))
	_check("PP-SAVE-REJECT/passage_proof_joint", "A produced passage root and selected proposal cannot jointly replace their original frozen barrier proof", valid, details)
