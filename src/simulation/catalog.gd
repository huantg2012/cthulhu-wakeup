extends RefCounted
const AnchorRoutes = preload("res://src/game/anchor_routes.gd")
const SocialGraph = preload("res://src/simulation/social_graph.gd")
## The authored CSV catalog is the only source of gameplay values.
## Loading is transactional: malformed content never replaces an existing catalog.

const ATTRIBUTES: Array[String] = ["will", "insight", "influence", "adaptation"]
const FILES: Array[String] = [
	"npc_profiles", "civilization_profiles", "civilization_conditions", "civilization_parameters", "run_parameters",
	"npc_behaviors", "simulation_parameters", "civilization_actions", "resistance_plans", "event_parameters",
]
const EXTENSIONS: Array[String] = ["powers", "power_effects", "relics", "relic_effects", "prayers", "prayer_facts", "prayer_effects", "events", "event_effects", "anchor_conditions", "anchor_restrictions", "event_sources", "event_operations", "prayer_addressing_modes", "prayer_knowledge_rules", "prayer_origin_rules", "prayer_root_rules", "cult_spread_conditions", "cult_spread_routes", "player_source_rules", "social_graph_parameters", "social_relation_types", "anchor_route_rules", "foundation_route_parameters", "memory_contract_route_parameters", "material_transfer_families", "material_transfer_parameters", "material_transfer_rules", "progression_route_operations", "progression_routes", "progression_opportunity_goals", "opportunity_parameters"]
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
		if name == "npc_profiles": candidate_extensions[name] = content.sha256_text()
		if name in EXTENSIONS: candidate_extensions[name] = content.sha256_text()
		else: digest_input += content
		file.seek(0)
		var headers: PackedStringArray = file.get_csv_line()
		var key_field: String = "profile_id" if name in ["civilization_conditions", "anchor_conditions", "cult_spread_conditions"] else ("relic_id" if name == "relic_effects" else ("prayer_id" if name in ["prayer_facts", "prayer_origin_rules"] else ("event_id" if name in ["event_effects", "anchor_restrictions", "event_sources"] else "id")))
		if name == "event_sources" and Array(headers) != ["event_id", "producer", "source_kind", "source_tag", "object_schema", "eligibility_a", "eligibility_b", "invalid_policy"]:
			errors.append("Invalid event source schema")
			continue
		if name == "event_operations" and Array(headers) != ["id", "event_id", "option", "operation", "subject", "field", "value", "parameter", "condition"]:
			errors.append("Invalid executable event schema")
			continue
		if name == "anchor_restrictions" and Array(headers) != ["event_id", "option", "reason"]:
			errors.append("Invalid institution restriction schema")
			continue
		if name == "event_effects" and Array(headers) != ["event_id", "option", "faith_cost", "eligibility", "on_choose", "irreversible_cost", "status"]:
			errors.append("Invalid institution event option schema")
			continue
		if name == "anchor_conditions" and Array(headers) != ["profile_id", "rule", "event_id", "event_option", "count_parameter", "alive_parameter", "alive_min"]:
			errors.append("Invalid institution condition schema")
			continue
		if name == "prayer_effects" and Array(headers) != ["id", "prayer_id", "variant", "stage", "operation", "subject", "field", "value", "parameter", "condition", "scale"]:
			errors.append("Invalid prayer executable schema")
			continue
		var schemas: Dictionary = {
			"prayer_addressing_modes": "id,requires_identity_knowledge,intent_rule,selection_rule,devotion_title,devotion_text",
			"prayer_knowledge_rules": "id,producer,source_rule,recipient_rule,output",
			"prayer_origin_rules": "prayer_id,need,root_rule,root_kind,petitioner_rule,producer_task,addressing_modes,exclusive_group",
			"prayer_root_rules": "id,phase,rule,product_kind,deadline_rule,producer_task",
			"cult_spread_conditions": "profile_id,rule,count_parameter,alive_parameter,alive_min",
			"cult_spread_routes": "id,kind,producer,source_kind,population_scope,requires_profile_for_seed",
			"player_source_rules": "id,rule,source_kind,tag,selector",
			"social_graph_parameters": "id,value,unit,rationale",
			"foundation_route_parameters": "id,value,unit,rationale",
			"memory_contract_route_parameters": "id,value,unit,rationale",
			"anchor_route_rules": "id,profile,rule,selector,required,optional,count_parameter,count,turn_parameter,turns,alive_parameter,alive_min,spread_alive_parameter",
			"material_transfer_families": "id,selector,normalization,knowledge,custody,preserve_identity,route_guard,runtime_status",
			"material_transfer_parameters": "id,value,unit,rationale,runtime_status",
			"material_transfer_rules": "id,entry,phase,channel_rule,cost_rule,focus_scope,person_scope,executor_rule,responds,used_power,used_relic,runtime_status",
			"progression_route_operations": "id,mode,cost_rule,check_rule,minimum_turn_gap,success_pollution,always_alert,always_sanity_loss,participants_max,repeat_turns,runtime_status,rationale",
			"social_relation_types": "id,direction,initial_weight,initial_rule,initial_need_tags,coexists_with,duplicate_policy,retirement_rule,knowledge_rule",
			"progression_routes": "id,goal_id,profile,branch,entry_ids,material_rule,delivery_mode,delivery_bound,producer_task,coordination_task,consumer_task,runtime_status",
			"progression_opportunity_goals": "id,milestone,instance_scope,profile_id,completion_rule,route_design_task,runtime_status",
			"opportunity_parameters": "id,value,unit,rationale"}
		if schemas.has(name) and headers != str(schemas[name]).split(","):
			errors.append("Invalid schema: " + name)
			continue

		if headers.is_empty() or headers[0] != key_field or Array(headers).size() != _unique(Array(headers)).size():
			errors.append("Invalid header: " + name)
			continue
		var records: Dictionary = {}
		while not file.eof_reached():
			var cells: PackedStringArray = file.get_csv_line()
			if cells.size() == 1 and cells[0].is_empty():
				continue
			var record_key: String = cells[0]
			if name in ["event_effects", "anchor_restrictions"] and cells.size() == headers.size(): record_key += "/" + cells[1]
			if cells.size() != headers.size() or cells[0].is_empty() or records.has(record_key):
				errors.append("Invalid row or duplicate ID: " + name + " " + str(cells))
				continue
			var row: Dictionary = {}
			for index: int in headers.size():
				row[headers[index]] = cells[index]
			records[record_key] = row
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
		errors.append_array(_validate_anchor_routes(candidate, candidate_parameters))
		errors.append_array(_validate_material_transfer(candidate, candidate_parameters))
		errors.append_array(_validate_progression_operations(candidate))
		errors.append_array(_validate_opportunity_indexes(candidate, candidate_parameters))
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

func _validate_opportunity_indexes(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var goals: Dictionary = candidate.get("progression_opportunity_goals", {})
	var routes: Dictionary = candidate.get("progression_routes", {})
	if goals.size() != 10 or routes.size() != 20: issues.append("Incomplete coordinated opportunity indexes")
	if values.get("policy_version") != 1 or values.get("minimum_action_windows") != 1: issues.append("Unsupported direct opportunity policy/window")
	for row: Dictionary in goals.values():
		if row.runtime_status != "coordinated" or not row.instance_scope in ["run", "institution"]: issues.append("Invalid coordinated goal: " + str(row.id))
	for row: Dictionary in routes.values():
		if not goals.has(row.goal_id) or row.runtime_status != "coordinated" or row.delivery_mode != "direct_action" or row.delivery_bound != "0": issues.append("Invalid coordinated direct route: " + str(row.id))
		for entry: String in str(row.entry_ids).split("|", false):
			if entry.begins_with("ROUTE_") and not candidate.progression_route_operations.has(entry): issues.append("Missing coordinated operation: " + entry)
	return issues

func _validate_progression_operations(candidate: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var modes: Array = ["guided_dream", "axiom_probe", "axiom_recheck", "axiom_repeat", "network_exchange", "private_devotion", "joint_work", "covert_gathering", "calendar_rite", "record_practice", "calendar_keeping", "ritual_transmission", "memory_circle", "memory_practice", "dissent_practice", "pact_agreement", "pact_performance", "reciprocal_covenant"]
	var seen: Array = []
	for row: Dictionary in candidate.get("progression_route_operations", {}).values():
		if not row.mode in modes or row.mode in seen or row.runtime_status != "implemented": issues.append("Unsupported progression operation: " + str(row.id))
		seen.append(row.mode)
		for field: String in ["minimum_turn_gap", "success_pollution", "always_alert", "always_sanity_loss", "participants_max", "repeat_turns"]:
			if not str(row[field]).is_empty() and (not str(row[field]).is_valid_int() or int(row[field]) < 0): issues.append("Invalid progression parameter: " + str(row.id) + "/" + field)
	if seen.size() != modes.size(): issues.append("Incomplete finite progression operations")
	return issues

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
	var required: Array[String] = ["contract_scene_weight", "contract_scene_cooldown", "exception_scene_weight", "exception_scene_cooldown", "memory_scene_weight", "memory_scene_cooldown", "conflict_scene_weight", "conflict_scene_cooldown", "rescue_scene_weight", "rescue_scene_cooldown", "npc_attribute_min", "npc_attribute_max", "attribute_max", "domains_total", "planet_domains", "system_domains", "cosmic_domains", "initial_named_per_domain", "institutions_per_domain", "living_named_global_limit", "domain_population", "domain_population_capacity", "autonomous_actions_per_npc", "autonomous_recovery_threshold", "evidence_confirmation_strength", "growth_distinct_sources_per_point", "growth_attribute_increment", "institution_successor_min_sanity", "interpretation_public_alert", "initial_generic_relation_count", "check_base", "check_attribute_step", "check_probability_min", "check_probability_max", "check_preparation_limit", "check_barrier_divisor", "check_alert_divisor", "check_critical_divisor", "check_planet_difficulty", "check_system_difficulty", "check_cosmic_difficulty", "loyalty_follower_threshold", "pollution_base_decay", "alert_quiet_decay", "barrier_base_recovery", "first_breach_threshold", "whisper_growth_step", "whisper_base", "whisper_cap", "initial_faith", "initial_insight", "initial_wounds", "initial_awakening", "awakening_before_final_cap", "cult_succession_cohesion_cost", "sanity_stable_threshold", "sanity_fractured_threshold", "major_event_limit", "prayer_response_limit", "faith_capacity_base", "faith_capacity_per_peak_awakening"]
	required.append_array(["cult_form_local_spend", "cult_form_followers", "cult_form_loyalty", "cult_initial_cohesion", "cult_dormant_max_turns", "cult_replace_leader_cohesion_cost"])
	required.append_array(["cult_income_cap", "cult_natural_attrition", "expansion_faith_cost", "expansion_base_growth", "expansion_influence_divisor", "expansion_alert", "conceal_income_multiplier", "conceal_alert", "anchor_followers_min", "anchor_cohesion_min"])
	for key: String in ["exception_scene_weight", "exception_scene_cooldown", "memory_scene_weight", "memory_scene_cooldown", "conflict_scene_weight", "conflict_scene_cooldown", "rescue_scene_weight", "rescue_scene_cooldown"]:
		if not values.has(key) or values[key] < 1 or values[key] != int(values[key]): issues.append("Invalid rescue scene parameter: " + key)
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
	if int(values.autonomous_actions_per_npc) != 1 or int(values.institutions_per_domain) != 3:
		issues.append("Unsupported action/institution count")
	if not str(candidate.simulation_parameters.initial_generic_relation_count.value).is_valid_int() or float(values.initial_generic_relation_count) < 0:
		issues.append("Invalid deprecated initial relation count")
	issues.append_array(SocialGraph.validate_catalog(candidate))
	for power: Dictionary in candidate.powers.values():
		for field: String in ["whispers", "faith", "unlock_awakening", "cooldown_turns"]:
			if not power.get(field, "").is_valid_int() or int(power[field]) < 0: issues.append("Invalid power cost/threshold: " + str(power.id))
		if not power.get("check_kind", "") in ["deterministic", "social", "occult"] or (power.check_kind != "deterministic" and not power.get("attribute", "") in ATTRIBUTES): issues.append("Invalid power check grammar")
	issues.append_array(_validate_power_grammar(candidate, values))
	issues.append_array(_validate_anchor_grammar(candidate, values))
	issues.append_array(_validate_event_grammar(candidate, values))
	issues.append_array(_validate_prayer_grammar(candidate, values))
	issues.append_array(_validate_source_grammar(candidate, values))
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

func _validate_prayer_grammar(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var branches: Dictionary = {}
	var signatures: Dictionary = {
		"delta": {"domain": ["pollution", "followers", "alert", "barrier", "stability"], "petitioner": ["sanity", "sanity_loss", "loyalty"], "relative": ["sanity"], "memory_people": ["sanity"], "actor": ["sanity_loss"]},
		"set_min": {"petitioner": ["loyalty"]}, "cure": {"relative": ["condition"]},
		"record": {"relative": ["miracle_witness"], "institution": ["private_testimony", "anomaly_record", "ritual_witness", "public_ritual", "orthodoxy_question", "contract_dependency", "anomaly_evidence", "public_evidence", "exception_record"], "petitioner": ["public_witness", "lost_anonymity", "investigation_candidate", "contract_witness", "public_prophet", "missing_risk", "relationship_exposed"], "second": ["investigation_candidate"], "counterparty": ["hostile_witness"], "memory_people": ["memory_conflict"], "opponent": ["hostility"], "other_institution": ["public_exception_qualification"]},
		"learn": {"rival": ["testimony"], "second": ["record"], "counterparty": ["contract"], "petitioner": ["relation", "relic_holder"], "other_institution": ["exception"]},
		"withdraw": {"petitioner": ["pursuit_clue", "pursuit_relation"], "institution": ["support"]}, "restrict": {"petitioner": ["spread", "appoint"]},
		"conceal": {"petitioner": ["duration"]}, "vacate": {"petitioner": ["office"]}, "fulfill": {"petitioner": ["contract"]},
		"memory": {"memory_people": ["first", "all"]}, "enroll": {"petitioner": ["member"]}, "route": {"petitioner": ["escape"]},
		"recovery": {"relic": ["opportunity"]}, "close": {"request": ["window", "pursuit_window", "evidence_window", "ritual_window", "devotion_contact", "route_window", "relic_claim", "exception_window"]},
		"succeed": {"rival": ["institution_representative"]}, "kill_if_dying": {"relative": ["condition"]}, "drop_memory": {"memory_people": ["unpreserved"]},
		"close_cooperation": {"petitioner": ["contract"]}, "settle_dispute": {"institution": ["default_stance"]}, "callback": {"request": ["future_event"]}}
	var operations: Array[String] = ["delta", "set_min", "cure", "record", "learn", "withdraw", "restrict", "conceal", "vacate", "fulfill", "memory", "enroll", "route", "recovery", "close", "succeed", "kill_if_dying", "drop_memory", "close_cooperation", "settle_dispute", "callback"]
	var subjects: Array[String] = ["actor", "petitioner", "relative", "rival", "pursuer", "second", "counterparty", "memory_people", "institution", "other_institution", "domain", "request", "relic", "opponent"]
	for id: String in candidate.prayers:
		var row: Dictionary = candidate.prayers[id]
		if not str(row.get("lifetime", "")).is_valid_int() or int(row.lifetime) < 1: issues.append("Invalid prayer request lifetime: " + id)
		if not candidate.prayer_facts.has(id): issues.append("Missing prayer fact semantics: " + id)
	for id: String in candidate.prayer_facts:
		if not candidate.prayers.has(id): issues.append("Unknown prayer fact semantics: " + id)
	for id: String in candidate.prayer_effects:
		var row: Dictionary = candidate.prayer_effects[id]
		var prayer: String = str(row.get("prayer_id", ""))
		if prayer != "*" and not candidate.prayers.has(prayer): issues.append("Unknown prayer effect content: " + id)
		if not row.get("variant", "") in ["shallow", "deep", "both"] or not row.get("stage", "") in ["always", "success", "expiry", "disaster"] or not row.get("operation", "") in operations or not row.get("subject", "") in subjects or not row.get("condition", "") in ["all", "subject_alive", "knows_disclosure"] or not row.get("scale", "") in ["none", "count"]: issues.append("Unsupported prayer effect grammar: " + id); continue
		if row.subject == "actor" and (prayer != "*" or row.stage != "disaster" or row.operation != "delta" or row.field != "sanity_loss"): issues.append("Actor is reserved for the shared prayer disaster cost: " + id)
		if not signatures.get(row.operation, {}).has(row.subject) or not row.get("field", "") in signatures.get(row.operation, {}).get(row.subject, []): issues.append("Unsupported prayer operation/subject/field: " + id)
		var parameter: String = str(row.get("parameter", ""))
		var value: String = str(row.get("value", ""))
		if not parameter.is_empty() and (not values.has(parameter) or not value.is_empty()): issues.append("Invalid prayer parameter reference: " + id)
		if row.operation in ["callback", "recovery"] and not candidate.events.has(value): issues.append("Unknown prayer event reference: " + id)
		if row.operation == "callback" and (prayer == "*" or candidate.prayers.get(prayer, {}).get("callback_event") != value): issues.append("Prayer callback disagrees with content: " + id)
		if row.scale == "count" and not row.field in ["pollution", "followers", "loyalty", "barrier"]: issues.append("Unsupported scaled prayer quantity: " + id)
		if row.operation in ["delta", "set_min"]:
			if parameter.is_empty() and not value.is_valid_int(): issues.append("Invalid numeric prayer effect: " + id)
			if not parameter.is_empty() and values.has(parameter) and float(values[parameter]) != float(int(values[parameter])): issues.append("Noninteger prayer delta: " + id)
		if row.scale == "count" and (row.stage != "success" or row.operation != "delta"): issues.append("Only direct success quantities may scale: " + id)
		if row.stage == "success" and prayer != "*":
			if row.variant == "both": branches[prayer + "/shallow"] = true; branches[prayer + "/deep"] = true
			else: branches[prayer + "/" + row.variant] = true
	for prayer: String in candidate.prayers:
		for variant: String in ["shallow", "deep"]:
			if not branches.has(prayer + "/" + variant): issues.append("Prayer lacks executable success branch: " + prayer + "/" + variant)
	for key: String in ["prayer_shallow_whispers", "prayer_shallow_faith", "prayer_deep_whispers", "prayer_deep_faith", "prayer_shallow_pollution", "prayer_deep_pollution", "prayer_disaster_sanity_loss", "prayer_disaster_alert"]:
		if not values.has(key) or float(values[key]) < 0 or float(values[key]) != float(int(values[key])): issues.append("Invalid prayer budget: " + key)
	if not values.has("prayer_deep_success_multiplier") or float(values.prayer_deep_success_multiplier) < 1: issues.append("Invalid prayer success scaling")
	for id: String in candidate.events:
		var event: Dictionary = candidate.events[id]
		if not str(event.get("min_age", "")).is_valid_int() or not str(event.get("max_age", "")).is_valid_int() or int(event.min_age) < 0 or int(event.max_age) < int(event.min_age): issues.append("Invalid referenced event age window: " + id)
	return issues

func _validate_anchor_grammar(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	for key: String in candidate.event_effects:
		var event_option: Dictionary = candidate.event_effects[key]
		if not candidate.events.has(event_option.event_id) or not event_option.option in ["A", "B"] or key != event_option.event_id + "/" + event_option.option: issues.append("Invalid institution event option reference: " + key)
		if not event_option.status in ["active", "retired"] or (event_option.status == "retired") != (key == "EVENT_04/A"): issues.append("Unsupported event option status: " + key)
		if not event_option.faith_cost.is_valid_int() or int(event_option.faith_cost) < 0: issues.append("Invalid referenced event option cost: " + key)
	for event: String in candidate.events:
		for option: String in ["A", "B"]:
			if not candidate.event_effects.has(event + "/" + option): issues.append("Missing referenced event option: " + event + "/" + option)
	# Only these authored option effects implement institution-wide denial.
	# Other effect kinds need a separate execution contract before extending CSV.
	var restriction_signatures: Dictionary = {}
	if candidate.anchor_restrictions.size() != restriction_signatures.size(): issues.append("Incomplete institution restriction effect grammar")
	for key: String in candidate.anchor_restrictions:
		var restriction: Dictionary = candidate.anchor_restrictions[key]
		if not candidate.event_effects.has(key) or key != restriction.event_id + "/" + restriction.option or restriction_signatures.get(key) != restriction.reason: issues.append("Unsupported institution restriction effect: " + key)
	var rules: Array[String] = ["dual_testimony", "calendar_ritual", "shared_memory", "orthodox_witness", "network_evidence", "contract_dependency", "axiom_exception", "collective_dissent"]
	if candidate.anchor_conditions.size() != candidate.civilization_profiles.size(): issues.append("Institution conditions must cover every civilization profile")
	# These are supported proof grammars, not a second copy of their counts.
	var signatures: Dictionary = {
		"dual_testimony": ["", "", "testimony_required_witnesses", "testimony_required_witnesses", false],
		"calendar_ritual": ["", "", "ritual_required_turns", "", false],
		"shared_memory": ["", "", "collective_required_witnesses", "collective_required_witnesses", false],
		"orthodox_witness": ["", "", "", "", false],
		"network_evidence": ["", "", "", "", false],
		"contract_dependency": ["", "", "", "", false],
		"axiom_exception": ["", "", "", "", false],
		"collective_dissent": ["", "", "collective_required_witnesses", "", true],
	}
	var used: Dictionary = {}
	for profile: String in candidate.civilization_profiles:
		if not candidate.anchor_conditions.has(profile): issues.append("Missing institution condition: " + profile)
	for profile: String in candidate.anchor_conditions:
		var row: Dictionary = candidate.anchor_conditions[profile]
		if not candidate.civilization_profiles.has(profile) or not row.rule in rules or used.has(row.rule): issues.append("Unknown or duplicate institution condition rule: " + profile)
		used[row.rule] = true
		if signatures.has(row.rule):
			var signature: Array = signatures[row.rule]
			if [row.event_id, row.event_option, row.count_parameter, row.alive_parameter, not row.alive_min.is_empty()] != signature: issues.append("Unsupported institution proof grammar: " + profile)
		if not row.event_id.is_empty() or not row.event_option.is_empty(): issues.append("Invalid institution event reference: " + profile)
		for field: String in ["count_parameter", "alive_parameter"]:
			var parameter: String = row[field]
			if not parameter.is_empty() and (not values.has(parameter) or float(values[parameter]) < 1 or float(values[parameter]) != float(int(values[parameter]))): issues.append("Invalid institution count parameter: " + profile + "/" + field)
		if not row.alive_min.is_empty() and (not row.alive_min.is_valid_int() or int(row.alive_min) < 1): issues.append("Invalid institution living minimum: " + profile)
		if not row.alive_parameter.is_empty() and not row.alive_min.is_empty(): issues.append("Institution living minimum has two sources: " + profile)
		if row.rule in ["dual_testimony", "calendar_ritual", "shared_memory", "collective_dissent"] and row.count_parameter.is_empty(): issues.append("Institution rule requires its authored count: " + profile)
		if row.rule in ["dual_testimony", "shared_memory", "collective_dissent"] and row.alive_parameter.is_empty() and row.alive_min.is_empty(): issues.append("Institution rule requires living witnesses: " + profile)
	return issues

func _validate_event_grammar(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var producers: Array = ["prayer_callback", "record_callback", "resistance_plan", "prayer_expiry"]
	var source_kinds: Array = ["prayer_fact", "miracle", "resistance_started", "prayer_window_due"]
	var source_tags: Array = ["future_callback", "evidence_or_public", "dream", "RESIST_TRACE", "RESIST_SEIZE", "RESIST_REWRITE", "unanswered"]
	var schemas: Array = ["survivor", "evidence_bundle", "vacant_office", "ritual_authority", "contract_ends", "shared_memory", "prophet_dispute", "exposed_medium", "faction_conflict", "seized_relic", "original_rewrite", "expired_request"]
	var eligibility: Array = ["survivor_alive", "secret_record_current", "public_proof", "cooperative_successor", "vacancy", "current_witness_priest", "heretic_or_deny", "contract_current", "obligor_or_current_successor", "living_original_witness", "prophet_or_fixed_legacy", "movable_medium", "investigation_target_current", "cooperative_material_endpoint", "always", "custody_current", "original_plan_record", "original_plan_valid", "petitioner_alive", "reopen_original"]
	var invalid_policy: Array = ["fixed_survivor_or_end", "keep_records_disable_dead_branch", "filled_office_end", "lost_institution_archive", "selected_successor_or_release", "no_living_witness_end", "fixed_will_or_end", "original_institution_recheck", "resolved_conflict_archive", "changed_custody_end", "invalid_target_cancel_no_retarget", "dead_petitioner_archive"]
	if candidate.event_sources.size() != candidate.events.size(): issues.append("Event source rules must cover every event")
	for event: String in candidate.events:
		if not candidate.event_sources.has(event): issues.append("Missing event source rule: " + event)
		var default_option: String = str(candidate.events[event].get("default_result", "")).trim_prefix("option:")
		if not candidate.event_effects.has(event + "/" + default_option) or int(candidate.event_effects[event + "/" + default_option].faith_cost) != 0 or candidate.event_effects[event + "/" + default_option].status != "active": issues.append("Mandatory event default must be a real zero-cost option: " + event)
	for event: String in candidate.event_sources:
		var row: Dictionary = candidate.event_sources[event]
		if not candidate.events.has(event) or not row.object_schema in schemas or (not row.eligibility_a in eligibility and not (event == "EVENT_04" and row.eligibility_a.is_empty())) or not row.eligibility_b in eligibility or not row.invalid_policy in invalid_policy: issues.append("Unsupported fixed event object or eligibility: " + event)
		for field: String in ["producer", "source_kind", "source_tag"]:
			var supported: Array = producers if field == "producer" else (source_kinds if field == "source_kind" else source_tags)
			var parts: Array = Array(str(row[field]).split("|"))
			if parts.is_empty() or parts.size() != _unique(parts).size(): issues.append("Empty or repeated event source grammar: " + event)
			for part: String in parts:
				if not part in supported: issues.append("Unknown event source grammar: " + event + "/" + field)
	var signatures: Dictionary = {
		"record": ["survivor/ordinary_life", "survivor/mutated", "institution/private_records", "cooperator/favor_owed", "heretic/heterodox_spread", "obligor/hostile_witness", "relic/custody_retained", "petitioner/departed", "institution/office_changed", "institution/interpretation_rejected"],
		"publish": ["survivor/miracle", "institution/records"],
		"succeed": ["cooperator/institution", "opponent/institution"],
		"release_contract": ["institution/dependency"], "retain_dependency": ["institution/EVENT_05"], "preserve_memory": ["institution/EVENT_06"],
		"drop_memory": ["witnesses/selected_qualification"], "close": ["institution/memory_dispute", "institution/cooperation_opportunity", "relic/recovery_opportunity", "petitioner/request"],
		"prophet": ["prophet/correct", "prophet/allow"], "move_medium": ["relic/local_store"], "evidence": ["institution/target"],
		"open_route": ["cooperator/covert_channel"], "relation": ["opponent/hostile", "institution/hostile"], "recover_relic": ["relic/local_store"],
		"erase_record": ["institution/selected_record"], "cancel_plan": ["plan/investigation", "plan/rewrite"], "resolve_plan": ["plan/rewrite"],
		"leave": ["petitioner/member"], "reopen": ["petitioner/request"]}
	var deltas: Array = ["survivor/sanity", "global/faith", "global/wounds", "domain/alert", "domain/stability", "domain/pollution", "domain/followers", "cult/cohesion", "prophet/loyalty", "petitioner/loyalty"]
	var covered: Dictionary = {}
	for id: String in candidate.event_operations:
		var row: Dictionary = candidate.event_operations[id]
		if not candidate.events.has(row.event_id) or not row.option in ["A", "B"] or not row.condition in ["all", "heretic_exists", "opponent_exists", "was_member"]: issues.append("Invalid event operation branch or condition: " + id)
		var pair: String = row.subject + "/" + row.field
		var numeric: bool = row.operation == "delta" or (row.operation == "prophet" and row.field == "allow")
		if row.operation == "delta":
			if not pair in deltas: issues.append("Unsupported event delta: " + id)
		elif not signatures.has(row.operation) or not pair in signatures[row.operation]: issues.append("Unsupported event operation: " + id)
		if numeric:
			if row.parameter.is_empty():
				if not row.value.is_valid_int(): issues.append("Invalid event numerical effect: " + id)
			elif not row.value.is_empty() or not values.has(row.parameter) or float(values[row.parameter]) != float(int(values[row.parameter])): issues.append("Invalid event parameter reference: " + id)
		elif not row.value.is_empty() or not row.parameter.is_empty(): issues.append("Nonnumerical event effect cannot smuggle a value: " + id)
		covered[row.event_id + "/" + row.option] = true
	for event: String in candidate.events:
		for option: String in ["A", "B"]:
			if candidate.event_effects.get(event + "/" + option, {}).get("status") == "retired":
				if covered.has(event + "/" + option): issues.append("Retired option has executable effects")
				continue
			if not covered.has(event + "/" + option): issues.append("Event lacks executable option: " + event + "/" + option)
	return issues

## Syntax support is not an execution capability. Consumers must version-gate
## their own implementations; these rows alone never register a producer.
func _validate_source_grammar(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var modes: Dictionary = {"undirected": ["0", "appeal_to_any_answerer"], "directed": ["1", "address_identified_entity"]}
	if candidate.prayer_addressing_modes.size() != modes.size(): issues.append("Incomplete addressing modes")
	for id: String in candidate.prayer_addressing_modes:
		var row: Dictionary = candidate.prayer_addressing_modes[id]
		if not modes.has(id) or [row.requires_identity_knowledge, row.intent_rule] != modes.get(id) or row.selection_rule != "stable_occurrence_choice" or row.devotion_title.is_empty() or row.devotion_text.is_empty(): issues.append("Unsupported addressing mode: " + id)
	var knowledge: Dictionary = {
		"KNOW_DREAM": ["powers", "successful_identified_dream", "actual_dream_recipient", "deity_identified"],
		"KNOW_ORACLE": ["powers", "successful_identified_oracle", "actual_oracle_recipient", "deity_identified"],
		"KNOW_DEVOTION": ["prayers", "successful_accepted_devotion", "original_petitioner", "deity_identified"],
		"KNOW_TELL": ["world", "current_specific_identity_notice", "one_existing_reachable_person", "deity_identity_received"]}
	if candidate.prayer_knowledge_rules.size() != knowledge.size(): issues.append("Incomplete knowledge grammar")
	for id: String in candidate.prayer_knowledge_rules:
		var row: Dictionary = candidate.prayer_knowledge_rules[id]
		if [row.producer, row.source_rule, row.recipient_rule, row.output] != knowledge.get(id, []): issues.append("Unsupported knowledge grammar: " + id)
	var roots: Dictionary = {
		"ROOT_INITIAL_TIES": "bootstrap/finite_initial_relationship/social_graph_generation|social_contact|initial_relationship/none/TASK-SOCIAL-GRAPH",
		"ROOT_INJURY": "4/current_kinship_rescue/dying_condition/first_possible_visible_plus_lifetime/TASK-SOURCE-LOCAL-TIES",
		"ROOT_DISPUTE": "4/current_dispute_scene/faction_conflict/first_possible_visible_plus_lifetime/TASK-SOURCE-LOCAL-CONFLICT",
		"ROOT_PURSUIT": "4/current_exposure_pursuit/pursuit_condition/first_possible_visible_plus_lifetime/TASK-SOURCE-LOCAL-CONFLICT",
		"ROOT_KNOWN_RECORD": "4/current_known_unexplained_record/record_source_view/source_validity/TASK-PRAYER-ORIGINS",
		"ROOT_CURRENT_RITUAL": "4/current_qualified_ritual/ritual_context/none/TASK-PRAYER-ORIGINS",
		"ROOT_CURRENT_PACT": "4/current_simple_obligation/contract_obligation/first_possible_visible_plus_lifetime/TASK-SOURCE-CONTRACT",
		"ROOT_SHARED_OBSERVATION": "4/current_shared_experience/shared_observation/none/TASK-SOURCE-MEMORY",
		"ROOT_MEMORY_REVIEW": "4/current_shared_memory_risk/memory_at_risk/first_possible_visible_plus_lifetime/TASK-SOURCE-MEMORY",
		"ROOT_CURRENT_APPEAL": "bootstrap|4/current_conditional_devotion/devotion_contact/none/TASK-PRAYER-ORIGINS",
		"ROOT_CURRENT_PASSAGE": "4/current_institution_passage/barrier_contact/none/TASK-PRAYER-ORIGINS",
		"ROOT_ACTUAL_SEIZURE": "4/actual_seizure_notice/message/source_validity/TASK-SOURCE-LOCAL-CONFLICT",
		"ROOT_COSMIC_OBSERVATION": "4/current_anomaly_observation/law_observation|exception/source_validity/TASK-SOURCE-EXCEPTION",
		"ROOT_IDENTITY_NOTICE": "4/current_specific_identity_notice/deity_identity_received/none/TASK-PRAYER-KNOWLEDGE"}
	if candidate.prayer_root_rules.size() != roots.size(): issues.append("Incomplete root grammar")
	for id: String in candidate.prayer_root_rules:
		var row: Dictionary = candidate.prayer_root_rules[id]
		if "/".join([row.phase, row.rule, row.product_kind, row.deadline_rule, row.producer_task]) != roots.get(id, ""): issues.append("Unsupported root grammar: " + id)
	var origins: Dictionary = {
		"rescue": "ROOT_INJURY/dying_condition/current_scene_relative",
		"recognition": "ROOT_DISPUTE/faction_conflict/current_dispute_party",
		"concealment": "ROOT_PURSUIT/pursuit_condition/actual_pursued_person",
		"knowledge": "ROOT_KNOWN_RECORD/exposure|exception|prayer_fact|miracle|law_observation/actual_record_knower",
		"belonging": "ROOT_CURRENT_RITUAL/ritual_context/actual_ritual_keeper",
		"obligation": "ROOT_CURRENT_PACT/contract_obligation/actual_obligor",
		"memory": "ROOT_MEMORY_REVIEW/memory_at_risk/current_scene_memory_holder",
		"devotion": "ROOT_CURRENT_APPEAL/devotion_contact/current_unbound_person",
		"escape": "ROOT_CURRENT_PASSAGE/barrier_contact/current_passage_person",
		"judgment": "ROOT_DISPUTE/faction_conflict/current_dispute_secret_party",
		"recovery": "ROOT_ACTUAL_SEIZURE/message/actual_previous_holder",
		"exception": "ROOT_COSMIC_OBSERVATION/exception/actual_cosmic_observer"}
	if candidate.prayer_origin_rules.size() != candidate.prayers.size(): issues.append("Incomplete prayer origins")
	for id: String in candidate.prayers:
		if not candidate.prayer_origin_rules.has(id): issues.append("Missing prayer origin: " + id)
	for id: String in candidate.prayer_origin_rules:
		var row: Dictionary = candidate.prayer_origin_rules[id]
		if not candidate.prayers.has(id) or row.need != candidate.prayers.get(id, {}).get("need") or "/".join([row.root_rule, row.root_kind, row.petitioner_rule]) != origins.get(row.need, ""): issues.append("Unsupported prayer origin: " + id)
		if not candidate.prayer_root_rules.has(row.root_rule) or row.producer_task != candidate.prayer_root_rules.get(row.root_rule, {}).get("producer_task"): issues.append("Invalid prayer root reference: " + id)
		if row.addressing_modes != "undirected|directed": issues.append("Invalid prayer addressing references: " + id)
		var exclusive: String = "conflict_petitioner" if row.need in ["recognition", "judgment"] else ""
		if row.exclusive_group != exclusive: issues.append("Invalid exclusive prayer group: " + id)
	var spread_rules: Array = ["dual_witness", "calendar_ritual", "shared_memory", "ritual_contacts", "network_evidence", "contract_dependency", "axiom_exception", "collective_dissent"]
	if candidate.cult_spread_conditions.size() != candidate.civilization_profiles.size(): issues.append("Incomplete cult conditions")
	var used: Array = []
	for id: String in candidate.cult_spread_conditions:
		var row: Dictionary = candidate.cult_spread_conditions[id]
		if not candidate.civilization_profiles.has(id) or not row.rule in spread_rules or row.rule in used: issues.append("Unsupported cult condition: " + id)
		used.append(row.rule)
		for field: String in ["count_parameter", "alive_parameter"]:
			if not row[field].is_empty() and (not values.has(row[field]) or float(values[row[field]]) < 1 or float(values[row[field]]) != float(int(values[row[field]]))): issues.append("Invalid cult parameter reference: " + id)
		if not row.alive_min.is_empty() and (not row.alive_min.is_valid_int() or int(row.alive_min) < 1 or not row.alive_parameter.is_empty()): issues.append("Invalid cult living minimum: " + id)
	var routes: Dictionary = {"COVERT_CELL": ["cell", "cults", "cult_established"], "ALLIED_CHANNEL": ["cooperation", "events", "event_result"]}
	if candidate.cult_spread_routes.size() != routes.size(): issues.append("Incomplete cult routes")
	for id: String in candidate.cult_spread_routes:
		var row: Dictionary = candidate.cult_spread_routes[id]
		if [row.kind, row.producer, row.source_kind] != routes.get(id, []) or row.population_scope != "local_unnamed_nonfollowers" or row.requires_profile_for_seed != "1": issues.append("Unsupported cult route: " + id)
	var selectors: Dictionary = {"current_member": ["dream", "member_enrolled|cult_member_joined"], "fixed_prayer_actor": ["dream", "prayer_fixed|background_fixed"], "barrier_subject": ["weakness", "barrier_contact|background_fixed"], "joined_member": ["tenure", "cult_member_joined"], "covert_spread_basis": ["spread", "economy_qualification"], "clue_fact": ["listen", "message"], "propagation_evidence": ["evidence", "prayer_fact"], "prayer_actor": ["witness|milestone", "prayer_fact"]}
	for id: String in candidate.player_source_rules:
		var row: Dictionary = candidate.player_source_rules[id]
		var signature: Array = selectors.get(row.selector, [])
		if signature.is_empty() or not row.rule in str(signature[0]).split("|") or not row.source_kind in str(signature[1]).split("|"): issues.append("Unsupported player source grammar: " + id)
		if not row.tag in ["", "public_witness", "public_evidence", "public_prophet"]: issues.append("Unsupported player source tag: " + id)
	return issues

## Finite consumer grammar only. Loading these rows does not install any of the
## later progression producers or actions.
func _validate_anchor_routes(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var counts: Dictionary = {}
	for id: String in candidate.get("anchor_route_rules", {}):
		var row: Dictionary = candidate.anchor_route_rules[id]
		if not candidate.anchor_conditions.has(row.profile) or row.rule != candidate.anchor_conditions.get(row.profile, {}).get("rule") or not row.selector in AnchorRoutes.SELECTORS or row.required.is_empty(): issues.append("Unsupported anchor route grammar: " + id)
		counts[row.profile] = int(counts.get(row.profile, 0)) + 1
		var fields: Array = Array(row.required.split("|", false)) + Array(row.optional.split("|", false))
		if fields.size() != _unique(fields).size() or "route" in fields or "carriers" in fields: issues.append("Repeated or reserved anchor basis key: " + id)
		for pair: Array in [["count_parameter", "count"], ["turn_parameter", "turns"], ["alive_parameter", "alive_min"]]:
			if not row[pair[1]].is_valid_int() or int(row[pair[1]]) < 0: issues.append("Invalid route count: " + id)
			if not row[pair[0]].is_empty() and (not values.has(row[pair[0]]) or float(values[row[pair[0]]]) < 1 or float(values[row[pair[0]]]) != float(int(values[row[pair[0]]]))): issues.append("Invalid route parameter reference: " + id)
		if not row.spread_alive_parameter.is_empty() and not values.has(row.spread_alive_parameter): issues.append("Invalid spread survival reference: " + id)
	for profile: String in candidate.anchor_conditions:
		if int(counts.get(profile, 0)) != 2: issues.append("Each civilization needs exactly two consumed routes: " + profile)
	return issues

func material_transfer_version() -> String:
	var parts: Array = ["material-reception/schema2", version]
	for name: String in ["material_transfer_families", "material_transfer_parameters", "material_transfer_rules"]: parts.append(str(extension_versions.get(name, "missing")))
	return "/".join(parts).sha256_text()

func _validate_material_transfer(candidate: Dictionary, values: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var families: Dictionary = candidate.get("material_transfer_families", {})
	if families.size() != 24: issues.append("Incomplete finite material families")
	var family_statuses: Dictionary = {
		"implemented": ["EVIDENCE", "DREAM", "RITUAL", "EXCEPTION", "MEMORY_QUALIFICATION", "MEMORY_CONFLICT", "CONTRACT_DEPENDENCY", "CONTRACT_WITNESS", "AXIOM_RECORD", "AXIOM_USE", "AXIOM_DEPENDENCY", "NETWORK_USE", "NETWORK_DEPENDENCY", "RECORD_PRACTICE", "CALENDAR_PRACTICE", "PERFORMED_RITE", "RITUAL_PRACTICE", "RECOLLECTION_PRACTICE", "DISSENT_PRACTICE", "RECIPROCAL_CONTRACT"],
		"design_only": [],
		"unsupported_material": ["ORDINARY_BACKGROUND", "DEITY_IDENTITY", "RELIC_INSTANCE", "PROPHET_OR_OFFICE"]}
	var selectors: Dictionary = {}
	for row: Dictionary in families.values():
		if not row.runtime_status in family_statuses or not row.id in family_statuses.get(row.runtime_status, []) or row.selector.is_empty() or selectors.has(row.selector) or not row.knowledge in ["0", "1"] or not row.custody in ["0", "1"] or (row.custody == "1" and row.knowledge != "1") or row.normalization.is_empty() or row.preserve_identity.is_empty() or row.route_guard.is_empty(): issues.append("Invalid finite material family: " + row.id)
		selectors[row.selector] = true
	for key: String in ["internal_faith_cost", "internal_whispers_cost", "materials_per_action", "participants_per_action", "receipt_schema"]:
		if not values.has(key) or values[key] < 0 or values[key] != int(values[key]): issues.append("Invalid material transfer parameter: " + key)
		if candidate.get("material_transfer_parameters", {}).get(key, {}).get("runtime_status") != "implemented": issues.append("Missing installed material parameter: " + key)
	if values.get("materials_per_action") != 1 or values.get("participants_per_action") != 2 or values.get("receipt_schema") != 2: issues.append("Unsupported material transfer cardinality/schema")
	var expected: Dictionary = {"INTERNAL_TRANSFER": ["cults/transfer_material", "actions", "same_continuous_cult_and_current_contact", "internal_parameters", "none", "participants", "none", "0", "0", "0"], "COOPERATION_09A": ["events/EVENT_09/A", "events", "actual_new_cooperative_endpoint", "original_EVENT_09_A_only", "original_event_policy", "participants", "original_event_policy", "0", "0", "0"], "ORIGINAL_RESULT": ["existing_declared_result", "original", "declared_recipient_and_actual_sender_possession", "original_result_only", "original_result_policy", "original_result_policy", "original_result_policy", "original_result_policy", "original_result_policy", "original_result_policy"]}
	var fields: Array = ["entry", "phase", "channel_rule", "cost_rule", "focus_scope", "person_scope", "executor_rule", "responds", "used_power", "used_relic"]
	var rules: Dictionary = candidate.get("material_transfer_rules", {})
	if rules.size() != expected.size(): issues.append("Incomplete material caller contracts")
	for id: String in expected:
		var row: Dictionary = rules.get(id, {})
		if row.is_empty() or row.get("runtime_status") != "implemented": issues.append("Missing material caller contract: " + id); continue
		for i: int in fields.size():
			if row.get(fields[i]) != expected[id][i]: issues.append("Unsupported material caller contract: " + id + "/" + fields[i])
	return issues
