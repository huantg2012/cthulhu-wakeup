extends RefCounted
## Editable content for the art fixture's two independent horizontal collections.
## Names and thresholds come from CSV; relic instances and states are fixture data.

const RELIC_IDS: Array[String] = ["RELIC_ROOT_NAIL", "RELIC_ECHO_BELL", "RELIC_HOLLOW_SEAL", "RELIC_WITNESS_LENS", "RELIC_LIVING_SCRIPT", "RELIC_LAST_EMBER"]
const RELIC_REGIONS: Array[Rect2] = [Rect2(1230,786,70,70), Rect2(1338,786,70,70), Rect2(1440,786,80,72), Rect2(1540,780,80,78)]

static func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	# A thin painted track with the full 13 px control kept as the drag target.
	style.expand_margin_top = -4.0
	style.expand_margin_bottom = -4.0
	return style

static func _scroll(app: Control, box: Control, name_value: String, rect: Rect2) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.name = name_value
	app._rect(scroll,rect)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	# Keep native scrolling and keyboard focus, without reserving a scrollbar row.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var native_bar := scroll.get_h_scroll_bar()
	var bar := HScrollBar.new()
	bar.name = name_value + "OverlayBar"
	app._rect(bar,Rect2(rect.position.x,rect.end.y-2,rect.size.x,13))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.focus_mode = Control.FOCUS_NONE
	bar.modulate.a = 0.0
	box.add_child(bar)
	bar.add_theme_stylebox_override("scroll",_bar_style(Color(0.20,0.18,0.13,0.35)))
	bar.add_theme_stylebox_override("scroll_focus",_bar_style(Color(0.20,0.18,0.13,0.35)))
	bar.add_theme_stylebox_override("grabber",_bar_style(Color(0.61,0.51,0.34,0.70)))
	bar.add_theme_stylebox_override("grabber_highlight",_bar_style(Color(0.83,0.70,0.47,0.90)))
	bar.add_theme_stylebox_override("grabber_pressed",_bar_style(Color(0.95,0.80,0.54,1.0)))
	var edge_left := _edge_fade(app,box,name_value+"FadeLeft",Rect2(rect.position,Vector2(26,rect.size.y)),true)
	var edge_right := _edge_fade(app,box,name_value+"FadeRight",Rect2(rect.end.x-26,rect.position.y,26,rect.size.y),false)
	var sync := func() -> void:
		bar.min_value = native_bar.min_value
		bar.max_value = native_bar.max_value
		bar.page = native_bar.page
		bar.set_value_no_signal(native_bar.value)
		var overflow: bool = native_bar.max_value-native_bar.page > native_bar.min_value+0.5
		edge_left.visible = overflow and native_bar.value > native_bar.min_value+0.5
		edge_right.visible = overflow and native_bar.value < native_bar.max_value-native_bar.page-0.5
	native_bar.changed.connect(sync)
	native_bar.value_changed.connect(func(_value: float): sync.call())
	bar.value_changed.connect(func(value: float): scroll.scroll_horizontal = roundi(value))
	var reveal := func() -> void: _fade_bar(bar,1.0)
	var conceal := func() -> void:
		if not bar.get_global_rect().has_point(bar.get_global_mouse_position()) and not scroll.get_global_rect().has_point(scroll.get_global_mouse_position()):
			_fade_bar(bar,0.0)
	scroll.mouse_entered.connect(reveal)
	scroll.mouse_exited.connect(conceal)
	bar.mouse_entered.connect(reveal)
	bar.mouse_exited.connect(conceal)
	var row := HBoxContainer.new()
	row.name = "Items"
	row.add_theme_constant_override("separation",4)
	scroll.add_child(row)
	sync.call_deferred()
	scroll.gui_input.connect(func(event: InputEvent): _wheel(scroll,event))
	return {"scroll":scroll,"row":row}

static func _edge_fade(app: Control, box: Control, title: String, rect: Rect2, left: bool) -> TextureRect:
	var dark := Color(0.006,0.016,0.018,0.80)
	var clear := Color(0.006,0.016,0.018,0.0)
	return app._gradient(box,title,rect,dark if left else clear,clear if left else dark,true)

static func _fade_bar(bar: HScrollBar, target: float) -> void:
	var previous: Variant = bar.get_meta("fade_tween") if bar.has_meta("fade_tween") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	var tween := bar.create_tween()
	tween.tween_property(bar,"modulate:a",target,0.16)
	bar.set_meta("fade_tween",tween)

static func _wheel(scroll: ScrollContainer, event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed: return
	var direction := 0
	if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_RIGHT]: direction=1
	elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT]: direction=-1
	if direction != 0:
		scroll.scroll_horizontal += direction*100
		scroll.accept_event()

static func _hover_icon(icon: TextureRect, active: bool, base_tint: Color) -> void:
	# Highlight the image itself. No ellipse or other hover background.
	icon.pivot_offset = icon.size/2.0
	icon.scale = Vector2(1.09,1.09) if active else Vector2.ONE
	if icon.material is ShaderMaterial:
		var material: ShaderMaterial = icon.material
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if str(uniform.name) == "icon_tint":
				material.set_shader_parameter("icon_tint",base_tint * (1.35 if active else 1.0))
				return
			if str(uniform.name) == "highlight":
				material.set_shader_parameter("highlight",1.4 if active else 1.0)
				return
	icon.self_modulate = base_tint * (1.35 if active else 1.0)

static func _bind_icon(app: Control, button: Button, icon: TextureRect, scroll: ScrollContainer, tint: Color = Color.WHITE) -> void:
	for state: String in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var bar: HScrollBar = scroll.get_parent().get_node(scroll.name + "OverlayBar")
	button.mouse_entered.connect(func(): _fade_bar(bar,1.0))
	button.mouse_exited.connect(func():
		var pointer := scroll.get_global_mouse_position()
		if not scroll.get_global_rect().has_point(pointer) and not bar.get_global_rect().has_point(pointer):
			_fade_bar(bar,0.0))
	button.mouse_entered.connect(func(): _hover_icon(icon,true,tint))
	button.mouse_exited.connect(func(): _hover_icon(icon,button.has_focus() and app.keyboard_input,tint))
	button.focus_entered.connect(func(): _hover_icon(icon,button.is_hovered() or app.keyboard_input,tint))
	button.focus_exited.connect(func(): _hover_icon(icon,button.is_hovered(),tint))
	button.gui_input.connect(func(event: InputEvent): _wheel(scroll,event))

static func _relic_icon(app: Control, parent: Control, i: int) -> TextureRect:
	if i >= RELIC_REGIONS.size():
		return app._image(parent,"Icon",Rect2(25,0,40,38),app._texture("res://tools/echoes-art-master/icons/ritual.svg"),Color(0.68,0.61,0.47,0.8))
	var region: Rect2 = RELIC_REGIONS[i]
	var icon: TextureRect = app._image(parent,"Icon",Rect2(22,0,46,38),app._source_region(region))
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 tile_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool dark_body=false;
uniform bool seal_mask=false;
uniform float highlight=1.0;
void fragment(){
 vec4 c=texture(TEXTURE,UV); vec2 p=(UV-tile_rect.xy)/tile_rect.zw;
 float edge=smoothstep(0.0,0.13,p.x)*(1.0-smoothstep(0.87,1.0,p.x))*smoothstep(0.0,0.13,p.y)*(1.0-smoothstep(0.87,1.0,p.y));
 float light=smoothstep(0.055,0.20,max(c.r,max(c.g,c.b)));
 float body=dark_body ? 0.7*(1.0-smoothstep(0.29,0.43,length((p-vec2(0.5))*vec2(1.1,0.85)))) : 0.0;
 float alpha=edge*max(light,body);
 if(seal_mask){
  float upper=max(0.0,0.13-p.y); float lower=max(0.0,p.y-0.77);
  float left=0.145+upper*2.2+lower*1.9; float right=0.91-upper*2.6-lower*2.2;
  float silhouette=smoothstep(left,left+0.025,p.x)*(1.0-smoothstep(right-0.025,right,p.x));
  alpha=edge*silhouette*max(light,0.92);
 }
 COLOR=vec4(c.rgb*highlight,c.a*alpha);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tile_rect",Vector4(region.position.x/1672.0,region.position.y/941.0,region.size.x/1672.0,region.size.y/941.0))
	material.set_shader_parameter("dark_body",i in [2,3])
	material.set_shader_parameter("seal_mask",i==2)
	icon.material = material
	return icon

static func build(app: Control, box: Control, bounds: Rect2) -> void:
	var awakened := int(app.fixture_state.awakening)
	var unlocked := 0
	for key: String in app.POWER_ICONS:
		if int(app.catalog.tables.powers["POWER_"+key.to_upper()].unlock_awakening) <= awakened: unlocked += 1
	app._label(box,"PowerHeading","权能",Rect2(bounds.position.x+20,48,65,30),22,app.GOLD,true)
	app._label(box,"PowerCount","%d/%d"%[unlocked,app.POWER_ICONS.size()],Rect2(bounds.position.x+73,53,60,25),16,app.MUTED)
	var powers := _scroll(app,box,"PowerScroll",Rect2(bounds.position.x+138,20,614,100))
	var power_row: HBoxContainer = powers.row
	var power_scroll: ScrollContainer = powers.scroll
	for key: String in app.POWER_ICONS:
		var id := "POWER_"+key.to_upper()
		var data: Dictionary = app.catalog.tables.powers[id]
		var locked := int(data.unlock_awakening) > awakened
		var button: Button = app._button(power_row,"Power_"+id,"",Rect2(0,0,99,99),func(): app.open_power(id),false,true)
		button.custom_minimum_size = Vector2(99,99)
		var base := Color(0.55,0.58,0.60,0.95) if locked else Color.WHITE
		# Powers have no instance-state line: give the emblem more presence and
		# centre the shorter two-line composition against the relic entry.
		var icon: TextureRect = app._icon(button,"Icon",key,Rect2(25,1,48,48),base)
		app._label(button,"PowerName",str(data.name),Rect2(0,49,99,27),18,app.MUTED if locked else app.BONE,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if locked:
			app._label(button,"LockReason","需苏醒%s"%data.unlock_awakening,Rect2(0,76,99,23),16,app.RISK).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		_bind_icon(app,button,icon,power_scroll,base)
	var relic_total := maxi(0,int(app.fixture_state.relics))
	app._label(box,"RelicHeading","圣物",Rect2(bounds.position.x+788,48,70,30),22,app.GOLD,true)
	app._label(box,"RelicCount","",Rect2(bounds.position.x+848,53,30,22),14,app.MUTED)
	if relic_total == 0:
		app._label(box,"RelicEmpty","尚无圣物",Rect2(bounds.position.x+875,38,240,55),20,app.MUTED)
		return
	var relics := _scroll(app,box,"RelicScroll",Rect2(bounds.position.x+875,20,531,100))
	var relic_row: HBoxContainer = relics.row
	var relic_scroll: ScrollContainer = relics.scroll
	for i: int in range(relic_total):
		var id: String = RELIC_IDS[i%RELIC_IDS.size()]
		var button: Button = app._button(relic_row,"Relic_%d"%i,"",Rect2(0,0,103,90),app.open_relics,false,true)
		button.custom_minimum_size = Vector2(103,90)
		var icon := _relic_icon(app,button,i%RELIC_IDS.size())
		icon.position.x += 5.5
		app._label(button,"RelicName",str(app.catalog.tables.relics[id].name),Rect2(0,38,103,26),17,app.BONE,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var state: String = ["绑定","携带","携带","保管"][i] if i<4 else ("绑定" if i%4==0 else ("保管" if i%3==0 else "携带"))
		app._label(button,"RelicState","R%02d · %s"%[i+1,state],Rect2(0,64,103,25),16,Color("b4ce76") if state=="绑定" else app.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if i%RELIC_IDS.size() >= RELIC_REGIONS.size(): icon.modulate.a=0.55
		_bind_icon(app,button,icon,relic_scroll)
