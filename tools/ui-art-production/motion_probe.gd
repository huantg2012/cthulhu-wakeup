extends "res://tools/ui-art-production/scene_probe.gd"
## Run with --write-movie /tmp/production.avi --fixed-fps 30.
## The gameplay state enters normally; the capture holds one complete continuous cycle.

func run() -> void:
	if not await setup(OS.get_cmdline_user_args()): return
	root.size = Vector2i(1280, 720)
	if not await wait_art("WorldArt"): return
	await process_frame
	var env: Control = app._atmosphere
	var phase_before: float = env.elapsed
	var before := Engine.get_process_frames()
	while Engine.get_process_frames() - before < 720:
		await process_frame
		var frame := Engine.get_process_frames() - before
		if frame == 222:
			await click("Menu")
		if frame == 276:
			await press_key(KEY_ESCAPE)
	var phase_after: float = env.elapsed
	print("MOTION_START_SEC ", float(before) / 30.0, " PHASE ", phase_before, " -> ", phase_after)
	quit()
