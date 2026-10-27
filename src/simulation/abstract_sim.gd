extends RefCounted
const PrayerRules = preload("res://src/game/prayer_rules.gd")
## Current summaries only. Proposals have no identity, population or payment side effects.
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const FILES: Dictionary = {
	"fidelity_parameters": ["id", "value", "unit", "activation", "rationale"],
	"background_templates": ["id", "content_id", "source_mode", "condition", "actor_policy", "profile", "institution_role", "population_group", "expiry_rule", "rationale"],
	"simulation_responsibilities": ["id", "focused", "background", "commit_owner", "phase"],
	"prayers": ["id", "title", "need", "actor_condition", "lifetime", "shallow_gain", "shallow_cost", "deep_gain", "deep_cost", "fact_tag", "callback_event"]}
const DUTIES: Dictionary = {
	"npc_agency": ["detailed", "selected_detailed_only", "world", "4"],
	"civilization_routine": ["detailed", "abstract_due", "world", "4"],
	"risk_selection": ["risk", "risk", "world", "4"],
	"evidence_from_actor": ["detailed", "selected_detailed_only", "world", "4"],
	"economy": ["economy", "economy", "economy", "4|5"],
	"identity_and_population": ["authorized_effects", "authorized_effects", "world", "bootstrap|1|2|3|4|5"],
	"due_obligations": ["scheduler", "scheduler", "turn", "1|5"],
	"candidate_generation": ["detailed_candidates", "abstract_candidates_due", "events", "bootstrap|4"],
	"candidate_fixation": ["events", "events", "events", "bootstrap|2|3|4"],
	"attention_admission": ["attention", "attention", "turn", "bootstrap|1|2|3|4|5"],
	"derived_progress": ["derived", "derived", "world", "after_commit"],
	"ending": ["ending", "ending", "turn", "6"],
	"history_and_receipts": ["commit", "commit", "transaction", "after_commit"],
	"candidate_selection": ["events", "events", "turn", "2"]}
var parameters: Dictionary = {}
var templates: Dictionary = {}
var prayer_lifetimes: Dictionary = {}
var version: String = ""
var errors: Array[String] = []

func _init(catalog: RefCounted) -> void:
	var tables: Dictionary = {}
	var digest: String = "abstract-v1\n"
	for name: String in FILES:
		var file: FileAccess = FileAccess.open("res://data/" + name + ".csv", FileAccess.READ)
		if file == null: errors.append("Missing background table: " + name); continue
		digest += name + "\n" + file.get_as_text() + "\n"; file.seek(0)
		if Array(file.get_csv_line()) != FILES[name]: errors.append("Background header: " + name); continue
		var records: Dictionary = {}
		while not file.eof_reached():
			var cells: PackedStringArray = file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty(): continue
			if cells.size() != FILES[name].size() or cells[0].is_empty() or records.has(cells[0]): errors.append("Background row/duplicate: " + name); continue
			var row: Dictionary = {}
			for index: int in cells.size(): row[FILES[name][index]] = cells[index]
			records[cells[0]] = row
		tables[name] = records
	if not errors.is_empty(): return
	for id: String in tables.fidelity_parameters:
		var row: Dictionary = tables.fidelity_parameters[id]
		if not str(row.value).is_valid_int() or int(row.value) <= 0: errors.append("Invalid background budget: " + id)
		else: parameters[id] = int(row.value)
	for id: String in ["focused_domain_limit", "initial_focused_domains", "bound_member_limit", "temporary_actor_limit", "local_actor_limit", "background_tick_interval", "background_candidate_trials", "pending_candidate_limit", "candidate_actor_limit"]:
		if not parameters.has(id) or tables.fidelity_parameters[id].activation != "hybrid": errors.append("Missing hybrid policy: " + id)
	if tables.simulation_responsibilities.size() != DUTIES.size(): errors.append("Unknown or missing responsibility")
	for id: String in DUTIES:
		if not tables.simulation_responsibilities.has(id): errors.append("Missing responsibility: " + id); continue
		var row: Dictionary = tables.simulation_responsibilities[id]
		if [row.focused, row.background, row.commit_owner, row.phase] != DUTIES[id]: errors.append("Unsupported responsibility: " + id)
	for id: String in tables.prayers:
		if str(tables.prayers[id].lifetime).is_valid_int() and int(tables.prayers[id].lifetime) > 0: prayer_lifetimes[id] = int(tables.prayers[id].lifetime)
		else: errors.append("Invalid prayer lifetime: " + id)
	for id: String in tables.background_templates:
		var row: Dictionary = tables.background_templates[id]
		var grammar: Dictionary = {"population_available": ["PRAYER_08", "current_background", "nominate", "interpretation"], "barrier_contact": ["PRAYER_09", "current_background", "nominate", "propagation"], "known_exposure": ["PRAYER_04", "known_history", "existing", "interpretation"]}
		if not grammar.has(row.condition) or grammar[row.condition] != [row.content_id, row.source_mode, row.actor_policy, row.institution_role] or row.expiry_rule != "unanswered_request" or not tables.prayers.has(row.content_id): errors.append("Unsupported background template: " + id); continue
		if row.actor_policy == "nominate" and (not catalog.tables.npc_profiles.has(row.profile) or row.population_group != "unnamed_nonfollowers"): errors.append("Invalid nomination template: " + id); continue
		if row.actor_policy == "existing" and (not row.profile.is_empty() or not row.population_group.is_empty()): errors.append("Historical callback cannot fabricate actor: " + id); continue
		var life: String = tables.prayers[row.content_id].lifetime
		if not life.is_valid_int() or int(life) <= 0: errors.append("Invalid candidate lifetime: " + id); continue
		row.lifetime = int(life)
		templates[id] = row
	if templates.is_empty(): errors.append("No authored background templates")
	if not errors.is_empty(): return
	version = digest.sha256_text()
	History._seal(parameters); History._seal(templates)

static func seed_for(seed: String, domain: String) -> int:
	return ("background-v1/" + seed + "/" + domain).sha256_text().substr(0, 15).hex_to_int()

func initialize(state: Dictionary, seed: String, focused: Array, persistent: Array, temporary: Array) -> Dictionary:
	var cursors: Dictionary = {}
	for domain: String in state.domains:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_for(seed, domain)
		cursors[domain] = {"seed": str(rng.seed), "state": str(rng.state), "next_turn": 1 + int(rng.seed % parameters.background_tick_interval)}
	return {"schema": 1, "mode": "assigned", "policy": version, "seed": seed, "focused": focused.duplicate(), "persistent": persistent.duplicate(), "temporary": temporary.duplicate(), "cursors": cursors, "candidates": {}, "holds": {}, "next_candidate": 1, "bootstrap": false}

func proposal(view: Dictionary, domain: String, template: Dictionary) -> Dictionary:
	var data: Dictionary = view.domains[domain]
	var people: Dictionary = {}
	for actor: String in view.simulation.temporary + view.simulation.holds.keys():
		if not actor in view.simulation.persistent: people[actor] = true
	if view.simulation.mode != "hybrid" and template.actor_policy == "nominate" and (people.size() >= parameters.temporary_actor_limit or int(view.living) >= int(view.living_limit)): return {}
	if view.simulation.mode != "hybrid" and template.actor_policy == "existing" and not str(data.exposure_actor).is_empty() and not data.exposure_actor in view.simulation.persistent:
		people[data.exposure_actor] = true
		if people.size() > parameters.temporary_actor_limit: return {}
	if template.condition == "population_available" and int(data.unnamed_nonfollowers) <= 0: return {}
	if template.condition == "barrier_contact" and (int(data.barrier) <= 0 or not data.route or int(data.unnamed_nonfollowers) <= 0): return {}
	if template.condition == "known_exposure" and str(data.exposure_source).is_empty(): return {}
	if template.actor_policy == "nominate" and not template.id in data.legal_templates: return {}
	return {"snapshot_version": view.version, "producer": "abstract", "object": domain, "duty": "candidate_generation", "template": template.id, "source_ids": [data.exposure_source] if template.source_mode == "known_history" else [data.origin], "actors": [data.exposure_actor] if template.actor_policy == "existing" else [], "once_key": domain + "/" + str(view.turn) + "/" + template.id}

func propose(view: Dictionary, due: Array, responsibility: String = "candidate_generation", bootstrap: bool = false) -> Dictionary:
	if version.is_empty() or responsibility != "candidate_generation": return {"ok": false, "error": "Invalid background producer policy/duty"}
	var result: Dictionary = {"ok": true, "snapshot_version": view.version, "policy": version, "cursors": {}, "proposals": []}
	var ids: Array = due.duplicate(); ids.sort()
	for domain: String in ids:
		var cursor: Dictionary = view.simulation.cursors[domain].duplicate(true)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(cursor.seed); rng.state = int(cursor.state)
		for trial: int in (1 if bootstrap else parameters.background_candidate_trials):
			if view.simulation.candidates.size() + result.proposals.size() >= parameters.pending_candidate_limit: break
			var eligible: Array = []
			var names: Array = templates.keys(); names.sort()
			for id: String in names:
				var option: Dictionary = proposal(view, domain, templates[id])
				option["trial"] = trial
				if option.has("template"): eligible.append(option)
			if eligible.is_empty(): break
			if bootstrap or rng.randi_range(1, 100) <= int(view.chance):
				var selected: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
				selected.once_key += "/" + str(trial)
				selected["sample_before"] = cursor.state; selected["sample_after"] = str(rng.state)
				result.proposals.append(selected)
		cursor.state = str(rng.state)
		if not bootstrap: cursor.next_turn = int(view.turn) + int(parameters.background_tick_interval)
		result.cursors[domain] = cursor
	return result

func detailed_ids(state: Dictionary, index: RefCounted) -> Array:
	var selected: Dictionary = {}
	for id: String in state.simulation.persistent + state.simulation.temporary + state.simulation.holds.keys(): selected[id] = true
	for domain: String in state.simulation.focused:
		for id: String in index.ids("active/" + domain): selected[id] = true
	var result: Array = selected.keys(); result.sort()
	return result

func validate(state: Dictionary) -> Array[String]:
	if not state.has("simulation"): return []
	var issues: Array[String] = []
	var sim: Variant = state.simulation
	if version.is_empty() or not sim is Dictionary or sim.get("mode") not in ["assigned", "hybrid"] or sim.get("schema") != (2 if sim.get("mode") == "hybrid" else 1) or sim.get("policy") != version: return ["Incompatible background policy/schema"]
	if not sim.get("seed") is String or not str(sim.seed).is_valid_int() or not sim.get("bootstrap") is bool or not sim.get("next_candidate") is int or int(sim.next_candidate) < 1: return ["Invalid background metadata"]
	for field: String in ["focused", "persistent", "temporary"]:
		if not sim.get(field) is Array: return ["Invalid background assignment"]
		var seen: Dictionary = {}
		for id: Variant in sim[field]:
			if not id is String or seen.has(id) or (not state.domains.has(id) if field == "focused" else not Store.has(state.npcs, id)): return ["Unknown or duplicate assigned identity"]
			seen[id] = true
	if sim.focused.size() > parameters.focused_domain_limit or sim.persistent.size() > parameters.bound_member_limit: issues.append("Assigned focus/member capacity exceeded")
	if not sim.get("cursors") is Dictionary or not sim.get("candidates") is Dictionary or not sim.get("holds") is Dictionary: return ["Invalid background collections"]
	if sim.cursors.size() != state.domains.size(): issues.append("Missing background domain cursor")
	for id: String in state.domains:
		if not sim.cursors.get(id) is Dictionary: return ["Invalid background cursor"]
		var cursor: Dictionary = sim.cursors[id]
		if not cursor.get("seed") is String or not cursor.get("state") is String or not str(cursor.seed).is_valid_int() or not str(cursor.state).is_valid_int() or int(cursor.seed) != seed_for(sim.seed, id) or not cursor.get("next_turn") is int or cursor.next_turn < 1: issues.append("Invalid background RNG/cursor")
	if sim.candidates.size() > parameters.pending_candidate_limit: issues.append("Candidate capacity exceeded")
	var expected: Dictionary = {}
	for id: String in sim.candidates:
		var card: Variant = sim.candidates[id]
		if not card is Dictionary or card.get("id") != id or not state.domains.has(card.get("domain", "")): return ["Invalid fixed candidate"]
		if card.get("origin") == "event":
			var event_errors: Array[String] = _validate_event_card(state, id, card)
			if not event_errors.is_empty(): return event_errors
			for actor: String in card.actors:
				if Store.entry(state.npcs, actor).status == "dead": continue
				if not expected.has(actor): expected[actor] = []
				expected[actor].append(id)
			continue
		var ordinary: bool = card.get("origin") == "prayer_situation"
		if ordinary:
			if not prayer_lifetimes.has(card.get("content_id", "")) or card.get("template") != "PRAYER_SOURCE/" + str(card.get("content_id")) or card.get("source_mode") != "known_history" or card.get("default_result") != "prayer_expiry" or not card.get("source") is String or not Store.has(state.facts, card.source) or Store.entry(state.applied_authorizations, "prayer/source/" + card.source, "") != card.get("fact"): return ["Invalid ordinary prayer candidate source"]
			if not card.get("institution") is String or not card.get("subjects") is Dictionary or not card.get("facts") is Dictionary: return ["Invalid fixed prayer bindings"]
		elif not templates.has(card.get("template", "")): return ["Invalid fixed candidate template"]
		for field: String in ["visible_turn", "due_turn", "created_turn", "snapshot_version"]:
			if not card.get(field) is int: return ["Invalid fixed candidate time"]
		var lifetime: int = int(prayer_lifetimes.get(card.get("content_id", ""), 0)) if ordinary else int(templates[card.template].lifetime)
		if card.visible_turn != card.created_turn + (0 if PrayerRules.event_reopen_card(state, card) else 1) or card.due_turn != card.visible_turn + lifetime - 1 or card.created_turn > state.turn or card.created_turn < 0 or card.snapshot_version < 0 or card.get("policy") != version: issues.append("Invalid fixed candidate lifetime")
		if not ordinary and (card.get("content_id") != templates[card.template].content_id or card.get("source_mode") != templates[card.template].source_mode or card.get("default_result") != templates[card.template].expiry_rule): issues.append("Invalid background content binding")
		if not card.get("actors") is Array or card.actors.is_empty() or card.actors.size() > parameters.candidate_actor_limit or not card.get("source_ids") is Array or card.source_ids.is_empty(): return ["Invalid candidate dependencies"]
		if not card.get("crisis") is String or card.crisis.is_empty() or (not ordinary and card.crisis != "CRISIS/" + id) or not card.get("fact") is String or not Store.has(state.facts, card.fact): return ["Missing candidate fixation"]
		if id != "BACKGROUND-%08d" % int(id.get_slice("-", 1)) or int(id.get_slice("-", 1)) < 1 or int(id.get_slice("-", 1)) >= sim.next_candidate or not card.get("once_key") is String or Store.entry(state.applied_authorizations, "background/" + str(card.get("once_key", "")), "") != card.fact: issues.append("Invalid fixed candidate identity/once key")
		var fact: Dictionary = Store.entry(state.facts, card.fact)
		if fact.kind != ("prayer_fixed" if ordinary else "background_fixed") or fact.changes.get("candidate") != card or fact.turn != card.created_turn: issues.append("Candidate disagrees with immutable fixation")
		for source: Variant in card.source_ids:
			if not source is String or not Store.has(state.facts, source) or not source in fact.causal_parents: issues.append("Unknown fixed candidate source")
		var unique_actors: Dictionary = {}
		for actor: Variant in card.actors:
			if unique_actors.has(actor): return ["Duplicate fixed actor"]
			unique_actors[actor] = true
			if not actor is String or not Store.has(state.npcs, actor): return ["Unknown fixed actor"]
			if ordinary and Store.entry(state.npcs, actor).status == "dead": continue
			if not expected.has(actor): expected[actor] = []
			expected[actor].append(id)
	for institution: Dictionary in state.institutions.values():
		if not institution.has("occupancy"): continue
		if not institution.occupancy in ["occupied_abstract", "represented", "vacant", "disabled"] or (institution.occupancy == "occupied_abstract" and (not str(institution.representative).is_empty())) or (institution.occupancy == "represented" and str(institution.representative).is_empty()): issues.append("Invalid institution occupancy")
	if expected != sim.holds: issues.append("Candidate reference ownership disagrees")
	var people: Dictionary = {}
	for id: String in sim.temporary + sim.holds.keys():
		if not id in sim.persistent: people[id] = true
	if people.size() > parameters.temporary_actor_limit: issues.append("Temporary actor capacity exceeded")
	return issues

func _validate_event_card(state: Dictionary, id: String, card: Dictionary) -> Array[String]:
	if not state.get("event_system") is Dictionary or not card.get("descriptor") is Dictionary or not card.get("actors") is Array or card.actors.size() > int(parameters.candidate_actor_limit) or not card.get("source_ids") is Array or card.source_ids.is_empty(): return ["Invalid formal event fixed graph"]
	for field: String in ["content_id", "visible_turn", "due_turn", "domain", "once_key", "actors"]:
		if card.get(field) != card.descriptor.get(field): return ["Formal event card changed its fixed descriptor"]
	for field: String in ["visible_turn", "due_turn", "created_turn", "snapshot_version"]:
		if not card.get(field) is int: return ["Invalid formal event clock"]
	if card.visible_turn < 1 or card.due_turn < card.visible_turn or card.created_turn > state.turn or card.created_turn < 0 or card.snapshot_version < 0 or card.get("policy") != state.event_system.get("version"): return ["Invalid formal event source window or version"]
	if card.get("template") != "EVENT_SOURCE/" + str(card.get("content_id")) or card.get("source_mode") != "known_history" or card.get("default_result") != card.descriptor.get("default_action") or card.get("crisis") != "EVENT/" + id: return ["Invalid formal event content binding"]
	if id != "BACKGROUND-%08d" % int(id.get_slice("-", 1)) or int(id.get_slice("-", 1)) < 1 or int(id.get_slice("-", 1)) >= state.simulation.next_candidate: return ["Invalid formal event persistent identity"]
	if not card.get("fact") is String or not Store.has(state.facts, card.fact) or Store.entry(state.applied_authorizations, "background/" + str(card.get("once_key", "")), "") != card.fact or Store.entry(state.applied_authorizations, str(card.get("once_key", "")), "") != card.fact: return ["Formal event lost its source consumption"]
	var fixed: Dictionary = Store.entry(state.facts, card.fact)
	if fixed.kind != "event_fixed" or fixed.changes.get("candidate") != card or fixed.turn != card.created_turn: return ["Formal event disagrees with immutable fixation"]
	for source: Variant in card.source_ids:
		if not source is String or not Store.has(state.facts, source) or not source in fixed.causal_parents: return ["Formal event lost a fixed cause"]
	var seen: Dictionary = {}
	for actor: Variant in card.actors:
		if not actor is String or seen.has(actor) or not Store.has(state.npcs, actor): return ["Formal event has an unknown or duplicate fixed actor"]
		seen[actor] = true
	return []
