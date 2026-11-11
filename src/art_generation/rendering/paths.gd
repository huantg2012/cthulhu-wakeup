extends RefCounted
## SVG path parsing for illustration-space deformation and tight raster bounds.
## Rasterization itself uses Godot's built-in Image SVG loader, at runtime.
static var token_re: RegEx
static func ellipse(x,y,rx,ry) -> String:
	var k = 0.55228475
	return "M%s %sC%s %s %s %s %s %sC%s %s %s %s %s %sC%s %s %s %s %s %sC%s %s %s %s %s %sZ" % [x+rx,y,x+rx,y+k*ry,x+k*rx,y+ry,x,y+ry,x-k*rx,y+ry,x-rx,y+k*ry,x-rx,y,x-rx,y-k*ry,x-k*rx,y-ry,x,y-ry,x+k*rx,y-ry,x+rx,y-k*ry,x+rx,y]

static func contours(source: String) -> Array:
	if token_re == null:
		token_re = RegEx.new()
		token_re.compile("[MLCQZHVSTmlcqzhvst]|[-+]?(?:\\d*\\.\\d+|\\d+\\.?\\d*)(?:[eE][-+]?\\d+)?")
	var tokens = []
	for m in token_re.search_all(source): tokens.append(m.get_string())
	var result = []
	var points = PackedVector2Array()
	var current = Vector2.ZERO
	var start = Vector2.ZERO
	var previous_control = Vector2.ZERO
	var last = ""
	var cmd = ""
	var i = 0
	while i < tokens.size():
		if tokens[i].length() == 1 and tokens[i] in "MLCQZHVSTmlcqzhvst":
			cmd = tokens[i]
			i += 1
		var op = cmd.to_upper()
		var rel = cmd != op
		if op == "Z":
			points.append(start)
			current = start
			result.append({"points":points,"closed":true})
			points = PackedVector2Array()
			cmd = ""
			last = op
			continue
		var count = {"M":2,"L":2,"H":1,"V":1,"Q":4,"C":6,"T":2,"S":4}.get(op,0)
		assert(count > 0 and i+count <= tokens.size(), "Invalid illustration path: "+source)
		var v = []
		for j in count: v.append(float(tokens[i+j]))
		i += count
		var origin = current if rel else Vector2.ZERO
		if op == "H" or op == "V":
			var end = Vector2(origin.x+v[0],current.y) if op == "H" else Vector2(current.x,origin.y+v[0])
			points.append_array(_segment(current,end))
			current = end
		elif op == "M" or op == "L":
			var end = origin+Vector2(v[0],v[1])
			if op == "M":
				if not points.is_empty(): result.append({"points":points,"closed":false})
				points = PackedVector2Array([end])
				start = end
				cmd = "l" if rel else "L"
			else: points.append_array(_segment(current,end))
			current = end
		else:
			var a = origin+Vector2(v[0],v[1])
			var b = origin+Vector2(v[2],v[3]) if count >= 4 else a
			var end = origin+Vector2(v[4],v[5]) if count == 6 else b
			if op == "T":
				end = a
				a = current*2-previous_control if last in ["Q","T"] else current
			if op == "S":
				end = b
				b = a
				a = current*2-previous_control if last in ["C","S"] else current
			for j in range(1,19):
				var t = j/18.0
				var u = 1-t
				points.append(u*u*current+2*u*t*a+t*t*end if op in ["Q","T"] else u*u*u*current+3*u*u*t*a+3*u*t*t*b+t*t*t*end)
			previous_control = a if op in ["Q","T"] else b
			current = end
		last = op
	if not points.is_empty(): result.append({"points":points,"closed":false})
	return result

static func _segment(a: Vector2,b: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	for j in range(1,maxi(1,ceili(a.distance_to(b)/12.0))+1): points.append(a.lerp(b,float(j)/maxi(1,ceili(a.distance_to(b)/12.0))))

	return points

static func mapped(source: String, mapping: Callable) -> String:
	var out = PackedStringArray()
	for c in contours(source):
		for j in c.points.size():
			var p = c.points[j]
			var v = mapping.call(p.x,p.y)
			out.append(("M" if j == 0 else "L")+"%.2f %.2f"%[v[0],v[1]])
		if c.closed: out.append("Z")
	return "".join(out)

static func bounds(source: String) -> Rect2:
	var low = Vector2(INF,INF)
	var high = Vector2(-INF,-INF)
	for c in contours(source):
		for p in c.points:
			low = low.min(p)
			high = high.max(p)
	return Rect2(low,high-low)
