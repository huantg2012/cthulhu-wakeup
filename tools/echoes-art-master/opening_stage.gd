extends RefCounted
## Isolated art-fixture opening. The caller supplies all content and actions.
## No Session changes, outcomes, or gameplay data are defined here.

const VIEW := Vector2(1672, 941)
const UI = preload("res://tools/echoes-art-master/ui_components.gd")

static func _backdrop(ui: RefCounted, parent: Control, name_value: String) -> Control:
	var root := Control.new()
	root.name = name_value
	root.size = VIEW
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.size = VIEW
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Layered moving-looking fog, rendered transparently over the actual scene.
	# The backdrop has no copied screenshot and is distinct from a solid tint.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float motion_time = 0.0;
uniform float drift = 0.0015;
uniform float drift_near = -0.003;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void fragment() {
 vec2 p=(UV+vec2(motion_time*drift,0.0))*vec2(8.0,5.0); float n=noise(p)*0.55+noise((UV+vec2(motion_time*drift_near,0.0))*vec2(8.0,5.0)*2.1+3.7)*0.30+noise(p*4.0+12.0)*0.15;
 float band=pow(max(0.0,1.0-abs(UV.y-(0.50+0.10*sin(UV.x*7.0)))*2.5),2.0);
 vec3 dark=mix(vec3(0.005,0.022,0.026),vec3(0.020,0.068,0.071),n*0.72+band*0.22);
 COLOR=vec4(dark,clamp(0.76+n*0.10-band*0.06,0.68,0.89));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	veil.material = material
	if parent.get("motion") != null:
		material.set_shader_parameter("drift",parent.motion.params.fog_far_uv_s*parent.motion.params.opening_fog_factor)
		material.set_shader_parameter("drift_near",parent.motion.params.fog_near_uv_s*parent.motion.params.opening_fog_factor)
		parent.motion.register_material(veil,material)
	root.add_child(veil)
	return root

static func _center(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func _heading(ui: RefCounted, root: Control, eyebrow: String, title: String, sub: String) -> void:
	ui.soft_support(root,"HeadingSupport",Rect2(300,42,1072,177),Color(0.002,0.010,0.012,0.94))
	var line: Label = ui.label(root,"Eyebrow",eyebrow,Rect2(260,68,1152,30),19,UI.MUTED)
	_center(line)
	line = ui.label(root,"Heading",title,Rect2(240,103,1192,56),36,UI.GOLD_HI,true)
	_center(line)
	line = ui.label(root,"Subtitle",sub,Rect2(240,163,1192,35),19,UI.BONE)
	_center(line)

static func show_event(ui: RefCounted, parent: Control, data: Dictionary, on_choice: Callable) -> Control:
	var root := _backdrop(ui,parent,"OpeningEvent")
	_heading(ui,root,"新回合 · 事件",str(data.get("heading","命运已有回响")),"请处理当前事件，再继续本回合")
	# Broad soft reading surface; no rectangular outline or fine dividers.
	ui.soft_support(root,"EventSupport",Rect2(280,204,1112,572),Color(0.003,0.012,0.014,0.93))
	var art: Texture2D = data.get("image",null)
	if art != null:
		ui.image(root,"EventArt",Rect2(332,256,415,358),art,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		ui.gradient(root,"ArtFade",Rect2(332,508,415,106),Color(0.006,0.018,0.021,0.0),Color(0.006,0.018,0.021,0.95))
	ui.label(root,"EventTag",str(data.get("tag","轮初事件")),Rect2(786,253,500,30),18,UI.CYAN)
	ui.label(root,"EventTitle",str(data.get("title","事件")),Rect2(786,294,500,50),30,UI.GOLD_HI,true)
	ui.label(root,"EventBody",str(data.get("body","")),Rect2(786,353,500,104),20,UI.BONE,false,true)
	ui.label(root,"ChoicesTitle","选择如何应对",Rect2(786,474,500,32),19,UI.GOLD)
	var choices: Array = data.get("choices",[])
	for i: int in range(mini(choices.size(),3)):
		var choice: Dictionary = choices[i]
		var id: Variant = choice.get("id",i)
		var y := 516.0+i*90.0
		var button: Button = ui.button(root,"Choice_%d"%i,"",Rect2(786,y,502,82),func(): on_choice.call(id),false,true)
		ui.label(button,"ChoiceLabel",str(choice.get("label","")),Rect2(16,2,468,27),20,UI.GOLD_HI)
		if not str(choice.get("detail","")).is_empty():
			ui.label(button,"ChoiceDetail",str(choice.detail),Rect2(16,30,468,48),16,UI.MUTED,false,true)
	var foot: Label = ui.label(root,"FixtureNote","画面为展示夹具 · 选择仅演示事件处理流程",Rect2(300,806,1072,29),16,UI.MUTED)
	_center(foot)
	return root

static func show_prayers(ui: RefCounted, parent: Control, cards: Array, on_open: Callable) -> Control:
	var root := _backdrop(ui,parent,"OpeningPrayers")
	_heading(ui,root,"新回合 · 神意所闻","本回合收到 %d 个祈求"%cards.size(),"选择一个祈求，前往查看详情")
	var count := mini(cards.size(),3)
	var card_width := 350.0
	var gap := 30.0
	var start_x := (VIEW.x-(count*card_width+maxi(0,count-1)*gap))/2.0
	for i: int in range(count):
		var data: Dictionary = cards[i]
		var index: Variant = data.get("index",i)
		var button: Button = ui.button(root,"Prayer_%d"%i,"",Rect2(start_x+i*(card_width+gap),235,card_width,468),func(): on_open.call(index),false,true)
		if parent.get("motion") != null and parent.motion.enabled:
			button.modulate.a = 0.0
			button.position.y += parent.motion.params.card_offset_px
			parent.motion.animate(button,"modulate:a",1.0,parent.motion.params.card_entrance_s,i*parent.motion.params.card_stagger_s)
			parent.motion.animate(button,"position:y",235.0,parent.motion.params.card_entrance_s,i*parent.motion.params.card_stagger_s)
		for state: String in ["normal","hover","pressed"]:
			var support := StyleBoxFlat.new()
			support.bg_color = Color(0.006,0.019,0.021,0.93) if state == "normal" else Color(0.048,0.053,0.042,0.96)
			if state == "pressed": support.bg_color = Color(0.10,0.09,0.065,0.97)
			support.set_corner_radius_all(3)
			button.add_theme_stylebox_override(state,support)
		var picture: Texture2D = data.get("image",null)
		if picture != null:
			var art: TextureRect = ui.image(button,"Art",Rect2(0,0,card_width,260),picture,Color.WHITE,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
			# State feedback is on the image itself, without a new border.
			var motion: Node = parent.get("motion")
			if motion != null:
				var refresh := func():
					var hot: bool = button.is_hovered() or (button.has_focus() and parent.keyboard_input)
					var level: float = motion.params.pressed_brightness if button.button_pressed else (motion.params.hover_brightness if hot else 1.0)
					motion.animate(art,"modulate",Color(level,level,level,1.0),0.0 if button.button_pressed else (motion.params.hover_in_s if hot else motion.params.hover_out_s))
				button.mouse_entered.connect(refresh)
				button.mouse_exited.connect(refresh)
				button.focus_entered.connect(refresh)
				button.focus_exited.connect(refresh)
				button.button_down.connect(refresh)
				button.button_up.connect(refresh)
			ui.gradient(button,"ArtFade",Rect2(0,180,card_width,83),Color(0.005,0.016,0.019,0),Color(0.005,0.016,0.019,0.94))
		ui.label(button,"Kind",str(data.get("kind","祈求")),Rect2(24,265,302,28),18,UI.CYAN)
		ui.label(button,"Person",str(data.get("person","")),Rect2(24,303,302,33),22,UI.BONE,true)
		ui.label(button,"Title",str(data.get("title","")),Rect2(24,345,302,65),24,UI.GOLD_HI,true,true)
		ui.label(button,"Due",str(data.get("due","")),Rect2(24,420,302,26),17,UI.RISK if data.get("urgent",false) else UI.MUTED)
	var foot: Label = ui.label(root,"FixtureNote","展示夹具 · 选择后可在主场景查看，尚未作出回应",Rect2(260,749,1152,30),16,UI.MUTED)
	_center(foot)
	return root
