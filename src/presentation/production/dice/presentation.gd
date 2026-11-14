extends CanvasLayer
## A transient resolution on the existing card table. The simulation has already
## committed once; this layer reveals its public receipt and never executes it.
signal finished
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Fields = preload("res://src/presentation/production/painted/card_fields.gd")
const DicePair = preload("res://src/presentation/production/dice/dice_pair.gd")
const Fan = preload("res://src/presentation/production/worldplay/hand_fan.gd")
var _ui := UI.new()
var _host: WeakRef
var _hidden: Dictionary = {}
var _focus: WeakRef
var _body: Control
var _hero: Control
var _reading: VBoxContainer
var _reading_scroll: ScrollContainer
var _dice_pair: Control
var _title: Label
var _context: Label
var _condition: RichTextLabel
var _outcome: Label
var _total: Label
var _comparison: Label
var _progress: Label
var _hint: Label
var _next: Button
var _previous: Button
var _batches: Array = []
var _entries: Array = []
var _seen := -1
var _index := -1
var _active := false
var _revealed := false
var _reveal_motion: Tween
var _master: Dictionary = {}
var _hand: Array = []
var _turn := 0

func _ready() -> void:
	layer = 30
	hide()
	set_process(false)

func is_active() -> bool:
	return _active

func enqueue(host: Control, batch: Dictionary) -> void:
	if batch.get("checks",[]).is_empty(): return
	if not _active:
		_host = weakref(host)
		_focus = weakref(get_viewport().gui_get_focus_owner()) if get_viewport().gui_get_focus_owner()!=null else null
		_turn = int(host.projection.get("turn",batch.get("turn",0)))
		_master = {}
		if host.has_method("_master_card") and not str(host.get("_world_id")).is_empty():
			_master = host._master_card().duplicate(true)
		_hand = host.get("_hand_cards").duplicate(true) if host.get("_hand_cards") is Array else []
		_active = true
		_build(host)
		show()
		set_process(true)
	var batch_index := _batches.size()
	_batches.append(batch.duplicate(true))
	for check_index: int in batch.checks.size():
		_entries.append({"batch":batch_index,"check":check_index})
	cover_current(host)
	if _index<0: _show_check(0)
	_update_controls()

func cover_current(host: Control) -> void:
	if not _active: return
	for key: String in ["_stage","_surface","_persistent_dock"]:
		var node: Variant = host.get(key)
		if not is_instance_valid(node) or not node is CanvasItem: continue
		var id: int = node.get_instance_id()
		if not _hidden.has(id): _hidden[id] = {"node":weakref(node),"visible":node.visible}
		# The existing layer may be rebuilt during public projection refresh.
		if node.visible: _hidden[id].visible = true
		node.hide()
	if is_instance_valid(host._portrait_transition): host._portrait_transition.hide()

func _process(_delta: float) -> void:
	var host: Variant = _host.get_ref() if _host!=null else null
	if is_instance_valid(host): cover_current(host)

func _build(host: Control) -> void:
	_body = Control.new()
	_body.name = "DiceResolution"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.theme = Paint.native_theme()
	add_child(_body)
	_label("StageTitle","第 %s 轮 · 骰已离手" % _turn,Rect2(32,13,650,32),18,Paint.MUTED)
	_progress = _label("RollProgress","",Rect2(944,14,296,30),16,Paint.MUTED)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not _master.is_empty():
		var main: Control = host._face(_body,_master,Rect2(32,90,240,360))
		main.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.modulate = Color(.84,.84,.84,1)
		if _master.get("kind")=="world":
			var metrics := ["barrier","pollution","alert","stability"]
			for index: int in metrics.size():
				var key: String = metrics[index]
				Fields.at(_body,"WorldMetric_"+key,[Fields.field(host._views.WORLD_METRICS[key],host._views.metric_display(_master.subject,key).value)],Rect2(42,476+index*28,232,27),16)
		else:
			_label("WorldContext","你的意志，已投向此间。",Rect2(42,482,226,70),16,Paint.MUTED)
	else:
		_label("WorldContext","界外 / 神意已降",Rect2(42,97,240,26),17,Paint.MUTED)
		_label("WorldScope","诸界静候",Rect2(42,139,240,48),30,Paint.BONE,true)
		_label("WorldWhisper","已付出的意志，\n终将留下回响。",Rect2(42,210,226,92),17,Paint.MUTED)
	_hero = Control.new()
	_hero.position = Vector2(316,95)
	_hero.size = Vector2(148,234)
	_body.add_child(_hero)
	_title = _label("ResolutionTitle","",Rect2(484,89,750,45),27,Paint.BONE,true)
	_context = _label("CheckContext","",Rect2(486,136,740,28),16,Paint.MUTED)
	_dice_pair = DicePair.new()
	_dice_pair.name = "EngravedDice"
	_dice_pair.position = Vector2(495,165)
	_dice_pair.size = Vector2(360,185)
	_body.add_child(_dice_pair)
	_dice_pair.settled.connect(_settled)
	_condition = Fields.at(_body,"DiceCondition",[Fields.field("成功条件","")],Rect2(879,172,344,29),18)
	_outcome = _label("DiceOutcome","",Rect2(879,209,344,38),28,Paint.WARM,true)
	_total = _label("DiceTotal","",Rect2(879,253,180,57),40,Paint.BONE,true)
	_comparison = _label("DiceComparison","",Rect2(879,312,344,25),15,Paint.MUTED)
	_reading_scroll = ScrollContainer.new()
	_reading_scroll.name = "Consequences"
	_reading_scroll.position = Vector2(484,355)
	_reading_scroll.size = Vector2(750,75)
	_reading_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_reading_scroll)
	_reading = VBoxContainer.new()
	_reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reading.add_theme_constant_override("separation",6)
	_reading_scroll.add_child(_reading)
	# The original complete hand is a quiet, frozen tabletop context. None of
	# these cards may be played while a committed result is being revealed.
	if not _hand.is_empty():
		var fan := Fan.new()
		fan.name = "RestingHand"
		fan.position = Vector2(304,437)
		fan.size = Vector2(936,214)
		fan.allow_play = false
		_body.add_child(fan)
		var faces: Array[Control] = []
		for card: Dictionary in _hand:
			faces.append(host._face(fan,card,Rect2(0,0,148,198)))
		fan.configure(faces)
		fan.set_blocked(true)
		fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fan.modulate = Color(.55,.57,.59,1)
		fan.set_process(false)
	_hint = _label("DiceHint","",Rect2(305,679,640,25),14,Paint.MUTED)
	_previous = _ui.button(_body,"PreviousDie","‹ 上次检定",Rect2(36,671,190,35),_review_previous)
	_next = _ui.button(_body,"ResolveDice","揭晓骰点",Rect2(1035,671,205,36),_advance,true)
	_next.grab_focus()

func _label(node_name: String, value: String, bounds: Rect2, px: int, color: Color, heading := false) -> Label:
	var label: Label = _ui.label(_body,node_name,value,bounds,px,color,heading)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _show_check(index: int) -> void:
	_index = clampi(index,0,_entries.size()-1)
	var entry: Dictionary = _entries[_index]
	var batch: Dictionary = _batches[entry.batch]
	var check: Dictionary = batch.checks[entry.check]
	_render_source(batch,"等待落定" if _index>_seen else check.label)
	_title.text = batch.title
	_title.tooltip_text = batch.title
	_context.text = str(check.title) if str(check.title)!=str(batch.title) else str(check.subject)
	_context.tooltip_text = str(check.detail)
	_condition.call("content",[Fields.field("成功条件","骰点 ≤ %d" % check.target)],18)
	_outcome.text = "命运未定"
	_outcome.add_theme_color_override("font_color",Paint.MUTED)
	_total.text = "…"
	_comparison.text = "两枚十面骰 · D100"
	for child: Node in _reading.get_children():
		_reading.remove_child(child)
		child.queue_free()
	_reading_scroll.scroll_vertical = 0
	if _reveal_motion!=null: _reveal_motion.kill()
	_reading.modulate.a = 0.0
	_revealed = false
	if _index<=_seen:
		_dice_pair.show_result(check.roll)
		_settled()
	else:
		# Decorative motion is derived from a public receipt index; it cannot
		# consume or alter any of the world's random streams.
		_dice_pair.roll_to(check.roll,(_turn*103+_index*37+11))
	_update_controls()

func _render_source(batch: Dictionary, detail: String) -> void:
	var host: Control = _host.get_ref()
	for child: Node in _hero.get_children():
		_hero.remove_child(child)
		child.queue_free()
	var card: Dictionary = batch.card.duplicate(true)
	if card.is_empty():
		card = {"id":"dice/source","title":batch.title,"type":"action","group":"action","kind":"action"}
	card.detail = detail
	card.erase("detail_fields")
	card.erase("targets")
	var face: Control = host._face(_hero,card,Rect2(0,0,148,234))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.focus_mode = Control.FOCUS_NONE
	face.tooltip_text = ""

func _settled() -> void:
	if not _active or _revealed: return
	_revealed = true
	_seen = maxi(_seen,_index)
	var entry: Dictionary = _entries[_index]
	var batch: Dictionary = _batches[entry.batch]
	var check: Dictionary = batch.checks[entry.check]
	_render_source(batch,check.label)
	_outcome.text = check.label
	_outcome.add_theme_color_override("font_color",Paint.RISK if check.outcome in ["failure","disaster"] else Paint.WARM)
	_total.text = "%02d 点" % check.roll
	_comparison.text = "%s  %s  %s" % [check.roll,"≤" if check.roll<=check.target else ">",check.target]
	if check.roll==100: _comparison.text += "   00 + 0 = 100"
	# A batch can contain several checks and combined effects. Do not pretend
	# the complete batch's consequences belong to just its first die.
	var batch_last_index: int = _index + batch.checks.size() - int(entry.check) - 1
	if _seen>=batch_last_index:
		for part: Variant in batch.lines:
			if part is Dictionary: Fields.row(_reading,str(part.caption),str(part.value),16)
			elif part is Array: Fields.line(_reading,part,16)
			else: Fields.line(_reading,[str(part)],16)
		if not str(batch.resources).is_empty(): Fields.line(_reading,[Fields.field("实际消耗与变化",batch.resources)],15)
	else:
		Fields.line(_reading,["本次点数已落定；本批检定全部揭晓后，一并展示实际后果。"],16)
	_reveal_motion = create_tween()
	_reveal_motion.tween_property(_reading,"modulate:a",1.0,.25)
	_update_controls()

func _update_controls() -> void:
	if _progress==null: return
	_progress.text = "检定  %02d / %02d" % [_index+1,_entries.size()]
	_previous.visible = _revealed and _index>0
	_next.text = "揭晓骰点" if not _revealed else ("下一次检定 →" if _index+1<_entries.size() else "让回响散去")
	_hint.text = "骰已离手 · 空格 / Esc 加速落定" if not _revealed else ("点数与后果均已结算 · 确认后继续" if _index+1<_entries.size() else "回响已留下 · 空格 / Esc 返回牌桌")

func _advance() -> void:
	if not _active: return
	if not _revealed:
		_dice_pair.reveal()
	elif _index+1<_entries.size(): _show_check(_index+1)
	else: _close()

func _review_previous() -> void:
	if _active and _revealed and _index>0: _show_check(_index-1)

func handle_input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE]: _advance()
			elif event.keycode==KEY_LEFT: _review_previous()
			elif event.keycode==KEY_RIGHT and _revealed: _advance()
		get_viewport().set_input_as_handled()

func _close() -> void:
	_restore()
	_clear()
	finished.emit()

func _restore() -> void:
	for item: Dictionary in _hidden.values():
		var node: Variant = item.node.get_ref()
		if is_instance_valid(node) and item.visible: node.show()
	var host: Variant = _host.get_ref() if _host!=null else null
	if is_instance_valid(host) and host._portraits.preparing: host._portrait_transition.show()
	var focus: Variant = _focus.get_ref() if _focus!=null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func _clear() -> void:
	_active = false
	set_process(false)
	hide()
	if _reveal_motion!=null: _reveal_motion.kill()
	if is_instance_valid(_body):
		remove_child(_body)
		_body.queue_free()
	_body = null
	_progress = null
	_hidden.clear()
	_batches.clear()
	_entries.clear()
	_master.clear()
	_hand.clear()
	_index = -1
	_seen = -1
	_revealed = false

func reset() -> void:
	if _active: _restore()
	_clear()
