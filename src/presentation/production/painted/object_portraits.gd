extends Node
## Prepare the public cast before revealing a playable scene. Identity and
## generation order never consume gameplay randomness.
const Service = preload("res://src/art_generation/service.gd")
const CACHE := "user://object-portraits/v1"
const VERSION := "object-art-1"
const MEMORY_LIMIT := 24
const DISK_LIMIT := 128 * 1024 * 1024
var _service: Node
var _catalog := preload("res://src/art_generation/catalog.gd").new()
var _profiles: Dictionary = {}
var _textures: Dictionary = {}
var _recent: Array[String] = []
var _jobs: Dictionary = {}
var _running := false
var _failed: Dictionary = {}
signal preparation_progress(done: int, total: int, world_id: String)
signal preparation_finished
var cache_directory := CACHE
var preparing := false
var _wanted: Dictionary = {}
var _pending: Dictionary = {}
var _io_tasks: Array[int] = []
var generated_count := 0
var disk_read_count := 0

func _ready() -> void:
	for row: Dictionary in _catalog.templates:
		if not str(row.civilization_id).is_empty():
			_profiles[row.civilization_id] = row
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_directory))
	_io_tasks.append(WorkerThreadPool.add_task(_prune_disk.bind(cache_directory)))

func _exit_tree() -> void:
	for task: int in _io_tasks:
		WorkerThreadPool.wait_for_task_completion(task)

func _reap_io() -> void:
	for index: int in range(_io_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_io_tasks[index]):
			WorkerThreadPool.wait_for_task_completion(_io_tasks[index])
			_io_tasks.remove_at(index)

func prepare(arts: Array) -> void:
	_wanted.clear()
	_pending.clear()
	for art: Dictionary in arts:
		if art.is_empty(): continue
		_wanted[art.key] = true
		if _textures.has(art.key) or DisplayServer.get_name() == "headless": continue
		if _failed.has(art.key) and Time.get_ticks_msec() - int(_failed[art.key]) < 3000: continue
		_pending[art.key] = true
		if not _jobs.has(art.key): _jobs[art.key] = {"art": art, "targets": {}}
	preparing = not _pending.is_empty()
	_trim_memory()
	if preparing and not _running:
		_running = true
		_drain.call_deferred()

func _trim_memory() -> void:
	var idle: Array[String] = []
	for key: String in _recent:
		if not _wanted.has(key): idle.append(key)
	while idle.size() > MEMORY_LIMIT:
		var key: String = idle.pop_front()
		_recent.erase(key)
		_textures.erase(key)

func recipe(kind: String, campaign_seed: String, subject: Dictionary, world: Dictionary) -> Dictionary:
	if kind == "cult" and subject.get("status", "") == "destroyed": return {}
	var profile: String = world.get("profile", "")
	if campaign_seed.is_empty() or not _profiles.has(profile) or not subject.has("id"):
		return {}
	var entry: Dictionary = _profiles[profile]
	var request := {"template": entry.id, "seed": _seed("world", campaign_seed, world.id) % 1000000,
		"style": int(entry.production_style_sid), "palette": _catalog.cults[int(entry.archetype)].default_palette}
	var options := {}
	if kind == "person":
		var person_profile: String = subject.get("profile", "")
		var background: Dictionary = _catalog.person_profiles.get(person_profile, {})
		if background.is_empty(): return {}
		options = {"seed": _seed("person", campaign_seed, subject.id), "profile": person_profile, "appearance": background}
	return {"request": request, "options": options, "kind": kind,
		"key": JSON.stringify([VERSION, Service.REVISION, kind, subject.id, request, options]).sha256_text()}

func _seed(kind: String, campaign_seed: String, subject_id: String) -> int:
	return JSON.stringify([kind, campaign_seed, subject_id]).sha256_text().left(8).hex_to_int()

func bind(slot: TextureRect, art: Dictionary, status: Label = null) -> void:
	slot.texture = null
	var key: String = art.get("key", "")
	slot.set_meta("art_key", key)
	if status != null: status.text = "尚无可靠图像" if key.is_empty() else "正在显影…"
	if key.is_empty(): return
	var target: WeakRef = weakref(slot)
	var note: WeakRef = weakref(status) if status != null else null
	if _textures.has(key):
		_touch(key)
		_display(target, note, key, _textures[key])
		return
	slot.visibility_changed.connect(_on_visibility.bind(target, note, art))
	var scroll := _scroller_for(slot)
	if scroll != null:
		var bar := scroll.get_v_scroll_bar()
		var moved := func(_value: float) -> void: _on_visibility(target, note, art)
		bar.value_changed.connect(moved)
		slot.tree_exiting.connect(func() -> void:
			if is_instance_valid(bar) and bar.value_changed.is_connected(moved): bar.value_changed.disconnect(moved),
			CONNECT_ONE_SHOT)
	_on_visibility.call_deferred(target, note, art)

func _scroller_for(slot: TextureRect) -> ScrollContainer:
	var node := slot.get_parent()
	while node != null:
		if node is ScrollContainer: return node
		node = node.get_parent()
	return null

func _visible(slot: TextureRect) -> bool:
	if not slot.is_visible_in_tree(): return false
	var scroll := _scroller_for(slot)
	return scroll == null or scroll.get_global_rect().intersects(slot.get_global_rect())

func _on_visibility(target: WeakRef, note: WeakRef, art: Dictionary) -> void:
	var slot := target.get_ref() as TextureRect
	if slot != null and _visible(slot) and slot.texture == null and slot.get_meta("art_key", "") == art.key:
		_enqueue(target, note, art)

func _enqueue(target: WeakRef, note: WeakRef, art: Dictionary) -> void:
	var key: String = art.key
	if _textures.has(key):
		_touch(key)
		_display(target, note, key, _textures[key])
		return
	if DisplayServer.get_name() == "headless" or (_failed.has(key) and Time.get_ticks_msec() - int(_failed[key]) < 3000):
		_display(target, note, key, null)
		return
	if not _jobs.has(key): _jobs[key] = {"art": art, "targets": {}}
	var slot := target.get_ref() as TextureRect
	if slot != null: _jobs[key].targets[slot.get_instance_id()] = [target, note]
	if not _running:
		_running = true
		_drain.call_deferred()

func _drain() -> void:
	while not _jobs.is_empty() and is_inside_tree():
		var key: String = _jobs.keys()[0]
		var job: Dictionary = _jobs[key]
		var useful: bool = _wanted.has(key) or job.targets.values().any(func(t: Array) -> bool:
			var slot := (t[0] as WeakRef).get_ref() as TextureRect
			return slot != null and _visible(slot) and slot.get_meta("art_key", "") == key)
		if not useful:
			_jobs.erase(key)
			continue
		await get_tree().process_frame
		preparation_progress.emit(_wanted.size() - _pending.size(), _wanted.size(), str(job.art.get("world_id", "")))
		_reap_io()
		var path := cache_directory.path_join(key + ".png")
		var image: Image
		if FileAccess.file_exists(path):
			var loaded := {}
			var task := WorkerThreadPool.add_task(func() -> void: loaded.image = Image.load_from_file(path))
			_io_tasks.append(task)
			while not WorkerThreadPool.is_task_completed(task): await get_tree().process_frame
			WorkerThreadPool.wait_for_task_completion(task)
			_io_tasks.erase(task)
			image = loaded.get("image")
			disk_read_count += 1
		if image == null or image.get_size() != Vector2i(960, 960):
			if _service == null:
				_service = Service.new()
				_service.catalog = _catalog
				add_child(_service)
			var result: Dictionary = await _service.generate_subject(job.art.kind, job.art.request, job.art.options)
			generated_count += 1
			image = result.get("image")
			if image != null and not image.is_empty():
				_io_tasks.append(WorkerThreadPool.add_task(_persist.bind(image, path), false, "Save object portrait"))
		var texture: Texture2D
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
			_textures[key] = texture
			_failed.erase(key)
			_touch(key)
			_trim_memory()
		else:
			_failed[key] = Time.get_ticks_msec()
		for t: Array in job.targets.values(): _display(t[0], t[1], key, texture)
		_jobs.erase(key)
		_pending.erase(key)
		preparation_progress.emit(_wanted.size() - _pending.size(), _wanted.size(), str(job.art.get("world_id", "")))
		if preparing and _pending.is_empty():
			preparing = false
			preparation_finished.emit()
	_running = false
	_reap_io()
	_io_tasks.append(WorkerThreadPool.add_task(_prune_disk.bind(cache_directory)))

func _display(target: WeakRef, note: WeakRef, key: String, texture: Texture2D) -> void:
	var slot := target.get_ref() as TextureRect
	if slot == null or not slot.is_inside_tree() or slot.is_queued_for_deletion() or slot.get_meta("art_key", "") != key: return
	slot.texture = texture
	var status := note.get_ref() as Label if note != null else null
	if status != null:
		status.visible = texture == null
		if texture == null: status.text = "图像暂不可用"

func _touch(key: String) -> void:
	_recent.erase(key)
	_recent.append(key)

static func _persist(image: Image, path: String) -> void:
	var temporary := path + ".%d.tmp" % OS.get_process_id()
	if image.save_png(temporary) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

static func _prune_disk(directory: String) -> void:
	var files: Array[String] = []
	var bytes := 0
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".png"): continue
		var path := directory.path_join(name)
		files.append(path)
		bytes += FileAccess.get_size(path)
	if bytes <= DISK_LIMIT: return
	files.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) < FileAccess.get_modified_time(b))
	for path: String in files:
		var size := FileAccess.get_size(path)
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK: bytes -= size
		if bytes <= DISK_LIMIT: break
