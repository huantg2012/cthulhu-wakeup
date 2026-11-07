extends RefCounted
const WorldNames = preload("res://src/content/world_names.gd")
## Editorial text is never a rule input. Session freezes generated world names.
## Only these display fields may be overridden. Rule tables remain untouched.
const FIELDS := {
	"relics": ["name", "description", "carry_effect", "carry_cost", "anchor_role"],
	"npc_profiles": ["name"],
	"civilization_profiles": ["name", "entry_route", "spread_route", "anchor_route", "resistance_style"],
	"progression_route_operations": ["name", "description"],
	"events": ["title", "choice_a", "choice_b"],
	"prayers": ["title", "appeal", "shallow_hint", "deep_hint"], "prayer_facts": ["failure_fact"],
	"powers": ["name", "target_requirement", "notes"],
	"event_effects": ["on_choose", "irreversible_cost"],
	"resistance_plans": ["name"], "npc_behaviors": ["name"],
	"institutions": ["name"], "world_names": ["name", "cult_name"],
}
var tables: Dictionary = {}
var names: Array[Dictionary] = []
var errors: Array[String] = []
var world_names: RefCounted

func load_files(rules: Dictionary, directory: String) -> bool:
	errors.clear()
	var candidate: Dictionary = rules.duplicate(true)
	candidate["institutions"] = {}
	candidate["world_names"] = {}
	var file := FileAccess.open(directory.path_join("player_text.csv"), FileAccess.READ)
	if file == null:
		# Standalone rule fixtures predate editorial text and need no UI catalog.
		if directory != "res://data": tables = candidate; return true
		errors.append("Missing player_text.csv"); return false
	if file.get_csv_line() != PackedStringArray(["table", "key", "field", "text"]):
		errors.append("Invalid player text header"); return false
	var seen := {}
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != 4: errors.append("Invalid player text row"); continue
		var table: String = cells[0]; var key: String = cells[1]; var field: String = cells[2]
		var identity: String = table + "/" + key + "/" + field
		var valid: bool = FIELDS.has(table) and field in FIELDS.get(table, []) and not cells[3].strip_edges().is_empty() and not seen.has(identity)
		if table == "world_names":
			valid = valid and key.begins_with("DOMAIN-") and key.trim_prefix("DOMAIN-").is_valid_int() and int(key.trim_prefix("DOMAIN-")) in range(1, int(rules.civilization_parameters.domains_total.value) + 1)
		elif table == "institutions":
			valid = valid and rules.civilization_profiles.has(key.get_slice("/", 0)) and key.get_slice("/", 1) in ["interpretation", "propagation", "order"]
		else: valid = valid and rules.get(table, {}).has(key)
		if not valid: errors.append("Invalid player text key: " + identity); continue
		seen[identity] = true
		if not candidate[table].has(key): candidate[table][key] = {}
		candidate[table][key][field] = cells[3]
	var world_labels := {}; var cult_labels := {}
	for entry: Dictionary in candidate.world_names.values():
		if not entry.has("name") or not entry.has("cult_name") or world_labels.has(entry.get("name")) or cult_labels.has(entry.get("cult_name")):
			errors.append("Missing or duplicate world/cult name"); continue
		world_labels[entry.name] = true; cult_labels[entry.cult_name] = true
	if candidate.world_names.size() != int(rules.civilization_parameters.domains_total.value): errors.append("Incomplete world names")
	var people := FileAccess.open(directory.path_join("person_names.csv"), FileAccess.READ)
	if people == null: errors.append("Missing person_names.csv"); return false
	if people.get_csv_line() != PackedStringArray(["id", "given", "family"]):
		errors.append("Invalid person name header"); return false
	var candidate_names: Array[Dictionary] = []
	var given := {}; var families := {}
	while not people.eof_reached():
		var cells := people.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != 3 or cells[0] != str(candidate_names.size() + 1) or cells[1].is_empty() or cells[2].is_empty() or given.has(cells[1]) or families.has(cells[2]):
			errors.append("Invalid or duplicate person name"); continue
		given[cells[1]] = true; families[cells[2]] = true
		candidate_names.append({"given": cells[1], "family": cells[2]})
	if candidate_names.is_empty(): errors.append("Empty person names")
	if not errors.is_empty(): return false
	var naming := WorldNames.new()
	if not naming.load_files(rules.civilization_profiles, directory):
		errors.append_array(naming.errors); return false
	tables = candidate; names = candidate_names; world_names = naming
	return true

func person_name(id: String) -> String:
	var serial: String = id.trim_prefix("NPC-")
	if names.is_empty() or not serial.is_valid_int() or int(serial) <= 0: return ""
	var ordinal: int = int(serial) - 1
	var width: int = names.size()
	@warning_ignore("integer_division")
	var result: String = names[ordinal % width].given + "·" + names[(ordinal * 7 + ordinal / width) % width].family
	return result

func institution_name(profile: String, role: String) -> String:
	return str(tables.institutions.get(profile + "/" + role, {}).get("name", "当地机构"))
