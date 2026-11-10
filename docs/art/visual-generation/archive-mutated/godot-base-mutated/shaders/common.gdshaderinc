// ---- shared globals (declared in project.godot [shader_globals]) ----
global uniform float g_time;
global uniform int g_style;          // 0 厚涂 1 赛璐璐 2 铜版画 3 低多边形 4 像素 5 全息 6 水彩手稿 7 怪奇杂志
global uniform vec3 g_light_dir;
global uniform vec3 g_light_pos;
global uniform float g_light_point;
global uniform vec3 g_light_col;
global uniform vec3 g_amb;
global uniform vec3 g_rim_col;
global uniform vec3 g_rim_dir;
global uniform float g_rim_amt;
global uniform vec3 g_holo;

#include "res://shaders/noise.gdshaderinc"

float luma3(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 light_vec(vec3 wpos) {
	return normalize(mix(normalize(g_light_dir), g_light_pos - wpos, g_light_point));
}

bool style_banded() { return g_style == 1 || g_style == 4 || g_style == 7; }

float style_diffuse(float ndl) {
	if (style_banded()) {
		float d = mix(0.03, 0.32, smoothstep(-0.24, -0.18, ndl));
		d = mix(d, 1.0, smoothstep(0.18, 0.24, ndl));
		if (g_style == 7) { d = mix(d, 1.18, smoothstep(0.72, 0.76, ndl)); }
		return d;
	}
	float d = clamp((ndl + 0.08) / 1.08, 0.0, 1.0);
	if (g_style == 3) { return floor(d * 5.0 + 0.5) / 5.0; }
	return d * d * (3.0 - 2.0 * d) * 0.45 + d * 0.55;
}

vec3 style_shade(vec3 alb, vec3 N, vec3 L, vec3 V, vec3 lcol, float spec, float gloss) {
	float ndl = dot(N, L);
	float diff = style_diffuse(ndl);
	vec3 term = vec3(1.0);
	if (g_style == 0 || g_style == 6 || g_style == 2) {
		float tz = 1.0 - smoothstep(0.0, 0.32, ndl);
		term = mix(vec3(1.0), vec3(1.0, 0.52, 0.34), tz * step(0.0, ndl) * 0.6);
	}
	float amb_k = 1.0;
	if (g_style == 6) { amb_k = 5.5; }
	else if (g_style == 2) { amb_k = 2.0; }
	vec3 H = normalize(L + V);
	float sp = pow(max(dot(N, H), 0.0), gloss) * spec * smoothstep(-0.05, 0.1, ndl);
	if (style_banded()) { sp = step(0.4, sp) * spec * 0.8; }
	vec3 fill = vec3(0.0);
	if (g_style == 2 || g_style == 6) {
		fill = vec3(0.22) * pow(max(dot(N, V), 0.0), 1.5);
	}
	return alb * (lcol * diff * term + g_amb * amb_k + fill) + lcol * sp * 0.5;
}

vec3 flat_normal(vec3 wpos) {
	return normalize(cross(dFdx(wpos), dFdy(wpos)));
}

vec3 rim_term(vec3 N, vec3 V) {
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	return g_rim_col * pow(1.0 - ndv, 4.0) * max(dot(N, normalize(g_rim_dir)), 0.0) * g_rim_amt;
}

vec3 perturb_normal(vec3 N, vec3 pos, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h) * k;
	float dhy = dFdy(h) * k;
	vec3 r1 = cross(dpdy, N);
	vec3 r2 = cross(N, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * N - grad);
}
