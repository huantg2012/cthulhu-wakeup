extends Control
## 旧日星图 · Eldritch Starchart — planet / system / wonder concept-art generator.
##
## Render pipeline (all SubViewports, so exported PNGs contain the full styled image):
##   vp3d (3D scene, internal res) -> bloom_a (1/4 threshold) -> bloom_b (blur)
##   -> vp_final: post.gdshader composite + overlay (titles / labels / frames) -> preview TextureRect

const SHADER_PATHS := {
	"sky": "res://shaders/sky.gdshader",
	"atmo": "res://shaders/atmo.gdshader",
	"ring_dust": "res://shaders/ring_dust.gdshader",
	"ring_fx": "res://shaders/ring_fx.gdshader",
	"star": "res://shaders/star.gdshader",
	"corona": "res://shaders/corona.gdshader",
	"tentacle": "res://shaders/tentacle.gdshader",
	"prop": "res://shaders/prop.gdshader",
	"rift": "res://shaders/rift.gdshader",
	"portal": "res://shaders/portal.gdshader",
	# 母星改造层级：新内容层，不走 ARCH / scene / composition 那套生成设计
	"world_tf": "res://shaders/world_terraform.gdshader",
	"world_core": "res://shaders/world_core.gdshader",
	"world_structure": "res://shaders/world_structure.gdshader",
}

var params := {
	"scene": 0, "style": 0, "seed": 1337, "archetype": -1, "palette": -1, "composition": 0,
	"star_type": -1, "wonder": -1, "count": -1, "rings": 0,
	"tentacles": 0.25, "eyes": 0.2, "glyphs": 0.35, "corruption": 0.2, "madness": 0.15, "nebula": 0.6,
	"aspect": 0, "quality": 1, "animate": true, "show_title": true, "show_labels": true, "show_frame": true, "show_swatch": false,
	"terraform": -1,  # -1 = 原作生成器；0/1/2 = 母星改造三档
	"tf_arch": 0,     # 母星原型 0 潮界 / 1 层台 / 2 陨野 / 3 菌原
}

var gen := EGen.new()
var info := {}
var font_ui: Font
var font_title: Font

# render graph
var vp3d: SubViewport
var world_root: Node3D
var cam: Camera3D
var bloom_a: SubViewport
var bloom_a_rect: ColorRect
var bloom_b: SubViewport
var bloom_b_rect: TextureRect
var vp_final: SubViewport
var post_rect: TextureRect
var overlay: Control
var post_mat: ShaderMaterial
var bloom_down_mat: ShaderMaterial

# UI
var preview: TextureRect
var preview_frame: Control
var ctrl := {}
var info_label: RichTextLabel
var right_panel: Control
var info_toggle: Button
var status_label: Label
var gallery_box: HFlowContainer
var gallery := []
var history := []
var hist_i := -1
var time_acc := 0.0
var rebuild_pending := false
var rebuild_timer := 0.0
var suppress := false
var batch_left := 0
var size_out := Vector2i(1280, 720)
var _cap_frames := -1
var _cap_cb: Callable


func _ready() -> void:
	font_ui = load("res://fonts/ui.ttf")
	font_title = load("res://fonts/title.ttf")
	var shaders := {}
	for k in SHADER_PATHS:
		shaders[k] = load(SHADER_PATHS[k])
	# one compiled variant per archetype (keeps each WebGL program small)
	for i in EData.ARCHETYPES.size():
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;\n#define ARCH %d\n#include \"res://shaders/planet_body.gdshaderinc\"\n" % i
		shaders["planet_%d" % i] = sh
	var meshes := {}
	var scene: PackedScene = load("res://assets/eldritch_assets.glb")
	var inst := scene.instantiate()
	_collect_meshes(inst, meshes)
	inst.free()
	gen.setup(meshes, shaders)
	_build_render_graph()
	_build_ui()
	_apply_seed_from_url()
	_sync_controls()
	rebuild(true)
	_apply_responsive.call_deferred()
	_maybe_shots()


func _maybe_shots() -> void:
	var out := ""
	var cfgs := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out = a.substr(8)
		elif a.begins_with("--cfg="):
			var d := {}
			for kv in a.substr(6).split(","):
				var p := kv.split(":")
				if p.size() == 2:
					d[p[0]] = float(p[1]) if p[1].contains(".") else int(p[1])
			cfgs.append(d)
	if out == "":
		return
	time_acc = 3.0
	await get_tree().process_frame
	await load("res://scripts/shots.gd").run(self, out, cfgs)


func _collect_meshes(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D:
		out[String(n.name)] = n.mesh
	for c in n.get_children():
		_collect_meshes(c, out)


func _apply_seed_from_url() -> void:
	if OS.has_feature("web"):
		var s = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('seed') || ''", true)
		if s is String and s.is_valid_int():
			params["seed"] = int(s)
		var st = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('style') || ''", true)
		if st is String and st.is_valid_int():
			params["style"] = clampi(int(st), 0, EData.STYLES.size() - 1)
		var sc = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('scene') || ''", true)
		if sc is String and sc.is_valid_int():
			params["scene"] = clampi(int(sc), 0, 2)
	else:
		params["seed"] = randi() % 100000


# ------------------------------------------------------------------ render graph
func _build_render_graph() -> void:
	var holder := Node.new()
	holder.name = "RenderGraph"
	add_child(holder)
	vp3d = SubViewport.new()
	vp3d.name = "VP3D"
	vp3d.own_world_3d = true
	vp3d.msaa_3d = Viewport.MSAA_4X
	vp3d.mesh_lod_threshold = 0.0
	vp3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp3d.transparent_bg = false
	holder.add_child(vp3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp3d.add_child(env)
	cam = Camera3D.new()
	cam.current = true
	vp3d.add_child(cam)
	world_root = Node3D.new()
	world_root.name = "World"
	vp3d.add_child(world_root)

	bloom_down_mat = ShaderMaterial.new()
	bloom_down_mat.shader = load("res://shaders/bloom_down.gdshader")
	bloom_a = SubViewport.new()
	bloom_a.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(bloom_a)
	var ta := TextureRect.new()
	ta.texture = vp3d.get_texture()
	ta.material = bloom_down_mat
	ta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ta.stretch_mode = TextureRect.STRETCH_SCALE
	ta.set_anchors_preset(Control.PRESET_FULL_RECT)
	bloom_a.add_child(ta)

	bloom_b = SubViewport.new()
	bloom_b.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(bloom_b)
	bloom_b_rect = TextureRect.new()
	bloom_b_rect.texture = bloom_a.get_texture()
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/bloom_blur.gdshader")
	bloom_b_rect.material = bm
	bloom_b_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bloom_b_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bloom_b_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bloom_b.add_child(bloom_b_rect)

	vp_final = SubViewport.new()
	vp_final.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp_final)
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	post_mat.set_shader_parameter("bloom_tex", bloom_b.get_texture())
	post_rect = TextureRect.new()
	post_rect.texture = vp3d.get_texture()
	post_rect.material = post_mat
	post_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	post_rect.stretch_mode = TextureRect.STRETCH_SCALE
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_final.add_child(post_rect)
	overlay = Control.new()
	overlay.set_script(load("res://scripts/overlay.gd"))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp_final.add_child(overlay)
	overlay.font_ui = font_ui
	overlay.font_title = font_title


func _set_sizes() -> void:
	var A: Dictionary = EData.ASPECTS[int(params["aspect"])]
	var w := int(A["w"])
	var h := int(A["h"])
	var q: float = [0.6, 1.0, 1.5][int(params["quality"])]
	size_out = Vector2i(int(w * q), int(h * q))
	vp3d.size = size_out
	vp_final.size = size_out
	var bs := Vector2i(maxi(size_out.x / 4, 8), maxi(size_out.y / 4, 8))
	bloom_a.size = bs
	bloom_b.size = bs
	bloom_down_mat.set_shader_parameter("src_px", Vector2(1.0 / size_out.x, 1.0 / size_out.y))
	if preview:
		preview.texture = vp_final.get_texture()
		_layout_preview()


# ------------------------------------------------------------------ build
func rebuild(push_hist := false) -> void:
	_set_sizes()
	info = gen.build(params, world_root, cam, size_out)
	_apply_globals()
	_apply_post()
	_update_overlay()
	_update_info()
	if push_hist:
		_push_history()


func _apply_globals() -> void:
	var L: Dictionary = info["light"]
	RenderingServer.global_shader_parameter_set("g_style", int(params["style"]))
	RenderingServer.global_shader_parameter_set("g_light_dir", L["dir"])
	RenderingServer.global_shader_parameter_set("g_light_pos", L["pos"])
	RenderingServer.global_shader_parameter_set("g_light_point", L["point"])
	var lc: Color = L["col"]
	RenderingServer.global_shader_parameter_set("g_light_col", Vector3(lc.r, lc.g, lc.b))
	var am: Color = L["amb"]
	RenderingServer.global_shader_parameter_set("g_amb", Vector3(am.r, am.g, am.b))
	var rc: Color = L["rim_col"]
	RenderingServer.global_shader_parameter_set("g_rim_col", Vector3(rc.r, rc.g, rc.b))
	RenderingServer.global_shader_parameter_set("g_rim_dir", L["rim_dir"])
	RenderingServer.global_shader_parameter_set("g_rim_amt", L["rim_amt"])
	var h := EData.HOLO
	RenderingServer.global_shader_parameter_set("g_holo", Vector3(h.r, h.g, h.b))


func _apply_post() -> void:
	var S: Dictionary = EData.STYLES[int(params["style"])]
	var pal := EData.pal_colors(int(info.get("pal", 0)))
	post_mat.set_shader_parameter("style", int(params["style"]))
	post_mat.set_shader_parameter("madness", float(params["madness"]))
	post_mat.set_shader_parameter("bloom_amt", float(S["bloom"]))
	post_mat.set_shader_parameter("grain", float(S["grain"]))
	post_mat.set_shader_parameter("vignette", float(S["vig"]))
	post_mat.set_shader_parameter("px_scale", maxf(0.75, float(mini(size_out.x, size_out.y)) / 720.0))
	post_mat.set_shader_parameter("seed", float(int(params["seed"]) % 1000) * 0.37)
	post_mat.set_shader_parameter("paper", EData.PAPER)
	post_mat.set_shader_parameter("ink", EData.INK)
	post_mat.set_shader_parameter("accent", pal["cor_glow"])
	post_mat.set_shader_parameter("holo", EData.HOLO)
	bloom_down_mat.set_shader_parameter("threshold", 0.55 if int(params["style"]) != 5 else 0.35)


func _update_overlay() -> void:
	overlay.info = info
	overlay.style = int(params["style"])
	overlay.pal = EData.pal_colors(int(info.get("pal", 0)))
	overlay.show_title = bool(params["show_title"])
	overlay.show_labels = bool(params["show_labels"])
	overlay.show_frame = bool(params["show_frame"])
	overlay.show_swatch = bool(params["show_swatch"])
	overlay.seed_val = int(params["seed"])
	var pts := []
	for L in info["labels"]:
		var p: Vector3 = L["pos"]
		if cam.is_position_behind(p):
			continue
		var sp := _project(p)
		pts.append({"p": sp, "text": L["text"], "sub": L.get("sub", ""), "main": L.get("main", false)})
	overlay.label_pts = pts
	overlay.main_pt = _project(info.get("focus", Vector3.ZERO))
	overlay.refresh()


func _project(p: Vector3) -> Vector2:
	# project with our own math because the camera lives in a SubViewport of custom size
	var v := cam.global_transform.affine_inverse() * p
	if v.z >= -0.001:
		return Vector2(-1, -1)
	var asp := float(size_out.x) / float(size_out.y)
	var t := tan(deg_to_rad(cam.fov * 0.5))
	var sx: float
	var sy: float
	if cam.keep_aspect == Camera3D.KEEP_HEIGHT:
		sy = t
		sx = t * asp
	else:
		sx = t
		sy = t / asp
	var nx := (v.x / -v.z) / sx
	var ny := (v.y / -v.z) / sy
	return Vector2((nx * 0.5 + 0.5) * size_out.x, (0.5 - ny * 0.5) * size_out.y)


func _process(delta: float) -> void:
	if bool(params["animate"]):
		time_acc += delta
	RenderingServer.global_shader_parameter_set("g_time", time_acc)
	if rebuild_pending:
		rebuild_timer -= delta
		if rebuild_timer <= 0.0:
			rebuild_pending = false
			rebuild(true)
	if _cap_frames >= 0:
		_cap_frames -= 1
		if _cap_frames < 0:
			var cb := _cap_cb
			_cap_cb = Callable()
			cb.call()


func request_rebuild() -> void:
	if suppress:
		return
	rebuild_pending = true
	rebuild_timer = 0.12


# ------------------------------------------------------------------ history
func _push_history() -> void:
	var snap := params.duplicate()
	if hist_i >= 0 and hist_i < history.size() and history[hist_i] == snap:
		return
	history = history.slice(0, hist_i + 1)
	history.append(snap)
	if history.size() > 60:
		history.pop_front()
	hist_i = history.size() - 1


func _hist_go(d: int) -> void:
	var n := hist_i + d
	if n < 0 or n >= history.size():
		return
	hist_i = n
	params = history[hist_i].duplicate()
	_sync_controls()
	rebuild(false)


# ------------------------------------------------------------------ UI
func _mk_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font_ui
	th.default_font_size = 14
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("101418")
	bg.border_color = Color("2b3a36")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 5
	bg.content_margin_bottom = 5
	var hov := bg.duplicate()
	hov.bg_color = Color("17201f")
	hov.border_color = Color("4dbf8f")
	var prs := bg.duplicate()
	prs.bg_color = Color("1f3a30")
	prs.border_color = Color("6bffb0")
	for t in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", t, bg)
		th.set_stylebox("hover", t, hov)
		th.set_stylebox("pressed", t, prs)
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_color("font_color", t, Color("cfe3da"))
		th.set_color("font_hover_color", t, Color("eafff4"))
		th.set_color("font_pressed_color", t, Color("9dffd0"))
	var le := bg.duplicate()
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", hov)
	th.set_color("font_color", "Label", Color("b9cfc6"))
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("2a4a40")
	grab.set_corner_radius_all(3)
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	var grabhi := grab.duplicate()
	grabhi.bg_color = Color("4dbf8f")
	th.set_stylebox("slider", "HSlider", grab)
	th.set_stylebox("grabber_area", "HSlider", grabhi)
	th.set_stylebox("grabber_area_highlight", "HSlider", grabhi)
	var pnl := StyleBoxFlat.new()
	pnl.bg_color = Color("0b0e10")
	pnl.border_color = Color("1e2a27")
	pnl.set_border_width_all(1)
	th.set_stylebox("panel", "PanelContainer", pnl)
	var pop := StyleBoxFlat.new()
	pop.bg_color = Color("12181a")
	pop.border_color = Color("2b3a36")
	pop.set_border_width_all(1)
	th.set_stylebox("panel", "PopupMenu", pop)
	th.set_stylebox("hover", "PopupMenu", hov)
	th.set_color("font_color", "PopupMenu", Color("cfe3da"))
	th.set_color("font_hover_color", "PopupMenu", Color("eafff4"))
	th.set_font_size("font_size", "PopupMenu", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1e2a27")
	sb.set_corner_radius_all(3)
	th.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	th.set_stylebox("grabber", "VScrollBar", sb)
	th.set_stylebox("grabber_highlight", "VScrollBar", hov)
	th.set_stylebox("grabber_pressed", "VScrollBar", prs)
	th.set_color("default_color", "RichTextLabel", Color("b9cfc6"))
	th.set_font("normal_font", "RichTextLabel", font_ui)
	th.set_font("bold_font", "RichTextLabel", font_title)
	th.set_font_size("normal_font_size", "RichTextLabel", 13)
	th.set_font_size("bold_font_size", "RichTextLabel", 15)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color("0b0e10")
	tb.content_margin_left = 10
	tb.content_margin_right = 10
	tb.content_margin_top = 6
	tb.content_margin_bottom = 6
	var tbs := tb.duplicate()
	tbs.bg_color = Color("17201f")
	tbs.border_color = Color("4dbf8f")
	tbs.border_width_bottom = 2
	th.set_stylebox("tab_selected", "TabBar", tbs)
	th.set_stylebox("tab_unselected", "TabBar", tb)
	th.set_stylebox("tab_hovered", "TabBar", tbs)
	th.set_color("font_selected_color", "TabBar", Color("9dffd0"))
	th.set_color("font_unselected_color", "TabBar", Color("8aa39a"))
	th.set_color("font_hovered_color", "TabBar", Color("eafff4"))
	th.set_font_size("font_size", "TabBar", 15)
	th.set_font("font", "TabBar", font_title)
	return th


func _build_ui() -> void:
	theme = _mk_theme()
	var bgc := ColorRect.new()
	bgc.color = Color("06080a")
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bgc)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ---------- left panel
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(318, 0)
	root.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lp.add_child(lv)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	var mh := MarginContainer.new()
	for side in ["left", "right", "top"]:
		mh.add_theme_constant_override("margin_" + side, 12)
	mh.add_child(head)
	lv.add_child(mh)
	var t1 := Label.new()
	t1.text = "旧日星图"
	t1.add_theme_font_override("font", font_title)
	t1.add_theme_font_size_override("font_size", 28)
	t1.add_theme_color_override("font_color", Color("9dffd0"))
	head.add_child(t1)
	var t2 := Label.new()
	t2.text = "ELDRITCH STARCHART · 克苏鲁星体概念立绘生成器"
	t2.add_theme_font_size_override("font_size", 11)
	t2.add_theme_color_override("font_color", Color("5f7d72"))
	head.add_child(t2)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	var mg := MarginContainer.new()
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + side, 12)
	mg.add_theme_constant_override("margin_bottom", 12)
	sc.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.add_child(v)

	_section(v, "画面类型")
	var tabs := TabBar.new()
	for s in EData.SCENE_TYPES:
		tabs.add_tab(s)
	tabs.tab_changed.connect(func(i): _setp("scene", i))
	ctrl["scene"] = tabs
	v.add_child(tabs)

	_section(v, "美术风格")
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 4)
	sg.add_theme_constant_override("v_separation", 4)
	v.add_child(sg)
	var bgroup := ButtonGroup.new()
	var sbtns := []
	for i in EData.STYLES.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = bgroup
		b.text = EData.STYLES[i]["name"]
		b.tooltip_text = "%s\n%s" % [EData.STYLES[i]["en"], EData.STYLES[i]["desc"]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _setp("style", i))
		sg.add_child(b)
		sbtns.append(b)
	ctrl["style"] = sbtns
	var sdesc := Label.new()
	sdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sdesc.add_theme_font_size_override("font_size", 11)
	sdesc.add_theme_color_override("font_color", Color("6f8c82"))
	ctrl["style_desc"] = sdesc
	v.add_child(sdesc)

	_section(v, "种子")
	var sh := HBoxContainer.new()
	v.add_child(sh)
	var se := LineEdit.new()
	se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	se.text_submitted.connect(func(t): if t.is_valid_int(): _setp("seed", int(t)))
	ctrl["seed"] = se
	sh.add_child(se)
	var bp := Button.new()
	bp.text = "◀"
	bp.tooltip_text = "上一个种子"
	bp.pressed.connect(func(): _setp("seed", int(params["seed"]) - 1))
	sh.add_child(bp)
	var bn := Button.new()
	bn.text = "▶"
	bn.tooltip_text = "下一个种子"
	bn.pressed.connect(func(): _setp("seed", int(params["seed"]) + 1))
	sh.add_child(bn)
	var br := Button.new()
	br.text = "随机"
	br.tooltip_text = "随机种子"
	br.pressed.connect(func(): _setp("seed", randi() % 1000000))
	sh.add_child(br)

	_section(v, "主体设定")
	var arch_items := ["随机"]
	for a in EData.ARCHETYPES:
		arch_items.append("%s  %s" % [a["name"], a["en"]])
	_option(v, "星球原型", "archetype", arch_items, -1)
	var pal_items := ["按原型自动"]
	for p in EData.PALETTES:
		pal_items.append(p["name"])
	_option(v, "色板", "palette", pal_items, -1)
	_option(v, "构图", "composition", EData.COMPOSITIONS, 0, "portrait_only")
	var st_items := ["随机"]
	for s in EData.STAR_TYPES:
		st_items.append(s["name"])
	_option(v, "中心天体", "star_type", st_items, -1, "system_only")
	var w_items := ["随机"]
	for w in EData.WONDERS:
		w_items.append(w["name"])
	_option(v, "奇景类型", "wonder", w_items, -1, "wonder_only")
	_option(v, "卫星/行星数", "count", ["随机", "0", "1", "2", "3", "4", "5", "6", "7", "8"], -1)
	_option(v, "星环", "rings", ["随机", "有", "无"], 0)

	_section(v, "克苏鲁元素")
	_slider(v, "触手", "tentacles")
	_slider(v, "眼睛", "eyes")
	_slider(v, "古神符文", "glyphs")
	_slider(v, "腐化蔓延", "corruption")
	_slider(v, "疯狂扭曲", "madness")
	_slider(v, "星云密度", "nebula")

	_section(v, "画面与输出")
	var asp_items := []
	for a in EData.ASPECTS:
		asp_items.append(a["name"])
	_option(v, "画幅", "aspect", asp_items, 0)
	_option(v, "渲染精度", "quality", ["预览 (0.6x)", "标准 (1x)", "高清 (1.5x)"], 0)
	var cg := GridContainer.new()
	cg.columns = 2
	v.add_child(cg)
	_check(cg, "标题卡", "show_title")
	_check(cg, "天体标注", "show_labels")
	_check(cg, "风格边框", "show_frame")
	_check(cg, "色板色卡", "show_swatch")
	_check(cg, "动态预览", "animate")

	# ---------- center
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 0)
	root.add_child(cv)
	var tb := PanelContainer.new()
	cv.add_child(tb)
	var tbm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		tbm.add_theme_constant_override("margin_" + side, 6)
	tb.add_child(tbm)
	var th := HFlowContainer.new()
	th.add_theme_constant_override("h_separation", 6)
	th.add_theme_constant_override("v_separation", 6)
	tbm.add_child(th)
	_tool(th, "★ 生成新立绘", func(): _setp("seed", randi() % 1000000), true)
	_tool(th, "◆ 全随机", _randomize_all)
	_tool(th, "◀ 撤销", func(): _hist_go(-1))
	_tool(th, "重做 ▶", func(): _hist_go(1))
	_tool(th, "☆ 收藏", _add_gallery)
	_tool(th, "⬇ 导出 PNG", _export_png)
	_tool(th, "▦ 批量风格对比", _style_sheet)
	info_toggle = Button.new()
	info_toggle.text = "◇ 设定档案"
	info_toggle.toggle_mode = true
	info_toggle.button_pressed = true
	info_toggle.toggled.connect(func(b):
		_user_toggled = true
		right_panel.visible = b)
	th.add_child(info_toggle)
	status_label = Label.new()
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("6f8c82"))
	th.add_child(status_label)

	preview_frame = Control.new()
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.clip_contents = true
	preview_frame.resized.connect(_layout_preview)
	cv.add_child(preview_frame)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preview_frame.add_child(preview)

	var gp := PanelContainer.new()
	gp.custom_minimum_size = Vector2(0, 104)
	cv.add_child(gp)
	var gsc := ScrollContainer.new()
	gsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gp.add_child(gsc)
	gallery_box = HFlowContainer.new()
	gallery_box.add_theme_constant_override("h_separation", 6)
	gsc.add_child(gallery_box)
	var gl := Label.new()
	gl.text = "  收藏夹：点击「☆ 收藏」将当前立绘加入此处，点击缩略图可恢复其全部参数。"
	gl.add_theme_font_size_override("font_size", 12)
	gl.add_theme_color_override("font_color", Color("4a6359"))
	gallery_box.add_child(gl)

	# ---------- right panel
	var rp := PanelContainer.new()
	rp.custom_minimum_size = Vector2(300, 0)
	root.add_child(rp)
	right_panel = rp
	var rm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + side, 12)
	rp.add_child(rm)
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.scroll_active = true
	info_label.selection_enabled = true
	rm.add_child(info_label)


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = "— " + text
	l.add_theme_font_override("font", font_title)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("6bdca8"))
	parent.add_child(l)


func _option(parent: Control, label: String, key: String, items: Array, base: int, vis := "") -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(84, 0)
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.fit_to_longest_item = false
	o.clip_text = true
	for it in items:
		o.add_item(it)
	o.item_selected.connect(func(i): _setp(key, i + base))
	h.add_child(o)
	ctrl[key] = {"node": o, "base": base, "row": h, "vis": vis}


func _slider(parent: Control, label: String, key: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(84, 0)
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var vl := Label.new()
	vl.custom_minimum_size = Vector2(34, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.add_theme_font_size_override("font_size", 12)
	h.add_child(vl)
	s.value_changed.connect(func(x):
		vl.text = "%d" % int(round(x * 100))
		_setp(key, x))
	ctrl[key] = {"slider": s, "val": vl}


func _check(parent: Control, label: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = label
	c.add_theme_font_size_override("font_size", 13)
	c.toggled.connect(func(b): _setp(key, b))
	parent.add_child(c)
	ctrl[key] = c


func _tool(parent: Control, text: String, cb: Callable, primary := false) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	if primary:
		b.add_theme_color_override("font_color", Color("9dffd0"))
	parent.add_child(b)


func _sync_controls() -> void:
	suppress = true
	(ctrl["scene"] as TabBar).current_tab = int(params["scene"])
	var sb: Array = ctrl["style"]
	for i in sb.size():
		(sb[i] as Button).set_pressed_no_signal(i == int(params["style"]))
	(ctrl["style_desc"] as Label).text = "%s · %s" % [EData.STYLES[int(params["style"])]["en"], EData.STYLES[int(params["style"])]["desc"]]
	(ctrl["seed"] as LineEdit).text = str(params["seed"])
	for key in ["archetype", "palette", "composition", "star_type", "wonder", "count", "rings", "aspect", "quality"]:
		var c: Dictionary = ctrl[key]
		(c["node"] as OptionButton).select(int(params[key]) - int(c["base"]))
		var vis: String = c["vis"]
		var row: Control = c["row"]
		match vis:
			"portrait_only":
				row.visible = int(params["scene"]) == 0
			"system_only":
				row.visible = int(params["scene"]) == 1
			"wonder_only":
				row.visible = int(params["scene"]) == 2
	for key in ["tentacles", "eyes", "glyphs", "corruption", "madness", "nebula"]:
		var c: Dictionary = ctrl[key]
		(c["slider"] as HSlider).set_value_no_signal(float(params[key]))
		(c["val"] as Label).text = "%d" % int(round(float(params[key]) * 100))
	for key in ["show_title", "show_labels", "show_frame", "show_swatch", "animate"]:
		(ctrl[key] as CheckBox).set_pressed_no_signal(bool(params[key]))
	suppress = false


func _setp(key: String, val) -> void:
	if suppress:
		return
	params[key] = val
	if key in ["scene", "style", "seed"]:
		_sync_controls()
	if key in ["show_title", "show_labels", "show_frame", "show_swatch"]:
		_update_overlay()
		return
	if key == "animate":
		return
	if key == "madness":
		post_mat.set_shader_parameter("madness", float(val))
		_update_info()
		return
	if key == "style":
		# style changes need no geometry rebuild except low-poly / tentacle mesh swap
		rebuild(true)
		return
	if key in ["seed", "scene", "aspect", "quality"]:
		rebuild(true)
		return
	request_rebuild()


func _randomize_all() -> void:
	params["seed"] = randi() % 1000000
	params["style"] = randi() % EData.STYLES.size()
	params["scene"] = [0, 0, 0, 1, 2, 2][randi() % 6]
	params["archetype"] = -1
	params["palette"] = -1
	params["composition"] = 0
	params["tentacles"] = [0.0, 0.0, 0.25, 0.5, 0.8][randi() % 5]
	params["eyes"] = [0.0, 0.0, 0.3, 0.6][randi() % 4]
	params["glyphs"] = randf_range(0.0, 0.9)
	params["corruption"] = randf_range(0.0, 0.7)
	params["madness"] = randf_range(0.0, 0.5)
	params["nebula"] = randf_range(0.3, 0.9)
	_sync_controls()
	rebuild(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and right_panel:
		_apply_responsive.call_deferred()


func _apply_responsive() -> void:
	if not _user_toggled:
		right_panel.visible = size.x >= 1220
	info_toggle.set_pressed_no_signal(right_panel.visible)


var _user_toggled := false


func _layout_preview() -> void:
	if not preview_frame:
		return
	var fs := preview_frame.size - Vector2(24, 24)
	var a := float(size_out.x) / float(size_out.y)
	var w := fs.x
	var h := w / a
	if h > fs.y:
		h = fs.y
		w = h * a
	preview.size = Vector2(w, h)
	preview.position = (preview_frame.size - preview.size) * 0.5


func _update_info() -> void:
	var t := ""
	t += "[font_size=22][color=#9dffd0][b]%s[/b][/color][/font_size]\n" % info.get("title", "")
	t += "[color=#e6c55a]%s[/color]  [color=#6f8c82]%s[/color]\n" % [info.get("cn", ""), info.get("catalog", "")]
	t += "[i][color=#b9cfc6]「%s」[/color][/i]\n" % info.get("epithet", "")
	t += "[color=#6f8c82]%s[/color]\n\n" % info.get("kind", "")
	t += "[b][color=#6bdca8]观测数据[/color][/b]\n"
	for s in info.get("stats", []):
		t += "[color=#6f8c82]%s[/color]   %s\n" % [s[0], s[1]]
	t += "\n[b][color=#6bdca8]天体清单[/color][/b]\n"
	for b in info.get("bodies", []):
		t += "· %s  [color=#6f8c82]%s[/color]\n" % [b["name"], b["kind"]]
	t += "\n[b][color=#6bdca8]异闻记录[/color][/b]\n%s\n" % info.get("hook", "")
	t += "\n[b][color=#6bdca8]玩法建议[/color][/b]\n%s\n" % info.get("gameplay", "")
	var pid := int(info.get("pal", 0))
	var P: Dictionary = EData.PALETTES[pid]
	t += "\n[b][color=#6bdca8]色板 · %s[/color][/b]\n" % P["name"]
	for hx in P["c"]:
		t += "[bgcolor=#%s]      [/bgcolor] " % hx
	t += "\n"
	for hx in P["c"]:
		t += "[color=#6f8c82][font_size=10]#%s[/font_size][/color] " % String(hx).to_upper()
	var S: Dictionary = EData.STYLES[int(params["style"])]
	t += "\n\n[b][color=#6bdca8]风格[/color][/b]  %s · %s\n[color=#6f8c82]%s[/color]\n" % [S["name"], S["en"], S["desc"]]
	t += "\n[color=#4a6359][font_size=11]种子 %d · %s · %dx%d\n相同种子+参数可稳定复现同一张立绘。[/font_size][/color]" % [int(params["seed"]), EData.SCENE_TYPES[int(params["scene"])], size_out.x, size_out.y]
	info_label.text = t
	status_label.text = "%s · %s · seed %d" % [EData.SCENE_TYPES[int(params["scene"])], S["name"], int(params["seed"])]


# ------------------------------------------------------------------ capture / export
func _capture(cb: Callable, frames := 3) -> void:
	_cap_frames = frames
	_cap_cb = cb


func _file_name() -> String:
	var t: String = info.get("title", "planet")
	var safe := ""
	for ch in t:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			safe += ch
	return "eldritch_%s_%s_%d.png" % [safe.substr(0, 20), EData.STYLES[int(params["style"])]["en"].replace(" ", ""), int(params["seed"])]


func _export_png() -> void:
	status_label.text = "正在导出……"
	_capture(func():
		var img := vp_final.get_texture().get_image()
		_save_image(img, _file_name())
		status_label.text = "已导出 %s" % _file_name())


func _save_image(img: Image, fname: String) -> void:
	var buf := img.save_png_to_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(buf, fname, "image/png")
	else:
		var dir := "user://exports"
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir + "/" + fname, FileAccess.WRITE)
		if f:
			f.store_buffer(buf)
			f.close()
		print("saved ", ProjectSettings.globalize_path(dir + "/" + fname))


func _add_gallery() -> void:
	var snap := params.duplicate()
	_capture(func():
		var img := vp_final.get_texture().get_image()
		var th := 88
		img.resize(int(th * float(img.get_width()) / img.get_height()), th, Image.INTERPOLATE_BILINEAR)
		var tex := ImageTexture.create_from_image(img)
		if gallery.is_empty():
			for c in gallery_box.get_children():
				c.queue_free()
		gallery.append(snap)
		var b := TextureButton.new()
		b.texture_normal = tex
		b.tooltip_text = "%s\n%s · seed %d" % [info.get("title", ""), EData.STYLES[int(snap["style"])]["name"], int(snap["seed"])]
		b.pressed.connect(func():
			params = snap.duplicate()
			_sync_controls()
			rebuild(true))
		gallery_box.add_child(b)
		status_label.text = "已收藏（%d）" % gallery.size())


## Renders the current subject in all 8 styles and stitches a 4x2 contact sheet.
func _style_sheet() -> void:
	var orig := int(params["style"])
	var tiles := []
	var cw := 480
	var ch := int(cw * float(size_out.y) / size_out.x)
	status_label.text = "生成风格对比表……"
	var sheet_name := _file_name().replace(".png", "_styles.png")
	var step := func(self_ref: Callable, i: int) -> void:
		if i > 0:
			var img := vp_final.get_texture().get_image()
			img.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			tiles.append(img)
		if i >= EData.STYLES.size():
			var sheet := Image.create(cw * 4 + 5 * 8, ch * 2 + 3 * 8, false, Image.FORMAT_RGBA8)
			sheet.fill(Color("06080a"))
			for k in tiles.size():
				var tl: Image = tiles[k]
				if tl.get_format() != Image.FORMAT_RGBA8:
					tl.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(tl, Rect2i(0, 0, cw, ch), Vector2i(8 + (k % 4) * (cw + 8), 8 + (k / 4) * (ch + 8)))
			_save_image(sheet, sheet_name)
			params["style"] = orig
			_sync_controls()
			rebuild(false)
			status_label.text = "风格对比表已导出"
			return
		params["style"] = i
		rebuild(false)
		_capture(func(): self_ref.call(self_ref, i + 1), 3)
	step.call(step, 0)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE:
				_setp("seed", randi() % 1000000)
			KEY_LEFT:
				_setp("seed", int(params["seed"]) - 1)
			KEY_RIGHT:
				_setp("seed", int(params["seed"]) + 1)
			KEY_S:
				_export_png()
			KEY_Z:
				if e.ctrl_pressed:
					_hist_go(-1)
