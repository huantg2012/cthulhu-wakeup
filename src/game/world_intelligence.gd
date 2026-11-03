extends RefCounted
## Knowledge precision, not risk bands. Ranges never retain the hidden total.
const FIELDS: Array[String] = ["barrier", "pollution", "alert", "stability"]
const Store = preload("res://src/simulation/archive_store.gd")

static func first_observation(domain: Dictionary, catalog: RefCounted, source: String, context: Dictionary, observed_sequence: int) -> Dictionary:
	var result: Dictionary = {}
	for field: String in FIELDS:
		for band: Dictionary in catalog.tables.world_intelligence_bands.values():
			if int(domain[field]) < int(band.lower) or int(domain[field]) > int(band.upper): continue
			result[field] = {"precision": "range", "band_id": str(band.id), "bands_version": str(catalog.extension_versions.world_intelligence_bands), "lower": int(band.lower), "upper": int(band.upper), "label": str(band.label), "source": source, "turn": int(context.turn), "observed_turn": int(context.turn), "observed_sequence": observed_sequence, "phase": str(context.phase)}
			break
	return result

static func observed_fact(fact: Dictionary) -> Dictionary:
	# A delta or an arbitrary known fact is not an observation of a total.
	if fact.kind == "message" and fact.changes.get("observation_version") == "world-observation/1": return fact.changes.get("intelligence", {}).duplicate(true)
	if fact.kind == "world_observation" and fact.changes.get("version") == "world-observation/1":
		var result: Dictionary = {}
		for field: String in FIELDS:
			result[field] = {"precision": "exact", "value": int(fact.changes.metrics[field]), "source": str(fact.id), "turn": int(fact.turn), "observed_turn": int(fact.turn), "observed_sequence": int(str(fact.id).trim_prefix("FACT-")), "phase": str(fact.changes.phase), "label": "最后获知"}
		return result
	if fact.kind != "resistance_breach" or not fact.changes.get("barrier") is int: return {}
	return {"barrier": {"precision": "exact", "value": int(fact.changes.barrier), "source": str(fact.id), "turn": int(fact.turn), "observed_turn": int(fact.turn), "observed_sequence": int(str(fact.id).trim_prefix("FACT-")), "phase": "unrecorded", "label": "最后获知"}}

static func exact_value(record: Dictionary) -> Variant:
	# Existing saves stored typed resistance_breach observations before precision
	# was explicit. Keep their exact value without inventing missing observations.
	if record.get("precision", "exact") == "exact" and record.get("value") is int: return record.value
	return null

static func newer(candidate: Dictionary, previous: Dictionary) -> bool:
	if previous.is_empty(): return true
	var candidate_turn: int = int(candidate.get("observed_turn", candidate.get("turn", 0)))
	var previous_turn: int = int(previous.get("observed_turn", previous.get("turn", 0)))
	if candidate_turn != previous_turn: return candidate_turn > previous_turn
	var candidate_sequence: int = int(candidate.get("observed_sequence", str(candidate.source).trim_prefix("FACT-")))
	var previous_sequence: int = int(previous.get("observed_sequence", str(previous.source).trim_prefix("FACT-")))
	if candidate_sequence != previous_sequence: return candidate_sequence > previous_sequence
	if previous.get("precision", "exact") == "range" and candidate.get("precision") == "exact": return true
	if previous.get("precision", "exact") == "exact" and candidate.get("precision") == "range": return false
	return str(candidate.source) > str(previous.source)

static func valid_snapshot(state: Dictionary, snapshot: Dictionary, catalog: RefCounted) -> bool:
	if snapshot.get("kind") != "world_observation" or snapshot.changes.get("version") != "world-observation/1" or snapshot.changes.get("sources_version") != catalog.extension_versions.world_observation_sources: return false
	var data: Dictionary = snapshot.changes
	if not data.get("metrics") is Dictionary or data.metrics.size() != FIELDS.size() or not data.get("phase") is String or str(data.phase).is_empty() or not data.get("sources") is Array or data.sources.is_empty() or not data.get("roots") is Array or data.roots.is_empty(): return false
	for field: String in FIELDS:
		if not data.metrics.get(field) is int or data.metrics[field] < catalog.integer("attribute_min") or data.metrics[field] > catalog.integer("attribute_max"): return false
	for source: Variant in data.sources:
		if not source is String or not source in snapshot.causal_parents or source >= snapshot.id: return false
		var origin: Dictionary = Store.entry(state.facts, source, {})
		if origin.get("domain") != snapshot.domain: return false
	var message: Dictionary = Store.entry(state.facts, "FACT-%08d" % (int(str(snapshot.id).trim_prefix("FACT-")) + 1), {})
	if message.get("kind") != "message" or message.domain != snapshot.domain or message.changes.get("fact") != snapshot.id or message.changes.get("observation_version") != "world-observation/1" or not snapshot.id in message.causal_parents: return false
	for root: Variant in data.roots:
		if not root is String or not Store.has(state.facts, root) or root >= snapshot.id or Store.entry(state.applied_authorizations, observation_source_key(str(snapshot.domain), root), "") != message.id: return false
	return true

static func observation_source_key(domain: String, root: String) -> String:
	return "world/observation/source/" + domain + "/" + root

static func validate(state: Dictionary, ledger: Dictionary, catalog: RefCounted) -> Array[String]:
	for domain: String in ledger.domain_intelligence:
		if not ledger.known_domains.has(domain) or not ledger.domain_intelligence[domain] is Dictionary: return ["World intelligence requires a known world"]
		for field: String in ledger.domain_intelligence[domain]:
			var record: Variant = ledger.domain_intelligence[domain][field]
			if field not in FIELDS or not record is Dictionary: return ["Invalid world intelligence field"]
			if not record.get("source") is String or not ledger.known_facts.has(record.source): return ["World intelligence requires a known source"]
			var fact: Dictionary = Store.entry(state.facts, record.source, {})
			if fact.get("domain") != domain or not record.get("turn") is int or int(record.turn) < int(fact.turn) or int(record.turn) > int(state.turn): return ["Invalid world intelligence provenance"]
			if record.has("observed_turn") and record.observed_turn != record.turn: return ["Invalid world observation time"]
			if record.has("observed_sequence") and (not record.observed_sequence is int or record.observed_sequence < 1 or record.observed_sequence >= int(state.next_fact)): return ["Invalid world observation sequence"]
			match str(record.get("precision", "exact")):
				"range":
					if record.get("bands_version") != catalog.extension_versions.world_intelligence_bands or not record.get("band_id") is String or not catalog.tables.world_intelligence_bands.has(record.band_id): return ["Incompatible world intelligence precision policy"]
					var band: Dictionary = catalog.tables.world_intelligence_bands[record.band_id]
					if record.has("value") or not record.get("lower") is int or not record.get("upper") is int or record.lower != int(band.lower) or record.upper != int(band.upper) or record.get("label") != band.label: return ["World intelligence range disagrees with authored precision"]
					if not record.get("observed_turn") is int or not record.get("observed_sequence") is int or not record.get("phase") is String or str(record.phase).is_empty(): return ["Missing world observation provenance"]
					if record.has("observation"):
						var observed: Dictionary = Store.entry(state.facts, str(record.observation), {})
						if not valid_snapshot(state, observed, catalog) or fact.kind != "message" or fact.changes.get("fact") != observed.id or fact.changes.get("intelligence", {}).get(field) != record: return ["World estimate requires its frozen observation message"]
						if record.observed_sequence != int(str(observed.id).trim_prefix("FACT-")) or record.turn != observed.turn or record.phase != observed.changes.phase or observed.changes.metrics[field] < record.lower or observed.changes.metrics[field] > record.upper: return ["World estimate contradicts its observation"]
					elif record.observed_sequence < int(str(record.source).trim_prefix("FACT-")): return ["World estimate precedes its source"]
				"exact":
					if fact.kind == "world_observation":
						if not valid_snapshot(state, fact, catalog) or record.get("value") != fact.changes.metrics.get(field) or record.get("phase") != fact.changes.phase or record.turn != fact.turn: return ["Invalid precise world snapshot"]
						var message_id: String = "FACT-%08d" % (int(str(fact.id).trim_prefix("FACT-")) + 1)
						if not ledger.known_facts.has(message_id): return ["Precise world snapshot requires its known clue"]
					elif fact.kind != "resistance_breach" or field != "barrier" or not record.get("value") is int or record.value != fact.changes.get("barrier") or record.turn != fact.turn: return ["Invalid exact world observation"]
					if record.has("observed_sequence") and record.observed_sequence != int(str(fact.id).trim_prefix("FACT-")): return ["Exact observation sequence disagrees with its fact"]
					if fact.kind == "resistance_breach" and record.has("phase") and record.phase != "unrecorded": return ["Exact observation cannot invent its unrecorded phase"]
				_: return ["Invalid world intelligence precision"]
	return []
