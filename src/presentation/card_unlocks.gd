extends RefCounted
## Persistent discovery of functional cards. These are structural prerequisites,
## not execution permission: no fees, rolls, temporary budgets or RNG are touched.
const Store = preload("res://src/simulation/archive_store.gd")
const Selectors = preload("res://src/game/entry_selectors.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Capabilities = preload("res://src/game/prayer_capabilities.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const RitualIntervention = preload("res://src/game/ritual_intervention.gd")
const VERSION := 1
var rules: Dictionary = {}
var _sources: Dictionary = {}
var _records: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open("res://data/card_unlocks.csv", FileAccess.READ)
	assert(file != null, "Missing card unlock policy")
	assert(Array(file.get_csv_line()) == ["id", "rule", "description"], "Invalid card unlock columns")
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		assert(cells.size() == 3 and not rules.has(cells[0]), "Invalid card unlock row")
		rules[cells[0]] = {"rule": cells[1], "description": cells[2]}

func observe(session: RefCounted, projection: Dictionary, unlocked: Dictionary) -> void:
	if unlocked.size() == rules.size(): return
	_sources.clear()
	_records.clear()
	var needs_routes: bool = rules.keys().any(func(id: String) -> bool: return id.begins_with("ROUTE_") and not unlocked.has(id))
	var view: Dictionary = session.turn._read_view("powers", "actions")
	var context: Dictionary = Selectors.context(view, session.knowledge_snapshot(), session.modules)
	# Hydrate only visible identities; neither unseen people nor unknown worlds
	# can unlock a card or disclose that such a prerequisite exists elsewhere.
	for person: Dictionary in projection.people:
		var found: Dictionary = view.reader.entity("npcs", str(person.id))
		if found.get("ok", false): context.world.npcs[person.id] = found.item
	for domain: Dictionary in projection.domains:
		if domain.has("已知范围"): continue
		var local: Array = []
		for person: Dictionary in projection.people:
			if person.get("domain") == domain.id and not person.has("已知范围"):
				var actual: Dictionary = Store.entry(context.world.npcs, str(person.id), {})
				if actual.get("status") == "active": local.append(actual)
		var cult: Dictionary = {}
		for known: Dictionary in projection.cults:
			if known.get("domain") == domain.id and known.get("status") != "destroyed": cult = known; break
		var operations: Array = []
		if needs_routes:
			operations = _activity_options(context, str(domain.id)).map(func(option: Dictionary): return option.id)
		for id: String in rules:
			if unlocked.has(id): continue
			if id.begins_with("POWER_"):
				if int(projection.awakening) < int(session.catalog.tables.powers[id].unlock_awakening): continue
			elif id not in operations: continue
			if _ready(context, projection, str(domain.id), cult, local, id):
				unlocked[id] = {"turn": int(projection.turn), "domain": str(domain.id)}
	view.reader.close()

func activity_options(session: RefCounted, domain: String) -> Array:
	# A card catalogue is also read during the event phase by round arrivals.
	# Query its structural scope without pretending the current phase is actions.
	var view: Dictionary = session.turn._read_view("powers", "actions")
	var context: Dictionary = Selectors.context(view, session.knowledge_snapshot(), session.modules)
	var result := _activity_options(context, domain)
	view.reader.close()
	return result

static func _activity_options(context: Dictionary, domain: String) -> Array:
	if not context.knowledge.known_domains.has(domain): return []
	# Explicitly no actor: the selector must not auto-pick the sole remaining
	# person and thereby remove an already discovered activity from the deck.
	for field: Dictionary in Selectors._route_fields(context, {"domain": domain, "npc": ""}):
		if field.key == "operation": return field.options
	return []

func _member(context: Dictionary, person: Dictionary) -> bool:
	return person.get("bound_member", false) and int(person.get("loyalty", 0)) >= context.catalog.integer("loyalty_follower_threshold")

func _source(context: Dictionary, domain: String, rule: String, actor := "") -> bool:
	var key := domain + "/" + rule
	if not _sources.has(key): _sources[key] = Selectors._source_options(context, domain, rule)
	if actor.is_empty(): return not _sources[key].is_empty()
	return _sources[key].any(func(option: Dictionary) -> bool: return Selectors._fact(context,str(option.id)).changes.get("actor") == actor)

func _linked(context: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	if a.institution == b.institution: return true
	return b.institution in context.world.institutions[a.institution].get("links", []) and a.institution in context.world.institutions[b.institution].get("links", [])

func _owned(context: Dictionary, person: Dictionary, custody := false) -> Array:
	var key := str(person.id) + ("/custody" if custody else "/knowledge")
	if _records.has(key): return _records[key]
	var result: Array = []
	for id: String in context.knowledge.known_facts:
		var material: Dictionary = Materials.resolve(context.world, id, context.catalog, context.reader)
		if not material.get("ok", false) or material.material.kind not in ["evidence", "dream"]: continue
		if not Materials.possession(context.world, str(person.id), material, "custody" if custody else "knowledge", context.catalog, context.reader).is_empty(): result.append(material.material.root)
	_records[key] = result
	return result

func _ready(context: Dictionary, projection: Dictionary, domain: String, cult: Dictionary, people: Array, id: String) -> bool:
	var rule: String = rules[id].rule
	var members: Array = people.filter(func(p: Dictionary) -> bool: return _member(context, p))
	var active_cult: bool = not cult.is_empty() and cult.get("status") == "active"
	match rule:
		"listen": return _source(context, domain, "listen")
		"dream": return people.any(func(p: Dictionary) -> bool: return _source(context, domain, "dream", str(p.id)))
		"member": return not members.is_empty()
		"appointment":
			# A dormant organisation also needs this recovery action.
			return not cult.is_empty() and members.any(func(p: Dictionary) -> bool: return Capabilities.allows(context.world, str(p.id), Capabilities.OFFICE_HOLDING))
		"tenure", "spread", "evidence", "weakness":
			if rule != "weakness" and not active_cult: return false
			return members.any(func(p: Dictionary) -> bool: return _source(context, domain, rule, str(p.id)))
		"transfer":
			if members.is_empty(): return false
			for receiver: Dictionary in projection.cults:
				if receiver.get("status") == "active" and receiver.domain in context.world.domains[domain].neighbors and context.knowledge.known_domains.has(receiver.domain): return true
			return false
		"manifest":
			for cosmic: Dictionary in projection.anchors:
				if cosmic.get("domain") != domain or not context.knowledge.known_people.has(str(cosmic.get("guardian", ""))): continue
				for system: Dictionary in projection.anchors:
					if context.knowledge.known_domains.has(system.domain) and context.modules.powers.manifest_configuration_valid(context.world, {"cosmic_anchor":cosmic.id,"system_anchor":system.id,"npc":cosmic.guardian}): return true
			return false
		"anchor":
			if not active_cult or people.is_empty(): return false
			var media: Array = projection.relics.filter(func(r: Dictionary) -> bool: return r.get("domain") == domain and r.get("placement") in ["controlled", "carried", "bound"])
			if media.is_empty(): return false
			for office: String in context.world.domains[domain].institutions:
				if Selectors._anchor_sources(context, office).is_empty(): continue
				for person: Dictionary in people:
					if not context.modules.cults.eligible(context.world, person, context.catalog): continue
					if not Capabilities.allows(context.world, str(person.id), Capabilities.OFFICE_HOLDING): continue
					for medium: Dictionary in media:
						if context.modules.powers.anchor_assignment_error(context.world, office, str(person.id), str(medium.id)).is_empty(): return true
			return false
		"devotion":
			return people.any(func(p: Dictionary) -> bool: return (p.get("bound_member", false) or int(p.loyalty) >= context.catalog.integer("loyalty_follower_threshold")) and Knowledge.known(context.world, str(p.id), {}, context.reader).get("known", false))
		"gathering": return not members.is_empty() and int(context.world.domains[domain].unnamed_nonfollowers) > 0
		"ritual": return people.any(func(p: Dictionary) -> bool: return not RitualIntervention.sources(context.world, p, context.knowledge.known_facts, context.catalog, context.reader).is_empty())
		"record_keeper":
			for person: Dictionary in people:
				if "record_keeper" in person.role_tags: return true
				var grant := Capabilities.grant_source(context.world, str(person.id), Capabilities.RECORD_PRACTICE)
				if context.knowledge.known_facts.has(grant) and Capabilities.practice_supported(context.world, person, context.catalog, str(context.catalog.tables.progression_route_operations[id].mode)): return true
			return false
		"cosmic": return not people.is_empty() and context.world.domains[domain].tier == "cosmic"
		"exception":
			if people.is_empty() or context.world.domains[domain].tier != "cosmic": return false
			return Selectors._kind(context,"exception").any(func(source: String) -> bool: return Selectors._fact(context,source).get("domain") == domain and not context.reader.invalidated(source))
		"circle":
			for host: Dictionary in people:
				if context.world.institutions[host.institution].role != "interpretation" or _owned(context,host).is_empty(): continue
				var others: Array = people.filter(func(p: Dictionary) -> bool: return p.id != host.id and _linked(context,host,p))
				if others.size() >= context.catalog.integer("collective_required_witnesses"): return true
			return false
		"joint", "transmission", "pair_record", "pact", "reciprocal", "network":
			for first: Dictionary in people:
				for second: Dictionary in people:
					if first.id == second.id or not _linked(context,first,second): continue
					match rule:
						"joint":
							for need: String in first.need_tags:
								if need in second.need_tags: return true
						"transmission":
							if "ritual_keeper" in first.role_tags and not context.reader.contact_context(first.id,second.id).is_empty() and not context.reader.relation_between(first.id,second.id,["support","cooperation"]).is_empty(): return true
						"pair_record":
							if not _owned(context,first).is_empty(): return true
						"pact":
							if not _owned(context,first,true).is_empty(): return true
						"network":
							if first.institution != second.institution and first.get("bound_member",false) and second.get("bound_member",false): return true
						"reciprocal":
							if first.institution == second.institution: continue
							for root: String in _owned(context,first,true):
								if _owned(context,second,true).any(func(other: String) -> bool: return root != other): return true
			return false
	push_error("Unknown card unlock predicate: " + rule)
	return false

func valid(payload: Variant, turn: int, domains: Dictionary) -> bool:
	if not payload is Dictionary or payload.get("version") != VERSION or not payload.get("entries") is Dictionary: return false
	for id: Variant in payload.entries:
		if not id is String or not rules.has(id): return false
		var record: Variant = payload.entries[id]
		if not record is Dictionary or not record.get("turn") is int or record.turn < 0 or record.turn > turn or not record.get("domain") is String or not domains.has(record.domain): return false
	return true
