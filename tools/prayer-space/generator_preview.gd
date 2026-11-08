extends SceneTree
## Author preview calls the same Catalog, world setup, and solver as the game.
const Session = preload("res://src/presentation/session.gd")
const Generator = preload("res://src/game/prayer_generator.gd")
const Space = preload("res://src/game/prayer_space.gd")
const World = preload("res://src/simulation/world.gd")
const Powers = preload("res://src/game/powers.gd")
const Store = preload("res://src/simulation/archive_store.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var query: Variant = JSON.parse_string(args[0]) if not args.is_empty() else {}
	if not query is Dictionary:
		_finish({"error": "预览参数无效"})
		return
	var seed_value := int(query.get("seed", 1))
	var built := Session.new()._build(seed_value)
	if not built.ok:
		_finish({"error": built.error})
		return
	var catalog: RefCounted = built.catalog
	var generator := Generator.new(catalog.prayer_space, catalog)
	var world := World.new(catalog)
	if not world.generate(seed_value) or not world.ensure_history():
		_finish({"error": world.last_error})
		return
	# Open the generated world's existing domains to the author. This is an
	# isolated view, and it never submits a command or writes a campaign slot.
	var state: Dictionary = world.state.duplicate(false)
	state["simulation"] = {"focused": state.domains.keys()}
	state["progression_routes"] = built.world.state.get("progression_routes", {})
	state.whispers = maxi(state.whispers, 10)
	state.faith = maxi(state.faith, 30)
	var generation := {"rng_seed": str(seed_value), "draw": int(query.get("draw", 0)), "situations": {}}
	var filters: Dictionary = query.get("filters", {})
	var locked: Dictionary = query.get("situation", {})
	if not locked.is_empty():
		generation.situations[locked.id] = locked
		filters["root"] = locked.id
	if query.get("capacity", false):
		_finish(_capacity(generator, state, generation, world.history))
		return
	var result: Dictionary = generator.propose(state, generation, filters, world.history)
	var choices := Powers.new(catalog)
	var cards: Array = []
	var roots := {}
	for draft: Dictionary in result.candidates:
		var root := locked if not locked.is_empty() else Space.draft_situation(draft)
		roots[root.id] = root
		var person: Dictionary = Store.entry(state.npcs, draft.roles.petitioner, {})
		var responses: Array = []
		for choice: Dictionary in draft.choices.values():
			var details: Dictionary = draft.contracts[choice.id]
			responses.append({"label": choice.label, "hint": choice.hint, "approach": choice.approach, "whispers": choice.whispers, "faith": choice.faith, "first_upkeep": choice.get("first_upkeep", 0), "upkeep_turns": choice.get("upkeep_turns", 0), "upkeep_stop": choice.get("upkeep_stop", ""), "target": choices.probability(person, state.domains[draft.domain], choice, 0), "contract": details, "difficulty": choice.difficulty, "effect": choice.effect})
		cards.append({"title": draft.title, "appeal": draft.appeal, "role": draft.petitioner_role, "root": root.id, "meta": draft.generation_meta, "responses": responses})
	_finish({"seed": seed_value, "draw": result.draw, "attempts": result.attempts, "rejected": result.rejected, "cards": cards, "roots": roots, "version": generator.version})

func _capacity(generator: RefCounted, state: Dictionary, generation: Dictionary, history: RefCounted) -> Dictionary:
	var semantic := {}
	var decisions := {}
	var wording := {}
	var coverage := {}
	var rejected := {}
	var attempts := 0
	var accepted := 0
	var budget: int = generator.parameter("capacity_attempt_limit")
	while attempts < budget:
		var batch: Dictionary = generator.propose(state, generation, {"attempt_limit": budget - attempts}, history)
		if int(batch.attempts) <= 0: break
		attempts += int(batch.attempts)
		generation.draw = batch.draw
		for key: String in batch.rejected:
			rejected[key] = int(rejected.get(key, 0)) + int(batch.rejected[key])
		for candidate: Dictionary in batch.candidates:
			var meta: Dictionary = candidate.generation_meta
			accepted += 1
			semantic[meta.semantic_signature] = true
			decisions[meta.decision_signature] = true
			wording[[candidate.title, candidate.appeal]] = true
			coverage[meta.frame] = int(coverage.get(meta.frame, 0)) + 1
	return {"seed": generation.rng_seed, "attempts": attempts, "accepted": accepted, "semantic": semantic.size(), "decisions": decisions.size(), "wording": wording.size(), "backgrounds": coverage, "rejected": rejected}

func _finish(result: Dictionary) -> void:
	print("PRAYER_GENERATOR_JSON " + JSON.stringify(result))
	quit(1 if result.has("error") else 0)
