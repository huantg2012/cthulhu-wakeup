extends RefCounted
## Public provenance and card-carrier history. Never grants knowledge or action rights.
const Store = preload("res://src/simulation/archive_store.gd")

static func observe(session: RefCounted, records: Dictionary, restoring := false) -> void:
	var ledger: Dictionary = session.knowledge_snapshot()
	var identities: Dictionary = ledger.request_people.duplicate()
	identities.merge(ledger.known_people)
	var now: int = session.turn.context.turn
	for id: String in identities:
		if records.has(id): continue
		var provenance := _provenance(session, id, ledger)
		var first := now if not restoring else int(provenance.get("turn", -1))
		records[id] = {"first_turn": first, "source": provenance.get("source", ""), "reason": provenance.get("reason", "此前已与你建立联系。"), "prayer_turn": -1}
	# Keep the carrier for the entire discovery turn, even after dismissal or response.
	# Known-prayers includes closed receipts; open request arrays alone are insufficient.
	for request: Dictionary in ledger.known_prayers.values():
		var descriptor: Dictionary = request.get("descriptor", {})
		var card: Dictionary = request.get("card", {})
		var id := str(descriptor.get("subjects", card.get("subjects", {})).get("petitioner", ""))
		if not records.has(id): continue
		var visible := int(card.get("visible_turn", descriptor.get("visible_turn", -1)))
		if int(records[id].first_turn) == now and visible == now:
			records[id].prayer_turn = now
			records[id].reason = "通过求告「%s」与你建立联系。" % session.prayer_title(descriptor, card)

static func _provenance(session: RefCounted, id: String, ledger: Dictionary) -> Dictionary:
	var earliest := {}
	for event: Dictionary in ledger.known_events.values():
		var card: Dictionary = event.get("card", {})
		var descriptor: Dictionary = event.get("descriptor", {})
		var participants: Array = Array(descriptor.get("actors", card.get("actors", [])))
		for value: Variant in descriptor.get("subjects", {}).values():
			if value is String: participants.append(value)
			elif value is Array: participants.append_array(value)
		if id in participants:
			var source := str(card.get("fact", descriptor.get("source", "")))
			if ledger.known_facts.has(source):
				var at := int(Store.entry(session.world.state.facts,source,{}).get("turn",-1))
				if earliest.is_empty() or at < int(earliest.turn): earliest = {"source":source,"turn":at,"reason":"在事件「%s」中进入你的视野。" % session.event_title(descriptor)}
	var sources: Array = ledger.known_facts.keys()
	sources.sort()
	for source: String in sources:
		var fact: Dictionary = Store.entry(session.world.state.facts, source, {})
		if fact.is_empty(): continue
		var kind := str(fact.kind)
		var participants: Array = [str(fact.get("actor", ""))] + fact.get("targets", [])
		if kind.begins_with("prayer_space_"):
			participants = [str(fact.get("actor", ""))]
		if id not in participants: continue
		var reason := "在已公开的经历中与你建立联系。"
		if kind.begins_with("prayer_"): reason = "通过求告与你建立联系。"
		elif kind == "power_result" or kind == "power_attempt":
			reason = "你的%s触及了此人。" % session.catalog.display_tables.powers.get(fact.changes.get("power", ""), {}).get("name", "神意")
		elif kind.begins_with("event_"): reason = "在当地传来的事件中进入你的视野。"
		elif kind.begins_with("member_"): reason = "通过归信与你建立联系。"
		elif kind == "route_material": reason = "在共同经历中进入你的视野。"
		var at := int(fact.get("turn", -1))
		if earliest.is_empty() or at < int(earliest.turn): earliest = {"source": source, "turn": at, "reason": reason}
	return earliest

static func decorate(row: Dictionary, records: Dictionary, turn: int) -> void:
	var record: Dictionary = records.get(str(row.id), {})
	row["discovery"] = record.get("reason", "此前已与你建立联系。")
	row["discovery_turn"] = int(record.get("first_turn", -1))
	row["prayer_introduced"] = int(record.get("prayer_turn", -1)) >= 0
	row["prayer_carried"] = int(record.get("prayer_turn", -1)) == turn

static func valid(value: Variant, state: Dictionary, turn: int) -> bool:
	if not value is Dictionary: return false
	for id: String in value:
		var row: Variant = value[id]
		if not Store.has(state.npcs, id) or not row is Dictionary: return false
		if not row.get("first_turn") is int or not row.get("prayer_turn") is int or not row.get("reason") is String or not row.get("source") is String: return false
		if row.first_turn < -1 or row.first_turn > turn or row.prayer_turn < -1 or row.prayer_turn > turn: return false
		if row.prayer_turn >= 0 and row.prayer_turn != row.first_turn: return false
		if not row.source.is_empty() and not Store.has(state.facts, row.source): return false
	return true
