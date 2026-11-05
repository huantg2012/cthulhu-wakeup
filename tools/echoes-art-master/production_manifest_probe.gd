extends "res://tools/echoes-art-master/production_manifest_fixture.gd"
## A finite production UI path: current full save -> start -> reload -> continue -> cancel.
const Production = preload("res://src/presentation/production/game_root.tscn")
var app: Control
var game: Node
var evidence: String
var checks: Array = []
var started: int

func _initialize() -> void:
	run_ui.call_deferred()

func need(ok: bool, message: String, details: Dictionary = {}) -> bool:
	checks.append({"check":message, "pass":ok, "details":details})
	print("MANIFEST_CHECK ", message, " ", ok)
	if not ok:
		finish(false)
		push_error(message)
	return ok

func finish(ok: bool) -> void:
	var file := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"pass" if ok else "fail", "engine":Engine.get_version_info().string,
		"seconds":float(Time.get_ticks_msec() - started) / 1000.0, "checks":checks,
		"scope":"Controlled preexisting nine-anchor source graph and knowledge, generated seed/profile, 80 faith and 20 insight; ordinary current Catalog and eleven production modules. No supplied manifestation step/payment, continuation, interruption or final outcome. Complete ordinary Session restoration and actual production UI handlers; no natural progression or final victory claim."}, "\t", true, true) + "\n")
	file.close()
	if is_instance_valid(game): game.free()
	quit(0 if ok else 1)

func press(id: String) -> bool:
	var button: Button = app.find_child(id, true, false)
	if not need(button != null and not button.disabled, "UI button " + id): return false
	button.pressed.emit()
	return true

func shoot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	if need(captured.get_size() == Vector2i(1920,1080), "1080p " + name_value):
		captured.save_png(evidence.path_join(name_value + ".png"))

func mount(player: RefCounted) -> void:
	if is_instance_valid(game): game.free()
	game = Production.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	app.session = player
	root.add_child(game)
	app._close_surface()

func save_copy(name_value: String) -> String:
	var path := evidence.path_join(name_value + ".json")
	if not need(app.session.save_game(path).get("ok", false), "save " + name_value): return ""
	# Further actions autosave into a disposable slot, leaving review checkpoints untouched.
	app.session.slot = evidence.path_join("working.json")
	return path

func restore(path: String, expected_snapshot: String = "", expected_knowledge: Dictionary = {}) -> bool:
	var before: String = app.session.turn.snapshot() if expected_snapshot.is_empty() else expected_snapshot
	var known: Dictionary = app.session.knowledge_snapshot()
	if not expected_knowledge.is_empty(): known = expected_knowledge
	var player := PlayerSession.new(evidence.path_join("working"))
	var loaded: Dictionary = player.continue_game(path)
	if not need(loaded.get("ok", false) and player.turn.snapshot() == before and player.knowledge_snapshot() == known,
		"ordinary Session restores exact turn and knowledge", {"path":path, "loaded":loaded, "sha256":FileAccess.get_sha256(path)}): return false
	player.slot = evidence.path_join("working.json")
	mount(player)
	return true

func run_ui() -> void:
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	evidence = args[0] if not args.is_empty() else "/tmp/ui-manifest-review"
	DirAccess.make_dir_recursive_absolute(evidence)
	root.title = "降临验收 · 独立存档"
	if args.has("--review"):
		var reviewing := PlayerSession.new(evidence.path_join("manual"))
		assert(reviewing.continue_game(evidence.path_join("ongoing.json")).get("ok", false))
		reviewing.slot = evidence.path_join("manual.json")
		mount(reviewing)
		app._tasks.open_subject("self")
		print("MANIFEST_REVIEW_READY")
		return
	mount(create_session(evidence.path_join("working")))
	var ready := save_copy("ready")
	if not restore(ready): return
	var cosmic: Dictionary = app.session.world.state.anchors["ANCHOR/DOMAIN-011/interpretation"]
	var chosen := {"domain":cosmic.domain, "npc":cosmic.guardian, "source":app.session.world.state.domains[cosmic.domain].origin,
		"cosmic_anchor":cosmic.id, "system_anchor":"ANCHOR/DOMAIN-007/interpretation"}
	app._tasks.open_action("POWER_MANIFEST", chosen)
	var preview: Dictionary = app.session.preview_action("POWER_MANIFEST", app._tasks.draft.selection)
	if not need(preview.get("ok", false), "legal initial manifestation preview", {"preview":preview}): return
	if not need(preview.preview.get("probability") == -1 and not preview.preview.has("outcomes"), "first payment hides final probabilities"): return
	await shoot("01-start")
	var before: String = app.session.turn.snapshot()
	if not press("ExecuteDraft") or not press("CancelAction"): return
	if not need(app.session.turn.snapshot() == before, "cancel initial confirmation is pure"): return
	var faith: int = app.session.world.state.faith
	var whispers: int = app.session.world.state.whispers
	if not press("ExecuteDraft") or not press("ConfirmAction"): return
	var first: Dictionary = app.session.world.state.power_system.manifest.duplicate(true)
	if not need(app._dialog == "receipt" and first.get("progress") == 1 and first.get("probability") == -1
		and faith - app.session.world.state.faith == int(catalog.tables.powers.POWER_MANIFEST.faith)
		and whispers - app.session.world.state.whispers == int(catalog.tables.powers.POWER_MANIFEST.whispers),
		"actual first payment and no premature final check", {"ritual":first, "faithBefore":faith, "faithAfter":app.session.world.state.faith}): return
	app._close_surface()
	app._advance(true)
	app._close_surface()
	if not need(app.session.turn.context.phase == "actions" and app.session.turn.context.turn == first.paid_turn + 1
		and app.session.world.state.power_system.manifest.get("progress") == 1, "ordinary next turn retains unpaid continuation"): return
	var ongoing := save_copy("ongoing")
	if not restore(ongoing): return
	app._tasks.open_subject("self")
	await shoot("02-ongoing")
	app._tasks.open_action("POWER_MANIFEST_CONTINUE")
	preview = app.session.preview_action("POWER_MANIFEST_CONTINUE", app._tasks.draft.selection)
	if not need(preview.get("ok", false), "loaded ongoing save offers continuation preview", {"preview":preview}): return
	if not need(preview.preview.get("probability") == -1 and not preview.preview.has("outcomes"), "second payment hides final probabilities"): return
	var row: Dictionary = app._actions.resolve_row(app._tasks, "POWER_MANIFEST_CONTINUE", app._tasks.draft.selection)
	var context_text: String = "\n".join(app._actions.context_lines(row, app._tasks.draft.selection, app._tasks.title))
	var confirmation: String = app._actions.confirmation_text(app._tasks, "POWER_MANIFEST_CONTINUE", app._tasks.draft.selection)
	if not need(context_text.contains("已付 1 / 3 轮") and context_text.contains("固定宇宙锚点") and context_text.contains("固定星系锚点")
		and confirmation.contains("本轮不作最终判定") and not confirmation.contains("苏醒设100"), "ongoing UI identifies paid progress, both anchors and current payment meaning"): return
	await shoot("03-continue")
	before = app.session.turn.snapshot()
	if not press("ExecuteDraft") or not press("CancelAction"): return
	if not need(app.session.turn.snapshot() == before, "cancel continuation confirmation is pure"): return
	faith = app.session.world.state.faith; whispers = app.session.world.state.whispers
	if not press("ExecuteDraft"): return
	var confirm: Button = app.find_child("ConfirmAction", true, false)
	confirm.pressed.emit()
	var paid: Dictionary = app.session.world.state.power_system.manifest.duplicate(true)
	before = app.session.turn.snapshot()
	confirm.pressed.emit()
	if not need(before == app.session.turn.snapshot(), "duplicate UI confirmation cannot charge twice"): return
	if not need(app._dialog == "receipt" and paid.get("progress") == 2 and paid.get("probability") == -1
		and faith - app.session.world.state.faith == catalog.integer("manifest_continue_faith")
		and whispers - app.session.world.state.whispers == catalog.integer("manifest_continue_whispers")
		and paid.npc == first.npc and paid.cosmic_anchor == first.cosmic_anchor and paid.system_anchor == first.system_anchor,
		"actual continuation pays once and preserves original subject and anchors", {"ritual":paid, "faithBefore":faith, "faithAfter":app.session.world.state.faith}): return
	var continued := save_copy("continued")
	if not restore(continued): return
	var second_snapshot: String = app.session.turn.snapshot()
	var second_knowledge: Dictionary = app.session.knowledge_snapshot()
	app._advance(true)
	app._close_surface()
	app._tasks.open_action("POWER_MANIFEST_CONTINUE")
	var final_preview: Dictionary = app.session.preview_action("POWER_MANIFEST_CONTINUE", app._tasks.draft.selection)
	if not need(final_preview.get("ok", false) and final_preview.preview.get("ritual_step") == catalog.integer("manifest_duration")
		and final_preview.preview.get("probability", -1) >= 0 and final_preview.preview.has("outcomes"),
		"actual third action window retains its final-check preview", {"preview":final_preview}): return
	# Inspect the last payment's real preview only; this UI batch does not pursue victory.
	if not restore(continued, second_snapshot, second_knowledge): return
	app._tasks.open_action("POWER_MANIFEST_CANCEL")
	before = app.session.turn.snapshot()
	if not press("ExecuteDraft"): return
	await shoot("04-cancel-confirm")
	if not press("CancelAction"): return
	if not need(app.session.turn.snapshot() == before, "back out of irreversible interruption leaves ritual and costs intact"): return
	faith = app.session.world.state.faith; whispers = app.session.world.state.whispers
	if not press("ExecuteDraft") or not press("ConfirmAction"): return
	var state: Dictionary = app.session.world.state
	if not need(app._dialog == "receipt" and state.power_system.manifest.is_empty() and state.power_system.completion.is_empty()
		and state.faith == faith and state.whispers == whispers and not state.attention.reservations.has(paid.token),
		"actual interruption removes ritual and releases reservation without refund", {"faith":faith,"whispers":whispers}): return
	await shoot("05-interrupted")
	var cancelled := save_copy("interrupted")
	if not restore(cancelled): return
	if not need(not app.session.preview_action("POWER_MANIFEST_CONTINUE").get("ok", false), "interrupted save cannot continue the old ritual"): return
	print("MANIFEST_UI_OK")
	finish(true)
