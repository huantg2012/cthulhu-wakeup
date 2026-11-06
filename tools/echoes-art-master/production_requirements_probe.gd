extends "res://tools/anchor-production-closure/run.gd"
const PlayerSession = preload("res://src/presentation/session.gd")
const RequirementModel = preload("res://src/presentation/gameplay_requirements.gd")
const ProductionScene = preload("res://src/presentation/production/game_root.tscn")
var player: RefCounted
var app: Control
var evidence := ""
func _initialize() -> void: run_ui.call_deferred()
func need(value: bool, label_value: String) -> bool:
	if not value: push_error(label_value); quit(1)
	return value
func capture(label_value: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label_value + ".png"))
func run_ui() -> void:
	if not OS.get_cmdline_user_args().is_empty(): evidence = OS.get_cmdline_user_args()[0]; DirAccess.make_dir_recursive_absolute(evidence)
	var data: Dictionary = _fixture("record_testimonies")
	if not need(not data.has("fixtureFailure"), "Legal initial fixture"): return
	data.timingStart = Time.get_ticks_msec(); data.timingPrevious = data.timingStart; data.timings = []
	player = PlayerSession.new("/tmp/ui-requirements-test")
	player.world = data.world; player.turn = data.turn; player.catalog = catalog
	for key: String in ["economy", "cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources"]: player.modules[key] = data[key]
	player.modules.progression_routes = data.routes
	player._refresh_knowledge(false)
	if not need(RequirementModel.independent_testimonies(player, data.institution, 2) == 0, "No invented starting evidence"): return
	var first: String = _observed_dream(data, data.guardian)
	player._refresh_knowledge(false)
	if not need(not first.is_empty() and RequirementModel.independent_testimonies(player, data.institution, 2) == 1, "First actual independent witness counts once"): return
	if not need(_next(data), "Next actual round"): return
	var second: String = _observed_dream(data, data.other)
	player._refresh_knowledge(false)
	if not need(not second.is_empty() and RequirementModel.independent_testimonies(player, data.institution, 2) == 1, "Unreceived remote evidence is not local progress"): return
	if not need(_next(data), "Transfer round"): return
	player._refresh_knowledge(false)
	var game: Node = ProductionScene.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot"); app.session = player
	root.add_child(game); app._close_surface()
	if not need(app.find_child("MaterialTransfer", true, false) == null, "No standalone transfer in world"): return
	if not need(not player.action_entries("").any(func(row: Dictionary) -> bool: return row.key == "cults/transfer_material"), "No standalone transfer in action index"): return
	var terms: Array = RequirementModel.activity({"原两项条款":[{"原记录":player.object_title(second)}]}, func(text: String) -> String: return app._actions.readable_reference(app._tasks, text))
	if not need(not str(terms[0].hint).contains("已知事实") and not str(terms[0].hint).contains(second.trim_prefix("FACT-")), "Activity help uses a readable event, not an internal record number"): return
	var selection: Dictionary = {"source":second, "sender":data.other, "recipient":data.guardian, "target_institution":data.institution, "grant":"custody"}
	var before: String = player.turn.snapshot()
	var knowledge: Dictionary = player.knowledge_snapshot()
	app._tasks.open_subject("anchors", data.domain)
	app.find_child("AnchorGoal_" + str(data.institution).replace("/", "_"), true, false).pressed.emit()
	if not need(app._dialog == "anchor_goal" and app.find_child("ActionTab_source", true, false) == null, "Goal replaces record/person configuration"): return
	for pass_number: int in 3:
		app._tasks.AnchorPreparation.plan(player, data.institution)
	if not need(before == player.turn.snapshot() and knowledge == player.knowledge_snapshot(), "Condition queries preserve world, RNG and knowledge"): return
	var quote: Dictionary = app._tasks.AnchorPreparation.plan(player, data.institution)
	if not need(quote.before == 1 and quote.after == 2, "Goal predicts actual useful progress"): return
	var whispers: int = player.project().whispers
	await capture("01-transfer-before")
	var execute: Button = app.find_child("GatherAnchorMaterial", true, false)
	if not need(execute != null and not execute.disabled, "Actual transfer executable"): return
	execute.pressed.emit()
	if not need(app._dialog == "receipt", "Transfer commits through ordinary UI"): return
	if not need(whispers - int(player.project().whispers) == int(quote.cost.whispers), "Goal charges exactly the displayed original cost"): return
	var paid: String = player.turn.snapshot()
	app._tasks._gather_anchor_material(data.institution, quote.selection)
	if not need(player.turn.snapshot() == paid, "Repeated goal click cannot pay twice"): return
	var progress: Label = app.find_child("Requirement_basis_records", true, false)
	if not need(progress != null and progress.get_meta("requirement").current == 2 and progress.get_meta("requirement").previous == 1, "Actual transfer updates independent evidence 1/2 to 2/2"): return
	var medium: Label = app.find_child("Requirement_medium", true, false)
	if not need(medium != null and medium.get_meta("requirement").current == 0, "Remaining relic gap stays visible in receipt"): return
	if not need(RequirementModel.independent_testimonies(player, data.institution, 2) == 2, "Receipt aliases never add a third witness"): return
	await capture("02-transfer-receipt")
	app.find_child("Return", true, false).pressed.emit()
	if not need(app._dialog == "anchor_goal" and app.find_child("GatherAnchorMaterial", true, false) == null, "Return to goal; no redundant transfer once materials complete"): return
	var receipts: Array = data.world.history.material_receipts(second)
	if not need(not receipts.is_empty(), "Actual receipt exists"): return
	var remembered: Dictionary = player._known_facts.duplicate(true)
	for id: String in receipts: player._known_facts.erase(id)
	if not need(RequirementModel.independent_testimonies(player, data.institution, 2) == 1, "Hidden custody never increases public count"): return
	player._known_facts = remembered
	var set: Dictionary = {"records":[first,first],"witnesses":[data.guardian,data.other]}
	var dup: Dictionary = ActualAnchors.evaluate(data.world.state, data.institution, {"route":"record_testimonies", "records":set.records, "witnesses":set.witnesses}, catalog, data.world.history)
	if not need(not dup.allowed, "Original evaluator still rejects duplicate roots"): return
	app._large_text = true
	app._show_receipt()
	await capture("03-transfer-receipt-large")
	for node: Node in _labels(app):
		if node.name.begins_with("RequirementValue_") and not need(node.get_minimum_size().x <= node.size.x + 1, "Large requirement value fits"): return
	print("REQUIREMENTS_OK actual independent evidence, custody, receipt delta, remaining gaps, hidden records, read purity, large type")
	game.free(); quit()
func _labels(node: Node) -> Array:
	var result: Array = [node] if node is Label else []
	for child: Node in node.get_children(): result.append_array(_labels(child))
	return result

# The native fixture supplies initial dream qualifications. Use the already
# known world contact as command source so Turn publishes each actual result
# through its normal knowledge reducer; no result or knowledge is injected.
func _observed_dream(data: Dictionary, person: String) -> String:
	var payload: Dictionary = {"npc":person, "source":data.source, "qualification":data.dreams[person]}
	_seed(data, "POWER_DREAM", "success", payload)
	var first: int = data.world.state.next_fact
	var result: Dictionary = _power(data, "POWER_DREAM", payload)
	if not need(result.get("ok", false), "Actual dream production"): return ""
	player._refresh_knowledge(false)
	for fact: Dictionary in _facts(data.world, "miracle"):
		if int(str(fact.id).trim_prefix("FACT-")) >= first: return fact.id
	return ""
