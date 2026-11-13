shader_type canvas_item;
render_mode unshaded;
uniform sampler2D carrier_mask : filter_linear, repeat_disable;
uniform float opening : hint_range(0.0, 1.0) = 0.0;
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float field(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(grain(i),grain(i+vec2(1,0)),f.x),mix(grain(i+vec2(0,1)),grain(i+vec2(1)),f.x),f.y);
}
void fragment() {
	float clouds = field(UV*6.0)*0.7 + field(UV*17.0)*0.3;
	float distance = length((UV-vec2(0.5,0.48))*vec2(0.82,1.0));
	float dissolve = smoothstep(opening*1.45-0.16, opening*1.45+0.14, distance+clouds*0.37);
	float edge = smoothstep(0.0,0.09,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
	COLOR = vec4(mix(vec3(0.031,0.050,0.056),vec3(0.10,0.15,0.13),clouds*0.24),dissolve*edge*texture(carrier_mask,UV).a*(1.0-smoothstep(0.85,1.0,opening)));
}
