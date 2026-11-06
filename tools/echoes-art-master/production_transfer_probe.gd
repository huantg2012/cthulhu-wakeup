extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const World = preload("res://src/simulation/world.gd")
const Scene = preload("res://src/presentation/production/game_root.tscn")
const Store = preload("res://src/simulation/archive_store.gd")
func _initialize() -> void: run.call_deferred()
# The input is an isolated copy of a real midgame save. Add a valid symmetric
# route between two existing known cults and select the initial check stream;
# neither a migration result nor a receipt is injected.
func package(body: Dictionary) -> String: return World.canonical({"body":body,"checksum":World.canonical(body).sha256_text()})
func press(app: Control, id: String) -> void:
	var b: Button = app.find_child(id,true,false); assert(b != null and not b.disabled, "missing " + id); b.pressed.emit()
func run() -> void:
	var outer: Dictionary = World._normalize_numbers(JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/ui-manifest/saves/ongoing.json")))
	var turn: Dictionary = World._normalize_numbers(JSON.parse_string(outer.body.snapshot))
	var world: Dictionary = World._normalize_numbers(JSON.parse_string(turn.body.world))
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var initial_state: int = rng.state
	while rng.randi_range(1, 100) > 40:
		rng.seed += 1; initial_state = rng.state
	world.body.randoms.checks.seed = str(rng.seed); world.body.randoms.checks.state = str(initial_state)
	world.body.state.domains["DOMAIN-001"].neighbors.append("DOMAIN-007")
	world.body.state.domains["DOMAIN-007"].neighbors.append("DOMAIN-001")
	turn.body.world = package(world.body); outer.body.snapshot = package(turn.body)
	var file := FileAccess.open("/tmp/transfer-ui-fixture-save.json",FileAccess.WRITE); file.store_string(package(outer.body)); file.close()
	var p = Session.new("/tmp/transfer-ui-check"); var loaded: Dictionary = p.continue_game("/tmp/transfer-ui-fixture-save.json"); assert(loaded.ok, str(loaded))
	p.slot="/tmp/transfer-ui-check.json"
	var select: Dictionary = {"domain":"DOMAIN-001", "npc":"NPC-00000007", "source":"FACT-00000041", "target_domain":"DOMAIN-007", "escort":4}
	var preview: Dictionary = p.preview_action("POWER_TRANSFER", select); assert(preview.ok)
	var faith: int = p.world.state.faith; var whispers: int = p.world.state.whispers
	# An existing legitimate office must not become an empty-office proof by editing it.
	var original: Dictionary = {}
	for id: String in Store.keys(p.world.state.facts):
		var fact: Dictionary = Store.entry(p.world.state.facts, id)
		if fact.get("kind") == "power_qualification" and fact.get("actor") == select.npc and fact.get("changes", {}).get("rule_id") == "SOURCE_DREAM_JOINED" and not str(fact.changes.get("institution", "")).is_empty(): original = fact; break
	assert(not original.is_empty() and p.modules.player_sources.valid_proof(p.world.state, original, null, false))
	var stripped: Dictionary = original.duplicate(true); stripped.changes.institution = ""
	assert(not p.modules.player_sources.valid_proof(p.world.state, stripped, null, false))
	var from_population: int = p.world.state.domains[select.domain].population; var to_population: int = p.world.state.domains[select.target_domain].population
	var game = Scene.instantiate(); var app: Control = game.get_node("Presentation/CanvasLayer/OverlayRoot"); app.session=p; root.add_child(game); app._close_surface()
	app._tasks.open_action("POWER_TRANSFER")
	for f: Dictionary in p.action_entry("POWER_TRANSFER", app._tasks.draft.selection).fields:
		if not select.has(f.key): continue
		if app._actions.fixed_evidence(f):
			assert(app._tasks.draft.selection.get(f.key) == select[f.key]); continue
		press(app,"ActionTab_"+f.key)
		if f.key == "escort":
			var s: SpinBox = app.find_child("Field_escort",true,false); s.value=select.escort; press(app,"Apply_escort"); continue
		var current: Dictionary = p.action_entry("POWER_TRANSFER",app._tasks.draft.selection)
		for field: Dictionary in current.fields:
			if field.key != f.key: continue
			for i: int in field.options.size():
				if field.options[i].id == select[f.key]: press(app,"Choice_"+f.key+"_"+str(i)); break
	assert(app._tasks.draft.selection == select)
	press(app,"ActionTab___outcomes"); press(app,"ExecuteDraft")
	assert(app._dialog == "receipt", p.turn.last_error)
	assert(Store.entry(p.world.state.npcs, select.npc).domain == select.target_domain)
	assert(p.world.state.faith == faith - int(preview.preview.faith) and p.world.state.whispers == whispers - int(preview.preview.whispers))
	assert(p.world.state.domains[select.domain].population == from_population - 5 and p.world.state.domains[select.target_domain].population == to_population + 5)
	var proof: Dictionary = {}
	for id: String in Store.keys(p.world.state.facts):
		var fact: Dictionary = Store.entry(p.world.state.facts, id)
		if fact.get("kind") == "power_qualification" and fact.get("actor") == select.npc and fact.get("domain") == select.target_domain and fact.get("changes", {}).get("rule_id") == "SOURCE_DREAM_JOINED": proof = fact; break
	assert(not proof.is_empty() and proof.changes.institution == "")
	assert(p.modules.player_sources.valid_proof(p.world.state, proof, null, false))
	var forged: Dictionary = proof.duplicate(true); forged.changes.institution = select.target_domain + "/interpretation"
	assert(not p.modules.player_sources.valid_proof(p.world.state, forged, null, false))
	forged = proof.duplicate(true); forged.changes.institution = select.domain + "/interpretation"
	assert(not p.modules.player_sources.valid_proof(p.world.state, forged, null, false))
	assert(p.save_game().ok)
	var reloaded = Session.new("/tmp/transfer-ui-reloaded"); var restored: Dictionary = reloaded.continue_game(p.slot)
	assert(restored.ok, str(restored))
	assert(Store.entry(reloaded.world.state.npcs, select.npc).domain == select.target_domain)
	print("TRANSFER_UI_REAL_MOVE_SAVE_AND_FORGERY_OK")
	game.free();quit()
