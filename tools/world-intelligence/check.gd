extends SceneTree
## Real-session save compatibility plus detached disclosure-contract fixtures.
## Fixtures exercise knowledge reduction; they do not invent campaign observers.
const Session = preload("res://src/presentation/session.gd")
const Knowledge = preload("res://src/game/player_knowledge.gd")
const Intel = preload("res://src/game/world_intelligence.gd")
const Catalog = preload("res://src/simulation/catalog.gd")
const World = preload("res://src/simulation/world.gd")
const DIRECTORY := "res://.godot/world-intelligence-check"
const LEGACY := "res://tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json"
var checks: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func need(ok: bool, label_value: String, detail: Variant = "") -> bool:
	if not ok:
		push_error("WORLD_INTELLIGENCE " + label_value + ": " + str(detail))
		quit(1); return false
	checks.append(label_value); return true

func _fact(number: int, kind: String, turn_number: int, changes: Dictionary = {}, parents: Array = []) -> Dictionary:
	return {"id": "FACT-%08d" % number, "kind": kind, "turn": turn_number, "domain": "DOMAIN-001", "actor": "", "targets": [], "causal_parents": parents, "changes": changes}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var catalog := Catalog.new()
	if not need(catalog.load_files(), "正式 CSV 包含完整精度箱", catalog.errors): return
	var malformed: Dictionary = catalog.tables.duplicate(true)
	malformed.world_intelligence_bands.RANGE_25_49.lower = "26"
	if not need(not catalog._validate_world_intelligence(malformed, catalog.parameters).is_empty(), "CSV 区间缺口被拒绝"): return
	malformed.world_intelligence_bands.RANGE_25_49.lower = "24"
	if not need(not catalog._validate_world_intelligence(malformed, catalog.parameters).is_empty(), "CSV 区间重叠被拒绝"): return
	malformed = catalog.tables.duplicate(true)
	malformed.world_observation_sources.OBS_POWER.selector = "cult_offering"
	if not need(not catalog._validate_world_intelligence(malformed, catalog.parameters).is_empty(), "CSV 观测选择器与来源事实类型错配被拒绝"): return
	var context: Dictionary = {"turn": 3, "phase": "actions"}
	var domain: Dictionary = {"barrier": 61, "pollution": 24, "alert": 25, "stability": 100}
	var state: Dictionary = {"turn": 3, "next_fact": 2, "domains": {"DOMAIN-001": domain}, "facts": {"FACT-00000001": _fact(1, "world_origin", 0)}, "npcs": {}, "relics": {}, "institutions": {}, "attention": {"members": []}, "prayer_system": {"offered": [], "requests": {}}, "event_system": {"selected": [], "cards": {}}}
	var ledger: Dictionary = Knowledge.learn(state, context, Knowledge.empty_ledger(), catalog, null, "FACT-00000001")
	var initial: Dictionary = ledger.domain_intelligence["DOMAIN-001"].duplicate(true)
	if not need(initial.size() == 4 and initial.pollution.upper == 24 and initial.alert.lower == 25 and initial.stability.upper == 100, "初次完整世界知情保存四项 CSV 区间"): return
	if not need(initial.barrier.source == "FACT-00000001" and initial.barrier.observed_turn == 3 and initial.barrier.phase == "actions" and not initial.barrier.has("value"), "初见记录真实获知时刻及来源且不保存隐藏总值"): return
	if not need(Knowledge.validate_ledger(state, ledger, catalog).is_empty(), "冻结区间通过正式 ledger 校验"): return
	state.domains["DOMAIN-001"].barrier = 90
	state.domains["DOMAIN-001"].pollution = 76
	var repeated: Dictionary = Knowledge.learn(state, context, ledger, catalog, null, "FACT-00000001")
	if not need(repeated.domain_intelligence == ledger.domain_intelligence, "同一来源重复查看不刷新变化后的世界数值"): return
	state.facts["FACT-00000002"] = _fact(2, "power_effect", 3, {"field": "pollution", "amount": 8})
	state.next_fact = 3
	var delta_known: Dictionary = Knowledge.learn(state, context, ledger, catalog, null, "FACT-00000002")
	if not need(delta_known.domain_intelligence == ledger.domain_intelligence and Intel.exact_value(delta_known.domain_intelligence["DOMAIN-001"].pollution) == null, "已知增量不推测总量或重算区间"): return
	# A real typed observation can be the one hidden fact reached by LISTEN.
	state.facts["FACT-00000002"] = _fact(2, "resistance_breach", 3, {"barrier": 27, "open": true, "initial": false})
	state.facts["FACT-00000003"] = _fact(3, "message", 3, {"fact": "FACT-00000002"})
	state.facts["FACT-00000004"] = _fact(4, "power_attempt", 3, {"power": "POWER_LISTEN", "proofs": {"listen": {"basis": {"fact": "FACT-00000002"}}}}, ["FACT-00000003"])
	state.next_fact = 5
	ledger = Knowledge.learn(state, context, ledger, catalog, null, "FACT-00000003")
	var listened: Dictionary = Knowledge.reduce(state, context, ledger, catalog, null, [], {"own_action": true, "first_fact": 4, "roots": {"FACT-00000003": true}})
	if not need(listened.domain_intelligence["DOMAIN-001"].barrier.value == 27 and listened.domain_intelligence["DOMAIN-001"].pollution == initial.pollution, "聆听仅更新目标真实观测字段且保留快照值而非当前90"): return
	if not need(Knowledge.validate_ledger(state, listened, catalog).is_empty(), "精确观测来源通过正式 ledger 校验"): return
	var late_discovery: Dictionary = Knowledge.learn(state, context, Knowledge.empty_ledger(), catalog, null, "FACT-00000001")
	var earlier_observation: Dictionary = Knowledge.learn(state, context, late_discovery, catalog, null, "FACT-00000002")
	if not need(earlier_observation.domain_intelligence == late_discovery.domain_intelligence, "同轮更早的精确记录不覆盖较新的观测区间"): return
	var prior: Dictionary = listened.duplicate(true)
	prior.domain_intelligence["DOMAIN-001"].barrier.erase("precision")
	prior.domain_intelligence["DOMAIN-001"].barrier.erase("observed_turn")
	prior.domain_intelligence["DOMAIN-001"].barrier.erase("phase")
	prior.domain_intelligence["DOMAIN-001"].barrier.erase("observed_sequence")
	if not need(Knowledge.validate_ledger(state, prior, catalog).is_empty() and Intel.exact_value(prior.domain_intelligence["DOMAIN-001"].barrier) == 27, "旧精确屏障记录格式保持兼容"): return
	var forged: Dictionary = listened.duplicate(true)
	forged.domain_intelligence["DOMAIN-001"].barrier.value = 90
	if not need(not Knowledge.validate_ledger(state, forged, catalog).is_empty(), "当前真值伪装成历史观测会被拒绝"): return
	for mutation: Dictionary in [{"lower": 37, "upper": 37}, {"lower": 20, "upper": 21}, {"band_id": "RANGE_75_100"}, {"bands_version": "different-policy"}, {"observed_sequence": null}]:
		forged = listened.duplicate(true)
		forged.domain_intelligence["DOMAIN-001"].pollution.merge(mutation, true)
		if not need(not Knowledge.validate_ledger(state, forged, catalog).is_empty(), "拒绝伪精度或缺失政策/时点 " + str(mutation)): return
	for mutation: Dictionary in [{"observed_sequence": 4}, {"phase": "actions"}]:
		forged = listened.duplicate(true)
		forged.domain_intelligence["DOMAIN-001"].barrier.merge(mutation, true)
		if not need(not Knowledge.validate_ledger(state, forged, catalog).is_empty(), "精确记录不能伪造较晚观测时点 " + str(mutation)): return
	var clue_only: Dictionary = Knowledge.empty_ledger()
	clue_only.request_domains["DOMAIN-001"] = true
	clue_only = Knowledge.learn(state, context, clue_only, catalog, null, "FACT-00000003")
	if not need(clue_only.known_domains.is_empty() and clue_only.domain_intelligence.is_empty(), "祈求的单世界线索不会升级完整态势知情"): return
	var legacy_shape: Dictionary = {"cursor": 5, "domains": ["DOMAIN-001"], "people": [], "facts": ["FACT-00000001", "FACT-00000003"]}
	var rebuilt: Dictionary = Knowledge.restore_ledger(state, context, legacy_shape, catalog, null)
	if not need(rebuilt.domain_intelligence.is_empty(), "重建旧知情不能把当前数值回填为历史观测"): return
	# Actual production session: browsing, durable save and resume.
	var fresh := Session.new(DIRECTORY + "/fresh")
	var created: Dictionary = fresh.start_new(1)
	if not need(created.get("ok", false), "正式新局可启动", created): return
	var first_view: Dictionary = fresh.project()
	var full_domains: Array = first_view.domains.filter(func(item: Dictionary) -> bool: return item.has("metric_sources"))
	if not need(not full_domains.is_empty() and full_domains.all(func(item: Dictionary) -> bool: return item.metric_sources.size() == 4), "正式新局的完整已知世界均有四项态势"): return
	var before: String = fresh.turn.snapshot()
	fresh.project(); fresh.action_catalog(); fresh.project()
	if not need(fresh.turn.snapshot() == before, "页面投影和行动目录零世界写入"): return
	var saved: Dictionary = fresh.save_game()
	var restored := Session.new(DIRECTORY + "/fresh")
	if not need(saved.get("ok", false) and restored.continue_game(saved.path).get("ok", false), "含区间快照的会话可保存恢复", restored.last_error): return
	if not need(restored.turn.snapshot() == before and restored.project().domains == first_view.domains, "读档不刷新快照时间或区间"): return
	# Re-sign the enclosing turn envelope to ensure rejection is semantic, not
	# merely a checksum mismatch. Restore failure must leave the session intact.
	for mutation: Dictionary in [{"lower": 37, "upper": 37}, {"bands_version": "different-policy"}]:
		var tampered: Dictionary = World._normalize_numbers(JSON.parse_string(before))
		var world_id: String = str(full_domains[0].id)
		tampered.body.context.player_knowledge.domain_intelligence[world_id].pollution.merge(mutation, true)
		tampered.checksum = World.canonical(tampered.body).sha256_text()
		if not need(not restored.turn.restore(World.canonical(tampered)) and restored.turn.snapshot() == before, "正式恢复拒绝重签的伪精度并保持原局 " + str(mutation)): return
	var legacy_hash: String = FileAccess.get_sha256(LEGACY)
	var legacy_copy: String = DIRECTORY + "/legacy-t3.json"
	if not need(DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY), ProjectSettings.globalize_path(legacy_copy)) == OK, "原 T3 存档只读复制"): return
	var old := Session.new(DIRECTORY)
	var loaded: Dictionary = old.continue_game(legacy_copy)
	if not need(loaded.get("ok", false), "原 T3 core/participant 签名可恢复", loaded): return
	var old_ledger: Dictionary = old.knowledge_snapshot().domain_intelligence.duplicate(true)
	var old_before: String = old.turn.snapshot()
	old.project(); old.action_catalog()
	if not need(old.turn.snapshot() == old_before and old.knowledge_snapshot().domain_intelligence == old_ledger and FileAccess.get_sha256(LEGACY) == legacy_hash, "旧档浏览不回填历史、不改写源文件"): return
	var report := FileAccess.open(DIRECTORY + "/results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "count": checks.size(), "scope": "real new/legacy save sessions + detached reducer contracts; recurring observations and actual listening covered by producer_check.gd"}, "\t"))
	print("WORLD_INTELLIGENCE_OK ", checks.size(), " checks; evidence ", DIRECTORY + "/results.json")
	quit(0)
