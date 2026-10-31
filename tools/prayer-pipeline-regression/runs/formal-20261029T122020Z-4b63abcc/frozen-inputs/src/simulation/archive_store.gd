extends RefCounted
## Persistent collection access and immutable, content-addressed save segments.
const History = preload("res://src/simulation/history_index.gd")
const WORLD_ROOTS: Array[String] = ["facts", "npcs", "evidence", "relics", "applied_authorizations", "invalid_records"]
const CONTEXT_ROOTS: Array[String] = ["receipts", "completed_jobs"]
const FORMAT: int = 2
var last_error: String = ""
var metrics: Dictionary = {}
var directory: String = ""
var head: String = ""
var saved_sequence: int = -1
var saved_root: String = ""
var page_records: int = 0
var _nodes: Dictionary = {}
var _values: Dictionary = {}
var _objects: Dictionary = {}
var _on_disk: Dictionary = {}
var _needed: Dictionary = {}
var _decoding: Dictionary = {}
var _decoded: Dictionary = {}

static func packed(value: Variant) -> bool:
	return History.is_history(value) and value.kind == "map"

static func overlay(value: Variant) -> bool:
	return History.is_overlay(value)

static func entry(value: Variant, key: Variant, fallback: Variant = null) -> Variant:
	return History.root_entry(value, key, fallback)

static func has(value: Variant, key: Variant) -> bool:
	return History.root_has(value, key)

static func size(value: Variant) -> int:
	if overlay(value):
		var result: int = History.size(value.base)
		for key: String in value.writes:
			if not History.has(value.base, key): result += 1
		for key: String in value.removed:
			if History.has(value.base, key): result -= 1
		return result
	return History.size(value)

static func keys(value: Variant) -> Array:
	return History.root_keys(value)

static func values(value: Variant) -> Array:
	if overlay(value):
		var result: Array = []
		for key: String in keys(value): result.append(entry(value, key))
		return result
	return History.values(value)

static func put(value: Dictionary, key: Variant, item: Variant) -> void:
	if overlay(value):
		value.writes[str(key)] = item
		value.removed.erase(str(key))
	else:
		assert(not History.is_history(value), "Writes require a transaction overlay")
		value[key] = item

static func erase(value: Dictionary, key: Variant) -> void:
	if overlay(value):
		value.writes.erase(str(key))
		value.removed[str(key)] = true
	else:
		assert(not History.is_history(value), "Writes require a transaction overlay")
		value.erase(key)

static func begin(value: Dictionary) -> Dictionary:
	return History.overlay(value if packed(value) else History.from_value(value, "map"))

static func finish(value: Dictionary) -> Dictionary:
	if not overlay(value): return value
	var result: Dictionary = value.base
	for key: String in value.removed: result = History.erase(result, key)
	for key: String in value.writes:
		if not has(value.base, key) or not same_current(entry(value.base, key), value.writes[key]): result = History.set_value(result, key, value.writes[key], "map")
	return result

static func changed(value: Dictionary) -> Array:
	return value.writes.keys() if overlay(value) else []

static func valid_root(value: Variant) -> bool:
	return value is Dictionary and (not overlay(value) or (packed(value.get("base")) and value.get("writes") is Dictionary and value.get("removed") is Dictionary))

static func retained(after: Variant, before: Variant, immutable_values: bool = false) -> Array[String]:
	if is_same(after, before): return []
	if not valid_root(after) or not overlay(after) or not is_same(after.base, before): return ["Untrusted collection root replacement"]
	if not after.removed.is_empty(): return ["Committed collection entries cannot disappear"]
	if immutable_values:
		for key: String in after.writes:
			if has(before, key) and not is_same(entry(before, key), after.writes[key]): return ["Committed immutable record was replaced"]
	return []

static func pack_state(state: Dictionary) -> Dictionary:
	var ready: bool = true
	for field: String in WORLD_ROOTS: ready = ready and packed(state[field])
	if ready: return state
	var result: Dictionary = state.duplicate(false)
	for field: String in WORLD_ROOTS:
		result[field] = state[field] if packed(state[field]) else History.from_value(state[field], "map")
	return result

static func pack_context(context: Dictionary) -> Dictionary:
	if packed(context.receipts) and packed(context.completed_jobs) and History.is_history(context.journal): return context
	var result: Dictionary = context.duplicate(false)
	for field: String in CONTEXT_ROOTS: result[field] = context[field] if packed(context[field]) else History.from_value(context[field], "map")
	result.journal = context.journal if History.is_history(context.journal) else History.from_value(context.journal, "sequence")
	return result

static func append_journal(context: Dictionary, item: Dictionary) -> void:
	if History.is_history(context.journal):
		context.journal = History.set_value(context.journal, "%012d" % History.size(context.journal), item, "sequence")
	else: context.journal.append(item)

func _fail(reason: String) -> bool:
	last_error = reason
	return false

static func canonical(value: Variant) -> String:
	return JSON.stringify(normalize(value), "", true, true)

func _init() -> void:
	var file: FileAccess = FileAccess.open("res://data/fidelity_parameters.csv", FileAccess.READ)
	if file == null: return
	var header: PackedStringArray = file.get_csv_line()
	if Array(header) != ["id", "value", "unit", "activation", "rationale"]: return
	var found: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == header.size() and row[0] == "archive_page_records":
			found += 1
			if row[1].is_valid_int() and int(row[1]) > 0 and row[3] == "segmented" and row[2] == "record_per_segment": page_records = int(row[1])
	if found != 1: page_records = 0

func _object(payload: Dictionary) -> String:
	var id: String = canonical(payload).sha256_text()
	_objects[id] = payload
	return id

func _encode(value: Variant) -> Array:
	if History.is_history(value): return ["r", _object({"type": "tree", "kind": value.kind, "node": _encode_node(value.root)})]
	if value is Dictionary:
		var items: Array = []
		var names: Array = value.keys(); names.sort()
		for key: String in names: items.append([key, _encode(value[key])])
		return ["r", _object({"type": "map", "items": items})]
	if value is Array or value is PackedStringArray:
		var items: Array = []
		for item: Variant in value: items.append(_encode(item))
		return ["r", _object({"type": "array", "items": items})]
	return ["v", value]

func _encode_node(node: Dictionary) -> String:
	if node.is_empty(): return ""
	var uid: String = node.serial
	if _nodes.has(uid): return _nodes[uid]
	metrics.nodes_encoded += 1
	var value_id: String = node.value_serial
	if not _values.has(value_id): _values[value_id] = _encode(node.value)
	var id: String = _object({"type": "node", "serial": uid, "value_serial": value_id, "key": node.key, "value": _values[value_id], "left": _encode_node(node.left), "right": _encode_node(node.right)})
	_nodes[uid] = id
	return id

func _references(payload: Dictionary) -> Array:
	var result: Array = []
	match str(payload.get("type", "")):
		"tree":
			if not str(payload.get("node", "")).is_empty(): result.append(payload.node)
		"node":
			for name: String in ["left", "right"]:
				if not str(payload.get(name, "")).is_empty(): result.append(payload[name])
			if payload.get("value") is Array and payload.value.size() == 2 and payload.value[0] == "r": result.append(payload.value[1])
		"map":
			for pair: Variant in payload.get("items", []):
				if pair is Array and pair.size() == 2 and pair[1] is Array and pair[1].size() == 2 and pair[1][0] == "r": result.append(pair[1][1])
		"array":
			for item: Variant in payload.get("items", []):
				if item is Array and item.size() == 2 and item[0] == "r": result.append(item[1])
	return result

func _include(id: String) -> void:
	if _on_disk.has(id) or _needed.has(id): return
	if not _objects.has(id): last_error = "Missing pending object"; return
	_needed[id] = _objects[id]
	for child: String in _references(_objects[id]): _include(child)

func _write(path: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _fail("Cannot write archive file")
	var text: String = canonical(value)
	var expected: int = text.to_utf8_buffer().size()
	var stored: bool = _store_bytes(file, text)
	file.flush()
	var complete: bool = stored and file.get_error() == OK and file.get_position() == expected and file.get_length() == expected
	file.close()
	if not complete: return _fail("Incomplete archive write")
	# Verify only the newly written bytes before a manifest may publish them.
	if FileAccess.get_file_as_string(path) != text: return _fail("Archive write verification failed")
	metrics.bytes_written = int(metrics.get("bytes_written", 0)) + expected
	return true

func _store_bytes(file: FileAccess, text: String) -> bool:
	return file.store_string(text)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): last_error = "Missing committed archive file"; return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: last_error = "Unreadable archive file"; return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK: last_error = "Malformed archive file"; return {}
	var value: Variant = normalize(parser.data)
	if not value is Dictionary: last_error = "Malformed archive file"; return {}
	return value

func save(session: RefCounted, path: String, fault: String = "") -> bool:
	last_error = ""; metrics = {"nodes_encoded": 0, "objects_written": 0, "segments_written": 0, "bytes_written": 0}
	if page_records <= 0: return _fail("Invalid authored archive segment policy")
	if not session._archive_ready(): return _fail("Session cannot be saved now")
	if not directory.is_empty() and directory != path: return _fail("Archive instance belongs to another directory")
	if directory.is_empty() and FileAccess.file_exists(path.path_join("manifest.json")): return _fail("Load an existing archive before appending")
	if not _check_head(path): return false
	directory = path
	if DirAccess.make_dir_recursive_absolute(path.path_join("segments")) != OK or DirAccess.make_dir_recursive_absolute(path.path_join("commits")) != OK: return _fail("Cannot create archive directory")
	var checkpoint: Dictionary = session._archive_checkpoint()
	if not checkpoint.get("sequence") is int or int(checkpoint.sequence) < 0 or checkpoint.get("schema") != FORMAT: return _fail("Invalid checkpoint metadata")
	var sequence: int = checkpoint.sequence
	var root: String = _encode(checkpoint)[1]
	if sequence < saved_sequence or (sequence == saved_sequence and root != saved_root): return _fail("Archive sequence collision")
	if sequence == saved_sequence and root == saved_root: return true
	_needed = {}; _include(root)
	if not last_error.is_empty(): return false
	var objects: Array = []
	for id: String in _needed: objects.append({"id": id, "payload": _needed[id]})
	var segments: Array = []
	for offset: int in range(0, objects.size(), page_records):
		var payload: Dictionary = {"format": FORMAT, "objects": objects.slice(offset, mini(objects.size(), offset + page_records))}
		var bytes: String = canonical(payload)
		var id: String = bytes.sha256_text()
		if not _write(path.path_join("segments/" + id + ".json"), payload): return false
		segments.append(id); metrics.segments_written += 1; metrics.objects_written += payload.objects.size()
	if fault == "segments": return _fail("Injected interruption before commit record")
	var commit: Dictionary = {"format": FORMAT, "previous": head, "sequence": sequence, "root": root, "segments": segments}
	var commit_id: String = canonical(commit).sha256_text()
	if not _write(path.path_join("commits/" + commit_id + ".json"), commit): return false
	if fault == "commit": return _fail("Injected interruption before manifest")
	var manifest: Dictionary = {"format": FORMAT, "head": commit_id, "sequence": sequence}
	var envelope: Dictionary = {"body": manifest, "checksum": canonical(manifest).sha256_text()}
	if not _write(path.path_join("manifest.pending"), envelope): return false
	if fault == "manifest": return _fail("Injected interruption before publication")
	if not _check_head(path): return false
	if DirAccess.rename_absolute(path.path_join("manifest.pending"), path.path_join("manifest.json")) != OK: return _fail("Cannot publish archive manifest")
	for id: String in _needed: _on_disk[id] = true
	head = commit_id; saved_sequence = sequence; saved_root = root
	return true

func _decode_ref(reference: Variant) -> Variant:
	if not reference is Array or reference.size() != 2: last_error = "Malformed archive reference"; return null
	if reference[0] == "v":
		if reference[1] is Dictionary or reference[1] is Array: last_error = "Non-scalar literal"; return null
		return reference[1]
	if reference[0] != "r" or not reference[1] is String: last_error = "Unknown archive reference"; return null
	return _decode(reference[1])

func _decode(id: String) -> Variant:
	if _decoded.has(id): return _decoded[id]
	if _decoding.has(id) or not _objects.has(id): last_error = "Cyclic or missing archive object"; return null
	_decoding[id] = true
	var payload: Dictionary = _objects[id]
	var result: Variant
	var type: String = str(payload.get("type", ""))
	if type in ["map", "array"] and not payload.get("items") is Array: last_error = "Invalid archive items"; return null
	if type == "tree" and not payload.get("node") is String: last_error = "Invalid archive tree reference"; return null
	if type == "node" and (not payload.get("left") is String or not payload.get("right") is String): last_error = "Invalid archive node links"; return null
	match type:
		"map":
			result = {}
			for pair: Variant in payload.get("items", []):
				if not pair is Array or pair.size() != 2 or not pair[0] is String or result.has(pair[0]): last_error = "Malformed archive map"; break
				result[pair[0]] = _decode_ref(pair[1])
		"array":
			result = []
			for item: Variant in payload.get("items", []): result.append(_decode_ref(item))
		"tree":
			if not payload.get("kind", "") in ["map", "list", "sequence"]: last_error = "Unknown archive tree kind"
			var node: Variant = {} if payload.get("node", "").is_empty() else _decode(payload.node)
			if not node is Dictionary: last_error = "Invalid archive tree node"; node = {}
			result = History._wrap(node, payload.get("kind", "map"))
			if payload.get("kind") == "sequence":
				var ordered: Array = History.keys(result)
				for index: int in ordered.size():
					if ordered[index] != "%012d" % index: last_error = "Noncanonical archive sequence"; break
		"node":
			var left: Variant = {} if payload.get("left", "").is_empty() else _decode(payload.left)
			var right: Variant = {} if payload.get("right", "").is_empty() else _decode(payload.right)
			var item: Variant = _decode_ref(payload.get("value"))
			if not left is Dictionary or not right is Dictionary or not payload.get("key") is String or not payload.get("serial") is String or not payload.get("value_serial") is String or payload.serial.is_empty() or payload.value_serial.is_empty():
				last_error = "Malformed archive node"; result = {}
			else:
				result = History._node(payload.key, item, left, right, payload.value_serial).duplicate(false)
				result.serial = payload.serial
				result.make_read_only()
				if absi(int(left.get("height", 0)) - int(right.get("height", 0))) > 1: last_error = "Unbalanced archive tree"
				if (not left.is_empty() and _extreme(left, "right") >= str(payload.key)) or (not right.is_empty() and _extreme(right, "left") <= str(payload.key)): last_error = "Unordered archive tree"
				if _nodes.has(payload.serial) and _nodes[payload.serial] != id: last_error = "Conflicting archive node identity"
				_nodes[payload.serial] = id
				if _values.has(payload.value_serial) and _values[payload.value_serial] != payload.value: last_error = "Conflicting archive payload identity"
				_values[payload.value_serial] = payload.value
		_:
			last_error = "Unknown archive object type"; result = null
	_decoding.erase(id)
	if not last_error.is_empty(): return null
	_decoded[id] = result
	return result

func load_session(session: RefCounted, path: String) -> bool:
	last_error = ""; _objects = {}; _decoded = {}; _decoding = {}; _nodes = {}; _values = {}; _on_disk = {}
	if page_records <= 0: return _fail("Invalid authored archive segment policy")
	var envelope: Dictionary = _read(path.path_join("manifest.json"))
	if not envelope.get("body") is Dictionary or envelope.get("checksum") != canonical(envelope.body).sha256_text() or envelope.body.get("format") != FORMAT: return _fail("Invalid archive manifest")
	var manifest: Dictionary = envelope.body
	if not manifest.get("sequence") is int or int(manifest.sequence) < 0: return _fail("Invalid manifest sequence")
	var cursor: Variant = manifest.get("head")
	var seen: Dictionary = {}
	var upper: int = int(manifest.get("sequence", -1)) + 1
	var first: bool = true
	while cursor is String and not cursor.is_empty():
		if not cursor.is_valid_hex_number(false) or cursor.length() != 64 or seen.has(cursor): return _fail("Invalid commit chain")
		seen[cursor] = true
		var commit: Dictionary = _read(path.path_join("commits/" + cursor + ".json"))
		if commit.get("format") != FORMAT or canonical(commit).sha256_text() != cursor or not commit.get("sequence") is int: return _fail("Corrupt committed archive record")
		var sequence: int = int(commit.sequence)
		if sequence < 0 or sequence >= upper or (first and sequence != int(manifest.sequence)): return _fail("Archive sequence chain disagrees")
		upper = sequence; first = false
		if not commit.get("segments") is Array: return _fail("Invalid segment listing")
		for segment: Variant in commit.segments:
			if not segment is String or segment.length() != 64 or not segment.is_valid_hex_number(false): return _fail("Invalid segment identity")
			var page: Dictionary = _read(path.path_join("segments/" + segment + ".json"))
			if page.get("format") != FORMAT or canonical(page).sha256_text() != segment or not page.get("objects") is Array: return _fail("Corrupt committed segment")
			for object: Variant in page.objects:
				if not object is Dictionary or not object.get("id") is String or not object.get("payload") is Dictionary or canonical(object.payload).sha256_text() != object.id: return _fail("Corrupt archive object")
				_objects[object.id] = object.payload; _on_disk[object.id] = true
		cursor = commit.get("previous")
	if not cursor is String or first: return _fail("Invalid archive prefix")
	var tip: Dictionary = _read(path.path_join("commits/" + manifest.head + ".json"))
	if not tip.get("root") is String: return _fail("Missing archive checkpoint")
	var checkpoint: Variant = _decode(tip.root)
	if not last_error.is_empty() or not checkpoint is Dictionary: return false
	if checkpoint.get("sequence") != int(manifest.sequence): return _fail("Checkpoint sequence disagrees")
	if not session._adopt_archive(checkpoint): return _fail(session.last_error)
	directory = path; head = manifest.head; saved_sequence = int(manifest.sequence); saved_root = tip.root
	return true

static func normalize(value: Variant) -> Variant:
	if value is float and is_finite(value) and floor(value) == value: return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = normalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(normalize(item))
		return result
	return value

static func _extreme(node: Dictionary, direction: String) -> String:
	while not node[direction].is_empty(): node = node[direction]
	return str(node.key)

static func same_current(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if is_same(a, b): return true
		if History.is_history(a) or History.is_history(b): return History.is_history(a) and History.is_history(b) and a.kind == b.kind and is_same(a.root, b.root)
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same_current(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i: int in a.size():
			if not same_current(a[i], b[i]): return false
		return true
	return a == b

func _check_head(path: String) -> bool:
	if not FileAccess.file_exists(path.path_join("manifest.json")):
		return true if head.is_empty() else _fail("Published manifest disappeared")
	var value: Dictionary = _read(path.path_join("manifest.json"))
	if not value.get("body") is Dictionary or value.get("checksum") != canonical(value.body).sha256_text(): return _fail("Published manifest is corrupt")
	if value.body.get("format") != FORMAT or value.body.get("head") != head or value.body.get("sequence") != saved_sequence: return _fail("Archive changed; reload before saving")
	return true
