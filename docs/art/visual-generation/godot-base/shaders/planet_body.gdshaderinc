// Planet surface body. Included by planet_aN.gdshader with ARCH defined.

// ARCH: 0 溺亡之海 1 凝视之眼 2 血肉之星 3 菌蚀冥星 4 炎狱之星 5 冷原 6 星之彩
//             7 黄衣王城 8 混沌核心 9 古神之茧 10 骸骨之月
uniform vec3 seed_off = vec3(0.0);
uniform vec3 c0 : source_color = vec3(0.02, 0.1, 0.12);
uniform vec3 c1 : source_color = vec3(0.04, 0.23, 0.25);
uniform vec3 c2 : source_color = vec3(0.12, 0.42, 0.37);
uniform vec3 c3 : source_color = vec3(0.42, 0.48, 0.35);
uniform vec3 c4 : source_color = vec3(0.5, 1.0, 0.6);
uniform vec3 atmo_col : source_color = vec3(0.3, 0.84, 0.63);
uniform float atmo_rim = 0.6;
uniform float sea_level = 0.0;
uniform float glyphs = 0.0;
uniform float corruption = 0.0;
uniform vec3 cor_dark : source_color = vec3(0.08, 0.0, 0.1);
uniform vec3 cor_glow : source_color = vec3(0.9, 0.2, 1.0);
uniform float night_lights = 0.5;
uniform float eyes_many = 0.0;
uniform float eye_amt = 0.0;
uniform vec3 eye_dir = vec3(0.0, 0.0, 1.0);
uniform float eye_size = 0.6;
uniform float eye_open = 1.0;
uniform vec2 eye_look = vec2(0.0);
uniform int pupil_type = 0;
uniform vec3 iris_col : source_color = vec3(1.0, 0.8, 0.2);
uniform float bump = 1.0;
uniform int octaves = 6;
uniform bool lowpoly = false;
uniform float ring_shadow = 0.0;
uniform vec3 ring_n = vec3(0.0, 1.0, 0.0);
uniform float ring_r0 = 1.4;
uniform float ring_r1 = 2.4;
uniform float ring_seed = 0.0;
uniform float self_emit = 0.0;

#include "res://shaders/common.gdshaderinc"

varying vec3 v_obj;
varying vec3 v_face;
varying vec3 v_wpos;
varying vec3 v_wnorm;

struct Surf {
	vec3 alb;
	vec3 emit;
	float spec;
	float h;
	float land;
};

void vertex() {
	v_obj = normalize(VERTEX);
	v_face = NORMAL;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

vec3 ramp4(float t) {
	t = clamp(t, 0.0, 1.0) * 3.0;
	vec3 a = mix(c0, c1, clamp(t, 0.0, 1.0));
	a = mix(a, c2, clamp(t - 1.0, 0.0, 1.0));
	a = mix(a, c3, clamp(t - 2.0, 0.0, 1.0));
	return a;
}

vec3 warp3(vec3 q, float f, float amt) {
	return q + amt * vec3(fbm3(q * f + vec3(11.0), 3), fbm3(q * f + vec3(23.0), 3), fbm3(q * f + vec3(37.0), 3));
}

#if ARCH == 0
Surf s_drowned(vec3 p, vec3 q) {
	Surf s;
	vec3 w = warp3(q, 1.3, 0.35);
	float h = fbm3(w * 1.8, octaves) + 0.12 * ridged3(w * 3.0, 3);
	float sl = sea_level + 0.06;
	float land = smoothstep(sl, sl + 0.015, h);
	float depth = clamp((sl - h) * 3.0, 0.0, 1.0);
	vec3 sea = mix(c2, c1, smoothstep(0.0, 0.25, depth));
	sea = mix(sea, c0, smoothstep(0.25, 1.0, depth));
	vec3 vd = normalize(vec3(0.6, 0.25, 0.75) + (hash33(seed_off) - 0.5) * 1.2);
	float vdist = acos(clamp(dot(p, vd), -1.0, 1.0));
	vec3 tu = normalize(cross(vd, vec3(0.0, 1.0, 0.0)));
	vec3 tv = cross(vd, tu);
	float ang = atan(dot(p, tv), dot(p, tu));
	float spiral = sin(ang * 3.0 + log(vdist + 0.02) * 9.0 - g_time * 0.6 + fbm3(q * 6.0, 2) * 2.0);
	float vmask = smoothstep(0.6, 0.05, vdist) * (1.0 - land);
	sea = mix(sea, mix(c0 * 0.5, c2 * 1.4, 0.5 + 0.5 * spiral), vmask * 0.75);
	sea = mix(sea, vec3(0.0), smoothstep(0.09, 0.0, vdist) * vmask);
	float coast = smoothstep(sl - 0.035, sl, h) * (1.0 - land);
	sea = mix(sea, c3, coast * 0.45);
	vec4 vo = voronoi3(q * 9.0);
	float seam = smoothstep(0.0, 0.06, vo.y - vo.x);
	vec3 stone = mix(c2 * 0.8, c3, clamp(vo.z * 0.6 + (h - sl) * 3.0, 0.0, 1.0));
	stone = mix(stone, mix(c1, c4 * 0.35, 0.4), smoothstep(0.1, 0.3, fbm3(q * 4.0 + 5.0, 3)) * 0.7);
	stone *= mix(0.35, 1.0, seam);
	s.alb = mix(sea, stone, land);
	s.emit = c4 * (1.0 - seam) * land * 0.3 * step(0.8, vo.z) + c4 * smoothstep(0.12, 0.0, vdist) * vmask * 0.4;
	s.spec = mix(0.9, 0.08, land);
	s.h = mix(sl, h + vo.z * 0.04 - (1.0 - seam) * 0.03, land);
	s.land = land;
	return s;
}
#endif

#if ARCH == 1
Surf s_eyeworld(vec3 p, vec3 q) {
	Surf s;
	vec3 w = warp3(q, 1.5, 0.3);
	float h = fbm3(w * 2.0, octaves);
	float wr = pow(1.0 - abs(gnoise3(w * 4.0)), 6.0);
	float wr2 = pow(1.0 - abs(gnoise3(w * 9.0 + 3.0)), 8.0);
	s.alb = ramp4(0.42 + h * 0.8 + wr * 0.12);
	s.alb = mix(s.alb, c1 * 0.5, wr2 * 0.5);
	s.emit = c4 * wr2 * 0.08;
	s.spec = 0.4;
	s.h = h * 0.6 + wr * 0.12 - wr2 * 0.05;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 2
Surf s_flesh(vec3 p, vec3 q) {
	Surf s;
	vec3 w = warp3(q, 1.5, 0.4);
	float h = fbm3(w * 2.2, octaves);
	vec4 vo = voronoi3(w * 5.0);
	float cell = 1.0 - smoothstep(0.0, 0.75, vo.x);
	float vein = pow(1.0 - abs(gnoise3(w * 3.0)), 14.0) + 0.6 * pow(1.0 - abs(gnoise3(w * 7.0 + 4.0)), 18.0);
	float pulse = 0.6 + 0.4 * sin(g_time * 2.5 - dot(p, vec3(3.0, 1.0, 2.0)) * 4.0);
	s.alb = ramp4(0.45 + h * 0.9 + cell * 0.15);
	s.alb = mix(s.alb, c1 * 0.6, clamp(vein, 0.0, 1.0) * 0.8);
	s.alb = mix(s.alb, c3 * 1.1, smoothstep(0.85, 1.0, cell) * step(0.8, vo.z) * 0.8);
	s.emit = c4 * clamp(vein, 0.0, 1.5) * pulse * 0.4;
	s.spec = 0.75;
	s.h = h * 0.5 + cell * 0.18 + vein * 0.06;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 3
Surf s_fungal(vec3 p, vec3 q) {
	Surf s;
	float h = ridged3(q * 1.7, octaves) - 0.45 + 0.3 * fbm3(q * 0.8, 3);
	s.alb = ramp4(0.25 + h * 1.0);
	float lat = abs(p.y) + 0.12 * fbm3(q * 4.0, 3);
	float ice = smoothstep(0.72, 0.78, lat);
	s.alb = mix(s.alb, c3 * 1.1, ice);
	vec4 vo = voronoi3(q * 7.0);
	float colony = smoothstep(0.05, 0.3, fbm3(q * 2.3 + 9.0, 4)) * (1.0 - ice);
	float spot = (1.0 - smoothstep(0.05, 0.32, vo.x)) * step(0.35, vo.z) * colony;
	s.alb = mix(s.alb, c4 * 0.22 + c1 * 0.5, colony * 0.6);
	s.emit = c4 * spot * (0.4 + 0.6 * vo.z) * (0.8 + 0.2 * sin(g_time * 1.3 + vo.z * 30.0));
	s.spec = ice * 0.6;
	s.h = h * 0.7 + spot * 0.06;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 4
Surf s_fire(vec3 p, vec3 q) {
	Surf s;
	vec3 w = warp3(q, 2.0, 0.25);
	vec4 vo = voronoi3(w * 4.0);
	float crack = 1.0 - smoothstep(0.0, 0.09, vo.y - vo.x);
	vec4 vo2 = voronoi3(w * 11.0 + 3.0);
	float crack2 = 1.0 - smoothstep(0.0, 0.06, vo2.y - vo2.x);
	float h = fbm3(w * 3.0, octaves);
	float lava = smoothstep(-0.18, -0.28, h);
	float heat = max(max(crack, crack2 * 0.6 * smoothstep(-0.1, 0.2, h)), lava);
	float flick = 0.8 + 0.2 * sin(g_time * 3.0 + vo.z * 20.0);
	s.alb = ramp4(0.3 + h * 0.8 + vo.z * 0.3) * (1.0 - heat);
	s.emit = mix(c4, vec3(1.0, 0.95, 0.7), heat * heat * 0.6) * heat * flick * 1.2;
	s.spec = 0.15;
	s.h = h * 0.4 + vo.z * 0.08 - heat * 0.12;
	s.land = 1.0 - lava;
	return s;
}
#endif

#if ARCH == 5
Surf s_leng(vec3 p, vec3 q) {
	Surf s;
	float h = fbm3(q * 1.5, octaves);
	float hq = floor(h * 7.0) / 7.0;
	float terr = mix(h, hq, 0.7);
	float cr = pow(1.0 - abs(gnoise3(q * 5.0)), 10.0);
	s.alb = ramp4(0.45 + terr * 0.9);
	float snow = smoothstep(0.05, 0.25, h + abs(p.y) * 0.35);
	s.alb = mix(s.alb, c3, snow * 0.8);
	s.alb = mix(s.alb, c0, cr * 0.7);
	s.emit = c4 * cr * 0.05;
	s.spec = snow * 0.4;
	s.h = terr * 0.8 - cr * 0.08;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 6
Surf s_colour(vec3 p, vec3 q, float ndv) {
	Surf s;
	vec3 cp;
	vec4 vo = voronoi3c(q * 5.0, cp);
	float edge = 1.0 - smoothstep(0.0, 0.05, vo.y - vo.x);
	float hue = fract(vo.z * 0.6 + ndv * 0.9 + g_time * 0.03 + fbm3(q * 2.0, 3) * 0.5);
	vec3 iri = 0.5 + 0.5 * cos(TAU * (hue + vec3(0.0, 0.33, 0.67)));
	iri = mix(iri, c4, 0.3);
	s.alb = mix(c0, iri * 0.75, 0.75) * (1.0 - edge * 0.6);
	s.emit = iri * edge * 0.6 + iri * 0.12 * vo.z;
	s.spec = 1.0;
	s.h = vo.z * 0.1 - edge * 0.06;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 7
Surf s_carcosa(vec3 p, vec3 q) {
	Surf s;
	vec3 w = warp3(q, 1.2, 0.3);
	float h = fbm3(w * 1.6, octaves);
	float dunes = sin(dot(w, vec3(14.0, 3.0, 9.0)) + fbm3(w * 3.0, 3) * 6.0) * 0.5 + 0.5;
	s.alb = ramp4(0.42 + h * 0.8 + dunes * 0.12);
	float lake = smoothstep(-0.12, -0.17, h);
	vec4 vo = voronoi3(q * 14.0);
	float city = smoothstep(0.15, 0.3, fbm3(q * 3.0 + 2.0, 3)) * (1.0 - lake);
	float seam = 1.0 - smoothstep(0.0, 0.05, vo.y - vo.x);
	s.alb *= 1.0 - city * seam * 0.55;
	s.alb = mix(s.alb, c0 * 0.25, lake);
	s.emit = c4 * city * seam * step(0.85, vo.z) * 0.4;
	s.spec = mix(0.05, 1.0, lake);
	s.h = mix(h * 0.5 + dunes * 0.03 + city * vo.z * 0.04, -0.2, lake);
	s.land = 1.0 - lake;
	return s;
}
#endif

#if ARCH == 8
Surf s_chaos(vec3 p, vec3 q) {
	Surf s;
	float t = g_time * 0.12;
	vec3 w = q * 1.4;
	vec3 o1 = vec3(fbm3(w + vec3(0.0, t, 0.0), 4), fbm3(w + vec3(5.2, 1.3 - t, 2.8), 4), fbm3(w + vec3(1.7, 9.2, 3.1 + t), 4));
	vec2 o2 = vec2(fbm3(w + 3.0 * o1 + vec3(1.7, 9.2, t), 4), fbm3(w + 3.0 * o1 + vec3(8.3, 2.8, -t), 4));
	float f = fbm3(w + 3.5 * vec3(o2, o1.z), octaves);
	float v = clamp(f * 1.3 + 0.5, 0.0, 1.0);
	vec3 col = ramp4(v);
	float hot = smoothstep(0.62, 0.95, v);
	s.alb = col * 0.35;
	s.emit = col * 0.8 + c4 * hot * 0.9;
	s.spec = 0.0;
	s.h = f * 0.3;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 9
Surf s_cocoon(vec3 p, vec3 q) {
	Surf s;
	vec4 vo = voronoi3(q * 3.2);
	float crack = 1.0 - smoothstep(0.0, 0.04 + 0.04 * fbm3(q * 8.0, 2), vo.y - vo.x);
	float stri = sin(p.y * 60.0 + fbm3(q * 3.0, 3) * 8.0) * 0.5 + 0.5;
	float h = fbm3(q * 2.5, octaves);
	float pulse = 0.55 + 0.45 * sin(g_time * 1.6 + vo.z * 6.0);
	s.alb = ramp4(0.35 + h * 0.6 + stri * 0.2 + vo.z * 0.15) * (1.0 - crack);
	float vein = pow(1.0 - abs(gnoise3(q * 6.0)), 16.0) * smoothstep(0.3, 0.0, vo.y - vo.x);
	s.emit = c4 * (crack * 1.3 + vein * 0.5) * pulse;
	s.spec = 0.5;
	s.h = h * 0.3 + stri * 0.02 - crack * 0.12 + (1.0 - vo.x) * 0.12;
	s.land = 1.0;
	return s;
}
#endif

#if ARCH == 10
Surf s_bone(vec3 p, vec3 q) {
	Surf s;
	float h = fbm3(q * 2.0, octaves) * 0.5;
	for (int i = 0; i < 2; i++) {
		float sc = i == 0 ? 3.5 : 8.0;
		vec4 vo = voronoi3(q * sc + float(i) * 7.0);
		float r = 0.25 + 0.4 * vo.z;
		float d = vo.x / r;
		float crater = d < 1.0 ? (d * d - 1.0) * 0.35 : 0.0;
		float rim = exp(-pow((d - 1.0) / 0.18, 2.0)) * 0.14;
		float amp = (i == 0 ? 1.0 : 0.5) * step(0.25, vo.z);
		h += (crater + rim) * amp;
	}
	s.alb = ramp4(0.55 + h * 1.1);
	s.emit = vec3(0.0);
	s.spec = 0.05;
	s.h = h;
	s.land = 1.0;
	return s;
}
#endif

void apply_eye(vec3 Nw, float amt, inout vec3 alb, inout vec3 emit, inout float spec, inout float h) {
	vec3 ed = normalize(eye_dir);
	vec3 up = abs(ed.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 eu = normalize(cross(up, ed));
	vec3 ev = cross(ed, eu);
	float c = dot(Nw, ed);
	amt *= smoothstep(0.0, 0.15, c);
	vec2 e = vec2(dot(Nw, eu), dot(Nw, ev)) / sin(eye_size);
	float lid_h = eye_open * 0.62 * max(1.0 - e.x * e.x, 0.0);
	float d_lid = abs(e.y) - lid_h;
	float inside = (1.0 - smoothstep(-0.015, 0.015, d_lid)) * step(abs(e.x), 1.0);
	vec2 de = e - eye_look;
	float ir = length(de) / 0.44;
	// sclera
	float vein = pow(1.0 - abs(gnoise3(vec3(e * 5.0, 1.3) + seed_off)), 12.0);
	vec3 sclera = mix(vec3(0.85, 0.8, 0.62), vec3(0.55, 0.05, 0.04), vein * 0.8);
	sclera *= mix(0.25, 1.0, smoothstep(0.0, -0.2, d_lid));
	// iris
	float ang = atan(de.y, de.x);
	float fib = gnoise3(vec3(cos(ang) * 7.0, sin(ang) * 7.0, ir * 4.0) + seed_off) * 0.5 + 0.5;
	float fib2 = gnoise3(vec3(cos(ang) * 19.0, sin(ang) * 19.0, ir * 9.0) + seed_off * 2.0) * 0.5 + 0.5;
	vec3 iris = mix(iris_col * 0.35, iris_col * 1.25, fib * 0.7 + fib2 * 0.3);
	iris *= mix(1.0, 0.25, smoothstep(0.75, 1.0, ir));
	iris += iris_col * smoothstep(0.55, 0.2, ir) * 0.5;
	float iris_m = 1.0 - smoothstep(0.97, 1.03, ir);
	// pupil
	float pup = 0.0;
	if (pupil_type == 0) {
		vec2 pp = de / vec2(0.07, 0.38);
		pup = 1.0 - smoothstep(0.9, 1.1, length(pp));
	} else if (pupil_type == 1) {
		pup = 1.0 - smoothstep(0.17, 0.19, length(de));
	} else if (pupil_type == 2) {
		for (int k = 0; k < 3; k++) {
			float a = float(k) * TAU / 3.0 + 0.5;
			vec2 o = vec2(cos(a), sin(a)) * 0.17;
			pup = max(pup, 1.0 - smoothstep(0.075, 0.09, length(de - o)));
		}
	} else {
		float sa = abs(sin(ang * 2.5)) * 0.12 + 0.05;
		pup = 1.0 - smoothstep(sa, sa + 0.02, length(de));
	}
	vec3 eyecol = mix(sclera, iris, iris_m);
	eyecol = mix(eyecol, vec3(0.0), pup);
	vec3 eyeemit = iris_col * iris_m * (1.0 - pup) * (0.55 + 0.6 * fib) + sclera * (1.0 - iris_m) * 0.12;
	// eyelid folds
	float outside = 1.0 - inside;
	float fold = sin(d_lid * 34.0 - 0.6) * exp(-max(d_lid, 0.0) * 2.5) * step(0.0, d_lid);
	float near = exp(-max(d_lid, 0.0) * 5.0) * smoothstep(1.7, 1.0, abs(e.x));
	float lash = smoothstep(0.08, 0.0, d_lid) * step(0.0, d_lid);
	vec3 lidcol = mix(alb, c1 * 0.7, near * 0.6);
	lidcol = mix(lidcol, vec3(0.02, 0.0, 0.0), lash * 0.9);
	float lm = amt * smoothstep(2.0, 1.2, length(e));
	alb = mix(alb, mix(lidcol, eyecol, inside), lm);
	emit = mix(emit, eyeemit * inside, lm * inside);
	spec = mix(spec, 1.0, inside * amt);
	float bulge = inside * (1.0 - min(dot(e, e), 1.0)) * 0.25 + outside * fold * near * 0.05 - lash * 0.04;
	h = mix(h, h * 0.3 + bulge, lm);
}

void apply_many_eyes(vec3 p, vec3 q, float amt, inout vec3 alb, inout vec3 emit, inout float spec, inout float h) {
	vec3 cp;
	vec4 vo = voronoi3c(q * 6.0 + vec3(5.0), cp);
	float present = step(vo.z, amt * 0.55);
	vec3 dv = (q * 6.0 + vec3(5.0)) - cp;
	vec3 dt = dv - p * dot(dv, p);
	vec3 up = abs(p.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 tu = normalize(cross(up, p));
	vec3 tv = cross(p, tu);
	float rs = 0.22 + 0.12 * fract(vo.z * 13.0);
	vec2 e = vec2(dot(dt, tu), dot(dt, tv)) / rs;
	float blink = smoothstep(0.92, 1.0, sin(g_time * 0.7 + vo.z * 40.0));
	float lid_h = 0.6 * (1.0 - blink) * max(1.0 - e.x * e.x, 0.0);
	float d_lid = abs(e.y) - lid_h;
	float inside = (1.0 - smoothstep(-0.03, 0.03, d_lid)) * step(abs(e.x), 1.0);
	float ring = smoothstep(0.25, 0.0, d_lid) * step(0.0, d_lid) * smoothstep(1.5, 0.9, abs(e.x));
	vec2 lk = vec2(sin(g_time * 0.5 + vo.z * 9.0), cos(g_time * 0.4 + vo.z * 7.0)) * 0.15;
	float ir = length(e - lk) / 0.42;
	vec3 iris = mix(iris_col * 0.5, iris_col * 1.2, smoothstep(1.0, 0.3, ir));
	float pup = 1.0 - smoothstep(0.32, 0.38, ir);
	vec3 sclera = vec3(0.8, 0.75, 0.6);
	vec3 col = mix(sclera, iris, step(ir, 1.0));
	col = mix(col, vec3(0.0), pup);
	inside *= present;
	ring *= present;
	alb = mix(alb, c1 * 0.4, ring * 0.8);
	alb = mix(alb, col, inside);
	emit = mix(emit, iris_col * step(ir, 1.0) * (1.0 - pup) * 0.45, inside);
	spec = mix(spec, 1.0, inside);
	h += inside * 0.06 + ring * 0.03;
}

float glyph_layer(vec3 p, out float band_out) {
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float lon = atan(p.z, p.x);
	float ncell = 64.0;
	float cw = TAU / ncell;
	// main inscription band on the equator, optional second band at a seeded latitude
	float lat2 = (hash12(seed_off.xy + vec2(3.0)) - 0.5) * 1.6;
	lat2 = lat2 + sign(lat2 + 0.0001) * 0.35;
	float use2 = step(0.55, glyphs);
	float dl1 = lat;
	float dl2 = lat - lat2;
	float dl = (use2 > 0.5 && abs(dl2) < abs(dl1)) ? dl2 : dl1;
	float which = (use2 > 0.5 && abs(dl2) < abs(dl1)) ? 1.0 : 0.0;
	float shrink = cos(lat);
	vec2 g = vec2(lon / cw * mix(1.0, 1.0, which) + which * 17.0, dl / cw + 0.5);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float inb = step(abs(g.y - 0.5), 0.5);
	float on = step(hash12(id + seed_off.xy * 3.1 + which * 5.0), 0.25 + glyphs * 0.7) * inb;
	float d = glyph_dist(f, floor(hash12(id * 1.7 + vec2(3.0)) * 97.0));
	float fw = length(fwidth(g));
	float lw = 0.028 + fw * 0.3;
	float line = 1.0 - smoothstep(lw, lw + fw * 0.8 + 0.01, d);
	float vis = smoothstep(0.5, 0.2, fw);
	// double rules framing the band
	float r1 = 1.0 - smoothstep(0.0, 0.03 + fw, abs(abs(g.y - 0.5) - 0.62));
	float r2 = 1.0 - smoothstep(0.0, 0.02 + fw * 0.7, abs(abs(g.y - 0.5) - 0.78));
	float edge = max(r1, r2 * 0.6) * vis;
	band_out = edge;
	return clamp(line * on * vis + edge * 0.85, 0.0, 1.0) * step(0.01, glyphs);
}


void fragment() {
	vec3 C = MODEL_MATRIX[3].xyz;
	float R = length(MODEL_MATRIX[0].xyz);
	vec3 Ng = normalize(v_wnorm);
	vec3 Nsph = normalize(v_wpos - C);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
	vec3 p = lowpoly ? normalize(v_face) : normalize(v_obj);
	vec3 q = p + seed_off;
	float ndv = clamp(dot(Nsph, V), 0.0, 1.0);

	Surf s;
#if ARCH == 0
	s = s_drowned(p, q);
#elif ARCH == 1
	s = s_eyeworld(p, q);
#elif ARCH == 2
	s = s_flesh(p, q);
#elif ARCH == 3
	s = s_fungal(p, q);
#elif ARCH == 4
	s = s_fire(p, q);
#elif ARCH == 5
	s = s_leng(p, q);
#elif ARCH == 6
	s = s_colour(p, q, ndv);
#elif ARCH == 7
	s = s_carcosa(p, q);
#elif ARCH == 8
	s = s_chaos(p, q);
#elif ARCH == 9
	s = s_cocoon(p, q);
#else
	s = s_bone(p, q);
#endif

	vec3 alb = s.alb;
	vec3 emit = s.emit;
	float spec = s.spec;
	float h = s.h;

	// glyph inscriptions
	float gband = 0.0;
	float gl = glyph_layer(p, gband);
	alb = mix(alb, alb * 0.35, gl * 0.7);
	h -= gl * 0.03;
	float gpulse = 0.75 + 0.25 * sin(g_time * 1.2 + p.x * 3.0);
	emit += c4 * gl * gpulse * 0.85;

	// corruption spreading from a seeded point
	if (corruption > 0.001) {
		vec3 cd = normalize(hash33(seed_off + vec3(7.0)) - 0.5);
		float dd = acos(clamp(dot(p, cd), -1.0, 1.0)) / PI;
		float reach = corruption * 1.3;
		float mask = smoothstep(reach, reach - 0.25, dd + fbm3(q * 3.0 + vec3(1.0), 3) * 0.3);
		float cv = pow(1.0 - abs(gnoise3(q * 4.0 + vec3(2.0))), 10.0) + 0.6 * pow(1.0 - abs(gnoise3(q * 9.0 + vec3(5.0))), 14.0);
		float cp = 0.6 + 0.4 * sin(g_time * 2.0 - dd * 30.0);
		alb = mix(alb, cor_dark, mask * 0.75);
		emit = mix(emit, emit * 0.3, mask * 0.5) + cor_glow * clamp(cv, 0.0, 1.2) * mask * cp * 0.8;
		h += cv * mask * 0.05;
		spec = mix(spec, 0.8, mask * 0.5);
	}

	if (eyes_many > 0.001) {
		apply_many_eyes(p, q, eyes_many, alb, emit, spec, h);
	}
	if (eye_amt > 0.001) {
		apply_eye(Nsph, eye_amt, alb, emit, spec, h);
	}

	vec3 L = light_vec(v_wpos);
	vec3 N = Ng;
	if (!lowpoly && bump > 0.0) {
		N = perturb_normal(Ng, v_wpos, h, bump * R * 0.06);
	}
	float ndl_geo = dot(Nsph, L);
	float day = smoothstep(-0.05, 0.2, ndl_geo);

	// night side lights
	if (night_lights > 0.001) {
		vec3 cq = q * 38.0;
		vec3 cid = floor(cq);
		vec3 cf = fract(cq) - 0.5;
		float dl = length(cf - (hash33(cid) - 0.5) * 0.6);
		float hl = hash13(cid + vec3(3.3));
		float dots = smoothstep(0.16, 0.02, dl) * step(0.78, hl);
		float cluster = smoothstep(0.0, 0.3, fbm3(q * 5.0 + vec3(3.0), 3));
		emit += mix(c4, vec3(1.0, 0.85, 0.5), 0.3) * dots * cluster * night_lights * s.land * (1.0 - day) * 1.4;
	}

	// ring shadow
	vec3 lcol = g_light_col;
	if (ring_shadow > 0.5) {
		float dn = dot(L, ring_n);
		if (abs(dn) > 0.001) {
			float t = dot(C - v_wpos, ring_n) / dn;
			if (t > 0.0) {
				vec3 hp = v_wpos + L * t;
				float rr = length(hp - C) / R;
				float m = smoothstep(ring_r0, ring_r0 + 0.05, rr) * smoothstep(ring_r1, ring_r1 - 0.05, rr);
				float bands = 0.55 + 0.45 * sin(rr * 40.0 + ring_seed) * sin(rr * 13.0 + ring_seed * 2.0);
				lcol *= 1.0 - m * bands * 0.75;
			}
		}
	}

	vec3 col;
	if (g_style == 5) {
		float fres = pow(1.0 - ndv, 2.2);
		float lat = asin(clamp(p.y, -1.0, 1.0));
		float lon = atan(p.z, p.x);
		vec2 gg = vec2(lon / TAU * 24.0, lat / PI * 12.0);
		vec2 gf = abs(fract(gg) - 0.5);
		vec2 gw = fwidth(gg);
		float grid = max(1.0 - smoothstep(0.0, gw.x * 1.5, 0.5 - gf.x), 1.0 - smoothstep(0.0, gw.y * 1.5, 0.5 - gf.y));
		float hc = h * 14.0;
		float cont = smoothstep(0.5 - fwidth(hc) * 1.5, 0.5, abs(fract(hc) - 0.5));
		float lit = 0.35 + 0.65 * day;
		col = g_holo * (0.05 + fres * 0.9 + grid * 0.28 + cont * 0.3 * lit) + g_holo * luma3(alb) * 0.25 * lit;
		col += mix(g_holo, c4, 0.5) * luma3(emit) * 0.9;
	} else {
		float gloss = ARCH == 0 ? 60.0 : 28.0;
		col = style_shade(alb, N, L, V, lcol, spec, gloss);
		float em_scale = (g_style == 6) ? 0.55 : 1.0;
		col += emit * em_scale;
		float fres = pow(1.0 - ndv, 3.0);
		col += atmo_col * fres * atmo_rim * smoothstep(-0.35, 0.5, ndl_geo);
		col += g_rim_col * pow(1.0 - ndv, 4.0) * max(dot(Nsph, normalize(g_rim_dir)), 0.0) * g_rim_amt;
		col += alb * self_emit;
	}
	ALBEDO = col;
}
