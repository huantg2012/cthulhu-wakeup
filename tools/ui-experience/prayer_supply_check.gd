extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const World = preload("res://src/simulation/world.gd")
const Supply = preload("res://src/game/prayer_supply.gd")
const Transaction = preload("res://src/simulation/transaction.gd")
const History = preload("res://src/simulation/history_index.gd")
const DIRECTORY := "res://.godot/prayer-supply-check"
const ORIGINAL := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
var checks: Array[String] = []
var windows: Array = []

func _initialize() -> void:
	_run.call_deferred()

func need(ok: bool, label_value: String, detail: Variant = "") -> bool:
	if not ok:
		push_error("SUPPLY_CHECK " + label_value + ": " + str(detail))
		quit(1); return false
	checks.append(label_value); return true

func _actions(session: RefCounted) -> bool:
	for step: int in range(7):
		if session.turn.context.phase == "actions": return true
		if session.turn.context.phase == "ended": return false
		var moved: Dictionary = session.progress()
		if not need(moved.get("ok", false), "阶段通过正式时钟推进", moved): return false
	return false

func _response(session: RefCounted) -> String:
	for prayer: Dictionary in session.project().prayers:
		var variants: Array = ["shallow", "deep"]
		if prayer.descriptor.get("space", false):
			variants = session.prayer_space_choices(prayer.id).map(func(choice: Dictionary) -> String: return choice.id)
		for variant: String in variants:
			var key: String = str(prayer.key) + "/" + variant
			if session.preview_action(key, {}).get("ok", false): return key
	return ""

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var before_hash: String = FileAccess.get_sha256(ORIGINAL)
	var copy: String = DIRECTORY + "/first-cult.json"
	if not need(DirAccess.copy_absolute(ProjectSettings.globalize_path(ORIGINAL), ProjectSettings.globalize_path(copy)) == OK, "旧存档只读复制"): return
	var legacy := Session.new(DIRECTORY)
	var loaded: Dictionary = legacy.continue_game(copy)
	if not need(loaded.get("ok", false), "原T3存档按旧签名完整恢复", loaded): return
	var old_sequence: int = legacy.turn.commit_sequence
	var old_fact_count: int = legacy.world.state.next_fact
	if not need(not Store.has(legacy.world.state.applied_authorizations, "prayer/supply/policy"), "恢复旧档不偷偷改写历史"): return
	if not _actions(legacy): return
	if not need(legacy.project().turn == 4 and legacy.project().prayers.size() >= 1 and legacy.project().prayers.size() <= 3 and not _response(legacy).is_empty(), "T4有真实可回应祈求"): return
	var policy: Dictionary = Store.entry(legacy.world.state.facts, str(Store.entry(legacy.world.state.applied_authorizations, "prayer/supply/policy", "")), {})
	if not need(policy.get("changes", {}).get("sequence") == old_sequence + 1 and policy.changes.get("fact_before") == old_fact_count and policy.turn == 4, "供给政策在真实下一次advance中前向启用"): return
	var events_before: int = legacy.world.state.next_fact
	var existing_count: int = legacy.project().prayers.size()
	# Pure browsing does not generate another request or consume random state.
	legacy.project(); legacy.action_catalog(); legacy.preview_action(_response(legacy), {})
	if not need(legacy.world.state.next_fact == events_before and legacy.project().prayers.size() == existing_count, "已有合法请求时浏览和预览不生产"): return
	var saved: Dictionary = legacy.save_game()
	var restored := Session.new(DIRECTORY)
	if not need(saved.get("ok", false) and restored.continue_game(saved.path).get("ok", false), "供给后的完整会话可保存恢复", restored.last_error): return
	if not need(legacy.turn.snapshot() == restored.turn.snapshot(), "保存恢复的规则快照相同"): return
	var response_key: String = _response(legacy)
	var left: Dictionary = legacy.execute_action(response_key, {}, true, "SUPPLY/REPLAY")
	var right: Dictionary = restored.execute_action(response_key, {}, true, "SUPPLY/REPLAY")
	if not need(left.get("ok", false) and right.get("ok", false) and legacy.turn.snapshot() == restored.turn.snapshot(), "恢复后同一回应及随机结果等值", [left, right]): return
	if not need(not legacy.preview_action(response_key, {}).get("ok", false), "实际回应仍只消费一次机会"): return
	var after_response: String = legacy.turn.snapshot()
	if not need(legacy.execute_action(response_key, {}, true, "SUPPLY/REPLAY").get("ok", false) and legacy.turn.snapshot() == after_response, "重复请求凭据不重复回应"): return
	var fresh := Session.new(DIRECTORY + "/fresh")
	var created: Dictionary = fresh.start_new(1)
	if not need(created.get("ok", false), "真实新局启动", created): return
	var missing_policy: Dictionary = History.export_value(fresh.world.state)
	Store.erase(missing_policy.applied_authorizations, "prayer/supply/policy")
	if not need(not Supply.validate_state(missing_policy, fresh.catalog).is_empty(), "已有启用事实但缺政策索引时拒绝恢复"): return
	for index: int in range(3):
		if not _actions(fresh): return
		var key: String = _response(fresh)
		if not need(not key.is_empty() and fresh.project().prayers.size() <= 3, "连续行动窗口至少一项且不超过三项", fresh.project().prayers): return
		var request_id: String = key.get_slice("/", 1)
		var request: Dictionary = fresh.prayer_entry(request_id)
		var card: Dictionary = request.card
		var call: Dictionary = Store.entry(fresh.world.state.facts, str(card.get("call", "")), {})
		windows.append({"turn": fresh.project().turn, "count": fresh.project().prayers.size(), "response": key, "petitioner": request.descriptor.subjects.petitioner, "source": request.descriptor.source, "occurrence": call.get("changes", {}).get("occurrence", "")})
		var action: Dictionary = fresh.execute_action(key, {}, true, "SUPPLY/FRESH/" + str(index))
		if not need(action.get("ok", false), "连续窗口执行真实回应", action): return
		if index < 2:
			var ended: Dictionary = fresh.progress(true)
			if not need(ended.get("ok", false), "正式结束当前行动", ended): return
	var invalid_grant: Dictionary = History.export_value(legacy.world.state)
	for fact: Dictionary in Store.values(invalid_grant.facts):
		if fact.kind == "prayer_supply_admitted":
			fact.changes.visible_turn += 1
			Store.put(invalid_grant.facts, fact.id, fact)
			break
	if not need(not Supply.validate_state(invalid_grant, legacy.catalog).is_empty(), "错位的当轮供给授权被拒绝"): return
	var invalid_context: Dictionary = History.export_value(legacy.turn.context)
	var wrong_policy_state: Dictionary = History.export_value(legacy.world.state)
	var wrong_policy: Dictionary = Store.entry(wrong_policy_state.facts, policy.id)
	wrong_policy.changes.sequence = int(wrong_policy.changes.sequence) + 1
	Store.put(wrong_policy_state.facts, policy.id, wrong_policy)
	if not need(not legacy.turn._validate_context(invalid_context, wrong_policy_state).is_empty(), "政策启用不能挪到另一个历史回执"): return
	var old_events := Session.new(DIRECTORY + "/events")
	var event_fixture: String = DIRECTORY + "/legacy-events.json"
	var event_copy: String = DIRECTORY + "/legacy-events-import.json"
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(event_fixture), ProjectSettings.globalize_path(event_copy)) != OK:
		push_error("Could not copy legacy event fixture"); quit(1); return
	var event_loaded: Dictionary = old_events.continue_game(event_copy)
	if not need(event_loaded.get("ok", false) and old_events.turn.context.phase == "events" and old_events.project().prayers.is_empty(), "原HEAD真实events存档按旧规则恢复", event_loaded): return
	# A bounded controlled refusal, not a natural-campaign coverage claim.
	var baseline: String = old_events.turn.snapshot()
	var blocked := Transaction.new(old_events.world, old_events.turn.context, old_events.turn.commit_sequence)
	if not need(blocked.activate(), "受控无合法来源夹具开启事务"): return
	old_events.world.stage_current()
	for institution: Dictionary in old_events.world.state.institutions.values(): institution.active = false
	var supplied: bool = Supply.ensure(old_events.world, old_events.turn)
	blocked.rollback()
	if not need(not supplied and old_events.turn.snapshot() == baseline, "无合法来源有限拒绝且完整回滚"): return
	if not _actions(old_events): return
	if not need(not _response(old_events).is_empty(), "旧events档在真实finish_events边界补足合法祈求"): return
	var event_saved: Dictionary = old_events.save_game()
	var event_restored := Session.new(DIRECTORY + "/events-restore")
	if not need(event_saved.get("ok", false) and event_restored.continue_game(event_saved.path).get("ok", false) and old_events.turn.snapshot() == event_restored.turn.snapshot(), "旧events迁移后的完整恢复等值", event_restored.last_error): return
	if not need(FileAccess.get_sha256(ORIGINAL) == before_hash, "原T3证据字节保持不变"): return
	var report: Dictionary = {"checks": checks, "windows": windows, "old_save_sha256": before_hash, "scope": "Original T3 to T4, three fresh action windows, exact save/restore next-action replay; not whole-campaign or balance validation."}
	var output := FileAccess.open("res://docs/game-state/ui-prayer-supply-checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  ")); output.close()
	print(JSON.stringify(report))
	quit(0)
