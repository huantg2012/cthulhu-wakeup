extends RefCounted
## Scene composition for the locked interaction framework. Only public
## projection rows are rendered. Controls route back to the production views.
const UI = preload("res://src/presentation/production/locked_controls.gd")

const Layout = preload("res://src/presentation/production/perception_layout.gd")
const Fan = preload("res://src/presentation/production/painted/card_fan.gd")
const Card = preload("res://src/presentation/production/painted/world_card.gd")
const METRIC_SIGNS := {"barrier": "◇", "pollution": "◉", "alert": "◆", "stability": "▥"}

var _host: WeakRef
var _textures := {}
var _overview_focus := ""
var _attention_kind := ""
var _attention_worlds: Array[String] = []
var host: Control:
	get: return _host.get_ref()

func _init(owner: Control) -> void:
	_host = weakref(owner)

func picture(kind: String) -> Texture2D:
	if _textures.has(kind): return _textures[kind]
	var shape: String
	var extent := 'width="600" height="380" viewBox="0 0 600 380"'
	match kind:
		"atmosphere":
			shape = ""
		"contact":
			shape = '<ellipse cx="300" cy="250" rx="178" ry="44" fill="none" stroke="#779cae" stroke-opacity=".6"/><ellipse cx="300" cy="250" rx="144" ry="32" fill="none" stroke="#779cae" stroke-opacity=".3"/><path d="M300 68v144" stroke="#a4bec8" stroke-opacity=".6"/>'
		"rings":
			extent = 'width="600" height="166" viewBox="0 170 600 166"'
			shape = '<g fill="none" stroke="#83a6b7"><ellipse cx="300" cy="252" rx="282" ry="69" stroke-opacity=".43"/><ellipse cx="300" cy="252" rx="243" ry="51" stroke-opacity=".29"/><ellipse cx="300" cy="252" rx="200" ry="34" stroke-opacity=".18"/></g>'
		_:
			shape = '<path d="M92 249l125-57 153 4 138 52-97 61-126 44-105-46z" fill="#253d4a" stroke="#658895"/><path d="M92 249l205 49 211-50M297 298l-12 55" fill="none" stroke="#698591"/><path d="M164 237v-62l53-25 48 26v77l-48 19zM330 239V98l61-31 58 32v157l-58 28z" fill="#4b6573"/><path d="M391 67v217l58-28V99zM217 150v122l48-19v-77z" fill="#314957"/><path d="M153 173l64-33 59 34-59 31zM318 98l73-39 70 40-70 38z" fill="#8298a1"/>'
	var halo := '<defs><radialGradient id="h"><stop stop-color="#638798" stop-opacity=".26"/><stop offset="1" stop-color="#638798" stop-opacity="0"/></radialGradient></defs><ellipse cx="300" cy="205" rx="296" ry="174" fill="url(#h)"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" %s>%s%s</svg>' % [extent, "" if kind == "rings" else halo, shape]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_textures[kind] = ImageTexture.create_from_image(image)
	return _textures[kind]

func _svg(key: String, drawing: String) -> Texture2D:
	var bitmap := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">%s</svg>' % drawing
	bitmap.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(bitmap)
	_textures[key] = texture
	return texture

func overview() -> void:
	var stage: Control = host._stage
	var requests: Array = host._pending_prayers()
	_world_fan(stage, _ranked_worlds(requests))
	_crumb(stage)
	_title(stage, "界外 / 神意未至", "诸界态势", "机会尚未消失，责任仍在延续。\n先决定，把你的意志投向哪里。")
	var anchors: Array = host.projection.get("anchors", [])
	var plans: Array = host.projection.get("resistance", [])
	_obligation(stage, "AllAnchors", "尚无已知锚点" if anchors.is_empty() else "%d 处锚点与供奉责任" % anchors.size(), 548, _highlight_worlds.bind("anchor"))
	var summary := "%d 声祈求尚未回应" % requests.size() if not requests.is_empty() else "尚无待回应的祈求"
	if host.projection.get("prayer_response_spent", false) and not requests.is_empty(): summary = "%d 声祈求 · 本轮回应已用" % requests.size()
	_obligation(stage, "PrayerIndex", summary, 576, _highlight_worlds.bind("prayer"))
	_obligation(stage, "ResistanceIndex", "%d 项反制预告" % plans.size() if not plans.is_empty() else "暂无反制预告", 604, _highlight_worlds.bind("resistance"))
	for item: Array in [["AllAnchors","anchor"],["PrayerIndex","prayer"],["ResistanceIndex","resistance"]]:
		var control: Button = stage.find_child(item[0],true,false)
		control.disabled = _related_worlds(item[1]).is_empty()
		control.tooltip_text = "标出对应世界；再次点击逐个定位" if not control.disabled else "暂无对应世界"
	var hint := _label(stage,"WorldAttentionHint","",Rect2(425,757,1000,25),14,UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_link(stage,"ClearWorldAttention","收起标记 ×",Rect2(1000,789,170,26),_clear_world_attention).visible = false
	_apply_world_attention()

func _related_worlds(kind: String) -> Array[String]:
	var result: Array[String] = []
	var rows: Array = host._pending_prayers() if kind == "prayer" else host.projection.get("anchors" if kind == "anchor" else "resistance",[])
	for row: Dictionary in rows:
		var domain := str(row.get("descriptor",{}).get("domain",row.get("card",{}).get("domain",""))) if kind == "prayer" else str(row.get("domain",""))
		if not domain.is_empty() and not result.has(domain) and host._worlds.any(func(w: Dictionary) -> bool: return w.id == domain): result.append(domain)
	return result

func _highlight_worlds(kind: String) -> void:
	var fan: Control = host._stage.get_node_or_null("WorldFan")
	if fan == null or fan._blocked: return
	var related := _related_worlds(kind)
	if related.is_empty(): return
	var candidates: Array[int] = []
	for i: int in fan.cards.size():
		if related.has(str(fan.cards[i].get_meta("subject_id"))): candidates.append(i)
	if candidates.is_empty(): return
	var index := candidates[0]
	if _attention_kind == kind:
		var current := candidates.find(fan.focus_index)
		index = candidates[(current+1)%candidates.size()]
	_attention_kind = kind
	_apply_world_attention()
	fan.set_focus(index)
	fan.grab_focus()

func _apply_world_attention() -> void:
	var fan: Control = host._stage.get_node_or_null("WorldFan")
	if fan == null: return
	_attention_worlds.clear()
	if not _attention_kind.is_empty(): _attention_worlds.assign(_related_worlds(_attention_kind))
	if _attention_worlds.is_empty(): _attention_kind = ""
	for card: Control in fan.cards:
		card.set_attention(_attention_kind if _attention_worlds.has(str(card.get_meta("subject_id"))) else "")
	var hint: Label = host._stage.find_child("WorldAttentionHint",true,false)
	if hint != null:
		var label := str({"anchor":"锚点","prayer":"祈求","resistance":"反制预告"}.get(_attention_kind,""))
		hint.text = "已标出 %d 个%s所在世界 · 再点摘要逐个定位，确认进入世界" % [_attention_worlds.size(),label] if not _attention_kind.is_empty() else ""
	var clear: Control = host._stage.find_child("ClearWorldAttention",true,false)
	if clear != null: clear.visible = not _attention_kind.is_empty()

func _clear_world_attention() -> void:
	_attention_kind = ""
	_apply_world_attention()
	var fan: Control = host._stage.get_node_or_null("WorldFan")
	if fan != null: fan.grab_focus()

func _world_fan(stage: Control, worlds: Array) -> void:
	if worlds.is_empty():
		_label(stage, "NoWorlds", "尚未感知可查看的世界", Rect2(548, 402, 790, 52), 21, UI.MUTED)
		return
	var fan := Fan.new()
	fan.name = "WorldFan"
	fan.position = Vector2(318, 126)
	fan.size = Vector2(920, 450)
	fan.accessibility_name = "已知世界"
	stage.add_child(fan)
	var counter: Label = host._ui.label(stage, "WorldCardPosition", "", Rect2(345, 558, 870, 28), host._size(16), UI.BONE)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cards: Array[Control] = []
	var ids: Array[String] = []
	var names: Array[String] = []
	var tips: Array[String] = []
	for world: Dictionary in worlds:
		var id: String = world.id
		ids.append(id)
		names.append(world.title)
		tips.append(host._views.world_metrics_text(host, id, true))
		var data := {"id": id, "title": world.title, "status": _world_status(world),
			"relation": "已关注" if world.get("focused", false) else world.get("已知范围", "已知联系"),
			"tier_title": {"planet": "星球", "system": "星系", "cosmic": "宇宙"}.get(world.get("tier", ""), "层级未明"),
			"art_recipe": host._portraits.recipe("world", host.session.visual_seed(), world, world)}
		var metrics: Array[String] = []
		for field: String in ["barrier", "pollution", "alert", "stability"]:
			metrics.append("%s%s" % [host._views.WORLD_METRICS[field], host._views.metric_display(world, field).value])
		data.metrics = ["  ".join(metrics.slice(0, 2)), "  ".join(metrics.slice(2, 4))]
		var card := Card.new()
		card.build(host._ui, data, cards.size(), host._size(0), host._portraits)
		cards.append(card)
	var previous := ids.find(_overview_focus)
	fan.card_chosen.connect(func(index: int) -> void: host._inspect_world(ids[index]))
	var update := func(index: int) -> void:
		_overview_focus = ids[index]
		counter.text = "%s  ·  ‹ %02d / %02d ›" % [names[index], index + 1, ids.size()]
		fan.accessibility_description = names[index] + "。左右键浏览，确认进入。"
		fan.tooltip_text = names[index] + "\n" + tips[index]
	fan.focus_changed.connect(update)
	fan.configure(cards)
	fan.set_focus(maxi(0, previous), false)
	update.call(fan.focus_index)

func _ranked_worlds(requests: Array) -> Array:
	var worlds: Array = host._worlds.duplicate()
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first := _priority(a, requests)
		var second := _priority(b, requests)
		return first > second or (first == second and str(a.id) < str(b.id)))
	return worlds

func _priority(world: Dictionary, requests: Array) -> int:
	var id: String = world.id
	var priority := 4 if not host._views.world_plans(host, id).is_empty() else 0
	if requests.any(func(p: Dictionary) -> bool: return p.descriptor.get("domain", "") == id): priority += 2
	if world.get("focused", false): priority += 1
	return priority

func reset_worlds() -> void:
	_overview_focus = ""
	_attention_kind = ""
	_attention_worlds.clear()

func _render_worlds(parent: Control, worlds: Array) -> void:
	var frames: Array = Layout.LOCAL_REALMS
	var captions: Array = Layout.LOCAL_CAPTIONS
	for index: int in mini(worlds.size(), frames.size()):
		_world_fragment(parent, worlds[index], frames[index], captions[index], index)

func _world_fragment(parent: Control, world: Dictionary, frame: Rect2, caption: Rect2, index: int) -> void:
	var id: String = world.id
	var tint := Color(1, 1, 1, [1.0, 0.74, 0.74][index])
	var art_box := Layout.box(frame)
	if index == 0:
		# Keep the existing focal centre. Leave the left rail, header and footer clear
		# even when the complete square illustration has a bright paper background.
		art_box = Rect2(art_box.get_center() - Vector2(178, 178), Vector2(356, 356))
		host._scene_plate(parent, "LocalWorldStock", Rect2(art_box.grow(7).position / Layout.SCALE, art_box.grow(7).size / Layout.SCALE), UI.FIELD)
	else:
		art_box = Rect2(Layout.box(caption).position - Vector2(0, 83), Vector2(80, 80))
	host._object_art(parent, "SceneSlot" if index == 0 else "WorldThumbnail_" + id, art_box, "world", id, index == 0)
	# Neighbour copy remains subordinate; generated image colours are unmodified.
	if index == 0: return
	# Hit target starts at the visible world and ends after the metric strip.
	var hit := Rect2(frame.position.x, maxf(frame.position.y, 138), minf(frame.size.x, 1600 - frame.position.x), maxf(frame.end.y, caption.end.y) - maxf(frame.position.y, 138))
	var button: Button = host._button(parent, "World_" + id, "", Layout.box(hit), host._inspect_world.bind(id))
	# The old transparent hit area remains while B02 replaces it with the card carrier.
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.accessibility_name = str(world.title)
	button.tooltip_text = host._views.world_metrics_text(host, id, true)
	var at := caption.position - hit.position
	var origin := str({"planet": "星球", "system": "星系", "cosmic": "宇宙"}.get(world.get("tier", ""), "层级未明"))
	var relation := "已关注" if world.get("focused", false) else str(world.get("已知范围", "已知联系"))
	var width := minf(160.0, 1600.0 - caption.position.x)
	_label(button, "WorldName", str(world.title), Rect2(at, Vector2(width, 26)), 18, UI.BONE).modulate = tint
	_label(button, "WorldOverline", relation + " / " + origin, Rect2(at + Vector2(0, 25), Vector2(width, 23)), 14, UI.MUTED).modulate = tint
	var reads := PackedStringArray()
	for field: String in host._views.WORLD_METRICS:
		reads.append("%s%s" % [METRIC_SIGNS[field], host._views.metric_display(world, field).value])
	for row: int in 2:
		var pair := "  ".join(reads.slice(2 * row, 2 * row + 2))
		_label(button, "WorldMetrics%d" % row, pair, Rect2(at + Vector2(0, 50 + 23 * row), Vector2(width, 23)), 14, UI.MUTED).modulate = tint
	button.tooltip_text = _world_status(world) + "\n" + button.tooltip_text
	host._world_buttons[id] = button

func _world_status(world: Dictionary) -> String:
	var id: String = world.id
	var plans: Array = host._views.world_plans(host, id)
	if not plans.is_empty(): return "反制预告 · " + host._tasks.crisis_summary(plans[0])
	var anchors: Array = _local_rows("anchors", id)
	if not anchors.is_empty(): return "%d 处已知锚点 · 可查看维系状态" % anchors.size()
	var requests: Array = host._prayers.local_requests(id)
	if not requests.is_empty(): return "%d 声祈求尚未回应" % requests.size()
	var opportunities: Array = host._views.current_opportunities(host, id)
	if not opportunities.is_empty(): return "%d 项限时圣物机会" % opportunities.size()
	return "可查当地情报与联系"

func local(world: Dictionary) -> void:
	var id: String = world.id
	var body: Control = host._world_body
	var requests: Array = host._prayers.local_requests(id)
	var worlds := _ranked_worlds(host._pending_prayers())
	worlds.erase(world)
	worlds.push_front(world)
	_render_worlds(body, worlds)
	_crumb(body, str(world.title))
	_title(body, "通过梦与见证所知", str(world.title), "联系仍在延续。你的干预，将从这里开始。")
	_intelligence(body, world)
	var institutions := _local_rows("institutions", id)
	var anchors := _local_rows("anchors", id)
	var cult: Dictionary = host._views._current_cult(host, id)
	var threads := PackedStringArray()
	if not cult.is_empty(): threads.append("M777 290Q700 364 465 430")
	if not requests.is_empty(): threads.append("M777 290Q860 337 995 467")
	threads.append("M777 290Q914 278 1090 316")
	if not cult.is_empty(): threads.append("M465 430Q510 544 677 568")
	var thread_key := "threads/" + str(threads)
	var thread: Texture2D = _textures.get(thread_key)
	if thread == null:
		thread = _svg(thread_key, '<path d="%s" fill="none" stroke="#829078" stroke-opacity=".25" stroke-dasharray="3 8"/>' % " ".join(threads))
	host._ui.image(body, "Threads", Rect2(0, 0, 1280, 720), thread, Color.WHITE, TextureRect.STRETCH_SCALE)
	var anchor_title: String = "锚点与护持" if institutions.size() != 1 else host.title(str(institutions[0].id))
	var anchor_status := "查看机构与锚定条件" if anchors.is_empty() else "%d 处锚点 · 查看状态" % anchors.size()
	pin(body, "AnchorIndex", anchor_title, anchor_status, "anchor_status", Layout.PIN_ANCHOR, host._tasks.open_subject.bind("anchors", id), true)
	if not cult.is_empty():
		pin(body, "LocalCult", host._views._cult_name(host, cult), "%s 名信众 · 凝聚 %s" % [cult.followers, cult.cohesion], "cult", Layout.PIN_CULT, host._world_management.open_cult.bind(id))
	var opportunities: Array = host._views.current_opportunities(host, id)
	var relic_name := "WorldOpportunities" if not opportunities.is_empty() else "LocalRelics"
	var relic_status := "%d 项机会 · 查看条件" % opportunities.size() if not opportunities.is_empty() else "持有与绑定状态"
	pin(body, relic_name, "当地圣物", relic_status, "◇", Layout.PIN_RELIC, host._tasks.open_subject.bind("relics", id))
	pin(body, "Activities", "持续活动", "安排活动 · 继续已有进展", "ritual", Layout.PIN_ACTIVITY, host._tasks.open_activities.bind(id))
	host._prayers.build_contact(body, id, requests)

func _local_rows(collection: String, id: String) -> Array:
	return host.projection.get(collection, []).filter(func(row: Dictionary) -> bool: return row.get("domain", "") == id)

func _intelligence(parent: Control, world: Dictionary) -> void:
	var sources := PackedStringArray()
	var id: String = world.id
	var index := 0
	for field: String in host._views.WORLD_METRICS:
		var metric: Dictionary = host._views.metric_display(world, field)
		var bounds := Layout.METRICS
		bounds.position.y += 40 * index
		var row: Button = host._button(parent, "MetricHelp_" + field, "", Layout.box(bounds), host._world_management.open_intelligence.bind(id, field))
		row.accessibility_name = "%s %s" % [host._views.WORLD_METRICS[field], metric.value]
		row.accessibility_description = host._views.metric_help_text(world, field)
		row.tooltip_text = host._views.WORLD_METRIC_MEANINGS[field] + "\n" + row.accessibility_description
		row.mouse_entered.connect(host._update_metric_hint)
		row.mouse_exited.connect(host._update_metric_hint)
		row.focus_entered.connect(host._update_metric_hint)
		row.focus_exited.connect(host._update_metric_hint)
		_label(row, "MetricName", "%s %s" % [METRIC_SIGNS[field], host._views.WORLD_METRICS[field]], Rect2(0, 0, 152, 37), 16, UI.MUTED)
		_label(row, "MetricValue", str(metric.value), Rect2(154, 0, 111, 37), 16, UI.BONE, false, 0.0, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		host._ui.fill(row, "MetricRule", Layout.box(Rect2(0, 39, 265, 1)), Color(UI.LINE, 0.38))
		if not str(metric.source) in sources: sources.append(str(metric.source))
		index += 1
	var source := "时点与精度因指标而异" if sources.size() > 1 else sources[0]
	if sources.size() == 1:
		var snapshot: Dictionary = world.get("metric_sources", {}).get("barrier", {})
		if snapshot.get("turn") is int:
			source = "第 %d 轮快照 · %s" % [snapshot.turn, "确知" if snapshot.get("precision") == "exact" else "区间估计"]
		elif not snapshot.has("value"): source = "尚无完整世界观测"
	_label(parent, "MetricSource", source, Rect2(78, 488, 265, 22), 12, UI.MUTED)
	_label(parent, "MetricHint", "", Rect2(78, 507, 320, 20), 11, UI.MUTED)
	_link(parent, "WorldObservations", "情报与反制 →", Rect2(78, 531, 114, 34), host._world_management.open_intelligence.bind(id), 13)
	_link(parent, "LocalPeople", "人物", Rect2(197, 531, 45, 34), host._tasks.open_subject.bind("people", id), 13)
	_link(parent, "LocalHistory", "编年史", Rect2(246, 531, 68, 34), host._tasks.open_subject.bind("history", id), 13)

func _crumb(parent: Control, world := "") -> void:
	var button := _link(parent, "WorldOverview", "◌ 诸界", Rect2(49, 100, 62, 36), host._inspect_world.bind(""), 16, UI.MUTED)
	if not world.is_empty():
		_label(parent, "CrumbWorld", "›    " + world, Rect2(119, 100, 468, 36), 16)
	else: button.focus_mode = Control.FOCUS_NONE

func _title(parent: Control, eyebrow: String, title_value: String, premise: String) -> void:
	_label(parent, "Perspective", eyebrow, Rect2(78, 181, 440, 18), 13, UI.CYAN, false, 5)
	_label(parent, "PerceptionTitle", title_value, Rect2(78, 215, 500, 59), 45, UI.BONE, true, 7)
	var lines := premise.split("\n")
	for index: int in lines.size():
		_label(parent, "PerceptionPremise", lines[index], Rect2(78, 290 + 29 * index, 420, 29), 16, UI.MUTED)

func _obligation(parent: Control, node_name: String, text_value: String, y: float, callback: Callable) -> void:
	var row := _link(parent, node_name, "", Rect2(79, y, 301, 28), callback)
	host._ui.style_action(row, false, false)
	row.accessibility_name = text_value
	host._ui.icon(row, "Marker", "attention_dot", Layout.box(Rect2(0, 11, 6, 6)), UI.GOLD)
	_label(row, "Obligation", text_value, Rect2(18, 0, 278, 28), 15, UI.MUTED)

func _link(parent: Control, node_name: String, text_value: String, bounds: Rect2, callback: Callable, px := 15, tint := UI.CYAN) -> Button:
	var button: Button = host._button(parent, node_name, "", Layout.box(bounds), callback)
	button.accessibility_name = text_value
	if not text_value.is_empty():
		_label(button, "LinkText", text_value, Rect2(Vector2.ZERO, bounds.size), px, tint)
	return button

func _label(parent: Node, node_name: String, value: String, bounds: Rect2, px: float, color := UI.BONE, heading := false, tracking := 0.0, emphasis := false) -> Label:
	return host._ui.reference_label(parent, node_name, value, bounds, px, color, heading, tracking, host._size(0), emphasis)

func pin(parent: Control, node_name: String, caption: String, detail: String, sign: String, at: Vector2, callback: Callable, warn := false) -> Button:
	var button: Button = host._button(parent, node_name, "", Layout.box(Rect2(at, Vector2(278, 64))), callback)
	var stock: Panel = Panel.new()
	host._ui.rect(stock, Rect2(Vector2.ZERO, button.size))
	stock.add_theme_stylebox_override("panel", UI.Paint.reading_plate(0.98))
	# The stock is opaque over the illustration; draw interaction state on top of it.
	parent.add_child(stock)
	stock.position = button.position
	parent.move_child(stock, button.get_index())
	button.accessibility_name = caption + " · " + detail
	button.tooltip_text = detail
	seal(button, "Seal", sign, Rect2(12, 10.5, 43, 43), 23)
	_label(button, "ContactTitle", caption, Rect2(67, 9, 211, 25), 18, UI.BONE, false, 2, true)
	_label(button, "ContactStatus", detail, Rect2(67, 37, 211, 18), 13, UI.GOLD if warn else UI.MUTED)
	return button

func seal(parent: Control, node_name: String, sign: String, bounds: Rect2, px: int, quiet := false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT if quiet else Color(UI.FIELD, 0.95)
	style.border_color = Color(UI.LINE, 0.8) if quiet else UI.CYAN
	style.set_border_width_all(1)
	style.set_corner_radius_all(ceil(Layout.box(bounds).size.x / 2))
	var plate := Panel.new()
	host._ui.rect(plate, Layout.box(bounds))
	plate.add_theme_stylebox_override("panel", style)
	parent.add_child(plate)
	if sign in ["anchor_status", "cult", "ritual"]:
		host._ui.icon(parent, node_name, sign, Layout.box(bounds.grow(-8)), UI.BONE)
	else:
		_label(parent, node_name, sign, bounds, px).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func action_layout(task, box: VBoxContainer, row: Dictionary, selection: Dictionary, actions, note: String) -> Dictionary:
	var canvas := Control.new()
	canvas.name = "ActionComposition"
	canvas.custom_minimum_size = Vector2(1144, 380)
	box.add_child(canvas)
	var origin := Vector2(85, 214)
	var fields := Rect2(Layout.CONTACT_FIELDS.position - origin, Layout.CONTACT_FIELDS.size)
	var risk := Rect2(Layout.CONTACT_RISK.position - origin, Layout.CONTACT_RISK.size)
	var nav: VBoxContainer = host._surface_column(canvas, fields)
	var activity: bool = row.key == "route/context"
	var nav_title := "事项与参加者" if activity else ("让神意抵达" if str(row.key).begins_with("POWER_") else "选择这次行动的联系")
	host._line(nav, nav_title, 18, UI.BONE)
	if activity and task.draft.get("fixed_activity", false):
		var scope: String = str(task.draft.get("activity_cult", ""))
		if scope.is_empty(): scope = str(selection.get("domain", ""))
		if not scope.is_empty(): host._line(nav, task.title(scope), 13, UI.CYAN)
	if task.draft.get("fixed_anchor", false):
		host._line(nav, "锚定于 · " + task.title(str(selection.get("institution", ""))), 13, UI.CYAN).name = "AnchorFixedInstitution"
	var costs: VBoxContainer = host._surface_column(canvas, risk)
	action_cost(task, costs, row, selection, actions)
	host._line(costs, note, 12, UI.MUTED)
	var chosen: String = ""
	var subject := ""
	var subject_kind := ""
	var texture: Texture2D
	var fields_keys: Array = row.get("fields", []).map(func(field: Dictionary) -> String: return str(field.key))
	var person_contact := fields_keys.any(func(key: String) -> bool: return key in ["npc", "actor", "guardian"])
	for field: String in ["npc", "actor", "guardian", "institution", "anchor", "relic", "cult", "domain"]:
		var value: Variant = selection.get(field, "")
		if not value is String or value.is_empty() or (field == "domain" and person_contact and not activity): continue
		subject = value
		chosen = str(task.title(value))
		subject_kind = "person" if field in ["npc", "actor", "guardian"] else "world" if field == "domain" else field
		if subject_kind not in ["person", "cult", "world"]: texture = picture("contact")
		break
	var ring := Rect2(Vector2(592, 471) - origin, Vector2(416, 151))
	host._ui.image(canvas, "ContactRings", Layout.box(ring), picture("rings"), Color.WHITE, TextureRect.STRETCH_SCALE)
	var art_rect := Layout.box(Rect2(Vector2(641, 224) - origin, Vector2(320, 332)))
	if subject_kind in ["person", "cult", "world"]:
		host._object_art(canvas, "ContactTarget", art_rect, subject_kind, subject, true)
	elif texture != null:
		host._ui.image(canvas, "ContactTarget", art_rect, texture)
	else:
		host._reference(canvas, "EmptyContact", "先选择一处真实联系", Rect2(Vector2(620, 350) - origin, Vector2(360, 49)), 17, UI.CYAN).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._reference(canvas, "ContactSubject", chosen if not chosen.is_empty() else "尚未建立联系", Rect2(Vector2(550, 565) - origin, Vector2(500, 52)), 25, UI.BONE, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not subject.is_empty():
		host._stage_button(canvas, "ReadContact", "查阅当前联系 ↗", Rect2(Vector2(705, 619) - origin, Vector2(190, 34)), task.show_subject.bind(subject_kind, subject), 14)
	return {"canvas": canvas, "nav": nav, "costs": costs}

func candidate_layer(canvas: Control, active: bool, close_callback: Callable, compare := false) -> Control:
	var bounds := Rect2(85, 214, 1430, 477) if compare else Layout.PICKER
	bounds.position -= Vector2(85, 214)
	var panel: Control = host._scene_plate(canvas, "RitualPicker", bounds, Color("#0d1b28f7"))
	panel.visible = active
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	host._stage_button(panel, "ClosePicker", "×", Rect2(1355 if compare else 630, 12, 42, 37), close_callback, 22).accessibility_name = "收起候选"
	return panel

func action_cost(task, pane: VBoxContainer, row: Dictionary, selection: Dictionary, actions) -> void:
	host._line(pane, "你将付出的代价", 18, UI.BONE)
	var summary: Dictionary = row.get("preview", {}).get("preview", {})
	var definition: Dictionary = task.session.catalog.display_tables.powers.get(str(row.key), {})
	if not summary.is_empty() or not definition.is_empty():
		var whispers: int = int(summary.get("whispers", definition.get("whispers", 0)))
		var faith: int = int(summary.get("faith", summary.get("faith_cost", definition.get("faith", 0))))
		host._line(pane, "%s 低语 · %s 信仰%s" % [whispers, faith, " · 基础费用" if summary.is_empty() else ""], 16, UI.GOLD)
	var always: String = actions._always_cost(task, row, selection)
	if not always.is_empty(): _contact_note(pane, "必付 · " + always)
	if not definition.is_empty():
		var effects: Dictionary = actions._outcome_effects(task, row, selection)
		for outcome: String in ["failure", "disaster"]:
			var effect: String = str(effects.get(outcome, ""))
			if effect.is_empty() or effect == "不适用": continue
			_contact_note(pane, ("失败 · " if outcome == "failure" else "灾变 · ") + effect)
	var consequence: String = actions._irreversible_summary(task, row, selection)
	if not consequence.is_empty(): _contact_note(pane, consequence)

func _contact_note(parent: VBoxContainer, value: String) -> void:
	var line: Label = host._line(parent, value, 14, UI.RISK)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.tooltip_text = value
