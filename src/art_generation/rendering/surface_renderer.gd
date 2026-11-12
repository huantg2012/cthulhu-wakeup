extends Node
## GPU implementation of the retained painting commands. Replaceable as a unit.
const Paths = preload("res://src/art_generation/rendering/paths.gd")
const Fields = preload("res://src/art_generation/rendering/field_compiler.gd")
const MAT = {"hair":1,"leather":2,"canvas":3,"cloth":4,"stone":5,"masonry":6,"water":7,"metal":8,"skin":9}
const FIELD = {"ridge":1,"flesh":2,"fungus":3,"basalt":4,"frost":5,"prism":6,"sand":7,"flux":8,"shell":9,"bone":10,"ivory":11,"wood":12,"silk":13,"lava":14,"quiet_flux":15}
const SurfaceShader = preload("res://src/art_generation/rendering/surface.gdshader")
var shader_source: String = SurfaceShader.code
var shader_cache = {}
var svg_cache = {}
var progress: Callable

static func col(v) -> Color:
	return Color(float(v[0])/255,float(v[1])/255,float(v[2])/255) if v is Array else Color(v)
static func vec(v) -> Vector3: return Vector3(v[0],v[1],v[2])
static func rgbvec(v) -> Vector3:
	var c = col(v)
	return Vector3(c.r,c.g,c.b)
func _surface_material(p, command) -> ShaderMaterial:
	var o = command.options
	var code = "#define NATIVE_FIELDS\n"+shader_source.replace("// GENERATED_FIELDS",Fields.build(p,o))
	var shader: Shader = shader_cache.get(code)
	if shader == null:
		shader = Shader.new()
		shader.code = code
		shader_cache[code] = shader
	var m = ShaderMaterial.new()
	m.shader = shader
	var values = {"seed":p.seed+o.get("seed",0),"mat_id":MAT.get(o.get("mat","stone"),0),"field_id":FIELD.get(o.get("field",{}).get("kind",""),0) if o.get("field") != null else 0,"base_col":rgbvec(o.get("color","#758e70")),"shade_col":rgbvec(o.get("shadow","#17333b")),"accent_col":rgbvec(o.get("accent","#b9b58b")),"glow_col":rgbvec(o.get("glow","#6bff9e")),"normal":vec(o.get("normal",[0,0,1])),"light_dir":vec(p.light),"ambient":vec(o.get("ambient",[.065,.10,.14])),"ambient_custom":o.has("ambient"),"bump":o.get("bump",.8),"exposure":o.get("exposure",1),"scale":o.get("scale",32),"salt":o.get("salt",.08),"emission_amount":o.get("emission",0),"center":Vector2(o.get("cx",0),o.get("cy",0)),"style_sid":p.styleSid,"corrupt_enabled":o.has("corrupt"),"layer_id":command.layer}
	var w = o.get("field",{}).get("world",p.world) if o.get("field") != null else p.world
	for k in ["c0","c1","c2","c4","star","nebula"]: values["world_"+k] = rgbvec(w.get(k,"#000000"))
	values.world_seed = w.get("worldSeed",0)
	if not p.dimensions.is_empty() and not p.world.is_empty():
		var kind = p.environment.get("treatment","")
		values.environment_kind = 1 if p.world.archetype==5 else 2 if p.world.archetype==4 else {"spore":3,"fibre":4,"iridescent":5,"stain":6,"ink":7,"streak":8,"chalk":9,"dust":10}.get(kind,0)
		if p.world.archetype in [4,5]:
			if values.mat_id == 9: values.exposure *= .82
			if values.mat_id in [2,3,4]: values.ambient = Vector3(.10,.13,.19) if p.world.archetype==5 else Vector3(.16,.085,.065)
	var positions = []
	var colors = []
	var factors = PackedVector3Array()
	assert(p.emitters.size()<=16,"Too many illustration point lights")
	for i in 16:
		if i>=p.emitters.size():
			positions.append(Vector4.ZERO);colors.append(Vector4.ZERO);factors.append(Vector3.ZERO);continue
		var e = p.emitters[i]
		positions.append(Vector4(e.x,e.y,e.get("z",55),e.r))
		var color = rgbvec(e.color)
		colors.append(Vector4(color.x,color.y,color.z,e.power))
		var visibility = o.pointVisibility.call(e) if o.has("pointVisibility") else 1.0
		factors.append(Vector3(e.get("falloff",2),e.get("specular",0),visibility))
	values.light_count = p.emitters.size()
	values.light_position_radius = positions
	values.light_color_power = colors
	values.light_falloff_spec_visibility = factors
	for k in values: m.set_shader_parameter(k,values[k])
	return m

func _svg(path: String, bounds: Rect2, stroke_width: float, clips: Array) -> Texture2D:
	var key = path+str(bounds)+str(stroke_width)+str(clips)
	if svg_cache.has(key): return svg_cache[key]
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">' % [int(bounds.size.x),int(bounds.size.y),bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	for i in clips.size(): svg += '<defs><clipPath id="c%d"><path d="%s"/></clipPath></defs><g clip-path="url(#c%d)">'%[i,clips[i],i]
	svg += '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>'%[path,"white" if stroke_width==0 else "none","none" if stroke_width==0 else "white",stroke_width]
	for i in clips.size(): svg += '</g>'
	svg += '</svg>'
	var image = Image.new()
	var err = image.load_svg_from_string(svg)
	assert(err==OK,"Cannot rasterize native illustration contour")
	var texture = ImageTexture.create_from_image(image)
	svg_cache[key]=texture
	return texture

func render(painter) -> Dictionary:
	shader_cache.clear()
	svg_cache.clear()
	var viewport = SubViewport.new()
	viewport.size = Vector2i(960,960)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)
	var items = []
	var i = 0
	for cmd in painter.commands:
		var item = TextureRect.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.stretch_mode = TextureRect.STRETCH_SCALE
		var bounds: Rect2
		if cmd.op == "glow":
			bounds=Rect2(cmd.center-Vector2.ONE*cmd.radius,Vector2.ONE*cmd.radius*2)
			var img = Image.create(1,1,false,Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			item.texture = ImageTexture.create_from_image(img)
			var sh = Shader.new()
			sh.code = "shader_type canvas_item; render_mode unshaded,blend_add; uniform vec4 tint; void fragment(){float r=length(UV-.5)*2.0;vec3 c=mix(tint.rgb,vec3(.035,.073,.106),clamp(r/.18,0.0,1.0)*.5);COLOR=vec4(c,tint.a*(1.0-smoothstep(.18,1.0,r)));}"
			var mat = ShaderMaterial.new();mat.shader=sh
			var color = col(cmd.color);color.a=cmd.alpha
			mat.set_shader_parameter("tint",color);item.material=mat
		else:
			var pad = maxf(cmd.get("width",0)*.6,1)+cmd.get("blur",0)*3
			bounds=Paths.bounds(cmd.path).grow(pad)
			bounds=Rect2(bounds.position.floor(),bounds.end.ceil()-bounds.position.floor())
			bounds=bounds.intersection(Rect2(0,0,960,960))
			if bounds.size.x<=0 or bounds.size.y<=0: item.free();continue
			item.texture=_svg(cmd.path,bounds,cmd.get("width",0),cmd.clips[0])
			if cmd.op=="surface":
				item.material=_surface_material(painter,cmd)
				item.material.set_shader_parameter("tile_origin",bounds.position)
				item.material.set_shader_parameter("tile_size",bounds.size)
			else:
				item.self_modulate=col(cmd.color)
				item.self_modulate.a=cmd.alpha
				if cmd.get("blur",0)>0:
					var sh=Shader.new()
					sh.code="shader_type canvas_item;render_mode unshaded;uniform vec2 step_size;void fragment(){vec4 tint=COLOR;float a=0.0,total=0.0;for(int y=-4;y<=4;y++){for(int x=-4;x<=4;x++){float w=exp(-float(x*x+y*y)*.22);a+=texture(TEXTURE,UV+vec2(float(x),float(y))*step_size).a*w;total+=w;}}COLOR=vec4(tint.rgb,tint.a*a/total);}"
					var mat=ShaderMaterial.new();mat.shader=sh;mat.set_shader_parameter("step_size",Vector2.ONE*cmd.blur*.65/bounds.size);item.material=mat
		item.position=bounds.position+cmd.get("offset",Vector2.ZERO)
		item.size=bounds.size
		viewport.add_child(item)
		items.append({"node":item,"command":cmd,"bounds":bounds})
		i+=1
		if i%48==0:
			if progress.is_valid(): progress.call("合成二维图层 %d/%d"%[i,painter.commands.size()])
			await get_tree().process_frame
	var out = {}
	for pass_index in 3:
		for row in items:
			var cmd=row.command
			row.node.visible=not (pass_index!=0 and cmd.op in ["stroke","glow"]) and not (pass_index==1 and cmd.op=="shadow")
			if cmd.op=="surface": row.node.material.set_shader_parameter("pass_index",pass_index)
			elif cmd.op!="glow" and cmd.clips[pass_index]!=cmd.clips[0]: row.node.texture=_svg(cmd.path,row.bounds,cmd.get("width",0),cmd.clips[pass_index])
		for frame in 2: await _render_frame()
		var image=viewport.get_texture().get_image()
		out[["lit","material","form"][pass_index]]=await _frame(image,painter.framing,painter.fade_start)
	viewport.queue_free()
	await get_tree().process_frame
	shader_cache.clear();svg_cache.clear()
	return out

func _frame(image: Image, framing: Array, fade_start: float) -> Image:
	var vp=SubViewport.new();vp.size=Vector2i(960,960);vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp)
	var rect=TextureRect.new();rect.texture=ImageTexture.create_from_image(image);rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_SCALE;rect.size=Vector2.ONE*960*framing[0];rect.position=Vector2(framing[1],framing[2]);vp.add_child(rect)
	var sh=Shader.new();sh.code="shader_type canvas_item;render_mode unshaded;uniform float fade_start;void fragment(){COLOR=texture(TEXTURE,UV);COLOR.a*=clamp((960.0-FRAGCOORD.y)/(960.0-fade_start),0.0,1.0);}"
	var mat=ShaderMaterial.new();mat.shader=sh;mat.set_shader_parameter("fade_start",minf(fade_start,959.99));rect.material=mat
	for frame in 2: await _render_frame()
	var result=vp.get_texture().get_image();vp.queue_free();return result

func _render_frame():
	await get_tree().process_frame
	# Explicit offscreen draw also works when the tool window is occluded.
	RenderingServer.force_draw(false)
