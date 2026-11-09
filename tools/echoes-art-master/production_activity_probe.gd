extends "res://tools/anchor-production-closure/run.gd"
const Production = preload("res://src/presentation/production/game_root.tscn")
const PlayerSession = preload("res://src/presentation/session.gd")
var app: Control
var player: RefCounted
var evidence := ""
func _initialize() -> void:
	run_ui.call_deferred()
func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func shoot(name_value: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name_value + ".png"))
func execute() -> bool:
	var b: Button = app.find_child("ExecuteDraft", true, false)
	if not require(b != null and not b.disabled, "Unavailable " + str(app._tasks.draft)): return false
	b.pressed.emit()
	if app._dialog == "task_confirm":
		app.find_child("ConfirmAction", true, false).pressed.emit()
	return require(app._dialog == "receipt", "No receipt " + app._notice_text)
func run_ui() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		evidence = args[0]
		DirAccess.make_dir_recursive_absolute(evidence)
	var data := _fixture("record_dependency")
	if not require(not data.has("fixtureFailure"),"Preconditions rejected"): return
	data.timingStart = Time.get_ticks_msec()
	data.timingPrevious = data.timingStart
	data.timings = []
	player = PlayerSession.new("user://ui-late-controlled/%s" % Time.get_ticks_usec())
	player.world = data.world
	player.turn = data.turn
	player.catalog = catalog
	for name_value: String in ["economy", "cults", "relics", "powers", "prayers", "anchors", "events", "resistance", "endings", "player_sources"]:
		player.modules[name_value] = data[name_value]
	player.modules.progression_routes = data.routes
	player._refresh_knowledge(false)
	var game := Production.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = player
	root.add_child(game)
	app._close_surface()
	var chosen := {"domain":data.domain,"npc":data.actor,"operation":"ROUTE_RECORD_PRACTICE","source":data.source}
	for i: int in 2:
		app._tasks.open_action("route/context",chosen)
		app.find_child("ActionTab___requirements", true, false).pressed.emit()
		var progress_label: Label = app.find_child("Requirement_activity_success", true, false)
		if not require(progress_label != null and progress_label.get_meta("requirement").current == i, "Actual progress is not shown before action"): return
		if i == 1: await shoot("11-route")
		var preview: Dictionary = data.routes.preview(data.turn, chosen.operation, {"npc":data.actor,"source":data.source})
		if not require(preview.get("ok", false), "Practice preview rejected"): return
		if i == 1 and not require(preview.progress.npc == data.actor and preview.progress.uses.size() == 1, "Original participant or recorded prior round lost"): return
		# Use the same bounded check seeding as the existing fixture. Turn still produces the outcome.
		if preview.get("probability",-1) >= 0:
			for seed_value in range(1,101):
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_value
				if data.world.check_result(preview.probability, rng.randi_range(1,100)) == "success":
					data.world.randoms.checks.seed = seed_value
					break
		if not execute(): return
		var changed: Label = app.find_child("Requirement_activity_success", true, false)
		if not require(changed != null and changed.get_meta("requirement").current == i + 1 and changed.get_meta("requirement").previous == i, "Receipt failed to show actual progress increment"): return
		if i == 1: await shoot("11-route-complete")
		if i == 0:
			if not require(_next(data), "Activity next round failed"): return
			app._refresh()
	var permissions: Array = ActualAnchors.available(data.world.state, data.institution, catalog, data.world.history)
	if not require(permissions.size() == 1,"Two practices did not produce basis"): return
	print("ACTIVITY_OK two paid rounds preserved the original participant and produced one anchor basis")
	var proof: String = permissions[0].source
	var opportunity: String = str(data.world.state.anchor_system.opportunities.get(data.institution, ""))
	if not require(not opportunity.is_empty() and _next(data),"No real recovery opportunity"): return
	app._refresh()
	if not require(player.is_known_source(proof) and player.is_known_source(opportunity), "Actual produced basis and opportunity not exposed"): return
	if not knowledge_boundary(data, proof, opportunity): return
	app._tasks.open_action("opportunity/" + opportunity + "/recover", {"npc":data.guardian})
	app.find_child("ActionTab___requirements", true, false).pressed.emit()
	await shoot("12-recovery")
	if not execute(): return
	var existing: Array = app.projection.relics
	if not require(existing.size() == 1 and _next(data), "No publicly recovered relic"): return
	var relic_id: String = existing[0].id
	var carry := {"domain":data.domain, "relic":relic_id,"npc":data.guardian,"source":data.source}
	app._refresh()
	app._tasks.open_action("relic/equip",carry)
	if not execute() or not require(_next(data), "Carry round failed"): return
	app._refresh()
	carry.domain = data.domain
	app._tasks.open_action("relic/unequip",carry)
	if not execute(): return
	if not require(app.projection.relics[0].placement == "controlled" and _next(data), "Actual unload did not put relic in storage"): return
	app._refresh()
	app._tasks.open_action("relic/equip",carry)
	await shoot("13-equip")
	if not execute(): return
	if not require(app.projection.relics[0].holder == data.guardian and _next(data), "Actual carry did not restore holder"): return
	app._refresh()
	print("CARRY_OK real unload and equip")
	var before_sacrifice: Dictionary = app.projection
	app._tasks.open_action("POWER_SACRIFICE", {"domain":data.domain, "npc":data.guardian})
	var sacrifice_unlock: int = int(player.catalog.display_tables.powers.POWER_SACRIFICE.unlock_awakening)
	if int(app.projection.awakening) >= sacrifice_unlock:
		app.find_child("ActionTab_mode", true, false).pressed.emit()
		app.find_child("Choice_mode_0", true, false).pressed.emit()
		var selected: Dictionary = app._tasks.draft.selection.duplicate(true)
		app.find_child("ActionTab_npc", true, false).pressed.emit()
		app.find_child("Read_npc", true, false).pressed.emit()
		if not require(app._dialog == "task_related", "Related person did not replace action"): return
		app._tasks.back()
		if not require(selected.mode == "faith" and app._tasks.draft.selection == selected, "Reading changed selected mode or person"): return
	else:
		if not require(app.find_child("ExecuteDraft", true, false) == null and app._dialog == "task_action", "Locked sacrifice offered an execution"): return
	app._tasks.back()
	if not require(app.projection.whispers == before_sacrifice.whispers and app.projection.people == before_sacrifice.people, "Leaving preparation changed resources or person"): return
	var target := {"domain":data.domain,"npc":data.guardian,"institution":data.institution,"relic":relic_id,"source":proof,"qualification":proof}
	_seed(data, "POWER_ANCHOR", "success", target)
	app._tasks.open_subject("anchors", data.domain)
	app.find_child("AnchorGoal_" + str(data.institution).replace("/", "_"), true, false).pressed.emit()
	var prepare: Button = app.find_child("ConfigureAnchor", true, false)
	if not require(prepare != null and not prepare.disabled, "Legal goal must offer the preparation entry"): return
	await shoot("15-anchor-institution")
	prepare.pressed.emit()
	for key: String in ["npc", "relic"]:
		app.find_child("ActionTab_" + key, true, false).pressed.emit()
		var field: Dictionary = app._tasks._current_fields.filter(func(row: Dictionary) -> bool: return row.key == key)[0]
		var index: int = field.options.find_custom(func(option: Dictionary) -> bool: return option.id == target[key])
		if not require(index >= 0, "Original legal object is visible: " + key): return
		var choose: Button = app.find_child("Choice_%s_%s" % [key, index], true, false)
		for frame: int in range(60):
			if not choose.disabled: break
			await process_frame
		if not require(not choose.disabled, "Original legal object can be chosen: " + key): return
		choose.pressed.emit()
	await shoot("15-anchor-preparation")
	app.find_child("ActionTab___requirements", true, false).pressed.emit()
	if not require(app.find_child("Requirement_guardian", true, false).get_meta("requirement").current >= 1 and app.find_child("Requirement_medium", true, false).get_meta("requirement").current >= 1, "Legal anchor was shown missing its actual person or medium"): return
	await shoot("15-anchor")
	if not execute(): return
	if not require(app._world_id == data.domain and app._surface.has_node("LocalFocus"), "Anchor receipt must stay in the institution's world"): return
	app.find_child("Return", true, false).pressed.emit()
	if not require(app._dialog == "anchor_goal" and app.find_child("AnchorUpkeep", true, false) != null, "Result returns to institution with its own upkeep preview"): return
	if not require(_next(data), "Anchor settlement failed"): return
	app._refresh()
	if not require(app.projection.anchors.size() == 1, "UI anchor did not become public"): return
	print("ANCHOR_UI_OK actual activity -> known material -> recovery -> carry -> paid anchor")
	app._tasks.open_subject("budget")
	var anchor: String = app.projection.anchors[0].id
	app._tasks._pick_budget_anchor(anchor)
	await shoot("14-supplies")
	var before: Dictionary = app.projection.economy_plan.duplicate(true)
	var faith: int = app.projection.faith
	app._tasks._edit_supply(anchor,0)
	app.find_child("SaveSupply",true,false).pressed.emit()
	app.find_child("CancelSupply",true,false).pressed.emit()
	if not require(app.projection.economy_plan == before and app.projection.faith == faith,"Cancelled plan changed official data"): return
	app.find_child("SaveSupply",true,false).pressed.emit()
	app.find_child("ConfirmSupply",true,false).pressed.emit()
	if not require(anchor in app.projection.economy_plan.refuse_anchors and app.projection.faith == faith,"Registered plan changed current payment or ignored stop"): return
	app._tasks._edit_supply(anchor,0)
	app.find_child("SaveSupply",true,false).pressed.emit()
	app.find_child("ConfirmSupply",true,false).pressed.emit()
	if not require(anchor not in app.projection.economy_plan.refuse_anchors and app.projection.faith == faith,"Supply resume did not register"): return
	app._tasks.open_action("relic/unbind",{"domain":data.domain,"relic":relic_id,"source":data.source})
	var submit: Button = app.find_child("ExecuteDraft",true,false)
	if not require(submit != null and not submit.disabled,"Unbinding unavailable " + str(app._tasks.draft)): return
	submit.pressed.emit()
	if not require(app._dialog == "task_confirm","Unbind did not request confirmation"): return
	app.find_child("CancelAction",true,false).pressed.emit()
	if not require(app.projection.relics[0].placement == "bound" and app.projection.faith == faith,"Cancel altered bound relic or faith"): return
	var expected: Dictionary = player.economy_preview().get("preview", {})
	if not require(not expected.anchors.is_empty() and expected.anchors[0].fee > 0, "No payable forecast after resuming"): return
	var settled_turn: int = app.projection.turn
	app._close_surface()
	app._advance(true)
	var payments: Array = Store.values(data.world.state.facts).filter(func(fact: Dictionary) -> bool:
		return fact.turn == settled_turn and fact.kind == "economy_anchor_payment" and fact.changes.get("anchor") == anchor)
	if not require(not payments.is_empty(), "No authoritative anchor payment in settlement"): return
	print("SUPPLY_OK registration, cancel, resume, settlement; UNBIND_CANCEL_OK")

	game.free()
	quit()

func knowledge_boundary(data: Dictionary, proof: String, opportunity: String) -> bool:
	var Knowledge = preload("res://src/game/player_knowledge.gd")
	var ledger: Dictionary = player.knowledge_snapshot()
	var fact: Dictionary = Store.entry(data.world.state.facts, proof)
	var hidden_material := ""
	for parent: String in fact.causal_parents:
		var item: Dictionary = Store.entry(data.world.state.facts, parent)
		if item.kind in ["route_attempt", "route_progress"] and not require(not player.is_known_source(parent), "Private execution record was disclosed"): return false
		if item.kind == "route_material": hidden_material = parent
	var reader = Knowledge.new(data.world.state, data.turn.context, ledger, catalog, data.world.history)
	if not require(reader._basis_visible(fact), "Fully known material basis unavailable"): return false
	reader._known_facts.erase(hidden_material)
	if not require(not reader._basis_visible(fact), "Unknown required material was skipped"): return false
	reader._known_facts[hidden_material] = true
	reader._known_people.erase(data.actor)
	if not require(not reader._basis_visible(fact), "Unknown original participant was skipped"): return false
	if not require(Knowledge.validate_ledger(data.world.state, ledger, catalog).is_empty(), "Invalid public ledger after basis disclosure"): return false
	var before: Dictionary = player.knowledge_snapshot()
	player.project(); player.action_catalog(); player.preview_action("POWER_ANCHOR", {"domain":data.domain})
	if not require(before == player.knowledge_snapshot(), "Reading granted knowledge"): return false
	print("KNOWLEDGE_OK required material and participant remain gated; private traces stay hidden; reads are pure")
	return true
