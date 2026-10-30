extends "res://tools/prayer-producers/run.gd"
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")
## Three bounded probes reuse the existing formal-module fixtures. Existing
## records/knowledge, two background nominees and the response RNG are controlled.
## Calls, situations, fixed cards, offers and response effects come from Turn.

func _initialize() -> void:
	catalog = Catalog.new()
	if not catalog.load_files():
		_check("CP-PRODUCTION", "Current content loads", false, {"reason": "catalog_failed", "errors": catalog.errors})
	else:
		_production_probe()
		_mode_probe()
		_empty_probe()
	var passed: bool = records.size() == 3 and records.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": records, "scope": "bounded_existing_record_production_and_response", "limitations": ["One existing unexplained-record route, not all prayer/root families or natural frequency.", "Prepared original record/knowledge and controlled success RNG; no target call, situation, card or result injection.", "The empty prerequisite case concerns this target record route; other families may remain eligible.", "Full Session/CULT compatibility and a natural complete new game remain outside scope."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if passed else 1)

func _record_probe_setup(known: bool = true) -> Dictionary:
	var data: Dictionary = _producer_native()
	data.person = _local_people(data.world)[0]
	data.root = _record_input(data, data.person, "valid" if known else "unknown")
	_attach_dispatch(data)
	data.boot_ok = _boot(data).get("ok", false)
	return data

func _production_probe() -> void:
	var data: Dictionary = _record_probe_setup()
	var binding_ok: bool = data.events.generation_binding_errors(data.world, data.turn).is_empty()
	var advanced: bool = data.boot_ok and _open(data) and _evolve(data)
	var calls: Array = _content_calls(data.world, "PRAYER_04", data.person, data.root)
	var cards: Array = _content_cards(data.world, "PRAYER_04", data.person, data.root)
	var opened_next: bool = advanced and _finish(data) and _open(data)
	var offered: bool = cards.size() == 1 and cards[0].id in data.world.state.prayer_system.offered
	var response: Dictionary = {}; var preview: Dictionary = {}; var result: Dictionary = {}; var produced: Dictionary = {}
	if opened_next and offered:
		preview = data.prayers.preview(data.turn, cards[0].id, "shallow")
		if preview.get("ok", false) and _choose_prayer_seed(data, "success", data.person, "DOMAIN-001") > 0:
			response = _response(data, cards[0].id, "shallow")
			for fact: Dictionary in _facts(data.world, "prayer_result"):
				if fact.changes.get("request") == cards[0].id: result = fact
			produced = Store.entry(data.world.state.facts, result.get("changes", {}).get("produced", {}).get("anomaly_record", ""), {})
	var valid: bool = binding_ok and advanced and opened_next and calls.size() == 1 and cards.size() == 1 and offered and preview.get("ok", false) and response.get("ok", false) and result.get("changes", {}).get("outcome") == "success" and produced.get("kind") == "prayer_fact" and produced.get("changes", {}).get("tag") == "anomaly_record" and data.turn.context.responses == 1
	_check("CP-PRODUCTION", "Formal record production reaches an offered card and a real shallow response effect", valid, {"bindingAccepted": binding_ok, "turnsAdvanced": advanced and opened_next, "reason": "missing_call_or_fixed_card" if calls.is_empty() or cards.is_empty() else ("" if valid else "offer_or_response_effect_failed"), "root": data.root, "callCount": calls.size(), "fixedCount": cards.size(), "offered": offered, "preview": preview, "response": response, "result": result, "produced": produced})

func _mode_probe() -> void:
	# Reuse the published adapter's lawful standalone nomination prerequisite;
	# DOMAIN-002 starts in background. No target call/situation/card is installed.
	var world: RefCounted = Support.new_world(catalog, 7919)
	var domain: String = "DOMAIN-002"
	var data: Dictionary = {"world": world, "source": world.state.domains[domain].origin}
	data.person = "NPC-%08d" % int(world.state.next_npc)
	for index: int in 2: assert(world._nominate_local(domain, domain + "/interpretation", "NPC_PROFILE_01", data.source))
	data.root = world._record("exposure", domain, data.person, [data.person], [data.source], {"unexplained": true, "public": false})
	world._know(data.person, data.root)
	_attach_dispatch(data)
	data.boot_ok = _boot(data).get("ok", false)
	var valid: bool = data.boot_ok and _open(data)
	var samples: Array = []
	for index: int in 3:
		var before: Dictionary = data.world.state.simulation.cursors[domain].duplicate(true)
		if index == 1:
			var focused: Dictionary = _submit(data, "attention", {"command": {"kind": "focus", "domain": domain}})
			var released: Dictionary = _submit(data, "attention", {"command": {"kind": "release_focus", "domain": domain}})
			valid = valid and focused.ok and released.ok and before == data.world.state.simulation.cursors[domain]
		var evolved: bool = _evolve(data)
		var tick: Dictionary = Store.entry(data.world.state.facts, data.world.state.prayer_dispatch.last[domain], {})
		var expected_mode: String = "detailed_candidates" if index == 1 else "abstract_candidates_due"
		valid = valid and evolved and tick.get("changes", {}).get("mode") == expected_mode
		if index == 0: valid = valid and _content_calls(data.world, "PRAYER_04", data.person, data.root).size() == 1 and _content_cards(data.world, "PRAYER_04", data.person, data.root).size() == 1
		samples.append({"turn": data.world.state.turn, "mode": tick.get("changes", {}).get("mode"), "before": before, "after": data.world.state.simulation.cursors[domain].duplicate(true), "callCount": _content_calls(data.world, "PRAYER_04", data.person, data.root).size(), "fixedCount": _content_cards(data.world, "PRAYER_04", data.person, data.root).size()})
		if index < 2: valid = _finish(data) and _open(data) and valid
	var calls: Array = _content_calls(data.world, "PRAYER_04", data.person, data.root)
	var cards: Array = _content_cards(data.world, "PRAYER_04", data.person, data.root)
	valid = valid and calls.size() == 1 and cards.size() == 1 and cards[0].call == calls[0].id
	_check("CP-MODE-HANDOFF", "Background first production survives focus acquisition and next-round release without resetting the cursor or duplicating the record call", valid, {"reason": "missing_or_repeated_record_production" if not valid else "", "prerequisite": "Two lawful standalone nominees and one known original record in initially background DOMAIN-002", "samples": samples, "callCount": calls.size(), "fixedCount": cards.size()})

func _empty_probe() -> void:
	var data: Dictionary = _record_probe_setup(false)
	var binding_ok: bool = data.events.generation_binding_errors(data.world, data.turn).is_empty()
	var advanced: bool = data.boot_ok and _open(data) and _evolve(data)
	var calls: Array = _content_calls(data.world, "PRAYER_04", data.person, data.root)
	var cards: Array = _content_cards(data.world, "PRAYER_04", data.person, data.root)
	var knows: bool = Producers._knows(data.world.state, data.person, data.root)
	_check("CP-LEGAL-EMPTY", "An unknown record supplies no target request while the registered evolution still succeeds", binding_ok and advanced and not knows and calls.is_empty() and cards.is_empty(), {"bindingAccepted": binding_ok, "turnsAdvanced": advanced, "recordKnown": knows, "callCount": calls.size(), "fixedCount": cards.size(), "scope": "Target record route only; no claim that all root families are empty"})
