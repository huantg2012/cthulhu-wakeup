extends SceneTree
## Read the real first-cult campaign through Session; do not manufacture requests.
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const EXAMPLE := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
const DIRECTORY := "res://.godot/ui-prayer-diagnostic"
const COPY := DIRECTORY + "/first-cult.json"
var result: Dictionary = {"steps": []}

func _initialize() -> void:
	_run.call_deferred()

func _capture(session: RefCounted, label_value: String) -> void:
	var state: Dictionary = session.world.state
	var cards: Array = []
	for id: String in state.simulation.candidates:
		var card: Dictionary = state.simulation.candidates[id]
		cards.append({"id": id, "content": card.content_id, "domain": card.domain, "visible": card.visible_turn, "due": card.due_turn})
	result.steps.append({"label": label_value, "turn": session.turn.context.turn, "phase": session.turn.context.phase, "projected_prayers": session.project().prayers, "offered": state.prayer_system.offered.duplicate(), "requests": state.prayer_system.requests.keys(), "candidates": cards, "next_generation": state.simulation.cursors.duplicate(true)})

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(EXAMPLE), ProjectSettings.globalize_path(COPY)) != OK:
		push_error("Could not copy original campaign"); quit(1); return
	var session := Session.new(DIRECTORY)
	var loaded: Dictionary = session.continue_game(COPY)
	if not loaded.ok:
		push_error(str(loaded)); quit(1); return
	_capture(session, "T3 original campaign")
	var first_fact: int = int(session.world.state.next_fact)
	var advanced: Dictionary = session.progress()
	if not advanced.ok:
		push_error(str(advanced)); quit(1); return
	_capture(session, "T4 after start")
	if session.turn.context.phase == "events":
		var events: Array = session.project().events
		result["events_at_start"] = events
		if events.is_empty():
			advanced = session.progress()
			if not advanced.ok:
				push_error(str(advanced)); quit(1); return
			_capture(session, "T4 action window")
	var facts: Array = []
	for number: int in range(maxi(1, first_fact - 120), int(session.world.state.next_fact)):
		var fact: Dictionary = Store.entry(session.world.state.facts, "FACT-%08d" % number, {})
		var kind: String = str(fact.get("kind", ""))
		if kind == "prayer_dispatch_tick":
			var data: Dictionary = fact.changes
			facts.append({"id": fact.id, "kind": kind, "turn": fact.turn, "domain": fact.domain, "opportunity": data.opportunity, "eligible": data.eligible.map(func(option: Dictionary) -> String: return option.root), "selected_root": data.choice.get("root", ""), "existing_outcome": data.existing_outcome, "new_outcome": data.new_outcome, "produced": data.produced, "next_generation": data.after.next_turn})
		elif kind in ["prayer_result", "prayer_closed", "background_prayer_closed", "ritual_context", "prayer_situation", "prayer_call", "prayer_registered"]:
			facts.append(fact)
	result["recent_prayer_facts"] = facts
	result["source_sha256"] = FileAccess.get_sha256(EXAMPLE)
	result["source_unchanged"] = result.source_sha256 == FileAccess.get_sha256(COPY)
	var output := FileAccess.open("res://docs/game-state/ui-prayer-diagnostic.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  ")); output.close()
	for step: Dictionary in result.steps:
		print(JSON.stringify({"label": step.label, "turn": step.turn, "phase": step.phase, "offered": step.offered, "requests": step.requests, "candidates": step.candidates, "projected_count": step.projected_prayers.size()}))
	print("Source unchanged: ", result.source_unchanged)
	quit(0)
