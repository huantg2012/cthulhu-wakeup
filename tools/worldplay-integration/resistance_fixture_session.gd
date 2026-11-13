extends "res://src/presentation/session.gd"
## Explicit initial-world fixture: two threatened worlds, before any receipt.
## All six systems and the real planner run normally. No pending plan injection.
func _build(seed_value: int, powers_revision: String = "", sustained_pollution := true) -> Dictionary:
	var content: RefCounted = Catalog.new()
	if not content.load_files("res://data", powers_revision, sustained_pollution): return {"ok":false}
	var fresh: RefCounted = World.new(content)
	if not fresh.generate_hybrid(seed_value): return {"ok":false}
	for id: String in ["DOMAIN-001","DOMAIN-002"]:
		fresh.state.domains[id].alert = int(content.tables.resistance_plans.RESIST_REPAIR.min_alert) + 5
		fresh.state.domains[id].barrier = 0
	fresh.history.rebuild(fresh.state)
	var clock: RefCounted = Turn.new(fresh)
	var issuers: Dictionary = Events.issuer_capability(content)
	issuers.merge(PlayerSources.issuer_capability(content))
	var services: Dictionary = {"economy": Economy.new(content, issuers), "cults": Cults.new(content), "relics": Relics.new(content, issuers), "powers": Powers.new(content, issuers), "prayers": Prayers.new(content, issuers), "anchors": Anchors.new(content, issuers), "events": Events.new(content), "resistance": Resistance.new(content), "endings": Endings.new(content), "player_sources": PlayerSources.new(content), "progression_routes": Progression.new(content)}
	for name: String in services:
		if not services[name].install(clock): return {"ok":false,"error":name}
	if not Opportunities.install(clock): return {"ok":false}
	var initial: Dictionary = clock.bootstrap_prayers(true)
	if not initial.get("ok",false): return initial
	return {"ok":true,"catalog":content,"world":fresh,"turn":clock,"modules":services}
