extends "res://tools/echoes-art-master/production_manifest_probe.gd"
func run_ui() -> void:
	started = Time.get_ticks_msec()
	evidence = "/tmp/ui-manifest-final"
	var player := PlayerSession.new(evidence.path_join("large-check"))
	assert(player.continue_game(evidence.path_join("continued.json")).get("ok", false))
	player.slot = evidence.path_join("large-working.json")
	mount(player)
	app._large_text = true
	app._refresh()
	app._tasks.open_action("POWER_MANIFEST_CANCEL")
	assert(press("ExecuteDraft"))
	await shoot("06-large-confirm")
	game.free()
	quit()
