extends "res://src/presentation/production/worldplay/card_illustration.gd"
## A symbol printed on the same carrier: no rectangular backing or loose circles.
func _draw() -> void:
	var c := size * Vector2(0.5, 0.49)
	var r := minf(size.x, size.y) * 0.35
	var points := PackedVector2Array()
	match motif:
		"event":
			var top := c + Vector2(0,-r)
			var bottom := c + Vector2(0,r)
			for cap: Vector2 in [top,bottom]:
				_stroke(PackedVector2Array([cap-Vector2(r*.7,0),cap+Vector2(r*.7,0)]))
			_stroke(PackedVector2Array([top+Vector2(-r*.55,0),c,bottom+Vector2(r*.55,0)]))
			_stroke(PackedVector2Array([top+Vector2(r*.55,0),c,bottom+Vector2(-r*.55,0)]))
			draw_circle(c+Vector2(0,r*.55),r*.16,Color(ink,.65))
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
