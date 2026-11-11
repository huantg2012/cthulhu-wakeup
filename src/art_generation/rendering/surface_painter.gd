extends RefCounted
## A retained list of 2D painting commands. No meshes, browser, external process.
const Paths = preload("res://src/art_generation/rendering/paths.gd")
var seed: int
var light: Array
var emitters: Array
var styleSid: int
var commands: Array = []
var layers = 0
var dimensions: Dictionary = {}
var world: Dictionary = {}
var environment: Dictionary = {}
var framing = [1.0,0.0,0.0]
var fade_start = 960.0
var c: ClipStack
var mc: ClipStack
var fc: ClipStack
var random: Callable
class ClipStack extends RefCounted:
	var clips: Array = []
	var states: Array = []
	func save(): states.append(clips.duplicate())
	func restore(): clips = states.pop_back()
	func clip(path): clips.append(path)

func _init(seed_value = 1339, options = {}):
	seed = int(seed_value)
	light = options.get("light",[-.7,-.26,.665])
	emitters = options.get("emitters",[])
	styleSid = int(options.get("styleSid",0))
	c = ClipStack.new()
	mc = ClipStack.new()
	fc = ClipStack.new()
	var state = [seed & 0xffffffff]
	random = func():
		state[0] = (state[0]+0x6D2B79F5) & 0xffffffff
		var t = state[0]
		t = ((t^(t>>15))*(t|1)) & 0xffffffff
		t = (t ^ ((t+(((t^(t>>7))*(t|61)) & 0xffffffff)) & 0xffffffff)) & 0xffffffff
		return float((t^(t>>14)) & 0xffffffff)/4294967296.0

func configure(config: Dictionary):
	dimensions = config.get("dimensions",{})
	world = config.get("environmentWorld",{})
	environment = config.get("environmentRule",{}) if config.get("environmentRule") != null else {}
	styleSid = int(config.get("styleSid",0))
	if world.get("archetype") == 5: light = [-.52,-.53,.67]
	elif world.get("archetype") == 4: light = [-.63,-.45,.64]
	for e in emitters:
		var xy = map_point(e.x,e.y)
		e.x = xy[0]
		e.y = xy[1]

func map_point(x,y) -> Array:
	if dimensions.is_empty(): return [x,y]
	var d = dimensions
	var head = 1-_smooth(326,416,y)
	var crown = 1-_smooth(170,310,y)
	var a = d.headTilt*head
	var hx = x-440
	var hy = y-302
	var xx = 440+(hx*cos(a)-hy*sin(a))*(1+head*(d.headWidth-1))+head*d.headShift
	var yy = 302+hx*sin(a)+hy*cos(a)+crown*d.crown
	var grip = _bell(x,y,480,595,125,79)
	var el = _bell(x,y,281,641,76,97)
	var er = _bell(x,y,650,645,76,97)
	xx += grip*d.gripX+el*d.elbowSpread-er*d.elbowSpread
	yy += grip*d.gripY+el*(d.gripY*.42+d.elbowDrop)+er*(d.gripY*.42-d.elbowDrop)
	yy += _bell(x,y,470,405,260,82)*(x-470)*d.shoulderSlope
	xx = 470+(xx-470)*(1+(1-head)*(d.width-1))+d.lean*(y-470)
	yy = 470+(yy-470)*d.height
	if d.get("viewPitch",0) != 0:
		var pitch = d.viewPitch
		xx = 455+(xx-455)*(1-pitch*_smooth(390,930,y)*.52)
		yy = 390+(yy-390)*(1-pitch*.42)+head*(12+d.headLift*10)
		yy -= _bell(x,y,370,520,125,120)*pitch*28
		yy -= head*_smooth(240,345,y)*(7+d.headLift*11)
	return [xx,yy]
func _smooth(a,b,x):
	var t = clampf((x-a)/(b-a),0,1)
	return t*t*(3-2*t)
func _bell(x,y,cx,cy,rx,ry): return exp(-pow((x-cx)/rx,2)-pow((y-cy)/ry,2))
func _path(p): return p if dimensions.is_empty() else Paths.mapped(p,map_point)
func _record(cmd):
	cmd["clips"] = [c.clips.duplicate(),mc.clips.duplicate(),fc.clips.duplicate()]
	commands.append(cmd)
func surface(path, _box, options = {}):
	layers += 1
	_record({"op":"surface","path":_path(path),"options":options.duplicate(),"layer":layers})
func fill(path, color, alpha = 1): _record({"op":"fill","path":_path(path),"color":color,"alpha":alpha})
func line(path,color,width=1,alpha=1): _record({"op":"line","path":_path(path),"color":color,"width":width,"alpha":alpha})
func shadow(path,amount=.5,blur=0): _record({"op":"shadow","path":_path(path),"alpha":amount,"blur":blur,"color":"#020711"})
func stroke(path,color,width=2,alpha=.5):
	for i in 3:
		var dx = (random.call()-.5)*width*.4
		var dy = (random.call()-.5)*width*.4
		var w = width*(.45+random.call()*.55)
		_record({"op":"stroke","path":_path(path),"color":color,"width":w,"alpha":alpha*.4,"offset":Vector2(dx,dy)})
func glow(x,y,r,color,alpha=.4):
	var xy = map_point(x,y)
	_record({"op":"glow","center":Vector2(xy[0],xy[1]),"radius":r,"color":color,"alpha":alpha})
func fade(start=870): fade_start = start
func reframe(scale,dx=null,dy=null): framing = scale if scale is Array else [scale,dx,dy]
func output(): return self
