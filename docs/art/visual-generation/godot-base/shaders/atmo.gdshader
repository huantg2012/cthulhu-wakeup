shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 atmo_col : source_color = vec3(0.3, 0.9, 0.6);
uniform float thickness = 0.08;
uniform float intensity = 1.0;
uniform float planet_r = 1.0;
uniform float haze = 0.35;

#include "res://shaders/common.gdshaderinc"

varying vec3 v_wpos;
void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 C = MODEL_MATRIX[3].xyz;
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(v_wpos - ro);
	float t = dot(C - ro, rd);
	vec3 P = ro + rd * t;
	float b = length(P - C) / planet_r;
	vec3 n = normalize(P - C);
	float g;
	if (b >= 1.0) {
		g = exp(-(b - 1.0) / thickness);
	} else {
		// over the disc: haze growing toward the limb, sample normal on surface
		float z = sqrt(1.0 - b * b);
		n = normalize(n * b - rd * z);
		g = exp(-z / (thickness * 2.2)) * 0.9 + haze * 0.12;
	}
	vec3 L = light_vec(P);
	float lit = smoothstep(-0.35, 0.45, dot(n, L));
	float back = pow(max(dot(rd, L), 0.0), 6.0) * smoothstep(1.0, 1.02, b);
	vec3 col = atmo_col * g * (lit * 0.9 + 0.06) + atmo_col * back * g * 1.2;
	if (g_style == 1 || g_style == 4 || g_style == 7) {
		col = atmo_col * smoothstep(0.35, 0.45, g * (lit + 0.1)) * 0.7;
	}
	if (g_style == 5) {
		col = g_holo * g * 0.5;
	}
	ALBEDO = col * intensity;
}
