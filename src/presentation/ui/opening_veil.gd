extends RefCounted
## Shared transparent atmosphere between the scene and a round-opening decision.

static func build(parent: Control, name_value: String, bounds: Vector2, motion: Node) -> Control:
	var root := Control.new()
	root.name = name_value
	root.size = bounds
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.size = bounds
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Layered moving-looking fog, rendered transparently over the actual scene.
	# The backdrop has no copied screenshot and is distinct from a solid tint.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float motion_time = 0.0;
uniform float drift = 0.0015;
uniform float drift_near = -0.003;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void fragment() {
 vec2 p=(UV+vec2(motion_time*drift,0.0))*vec2(8.0,5.0); float n=noise(p)*0.55+noise((UV+vec2(motion_time*drift_near,0.0))*vec2(8.0,5.0)*2.1+3.7)*0.30+noise(p*4.0+12.0)*0.15;
 float band=pow(max(0.0,1.0-abs(UV.y-(0.50+0.10*sin(UV.x*7.0)))*2.5),2.0);
 vec3 dark=mix(vec3(0.005,0.022,0.026),vec3(0.020,0.068,0.071),n*0.72+band*0.22);
 COLOR=vec4(dark,clamp(0.76+n*0.10-band*0.06,0.68,0.89));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	veil.material = material
	if motion != null:
		material.set_shader_parameter("drift",motion.params.fog_far_uv_s*motion.params.opening_fog_factor)
		material.set_shader_parameter("drift_near",motion.params.fog_near_uv_s*motion.params.opening_fog_factor)
		motion.register_material(veil,material)
	root.add_child(veil)
	return root
