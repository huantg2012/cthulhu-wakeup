extends Control
## Two engraved ten-sided dice, painted into the 2D table. Geometry is projected
## by this Control; no 3D scene, physics, gameplay RNG or rule evaluation lives here.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
signal settled
const DURATION := 2.16
const DIE_TIMES := [1.73,2.12]
const LIGHT := Vector3(-0.42,0.66,1.0)
var elapsed := DURATION
var rolling := false
var value := 100
var sound_enabled := true
var _speed := 1.0
var _seed := 1
var _vertices: Array[Vector3] = []
var _faces: Array[Dictionary] = []
var _pose := Quaternion.IDENTITY
var _clacks: Array[AudioStreamPlayer] = []
var _impact_index := 0
var _canvas_transform := Transform2D.IDENTITY
const IMPACTS := [0.22,0.43,0.72,0.98,1.24,1.50,1.73,1.96,2.12]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shape()
	_make_sound()
	set_process(rolling)

static func final_d10(result: int) -> Vector2i:
	var number := clampi(result,1,100)%100
	return Vector2i(number/10,number%10)

func roll_to(result: int, seed_value: int = 1) -> void:
	value = clampi(result,1,100)
	_seed = seed_value
	elapsed = 0.0
	_speed = 1.0
	_impact_index = 0
	rolling = true
	set_process(true)
	queue_redraw()

func reveal() -> void:
	# Accelerate the same continuous paths, never replace the true final roll.
	if rolling: _speed = 9.0

func show_result(result: int) -> void:
	value = clampi(result,1,100)
	elapsed = DURATION
	rolling = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not rolling: return
	elapsed = minf(DURATION,elapsed+delta*_speed)
	while _impact_index<IMPACTS.size() and elapsed>=float(IMPACTS[_impact_index]):
		if _speed<2.0: _impact(_impact_index)
		_impact_index += 1
	queue_redraw()
	if elapsed>=DURATION:
		rolling = false
		set_process(false)
		settled.emit()

func _build_shape() -> void:
	if not _vertices.is_empty(): return
	var h := 1.17
	var c := h*pow(tan(PI/10.0),2.0)
	_vertices = [Vector3(0,0,h),Vector3(0,0,-h)]
	for index: int in 10:
		var angle := TAU*index/10.0
		_vertices.append(Vector3(cos(angle),sin(angle),c if index%2==0 else -c))
	for index: int in 10:
		var top := index<5
		var ring := index*2 if top else (index-5)*2+1
		var ids: Array[int] = [0 if top else 1,2+ring%10,2+(ring+1)%10,2+(ring+2)%10]
		var center := Vector3.ZERO
		for id: int in ids: center += _vertices[id]/4.0
		var normal := (_vertices[ids[1]]-_vertices[ids[0]]).cross(_vertices[ids[2]]-_vertices[ids[0]]).normalized()
		if normal.dot(center)<0: normal = -normal
		var up := (_vertices[ids[0]]-center).normalized()
		var right := up.cross(normal).normalized()
		var grains: Array[Vector3] = []
		# Barycentric material points follow the face under every rotation.
		for speck: int in 92:
			var a := _hash(index*230+speck*3)
			var b := _hash(index*230+speck*3+1)
			if a+b>1.0: a=1.0-a; b=1.0-b
			var third := 1 if speck%2==0 else 3
			grains.append(_vertices[ids[0]]*(1.0-a-b)+_vertices[ids[2]]*a+_vertices[ids[third]]*b)
		_faces.append({"ids":ids,"center":center,"normal":normal,"up":up,"right":right,"grains":grains,"number":index})
	var front: Dictionary = _faces[0]
	var base := Quaternion(front.normal,Vector3.FORWARD*-1.0)
	var heading: Vector3 = base*front.up
	_pose = Quaternion(Vector3(0,0,1),PI/2.0-atan2(heading.y,heading.x))*base
	_pose = Quaternion(Vector3.RIGHT,0.18)*Quaternion(Vector3.UP,-0.20)*_pose

static func _hash(index: int) -> float:
	return fposmod(sin(float(index)*127.13+311.71)*43758.5453,1.0)

func _draw() -> void:
	if _faces.is_empty(): return
	var scale_value := minf(size.x/360.0,size.y/185.0)
	if scale_value<=0.0: return
	_canvas_transform = Transform2D(Vector2(scale_value,0),Vector2(0,scale_value),(size-Vector2(360,185)*scale_value)*0.5)
	draw_set_transform_matrix(_canvas_transform)
	var digits := final_d10(value)
	_draw_die(0,digits.x)
	_draw_die(1,digits.y)
	draw_set_transform(Vector2.ZERO)

func _draw_die(index: int, digit: int) -> void:
	var progress := clampf(elapsed/float(DIE_TIMES[index]),0.0,1.0)
	var remaining := 1.0-progress
	var final_center := Vector2(108 if index==0 else 248,92 if index==0 else 98)
	var roll_offset := Vector2((-40.0 if index==0 else 42.0)*pow(remaining,2.0),-25.0*pow(remaining,1.3))
	var lift := absf(sin(progress*PI*(3.2 if index==0 else 3.7)))*38.0*pow(remaining,1.15)
	var center := final_center+roll_offset-Vector2(0,lift)
	var radius := 51.0*(1.0+lift*.0018)
	var twist := (TAU*2.2+float(posmod(_seed,7))*.08)*pow(remaining,2.35)
	var pose := Quaternion(Vector3(0.3,1.0,0.1).normalized(),twist)*Quaternion(Vector3(1.0,0.2,0.4).normalized(),twist*.71)*_pose
	pose = Quaternion(Vector3(0,0,1),-.09 if index==0 else .08)*pose
	var shadow_y := final_center.y+43
	for band: int in range(6,0,-1):
		var alpha := (.03 if band>2 else .06)*(1.0-lift*.009)
		var polygon := PackedVector2Array()
		for point: int in 40:
			var angle := TAU*point/40.0
			polygon.append(Vector2(center.x+cos(angle)*(48+band*2.3+lift*.18),shadow_y+sin(angle)*(8+band*1.2+lift*.09)))
		draw_colored_polygon(polygon,Color(.015,.018,.017,alpha))
	var sorted: Array[Dictionary] = []
	for face: Dictionary in _faces:
		var normal: Vector3 = pose*face.normal
		if normal.z>.015:
			var entry := face.duplicate()
			entry.normal_now = normal
			entry.depth = (pose*face.center).z
			sorted.append(entry)
	sorted.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.depth<b.depth)
	for face: Dictionary in sorted:
		_draw_face(face,pose,center,radius,index,digit)
	var caption := "十位" if index==0 else "个位"
	var font: Font = Paint.fonts().body
	var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(font,Vector2(final_center.x-width*.5,176),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(Paint.MUTED,.72))

func _project(point: Vector3, pose: Quaternion, center: Vector2, radius: float) -> Vector2:
	var p := pose*point
	var perspective := 1.0+p.z*.035
	return center+Vector2(p.x,-p.y)*radius*perspective

func _draw_face(face: Dictionary, pose: Quaternion, center: Vector2, radius: float, index: int, digit: int) -> void:
	var polygon := PackedVector2Array()
	for id: int in face.ids: polygon.append(_project(_vertices[id],pose,center,radius))
	var illumination := clampf(face.normal_now.dot(LIGHT.normalized()),0.0,1.0)
	var base := Color("c5ad82") if index==0 else Color("c5c4ae")
	var shade := base*lerpf(.47,1.04,illumination)
	shade.a = 1.0
	draw_colored_polygon(polygon,shade)
	# Edge chips and pores are fixed in material space, not screen-space noise.
	for speck: int in face.grains.size():
		var material_point: Vector3 = face.grains[speck]
		var p := _project(material_point,pose,center,radius)
		var ink := Color(.25,.19,.14,.09+_hash(speck+face.number*33)*.10)
		if speck%4==0: ink = Color(.97,.89,.69,.12)
		draw_circle(p,.30+_hash(speck*7+face.number)*.55,ink)
	var center2 := _project(face.center,pose,center,radius)
	for side: int in 4:
		var a: Vector2 = polygon[side]
		var b: Vector2 = polygon[(side+1)%4]
		var inward := (center2-(a+b)*.5).normalized()
		draw_line(a,b,Color(.19,.16,.12,.58),1.25,true)
		if illumination>.30:
			for mark: int in 3:
				var start := .08+mark*.29+_hash(face.number*20+side*5+mark)*.045
				var end := minf(.96,start+.13+_hash(mark*30+side)*.11)
				draw_line(a.lerp(b,start)+inward*1.4,a.lerp(b,end)+inward*1.4,Color(.96,.88,.70,.30*illumination),.8,true)
	# Digits belong to this facet. Their affine projection follows its tilt.
	var shown := posmod(digit+int(face.number)*3,10)
	var words := ("%02d" % (shown*10)) if index==0 else str(shown)
	var u := _project(face.center+face.right*.6,pose,center,radius)-center2
	var v := _project(face.center-face.up*.6,pose,center,radius)-center2
	if u.cross(v)<=1.0: return
	var text_transform := Transform2D(u/30.0,v/30.0,center2)
	draw_set_transform_matrix(_canvas_transform*text_transform)
	var font: Font = Paint.fonts().body
	var font_size := 29 if index==0 else 35
	var width := font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := Vector2(-width*.5,font_size*.31)
	draw_string(font,baseline+Vector2(.8,1),words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(.99,.89,.68,.37))
	draw_string(font,baseline,words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("302c27"))
	if shown in [6,9]: draw_line(Vector2(-7,16),Vector2(7,16),Color("302c27"),1.0,true)
	draw_set_transform_matrix(_canvas_transform)

func _make_sound() -> void:
	# Short, dry wood/bone contacts. Seeded locally and cached on creation;
	# never touches the game's check stream or makes a sound during inspection.
	for variant: int in 3:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var length := 1600+variant*200
		var samples := PackedByteArray()
		samples.resize(length*2)
		for sample: int in length:
			var t := float(sample)/22050.0
			var noise := (_hash(sample+variant*2207)*2.0-1.0)
			var attack := minf(1.0,t*2000.0)
			var wave := (.56*noise*exp(-t*160.0)+.27*sin(t*(1600+variant*175))*exp(-t*85.0)+.17*sin(t*6000)*exp(-t*180))*attack
			samples.encode_s16(sample*2,int(clampf(wave,-1.0,1.0)*18000))
		stream.data = samples
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -23.0
		add_child(player)
		_clacks.append(player)

func _impact(index: int) -> void:
	if not sound_enabled or _clacks.is_empty(): return
	var player: AudioStreamPlayer = _clacks[index%_clacks.size()]
	player.volume_db = -22.0-minf(7.0,float(index)*.7)
	player.pitch_scale = 1.0+float(index%3)*.07
	player.play()
