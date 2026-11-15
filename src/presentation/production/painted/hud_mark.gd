extends Control
## Small, directly drawn pigments; no line-art icons or runtime portrait work.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Pigment = preload("res://src/presentation/production/painted/hud_pigment.gdshader")
var motif := "awakening"
var amount := .1
var change := 0.0
var hover := 0.0
var elapsed := 0.0
var count := 3
var slots := 3
var energies: Array[float] = []
var muted := false
var _vertices := PackedVector3Array()
var _colors := PackedColorArray()
var _mesh := ArrayMesh.new()

func _triangle(a: Vector2,b: Vector2,c: Vector2,color: Color) -> void:
	for point: Vector2 in [a,b,c]:
		_vertices.append(Vector3(point.x,point.y,0))
		_colors.append(color)

func _polygon(points: PackedVector2Array,color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for i: int in range(0,indices.size(),3):
		_triangle(points[indices[i]],points[indices[i+1]],points[indices[i+2]],color)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := ShaderMaterial.new()
	ink.shader = Pigment
	material = ink

func _stroke(points: PackedVector2Array, width: float, color: Color) -> void:
	if points.size() < 2: return
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i: int in points.size():
		var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		var t := float(i)/float(points.size()-1)
		var taper := pow(sin(PI*t),.27)*.8+.2
		var w := width*taper*(.46+.09*sin(i*2.1)+.06*sin(i*5.7))
		top.append(points[i]+normal*w)
		bottom.append(points[i]-normal*w*.8)
	# Short ribbon segments cannot self-intersect at tightly curved dry edges.
	for i: int in range(points.size()-1):
		_triangle(top[i],top[i+1],bottom[i+1],color)
		_triangle(top[i],bottom[i+1],bottom[i],color)

func _arc(center: Vector2,radius: Vector2,start: float,end: float,width: float,color: Color,phase:=0.0) -> void:
	var path := PackedVector2Array()
	for i: int in 43:
		var angle := lerpf(start,end,float(i)/42.0)
		var irregular := 1.0+.016*sin(angle*13.+phase)+.01*sin(angle*29.)
		path.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y)*irregular)
	_stroke(path,width,color)

func _wash(bounds: Rect2, opacity: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 33:
		var t := float(i)/32.0
		points.append(bounds.position+Vector2(bounds.size.x*t,2.0*sin(i*1.9)+sin(i*4.4)))
	for i: int in range(32,-1,-1):
		var t := float(i)/32.0
		points.append(bounds.position+Vector2(bounds.size.x*t,bounds.size.y+2.*sin(i*2.3)))
	_polygon(points,Color(tint,opacity))

func _draw() -> void:
	_vertices.clear()
	_colors.clear()
	var warm := Paint.WARM
	var ash := Paint.MUTED
	var dark := Paint.INK.darkened(.4)
	var energy := absf(change)
	if muted: modulate.a = .45
	else: modulate.a = 1.0
	match motif:
		"epoch":
			_wash(Rect2(0,4,size.x,37),.8,dark)
			_stroke(PackedVector2Array([Vector2(3,39),Vector2(65,40),Vector2(size.x*.63,38),Vector2(size.x,37)]),1.8,Color(ash,.35))
			for i: int in 4:
				_stroke(PackedVector2Array([Vector2(10+i*5,12-i),Vector2(8+i*5,28+i)]),2.3,Color(warm,.4+i*.1))
		"faith":
			_wash(Rect2(3,5,size.x-6,37),.86,dark)
			_arc(Vector2(24,20),Vector2(13,13),.13,PI-.13,5.,Color(ash,.85))
			_stroke(PackedVector2Array([Vector2(17,36),Vector2(25,32),Vector2(33,35)]),3.,Color(warm,.58))
			_polygon(PackedVector2Array([Vector2(25,6),Vector2(29,17),Vector2(24,22),Vector2(21,17)]),warm)
		"awakening":
			var pulse := .5+.5*sin(elapsed*.8)
			# A: a layered breach in the same membrane that surrounds the table.
			var center := size*.5
			var open := 5.0+amount*13.0+energy*2.0
			for layer: int in range(4,-1,-1):
				var upper := PackedVector2Array()
				var lower := PackedVector2Array()
				for i: int in 55:
					var x := -1.+float(i)/27.
					var envelope := pow(maxf(0.,1.-x*x),1.25)
					var wave := sin(x*15.+.4)*1.5+sin(x*31.)*.7
					upper.append(center+Vector2(x*size.x*.48,-envelope*(open+layer*3.)+wave))
					lower.append(center+Vector2(x*size.x*.48,envelope*(open*.7+layer*2.4)+wave))
				var pigment := dark.lerp(ash,.12+float(4-layer)*.065)
				_stroke(upper,8.-layer*.7,Color(pigment,.9-float(layer)*.12))
				_stroke(lower,7.-layer*.7,Color(pigment,.85-float(layer)*.12))
			var opening := PackedVector2Array()
			for i: int in 65:
				var x := -1.+float(i)/32.
				opening.append(center+Vector2(x*size.x*.43,sin(x*17.)*.8-(1.-x*x)*open*.65))
			for i: int in range(64,-1,-1):
				var x := -1.+float(i)/32.
				opening.append(center+Vector2(x*size.x*.43,sin(x*17.)*.8+(1.-x*x)*open*.55))
			_polygon(opening,dark)
			for i: int in 7:
				var x := float(i-3)*20.
				var y := sin(i*2.3)*open*.21
				var strength := clampf(amount*7.-float(abs(i-3)),0.,1.)
				_stroke(PackedVector2Array([center+Vector2(x-5,y-open*.48),center+Vector2(x+2,y),center+Vector2(x-3,y+open*.5)]),2.+strength*2.,Color(warm,.22+strength*(.65+.1*pulse)+energy*.2))
		"whispers":
			for i: int in slots:
				var x := 4.+float(i)*15.
				var glow := energies[i] if i < energies.size() else (1.0 if i < count else 0.0)
				var points := PackedVector2Array([Vector2(x,2),Vector2(x+4,10),Vector2(x+2,19),Vector2(x-3,24),Vector2(x-4,13)])
				_polygon(points,Color(ash.lerp(warm,glow),.17+glow*(.65+.08*sin(elapsed*.8+i))))
				_stroke(PackedVector2Array([Vector2(x,8),Vector2(x-1,18)]),1.3,Color(Paint.BONE,.6*glow))
		"turn":
			_wash(Rect2(2,4,size.x-5,size.y-8),.97,Paint.WARM.lerp(Paint.INK,.52-hover*.1))
			_wash(Rect2(5,6,size.x-11,size.y-15),.85,dark.lerp(Paint.WARM,.11+hover*.1))
			_stroke(PackedVector2Array([Vector2(12,size.y-6),Vector2(size.x*.5,size.y-4),Vector2(size.x-9,size.y-7)]),2.2,Color(warm,.7))
			var c := Vector2(size.x-26.,size.y*.5)
			_arc(c,Vector2(12,14),-.7,3.9,3.5,Color(warm,.9))
			_stroke(PackedVector2Array([c+Vector2(0,-7),c+Vector2(7,0),c+Vector2(0,7)]),4.,Paint.BONE)
		"navigation":
			# Discontinuous rubbed ledge: never a flat rectangle across the screen.
			_stroke(PackedVector2Array([Vector2(0,36),Vector2(size.x*.15,37),Vector2(size.x*.4,35),Vector2(size.x*.67,37),Vector2(size.x,35)]),2.,Color(ash,.22))
			for i: int in 6:
				var x := 6.+float(i)*(size.x-12)/6.
				_stroke(PackedVector2Array([Vector2(x,37),Vector2(x+3,40),Vector2(x+7,37)]),2.,Color(warm,.28))
	if not _vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_COLOR] = _colors
		_mesh.clear_surfaces()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		draw_mesh(_mesh,null)
