shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform float len = 2.0;
uniform float thick = 1.0;
uniform float curl = 2.5;
uniform float curl_pow = 2.0;
uniform float wave_amp = 0.4;
uniform float wave_freq = 1.2;
uniform float wave_speed = 0.6;
uniform float twist = 0.3;
uniform float phase = 0.0;
uniform vec3 skin_a : source_color = vec3(0.12, 0.2, 0.18);
uniform vec3 skin_b : source_color = vec3(0.55, 0.45, 0.38);
uniform vec3 sucker_col : source_color = vec3(0.85, 0.7, 0.6);
uniform vec3 glow : source_color = vec3(0.4, 1.0, 0.7);
uniform float glow_amt = 0.0;
uniform vec3 seed_off = vec3(0.0);
uniform float shade_mul = 1.0;

#include "res://shaders/common.gdshaderinc"

varying vec3 v_wpos;
varying vec3 v_wn;
varying float v_t;
varying float v_side;
varying float v_ang;
varying float v_suck;

float theta_at(float s) {
	return curl * pow(s, curl_pow) + wave_amp * s * sin(s * wave_freq * TAU - g_time * wave_speed + phase);
}
float phi_at(float s) {
	return twist * s * sin(s * 3.1 + phase * 1.7 + g_time * wave_speed * 0.45);
}
vec3 dir_at(float s) {
	float th = theta_at(s);
	float ph = phi_at(s);
	return vec3(sin(th) * cos(ph), cos(th) * cos(ph), sin(ph));
}

void vertex() {
	float t = clamp(VERTEX.y, 0.0, 1.0);
	vec3 pos = vec3(0.0);
	float ds = t / 20.0;
	for (int i = 0; i < 20; i++) {
		pos += dir_at((float(i) + 0.5) * ds) * ds;
	}
	float th = theta_at(t);
	vec3 T = dir_at(t);
	vec3 Nn = vec3(cos(th), -sin(th), 0.0);
	vec3 B = normalize(cross(Nn, T));
	Nn = normalize(cross(T, B));
	vec2 xs = VERTEX.xz;
	v_side = length(xs) > 0.0 ? normalize(xs).x : 0.0;
	v_ang = atan(VERTEX.z, VERTEX.x);
	v_t = t;
	v_suck = COLOR.r;
	VERTEX = pos * len + (xs.x * Nn + xs.y * B) * len * thick + T * max(VERTEX.y - 1.0, 0.0) * len;
	NORMAL = normalize(NORMAL.x * Nn + NORMAL.y * T + NORMAL.z * B);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 N = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
	if (g_style == 3) { N = flat_normal(v_wpos); }
	vec2 sp = vec2(v_ang * 1.3, v_t * len * 9.0 / max(thick, 0.3));
	float mott = fbm2(sp * 1.6 + seed_off.xy, 4);
	float rings = 0.5 + 0.5 * sin(v_t * len * 70.0 / max(thick, 0.3) + mott * 3.0);
	float ventral = smoothstep(-0.1, 0.7, v_side);
	vec3 alb = mix(skin_a * (0.75 + 0.5 * mott), skin_b, ventral);
	alb *= 0.85 + 0.15 * rings * (1.0 - ventral);
	// suckers
	float rim = smoothstep(0.15, 0.6, v_suck) * (1.0 - smoothstep(0.75, 0.98, v_suck));
	float hole = smoothstep(0.92, 1.0, v_suck);
	alb = mix(alb, sucker_col, rim * 0.85);
	alb = mix(alb, sucker_col * 0.25, hole);
	// bioluminescent spots on the dorsal side
	vec2 g = sp * vec2(1.2, 0.8);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float spot = smoothstep(0.22, 0.05, length(f - (hash22(id) - 0.5) * 0.4)) * step(0.55, hash12(id + 2.0)) * (1.0 - ventral);
	float tipfade = smoothstep(1.0, 0.6, v_t);
	vec3 emit = glow * spot * glow_amt * (0.6 + 0.4 * sin(g_time * 2.0 + id.y * 0.7)) * tipfade;
	emit += glow * hole * glow_amt * 0.5;
	float h = mott * 0.3 + rim * 0.6 - hole * 0.4 + rings * 0.1;
	if (g_style != 3) { N = perturb_normal(N, v_wpos, h, 0.02 * len * thick); }
	vec3 L = light_vec(v_wpos);
	vec3 col = style_shade(alb, N, L, V, g_light_col, 0.9, 40.0) * shade_mul;
	col += rim_term(N, V) * 1.2;
	col += emit;
	if (g_style == 5) {
		float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.0);
		float ln = smoothstep(0.85, 1.0, rings);
		col = g_holo * (0.08 + fres * 0.9 + ln * 0.4 + luma3(emit));
	}
	ALBEDO = col;
}
