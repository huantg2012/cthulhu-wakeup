extends "res://tools/prayer-pipeline-regression/adapters/dispatch.gd"
const InspectDispatch = preload("res://src/game/prayer_dispatch.gd")
const InspectProducers = preload("res://src/game/prayer_producers.gd")

func _initialize() -> void:
	catalog = Catalog.new()
	assert(catalog.load_files())
	var output: String = OS.get_cmdline_user_args()[0]
	scratch = output.get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	# Actual original fixture setup includes its initial opening and DREAM.
	# This entry never advances its target evolution or tests notice delivery.
	var data: Dictionary = _notice_fixture("focused", "valid", 1981)
	assert(data.turn.context.phase == "actions")
	var before: String = data.turn.snapshot()
	var frozen: Dictionary = data.world._evolution_snapshot()
	# Read-only predicate input, not Knowledge.capture(), an authorization,
	# a true evolution snapshot position or a value ever sent to a writer.
	var diagnostic_boundary: Dictionary = {"turn": data.world.state.turn, "phase": 4, "commit_seq": data.turn.commit_sequence, "fact_cutoff": int(data.world.state.next_fact) - 1}
	var current: Dictionary = _notice_observation(data, data.world.state, data.world.history)
	var copied: Dictionary = _notice_observation(data, frozen, frozen._history_snapshot)
	var options: Array = InspectProducers.prepare_options(data.world, frozen, "DOMAIN-001", diagnostic_boundary)
	var notice: Dictionary = InspectDispatch._notice(data.world, frozen, "DOMAIN-001", frozen.prayer_dispatch.positions["DOMAIN-001"].duplicate(true), diagnostic_boundary, int(frozen.simulation.cursors["DOMAIN-001"].next_turn))
	var unchanged: bool = before == data.turn.snapshot()
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "inspection_recorded", "seed": 1981, "mode": "focused", "variant": "valid", "phase": data.turn.context.phase, "fixture": data.ppr_notice_input, "current": current, "detachedSnapshot": copied, "predicateDiagnosticBoundary": diagnostic_boundary, "pureOriginOptions": options, "pureNoticeScan": notice, "turnSnapshotUnchangedByReads": unchanged, "limitations": ["Actual initial fixture/DREAM setup; no target end_actions or evolution advance.", "No notice was committed or tested for successful delivery; no behavior PASS.", "Diagnostic predicate boundary is not a managed sampling credential."]}, "\t", true, true) + "\n")
	file.close()
	quit(0 if unchanged else 1)
