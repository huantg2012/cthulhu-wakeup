extends RefCounted
## Shared content controls consume display fields and emit view intentions.
const UI = preload("res://tools/echoes-art-master/ui_components.gd")

static func world_entry(ui: RefCounted, parent: Node, title: String, data: Dictionary, picture: Texture2D, callback: Callable) -> Button:
	var row: Button = ui.button(parent,title,"",Rect2(0,0,270,96),callback,false,true)
	row.custom_minimum_size = Vector2(0,96)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("search_text",str(data.name))
	ui.image(row,"Portrait",Rect2(0,0,91,96),picture,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	ui.gradient(row,"PortraitFade",Rect2(70,0,32,96),Color(0.02,0.033,0.032,0),Color(0.02,0.033,0.032,0.83),true)
	ui.label(row,"Name",str(data.name),Rect2(105,8,156,31),22,UI.GOLD_HI,true)
	ui.label(row,"Hint",str(data.hint),Rect2(105,44,162,28),17,UI.RISK if data.get("risk",false) else UI.BONE)
	ui.label(row,"Tag",str(data.get("tag","")),Rect2(105,70,142,23),14,UI.MUTED)
	select_entry(ui,row,bool(data.get("selected",false)))
	return row

static func select_entry(ui: RefCounted, row: Button, selected: bool) -> void:
	for state: String in ["normal","hover","pressed"]:
		row.add_theme_stylebox_override(state,ui.world_row_style(state,selected))
	row.add_theme_stylebox_override("focus",ui.unframed_style("focus"))
	if row.has_node("Name"):
		row.get_node("Name").add_theme_color_override("font_color",UI.GOLD_HI if selected else UI.BONE)

static func prayer_card(ui: RefCounted, parent: Node, title: String, bounds: Rect2, data: Dictionary, picture: Texture2D, material: ShaderMaterial, callback: Callable) -> Button:
	var card: Button = ui.button(parent,title,"",bounds,callback,false,true)
	select_entry(ui,card,bool(data.get("selected",false)))
	var art: TextureRect = ui.image(card,"SceneImage",Rect2(0,0,105,112),picture,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.material = material
	ui.label(card,"Person",str(data.person),Rect2(116,4,223,27),19,UI.BONE,true)
	ui.label(card,"Kind",str(data.kind),Rect2(116,33,224,25),17,UI.CYAN)
	ui.label(card,"Title",str(data.title),Rect2(116,59,224,26),19,UI.GOLD_HI,true)
	ui.label(card,"Due",str(data.due),Rect2(116,85,224,23),16,UI.RISK if data.get("urgent",false) else UI.MUTED)
	return card

static func metric(ui: RefCounted, parent: Node, suffix: String, at: Vector2, icon: String, label: String, value: String, source: String, known: bool) -> void:
	ui.icon(parent,"MetricIcon_"+suffix,icon,Rect2(at+Vector2(0,9),Vector2(37,39)))
	ui.label(parent,"MetricName_"+suffix,label,Rect2(at+Vector2(43,0),Vector2(48,32)),21,UI.GOLD,true)
	ui.label(parent,"MetricValue_"+suffix,value,Rect2(at+Vector2(93,0),Vector2(90,32)),22,UI.GOLD if known else UI.MUTED,true)
	ui.label(parent,"MetricSource_"+suffix,source,Rect2(at+Vector2(43,32),Vector2(135,26)),19,UI.MUTED,true)

static func threat(ui: RefCounted, parent: Node, title: String, at: Vector2, text: String, known: bool) -> Control:
	var warning := Control.new()
	warning.name = title
	ui.rect(warning,Rect2(at,Vector2(728,38)))
	parent.add_child(warning)
	ui.soft_support(warning,"RiskSupport",Rect2(-12,-5,752,48),Color(0.12,0.022,0.018,0.86))
	ui.icon(warning,"WarningIcon","countermeasure",Rect2(17,7,27,24))
	ui.label(warning,"Resistance",text,Rect2(50,0,670,38),18,UI.RISK if known else UI.MUTED,true)
	return warning
