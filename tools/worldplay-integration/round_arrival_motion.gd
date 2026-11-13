extends "res://tools/worldplay-integration/probe.gd"
## Native Movie Maker capture; uses a copied real save and normal turn confirmation.
func run() -> void:
	auto_arrivals = false
	if not await setup(PackedStringArray(["--save="+OS.get_cmdline_user_args()[0],"--keep-arrival"])): return
	# Movie Maker uses the project's fixed 1280x720 canvas; do not resize its
	# capture surface to the normal screenshot probe's 1920x1080 window.
	root.size = Vector2i(1280,720)
	for frame: int in 3: await process_frame
	if not await click("EnterRound"): return
	if not await click("PhaseAction"): return
	if not await click("ConfirmEnd"): return
	while app._portraits.preparing or not app._arrival.visible: await process_frame
	print("ARRIVAL_MOVIE_START_FRAME ",Engine.get_process_frames())
	await create_timer(1.5).timeout
	if not await click("ArrivalGroup_prayer"): return
	await create_timer(1.5).timeout
	if not await click("ArrivalGroup_person"): return
	await create_timer(1.25).timeout
	print("ARRIVAL_MOVIE_END_FRAME ",Engine.get_process_frames())
	quit()
