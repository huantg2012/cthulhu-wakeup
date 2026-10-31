extends SceneTree
const Store = preload("res://src/simulation/archive_store.gd")
## Intentional read-only errors run in a separate process, never hidden in main suite.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")

func _empty(_view: Dictionary, input: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
	if input.slot == "events":
		result.events = []
	return result

func _write_fact(alias: Dictionary) -> void:
	alias["injected"] = true

func _write_npc(alias: Array) -> void:
	alias.clear()

func _write_context(alias: Dictionary) -> void:
	alias["injected"] = {"nested": [1]}

func _initialize() -> void:
	var catalog: RefCounted = Catalog.new()
	assert(catalog.load_files())
	var world: RefCounted = World.new(catalog)
	assert(world.generate(7919))
	var turn: RefCounted = Turn.new(world)
	assert(turn.register_participant("tx-alias", "1", Turn.SLOTS, [], _empty))
	# Capture BEFORE adoption; replacing only the public World.state cannot protect these.
	var fact: Dictionary = Store.entry(world.state.facts, world.state.domains["DOMAIN-001"].origin).changes
	var npc: Array = Store.values(world.state.npcs)[0].relations
	var plans: Dictionary = turn.context.plans
	assert(turn.submit({"id": "TX-ALIAS-1", "op": "advance", "turn": 0, "phase": "between"}).ok)
	var before: String = turn.snapshot()
	_write_fact(fact)
	_write_npc(npc)
	_write_context(plans)
	var ok: bool = fact.is_read_only() and npc.is_read_only() and plans.is_read_only() and before == turn.snapshot()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "unchanged": before == turn.snapshot(), "capturedBeforeAdoption": true, "frozenAliases": [fact.is_read_only(), npc.is_read_only(), plans.is_read_only()]}))
	file.close()
	print("ALIAS-PROBE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
