extends RefCounted
## Shared content controls consume display fields and emit view intentions.
const UI = preload("res://src/presentation/ui/ui_components.gd")

static func world_entry(ui: RefCounted, parent: Node, title: String, data: Dictionary, picture: Texture2D, callback: Callable, unit: float = 1.0, text_delta: int = 0) -> Button:
	var multiline: bool = data.get("multiline_name", false)
	var extra := (88 if text_delta > 0 else 28) if multiline else 0
	var row: Button = ui.button(parent,title,"",_rect(0,0,270,96 + extra,unit),callback,false,true)
	row.custom_minimum_size = Vector2(0,(96 + extra) * unit)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("search_text",str(data.name))
	ui.image(row,"Portrait",_rect(0,0,91,96 + extra,unit),picture,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	ui.gradient(row,"PortraitFade",_rect(70,0,32,96 + extra,unit),Color(0.02,0.033,0.032,0),Color(0.02,0.033,0.032,0.83),true)
	ui.label(row,"Name",str(data.name),_rect(105,8,156,31 + extra,unit),roundi(22 * unit) + text_delta,UI.GOLD_HI,true,multiline)
	ui.label(row,"Hint",str(data.hint),_rect(105,44 + extra,162,28,unit),roundi(17 * unit) + text_delta,UI.RISK if data.get("risk",false) else UI.BONE)
	ui.label(row,"Tag",str(data.get("tag","")),_rect(105,70 + extra,142,23,unit),roundi(14 * unit) + text_delta,UI.MUTED)
	select_entry(ui,row,bool(data.get("selected",false)))
	_fit_labels(row)
	if multiline:
		row.get_node("Name").text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return row

static func select_entry(ui: RefCounted, row: Button, selected: bool) -> void:
	for state: String in ["normal","hover","pressed"]:
		row.add_theme_stylebox_override(state,ui.world_row_style(state,selected))
	row.add_theme_stylebox_override("focus",ui.unframed_style("focus"))
	if row.has_node("Name"):
		row.get_node("Name").add_theme_color_override("font_color",UI.GOLD_HI if selected else UI.BONE)

static func prayer_card(ui: RefCounted, parent: Node, title: String, bounds: Rect2, data: Dictionary, picture: Texture2D, material: ShaderMaterial, callback: Callable, unit: float = 1.0, text_delta: int = 0) -> Button:
	var card: Button = ui.button(parent,title,"",bounds,callback,false,true)
	select_entry(ui,card,bool(data.get("selected",false)))
	var art: TextureRect = ui.image(card,"SceneImage",_rect(0,0,105,112,unit),picture,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.material = material
	ui.label(card,"Person",str(data.person),_rect(116,4,223,27,unit),roundi(19 * unit) + text_delta,UI.BONE,true)
	ui.label(card,"Kind",str(data.kind),_rect(116,33,224,25,unit),roundi(17 * unit) + text_delta,UI.CYAN)
	ui.label(card,"Title",str(data.title),_rect(116,59,224,26,unit),roundi(19 * unit) + text_delta,UI.GOLD_HI,true)
	ui.label(card,"Due",str(data.due),_rect(116,85,224,23,unit),roundi(16 * unit) + text_delta,UI.RISK if data.get("urgent",false) else UI.MUTED)
	_fit_labels(card)
	return card

static func metric(ui: RefCounted, parent: Node, suffix: String, at: Vector2, icon: String, label: String, value: String, source: String, known: bool, unit: float = 1.0, text_delta: int = 0) -> void:
	ui.icon(parent,"MetricIcon_"+suffix,icon,Rect2(at+Vector2(0,9) * unit,Vector2(37,39) * unit))
	ui.label(parent,"MetricName_"+suffix,label,Rect2(at+Vector2(43,0) * unit,Vector2(48,32) * unit),roundi(21 * unit) + text_delta,UI.GOLD,true)
	ui.label(parent,"MetricValue_"+suffix,value,Rect2(at+Vector2(93,0) * unit,Vector2(90,32) * unit),roundi(22 * unit) + text_delta,UI.GOLD if known else UI.MUTED,true)
	ui.label(parent,"MetricSource_"+suffix,source,Rect2(at+Vector2(43,32) * unit,Vector2(135,26) * unit),roundi(19 * unit) + text_delta,UI.MUTED,true)

static func threat(ui: RefCounted, parent: Node, title: String, at: Vector2, text: String, known: bool) -> Control:
	var warning := Control.new()
	warning.name = title
	ui.rect(warning,Rect2(at,Vector2(728,38)))
	parent.add_child(warning)
	ui.soft_support(warning,"RiskSupport",Rect2(-12,-5,752,48),Color(0.12,0.022,0.018,0.86))
	ui.icon(warning,"WarningIcon","countermeasure",Rect2(17,7,27,24))
	ui.label(warning,"Resistance",text,Rect2(50,0,670,38),18,UI.RISK if known else UI.MUTED,true)
	return warning

static func _rect(x: float, y: float, w: float, h: float, unit: float) -> Rect2:
	return Rect2(Vector2(x,y) * unit, Vector2(w,h) * unit)

static func _fit_labels(parent: Control) -> void:
	for child: Node in parent.get_children():
		if child is Label:
			child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			child.tooltip_text = child.text
			child.mouse_filter = Control.MOUSE_FILTER_PASS
