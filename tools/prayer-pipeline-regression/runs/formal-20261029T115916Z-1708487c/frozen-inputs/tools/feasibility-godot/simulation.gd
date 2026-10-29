extends RefCounted
## Deterministic, plain-data simulator for technical feasibility only.

const Catalog = preload("res://catalog.gd")
const STREAM_NAMES: Array[String] = ["generation", "checks", "events"]
const SAVE_SCHEMA: int = 1
const STAT_KEYS: Array[String] = ["executed", "cancelled_dead", "cancelled_expired", "cancelled_condition", "candidate_checks", "blank_turns", "compact_records", "npc_updates"]
var catalog: RefCounted
var state: Dictionary = {}
var streams: Dictionary = {}
var last_error: String = ""
var generation_attempts: int = 0
var stats: Dictionary = {}

func _init(content: RefCounted) -> void:
	catalog = content

func new_run(run_seed: int, civilization_count: int, npcs_per_civilization: int) -> bool:
	last_error = ""
	generation_attempts = 0
	streams.clear()
	for name: String in STREAM_NAMES:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = (str(run_seed) + ":" + name).sha256_text().substr(0, 15).hex_to_int()
		streams[name] = rng
	state = {"turn": 0, "faith": int(catalog.parameters.initial_faith), "civilizations": {}, "npcs": {}, "cults": {}, "relics": {}, "pending": [], "history": {}, "next_event": 1, "fired": {}, "last_causes": {}}
	stats = {"executed": 0, "cancelled_dead": 0, "cancelled_expired": 0, "cancelled_condition": 0, "candidate_checks": 0, "blank_turns": 0, "compact_records": 0, "npc_updates": 0}
	for index: int in civilization_count:
		var civ: Dictionary = _generate_civilization(index)
		if civ.is_empty():
			return false
		state.civilizations[civ.id] = civ
		var cult_id: String = "cult_%04d" % index
		state.cults[cult_id] = {"id": cult_id, "civilization": civ.id, "members": []}
		for member_index: int in npcs_per_civilization:
			var templates: Array = catalog.rows.npcs
			var template: Dictionary = templates[streams.generation.randi_range(0, templates.size() - 1)]
			var npc_id: String = "npc_%04d_%04d" % [index, member_index]
			var npc: Dictionary = {"id": npc_id, "civilization": civ.id, "cult": cult_id, "template": template.id, "alive": true, "competence": int(template.competence), "resolve": int(template.resolve), "sanity": int(template.sanity), "faith": int(template.faith), "exposure": 0}
			state.npcs[npc_id] = npc
			state.cults[cult_id].members.append(npc_id)
			civ.members.append(npc_id)
		var relic_id: String = "relic_%04d" % index
		state.relics[relic_id] = {"id": relic_id, "civilization": civ.id, "holder": "" if civ.members.is_empty() else civ.members[0]}
	return validate_state(state).is_empty()

func _generate_civilization(index: int) -> Dictionary:
	var rng: RandomNumberGenerator = streams.generation
	for attempt: int in int(catalog.parameters.generation_attempt_limit):
		generation_attempts += 1
		var paradigms: Array = []
		var choices: Array = catalog.choices("paradigm")
		if choices.is_empty():
			break
		paradigms.append(choices[rng.randi_range(0, choices.size() - 1)].id)
		var second: String = choices[rng.randi_range(0, choices.size() - 1)].id
		if not second in paradigms:
			paradigms.append(second)
		paradigms.sort()
		var civ: Dictionary = {"id": "civ_%04d" % index, "paradigms": paradigms, "members": [], "pollution": int(catalog.parameters.initial_pollution), "alert": int(catalog.parameters.initial_alert)}
		var complete: bool = true
		for dimension: String in ["government", "channel", "institution", "anchor", "tier"]:
			var compatible: Array = catalog.choices(dimension, paradigms)
			if compatible.is_empty():
				complete = false
				break
			var chosen: Dictionary = compatible[rng.randi_range(0, compatible.size() - 1)]
			civ[dimension] = chosen.id
			if dimension == "tier":
				civ.barrier = int(chosen.barrier)
				civ.stability = int(chosen.stability)
		if complete:
			return civ
	last_error = "civilization generation exhausted bounded attempts at index %d" % index
	return {}

func advance(commands: Array = []) -> void:
	state.turn += 1
	var executed_before: int = int(stats.executed)
	var pending_before: Array = state.pending
	state.pending = []
	# Only items queued before this turn may resolve here. Effects cannot recursively drain.
	for scheduled: Dictionary in pending_before:
		if int(scheduled.expires) < int(state.turn):
			stats.cancelled_expired += 1
			continue
		if int(scheduled.due) > int(state.turn):
			state.pending.append(scheduled)
			continue
		var definition: Dictionary = catalog.events[scheduled.template]
		if not state.npcs.has(scheduled.npc) or not state.npcs[scheduled.npc].alive:
			stats.cancelled_dead += 1
			continue
		if not _conditions(definition, state.civilizations[scheduled.civilization]):
			stats.cancelled_condition += 1
			continue
		_execute(definition, scheduled.civilization, scheduled.npc, scheduled.parent)
	for command: Dictionary in commands:
		_apply_command(command)
	for civ_id: String in state.civilizations:
		var civ: Dictionary = state.civilizations[civ_id]
		civ.alert = maxi(0, int(civ.alert) - int(catalog.parameters.passive_alert_decay))
		civ.pollution = maxi(0, int(civ.pollution) - int(catalog.parameters.passive_pollution_decay))
		var alive: Array[String] = []
		for npc_id: String in civ.members:
			var npc: Dictionary = state.npcs[npc_id]
			stats.npc_updates += 1
			if npc.alive:
				alive.append(npc_id)
				npc.exposure = clampi(int(npc.exposure) + (1 if int(civ.pollution) > int(npc.resolve) else -1), 0, 100)
		state.faith = mini(int(catalog.parameters.faith_cap), int(state.faith) + alive.size() * int(catalog.parameters.faith_per_alive_npc))
		if alive.is_empty():
			continue
		var candidates: Array = eligible_events(civ_id)
		var used_groups: Dictionary = {}
		var count: int = 0
		for candidate: Dictionary in candidates:
			if count >= int(catalog.parameters.max_events_per_civilization_turn):
				break
			if used_groups.has(candidate.exclusive_group):
				continue
			if streams.events.randi_range(1, 100) > int(candidate.chance):
				continue
			var target: String = alive[streams.events.randi_range(0, alive.size() - 1)]
			if not state.npcs[target].alive:
				continue
			_execute(candidate, civ_id, target, str(state.last_causes.get(civ_id, "")))
			used_groups[candidate.exclusive_group] = true
			count += 1
	if int(stats.executed) == executed_before:
		stats.blank_turns += 1
	if state.history.size() >= int(catalog.parameters.history_compact_after_records) and int(state.turn) % 32 == 0:
		_compact_history()

func _apply_command(command: Dictionary) -> bool:
	if not command.has("kind") or not command.has("civilization") or not state.civilizations.has(command.civilization):
		return false
	var civ: Dictionary = state.civilizations[command.civilization]
	if command.kind == "conceal":
		if int(state.faith) < int(catalog.parameters.action_cost):
			return false
		state.faith -= int(catalog.parameters.action_cost)
		civ.alert = maxi(0, int(civ.alert) - int(catalog.parameters.conceal_alert_reduction))
		_record("conceal", str(civ.id), "", str(state.last_causes.get(civ.id, "")), {})
		return true
	if command.kind == "intervene":
		if int(state.faith) < int(catalog.parameters.action_cost):
			return false
		state.faith -= int(catalog.parameters.action_cost)
		var success: bool = streams.checks.randi_range(1, 100) <= int(catalog.parameters.action_success_percent)
		if success:
			civ.pollution = mini(100, int(civ.pollution) + int(catalog.parameters.action_pollution_gain))
		civ.alert = mini(100, int(civ.alert) + int(catalog.parameters.action_alert_gain))
		_record("intervention", str(civ.id), "", str(state.last_causes.get(civ.id, "")), {"success": success})
		return true
	if command.kind == "kill" and command.has("npc") and state.npcs.has(command.npc) and state.npcs[command.npc].civilization == civ.id:
		_kill(command.npc)
		_record("death", str(civ.id), str(command.npc), str(state.last_causes.get(civ.id, "")), {})
		return true
	return false

func eligible_events(civ_id: String) -> Array:
	var result: Array = []
	var civ: Dictionary = state.civilizations[civ_id]
	for event_id: String in catalog.events:
		var definition: Dictionary = catalog.events[event_id]
		stats.candidate_checks += 1
		# Delayed definitions enter only through their explicit causal parent.
		if int(definition.delay) > 0 or not _conditions(definition, civ):
			continue
		var key: String = civ_id + ":" + event_id
		if state.fired.has(key):
			if int(definition.once) == 1 or int(state.turn) - int(state.fired[key]) < int(definition.cooldown):
				continue
		if int(definition.requires_alive) == 1 and _alive_target(civ_id).is_empty():
			continue
		result.append(definition)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority) == int(b.priority):
			return str(a.id) < str(b.id)
		return int(a.priority) > int(b.priority)
	)
	return result

func _conditions(definition: Dictionary, civ: Dictionary) -> bool:
	return int(civ.alert) >= int(definition.min_alert) and int(civ.alert) <= int(definition.max_alert) and int(civ.pollution) >= int(definition.min_pollution) and int(civ.pollution) <= int(definition.max_pollution)

func _alive_target(civ_id: String) -> String:
	for npc_id: String in state.civilizations[civ_id].members:
		if state.npcs[npc_id].alive:
			return npc_id
	return ""

func _execute(definition: Dictionary, civ_id: String, npc_id: String, parent: String) -> void:
	var civ: Dictionary = state.civilizations[civ_id]
	match str(definition.effect):
		"faith":
			state.faith = clampi(int(state.faith) + int(definition.delta), 0, int(catalog.parameters.faith_cap))
		"alert", "pollution":
			civ[definition.effect] = clampi(int(civ[definition.effect]) + int(definition.delta), 0, 100)
		"kill":
			_kill(npc_id)
	var record_id: String = _record(str(definition.id), civ_id, npc_id, parent, {"effect": definition.effect, "delta": definition.delta})
	state.fired[civ_id + ":" + str(definition.id)] = int(state.turn)
	stats.executed += 1
	if not str(definition.followup).is_empty():
		var followup: Dictionary = catalog.events[definition.followup]
		state.pending.append({"template": followup.id, "civilization": civ_id, "npc": npc_id, "parent": record_id, "due": int(state.turn) + maxi(1, int(followup.delay)), "expires": int(state.turn) + maxi(1, int(followup.delay)) + int(catalog.parameters.event_expiry_turns)})

func _kill(npc_id: String) -> void:
	state.npcs[npc_id].alive = false
	# A deceased person stays addressable; possessions return to their location.
	for relic_id: String in state.relics:
		if state.relics[relic_id].holder == npc_id:
			state.relics[relic_id].holder = ""

func _record(kind: String, civ_id: String, npc_id: String, parent: String, detail: Dictionary) -> String:
	var event_id: String = "event_%09d" % int(state.next_event)
	state.next_event += 1
	# Facts are permanent: outcome/effect deltas may be needed by later narrative.
	# Only redundant display/debug labels are eligible for compaction.
	state.history[event_id] = {"id": event_id, "kind": kind, "civilization": civ_id, "npc": npc_id, "parent": parent, "turn": int(state.turn), "facts": detail.duplicate(true), "detail": {"source_label": kind}}
	state.last_causes[civ_id] = event_id
	return event_id

func _compact_history() -> void:
	# Keep IDs, causal links and participants forever; discard only old display detail.
	# This reduces payload but does not promise constant-memory infinite campaigns.
	for event_id: String in state.history:
		var record: Dictionary = state.history[event_id]
		if record.has("detail") and int(state.turn) - int(record.turn) > int(catalog.parameters.history_full_retention_turns):
			record.erase("detail")
			stats.compact_records += 1

func rng_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for name: String in STREAM_NAMES:
		# Decimal strings avoid JSON's float-based 53-bit exact-integer limit.
		snapshot[name] = {"seed": str(streams[name].seed), "state": str(streams[name].state)}
	return snapshot

func save_text() -> String:
	var payload: Dictionary = {"schema": SAVE_SCHEMA, "engine": Engine.get_version_info().string, "content": catalog.version, "rng": rng_snapshot(), "state": state, "stats": stats}
	var text: String = JSON.stringify(payload, "", true, true)
	return JSON.stringify({"payload": text, "checksum": text.sha256_text()})

func load_text(text: String) -> bool:
	last_error = ""
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _reject("invalid envelope JSON")
	var envelope: Dictionary = parser.data
	if not envelope.get("payload") is String or not envelope.get("checksum") is String:
		return _reject("invalid envelope fields")
	if envelope.payload.sha256_text() != envelope.checksum:
		return _reject("checksum mismatch")
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary:
		return _reject("invalid payload JSON")
	var payload: Dictionary = parser.data
	if int(payload.get("schema", -1)) != SAVE_SCHEMA or payload.get("content", "") != catalog.version or payload.get("engine", "") != Engine.get_version_info().string:
		return _reject("unsupported schema/content/engine version")
	if not payload.get("rng") is Dictionary or not payload.get("state") is Dictionary or not payload.get("stats") is Dictionary:
		return _reject("missing state or rng")
	for key: String in STAT_KEYS:
		if not _nonnegative_integer(payload.stats.get(key)):
			return _reject("invalid statistics counter: " + key)
	for name: String in STREAM_NAMES:
		if not payload.rng.get(name) is Dictionary:
			return _reject("missing random stream")
		var record: Dictionary = payload.rng[name]
		if not record.get("seed") is String or not record.get("state") is String or not record.seed.is_valid_int() or not record.state.is_valid_int():
			return _reject("invalid RNG integer string")
	var failures: Array[String] = validate_state(payload.state)
	if not failures.is_empty():
		return _reject("invalid state: " + "; ".join(failures))
	# Commit only after every validation succeeds; failed loads leave active state intact.
	state = _restore_integers(payload.state)
	stats = _restore_integers(payload.stats)
	streams.clear()
	for name: String in STREAM_NAMES:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(payload.rng[name].seed)
		rng.state = int(payload.rng[name].state)
		streams[name] = rng
	return true

func _restore_integers(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Dictionary:
		var restored: Dictionary = {}
		for key: Variant in value:
			restored[key] = _restore_integers(value[key])
		return restored
	if value is Array:
		var restored: Array = []
		for element: Variant in value:
			restored.append(_restore_integers(element))
		return restored
	return value

func _reject(reason: String) -> bool:
	last_error = reason
	return false

func validate_state(candidate: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for field: String in ["civilizations", "npcs", "cults", "relics", "history", "fired", "last_causes"]:
		if not candidate.get(field) is Dictionary:
			failures.append("missing dictionary: " + field)
	if not candidate.get("pending") is Array:
		failures.append("missing pending array")
	for field: String in ["turn", "faith", "next_event"]:
		if not _nonnegative_integer(candidate.get(field)):
			failures.append("invalid counter: " + field)
	if not failures.is_empty():
		return failures
	var civilization_memberships: Dictionary = {}
	var cult_memberships: Dictionary = {}
	for civ_id: String in candidate.civilizations:
		var civ: Variant = candidate.civilizations[civ_id]
		if not civ is Dictionary or civ.get("id") != civ_id or not civ.get("members") is Array or not civ.get("paradigms") is Array:
			failures.append("invalid civilization: " + civ_id)
			continue
		for metric: String in ["barrier", "pollution", "alert", "stability"]:
			if not _bounded_metric(civ.get(metric)):
				failures.append("civilization metric: " + metric)
		for dimension: String in ["government", "channel", "institution", "anchor", "tier"]:
			var found: bool = false
			for row: Dictionary in catalog.choices(dimension, civ.paradigms):
				if row.id == civ.get(dimension):
					found = true
			if not found:
				failures.append("incompatible civilization dimension: " + dimension)
		for npc_id: Variant in civ.members:
			civilization_memberships[npc_id] = int(civilization_memberships.get(npc_id, 0)) + 1
			if not candidate.npcs.has(npc_id):
				failures.append("missing civilization member")
			elif not candidate.npcs[npc_id] is Dictionary or candidate.npcs[npc_id].get("civilization") != civ_id:
				failures.append("inconsistent civilization membership")
	for npc_id: String in candidate.npcs:
		var npc: Variant = candidate.npcs[npc_id]
		if not npc is Dictionary or npc.get("id") != npc_id or not npc.get("alive") is bool:
			failures.append("invalid NPC: " + npc_id)
			continue
		if not candidate.civilizations.has(npc.get("civilization")) or not candidate.cults.has(npc.get("cult")):
			failures.append("NPC orphan: " + npc_id)
		for metric: String in ["competence", "resolve", "sanity", "faith", "exposure"]:
			if not _bounded_metric(npc.get(metric)):
				failures.append("NPC metric: " + metric)
	for cult_id: String in candidate.cults:
		var cult: Variant = candidate.cults[cult_id]
		if not cult is Dictionary or cult.get("id") != cult_id or not cult.get("members") is Array or not candidate.civilizations.has(cult.get("civilization")):
			failures.append("invalid cult: " + cult_id)
			continue
		for npc_id: Variant in cult.members:
			cult_memberships[npc_id] = int(cult_memberships.get(npc_id, 0)) + 1
			if not candidate.npcs.has(npc_id):
				failures.append("missing cult member")
			elif not candidate.npcs[npc_id] is Dictionary or candidate.npcs[npc_id].get("cult") != cult_id or candidate.npcs[npc_id].get("civilization") != cult.civilization:
				failures.append("inconsistent cult membership")
	for npc_id: String in candidate.npcs:
		if int(civilization_memberships.get(npc_id, 0)) != 1 or int(cult_memberships.get(npc_id, 0)) != 1:
			failures.append("NPC must have exactly one civilization and cult membership")
	for relic_id: String in candidate.relics:
		var relic: Variant = candidate.relics[relic_id]
		if not relic is Dictionary or relic.get("id") != relic_id or not candidate.civilizations.has(relic.get("civilization")) or not relic.get("holder") is String:
			failures.append("invalid relic: " + relic_id)
			continue
		if not relic.holder.is_empty() and (not candidate.npcs.has(relic.holder) or not candidate.npcs[relic.holder].alive):
			failures.append("invalid relic holder")
	var max_event_number: int = 0
	for event_id: String in candidate.history:
		if not event_id.begins_with("event_") or not event_id.substr(6).is_valid_int():
			failures.append("invalid history ID format")
		else:
			max_event_number = maxi(max_event_number, int(event_id.substr(6)))
		var record: Variant = candidate.history[event_id]
		if not record is Dictionary or record.get("id") != event_id or not record.get("parent") is String or not record.get("npc") is String or not record.get("facts") is Dictionary or not candidate.civilizations.has(record.get("civilization")) or not _nonnegative_integer(record.get("turn")):
			failures.append("invalid history: " + event_id)
			continue
		if not record.parent.is_empty() and (not candidate.history.has(record.parent) or str(record.parent) >= event_id):
			failures.append("orphan/noncausal history parent")
		if not record.npc.is_empty() and not candidate.npcs.has(record.npc):
			failures.append("orphan history participant")
	if int(candidate.next_event) <= max_event_number:
		failures.append("next_event would reuse a history ID")
	for civ_id: String in candidate.last_causes:
		var cause: Variant = candidate.last_causes[civ_id]
		if not candidate.civilizations.has(civ_id) or not cause is String or not candidate.history.has(cause) or not candidate.history[cause] is Dictionary or candidate.history[cause].get("civilization") != civ_id:
			failures.append("orphan last cause")
	for fired_key: String in candidate.fired:
		var parts: PackedStringArray = fired_key.split(":")
		if parts.size() != 2 or not candidate.civilizations.has(parts[0]) or not catalog.events.has(parts[1]) or not _nonnegative_integer(candidate.fired[fired_key]) or int(candidate.fired[fired_key]) > int(candidate.turn):
			failures.append("invalid event cooldown history")
	for item: Variant in candidate.pending:
		if not item is Dictionary or not catalog.events.has(item.get("template")) or not candidate.civilizations.has(item.get("civilization")) or not candidate.npcs.has(item.get("npc")) or not candidate.history.has(item.get("parent")):
			failures.append("orphan pending event")
			continue
		if not _nonnegative_integer(item.get("due")) or not _nonnegative_integer(item.get("expires")) or int(item.due) > int(item.expires):
			failures.append("invalid pending dates")
	return failures

func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) >= 0.0 and float(value) == floorf(float(value))

func _bounded_metric(value: Variant) -> bool:
	return _nonnegative_integer(value) and float(value) <= 100.0
