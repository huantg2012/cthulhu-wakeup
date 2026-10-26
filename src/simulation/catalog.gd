extends RefCounted
## The authored CSV catalog is the only source of gameplay values.
## Loading is transactional: malformed content never replaces an existing catalog.

const ATTRIBUTES: Array[String] = ["will", "insight", "influence", "adaptation"]
const FILES: Array[String] = [
	"npc_profiles", "civilization_profiles", "civilization_conditions", "civilization_parameters", "run_parameters",
	"npc_behaviors", "simulation_parameters", "civilization_actions", "resistance_plans", "event_parameters",
]
const EXTENSIONS: Array[String] = ["powers", "power_effects", "relics", "relic_effects"]
## Supported effect grammar, not balance data: each handler requires this exact
## institution/evidence/target contract before it can safely execute a CSV row.
const CIVILIZATION_EFFECT_SIGNATURES: Dictionary = {
	"confirm_evidence": ["order", "exposed", "npc|relic"],
	"purge_cult": ["order", "confirmed_npc", "cult"],
	"seize_relic": ["order", "confirmed_relic", "relic"],
	"repair_barrier": ["order", "breach", "civilization"],
	"destroy_anchor": ["order", "confirmed_anchor", "anchor"],
	"rewrite_reality": ["interpretation", "confirmed_exception", "record"],
}
var tables: Dictionary = {}
var parameters: Dictionary = {}
var version: String = ""
var extension_versions: Dictionary = {}
var errors: Array[String] = []

func load_files(directory: String = "res://data") -> bool:
	var candidate: Dictionary = {}
	var candidate_parameters: Dictionary = {}
	var digest_input: String = ""
	var candidate_extensions: Dictionary = {}
	errors.clear()
	for name: String in FILES + EXTENSIONS:
		var path: String = directory.path_join(name + ".csv")
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			errors.append("Missing CSV: " + path)
			continue
		var content: String = name + "\n" + file.get_as_text() + "\n"
		if name in EXTENSIONS: candidate_extensions[name] = content.sha256_text()
		else: digest_input += content
		file.seek(0)
		var headers: PackedStringArray = file.get_csv_line()
		var key_field: String = "profile_id" if name == "civilization_conditions" else ("relic_id" if name == "relic_effects" else "id")
		if headers.is_empty() or headers[0] != key_field or Array(headers).size() != _unique(Array(headers)).size():
			errors.append("Invalid header: " + name)
			continue
		var records: Dictionary = {}
		while not file.eof_reached():
			var cells: PackedStringArray = file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty():
				continue
			if cells.size() != headers.size() or cells[0].is_empty() or records.has(cells[0]):
				errors.append("Invalid row or duplicate ID: " + name + " " + str(cells))
				continue
			var row: Dictionary = {}
			for index: int in headers.size():
				row[headers[index]] = cells[index]
			records[row[key_field]] = row
			if name.ends_with("parameters"):
				if not row.has("value") or not str(row.value).is_valid_float() or not is_finite(float(row.value)):
					errors.append("Invalid numeric parameter: " + str(row.id))
				elif candidate_parameters.has(row.id):
					errors.append("Duplicate parameter name: " + str(row.id))
				else:
					candidate_parameters[row.id] = float(row.value)
		candidate[name] = records
	if errors.is_empty():
		errors.append_array(_validate(candidate, candidate_parameters))
	if not errors.is_empty():
		return false
	tables = candidate
	parameters = candidate_parameters
	version = digest_input.sha256_text()
	extension_versions = candidate_extensions
	return true

func number(key: String) -> float:
	assert(parameters.has(key), "Unknown authored parameter: " + key)
	return float(parameters[key])

func integer(key: String) -> int:
	return int(number(key))

func _unique(values: Array) -> Array:
	var found: Array = []
	for value: Variant in values:
		if not value in found:
			found.append(value)
	return found

func _validate(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	for name: String in FILES:
		if not candidate.has(name) or candidate[name].is_empty():
			issues.append("Empty collection: " + name)
	if not issues.is_empty():
		return issues
	var required: Array[String] = ["npc_attribute_min", "npc_attribute_max", "attribute_max", "domains_total", "planet_domains", "system_domains", "cosmic_domains", "initial_named_per_domain", "institutions_per_domain", "living_named_global_limit", "domain_population", "domain_population_capacity", "autonomous_actions_per_npc", "autonomous_recovery_threshold", "evidence_confirmation_strength", "growth_distinct_sources_per_point", "growth_attribute_increment", "institution_successor_min_sanity", "interpretation_public_alert", "initial_generic_relation_count", "check_base", "check_attribute_step", "check_probability_min", "check_probability_max", "check_preparation_limit", "check_barrier_divisor", "check_alert_divisor", "check_critical_divisor", "check_planet_difficulty", "check_system_difficulty", "check_cosmic_difficulty", "loyalty_follower_threshold", "pollution_base_decay", "alert_quiet_decay", "barrier_base_recovery", "first_breach_threshold", "whisper_growth_step", "whisper_base", "whisper_cap", "initial_faith", "initial_insight", "initial_wounds", "initial_awakening", "awakening_before_final_cap", "cult_succession_cohesion_cost", "sanity_stable_threshold", "sanity_fractured_threshold", "major_event_limit", "prayer_response_limit", "faith_capacity_base", "faith_capacity_per_peak_awakening"]
	required.append_array(["cult_form_local_spend", "cult_form_followers", "cult_form_loyalty", "cult_initial_cohesion", "cult_dormant_max_turns", "cult_replace_leader_cohesion_cost"])
	required.append_array(["cult_income_cap", "cult_natural_attrition", "expansion_faith_cost", "expansion_base_growth", "expansion_influence_divisor", "expansion_alert", "conceal_income_multiplier", "conceal_alert", "anchor_followers_min", "anchor_cohesion_min"])
	for tier: String in ["planet", "system", "cosmic"]:
		required.append("anchor_" + tier + "_upkeep")
	for ordinal: int in [1, 2, 3]:
		required.append("anchor_maintain_pollution_" + str(ordinal))
	for key: String in required:
		if not values.has(key):
			issues.append("Missing required parameter: " + key)
	for tier: String in ["planet", "system", "cosmic"]:
		if not values.has("anchor_" + tier + "_contribution"):
			issues.append("Missing anchor contribution")
	for band: String in ["stable", "disordered"]:
		for mode: String in ["social", "occult"]:
			if not values.has("sanity_" + band + "_" + mode + "_modifier"):
				issues.append("Missing sanity modifier")
	if not issues.is_empty():
		return issues
	for key: String in ["check_barrier_divisor", "check_alert_divisor", "check_critical_divisor", "growth_distinct_sources_per_point", "whisper_growth_step", "evidence_confirmation_strength"]:
		if float(values[key]) <= 0:
			issues.append("Nonpositive divisor/threshold: " + key)
	for key: String in ["major_event_limit", "prayer_response_limit", "whisper_base", "whisper_cap", "faith_capacity_base", "faith_capacity_per_peak_awakening"]:
		if float(values[key]) < 0 or float(values[key]) != float(int(values[key])):
			issues.append("Invalid nonnegative integer budget: " + key)
	if int(values.whisper_base) > int(values.whisper_cap):
		issues.append("Initial whisper budget exceeds cap")
	for key: String in ["cult_income_cap", "expansion_faith_cost", "expansion_base_growth", "expansion_alert", "anchor_followers_min", "anchor_cohesion_min", "anchor_planet_upkeep", "anchor_system_upkeep", "anchor_cosmic_upkeep", "anchor_maintain_pollution_1", "anchor_maintain_pollution_2", "anchor_maintain_pollution_3"]:
		if float(values[key]) < 0 or float(values[key]) != float(int(values[key])):
			issues.append("Invalid authored economy integer: " + key)
	if float(values.expansion_influence_divisor) < 1 or float(values.expansion_influence_divisor) != float(int(values.expansion_influence_divisor)) or float(values.conceal_alert) != float(int(values.conceal_alert)):
		issues.append("Invalid economy divisor or alert delta")
	for key: String in ["cult_natural_attrition", "conceal_income_multiplier"]:
		if float(values[key]) < 0 or float(values[key]) > 1:
			issues.append("Invalid economy ratio: " + key)
	if absf(float(values.cult_natural_attrition) * 1000000.0 - round(float(values.cult_natural_attrition) * 1000000.0)) > 0.000001:
		issues.append("Attrition rate exceeds supported six decimal places")
	if int(values.autonomous_actions_per_npc) != 1 or int(values.institutions_per_domain) != 3 or int(values.initial_generic_relation_count) != 1:
		issues.append("Unsupported action/institution count")
	for power: Dictionary in candidate.powers.values():
		for field: String in ["whispers", "faith", "unlock_awakening", "cooldown_turns"]:
			if not power.get(field, "").is_valid_int() or int(power[field]) < 0: issues.append("Invalid power cost/threshold: " + str(power.id))
		if not power.get("check_kind", "") in ["deterministic", "social", "occult"] or (power.check_kind != "deterministic" and not power.get("attribute", "") in ATTRIBUTES): issues.append("Invalid power check grammar")
	issues.append_array(_validate_power_grammar(candidate, values))
	var appointment: Dictionary = candidate.powers.get("POWER_APPOINT", {})
	for field: String in ["whispers", "faith", "unlock_awakening"]:
		if not appointment.get(field, "").is_valid_int() or int(appointment[field]) < 0: issues.append("Invalid appointment cost/threshold: " + field)
	for key: String in ["cult_form_local_spend", "cult_form_followers", "cult_form_loyalty", "cult_initial_cohesion", "cult_dormant_max_turns", "cult_replace_leader_cohesion_cost"]:
		if values[key] < 0 or float(values[key]) != float(int(values[key])): issues.append("Invalid cult parameter: " + key)
	for row: Dictionary in candidate.npc_behaviors.values():
		for field: String in ["base_score", "attribute_weight", "need_bonus", "cooldown_turns", "effect_base", "effect_divisor", "sanity_cost", "target_loyalty_delta"]:
			if not row.has(field) or not str(row[field]).is_valid_int() or int(row[field]) < 0:
				issues.append("Invalid behavior numeric field: " + str(row.id) + "." + field)
		if not row.has("effect_divisor") or int(row.effect_divisor) <= 0:
			issues.append("Behavior divisor must be positive")
		if not row.get("attribute", "") in ATTRIBUTES or not row.get("eligibility", "") in ["strained_self", "known_local_exposure", "related_harmed_follower", "personally_witnessed_miracle"] or not row.get("effect", "") in ["restore_self_sanity", "gather_evidence", "restore_target_sanity", "increase_self_loyalty"] or not row.get("repeat_policy", "") in ["repeat_until_threshold", "once_per_actor_source", "once_per_actor_source_target"]:
			issues.append("Unknown behavior grammar")
	var plan_ids: Array = candidate.resistance_plans.keys()
	var action_ids: Array = candidate.civilization_actions.keys()
	plan_ids.sort()
	action_ids.sort()
	if plan_ids != action_ids:
		issues.append("Resistance effects must correspond one to one")
	for row: Dictionary in candidate.resistance_plans.values():
		for field: String in ["min_alert", "priority", "warning_turns", "cooldown_turns"]:
			if not row.has(field) or not str(row[field]).is_valid_int() or int(row[field]) < 0:
				issues.append("Invalid resistance numeric field")
	for row: Dictionary in candidate.civilization_actions.values():
		for field: String in ["cohesion_delta", "barrier_delta", "pollution_delta", "wounds_delta"]:
			if not row.has(field) or not str(row[field]).is_valid_int():
				issues.append("Invalid civilization effect integer")
		if not str(row.get("followers_loss_ratio", "")).is_valid_float() or float(row.followers_loss_ratio) < 0.0 or float(row.followers_loss_ratio) > 1.0:
			issues.append("Invalid population loss fraction")
		if not row.get("institution_role", "") in ["order", "interpretation"] or not row.get("effect", "") in ["confirm_evidence", "purge_cult", "seize_relic", "repair_barrier", "destroy_anchor", "rewrite_reality"] or not row.get("evidence_requirement", "") in ["exposed", "confirmed_npc", "confirmed_relic", "breach", "confirmed_anchor", "confirmed_exception"]:
			issues.append("Unknown civilization effect grammar")
		if not row.get("target_kind", "") in ["npc|relic", "cult", "relic", "civilization", "anchor", "record"]:
			issues.append("Unknown civilization target kind")
		if CIVILIZATION_EFFECT_SIGNATURES.has(row.get("effect", "")):
			var signature: Array = [row.get("institution_role", ""), row.get("evidence_requirement", ""), row.get("target_kind", "")]
			if signature != CIVILIZATION_EFFECT_SIGNATURES[row.effect]:
				issues.append("Incompatible civilization effect contract: " + str(row.id))
	for row: Dictionary in candidate.npc_profiles.values():
		for flag: String in ["requires_ritual", "requires_route", "requires_crisis", "requires_listener"]:
			if not row.has(flag) or not str(row[flag]).is_valid_int() or not int(row[flag]) in [0, 1]:
				issues.append("Invalid NPC context flag")
		for role: String in str(row.get("institution_roles", "")).split("|"):
			if not role in ["interpretation", "propagation", "order", "none"]:
				issues.append("Unknown institution role")
		for attribute: String in ATTRIBUTES + ["sanity", "loyalty"]:
			if not row.has(attribute) or not str(row[attribute]).is_valid_int():
				issues.append("NPC attribute must be integer: " + str(row.id) + "." + attribute)
				continue
			var maximum: int = int(values.npc_attribute_max) if attribute in ATTRIBUTES else int(values.attribute_max)
			if int(row[attribute]) < 0 or int(row[attribute]) > maximum:
				issues.append("NPC attribute range: " + str(row.id) + "." + attribute)
	if candidate.civilization_profiles.size() != candidate.civilization_conditions.size():
		issues.append("Missing civilization condition rows")
	for row: Dictionary in candidate.civilization_profiles.values():
		if not candidate.civilization_conditions.has(row.id) or not row.authority in str(candidate.civilization_conditions.get(row.id, {}).get("allowed_authority", "")).split("|"):
			issues.append("Illegal civilization authority or missing condition")
		var sum: int = 0
		for field: String in ["tech", "occult", "faith", "meme", "barrier", "stability"]:
			if not row.has(field) or not str(row[field]).is_valid_int() or int(row[field]) < 0 or int(row[field]) > int(values.attribute_max):
				issues.append("Civilization attribute range: " + str(row.id) + "." + field)
			elif field in ["tech", "occult", "faith", "meme"]:
				sum += int(row[field])
		if sum != int(values.attribute_max) or not row.get("tier", "") in ["planet", "system", "cosmic"]:
			issues.append("Civilization paradigm/tier: " + str(row.id))
	if int(values.domains_total) != int(values.planet_domains) + int(values.system_domains) + int(values.cosmic_domains):
		issues.append("Domain tier counts do not sum")
	if int(values.initial_named_per_domain) < int(values.institutions_per_domain) or int(values.domains_total) * int(values.initial_named_per_domain) > int(values.living_named_global_limit):
		issues.append("Named population budget is impossible")
	return issues

func _validate_power_grammar(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var outcomes: Dictionary = {}
	var numeric: Array[String] = ["delta", "grant_preparation", "migrate", "detain", "seal"]
	for row: Dictionary in candidate.power_effects.values():
		var power: String = str(row.get("power_id", ""))
		var operation: String = str(row.get("operation", ""))
		var subject: String = str(row.get("subject", ""))
		var field: String = str(row.get("field", ""))
		var parameter: String = str(row.get("parameter", ""))
		var value: String = str(row.get("value", ""))
		if not candidate.powers.has(power) or not row.get("outcome", "") in ["always", "deep_success", "success", "failure", "disaster"]: issues.append("Invalid power effect identity/outcome: " + str(row.id)); continue
		outcomes[power + "/" + row.outcome] = true
		if not parameter.is_empty() and (not values.has(parameter) or not value.is_empty()): issues.append("Invalid effect parameter reference: " + str(row.id)); continue
		var amount: int = 0
		if operation in numeric:
			if parameter.is_empty() and not value.is_valid_int(): issues.append("Invalid numeric effect: " + str(row.id)); continue
			if not parameter.is_empty() and float(values[parameter]) != float(int(values[parameter])): issues.append("Noninteger numeric effect parameter: " + str(row.id)); continue
			amount = int(values[parameter]) if not parameter.is_empty() else int(value)
		var valid: bool = false
		match operation:
			"delta":
				match subject:
					"actor": valid = field in ATTRIBUTES + ["sanity", "loyalty"] or (field == "selected_attribute" and power == "POWER_BESTOW")
					"domain", "source_domain", "target_domain": valid = field in ["alert", "pollution", "barrier", "followers"] and (subject == "domain" or power == "POWER_TRANSFER")
					"cult": valid = field == "cohesion" or (field == "cohesion_loss" and power == "POWER_SACRIFICE" and amount >= 0)
					"global": valid = field == "wounds" or (power == "POWER_SACRIFICE" and field in ["faith_base", "faith_per_rank", "insight", "wound_recovery"] and amount >= 0)
			"grant_preparation": valid = power == "POWER_ORACLE" and subject == "actor" and field == "preparation" and amount > 0
			"reveal": valid = power == "POWER_LISTEN" and subject == "actor" and field == "fact" and value.is_empty() and parameter.is_empty()
			"appoint": valid = power == "POWER_APPOINT" and subject == "actor" and field == "office" and value == "next_start" and parameter.is_empty()
			"sacrifice": valid = power == "POWER_SACRIFICE" and row.outcome == "always" and subject == "actor" and field == "status" and value == "dead" and parameter.is_empty()
			"anchor": valid = power == "POWER_ANCHOR" and subject == "anchor" and field == "state" and value == "dormant" and parameter.is_empty()
			"invalidate_evidence": valid = power == "POWER_VEIL" and row.outcome == "always" and subject == "domain" and field == "evidence" and value.is_empty() and parameter.is_empty()
			"migrate": valid = power == "POWER_TRANSFER" and subject == "actor" and field == "escort_limit" and amount >= 0
			"detain": valid = power == "POWER_TRANSFER" and subject == "actor" and field == "duration" and amount > 0
			"seal": valid = power == "POWER_ANCHOR" and subject == "relic" and field == "duration" and amount > 0
			"set": valid = power == "POWER_MANIFEST" and subject == "anchor" and field == "state" and value == "dormant" and parameter.is_empty()
			"manifest_complete": valid = power == "POWER_MANIFEST" and subject == "global" and field == "awakening" and parameter == "awakening_terminal" and value.is_empty()
		if not valid: issues.append("Unsupported power operation/subject/field combination: " + str(row.id))
	for id: String in candidate.powers:
		var required: Array = ["success"] if candidate.powers[id].check_kind == "deterministic" else ["deep_success", "success", "failure", "disaster"]
		for outcome: String in required:
			if not outcomes.has(id + "/" + outcome): issues.append("Power lacks executable outcome: " + id + "/" + outcome)
	if candidate.relic_effects.size() != candidate.relics.size(): issues.append("Relic effects must cover every authored relic exactly once")
	for id: String in candidate.relics:
		if not candidate.relic_effects.has(id): issues.append("Missing relic effect: " + id)
		for field: String in ["faith_disassembly", "insight_disassembly", "follower_gift", "whisper_release"]:
			var value: String = str(candidate.relics[id].get(field, ""))
			if not value.is_valid_int() or int(value) < 0: issues.append("Invalid nonnegative relic conversion: " + id + "/" + field)
	for id: String in candidate.relic_effects:
		var row: Dictionary = candidate.relic_effects[id]
		if not candidate.relics.has(id): issues.append("Unknown relic effect type: " + id)
		var numbers: bool = true
		for field: String in ["preparation", "carry_delta", "release_alert"]:
			if not str(row.get(field, "")).is_valid_int(): issues.append("Invalid relic effect integer: " + id + "/" + field); numbers = false
		if not numbers: continue
		if int(row.preparation) < 0 or int(row.release_alert) < 0: issues.append("Negative relic preparation or release alert: " + id)
		var subject: String = str(row.get("carry_subject", "")); var field: String = str(row.get("carry_field", ""))
		var valid: bool = (subject in ["actor", "holder"] and field == "sanity" and int(row.carry_delta) <= 0) or (subject == "domain" and field == "alert" and int(row.carry_delta) >= 0) or (subject == "cult" and field == "cohesion" and int(row.carry_delta) <= 0)
		if not valid: issues.append("Unsupported relic carrying cost: " + id)
		var seen: Dictionary = {}
		for power: String in str(row.get("powers", "")).split("|"):
			if not candidate.powers.has(power) or seen.has(power): issues.append("Unknown or repeated relic preparation power: " + id)
			seen[power] = true
	return issues
