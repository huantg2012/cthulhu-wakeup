shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 c_a : source_color = vec3(0.6, 0.55, 0.45);
uniform vec3 c_b : source_color = vec3(0.3, 0.25, 0.22);
uniform vec3 c_glow : source_color = vec3(0.4, 1.0, 0.6);
uniform float inner = 0.55;          // inner radius as fraction of outer
uniform float seed = 0.0;
uniform float density = 0.85;
uniform float glyph_amt = 0.0;
uniform vec3 planet_c = vec3(0.0);
uniform float planet_r = 1.0;

#include "res://shaders/common.gdshaderinc"

varying vec3 v_obj;
varying vec3 v_wpos;
void vertex() {
	v_obj = VERTEX;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bandn(float x) {
	return fbm2(vec2(x, seed), 4);
}

void fragment() {
	float r = length(v_obj.xz);
	float f = (r - inner) / (1.0 - inner);
	if (f < 0.0 || f > 1.0) { discard; }
	float b1 = bandn(f * 14.0) * 0.5 + 0.5;
	float b2 = bandn(f * 55.0 + 10.0) * 0.5 + 0.5;
	float b3 = bandn(f * 160.0 + 20.0) * 0.5 + 0.5;
	float gaps = smoothstep(0.25, 0.35, abs(fract(f * 2.3 + seed) - 0.5) * 2.0 + 0.1);
	float dens = clamp(b1 * 0.6 + b2 * 0.5 + b3 * 0.3 - 0.35, 0.0, 1.0) * gaps;
	dens *= smoothstep(0.0, 0.04, f) * smoothstep(1.0, 0.9, f);
	dens = clamp(dens * 1.6 * density, 0.0, 0.97);
	vec3 col = mix(c_b, c_a, b2 * 0.7 + b1 * 0.3);
	// lighting: lit from either side, forward scatter brightens
	vec3 L = light_vec(v_wpos);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
	float fwd = pow(max(dot(-V, L), 0.0), 4.0);
	float lit = 0.55 + 0.45 * abs(dot(normalize(mat3(MODEL_MATRIX) * vec3(0.0, 1.0, 0.0)), L));
	// planet shadow
	vec3 oc = planet_c - v_wpos;
	float t = dot(oc, L);
	float sh = 1.0;
	if (t > 0.0) {
		float d2 = dot(oc, oc) - t * t;
		sh = smoothstep(planet_r * 0.92, planet_r * 1.02, sqrt(max(d2, 0.0)));
	}
	vec3 c = col * g_light_col * (lit * sh * 0.95 + 0.05) + col * fwd * sh * (1.0 - dens) * 1.5;
	c += g_amb * col;
	// eldritch glyph circle inside the rings
	if (glyph_amt > 0.0) {
		float ang = atan(v_obj.z, v_obj.x);
		float ncell = 72.0;
		float gx = (ang / TAU + 0.5) * ncell + g_time * 0.15;
		float band_c = 0.62;
		float gy = (f - band_c) / (1.0 / ncell * TAU * 0.5 * (inner + (1.0 - inner) * band_c) / (1.0 - inner) * 1.0) * 0.5 + 0.5;
		vec2 gf = vec2(fract(gx), gy);
		float gid = floor(gx);
		float gd = glyph_dist(gf, mod(gid, ncell) + floor(seed * 10.0) * 31.0);
		float inb = step(0.0, gy) * step(gy, 1.0);
		float fw = fwidth(gx) * 1.2;
		float gl = (1.0 - smoothstep(0.05, 0.05 + fw * 0.6 + 0.02, gd)) * inb;
		float lines = 1.0 - smoothstep(0.0, fwidth(gy) * 1.5, abs(gy + 0.15) * 1.0);
		lines = max(lines, 1.0 - smoothstep(0.0, fwidth(gy) * 1.5, abs(gy - 1.15)));
		float gg = (gl + lines * 0.8) * glyph_amt;
		c = mix(c, c_glow * 1.4, clamp(gg, 0.0, 1.0));
		dens = max(dens, clamp(gg, 0.0, 1.0));
	}
	if (g_style == 5) {
		c = g_holo * (0.3 + dens);
		dens *= 0.45;
	}
	ALBEDO = c;
	ALPHA = dens;
}
