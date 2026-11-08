extends RefCounted
## Display-only vocabulary. Never reads outcome bodies or advances gameplay RNG.
static var groups: Dictionary = {}

static func _load() -> void:
	if not groups.is_empty(): return
	var file := FileAccess.open("res://data/prayer_response_voice.csv", FileAccess.READ)
	assert(file != null, "Missing prayer response voice")
	file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() != 3: continue
		if not groups.has(cells[1]): groups[cells[1]] = []
		groups[cells[1]].append(cells[2])

static func _pick(group: String, index: int) -> String:
	return str(groups[group][index % groups[group].size()])

static func wording(choice: Dictionary, case_id: String, choice_id: String) -> Dictionary:
	_load()
	var index := 0
	for byte: int in case_id.to_utf8_buffer(): index += byte
	index += choice_id.unicode_at(choice_id.length() - 1) - 97
	var approach := str(choice.get("approach", "mercy"))
	if not groups.has(approach): approach = "mercy"
	var pollution := int(choice.get("pollution", 0))
	var alert := int(choice.get("alert", 0))
	var risk := int(choice.get("disaster_sanity", 0))
	var hint := _pick("pollution_%d" % (1 if pollution <= 1 else (2 if pollution <= 3 else 3)), index)
	hint += "，" + _pick("alert_%d" % (0 if alert == 0 else (1 if alert <= 1 else (2 if alert <= 3 else 3))), index) + "。"
	if choice.get("disclosure") == "unknown": hint += _pick("unknown", index)
	else: hint += _pick("risk_%d" % (0 if risk == 0 else (1 if risk <= 4 else (2 if risk <= 6 else 3))), index)
	return {"label": _pick(approach, index), "hint": hint}
