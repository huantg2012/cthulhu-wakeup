extends "res://tools/incremental-tx/replay.gd"
const HistoryIndex = preload("res://src/simulation/history_index.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var records: Array = []
var base_path: String
class InvalidSession extends RefCounted:
	var checkpoint: Dictionary
	func _archive_ready() -> bool: return true
	func _archive_checkpoint() -> Dictionary: return checkpoint
class ShortWriter extends "res://src/simulation/archive_store.gd":
	var fail_at: int = -1
	var writes: int = 0
	func _store_bytes(file: FileAccess, text: String) -> bool:
		writes += 1
		if writes == fail_at:
			file.store_string(text.substr(0, text.length() / 2))
			return false
		return super._store_bytes(file, text)
func _capture(_data: Dictionary, _label: String, _response: Variant) -> void:
	pass
func _initialize() -> void:
	catalog = Catalog.new()
	assert(catalog.load_files())
	base_path = "/tmp/cthulhu-archive-" + str(Time.get_ticks_usec())
	_roundtrip()
	_interruptions()
	_corruption()
	_incremental()
	_growth_cost()
	_stale_writer()
	_failed_action()
	_short_writes()
	_sequence_keys()
	var ok: bool = not failed
	for record: Dictionary in records: ok = ok and record.status == "pass"
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "pass" if ok else "fail", "checks": records}, "\t", true, true)); file.close()
	quit(0 if ok else 1)
func _check(id: String, name: String, ok: bool, details: Dictionary = {}) -> void:
	records.append({"id": id, "name": name, "status": "pass" if ok else "fail", "details": details})
	print("PASS " if ok else "FAIL ", id, " ", name, " ", details)
func _roundtrip() -> void:
	var data: Dictionary = _setup(7919)
	for op: String in ["advance", "finish_events", "end_actions", "advance"]: _submit(data, op)
	var before: String = data.turn.snapshot()
	var path: String = base_path.path_join("roundtrip")
	var saved: bool = data.turn.save_archive(path)
	var restored: Dictionary = _setup(7919)
	var loaded: bool = restored.turn.load_archive(path)
	var equal: bool = loaded and restored.turn.snapshot() == before
	_check("ARCH-001", "阶段四后分段存档完整恢复世界/随机/阶段/账本与回执", saved and equal, {"error": restored.turn.last_error, "metrics": data.turn.last_save_metrics})
	if not equal: return
	var replay: bool = true
	for op: String in ["advance", "advance", "advance", "finish_events", "end_actions", "advance", "advance", "advance"]:
		sequence += 1
		var request: Dictionary = {"id": "ARCH-CONTINUE-" + str(sequence), "op": op, "turn": data.turn.context.turn, "phase": data.turn.context.phase}
		var a: Dictionary = data.turn.submit(request); var b: Dictionary = restored.turn.submit(request)
		replay = replay and a.ok and World.canonical(a) == World.canonical(b) and data.turn.snapshot() == restored.turn.snapshot()
	_check("ARCH-002", "恢复后连续六阶段与未中断会话一致，不重付/重收/重演化", replay)
	var old: Dictionary = Store.values(restored.turn.context.receipts)[0].request
	before = restored.turn.snapshot()
	var response: Dictionary = restored.turn.submit(old)
	var changed: Dictionary = old.duplicate(true); changed["unrecognized"] = true
	_check("ARCH-003", "旧请求恢复后仍按键重放，异内容拒绝且不发布新提交", response.ok and not restored.turn.submit(changed).ok and before == restored.turn.snapshot())
func _interruptions() -> void:
	var data: Dictionary = _setup(1981)
	var path: String = base_path.path_join("interruptions")
	var saved: bool = data.turn.save_archive(path)
	var before: String = data.turn.snapshot()
	_submit(data, "advance")
	var current: String = data.turn.snapshot()
	var cases: Dictionary = {}
	for fault: String in ["segments", "commit", "manifest"]:
		var rejected: bool = not data.turn.save_archive(path, fault)
		var rescue: Dictionary = _setup(1981)
		cases[fault] = rejected and rescue.turn.load_archive(path) and rescue.turn.snapshot() == before and data.turn.snapshot() == current
	_check("ARCH-004", "清单发布前任意中断尾部忽略，保留上次完整提交与当前内存状态", saved and not false in cases.values(), cases)
	var published: bool = data.turn.save_archive(path)
	var latest: Dictionary = _setup(1981)
	_check("ARCH-005", "失败后重试发布最新完整提交，不回退已成功保存", published and latest.turn.load_archive(path) and latest.turn.snapshot() == current)
func _corruption() -> void:
	var data: Dictionary = _setup(7919)
	var path: String = base_path.path_join("corruption")
	var saved: bool = data.turn.save_archive(path)
	_submit(data, "advance"); saved = data.turn.save_archive(path) and saved
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("manifest.json")))
	var commit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("commits/" + manifest.body.head + ".json")))
	var segment: String = path.path_join("segments/" + commit.segments[0] + ".json")
	var original: String = FileAccess.get_file_as_string(segment)
	var file: FileAccess = FileAccess.open(segment, FileAccess.WRITE); file.store_string(original + "corrupt"); file.close()
	var target: Dictionary = _setup(1981); var before: String = target.turn.snapshot()
	_check("ARCH-006", "已发布段损坏明确拒绝且不污染会话，不静默回退旧存档", saved and not target.turn.load_archive(path) and before == target.turn.snapshot())
	file = FileAccess.open(segment, FileAccess.WRITE); file.store_string(original); file.close()
	var bogus: RefCounted = InvalidSession.new()
	bogus.checkpoint = HistoryIndex.export_value(data.turn._archive_checkpoint())
	bogus.checkpoint.world.state.next_npc = 1
	var storage: RefCounted = Store.new()
	var signed: bool = storage.save(bogus, base_path.path_join("semantic"))
	_check("ARCH-007", "格式和校验和均合法但语义坏的存档仍先审计后拒绝", signed and not target.turn.load_archive(base_path.path_join("semantic")) and before == target.turn.snapshot())
	manifest.body.format = 999; manifest.checksum = Store.canonical(manifest.body).sha256_text()
	file = FileAccess.open(path.path_join("manifest.json"), FileAccess.WRITE); file.store_string(Store.canonical(manifest)); file.close()
	_check("ARCH-008", "未知档案格式拒绝，不修补身份或丢失旧数据", not target.turn.load_archive(path) and before == target.turn.snapshot())
func _incremental() -> void:
	var data: Dictionary = _setup(7919)
	var path: String = base_path.path_join("incremental")
	var saved: bool = data.turn.save_archive(path)
	var initial: Dictionary = data.turn.last_save_metrics.duplicate(true)
	_submit(data, "advance")
	saved = data.turn.save_archive(path) and saved
	var delta: Dictionary = data.turn.last_save_metrics.duplicate(true)
	var noop: bool = data.turn.save_archive(path)
	_check("ARCH-009", "普通保存只写新路径/变化对象，重复保存零写入", saved and delta.nodes_encoded > 0 and delta.nodes_encoded < initial.nodes_encoded and noop and data.turn.last_save_metrics.bytes_written == 0, {"bootstrap": initial, "delta": delta, "noop": data.turn.last_save_metrics})
	var restored: Dictionary = _setup(7919)
	var loaded: bool = restored.turn.load_archive(path)
	_submit(restored, "finish_events")
	_check("ARCH-010", "读档后的普通保存继续复用已落盘节点而非重写全档案", loaded and restored.turn.save_archive(path) and restored.turn.last_save_metrics.nodes_encoded < initial.nodes_encoded, {"afterLoad": restored.turn.last_save_metrics})

func _measure_growth(count: int) -> Dictionary:
	var data: Dictionary = _setup(7919)
	var origin: String = data.world.state.domains["DOMAIN-001"].origin
	var template: Dictionary = data.world.state.npcs["NPC-00000001"].duplicate(true)
	for i: int in count:
		var fact_id: String = "FACT-%08d" % int(data.world.state.next_fact)
		data.world.state.next_fact += 1
		data.world.state.facts[fact_id] = {"id": fact_id, "turn": 0, "kind": "message", "domain": "DOMAIN-001", "actor": "", "targets": [], "causal_parents": [origin], "changes": {"unrelated": i}}
		var npc_id: String = "NPC-%08d" % int(data.world.state.next_npc)
		data.world.state.next_npc += 1
		var person: Dictionary = template.duplicate(true)
		person.id = npc_id; person.status = "dead"; person.institution = ""; person.known_facts = [origin]; person.relations = []
		data.world.state.npcs[npc_id] = person
	var path: String = base_path.path_join("growth-" + str(count))
	var ok: bool = data.turn.save_archive(path)
	var initial: Dictionary = data.turn.last_save_metrics.duplicate(true)
	data.world.history.reset_metrics()
	_submit(data, "advance")
	var work: Dictionary = data.world.history.metrics.duplicate(true)
	ok = data.turn.save_archive(path) and ok
	return {"ok": ok, "bootstrap": initial, "delta": data.turn.last_save_metrics.duplicate(true), "transaction": data.turn.last_transaction_metrics.duplicate(true), "work": work}
func _growth_cost() -> void:
	var small: Dictionary = _measure_growth(0)
	var large: Dictionary = _measure_growth(2000)
	var bounded: bool = small.ok and large.ok and small.transaction.history_root_entries == 0 and large.transaction.history_root_entries == 0 and small.work.root_identity_entries == 0 and large.work.root_identity_entries == 0 and small.work.history_scanned == 0 and large.work.history_scanned == 0
	bounded = bounded and large.delta.nodes_encoded < small.delta.nodes_encoded * 4 and large.delta.nodes_encoded < large.bootstrap.nodes_encoded / 4
	_check("ARCH-011", "追加2000无关事实和墓碑后，普通提交不复制/遍历旧根，保存仅新增树路径", bounded, {"small": small, "large": large})
func _stale_writer() -> void:
	var first: Dictionary = _setup(7919)
	var path: String = base_path.path_join("stale")
	var saved: bool = first.turn.save_archive(path)
	var second: Dictionary = _setup(7919)
	var loaded: bool = second.turn.load_archive(path)
	_submit(first, "advance"); saved = first.turn.save_archive(path) and saved
	_submit(second, "advance")
	var rejected: bool = not second.turn.save_archive(path)
	var recovered: Dictionary = _setup(7919)
	_check("ARCH-012", "过时存储实例不能覆盖另一实例已发布的成功提交", saved and loaded and rejected and recovered.turn.load_archive(path) and recovered.turn.snapshot() == first.turn.snapshot())
func _failed_action() -> void:
	var data: Dictionary = _setup(7919)
	_submit(data, "advance"); _submit(data, "finish_events")
	var before: String = data.turn.snapshot()
	_submit(data, "act", {"participant": "tx-fixture", "action": "failed_batch", "payload": {}}, false)
	var same: bool = data.turn.snapshot() == before and data.turn.last_transaction_metrics.history_root_entries == 0
	var path: String = base_path.path_join("failed-action")
	var restored: Dictionary = _setup(7919)
	_check("ARCH-013", "失败行动丢弃覆盖层，世界/随机/请求与存档均不留下半笔", same and data.turn.save_archive(path) and restored.turn.load_archive(path) and restored.turn.snapshot() == before)

func _short_writes() -> void:
	var results: Dictionary = {}
	for stage: String in ["segment", "manifest"]:
		var data: Dictionary = _setup(7919)
		var storage: RefCounted = ShortWriter.new()
		var path: String = base_path.path_join("short-" + stage)
		var saved: bool = storage.save(data.turn, path)
		var before: String = data.turn.snapshot()
		var manifest: String = FileAccess.get_file_as_string(path.path_join("manifest.json"))
		_submit(data, "advance")
		# Measure this exact pending delta with prepublication interruption, then
		# inject a real truncated write at its first segment or final pending manifest.
		storage.writes = 0
		storage.save(data.turn, path, "manifest")
		var count: int = storage.writes
		storage.writes = 0; storage.fail_at = 1 if stage == "segment" else count
		var rejected: bool = not storage.save(data.turn, path)
		var restored: Dictionary = _setup(1981)
		results[stage] = saved and rejected and FileAccess.get_file_as_string(path.path_join("manifest.json")) == manifest and restored.turn.load_archive(path) and restored.turn.snapshot() == before
	_check("ARCH-014", "段与待发布清单短写均拒绝，不改变已发布清单或可恢复会话", not false in results.values(), results)

func _sequence_keys() -> void:
	var data: Dictionary = _setup(7919)
	_submit(data, "advance")
	var bogus: RefCounted = InvalidSession.new()
	bogus.checkpoint = HistoryIndex.export_value(data.turn._archive_checkpoint())
	var shifted: Dictionary = {}
	var journal: Array = bogus.checkpoint.context.journal
	for index: int in journal.size(): shifted["%012d" % (index + 1)] = journal[index]
	bogus.checkpoint.context.journal = HistoryIndex.from_value(shifted, "sequence")
	var storage: RefCounted = Store.new()
	var path: String = base_path.path_join("shifted-sequence")
	var saved: bool = storage.save(bogus, path)
	var target: Dictionary = _setup(1981); var before: String = target.turn.snapshot()
	_check("ARCH-015", "合法校验和但序列键偏移的日志拒绝，避免续写覆盖已提交日志", saved and not target.turn.load_archive(path) and target.turn.snapshot() == before, {"error": target.turn.last_error})
