extends RefCounted
## Converts native field descriptions to Godot shading language.
## Contours and recipes stay independent of this replaceable rendering backend.
const MathUtil = preload("res://src/art_generation/algorithms/drawing_math.gd")
static func field_function(name: String, value, default_expression: String) -> String:
	var body = "return "+default_expression+";"
	if value is Dictionary:
		if value.has("body"): body = value.body
		elif value.has("curves"):
			body = "float h = base_"+name+"(x,y,b);"
			for curve in value.curves:
				body += "h += fold_curve(vec2(x,y),%s,%s,%s,%s,%s,%s);" % [literal(curve[0]),literal(curve[1]),literal(curve[2]),literal(curve[3]),literal(curve[4]),literal(curve[5])]
			body += "return h;"
			return field_function("base_"+name,value.get("base"),"0.0")+"\nfloat %s(float x,float y,float b){%s}\n"%[name,body]
	return "float %s(float x,float y,float b){%s}\n"%[name,body]
static func literal(v): return MathUtil.gl_literal(v)
static func build(painter, options: Dictionary) -> String:
	var out = ""
	for key in ["height","u","v","wet","ao","corrupt","shadowField"]:
		var default = {"u":"x","v":"y","ao":"1.0","shadowField":"1.0"}.get(key,"0.0")
		out += field_function("field_"+key,options.get(key),default)
	out += design(painter.dimensions)
	for i in painter.emitters.size(): out += field_function("visibility_%d"%i,painter.emitters[i].get("visibility"),"1.0")
	out += "float light_visibility(int i,float x,float y){"
	for i in painter.emitters.size(): out += "if(i==%d)return visibility_%d(x,y,0.0);"%[i,i]
	out += "return 1.0;}\n"
	return out
static func design(d: Dictionary) -> String:
	if d.is_empty(): return "vec2 inverse_design(vec2 p){return p;}\n"
	var source = """
float bell(vec2 p,vec2 c,vec2 r){vec2 t=(p-c)/r;return exp(-dot(t,t));}
vec2 forward_design(vec2 p){float x=p.x,y=p.y,head=1.0-sm(326.0,416.0,y),crown=1.0-sm(170.0,310.0,y),a=@headTilt@*head;vec2 h=p-vec2(440,302);float xx=440.0+(h.x*cos(a)-h.y*sin(a))*(1.0+head*(@headWidth@-1.0))+head*@headShift@;float yy=302.0+h.x*sin(a)+h.y*cos(a)+crown*@crown@;
float grip=bell(p,vec2(480,595),vec2(125,79)),el=bell(p,vec2(281,641),vec2(76,97)),er=bell(p,vec2(650,645),vec2(76,97));
xx+=grip*@gripX@+el*@elbowSpread@-er*@elbowSpread@;yy+=grip*@gripY@+el*(@gripY@*.42+@elbowDrop@)+er*(@gripY@*.42-@elbowDrop@);yy+=bell(p,vec2(470,405),vec2(260,82))*(x-470.0)*@shoulderSlope@;xx=470.0+(xx-470.0)*(1.0+(1.0-head)*(@width@-1.0))+@lean@*(y-470.0);yy=470.0+(yy-470.0)*@height@;
float pitch=@viewPitch@;if(pitch!=0.0){xx=455.0+(xx-455.0)*(1.0-pitch*sm(390.0,930.0,y)*.52);yy=390.0+(yy-390.0)*(1.0-pitch*.42)+head*(12.0+@headLift@*10.0);yy-=bell(p,vec2(370,520),vec2(125,120))*pitch*28.0;yy-=head*sm(240.0,345.0,y)*(7.0+@headLift@*11.0);}return vec2(xx,yy);}
vec2 inverse_design(vec2 p){vec2 q=p;for(int i=0;i<9;i++){vec2 a=forward_design(q),e=p-a;if(abs(e.x)+abs(e.y)<.02)break;vec2 ax=(forward_design(q+vec2(.3,0))-a)/.3,bx=(forward_design(q+vec2(0,.3))-a)/.3;float det=ax.x*bx.y-bx.x*ax.y;if(abs(det)<.08)break;q+=clamp(vec2(e.x*bx.y-e.y*bx.x,e.y*ax.x-e.x*ax.y)/det,vec2(-60),vec2(60));}return q;}
"""
	for key in ["headTilt","headWidth","headShift","crown","gripX","elbowSpread","gripY","elbowDrop","shoulderSlope","width","lean","height","viewPitch","headLift"]: source=source.replace("@"+key+"@",literal(d.get(key,0)))
	return source
