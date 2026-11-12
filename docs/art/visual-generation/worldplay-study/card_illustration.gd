extends Control
## Painted symbolic studies for action / relic cards. Replaceable illustration slots.
var motif := "power"
var ink := Color("9caa86")
var seed_value := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d21"))
	var c := size * Vector2(0.5, 0.49)
	var r := minf(size.x, size.y) * 0.35
	# Broad washes and broken dry lines share the stock's muted palette.
	for i: int in 90:
		var v := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		draw_circle(v, rng.randf_range(2, 19), Color(ink, rng.randf_range(0.008, 0.045)))
	for i: int in 7:
		draw_arc(c, r + i * 0.7, -2.7, 2.1, 40, Color(ink, 0.06), 1.5, false)
	var points := PackedVector2Array()
	match motif:
		"anchor":
			points = PackedVector2Array([c+Vector2(-r*.8,r*.8), c+Vector2(0,-r), c+Vector2(r*.8,r*.8), c+Vector2(-r*.8,r*.8)])
			_stroke(points)
			_stroke(PackedVector2Array([c+Vector2(0,-r*.55), c+Vector2(0,r*1.3)]))
			draw_circle(c+Vector2(0,-r*.2), r*.19, Color(ink,.7))
		"relic":
			points = PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*.48,0),c+Vector2(0,r),c+Vector2(-r*.48,0),c+Vector2(0,-r)])
			_stroke(points)
			_stroke(PackedVector2Array([c+Vector2(-r*.48,0), c+Vector2(r*.48,0)]))
		"person", "activity", "cult":
			for i: int in 3:
				var x := c.x + (i-1)*r*.66
				var y: float = c.y + (0.0 if i==1 else r*.2)
				draw_circle(Vector2(x,y-r*.45), r*.19, Color(ink,.6))
				draw_colored_polygon(PackedVector2Array([Vector2(x,y-r*.2),Vector2(x-r*.28,y+r*.7),Vector2(x+r*.28,y+r*.7)]),Color(ink,.18))
				_stroke(PackedVector2Array([Vector2(x-r*.28,y+r*.7),Vector2(x,y-r*.2),Vector2(x+r*.28,y+r*.7)]))
		_:
			for side: int in [-1,1]:
				points = PackedVector2Array()
				for i: int in 25:
					var t := float(i)/24
					points.append(c+Vector2(lerpf(-r*1.15,r*1.15,t),sin(t*PI)*r*.55*side))
				_stroke(points)
			draw_circle(c, r*.28, Color(ink,.65))
			draw_line(c-Vector2(0,r*.2), c+Vector2(0,r*.2),Color("122326"),3)

func _stroke(points: PackedVector2Array) -> void:
	for shift: int in 4:
		var displaced := PackedVector2Array()
		for point: Vector2 in points: displaced.append(point + Vector2(shift*.7,shift*.3))
		draw_polyline(displaced,Color(ink,.14 if shift else .65),1.5,false)
