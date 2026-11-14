extends SceneTree
## Real seeded Session commits: signal isolation, idempotent replay, and no-dice actions.
const Session = preload("res://src/presentation/session.gd")
var seen: Array = []
func fail(message: String) -> void:
	push_error(message)
	quit(1)
func _initialize() -> void:
	var player := Session.new("user://dice-signal-check/%d" % Time.get_ticks_usec())
	player.checks_committed.connect(func(response: Dictionary):
		seen.append(response.duplicate(true))
		response.result.checks[0].roll = 999
	)
	if not player.start_new(1).get("ok",false): fail("new game"); return
	if player.turn.context.phase=="events": player.progress()
	if not seen.is_empty(): fail("startup emitted a roll"); return
	player.execute_action("invalid/dice-test")
	if not seen.is_empty(): fail("failed action emitted"); return
	var selected := ""
	for prayer: Dictionary in player.project().prayers:
		for choice: Dictionary in player.prayer_response_choices(prayer.id):
			if player.preview_action(choice.key).get("ok",false): selected=choice.key; break
		if not selected.is_empty(): break
	if selected.is_empty(): fail("no natural executable prayer"); return
	var result: Dictionary = player.execute_action(selected,{},true,"dice-signal-check")
	if not result.get("ok",false) or seen.size()!=1: fail("new commit not emitted exactly once"); return
	if int(result.result.checks[0].roll)<1 or int(result.result.checks[0].roll)>100: fail("observer mutated returned result"); return
	if seen[0].result.checks != result.result.checks: fail("signal is not committed public check"); return
	var state: String = player.turn.snapshot()
	var replay: Dictionary = player.execute_action(selected,{},true,"dice-signal-check")
	if not replay.get("ok",false) or seen.size()!=1 or player.turn.snapshot()!=state: fail("replay emitted, changed RNG or recommitted"); return
	for prayer: Dictionary in player.project().prayers:
		if prayer.status=="open":
			var dismissed: Dictionary=player.execute_action("prayer/"+str(prayer.id)+"/dismiss",{},true)
			if not dismissed.get("ok",false) or seen.size()!=1: fail("no-dice dismissal emitted"); return
			break
	print("DICE_SIGNAL_OK new_commit=1 replay=0 no_dice=0 observer_isolation=1")
	quit()
