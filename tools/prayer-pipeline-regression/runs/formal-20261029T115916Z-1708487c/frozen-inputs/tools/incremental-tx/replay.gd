extends SceneTree
## Identical driver runs against the immutable pre-refactor revision and current code.
## Test adapters authorize fixture actions; economic/NPC/civilization rules are production.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Turn = preload("res://src/game/turn.gd")
const Economy = preload("res://src/game/economy.gd")
var catalog: RefCounted
var trace: Array = []
var sequence: int = 0
var failed: bool = false
var checkpoint: String = ""
var legacy_checkpoint: String = ""
var legacy_loaded: bool = false

class Adapter extends RefCounted:
	func handle(view: Dictionary, input: Dictionary) -> Dictionary:
		var origin: String = view.world.domains["DOMAIN-001"].origin
		var result: Dictionary = {"ok": true, "empty": true, "effects": [], "state": {}}
		if input.slot == "events" and input.operation == "gather":
			result.events = []
			if (int(view.turn.turn) - 1) % 6 == 0:
				for domain: Dictionary in view.world.domains.values():
					var actor: String = view.world.institutions[domain.id + "/propagation"].representative
					var witness: String = view.world.institutions[domain.id + "/order"].representative
					if view.world.npcs.has(actor) and view.world.npcs[actor].status == "active" and view.world.npcs.has(witness) and view.world.npcs[witness].status == "active":
						result.effects.append({"type": "fact", "source": domain.origin, "kind": "miracle", "domain": domain.id, "actor": actor, "targets": [actor], "observers": [actor], "institutions": [], "details": {"witnesses": [actor], "public": true}})
						result.effects.append({"type": "fact", "source": domain.origin, "kind": "exposure", "domain": domain.id, "actor": actor, "targets": [actor], "observers": [witness], "institutions": [domain.id + "/order"], "details": {"public": true}})
		if input.slot == "actions":
			result.meta = {"faith_cost": 1 if input.action == "paid" else 0, "whispers_cost": 0, "min_awakening": 0, "actor": "", "source": origin, "outcome": "authorized_test_boundary", "responds": false, "used_power": false, "used_relic": false}
			if input.action in ["roll", "failed_batch"]:
				var actor: String = ""
				for id: String in view.world.npcs.keys():
					if view.world.npcs[id].status == "active":
						actor = id
						break
				var branch: Array = [{"type": "wounds", "source": origin, "delta": 0}]
				result.effects.append({"type": "check", "source": origin, "npc": actor, "domain": view.world.npcs[actor].domain, "attribute": "will", "mode": "occult", "preparation": 0, "branches": {"deep": branch, "success": branch, "failure": branch, "disaster": branch}})
				if input.action == "failed_batch":
					# Both spends are individually affordable against the shared starting balance.
					var spend: int = int(view.world.faith) / 2 + 1
					for ignored: int in 2:
						result.effects.append({"type": "resource", "source": origin, "field": "faith", "delta": -spend})
		result.empty = result.effects.is_empty()
		return result

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2:
		legacy_checkpoint = JSON.parse_string(FileAccess.get_file_as_string(args[1])).checkpoint
	catalog = Catalog.new()
	if not catalog.load_files():
		quit(1)
		return
	for seed_value: int in [7919, 1981]:
		_run(seed_value)
	if args.size() not in [1, 2]:
		push_error("Replay requires an output path")
		quit(1)
		return
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "fail" if failed else "pass", "engine": Engine.get_version_info().string, "trace": trace, "checkpoint": checkpoint, "legacyLoaded": legacy_loaded}, "\t", true, true))
	file.close()
	print("REPLAY ", trace.size(), " snapshots; status=", "fail" if failed else "pass")
	quit(1 if failed else 0)

func _setup(seed_value: int) -> Dictionary:
	var world: RefCounted = World.new(catalog)
	assert(world.generate(seed_value))
	var economy: RefCounted = Economy.new(catalog, {"tx-fixture": "1"})
	assert(economy.initialize(world))
	for domain: String in ["DOMAIN-001", "DOMAIN-002"]:
		var cult: String = "CULT-" + domain
		var leader: String = world.state.institutions[domain + "/propagation"].representative
		var source: String = world.state.domains[domain].origin
		world.state.npcs[leader].loyalty = 100
		assert(world.submit({"kind": "population", "domain": domain, "mode": "convert", "amount": 81, "parents": [source]}))
		var authorization: String = world.introduce_fact("cult_establishment_authorized", domain, leader, [leader], [source], {"issuer": "tx-fixture", "version": "1", "cult": cult, "domain": domain, "leader": leader, "cohesion": 80}, [])
		assert(world.submit({"kind": "establish_cult", "authorization": authorization, "parents": [authorization]}))
		assert(world.submit({"kind": "economy_qualification", "rule": "propagation", "subject": cult, "institution": domain + "/propagation", "allowed": true, "issuer": "tx-fixture", "version": "1", "parents": [authorization]}))
		var anchor: String = "ANCHOR-" + domain
		var relic: String = "RELIC-" + domain
		world.state.domains[domain].pollution = 50
		world.state.relics[relic] = {"id": relic, "domain": domain, "placement": "bound", "holder": "", "anchor": anchor}
		world.state.anchors[anchor] = {"id": anchor, "domain": domain, "institution": domain + "/interpretation", "guardian": leader, "relic": relic, "state": "active", "needs_rebind": false, "origin": authorization, "ordinal": 1, "cult": cult}
		assert(world.submit({"kind": "economy_qualification", "rule": "anchor", "subject": anchor, "institution": domain + "/interpretation", "allowed": true, "issuer": "tx-fixture", "version": "1", "parents": [authorization]}))
	world._refresh_anchors()
	var turn: RefCounted = Turn.new(world)
	assert(economy.install(turn))
	var adapter: RefCounted = Adapter.new()
	assert(turn.register_participant("tx-fixture", "1", ["events", "actions", "deadlines", "ending"], ["world_command", "fact", "resource", "wounds", "check"], adapter.handle))
	return {"world": world, "turn": turn, "economy": economy, "adapter": adapter, "seed": seed_value}

func _capture(data: Dictionary, label: String, response: Variant) -> void:
	var saved: Dictionary = JSON.parse_string(data.world.snapshot()).body
	var state: Dictionary = saved.state.duplicate(true)
	# A publication counter is storage metadata, not an old gameplay field.
	state.erase("commit_sequence")
	var context: Dictionary = data.turn.context.duplicate(true)
	context.erase("commit_sequence")
	var sections: Dictionary = {}
	for key: String in state:
		sections["world/" + key] = World.canonical(state[key]).sha256_text()
	sections["randoms"] = World.canonical(saved.randoms).sha256_text()
	sections["stats"] = World.canonical(saved.stats).sha256_text()
	sections["context"] = World.canonical(context).sha256_text()
	sections["response"] = World.canonical(response).sha256_text()
	trace.append({"seed": data.seed, "step": sequence, "label": label, "sections": sections, "facts": state.facts.size(), "turn": context.turn, "phase": context.phase})

func _submit(data: Dictionary, operation: String, extra: Dictionary = {}, expected: bool = true) -> Dictionary:
	sequence += 1
	var request: Dictionary = {"id": "TX-REPLAY-%d" % sequence, "op": operation, "turn": data.turn.context.turn, "phase": data.turn.context.phase}
	request.merge(extra)
	var response: Dictionary = data.turn.submit(request)
	if response.get("ok", false) != expected:
		failed = true
		print("Unexpected response ", request, " ", response)
	_capture(data, operation + "/" + str(extra.get("action", "")), response)
	return request

func _run(seed_value: int) -> void:
	var data: Dictionary = _setup(seed_value)
	_capture(data, "initial", {})
	for round_index: int in 12:
		_submit(data, "advance")
		_submit(data, "finish_events")
		var request: Dictionary = _submit(data, "act", {"participant": "tx-fixture", "action": "paid", "payload": {}})
		var old_snapshot: String = data.turn.snapshot()
		var retry: Dictionary = data.turn.submit(request)
		failed = failed or not retry.ok or old_snapshot != data.turn.snapshot()
		_capture(data, "retry", retry)
		_submit(data, "act", {"participant": "tx-fixture", "action": "failed_batch", "payload": {}}, false)
		_submit(data, "act", {"participant": "tx-fixture", "action": "roll", "payload": {}})
		var strategy: String = ["expand", "conceal", "hold"][round_index % 3]
		_submit(data, "set_plan", {"participant": "economy", "payload": {"strategies": {"CULT-DOMAIN-001": strategy, "CULT-DOMAIN-002": "hold"}, "refuse_anchors": ["ANCHOR-DOMAIN-002"] if round_index % 3 == 1 else []}})
		var before: String = data.turn.snapshot()
		var preview: Dictionary = data.turn.preview_plan("economy", {"strategies": {"CULT-DOMAIN-001": "expand"}})
		failed = failed or not preview.ok or before != data.turn.snapshot()
		_capture(data, "preview", preview)
		_submit(data, "end_actions")
		_submit(data, "advance")
		if round_index == 5:
			var saved: String = data.turn.snapshot()
			if seed_value == 7919:
				checkpoint = saved
				if not legacy_checkpoint.is_empty():
					saved = legacy_checkpoint
			var restored: bool = data.turn.restore(saved)
			if seed_value == 7919 and not legacy_checkpoint.is_empty():
				legacy_loaded = restored
			failed = failed or not restored
			_capture(data, "restore", {"ok": restored})
		_submit(data, "advance")
		_submit(data, "advance")
