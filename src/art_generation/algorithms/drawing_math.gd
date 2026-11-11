extends RefCounted
## Shared arithmetic and 2D field descriptions. All generation runs inside Godot.
const Painter = preload("res://src/art_generation/rendering/surface_painter.gd")
const Paths = preload("res://src/art_generation/rendering/paths.gd")
const TIDE = {"archetype":0,"styleSid":0,"palette":0,"worldSeed":1339,"c0":"#04161a","c1":"#0b3b3d","c2":"#1f6b5e","c3":"#8c9a6a","c4":"#6bff9e","nebula":"#5a2a6e","star":"#fff4c8","corruption":"#c040ff"}

static func getv(o, k) -> Variant:
	if o == null: return null
	if o is Dictionary: return o.get(k)
	if o is Array or o is PackedStringArray:
		var i = int(k)
		return o[i] if i >= 0 and i < o.size() else null
	if o is Object: return o.get(str(k))
	return null

static func truth(v) -> bool:
	if v == null: return false
	if v is Array or v is Dictionary: return true
	if v is Callable or v is Object: return true
	if v is String: return not v.is_empty()
	if v is bool: return v
	return v != 0

static func or_value(a, b): return a if truth(a) else b
static func fallback(a, b): return b if a == null else a
static func merge_dicts(values: Array) -> Dictionary:
	var out = {}
	for v in values: out.merge(v, true)
	return out
static func without(v: Dictionary, keys: Array):
	var out = v.duplicate()
	for k in keys: out.erase(k)
	return out
static func invoke(fn, args: Array = []):
	if fn == null: return null
	assert(fn is Callable, "Expected native drawing callable")
	return fn.callv(args.slice(0,fn.get_argument_count()))
static func invoke_member(o, k, args: Array = []):
	if o == null: return null
	if o is Dictionary: return invoke(o.get(k), args)
	return o.callv(str(k), args)
static func map_values(a: Array, fn: Callable) -> Array:
	var out = []
	for v in a: out.append(fn.call(v))
	return out
static func text_value(v) -> String:
	if v is Array:
		var a = PackedStringArray()
		for x in v: a.append(str(x))
		return ",".join(a)
	return str(v)
static func is_integer(v): return v is int or (v is float and v == floor(v))
static func hypot(v: Array):
	var s = 0.0
	for x in v: s += x*x
	return sqrt(s)
static func imul(a,b): return (int(a)*int(b)) & 0xffffffff
static func rng(seed_value):
	var state = [int(seed_value) & 0xffffffff]
	return func():
		state[0] = (state[0]+0x6D2B79F5) & 0xffffffff
		var t = state[0]
		t = imul(t^(t>>15),t|1)
		t = (t ^ ((t+imul(t^(t>>7), t|61)) & 0xffffffff)) & 0xffffffff
		return float((t^(t>>14)) & 0xffffffff)/4294967296.0
static func seedOf(parts: Array):
	var h = 2166136261
	var strings = PackedStringArray()
	for part in parts: strings.append(str(part))
	for c in "|".join(strings): h = imul(h ^ c.unicode_at(0),16777619)
	return h
static func smooth(a,b,x):
	var t = clampf((x-a)/(b-a),0,1)
	return t*t*(3-2*t)
static func rgb(c):
	if c is Array: return c
	var col = Color(c)
	return [col.r*255,col.g*255,col.b*255]
static func mix(a,b,t):
	var aa = rgb(a)
	var bb = rgb(b)
	var f = clampf(t,0,1)
	return [lerpf(aa[0],bb[0],f),lerpf(aa[1],bb[1],f),lerpf(aa[2],bb[2],f)]
static func ellipse(x,y,rx,ry): return Paths.ellipse(x,y,rx,ry)
static func mapPath(p, mapping): return Paths.mapped(p,mapping)
static func make_field(body: String, values: Array):
	for i in values.size(): body = body.replace("@%d@"%i, gl_literal(values[i]))
	return {"body":body}
static func gl_literal(v) -> String:
	if v is bool: return "true" if v else "false"
	if v is Array:
		var a = PackedStringArray()
		for x in v: a.append(gl_literal(x))
		return "vec%d(%s)"%[v.size(),",".join(a)]
	return "(%.9f)" % float(v)
static func foldField(curves, base = null): return {"curves":curves,"base":base}
static func worldField(kind, world): return {"kind":kind,"world":world}

static func add(a,b):
	return text_value(a)+text_value(b) if a is String or b is String else a+b

static func assign(target: Dictionary, values: Dictionary):
	target.merge(values,true)
	return target
