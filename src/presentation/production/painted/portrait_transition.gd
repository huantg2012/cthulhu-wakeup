extends CanvasLayer
## Public world observations accompany preparation; this layer owns no rules.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
var _ui := UI.new()
var _body: Control
var _progress: Label
var _bar: ProgressBar
var _worlds: Dictionary = {}

func _ready() -> void:
	layer = 20
	hide()

func begin(projection: Dictionary, worlds: Array) -> void:
	if _body != null:
		remove_child(_body)
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.theme = Paint.native_theme()
	add_child(_body)
	_ui.fill(_body, "Night", Rect2(0, 0, 1280, 720), Color("080e12"))
	_ui.image(_body, "Pigment", Rect2(0, 0, 1280, 720), Paint.MaterialSource.pigment("sky"), Color(1,1,1,.55), TextureRect.STRETCH_SCALE)
	_ui.label(_body, "Turn", "第 %s 轮 · 诸界流转" % projection.turn, Rect2(120, 84, 900, 32), 18, Paint.MUTED)
	_ui.label(_body, "Heading", "你的意志，仍与诸界相连", Rect2(120, 129, 1040, 54), 30, Paint.BONE, true)
	_progress = _ui.label(_body, "Progress", "已知的联系正在显现…", Rect2(120, 200, 1040, 30), 17, Paint.MUTED)
	_ui.label(_body, "Observation", "当前掌握的诸界情报", Rect2(120, 237, 1040, 22), 14, Paint.MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(120, 264)
	scroll.size = Vector2(1040, 291)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 19)
	scroll.add_child(rows)
	_worlds.clear()
	for world: Dictionary in worlds:
		var line := Label.new()
		line.text = world.title + "\n" + world.observation
		line.add_theme_font_size_override("font_size", 16)
		line.add_theme_color_override("font_color", Paint.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(line)
		_worlds[world.id] = {"label": line, "title": world.title}
	_bar = ProgressBar.new()
	_bar.position = Vector2(120, 601)
	_bar.size = Vector2(1040, 4)
	_bar.show_percentage = false
	_bar.add_theme_font_size_override("font_size", 1)
	for state: String in ["background", "fill"]:
		var ink := StyleBoxFlat.new()
		ink.bg_color = Paint.ACCENT if state == "fill" else Paint.FIELD
		_bar.add_theme_stylebox_override(state, ink)
	_body.add_child(_bar)
	_bar.set_deferred("size", Vector2(1040, 4))
	show()

func report(done: int, total: int, world_id: String) -> void:
	if not visible: return
	var title := str(_worlds.get(world_id, {}).get("title", "已知联系"))
	_progress.text = "%s · 显影 %s / %s" % [title, done, total]
	_bar.max_value = maxi(1, total)
	_bar.value = done
	for id: String in _worlds:
		_worlds[id].label.add_theme_color_override("font_color", Paint.BONE if id == world_id else Paint.MUTED)
