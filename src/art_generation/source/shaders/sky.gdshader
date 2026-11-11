shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec3 n0 : source_color = vec3(0.04, 0.12, 0.15);
uniform vec3 n1 : source_color = vec3(0.12, 0.42, 0.36);
uniform vec3 n2 : source_color = vec3(0.42, 0.17, 0.48);
uniform vec3 paper : source_color = vec3(0.86, 0.8, 0.67);
uniform float neb_amt = 0.6;
uniform float star_amt = 1.0;
uniform vec3 seed_off = vec3(0.0);
uniform int feature = 0;         // 0 none 1 tendrils 2 spiral galaxy 3 faint watcher
uniform vec3 feat_dir = vec3(0.0, 0.0, -1.0);
uniform float feat_amt = 1.0;
uniform float madness = 0.0;

#include "res://src/art_generation/source/shaders/common.gdshaderinc"

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 star_layer(vec3 d, float scale, float prob, float size, float bright) {
	vec3 q = d * scale + seed_off * 13.0;
	vec3 id = floor(q);
	vec3 f = fract(q);
	vec3 h = hash33(id);
	vec3 sp = 0.15 + h * 0.7;
	float pix = length(fwidth(q)) * 0.6;
	float dd = length(f - sp);
	float on = step(hash13(id + vec3(7.1)), prob);
	float sz = max(pix * size, 0.0001);
	float core = exp(-dd * dd / (sz * sz));
	float halo = exp(-dd / (sz * 4.0)) * 0.12;
	float tw = 0.75 + 0.25 * sin(g_time * (1.0 + h.y * 3.0) + h.z * 40.0);
	vec3 tint = mix(vec3(0.65, 0.78, 1.0), vec3(1.0, 0.82, 0.62), h.x);
	return tint * (core + halo) * on * bright * (0.4 + 0.6 * h.z) * tw;
}

void fragment() {
	vec3 d = normalize(v_wpos - CAMERA_POSITION_WORLD);
	vec3 q = d * 2.1 + seed_off;
	vec3 w = q + 0.7 * vec3(fbm3(q * 1.2, 4), fbm3(q * 1.2 + vec3(5.1), 4), fbm3(q * 1.2 + vec3(9.7), 4));
	float tend = 0.0;
	if (feature == 1) {
		// stretched, writhing tendrils
		vec3 ax = normalize(feat_dir);
		float along = dot(d, ax);
		vec3 perp = d - ax * along;
		w += perp * 2.5 * feat_amt + ax * fbm3(perp * 3.0 + seed_off, 3) * 0.8;
		tend = pow(ridged3(w * 1.6 + vec3(2.0), 5), 2.0) * feat_amt;
	}
	float a = fbm3(w * 1.4, 6);
	float b = ridged3(w * 2.2 + vec3(3.0), 5);
	float dust = smoothstep(0.05, 0.45, fbm3(w * 3.1 + vec3(7.0), 5));
	float big = fbm3(q * 0.6 + vec3(2.0), 3);

	float dens = clamp(a * 1.5 + 0.25 + (neb_amt - 0.5) * 0.7, 0.0, 1.0);
	dens = dens * dens * neb_amt * 1.6;
	vec3 base = mix(vec3(0.003, 0.003, 0.008), n0 * 0.22, smoothstep(-0.4, 0.5, big));
	vec3 neb = base;
	neb += mix(n0, n1, smoothstep(0.1, 0.8, dens)) * dens * 0.9;
	neb += n2 * pow(b, 4.0) * neb_amt * 0.55 * smoothstep(-0.2, 0.3, a);
	neb += mix(n1, n2, 0.5) * tend * 0.9;
	neb *= 1.0 - dust * 0.75 * neb_amt;
	float occl = 1.0 - clamp(dens * 0.6 + dust * 0.5 * neb_amt, 0.0, 0.85);

	vec3 stars = star_layer(d, 90.0, 0.10, 1.6, 1.4) + star_layer(d, 220.0, 0.28, 1.1, 0.8) + star_layer(d, 480.0, 0.45, 0.9, 0.45);
	stars *= star_amt;

	vec3 col = neb + stars * occl;

	if (feature == 2) {
		vec3 ax = normalize(feat_dir);
		vec3 tu = normalize(cross(ax, vec3(0.0, 1.0, 0.0)));
		vec3 tv = cross(tu, ax);
		vec2 g = vec2(dot(d, tu), dot(d, tv) * 2.4) / 0.12;
		float r = length(g);
		float an = atan(g.y, g.x);
		float arms = 0.5 + 0.5 * sin(an * 2.0 - log(r + 0.05) * 4.0 + fbm2(g * 2.0, 3) * 1.5);
		float gal = exp(-r * 1.6) * (0.4 + 0.9 * arms * smoothstep(0.0, 0.4, r)) + exp(-r * r * 30.0) * 0.8;
		col += mix(n2, vec3(1.0, 0.9, 0.75), exp(-r * 3.0)) * gal * feat_amt * step(0.0, dot(d, ax)) * 0.9;
	}
	if (feature == 3) {
		// a faint, enormous eye made of nebula gas
		vec3 ax = normalize(feat_dir);
		vec3 tu = normalize(cross(ax, vec3(0.0, 1.0, 0.0)));
		vec3 tv = cross(tu, ax);
		float front = smoothstep(0.0, 0.2, dot(d, ax));
		vec2 e = vec2(dot(d, tu), dot(d, tv)) / 0.2;
		float lid = 0.48 * max(1.0 - e.x * e.x, 0.0);
		float dl = abs(e.y) - lid;
		float ins = (1.0 - smoothstep(-0.06, 0.1, dl)) * step(abs(e.x), 1.0);
		float ir = length(e) / 0.36;
		float wisp = smoothstep(0.4, 0.0, abs(dl)) * (0.45 + 0.55 * fbm2(e * 5.0 + seed_off.xy, 4)) * smoothstep(1.4, 0.8, abs(e.x));
		float iris = smoothstep(1.0, 0.55, ir) * (0.55 + 0.45 * fbm2(vec2(atan(e.y, e.x) * 3.0, ir * 3.0), 3));
		float pup = (1.0 - smoothstep(0.06, 0.12, abs(e.x) / max(0.2, 1.0 - ir * 0.7))) * smoothstep(0.9, 0.6, ir);
		vec3 ec = n1 * wisp * 0.8 + mix(n2, vec3(1.0, 0.85, 0.4), 0.45) * iris * ins * (1.0 - pup) * 0.85;
		col = mix(col, col * 0.35, ins * pup * feat_amt * front);
		col += ec * feat_amt * front;
	}

	if (g_style == 5) {
		float lum = luma3(col);
		float lat = asin(clamp(d.y, -1.0, 1.0));
		float lon = atan(d.z, d.x);
		vec2 gg = vec2(lon / TAU * 72.0, lat / PI * 36.0);
		vec2 gf = abs(fract(gg) - 0.5);
		vec2 gw = fwidth(gg);
		float grid = max(1.0 - smoothstep(0.0, gw.x * 1.2, 0.5 - gf.x), 1.0 - smoothstep(0.0, gw.y * 1.2, 0.5 - gf.y));
		col = g_holo * (0.02 + lum * 0.55 + grid * 0.05) + g_holo * luma3(stars) * 0.8;
	} else if (g_style == 6) {
		float pig = clamp(dens * 0.9 + pow(b, 4.0) * neb_amt * 0.5 + tend * 0.6, 0.0, 1.0);
		vec3 wash = mix(paper, paper * mix(vec3(1.0), n1 * 1.6 + 0.25, 0.8), pig * 0.75);
		wash = mix(wash, wash * (n2 * 0.9 + 0.35), pow(b, 5.0) * neb_amt * 0.6);
		wash *= 1.0 - 0.06 * big;
		float ink = clamp(luma3(stars) * 1.6, 0.0, 1.0);
		col = mix(wash, vec3(0.16, 0.11, 0.08), ink * 0.7);
	} else if (g_style == 2) {
		// engraving plate: negative of the sky, paper with inked stars and hatched nebulae
		float sv = luma3(star_layer(d, 90.0, 0.10, 1.6, 1.4));
		float neb_v = clamp(dens * 0.9 + pow(b, 4.0) * neb_amt * 0.5 + tend * 0.6, 0.0, 1.0);
		float v = 0.95 - neb_v * 0.5 - smoothstep(0.25, 0.7, sv) * 0.9;
		col = vec3(clamp(v, 0.0, 1.0));
	} else if (g_style == 7) {
		vec3 grad = mix(n0 * 1.1 + 0.04, n2 * 1.3 + 0.06, smoothstep(-0.6, 0.8, d.y + big * 0.4));
		float flat_d = floor(dens * 3.0 + 0.5) / 3.0;
		col = grad + mix(n1, n2, 0.4) * flat_d * 0.8 + stars * 1.3;
	}
	ALBEDO = col;
}
