extends RefCounted
## The power circle is a browse and preparation entrance, not a second action catalog.
const UI = preload("res://src/presentation/production/locked_controls.gd")

const Layout = preload("res://src/presentation/production/perception_layout.gd")

var _owner: WeakRef
var _selected := "POWER_DREAM"
var host: Control:
	get: return _owner.get_ref()

func _init(root: Control) -> void:
	_owner = weakref(root)

func open(id := "", focus_name := "") -> void:
	if host._busy or not host.projection.get("active", false): return
	if host.projection.get("phase") == "events": return
	if not id.is_empty(): _selected = id
	var definitions: Dictionary = host.session.catalog.display_tables.powers
	if not definitions.has(_selected): return
	var frame: Control = host._scene_frame("powers", "PowerField", Color("#0a1421"))
	host._ritual_placeholder(frame)
	var surface: Control = host._surface
	host._reference(surface, "PowerHeader", "十二权能 / 神意所及", Layout.SCENE_HEADER, 14, UI.MUTED)
	host._stage_button(surface, "PowerRules", "查看权能规则 ↗", Rect2(1280, 167, 173, 38), _rules)
	var back: Button = host._stage_button(surface, "ClosePowers", "×", Rect2(1484, 167, 38, 38), host._close_surface, 22)
	back.accessibility_name = "收起十二权能"
	var active: Button = back
	for index: int in UI.POWER_ORDER.size():
		var icon: String = UI.POWER_ORDER[index]
		var key := "POWER_" + icon.to_upper()
		if not definitions.has(key): continue
		var definition: Dictionary = definitions[key]
		var theta := -PI / 2.0 + TAU * index / UI.POWER_ORDER.size()
		var origin := Vector2(753 + cos(theta) * 537, 388 + sin(theta) * 208)
		var control: Button = host._stage_button(surface, "Sigil_" + key, "", Rect2(origin, Vector2(94, 92)), open.bind(key))
		control.accessibility_name = str(definition.name)
		var locked: bool = int(definition.unlock_awakening) > int(host.projection.awakening)
		host._ui.select_entry(control, key == _selected)
		var tint := UI.BONE if key == _selected else UI.MUTED if locked else UI.BONE
		control.accessibility_description = ("需苏醒 %s" % definition.unlock_awakening) if locked else "已解锁"
		host._ui.icon(control, "Sigil", icon, Layout.box(Rect2(23.5, 9, 47, 47)), tint)
		host._reference(control, "PowerName", str(definition.name), Rect2(0, 59, 94, 28), 17, tint).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		control.tooltip_text = "需苏醒 %s" % definition.unlock_awakening if locked else str(definition.name)
		if key == _selected: active = control
	var selected: Dictionary = definitions[_selected]
	host._reference(surface, "PowerPremise", "梦与醒之间" if _selected == "POWER_DREAM" else "由现实联系抵达", Rect2(530, 305, 540, 22), 13, UI.CYAN, false, 5).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._reference(surface, "SelectedPower", str(selected.name), Rect2(530, 340, 540, 69), 49, UI.BONE, true, 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._text(surface, str(selected.target_requirement), Layout.box(Rect2(580, 421, 440, 62)), 13, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var locked: bool = int(selected.unlock_awakening) > int(host.projection.awakening)
	var price := "需苏醒 %s · 当前 %s" % [selected.unlock_awakening, host.projection.awakening] if locked else "%s 低语 · %s 信仰" % [selected.whispers, selected.faith]
	var enter: Button = host._stage_button(surface, "PreparePower", ("查看要求" if locked else "进入") + " " + str(selected.name) + " →", Rect2(689, 490, 222, 49), _prepare.bind(_selected), 19)
	host._ui.scene_submit(enter)
	host._reference(surface, "PowerPrice", price, Rect2(595, 548, 410, 29), 13, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._ui.fill(surface, "PowerFooterRule", Layout.box(Rect2(85, 724, 1430, 1)), UI.LINE)
	host._reference(surface, "PowerFooter", "选择符印查看权能。查看与准备不消耗资源。", Rect2(85, 737, 1430, 26), 13, UI.MUTED)
	active.grab_focus()
	if not focus_name.is_empty(): host._focus_surface_control(focus_name)

func _rules() -> void:
	var definition: Dictionary = host.session.catalog.display_tables.powers[_selected]
	host._begin_peek("power_rules")
	var body: VBoxContainer = host._peek_content("十二权能 / 完整规则", str(definition.name))
	for field: String in ["target_requirement", "always_cost", "success", "failure", "disaster", "notes"]:
		if not str(definition.get(field, "")).is_empty(): host._line(body, str(definition[field]), 14)
	host._stage_button(host._surface, "ClosePowerRules", "返回权能全览 ←", Rect2(1130, 661, 393, 38), close_rules).grab_focus()

func close_rules() -> void:
	open(_selected, "PowerRules")

func _prepare(id: String) -> void:
	var return_to := open.bind(id, "PreparePower")
	if id == "POWER_MANIFEST":
		host._tasks.open_subject("self", "", return_to)
	elif id == "POWER_ANCHOR":
		host._tasks.open_action(id, {}, return_to)
	else:
		var definition: Dictionary = host.session.catalog.display_tables.powers[id]
		var locked: bool = int(definition.unlock_awakening) > int(host.projection.awakening)
		host._tasks.open_action(id, {}, return_to, locked)
