extends "res://tools/echoes-art-master/production_late_probe.gd"
## Finite navigation/return checks against current Session; no replacement rules.
const CULT_SAVE := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		evidence = args[0]
		DirAccess.make_dir_recursive_absolute(evidence)
	folder = "user://ui-audit/%s" % Time.get_ticks_usec()
	var game := open_game()
	press("NewGame")
	app._close_surface()
	app._tasks.open_action("POWER_LISTEN")
	var draft: Dictionary = app._tasks.draft.selection.duplicate(true)
	var state: Dictionary = app.session.knowledge_snapshot()
	press("Read_domain")
	if not check(app._dialog == "task_related" and app._tasks._subject.kind == "world", "Selected world reading missing"): return
	app._tasks.back()
	if not check(app._tasks.draft.selection == draft, "World reading changed action selection"): return
	var source: String = str(draft.get("source", ""))
	if not source.is_empty():
		var record: Dictionary = app._actions.source_info(app._tasks, source)
		if not check(not record.is_empty() and not str(record.summary).is_empty(), "Selected evidence has no explanation"): return
		var source_tab: Button = app.find_child("ActionTab_source", true, false)
		if source_tab != null: source_tab.pressed.emit()
		else: press("ActionTab___outcomes")
		var visible := ""
		for label: Label in app.find_child("ActionOptionsScroll", true, false).find_children("*", "Label", true, false): visible += label.text + "\n"
		if not check(visible.contains(str(record.summary)), "Selected evidence explanation missing from decision page"): return
		if not check(app.find_child("Read_source", true, false) == null, "Evidence requires recursive record navigation"): return
	if not check(app._tasks.draft.selection == draft and app.session.knowledge_snapshot() == state, "Source explanation mutated selection/knowledge"): return
	print("READ_RETURN_OK selected world and inline evidence preserve draft and knowledge")
	app._close_surface()
	var original_hash := FileAccess.get_sha256(CULT_SAVE)
	app._import_copy(ProjectSettings.globalize_path(CULT_SAVE))
	app._close_surface()
	if not check(app.projection.cults.size() == 1, "Existing legal cult save did not load"): return
	var cult: Dictionary = app.projection.cults[0]
	press("WorldArchive")
	press("WorldRecord_" + cult.domain)
	await process_frame
	app._world_management._reading.scroll_vertical = 42
	press("WorldAttention")
	app._tasks.back()
	await process_frame
	if not check(app._world_management._reading.scroll_vertical == 42, "Attention return lost archive reading position"): return
	app._world_management._reading.scroll_vertical = 0
	await shot("01-world-archive")
	for pair: Array in [["WorldPeople","people"],["WorldInstitutions","institutions"],["WorldMaterials","materials"],["WorldRelics","relics"],["WorldAnchors","anchors"]]:
		press(pair[0])
		if not check(app._tasks._subject.kind == pair[1], "Wrong world destination " + pair[0]): return
		app._tasks.back()
		if not check(app._dialog == "world_management" and app._world_management._domain == cult.domain, "Archive return lost world"): return
	press("ArchiveCult")
	for pair: Array in [["CultMaterials","materials"],["CultBudget","budget"]]:
		press(pair[0])
		if not check(app._tasks._subject.kind == pair[1], "Wrong cult destination " + pair[0]): return
		if pair[0] == "CultMaterials" and not check(app._tasks._subject.id == cult.id, "Cult activities lost membership scope"): return
		app._tasks.back()
		if not check(app._dialog == "world_management" and app._world_management._page == "cult", "Cult return lost management"): return
	await shot("02-cult-links")
	app._close_surface()
	for item: Array in [["Activities", "materials"], ["AnchorIndex", "anchors"]]:
		press(item[0])
		if not check(app._tasks._subject.kind == item[1], "Main gameplay entrance missing " + item[0]): return
		app._close_surface()
	app._tasks.open_subject("people",cult.domain)
	press("PersonFilter_people_" + cult.domain)
	if not check(app._views.person_filters["people/" + cult.domain], "Person filter failed"): return
	press("PersonFilter_people_" + cult.domain)
	if not check(not app._views.person_filters["people/" + cult.domain], "Person filter did not reset"): return
	await shot("03-people")
	for institution: Dictionary in app.projection.institutions:
		app._tasks.open_subject("institution", institution.id)
		if not check(not app._body.get_children().is_empty(), "Institution empty"): return
		if institution.domain == cult.domain: await shot("04-institution")
	app._tasks.open_subject("budget")
	app._tasks.show_subject("cult",cult.id)
	app._tasks.manage_cult(cult.id)
	if not check(app._dialog == "world_management", "Related cult failed to reach the shared management layout"): return
	if not check(app.find_child("WorldBack", true, false).text == "返回资料", "Management return mislabeled its origin"): return
	app._world_management.back()
	if not check(app._dialog == "task_related" and app._tasks._subject.kind == "cult", "Management return lost cult reading"): return
	app._tasks.back()
	if not check(app._tasks._subject.kind == "budget", "Return lost original budget"): return
	app._tasks.open_action("POWER_LISTEN", {"domain":cult.domain})
	var prior: Dictionary = app._tasks.draft.selection.duplicate(true)
	press("Read_domain")
	app._tasks.open_action("POWER_DREAM", {"domain":cult.domain,"npc":cult.leader})
	if not check(app._dialog == "task_switch", "Related action silently replaced main task"): return
	press("CancelTaskSwitch")
	app._tasks.back()
	if not check(app._tasks.draft.key == "POWER_LISTEN" and app._tasks.draft.selection == prior, "Cancel task switch lost original preparation"): return
	print("NAVIGATION_OK archive/cult/material/institution/filter/budget and explicit task switching")
	app._close_surface()
	var original_slot: String = app.session.slot
	app._start_new(2)
	app._close_surface()
	app._show_menu()
	press("SavedGames")
	var saves: Array = app.session.saved_games()
	var selected := -1
	for i: int in saves.size():
		if ProjectSettings.globalize_path(saves[i].path) == ProjectSettings.globalize_path(original_slot): selected = i; break
	if not check(selected >= 0 and saves.size() >= 2, "Saved campaign list omitted earlier game"): return
	await shot("05-saved-games")
	press("SavedGame_%s" % selected)
	press("Cancel")
	if not check(app.session.slot != original_slot, "Cancelled load replaced campaign"): return
	press("SavedGames")
	press("SavedGame_%s" % selected)
	press("Switch")
	if not check(ProjectSettings.globalize_path(app.session.slot) == ProjectSettings.globalize_path(original_slot) and app.projection.cults.size() == 1 and FileAccess.get_sha256(CULT_SAVE) == original_hash, "Saved-game selection did not restore chosen copy or changed original"): return
	print("SAVES_OK choose earlier campaign; cancel leaves current; original untouched")
	if args.has("live"):
		app._close_surface()
		root.title = "UI 接入审查 · 隔离存档"
		app._tasks.open_subject("institutions",cult.domain)
		return
	game.free()
	quit()
