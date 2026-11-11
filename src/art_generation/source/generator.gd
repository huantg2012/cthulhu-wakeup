extends RefCounted
const ELore = preload("res://src/art_generation/source/lore.gd")
const EData = preload("res://src/art_generation/source/data.gd")
## Builds a 3D celestial scene from a parameter dictionary.

const FOV := 34.0
const D := 10.0

var meshes := {}
var shaders := {}
var rng := RandomNumberGenerator.new()
var root: Node3D
var cam: Camera3D
var P: Dictionary
var aspect := 16.0 / 9.0
var hx := 1.0   # horizontal half extent at depth D (plane z = 0)
var hy := 1.0
var style := 0
var info := {}
var labels := []
var light := {}
var quad: QuadMesh


func setup(mesh_dict: Dictionary, shader_dict: Dictionary) -> void:
	meshes = mesh_dict
	shaders = shader_dict
	quad = QuadMesh.new()
	quad.size = Vector2(1, 1)


# ------------------------------------------------------------------ helpers
## independent random stream per feature so sliders don't reshuffle the whole composition
func sub(k: int) -> void:
	rng.seed = int(P["seed"]) * 7919 + int(P["scene"]) * 104729 + k * 15485863 + 17


func rf(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func ri(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func chance(p: float) -> bool:
	return rng.randf() < p


func wpick(weights: Array) -> int:
	var tot := 0.0
	for w in weights:
		tot += w
	var x := rng.randf() * tot
	for i in weights.size():
		x -= weights[i]
		if x <= 0.0:
			return i
	return weights.size() - 1


func seed_vec() -> Vector3:
	return Vector3(rf(-60, 60), rf(-60, 60), rf(-60, 60))


func mat(key: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shaders[key]
	return m


func mi(mesh: Mesh, m: Material, xf: Transform3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.transform = xf
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)
	return n


func screen_dir(u: float, v: float) -> Vector3:
	return Vector3(u * hx / D, v * hy / D, -1.0).normalized()


## world point on the plane at depth z (camera looks down -Z from (0,0,D)) for normalised screen coords
func screen_pt(u: float, v: float, z: float) -> Vector3:
	var k := (D - z) / D
	return Vector3(u * hx * k, v * hy * k, z)


func to_screen(p: Vector3) -> Vector2:
	var k := (D - p.z) / D
	return Vector2(p.x / (hx * k), p.y / (hy * k))


func darker(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


func basis_from_y(y: Vector3, side: Vector3) -> Basis:
	y = y.normalized()
	var x := side - y * side.dot(y)
	if x.length() < 0.001:
		x = Vector3(1, 0, 0) - y * y.x
	x = x.normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


# ------------------------------------------------------------------ main entry
func build(params: Dictionary, root_node: Node3D, camera: Camera3D, size: Vector2i) -> Dictionary:
	P = params
	root = root_node
	cam = camera
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	rng.seed = int(P["seed"]) * 7919 + int(P["scene"]) * 31 + 17
	style = int(P["style"])
	aspect = float(size.x) / float(size.y)
	var t := tan(deg_to_rad(FOV * 0.5)) * D
	if aspect >= 1.0:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		hy = t
		hx = t * aspect
	else:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		hx = t
		hy = t / aspect
	cam.fov = FOV
	cam.near = 0.05
	cam.far = 4000.0
	cam.transform = Transform3D(Basis(), Vector3(0, 0, D))
	info = {"stats": [], "bodies": []}
	labels = []
	light = {"dir": Vector3(1, 0.4, 0.6).normalized(), "pos": Vector3.ZERO, "point": 0.0,
		"col": Color(1, 0.96, 0.9), "amb": Color(0.03, 0.035, 0.05), "rim_dir": Vector3(-1, 0.2, -0.4), "rim_col": Color(0.3, 1, 0.6), "rim_amt": 0.6}
	match int(P["scene"]):
		0:
			_build_portrait()
		1:
			_build_system()
		_:
			_build_wonder()
	info["light"] = light
	info["labels"] = labels
	return info


# ------------------------------------------------------------------ building blocks
func pick_arch(fixed: int, exclude: Array = []) -> int:
	if fixed >= 0:
		return fixed
	var w := [1.2, 1.1, 1.0, 1.0, 0.9, 0.9, 0.9, 1.0, 0.8, 0.9, 0.5]
	for e in exclude:
		w[e] = 0.0
	return wpick(w)


func pick_pal(arch: int, fixed: int) -> int:
	if fixed >= 0:
		return fixed
	var pals: Array = EData.ARCHETYPES[arch]["pals"]
	if chance(0.78):
		return pals[rng.randi() % pals.size()]
	return rng.randi() % EData.PALETTES.size()


func setup_light(dir: Vector3, pal: Dictionary) -> void:
	light["dir"] = dir.normalized()
	light["point"] = 0.0
	var lc: Color = pal["star_hot"]
	light["col"] = Color(1, 1, 1).lerp(lc, 0.35) * 1.05
	light["amb"] = darker(pal["n1"], 0.12).lerp(Color(0.02, 0.02, 0.03), 0.5)
	var rd := Vector3(-dir.x, 0.25 - dir.y * 0.4, -0.45).normalized()
	light["rim_dir"] = rd
	light["rim_col"] = pal["rim"]
	light["rim_amt"] = float(EData.STYLES[style]["rim"]) * rf(0.45, 0.9)


func add_planet(pos: Vector3, R: float, arch: int, pid: int, o: Dictionary = {}) -> Dictionary:
	var pal := EData.pal_colors(pid)
	var A: Dictionary = EData.ARCHETYPES[arch]
	var m := mat("planet_%d" % arch)
	for k in ["c0", "c1", "c2", "c3", "c4"]:
		m.set_shader_parameter(k, pal[k])
	m.set_shader_parameter("seed_off", seed_vec())
	m.set_shader_parameter("atmo_col", pal["atmo"])
	m.set_shader_parameter("atmo_rim", float(A["atmo"]) * 0.55)
	m.set_shader_parameter("sea_level", rf(-0.08, 0.06))
	m.set_shader_parameter("glyphs", float(o.get("glyphs", 0.0)))
	m.set_shader_parameter("corruption", float(o.get("corruption", 0.0)))
	m.set_shader_parameter("cor_dark", pal["cor_dark"])
	m.set_shader_parameter("cor_glow", pal["cor_glow"])
	m.set_shader_parameter("night_lights", float(A["night"]) * rf(0.6, 1.2))
	m.set_shader_parameter("eyes_many", float(o.get("eyes", 0.0)))
	m.set_shader_parameter("iris_col", pal["iris"])
	m.set_shader_parameter("bump", float(A["bump"]))
	var low := style == 3
	m.set_shader_parameter("lowpoly", low)
	m.set_shader_parameter("octaves", 4 if (style == 3 or style == 4 or R < 0.5) else 6)
	if arch == 1 or float(o.get("big_eye", 0.0)) > 0.0:
		var v := (cam.position - pos).normalized()
		var ed: Vector3 = (v + Vector3(rf(-0.25, 0.25), rf(-0.2, 0.25), 0.0) + light["dir"] * 0.25).normalized()
		if o.has("eye_dir"):
			ed = o["eye_dir"]
		m.set_shader_parameter("eye_amt", 1.0)
		m.set_shader_parameter("eye_dir", ed)
		m.set_shader_parameter("eye_size", rf(0.42, 0.72))
		m.set_shader_parameter("eye_open", rf(0.55, 1.0))
		m.set_shader_parameter("eye_look", Vector2(rf(-0.25, 0.25), rf(-0.12, 0.12)))
		m.set_shader_parameter("pupil_type", ri(0, 3))
	var xf := Transform3D(Basis.from_euler(Vector3(rf(-0.5, 0.5), rf(0, TAU), rf(-0.3, 0.3))).scaled(Vector3.ONE * R), pos)
	var body := mi(meshes["PlanetLow" if low else "Planet"], m, xf)
	var res := {"node": body, "mat": m, "pos": pos, "R": R, "arch": arch, "pid": pid, "pal": pal}
	# atmosphere shell
	var atmo := float(A["atmo"]) * float(o.get("atmo_k", 1.0))
	if atmo > 0.01:
		var am := mat("atmo")
		var th := rf(0.05, 0.09)
		am.set_shader_parameter("atmo_col", pal["atmo"])
		am.set_shader_parameter("thickness", th)
		am.set_shader_parameter("intensity", atmo * rf(0.8, 1.15))
		am.set_shader_parameter("planet_r", R)
		mi(meshes["Orb"] if R < 0.6 else meshes["Planet"], am, Transform3D(Basis().scaled(Vector3.ONE * R * (1.0 + th * 5.5)), pos))
	# ring
	if o.get("ring", false):
		add_ring(res, o)
	return res


func add_ring(pl: Dictionary, o: Dictionary) -> void:
	var R: float = pl["R"]
	var pal: Dictionary = pl["pal"]
	var outer := R * rf(1.85, 2.5)
	var inner := maxf(rf(0.48, 0.7), R * 1.12 / outer)
	var tilt := deg_to_rad(rf(11.0, 28.0)) * (1.0 if chance(0.7) else -1.0)
	var b := Basis(Vector3(0, 0, 1), deg_to_rad(rf(-28, 28))) * Basis(Vector3(1, 0, 0), tilt)
	if o.has("ring_basis"):
		b = o["ring_basis"]
	var rm := mat("ring_dust")
	rm.set_shader_parameter("c_a", pal["c3"])
	rm.set_shader_parameter("c_b", pal["c1"].lerp(pal["c2"], 0.5))
	rm.set_shader_parameter("c_glow", pal["c4"])
	rm.set_shader_parameter("inner", inner)
	rm.set_shader_parameter("seed", rf(0, 100))
	rm.set_shader_parameter("density", rf(0.65, 1.0))
	var gl := float(o.get("glyphs", 0.0))
	rm.set_shader_parameter("glyph_amt", gl if (gl > 0.3 and chance(0.65)) else 0.0)
	rm.set_shader_parameter("planet_c", pl["pos"])
	rm.set_shader_parameter("planet_r", R)
	mi(meshes["Ring"], rm, Transform3D(b.scaled(Vector3.ONE * outer), pl["pos"]))
	var pm: ShaderMaterial = pl["mat"]
	pm.set_shader_parameter("ring_shadow", 1.0)
	pm.set_shader_parameter("ring_n", b.y.normalized())
	pm.set_shader_parameter("ring_r0", inner * outer / R)
	pm.set_shader_parameter("ring_r1", outer / R)
	pm.set_shader_parameter("ring_seed", rf(0, 10))


func add_star(pos: Vector3, r: float, stype: int, pal: Dictionary, glow_k: float = 1.0, inner_k: float = 1.0) -> void:
	var sm := mat("star")
	var hot: Color = pal["star_hot"]
	var cool: Color = pal["star_cool"]
	sm.set_shader_parameter("stype", stype)
	sm.set_shader_parameter("hot", hot)
	sm.set_shader_parameter("cool", cool)
	sm.set_shader_parameter("accent", pal["iris"] if stype == 2 else pal["c4"])
	sm.set_shader_parameter("seed_off", seed_vec())
	mi(meshes["Planet"], sm, Transform3D(Basis().scaled(Vector3.ONE * r), pos))
	var cm := mat("corona")
	var inner := 0.12
	if stype == 4:
		cm.set_shader_parameter("mode", 1)
		cm.set_shader_parameter("col_a", Color(1, 0.95, 0.85).lerp(hot, 0.4))
		cm.set_shader_parameter("col_b", cool)
		inner = 0.2
	elif stype == 1:
		cm.set_shader_parameter("mode", 0)
		cm.set_shader_parameter("col_a", pal["c4"])
		cm.set_shader_parameter("col_b", pal["cor_glow"])
		cm.set_shader_parameter("rays", 1.6)
	else:
		cm.set_shader_parameter("mode", 0)
		cm.set_shader_parameter("col_a", hot)
		cm.set_shader_parameter("col_b", cool)
		if stype == 3:
			cm.set_shader_parameter("rays", 0.4)
	inner = minf(inner * inner_k, 0.45)
	cm.set_shader_parameter("inner", inner)
	cm.set_shader_parameter("seed", rf(0, 100))
	cm.set_shader_parameter("intensity", glow_k)
	mi(quad, cm, Transform3D(Basis().scaled(Vector3.ONE * r / inner), pos)).extra_cull_margin = r * 10.0
	if stype == 4:
		var dm := mat("ring_fx")
		dm.set_shader_parameter("mode", 2)
		dm.set_shader_parameter("col_a", Color(1, 0.92, 0.75).lerp(hot, 0.5))
		dm.set_shader_parameter("col_b", cool)
		dm.set_shader_parameter("inner", 0.3)
		dm.set_shader_parameter("seed", rf(0, 50))
		dm.set_shader_parameter("spin", 0.6)
		var b := Basis(Vector3(0, 0, 1), deg_to_rad(rf(-12, 12))) * Basis(Vector3(1, 0, 0), deg_to_rad(rf(9, 16)))
		mi(meshes["Ring"], dm, Transform3D(b.scaled(Vector3.ONE * r * 4.2), pos))


func add_tentacle(base: Vector3, b: Basis, length: float, pal: Dictionary, o: Dictionary = {}) -> void:
	var tm := mat("tentacle")
	tm.set_shader_parameter("len", length)
	tm.set_shader_parameter("thick", float(o.get("thick", rf(0.8, 1.25))))
	tm.set_shader_parameter("curl", float(o.get("curl", rf(1.4, 3.6))))
	tm.set_shader_parameter("curl_pow", rf(1.6, 2.8))
	tm.set_shader_parameter("wave_amp", rf(0.3, 0.9))
	tm.set_shader_parameter("wave_freq", rf(0.7, 1.6))
	tm.set_shader_parameter("wave_speed", rf(0.3, 0.9))
	tm.set_shader_parameter("twist", rf(-0.5, 0.5))
	tm.set_shader_parameter("phase", rf(0, TAU))
	tm.set_shader_parameter("skin_a", darker(pal["c1"], 0.9))
	tm.set_shader_parameter("skin_b", pal["c3"].lerp(Color(0.75, 0.5, 0.48), 0.35))
	tm.set_shader_parameter("sucker_col", pal["c3"].lerp(Color(0.95, 0.82, 0.75), 0.5))
	tm.set_shader_parameter("glow", pal["c4"])
	tm.set_shader_parameter("glow_amt", float(o.get("glow", rf(0.2, 0.9))))
	tm.set_shader_parameter("seed_off", seed_vec())
	tm.set_shader_parameter("shade_mul", float(o.get("shade", 1.0)))
	var n := mi(meshes["TentacleLow" if style == 3 else "Tentacle"], tm, Transform3D(b, base))
	n.extra_cull_margin = length * 2.0


func add_prop(mesh_name: String, xf: Transform3D, pal: Dictionary, o: Dictionary = {}) -> void:
	var pm := mat("prop")
	pm.set_shader_parameter("base", o.get("base", darker(pal["c1"], 0.55).lerp(Color(0.1, 0.1, 0.11), 0.5)))
	pm.set_shader_parameter("base2", o.get("base2", pal["c2"].lerp(Color(0.4, 0.38, 0.35), 0.5)))
	pm.set_shader_parameter("glow", pal["c4"])
	pm.set_shader_parameter("glyph_amt", float(o.get("glyph", 0.0)))
	pm.set_shader_parameter("crack_amt", float(o.get("crack", 0.0)))
	pm.set_shader_parameter("noise_scale", float(o.get("ns", 3.0)))
	pm.set_shader_parameter("flat_shade", float(o.get("flat", 0.0)))
	pm.set_shader_parameter("glyph_scale", float(o.get("gs", 9.0)))
	pm.set_shader_parameter("seed_off", seed_vec())
	pm.set_shader_parameter("shade_mul", float(o.get("shade", 1.0)))
	mi(meshes[mesh_name], pm, xf)


func add_belt(center: Vector3, b: Basis, r0: float, r1: float, count: int, size: float, pal: Dictionary, thick: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = meshes["Rock%d" % ri(0, 3)]
	mm.instance_count = count
	for i in count:
		var a := rf(0, TAU)
		var r := lerpf(r0, r1, pow(rng.randf(), 0.8))
		var p := Vector3(cos(a) * r, rf(-thick, thick), sin(a) * r)
		var s := size * pow(rng.randf(), 2.2) * 1.6 + size * 0.25
		var rb := Basis.from_euler(Vector3(rf(0, TAU), rf(0, TAU), rf(0, TAU))).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(b * rb, center + b * p))
		var k := rf(0.6, 1.25)
		mm.set_instance_color(i, Color(k, k * rf(0.9, 1.05), k * rf(0.85, 1.05), rng.randf()))
	var pm := mat("prop")
	pm.set_shader_parameter("base", darker(pal["c1"], 0.6).lerp(Color(0.12, 0.11, 0.1), 0.5))
	pm.set_shader_parameter("base2", pal["c3"].lerp(Color(0.45, 0.42, 0.38), 0.5))
	pm.set_shader_parameter("glow", pal["c4"])
	pm.set_shader_parameter("use_instance_color", true)
	pm.set_shader_parameter("noise_scale", 2.0)
	pm.set_shader_parameter("crack_amt", 0.35)
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	n.material_override = pm
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)


func add_ringfx(xf: Transform3D, mode: int, ca: Color, cb: Color, o: Dictionary = {}) -> void:
	var m := mat("ring_fx")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("col_a", ca)
	m.set_shader_parameter("col_b", cb)
	m.set_shader_parameter("intensity", float(o.get("intensity", 1.0)))
	m.set_shader_parameter("seed", rf(0, 50))
	m.set_shader_parameter("spin", float(o.get("spin", rf(0.04, 0.12))))
	m.set_shader_parameter("line_px", float(o.get("px", 1.3)))
	m.set_shader_parameter("dash", float(o.get("dash", 0.0)))
	mi(meshes["Ring"], m, xf)


func add_sky(pal: Dictionary, feature: int, fdir: Vector3, famt: float = 1.0) -> void:
	var m := mat("sky")
	m.set_shader_parameter("n0", pal["n0"])
	m.set_shader_parameter("n1", pal["n1"])
	m.set_shader_parameter("n2", pal["n2"])
	m.set_shader_parameter("paper", EData.PAPER)
	m.set_shader_parameter("neb_amt", float(P["nebula"]))
	m.set_shader_parameter("star_amt", 1.0)
	m.set_shader_parameter("seed_off", seed_vec() * 0.05)
	m.set_shader_parameter("feature", feature)
	m.set_shader_parameter("feat_dir", fdir)
	m.set_shader_parameter("feat_amt", famt)
	var n := mi(meshes["Planet"], m, Transform3D(Basis().scaled(Vector3.ONE * 1500.0), cam.position))
	n.extra_cull_margin = 4000.0


func sky_feature_dir(avoid: Vector2) -> Vector3:
	for i in 12:
		var u := rf(-0.75, 0.75)
		var v := rf(-0.6, 0.65)
		if Vector2(u, v).distance_to(avoid) > 0.75:
			return screen_dir(u, v)
	return screen_dir(-avoid.x * 0.7, 0.4)


func lore_planet(arch: int) -> void:
	var A: Dictionary = EData.ARCHETYPES[arch]
	info["title"] = ELore.gen_name(rng)
	info["cn"] = ELore.gen_cn_name(rng)
	info["catalog"] = ELore.catalog_id(rng)
	info["epithet"] = ELore.pick(rng, ELore.EPITHETS[arch])
	info["kind"] = "%s · %s" % [A["name"], A["en"]]
	info["hook"] = ELore.pick(rng, ELore.HOOKS)
	info["gameplay"] = ELore.GAMEPLAY[arch]


func add_stats(R_earth: float) -> void:
	var dread := clampi(int(round(1.0 + float(P["madness"]) * 1.5 + float(P["corruption"]) * 1.2 + float(P["eyes"]) * 0.8 + float(P["tentacles"]) * 0.8 + rf(-0.4, 0.6))), 1, 5)
	info["stats"] = [
		["半径", "%.2f R⊕" % R_earth],
		["自转周期", "%d 小时" % ri(7, 900) if chance(0.8) else "不规则"],
		["表面重力", "%.2f g" % rf(0.2, 3.5)],
		["地表温度", "%d °C" % ri(-230, 460)],
		["理智侵蚀", "★".repeat(dread) + "☆".repeat(5 - dread)],
		["威胁等级", ["可观测", "警戒", "禁区", "封印", "不可名状"][clampi(dread - 1 + ri(-1, 0), 0, 4)]],
	]


# ------------------------------------------------------------------ 0. planet portrait
func _build_portrait() -> void:
	var comp := int(P["composition"])
	if comp == 0:
		# 三分构图 / 远景已移除；只在居中(1)、巨构地平线(2)、日蚀逆光(3) 里抽
		var pool := [1, 2, 3]
		comp = int(pool[wpick([3.0, 1.4, 1.6])])
	var arch := pick_arch(int(P["archetype"]))
	var pid := pick_pal(arch, int(P["palette"]))
	var pal := EData.pal_colors(pid)
	var long_x := aspect >= 1.0
	var short_h := minf(hx, hy)
	var C := Vector3.ZERO
	var R := short_h * 0.62
	var L := Vector3(rf(0.55, 1.0) * (1.0 if chance(0.5) else -1.0), rf(0.1, 0.55), rf(0.25, 0.8))
	match comp:
		2:  # 巨构地平线
			R = short_h * 4.2
			C = Vector3(rf(-0.15, 0.15) * hx, -R - short_h * (0.25 if long_x else 0.0) - (0.0 if long_x else hy * 0.35), -R * 0.35)
			L = Vector3(rf(0.5, 1.0) * (1.0 if chance(0.5) else -1.0), rf(0.45, 0.9), rf(0.25, 0.7))
		3:  # 日蚀逆光
			R = short_h * 0.6
			C = Vector3(0, 0, 0)
	var star_behind := Vector3.ZERO
	if comp == 3:
		star_behind = C + Vector3(rf(-0.32, 0.32) * R, rf(0.0, 0.3) * R, -32.0)
		L = (star_behind - C).normalized()
	setup_light(L, pal)
	var glyphs := float(P["glyphs"])
	var has_ring := false
	var rp := int(P["rings"])
	if rp == 1:
		has_ring = true
	elif rp == 0:
		has_ring = comp != 2 and chance(0.38)
	sub(8)
	var hero := add_planet(C, R, arch, pid, {"glyphs": glyphs, "corruption": float(P["corruption"]), "eyes": float(P["eyes"]) * (0.6 if arch == 1 else 1.0), "ring": has_ring})
	info["focus"] = C
	sub(9)
	lore_planet(arch)
	add_stats(R * rf(0.8, 3.5))
	info["type"] = "星球立绘"
	info["pal"] = pid
	info["bodies"].append({"name": info["title"], "kind": EData.ARCHETYPES[arch]["name"]})

	var avoid := to_screen(C)
	sub(1)
	# sky
	var feat := wpick([4.0, 2.0, 1.6, 1.0 + float(P["eyes"]) * 3.0])
	add_sky(pal, feat, sky_feature_dir(avoid), rf(0.7, 1.0))
	sub(2)
	# eclipse star / companion star
	if comp == 3:
		var st := wpick([3.0, 1.2, 0.8, 1.0, 0.0])
		add_star(star_behind, 3.0, st, pal, 1.3)
	elif chance(0.4):
		for i in 8:
			var u := rf(-0.85, 0.85)
			var v := rf(-0.75, 0.8)
			if Vector2(u, v).distance_to(avoid) > 0.9 or comp == 2 and v > 0.0:
				add_star(screen_pt(u, v, -70.0), rf(0.5, 1.0), wpick([3.0, 1.0, 1.0, 1.0, 0.4]), pal, rf(0.6, 0.9))
				break
	sub(3)
	# moons
	var nm := int(P["count"])
	if nm < 0:
		nm = ri(0, 3) if comp != 2 else ri(1, 3)
	for i in nm:
		var march := wpick([0.4, 0.5, 0.2, 0.6, 0.6, 0.8, 0.5, 0.3, 0.2, 0.3, 2.2])
		var mpid := pid if chance(0.55) else rng.randi() % EData.PALETTES.size()
		var mp := Vector3.ZERO
		var mr := 0.0
		var ok := false
		for tries in 16:
			if comp == 2:
				mr = rf(0.3, 1.2)
				mp = screen_pt(rf(-0.85, 0.85), rf(0.15, 0.8), rf(-10.0, -25.0))
				mr *= (D - mp.z) / D * 0.35
			else:
				mr = R * rf(0.1, 0.26)
				var a := rf(0, TAU)
				mp = C + Vector3(cos(a), sin(a), 0) * R * rf(1.45, 2.4) + Vector3(0, 0, rf(-4.0, 2.5))
			var s := to_screen(mp)
			if absf(s.x) < 0.88 and absf(s.y) < 0.85:
				ok = true
				break
		if not ok:
			continue
		var mo := add_planet(mp, mr, march, mpid, {"glyphs": glyphs * 0.5, "eyes": float(P["eyes"]) * 0.5, "atmo_k": 0.6})
		var mname := "%s %s" % [info["title"], ELore.roman(i + 1)]
		info["bodies"].append({"name": mname, "kind": "卫星 · " + EData.ARCHETYPES[march]["name"]})
		if true:
			labels.append({"pos": mp + Vector3(0, -mr * 1.25, 0), "text": mname, "sub": EData.ARCHETYPES[march]["name"]})
	sub(4)
	# sigil
	if glyphs >= 0.5 and chance(0.75):
		if not has_ring and chance(0.5):
			var b := Basis(Vector3(0, 0, 1), deg_to_rad(rf(-25, 25))) * Basis(Vector3(1, 0, 0), deg_to_rad(rf(12, 24)))
			add_ringfx(Transform3D(b.scaled(Vector3.ONE * R * rf(1.5, 1.9)), C), 1, pal["c4"], pal["atmo"], {"intensity": 0.9})
		elif comp != 2:
			var b2 := Basis(Vector3(1, 0, 0), PI * 0.5)
			add_ringfx(Transform3D(b2.scaled(Vector3.ONE * R * rf(1.35, 1.6)), C - Vector3(0, 0, R * 1.5)), 1, pal["c4"], pal["iris"], {"intensity": 0.85})
	sub(5)
	# tentacles
	var nt := int(round(float(P["tentacles"]) * 9.0))
	for i in nt:
		if comp == 2:
			var u := lerpf(-0.9, 0.9, (float(i) + rf(0.2, 0.8)) / float(nt))
			var top := C.y + R
			var base := Vector3(u * hx * 1.6, top - 0.6, C.z + R * 0.45 + rf(-1.5, 2.0))
			base.y = C.y + sqrt(maxf(R * R - pow(base.x - C.x, 2) - pow(base.z - C.z, 2), 0.0)) - 0.4
			var up := Vector3(rf(-0.35, 0.35) - u * 0.2, 1.0, rf(-0.15, 0.25))
			add_tentacle(base, basis_from_y(up, Vector3(1 if chance(0.5) else -1, 0, 0.2)), short_h * rf(0.9, 1.7), pal)
		else:
			var a := float(i) / float(nt) * TAU + rf(-0.4, 0.4) + 0.7
			var rad := Vector3(cos(a), sin(a), 0)
			var base := C + rad * R * 0.5 + Vector3(0, 0, -R * 0.75)
			var dir := (rad + Vector3(0, 0, rf(0.1, 0.4))).normalized()
			var side := Vector3(0, 0, 1).cross(dir) * (1.0 if chance(0.5) else -1.0)
			add_tentacle(base, basis_from_y(dir, side + Vector3(0, 0, rf(-0.3, 0.3))), R * rf(1.3, 2.3), pal)
	sub(6)
	# foreground debris
	if comp != 2 and chance(0.55):
		var nd := ri(2, 5)
		for i in nd:
			var u := rf(0.62, 1.0) * (1.0 if chance(0.5) else -1.0)
			var v := rf(-0.95, 0.95)
			var z := rf(2.0, 5.0)
			var p := screen_pt(u, v, z)
			var s := rf(0.08, 0.3)
			add_prop("Rock%d" % ri(0, 3), Transform3D(Basis.from_euler(Vector3(rf(0, TAU), rf(0, TAU), rf(0, TAU))).scaled(Vector3.ONE * s), p), pal, {"crack": rf(0.0, 0.8), "shade": 0.8})
	sub(7)
	if glyphs > 0.4 and chance(0.6):
		var p := screen_pt(rf(0.55, 0.85) * (1.0 if chance(0.5) else -1.0), rf(-0.7, 0.4), rf(1.0, 4.0))
		var s := rf(0.35, 0.6)
		add_prop("Monolith", Transform3D(Basis.from_euler(Vector3(rf(-0.4, 0.4), rf(0, TAU), rf(-0.5, 0.5))).scaled(Vector3.ONE * s), p), pal, {"glyph": glyphs, "flat": 1.0, "gs": 11.0})
	if comp != 2:
		labels.append({"pos": C + Vector3(0, -R * 1.12, 0), "text": info["title"], "sub": EData.ARCHETYPES[arch]["name"], "main": true})


# ------------------------------------------------------------------ 1. system map
func _build_system() -> void:
	var st := int(P["star_type"])
	if st < 0:
		st = wpick([3.5, 1.8, 1.6, 1.2, 1.0])
	var pid := int(P["palette"]) if int(P["palette"]) >= 0 else rng.randi() % EData.PALETTES.size()
	var pal := EData.pal_colors(pid)
	var np := int(P["count"])
	if np < 0:
		np = ri(4, 7)
	np = clampi(np, 1, 8)
	var el := deg_to_rad(rf(22.0, 34.0))
	var radii := []
	var r := rf(2.3, 2.7)
	for i in np:
		radii.append(r)
		r += rf(1.15, 1.55) + float(i) * 0.08
	var rmax: float = radii[np - 1] + 0.6
	var t := tan(deg_to_rad(FOV * 0.5))
	var kx := hx / D
	var ky := hy / D
	var dist := maxf(rmax * 1.04 / kx, (rmax * sin(el) * 1.08 + 0.9) / ky)
	dist = maxf(dist, 8.0)
	var look := Vector3(0, -rmax * 0.04, 0)
	cam.transform = Transform3D(Basis(), Vector3(0, sin(el), cos(el)) * dist).looking_at(look, Vector3.UP)
	# helpers for to_screen no longer valid; labels use projection in UI
	light["point"] = 1.0
	light["pos"] = Vector3.ZERO
	light["dir"] = Vector3(0, 1, 0)
	var lc: Color = pal["star_hot"]
	light["col"] = Color(1, 1, 1).lerp(lc, 0.45) * (0.6 if st == 1 or st == 4 else 1.1)
	if st == 1:
		light["col"] = Color(1, 1, 1).lerp(pal["c4"], 0.6) * 0.9
	light["amb"] = darker(pal["n1"], 0.1).lerp(Color(0.02, 0.02, 0.03), 0.5)
	light["rim_dir"] = Vector3(0, 1, -0.3).normalized()
	light["rim_col"] = pal["rim"]
	light["rim_amt"] = 0.25
	add_sky(pal, wpick([3.0, 1.5, 1.5, float(P["eyes"]) * 2.0]), Vector3(rf(-0.5, 0.5), rf(0.1, 0.5), -1).normalized(), rf(0.6, 0.9))
	var star_r := rf(0.7, 1.0)
	add_star(Vector3.ZERO, star_r, st, pal, 0.6, 1.5)
	info["focus"] = Vector3.ZERO
	var sname := ELore.gen_name(rng)
	info["title"] = "%s 星系" % sname
	info["cn"] = ELore.gen_cn_name(rng) + "星系"
	info["catalog"] = ELore.catalog_id(rng)
	info["epithet"] = "中心天体：" + EData.STAR_TYPES[st]["name"]
	info["kind"] = "星系图 · %s" % EData.STAR_TYPES[st]["en"]
	info["hook"] = ELore.pick(rng, ELore.SYSTEM_HOOKS)
	info["type"] = "星系图"
	info["pal"] = pid
	info["bodies"].append({"name": sname, "kind": "主星 · " + EData.STAR_TYPES[st]["name"]})
	var glyphs := float(P["glyphs"])
	if glyphs > 0.25:
		add_ringfx(Transform3D(Basis().scaled(Vector3.ONE * star_r * rf(2.0, 2.6)), Vector3.ZERO), 1, pal["c4"], pal["atmo"], {"intensity": 0.6 + glyphs * 0.5})
	var belt_i := ri(1, maxi(np - 2, 1))
	for i in np:
		sub(100 + i)
		var orad: float = radii[i]
		var dash := 0.0 if chance(0.65) else 90.0
		add_ringfx(Transform3D(Basis().scaled(Vector3.ONE * orad / 0.985), Vector3.ZERO), 0, pal["atmo"].lerp(Color(1, 1, 1), 0.2), pal["atmo"], {"intensity": 0.42, "px": 1.2, "dash": dash})
		var arch := pick_arch(-1, [])
		if int(P["archetype"]) >= 0 and i == np / 2:
			arch = int(P["archetype"])
		var ppid := pick_pal(arch, -1) if chance(0.75) else pid
		var pr := rf(0.36, 0.55)
		if arch in [8, 6, 0, 7] and chance(0.6):
			pr = rf(0.55, 0.75)
		var ang := rf(0, TAU)
		var pos := Vector3(cos(ang) * orad, 0, sin(ang) * orad)
		var pl := add_planet(pos, pr, arch, ppid, {"glyphs": glyphs * 0.7, "corruption": float(P["corruption"]) * rf(0.3, 1.0), "eyes": float(P["eyes"]) * rf(0.3, 1.0), "ring": (int(P["rings"]) == 0 and chance(0.22)) or (int(P["rings"]) == 1 and (chance(0.4) or i == np - 2)), "atmo_k": 0.8, "ring_basis": Basis(Vector3(1, 0, 0), deg_to_rad(rf(-25, 25))) * Basis(Vector3(0, 0, 1), deg_to_rad(rf(-20, 20)))})
		var pname := "%s %s" % [sname, ELore.roman(i + 1)]
		info["bodies"].append({"name": pname, "kind": EData.ARCHETYPES[arch]["name"]})
		if true:
			labels.append({"pos": pos + Vector3(0, -pr * 1.4, 0), "text": pname, "sub": EData.ARCHETYPES[arch]["name"]})
		# a moon
		if pr > 0.35 and chance(0.4):
			var ma := rf(0, TAU)
			add_planet(pos + Vector3(cos(ma), rf(-0.2, 0.3), sin(ma)) * pr * rf(1.8, 2.4), pr * rf(0.18, 0.3), 10, ppid, {"atmo_k": 0.0})
		if i == belt_i and i + 1 < np:
			var br0: float = orad + 0.35
			var br1: float = radii[i + 1] - 0.35
			if br1 > br0 + 0.2:
				add_belt(Vector3.ZERO, Basis(), br0, br1, 420, 0.05, pal, 0.08)
	sub(200)
	# outer debris ring
	add_belt(Vector3.ZERO, Basis(), rmax + 0.2, rmax + 1.2, 360, 0.04, pal, 0.15)
	sub(201)
	# tentacles from the star
	var nt := int(round(float(P["tentacles"]) * 7.0))
	for i in nt:
		var a := float(i) / float(nt) * TAU + rf(-0.3, 0.3)
		var dir := Vector3(cos(a), rf(-0.1, 0.5), sin(a)).normalized()
		add_tentacle(dir * star_r * 0.6, basis_from_y(dir, Vector3(0, 1, 0).cross(dir)), rf(2.5, 4.5), pal, {"glow": 1.0})
	sub(202)
	info["stats"] = [
		["行星数量", "%d" % np],
		["主星", EData.STAR_TYPES[st]["name"]],
		["星系年龄", "%.1f 亿年" % rf(3.0, 140.0)],
		["轨道异常", ["无", "轻微", "显著", "违背几何"][ri(0, 3)]],
		["已知信徒", ["无", "零星", "教团", "全星系"][ri(0, 3)]],
	]
	info["gameplay"] = "可作为章节大地图：每颗行星对应一个关卡/据点，轨道相位决定可航行窗口；中心天体可作为终局。"


# ------------------------------------------------------------------ 2. wonders
func _build_wonder() -> void:
	var w := int(P["wonder"])
	if w < 0:
		w = ri(0, EData.WONDERS.size() - 1)
	var arch := pick_arch(int(P["archetype"]))
	var pid := pick_pal(arch, int(P["palette"]))
	var pal := EData.pal_colors(pid)
	var short_h := minf(hx, hy)
	var L := Vector3(rf(0.55, 1.0) * (1.0 if chance(0.5) else -1.0), rf(0.2, 0.6), rf(0.3, 0.8))
	setup_light(L, pal)
	var glyphs := float(P["glyphs"])
	var W: Dictionary = EData.WONDERS[w]
	info["title"] = "%s · %s" % [ELore.gen_name(rng), W["en"]]
	info["cn"] = W["name"]
	info["catalog"] = ELore.catalog_id(rng)
	info["kind"] = "星际奇景 · " + W["name"]
	info["hook"] = ELore.pick(rng, ELore.WONDER_HOOKS)
	info["type"] = "星际奇景"
	info["pal"] = pid
	info["stats"] = []
	var nt := int(round(float(P["tentacles"]) * 8.0))
	sub(300 + w)
	match w:
		0:
			_wonder_gate(pal, pid, arch, short_h, glyphs, nt)
		1:
			_wonder_maw(pal, pid, arch, short_h, glyphs, nt)
		2:
			_wonder_rift(pal, pid, arch, short_h, glyphs, nt)
		3:
			_wonder_eye(pal, pid, arch, short_h, glyphs, nt)
		4:
			_wonder_ruins(pal, pid, arch, short_h, glyphs, nt)
		_:
			_wonder_tendrils(pal, pid, arch, short_h, glyphs, nt)
	sub(399)
	var dread := clampi(int(round(2.0 + float(P["madness"]) * 1.5 + float(P["tentacles"]) + float(P["eyes"]))), 1, 5)
	info["stats"].append(["理智侵蚀", "★".repeat(dread) + "☆".repeat(5 - dread)])
	info["stats"].append(["空间曲率", ["正常", "轻度扭曲", "非欧几里得", "自我指涉"][ri(0, 3)]])
	info["stats"].append(["首次记录", "%d 年" % ri(1690, 2340)])


func _bg_planet(pal_id: int, arch: int, u: float, v: float, z: float, r: float, o: Dictionary = {}) -> Dictionary:
	return add_planet(screen_pt(u, v, z), r, arch, pal_id, o)


func _debris(pal: Dictionary, n: int, zmin: float, zmax: float, smin: float, smax: float, crack: float = 0.4) -> void:
	for i in n:
		var p := screen_pt(rf(-1.0, 1.0), rf(-0.95, 0.95), rf(zmin, zmax))
		var s := rf(smin, smax)
		add_prop("Rock%d" % ri(0, 3), Transform3D(Basis.from_euler(Vector3(rf(0, TAU), rf(0, TAU), rf(0, TAU))).scaled(Vector3.ONE * s), p), pal, {"crack": rf(0, crack)})


func _wonder_gate(pal: Dictionary, pid: int, arch: int, sh: float, glyphs: float, nt: int) -> void:
	var gs := sh * 0.62
	var C := Vector3(0, sh * 0.02, -1.0)
	var b := Basis(Vector3(0, 1, 0), deg_to_rad(rf(-32, 32))) * Basis(Vector3(1, 0, 0), deg_to_rad(rf(-12, 8))) * Basis(Vector3(0, 0, 1), deg_to_rad(rf(-12, 12)))
	add_prop("Gate", Transform3D(b.scaled(Vector3.ONE * gs), C), pal, {"glyph": maxf(glyphs, 0.35), "crack": 0.3, "flat": 1.0, "gs": 8.0, "ns": 1.5})
	var pm := mat("portal")
	pm.set_shader_parameter("col_a", pal["c4"])
	pm.set_shader_parameter("col_b", pal["n2"].lerp(pal["cor_glow"], 0.4))
	pm.set_shader_parameter("col_c", pal["iris"])
	pm.set_shader_parameter("seed", rf(0, 50))
	pm.set_shader_parameter("eye_amt", clampf(float(P["eyes"]) * 1.5, 0.0, 1.0))
	mi(quad, pm, Transform3D(b.scaled(Vector3.ONE * gs * 1.9), C))
	add_sky(pal, wpick([2.0, 2.0, 1.0, 1.0]), sky_feature_dir(Vector2.ZERO), 0.8)
	var bp := _bg_planet(pid, arch, rf(0.5, 0.75) * (1.0 if chance(0.5) else -1.0), rf(0.2, 0.55), -30.0, rf(4.0, 8.0), {"glyphs": glyphs * 0.5, "eyes": float(P["eyes"]) * 0.5})
	add_belt(C, b * Basis(Vector3(1, 0, 0), PI * 0.5), gs * 1.4, gs * 2.6, 260, 0.08, pal, 0.25)
	if glyphs > 0.2:
		add_ringfx(Transform3D((b * Basis(Vector3(1, 0, 0), PI * 0.5)).scaled(Vector3.ONE * gs * 1.6), C - b.z * 0.3), 1, pal["c4"], pal["iris"], {"intensity": 0.5 + glyphs * 0.5})
	for i in 6:
		var a := float(i) / 6.0 * TAU + rf(-0.2, 0.2)
		var p := C + b * Vector3(cos(a) * gs * 1.85, sin(a) * gs * 1.85, rf(-0.4, 0.4))
		add_prop("Monolith", Transform3D(Basis.from_euler(Vector3(rf(-0.3, 0.3), rf(0, TAU), a - PI * 0.5 + rf(-0.2, 0.2))).scaled(Vector3.ONE * gs * 0.24), p), pal, {"glyph": glyphs, "flat": 1.0, "gs": 11.0})
	for i in nt:
		var a := float(i) / float(maxi(nt, 1)) * TAU + rf(-0.3, 0.3)
		var dir := b * Vector3(cos(a) * 0.8, sin(a) * 0.8, 0.6)
		add_tentacle(C + b * Vector3(cos(a), sin(a), 0) * gs * 0.3 - b.z * 0.2, basis_from_y(dir, b * Vector3(-sin(a), cos(a), 0)), gs * rf(1.1, 1.9), pal, {"glow": 1.0})
	_debris(pal, ri(3, 6), 2.0, 6.0, 0.08, 0.3)
	info["focus"] = C
	info["epithet"] = "通往%s的门扉" % EData.ARCHETYPES[bp["arch"]]["name"]
	info["gameplay"] = "可作为跨星域传送节点/副本入口；门扉开启度可与剧情进度或理智值绑定。"
	info["stats"].append(["门扉直径", "%d km" % ri(40, 9000)])
	info["bodies"].append({"name": info["title"], "kind": "星门"})


func _wonder_maw(pal: Dictionary, pid: int, arch: int, sh: float, glyphs: float, nt: int) -> void:
	var r := sh * rf(0.2, 0.26)
	var C := screen_pt(rf(-0.15, 0.15), rf(-0.05, 0.1), -2.0)
	light["point"] = 1.0
	light["pos"] = C
	light["col"] = Color(1, 0.9, 0.75).lerp(pal["star_hot"], 0.5) * 1.2
	add_sky(pal, wpick([1.0, 3.0, 1.0, 1.0]), sky_feature_dir(to_screen(C)), 1.0)
	add_star(C, r, 4, pal, 1.2)
	add_belt(C, Basis(Vector3(1, 0, 0), deg_to_rad(12)), r * 4.6, r * 7.0, 360, 0.06, pal, 0.1)
	var side := 1.0 if chance(0.5) else -1.0
	var vp := add_planet(screen_pt(side * rf(0.55, 0.75), rf(-0.45, 0.2), 1.5), sh * rf(0.13, 0.2), arch, pid, {"glyphs": glyphs, "corruption": maxf(float(P["corruption"]), 0.35), "eyes": float(P["eyes"])})
	info["bodies"].append({"name": ELore.gen_name(rng), "kind": "被吞噬者 · " + EData.ARCHETYPES[arch]["name"]})
	for i in nt:
		var a := float(i) / float(maxi(nt, 1)) * TAU + rf(-0.3, 0.3)
		var dir := Vector3(cos(a), sin(a), rf(0.1, 0.5)).normalized()
		add_tentacle(C + dir * r * 0.5, basis_from_y(dir, Vector3(0, 0, 1).cross(dir)), r * rf(3.5, 6.0), pal, {"glow": 1.0, "shade": 0.9})
	if glyphs > 0.3:
		add_ringfx(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5).scaled(Vector3.ONE * r * 6.5), C - Vector3(0, 0, 4)), 1, pal["c4"], pal["cor_glow"], {"intensity": 0.25 + glyphs * 0.35})
	_debris(pal, ri(3, 7), 0.0, 4.5, 0.05, 0.2, 0.8)
	info["focus"] = C
	info["epithet"] = "吞噬群星的无光之喉"
	info["gameplay"] = "可作为终局 Boss 场景或倒计时灾变：引力范围逐回合扩大，玩家需在被吞噬前完成目标。"
	info["stats"].append(["事件视界", "%d 万 km" % ri(3, 900)])
	info["bodies"].push_front({"name": info["title"], "kind": "吞星之口"})


func _wonder_rift(pal: Dictionary, pid: int, arch: int, sh: float, glyphs: float, nt: int) -> void:
	var C := screen_pt(rf(-0.25, 0.25), rf(0.0, 0.2), -6.0)
	var rh := sh * 1.6
	var rot := deg_to_rad(rf(-25, 25))
	add_sky(pal, 1, (C - cam.position).normalized(), 1.0)
	var rm := mat("rift")
	rm.set_shader_parameter("edge_col", pal["c4"])
	rm.set_shader_parameter("inner_col", pal["cor_glow"].lerp(pal["n2"], 0.4))
	rm.set_shader_parameter("eye_col", pal["iris"])
	rm.set_shader_parameter("seed", rf(0, 50))
	rm.set_shader_parameter("open_amt", rf(0.7, 1.15))
	rm.set_shader_parameter("eyes", clampf(0.4 + float(P["eyes"]), 0.0, 1.0))
	mi(quad, rm, Transform3D(Basis(Vector3(0, 0, 1), rot).scaled(Vector3(rh * 1.2, rh * 2.0, 1.0)), C))
	var axis := Basis(Vector3(0, 0, 1), rot) * Vector3(0, 1, 0)
	for i in nt:
		var tt := rf(-0.6, 0.6)
		var base := C + axis * tt * rh * 0.8 - Vector3(0, 0, 0.5)
		var side := 1.0 if i % 2 == 0 else -1.0
		var dir := (Basis(Vector3(0, 0, 1), rot) * Vector3(side, rf(-0.4, 0.4), 0.0) + Vector3(0, 0, rf(0.4, 0.9))).normalized()
		add_tentacle(base, basis_from_y(dir, Vector3(0, -side, 0)), sh * rf(1.0, 2.0), pal, {"glow": 1.0})
	# foreground planet horizon
	var R := sh * 3.0
	var hp := add_planet(Vector3(rf(-0.3, 0.3) * hx, -R - sh * 0.55, -R * 0.4), R, arch, pid, {"glyphs": glyphs, "corruption": float(P["corruption"]), "eyes": float(P["eyes"]) * 0.6})
	_debris(pal, ri(5, 9), -4.0, 5.0, 0.08, 0.35, 0.8)
	info["focus"] = C
	info["epithet"] = "现实帷幕上的伤口"
	info["gameplay"] = "裂隙可作为敌人刷新点或异界入口；裂隙开合度随时间/仪式进度改变。"
	info["stats"].append(["裂隙长度", "%d 光秒" % ri(2, 600)])
	info["bodies"].append({"name": info["title"], "kind": "虚空裂隙"})
	info["bodies"].append({"name": ELore.gen_name(rng), "kind": "下方行星 · " + EData.ARCHETYPES[arch]["name"]})


func _wonder_eye(pal: Dictionary, pid: int, arch: int, sh: float, glyphs: float, nt: int) -> void:
	var C := Vector3(0, sh * 0.05, -3.0)
	var r := sh * 0.32
	add_sky(pal, 3, screen_dir(rf(-0.2, 0.2), rf(0.25, 0.5)), 1.0)
	add_star(C, r, 2, pal, 0.55)
	setup_light((Vector3(0, 0.2, 1)).normalized(), pal)
	light["col"] = Color(1, 1, 1).lerp(pal["iris"], 0.4)
	var b := Basis(Vector3(0, 0, 1), deg_to_rad(rf(-15, 15))) * Basis(Vector3(1, 0, 0), deg_to_rad(rf(10, 22)))
	var n := ri(9, 13)
	for i in n:
		var a := float(i) / float(n) * TAU
		var p := C + b * Vector3(cos(a), 0, sin(a)) * r * 2.6
		add_prop("Monolith", Transform3D(b * Basis(Vector3(0, 1, 0), -a).scaled(Vector3.ONE * r * 0.32), p), pal, {"glyph": maxf(glyphs, 0.5), "flat": 1.0, "gs": 11.0})
	add_ringfx(Transform3D(b.scaled(Vector3.ONE * r * 2.25), C), 1, pal["c4"], pal["iris"], {"intensity": 0.7 + glyphs * 0.4})
	add_ringfx(Transform3D(b.scaled(Vector3.ONE * r * 3.1 / 0.985), C), 0, pal["atmo"], pal["atmo"], {"intensity": 0.5, "dash": 120.0})
	for i in nt:
		var a := float(i) / float(maxi(nt, 1)) * TAU + rf(-0.3, 0.3)
		var dir := Vector3(cos(a), sin(a), rf(-0.1, 0.3)).normalized()
		add_tentacle(C + dir * r * 0.7, basis_from_y(dir, Vector3(0, 0, 1).cross(dir)), r * rf(2.5, 4.0), pal, {"glow": 1.0})
	var side := 1.0 if chance(0.5) else -1.0
	add_planet(screen_pt(side * 0.7, -0.55, 2.0), sh * 0.22, arch, pid, {"glyphs": glyphs, "eyes": float(P["eyes"]) * 0.5, "corruption": float(P["corruption"])})
	_debris(pal, ri(2, 5), 1.0, 6.0, 0.06, 0.22)
	info["focus"] = C
	info["epithet"] = "在群星之外，注视着注视者"
	info["gameplay"] = "可作为全局“被注视”机制的来源：玩家行动会累积其关注度，达到阈值触发事件。"
	info["stats"].append(["视线范围", "约 %d 光年" % ri(3, 400)])
	info["bodies"].append({"name": info["title"], "kind": "宇宙之眼"})


func _wonder_ruins(pal: Dictionary, pid: int, arch: int, sh: float, glyphs: float, nt: int) -> void:
	var C := screen_pt(rf(-0.1, 0.1), rf(-0.2, 0.0), 0.0)
	var s := sh * 0.55
	add_sky(pal, wpick([2.0, 1.0, 1.0, 1.0]), sky_feature_dir(Vector2(0, -0.1)), 0.8)
	var R := sh * 2.4
	var side := 1.0 if chance(0.5) else -1.0
	add_planet(screen_pt(side * rf(0.45, 0.7), rf(0.25, 0.55), -18.0), sh * rf(1.3, 1.9), arch, pid, {"glyphs": glyphs * 0.6, "eyes": float(P["eyes"]) * 0.5, "corruption": float(P["corruption"])})
	add_prop("Ruins", Transform3D((Basis(Vector3(1, 0, 0), deg_to_rad(rf(10, 22))) * Basis(Vector3(0, 1, 0), rf(0, TAU))).scaled(Vector3.ONE * s), C), pal, {"glyph": maxf(glyphs, 0.3), "crack": 0.4, "flat": 1.0, "gs": 10.0, "ns": 1.2})
	for i in ri(3, 5):
		var p := C + Vector3(rf(-2.5, 2.5) * s, rf(-0.4, 1.2) * s, rf(-2.0, 1.0) * s)
		var ss := s * rf(0.15, 0.3)
		add_prop("Ruins", Transform3D(Basis.from_euler(Vector3(rf(-0.4, 0.4), rf(0, TAU), rf(-0.3, 0.3))).scaled(Vector3.ONE * ss), p), pal, {"glyph": glyphs, "crack": 0.3, "flat": 1.0, "gs": 10.0})
	for i in ri(3, 6):
		var p := C + Vector3(rf(-2.0, 2.0) * s, rf(0.3, 1.5) * s, rf(-1.5, 1.5) * s)
		add_prop("Monolith", Transform3D(Basis.from_euler(Vector3(rf(-0.5, 0.5), rf(0, TAU), rf(-0.6, 0.6))).scaled(Vector3.ONE * s * rf(0.12, 0.25)), p), pal, {"glyph": maxf(glyphs, 0.4), "flat": 1.0, "gs": 11.0})
	if glyphs > 0.3:
		add_ringfx(Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(rf(8, 20))).scaled(Vector3.ONE * s * 1.8), C - Vector3(0, s * 0.35, 0)), 1, pal["c4"], pal["iris"], {"intensity": 0.6})
	for i in nt:
		var p := C + Vector3(rf(-0.8, 0.8) * s, -s * 0.7, rf(-0.3, 0.3) * s)
		var dir := Vector3(rf(-0.6, 0.6), -1.0, rf(0.0, 0.5)).normalized()
		add_tentacle(p, basis_from_y(dir, Vector3(1 if chance(0.5) else -1, 0, 0)), s * rf(1.2, 2.2), pal, {"glow": 0.8})
	_debris(pal, ri(6, 10), -3.0, 6.0, 0.06, 0.3)
	info["focus"] = C
	info["epithet"] = "古老者遗弃的天空之城"
	info["gameplay"] = "适合作为探索/解谜关卡：遗迹之间以漂浮碎石相连，石碑铭文可拼出隐藏剧情。"
	info["stats"].append(["遗迹规模", "%d 座塔楼" % ri(7, 300)])
	info["bodies"].append({"name": info["title"], "kind": "浮空遗迹"})


func _wonder_tendrils(pal: Dictionary, pid: int, arch: int, sh: float, glyphs: float, nt: int) -> void:
	var C := Vector3(rf(-0.1, 0.1) * hx, rf(-0.1, 0.05) * hy, -1.0)
	var R := sh * 0.45
	add_sky(pal, 1, screen_dir(rf(-0.4, 0.4), rf(0.2, 0.5)), 1.0)
	var pl := add_planet(C, R, arch, pid, {"glyphs": glyphs, "corruption": maxf(float(P["corruption"]), 0.4), "eyes": float(P["eyes"])})
	var n := maxi(nt, 5)
	for i in n:
		var a := float(i) / float(n) * TAU + rf(-0.25, 0.25)
		var rad := Vector3(cos(a), sin(a), 0)
		var base := C + rad * R * rf(0.3, 0.6) + Vector3(0, 0, -R * 0.85)
		var dir := (rad + Vector3(0, 0, rf(0.3, 0.9))).normalized()
		var side := Vector3(0, 0, 1).cross(dir)
		add_tentacle(base, basis_from_y(dir, -side), R * rf(2.0, 3.0), pal, {"curl": rf(2.8, 4.5), "thick": rf(1.1, 1.5), "glow": 1.0})
	for i in ri(2, 4):
		var a := rf(0, TAU)
		var dir := Vector3(cos(a), sin(a), rf(0.6, 1.0)).normalized()
		add_tentacle(C + Vector3(cos(a), sin(a), 0) * R * 0.5 + Vector3(0, 0, R * 0.2), basis_from_y(dir, Vector3(0, 0, 1).cross(dir)), R * rf(1.4, 2.0), pal, {"curl": rf(1.5, 2.5), "thick": 1.0})
	_debris(pal, ri(3, 6), 1.0, 6.5, 0.06, 0.3)
	info["focus"] = C
	info["epithet"] = "被旧日支配者握在掌中的世界"
	info["gameplay"] = "可作为章节 Boss 关：触手为可破坏的部位，每断一根解锁星球的一个区域。"
	info["stats"].append(["触须跨度", "%d 万 km" % ri(4, 300)])
	info["bodies"].append({"name": info["title"], "kind": "星海巨触"})
	info["bodies"].append({"name": ELore.gen_name(rng), "kind": "受缚之星 · " + EData.ARCHETYPES[arch]["name"]})
