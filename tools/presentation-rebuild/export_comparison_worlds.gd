extends SceneTree
## Export identity only. The review fixture supplies public contact and its local scene.
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const Store = preload("res://src/simulation/archive_store.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the output JSON path after --")
		quit(1)
		return
	var catalog = Catalog.new()
	assert(catalog.load_files())
	var fixture := FileAccess.open("res://tools/presentation-rebuild/comparison_scenes.csv", FileAccess.READ)
	assert(fixture != null)
	fixture.get_csv_line()
	var snapshots := {}
	while not fixture.eof_reached():
		var row := fixture.get_csv_line()
		if row[0].is_empty(): continue
		var world = World.new(catalog)
		assert(world.generate_hybrid(int(row[0])))
		var naming: Dictionary = catalog.player_text.world_names.generate(int(row[0]), world.state.domains)
		assert(naming.ok)
		var worlds: Array[Dictionary] = []
		for id: String in [row[1], row[2], row[3]]:
			var domain: Dictionary = world.state.domains[id]
			worlds.append({"id": id, "name": naming.names[id], "background": naming.backgrounds[id], "tier": domain.tier})
		var person: Dictionary = Store.entry(world.state.npcs, row[5])
		assert(person.domain == row[1])
		snapshots[row[0]] = {"worlds": worlds, "person": catalog.player_text.person_name(row[5])}
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(snapshots, "\t") + "\n")
	quit()
