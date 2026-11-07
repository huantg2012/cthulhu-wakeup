extends SceneTree
## Focused CSV boundary and complete Session save compatibility check.
const Catalog = preload("res://src/simulation/catalog.gd")
const Powers = preload("res://src/game/powers.gd")
const Session = preload("res://src/presentation/session.gd")
const World = preload("res://src/simulation/world.gd")
var failures: Array[String] = []

class Reader extends RefCounted:
	var person: Dictionary = {"id":"NPC-TEST", "domain":"DOMAIN-TEST", "status":"active", "bound_member":true, "loyalty":100, "cult_id":"CULT-TEST", "acted_turn":-1}
	func entity(_collection: String, _id: String) -> Dictionary:
		return {"ok":true, "item":person}
	func authorization(_key: String) -> Dictionary:
		return {"ok":true, "used":false}

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_files(), "current catalog loads")
	var expected := {"LISTEN":0, "DREAM":0, "APPOINT":0, "ANCHOR":10, "ORACLE":14, "VEIL":18, "SEED":26, "SACRIFICE":34, "TRANSFER":44, "BESTOW":56, "BREACH":70, "MANIFEST":90}
	for id: String in expected:
		check(int(catalog.tables.powers["POWER_" + id].unlock_awakening) == expected[id], "authored threshold " + id)
	var powers := Powers.new(catalog)
	var view := {"reader":Reader.new(), "world":{"power_system":{"version":powers.version, "completion":"", "manifest":{}}, "npcs":{}, "domains":{"DOMAIN-TEST":{}}, "cults":{"CULT-TEST":{"domain":"DOMAIN-TEST", "status":"active"}}, "turn":1, "faith":100, "whispers":10, "awakening":0, "awakening_peak":99}}
	for id: String in ["ORACLE", "VEIL", "SEED", "SACRIFICE", "TRANSFER", "BESTOW", "BREACH", "MANIFEST"]:
		var payload := {"npc":"NPC-TEST", "domain":"DOMAIN-TEST"}
		view.world.awakening = expected[id] - 1
		var denied: Dictionary = powers.prepare(view, "POWER_" + id, payload, true)
		check(not denied.ok and denied.get("error") == "Current awakening is below the power threshold", "below threshold denied despite peak " + id)
		view.world.awakening = expected[id]
		check(powers.prepare(view, "POWER_" + id, payload, true).ok, "threshold reached " + id)
	var old_path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	if not old_path.is_empty():
		var old := Session.new("/tmp/power-unlock-compat")
		check(old.continue_game(old_path).ok, "original pre-change save continues")
		if old.turn != null:
			check(old.catalog.extension_versions.powers == Catalog.LEGACY_POWERS_VERSION, "old campaign keeps exact original rules")
			check(int(old.catalog.tables.powers.POWER_BESTOW.unlock_awakening) == 10, "old bestow threshold retained")
			var original: String = old.turn.snapshot()
			check(old.save_game("/tmp/power-unlock-compat/resaved.json").ok, "old campaign resaves")
			var restored := Session.new("/tmp/power-unlock-compat")
			check(restored.continue_game("/tmp/power-unlock-compat/resaved.json").ok, "resaved campaign continues")
			check(restored.turn != null and restored.turn.snapshot() == original, "restore preserves full state history and random streams")
	var fresh := Session.new("/tmp/power-unlock-new")
	check(fresh.start_new(501).ok, "new campaign starts")
	check(int(fresh.catalog.tables.powers.POWER_BESTOW.unlock_awakening) == 56, "new campaign uses new curve")
	check(fresh.save_game("/tmp/power-unlock-new/current.json").ok, "new campaign saves")
	var continued := Session.new("/tmp/power-unlock-new")
	check(continued.continue_game("/tmp/power-unlock-new/current.json").ok, "new campaign continues")
	print(JSON.stringify({"ok":failures.is_empty(), "failures":failures, "legacy_checked":not old_path.is_empty()}))
	quit(0 if failures.is_empty() else 1)
