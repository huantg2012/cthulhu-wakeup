extends "res://tools/worldplay-integration/probe.gd"
## Bounded visual path: real seed 1, isolated saves, formal main scene.
func run() -> void:
	output = "res://docs/art/visual-generation/production-evidence/card-unlock-pacing"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	auto_arrivals = false
	if not await setup(["--seed=1", "--keep-arrival"]): return
	if not require(app._arrival.visible, "Initial arrival did not open"): return
	if not require(app._arrival_model.counts.unlock == 4, "Initial arrival should show two powers and two genuinely available foundation activities"): return
	await create_timer(1.0).timeout # Capture after the accepted entrance/veil animation.
	await capture("initial-arrival")
	await press_key(KEY_ENTER)
	auto_arrivals = true
	if not await world(str(app.projection.domains[0].id)): return
	if not require(app._hand_cards.all(func(card: Dictionary) -> bool: return card.id != "POWER_APPOINT" and card.id != "anchor/bind"), "Premature function on native table"): return
	await capture("initial-table")
	if not await click("PowerIndex"): return
	if not require(app._deck.size() == 2, "Reference library differs from initial table"): return
	var requirements := app.find_child("LockedPowerRequirements", true, false) as ScrollContainer
	if not require(requirements != null and requirements.is_visible_in_tree(), "Missing locked requirement explanations"): return
	await capture("power-requirements")
	if not await click("Self"): return
	if not require(app._dialog == "task_subject", "Progress page did not open"): return
	for button: Node in app._surface.find_children("*", "Button", true, false):
		if not require(not "降临条件" in button.text and not "开始降临" in button.text, "Progress page bypassed manifestation discovery"): return
	await capture("manifest-locked")
	print("CARD_UNLOCK_NATIVE_OK ", checks, " checks; isolated seed 1 arrival/table/library")
	quit()
