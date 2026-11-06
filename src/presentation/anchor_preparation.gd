extends RefCounted
## Goal-bound, read-only planning. Only real legal reception that improves the
## selected institution is offered; no hypothetical fact is written to Session.
const Requirements = preload("res://src/presentation/gameplay_requirements.gd")
const Materials = preload("res://src/simulation/material_transfer.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Routes = preload("res://src/game/anchor_routes.gd")
const Store = preload("res://src/simulation/archive_store.gd")

class ReceptionPreview extends RefCounted:
	var history: RefCounted
	var state: Dictionary
	var recipient: String
	var source: String
	func fact(id: String) -> Dictionary: return {"ok":Store.has(state.facts, id), "item":Store.entry(state.facts, id, {})}
	func entity(kind: String, id: String) -> Dictionary: return {"ok":Store.has(state[kind], id), "item":Store.entry(state[kind], id, {})}
	func knows(person: String, record: String) -> bool:
		return (person == recipient and record == source) or history.knows(state, person, record)

static func plan(session, institution: String) -> Dictionary:
	var public: Dictionary = session.project()
	var office: Dictionary = Requirements.find(public, "institutions", institution)
	if office.is_empty() or not session.anchor_source_options(institution).is_empty(): return {}
	var state: Dictionary = session.world.state
	var history = session.world.history
	var domain: String = office.domain
	var known: Array = public.people.filter(func(p: Dictionary) -> bool: return p.domain == domain and p.status == "active")
	var options: Array = []
	for receiver: Dictionary in known:
		var recipient: Dictionary = Store.entry(state.npcs, receiver.id, {})
		if recipient.get("institution") != institution: continue
		for sender: Dictionary in known:
			if sender.id == receiver.id: continue
			if Materials.internal_channel(state, Store.entry(state.npcs, sender.id, {}), recipient).get("ok", false): options.append({"sender":sender.id,"recipient":receiver.id,"target_institution":institution,"grant":"custody"})
	if options.is_empty(): return {}
	var bases: Array = Anchors._candidate_bases(state, institution, session.catalog, history)
	var current: int = Requirements.independent_testimonies(session, institution, session.catalog.integer("testimony_required_witnesses")) if state.domains[domain].profile == "CIV_01" else -1
	for source: String in history.anchor_material_heads(domain, session.catalog.integer("collective_required_witnesses")):
		if not session.is_known_source(source): continue
		var resolved: Dictionary = Materials.resolve(state, source, session.catalog, history)
		if not resolved.get("ok", false) or resolved.row.custody != "1": continue
		for endpoint: Dictionary in options:
			var request: Dictionary = endpoint.duplicate(); request["source"] = resolved.source
			if not Materials.preview(state, request, session.catalog, history).get("ok", false): continue
			var reader := ReceptionPreview.new(); reader.history = history; reader.state = state; reader.recipient = request.recipient; reader.source = request.source
			var completes := false
			for basis: Dictionary in bases:
				var items: Dictionary = Anchors._basis_materials(state, basis, session.catalog, history)
				if not items.has(request.source) or not items.keys().all(func(id: String) -> bool: return session.is_known_source(id)): continue
				var visible := true
				for item: Dictionary in items.values():
					if not item.get("originals", []).all(func(id: String) -> bool: return session._identity_known(id)): visible = false; break
					item.owners = item.get("owners", []).filter(func(id: String) -> bool: return session._identity_known(id) and Requirements._public_custody(session, item, id))
				if not visible: continue
				items[request.source].owners.append(request.recipient)
				if Routes.evaluate_normalized(state, institution, basis, items, session.catalog, reader).get("allowed", false): completes = true; break
			# A useful partial testimony can be gathered before the other witness
			# exists. The count applies the same independence rules as completion.
			var next: int = Requirements.independent_testimonies(session, institution, session.catalog.integer("testimony_required_witnesses"), request) if current >= 0 else -1
			if not completes and next <= current: continue
			var preview: Dictionary = session.preview_action("cults/transfer_material", request)
			if not preview.get("ok", false): continue
			return {"selection":request,"before":current,"after":next,"complete":completes,"cost":preview.get("preview", {})}
	return {}
