shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform vec3 base : source_color = vec3(0.18, 0.18, 0.2);
uniform vec3 base2 : source_color = vec3(0.35, 0.33, 0.3);
uniform vec3 glow : source_color = vec3(0.4, 1.0, 0.7);
uniform float glyph_amt = 0.0;
uniform float crack_amt = 0.0;
uniform float noise_scale = 3.0;
uniform bool use_instance_color = false;
uniform float flat_shade = 0.0;
uniform float glyph_scale = 9.0;
uniform vec3 seed_off = vec3(0.0);
uniform float shade_mul = 1.0;

#include "res://src/art_generation/source/shaders/common.gdshaderinc"

varying vec3 v_obj;
varying vec3 v_onorm;
varying vec3 v_wpos;
varying vec3 v_wn;
varying vec3 v_col;
varying float v_iid;

void vertex() {
	v_obj = VERTEX;
	v_onorm = NORMAL;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = use_instance_color ? COLOR.rgb : vec3(1.0);
	v_iid = use_instance_color ? COLOR.a : 0.0;
}

void fragment() {
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
	vec3 N = normalize(v_wn);
	if (flat_shade > 0.5 || g_style == 3) { N = flat_normal(v_wpos); }
	vec3 q = v_obj * noise_scale + seed_off + vec3(v_iid * 37.0);
	float n = fbm3(q, 5);
	float r = ridged3(q * 0.7 + vec3(3.0), 4);
	vec3 alb = mix(base, base2, clamp(n * 1.2 + 0.5, 0.0, 1.0)) * v_col;
	alb *= 0.8 + 0.3 * r;
	float crack = pow(1.0 - abs(gnoise3(q * 1.3 + vec3(9.0))), 18.0) * crack_amt;
	vec3 emit = glow * crack * 1.4;
	// glyph panels on the large flat faces (object space)
	if (glyph_amt > 0.0) {
		vec3 an = abs(normalize(v_onorm));
		vec2 uv = an.z > an.x ? v_obj.xy : v_obj.zy;
		vec2 g = uv * glyph_scale;
		vec2 id = floor(g);
		float on = step(hash12(id + seed_off.xy), 0.75);
		float d = glyph_dist(fract(g), floor(hash12(id * 3.1) * 200.0));
		float fw = length(fwidth(g));
		float line = (1.0 - smoothstep(0.035, 0.035 + fw + 0.015, d)) * on * step(an.y, 0.6);
		alb *= 1.0 - line * 0.5;
		emit += glow * line * glyph_amt * (0.75 + 0.25 * sin(g_time * 1.5 + id.y * 0.8));
	}
	float h = n * 0.5 + r * 0.3;
	if (flat_shade < 0.5 && g_style != 3) { N = perturb_normal(N, v_wpos, h, 0.04 * length(MODEL_MATRIX[0].xyz)); }
	vec3 L = light_vec(v_wpos);
	vec3 col = style_shade(alb, N, L, V, g_light_col, 0.25, 16.0) * shade_mul;
	col += rim_term(N, V);
	col += emit;
	if (g_style == 5) {
		float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.0);
		float edge = 1.0 - smoothstep(0.0, 0.35, abs(dot(N, V)));
		col = g_holo * (0.02 + fres * 0.35 + edge * 0.25 + luma3(emit) * 0.6);
	}
	ALBEDO = col;
}
