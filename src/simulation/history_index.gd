extends RefCounted
## Immutable AVL maps are the in-memory cold representation. Canonical exports
## hydrate legacy arrays/maps; normal writes copy a logarithmic search path only.
const COLD_FIELDS: Dictionary = {"npcs": ["known_facts", "consumed_sources", "growth_sources", "relations"], "institutions": ["known_facts"], "domains": ["public_facts", "crisis_facts", "public_anomalies"], "evidence": ["sources", "confirmations", "contributions"], "relics": []}
static var _serial: int = 0
static var work_metrics: Dictionary = {}
static var _marker_token: String = Crypto.new().generate_random_bytes(16).hex_encode()
var metrics: Dictionary = {}
var data: Dictionary = {}
var version: int = 0
var policy: String = ""
var page_limit: int = 0
var source_root: Dictionary = {}
var rules: Dictionary = {}
var restriction_validator: Callable = Callable()
var pending: Dictionary = {}
var incarnation: String = Crypto.new().generate_random_bytes(16).hex_encode()

func _init(read_policy: bool = true) -> void:
	reset_metrics()
	if read_policy:
		load_policy()

func load_policy(path: String = "res://data/fidelity_parameters.csv") -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 4 or headers[0] != "id" or headers[1] != "value": return false
	var found: int = 0
	var candidate: int = 0
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != headers.size(): return false
		if cells[0] == "decision_query_page_limit":
			if not cells[1].is_valid_int() or int(cells[1]) <= 0: return false
			found += 1
			candidate = int(cells[1])
	if found != 1: return false
	page_limit = candidate
	policy = ("decision_query_page_limit=" + str(candidate)).sha256_text()
	return true

func reset_metrics() -> void:
	metrics = {"history_scanned": 0, "rebuild_records": 0, "decision_reads": 0, "current_entities": 0, "copied_current_objects": 0, "copied_history_values": 0, "output_sources": 0, "index_updates": 0, "tree_nodes_allocated": 0, "tree_nodes_read": 0, "root_identity_entries": 0}
	work_metrics = metrics

static func _count(name: String, amount: int = 1) -> void:
	if not work_metrics.is_empty():
		work_metrics[name] = int(work_metrics.get(name, 0)) + amount

static func is_history(value: Variant) -> bool:
	return _encoded_history(value) and value.is_read_only()

static func _encoded_history(value: Variant) -> bool:
	return value is Dictionary and value.get("$history_index") == _marker_token and value.get("kind", "") in ["list", "map", "sequence"] and value.get("root") is Dictionary and value.size() == 3

static func _height(node: Dictionary) -> int:
	return int(node.get("height", 0))

static func _seal(value: Variant) -> void:
	if value is Dictionary or value is Array:
		if value.is_read_only(): return
		for child: Variant in (value.values() if value is Dictionary else value): _seal(child)
		value.make_read_only()

static func next_serial() -> String:
	_serial += 1
	return _marker_token + "/" + str(_serial)

static func overlay(base: Dictionary) -> Dictionary:
	return {"$archive_overlay": _marker_token, "base": base, "writes": {}, "removed": {}}

static func is_overlay(value: Variant) -> bool:
	return value is Dictionary and value.get("$archive_overlay") == _marker_token

static func _node(key: String, value: Variant, left: Dictionary, right: Dictionary, value_serial: String = "") -> Dictionary:
	_count("tree_nodes_allocated")
	_seal(left)
	_seal(right)
	_seal(value)
	var recent: int = int(value) if value is int else -1
	var node: Dictionary = {"serial": next_serial(), "value_serial": next_serial() if value_serial.is_empty() else value_serial, "key": key, "value": value, "left": left, "right": right, "height": 1 + maxi(_height(left), _height(right)), "count": 1 + int(left.get("count", 0)) + int(right.get("count", 0)), "recent": maxi(recent, maxi(int(left.get("recent", -1)), int(right.get("recent", -1))))}
	node.make_read_only()
	return node

static func _balance(node: Dictionary) -> Dictionary:
	var balance: int = _height(node.left) - _height(node.right)
	if balance > 1:
		var left: Dictionary = node.left
		if _height(left.left) < _height(left.right):
			var pivot: Dictionary = left.right
			left = _node(pivot.key, pivot.value, _node(left.key, left.value, left.left, pivot.left, left.value_serial), pivot.right, pivot.value_serial)
		return _node(left.key, left.value, left.left, _node(node.key, node.value, left.right, node.right, node.value_serial), left.value_serial)
	if balance < -1:
		var right: Dictionary = node.right
		if _height(right.right) < _height(right.left):
			var pivot: Dictionary = right.left
			right = _node(pivot.key, pivot.value, pivot.left, _node(right.key, right.value, pivot.right, right.right, right.value_serial), pivot.value_serial)
		return _node(right.key, right.value, _node(node.key, node.value, node.left, right.left, node.value_serial), right.right, right.value_serial)
	return node

static func _put(node: Dictionary, key: String, value: Variant) -> Dictionary:
	_count("tree_nodes_read")
	if node.is_empty():
		return _node(key, value, {}, {})
	if key == node.key:
		return node if (is_same(node.value, value) if value is Dictionary or value is Array else node.value == value) else _node(key, value, node.left, node.right)
	if key < str(node.key):
		return _balance(_node(node.key, node.value, _put(node.left, key, value), node.right, node.value_serial))
	return _balance(_node(node.key, node.value, node.left, _put(node.right, key, value), node.value_serial))

static func _remove(node: Dictionary, key: String) -> Dictionary:
	_count("tree_nodes_read")
	if node.is_empty():
		return node
	if key < str(node.key):
		return _balance(_node(node.key, node.value, _remove(node.left, key), node.right, node.value_serial))
	if key > str(node.key):
		return _balance(_node(node.key, node.value, node.left, _remove(node.right, key), node.value_serial))
	if node.left.is_empty():
		return node.right
	if node.right.is_empty():
		return node.left
	var successor: Dictionary = node.right
	while not successor.left.is_empty():
		successor = successor.left
	return _balance(_node(successor.key, successor.value, node.left, _remove(node.right, successor.key), successor.value_serial))

static func _wrap(root: Dictionary, kind: String) -> Dictionary:
	_seal(root)
	var result: Dictionary = {"$history_index": _marker_token, "kind": kind, "root": root}
	result.make_read_only()
	return result

static func _build_balanced(ordered: Array, entries: Dictionary, start: int, end: int) -> Dictionary:
	if start >= end: return {}
	var middle: int = (start + end) / 2
	var key: String = ordered[middle]
	return _node(key, entries[key], _build_balanced(ordered, entries, start, middle), _build_balanced(ordered, entries, middle + 1, end))

static func from_value(value: Variant, kind: String = "list") -> Dictionary:
	if is_history(value): return value
	if _encoded_history(value): return from_value(export_value(value), str(value.kind))
	var entries: Dictionary = {}
	if value is Array or value is PackedStringArray:
		if kind == "sequence":
			for index: int in value.size(): entries["%012d" % index] = copy_current(value[index])
		else:
			for key: String in value: entries[key] = true
	elif value is Dictionary:
		for key: String in value: entries[key] = copy_current(value[key])
	var ordered: Array = entries.keys()
	ordered.sort()
	return _wrap(_build_balanced(ordered, entries, 0, ordered.size()), kind)

static func set_value(value: Variant, key: String, item: Variant = true, kind: String = "list") -> Dictionary:
	var tree: Dictionary = from_value(value, kind)
	var stored: Variant = item if is_history(item) else copy_current(item)
	return _wrap(_put(tree.root, key, stored), tree.kind)

static func erase(value: Variant, key: String) -> Dictionary:
	var tree: Dictionary = from_value(value)
	return _wrap(_remove(tree.root, key), tree.kind)

static func mapget(value: Variant, key: String, fallback: Variant = null) -> Variant:
	if not is_history(value):
		return value.get(key, fallback) if value is Dictionary else (true if key in value else fallback)
	var node: Dictionary = value.root
	while not node.is_empty():
		_count("tree_nodes_read")
		if key == node.key:
			return node.value
		node = node.left if key < str(node.key) else node.right
	return fallback

static func has(value: Variant, key: String) -> bool:
	return mapget(value, key) != null

static func size(value: Variant) -> int:
	return int(value.root.get("count", 0)) if is_history(value) else value.size()

static func at(value: Variant, rank: int) -> Dictionary:
	var tree: Dictionary = from_value(value)
	var node: Dictionary = tree.root
	while not node.is_empty():
		_count("tree_nodes_read")
		var left_count: int = int(node.left.get("count", 0))
		if rank == left_count:
			return {"key": node.key, "value": node.value}
		if rank < left_count:
			node = node.left
		else:
			rank -= left_count + 1
			node = node.right
	return {}

static func _flatten(node: Dictionary, output: Array, keys: bool) -> void:
	if node.is_empty():
		return
	_flatten(node.left, output, keys)
	output.append(node.key if keys else node.value)
	_flatten(node.right, output, keys)

static func keys(value: Variant) -> Array:
	if not is_history(value):
		return value.keys() if value is Dictionary else Array(value)
	var output: Array = []
	_flatten(value.root, output, true)
	_count("output_sources", output.size())
	return output

static func values(value: Variant) -> Array:
	if not is_history(value):
		return value.values() if value is Dictionary else Array(value)
	var output: Array = []
	_flatten(value.root, output, value.kind == "list")
	_count("output_sources", output.size())
	return output

static func _find_node(node: Dictionary, key: String) -> Dictionary:
	while not node.is_empty():
		_count("tree_nodes_read")
		if node.key == key: return node
		node = node.left if key < str(node.key) else node.right
	return {}

static func _changed_nodes(node: Dictionary, before: Dictionary, result: Array) -> void:
	if node.is_empty(): return
	var prior: Dictionary = _find_node(before, node.key)
	if is_same(node, prior): return
	if prior.is_empty() or node.value != prior.value: result.append({"key": node.key, "value": node.value})
	_changed_nodes(node.left, before, result)
	_changed_nodes(node.right, before, result)

static func changed_entries(after: Variant, before: Variant) -> Array:
	if is_same(after, before): return []
	var kind: String = str(after.kind) if is_history(after) else (str(before.kind) if is_history(before) else ("map" if after is Dictionary else ("sequence" if after is Array and not after.is_empty() and after[0] is Dictionary else "list")))
	var newer: Dictionary = from_value(after, kind)
	var older: Dictionary = from_value(before, newer.kind)
	var result: Array = []
	_changed_nodes(newer.root, older.root, result)
	return result

static func export_value(value: Variant) -> Variant:
	if is_overlay(value):
		var output: Dictionary = export_value(value.base)
		for key: String in value.removed: output.erase(key)
		for key: String in value.writes: output[key] = export_value(value.writes[key])
		return output
	if _encoded_history(value):
		var ordered_keys: Array = []
		var ordered_values: Array = []
		_flatten(value.root, ordered_keys, true)
		_flatten(value.root, ordered_values, false)
		_count("output_sources", ordered_keys.size())
		if value.kind == "list": return ordered_keys
		if value.kind == "sequence": return ordered_values
		var output: Dictionary = {}
		for index: int in ordered_keys.size():
			output[ordered_keys[index]] = export_value(ordered_values[index])
		return output
	if value is Dictionary:
		var output: Dictionary = {}
		for key: Variant in value:
			output[key] = export_value(value[key])
		return output
	if value is Array:
		var output: Array = []
		for item: Variant in value:
			output.append(export_value(item))
		return output
	return value

static func copy_current(value: Variant) -> Variant:
	if is_history(value):
		return value
	if value is Dictionary:
		var output: Dictionary = {}
		for key: Variant in value:
			output[key] = copy_current(value[key])
		return output
	if value is Array:
		var output: Array = []
		for item: Variant in value:
			output.append(copy_current(item))
		return output
	return value

func fork() -> RefCounted:
	var copy: RefCounted = get_script().new(false)
	copy.rules = rules
	copy.restriction_validator = restriction_validator
	copy.page_limit = page_limit
	copy.policy = policy
	copy.data = data.duplicate(false)
	copy.version = version
	copy.incarnation = incarnation
	copy.source_root = source_root
	copy.pending = {}
	copy.metrics = metrics
	work_metrics = metrics
	return copy

func _bucket(key: String) -> Dictionary:
	work_metrics = metrics
	return mapget(data.get("buckets", from_value({}, "map")), key, from_value([]))

func _add(bucket: String, id: String, value: Variant = true) -> void:
	work_metrics = metrics
	data["buckets"] = set_value(data.get("buckets", from_value({}, "map")), bucket, set_value(_bucket(bucket), id, value), "map")
	version += 1
	metrics.index_updates += 1

func _drop(bucket: String, id: String) -> void:
	work_metrics = metrics
	if has(data.get("buckets", from_value({}, "map")), bucket):
		data["buckets"] = set_value(data.buckets, bucket, erase(_bucket(bucket), id), "map")
		version += 1
		metrics.index_updates += 1

func ids(bucket: String) -> Array:
	work_metrics = metrics
	return keys(_bucket(bucket))

func support(owner: String, target: String) -> Dictionary:
	work_metrics = metrics
	return mapget(_bucket("support/" + owner), target, {})

func recovery(owner: String) -> String:
	work_metrics = metrics
	return str(mapget(data.get("recovery", from_value({}, "map")), owner, ""))

func knows(state: Dictionary, actor: String, source: String, institution: bool = false) -> bool:
	work_metrics = metrics
	if institution: return state.institutions.has(actor) and has(state.institutions[actor].known_facts, source)
	return root_has(state.npcs, actor) and has(root_entry(state.npcs, actor).known_facts, source)

func rebuild(state: Dictionary) -> void:
	work_metrics = metrics
	data = {}
	pending = {}
	for collection: String in COLD_FIELDS:
		for id: String in state[collection]:
			var record: Dictionary = state[collection][id]
			for field: String in COLD_FIELDS[collection]:
				if not record.has(field):
					continue
				if field == "growth_sources":
					for attribute: String in record.growth_sources:
						record.growth_sources[attribute] = from_value(record.growth_sources[attribute])
				else:
					record[field] = from_value(record[field], "map" if field in ["consumed_sources", "contributions", "public_anomalies"] else ("sequence" if field == "relations" else "list"))
			metrics.rebuild_records += 1
	for source: String in root_keys(state.facts):
		add_event_record(state, source)
		if root_entry(state.facts, source).kind == "prayer_situation": add_prayer_source(state, source)
		if root_entry(state.facts, source).kind == "institution_event_result": add_institution_result(state, source)
		if root_entry(state.facts, source).kind == "institution_restriction" and restriction_validator.is_valid() and restriction_validator.call(state, source): add_institution_restriction(state, source)
	for id: String in root_keys(state.npcs):
		refresh_person(state, id)
		for relation: Dictionary in values(root_entry(state.npcs, id).relations):
			add_relation(id, relation, state)
			if relation.kind == "support":
				_add("support/" + id, relation.target, relation)
		for source: String in values(root_entry(state.npcs, id).known_facts):
			metrics.history_scanned += 1
			learn(state, id, source, false)
	for id: String in state.institutions:
		for source: String in values(state.institutions[id].known_facts):
			metrics.history_scanned += 1
			learn(state, id, source, true)
	for relic: String in root_keys(state.relics): refresh_relic(state, relic)
	for key: String in root_keys(state.evidence):
		refresh_evidence(state, key)
	for domain: String in state.domains:
		for source: String in keys(state.domains[domain].public_anomalies):
			add_anomaly(domain, source, str(mapget(state.domains[domain].public_anomalies, source)))
	source_root = state
	version += 1

func refresh_person(state: Dictionary, id: String) -> void:
	work_metrics = metrics
	for domain: String in state.domains:
		_drop("living/" + domain, id)
		_drop("active/" + domain, id)
	_drop("living", id)
	_drop("active", id)
	if root_has(state.npcs, id) and root_entry(state.npcs, id).status != "dead":
		var npc: Dictionary = root_entry(state.npcs, id)
		_add("living", id)
		_add("living/" + npc.domain, id)
		if npc.status == "active":
			_add("active", id)
			_add("active/" + npc.domain, id)

func refresh_relic(state: Dictionary, id: String) -> void:
	work_metrics = metrics
	var metadata: Dictionary = data.get("relic_metadata", from_value({}, "map"))
	var prior: Dictionary = mapget(metadata, id, {})
	if not prior.is_empty():
		_drop("relics", id)
		_drop("subject_relics/" + prior.domain, id)
		_drop("public_relics/" + prior.domain, id)
		if not str(prior.holder).is_empty(): _drop("holder/" + prior.holder, id)
	if not root_has(state.relics, id): return
	var relic: Dictionary = root_entry(state.relics, id)
	var holder: String = str(relic.get("holder", ""))
	if relic.placement != "consumed" or not holder.is_empty(): _add("relics", id)
	if not relic.placement in ["consumed", "seized"]: _add("subject_relics/" + relic.domain, id)
	if not relic.placement in ["consumed", "seized", "sealed"]: _add("public_relics/" + relic.domain, id)
	if not holder.is_empty(): _add("holder/" + holder, id)
	data["relic_metadata"] = set_value(metadata, id, {"domain": relic.domain, "holder": holder, "placement": relic.placement}, "map")

func refresh_evidence(state: Dictionary, key: String) -> void:
	work_metrics = metrics
	if not root_has(state.evidence, key):
		return
	var evidence: Dictionary = root_entry(state.evidence, key)
	if size(evidence.confirmations) > 0:
		_add("confirmed/" + evidence.institution, evidence.subject, key)
		if root_has(state.facts, evidence.subject) and root_entry(state.facts, evidence.subject).kind == "exception" and not root_has(state.invalid_records, evidence.subject):
			_add("exceptions/" + evidence.institution, evidence.subject, key)
	else:
		_drop("confirmed/" + evidence.institution, evidence.subject)

func add_anomaly(domain: String, source: String, carrier: String) -> void:
	work_metrics = metrics
	_add("anomaly/" + domain + "/" + carrier, source)

func remove_anomaly(domain: String, source: String, carrier: String) -> void:
	work_metrics = metrics
	_drop("anomaly/" + domain + "/" + carrier, source)

func anomaly_count(domain: String, carrier: String) -> int:
	work_metrics = metrics
	metrics.decision_reads += 1
	return size(_bucket("anomaly/" + domain + "/" + carrier))

func configure(behaviors: Dictionary, validate_restriction: Callable = Callable()) -> void:
	restriction_validator = validate_restriction
	work_metrics = metrics
	rules = copy_current(behaviors)
	_seal(rules)

func behavior_bucket(rule: Dictionary, actor: String, domain: String, target: String) -> String:
	return "behavior/" + str(rule.id) + "/" + actor + "/" + (domain + "/" if rule.eligibility == "known_local_exposure" else "") + target

func _available(npc: Dictionary, rule: Dictionary, source: String, target: String) -> bool:
	var key: String = str(rule.id) + "/" + source
	if rule.repeat_policy == "once_per_actor_source_target": key += "/" + target
	return rule.repeat_policy == "repeat_until_threshold" or not has(npc.consumed_sources, key)

func learn(state: Dictionary, owner: String, source: String, institution: bool = false) -> void:
	version += 1
	work_metrics = metrics
	var fact: Dictionary = root_entry(state.facts, source)
	if institution:
		if fact.kind == "exposure":
			for target: String in fact.targets: _add("exposed/" + owner + "/" + fact.domain + "/" + target, source, fact.turn)
		return
	var npc: Dictionary = root_entry(state.npcs, owner)
	if fact.kind in ["strain", "harm"] and owner in fact.targets:
		var old: String = recovery(owner)
		if source > old: data["recovery"] = set_value(data.get("recovery", from_value({}, "map")), owner, source, "map")
	for rule: Dictionary in rules.values():
		if rule.eligibility == "known_local_exposure" and fact.kind == "exposure":
			for target: String in fact.targets:
				if _available(npc, rule, source, target): _add(behavior_bucket(rule, owner, fact.domain, target), source, fact.turn)
		if rule.eligibility == "personally_witnessed_miracle" and fact.kind == "miracle" and owner in fact.changes.get("witnesses", []) and _available(npc, rule, source, owner):
			_add(behavior_bucket(rule, owner, "", owner), source, fact.turn)
	if fact.kind == "harm":
		_add("harm_observers/" + source, owner)
		for target: String in fact.targets:
			if not root_has(state.npcs, target) or not knows(state, target, source): continue
			for observer: String in ids("living"):
				if not has(_bucket("harm_observers/" + source), observer): continue
				for rule: Dictionary in rules.values():
					if rule.eligibility == "related_harmed_follower" and _available(root_entry(state.npcs, observer), rule, source, target):
						_add(behavior_bucket(rule, observer, "", target), source, fact.turn)

func consume(state: Dictionary, actor: String, behavior: String, source: String, target: String) -> void:
	work_metrics = metrics
	if not rules.has(behavior): return
	var rule: Dictionary = rules[behavior]
	var fact: Dictionary = root_entry(state.facts, source)
	if rule.repeat_policy == "repeat_until_threshold": return
	if rule.eligibility == "known_local_exposure" and rule.repeat_policy != "once_per_actor_source_target":
		for subject: String in fact.targets: _drop(behavior_bucket(rule, actor, fact.domain, subject), source)
	elif rule.eligibility == "related_harmed_follower" and rule.repeat_policy != "once_per_actor_source_target":
		for subject: String in fact.targets: _drop(behavior_bucket(rule, actor, "", subject), source)
	else:
		_drop(behavior_bucket(rule, actor, fact.domain, target), source)

func first(bucket: String) -> String:
	work_metrics = metrics
	metrics.decision_reads += 1
	var item: Dictionary = at(_bucket(bucket), 0)
	return str(item.get("key", ""))

func sources(bucket: String) -> Dictionary:
	work_metrics = metrics
	metrics.decision_reads += 1
	return _bucket(bucket)

func current_ids(state: Dictionary, collection: String) -> Array:
	work_metrics = metrics
	if collection == "npcs": return ids("living")
	if collection == "relics":
		var selected: Dictionary = {}
		for id: String in ids("relics"): selected[id] = true
		for anchor: Dictionary in state.anchors.values():
			var id: String = str(anchor.get("relic", ""))
			if root_has(state.relics, id): selected[id] = true
		return selected.keys()
	if collection == "evidence":
		var result: Array = []
		var subjects: Array = ids("living") + current_ids(state, "relics") + state.anchors.keys()
		for institution: String in state.institutions:
			for subject: String in subjects:
				var key: String = institution + "|" + subject
				if root_has(state.evidence, key): result.append(key)
			for subject: String in ids("exceptions/" + institution):
				if root_has(state.facts, subject) and root_entry(state.facts, subject).kind == "exception" and not root_has(state.invalid_records, subject):
					result.append(institution + "|" + subject)
		result.sort()
		return result
	return root_keys(state[collection])

func copy_collection(state: Dictionary, collection: String) -> Dictionary:
	work_metrics = metrics
	var source: Dictionary = state[collection]
	var result: Dictionary
	if is_overlay(source):
		result = overlay(source.base)
		result.removed = source.removed.duplicate(false)
		for id: String in source.writes: result.writes[id] = copy_current(source.writes[id])
	else: result = overlay(source) if is_history(source) else source.duplicate(false)
	for id: String in current_ids(state, collection):
		if is_overlay(result) and result.writes.has(id): continue
		var copy: Variant = copy_current(root_entry(source, id))
		if is_overlay(result): result.writes[id] = copy
		else: result[id] = copy
		metrics.copied_current_objects += 1
	return result

static func same_roots(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size(): return false
	for key: Variant in left:
		if not right.has(key): return false
		if left[key] is Dictionary or left[key] is Array:
			if not is_same(left[key], right[key]): return false
		elif left[key] != right[key]: return false
	return true

static func contains_reserved(value: Variant) -> bool:
	if value is Dictionary:
		if value.has("$history_index") or value.has("$archive_overlay"): return true
		for item: Variant in value.values():
			if contains_reserved(item): return true
	elif value is Array:
		for item: Variant in value:
			if contains_reserved(item): return true
	return false

static func valid_shape(value: Variant, kind: String) -> bool:
	if is_history(value): return value.kind == kind
	if kind == "map": return value is Dictionary and not value.has("$history_index")
	return value is Array

func rebuild_jobs(context: Dictionary) -> void:
	work_metrics = metrics
	data["jobs"] = from_value({}, "map")
	for job: Dictionary in context.get("queued", []): schedule_job(job)

func schedule_job(job: Dictionary) -> void:
	work_metrics = metrics
	var key: String = "%s|%012d|%s" % [job.phase, job.due, job.id]
	data["jobs"] = set_value(data.get("jobs", from_value({}, "map")), key, copy_current(job), "map")

func consume_job(job: Dictionary) -> void:
	work_metrics = metrics
	var key: String = "%s|%012d|%s" % [job.phase, job.due, job.id]
	data["jobs"] = erase(data.get("jobs", from_value({}, "map")), key)

static func _lower_rank(node: Dictionary, key: String) -> int:
	var rank: int = 0
	while not node.is_empty():
		_count("tree_nodes_read")
		if str(node.key) < key:
			rank += int(node.left.get("count", 0)) + 1
			node = node.right
		else: node = node.left
	return rank

func due_jobs(phase: String, turn: int) -> Array:
	work_metrics = metrics
	var jobs: Dictionary = data.get("jobs", from_value({}, "map"))
	var rank: int = _lower_rank(jobs.root, phase + "|")
	var result: Array = []
	while rank < size(jobs):
		var entry: Dictionary = at(jobs, rank)
		if not str(entry.key).begins_with(phase + "|") or int(entry.value.due) > turn: break
		result.append(entry.value.duplicate(true))
		rank += 1
		metrics.decision_reads += 1
	return result

func query(state: Dictionary, kind: String, owner: String, cursor: Dictionary = {}, limit: int = 0) -> Dictionary:
	work_metrics = metrics
	var count: int = page_limit if limit == 0 else limit
	if count < 1 or count > page_limit:
		return {"ok": false, "error": "Invalid authored query page size"}
	var source: Variant
	match kind:
		"person_knowledge":
			if not root_has(state.npcs, owner): return {"ok": false, "error": "Unknown person"}
			source = root_entry(state.npcs, owner).known_facts
		"person_relations":
			if not root_has(state.npcs, owner): return {"ok": false, "error": "Unknown person"}
			source = root_entry(state.npcs, owner).relations
		"institution_results":
			if not state.institutions.has(owner): return {"ok": false, "error": "Unknown institution"}
			source = _bucket("institution_results/" + owner)
		"institution_knowledge":
			if not state.institutions.has(owner): return {"ok": false, "error": "Unknown institution"}
			source = state.institutions[owner].known_facts
		"growth_sources":
			var parts: PackedStringArray = owner.split("|")
			if parts.size() != 2 or not root_has(state.npcs, parts[0]) or not root_entry(state.npcs, parts[0]).growth_sources.has(parts[1]): return {"ok": false, "error": "Unknown growth source scope"}
			source = root_entry(state.npcs, parts[0]).growth_sources[parts[1]]
		_:
			return {"ok": false, "error": "Unknown indexed query"}
	var offset: int = 0
	if not cursor.is_empty():
		if cursor.get("incarnation") != incarnation or cursor.get("version") != version or cursor.get("policy") != policy or cursor.get("kind") != kind or cursor.get("owner") != owner or not cursor.get("offset") is int:
			return {"ok": false, "error": "Stale or mismatched query cursor"}
		offset = cursor.offset
	if offset < 0 or offset > size(source): return {"ok": false, "error": "Invalid cursor offset"}
	var items: Array = []
	var end: int = mini(size(source), offset + count)
	for rank: int in range(offset, end):
		var entry: Dictionary = at(source, rank)
		items.append(entry.value.duplicate(true) if kind == "person_relations" else root_entry(state.facts, entry.key).duplicate(true))
		metrics.decision_reads += 1
	return {"ok": true, "items": items, "cursor": {"incarnation": incarnation, "version": version, "policy": policy, "kind": kind, "owner": owner, "offset": end}, "complete": end == size(source), "version": version, "policy": policy}

static func root_entry(value: Variant, key: Variant, fallback: Variant = null) -> Variant:
	if is_overlay(value):
		if value.removed.has(str(key)): return fallback
		if value.writes.has(str(key)): return value.writes[str(key)]
		return mapget(value.base, str(key), fallback)
	if is_history(value):
		if value.kind == "sequence": return at(value, int(key)).get("value", fallback)
		return mapget(value, str(key), fallback)
	return value.get(key, fallback) if value is Dictionary else (value[int(key)] if int(key) >= 0 and int(key) < value.size() else fallback)

static func root_has(value: Variant, key: Variant) -> bool:
	if is_overlay(value): return not value.removed.has(str(key)) and (value.writes.has(str(key)) or has(value.base, str(key)))
	return has(value, str(key)) if is_history(value) else value.has(key)

static func root_keys(value: Variant) -> Array:
	if is_overlay(value):
		var result: Dictionary = {}
		for key: String in keys(value.base): result[key] = true
		for key: String in value.removed: result.erase(key)
		for key: String in value.writes: result[key] = true
		return result.keys()
	return keys(value)

func add_prayer_source(state: Dictionary, source: String) -> void:
	if root_has(state.applied_authorizations, "prayer/source/" + source) or root_has(state.invalid_records, source): return
	_add("prayer_sources", source)

func drop_prayer_source(source: String) -> void:
	_drop("prayer_sources", source)

func add_relation(owner: String, item: Dictionary, state: Dictionary = {}) -> void:
	_add("relations/" + owner + "/" + str(item.target), str(item.source), item.duplicate(true))
	if item.get("kind") == "support": _add("support/" + owner, str(item.target), item.duplicate(true))
	if root_has(state.get("invalid_records", {}), str(item.source)): return
	var bucket: String = "relation_heads/" + owner + "/" + str(item.target) + "/" + str(item.kind)
	_add(bucket, str(item.source), item.duplicate(true))
	var entries: Array = mapget(data.get("relation_head_metadata", from_value({}, "map")), str(item.source), []).duplicate()
	if not bucket in entries: entries.append(bucket)
	data["relation_head_metadata"] = set_value(data.get("relation_head_metadata", from_value({}, "map")), str(item.source), entries, "map")

func relation_head(owner: String, target: String, kinds: Array) -> Dictionary:
	work_metrics = metrics; metrics.decision_reads += 1
	var result: Dictionary = {}
	for kind: String in kinds:
		var current: Dictionary = _bucket("relation_heads/" + owner + "/" + target + "/" + kind)
		if size(current) == 0: continue
		var entry: Dictionary = at(current, size(current) - 1)
		if result.is_empty() or str(entry.key) > str(result.source): result = entry.value
	return result.duplicate(true)

func relation(owner: String, target: String, source: String) -> Dictionary:
	work_metrics = metrics
	metrics.decision_reads += 1
	return mapget(_bucket("relations/" + owner + "/" + target), source, {}).duplicate(true)

func add_institution_result(state: Dictionary, source: String) -> void:
	if not root_has(state.facts, source): return
	var fact: Dictionary = root_entry(state.facts, source)
	var institution: Variant = fact.get("changes", {}).get("institution")
	if fact.get("kind") != "institution_event_result" or not institution is String or not state.institutions.has(institution) or state.institutions[institution].domain != fact.domain: return
	# This is a cold discovery index. Membership never grants recognition;
	# Anchors rechecks the exact typed proof and current state before any grant.
	_add("institution_results/" + institution, source)

func add_institution_restriction(state: Dictionary, source: String) -> void:
	if root_has(state.invalid_records, source) or not root_has(state.facts, source): return
	var fact: Dictionary = root_entry(state.facts, source)
	var institution: Variant = fact.get("changes", {}).get("institution")
	if fact.get("kind") != "institution_restriction" or not institution is String or not state.institutions.has(institution): return
	var scopes: Array = _ritual_denial_keys(state, fact)
	if scopes.is_empty(): _add("institution_restrictions/" + institution, source)
	else:
		for scope: String in scopes: _add("institution_ritual_restrictions/" + scope, source)

func sync_institution_restrictions(state: Dictionary) -> void:
	# Invalidations are immutable source keys. Only this transaction's writes
	# can change an existing current restriction; archived H is never walked.
	var invalidations: Variant = state.get("invalid_records", {})
	if not is_overlay(invalidations): return
	for source: String in invalidations.writes:
		if not root_has(state.facts, source): continue
		var fact: Dictionary = root_entry(state.facts, source)
		if fact.get("kind") == "institution_restriction":
			var bucket: String = "institution_restrictions/" + str(fact.changes.get("institution", ""))
			if has(_bucket(bucket), source): _drop(bucket, source)
			for scope: String in _ritual_denial_keys(state, fact): _drop("institution_ritual_restrictions/" + scope, source)

func institution_restriction(institution: String) -> String:
	work_metrics = metrics
	metrics.decision_reads += 1
	var current: Dictionary = _bucket("institution_restrictions/" + institution)
	return "" if size(current) == 0 else str(at(current, 0).key)

## Cold source discovery, not eligibility. Each bucket has a persistent turn tree;
## decisions read its last two turns, never an archived person's full history.
func add_event_record(state: Dictionary, source: String) -> void:
	if not root_has(state.facts, source): return
	var item: Dictionary = root_entry(state.facts, source)
	if item.kind == "event_publication": _index_event_publication(state, item)
	if root_has(state.invalid_records, source): return
	if item.kind == "institution_recognition_clear": add_institution_ritual_clear(state, source)
	if item.kind == "contract_inheritance_fixed":
		if item.changes.get("contract") is String: _add("event_inheritance/" + item.changes.contract, source)
	elif item.kind == "message" and item.changes.get("rule") == "prophet_will":
		if item.changes.get("prophet") is String and item.changes.get("prophet_source") is String: _add("event_will/" + item.changes.prophet + "/" + item.changes.prophet_source, source)
	var record: Dictionary = item
	var dependencies: Array = []
	if item.kind in ["exposure", "event_publication"]:
		var parent: String = str(item.changes.get("record", "")) if item.kind == "event_publication" else (str(item.causal_parents[0]) if item.causal_parents.size() == 1 else "")
		if not root_has(state.facts, parent) or root_has(state.invalid_records, parent): return
		dependencies.append(parent)
		record = root_entry(state.facts, parent)
		if record.kind == "exposure" and record.causal_parents.size() == 1 and root_has(state.facts, record.causal_parents[0]): record = root_entry(state.facts, record.causal_parents[0])
		if root_has(state.invalid_records, str(record.id)): return
	var institution: String = str(record.changes.get("institution", ""))
	var families: Array = []
	if record.kind == "prayer_fact":
		var tag: String = str(record.changes.get("tag", ""))
		if tag in ["private_testimony", "anomaly_record", "public_witness", "public_evidence", "exception_record", "exception_learned"]: families.append("evidence")
		if tag in ["ritual_witness", "public_ritual"]: families.append("ritual")
		if tag in ["exception_learned", "public_exception_qualification"]: institution = str(record.changes.get("subjects", {}).get("other_institution", ""))
		if tag in ["exception_record", "exception_learned", "public_exception_qualification"]:
			families.append("exception/" + str(record.changes.get("facts", {}).get("exception", "")))
	elif record.kind == "miracle" and record.changes.get("power") == "POWER_DREAM":
		for parent: String in record.causal_parents:
			if not root_has(state.facts, parent): continue
			var checked: Dictionary = root_entry(state.facts, parent)
			if checked.kind == "power_result":
				for cause: String in checked.causal_parents:
					if root_has(state.facts, cause) and root_entry(state.facts, cause).kind == "turn_check": checked = root_entry(state.facts, cause); break
			if checked.kind != "turn_check": continue
			for cause: String in checked.causal_parents:
				if not root_has(state.facts, cause): continue
				var attempt: Dictionary = root_entry(state.facts, cause)
				if attempt.kind == "power_attempt" and attempt.changes.get("power") == "POWER_DREAM": institution = str(attempt.changes.get("proofs", {}).get("dream", {}).get("institution", ""))
		families.append("dream")
	if families.is_empty() or not state.institutions.has(institution): return
	var persons: Array = record.targets.duplicate()
	if not str(record.actor).is_empty() and not record.actor in persons: persons.append(record.actor)
	for value: Variant in record.changes.get("subjects", {}).values():
		for person: Variant in (value if value is Array else [value]):
			if person is String and not person in persons: persons.append(person)
	var buckets: Array = []
	persons.append("") # institution-level exact exception query
	for person: Variant in persons:
		if not person is String or (not person.is_empty() and not root_has(state.npcs, person)): continue
		for family: String in families:
			if person.is_empty() and not family.begins_with("exception/"): continue
			var bucket: String = "event_records/" + institution + "/" + person + "/" + family
			var turn_key: String = "%012d" % int(record.turn)
			var turns: Dictionary = _bucket(bucket)
			var sources: Dictionary = mapget(turns, turn_key, from_value([]))
			_add(bucket, turn_key, set_value(sources, source))
			buckets.append({"bucket": bucket, "turn": turn_key})
	data["event_record_metadata"] = set_value(data.get("event_record_metadata", from_value({}, "map")), source, buckets, "map")
	if record.id != source and not str(record.id) in dependencies: dependencies.append(str(record.id))
	for dependency: String in dependencies:
		var dependents: Dictionary = mapget(data.get("event_record_dependents", from_value({}, "map")), dependency, from_value([]))
		data["event_record_dependents"] = set_value(data.get("event_record_dependents", from_value({}, "map")), dependency, set_value(dependents, source), "map")

func _drop_event_record(source: String) -> void:
	var metadata: Array = mapget(data.get("event_record_metadata", from_value({}, "map")), source, [])
	for entry: Dictionary in metadata:
		var sources: Dictionary = erase(mapget(_bucket(entry.bucket), entry.turn, from_value([])), source)
		if size(sources) == 0: _drop(entry.bucket, entry.turn)
		else: _add(entry.bucket, entry.turn, sources)

func sync_event_records(state: Dictionary) -> void:
	var invalidations: Variant = state.get("invalid_records", {})
	if not is_overlay(invalidations): return
	for source: String in invalidations.writes:
		if root_has(state.facts, source):
			var item: Dictionary = root_entry(state.facts, source)
			if item.kind == "institution_recognition_clear":
				for scope: String in _ritual_scope_keys(str(item.changes.get("institution", "")), {"priest": item.changes.get("priest", ""), "rituals": item.changes.get("rituals", [])}): _drop("institution_ritual_clears/" + scope, source)
			if item.kind == "contract_inheritance_fixed": _drop("event_inheritance/" + str(item.changes.get("contract", "")), source)
			elif item.kind == "message" and item.changes.get("rule") == "prophet_will": _drop("event_will/" + str(item.changes.get("prophet", "")) + "/" + str(item.changes.get("prophet_source", "")), source)
		for bucket: String in mapget(data.get("relation_head_metadata", from_value({}, "map")), source, []): _drop(bucket, source)
		_drop_event_record(source)
		var dependents: Dictionary = mapget(data.get("event_record_dependents", from_value({}, "map")), source, from_value([]))
		for wrapper: String in keys(dependents): _drop_event_record(wrapper)

func event_record_heads(institution: String, person: String, family: String) -> Array:
	work_metrics = metrics; metrics.decision_reads += 1
	var turns: Dictionary = _bucket("event_records/" + institution + "/" + person + "/" + family)
	var result: Array = []
	for offset: int in mini(2, size(turns)):
		var entry: Dictionary = at(turns, size(turns) - 1 - offset)
		var records: Dictionary = entry.value
		if size(records) > 0: result.append(str(at(records, size(records) - 1).key))
	return result

func event_inheritance(contract: String) -> Array:
	return _event_documents("event_inheritance/" + contract)

func event_will(prophet: String, prophet_source: String) -> Array:
	return _event_documents("event_will/" + prophet + "/" + prophet_source)

func _event_documents(bucket: String) -> Array:
	work_metrics = metrics; metrics.decision_reads += 1
	var documents: Dictionary = _bucket(bucket)
	var result: Array = []
	for offset: int in mini(page_limit, size(documents)):
		result.append(str(at(documents, size(documents) - offset - 1).key))
	return result

func _ritual_denial_keys(state: Dictionary, restriction: Dictionary) -> Array:
	for id: String in restriction.get("causal_parents", []):
		if not root_has(state.facts, id): continue
		var event: Dictionary = root_entry(state.facts, id)
		if event.kind != "institution_event_result" or event.changes.get("event") != "EVENT_04" or event.changes.get("option") != "B" or event.changes.get("institution") != restriction.changes.get("institution"): continue
		return _ritual_scope_keys(str(event.changes.institution), event.changes.get("basis", {}))
	return []

static func _ritual_scope_keys(institution: String, basis: Dictionary) -> Array:
	var rituals: Array = basis.get("rituals", [basis.ritual] if basis.has("ritual") else [])
	var priest: String = str(basis.get("priest", ""))
	var result: Array = []
	if priest.is_empty(): return result
	for ritual: Variant in rituals:
		if ritual is String and not ritual.is_empty(): result.append(institution + "/" + priest + "/" + ritual)
	return result

func add_institution_ritual_clear(state: Dictionary, source: String) -> void:
	if not root_has(state.facts, source) or root_has(state.invalid_records, source): return
	var cleared: Dictionary = root_entry(state.facts, source)
	var data: Dictionary = cleared.changes
	if cleared.kind != "institution_recognition_clear" or data.size() != 4 or not data.get("institution") is String or not data.get("priest") is String or not data.get("rituals") is Array or not data.get("grant") is String or not data.grant in cleared.causal_parents or not root_has(state.facts, data.grant): return
	var grant: Dictionary = root_entry(state.facts, data.grant)
	if grant.kind != "institution_event_result" or grant.changes.get("institution") != data.institution or grant.changes.get("event") != "EVENT_04" or grant.changes.get("option") != "A" or state.get("anchor_system", {}).get("issuers", {}).get(grant.changes.get("issuer", "")) != grant.changes.get("version"): return
	var keys: Array = _ritual_scope_keys(data.institution, {"priest": data.priest, "rituals": data.rituals})
	if keys.is_empty() or keys != _ritual_scope_keys(data.institution, grant.changes.get("basis", {})): return
	var actual: bool = false
	for parent: String in grant.causal_parents:
		if not root_has(state.facts, parent): continue
		var result: Dictionary = root_entry(state.facts, parent)
		if result.kind == "event_result" and result.changes.get("content_id") == "EVENT_04" and result.changes.get("option") == "A" and root_entry(state.applied_authorizations, "event/resolved/" + str(result.changes.get("event", "")), "") == parent: actual = true
	if not actual: return
	for scope: String in keys: _add("institution_ritual_clears/" + scope, source)

func institution_ritual_restriction(institution: String, priest: String, ritual: String, after: String = "") -> String:
	work_metrics = metrics; metrics.decision_reads += 1
	var node: Dictionary = _bucket("institution_ritual_restrictions/" + institution + "/" + priest + "/" + ritual).root
	var result: String = ""
	while not node.is_empty():
		_count("tree_nodes_read")
		if str(node.key) > after: result = str(node.key); node = node.left
		else: node = node.right
	return result

func institution_ritual_clear(institution: String, priest: String, ritual: String) -> String:
	work_metrics = metrics; metrics.decision_reads += 1
	var current: Dictionary = _bucket("institution_ritual_clears/" + institution + "/" + priest + "/" + ritual)
	return "" if size(current) == 0 else str(at(current, size(current) - 1).key)

func _index_event_publication(state: Dictionary, publication: Dictionary) -> void:
	var original: String = str(publication.changes.get("record", ""))
	if publication.changes.get("event") != "EVENT_02" or publication.changes.get("option") != "B" or not original in publication.causal_parents or not root_has(state.facts, original): return
	var actual: bool = false
	for parent: String in publication.causal_parents:
		if not root_has(state.facts, parent): continue
		var result: Dictionary = root_entry(state.facts, parent)
		if result.kind == "event_result" and result.changes.get("content_id") == "EVENT_02" and result.changes.get("option") == "B" and original in result.changes.get("descriptor", {}).get("facts", {}).get("records", []) and root_entry(state.applied_authorizations, "event/resolved/" + str(result.changes.get("event", "")), "") == parent: actual = true
	if not actual: return
	# Actual publication cannot be made secret again by withdrawing its wrapper.
	_add("event_publications/" + original, str(publication.id))
	var record: Dictionary = root_entry(state.facts, original)
	if record.kind == "exposure" and record.causal_parents.size() == 1 and root_has(state.facts, record.causal_parents[0]):
		_add("event_publications/" + str(record.causal_parents[0]), str(publication.id))

func event_record_public(source: String) -> bool:
	work_metrics = metrics; metrics.decision_reads += 1
	return size(_bucket("event_publications/" + source)) > 0
